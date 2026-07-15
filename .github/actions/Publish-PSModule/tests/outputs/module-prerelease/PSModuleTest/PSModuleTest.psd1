@{
    RootModule           = 'PSModuleTest.psm1'
    ModuleVersion        = '2.0.0'
    CompatiblePSEditions = @(
        'Core'
        'Desktop'
    )
    GUID                 = '20b37221-db1c-43db-9cca-f22b33123548'
    Author               = 'PSModule'
    CompanyName          = 'PSModule'
    Copyright            = '(c) 2024 PSModule. All rights reserved.'
    Description          = 'Process a module from source code to published module.'
    PowerShellVersion    = '5.1'
    FunctionsToExport    = @(
        'Get-PSModuleTest'
        'New-PSModuleTest'
        'Set-PSModuleTest'
        'Test-PSModuleTest'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Prerelease = 'preview1'
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
