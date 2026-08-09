# Publish-PSModule

Publishes a pre-versioned PowerShell module artifact to the PowerShell Gallery. GitHub Release creation is intentionally handled by the separate [Release-PSModule](../Release-PSModule/README.md) action.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `Name` | Name of the module to publish. | No | Repository name |
| `ModulePath` | Path containing the built `<Name>/` module directory. | No | `outputs/module` |
| `ArtifactName` | Name of the module artifact to download. | No | `module` |
| `APIKey` | PowerShell Gallery API key. | Yes | N/A |
| `WhatIf` | Logs publishing operations without publishing the module. | No | `false` |
| `WorkingDirectory` | Directory where the publishing script runs. | No | `.` |

## Outputs

This action does not provide outputs.

## Usage

```yaml
- name: Publish module
  uses: ./.github/actions/Publish-PSModule
  with:
    Name: ExampleModule
    ModulePath: outputs/module
    ArtifactName: module
    APIKey: ${{ secrets.PSGALLERY_API_KEY }}
```

Use [Release-PSModule](../Release-PSModule/README.md) in a separate workflow step to create the GitHub release from the same artifact.
