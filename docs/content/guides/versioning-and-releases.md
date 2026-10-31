---
title: Versioning and releases
description: How Process-PSModule resolves configured defaults and labels, publishes default-branch releases, and safely recovers publication.
---

# Versioning and releases

Process-PSModule orchestrates the module lifecycle through GitHub Actions. Version progression is label-driven in pull
requests and resolved once, in the Plan stage, before anything is built. Stable publication occurs from a push or a
supported recovery dispatch on the configured default branch.

## Flow

1. Resolve settings and release intent.
2. Build the module artifact from `src/`, stamping the resolved version into the manifest.
3. Run tests and quality checks.
4. Package docs and site artifacts when enabled.
5. Publish the module and release metadata when release conditions are met.

Test and lint stages run before the publish gates, and publish is blocked when required checks fail.

An open labeled pull request can publish a prerelease. A closed pull request only cleans up its prereleases. When a
pull request merges, the resulting push to the default branch resolves that pull request's labels and creates the
stable release from the exact pushed commit.

## Version labels

An explicit configured bump label overrides `Publish.Module.DefaultBump`. Without a bump label, that setting supplies
`patch`, `minor`, or `major`, with `patch` as the default. The next version is computed as `current version + bump`.

| Label | Effect |
| --- | --- |
| `release:major` | Breaking change; bump `MAJOR`. |
| `release:minor` | New feature; bump `MINOR`. |
| `release:patch` | Bugfix; bump `PATCH`. |
| `release:prerelease` | Publish the resolved bump as a prerelease; not promoted to latest. |
| `release:skip` | Run the pipeline, skip publication. |

Multiple configured bump labels, or skip combined with bump or prerelease intent, fail Plan even for an open PR that
does not publish. A valid skip stops new-version resolution and publication. Closed-PR cleanup ignores release-label
conflicts because it cannot publish. Invalid publication settings fail independently of labels.
Direct releases without an associated merged pull request also use `Publish.Module.DefaultBump`. A default-branch
manual dispatch at a merge commit resolves the same pull request and label as the equivalent push; an ambiguous
merged association fails rather than discarding release intent.
A documentation-only push that cannot publish is not rejected for an unrelated merged association.

These are default names. They remain configurable through `Publish.Module.MajorLabels`, `MinorLabels`, `PatchLabels`,
`PrereleaseLabels`, and `IgnoreLabels` — see [Settings](../reference/settings.md).

## Branch types

- **Main (stable)** — the default branch and the only branch that publishes stable releases.
- **Feature branch** — a short-lived topic branch with a pull request targeting `main`.

Exactly one branch is authorized to publish stable releases, so consumers always have one
unambiguous latest version. Use a
[stacked pull request](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/#stacked-pull-requests)
when changes genuinely depend on each other; independent changes remain separate
short-lived pull requests targeting `main`.

## Recovering a failed release

Rerun the failed jobs in the original workflow run to preserve its source SHA, resolved version, and any successful
build artifacts. A manual dispatch on the default branch uses that branch's current tip, not an arbitrary historical
SHA. It can recover the intended merge only while that merge remains the tip. If the branch has advanced, rerun the
original workflow rather than dispatching the newer tip or selecting an old tag; a tag dispatch is not a
default-branch recovery.

An ambiguous merged-PR association stops a release-capable run instead of falling back to patch. Prerelease cleanup
uses the exact GitHub release target branch, not a sanitized-name substring, so recovery cannot clean another branch's
prereleases. Stable releases and the current published tag are retained.

## Prereleases

A pull request labeled with the configured prerelease label (`release:prerelease` by default) publishes an installable
prerelease using its explicit bump or `Publish.Module.DefaultBump`. Prerelease mode does not select a level by itself
and does not promote the version as latest. When the pull request merges, the stable version uses the resolved bump
and the current version on `main`.

The caller's `pull_request` trigger includes `unlabeled` so removing a bump label recomputes a prerelease from the
effective default. Removing the prerelease label stops publication but retains normal validation. A non-publishing
open PR still validates its bump/default and builds a preview; it is not treated as closed-PR cleanup.

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
