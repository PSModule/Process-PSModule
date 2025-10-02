# Data Model: Unified CI and Release Workflow

**Feature**: 001-merge-ci-release-workflows
**Date**: 2025-10-02

## Workflow Execution Modes

The unified workflow operates in one of two execution modes, determined dynamically at runtime based on trigger context.

### Mode 1: CI-Only (Test-Only Execution)

**Purpose**: Validate code changes without publishing releases

**Trigger Conditions**:
- Pull request opened, synchronized, or reopened (not merged)
- Manual workflow trigger (`workflow_dispatch`)
- Scheduled workflow runs (`schedule`)
- Push to non-default branch

**Job Execution**:
```
Get-Settings
├── Build-Module
│   ├── Build-Docs
│   ├── Build-Site
│   ├── Test-SourceCode (matrix: multiple OS)
│   ├── Lint-SourceCode (matrix: multiple OS)
│   ├── Test-Module
│   ├── BeforeAll-ModuleLocal
│   ├── Test-ModuleLocal (matrix: ubuntu, windows, macos)
│   ├── AfterAll-ModuleLocal
│   ├── Get-TestResults
│   └── Get-CodeCoverage
```

**Skipped Jobs**:
- Publish-Module
- Publish-Site

**Permissions Required**:
- `contents: write` (for checkout and tags)
- `pull-requests: write` (for PR comments)
- `statuses: write` (for linter status)
- Note: Publish permissions not required but maintained for consistency

**Exit Criteria**:
- All test jobs complete (success or failure)
- Test results reported
- Code coverage analyzed
- Workflow exits without release operations

### Mode 2: CI + Release (Full Pipeline Execution)

**Purpose**: Validate code changes and publish releases

**Trigger Conditions**:
- Pull request merged to default branch (`github.event.pull_request.merged == true`)
- Direct push to default branch (`github.ref == refs/heads/main`)

**Job Execution**:
```
Get-Settings
├── Build-Module
│   ├── Build-Docs
│   ├── Build-Site
│   ├── Test-SourceCode (matrix: multiple OS)
│   ├── Lint-SourceCode (matrix: multiple OS)
│   ├── Test-Module
│   ├── BeforeAll-ModuleLocal
│   ├── Test-ModuleLocal (matrix: ubuntu, windows, macos)
│   ├── AfterAll-ModuleLocal
│   ├── Get-TestResults
│   ├── Get-CodeCoverage
│   ├── Publish-Module ← EXECUTES
│   └── Publish-Site ← EXECUTES
```

**Skipped Jobs**: None (all jobs execute if tests pass)

**Permissions Required**:
- `contents: write` (for checkout, tags, and GitHub releases)
- `pull-requests: write` (for PR comments)
- `statuses: write` (for linter status)
- `pages: write` (for GitHub Pages deployment)
- `id-token: write` (for deployment verification)

**Exit Criteria**:
- All test jobs complete successfully
- Module published to PowerShell Gallery
- Documentation site deployed to GitHub Pages
- GitHub release created with artifacts

## Workflow State Transitions

```
[Workflow Triggered]
        |
        v
[Get-Settings] → Determine configuration
        |
        v
[Build & Test Jobs] → Execute always (both modes)
        |
        v
[Test Results Check]
        |
        ├─ Tests Failed → Exit (no publishing)
        |
        └─ Tests Passed
                |
                v
        [Evaluate Trigger Context]
                |
                ├─ Unmerged PR / Manual / Scheduled → Skip Publishing (CI-Only Mode)
                |
                └─ Merged PR / Main Push → Execute Publishing (CI + Release Mode)
                        |
                        v
                [Publish-Module & Publish-Site]
                        |
                        v
                [Release Complete]
```

## Conditional Logic Entities

### Entity: TriggerContext

**Purpose**: Encapsulates GitHub event information used for conditional execution

**Attributes**:
- `event_name`: GitHub event type (pull_request, push, workflow_dispatch, schedule)
- `is_pull_request`: Boolean indicating PR event
- `is_merged`: Boolean indicating merged PR (only relevant for pull_request events)
- `ref`: Git reference (branch/tag) for push events
- `default_branch`: Repository default branch name

**Derived Properties**:
- `is_ci_only_mode`: `!is_merged || event_name not in [pull_request, push]`
- `is_release_mode`: `(is_pull_request && is_merged) || (event_name == push && ref == default_branch)`

**Example Values**:

| Scenario | event_name | is_pull_request | is_merged | ref | is_release_mode |
|----------|------------|----------------|-----------|-----|----------------|
| PR opened | pull_request | true | false | N/A | false (CI-only) |
| PR merged | pull_request | true | true | N/A | true (Release) |
| Push to main | push | false | N/A | refs/heads/main | true (Release) |
| Push to feature | push | false | N/A | refs/heads/feature-x | false (CI-only) |
| Manual trigger | workflow_dispatch | false | N/A | N/A | false (CI-only) |
| Scheduled run | schedule | false | N/A | N/A | false (CI-only) |

### Entity: JobExecutionPlan

**Purpose**: Defines which jobs execute based on trigger context and test results

**Attributes**:
- `trigger_context`: TriggerContext instance
- `test_results_passed`: Boolean from Get-TestResults job
- `code_coverage_passed`: Boolean from Get-CodeCoverage job
- `build_site_passed`: Boolean from Build-Site job
- `workflow_cancelled`: Boolean indicating workflow cancellation

**Methods**:
- `should_publish_module()`: Returns true if Publish-Module should execute
- `should_publish_site()`: Returns true if Publish-Site should execute

**Logic**:

```yaml
should_publish_module():
  return (
    test_results_passed &&
    code_coverage_passed &&
    !workflow_cancelled &&
    trigger_context.is_release_mode
  )

should_publish_site():
  return (
    test_results_passed &&
    code_coverage_passed &&
    build_site_passed &&
    !workflow_cancelled &&
    trigger_context.is_release_mode
  )
```

### Entity: WorkflowConfiguration

**Purpose**: Settings that control workflow behavior (from .github/PSModule.yml)

**Attributes**:
- `skip_build`: Boolean to skip Build-Module job
- `skip_tests`: Boolean to skip test jobs
- `skip_publish`: Boolean to skip publish jobs (overrides trigger context)
- `auto_patching`: Boolean for automatic patch version bumps
- `prerelease_increment`: Boolean for incremental prerelease versioning

**Usage**: Allows consuming repositories to override default behavior

## Migration State Model

### Repository Migration States

**State 1: Legacy (Using CI.yml)**
- Repository has `.github/workflows/CI.yml` for PR validation
- Repository has `.github/workflows/Process-PSModule.yml` calling workflow.yml for releases
- Two separate workflow files to maintain

**State 2: Transitional (Adopting Unified)**
- Repository updates `.github/workflows/Process-PSModule.yml` to use workflow.yml for all events
- CI.yml remains but is unused (safety net)
- Single workflow handles CI and release

**State 3: Unified (Complete Migration)**
- Repository removes `.github/workflows/CI.yml` entirely
- Single `.github/workflows/Process-PSModule.yml` handles all events
- Optimal state: one workflow file to maintain

### Migration Validation

**Validation Checklist**:
1. ✅ PR opened → CI tests run, no publish
2. ✅ PR merged → CI tests run, publish succeeds
3. ✅ Direct push to main → CI tests run, publish succeeds
4. ✅ Manual trigger → CI tests run, no publish
5. ✅ Feature branch push → No workflow trigger (expected)

## Backward Compatibility

### Existing workflow.yml Consumers

**Impact**: Minimal - existing behavior preserved

**Changes Required**: None immediately

**Recommended Updates**:
1. Review trigger conditions in consuming repository workflows
2. Update documentation referencing CI.yml
3. Plan removal of CI.yml references

### Existing CI.yml Consumers

**Impact**: CI.yml marked deprecated; functionality unchanged

**Changes Required**: Migrate to workflow.yml during v5.x timeframe

**Migration Path**:
1. Update workflow file to call workflow.yml instead of CI.yml
2. Test PR and release workflows
3. Remove CI.yml reference after validation
4. Remove local CI.yml file (optional during v5.x)

## Version Compatibility Matrix

| Process-PSModule Version | Unified Workflow | CI.yml Support | Breaking Changes |
|-------------------------|------------------|----------------|-----------------|
| v4.x (current) | ❌ No | ✅ Yes | N/A |
| v5.0 (this feature) | ✅ Yes | ⚠️ Deprecated | Yes - CI.yml deprecated |
| v6.0 (future) | ✅ Yes | ❌ Removed | Yes - CI.yml removed entirely |

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ GitHub Trigger Event                                         │
│ (PR opened/merged, push, workflow_dispatch, schedule)       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────────────────┐
│ Get-Settings Job                                             │
│ - Load .github/PSModule.yml                                  │
│ - Parse configuration                                        │
│ - Output settings JSON                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────────────────┐
│ Build & Test Phase (Always Executes)                        │
│ - Build-Module, Build-Docs, Build-Site                      │
│ - Test-SourceCode, Lint-SourceCode, Test-Module             │
│ - Test-ModuleLocal (matrix: 3 OS)                           │
│ - Get-TestResults, Get-CodeCoverage                          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────────────────┐
│ Conditional Evaluation                                       │
│ - Check: Tests passed?                                       │
│ - Check: Trigger context (merged/push to main?)            │
│ - Check: Workflow not cancelled?                            │
└─────┬──────────────────────────────────┬────────────────────┘
      │                                  │
      v                                  v
┌─────────────────┐              ┌──────────────────────────┐
│ CI-Only Mode    │              │ CI + Release Mode        │
│ Skip Publishing │              │ Execute Publishing       │
│ Exit            │              │                          │
└─────────────────┘              │ - Publish-Module         │
                                 │ - Publish-Site           │
                                 │ - Create GitHub Release  │
                                 └──────────────────────────┘
```

## Conclusion

The workflow state model is deterministic and based on observable trigger context. The conditional logic ensures safe, predictable behavior across all trigger scenarios while maintaining a single workflow file.
