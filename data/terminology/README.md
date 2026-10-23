# Vocabulary mappings

No vocabulary terms or OMOP concept IDs are bundled. Load a licensed/authorized
OMOP vocabulary release into `raw.terminology_map` with its release identifier.
The dbt models join exact `source_system` + `source_code`; absent mappings retain
the source code and set the concept ID to `0`. This avoids fabricated mappings.

