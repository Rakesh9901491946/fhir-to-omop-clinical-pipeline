{{ config(materialized='table') }}
select resource_id as source_resource_id,
       split_part(payload#>>'{subject,reference}','/',2) as person_source_id,
       nullif(payload->>'authoredOn','')::date as authored_date,
       coalesce(payload#>>'{medicationCodeableConcept,coding,0,code}',payload#>>'{medicationCodeableConcept,text}') as medication_source_value,
       0::integer as medication_source_concept_id,
       payload->>'status' as status,
       'prescription_order'::text as semantic_type
from {{ ref('stg_resources') }} where resource_type='MedicationRequest'

