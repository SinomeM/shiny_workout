# Workout model: pure functions to create, validate, compile and estimate workouts.
# A workout is a plain list that mirrors the YAML schema (docs/workout-format.md).
# A catalog, where used, is a data frame with at least `id` and `name` columns.

schema_version <- 1L
step_types <- c("warmup", "exercise", "rest", "cooldown", "repeat")
advance_modes <- c("auto", "manual")
sports <- c("strength", "hiit", "mobility", "yoga", "pilates", "physio")

workout_fields <- c("schema_version", "name", "description", "sport", "tags", "settings", "steps")
step_fields <- c(
  "type", "exercise", "name", "reps", "seconds", "hold_seconds", "relax_seconds",
  "sides", "advance", "weight", "notes"
)
repeat_fields <- c("type", "times", "skip_last_rest", "steps")

type_labels <- c(
  warmup = "Warm-up", exercise = "Exercise", rest = "Rest", cooldown = "Cool-down",
  `repeat` = "Repeat"
)

# Constructors -------------------------------------------------------------

new_workout <- function(name = "New workout", steps = list(), description = NULL,
                        sport = NULL, tags = NULL, settings = NULL) {
  w <- list(schema_version = schema_version, name = name, description = description,
            sport = sport, tags = tags, settings = settings)
  w <- w[!vapply(w, is.null, logical(1))]
  w$steps <- steps
  w
}

new_step <- function(type, ...) {
  type <- match.arg(type, step_types)
  fields <- list(...)
  step <- c(list(type = type), fields[!vapply(fields, is.null, logical(1))])
  if (type == "repeat") {
    step$times <- step$times %||% 2L
    step$steps <- step$steps %||% list()
  } else {
    step$advance <- step$advance %||% default_advance(step)
  }
  step
}

# A step moves on by itself when it has a time to count down, otherwise on Space.
default_advance <- function(step) {
  if (!is.null(step$seconds) || !is.null(step$hold_seconds)) "auto" else "manual"
}

step_advance <- function(step) step$advance %||% default_advance(step)

step_label <- function(step, catalog = NULL) {
  if (!is.null(step$name)) return(step$name)
  if (!is.null(step$exercise)) {
    if (is.null(catalog)) return(step$exercise)
    row <- catalog_row(catalog, step$exercise)
    return(if (is.na(row)) paste0("Unknown exercise (", step$exercise, ")") else catalog$name[row])
  }
  if (step$type == "repeat") return(sprintf("Repeat × %d", step$times))
  unname(type_labels[[step$type]])
}

# Validation ---------------------------------------------------------------

is_count <- function(x, min = 1) {
  is.numeric(x) && length(x) == 1 && !is.na(x) && x == round(x) && x >= min
}
is_positive <- function(x) {
  is.numeric(x) && length(x) == 1 && !is.na(x) && is.finite(x) && x > 0
}
is_text <- function(x) is.character(x) && length(x) == 1 && !is.na(x) && nzchar(trimws(x))
is_flag <- function(x) is.logical(x) && length(x) == 1 && !is.na(x)
show_value <- function(x) if (is.null(x)) "nothing" else paste(format(x), collapse = ", ")

# Returns list(errors, warnings). Errors block loading, saving and running; warnings
# are shown but the workout still works (e.g. an unknown exercise id).
validate_workout <- function(w, catalog = NULL) {
  errors <- character()
  warnings <- character()
  err <- function(...) errors <<- c(errors, paste0(...))
  warn <- function(...) warnings <<- c(warnings, paste0(...))

  if (!is.list(w) || is.null(names(w))) {
    err("This is not a workout: expected fields such as name and steps.")
    return(list(errors = errors, warnings = warnings))
  }

  v <- w$schema_version
  if (is.null(v)) {
    warn("No schema_version: assuming version ", schema_version, ".")
  } else if (!is_count(v)) {
    err("schema_version must be a whole number.")
  } else if (v > schema_version) {
    err("This workout uses format version ", v, ", but this app only reads up to version ",
        schema_version, ".")
  }
  if (!is_text(w$name)) err("The workout needs a name.")
  if (!is.null(w$description) && !(is.character(w$description) && length(w$description) == 1)) {
    err("description must be text.")
  }
  if (!is.null(w$sport) && !(is_text(w$sport) && w$sport %in% sports)) {
    warn("Unknown sport '", show_value(w$sport), "'; expected one of: ",
         paste(sports, collapse = ", "), ".")
  }
  if (!is.null(w$tags) && !is.character(w$tags)) err("tags must be a list of words.")
  if (!is.null(w$settings)) {
    s <- validate_settings(w$settings)
    errors <- c(errors, paste("settings:", s$errors)[length(s$errors) > 0])
    warnings <- c(warnings, paste("settings:", s$warnings)[length(s$warnings) > 0])
  }
  extra <- setdiff(names(w), workout_fields)
  if (length(extra)) warn("Ignored unknown field(s): ", paste(extra, collapse = ", "), ".")

  check_step <- function(s, path, depth) {
    at <- paste0("Step ", paste(path, collapse = "."), ": ")
    if (!is.list(s) || is.null(names(s))) {
      return(err(at, "not a step (expected a type and a target such as reps or seconds)."))
    }
    type <- s$type
    if (!is_text(type) || !type %in% step_types) {
      return(err(at, "unknown type '", show_value(type), "'; expected one of: ",
                 paste(step_types, collapse = ", "), "."))
    }
    known <- if (type == "repeat") repeat_fields else step_fields
    extra <- setdiff(names(s), c(known, "uid"))
    if (length(extra)) warn(at, "ignored unknown field(s): ", paste(extra, collapse = ", "), ".")

    if (type == "repeat") {
      if (!is_count(s$times)) err(at, "repeat needs times, a whole number of at least 1.")
      if (!is.null(s$skip_last_rest) && !is_flag(s$skip_last_rest)) {
        err(at, "skip_last_rest must be true or false.")
      }
      if (depth >= 1) err(at, "repeat blocks inside repeat blocks are not supported yet.")
      if (!is.list(s$steps) || length(s$steps) == 0) {
        err(at, "the repeat block has no steps.")
      } else {
        for (i in seq_along(s$steps)) check_step(s$steps[[i]], c(path, i), depth + 1)
      }
      return(invisible())
    }

    has_reps <- !is.null(s$reps)
    has_seconds <- !is.null(s$seconds)
    has_hold <- !is.null(s$hold_seconds)
    if (has_reps && !is_count(s$reps)) err(at, "reps must be a whole number of at least 1.")
    if (has_seconds && !is_positive(s$seconds)) err(at, "seconds must be a number above 0.")
    if (has_hold) {
      if (!is_positive(s$hold_seconds)) err(at, "hold_seconds must be a number above 0.")
      if (!has_reps) err(at, "hold_seconds needs reps (e.g. 10 reps with a 5 s hold).")
    }
    if (!is.null(s$relax_seconds)) {
      zero <- is.numeric(s$relax_seconds) && identical(as.numeric(s$relax_seconds), 0)
      if (!is_positive(s$relax_seconds) && !zero) {
        err(at, "relax_seconds must be a number of 0 or more.")
      }
      if (!has_hold) warn(at, "relax_seconds is only used together with hold_seconds.")
    }
    if (!is.null(s$sides) && !(is_count(s$sides) && s$sides %in% 1:2)) {
      err(at, "sides must be 1 or 2.")
    }
    if (!is.null(s$advance) && !(is_text(s$advance) && s$advance %in% advance_modes)) {
      err(at, "advance must be auto or manual.")
    } else if (step_advance(s) == "auto" && !has_seconds && !has_hold) {
      err(at, "advance: auto needs seconds (or hold_seconds) to know when to move on.")
    }
    for (f in c("exercise", "name", "weight", "notes")) {
      if (!is.null(s[[f]]) && !is_text(s[[f]])) err(at, f, " must be text.")
    }
    if (type == "rest") {
      bad <- intersect(names(s), c("exercise", "name", "reps", "hold_seconds", "relax_seconds",
                                   "sides", "weight"))
      if (length(bad)) {
        err(at, "rest steps only take seconds, advance and notes (found ",
            paste(bad, collapse = ", "), ").")
      }
    }
    if (type == "exercise" && is.null(s$exercise) && is.null(s$name)) {
      err(at, "exercise steps need an exercise id or a name.")
    }
    if (!is.null(catalog) && is_text(s$exercise) && is.na(catalog_row(catalog, s$exercise))) {
      warn(at, "unknown exercise '", s$exercise, "'.")
    }
  }

  if (!is.list(w$steps) || length(w$steps) == 0) {
    err("The workout has no steps.")
  } else {
    for (i in seq_along(w$steps)) check_step(w$steps[[i]], i, 0)
  }
  list(errors = errors, warnings = warnings)
}

# Compiling ----------------------------------------------------------------

# One atomic step of the player. All fields are always present (NA when unused), so
# a list of atoms binds into a data frame with fixed columns.
atom <- function(kind, label, exercise = NA_character_, side = NA_character_,
                 round = NA_character_, reps = NA_integer_, seconds = NA_real_,
                 hold_seconds = NA_real_, relax_seconds = NA_real_, advance = "auto",
                 notes = NA_character_, weight = NA_character_, path = NA_character_) {
  list(kind = kind, label = label, exercise = exercise, side = side, round = round,
       reps = as.integer(reps), seconds = as.numeric(seconds),
       hold_seconds = as.numeric(hold_seconds), relax_seconds = as.numeric(relax_seconds),
       advance = advance, notes = notes, weight = weight, path = path)
}

atoms_to_df <- function(atoms) {
  atoms <- c(list(atom("prep", "")), atoms)  # template row keeps the column types
  cols <- names(atoms[[1]])
  df <- as.data.frame(
    lapply(stats::setNames(cols, cols), function(f) unlist(lapply(atoms, `[[`, f))),
    stringsAsFactors = FALSE
  )[-1, , drop = FALSE]
  rownames(df) <- NULL
  df
}

# Flattens a valid workout into the list of steps the player runs: a "get ready"
# step, repeats expanded per round, sides expanded into Left / switch / Right, names
# resolved, plus an estimate and a preview of the next step. `settings` are the app
# and user layers; the workout's own `settings:` are applied on top.
compile_workout <- function(w, settings, catalog = NULL) {
  s <- resolve_settings(settings, w$settings)

  compile_step <- function(st, path, rounds) {
    round <- if (length(rounds)) paste("Round", paste(rounds, collapse = " · ")) else NA
    path <- paste(path, collapse = ".")
    one_side <- function(side) {
      atom(st$type, step_label(st, catalog), exercise = st$exercise %||% NA, side = side,
           round = round, reps = st$reps %||% NA, seconds = st$seconds %||% NA,
           hold_seconds = st$hold_seconds %||% NA,
           relax_seconds = if (is.null(st$hold_seconds)) NA else st$relax_seconds %||% s$relax_seconds,
           advance = step_advance(st), notes = st$notes %||% NA, weight = st$weight %||% NA,
           path = path)
    }
    if (!isTRUE(st$sides == 2)) return(list(one_side(NA)))
    switch_step <- if (s$switch_seconds > 0) {
      list(atom("switch", "Switch sides", round = round, seconds = s$switch_seconds, path = path))
    }
    c(list(one_side("Left")), switch_step, list(one_side("Right")))
  }

  compile_steps <- function(steps, path, rounds) {
    out <- list()
    for (i in seq_along(steps)) {
      st <- steps[[i]]
      if (st$type != "repeat") {
        out <- c(out, compile_step(st, c(path, i), rounds))
        next
      }
      for (r in seq_len(st$times)) {
        inner <- st$steps
        if (r == st$times && isTRUE(st$skip_last_rest)) inner <- drop_trailing_rest(inner)
        out <- c(out, compile_steps(inner, c(path, i), c(rounds, sprintf("%d/%d", r, st$times))))
      }
    }
    out
  }

  prep <- if (s$prep_seconds > 0) list(atom("prep", "Get ready", seconds = s$prep_seconds))
  df <- atoms_to_df(c(prep, compile_steps(w$steps, character(), character())))

  df$block <- suppressWarnings(as.integer(sub("\\..*", "", df$path)))
  df$est_seconds <- ifelse(
    !is.na(df$seconds), df$seconds,
    ifelse(!is.na(df$hold_seconds),
           df$reps * df$hold_seconds + (df$reps - 1) * df$relax_seconds,
           df$reps * s$seconds_per_rep)
  )
  title <- ifelse(is.na(df$side), df$label, paste0(df$label, " · ", df$side))
  df$next_label <- c(title[-1], NA_character_)[seq_len(nrow(df))]
  cbind(index = seq_len(nrow(df)), df)
}

drop_trailing_rest <- function(steps) {
  while (length(steps) && steps[[length(steps)]]$type == "rest") steps <- steps[-length(steps)]
  steps
}

# Estimates ----------------------------------------------------------------

# Total and per top-level block, in seconds. Open steps (manual, no reps or time)
# can't be estimated: they count as 0 and are reported in `open_steps`.
estimate_duration <- function(w, settings, catalog = NULL) {
  steps <- compile_workout(w, settings, catalog)
  est <- steps$est_seconds
  blocks <- data.frame(
    block = seq_along(w$steps),
    label = vapply(w$steps, step_label, character(1), catalog = catalog),
    seconds = vapply(seq_along(w$steps), function(i) sum(est[which(steps$block == i)], na.rm = TRUE), numeric(1)),
    open_steps = vapply(seq_along(w$steps), function(i) sum(is.na(est[which(steps$block == i)])), integer(1)),
    stringsAsFactors = FALSE
  )
  list(total_seconds = sum(est, na.rm = TRUE), open_steps = sum(is.na(est)), blocks = blocks)
}
