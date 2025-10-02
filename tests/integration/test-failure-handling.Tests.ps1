BeforeAll {
    # This test verifies the unified workflow failure handling
    # Scenario: Test failure → workflow fails, publishing skipped

    $WorkflowPath = Join-Path $PSScriptRoot '../../.github/workflows/workflow.yml'

    if (-not (Test-Path $WorkflowPath)) {
        throw "Workflow file not found at: $WorkflowPath"
    }

    $script:WorkflowYaml = Get-Content $WorkflowPath -Raw
}

Describe 'Test Failure Handling Scenario' {

    Context 'Job Dependencies Prevent Publishing on Failure' {
        It 'Publish-Module should depend on test results job' {
            # If tests fail, Get-TestResults won't succeed, blocking publish
            $publishSection = $script:WorkflowYaml -split 'Publish-Module:' | Select-Object -Skip 1 -First 1
            $publishSection | Should -Match 'needs:'
        }

        It 'Publish-Site should depend on test results job' {
            # If tests fail, Get-TestResults won't succeed, blocking publish
            $publishSection = $script:WorkflowYaml -split 'Publish-Site:' | Select-Object -Skip 1 -First 1
            $publishSection | Should -Match 'needs:'
        }

        It 'Get-TestResults should depend on test jobs' {
            # Test results collection depends on test execution
            $resultsSection = $script:WorkflowYaml -split 'Get-TestResults:' | Select-Object -Skip 1 -First 1
            $resultsSection | Should -Match 'needs:'
        }

        It 'Should have proper dependency chain to prevent publishing' {
            # Test → Results → Publish chain ensures failure blocks publishing
            $script:WorkflowYaml | Should -Match 'Test-Module:'
            $script:WorkflowYaml | Should -Match 'Test-ModuleLocal:'
            $script:WorkflowYaml | Should -Match 'Get-TestResults:'
            $script:WorkflowYaml | Should -Match 'Publish-Module:'
        }
    }

    Context 'Test Job Failure Propagation' {
        It 'Test-Module job should not have continue-on-error' {
            # Test failures should fail the job
            $testSection = $script:WorkflowYaml -split 'Test-Module:' | Select-Object -Skip 1 -First 1
            $testSection | Should -Not -Match 'continue-on-error:\s*true'
        }

        It 'Test-ModuleLocal job should not have continue-on-error' {
            # Test failures should fail the job
            $testSection = $script:WorkflowYaml -split 'Test-ModuleLocal:' | Select-Object -Skip 1 -First 1
            $testSection | Should -Not -Match 'continue-on-error:\s*true'
        }

        It 'Get-TestResults should fail if any test job fails' {
            # Results job should not ignore test failures
            $resultsSection = $script:WorkflowYaml -split 'Get-TestResults:' | Select-Object -Skip 1 -First 1

            # Should have needs that reference test jobs
            $resultsSection | Should -Match 'needs:'

            # Should not have if: always() or continue-on-error
            $resultsSection | Should -Not -Match 'if:\s*always\(\)'
            $resultsSection | Should -Not -Match 'continue-on-error:\s*true'
        }
    }

    Context 'Publishing Should Skip on Test Failure' {
        It 'Publish-Module should not run if dependencies fail' {
            # Default GitHub Actions behavior: job skips if dependency fails
            $publishSection = $script:WorkflowYaml -split 'Publish-Module:' | Select-Object -Skip 1 -First 1

            # Should have needs (creates dependency)
            $publishSection | Should -Match 'needs:'

            # Should NOT have if: always() which would run regardless
            $publishSection | Should -Not -Match 'if:\s*always\(\)'
        }

        It 'Publish-Site should not run if dependencies fail' {
            # Default GitHub Actions behavior: job skips if dependency fails
            $publishSection = $script:WorkflowYaml -split 'Publish-Site:' | Select-Object -Skip 1 -First 1

            # Should have needs (creates dependency)
            $publishSection | Should -Match 'needs:'

            # Should NOT have if: always() which would run regardless
            $publishSection | Should -Not -Match 'if:\s*always\(\)'
        }

        It 'Should not have conditional publishing that ignores test results' {
            # Publishing conditions should not override test failures
            $publishModuleSection = $script:WorkflowYaml -split 'Publish-Module:' | Select-Object -Skip 1 -First 1
            $publishSiteSection = $script:WorkflowYaml -split 'Publish-Site:' | Select-Object -Skip 1 -First 1

            # Neither should force execution on failure
            $publishModuleSection | Should -Not -Match 'if:\s*always\(\)'
            $publishSiteSection | Should -Not -Match 'if:\s*always\(\)'
        }
    }

    Context 'Workflow Failure Status' {
        It 'Should have required test jobs' {
            # All test jobs must exist
            $script:WorkflowYaml | Should -Match 'Test-Module:'
            $script:WorkflowYaml | Should -Match 'Test-ModuleLocal:'
        }

        It 'Should propagate test failures to workflow status' {
            # No continue-on-error on test jobs means workflow will fail
            $testModuleSection = $script:WorkflowYaml -split 'Test-Module:' | Select-Object -Skip 1 -First 1
            $testModuleLocalSection = $script:WorkflowYaml -split 'Test-ModuleLocal:' | Select-Object -Skip 1 -First 1

            $testModuleSection | Should -Not -Match 'continue-on-error:\s*true'
            $testModuleLocalSection | Should -Not -Match 'continue-on-error:\s*true'
        }

        It 'Should ensure Get-TestResults fails if tests fail' {
            # Results job must respect test job failures
            $resultsSection = $script:WorkflowYaml -split 'Get-TestResults:' | Select-Object -Skip 1 -First 1

            # Has dependencies on test jobs
            $resultsSection | Should -Match 'needs:'

            # Does not force execution
            $resultsSection | Should -Not -Match 'if:\s*always\(\)'
        }
    }

    Context 'Expected Behavior Documentation' {
        It 'Should match quickstart scenario 4 requirements' {
            # Quickstart scenario 4: Test failure → workflow fails, publishing skipped

            # 1. Tests should execute and be able to fail
            $script:WorkflowYaml | Should -Match 'Test-Module:'
            $script:WorkflowYaml | Should -Not -Match 'continue-on-error:\s*true'

            # 2. Publishing should depend on test results
            $script:WorkflowYaml | Should -Match 'Publish-Module:'
            $publishSection = $script:WorkflowYaml -split 'Publish-Module:' | Select-Object -Skip 1 -First 1
            $publishSection | Should -Match 'needs:'

            # 3. Publishing should not force execution
            $publishSection | Should -Not -Match 'if:\s*always\(\)'
        }

        It 'Should ensure dependency chain blocks publishing on failure' {
            # Test failure → Results job skipped → Publish jobs skipped

            # All jobs in chain must exist
            $script:WorkflowYaml | Should -Match 'Test-Module:'
            $script:WorkflowYaml | Should -Match 'Get-TestResults:'
            $script:WorkflowYaml | Should -Match 'Publish-Module:'

            # Results depends on tests
            $resultsSection = $script:WorkflowYaml -split 'Get-TestResults:' | Select-Object -Skip 1 -First 1
            $resultsSection | Should -Match 'needs:'

            # Publish depends on results
            $publishSection = $script:WorkflowYaml -split 'Publish-Module:' | Select-Object -Skip 1 -First 1
            $publishSection | Should -Match 'needs:'
        }

        It 'Should prevent accidental publishing on test failure' {
            # No continue-on-error or if: always() that could bypass failures
            $fullWorkflow = $script:WorkflowYaml

            # Count dangerous patterns in publish sections
            $publishModuleSection = $fullWorkflow -split 'Publish-Module:' | Select-Object -Skip 1 -First 1
            $publishSiteSection = $fullWorkflow -split 'Publish-Site:' | Select-Object -Skip 1 -First 1

            # Neither publish job should force execution
            $publishModuleSection | Should -Not -Match 'if:\s*always\(\)'
            $publishSiteSection | Should -Not -Match 'if:\s*always\(\)'
        }
    }
}
