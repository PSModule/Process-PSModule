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

            $typePattern = "(?<![\w\.])\[$([Regex]::Escape($typeName))(?:\[\])?\](?![\w\.])"
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
        $remainingNames = ($remainingPaths | ForEach-Object { [System.IO.Path]::GetFileName($_) }) -join ', '
        Write-Warning "Cyclical class/enum dependencies detected in [$($sortedFiles[0].DirectoryName)]. Falling back to lexical order for unresolved files: $remainingNames"
        $remainingPaths | Sort-Object | ForEach-Object {
            $orderedPaths.Add($_)
        }
    }

    return @($orderedPaths | ForEach-Object { $metadataByPath[$_].File })
}
