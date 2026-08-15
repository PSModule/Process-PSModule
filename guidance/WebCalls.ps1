# Define the list of URLs (images or other files) to test.
$urls = @(
    'https://github.com'
    'https://microsoft.com'
    'https://google.com'
    'https://bing.com'
    'https://yahoo.com'
    'https://duckduckgo.com'
    'https://wikipedia.org'
    'https://youtube.com'
)

# Number of times to repeat each test per URL.
$iterations = 50

$results = @()

foreach ($url in $urls) {
    Write-Host "Testing URL: $url"

    for ($i = 1; $i -le $iterations; $i++) {
        # 1) Invoke-RestMethod - default
        $timeIR = Measure-Command {
            Invoke-RestMethod -Uri $url | Out-Null
        }
        $results += [PSCustomObject]@{
            URL                 = $url
            Method              = 'Invoke-RestMethod (HTTP/1.1)'
            ElapsedMilliseconds = $timeIR.TotalMilliseconds
        }

        # 2) Invoke-RestMethod - HTTP/2
        $timeIR2 = Measure-Command {
            Invoke-RestMethod -Uri $url -HttpVersion 2.0 | Out-Null
        }
        $results += [PSCustomObject]@{
            URL                 = $url
            Method              = 'Invoke-RestMethod (HTTP/2.0)'
            ElapsedMilliseconds = $timeIR2.TotalMilliseconds
        }

        # 3) Invoke-WebRequest - default
        $timeIW = Measure-Command {
            Invoke-WebRequest -Uri $url | Out-Null
        }
        $results += [PSCustomObject]@{
            URL                 = $url
            Method              = 'Invoke-WebRequest (HTTP/1.1)'
            ElapsedMilliseconds = $timeIW.TotalMilliseconds
        }

        # 4) Invoke-WebRequest - HTTP/2
        $timeIW2 = Measure-Command {
            Invoke-WebRequest -Uri $url -HttpVersion 2.0 | Out-Null
        }
        $results += [PSCustomObject]@{
            URL                 = $url
            Method              = 'Invoke-WebRequest (HTTP/2.0)'
            ElapsedMilliseconds = $timeIW2.TotalMilliseconds
        }
    }
}

# Summarize: average, min, and max of each combination
$summary = $results |
    Group-Object URL, Method |
    ForEach-Object {
        $elapsed = $_.Group | Select-Object -ExpandProperty ElapsedMilliseconds
        [PSCustomObject]@{
            URL            = $_.Group[0].URL
            Method         = $_.Group[0].Method
            AverageTime_ms = [Math]::Round(($elapsed | Measure-Object -Average).Average, 2)
            MinTime_ms     = [Math]::Round(($elapsed | Measure-Object -Minimum).Minimum, 2)
            MaxTime_ms     = [Math]::Round(($elapsed | Measure-Object -Maximum).Maximum, 2)
        }
    } |
    Sort-Object URL, Method

# Display in a table
$summary | Format-Table -AutoSize
