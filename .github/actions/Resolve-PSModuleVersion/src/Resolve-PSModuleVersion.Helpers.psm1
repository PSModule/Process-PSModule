function Read-ActionInput {
    <#
        .SYNOPSIS
        Reads and validates action inputs from environment variables.

        .DESCRIPTION
        Reads the module name and settings JSON from GitHub Actions environment variables.
        Falls back to the repository name when the module name input is not provided.

        .OUTPUTS
        PSCustomObject with Name, SettingsJson, and ReleaseDecision properties.

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
            Name            = $name
            SettingsJson    = $settingsJson
            ReleaseDecision = [string]$env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_ReleaseDecision
        }
    }
}

function Get-PublishConfiguration {
    <#
        .SYNOPSIS
        Parses the settings JSON into a publish configuration object.

        .DESCRIPTION
        Extracts publish module settings used to format versions and prereleases.

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
            IncrementalPrerelease = [bool]$publishModule.IncrementalPrerelease
            DatePrereleaseFormat  = [string]$publishModule.DatePrereleaseFormat
            VersionPrefix         = [string]$publishModule.VersionPrefix
        }

        Write-Host '-------------------------------------------------'
        Write-Host ([PSCustomObject]@{
                IncrementalPrerelease = $config.IncrementalPrerelease
                DatePrereleaseFormat  = $config.DatePrereleaseFormat
                VersionPrefix         = $config.VersionPrefix
            } | Format-List | Out-String)
        Write-Host '-------------------------------------------------'

        $config
    }
}

function Get-ReleaseContext {
    <#
        .SYNOPSIS
        Reads normalized release context from settings, with event-payload fallback.

        .DESCRIPTION
        The settings action resolves a pull request associated with a default-branch
        push before this action runs. Pull requests use canonical labels, while a
        release-capable event without a pull request uses the explicit action input.

        .OUTPUTS
        PSCustomObject describing whether the run is a pull request, stable release,
        cleanup, or validation context.

        .EXAMPLE
        $releaseContext = Get-ReleaseContext -SettingsJson $actionInput.SettingsJson `
            -ReleaseDecision $actionInput.ReleaseDecision
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside a LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The complete settings object, including normalized workflow context.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SettingsJson,

        # Explicit canonical decision for a release-capable event without a pull request.
        [Parameter()]
        [AllowEmptyString()]
        [string] $ReleaseDecision = ''
    )

    LogGroup 'Event information' {
        $settings = $SettingsJson | ConvertFrom-Json
        $context = $settings.Context
        if ($context) {
            $contextPullRequest = $context.PullRequest
            $eventName = [string]$context.EventName
            $eventAction = [string]$context.EventAction
            $isCleanupOnly = $eventName -eq 'pull_request' -and $eventAction -eq 'closed'

            if ($isCleanupOnly) {
                Write-Host 'Using cleanup-only closed pull request context.'
                return [PSCustomObject]@{
                    Type                = 'Cleanup'
                    DecisionSource      = 'None'
                    RequiresDecision    = $false
                    CanPublish          = $false
                    HasImportantChanges = [bool]$settings.HasImportantChanges
                    Number              = $contextPullRequest.Number
                    HeadRef             = [string]$contextPullRequest.HeadRef
                    Labels              = @()
                    IsDirectRelease     = $false
                }
            }

            if ($contextPullRequest) {
                if ($eventName -notin @('pull_request', 'push')) {
                    Write-Host "Ignoring pull request data in unsupported [$eventName] release context."
                    return [PSCustomObject]@{
                        Type                = 'Validation'
                        DecisionSource      = 'None'
                        RequiresDecision    = $false
                        CanPublish          = $false
                        HasImportantChanges = [bool]$settings.HasImportantChanges
                        Number              = $contextPullRequest.Number
                        HeadRef             = [string]$contextPullRequest.HeadRef
                        Labels              = @()
                        IsDirectRelease     = $false
                    }
                }

                Write-Host "Using normalized pull request context for #$($contextPullRequest.Number)."
                $isStableContext = $eventName -eq 'push'
                return [PSCustomObject]@{
                    Type                = if ($isStableContext) { 'Stable' } else { 'PullRequest' }
                    DecisionSource      = 'Labels'
                    RequiresDecision    = $true
                    CanPublish          = if ($isStableContext) {
                        [bool]$context.IsPushToDefaultBranch
                    } else {
                        $true
                    }
                    HasImportantChanges = [bool]$settings.HasImportantChanges
                    Number              = $contextPullRequest.Number
                    HeadRef             = [string]$contextPullRequest.HeadRef
                    Labels              = @($contextPullRequest.Labels)
                    IsDirectRelease     = $false
                }
            }

            if ($eventName -in @('push', 'workflow_dispatch')) {
                Write-Host "Using explicit [$eventName] release context."
                return [PSCustomObject]@{
                    Type                = 'Stable'
                    DecisionSource      = 'Input'
                    RequiresDecision    = $true
                    CanPublish          = [bool](
                        $context.IsPushToDefaultBranch -or
                        $context.IsManualDispatchToDefaultBranch
                    )
                    HasImportantChanges = [bool]$settings.HasImportantChanges
                    Number              = $null
                    HeadRef             = [string]$context.DefaultBranch
                    Labels              = @()
                    ExplicitDecision    = $ReleaseDecision
                    IsDirectRelease     = $true
                }
            }

            Write-Host "Using validation-only [$eventName] context."
            return [PSCustomObject]@{
                Type                = 'Validation'
                DecisionSource      = 'None'
                RequiresDecision    = $false
                CanPublish          = $false
                HasImportantChanges = [bool]$settings.HasImportantChanges
                Number              = $null
                HeadRef             = [string]$context.DefaultBranch
                Labels              = @()
                IsDirectRelease     = $false
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
            $eventName = [string]$env:GITHUB_EVENT_NAME
            if ($eventName -in @('push', 'workflow_dispatch')) {
                throw "Cannot authorize [$eventName] publication without normalized default-branch context."
            }

            Write-Host 'GitHub event does not contain pull_request data and no release context was normalized.'
            return [PSCustomObject]@{
                Type                = 'Validation'
                DecisionSource      = 'None'
                RequiresDecision    = $false
                CanPublish          = $false
                HasImportantChanges = [bool]$settings.HasImportantChanges
                Number              = $null
                HeadRef             = ''
                Labels              = @()
                IsDirectRelease     = $false
            }
        }

        $labels = @()
        $labels += $pr.labels.name

        Write-Host '-------------------------------------------------'
        Write-Host ([PSCustomObject]@{
                PRHeadRef = $pr.head.ref
                Labels    = $labels -join ', '
            } | Format-List | Out-String)
        Write-Host '-------------------------------------------------'

        $isCleanupOnly = [string]$githubEvent.action -eq 'closed'
        $defaultBranch = [string]$githubEvent.repository.default_branch
        $targetsDefaultBranch = (
            -not [string]::IsNullOrWhiteSpace($defaultBranch) -and
            [string]$pr.base.ref -eq $defaultBranch
        )
        [PSCustomObject]@{
            Type                = if ($isCleanupOnly) { 'Cleanup' } else { 'PullRequest' }
            DecisionSource      = if ($isCleanupOnly) { 'None' } else { 'Labels' }
            RequiresDecision    = -not $isCleanupOnly
            CanPublish          = -not $isCleanupOnly -and $targetsDefaultBranch
            HasImportantChanges = [bool]$settings.HasImportantChanges
            Number              = $pr.number
            HeadRef             = [string]$pr.head.ref
            Labels              = if ($isCleanupOnly) { @() } else { $labels }
            IsDirectRelease     = $false
        }
    }
}

function Resolve-ReleaseDecision {
    <#
        .SYNOPSIS
        Determines whether to publish a release and what kind of version bump to apply.

        .DESCRIPTION
        Evaluates only the canonical release labels or the explicit non-PR input.
        Missing, conflicting, and invalid release-capable decisions fail closed.

        .OUTPUTS
        PSCustomObject with ShouldPublish, CreateRelease, CreatePrerelease, MajorRelease,
        MinorRelease, PatchRelease, HasVersionBump, and PrereleaseName properties.

        .EXAMPLE
        $decision = Resolve-ReleaseDecision -ReleaseContext $releaseContext
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The normalized release context.
        [Parameter(Mandatory)]
        [PSCustomObject] $ReleaseContext
    )

    LogGroup 'Determine release configuration' {
        $prereleaseName = [string]$ReleaseContext.HeadRef -replace '[^a-zA-Z0-9]'
        if (-not $ReleaseContext.RequiresDecision) {
            return [PSCustomObject]@{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $false
                HasVersionBump   = $false
                PrereleaseName   = $prereleaseName
                SkipRelease      = $false
                Bump             = 'None'
            }
        }

        $bumpLabelTypes = [ordered]@{
            'release:patch' = 'Patch'
            'release:minor' = 'Minor'
            'release:major' = 'Major'
        }
        $ownedLabelNames = @($bumpLabelTypes.Keys) + @('release:pre-release', 'release:skip')
        $ownedLabels = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::Ordinal
        )

        if ($ReleaseContext.DecisionSource -eq 'Input') {
            $explicitDecision = [string]$ReleaseContext.ExplicitDecision
            $validInputDecisions = @($bumpLabelTypes.Keys) + @('release:skip')
            if ($validInputDecisions -cnotcontains $explicitDecision) {
                throw (
                    "Invalid or missing ReleaseDecision: [$explicitDecision]. Specify exactly one of " +
                    "$($validInputDecisions -join ', ')."
                )
            }
            $null = $ownedLabels.Add($explicitDecision)
        } else {
            foreach ($label in @($ReleaseContext.Labels)) {
                if ($ownedLabelNames -ccontains $label) {
                    $null = $ownedLabels.Add($label)
                }
            }
        }

        $hasSkip = $ownedLabels.Contains('release:skip')
        $hasPrerelease = $ownedLabels.Contains('release:pre-release')
        $bumpLabels = @($bumpLabelTypes.Keys | Where-Object { $ownedLabels.Contains($_) })

        if ($hasSkip) {
            if ($ownedLabels.Count -ne 1) {
                throw 'Invalid release labels: release:skip must not be combined with another release label.'
            }
        } elseif ($bumpLabels.Count -eq 0) {
            if ($hasPrerelease) {
                throw 'Invalid release labels: release:pre-release requires exactly one release bump label.'
            }
            throw (
                'Release decision is missing. Apply exactly one of release:patch, release:minor, ' +
                'release:major, or release:skip.'
            )
        } elseif ($bumpLabels.Count -gt 1) {
            throw "Conflicting release bump labels: [$($bumpLabels -join ', ')]. Apply exactly one bump label."
        }

        $bump = if ($bumpLabels.Count -eq 1) { $bumpLabelTypes[$bumpLabels[0]] } else { 'None' }
        $majorRelease = $bump -eq 'Major'
        $minorRelease = $bump -eq 'Minor'
        $patchRelease = $bump -eq 'Patch'
        $hasVersionBump = $majorRelease -or $minorRelease -or $patchRelease
        $canPublish = [bool]$ReleaseContext.CanPublish -and [bool]$ReleaseContext.HasImportantChanges
        $createRelease = -not $hasSkip -and $ReleaseContext.Type -eq 'Stable' -and $canPublish
        $publishPrerelease = (
            -not $hasSkip -and
            $ReleaseContext.Type -eq 'PullRequest' -and
            $hasPrerelease -and
            $canPublish
        )
        $shouldPublish = $createRelease -or $publishPrerelease
        $createPrerelease = (
            -not $hasSkip -and
            $ReleaseContext.Type -eq 'PullRequest' -and
            $hasVersionBump
        )
        if ($createPrerelease -and [string]::IsNullOrWhiteSpace($prereleaseName)) {
            throw 'Cannot create a pull-request preview version because the head branch name is missing.'
        }

        Write-Host '-------------------------------------------------'
        Write-Host ([PSCustomObject]@{
                ContextType       = $ReleaseContext.Type
                ShouldPublish     = $shouldPublish
                CreateRelease     = $createRelease
                PublishPrerelease = $publishPrerelease
                PreviewVersion    = $createPrerelease
                Skip              = $hasSkip
                Bump              = $bump
                Major             = $majorRelease
                Minor             = $minorRelease
                Patch             = $patchRelease
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
            SkipRelease      = $hasSkip
            Bump             = $bump
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

function Get-ResolvedModuleVersion {
    <#
        .SYNOPSIS
        Resolves the next module version and resumes an incomplete stable release when possible.

        .DESCRIPTION
        Normally the highest version from GitHub Releases and the PowerShell Gallery is the
        version baseline. If Gallery contains exactly the stable version implied by the latest
        GitHub release and this run's version bump, Gallery publication succeeded but GitHub
        release creation did not. In that case, return the Gallery version rather than bumping
        again so the workflow can resume the missing GitHub release.

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

    LogGroup 'Resolve module version' {
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
