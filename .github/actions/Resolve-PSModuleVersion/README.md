# Resolve-PSModuleVersion

Resolves the module version once in Plan, before Build. Existing configured bump labels, preview behavior, version prefixes, and prerelease settings remain the decision authority.

For a stable retry, the resolver searches actual version-tag claims for the original immutable consumer source and producing repository/PR or direct-release context. It uses the shared [publication preflight](../Publish-PSModule/README.md) to verify the exact raw Gallery package and any GitHub release/asset evidence before choosing the original version. Numeric equality, release names, mutable targets, and latest-version hints are not ownership proof.

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

Only one exact source/context claim with matching raw package bytes can select a recovery version. An already-created GitHub release with a missing upload can resume through [Release-PSModule](../Release-PSModule/README.md). The publisher retains the proven Gallery package and verifies the rebuilt/tested artifact again before any write.

| Failure | Safe behavior |
| --- | --- |
| Gallery-only package has missing, foreign, or legacy proof | Stop version resolution; do not reuse the package or invent a fallback number. |
| Same source has multiple claimed published versions | Stop ambiguous recovery for reviewed reconciliation. |
| Claim exists but its Gallery package is absent | Keep the original resolved version/tested artifact and rerun the original failed job. |
| Raw package or rebuilt artifact bytes differ | Stop; never replace published contents. |
| Authentication or API lookup fails | Surface the error instead of treating it as absence. |

Legacy incomplete publication requires reviewed forward-only recovery. Do not fabricate provenance, retarget existing tags, change consumer metadata, or choose a version from a moving/latest hint.
