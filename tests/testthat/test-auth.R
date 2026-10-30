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

test_that("admin password must match exactly and be long enough", {
  pw <- "0123456789abcdef"
  expect_true(admin_password_matches(pw, password = pw, secret = "abc"))
  expect_false(admin_password_matches("0123456789abcdeX", password = pw, secret = "abc"))
  expect_false(admin_password_matches("", password = pw, secret = "abc"))
  expect_false(admin_password_matches(NULL, password = pw, secret = "abc"))
  expect_false(admin_password_matches("short", password = "short", secret = "abc"))
})

test_that("start-up check rejects a weak password or missing admin iD", {
  ok <- c(CROPLOSS_ADMIN_PASSWORD = "0123456789abcdef",
          CROPLOSS_ADMIN_ORCID = "0000-0002-1825-0097",
          CROPLOSS_STATE_SECRET = "abc")
  with_env <- function(vars, code) {
    old <- Sys.getenv(names(vars), unset = NA, names = TRUE)
    do.call(Sys.setenv, as.list(vars))
    on.exit({
      Sys.unsetenv(names(old)[is.na(old)])
      if (any(!is.na(old))) do.call(Sys.setenv, as.list(old[!is.na(old)]))
    })
    code
  }
  expect_true(with_env(ok, check_auth_config()))
  expect_error(with_env(replace(ok, 1, "change-me"), check_auth_config()), "16 characters")
  expect_error(with_env(replace(ok, 2, ""), check_auth_config()), "CROPLOSS_ADMIN_ORCID")
  expect_true(with_env(replace(ok, 1, ""), check_auth_config()))
})

test_that("admin sign-in signs in as the configured iD and stops after repeated failures", {
  vars <- c(CROPLOSS_ADMIN_PASSWORD = "0123456789abcdef",
            CROPLOSS_ADMIN_ORCID = "0000-0002-1825-0097",
            CROPLOSS_STATE_SECRET = "abc",
            ORCID_CLIENT_ID = "", ORCID_CLIENT_SECRET = "", CROPLOSS_DEV_AUTH = "")
  old <- Sys.getenv(names(vars), unset = NA, names = TRUE)
  do.call(Sys.setenv, as.list(vars))
  on.exit({
    Sys.unsetenv(names(old)[is.na(old)])
    if (any(!is.na(old))) do.call(Sys.setenv, as.list(old[!is.na(old)]))
  })
  local_mocked_bindings(
    upsert_user = function(pool, orcid, full_name = NULL) {
      list(orcid = orcid, full_name = NA_character_, role = "contributor")
    },
    client_address = function(session) "test"
  )
  server <- function(input, output, session) {
    user <- auth_server(input, output, session, pool = NULL)
  }

  shiny::testServer(server, {
    # No ORCID credentials: only the admin button is offered
    expect_false(grepl("Sign in with ORCID", output$auth_ui$html))
    expect_true(grepl("Admin sign-in", output$auth_ui$html))

    session$setInputs(admin_login = 1, admin_password = "wrong-password!!", admin_submit = 1)
    expect_null(user())
    session$setInputs(admin_password = "0123456789abcdef", admin_submit = 2)
    expect_identical(user()$orcid, "0000-0002-1825-0097")
  })

  shiny::testServer(server, {
    for (i in seq_len(admin_max_attempts)) {
      session$setInputs(admin_password = "wrong-password!!", admin_submit = i)
    }
    session$setInputs(admin_password = "0123456789abcdef", admin_submit = 99)
    expect_null(user())
  })
})
