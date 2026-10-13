mod_browse_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    col_widths = c(7, 5),
    bslib::card(full_screen = TRUE,
                bslib::card_header("Observations"),
                DT::DTOutput(ns("table"))),
    bslib::card(bslib::card_header("Selected observation"),
                shiny::uiOutput(ns("detail")))
  )
}

display_cols <- c("id", "crop", "pathogen", "year", "location", "disease_inc",
                  "yield", "yield_attainable", "yield_loss", "status", "n_edits")

record_detail_ui <- function(rec) {
  row <- function(label, value) {
    if (is_blank(value)) return(NULL)
    shiny::tags$tr(shiny::tags$th(label), shiny::tags$td(shiny::HTML(as.character(value))))
  }
  esc <- function(x) if (is_blank(x)) NULL else htmltools::htmlEscape(as.character(x))
  coords <- if (!is_blank(rec$latitude)) sprintf("%s, %s", rec$latitude, rec$longitude)
  shiny::tags$table(
    class = "table table-sm",
    row("Crop", esc(rec$crop)),
    row("Agent", shiny::tags$em(rec$pathogen)),
    row("Common name", esc(rec$pathogen_common_name)),
    row("Year", rec$year),
    row("Location", esc(rec$location)),
    row("Coordinates", coords),
    row("Incidence", rec$disease_inc),
    row("Severity", if (!is_blank(rec$disease_sev))
      paste(rec$disease_sev, esc(rec$severity_unit))),
    row("Observed yield (t/ha)", rec$yield),
    row("Attainable yield (t/ha)", rec$yield_attainable),
    row("Yield loss (t/ha)", rec$yield_loss),
    row("Method", esc(rec$measurement_method)),
    row("Reference", esc(rec$pub_ref)),
    row("Notes", esc(rec$meta_data)),
    row("Status", rec$status),
    row("Submitted by", orcid_link(rec$submitting_person, rec$submitter_name)),
    row("Approved by", if (!is_blank(rec$approving_person))
      orcid_link(rec$approving_person, rec$approver_name))
  )
}

mod_browse_server <- function(id, pool, user, refresh, lookups) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    sel_id <- shiny::reactiveVal(NULL)

    data <- shiny::reactive({
      refresh()
      list_crop_loss(pool)
    })

    output$table <- DT::renderDT({
      d <- data()
      keep <- shiny::isolate(sel_id())
      pre <- if (!is.null(keep)) which(d$id == keep) else NULL
      DT::datatable(d[, display_cols, drop = FALSE], rownames = FALSE,
                    filter = "top",
                    selection = list(mode = "single", selected = pre),
                    options = list(pageLength = 15, scrollX = TRUE))
    })

    shiny::observeEvent(input$table_rows_selected, {
      i <- input$table_rows_selected
      sel_id(if (length(i)) data()$id[i] else NULL)
    }, ignoreNULL = FALSE)

    record <- shiny::reactive({
      refresh()
      if (is.null(sel_id())) NULL else get_crop_loss(pool, sel_id())
    })

    history <- shiny::reactive({
      refresh()
      if (is.null(sel_id())) NULL else get_history(pool, sel_id())
    })

    output$detail <- shiny::renderUI({
      rec <- record()
      if (is.null(rec)) return(shiny::p(class = "text-muted", "Select a row to see details."))
      u <- user()
      shiny::tagList(
        record_detail_ui(rec),
        shiny::hr(),
        history_summary_ui(history()),
        shiny::div(
          class = "d-flex gap-2",
          shiny::actionButton(ns("show_history"), "Full change history",
                              class = "btn-outline-secondary btn-sm"),
          if (can_edit(u, rec)) shiny::actionButton(ns("edit"), "Edit",
                                                    class = "btn-outline-primary btn-sm"),
          if (can_approve(u, rec)) shiny::actionButton(ns("approve"), "Approve",
                                                       class = "btn-success btn-sm")
        )
      )
    })

    # ---- full history ----
    output$history_table <- DT::renderDT({
      d <- history_diff_table(history())
      DT::datatable(d, rownames = FALSE, escape = -which(names(d) == "who"),
                    options = list(pageLength = 25, dom = "tp"))
    })

    shiny::observeEvent(input$show_history, {
      shiny::showModal(shiny::modalDialog(
        title = sprintf("Change history: observation %s", sel_id()),
        DT::DTOutput(ns("history_table")),
        size = "xl", easyClose = TRUE
      ))
    })

    # ---- edit ----
    shiny::observeEvent(input$edit, {
      rec <- record()
      shiny::req(can_edit(user(), rec))
      shiny::showModal(shiny::modalDialog(
        title = sprintf("Edit observation %s", rec$id),
        entry_form_inputs(ns, lookups, studies = list_studies(pool),
                          values = rec, edit = TRUE),
        size = "xl",
        footer = shiny::tagList(
          shiny::modalButton("Cancel"),
          shiny::actionButton(ns("save_edit"), "Save changes", class = "btn-primary")
        )
      ))
    })

    shiny::observeEvent(input$save_edit, {
      rec <- record()
      shiny::req(can_edit(user(), rec))
      vals <- read_form(input)
      errs <- validate_entry(vals)
      if (length(errs)) return(notify_errors(errs))

      ok <- safe_db(update_crop_loss(pool, user()$orcid, rec$id, vals,
                                     comment = input$change_comment))
      if (!is.null(ok)) {
        shiny::removeModal()
        shiny::showNotification("Changes saved.", type = "message")
        refresh(refresh() + 1)
      }
    })

    # ---- approve ----
    shiny::observeEvent(input$approve, {
      rec <- record()
      shiny::req(can_approve(user(), rec))
      ok <- safe_db(approve_crop_loss(pool, user()$orcid, rec$id))
      if (!is.null(ok)) refresh(refresh() + 1)
    })
  })
}
