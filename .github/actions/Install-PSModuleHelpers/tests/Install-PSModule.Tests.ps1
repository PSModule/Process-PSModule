[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$helpersManifestPath = Join-Path -Path $repoRoot -ChildPath 'src/Helpers/Helpers.psd1'
$originalPSModulePath = $env:PSModulePath
$testRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "Install-PSModule-$([guid]::NewGuid())"

$assert = {
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

try {
    $testPSModulePath = Join-Path -Path $testRoot -ChildPath 'PSModules'
    New-Item -Path $testPSModulePath -ItemType Directory -Force | Out-Null
    $env:PSModulePath = $testPSModulePath + [System.IO.Path]::PathSeparator + $originalPSModulePath

    Remove-Module -Name Helpers -Force -ErrorAction SilentlyContinue
    Import-Module -Name $helpersManifestPath -Force

    $realVersionSourcePath = Join-Path -Path $testRoot -ChildPath 'RealVersionModule'
    New-Item -Path $realVersionSourcePath -ItemType Directory -Force | Out-Null
    "function Get-RealVersionValue { 'real-1.2.3' }" |
        Set-Content -Path (Join-Path -Path $realVersionSourcePath -ChildPath 'RealVersionModule.psm1')
    @'
@{
    RootModule = 'RealVersionModule.psm1'
    ModuleVersion = '1.2.3'
    GUID = '11111111-1111-1111-1111-111111111111'
    Author = 'Test'
    FunctionsToExport = @('Get-RealVersionValue')
}
'@ | Set-Content -Path (Join-Path -Path $realVersionSourcePath -ChildPath 'RealVersionModule.psd1')

    $realVersionInstalledPath = Install-PSModule -Path $realVersionSourcePath -PassThru
    $realVersionInstallRoot = Join-Path -Path $testPSModulePath -ChildPath 'RealVersionModule'
    $expectedRealVersionPath = Join-Path -Path $realVersionInstallRoot -ChildPath '1.2.3'
    $unexpectedPlaceholderPath = Join-Path -Path $realVersionInstallRoot -ChildPath '999.0.0'
    $realVersionManifestPath = Join-Path -Path $expectedRealVersionPath -ChildPath 'RealVersionModule.psd1'
    $returnedRealVersionPath = [System.IO.Path]::GetFullPath($realVersionInstalledPath)
    $expectedRealVersionFullPath = [System.IO.Path]::GetFullPath($expectedRealVersionPath)

    & $assert ($returnedRealVersionPath -eq $expectedRealVersionFullPath) 'Expected Install-PSModule to return the real version path.'
    & $assert (Test-Path -Path $realVersionManifestPath) 'Expected the module to be installed under version 1.2.3.'
    & $assert (-not (Test-Path -Path $unexpectedPlaceholderPath)) 'Did not expect stamped modules to be installed under 999.0.0.'
    & $assert ((Get-RealVersionValue) -eq 'real-1.2.3') 'Expected the real-version module command to be imported.'

    Remove-Module -Name RealVersionModule -Force -ErrorAction SilentlyContinue

    $shadowInstallRoot = Join-Path -Path $testPSModulePath -ChildPath 'ShadowModule'
    $oldShadowInstallPath = Join-Path -Path $shadowInstallRoot -ChildPath '999.0.0'
    New-Item -Path $oldShadowInstallPath -ItemType Directory -Force | Out-Null
    "function Get-ShadowValue { 'old-999' }" |
        Set-Content -Path (Join-Path -Path $oldShadowInstallPath -ChildPath 'ShadowModule.psm1')
    @'
@{
    RootModule = 'ShadowModule.psm1'
    ModuleVersion = '999.0.0'
    GUID = '22222222-2222-2222-2222-222222222222'
    Author = 'Test'
    FunctionsToExport = @('Get-ShadowValue')
}
'@ | Set-Content -Path (Join-Path -Path $oldShadowInstallPath -ChildPath 'ShadowModule.psd1')

    $shadowSourcePath = Join-Path -Path $testRoot -ChildPath 'ShadowModule'
    New-Item -Path $shadowSourcePath -ItemType Directory -Force | Out-Null
    "function Get-ShadowValue { 'new-2.0.0' }" |
        Set-Content -Path (Join-Path -Path $shadowSourcePath -ChildPath 'ShadowModule.psm1')
    @'
@{
    RootModule = 'ShadowModule.psm1'
    ModuleVersion = '2.0.0'
    GUID = '33333333-3333-3333-3333-333333333333'
    Author = 'Test'
    FunctionsToExport = @('Get-ShadowValue')
}
'@ | Set-Content -Path (Join-Path -Path $shadowSourcePath -ChildPath 'ShadowModule.psd1')

    $oldShadowManifestPath = Join-Path -Path $oldShadowInstallPath -ChildPath 'ShadowModule.psd1'
    Import-Module -Name $oldShadowManifestPath -Force
    & $assert ((Get-ShadowValue) -eq 'old-999') 'Expected the fixture to preload the placeholder module.'

    $shadowInstalledPath = Install-PSModule -Path $shadowSourcePath -PassThru
    $expectedShadowPath = Join-Path -Path $shadowInstallRoot -ChildPath '2.0.0'
    $shadowCommand = Get-Command -Name Get-ShadowValue
    $returnedShadowPath = [System.IO.Path]::GetFullPath($shadowInstalledPath)
    $expectedShadowFullPath = [System.IO.Path]::GetFullPath($expectedShadowPath)

    & $assert ($returnedShadowPath -eq $expectedShadowFullPath) 'Expected the shadowed module under version 2.0.0.'
    & $assert ((Get-ShadowValue) -eq 'new-2.0.0') 'Expected the real-version command to replace the preloaded 999.0.0 command.'
    & $assert ($shadowCommand.Version.ToString() -eq '2.0.0') 'Expected command resolution to point at version 2.0.0.'

    Remove-Module -Name ShadowModule -Force -ErrorAction SilentlyContinue

    $badSourcePath = Join-Path -Path $testRoot -ChildPath 'BadModule'
    New-Item -Path $badSourcePath -ItemType Directory -Force | Out-Null
    "function Get-BadValue { 'bad' }" |
        Set-Content -Path (Join-Path -Path $badSourcePath -ChildPath 'BadModule.psm1')
    @'
@{
    RootModule = 'BadModule.psm1'
    ModuleVersion = '1.0/bad'
    GUID = '44444444-4444-4444-4444-444444444444'
    Author = 'Test'
    FunctionsToExport = @('Get-BadValue')
}
'@ | Set-Content -Path (Join-Path -Path $badSourcePath -ChildPath 'BadModule.psd1')

    $invalidVersionRejected = $false
    try {
        Install-PSModule -Path $badSourcePath
    } catch {
        $invalidVersionRejected = $_.Exception.Message -like '*is not a valid version*'
    }

    & $assert $invalidVersionRejected 'Expected malformed ModuleVersion values to be rejected.'
} finally {
    $env:PSModulePath = $originalPSModulePath
    Remove-Module -Name Helpers, RealVersionModule, ShadowModule, BadModule -Force -ErrorAction SilentlyContinue
    if (Test-Path -Path $testRoot) {
        Remove-Item -Path $testRoot -Recurse -Force
    }
}
