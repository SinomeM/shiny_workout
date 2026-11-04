placeholder_card <- function(title, text) {
  card(
    card_header(title),
    p(class = "text-muted mb-0", text)
  )
}

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
    p("Code: ", tags$a(href = "https://github.com/SinomeM/shiny_workout", target = "_blank",
                       rel = "noopener", "github.com/SinomeM/shiny_workout"), " (GPL-3.0)."),
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
