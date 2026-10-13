# Run the app locally with the dev auth bypass.
# 1. Start Postgres (dev/docker-compose.yml) and run dev/setup_db.sh
# 2. Copy dev/Renviron.example to .Renviron and uncomment CROPLOSS_DEV_AUTH
# 3. source("dev/run_dev.R")
readRenviron(".Renviron")
pkgload::load_all(".")
shiny::runApp(run_app(), port = 3838, launch.browser = TRUE)
