class BookInventory {
    [string] $Name
    [BookCopy[]] $Copies
    [ZCatalog] $Catalog

    BookInventory([string]$Name, [ZCatalog]$Catalog) {
        $this.Name = $Name
        $this.Catalog = $Catalog
        $this.Copies = @()
    }
}
