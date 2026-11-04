# Run tab. R renders the layout and the "ready" screen and sends the plan; player.js
# does everything while the workout runs (clock, keys, sounds, voice, wake lock) and
# sends the session log back when asked to download it.

player_ui <- function(id) {
  ns <- NS(id)
  icon <- function(name, class = NULL) span(class = class, bsicons::bs_icon(name))
  control <- function(act, label, ..., class = "btn-outline-secondary") {
    tags$button(type = "button", class = paste("btn", class), `data-pact` = act,
                title = label, `aria-label` = label, ...)
  }
  div(
    class = "sw-player", `data-sw-player` = ns(""), `data-state` = "idle",
    div(
      class = "sw-p-bar",
      span(class = "sw-p-workout", `data-p` = "workout"),
      div(class = "sw-p-progress progress", role = "progressbar",
          div(class = "progress-bar", `data-p` = "progress")),
      span(class = "sw-p-times", `data-p` = "times"),
      div(
        class = "sw-p-prefs",
        control("sound", "Sound on/off (S)", icon("bell", "sw-on"), icon("bell-slash", "sw-off"),
                class = "btn-sm btn-link"),
        control("voice", "Voice on/off (V)", icon("megaphone", "sw-on"), icon("volume-mute", "sw-off"),
                class = "btn-sm btn-link"),
        tags$select(class = "form-select form-select-sm sw-p-voice", `data-pact` = "voicename",
                    title = "Voice", `aria-label` = "Voice"),
        span(class = "sw-p-voice-note small text-warning", "Voice may crackle in Firefox; Chrome sounds better."),
        tags$input(type = "range", class = "form-range sw-p-volume", min = 0, max = 1, step = 0.1,
                   `data-pact` = "volume", title = "Volume", `aria-label` = "Volume"),
        control("full", "Full screen (F)", icon("arrows-fullscreen", "sw-off"),
                icon("fullscreen-exit", "sw-on"), class = "btn-sm btn-link")
      )
    ),
    div(class = "sw-p-ready", uiOutput(ns("ready"))),
    div(
      class = "sw-p-run",
      div(
        class = "sw-p-stage", `data-pact` = "tap",
        div(class = "sw-p-kind", `data-p` = "kind"),
        div(class = "sw-p-title", `data-p` = "title"),
        div(class = "sw-p-sub", `data-p` = "sub"),
        div(class = "sw-p-clock", `data-p` = "clock"),
        div(class = "sw-p-target", `data-p` = "target"),
        div(class = "sw-p-hint", `data-p` = "hint"),
        div(class = "sw-p-notes", `data-p` = "notes")
      ),
      div(class = "sw-p-next", span(class = "sw-p-next-label", "Next"), span(`data-p` = "next")),
      div(
        class = "sw-p-controls",
        control("prev", "Previous step (←)", icon("skip-start-fill")),
        control("pause", "Pause / resume (P)", icon("pause-fill", "sw-off"), icon("play-fill", "sw-on")),
        control("done", "Done, next step (Space)", icon("check-lg"), " Done", class = "btn-primary btn-lg sw-p-done"),
        control("next", "Skip to next step (→)", icon("skip-end-fill")),
        control("stop", "Stop (Esc)", icon("stop-fill"))
      ),
      div(
        class = "sw-p-confirm",
        div(
          class = "sw-p-confirm-box",
          div(class = "fs-4 mb-3", "Stop the workout?"),
          div(class = "d-flex gap-2 justify-content-center",
              control("resume", "Keep going", "Keep going (Space)"),
              control("end", "Stop", "Stop (Esc)", class = "btn-danger"))
        )
      )
    ),
    div(
      class = "sw-p-end",
      div(class = "sw-p-end-title", `data-p` = "end-title"),
      div(class = "sw-stats mb-3", `data-p` = "end-stats"),
      div(class = "d-flex flex-wrap gap-2 mb-3",
          control("again", "Run again", icon("arrow-repeat"), " Run again", class = "btn-primary"),
          control("log", "Download the session log", icon("download"), " Download log"),
          control("edit", "Back to the editor", icon("pencil"), " Back to editor")),
      div(class = "sw-p-end-table", `data-p` = "end-table")
    )
  )
}

player_server <- function(id, workout, settings, catalog, active, go_build) {
  moduleServer(id, function(input, output, session) {
    checked <- reactive({
      w <- workout()
      check <- validate_workout(w, catalog)
      plan <- if (!length(check$errors)) player_plan(w, settings(), catalog)
      list(w = w, errors = check$errors, plan = plan)
    })

    # Sent only while the Run tab is open, so editing doesn't recompile in the background.
    observe({
      req(active())
      session$sendCustomMessage("sw-player-load", list(plan = checked()$plan))
    })

    output$ready <- renderUI(ready_screen(checked()))

    observeEvent(input$log, {
      log <- session_log(jsonlite::fromJSON(input$log, simplifyVector = FALSE))
      session$sendCustomMessage("sw-download", list(filename = session_log_filename(log$workout),
                                                    text = session_log_to_yaml(log)))
    })
    observeEvent(input$edit, go_build())
  })
}

ready_screen <- function(x) {
  w <- x$w
  if (length(x$errors)) {
    return(div(
      class = "sw-p-intro",
      h2(w$name),
      div(class = "alert alert-warning",
          p(class = "mb-1", "This workout can't run yet. Fix these in the editor first:"),
          tags$ul(class = "mb-0", lapply(x$errors, tags$li))),
      tags$button(type = "button", class = "btn btn-outline-primary", `data-pact` = "edit",
                  bsicons::bs_icon("pencil"), " Back to editor")
    ))
  }
  p <- x$plan
  work <- sum(vapply(p$steps, function(s) s$kind %in% c("warmup", "exercise", "cooldown"), logical(1)))
  key <- function(k, what) tags$tr(tags$td(tags$kbd(k)), tags$td(what))
  div(
    class = "sw-p-intro",
    h2(w$name),
    if (!is.null(w$description)) p(class = "text-muted", w$description),
    div(
      class = "sw-stats mb-4",
      div(div(class = "sw-stat-value", paste0("≈ ", format_duration(p$total), if (p$open_steps) " +")),
          div(class = "small text-muted", if (p$open_steps) sprintf("plus %d open step%s", p$open_steps,
                                                                   if (p$open_steps == 1) "" else "s")
              else "estimated")),
      div(div(class = "sw-stat-value", work), div(class = "small text-muted", "exercise steps")),
      div(div(class = "sw-stat-value", length(p$steps)), div(class = "small text-muted", "steps in all"))
    ),
    tags$button(type = "button", class = "btn btn-primary btn-lg px-5", `data-pact` = "start",
                bsicons::bs_icon("play-fill"), " Start"),
    span(class = "ms-2 text-muted small", "or press Space"),
    tags$table(
      class = "table table-sm sw-p-keys mt-4",
      tags$tbody(
        key("Space", "Done / next step"), key("P", "Pause or resume (or tap the screen)"),
        key("← →", "Previous / next step"), key("Esc", "Stop"), key("F", "Full screen"),
        key("S / V", "Sound / voice on or off")
      )
    )
  )
}
