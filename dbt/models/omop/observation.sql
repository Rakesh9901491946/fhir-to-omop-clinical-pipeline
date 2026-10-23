{{ config(materialized='table') }}
select row_number() over(order by o.resource_id)::bigint as observation_id, p.person_id,
       (o.payload#>>'{effectiveDateTime}')::date as observation_date,
       coalesce(m.target_concept_id,0)::integer as observation_concept_id,
       coalesce(o.payload#>>'{code,coding,0,code}',o.payload#>>'{code,text}') as observation_source_value,
       coalesce(m.source_concept_id,0)::integer as observation_source_concept_id,
       coalesce(o.payload#>>'{valueString}', o.payload#>>'{valueCodeableConcept,text}', o.payload#>>'{valueBoolean}') as value_as_string,
       null::bigint as visit_occurrence_id
from {{ ref('stg_resources') }} o
join {{ ref('stg_resources') }} pr on pr.resource_type='Patient' and pr.resource_id=split_part(o.payload#>>'{subject,reference}','/',2)
join {{ ref('person') }} p on p.person_source_value=pr.resource_id
left join raw.terminology_map m on m.source_system=o.payload#>>'{code,coding,0,system}' and m.source_code=o.payload#>>'{code,coding,0,code}'
  and m.vocabulary_release=(select config_value from raw.pipeline_config where config_key='vocabulary_release' limit 1)
where o.resource_type='Observation' and o.payload#>'{valueQuantity}' is null

