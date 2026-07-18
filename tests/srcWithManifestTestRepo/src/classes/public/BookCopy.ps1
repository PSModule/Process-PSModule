class BookCopy {
    [string] $InventoryId
    [Book] $Book
    [ShelfLocation] $Location

    BookCopy([string]$InventoryId, [Book]$Book, [ShelfLocation]$Location) {
        $this.InventoryId = $InventoryId
        $this.Book = $Book
        $this.Location = $Location
    }
}
