class AuthorIndex {
    [string] $Name
    [AuthorProfile[]] $Authors
    [ZCatalog] $Catalog

    AuthorIndex([string]$Name, [ZCatalog]$Catalog) {
        $this.Name = $Name
        $this.Catalog = $Catalog
        $this.Authors = @()
    }
}
