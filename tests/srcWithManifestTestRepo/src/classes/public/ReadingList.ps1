class ReadingList {
    [Book[]] $Books

    ReadingList([Book[]]$Books) {
        $this.Books = $Books
    }
}
