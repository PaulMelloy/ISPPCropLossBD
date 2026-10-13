good <- list(crop = "Wheat", pathogen = "Fusarium sp.", year = 2022L,
             location = "N\u00e9roux, France", yield = 2.5, yield_attainable = 3.1,
             measurement_method = "harvested_plot")

test_that("a complete minimal entry is valid", {
  expect_length(validate_entry(good), 0)
})

test_that("missing required fields are reported", {
  bad <- good
  bad$crop <- NA_character_
  bad$yield <- NA_real_
  errs <- validate_entry(bad)
  expect_true(any(grepl("Crop", errs)))
  expect_true(any(grepl("Observed yield", errs)))
})

test_that("incidence must be a proportion", {
  bad <- good
  bad$disease_inc <- 26
  expect_true(any(grepl("incidence", validate_entry(bad), ignore.case = TRUE)))
})

test_that("severity needs units", {
  bad <- good
  bad$disease_sev <- 12
  expect_true(any(grepl("Severity units", validate_entry(bad))))
  bad$severity_unit <- "percent"
  expect_length(validate_entry(bad), 0)
})

test_that("coordinates come in pairs", {
  bad <- good
  bad$latitude <- 46.9
  expect_true(any(grepl("latitude and longitude", validate_entry(bad))))
})

test_that("future years are rejected", {
  bad <- good
  bad$year <- 2099L
  expect_true(any(grepl("Year", validate_entry(bad, current_year = 2026L))))
})
