# Production image for the Shiny app. Build context is the repo root:
#   docker compose -f deploy/docker-compose.yml build
FROM rocker/r-ver:4.4.2

# Runtime/build libraries for RPostgres, openssl and httr2 (curl)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libpq-dev libssl-dev libcurl4-openssl-dev libxml2-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Dependencies first, so this slow layer is cached until DESCRIPTION changes
COPY DESCRIPTION ./
RUN Rscript -e 'install.packages("remotes"); \
      remotes::install_deps(".", dependencies = c("Depends", "Imports"), upgrade = "never")'

COPY . .
RUN R CMD INSTALL --no-docs . && rm -rf /build

RUN useradd --create-home --shell /usr/sbin/nologin app
USER app
WORKDIR /home/app

EXPOSE 3838
# All configuration arrives as environment variables (see deploy/.env.example)
CMD ["Rscript", "-e", "shiny::runApp(ISPPCropLossDB::run_app(), host = '0.0.0.0', port = 3838)"]
