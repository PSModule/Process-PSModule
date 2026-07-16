function Normalize-IndentationExceptFirst {
    <#
    .SYNOPSIS
    Normalizes the indentation of a multi-line string, except for the first line.

    .DESCRIPTION
    This function takes a multi-line string and normalizes the indentation of all lines except the first one.
    It removes the minimum leading whitespace from all subsequent lines.

    .PARAMETER Code
    The multi-line string to normalize.

    .OUTPUTS
    Returns the normalized multi-line string.
    s#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Scope = 'Function', Justification = 'Function isn''t exported.')]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code
    )

    # Split the code into lines
    $lines = $Code -split "`r?`n"

    # If there's 0 or 1 line, there's nothing special to do
    if ($lines.Count -le 1) {
        return $Code
    }

    # The first line stays as-is; we skip it for indentation measurement
    $firstLine = $lines[0]
    $subsequentLines = $lines[1..($lines.Count - 1)]

    # Find the minimum leading indentation among the *subsequent* lines
    $minIndent = ($subsequentLines | Where-Object { $_ -match '\S' } | ForEach-Object {
            # If the line starts with whitespace, capture how many characters
            if ($_ -match '^(\s+)') {
                $matches[1].Length
            } else {
                0
            }
        } | Measure-Object -Minimum).Minimum

    # Remove that leading indentation from each subsequent line
    for ($i = 0; $i -lt $subsequentLines.Count; $i++) {
        $line = $subsequentLines[$i]

        # Only attempt to remove indentation if we actually have some whitespace
        if ($line -match '^(\s+)(.*)$') {
            # $matches[1] = leading whitespace; $matches[2] = the rest
            $leading = $matches[1]
            $rest = $matches[2]

            # If we have enough whitespace to remove $minIndent worth, do it
            if ($leading.Length -ge $minIndent) {
                $leading = $leading.Substring($minIndent)
            }
            # Recombine
            $subsequentLines[$i] = $leading + $rest
        }
    }

    $newLine = [Environment]::NewLine
    # Reconstruct the final code: first line + adjusted subsequent lines
    return ($firstLine + $newLine + ($subsequentLines -join $newLine))
}
