# Release-PSModule

Creates or resumes a GitHub release for a pre-versioned, tested PowerShell module artifact. The action verifies the same immutable source/context/artifact claim as the Gallery publisher, attaches repeatable module ZIP bytes, and reports the result on the producing pull request when available.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `Name` | Name of the module to release. | No | Repository name |
| `ModulePath` | Path containing the built `<Name>/` module directory. | No | `.PSModule/module` |
| `ArtifactName` | Name of the module artifact to download. | No | `module` |
| `ReleaseTag` | Full GitHub release tag resolved by `Resolve-PSModuleVersion`. | Yes | N/A |
| `VersionPrefix` | Existing configured resolver prefix; verifies tag/artifact version binding. | No | `v` |
| `CommitSha` | Original immutable build source for stable and prerelease tags. | No | Original workflow `GITHUB_SHA` |
| `PullRequest` | Normalized producing-PR context; empty for a direct stable release. | No | Empty |
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
    ModulePath: .PSModule/module
    ArtifactName: module
    ReleaseTag: ${{ fromJson(inputs.Settings).Publish.Module.Resolution.FullVersion }}
    VersionPrefix: ${{ fromJson(inputs.Settings).Publish.Module.VersionPrefix }}
    CommitSha: ${{ fromJson(inputs.Settings).Context.CommitSha }}
    PullRequest: ${{ toJson(fromJson(inputs.Settings).Context.PullRequest) }}
```

The action supports normalized pull-request context and direct stable releases. Provide repository-scoped contents-write `GH_TOKEN` access and the original tested artifact/source. Tags resolve to actual commits, including annotated tags; mutable branch names and release target hints are not ownership proof.

Release creation and upload recheck the release tag, shared module/version coordinate, provenance, and artifact identity. Both refs must bind the same immutable claim, regardless of tag prefix. A missing upload can resume. An existing asset is retained only when its published SHA-256 matches the exact local ZIP; differing, ambiguous, or unverifiable bytes stop the action. Uploads never use `--clobber`, and tags are never retargeted.

The local ZIP's exact bytes and payload digest are verified together against the tested file tree before claiming, creating, or uploading. Original event PR context and versioned provenance must have valid object/scalar shapes before normalization; arrays cannot supply publication ownership.

Complete authored or generated prerelease notes precede a final repository/producing-PR/source footer. A matching tag/source does not authorize another PR's release. Legacy records without proof require reviewed forward-only recovery; the action does not fabricate provenance or alter consumer metadata.
