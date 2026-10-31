[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester fixture state is used by test blocks and injected readers.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

BeforeAll {
    Import-Module PSModule -Force
    Import-Module -Name ([IO.Path]::Combine($PSScriptRoot, '..', 'src', 'Resolve-PSModuleVersion.Helpers.psm1')) -Force
    Import-Module -Name ([IO.Path]::Combine(
            $PSScriptRoot, '..', '..', 'Release-PSModule', 'src', 'Release-PSModule.Helpers.psm1'
        )) -Force
    Import-Module -Name ([IO.Path]::Combine(
            $PSScriptRoot, '..', '..', 'Publish-PSModule', 'tests', 'Publish-PSModule.TestFixture.psm1'
        )) -Force
}

Describe 'Gallery-only version selection requires original ownership proof' {
    BeforeEach {
        $modulePath = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString()) -AdditionalChildPath 'TestModule'
        $null = New-Item -Path $modulePath -ItemType Directory -Force
        [IO.File]::WriteAllText((Join-Path -Path $modulePath -ChildPath 'TestModule.psm1'), '# Original tested payload.')
        New-ModuleManifest -Path (Join-Path -Path $modulePath -ChildPath 'TestModule.psd1') `
            -RootModule TestModule.psm1 -ModuleVersion 1.2.4 -Author PublicationFixture `
            -Guid '3c0f8d73-60b7-4f38-b3cf-9386db4982a4' -Description 'Anonymous recovery fixture.'
        $zipPath = Join-Path -Path (Split-Path -Path $modulePath -Parent) -ChildPath 'original.zip'
        $packagePath = Join-Path -Path (Split-Path -Path $modulePath -Parent) -ChildPath 'original.nupkg'
        $null = New-PSModuleReleaseArchive -Path $modulePath -DestinationPath $zipPath
        New-PSModuleFixturePackage -Path $modulePath -DestinationPath $packagePath -Version '1.2.4'
        $claim = [pscustomobject]@{
            Repository     = 'PSModule/TestModule'
            PullRequest    = 42
            CommitSha      = '1111111111111111111111111111111111111111'
            ModuleName     = 'TestModule'
            GalleryVersion = '1.2.4'
            VersionPrefix  = 'v'
            ReleaseTag     = 'v1.2.4'
            ReleaseType    = 'Release'
            ArtifactSha256 = Get-PSModuleArtifactDigest -Path $modulePath
            AssetName      = 'TestModule-1.2.4.zip'
            AssetSha256    = (Get-FileHash -LiteralPath $zipPath).Hash.ToLowerInvariant()
        }
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($claim | ConvertTo-Json -Compress)))
        $record = [pscustomobject]@{
            Reference   = [pscustomobject]@{
                ref    = 'refs/tags/v1.2.4'
                object = [pscustomobject]@{ type = 'tag'; sha = '3333333333333333333333333333333333333333' }
            }
            Annotation  = [pscustomobject]@{
                sha     = '3333333333333333333333333333333333333333'
                tag     = 'v1.2.4'
                object  = [pscustomobject]@{ type = 'commit'; sha = $claim.CommitSha }
                message = "<!-- PSModule.Publication:v1:$encoded -->"
            }
            Package     = [pscustomobject]@{ Name = 'TestModule'; Version = '1.2.4' }
            PackagePath = $packagePath
            Release     = $null
        }
        $state = @{
            Record     = $record
            Claims     = @($record.Reference)
            Calls      = [Collections.Generic.List[string]]::new()
            ModulePath = $modulePath
            Claim      = $claim
        }
        $script:state = $state
        $reader = @{
            GetSource                = {
                param($Sha)
                $state.Calls.Add('source-read')
                $Sha
            }.GetNewClosure()
            GetTagList               = {
                $state.Calls.Add('tag-list-read')
                $state.Claims
            }.GetNewClosure()
            GetTagReference          = {
                param($Tag)
                $state.Calls.Add("tag-read:$Tag")
                if ($Tag -ceq $state.Record.Annotation.tag) { $state.Record.Reference.object }
            }.GetNewClosure()
            GetVersionReference      = {
                param($Name, $Version)
                if ($Name -cne 'TestModule' -or $Version -cne '1.2.4') {
                    throw 'Unexpected module/version coordinate lookup.'
                }
                $state.Calls.Add('module-version-coordinate-read')
                $state.Record.Reference.object
            }.GetNewClosure()
            GetTagObject             = {
                param($Sha)
                if ($Sha -cne $state.Record.Annotation.sha) { throw 'Unexpected annotated tag lookup.' }
                $state.Record.Annotation
            }.GetNewClosure()
            GetRelease               = {
                param($Tag)
                $state.Calls.Add("release-read:$Tag")
                if ($Tag -ceq $state.Record.Annotation.tag) { $state.Record.Release }
            }.GetNewClosure()
            GetPackage               = {
                param($Name, $Version)
                $state.Calls.Add("package-read:$Version")
                if ($Name -cne 'TestModule') { throw 'Unexpected module lookup.' }
                if ($Version -ceq '1.2.4') { $state.Record.Package }
            }.GetNewClosure()
            GetPackageArtifactDigest = {
                param($Name, $Version)
                $state.Calls.Add("raw-package-read:$Version")
                Get-PSModulePackageArtifactDigest -Path $state.Record.PackagePath -ModuleName $Name -GalleryVersion $Version
            }.GetNewClosure()
        }
        $script:parameters = @{
            GitHubVersion      = New-PSSemVer -Version '1.2.3'
            PSGalleryVersion   = New-PSSemVer -Version '1.2.4'
            Decision           = [pscustomobject]@{
                ShouldPublish = $true; CreateRelease = $true; CreatePrerelease = $false
                MajorRelease = $false; MinorRelease = $false; PatchRelease = $true
                HasVersionBump = $true; PrereleaseName = ''
            }
            Configuration      = [pscustomobject]@{
                VersionPrefix = 'v'; AutoPatching = $true; IncrementalPrerelease = $false; DatePrereleaseFormat = ''
            }
            ModuleName         = 'TestModule'
            Releases           = @()
            PublicationContext = [pscustomobject]@{
                Repository = 'PSModule/TestModule'; PullRequest = 42; CommitSha = $claim.CommitSha
            }
            PublicationReader  = $reader
        }
    }

    It 'never reuses numeric equality without immutable source and artifact proof' {
        $parameters = $script:parameters.Clone()
        $parameters.Remove('PublicationContext')
        $parameters.Remove('PublicationReader')

        { Get-ResolvedModuleVersion @parameters } | Should -Throw '*proof*'
    }

    It 'reuses the exact original version only after reading its raw package proof before Build' {
        $result = Get-ResolvedModuleVersion @script:parameters

        $result.ToString() | Should -BeExactly 'v1.2.4'
        $script:state.Calls | Should -Contain 'raw-package-read:1.2.4'
    }

    It 'does not take a new number when latest Gallery and GitHub hints have advanced' {
        $script:parameters.GitHubVersion = New-PSSemVer -Version '1.2.5'
        $script:parameters.PSGalleryVersion = New-PSSemVer -Version '1.2.5'

        (Get-ResolvedModuleVersion @script:parameters).ToString() | Should -BeExactly 'v1.2.4'
    }

    It 'rejects a Gallery-only version with unavailable legacy proof instead of inventing a fallback' {
        $script:state.Record.Annotation.message = 'Legacy tag without artifact proof.'

        { Get-ResolvedModuleVersion @script:parameters } | Should -Throw '*proof*'
    }

    It 'rejects the same commit when the claim belongs to another producing PR' {
        $foreign = $script:state.Claim | ConvertTo-Json -Compress | ConvertFrom-Json
        $foreign.PullRequest = 99
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($foreign | ConvertTo-Json -Compress)))
        $script:state.Record.Annotation.message = "<!-- PSModule.Publication:v1:$encoded -->"

        { Get-ResolvedModuleVersion @script:parameters } | Should -Throw '*context*'
    }

    It 'rejects a foreign source with an incomplete Gallery-only publication instead of bumping' {
        $script:state.Record.Annotation.object.sha = '2222222222222222222222222222222222222222'

        { Get-ResolvedModuleVersion @script:parameters } | Should -Throw '*source/artifact recovery context*'
    }

    It 'keeps the normal bump for a different source after a completed legacy publication' {
        $script:state.Record.Annotation.object.sha = '2222222222222222222222222222222222222222'
        $script:state.Record.Annotation.message = 'Completed legacy tag.'
        $script:state.Record.Release = [pscustomobject]@{
            tag_name = 'v1.2.4'; prerelease = $false; draft = $false
            assets = @([pscustomobject]@{ name = 'TestModule-1.2.4.zip'; state = 'uploaded' })
        }

        (Get-ResolvedModuleVersion @script:parameters).ToString() | Should -BeExactly 'v1.2.5'
    }

    It 'rejects changed package bytes despite matching source, version, and PR' {
        [IO.File]::WriteAllText(
            (Join-Path -Path $script:state.ModulePath -ChildPath 'TestModule.psm1'), '# Different package payload.'
        )
        New-PSModuleFixturePackage -Path $script:state.ModulePath -DestinationPath $script:state.Record.PackagePath -Version '1.2.4'

        { Get-ResolvedModuleVersion @script:parameters } | Should -Throw '*artifact*'
    }

    It 'rejects missing raw package evidence for an already-claimed source' {
        $script:state.Record.Package = $null

        { Get-ResolvedModuleVersion @script:parameters } | Should -Throw '*package*'
    }

    It 'propagates API failure rather than treating it as no recovery candidate' {
        $script:parameters.PublicationReader.GetTagList = { throw 'Injected GitHub API HTTP 503.' }

        { Get-ResolvedModuleVersion @script:parameters } | Should -Throw '*503*'
    }

    It 'leaves non-publishing preview decisions on the existing resolver path' {
        $script:parameters.Decision.ShouldPublish = $false
        $script:parameters.Decision.CreateRelease = $false

        $result = Get-ResolvedModuleVersion @script:parameters

        $result.ToString() | Should -BeExactly 'v1.2.5'
        $script:state.Calls.Count | Should -Be 0
    }
}
