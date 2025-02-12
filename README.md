# PSModule CI/CD Workflow

## Overview

The **Process-PSModule** workflow is a comprehensive GitHub reusable workflow that automates the **CI/CD pipeline** for PowerShell modules. It integrates the entire module lifecycle, from initialization to publication, ensuring best practices, compatibility, and compliance with industry standards.

## Features

This workflow seamlessly stitches together the following actions:

- **[Initialize-PSModule](https://github.com/PSModule/Initialize-PSModule)**: Prepares the GitHub Actions runner with required dependencies.
- **[Build-PSModule](https://github.com/PSModule/Build-PSModule)**: Compiles the source code into a production-ready PowerShell module.
- **[Test-PSModule](https://github.com/PSModule/Test-PSModule)**: Executes Pester and PSScriptAnalyzer tests to validate the module.
- **[Publish-PSModule](https://github.com/PSModule/Publish-PSModule)**: Publishes the module to the PowerShell Gallery, generates documentation, and creates GitHub releases.

## How It Works

The workflow triggers automatically on pull requests to the repository's default branch, responding to events such as opening, closing, synchronization, and labeling. Based on the assigned labels, it determines the appropriate workflow actions to execute.

### Key Practices Followed
- **Test-Driven Development** using [Pester](https://pester.dev) and [PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules)
- **GitHub Flow** for streamlined branching and merging
- **Semantic Versioning (SemVer 2.0.0)** to manage module versions systematically
- **Continuous Delivery (CD)** principles for automated deployments

## Usage

To use this workflow in your PowerShell module repository, create a new GitHub Actions workflow file under `.github/workflows`:

```yaml
name: Process-PSModule

on:
  pull_request:
    branches:
      - main
    types:
      - closed
      - opened
      - reopened
      - synchronize
      - labeled

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v2
    secrets: inherit
```

## Documentation

For a detailed guide on how to configure and use the **Process-PSModule** workflow, please review the [documentation](https://PSModule.io/Process-PSModule).
