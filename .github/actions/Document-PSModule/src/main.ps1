[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Want to just write to the console, not the pipeline.'
)]
[CmdletBinding()]
param(
    [string]$Name = $env:DOCUMENT_PSMODULE_INPUT_Name,
    [bool]$ShowSummaryOnSuccess = $env:DOCUMENT_PSMODULE_INPUT_ShowSummaryOnSuccess -eq 'true'
)

$PSStyle.OutputRendering = 'Ansi'

'Microsoft.PowerShell.PlatyPS' | ForEach-Object {
    Write-Output "Installing module: $_"
    $retryCount = 5
    $retryDelay = 10
    for ($i = 0; $i -lt $retryCount; $i++) {
        try {
            Install-PSResource -Name $_ -WarningAction SilentlyContinue -TrustRepository -Repository PSGallery
            break
        } catch {
            Write-Warning "Installation of $($psResourceParams.Name) failed with error: $_"
            if ($i -eq $retryCount - 1) {
                throw
            }
            Write-Warning "Retrying in $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
        }
    }
    Import-Module -Name $_
}

$path = (Join-Path -Path $PSScriptRoot -ChildPath 'helpers') | Get-Item | Resolve-Path -Relative
Write-Host "::group::Loading helper scripts from [$path]"
Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | Resolve-Path -Relative | ForEach-Object {
    Write-Host "$_"
    . $_
}

Write-Host '::group::Loading inputs'
$env:GITHUB_REPOSITORY_NAME = $env:GITHUB_REPOSITORY -replace '.+/'
$moduleSourceFolderPath = Resolve-Path -Path 'src' | Select-Object -ExpandProperty Path
$modulesOutputFolderPath = Join-Path -Path . -ChildPath 'outputs/module'
$docsOutputFolderPath = Join-Path -Path . -ChildPath 'outputs/docs'

$params = @{
    ModuleName              = [string]::IsNullOrEmpty($Name) ? $env:GITHUB_REPOSITORY_NAME : $Name
    ModuleSourceFolderPath  = $moduleSourceFolderPath
    ModulesOutputFolderPath = $modulesOutputFolderPath
    DocsOutputFolderPath    = $docsOutputFolderPath
    ShowSummaryOnSuccess    = $ShowSummaryOnSuccess
}

[pscustomobject]$params | Format-List | Out-String

Build-PSModuleDocumentation @params
