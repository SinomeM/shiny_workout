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

  // On narrow screens the catalog is hidden and opens over the editor.
  function showCatalog(on) {
    document.body.classList.toggle("sw-catalog-shown", on);
    // Focus the search only with a mouse: on a phone it would pop the keyboard up at once.
    if (on && window.matchMedia("(hover: hover)").matches) {
      var search = document.querySelector(".sw-catalog input[type=text]");
      if (search) search.focus();
    }
  }
  document.addEventListener("click", function (e) {
    var t = e.target.closest && e.target.closest("[data-sw-catalog]");
    if (t) showCatalog(t.dataset.swCatalog === "open");
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && document.body.classList.contains("sw-catalog-shown") &&
        !document.querySelector(".modal.show")) showCatalog(false);
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Enter" && e.target.classList.contains("sw-ex-row")) handle(e);
  });
})();
