-- =====================================================================
-- Seed vocabularies + one example row from the committee Google Sheet.
-- Vocabularies are a STARTING POINT for committee discussion.
-- =====================================================================
SET search_path TO croploss, public;

INSERT INTO lkp_measurement_method (code, label, description) VALUES
  ('harvested_plot',  'Harvested plot (paired / treated vs untreated)', 'Yield measured by harvesting plots with and without the agent or its control'),
  ('field_survey',    'Field survey',                 'Farm or field survey of yield and disease'),
  ('remote_sensing',  'Remote sensing',               'Satellite, aerial or UAV derived estimates'),
  ('model',           'Modelled / simulated',         'Crop or damage model estimate'),
  ('expert_estimate', 'Expert estimate',              'Expert elicitation or extension estimate'),
  ('other',           'Other (describe in meta_data)', NULL)
ON CONFLICT (code) DO NOTHING;

INSERT INTO lkp_severity_unit (code, label, description) VALUES
  ('proportion',   'Proportion (0-1)',     'Proportion of tissue affected'),
  ('percent',      'Percent (0-100)',      'Percent of tissue affected'),
  ('ordinal_0_5',  'Ordinal scale 0-5',    NULL),
  ('ordinal_1_9',  'Ordinal scale 1-9',    NULL),
  ('other',        'Other (describe in meta_data)', NULL)
ON CONFLICT (code) DO NOTHING;

INSERT INTO lkp_agent_group (code, label) VALUES
  ('pathogen_fungus',    'Pathogen: fungus'),
  ('pathogen_oomycete',  'Pathogen: oomycete'),
  ('pathogen_bacterium', 'Pathogen: bacterium'),
  ('pathogen_virus',     'Pathogen: virus'),
  ('pathogen_nematode',  'Pathogen: nematode'),
  ('insect',             'Insect / mite'),
  ('weed',               'Weed'),
  ('other',              'Other')
ON CONFLICT (code) DO NOTHING;

-- Example contributor (ORCID's documented test iD; replace with real users)
INSERT INTO app_user (orcid, full_name, role)
VALUES ('0000-0002-1825-0097', 'Example Contributor', 'contributor')
ON CONFLICT (orcid) DO NOTHING;

BEGIN;
SELECT set_config('croploss.current_orcid', '0000-0002-1825-0097', true);
SELECT set_config('croploss.change_comment', 'Seed example from committee Google Sheet', true);

INSERT INTO crop_loss
  (crop, pathogen, agent_group, year, location,
   disease_inc, disease_inc_var,
   yield, yield_var, yield_attainable, yield_attainable_var,
   measurement_method, submitting_person)
VALUES
  ('Wheat', 'Fusarium sp.', 'pathogen_fungus', 2022, 'Néroux, Sainte-Lizaigne, France',
   0.26, 0.06,
   2.5, 0.7, 3.1, 0.5,
   'harvested_plot', '0000-0002-1825-0097');
COMMIT;
