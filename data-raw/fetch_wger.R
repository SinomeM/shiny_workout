# Saves a dated snapshot of the wger exercise database (English entries only, trimmed
# to the fields we use) to data-raw/snapshots/wger.json, so catalog builds don't
# depend on the live API. Run from the project root: Rscript data-raw/fetch_wger.R

fetch_wger <- function(out = "data-raw/snapshots/wger.json") {
  url <- "https://wger.de/api/v2/exerciseinfo/?limit=100&offset=0"
  raw <- list()
  while (!is.null(url)) {
    message("GET ", url)
    page <- jsonlite::fromJSON(url, simplifyVector = FALSE)
    raw <- c(raw, page$results)
    url <- page$`next`
  }
  names_of <- function(x, field = "name") vapply(x, function(i) i[[field]] %||% "", character(1))
  trimmed <- lapply(raw, function(e) {
    en <- Filter(function(t) identical(t$language, 2L), e$translations)
    if (!length(en)) return(NULL)
    en <- en[[1]]
    list(
      id = e$id,
      uuid = e$uuid,
      category = e$category$name,
      muscles = names_of(e$muscles),
      muscles_secondary = names_of(e$muscles_secondary),
      equipment = names_of(e$equipment),
      variations = e$variations,
      license = e$license$short_name,
      license_url = e$license$url,
      license_author = e$license_author %||% "",
      name = en$name,
      aliases = names_of(en$aliases, "alias"),
      description = en$description %||% "",
      description_source = en$description_source %||% "",
      translation_license_author = en$license_author %||% "",
      author_history = unlist(en$author_history) %||% character(),
      images = lapply(e$images, function(i) list(
        url = i$image, is_main = i$is_main, license = i$license_title %||% "",
        license_id = i$license, author = i$license_author %||% ""
      ))
    )
  })
  trimmed <- Filter(Negate(is.null), trimmed)
  snapshot <- list(
    source = "https://wger.de/api/v2/exerciseinfo/",
    fetched = format(Sys.Date()),
    count = length(trimmed),
    exercises = trimmed
  )
  jsonlite::write_json(snapshot, out, auto_unbox = TRUE, pretty = TRUE, null = "null")
  message("Wrote ", length(trimmed), " English exercises to ", out)
}

if (sys.nframe() == 0) fetch_wger()
