{{ config(materialized='table') }}
with source_people as (
  select resource_id as person_source_value,
         extract(year from nullif(payload->>'birthDate','')::date)::integer as year_of_birth,
         payload->>'gender' as gender_source_value
  from {{ ref('stg_resources') }} where resource_type = 'Patient'
  union
  select distinct person_source_value, null::integer, 'partner'::text
  from raw.partner_omop_staging where nullif(person_source_value, '') is not null
)
select row_number() over (order by person_source_value)::bigint as person_id,
       person_source_value,
       year_of_birth,
       gender_source_value,
       0::integer as gender_source_concept_id
from source_people

