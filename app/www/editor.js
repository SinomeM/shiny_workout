// Workout editor. One delegated click handler sends {op, uid, container} for every card
// button and add button; SortableJS (www/vendor, MIT) makes each step list
// draggable and sends the new order. Lists are re-rendered by Shiny after each change,
// so new lists are picked up with a MutationObserver.
(function () {
  document.addEventListener("click", function (e) {
    var btn = e.target.closest("[data-sw-op]");
    var root = btn && btn.closest("[data-sw-editor]");
    if (!root || !window.Shiny) return;
    Shiny.setInputValue(root.dataset.swEditor, {
      op: btn.dataset.swOp,
      uid: btn.dataset.uid || "",
      container: btn.dataset.container || "",
      t: Date.now()
    }, { priority: "event" });
  });

  function initLists() {
    if (!window.Sortable) return;
    document.querySelectorAll("[data-sw-sortable]").forEach(function (el) {
      if (el.swSortable) return;
      el.swSortable = Sortable.create(el, {
        handle: ".sw-drag",
        draggable: ".sw-card",
        animation: 150,
        onEnd: function (evt) {
          if (evt.oldIndex === evt.newIndex) return;
          Shiny.setInputValue(el.dataset.swSortable, {
            container: el.dataset.container || "",
            order: el.swSortable.toArray(),
            t: Date.now()
          }, { priority: "event" });
        }
      });
    });
  }

  var pending = null;
  new MutationObserver(function () {
    if (pending) return;
    pending = setTimeout(function () { pending = null; initLists(); }, 0);
  }).observe(document.documentElement, { childList: true, subtree: true });
})();
