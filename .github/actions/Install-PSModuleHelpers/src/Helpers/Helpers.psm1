[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Want to just write to the console, not the pipeline.'
)]
param()

function Convert-VersionSpec {
    <#
            .SYNOPSIS
            Converts legacy version parameters into a NuGet version range string.

            .DESCRIPTION
            This function takes minimum, maximum, or required version parameters
            and constructs a NuGet-compatible version range string.

            - If `RequiredVersion` is specified, the output is an exact match range.
            - If both `MinimumVersion` and `MaximumVersion` are provided,
              an inclusive range is returned.
            - If only `MinimumVersion` is provided, it returns a minimum-inclusive range.
            - If only `MaximumVersion` is provided, it returns an upper-bound range.
            - If no parameters are provided, `$null` is returned.

            .EXAMPLE
            Convert-VersionSpec -MinimumVersion "1.0.0" -MaximumVersion "2.0.0"

            Output:
            ```powershell
            [1.0.0,2.0.0]
            ```

            Returns an inclusive version range from 1.0.0 to 2.0.0.

            .EXAMPLE
            Convert-VersionSpec -RequiredVersion "1.5.0"

            Output:
            ```powershell
            [1.5.0]
            ```

            Returns an exact match for version 1.5.0.

            .EXAMPLE
            Convert-VersionSpec -MinimumVersion "1.0.0"

            Output:
            ```powershell
            [1.0.0, ]
            ```

            Returns a minimum-inclusive version range starting at 1.0.0.

            .EXAMPLE
            Convert-VersionSpec -MaximumVersion "2.0.0"

            Output:
            ```powershell
            (, 2.0.0]
            ```

            Returns an upper-bound range up to version 2.0.0.

            .OUTPUTS
            string

            .NOTES
            The NuGet version range string based on the provided parameters.
            The returned string follows NuGet versioning syntax.

            .LINK
            https://psmodule.io/Convert/Functions/Convert-VersionSpec
        #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The minimum version for the range. If specified alone, the range is open-ended upwards.
        [Parameter()]
        [string] $MinimumVersion,

        # The maximum version for the range. If specified alone, the range is open-ended downwards.
        [Parameter()]
        [string] $MaximumVersion,

        # Specifies an exact required version. If set, an exact version range is returned.
        [Parameter()]
        [string] $RequiredVersion
    )

    if ($RequiredVersion) {
        # Use exact match in bracket notation.
        return "[$RequiredVersion]"
    } elseif ($MinimumVersion -and $MaximumVersion) {
        # Both bounds provided; both are inclusive.
        return "[$MinimumVersion,$MaximumVersion]"
    } elseif ($MinimumVersion) {
        # Only a minimum is provided. Use a minimum-inclusive range.
        return "[$MinimumVersion, ]"
    } elseif ($MaximumVersion) {
        # Only a maximum is provided; lower bound open.
        return "(, $MaximumVersion]"
    } else {
        return $null
    }
}

function Import-PSModule {
    <#
    .SYNOPSIS
    Imports a build PS module.

    .DESCRIPTION
    Imports a build PS module.

    .EXAMPLE
    Import-PSModule -SourceFolderPath $ModuleFolderPath -ModuleName $moduleName

    Imports a module located at $ModuleFolderPath with the name $moduleName.
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $Path
    )

    $moduleName = Split-Path -Path $Path -Leaf
    $manifestFilePath = Join-Path -Path $Path "$moduleName.psd1"

    Write-Host " - Manifest file path: [$manifestFilePath]"
    Resolve-PSModuleDependency -ManifestFilePath $manifestFilePath

    Write-Host ' - List installed modules'
    Get-InstalledPSResource | Format-Table -AutoSize | Out-String

    Write-Host " - Importing module [$moduleName] v999"
    Import-Module $Path

    Write-Host ' - List loaded modules'
    $availableModules = Get-Module -ListAvailable -Refresh -Verbose:$false
    $availableModules | Select-Object Name, Version, Path | Sort-Object Name | Format-Table -AutoSize | Out-String
    Write-Host ' - List commands'
    $commands = Get-Command -Module $moduleName -ListImported
    Get-Command -Module $moduleName -ListImported | Format-Table -AutoSize | Out-String

    if ($moduleName -notin $commands.Source) {
        throw 'Module not found'
    }
}

function Resolve-PSModuleDependency {
    <#
        .SYNOPSIS
        Resolves module dependencies from a manifest file using Install-PSResource.

        .DESCRIPTION
        Reads a module manifest (PSD1) and for each required module converts the old
        Install-Module parameters (MinimumVersion, MaximumVersion, RequiredVersion)
        into a single NuGet version range string for Install-PSResource's –Version parameter.
        (Note: If RequiredVersion is set, that value takes precedence.)

        .EXAMPLE
        Resolve-PSModuleDependency -ManifestFilePath 'C:\MyModule\MyModule.psd1'
        Installs all modules defined in the manifest file, following PSModuleInfo structure.

        .NOTES
        Should later be adapted to support both pre-reqs, and dependencies.
        Should later be adapted to take 4 parameters sets: specific version ("requiredVersion" | "GUID"), latest version ModuleVersion,
        and latest version within a range MinimumVersion - MaximumVersion.
    #>
    [CmdletBinding()]
    param(
        # The path to the manifest file.
        [Parameter(Mandatory)]
        [string] $ManifestFilePath
    )

    Write-Host 'Resolving dependencies'
    $manifest = Import-PowerShellDataFile -Path $ManifestFilePath
    Write-Host " - Reading [$ManifestFilePath]"
    Write-Host " - Found [$($manifest.RequiredModules.Count)] module(s) to install"

    foreach ($requiredModule in $manifest.RequiredModules) {
        # Build parameters for Install-PSResource (new version spec).
        $psResourceParams = @{
            TrustRepository = $true
        }
        # Build parameters for Import-Module (legacy version spec).
        $importParams = @{
            Force   = $true
            Verbose = $false
        }

        if ($requiredModule -is [string]) {
            $psResourceParams.Name = $requiredModule
            $importParams.Name = $requiredModule
        } else {
            $psResourceParams.Name = $requiredModule.ModuleName
            $importParams.Name = $requiredModule.ModuleName

            # Convert legacy version info for Install-PSResource.
            $versionSpec = Convert-VersionSpec `
                -MinimumVersion $requiredModule.ModuleVersion `
                -MaximumVersion $requiredModule.MaximumVersion `
                -RequiredVersion $requiredModule.RequiredVersion

            if ($versionSpec) {
                $psResourceParams.Version = $versionSpec
            }

            # For Import-Module, keep the original version parameters.
            if ($requiredModule.ModuleVersion) {
                $importParams.MinimumVersion = $requiredModule.ModuleVersion
            }
            if ($requiredModule.RequiredVersion) {
                $importParams.RequiredVersion = $requiredModule.RequiredVersion
            }
            if ($requiredModule.MaximumVersion) {
                $importParams.MaximumVersion = $requiredModule.MaximumVersion
            }
        }

        Write-Host " - [$($psResourceParams.Name)] - Installing module with Install-PSResource using version spec: $($psResourceParams.Version)"
        $VerbosePreferenceOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        $retryCount = 5
        $retryDelay = 10
        for ($i = 0; $i -lt $retryCount; $i++) {
            try {
                Install-PSResource @psResourceParams
                break
            } catch {
                Write-Warning "Installation of $($psResourceParams.Name) failed with error: $_"
                if ($i -eq $retryCount - 1) {
                    throw
                }
                Write-Warning "Retrying in $retryDelay seconds..."
                Start-Sleep -Seconds $retryDelay
            }
        }
        $VerbosePreference = $VerbosePreferenceOriginal

        Write-Host " - [$($importParams.Name)] - Importing module with legacy version spec"
        $VerbosePreferenceOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        Import-Module @importParams
        $VerbosePreference = $VerbosePreferenceOriginal
        Write-Host " - [$($importParams.Name)] - Done"
    }
    Write-Host ' - Resolving dependencies - Done'
}

function Show-FileContent {
    <#
        .SYNOPSIS
        Prints the content of a file with line numbers in front of each line.

        .DESCRIPTION
        Prints the content of a file with line numbers in front of each line.

        .EXAMPLE
        $Path = 'C:\Utilities\Show-FileContent.ps1'
        Show-FileContent -Path $Path

        Shows the content of the file with line numbers in front of each line.
    #>
    [CmdletBinding()]
    param (
        # The path to the file to show the content of.
        [Parameter(Mandatory)]
        [string] $Path
    )

    $content = Get-Content -Path $Path
    $lineNumber = 1
    $columnSize = $content.Count.ToString().Length
    # Foreach line print the line number in front of the line with [    ] around it.
    # The linenumber should dynamically adjust to the number of digits with the length of the file.
    foreach ($line in $content) {
        $lineNumberFormatted = $lineNumber.ToString().PadLeft($columnSize)
        Write-Host "[$lineNumberFormatted] $line"
        $lineNumber++
    }
}

function Install-PSModule {
    <#
        .SYNOPSIS
        Installs a build PS module.

        .DESCRIPTION
        Installs a build PS module.

        .EXAMPLE
        Install-PSModule -SourceFolderPath $ModuleFolderPath -ModuleName $moduleName

        Installs a module located at $ModuleFolderPath with the name $moduleName.
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $Path,

        # Return the path of the installed module
        [Parameter()]
        [switch] $PassThru
    )

    $moduleName = Split-Path -Path $Path -Leaf
    $manifestFilePath = Join-Path -Path $Path "$moduleName.psd1"
    Write-Verbose " - Manifest file path: [$manifestFilePath]" -Verbose
    Write-Host '::group::Resolving dependencies'
    Resolve-PSModuleDependency -ManifestFilePath $manifestFilePath
    Write-Host '::endgroup::'
    # Install into a version folder that matches the manifest's ModuleVersion so PowerShell
    # accepts the module. Fall back to the 999.0.0 placeholder only when the manifest is
    # unstamped (e.g. a build that opted out of version resolution). Validate the version as a
    # real [version] so a malformed manifest cannot inject path separators/traversal into the
    # install path.
    $manifestVersion = (Import-PowerShellDataFile -Path $manifestFilePath).ModuleVersion
    if ([string]::IsNullOrWhiteSpace($manifestVersion)) {
        $moduleVersion = '999.0.0'
    } else {
        $parsedVersion = $null
        if (-not [version]::TryParse($manifestVersion, [ref] $parsedVersion)) {
            throw "ModuleVersion '$manifestVersion' in [$manifestFilePath] is not a valid version."
        }
        $moduleVersion = $parsedVersion.ToString()
    }
    $PSModulePath = $env:PSModulePath -split [System.IO.Path]::PathSeparator | Select-Object -First 1
    $moduleInstallRoot = Join-Path -Path $PSModulePath -ChildPath $moduleName
    $moduleInstallPath = Join-Path -Path $moduleInstallRoot -ChildPath $moduleVersion
    $codePath = New-Item -Path $moduleInstallPath -ItemType Directory -Force |
        Select-Object -ExpandProperty FullName
    Copy-Item -Path "$Path/*" -Destination $codePath -Recurse -Force
    Write-Host '::group::Importing module'
    # Import the freshly-installed copy explicitly by its manifest path (with -Force) so it is
    # not shadowed by another version of the same module that may already be loaded or present
    # on $env:PSModulePath.
    $installedManifestPath = Join-Path -Path $codePath -ChildPath "$moduleName.psd1"
    Import-Module -Name $installedManifestPath -Force -Global -Verbose
    Write-Host '::endgroup::'
    if ($PassThru) {
        return $codePath
    }
}

function Get-ModuleManifest {
    <#
        .SYNOPSIS
        Get the module manifest.

        .DESCRIPTION
        Get the module manifest as a path, file info, content, or hashtable.

        .EXAMPLE
        Get-PSModuleManifest -Path 'src/PSModule/PSModule.psd1' -As Hashtable
    #>
    [OutputType([string], [System.IO.FileInfo], [System.Collections.Hashtable], [System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        # Path to the module manifest file.
        [Parameter(Mandatory)]
        [string] $Path,

        # The format of the output.
        [Parameter()]
        [ValidateSet('FileInfo', 'Content', 'Hashtable')]
        [string] $As = 'Hashtable'
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Warning 'No manifest file found.'
        return $null
    }
    Write-Verbose "Found manifest file [$Path]"

    switch ($As) {
        'FileInfo' {
            return Get-Item -Path $Path
        }
        'Content' {
            return Get-Content -Path $Path
        }
        'Hashtable' {
            $manifest = [System.Collections.Specialized.OrderedDictionary]@{}
            $psData = [System.Collections.Specialized.OrderedDictionary]@{}
            $privateData = [System.Collections.Specialized.OrderedDictionary]@{}
            $tempManifest = Import-PowerShellDataFile -Path $Path
            if ($tempManifest.ContainsKey('PrivateData')) {
                $tempPrivateData = $tempManifest.PrivateData
                if ($tempPrivateData.ContainsKey('PSData')) {
                    $tempPSData = $tempPrivateData.PSData
                    $tempPrivateData.Remove('PSData')
                }
            }

            $psdataOrder = @(
                'Tags'
                'LicenseUri'
                'ProjectUri'
                'IconUri'
                'ReleaseNotes'
                'Prerelease'
                'RequireLicenseAcceptance'
                'ExternalModuleDependencies'
            )
            foreach ($key in $psdataOrder) {
                if (($null -ne $tempPSData) -and ($tempPSData.ContainsKey($key))) {
                    $psData.$key = $tempPSData.$key
                }
            }
            if ($psData.Count -gt 0) {
                $privateData.PSData = $psData
            } else {
                $privateData.Remove('PSData')
            }
            foreach ($key in $tempPrivateData.Keys) {
                $privateData.$key = $tempPrivateData.$key
            }

            $manifestOrder = @(
                'RootModule'
                'ModuleVersion'
                'CompatiblePSEditions'
                'GUID'
                'Author'
                'CompanyName'
                'Copyright'
                'Description'
                'PowerShellVersion'
                'PowerShellHostName'
                'PowerShellHostVersion'
                'DotNetFrameworkVersion'
                'ClrVersion'
                'ProcessorArchitecture'
                'RequiredModules'
                'RequiredAssemblies'
                'ScriptsToProcess'
                'TypesToProcess'
                'FormatsToProcess'
                'NestedModules'
                'FunctionsToExport'
                'CmdletsToExport'
                'VariablesToExport'
                'AliasesToExport'
                'DscResourcesToExport'
                'ModuleList'
                'FileList'
                'HelpInfoURI'
                'DefaultCommandPrefix'
                'PrivateData'
            )
            foreach ($key in $manifestOrder) {
                if ($tempManifest.ContainsKey($key)) {
                    $manifest.$key = $tempManifest.$key
                }
            }
            if ($privateData.Count -gt 0) {
                $manifest.PrivateData = $privateData
            } else {
                $manifest.Remove('PrivateData')
            }

            return $manifest
        }
    }
}

filter Set-ModuleManifest {
    <#
        .SYNOPSIS
        Sets the values of a module manifest file.

        .DESCRIPTION
        This function sets the values of a module manifest file.
        Very much like the Update-ModuleManifest function, but allows values to be missing.

        .EXAMPLE
        Set-ModuleManifest -Path 'C:\MyModule\MyModule.psd1' -ModuleVersion '1.0.0'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Function does not change state.'
    )]
    [CmdletBinding()]
    param(
        # Path to the module manifest file.
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [string] $Path,

        #Script module or binary module file associated with this manifest.
        [Parameter()]
        [AllowNull()]
        [string] $RootModule,

        #Version number of this module.
        [Parameter()]
        [AllowNull()]
        [Version] $ModuleVersion,

        # Supported PSEditions.
        [Parameter()]
        [AllowNull()]
        [string[]] $CompatiblePSEditions,

        # ID used to uniquely identify this module.
        [Parameter()]
        [AllowNull()]
        [guid] $GUID,

        # Author of this module.
        [Parameter()]
        [AllowNull()]
        [string] $Author,

        # Company or vendor of this module.
        [Parameter()]
        [AllowNull()]
        [string] $CompanyName,

        # Copyright statement for this module.
        [Parameter()]
        [AllowNull()]
        [string] $Copyright,

        # Description of the functionality provided by this module.
        [Parameter()]
        [AllowNull()]
        [string] $Description,

        # Minimum version of the PowerShell engine required by this module.
        [Parameter()]
        [AllowNull()]
        [Version] $PowerShellVersion,

        # Name of the PowerShell host required by this module.
        [Parameter()]
        [AllowNull()]
        [string] $PowerShellHostName,

        # Minimum version of the PowerShell host required by this module.
        [Parameter()]
        [AllowNull()]
        [version] $PowerShellHostVersion,

        # Minimum version of Microsoft .NET Framework required by this module.
        # This prerequisite is valid for the PowerShell Desktop edition only.
        [Parameter()]
        [AllowNull()]
        [Version] $DotNetFrameworkVersion,

        # Minimum version of the common language runtime (CLR) required by this module.
        # This prerequisite is valid for the PowerShell Desktop edition only.
        [Parameter()]
        [AllowNull()]
        [Version] $ClrVersion,

        # Processor architecture (None,X86, Amd64) required by this module
        [Parameter()]
        [AllowNull()]
        [System.Reflection.ProcessorArchitecture] $ProcessorArchitecture,

        # Modules that must be imported into the global environment prior to importing this module.
        [Parameter()]
        [AllowNull()]
        [Object[]] $RequiredModules,

        # Assemblies that must be loaded prior to importing this module.
        [Parameter()]
        [AllowNull()]
        [string[]] $RequiredAssemblies,

        # Script files (.ps1) that are run in the caller's environment prior to importing this module.
        [Parameter()]
        [AllowNull()]
        [string[]] $ScriptsToProcess,

        # Type files (.ps1xml) to be loaded when importing this module.
        [Parameter()]
        [AllowNull()]
        [string[]] $TypesToProcess,

        # Format files (.ps1xml) to be loaded when importing this module.
        [Parameter()]
        [AllowNull()]
        [string[]] $FormatsToProcess,

        # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess.
        [Parameter()]
        [AllowNull()]
        [Object[]] $NestedModules,

        # Functions to export from this module, for best performance, do not use wildcards and do not
        # delete the entry, use an empty array if there are no functions to export.
        [Parameter()]
        [AllowNull()]
        [string[]] $FunctionsToExport,

        # Cmdlets to export from this module, for best performance, do not use wildcards and do not
        # delete the entry, use an empty array if there are no cmdlets to export.
        [Parameter()]
        [AllowNull()]
        [string[]] $CmdletsToExport,

        # Variables to export from this module.
        [Parameter()]
        [AllowNull()]
        [string[]] $VariablesToExport,

        # Aliases to export from this module, for best performance, do not use wildcards and do not
        # delete the entry, use an empty array if there are no aliases to export.
        [Parameter()]
        [AllowNull()]
        [string[]] $AliasesToExport,

        # DSC resources to export from this module.
        [Parameter()]
        [AllowNull()]
        [string[]] $DscResourcesToExport,

        # List of all modules packaged with this module.
        [Parameter()]
        [AllowNull()]
        [Object[]] $ModuleList,

        # List of all files packaged with this module.
        [Parameter()]
        [AllowNull()]
        [string[]] $FileList,

        # Tags applied to this module. These help with module discovery in online galleries.
        [Parameter()]
        [AllowNull()]
        [string[]] $Tags,

        # A URL to the license for this module.
        [Parameter()]
        [AllowNull()]
        [uri] $LicenseUri,

        # A URL to the main site for this project.
        [Parameter()]
        [AllowNull()]
        [uri] $ProjectUri,

        # A URL to an icon representing this module.
        [Parameter()]
        [AllowNull()]
        [uri] $IconUri,

        # ReleaseNotes of this module.
        [Parameter()]
        [AllowNull()]
        [string] $ReleaseNotes,

        # Prerelease string of this module.
        [Parameter()]
        [AllowNull()]
        [string] $Prerelease,

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save.
        [Parameter()]
        [AllowNull()]
        [bool] $RequireLicenseAcceptance,

        # External dependent modules of this module.
        [Parameter()]
        [AllowNull()]
        [string[]] $ExternalModuleDependencies,

        # HelpInfo URI of this module.
        [Parameter()]
        [AllowNull()]
        [String] $HelpInfoURI,

        # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
        [Parameter()]
        [AllowNull()]
        [string] $DefaultCommandPrefix,

        # Private data to pass to the module specified in RootModule/ModuleToProcess.
        # This may also contain a PSData hashtable with additional module metadata used by PowerShell.
        [Parameter()]
        [AllowNull()]
        [object] $PrivateData
    )

    $outManifest = [ordered]@{}
    $outPSData = [ordered]@{}
    $outPrivateData = [ordered]@{}

    $tempManifest = Get-ModuleManifest -Path $Path
    if ($tempManifest.Keys.Contains('PrivateData')) {
        $tempPrivateData = $tempManifest.PrivateData
        if ($tempPrivateData.Keys.Contains('PSData')) {
            $tempPSData = $tempPrivateData.PSData
            $tempPrivateData.Remove('PSData')
        }
    }

    $psdataOrder = @(
        'Tags'
        'LicenseUri'
        'ProjectUri'
        'IconUri'
        'ReleaseNotes'
        'Prerelease'
        'RequireLicenseAcceptance'
        'ExternalModuleDependencies'
    )
    foreach ($key in $psdataOrder) {
        if (($null -ne $tempPSData) -and $tempPSData.Keys.Contains($key)) {
            $outPSData[$key] = $tempPSData[$key]
        }
        if ($PSBoundParameters.Keys.Contains($key)) {
            if ($null -eq $PSBoundParameters[$key]) {
                $outPSData.Remove($key)
            } else {
                $outPSData[$key] = $PSBoundParameters[$key]
            }
        }
    }

    if ($outPSData.Count -gt 0) {
        $outPrivateData.PSData = $outPSData
    } else {
        $outPrivateData.Remove('PSData')
    }
    foreach ($key in $tempPrivateData.Keys) {
        $outPrivateData[$key] = $tempPrivateData[$key]
    }
    foreach ($key in $PrivateData.Keys) {
        $outPrivateData[$key] = $PrivateData[$key]
    }

    $manifestOrder = @(
        'RootModule'
        'ModuleVersion'
        'CompatiblePSEditions'
        'GUID'
        'Author'
        'CompanyName'
        'Copyright'
        'Description'
        'PowerShellVersion'
        'PowerShellHostName'
        'PowerShellHostVersion'
        'DotNetFrameworkVersion'
        'ClrVersion'
        'ProcessorArchitecture'
        'RequiredModules'
        'RequiredAssemblies'
        'ScriptsToProcess'
        'TypesToProcess'
        'FormatsToProcess'
        'NestedModules'
        'FunctionsToExport'
        'CmdletsToExport'
        'VariablesToExport'
        'AliasesToExport'
        'DscResourcesToExport'
        'ModuleList'
        'FileList'
        'HelpInfoURI'
        'DefaultCommandPrefix'
        'PrivateData'
    )
    foreach ($key in $manifestOrder) {
        if ($tempManifest.Keys.Contains($key)) {
            $outManifest[$key] = $tempManifest[$key]
        }
        if ($PSBoundParameters.Keys.Contains($key)) {
            if ($null -eq $PSBoundParameters[$key]) {
                $outManifest.Remove($key)
            } else {
                $outManifest[$key] = $PSBoundParameters[$key]
            }
        }
    }
    if ($outPrivateData.Count -gt 0) {
        $outManifest['PrivateData'] = $outPrivateData
    } else {
        $outManifest.Remove('PrivateData')
    }

    $sectionsToSort = @(
        'CompatiblePSEditions',
        'RequiredAssemblies',
        'ScriptsToProcess',
        'TypesToProcess',
        'FormatsToProcess',
        'FunctionsToExport',
        'CmdletsToExport',
        'VariablesToExport',
        'AliasesToExport',
        'DscResourcesToExport',
        'ModuleList',
        'FileList'
    )

    foreach ($section in $sectionsToSort) {
        if ($outManifest.Contains($section) -and $null -ne $outManifest[$section]) {
            $outManifest[$section] = @($outManifest[$section] | Sort-Object)
        }
    }

    $objectSectionsToSort = @('RequiredModules', 'NestedModules')
    foreach ($section in $objectSectionsToSort) {
        if ($outManifest.Contains($section) -and $null -ne $outManifest[$section]) {
            $sortedObjects = $outManifest[$section] | Sort-Object -Property {
                if ($_ -is [hashtable]) {
                    $_['ModuleName']
                } elseif ($_ -is [Microsoft.PowerShell.Commands.ModuleSpecification]) {
                    $_.Name
                } elseif ($_ -is [string]) {
                    $_
                } else {
                    throw "Unsupported type '$($_.GetType().Name)' in module manifest."
                }
            }

            $formattedModules = foreach ($item in $sortedObjects) {
                if ($item -is [Microsoft.PowerShell.Commands.ModuleSpecification]) {
                    $hash = [ordered]@{}
                    $hash['ModuleName'] = $item.Name
                    if ($item.RequiredVersion) {
                        $hash['RequiredVersion'] = $item.RequiredVersion.ToString()
                    } elseif ($item.Version) {
                        $hash['ModuleVersion'] = $item.Version.ToString()
                    } elseif ($item.MaximumVersion) {
                        $hash['MaximumVersion'] = $item.MaximumVersion.ToString()
                    }

                    if ($hash.Count -eq 1) {
                        # Simplify if only ModuleName
                        $hash.ModuleName
                    } else {
                        $hash
                    }
                } elseif ($item -is [hashtable]) {
                    # Recreate as ordered hashtable explicitly
                    $orderedItem = [ordered]@{}
                    if ($item.ContainsKey('ModuleName')) {
                        $orderedItem['ModuleName'] = $item['ModuleName']
                    }
                    if ($item.RequiredVersion) {
                        $orderedItem['RequiredVersion'] = $item.RequiredVersion
                    }
                    if ($item.ModuleVersion) {
                        $orderedItem['ModuleVersion'] = $item.ModuleVersion
                    }
                    if ($item.MaximumVersion) {
                        $orderedItem['MaximumVersion'] = $item.MaximumVersion
                    }
                    $orderedItem
                } elseif ($item -is [string]) {
                    $item
                }
            }

            $outManifest[$section] = @($formattedModules)
        }
    }




    if ($outPrivateData.Contains('PSData')) {
        if ($outPrivateData.PSData.Contains('ExternalModuleDependencies') -and $null -ne $outPrivateData.PSData.ExternalModuleDependencies) {
            $outPrivateData.PSData.ExternalModuleDependencies = @($outPrivateData.PSData.ExternalModuleDependencies | Sort-Object)
        }
        if ($outPrivateData.PSData.Contains('Tags') -and $null -ne $outPrivateData.PSData.Tags) {
            $outPrivateData.PSData.Tags = @($outPrivateData.PSData.Tags | Sort-Object)
        }
    }

    Remove-Item -Path $Path -Force
    Export-PowerShellDataFile -Hashtable $outManifest -Path $Path
}

function Export-PowerShellDataFile {
    <#
        .SYNOPSIS
        Export a hashtable to a .psd1 file.

        .DESCRIPTION
        This function exports a hashtable to a .psd1 file. It also formats the .psd1 file using the Format-ModuleManifest cmdlet.

        .EXAMPLE
        Export-PowerShellDataFile -Hashtable @{ Name = 'MyModule'; ModuleVersion = '1.0.0' } -Path 'MyModule.psd1'
    #>
    [CmdletBinding()]
    param (
        # The hashtable to export to a .psd1 file.
        [Parameter(Mandatory)]
        [object] $Hashtable,

        # The path of the .psd1 file to export.
        [Parameter(Mandatory)]
        [string] $Path,

        # Force the export, even if the file already exists.
        [Parameter()]
        [switch] $Force
    )

    $content = Format-Hashtable -Hashtable $Hashtable
    $content | Out-File -FilePath $Path -Force:$Force
    Format-ModuleManifest -Path $Path
}

function Format-ModuleManifest {
    <#
        .SYNOPSIS
        Formats a module manifest file.

        .DESCRIPTION
        This function formats a module manifest file, by removing comments and empty lines,
        and then formatting the file using the `Invoke-Formatter` function.

        .EXAMPLE
        Format-ModuleManifest -Path 'C:\MyModule\MyModule.psd1'
    #>
    [CmdletBinding()]
    param(
        # Path to the module manifest file.
        [Parameter(Mandatory)]
        [string] $Path
    )

    $Utf8BomEncoding = New-Object System.Text.UTF8Encoding $true

    $manifestContent = Get-Content -Path $Path
    $manifestContent = $manifestContent | ForEach-Object { $_ -replace '#.*' }
    $manifestContent = $manifestContent | ForEach-Object { $_.TrimEnd() }
    $manifestContent = $manifestContent | Where-Object { -not [string]::IsNullOrEmpty($_) }
    [System.IO.File]::WriteAllLines($Path, $manifestContent, $Utf8BomEncoding)
    $manifestContent = Get-Content -Path $Path -Raw

    $content = Invoke-Formatter -ScriptDefinition $manifestContent

    # Ensure exactly one empty line at the end
    $content = $content.TrimEnd([System.Environment]::NewLine) + [System.Environment]::NewLine

    [System.IO.File]::WriteAllText($Path, $content, $Utf8BomEncoding)
}

filter Format-Hashtable {
    <#
        .SYNOPSIS
        Converts a hashtable to its PowerShell code representation.

        .DESCRIPTION
        Recursively converts a hashtable to its PowerShell code representation.
        This function is useful for exporting hashtables to `.psd1` files,
        making it easier to store and retrieve structured data.

        .EXAMPLE
        $hashtable = @{
            Key1 = 'Value1'
            Key2 = @{
                NestedKey1 = 'NestedValue1'
                NestedKey2 = 'NestedValue2'
            }
            Key3 = @(1, 2, 3)
            Key4 = $true
        }
        Format-Hashtable -Hashtable $hashtable

        Output:
        ```powershell
        @{
            Key1       = 'Value1'
            Key2       = @{
                NestedKey1 = 'NestedValue1'
                NestedKey2 = 'NestedValue2'
            }
            Key3       = @(
                1
                2
                3
            )
            Key4       = $true
        }
        ```

        .OUTPUTS
        string

        .NOTES
        A string representation of the given hashtable.
        Useful for serialization and exporting hashtables to files.

        .LINK
        https://psmodule.io/Hashtable/Functions/Format-Hashtable
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        # The hashtable to convert to a PowerShell code representation.
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [System.Collections.IDictionary] $Hashtable,

        # The indentation level for formatting nested structures.
        [Parameter()]
        [int] $IndentLevel = 1
    )

    # If the hashtable is empty, return '@{}' immediately.
    if ($Hashtable.Count -eq 0) {
        return '@{}'
    }

    $indent = '    '
    $lines = @()
    $lines += '@{'
    $levelIndent = $indent * $IndentLevel

    # Compute maximum key length at this level to align the '=' characters
    $maxKeyLength = ($Hashtable.Keys | ForEach-Object { $_.ToString().Length } | Measure-Object -Maximum).Maximum

    foreach ($key in $Hashtable.Keys) {
        # Pad each key to the maximum length so the '=' lines up.
        $paddedKey = $key.ToString().PadRight($maxKeyLength)
        Write-Verbose "Processing key: [$key]"
        $value = $Hashtable[$key]
        Write-Verbose "Processing value: [$value]"
        if ($null -eq $value) {
            Write-Verbose "Value type: `$null"
            $lines += "$levelIndent$paddedKey = `$null"
            continue
        }
        Write-Verbose "Value type: [$($value.GetType().Name)]"
        if ($value -is [System.Collections.IDictionary]) {
            # Nested hashtable
            $nestedString = Format-Hashtable -Hashtable $value -IndentLevel ($IndentLevel + 1)
            $lines += "$levelIndent$paddedKey = $nestedString"
        } elseif ($value -is [System.Management.Automation.PSCustomObject]) {
            # PSCustomObject => Convert to hashtable & recurse
            $nestedString = $value | ConvertTo-Hashtable | Format-Hashtable -IndentLevel ($IndentLevel + 1)
            $lines += "$levelIndent$paddedKey = $nestedString"
        } elseif ( $value -is [bool] -or $value -is [System.Management.Automation.SwitchParameter] ) {
            $boolValue = [bool]$value
            $lines += "$levelIndent$paddedKey = `$$($boolValue.ToString().ToLower())"
        } elseif ($value -is [int] -or $value -is [long] -or $value -is [double] -or $value -is [decimal]) {
            $lines += "$levelIndent$paddedKey = $value"
        } elseif ($value -is [System.Collections.IList]) {
            # This covers normal arrays, ArrayList, List<T>, etc.
            if ($value.Count -eq 0) {
                $lines += "$levelIndent$paddedKey = @()"
            } else {
                $lines += "$levelIndent$paddedKey = @("
                $arrayIndent = $levelIndent + $indent

                foreach ($nestedValue in $value) {
                    Write-Verbose "Processing array element: [$nestedValue]"
                    Write-Verbose "Element type: [$($nestedValue.GetType().Name)]"

                    if (($nestedValue -is [System.Collections.IDictionary])) {
                        # Nested hashtable
                        $nestedString = Format-Hashtable -Hashtable $nestedValue -IndentLevel ($IndentLevel + 2)
                        $lines += "$arrayIndent$nestedString"
                    } elseif ($nestedValue -is [System.Management.Automation.PSCustomObject]) {
                        # PSCustomObject => Convert to hashtable & recurse
                        $nestedString = $nestedValue | ConvertTo-Hashtable | Format-Hashtable -IndentLevel ($IndentLevel + 2)
                        $lines += "$arrayIndent$nestedString"
                    } elseif ( $nestedValue -is [bool] -or $nestedValue -is [System.Management.Automation.SwitchParameter] ) {
                        $boolValue = [bool]$nestedValue
                        $lines += "$arrayIndent`$$($boolValue.ToString().ToLower())"
                    } elseif ($nestedValue -is [int] -or $nestedValue -is [long] -or $nestedValue -is [double] -or $nestedValue -is [decimal]) {
                        $lines += "$arrayIndent$nestedValue"
                    } else {
                        # Fallback => treat as string (escape single-quotes)
                        $escapedElement = $nestedValue -replace "('+)", "''"
                        $lines += "$arrayIndent'$escapedElement'"
                    }
                }

                $lines += ($levelIndent + ')')
            }
        } else {
            # Fallback: treat as string (escaping single-quotes)
            $escapedValue = $value -replace "('+)", "''"
            $lines += "$levelIndent$paddedKey = '$escapedValue'"
        }
    }

    $levelIndent = $indent * ($IndentLevel - 1)
    $lines += "$levelIndent}"

    return $lines -join [Environment]::NewLine
}

function Add-PSModulePath {
    <#
        .SYNOPSIS
        Adds a path to the PSModulePath environment variable.

        .DESCRIPTION
        Adds a path to the PSModulePath environment variable.
        For Linux and macOS, the path delimiter is ':' and for Windows it is ';'.

        .EXAMPLE
        Add-PSModulePath -Path 'C:\Users\user\Documents\WindowsPowerShell\Modules'

        Adds the path 'C:\Users\user\Documents\WindowsPowerShell\Modules' to the PSModulePath environment variable.
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $Path
    )
    $PSModulePathSeparator = [System.IO.Path]::PathSeparator

    $env:PSModulePath += "$PSModulePathSeparator$Path"

    Write-Verbose 'PSModulePath:'
    $env:PSModulePath.Split($PSModulePathSeparator) | ForEach-Object {
        Write-Verbose " - [$_]"
    }
}

function Set-GitHubLogGroup {
    <#
        .SYNOPSIS
        Encapsulates commands with a log group in GitHub Actions

        .DESCRIPTION
        DSL approach for GitHub Action commands.
        Allows for collapsing of code in IDE for code that belong together.

        .EXAMPLE
        Set-GitHubLogGroup -Name 'MyGroup' -ScriptBlock {
            Write-Host 'Hello, World!'
        }

        Creates a new log group named 'MyGroup' and writes 'Hello, World!' to the output.

        .EXAMPLE
        LogGroup 'MyGroup' {
            Write-Host 'Hello, World!'
        }

        Uses the alias 'LogGroup' to create a new log group named 'MyGroup' and writes 'Hello, World!' to the output.

        .NOTES
        [GitHub - Grouping log lines](https://docs.github.com/actions/using-workflows/workflow-commands-for-github-actions#grouping-log-lines)

        .LINK
        https://psmodule.io/GitHub/Functions/Commands/Set-GitHubLogGroup
    #>
    [Alias('LogGroup')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function',
        Justification = 'Does not change state'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Intended for logging in Github Runners which does support Write-Host'
    )]
    [CmdletBinding()]
    param(
        # The name of the log group
        [Parameter(Mandatory)]
        [string] $Name,

        # The script block to execute
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    Write-Host "::group::$Name"
    . $ScriptBlock
    Write-Host '::endgroup::'
}

function Import-TestData {
    <#
        .SYNOPSIS
        Exposes caller-provided TestData as environment variables for later steps in the job.

        .DESCRIPTION
        Reads the `PSMODULE_TEST_DATA` environment variable, which is expected to contain a single-line
        JSON object with optional `secrets` and `variables` maps. Each entry is validated and written to
        the file referenced by `GITHUB_ENV` so it becomes available as `$env:<name>` in subsequent steps
        of the same job. Values under `secrets` are masked in the logs via `::add-mask::`; values under
        `variables` are not. When no test data is provided the function is a no-op.

        .EXAMPLE
        Import-TestData

        Reads `$env:PSMODULE_TEST_DATA` and exposes its `secrets` and `variables` entries as environment
        variables for the following steps in the job.
    #>
    [CmdletBinding()]
    param()

    if ([string]::IsNullOrWhiteSpace($env:PSMODULE_TEST_DATA)) {
        Write-Verbose 'No test data was provided by the calling workflow.'
        return
    }
    if ([string]::IsNullOrWhiteSpace($env:GITHUB_ENV)) {
        throw 'Import-TestData requires the GITHUB_ENV environment file, which is only available inside GitHub Actions.'
    }
    try {
        $data = $env:PSMODULE_TEST_DATA | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "The 'TestData' secret must be valid JSON with 'secrets' and/or 'variables' maps."
    }
    if ($null -eq $data -or $data -isnot [pscustomobject]) {
        throw "The 'TestData' secret must be a JSON object with 'secrets' and/or 'variables' maps."
    }
    $allowedTopLevelKeys = @('secrets', 'variables')
    foreach ($propertyName in $data.PSObject.Properties.Name) {
        if ($allowedTopLevelKeys -notcontains $propertyName) {
            throw "The 'TestData' secret only supports 'secrets' and 'variables' maps."
        }
    }
    $reservedNames = @('CI', 'HOME', 'PATH', 'PWD', 'SHELL', 'PSMODULE_TEST_DATA')
    $reservedPrefixes = @('GITHUB_', 'RUNNER_', 'ACTIONS_')
    function Assert-EnvironmentName {
        <#
            .SYNOPSIS
            Validates that a TestData key can safely be written to GITHUB_ENV.
        #>
        param([string] $Name)
        if ($Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw 'TestData keys must be valid environment variable names.'
        }
        $normalized = $Name.ToUpperInvariant()
        if ($reservedNames -contains $normalized) {
            throw 'TestData keys must not override reserved environment variables.'
        }
        foreach ($prefix in $reservedPrefixes) {
            if ($normalized.StartsWith($prefix)) {
                throw 'TestData keys must not override reserved environment variables.'
            }
        }
    }
    function Assert-Map {
        <#
            .SYNOPSIS
            Validates that a TestData section is a JSON object map.
        #>
        param(
            [object] $Map,
            [string] $Name
        )
        if ($null -eq $Map) { return }
        if ($Map -isnot [pscustomobject]) {
            throw "The 'TestData.$Name' value must be a JSON object."
        }
    }
    function Get-EnvironmentValue {
        <#
            .SYNOPSIS
            Converts a scalar TestData value to an environment variable value.
        #>
        param(
            [object] $Value,
            [string] $Name
        )
        if ($null -eq $Value) { return '' }
        if (
            $Value -is [pscustomobject] -or
            ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string])
        ) {
            throw "Values in 'TestData.$Name' must be scalar values."
        }
        return [string]$Value
    }
    function Add-EnvFromMap {
        <#
            .SYNOPSIS
            Writes validated TestData entries to GITHUB_ENV.
        #>
        param(
            [object] $Map,
            [string] $Name,
            [switch] $Mask
        )
        Assert-Map -Map $Map -Name $Name
        if ($null -eq $Map) { return }
        $count = 0
        foreach ($item in $Map.PSObject.Properties) {
            $entryName = $item.Name
            Assert-EnvironmentName -Name $entryName
            $value = Get-EnvironmentValue -Value $item.Value -Name $Name
            if ($Mask) {
                foreach ($line in ($value -split "`n")) {
                    $line = $line.TrimEnd("`r")
                    if ($line.Length -gt 0) {
                        Write-Host "::add-mask::$line"
                    }
                }
            }
            do {
                $delimiter = "GHENV_$([guid]::NewGuid().ToString('N'))"
            } while ($value.Contains($delimiter))
            Add-Content -Path $env:GITHUB_ENV -Value "$entryName<<$delimiter" -Encoding utf8 -ErrorAction Stop
            Add-Content -Path $env:GITHUB_ENV -Value $value -Encoding utf8 -ErrorAction Stop
            Add-Content -Path $env:GITHUB_ENV -Value $delimiter -Encoding utf8 -ErrorAction Stop
            $count++
        }
        if ($count -gt 0) {
            if ($Mask) {
                Write-Host "Exposed $count secret value(s) as environment variables."
            } else {
                Write-Host "Exposed $count variable value(s) as environment variables."
            }
        }
    }

    Assert-Map -Map $data.secrets -Name 'secrets'
    Assert-Map -Map $data.variables -Name 'variables'

    $secretNames = @()
    if ($null -ne $data.secrets) {
        $secretNames = @($data.secrets.PSObject.Properties.Name)
    }
    $variableNames = @()
    if ($null -ne $data.variables) {
        $variableNames = @($data.variables.PSObject.Properties.Name)
    }
    $secretNameSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($secretName in $secretNames) {
        [void] $secretNameSet.Add($secretName)
    }
    foreach ($variableName in $variableNames) {
        if ($secretNameSet.Contains($variableName)) {
            throw 'TestData keys must not be duplicated across secrets and variables.'
        }
    }

    Add-EnvFromMap -Map $data.secrets -Name 'secrets' -Mask
    Add-EnvFromMap -Map $data.variables -Name 'variables'
}

