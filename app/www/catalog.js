// Catalog list: one delegated handler for every row. A click (or Enter) on a row opens
// its details; a click on its "+" button adds it. The container names the inputs.
(function () {
  function send(list, attr, id) {
    Shiny.setInputValue(list.dataset[attr], { id: id, t: Date.now() }, { priority: "event" });
  }

  function handle(e) {
    var list = e.target.closest("[data-sw-open]");
    if (!list || !window.Shiny) return;
    var add = e.target.closest(".sw-ex-add");
    var row = e.target.closest(".sw-ex-row");
    if (add) send(list, "swAdd", add.dataset.id);
    else if (row) send(list, "swOpen", row.dataset.id);
  }

  document.addEventListener("click", handle);
  document.addEventListener("keydown", function (e) {
    if (e.key === "Enter" && e.target.classList.contains("sw-ex-row")) handle(e);
  });
})();
