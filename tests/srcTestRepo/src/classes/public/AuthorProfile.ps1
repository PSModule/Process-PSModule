class AuthorProfile {
    [string] $Name
    [Book[]] $PublishedBooks

    AuthorProfile([string]$Name, [Book[]]$PublishedBooks) {
        $this.Name = $Name
        $this.PublishedBooks = $PublishedBooks
    }
}
