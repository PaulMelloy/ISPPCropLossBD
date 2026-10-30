#' Run the crop loss database app
#'
#' Connection and ORCID settings are read from environment variables;
#' see `dev/.Renviron.example`.
#'
#' @param ... Passed to [shiny::shinyApp()].
#' @export
run_app <- function(...) {
  check_auth_config()
  pool <- db_pool()
  shiny::shinyApp(
    ui = app_ui,
    server = app_server(pool),
    onStart = function() {
      shiny::onStop(function() pool::poolClose(pool))
    },
    ...
  )
}
