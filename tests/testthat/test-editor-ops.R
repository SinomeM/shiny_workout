ex <- function(name, ...) new_step("exercise", name = name, reps = 10, ...)
uids_of <- function(steps) vapply(steps, `[[`, "", "uid")
names_of <- function(steps) vapply(steps, function(s) s$name %||% s$type, "")

sample_workout <- function() {
  with_uids(new_workout("W", steps = list(
    ex("A"),
    new_step("repeat", times = 3, steps = list(ex("B"), new_step("rest", seconds = 30))),
    ex("C")
  )))
}

test_that("with_uids gives every step a unique id and keeps existing ones", {
  w <- sample_workout()
  all <- c(uids_of(w$steps), uids_of(w$steps[[2]]$steps))
  expect_false(anyDuplicated(all) > 0)
  expect_equal(with_uids(w), w)
  expect_false(identical(uids_of(with_uids(w, fresh = TRUE)$steps), uids_of(w$steps)))
  expect_null(tidy_workout(w)$steps[[1]]$uid)       # never saved
})

test_that("locate, find and remove work at both levels", {
  w <- sample_workout()
  b <- w$steps[[2]]$steps[[1]]$uid
  expect_equal(locate_step(w, b), list(container = w$steps[[2]]$uid, index = 1L))
  expect_equal(find_step(w, b)$name, "B")
  expect_null(locate_step(w, "nope"))
  expect_equal(names_of(remove_step(w, b)$steps[[2]]$steps), "rest")
  expect_equal(names_of(remove_step(w, w$steps[[1]]$uid)$steps), c("repeat", "C"))
  expect_equal(remove_step(w, "nope"), w)
})

test_that("insert appends to a list or after a step, with a new uid", {
  w <- sample_workout()
  w2 <- insert_step(w, ex("D"))
  expect_equal(names_of(w2$steps), c("A", "repeat", "C", "D"))
  expect_false(is.null(w2$steps[[4]]$uid))
  w3 <- insert_step(w, ex("E"), container = w$steps[[2]]$uid)
  expect_equal(names_of(w3$steps[[2]]$steps), c("B", "rest", "E"))
  w4 <- insert_step(w, ex("F"), after = w$steps[[1]]$uid)
  expect_equal(names_of(w4$steps), c("A", "F", "repeat", "C"))
  expect_equal(insert_step(w, ex("G"), container = "nope"), w)
})

test_that("duplicate copies next to the original with fresh uids", {
  w <- sample_workout()
  d <- duplicate_step(w, w$steps[[2]]$uid)
  expect_equal(names_of(d$steps), c("A", "repeat", "repeat", "C"))
  expect_false(d$steps[[3]]$uid == d$steps[[2]]$uid)
  expect_false(any(uids_of(d$steps[[3]]$steps) %in% uids_of(d$steps[[2]]$steps)))
})

test_that("replace keeps the uid and a block's steps", {
  w <- sample_workout()
  r <- replace_step(w, w$steps[[1]]$uid, ex("A2"))
  expect_equal(r$steps[[1]]$name, "A2")
  expect_equal(r$steps[[1]]$uid, w$steps[[1]]$uid)
  r <- replace_step(w, w$steps[[2]]$uid, new_step("repeat", times = 5, steps = list()))
  expect_equal(r$steps[[2]]$times, 5)
  expect_equal(r$steps[[2]]$steps, w$steps[[2]]$steps)
})

test_that("move up and down stays within the list", {
  w <- sample_workout()
  expect_equal(names_of(move_step(w, w$steps[[3]]$uid, -1)$steps), c("A", "C", "repeat"))
  expect_equal(move_step(w, w$steps[[1]]$uid, -1), w)
  expect_equal(move_step(w, w$steps[[3]]$uid, 1), w)
  inner <- w$steps[[2]]$steps
  expect_equal(names_of(move_step(w, inner[[1]]$uid, 1)$steps[[2]]$steps), c("rest", "B"))
})

test_that("moving into and out of repeat blocks", {
  w <- sample_workout()
  expect_equal(into_block_target(w, w$steps[[1]]$uid), "below")
  expect_equal(into_block_target(w, w$steps[[3]]$uid), "above")
  expect_true(is.na(into_block_target(w, w$steps[[2]]$uid)))
  expect_true(is.na(into_block_target(w, w$steps[[2]]$steps[[1]]$uid)))
  a <- move_into_block(w, w$steps[[1]]$uid)
  expect_equal(names_of(a$steps), c("repeat", "C"))
  expect_equal(names_of(a$steps[[1]]$steps), c("A", "B", "rest"))
  c <- move_into_block(w, w$steps[[3]]$uid)
  expect_equal(names_of(c$steps[[2]]$steps), c("B", "rest", "C"))
  out <- move_out_of_block(w, w$steps[[2]]$steps[[1]]$uid)
  expect_equal(names_of(out$steps), c("A", "repeat", "B", "C"))
  expect_equal(move_out_of_block(w, w$steps[[1]]$uid), w)
})

test_that("reorder applies a drag-and-drop order only if it matches", {
  w <- sample_workout()
  u <- uids_of(w$steps)
  expect_equal(names_of(reorder_container(w, NULL, list(u[3], u[1], u[2]))$steps), c("C", "A", "repeat"))
  expect_equal(reorder_container(w, NULL, u[1:2]), w)
  expect_equal(reorder_container(w, NULL, c(u[1:2], "x")), w)
  inner <- uids_of(w$steps[[2]]$steps)
  r <- reorder_container(w, w$steps[[2]]$uid, rev(inner))
  expect_equal(names_of(r$steps[[2]]$steps), c("rest", "B"))
})

test_that("step summaries", {
  expect_equal(step_summary(ex("A", advance = "manual")), "10 reps · manual")
  expect_equal(step_summary(new_step("exercise", name = "P", seconds = 45)), "0:45 · auto")
  expect_equal(step_summary(new_step("exercise", name = "Q", reps = 10, hold_seconds = 3, sides = 2)),
               "10 × 3 s hold · each side · auto")
  expect_equal(step_summary(new_step("exercise", name = "R", reps = 12, seconds = 40, advance = "auto")),
               "12 reps · 0:40 · auto")
  expect_equal(step_summary(new_step("cooldown")), "open · manual")
  expect_equal(step_summary(new_step("repeat", times = 3, skip_last_rest = TRUE)),
               "× 3 · no rest after the last round")
})

test_that("workout summary counts exercises, sets, focus, muscles and equipment", {
  w <- new_workout("W", steps = list(
    new_step("warmup", exercise = "cur:mountain_pose", seconds = 30),
    new_step("repeat", times = 2, steps = list(
      step_from_exercise(catalog, "cur:physio_clamshell", app_defaults),
      step_from_exercise(catalog, "cur:physio_terminal_knee_extension", app_defaults),
      new_step("rest", seconds = 30)
    ))
  ))
  s <- workout_summary(w, app_defaults, catalog)
  expect_equal(s$exercises, 2)
  expect_equal(s$sets, 4)                                  # 2 exercises x 2 rounds, sides count once
  expect_equal(s$open_steps, 0)
  expect_true(all(c("physio", "yoga") %in% names(s$focus)))
  expect_true(all(c("glutes", "quads") %in% s$muscles))
  expect_setequal(s$equipment, c("mat", "bands"))
  expect_equal(s$total_seconds, estimate_duration(w, app_defaults, catalog)$total_seconds)
})
