# Release-PSModule

Creates or resumes a GitHub release for a pre-versioned PowerShell module artifact. The action attaches the exact built module ZIP to the release and reports the result on the source pull request.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `Name` | Name of the module to release. | No | Repository name |
| `ModulePath` | Path containing the built `<Name>/` module directory. | No | `outputs/module` |
| `ArtifactName` | Name of the module artifact to download. | No | `module` |
| `ReleaseTag` | Full GitHub release tag resolved by `Resolve-PSModuleVersion`. | Yes | N/A |
| `WhatIf` | Logs release operations without creating or uploading anything. | No | `false` |
| `WorkingDirectory` | Directory where the release script runs. | No | `.` |
| `UsePRTitleAsReleaseName` | Uses the pull request title as the release name. | No | `false` |
| `UsePRBodyAsReleaseNotes` | Uses the pull request body as release notes. | No | `true` |
| `UsePRTitleAsNotesHeading` | Adds the pull request title as an H1 release-notes heading. | No | `true` |

## Outputs

| Name | Description |
| --- | --- |
| `ReleaseTag` | Full GitHub release tag created or resumed by the action. |
| `ReleaseUrl` | URL of the GitHub release created or resumed by the action. |

## Usage

Pass the Plan job's resolved `FullVersion` as `ReleaseTag` so the configured tag prefix is preserved.

```yaml
- name: Create GitHub release
  id: create-github-release
  uses: ./.github/actions/Release-PSModule
  with:
    Name: ExampleModule
    ModulePath: outputs/module
    ArtifactName: module
    ReleaseTag: ${{ fromJson(inputs.Settings).Publish.Module.Resolution.FullVersion }}
```

The action requires a `pull_request` event and a built module artifact. If a release already exists for `ReleaseTag`, it resumes by replacing the module ZIP, which makes retrying a partial release safe.
