[CmdletBinding()]
param()

enum ModuleLifecycle {
    Loaded
    Removed
}

#region Class exporter
$TypeAcceleratorsClass = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
$ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
$ExportableEnums = @(
    [ModuleLifecycle]
)
$ExportableEnums | ForEach-Object { Write-Verbose "Exporting enum '$($_.FullName)'." }
foreach ($Type in $ExportableEnums) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        Write-Verbose "Enum already exists [$($Type.FullName)]. Skipping."
    } else {
        Write-Verbose "Importing enum '$Type'."
        $TypeAcceleratorsClass::Add($Type.FullName, $Type)
    }
}
$ExportableClasses = @(
)
$ExportableClasses | ForEach-Object { Write-Verbose "Exporting class '$($_.FullName)'." }
foreach ($Type in $ExportableClasses) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        Write-Verbose "Class already exists [$($Type.FullName)]. Skipping."
    } else {
        Write-Verbose "Importing class '$Type'."
        $TypeAcceleratorsClass::Add($Type.FullName, $Type)
    }
}

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    $CurrentTypeAccelerators = $TypeAcceleratorsClass::Get
    foreach ($Type in ($ExportableEnums + $ExportableClasses)) {
        if ($CurrentTypeAccelerators[$Type.FullName] -eq $Type) {
            $null = $TypeAcceleratorsClass::Remove($Type.FullName)
        }
    }
}.GetNewClosure()
#endregion Class exporter

Export-ModuleMember -Function @() -Alias @() -Variable @()