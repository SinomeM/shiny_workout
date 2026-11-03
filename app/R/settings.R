# Default values, resolved in layers: app config.yml -> user Settings panel -> the
# workout's own `settings:` block. Later layers win; invalid values fall through.

settings_keys <- c(
  "prep_seconds", "rest_seconds", "reps", "exercise_seconds", "hold_seconds",
  "relax_seconds", "switch_seconds", "seconds_per_rep"
)

# Settings that may be 0 (meaning "skip"); the others must be above 0.
settings_zero_ok <- c("prep_seconds", "rest_seconds", "relax_seconds", "switch_seconds")

read_app_config <- function(path = "config.yml") {
  config <- yaml::read_yaml(path)
  check <- validate_settings(config$defaults, partial = FALSE)
  if (length(check$errors)) {
    stop("Invalid defaults in ", path, ": ", paste(check$errors, collapse = " "), call. = FALSE)
  }
  config
}

setting_ok <- function(key, x) {
  if (!is.numeric(x) || length(x) != 1 || is.na(x) || !is.finite(x)) return(FALSE)
  if (key == "reps") return(x == round(x) && x >= 1)
  if (key %in% settings_zero_ok) x >= 0 else x > 0
}

# Returns list(errors, warnings). With partial = FALSE every key must be present.
validate_settings <- function(s, partial = TRUE) {
  errors <- character()
  warnings <- character()
  if (is.null(s)) s <- list()
  if (!is.list(s) || (length(s) && is.null(names(s)))) {
    return(list(errors = "settings must be a mapping of names to numbers.", warnings = warnings))
  }
  unknown <- setdiff(names(s), settings_keys)
  if (length(unknown)) {
    warnings <- c(warnings, paste0("ignored unknown setting(s): ", paste(unknown, collapse = ", "), "."))
  }
  for (key in intersect(names(s), settings_keys)) {
    if (!setting_ok(key, s[[key]])) {
      rule <- if (key == "reps") "a whole number of at least 1"
              else if (key %in% settings_zero_ok) "a number of 0 or more"
              else "a number above 0"
      errors <- c(errors, sprintf("%s must be %s.", key, rule))
    }
  }
  if (!partial) {
    missing <- setdiff(settings_keys, names(s))
    if (length(missing)) {
      errors <- c(errors, paste0("missing setting(s): ", paste(missing, collapse = ", "), "."))
    }
  }
  list(errors = errors, warnings = warnings)
}

# resolve_settings(app, user, workout): merge layers, later ones win. The first layer
# must be complete (the app defaults); invalid or unknown values are ignored.
resolve_settings <- function(...) {
  out <- list()
  for (layer in list(...)) {
    if (!is.list(layer)) next
    for (key in intersect(names(layer), settings_keys)) {
      if (setting_ok(key, layer[[key]])) out[[key]] <- layer[[key]]
    }
  }
  missing <- setdiff(settings_keys, names(out))
  if (length(missing)) stop("Missing setting(s): ", paste(missing, collapse = ", "), call. = FALSE)
  out[settings_keys]
}
