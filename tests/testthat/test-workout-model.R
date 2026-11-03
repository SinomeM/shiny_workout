ex <- function(...) new_step("exercise", ...)
rest <- function(seconds = 30) new_step("rest", seconds = seconds)
errors_of <- function(w, catalog = NULL) validate_workout(w, catalog)$errors
warnings_of <- function(w, catalog = NULL) validate_workout(w, catalog)$warnings
no_prep <- utils::modifyList(app_defaults, list(prep_seconds = 0))

test_that("new_step infers advance from the target", {
  expect_equal(ex(name = "A", seconds = 30)$advance, "auto")
  expect_equal(ex(name = "A", reps = 10)$advance, "manual")
  expect_equal(ex(name = "A", reps = 10, hold_seconds = 5)$advance, "auto")
  expect_equal(ex(name = "A", reps = 10, advance = "auto", seconds = 40)$advance, "auto")
  r <- new_step("repeat")
  expect_equal(r$times, 2L)
  expect_null(r$advance)
})

test_that("a well-formed workout has no errors or warnings", {
  w <- new_workout("W", sport = "hiit", tags = c("a", "b"), settings = list(prep_seconds = 5),
                   steps = list(new_step("warmup", seconds = 60),
                                new_step("repeat", times = 3, skip_last_rest = TRUE,
                                         steps = list(ex(name = "A", reps = 10), rest())),
                                new_step("cooldown")))
  expect_equal(validate_workout(w), list(errors = character(), warnings = character()))
})

test_that("validation rules from the schema", {
  one <- function(step) new_workout("W", steps = list(step))
  expect_match(errors_of(one(ex(name = "A", advance = "auto"))), "advance: auto needs seconds")
  expect_match(errors_of(one(ex(name = "A", seconds = 30, hold_seconds = 5))), "hold_seconds needs reps")
  expect_match(errors_of(one(ex(name = "A", reps = 10, sides = 3))), "sides must be 1 or 2")
  expect_match(errors_of(one(ex(name = "A", reps = 2.5))), "reps must be a whole number")
  expect_match(errors_of(one(ex(name = "A", seconds = 0))), "seconds must be a number above 0")
  expect_match(errors_of(one(ex(name = "A", seconds = "30"))), "seconds must be a number above 0")
  expect_match(errors_of(one(ex(name = "A", reps = 5, advance = "later"))), "advance must be auto or manual")
  expect_match(errors_of(one(new_step("exercise", reps = 10))), "need an exercise id or a name")
  expect_match(errors_of(one(new_step("rest", seconds = 30, reps = 5))), "rest steps only take")
  expect_match(errors_of(one(list(type = "jog", seconds = 30))), "unknown type 'jog'")
  expect_match(errors_of(one(new_step("rest", advance = "auto"))), "^Step 1: advance: auto needs")
  expect_length(errors_of(one(list(type = "rest"))), 0)     # open rest, manual by default
  expect_length(errors_of(one(new_step("cooldown"))), 0)    # open cool-down
  expect_length(errors_of(one(ex(name = "A", reps = 10, hold_seconds = 5, relax_seconds = 0))), 0)
  expect_match(warnings_of(one(ex(name = "A", seconds = 30, relax_seconds = 2))), "only used together")
})

test_that("workout-level checks", {
  expect_match(errors_of(list(1, 2)), "not a workout")
  expect_match(errors_of(new_workout("")), "needs a name", all = FALSE)
  expect_match(errors_of(new_workout("W")), "no steps")
  w <- new_workout("W", steps = list(rest()))
  w$schema_version <- 2L
  expect_match(errors_of(w), "format version 2")
  w$schema_version <- NULL
  expect_match(warnings_of(w), "assuming version 1")
  w$schema_version <- 1L
  w$sport <- "chess"
  w$colour <- "red"
  expect_match(warnings_of(w), "Unknown sport 'chess'", all = FALSE)
  expect_match(warnings_of(w), "unknown field\\(s\\): colour", all = FALSE)
  w$settings <- list(reps = 0)
  expect_match(errors_of(w), "settings: reps must be")
})

test_that("repeat blocks: times, steps, one nesting level, error paths", {
  bad <- new_workout("W", steps = list(
    rest(),
    new_step("repeat", times = 0, steps = list(ex(name = "A", reps = 5, sides = 4))),
    new_step("repeat", times = 2, steps = list(new_step("repeat", times = 2, steps = list(rest())))),
    new_step("repeat", times = 2)
  ))
  e <- errors_of(bad)
  expect_true(any(grepl("^Step 2: repeat needs times", e)))
  expect_true(any(grepl("^Step 2.1: sides must be", e)))
  expect_true(any(grepl("^Step 3.1: repeat blocks inside repeat blocks", e)))
  expect_true(any(grepl("^Step 4: the repeat block has no steps", e)))
})

test_that("unknown catalog ids warn, and labels say so", {
  catalog <- data.frame(id = c("fedb:Pushups", "yoga:7"), name = c("Push-ups", "Cat pose"))
  w <- new_workout("W", steps = list(ex(exercise = "fedb:Pushups", reps = 10),
                                     ex(exercise = "fedb:Nope", reps = 10)))
  expect_match(warnings_of(w, catalog), "Step 2: unknown exercise 'fedb:Nope'")
  expect_length(errors_of(w, catalog), 0)
  steps <- compile_workout(w, no_prep, catalog)
  expect_equal(steps$label, c("Push-ups", "Unknown exercise (fedb:Nope)"))
  expect_equal(compile_workout(w, no_prep)$label, c("fedb:Pushups", "fedb:Nope"))
  w$steps[[1]]$name <- "Knee push-ups"
  expect_equal(compile_workout(w, no_prep, catalog)$label[1], "Knee push-ups")
})

test_that("compile adds a get-ready step and resolves default labels", {
  w <- new_workout("W", steps = list(new_step("warmup", seconds = 60), rest(), new_step("cooldown")))
  steps <- compile_workout(w, app_defaults)
  expect_equal(steps$kind, c("prep", "warmup", "rest", "cooldown"))
  expect_equal(steps$label, c("Get ready", "Warm-up", "Rest", "Cool-down"))
  expect_equal(steps$seconds[1], app_defaults$prep_seconds)
  expect_equal(steps$index, 1:4)
  expect_equal(steps$next_label, c("Warm-up", "Rest", "Cool-down", NA))
  expect_equal(nrow(compile_workout(w, no_prep)), 3)
  w$settings <- list(prep_seconds = 3)
  expect_equal(compile_workout(w, app_defaults)$seconds[1], 3)
})

test_that("repeats expand per round and skip_last_rest drops trailing rests", {
  block <- function(skip) new_step("repeat", times = 3, skip_last_rest = skip,
                                   steps = list(ex(name = "A", seconds = 20), rest(10), rest(5)))
  steps <- compile_workout(new_workout("W", steps = list(block(FALSE))), no_prep)
  expect_equal(nrow(steps), 9)
  expect_equal(unique(steps$round), c("Round 1/3", "Round 2/3", "Round 3/3"))
  expect_equal(steps$path, rep(c("1.1", "1.2", "1.3"), 3))
  steps <- compile_workout(new_workout("W", steps = list(block(TRUE))), no_prep)
  expect_equal(steps$kind, c(rep(c("exercise", "rest", "rest"), 2), "exercise"))
  expect_equal(steps$block, rep(1L, 7))
})

test_that("sides expand into left, switch and right", {
  w <- new_workout("W", steps = list(ex(name = "Side plank", seconds = 30, sides = 2)))
  steps <- compile_workout(w, no_prep)
  expect_equal(steps$kind, c("exercise", "switch", "exercise"))
  expect_equal(steps$side, c("Left", NA, "Right"))
  expect_equal(steps$seconds, c(30, app_defaults$switch_seconds, 30))
  expect_equal(steps$next_label, c("Switch sides", "Side plank · Right", NA))
  w$settings <- list(switch_seconds = 0)
  expect_equal(compile_workout(w, no_prep)$side, c("Left", "Right"))
})

test_that("guided reps keep reps, hold and relax, and estimate from them", {
  w <- new_workout("W", steps = list(
    ex(name = "Quad sets", reps = 10, hold_seconds = 5),
    ex(name = "Bridge", reps = 10, hold_seconds = 2, relax_seconds = 1)
  ))
  steps <- compile_workout(w, no_prep)
  expect_equal(steps$relax_seconds, c(app_defaults$relax_seconds, 1))
  expect_equal(steps$est_seconds, c(10 * 5 + 9 * app_defaults$relax_seconds, 10 * 2 + 9))
  expect_equal(steps$advance, c("auto", "auto"))
})

test_that("estimates: seconds win, reps use seconds_per_rep, open steps are counted", {
  w <- new_workout("W", steps = list(
    ex(name = "A", reps = 10),
    ex(name = "B", reps = 10, seconds = 40, advance = "auto"),
    new_step("repeat", times = 2, steps = list(ex(name = "C", seconds = 30, sides = 2), rest())),
    new_step("cooldown")
  ))
  e <- estimate_duration(w, app_defaults)
  rep_block <- 2 * (30 + app_defaults$switch_seconds + 30 + 30)
  expect_equal(e$blocks$seconds, c(10 * app_defaults$seconds_per_rep, 40, rep_block, 0))
  expect_equal(e$blocks$label, c("A", "B", "Repeat × 2", "Cool-down"))
  expect_equal(e$blocks$open_steps, c(0L, 0L, 0L, 1L))
  expect_equal(e$open_steps, 1)
  expect_equal(e$total_seconds, app_defaults$prep_seconds + sum(e$blocks$seconds))
})
