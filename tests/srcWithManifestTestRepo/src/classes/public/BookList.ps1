class BookList {
    static [System.Collections.Generic.List[Book]] $Books

    static [void] Initialize() { [BookList]::Initialize($false) }
    static [bool] Initialize([bool]$force) {
        if ([BookList]::Books.Count -gt 0 -and -not $force) {
            return $false
        }

        [BookList]::Books = [System.Collections.Generic.List[Book]]::new()

        return $true
    }

    static [void] Validate([Book]$Book) {
        $Prefix = @(
            'Book validation failed: Book must be defined with the Title,'
            'Author, and PublishDate properties, but'
        ) -join ' '
        if ($null -eq $Book) { throw "$Prefix was null" }
        if ([string]::IsNullOrEmpty($Book.Title)) { throw "$Prefix Title wasn't defined" }
        if ([string]::IsNullOrEmpty($Book.Author)) { throw "$Prefix Author wasn't defined" }
        if ([datetime]::MinValue -eq $Book.PublishDate) { throw "$Prefix PublishDate wasn't defined" }
    }

    static [void] Add([Book]$Book) {
        [BookList]::Initialize()
        [BookList]::Validate($Book)
        if ([BookList]::Books.Contains($Book)) { throw "Book '$Book' already in list" }

        $findPredicate = {
            param([Book]$b)

            $b.Title -eq $Book.Title -and
            $b.Author -eq $Book.Author -and
            $b.PublishDate -eq $Book.PublishDate
        }.GetNewClosure()
        if ([BookList]::Books.Find($findPredicate)) { throw "Book '$Book' already in list" }

        [BookList]::Books.Add($Book)
    }

    static [void] Clear() {
        [BookList]::Initialize()
        [BookList]::Books.Clear()
    }

    static [Book] Find([scriptblock]$Predicate) {
        [BookList]::Initialize()
        return [BookList]::Books.Find($Predicate)
    }

    static [Book[]] FindAll([scriptblock]$Predicate) {
        [BookList]::Initialize()
        return [BookList]::Books.FindAll($Predicate)
    }
}
