function Normalize-IndentationExceptFirst {
    <#
    .SYNOPSIS
    Normalize multiline string indentation except on the first line.

    .DESCRIPTION
    Normalize-IndentationExceptFirst leaves the first line unchanged.
    It removes the minimum leading whitespace from each remaining line.

    .PARAMETER Code
    The multiline string to normalize.

    .OUTPUTS
    System.String

    The multiline string with adjusted indentation.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Scope = 'Function', Justification = 'Function isn''t exported.')]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code
    )

    # Split the code into lines
    $lines = $Code -split "`r?`n"

    # A single-line string needs no indentation adjustment.
    if ($lines.Count -le 1) {
        return $Code
    }

    # Exclude the first line from the indentation measurement.
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

        # Remove indentation only when the line starts with whitespace.
        if ($line -match '^(\s+)(.*)$') {
            # $matches[1] = leading whitespace; $matches[2] = the rest
            $leading = $matches[1]
            $rest = $matches[2]

            # Remove the minimum indentation when the prefix is long enough.
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
