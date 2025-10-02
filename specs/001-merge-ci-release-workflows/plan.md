# Implementation Plan: Unified CI and Release Workflow

**Branch**: `001-merge-ci-release-workflows` | **Date**: 2025-10-02 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-merge-ci-release-workflows/spec.md`

## Execution Flow (/plan command scope)

1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+API)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document them in Complexity Tracking
   → If no justification is possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:

- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary

This feature consolidates the separate CI (CI.yml) and release (workflow.yml) workflows into a single unified workflow that intelligently handles both continuous integration testing and automated release publishing based on trigger context. The unified workflow executes CI tests on all events (PR and main branch), but conditionally executes release operations only when changes are merged to the main branch. This breaking change eliminates maintenance overhead across all PSModule repositories by providing a single source of truth for the entire CI/CD pipeline.

## Technical Context

| Aspect | Details |
|--------|---------|
| **Language/Version** | PowerShell 7.4+ (GitHub Actions composite actions), YAML (GitHub Actions workflows) |
| **Primary Dependencies** | GitHub Actions, PSModule/GitHub-Script@v1, PSModule/Install-PSModuleHelpers@v1, PSModule/Publish-PSModule@v2 |
| **Storage** | GitHub Actions artifacts for module builds, test results, and code coverage data |
| **Testing** | Pester tests, PSScriptAnalyzer linting, cross-platform matrix testing (ubuntu-latest, windows-latest, macos-latest) |
| **Target Platform** | GitHub Actions runners (ubuntu-latest, windows-latest, macos-latest) |
| **Project Type** | Single project (GitHub Actions reusable workflow framework) |
| **Performance Goals** | Workflow execution time similar to current separate workflows (no performance regression) |
| **Constraints** | Must maintain backward compatibility with existing trigger patterns; must not require simultaneous updates across all consuming repositories |
| **Scale/Scope** | Affects all PSModule repositories consuming Process-PSModule workflows (~10-20 repositories); single workflow file replacing two separate files |

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Workflow-First Design (NON-NEGOTIABLE)

- [x] Feature is implemented as reusable GitHub Actions workflow(s)
  - Unified workflow.yml will remain a reusable workflow with `workflow_call` trigger
- [x] Workflows have clearly defined inputs and outputs
  - Same inputs/outputs as current workflow.yml; secrets remain unchanged
- [x] Workflows follow single responsibility principle
  - Single workflow handles complete CI/CD pipeline with conditional execution
- [x] Matrix strategies used for parallel execution where appropriate
  - Existing matrix strategies preserved (Test-SourceCode, Test-ModuleLocal)
- [x] Workflows are independently testable via CI validation workflow
  - Existing CI validation workflow pattern will be adapted for unified workflow
- [x] Logic delegated to reusable GitHub Actions (PSModule organization)
  - All existing action calls preserved (PSModule/GitHub-Script@v1, etc.)
- [x] Inline PowerShell code avoided; action-based scripts used instead
  - No inline PowerShell; all scripts delegated to actions
- [x] Actions referenced by specific versions/tags
  - All actions use versioned references (@v1, @v2, etc.)

### II. Test-Driven Development (NON-NEGOTIABLE)

- [x] Tests will be written before implementation
  - Test plan for conditional execution logic before workflow modifications
- [x] Initial tests will fail (Red phase documented)
  - Validation tests will fail until conditional logic implemented
- [x] Implementation plan includes making tests pass (Green phase)
  - Implementation phases documented below
- [x] Refactoring phase planned while maintaining tests
  - Workflow optimization phase after initial implementation
- [x] PSScriptAnalyzer validation included
  - Existing linting workflows apply to any PowerShell scripts
- [x] Manual testing documented if needed
  - Manual testing required for trigger condition validation
- [x] CI validation workflow tests included
  - CI validation workflow will be updated to test unified workflow

### III. Platform Independence with Modern PowerShell

- [x] PowerShell 7.4+ constructs used exclusively
  - All PowerShell scripts target 7.4+
- [x] Matrix testing across Linux, macOS, Windows included
  - Existing Test-ModuleLocal matrix preserved (ubuntu-latest, windows-latest, macos-latest)
- [x] Platform-specific behaviors documented
  - No platform-specific changes; workflow behavior platform-agnostic
- [x] Skip mechanisms justified if platform-specific tests needed
  - No platform-specific skip mechanisms needed
- [x] No backward compatibility with PowerShell 5.1 required
  - No 5.1 compatibility required

### IV. Quality Gates and Observability

- [x] Test results captured in structured JSON format
  - Existing Get-TestResults job captures structured results
- [x] Code coverage measurement included
  - Existing Get-CodeCoverage job preserved
- [x] Linting results captured and enforced
  - Existing Lint-SourceCode job preserved
- [x] Quality gate thresholds defined
  - Existing quality gates maintained
- [x] Clear error messages planned
  - Conditional execution includes clear skip reasons
- [x] Debug mode support included
  - Existing Debug input parameter preserved

### V. Continuous Delivery with Semantic Versioning

- [x] Version bump strategy documented (labels, SemVer)
  - This is a Major breaking change requiring version bump to v5
- [x] Release automation compatible with existing workflow
  - Unified workflow maintains existing release automation
- [x] Documentation updates included
  - README and migration guide required
- [x] GitHub Pages publishing considered if docs changes
  - Documentation site will be updated with migration instructions

## Project Structure

### Documentation (this feature)

```plaintext
specs/001-merge-ci-release-workflows/
├── spec.md              # Feature specification
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0 output (workflow analysis)
├── data-model.md        # Phase 1 output (workflow state model)
├── quickstart.md        # Phase 1 output (migration guide)
└── contracts/           # Phase 1 output (workflow contracts)
    └── workflow-api.yml # Workflow inputs/outputs contract
```

### Source Code (repository root)

```plaintext
.github/workflows/
├── workflow.yml                        # MODIFIED: Unified CI + Release workflow
├── CI.yml                              # DEPRECATED: To be removed in future version
├── Get-Settings.yml                    # UNCHANGED: Settings loader
├── Build-Module.yml                    # UNCHANGED: Module builder
├── Build-Docs.yml                      # UNCHANGED: Documentation builder
├── Build-Site.yml                      # UNCHANGED: Site builder
├── Test-SourceCode.yml                 # UNCHANGED: Source code tests
├── Lint-SourceCode.yml                 # UNCHANGED: Source code linting
├── Test-Module.yml                     # UNCHANGED: Module tests
├── Test-ModuleLocal.yml                # UNCHANGED: Local Pester tests
├── Get-TestResults.yml                 # UNCHANGED: Test aggregation
├── Get-CodeCoverage.yml                # UNCHANGED: Coverage analysis
├── Publish-Module.yml                  # REMOVED: Logic moved to workflow.yml
├── Publish-Site.yml                    # REMOVED: Logic moved to workflow.yml
├── Workflow-Test-Default.yml           # MODIFIED: Test unified workflow
├── Workflow-Test-Default-CI.yml        # DEPRECATED: No longer needed
├── Workflow-Test-WithManifest.yml      # MODIFIED: Test unified workflow
└── Workflow-Test-WithManifest-CI.yml   # DEPRECATED: No longer needed

docs/
└── migration/
    └── v5-unified-workflow.md          # NEW: Migration guide for consuming repos

README.md                               # MODIFIED: Update workflow documentation
```

**Structure Decision**: Single project structure. This is a workflow consolidation within the Process-PSModule framework. The unified workflow.yml will incorporate conditional logic to determine whether to execute release operations based on trigger context (PR event vs main branch push).

**Key Changes**:
1. **workflow.yml**: Enhanced with conditional Publish-Module and Publish-Site jobs
2. **CI.yml**: Marked as deprecated; will be removed in future release after migration period
3. **Publish-Module.yml** and **Publish-Site.yml**: Removed as separate files; logic inlined to workflow.yml
4. **Test workflows**: Updated to test unified workflow behavior
5. **Migration guide**: Comprehensive guide for consuming repositories to update their workflow references

## Phase 0: Outline & Research

### Research Questions

Based on the specification NEEDS CLARIFICATION markers and technical analysis:

1. **Publishing Target**: PowerShell Gallery (confirmed from existing workflow.yml)
2. **Versioning Strategy**: Semantic Versioning with PR labels (confirmed from Publish-PSModule@v2 usage)
3. **Manual Trigger Behavior**: Tests only (no releases) - inferred from existing workflow patterns
4. **Authentication**: PowerShell Gallery API key via secrets.APIKEY (confirmed)
5. **CI Time Limits**: No hard limits specified; existing workflow timeout defaults apply
6. **Conditional Execution Strategy**: Analyze existing workflow.yml and CI.yml differences

### Analysis: Current Workflow Differences

**CI.yml (Test-Only Mode)**:
- Triggers: `pull_request`, `workflow_dispatch`, `schedule`
- Permissions: `contents: read`, `pull-requests: write`, `statuses: write` (read-only, no releases)
- Jobs: Get-Settings → Build → Test → Results → Coverage
- **Missing**: Publish-Module, Publish-Site jobs

**workflow.yml (CI + Release Mode)**:
- Triggers: `workflow_call` (called by consuming repos)
- Permissions: `contents: write`, `pull-requests: write`, `statuses: write`, `pages: write`, `id-token: write`
- Jobs: Get-Settings → Build → Test → Results → Coverage → **Publish-Module** → **Publish-Site**
- **Publish-Module condition**: `github.event_name == 'pull_request'`
- **Publish-Site condition**: `github.event_name == 'pull_request' && github.event.pull_request.merged == true`

### Key Findings

**Decision**: Merge workflows by adding intelligent conditionals to workflow.yml

**Rationale**:
1. **CI.yml is already test-only**: It lacks publish jobs entirely
2. **workflow.yml has conditional publishing**: Publish jobs already check event context
3. **Minimal disruption**: Consuming repos already call workflow.yml; they won't need immediate changes
4. **Graceful deprecation**: CI.yml can be marked deprecated and removed later
5. **Trigger compatibility**: workflow.yml uses `workflow_call`, making it trigger-agnostic

**Alternatives Considered**:
1. ❌ **Create new workflow, deprecate both**: High migration burden; all repos must update simultaneously
2. ❌ **Merge into CI.yml**: Consuming repos call workflow.yml, not CI.yml; would break all repos
3. ✅ **Enhance workflow.yml conditionals**: Minimal breaking changes; clear migration path

### Conditional Execution Strategy

The unified workflow will use these conditions for publish jobs:

**Publish-Module**:
```yaml
if: |
  needs.Get-Settings.result == 'success' &&
  needs.Get-TestResults.result == 'success' &&
  needs.Get-CodeCoverage.result == 'success' &&
  !cancelled() &&
  (
    (github.event_name == 'pull_request' && github.event.pull_request.merged == true) ||
    (github.event_name == 'push' && github.ref == format('refs/heads/{0}', github.event.repository.default_branch))
  )
```

**Publish-Site**:
```yaml
if: |
  needs.Get-Settings.result == 'success' &&
  needs.Get-TestResults.result == 'success' &&
  needs.Get-CodeCoverage.result == 'success' &&
  needs.Build-Site.result == 'success' &&
  !cancelled() &&
  (
    (github.event_name == 'pull_request' && github.event.pull_request.merged == true) ||
    (github.event_name == 'push' && github.ref == format('refs/heads/{0}', github.event.repository.default_branch))
  )
```

**Rationale**:
- Publish only on merged PRs OR direct pushes to default branch
- Maintains existing behavior for current consumers
- Prevents accidental releases from unmerged PRs or non-default branches
- Compatible with manual triggers (workflow_dispatch) - tests run, releases skip

**Output**: Research complete - no unknowns remain

## Phase 1: Design & Contracts

*Prerequisites: research.md complete ✓*

### Design Entities

From the specification and research, the following entities are required:

1. **Workflow Execution Context**: Determines CI-only vs CI+Release mode
2. **Job Conditional Logic**: Implements intelligent skipping of publish jobs
3. **Trigger Event Classification**: Maps trigger types to execution modes
4. **Migration Path**: Defines consuming repository migration approach

### Workflow State Model (data-model.md)

The unified workflow operates in one of two modes based on trigger context:

**Mode 1: CI-Only** (Tests without Release)
- Trigger Events: Unmerged PRs, manual triggers, scheduled runs, non-default branch pushes
- Executed Jobs: Get-Settings → Build → Test → Results/Coverage
- Skipped Jobs: Publish-Module, Publish-Site
- Permissions: Can use read-only or write (write preferred for consistency)

**Mode 2: CI + Release** (Tests with Release)
- Trigger Events: Merged PRs to default branch, direct pushes to default branch
- Executed Jobs: Get-Settings → Build → Test → Results/Coverage → **Publish-Module → Publish-Site**
- Skipped Jobs: None (all jobs execute)
- Permissions: Requires write permissions (contents, pages, id-token)

### Workflow API Contract (contracts/workflow-api.yml)

The unified workflow maintains the same API surface as current workflow.yml:

**Inputs**: (Unchanged)
- Name, SettingsPath, Debug, Verbose, Version, Prerelease, WorkingDirectory

**Secrets**: (Unchanged)
- APIKey, TEST_APP_ENT_CLIENT_ID, TEST_APP_ENT_PRIVATE_KEY, etc.

**Outputs**: (Unchanged)
- None (workflow uses job artifacts and GitHub release artifacts)

**Breaking Changes**:
- CI.yml will be marked deprecated
- Consuming repositories using CI.yml should migrate to workflow.yml
- No immediate breaking changes for repositories already using workflow.yml

### Test Scenarios (quickstart.md)

The quickstart will serve as a migration guide with these scenarios:

1. **Scenario: PR Opened on Feature Branch**
   - Expected: CI tests run; no release operations
   - Validation: Check job skips in workflow log

2. **Scenario: PR Merged to Main Branch**
   - Expected: CI tests run; release operations execute
   - Validation: Check PowerShell Gallery and GitHub releases

3. **Scenario: Direct Push to Main Branch**
   - Expected: CI tests run; release operations execute
   - Validation: Same as merged PR

4. **Scenario: Manual Workflow Trigger**
   - Expected: CI tests run; release operations skipped
   - Validation: Check job skips in workflow log

5. **Scenario: Repository Migration**
   - Expected: Update workflow references from CI.yml to workflow.yml
   - Validation: Verify PR and release workflows function correctly

### Agent Context Update

After design is complete, update `.github/copilot-instructions.md`:

```markdown
## Recent Changes

- 001-merge-ci-release-workflows: Unified workflow.yml handles CI and release with conditional execution (v5.0.0)
```

**Output**: data-model.md, contracts/workflow-api.yml, quickstart.md, updated .github/copilot-instructions.md
## Phase 2: Task Planning Approach

*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:

The /tasks command will generate implementation tasks organized into these categories:

1. **Workflow Modification Tasks**:
   - Update workflow.yml conditional logic for Publish-Module
   - Update workflow.yml conditional logic for Publish-Site
   - Add deprecation warning to CI.yml header
   - Update workflow permissions documentation

2. **Test Infrastructure Tasks**:
   - Create test scenarios for CI-only mode validation
   - Create test scenarios for CI + Release mode validation
   - Update CI validation workflow to test unified workflow
   - Create manual testing procedures document

3. **Documentation Tasks**:
   - Create migration guide (docs/migration/v5-unified-workflow.md)
   - Update README.md with unified workflow documentation
   - Update workflow.yml inline documentation
   - Add deprecation notice to CI.yml

4. **Validation Tasks**:
   - Test PR opened scenario (CI-only mode)
   - Test PR merged scenario (CI + Release mode)
   - Test direct push to main scenario (CI + Release mode)
   - Test manual trigger scenario (CI-only mode)
   - Test scheduled run scenario (CI-only mode)

**Ordering Strategy**:

1. **Phase A: Documentation First** (TDD approach - define expected behavior)
   - Write migration guide
   - Update README documentation
   - Document test scenarios

2. **Phase B: Test Infrastructure** (Tests before implementation)
   - Create test validation workflows
   - Define manual testing procedures
   - Create test result validation criteria

3. **Phase C: Implementation** (Make tests pass)
   - Update workflow.yml conditionals
   - Deprecate CI.yml
   - Update workflow documentation

4. **Phase D: Validation** (Verify implementation)
   - Execute test scenarios
   - Validate migration guide accuracy
   - Test against real repository

**Parallel Execution Markers**: Tasks marked [P] can be executed in parallel

**Estimated Output**: 15-20 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation

*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following constitutional principles)
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

No constitutional violations identified. All constitutional principles are satisfied:

- ✅ Workflow-First Design: Implemented as reusable workflow modification
- ✅ Test-Driven Development: Test scenarios documented before implementation
- ✅ Platform Independence: No platform-specific changes required
- ✅ Quality Gates: Existing quality gates preserved
- ✅ Continuous Delivery: SemVer bump to v5.0.0 (Major breaking change)

## Progress Tracking

*This checklist is updated during execution flow*

**Phase Status**:

- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved (via research phase)
- [x] Complexity deviations documented (none identified)

**Artifacts Generated**:

- [x] research.md (Phase 0)
- [x] data-model.md (Phase 1)
- [x] contracts/workflow-api.md (Phase 1)
- [x] quickstart.md (Phase 1 - serves as migration guide)
- [x] .github/copilot-instructions.md (updated)

---
*Based on Constitution - See `.specify/memory/constitution.md`*
