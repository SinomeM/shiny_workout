# Catalog browser: search, filters, a compact list and a details modal.
# Row clicks reach R through one delegated JS handler (www/catalog.js), not one
# observer per row. Returns a reactive with the id of the last exercise added.

catalog_page_size <- 50

catalog_ui <- function(id, catalog) {
  ns <- NS(id)
  choices <- function(field) {
    values <- catalog_values(catalog, field)
    stats::setNames(values, term_label(values))
  }
  multi <- function(input_id, label, field) {
    selectizeInput(ns(input_id), label, choices = choices(field), multiple = TRUE,
                   options = list(plugins = list("remove_button"), placeholder = "Any"))
  }
  card(
    class = "sw-catalog", fill = FALSE,
    card_header(
      class = "d-flex justify-content-between align-items-center",
      "Exercises",
      div(
        class = "d-flex align-items-center gap-2",
        textOutput(ns("count"), inline = TRUE) |> tagAppendAttributes(class = "badge text-bg-secondary"),
        # Only on narrow screens, where the catalog opens over the editor.
        tags$button(type = "button", class = "btn btn-sm btn-primary sw-catalog-close",
                    `data-sw-catalog` = "close", "Done")
      )
    ),
    card_body(
      gap = "0.5rem",
      textInput(ns("query"), NULL, placeholder = "Search name, alias or muscle", width = "100%"),
      accordion(
        open = FALSE,
        accordion_panel(
          "Filters",
          icon = bsicons::bs_icon("funnel"),
          multi("focus", "Focus", "focus"),
          multi("equipment", "Equipment", "equipment"),
          multi("muscle", "Primary muscle", "primary_muscles"),
          multi("level", "Level", "level"),
          multi("source", "Source", "source"),
          actionLink(ns("clear"), "Clear filters")
        )
      ),
      div(
        class = "sw-ex-list",
        `data-sw-open` = ns("open"),
        `data-sw-add` = ns("add"),
        uiOutput(ns("list"))
      ),
      uiOutput(ns("more_ui"))
    )
  )
}

catalog_server <- function(id, catalog, settings) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    # textInput already waits for a pause in typing before it sends its value.
    query <- reactive(input$query)
    limit <- reactiveVal(catalog_page_size)
    added <- reactiveVal(NULL)

    results <- reactive({
      search_catalog(catalog, query(), focus = input$focus, equipment = input$equipment,
                     muscle = input$muscle, level = input$level, source = input$source)
    })
    observeEvent(results(), limit(catalog_page_size))
    observeEvent(input$more, limit(limit() + catalog_page_size))
    observeEvent(input$clear, {
      for (f in c("focus", "equipment", "muscle", "level", "source")) {
        updateSelectizeInput(session, f, selected = character())
      }
      updateTextInput(session, "query", value = "")
    })

    output$count <- renderText(format(nrow(results()), big.mark = ","))
    # An empty inline badge has no size, so Shiny would treat it as hidden and never fill it.
    outputOptions(output, "count", suspendWhenHidden = FALSE)

    output$list <- renderUI({
      r <- results()
      if (!nrow(r)) return(p(class = "text-muted my-3", "No exercises match."))
      shown <- utils::head(r, limit())
      tagList(lapply(seq_len(nrow(shown)), function(i) exercise_row(shown[i, ])))
    })

    output$more_ui <- renderUI({
      left <- nrow(results()) - limit()
      if (left <= 0) return(NULL)
      actionButton(ns("more"), sprintf("Show %d more", min(left, catalog_page_size)),
                   class = "btn-sm btn-outline-secondary w-100")
    })

    observeEvent(input$open, {
      row <- catalog_row(catalog, input$open$id)
      if (!is.na(row)) showModal(exercise_modal(catalog[row, ], ns))
    })

    add <- function(id) {
      added(list(id = id, step = step_from_exercise(catalog, id, settings()), t = Sys.time()))
    }
    observeEvent(input$add, add(input$add$id))
    observeEvent(input$add_from_modal, {
      removeModal()
      add(input$add_from_modal)
    })

    reactive(added())
  })
}

term_badges <- function(values, class) {
  lapply(values, function(v) span(class = paste("badge rounded-pill", class), term_label(v)))
}

exercise_row <- function(ex) {
  div(
    class = "sw-ex-row", `data-id` = ex$id, tabindex = "0", role = "button",
    div(
      class = "sw-ex-main",
      div(class = "sw-ex-name", ex$name, if (isTRUE(ex$unilateral)) span(class = "sw-ex-sides", "each side")),
      div(
        class = "sw-ex-badges",
        term_badges(ex$focus[[1]], "sw-badge-focus"),
        term_badges(utils::head(ex$primary_muscles[[1]], 2), "sw-badge-muscle"),
        term_badges(setdiff(ex$equipment[[1]], "bodyweight"), "sw-badge-equipment")
      )
    ),
    tags$button(
      type = "button", class = "btn btn-sm btn-outline-primary sw-ex-add",
      `data-id` = ex$id, title = "Add to workout", `aria-label` = paste("Add", ex$name),
      bsicons::bs_icon("plus-lg")
    )
  )
}

exercise_modal <- function(ex, ns) {
  steps <- ex$instructions[[1]]
  muscles <- function(label, values) {
    if (length(values)) tags$p(tags$strong(paste0(label, ":")), paste(term_label(values), collapse = ", "))
  }
  modalDialog(
    title = ex$name,
    easyClose = TRUE,
    size = "l",
    if (length(ex$aliases[[1]])) p(class = "text-muted", paste(ex$aliases[[1]], collapse = " · ")),
    div(
      class = "sw-ex-badges mb-3",
      term_badges(ex$focus[[1]], "sw-badge-focus"),
      term_badges(ex$equipment[[1]], "sw-badge-equipment"),
      if (!is.na(ex$level)) span(class = "badge rounded-pill sw-badge-level", term_label(ex$level)),
      if (isTRUE(ex$unilateral)) span(class = "badge rounded-pill sw-badge-level", "Each side")
    ),
    muscles("Primary muscles", ex$primary_muscles[[1]]),
    muscles("Secondary muscles", ex$secondary_muscles[[1]]),
    if (length(steps)) tags$ol(lapply(steps, tags$li)) else p(class = "text-muted", "No instructions yet."),
    tags$p(
      class = "small text-muted mb-0",
      "Source: ", tags$a(href = ex$url, target = "_blank", rel = "noopener", ex$attribution),
      " · ", tags$a(href = ex$license_url, target = "_blank", rel = "noopener", ex$license),
      if (!is.na(ex$instructions_from %||% NA)) tagList(tags$br(), "Instructions: ", ex$instructions_from)
    ),
    footer = tagList(
      modalButton("Close"),
      tags$button(
        type = "button", class = "btn btn-primary",
        onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'})",
                          ns("add_from_modal"), ex$id),
        bsicons::bs_icon("plus-lg"), "Add to workout"
      )
    )
  )
}
