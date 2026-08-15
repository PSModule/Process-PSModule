# Adding 10000 items property-style
Measure-Command {
    $HashProp = @{}
    1..10000 | ForEach-Object { $HashProp.$_ = $_ }
}

# Adding 10000 items using the Add method
Measure-Command {
    $HashMethod = @{}
    1..10000 | ForEach-Object { $HashMethod.Add($_, $_) }
}

# Adding 10000 items dictionary-style
Measure-Command {
    $HashDict = @{}
    1..10000 | ForEach-Object { $HashDict[$_] = $_ }
}
