-- =====================================================================
-- Crop Loss Database: core schema (iteration 1)
-- Run as a database owner/superuser. All objects live in schema "croploss".
-- The schema, constraints and triggers live in SQL (not R) so that the
-- planned Python/FastAPI rewrite can reuse them unchanged.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS croploss;
SET search_path TO croploss, public;

-- ---------------------------------------------------------------------
-- Users (populated automatically on first ORCID sign-in)
-- ---------------------------------------------------------------------
CREATE TABLE app_user (
  user_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  orcid        text NOT NULL UNIQUE
               CHECK (orcid ~ '^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$'),
  full_name    text,
  email        text,
  affiliation  text,
  role         text NOT NULL DEFAULT 'contributor'
               CHECK (role IN ('contributor', 'curator', 'admin')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_login   timestamptz
);

-- ---------------------------------------------------------------------
-- Controlled vocabularies. Lookup tables rather than CHECK lists so the
-- committee can add terms without a schema change.
-- ---------------------------------------------------------------------
CREATE TABLE lkp_measurement_method (
  code        text PRIMARY KEY,
  label       text NOT NULL,
  description text
);

CREATE TABLE lkp_severity_unit (
  code        text PRIMARY KEY,
  label       text NOT NULL,
  description text
);

CREATE TABLE lkp_agent_group (
  code        text PRIMARY KEY,
  label       text NOT NULL
);

-- ---------------------------------------------------------------------
-- Studies / trials: groups related crop_loss observations (group_id)
-- ---------------------------------------------------------------------
CREATE TABLE study (
  group_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title        text NOT NULL,
  description  text,
  study_type   text CHECK (study_type IN
               ('field_trial', 'survey', 'literature', 'meta_analysis', 'model', 'other')),
  pub_ref      text,
  created_by   text NOT NULL REFERENCES app_user (orcid),
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- crop_loss: the minimum information required for an entry
-- ---------------------------------------------------------------------
CREATE TABLE crop_loss (
  id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id              bigint REFERENCES study (group_id),

  crop                  text NOT NULL,
  pathogen              text NOT NULL,   -- taxonomic name, genus or species
  pathogen_common_name  text,            -- non-taxonomic name / description
  agent_group           text REFERENCES lkp_agent_group (code),

  year                  integer NOT NULL CHECK (year BETWEEN 1800 AND 2100),
  location              text NOT NULL,
  latitude              numeric(9, 6) CHECK (latitude  BETWEEN -90  AND 90),
  longitude             numeric(9, 6) CHECK (longitude BETWEEN -180 AND 180),

  disease_inc           numeric CHECK (disease_inc BETWEEN 0 AND 1),
  disease_inc_var       numeric CHECK (disease_inc_var >= 0),
  disease_sev           numeric,
  disease_sev_var       numeric CHECK (disease_sev_var >= 0),
  severity_unit         text REFERENCES lkp_severity_unit (code),

  yield                 numeric NOT NULL CHECK (yield >= 0),            -- t/ha
  yield_var             numeric CHECK (yield_var >= 0),
  yield_attainable      numeric NOT NULL CHECK (yield_attainable >= 0), -- t/ha
  yield_attainable_var  numeric CHECK (yield_attainable_var >= 0),
  -- Derived, never typed in, so it can't disagree with the yields:
  yield_loss            numeric GENERATED ALWAYS AS (yield_attainable - yield) STORED,
  yield_loss_var        numeric CHECK (yield_loss_var >= 0),

  measurement_method    text NOT NULL REFERENCES lkp_measurement_method (code),

  pub_ref               text,
  meta_data             text,   -- free text; structured detail goes in crop_loss_meta
  search_string         text,

  status                text NOT NULL DEFAULT 'submitted'
                        CHECK (status IN ('submitted', 'approved', 'rejected', 'withdrawn')),
  submitting_person     text NOT NULL REFERENCES app_user (orcid),
  approving_person      text REFERENCES app_user (orcid),
  approved_at           timestamptz,

  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT severity_needs_unit
    CHECK (disease_sev IS NULL OR severity_unit IS NOT NULL),
  CONSTRAINT coords_both_or_neither
    CHECK ((latitude IS NULL) = (longitude IS NULL)),
  CONSTRAINT approved_has_approver
    CHECK (status <> 'approved' OR approving_person IS NOT NULL),
  CONSTRAINT no_self_approval
    CHECK (approving_person IS NULL OR approving_person <> submitting_person)
);

CREATE INDEX crop_loss_crop_idx     ON crop_loss (lower(crop));
CREATE INDEX crop_loss_pathogen_idx ON crop_loss (lower(pathogen));
CREATE INDEX crop_loss_group_idx    ON crop_loss (group_id);

-- ---------------------------------------------------------------------
-- crop_loss_meta: optional structured agronomic detail ("meta-data" tab).
-- Many meta rows may refer to one crop_loss row.
-- ---------------------------------------------------------------------
CREATE TABLE crop_loss_meta (
  meta_id                     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  crop_loss_id                bigint NOT NULL REFERENCES crop_loss (id) ON DELETE CASCADE,
  inoculation_type            text CHECK (inoculation_type IN ('inoculated', 'incidental')),
  sowing_date                 date,
  harvest_date                date,
  observation_date            date,
  agronomic_comments          text,
  insecticide_management      text,
  insecticide_management_date date,
  fungicide_management        text,
  fungicide_management_date   date,
  herbicide_management        text,
  herbicide_management_date   date,
  fertiliser_name             text,
  fertiliser_t_ha             numeric CHECK (fertiliser_t_ha >= 0),
  irrigation                  text,
  planting_density            text,
  row_spacing                 text,
  crop_hygiene                text,
  created_by                  text REFERENCES app_user (orcid),
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX crop_loss_meta_parent_idx ON crop_loss_meta (crop_loss_id);

-- ---------------------------------------------------------------------
-- Keep updated_at current
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

CREATE TRIGGER crop_loss_touch      BEFORE UPDATE ON crop_loss
  FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();
CREATE TRIGGER crop_loss_meta_touch BEFORE UPDATE ON crop_loss_meta
  FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();
