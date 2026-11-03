# Workout <-> YAML. Writing uses a stable key order, drops empty fields and internal
# UI ids (`uid`), and writes whole numbers without ".0", so files stay easy to read
# and diff. Reading only parses; check the result with validate_workout().

workout_to_yaml <- function(w) {
  yaml::as.yaml(
    tidy_workout(w),
    indent.mapping.sequence = TRUE,
    handlers = list(logical = yaml::verbatim_logical)
  )
}

write_workout <- function(w, path) {
  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con))
  writeLines(workout_to_yaml(w), con, sep = "")
}

workout_from_yaml <- function(text) {
  w <- tryCatch(
    yaml::yaml.load(text),
    error = function(e) stop("This file is not valid YAML: ", conditionMessage(e), call. = FALSE)
  )
  if (!is.list(w) || is.null(names(w))) {
    stop("This file is not a workout: expected fields such as name and steps.", call. = FALSE)
  }
  w
}

read_workout <- function(path) {
  workout_from_yaml(paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n"))
}

tidy_workout <- function(w) {
  w <- tidy_fields(w, workout_fields)
  if (!is.null(w$tags)) w$tags <- as.list(w$tags)
  if (!is.null(w$settings)) w$settings <- tidy_fields(w$settings, settings_keys)
  w$steps <- lapply(w$steps %||% list(), tidy_step)
  w
}

tidy_step <- function(s) {
  s <- tidy_fields(s, if (identical(s$type, "repeat")) repeat_fields else step_fields)
  if (!is.null(s$steps)) s$steps <- lapply(s$steps, tidy_step)
  s
}

# Known fields first in schema order, unknown ones after (kept, so files written by a
# newer version survive a round trip); NULLs and `uid` dropped; 30.0 -> 30.
tidy_fields <- function(x, order) {
  x <- x[setdiff(names(x), "uid")]
  x <- x[!vapply(x, is.null, logical(1))]
  x <- x[c(intersect(order, names(x)), setdiff(names(x), order))]
  lapply(x, function(v) {
    if (is.double(v) && length(v) == 1 && !is.na(v) && v == round(v) && abs(v) < 1e9) {
      as.integer(v)
    } else {
      v
    }
  })
}
