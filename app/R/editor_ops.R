# Editor operations: pure functions on a workout whose steps carry a `uid` (an internal
# id for the UI, never saved). A "container" is NULL for the top-level step list, or
# the uid of a repeat block for the steps inside it. Every function returns a new
# workout; invalid requests return it unchanged.

new_uid <- local({
  n <- 0L
  function() {
    n <<- n + 1L
    paste0("s", n)
  }
})

with_uids <- function(w, fresh = FALSE) {
  w$steps <- lapply(w$steps %||% list(), uid_step, fresh = fresh)
  w
}

uid_step <- function(s, fresh = FALSE) {
  if (fresh || is.null(s$uid)) s$uid <- new_uid()
  if (identical(s$type, "repeat")) s$steps <- lapply(s$steps %||% list(), uid_step, fresh = fresh)
  s
}

# Where a step is: list(container, index), or NULL.
locate_step <- function(w, uid) {
  for (i in seq_along(w$steps)) {
    s <- w$steps[[i]]
    if (identical(s$uid, uid)) return(list(container = NULL, index = i))
    if (identical(s$type, "repeat")) {
      for (j in seq_along(s$steps)) {
        if (identical(s$steps[[j]]$uid, uid)) return(list(container = s$uid, index = j))
      }
    }
  }
  NULL
}

find_step <- function(w, uid) {
  at <- locate_step(w, uid)
  if (is.null(at)) NULL else get_container(w, at$container)[[at$index]]
}

block_index <- function(w, block_uid) {
  which(vapply(w$steps, function(s) identical(s$uid, block_uid), logical(1)))
}

get_container <- function(w, container) {
  if (is.null(container)) w$steps else w$steps[[block_index(w, container)]]$steps
}

set_container <- function(w, container, steps) {
  if (is.null(container)) w$steps <- steps else w$steps[[block_index(w, container)]]$steps <- steps
  w
}

insert_step <- function(w, step, container = NULL, after = NULL) {
  if (!is.null(container) && !length(block_index(w, container))) return(w)
  steps <- get_container(w, container)
  pos <- if (is.null(after)) length(steps) else match(after, vapply(steps, `[[`, "", "uid"))
  if (is.na(pos)) pos <- length(steps)
  set_container(w, container, append(steps, list(uid_step(step)), after = pos))
}

replace_step <- function(w, uid, step) {
  at <- locate_step(w, uid)
  if (is.null(at)) return(w)
  steps <- get_container(w, at$container)
  step$uid <- uid
  if (identical(step$type, "repeat")) step$steps <- steps[[at$index]]$steps %||% list()
  steps[[at$index]] <- step
  set_container(w, at$container, steps)
}

remove_step <- function(w, uid) {
  at <- locate_step(w, uid)
  if (is.null(at)) return(w)
  set_container(w, at$container, get_container(w, at$container)[-at$index])
}

duplicate_step <- function(w, uid) {
  at <- locate_step(w, uid)
  if (is.null(at)) return(w)
  copy <- uid_step(find_step(w, uid), fresh = TRUE)
  steps <- get_container(w, at$container)
  set_container(w, at$container, append(steps, list(copy), after = at$index))
}

# Move up (by = -1) or down (by = 1) within the same list.
move_step <- function(w, uid, by) {
  at <- locate_step(w, uid)
  if (is.null(at)) return(w)
  steps <- get_container(w, at$container)
  to <- at$index + by
  if (to < 1 || to > length(steps)) return(w)
  steps[c(at$index, to)] <- steps[c(to, at$index)]
  set_container(w, at$container, steps)
}

# A top-level step next to a repeat block can move into it: to the end of the block
# above, or else to the start of the block below. Returns "above", "below" or NA.
into_block_target <- function(w, uid) {
  at <- locate_step(w, uid)
  if (is.null(at) || !is.null(at$container) || identical(w$steps[[at$index]]$type, "repeat")) {
    return(NA_character_)
  }
  is_block <- function(i) i >= 1 && i <= length(w$steps) && identical(w$steps[[i]]$type, "repeat")
  if (is_block(at$index - 1)) "above" else if (is_block(at$index + 1)) "below" else NA_character_
}

move_into_block <- function(w, uid) {
  target <- into_block_target(w, uid)
  if (is.na(target)) return(w)
  i <- locate_step(w, uid)$index
  step <- w$steps[[i]]
  if (target == "above") {
    w$steps[[i - 1]]$steps <- append(w$steps[[i - 1]]$steps %||% list(), list(step))
  } else {
    w$steps[[i + 1]]$steps <- append(w$steps[[i + 1]]$steps %||% list(), list(step), after = 0)
  }
  w$steps <- w$steps[-i]
  w
}

# A step inside a block moves out to just after the block.
move_out_of_block <- function(w, uid) {
  at <- locate_step(w, uid)
  if (is.null(at) || is.null(at$container)) return(w)
  step <- find_step(w, uid)
  w <- remove_step(w, uid)
  w$steps <- append(w$steps, list(step), after = block_index(w, at$container))
  w
}

# Apply a new order from drag and drop. `order` must hold exactly the same uids.
reorder_container <- function(w, container, order) {
  if (!is.null(container) && !length(block_index(w, container))) return(w)
  steps <- get_container(w, container)
  uids <- vapply(steps, `[[`, "", "uid")
  order <- unlist(order)
  if (length(order) != length(uids) || !setequal(order, uids)) return(w)
  set_container(w, container, steps[match(order, uids)])
}

# Short description of a step's target, e.g. "12 reps · manual", "0:45 · auto",
# "10 × 3 s hold · each side".
step_summary <- function(step) {
  if (identical(step$type, "repeat")) {
    return(paste0(sprintf("× %d", step$times),
                  if (isTRUE(step$skip_last_rest)) " · no rest after the last round"))
  }
  target <- if (!is.null(step$hold_seconds)) {
    sprintf("%d × %g s hold", step$reps, step$hold_seconds)
  } else {
    c(if (!is.null(step$reps)) paste(step$reps, "reps"),
      if (!is.null(step$seconds)) format_duration(step$seconds))
  }
  if (!length(target)) target <- "open"
  paste(c(target, if (isTRUE(step$sides == 2)) "each side", step_advance(step)), collapse = " · ")
}

# Numbers for the summary panel. Expects a workout without validation errors.
workout_summary <- function(w, settings, catalog) {
  steps <- compile_workout(w, settings, catalog)
  est <- steps$est_seconds
  ex <- steps[steps$kind %in% c("warmup", "exercise", "cooldown"), , drop = FALSE]
  rows <- stats::na.omit(catalog_row(catalog, ex$exercise[!is.na(ex$exercise)]))
  focus <- table(unlist(catalog$focus[rows]))
  list(
    total_seconds = sum(est, na.rm = TRUE),
    open_steps = sum(is.na(est)),
    exercises = length(unique(ex$label[ex$kind == "exercise"])),
    sets = sum(ex$kind == "exercise" & (is.na(ex$side) | ex$side == "Left")),
    focus = sort(focus, decreasing = TRUE),
    muscles = unique(unlist(catalog$primary_muscles[rows])),
    equipment = setdiff(unique(unlist(catalog$equipment[rows])), "bodyweight")
  )
}
