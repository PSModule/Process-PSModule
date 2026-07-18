class LibraryReport {
    [AuthorIndex] $Authors
    [ActiveLoanRegister] $ActiveLoans
    [BookInventory] $Inventory
    [ZCatalog] $Catalog

    LibraryReport(
        [AuthorIndex]$Authors,
        [ActiveLoanRegister]$ActiveLoans,
        [BookInventory]$Inventory,
        [ZCatalog]$Catalog
    ) {
        $this.Authors = $Authors
        $this.ActiveLoans = $ActiveLoans
        $this.Inventory = $Inventory
        $this.Catalog = $Catalog
    }
}
