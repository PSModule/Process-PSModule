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
        Reads and validates the GitHub pull request from the event payload.

        .DESCRIPTION
        Loads the GitHub event from the input override or from the event path file. On a
        pull_request event it returns the pull request head ref and labels. On any other
        event (for example workflow_dispatch or schedule) there is no pull request, so it
        returns $null and the caller resolves the current version without a version bump.

        .OUTPUTS
        PSCustomObject with HeadRef and Labels properties for a pull_request event, or
        $null when the event has no pull request (non-PR events).

        .EXAMPLE
        $pullRequest = Get-GitHubPullRequest
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    LogGroup 'Event information' {
        $eventJsonInput = $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson
        $githubEvent = if (-not [string]::IsNullOrWhiteSpace($eventJsonInput)) {
            $eventJsonInput | ConvertFrom-Json
        } else {
            Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json
        }

        $pr = $githubEvent.pull_request
        if (-not $pr) {
            Write-Host 'GitHub event does not contain pull_request data (non-PR event, e.g. workflow_dispatch or schedule).'
            Write-Host 'No pull request context is available; the caller keeps the current version without a bump.'
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

        $ignoreRelease = ($labels | Where-Object { $Configuration.IgnoreLabels -contains $_ }).Count -gt 0
        if ($ignoreRelease -and $shouldPublish) {
            Write-Host 'Ignoring release creation due to ignore label.'
            $shouldPublish = $false
        }

        # Always evaluate the version-bump labels so the resolved version reflects what WOULD be
        # created, regardless of whether this run publishes. ReleaseType (and the prerelease label
        # that drives it) only controls whether and how we publish - never the version increment.
        $majorRelease = ($labels | Where-Object { $Configuration.MajorLabels -contains $_ }).Count -gt 0
        $minorRelease = ($labels | Where-Object { $Configuration.MinorLabels -contains $_ }).Count -gt 0 -and -not $majorRelease
        $patchRelease = (
            (($labels | Where-Object { $Configuration.PatchLabels -contains $_ }).Count -gt 0) -or $Configuration.AutoPatching
        ) -and -not $majorRelease -and -not $minorRelease

        $hasVersionBump = $majorRelease -or $minorRelease -or $patchRelease
        if (-not $hasVersionBump) {
            # No explicit bump label and no AutoPatching: still resolve a patch version so the run
            # can preview what it would create, but do not publish a full release for an unlabeled change.
            Write-Host 'No version bump label and AutoPatching disabled; previewing a patch version without publishing.'
            $patchRelease = $true
            $hasVersionBump = $true
            $shouldPublish = $false
        }

        # Anything that is not a published full release is surfaced as a prerelease - either a
        # published prerelease (ShouldPublish) or a non-published preview.
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

function Get-GitHubRelease {
    <#
        .SYNOPSIS
        Retrieves all releases from the current GitHub repository.

        .OUTPUTS
        Array of release objects.

        .EXAMPLE
        $releases = Get-GitHubRelease
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
        # A repository that has never released returns '[]', which deserializes to nothing. Wrap the
        # result so callers always receive an array, even for a module being bootstrapped.
        $releases = @($releasesJson | ConvertFrom-Json)

        Write-Host '-------------------------------------------------'
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
        # The GitHub releases array to search.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array] $Releases
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
        Retries up to five times with a ten-second delay between attempts.

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
        Returns the highest version between GitHub and the PowerShell Gallery.

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
        # The latest version found in GitHub releases.
        [Parameter(Mandatory)]
        [object] $GitHubVersion,

        # The latest version found in the PowerShell Gallery.
        [Parameter(Mandatory)]
        [object] $PSGalleryVersion
    )

    LogGroup 'Latest version' {
        $latestVersion = New-PSSemVer -Version (
            $PSGalleryVersion, $GitHubVersion | Sort-Object -Descending | Select-Object -First 1
        )
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

        # The GitHub releases list.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array] $Releases
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
        # The current latest published version.
        [Parameter(Mandatory)]
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
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array] $Releases
    )

    LogGroup 'Calculate new version' {
        $newVersion = New-PSSemVer -Version $LatestVersion
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
