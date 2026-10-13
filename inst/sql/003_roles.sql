-- =====================================================================
-- Application login role with least privilege.
-- Run with:  psql -v app_password='...' -f 003_roles.sql
-- The app can read everything, insert/update data, but cannot DELETE
-- (entries are withdrawn via status), cannot touch the audit table,
-- and cannot change anyone's role.
-- =====================================================================
SET search_path TO croploss, public;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'croploss_app') THEN
    CREATE ROLE croploss_app LOGIN;
  END IF;
END $$;

ALTER ROLE croploss_app PASSWORD :'app_password';
ALTER ROLE croploss_app SET search_path = croploss, public;

GRANT USAGE ON SCHEMA croploss TO croploss_app;
GRANT SELECT ON ALL TABLES IN SCHEMA croploss TO croploss_app;

GRANT INSERT, UPDATE ON crop_loss, crop_loss_meta, study TO croploss_app;
GRANT INSERT ON app_user TO croploss_app;
GRANT UPDATE (full_name, email, affiliation, last_login) ON app_user TO croploss_app;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA croploss TO croploss_app;

-- The audit table is written only by the SECURITY DEFINER trigger.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON crop_loss_audit FROM croploss_app;
