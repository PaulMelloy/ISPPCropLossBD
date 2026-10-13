test_that("history diff expands updates into one row per field", {
  h <- data.frame(
    audit_id = 2:1,
    change_type = c("UPDATE", "INSERT"),
    changed_at = as.POSIXct(c("2026-10-14 10:30", "2026-10-13 09:00"), tz = "UTC"),
    changed_by_orcid = "0000-0002-1825-0097",
    full_name = "Example Contributor",
    old_values = c('{"yield": 2.5, "yield_loss": 0.6}', NA),
    new_values = c('{"yield": 2.7, "yield_loss": 0.4}', '{"id": 1}'),
    change_comment = c("fix yield", NA),
    stringsAsFactors = FALSE
  )
  d <- history_diff_table(h)
  expect_equal(nrow(d), 3)
  expect_equal(d$field[1:2], c("yield", "yield_loss"))
  expect_equal(d$old[1], "2.5")
  expect_equal(d$new[1], "2.7")
  expect_equal(d$action[3], "Created")
})

test_that("ORCID names are HTML-escaped", {
  link <- orcid_link("0000-0002-1825-0097", "<script>x</script>")
  expect_false(grepl("<script>", link, fixed = TRUE))
})
