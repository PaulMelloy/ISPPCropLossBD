# ORCID OAuth 2.0 (authorization code flow, scope /authenticate).
#
# 1. User clicks "Sign in with ORCID" -> browser goes to ORCID.
# 2. ORCID redirects back to ORCID_REDIRECT_URI with ?code=...&state=...
# 3. Server exchanges the code for a token; the token response contains the
#    user's ORCID iD and name, which is all we need for /authenticate.
#
# The `state` value is signed with CROPLOSS_STATE_SECRET and time-limited, so
# it can be verified after the redirect without server-side storage.

orcid_enabled <- function() {
  nzchar(Sys.getenv("ORCID_CLIENT_ID")) && nzchar(Sys.getenv("ORCID_CLIENT_SECRET"))
}

orcid_state_new <- function(secret = cfg("CROPLOSS_STATE_SECRET"),
                            now = Sys.time()) {
  ts <- as.character(as.integer(now))
  nonce <- paste(as.character(openssl::rand_bytes(8)), collapse = "")
  payload <- paste(ts, nonce, sep = ".")
  sig <- as.character(openssl::sha256(payload, key = secret))
  paste(payload, sig, sep = ".")
}

orcid_state_valid <- function(state, secret = cfg("CROPLOSS_STATE_SECRET"),
                              max_age = 600, now = Sys.time()) {
  if (is_blank(state)) return(FALSE)
  parts <- strsplit(state, ".", fixed = TRUE)[[1]]
  if (length(parts) != 3) return(FALSE)
  payload <- paste(parts[1:2], collapse = ".")
  expected <- as.character(openssl::sha256(payload, key = secret))
  age <- as.integer(now) - suppressWarnings(as.integer(parts[1]))
  identical(expected, parts[3]) && !is.na(age) && age >= 0 && age <= max_age
}

orcid_authorize_url <- function(state) {
  paste0(
    orcid_base(), "/oauth/authorize",
    "?client_id=",    utils::URLencode(cfg("ORCID_CLIENT_ID"), reserved = TRUE),
    "&response_type=code",
    "&scope=",        utils::URLencode("/authenticate", reserved = TRUE),
    "&redirect_uri=", utils::URLencode(cfg("ORCID_REDIRECT_URI"), reserved = TRUE),
    "&state=",        utils::URLencode(state, reserved = TRUE)
  )
}

orcid_exchange_code <- function(code) {
  resp <- httr2::request(paste0(orcid_base(), "/oauth/token")) |>
    httr2::req_headers(Accept = "application/json") |>
    httr2::req_body_form(
      client_id     = cfg("ORCID_CLIENT_ID"),
      client_secret = cfg("ORCID_CLIENT_SECRET"),
      grant_type    = "authorization_code",
      code          = code,
      redirect_uri  = cfg("ORCID_REDIRECT_URI")
    ) |>
    httr2::req_perform()
  body <- httr2::resp_body_json(resp)
  if (is.null(body$orcid)) stop("ORCID token response did not include an ORCID iD")
  list(orcid = body$orcid, name = body$name)
}

# Returns a reactiveVal holding list(orcid, full_name, role) or NULL.
auth_server <- function(input, output, session, pool) {
  user <- shiny::reactiveVal(NULL)

  # Development bypass: set CROPLOSS_DEV_AUTH to an ORCID iD to skip ORCID.
  # NEVER set this on a public server.
  dev_orcid <- Sys.getenv("CROPLOSS_DEV_AUTH", unset = "")
  if (nzchar(dev_orcid)) {
    user(upsert_user(pool, dev_orcid, "Development User"))
  }

  shiny::observeEvent(session$clientData$url_search, {
    q <- shiny::parseQueryString(session$clientData$url_search)
    if (is.null(q$code) || !is.null(user()) || !orcid_enabled()) return()
    shiny::updateQueryString("?", mode = "replace", session = session)

    if (!orcid_state_valid(q$state)) {
      shiny::showNotification("Sign-in failed: the login link expired. Please try again.",
                              type = "error", duration = 8)
      return()
    }
    info <- tryCatch(orcid_exchange_code(q$code), error = function(e) {
      shiny::showNotification(paste("Sign-in failed:", conditionMessage(e)),
                              type = "error", duration = 10)
      NULL
    })
    if (!is.null(info)) user(upsert_user(pool, info$orcid, info$name))
  }, once = TRUE)

  if (password_login_enabled()) admin_login_server(input, session, pool, user)

  output$auth_ui <- shiny::renderUI({
    u <- user()
    if (is.null(u)) {
      shiny::tagList(
        if (orcid_enabled()) {
          shiny::tags$a(href = orcid_authorize_url(orcid_state_new()),
                        class = "btn btn-success btn-sm",
                        "Sign in with ORCID")
        },
        if (password_login_enabled()) {
          shiny::actionButton("admin_login", "Admin sign-in",
                              class = "btn-outline-secondary btn-sm ms-2")
        }
      )
    } else {
      shiny::tagList(
        shiny::HTML(orcid_link(u$orcid, u$full_name)),
        shiny::tags$small(class = "text-muted ms-1", paste0("(", u$role, ")")),
        shiny::actionLink("logout", "Sign out", class = "ms-2")
      )
    }
  })

  shiny::observeEvent(input$logout, user(NULL))

  user
}
