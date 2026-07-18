class BookLoan {
    [BookCopy] $Copy
    [MemberAccount] $Member
    [datetime] $LoanDate
    [datetime] $DueDate

    BookLoan([BookCopy]$Copy, [MemberAccount]$Member, [DueDatePolicy]$Policy) {
        $this.Copy = $Copy
        $this.Member = $Member
        $this.LoanDate = Get-Date
        $this.DueDate = $this.LoanDate.AddDays($Policy.StandardLoanDays)
    }
}
