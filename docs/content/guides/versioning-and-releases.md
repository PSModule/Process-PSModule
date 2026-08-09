---
title: Versioning and releases
description: How Process-PSModule resolves a version from pull-request labels, what a release produces, and how prereleases are published and cleaned up.
---

# Versioning and releases

Process-PSModule orchestrates the module lifecycle through GitHub Actions. Version progression is label-driven in pull
requests and resolved once, in the Plan stage, before anything is built.

## Flow

1. Resolve settings and release intent.
2. Build the module artifact from `src/`, stamping the resolved version into the manifest.
3. Run tests and quality checks.
4. Package docs and site artifacts when enabled.
5. Publish the module and release metadata when release conditions are met.

Test and lint stages run before the publish gates, and publish is blocked when required checks fail.

## Version labels

The bump comes from the pull-request label; the next version is computed as `current version + bump`.

| Label | Effect |
| --- | --- |
| `major` / `breaking` | Breaking change; bump `MAJOR`. |
| `minor` / `feature` | New feature; bump `MINOR`. |
| `patch` / `fix` | Bugfix; bump `PATCH`. Applied by default when no label is present. |
| `Prerelease` | Publish as a prerelease; not promoted to latest. |
| `NoRelease` | Run the pipeline, skip publication. |

Multiple or conflicting version labels (for example `major` together with `NoRelease`) are rejected and block the merge.

The label names are configurable through `Publish.Module.MajorLabels`, `MinorLabels`, `PatchLabels`, and
`IgnoreLabels` — see [Settings](../reference/settings.md).

## Branch types

- **Main (stable)** — publishes stable releases. A prerelease label publishes a prerelease from `main`.
- **Development** — optional prerelease branch (for example `dev`). Each push publishes a prerelease.
- **Feature branch** — optional feature branch. A prerelease label publishes a prerelease for testing.

Exactly one branch is authorized to publish stable releases, so consumers always have one unambiguous latest version.

## Release branch pattern

For a larger release made up of several independent features, use a release branch to
collect the changes before promoting them to `main`. This is different from a
[stacked pull request](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/#stacked-pull-requests),
where each layer depends on the preceding layer.

Before creating the release branch, make sure the module repository's caller workflow
triggers on it as well as `main`. The standard example filters pull requests to `main`:

```yaml
on:
  pull_request:
    branches:
      - main
      - 'release/**'
```

Then:

1. Cut a release branch such as `release/v1` from `main`.
2. Open a draft release pull request from the release branch to `main`.
3. Cut each independent feature branch from the release branch and open its pull request
   against the release branch.
4. Merge feature pull requests into the release branch as they become ready. Use a
   [stack](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/#stacked-pull-requests)
   only when two features genuinely depend on each other.
5. When the release branch is complete and all checks pass, mark the release pull request
   ready and merge it into `main`.

Pull requests targeting the release branch can publish preview versions when they carry
the `Prerelease` label. Only the final merge into the repository's default branch can
produce the stable release, because the workflow authorizes stable publication only when
the merged pull request targets that branch.

Each feature pull request follows the
[MSX PR Format](https://msx.no/docs/Ways-of-Working/PR-Format/) and closes its own
scoped issue. The release pull request should summarize the combined user-facing
release and link the included feature pull requests; it must not replace their
issue-closing references with a second aggregate closure.

## Prereleases

A pull request labelled `Prerelease` publishes a prerelease version (for example `v1.2.3-pr.1.5`) that is installable
but not promoted as latest. When that pull request is merged with a version label, the stable version is computed from
the label and the current version on the release branch.

When a pull request is closed without merging, the prerelease versions and tags created for it are removed, so
abandoned work leaves no orphaned prereleases. This is controlled by `Publish.Module.AutoCleanup`.

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
[Principles and practices](../specification/principles-and-practices.md) for the reasoning and for the release-branch
pattern used for larger efforts.

## Related

- [Your first release](../get-started/your-first-release.md) — the pull request flow end-to-end.
- [Pipeline stages](../reference/pipeline-stages.md#publish-module) — what the publish job does.
- [Versioning](../reference/versioning.md) — the PSModule versioning policy.
