function Get-PSModuleFunctionsToExport {
    <#
        .SYNOPSIS
        Get the functions and filters to export from the module source code.

        .DESCRIPTION
        Get-PSModuleFunctionsToExport reads public source files to identify the functions and filters to export.

        .EXAMPLE
        Get-PSModuleFunctionsToExport -SourceFolderPath 'C:\MyModule\src\MyModule'
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Scope = 'Function', Justification = 'Want to just write to the console, not the pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidLongLines', '', Scope = 'Function', Justification = 'Contains long links.')]
    [OutputType([array])]
    param(
        # Path to the module source folder.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath
    )

    $manifestPropertyName = 'FunctionsToExport'

    Write-Host "[$manifestPropertyName]"
    Write-Host "[$manifestPropertyName] - Checking path for functions and filters"

    $publicFolderPath = Join-Path -Path $SourceFolderPath -ChildPath 'functions/public'
    if (-not (Test-Path -Path $publicFolderPath -PathType Container)) {
        Write-Host "[$manifestPropertyName] - [Folder not found] - [$publicFolderPath]"
        return $functionsToExport
    }
    Write-Host "[$manifestPropertyName] - [$publicFolderPath]"
    $functionsToExport = [Collections.Generic.List[string]]::new()
    $scriptFiles = Get-ChildItem -Path $publicFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1'
    Write-Host "[$manifestPropertyName] - [$($scriptFiles.Count)]"
    foreach ($file in $scriptFiles) {
        $fileContent = Get-Content -Path $file.FullName -Raw
        $containsFunction = ($fileContent -match 'function ') -or ($fileContent -match 'filter ')
        Write-Host "[$manifestPropertyName] - [$($file.BaseName)] - [$containsFunction]"
        if ($containsFunction) {
            $functionsToExport.Add($file.BaseName)
        }
    }

    [array]$functionsToExport
}
