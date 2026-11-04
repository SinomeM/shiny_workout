// localStorage bridge between R and the browser.
// R -> JS: "sw-storage-set" {key, value}, "sw-storage-get" {key, input}
// JS -> R: Shiny input `input` = {key, value} (value is null when missing).
// Also "sw-download" {filename, text}: saves text as a file, without a server round trip.
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
    Shiny.addCustomMessageHandler("sw-download", function (msg) {
      var blob = new Blob([msg.text], { type: "application/x-yaml;charset=utf-8" });
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = msg.filename;
      document.body.appendChild(a);
      a.click();
      setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
    });
  }

  if (window.Shiny && Shiny.addCustomMessageHandler) {
    register();
  } else {
    document.addEventListener("DOMContentLoaded", register);
  }
})();
