class BranchLibrary {
    [string] $Code
    [string] $Name
    [OpeningHours] $Hours

    BranchLibrary([string]$Code, [string]$Name, [OpeningHours]$Hours) {
        $this.Code = $Code
        $this.Name = $Name
        $this.Hours = $Hours
    }
}
