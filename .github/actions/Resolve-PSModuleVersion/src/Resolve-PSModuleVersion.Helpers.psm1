function Split-CommaSeparatedList {
    <#
        .SYNOPSIS
        Split a comma-separated string into a trimmed, non-empty array.

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

function Resolve-DefaultBump {
    <#
        .SYNOPSIS
        Validates and returns the configured default version bump.

        .DESCRIPTION
        Rejects missing, invalid, and noncanonical values rather than using a
        fallback to recover from invalid configuration.

        .EXAMPLE
        Resolve-DefaultBump -DefaultBump 'patch'

        Returns the validated patch level.

        .INPUTS
        None

        You can't pipe objects to Resolve-DefaultBump.

        .OUTPUTS
        System.String

        The validated lowercase version-bump level.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The default bump name.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $DefaultBump
    )

    $validDefaultBumps = @('patch', 'minor', 'major')
    if ($validDefaultBumps -cnotcontains $DefaultBump) {
        throw (
            "Invalid Publish.Module.DefaultBump: [$DefaultBump]. " +
            "Valid values are: $($validDefaultBumps -join ', ')."
        )
    }

    $DefaultBump
}

function Read-ActionInput {
    <#
        .SYNOPSIS
        Read and validate action inputs from environment variables.

        .DESCRIPTION
        The function reads the module name and settings JSON from GitHub Actions environment variables.
        If the module name input is not provided, it uses the repository name.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        An object with Name and SettingsJson properties.

        .EXAMPLE
        $actionInput = Read-ActionInput
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Set-GitHubLogGroup 'Load inputs' {
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
        Parse the settings JSON into a publish configuration object.

        .DESCRIPTION
        The function extracts module publish settings: default bump, version prefix,
        release type, cleanup-only event state, and all five label mappings.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        An object with publish configuration properties.

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

    Set-GitHubLogGroup 'Resolve configuration' {
        $settings = $SettingsJson | ConvertFrom-Json
        $publishModule = $settings.Publish.Module
        if ($publishModule.PSObject.Properties.Name -contains 'AutoPatching') {
            throw 'Publish.Module.AutoPatching was removed. Replace it with Publish.Module.DefaultBump.'
        }
        $defaultBump = Resolve-DefaultBump -DefaultBump ([string]$publishModule.DefaultBump)
        $context = $settings.Context
        $isCleanupOnly = $context.EventName -eq 'pull_request' -and (
            $context.EventAction -eq 'closed' -or $context.PullRequest.Closed
        )

        $config = [PSCustomObject]@{
            Skip                  = [bool]$publishModule.Skip
            DefaultBump           = $defaultBump
            DefaultBumpSource     = [string]($publishModule.DefaultBumpSource ?? 'Publish.Module.DefaultBump')
            IncrementalPrerelease = [bool]$publishModule.IncrementalPrerelease
            DatePrereleaseFormat  = [string]$publishModule.DatePrereleaseFormat
            VersionPrefix         = [string]$publishModule.VersionPrefix
            ReleaseType           = [string]$publishModule.ReleaseType
            IsCleanupOnly         = $isCleanupOnly
            IgnoreLabels          = Split-CommaSeparatedList ([string]$publishModule.IgnoreLabels)
            MajorLabels           = Split-CommaSeparatedList ([string]$publishModule.MajorLabels)
            MinorLabels           = Split-CommaSeparatedList ([string]$publishModule.MinorLabels)
            PatchLabels           = Split-CommaSeparatedList ([string]$publishModule.PatchLabels)
            PrereleaseLabels      = Split-CommaSeparatedList -Value ([string]$publishModule.PrereleaseLabels)
        }

        Write-Host '-------------------------------------------------'
        Write-Host ([PSCustomObject]@{
                Skip                  = $config.Skip
                DefaultBump           = $config.DefaultBump
                DefaultBumpSource     = $config.DefaultBumpSource
                IncrementalPrerelease = $config.IncrementalPrerelease
                DatePrereleaseFormat  = $config.DatePrereleaseFormat
                VersionPrefix         = $config.VersionPrefix
                ReleaseType           = $config.ReleaseType
                IsCleanupOnly         = $config.IsCleanupOnly
                IgnoreLabels          = $config.IgnoreLabels -join ', '
                MajorLabels           = $config.MajorLabels -join ', '
                MinorLabels           = $config.MinorLabels -join ', '
                PatchLabels           = $config.PatchLabels -join ', '
                PrereleaseLabels      = $config.PrereleaseLabels -join ', '
            } | Format-List | Out-String)
        Write-Host '-------------------------------------------------'

        $config
    }
}

function Get-GitHubPullRequest {
    <#
        .SYNOPSIS
        Read normalized pull-request context from settings, with event-payload fallback.

        .DESCRIPTION
        The settings action resolves the pull request for a default-branch push before this action runs.
        If no pull request exists, a direct push or manual dispatch on the default branch receives release context.
        This context resolves the configured default bump.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        An object with pull-request metadata, or a default-branch direct-release context with no pull-request number.

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

    Set-GitHubLogGroup 'Event information' {
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
                Write-Host 'Using direct default-branch release context with the configured default bump.'
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
        Find whether to publish a release and which version bump to apply.

        .DESCRIPTION
        The function evaluates the PR labels against the configured label categories and release type
        to produce a complete release decision. Open non-publishing previews validate the same intent;
        closed-PR cleanup does not resolve a version.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        An object with ShouldPublish, CreateRelease, CreatePrerelease, MajorRelease,
        MinorRelease, PatchRelease, HasVersionBump, PrereleaseName, and BumpSource properties.

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

    Set-GitHubLogGroup 'Determine release configuration' {
        $prereleaseName = $PullRequest.HeadRef -replace '[^a-zA-Z0-9]'
        $labels = $PullRequest.Labels
        $releaseType = $Configuration.ReleaseType
        $defaultBump = Resolve-DefaultBump -DefaultBump ([string]$Configuration.DefaultBump)

        $validReleaseTypes = @('Release', 'Prerelease', 'None')
        if ([string]::IsNullOrWhiteSpace($releaseType)) {
            throw "Settings.Publish.Module.ReleaseType is required. Valid values are: $($validReleaseTypes -join ', ')"
        }
        if ($releaseType -notin $validReleaseTypes) {
            throw "Invalid ReleaseType: [$releaseType]. Valid values are: $($validReleaseTypes -join ', ')"
        }

        $createRelease = $releaseType -eq 'Release'
        $createPrerelease = $releaseType -eq 'Prerelease'
        $shouldPublish = ($createRelease -or $createPrerelease) -and $Configuration.Skip -ne $true
        if ($Configuration.Skip -eq $true) {
            $createRelease = $false
        }
        $isCleanupOnly = $Configuration.IsCleanupOnly -eq $true

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
                BumpSource       = 'ClosedPullRequest'
            }
        }

        $ignoreRelease = ($labels | Where-Object { $Configuration.IgnoreLabels -contains $_ }).Count -gt 0
        $prereleaseLabels = @($labels | Where-Object { $Configuration.PrereleaseLabels -contains $_ })

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
        if ($ignoreRelease -and $prereleaseLabels.Count -gt 0) {
            throw 'The ignore label cannot be combined with prerelease intent.'
        }
        if ($ignoreRelease) {
            $skipLabel = @($labels | Where-Object { $Configuration.IgnoreLabels -contains $_ })[0]
            Write-Host "No release or new version is resolved: [$skipLabel]."
            return [PSCustomObject]@{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $false
                HasVersionBump   = $false
                PrereleaseName   = ''
                BumpSource       = "Label:$skipLabel"
            }
        }

        $majorRelease = $majorLabels.Count -eq 1
        $minorRelease = $minorLabels.Count -eq 1
        $patchRelease = $patchLabels.Count -eq 1

        if (-not $majorRelease -and -not $minorRelease -and -not $patchRelease) {
            switch -CaseSensitive ($defaultBump) {
                'major' { $majorRelease = $true }
                'minor' { $minorRelease = $true }
                'patch' { $patchRelease = $true }
            }
        }
        $hasVersionBump = $majorRelease -or $minorRelease -or $patchRelease
        $bumpSource = if ($versionLabels.Count -eq 1) {
            "Label:$($versionLabels[0])"
        } else {
            [string]($Configuration.DefaultBumpSource ?? 'Publish.Module.DefaultBump')
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
                DefaultBump      = $defaultBump
                BumpSource       = $bumpSource
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
            BumpSource       = $bumpSource
        }
    }
}

function ConvertFrom-GitHubReleaseJson {
    <#
        .SYNOPSIS
        Convert the JSON output of 'gh release list' into a flat array of release objects.

        .DESCRIPTION
        The function normalizes the release list.
        If the repository has no releases or the command produces no output, the result is an empty array instead of $null.

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
        Get all releases from the current GitHub repository.

        .DESCRIPTION
        The function lists releases from the current repository. If the repository has no releases, it produces no output.
        Callers use @() to normalize the result.

        .OUTPUTS
        Array of release objects. Nothing when the repository has no releases.

        .EXAMPLE
        $releases = @(Get-GitHubRelease)
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param()

    Set-GitHubLogGroup 'Get releases - GitHub' {
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
        Get the latest stable version from a GitHub releases list.

        .DESCRIPTION
        The function returns the version of the release marked as latest.
        If the repository has no releases or no release has the latest marker, the function returns '0.0.0'.
        This baseline lets the workflow set a module version before the first release.

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

    Set-GitHubLogGroup 'Get latest version - GitHub' {
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
        Find the latest stable version of a module in the PowerShell Gallery.

        .DESCRIPTION
        The function queries the PowerShell Gallery for the latest published version of the module.
        It retries up to five times, with a ten-second delay between attempts.

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

    Set-GitHubLogGroup 'Get latest version - PSGallery' {
        $retryCount = 5
        $retryDelaySeconds = 10
        $latest = $null

        for ($i = 1; $i -le $retryCount; $i++) {
            try {
                Write-Host "Finding module [$ModuleName] in the PowerShell Gallery."
                $latest = Find-PSResource -Name $ModuleName -Repository PSGallery -Verbose:$false
                Write-Host ($latest | Format-Table | Out-String)
                break
            } catch {
                if ($i -eq $retryCount) {
                    Write-Warning "Failed to find the module [$ModuleName] in the PowerShell Gallery."
                    Write-Warning $_.Exception.Message
                }
                Start-Sleep -Seconds $retryDelaySeconds
            }
        }

        $version = if ($latest.Version) {
            New-PSSemVer -Version ($latest.Version).ToString()
        } else {
            Write-Warning "Could not find module online. Using '0.0.0'."
            New-PSSemVer -Version '0.0.0'
        }

        Write-Host "PSGallery version: [$($version.ToString())]"
        $version
    }
}

function Get-LatestPublishedVersion {
    <#
        .SYNOPSIS
        Return the highest version between GitHub and the PowerShell Gallery.

        .DESCRIPTION
        The function compares the two known published versions and returns the highest one.
        If a version is missing (null), the function treats it as '0.0.0'.
        A module with no GitHub release or PowerShell Gallery publication has a '0.0.0' baseline.

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

    Set-GitHubLogGroup 'Latest version' {
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
        Calculate the next incremental prerelease number across GitHub and PSGallery.

        .DESCRIPTION
        The function queries GitHub releases and the PowerShell Gallery for prereleases that match the base version and prerelease name.
        It returns the next number, zero-padded to three digits.

        .OUTPUTS
        System.String

        A zero-padded three-digit number (e.g. '001').

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
        ErrorAction = 'SilentlyContinue'
    }
    $matchingPSGalleryPrereleases = Find-PSResource @params |
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
        Calculate the next module version from the release decision.

        .DESCRIPTION
        The function increments the current version for the major, minor, or patch version bump.
        It can append a prerelease suffix with date-based and incremental numbering.

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

    Set-GitHubLogGroup 'Calculate new version' {
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

function Get-ResolvedModuleVersion {
    <#
        .SYNOPSIS
        Resolve the next module version and resume an incomplete stable release when possible.

        .DESCRIPTION
        The highest version from GitHub Releases and the PowerShell Gallery is normally the version baseline.
        If Gallery contains exactly the stable version implied by the latest GitHub release and this run's version bump,
        Gallery publication succeeded. GitHub release creation did not succeed in this case.
        The function returns the Gallery version instead of another version bump so the workflow can resume the missing GitHub release.

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
        [array] $Releases = @()
    )

    Set-GitHubLogGroup 'Resolve module version' {
        $latestVersion = Get-LatestPublishedVersion -GitHubVersion $GitHubVersion -PSGalleryVersion $PSGalleryVersion
        $params = @{
            LatestVersion = $latestVersion
            Decision      = $Decision
            Configuration = $Configuration
            ModuleName    = $ModuleName
            Releases      = $Releases
        }
        $resolvedVersion = Get-NextModuleVersion @params

        if ($Decision.CreateRelease) {
            $githubParams = $params.Clone()
            $githubParams.LatestVersion = $GitHubVersion
            $githubCandidate = Get-NextModuleVersion @githubParams
            $galleryVersionString = "$($PSGalleryVersion.Major).$($PSGalleryVersion.Minor).$($PSGalleryVersion.Patch)"
            $githubCandidateString = "$($githubCandidate.Major).$($githubCandidate.Minor).$($githubCandidate.Patch)"

            if ([string]::IsNullOrWhiteSpace($PSGalleryVersion.Prerelease) -and
                $galleryVersionString -eq $githubCandidateString) {
                Write-Host (
                    "PowerShell Gallery contains [$galleryVersionString], the next stable version after " +
                    "GitHub [$GitHubVersion]. Resuming the Gallery-only publication."
                )
                $resolvedVersion = $githubCandidate
            }
        }

        $resolvedVersion
    }
}

function Write-ActionOutput {
    <#
        .SYNOPSIS
        Write the resolved version and release type as GitHub Actions step outputs.

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

    Set-GitHubLogGroup 'Emit outputs' {
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
