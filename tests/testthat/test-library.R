examples <- lapply(list.files(app_path("workouts"), full.names = TRUE), read_workout)
t0 <- as.POSIXct("2026-11-04 10:00:00", tz = "UTC")

test_that("upsert adds new entries first and replaces by id, without uids", {
  r <- library_upsert(list(), with_uids(examples[[1]]), now = t0)
  expect_length(r$entries, 1)
  expect_null(r$entries[[1]]$workout$steps[[1]]$uid)
  r2 <- library_upsert(r$entries, examples[[2]], now = t0)
  expect_equal(vapply(r2$entries, `[[`, "", "id"), c(r2$id, r$id))
  w <- examples[[1]]
  w$name <- "Changed"
  r3 <- library_upsert(r2$entries, w, id = r$id, now = t0)
  expect_length(r3$entries, 2)
  expect_equal(library_get(r3$entries, r$id)$workout$name, "Changed")
})

test_that("remove, duplicate and rename", {
  r <- library_upsert(list(), examples[[1]], now = t0)
  d <- library_duplicate(r$entries, r$id, now = t0)
  expect_length(d$entries, 2)
  expect_equal(library_get(d$entries, d$id)$workout$name, paste(examples[[1]]$name, "(copy)"))
  expect_false(identical(d$id, r$id))
  renamed <- library_rename(d$entries, r$id, "  New name ")
  expect_equal(library_get(renamed, r$id)$workout$name, "New name")
  expect_equal(library_rename(d$entries, r$id, "  "), d$entries)
  expect_length(library_remove(d$entries, r$id), 1)
  expect_null(library_get(library_remove(d$entries, r$id), r$id))
})

test_that("the library survives a JSON round trip unchanged (Phase 4 exit check)", {
  entries <- list()
  for (w in examples) entries <- library_upsert(entries, with_uids(w), now = t0)$entries
  back <- library_from_json(library_to_json(entries))
  expect_equal(length(back), length(entries))
  for (i in seq_along(entries)) {
    expect_equal(back[[i]]$id, entries[[i]]$id)
    expect_equal(tidy_workout(back[[i]]$workout), tidy_workout(entries[[i]]$workout))
  }
})

test_that("bad stored data is skipped, not fatal", {
  expect_equal(library_from_json(NULL), list())
  expect_equal(library_from_json("not json"), list())
  good <- library_to_json(library_upsert(list(), examples[[1]], now = t0)$entries)
  mixed <- sub("^\\[", '[{"id":"x","yaml":"name: [broken"},', good)
  expect_length(library_from_json(mixed), 1)
})

test_that("export all and import read the same workouts back", {
  text <- workouts_to_multi_yaml(examples)
  results <- import_workouts(text, "backup.yaml", catalog)
  expect_length(results, length(examples))
  for (i in seq_along(examples)) {
    expect_length(results[[i]]$errors, 0)
    expect_equal(tidy_workout(results[[i]]$workout), tidy_workout(examples[[i]]))
  }
  single <- import_workouts(workout_to_yaml(examples[[1]]), "one.yaml", catalog)
  expect_length(single, 1)
  expect_equal(single[[1]]$name, examples[[1]]$name)
})

test_that("import explains files it can't use", {
  expect_match(import_workouts("", "empty.yaml")[[1]]$errors, "empty")
  bad <- import_workouts("name: [oops", "bad.yaml")[[1]]
  expect_null(bad$workout)
  expect_match(bad$errors, "not valid YAML")
  invalid <- import_workouts("schema_version: 1\nname: X\nsteps: []\n", "x.yaml")[[1]]
  expect_null(invalid$workout)
  expect_match(invalid$errors, "no steps")
  unknown <- import_workouts(
    "name: X\nsteps:\n  - type: exercise\n    exercise: nope:1\n    reps: 5\n", "u.yaml", catalog)[[1]]
  expect_false(is.null(unknown$workout))               # warnings don't block
  expect_match(unknown$warnings, "unknown exercise", all = FALSE)
})

test_that("file names", {
  expect_equal(workout_filename("Morning core & rehab"), "morning-core-rehab.yaml")
  expect_equal(workout_filename("  "), "workout.yaml")
  expect_equal(workout_filename(NULL), "workout.yaml")
})

test_that("user settings JSON keeps only known settings and feeds the layers", {
  s <- user_settings_from_json('{"rest_seconds": 45, "reps": 12, "colour": "red"}')
  expect_equal(s, list(rest_seconds = 45L, reps = 12L))
  expect_equal(user_settings_from_json(user_settings_to_json(s)), s)
  expect_equal(user_settings_from_json("garbage"), list())
  expect_equal(resolve_settings(app_defaults, s)$rest_seconds, 45)
})
