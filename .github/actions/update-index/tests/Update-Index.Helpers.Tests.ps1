[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'The temporary path is assigned before assertions and cleanup.'
)]
[CmdletBinding()]
param()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../src/Helper.psm1') -Force
}

Describe 'Update-ModuleList' {
    Context 'catalog page at the Modules root' {
        It 'Update-ModuleList - writes the catalog index and repository page to the new Modules paths' {
            $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("update-index-test-$([guid]::NewGuid())")
            $modulesPath = Join-Path $testRoot 'docs/content/Modules'
            $catalogIndexPath = Join-Path $modulesPath 'index.md'
            New-Item -ItemType Directory -Path $modulesPath -Force | Out-Null
            Set-Content -Path $catalogIndexPath -Value @(
                '# Modules'
                ''
                '<!-- MODULE_CATALOG_START -->'
                '<!-- MODULE_CATALOG_END -->'
            )

            try {
                Push-Location $testRoot
                InModuleScope Helper {
                    Mock Get-RepositoryVersion { '1.2.3' }
                    Mock Get-RepositoryReadmeContent { '# Example`nExample module summary.' }
                    Mock Get-MarkdownSummary { 'Example module summary.' }
                    Mock Get-WorkflowReference { 'v1.2.3' }
                    Mock Get-ProcessReferenceStatus { 'up-to-date' }
                    Mock Get-OpenItemCount { 0 }

                    Update-ModuleList -Repos @(
                        [pscustomobject]@{
                            Type          = 'Module'
                            Owner         = 'PSModule'
                            Name          = 'Example'
                            Description   = 'Example module.'
                            DefaultBranch = 'main'
                            Stars         = 1
                        }
                    )
                }

                $catalogContent = Get-Content -Path $catalogIndexPath -Raw
                Test-Path (Join-Path $modulesPath 'Repositories/Example.md') | Should -BeTrue
                $catalogContent | Should -Match '\./Repositories/Example\.md'
                $catalogContent | Should -Match '\.\./assets/images/module-catalog/githubtags\.svg'
            } finally {
                Pop-Location
                Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
