# Release-PSModule

Creates or resumes a GitHub release for a pre-versioned PowerShell module artifact. The action attaches the exact built module ZIP to the release and reports the result on the source pull request.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `Name` | Name of the module to release. | No | Repository name |
| `ModulePath` | Path containing the built `<Name>/` module directory. | No | `.PSModule/module` |
| `ArtifactName` | Name of the module artifact to download. | No | `module` |
| `ReleaseTag` | Full GitHub release tag resolved by `Resolve-PSModuleVersion`. | Yes | N/A |
| `CommitSha` | Original immutable source commit; used to verify ownership on a retry. | No | Original `GITHUB_SHA` context for retry verification |
| `PullRequest` | Normalized source PR context; direct releases also remain supported. | No | Event-payload fallback |
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
    CommitSha: ${{ fromJson(inputs.Settings).Context.CommitSha }}
```

The action consumes a built module artifact and normalized PR or direct-release context. An existing tag is resolved
to its actual commit, including annotated tags; `target_commitish` is not treated as immutable proof. A retry proceeds
only when that commit matches the original source.

Tag ownership is checked even when no GitHub release exists: a missing release is not evidence that the tag is
unclaimed. The source is checked again immediately before asset upload to reject concurrent tag changes.

Prerelease creation and retry both use the original build commit, not a mutable PR head branch. The complete authored
notes or generated notes are preserved, followed by a versioned controller-owned footer recording the base repository,
source PR number, and immutable commit. This publication provenance lets cleanup retain unambiguous PR ownership
without deriving it from a tag substring.

## Retrying publication

Use the original run's resolved tag, source, and artifact. A missing ZIP can be uploaded to the same-source release.
An existing ZIP is retained only when its published SHA-256 digest matches the local bytes. Different or unverifiable
published contents are rejected explicitly; the action never uses `--clobber`.

If a tag belongs to another commit, or an artifact differs, stop and reconcile the conflict through reviewed
forward-only work. Do not retag, replace an existing version's asset, or retry a newly computed bump as if it were the
original publication. `WhatIf` reports commands without creating, replacing, or deleting release state.
