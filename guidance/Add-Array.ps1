$tests = @{
    'PowerShell Explicit Assignment' = {
        param($count)

        $result = foreach ($i in 1..$count) {
            $i
        }
        $null = $result # just added for linter issues
    }
    '.Add(..) to List<T>'            = {
        param($count)

        $result = [Collections.Generic.List[int]]::new()
        foreach ($i in 1..$count) {
            $result.Add($i)
        }
    }
    '+= Operator to Array'           = {
        param($count)

        $result = @()
        foreach ($i in 1..$count) {
            $result += $i
        }
    }
}

5kb, 10kb, 100kb | ForEach-Object {
    $groupResult = foreach ($test in $tests.GetEnumerator()) {
        $ms = (Measure-Command { & $test.Value -Count $_ }).TotalMilliseconds

        [pscustomobject]@{
            CollectionSize    = $_
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
