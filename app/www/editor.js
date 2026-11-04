// Workout editor drag and drop: SortableJS (www/vendor, MIT) makes each step list
// draggable and sends the new order. Card buttons go through www/actions.js. Lists are
// re-rendered by Shiny after each change, so new lists are picked up with a
// MutationObserver.
(function () {
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
