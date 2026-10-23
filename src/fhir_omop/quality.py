from collections import Counter
from pathlib import Path

from .ingest import iter_resources


def profile(directory: Path) -> dict:
    counts = Counter()
    source_codes = Counter()
    fingerprints = set()
    duplicates = 0
    rejected = 0
    errors = []
    try:
        for record in iter_resources(directory):
            counts[record.resource_type] += 1
            codings = record.payload.get("code", {}).get("coding", [])
            medication = record.payload.get("medicationCodeableConcept", {}).get("coding", [])
            for coding in codings + medication:
                if coding.get("code"):
                    source_codes[f"{coding.get('system', 'unknown')}|{coding['code']}"] += 1
            if record.fingerprint in fingerprints:
                duplicates += 1
            fingerprints.add(record.fingerprint)
    except ValueError as exc:
        rejected += 1
        errors.append(str(exc))
    return {"resource_counts": dict(sorted(counts.items())), "total_resources": sum(counts.values()),
            "duplicate_payloads": duplicates, "rejected_files_or_entries": rejected,
            "source_code_inventory": dict(sorted(source_codes.items())),
            "mapped_source_codes": 0,
            "unmapped_source_codes": dict(sorted(source_codes.items())),
            "terminology_mapping_note": "No vocabulary release configured; no mappings inferred.",
            "errors": errors}

