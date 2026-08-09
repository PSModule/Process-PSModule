# Function to simulate processing each line
function Test-LineProcessing {
    <#
        .SYNOPSIS
        Simulates processing a single line of text.

        .DESCRIPTION
        Returns whether the input text has a length greater than zero.

        .PARAMETER InputText
        The text line to process.
    #>
    param([string]$InputText)
    # Simulate some work by creating a simple string operation
    $InputText.Length > 0
}

$tests = @{
    'Get-Content + foreach'        = {
        param($filePath)
        $content = Get-Content -Path $filePath
        foreach ($line in $content) {
            Test-LineProcessing -InputText $line
        }
    }
    'Get-Content | ForEach-Object' = {
        param($filePath)
        Get-Content -Path $filePath |
            ForEach-Object -Process {
                Test-LineProcessing -InputText $_
            }
    }
    'StreamReader'                 = {
        param($filePath)
        $sr = New-Object -TypeName System.IO.StreamReader -ArgumentList $filePath
        try {
            while ($sr.Peek() -ge 0) {
                $line = $sr.ReadLine()
                Test-LineProcessing -InputText $line
            }
        } finally {
            $sr.Dispose()
        }
    }
    'Get-Content -ReadCount 1'     = {
        param($filePath)
        Get-Content -Path $filePath -ReadCount 1 |
            ForEach-Object -Process {
                Test-LineProcessing -InputText $_
            }
    }
}

# Create test files
$testFiles = @{
    'test-small.txt'  = (1..100 | ForEach-Object { "This is line $_ with some additional text to make it realistic." })
    'test-medium.txt' = (1..5000 | ForEach-Object {
            "This is line $_ with some additional text to make it realistic and longer for testing purposes."
        })
    'test-large.txt'  = (1..50000 | ForEach-Object {
            "This is line $_ with some additional text to make it realistic and longer for testing purposes with even more content."
        })
}

# Generate test files
foreach ($file in $testFiles.GetEnumerator()) {
    $file.Value | Out-File -FilePath $file.Key -Encoding UTF8
}

'test-small.txt', 'test-medium.txt', 'test-large.txt' | ForEach-Object {
    $groupResult = foreach ($test in $tests.GetEnumerator()) {
        $ms = (Measure-Command { & $test.Value $_ }).TotalMilliseconds

        [pscustomobject]@{
            TestFile          = $_
            Test              = $test.Key
            TotalMilliseconds = [math]::Round($ms, 2)
        }

        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }

    $groupResult = $groupResult | Sort-Object TotalMilliseconds
    $groupResult | Select-Object *, @{
        Name       = 'RelativeSpeed'
        Expression = {
            $relativeSpeed = $_.TotalMilliseconds / $groupResult[0].TotalMilliseconds
            [math]::Round($relativeSpeed, 2).ToString() + 'x'
        }
    }
}

# Cleanup test files
'test-small.txt', 'test-medium.txt', 'test-large.txt' | ForEach-Object {
    Remove-Item $_ -Force -ErrorAction SilentlyContinue
}
