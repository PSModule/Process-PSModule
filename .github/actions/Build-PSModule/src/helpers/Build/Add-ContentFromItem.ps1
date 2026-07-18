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
        [string] $RootPath,

        # Whether the folder should be loaded using dependency ordering (class/enum aware).
        [Parameter()]
        [switch] $DependencyAware
    )
    $separators = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    $relativeFolderPath = [System.IO.Path]::GetRelativePath($RootPath, $Path)
    $relativeFolderPath = $relativeFolderPath.Split($separators, [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { "[$_]" }
    $relativeFolderPath = $relativeFolderPath -join ' - '

    Add-Content -Path $RootModuleFilePath -Force -Value @"
#region    $relativeFolderPath
Write-Debug "[`$scriptName] - $relativeFolderPath - Processing folder"
"@

    if ($DependencyAware) {
        $files = $Path | Get-ChildItem -Recurse -File -Force -Filter '*.ps1' | Sort-Object -Property FullName
        $files = Get-DependencyOrderedScriptFile -Files $files
    } else {
        $files = $Path | Get-ChildItem -File -Force -Filter '*.ps1' | Sort-Object -Property FullName
    }

    foreach ($file in $files) {
        $relativeFilePath = [System.IO.Path]::GetRelativePath($RootPath, $file.FullName)
        $relativeFilePath = [System.IO.Path]::ChangeExtension($relativeFilePath, $null).TrimEnd('.')
        $relativeFilePath = $relativeFilePath.Split($separators, [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { "[$_]" }
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

    if (-not $DependencyAware) {
        $subFolders = $Path | Get-ChildItem -Directory -Force | Sort-Object -Property Name
        foreach ($subFolder in $subFolders) {
            Add-ContentFromItem -Path $subFolder.FullName -RootModuleFilePath $RootModuleFilePath -RootPath $RootPath
        }
    }
    Add-Content -Path $RootModuleFilePath -Force -Value @"
Write-Debug "[`$scriptName] - $relativeFolderPath - Done"
#endregion $relativeFolderPath
"@
}
