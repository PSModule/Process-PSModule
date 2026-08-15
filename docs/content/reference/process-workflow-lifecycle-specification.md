---
title: Process-PSModule workflow lifecycle specification
description: Behavior-driven requirements for Process-PSModule event routing, recovery releases, validation, and cleanup.
---

# Process-PSModule workflow lifecycle specification

This specification defines the lifecycle requirements for the Process-PSModule reusable workflow. Requirements follow
[spec-driven development](https://msx.no/docs/Ways-of-Working/Spec-Driven-Development/) and use
[Given / When / Then scenarios](https://msx.no/docs/Ways-of-Working/Spec-Driven-Development/#behavioral-scenarios) as
the acceptance contract.

## Scope

The lifecycle covers dispatch recovery, scheduled published-artifact validation, pull-request validation and prerelease
evaluation, closed-pull-request cleanup, and stable publication after a default-branch push.

The [Process-PSModule caller contract](process-workflow-fleet-standard.md) requires exactly one reusable-workflow call
job and the shared top-level controls that govern it. Repository-owned jobs MAY exist in the same workflow file or in
separate workflows, provided they do not weaken or bypass the call's trigger, concurrency, permissions, Plan
authorization, or credential boundary.

## Functional requirements

### FR1 — Manual dispatch MUST provide a safe recovery release {#fr1}

A default-branch manual dispatch MUST either publish one stable release after all required validation succeeds or report
that the selected commit is already covered by a stable publication. It MUST NOT create a duplicate stable publication.
Release notes MUST identify the merged pull requests from the last successfully published stable version through the
selected commit.

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

A scheduled run MUST validate the latest published stable artifact and its published documentation against configured
checks. It MUST NOT create, replace, or delete a package, tag, release, or prerelease.

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

An `opened`, `reopened`, or `synchronize` pull-request event targeting the default branch MUST run configured
validation. It MUST NOT create a stable publication.

#### Behavioral scenarios {#fr3-scenarios}

```gherkin
Scenario: Validate a synchronized pull request
  Given a pull request targets the default branch
  When a new commit synchronizes the pull request
  Then the workflow reports the configured validation result
  And it does not publish a stable version
```

### FR4 — Label changes MUST refresh the release classification {#fr4}

A `labeled` or `unlabeled` pull-request event targeting the default branch MUST resolve the complete classification
from the current label set and repository settings. A prerelease publication MUST occur only when the classification is
prerelease and every required validation succeeds.

#### Behavioral scenarios {#fr4-scenarios}

```gherkin
Scenario: Add prerelease eligibility
  Given a validated pull request has no prerelease eligibility
  When a prerelease label is added
  Then Plan resolves the pull request as prerelease eligible
  And it publishes at most one eligible prerelease version

Scenario: Remove prerelease eligibility
  Given a pull request has prerelease eligibility
  When its prerelease label is removed
  Then Plan resolves the pull request as prerelease ineligible
  And it does not create a new prerelease version
```

### FR5 — Closed pull requests MUST route cleanup by close outcome {#fr5}

A merged pull-request close MUST NOT perform prerelease cleanup. A successful default-branch stable release MUST own
promotion cleanup. An abandoned pull-request close MUST run cleanup-only behavior for prerelease artifacts associated
with that pull request. Neither close outcome MUST authorize or create a stable publication.

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

A push to the default branch MUST publish a stable version only after all required build, test, quality, and publication
gates succeed. A successful stable release MUST own promotion cleanup.

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

Every prerelease or stable publication MUST contain the planned manifest version and prerelease identity. A mismatch
MUST fail publication before the release becomes visible.

#### Behavioral scenarios {#fr7-scenarios}

```gherkin
Scenario: Reject an incorrectly stamped artifact
  Given Plan resolves a release version
  And the built artifact reports a different version
  When publication is attempted
  Then publication fails
  And no release is made visible for that artifact
```

### FR8 — Pull-request prereleases MUST have deterministic immutable identities {#fr8}

A pull-request prerelease MUST use a deterministic identity scoped to its pull request. Reprocessing the same
pull-request state MUST resolve the same identity, and different pull requests MUST NOT resolve the same identity.
PowerShell Gallery versions MUST be treated as immutable and MUST NOT be overwritten.

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

### FR9 — Plan MUST resolve lifecycle policy before downstream work {#fr9}

Plan MUST resolve lifecycle policy before build, test, or release execution. Its enriched Settings MUST contain the
event and run type, event action, pull-request identity, state and merge status, labels, version bump, base version,
manifest version, prerelease identifier, full version or tag, target commit, resolved release action, create and publish
flags, cleanup intent, artifact identity, release-note source and boundary, and authorization capabilities. Downstream
work MUST consume Settings and MUST NOT reinterpret event data, labels, or repository settings.

#### Behavioral scenarios {#fr9-scenarios}

```gherkin
Scenario: Execute a planned prerelease action
  Given Plan resolves a pull request as an eligible prerelease publication
  When downstream work executes
  Then it consumes the planned release action and version
  And it does not re-evaluate pull-request labels or event data

Scenario: Execute a planned cleanup-only action
  Given Plan resolves an abandoned pull-request close as cleanup only
  When release execution runs
  Then it reconciles only the planned cleanup state
  And it does not create or publish an artifact
```

### FR10 — Stable targets MUST aggregate unreleased merged pull requests {#fr10}

For every stable push or recovery target, Plan MUST aggregate merged pull requests and their release intent from the
last successfully published version through the target commit. The resulting stable action MUST converge when GitHub
replaces an intermediate pending run.

#### Behavioral scenarios {#fr10-scenarios}

```gherkin
Scenario: Publish after an intermediate pending push is replaced
  Given merged pull requests exist after the last successfully published version
  And an intermediate default-branch push is replaced while pending
  When a later default-branch push is planned
  Then Plan aggregates every merged pull request through the later target commit
  And the stable release uses the aggregated release intent

Scenario: Recover a range of unreleased merged pull requests
  Given merged pull requests exist after the last successfully published version
  When a maintainer dispatches recovery for a later default-branch commit
  Then Plan aggregates every merged pull request through that target commit
  And the release notes use that aggregated range
```

### FR11 — Repository operations MUST use scoped authorization {#fr11}

The caller MUST declare top-level `permissions: {}`. Its Process-PSModule job MUST grant only `contents: read`,
`pages: write`, and `id-token: write`. It MUST explicitly map `PSGALLERY_API_KEY`, `GitHubAppClientId`, and
`GitHubAppPrivateKey`; `secrets: inherit` MUST NOT be used. It MAY map `TestData` only for module-local tests.
When present, `TestData` MUST contain a JSON object with separate `secrets` and `variables` maps; callers MUST omit it
when unused. `TestData` MUST be the only variation from the canonical caller template. A caller MUST NOT declare
`run-name`, alter the canonical schedule, add a caller condition, or pass any `with:` input.

Built-in `GITHUB_TOKEN` MAY authorize repository-local, non-user-facing work when those permissions are sufficient,
including checkout, reads, and standard Pages/OIDC deployment. GitHub App installation tokens MUST authorize all
user-facing interactions and operations beyond the built-in token boundary, including pull-request comments and labels,
commit statuses and check-facing reporting, releases, tags, assets, and cleanup. Tokens MUST remain scoped to the steps
that require them.

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

Scenario: Match the canonical caller template
  Given a conforming caller invokes the reusable workflow
  When its Process-PSModule caller contract is compared with the canonical template
  Then every field matches the template
  And TestData is the only permitted optional mapping

Scenario: Perform a user-facing repository operation
  Given the reusable workflow must create a pull-request comment or release
  When the operation requires authority beyond the built-in token boundary
  Then it creates a narrowly scoped GitHub App installation token
  And it uses the App token only for the steps that require that authority
```

### FR12 — Plan MUST authorize events before downstream execution {#fr12}

The caller MUST invoke the reusable workflow without a caller-level fork or event condition. For a normal fork
`pull_request`, the controlled upstream Plan implementation MUST derive a restricted capability envelope from immutable
GitHub event metadata, including fork, base, and head identities, before interpreting repository settings or executing
checked-out code. The Settings record MUST set `IsFork=true`, `AllowAppToken=false`, `AllowPublication=false`, and
`AllowMutation=false`.

The restricted mode MAY perform repository-local checkout, build, lint, and test with the least-privilege built-in
token. It MUST NOT create an App token; access PowerShell Gallery; create pull-request comments, labels, or status
mutations; create releases, tags, or assets; perform cleanup; deploy Pages; or run another privileged or user-facing
operation. Fork settings and files MAY be consumed only as untrusted validation and build inputs and MUST NOT broaden
the capability envelope. The restricted mode MUST provide a green or red validation outcome without contributor secrets.

`pull_request_target` MUST be rejected before credentials or repository-defined code run. Every downstream job,
including a job with `always()`, MUST require successful Plan execution and valid Settings. Every privileged downstream
job MUST also require its relevant planned capability. No downstream job MAY evaluate missing or invalid Settings or
bypass the Plan gate.

#### Behavioral scenarios {#fr12-scenarios}

```gherkin
Scenario: Validate a normal fork pull request in restricted mode
  Given a pull request originates from a fork through the pull_request event
  When Plan evaluates immutable fork, base, and head metadata
  Then Plan emits valid restricted Settings
  And downstream work may perform only repository-local checkout, build, lint, and test
  And the contributor receives a green or red validation outcome without configured secrets

Scenario: Prevent untrusted inputs from expanding fork capabilities
  Given a pull request originates from a fork through the pull_request event
  And its repository settings attempt to enable publication
  When Plan reads the settings or checked-out files
  Then App-token, publication, mutation, deployment, and cleanup capabilities remain false

Scenario: Reject a pull_request_target event
  Given a pull_request_target event is received
  When Plan evaluates the event
  Then Plan rejects the event before credentials or repository-defined code run
  And no downstream job receives authorized Settings

Scenario: Gate a privileged job for a restricted fork run
  Given Plan emits valid restricted Settings for a fork pull request
  And the planned capability for publication is false
  When a publication job is evaluated
  Then the job does not run
  And it does not create an App token or parse an absent publication configuration
```

### FR13 — Caller conformance MUST be limited to the reusable-workflow boundary {#fr13}

A conforming caller MUST contain exactly one Process-PSModule reusable-workflow call job and the shared top-level
triggers, concurrency, permissions, Plan authorization, and credential boundary that govern it. Repository-owned jobs
MAY coexist in the same workflow file or in separate workflows. They MUST NOT weaken or bypass any of those controls for
the Process-PSModule call.

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
  When it weakens or bypasses the Process-PSModule call's trigger, concurrency, permissions, Plan authorization, or credential boundary
  Then the caller arrangement is nonconforming
```

## Non-functional requirements

### NFR1 — Lifecycle mutations MUST be idempotent {#nfr1}

Retrying the same event for the same commit and resolved version MUST produce no more than one package, tag, and
release for that version.

```gherkin
Scenario: Retry a publication after an interrupted run
  Given a publication for a resolved version was interrupted
  When the workflow retries the same event
  Then it completes the missing work or reports the completed work
  And it does not duplicate the package, tag, or release
```

### NFR2 — Pull-request cancellation MUST preserve non-pull-request serialization {#nfr2}

The caller MUST use:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

All pull-request events for one pull request share a cancellation scope. Push, manual dispatch, and scheduled runs
share a full-ref serialization scope and MUST NOT cancel an in-progress run. GitHub permits one running and one pending
run per group; a later non-pull-request run MAY replace an earlier pending run. Stable planning MUST therefore converge
from the last successfully published version. The group MUST use full `github.ref`; `github.ref_name` does not
distinguish colliding branch and tag names.

```gherkin
Scenario: Serialize non-pull-request runs
  Given a default-branch release is in progress
  And an earlier default-branch run is pending
  When a manual dispatch or scheduled validation starts for the same full ref
  Then the later run does not cancel the running release
  And it may replace the earlier pending run
  And the next stable plan aggregates the unreleased merged pull requests
```

### NFR3 — Each lifecycle outcome MUST be auditable {#nfr3}

Every run MUST report its event category, resolved or validated version, release decision, and terminal outcome.

### NFR4 — Pull-request mutation paths MUST resume and converge {#nfr4}

Every pull-request path, including prerelease publication and cleanup, MUST be idempotent and resumable after
cancellation. The next `synchronize`, `labeled`, `unlabeled`, or `closed` event MUST reconcile release-related state
to the latest pull-request state. Cancellation MAY leave transient partial state but MUST NOT leave a permanent
duplicate or obsolete artifact without its required disposition.

### NFR5 — Pull-request events MUST NOT produce production artifacts {#nfr5}

A pull-request event MUST NOT create a stable or signable production artifact. Pull-request events MAY create only
eligible prerelease artifacts and associated metadata.

### NFR6 — Immutable Gallery prereleases MUST have a durable disposition {#nfr6}

An obsolete PowerShell Gallery prerelease MUST be unlisted through a supported Gallery API when feasible. When unlisting
is infeasible, the workflow MUST retain and record the immutable version. GitHub Release and tag cleanup MUST execute
independently from Gallery disposition.

```gherkin
Scenario: Dispose of an obsolete Gallery prerelease
  Given a pull-request prerelease is obsolete
  And a supported Gallery API can unlist that version
  When the prerelease is reconciled
  Then the workflow unlists the immutable Gallery package
  And it performs GitHub Release and tag cleanup independently

Scenario: Retain an immutable Gallery prerelease
  Given a pull-request prerelease is obsolete
  And unlisting that Gallery version is infeasible
  When the prerelease is reconciled
  Then the workflow records the retained immutable Gallery version
  And it performs GitHub Release and tag cleanup independently
```

### NFR7 — App-required operations MUST fail closed {#nfr7}

When an operation requires GitHub App authorization and the required App token is unavailable, the operation MUST fail
before an unauthorized API request, status update, comment, release, tag or asset mutation, or cleanup. It MUST NOT
fall back to built-in `GITHUB_TOKEN` authority.

## Cross-cutting acceptance criteria

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

## Related

- [Process-PSModule workflow lifecycle design](process-workflow-lifecycle-design.md)
- [Process-PSModule caller contract](process-workflow-fleet-standard.md)
