#Requires -Modules @{ ModuleName = 'GitHub'; ModuleVersion = '0.13.2' }
#Requires -Modules @{ ModuleName = 'Utilities'; ModuleVersion = '0.3.0' }

function Build-PSModuleRootModule {
    <#
        .SYNOPSIS
        Compiles the module root module files.

        .DESCRIPTION
        This function will compile the modules root module from source files.
        It will copy the source files to the output folder and start compiling the module.
        During compilation, the source files are added to the root module file in the following order:

        1. Module header from header.ps1 file. Usually to suppress code analysis warnings/errors and to add [CmdletBinding()] to the module.
        2. Data loader is added if data files are available.
        3. Combines *.ps1 files from the following folders in alphabetical order from each folder:
            1. init
            2. classes/private
            3. classes/public
            4. functions/private
            5. functions/public
            6. variables/private
            7. variables/public
            8. Any remaining *.ps1 on module root.
        4. Adds a class loader for classes found in the classes/public folder.
        5. Export-ModuleMember by using the functions, cmdlets, variables and aliases found in the source files.
            - `Functions` will only contain functions that are from the `functions/public` folder.
            - `Cmdlets` will only contain cmdlets that are from the `cmdlets/public` folder.
            - `Variables` will only contain variables that are from the `variables/public` folder.
            - `Aliases` will only contain aliases that are from the functions from the `functions/public` folder.

        .EXAMPLE
        Build-PSModuleRootModule -SourceFolderPath 'C:\MyModule\src\MyModule' -OutputFolderPath 'C:\MyModule\build\MyModule'
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Want to just write to the console, not the pipeline.'
    )]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Folder where the built modules are outputted. 'outputs/modules/MyModule'
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )

    # Get the path separator for the current OS
    $pathSeparator = [System.IO.Path]::DirectorySeparatorChar

    LogGroup 'Build root module' {
        $rootModuleFile = New-Item -Path $ModuleOutputFolder -Name "$ModuleName.psm1" -Force

        #region - Analyze source files

        #region - Export-Classes
        $classesFolder = Join-Path -Path $ModuleOutputFolder -ChildPath 'classes/public'
        $classExports = ''
        if (Test-Path -Path $classesFolder) {
            $classes = Get-PSModuleClassesToExport -SourceFolderPath $classesFolder
            if ($classes.count -gt 0) {
                $classExports += @'
#region    Class exporter
# Get the internal TypeAccelerators class to use its static methods.
$TypeAcceleratorsClass = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
# Ensure none of the types would clobber an existing type accelerator.
# If a type accelerator with the same name exists, throw an exception.
$ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
# Define the types to export with type accelerators.
$ExportableEnums = @(

'@
                $classes | Where-Object Type -EQ 'enum' | ForEach-Object {
                    $classExports += "    [$($_.Name)]`n"
                }

                $classExports += @'
)
$ExportableEnums | Foreach-Object { Write-Verbose "Exporting enum '$($_.FullName)'." }
foreach ($Type in $ExportableEnums) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        Write-Verbose "Enum already exists [$($Type.FullName)]. Skipping."
    } else {
        Write-Verbose "Importing enum '$Type'."
        $TypeAcceleratorsClass::Add($Type.FullName, $Type)
    }
}
$ExportableClasses = @(

'@
                $classes | Where-Object Type -EQ 'class' | ForEach-Object {
                    $classExports += "    [$($_.Name)]`n"
                }

                $classExports += @'
)
$ExportableClasses | Foreach-Object { Write-Verbose "Exporting class '$($_.FullName)'." }
foreach ($Type in $ExportableClasses) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        Write-Verbose "Class already exists [$($Type.FullName)]. Skipping."
    } else {
        Write-Verbose "Importing class '$Type'."
        $TypeAcceleratorsClass::Add($Type.FullName, $Type)
    }
}

# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach ($Type in ($ExportableEnums + $ExportableClasses)) {
        $TypeAcceleratorsClass::Remove($Type.FullName)
    }
}.GetNewClosure()
#endregion Class exporter
'@
            }
        }
        #endregion - Export-Classes

        $exports = [System.Collections.Specialized.OrderedDictionary]::new()
        $exports.Add('Alias', (Get-PSModuleAliasesToExport -SourceFolderPath $ModuleOutputFolder))
        $exports.Add('Cmdlet', (Get-PSModuleCmdletsToExport -SourceFolderPath $ModuleOutputFolder))
        $exports.Add('Function', (Get-PSModuleFunctionsToExport -SourceFolderPath $ModuleOutputFolder))
        $exports.Add('Variable', (Get-PSModuleVariablesToExport -SourceFolderPath $ModuleOutputFolder))

        Write-Host ($exports | Out-String)
        #endregion - Analyze source files

        #region - Module header
        $headerFilePath = Join-Path -Path $ModuleOutputFolder -ChildPath 'header.ps1'
        if (Test-Path -Path $headerFilePath) {
            Get-Content -Path $headerFilePath -Raw | Add-Content -Path $rootModuleFile -Force
            $headerFilePath | Remove-Item -Force
        } else {
            Add-Content -Path $rootModuleFile -Force -Value @'
[CmdletBinding()]
param()
'@
        }
        #endregion - Module header

        #region - Module post-header
        Add-Content -Path $rootModuleFile -Force -Value @'
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
$script:PSModuleInfo = Test-ModuleManifest -Path "$PSScriptRoot\$baseName.psd1"
$script:PSModuleInfo | Format-List | Out-String -Stream | ForEach-Object { Write-Debug $_ }
$scriptName = $script:PSModuleInfo.Name
Write-Debug "[$scriptName] - Importing module"
'@
        #endregion - Module post-header

        #region - Data loader
        if (Test-Path -Path (Join-Path -Path $ModuleOutputFolder -ChildPath 'data')) {

            Add-Content -Path $rootModuleFile.FullName -Force -Value @'
#region    Data importer
Write-Debug "[$scriptName] - [data] - Processing folder"
$dataFolder = (Join-Path $PSScriptRoot 'data')
Write-Debug "[$scriptName] - [data] - [$dataFolder]"
Get-ChildItem -Path "$dataFolder" -Recurse -Force -Include '*.psd1' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Debug "[$scriptName] - [data] - [$($_.BaseName)] - Importing"
    New-Variable -Name $_.BaseName -Value (Import-PowerShellDataFile -Path $_.FullName) -Force
    Write-Debug "[$scriptName] - [data] - [$($_.BaseName)] - Done"
}
Write-Debug "[$scriptName] - [data] - Done"
#endregion Data importer
'@
        }
        #endregion - Data loader

        #region - Add content from subfolders
        $scriptFoldersToProcess = @(
            'init',
            'classes/private',
            'classes/public',
            'functions/private',
            'functions/public',
            'variables/private',
            'variables/public'
        )

        foreach ($scriptFolder in $scriptFoldersToProcess) {
            $scriptFolder = Join-Path -Path $ModuleOutputFolder -ChildPath $scriptFolder
            if (-not (Test-Path -Path $scriptFolder)) {
                continue
            }
            Add-ContentFromItem -Path $scriptFolder -RootModuleFilePath $rootModuleFile -RootPath $ModuleOutputFolder
            Remove-Item -Path $scriptFolder -Force -Recurse
        }
        #endregion - Add content from subfolders

        #region - Add content from *.ps1 files on module root
        $files = $ModuleOutputFolder | Get-ChildItem -File -Force -Filter '*.ps1' | Sort-Object -Property FullName
        foreach ($file in $files) {
            $relativePath = $file.FullName -Replace $ModuleOutputFolder, ''
            $relativePath = $relativePath -Replace $file.Extension, ''
            $relativePath = $relativePath.TrimStart($pathSeparator)
            $relativePath = $relativePath -Split $pathSeparator | ForEach-Object { "[$_]" }
            $relativePath = $relativePath -Join ' - '

            Add-Content -Path $rootModuleFile -Force -Value @"
#region    $relativePath
Write-Debug "[`$scriptName] - $relativePath - Importing"
"@
            Get-Content -Path $file.FullName | Add-Content -Path $rootModuleFile -Force

            Add-Content -Path $rootModuleFile -Force -Value @"
Write-Debug "[`$scriptName] - $relativePath - Done"
#endregion $relativePath
"@
            $file | Remove-Item -Force
        }
        #endregion - Add content from *.ps1 files on module root

        #region - Export-ModuleMember
        Add-Content -Path $rootModuleFile -Force -Value $classExports

        $exportsString = Convert-HashtableToString -Hashtable $exports

        Write-Host ($exportsString | Out-String)

        $params = @{
            Path  = $rootModuleFile
            Force = $true
            Value = @"
#region    Member exporter
`$exports = $exportsString
Export-ModuleMember @exports
#endregion Member exporter
"@
        }
        Add-Content @params
        #endregion - Export-ModuleMember

    }

    LogGroup 'Build root module - Result - Before format' {
        Write-Host (Show-FileContent -Path $rootModuleFile)
    }

    LogGroup 'Build root module - Format' {
        $AllContent = Get-Content -Path $rootModuleFile -Raw
        $settings = Join-Path -Path $PSScriptRoot 'PSScriptAnalyzer.Tests.psd1'
        Invoke-Formatter -ScriptDefinition $AllContent -Settings $settings |
            Out-File -FilePath $rootModuleFile -Encoding utf8BOM -Force
    }

    LogGroup 'Build root module - Result - After format' {
        Write-Host (Show-FileContent -Path $rootModuleFile)
    }

    LogGroup 'Build root module - Validate - Import' {
        Add-PSModulePath -Path (Split-Path -Path $ModuleOutputFolder -Parent)
        Import-PSModule -Path $ModuleOutputFolder -ModuleName $ModuleName
    }

    LogGroup 'Build root module - Validate - File list' {
        (Get-ChildItem -Path $ModuleOutputFolder -Recurse -Force).FullName | Sort-Object
    }
}
