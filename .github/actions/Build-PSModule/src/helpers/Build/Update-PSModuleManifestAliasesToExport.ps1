function Update-PSModuleManifestAliasesToExport {
    <#
    .SYNOPSIS
    Updates the aliases to export in the module manifest.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function',
        Justification = 'Updates a file that is being built.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Want to just write to the console, not the pipeline.'
    )]
    [CmdletBinding()]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleSourceFolder,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )
    Set-GitHubLogGroup 'Updating aliases to export in module manifest' {
        Write-Host "Module name: [$ModuleName]"
        Write-Host "Module output folder: [$ModuleSourceFolder]"

        $publicFunctionsPath = Join-Path -Path $ModuleSourceFolder -ChildPath 'functions/public'
        Write-Host "Public functions path: [$publicFunctionsPath]"
        if (-not (Test-Path -Path $publicFunctionsPath)) {
            Write-Host "Public functions path does not exist: [$publicFunctionsPath]"
            return
        }

        # Get all child items in the module source folder of a powershell file type
        $files = Get-ChildItem -Path $publicFunctionsPath -Recurse -File -Include '*.ps1', '*.psm1' | Select-Object -ExpandProperty FullName

        # Initialize an array to store all found aliases
        $allAliases = @()

        foreach ($file in $files) {
            Write-Host "Parsing file: [$file]"

            # Parse the file using AST
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $file,
                [ref]$null,
                [ref]$null
            )

            # Get all function definitions
            $functionAsts = $ast.FindAll(
                {
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
                }, $false)

            Write-Host "   Found functions: [$($functionAsts.Count)]"
            foreach ($functionAst in $functionAsts) {
                # Get the function name
                $functionName = $functionAst.Name
                Write-Host "   Processing: [$functionName]"

                $functionAst | ForEach-Object {
                    $funcName = $_.Name
                    $funcAttributes = $_.Body.FindAll({ $args[0] -is [System.Management.Automation.Language.AttributeAst] }, $true) | Where-Object {
                        $_.Parent -is [System.Management.Automation.Language.ParamBlockAst]
                    }
                    $aliasAttr = $funcAttributes | Where-Object { $_.TypeName.Name -eq 'Alias' }

                    if ($aliasAttr) {
                        $aliases = $aliasAttr.PositionalArguments | ForEach-Object { $_.ToString().Trim('"', "'") }
                        Write-Host "  Found alias [$aliases] for function [$funcName]"
                        $allAliases += $aliases
                    }
                }
            }
        }

        Write-Host "Found aliases: [$($allAliases.Count)]"
        foreach ($alias in $allAliases) {
            Write-Host " - [$alias]"
        }
        $outputManifestPath = Join-Path -Path $ModuleOutputFolder -ChildPath "$ModuleName.psd1"
        Write-Host "Output manifest path: [$outputManifestPath]"
        Write-Host 'Setting module manifest with AliasesToExport'
        Set-ModuleManifest -Path $outputManifestPath -AliasesToExport $allAliases -Verbose
    }
}
