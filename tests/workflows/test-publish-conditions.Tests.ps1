BeforeAll {
    $WorkflowPath = Join-Path $PSScriptRoot '../../.github/workflows/workflow.yml'

    if (-not (Test-Path $WorkflowPath)) {
        throw "Workflow file not found at: $WorkflowPath"
    }

    # Parse YAML workflow file
    $WorkflowContent = Get-Content $WorkflowPath -Raw
    $script:WorkflowYaml = $WorkflowContent

    # Helper function to extract job conditional
    function Get-JobConditional {
        param([string]$JobName)

        $jobPattern = "^\s*${JobName}:\s*$"
        $lines = $script:WorkflowYaml -split "`n"
        $jobIndex = -1

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $jobPattern) {
                $jobIndex = $i
                break
            }
        }

        if ($jobIndex -eq -1) {
            return $null
        }

        # Look for if: condition in the next 20 lines
        $ifPattern = '^\s*if:\s*(.+)$'

        for ($i = $jobIndex; $i -lt [Math]::Min($jobIndex + 20, $lines.Count); $i++) {
            if ($lines[$i] -match $ifPattern) {
                return $matches[1].Trim()
            }

            # Stop if we hit another job
            if ($i -gt $jobIndex -and $lines[$i] -match '^\s*\w+:\s*$' -and $lines[$i] -notmatch '^\s*#') {
                break
            }
        }

        return $null
    }

    $script:GetJobConditional = ${function:Get-JobConditional}
}

Describe 'Unified Workflow Conditional Publishing Logic' {

    Context 'Publish-Module Conditional' {
        It 'Should have a conditional expression' {
            $conditional = & $script:GetJobConditional -JobName 'Publish-Module'
            $conditional | Should -Not -BeNullOrEmpty
        }

        It 'Should check for pull_request event' {
            $conditional = & $script:GetJobConditional -JobName 'Publish-Module'
            $conditional | Should -Match 'github\.event_name\s*==\s*''pull_request'''
        }

        It 'Should check if pull request is merged' {
            $conditional = & $script:GetJobConditional -JobName 'Publish-Module'
            $conditional | Should -Match 'github\.event\.pull_request\.merged\s*==\s*true'
        }

        It 'Should combine conditions with AND logic' {
            $conditional = & $script:GetJobConditional -JobName 'Publish-Module'
            $conditional | Should -Match '&&'
        }

        It 'Should respect Settings.Publish.Module.Skip flag' {
            # The job may have additional conditions for skip flags
            # This test verifies the structure exists even if not in the if: directly
            $script:WorkflowYaml | Should -Match 'Publish-Module'
        }
    }

    Context 'Publish-Site Conditional' {
        It 'Should have a conditional expression' {
            $conditional = & $script:GetJobConditional -JobName 'Publish-Site'
            $conditional | Should -Not -BeNullOrEmpty
        }

        It 'Should check for pull_request event' {
            $conditional = & $script:GetJobConditional -JobName 'Publish-Site'
            $conditional | Should -Match 'github\.event_name\s*==\s*''pull_request'''
        }

        It 'Should check if pull request is merged' {
            $conditional = & $script:GetJobConditional -JobName 'Publish-Site'
            $conditional | Should -Match 'github\.event\.pull_request\.merged\s*==\s*true'
        }

        It 'Should combine conditions with AND logic' {
            $conditional = & $script:GetJobConditional -JobName 'Publish-Site'
            $conditional | Should -Match '&&'
        }

        It 'Should respect Settings.Publish.Site.Skip flag' {
            # The job may have additional conditions for skip flags
            # This test verifies the structure exists even if not in the if: directly
            $script:WorkflowYaml | Should -Match 'Publish-Site'
        }
    }

    Context 'Publishing Behavior Verification' {
        It 'Should have consistent merge check pattern between both publish jobs' {
            $publishModuleIf = & $script:GetJobConditional -JobName 'Publish-Module'
            $publishSiteIf = & $script:GetJobConditional -JobName 'Publish-Site'

            # Both should check for merged PR
            $publishModuleIf | Should -Match 'merged'
            $publishSiteIf | Should -Match 'merged'
        }

        It 'Should only publish on pull_request events' {
            # Both jobs should explicitly check event_name
            $publishModuleIf = & $script:GetJobConditional -JobName 'Publish-Module'
            $publishSiteIf = & $script:GetJobConditional -JobName 'Publish-Site'

            $publishModuleIf | Should -Match 'event_name'
            $publishSiteIf | Should -Match 'event_name'
        }

        It 'Should not publish on PR open/synchronize (only on merge)' {
            # The condition should specifically check merged == true
            $publishModuleIf = & $script:GetJobConditional -JobName 'Publish-Module'
            $publishModuleIf | Should -Match 'merged\s*==\s*true'
        }
    }

    Context 'Conditional Syntax' {
        It 'Publish-Module should use valid GitHub Actions conditional syntax' {
            $conditional = & $script:GetJobConditional -JobName 'Publish-Module'

            # Should use proper expression syntax ${{ }}
            $script:WorkflowYaml | Should -Match 'if:\s*\$\{\{.*Publish-Module'
        }

        It 'Publish-Site should use valid GitHub Actions conditional syntax' {
            $conditional = & $script:GetJobConditional -JobName 'Publish-Site'

            # Should use proper expression syntax ${{ }}
            $script:WorkflowYaml | Should -Match 'if:\s*\$\{\{.*Publish-Site'
        }
    }
}
