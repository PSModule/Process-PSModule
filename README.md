# Process-PSModule

Process-PSModule provides an opinionated, end-to-end GitHub Actions workflow that builds, tests, documents, and publishes PowerShell modules with minimal setup. It is the production workflow used across the PSModule organization and is designed for repositories created from the [Template-PSModule](https://github.com/PSModule/Template-PSModule) starter.

## What you can expect

- One workflow run manages build, validation, documentation, and publishing across Linux, macOS, and Windows.
- Dynamic behavior driven by repository metadata, GitHub event context, and settings via `.github/PSModule.yml`.
- Every run shares consistent artifacts, logs, and gating so each environment observes the same result.
- Releases can be automated or skipped entirely through labels and configuration.
- Version bumps are controlled by labels on PRs (patch by default, or major/minor via specific labels).
- The workflow keeps module structure, tooling, and release automation aligned with PSModule standards.

## How the workflow responds to your repository

The workflow monitors pull requests to the default branch, manual runs, and scheduled executions. It reacts to open, synchronize, reopen, label, and close events, then decides which jobs to run based on repository configuration and labels.

![Process diagram](./media/Process-PSModule.png)

### Discover and plan

The run begins by reading the configuration file at `.github/PSModule` (YAML, JSON, or PSD1). It inspects repository labels, event payloads, and the staged module layout to decide which operating systems to target, which quality gates are required, and whether publishing is in scope. This discovery step produces shared outputs so downstream phases stay in sync.

### Build and document

When builds are enabled, the workflow copies your `src/` tree into a staging area, honors any `*build.ps1` hooks you commit, composes a root module, and regenerates the manifest when necessary. If documentation is in scope, the staged module output feeds documentation and site generation so the published docs always mirror the built artifact.

### Validate quality

Testing phases execute according to the settings-driven matrices. Source linting, module framework validation, and repository-specific tests all run against the staged module. Optional `tests/BeforeAll.ps1` and `tests/AfterAll.ps1` scripts run once per workflow to handle shared setup and teardown. Coverage targets and consolidated reports enforce the gates you define.

### Publish and close out

When the workflow determines a release is required, it promotes the staged module to the PowerShell Gallery, produces a GitHub release, and deploys documentation to Pages. Labels and settings can skip publishing or trigger cleanup releases for abandoned pull requests.

### Lifecycle across GitHub events

| Job | Open/updated PR | Merged PR | Abandoned PR | Manual run |
|-----|-----------------|-----------|--------------|------------|
| **Gather repo settings** | ✅ Always | ✅ Always | ✅ Always | ✅ Always |
| **Repository lint** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Module build** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Documentation build** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Site build** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Source lint** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Framework tests** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Module-local tests** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Module-local cleanup** | ✅ Yes | ✅ Yes | ✅ Yes* | ✅ Yes |
| **Results aggregation** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Coverage summary** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Site publish** | ❌ No | ✅ Yes | ❌ No | ❌ No |
| **Module publish** | ✅ Yes** | ✅ Yes** | ✅ Yes*** | ✅ Yes** |

\* Runs for cleanup if tests were started.

\*\* Only when build, test, and coverage gates succeed.

\*\*\* Publishes a cleanup or retraction version when required.

## Configure behavior through `.github/PSModule.yml`

The settings file keeps the workflow declarative. Use it to:

- Override the module name that appears in artifacts and releases.
- Enable or skip entire phases (build, docs, site, test, linter, publish) without editing YAML.
- Control which operating systems participate in each matrix.
- Gate releases on coverage percentages or disable coverage entirely for rapid iteration.
- Drive release behavior with label-based version bumping, prerelease strategy, and cleanup preferences.
- Pass custom environment variables into repository linting.

Settings can be expressed as YAML, JSON, or PSD1, and the workflow reads whichever file you place at `.github/PSModule`. The default configuration below illustrates the available keys and their defaults.

<details>
<summary>Default configuration (`PSModule.yml`)</summary>

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

### Configuration patterns

**Enforce coverage targets**

```yaml
Test:
  CodeCoverage:
    PercentTarget: 80
```

**Fast local validation (Linux only)**

```yaml
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

**Tune repository linting**

```yaml
Linter:
  env:
    LOG_LEVEL: DEBUG
    VALIDATE_JSON: true
    VALIDATE_YAML: true
    VALIDATE_MARKDOWN: true
```

## Controlling releases with PR labels

By default, merged pull requests trigger a patch release (incrementing the patch version, e.g., 1.0.0 → 1.0.1). To control the version bump, label your PRs with one of the configured semver labels:

- **Patch** (default): No label needed, or use labels like `patch` or `fix`.
- **Minor**: Use labels like `minor` or `feature` to increment the minor version (e.g., 1.0.0 → 1.1.0).
- **Major**: Use labels like `major` or `breaking` to increment the major version (e.g., 1.0.0 → 2.0.0).

You can customize these labels in your `.github/PSModule.yml` file under `Publish.Module.MajorLabels`, `Publish.Module.MinorLabels`, and `Publish.Module.PatchLabels`. For example, to add a custom label for major releases:

```yaml
Publish:
  Module:
    MajorLabels: 'major, breaking, api-change'
```

To skip publishing entirely for a PR, apply an ignore label like `NoRelease` (configurable via `Publish.Module.IgnoreLabels`).

## Release automation details

Process-PSModule coordinates releases through the shared `Publish-PSModule` action. When publishing is enabled:

- On pull request events it inspects existing GitHub releases, the PowerShell Gallery, and the staged module manifest to establish the current version.
- It determines the next semantic version from the configured labels, falling back to automatic patch bumps when none are supplied. Prerelease labels generate normalized branch-name prereleases that can increment or use date-based identifiers depending on your settings.
- Previous prereleases for the same branch are cleaned up automatically when `Publish.Module.AutoCleanup` remains true, keeping release listings tidy.
- After a merge into the default branch, the workflow promotes the staged module, creates a GitHub release using the configured `VersionPrefix`, and removes temporary prereleases.
- Ignore labels prevent promotion entirely so experimental branches can run the pipeline without shipping packages.

Tune this behavior through the `Publish.Module` block in `.github/PSModule.yml`. Adjust label names, prerelease strategy (`IncrementalPrerelease`, `DatePrereleaseFormat`), cleanup policy, or disable publishing outright when the workflow should stop at validation.

## How repository content influences runs

Process-PSModule expects repositories to follow the staged layout produced by Template-PSModule. The workflow inspects this structure to decide what to compile, document, and publish.

```plaintext
<ModuleName>/
├── .github/                                   # Workflow config, doc/site templates, automation policy
│   ├── linters/                               # Rule sets applied by shared lint steps
│   │   ├── .markdown-lint.yml                 # Markdown rules enforced via super-linter
│   │   ├── .powershell-psscriptanalyzer.psd1  # Analyzer profile for test jobs
│   │   └── .textlintrc                        # Text lint rules surfaced in Build Docs summaries
│   ├── workflows/                             # Entry points for the reusable workflow
│   │   └── Process-PSModule.yml               # Consumer hook into this workflow bundle
│   ├── CODEOWNERS                             # Default reviewers enforced by Process-PSModule checks
│   ├── dependabot.yml                         # Dependency update cadence handled by GitHub
│   ├── mkdocs.yml                             # MkDocs config consumed during site builds
│   ├── PSModule.yml                           # Settings parsed to drive matrices
│   └── release.yml                            # Release automation template invoked on publish
├── examples/                                  # Samples referenced in generated documentation
│   └── General.ps1                            # Example script ingested by Document-PSModule
├── icon/                                      # Icon assets linked from manifest and documentation
│   └── icon.png                               # Default module icon (PNG format)
├── src/                                       # Module source compiled and documented by the pipeline
│   ├── assemblies/                            # Bundled binaries copied into the build artifact
│   ├── classes/                               # Class scripts merged into the root module
│   │   ├── private/                           # Internal classes kept out of exports
│   │   │   └── SecretWriter.ps1               # Example internal class implementation
│   │   └── public/                            # Public classes exported via type accelerators
│   │       └── Book.ps1                       # Example public class documented for consumers
│   ├── data/                                  # Configuration loaded into `$script:` scope at runtime
│   │   ├── Config.psd1                        # Example config surfaced in generated help
│   │   └── Settings.psd1                      # Additional configuration consumed on import
│   ├── formats/                               # Formatting metadata registered during build
│   │   ├── CultureInfo.Format.ps1xml          # Example format included in manifest
│   │   └── Mygciview.Format.ps1xml            # Additional format loaded at import
│   ├── functions/                             # Function scripts exported by the module
│   │   ├── private/                           # Helper functions scoped to the module
│   │   │   ├── Get-InternalPSModule.ps1       # Sample internal helper
│   │   │   └── Set-InternalPSModule.ps1       # Sample internal helper
│   │   └── public/                            # Public commands documented and tested
│   │       ├── Category/                      # Optional: organize commands into categories
│   │       │   ├── Get-CategoryCommand.ps1    # Command file within category
│   │       │   └── Category.md                # Category overview merged into docs output
│   │       ├── Get-PSModuleTest.ps1           # Example command captured by Microsoft.PowerShell.PlatyPS
│   │       ├── New-PSModuleTest.ps1           # Example command exported and tested
│   │       ├── Set-PSModuleTest.ps1           # Example command exported and tested
│   │       └── Test-PSModuleTest.ps1          # Example command exported and tested
│   ├── init/                                  # Initialization scripts executed during module load
│   │   └── initializer.ps1                    # Example init script included in build output
│   ├── modules/                               # Nested modules packaged with the compiled output
│   │   └── OtherPSModule.psm1                 # Example nested module staged for export
│   ├── scripts/                               # Scripts listed in 'ScriptsToProcess'
│   │   └── loader.ps1                         # Loader executed when the module imports
│   ├── types/                                 # Type data merged into the manifest
│   │   ├── DirectoryInfo.Types.ps1xml         # Type definition registered on import
│   │   └── FileInfo.Types.ps1xml              # Type definition registered on import
│   ├── variables/                             # Variable scripts exported by the module
│   │   ├── private/                           # Internal variables scoped to the module
│   │   │   └── PrivateVariables.ps1           # Example private variable seed
│   │   └── public/                            # Public variables exported and documented
│   │       ├── Moons.ps1                      # Example variable surfaced in generated docs
│   │       ├── Planets.ps1                    # Example variable surfaced in generated docs
│   │       └── SolarSystems.ps1               # Example variable surfaced in generated docs
│   ├── finally.ps1                            # Cleanup script appended to the root module
│   ├── header.ps1                             # Optional header injected at the top of the module
│   ├── manifest.psd1 (optional)               # Source manifest reused when present
│   └── README.md                              # Module-level docs ingested by Document-PSModule
├── tests/                                     # Pester suites executed during validation
│   ├── AfterAll.ps1 (optional)                # Cleanup script for ModuleLocal runs
│   ├── BeforeAll.ps1 (optional)               # Setup script for ModuleLocal runs
│   └── <ModuleName>.Tests.ps1                 # Primary test entry point
├── .gitattributes                             # Normalizes line endings across platforms
├── .gitignore                                 # Excludes build artifacts from source control
├── LICENSE                                    # License text surfaced in manifest metadata
└── README.md                                  # Repository overview rendered on GitHub and docs landing
```

Key expectations:

- Keep at least one exported function under `src/functions/public/` and corresponding tests in `tests/`.
- Optional folders (`assemblies`, `formats`, `types`, `variables`, and others) are processed automatically when present.
- Markdown files in `src/functions/public` subfolders become documentation pages alongside generated help.
- The build step compiles `src/` into a root module file and removes the original project layout from the artifact.
- Documentation generation mirrors the `src/functions/public` hierarchy so help content always aligns with source.

## Repository setup

1. [Create a repository from the template](https://github.com/new?template_name=Template-PSModule&template_owner=PSModule&description=Add%20a%20description%20(required)&name=%3CModule%20name%3E).
1. Enable GitHub Pages for the repo, set deployment source to `GitHub Actions`, and remove the default `main` branch protection inside the `github-pages` environment.
1. [Create a PowerShell Gallery API key](https://www.powershellgallery.com/account/apikeys) with rights to publish your module.
1. Add a repository secret named `APIKEY` containing the gallery key.
1. Develop on a feature branch, open a pull request, and allow Process-PSModule to validate the changes.

## Module structure requirements

Process-PSModule expects repositories to follow the staged layout produced by Template-PSModule.

```plaintext
<ModuleName>/
├── .github/                                   # Workflow config, doc/site templates, automation policy
│   ├── linters/                               # Rule sets applied by Build-Docs and lint jobs
│   │   ├── .markdown-lint.yml                 # Markdown rules enforced via super-linter
│   │   ├── .powershell-psscriptanalyzer.psd1  # Analyzer profile for Test jobs
│   │   └── .textlintrc                        # Text lint rules surfaced in Build Docs summaries
│   ├── workflows/                             # Entry points for the reusable workflow
│   │   └── Process-PSModule.yml               # Consumer hook into this workflow bundle
│   ├── CODEOWNERS                             # Default reviewers enforced by Process-PSModule checks
│   ├── dependabot.yml                         # Dependency update cadence handled by GitHub
│   ├── mkdocs.yml                             # MkDocs config consumed during Build-Site
│   ├── PSModule.yml                           # Settings parsed by Get-Settings to drive matrices
│   └── release.yml                            # Release automation template invoked on publish
├── examples/                                  # Samples referenced in generated documentation
│   └── General.ps1                            # Example script ingested by Document-PSModule
├── icon/                                      # Icon assets linked from manifest and documentation
│   └── icon.png                               # Default module icon (PNG format)
├── src/                                       # Module source compiled and documented by the pipeline
│   ├── assemblies/                            # Bundled binaries copied into the build artifact
│   ├── classes/                               # Class scripts merged into the root module
│   │   ├── private/                           # Internal classes kept out of exports
│   │   │   └── SecretWriter.ps1               # Example internal class implementation
│   │   └── public/                            # Public classes exported via type accelerators
│   │       └── Book.ps1                       # Example public class documented for consumers
│   ├── data/                                  # Configuration loaded into `$script:` scope at runtime
│   │   ├── Config.psd1                        # Example config surfaced in generated help
│   │   └── Settings.psd1                      # Additional configuration consumed on import
│   ├── formats/                               # Formatting metadata registered during build
│   │   ├── CultureInfo.Format.ps1xml          # Example format included in manifest
│   │   └── Mygciview.Format.ps1xml            # Additional format loaded at import
│   ├── functions/                             # Function scripts exported by the module
│   │   ├── private/                           # Helper functions scoped to the module
│   │   │   ├── Get-InternalPSModule.ps1       # Sample internal helper
│   │   │   └── Set-InternalPSModule.ps1       # Sample internal helper
│   │   └── public/                            # Public commands documented and tested
│   │       ├── Category/                      # Optional: organize commands into categories
│   │       │   ├── Get-CategoryCommand.ps1    # Command file within category
│   │       │   └── Category.md                # Category overview merged into docs output
│   │       ├── Get-PSModuleTest.ps1           # Example command captured by Microsoft.PowerShell.PlatyPS
│   │       ├── New-PSModuleTest.ps1           # Example command exported and tested
│   │       ├── Set-PSModuleTest.ps1           # Example command exported and tested
│   │       └── Test-PSModuleTest.ps1          # Example command exported and tested
│   ├── init/                                  # Initialization scripts executed during module load
│   │   └── initializer.ps1                    # Example init script included in build output
│   ├── modules/                               # Nested modules packaged with the compiled output
│   │   └── OtherPSModule.psm1                 # Example nested module staged for export
│   ├── scripts/                               # Scripts listed in 'ScriptsToProcess'
│   │   └── loader.ps1                         # Loader executed when the module imports
│   ├── types/                                 # Type data merged into the manifest
│   │   ├── DirectoryInfo.Types.ps1xml         # Type definition registered on import
│   │   └── FileInfo.Types.ps1xml              # Type definition registered on import
│   ├── variables/                             # Variable scripts exported by the module
│   │   ├── private/                           # Internal variables scoped to the module
│   │   │   └── PrivateVariables.ps1           # Example private variable seed
│   │   └── public/                            # Public variables exported and documented
│   │       ├── Moons.ps1                      # Example variable surfaced in generated docs
│   │       ├── Planets.ps1                    # Example variable surfaced in generated docs
│   │       └── SolarSystems.ps1               # Example variable surfaced in generated docs
│   ├── finally.ps1                            # Cleanup script appended to the root module
│   ├── header.ps1                             # Optional header injected at the top of the module
│   ├── manifest.psd1 (optional)               # Source manifest reused when present
│   └── README.md                              # Module-level docs ingested by Document-PSModule
├── tests/                                     # Pester suites executed by Test-Module and Test-ModuleLocal
│   ├── AfterAll.ps1 (optional)                # Cleanup script for ModuleLocal runs
│   ├── BeforeAll.ps1 (optional)               # Setup script for ModuleLocal runs
│   └── <ModuleName>.Tests.ps1                 # Primary test entry point
├── .gitattributes                             # Normalizes line endings across platforms
├── .gitignore                                 # Excludes build artifacts from source control
├── LICENSE                                    # License text surfaced in manifest metadata
└── README.md                                  # Repository overview rendered on GitHub and docs landing
```

Key expectations:

- Keep at least one exported function under `src/functions/public/` and corresponding tests in `tests/`.
- Optional folders (`assemblies`, `formats`, `types`, `variables`, and others) are processed automatically when present.
- Markdown files (`.md`) placed in `src/functions/public` subfolders are merged into the documentation output, preserving the folder structure. Use these for category overviews, conceptual documentation, or grouping related commands.
- The build step compiles `src/` into a root module file and prunes the original structure from the output artifact.
- Documentation generation mirrors the `src/functions/public` hierarchy: auto-generated command help files are placed in the same folder structure as their corresponding `.ps1` source files.

## Build Module job

Process-PSModule compiles each module by invoking the [`PSModule/Build-PSModule`](https://github.com/PSModule/Build-PSModule) composite action. The workflow emphasizes predictable outcomes: repositories provide their source and optional hooks, while the shared action delivers a consistent artifact.

### Supported module types

- Script modules
- Manifest modules

### Practices upheld

- Aligns with the [PowerShellGallery publishing guidelines](https://learn.microsoft.com/powershell/gallery/concepts/publishing-guidelines)
- Targets PowerShell 7.4+ and keeps file ordering deterministic across platforms

### Build pipeline overview

1. Discovers the module name (workflow input fallback: repository name) and stages `outputs/module/<ModuleName>`.
1. Executes repository `*build.ps1` scripts alphabetically so teams can inject preprocessing without forking the action.
1. Copies `src/` into staging, skipping any existing root module so a fresh file can be generated.
1. Rebuilds the module manifest from staged content plus repository metadata.
1. Composes the root module `.psm1` from staged scripts, classes, variables, and support files.
1. Uploads the `module` artifact and exposes `ModuleOutputFolderPath` for documentation and test jobs.

### Root module composition

1. Adds `header.ps1` (when present) to the top of `<ModuleName>.psm1`.
1. Injects a data loader so resources in `data/` become `$script:`-scoped variables.
1. Appends content from `init`, `classes/private`, `classes/public`, `functions/private`, `functions/public`, `variables/private`, `variables/public`, and root-level `*.ps1` files in alphabetical order.
1. Registers public classes and enums using type accelerators to expose them to callers.
1. Emits a trailing `Export-ModuleMember` statement that exports only members sourced from the `public` folders.

### Module manifest enrichment

1. Reuses `manifest.psd1` when provided; otherwise creates a new manifest anchored to the derived module name.
1. Sets baseline metadata including `RootModule`, `ModuleVersion`, `Author`, `CompanyName`, and `Description`.
1. Populates `FileList`, `ModuleList`, `RequiredAssemblies`, `NestedModules`, `ScriptsToProcess`, `TypesToProcess`, `FormatsToProcess`, `DscResourcesToExport`, and export lists from the staged file system.
1. Gathers `#requires` statements to update `RequiredModules`, `PowerShellVersion`, and `CompatiblePSEditions`.
1. Derives `Tags`, `LicenseUri`, `ProjectUri`, and `IconUri` from repository data when values are absent.
1. Preserves optional fields such as `HelpInfoURI`, `ExternalModuleDependencies`, and custom `PrivateData` entries when supplied.

### Artifact output and downstream use

- Updates manifest aliases via `Update-PSModuleManifestAliasesToExport` to keep exports aligned with the compiled root module.
- Returns `ModuleOutputFolderPath` so documentation, testing, and publishing stages operate on an identical payload.
- Uploads the artifact with a one-day retention, protecting downstream jobs from source drift.

### References

- [about_Module_Manifests](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_module_manifests)
- [How to write a PowerShell module manifest](https://learn.microsoft.com/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)
- [New-ModuleManifest](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/new-modulemanifest)
- [Update-ModuleManifest](https://learn.microsoft.com/powershell/module/powershellget/update-modulemanifest)
- [Package metadata values that impact the PowerShell Gallery UI](https://learn.microsoft.com/powershell/gallery/concepts/package-manifest-affecting-ui#powershell-gallery-feature-elements-controlled-by-the-module-manifest)
- [PowerShell scripting performance considerations](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations)
- [PowerShell module authoring considerations](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/module-authoring-considerations)

## Test Module job

Process-PSModule validates the staged module by invoking the [`PSModule/Test-PSModule`](https://github.com/PSModule/Test-PSModule) composite action. The job keeps feedback fast and consistent across matrices so repositories see the same results regardless of operating system.

- Executes SourceCode, PSModule framework, and repository module suites against the built artifact rather than raw source.
- Enables test-driven development with [Invoke-Pester](https://github.com/PSModule/Invoke-Pester) support and honors optional `tests/BeforeAll.ps1` and `tests/AfterAll.ps1` hooks.
- Consolidates results, coverage, and diagnostics into artifacts so later jobs (or manual investigations) consume the same evidence.
- Exposes configuration through `.github/PSModule.yml`, action inputs, and labels, allowing teams to dial in which matrices run and how verbose the reporting should be.

### SourceCode gates

| ID | Category | Description |
|----|----------|-------------|
| NumberOfProcessors | General | Should use `[System.Environment]::ProcessorCount` instead of `$env:NUMBER_OF_PROCESSORS`. |
| Verbose | General | Should not contain `-Verbose` unless it is explicitly disabled with `:$false`. |
| OutNull | General | Should use `$null = ...` instead of piping output to `Out-Null`. |
| NoTernary | General | Should not use ternary operations to maintain compatibility with PowerShell 5.1 and below. |
| LowercaseKeywords | General | All PowerShell keywords should be written in lowercase. |
| FunctionCount | Functions (Generic) | Each script file should contain exactly one function or filter. |
| FunctionName | Functions (Generic) | Script filenames should match the name of the function or filter they contain. |
| CmdletBinding | Functions (Generic) | Functions should include the `[CmdletBinding()]` attribute. |
| ParamBlock | Functions (Generic) | Functions should have a parameter block (`param()`). |
| FunctionTest | Functions (Public) | All public functions/filters should have corresponding tests. |

### Module gates

| Name | Description |
|------|-------------|
| Module Manifest exists | Verifies that a module manifest file is present. |
| Module Manifest is valid | Verifies that the module manifest file is valid. |

### Results and reports

- Emits `Outcome`, `Conclusion`, `Result`, and aggregated counts so downstream jobs can gate on failure without re-parsing logs.
- Produces NUnit-compatible test results and configurable coverage reports, uploaded as artifacts for each matrix entry.
- Supports GitHub step summaries with configurable filters (`StepSummary_Mode`, `StepSummary_ShowTestOverview`, `StepSummary_ShowConfiguration`).
- Offers granular include/exclude controls for tests, tags, paths, and even scriptblocks when diagnosing issues.

#### Action inputs reference

<details>
<summary>Expand to view the full input catalog</summary>

| Name | Description | Required | Default |
| ---- | ----------- | -------- | ------- |
| `Name` | The name of the module to test. The name of the repository is used if not specified. | `false` | |
| `Settings` | The type of tests to run. Can be either `Module` or `SourceCode`. | `true` | |
| `Debug` | Enable debug output. | `false` | `'false'` |
| `Verbose` | Enable verbose output. | `false` | `'false'` |
| `Version` | Specifies the version of the GitHub module to be installed. The value must be an exact version. | `false` | |
| `Prerelease` | Allow prerelease versions if available. | `false` | `'false'` |
| `WorkingDirectory` | The working directory to use for the action. This is the root folder where tests and outputs are expected. | `false` | `'.'` |
| `StepSummary_Mode` | Controls which tests to show in the GitHub step summary. Allows `Full`, `Failed`, or `None`. | `false` | `Failed` |
| `StepSummary_ShowTestOverview` | Controls whether to show the test overview table in the GitHub step summary. | `false` | `false` |
| `StepSummary_ShowConfiguration` | Controls whether to show the configuration details in the GitHub step summary. | `false` | `false` |
| `Run_ExcludePath` | Directories/files to exclude from the run. | `false` | |
| `Run_ScriptBlock` | ScriptBlocks containing tests to be executed. | `false` | |
| `Run_Container` | ContainerInfo objects containing tests to be executed. | `false` | |
| `Run_TestExtension` | Filter used to identify test files (e.g. `.Tests.ps1`). | `false` | |
| `Run_Exit` | Whether to exit with a non-zero exit code on failure. | `false` | |
| `Run_Throw` | Whether to throw an exception on test failure. | `false` | |
| `Run_SkipRun` | Discovery only, skip actual test run. | `false` | |
| `Run_SkipRemainingOnFailure` | Skips remaining tests after the first failure. Options: `None`, `Run`, `Container`, `Block`. | `false` | |
| `Filter_Tag` | Tags of Describe/Context/It blocks to run. | `false` | |
| `Filter_ExcludeTag` | Tags of Describe/Context/It blocks to exclude. | `false` | |
| `Filter_Line` | Filter by file + scriptblock start line (e.g. `C:\tests\file1.Tests.ps1:37`). | `false` | |
| `Filter_ExcludeLine` | Exclude by file + scriptblock start line. Precedence over `Filter_Line`. | `false` | |
| `Filter_FullName` | Full name of a test with wildcards, joined by dot (e.g. `*.describe Get-Item.test1`). | `false` | |
| `CodeCoverage_Enabled` | Enable code coverage. | `false` | |
| `CodeCoverage_OutputFormat` | Format for the coverage report. Possible values: `JaCoCo`, `CoverageGutters`, `Cobertura`. | `false` | |
| `CodeCoverage_OutputPath` | Where to save the code coverage report (relative to the current dir). | `false` | |
| `CodeCoverage_OutputEncoding` | Encoding of the coverage file. | `false` | |
| `CodeCoverage_Path` | Files/directories to measure coverage on (defaults to the main `Path` setting). | `false` | |
| `CodeCoverage_ExcludeTests` | Exclude tests themselves from coverage. | `false` | |
| `CodeCoverage_RecursePaths` | Recurse through coverage directories. | `false` | |
| `CodeCoverage_CoveragePercentTarget` | Desired minimum coverage percentage. | `false` | |
| `CodeCoverage_UseBreakpoints` | Experimental: when `false`, use a profiler-based tracer instead of breakpoints. | `false` | |
| `CodeCoverage_SingleHitBreakpoints` | Remove breakpoints after first hit. | `false` | |
| `TestResult_Enabled` | Enable test-result output (e.g. NUnitXml, JUnitXml). | `false` | |
| `TestResult_OutputFormat` | Possible values: `NUnitXml`, `NUnit2.5`, `NUnit3`, `JUnitXml`. | `false` | |
| `TestResult_OutputPath` | Where to save the test-result report (relative path). | `false` | |
| `TestResult_OutputEncoding` | Encoding of the test-result file. | `false` | |
| `Should_ErrorAction` | Controls if `Should` throws on error (`Stop`) or collects failures (`Continue`). | `false` | |
| `Debug_ShowFullErrors` | Show Pester internal stack on errors (overrides `Output.StackTraceVerbosity` to `Full`). | `false` | |
| `Debug_WriteDebugMessages` | Write debug messages to screen. | `false` | |
| `Debug_WriteDebugMessagesFrom` | Filter debug messages by source (wildcards allowed). | `false` | |
| `Debug_ShowNavigationMarkers` | Write paths after every block/test for easier navigation. | `false` | |
| `Debug_ReturnRawResultObject` | Returns an unfiltered result object, intended for development. | `false` | |
| `Output_Verbosity` | Verbosity: `None`, `Normal`, `Detailed`, `Diagnostic`. | `false` | |
| `Output_StackTraceVerbosity` | Stacktrace detail: `None`, `FirstLine`, `Filtered`, `Full`. | `false` | |
| `Output_CIFormat` | CI format of error output: `None`, `Auto`, `AzureDevops`, `GithubActions`. | `false` | |
| `Output_CILogLevel` | CI log level: `Error` or `Warning`. | `false` | |
| `Output_RenderMode` | How to render console output: `Auto`, `Ansi`, `ConsoleColor`, `Plaintext`. | `false` | |
| `TestDrive_Enabled` | Enable `TestDrive`. | `false` | |
| `TestRegistry_Enabled` | Enable `TestRegistry`. | `false` | |

</details>

#### Action outputs reference

<details>
<summary>Expand to view the published outputs</summary>

| Output | Description |
|--------|-------------|
| `Outcome` | Outcome of the test run. |
| `Conclusion` | Conclusion status of test execution. |
| `Executed` | Indicates if tests were executed. |
| `Result` | Overall result (`Passed`, `Failed`). |
| `FailedCount` | Number of failed tests. |
| `FailedBlocksCount` | Number of failed blocks. |
| `FailedContainersCount` | Number of failed containers. |
| `PassedCount` | Number of passed tests. |
| `SkippedCount` | Number of skipped tests. |
| `InconclusiveCount` | Number of inconclusive tests. |
| `NotRunCount` | Number of tests not run. |
| `TotalCount` | Total tests executed. |

</details>

## Workflow configuration file

Behavior is controlled through `.github/PSModule.yml` (or `.json`/`.psd1`). Settings cascade into the Get-Settings job, which then toggles downstream jobs and matrices.

### Settings catalog

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `Name` | `String` | Overrides the module name (otherwise the repo name is used). | `null` |
| `Test.Skip` | `Boolean` | Bypass every test job. | `false` |
| `Test.Linux.Skip` | `Boolean` | Skip all Linux matrix runs. | `false` |
| `Test.MacOS.Skip` | `Boolean` | Skip all macOS matrix runs. | `false` |
| `Test.Windows.Skip` | `Boolean` | Skip all Windows matrix runs. | `false` |
| `Test.SourceCode.Skip` | `Boolean` | Skip source code tests. | `false` |
| `Test.SourceCode.Linux.Skip` | `Boolean` | Skip source code tests on Linux. | `false` |
| `Test.SourceCode.MacOS.Skip` | `Boolean` | Skip source code tests on macOS. | `false` |
| `Test.SourceCode.Windows.Skip` | `Boolean` | Skip source code tests on Windows. | `false` |
| `Test.PSModule.Skip` | `Boolean` | Skip framework-level module tests. | `false` |
| `Test.PSModule.Linux.Skip` | `Boolean` | Skip framework tests on Linux. | `false` |
| `Test.PSModule.MacOS.Skip` | `Boolean` | Skip framework tests on macOS. | `false` |
| `Test.PSModule.Windows.Skip` | `Boolean` | Skip framework tests on Windows. | `false` |
| `Test.Module.Skip` | `Boolean` | Skip repository module tests. | `false` |
| `Test.Module.Linux.Skip` | `Boolean` | Skip module tests on Linux. | `false` |
| `Test.Module.MacOS.Skip` | `Boolean` | Skip module tests on macOS. | `false` |
| `Test.Module.Windows.Skip` | `Boolean` | Skip module tests on Windows. | `false` |
| `Test.TestResults.Skip` | `Boolean` | Skip the consolidated results job. | `false` |
| `Test.CodeCoverage.Skip` | `Boolean` | Skip code coverage calculation. | `false` |
| `Test.CodeCoverage.PercentTarget` | `Integer` | Required coverage percentage before publishing. | `0` |
| `Test.CodeCoverage.StepSummaryMode` | `String` | Display mode for coverage summaries. | `Missed, Files` |
| `Build.Skip` | `Boolean` | Disable every build job. | `false` |
| `Build.Module.Skip` | `Boolean` | Skip module compilation. | `false` |
| `Build.Docs.Skip` | `Boolean` | Skip documentation linting. | `false` |
| `Build.Docs.ShowSummaryOnSuccess` | `Boolean` | Show super-linter summary even when linting succeeds. | `false` |
| `Build.Site.Skip` | `Boolean` | Skip site generation. | `false` |
| `Publish.Module.Skip` | `Boolean` | Skip module publishing. | `false` |
| `Publish.Module.AutoCleanup` | `Boolean` | Remove stale prerelease versions automatically. | `true` |
| `Publish.Module.AutoPatching` | `Boolean` | Auto-increment patch versions during release. | `true` |
| `Publish.Module.IncrementalPrerelease` | `Boolean` | Use incremental prerelease tagging. | `true` |
| `Publish.Module.DatePrereleaseFormat` | `String` | Date format for prerelease tags (uses .NET format strings). | `''` |
| `Publish.Module.VersionPrefix` | `String` | Prefix prepended to release tags. | `v` |
| `Publish.Module.MajorLabels` | `String` | Labels that trigger a major release. | `major, breaking` |
| `Publish.Module.MinorLabels` | `String` | Labels that trigger a minor release. | `minor, feature` |
| `Publish.Module.PatchLabels` | `String` | Labels that trigger a patch release. | `patch, fix` |
| `Publish.Module.IgnoreLabels` | `String` | Labels that skip releasing entirely. | `NoRelease` |
| `Linter.Skip` | `Boolean` | Skip repository linting. | `false` |
| `Linter.ShowSummaryOnSuccess` | `Boolean` | Show linter summary on success. | `false` |
| `Linter.env` | `Object` | Key/value pairs forwarded to super-linter. | `{}` |

<details>
<summary>Default configuration (`PSModule.yml`)</summary>

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
    ## Workflow usage in consuming repos
