---
title: Principles and practices
description: The versioning, branching, and colocation principles behind Process-PSModule, and the development practices it is compatible with.
---

# Principles and practices

## Linear versioning

The contribution and release process is based on the idea that a PR is a release, and we only maintain a single linear ancestry of versions, not going
back to patch and update old versions of the modules. This means that if we are on version `2.1.3` of a module and there is a security issue, we only
patch the latest version with a fix, not releasing new versions based on older versions of the module, i.e. not updating the latest 1.x with the
patch.

## Trunk-based development

Keep feature branches short-lived and open pull requests directly toward `main`.
Independent changes use separate branches; use a
[stacked pull request](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/#stacked-pull-requests)
only when changes genuinely depend on each other. Add the `Prerelease` label to a
feature pull request when a preview version is needed before merging to `main`.

## Colocation of concerns

Colocate concerns for long-term maintainability. For example, `#Requires -Modules` statements belong in the function files that use them, not in a
central manifest — this makes it immediately visible which functions drive each external dependency, and avoids silent drift between the manifest and
the actual code. Another example is how parameter descriptions are placed as comments in the `param()` block directly above each parameter
declaration, rather than in the comment-based help at the top of the function — this keeps the description next to the code it documents.

## Compatibility

The process is compatible with:

- [Test-Driven Development](https://testdriven.io/test-driven-development/) using [Pester](https://pester.dev) and [PSScriptAnalyzer](https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/overview)
- [GitHub Flow specifications](https://docs.github.com/en/get-started/using-github/github-flow)
- [SemVer 2.0.0 specifications](https://semver.org)
- [Continuous Delivery practices](https://en.wikipedia.org/wiki/Continuous_delivery)
