class CatalogSection {
    [string] $Name
    [Book[]] $Books

    CatalogSection([string]$Name, [Book[]]$Books) {
        $this.Name = $Name
        $this.Books = $Books
    }
}
