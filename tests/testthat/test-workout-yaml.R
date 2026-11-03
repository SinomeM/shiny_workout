test_that("YAML round trip keeps the workout", {
  w <- new_workout("Round trip × è", description = "", sport = "yoga", tags = "solo",
                   settings = list(switch_seconds = 8, prep_seconds = 0),
                   steps = list(new_step("exercise", name = "yes", reps = 10, hold_seconds = 2.5),
                                new_step("repeat", times = 2, skip_last_rest = TRUE,
                                         steps = list(new_step("rest", seconds = 30)))))
  back <- workout_from_yaml(workout_to_yaml(w))
  expect_equal(back$name, w$name)
  expect_equal(back$steps[[1]]$name, "yes")             # not turned into TRUE
  expect_equal(back$steps[[1]]$hold_seconds, 2.5)
  expect_identical(back$steps[[2]]$skip_last_rest, TRUE)
  expect_equal(back$tags, "solo")
  expect_equal(tidy_workout(back), tidy_workout(w))
  path <- withr::local_tempfile(fileext = ".yaml")
  write_workout(w, path)
  expect_equal(tidy_workout(read_workout(path)), tidy_workout(w))
})

test_that("writing uses schema key order, whole numbers and drops uid and NULLs", {
  w <- list(steps = list(list(advance = "auto", seconds = 30, uid = "s1", name = "A",
                              type = "exercise", notes = NULL, later = "kept")),
            name = "W", schema_version = 1)
  y <- workout_to_yaml(w)
  expect_equal(y, paste0(
    "schema_version: 1\nname: W\nsteps:\n",
    "  - type: exercise\n    name: A\n    seconds: 30\n    advance: auto\n    later: kept\n"
  ))
  expect_equal(workout_to_yaml(new_workout("E")), "schema_version: 1\nname: E\nsteps: []\n")
})

test_that("reading reports parse errors and non-workouts clearly", {
  expect_error(workout_from_yaml("name: [unclosed"), "not valid YAML")
  expect_error(workout_from_yaml("- just\n- a list\n"), "not a workout")
  expect_error(workout_from_yaml(""), "not a workout")
})
