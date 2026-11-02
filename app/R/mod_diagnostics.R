# Phase 0 spike: checks that the Shiny features we rely on work in the
# exported Shinylive (webR) build. Remove or hide once Phase 0 is signed off.

storage_key <- "shiny_workout.spike"

spike_workout <- function() {
  list(
    schema_version = 1L,
    name = "Spike workout",
    steps = list(
      list(type = "exercise", name = "Push-ups", reps = 10L, advance = "manual"),
      list(type = "rest", seconds = 30L, advance = "auto")
    )
  )
}

diagnostics_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_column_wrap(
      width = 1 / 2,
      card(
        card_header("Runtime"),
        tableOutput(ns("runtime"))
      ),
      card(
        card_header("Download YAML"),
        p("Should save a file named spike.yaml."),
        downloadButton(ns("download"), "Download spike.yaml")
      ),
      card(
        card_header("Upload YAML"),
        fileInput(ns("upload"), NULL, accept = c(".yaml", ".yml")),
        verbatimTextOutput(ns("uploaded"))
      ),
      card(
        card_header("localStorage"),
        p("Save, reload the page, then Load: the value should survive."),
        textInput(ns("ls_text"), "Value to store", "hello"),
        div(
          actionButton(ns("ls_save"), "Save"),
          actionButton(ns("ls_load"), "Load")
        ),
        verbatimTextOutput(ns("ls_result"))
      ),
      card(
        card_header("Keyboard"),
        div(
          `data-sw-keys` = ns("key"),
          p(
            "Press Space, P, arrows, F or Esc. The page must not scroll, and the",
            "decoy button must not be clicked even when it has focus."
          ),
          actionButton(ns("decoy"), "Decoy button"),
          verbatimTextOutput(ns("keys"))
        )
      )
    ),
    # Tall spacer so an unwanted Space-bar scroll is obvious.
    div(class = "sw-scroll-spacer")
  )
}

diagnostics_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$runtime <- renderTable({
      data.frame(
        item = c("R", "Platform", "In webR", "shiny", "bslib", "yaml"),
        value = c(
          R.version.string,
          R.version$platform,
          as.character(grepl("emscripten", R.version$platform)),
          as.character(packageVersion("shiny")),
          as.character(packageVersion("bslib")),
          as.character(packageVersion("yaml"))
        )
      )
    })

    output$download <- downloadHandler(
      filename = function() "spike.yaml",
      content = function(file) yaml::write_yaml(spike_workout(), file)
    )

    output$uploaded <- renderPrint({
      req(input$upload)
      str(yaml::read_yaml(input$upload$datapath))
    })

    observeEvent(input$ls_save, {
      session$sendCustomMessage("sw-storage-set", list(key = storage_key, value = input$ls_text))
    })
    observeEvent(input$ls_load, {
      session$sendCustomMessage("sw-storage-get", list(key = storage_key, input = session$ns("ls_value")))
    })
    output$ls_result <- renderPrint({
      req(input$ls_value)
      input$ls_value
    })

    keys <- reactiveVal(character())
    observeEvent(input$key, {
      entry <- sprintf("%s  %s", format(Sys.time(), "%H:%M:%S"), input$key$key)
      keys(head(c(entry, keys()), 8))
    })
    output$keys <- renderText({
      paste(c(sprintf("Decoy clicks: %d", input$decoy), keys()), collapse = "\n")
    })
  })
}
