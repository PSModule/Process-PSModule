Class PSModule {
    $Name
    $Version
    $Functions

    PSModule ([string] $Name, [string] $Version, [hashtable] $Functions) {
        $this.Name = $Name
        $this.Version = $Version
        $this.Functions = $Functions
    }
}
