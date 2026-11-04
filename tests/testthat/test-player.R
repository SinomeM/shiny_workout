plan_of <- function(steps, ...) player_plan(new_workout("T", steps = steps, ...), app_defaults, catalog)

test_that("spoken durations and targets", {
  expect_equal(spoken_duration(30), "30 seconds")
  expect_equal(spoken_duration(1), "1 second")
  expect_equal(spoken_duration(60), "1 minute")
  expect_equal(spoken_duration(90), "1 minute 30 seconds")
  expect_equal(step_target(12L, NA, NA), "12 reps")
  expect_equal(step_target(1L, NA, NA), "1 rep")
  expect_equal(step_target(10L, NA, 5), "10 × 5 s hold")
  expect_equal(step_target(10L, NA, 5, spoken = TRUE), "10 reps, 5 second hold")
  expect_equal(step_target(NA, 45, NA, spoken = TRUE), "45 seconds")
  expect_true(is.na(step_target(NA, 45, NA)))
})

test_that("durations follow the advance rules", {
  p <- plan_of(list(
    new_step("exercise", name = "Timed", seconds = 45),
    new_step("exercise", name = "Overtime", seconds = 30, advance = "manual"),
    new_step("exercise", name = "Reps", reps = 12),
    new_step("exercise", name = "Reps with limit", reps = 12, seconds = 40, advance = "auto"),
    new_step("cooldown", advance = "manual"),
    new_step("exercise", name = "Guided", reps = 10, hold_seconds = 5, relax_seconds = 2)
  ))
  s <- p$steps
  expect_equal(s[[1]]$kind, "prep")
  expect_equal(vapply(s, function(x) x$duration, 0), c(app_defaults$prep_seconds, 45, 30, NA, 40, NA, 68))
  expect_equal(vapply(s, function(x) x$auto, TRUE), c(TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, TRUE))
  expect_equal(s[[7]]$target, "10 × 5 s hold")
  expect_equal(s[[7]]$relax, 2)
  expect_equal(p$open_steps, 1)
  expect_false(p$soft)
})

test_that("rests announce the next step; the last step has no next", {
  p <- plan_of(list(new_step("exercise", name = "Squat", reps = 10), new_step("rest", seconds = 30),
                    new_step("exercise", name = "Plank", seconds = 45, sides = 2L)), sport = "yoga")
  s <- p$steps
  expect_equal(s[[1]]$speech, sprintf("Get ready, %s. Next: Squat. 10 reps.", spoken_duration(app_defaults$prep_seconds)))
  expect_equal(s[[3]]$speech, "Rest, 30 seconds. Next: Plank, left. 45 seconds.")
  expect_equal(s[[4]]$label, "Plank")
  expect_equal(s[[4]]$title, "Plank · Left")
  expect_equal(s[[4]]$sub, "Left")
  expect_equal(s[[5]]$speech, "Switch sides.")
  expect_equal(s[[3]]$next_text, "Plank · Left · 0:45")
  expect_true(is.na(s[[length(s)]]$next_text))
  expect_true(p$soft)
})

test_that("rounds and repeat blocks are numbered for the end screen", {
  p <- plan_of(list(new_step("repeat", times = 3L, skip_last_rest = TRUE, steps = list(
    new_step("exercise", name = "Push-up", reps = 8), new_step("rest", seconds = 20)))))
  s <- p$steps[-1]
  expect_equal(vapply(s, function(x) x$round_n, 1L), c(1L, 1L, 2L, 2L, 3L))
  expect_equal(s[[3]]$sub, "Round 2/3")
  expect_equal(p$blocks, list(list(block = 1L, label = "rounds of block 1", times = 3L)))
})

test_that("every example compiles to a plan the player can run", {
  for (f in list.files(app_path("workouts"), full.names = TRUE)) {
    w <- read_workout(f)
    p <- player_plan(w, app_defaults, catalog)
    expect_gt(length(p$steps), 1)
    expect_equal(p$total, estimate_duration(w, app_defaults, catalog)$total_seconds)
    for (s in p$steps) {
      expect_true(!s$auto || !is.na(s$duration), info = paste(basename(f), s$index))
      expect_false(grepl("NA", s$speech), info = paste(basename(f), s$index))
    }
    # The plan goes to the browser as JSON
    expect_silent(jsonlite::toJSON(p, auto_unbox = TRUE, na = "null"))
  }
})

test_that("session log", {
  x <- jsonlite::fromJSON('{
    "workout": "T", "started": "2026-11-04T10:00:00", "finished": "2026-11-04T10:21:05",
    "completed": false, "active_seconds": 1200.4, "wall_seconds": 1265,
    "entries": [
      {"title": "Get ready", "kind": "prep", "round": null, "side": null, "planned": 10, "actual": 10, "ended": "auto"},
      {"title": "Plank · Left", "kind": "exercise", "round": "Round 1/2", "side": "Left", "planned": null, "actual": 33.6, "ended": "done"},
      {"title": "Rest", "kind": "rest", "round": "Round 1/2", "side": null, "planned": 30, "actual": 4, "ended": "skipped"},
      {"title": "Plank · Left", "kind": "exercise", "round": "Round 2/2", "side": "Left", "planned": null, "actual": 3, "ended": "stopped"}
    ]}', simplifyVector = FALSE)
  log <- session_log(x)
  expect_equal(log$active_time, "20:00")
  expect_equal(log$total_time, "21:05")
  expect_equal(log$steps_done, 2)          # the stopped step doesn't count
  expect_equal(log$steps_skipped, 1)
  expect_false(log$completed)
  expect_equal(log$steps[[2]], list(step = "Plank · Left", kind = "exercise", round = "Round 1/2",
                                    side = "Left", actual_seconds = 34, ended = "done"))
  text <- session_log_to_yaml(log)
  expect_match(text, "completed: false")
  expect_match(text, "actual_seconds: 34\n")
  expect_equal(yaml::yaml.load(text)$steps[[3]]$ended, "skipped")
  expect_equal(session_log_filename("Morning core", as.Date("2026-11-04")), "morning-core-log-2026-11-04.yaml")
})
