# Workout file format (schema version 1)

A workout is a YAML file. You can build it in the app and download it, or write it by
hand. The app checks every file it opens and explains what's wrong; errors stop a file
from loading, warnings don't. Examples are in [`app/workouts/`](../app/workouts/).

```yaml
schema_version: 1
name: Morning core and rehab
description: Mat and band.
sport: physio                      # strength | hiit | mobility | yoga | pilates | physio
tags: [home, core]
settings:                          # optional: override your defaults for this workout
  prep_seconds: 10
steps:
  - type: warmup
    name: Cat-cow
    seconds: 60                    # counts down, moves on at 0
  - type: repeat
    times: 3
    skip_last_rest: true           # no rest after the final round
    steps:
      - type: exercise
        name: Push-ups
        reps: 12                   # waits for Space
        notes: Slow on the way down.
      - type: exercise
        name: Clamshell
        reps: 10
        hold_seconds: 3            # guided reps: hold 3 s, relax, 10 times
        sides: 2                   # left, then right
        weight: light band
      - type: rest
        seconds: 30
  - type: cooldown                 # no target: stretch until you press Space
```

## Workout fields

| Field | Required | Meaning |
|---|---|---|
| `schema_version` | yes | Always `1` for now. Files from a newer version are refused. |
| `name` | yes | Shown in the library and the player. |
| `description` | no | Free text. |
| `sport` | no | One of `strength`, `hiit`, `mobility`, `yoga`, `pilates`, `physio`. |
| `tags` | no | A list of words, for searching. |
| `settings` | no | Overrides for the defaults below, for this workout only. |
| `steps` | yes | At least one step. |

## Steps

Every step has a `type`: `warmup`, `exercise`, `rest`, `cooldown` or `repeat`.

### Warm-up, exercise, rest and cool-down

| Field | Meaning |
|---|---|
| `exercise` | A catalog id, e.g. `fedb:Pushups`, `wger:123`, `yoga:7`, `cur:physio_clamshell`. |
| `name` | Free text. Shown instead of the catalog name when both are given. |
| `reps` | Number of reps (whole number, 1 or more). |
| `seconds` | Time target or limit (above 0). |
| `hold_seconds` | Guided reps: hold each rep this long. Needs `reps`. |
| `relax_seconds` | Pause between guided reps (default from settings). |
| `sides` | `2` runs the step for the left side, then the right, with a short switch countdown between. |
| `advance` | `auto` moves on when the time is up; `manual` waits for Space. |
| `weight` | Free text, e.g. `red band`. |
| `notes` | Free text, shown in the player. |

Exercise steps need an `exercise` or a `name`. Rest steps only take `seconds`, `advance`
and `notes`.

How a step behaves depends on its target and `advance`. If `advance` is left out, it is
`auto` when the step has `seconds` or `hold_seconds`, and `manual` otherwise.

| `reps` | `seconds` | `advance` | In the player |
|---|---|---|---|
| – | ✓ | `auto` | Counts down and moves on at 0. |
| – | ✓ | `manual` | Counts down, beeps at 0, then counts overtime until you press Space. |
| ✓ | – | `manual` | Shows the reps, counts time up, waits for Space. |
| ✓ | ✓ | `auto` | Shows the reps with a time limit; moves on at 0 or on Space. |
| – | – | `manual` | Open step: runs until you press Space. |

`advance: auto` needs `seconds` or `hold_seconds`. Space always ends the current step
early.

### Repeat blocks

| Field | Meaning |
|---|---|
| `times` | Number of rounds (whole number, 1 or more). |
| `skip_last_rest` | `true` drops the rest steps at the end of the final round. |
| `steps` | The steps of one round. Repeat blocks can't contain other repeat blocks yet. |

## Settings

The defaults come from the app, then from your Settings panel, then from the workout's
own `settings:`; later ones win.

| Setting | Default | Used for |
|---|---|---|
| `prep_seconds` | 10 | "Get ready" countdown before the first step (0 to skip). |
| `rest_seconds` | 30 | Length of a new rest step in the editor. |
| `reps` | 10 | Reps of a new rep-based step in the editor. |
| `exercise_seconds` | 30 | Length of a new timed step in the editor. |
| `hold_seconds` | 5 | Hold of a new guided-rep step in the editor. |
| `relax_seconds` | 3 | Pause between guided reps. |
| `switch_seconds` | 5 | "Switch sides" countdown (0 to skip). |
| `seconds_per_rep` | 3 | Duration estimate for rep-based steps. |

## Notes for app developers

- Unknown fields produce a warning and are kept when the file is saved again.
- Internal editor ids (`uid`) are never written to files.
- `compile_workout()` turns a workout into the flat list of steps the player runs;
  `estimate_duration()` sums it. Steps without a target count as 0 and are reported as
  open.
