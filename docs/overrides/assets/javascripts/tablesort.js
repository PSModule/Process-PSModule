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
  });
});
