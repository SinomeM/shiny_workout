# One line per compiled step, for readable snapshots of compile_workout().
describe_steps <- function(steps) {
  target <- character(nrow(steps))
  for (i in seq_len(nrow(steps))) {
    s <- steps[i, ]
    parts <- c(
      if (!is.na(s$reps)) paste(s$reps, "reps"),
      if (!is.na(s$hold_seconds)) sprintf("hold %gs relax %gs", s$hold_seconds, s$relax_seconds),
      if (!is.na(s$seconds)) paste0(s$seconds, "s"),
      s$advance
    )
    target[i] <- paste(parts, collapse = " ")
  }
  sprintf(
    "%2d %-8s %-28s %-5s %-11s %-26s ~%s",
    steps$index, steps$kind, steps$label, ifelse(is.na(steps$side), "", steps$side),
    ifelse(is.na(steps$round), "", sub("Round ", "R", steps$round)), target,
    ifelse(is.na(steps$est_seconds), "open", paste0(steps$est_seconds, "s"))
  )
}
