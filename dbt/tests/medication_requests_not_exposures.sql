select * from {{ ref('stg_medication_request') }} where semantic_type <> 'prescription_order'

