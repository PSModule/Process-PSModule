# Cleanup-PSModulePrereleases

Removes prerelease GitHub releases and their tags only when the release's `target_commitish` exactly matches the
unsanitized PR head branch supplied by the workflow. `Release-PSModule` records that branch as its prerelease target.
The head repository must also match the base repository; a fork's identically named branch is not ownership proof.
Substring matches, sanitized-name collisions, numeric suffixes, stable releases, and another branch's records do not
establish cleanup ownership.

The normalized `PullRequest` JSON and event-payload fallback retain their existing interfaces. `ReleaseTag` is always
excluded, and `WhatIf: true` reports the exact commands without deleting anything. Releases targeted at an immutable
SHA rather than the exact branch are not eligible through this branch-based interface. Malformed release records or a
failed GitHub lookup stop cleanup instead of guessing.

Normalized context includes `HeadRepository`. For an older payload, the action reads the PR's repository from its
number before selecting releases. Missing or unverifiable repository ownership fails explicitly.

The action fetches every release page through the GitHub API. Tests replace the GitHub CLI with a local function, so
ownership, retained-tag, collision, and dry-run checks do not create or delete real releases.
