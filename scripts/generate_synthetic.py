"""Create reproducible Synthea-shaped FHIR R4 examples; no real patient data."""
import json
from pathlib import Path


def generate(output: Path, patients: int = 100) -> None:
    output.mkdir(parents=True, exist_ok=True)
    for batch in range((patients + 24) // 25):
        entries = []
        for n in range(batch * 25 + 1, min((batch + 1) * 25, patients) + 1):
            pid, month = f"patient-{n:03}", (n % 12) + 1
            start, visit = f"2024-{month:02}-10T09:00:00Z", f"encounter-{n:03}"
            resources = [
                {"resourceType": "Patient", "id": pid, "birthDate": f"{1960+n%35}-01-15", "gender": ["female", "male", "unknown"][n%3]},
                {"resourceType": "Encounter", "id": visit, "status": "finished", "subject": {"reference": f"Patient/{pid}"}, "period": {"start": start, "end": start}},
                {"resourceType": "Condition", "id": f"condition-{n:03}", "subject": {"reference": f"Patient/{pid}"}, "encounter": {"reference": f"Encounter/{visit}"}, "onsetDateTime": start, "code": {"coding": [{"system": "http://hl7.org/fhir/sid/icd-10-cm", "code": "I10"}], "text": "Synthetic hypertension example"}},
                {"resourceType": "Observation", "id": f"observation-{n:03}", "subject": {"reference": f"Patient/{pid}"}, "effectiveDateTime": start, "status": "final", "code": {"coding": [{"system": "http://loinc.org", "code": "8480-6"}], "text": "Synthetic systolic blood pressure"}, "valueQuantity": {"value": 120+n%20, "unit": "mmHg"}},
                {"resourceType": "Observation", "id": f"observation-status-{n:03}", "subject": {"reference": f"Patient/{pid}"}, "effectiveDateTime": start, "status": "final", "code": {"text": "Synthetic smoking status"}, "valueString": "never smoker"},
                {"resourceType": "Procedure", "id": f"procedure-{n:03}", "subject": {"reference": f"Patient/{pid}"}, "performedDateTime": start, "status": "completed", "code": {"coding": [{"system": "http://snomed.info/sct", "code": "185349003"}], "text": "Synthetic clinical procedure"}},
                {"resourceType": "MedicationRequest", "id": f"medication-request-{n:03}", "subject": {"reference": f"Patient/{pid}"}, "status": "active", "intent": "order", "authoredOn": f"2024-{month:02}-10", "medicationCodeableConcept": {"coding": [{"system": "http://www.nlm.nih.gov/research/umls/rxnorm", "code": "197361"}], "text": "Synthetic prescription order"}},
            ]
            entries.extend({"resource": resource} for resource in resources)
        bundle = {"resourceType": "Bundle", "type": "collection", "entry": entries}
        (output / f"synthetic-{batch+1:02}.json").write_text(json.dumps(bundle, indent=2) + "\n")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("data/fhir"))
    parser.add_argument("--patients", type=int, default=100)
    args = parser.parse_args()
    generate(args.output, args.patients)

