# Research: Unified CI/CD Workflow

**Feature**: 001-unified-workflow
**Date**: 2025-10-02

## Research Questions

### 1. GitHub Actions Conditional Execution Patterns

**Decision**: Use `if` conditions with `github.event` context variables to control job execution

**Rationale**:
- GitHub Actions provides native conditional execution via `if` expressions
- Event context (`github.event_name`, `github.event.pull_request.merged`) reliably differentiates PR vs merge contexts
- Conditions can be evaluated at job level, preventing unnecessary job execution entirely
- Well-documented pattern used across GitHub Actions ecosystem

**Alternatives Considered**:
- **Separate workflows with different triggers**: Rejected because it maintains the two-file problem we're trying to solve
- **Dynamic workflow generation**: Rejected due to complexity and maintenance burden
- **Workflow dispatch with manual selection**: Rejected because it removes automation

**Implementation Pattern**:
```yaml
on:
  pull_request:
    branches: [main]
    types: [opened, reopened, synchronize, closed]

jobs:
  test:
    runs-on: ubuntu-latest
    steps: [...]

  publish:
    if: github.event_name == 'pull_request' && github.event.pull_request.merged == true
    needs: test
    runs-on: ubuntu-latest
    steps: [...]
```

### 2. Concurrency Control Strategy

**Decision**: Use GitHub Actions concurrency groups with `cancel-in-progress: true` for PR builds, and `cancel-in-progress: false` for main branch builds

**Rationale**:
- Concurrency groups automatically cancel stale workflow runs when new commits are pushed
- PR builds can safely cancel previous runs (new commits supersede old ones)
- Main branch builds should complete to ensure releases aren't interrupted
- Built-in GitHub Actions feature, no external dependencies

**Alternatives Considered**:
- **Queue-based approach**: Rejected due to increased wait times and complexity
- **No concurrency control**: Rejected due to resource waste and confusion from multiple simultaneous builds
- **External orchestration**: Rejected due to additional dependencies and complexity

**Implementation Pattern**:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != format('refs/heads/{0}', github.event.repository.default_branch) }}
```

### 3. Authentication and Secrets Management

**Decision**: Continue using GitHub repository secrets with `APIKey` secret for PowerShell Gallery publishing

**Rationale**:
- Consistent with existing workflow patterns in Process-PSModule
- Repository secrets scope is appropriate (per-repo API keys)
- Simple to configure and maintain
- Well-understood by consuming repository maintainers
- Clarification session confirmed this approach

**Alternatives Considered**:
- **Organization secrets**: Rejected because different repos may use different API keys
- **OIDC/Federated Identity**: Rejected because PowerShell Gallery doesn't support OIDC yet
- **Environment secrets**: Rejected due to added complexity for simple use case

**Implementation**: No changes required to existing secrets infrastructure

### 4. Notification Strategy for Failures

**Decision**: Rely on GitHub's default notification mechanisms (workflow status, email, UI)

**Rationale**:
- Clarification session confirmed no additional notification systems needed
- GitHub already provides email, mobile, and UI notifications for workflow failures
- Reduces dependencies and complexity
- Consuming repositories can add their own notification integrations if desired

**Alternatives Considered**:
- **Slack/Teams webhooks**: Rejected as unnecessary; users can add via GitHub Actions marketplace if needed
- **GitHub Issues auto-creation**: Rejected due to noise and management overhead
- **PR comments on every failure**: Rejected due to notification spam

**Implementation**: Document that maintainers should ensure their GitHub notification settings are configured

### 5. Migration Path and Breaking Change Communication

**Decision**: Document as major version bump with clear migration guide in README and release notes

**Rationale**:
- Deletion of CI.yml is a breaking change requiring consuming repository updates
- External automation may reference CI.yml and must be updated
- Clear documentation reduces confusion and adoption friction
- Major version bump signals breaking change per SemVer

**Migration Steps**:
1. Update consuming repository workflow file references from CI.yml to workflow.yml
2. Delete CI.yml from consuming repositories
3. Update any external CI/CD integrations or scripts
4. Test workflow execution in consuming repositories
5. Merge and verify

**Communication Channels**:
- Release notes with breaking change warning
- README documentation update
- Migration guide in docs/
- GitHub issue/discussion for support

### 6. Backward Compatibility Considerations

**Decision**: Maintain all existing inputs, outputs, and behavior of both workflows; only change is consolidation

**Rationale**:
- Consuming repositories should see identical behavior post-migration
- Test execution, publishing logic, and configuration remain unchanged
- Only the trigger source (single vs dual workflow files) changes
- Reduces risk and testing burden

**Preserved Elements**:
- All workflow inputs (Name, SettingsPath, Debug, Verbose, etc.)
- All secrets (APIKey, TEST_* secrets)
- All permissions (contents, pull-requests, statuses, pages, id-token)
- All job execution order and dependencies
- All test matrix strategies
- All conditional skips (via Settings.Build.*.Skip flags)

### 7. Testing Strategy for Unified Workflow

**Decision**: Use existing CI validation workflow test pattern with new test scenarios for PR and merge contexts

**Rationale**:
- Process-PSModule already has Workflow-Test-Default and Workflow-Test-WithManifest patterns
- Extend these patterns to validate unified workflow behavior
- Test both PR-only execution and merge-triggered publishing
- Leverage existing test repositories (srcTestRepo, srcWithManifestTestRepo)

**Test Scenarios**:
1. PR opened → verify tests run, publishing skipped
2. PR synchronized → verify tests run, publishing skipped
3. PR merged → verify tests run, publishing executes
4. Test failure on PR → verify workflow fails, merge blocked
5. Test failure on merge → verify publishing skipped
6. Concurrency → verify old runs cancelled when new commits pushed

**Implementation**: Add new test workflow files similar to existing Workflow-Test-*.yml patterns

## Dependencies

### GitHub Actions Features Required
- `workflow_call` trigger (existing)
- Event context variables (existing)
- Concurrency groups (existing, GitHub Actions core feature)
- Conditional job execution with `if` (existing)
- Job dependencies with `needs` (existing)

### PSModule Composite Actions Used
- PSModule/GitHub-Script@v1
- PSModule/Install-PSModuleHelpers@v1
- All existing actions called by workflow.yml and CI.yml

### External Services
- PowerShell Gallery API (existing, requires APIKey secret)
- GitHub Pages (existing, for docs publishing)

## Performance Considerations

### Workflow Execution Time
- **Target**: Under 10 minutes for typical module (unchanged from existing)
- **Factors**: Test matrix parallelization, build caching, test execution time
- **Optimization**: No changes needed; consolidation doesn't affect performance

### Resource Usage
- **Benefit**: Reduced workflow runs (single workflow vs. potentially two separate runs)
- **Tradeoff**: None; same jobs execute, just orchestrated from one workflow file

## Security Considerations

### Secrets Exposure
- **Risk**: Secrets passed to workflow_call from consuming repositories
- **Mitigation**: Same pattern as existing; no new exposure
- **Required Secrets**: APIKey (required), TEST_* secrets (optional)

### Permission Scope
- **Current**: Contents, pull-requests, statuses, pages, id-token (write)
- **Change**: None; unified workflow maintains same permissions
- **Justification**: Required for checkout, PR comments, status updates, Pages deployment, and release creation

### Workflow Security
- **Branch Protection**: Consuming repositories should protect main branch and require PR reviews
- **Status Checks**: Unified workflow should be required status check
- **Approval**: Consider requiring approval for publishing jobs (can be added via environments)

## Technical Constraints

### GitHub Actions Limitations
- **Workflow Call Depth**: Limited to 4 levels (current usage: 2 levels, within limit)
- **Job Dependencies**: Jobs can only depend on jobs in same workflow (design accounts for this)
- **Matrix Size**: Maximum 256 jobs per matrix (current usage well below this)

### PowerShell Gallery Constraints
- **API Rate Limits**: Publishing rate limits exist but not typically hit
- **Version Uniqueness**: Cannot republish same version (handled by version bump logic)

### Consuming Repository Impact
- **Required Action**: Delete CI.yml, update references (breaking change)
- **Configuration**: No changes to PSModule.yml configuration required
- **Testing**: Consuming repos must verify workflow execution post-migration

## Open Questions (Resolved)

All open questions were resolved through clarification session (2025-10-02):
- ✅ Notification strategy: GitHub default mechanisms
- ✅ Retry mechanism: Manual re-run of entire workflow
- ✅ Authentication: GitHub repository secret with API key
- ✅ Composite actions: PSModule workflow composite actions
- ✅ Concurrency: Use concurrency groups with cancel-in-progress

## References

- [GitHub Actions Documentation: Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions: Reusing Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [GitHub Actions: Concurrency](https://docs.github.com/en/actions/using-jobs/using-concurrency)
- [PowerShell Gallery API Documentation](https://learn.microsoft.com/en-us/powershell/gallery/concepts/publishing-guidelines)
- [Process-PSModule Constitution](../../.specify/memory/constitution.md)
