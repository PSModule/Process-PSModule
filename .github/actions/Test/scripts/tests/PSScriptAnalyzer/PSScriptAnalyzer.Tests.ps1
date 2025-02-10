[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', 'Path',
    Justification = 'Path is being used.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', 'SettingsFilePath',
    Justification = 'SettingsFilePath is being used.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'relativeSettingsFilePath',
    Justification = 'relativeSettingsFilePath is being used.'
)]
[CmdLetBinding()]
Param(
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter(Mandatory)]
    [string] $SettingsFilePath
)

BeforeDiscovery {
    $rules = [Collections.Generic.List[System.Collections.Specialized.OrderedDictionary]]::new()
    $ruleObjects = Get-ScriptAnalyzerRule -Verbose:$false | Sort-Object -Property Severity, CommonName
    foreach ($ruleObject in $ruleObjects) {
        $rules.Add(
            [ordered]@{
                RuleName    = $ruleObject.RuleName
                CommonName  = $ruleObject.CommonName
                Severity    = $ruleObject.Severity
                Description = $ruleObject.Description
            }
        )
    }
    Write-Warning "Discovered [$($rules.Count)] rules"
    $relativeSettingsFilePath = $SettingsFilePath.Replace($PSScriptRoot, '').Trim('\').Trim('/')
}

Describe "PSScriptAnalyzer tests using settings file [$relativeSettingsFilePath]" {
    BeforeAll {
        $testResults = Invoke-ScriptAnalyzer -Path $Path -Settings $SettingsFilePath -Recurse -Verbose:$false
        Write-Warning "Found [$($testResults.Count)] issues"
    }

    Context 'Severity: <_>' -ForEach 'Error', 'Warning', 'Information' {
        It '<CommonName> (<RuleName>)' -ForEach ($rules | Where-Object -Property Severity -EQ $_) {
            $issues = [Collections.Generic.List[string]]::new()
            $testResults | Where-Object -Property RuleName -EQ $RuleName | ForEach-Object {
                $relativePath = $_.ScriptPath.Replace($Path, '').Trim('\').Trim('/')
                $issues.Add(([Environment]::NewLine + " - $relativePath`:L$($_.Line):C$($_.Column)"))
            }
            $issues -join '' | Should -BeNullOrEmpty -Because $Description
        }
    }
}
