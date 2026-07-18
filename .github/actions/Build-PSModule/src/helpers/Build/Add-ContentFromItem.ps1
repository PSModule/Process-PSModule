function Get-DependencyOrderedScriptFiles {
    [OutputType([System.IO.FileInfo[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]] $Files
    )

    $sortedFiles = $Files | Sort-Object -Property FullName
    if ($sortedFiles.Count -le 1) {
        return $sortedFiles
    }

    $metadataByPath = @{}
    $typeToPath = @{}
    $duplicateTypes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($file in $sortedFiles) {
        $content = Get-Content -Path $file.FullName -Raw
        $declaredTypes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        [Regex]::Matches($content, '(?im)^\s*(class|enum)\s+([^\s:{]+)') | ForEach-Object {
            [void] $declaredTypes.Add($_.Groups[2].Value)
        }

        $metadataByPath[$file.FullName] = [pscustomobject]@{
            File          = $file
            Content       = $content
            DeclaredTypes = $declaredTypes
        }

        foreach ($typeName in $declaredTypes) {
            if ($typeToPath.ContainsKey($typeName)) {
                [void]$duplicateTypes.Add($typeName)
                continue
            }

            $typeToPath[$typeName] = $file.FullName
        }
    }

    $dependenciesByPath = @{}
    $dependentsByPath = @{}
    foreach ($file in $sortedFiles) {
        $dependenciesByPath[$file.FullName] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $dependentsByPath[$file.FullName] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    foreach ($metadata in $metadataByPath.Values) {
        foreach ($typeName in $typeToPath.Keys) {
            if ($duplicateTypes.Contains($typeName)) {
                continue
            }

            if ($metadata.DeclaredTypes.Contains($typeName)) {
                continue
            }

            $typePattern = "(?<![\w\.])\[$([Regex]::Escape($typeName))\](?![\w\.])"
            if ([Regex]::IsMatch($metadata.Content, $typePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                $dependencyPath = $typeToPath[$typeName]
                [void]$dependenciesByPath[$metadata.File.FullName].Add($dependencyPath)
                [void]$dependentsByPath[$dependencyPath].Add($metadata.File.FullName)
            }
        }
    }

    $remainingPaths = @($sortedFiles.FullName)
    $ready = @(
        $remainingPaths |
        Where-Object { $dependenciesByPath[$_].Count -eq 0 } |
        Sort-Object
    )
    $orderedPaths = [System.Collections.Generic.List[string]]::new()

    while ($ready.Count -gt 0) {
        $currentPath = $ready[0]
        $ready = @($ready | Select-Object -Skip 1)
        $orderedPaths.Add($currentPath)
        $remainingPaths = @($remainingPaths | Where-Object { $_ -ne $currentPath })

        $dependents = @($dependentsByPath[$currentPath] | Sort-Object)
        foreach ($dependentPath in $dependents) {
            $null = $dependenciesByPath[$dependentPath].Remove($currentPath)
            if ($dependenciesByPath[$dependentPath].Count -eq 0) {
                $ready = @($ready + $dependentPath | Sort-Object -Unique)
            }
        }
    }

    if ($orderedPaths.Count -lt $sortedFiles.Count) {
        Write-Warning "Detected cyclical or unresolved class/enum dependencies. Falling back to lexical order for remaining files in [$($sortedFiles[0].DirectoryName)]."
        $remainingPaths | Sort-Object | ForEach-Object {
            $orderedPaths.Add($_)
        }
    }

    return @($orderedPaths | ForEach-Object { $metadataByPath[$_].File })
}

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
        $files = Get-DependencyOrderedScriptFiles -Files $files
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
