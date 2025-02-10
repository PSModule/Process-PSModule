[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', 'Path',
    Justification = 'Path is used to specify the path to the module to test.'
)]
[CmdLetBinding()]
Param(
    [Parameter(Mandatory)]
    [string] $Path
)

BeforeAll {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseDeclaredVarsMoreThanAssignments', 'moduleName',
        Justification = 'moduleName is used in the test.'
    )]
    $moduleName = Split-Path -Path $Path -Leaf
}

Describe 'PSModule - Module tests' {
    Context 'Module' {
        It 'The module should be available' {
            Get-Module -Name $moduleName -ListAvailable | Should -Not -BeNullOrEmpty
            Write-Verbose (Get-Module -Name $moduleName -ListAvailable | Out-String)
        }
        It 'The module should be importable' {
            { Import-Module -Name $moduleName -RequiredVersion 999.0.0 -Force } | Should -Not -Throw
        }
    }

    Context "Module Manifest" {
        BeforeAll {
            $moduleManifestPath = Join-Path -Path $Path -ChildPath "$moduleName.psd1"
            Write-Verbose "Module Manifest Path: [$moduleManifestPath]"
        }
        It 'Module Manifest exists' {
            $result = Test-Path -Path $moduleManifestPath
            $result | Should -Be $true
            Write-Verbose $result
        }
        It 'Module Manifest is valid' {
            $result = Test-ModuleManifest -Path $moduleManifestPath
            $result | Should -Not -Be $null
            Write-Verbose $result
        }
        # It 'has a valid license URL' {}
        # It 'has a valid project URL' {}
        # It 'has a valid icon URL' {}
        # It 'has a valid help URL' {}
    }
}
