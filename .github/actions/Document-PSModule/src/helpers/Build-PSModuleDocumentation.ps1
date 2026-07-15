function Build-PSModuleDocumentation {
    <#
        .SYNOPSIS
        Builds a module.

        .DESCRIPTION
        Builds a module.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Want to just write to the console, not the pipeline.'
    )]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Path to the folder where the modules are located.
        [Parameter(Mandatory)]
        [string] $ModuleSourceFolderPath,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [string] $ModulesOutputFolderPath,

        # Path to the folder where the documentation is outputted.
        [Parameter(Mandatory)]
        [string] $DocsOutputFolderPath,

        # Show GitHub Step Summary even when all commands succeed.
        [Parameter()]
        [bool] $ShowSummaryOnSuccess = $false
    )

    Write-Host "::group::Documenting module [$ModuleName]"
    [pscustomobject]@{
        ModuleName              = $ModuleName
        ModuleSourceFolderPath  = $ModuleSourceFolderPath
        ModulesOutputFolderPath = $ModulesOutputFolderPath
        DocsOutputFolderPath    = $DocsOutputFolderPath
    } | Format-List | Out-String

    if (-not (Test-Path -Path $ModuleSourceFolderPath)) {
        Write-Error "Source folder not found at [$ModuleSourceFolderPath]"
        exit 1
    }
    $moduleSourceFolder = Get-Item -Path $ModuleSourceFolderPath
    $moduleOutputFolder = New-Item -Path $ModulesOutputFolderPath -Name $ModuleName -ItemType Directory -Force
    $docsOutputFolder = New-Item -Path $DocsOutputFolderPath -ItemType Directory -Force

    Write-Host '::group::Build docs - Generate markdown help - Raw'
    Install-PSModule -Path $ModuleOutputFolder
    $moduleInfo = Import-Module -Name $ModuleName -PassThru -Verbose:$false -Force

    # Get all exported commands from the module
    $commands = $moduleInfo.ExportedCommands.Values | Where-Object { $_.CommandType -ne 'Alias' }

    Write-Host "::group::Build docs - Generating markdown help files for $($commands.Count) commands in [$docsOutputFolder]"
    $commandResults = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($command in $commands) {
        try {
            Write-Host "$($command.Name)" -NoNewline
            $params = @{
                CommandInfo    = $command
                OutputFolder   = $docsOutputFolder
                Encoding       = 'utf8'
                ProgressAction = 'SilentlyContinue'
                ErrorAction    = 'Stop'
                Force          = $true
            }
            $null = New-MarkdownCommandHelp @params
            Write-Host " - $($PSStyle.Foreground.Green)✓$($PSStyle.Reset)"
            $commandResults.Add([PSCustomObject]@{
                    CommandName = $command.Name
                    Status      = 'Success'
                    Error       = $null
                    ErrorString = $null
                })
        } catch {
            Write-Host " - $($PSStyle.Foreground.Red)✗$($PSStyle.Reset)"
            $commandResults.Add([PSCustomObject]@{
                    CommandName = $command.Name
                    Status      = 'Failed'
                    Error       = $_
                    ErrorString = $_.ToString()
                })
            Write-Warning "Failed to generate markdown help for $($command.Name): $_"
        }
    }
    Write-Host '::endgroup::'

    $failedCommands = $commandResults | Where-Object { $_.Status -eq 'Failed' }
    $successfulCommands = $commandResults | Where-Object { $_.Status -eq 'Success' }
    $hasFailures = $failedCommands.Count -gt 0
    $shouldShowSummary = $hasFailures -or $ShowSummaryOnSuccess

    # Generate summary if ShowSummaryOnSuccess is enabled
    if ($shouldShowSummary) {
        $statusIcon = $hasFailures ? '❌' : '✅'
        $statusText = $hasFailures ? 'Failed' : 'Succeeded'
        Write-Host "::group::Build docs - Documentation generation summary $statusIcon"

        $successCount = $successfulCommands.Count
        $failureCount = $failedCommands.Count

        $summaryContent = @"
# $statusIcon Documentation Build $($statusText.ToLower())

| Success | Failure |
|---------|---------|
| $successCount | $failureCount |

"@

        if ($failedCommands) {
            $summaryContent += @"

<details><summary>Failed</summary>

<p>

$(($failedCommands | ForEach-Object { "- ``$($_.CommandName)`` `n" }) -join '')

</p>

</details>

"@
        }

        if ($successfulCommands) {
            $summaryContent += @"

<details><summary>Succeeded</summary>

<p>

$(($successfulCommands | ForEach-Object { "- ``$($_.CommandName)`` `n" }) -join '')

</p>

</details>

"@
        }


        $summaryContent | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
        Write-Host "$summaryContent"
        Write-Host '::endgroup::'
    }

    # Fail the task if there were any failures (independent of summary display)
    if ($hasFailures) {
        Write-Error "Documentation generation failed for $($failedCommands.Count) command(s). See above for details."
        exit 1
    }

    Write-Host '::group::Build docs - Generated files'
    Get-ChildItem -Path $docsOutputFolder -Recurse | Select-Object -ExpandProperty FullName

    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | Sort-Object FullName | ForEach-Object {
        $relPath = [System.IO.Path]::GetRelativePath($docsOutputFolder, $_.FullName)
        Write-Host "::group:: - [$relPath]"
        Show-FileContent -Path $_
    }

    Write-Host '::group::Build docs - Fix markdown code blocks'
    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $content = Get-Content -Path $_.FullName
        $fixedOpening = $false
        $newContent = @()
        foreach ($line in $content) {
            if ($line -match '^```$' -and -not $fixedOpening) {
                $line = $line -replace '^```$', '```powershell'
                $fixedOpening = $true
            } elseif ($line -match '^```.+$') {
                $fixedOpening = $true
            } elseif ($line -match '^```$') {
                $fixedOpening = $false
            }
            $newContent += $line
        }
        $newContent | Set-Content -Path $_.FullName
    }

    Write-Host '::group::Build docs - Fix markdown escape characters'
    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $content = Get-Content -Path $_.FullName -Raw
        $content = $content -replace '\\`', '`'
        $content = $content -replace '\\\[', '['
        $content = $content -replace '\\\]', ']'
        $content = $content -replace '\\\<', '<'
        $content = $content -replace '\\\>', '>'
        $content = $content -replace '\\\\', '\'
        $content | Set-Content -Path $_.FullName
    }

    Write-Host '::group::Build docs - Structure markdown files to match source files'
    $PublicFunctionsFolder = Join-Path $ModuleSourceFolder.FullName 'functions\public' | Get-Item
    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $file = $_
        $relPath = [System.IO.Path]::GetRelativePath($docsOutputFolder, $file.FullName)
        Write-Host " - $relPath"
        Write-Host "   Path:     $file"

        # find the source code file that matches the markdown file
        $scriptPath = Get-ChildItem -Path $PublicFunctionsFolder -Recurse -Force | Where-Object { $_.Name -eq ($file.BaseName + '.ps1') }
        Write-Host "   PS1 path: $scriptPath"
        $docsFilePath = ($scriptPath.FullName).Replace($PublicFunctionsFolder.FullName, $docsOutputFolder).Replace('.ps1', '.md')
        Write-Host "   MD path:  $docsFilePath"
        $docsFolderPath = Split-Path -Path $docsFilePath -Parent
        $null = New-Item -Path $docsFolderPath -ItemType Directory -Force
        Move-Item -Path $file.FullName -Destination $docsFilePath -Force
    }

    Write-Host '::group::Build docs - Fix frontmatter title'
    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $content = Get-Content -Path $_.FullName -Raw
        # Replace 'title:' with 'ms.title:' in frontmatter only (between --- markers)
        $content = $content -replace '(?s)^(---.*?)title:(.*?---)', '$1ms.title:$2'
        $content | Set-Content -Path $_.FullName
    }

    Write-Host '::group::Build docs - Move markdown files from public functions folder to docs output folder'
    # Enumerate the public markdown once and reuse it (no second tree walk).
    $publicMarkdownFiles = @(Get-ChildItem -Path $PublicFunctionsFolder -Recurse -Force -File -Include '*.md')

    # Folders that provide an explicit index page. Detected case-insensitively because the runner
    # filesystem is case-sensitive. Two index pages that differ only by case (index.md and
    # Index.md) are ambiguous, so fail fast instead of silently overwriting one.
    $explicitIndexFolders = [System.Collections.Generic.HashSet[string]]::new()
    $indexGroups = $publicMarkdownFiles | Where-Object { $_.Name -ieq 'index.md' } | Group-Object { $_.Directory.FullName }
    foreach ($group in $indexGroups) {
        if ($group.Count -gt 1) {
            $names = ($group.Group.Name | Sort-Object) -join ', '
            throw "Ambiguous section index in '$($group.Name)': multiple index pages ($names). Keep only one index.md."
        }
        [void]$explicitIndexFolders.Add($group.Name)
    }

    foreach ($file in $publicMarkdownFiles) {
        $relPath = [System.IO.Path]::GetRelativePath($PublicFunctionsFolder.FullName, $file.FullName)
        Write-Host " - $relPath"
        Write-Host "   Path:     $file"

        $docsFilePath = ($file.FullName).Replace($PublicFunctionsFolder.FullName, $docsOutputFolder)

        # A group's overview page becomes the section landing page (index.md) so the navigation
        # shows it when the group is selected, instead of a page nested under the group. Authors
        # can either name it after the folder (e.g. Auth/Auth.md) or provide Auth/index.md directly.
        $parentFolder = Split-Path -Path $file.FullName -Parent
        $parentFolderName = Split-Path -Path $parentFolder -Leaf
        if ($file.Name -ieq 'index.md') {
            # Normalize any casing (Index.md/INDEX.md) to index.md so it is treated as the
            # section index on case-sensitive filesystems.
            $docsFilePath = Join-Path -Path (Split-Path -Path $docsFilePath -Parent) -ChildPath 'index.md'
            Write-Host '   Section index page detected - publishing as index.md'
        } elseif ($file.BaseName -eq $parentFolderName) {
            if ($explicitIndexFolders.Contains($parentFolder)) {
                Write-Warning "Ignoring group overview '$relPath' as the section index; folder already has an explicit index.md."
            } else {
                $docsFilePath = Join-Path -Path (Split-Path -Path $docsFilePath -Parent) -ChildPath 'index.md'
                Write-Host '   Group overview page detected - publishing as section index (index.md)'
            }
        }

        Write-Host "   MD path:  $docsFilePath"
        $docsFolderPath = Split-Path -Path $docsFilePath -Parent
        $null = New-Item -Path $docsFolderPath -ItemType Directory -Force
        Move-Item -Path $file.FullName -Destination $docsFilePath -Force
    }
    Write-Host '::endgroup::'

    Write-Host '────────────────────────────────────────────────────────────────────────────────'
    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | Sort-Object FullName | ForEach-Object {
        $relPath = [System.IO.Path]::GetRelativePath($docsOutputFolder, $_.FullName)
        Write-Host "::group:: - [$relPath]"
        Show-FileContent -Path $_
    }
}
