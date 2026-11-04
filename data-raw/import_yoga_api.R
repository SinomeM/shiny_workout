# yoga-api (code and data MIT), pinned to a commit. Pose descriptions come from an
# unlicensed upstream project, so only names, categories and levels are imported.

yoga_sha <- "0c5b47bec4bb54c3e9271759fe8e82e09d91657c"

import_yoga_api <- function(vocab, cache = "data-raw/cache") {
  url <- sprintf("https://raw.githubusercontent.com/alexcumplido/yoga-api/%s/db/database.db", yoga_sha)
  path <- download_once(url, file.path(cache, paste0("yoga-api-", yoga_sha, ".db")))
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  on.exit(DBI::dbDisconnect(con))
  poses <- DBI::dbGetQuery(con, "
    SELECT p.id, p.english_name, p.sanskrit_name_adapted, p.url_svg, p.url_png,
           group_concat(DISTINCT c.category_name) AS categories,
           group_concat(DISTINCT d.difficulty_level) AS levels
    FROM poses p
    JOIN transitive_poses t ON t.pose_id = p.id
    JOIN categories c ON c.id = t.category_id
    JOIN difficulty d ON d.id = t.difficulty_id
    GROUP BY p.id ORDER BY p.id")
  level_order <- c("beginner", "intermediate", "expert")
  lapply(seq_len(nrow(poses)), function(i) {
    p <- poses[i, ]
    categories <- strsplit(p$categories, ",", fixed = TRUE)[[1]]
    focus <- unlist(lapply(categories, function(c) vocab$focus$yoga[[c]] %||% vocab$focus$yoga$default))
    levels <- intersect(level_order, tolower(strsplit(p$levels, ",", fixed = TRUE)[[1]]))
    exercise_record(
      id = paste0("yoga:", p$id),
      name = p$english_name,
      source = "yoga-api",
      license = "MIT",
      license_url = "https://github.com/alexcumplido/yoga-api/blob/main/LICENSE",
      attribution = "yoga-api by Alexandre Cumplido (MIT)",
      url = "https://github.com/alexcumplido/yoga-api",
      aliases = p$sanskrit_name_adapted,
      focus = c(focus, "mobility"),
      equipment = "mat",
      level = levels[1] %||% NA,
      default_target = "seconds",
      images = list(list(url = p$url_svg, license = "see yoga-api README", author = "yoga-api"))
    )
  })
}
