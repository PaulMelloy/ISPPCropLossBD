`%||%` <- function(x, y) if (is.null(x)) y else x

is_blank <- function(x) {
  is.null(x) || length(x) == 0 || all(is.na(x)) ||
    (is.character(x) && !nzchar(trimws(x[1])))
}

# Read a required/optional setting from environment variables
cfg <- function(name, default = NULL) {
  val <- Sys.getenv(name, unset = "")
  if (nzchar(val)) return(val)
  if (!is.null(default)) return(default)
  stop("Missing required environment variable: ", name, call. = FALSE)
}

orcid_base <- function() {
  if (identical(cfg("ORCID_ENV", "sandbox"), "production")) {
    "https://orcid.org"
  } else {
    "https://sandbox.orcid.org"
  }
}

# HTML link to an ORCID profile; name is escaped because it comes from ORCID
orcid_link <- function(orcid, name = NULL) {
  if (is_blank(orcid)) return("system")
  label <- if (is_blank(name)) orcid else name
  sprintf('<a href="%s/%s" target="_blank" rel="noopener">%s</a>',
          orcid_base(), orcid, htmltools::htmlEscape(label))
}
