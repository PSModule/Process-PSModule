BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../src/Release-PSModule.Helpers.psm1') -Force
}

Describe 'Get-PSModulePrereleaseOwnership' {
    It 'returns no ownership evidence for legacy authored notes' {
        Get-PSModulePrereleaseOwnership -Body 'Release notes without producer provenance.' | Should -BeNullOrEmpty
    }

    It 'reads only the final controller footer rather than an earlier authored marker' {
        $foreign = @{ Repository = 'Another/Repo'; PullRequest = 99; CommitSha = 'foreign-sha' } |
            ConvertTo-Json -Compress
        $owner = @{ Repository = 'PSModule/TestModule'; PullRequest = 42; CommitSha = 'original-sha' } |
            ConvertTo-Json -Compress
        $foreignEncoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($foreign))
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
        $body = "<!-- PSModule.PrereleaseOwner:v1:$foreignEncoded -->`nAuthored notes`n`n<!-- PSModule.PrereleaseOwner:v1:$encoded -->"

        $result = Get-PSModulePrereleaseOwnership -Body $body

        $result.Repository | Should -BeExactly 'PSModule/TestModule'
        $result.PullRequest | Should -Be 42
        $result.CommitSha | Should -BeExactly 'original-sha'
    }

    It 'refuses an invalid producer ownership footer' {
        $owner = @{ Repository = ''; PullRequest = 0; CommitSha = '' } | ConvertTo-Json -Compress
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))

        { Get-PSModulePrereleaseOwnership -Body "<!-- PSModule.PrereleaseOwner:v1:$encoded -->" } |
            Should -Throw '*ownership footer is invalid*'
    }
}

Describe 'Resolve-PSModuleReleaseTagCommit' {
    It 'returns the commit from a lightweight release tag' {
        $parameters = @{
            Tag             = 'v1.2.3'
            GetTagReference = { [pscustomobject]@{ type = 'commit'; sha = 'original-sha' } }
            GetTagObject    = { throw 'A lightweight tag must not request an annotated object.' }
        }

        Resolve-PSModuleReleaseTagCommit @parameters | Should -BeExactly 'original-sha'
    }

    It 'peels an annotated tag instead of trusting a mutable release target hint' {
        $parameters = @{
            Tag             = 'v1.2.3'
            GetTagReference = { [pscustomobject]@{ type = 'tag'; sha = 'tag-object' } }
            GetTagObject    = {
                param($Sha)
                $Sha | Should -BeExactly 'tag-object'
                [pscustomobject]@{ type = 'commit'; sha = 'original-sha' }
            }
        }

        Resolve-PSModuleReleaseTagCommit @parameters | Should -BeExactly 'original-sha'
    }

    It 'fails on a cyclic annotated-tag response' {
        $parameters = @{
            Tag             = 'v1.2.3'
            GetTagReference = { [pscustomobject]@{ type = 'tag'; sha = 'tag-object' } }
            GetTagObject    = { [pscustomobject]@{ type = 'tag'; sha = 'tag-object' } }
        }

        { Resolve-PSModuleReleaseTagCommit @parameters } | Should -Throw '*cyclic*'
    }

    It 'fails when a tag does not identify an immutable commit' {
        $parameters = @{
            Tag             = 'v1.2.3'
            GetTagReference = { [pscustomobject]@{ type = 'tree'; sha = 'not-a-commit' } }
            GetTagObject    = { throw 'No annotated lookup is expected.' }
        }

        { Resolve-PSModuleReleaseTagCommit @parameters } | Should -Throw '*immutable commit*'
    }
}
