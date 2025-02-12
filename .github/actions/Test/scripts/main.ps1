[CmdletBinding()]
param()

$path = (Join-Path -Path $PSScriptRoot -ChildPath 'helpers')
LogGroup "Loading helper scripts from [$path]" {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | ForEach-Object {
        Write-Host " - $($_.FullName)"
        . $_.FullName
    }
}

LogGroup 'Loading inputs' {
    $moduleName = ($env:GITHUB_ACTION_INPUT_Name | IsNullOrEmpty) ? $env:GITHUB_REPOSITORY_NAME : $env:GITHUB_ACTION_INPUT_Name
    $codeToTest = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath "$env:GITHUB_ACTION_INPUT_Path\$moduleName"
    if (-not (Test-Path -Path $codeToTest)) {
        $codeToTest = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $env:GITHUB_ACTION_INPUT_Path
    }
    if (-not (Test-Path -Path $codeToTest)) {
        throw "Path [$codeToTest] does not exist."
    }

    if (-not (Test-Path -Path $env:GITHUB_ACTION_INPUT_TestsPath)) {
        throw "Path [$env:GITHUB_ACTION_INPUT_TestsPath] does not exist."
    }

    [pscustomobject]@{
        ModuleName          = $moduleName
        CodeToTest          = $codeToTest
        TestType            = $env:GITHUB_ACTION_INPUT_TestType
        TestsPath           = $env:GITHUB_ACTION_INPUT_TestsPath
        StackTraceVerbosity = $env:GITHUB_ACTION_INPUT_StackTraceVerbosity
        Verbosity           = $env:GITHUB_ACTION_INPUT_Verbosity
    } | Format-List
}

$params = @{
    Path                = $codeToTest
    TestType            = $env:GITHUB_ACTION_INPUT_TestType
    TestsPath           = $env:GITHUB_ACTION_INPUT_TestsPath
    StackTraceVerbosity = $env:GITHUB_ACTION_INPUT_StackTraceVerbosity
    Verbosity           = $env:GITHUB_ACTION_INPUT_Verbosity
}
$testResults = Test-PSModule @params

LogGroup 'Test results' {
    $testResults | Format-List
}

$failedTests = [int]$testResults.FailedCount

if (($failedTests -gt 0) -or ($testResults.Result -ne 'Passed')) {
    Write-GitHubError "❌ Some [$failedTests] tests failed."
    Set-GitHubOutput -Name 'passed' -Value $false
    $return = 1
} elseif ($failedTests -eq 0) {
    Write-GitHubNotice '✅ All tests passed.'
    Set-GitHubOutput -Name 'passed' -Value $true
    $return = 0
}

Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
exit $return
