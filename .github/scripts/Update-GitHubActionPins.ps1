[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$Path = '.github'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CommitShaForTag {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Repository,

        [Parameter(Mandatory)]
        [string]$Tag,

        [Parameter(Mandatory)]
        [hashtable]$Headers
    )

    $tagReference = Invoke-RestMethod -Headers $Headers -Uri "https://api.github.com/repos/$Repository/git/ref/tags/$Tag"
    while ($tagReference.object.type -eq 'tag') {
        $tagReference = Invoke-RestMethod -Headers $Headers -Uri "https://api.github.com/repos/$Repository/git/tags/$($tagReference.object.sha)"
    }

    if ($tagReference.object.type -ne 'commit') {
        throw "Tag '$Tag' in '$Repository' does not resolve to a commit."
    }

    return $tagReference.object.sha
}

function Get-LatestActionPin {
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [hashtable]$Headers
    )

    if ($Action -notmatch '^(?<owner>[^/]+)/(?<repository>[^/]+)(?:/.*)?$') {
        throw "'$Action' is not a GitHub Action repository reference."
    }

    $repository = "$($Matches.owner)/$($Matches.repository)"
    $release = Invoke-RestMethod -Headers $Headers -Uri "https://api.github.com/repos/$repository/releases/latest"

    return [pscustomobject]@{
        Repository = $repository
        Tag        = $release.tag_name
        Sha        = Get-CommitShaForTag -Repository $repository -Tag $release.tag_name -Headers $Headers
    }
}

$root = (Resolve-Path -LiteralPath $Path).Path
$token = $env:GITHUB_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
    $token = $env:GH_TOKEN
}

$headers = @{
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'Process-PSModule-action-pin-updater'
}
if (-not [string]::IsNullOrWhiteSpace($token)) {
    $headers.Authorization = "Bearer $token"
}

$linePattern = [regex]'(?m)^(?<prefix>[ \t]*uses:[ \t]*)(?<action>[^@\s]+)@(?<sha>[^\s#]+)(?:[ \t]*#[^\r\n]*)?(?<carriageReturn>\r?)$'
$pins = @{}

Get-ChildItem -LiteralPath $root -Recurse -File -Include '*.yml', '*.yaml' | ForEach-Object {
    $file = $_
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $lineMatches = $linePattern.Matches($content)
    if ($lineMatches.Count -eq 0) {
        return
    }

    $updatedContent = $linePattern.Replace($content, {
            param($match)

            $action = $match.Groups['action'].Value
            if ($action.StartsWith('./', [System.StringComparison]::Ordinal) -or
                $action.StartsWith('docker://', [System.StringComparison]::OrdinalIgnoreCase)) {
                return $match.Value
            }

            if (-not $pins.ContainsKey($action)) {
                $pins[$action] = Get-LatestActionPin -Action $action -Headers $headers
            }

            $pin = $pins[$action]
            return "$($match.Groups['prefix'].Value)$action@$($pin.Sha) # $($pin.Tag)$($match.Groups['carriageReturn'].Value)"
        })

    if ($updatedContent -eq $content) {
        return
    }

    $relativePath = [System.IO.Path]::GetRelativePath((Get-Location).Path, $file.FullName)
    $actionNames = $lineMatches | ForEach-Object { $_.Groups['action'].Value } | Sort-Object -Unique
    $target = "$relativePath ($($actionNames -join ', '))"
    if ($PSCmdlet.ShouldProcess($target, 'Update GitHub Action SHA pins and release tags')) {
        $hasUtf8Bom = $content.Length -gt 0 -and $content[0] -eq [char]0xFEFF
        [System.IO.File]::WriteAllText($file.FullName, $updatedContent, [System.Text.UTF8Encoding]::new($hasUtf8Bom))
    }

    [pscustomobject]@{
        Path    = $relativePath
        Actions = $actionNames -join ', '
    }
}
