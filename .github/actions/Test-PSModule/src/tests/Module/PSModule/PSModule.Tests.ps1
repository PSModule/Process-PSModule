[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', 'Path',
    Justification = 'Path is used to specify the path to the module to test.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Log outputs to GitHub Actions logs.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are set in BeforeAll and consumed in Describe/It blocks.'
)]
[CmdLetBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path
)

# Discovery-phase variables — must be set at script scope (outside BeforeAll) so that
# Pester's -Skip and -ForEach parameters can reference them during test discovery.
$moduleName = Split-Path -Path (Split-Path -Path $Path -Parent) -Leaf
$moduleManifestPath = Join-Path -Path $Path -ChildPath "$moduleName.psd1"
$moduleRootPath = Join-Path -Path $Path -ChildPath "$moduleName.psm1"

# Discover public classes and enums from the compiled module source.
# The class exporter region is injected by Build-PSModule when classes/public contains types.
$moduleContent = if (Test-Path -Path $moduleRootPath) { Get-Content -Path $moduleRootPath -Raw } else { '' }
$hasClassExporter = $moduleContent -match '#region\s+Class exporter'

# Extract expected class and enum names from the class exporter block.
$expectedClassNames = @()
$expectedEnumNames = @()
if ($hasClassExporter) {
    # Match $ExportableClasses = @( ... ) block
    if ($moduleContent -match '\$ExportableClasses\s*=\s*@\(([\s\S]*?)\)') {
        $expectedClassNames = @([regex]::Matches($Matches[1], '\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
    }
    # Match $ExportableEnums = @( ... ) block
    if ($moduleContent -match '\$ExportableEnums\s*=\s*@\(([\s\S]*?)\)') {
        $expectedEnumNames = @([regex]::Matches($Matches[1], '\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
    }
}


# Run-phase setup — recompute from $Path so that It/Context blocks can use these variables.
# Pester 6 Discovery and Run are separate executions. The script-scope variables above drive
# -Skip and -ForEach during Discovery. This BeforeAll recomputes the same values for the Run
# phase, where It blocks actually execute. The duplication is intentional and required.
BeforeAll {
    $moduleName = Split-Path -Path (Split-Path -Path $Path -Parent) -Leaf
    $moduleManifestPath = Join-Path -Path $Path -ChildPath "$moduleName.psd1"
    $moduleRootPath = Join-Path -Path $Path -ChildPath "$moduleName.psm1"

    $moduleContent = if (Test-Path -Path $moduleRootPath) { Get-Content -Path $moduleRootPath -Raw } else { '' }
    $hasClassExporter = $moduleContent -match '#region\s+Class exporter'

    $expectedClassNames = @()
    $expectedEnumNames = @()
    if ($hasClassExporter) {
        if ($moduleContent -match '\$ExportableClasses\s*=\s*@\(([\s\S]*?)\)') {
            $expectedClassNames = @([regex]::Matches($Matches[1], '\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
        }
        if ($moduleContent -match '\$ExportableEnums\s*=\s*@\(([\s\S]*?)\)') {
            $expectedEnumNames = @([regex]::Matches($Matches[1], '\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
        }
    }
    Write-Host "Has class exporter: $hasClassExporter"
    Write-Host "Expected classes: $($expectedClassNames -join ', ')"
    Write-Host "Expected enums: $($expectedEnumNames -join ', ')"
}

Describe 'PSModule - Module tests' {
    Context 'Module' {
        It 'The module should be importable' {
            { Import-Module -Name $moduleManifestPath -Force } | Should -Not -Throw
        }
    }

    Context 'Module Manifest' {
        It 'Module Manifest exists' {
            $result = Test-Path -Path $moduleManifestPath
            $result | Should -Be $true
            Write-Host "$($result | Format-List | Out-String)"
        }
        It 'Module version folder matches the manifest version' {
            $manifest = Import-PowerShellDataFile -Path $moduleManifestPath
            $moduleVersionFolder = Split-Path -Path (Split-Path -Path $moduleManifestPath -Parent) -Leaf

            $moduleVersionFolder | Should -Be $manifest.ModuleVersion.ToString()
        }
        It 'Module Manifest is valid' {
            $result = Test-ModuleManifest -Path $moduleManifestPath
            $result | Should -Not -Be $null
            Write-Host "$($result | Format-List | Out-String)"
        }
    }

    Context 'Framework - Type accelerator registration' -Skip:(-not $hasClassExporter) {
        BeforeAll {
            Import-Module -Name $moduleManifestPath -Force
        }
        It 'Should register public enum [<_>] as a type accelerator' -ForEach $expectedEnumNames -AllowNullOrEmptyForEach {
            $registered = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::Get
            $registered.Keys | Should -Contain $_ -Because 'the framework registers public enums as type accelerators'
        }

        It 'Should register public class [<_>] as a type accelerator' -ForEach $expectedClassNames -AllowNullOrEmptyForEach {
            $registered = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::Get
            $registered.Keys | Should -Contain $_ -Because 'the framework registers public classes as type accelerators'
        }
    }

    Context 'Framework - Module OnRemove cleanup' -Skip:(-not $hasClassExporter) {
        BeforeAll {
            Import-Module -Name $moduleManifestPath -Force
        }
        It 'Should clean up type accelerators when the module is removed' {
            # Capture type names before removal
            $typeNames = @(@($expectedEnumNames) + @($expectedClassNames) | Where-Object { $_ })
            $typeNames | Should -Not -BeNullOrEmpty -Because 'there should be types to verify cleanup for'

            try {
                # Remove the module to trigger the OnRemove hook
                Remove-Module -Name $moduleName -Force

                # Verify type accelerators are cleaned up
                $typeAccelerators = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::Get
                foreach ($typeName in $typeNames) {
                    $typeAccelerators.Keys | Should -Not -Contain $typeName -Because "the OnRemove hook should remove type accelerator [$typeName]"
                }
            } finally {
                # Re-import the module for any subsequent tests
                Import-Module -Name $moduleManifestPath -Force
            }
        }
    }
}
