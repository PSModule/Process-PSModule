@{
    RootModule            = 'PSModuleEnumOnly.psm1'
    ModuleVersion         = '999.0.0'
    CompatiblePSEditions  = @(
        'Core'
        'Desktop'
    )
    GUID                  = 'b1c8c046-2253-4f30-8e08-e98a222a954a'
    Author                = 'PSModule'
    CompanyName           = 'PSModule'
    Copyright             = '(c) 2024 PSModule. All rights reserved.'
    Description           = 'Fixture module with enum type accelerators and no class type accelerators.'
    PowerShellVersion     = '5.1'
    ProcessorArchitecture = 'None'
    FunctionsToExport     = @()
    CmdletsToExport       = @()
    VariablesToExport     = @()
    AliasesToExport       = @()
    FileList              = @(
        'PSModuleEnumOnly.psd1'
        'PSModuleEnumOnly.psm1'
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
            LicenseUri = 'https://github.com/PSModule/Test-PSModule/blob/main/LICENSE'
            ProjectUri = 'https://github.com/PSModule/Test-PSModule'
        }
    }
}