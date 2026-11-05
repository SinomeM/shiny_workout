app_version <- "1.0.0"
repo_url <- "https://github.com/SinomeM/shiny_workout"

# Seconds as "m:ss", or "h:mm:ss" from one hour up. NA stays NA.
format_duration <- function(seconds) {
  s <- round(seconds)
  out <- ifelse(
    s >= 3600,
    sprintf("%d:%02d:%02d", s %/% 3600, (s %% 3600) %/% 60, s %% 60),
    sprintf("%d:%02d", s %/% 60, s %% 60)
  )
  out[is.na(s)] <- NA_character_
  out
}

about_modal <- function(sources) {
  rows <- lapply(seq_len(nrow(sources)), function(i) {
    s <- sources[i, ]
    tags$tr(
      tags$td(tags$a(href = s$url, target = "_blank", rel = "noopener", s$name)),
      tags$td(tags$a(href = s$license_url, target = "_blank", rel = "noopener", s$license)),
      tags$td(s$version)
    )
  })
  modalDialog(
    title = "About & credits",
    easyClose = TRUE,
    size = "l",
    p("shiny_workout builds, saves and runs workout routines in your browser. It is an R",
      "Shiny app running on WebAssembly, so nothing is sent to a server."),
    p("Your workouts and settings stay in this browser (its local storage). Download them as",
      "YAML files to keep a backup or move them to another device."),
    p("Version ", app_version, " · code: ",
      tags$a(href = repo_url, target = "_blank", rel = "noopener", "github.com/SinomeM/shiny_workout"),
      " (GPL-3.0)."),
    h5("Exercise catalog"),
    p("The catalog combines the sources below and is published under CC-BY-SA 4.0. Each",
      "exercise's details show its own source and license."),
    tags$table(
      class = "table table-sm",
      tags$thead(tags$tr(tags$th("Source"), tags$th("License"), tags$th("Version"))),
      tags$tbody(rows)
    ),
    p(class = "small text-muted",
      "Physiotherapy exercises are general examples, not medical advice; follow your",
      "physiotherapist's prescription."),
    footer = modalButton("Close")
  )
}

# A missing number as an empty input box. Passing NA to numericInput() or
# updateNumericInput() writes the text "NA", which browsers reject with a warning.
blank_na <- function(x) if (is.null(x) || (length(x) == 1 && is.na(x))) NULL else x

help_modal <- function() {
  key <- function(k, what) tags$tr(tags$td(tags$kbd(k)), tags$td(what))
  link <- function(path, text) tags$a(href = paste0(repo_url, "/blob/main/", path), target = "_blank",
                                      rel = "noopener", text, .noWS = "after")
  modalDialog(
    title = "Help",
    easyClose = TRUE,
    size = "l",
    h5("Build"),
    tags$ul(
      tags$li("Find exercises in the catalog (on a phone: ", tags$em("Browse catalog", .noWS = "after"),
              ") and press ", tags$strong("+"), " to add one. Click a name for its details."),
      tags$li("Each step counts reps (moves on when you press Space) or time (moves on by itself).",
              " Edit a step to change its target, add holds, do each side, or add notes."),
      tags$li("Drag steps to reorder them. A ", tags$em("Repeat block"), " runs its steps several rounds."),
      tags$li(tags$em("Timing for this workout"), " overrides your defaults (Settings) for one workout.")
    ),
    h5("Save and share"),
    tags$ul(
      tags$li(tags$strong("Save"), " keeps the workout in this browser's library (Library tab)."),
      tags$li(tags$strong("Download"), " saves it as a YAML file you can back up, edit by hand ",
              "or import elsewhere. The format is described in ", link("docs/workout-format.md", "workout-format.md"), ".")
    ),
    h5("Run"),
    tags$table(
      class = "table table-sm",
      tags$tbody(
        key("Space", "Done, next step (also starts the workout)"),
        key("P", "Pause or resume (or tap the screen)"),
        key("\u2190 \u2192", "Previous / next step"),
        key("Esc", "Stop (asks first)"),
        key("F", "Full screen"),
        key("S / V", "Sound / voice on or off"),
        key("?", "This help")
      )
    ),
    p(class = "small text-muted mb-0", "Voice works best in Chrome; in Firefox it may crackle."),
    footer = modalButton("Close")
  )
}
