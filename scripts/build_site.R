# Build the static site: run tests, then export the Shinylive app to _site/.
# Usage (from the project root): Rscript scripts/build_site.R [--serve]

args <- commandArgs(trailingOnly = TRUE)

Sys.setenv(NOT_CRAN = "true")  # run snapshot tests
testthat::test_dir("tests/testthat", stop_on_failure = TRUE)

unlink("_site", recursive = TRUE)
shinylive::export("app", "_site")

if ("--serve" %in% args) {
  httpuv::runStaticServer("_site", port = 8008, browse = FALSE)
}
