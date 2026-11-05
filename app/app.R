library(shiny)
library(bslib)

# Modules and helpers in R/ are sourced automatically by shiny::runApp().

config <- read_app_config("config.yml")
catalog <- load_catalog("data/exercises.json", config)
example_files <- list.files("workouts", pattern = "\\.ya?ml$", full.names = TRUE)
examples <- stats::setNames(lapply(example_files, read_workout), tools::file_path_sans_ext(basename(example_files)))

ui <- page_navbar(
  title = "shiny_workout",
  id = "nav",
  theme = bs_theme(version = 5),
  fillable = FALSE,
  header = tags$head(
    tags$link(rel = "stylesheet", href = "styles.css"),
    tags$script(src = "storage.js"),
    tags$script(src = "actions.js"),
    tags$script(src = "catalog.js"),
    tags$script(src = "vendor/Sortable-1.15.6.min.js"),  # SortableJS, MIT licence
    tags$script(src = "editor.js"),
    tags$script(src = "player.js")
  ),
  nav_panel(
    "Build",
    layout_columns(
      col_widths = breakpoints(sm = 12, lg = c(5, 7)),
      catalog_ui("catalog", catalog),
      editor_ui("editor")
    )
  ),
  nav_panel("Library", library_ui("library")),
  nav_panel("Run", player_ui("player")),
  nav_spacer(),
  nav_item(actionLink("help", "Help", icon = bsicons::bs_icon("question-circle"))),
  nav_item(actionLink("settings", "Settings", icon = bsicons::bs_icon("gear"))),
  nav_item(actionLink("about", "About", icon = bsicons::bs_icon("info-circle"))),
  nav_item(input_dark_mode(id = "dark_mode"))
)

server <- function(input, output, session) {
  user_settings <- settings_store(input, session, config$defaults)
  settings <- user_settings$settings
  settings_server(input, output, session, user_settings, config$defaults)
  store <- library_store(input, session)

  go_build <- function() nav_select("nav", "Build", session = session)
  go_run <- function() nav_select("nav", "Run", session = session)

  added <- catalog_server("catalog", catalog, settings)
  editor <- editor_server("editor", catalog, settings, added, store, go_run)
  library_server("library", store, examples, catalog, settings, editor, go_build, go_run)
  player_server("player", editor$workout, settings, catalog,
                active = reactive(identical(input$nav, "Run")), go_build)

  observeEvent(input$about, showModal(about_modal(attr(catalog, "sources"))))
  observeEvent(input$help, showModal(help_modal()))
  observeEvent(input$help_key, showModal(help_modal()))
}

shinyApp(ui, server)
