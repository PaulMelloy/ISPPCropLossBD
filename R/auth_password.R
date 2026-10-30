# Admin password sign-in, for running the app before ORCID is registered.
#
# It signs in as CROPLOSS_ADMIN_ORCID, so records and audit entries made this
# way belong to that iD and stay linked to it once ORCID sign-in is turned on.
# Leave CROPLOSS_ADMIN_PASSWORD empty to turn it off.
#
# The attempt and the password are compared as HMACs keyed with
# CROPLOSS_STATE_SECRET, so the comparison time reveals nothing about the
# password. There is no lockout across sessions, so the password must be long
# and random; check_auth_config() refuses to start with a short one.

admin_password_min_chars <- 16
admin_max_attempts <- 5

password_login_enabled <- function() {
  nzchar(Sys.getenv("CROPLOSS_ADMIN_PASSWORD"))
}

admin_password_matches <- function(attempt,
                                   password = cfg("CROPLOSS_ADMIN_PASSWORD"),
                                   secret = cfg("CROPLOSS_STATE_SECRET")) {
  if (is_blank(attempt) || nchar(password) < admin_password_min_chars) return(FALSE)
  mac <- function(x) as.character(openssl::sha256(x, key = secret))
  identical(mac(attempt), mac(password))
}

# Stops the app at start-up with a clear message rather than failing at sign-in
check_auth_config <- function() {
  if (!password_login_enabled()) return(invisible(TRUE))
  if (nchar(cfg("CROPLOSS_ADMIN_PASSWORD")) < admin_password_min_chars) {
    stop("CROPLOSS_ADMIN_PASSWORD must be at least ", admin_password_min_chars,
         " characters (openssl rand -hex 16)", call. = FALSE)
  }
  if (!grepl("^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$",
             Sys.getenv("CROPLOSS_ADMIN_ORCID"))) {
    stop("CROPLOSS_ADMIN_ORCID must be your ORCID iD (0000-0000-0000-000X) ",
         "when CROPLOSS_ADMIN_PASSWORD is set", call. = FALSE)
  }
  cfg("CROPLOSS_STATE_SECRET")
  invisible(TRUE)
}

# For the log lines; Caddy passes the browser's address in X-Forwarded-For
client_address <- function(session) {
  session$request$HTTP_X_FORWARDED_FOR %||% session$request$REMOTE_ADDR
}

# Adds the "Admin sign-in" dialog to auth_server(); signs in through `user`.
admin_login_server <- function(input, session, pool, user) {
  failures <- 0

  shiny::observeEvent(input$admin_login, {
    shiny::showModal(shiny::modalDialog(
      title = "Admin sign-in",
      shiny::passwordInput("admin_password", "Password"),
      footer = shiny::tagList(
        shiny::modalButton("Cancel"),
        shiny::actionButton("admin_submit", "Sign in", class = "btn-primary")
      ),
      easyClose = TRUE
    ))
  })

  shiny::observeEvent(input$admin_submit, {
    client <- client_address(session)
    if (failures >= admin_max_attempts) {
      shiny::showNotification("Too many failed attempts.", type = "error")
      return()
    }
    if (!admin_password_matches(input$admin_password)) {
      failures <<- failures + 1
      message("Admin sign-in failed from ", client)
      shiny::showNotification("Incorrect password.", type = "error")
      return()
    }
    shiny::removeModal()
    message("Admin sign-in succeeded from ", client)
    user(upsert_user(pool, cfg("CROPLOSS_ADMIN_ORCID")))
  })
}
