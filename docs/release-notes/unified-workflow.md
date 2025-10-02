# Release Notes: Unified CI/CD Workflow (v4.0.0)

**Feature ID**: 001-unified-workflow
**Release Date**: 2025-10-02
**Type**: Breaking Change

## Summary

The `CI.yml` and `workflow.yml` files have been consolidated into a single unified workflow file (`.github/workflows/workflow.yml`). This change simplifies the CI/CD pipeline, reduces duplication, and provides clearer conditional logic for test execution and publishing.

## Breaking Changes

### Removed Files

- **`.github/workflows/CI.yml`** - Deleted (functionality merged into `workflow.yml`)

### Migration Required

**For Consuming Repositories**:

If your repository directly references `CI.yml`:
1. Update all workflow files that call `CI.yml` to use `workflow.yml` instead
2. Update any documentation that references `CI.yml`
3. No code changes required - same inputs/secrets/behavior

**Example Migration**:

Before:
```yaml
jobs:
  CI:
    uses: PSModule/Process-PSModule/.github/workflows/CI.yml@v3
    secrets: inherit
```

After:
```yaml
jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v4
    secrets: inherit
```

See [docs/unified-workflow-migration.md](../unified-workflow-migration.md) for detailed migration instructions.

## What Changed

### Unified Workflow Structure

The new unified workflow (`workflow.yml`) now handles:
- **Test Execution**: All test jobs execute on every PR event (open, synchronize, reopened)
- **Conditional Publishing**: Publishing only occurs when a PR is merged to the default branch
- **Concurrency Control**: Automatic cancellation of previous runs when PR is updated (non-default branch only)

### Key Features

1. **Single Source of Truth**
   - All CI/CD logic in one file (`.github/workflows/workflow.yml`)
   - Easier to understand and maintain
   - Reduced duplication

2. **Conditional Publishing**
   - Publish-Module and Publish-Site jobs only run when:
     - PR is merged to default branch (`github.event.pull_request.merged == true`)
     - All tests pass
     - Settings.Publish.*.Skip flags are false
   - Publishing is **skipped** for:
     - Open PRs
     - PR updates (synchronize)
     - Draft PRs

3. **Concurrency Groups**
   - Group: `${{ github.workflow }}-${{ github.ref }}`
   - Cancel-in-progress: `true` for non-default branches, `false` for main
   - Prevents duplicate workflow runs on PR updates

4. **BeforeAll/AfterAll Test Support**
   - Optional setup and teardown scripts for test environments
   - `tests/BeforeAll.ps1`: Runs once before all test matrix jobs
   - `tests/AfterAll.ps1`: Runs once after all test matrix jobs complete
   - Ideal for managing external test resources (databases, APIs, infrastructure)

### Workflow Execution Order

1. **Get-Settings** - Configuration loading
2. **Build-Module** - Module compilation
3. **Build-Docs** - Documentation generation
4. **Build-Site** - Static site generation
5. **Test-SourceCode** - Parallel source validation
6. **Lint-SourceCode** - Parallel code quality checks
7. **Test-Module** - Framework validation
8. **BeforeAll-ModuleLocal** - Setup test environment (optional)
9. **Test-ModuleLocal** - Pester tests across platform matrix
10. **AfterAll-ModuleLocal** - Teardown test environment (optional)
11. **Get-TestResults** - Test aggregation
12. **Get-CodeCoverage** - Coverage analysis
13. **Publish-Module** - PowerShell Gallery publishing (if merged + tests pass)
14. **Publish-Site** - GitHub Pages deployment (if merged + tests pass)

## Migration Checklist

For repository maintainers migrating to v4:

- [ ] Update workflow references from `CI.yml` to `workflow.yml`
- [ ] Update documentation that references `CI.yml`
- [ ] Update version tag from `@v3` to `@v4` in workflow calls
- [ ] Review conditional publishing behavior (only on PR merge)
- [ ] Test workflow with PR open/update/merge scenarios
- [ ] Verify publishing still works after PR merge
- [ ] Optional: Add `tests/BeforeAll.ps1` and `tests/AfterAll.ps1` if external test resources needed

## Validation Steps

### Scenario 1: PR Opens → Tests Execute, Publishing Skipped

1. Create branch, make changes, open PR
2. Verify workflow executes all test jobs
3. Verify Publish-Module and Publish-Site are **skipped**

### Scenario 2: PR Updated → Tests Re-Execute, Previous Run Cancelled

1. Push additional commit to open PR
2. Verify previous workflow run is **cancelled**
3. Verify new workflow run executes tests

### Scenario 3: PR Merged → Tests Execute, Publishing Executes

1. Merge PR to default branch
2. Verify workflow executes all test jobs
3. Verify Publish-Module and Publish-Site **execute** (if tests pass)
4. Verify module published to PowerShell Gallery
5. Verify site deployed to GitHub Pages

### Scenario 4: Test Failure → Workflow Fails, Publishing Skipped

1. Create PR with failing test
2. Verify workflow fails
3. Verify Publish-Module and Publish-Site are **skipped**

See [specs/001-unified-workflow/quickstart.md](../../specs/001-unified-workflow/quickstart.md) for detailed validation instructions.

## Performance

- **Target**: Workflow execution under 10 minutes
- **Benefit**: Reduced overhead from single workflow file
- **Matrix Testing**: Cross-platform tests (Linux, macOS, Windows) remain unchanged

## References

- **Feature Specification**: [specs/001-unified-workflow/spec.md](../../specs/001-unified-workflow/spec.md)
- **Implementation Plan**: [specs/001-unified-workflow/plan.md](../../specs/001-unified-workflow/plan.md)
- **Migration Guide**: [docs/unified-workflow-migration.md](../unified-workflow-migration.md)
- **Quickstart Guide**: [specs/001-unified-workflow/quickstart.md](../../specs/001-unified-workflow/quickstart.md)
- **Test Plan**: [specs/001-unified-workflow/test-plan.md](../../specs/001-unified-workflow/test-plan.md)

## Support

For issues or questions:
1. Review the migration guide: [docs/unified-workflow-migration.md](../unified-workflow-migration.md)
2. Check quickstart scenarios: [specs/001-unified-workflow/quickstart.md](../../specs/001-unified-workflow/quickstart.md)
3. Open an issue in the Process-PSModule repository

---

**Version**: 4.0.0
**Author**: PSModule Team
**Date**: 2025-10-02
