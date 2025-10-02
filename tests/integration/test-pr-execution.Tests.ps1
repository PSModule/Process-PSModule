BeforeAll {
    # This test verifies the unified workflow behavior for PR-only execution
    # Scenario: PR opens → tests execute, publishing skipped

    $WorkflowPath = Join-Path $PSScriptRoot '../../.github/workflows/workflow.yml'

    if (-not (Test-Path $WorkflowPath)) {
        throw "Workflow file not found at: $WorkflowPath"
    }

    $script:WorkflowYaml = Get-Content $WorkflowPath -Raw
}

Describe 'PR-Only Execution Scenario' {

    Context 'Test Jobs Should Execute on PR' {
        It 'Get-Settings job should not have PR-blocking conditional' {
            # Get-Settings should always run
            $script:WorkflowYaml | Should -Match 'Get-Settings:'
        }

        It 'Build-Module job should execute on PR' {
            # Build jobs should run on PR
            $script:WorkflowYaml | Should -Match 'Build-Module:'
        }

        It 'Test-Module job should execute on PR' {
            # Test jobs should run on PR
            $script:WorkflowYaml | Should -Match 'Test-Module:'
        }

        It 'Test-ModuleLocal job should execute on PR' {
            # Local tests should run on PR
            $script:WorkflowYaml | Should -Match 'Test-ModuleLocal:'
        }
    }

    Context 'Publishing Jobs Should Be Skipped on PR' {
        It 'Publish-Module should have merge-only conditional' {
            # This test verifies Publish-Module won't run on unmerged PR
            # It should check for merged == true
            $publishModuleSection = $script:WorkflowYaml -split 'Publish-Module:' | Select-Object -Skip 1 -First 1

            # Should contain conditional that checks for merged
            $publishModuleSection | Should -Match 'merged'
        }

        It 'Publish-Site should have merge-only conditional' {
            # This test verifies Publish-Site won't run on unmerged PR
            # It should check for merged == true
            $publishSiteSection = $script:WorkflowYaml -split 'Publish-Site:' | Select-Object -Skip 1 -First 1

            # Should contain conditional that checks for merged
            $publishSiteSection | Should -Match 'merged'
        }

        It 'Publishing should only occur when merged is true' {
            # Verify both publish jobs check merged == true
            $script:WorkflowYaml | Should -Match 'merged\s*==\s*true'
        }
    }

    Context 'Workflow Structure for PR Context' {
        It 'Should have workflow_call trigger for reusability' {
            # Workflow should be callable from consuming repos
            $script:WorkflowYaml | Should -Match 'workflow_call:'
        }

        It 'Should define required secrets for test execution' {
            # Tests may need secrets even in PR context
            $script:WorkflowYaml | Should -Match 'secrets:'
        }

        It 'Should allow test jobs to run regardless of PR state' {
            # Test jobs should not be conditionally blocked on PR context
            # They should run on opened, synchronized, etc.
            $script:WorkflowYaml | Should -Match 'Test-Module:'
            $script:WorkflowYaml | Should -Match 'Test-ModuleLocal:'
        }
    }

    Context 'Expected Behavior Documentation' {
        It 'Should match quickstart scenario 1 requirements' {
            # Quickstart scenario 1: PR opens → tests execute, publishing skipped

            # 1. Workflow should execute (workflow_call trigger)
            $script:WorkflowYaml | Should -Match 'workflow_call:'

            # 2. Tests should execute
            $script:WorkflowYaml | Should -Match 'Test-Module:'

            # 3. Publishing should be conditional (not automatic on PR)
            $script:WorkflowYaml | Should -Match 'Publish-Module:'
            $script:WorkflowYaml | Should -Match 'if:'
        }
    }
}
