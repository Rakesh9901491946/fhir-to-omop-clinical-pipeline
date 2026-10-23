CREATE TABLE IF NOT EXISTS raw.partner_omop_staging (
  person_source_value text,
  condition_source_value text,
  condition_start_date date,
  source_partner text NOT NULL,
  loaded_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS partner_omop_staging_natural_key
  ON raw.partner_omop_staging(source_partner, person_source_value, condition_source_value, condition_start_date);
CREATE TABLE IF NOT EXISTS raw.pipeline_config (
  config_key text PRIMARY KEY,
  config_value text NOT NULL
);

