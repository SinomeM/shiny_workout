# README screenshots (docs/screenshots/*.png), taken with headless Chrome.
# Needs the chromote package (not part of renv: it's only for this script) and the app
# running locally: shiny::runApp("app", port = 8010). Usage:
#   Rscript scripts/screenshots.R [url]

url <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(url)) url <- "http://127.0.0.1:8010"
out <- "docs/screenshots"
dir.create(out, showWarnings = FALSE, recursive = TRUE)

b <- chromote::ChromoteSession$new()
js <- function(code) {
  b$Runtime$evaluate(code, awaitPromise = TRUE, returnByValue = TRUE)$result$value
}
wait_for <- function(code, timeout = 30) {
  start <- Sys.time()
  while (!isTRUE(js(code))) {
    if (difftime(Sys.time(), start, units = "secs") > timeout) stop("Timed out waiting for: ", code)
    Sys.sleep(0.25)
  }
}
viewport <- function(width, height, mobile = FALSE) {
  b$Emulation$setDeviceMetricsOverride(width = width, height = height, deviceScaleFactor = 2, mobile = mobile)
}
open_app <- function() {
  b$Page$navigate(url)
  wait_for("!!(window.Shiny && Shiny.shinyapp && Shiny.shinyapp.isConnected() && window.swPlayer)")
  Sys.sleep(1.5)
}
action <- function(op, id) {
  js(sprintf("Shiny.setInputValue('library-action', {op: '%s', id: '%s', t: Date.now()}, {priority: 'event'})", op, id))
  Sys.sleep(1.5)
}
tab <- function(name) {
  js(sprintf("document.querySelector('a[data-value=\"%s\"]').click(); window.scrollTo(0, 0)", name))
  Sys.sleep(1.5)
}
shot <- function(name, width, height) {
  b$screenshot(file.path(out, name), cliprect = c(0, 0, width, height), scale = 2, show = FALSE)
  message("Wrote ", file.path(out, name))
}
# Drive the player's clock by hand, so the screenshot shows a chosen moment. Each move
# is c(seconds to wait, 1 to press Space afterwards).
player_at <- function(...) {
  js("window.fake = 1e6; swPlayer.setClock(() => window.fake); swPlayer.act('start')")
  for (m in list(...)) {
    js(sprintf("window.fake += %f; swPlayer.tick()", m[1] * 1000))
    if (m[2] == 1) js("swPlayer.act('done')")
  }
  Sys.sleep(0.5)
}

b$Emulation$setEmulatedMedia(features = list(list(name = "prefers-color-scheme", value = "light")))

# Laptop
viewport(1280, 800)
open_app()
js("localStorage.clear()")
open_app()
action("open_example", "knee-rehab")
js("document.getElementById('editor-save').click()")
Sys.sleep(1)
action("open_example", "bodyweight-hiit")
js("document.getElementById('editor-save').click()")
Sys.sleep(1)
tab("Build")
shot("build.png", 1280, 800)
tab("Library")
shot("library.png", 1280, 800)

action("run_example", "bodyweight-hiit")
player_at(c(10, 0), c(120, 0), c(13, 0))   # get ready, warm-up, 13 s into squat jumps
shot("run.png", 1280, 800)

# Phone
viewport(390, 844, mobile = TRUE)
open_app()
action("run_example", "knee-rehab")
# Get ready, heel slides (left, done), switch sides, heel slides (right, done), then
# 10 s into the guided quad sets: rep 2, holding.
player_at(c(10, 0), c(4, 1), c(10, 0), c(4, 1), c(10, 0))
shot("phone-run.png", 390, 844)

b$close()
