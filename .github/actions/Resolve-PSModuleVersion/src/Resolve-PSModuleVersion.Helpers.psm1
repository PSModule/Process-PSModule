$ErrorActionPreference = 'Stop'

Import-Module -Name ([IO.Path]::Combine(
        $PSScriptRoot, '..', '..', 'Publish-PSModule', 'src', 'Publish-PSModule.Helpers.psm1'
    )) -Force
Import-Module -Name ([IO.Path]::Combine(
        $PSScriptRoot, '..', '..', 'Release-PSModule', 'src', 'Release-PSModule.Helpers.psm1'
    )) -Force

function Split-CommaSeparatedList {
    <#
        .SYNOPSIS
        Splits a comma-separated string into a trimmed, non-empty array.

        .EXAMPLE
        Split-CommaSeparatedList -Value 'Major, Minor, Patch'

        Returns @('Major', 'Minor', 'Patch').
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        # The comma-separated string to split.
        [Parameter()]
        [string] $Value
    )

    ($Value -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

function Read-ActionInput {
    <#
        .SYNOPSIS
        Reads and validates action inputs from environment variables.

        .DESCRIPTION
        Reads the module name and settings JSON from GitHub Actions environment variables.
        Falls back to the repository name when the module name input is not provided.

        .OUTPUTS
        PSCustomObject with Name and SettingsJson properties.

        .EXAMPLE
        $actionInput = Read-ActionInput
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    LogGroup 'Load inputs' {
        $env:GITHUB_REPOSITORY_NAME = $env:GITHUB_REPOSITORY -replace '.+/'

        $name = if ([string]::IsNullOrEmpty($env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_Name)) {
            $env:GITHUB_REPOSITORY_NAME
        } else {
            $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_Name
        }
        Write-Host "Module name: [$name]"

        $settingsJson = $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_Settings
        if ([string]::IsNullOrWhiteSpace($settingsJson)) {
            throw 'Settings input is required.'
        }

        [PSCustomObject]@{
            Name         = $name
            SettingsJson = $settingsJson
        }
    }
}

function Get-PublishConfiguration {
    <#
        .SYNOPSIS
        Parses the settings JSON into a publish configuration object.

        .DESCRIPTION
        Extracts publish module settings including auto-patching flags, version prefix,
        release type, and label classification arrays.

        .OUTPUTS
        PSCustomObject with publish configuration properties.

        .EXAMPLE
        $config = Get-PublishConfiguration -SettingsJson $actionInput.SettingsJson
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The JSON string containing the module settings.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SettingsJson
    )

    LogGroup 'Resolve configuration' {
        $settings = $SettingsJson | ConvertFrom-Json
        $publishModule = $settings.Publish.Module

        $config = [PSCustomObject]@{
            AutoPatching          = [bool]$publishModule.AutoPatching
            IncrementalPrerelease = [bool]$publishModule.IncrementalPrerelease
            DatePrereleaseFormat  = [string]$publishModule.DatePrereleaseFormat
            VersionPrefix         = [string]$publishModule.VersionPrefix
            ReleaseType           = [string]$publishModule.ReleaseType
            IgnoreLabels          = Split-CommaSeparatedList ([string]$publishModule.IgnoreLabels)
            MajorLabels           = Split-CommaSeparatedList ([string]$publishModule.MajorLabels)
            MinorLabels           = Split-CommaSeparatedList ([string]$publishModule.MinorLabels)
            PatchLabels           = Split-CommaSeparatedList ([string]$publishModule.PatchLabels)
        }

        Write-Host '-------------------------------------------------'
        Write-Host ([PSCustomObject]@{
                AutoPatching          = $config.AutoPatching
                IncrementalPrerelease = $config.IncrementalPrerelease
                DatePrereleaseFormat  = $config.DatePrereleaseFormat
                VersionPrefix         = $config.VersionPrefix
                ReleaseType           = $config.ReleaseType
                IgnoreLabels          = $config.IgnoreLabels -join ', '
                MajorLabels           = $config.MajorLabels -join ', '
                MinorLabels           = $config.MinorLabels -join ', '
                PatchLabels           = $config.PatchLabels -join ', '
            } | Format-List | Out-String)
        Write-Host '-------------------------------------------------'

        $config
    }
}

function Get-GitHubPullRequest {
    <#
        .SYNOPSIS
        Reads normalized pull-request context from settings, with event-payload fallback.

        .DESCRIPTION
        The settings action resolves the pull request associated with a default-branch push
        before this action runs. When no pull request exists, a direct push or manual
        dispatch on the default branch still receives release context so it resolves the
        default patch bump.

        .OUTPUTS
        PSCustomObject with pull-request metadata, or a default-branch direct-release
        context with no pull-request number.

        .EXAMPLE
        $pullRequest = Get-GitHubPullRequest -SettingsJson $actionInput.SettingsJson
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SettingsJson',
        Justification = 'Parameter is used inside a LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The complete settings object, including normalized workflow context.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SettingsJson
    )

    LogGroup 'Event information' {
        $settings = $SettingsJson | ConvertFrom-Json
        $context = $settings.Context
        if ($context) {
            $contextPullRequest = $context.PullRequest
            if ($contextPullRequest) {
                Write-Host "Using normalized pull request context for #$($contextPullRequest.Number)."
                return [PSCustomObject]@{
                    Number  = $contextPullRequest.Number
                    HeadRef = $contextPullRequest.HeadRef
                    Labels  = @($contextPullRequest.Labels)
                }
            }

            if ($context.IsPushToDefaultBranch -or $context.IsManualDispatchToDefaultBranch) {
                Write-Host 'Using direct default-branch release context with the default patch bump.'
                return [PSCustomObject]@{
                    Number          = $null
                    HeadRef         = $context.DefaultBranch
                    Labels          = @()
                    IsDirectRelease = $true
                }
            }
        }

        $eventJsonInput = $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson
        $githubEvent = if (-not [string]::IsNullOrWhiteSpace($eventJsonInput)) {
            $eventJsonInput | ConvertFrom-Json
        } else {
            Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json
        }

        $pr = $githubEvent.pull_request
        if (-not $pr) {
            Write-Host 'GitHub event does not contain pull_request data and no release context was normalized.'
            return $null
        }

        $labels = @()
        $labels += $pr.labels.name

        Write-Host '-------------------------------------------------'
        Write-Host ([PSCustomObject]@{
                PRHeadRef = $pr.head.ref
                Labels    = $labels -join ', '
            } | Format-List | Out-String)
        Write-Host '-------------------------------------------------'

        [PSCustomObject]@{
            HeadRef = $pr.head.ref
            Labels  = $labels
        }
    }
}

function Resolve-ReleaseDecision {
    <#
        .SYNOPSIS
        Determines whether to publish a release and what kind of version bump to apply.

        .DESCRIPTION
        Evaluates the PR labels against the configured label categories and release type
        to produce a complete release decision.

        .OUTPUTS
        PSCustomObject with ShouldPublish, CreateRelease, CreatePrerelease, MajorRelease,
        MinorRelease, PatchRelease, HasVersionBump, and PrereleaseName properties.

        .EXAMPLE
        $decision = Resolve-ReleaseDecision -Configuration $config -PullRequest $pullRequest
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The publish configuration object.
        [Parameter(Mandatory)]
        [PSCustomObject] $Configuration,

        # The pull request data object.
        [Parameter(Mandatory)]
        [PSCustomObject] $PullRequest
    )

    LogGroup 'Determine release configuration' {
        $prereleaseName = $PullRequest.HeadRef -replace '[^a-zA-Z0-9]'
        $labels = $PullRequest.Labels
        $releaseType = $Configuration.ReleaseType

        $validReleaseTypes = @('Release', 'Prerelease', 'None')
        if ([string]::IsNullOrWhiteSpace($releaseType)) {
            throw "Settings.Publish.Module.ReleaseType is required. Valid values are: $($validReleaseTypes -join ', ')"
        }
        if ($releaseType -notin $validReleaseTypes) {
            throw "Invalid ReleaseType: [$releaseType]. Valid values are: $($validReleaseTypes -join ', ')"
        }

        $createRelease = $releaseType -eq 'Release'
        $createPrerelease = $releaseType -eq 'Prerelease'
        $shouldPublish = $createRelease -or $createPrerelease
        $isCleanupOnly = $releaseType -eq 'None'

        if ($isCleanupOnly) {
            return [PSCustomObject]@{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $false
                HasVersionBump   = $false
                PrereleaseName   = $prereleaseName
            }
        }

        $ignoreRelease = ($labels | Where-Object { $Configuration.IgnoreLabels -contains $_ }).Count -gt 0
        if ($ignoreRelease -and $shouldPublish) {
            Write-Host 'Ignoring release creation due to ignore label.'
            $shouldPublish = $false
        }

        $majorLabels = @($labels | Where-Object { $Configuration.MajorLabels -contains $_ })
        $minorLabels = @($labels | Where-Object { $Configuration.MinorLabels -contains $_ })
        $patchLabels = @($labels | Where-Object { $Configuration.PatchLabels -contains $_ })
        $versionLabels = @($majorLabels + $minorLabels + $patchLabels)

        if ($versionLabels.Count -gt 1) {
            throw "Conflicting version labels: [$($versionLabels -join ', ')]. Apply exactly one version label."
        }
        if ($ignoreRelease -and $versionLabels.Count -gt 0) {
            throw "The ignore label cannot be combined with a version label: [$($versionLabels -join ', ')]."
        }

        $majorRelease = $majorLabels.Count -eq 1
        $minorRelease = $minorLabels.Count -eq 1
        $isDirectStableRelease = $createRelease -and $PullRequest.IsDirectRelease
        $patchRelease = $patchLabels.Count -eq 1 -or (
            -not $majorRelease -and
            -not $minorRelease -and
            ($Configuration.AutoPatching -or $isDirectStableRelease)
        )
        $hasVersionBump = $majorRelease -or $minorRelease -or $patchRelease

        if (-not $hasVersionBump) {
            Write-Host 'No version bump label and AutoPatching disabled; previewing a patch version without publishing.'
            $patchRelease = $true
            $hasVersionBump = $true
            $shouldPublish = $false
        }

        if ($ignoreRelease) {
            $createRelease = $false
            $createPrerelease = $false
            $shouldPublish = $false
        }

        if (-not $shouldPublish) {
            $createPrerelease = $true
        }

        Write-Host '-------------------------------------------------'
        Write-Host ([PSCustomObject]@{
                ReleaseType      = $releaseType
                ShouldPublish    = $shouldPublish
                CreateRelease    = $createRelease
                CreatePrerelease = $createPrerelease
                Major            = $majorRelease
                Minor            = $minorRelease
                Patch            = $patchRelease
            } | Format-List | Out-String)
        Write-Host '-------------------------------------------------'

        [PSCustomObject]@{
            ShouldPublish    = $shouldPublish
            CreateRelease    = $createRelease
            CreatePrerelease = $createPrerelease
            MajorRelease     = $majorRelease
            MinorRelease     = $minorRelease
            PatchRelease     = $patchRelease
            HasVersionBump   = $hasVersionBump
            PrereleaseName   = $prereleaseName
        }
    }
}

function ConvertFrom-GitHubReleaseJson {
    <#
        .SYNOPSIS
        Converts the JSON output of 'gh release list' into a flat array of release objects.

        .DESCRIPTION
        Normalizes the release listing so a repository with no releases, or a command that
        produced no output at all, yields an empty array instead of $null.

        .OUTPUTS
        Array of release objects. Empty when there are no releases.

        .EXAMPLE
        $releases = ConvertFrom-GitHubReleaseJson -Json '[{"tagName":"v1.0.0"}]'
    #>
    [CmdletBinding()]
    [OutputType([object[]], [array])]
    param(
        # The raw JSON returned by 'gh release list'. Empty or null when the command produced no output.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Json
    )

    if ([string]::IsNullOrWhiteSpace($Json)) {
        return @()
    }

    @($Json | ConvertFrom-Json)
}

function Get-GitHubRelease {
    <#
        .SYNOPSIS
        Retrieves all releases from the current GitHub repository.

        .DESCRIPTION
        Lists the releases of the current repository. A repository that has no releases yet
        produces no output, so callers normalize the result with @() before using it.

        .OUTPUTS
        Array of release objects. Nothing when the repository has no releases.

        .EXAMPLE
        $releases = @(Get-GitHubRelease)
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param()

    LogGroup 'Get releases - GitHub' {
        $releasesJson = gh release list --json 'createdAt,isDraft,isLatest,isPrerelease,name,publishedAt,tagName'
        if ($LASTEXITCODE -ne 0) {
            Write-Error 'Failed to list releases for the repo.'
            exit $LASTEXITCODE
        }
        $releases = ConvertFrom-GitHubReleaseJson -Json $releasesJson

        Write-Host '-------------------------------------------------'
        Write-Host "Found [$($releases.Count)] releases."
        Write-Host ($releases | Select-Object -Property name, isPrerelease, isLatest, publishedAt |
                Format-Table | Out-String)
        Write-Host '-------------------------------------------------'

        $releases
    }
}

function Get-LatestGitHubVersion {
    <#
        .SYNOPSIS
        Extracts the latest stable version from a GitHub releases list.

        .DESCRIPTION
        Returns the version of the release marked as latest. A repository that has no releases
        yet - or that has releases but none marked as latest - resolves to '0.0.0' so a brand-new
        module can still be versioned before its first release exists.

        .OUTPUTS
        PSSemVer representing the latest GitHub release version.

        .EXAMPLE
        $ghVersion = Get-LatestGitHubVersion -Releases $releases
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The GitHub releases array to search. Empty or null when the repository has no releases.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [array] $Releases = @()
    )

    LogGroup 'Get latest version - GitHub' {
        $latestRelease = $Releases | Where-Object { $_.isLatest -eq $true }
        $tagName = [string]$latestRelease.tagName

        $version = if (-not [string]::IsNullOrEmpty($tagName)) {
            New-PSSemVer -Version $tagName
        } else {
            Write-Warning "Could not find the latest GitHub release. Using '0.0.0'."
            New-PSSemVer -Version '0.0.0'
        }

        Write-Host "GitHub version: [$($version.ToString())]"
        $version
    }
}

function Get-LatestPSGalleryVersion {
    <#
        .SYNOPSIS
        Finds the latest stable version of a module in the PowerShell Gallery.

        .DESCRIPTION
        Queries the PowerShell Gallery for the latest published version of the module.
        Only verified PackageNotFound absence provides a first-release baseline.
        Authentication, API, and incomplete-metadata errors stop version resolution.

        .OUTPUTS
        PSSemVer representing the latest PSGallery version.

        .EXAMPLE
        $psGalleryVersion = Get-LatestPSGalleryVersion -ModuleName 'MyModule'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The name of the module to find in the PowerShell Gallery.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName
    )

    LogGroup 'Get latest version - PSGallery' {
        Write-Host "Finding module [$ModuleName] in the PowerShell Gallery."
        try {
            $packages = @(Find-PSResource -Name $ModuleName -Repository PSGallery -ErrorAction Stop)
        } catch {
            $failure = $_
            if ($failure.FullyQualifiedErrorId -notlike 'PackageNotFound,*') {
                throw
            }
            Write-Host "The module [$ModuleName] is absent from the Gallery; using the first-release baseline [0.0.0]."
            return (New-PSSemVer -Version '0.0.0')
        }
        if ($packages.Count -ne 1 -or $packages[0].Name -ine $ModuleName -or
            [string]::IsNullOrWhiteSpace([string]$packages[0].Version)) {
            throw "Cannot verify the latest Gallery version metadata for [$ModuleName]."
        }
        $version = New-PSSemVer -Version ([string]$packages[0].Version)
        Write-Host "PSGallery version: [$($version.ToString())]"
        $version
    }
}

function Get-LatestPublishedVersion {
    <#
        .SYNOPSIS
        Returns the highest version between GitHub and the PowerShell Gallery.

        .DESCRIPTION
        Compares the two known published versions and returns the highest one. A missing
        (null) version is treated as '0.0.0', so a module that has never been released to
        GitHub or published to the PowerShell Gallery resolves to a '0.0.0' baseline.

        .OUTPUTS
        PSSemVer representing the highest known published version.

        .EXAMPLE
        $latestVersion = Get-LatestPublishedVersion -GitHubVersion $ghVersion -PSGalleryVersion $psGalleryVersion
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The latest version found in GitHub releases. Null when the repository has no releases.
        [Parameter()]
        [AllowNull()]
        [object] $GitHubVersion,

        # The latest version found in the PowerShell Gallery. Null when the module is unpublished.
        [Parameter()]
        [AllowNull()]
        [object] $PSGalleryVersion
    )

    LogGroup 'Latest version' {
        $candidates = @($PSGalleryVersion, $GitHubVersion) |
            Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) }

        $latestVersion = if ($candidates.Count -gt 0) {
            New-PSSemVer -Version ($candidates | Sort-Object -Descending | Select-Object -First 1)
        } else {
            Write-Warning "No published version found in GitHub or the PowerShell Gallery. Using '0.0.0'."
            New-PSSemVer -Version '0.0.0'
        }
        Write-Host "Latest version: [$($latestVersion.ToString())]"
        $latestVersion
    }
}

function Get-NextPrereleaseNumber {
    <#
        .SYNOPSIS
        Calculates the next incremental prerelease number across GitHub and PSGallery.

        .DESCRIPTION
        Queries both GitHub releases and the PowerShell Gallery for existing prereleases
        matching the base version and prerelease name, then returns the next number
        zero-padded to three digits.

        .OUTPUTS
        String. A zero-padded three-digit number (e.g. '001').

        .EXAMPLE
        $number = Get-NextPrereleaseNumber -ModuleName 'MyModule' -BaseVersion '1.2.3' -PrereleaseName 'mybranch' -Releases $releases
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The module name to query in the PowerShell Gallery.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName,

        # The base version string without prerelease (e.g. '1.2.3').
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BaseVersion,

        # The sanitized prerelease name derived from the branch name.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrereleaseName,

        # The GitHub releases list. Empty or null when the repository has no releases.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [array] $Releases = @()
    )

    $params = @{
        Name        = $ModuleName
        Version     = '*'
        Prerelease  = $true
        Repository  = 'PSGallery'
        Verbose     = $false
        ErrorAction = 'Stop'
    }
    try {
        $galleryVersions = @(Find-PSResource @params)
    } catch {
        $failure = $_
        if ($failure.FullyQualifiedErrorId -notlike 'PackageNotFound,*') {
            throw
        }
        $galleryVersions = @()
    }
    $matchingPSGalleryPrereleases = $galleryVersions |
        Where-Object { "$($_.Version.Major).$($_.Version.Minor).$($_.Version.Build)" -eq $BaseVersion } |
        Where-Object { $_.Prerelease -like "$PrereleaseName*" }

    $latestPSGalleryNumber = $matchingPSGalleryPrereleases.Prerelease | ForEach-Object {
        [long]($_ -replace $PrereleaseName)
    } | Sort-Object | Select-Object -Last 1
    Write-Host "PSGallery prerelease: [$latestPSGalleryNumber]"

    $matchingGHPrereleases = $Releases |
        Where-Object { $_.tagName -like "*$BaseVersion*" } |
        Where-Object { $_.tagName -like "*$PrereleaseName*" }

    $latestGHNumber = $matchingGHPrereleases.tagName | ForEach-Object {
        $tagWithoutDots = $_ -replace '\.'
        [long](($tagWithoutDots -split $PrereleaseName, 2)[-1])
    } | Sort-Object | Select-Object -Last 1
    Write-Host "GitHub prerelease: [$latestGHNumber]"

    if ($null -eq $latestPSGalleryNumber) { $latestPSGalleryNumber = 0 }
    if ($null -eq $latestGHNumber) { $latestGHNumber = 0 }

    $nextNumber = [Math]::Max($latestPSGalleryNumber, $latestGHNumber) + 1
    ([string]$nextNumber).PadLeft(3, '0')
}

function Get-NextModuleVersion {
    <#
        .SYNOPSIS
        Calculates the next module version based on the release decision.

        .DESCRIPTION
        Increments the current version according to the version bump type (major, minor, or patch),
        then optionally appends a prerelease suffix with support for date-based and incremental numbering.

        .OUTPUTS
        PSSemVer representing the resolved next version.

        .EXAMPLE
        $newVersion = Get-NextModuleVersion -LatestVersion $latestVersion -Decision $decision `
            -Configuration $config -ModuleName 'MyModule' -Releases $releases
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The current latest published version. Null resolves to a '0.0.0' baseline.
        [Parameter()]
        [AllowNull()]
        [object] $LatestVersion,

        # The release decision object.
        [Parameter(Mandatory)]
        [PSCustomObject] $Decision,

        # The publish configuration object.
        [Parameter(Mandatory)]
        [PSCustomObject] $Configuration,

        # The name of the module.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName,

        # The GitHub releases list, used for incremental prerelease calculation.
        # Empty or null when the repository has no releases.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [array] $Releases = @()
    )

    LogGroup 'Calculate new version' {
        $baseVersion = if ($null -eq $LatestVersion -or [string]::IsNullOrWhiteSpace([string]$LatestVersion)) {
            Write-Warning "No latest version was resolved. Using '0.0.0' as the baseline."
            '0.0.0'
        } else {
            $LatestVersion
        }
        $newVersion = New-PSSemVer -Version $baseVersion
        $newVersion.Prefix = $Configuration.VersionPrefix

        if ($Decision.MajorRelease) {
            Write-Host 'Incrementing major version.'
            $newVersion.BumpMajor()
        } elseif ($Decision.MinorRelease) {
            Write-Host 'Incrementing minor version.'
            $newVersion.BumpMinor()
        } elseif ($Decision.PatchRelease) {
            Write-Host 'Incrementing patch version.'
            $newVersion.BumpPatch()
        }
        Write-Host "Partial new version: [$newVersion]"

        if ($Decision.CreatePrerelease -and $Decision.HasVersionBump) {
            $prereleaseName = $Decision.PrereleaseName
            Write-Host "Adding a prerelease tag using the branch name [$prereleaseName]."
            $newVersion.Prerelease = $prereleaseName

            if (-not [string]::IsNullOrEmpty($Configuration.DatePrereleaseFormat)) {
                Write-Host "Using date-based prerelease format: [$($Configuration.DatePrereleaseFormat)]."
                $newVersion.Prerelease += "$(Get-Date -Format $Configuration.DatePrereleaseFormat)"
            }

            if ($Configuration.IncrementalPrerelease -or -not $Decision.ShouldPublish) {
                $baseVersionString = "$($newVersion.Major).$($newVersion.Minor).$($newVersion.Patch)"
                $params = @{
                    ModuleName     = $ModuleName
                    BaseVersion    = $baseVersionString
                    PrereleaseName = $prereleaseName
                    Releases       = $Releases
                }
                $newVersion.Prerelease += Get-NextPrereleaseNumber @params
            }
        }

        Write-Host "New version: [$($newVersion.ToString())]"
        $newVersion
    }
}

function Get-PSModuleGalleryRecoveryVersion {
    <#
        .SYNOPSIS
        Recover a stable version only from exact source/context and raw package proof.

        .DESCRIPTION
        Searches actual version-tag claims, not latest hints or numeric equality.
        The canonical preflight validates the original package/release evidence before Build.
        A claimed source without package proof, conflicting context, or multiple versions fails.

        .EXAMPLE
        Get-PSModuleGalleryRecoveryVersion -Context $context -Configuration $config -ModuleName $name `
            -PSGalleryVersion $galleryVersion -Reader $reader

        Return the original owned version or no recovery when the published baseline is complete.

        .INPUTS
        None

        You can't pipe objects to Get-PSModuleGalleryRecoveryVersion.

        .OUTPUTS
        System.Object

        The proven original PSSemVer version, when recoverable.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The immutable consumer repository, producing PR/direct context, and source.
        [Parameter(Mandatory)]
        [PSCustomObject] $Context,

        # The existing configured version prefix; no new decision policy is introduced.
        [Parameter(Mandatory)]
        [PSCustomObject] $Configuration,

        # The module whose original package is being recovered.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # The latest observed stable Gallery version, used only to reject incomplete baselines.
        [Parameter(Mandatory)]
        [object] $PSGalleryVersion,

        # Read-only repository/tag/release/raw-package boundaries.
        [Parameter(Mandatory)]
        [hashtable] $Reader
    )

    $number = 0L
    if ($Context.Repository -notmatch '^[^/\s]+/[^/\s]+$' -or
        $Context.CommitSha -notmatch '^[0-9a-f]{40}$' -or
        -not [long]::TryParse([string]$Context.PullRequest, [ref]$number) -or $number -lt 0) {
        throw 'Immutable repository/PR/source context is required for Gallery recovery proof.'
    }
    foreach ($name in @('GetSource', 'GetTagList', 'GetTagReference', 'GetTagObject', 'GetRelease', 'GetPackage', 'GetPackageArtifactDigest')) {
        if ($Reader[$name] -isnot [scriptblock]) {
            throw "The immutable publication reader [$name] is required for Gallery recovery proof."
        }
    }
    $source = & $Reader.GetSource $Context.CommitSha
    if ($source -cne $Context.CommitSha) {
        throw 'The original consumer source could not be verified before Build.'
    }
    $owned = [Collections.Generic.List[object]]::new()
    $references = @(& $Reader.GetTagList)
    $prefix = [string]$Configuration.VersionPrefix
    foreach ($reference in $references) {
        if ($reference.ref -isnot [string] -or -not $reference.ref.StartsWith('refs/tags/') -or
            $null -eq $reference.object) {
            throw 'The publication tag enumeration returned unverifiable reference metadata.'
        }
        $tag = $reference.ref.Substring('refs/tags/'.Length)
        if (-not $tag.StartsWith($prefix, [StringComparison]::Ordinal) -or
            $tag.Substring($prefix.Length) -notmatch '^\d+\.\d+\.\d+$') {
            continue
        }
        $evidence = @{ Annotation = $null; Reference = $null }
        $parameters = @{
            Tag             = $tag
            GetTagReference = {
                param($Tag)
                $evidence.Reference = & $Reader.GetTagReference $Tag
                $evidence.Reference
            }.GetNewClosure()
            GetTagObject    = {
                param($Sha)
                $annotation = & $Reader.GetTagObject $Sha
                if ($null -eq $evidence.Annotation) { $evidence.Annotation = $annotation }
                $annotation.object
            }.GetNewClosure()
        }
        $tagCommit = Resolve-PSModuleReleaseTagCommit @parameters
        if ($tagCommit -cne $Context.CommitSha) {
            continue
        }
        $claim = Get-PSModulePublicationClaim -Message $evidence.Annotation.message
        if ($null -eq $claim) {
            throw "Existing source-bound tag [$tag] has no verifiable artifact/release-context proof. Do not invent a fallback version."
        }
        if ($claim.Repository -ine $Context.Repository -or $claim.PullRequest -ne $number -or
            $claim.CommitSha -cne $Context.CommitSha -or $claim.ModuleName -cne $ModuleName -or
            $claim.ReleaseType -cne 'Release' -or $claim.ReleaseTag -cne $tag -or
            "$prefix$($claim.GalleryVersion)" -cne $tag) {
            throw "The source-bound tag [$tag] belongs to a different module or release context."
        }
        $state = Get-PSModulePublicationState -ExpectedClaim $claim -Reader $Reader
        if ($state.TagSha -cne $evidence.Reference.sha) {
            throw "Publication claim [$tag] changed while verifying recovery proof. Refusing version resolution."
        }
        if ($null -eq $state.Package) {
            throw ("The original source claim [$tag] has no published raw package proof. " +
                'Retain its resolved version/artifact and rerun the original job.')
        }
        $owned.Add($claim)
    }
    if ($owned.Count -gt 1) {
        throw 'Multiple published versions claim this exact source and release context. Refusing ambiguous recovery.'
    }
    if ($owned.Count -eq 1) {
        $version = New-PSSemVer -Version $owned[0].GalleryVersion
        $version.Prefix = $prefix
        Write-Verbose "Recovering proven original publication [$($version.ToString())] before Build."
        return $version
    }
    if ($PSGalleryVersion.ToString() -ne '0.0.0') {
        $galleryVersion = "$($PSGalleryVersion.Major).$($PSGalleryVersion.Minor).$($PSGalleryVersion.Patch)"
        $tag = "$prefix$galleryVersion"
        $release = & $Reader.GetRelease $tag
        $assets = @($release.assets | Where-Object {
                $_.name -ceq "$ModuleName-$galleryVersion.zip" -and $_.state -ceq 'uploaded'
            })
        if ($null -eq $release -or $release.tag_name -cne $tag -or $release.prerelease -ne $false -or
            $release.draft -ne $false -or $assets.Count -ne 1) {
            throw "Gallery-only package [$galleryVersion] has no proven source/artifact recovery context. Do not invent a fallback version."
        }
        $tagParameters = @{
            Tag             = $tag
            GetTagReference = $Reader.GetTagReference
            GetTagObject    = {
                param($Sha)
                (& $Reader.GetTagObject $Sha).object
            }.GetNewClosure()
        }
        $baselineSource = Resolve-PSModuleReleaseTagCommit @tagParameters
        if ($baselineSource -ceq $Context.CommitSha) {
            throw 'The original source already has publication records but recovery proof was not discovered. Do not invent a fallback version.'
        }
    }
}

function Get-ResolvedModuleVersion {
    <#
        .SYNOPSIS
        Resolves the next module version and resumes an incomplete stable release when possible.

        .DESCRIPTION
        Keeps the existing version decision for new releases and previews. A stable
        retry first verifies actual source-bound tag and raw package evidence before
        choosing the original version. Numeric equality and latest hints are not ownership.

        .OUTPUTS
        PSSemVer representing the resolved module version.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The latest version found in GitHub Releases.
        [Parameter(Mandatory)]
        [object] $GitHubVersion,

        # The latest stable version found in the PowerShell Gallery.
        [Parameter(Mandatory)]
        [object] $PSGalleryVersion,

        # The release decision for this workflow run.
        [Parameter(Mandatory)]
        [PSCustomObject] $Decision,

        # The publish configuration object.
        [Parameter(Mandatory)]
        [PSCustomObject] $Configuration,

        # The name of the module.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName,

        # The GitHub releases list, used for prerelease numbering.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [array] $Releases = @(),

        # Original consumer repository, producing PR/direct context, and immutable source.
        [Parameter()]
        [AllowNull()]
        [PSCustomObject] $PublicationContext,

        # Injectable read-only proof boundaries; defaults to the consumer repository API.
        [Parameter()]
        [AllowNull()]
        [hashtable] $PublicationReader
    )

    LogGroup 'Resolve module version' {
        if ($Decision.ShouldPublish -and $Decision.CreateRelease) {
            if ($null -eq $PublicationContext) {
                if ($PSGalleryVersion -gt $GitHubVersion) {
                    throw 'Source/artifact ownership proof is required before resolving a Gallery-only retry.'
                }
            } else {
                if ($null -eq $PublicationReader) {
                    $PublicationReader = Get-PSModulePublicationReader -Repository $PublicationContext.Repository -ReadOnly
                }
                $recoveryParameters = @{
                    Context          = $PublicationContext
                    Configuration    = $Configuration
                    ModuleName       = $ModuleName
                    PSGalleryVersion = $PSGalleryVersion
                    Reader           = $PublicationReader
                }
                $recovered = Get-PSModuleGalleryRecoveryVersion @recoveryParameters
                if ($null -ne $recovered) {
                    return $recovered
                }
            }
        }
        $latestVersion = Get-LatestPublishedVersion -GitHubVersion $GitHubVersion -PSGalleryVersion $PSGalleryVersion
        $params = @{
            LatestVersion = $latestVersion
            Decision      = $Decision
            Configuration = $Configuration
            ModuleName    = $ModuleName
            Releases      = $Releases
        }
        $resolvedVersion = Get-NextModuleVersion @params

        $resolvedVersion
    }
}

function Write-ActionOutput {
    <#
        .SYNOPSIS
        Emits the resolved version and release type as GitHub Actions step outputs.

        .EXAMPLE
        Write-ActionOutput -Decision $decision -NewVersion $newVersion
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside LogGroup script block.')]
    [CmdletBinding()]
    param(
        # The release decision object.
        [Parameter(Mandatory)]
        [PSCustomObject] $Decision,

        # The resolved next version.
        [Parameter(Mandatory)]
        [object] $NewVersion
    )

    LogGroup 'Emit outputs' {
        $versionString = "$($NewVersion.Major).$($NewVersion.Minor).$($NewVersion.Patch)"
        $prereleaseString = [string]$NewVersion.Prerelease
        $fullVersionString = $NewVersion.ToString()

        $resolvedReleaseType = if ($Decision.ShouldPublish) {
            if ($Decision.CreateRelease) { 'Release' } else { 'Prerelease' }
        } else {
            'None'
        }

        Add-Content -Path $env:GITHUB_OUTPUT -Value "Version=$versionString"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "Prerelease=$prereleaseString"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "FullVersion=$fullVersionString"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "ReleaseType=$resolvedReleaseType"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "CreateRelease=$($Decision.ShouldPublish.ToString().ToLower())"

        Write-Host '-------------------------------------------------'
        Write-Host ([PSCustomObject]@{
                Version       = $versionString
                Prerelease    = $prereleaseString
                FullVersion   = $fullVersionString
                ReleaseType   = $resolvedReleaseType
                CreateRelease = $Decision.ShouldPublish
            } | Format-List | Out-String)
        Write-Host '-------------------------------------------------'
    }
}
