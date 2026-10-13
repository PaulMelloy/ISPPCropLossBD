#' Create a connection pool to the crop loss database
#' @export
db_pool <- function() {
  pool::dbPool(
    RPostgres::Postgres(),
    host     = cfg("CROPLOSS_DB_HOST", "localhost"),
    port     = as.integer(cfg("CROPLOSS_DB_PORT", "5432")),
    dbname   = cfg("CROPLOSS_DB_NAME", "croploss"),
    user     = cfg("CROPLOSS_DB_USER", "croploss_app"),
    password = cfg("CROPLOSS_DB_PASSWORD"),
    bigint   = "integer"
  )
}

# Every write goes through here so the audit trigger knows who and why.
db_write <- function(pool, orcid, comment = NULL, fn) {
  pool::poolWithTransaction(pool, function(con) {
    DBI::dbGetQuery(con, "SELECT set_config('croploss.current_orcid', $1, true)",
                    params = list(orcid))
    DBI::dbGetQuery(con, "SELECT set_config('croploss.change_comment', $1, true)",
                    params = list(if (is_blank(comment)) "" else comment))
    fn(con)
  })
}

# Columns a user may set through the form. Everything else (id, status,
# yield_loss, timestamps, submitter, approver) is controlled by the system.
editable_cols <- c(
  "group_id", "crop", "pathogen", "pathogen_common_name", "agent_group",
  "year", "location", "latitude", "longitude",
  "disease_inc", "disease_inc_var", "disease_sev", "disease_sev_var", "severity_unit",
  "yield", "yield_var", "yield_attainable", "yield_attainable_var", "yield_loss_var",
  "measurement_method", "pub_ref", "meta_data", "search_string"
)

quote_cols <- function(cols) {
  as.character(DBI::dbQuoteIdentifier(DBI::ANSI(), cols))
}

# ---- users -------------------------------------------------------------

upsert_user <- function(pool, orcid, full_name = NULL) {
  res <- DBI::dbGetQuery(pool, "
    INSERT INTO app_user (orcid, full_name, last_login)
    VALUES ($1, $2, now())
    ON CONFLICT (orcid) DO UPDATE
      SET full_name  = coalesce(EXCLUDED.full_name, app_user.full_name),
          last_login = now()
    RETURNING orcid, full_name, role",
    params = list(orcid, if (is_blank(full_name)) NA_character_ else full_name))
  as.list(res[1, ])
}

# ---- lookups -----------------------------------------------------------

load_lookups <- function(pool) {
  get <- function(tbl) {
    d <- DBI::dbGetQuery(pool, sprintf("SELECT code, label FROM %s ORDER BY label", tbl))
    stats::setNames(d$code, d$label)
  }
  list(
    measurement_method = get("lkp_measurement_method"),
    severity_unit      = get("lkp_severity_unit"),
    agent_group        = get("lkp_agent_group")
  )
}

list_studies <- function(pool) {
  d <- DBI::dbGetQuery(pool, "SELECT group_id, title FROM study ORDER BY title")
  stats::setNames(as.character(d$group_id), d$title)
}

# ---- crop_loss ---------------------------------------------------------

list_crop_loss <- function(pool) {
  DBI::dbGetQuery(pool, "
    SELECT cl.id, cl.crop, cl.pathogen, cl.year, cl.location,
           cl.disease_inc, cl.yield, cl.yield_attainable, cl.yield_loss,
           cl.measurement_method, cl.status,
           cl.submitting_person, u.full_name AS submitter_name,
           (SELECT count(*) FROM crop_loss_audit a
             WHERE a.table_name = 'crop_loss' AND a.record_id = cl.id
               AND a.change_type = 'UPDATE') AS n_edits,
           cl.updated_at
      FROM crop_loss cl
      LEFT JOIN app_user u ON u.orcid = cl.submitting_person
     ORDER BY cl.id")
}

get_crop_loss <- function(pool, id) {
  d <- DBI::dbGetQuery(pool, "
    SELECT cl.*, s.full_name AS submitter_name, a.full_name AS approver_name
      FROM crop_loss cl
      LEFT JOIN app_user s ON s.orcid = cl.submitting_person
      LEFT JOIN app_user a ON a.orcid = cl.approving_person
     WHERE cl.id = $1", params = list(id))
  if (nrow(d) == 0) return(NULL)
  as.list(d[1, ])
}

insert_crop_loss <- function(pool, orcid, values, comment = NULL) {
  values <- values[intersect(names(values), editable_cols)]
  values$submitting_person <- orcid
  cols <- names(values)
  sql <- sprintf("INSERT INTO crop_loss (%s) VALUES (%s) RETURNING id",
                 paste(quote_cols(cols), collapse = ", "),
                 paste0("$", seq_along(cols), collapse = ", "))
  db_write(pool, orcid, comment, function(con) {
    DBI::dbGetQuery(con, sql, params = unname(values))$id
  })
}

update_crop_loss <- function(pool, orcid, id, values, comment = NULL) {
  values <- values[intersect(names(values), editable_cols)]
  cols <- names(values)
  sql <- sprintf("UPDATE crop_loss SET %s WHERE id = $%d",
                 paste(sprintf("%s = $%d", quote_cols(cols), seq_along(cols)),
                       collapse = ", "),
                 length(cols) + 1L)
  db_write(pool, orcid, comment, function(con) {
    DBI::dbExecute(con, sql, params = c(unname(values), list(id)))
  })
}

approve_crop_loss <- function(pool, orcid, id) {
  db_write(pool, orcid, "Approved", function(con) {
    DBI::dbExecute(con, "
      UPDATE crop_loss
         SET status = 'approved', approving_person = $1, approved_at = now()
       WHERE id = $2", params = list(orcid, id))
  })
}

get_history <- function(pool, id, table = "crop_loss") {
  DBI::dbGetQuery(pool, "
    SELECT a.audit_id, a.change_type, a.changed_at, a.changed_by_orcid,
           u.full_name, a.old_values::text AS old_values,
           a.new_values::text AS new_values, a.change_comment
      FROM crop_loss_audit a
      LEFT JOIN app_user u ON u.orcid = a.changed_by_orcid
     WHERE a.table_name = $1 AND a.record_id = $2
     ORDER BY a.changed_at DESC, a.audit_id DESC",
    params = list(table, id))
}

# ---- permissions (UI-level; see protocol for moving these into the DB) --

can_edit <- function(user, rec) {
  !is.null(user) && !is.null(rec) &&
    (identical(user$orcid, rec$submitting_person) ||
       user$role %in% c("curator", "admin"))
}

can_approve <- function(user, rec) {
  !is.null(user) && !is.null(rec) &&
    user$role %in% c("curator", "admin") &&
    identical(rec$status, "submitted") &&
    !identical(user$orcid, rec$submitting_person)
}
