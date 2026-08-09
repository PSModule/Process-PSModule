---
title: Dependencies
description: The actions, modules, and services the Process-PSModule workflow composes.
---

# Dependencies

Process-PSModule composes its work from reusable workflows, actions, a container image, PowerShell modules, and Python
packages. Each is versioned independently, and the main workflow pins versions explicitly.

| Dependency | Role |
| --- | --- |
| [PSModule/Build-PSModule](https://github.com/PSModule/Build-PSModule) | Compiles and versions the module. |
| [PSModule/Test-PSModule](https://github.com/PSModule/Test-PSModule) | Runs framework tests and style validation. |
| [PSModule/Invoke-ScriptAnalyzer](https://github.com/PSModule/Invoke-ScriptAnalyzer) | Runs PSScriptAnalyzer linting. |
| [PSModule/Invoke-Pester](https://github.com/PSModule/Invoke-Pester) | Installs Pester and runs module-local tests. |
| [PSModule/Install-PSModuleHelpers](https://github.com/PSModule/Install-PSModuleHelpers) | Installs shared helper commands, including `Import-TestData`. |
| [Pester](https://pester.dev/) | Test framework for module-local tests. |
| [super-linter](https://github.com/super-linter/super-linter) | Lints the repository and generated documentation. |
| [Zensical](https://zensical.org/) | Generates the documentation site. |
| [GitHub Actions](https://github.com/features/actions) | Workflow engine. |
| PowerShell Gallery API | Publishes module packages. |
| GitHub Pages | Hosts the documentation site. |

For the full dependency tree, including diagrams and a reference of every transitive dependency, see
[DEPENDENCIES.md](https://github.com/PSModule/Process-PSModule/blob/main/DEPENDENCIES.md).
