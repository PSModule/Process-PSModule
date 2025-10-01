# Contract: Test-ModuleLocal.yml Workflow Integration

**File**: `.github/workflows/Test-ModuleLocal.yml`
**Purpose**: Define integration contract for setup-test composite action within Test-ModuleLocal workflow

## Integration Overview

This contract specifies the modifications required to Test-ModuleLocal.yml to integrate the setup-test composite action.

## Modified Jobs

### BeforeAll-ModuleLocal Job

**Current Implementation** (lines 67-158):
- Inline GitHub-Script with Find-TestDirectories helper
- Recursive script discovery and execution
- ~92 lines of code

**New Implementation**:
```yaml
BeforeAll-ModuleLocal:
  name: BeforeAll-ModuleLocal
  runs-on: ubuntu-latest
  steps:
    - name: Checkout Code
      uses: actions/checkout@v5

    - name: Run BeforeAll Setup
      uses: ./.github/actions/setup-test
      env:
        TEST_APP_ENT_CLIENT_ID: ${{ secrets.TEST_APP_ENT_CLIENT_ID }}
        TEST_APP_ENT_PRIVATE_KEY: ${{ secrets.TEST_APP_ENT_PRIVATE_KEY }}
        TEST_APP_ORG_CLIENT_ID: ${{ secrets.TEST_APP_ORG_CLIENT_ID }}
        TEST_APP_ORG_PRIVATE_KEY: ${{ secrets.TEST_APP_ORG_PRIVATE_KEY }}
        TEST_USER_ORG_FG_PAT: ${{ secrets.TEST_USER_ORG_FG_PAT }}
        TEST_USER_USER_FG_PAT: ${{ secrets.TEST_USER_USER_FG_PAT }}
        TEST_USER_PAT: ${{ secrets.TEST_USER_PAT }}
        GITHUB_TOKEN: ${{ github.token }}
      with:
        mode: before
        Debug: ${{ inputs.Debug }}
        Verbose: ${{ inputs.Verbose }}
        Prerelease: ${{ inputs.Prerelease }}
        Version: ${{ inputs.Version }}
        WorkingDirectory: ${{ inputs.WorkingDirectory }}
```

**Key Changes**:
- Remove Install-PSModuleHelpers step (moved to composite action)
- Remove GitHub-Script step with inline script
- Add setup-test composite action call with mode: before
- Maintain all environment variables (secrets)
- Maintain all workflow inputs pass-through

**Lines Removed**: ~86 lines (steps 2-3 of current implementation)
**Lines Added**: ~20 lines (single setup-test action call)
**Net Change**: -66 lines

### AfterAll-ModuleLocal Job

**Current Implementation** (lines 223-314):
- Inline GitHub-Script with Find-TestDirectories helper (duplicate)
- Recursive script discovery and execution
- ~92 lines of code

**New Implementation**:
```yaml
AfterAll-ModuleLocal:
  name: AfterAll-ModuleLocal
  runs-on: ubuntu-latest
  needs:
    - Test-ModuleLocal
  if: always()
  steps:
    - name: Checkout Code
      uses: actions/checkout@v5

    - name: Run AfterAll Teardown
      if: always()
      uses: ./.github/actions/setup-test
      env:
        TEST_APP_ENT_CLIENT_ID: ${{ secrets.TEST_APP_ENT_CLIENT_ID }}
        TEST_APP_ENT_PRIVATE_KEY: ${{ secrets.TEST_APP_ENT_PRIVATE_KEY }}
        TEST_APP_ORG_CLIENT_ID: ${{ secrets.TEST_APP_ORG_CLIENT_ID }}
        TEST_APP_ORG_PRIVATE_KEY: ${{ secrets.TEST_APP_ORG_PRIVATE_KEY }}
        TEST_USER_ORG_FG_PAT: ${{ secrets.TEST_USER_ORG_FG_PAT }}
        TEST_USER_USER_FG_PAT: ${{ secrets.TEST_USER_USER_FG_PAT }}
        TEST_USER_PAT: ${{ secrets.TEST_USER_PAT }}
        GITHUB_TOKEN: ${{ github.token }}
      with:
        mode: after
        Debug: ${{ inputs.Debug }}
        Verbose: ${{ inputs.Verbose }}
        Prerelease: ${{ inputs.Prerelease }}
        Version: ${{ inputs.Version }}
        WorkingDirectory: ${{ inputs.WorkingDirectory }}
```

**Key Changes**:
- Remove Install-PSModuleHelpers step (moved to composite action)
- Remove GitHub-Script step with inline script
- Add setup-test composite action call with mode: after
- Maintain if: always() at job level
- Maintain if: always() at step level for resilience
- Maintain all environment variables (secrets)
- Maintain all workflow inputs pass-through

**Lines Removed**: ~86 lines (steps 2-3 of current implementation)
**Lines Added**: ~22 lines (single setup-test action call with if: always())
**Net Change**: -64 lines

### Test-ModuleLocal Job

**No changes required** - This job remains unchanged.

## Workflow Structure Contract

### File Organization
```
Test-ModuleLocal.yml (314 lines → ~176 lines)
├── on: workflow_call
│   ├── secrets: [8 test secrets]
│   └── inputs: [8 configuration inputs]
├── permissions: contents: read
└── jobs:
    ├── BeforeAll-ModuleLocal (lines 67-158 → simplified ~20 lines)
    │   ├── runs-on: ubuntu-latest
    │   └── steps:
    │       ├── Checkout Code
    │       └── Run BeforeAll Setup (setup-test action)
    ├── Test-ModuleLocal (lines 159-222 → unchanged)
    │   ├── runs-on: ${{ matrix.RunsOn }}
    │   ├── needs: BeforeAll-ModuleLocal
    │   └── strategy: matrix testing
    └── AfterAll-ModuleLocal (lines 223-314 → simplified ~22 lines)
        ├── runs-on: ubuntu-latest
        ├── needs: Test-ModuleLocal
        ├── if: always()
        └── steps:
            ├── Checkout Code
            └── Run AfterAll Teardown (setup-test action, if: always())
```

## Workflow Input Contract

**No changes to workflow inputs** - All existing inputs preserved and passed through:

| Input | Type | Required | Default | Usage |
|-------|------|----------|---------|-------|
| ModuleTestSuites | string | Yes | N/A | Test-ModuleLocal job only |
| Name | string | No | '' | Not used by setup-test |
| Debug | boolean | No | false | Passed to setup-test |
| Verbose | boolean | No | false | Passed to setup-test |
| Version | string | No | '' | Passed to setup-test |
| Prerelease | boolean | No | false | Passed to setup-test |
| WorkingDirectory | string | No | '.' | Passed to setup-test |

## Workflow Secret Contract

**No changes to workflow secrets** - All existing secrets preserved and passed through:

| Secret | Description | Usage |
|--------|-------------|-------|
| TEST_APP_ENT_CLIENT_ID | Enterprise GitHub App client ID | Passed to setup-test as env var |
| TEST_APP_ENT_PRIVATE_KEY | Enterprise GitHub App private key | Passed to setup-test as env var |
| TEST_APP_ORG_CLIENT_ID | Organization GitHub App client ID | Passed to setup-test as env var |
| TEST_APP_ORG_PRIVATE_KEY | Organization GitHub App private key | Passed to setup-test as env var |
| TEST_USER_ORG_FG_PAT | Fine-grained PAT with org access | Passed to setup-test as env var |
| TEST_USER_USER_FG_PAT | Fine-grained PAT with user access | Passed to setup-test as env var |
| TEST_USER_PAT | Classic PAT | Passed to setup-test as env var |
| GITHUB_TOKEN | Auto-provided by GitHub Actions | Passed to setup-test as env var |

## Job Dependency Contract

```
BeforeAll-ModuleLocal (no dependencies)
        ↓
Test-ModuleLocal (needs: BeforeAll-ModuleLocal)
        ↓
AfterAll-ModuleLocal (needs: Test-ModuleLocal, if: always())
```

**Contract Requirements**:
1. BeforeAll-ModuleLocal must run first (no dependencies)
2. Test-ModuleLocal must wait for BeforeAll-ModuleLocal (needs: BeforeAll-ModuleLocal)
3. AfterAll-ModuleLocal must wait for Test-ModuleLocal (needs: Test-ModuleLocal)
4. AfterAll-ModuleLocal must always run even if Test-ModuleLocal fails (if: always())
5. AfterAll-ModuleLocal step must always run even if previous steps fail (if: always() on step)

## Backward Compatibility Contract

### Breaking Changes

1. **Nested script support removed**:
   - Old: Tests in any subdirectory under tests/ are discovered and executed
   - New: Only tests/BeforeAll.ps1 and tests/AfterAll.ps1 are executed
   - Impact: Repositories with nested setup/teardown scripts must consolidate
   - Migration: Move or merge nested scripts to root tests/ folder

2. **Multiple script execution removed**:
   - Old: All BeforeAll.ps1/AfterAll.ps1 scripts found are executed
   - New: Only single BeforeAll.ps1 or AfterAll.ps1 in root tests/ folder
   - Impact: Repositories with multiple scripts must merge into single script
   - Migration: Combine logic from multiple scripts into single file

### Preserved Behaviors

1. **Job execution order**: Unchanged (BeforeAll → Test → AfterAll)
2. **Error handling**: Unchanged (BeforeAll throws, AfterAll warns)
3. **Environment variables**: Unchanged (all secrets accessible)
4. **Runner OS**: Unchanged (ubuntu-latest for setup/teardown jobs)
5. **Output format**: Unchanged (LogGroup wrapper with status messages)
6. **Workflow inputs**: Unchanged (all inputs preserved and passed through)
7. **Workflow secrets**: Unchanged (all secrets preserved and passed through)

## Testing Contract

### Integration Test Scenarios

1. **Test: Workflow with no tests directory**
   - Setup: Repository with no tests/ folder
   - Expected: BeforeAll and AfterAll jobs succeed with "No tests directory found" message

2. **Test: Workflow with no BeforeAll.ps1**
   - Setup: Repository with tests/ folder but no BeforeAll.ps1
   - Expected: BeforeAll job succeeds with "No BeforeAll.ps1 script found" message

3. **Test: Workflow with no AfterAll.ps1**
   - Setup: Repository with tests/ folder but no AfterAll.ps1
   - Expected: AfterAll job succeeds with "No AfterAll.ps1 script found" message

4. **Test: Workflow with successful BeforeAll.ps1**
   - Setup: Repository with tests/BeforeAll.ps1 that succeeds
   - Expected: BeforeAll job succeeds, Test-ModuleLocal runs

5. **Test: Workflow with failing BeforeAll.ps1**
   - Setup: Repository with tests/BeforeAll.ps1 that throws error
   - Expected: BeforeAll job fails, Test-ModuleLocal skipped, AfterAll runs (if: always())

6. **Test: Workflow with successful AfterAll.ps1**
   - Setup: Repository with tests/AfterAll.ps1 that succeeds
   - Expected: AfterAll job succeeds

7. **Test: Workflow with failing AfterAll.ps1**
   - Setup: Repository with tests/AfterAll.ps1 that throws error
   - Expected: AfterAll job succeeds with warning message

8. **Test: Workflow with Test-ModuleLocal failure**
   - Setup: Repository where Test-ModuleLocal job fails
   - Expected: AfterAll job still runs (if: always())

9. **Test: All secrets accessible in scripts**
   - Setup: BeforeAll.ps1/AfterAll.ps1 that reads environment variables
   - Expected: All TEST_* and GITHUB_TOKEN variables accessible

10. **Test: WorkingDirectory parameter respected**
    - Setup: Workflow call with WorkingDirectory set to subdirectory
    - Expected: setup-test action respects WorkingDirectory parameter

## Documentation Contract

### Files to Update

1. **Test-ModuleLocal.yml**: Inline comments if needed
2. **Process-PSModule README**: Update workflow documentation section
3. **Template-PSModule**: Update example workflows to use new pattern
4. **Migration Guide**: Document breaking changes and migration steps

### Migration Guide Required Content

1. **Overview of changes**:
   - What: BeforeAll/AfterAll logic moved to composite action
   - Why: Reduce duplication, improve maintainability, enable reuse
   - When: Version X.Y.Z of Process-PSModule

2. **Breaking changes**:
   - Nested script support removed
   - Multiple script execution removed
   - Only tests/BeforeAll.ps1 and tests/AfterAll.ps1 supported

3. **Migration steps**:
   - Step 1: Identify nested BeforeAll.ps1/AfterAll.ps1 scripts
   - Step 2: Consolidate logic into root tests/ folder
   - Step 3: Test consolidated scripts locally
   - Step 4: Update to new Process-PSModule version
   - Step 5: Verify workflow execution

4. **Examples**:
   - Before: Multiple nested scripts
   - After: Single consolidated script
   - Sample consolidation patterns

## Validation Contract

### Pre-Integration Validation

1. **Composite action exists**: .github/actions/setup-test/action.yml present
2. **Composite action syntax valid**: YAML linting passes
3. **Composite action contract matches**: action.yml.md specification

### Post-Integration Validation

1. **Workflow syntax valid**: YAML linting passes
2. **Workflow line count reduced**: ~140 lines removed (66 + 64 + adjustments)
3. **All workflow inputs preserved**: No changes to workflow_call inputs
4. **All workflow secrets preserved**: No changes to workflow_call secrets
5. **Job dependencies preserved**: needs and if: always() clauses unchanged

### Runtime Validation

1. **BeforeAll job executes**: setup-test action called with mode: before
2. **AfterAll job executes**: setup-test action called with mode: after
3. **Output format matches**: LogGroup and messages match current implementation
4. **Error handling matches**: Failures behave as before (throw vs warn)
5. **Secrets accessible**: Environment variables available to scripts

## Performance Contract

| Metric | Current | New | Change |
|--------|---------|-----|--------|
| Workflow file size | 314 lines | ~176 lines | -44% |
| BeforeAll job steps | 3 | 2 | -1 step |
| AfterAll job steps | 3 | 2 | -1 step |
| Execution time | Baseline | +1-2s overhead | <5% increase |
| Maintenance burden | High (duplicated code) | Low (single action) | Significant improvement |

**Execution Time Breakdown**:
- Current: Checkout + Install-PSModuleHelpers + GitHub-Script + Script execution
- New: Checkout + setup-test (Install-PSModuleHelpers + GitHub-Script) + Script execution
- Difference: Composite action invocation overhead (~1-2 seconds)

## Rollback Contract

If issues are discovered post-integration:

1. **Immediate rollback**: Revert Test-ModuleLocal.yml to previous version
2. **Investigate**: Determine root cause of issue
3. **Fix**: Update composite action or workflow integration
4. **Re-test**: Validate fix against all test scenarios
5. **Re-deploy**: Apply fix and re-test in production

**Rollback steps**:
```bash
git revert <commit-hash>  # Revert workflow changes
git push origin main      # Deploy rollback
```

---
**Workflow Integration Contract Complete**: Ready for implementation and testing.
