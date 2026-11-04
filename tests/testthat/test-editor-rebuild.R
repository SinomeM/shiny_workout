# Phase 3 exit check: an example can be rebuilt with the editor's own building blocks
# (edit-modal inputs -> step_from_inputs, insert_step into the list or a block).

modal <- function(type, ...) {
  defaults <- list(type = type, exercise = "", step_name = "", reps = NA, seconds = NA,
                   hold_seconds = NA, relax_seconds = NA, sides = FALSE, advance = "manual",
                   weight = "", notes = "")
  step_from_inputs(utils::modifyList(defaults, list(...)), type)
}

test_that("the knee example can be rebuilt from the editor's inputs", {
  w <- with_uids(new_workout("Knee strengthening"))
  w <- insert_step(w, modal("warmup", exercise = "cur:physio_heel_slides", reps = 10, sides = TRUE))
  w <- insert_step(w, step_from_inputs(list(times = 2, skip_last_rest = TRUE), "repeat"))
  block <- w$steps[[2]]$uid
  inner <- list(
    modal("exercise", exercise = "cur:physio_quad_sets", reps = 10, hold_seconds = 5, sides = TRUE,
          advance = "auto", notes = "Press the back of the knee into the mat."),
    modal("exercise", exercise = "cur:physio_straight_leg_raise", reps = 10, hold_seconds = 3,
          sides = TRUE, advance = "auto"),
    modal("exercise", exercise = "cur:physio_clamshell", reps = 12, sides = TRUE, weight = "light band"),
    modal("exercise", exercise = "wger:1408", seconds = 30, advance = "auto"),
    modal("rest", seconds = 60, advance = "auto")
  )
  for (s in inner) w <- insert_step(w, s, container = block)
  w <- insert_step(w, modal("cooldown", exercise = "fedb:Hamstring_Stretch", seconds = 30,
                            sides = TRUE, advance = "auto"))

  example <- read_workout(app_path("workouts", "knee-rehab.yaml"))
  w[c("description", "sport", "tags", "settings")] <- example[c("description", "sport", "tags", "settings")]
  expect_equal(tidy_workout(w), tidy_workout(example))
})

test_that("friendly_error rewrites common validation messages", {
  expect_match(friendly_error("Step 1: advance: auto needs seconds (or hold_seconds) to know when to move on."),
               "Set the seconds")
  expect_equal(friendly_error("Step 1.1: sides must be 1 or 2."), "Sides must be 1 or 2.")
})
