class ActiveLoanRegister {
    [System.Collections.Generic.List[BookLoan]] $Loans

    ActiveLoanRegister() {
        $this.Loans = [System.Collections.Generic.List[BookLoan]]::new()
    }

    [void] AddLoan([BookLoan]$Loan) {
        $this.Loans.Add($Loan)
    }
}
