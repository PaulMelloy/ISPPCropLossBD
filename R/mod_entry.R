mod_entry_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::uiOutput(ns("form_ui"))
}

mod_entry_server <- function(id, pool, user, refresh, lookups) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    output$form_ui <- shiny::renderUI({
      refresh()   # re-render (clear form) after each successful submission
      if (is.null(user())) {
        return(bslib::card(bslib::card_body(
          "Please sign in with ORCID to add observations."
        )))
      }
      bslib::card(
        fill = FALSE,
        bslib::card_header("New crop loss observation"),
        bslib::card_body(
          fillable = FALSE,
          entry_form_inputs(ns, lookups, studies = list_studies(pool)),
          shiny::actionButton(ns("submit"), "Submit observation", class = "btn-primary")
        )
      )
    })

    shiny::observeEvent(input$submit, {
      shiny::req(user())
      vals <- read_form(input)
      errs <- validate_entry(vals)
      if (length(errs)) return(notify_errors(errs))

      new_id <- safe_db(insert_crop_loss(pool, user()$orcid, vals,
                                         comment = "New observation"))
      if (!is.null(new_id)) {
        shiny::showNotification(sprintf("Observation %s submitted.", new_id),
                                type = "message")
        refresh(refresh() + 1)
      }
    })
  })
}
