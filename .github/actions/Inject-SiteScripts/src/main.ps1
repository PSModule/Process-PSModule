#Requires -Version 7.0

<#
    .SYNOPSIS
    Inject shared JavaScript snippets into generated site HTML files.

    .DESCRIPTION
    The script reads .github/scripts/site-injectors in the checked-out workflow repository.
    It injects each script into every HTML file under SitePath, once per file.

    .EXAMPLE
    ./main.ps1 -SitePath './.PSModule/site/_site' -WorkflowPath '_wf'

    .INPUTS
    None.

    .OUTPUTS
    None.
#>
[CmdletBinding()]
param(
    # Path to the generated site output directory with HTML files.
    [Parameter(Mandatory)]
    [string]$SitePath,

    # Relative path to the checked-out workflow repository root.
    [Parameter(Mandatory)]
    [string]$WorkflowPath
)

$resolvedSitePath = Resolve-Path -Path $SitePath -ErrorAction Stop | Select-Object -ExpandProperty Path
$injectorsPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath "$WorkflowPath/.github/scripts/site-injectors"

if (-not (Test-Path -Path $injectorsPath)) {
    throw "Expected site injector folder at $injectorsPath but it was not found."
}

$injectorScripts = Get-ChildItem -Path $injectorsPath -File -Filter '*.js' | Sort-Object -Property Name
if (-not $injectorScripts) {
    Write-Host "No site injector scripts found under $injectorsPath."
    exit 0
}

Get-ChildItem -Path $resolvedSitePath -Filter '*.html' -Recurse | ForEach-Object {
    $html = Get-Content -Path $_.FullName -Raw
    $modified = $false

    foreach ($injectorScript in $injectorScripts) {
        $marker = "data-psmodule-site-injector=""$($injectorScript.Name)"""
        if ($html -match [Regex]::Escape($marker)) {
            continue
        }

        $scriptContent = Get-Content -Path $injectorScript.FullName -Raw
        $injectedScript = "<script $marker>$scriptContent</script>"
        $html = $html -replace '</body>', "$injectedScript`n</body>"
        $modified = $true
    }

    if ($modified) {
        Set-Content -Path $_.FullName -Value $html -NoNewline
    }
}
