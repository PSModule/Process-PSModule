class DueDatePolicy {
    [int] $StandardLoanDays
    [int] $GraceDays

    DueDatePolicy([int]$StandardLoanDays, [int]$GraceDays) {
        $this.StandardLoanDays = $StandardLoanDays
        $this.GraceDays = $GraceDays
    }
}
