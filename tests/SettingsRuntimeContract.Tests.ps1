[CmdletBinding()]
param()

Describe 'Runtime settings contract' {
    BeforeAll {
        $repoRoot = (Get-Location).Path
        $workflowFile = Join-Path $repoRoot '.github/workflows/workflow.yml'
        $planFile = Join-Path $repoRoot '.github/workflows/Plan.yml'
        $settingsActionFile = Join-Path $repoRoot '.github/actions/Get-PSModuleSettings/src/main.ps1'
    }

    It 'does not use legacy root Run flags in workflow dispatch conditions' {
        $workflowContent = Get-Content -Path $workflowFile -Raw
        $workflowContent | Should -Not -Match '\.Run\.'
    }

    It 'uses phase-owned test suites for workflow matrices' {
        $workflowFiles = @(
            '.github/workflows/Test-SourceCode.yml',
            '.github/workflows/Lint-SourceCode.yml',
            '.github/workflows/Test-Module.yml',
            '.github/workflows/Test-ModuleLocal.yml',
            '.github/workflows/Get-TestResults.yml'
        ) | ForEach-Object { Join-Path $repoRoot $_ }

        foreach ($file in $workflowFiles) {
            $content = Get-Content -Path $file -Raw
            $content | Should -Not -Match '\.TestSuites\.'
        }
    }

    It 'stores resolved version metadata in Publish.Module.Resolution' {
        $planContent = Get-Content -Path $planFile -Raw
        $planContent | Should -Match 'Publish\.Module \| Add-Member -MemberType NoteProperty -Name Resolution'
    }

    It 'keeps phase execution state in owned objects, not root Run' {
        $settingsContent = Get-Content -Path $settingsActionFile -Raw
        $settingsContent | Should -Not -Match 'Add-Member -MemberType NoteProperty -Name Run'
        $settingsContent | Should -Match 'Linter\.Repository'
        $settingsContent | Should -Match 'Build\.Module'
        $settingsContent | Should -Match 'Test\.SourceCode'
        $settingsContent | Should -Match 'Publish\.Module'
    }
}
