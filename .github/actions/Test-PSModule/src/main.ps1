[CmdletBinding()]
param()

$env:GITHUB_REPOSITORY_NAME = $env:GITHUB_REPOSITORY -replace '.+/'
$moduleName = if ([string]::IsNullOrEmpty($env:PSMODULE_TEST_PSMODULE_INPUT_Name)) {
    $env:GITHUB_REPOSITORY_NAME
} else {
    $env:PSMODULE_TEST_PSMODULE_INPUT_Name
}
$settings = $env:PSMODULE_TEST_PSMODULE_INPUT_Settings
$testPath = Resolve-Path -Path "$PSScriptRoot/tests/$settings" | Select-Object -ExpandProperty Path

$localTestPath = Resolve-Path -Path 'tests' | Select-Object -ExpandProperty Path
switch ($settings) {
    'Module' {
        $modulePath = Resolve-Path -Path "outputs/module/$moduleName" | Select-Object -ExpandProperty Path
        $codePath = Install-PSModule -Path $modulePath -PassThru
    }
    'SourceCode' {
        $codePath = Resolve-Path -Path 'src' | Select-Object -ExpandProperty Path
    }
    default {
        throw "Invalid test type: [$settings]"
    }
}

[pscustomobject]@{
    ModuleName    = $moduleName
    Settings      = $settings
    CodePath      = $codePath
    LocalTestPath = $localTestPath
    TestPath      = $testPath
} | Format-List | Out-String

"ModuleName=$moduleName" >> $env:GITHUB_OUTPUT
"CodePath=$codePath" >> $env:GITHUB_OUTPUT
"LocalTestPath=$localTestPath" >> $env:GITHUB_OUTPUT
"TestPath=$testPath" >> $env:GITHUB_OUTPUT
