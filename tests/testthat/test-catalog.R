test_that("the catalog has the expected shape and unique ids", {
  expect_gt(nrow(catalog), 1000)
  expect_false(anyDuplicated(catalog$id) > 0)
  expect_false(any(names(attr(catalog, "index")) == ""))
  expect_false(anyDuplicated(names(attr(catalog, "index"))) > 0)
  expect_true(all(c("id", "name", "focus", "equipment", "instructions", "attribution",
                    "license", "source") %in% names(catalog)))
  expect_true(all(nzchar(catalog$name)))
  expect_true(all(nzchar(catalog$attribution)))
  expect_true(all(catalog$default_target %in% c("reps", "seconds")))
  expect_true(all(lengths(catalog$focus) > 0))
  expect_setequal(attr(catalog, "sources")$id,
                  c("shiny_workout", "free-exercise-db", "wger", "yoga-api"))
})

test_that("config filters by equipment and focus", {
  cfg <- app_config$catalog
  shown <- catalog[catalog$enabled, ]
  expect_gt(nrow(shown), 500)
  expect_true(all(vapply(shown$equipment, function(e) all(e %in% cfg$enabled_equipment), TRUE)))
  hidden <- catalog[!catalog$enabled, ]
  expect_true(all(vapply(hidden$equipment, function(e) any(!e %in% cfg$enabled_equipment), TRUE)))
  expect_true(all(catalog_enabled(catalog, NULL)))
  narrow <- catalog_enabled(catalog, list(enabled_equipment = "bodyweight", enabled_focus = "yoga"))
  expect_true(all(vapply(catalog$focus[narrow], function(f) "yoga" %in% f, TRUE)))
})

test_that("every enabled focus has exercises, including the curated ones", {
  counts <- table(unlist(catalog$focus[catalog$enabled]))
  expect_true(all(app_config$catalog$enabled_focus %in% names(counts)))
  expect_true(all(counts[c("pilates", "physio", "yoga", "hiit")] >= 20))
})

test_that("lookups resolve merged ids to the kept exercise", {
  row <- catalog_row(catalog, "cur:physio_clamshell")
  expect_equal(catalog$name[row], "Clamshell")
  expect_equal(catalog_row(catalog, "wger:1823"), row)      # merged into the curated one
  expect_true(is.na(catalog_row(catalog, "nope:1")))
  w <- new_workout("W", steps = list(new_step("exercise", exercise = "wger:1823", reps = 10)))
  expect_length(validate_workout(w, catalog)$warnings, 0)
  expect_equal(compile_workout(w, app_defaults, catalog)$label[2], "Clamshell")
})

test_that("search matches name, alias and muscle, with filters", {
  hits <- search_catalog(catalog, "plank")
  expect_gt(nrow(hits), 5)
  expect_true(all(grepl("plank", hits$search)))
  expect_true(grepl("plank", tolower(hits$name[1])))
  expect_equal(search_catalog(catalog, "clamshell")$name[1], "Clamshell")
  expect_equal(search_catalog(catalog, "side plank")$name[1], "Side Plank")
  expect_true("Cobra pose" %in% search_catalog(catalog, "bhujangasana")$name)
  expect_true(all(search_catalog(catalog, "", focus = "pilates")$enabled))
  expect_true(all(vapply(search_catalog(catalog, "", focus = "physio")$focus,
                         function(f) "physio" %in% f, TRUE)))
  glutes <- search_catalog(catalog, "", muscle = "glutes", level = "beginner")
  expect_true(all(vapply(glutes$primary_muscles, function(m) "glutes" %in% m, TRUE)))
  expect_true(all(glutes$level == "beginner"))
  expect_equal(nrow(search_catalog(catalog, "zzzz no such exercise")), 0)
  expect_gt(nrow(search_catalog(catalog, "barbell", show_all = TRUE)),
            nrow(search_catalog(catalog, "barbell")))
})

test_that("step_from_exercise uses the suggested target and sides", {
  s <- step_from_exercise(catalog, "cur:physio_clamshell", app_defaults)
  expect_equal(s[c("type", "exercise", "reps", "sides", "advance")],
               list(type = "exercise", exercise = "cur:physio_clamshell",
                    reps = app_defaults$reps, sides = 2L, advance = "manual"))
  s <- step_from_exercise(catalog, "cur:mountain_pose", app_defaults)
  expect_equal(s$seconds, app_defaults$exercise_seconds)
  expect_null(s$sides)
  expect_equal(s$advance, "auto")
})

test_that("term labels", {
  expect_equal(term_label(c("exercise_ball", "hiit", "glutes", "upper_back")),
               c("Exercise ball", "HIIT", "Glutes", "Upper back"))
})
