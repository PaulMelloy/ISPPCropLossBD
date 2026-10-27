#!/usr/bin/env bash
# Install everything needed before running the app:
#   1. Linux system libraries and tools (needs sudo; skip with --skip-system)
#   2. R packages, into ./r-lib inside the repo (not your global library)
#
# Usage: ./packages_dependancies.sh [--skip-system]
#
# R package names are read from DESCRIPTION (Imports + Suggests), plus
# pkgload, which dev/run_dev.R uses. Add new dependencies to DESCRIPTION
# and re-run this script.
set -euo pipefail
cd "$(dirname "$0")"

# ---- 1. System libraries ------------------------------------------------
# libpq        -> RPostgres        libssl   -> openssl
# libcurl      -> curl (via httr2) psql     -> dev/setup_db.sh
# docker       -> dev/docker-compose.yml (Postgres)
# compilers    -> building R packages from source
if [[ "${1:-}" != "--skip-system" ]]; then
  if command -v pacman >/dev/null; then            # Arch / Omarchy
    sudo pacman -S --needed base-devel r gcc-fortran postgresql-libs postgresql \
      openssl curl libxml2 docker docker-compose
  elif command -v apt-get >/dev/null; then         # Debian / Ubuntu
    sudo apt-get update
    sudo apt-get install -y build-essential r-base r-base-dev libpq-dev \
      postgresql-client libssl-dev libcurl4-openssl-dev libxml2-dev \
      docker.io docker-compose-v2
  elif command -v dnf >/dev/null; then             # Fedora / RHEL
    sudo dnf install -y gcc gcc-c++ gcc-gfortran make R libpq-devel postgresql \
      openssl-devel libcurl-devel libxml2-devel docker docker-compose
  else
    echo "Unknown package manager. Install manually: a C/C++/Fortran toolchain," >&2
    echo "R (>= 4.1), libpq + headers, psql, OpenSSL + headers, libcurl + headers, Docker." >&2
    exit 1
  fi
fi

# ---- 2. R packages into ./r-lib ----------------------------------------
mkdir -p r-lib
R_LIBS="$PWD/r-lib" Rscript - <<'EOF'
lib <- Sys.getenv("R_LIBS")
d <- read.dcf("DESCRIPTION", fields = c("Imports", "Suggests"))
pkgs <- unlist(strsplit(d[!is.na(d)], ","))
pkgs <- trimws(sub("\\(.*\\)", "", pkgs))
pkgs <- unique(c(pkgs[nzchar(pkgs)], "pkgload"))
missing <- setdiff(pkgs, rownames(installed.packages(lib.loc = lib)))
if (length(missing)) {
  install.packages(missing, lib = lib, repos = "https://cloud.r-project.org")
}
still <- setdiff(pkgs, rownames(installed.packages(lib.loc = lib)))
if (length(still)) stop("Failed to install: ", paste(still, collapse = ", "))
cat("R packages installed in", lib, ":", paste(pkgs, collapse = ", "), "\n")
EOF
