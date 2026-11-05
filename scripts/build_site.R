# Build the static site: run tests, then export the Shinylive app to _site/.
# Usage (from the project root): Rscript scripts/build_site.R [--serve]

args <- commandArgs(trailingOnly = TRUE)

Sys.setenv(NOT_CRAN = "true")  # run snapshot tests
testthat::test_dir("tests/testthat", stop_on_failure = TRUE)

unlink("_site", recursive = TRUE)
# Page title, icon and a loading screen around the Shinylive app (see scripts/site/).
read_part <- function(name) paste(readLines(file.path("scripts/site", name), warn = FALSE), collapse = "\n")
shinylive::export("app", "_site", template_params = list(
  title = "shiny_workout",
  include_in_head = read_part("head.html"),
  include_before_body = read_part("loading.html")
))

if ("--serve" %in% args) {
  httpuv::runStaticServer("_site", port = 8008, browse = FALSE)
}
