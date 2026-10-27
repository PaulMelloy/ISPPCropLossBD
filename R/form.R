# Shared input form used for both "Add entry" and "Edit" (modal).
entry_form_inputs <- function(ns, lookups, studies = character(), values = NULL,
                              edit = FALSE) {
  v <- function(f) {
    x <- values[[f]]
    if (is_blank(x)) NULL else x
  }
  txt <- function(id, label, ...) shiny::textInput(ns(id), label, value = v(id) %||% "", ...)
  num <- function(id, label, ...) shiny::numericInput(ns(id), label, value = v(id) %||% NA, ...)
  sel <- function(id, label, choices) {
    shiny::selectInput(ns(id), label, choices = c("(none)" = "", choices),
                       selected = as.character(v(id) %||% ""))
  }
  grid <- function(...) bslib::layout_column_wrap(width = 1 / 4, ...)

  shiny::tagList(
    shiny::h5("Host and agent"),
    grid(
      txt("crop", "Crop / commodity *", placeholder = "Wheat"),
      txt("pathogen", "Pathogen, taxonomic name *", placeholder = "Fusarium graminearum"),
      txt("pathogen_common_name", "Common name / description", placeholder = "Fusarium head blight"),
      sel("agent_group", "Agent group", lookups$agent_group)
    ),
    br(),
    br(),
    br(),
    shiny::h5("Where and when"),
    grid(
      num("year", "Year of observation *", min = 1800, step = 1),
      txt("location", "Location *", placeholder = "N\u00e9roux, Sainte-Lizaigne, France"),
      num("latitude", "Latitude (decimal)", step = 0.0001),
      num("longitude", "Longitude (decimal)", step = 0.0001)
    ),
    br(),
    br(),
    br(),
    shiny::h5("Disease"),
    grid(
      num("disease_inc", "Incidence (proportion 0-1)", min = 0, max = 1, step = 0.01),
      num("disease_inc_var", "Incidence variation", min = 0, step = 0.01),
      num("disease_sev", "Severity", step = 0.01),
      num("disease_sev_var", "Severity variation", min = 0, step = 0.01),
      br(),
      br(),
      sel("severity_unit", "Severity units", lookups$severity_unit)
    ),
    br(),
    br(),
    br(),
    shiny::h5("Yield (t/ha)"),
    grid(
      num("yield", "Observed yield *", min = 0, step = 0.01),
      num("yield_var", "Observed yield variation", min = 0, step = 0.01),
      num("yield_attainable", "Attainable yield *", min = 0, step = 0.01),
      num("yield_attainable_var", "Attainable yield variation", min = 0, step = 0.01),
      br(),
      br(),
      num("yield_loss_var", "Yield loss variation", min = 0, step = 0.01)
    ),
    br(),
    br(),
    br(),
    shiny::p(class = "text-muted small",
             "Yield loss is calculated automatically as attainable minus observed yield."),
    shiny::h5("Method and source"),
    grid(
      sel("measurement_method", "Measurement method *", lookups$measurement_method),
      sel("group_id", "Study / trial", studies),
      txt("pub_ref", "Publication (DOI or citation)")
    ),
    br(),
    shiny::textAreaInput(ns("search_string"), "Search string (if from a meta-analysis)",
                         value = v("search_string") %||% "", width = "100%", rows = 2),
    shiny::textAreaInput(ns("meta_data"), "Additional notes (cultivar, treatments, units...)",
                         value = v("meta_data") %||% "", width = "100%", rows = 3),
    if (edit) shiny::textInput(ns("change_comment"), "Reason for this change",
                               width = "100%", placeholder = "e.g. corrected yield after checking Table 2")
  )
}

read_form <- function(input) {
  txt <- function(id) {
    x <- input[[id]]
    if (is_blank(x)) NA_character_ else trimws(x)
  }
  num <- function(id) {
    x <- input[[id]]
    if (is_blank(x)) NA_real_ else as.numeric(x)
  }
  int <- function(id) {
    x <- input[[id]]
    if (is_blank(x)) NA_integer_ else as.integer(x)
  }
  list(
    crop = txt("crop"), pathogen = txt("pathogen"),
    pathogen_common_name = txt("pathogen_common_name"), agent_group = txt("agent_group"),
    year = int("year"), location = txt("location"),
    latitude = num("latitude"), longitude = num("longitude"),
    disease_inc = num("disease_inc"), disease_inc_var = num("disease_inc_var"),
    disease_sev = num("disease_sev"), disease_sev_var = num("disease_sev_var"),
    severity_unit = txt("severity_unit"),
    yield = num("yield"), yield_var = num("yield_var"),
    yield_attainable = num("yield_attainable"),
    yield_attainable_var = num("yield_attainable_var"),
    yield_loss_var = num("yield_loss_var"),
    measurement_method = txt("measurement_method"), group_id = int("group_id"),
    pub_ref = txt("pub_ref"), search_string = txt("search_string"),
    meta_data = txt("meta_data")
  )
}

notify_errors <- function(errs) {
  shiny::showNotification(shiny::HTML(paste(htmltools::htmlEscape(errs), collapse = "<br>")),
                          type = "error", duration = 8)
}

safe_db <- function(expr) {
  tryCatch(expr, error = function(e) {
    shiny::showNotification(paste("Database error:", conditionMessage(e)),
                            type = "error", duration = 10)
    NULL
  })
}
