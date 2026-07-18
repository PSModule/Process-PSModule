class ZCatalog {
    [string] $CatalogName
    [CatalogSection[]] $Sections
    [BranchLibrary[]] $Branches

    ZCatalog([string]$CatalogName, [CatalogSection[]]$Sections, [BranchLibrary[]]$Branches) {
        $this.CatalogName = $CatalogName
        $this.Sections = $Sections
        $this.Branches = $Branches
    }
}
