function Add-ContentFromItem {
    <#
        .SYNOPSIS
        Add the content of a folder or file to the root module file.

        .DESCRIPTION
        This function will add the content of a folder or file to the root module file.

        .EXAMPLE
        Add-ContentFromItem -Path 'C:\MyModule\src\MyModule' -RootModuleFilePath 'C:\MyModule\src\MyModule.psm1' -RootPath 'C:\MyModule\src'
    #>
    param(
        # The path to the folder or file to process.
        [Parameter(Mandatory)]
        [string] $Path,

        # The path to the root module file.
        [Parameter(Mandatory)]
        [string] $RootModuleFilePath,

        # The root path of the module.
        [Parameter(Mandatory)]
        [string] $RootPath
    )
    # Get the path separator for the current OS
    $pathSeparator = [System.IO.Path]::DirectorySeparatorChar

    $relativeFolderPath = $Path -replace $RootPath, ''
    $relativeFolderPath = $relativeFolderPath -replace $file.Extension, ''
    $relativeFolderPath = $relativeFolderPath.TrimStart($pathSeparator)
    $relativeFolderPath = $relativeFolderPath -split $pathSeparator | ForEach-Object { "[$_]" }
    $relativeFolderPath = $relativeFolderPath -join ' - '

    Add-Content -Path $RootModuleFilePath -Force -Value @"
#region    $relativeFolderPath
Write-Debug "[`$scriptName] - $relativeFolderPath - Processing folder"
"@

    $files = $Path | Get-ChildItem -File -Force -Filter '*.ps1' | Sort-Object -Property FullName
    foreach ($file in $files) {
        $relativeFilePath = $file.FullName -replace $RootPath, ''
        $relativeFilePath = $relativeFilePath -replace $file.Extension, ''
        $relativeFilePath = $relativeFilePath.TrimStart($pathSeparator)
        $relativeFilePath = $relativeFilePath -split $pathSeparator | ForEach-Object { "[$_]" }
        $relativeFilePath = $relativeFilePath -join ' - '

        Add-Content -Path $RootModuleFilePath -Force -Value @"
#region    $relativeFilePath
Write-Debug "[`$scriptName] - $relativeFilePath - Importing"
"@
        Get-Content -Path $file.FullName | Add-Content -Path $RootModuleFilePath -Force
        Add-Content -Path $RootModuleFilePath -Value @"
Write-Debug "[`$scriptName] - $relativeFilePath - Done"
#endregion $relativeFilePath
"@
    }

    $subFolders = $Path | Get-ChildItem -Directory -Force | Sort-Object -Property Name
    foreach ($subFolder in $subFolders) {
        Add-ContentFromItem -Path $subFolder.FullName -RootModuleFilePath $RootModuleFilePath -RootPath $RootPath
    }
    Add-Content -Path $RootModuleFilePath -Force -Value @"
Write-Debug "[`$scriptName] - $relativeFolderPath - Done"
#endregion $relativeFolderPath
"@
}
