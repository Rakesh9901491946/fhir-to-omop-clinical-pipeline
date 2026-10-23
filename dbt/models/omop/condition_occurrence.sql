{{ config(materialized='table') }}
with fhir_conditions as (
  select p.person_id, nullif(c.payload->>'onsetDateTime','')::date as condition_start_date,
         coalesce(m.target_concept_id, 0)::integer as condition_concept_id,
         coalesce(c.payload#>>'{code,coding,0,code}', c.payload#>>'{code,text}') as condition_source_value,
         coalesce(m.source_concept_id, 0)::integer as condition_source_concept_id,
         v.visit_occurrence_id,
         'fhir:' || c.resource_id as ordering_key
  from {{ ref('stg_resources') }} c
  join {{ ref('stg_resources') }} pr on pr.resource_type='Patient' and pr.resource_id=split_part(c.payload#>>'{subject,reference}','/',2)
  join {{ ref('person') }} p on p.person_source_value=pr.resource_id
  left join {{ ref('visit_occurrence') }} v on v.person_id=p.person_id and v.visit_start_date <= coalesce(nullif(c.payload->>'onsetDateTime','')::date, v.visit_start_date)
  left join raw.terminology_map m on m.source_system=c.payload#>>'{code,coding,0,system}' and m.source_code=c.payload#>>'{code,coding,0,code}'
    and m.vocabulary_release=(select config_value from raw.pipeline_config where config_key='vocabulary_release' limit 1)
  where c.resource_type='Condition'
), partner_conditions as (
  select p.person_id, s.condition_start_date, 0::integer as condition_concept_id,
         s.condition_source_value, 0::integer as condition_source_concept_id,
         null::bigint as visit_occurrence_id,
         'partner:' || s.source_partner || ':' || s.loaded_at::text || ':' || s.person_source_value || ':' || s.condition_source_value as ordering_key
  from raw.partner_omop_staging s
  join {{ ref('person') }} p on p.person_source_value=s.person_source_value
)
select row_number() over (order by ordering_key)::bigint as condition_occurrence_id,
       person_id, condition_start_date, condition_concept_id,
       condition_source_value, condition_source_concept_id, visit_occurrence_id
from (
  select * from fhir_conditions
  union all
  select * from partner_conditions
) all_conditions

