-- =====================================================================
-- Audit trail (version control).
-- Every INSERT / UPDATE / DELETE on crop_loss and crop_loss_meta is logged
-- by trigger. The application never writes to this table directly.
--
-- Who made the change: the app runs each write in a transaction and first
-- calls  set_config('croploss.current_orcid', '<orcid>', true)
-- (and optionally 'croploss.change_comment'). The trigger reads these.
-- Writes from the app login role WITHOUT an ORCID are rejected.
-- =====================================================================
SET search_path TO croploss, public;

CREATE TABLE crop_loss_audit (
  audit_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_name        text NOT NULL,
  record_id         bigint NOT NULL,
  change_type       text NOT NULL CHECK (change_type IN ('INSERT', 'UPDATE', 'DELETE')),
  changed_by_orcid  text,
  changed_at        timestamptz NOT NULL DEFAULT now(),
  old_values        jsonb,   -- UPDATE: only fields that changed; DELETE: whole row
  new_values        jsonb,   -- INSERT: whole row; UPDATE: only fields that changed
  row_snapshot      jsonb,   -- full row as it was BEFORE the change (enables revert)
  change_comment    text
);

CREATE INDEX crop_loss_audit_record_idx
  ON crop_loss_audit (table_name, record_id, changed_at DESC);
CREATE INDEX crop_loss_audit_user_idx
  ON crop_loss_audit (changed_by_orcid);

-- TG_ARGV[0] = name of the primary-key column of the audited table
CREATE OR REPLACE FUNCTION fn_audit() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = croploss, pg_temp
AS $$
DECLARE
  v_old      jsonb;
  v_new      jsonb;
  v_old_diff jsonb;
  v_new_diff jsonb;
  v_id       bigint;
  v_orcid    text := nullif(current_setting('croploss.current_orcid', true), '');
  v_comment  text := nullif(current_setting('croploss.change_comment', true), '');
BEGIN
  IF v_orcid IS NULL AND session_user = 'croploss_app' THEN
    RAISE EXCEPTION 'Audit: writes from the application must set croploss.current_orcid';
  END IF;

  IF TG_OP = 'INSERT' THEN
    v_new := to_jsonb(NEW);
    v_id  := (v_new ->> TG_ARGV[0])::bigint;
    INSERT INTO crop_loss_audit
      (table_name, record_id, change_type, changed_by_orcid, new_values, change_comment)
    VALUES (TG_TABLE_NAME, v_id, TG_OP, v_orcid, v_new, v_comment);
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    v_id  := (v_new ->> TG_ARGV[0])::bigint;

    SELECT jsonb_object_agg(o.key, o.value),
           jsonb_object_agg(o.key, v_new -> o.key)
      INTO v_old_diff, v_new_diff
      FROM jsonb_each(v_old) AS o
     WHERE o.key <> 'updated_at'
       AND (v_new -> o.key) IS DISTINCT FROM o.value;

    IF v_old_diff IS NULL THEN      -- nothing meaningful changed
      RETURN NEW;
    END IF;

    INSERT INTO crop_loss_audit
      (table_name, record_id, change_type, changed_by_orcid,
       old_values, new_values, row_snapshot, change_comment)
    VALUES (TG_TABLE_NAME, v_id, TG_OP, v_orcid,
            v_old_diff, v_new_diff, v_old, v_comment);
    RETURN NEW;

  ELSE -- DELETE
    v_old := to_jsonb(OLD);
    v_id  := (v_old ->> TG_ARGV[0])::bigint;
    INSERT INTO crop_loss_audit
      (table_name, record_id, change_type, changed_by_orcid,
       old_values, row_snapshot, change_comment)
    VALUES (TG_TABLE_NAME, v_id, TG_OP, v_orcid, v_old, v_old, v_comment);
    RETURN OLD;
  END IF;
END $$;

CREATE TRIGGER crop_loss_audit_trg
  AFTER INSERT OR UPDATE OR DELETE ON crop_loss
  FOR EACH ROW EXECUTE FUNCTION fn_audit('id');

CREATE TRIGGER crop_loss_meta_audit_trg
  AFTER INSERT OR UPDATE OR DELETE ON crop_loss_meta
  FOR EACH ROW EXECUTE FUNCTION fn_audit('meta_id');
