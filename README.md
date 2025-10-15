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
7. Optionally label the PR to control version bumping. The default being a patch bump, but add a label called `minor` or `major` to bump the version
   accordingly.
8. Merge the PR to trigger publishing: the built module is published to PowerShell Gallery and documentation is deployed to GitHub Pages.

## What you get

- One workflow run manages build, validation across Linux, macOS, and Windows, documentation, and publishing the module and documentation.
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
2. **Build and document** — Builds a module from the `src/` tree, runs `*build.ps1` scripts, composes root module, generates the +manifest,
   and generates documentation based on the built module.
3. **Validate quality** — Executes linting, module framework validation, and repository-specific tests against
   staged module. Optional `tests/BeforeAll.ps1` and `tests/AfterAll.ps1` scripts handle shared setup and teardown.
4. **Publish and close out** — Promotes staged module to PowerShell Gallery, creates GitHub release, deploys
   documentation to Pages, and cleans up abandoned prereleases when configured.

**Job lifecycle across GitHub events:**

| Job | Open/updated PR | Merged PR | Abandoned PR | Manual run |
|-|-|-|-|-|
| Get settings | ✅ Always | ✅ Always | ✅ Always | ✅ Always |
| Repository lint | ✅ Yes | ❌ No | ❌ No | ❌ No |
| Module build | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Documentation build | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Site build | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Source lint | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Framework tests | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Module-local tests | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Module-local cleanup| ✅ Yes | ✅ Yes | ✅ Yes* | ✅ Yes |
| Results aggregation | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Coverage summary | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Site publish | ❌ No | ✅ Yes | ❌ No | ❌ No |
| Module publish | ✅ Yes** | ✅ Yes** | ✅ Yes*** | ✅ Yes** |

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
# Fast Linux-only validation (skip macOS/Windows, disable test summary)
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
Linter:
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

Process-PSModule expects repositories to follow the staged layout produced by [Template-PSModule](https://github.com/PSModule/Template-PSModule).
The workflow inspects this structure to decide what to compile, document, and publish.

```plaintext
<ModuleName>/
├── .github/
│   ├── linters/                               # Linter configurations, align with super-linter
│   │   ├── .markdown-lint.yml                 # Markdown rules
│   │   ├── .powershell-psscriptanalyzer.psd1  # PSScriptAnalyzer rules
│   │   └── .textlintrc                        # Text lint rules
│   ├── workflows/
│   │   └── Process-PSModule.yml               # Entry point for this reusable workflow
│   ├── CODEOWNERS                             # Default reviewers enforced by Process-PSModule checks
│   ├── dependabot.yml                         # Dependabot settings
│   ├── mkdocs.yml                             # MkDocs config consumed during site builds
│   ├── PSModule.yml                           # Settings used by the Process-PSModule.yml workflow
│   └── release.yml                            # Release template when making GitHub releases
├── examples/
│   └── General.ps1                            # Example script ingested by Document-PSModule
├── icon/
│   └── icon.png                               # The icon automatically used in the manifest
├── src/
│   ├── assemblies/                            # Bundled binaries copied into build artifact
│   ├── classes/                               # Classes and enums added to the module
│   │   ├── private/                           # Internal classes kept out of exports
│   │   │   └── SecretWriter.ps1
│   │   └── public/                            # Public classes exported via type accelerators
│   │       └── Book.ps1
│   ├── data/                                  # Configuration loaded into $script: scope at runtime
│   │   ├── Config.psd1                        # Example: $script:Config - module internal variable
│   │   └── Settings.psd1                      # Example: $script:Settings - module internal variable
│   ├── formats/                               # View formats, added to the manifest as 'FormatsToProcess'
│   │   ├── CultureInfo.Format.ps1xml
│   │   └── Mygciview.Format.ps1xml
│   ├── functions/                             # Functions added to the module
│   │   ├── private/                           # Helper functions scoped to the module
│   │   │   ├── Get-InternalPSModule.ps1
│   │   │   └── Set-InternalPSModule.ps1
│   │   └── public/                            # Functions that are documented, tested and exported
│   │       ├── Category/                      # Optional: organize commands into folders. Docs mirror structure.
│   │       │   ├── Get-CategoryCommand.ps1
│   │       │   └── Category.md                # Markdown docs are added to the documentation
│   │       ├── Get-PSModuleTest.ps1
│   │       ├── New-PSModuleTest.ps1
│   │       ├── Set-PSModuleTest.ps1
│   │       └── Test-PSModuleTest.ps1
│   ├── init/                                  # Initialization scripts executed during module load, run in module context
│   │   └── initializer.ps1
│   ├── modules/                               # Nested modules packaged with compiled output
│   │   └── OtherPSModule.psm1
│   ├── scripts/                               # Scripts listed in 'ScriptsToProcess', run in user context
│   │   └── loader.ps1
│   ├── types/                                 # Type extensions, added to the manifest as 'TypesToProcess'
│   │   ├── DirectoryInfo.Types.ps1xml
│   │   └── FileInfo.Types.ps1xml
│   ├── variables/                             # Module-level variables
│   │   ├── private/                           # Variables scoped to the module, not exported
│   │   │   └── PrivateVariables.ps1
│   │   └── public/                            # Variables that are exported to the user context
│   │       ├── Moons.ps1
│   │       ├── Planets.ps1
│   │       └── SolarSystems.ps1
│   ├── finally.ps1                            # Script added at the end of the root module
│   ├── header.ps1                             # Script added at the start of the root module
│   └── manifest.psd1                          # If present, a manifest that is reused when building the module
├── tests/
│   ├── AfterAll.ps1                           # Cleanup script for module-local runs
│   ├── BeforeAll.ps1                          # Setup script for module-local runs
│   └── <ModuleName>.Tests.ps1                 # Pester test that is run against the built module on Linux, macOS, and Windows
├── .gitattributes                             # Normalizes line endings across platforms
├── .gitignore                                 # Excludes build artifacts from source control
├── LICENSE                                    # License, added to the manifest
└── README.md                                  # Repository overview rendered on GitHub and the landing for the docs
```

**Key expectations:**

- Keep at least one exported function under `src/functions/public/` and corresponding tests in `tests/`.
- Optional folders (`assemblies`, `formats`, `types`, `variables`, and others) are processed automatically when
  present.
- Markdown files (`.md`) in `src/functions/public` subfolders become documentation pages alongside generated help,
  preserving the folder structure for category overviews and conceptual docs.
- The build step compiles `src/` into a root module file and removes the original project layout from the artifact.
- Documentation generation mirrors the `src/functions/public` hierarchy so help content always aligns with source.

## Phase details

### Get settings

The Get-Settings job initializes the workflow by reading and processing configuration settings, determining the module name, and establishing
the test execution matrix. This phase ensures all downstream jobs operate with consistent, repository-specific parameters.

**What it does:**

1. Gets settings from the `.github/PSModule.yml` (or equivalent JSON/PSD1 file).
2. Determines the module name, defaulting to the repository name.
3. Constructs test suites for PSModule framework tests, and module tests, filtering by operating system (Linux, macOS, Windows),
   depending on settings.
4. Outputs the processed settings as JSON for consumption by subsequent jobs, enabling dynamic workflow behavior.

This phase provides the foundation for conditional job execution, ensuring that builds, tests, and publishing align with repository-specific
requirements and event contexts.

### Repository Linter

Runs [super-linter](https://github.com/super-linter/super-linter) to enforce code quality and style guidelines.
- Honors `.github/linters/` configurations for Markdown, PowerShell, and text linting.
- Configurable settings via the `Linter.env` key in the `.github/PSModule.yml` file.

### Build Module

Compiles each module by invoking [`PSModule/Build-PSModule`](https://github.com/PSModule/Build-PSModule).
Supports script modules and manifest modules. Targets PowerShell 7.4+.

**What it does:**

1. Executes `*build.ps1` scripts alphabetically for preprocessing in `src/`.
2. Builds the module manifest `<moduleName>.psd1` from data in `src/`.
   1. Uses the partial `src/manifest.psd1` if provided; otherwise creates new manifest.
   2. Sets baseline metadata: `RootModule`, `ModuleVersion`, `Author`, `CompanyName`, `Description`.
   3. Populates `FileList`, `ModuleList`, `RequiredAssemblies`, `NestedModules`, `ScriptsToProcess`, `TypesToProcess`,
      `FormatsToProcess`, `DscResourcesToExport`, and export lists.
   4. Gathers `#requires` statements to update `RequiredModules`, `PowerShellVersion`, `CompatiblePSEditions`.
   5. Derives `Tags`, `LicenseUri`, `ProjectUri`, `IconUri` from repository data.
   6. Preserves optional fields (`HelpInfoURI`, `ExternalModuleDependencies`, custom `PrivateData`).
3. Composes root module `<moduleName>.psm1` from scripts, classes, variables, and support files in `src/`.
   1. Adds `header.ps1` (when present) to the top.
   2. Injects a data loader so `.psd1` files in `data/` become `$script:` scoped variables.
   3. Appends content from `init`, `classes/private`, `classes/public`, `functions/private`, `functions/public`,
      `variables/private`, `variables/public`, and root-level `*.ps1` files in alphabetical order.
   4. Registers public classes and enums using type accelerators.
   5. Emits trailing `Export-ModuleMember` statement exporting only members from `public` folders.
4.  Uploads `module` artifact and exposes `ModuleOutputFolderPath` for downstream jobs.

**References:**

- [about_Module_Manifests](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_module_manifests)
- [How to write a PowerShell module manifest](https://learn.microsoft.com/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)
- [PowerShellGallery publishing guidelines](https://learn.microsoft.com/powershell/gallery/concepts/publishing-guidelines)

### Build Documentation

Generates module documentation by invoking [`PSModule/Document-PSModule`](https://github.com/PSModule/Document-PSModule).

- Produces Markdown-based help files from the built module using
  [Microsoft.PowerShell.PlatyPS](https://github.com/PowerShell/platyPS).
- Integrates conceptual documentation from `src/functions/public/` subfolders.

### Build Site

Creates a documentation website using [MkDocs](https://www.mkdocs.org/) and the
[Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) theme.

- Consumes `docs/` for custom pages and `.github/mkdocs.yml` for site configuration.
- Automatically generates navigation based on `src/functions/public/` structure.

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
