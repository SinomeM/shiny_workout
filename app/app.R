library(shiny)
library(bslib)

# Modules and helpers in R/ are sourced automatically by shiny::runApp().

config <- read_app_config("config.yml")
catalog <- load_catalog("data/exercises.json", config)

ui <- page_navbar(
  title = "shiny_workout",
  id = "nav",
  theme = bs_theme(version = 5),
  fillable = FALSE,
  header = tags$head(
    tags$link(rel = "stylesheet", href = "styles.css"),
    tags$script(src = "storage.js"),
    tags$script(src = "keys.js"),
    tags$script(src = "catalog.js")
  ),
  nav_panel(
    "Build",
    layout_columns(
      col_widths = breakpoints(sm = 12, lg = c(5, 7)),
      catalog_ui("catalog", catalog),
      placeholder_card("Workout", "Workout editor (Phase 3). Use + in the catalog to add exercises.")
    )
  ),
  nav_panel("Library", placeholder_card("Library", "Saved and example workouts (Phase 4).")),
  nav_panel("Run", placeholder_card("Run", "Workout player (Phase 5).")),
  nav_panel("Diagnostics", diagnostics_ui("diag")),
  nav_spacer(),
  nav_item(actionLink("about", "About", icon = bsicons::bs_icon("info-circle"))),
  nav_item(input_dark_mode(id = "dark_mode"))
)

server <- function(input, output, session) {
  settings <- reactive(config$defaults)
  added <- catalog_server("catalog", catalog, settings)

  # Until the editor exists (Phase 3), confirm what "+" would add.
  observeEvent(added(), {
    step <- added()$step
    target <- if (!is.null(step$reps)) paste(step$reps, "reps") else paste(step$seconds, "s")
    sides <- if (identical(step$sides, 2L)) ", each side" else ""
    showNotification(sprintf("Would add %s: %s%s.", step_label(step, catalog), target, sides),
                     type = "message", duration = 3)
  })

  observeEvent(input$about, showModal(about_modal(attr(catalog, "sources"))))
  diagnostics_server("diag")
}

shinyApp(ui, server)
