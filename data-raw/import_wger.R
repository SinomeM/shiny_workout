# wger (CC-BY-SA), from the dated snapshot written by data-raw/fetch_wger.R.

import_wger <- function(vocab, snapshot = "data-raw/snapshots/wger.json") {
  snap <- jsonlite::fromJSON(snapshot, simplifyVector = FALSE)
  license_name <- function(x) sub("^CC-BY-SA (\\d)$", "CC-BY-SA \\1.0", x)
  image_licenses <- c("1" = "CC-BY-SA 3.0", "2" = "CC-BY-SA 4.0", "3" = "CC0", "4" = "CC-BY 4.0", "5" = "ODbL")
  lapply(snap$exercises, function(e) {
    equipment <- map_terms(e$equipment, vocab$equipment$wger, "wger equipment") %||% "bodyweight"
    for (rule in vocab$name_equipment) {
      if (matches(rule$pattern, e$name)) {
        equipment <- unique(c(setdiff(equipment, "bodyweight"), rule$equipment))
      }
    }
    authors <- unique(c(unlist(e$author_history), e$license_author, e$translation_license_author))
    authors <- authors[nzchar(authors)]
    license <- license_name(e$license)
    exercise_record(
      id = paste0("wger:", e$id),
      name = e$name,
      source = "wger",
      license = license,
      license_url = e$license_url,
      attribution = sprintf("wger.de exercise %d%s, %s", e$id,
                            if (length(authors)) paste0(" by ", paste(authors, collapse = ", ")) else "",
                            license),
      url = sprintf("https://wger.de/en/exercise/%d/view-base", e$id),
      aliases = unlist(e$aliases) %||% character(),
      instructions = clean_instructions(if (nzchar(e$description)) e$description else e$description_source),
      focus = map_terms(e$category, vocab$focus$wger, "wger category"),
      equipment = equipment,
      primary_muscles = map_terms(e$muscles, vocab$muscles$wger, "wger muscle"),
      secondary_muscles = map_terms(e$muscles_secondary, vocab$muscles$wger, "wger muscle"),
      images = lapply(e$images, function(i) list(
        url = i$url, license = unname(image_licenses[as.character(i$license_id)]) %||% license,
        author = i$author %||% ""
      ))
    )
  })
}
