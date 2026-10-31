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
            Calls     = [System.Collections.Generic.List[string]]::new()
            TagSource = 'original-source-sha'
            Releases  = @(
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
        foreach ($release in $script:state.Releases) {
            $number = if ($release.tagName -in @('v1.2.4-featureab001', 'v1.2.4-featurea002')) { 43 } else { 42 }
            $owner = @{ Repository = 'PSModule/CleanupFixture'; PullRequest = $number; CommitSha = 'original-source-sha' } |
                ConvertTo-Json -Compress
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
            $release.targetCommitish = 'original-source-sha'
            $release | Add-Member -NotePropertyName body -NotePropertyValue "<!-- PSModule.PrereleaseOwner:v1:$encoded -->"
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
            } elseif ($Arguments[0] -eq 'api' -and $Arguments[1] -match '/git/ref/tags/') {
                @{ object = @{ type = 'commit'; sha = $state.TagSource } } | ConvertTo-Json -Compress
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
        foreach ($release in $script:state.Releases) {
            $number = if ($release.tagName -eq 'v1.2.4-feature1001') { 42 } else { 43 }
            $owner = @{ Repository = 'PSModule/CleanupFixture'; PullRequest = $number; CommitSha = 'original-source-sha' } |
                ConvertTo-Json -Compress
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
            $release.targetCommitish = 'original-source-sha'
            $release | Add-Member -NotePropertyName body -NotePropertyValue "<!-- PSModule.PrereleaseOwner:v1:$encoded -->"
        }
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

    It 'retains legacy releases whose producing PR cannot be established' {
        $script:state.Releases = @([pscustomobject]@{
                tagName = 'v1.2.4-featurea001'; isPrerelease = $true; targetCommitish = 'feature/a'
            })
        $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_PullRequest = @{
            Number = 42; HeadRef = 'feature/a'
        } | ConvertTo-Json

        $output = & $script:cleanupScriptPath 6>&1 | Out-String

        $output | Should -Not -Match 'release delete.*v1\.2\.4-featurea001'
        @($script:state.Calls | Where-Object { $_ -like 'release delete*' }).Count | Should -Be 0
        $output | Should -Not -Match 'release delete.*v1\.2\.4-featureab001'
    }

    It 'selects a SHA-targeted prerelease only from exact PR and source provenance for <HeadRepository>' -ForEach @(
        @{ HeadRepository = 'PSModule/CleanupFixture' }
        @{ HeadRepository = 'AnotherOwner/Fork' }
    ) {
        $owner = @{ Repository = 'PSModule/CleanupFixture'; PullRequest = 42; CommitSha = 'original-source-sha' } |
            ConvertTo-Json -Compress
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
        $foreign = @{ Repository = 'PSModule/CleanupFixture'; PullRequest = 43; CommitSha = 'original-source-sha' } |
            ConvertTo-Json -Compress
        $foreignEncoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($foreign))
        $script:state.Releases = @(
            [pscustomobject]@{
                tagName = 'v1.2.4-featurea001'; isPrerelease = $true; targetCommitish = 'original-source-sha'
                body = "Authored notes`n`n<!-- PSModule.PrereleaseOwner:v1:$encoded -->"
            }
            [pscustomobject]@{
                tagName = 'v1.2.4-featurea002'; isPrerelease = $true; targetCommitish = 'original-source-sha'
                body = "Authored notes`n`n<!-- PSModule.PrereleaseOwner:v1:$foreignEncoded -->"
            }
        )
        $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_PullRequest = @{
            Number = 42; HeadRef = 'feature/a'; HeadRepository = $HeadRepository
        } | ConvertTo-Json

        $output = & $script:cleanupScriptPath 6>&1 | Out-String

        $output | Should -Match 'release delete.*v1\.2\.4-featurea001'
        $output | Should -Not -Match 'release delete.*v1\.2\.4-featurea002'
    }

    It 'refuses cleanup when the tag has moved away from its recorded immutable source' {
        $owner = @{ Repository = 'PSModule/CleanupFixture'; PullRequest = 42; CommitSha = 'original-source-sha' } |
            ConvertTo-Json -Compress
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
        $script:state.Releases = @([pscustomobject]@{
                tagName = 'v1.2.4-featurea001'; isPrerelease = $true; targetCommitish = 'original-source-sha'
                body = "Notes`n`n<!-- PSModule.PrereleaseOwner:v1:$encoded -->"
            })
        $script:state.TagSource = 'another-source-sha'

        { & $script:cleanupScriptPath } | Should -Throw '*no longer matches*recorded source*'

        @($script:state.Calls | Where-Object { $_ -like 'release delete*' }).Count | Should -Be 0
    }
}
