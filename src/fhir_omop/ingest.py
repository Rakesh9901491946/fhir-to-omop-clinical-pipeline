"""FHIR bundle validation, deterministic de-identification and idempotent loading."""
from __future__ import annotations

import hashlib
import json
import logging
import os
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Iterable

LOGGER = logging.getLogger(__name__)
SUPPORTED = {"Patient", "Encounter", "Condition", "Observation", "Procedure", "MedicationRequest"}


class FHIRValidationError(ValueError):
    pass


@dataclass(frozen=True)
class ResourceRecord:
    resource_type: str
    resource_id: str
    payload: dict[str, Any]
    fingerprint: str


def stable_token(value: str, salt: str) -> str:
    return hashlib.sha256(f"{salt}:{value}".encode()).hexdigest()[:24]


def shift_date(value: str, days: int) -> str:
    try:
        if "T" in value:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return (parsed + timedelta(days=days)).isoformat().replace("+00:00", "Z")
        return (date.fromisoformat(value) + timedelta(days=days)).isoformat()
    except ValueError:
        return value


def deidentify(resource: dict[str, Any], salt: str, shift_days: int) -> dict[str, Any]:
    """Replace resource identifiers and shift dates while preserving references."""
    data = json.loads(json.dumps(resource))
    old_id = data.get("id")
    if old_id:
        data["id"] = stable_token(f"{data.get('resourceType')}:{old_id}", salt)
    def walk(node: Any) -> None:
        if isinstance(node, dict):
            for key, value in list(node.items()):
                if key == "reference" and isinstance(value, str) and "/" in value:
                    typ, rid = value.split("/", 1)
                    if typ in SUPPORTED:
                        node[key] = f"{typ}/{stable_token(f'{typ}:{rid}', salt)}"
                elif key in {"valueDate", "valueDateTime", "effectiveDateTime", "birthDate", "issued", "authoredOn", "recordedDate", "onsetDateTime"} and isinstance(value, str):
                    node[key] = shift_date(value, shift_days)
                else:
                    walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)
    walk(data)
    return data


def iter_resources(path: Path, *, salt: str = "local-demo-only", shift_days: int = 0) -> Iterable[ResourceRecord]:
    """Yield supported resources from FHIR Bundle JSON files; reject malformed entries."""
    for file_path in sorted(path.glob("*.json")):
        try:
            bundle = json.loads(file_path.read_text())
        except (OSError, json.JSONDecodeError) as exc:
            raise FHIRValidationError(f"{file_path}: invalid JSON: {exc}") from exc
        if not isinstance(bundle, dict) or bundle.get("resourceType") != "Bundle" or not isinstance(bundle.get("entry", []), list):
            raise FHIRValidationError(f"{file_path}: expected a FHIR Bundle with entry array")
        for index, entry in enumerate(bundle.get("entry", [])):
            if not isinstance(entry, dict):
                raise FHIRValidationError(f"{file_path} entry {index}: expected object")
            resource = entry.get("resource", {})
            if not isinstance(resource, dict):
                raise FHIRValidationError(f"{file_path} entry {index}: resource must be object")
            typ, rid = resource.get("resourceType"), resource.get("id")
            if typ not in SUPPORTED:
                continue
            if not isinstance(rid, str) or not rid:
                raise FHIRValidationError(f"{file_path} entry {index}: {typ} is missing id")
            clean = deidentify(resource, salt, shift_days)
            canonical = json.dumps(clean, sort_keys=True, separators=(",", ":"))
            yield ResourceRecord(typ, clean["id"], clean, hashlib.sha256(canonical.encode()).hexdigest())


def load_directory(path: Path, database_url: str, *, salt: str | None = None, shift_days: int | None = None) -> dict[str, int]:
    """Upsert resource payloads into raw.fhir_resource; resource identity makes reruns safe."""
    try:
        import psycopg
    except ImportError as exc:
        raise RuntimeError("Install the project dependencies to connect to PostgreSQL") from exc
    salt = salt or os.getenv("DEIDENTIFICATION_SALT", "local-demo-only")
    shift_days = int(os.getenv("DATE_SHIFT_DAYS", "0")) if shift_days is None else shift_days
    counts: dict[str, int] = {}
    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            for record in iter_resources(path, salt=salt, shift_days=shift_days):
                cur.execute("""INSERT INTO raw.fhir_resource(resource_type, resource_id, payload, fingerprint)
                    VALUES (%s, %s, %s, %s) ON CONFLICT(resource_type, resource_id)
                    DO UPDATE SET payload=EXCLUDED.payload, fingerprint=EXCLUDED.fingerprint,
                    ingested_at=now() WHERE raw.fhir_resource.fingerprint <> EXCLUDED.fingerprint""",
                    (record.resource_type, record.resource_id, json.dumps(record.payload), record.fingerprint))
                counts[record.resource_type] = counts.get(record.resource_type, 0) + 1
    LOGGER.info("FHIR ingestion complete", extra={"resource_counts": counts})
    return counts

