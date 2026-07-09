if ([string]::IsNullOrWhiteSpace($env:PSMODULE_TEST_DATA)) {
    Write-Output 'No test data was provided by the calling workflow.'
    return
}
try {
    $data = $env:PSMODULE_TEST_DATA | ConvertFrom-Json -ErrorAction Stop
} catch {
    throw "The 'TestData' secret must be valid JSON with 'secrets' and/or 'variables' maps."
}
if ($null -eq $data -or $data -isnot [pscustomobject]) {
    throw "The 'TestData' secret must be a JSON object with 'secrets' and/or 'variables' maps."
}
$allowedTopLevelKeys = @('secrets', 'variables')
foreach ($propertyName in $data.PSObject.Properties.Name) {
    if ($allowedTopLevelKeys -notcontains $propertyName) {
        throw "The 'TestData' secret only supports 'secrets' and 'variables' maps."
    }
}
$reservedNames = @('CI', 'HOME', 'PATH', 'PWD', 'SHELL', 'PSMODULE_TEST_DATA')
$reservedPrefixes = @('GITHUB_', 'RUNNER_', 'ACTIONS_')
function Assert-EnvironmentName {
    <#
        .SYNOPSIS
        Validates that a TestData key can safely be written to GITHUB_ENV.
    #>
    param([string] $Name)
    if ($Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        throw 'TestData keys must be valid environment variable names.'
    }
    $normalized = $Name.ToUpperInvariant()
    if ($reservedNames -contains $normalized) {
        throw 'TestData keys must not override reserved environment variables.'
    }
    foreach ($prefix in $reservedPrefixes) {
        if ($normalized.StartsWith($prefix)) {
            throw 'TestData keys must not override reserved environment variables.'
        }
    }
}
function Assert-Map {
    <#
        .SYNOPSIS
        Validates that a TestData section is a JSON object map.
    #>
    param(
        [object] $Map,
        [string] $Name
    )
    if ($null -eq $Map) { return }
    if ($Map -isnot [pscustomobject]) {
        throw "The 'TestData.$Name' value must be a JSON object."
    }
}
function Get-EnvironmentValue {
    <#
        .SYNOPSIS
        Converts a scalar TestData value to an environment variable value.
    #>
    param(
        [object] $Value,
        [string] $Name
    )
    if ($null -eq $Value) { return '' }
    if (
        $Value -is [pscustomobject] -or
        ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string])
    ) {
        throw "Values in 'TestData.$Name' must be scalar values."
    }
    return [string]$Value
}
function Add-EnvFromMap {
    <#
        .SYNOPSIS
        Writes validated TestData entries to GITHUB_ENV.
    #>
    param(
        [object] $Map,
        [string] $Name,
        [switch] $Mask
    )
    Assert-Map -Map $Map -Name $Name
    if ($null -eq $Map) { return }
    $count = 0
    foreach ($item in $Map.PSObject.Properties) {
        $name = $item.Name
        Assert-EnvironmentName -Name $name
        $value = Get-EnvironmentValue -Value $item.Value -Name $Name
        if ($Mask) {
            foreach ($line in ($value -split "`n")) {
                $line = $line.TrimEnd("`r")
                if ($line.Length -gt 0) {
                    Write-Output "::add-mask::$line"
                }
            }
        }
        do {
            $delimiter = "GHENV_$([guid]::NewGuid().ToString('N'))"
        } while ($value.Contains($delimiter))
        Add-Content -Path $env:GITHUB_ENV -Value "$name<<$delimiter" -Encoding utf8
        Add-Content -Path $env:GITHUB_ENV -Value $value -Encoding utf8
        Add-Content -Path $env:GITHUB_ENV -Value $delimiter -Encoding utf8
        $count++
    }
    if ($count -gt 0) {
        if ($Mask) {
            Write-Output "Exposed $count secret value(s) as environment variables."
        } else {
            Write-Output "Exposed $count variable value(s) as environment variables."
        }
    }
}

Assert-Map -Map $data.secrets -Name 'secrets'
Assert-Map -Map $data.variables -Name 'variables'

$secretNames = @()
if ($null -ne $data.secrets) {
    $secretNames = @($data.secrets.PSObject.Properties.Name)
}
$variableNames = @()
if ($null -ne $data.variables) {
    $variableNames = @($data.variables.PSObject.Properties.Name)
}
$secretNameSet = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
foreach ($secretName in $secretNames) {
    [void] $secretNameSet.Add($secretName)
}
foreach ($variableName in $variableNames) {
    if ($secretNameSet.Contains($variableName)) {
        throw 'TestData keys must not be duplicated across secrets and variables.'
    }
}

Add-EnvFromMap -Map $data.secrets -Name 'secrets' -Mask
Add-EnvFromMap -Map $data.variables -Name 'variables'
