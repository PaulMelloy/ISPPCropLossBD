app_ui <- function(request) {
  bslib::page_navbar(
    title = "Crop Loss Database (prototype)",
    theme = bslib::bs_theme(version = 5, preset = "flatly"),
    bslib::nav_panel("Browse", mod_browse_ui("browse")),
    bslib::nav_panel("Add observation", mod_entry_ui("entry")),
    bslib::nav_panel("About", about_ui()),
    bslib::nav_spacer(),
    bslib::nav_item(shiny::uiOutput("auth_ui"))
  )
}

app_server <- function(pool) {
  function(input, output, session) {
    user    <- auth_server(input, output, session, pool)
    refresh <- shiny::reactiveVal(0)
    lookups <- load_lookups(pool)

    mod_browse_server("browse", pool, user, refresh, lookups)
    mod_entry_server("entry", pool, user, refresh, lookups)
  }
}

about_ui <- function() {
  bslib::card(bslib::card_body(
    shiny::h4("About this prototype"),
    shiny::p("A collaborative database of crop loss observations for the
              International Society for Plant Pathology Crop Loss Subcommittee."),
    shiny::p("Contributors sign in with ORCID. Every submission and edit is recorded,
              with who made it, when, and what changed, and is visible from each
              observation's change history."),
    shiny::p(class = "text-muted",
             "This is a prototype for discussion. Data entered here may be reset.")
  ))
}
