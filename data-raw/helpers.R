# Shared helpers for the catalog importers.

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# One exercise in our schema. Vector fields are character vectors (possibly empty).
exercise_record <- function(id, name, source, license, license_url, attribution, url = NA,
                            aliases = character(), instructions = character(),
                            focus = character(), equipment = character(), level = NA,
                            primary_muscles = character(), secondary_muscles = character(),
                            default_target = "reps", unilateral = FALSE, images = list()) {
  list(
    id = id, name = trimws(name), aliases = unique(setdiff(trimws(aliases), c("", trimws(name)))),
    instructions = instructions, focus = unique(focus), equipment = unique(equipment),
    level = level, primary_muscles = unique(primary_muscles),
    secondary_muscles = setdiff(unique(secondary_muscles), primary_muscles),
    default_target = default_target, unilateral = unilateral, images = images,
    source = source, license = license, license_url = license_url,
    attribution = attribution, url = url, merged_ids = character()
  )
}

matches <- function(pattern, x) grepl(pattern, x, ignore.case = TRUE, perl = TRUE)

# Map source terms through a named list; unknown terms are dropped with a message.
map_terms <- function(terms, map, what) {
  terms <- unlist(terms) %||% character()
  out <- unlist(map[terms], use.names = FALSE)
  unknown <- setdiff(terms, names(map))
  if (length(unknown)) message("Unmapped ", what, ": ", paste(unknown, collapse = ", "))
  unique(out) %||% character()
}

# HTML or markdown-ish description -> plain-text steps.
clean_instructions <- function(text) {
  if (is.null(text) || !nzchar(trimws(text))) return(character())
  x <- gsub("(?i)<\\s*(br|/p|/li|/h[1-6]|/div)\\s*/?>", "\n", text, perl = TRUE)
  x <- gsub("<[^>]+>", "", x)
  entities <- c("&nbsp;" = " ", "&amp;" = "&", "&quot;" = "\"", "&#39;" = "'",
                "&apos;" = "'", "&lt;" = "<", "&gt;" = ">", "&rsquo;" = "'", "&ndash;" = "-")
  for (e in names(entities)) x <- gsub(e, entities[[e]], x, fixed = TRUE)
  lines <- trimws(strsplit(x, "\n", fixed = TRUE)[[1]])
  lines <- sub("^([0-9]+[.)]|[-*•])\\s*", "", lines)
  lines[nzchar(lines)]
}

# Name used to find duplicates across sources.
dedupe_key <- function(name) {
  x <- tolower(name)
  x <- gsub("\\b(pose|the|exercise)\\b", "", x)
  x <- gsub("[^a-z0-9]", "", x)
  sub("(es|s)$", "", x)
}

download_once <- function(url, path) {
  if (!file.exists(path)) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    message("Downloading ", url)
    utils::download.file(url, path, mode = "wb", quiet = TRUE)
  }
  path
}
