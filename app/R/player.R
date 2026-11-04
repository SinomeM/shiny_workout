# Player: pure functions behind the Run tab. R compiles the workout into a plan once;
# www/player.js runs it with its own clock and reports a session log at the end.

player_kind_labels <- c(
  prep = "Get ready", switch = "Switch sides", warmup = "Warm-up", exercise = "Exercise",
  rest = "Rest", cooldown = "Cool-down"
)

# Sports that get the softer chime sounds.
soft_sports <- c("yoga", "pilates", "physio")

# "1 minute 30 seconds", for the voice.
spoken_duration <- function(seconds) {
  s <- round(seconds)
  m <- s %/% 60
  r <- s %% 60
  unit <- function(n, word) sprintf("%d %s%s", n, word, if (n == 1) "" else "s")
  parts <- c(if (m > 0) unit(m, "minute"), if (r > 0 || m == 0) unit(r, "second"))
  paste(parts, collapse = " ")
}

# What to do, shown under the clock ("12 reps", "10 × 5 s hold") and spoken.
step_target <- function(reps, seconds, hold, spoken = FALSE) {
  if (!is.na(hold)) {
    if (spoken) return(sprintf("%d reps, %s hold", reps, sub("seconds?$", "second", spoken_duration(hold))))
    return(sprintf("%d × %s s hold", reps, format(hold)))
  }
  if (!is.na(reps)) return(sprintf("%d rep%s", reps, if (reps == 1) "" else "s"))
  if (spoken && !is.na(seconds)) return(spoken_duration(seconds))
  NA_character_
}

# The plan player.js runs: one entry per atomic step, plus the repeat blocks so the end
# screen can count completed rounds. `duration` is NA for steps that wait for Space with
# no time limit; guided reps last reps × hold + (reps - 1) × relax.
player_plan <- function(w, settings, catalog = NULL) {
  df <- compile_workout(w, settings, catalog)
  n <- nrow(df)
  guided <- !is.na(df$hold_seconds)
  duration <- ifelse(!is.na(df$seconds), df$seconds,
                     ifelse(guided, df$reps * df$hold_seconds + (df$reps - 1) * df$relax_seconds, NA))
  title <- ifelse(is.na(df$side), df$label, paste0(df$label, " · ", df$side))
  target <- vapply(seq_len(n), function(i) step_target(df$reps[i], df$seconds[i], df$hold_seconds[i]), "")
  spoken <- vapply(seq_len(n), function(i) {
    step_target(df$reps[i], df$seconds[i], df$hold_seconds[i], spoken = TRUE)
  }, "")
  say <- ifelse(is.na(df$side), df$label, paste0(df$label, ", ", tolower(df$side)))
  say <- ifelse(is.na(spoken), say, paste0(say, ". ", spoken))
  shown <- vapply(seq_len(n), function(i) {
    if (!is.na(target[i])) paste0(title[i], " · ", target[i])
    else if (!is.na(duration[i])) paste0(title[i], " · ", format_duration(duration[i]))
    else title[i]
  }, "")
  next_text <- c(shown[-1], NA_character_)[seq_len(n)]
  # Rests announce what comes next, so there is time to get in position.
  speech <- vapply(seq_len(n), function(i) {
    if (df$kind[i] == "switch") return("Switch sides.")
    if (!df$kind[i] %in% c("prep", "rest")) return(paste0(say[i], "."))
    out <- df$label[i]
    if (!is.na(df$seconds[i])) out <- paste0(out, ", ", spoken_duration(df$seconds[i]))
    if (i < n) out <- paste0(out, ". Next: ", say[i + 1])
    paste0(out, ".")
  }, "")
  round_n <- suppressWarnings(as.integer(sub("^Round (\\d+)/.*$", "\\1", df$round)))

  steps <- lapply(seq_len(n), function(i) {
    list(
      index = i, kind = df$kind[i], kind_label = player_kind_labels[[df$kind[i]]],
      label = df$label[i], title = title[i], sub =paste(stats::na.omit(c(df$round[i], df$side[i])), collapse = " · "),
      round = df$round[i], side = df$side[i], block = df$block[i], round_n = round_n[i],
      reps = df$reps[i], hold = df$hold_seconds[i], relax = df$relax_seconds[i],
      duration = duration[i], auto = df$advance[i] == "auto",
      target = target[i], speech = speech[i], next_text = next_text[i],
      notes = df$notes[i], weight = df$weight[i], est = df$est_seconds[i]
    )
  })
  blocks <- Filter(Negate(is.null), lapply(seq_along(w$steps), function(i) {
    st <- w$steps[[i]]
    if (st$type == "repeat") list(block = i, label = sprintf("rounds of block %d", i), times = st$times)
  }))
  est <- df$est_seconds
  list(
    name = w$name, sport = w$sport %||% NA_character_, soft = isTRUE(w$sport %in% soft_sports),
    total = sum(est, na.rm = TRUE), open_steps = sum(is.na(est)), steps = steps, blocks = blocks
  )
}

# Session log -------------------------------------------------------------

# `x` is the log player.js sends at the end (parsed JSON). Returns a tidy list in the
# order it is written to YAML.
session_log <- function(x) {
  num <- function(v) if (is.null(v)) NULL else as.integer(round(as.numeric(v)))
  entries <- lapply(x$entries, function(e) {
    out <- list(step = e$title, kind = e$kind, round = e$round, side = e$side,
                planned_seconds = num(e$planned), actual_seconds = num(e$actual), ended = e$ended)
    out[!vapply(out, function(v) is.null(v) || (length(v) == 1 && is.na(v)), logical(1))]
  })
  list(
    workout = x$workout,
    started = x$started,
    finished = x$finished,
    completed = isTRUE(x$completed),
    active_time = format_duration(num(x$active_seconds) %||% 0),
    total_time = format_duration(num(x$wall_seconds) %||% 0),
    steps_done = sum(vapply(entries, function(e) isTRUE(e$ended %in% c("done", "auto")), logical(1))),
    steps_skipped = sum(vapply(entries, function(e) identical(e$ended, "skipped"), logical(1))),
    steps = entries
  )
}

session_log_to_yaml <- function(log) {
  yaml::as.yaml(log, indent.mapping.sequence = TRUE, handlers = list(logical = yaml::verbatim_logical))
}

session_log_filename <- function(name, date = Sys.Date()) {
  paste0(sub("\\.yaml$", "", workout_filename(name)), "-log-", format(date), ".yaml")
}
