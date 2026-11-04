# Workout library: pure functions for the saved workouts (kept in localStorage as JSON),
# multi-workout YAML files (export all / import), file names and the user's settings.
# A library is a list of entries: list(id, updated, workout). Workouts in the library
# carry no uids.

library_key <- "shiny_workout.library"
settings_key <- "shiny_workout.settings"

new_library_id <- function() {
  paste0("w", format(Sys.time(), "%Y%m%d%H%M%OS3"), sample.int(9999, 1))
}

strip_uids <- function(w) {
  strip <- function(s) {
    s$uid <- NULL
    if (!is.null(s$steps)) s$steps <- lapply(s$steps, strip)
    s
  }
  w$steps <- lapply(w$steps %||% list(), strip)
  w
}

# Add a workout, or replace the entry with `id`. Returns list(entries, id).
library_upsert <- function(entries, w, id = NULL, now = Sys.time()) {
  entry <- list(id = id %||% new_library_id(), updated = format(now, "%Y-%m-%dT%H:%M:%S"),
                workout = strip_uids(w))
  ids <- vapply(entries, `[[`, "", "id")
  at <- match(entry$id, ids)
  if (is.na(at)) entries <- c(list(entry), entries) else entries[[at]] <- entry
  list(entries = entries, id = entry$id)
}

library_remove <- function(entries, id) {
  Filter(function(e) !identical(e$id, id), entries)
}

library_get <- function(entries, id) {
  for (e in entries) if (identical(e$id, id)) return(e)
  NULL
}

library_duplicate <- function(entries, id, now = Sys.time()) {
  e <- library_get(entries, id)
  if (is.null(e)) return(list(entries = entries, id = NULL))
  w <- e$workout
  w$name <- paste(w$name, "(copy)")
  library_upsert(entries, w, now = now)
}

library_rename <- function(entries, id, name, now = Sys.time()) {
  e <- library_get(entries, id)
  name <- trimws(name %||% "")
  if (is.null(e) || !nzchar(name)) return(entries)
  e$workout$name <- name
  library_upsert(entries, e$workout, id, now = now)$entries
}

# Stored as JSON with each workout as YAML text, so the stored form is the file format.
library_to_json <- function(entries) {
  as.character(jsonlite::toJSON(
    lapply(entries, function(e) list(id = e$id, updated = e$updated, yaml = workout_to_yaml(e$workout))),
    auto_unbox = TRUE
  ))
}

# Unreadable entries are skipped, so one bad entry can't lose the rest.
library_from_json <- function(text) {
  if (is.null(text) || !nzchar(text)) return(list())
  raw <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) list())
  entries <- lapply(raw, function(r) {
    w <- tryCatch(workout_from_yaml(r$yaml), error = function(e) NULL)
    if (is.null(w) || is.null(r$id)) return(NULL)
    list(id = r$id, updated = r$updated %||% "", workout = w)
  })
  Filter(Negate(is.null), entries)
}

# Several workouts in one YAML file, separated by "---" lines.
workouts_to_multi_yaml <- function(workouts) {
  paste0("---\n", vapply(workouts, workout_to_yaml, ""), collapse = "")
}

split_yaml_documents <- function(text) {
  lines <- strsplit(text, "\r?\n")[[1]]
  doc <- cumsum(grepl("^---\\s*$", lines))
  docs <- split(lines[!grepl("^---\\s*$", lines)], doc[!grepl("^---\\s*$", lines)])
  docs <- vapply(docs, paste, "", collapse = "\n")
  docs[grepl("[^[:space:]]", docs)]
}

# Each document of an uploaded file, checked. Returns a list of
# list(file, name, workout, errors, warnings); workout is NULL when it can't be used.
import_workouts <- function(text, file, catalog = NULL) {
  docs <- split_yaml_documents(text)
  if (!length(docs)) {
    return(list(list(file = file, name = file, workout = NULL,
                     errors = "The file is empty.", warnings = character())))
  }
  lapply(unname(docs), function(doc) {
    w <- tryCatch(workout_from_yaml(doc), error = function(e) conditionMessage(e))
    if (is.character(w)) {
      return(list(file = file, name = file, workout = NULL, errors = w, warnings = character()))
    }
    v <- validate_workout(w, catalog)
    name <- if (is.character(w$name) && length(w$name) == 1) w$name else file
    list(file = file, name = name, workout = if (!length(v$errors)) w, errors = v$errors,
         warnings = v$warnings)
  })
}

# "Morning core & rehab" -> "morning-core-rehab.yaml"
workout_filename <- function(name) {
  slug <- tolower(gsub("[^A-Za-z0-9]+", "-", name %||% ""))
  slug <- gsub("^-+|-+$", "", slug)
  paste0(if (nzchar(slug)) slug else "workout", ".yaml")
}

# The user's settings layer (Settings dialog), stored as JSON.
user_settings_from_json <- function(text) {
  if (is.null(text) || !nzchar(text)) return(list())
  s <- tryCatch(jsonlite::fromJSON(text, simplifyVector = TRUE), error = function(e) list())
  if (!is.list(s)) return(list())
  s[intersect(names(s), settings_keys)]
}

user_settings_to_json <- function(s) {
  as.character(jsonlite::toJSON(s[intersect(names(s), settings_keys)], auto_unbox = TRUE))
}
