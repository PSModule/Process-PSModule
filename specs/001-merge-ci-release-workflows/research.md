# Research: Unified CI and Release Workflow

**Feature**: 001-merge-ci-release-workflows
**Date**: 2025-10-02
**Status**: Complete

## Research Questions Resolved

### 1. Publishing Target

**Decision**: PowerShell Gallery

**Rationale**:
- Existing workflow.yml uses `PSModule/Publish-PSModule@v2` action
- Action publishes to PowerShell Gallery via `APIKey` secret
- All PSModule repositories publish to PowerShell Gallery
- No private feed or alternative registry support currently exists

**Alternatives Considered**:
- Private feeds (NuGet, Azure Artifacts): Not currently used by PSModule repositories
- Multiple registries: Would add complexity without current need

### 2. Versioning Strategy

**Decision**: Semantic Versioning with PR labels

**Rationale**:
- Existing Publish-PSModule action uses PR labels for version bumping
- Labels: `major`, `minor`, `patch` (or configured alternatives)
- SemVer 2.0.0 compliant version increments
- Prerelease support via `prerelease` label
- AutoPatching option for automatic patch bumps

**Alternatives Considered**:
- Date-based versioning: Available via DatePrereleaseFormat but not default
- Manual version tags: Less automated, more error-prone

### 3. Manual Trigger Behavior

**Decision**: Tests only (no releases)

**Rationale**:
- Manual triggers (`workflow_dispatch`) should not automatically publish
- Releases should only occur from PR merges or direct pushes to main
- Prevents accidental releases from manual workflow runs
- Consistent with CI-only behavior for non-release triggers

**Alternatives Considered**:
- Allow releases on manual trigger: Risky; could lead to unintended publishes
- Add manual trigger input for release control: Adds complexity without clear benefit

### 4. Authentication

**Decision**: PowerShell Gallery API key via `secrets.APIKEY`

**Rationale**:
- Existing workflow requires `APIKey` secret
- PowerShell Gallery publishing requires API key authentication
- GitHub token (`GITHUB_TOKEN`) used for GitHub Releases
- No additional authentication mechanisms needed

**Alternatives Considered**:
- Service principal / Azure AD: Not applicable for PowerShell Gallery
- Multiple API keys: Not needed; single gallery per repository

### 5. CI Time Limits

**Decision**: Use GitHub Actions default timeouts (6 hours per job, 72 hours per workflow)

**Rationale**:
- No hard time limits specified in existing workflows
- Current workflows complete in 5-15 minutes typically
- GitHub Actions default timeouts are sufficient
- Individual jobs can be configured with custom timeouts if needed

**Alternatives Considered**:
- Enforce specific time limits: Not necessary; existing workflows perform adequately
- Progressive timeout warnings: Adds complexity without clear benefit

## Workflow Consolidation Analysis

### Current Workflow Architecture

**CI.yml** (Test-Only Mode):
```yaml
Triggers: pull_request, workflow_dispatch, schedule
Permissions: contents: read, pull-requests: write, statuses: write
Jobs:
  - Get-Settings
  - Build-Module
  - Build-Docs
  - Build-Site
  - Test-SourceCode
  - Lint-SourceCode
  - Test-Module
  - BeforeAll-ModuleLocal
  - Test-ModuleLocal
  - AfterAll-ModuleLocal
  - Get-TestResults
  - Get-CodeCoverage
Missing: Publish-Module, Publish-Site
```

**workflow.yml** (CI + Release Mode):
```yaml
Triggers: workflow_call (called by consuming repositories)
Permissions: contents: write, pull-requests: write, statuses: write, pages: write, id-token: write
Jobs:
  - Get-Settings
  - Build-Module
  - Build-Docs
  - Build-Site
  - Test-SourceCode
  - Lint-SourceCode
  - Test-Module
  - BeforeAll-ModuleLocal
  - Test-ModuleLocal
  - AfterAll-ModuleLocal
  - Get-TestResults
  - Get-CodeCoverage
  - Publish-Site (conditional on merged PR)
  - Publish-Module (conditional on PR event)
```

### Key Differences Identified

1. **Triggers**: CI.yml has explicit triggers; workflow.yml uses `workflow_call`
2. **Permissions**: workflow.yml has write permissions for releases; CI.yml is read-only
3. **Publish Jobs**: Only workflow.yml includes Publish-Module and Publish-Site
4. **Conditionals**: workflow.yml already has conditional publishing logic

### Consolidation Strategy

**Decision**: Enhance workflow.yml conditional logic; deprecate CI.yml

**Rationale**:
1. **Minimal Breaking Changes**: Consuming repositories already call workflow.yml
2. **Clear Migration Path**: CI.yml can remain for backward compatibility during migration
3. **Existing Conditionals**: workflow.yml already has publish conditionals; just need refinement
4. **Permission Safety**: Unified workflow maintains appropriate permissions for both modes

**Implementation Approach**:

1. **Update Publish-Module condition**:
   - Current: `github.event_name == 'pull_request'`
   - New: `(github.event_name == 'pull_request' && github.event.pull_request.merged == true) || (github.event_name == 'push' && github.ref == default_branch)`
   
2. **Update Publish-Site condition**:
   - Current: `github.event_name == 'pull_request' && github.event.pull_request.merged == true`
   - New: Same as Publish-Module (add push trigger support)

3. **Maintain existing job dependencies**: No changes to job execution order

4. **Preserve permissions**: Unified workflow maintains write permissions

### Conditional Execution Logic

**Publish-Module Condition**:
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

**Rationale**:
- Tests must pass (Get-TestResults, Get-CodeCoverage success)
- Workflow must not be cancelled
- Publish only on:
  - Merged pull requests to default branch, OR
  - Direct pushes to default branch
- Skips on:
  - Unmerged pull requests
  - Manual triggers (workflow_dispatch)
  - Scheduled runs
  - Pushes to non-default branches

**Publish-Site Condition**:
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

**Rationale**: Same as Publish-Module, plus requires successful Build-Site job

## Alternatives Considered

### Alternative 1: Create New Workflow, Deprecate Both

**Approach**: Create workflow-v5.yml, mark both CI.yml and workflow.yml deprecated

**Pros**:
- Clean slate; no technical debt
- Clear versioning signal (v5)

**Cons**:
- High migration burden; all consuming repositories must update simultaneously
- Increased risk of breakage across multiple repositories
- Longer migration timeline
- Two deprecated workflows to maintain during transition

**Verdict**: ❌ Rejected due to high migration risk and coordination burden

### Alternative 2: Merge into CI.yml

**Approach**: Enhance CI.yml with release logic; deprecate workflow.yml

**Pros**:
- CI.yml already has explicit triggers
- Clear naming for "CI + Release"

**Cons**:
- All consuming repositories call workflow.yml, not CI.yml
- Would break every consuming repository immediately
- Requires simultaneous updates across all repositories
- Violates least-surprise principle (existing references break)

**Verdict**: ❌ Rejected due to immediate breakage of all consuming repositories

### Alternative 3: Enhance workflow.yml (SELECTED)

**Approach**: Add refined conditionals to workflow.yml; mark CI.yml deprecated

**Pros**:
- Minimal breaking changes; consuming repos continue working
- Graceful migration path with backward compatibility period
- workflow.yml already has conditional logic foundation
- Clear deprecation path for CI.yml

**Cons**:
- CI.yml remains in codebase during migration (minor maintenance burden)
- Slightly less obvious from naming that workflow.yml handles both CI and release

**Verdict**: ✅ Selected - balances functionality with migration safety

## Migration Considerations

### Consuming Repository Impact

**Immediate Changes Required**: None (if using workflow.yml already)

**Recommended Changes**:
1. Update documentation referencing CI.yml
2. Remove any direct CI.yml references (if present)
3. Consolidate workflow triggers in repository workflows
4. Review and update workflow permissions if needed

### Migration Timeline

**Phase 1** (v5.0.0 release):
- Unified workflow.yml released
- CI.yml marked deprecated with warning comment
- Migration guide published

**Phase 2** (v5.x maintenance period - 6+ months):
- Support both workflow patterns
- Respond to migration issues
- Update consuming repositories incrementally

**Phase 3** (v6.0.0 release):
- Remove CI.yml entirely
- Complete documentation cleanup
- Final migration verification

## Conclusion

All research questions resolved. The unified workflow consolidation strategy is clear:
- Enhance workflow.yml with refined conditional logic
- Deprecate CI.yml with graceful migration period
- Maintain backward compatibility during transition
- Provide comprehensive migration guide for consuming repositories

**Ready for Phase 1: Design & Contracts**
