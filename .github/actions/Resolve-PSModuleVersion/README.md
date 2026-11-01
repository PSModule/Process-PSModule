# Resolve-PSModuleVersion

Resolves the module version once in Plan, before Build. Existing configured bump labels, preview behavior, version prefixes, and prerelease settings remain the decision authority.

For a stable retry, the resolver searches both release-tag and shared module/version claims for the original immutable consumer source and producing repository/PR or direct-release context. Refs pointing to the same immutable claim are deduplicated. It uses the shared [publication preflight](../Publish-PSModule/README.md) to verify the exact raw Gallery package and any GitHub release/asset evidence before choosing the original version. Numeric equality, release names, mutable targets, and latest-version hints are not ownership proof.

## Inputs

| Name | Meaning |
| --- | --- |
| `Name` | Existing module-name input; defaults to the consumer repository name. |
| `Settings` | Complete settings JSON, including the existing normalized `Context.CommitSha`, producing `Context.PullRequest`, and publish configuration. |
| `WorkingDirectory` | Existing consumer working directory. |

The normal workflow supplies these values internally. Recovery does not add a scalar bump input or replace the configured release-decision policy.

## Outputs

The existing `Version`, `Prerelease`, `FullVersion`, `ReleaseType`, and `CreateRelease` outputs remain unchanged. Build receives the proven original coordinates for recovery instead of a newly guessed version.

## Recovery safety

Only one exact source/context claim with matching raw package bytes can select a recovery version. An already-created GitHub release with a missing upload can resume through [Release-PSModule](../Release-PSModule/README.md), but only from the original proven tested bytes. Selecting the original version does not make a rebuild byte-identical or select the original tested artifact.

An unpublished shared-only claim still stops Plan for original-job retry, even after a later source completes another version. A new source checks baseline completeness using the actual historical tag and release, not a tag reconstructed with the current configured prefix. Recovery and new claims still require exact configured-prefix binding; ambiguous historical baselines stop explicitly.

Historical prefixes may contain digits, with or without a separator. A matching version suffix only discovers a candidate tag; exact release metadata, matching module/version asset and immutable tag source must establish baseline completeness. Numeric suffixes alone never establish ownership.

| Failure | Safe behavior |
| --- | --- |
| Gallery-only package has missing, foreign, or legacy proof | Stop version resolution; do not reuse the package or invent a fallback number. |
| Same source has multiple claimed published versions | Stop ambiguous recovery for reviewed reconciliation. |
| Claim exists but its Gallery package is absent | Keep the original resolved version/tested artifact and rerun the original failed job. |
| Raw package or rebuilt artifact bytes differ | Stop; never replace published contents. |
| Authentication or API lookup fails | Surface the error instead of treating it as absence. |

Legacy incomplete publication requires reviewed forward-only recovery. Do not fabricate provenance, retarget existing tags, change consumer metadata, or choose a version from a moving/latest hint.

## Retry eligibility

Plan resolves coordinates, not original-run artifact selection or completed-test provenance. A full workflow rerun still executes enabled Build/test jobs; supported manifests without a `GUID` can produce different artifact bytes on that rebuild. Publication rejects those bytes rather than treating the resolved version as proof of recovery.

An original failed-publishing-job retry is eligible only while its original artifact, settings, source/context, and required test evidence remain verifiable and its original runtime already contains the ownership checks. Missing or expired artifacts and unproven evidence do not authorize publication. See [Retry eligibility and artifact retention](../../../docs/content/guides/versioning-and-releases.md#retry-eligibility-and-artifact-retention) for the supported paths and the wrappers' current-run/name selection limits.
