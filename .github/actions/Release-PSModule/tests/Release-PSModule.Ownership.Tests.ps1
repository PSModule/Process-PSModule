[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester setup variables are used by test blocks.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

BeforeAll {
    Import-Module -Name ([IO.Path]::Combine(
            $PSScriptRoot, '..', 'src', 'Release-PSModule.Helpers.psm1'
        )) -Force
}

Describe 'Source-bound publication proof' {
    BeforeEach {
        $script:claim = [ordered]@{
            Repository     = 'PSModule/TestModule'
            PullRequest    = 42
            CommitSha      = '1111111111111111111111111111111111111111'
            ModuleName     = 'TestModule'
            GalleryVersion = '1.2.4'
            VersionPrefix  = 'release-'
            ReleaseTag     = 'release-1.2.4'
            ReleaseType    = 'Release'
            ArtifactSha256 = 'a' * 64
            AssetName      = 'TestModule-1.2.4.zip'
            AssetSha256    = 'b' * 64
        }
    }

    It 'reads a final versioned claim without treating notes as identity' {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(
                ($script:claim | ConvertTo-Json -Compress)
            ))

        $result = Get-PSModulePublicationClaim -Message "Authored notes.`n<!-- PSModule.Publication:v1:$encoded -->"

        $result.Repository | Should -BeExactly 'PSModule/TestModule'
        $result.PullRequest | Should -Be 42
        $result.CommitSha | Should -BeExactly $script:claim.CommitSha
        $result.GalleryVersion | Should -BeExactly '1.2.4'
        $result.ReleaseTag | Should -BeExactly 'release-1.2.4'
        $result.ArtifactSha256 | Should -BeExactly ('a' * 64)
        $result.AssetSha256 | Should -BeExactly ('b' * 64)
    }

    It 'does not fabricate ownership for a legacy annotated tag' {
        Get-PSModulePublicationClaim -Message 'Legacy tag message.' | Should -BeNullOrEmpty
    }

    It 'ignores a completed authored ownership marker followed by ordinary notes' {
        $owner = @{ Repository = 'PSModule/TestModule'; PullRequest = 42; CommitSha = 'original-source' } |
            ConvertTo-Json -Compress
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
        $body = "<!-- PSModule.PrereleaseOwner:v1:$encoded -->`nOrdinary authored notes follow."

        Get-PSModulePrereleaseOwnership -Body $body | Should -BeNullOrEmpty
    }

    It 'rejects malformed claim provenance explicitly' -ForEach @(
        @{ Message = '<!-- PSModule.Publication:v1:not-base64 -->' }
        @{ Message = '<!-- PSModule.Publication:v1:e30= -->' }
        @{ Message = '<!-- PSModule.Publication:v2:e30= -->' }
    ) {
        { Get-PSModulePublicationClaim -Message $Message } | Should -Throw '*publication*'
    }

    It 'rejects a foreign PR footer even when its immutable source matches' {
        $owner = @{
            Repository  = 'PSModule/TestModule'
            PullRequest = 99
            CommitSha   = $script:claim.CommitSha
        } | ConvertTo-Json -Compress
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
        $parameters = @{
            Body        = "Notes.`n<!-- PSModule.PrereleaseOwner:v1:$encoded -->"
            Repository  = 'PSModule/TestModule'
            PullRequest = 42
            CommitSha   = $script:claim.CommitSha
        }

        { Get-PSModuleReleaseOwnership @parameters } | Should -Throw '*pull request*'
    }

    It 'rejects a foreign repository or source in the existing footer' -ForEach @(
        @{ Repository = 'Other/TestModule'; CommitSha = '1111111111111111111111111111111111111111' }
        @{ Repository = 'PSModule/TestModule'; CommitSha = '2222222222222222222222222222222222222222' }
    ) {
        $owner = @{ Repository = $Repository; PullRequest = 42; CommitSha = $CommitSha } | ConvertTo-Json -Compress
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
        $parameters = @{
            Body        = "<!-- PSModule.PrereleaseOwner:v1:$encoded -->"
            Repository  = 'PSModule/TestModule'
            PullRequest = 42
            CommitSha   = $script:claim.CommitSha
        }

        { Get-PSModuleReleaseOwnership @parameters } | Should -Throw '*ownership*'
    }
}

Describe 'Tested artifact identity' {
    BeforeEach {
        $script:modulePath = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString()) -AdditionalChildPath 'TestModule'
        $null = New-Item -Path $script:modulePath -ItemType Directory -Force
        [IO.File]::WriteAllText(
            (Join-Path -Path $script:modulePath -ChildPath 'TestModule.psm1'),
            'throw "Never import package bytes for proof."',
            [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::WriteAllText(
            (Join-Path -Path $script:modulePath -ChildPath 'TestModule.psd1'),
            "@{ ModuleVersion = '1.2.4'; PrivateData = @{ ConsumerMetadata = 'retained' } }",
            [Text.UTF8Encoding]::new($false)
        )
    }

    It 'produces identical ZIP bytes after timestamp-only changes and includes the exact files' {
        $firstPath = Join-Path -Path $TestDrive -ChildPath 'first.zip'
        $secondPath = Join-Path -Path $TestDrive -ChildPath 'second.zip'
        $firstDigest = Get-PSModuleArtifactDigest -Path $script:modulePath
        $null = New-PSModuleReleaseArchive -Path $script:modulePath -DestinationPath $firstPath
        [IO.File]::SetLastWriteTimeUtc(
            (Join-Path -Path $script:modulePath -ChildPath 'TestModule.psm1'),
            [datetime]'2001-02-03T04:05:06Z'
        )
        $null = New-PSModuleReleaseArchive -Path $script:modulePath -DestinationPath $secondPath

        (Get-FileHash -LiteralPath $firstPath).Hash | Should -BeExactly (Get-FileHash -LiteralPath $secondPath).Hash
        Get-PSModuleArtifactDigest -Path $script:modulePath | Should -BeExactly $firstDigest
        $archive = [IO.Compression.ZipFile]::OpenRead($firstPath)
        try {
            @($archive.Entries.FullName) | Should -Be @('TestModule/TestModule.psd1', 'TestModule/TestModule.psm1')
            $archive.Entries[0].LastWriteTime.Year | Should -Be 1980
        } finally {
            $archive.Dispose()
        }
    }

    It 'detects changed or renamed module files rather than comparing only the version' {
        $original = Get-PSModuleArtifactDigest -Path $script:modulePath
        [IO.File]::WriteAllText((Join-Path -Path $script:modulePath -ChildPath 'TestModule.psm1'), 'Changed bytes.')
        Get-PSModuleArtifactDigest -Path $script:modulePath | Should -Not -BeExactly $original
        Rename-Item -LiteralPath (Join-Path -Path $script:modulePath -ChildPath 'TestModule.psm1') -NewName 'Other.psm1'
        Get-PSModuleArtifactDigest -Path $script:modulePath | Should -Not -BeExactly $original
    }

    It 'rejects a literal Unix filename backslash before hashing or creating an archive' -Skip:$IsWindows {
        [IO.File]::WriteAllText([IO.Path]::Combine($script:modulePath, 'data\value.txt'), 'Literal filename bytes.')
        $archivePath = Join-Path -Path $TestDrive -ChildPath 'rejected-backslash.zip'

        { Get-PSModuleArtifactDigest -Path $script:modulePath } | Should -Throw '*backslash*'
        { New-PSModuleReleaseArchive -Path $script:modulePath -DestinationPath $archivePath } | Should -Throw '*backslash*'
        Test-Path -LiteralPath $archivePath | Should -BeFalse
    }

    It 'does not treat a raw backslash file record as a directory path' {
        $record = [pscustomobject]@{
            RelativePath = 'data\value.txt'
            Length       = 1L
            Hash         = [byte[]](0..31)
        }

        { Get-PSModuleContentDigest -File @($record) } | Should -Throw '*path*'
    }

    It 'compares raw nupkg payload files without importing or changing consumer metadata' {
        $packagePath = Join-Path -Path $TestDrive -ChildPath 'TestModule.1.2.4.nupkg'
        $stream = [IO.File]::Create($packagePath)
        $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($file in Get-ChildItem -LiteralPath $script:modulePath -File) {
                $entry = $archive.CreateEntry($file.Name)
                $entryStream = $entry.Open()
                $fileStream = $file.OpenRead()
                try { $fileStream.CopyTo($entryStream) } finally { $fileStream.Dispose(); $entryStream.Dispose() }
            }
            $entry = $archive.CreateEntry('TestModule.nuspec')
            $writer = [IO.StreamWriter]::new($entry.Open())
            try {
                $writer.Write('<package><metadata><id>TestModule</id><version>1.2.4</version></metadata></package>')
            } finally {
                $writer.Dispose()
            }
            $entry = $archive.CreateEntry('[Content_Types].xml')
            $writer = [IO.StreamWriter]::new($entry.Open())
            try { $writer.Write('<Types />') } finally { $writer.Dispose() }
        } finally {
            $archive.Dispose()
            $stream.Dispose()
        }

        $before = Get-PSModuleArtifactDigest -Path $script:modulePath
        $parameters = @{ Path = $packagePath; ModuleName = 'TestModule'; GalleryVersion = '1.2.4' }

        Get-PSModulePackageArtifactDigest @parameters | Should -BeExactly $before
        Get-PSModuleArtifactDigest -Path $script:modulePath | Should -BeExactly $before
        $parameters.GalleryVersion = '1.2.5'
        { Get-PSModulePackageArtifactDigest @parameters } | Should -Throw '*identity*'
    }
}
