---
title: Principles and practices
description: The versioning, branching, and colocation principles behind Process-PSModule, and the development practices it is compatible with.
---

# Principles and practices

## Linear versioning

The contribution and release process treats a PR as a release and maintains one linear version history. Only the latest version receives patches and updates.

For example, if version `2.1.3` has a security issue, the fix applies to the latest version. The 1.x series does not receive the patch.

## Trunk-based development

Keep feature branches short-lived and open pull requests directly toward `main`.
Independent changes use separate branches; use a
[stacked pull request](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/#stacked-pull-requests)
only when changes genuinely depend on each other. Add the `Prerelease` label to a
feature pull request when a preview version is needed before merging to `main`.

## Colocation of concerns

Colocate concerns for long-term maintainability. For example, `#Requires -Modules` statements belong in the function files that use them, not in a central manifest. This shows which functions use each external dependency and prevents silent drift between the manifest and the code.

Parameter descriptions are comments in the `param()` block, directly above each parameter declaration. This keeps each description next to its code, rather than in the comment-based help at the top of the function.

## Compatibility

The process is compatible with:

- [Test-Driven Development](https://testdriven.io/test-driven-development/) using [Pester](https://pester.dev) and [PSScriptAnalyzer](https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/overview)
- [GitHub Flow specifications](https://docs.github.com/en/get-started/using-github/github-flow)
- [SemVer 2.0.0 specifications](https://semver.org)
- [Continuous Delivery practices](https://en.wikipedia.org/wiki/Continuous_delivery)
