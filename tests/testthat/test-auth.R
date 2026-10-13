test_that("signed state round-trips and expires", {
  s <- orcid_state_new(secret = "abc", now = as.POSIXct(1e9))
  expect_true(orcid_state_valid(s, secret = "abc", now = as.POSIXct(1e9 + 60)))
  expect_false(orcid_state_valid(s, secret = "wrong", now = as.POSIXct(1e9 + 60)))
  expect_false(orcid_state_valid(s, secret = "abc", now = as.POSIXct(1e9 + 3600)))
})

test_that("tampered or malformed state is rejected", {
  s <- orcid_state_new(secret = "abc")
  expect_false(orcid_state_valid(paste0(s, "x"), secret = "abc"))
  expect_false(orcid_state_valid("not-a-state", secret = "abc"))
  expect_false(orcid_state_valid(NULL, secret = "abc"))
})
