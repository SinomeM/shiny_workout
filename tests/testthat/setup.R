# Tests run outside a package: source the app's R/ folder the way
# shiny::runApp() would.
library(shiny)
library(bslib)

for (f in list.files(testthat::test_path("..", "..", "app", "R"), pattern = "\\.R$", full.names = TRUE)) {
  source(f, local = FALSE)
}
