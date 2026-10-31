# Publish-PSModule

Publishes a pre-versioned, tested PowerShell module artifact to the PowerShell Gallery after source-bound ownership preflight. GitHub Release creation is handled by the separate [Release-PSModule](../Release-PSModule/README.md) action.

The publisher verifies the original source, exact resolved tag/version, producing repository/PR or direct-release context, and tested bytes before an external versioned-artifact mutation. An absent Gallery module/version is reserved at `PSModule-Publication/<lowercase-module>/<lowercase-version>`, independently of the configured release-tag prefix. The shared coordinate and release tag reference the same immutable annotated source/context/file-tree/ZIP claim. Existing tags are never updated or deleted; the package ownership coordinate is retained for immutable Gallery proof.

An observed release tag must remain unchanged through shared coordinate creation. If it disappears or is replaced during that reservation, the attempt fails instead of recreating it. A valid partial shared claim can still create an absent release tag that has never been observed in the attempt.

An existing Gallery package is retained only when its raw nupkg payload matches that proof and the tested artifact. Package code is never imported to establish ownership. Unknown legacy proof, foreign tags/releases/assets, changed claims, authentication errors, and API failures stop publication explicitly.

Provenance must contain one original JSON object with scalar proof fields; arrays are not projected into valid identities. The ZIP's exact bytes and canonical payload digest are verified together against the tested file tree before a claim or Gallery write. Original event PR context is validated before normalized fields are selected.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `Name` | Name of the module to publish. | No | Repository name |
| `ModulePath` | Path containing the built `<Name>/` module directory. | No | `.PSModule/module` |
| `ArtifactName` | Name of the module artifact to download. | No | `module` |
| `PSGALLERY_API_KEY` | PowerShell Gallery API key. | Yes | N/A |
| `ReleaseTag` | Exact tag already resolved as `Publish.Module.Resolution.FullVersion`. | Yes | N/A |
| `VersionPrefix` | Existing resolver prefix used to bind `ReleaseTag` to the tested module version. | No | `v` |
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
    VersionPrefix: ${{ fromJson(inputs.Settings).Publish.Module.VersionPrefix }}
    CommitSha: ${{ fromJson(inputs.Settings).Context.CommitSha }}
    PullRequest: ${{ toJson(fromJson(inputs.Settings).Context.PullRequest) }}
```

Provide `GH_TOKEN` with contents-write access scoped to the consumer repository. The reusable workflow supplies its existing GitHub App token and resolved context internally.

NuGet-reserved container metadata paths are rejected in the tested candidate before a claim or upload, using the same path classification as raw package verification. A published package without its shared module/version coordinate is unproven; the publisher does not fabricate that ownership record on retry.

Use [Release-PSModule](../Release-PSModule/README.md) in a separate step to create the GitHub release from the same source and tested artifact. A retry must retain the original coordinates and bytes; unproven legacy publication requires reviewed forward-only recovery, not numeric guessing, retagging, or metadata changes.
