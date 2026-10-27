# Run the app locally with the dev auth bypass.
# 1. Start Postgres (dev/docker-compose.yml) and run dev/setup_db.sh
# 2. Copy dev/Renviron.example to .Renviron and uncomment CROPLOSS_DEV_AUTH
# 3. source("dev/run_dev.R")

# Browser launch. Windows and macOS work out of the box. On Linux (and over
# SSH or in minimal sessions) R may have no browser set, which fails with
# "'browser' must be a non-empty character string". Set one by uncommenting
# a line, or in ~/.Rprofile:
#   Linux:   options(browser = "xdg-open")   # or "firefox", "chromium"
#   macOS:   options(browser = "open")       # only if the default fails
#   Windows: options(browser = "C:/Program Files/Mozilla Firefox/firefox.exe")
# Alternatively set launch.browser = FALSE below and open the URL by hand.
if (is.null(getOption("browser")) || !nzchar(getOption("browser"))) {
  if (Sys.info()[["sysname"]] == "Linux") options(browser = "xdg-open")
}

readRenviron(".Renviron")
pkgload::load_all(".")
shiny::runApp(run_app(), port = 3838, launch.browser = TRUE)
