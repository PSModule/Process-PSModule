---
title: Your first release
description: The pull request flow, version labels, and what happens when a Process-PSModule pull request is merged.
---

# Your first release

Process-PSModule is driven entirely by pull requests. There is no manual publish step, no version file to edit, and no
tag to push by hand.

## The flow

1. Clone the repository, create a branch, and make your changes.
2. Push the branch and open a pull request against `main`.
3. The workflow builds the module, runs tests on Windows, Linux, and macOS, lints the repository, and reports back on
   the pull request.
4. Apply a version label to declare release intent (see below). Without a label, the change releases as a **patch**.
5. Merge the pull request. The workflow publishes the module to the PowerShell Gallery, creates a GitHub Release and
   tag, and deploys the documentation site to GitHub Pages.

## Version labels

| Label | Effect |
| --- | --- |
| `major` / `breaking` | Bump `MAJOR`. |
| `minor` / `feature` | Bump `MINOR`. |
| `patch` / `fix` | Bump `PATCH`. This is the default when no label is applied. |
| `Prerelease` | Publish a prerelease version from the pull request, before it is merged. |
| `NoRelease` | Run the pipeline but skip publication. |

Conflicting labels (for example `major` together with `NoRelease`) are rejected and block the merge. The label names are
configurable — see [Settings](../reference/settings.md).

For the full model, including prerelease promotion and what a release produces, see
[Versioning and releases](../guides/versioning-and-releases.md).

## Testing before you merge

Add the `Prerelease` label to publish a prerelease version from the open pull request. The prerelease is installable
from the PowerShell Gallery but is not promoted as the latest stable version, so it can be validated before the pull
request is merged. When the pull request is closed without merging, the prerelease versions and tags created for it are
cleaned up automatically.

## When nothing is released

If a pull request only touches files outside the configured important-file patterns — documentation, CI tweaks, comment
typos — the build, test, and publish stages are skipped and no release is created. A comment on the pull request
explains why. See
[important-file change detection](../guides/calling-the-workflow.md#important-file-change-detection) to change which
paths trigger a release.

## What runs when

Not every job runs for every trigger. See the [scenario matrix](../reference/scenario-matrix.md) for the full table.
