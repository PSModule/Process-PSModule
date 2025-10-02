BeforeAll {
    $WorkflowPath = Join-Path $PSScriptRoot '../../.github/workflows/workflow.yml'

    if (-not (Test-Path $WorkflowPath)) {
        throw "Workflow file not found at: $WorkflowPath"
    }

    # Parse YAML workflow file
    $WorkflowContent = Get-Content $WorkflowPath -Raw
    $script:WorkflowYaml = $WorkflowContent

    # Helper function to check if a job depends on another
    function Test-JobDependency {
        param(
            [string]$JobName,
            [string[]]$ExpectedDependencies
        )

        # Find the job section
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
            return @{
                Found        = $false
                Dependencies = @()
            }
        }

        # Look for needs: in the next few lines
        $needsPattern = '^\s*needs:\s*'
        $foundDependencies = @()

        for ($i = $jobIndex; $i -lt [Math]::Min($jobIndex + 20, $lines.Count); $i++) {
            $line = $lines[$i]

            # Check for needs with array
            if ($line -match $needsPattern) {
                # Could be single line or multi-line
                if ($line -match 'needs:\s*\[([^\]]+)\]') {
                    $foundDependencies = $matches[1] -split ',' | ForEach-Object { $_.Trim() }
                    break
                } elseif ($line -match 'needs:\s*(\S+)') {
                    $foundDependencies = @($matches[1])
                    break
                } else {
                    # Multi-line array format
                    for ($j = $i + 1; $j -lt [Math]::Min($i + 10, $lines.Count); $j++) {
                        if ($lines[$j] -match '^\s*-\s*(\S+)') {
                            $foundDependencies += $matches[1]
                        } elseif ($lines[$j] -match '^\s*\w+:') {
                            # Next property, stop looking
                            break
                        }
                    }
                    break
                }
            }

            # Stop if we hit another job
            if ($i -gt $jobIndex -and $line -match '^\s*\w+:\s*$' -and $line -notmatch '^\s*#') {
                break
            }
        }

        return @{
            Found        = $true
            Dependencies = $foundDependencies
        }
    }

    $script:TestJobDependency = ${function:Test-JobDependency}
}

Describe 'Unified Workflow Job Execution Order' {

    Context 'Get-Settings Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Get-Settings:\s*$'
        }

        It 'Should have no dependencies' {
            $result = & $script:TestJobDependency -JobName 'Get-Settings' -ExpectedDependencies @()
            $result.Found | Should -Be $true
            $result.Dependencies | Should -BeNullOrEmpty
        }
    }

    Context 'Build-Module Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Build-Module:\s*$'
        }

        It 'Should depend on Get-Settings' {
            $result = & $script:TestJobDependency -JobName 'Build-Module'
            $result.Found | Should -Be $true
            $result.Dependencies | Should -Contain 'Get-Settings'
        }
    }

    Context 'Build-Docs Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Build-Docs:\s*$'
        }

        It 'Should depend on Get-Settings and Build-Module' {
            $result = & $script:TestJobDependency -JobName 'Build-Docs'
            $result.Found | Should -Be $true
            $result.Dependencies | Should -Contain 'Get-Settings'
            $result.Dependencies | Should -Contain 'Build-Module'
        }
    }

    Context 'Build-Site Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Build-Site:\s*$'
        }

        It 'Should depend on Get-Settings and Build-Docs' {
            $result = & $script:TestJobDependency -JobName 'Build-Site'
            $result.Found | Should -Be $true
            $result.Dependencies | Should -Contain 'Get-Settings'
            $result.Dependencies | Should -Contain 'Build-Docs'
        }
    }

    Context 'Test-SourceCode Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Test-SourceCode:\s*$'
        }

        It 'Should depend on Get-Settings' {
            $result = & $script:TestJobDependency -JobName 'Test-SourceCode'
            $result.Found | Should -Be $true
            $result.Dependencies | Should -Contain 'Get-Settings'
        }
    }

    Context 'Lint-SourceCode Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Lint-SourceCode:\s*$'
        }

        It 'Should depend on Get-Settings' {
            $result = & $script:TestJobDependency -JobName 'Lint-SourceCode'
            $result.Found | Should -Be $true
            $result.Dependencies | Should -Contain 'Get-Settings'
        }
    }

    Context 'Test-Module Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Test-Module:\s*$'
        }

        It 'Should depend on Get-Settings and Build-Module' {
            $result = & $script:TestJobDependency -JobName 'Test-Module'
            $result.Found | Should -Be $true
            $result.Dependencies | Should -Contain 'Get-Settings'
            $result.Dependencies | Should -Contain 'Build-Module'
        }
    }

    Context 'Test-ModuleLocal Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Test-ModuleLocal:\s*$'
        }

        It 'Should depend on Get-Settings and Build-Module' {
            $result = & $script:TestJobDependency -JobName 'Test-ModuleLocal'
            $result.Found | Should -Be $true
            $result.Dependencies | Should -Contain 'Get-Settings'
            $result.Dependencies | Should -Contain 'Build-Module'
        }
    }

    Context 'Get-TestResults Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Get-TestResults:\s*$'
        }

        It 'Should depend on all test jobs' {
            $result = & $script:TestJobDependency -JobName 'Get-TestResults'
            $result.Found | Should -Be $true

            # Should depend on at least Test-Module and Test-ModuleLocal
            # Test-SourceCode and Lint-SourceCode are conditional
            $result.Dependencies | Should -Contain 'Test-Module'
            $result.Dependencies | Should -Contain 'Test-ModuleLocal'
        }
    }

    Context 'Get-CodeCoverage Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Get-CodeCoverage:\s*$'
        }

        It 'Should depend on Get-TestResults' {
            $result = & $script:TestJobDependency -JobName 'Get-CodeCoverage'
            $result.Found | Should -Be $true
            $result.Dependencies | Should -Contain 'Get-TestResults'
        }
    }

    Context 'Publish-Module Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Publish-Module:\s*$'
        }

        It 'Should depend on Build-Module and Get-TestResults' {
            $result = & $script:TestJobDependency -JobName 'Publish-Module'
            $result.Found | Should -Be $true
            $result.Dependencies | Should -Contain 'Build-Module'
            $result.Dependencies | Should -Contain 'Get-TestResults'
        }
    }

    Context 'Publish-Site Job' {
        It 'Should exist' {
            $script:WorkflowYaml | Should -Match '^\s*Publish-Site:\s*$'
        }

        It 'Should depend on Build-Site and Get-TestResults' {
            $result = & $script:TestJobDependency -JobName 'Publish-Site'
            $result.Found | Should -Be $true
            $result.Dependencies | Should -Contain 'Build-Site'
            $result.Dependencies | Should -Contain 'Get-TestResults'
        }
    }
}
