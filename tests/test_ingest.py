import json
from pathlib import Path

import pytest

from fhir_omop.ingest import FHIRValidationError, deidentify, iter_resources, stable_token
from fhir_omop.quality import profile


def test_deidentification_is_stable_shifts_dates_and_preserves_links():
    patient = {"resourceType": "Patient", "id": "p1", "birthDate": "1980-01-02"}
    encounter = {"resourceType": "Encounter", "id": "e1", "subject": {"reference": "Patient/p1"}}
    clean_p = deidentify(patient, "salt", 2)
    clean_e = deidentify(encounter, "salt", 2)
    assert clean_p["id"] == stable_token("Patient:p1", "salt")
    assert clean_p["birthDate"] == "1980-01-04"
    assert clean_e["subject"]["reference"] == f"Patient/{clean_p['id']}"


def test_ingestion_deduplicates_identity_and_reports_records(tmp_path: Path):
    patient = {"resourceType": "Patient", "id": "p1", "gender": "female"}
    bundle = {"resourceType": "Bundle", "entry": [{"resource": patient}, {"resource": patient}]}
    (tmp_path / "bundle.json").write_text(json.dumps(bundle))
    records = list(iter_resources(tmp_path))
    assert len(records) == 2
    assert len({r.resource_id for r in records}) == 1
    assert profile(tmp_path)["duplicate_payloads"] == 1


def test_invalid_bundle_is_rejected(tmp_path: Path):
    (tmp_path / "bad.json").write_text('{"resourceType":"Patient"}')
    with pytest.raises(FHIRValidationError):
        list(iter_resources(tmp_path))

