{{ config(materialized='view') }}
select resource_type, resource_id, payload, fingerprint, ingested_at
from raw.fhir_resource

