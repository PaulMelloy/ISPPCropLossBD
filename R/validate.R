# Returns a character vector of problems; length 0 means valid.
# The database enforces the same rules; this just gives friendlier messages.
validate_entry <- function(v, current_year = as.integer(format(Sys.Date(), "%Y"))) {
  errs <- character()

  required <- c(
    crop = "Crop", pathogen = "Pathogen (taxonomic name)", year = "Year",
    location = "Location", yield = "Observed yield",
    yield_attainable = "Attainable yield", measurement_method = "Measurement method"
  )
  for (f in names(required)) {
    if (is_blank(v[[f]])) errs <- c(errs, paste0(required[[f]], " is required."))
  }

  check_range <- function(f, lo, hi, label) {
    x <- v[[f]]
    if (!is_blank(x) && (x < lo || x > hi)) {
      errs <<- c(errs, sprintf("%s must be between %s and %s.", label, lo, hi))
    }
  }
  check_range("year", 1800, current_year, "Year")
  check_range("disease_inc", 0, 1, "Disease incidence")
  check_range("latitude", -90, 90, "Latitude")
  check_range("longitude", -180, 180, "Longitude")

  non_negative <- c("yield", "yield_var", "yield_attainable", "yield_attainable_var",
                    "yield_loss_var", "disease_inc_var", "disease_sev_var")
  for (f in non_negative) {
    x <- v[[f]]
    if (!is_blank(x) && x < 0) errs <- c(errs, paste0(f, " cannot be negative."))
  }

  if (!is_blank(v$disease_sev) && is_blank(v$severity_unit)) {
    errs <- c(errs, "Severity units are required when disease severity is given.")
  }
  if (xor(is_blank(v$latitude), is_blank(v$longitude))) {
    errs <- c(errs, "Provide both latitude and longitude, or neither.")
  }
  errs
}
