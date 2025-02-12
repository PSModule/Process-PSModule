#Requires -Modules @{ ModuleName = 'GitHub'; ModuleVersion = '0.13.2' }
#Requires -Modules @{ ModuleName = 'platyPS'; ModuleVersion = '0.14.2' }
#Requires -Modules @{ ModuleName = 'Utilities'; ModuleVersion = '0.3.0' }

function Build-PSModuleDocumentation {
    <#
        .SYNOPSIS
        Compiles the module documentation.

        .DESCRIPTION
        This function will compile the module documentation.
        It will generate the markdown files for the module help and copy them to the output folder.

        .EXAMPLE
        Build-PSModuleDocumentation -ModuleOutputFolder 'C:\MyModule\src\MyModule' -DocsOutputFolder 'C:\MyModule\build\MyModule'
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
    )]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleSourceFolder,

        # Folder where the documentation for the modules should be outputted. 'outputs/docs/MyModule'
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $DocsOutputFolder
    )

    LogGroup 'Build docs - Generate markdown help' {
        $ModuleName | Remove-Module -Force
        Import-Module -Name $ModuleName -Force -RequiredVersion '999.0.0'
        Write-Host ($ModuleName | Get-Module)
        $null = New-MarkdownHelp -Module $ModuleName -OutputFolder $DocsOutputFolder -Force -Verbose
    }

    LogGroup 'Build docs - Fix markdown code blocks' {
        Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
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
    }

    LogGroup 'Build docs - Fix markdown escape characters' {
        Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
            $content = Get-Content -Path $_.FullName -Raw
            $content = $content -replace '\\`', '`'
            $content = $content -replace '\\\[', '['
            $content = $content -replace '\\\]', ']'
            $content = $content -replace '\\\<', '<'
            $content = $content -replace '\\\>', '>'
            $content = $content -replace '\\\\', '\'
            $content | Set-Content -Path $_.FullName
        }
    }

    LogGroup 'Build docs - Structure markdown files to match source files' {
        $PublicFunctionsFolder = Join-Path $ModuleSourceFolder.FullName 'functions\public' | Get-Item
        Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
            $file = $_
            Write-Host "Processing:        $file"

            # find the source code file that matches the markdown file
            $scriptPath = Get-ChildItem -Path $PublicFunctionsFolder -Recurse -Force | Where-Object { $_.Name -eq ($file.BaseName + '.ps1') }
            Write-Host "Found script path: $scriptPath"
            $docsFilePath = ($scriptPath.FullName).Replace($PublicFunctionsFolder.FullName, $DocsOutputFolder.FullName).Replace('.ps1', '.md')
            Write-Host "Doc file path:     $docsFilePath"
            $docsFolderPath = Split-Path -Path $docsFilePath -Parent
            New-Item -Path $docsFolderPath -ItemType Directory -Force
            Move-Item -Path $file.FullName -Destination $docsFilePath -Force
        }
        # Get the MD files that are in the public functions folder and move them to the same place in the docs folder
        Get-ChildItem -Path $PublicFunctionsFolder -Recurse -Force -Include '*.md' | ForEach-Object {
            $file = $_
            Write-Host "Processing:        $file"
            $docsFilePath = ($file.FullName).Replace($PublicFunctionsFolder.FullName, $DocsOutputFolder.FullName)
            Write-Host "Doc file path:     $docsFilePath"
            $docsFolderPath = Split-Path -Path $docsFilePath -Parent
            New-Item -Path $docsFolderPath -ItemType Directory -Force
            Move-Item -Path $file.FullName -Destination $docsFilePath -Force
        }
    }

    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $fileName = $_.Name
        $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
        LogGroup " - [$fileName] - [$hash]" {
            Show-FileContent -Path $_
        }
    }
}
