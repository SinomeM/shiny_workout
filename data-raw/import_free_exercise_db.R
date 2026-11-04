# free-exercise-db (Unlicense), pinned to a commit.

fedb_sha <- "f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5"
fedb_raw <- function(path) {
  sprintf("https://raw.githubusercontent.com/yuhonas/free-exercise-db/%s/%s", fedb_sha, path)
}

import_free_exercise_db <- function(vocab, cache = "data-raw/cache") {
  path <- download_once(fedb_raw("dist/exercises.json"), file.path(cache, paste0("fedb-", fedb_sha, ".json")))
  raw <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  lapply(raw, function(e) {
    equipment <- if (is.null(e$equipment)) "bodyweight" else map_terms(e$equipment, vocab$equipment$fedb, "fedb equipment")
    hold <- identical(e$force, "static") || identical(e$category, "stretching")
    exercise_record(
      id = paste0("fedb:", e$id),
      name = e$name,
      source = "free-exercise-db",
      license = "Unlicense",
      license_url = "https://unlicense.org/",
      attribution = "free-exercise-db (public domain)",
      url = sprintf("https://github.com/yuhonas/free-exercise-db/tree/%s/exercises/%s", fedb_sha, e$id),
      instructions = unlist(e$instructions) %||% character(),
      focus = map_terms(e$category, vocab$focus$fedb, "fedb category"),
      equipment = equipment,
      level = e$level %||% NA,
      primary_muscles = map_terms(e$primaryMuscles, vocab$muscles$fedb, "fedb muscle"),
      secondary_muscles = map_terms(e$secondaryMuscles, vocab$muscles$fedb, "fedb muscle"),
      default_target = if (hold) "seconds" else "reps",
      images = lapply(unlist(e$images), function(p) list(
        url = fedb_raw(paste0("exercises/", p)), license = "Unlicense", author = "free-exercise-db"
      ))
    )
  })
}
