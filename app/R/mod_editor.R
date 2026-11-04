# Workout editor: header fields, step cards, add bar, edit modal, summary, undo/redo,
# save to the library, download, and a draft autosaved to localStorage. All card
# buttons reach R through one delegated JS handler (www/actions.js) as
# input$action = {op, uid, container}; drag and drop (www/editor.js) sends
# input$reorder = {container, order}. The library entry a workout came from is kept
# as attr(w, "library_id"), so it follows undo/redo and is never written to files.

draft_key <- "shiny_workout.draft"

# Settings that can be overridden per workout from the editor.
workout_timing <- c(prep_seconds = "Get ready (s)", relax_seconds = "Relax between reps (s)",
                    switch_seconds = "Switch sides (s)")
undo_limit <- 50

editor_ui <- function(id) {
  ns <- NS(id)
  icon_button <- function(input_id, icon, title) {
    actionButton(ns(input_id), bsicons::bs_icon(icon), class = "btn-sm btn-outline-secondary",
                 title = title, `aria-label` = title)
  }
  add_button <- function(op, label, icon) {
    tags$button(type = "button", class = "btn btn-sm btn-outline-primary", `data-sw-op` = op,
                bsicons::bs_icon(icon), label)
  }
  card(
    class = "sw-editor align-self-start",
    card_header(
      class = "d-flex align-items-center gap-2",
      "Workout",
      div(
        class = "ms-auto d-flex gap-1",
        actionButton(ns("run"), "Run", icon = bsicons::bs_icon("play-fill"), class = "btn-sm btn-success",
                     title = "Run this workout"),
        icon_button("save", "floppy", "Save to library"),
        icon_button("download", "download", "Download as YAML"),
        icon_button("undo", "arrow-counterclockwise", "Undo"),
        icon_button("redo", "arrow-clockwise", "Redo"),
        icon_button("new", "file-earmark-plus", "New workout")
      )
    ),
    card_body(
      fillable = FALSE,
      gap = "0.75rem",
      layout_columns(
        col_widths = c(8, 4), gap = "0.5rem",
        tagList(
          textInput(ns("name"), "Name", value = "New workout", width = "100%"),
          uiOutput(ns("status"), class = "sw-save-status")
        ),
        selectInput(ns("sport"), "Sport", choices = c("None" = "", stats::setNames(sports, term_label(sports))),
                    width = "100%")
      ),
      accordion(
        open = FALSE,
        accordion_panel(
          "Description and tags",
          icon = bsicons::bs_icon("card-text"),
          textAreaInput(ns("description"), NULL, rows = 2, width = "100%",
                        placeholder = "What is this workout for?"),
          selectizeInput(ns("tags"), "Tags", choices = NULL, multiple = TRUE, width = "100%",
                         options = list(create = TRUE, plugins = list("remove_button"),
                                        placeholder = "Type a tag and press Enter"))
        ),
        accordion_panel(
          "Timing for this workout",
          icon = bsicons::bs_icon("stopwatch"),
          p(class = "small text-muted", "Leave empty to use your default settings."),
          do.call(layout_columns, c(
            list(col_widths = c(4, 4, 4), gap = "0.5rem"),
            lapply(names(workout_timing), function(key) {
              numericInput(ns(paste0("set_", key)), workout_timing[[key]], value = NA, min = 0, step = 1)
            })
          ))
        )
      ),
      uiOutput(ns("summary")),
      div(
        class = "sw-editor-steps",
        `data-sw-actions` = ns("action"),
        uiOutput(ns("steps")),
        div(
          class = "sw-add-bar",
          add_button("add_exercise", "Exercise", "plus-lg"),
          add_button("add_rest", "Rest", "pause-circle"),
          add_button("add_warmup", "Warm-up", "sunrise"),
          add_button("add_cooldown", "Cool-down", "sunset"),
          add_button("add_repeat", "Repeat block", "repeat")
        )
      ),
      uiOutput(ns("problems"))
    )
  )
}

editor_server <- function(id, catalog, settings, added, store, go_run) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    state <- reactiveValues(
      w = with_uids(new_workout("New workout")), undo = list(), redo = list(),
      last_key = NULL, editing = NULL, loaded = FALSE
    )

    # Every change goes through commit(). Changes with the same `key` (typing in one
    # field) share one undo step.
    commit <- function(w, key = NULL) {
      if (identical(w, state$w)) return(invisible())
      if (is.null(key) || !identical(key, state$last_key)) {
        state$undo <- c(utils::tail(state$undo, undo_limit - 1), list(state$w))
      }
      state$redo <- list()
      state$last_key <- key
      state$w <- w
    }

    observeEvent(input$undo, {
      if (!length(state$undo)) return()
      state$redo <- c(state$redo, list(state$w))
      state$w <- state$undo[[length(state$undo)]]
      state$undo <- state$undo[-length(state$undo)]
      state$last_key <- NULL
    })
    observeEvent(input$redo, {
      if (!length(state$redo)) return()
      state$undo <- c(state$undo, list(state$w))
      state$w <- state$redo[[length(state$redo)]]
      state$redo <- state$redo[-length(state$redo)]
      state$last_key <- NULL
    })
    observe({
      updateActionButton(session, "undo", disabled = !length(state$undo))
      updateActionButton(session, "redo", disabled = !length(state$redo))
    })
    observeEvent(input$new, commit(with_uids(new_workout("New workout"))))
    observeEvent(input$run, go_run())

    load_workout <- function(w, library_id = NULL) {
      w <- with_uids(strip_uids(w))
      attr(w, "library_id") <- library_id
      commit(w)
    }

    # Save to the library: replaces the entry it came from, or adds a new one.
    observeEvent(input$save, {
      w <- state$w
      if (length(validate_workout(w, catalog)$errors)) {
        showNotification("Fix the problems listed under the steps before saving.", type = "error", duration = 3)
        return()
      }
      id <- store$save(w, attr(w, "library_id"))
      attr(w, "library_id") <- id
      state$w <- w
      showNotification(paste("Saved", dQuote(w$name, FALSE), "to your library."), duration = 2, type = "message")
    })
    observeEvent(input$download, {
      w <- state$w
      session$sendCustomMessage("sw-download", list(filename = workout_filename(w$name),
                                                    text = workout_to_yaml(w)))
    })
    output$status <- renderUI({
      w <- state$w
      id <- attr(w, "library_id")
      entry <- if (!is.null(id)) library_get(store$entries(), id)
      if (is.null(entry)) return("Not in your library yet")
      if (identical(tidy_workout(entry$workout), tidy_workout(w))) "Saved in your library" else "Unsaved changes"
    })

    # Draft: restore once at start, then save after every change. Stored as JSON with
    # the library id and the workout as YAML; older drafts are plain YAML.
    session$sendCustomMessage("sw-storage-get", list(key = draft_key, input = ns("draft")))
    observeEvent(input$draft, once = TRUE, {
      text <- input$draft$value
      if (is.character(text) && nzchar(text)) {
        draft <- tryCatch(jsonlite::fromJSON(text), error = function(e) list(yaml = text))
        w <- tryCatch(workout_from_yaml(draft$yaml %||% text), error = function(e) NULL)
        if (!is.null(w) && is.list(w$steps %||% list())) {
          w <- with_uids(w)
          if (is.character(draft$id) && length(draft$id) == 1) attr(w, "library_id") <- draft$id
          state$w <- w
        }
      }
      state$loaded <- TRUE
    })
    observeEvent(state$w, {
      if (state$loaded) {
        draft <- list(id = attr(state$w, "library_id"), yaml = workout_to_yaml(state$w))
        session$sendCustomMessage("sw-storage-set", list(
          key = draft_key, value = as.character(jsonlite::toJSON(draft, auto_unbox = TRUE, null = "null"))
        ))
      }
    })

    # Header fields <-> workout.
    observe({
      w <- state$w
      if (!identical(isolate(input$name), w$name)) updateTextInput(session, "name", value = w$name %||% "")
      if (!identical(isolate(input$sport) %||% "", w$sport %||% "")) updateSelectInput(session, "sport", selected = w$sport %||% "")
      if (!identical(isolate(input$description) %||% "", w$description %||% "")) {
        updateTextAreaInput(session, "description", value = w$description %||% "")
      }
      if (!setequal(isolate(input$tags) %||% character(), w$tags %||% character())) {
        updateSelectizeInput(session, "tags", choices = w$tags, selected = w$tags)
      }
      for (key in names(workout_timing)) {
        id <- paste0("set_", key)
        value <- w$settings[[key]] %||% NA
        current <- isolate(input[[id]]) %||% NA
        if (!identical(as.numeric(current), as.numeric(value))) updateNumericInput(session, id, value = value)
      }
    })
    header_field <- function(field, value) {
      w <- state$w
      value <- if (length(value) && any(nzchar(value))) value else NULL
      if (identical(w[[field]], value)) return()
      w[[field]] <- value
      ordered <- w[c(intersect(workout_fields, names(w)), setdiff(names(w), workout_fields))]
      attr(ordered, "library_id") <- attr(w, "library_id")
      commit(ordered, key = field)
    }
    observeEvent(input$name, header_field("name", input$name), ignoreInit = TRUE)
    observeEvent(input$sport, header_field("sport", input$sport), ignoreInit = TRUE)
    observeEvent(input$description, header_field("description", input$description), ignoreInit = TRUE)
    observeEvent(input$tags, header_field("tags", input$tags), ignoreInit = TRUE, ignoreNULL = FALSE)
    lapply(names(workout_timing), function(key) {
      id <- paste0("set_", key)
      observeEvent(input[[id]], {
        value <- input[[id]]
        value <- if (is.null(value) || is.na(value) || !setting_ok(key, value)) NULL else value
        w <- state$w
        if (identical(w$settings[[key]], value)) return()
        settings <- w$settings %||% list()
        settings[[key]] <- value
        w$settings <- if (length(settings)) settings[intersect(settings_keys, names(settings))]
        commit(w, key = id)
      }, ignoreInit = TRUE, ignoreNULL = FALSE)
    })

    # Card buttons and the add bar.
    open_editor <- function(step, uid = NULL, container = NULL) {
      state$editing <- list(step = step, uid = uid, container = container)
      output$modal_errors <- renderUI(NULL)
      showModal(step_modal(step, ns, catalog, is_new = is.null(uid)))
    }
    observeEvent(input$action, {
      a <- input$action
      w <- state$w
      uid <- a$uid
      container <- if (nzchar(a$container %||% "")) a$container
      s <- settings()
      switch(
        a$op,
        edit = { step <- find_step(w, uid); if (!is.null(step)) open_editor(step, uid) },
        duplicate = commit(duplicate_step(w, uid)),
        up = commit(move_step(w, uid, -1)),
        down = commit(move_step(w, uid, 1)),
        into = commit(move_into_block(w, uid)),
        out = commit(move_out_of_block(w, uid)),
        delete = commit(remove_step(w, uid)),
        add_exercise = open_editor(new_step("exercise", reps = s$reps), container = container),
        add_rest = commit(insert_step(w, new_step("rest", seconds = s$rest_seconds), container)),
        add_warmup = open_editor(new_step("warmup", seconds = s$exercise_seconds)),
        add_cooldown = open_editor(new_step("cooldown")),
        add_repeat = commit(insert_step(w, new_step("repeat", times = 3L, skip_last_rest = TRUE)))
      )
    })
    observeEvent(input$reorder, {
      r <- input$reorder
      container <- if (nzchar(r$container %||% "")) r$container
      commit(reorder_container(state$w, container, r$order))
    })

    # Edit modal.
    observeEvent(input$exercise, {
      e <- state$editing
      if (is.null(e) || !is.null(e$uid) || !nzchar(input$exercise)) return()
      suggested <- step_from_exercise(catalog, input$exercise, settings())
      updateNumericInput(session, "reps", value = suggested$reps %||% NA)
      updateNumericInput(session, "seconds", value = suggested$seconds %||% NA)
      updateCheckboxInput(session, "sides", value = identical(suggested$sides, 2L))
      updateRadioButtons(session, "advance", selected = suggested$advance)
    }, ignoreInit = TRUE)

    observeEvent(input$save, {
      e <- state$editing
      if (is.null(e)) return()
      step <- step_from_inputs(input, e$step$type)
      check <- validate_workout(new_workout("check", steps = list(
        if (step$type == "repeat") utils::modifyList(step, list(steps = list(new_step("rest"))))
        else step
      )), catalog)
      if (length(check$errors)) {
        output$modal_errors <- renderUI(div(class = "alert alert-danger py-2 small mb-0",
                                            friendly_error(check$errors[1])))
        return()
      }
      w <- if (is.null(e$uid)) insert_step(state$w, step, e$container) else replace_step(state$w, e$uid, step)
      commit(w)
      state$editing <- NULL
      output$modal_errors <- renderUI(NULL)
      removeModal()
    })

    observeEvent(added(), {
      a <- added()
      commit(insert_step(state$w, a$step))
      showNotification(paste("Added", step_label(a$step, catalog)), duration = 2, type = "message")
    })

    # Output.
    output$steps <- renderUI({
      w <- state$w
      div(
        class = "sw-steps", `data-sw-sortable` = ns("reorder"), `data-container` = "",
        if (!length(w$steps)) {
          div(class = "sw-empty", "No steps yet. Add exercises with + in the catalog or the buttons below.")
        } else {
          lapply(w$steps, step_card, w = w, catalog = catalog, ns = ns)
        }
      )
    })

    output$summary <- renderUI({
      w <- state$w
      if (!length(w$steps) || length(validate_workout(w, catalog)$errors)) return(NULL)
      summary_panel(workout_summary(w, settings(), catalog))
    })

    output$problems <- renderUI({
      w <- state$w
      v <- validate_workout(w, catalog)
      errors <- setdiff(v$errors, "The workout has no steps.")
      tagList(
        if (length(errors)) div(class = "alert alert-danger py-2 small", tags$ul(class = "mb-0", lapply(errors, tags$li))),
        if (length(v$warnings)) div(class = "alert alert-warning py-2 small", tags$ul(class = "mb-0", lapply(v$warnings, tags$li)))
      )
    })

    list(
      workout = reactive(state$w),
      load = load_workout,
      # A deleted library entry: the open workout is no longer linked to it.
      forget = function(id) {
        w <- isolate(state$w)
        if (identical(attr(w, "library_id"), id)) {
          attr(w, "library_id") <- NULL
          state$w <- w
        }
      }
    )
  })
}

# Validation messages name YAML fields; in the edit modal, say it in UI terms.
friendly_error <- function(message) {
  message <- sub("^Step 1(\\.1)?: ", "", message)
  fixes <- c(
    "advance: auto needs seconds" = "Set the seconds, or choose \u201cWhen I press Space\u201d.",
    "hold_seconds needs reps" = "Set the reps for the hold.",
    "exercise steps need an exercise id or a name" = "Choose an exercise or type a name."
  )
  hit <- which(startsWith(message, names(fixes)))
  if (length(hit)) fixes[[hit[1]]] else paste0(toupper(substring(message, 1, 1)), substring(message, 2))
}

# Step built from the modal's inputs.
step_from_inputs <- function(input, type) {
  num <- function(x) if (is.null(x) || is.na(x)) NULL else x
  text <- function(x) if (is.null(x) || !nzchar(trimws(x))) NULL else trimws(x)
  if (type == "repeat") {
    return(new_step("repeat", times = as.integer(num(input$times) %||% 1),
                    skip_last_rest = isTRUE(input$skip_last_rest)))
  }
  type <- input$type %||% type
  if (type == "rest") {
    return(new_step("rest", seconds = num(input$seconds), advance = input$advance, notes = text(input$notes)))
  }
  new_step(
    type,
    exercise = text(input$exercise), name = text(input$step_name),
    reps = if (!is.null(num(input$reps))) as.integer(input$reps),
    seconds = num(input$seconds), hold_seconds = num(input$hold_seconds),
    relax_seconds = if (!is.null(num(input$hold_seconds))) num(input$relax_seconds),
    sides = if (isTRUE(input$sides)) 2L, advance = input$advance,
    weight = text(input$weight), notes = text(input$notes)
  )
}

step_modal <- function(step, ns, catalog, is_new) {
  title <- paste(if (is_new) "Add" else "Edit", tolower(unname(type_labels[[step$type]])))
  if (step$type == "repeat") {
    body <- tagList(
      numericInput(ns("times"), "Rounds", value = step$times, min = 1, step = 1),
      checkboxInput(ns("skip_last_rest"), "No rest after the last round", value = isTRUE(step$skip_last_rest))
    )
  } else {
    enabled <- catalog[catalog$enabled | catalog$id %in% step$exercise, ]
    choices <- c("Custom (use the name below)" = "", stats::setNames(enabled$id, enabled$name))
    not_rest <- sprintf("input['%s'] != 'rest'", ns("type"))
    body <- tagList(
      selectInput(ns("type"), "Type", selected = step$type,
                  choices = stats::setNames(c("warmup", "exercise", "rest", "cooldown"),
                                            c("Warm-up", "Exercise", "Rest", "Cool-down"))),
      conditionalPanel(
        not_rest,
        selectizeInput(ns("exercise"), "Exercise", choices = choices, selected = step$exercise %||% "",
                       width = "100%", options = list(placeholder = "Search the catalog")),
        textInput(ns("step_name"), "Name", value = step$name %||% "", width = "100%",
                  placeholder = "Optional with a catalog exercise: shown instead of its name")
      ),
      layout_columns(
        col_widths = c(6, 6), gap = "0.5rem",
        conditionalPanel(not_rest, numericInput(ns("reps"), "Reps", value = step$reps %||% NA, min = 1, step = 1)),
        numericInput(ns("seconds"), "Seconds", value = step$seconds %||% NA, min = 1, step = 5)
      ),
      conditionalPanel(
        not_rest,
        layout_columns(
          col_widths = c(6, 6), gap = "0.5rem",
          numericInput(ns("hold_seconds"), "Hold per rep (s)", value = step$hold_seconds %||% NA, min = 1),
          numericInput(ns("relax_seconds"), "Relax between reps (s)", value = step$relax_seconds %||% NA, min = 0)
        ),
        checkboxInput(ns("sides"), "Each side (left, then right)", value = isTRUE(step$sides == 2))
      ),
      radioButtons(ns("advance"), "Move on", inline = TRUE, selected = step_advance(step),
                   choices = c("When the time is up" = "auto", "When I press Space" = "manual")),
      conditionalPanel(not_rest, textInput(ns("weight"), "Weight or band", value = step$weight %||% "", width = "100%")),
      textAreaInput(ns("notes"), "Notes", value = step$notes %||% "", rows = 2, width = "100%")
    )
  }
  modalDialog(
    title = title,
    easyClose = FALSE,
    body,
    uiOutput(ns("modal_errors")),
    footer = tagList(modalButton("Cancel"), actionButton(ns("save"), "Save", class = "btn-primary"))
  )
}

step_card <- function(step, w, catalog, ns, nested = FALSE) {
  uid <- step$uid
  button <- function(op, icon, title) {
    tags$button(type = "button", class = "btn btn-sm btn-link sw-card-btn", `data-sw-op` = op,
                `data-uid` = uid, title = title, `aria-label` = title, bsicons::bs_icon(icon))
  }
  into <- into_block_target(w, uid)
  is_block <- identical(step$type, "repeat")
  type_label <- unname(type_labels[[step$type]])
  label <- if (is_block) type_label else step_label(step, catalog)
  extras <- c(
    if (!is.null(step$weight)) step$weight,
    if (!is.null(step$notes)) step$notes
  )
  div(
    class = paste("sw-card", paste0("sw-card-", step$type)), `data-id` = uid,
    div(
      class = "sw-card-row",
      span(class = "sw-drag", title = "Drag to reorder", bsicons::bs_icon("grip-vertical")),
      div(
        class = "sw-card-main",
        div(class = "sw-card-title",
            if (step$type != "exercise" && !identical(label, type_label)) span(class = "sw-type", type_label),
            label),
        div(class = "sw-card-target", step_summary(step)),
        if (length(extras)) div(class = "sw-card-notes", paste(extras, collapse = " · "))
      ),
      div(
        class = "sw-card-actions",
        button("edit", "pencil", "Edit"),
        button("duplicate", "copy", "Duplicate"),
        button("up", "arrow-up", "Move up"),
        button("down", "arrow-down", "Move down"),
        if (!is.na(into)) button("into", if (into == "above") "box-arrow-in-up" else "box-arrow-in-down", "Move into the repeat block"),
        if (nested) button("out", "box-arrow-down", "Move out of the repeat block"),
        button("delete", "trash", "Delete")
      )
    ),
    if (is_block) {
      tagList(
        div(
          class = "sw-block-steps", `data-sw-sortable` = ns("reorder"), `data-container` = uid,
          if (!length(step$steps)) {
            div(class = "sw-empty small", "Empty block: add steps below or move steps into it.")
          } else {
            lapply(step$steps, step_card, w = w, catalog = catalog, ns = ns, nested = TRUE)
          }
        ),
        div(
          class = "sw-block-add",
          tags$button(type = "button", class = "btn btn-sm btn-link", `data-sw-op` = "add_exercise",
                      `data-container` = uid, bsicons::bs_icon("plus-lg"), "Exercise"),
          tags$button(type = "button", class = "btn btn-sm btn-link", `data-sw-op` = "add_rest",
                      `data-container` = uid, bsicons::bs_icon("pause-circle"), "Rest")
        )
      )
    }
  )
}

summary_panel <- function(s) {
  stat <- function(label, value) div(class = "sw-stat", div(class = "sw-stat-value", value), div(class = "sw-stat-label", label))
  duration <- paste0("≈ ", format_duration(s$total_seconds), if (s$open_steps) " +")
  top_focus <- utils::head(names(s$focus), 4)
  div(
    class = "sw-summary",
    div(
      class = "sw-stats",
      stat(if (s$open_steps) "Duration, plus open steps" else "Duration", duration),
      stat("Exercises", s$exercises),
      stat("Sets", s$sets)
    ),
    if (length(top_focus)) div(class = "sw-ex-badges", term_badges(top_focus, "sw-badge-focus")),
    if (length(s$muscles)) div(class = "small", tags$strong("Muscles: "), paste(term_label(s$muscles), collapse = ", ")),
    div(class = "small", tags$strong("Equipment: "),
        if (length(s$equipment)) paste(term_label(s$equipment), collapse = ", ") else "None")
  )
}
