---
title: Structuring your module
description: The repository and module source layout Process-PSModule expects, what goes where, and how to declare module dependencies with #Requires -Modules.
---

# Structuring your module

Process-PSModule expects repositories to follow the staged layout produced by Template-PSModule. The workflow inspects this structure to decide what to compile, document, and publish.

The goal is a stable repository anatomy so both humans and automation know exactly where to place and find module concerns.

## What goes where

| Concern | Location |
| --- | --- |
| Public command surface — the module API | `src/functions/public/<Group>/` |
| Private implementation — not exported | `src/functions/private/<Group>/` |
| Public and private classes | `src/classes/` |
| Formatting definitions | `src/formats/` |
| Type extensions | `src/types/` |
| Import-time setup | `src/init/` |
| Scoped variables | `src/variables/private/` and `src/variables/public/` |
| Behavior tests | `tests/` |
| Representative usage | `examples/` |

## Repository layout

```plaintext
<ModuleName>/
├── .claude/
│   └── CLAUDE.md                               # Claude Code route to AGENTS.md
├── .github/                                   # Workflow config, doc/site templates, automation policy
│   ├── linters/                               # Rule sets applied by shared lint steps
│   │   ├── .markdown-lint.yml                 # Markdown rules enforced via super-linter
│   │   ├── .powershell-psscriptanalyzer.psd1  # Analyzer profile for test jobs
│   │   └── .textlintrc                        # Text lint rules surfaced in Build Docs summaries
│   ├── workflows/                             # Entry points for the reusable workflow
│   │   └── Process-PSModule.yml               # Consumer hook into this workflow bundle
│   ├── CODE_OF_CONDUCT.md                      # Community participation rules
│   ├── CODEOWNERS                             # Default reviewers enforced by Process-PSModule checks
│   ├── CONTRIBUTING.md                         # Repository-local contribution workflow
│   ├── copilot-instructions.md                 # Copilot route to AGENTS.md
│   ├── dependabot.yml                         # Dependency update cadence handled by GitHub
│   ├── PSModule.yml                           # Settings parsed to drive matrices
│   ├── release.yml                            # Release automation template invoked on publish
│   ├── SECURITY.md                             # Private vulnerability reporting policy
│   ├── SUPPORT.md                              # Support channels and issue routing
│   └── zensical.toml                           # Site config consumed during site builds
├── examples/                                  # Samples referenced in generated documentation
│   └── General.ps1                            # Example script ingested by Document-PSModule
├── icon/                                      # Icon assets linked from manifest and documentation
│   └── icon.png                               # Default module icon (PNG format)
├── src/                                       # Module source, see "Module source code structure" below
├── tests/                                     # Pester suites; the Simple layout is shown
│   ├── AfterAll.ps1 (optional)                # Cleanup script for ModuleLocal runs
│   ├── BeforeAll.ps1 (optional)               # Setup script for ModuleLocal runs
│   └── <ModuleName>.Tests.ps1                 # Simple: one root-level module suite
├── .gitattributes                             # Normalizes line endings across platforms
├── .gitignore                                 # Excludes build artifacts from source control
├── AGENTS.md                                  # Cross-client agent guidance router
├── LICENSE                                    # License text surfaced in manifest metadata
└── README.md                                  # Repository overview rendered on GitHub and docs landing
```

The tree shows the [Simple PowerShell test profile](https://msx.no/docs/Coding-Standards/PowerShell/Testing/#simple), not an exclusive test-file shape. Standard keeps one root-level `tests/<Group>.Tests.ps1` file per public function group. Advanced uses recursively discovered subdirectories, and layouts may mix across directories. Process-PSModule defines the exact [per-directory precedence and sibling suppression](writing-module-tests.md#test-discovery).

These names describe repository conventions, not settings. `.github/PSModule.yml` does not select a test profile. The optional `tests/BeforeAll.ps1` and `tests/AfterAll.ps1` files are root-only workflow phases and are not discovered recursively.

Key expectations:

- Keep at least one exported function under `src/functions/public/` and corresponding tests in `tests/` using a [documented test profile](https://msx.no/docs/Coding-Standards/PowerShell/Testing/#module-test-profiles).
- Keep documentation site configuration aligned with
  `Template-PSModule/.github/zensical.toml`. Omit `nav`; Zensical follows the
  generated folder structure and sorts pages alphabetically.
- Optional folders (`assemblies`, `formats`, `types`, `variables`, and others) are processed automatically when present.
- Markdown files in `src/functions/public` subfolders become documentation pages alongside generated help.
- A group's overview page (`<Category>/<Category>.md` named after the folder, or `<Category>/index.md`) becomes that group's section landing page in the docs navigation.
- The build step compiles `src/` into a root module file and removes the original project layout from the artifact.
- Documentation generation mirrors the `src/functions/public` hierarchy so help content always aligns with source.

## Module source code structure

How the module is built.

```plaintext
├── src/                                    # Module source compiled and documented by the pipeline
│   ├── assemblies/                         # Bundled binaries copied into the build artifact
│   ├── classes/                            # Class scripts merged into the root module
│   │   ├── private/                        # Internal classes kept out of exports
│   │   │   └── SecretWriter.ps1            # Example internal class implementation
│   │   └── public/                         # Public classes exported via type accelerators
│   │       └── Book.ps1                    # Example public class documented for consumers
│   ├── data/                               # Configuration loaded into `$script:` scope at runtime
│   │   ├── Config.psd1                     # Example config surfaced in generated help
│   │   └── Settings.psd1                   # Additional configuration consumed on import
│   ├── formats/                            # Formatting metadata registered during build
│   │   ├── CultureInfo.Format.ps1xml       # Example format included in manifest
│   │   └── Mygciview.Format.ps1xml         # Additional format loaded at import
│   ├── functions/                          # Function scripts exported by the module
│   │   ├── private/                        # Helper functions scoped to the module
│   │   │   ├── Get-InternalPSModule.ps1    # Sample internal helper
│   │   │   └── Set-InternalPSModule.ps1    # Sample internal helper
│   │   └── public/                         # Public commands documented and tested
│   │       ├── Category/                   # Optional: organize commands into categories
│   │       │   ├── Get-CategoryCommand.ps1 # Command file within category
│   │       │   └── Category.md             # Group overview -> section landing page (or index.md)
│   │       ├── Get-PSModuleTest.ps1        # Example command captured by Microsoft.PowerShell.PlatyPS
│   │       ├── New-PSModuleTest.ps1        # Example command exported and tested
│   │       ├── Set-PSModuleTest.ps1        # Example command exported and tested
│   │       └── Test-PSModuleTest.ps1       # Example command exported and tested
│   ├── init/                               # Initialization scripts executed during module load
│   │   └── initializer.ps1                 # Example init script included in build output
│   ├── modules/                            # Nested modules packaged with the compiled output
│   │   └── OtherPSModule.psm1              # Example nested module staged for export
│   ├── scripts/                            # Scripts listed in 'ScriptsToProcess'
│   │   └── loader.ps1                      # Loader executed when the module imports
│   ├── types/                              # Type data merged into the manifest
│   │   ├── DirectoryInfo.Types.ps1xml      # Type definition registered on import
│   │   └── FileInfo.Types.ps1xml           # Type definition registered on import
│   ├── variables/                          # Variable scripts exported by the module
│   │   ├── private/                        # Internal variables scoped to the module
│   │   │   └── PrivateVariables.ps1        # Example private variable seed
│   │   └── public/                         # Public variables exported and documented
│   │       ├── Moons.ps1                   # Example variable surfaced in generated docs
│   │       ├── Planets.ps1                 # Example variable surfaced in generated docs
│   │       └── SolarSystems.ps1            # Example variable surfaced in generated docs
│   ├── finally.ps1                         # Cleanup script appended to the root module
│   ├── header.ps1                          # Optional header injected at the top of the module
│   ├── manifest.psd1 (optional)            # Source manifest reused when present
│   └── README.md                           # Module-level docs ingested by Document-PSModule
```

### Declaring module dependencies

Declare module dependencies using
[`#Requires -Modules`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires)
statements at the top of function files in `src/functions/public/` or `src/functions/private/` that genuinely require external modules. For modules we build, the default is to avoid third-party module, DLL, and package dependencies when PowerShell, the .NET base class library, or code we own can carry the feature with reasonable effort.
[Build-PSModule](https://github.com/PSModule/Build-PSModule) collects every `#Requires -Modules` declaration across all
source files, de-duplicates the list, and writes it into the `RequiredModules` field of the compiled manifest
automatically. For the full range of supported syntax variants, see the
[about_Requires](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires)
documentation.

> **Important:** Adding `RequiredModules` to `src/manifest.psd1` is **not** supported for this purpose. Those entries are silently ignored by the build and will not appear in the compiled manifest. Use `#Requires -Modules` in function files instead.
