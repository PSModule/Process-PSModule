# Process-PSModule Constitution

## Product Overview

**Process-PSModule** is a **reusable workflow product** that provides an **opinionated flow and structure** for building PowerShell modules using GitHub Actions. It is NOT a library or toolkit; it is a complete CI/CD workflow framework designed to be consumed by PowerShell module repositories.

### Product Characteristics

- **Opinionated Architecture**: Defines a specific workflow execution order and module structure
- **Reusable Workflows**: Consuming repositories call Process-PSModule workflows via `uses:` syntax
- **Configurable via Settings**: Behavior customized through `.github/PSModule.yml` (or JSON/PSD1) in consuming repos
- **Structure Requirements**: Consuming repos MUST follow documented structure in GitHub Actions README files
- **Not for Local Development**: Designed exclusively for GitHub Actions execution environment

### Consuming Repository Requirements

Repositories that consume Process-PSModule workflows MUST:
- Follow the module source structure documented in framework actions (see Required Module Structure below)
- Provide configuration file (`.github/PSModule.yml`) with appropriate settings
- Adhere to the opinionated workflow execution order
- Reference Process-PSModule workflows using stable version tags (e.g., `@v4`)
- Review action README documentation for structure and configuration requirements
- Use the [Template-PSModule](https://github.com/PSModule/Template-PSModule) repository as a starting point

### Required Module Structure

**Process-PSModule enforces an opinionated module structure.** Consuming repositories MUST organize their PowerShell module following this complete structure:

#### Complete Repository Structure

```plaintext
<ModuleName>/                       # Repository root
├── .github/                        # GitHub Actions configuration
│   ├── linters/                    # Linter configuration files
│   │   ├── .jscpd.json             # Copy/paste detector settings
│   │   ├── .markdown-lint.yml      # Markdown linter settings
│   │   ├── .powershell-psscriptanalyzer.psd1  # PSScriptAnalyzer rules
│   │   └── .textlintrc             # Text linter settings
│   ├── workflows/                  # GitHub Actions workflows
│   │   ├── Linter.yml              # Linting workflow (optional)
│   │   ├── Nightly-Run.yml         # Scheduled validation (optional)
│   │   └── Process-PSModule.yml    # Main workflow (REQUIRED)
│   ├── CODEOWNERS                  # Code ownership and review assignments
│   ├── dependabot.yml              # Dependency update automation
│   ├── mkdocs.yml                  # Material for MkDocs site configuration
│   ├── PSModule.yml                # Process-PSModule settings (YAML/JSON/PSD1 supported)
│   └── release.yml                 # GitHub release configuration
├── examples/                       # Usage examples (optional)
│   └── General.ps1                 # Example script
├── icon/                           # Module icon (optional, referenced in manifest)
│   └── icon.png                    # PNG icon file
├── src/                            # MODULE SOURCE CODE (REQUIRED)
│   ├── assemblies/                 # .NET assemblies (.dll) to load
│   ├── classes/                    # PowerShell classes and enums
│   │   ├── private/                # Private (not exported)
│   │   └── public/                 # Public (exported)
│   ├── data/                       # Configuration data files loaded as private variables (.psd1)
│   │   ├── Config.psd1             # Example configuration file
│   │   └── Settings.psd1           # Example settings file
│   ├── formats/                    # Format definition files (.ps1xml)
│   ├── functions/                  # The functions for the PowerShell module
│   │   ├── private/                # Private (not exported)
│   │   └── public/                 # Public (exported)
│   │       └── <SubFolder>/        # Optional: Group functions by category
│   │           ├── <SubFolder>.md  # Optional: Category documentation
│   │           └── Get-*.ps1       # Example: Get commands
│   ├── init/                       # Initialization scripts
│   │   └── initializer.ps1         # Example initialization script
│   ├── modules/                    # Nested PowerShell modules (.psm1)
│   ├── scripts/                    # Script files that are loaded to the users runtime on import (.ps1)
│   │   └── loader.ps1              # Example script file
│   ├── types/                      # Type definition files (.ps1xml)
│   ├── variables/                  # Variables for the PowerShell module
│   │   ├── private/                # Private (not exported)
│   │   │   └── PrivateVariables.ps1
│   │   └── public/                 # Public (exported)
│   │       ├── Moons.ps1
│   │       ├── Planets.ps1
│   │       └── SolarSystems.ps1
│   ├── finally.ps1                 # Code executed at module load end (optional)
│   ├── header.ps1                  # Code executed at module load start (optional)
│   ├── manifest.psd1               # PowerShell module manifest (optional, auto-generated if missing)
│   └── README.md                   # Documentation reference (points to Build-PSModule)
├── tests/                          # Module tests (REQUIRED for Test-ModuleLocal)
│   ├── Environments/               # Optional: Test environment configurations
│   │   └── Environment.Tests.ps1
│   ├── MyTests/                    # Optional: Additional test suites
│   │   └── <ModuleName>.Tests.ps1
│   ├── AfterAll.ps1                # Teardown script (optional, runs once after all test matrix jobs)
│   ├── BeforeAll.ps1               # Setup script (optional, runs once before all test matrix jobs)
│   ├── <ModuleName>.Tests.ps1      # Module functional tests (Pester)
│   └── Environment.Tests.ps1       # Environment validation tests (optional)
├── .gitattributes                  # Git line ending configuration
├── .gitignore                      # Git ignore patterns
├── LICENSE                         # License file (referenced in manifest)
└── README.md                       # Module documentation and usage
```

#### Module Source Structure Details (`src/` folder)

The `src/` folder contains the module source code that Build-PSModule compiles into a production-ready module:

**Required Files/Folders**:

- At least one `.ps1` file in `functions/public/` to export functionality
- `tests/` folder at repository root with at least one Pester test file

**Optional Configuration Files**:

- `manifest.psd1` - PowerShell module manifest (auto-generated if missing with GitHub metadata)
- `header.ps1` - Code executed at module load start (before any other code)
- `finally.ps1` - Code executed at module load end (after all other code)
- `README.md` - Documentation pointer (typically references Build-PSModule for structure)

**Source Folders** (all optional, include only what your module needs):

- `assemblies/` - .NET assemblies (`.dll`) loaded into module session
- `classes/private/` - Private PowerShell classes (not exported)
- `classes/public/` - Public PowerShell classes (exported via TypeAccelerators)
- `data/` - Configuration data files (`.psd1`) loaded as module variables
- `formats/` - Format definition files (`.ps1xml`) for object display
- `functions/private/` - Private functions (internal implementation)
  - Supports subdirectories for grouping (e.g., `functions/public/ComponentA/`, `functions/public/ComponentB/`)
- `functions/public/` - Public functions (exported to module consumers)
  - Supports subdirectories for grouping (e.g., `functions/public/ComponentA/`, `functions/public/ComponentB/`)
  - Optional category documentation files (e.g., `functions/public/PSModule/PSModule.md`)
- `init/` - Initialization scripts (executed first during module load)
- `modules/` - Nested PowerShell modules (`.psm1`) or additional assemblies
- `scripts/` - Script files (`.ps1`) to process in caller's scope
- `types/` - Type definition files (`.ps1xml`) for custom type extensions
- `variables/private/` - Private variables (module scope only)
- `variables/public/` - Public variables (exported to module consumers)

**Build Processing**:

- Build-PSModule compiles `src/` into a single root module file (`<ModuleName>.psm1`)
- Source folders are removed from output after processing (only compiled module remains)
- Files processed in alphabetical order within each folder
- See "Build Process Requirements" section for detailed compilation flow

#### Repository Configuration Details

**GitHub Actions Configuration** (`.github/` folder):

- `PSModule.yml` (or `.json`/`.psd1`) - **REQUIRED** configuration file controlling Process-PSModule behavior
- `workflows/Process-PSModule.yml` - **REQUIRED** workflow file calling reusable Process-PSModule workflow
- `mkdocs.yml` - Material for MkDocs configuration for GitHub Pages documentation
- `linters/` - Linter configuration files (optional, uses framework defaults if missing)
- Other workflows (Linter, Nightly-Run) are optional supplementary workflows

**Documentation Assets**:

- `LICENSE` - Referenced in module manifest `LicenseUri` property
- `icon/icon.png` - Referenced in module manifest `IconUri` property (public URL)
- `README.md` - Project documentation, referenced in GitHub repository metadata
- `examples/` - Usage examples for module consumers

**Testing Requirements**:

- `tests/` folder at repository root (NOT inside `src/`)
- Pester test files (`.Tests.ps1`) for module validation
- Optional `BeforeAll.ps1` and `AfterAll.ps1` scripts for external test resource management (see below)
- Tests executed by Test-ModuleLocal workflow across all platforms
- See "Workflow Execution Order" section for BeforeAll/AfterAll/Test workflow sequence

**BeforeAll/AfterAll Test Scripts** (Optional):

Process-PSModule supports optional test setup and teardown scripts that execute once per workflow run (not per platform):

- **`tests/BeforeAll.ps1`** - Runs once before all Test-ModuleLocal matrix jobs
  - **Purpose**: Setup external test resources independent of test platform/OS
  - **Intended Use**: Deploy cloud infrastructure via APIs, create external database instances, initialize test data in third-party services
  - **NOT Intended For**: OS-specific dependencies, platform-specific test files, test-specific resources for individual matrix combinations
  - **Execution**: Runs in `tests/` directory on ubuntu-latest with full access to environment secrets
  - **Error Handling**: Script failures halt the testing workflow (setup must succeed)
  - **Example Use Cases**: Deploy Azure/AWS resources via APIs, create external PostgreSQL databases, initialize SaaS test accounts

- **`tests/AfterAll.ps1`** - Runs once after all Test-ModuleLocal matrix jobs complete
  - **Purpose**: Cleanup external test resources independent of test platform/OS
  - **Intended Use**: Remove cloud infrastructure via APIs, delete external database instances, cleanup test data in third-party services
  - **NOT Intended For**: OS-specific cleanup, platform-specific file removal, test-specific cleanup for individual matrix combinations
  - **Execution**: Runs in `tests/` directory on ubuntu-latest with full access to environment secrets
  - **Error Handling**: Script failures logged as warnings but don't halt workflow (cleanup is best-effort)
  - **Always Executes**: Runs even if tests fail (via `if: always()` condition)
  - **Example Use Cases**: Delete Azure/AWS resources via APIs, remove external databases, cleanup SaaS test accounts

**Key Distinction**: BeforeAll/AfterAll are for managing **external resources via APIs** that exist outside GitHub Actions execution environment. Test-specific resources for individual OS/platform combinations should be created within the tests themselves using Pester `BeforeAll`/`AfterAll` blocks.

**Key Points**:

- **Private vs Public**: `private/` folders contain internal implementations; `public/` folders contain exported elements
- **Optional Components**: Not all folders are required; include only what your module needs
- **Function Organization**: Functions can be organized in subdirectories with optional category documentation
- **Manifest Generation**: If `manifest.psd1` is not provided, Build-PSModule auto-generates with GitHub metadata
- **Minimal Structure**: At minimum, provide `src/functions/public/<Function>.ps1` and `tests/<ModuleName>.Tests.ps1`
- **Template Reference**: Use [Template-PSModule](https://github.com/PSModule/Template-PSModule) as starting point

**Documentation References**:

- [Build-PSModule README](https://github.com/PSModule/Build-PSModule) - Complete build process details
- [Template-PSModule](https://github.com/PSModule/Template-PSModule) - Reference implementation
- [Process-PSModule Configuration](#configuration) - Settings file documentation

### Workflow Integration Requirements

Consuming repositories MUST create a workflow file (e.g., `.github/workflows/Process-PSModule.yml`) that calls the reusable Process-PSModule workflow:

```yaml
name: Process-PSModule

on:
  pull_request:
    branches: [main]
    types: [closed, opened, reopened, synchronize, labeled]

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v4
    secrets:
      APIKEY: ${{ secrets.APIKEY }}  # PowerShell Gallery API key
```

**Configuration Requirements**:

- Configuration file at `.github/PSModule.yml` (YAML, JSON, or PSD1 format supported)
- Reference: [Process-PSModule Configuration Documentation](https://github.com/PSModule/Process-PSModule#configuration)
- Use Template-PSModule as starting point: [Template-PSModule](https://github.com/PSModule/Template-PSModule)

### Build Process Requirements

**Process-PSModule uses the Build-PSModule action to compile module source code into a production-ready PowerShell module.** The build process is automated and opinionated, following a specific execution flow:

#### Build Execution Flow

1. **Execute Custom Build Scripts** (Optional)
   - Build-PSModule searches for `*build.ps1` files **anywhere in the repository**
   - Scripts are executed in **alphabetical order by filename** (path-independent)
   - Allows custom pre-build logic (e.g., code generation, asset processing, configuration setup)
   - Example: `1-build.ps1` runs before `2-build.ps1` regardless of directory location
   - Custom scripts can modify source files before the build process continues
2. **Copy Source Code**
   - All files from `src/` folder are copied to the output folder
   - Existing root module file (`<ModuleName>.psm1`) is **excluded** (recreated in step 4)
   - Creates a clean build environment for compilation
3. **Build Module Manifest** (`<ModuleName>.psd1`)
   - Searches for existing `manifest.psd1` or `<ModuleName>.psd1` in source
   - If found, uses it as base (preserving specified properties)
   - If not found, creates new manifest from scratch
   - **Automatically Derived Properties**:
     - `RootModule`: Set to `<ModuleName>.psm1`
     - `ModuleVersion`: Temporary value (`999.0.0`) - updated by Publish-PSModule during release
     - `Author`: GitHub repository owner (or preserved from source manifest)
     - `CompanyName`: GitHub repository owner (or preserved from source manifest)
     - `Copyright`: Generated as `(c) YYYY <Owner>. All rights reserved.` (or preserved from source manifest)
     - `Description`: GitHub repository description (or preserved from source manifest)
     - `GUID`: New GUID generated by New-ModuleManifest
     - `FileList`: All files in the module output folder
     - `RequiredAssemblies`: All `*.dll` files from `assemblies/` and `modules/` (depth = 1)
     - `NestedModules`: All `*.psm1`, `*.ps1`, `*.dll` files from `modules/` (one level down)
     - `ScriptsToProcess`: All `*.ps1` files from `scripts/` folder (loaded into caller session)
     - `TypesToProcess`: All `*.Types.ps1xml` files (searched recursively)
     - `FormatsToProcess`: All `*.Format.ps1xml` files (searched recursively)
     - `DscResourcesToExport`: All `*.psm1` files from `resources/` folder
     - `FunctionsToExport`: All functions from `functions/public/` (determined by AST parsing)
     - `CmdletsToExport`: Empty array (or preserved from source manifest)
     - `VariablesToExport`: All variables from `variables/public/` (determined by AST parsing)
     - `AliasesToExport`: All aliases from `functions/public/` (determined by AST parsing)
     - `ModuleList`: All `*.psm1` files in source folder (excluding root module)
     - `RequiredModules`: Gathered from `#Requires -Modules` statements in source files
     - `PowerShellVersion`: Gathered from `#Requires -Version` statements in source files
     - `CompatiblePSEditions`: Gathered from `#Requires -PSEdition` statements (defaults to `@('Core','Desktop')`)
     - `Tags`: GitHub repository topics plus compatibility tags from source files
     - `LicenseUri`: Public URL to `LICENSE` file (or preserved from source manifest)
     - `ProjectUri`: GitHub repository URL (or preserved from source manifest)
     - `IconUri`: Public URL to `icon/icon.png` (or preserved from source manifest)
   - **Preserved from Source Manifest** (if provided):
     - `PowerShellHostName`, `PowerShellHostVersion`, `DotNetFrameworkVersion`, `ClrVersion`, `ProcessorArchitecture`
     - `RequireLicenseAcceptance` (defaults to `false` if not specified)
     - `ExternalModuleDependencies`, `HelpInfoURI`, `DefaultCommandPrefix`
     - `ReleaseNotes` (not automated - can be set via PR/release description)
     - `Prerelease` (managed by Publish-PSModule during release)
4. **Build Root Module** (`<ModuleName>.psm1`)
   - Creates new root module file (ignoring any existing `.psm1` in source)
   - **Compilation Order**:
     1. **Module Header**:
        - Adds content from `header.ps1` if exists (then removes file)
        - If no `header.ps1`, adds default `[CmdletBinding()]` parameter block
        - Adds PSScriptAnalyzer suppression for cross-platform compatibility
     2. **Post-Header Initialization**:
        - Loads module manifest information (`$script:PSModuleInfo`)
        - Adds platform detection (`$IsWindows` for PS 5.1 compatibility)
     3. **Data Loader** (if `data/` folder exists):
        - Recursively imports all `*.psd1` files from `data/` folder
        - Creates module-scoped variables: `$script:<filename>` for each data file
        - Example: `data/Config.psd1` becomes `$script:Config`
     4. **Source File Integration** (in this specific order):
        - Processes each folder alphabetically within the folder, files on root first, then subfolders
        - Files are wrapped with debug logging regions
        - After processing, source folders are **removed** from output:
          1. `init/` - Initialization scripts (executed first during module load)
          2. `classes/private/` - Private PowerShell classes (not exported)
          3. `classes/public/` - Public PowerShell classes (exported via TypeAccelerators)
          4. `functions/private/` - Private functions (not exported)
          5. `functions/public/` - Public functions (exported to module consumers)
          6. `variables/private/` - Private variables (not exported)
          7. `variables/public/` - Public variables (exported to module consumers)
          8. Any remaining `*.ps1` files on module root
     5. **Class and Enum Exporter** (if `classes/public/` exists):
        - Uses `System.Management.Automation.TypeAccelerators` for type registration
        - Exports enums from `classes/public/` as type accelerators
        - Exports classes from `classes/public/` as type accelerators
        - Adds `OnRemove` handler to clean up type accelerators when module is removed
        - Provides Write-Verbose output for each exported type
     6. **Export-ModuleMember**:
        - Adds `Export-ModuleMember` call with explicit lists
        - Only exports items from `public/` folders:
          - **Functions**: From `functions/public/`
          - **Cmdlets**: From manifest (usually empty for script modules)
          - **Variables**: From `variables/public/`
          - **Aliases**: From functions in `functions/public/`
     7. **Format with PSScriptAnalyzer**:
        - Entire root module content is formatted using `Invoke-Formatter`
        - Uses PSScriptAnalyzer settings from `Build/PSScriptAnalyzer.Tests.psd1`
        - Ensures consistent code style and UTF-8 BOM encoding
5. **Update Manifest Aliases**
   - Re-analyzes root module to extract actual aliases defined
   - Updates `AliasesToExport` in manifest with discovered aliases
6. **Upload Module Artifact**
   - Built module is packaged and uploaded as workflow artifact
   - Artifact name defaults to `module` (configurable via action input)
   - Available for subsequent workflow steps (testing, publishing)

#### Build Process Constraints

- **No Manual Root Module**: Any existing `.psm1` file in `src/` is **ignored and replaced**
- **Source Folder Removal**: Processed source folders are removed from output (only compiled root module remains)
- **Alphabetical Processing**: Files within each folder are processed alphabetically
- **Manifest Precedence**: Source manifest values take precedence over generated values
- **UTF-8 BOM Encoding**: Final root module uses UTF-8 with BOM encoding
- **PowerShell 7.4+ Target**: Build process and generated code target PowerShell 7.4+

#### Build Process References

- [Build-PSModule Action](https://github.com/PSModule/Build-PSModule)
- [PowerShell Gallery Publishing Guidelines](https://learn.microsoft.com/powershell/gallery/concepts/publishing-guidelines)
- [PowerShell Module Manifests](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_module_manifests)
- [PowerShell Module Authoring](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/module-authoring-considerations)

## Core Principles

### I. Workflow-First Design (NON-NEGOTIABLE)

Every feature MUST be implemented as a reusable GitHub Actions workflow component. This is NOT a local development framework; it is designed for CI/CD execution. Workflows MUST:
- Be composable and callable from other workflows using `uses:` syntax
- Use clearly defined inputs and outputs with proper documentation
- Follow the single responsibility principle (one workflow = one concern)
- Support matrix strategies for parallel execution where appropriate
- Be independently testable via the CI validation workflow (`.github/workflows/ci.yml`)
- Delegate logic to reusable GitHub Actions (from github.com/PSModule organization)
- **Avoid inline PowerShell code** in workflow YAML; use action-based script files instead
- Reference actions by specific versions or tags for stability

**Rationale**: Reusable workflow architecture enables maintainability, reduces duplication, and allows consuming repositories to leverage Process-PSModule capabilities consistently. Action-based scripts provide better testability, reusability, and version control than inline code.

### II. Test-Driven Development (NON-NEGOTIABLE)

All code changes MUST follow strict TDD practices using Pester and PSScriptAnalyzer:

- Tests MUST be written before implementation
- Tests MUST fail initially (Red phase)
- Implementation proceeds only after failing tests exist (Green phase)
- Code MUST be refactored while maintaining passing tests (Refactor phase)
- PSScriptAnalyzer rules MUST pass for all PowerShell code
- Manual testing procedures MUST be documented when automated testing is insufficient
- **Workflow functionality MUST be validated** through CI workflow tests (`.github/workflows/ci.yml`)
- Consuming module repositories SHOULD use CI workflow for nightly validation

**Rationale**: TDD ensures code quality, prevents regressions, and creates living documentation through tests. This is fundamental to project reliability. CI workflow validation ensures the entire framework functions correctly in real-world scenarios.

### III. Platform Independence with Modern PowerShell

**Modules MUST be built to be cross-platform.** All workflows, features, and consuming modules MUST support cross-platform execution (Linux, macOS, Windows) using **PowerShell 7.4 or newer**:
- Use platform-agnostic PowerShell Core 7.4+ constructs exclusively
- **Modules MUST function identically** on Linux, macOS, and Windows
- Cross-platform compatibility is **verified through Test-ModuleLocal** workflow
- Test-ModuleLocal executes module tests on: `ubuntu-latest`, `windows-latest`, `macos-latest`
- **BeforeAll/AfterAll scripts** execute on `ubuntu-latest` only (external resource setup)
- Implement matrix testing across all supported operating systems for all workflow components
- Document any platform-specific behaviors or limitations explicitly
- Test failures on any platform MUST block merging
- Provide skip mechanisms for platform-specific tests when justified (with clear rationale)
- **No backward compatibility** required for Windows PowerShell 5.1 or earlier PowerShell Core versions

**Rationale**: PowerShell 7.4+ provides consistent cross-platform behavior and modern language features. Focusing on a single modern version reduces complexity and maintenance burden. Modules built with Process-PSModule framework must work seamlessly across all platforms, verified through automated matrix testing in Test-ModuleLocal, ensuring maximum compatibility for consuming projects on contemporary platforms.

### IV. Quality Gates and Observability

Every workflow execution MUST produce verifiable quality metrics:

- Test results MUST be captured in structured formats (JSON reports)
- Code coverage MUST be measured and reported
- Linting results MUST be captured and enforced
- All quality gates MUST fail the workflow if thresholds are not met
- Workflow steps MUST produce clear, actionable error messages
- Debug mode MUST be available for troubleshooting

**Rationale**: Measurable quality gates prevent degradation over time and provide clear feedback. Observability enables rapid debugging and continuous improvement.

### V. Continuous Delivery with Semantic Versioning

Release management MUST be automated and follow SemVer 2.0.0:

- Version bumps MUST be determined by PR labels (major, minor, patch)
- Releases MUST be automated on merge to main branch
- PowerShell Gallery publishing MUST be automatic for labeled releases
- GitHub releases MUST be created with complete changelogs
- Prerelease versioning MUST support incremental or date-based formats
- Documentation MUST be published to GitHub Pages automatically

**Rationale**: Automated releases reduce human error, ensure consistency, and enable rapid iteration while maintaining clear version semantics.

## Pull Request Workflow and Publishing Process

Process-PSModule implements an **automated publishing workflow** triggered by pull request events. The workflow behavior is controlled by PR labels following Semantic Versioning (SemVer 2.0.0) conventions.

### PR Label-Based Release Types

Pull requests MUST use labels to determine release behavior:

#### Version Increment Labels (SemVer)

- **`major`** - Breaking changes, incompatible API changes
  - Increments major version: `1.2.3` → `2.0.0`
  - Resets minor and patch to zero

- **`minor`** - New features, backward-compatible functionality additions
  - Increments minor version: `1.2.3` → `1.3.0`
  - Resets patch to zero

- **`patch`** - bugfixes, backward-compatible patches (default)
  - Increments patch version: `1.2.3` → `1.2.4`
  - Applied by default when no version label specified (if AutoPatching enabled)

#### Special Release Labels

- **`prerelease`** - Creates prerelease version (unmerged PR publishing)
  - Publishes module to PowerShell Gallery with prerelease tag
  - Creates GitHub Release marked as prerelease
  - Prerelease tag format: `<version>-<branchname><increment>`
  - Example: `1.2.4-featureauth001` for branch `feature/auth`
  - Only applies to **unmerged PRs** (opened, reopened, synchronized, labeled)
  - When merged to main, normal release takes precedence (prerelease label ignored)

- **`NoRelease`** - Skips all publishing
  - Workflow runs build and test jobs
  - Publishing jobs (Publish-Module, Publish-Site) are skipped
  - Used for documentation-only changes or work-in-progress validation

### Workflow Conditional Execution

The Process-PSModule workflow uses **dynamic conditions** to determine job execution:

#### Always Execute (All PR States)

- **Get-Settings** - Configuration loading
- **Build-Module** - Module compilation
- **Build-Docs** - Documentation generation
- **Build-Site** - Static site generation
- **Test-SourceCode** - Source code validation
- **Lint-SourceCode** - Code quality checks
- **Test-Module** - Built module validation
- **Test-ModuleLocal** - Pester tests across platforms
- **Get-TestResults** - Test aggregation
- **Get-CodeCoverage** - Coverage analysis

#### Conditional Execution (Based on PR State and Labels)

**Publish-Site** (GitHub Pages deployment):

- **Executes when**: PR is **merged** to default branch AND tests pass
- **Skipped when**: PR is open/synchronized OR not merged OR scheduled run OR manual trigger
- Condition: `github.event_name == 'pull_request' AND github.event.pull_request.merged == true`

**Publish-Module** (PowerShell Gallery publishing):

- **Executes when**:
  - PR is **merged** to default branch AND tests pass (normal release), OR
  - PR has **`prerelease` label** AND PR is **not merged** AND tests pass (prerelease)
- **Skipped when**:
  - PR has `NoRelease` label, OR
  - Scheduled run (cron trigger), OR
  - Manual run (workflow_dispatch), OR
  - Tests fail
- Condition: `(github.event_name == 'pull_request' AND github.event.pull_request.merged == true) OR (labels contains 'prerelease' AND NOT merged)`

### Publishing Behavior Examples

| PR State | Labels | Build/Test | Publish-Module | Publish-Site | Version |
|----------|--------|------------|----------------|--------------|---------|
| Opened | `minor` | ✅ Yes | ❌ No | ❌ No | N/A (not published) |
| Opened | `prerelease` | ✅ Yes | ✅ Yes (prerelease) | ❌ No | `1.3.0-branchname001` |
| Opened | `prerelease`, `minor` | ✅ Yes | ✅ Yes (prerelease) | ❌ No | `1.3.0-branchname001` |
| Synchronized | `major` | ✅ Yes | ❌ No | ❌ No | N/A (not published) |
| Synchronized | `prerelease` | ✅ Yes | ✅ Yes (prerelease) | ❌ No | `1.3.0-branchname002` |
| Merged | `minor` | ✅ Yes | ✅ Yes (normal) | ✅ Yes | `1.3.0` |
| Merged | `major` | ✅ Yes | ✅ Yes (normal) | ✅ Yes | `2.0.0` |
| Merged | `patch` | ✅ Yes | ✅ Yes (normal) | ✅ Yes | `1.2.4` |
| Merged | (no label) | ✅ Yes | ✅ Yes (if AutoPatching) | ✅ Yes | `1.2.4` (patch) |
| Merged | `NoRelease` | ✅ Yes | ❌ No | ❌ No | N/A (skipped) |
| Merged | `prerelease`, `minor` | ✅ Yes | ✅ Yes (normal) | ✅ Yes | `1.3.0` (prerelease ignored) |
| Scheduled (cron) | N/A | ✅ Yes | ❌ No | ❌ No | N/A (validation only) |
| Manual (workflow_dispatch) | N/A | ✅ Yes | ❌ No | ❌ No | N/A (validation only) |

### Version Calculation Process

The Publish-PSModule action determines the new version using this process:

1. **Get Latest Version**
   - Query PowerShell Gallery for latest published version
   - Query GitHub Releases for latest release version
   - Use the higher of the two as base version
2. **Determine Version Increment**
   - Check PR labels for `major`, `minor`, or `patch`
   - If no version label and AutoPatching enabled, default to `patch`
   - If no version label and AutoPatching disabled, skip publishing
3. **Calculate New Version**
   - Apply SemVer increment based on label
   - Major: `1.2.3` → `2.0.0`
   - Minor: `1.2.3` → `1.3.0`
   - Patch: `1.2.3` → `1.2.4`
4. **Add Prerelease Tag** (if `prerelease` label present on unmerged PR)
   - Extract branch name, sanitize to alphanumeric only
   - Query existing prerelease versions with same branch name
   - Increment prerelease counter
   - Format: `<version>-<branchname><increment>`
   - Example: `1.3.0-featureauth001`, `1.3.0-featureauth002`
5. **Publish to PowerShell Gallery**
   - Upload module with calculated version
   - Set prerelease flag if prerelease tag present
   - Validate publication success
6. **Create GitHub Release**
   - Generate release notes from PR description and commits
   - Create release with version tag (e.g., `v1.3.0` or `v1.3.0-featureauth001`)
   - Mark as prerelease if prerelease tag present
   - Attach module artifact

### Configuration Options

Repositories can configure publishing behavior in `.github/PSModule.yml`:

```yaml
Publish:
  Module:
    AutoPatching: true                    # Auto-apply patch when no label
    AutoCleanup: false                    # Remove old prereleases
    IncrementalPrerelease: true           # Use incremental prerelease counter
    DatePrereleaseFormat: ''              # Alternative: date-based prerelease (yyyyMMddHHmmss)
    VersionPrefix: 'v'                    # Prefix for git tags (e.g., v1.2.3)
    MajorLabels: ['major', 'breaking']    # Labels that trigger major bump
    MinorLabels: ['minor', 'feature']     # Labels that trigger minor bump
    PatchLabels: ['patch', 'fix', 'bug']  # Labels that trigger patch bump
    IgnoreLabels: ['NoRelease', 'skip']   # Labels that skip publishing
```

### Workflow Trigger Configuration

Consuming repositories MUST configure their workflow file to trigger on appropriate PR events:

```yaml
name: Process-PSModule

on:
  pull_request:
    branches: [main]
    types:
      - closed      # Detect merged PRs
      - opened      # Initial PR creation
      - reopened    # Reopened PR
      - synchronize # New commits pushed
      - labeled     # Label added/changed

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v4
    secrets:
      APIKEY: ${{ secrets.APIKEY }}  # Required for publishing
```

**Key Points**:

- **`closed` event** with `github.event.pull_request.merged == true` triggers normal releases
- **`labeled` event** allows immediate prerelease publishing when `prerelease` label added
- **`synchronize` event** with `prerelease` label publishes new prerelease on each push
- **Secrets** MUST include `APIKEY` for PowerShell Gallery publishing (optional for CI-only runs)

### Publishing Constraints

- **API Key Required**: PowerShell Gallery publishing requires valid API key in secrets
- **Test Pass Requirement**: Publishing jobs only execute if all tests pass
- **Branch Protection**: Recommended to protect main branch and require PR reviews
- **Label Discipline**: Teams MUST follow label conventions for predictable versioning
- **Prerelease Cleanup**: Consider enabling AutoCleanup to remove old prerelease versions
- **Version Conflicts**: Publishing fails if version already exists in PowerShell Gallery
- **Incremental Prereleases**: Each push to prerelease PR increments counter (001, 002, 003...)
- **Branch Name Sanitization**: Prerelease tags use alphanumeric-only branch names

## Quality Standards

### Technical Constraints

- **PowerShell Version**: 7.4 or newer (no backward compatibility with 5.1 or older Core versions)
- **Execution Environment**: GitHub Actions runners (not designed for local development)
- **Code Organization**: Action-based scripts preferred over inline workflow code
- **Action References**: Use PSModule organization actions (github.com/PSModule) with version tags
- **Workflow Structure**: Reusable workflows in `.github/workflows/` using `workflow_call` trigger

### Code Quality

- All PowerShell code MUST pass PSScriptAnalyzer with project-defined rules
- Source code structure MUST follow PSModule framework conventions
- Code coverage target MUST be configurable per repository (default 0% for flexibility)
- All workflow YAML MUST be valid and pass linting
- Action scripts MUST be testable and maintainable
- Inline code in workflows SHOULD be avoided; extract to action scripts
- **Git credential handling**: Workflows MUST use `persist-credentials: false` for checkout actions to prevent credential leakage
- **Repository depth**: Workflows SHOULD use `fetch-depth: 0` for full git history when needed for versioning or changelog generation

### Documentation

- README MUST provide clear setup instructions and workflow usage examples
- All workflows MUST include descriptive comments explaining inputs, outputs, and purpose
- Changes MUST update relevant documentation in the same PR
- GitHub Pages documentation MUST be generated automatically using Material for MkDocs

### Testing

- Source code tests MUST validate framework compliance
- Module tests MUST validate built module integrity
- Local module tests (Pester) MUST validate functional behavior across all platforms
- **Test-ModuleLocal workflow** verifies cross-platform module compatibility on:
  - `ubuntu-latest` (Linux)
  - `windows-latest` (Windows)
  - `macos-latest` (macOS)
- BeforeAll/AfterAll setup and teardown scripts MUST be supported for test environments
- Test matrices MUST be configurable via repository settings
- **CI validation workflows** (`.github/workflows/Workflow-Test-*.yml`) MUST be maintained for integration testing
- **Unified production workflow** (`.github/workflows/workflow.yml`) is the primary consumer-facing workflow
- Consuming repositories SHOULD use CI validation workflows for nightly regression testing

## Development Workflow

### Branching and Pull Requests

- Follow GitHub Flow: feature branches → PR → main
- PR MUST be opened for all changes
- CI workflows MUST execute on PR synchronize, open, reopen, label events
- **PR labels determine release behavior**: `major`, `minor`, `patch`, `prerelease`, `NoRelease`
- **`prerelease` label** enables publishing of prerelease versions from unmerged PRs
- **Merged PRs** trigger normal releases (major/minor/patch based on labels)
- **Unmerged PRs with `prerelease` label** trigger prerelease publishing with incremental tags
- **`NoRelease` label** skips publishing but runs all build and test jobs
- **AutoPatching** (if enabled) applies patch increment when no version label present
- **Prerelease tags** format: `<version>-<branchname><increment>` (e.g., `1.3.0-featureauth001`)
- **Version labels** follow SemVer: `major` (breaking), `minor` (features), `patch` (fixes)
- See "Pull Request Workflow and Publishing Process" section for detailed behavior

### Workflow Execution Order

The standard execution order for Process-PSModule workflows MUST be:
1. **Get-Settings** - Reads configuration and prepares test matrices
2. **Build-Module** - Compiles source into module
3. **Test-SourceCode** - Parallel matrix testing of source code standards
4. **Lint-SourceCode** - Parallel matrix linting of source code
5. **Test-Module** - Framework validation and linting of built module
6. **BeforeAll-ModuleLocal** - Optional: Execute tests/BeforeAll.ps1 setup script once before all test matrix jobs
   - **Runs on ubuntu-latest only** (external resource setup via APIs)
   - Script failures halt workflow execution
   - Skipped if tests/BeforeAll.ps1 does not exist
7. **Test-ModuleLocal** - Runs Pester tests across platform matrix (ubuntu-latest, windows-latest, macos-latest)
   - **Verifies cross-platform module compatibility**
   - Tests module functionality across all supported platforms
   - Depends on BeforeAll-ModuleLocal (waits for external resource setup)
8. **AfterAll-ModuleLocal** - Optional: Execute tests/AfterAll.ps1 teardown script once after all test matrix jobs
   - **Always runs even if tests fail** (via `if: always()` condition)
   - **Runs on ubuntu-latest only** (external resource cleanup via APIs)
   - Script failures logged as warnings but don't halt workflow
   - Skipped if tests/AfterAll.ps1 does not exist
9. **Get-TestResults** - Aggregates and validates test results
10. **Get-CodeCoverage** - Validates coverage thresholds
11. **Build-Docs** and **Build-Site** - Generates documentation
12. **Publish-Module** and **Publish-Site** - Automated publishing on release

**Workflow Types**:

- **Unified Production Workflow** (`.github/workflows/workflow.yml`) - Single workflow handling both CI and CD for consuming repositories
  - Intelligently executes appropriate jobs based on PR state (open/merged/abandoned)
  - Eliminates need for separate CI and release workflows
  - Uses conditional execution to optimize for different scenarios
- **CI Validation Workflows** (`.github/workflows/Workflow-Test-*.yml`) - Integration tests for framework development
- Consuming repositories use the unified production workflow for all scenarios

### Configuration

- Settings MUST be stored in `.github/PSModule.yml` (or JSON/PSD1 format) in consuming repositories
- Skip flags MUST be available for all major workflow steps
- OS-specific skip flags MUST be supported (Linux, macOS, Windows)
- Settings MUST support test configuration, build options, and publish behavior
- **Consuming repositories** configure behavior through settings file (opinionated defaults provided)
- **Structure requirements** documented in GitHub Actions README files MUST be followed by consumers
- Configuration options MUST be backward compatible within major versions

## Governance

### Constitution Authority

This constitution supersedes all other development practices **for Process-PSModule framework development**. When conflicts arise between this document and other guidance, the constitution takes precedence.

**For Consuming Repositories**: This constitution defines how the Process-PSModule framework is built and maintained. Consuming repositories follow the opinionated structure and configuration documented in framework action README files.

### Amendments

Changes to this constitution require:

1. Documentation of the proposed change with clear rationale
2. Review and approval by project maintainers
3. Migration plan for existing code/workflows if applicable
4. Version bump according to impact:
   - MAJOR: Backward incompatible principle removals or redefinitions
   - MINOR: New principles or materially expanded guidance
   - PATCH: Clarifications, wording fixes, non-semantic refinements

### Compliance

- All PRs MUST be validated against constitutional principles **for framework development**
- Workflow design MUST align with Workflow-First Design principle
- Test-First principle compliance is NON-NEGOTIABLE and enforced by review
- **Platform Independence MUST be verified** through Test-ModuleLocal matrix testing (ubuntu-latest, windows-latest, macos-latest)
- **Modules MUST function identically** across all platforms
- Quality Gates MUST be enforced by workflow automation
- PowerShell 7.4+ compatibility MUST be verified
- Action-based implementation preferred over inline workflow code
- CI validation workflow MUST pass before merging changes to core workflows
- **Consuming repositories** MUST follow the Required Module Structure documented in Product Overview

### Runtime Development Guidance

For agent-specific runtime development guidance **when developing the framework**, agents should reference:
- GitHub Copilot: `.github/copilot-instructions.md` (if exists)
- Other agents: Check for `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or `QWEN.md`

**For Consuming Repositories**: Follow the Required Module Structure and Workflow Integration Requirements documented in the Product Overview section. Start with [Template-PSModule](https://github.com/PSModule/Template-PSModule).

**Version**: 1.6.1 | **Ratified**: TODO(RATIFICATION_DATE) | **Last Amended**: 2025-10-03
