library(shiny)
library(bslib)

# Modules and helpers in R/ are sourced automatically by shiny::runApp().

ui <- page_navbar(
  title = "shiny_workout",
  id = "nav",
  theme = bs_theme(version = 5),
  fillable = FALSE,
  header = tags$head(
    tags$link(rel = "stylesheet", href = "styles.css"),
    tags$script(src = "storage.js"),
    tags$script(src = "keys.js")
  ),
  nav_panel("Build", placeholder_card("Build", "Exercise catalog and workout editor (Phases 2-3).")),
  nav_panel("Library", placeholder_card("Library", "Saved and example workouts (Phase 4).")),
  nav_panel("Run", placeholder_card("Run", "Workout player (Phase 5).")),
  nav_panel("Diagnostics", diagnostics_ui("diag")),
  nav_spacer(),
  nav_item(input_dark_mode(id = "dark_mode"))
)

server <- function(input, output, session) {
  diagnostics_server("diag")
}

shinyApp(ui, server)
