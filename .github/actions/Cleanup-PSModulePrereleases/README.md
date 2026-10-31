# Cleanup-PSModulePrereleases

Removes prerelease GitHub releases and their tags only when cleanup ownership is established. Source-bound
prereleases use the final controller-owned footer written by `Release-PSModule`: the exact base repository and PR
number must match, and the actual tag must resolve to its recorded immutable commit.

Legacy releases without that footer are retained. A branch or `target_commitish` hint cannot prove which PR or
repository produced a record, even when its short name matches the current PR.
Substring matches, sanitized-name collisions, numeric suffixes, stable releases, and another branch's records do not
establish cleanup ownership.

The normalized `PullRequest` JSON and event-payload fallback retain their existing interfaces. `ReleaseTag` is always
excluded, and `WhatIf: true` reports commands without deleting anything. SHA-targeted records without verified
controller provenance are retained. Malformed records, conflicting tag/source provenance, or a failed GitHub lookup
stop cleanup instead of guessing.

The existing normalized `PullRequest` context supplies the source PR number. Missing or invalid PR identity fails
explicitly; older unproven release records are not rewritten or deleted by adopting this version.

The action fetches every release page through the GitHub API. Tests replace the GitHub CLI with a local function, so
ownership, retained-tag, collision, and dry-run checks do not create or delete real releases.
