select visit_occurrence_id from {{ ref('visit_occurrence') }} where visit_start_date > current_date + interval '1 day'

