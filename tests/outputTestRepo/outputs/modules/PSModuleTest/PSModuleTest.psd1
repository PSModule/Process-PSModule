@{
    RootModule            = 'PSModuleTest.psm1'
    ModuleVersion         = '999.0.0'
    CompatiblePSEditions  = @(
        'Core'
        'Desktop'
    )
    GUID                  = 'e4fb58a5-2027-4542-b7be-e5e5f352e358'
    Author                = 'PSModule'
    CompanyName           = 'PSModule'
    Copyright             = '(c) 2025 PSModule. All rights reserved.'
    Description           = 'Process a module from source code to published module.'
    PowerShellVersion     = '5.1'
    ProcessorArchitecture = 'None'
    RequiredModules       = @(
        @{
            ModuleVersion = '1.1.8'
            ModuleName    = 'DynamicParams'
        }
        @{
            RequiredVersion = '1.0.0'
            ModuleName      = 'PSSemVer'
        }
        @{
            ModuleVersion = '0.3.1'
            ModuleName    = 'Store'
        }
        'Utilities'
    )
    RequiredAssemblies    = 'assemblies/LsonLib.dll'
    ScriptsToProcess      = 'scripts/loader.ps1'
    TypesToProcess        = @(
        'types/DirectoryInfo.Types.ps1xml'
        'types/FileInfo.Types.ps1xml'
    )
    FormatsToProcess      = @(
        'formats/CultureInfo.Format.ps1xml'
        'formats/Mygciview.Format.ps1xml'
    )
    NestedModules         = @(
        'modules/OtherPSModule.psm1'
    )
    FunctionsToExport     = @(
        'Get-PSModuleTest'
        'New-PSModuleTest'
        'Set-PSModuleTest'
        'Test-PSModuleTest'
    )
    CmdletsToExport       = @()
    VariablesToExport     = @(
        'Moons'
        'Planets'
        'SolarSystems'
    )
    AliasesToExport       = @(
        'New-PSModuleTestAlias1'
        'New-PSModuleTestAlias2'
        'New-PSModuleTestAlias3'
        'New-PSModuleTestAlias4'
        'New-PSModuleTestAlias5'
    )
    ModuleList            = @(
        'modules/OtherPSModule.psm1'
    )
    FileList              = @(
        'PSModuleTest.psm1'
        'assemblies/LsonLib.dll'
        'data/Config.psd1'
        'data/Settings.psd1'
        'formats/CultureInfo.Format.ps1xml'
        'formats/Mygciview.Format.ps1xml'
        'modules/OtherPSModule.psm1'
        'scripts/loader.ps1'
        'types/DirectoryInfo.Types.ps1xml'
        'types/FileInfo.Types.ps1xml'
    )
    PrivateData           = @{
        PSData = @{
            Tags       = @(
                'workflow'
                'powershell'
                'powershell-module'
                'PSEdition_Desktop'
                'PSEdition_Core'
            )
            LicenseUri = 'https://github.com/PSModule/Process-PSModule/blob/main/LICENSE'
            ProjectUri = 'https://github.com/PSModule/Process-PSModule'
            IconUri    = 'https://raw.githubusercontent.com/PSModule/Process-PSModule/main/icon/icon.png'
        }
    }
}

