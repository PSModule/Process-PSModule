[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester setup state is used in test blocks and command replacements.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

BeforeAll {
    Import-Module -Name PSModule -Force
    Import-Module -Name ([IO.Path]::Combine(
            $PSScriptRoot, '..', 'src', 'Resolve-PSModuleVersion.Helpers.psm1'
        )) -Force
    $script:originalFind = (Get-Item -LiteralPath 'Function:\Find-PSResource' -ErrorAction SilentlyContinue).ScriptBlock
    $script:originalSleep = (Get-Item -LiteralPath 'Function:\Start-Sleep' -ErrorAction SilentlyContinue).ScriptBlock
}

AfterAll {
    foreach ($name in @('Find-PSResource', 'Start-Sleep')) {
        Remove-Item -LiteralPath "Function:\$name" -ErrorAction SilentlyContinue
    }
    if ($null -ne $script:originalFind) {
        Set-Item -Path function:global:Find-PSResource -Value $script:originalFind
    }
    if ($null -ne $script:originalSleep) {
        Set-Item -Path function:global:Start-Sleep -Value $script:originalSleep
    }
}

Describe 'Version lookup errors are not version baselines' {
    BeforeEach {
        $state = @{ Message = ''; ErrorId = ''; Package = $null }
        $script:state = $state
        Set-Item -Path function:global:Start-Sleep -Value {}
        Set-Item -Path function:global:Find-PSResource -Value {
            [CmdletBinding()]
            param(
                [string] $Name,
                [string] $Repository,
                [string] $Version,
                [switch] $Prerelease
            )
            if ($Name -cne 'TestModule' -or $Repository -cne 'PSGallery' -or
                ($Version -and ($Version -cne '*' -or -not $Prerelease))) {
                throw 'Unexpected Gallery boundary in the version-reader fixture.'
            }
            if ($state.Message) {
                Write-Error -Message $state.Message -ErrorId $state.ErrorId -Category ResourceUnavailable
                return
            }
            $state.Package
        }.GetNewClosure()
    }

    It 'retains verified Gallery package absence as the first-release baseline' {
        $script:state.Message = 'The exact module is absent.'
        $script:state.ErrorId = 'PackageNotFound'

        (Get-LatestPSGalleryVersion -ModuleName TestModule).ToString() | Should -BeExactly '0.0.0'
    }

    It 'surfaces Gallery authentication and API errors before resolving a publishable version' -ForEach @(
        @{ Message = 'Gallery authentication failed (HTTP 401).' }
        @{ Message = 'Gallery Service Unavailable (HTTP 503).' }
    ) {
        $script:state.Message = $Message
        $script:state.ErrorId = 'HttpRequestCallFailure'

        { Get-LatestPSGalleryVersion -ModuleName TestModule } | Should -Throw
    }

    It 'rejects a successful lookup with no version metadata rather than returning 0.0.0' {
        $script:state.Package = [pscustomobject]@{ Name = 'TestModule'; Version = $null }

        { Get-LatestPSGalleryVersion -ModuleName TestModule } | Should -Throw '*version*'
    }

    It 'retains the actual stable version without an extra bump policy' {
        $script:state.Package = [pscustomobject]@{ Name = 'TestModule'; Version = [version]'1.2.3' }

        (Get-LatestPSGalleryVersion -ModuleName TestModule).ToString() | Should -BeExactly '1.2.3'
    }

    It 'does not interpret a prerelease enumeration outage as counter zero' {
        $script:state.Message = 'Gallery enumeration failed (HTTP 503).'
        $script:state.ErrorId = 'HttpRequestCallFailure'
        $parameters = @{ ModuleName = 'TestModule'; BaseVersion = '1.2.4'; PrereleaseName = 'preview'; Releases = @() }

        { Get-NextPrereleaseNumber @parameters } | Should -Throw
    }

    It 'rejects prerelease missing version metadata before filtering' {
        $script:state.Package = [pscustomobject]@{ Name = 'TestModule'; Version = $null; Prerelease = 'preview001' }
        $parameters = @{ ModuleName = 'TestModule'; BaseVersion = '1.2.4'; PrereleaseName = 'preview'; Releases = @() }

        { Get-NextPrereleaseNumber @parameters } | Should -Throw '*metadata*'
    }

    It 'rejects prerelease empty successful enumeration instead of treating it as verified absence' {
        $parameters = @{ ModuleName = 'TestModule'; BaseVersion = '1.2.4'; PrereleaseName = 'preview'; Releases = @() }

        { Get-NextPrereleaseNumber @parameters } | Should -Throw '*metadata*'
    }
}
