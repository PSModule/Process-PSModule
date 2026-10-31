/* global document$, Tablesort */
document$.subscribe(function () {
  var tables = document.querySelectorAll("article table:not([class])");
  tables.forEach(function (table) {
    // If table doesn't have a thead, create one from the first row
    if (!table.querySelector("thead")) {
      var firstRow = table.querySelector("tr");
      if (firstRow) {
        var thead = document.createElement("thead");
        thead.appendChild(firstRow);
        table.insertBefore(thead, table.firstChild);
      }
    }
    new Tablesort(table);

    // Tablesort binds clicks to sortable headers. Make those cells focusable
    // before adding Enter/Space activation. A synthesized thead may contain td.
    table.querySelectorAll("thead th, thead td").forEach(function (header) {
      if (
        header.getAttribute("role") !== "columnheader" ||
        header.getAttribute("data-sort-method") === "none"
      ) {
        return;
      }
      header.tabIndex = 0;
      header.addEventListener("keydown", function (event) {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          header.click();
        }
      });
    });
  });
});
