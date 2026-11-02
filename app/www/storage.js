// localStorage bridge between R and the browser.
// R -> JS: "sw-storage-set" {key, value}, "sw-storage-get" {key, input}
// JS -> R: Shiny input `input` = {key, value} (value is null when missing).
(function () {
  function safe(fn, fallback) {
    try {
      return fn();
    } catch (e) {
      return fallback;
    }
  }

  function register() {
    Shiny.addCustomMessageHandler("sw-storage-set", function (msg) {
      safe(function () { localStorage.setItem(msg.key, msg.value); });
    });
    Shiny.addCustomMessageHandler("sw-storage-get", function (msg) {
      var value = safe(function () { return localStorage.getItem(msg.key); }, null);
      Shiny.setInputValue(msg.input, { key: msg.key, value: value }, { priority: "event" });
    });
  }

  if (window.Shiny && Shiny.addCustomMessageHandler) {
    register();
  } else {
    document.addEventListener("DOMContentLoaded", register);
  }
})();
