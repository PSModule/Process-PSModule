#Requires -Modules @{ ModuleName = 'GitHub'; ModuleVersion = '0.13.2' }
#Requires -Modules @{ ModuleName = 'Utilities'; ModuleVersion = '0.3.0' }

function Build-PSModuleManifest {
    <#
        .SYNOPSIS
        Compiles the module manifest.

        .DESCRIPTION
        This function will compile the module manifest.
        It will generate the module manifest file and copy it to the output folder.

        .EXAMPLE
        Build-PSModuleManifest -SourceFolderPath 'C:\MyModule\src\MyModule' -OutputFolderPath 'C:\MyModule\build\MyModule'
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidLongLines', '', Scope = 'Function',
        Justification = 'Easier to read the multi ternery operators in a single line.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
    )]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Folder where the built modules are outputted. 'outputs/modules/MyModule'
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )

    LogGroup 'Build manifest file' {
        $sourceManifestFilePath = Join-Path -Path $ModuleOutputFolder -ChildPath "$ModuleName.psd1"
        Write-Host "[SourceManifestFilePath] - [$sourceManifestFilePath]"
        if (-not (Test-Path -Path $sourceManifestFilePath)) {
            Write-Host "[SourceManifestFilePath] - [$sourceManifestFilePath] - Not found"
            $sourceManifestFilePath = Join-Path -Path $ModuleOutputFolder -ChildPath 'manifest.psd1'
        }
        if (-not (Test-Path -Path $sourceManifestFilePath)) {
            Write-Host "[SourceManifestFilePath] - [$sourceManifestFilePath] - Not found"
            $manifest = @{}
            Write-Host '[Manifest] - Loading empty manifest'
        } else {
            Write-Host "[SourceManifestFilePath] - [$sourceManifestFilePath] - Found"
            $manifest = Get-ModuleManifest -Path $sourceManifestFilePath -Verbose:$false
            Write-Host '[Manifest] - Loading from file'
            Remove-Item -Path $sourceManifestFilePath -Force -Verbose:$false
        }

        $rootModule = "$ModuleName.psm1"
        $manifest.RootModule = $rootModule
        Write-Host "[RootModule] - [$($manifest.RootModule)]"

        $manifest.ModuleVersion = '999.0.0'
        Write-Host "[ModuleVersion] - [$($manifest.ModuleVersion)]"

        $manifest.Author = $manifest.Keys -contains 'Author' ? ($manifest.Author | IsNotNullOrEmpty) ? $manifest.Author : $env:GITHUB_REPOSITORY_OWNER : $env:GITHUB_REPOSITORY_OWNER
        Write-Host "[Author] - [$($manifest.Author)]"

        $manifest.CompanyName = $manifest.Keys -contains 'CompanyName' ? ($manifest.CompanyName | IsNotNullOrEmpty) ? $manifest.CompanyName : $env:GITHUB_REPOSITORY_OWNER : $env:GITHUB_REPOSITORY_OWNER
        Write-Host "[CompanyName] - [$($manifest.CompanyName)]"

        $year = Get-Date -Format 'yyyy'
        $copyrightOwner = $manifest.CompanyName -eq $manifest.Author ? $manifest.Author : "$($manifest.Author) | $($manifest.CompanyName)"
        $copyright = "(c) $year $copyrightOwner. All rights reserved."
        $manifest.Copyright = $manifest.Keys -contains 'Copyright' ? -not [string]::IsNullOrEmpty($manifest.Copyright) ? $manifest.Copyright : $copyright : $copyright
        Write-Host "[Copyright] - [$($manifest.Copyright)]"

        $repoDescription = gh repo view --json description | ConvertFrom-Json | Select-Object -ExpandProperty description
        $manifest.Description = $manifest.Keys -contains 'Description' ? ($manifest.Description | IsNotNullOrEmpty) ? $manifest.Description : $repoDescription : $repoDescription
        Write-Host "[Description] - [$($manifest.Description)]"

        $manifest.PowerShellHostName = $manifest.Keys -contains 'PowerShellHostName' ? -not [string]::IsNullOrEmpty($manifest.PowerShellHostName) ? $manifest.PowerShellHostName : $null : $null
        Write-Host "[PowerShellHostName] - [$($manifest.PowerShellHostName)]"

        $manifest.PowerShellHostVersion = $manifest.Keys -contains 'PowerShellHostVersion' ? -not [string]::IsNullOrEmpty($manifest.PowerShellHostVersion) ? $manifest.PowerShellHostVersion : $null : $null
        Write-Host "[PowerShellHostVersion] - [$($manifest.PowerShellHostVersion)]"

        $manifest.DotNetFrameworkVersion = $manifest.Keys -contains 'DotNetFrameworkVersion' ? -not [string]::IsNullOrEmpty($manifest.DotNetFrameworkVersion) ? $manifest.DotNetFrameworkVersion : $null : $null
        Write-Host "[DotNetFrameworkVersion] - [$($manifest.DotNetFrameworkVersion)]"

        $manifest.ClrVersion = $manifest.Keys -contains 'ClrVersion' ? -not [string]::IsNullOrEmpty($manifest.ClrVersion) ? $manifest.ClrVersion : $null : $null
        Write-Host "[ClrVersion] - [$($manifest.ClrVersion)]"

        $manifest.ProcessorArchitecture = $manifest.Keys -contains 'ProcessorArchitecture' ? -not [string]::IsNullOrEmpty($manifest.ProcessorArchitecture) ? $manifest.ProcessorArchitecture : 'None' : 'None'
        Write-Host "[ProcessorArchitecture] - [$($manifest.ProcessorArchitecture)]"

        # Get the path separator for the current OS
        $pathSeparator = [System.IO.Path]::DirectorySeparatorChar

        Write-Host '[FileList]'
        $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

        # Get files on module root
        $ModuleOutputFolder | Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object -Property Name -NotLike '*.ps1' |
            ForEach-Object { $files.Add($_) }

        # Get files on module subfolders, excluding the following folders 'init', 'classes', 'public', 'private'
        $skipList = @('init', 'classes', 'functions', 'variables')
        $ModuleOutputFolder | Get-ChildItem -Directory | Where-Object { $_.Name -NotIn $skipList } |
            Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $files.Add($_) }

        # Get the relative file path and store it in the manifest
        $files = $files | Select-Object -ExpandProperty FullName | ForEach-Object { $_.Replace($ModuleOutputFolder, '').TrimStart($pathSeparator) }
        $manifest.FileList = $files.count -eq 0 ? @() : @($files)
        $manifest.FileList | ForEach-Object { Write-Host "[FileList] - [$_]" }

        $requiredAssembliesFolderPath = Join-Path $ModuleOutputFolder 'assemblies'
        $nestedModulesFolderPath = Join-Path $ModuleOutputFolder 'modules'

        Write-Host '[RequiredAssemblies]'
        $existingRequiredAssemblies = $manifest.RequiredAssemblies
        $requiredAssemblies = Get-ChildItem -Path $requiredAssembliesFolderPath -Recurse -File -ErrorAction SilentlyContinue -Filter '*.dll' |
            Select-Object -ExpandProperty FullName |
            ForEach-Object { $_.Replace($ModuleOutputFolder, '').TrimStart([System.IO.Path]::DirectorySeparatorChar) }
        $requiredAssemblies += Get-ChildItem -Path $nestedModulesFolderPath -Recurse -Depth 1 -File -ErrorAction SilentlyContinue -Filter '*.dll' |
            Select-Object -ExpandProperty FullName |
            ForEach-Object { $_.Replace($ModuleOutputFolder, '').TrimStart([System.IO.Path]::DirectorySeparatorChar) }
        $manifest.RequiredAssemblies = if ($existingRequiredAssemblies) { $existingRequiredAssemblies } elseif ($requiredAssemblies.Count -gt 0) { @($requiredAssemblies) } else { @() }
        $manifest.RequiredAssemblies | ForEach-Object { Write-Host "[RequiredAssemblies] - [$_]" }

        Write-Host '[NestedModules]'
        $existingNestedModules = $manifest.NestedModules
        $nestedModules = Get-ChildItem -Path $nestedModulesFolderPath -Recurse -Depth 1 -File -ErrorAction SilentlyContinue -Include '*.psm1', '*.ps1', '*.dll' |
            Select-Object -ExpandProperty FullName |
            ForEach-Object { $_.Replace($ModuleOutputFolder, '').TrimStart([System.IO.Path]::DirectorySeparatorChar) }
        $manifest.NestedModules = if ($existingNestedModules) { $existingNestedModules } elseif ($nestedModules.Count -gt 0) { @($nestedModules) } else { @() }
        $manifest.NestedModules | ForEach-Object { Write-Host "[NestedModules] - [$_]" }

        Write-Host '[ScriptsToProcess]'
        $existingScriptsToProcess = $manifest.ScriptsToProcess
        $allScriptsToProcess = @('scripts') | ForEach-Object {
            Write-Host "[ScriptsToProcess] - Processing [$_]"
            $scriptsFolderPath = Join-Path $ModuleOutputFolder $_
            Get-ChildItem -Path $scriptsFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1' | Select-Object -ExpandProperty FullName | ForEach-Object {
                $_.Replace($ModuleOutputFolder, '').TrimStart([System.IO.Path]::DirectorySeparatorChar) }
        }
        $manifest.ScriptsToProcess = if ($existingScriptsToProcess) { $existingScriptsToProcess } elseif ($allScriptsToProcess.Count -gt 0) { @($allScriptsToProcess) } else { @() }
        $manifest.ScriptsToProcess | ForEach-Object { Write-Host "[ScriptsToProcess] - [$_]" }

        Write-Host '[TypesToProcess]'
        $typesToProcess = Get-ChildItem -Path $ModuleOutputFolder -Recurse -File -ErrorAction SilentlyContinue -Include '*.Types.ps1xml' |
            Select-Object -ExpandProperty FullName |
            ForEach-Object { $_.Replace($ModuleOutputFolder, '').TrimStart($pathSeparator) }
        $manifest.TypesToProcess = $typesToProcess.count -eq 0 ? @() : @($typesToProcess)
        $manifest.TypesToProcess | ForEach-Object { Write-Host "[TypesToProcess] - [$_]" }

        Write-Host '[FormatsToProcess]'
        $formatsToProcess = Get-ChildItem -Path $ModuleOutputFolder -Recurse -File -ErrorAction SilentlyContinue -Include '*.Format.ps1xml' |
            Select-Object -ExpandProperty FullName |
            ForEach-Object { $_.Replace($ModuleOutputFolder, '').TrimStart($pathSeparator) }
        $manifest.FormatsToProcess = $formatsToProcess.count -eq 0 ? @() : @($formatsToProcess)
        $manifest.FormatsToProcess | ForEach-Object { Write-Host "[FormatsToProcess] - [$_]" }

        Write-Host '[DscResourcesToExport]'
        $dscResourcesToExportFolderPath = Join-Path $ModuleOutputFolder 'resources'
        $dscResourcesToExport = Get-ChildItem -Path $dscResourcesToExportFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1' |
            Select-Object -ExpandProperty FullName |
            ForEach-Object { $_.Replace($ModuleOutputFolder, '').TrimStart($pathSeparator) }
        $manifest.DscResourcesToExport = $dscResourcesToExport.count -eq 0 ? @() : @($dscResourcesToExport)
        $manifest.DscResourcesToExport | ForEach-Object { Write-Host "[DscResourcesToExport] - [$_]" }

        $manifest.FunctionsToExport = Get-PSModuleFunctionsToExport -SourceFolderPath $ModuleOutputFolder
        $manifest.CmdletsToExport = Get-PSModuleCmdletsToExport -SourceFolderPath $ModuleOutputFolder
        $manifest.AliasesToExport = Get-PSModuleAliasesToExport -SourceFolderPath $ModuleOutputFolder
        $manifest.VariablesToExport = Get-PSModuleVariablesToExport -SourceFolderPath $ModuleOutputFolder

        Write-Host '[ModuleList]'
        $moduleList = Get-ChildItem -Path $ModuleOutputFolder -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1' | Where-Object -Property Name -NE $rootModule |
            Select-Object -ExpandProperty FullName |
            ForEach-Object { $_.Replace($ModuleOutputFolder, '').TrimStart($pathSeparator) }
        $manifest.ModuleList = $moduleList.count -eq 0 ? @() : @($moduleList)
        $manifest.ModuleList | ForEach-Object { Write-Host "[ModuleList] - [$_]" }

        Write-Host '[Gather]'
        $capturedModules = [System.Collections.Generic.List[System.Object]]::new()
        $capturedVersions = [System.Collections.Generic.List[string]]::new()
        $capturedPSEdition = [System.Collections.Generic.List[string]]::new()

        $files = $ModuleOutputFolder | Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue
        Write-Host "[Gather] - Processing [$($files.Count)] files"
        foreach ($file in $files) {
            $relativePath = $file.FullName.Replace($ModuleOutputFolder, '').TrimStart($pathSeparator)
            Write-Host "[Gather] - [$relativePath]"

            if ($file.extension -in '.psm1', '.ps1') {
                $fileContent = Get-Content -Path $file

                switch -Regex ($fileContent) {
                    # RequiredModules -> REQUIRES -Modules <Module-Name> | <Hashtable>, @() if not provided
                    '^\s*#Requires -Modules (.+)$' {
                        # Add captured module name to array
                        $capturedMatches = $matches[1].Split(',').trim()
                        $capturedMatches | ForEach-Object {
                            $hashtable = '@\{[^}]*\}'
                            if ($_ -match $hashtable) {
                                Write-Host " - [#Requires -Modules] - [$_] - Hashtable"
                            } else {
                                Write-Host " - [#Requires -Modules] - [$_] - String"
                            }
                            $capturedModules.Add($_)
                        }
                    }
                    # PowerShellVersion -> REQUIRES -Version <N>[.<n>], $null if not provided
                    '^\s*#Requires -Version (.+)$' {
                        Write-Host " - [#Requires -Version] - [$($matches[1])]"
                        $capturedVersions.Add($matches[1])
                    }
                    #CompatiblePSEditions -> REQUIRES -PSEdition <PSEdition-Name>, $null if not provided
                    '^\s*#Requires -PSEdition (.+)$' {
                        Write-Host " - [#Requires -PSEdition] - [$($matches[1])]"
                        $capturedPSEdition.Add($matches[1])
                    }
                }
            }
        }

        <#
            $test = [Microsoft.PowerShell.Commands.ModuleSpecification]::new()
            [Microsoft.PowerShell.Commands.ModuleSpecification]::TryParse("@{ModuleName = 'Az'; RequiredVersion = '5.0.0' }", [ref]$test)
            $test

            $test.ToString()

            $required = [Microsoft.PowerShell.Commands.ModuleSpecification]::new(@{ModuleName = 'Az'; RequiredVersion = '5.0.0' })
            $required.ToString()
        #>

        Write-Host '[RequiredModules] - Gathered'
        # Group the module specifications by ModuleName
        $capturedModules = $capturedModules | ForEach-Object {
            $test = [Microsoft.PowerShell.Commands.ModuleSpecification]::new()
            if ([Microsoft.PowerShell.Commands.ModuleSpecification]::TryParse($_, [ref]$test)) {
                $test
            } else {
                [Microsoft.PowerShell.Commands.ModuleSpecification]::new($_)
            }
        }

        $groupedModules = $capturedModules | Group-Object -Property Name

        # Initialize a list to store unique module specifications
        $uniqueModules = [System.Collections.Generic.List[System.Object]]::new()

        # Iterate through each group
        foreach ($group in $groupedModules) {
            $requiredModuleName = $group.Name
            Write-Host "Processing required module [$requiredModuleName]"
            $requiredVersion = $group.Group.RequiredVersion | ForEach-Object { [Version]$_ } | Sort-Object -Unique
            $minimumVersion = $group.Group.Version | ForEach-Object { [Version]$_ } | Sort-Object -Unique | Select-Object -Last 1
            $maximumVersion = $group.Group.MaximumVersion | ForEach-Object { [Version]$_ } | Sort-Object -Unique | Select-Object -First 1
            Write-Host "RequiredVersion: [$($requiredVersion -join ', ')]"
            Write-Host "ModuleVersion:   [$minimumVersion]"
            Write-Host "MaximumVersion:  [$maximumVersion]"

            if ($requiredVersion.Count -gt 1) {
                throw 'Multiple RequiredVersions specified.'
            }

            if (-not $minimumVersion) {
                $minimumVersion = [Version]'0.0.0'
            }

            if (-not $maximumVersion) {
                $maximumVersion = [Version]'9999.9999.9999'
            }

            if ($requiredVersion -and ($minimumVersion -gt $requiredVersion)) {
                throw 'ModuleVersion is higher than RequiredVersion.'
            }

            if ($minimumVersion -gt $maximumVersion) {
                throw 'ModuleVersion is higher than MaximumVersion.'
            }
            if ($requiredVersion -and ($requiredVersion -gt $maximumVersion)) {
                throw 'RequiredVersion is higher than MaximumVersion.'
            }

            if ($requiredVersion) {
                Write-Host '[RequiredModules] - RequiredVersion'
                $uniqueModule = @{
                    ModuleName      = $requiredModuleName
                    RequiredVersion = $requiredVersion
                }
            } elseif (($minimumVersion -ne [Version]'0.0.0') -or ($maximumVersion -ne [Version]'9999.9999.9999')) {
                Write-Host '[RequiredModules] - ModuleVersion/MaximumVersion'
                $uniqueModule = @{
                    ModuleName = $requiredModuleName
                }
                if ($minimumVersion -ne [Version]'0.0.0') {
                    $uniqueModule['ModuleVersion'] = $minimumVersion
                }
                if ($maximumVersion -ne [Version]'9999.9999.9999') {
                    $uniqueModule['MaximumVersion'] = $maximumVersion
                }
            } else {
                Write-Host '[RequiredModules] - Simple string'
                $uniqueModule = $requiredModuleName
            }
            $uniqueModules.Add([Microsoft.PowerShell.Commands.ModuleSpecification]::new($uniqueModule))
        }

        Write-Host '[RequiredModules] - Result'
        $manifest.RequiredModules = $uniqueModules
        $manifest.RequiredModules | ForEach-Object { Write-Host " - [$($_ | Out-String)]" }

        Write-Host '[PowerShellVersion]'
        $capturedVersions = $capturedVersions | Sort-Object -Unique -Descending
        $capturedVersions | ForEach-Object { Write-Host "[PowerShellVersion] - [$_]" }
        $manifest.PowerShellVersion = $capturedVersions.count -eq 0 ? [version]'5.1' : [version]($capturedVersions | Select-Object -First 1)
        Write-Host '[PowerShellVersion] - Selecting version'
        Write-Host "[PowerShellVersion] - [$($manifest.PowerShellVersion)]"

        Write-Host '[CompatiblePSEditions]'
        $capturedPSEdition = $capturedPSEdition | Sort-Object -Unique
        if ($capturedPSEdition.count -eq 2) {
            throw "Conflict detected: The module requires both 'Desktop' and 'Core' editions." +
            "'Desktop' and 'Core' editions cannot be required at the same time."
        }
        if ($capturedPSEdition.count -eq 0 -and $manifest.PowerShellVersion -gt '5.1') {
            Write-Host "[CompatiblePSEditions] - Defaulting to 'Core', as no PSEdition was specified and PowerShellVersion > 5.1"
            $capturedPSEdition = @('Core')
        }
        $manifest.CompatiblePSEditions = $capturedPSEdition.count -eq 0 ? @('Core', 'Desktop') : @($capturedPSEdition)
        $manifest.CompatiblePSEditions | ForEach-Object { Write-Host "[CompatiblePSEditions] - [$_]" }

        if ($manifest.PowerShellVersion -gt '5.1' -and $manifest.CompatiblePSEditions -contains 'Desktop') {
            throw "Conflict detected: The module requires PowerShellVersion > 5.1 while CompatiblePSEditions = 'Desktop'" +
            "'Desktop' edition is not supported for PowerShellVersion > 5.1"
        }

        Write-Host '[PrivateData]'
        $privateData = $manifest.Keys -contains 'PrivateData' ? $null -ne $manifest.PrivateData ? $manifest.PrivateData : @{} : @{}
        if ($manifest.Keys -contains 'PrivateData') {
            $manifest.Remove('PrivateData')
        }

        Write-Host '[HelpInfoURI]'
        $manifest.HelpInfoURI = $privateData.Keys -contains 'HelpInfoURI' ? $null -ne $privateData.HelpInfoURI ? $privateData.HelpInfoURI : '' : ''
        Write-Host "[HelpInfoURI] - [$($manifest.HelpInfoURI)]"
        if ([string]::IsNullOrEmpty($manifest.HelpInfoURI)) {
            $manifest.Remove('HelpInfoURI')
        }

        Write-Host '[DefaultCommandPrefix]'
        $manifest.DefaultCommandPrefix = $privateData.Keys -contains 'DefaultCommandPrefix' ? $null -ne $privateData.DefaultCommandPrefix ? $privateData.DefaultCommandPrefix : '' : ''
        Write-Host "[DefaultCommandPrefix] - [$($manifest.DefaultCommandPrefix)]"

        $PSData = $privateData.Keys -contains 'PSData' ? $null -ne $privateData.PSData ? $privateData.PSData : @{} : @{}

        Write-Host '[Tags]'
        try {
            $repoLabels = gh repo view --json repositoryTopics | ConvertFrom-Json | Select-Object -ExpandProperty repositoryTopics | Select-Object -ExpandProperty name
        } catch {
            $repoLabels = @()
        }
        $manifestTags = [System.Collections.Generic.List[string]]::new()
        $tags = $PSData.Keys -contains 'Tags' ? ($PSData.Tags).Count -gt 0 ? $PSData.Tags : $repoLabels : $repoLabels
        $tags | ForEach-Object { $manifestTags.Add($_) }
        # Add tags for compatability mode. https://docs.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest?view=powershell-7.1#compatibility-tags
        if ($manifest.CompatiblePSEditions -contains 'Desktop') {
            if ($manifestTags -notcontains 'PSEdition_Desktop') {
                $manifestTags.Add('PSEdition_Desktop')
            }
        }
        if ($manifest.CompatiblePSEditions -contains 'Core') {
            if ($manifestTags -notcontains 'PSEdition_Core') {
                $manifestTags.Add('PSEdition_Core')
            }
        }
        $manifestTags | ForEach-Object { Write-Host "[Tags] - [$_]" }
        $manifest.Tags = $manifestTags

        if ($PSData.Tags -contains 'PSEdition_Core' -and $manifest.PowerShellVersion -lt '6.0') {
            throw "[Tags] - Cannot be PSEdition = 'Core' and PowerShellVersion < 6.0"
        }
        <#
            Windows: Packages that are compatible with the Windows Operating System
            Linux: Packages that are compatible with Linux Operating Systems
            MacOS: Packages that are compatible with the Mac Operating System
            https://learn.microsoft.com/en-us/powershell/gallery/concepts/package-manifest-affecting-ui?view=powershellget-2.x#tag-details
        #>

        Write-Host '[LicenseUri]'
        $licenseUri = "https://github.com/$env:GITHUB_REPOSITORY_OWNER/$env:GITHUB_REPOSITORY_NAME/blob/main/LICENSE"
        $manifest.LicenseUri = $PSData.Keys -contains 'LicenseUri' ? $null -ne $PSData.LicenseUri ? $PSData.LicenseUri : $licenseUri : $licenseUri
        Write-Host "[LicenseUri] - [$($manifest.LicenseUri)]"
        if ([string]::IsNullOrEmpty($manifest.LicenseUri)) {
            $manifest.Remove('LicenseUri')
        }

        Write-Host '[ProjectUri]'
        $projectUri = gh repo view --json url | ConvertFrom-Json | Select-Object -ExpandProperty url
        $manifest.ProjectUri = $PSData.Keys -contains 'ProjectUri' ? $null -ne $PSData.ProjectUri ? $PSData.ProjectUri : $projectUri : $projectUri
        Write-Host "[ProjectUri] - [$($manifest.ProjectUri)]"
        if ([string]::IsNullOrEmpty($manifest.ProjectUri)) {
            $manifest.Remove('ProjectUri')
        }

        Write-Host '[IconUri]'
        $iconUri = "https://raw.githubusercontent.com/$env:GITHUB_REPOSITORY_OWNER/$env:GITHUB_REPOSITORY_NAME/main/icon/icon.png"
        $manifest.IconUri = $PSData.Keys -contains 'IconUri' ? $null -ne $PSData.IconUri ? $PSData.IconUri : $iconUri : $iconUri
        Write-Host "[IconUri] - [$($manifest.IconUri)]"
        if ([string]::IsNullOrEmpty($manifest.IconUri)) {
            $manifest.Remove('IconUri')
        }

        Write-Host '[ReleaseNotes]'
        $manifest.ReleaseNotes = $PSData.Keys -contains 'ReleaseNotes' ? $null -ne $PSData.ReleaseNotes ? $PSData.ReleaseNotes : '' : ''
        Write-Host "[ReleaseNotes] - [$($manifest.ReleaseNotes)]"
        if ([string]::IsNullOrEmpty($manifest.ReleaseNotes)) {
            $manifest.Remove('ReleaseNotes')
        }

        Write-Host '[PreRelease]'
        # $manifest.PreRelease = ""
        # Is managed by the publish action

        Write-Host '[RequireLicenseAcceptance]'
        $manifest.RequireLicenseAcceptance = $PSData.Keys -contains 'RequireLicenseAcceptance' ? $null -ne $PSData.RequireLicenseAcceptance ? $PSData.RequireLicenseAcceptance : $false : $false
        Write-Host "[RequireLicenseAcceptance] - [$($manifest.RequireLicenseAcceptance)]"
        if ($manifest.RequireLicenseAcceptance -eq $false) {
            $manifest.Remove('RequireLicenseAcceptance')
        }

        Write-Host '[ExternalModuleDependencies]'
        $manifest.ExternalModuleDependencies = $PSData.Keys -contains 'ExternalModuleDependencies' ? $null -ne $PSData.ExternalModuleDependencies ? $PSData.ExternalModuleDependencies : @() : @()
        if (($manifest.ExternalModuleDependencies).count -eq 0) {
            $manifest.Remove('ExternalModuleDependencies')
        } else {
            $manifest.ExternalModuleDependencies | ForEach-Object { Write-Host "[ExternalModuleDependencies] - [$_]" }
        }

        Write-Host 'Creating new manifest file in outputs folder'
        $outputManifestPath = Join-Path -Path $ModuleOutputFolder -ChildPath "$ModuleName.psd1"
        Write-Host "OutputManifestPath - [$outputManifestPath]"
        New-ModuleManifest -Path $outputManifestPath @manifest
    }

    LogGroup 'Build manifest file - Result - Before format' {
        Show-FileContent -Path $outputManifestPath
    }

    LogGroup 'Build manifest file - Format' {
        Set-ModuleManifest -Path $outputManifestPath -Verbose
    }

    LogGroup 'Build manifest file - Result - After format' {
        Show-FileContent -Path $outputManifestPath
    }

    LogGroup 'Build manifest file - Validate - Install module dependencies' {
        Resolve-PSModuleDependency -ManifestFilePath $outputManifestPath
    }

    LogGroup 'Build manifest file - Validate - Test manifest file' {
        Test-ModuleManifest -Path $outputManifestPath
    }
}
