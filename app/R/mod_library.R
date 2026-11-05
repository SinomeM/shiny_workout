# Library tab (saved workouts, examples, import, export all) and the stores behind it:
# the saved workouts and the user's settings, both kept in localStorage.

# Saved workouts. Loaded once from localStorage, written back after every change.
library_store <- function(input, session) {
  entries <- reactiveVal(list())
  loaded <- reactiveVal(FALSE)
  session$sendCustomMessage("sw-storage-get", list(key = library_key, input = "library_raw"))
  observeEvent(input$library_raw, once = TRUE, {
    entries(library_from_json(input$library_raw$value))
    loaded(TRUE)
  })
  update <- function(new) {
    entries(new)
    if (isolate(loaded())) {
      session$sendCustomMessage("sw-storage-set", list(key = library_key, value = library_to_json(new)))
    }
  }
  list(
    entries = entries,
    save = function(w, id = NULL) {
      r <- library_upsert(isolate(entries()), w, id)
      update(r$entries)
      r$id
    },
    add = function(w) {
      r <- library_upsert(isolate(entries()), w)
      update(r$entries)
      r$id
    },
    remove = function(id) update(library_remove(isolate(entries()), id)),
    duplicate = function(id) update(library_duplicate(isolate(entries()), id)$entries),
    rename = function(id, name) update(library_rename(isolate(entries()), id, name))
  )
}

# The user's settings layer, on top of the app defaults from config.yml.
settings_store <- function(input, session, app_defaults) {
  user <- reactiveVal(list())
  session$sendCustomMessage("sw-storage-get", list(key = settings_key, input = "settings_raw"))
  observeEvent(input$settings_raw, once = TRUE, user(user_settings_from_json(input$settings_raw$value)))
  list(
    user = user,
    settings = reactive(resolve_settings(app_defaults, user())),
    set = function(s) {
      user(s)
      session$sendCustomMessage("sw-storage-set", list(key = settings_key, value = user_settings_to_json(s)))
    }
  )
}

settings_labels <- c(
  prep_seconds = "Get ready before the first step (s)",
  rest_seconds = "New rest steps (s)",
  reps = "New rep-based steps (reps)",
  exercise_seconds = "New timed steps (s)",
  hold_seconds = "New guided-rep holds (s)",
  relax_seconds = "Relax between guided reps (s)",
  switch_seconds = "Switch sides (s)",
  seconds_per_rep = "Seconds per rep, for duration estimates"
)

settings_modal <- function(current, defaults) {
  fields <- lapply(settings_keys, function(key) {
    numericInput(paste0("setting_", key), settings_labels[[key]], value = current[[key]],
                 min = if (key == "reps") 1 else 0, step = 1)
  })
  modalDialog(
    title = "Settings",
    easyClose = TRUE,
    p(class = "text-muted small", "Defaults for new steps and for every workout. A workout's own",
      "timing (in the editor) overrides these. Saved in this browser."),
    do.call(layout_columns, c(list(col_widths = c(6, 6), gap = "0.5rem"), fields)),
    uiOutput("settings_errors"),
    footer = tagList(
      actionButton("settings_reset", "Reset to defaults", class = "btn-outline-secondary me-auto"),
      modalButton("Cancel"),
      actionButton("settings_save", "Save", class = "btn-primary")
    )
  )
}

# Settings dialog wiring, in the app's top-level server.
settings_server <- function(input, output, session, store, app_defaults) {
  observeEvent(input$settings, showModal(settings_modal(store$settings(), app_defaults)))
  observeEvent(input$settings_reset, {
    for (key in settings_keys) updateNumericInput(session, paste0("setting_", key), value = app_defaults[[key]])
  })
  observeEvent(input$settings_save, {
    values <- lapply(stats::setNames(settings_keys, settings_keys), function(key) input[[paste0("setting_", key)]])
    check <- validate_settings(values, partial = FALSE)
    if (length(check$errors)) {
      output$settings_errors <- renderUI(div(class = "alert alert-danger py-2 small mb-0",
                                             paste(check$errors, collapse = " ")))
      return()
    }
    changed <- Filter(Negate(is.null), lapply(settings_keys, function(key) {
      if (!isTRUE(all.equal(values[[key]], app_defaults[[key]]))) key
    }))
    store$set(values[unlist(changed)])
    output$settings_errors <- renderUI(NULL)
    removeModal()
    showNotification("Settings saved.", duration = 2, type = "message")
  })
}

library_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = breakpoints(sm = 12, lg = c(7, 5)),
    card(
      fill = FALSE,
      card_header(
        class = "d-flex align-items-center gap-2",
        "My workouts",
        actionButton(ns("export_all"), "Export all", icon = bsicons::bs_icon("download"),
                     class = "btn-sm btn-outline-primary ms-auto")
      ),
      card_body(
        fillable = FALSE,
        div(`data-sw-actions` = ns("action"), uiOutput(ns("mine"))),
        fileInput(ns("import"), "Import workouts (.yaml)", multiple = TRUE, accept = c(".yaml", ".yml"),
                  width = "100%", buttonLabel = "Choose files…"),
        uiOutput(ns("import_result"))
      )
    ),
    card(
      fill = FALSE,
      card_header("Examples"),
      card_body(
        fillable = FALSE,
        p(class = "small text-muted mb-1", "Opening or running an example puts a copy in the editor."),
        div(`data-sw-actions` = ns("action"), uiOutput(ns("examples")))
      )
    )
  )
}

library_server <- function(id, store, examples, catalog, settings, editor, go_build, go_run) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    pending <- reactiveVal(NULL)   # id waiting for rename / delete confirmation

    describe <- function(w) {
      est <- tryCatch(estimate_duration(w, settings(), catalog), error = function(e) NULL)
      parts <- c(
        if (!is.null(est)) paste0("≈ ", format_duration(est$total_seconds), if (est$open_steps) " +"),
        sprintf("%d step%s", length(w$steps), if (length(w$steps) == 1) "" else "s")
      )
      paste(parts, collapse = " · ")
    }

    output$mine <- renderUI({
      entries <- store$entries()
      if (!length(entries)) {
        return(div(class = "sw-empty mb-3", "Nothing saved yet. Use Save in the editor, or import files below."))
      }
      div(class = "sw-lib-list mb-3", lapply(entries, function(e) {
        library_row(e$id, e$workout, describe(e$workout), saved = e$updated,
                    buttons = list(c("run", "play-fill", "Run"),
                                   c("open", "box-arrow-up-right", "Open"),
                                   c("duplicate", "copy", "Duplicate"),
                                   c("rename", "pencil", "Rename"),
                                   c("download", "download", "Download"),
                                   c("delete", "trash", "Delete")))
      }))
    })

    output$examples <- renderUI({
      div(class = "sw-lib-list", lapply(names(examples), function(key) {
        library_row(key, examples[[key]], describe(examples[[key]]),
                    buttons = list(c("run_example", "play-fill", "Run"),
                                   c("open_example", "box-arrow-up-right", "Open a copy"),
                                   c("download_example", "download", "Download")))
      }))
    })

    download <- function(w) {
      session$sendCustomMessage("sw-download", list(filename = workout_filename(w$name),
                                                    text = workout_to_yaml(w)))
    }

    observeEvent(input$action, {
      a <- input$action
      e <- library_get(store$entries(), a$id)
      switch(
        a$op,
        open = if (!is.null(e)) { editor$load(e$workout, e$id); go_build() },
        run = if (!is.null(e)) { editor$load(e$workout, e$id); go_run() },
        duplicate = store$duplicate(a$id),
        download = if (!is.null(e)) download(e$workout),
        rename = if (!is.null(e)) {
          pending(a$id)
          showModal(modalDialog(
            title = "Rename workout", easyClose = TRUE,
            textInput(ns("new_name"), "Name", value = e$workout$name, width = "100%"),
            footer = tagList(modalButton("Cancel"), actionButton(ns("rename_ok"), "Rename", class = "btn-primary"))
          ))
        },
        delete = if (!is.null(e)) {
          pending(a$id)
          showModal(modalDialog(
            title = "Delete workout", easyClose = TRUE,
            p(sprintf("Delete “%s” from your library? This can't be undone.", e$workout$name)),
            footer = tagList(modalButton("Cancel"), actionButton(ns("delete_ok"), "Delete", class = "btn-danger"))
          ))
        },
        open_example = { editor$load(examples[[a$id]], NULL); go_build() },
        run_example = { editor$load(examples[[a$id]], NULL); go_run() },
        download_example = download(examples[[a$id]])
      )
    })
    observeEvent(input$rename_ok, {
      store$rename(pending(), input$new_name)
      removeModal()
    })
    observeEvent(input$delete_ok, {
      store$remove(pending())
      editor$forget(pending())
      removeModal()
    })

    observeEvent(input$export_all, {
      entries <- store$entries()
      if (!length(entries)) {
        showNotification("Your library is empty.", duration = 2, type = "warning")
        return()
      }
      session$sendCustomMessage("sw-download", list(
        filename = sprintf("shiny_workout-library-%s.yaml", format(Sys.Date())),
        text = workouts_to_multi_yaml(lapply(entries, `[[`, "workout"))
      ))
    })

    observeEvent(input$import, {
      files <- input$import
      results <- unlist(lapply(seq_len(nrow(files)), function(i) {
        text <- paste(readLines(files$datapath[i], encoding = "UTF-8", warn = FALSE), collapse = "\n")
        import_workouts(text, files$name[i], catalog)
      }), recursive = FALSE)
      for (r in results) if (!is.null(r$workout)) store$add(r$workout)
      output$import_result <- renderUI(import_report(results))
    })
  })
}

library_row <- function(id, w, details, buttons, saved = NULL) {
  div(
    class = "sw-lib-row",
    div(
      class = "sw-lib-main",
      div(class = "sw-lib-name", w$name,
          if (!is.null(w$sport)) span(class = "badge rounded-pill sw-badge-focus ms-1", term_label(w$sport))),
      div(class = "sw-lib-details", details,
          if (!is.null(saved) && nzchar(saved)) paste0(" · saved ", format_saved(saved)))
    ),
    div(
      class = "sw-card-actions",
      lapply(buttons, function(b) {
        tags$button(type = "button", class = "btn btn-sm btn-link sw-card-btn", `data-sw-op` = b[[1]],
                    `data-id` = id, title = b[[3]], `aria-label` = b[[3]], bsicons::bs_icon(b[[2]]))
      })
    )
  )
}

format_saved <- function(stamp) {
  t <- as.POSIXct(stamp, format = "%Y-%m-%dT%H:%M:%S")
  if (is.na(t)) return(stamp)
  format(t, "%d %b %Y, %H:%M")
}

import_report <- function(results) {
  items <- lapply(results, function(r) {
    if (is.null(r$workout)) {
      tags$li(class = "text-danger", tags$strong(paste0(r$name, ":")), " not imported. ", r$errors[1],
              if (length(r$errors) > 1) sprintf(" (and %d more problems)", length(r$errors) - 1))
    } else {
      tags$li(tags$strong(paste0(r$name, ":")), " added to your library",
              if (length(r$warnings)) tagList(" with warnings: ", paste(r$warnings, collapse = " ")))
    }
  })
  div(class = "small", tags$ul(class = "mb-0 ps-3", items))
}
