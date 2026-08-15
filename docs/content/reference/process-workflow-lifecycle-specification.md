---
title: Process-PSModule workflow lifecycle candidate specification
description: Candidate behavior-driven requirements for Process-PSModule caller event routing, recovery releases, validation, and cleanup.
---

# Process-PSModule workflow lifecycle candidate specification

**Status:** This is a candidate for discussion. It is not an approved workflow standard and does not change the candidate caller contract in [Process-PSModule caller workflow candidate](process-workflow-fleet-standard.md).

## Problem and outcome

Module repositories need each workflow event to have one safe, observable lifecycle outcome. A failed or missed publication needs a recoverable path; published artifacts need continuing validation; and pull-request activity must not create an accidental stable release.

This candidate defines the behavior required from a Process-PSModule workflow lifecycle. Its requirements follow [spec-driven development](https://msx.no/docs/Ways-of-Working/Spec-Driven-Development/) and use [Given / When / Then scenarios](https://msx.no/docs/Ways-of-Working/Spec-Driven-Development/#behavioral-scenarios) as the acceptance contract.

## Scope

The candidate covers dispatch recovery, scheduled validation, pull-request validation and prerelease evaluation, closed-pull-request cleanup, stable publication after a default-branch push, and the Process-PSModule reusable-workflow caller boundary.

It standardizes exactly one conforming Process-PSModule reusable-workflow call job and the shared top-level controls that govern
it; it does not standardize the repository owner's whole workflow. Repository-owned jobs may exist in the same workflow
file or separate workflows, provided they do not weaken or bypass the call's trigger, concurrency, permissions, Plan
authorization, or credential boundary. It does not change module build or publication implementation, define label
names, or prescribe release-note presentation. Those choices remain in the caller candidate, the existing versioning
guidance, and the companion [candidate design](process-workflow-lifecycle-design.md).

## Confirmed implementation baseline

The reusable workflow has a single planning decision that enriches downstream settings with a resolved version and release decision. It also serializes runs by pull request number or ref without canceling a running workflow.

The version resolver treats non-pull-request events, including `workflow_dispatch` and `schedule`, as events without a pull request and does not create a release decision. The existing workflow supports pull-request validation, prerelease publication, default-branch publication, and closed-pull-request prerelease cleanup. Scheduled published-artifact validation and manual recovery publication are not confirmed behavior.

The following requirements describe desired behavior, not a claim that the confirmed implementation already satisfies it.

## Functional requirements

### FR1 — Manual dispatch MUST provide a safe recovery release {#fr1}

A default-branch manual dispatch MUST either publish one recoverable stable release after all required validation succeeds or report that the selected commit is already covered by a stable publication. It MUST NOT create a duplicate stable publication.

#### Behavioral scenarios {#fr1-scenarios}

```gherkin
Scenario: Recover a missing stable publication
  Given the default branch contains a validated commit without a stable publication
  When a maintainer dispatches the workflow for that commit
  Then the workflow publishes one stable artifact and release for the commit
  And the release notes identify merged pull requests since the previous published version

Scenario: Repeat a completed recovery dispatch
  Given a stable publication already covers the selected default-branch commit
  When a maintainer dispatches the workflow again
  Then the workflow reports that no recovery release is required
  And it does not create another artifact, tag, or release
```

### FR2 — Scheduled runs MUST validate published artifacts without publishing {#fr2}

A scheduled run MUST validate the latest published stable artifact and its published documentation against the repository's configured checks. It MUST NOT create, replace, or delete a package, tag, release, or prerelease.

#### Behavioral scenarios {#fr2-scenarios}

```gherkin
Scenario: Validate the latest published artifact
  Given a stable module version and its documentation are published
  When the scheduled workflow runs
  Then the workflow validates that published version
  And it reports the validated version and result
  And it creates no release-related artifact
```

### FR3 — Pull-request delivery events MUST run validation only {#fr3}

An `opened`, `reopened`, or `synchronize` pull-request event targeting the default branch MUST run the configured validation for the pull request. It MUST NOT create a stable publication.

#### Behavioral scenarios {#fr3-scenarios}

```gherkin
Scenario: Validate a synchronized pull request
  Given a pull request targets the default branch
  When a new commit synchronizes the pull request
  Then the workflow reports the configured validation result on that pull request
  And it does not publish a stable version
```

### FR4 — Label changes MUST refresh the planned release classification {#fr4}

A `labeled` or `unlabeled` pull-request event targeting the default branch MUST refresh the complete planned release classification from the current label set and repository settings. A prerelease publication MUST occur only when the planned classification is prerelease and every required validation succeeds.

#### Behavioral scenarios {#fr4-scenarios}

```gherkin
Scenario: Add prerelease eligibility
  Given a validated pull request has no prerelease eligibility
  When a prerelease label is added
  Then the plan resolves the pull request as prerelease eligible
  And it publishes at most one eligible prerelease version

Scenario: Remove prerelease eligibility
  Given a pull request has prerelease eligibility
  When its prerelease label is removed
  Then the plan resolves the pull request as prerelease ineligible
  And it does not create a new prerelease version
```

### FR5 — Closed pull requests MUST route cleanup by close outcome {#fr5}

A merged pull request close MUST NOT perform prerelease cleanup. A successful default-branch release for the merge MUST own promotion cleanup. An abandoned pull request close MUST run cleanup-only behavior for prerelease artifacts associated with that pull request when cleanup is enabled. Neither close outcome MUST authorize or create a stable publication.

#### Behavioral scenarios {#fr5-scenarios}

```gherkin
Scenario: Merge a pull request with prereleases
  Given a merged pull request owns prerelease artifacts
  When its close event is processed
  Then the close event does not clean up prerelease artifacts
  And the successful default-branch release owns promotion cleanup

Scenario: Abandon a pull request with prereleases
  Given an unmerged closed pull request owns prerelease artifacts
  When its close event is processed
  Then the workflow runs cleanup only for that pull request's prerelease artifacts
  And no stable artifact, tag, or release is created
```

### FR6 — Default-branch pushes MUST authorize stable publication after validation {#fr6}

A push to the default branch MUST publish a stable version only after all required build, test, quality, and publication gates succeed. A successful stable release MUST own promotion cleanup.

#### Behavioral scenarios {#fr6-scenarios}

```gherkin
Scenario: Publish a merged pull request
  Given a merged pull request has an unambiguous release intent
  And its merge commit is pushed to the default branch
  When all required validation gates succeed
  Then the workflow publishes the resulting stable version
  And the publication is associated with the pushed commit
  And the successful release performs promotion cleanup
```

### FR7 — Published artifacts MUST match the planned version {#fr7}

Every prerelease or stable publication MUST contain the version and prerelease identity in the planned release decision. A version mismatch MUST fail publication before the release is made visible.

#### Behavioral scenarios {#fr7-scenarios}

```gherkin
Scenario: Reject an incorrectly stamped artifact
  Given the plan resolves a release version
  And the built artifact reports a different version
  When publication is attempted
  Then publication fails
  And no release is made visible for that artifact
```

### FR8 — Pull-request prereleases MUST have deterministic scoped identities {#fr8}

A pull-request prerelease MUST use a deterministic identity scoped to its pull request. Reprocessing the same pull-request state MUST resolve the same prerelease identity, and different pull requests MUST NOT resolve the same identity.

#### Behavioral scenarios {#fr8-scenarios}

```gherkin
Scenario: Reprocess the same pull-request state
  Given a pull request has resolved a prerelease identity
  When the same pull-request state is processed again
  Then the workflow resolves the same prerelease identity
  And it detects an existing publication instead of attempting an overwrite

Scenario: Publish prereleases for distinct pull requests
  Given two pull requests are eligible for prerelease publication
  When both pull requests are processed
  Then each pull request resolves a distinct prerelease identity
```

### FR9 — Lifecycle policy MUST be resolved once before downstream work {#fr9}

The plan MUST resolve the lifecycle policy before build, test, or release execution begins. Downstream work MUST consume that planned policy and MUST NOT reinterpret event data, labels, or repository settings.

#### Behavioral scenarios {#fr9-scenarios}

```gherkin
Scenario: Execute a planned prerelease action
  Given the plan resolves a pull request as an eligible prerelease publication
  When downstream work executes
  Then it consumes the planned release action and version
  And it does not re-evaluate pull-request labels or event data

Scenario: Execute a planned cleanup-only action
  Given the plan resolves an abandoned pull-request close as cleanup only
  When release execution runs
  Then it reconciles only the planned cleanup state
  And it does not create or publish an artifact
```

### FR10 — Stable targets MUST aggregate unreleased merged pull requests {#fr10}

For every stable push or recovery target, the plan MUST aggregate merged pull requests and their release intent from the last successfully published version through the target commit. The resulting stable action MUST converge correctly when GitHub replaces an intermediate pending run.

#### Behavioral scenarios {#fr10-scenarios}

```gherkin
Scenario: Publish after an intermediate pending push is replaced
  Given merged pull requests exist after the last successfully published version
  And an intermediate default-branch push is replaced while pending
  When a later default-branch push is planned
  Then the plan aggregates every merged pull request through the later target commit
  And the stable release uses the aggregated release intent

Scenario: Recover a range of unreleased merged pull requests
  Given merged pull requests exist after the last successfully published version
  When a maintainer dispatches recovery for a later default-branch commit
  Then the plan aggregates every merged pull request through that target commit
  And the release notes use that aggregated range
```

### FR11 — Repository operations MUST use scoped authorization {#fr11}

The caller MUST declare top-level `permissions: {}`. Its Process-PSModule job MUST grant only `contents: read`, `pages: write`, and `id-token: write`. It MUST explicitly map `PSGALLERY_API_KEY`, `GitHubAppClientId`, and `GitHubAppPrivateKey`; `secrets: inherit` is nonconforming. It MAY additionally map `TestData` only for module-local tests. When present, `TestData` MUST contain a JSON object with separate `secrets` and `variables` maps; callers MUST omit it when unused. No conforming caller MAY set `with.Debug: true`; the reusable workflow default remains `false`.

Built-in `GITHUB_TOKEN` MAY authorize repository-local, non-user-facing work when those permissions are sufficient, including checkout, reads, and standard Pages/OIDC deployment. GitHub App installation tokens MUST authorize all user-facing interactions and any operation that exceeds the built-in token's reach or permissions, including pull-request comments and labels, commit statuses and check-facing reporting, releases, tags, assets, and cleanup. Tokens MUST remain scoped to the steps that require them.

#### Behavioral scenarios {#fr11-scenarios}

```gherkin
Scenario: Run with the caller's minimum permissions
  Given the caller declares top-level permissions as an empty object
  And its Process-PSModule job grants only contents read, Pages write, and ID-token write
  When the reusable workflow performs checkout or standard Pages deployment
  Then it may use the built-in workflow token within that granted boundary

Scenario: Provide the required caller credentials explicitly
  Given a conforming caller invokes the reusable workflow
  When it maps credentials to the Process-PSModule job
  Then it maps PSGALLERY_API_KEY, GitHubAppClientId, and GitHubAppPrivateKey explicitly
  And it does not use secrets inherit

Scenario: Provide optional module-local test data
  Given module-local tests require caller-provided data
  When the caller maps TestData
  Then its secret value is a JSON object with separate secrets and variables maps
  And the caller omits TestData when tests do not require it

Scenario: Keep caller debug disabled
  Given a conforming caller invokes the reusable workflow
  When it sets workflow inputs
  Then it does not set Debug to true
  And the reusable workflow uses its false default

Scenario: Perform a user-facing repository operation
  Given the reusable workflow must create a pull-request comment or release
  When the operation requires authority beyond the built-in token boundary
  Then it creates a narrowly scoped GitHub App installation token
  And it uses the App token only for the steps that require that authority
```

### FR12 — Plan MUST authorize events before downstream execution {#fr12}

The caller MUST invoke the reusable workflow without a caller-level fork or event condition. Plan MUST classify a normal
fork `pull_request` event into an authorized restricted read-only validation mode before downstream execution. Its valid
Settings MUST explicitly set `IsFork=true`, `AllowAppToken=false`, `AllowPublication=false`, and
`AllowMutation=false`. That mode MAY perform only safe repository-local checkout, build, lint, and test with the
least-privilege built-in token. It MUST NOT create an App token; access PowerShell Gallery; create pull-request
comments, labels, or status mutations; create releases, tags, or assets; perform cleanup; deploy Pages; or run another
privileged or user-facing operation.

The controlled upstream reusable-workflow Plan implementation MUST derive the restricted capability envelope first from
immutable GitHub event metadata, including fork, base, and head identities, before interpreting repository settings or
executing checked-out repository code. It MAY query the trusted upstream or base version and state as needed. Fork
settings and files MAY be consumed only as untrusted validation and build inputs; they MUST NOT enable App tokens,
mutation, publication, deployment, cleanup, or broaden permissions. The restricted mode MUST provide the ordinary
green/red validation outcome without requiring contributor-configured secrets.

`pull_request_target` MUST remain unsupported until a separate trust boundary is designed and approved. Plan MUST reject
that event before credentials or repository-defined code run. Every downstream job, including a job with `always()`,
MUST require a successful authorized Plan and valid Settings, and every privileged downstream job MUST also require its
relevant planned capability. No downstream job MAY evaluate missing or invalid Settings or bypass the Plan gate.

#### Behavioral scenarios {#fr12-scenarios}

```gherkin
Scenario: Validate a normal fork pull request in restricted mode
  Given a pull request originates from a fork through the pull_request event
  When Plan evaluates the event
  Then Plan emits valid Settings with IsFork true and App-token, publication, and mutation capabilities false
  And downstream work may perform only repository-local checkout, build, lint, and test with the least-privilege built-in token
  And no App token, Gallery access, user-facing operation, Pages deployment, publication, or cleanup runs
  And the contributor receives the standard green or red validation outcome without configured secrets

Scenario: Derive fork capabilities before interpreting untrusted repository inputs
  Given a pull request originates from a fork through the pull_request event
  And its repository settings attempt to enable publication
  When the controlled upstream Plan evaluates immutable fork, base, and head metadata
  Then it fixes the restricted capability envelope before reading the settings or checked-out files
  And the settings cannot enable App tokens, mutation, publication, deployment, cleanup, or broader permissions

Scenario: Reject an unsupported pull_request_target event
  Given a pull_request_target event is received
  When Plan evaluates the event
  Then Plan rejects the event before credentialed or repository-defined code runs
  And no downstream job receives authorized Settings

Scenario: Gate an always-running downstream job
  Given Plan rejects an event or produces invalid Settings
  When a downstream job with an always condition is evaluated
  Then the job does not run
  And it does not evaluate the missing or invalid Settings

Scenario: Gate a privileged job for a restricted fork run
  Given Plan emits valid restricted Settings for a fork pull request
  And the planned capability for publication is false
  When a publication job is evaluated
  Then the job does not run
  And it does not create an App token or parse an absent publication configuration
```

### FR13 — Caller conformance MUST be limited to the reusable-workflow boundary {#fr13}

A conforming caller MUST contain exactly one Process-PSModule reusable-workflow call job and the shared top-level triggers,
concurrency, permissions, Plan authorization, and credential boundary that govern it. Repository-owned jobs MAY coexist
in the same workflow file or in separate workflows. They are not nonconforming merely by existing, but they MUST NOT
weaken or bypass any of those controls for the Process-PSModule call.

#### Behavioral scenarios {#fr13-scenarios}

```gherkin
Scenario: Retain a repository-owned job beside the reusable-workflow call
  Given a workflow contains one conforming Process-PSModule reusable-workflow call job
  And a repository-owned documentation job exists in the same workflow file
  When the workflow is evaluated for caller conformance
  Then the documentation job is reported for visibility
  And its existence does not make the Process-PSModule call nonconforming

Scenario: Prevent a repository-owned job from bypassing the caller boundary
  Given a repository-owned job exists beside or outside the caller workflow
  When it could weaken or bypass the Process-PSModule call's trigger, concurrency, permissions, Plan authorization, or credential boundary
  Then the caller arrangement is nonconforming
```

## Non-functional requirements

### NFR1 — Lifecycle mutations MUST be idempotent {#nfr1}

Retrying the same event for the same commit and resolved version MUST produce no more than one package, tag, and release for that version.

#### Behavioral scenarios {#nfr1-scenarios}

```gherkin
Scenario: Retry a publication after an interrupted run
  Given a publication for a resolved version was interrupted
  When the workflow retries the same event
  Then it completes the missing work or reports the completed work
  And it does not duplicate the package, tag, or release
```

### NFR2 — Pull-request cancellation MUST preserve non-pull-request serialization {#nfr2}

All pull-request events for one pull request MUST share a cancellation scope, so a newer pull-request event cancels a superseded run. Push, manual dispatch, and scheduled runs MUST share a full-ref serialization scope and MUST NOT cancel an in-progress run. Because GitHub permits at most one running and one pending run per group, a newer same-group non-pull-request run MAY replace an older pending run; the stable plan MUST therefore converge from the last successfully published version.

#### Behavioral scenarios {#nfr2-scenarios}

```gherkin
Scenario: Supersede a pull-request run
  Given a pull-request run is in progress
  When a newer synchronize, label, unlabel, or close event starts
  Then the older pull-request run is canceled

Scenario: Serialize non-pull-request runs
  Given a default-branch release is in progress
  And an earlier default-branch run is pending
  When a manual dispatch or scheduled validation starts for the same full ref
  Then the later run does not cancel the running release
  And it may replace the older pending run
  And the next stable plan aggregates the unreleased merged pull requests
```

### NFR3 — Each lifecycle outcome MUST be auditable {#nfr3}

Every run MUST report its event category, resolved version or validated published version, release decision, and terminal outcome before the run completes.

#### Behavioral scenarios {#nfr3-scenarios}

```gherkin
Scenario: Inspect a scheduled validation result
  Given a scheduled validation has completed
  When a maintainer inspects the workflow result
  Then the result identifies the validated published version
  And it identifies whether validation passed or failed
  And it identifies that no release mutation occurred
```

### NFR4 — Pull-request mutation paths MUST resume and converge {#nfr4}

Every pull-request path, including prerelease publication and cleanup, MUST be idempotent and resumable after cancellation. The next `synchronize`, `labeled`, `unlabeled`, or `closed` event MUST converge release-related state to the latest pull-request state. Cancellation MAY leave transient partial state, but it MUST NOT leave a permanent duplicate or an obsolete artifact without the required disposition.

#### Behavioral scenarios {#nfr4-scenarios}

```gherkin
Scenario: Resume a canceled prerelease publication
  Given a canceled pull-request run published a prerelease package but did not finish its release metadata
  When a later pull-request event is processed
  Then the workflow detects the existing version
  And it completes or reconciles the prerelease release state without duplication

Scenario: Reconcile obsolete prereleases
  Given a canceled pull-request run left prerelease artifacts for an earlier pull-request state
  When a synchronize, label, unlabel, or close event is processed
  Then the workflow reconciles prerelease artifacts to the latest pull-request state
  And every obsolete prerelease has the required disposition
```

### NFR5 — Pull-request events MUST NOT produce production artifacts {#nfr5}

A pull-request event MUST NOT create a stable or signable production artifact. Pull-request events MAY create only eligible prerelease artifacts and their associated metadata.

#### Behavioral scenarios {#nfr5-scenarios}

```gherkin
Scenario: Evaluate an eligible prerelease pull request
  Given a pull request is eligible for prerelease publication
  When its release-capable path completes
  Then it creates only prerelease artifacts and metadata
  And it does not create a stable or signable production artifact
```

### NFR6 — Immutable Gallery prereleases MUST have a disposition policy {#nfr6}

PowerShell Gallery packages MUST be treated as immutable and MUST NOT be overwritten. The candidate MUST define whether obsolete pull-request prereleases are unlisted through a supported Gallery API or retained as documented immutable versions when unlisting is not feasible. This policy is distinct from GitHub Release and tag cleanup.

#### Behavioral scenarios {#nfr6-scenarios}

```gherkin
Scenario: Dispose of an obsolete Gallery prerelease
  Given a pull-request prerelease is obsolete
  And a supported Gallery API can unlist that version
  When the prerelease is reconciled
  Then the workflow unlists the immutable Gallery package
  And it performs GitHub Release and tag cleanup independently

Scenario: Retain an immutable Gallery prerelease
  Given a pull-request prerelease is obsolete
  And unlisting that Gallery version is not feasible
  When the prerelease is reconciled
  Then the workflow records the retained immutable Gallery version
  And it performs GitHub Release and tag cleanup independently
```

### NFR7 — App-required operations MUST fail closed {#nfr7}

When an operation requires GitHub App authorization and the required App token is unavailable, the operation MUST fail before an unauthorized API request, status update, comment, release, tag or asset mutation, or cleanup. It MUST NOT silently fall back to built-in `GITHUB_TOKEN` authority. Repository-local reads and standard Pages/OIDC deployment MAY continue only within the caller job's explicit built-in-token permissions.

#### Behavioral scenarios {#nfr7-scenarios}

```gherkin
Scenario: Reject a user-facing operation without GitHub App authorization
  Given a reusable-workflow job cannot create its required GitHub App token
  When the job attempts to create a pull-request comment
  Then the operation fails before the API request
  And it does not use the built-in workflow token as a fallback
```

## Cross-cutting acceptance criteria

### AC1 — Verifies: [FR1](#fr1), [FR6](#fr6), [FR7](#fr7), [NFR1](#nfr1)

```gherkin
Scenario: Recover release notes after a missed main-push publication
  Given merged pull requests exist after the last published stable version
  And the selected default-branch commit has no stable publication
  When a maintainer dispatches a recovery release
  Then the published artifact matches the resolved version
  And the release notes identify the merged pull requests in that unreleased range
  And a retry creates no duplicate publication
```

### AC2 — Verifies: [FR2](#fr2), [FR4](#fr4), [FR5](#fr5), [FR6](#fr6), [FR8](#fr8), [FR9](#fr9), [FR10](#fr10), [FR11](#fr11), [FR12](#fr12), [FR13](#fr13), [NFR2](#nfr2), [NFR3](#nfr3), [NFR4](#nfr4), [NFR5](#nfr5), [NFR6](#nfr6), [NFR7](#nfr7)

```gherkin
Scenario: Lifecycle runs preserve release ownership after cancellation
  Given a scheduled validation and an abandoned pull-request cleanup overlap a main-push release
  And the cleanup supersedes a canceled prerelease publication
  When all three runs complete
  Then the scheduled run reports validation without a release mutation
  And the cleanup reconciles only the abandoned pull request's prereleases
  And none of the runs cancel the main-push release
  And the main-push run is the only run that publishes the stable release and performs promotion cleanup
```

## Impact

This candidate aims to reduce time to restore a missed publication and reduce change failure risk by separating validation, cleanup, prerelease, and stable-release authority. Its domain signal is the count of duplicate, missing, or incorrectly stamped published versions per release cycle; the target is zero.

## Dependencies and constraints

Approval of the caller event and concurrency contract in [PSModule/Process-PSModule#514](https://github.com/PSModule/Process-PSModule/issues/514) is required before this candidate becomes an implementation commitment. The candidate depends on repository credentials that can query pull requests and publish module artifacts. It retains the caller candidate's default-branch and fork boundaries.

## Related

- [Candidate design](process-workflow-lifecycle-design.md) — proposed routing and recovery approach.
- [Scenario matrix](scenario-matrix.md) — established job-level routing reference.
- [Process-PSModule caller workflow candidate](process-workflow-fleet-standard.md) — candidate caller event and concurrency contract.
