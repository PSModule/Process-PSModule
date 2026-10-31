# Publish-PSModule

Publishes a pre-versioned, tested PowerShell module artifact to the PowerShell Gallery after source-bound ownership preflight. GitHub Release creation is handled by the separate [Release-PSModule](../Release-PSModule/README.md) action.

The publisher verifies the original source, exact resolved tag/version, producing repository/PR or direct-release context, and tested bytes before an external versioned-artifact mutation. An absent version is reserved with a create-only annotated tag containing the file-tree and ZIP SHA-256 proof. Existing tags are never updated or deleted.

An existing Gallery package is retained only when its raw nupkg payload matches that proof and the tested artifact. Package code is never imported to establish ownership. Unknown legacy proof, foreign tags/releases/assets, changed claims, authentication errors, and API failures stop publication explicitly.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `Name` | Name of the module to publish. | No | Repository name |
| `ModulePath` | Path containing the built `<Name>/` module directory. | No | `.PSModule/module` |
| `ArtifactName` | Name of the module artifact to download. | No | `module` |
| `PSGALLERY_API_KEY` | PowerShell Gallery API key. | Yes | N/A |
| `ReleaseTag` | Exact tag already resolved as `Publish.Module.Resolution.FullVersion`. | Yes | N/A |
| `CommitSha` | Immutable commit that produced the tested artifact. | No | Original workflow `GITHUB_SHA` |
| `PullRequest` | Normalized producing-PR context; empty for a direct stable release. | No | Empty |
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
    ModulePath: .PSModule/module
    ArtifactName: module
    PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
    ReleaseTag: ${{ fromJson(inputs.Settings).Publish.Module.Resolution.FullVersion }}
    CommitSha: ${{ fromJson(inputs.Settings).Context.CommitSha }}
    PullRequest: ${{ toJson(fromJson(inputs.Settings).Context.PullRequest) }}
```

Provide `GH_TOKEN` with contents-write access scoped to the consumer repository. The reusable workflow supplies its existing GitHub App token and resolved context internally.

Use [Release-PSModule](../Release-PSModule/README.md) in a separate step to create the GitHub release from the same source and tested artifact. A retry must retain the original coordinates and bytes; unproven legacy publication requires reviewed forward-only recovery, not numeric guessing, retagging, or metadata changes.
