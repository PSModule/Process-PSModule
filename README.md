# Process-PSModule

An opinionated, end-to-end GitHub Actions workflow that builds, tests, documents, and publishes PowerShell modules with
minimal setup.

## Getting started

1. [Create a repository from Template-PSModule](https://github.com/new?template_name=Template-PSModule&template_owner=PSModule).
2. Enable GitHub Pages with deployment source set to `GitHub Actions`.
3. Remove default `main` branch protection from the `github-pages` environment.
4. [Create a PowerShell Gallery API key](https://www.powershellgallery.com/account/apikeys) with publish rights.
5. Add a repository secret named `APIKEY` containing your gallery key.
6. Develop on a feature branch, open a pull request, and let Process-PSModule validate your changes.

## What you get

- One workflow run manages build, validation, documentation, and publishing across Linux, macOS, and Windows.
- Dynamic behavior driven by repository metadata, GitHub event context, and settings via `.github/PSModule.yml`.
- Consistent artifacts, logs, and gating so every environment observes the same result.
- Label-driven version bumping: patch (default), minor (`minor`, `feature`), or major (`major`, `breaking`).
- Automated releases to PowerShell Gallery and GitHub Releases with optional prerelease cleanup.
- Module structure, tooling, and release automation aligned with PSModule standards.

## How it works

Process-PSModule monitors pull requests to the default branch, manual runs, and scheduled executions. It reacts to
open, synchronize, reopen, label, and close events, then decides which jobs to run based on repository configuration
and PR labels.

![Process diagram](./media/Process-PSModule.png)

**Workflow phases:**

1. **Discover and plan** — Reads `.github/PSModule.yml` (YAML, JSON, or PSD1), inspects labels and event payloads,
   determines target operating systems, quality gates, and whether publishing is in scope.
2. **Build and document** — Stages `src/` tree, honors `*build.ps1` hooks, composes root module, regenerates manifest,
   and generates documentation from staged output.
3. **Validate quality** — Executes source linting, module framework validation, and repository-specific tests against
   staged module. Optional `tests/BeforeAll.ps1` and `tests/AfterAll.ps1` scripts handle shared setup and teardown.
4. **Publish and close out** — Promotes staged module to PowerShell Gallery, creates GitHub release, deploys
   documentation to Pages, and cleans up abandoned prereleases when configured.

**Job lifecycle across GitHub events:**

| Job                       | Open/updated PR | Merged PR | Abandoned PR | Manual run |
|---------------------------|-----------------|-----------|--------------|------------|
| Gather repo settings      | ✅ Always       | ✅ Always | ✅ Always    | ✅ Always  |
| Repository lint           | ✅ Yes          | ❌ No     | ❌ No        | ❌ No      |
| Module build              | ✅ Yes          | ✅ Yes    | ❌ No        | ✅ Yes     |
| Documentation build       | ✅ Yes          | ✅ Yes    | ❌ No        | ✅ Yes     |
| Site build                | ✅ Yes          | ✅ Yes    | ❌ No        | ✅ Yes     |
| Source lint               | ✅ Yes          | ✅ Yes    | ❌ No        | ✅ Yes     |
| Framework tests           | ✅ Yes          | ✅ Yes    | ❌ No        | ✅ Yes     |
| Module-local tests        | ✅ Yes          | ✅ Yes    | ❌ No        | ✅ Yes     |
| Module-local cleanup      | ✅ Yes          | ✅ Yes    | ✅ Yes*      | ✅ Yes     |
| Results aggregation       | ✅ Yes          | ✅ Yes    | ❌ No        | ✅ Yes     |
| Coverage summary          | ✅ Yes          | ✅ Yes    | ❌ No        | ✅ Yes     |
| Site publish              | ❌ No           | ✅ Yes    | ❌ No        | ❌ No      |
| Module publish            | ✅ Yes**        | ✅ Yes**  | ✅ Yes***    | ✅ Yes**   |

\* Runs cleanup only if tests were started.
\*\* Only when build, test, and coverage gates succeed.
\*\*\* Publishes cleanup or retraction version when required.


## Configuration

Control workflow behavior through `.github/PSModule.yml` (or `.json` / `.psd1`). The workflow reads this file to
determine which jobs run, which operating systems participate, and how releases are managed.

**Common patterns:**

```yaml
# Enforce 80% coverage
Test:
  CodeCoverage:
    PercentTarget: 80
```

```yaml
# Fast Linux-only validation (skip macOS/Windows, disable coverage)
Test:
  SourceCode:
    Skip: true
  PSModule:
    Skip: true
  Module:
    MacOS:
      Skip: true
    Windows:
      Skip: true
  TestResults:
    Skip: true
  CodeCoverage:
    Skip: true
Build:
  Docs:
    Skip: true
```

```yaml
# Tune repository linter verbosity
Linter:
  env:
    LOG_LEVEL: DEBUG
    VALIDATE_JSON: true
    VALIDATE_YAML: true
    VALIDATE_MARKDOWN: true
```

<details>
<summary>Full default configuration</summary>

```yaml
Name: null

Build:
  Skip: false
  Module:
    Skip: false
  Docs:
    Skip: false
    ShowSummaryOnSuccess: false
  Site:
    Skip: false

Test:
  Skip: false
  Linux:
    Skip: false
  MacOS:
    Skip: false
  Windows:
    Skip: false
  SourceCode:
    Skip: false
    Linux:
      Skip: false
    MacOS:
      Skip: false
    Windows:
      Skip: false
  PSModule:
    Skip: false
    Linux:
      Skip: false
    MacOS:
      Skip: false
    Windows:
      Skip: false
  Module:
    Skip: false
    Linux:
      Skip: false
    MacOS:
      Skip: false
    Windows:
      Skip: false
  TestResults:
    Skip: false
  CodeCoverage:
    Skip: false
    PercentTarget: 0
    StepSummaryMode: 'Missed, Files'

Publish:
  Module:
    Skip: false
    AutoCleanup: true
    AutoPatching: true
    IncrementalPrerelease: true
    DatePrereleaseFormat: ''
    VersionPrefix: 'v'
    MajorLabels: 'major, breaking'
    MinorLabels: 'minor, feature'
    PatchLabels: 'patch, fix'
    IgnoreLabels: 'NoRelease'

Linter:
  Skip: false
  ShowSummaryOnSuccess: false
  env: {}
```

</details>

<details>
<summary>Configuration settings reference</summary>

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `Name` | String | Override module name (default: repository name). | `null` |
| `Build.Skip` | Boolean | Skip all build jobs. | `false` |
| `Build.Module.Skip` | Boolean | Skip module compilation. | `false` |
| `Build.Docs.Skip` | Boolean | Skip documentation linting. | `false` |
| `Build.Docs.ShowSummaryOnSuccess` | Boolean | Show linter summary even when linting succeeds. | `false` |
| `Build.Site.Skip` | Boolean | Skip site generation. | `false` |
| `Test.Skip` | Boolean | Skip all test jobs. | `false` |
| `Test.Linux.Skip` | Boolean | Skip all Linux matrix runs. | `false` |
| `Test.MacOS.Skip` | Boolean | Skip all macOS matrix runs. | `false` |
| `Test.Windows.Skip` | Boolean | Skip all Windows matrix runs. | `false` |
| `Test.SourceCode.Skip` | Boolean | Skip source code tests. | `false` |
| `Test.SourceCode.Linux.Skip` | Boolean | Skip source code tests on Linux. | `false` |
| `Test.SourceCode.MacOS.Skip` | Boolean | Skip source code tests on macOS. | `false` |
| `Test.SourceCode.Windows.Skip` | Boolean | Skip source code tests on Windows. | `false` |
| `Test.PSModule.Skip` | Boolean | Skip framework-level module tests. | `false` |
| `Test.PSModule.Linux.Skip` | Boolean | Skip framework tests on Linux. | `false` |
| `Test.PSModule.MacOS.Skip` | Boolean | Skip framework tests on macOS. | `false` |
| `Test.PSModule.Windows.Skip` | Boolean | Skip framework tests on Windows. | `false` |
| `Test.Module.Skip` | Boolean | Skip repository module tests. | `false` |
| `Test.Module.Linux.Skip` | Boolean | Skip module tests on Linux. | `false` |
| `Test.Module.MacOS.Skip` | Boolean | Skip module tests on macOS. | `false` |
| `Test.Module.Windows.Skip` | Boolean | Skip module tests on Windows. | `false` |
| `Test.TestResults.Skip` | Boolean | Skip consolidated results job. | `false` |
| `Test.CodeCoverage.Skip` | Boolean | Skip code coverage calculation. | `false` |
| `Test.CodeCoverage.PercentTarget` | Integer | Required coverage percentage before publishing. | `0` |
| `Test.CodeCoverage.StepSummaryMode` | String | Display mode for coverage summaries. | `Missed, Files` |
| `Publish.Module.Skip` | Boolean | Skip module publishing. | `false` |
| `Publish.Module.AutoCleanup` | Boolean | Remove stale prerelease versions automatically. | `true` |
| `Publish.Module.AutoPatching` | Boolean | Auto-increment patch versions during release. | `true` |
| `Publish.Module.IncrementalPrerelease` | Boolean | Use incremental prerelease tagging. | `true` |
| `Publish.Module.DatePrereleaseFormat` | String | Date format for prerelease tags (.NET format strings). | `''` |
| `Publish.Module.VersionPrefix` | String | Prefix prepended to release tags. | `'v'` |
| `Publish.Module.MajorLabels` | String | Labels that trigger a major release. | `'major, breaking'` |
| `Publish.Module.MinorLabels` | String | Labels that trigger a minor release. | `'minor, feature'` |
| `Publish.Module.PatchLabels` | String | Labels that trigger a patch release. | `'patch, fix'` |
| `Publish.Module.IgnoreLabels` | String | Labels that skip releasing entirely. | `'NoRelease'` |
| `Linter.Skip` | Boolean | Skip repository linting. | `false` |
| `Linter.ShowSummaryOnSuccess` | Boolean | Show linter summary on success. | `false` |
| `Linter.env` | Object | Key/value pairs forwarded to super-linter. | `{}` |

</details>

## Release control with PR labels

By default, merged pull requests trigger a **patch** release (e.g., `1.0.0` → `1.0.1`). Apply PR labels to control
version bumps:

- **Patch** (default) — No label needed, or use `patch`, `fix`.
- **Minor** — Use `minor`, `feature` to increment the minor version (e.g., `1.0.0` → `1.1.0`).
- **Major** — Use `major`, `breaking` to increment the major version (e.g., `1.0.0` → `2.0.0`).
- **Skip release** — Apply `NoRelease` to run validation without publishing.

Customize labels in `.github/PSModule.yml`:

```yaml
Publish:
  Module:
    MajorLabels: 'major, breaking, api-change'
    MinorLabels: 'minor, feature, enhancement'
    PatchLabels: 'patch, fix, bugfix'
    IgnoreLabels: 'NoRelease, WIP'
```

**Prerelease handling:**

- On PR open/update, the workflow generates a normalized branch-name prerelease (e.g., `1.0.1-feat-awesome.1`).
- When `Publish.Module.AutoCleanup` is `true` (default), previous prereleases for the same branch are removed
  automatically.
- On merge to the default branch, the workflow promotes the staged module and removes temporary prereleases.
- Set `Publish.Module.IncrementalPrerelease` to `false` and provide `DatePrereleaseFormat` (e.g., `yyyyMMddHHmmss`) for
  date-based prerelease identifiers.


## Repository layout

Process-PSModule expects repositories to follow the staged layout produced by
[Template-PSModule](https://github.com/PSModule/Template-PSModule). The workflow inspects this structure to decide what
to compile, document, and publish.

```plaintext
<ModuleName>/
├── .github/
│   ├── linters/
│   │   ├── .markdown-lint.yml                 # Markdown rules enforced via super-linter
│   │   ├── .powershell-psscriptanalyzer.psd1  # Analyzer profile for test jobs
│   │   └── .textlintrc                        # Text lint rules surfaced in build docs summaries
│   ├── workflows/
│   │   └── Process-PSModule.yml               # Entry point for this reusable workflow
│   ├── CODEOWNERS                             # Default reviewers enforced by Process-PSModule checks
│   ├── dependabot.yml                         # Dependency update cadence
│   ├── mkdocs.yml                             # MkDocs config consumed during site builds
│   ├── PSModule.yml                           # Settings parsed to drive matrices
│   └── release.yml                            # Release automation template invoked on publish
├── examples/
│   └── General.ps1                            # Example script ingested by Document-PSModule
├── icon/
│   └── icon.png                               # Default module icon (PNG format)
├── src/
│   ├── assemblies/                            # Bundled binaries copied into build artifact
│   ├── classes/
│   │   ├── private/                           # Internal classes kept out of exports
│   │   │   └── SecretWriter.ps1
│   │   └── public/                            # Public classes exported via type accelerators
│   │       └── Book.ps1
│   ├── data/                                  # Configuration loaded into $script: scope at runtime
│   │   ├── Config.psd1
│   │   └── Settings.psd1
│   ├── formats/                               # Formatting metadata registered during build
│   │   ├── CultureInfo.Format.ps1xml
│   │   └── Mygciview.Format.ps1xml
│   ├── functions/
│   │   ├── private/                           # Helper functions scoped to the module
│   │   │   ├── Get-InternalPSModule.ps1
│   │   │   └── Set-InternalPSModule.ps1
│   │   └── public/                            # Public commands documented and tested
│   │       ├── Category/                      # Optional: organize commands into categories
│   │       │   ├── Get-CategoryCommand.ps1
│   │       │   └── Category.md                # Category overview merged into docs output
│   │       ├── Get-PSModuleTest.ps1
│   │       ├── New-PSModuleTest.ps1
│   │       ├── Set-PSModuleTest.ps1
│   │       └── Test-PSModuleTest.ps1
│   ├── init/                                  # Initialization scripts executed during module load
│   │   └── initializer.ps1
│   ├── modules/                               # Nested modules packaged with compiled output
│   │   └── OtherPSModule.psm1
│   ├── scripts/                               # Scripts listed in 'ScriptsToProcess'
│   │   └── loader.ps1
│   ├── types/                                 # Type data merged into manifest
│   │   ├── DirectoryInfo.Types.ps1xml
│   │   └── FileInfo.Types.ps1xml
│   ├── variables/
│   │   ├── private/                           # Internal variables scoped to the module
│   │   │   └── PrivateVariables.ps1
│   │   └── public/                            # Public variables exported and documented
│   │       ├── Moons.ps1
│   │       ├── Planets.ps1
│   │       └── SolarSystems.ps1
│   ├── finally.ps1                            # Cleanup script appended to root module
│   ├── header.ps1                             # Optional header injected at top of module
│   ├── manifest.psd1                          # (Optional) Source manifest reused when present
│   └── README.md                              # Module-level docs ingested by Document-PSModule
├── tests/
│   ├── AfterAll.ps1                           # (Optional) Cleanup script for module-local runs
│   ├── BeforeAll.ps1                          # (Optional) Setup script for module-local runs
│   └── <ModuleName>.Tests.ps1                 # Primary test entry point
├── .gitattributes                             # Normalizes line endings across platforms
├── .gitignore                                 # Excludes build artifacts from source control
├── LICENSE                                    # License text surfaced in manifest metadata
└── README.md                                  # Repository overview rendered on GitHub and docs landing
```

**Key expectations:**

- Keep at least one exported function under `src/functions/public/` and corresponding tests in `tests/`.
- Optional folders (`assemblies`, `formats`, `types`, `variables`, and others) are processed automatically when
  present.
- Markdown files (`.md`) in `src/functions/public` subfolders become documentation pages alongside generated help,
  preserving the folder structure for category overviews and conceptual docs.
- The build step compiles `src/` into a root module file and removes the original project layout from the artifact.
- Documentation generation mirrors the `src/functions/public` hierarchy so help content always aligns with source.

## Pipeline jobs

### Build Module

Compiles each module by invoking [`PSModule/Build-PSModule`](https://github.com/PSModule/Build-PSModule). Supports
script modules and manifest modules. Targets PowerShell 7.4+.

**Pipeline steps:**

1. Discovers module name (fallback: repository name) and stages `outputs/module/<ModuleName>`.
2. Executes repository `*build.ps1` scripts alphabetically for preprocessing.
3. Copies `src/` into staging, skipping any existing root module.
4. Rebuilds module manifest from staged content plus repository metadata.
5. Composes root module `.psm1` from staged scripts, classes, variables, and support files.
6. Uploads `module` artifact and exposes `ModuleOutputFolderPath` for downstream jobs.

**Root module composition:**

1. Adds `header.ps1` (when present) to the top of `<ModuleName>.psm1`.
2. Injects a data loader so resources in `data/` become `$script:`-scoped variables.
3. Appends content from `init`, `classes/private`, `classes/public`, `functions/private`, `functions/public`,
   `variables/private`, `variables/public`, and root-level `*.ps1` files in alphabetical order.
4. Registers public classes and enums using type accelerators.
5. Emits trailing `Export-ModuleMember` statement exporting only members from `public` folders.

**Module manifest enrichment:**

- Reuses `manifest.psd1` when provided; otherwise creates new manifest.
- Sets baseline metadata: `RootModule`, `ModuleVersion`, `Author`, `CompanyName`, `Description`.
- Populates `FileList`, `ModuleList`, `RequiredAssemblies`, `NestedModules`, `ScriptsToProcess`, `TypesToProcess`,
  `FormatsToProcess`, `DscResourcesToExport`, and export lists from staged file system.
- Gathers `#requires` statements to update `RequiredModules`, `PowerShellVersion`, `CompatiblePSEditions`.
- Derives `Tags`, `LicenseUri`, `ProjectUri`, `IconUri` from repository data when absent.
- Preserves optional fields (`HelpInfoURI`, `ExternalModuleDependencies`, custom `PrivateData`).

**References:**

- [about_Module_Manifests](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_module_manifests)
- [How to write a PowerShell module manifest](https://learn.microsoft.com/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)
- [PowerShellGallery publishing guidelines](https://learn.microsoft.com/powershell/gallery/concepts/publishing-guidelines)

### Test Module

Validates staged module by invoking [`PSModule/Test-PSModule`](https://github.com/PSModule/Test-PSModule). Executes
SourceCode, PSModule framework, and repository module suites against built artifact. Supports test-driven development
with [Invoke-Pester](https://github.com/PSModule/Invoke-Pester) and honors optional `tests/BeforeAll.ps1` and
`tests/AfterAll.ps1` hooks.

<details>
<summary>SourceCode gates</summary>

| ID | Category | Description |
|----|----------|-------------|
| NumberOfProcessors | General | Should use `[System.Environment]::ProcessorCount` instead of `$env:NUMBER_OF_PROCESSORS`. |
| Verbose | General | Should not contain `-Verbose` unless explicitly disabled with `:$false`. |
| OutNull | General | Should use `$null = ...` instead of piping output to `Out-Null`. |
| NoTernary | General | Should not use ternary operations (PowerShell 5.1 compatibility). |
| LowercaseKeywords | General | All PowerShell keywords should be lowercase. |
| FunctionCount | Functions (Generic) | Each script file should contain exactly one function or filter. |
| FunctionName | Functions (Generic) | Script filenames should match the function/filter name they contain. |
| CmdletBinding | Functions (Generic) | Functions should include `[CmdletBinding()]` attribute. |
| ParamBlock | Functions (Generic) | Functions should have a parameter block (`param()`). |
| FunctionTest | Functions (Public) | All public functions/filters should have corresponding tests. |

</details>

<details>
<summary>Module gates</summary>

| Name | Description |
|------|-------------|
| Module Manifest exists | Verifies that a module manifest file is present. |
| Module Manifest is valid | Verifies that the module manifest file is valid. |

</details>

**Results and reports:**

- Emits `Outcome`, `Conclusion`, `Result`, and aggregated counts for downstream gating.
- Produces NUnit-compatible test results and configurable coverage reports, uploaded as artifacts for each matrix entry.
- Supports GitHub step summaries with configurable filters (`StepSummary_Mode`, `StepSummary_ShowTestOverview`,
  `StepSummary_ShowConfiguration`).

### Publish Module

Promotes staged module to PowerShell Gallery, creates GitHub release, and deploys documentation to Pages. Managed
through [`PSModule/Publish-PSModule`](https://github.com/PSModule/Publish-PSModule).

**Release coordination:**

- Inspects existing GitHub releases, PowerShell Gallery, and staged module manifest to establish current version.
- Determines next semantic version from configured labels, falling back to automatic patch bumps.
- Generates normalized branch-name prereleases (e.g., `1.0.1-feat-awesome.1`) on PR open/update.
- Cleans up previous prereleases for the same branch when `Publish.Module.AutoCleanup` is `true` (default).
- On merge to default branch, promotes staged module, creates GitHub release with `VersionPrefix`, removes temporary
  prereleases.

## Contributing

Contributions are welcome. Open an issue or pull request to discuss changes.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

