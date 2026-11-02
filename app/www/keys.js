// Keyboard shortcuts for the player. Keys are captured only while an element
// with a `data-sw-keys="<input id>"` attribute is visible, and never while the
// user is typing. Handled keys are reported to R as {key, t}.
(function () {
  var HANDLED = [" ", "p", "P", "ArrowLeft", "ArrowRight", "Escape", "f", "F"];

  function activeZone() {
    var zones = document.querySelectorAll("[data-sw-keys]");
    for (var i = 0; i < zones.length; i++) {
      if (zones[i].offsetParent !== null) return zones[i];
    }
    return null;
  }

  function isTyping(el) {
    return el && (el.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName));
  }

  function handle(e) {
    if (HANDLED.indexOf(e.key) < 0 || isTyping(e.target)) return;
    var zone = activeZone();
    if (!zone) return;
    // Stop page scrolling and Space/Enter activation of a focused button.
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "keydown" && !e.repeat && window.Shiny && Shiny.setInputValue) {
      var key = e.key === " " ? "Space" : e.key;
      Shiny.setInputValue(zone.dataset.swKeys, { key: key, t: Date.now() }, { priority: "event" });
    }
  }

  // Capture phase, so we run before button handlers.
  document.addEventListener("keydown", handle, true);
  document.addEventListener("keyup", handle, true);
})();
