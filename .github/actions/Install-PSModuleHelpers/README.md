# Install-PSModuleHelpers

A GitHub Action to install and configure the PSModule helper modules for use in continuous integration and delivery (CI/CD) workflows. This action is
a critical component for setting up a standardized PowerShell environment across repositories using the PSModule framework.

This GitHub Action is a part of the [PSModule framework](https://github.com/PSModule). It is recommended to use the
[Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate the whole process of managing the PowerShell module.

## What this action does

- Removes any existing instances of the `Helpers` module from the PowerShell session.
- Copies the latest version of the `Helpers` module into the PowerShell module directory.
- Imports the `Helpers` module, ensuring it is available for subsequent steps.

This action helps maintain consistency and reliability across workflows that depend on the PSModule framework.

## Usage

```yaml
- name: Install PSModule Helpers
  uses: PSModule/Install-PSModuleHelpers@v1
```

## Inputs

_No inputs required._

## Secrets

_No secrets required._

## Outputs

This action does not provide any outputs.

## Example

Here's a complete workflow example demonstrating how to use the Install-PSModuleHelpers action:

```yaml
name: CI

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install PSModule Helpers
        uses: PSModule/Install-PSModuleHelpers@v1

      - name: Run additional steps
        shell: pwsh
        run: |
          # Example usage of imported Helpers module
          Get-Command -Module Helpers
```
