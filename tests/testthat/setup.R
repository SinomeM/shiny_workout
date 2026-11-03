# Tests run outside a package: source the app's R/ folder the way
# shiny::runApp() would.
library(shiny)
library(bslib)
testthat::local_edition(3, .env = testthat::teardown_env())

for (f in list.files(testthat::test_path("..", "..", "app", "R"), pattern = "\\.R$", full.names = TRUE)) {
  source(f, local = FALSE)
}

app_path <- function(...) testthat::test_path("..", "..", "app", ...)
app_defaults <- read_app_config(app_path("config.yml"))$defaults
