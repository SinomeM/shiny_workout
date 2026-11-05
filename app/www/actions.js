// Delegated buttons: any element with data-sw-op inside a [data-sw-actions] container
// sends {op, uid, id, container} to the Shiny input the container names. This avoids
// one observer per button in lists that Shiny re-renders.
(function () {
  document.addEventListener("click", function (e) {
    var btn = e.target.closest("[data-sw-op]");
    var root = btn && btn.closest("[data-sw-actions]");
    if (!root || !window.Shiny) return;
    Shiny.setInputValue(root.dataset.swActions, {
      op: btn.dataset.swOp,
      uid: btn.dataset.uid || "",
      id: btn.dataset.id || "",
      container: btn.dataset.container || "",
      t: Date.now()
    }, { priority: "event" });
  });

  // "?" opens the help, unless the user is typing or a dialog is open.
  document.addEventListener("keydown", function (e) {
    var t = e.target;
    if (e.key !== "?" || !window.Shiny || document.querySelector(".modal.show")) return;
    if (t && (t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName))) return;
    e.preventDefault();
    Shiny.setInputValue("help_key", Date.now(), { priority: "event" });
  });
})();
