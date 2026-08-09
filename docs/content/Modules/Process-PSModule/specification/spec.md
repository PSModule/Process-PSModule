---
title: Spec
description: Requirements for Process-PSModule — an end-to-end PowerShell module pipeline that guarantees build, testing, quality gates, documentation generation, and versioned publication to package and docs registries.
---

# Process-PSModule — Spec

## Premise

A PowerShell module's lifecycle — from source code to versioned, published artifact — MUST be reliable, repeatable, and as automated as possible. Contributors focus on code and tests; the pipeline focuses on build, test, quality, documentation, and release. The pipeline MUST be driven entirely by pull-request labels and merge events, never by manual intervention or external tooling. The result is a versioned, immutable artifact — a module package in the PowerShell Gallery and its documentation site — paired with a GitHub Release and a git tag.

### Principles

This capability rests on the [MSX principles](https://msxorg.github.io/docs/Ways-of-Working/Principles/):

- **[Everything as Code](https://msxorg.github.io/docs/Ways-of-Working/Principles/Engineering-Practices/#everything-as-code).** The pipeline and versioning are version-controlled, never a GUI action or manual tag.
- **[Decision before change](https://msxorg.github.io/docs/Ways-of-Working/Principles/AI-First-Development/#decision-before-change).** The pull request is the decision point; its review and labels encode both code acceptance and release intent.
- **[Extensible by default](https://msxorg.github.io/docs/Ways-of-Working/Principles/Software-Design/#extensible-by-default).** The pipeline is technology-agnostic at its core, configurable via a single settings file.

## Scope

Applies to any PowerShell module in the PSModule ecosystem that produces a versioned, publishable artifact. The pipeline does not govern module design, naming, or structure — only the lifecycle from source to published, versioned release.

## Requirements

### Functional Requirements

### FR1 — Build the module from source { #fr1 }

The pipeline MUST compile the PowerShell module source code into a module artifact, stamping it with the resolved semantic version and making it available for downstream testing and publication.

### FR2 — Run cross-platform tests { #fr2 }

The pipeline MUST execute the module's test suites against multiple platforms — at minimum Windows, Linux, and macOS — and fail the build if any platform's tests fail. Tests MUST include source-code validation (style, standards), framework tests (module structure, common issues), and module-local tests (user-written Pester tests).

### FR3 — Enforce code quality and coverage gates { #fr3 }

The pipeline MUST measure and enforce code coverage thresholds and static-analysis results. A build MUST NOT proceed to publication if quality or coverage targets are missed; the gate MUST prevent merge unless explicitly overridden by a label.

### FR4 — Generate and publish documentation { #fr4 }

The pipeline MUST generate module documentation from the source (cmdlet help, README, schema) and publish it to a static documentation site. Documentation MUST be versioned and deployable alongside the module release.

### FR5 — Support label-driven versioning and publication { #fr5 }

The pipeline MUST read pull-request labels (`Major`, `Minor`, `Patch`, `Prerelease`, `NoRelease`) to decide the semantic-version bump. It MUST compute the next version automatically, never reading or writing a hand-edited version file. A merge to the release branch MUST trigger publication to the PowerShell Gallery and documentation site; a prerelease label MUST result in a prerelease version available for testing before stable release.

### FR6 — Produce immutable, linkable releases { #fr6 }

Each publication MUST produce a GitHub Release, a git tag, and a PowerShell Gallery package version — all linked and versioned together so they are discoverable and pinnable for consumers.

### Non-Functional Requirements

### NFR1 — Semantic versioning compliance { #nfr1 }

Versions MUST follow [SemVer 2.0.0](https://semver.org/) (`vMAJOR.MINOR.PATCH` or `vMAJOR.MINOR.PATCH-prerelease.N`). Breaking changes MUST increment `MAJOR`; new functionality MUST increment `MINOR`; bugfixes MUST increment `PATCH`. Prerelease versions MUST be obtainable but not promoted as the latest stable release.

### NFR2 — Serialized releases { #nfr2 }

Only one release process MUST run against a given version of the codebase at a time. Concurrent releases to the same ref MUST be prevented, so the tag, version counter, and published artifact remain consistent.

### NFR3 — Single production authority { #nfr3 }

Exactly one branch (typically `main`) MUST be authorized to publish stable releases. All other release branches MUST publish only prerelease versions. This ensures consumers have one unambiguous latest stable version.

### NFR4 — Rapid feedback on failure { #nfr4 }

Pipeline failures MUST be visible in the pull request and block merge. Contributors MUST know within minutes whether their changes pass quality and test gates, not hours or days later.

### NFR5 — Reproducible and auditable { #nfr5 }

The entire pipeline and its decisions MUST be stored in git, so the build is reproducible and auditable from the commit alone. No external configuration, API calls, or out-of-band decisions.

## Success Criteria

### Building and testing

```gherkin
Scenario: Merge a valid pull request to main
  Given a pull request with passing tests and quality gates
  When the PR is merged to main
  Then the module is built
  And all tests pass on all configured platforms
  And code coverage meets the configured threshold
```

### Version computation

```gherkin
Scenario: Compute the next version from the PR label
  Given a pull request with the label "Minor"
  When the PR is merged to main and the current version is v1.2.3
  Then the new version is computed as v1.3.0

Scenario: Reject ambiguous version labels
  Given a pull request with both "Major" and "Minor" labels
  When the merge is attempted
  Then the build fails and the merge is blocked
```

### Publication

```gherkin
Scenario: Publish a module after a stable release
  Given a merged PR to main with a version bump label
  When the build completes successfully
  Then a new version is published to the PowerShell Gallery
  And a GitHub Release is created
  And a git tag is pushed
  And the documentation site is updated
```

### Prerelease workflow

```gherkin
Scenario: Publish a prerelease version
  Given a pull request with the label "Prerelease"
  When the PR runs the pipeline
  Then a prerelease version is published (e.g., v1.2.3-pr.1.N)
  And it is available for testing before the PR is merged

Scenario: Promote a prerelease to stable
  Given a prerelease PR that is merged to main with a version label
  When the PR is merged
  Then a stable version is computed (e.g., v1.3.0) based on the label and the current main version
  And the stable version is published
```

### Failure handling

```gherkin
Scenario: Block merge on quality gate failure
  Given a pull request failing code coverage requirements
  When the PR is attempted to be merged
  Then the build fails
  And the merge is blocked

Scenario: Handle documentation generation failure
  Given a PR that breaks documentation generation
  When the pipeline runs
  Then the build fails
  And feedback is provided in the PR
  And the module is not published
```

## Where this connects

- [Design](design.md) — how these requirements are delivered.
- [Pipeline stages](../reference/pipeline-stages.md) — the job-by-job breakdown of the workflow.
- [Calling the workflow](../guides/calling-the-workflow.md) — how to invoke the workflow.
- [Settings](../reference/settings.md) — the settings file and its options.
- [Principles and practices](principles-and-practices.md) — versioning, branching, and development practices.
- [Documentation Model](https://msxorg.github.io/docs/Ways-of-Working/Documentation-Model/) — why this spec holds only the why and what.
