#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are used across Pester BeforeAll/It blocks.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
    Justification = 'Parameters in LogGroup mock are required by the caller signature.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideCommentHelp', '',
    Justification = 'LogGroup is a test helper mock, not a public function.')]
param()

# Load test data at script scope so it is available during Pester discovery (-ForEach)
$TestData = Import-PowerShellDataFile -Path "$PSScriptRoot/Resolve-PSModuleVersion.Helpers.Tests.Data.psd1"

BeforeAll {
    # Install PSSemVer for version handling
    if (-not (Get-Module -ListAvailable -Name PSSemVer)) {
        Install-PSResource -Name PSSemVer -Repository PSGallery -TrustRepository -Scope CurrentUser
    }
    Import-Module -Name PSSemVer -Force

    # Mock LogGroup so module functions execute their blocks without console decoration
    function LogGroup {
        param([string]$Name, [scriptblock]$ScriptBlock)
        & $ScriptBlock
    }

    # Import the module under test
    Import-Module -Name "$PSScriptRoot/../scripts/Resolve-PSModuleVersion.Helpers.psm1" -Force
}

Describe 'Resolve-ReleaseDecision' {
    BeforeAll {
        $baseConfig = [PSCustomObject]@{
            AutoPatching          = $false
            IncrementalPrerelease = $false
            DatePrereleaseFormat  = ''
            VersionPrefix         = 'v'
            ReleaseType           = 'Release'
            IgnoreLabels          = @('skip-release')
            MajorLabels           = @('major')
            MinorLabels           = @('minor')
            PatchLabels           = @('patch')
        }
    }

    Context '<Name>' -ForEach $TestData.ReleaseDecision {
        BeforeAll {
            $config = [PSCustomObject]@{
                AutoPatching          = $AutoPatching
                IncrementalPrerelease = $baseConfig.IncrementalPrerelease
                DatePrereleaseFormat  = $baseConfig.DatePrereleaseFormat
                VersionPrefix         = $baseConfig.VersionPrefix
                ReleaseType           = $ReleaseType
                IgnoreLabels          = $baseConfig.IgnoreLabels
                MajorLabels           = $baseConfig.MajorLabels
                MinorLabels           = $baseConfig.MinorLabels
                PatchLabels           = $baseConfig.PatchLabels
            }
            $pullRequest = [PSCustomObject]@{
                HeadRef = $HeadRef
                Labels  = $Labels
            }
            $result = Resolve-ReleaseDecision -Configuration $config -PullRequest $pullRequest
        }

        It 'ShouldPublish is <Expected.ShouldPublish>' {
            $result.ShouldPublish | Should -Be $Expected.ShouldPublish
        }
        It 'CreateRelease is <Expected.CreateRelease>' {
            $result.CreateRelease | Should -Be $Expected.CreateRelease
        }
        It 'CreatePrerelease is <Expected.CreatePrerelease>' {
            $result.CreatePrerelease | Should -Be $Expected.CreatePrerelease
        }
        It 'MajorRelease is <Expected.MajorRelease>' {
            $result.MajorRelease | Should -Be $Expected.MajorRelease
        }
        It 'MinorRelease is <Expected.MinorRelease>' {
            $result.MinorRelease | Should -Be $Expected.MinorRelease
        }
        It 'PatchRelease is <Expected.PatchRelease>' {
            $result.PatchRelease | Should -Be $Expected.PatchRelease
        }
        It 'HasVersionBump is <Expected.HasVersionBump>' {
            $result.HasVersionBump | Should -Be $Expected.HasVersionBump
        }
        It 'PrereleaseName is <Expected.PrereleaseName>' {
            $result.PrereleaseName | Should -Be $Expected.PrereleaseName
        }
    }
}

Describe 'Get-NextModuleVersion' {
    BeforeAll {
        Mock -CommandName Find-PSResource -ModuleName 'Resolve-PSModuleVersion.Helpers' -MockWith { @() }
        $emptyReleases = @([PSCustomObject]@{ tagName = 'v0.0.0'; isLatest = $false; isPrerelease = $false })
    }

    Context '<Name>' -ForEach $TestData.NextModuleVersion {
        BeforeAll {
            $config = [PSCustomObject]@{
                AutoPatching          = $false
                IncrementalPrerelease = $IncrementalPrerelease
                DatePrereleaseFormat  = $DatePrereleaseFormat
                VersionPrefix         = $VersionPrefix
                ReleaseType           = 'Release'
                IgnoreLabels          = @()
                MajorLabels           = @('major')
                MinorLabels           = @('minor')
                PatchLabels           = @('patch')
            }
            $decisionObj = [PSCustomObject]$Decision
            $latestVer = New-PSSemVer -Version $LatestVersion
            $result = Get-NextModuleVersion -LatestVersion $latestVer -Decision $decisionObj `
                -Configuration $config -ModuleName 'TestModule' -Releases $emptyReleases
        }

        It 'Version is <ExpectedVersion>' {
            "$($result.Major).$($result.Minor).$($result.Patch)" | Should -Be $ExpectedVersion
        }
        It 'Prerelease is <ExpectedPrerelease>' {
            if ([string]::IsNullOrEmpty($ExpectedPrerelease)) {
                $result.Prerelease | Should -BeNullOrEmpty
            } else {
                $result.Prerelease | Should -Be $ExpectedPrerelease
            }
        }
        It 'Prefix is <ExpectedPrefix>' {
            $result.Prefix | Should -Be $ExpectedPrefix
        }
    }
}

Describe 'End-to-end: Resolve-ReleaseDecision + Get-NextModuleVersion' {
    BeforeAll {
        Mock -CommandName Find-PSResource -ModuleName 'Resolve-PSModuleVersion.Helpers' -MockWith { @() }
        $emptyReleases = @([PSCustomObject]@{ tagName = 'v0.0.0'; isLatest = $false; isPrerelease = $false })
    }

    Context '<Name>' -ForEach $TestData.EndToEnd {
        BeforeAll {
            $config = [PSCustomObject]@{
                AutoPatching          = $AutoPatching
                IncrementalPrerelease = $IncrementalPrerelease
                DatePrereleaseFormat  = ''
                VersionPrefix         = $VersionPrefix
                ReleaseType           = $ReleaseType
                IgnoreLabels          = @('skip-release')
                MajorLabels           = @('major')
                MinorLabels           = @('minor')
                PatchLabels           = @('patch')
            }
            $pullRequest = [PSCustomObject]@{
                HeadRef = $HeadRef
                Labels  = $Labels
            }
            $decision = Resolve-ReleaseDecision -Configuration $config -PullRequest $pullRequest
            $latestVer = New-PSSemVer -Version $LatestVersion
            $newVersion = Get-NextModuleVersion -LatestVersion $latestVer -Decision $decision `
                -Configuration $config -ModuleName 'TestModule' -Releases $emptyReleases

            # Derive resolved release type the same way Write-ActionOutput does
            $resolvedReleaseType = if ($decision.ShouldPublish) {
                if ($decision.CreateRelease) { 'Release' } else { 'Prerelease' }
            } else {
                'None'
            }
        }

        It 'ShouldPublish is <ExpectedShouldPublish>' {
            $decision.ShouldPublish | Should -Be $ExpectedShouldPublish
        }
        It 'ReleaseType is <ExpectedReleaseType>' {
            $resolvedReleaseType | Should -Be $ExpectedReleaseType
        }
        It 'Version is <ExpectedVersion>' {
            "$($newVersion.Major).$($newVersion.Minor).$($newVersion.Patch)" | Should -Be $ExpectedVersion
        }
        It 'Prerelease is <ExpectedPrerelease>' {
            if ([string]::IsNullOrEmpty($ExpectedPrerelease)) {
                $newVersion.Prerelease | Should -BeNullOrEmpty
            } else {
                $newVersion.Prerelease | Should -Be $ExpectedPrerelease
            }
        }
        It 'FullVersion is <ExpectedFullVersion>' {
            $newVersion.ToString() | Should -Be $ExpectedFullVersion
        }
    }
}

Describe 'Non-PR event keeps the current version' {
    # main.ps1 builds this decision when the event has no pull_request (for example
    # workflow_dispatch or schedule): no bump, no prerelease, no publish. Get-NextModuleVersion
    # must then return the current published version unchanged, floored at 0.0.0 when nothing
    # has ever been released.
    BeforeAll {
        Mock -CommandName Find-PSResource -ModuleName 'Resolve-PSModuleVersion.Helpers' -MockWith { @() }
        $emptyReleases = @([PSCustomObject]@{ tagName = 'v0.0.0'; isLatest = $false; isPrerelease = $false })
        $config = [PSCustomObject]@{
            AutoPatching          = $false
            IncrementalPrerelease = $true
            DatePrereleaseFormat  = ''
            VersionPrefix         = 'v'
            ReleaseType           = 'None'
            IgnoreLabels          = @()
            MajorLabels           = @('major')
            MinorLabels           = @('minor')
            PatchLabels           = @('patch')
        }
        $noReleaseDecision = [PSCustomObject]@{
            ShouldPublish    = $false
            CreateRelease    = $false
            CreatePrerelease = $false
            MajorRelease     = $false
            MinorRelease     = $false
            PatchRelease     = $false
            HasVersionBump   = $false
            PrereleaseName   = ''
        }
    }

    It 'keeps the current version <LatestVersion> with no bump and no prerelease' -ForEach @(
        @{ LatestVersion = '1.2.3' }
        @{ LatestVersion = '0.0.0' }
    ) {
        $latestVer = New-PSSemVer -Version $LatestVersion
        $result = Get-NextModuleVersion -LatestVersion $latestVer -Decision $noReleaseDecision `
            -Configuration $config -ModuleName 'TestModule' -Releases $emptyReleases
        "$($result.Major).$($result.Minor).$($result.Patch)" | Should -Be $LatestVersion
        $result.Prerelease | Should -BeNullOrEmpty
    }
}

Describe 'Get-GitHubPullRequest' {
    # Covers the non-PR branch: on an event without a pull_request (workflow_dispatch/schedule)
    # the function must return $null so the caller keeps the current version, and it must still
    # return the head ref + labels on a pull_request event.
    AfterEach {
        Remove-Item Env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson -ErrorAction SilentlyContinue
    }

    It 'returns $null when the event has no pull_request (non-PR event)' {
        $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson = '{ "action": "workflow_dispatch" }'
        Get-GitHubPullRequest | Should -BeNullOrEmpty
    }

    It 'returns the head ref and labels for a pull_request event' {
        $eventJson = @{
            pull_request = @{
                head   = @{ ref = 'feat/example' }
                labels = @(@{ name = 'patch' }, @{ name = 'prerelease' })
            }
        } | ConvertTo-Json -Depth 5
        $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson = $eventJson
        $result = Get-GitHubPullRequest
        $result.HeadRef | Should -Be 'feat/example'
        ($result.Labels -join ',') | Should -Be 'patch,prerelease'
    }
}
