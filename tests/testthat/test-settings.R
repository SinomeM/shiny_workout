test_that("app config has a complete, valid set of defaults", {
  expect_named(app_defaults, settings_keys, ignore.order = TRUE)
  expect_length(validate_settings(app_defaults, partial = FALSE)$errors, 0)
})

test_that("later layers win and invalid values fall through", {
  user <- list(rest_seconds = 45, reps = 0, bogus = 1)
  workout <- list(rest_seconds = 20, prep_seconds = "ten")
  s <- resolve_settings(app_defaults, user, workout)
  expect_equal(s$rest_seconds, 20)
  expect_equal(s$reps, app_defaults$reps)
  expect_equal(s$prep_seconds, app_defaults$prep_seconds)
  expect_named(s, settings_keys)
  expect_equal(resolve_settings(app_defaults, NULL, NULL), app_defaults[settings_keys])
})

test_that("an incomplete first layer is an error", {
  expect_error(resolve_settings(list(reps = 10)), "Missing setting")
})

test_that("validate_settings explains bad values and flags unknown keys", {
  v <- validate_settings(list(reps = 2.5, switch_seconds = 0, hold_seconds = 0, x = 1))
  expect_match(v$errors, "reps must be a whole number", all = FALSE)
  expect_match(v$errors, "hold_seconds must be a number above 0", all = FALSE)
  expect_length(v$errors, 2)
  expect_match(v$warnings, "unknown setting\\(s\\): x")
  expect_match(validate_settings(list(reps = 10), partial = FALSE)$errors, "missing setting")
})

test_that("format_duration", {
  expect_equal(format_duration(c(0, 5, 75, 600, 3725, NA)),
               c("0:00", "0:05", "1:15", "10:00", "1:02:05", NA))
})
