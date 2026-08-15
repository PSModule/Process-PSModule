#Requires -Modules powershell-yaml

<#
    .SYNOPSIS
    Inventories caller workflows that use the Process-PSModule reusable workflow.

    .DESCRIPTION
    Discovers Process-PSModule caller workflows from either the authenticated GitHub
    organization or local Git checkouts. Outputs structured objects and can refresh
    JSON and Markdown reports.

    GitHub mode uses the GitHub CLI. Authenticate with GH_TOKEN or gh auth login.
    Local mode accepts repository paths or parent directories containing repositories.

    .EXAMPLE
    ./.github/scripts/Get-ProcessPSModuleWorkflowInventory.ps1 `
        -Organization PSModule `
        -JsonPath ./output/process-workflows.json `
        -MarkdownPath ./output/process-workflows.md

    Inventories the PSModule organization through the GitHub API and writes both report formats.

    .EXAMPLE
    ./.github/scripts/Get-ProcessPSModuleWorkflowInventory.ps1 `
        -Path C:\Repos, C:\Users\me\.copilot\repos `
        -MarkdownPath ./output/process-workflows.md

    Recursively discovers local Git repositories below the supplied paths.
#>
[CmdletBinding(DefaultParameterSetName = 'GitHub')]
param(
    [Parameter(ParameterSetName = 'GitHub')]
    [ValidateNotNullOrEmpty()]
    [string] $Organization = 'PSModule',

    [Parameter(ParameterSetName = 'GitHub')]
    [ValidateNotNullOrEmpty()]
    [string[]] $Repository,

    [Parameter(Mandatory, ParameterSetName = 'Local')]
    [ValidateNotNullOrEmpty()]
    [string[]] $Path,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $WorkflowReference = 'PSModule/Process-PSModule/.github/workflows/workflow.yml',

    [Parameter()]
    [string] $JsonPath,

    [Parameter()]
    [string] $MarkdownPath,

    [Parameter(ParameterSetName = 'GitHub')]
    [switch] $IncludeArchived
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GhCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $ArgumentList
    )

    $output = (& gh @ArgumentList 2>&1) -join "`n"
    if ($LASTEXITCODE -eq 0) {
        return $output
    }

    throw "gh $($ArgumentList -join ' ') failed:`n$output"
}

function ConvertFrom-JsonResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return @()
    }

    @($Content | ConvertFrom-Json -Depth 100)
}

function Get-GitHubRepository {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Owner,

        [Parameter()]
        [string[]] $NameWithOwner,

        [Parameter()]
        [switch] $IncludeArchivedRepository
    )

    if ($NameWithOwner) {
        $repositories = foreach ($name in $NameWithOwner) {
            $fullName = if ($name.Contains('/')) { $name } else { "$Owner/$name" }
            $response = Invoke-GhCommand -ArgumentList @(
                'repo', 'view', $fullName,
                '--json', 'nameWithOwner,defaultBranchRef,isArchived,url'
            )
            ConvertFrom-JsonResponse -Content $response
        }
    } else {
        $response = Invoke-GhCommand -ArgumentList @(
            'repo', 'list', $Owner,
            '--limit', '1000',
            '--json', 'nameWithOwner,defaultBranchRef,isArchived,url'
        )
        $repositories = ConvertFrom-JsonResponse -Content $response
    }

    @($repositories |
            Where-Object { $IncludeArchivedRepository -or -not $_.isArchived } |
            Sort-Object nameWithOwner)
}

function Get-GitHubMatchingWorkflowFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject[]] $RepositoryInfo,

        [Parameter(Mandatory)]
        [string] $Owner,

        [Parameter(Mandatory)]
        [string] $ExpectedReference
    )

    $query = "$ExpectedReference org:$Owner path:.github/workflows"
    $response = Invoke-GhCommand -ArgumentList @(
        'api',
        '--paginate',
        '--slurp',
        '-X',
        'GET',
        'search/code',
        '-f',
        "q=$query",
        '-f',
        'per_page=100'
    )
    $pages = @($response | ConvertFrom-Json -Depth 100)
    $searchResults = @($pages | ForEach-Object { $_.items })
    if (-not $searchResults) {
        throw "GitHub code search returned no matches for [$query]."
    }

    $repositoryByName = @{}
    foreach ($item in $RepositoryInfo) {
        $repositoryByName[$item.nameWithOwner] = $item
    }

    @($searchResults |
            Where-Object { $repositoryByName.ContainsKey($_.repository.full_name) } |
            Sort-Object { $_.repository.full_name }, path -Unique |
            ForEach-Object {
                $match = $_
                $repository = $repositoryByName[$match.repository.full_name]
                $branch = [uri]::EscapeDataString($repository.defaultBranchRef.name)
                [pscustomobject]@{
                    Repository    = $repository.nameWithOwner
                    DefaultBranch = $repository.defaultBranchRef.name
                    Archived      = $repository.isArchived
                    RepositoryUrl = $repository.url
                    WorkflowPath  = $match.path
                    WorkflowUrl   = $match.html_url
                    SearchQuery   = $query
                    Content       = Invoke-GhCommand -ArgumentList @(
                        'api',
                        "repos/$($repository.nameWithOwner)/contents/$($match.path)?ref=$branch",
                        '-H',
                        'Accept: application/vnd.github.raw+json'
                    )
                }
            })
}

function Get-LocalRepositoryRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $InputPath
    )

    $roots = foreach ($candidate in $InputPath) {
        $resolvedPath = (Resolve-Path -LiteralPath $candidate).Path
        if (Test-Path -LiteralPath (Join-Path $resolvedPath '.git')) {
            $resolvedPath
            continue
        }

        Get-ChildItem -LiteralPath $resolvedPath -Filter '.git' -Force -Recurse |
            ForEach-Object {
                if ($_.PSIsContainer) {
                    $_.Parent.FullName
                } else {
                    $_.DirectoryName
                }
            }
    }

    @($roots | Sort-Object -Unique)
}

function Get-LocalRepositoryName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryRoot
    )

    $remote = (& git -C $RepositoryRoot config --get remote.origin.url 2>$null) -join ''
    if ($LASTEXITCODE -eq 0 -and $remote -match '(?<owner>[^/:]+)/(?<repo>[^/]+?)(?:\.git)?$') {
        return "$($Matches.owner)/$($Matches.repo)"
    }

    Split-Path -Path $RepositoryRoot -Leaf
}

function Get-LocalDefaultBranch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryRoot
    )

    $originHead = (& git -C $RepositoryRoot symbolic-ref refs/remotes/origin/HEAD --short 2>$null) -join ''
    if ($LASTEXITCODE -eq 0 -and $originHead) {
        return $originHead -replace '^origin/', ''
    }

    $branch = (& git -C $RepositoryRoot branch --show-current 2>$null) -join ''
    if ($LASTEXITCODE -eq 0 -and $branch) {
        return $branch
    }

    $null
}

function Get-LocalWorkflowFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $InputPath
    )

    foreach ($repositoryRoot in Get-LocalRepositoryRoot -InputPath $InputPath) {
        $workflowRoot = Join-Path $repositoryRoot '.github/workflows'
        if (-not (Test-Path -LiteralPath $workflowRoot -PathType Container)) {
            continue
        }

        $repositoryName = Get-LocalRepositoryName -RepositoryRoot $repositoryRoot
        $defaultBranch = Get-LocalDefaultBranch -RepositoryRoot $repositoryRoot
        Get-ChildItem -LiteralPath $workflowRoot -File |
            Where-Object { $_.Extension -in @('.yml', '.yaml') } |
            ForEach-Object {
                [pscustomobject]@{
                    Repository    = $repositoryName
                    DefaultBranch = $defaultBranch
                    Archived      = $false
                    RepositoryUrl = $null
                    WorkflowPath  = [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName).Replace('\', '/')
                    WorkflowUrl   = $null
                    SearchQuery   = $null
                    Content       = Get-Content -LiteralPath $_.FullName -Raw
                }
            }
    }
}

function Get-MapKey {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Map
    )

    if ($null -eq $Map) {
        return @()
    }

    if ($Map -is [Collections.IDictionary]) {
        return @($Map.Keys | ForEach-Object { "$_" })
    }

    @($Map.PSObject.Properties.Name)
}

function Get-MapValue {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Map,

        [Parameter(Mandatory)]
        [string] $Name
    )

    if ($null -eq $Map) {
        return $null
    }

    if ($Map -is [Collections.IDictionary]) {
        return $Map[$Name]
    }

    $Map.PSObject.Properties[$Name].Value
}

function ConvertTo-StringMap {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Map
    )

    $result = [ordered]@{}
    foreach ($key in Get-MapKey -Map $Map) {
        $value = Get-MapValue -Map $Map -Name $key
        $result[$key] = if ($null -eq $value) { $null } else { "$value" }
    }
    $result
}

function ConvertTo-StringArray {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    @($Value | ForEach-Object { "$_" })
}

function Get-WorkflowInventoryItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject] $WorkflowFile,

        [Parameter(Mandatory)]
        [string] $ExpectedReference
    )

    if ($WorkflowFile.Content -notmatch [regex]::Escape($ExpectedReference)) {
        return
    }

    try {
        $workflow = ConvertFrom-Yaml -Yaml $WorkflowFile.Content -Ordered
    } catch {
        return [pscustomobject]@{
            Repository    = $WorkflowFile.Repository
            DefaultBranch = $WorkflowFile.DefaultBranch
            Archived      = $WorkflowFile.Archived
            RepositoryUrl = $WorkflowFile.RepositoryUrl
            WorkflowPath  = $WorkflowFile.WorkflowPath
            WorkflowUrl   = $WorkflowFile.WorkflowUrl
            SearchQuery   = $WorkflowFile.SearchQuery
            Status        = 'ParseError'
            Error         = $_.Exception.Message
        }
    }

    $jobs = Get-MapValue -Map $workflow -Name 'jobs'
    $processJobs = foreach ($jobName in Get-MapKey -Map $jobs) {
        $job = Get-MapValue -Map $jobs -Name $jobName
        $uses = Get-MapValue -Map $job -Name 'uses'
        if ("$uses" -notlike "$ExpectedReference@*") {
            continue
        }

        $secrets = Get-MapValue -Map $job -Name 'secrets'
        $secretMode = if ($secrets -is [string]) { "$secrets" } elseif ($null -eq $secrets) { 'none' } else { 'explicit' }
        [pscustomobject]@{
            Name           = $jobName
            Uses           = "$uses"
            Reference      = "$uses".Substring("$ExpectedReference@".Length)
            Inputs         = ConvertTo-StringMap -Map (Get-MapValue -Map $job -Name 'with')
            SecretMode     = $secretMode
            SecretMappings = if ($secretMode -eq 'explicit') {
                ConvertTo-StringMap -Map $secrets
            } else {
                [ordered]@{}
            }
            Environment    = Get-MapValue -Map $job -Name 'environment'
        }
    }

    if (-not $processJobs) {
        return
    }

    $trigger = Get-MapValue -Map $workflow -Name 'on'
    $pullRequest = Get-MapValue -Map $trigger -Name 'pull_request'
    $push = Get-MapValue -Map $trigger -Name 'push'
    $schedule = Get-MapValue -Map $trigger -Name 'schedule'
    $concurrency = Get-MapValue -Map $workflow -Name 'concurrency'
    $allJobNames = Get-MapKey -Map $jobs
    $processJobNames = @($processJobs.Name)

    $versionComments = @(
        [regex]::Matches(
            $WorkflowFile.Content,
            "(?m)^\s*uses:\s*$([regex]::Escape($ExpectedReference))@(?<reference>[^\s#]+)\s*(?:#\s*(?<version>\S+))?"
        ) | ForEach-Object {
            [pscustomobject]@{
                Reference = $_.Groups['reference'].Value
                Version   = $_.Groups['version'].Value
            }
        }
    )

    [pscustomobject]@{
        Repository          = $WorkflowFile.Repository
        DefaultBranch       = $WorkflowFile.DefaultBranch
        Archived            = $WorkflowFile.Archived
        RepositoryUrl       = $WorkflowFile.RepositoryUrl
        WorkflowPath        = $WorkflowFile.WorkflowPath
        WorkflowUrl         = $WorkflowFile.WorkflowUrl
        SearchQuery         = $WorkflowFile.SearchQuery
        Status              = 'Parsed'
        Error               = $null
        WorkflowName        = Get-MapValue -Map $workflow -Name 'name'
        Events              = @(Get-MapKey -Map $trigger | Sort-Object)
        Schedules           = @($schedule | ForEach-Object { Get-MapValue -Map $_ -Name 'cron' })
        PushBranches        = ConvertTo-StringArray -Value (Get-MapValue -Map $push -Name 'branches')
        PushBranchesIgnore  = ConvertTo-StringArray -Value (Get-MapValue -Map $push -Name 'branches-ignore')
        PushPaths           = ConvertTo-StringArray -Value (Get-MapValue -Map $push -Name 'paths')
        PushPathsIgnore     = ConvertTo-StringArray -Value (Get-MapValue -Map $push -Name 'paths-ignore')
        PullRequestBranches = ConvertTo-StringArray -Value (Get-MapValue -Map $pullRequest -Name 'branches')
        PullRequestTypes    = ConvertTo-StringArray -Value (Get-MapValue -Map $pullRequest -Name 'types')
        ConcurrencyGroup    = Get-MapValue -Map $concurrency -Name 'group'
        CancelInProgress    = Get-MapValue -Map $concurrency -Name 'cancel-in-progress'
        Permissions         = ConvertTo-StringMap -Map (Get-MapValue -Map $workflow -Name 'permissions')
        ProcessJobs         = @($processJobs)
        AdditionalJobs      = @($allJobNames | Where-Object { $_ -notin $processJobNames })
        VersionComments     = $versionComments
    }
}

function ConvertTo-MarkdownCell {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    (($Value -join ', ') -replace '\|', '\|' -replace '\r?\n', '<br>')
}

function ConvertTo-WorkflowInventoryMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject[]] $Inventory,

        [Parameter(Mandatory)]
        [ValidateSet('GitHub', 'Local')]
        [string] $Source
    )

    $parsed = @($Inventory | Where-Object Status -eq 'Parsed')
    $parseErrors = @($Inventory | Where-Object Status -eq 'ParseError')
    $references = @(
        $parsed |
            ForEach-Object { $_.ProcessJobs.Reference } |
            Group-Object |
            Sort-Object @{ Expression = 'Count'; Descending = $true }, Name
    )
    $eventSets = @(
        $parsed |
            ForEach-Object { $_.Events -join ', ' } |
            Group-Object |
            Sort-Object @{ Expression = 'Count'; Descending = $true }, Name
    )

    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('# Process-PSModule workflow inventory')
    $lines.Add('')
    $lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')")
    $lines.Add('')
    $lines.Add("- Source: $Source")
    $lines.Add("- Workflow files: $($Inventory.Count)")
    $lines.Add("- Parsed: $($parsed.Count)")
    $lines.Add("- Parse errors: $($parseErrors.Count)")
    $lines.Add('')
    $lines.Add('## Reference distribution')
    $lines.Add('')
    $lines.Add('| Reference | Workflows |')
    $lines.Add('| --- | ---: |')
    foreach ($group in $references) {
        $lines.Add("| $(ConvertTo-MarkdownCell $group.Name) | $($group.Count) |")
    }
    $lines.Add('')
    $lines.Add('## Trigger distribution')
    $lines.Add('')
    $lines.Add('| Events | Workflows |')
    $lines.Add('| --- | ---: |')
    foreach ($group in $eventSets) {
        $lines.Add("| $(ConvertTo-MarkdownCell $group.Name) | $($group.Count) |")
    }
    $lines.Add('')
    $lines.Add('## Workflow files')
    $lines.Add('')
    $lines.Add(
        '| Repository | File | Name | Events | Reference | Version | PR types | Push branches | Schedule |' +
        ' Concurrency | Cancel | Permissions | Secrets | Inputs | Extra jobs |'
    )
    $lines.Add(
        '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |'
    )

    foreach ($item in $Inventory | Sort-Object Repository, WorkflowPath) {
        if ($item.Status -eq 'ParseError') {
            $lines.Add(
                "| $(ConvertTo-MarkdownCell $item.Repository) " +
                "| $(ConvertTo-MarkdownCell $item.WorkflowPath) | parse error | | | | | | | | | | | | |"
            )
            continue
        }

        $referencesForItem = @($item.ProcessJobs.Reference | Sort-Object -Unique)
        $versionsForItem = @($item.VersionComments.Version | Where-Object { $_ } | Sort-Object -Unique)
        $secretSummary = @(
            $item.ProcessJobs | ForEach-Object {
                if ($_.SecretMode -eq 'explicit') {
                    "explicit: $(($_.SecretMappings.Keys | Sort-Object) -join ', ')"
                } else {
                    $_.SecretMode
                }
            }
        ) | Sort-Object -Unique
        $inputSummary = @(
            $item.ProcessJobs |
                ForEach-Object { $_.Inputs.Keys } |
                Sort-Object -Unique
        )
        $permissionSummary = @(
            $item.Permissions.GetEnumerator() |
                Sort-Object Key |
                ForEach-Object { "$($_.Key)=$($_.Value)" }
        )

        $lines.Add(
            "| $(ConvertTo-MarkdownCell $item.Repository) " +
            "| $(ConvertTo-MarkdownCell $item.WorkflowPath) " +
            "| $(ConvertTo-MarkdownCell $item.WorkflowName) " +
            "| $(ConvertTo-MarkdownCell $item.Events) " +
            "| $(ConvertTo-MarkdownCell $referencesForItem) " +
            "| $(ConvertTo-MarkdownCell $versionsForItem) " +
            "| $(ConvertTo-MarkdownCell $item.PullRequestTypes) " +
            "| $(ConvertTo-MarkdownCell $item.PushBranches) " +
            "| $(ConvertTo-MarkdownCell $item.Schedules) " +
            "| $(ConvertTo-MarkdownCell $item.ConcurrencyGroup) " +
            "| $(ConvertTo-MarkdownCell $item.CancelInProgress) " +
            "| $(ConvertTo-MarkdownCell $permissionSummary) " +
            "| $(ConvertTo-MarkdownCell $secretSummary) " +
            "| $(ConvertTo-MarkdownCell $inputSummary) " +
            "| $(ConvertTo-MarkdownCell $item.AdditionalJobs) |"
        )
    }

    if ($parseErrors) {
        $lines.Add('')
        $lines.Add('## Parse errors')
        $lines.Add('')
        foreach ($item in $parseErrors) {
            $lines.Add("- **$($item.Repository)/$($item.WorkflowPath):** $(ConvertTo-MarkdownCell $item.Error)")
        }
    }

    $lines -join "`n"
}

$workflowFiles = if ($PSCmdlet.ParameterSetName -eq 'GitHub') {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'GitHub mode requires the GitHub CLI (gh). Install it and authenticate with gh auth login or GH_TOKEN.'
    }

    $repositories = Get-GitHubRepository `
        -Owner $Organization `
        -NameWithOwner $Repository `
        -IncludeArchivedRepository:$IncludeArchived
    if (-not $repositories) {
        throw "No repositories were found for organization [$Organization]."
    }

    @(
        Get-GitHubMatchingWorkflowFile `
            -RepositoryInfo $repositories `
            -Owner $Organization `
            -ExpectedReference $WorkflowReference
    )
} else {
    @(Get-LocalWorkflowFile -InputPath $Path)
}

if (-not $workflowFiles) {
    throw "No workflow files containing [$WorkflowReference] were discovered."
}

$inventory = @(
    $workflowFiles |
        ForEach-Object {
            Get-WorkflowInventoryItem -WorkflowFile $_ -ExpectedReference $WorkflowReference
        }
)

if (-not $inventory) {
    throw "No reusable workflow jobs using [$WorkflowReference] were found in the discovered files."
}

if ($JsonPath) {
    $parent = Split-Path -Path $JsonPath -Parent
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $inventory | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $JsonPath -Encoding utf8
}

if ($MarkdownPath) {
    $parent = Split-Path -Path $MarkdownPath -Parent
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    ConvertTo-WorkflowInventoryMarkdown `
        -Inventory $inventory `
        -Source $PSCmdlet.ParameterSetName |
        Set-Content -LiteralPath $MarkdownPath -Encoding utf8
}

$inventory
