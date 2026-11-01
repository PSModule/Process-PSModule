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
    Import-Module -Name 'PSModule' -Force
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Publish-PSModule.TestFixture.psm1') -Force
    Import-Module -Name ([IO.Path]::Combine(
            $PSScriptRoot, '..', '..', 'Resolve-PSModuleVersion', 'src', 'Resolve-PSModuleVersion.Helpers.psm1'
        )) -Force

    $script:publishScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/publish.ps1'
    $script:environmentVariableNames = @(
        'GITHUB_EVENT_PATH'
        'GITHUB_REPOSITORY'
        'GITHUB_SHA'
        'GITHUB_WORKSPACE'
        'GITHUB_OUTPUT'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_Name'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_ModulePath'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_PSGALLERY_API_KEY'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_ReleaseTag'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_VersionPrefix'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_CommitSha'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_WhatIf'
        'PSMODULE_RELEASE_PSMODULE_INPUT_Name'
        'PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath'
        'PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading'
        'PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag'
        'PSMODULE_RELEASE_PSMODULE_INPUT_VersionPrefix'
        'PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest'
        'PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha'
    )
    $script:originalEnvironment = @{}
    foreach ($name in $script:environmentVariableNames) {
        $script:originalEnvironment[$name] = [System.Environment]::GetEnvironmentVariable($name)
    }
}

AfterAll {
    try {
        foreach ($name in $script:environmentVariableNames) {
            [System.Environment]::SetEnvironmentVariable($name, $script:originalEnvironment[$name])
        }
        foreach ($name in @('Find-PSResource', 'Publish-PSResource', 'Resolve-PSModuleDependency', 'gh', 'Save-PSResource', 'Invoke-WebRequest')) {
            Remove-Item -LiteralPath "Function:\$name" -ErrorAction SilentlyContinue
        }
    } finally {
        $script:environmentMutex.ReleaseMutex()
        $script:environmentMutex.Dispose()
    }
}

Describe 'Publish-PSModule recovery' {
    BeforeEach {
        $script:moduleName = 'TestModule'
        $script:workspacePath = Join-Path -Path $TestDrive -ChildPath 'workspace'
        $script:modulePath = Join-Path -Path $script:workspacePath -ChildPath ".PSModule/module/$script:moduleName"
        $manifestPath = Join-Path -Path $script:modulePath -ChildPath "$script:moduleName.psd1"
        $eventPath = Join-Path -Path $TestDrive -ChildPath 'event.json'
        $null = New-Item -Path $script:modulePath -ItemType Directory -Force
        Set-Content -Path (Join-Path -Path $script:modulePath -ChildPath "$script:moduleName.psm1") -Value ''
        Set-Content -Path $manifestPath -Value @"
@{
    RootModule = '$script:moduleName.psm1'
    ModuleVersion = '1.2.4'
    GUID = '3c0f8d73-60b7-4f38-b3cf-9386db4982a4'
    Author = 'PSModule'
    Description = 'Test module'
    PowerShellVersion = '5.1'
    PrivateData = @{
        PSData = @{
            Prerelease = ''
        }
    }
}
"@
        @{} | ConvertTo-Json | Set-Content -Path $eventPath

        $env:GITHUB_EVENT_PATH = $eventPath
        $env:GITHUB_REPOSITORY = "PSModule/$script:moduleName"
        $env:GITHUB_SHA = '1111111111111111111111111111111111111111'
        $env:GITHUB_WORKSPACE = $script:workspacePath
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_Name = $script:moduleName
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ModulePath = '.PSModule/module'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PSGALLERY_API_KEY = 'test-key'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest = ''
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ReleaseTag = 'v1.2.4'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_VersionPrefix = 'v'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_CommitSha = $env:GITHUB_SHA
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_WhatIf = 'false'
        $script:state = New-PSModulePublicationFixture -Path $script:modulePath -Version '1.2.4' -Tag 'v1.2.4'
        $script:releaseScriptPath = [IO.Path]::Combine(
            $PSScriptRoot, '..', '..', 'Release-PSModule', 'src', 'release.ps1'
        )
        $env:GITHUB_OUTPUT = Join-Path -Path $TestDrive -ChildPath 'output'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_Name = $script:moduleName
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath = '.PSModule/module'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag = 'v1.2.4'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_VersionPrefix = 'v'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest = ''
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = $env:GITHUB_SHA
        $script:recoveryParameters = @{
            GitHubVersion      = New-PSSemVer -Version '1.2.3'
            PSGalleryVersion   = New-PSSemVer -Version '1.2.4'
            ModuleName         = 'TestModule'
            Releases           = @()
            PublicationContext = [pscustomobject]@{
                Repository = 'PSModule/TestModule'; PullRequest = 0; CommitSha = $env:GITHUB_SHA
            }
            Configuration      = [pscustomobject]@{
                VersionPrefix = 'v'; AutoPatching = $true; IncrementalPrerelease = $false; DatePrereleaseFormat = ''
            }
            Decision           = [pscustomobject]@{
                ShouldPublish = $true; CreateRelease = $true; CreatePrerelease = $false
                MajorRelease = $false; MinorRelease = $false; PatchRelease = $true
                HasVersionBump = $true; PrereleaseName = ''
            }
        }
    }

    It 'rejects a Gallery-only version whose source and artifact proof is missing' {
        $script:state.Package = [pscustomobject]@{ Name = 'TestModule'; Version = '1.2.4' }

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*proof*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'publishes when the resolved version is not in the Gallery' {
        Set-Item -Path function:global:Find-PSResource -Value {
            [CmdletBinding()]
            param(
                [string] $Name,
                [string] $Version,
                [string] $Repository
            )

            # Mirrors how PSResourceGet reports an absent version: an error with the PackageNotFound error ID
            # that honours -ErrorAction, so the shim reacts to -ErrorAction the same way the real cmdlet does.
            Write-Error -Message "Package with name '$Name', version '$Version' could not be found in repository '$Repository'." `
                -ErrorId 'PackageNotFound' -Category ObjectNotFound -TargetObject $Name
        }

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GalleryWrites | Should -Be 1
    }

    It 'fails without publishing when the Gallery lookup errors for another reason' {
        Set-Item -Path function:global:Find-PSResource -Value {
            [CmdletBinding()]
            param(
                [string] $Name,
                [string] $Version,
                [string] $Repository
            )

            # A transient Gallery failure carries a different error ID and must not be mistaken for
            # 'version not published', otherwise an already-published version would be re-uploaded.
            Write-Error -Message "Failed to find '$Name' '$Version' in repository '$Repository': Service Unavailable" `
                -ErrorId 'HttpRequestCallFailure' -Category ResourceUnavailable -TargetObject $Name
        }

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'recovers Gallery success then GitHub failure using the same version and exact bytes' {
        @{ head_commit = @{ message = 'Anonymous stable release notes.' } } |
            ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $env:GITHUB_EVENT_PATH
        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw
        $originalPackageHash = (Get-FileHash -LiteralPath $script:state.RawPackage).Hash
        $script:state.FailReleaseCreate = $true
        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Throw '*Failed to create*'

        $version = Get-ResolvedModuleVersion @script:recoveryParameters
        $version.ToString() | Should -BeExactly 'v1.2.4'
        $script:state.Calls.Add('build-start')
        $script:state.Calls.IndexOf('raw-package-read') | Should -BeLessThan $script:state.Calls.IndexOf('build-start')
        $script:state.FailReleaseCreate = $false

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw
        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GalleryWrites | Should -Be 1
        $script:state.Release.tag_name | Should -BeExactly 'v1.2.4'
        $script:state.Release.assets[0].digest | Should -BeExactly "sha256:$($script:state.ExpectedClaim.AssetSha256)"
        (Get-FileHash -LiteralPath $script:state.RawPackage).Hash | Should -BeExactly $originalPackageHash
        ($script:state.Calls -join "`n") | Should -Not -Match '--clobber'
    }

    It 'rejects changed rebuilt bytes without a duplicate Gallery or GitHub upload' {
        @{ head_commit = @{ message = 'Anonymous stable release notes.' } } |
            ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $env:GITHUB_EVENT_PATH
        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw
        $script:state.FailReleaseCreate = $true
        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Throw '*Failed to create*'
        (Get-ResolvedModuleVersion @script:recoveryParameters).ToString() | Should -BeExactly 'v1.2.4'
        $writes = $script:state.GitHubCreationUpload
        [IO.File]::WriteAllText(
            (Join-Path -Path $script:modulePath -ChildPath 'TestModule.psm1'), '# Different rebuilt artifact.'
        )
        $script:state.FailReleaseCreate = $false

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*artifact*'

        $script:state.GalleryWrites | Should -Be 1
        $script:state.GitHubCreationUpload | Should -Be $writes
        $script:state.Release | Should -BeNullOrEmpty
    }

    It 'recovers the original version and missing upload even when GitHub already has the release' {
        @{ head_commit = @{ message = 'Complete anonymous stable notes.' } } |
            ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $env:GITHUB_EVENT_PATH
        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw
        $script:state.FailAssetUpload = $true
        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Throw '*Failed to upload*'
        $originalNotes = $script:state.Release.body
        $script:recoveryParameters.GitHubVersion = New-PSSemVer -Version '1.2.4'

        (Get-ResolvedModuleVersion @script:recoveryParameters).ToString() | Should -BeExactly 'v1.2.4'
        $script:state.FailAssetUpload = $false
        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw
        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GalleryWrites | Should -Be 1
        $script:state.Release.body | Should -BeExactly $originalNotes
        @($script:state.Release.assets).Count | Should -Be 1
        @($script:state.Calls | Where-Object { $_ -ceq 'release-create' }).Count | Should -Be 1
        $script:state.Release.assets[0].digest | Should -BeExactly "sha256:$($script:state.ExpectedClaim.AssetSha256)"
    }
}
