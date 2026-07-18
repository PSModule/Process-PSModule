class ShelfLocation {
    [string] $BranchCode
    [string] $Section
    [string] $Shelf

    ShelfLocation([string]$BranchCode, [string]$Section, [string]$Shelf) {
        $this.BranchCode = $BranchCode
        $this.Section = $Section
        $this.Shelf = $Shelf
    }
}
