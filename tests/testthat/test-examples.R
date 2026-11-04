example_files <- list.files(app_path("workouts"), pattern = "\\.ya?ml$", full.names = TRUE)

test_that("there is one example per focus", {
  sports_used <- vapply(example_files, function(f) read_workout(f)$sport, character(1))
  expect_setequal(sports_used, sports)
})

for (f in example_files) {
  test_that(paste("example", basename(f), "is valid, round-trips and compiles"), {
    w <- read_workout(f)
    expect_equal(validate_workout(w, catalog), list(errors = character(), warnings = character()))
    expect_equal(tidy_workout(workout_from_yaml(workout_to_yaml(w))), tidy_workout(w))
    steps <- compile_workout(w, app_defaults, catalog)
    expect_false(anyNA(steps$label))
    expect_snapshot(cat(describe_steps(steps), sep = "\n"))
  })
}
