---
title: Versioning and releases
description: How Process-PSModule resolves a version from pull-request labels, publishes stable releases from default-branch pushes, and cleans up prereleases.
---

# Versioning and releases

Process-PSModule orchestrates the module lifecycle through GitHub Actions. Version progression is label-driven in pull
requests and resolved once, in the Plan stage, before anything is built. Stable publication occurs only from a push to
the configured default branch.

## Flow

1. Resolve settings and release intent.
2. Build the module artifact from `src/`, stamping the resolved version into the manifest.
3. Run tests and quality checks.
4. Package docs and site artifacts when enabled.
5. Publish the module and release metadata when release conditions are met.

Test and lint stages run before the publish gates, and publish is blocked when required checks fail.

An open labelled pull request can publish a prerelease. A closed pull request only cleans up its prereleases. When a
pull request merges, the resulting push to the default branch resolves that pull request's labels and creates the
stable release from the exact pushed commit.

## Version labels

The bump comes from the pull-request label; the next version is computed as `current version + bump`.

| Label | Effect |
| --- | --- |
| `major` / `breaking` | Breaking change; bump `MAJOR`. |
| `minor` / `feature` | New feature; bump `MINOR`. |
| `patch` / `fix` | Bugfix; bump `PATCH`. |
| `Prerelease` | Publish as a prerelease; not promoted to latest. |
| `NoRelease` | Run the pipeline, skip publication. |

Multiple or conflicting version labels (for example `major` together with `NoRelease`) are rejected and block the merge.
With `AutoPatching: true`, an unlabeled pull request defaults to `Patch`; otherwise it needs an explicit version label.
Direct pushes and manual dispatches on the default branch always use `Patch`, regardless of `AutoPatching`.

The label names are configurable through `Publish.Module.MajorLabels`, `MinorLabels`, `PatchLabels`, and
`IgnoreLabels` — see [Settings](../reference/settings.md).

## Branch types

- **Main (stable)** — the default branch and the only branch that publishes stable releases.
- **Feature branch** — a short-lived topic branch with a pull request targeting `main`.

Exactly one branch is authorized to publish stable releases, so consumers always have one
unambiguous latest version. Use a
[stacked pull request](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/#stacked-pull-requests)
when changes genuinely depend on each other; independent changes remain separate
short-lived pull requests targeting `main`.

## Prereleases

A pull request labelled `Prerelease` publishes a prerelease version (for example `v1.2.3-pr.1.5`) that is installable
but not promoted as latest. When that pull request is merged with a version label, the stable version is computed from
the label and the current version on `main`.

When a pull request closes, the prerelease versions and tags created for it are removed, so abandoned or promoted work
leaves no orphaned prereleases. This is controlled by `Publish.Module.AutoCleanup`.

## What a release produces

Each publication produces three linked, immutable artifacts:

- a version on the PowerShell Gallery, published exactly as built with no version mutation,
- a GitHub Release, with the built module attached as a `.zip` asset,
- a git tag.

Release names and notes can be generated from the pull request — see
[Configuring the pipeline](configuring-the-pipeline.md).

## Linear versioning

Only a single linear ancestry of versions is maintained. Old versions are not patched: if a security issue is found on
`2.1.3`, the fix ships on the latest version, not as a new `1.x` release. See
[Principles and practices](../specification/principles-and-practices.md) for the reasoning.

## Related

- [Your first release](../get-started/your-first-release.md) — the pull request flow end-to-end.
- [Pipeline stages](../reference/pipeline-stages.md#publish-module) — what the publish job does.
- [Versioning](../reference/versioning.md) — the PSModule versioning policy.
