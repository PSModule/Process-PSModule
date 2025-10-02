# Workflow Contract: Unified workflow.yml

**Feature**: 001-unified-workflow
**Date**: 2025-10-02

## Overview

This contract defines the expected structure and behavior of the unified workflow.yml file that consolidates CI.yml and workflow.yml functionality.

## Workflow Definition Contract

### Required Top-Level Properties

```yaml
name: Process-PSModule

on:
  workflow_call:
    secrets: {...}
    inputs: {...}

permissions: {...}

concurrency:
  group: {...}
  cancel-in-progress: {...}

jobs: {...}
```

### Trigger Configuration (on)

**Type**: `workflow_call`

**Required Secrets**:
| Secret | Type | Required | Description |
|--------|------|----------|-------------|
| APIKey | string | true | PowerShell Gallery API key |
| TEST_APP_ENT_CLIENT_ID | string | false | Enterprise App client ID |
| TEST_APP_ENT_PRIVATE_KEY | string | false | Enterprise App private key |
| TEST_APP_ORG_CLIENT_ID | string | false | Organization App client ID |
| TEST_APP_ORG_PRIVATE_KEY | string | false | Organization App private key |
| TEST_USER_ORG_FG_PAT | string | false | Fine-grained PAT (org scope) |
| TEST_USER_USER_FG_PAT | string | false | Fine-grained PAT (user scope) |
| TEST_USER_PAT | string | false | Classic PAT |

**Required Inputs**:
| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| Name | string | false | (repo name) | Module name |
| SettingsPath | string | false | .github/PSModule.yml | Settings file path |
| Debug | boolean | false | false | Enable debug output |
| Verbose | boolean | false | false | Enable verbose output |
| Version | string | false | '' | GitHub module version |
| Prerelease | boolean | false | false | Use prerelease GitHub module |
| WorkingDirectory | string | false | '.' | Repository root path |

### Permissions

**Required Permissions**:
```yaml
permissions:
  contents: write       # Repository operations, releases
  pull-requests: write  # PR comments
  statuses: write       # Workflow status updates
  pages: write          # GitHub Pages deployment
  id-token: write       # Deployment verification
```

### Concurrency Configuration

**Required Structure**:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != format('refs/heads/{0}', github.event.repository.default_branch) }}
```

**Behavior**:
- PR builds: `cancel-in-progress` = `true` (new commits cancel old runs)
- Main branch builds: `cancel-in-progress` = `false` (runs complete)

### Job Execution Order

**Required Jobs** (in dependency order):

1. **Get-Settings** (always runs)
   - Uses: `./.github/workflows/Get-Settings.yml`
   - No dependencies
   - Outputs: Settings JSON, test matrices

2. **Build-Module** (conditional)
   - Uses: `./.github/workflows/Build-Module.yml`
   - Depends on: Get-Settings
   - Condition: `Settings.Build.Module.Skip != true`

3. **Build-Docs** (conditional)
   - Uses: `./.github/workflows/Build-Docs.yml`
   - Depends on: Get-Settings, Build-Module
   - Condition: `Settings.Build.Docs.Skip != true`

4. **Build-Site** (conditional)
   - Uses: `./.github/workflows/Build-Site.yml`
   - Depends on: Get-Settings, Build-Docs
   - Condition: `Settings.Build.Site.Skip != true`

5. **Test-SourceCode** (matrix, conditional)
   - Uses: `./.github/workflows/Test-SourceCode.yml`
   - Depends on: Get-Settings
   - Condition: `SourceCodeTestSuites != '[]'`
   - Strategy: Matrix based on test suite configuration

6. **Lint-SourceCode** (matrix, conditional)
   - Uses: `./.github/workflows/Lint-SourceCode.yml`
   - Depends on: Get-Settings
   - Condition: `SourceCodeTestSuites != '[]'`
   - Strategy: Matrix based on test suite configuration

7. **Test-Module** (conditional)
   - Uses: `./.github/workflows/Test-Module.yml`
   - Depends on: Get-Settings, Build-Module
   - Condition: `Settings.Test.Module.Skip != true`

8. **BeforeAll-ModuleLocal** (conditional)
   - Uses: `./.github/workflows/BeforeAll-ModuleLocal.yml` (if exists)
   - Depends on: Get-Settings, Build-Module
   - Condition: `Settings.Test.ModuleLocal.Skip != true AND tests/BeforeAll.ps1 exists`

9. **Test-ModuleLocal** (matrix, conditional)
   - Uses: `./.github/workflows/Test-ModuleLocal.yml`
   - Depends on: Get-Settings, Build-Module, BeforeAll-ModuleLocal
   - Condition: `Settings.Test.ModuleLocal.Skip != true`
   - Strategy: Matrix across platforms (ubuntu, windows, macos)

10. **AfterAll-ModuleLocal** (conditional, always runs)
    - Uses: `./.github/workflows/AfterAll-ModuleLocal.yml` (if exists)
    - Depends on: Test-ModuleLocal
    - Condition: `always() AND Settings.Test.ModuleLocal.Skip != true AND tests/AfterAll.ps1 exists`

11. **Get-TestResults** (always after tests)
    - Uses: `./.github/workflows/Get-TestResults.yml`
    - Depends on: Test-SourceCode, Lint-SourceCode, Test-Module, Test-ModuleLocal
    - Condition: `always()` (runs even if tests fail)

12. **Get-CodeCoverage** (always after results)
    - Uses: `./.github/workflows/Get-CodeCoverage.yml`
    - Depends on: Get-TestResults
    - Condition: `always()` (runs even if tests fail)

13. **Publish-Module** (conditional, main branch only)
    - Uses: `./.github/workflows/Publish-Module.yml` (if exists)
    - Depends on: Build-Module, Get-TestResults
    - Condition: `github.event_name == 'pull_request' AND github.event.pull_request.merged == true AND Settings.Publish.Module.Skip != true AND tests passed`

14. **Publish-Site** (conditional, main branch only)
    - Uses: `./.github/workflows/Publish-Site.yml` (if exists)
    - Depends on: Build-Site, Get-TestResults
    - Condition: `github.event_name == 'pull_request' AND github.event.pull_request.merged == true AND Settings.Publish.Site.Skip != true AND tests passed`

### Conditional Execution Matrix

| Context | Event | Get-Settings | Build | Test | Publish-Module | Publish-Site |
|---------|-------|--------------|-------|------|----------------|--------------|
| PR opened | pull_request | ✅ | ✅ | ✅ | ❌ | ❌ |
| PR sync | pull_request | ✅ | ✅ | ✅ | ❌ | ❌ |
| PR merged | pull_request (merged=true) | ✅ | ✅ | ✅ | ✅ (if tests pass) | ✅ (if tests pass) |
| PR closed (not merged) | pull_request (merged=false) | ❌ | ❌ | ❌ | ❌ | ❌ |

## Breaking Changes from CI.yml

### Removed
- **CI.yml file**: Deleted entirely
- **Separate CI workflow**: Functionality consolidated into workflow.yml

### Maintained (No Changes)
- All workflow inputs
- All secrets
- All permissions
- All job definitions
- All reusable workflow references
- All conditional logic (except publishing conditions)

### Modified
- **Publishing trigger**: Changed from separate workflow to conditional execution within unified workflow
- **Concurrency group**: Applied to unified workflow instead of separate workflows

## Consumer Repository Impact

### Required Changes
1. Delete `.github/workflows/CI.yml`
2. Update any references to `CI.yml` in:
   - Documentation
   - External CI/CD integrations
   - Monitoring/alerting systems
   - Branch protection rules (use `workflow.yml` status checks)

### No Changes Required
- `.github/PSModule.yml` configuration
- Test files
- Module source code
- Documentation (except workflow references)

## Validation Contract

### PR Context Validation
```yaml
# Test that publish jobs are skipped on PR
assert:
  - job: Publish-Module
    status: skipped
    reason: "Condition not met (PR not merged)"
  - job: Publish-Site
    status: skipped
    reason: "Condition not met (PR not merged)"
```

### Merge Context Validation
```yaml
# Test that publish jobs execute on merge (when tests pass)
assert:
  - job: Publish-Module
    status: success
    condition: "github.event.pull_request.merged == true AND tests passed"
  - job: Publish-Site
    status: success
    condition: "github.event.pull_request.merged == true AND tests passed"
```

### Concurrency Validation
```yaml
# Test that PR builds cancel in-progress runs
assert:
  - concurrency_group: "Process-PSModule-refs/heads/feature-branch"
  - cancel_in_progress: true
  - previous_run_status: cancelled

# Test that main branch builds do not cancel
assert:
  - concurrency_group: "Process-PSModule-refs/heads/main"
  - cancel_in_progress: false
  - previous_run_status: completed
```

### Failure Handling Validation
```yaml
# Test that publish is skipped when tests fail
assert:
  - job: Test-Module
    status: failure
  - job: Publish-Module
    status: skipped
    reason: "Dependency failed"
```

## Error Handling

### Test Failure on PR
- **Behavior**: Workflow fails, PR status check fails, merge blocked
- **Publish jobs**: Skipped (conditions not met)
- **Notification**: GitHub default mechanisms

### Test Failure on Merge
- **Behavior**: Workflow fails, publish jobs skipped
- **Rollback**: Not automatic; maintainer must fix and re-run or revert merge
- **Notification**: GitHub default mechanisms

### Publish Failure
- **Behavior**: Workflow fails
- **Retry**: Maintainer manually re-runs entire workflow (tests + publish)
- **Partial retry**: Not supported; entire workflow re-executes

## Backward Compatibility

### Compatible
- All existing consuming repositories can migrate by deleting CI.yml
- No changes to module structure, test frameworks, or configuration files
- Publishing behavior unchanged (still uses APIKey secret)

### Incompatible
- External systems referencing CI.yml must be updated
- Branch protection rules must reference workflow.yml checks instead of CI.yml checks

## Migration Contract

### Pre-Migration Checklist
- [ ] Identify all references to CI.yml in external systems
- [ ] Document external integrations that must be updated
- [ ] Communicate breaking change to consuming repository maintainers
- [ ] Prepare migration guide

### Migration Steps
1. Update workflow.yml with unified logic
2. Test in Process-PSModule repository
3. Validate all scenarios in quickstart.md
4. Release as new major version
5. Update consuming repositories:
   - Delete CI.yml
   - Update branch protection rules
   - Update external integrations
   - Test workflow execution

### Post-Migration Validation
- [ ] CI.yml file deleted
- [ ] Workflow.yml triggers on PR events
- [ ] Tests execute on PR open/sync
- [ ] Publishing executes on PR merge
- [ ] Concurrency control working
- [ ] External integrations updated

## References

- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Reusing Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Feature Specification](../spec.md)
- [Data Model](../data-model.md)
