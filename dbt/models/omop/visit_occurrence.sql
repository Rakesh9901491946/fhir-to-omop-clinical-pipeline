{{ config(materialized='table') }}
select row_number() over (order by e.resource_id)::bigint as visit_occurrence_id,
       p.person_id, (e.payload#>>'{period,start}')::date as visit_start_date,
       coalesce((e.payload#>>'{period,end}')::date, (e.payload#>>'{period,start}')::date) as visit_end_date,
       0::integer as visit_concept_id,
       coalesce(e.payload#>>'{type,0,text}', 'FHIR Encounter') as visit_source_value,
       0::integer as visit_source_concept_id
from {{ ref('stg_resources') }} e
join {{ ref('stg_resources') }} pr on pr.resource_type='Patient'
  and pr.resource_id = split_part(e.payload#>>'{subject,reference}', '/', 2)
join {{ ref('person') }} p on p.person_source_value = pr.resource_id
where e.resource_type='Encounter'

