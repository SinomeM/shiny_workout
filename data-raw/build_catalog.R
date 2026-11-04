# Builds the exercise catalog (app/data/exercises.json) and CREDITS.md from all sources:
# our curated files, free-exercise-db, wger (snapshot) and yoga-api.
# Run from the project root: Rscript data-raw/build_catalog.R
#
# Steps: import -> name rules (vocab.yaml) -> curation.yaml (exclude, fix, merge)
# -> automatic merge of same-name exercises -> write.

for (f in c("helpers.R", "import_free_exercise_db.R", "import_wger.R", "import_yoga_api.R")) {
  source(file.path("data-raw", f))
}

source_info <- list(
  list(id = "shiny_workout", name = "shiny_workout curated exercises",
       url = "https://github.com/SinomeM/shiny_workout/tree/main/data-raw/curated",
       license = "CC-BY-SA 4.0", license_url = "https://creativecommons.org/licenses/by-sa/4.0/",
       version = "this repository"),
  list(id = "free-exercise-db", name = "free-exercise-db",
       url = "https://github.com/yuhonas/free-exercise-db",
       license = "Unlicense (public domain)", license_url = "https://unlicense.org/",
       version = paste("commit", substr(fedb_sha, 1, 7))),
  list(id = "wger", name = "wger Workout Manager exercise database",
       url = "https://wger.de",
       license = "CC-BY-SA 3.0 / 4.0 and CC0, per exercise",
       license_url = "https://creativecommons.org/licenses/by-sa/4.0/",
       version = NULL),
  list(id = "yoga-api", name = "yoga-api",
       url = "https://github.com/alexcumplido/yoga-api",
       license = "MIT (names, categories and levels only)",
       license_url = "https://github.com/alexcumplido/yoga-api/blob/main/LICENSE",
       version = paste("commit", substr(yoga_sha, 1, 7)))
)

import_curated <- function(dir = "data-raw/curated") {
  files <- list.files(dir, pattern = "\\.ya?ml$", full.names = TRUE)
  unlist(lapply(files, function(f) {
    lapply(yaml::read_yaml(f), function(e) {
      rec <- exercise_record(
        id = paste0("cur:", e$id),
        name = e$name,
        source = "shiny_workout",
        license = "CC-BY-SA 4.0",
        license_url = "https://creativecommons.org/licenses/by-sa/4.0/",
        attribution = "shiny_workout contributors, CC-BY-SA 4.0",
        url = paste0("https://github.com/SinomeM/shiny_workout/blob/main/data-raw/curated/", basename(f)),
        aliases = unlist(e$aliases) %||% character(),
        instructions = unlist(e$instructions) %||% character(),
        focus = unlist(e$focus),
        equipment = unlist(e$equipment) %||% "bodyweight",
        level = e$level %||% NA,
        primary_muscles = unlist(e$primary_muscles) %||% character(),
        secondary_muscles = unlist(e$secondary_muscles) %||% character(),
        default_target = e$default_target %||% "reps",
        unilateral = isTRUE(e$unilateral)
      )
      rec$curated <- TRUE
      rec
    })
  }), recursive = FALSE)
}

# Name-based rules from vocab.yaml. Curated entries are already explicit.
apply_name_rules <- function(rec, vocab) {
  if (isTRUE(rec$curated)) return(rec)
  for (rule in vocab$name_focus) {
    if (matches(rule$pattern, rec$name)) rec$focus <- union(rec$focus, rule$focus)
  }
  if (any(c("abs", "obliques") %in% rec$primary_muscles)) rec$focus <- union(rec$focus, "core")
  if (matches(vocab$hold_pattern, rec$name)) rec$default_target <- "seconds"
  if (matches(vocab$unilateral_pattern, rec$name)) rec$unilateral <- TRUE
  rec
}

merge_into <- function(keep, drop) {
  keep$aliases <- unique(setdiff(c(keep$aliases, drop$name, drop$aliases), keep$name))
  keep$merged_ids <- unique(c(keep$merged_ids, drop$id, drop$merged_ids))
  if (!isTRUE(keep$curated)) keep$focus <- union(keep$focus, drop$focus)
  if (!length(keep$primary_muscles)) keep$primary_muscles <- drop$primary_muscles
  if (!length(keep$secondary_muscles)) {
    keep$secondary_muscles <- setdiff(drop$secondary_muscles, keep$primary_muscles)
  }
  if (is.na(keep$level)) keep$level <- drop$level
  if (!length(keep$instructions) && length(drop$instructions)) {
    keep$instructions <- drop$instructions
    keep$instructions_from <- drop$attribution
  }
  keep$images <- c(keep$images, drop$images)
  keep
}

build_catalog <- function(out = "app/data/exercises.json", credits = "CREDITS.md") {
  vocab <- yaml::read_yaml("data-raw/vocab.yaml")
  curation <- yaml::read_yaml("data-raw/curation.yaml")

  # Preference order for merges: curated > free-exercise-db > wger > yoga-api.
  all <- c(import_curated(), import_free_exercise_db(vocab), import_wger(vocab), import_yoga_api(vocab))
  message("Imported ", length(all), " exercises")
  ids <- vapply(all, `[[`, "", "id")
  stopifnot(!anyDuplicated(ids))
  names(all) <- ids

  all <- lapply(all, apply_name_rules, vocab = vocab)

  # Curation: drop, then fix fields, then explicit merges.
  drop <- intersect(unlist(curation$exclude), ids)
  unknown <- setdiff(unlist(curation$exclude), ids)
  if (length(unknown)) warning("curation.yaml excludes unknown ids: ", paste(unknown, collapse = ", "))
  for (p in unlist(curation$exclude_name_patterns)) {
    hit <- vapply(all, function(r) !isTRUE(r$curated) && matches(p, r$name), logical(1))
    drop <- union(drop, names(all)[hit])
  }
  all <- all[setdiff(names(all), drop)]
  message("Excluded ", length(drop))

  for (id in names(curation$set)) {
    if (is.null(all[[id]])) { warning("curation.yaml sets fields of unknown id ", id); next }
    for (field in names(curation$set[[id]])) all[[id]][[field]] <- curation$set[[id]][[field]]
  }
  for (keep in names(curation$merge)) {
    for (d in unlist(curation$merge[[keep]])) {
      if (is.null(all[[keep]]) || is.null(all[[d]])) { warning("curation.yaml merge: unknown ", keep, " / ", d); next }
      all[[keep]] <- merge_into(all[[keep]], all[[d]])
      all[[d]] <- NULL
    }
  }

  # Automatic merge of exercises with the same name, keeping the preferred source.
  keys <- vapply(all, function(r) dedupe_key(r$name), "")
  no_merge <- unlist(curation$no_merge)
  merged <- 0
  for (k in unique(keys[duplicated(keys)])) {
    group <- setdiff(names(all)[keys == k], no_merge)
    if (length(group) < 2) next
    for (d in group[-1]) all[[group[1]]] <- merge_into(all[[group[1]]], all[[d]])
    all[group[-1]] <- NULL
    keys <- keys[names(all)]
    merged <- merged + length(group) - 1
  }
  message("Merged ", merged, " duplicates by name")

  all <- all[order(tolower(vapply(all, `[[`, "", "name")))]
  vector_fields <- c("aliases", "instructions", "focus", "equipment", "primary_muscles",
                     "secondary_muscles", "merged_ids")
  exercises <- unname(lapply(all, function(r) {
    r$curated <- NULL
    for (f in vector_fields) r[[f]] <- I(as.character(r[[f]]))  # always a JSON array
    r
  }))
  wger_info <- jsonlite::fromJSON("data-raw/snapshots/wger.json", simplifyVector = FALSE)
  sources <- source_info
  sources[[3]]$version <- paste("API snapshot of", wger_info$fetched)

  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    list(schema = 1L, built = format(Sys.Date()), sources = sources, exercises = exercises),
    out, auto_unbox = TRUE, null = "null", na = "null", digits = NA
  )
  message("Wrote ", length(exercises), " exercises to ", out)
  write_credits(exercises, sources, credits)
}

write_credits <- function(exercises, sources, path) {
  counts <- table(vapply(exercises, `[[`, "", "source"))
  wger_authors <- sort(unique(unlist(lapply(exercises, function(r) {
    if (r$source != "wger") return(NULL)
    sub("^wger\\.de exercise \\d+ by (.*), CC.*$", "\\1", r$attribution)
  }))))
  wger_authors <- sort(unique(trimws(unlist(strsplit(wger_authors[!grepl("^wger", wger_authors)], ", ")))))
  lines <- c(
    "# Credits",
    "",
    "<!-- Generated by data-raw/build_catalog.R. Do not edit by hand. -->",
    "",
    "The app's code is licensed under GPL-3.0 (see `LICENSE`). The exercise catalog",
    "(`app/data/exercises.json`) combines the sources below and, because wger is",
    "share-alike, is published under **CC-BY-SA 4.0**. Every exercise in the catalog",
    "carries its own source, license and attribution, and the app shows them in the",
    "exercise details.",
    "",
    "| Source | License | Version | Exercises |",
    "|---|---|---|---|",
    vapply(sources, function(s) sprintf("| [%s](%s) | [%s](%s) | %s | %d |", s$name, s$url,
                                        s$license, s$license_url, s$version,
                                        as.integer(counts[s$id] %||% 0)), ""),
    "",
    "Exercises found in more than one source are merged and credited to the preferred",
    "source (curated, then free-exercise-db, then wger, then yoga-api). When a merged",
    "exercise borrows its instructions from another source, that source is credited",
    "too.",
    "",
    "yoga-api: only pose names, Sanskrit names, categories and levels are used; its",
    "pose descriptions come from an upstream project without a license and are not",
    "included.",
    "",
    "## wger contributors",
    "",
    paste0("Exercise texts from wger.de were written by: ", paste(wger_authors, collapse = ", "), "."),
    "",
    "Physiotherapy exercises are general examples, not medical advice; follow your",
    "physiotherapist's prescription."
  )
  writeLines(lines, path)
  message("Wrote ", path)
}

if (sys.nframe() == 0) build_catalog()
