---
title: Your first release
description: The pull request flow, version labels, and the default-branch push that creates a stable Process-PSModule release.
---

# Your first release

Process-PSModule uses pull requests for review and release metadata, and an important push to the default branch as
the authority for stable publication. There is no manual publish step, no version file to edit, and no tag to push by
hand.

## The flow

1. Clone the repository, create a branch, and make your changes.
2. Push the branch and open a pull request against `main`.
3. The workflow builds the module, runs tests on Windows, Linux, and macOS, lints the repository, and reports back on
   the pull request.
4. Apply one configured bump label when it must override `Publish.Module.DefaultBump` (see below). Without one, the
   effective default supplies `patch`, `minor`, or `major`; an omitted setting uses `patch`.
5. Merge the pull request. Its resulting important push to `main` runs the stable release: after the pipeline passes,
   it publishes the module to the PowerShell Gallery, creates a GitHub Release and tag for the tested commit, and
   deploys the documentation site unless site publication is configured to skip. The closed-pull-request event only
   cleans up prereleases.

An important direct push to the default branch also uses the effective default, with commit-based notes when no
release PR is associated. A recovery dispatch at a merged PR's merge commit retains that PR's labels and metadata.
Ambiguous merged associations stop the run rather than assuming a different bump.

## Version labels

| Label | Effect |
| --- | --- |
| `release:major` | Bump `MAJOR`. |
| `release:minor` | Bump `MINOR`. |
| `release:patch` | Override the default and bump `PATCH`. |
| `release:prerelease` | Publish the resolved bump as a prerelease before the pull request merges. |
| `release:skip` | Run the pipeline but skip publication. |

Conflicting labels (for example `release:major` together with `release:skip`) are rejected whenever that run resolves a
release. A prerelease conflict fails the pull-request check; a stable conflict fails the resulting release run. These
are the defaults; every label mapping remains configurable — see [Settings](../reference/settings.md).

For the full model, including prerelease promotion and what a release produces, see
[Versioning and releases](../guides/versioning-and-releases.md).

## Testing before you merge

Add the configured prerelease label (`release:prerelease` by default) to publish a prerelease from the open pull
request. It uses one explicit bump label or the effective `DefaultBump`. The prerelease is installable from the
PowerShell Gallery but is not promoted as the latest stable version, so it can be validated before the pull request is
merged. When the pull request is closed without merging, the prerelease versions and tags created for it are cleaned up
automatically.

## When nothing is released

If a pull request or default-branch push only touches files outside the configured important-file patterns —
documentation, CI tweaks, comment typos — the build, test, and publish stages are skipped and no release is created.
A pull-request comment explains why for pull-request runs. See
[important-file change detection](../guides/calling-the-workflow.md#important-file-change-detection) to change which
paths trigger a release.

## What runs when

Not every job runs for every trigger. See the [scenario matrix](../reference/scenario-matrix.md) for the full table.
