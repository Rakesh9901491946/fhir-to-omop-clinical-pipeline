CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS omop;

CREATE TABLE IF NOT EXISTS raw.fhir_resource (
    resource_type text NOT NULL,
    resource_id text NOT NULL,
    payload jsonb NOT NULL,
    fingerprint text NOT NULL,
    ingested_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(resource_type, resource_id)
);
CREATE TABLE IF NOT EXISTS raw.terminology_map (
  source_system text NOT NULL,
  source_code text NOT NULL,
  target_concept_id integer NOT NULL,
  source_concept_id integer NOT NULL DEFAULT 0,
  vocabulary_release text NOT NULL,
  PRIMARY KEY(source_system, source_code, vocabulary_release),
  CHECK(target_concept_id > 0)
);

-- OMOP CDM v5.4 demo subset. Concepts are never fabricated: source mappings
-- must be loaded from a licensed/authorized vocabulary release by the operator.
CREATE TABLE IF NOT EXISTS omop.person (
    person_id bigint PRIMARY KEY,
    person_source_value text NOT NULL,
    year_of_birth integer,
    gender_source_value text,
    gender_source_concept_id integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS omop.visit_occurrence (
    visit_occurrence_id bigint PRIMARY KEY,
    person_id bigint NOT NULL REFERENCES omop.person(person_id),
    visit_start_date date NOT NULL,
    visit_end_date date NOT NULL,
    visit_concept_id integer NOT NULL DEFAULT 0,
    visit_source_value text,
    visit_source_concept_id integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS omop.condition_occurrence (
    condition_occurrence_id bigint PRIMARY KEY,
    person_id bigint NOT NULL REFERENCES omop.person(person_id),
    condition_start_date date,
    condition_concept_id integer NOT NULL DEFAULT 0,
    condition_source_value text,
    condition_source_concept_id integer NOT NULL DEFAULT 0,
    visit_occurrence_id bigint REFERENCES omop.visit_occurrence(visit_occurrence_id)
);
CREATE TABLE IF NOT EXISTS omop.measurement (
    measurement_id bigint PRIMARY KEY,
    person_id bigint NOT NULL REFERENCES omop.person(person_id),
    measurement_date date,
    measurement_concept_id integer NOT NULL DEFAULT 0,
    measurement_source_value text,
    measurement_source_concept_id integer NOT NULL DEFAULT 0,
    value_as_number numeric,
    unit_source_value text,
    visit_occurrence_id bigint REFERENCES omop.visit_occurrence(visit_occurrence_id)
);
CREATE TABLE IF NOT EXISTS omop.observation (
    observation_id bigint PRIMARY KEY,
    person_id bigint NOT NULL REFERENCES omop.person(person_id),
    observation_date date,
    observation_concept_id integer NOT NULL DEFAULT 0,
    observation_source_value text,
    observation_source_concept_id integer NOT NULL DEFAULT 0,
    value_as_string text,
    visit_occurrence_id bigint REFERENCES omop.visit_occurrence(visit_occurrence_id)
);
CREATE TABLE IF NOT EXISTS omop.procedure_occurrence (
    procedure_occurrence_id bigint PRIMARY KEY,
    person_id bigint NOT NULL REFERENCES omop.person(person_id),
    procedure_date date,
    procedure_concept_id integer NOT NULL DEFAULT 0,
    procedure_source_value text,
    procedure_source_concept_id integer NOT NULL DEFAULT 0,
    visit_occurrence_id bigint REFERENCES omop.visit_occurrence(visit_occurrence_id)
);
-- MedicationRequest means an order/prescription, not confirmed drug exposure.
CREATE TABLE IF NOT EXISTS staging.medication_request (
    source_resource_id text PRIMARY KEY,
    person_source_id text NOT NULL,
    authored_date date,
    medication_source_value text,
    medication_source_concept_id integer NOT NULL DEFAULT 0,
    status text,
    semantic_type text NOT NULL DEFAULT 'prescription_order'
);

