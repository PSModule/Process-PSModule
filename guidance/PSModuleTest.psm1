[Cmdletbinding()]
param()

Write-Verbose 'Importing subcomponents'
$Folders = 'init', 'classes', 'private', 'public'
# Import everything in these folders
Foreach ($Folder in $Folders) {
    $Root = Join-Path -Path $PSScriptRoot -ChildPath $Folder
    Write-Verbose "Processing folder: $Root"
    if (Test-Path -Path $Root) {
        Write-Verbose "Getting all files in $Root"
        $Files = $null
        $Files = Get-ChildItem -Path $Root -Include '*.ps1', '*.psm1' -Recurse
        # dot source each file
        foreach ($File in $Files) {
            Write-Verbose "Importing $($File)"
            Import-Module $File
            Write-Verbose "Importing $($File): Done"
        }
    }
}

. "$PSScriptRoot\finally.ps1"

# Define the types to export with type accelerators.
$ExportableTypes = @(
    [Book]
    [BookList]
)

# Get the internal TypeAccelerators class to use its static methods.
$TypeAcceleratorsClass = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
# Ensure none of the types would clobber an existing type accelerator.
# If a type accelerator with the same name exists, throw an exception.
$ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
foreach ($Type in $ExportableTypes) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        $Message = @(
            "Unable to register type accelerator '$($Type.FullName)'"
            'Accelerator already exists.'
        ) -join ' - '

        throw [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($Message),
            'TypeAcceleratorAlreadyExists',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $Type.FullName
        )
    }
}
# Add type accelerators for every exportable type.
foreach ($Type in $ExportableTypes) {
    $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach ($Type in $ExportableTypes) {
        $TypeAcceleratorsClass::Remove($Type.FullName)
    }
}.GetNewClosure()

$Param = @{
    Function = (Get-ChildItem -Path "$PSScriptRoot\public" -Include '*.ps1' -Recurse).BaseName
    Variable = '*'
    Cmdlet   = '*'
    Alias    = '*'
}

Write-Verbose 'Exporting module members'

Export-ModuleMember @Param
