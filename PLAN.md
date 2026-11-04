# shiny_workout: project plan

A small R Shiny app to build, save, load and **run** custom workout routines, in the
spirit of Garmin Connect's strength / HIIT / yoga / pilates workouts. It runs entirely in
the browser via **Shinylive** (R compiled to WebAssembly) and is hosted for free on
**GitHub Pages**.

Repo: [SinomeM/shiny_workout](https://github.com/SinomeM/shiny_workout) · License: GPL-3.0 ·
Status: v2, reviewed and confirmed · 2026-11-02

---

## 1. Decisions

| Topic | Decision |
|---|---|
| Hosting | GitHub Pages (static) → the app is a **Shinylive** app: no R server, R runs in the browser via webR. |
| Primary device | **Laptop first** (keyboard, Space bar to advance); phone must be usable (stacked layout, big tap button). |
| Activity focus (v1) | **Bodyweight strength, HIIT, core & planks, mobility / stretching, yoga, pilates, physiotherapy.** Steps use reps, time, holds and "each side"; repeat blocks for sets and circuits. No distance, pace or heart-rate targets. |
| Exercise catalog | **Multi-source**, imported in full and filtered at build time by config (§4): free-exercise-db + wger + yoga-api, plus our own curated pilates / physio / extras files. |
| Default equipment | Bodyweight, mat, swiss ball, elastic bands, foam roller (config, editable). |
| Data license | Generated exercise catalog published as **CC-BY-SA 4.0** (required by wger), next to the GPL-3.0 code. |
| Language | **English** (UI and exercise names). |
| Garmin export | Not in v1, but the data model mirrors Garmin's step structure so a FIT exporter can be added later. |
| File format | YAML, with a `schema_version` field. |
| Defaults | Prep 10 s, rest 30 s, 10 reps or 30 s per new exercise, hold 5 s, 3 s per rep for estimates. **Editable** in a Settings panel and per workout. |
| Timed step, manual advance | At 0:00 it beeps and counts overtime **until Space**. |
| Custom exercises | v1: free-text steps inside a workout. A real "add to my catalog" UI comes later. |
| R version | **R 4.6.0**, the only install left after cleanup. Pinned locally (renv) and in CI (§7). |
| Images / GIFs | Later phase (Phase 7). |

### What I checked

**R on this Mac**: a single install, **R 4.6.0** (CRAN framework, `/usr/local/bin/R`), used
by both the terminal and RStudio. It has 140 packages, including shiny 1.14, bslib 0.10,
yaml, jsonlite and httpuv. Still to install in Phase 0: renv, shinylive, sortable, bsicons,
testthat.

**webR (the R that runs in the browser)**: webR v0.6.0, with package binaries built for R 4.6
and 4.5. shiny, bslib, yaml, jsonlite, sortable, bsicons, htmltools and shinyjs are all
available. The browser's R version is set by the Shinylive assets, not by local R. Pinning the
`shinylive` package version pins it (§7).

**Exercise sources**: see §4 for the comparison. In short, no single open dataset covers
bodyweight + yoga + pilates + physio well, so we combine three and curate the rest.

---

## 2. Architecture

```
            build time (your laptop / GitHub Actions)                 run time (browser)
 ┌───────────────────────────────────────────────────────┐   ┌──────────────────────────────────┐
 │ free-exercise-db ─┐ (pinned)                          │   │  GitHub Pages (static files)     │
 │ wger API ─────────┤                                   │   │   └─ Shinylive loader            │
 │ yoga-api ─────────┼─► data-raw/build_catalog.R        │   │       └─ webR (R in WASM)        │
 │ curated/*.yaml ───┘    normalise · dedupe · filter    │   │           └─ Shiny app (app/)    │
 │                        → app/data/exercises.json      │   │               ├─ catalog + editor│
 │                        → CREDITS.md                   │   │               └─ player (JS)     │
 │ app/ ──► tests ──► shinylive::export() ──► _site/ ────┼──►│  localStorage: workouts, settings│
 └───────────────────────────────────────────────────────┘   │  files: YAML download / upload   │
                                                             └──────────────────────────────────┘
```

**Split of responsibilities**

- **R (Shiny modules)**: catalog filtering, workout editor state, validation, YAML
  read/write, compiling a workout into a flat list of steps, duration estimate, summary.
- **JavaScript (small, hand-written, no build step)**: the workout *player* (timer,
  keyboard, sounds, wake lock), localStorage access, and a little event delegation for the
  editor. The player lives in JS because a countdown needs accurate timing and instant key
  response. Driving a ticking clock through Shiny reactivity (webR runs in a web worker)
  would be jittery and drift. R hands the compiled workout to JS once, and JS reports
  events back.

**Shinylive constraints that shape the design**

1. *No server storage*: persistence is YAML files (download / upload) plus browser
   `localStorage`.
2. *Everything inside `app/` is bundled* into the initial download, so the catalog JSON
   (~2 MB) is fine but **images must live outside `app/`**: copied into `_site/img/`
   after export.
3. *First load is heavy* (webR + packages, roughly 10–30 MB, cached by the browser
   afterwards). Keep dependencies minimal and show a loading screen.
4. A few Shiny features behave differently in WASM (downloads, `www/` assets, `R/`
   autoloading). Phase 0 checks each one before we build on it.

**Not an R package** (no golem / rhino): a plain `app/` folder with an `R/` subfolder of
modules is the simplest thing Shinylive exports. Pure functions stay testable with testthat.

---

## 3. Repository layout

```
shiny_workout/
├── app/                          # bundled by shinylive: keep it lean
│   ├── app.R                     # page layout + module wiring
│   ├── config.yml                # enabled equipment / focus, initial default values
│   ├── R/
│   │   ├── catalog.R             # load, filter, look up exercises
│   │   ├── workout_model.R       # new/validate/compile/estimate (pure functions)
│   │   ├── workout_yaml.R        # to/from YAML, schema versioning
│   │   ├── settings.R            # defaults: config.yml → user settings → workout settings
│   │   ├── mod_catalog.R         # browse + filter + details
│   │   ├── mod_editor.R          # build/edit a workout
│   │   ├── mod_library.R         # saved workouts, examples, import/export
│   │   ├── mod_settings.R        # editable defaults (modal)
│   │   ├── mod_player.R          # R side of the player (sends steps, receives events)
│   │   └── ui_helpers.R          # step cards, icons, formatting (mm:ss)
│   ├── data/exercises.json       # GENERATED by data-raw/build_catalog.R (committed)
│   ├── workouts/                 # bundled example workouts (*.yaml)
│   └── www/
│       ├── player.js             # timer state machine, keys, audio, wake lock
│       ├── storage.js            # localStorage bridge
│       ├── editor.js             # click delegation for step cards
│       └── styles.css
├── data-raw/
│   ├── build_catalog.R           # orchestrates import → normalise → dedupe → write
│   ├── import_free_exercise_db.R
│   ├── import_wger.R
│   ├── import_yoga_api.R
│   ├── vocab.yaml                # source equipment/category/muscle → our vocabulary
│   ├── curation.yaml             # excludes, duplicate merges, focus overrides
│   └── curated/
│       ├── pilates.yaml          # classic mat repertoire (our own text)
│       ├── physio.yaml           # common rehab / prehab exercises (our own text)
│       └── extras.yaml           # gaps: wall sit, skaters, plank variants, …
├── docs/workout-format.md        # YAML schema reference for humans
├── scripts/build_site.R          # run tests → shinylive::export("app", "_site") → copy images
├── tests/testthat/               # unit tests (outside app/, so not bundled)
├── .github/workflows/deploy.yml  # test + export + deploy to Pages
├── CREDITS.md                    # GENERATED: data sources, licenses, attributions
├── renv.lock, .Rprofile, renv/   # R 4.6 + pinned dev packages (incl. shinylive)
├── shiny_workout.Rproj
├── README.md
└── LICENSE                       # GPL-3.0 (existing)
```

Note: the current `.gitignore` ignores `docs/` (a pkgdown leftover). Phase 0 removes that
line and adds `_site/` and `.DS_Store`.

---

## 4. Exercise catalog

### 4.1 Sources compared

| Source | Size | License | Fit for us |
|---|---|---|---|
| [free-exercise-db](https://github.com/yuhonas/free-exercise-db) | 876 | **Unlicense** (public domain), images too | Gym-heavy. ~220 match our equipment (106 strength, 89 stretching, 21 plyometrics). 2 photos per exercise. Consistent quality. |
| [wger](https://wger.de) (public API) | 904, all in English (140 also in Italian) | Exercises **CC-BY-SA 4.0 / 3.0** (26 CC0); images CC-BY-SA; per-exercise author attribution | **518** use only bodyweight / mat / swiss ball / band / nothing listed (161 legs, 80 abs, 77 back, 51 cardio, …). Fills the HIIT gaps: burpees, jumping jacks, high knees, bird dog, clamshells, glute bridges, **15 plank variants**. Only 145 of those 518 have an image. Community-contributed, so it has duplicates and uneven quality and needs curation. |
| [yoga-api](https://github.com/alexcumplido/yoga-api) | **48 poses**, 12 categories | Code/data MIT. Images: red set CC0; pink / green sets from Flaticon (attribution required) | English + Sanskrit names, description, benefits, level, category (standing, balancing, hip opening, restorative, …), SVG/PNG. Some text was taken from older repos with unclear licenses, so we import names, categories and levels, and use descriptions only after checking where they came from. |
| Curated by us | ~40 pilates + ~40 physio + extras | Ours | No open pilates or physiotherapy dataset exists. We write short original instructions for the classic mat pilates repertoire (hundred, roll up, single / double leg stretch, saw, swimming, teaser, side kick series, …) and common physio moves (clamshell, heel slides, straight-leg raise, chin tucks, scapular retraction, wall slides, McGill curl-up, terminal knee extension with band, …). |
| ~~RepDB free tier~~ | 701 | Custom: in-app use OK, **no redistribution as a dataset** | Rejected: committing it to a public repo is redistribution. |
| ~~exercises-dataset (hasaneyldrm)~~ | 1,324 GIFs | Text MIT, but **GIFs © Gym visual**, used by that repo with permission | Rejected for media; gym-heavy anyway. |
| ~~ExerciseDB API~~ | 1,300+ | Copyrighted media | Rejected. |
| ~~Roboflow yoga datasets~~ | – | CC BY 4.0 | These are photos for training pose-detection models, not instructional content. |

**Recommendation**: base = free-exercise-db + wger + yoga-api + our curated files.
**License note**: because wger is share-alike, the generated `app/data/exercises.json` is
published under **CC-BY-SA 4.0** with per-exercise attribution, separately from the
GPL-3.0 code. That is fine in a GPL repo. `CREDITS.md` and an in-app "About & credits"
dialog list every source.

### 4.2 Import pipeline (`data-raw/build_catalog.R`, run manually to refresh)

1. **Fetch** each source at a pinned version: commit SHA for free-exercise-db and yoga-api;
   a dated snapshot of the wger API saved to `data-raw/snapshots/` so builds don't depend
   on a live API.
2. **Normalise** to one schema:

   | Field | Notes |
   |---|---|
   | `id` | `<source>:<source id>`, e.g. `fedb:Pushups`, `wger:1234`, `yoga:15`, `cur:pilates_hundred` |
   | `name`, `instructions` | English; wger HTML descriptions are cleaned to plain text |
   | `aliases` | other names, e.g. the Sanskrit name for yoga poses |
   | `focus` | one or more of `strength`, `hiit`, `core`, `mobility`, `yoga`, `pilates`, `physio` |
   | `equipment` | our vocabulary: `bodyweight`, `mat`, `exercise_ball`, `bands`, `foam_roller`, `dumbbell`, … (mapped via `vocab.yaml`) |
   | `level` | beginner / intermediate / expert, where known |
   | `primary_muscles`, `secondary_muscles` | our vocabulary (mapped via `vocab.yaml`) |
   | `default` | suggested target: `hold` (isometric, e.g. planks and yoga poses) → 30 s; stretch → 30 s; otherwise 10 reps |
   | `unilateral` | true if usually done per side (suggests `sides: 2` when added) |
   | `images` | source paths / URLs (used in Phase 7) |
   | `source`, `license`, `attribution` | for credits, per exercise |
   | `garmin` | *reserved*, empty for now: future FIT exercise category/name mapping |

3. **Dedupe** across sources (e.g. "Plank" exists in two of them). Exact name matches are
   merged automatically, and `curation.yaml` lists the rest by hand. Preferred source order:
   curated > free-exercise-db > wger > yoga-api.
4. **Curate**: `curation.yaml` drops junk or duplicate wger entries and fixes `focus` tags.
   Exercises with no equipment listed are treated as bodyweight unless excluded.
5. **Write** `app/data/exercises.json` (everything) and regenerate `CREDITS.md`.

### 4.3 Filtering "on the backend"

The catalog ships complete. `app/config.yml` decides what the UI shows:

```yaml
catalog:
  enabled_equipment: [bodyweight, mat, exercise_ball, bands, foam_roller]
  enabled_focus: [strength, hiit, core, mobility, yoga, pilates, physio]
  show_all_toggle: false   # if true, the user can reveal the rest of the catalog
```

### 4.4 Catalog UI (left column of the Build tab)

- Search (name, alias, muscle), filters: **focus**, equipment (within the enabled set),
  primary muscle, level, source.
- Compact rows: thumbnail (Phase 7), name, focus / muscle / equipment badges, "+" button.
- Clicking a row opens a details modal: instructions, muscles, equipment, credits line.
- "+" adds the exercise with its default target (and `sides: 2` if unilateral).

---

## 5. Workout data model (YAML, schema v1)

Designed to be read and written by hand, and to map 1:1 onto Garmin's step model later.

```yaml
schema_version: 1
name: Morning core, mobility & rehab
description: 30 min, mat + band
sport: pilates             # strength | hiit | mobility | yoga | pilates | physio
tags: [home, core]
settings:                  # optional, override the user's defaults for this workout
  prep_seconds: 10
  seconds_per_rep: 3
steps:
  - type: warmup
    exercise: yoga:7                  # Cat pose (Marjaryasana)
    seconds: 60
    advance: auto

  - type: repeat
    times: 3
    skip_last_rest: true              # don't rest after the final round
    steps:
      - type: exercise
        exercise: fedb:Pushups
        reps: 12
        advance: manual               # press Space / tap "Done"
        notes: slow on the way down
      - type: exercise
        exercise: fedb:Plank
        seconds: 45
        advance: auto                 # moves on by itself at 0:00
      - type: exercise
        exercise: cur:physio_clamshell
        reps: 10
        hold_seconds: 3               # guided reps: hold 3 s, relax, ×10
        sides: 2                      # left then right
        advance: auto
      - type: rest
        seconds: 30
        advance: auto

  - type: exercise
    name: Box breathing, lying down   # free-text step (no catalog exercise)
    seconds: 90
    advance: auto

  - type: cooldown
    advance: manual                   # open-ended: stretch until you press Space
```

**Step types**: `warmup`, `exercise`, `rest`, `cooldown`, `repeat`.

**Targets and advancing**, one rule set for all non-repeat steps:

| `reps` | `seconds` | `advance` | Player behaviour |
|---|---|---|---|
| – | ✓ | `auto` | countdown, moves on at 0 |
| – | ✓ | `manual` | countdown, at 0 beeps and **counts overtime (+0:05…) until Space** |
| ✓ | – | `manual` | shows "12 reps", counts elapsed time up, waits for Space |
| ✓ | ✓ | `auto` | shows "12 reps" with a time limit, moves on at 0 (or earlier on Space) |
| – | – | `manual` | open step (Garmin's "lap button") |

Two modifiers, added for yoga / pilates / physio:

- **`sides: 2`**: the step runs twice, labelled *Left* and *Right*. The target applies per
  side, with a short "switch sides" countdown in between (default 5 s, editable).
- **`hold_seconds`** (needs `reps`): **guided reps**. The player counts *Rep 3/10*, beeps
  at the start and end of each hold, and adds a short relax between reps (default 3 s,
  editable via `relax_seconds`). This is the typical physio "10 × 5 s hold" prescription.

Validation: `advance: auto` requires `seconds` or `hold_seconds`; `hold_seconds` requires
`reps`; `sides` ∈ {1, 2}. Space always ends the current step early. Optional per step:
`notes`, `weight` (free text, e.g. "red band"). A step references a catalog `exercise` **or**
carries a free-text `name`.

**Repeat blocks**: `times ≥ 1`, `skip_last_rest`, one nesting level in v1 (the schema
doesn't forbid more later).

**Core pure functions** (`workout_model.R`, all unit-tested):

- `new_workout()`, `new_step(type, …)`
- `validate_workout(w, catalog)` → errors (block loading/saving) and warnings (e.g. an
  unknown exercise id still loads, shown as "Unknown exercise").
- `compile_workout(w, settings, catalog = NULL)` → flat list (a data frame) of atomic steps: repeats expanded
  (`Round 2/3`), sides expanded (`Left` / `Right` + switch countdown), exercise names
  resolved, `next` preview. This is what the player runs.
- `estimate_duration(w, settings, catalog = NULL)` → total and per-block estimate.
- `workout_to_yaml()` / `workout_from_yaml()` with stable key order, nulls dropped, and
  round-trip tests. Internal UI ids (`uid`) are stripped on save.

**Defaults** are resolved in layers: `config.yml` (app) → Settings panel (user, saved in
localStorage) → `settings:` in the workout YAML. Editable values: prep, default rest,
default reps, default time, default hold, relax between holds, switch-sides time, seconds
per rep for estimates.

**Garmin mapping (for later)**: `warmup/exercise/rest/cooldown` → FIT intensity;
`seconds + auto` → duration *time*; `reps` → duration *reps*; manual without seconds →
*open / lap button*; `repeat` → *repeat until steps complete*; `sides` and guided reps
are expanded before export; `exercise` → FIT exercise category / name via the catalog's
`garmin` field.

---

## 6. UI and UX

`bslib::page_navbar` with three tabs, plus Settings (gear icon), About & credits, and a
light/dark toggle.

### Build (laptop: two columns; phone: stacked, catalog opens as a modal)

- **Left: catalog** (§4.4).
- **Right: workout editor**
  - Header: name, sport, description, tags.
  - **Step list** as cards, coloured by type (warm-up orange, exercise green, rest blue,
    cool-down purple, repeat block framed with "× 3").
    Each card: name, target summary (`12 reps · manual`, `0:45 · auto`,
    `10 × 3 s hold · each side`), notes, and actions: edit, duplicate, move up/down, delete.
  - **Drag & drop** reordering with `sortable` (available in webR). Moving steps in and
    out of repeat blocks by drag is a stretch goal; the "move into block" buttons always work.
  - Add bar: `+ Exercise` (from catalog), `+ Rest`, `+ Warm-up`, `+ Cool-down`,
    `+ Repeat block`, `+ Custom step`.
  - **Edit modal**: exercise (searchable select), reps, seconds, hold, sides, advance mode,
    notes, weight.
  - **Summary panel**: estimated duration, number of exercises and sets, focus mix,
    muscles worked, equipment needed.
  - Undo / redo (cheap: keep a short history of workout states).
  - Draft autosaved to localStorage, so a reload doesn't lose work.

Implementation note: step cards are rendered by one `renderUI`; clicks reach R through **one**
delegated JS handler (`Shiny.setInputValue("editor-action", {op, uid})`) instead of one
observer per card. This avoids the classic duplicated-observer bugs of dynamic Shiny UIs.

### Library

- **My workouts** (localStorage): open, duplicate, rename, delete, download.
- **Examples** bundled in `app/workouts/` (read-only; "open as copy"): one per focus,
  e.g. bodyweight HIIT, plank ladder, yoga flow, pilates mat basics, knee rehab.
- **Import**: upload one or more `.yaml` files → validated, with readable error messages.
- **Export**: download the current workout as `<name>.yaml`; "export all" as a single
  multi-document YAML file (backup).

### Run (player)

- Big, readable layout for across-the-room viewing: current step name, huge countdown or
  rep target, `Round 2/3`, `Left` / `Right`, `Rep 3/10 · hold`, image (Phase 7), notes,
  **next up** card, total progress bar, elapsed / remaining time.
- **Keyboard**: `Space` = done / next · `P` = pause / resume · `←` / `→` = previous / next
  step · `Esc` = stop (asks to confirm) · `F` = fullscreen.
- **Touch**: large "Done" button; tap to pause.
- "Get ready" countdown before the first step (default 10 s).
- **Sound** (Web Audio, no files): beeps at 3-2-1, a distinct tone on step change, a softer
  chime set for yoga / pilates / physio. Optional **voice** (browser speech synthesis):
  "Next: Side plank, left, 30 seconds".
- **Screen Wake Lock** so the laptop or phone screen doesn't sleep mid-workout.
- Timing uses timestamps (`performance.now()`), not counted ticks, so it doesn't drift and
  survives background-tab throttling.
- End screen: total time, actual time per step, rounds completed; optional download of the
  session log (YAML).
- Player preferences in localStorage: sound, voice, volume.

About & credits includes a short note: *physiotherapy exercises are general examples, not
medical advice; follow your physiotherapist's prescription.*

---

## 7. Environment, build, test and deploy

### R version

**Cleanup: done on 2026-11-02.** Homebrew R 4.5.0 (with its 820 MB site-library) and the
leftover CRAN R 4.4 framework (8.1 GB) were removed, and no orphaned Homebrew dependencies
were left. Only R 4.6.0 remains; `R` resolves to it in the terminal and in RStudio. The old
package lists and a reinstall script (`pak`, covering CRAN, Bioconductor and GitHub) are saved
in `~/R_package_backup/`. They're unrelated to this project.

**Pinning**

- **renv** in the project: `renv.lock` records R 4.6.0 and the exact dev package versions,
  including `shinylive`. That also pins the Shinylive web assets, and so the browser-side
  webR / R version, which makes builds reproducible. renv lives outside `app/`, so it is
  never bundled.
- CI uses the same lockfile (`r-lib/actions/setup-r` with R 4.6 + `r-lib/actions/setup-renv`).
- Phase 0 prints `R.version.string` inside the exported app to confirm which R the
  browser actually runs.

### Local development loop

1. `shiny::runApp("app")` from RStudio: normal R, fast reload, most of the work happens here.
2. Periodically: `source("scripts/build_site.R")` → `shinylive::export("app", "_site")`
   → serve `_site/` locally (`httpuv::runStaticServer("_site")`) and test the real WASM
   build. I can drive this in the built-in browser to check behaviour and take screenshots.

### Tests

- testthat for all pure R: each importer and normalisation, dedupe, config filtering,
  validation rules, YAML round-trip, `compile_workout` (repeats, `skip_last_rest`, sides,
  guided reps, free-text steps), settings layering, duration estimate.
- Manual QA checklist for the player (keys, auto/manual advance, overtime, sides, guided
  reps, pause, wake lock, sound), run on Chrome, Firefox and Safari plus one phone.
- (Optional, later) a shinytest2 smoke test.

### GitHub Actions (`.github/workflows/deploy.yml`)

Adapted from `posit-dev/r-shinylive`'s example, because our app lives in `app/` and needs
extra steps:

1. Set up R 4.6 + renv restore.
2. Run tests and fail early.
3. `shinylive::export("app", "_site")`.
4. (Phase 7) copy the enabled exercise images into `_site/img/`.
5. `actions/upload-pages-artifact` → `actions/deploy-pages`.

PRs run steps 1–3 only, without deploying. Pages must be set to "GitHub Actions" as the
source in the repo settings (one click, done by you in Phase 0).

---

## 8. Phases and milestones

Each phase ends with something runnable. Effort is relative (S/M/L).

### Phase 0: Environment, skeleton and Shinylive spike (S) ✓ done 2026-11-03
- renv with R 4.6.0; install shinylive, sortable, bsicons, testthat (R cleanup already done).
- `.gitignore` fixes, commit `shiny_workout.Rproj`, folders from §3, README stub.
- Minimal `app.R` (bslib navbar) proving in **the exported WASM build**
  (Diagnostics tab; checked in the local WASM build on 2026-11-02):
  - [x] `R/` folder modules load,
  - [x] `www/` JS and CSS are served,
  - [x] `downloadHandler` produces a YAML file,
  - [x] `fileInput` reads a YAML file,
  - [x] localStorage round-trip via custom messages (survives reload),
  - [x] Space, P, arrows and Esc reach R; the page doesn't scroll,
  - [x] Space doesn't click a button focused with Tab,
  - [x] browser-side R version: webR runs **R 4.6.0**.
- Note: package versions in webR differ from local renv: shiny 1.13.0.8000 and bslib
  0.11.0 in the browser (local: shiny 1.14.0, bslib 0.12.0). Use only features present in
  the webR versions, and check them on the Diagnostics tab when it matters.
- Actions workflow → **live "hello" URL on GitHub Pages**: deployed 2026-11-02 to
  <https://sinomem.github.io/shiny_workout/>.
- Note: the first CI run failed because `openssl` 2.5.0 was on CRAN but not yet on Posit
  Package Manager, which CI installs from. Pinned 2.4.2. If this recurs, point local renv
  at the same PPM repository so the lockfile only records versions CI can install.
- Note: Claude's in-app browser blocks service workers, so it can't run Shinylive; WASM
  checks happen in a regular browser (local `_site/` or the live URL).
- Note: `page_navbar(fillable = FALSE)`: with fill layout, the cards collapsed to zero
  height and Shiny skipped rendering them.
- *Exit*: every checkbox works on the live URL. If one doesn't, we adapt the design here.

### Phase 1: Workout model and YAML (M) ✓ done 2026-11-03
- Schema v1 (incl. sides and guided reps), `workout_model.R`, `workout_yaml.R`,
  `settings.R`, `docs/workout-format.md`.
- Example workouts (one per focus, plus a plank ladder), written with free-text `name`s
  for now; Phase 2 points them at catalog ids.
- Full unit tests.
- *Exit*: `compile_workout()` turns each example into the expected flat step list
  (snapshot tests in `tests/testthat/_snaps/examples.md`).

### Phase 2: Catalog (L) ✓ done 2026-11-04
- Importers for free-exercise-db, wger (snapshot), yoga-api; `vocab.yaml`; dedupe;
  `curation.yaml`; curated `pilates.yaml`, `physio.yaml`, `extras.yaml`; `CREDITS.md`.
- `mod_catalog`: search, filters, details modal (text only).
- *Exit*: the enabled catalog (estimated 600–700 exercises after dedupe and curation) is
  browsable and filterable by focus, with credits shown.
- Status (2026-11-04): ✓ done, checked in the WASM build. 1,770 exercises in all,
  **618 enabled** (wger 264, free-exercise-db 228, curated 86, yoga-api 40). The examples
  now use catalog ids. "+" only shows a notification until the editor exists (Phase 3).
- Notes:
  - wger has 930 English exercises but often tags gym exercises as bodyweight or leaves
    equipment empty; `vocab.yaml` fixes equipment from the name (machine, bar, …).
  - yoga-api pose descriptions come from an unlicensed upstream project, so the 37
    yoga-api poses have no instructions yet. Follow-up: write our own short instructions
    (curation `set:` or a curated file).
  - The yoga importer reads yoga-api's SQLite file, so RSQLite is a dev dependency.
  - Server-side `debounce()` didn't fire on its own for the search box; `textInput`
    already waits for a pause in typing, so the extra debounce was removed.

### Phase 3: Editor (L) ✓ done 2026-11-04
- Step cards, add / edit / duplicate / delete / move, repeat blocks, sides, holds,
  drag & drop, summary, undo, draft autosave.
- *Exit*: the example workouts can be rebuilt from scratch in the UI.
- Status (2026-11-04): ✓ done, checked in regular Shiny and the WASM build.
  `editor_ops.R` (pure, tested) + `mod_editor.R` + `www/editor.js`. The knee example is
  rebuilt from the edit modal's inputs in `test-editor-rebuild.R`.
- Notes:
  - Added a "Timing for this workout" panel (get ready, relax, switch sides), because two
    examples override those settings; the full Settings panel is still Phase 4.
  - "+ Custom step" is the exercise modal with only a name filled in, so there's no
    separate button.
  - Drag and drop works within one list (top level, or inside one block); moving between
    them uses the "move into / out of block" buttons, as planned.
  - SortableJS 1.15.6 (MIT) is vendored in `app/www/vendor/` instead of using the
    `sortable` R package, which would make webR download learnr, rmarkdown and knitr.

### Phase 4: Save, load, library, settings (M)
- Download / upload YAML with validation messages, localStorage library, examples,
  export all; Settings panel for editable defaults.
- *Exit*: build → save → reload page → open from library → identical workout; same via file.
- Status (2026-11-04): ✓ done, checked in regular Shiny and the WASM build (downloads included).
  `library.R` (pure, tested: the library JSON and multi-workout YAML round trips give
  identical workouts) + `mod_library.R`. Checked in the browser: save, reload, rename,
  delete, open example, import (one good and one broken workout in one file), settings
  saved across reloads. Not checked by me: the actual file downloads (needs your browser).
- Notes:
  - Downloads are made in the browser from text R sends (`sw-download` in storage.js),
    not with `downloadHandler`, so each library row can have its own Download button.
  - The open workout remembers which library entry it came from, so Save updates that
    entry; the editor shows "Saved in your library" / "Unsaved changes".
  - The draft is now stored as JSON (library id + YAML); older YAML drafts still load.
  - Card buttons in the editor and library share one delegated handler (`actions.js`).

### Phase 5: Player (L)
- `player.js` state machine, layout, keyboard + touch, overtime, sides, guided reps,
  sounds, voice, wake lock, fullscreen, end summary + log.
- *Exit*: every example runs end to end, with no drift against a stopwatch over 20+ min.
- Status (2026-11-05): ✓ done, checked in regular Shiny and the WASM build (Chrome; Firefox
  except voice, see below). The 20+ min stopwatch check is still open.
  `player.R` (pure, tested: plan, spoken text, session log) + `mod_player.R` + `www/player.js`.
  With the clock driven by hand, all 7 examples run end to end and the active time equals
  the planned time exactly; with 7 s gaps between ticks (a throttled background tab) and a
  2 min pause, auto steps still end on their planned time. A real 20+ min stopwatch check
  is left for you.
- Notes:
  - Auto steps end at start + duration, not at the tick that notices it, so a late tick
    never shifts the steps after it. Manual steps start when you press Space.
  - The Run tab plays the workout open in the editor. "Run" buttons in the editor and on
    each library / example row put it there first.
  - ← redoes the previous step (its earlier time is dropped from the log); stopping logs
    the step in progress as "stopped".
  - Full screen falls back to filling the browser window when the browser refuses it.
  - Player preferences (sound, voice, chosen voice, volume) live in localStorage as
    `shiny_workout.player`, separate from the R settings.
  - Voice: browsers tend to use the first voice in their list, which on a Mac is a
    novelty voice (Albert: low, slow, robotic). The player skips the novelty voices and
    picks a natural English one (Premium / Enhanced first, then Daniel, Samantha, Karen,
    Moira…, preferring the browser's region); a picker next to the voice button overrides it.
  - Known limitation: in Firefox on macOS every phrase crackles at the end, whatever the
    voice, volume or beeps (tested one change at a time). Chrome is fine. The player shows
    a short note in Firefox when voice is on; sounds (beeps) work in both.
  - The browser pane I test with doesn't run IntersectionObserver while hidden, so Shiny
    outputs on other tabs don't render there; tests drive inputs directly instead.

### Phase 6: Polish and phone usability (M)
- Responsive checks at phone width, dark mode, loading screen, keyboard-shortcut help
  overlay, About & credits, README with screenshots and a "write a workout in YAML" section.
- *Exit*: v1.0 tagged and live.

### Phase 7: Images (M, later)
- free-exercise-db: 2 photos per exercise alternating every ~1 s (GIF-like).
- wger: images where available (CC-BY-SA, credited).
- yoga-api: CC0 (red) SVGs; the Flaticon sets only with their attribution line.
- Curated pilates / physio: our own illustrations or none at first.
- Vendor the images of enabled exercises into `_site/img/` (lazy-loaded), never inside `app/`.

### Backlog (post v1)
- Garmin FIT workout export (mapping in §5; evaluate Garmin's official FIT JavaScript SDK
  vs a minimal encoder).
- "Add to my catalog" for user-defined exercises.
- Share a workout by link (YAML compressed into the URL `#hash`, nothing sent to a server).
- Workout history / log across sessions.
- Breaths as a unit for yoga holds; tempo (e.g. 3-1-1) for pilates / physio.
- Supersets, nested repeats, EMOM / Tabata templates (generate steps from 3 numbers).

---

## 9. Risks

| Risk | Mitigation |
|---|---|
| A Shiny feature doesn't work under Shinylive (downloads, `www/`, `R/` autoload) | Phase 0 spike on the live URL before any real feature. Fallbacks: inline JS/CSS via `tags$script(HTML(...))`, explicit `source()`, JS-side Blob download. |
| Slow first load, especially on phone | Minimal packages, loading screen; the browser caches after the first visit. |
| wger quality (duplicates, junk, missing equipment) | Dated snapshot + `curation.yaml` excludes and merges; filters by source. |
| License mix (Unlicense, CC-BY-SA, CC0, Flaticon) | Per-exercise `license` / `attribution` fields, generated `CREDITS.md`, data published as CC-BY-SA 4.0 separately from GPL code; Flaticon images only with attribution. |
| No open pilates / physio data | Curated files with our own text; physio disclaimer. |
| localStorage is per browser and can be cleared | YAML files are the source of truth; "export all" backup; documented in README. |
| Space bar conflicts (scrolling, focused buttons, text inputs) | Player captures keys only on the Run tab and outside text inputs; `preventDefault`. |
| Timer drift / background tabs | Timestamp-based timing + wake lock (Phase 5 exit test). |

---

## 10. Open questions

None. Resolved on 2026-11-02:

1. **R cleanup**: done. Only R 4.6.0 remains; old package lists saved in `~/R_package_backup/`.
2. **Extra equipment**: foam roller enabled; yoga props (block, strap) later.
3. **Data license**: catalog published as CC-BY-SA 4.0 next to the GPL-3.0 code.
