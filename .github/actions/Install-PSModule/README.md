# Install-PSModule

This GitHub Action prepares the PowerShell environment for continuous integration and delivery (CI/CD) workflows.

The [PSModule framework](https://github.com/PSModule) includes this action.
For the recommended setup, use the [Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate PowerShell module management.

## What this action does

- Removes any existing instances of the `Helpers` module from the PowerShell session.
- Copies the latest version of the `Helpers` module into the PowerShell module directory.
- Imports the `Helpers` module, ensuring it is available for subsequent steps.

## Usage

```yaml
- name: Install PSModule Helpers
  uses: PSModule/Install-PSModule@v1
```

## Inputs

_No inputs required._

## Secrets

_No secrets required._

## Outputs

The action defines no outputs.

## Example

This example shows the action in a workflow:

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
        uses: PSModule/Install-PSModule@v1

      - name: Run additional steps
        shell: pwsh
        run: |
          # Example usage of imported Helpers module
          Get-Command -Module Helpers
```
