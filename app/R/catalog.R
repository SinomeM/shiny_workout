# Exercise catalog: load, filter by the app config, search and look up exercises.
# The catalog is a data frame with one row per exercise; vector fields (aliases,
# focus, equipment, muscles, instructions, merged_ids) are list columns. It is built
# by data-raw/build_catalog.R.

load_catalog <- function(path = "data/exercises.json", config = NULL) {
  raw <- jsonlite::fromJSON(path)
  ex <- raw$exercises
  flat <- function(col) vapply(col, paste, character(1), collapse = " ")
  ex$search <- tolower(paste(ex$name, flat(ex$aliases), flat(ex$primary_muscles),
                             flat(ex$secondary_muscles)))
  ex$enabled <- catalog_enabled(ex, config$catalog)
  attr(ex, "sources") <- raw$sources
  attr(ex, "index") <- catalog_index(ex)
  ex
}

# An exercise is shown when all its equipment and at least one of its focus areas
# are enabled in config.yml.
catalog_enabled <- function(ex, cfg) {
  if (is.null(cfg)) return(rep(TRUE, nrow(ex)))
  equipment_ok <- vapply(ex$equipment, function(e) all(e %in% cfg$enabled_equipment), logical(1))
  focus_ok <- vapply(ex$focus, function(f) any(f %in% cfg$enabled_focus), logical(1))
  equipment_ok & focus_ok
}

# Row lookup by id, including the ids of exercises merged into another one.
catalog_index <- function(ex) {
  rows <- seq_len(nrow(ex))
  if (is.null(ex$merged_ids)) return(stats::setNames(rows, ex$id))
  stats::setNames(c(rows, rep(rows, lengths(ex$merged_ids))), c(ex$id, unlist(ex$merged_ids)))
}

catalog_row <- function(catalog, id) {
  index <- attr(catalog, "index") %||% catalog_index(catalog)
  unname(index[id])
}

# Filters combine with AND; values within a filter with OR. Every search word must
# appear in the name, an alias or a muscle. Exact, then leading, then other name
# matches come first.
search_catalog <- function(ex, query = "", focus = NULL, equipment = NULL, muscle = NULL,
                           level = NULL, source = NULL, show_all = FALSE) {
  keep <- if (show_all) rep(TRUE, nrow(ex)) else ex$enabled
  words <- strsplit(tolower(trimws(query %||% "")), "\\s+")[[1]]
  for (w in words[nzchar(words)]) keep <- keep & grepl(w, ex$search, fixed = TRUE)
  any_of <- function(col, values) vapply(col, function(x) any(x %in% values), logical(1))
  if (length(focus)) keep <- keep & any_of(ex$focus, focus)
  if (length(equipment)) keep <- keep & any_of(ex$equipment, equipment)
  if (length(muscle)) keep <- keep & any_of(ex$primary_muscles, muscle)
  if (length(level)) keep <- keep & ex$level %in% level
  if (length(source)) keep <- keep & ex$source %in% source
  out <- ex[keep, , drop = FALSE]
  if (length(words) && nzchar(words[1])) {
    q <- paste(words, collapse = " ")
    name <- tolower(out$name)
    rank <- ifelse(name == q, 0, ifelse(startsWith(name, q), 1, ifelse(grepl(q, name, fixed = TRUE), 2, 3)))
    out <- out[order(rank), , drop = FALSE]
  }
  out
}

# Distinct values of a list or character column among the enabled exercises.
catalog_values <- function(ex, field, enabled_only = TRUE) {
  rows <- if (enabled_only) ex$enabled else rep(TRUE, nrow(ex))
  values <- unlist(ex[[field]][rows])
  sort(unique(values[!is.na(values)]))
}

# A new workout step for a catalog exercise, with its suggested target.
step_from_exercise <- function(catalog, id, settings) {
  ex <- catalog[catalog_row(catalog, id), ]
  target <- if (identical(ex$default_target, "seconds")) {
    list(seconds = settings$exercise_seconds)
  } else {
    list(reps = settings$reps)
  }
  do.call(new_step, c(list("exercise", exercise = ex$id), target,
                      list(sides = if (isTRUE(ex$unilateral)) 2L)))
}

term_labels <- c(
  hiit = "HIIT", physio = "Physio", exercise_ball = "Exercise ball", foam_roller = "Foam roller",
  pullup_bar = "Pull-up bar", ez_bar = "EZ bar", medicine_ball = "Medicine ball",
  upper_back = "Upper back", lower_back = "Lower back", hip_flexors = "Hip flexors",
  `free-exercise-db` = "free-exercise-db", wger = "wger", `yoga-api` = "yoga-api",
  shiny_workout = "Curated"
)

# Vocabulary term -> label, e.g. "exercise_ball" -> "Exercise ball".
term_label <- function(x) {
  out <- unname(term_labels[x])
  plain <- is.na(out)
  out[plain] <- vapply(gsub("_", " ", x[plain]), function(s) {
    paste0(toupper(substring(s, 1, 1)), substring(s, 2))
  }, character(1), USE.NAMES = FALSE)
  out
}
