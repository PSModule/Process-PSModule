---
title: Versioning and releases
description: How Process-PSModule resolves release labels, publishes default-branch releases, and safely recovers failed publication.
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
A direct default-branch release without an associated merged PR uses `Patch`, regardless of `AutoPatching`. A
default-branch recovery dispatch at the matching merge commit retains the PR's configured bump or ignore label and
release notes, just like the equivalent push. A documentation-only push does not fail merely because an unrelated
merged PR also claims its commit.

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

## Recovering a failed release

Before retrying, identify the original Plan output's version/tag and source SHA. Retry only when the tag is unclaimed
or its actual immutable commit belongs to that original source. Resolve annotated tags when checking; a release's
`target_commitish` hint is not source proof. If a newer run claimed the same version for different source or contents,
stop and reconcile the conflict instead of retagging or overwriting the published artifact.

Rerun the failed jobs in the original workflow run to preserve its source SHA, resolved version, and any successful
build artifacts. A manual dispatch on the default branch uses that branch's current tip, not an arbitrary historical
SHA. It can recover the intended merge only while that merge remains the tip. If the branch has advanced, rerun the
original workflow rather than dispatching the newer tip or selecting an old tag; a tag dispatch is not a
default-branch recovery.

A new dispatch is rejected when that commit already has a published GitHub release. It must not compute a second
bump after release creation succeeded but asset upload failed. Use the original failed publication job with its
already-resolved version instead. The publisher verifies tag/source ownership, resumes a missing ZIP, retains an
identical existing asset, and rejects different or unverifiable contents without `--clobber`.

An ambiguous merged-PR association stops a release-capable run instead of falling back to patch. Prerelease cleanup
uses exact PR and source provenance for source-bound prereleases. The producer appends a controller-owned footer
after the complete notes and tags the original build commit, so a prerelease retry verifies the same source used at
creation. Legacy branch-targeted records are retained because short refs do not identify their producing PR or
repository. Stable releases, another PR's records, and the current published tag are retained.

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
