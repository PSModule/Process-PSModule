BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../src/Release-PSModule.Helpers.psm1') -Force
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
