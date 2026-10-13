\name{run_app}
\alias{run_app}
\title{Run the crop loss database app}
\usage{
run_app(...)
}
\arguments{
\item{...}{Passed to \code{shiny::shinyApp()}.}
}
\description{
Starts the Shiny application. Database and ORCID settings are read from
environment variables; see \code{dev/Renviron.example} in the source package.
}
