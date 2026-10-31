[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are assigned in BeforeAll and used inside It blocks.'
)]
[CmdletBinding()]
param()

BeforeAll {
    $script:environmentMutex = [Threading.Mutex]::new($false, "PSModule-ActionTests-Environment-$PID")
    if (-not $script:environmentMutex.WaitOne([TimeSpan]::FromMinutes(5))) {
        throw 'Cannot acquire the process environment lock for action tests.'
    }
    Import-Module -Name PSModule -Force
    $script:cleanupScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/cleanup.ps1'
    $script:environmentNames = @(
        'GITHUB_REPOSITORY'
        'GITHUB_EVENT_PATH'
        'PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_PullRequest'
        'PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_WhatIf'
        'PSMODULE_CLEANUP_PSMODULEPRERELEASES_CONTEXT_ReleaseTag'
    )
    $script:originalEnvironment = @{}
    foreach ($name in $script:environmentNames) {
        $script:originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
}

AfterAll {
    try {
        foreach ($name in $script:environmentNames) {
            [Environment]::SetEnvironmentVariable($name, $script:originalEnvironment[$name])
        }
        Remove-Item -Path 'Function:\gh' -ErrorAction SilentlyContinue
    } finally {
        $script:environmentMutex.ReleaseMutex()
        $script:environmentMutex.Dispose()
    }
}

Describe 'Cleanup-PSModulePrereleases ownership' {
    BeforeEach {
        $script:state = @{
            Calls    = [System.Collections.Generic.List[string]]::new()
            Releases = @(
                [pscustomobject]@{
                    tagName = 'v1.2.4-featurea001'; isPrerelease = $true; targetCommitish = 'feature/a'
                }
                [pscustomobject]@{
                    tagName = 'v1.2.4-featureab001'; isPrerelease = $true; targetCommitish = 'feature/ab'
                }
                [pscustomobject]@{
                    tagName = 'v1.2.4-featurea002'; isPrerelease = $true; targetCommitish = 'feature-a'
                }
                [pscustomobject]@{
                    tagName = 'v1.2.4-featurea003'; isPrerelease = $true; targetCommitish = 'feature/a'
                }
                [pscustomobject]@{
                    tagName = 'v1.2.4'; isPrerelease = $false; targetCommitish = 'feature/a'
                }
            )
        }
        $state = $script:state
        Set-Item -Path 'Function:global:gh' -Value {
            [CmdletBinding()]
            param(
                [Parameter(ValueFromRemainingArguments)]
                [string[]] $Arguments
            )

            $state.Calls.Add($Arguments -join ' ')
            $global:LASTEXITCODE = 0
            if ($Arguments[0] -eq 'api' -and $Arguments[1] -match '/pulls/') {
                'PSModule/CleanupFixture'
            } elseif ($Arguments[0] -eq 'api' -or ($Arguments[0] -eq 'release' -and $Arguments[1] -eq 'list')) {
                $state.Releases | ConvertTo-Json -Compress
            }
        }.GetNewClosure()
        $eventPath = Join-Path -Path $TestDrive -ChildPath 'dispatch.json'
        @{} | ConvertTo-Json | Set-Content -LiteralPath $eventPath
        $env:GITHUB_EVENT_PATH = $eventPath
        $env:GITHUB_REPOSITORY = 'PSModule/CleanupFixture'
        $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_PullRequest = @{
            Number = 42; HeadRef = 'feature/a'
            HeadRepository = 'PSModule/CleanupFixture'
        } | ConvertTo-Json
        $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_WhatIf = 'true'
        $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_CONTEXT_ReleaseTag = 'v1.2.4-featurea003'
    }

    It 'does not preview deleting another branch or a sanitized-name collision during a dispatch' {
        $output = & $script:cleanupScriptPath 6>&1 | Out-String

        $output | Should -Match 'release delete.*v1\.2\.4-featurea001'
        $output | Should -Not -Match 'release delete.*v1\.2\.4-featureab001'
        $output | Should -Not -Match 'release delete.*v1\.2\.4-featurea002'
        $output | Should -Not -Match 'release delete.*v1\.2\.4-featurea003'
        @($script:state.Calls | Where-Object { $_ -like 'release delete*' }).Count | Should -Be 0
    }

    It 'deletes only exact branch-owned prereleases and retains the published tag' {
        $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_WhatIf = 'false'

        & $script:cleanupScriptPath

        $deletions = @($script:state.Calls | Where-Object { $_ -like 'release delete*' })
        $deletions.Count | Should -Be 1
        $deletions[0] | Should -Match 'v1\.2\.4-featurea001'
        $deletions[0] | Should -Not -Match 'featureab|featurea002|featurea003'
    }

    It 'keeps numeric branch identifiers distinct from prerelease counters' {
        $script:state.Releases = @(
            [pscustomobject]@{
                tagName = 'v1.2.4-feature1001'; isPrerelease = $true; targetCommitish = 'feature/1'
            }
            [pscustomobject]@{
                tagName = 'v1.2.4-feature10001'; isPrerelease = $true; targetCommitish = 'feature/10'
            }
        )
        $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_PullRequest = @{
            Number = 42; HeadRef = 'feature/1'
            HeadRepository = 'PSModule/CleanupFixture'
        } | ConvertTo-Json

        $output = & $script:cleanupScriptPath 6>&1 | Out-String

        $output | Should -Match 'release delete.*v1\.2\.4-feature1001'
        $output | Should -Not -Match 'release delete.*v1\.2\.4-feature10001'
    }

    It 'does not clean base-repository prereleases for a fork with the same head ref' {
        $script:state.Releases = @([pscustomobject]@{
                tagName = 'v1.2.4-main001'; isPrerelease = $true; targetCommitish = 'main'
            })
        $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_PullRequest = @{
            Number = 42; HeadRef = 'main'; HeadRepository = 'AnotherOwner/Fork'
        } | ConvertTo-Json

        $output = & $script:cleanupScriptPath 6>&1 | Out-String

        $output | Should -Not -Match 'release delete.*v1\.2\.4-main001'
        @($script:state.Calls | Where-Object { $_ -like 'release delete*' }).Count | Should -Be 0
    }

    It 'resolves repository ownership for an older normalized PR payload' {
        $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_PullRequest = @{
            Number = 42; HeadRef = 'feature/a'
        } | ConvertTo-Json

        $output = & $script:cleanupScriptPath 6>&1 | Out-String

        $output | Should -Match 'release delete.*v1\.2\.4-featurea001'
        @($script:state.Calls | Where-Object { $_ -match '/pulls/42' }).Count | Should -Be 1
        $output | Should -Not -Match 'release delete.*v1\.2\.4-featureab001'
    }
}
