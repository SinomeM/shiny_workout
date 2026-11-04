# Curated exercises

Our own exercises, written for this project and published with the catalog under
CC-BY-SA 4.0. Each file is a YAML list; ids get the `cur:` prefix in the catalog.

| Field | Required | Values |
|---|---|---|
| `id` | yes | Unique within these files, e.g. `pilates_hundred`. Never change it once published: workouts refer to it. |
| `name` | yes | English name. |
| `aliases` | no | Other names (Sanskrit, common variants). |
| `focus` | yes | `strength`, `hiit`, `core`, `mobility`, `yoga`, `pilates`, `physio` |
| `equipment` | no | Defaults to `[bodyweight]`. See `data-raw/vocab.yaml` for the vocabulary. |
| `level` | no | `beginner`, `intermediate`, `expert` |
| `primary_muscles`, `secondary_muscles` | no | See `data-raw/vocab.yaml`. |
| `default_target` | no | `reps` (default) or `seconds`, for holds and stretches. |
| `unilateral` | no | `true` if usually done one side at a time. |
| `instructions` | yes | A few short steps, in our own words. |

Curated entries win over imported ones with the same name. Rebuild the catalog with
`Rscript data-raw/build_catalog.R`.
