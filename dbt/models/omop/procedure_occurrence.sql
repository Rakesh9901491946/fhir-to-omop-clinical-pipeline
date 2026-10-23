{{ config(materialized='table') }}
select row_number() over(order by prc.resource_id)::bigint as procedure_occurrence_id, p.person_id,
       (prc.payload#>>'{performedDateTime}')::date as procedure_date,
       coalesce(m.target_concept_id,0)::integer as procedure_concept_id,
       coalesce(prc.payload#>>'{code,coding,0,code}',prc.payload#>>'{code,text}') as procedure_source_value,
       coalesce(m.source_concept_id,0)::integer as procedure_source_concept_id, null::bigint as visit_occurrence_id
from {{ ref('stg_resources') }} prc
join {{ ref('stg_resources') }} pr on pr.resource_type='Patient' and pr.resource_id=split_part(prc.payload#>>'{subject,reference}','/',2)
join {{ ref('person') }} p on p.person_source_value=pr.resource_id
left join raw.terminology_map m on m.source_system=prc.payload#>>'{code,coding,0,system}' and m.source_code=prc.payload#>>'{code,coding,0,code}'
  and m.vocabulary_release=(select config_value from raw.pipeline_config where config_key='vocabulary_release' limit 1)
where prc.resource_type='Procedure'

