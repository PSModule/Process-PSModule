# Quickstart: Setup-Test Composite Action Integration

**Feature**: 001-building-on-this
**Date**: October 1, 2025
**Purpose**: Quick validation steps to verify setup-test composite action is working correctly

## Overview

This quickstart provides a minimal integration path and validation steps for the setup-test composite action. Follow these steps to verify the feature works as expected.

## Prerequisites

- Process-PSModule repository checked out on branch `001-building-on-this`
- Access to a test repository that uses Process-PSModule workflows
- Understanding of GitHub Actions workflow execution

## Quick Integration Steps

### Step 1: Verify Composite Action Exists

Check that the composite action file is present:

```powershell
Test-Path .github/actions/setup-test/action.yml
# Expected: True
```

### Step 2: Verify Composite Action Content

Read and verify the action.yml structure:

```powershell
Get-Content .github/actions/setup-test/action.yml
```

Expected structure:
- `name`: 'Setup-Test'
- `inputs`: mode, Debug, Verbose, Prerelease, Version, WorkingDirectory
- `runs`: using: 'composite'
- `steps`: Install-PSModuleHelpers, GitHub-Script

### Step 3: Verify Test-ModuleLocal.yml Updated

Check that Test-ModuleLocal.yml uses the composite action:

```powershell
$content = Get-Content .github/workflows/Test-ModuleLocal.yml -Raw
$content -match 'uses: \./\.github/actions/setup-test'
# Expected: True
```

### Step 4: Create Test Repository Setup

Create a minimal test repository structure:

```powershell
# In test repository
New-Item -ItemType Directory -Path tests -Force
```

### Step 5: Create BeforeAll Test Script

```powershell
# tests/BeforeAll.ps1
@'
Write-Host "BeforeAll test script executing"
Write-Host "TEST_USER_PAT available: $($null -ne $env:TEST_USER_PAT)"
Write-Host "GITHUB_TOKEN available: $($null -ne $env:GITHUB_TOKEN)"
Write-Host "BeforeAll completed successfully"
'@ | Set-Content tests/BeforeAll.ps1
```

### Step 6: Create AfterAll Test Script

```powershell
# tests/AfterAll.ps1
@'
Write-Host "AfterAll test script executing"
Write-Host "Cleanup completed successfully"
'@ | Set-Content tests/AfterAll.ps1
```

### Step 7: Trigger Workflow

Push changes to trigger Test-ModuleLocal workflow:

```powershell
git add tests/
git commit -m "Add test setup/teardown scripts"
git push origin <branch-name>
```

### Step 8: Verify Workflow Execution

Check GitHub Actions workflow run:

1. Navigate to repository → Actions tab
2. Find Test-ModuleLocal workflow run
3. Check BeforeAll-ModuleLocal job output
4. Check AfterAll-ModuleLocal job output

## Validation Checklist

### Composite Action Validation

- [ ] `.github/actions/setup-test/action.yml` exists
- [ ] Action has `mode` input parameter
- [ ] Action has configuration inputs (Debug, Verbose, etc.)
- [ ] Action uses `PSModule/Install-PSModuleHelpers@v1`
- [ ] Action uses `PSModule/GitHub-Script@v1`
- [ ] Action has embedded PowerShell script

### Workflow Integration Validation

- [ ] Test-ModuleLocal.yml BeforeAll-ModuleLocal job uses setup-test action
- [ ] Test-ModuleLocal.yml AfterAll-ModuleLocal job uses setup-test action
- [ ] BeforeAll job passes `mode: before`
- [ ] AfterAll job passes `mode: after`
- [ ] Both jobs pass all secrets as environment variables
- [ ] Both jobs pass all configuration inputs
- [ ] AfterAll job has `if: always()` at job and step level

### Execution Validation

- [ ] BeforeAll-ModuleLocal job runs first
- [ ] BeforeAll job output shows "Running BeforeAll Setup Scripts" log group
- [ ] BeforeAll job output shows "Tests found at [path]"
- [ ] BeforeAll job output shows "Running BeforeAll setup script: [path]"
- [ ] BeforeAll job output shows "BeforeAll script completed successfully: [path]"
- [ ] Test-ModuleLocal job runs after BeforeAll succeeds
- [ ] AfterAll-ModuleLocal job runs after Test-ModuleLocal completes
- [ ] AfterAll job output shows "Running AfterAll Teardown Scripts" log group
- [ ] AfterAll job output shows "Tests found at [path]"
- [ ] AfterAll job output shows "Running AfterAll teardown script: [path]"
- [ ] AfterAll job output shows "AfterAll script completed successfully: [path]"

### Environment Variables Validation

- [ ] TEST_USER_PAT accessible in BeforeAll.ps1
- [ ] GITHUB_TOKEN accessible in BeforeAll.ps1
- [ ] All environment variables accessible in AfterAll.ps1
- [ ] No secrets logged in workflow output

## Test Scenarios

### Scenario 1: Happy Path (All Scripts Present and Succeed)

**Setup**:
- Repository has tests/BeforeAll.ps1 (succeeds)
- Repository has tests/AfterAll.ps1 (succeeds)

**Expected**:
1. BeforeAll job: Success, script executed
2. Test-ModuleLocal job: Runs
3. AfterAll job: Success, script executed

**Validation**:
```powershell
# Check workflow run status
gh run view <run-id> --json conclusion
# Expected: {"conclusion": "success"}
```

### Scenario 2: No Tests Directory

**Setup**:
- Repository has no tests/ directory

**Expected**:
1. BeforeAll job: Success with "No tests directory found" message
2. Test-ModuleLocal job: Runs
3. AfterAll job: Success with "No tests directory found" message

**Validation**:
```powershell
# Check BeforeAll job log
gh run view <run-id> --log | grep "No tests directory found"
# Expected: Message appears twice (BeforeAll and AfterAll)
```

### Scenario 3: No BeforeAll.ps1 Script

**Setup**:
- Repository has tests/ directory
- No tests/BeforeAll.ps1 file

**Expected**:
1. BeforeAll job: Success with "No BeforeAll.ps1 script found" message
2. Test-ModuleLocal job: Runs
3. AfterAll job: Runs normally

**Validation**:
```powershell
# Check BeforeAll job log
gh run view <run-id> --log | grep "No BeforeAll.ps1 script found"
# Expected: Message appears
```

### Scenario 4: No AfterAll.ps1 Script

**Setup**:
- Repository has tests/ directory
- No tests/AfterAll.ps1 file

**Expected**:
1. BeforeAll job: Runs normally
2. Test-ModuleLocal job: Runs
3. AfterAll job: Success with "No AfterAll.ps1 script found" message

**Validation**:
```powershell
# Check AfterAll job log
gh run view <run-id> --log | grep "No AfterAll.ps1 script found"
# Expected: Message appears
```

### Scenario 5: BeforeAll.ps1 Fails

**Setup**:
- tests/BeforeAll.ps1 throws error:
```powershell
@'
Write-Host "BeforeAll starting"
throw "Simulated failure"
'@ | Set-Content tests/BeforeAll.ps1
```

**Expected**:
1. BeforeAll job: Failure with "BeforeAll script failed" error message
2. Test-ModuleLocal job: Skipped (dependency failed)
3. AfterAll job: Runs (if: always())

**Validation**:
```powershell
# Check BeforeAll job status
gh run view <run-id> --json jobs | jq '.jobs[] | select(.name=="BeforeAll-ModuleLocal") | .conclusion'
# Expected: "failure"

# Check Test-ModuleLocal job status
gh run view <run-id> --json jobs | jq '.jobs[] | select(.name | contains("Test-")) | .conclusion'
# Expected: "skipped" or null

# Check AfterAll job status
gh run view <run-id> --json jobs | jq '.jobs[] | select(.name=="AfterAll-ModuleLocal") | .conclusion'
# Expected: "success"
```

### Scenario 6: AfterAll.ps1 Fails

**Setup**:
- tests/AfterAll.ps1 throws error:
```powershell
@'
Write-Host "AfterAll starting"
throw "Simulated cleanup failure"
'@ | Set-Content tests/AfterAll.ps1
```

**Expected**:
1. BeforeAll job: Runs normally
2. Test-ModuleLocal job: Runs
3. AfterAll job: Success with warning "AfterAll script failed"

**Validation**:
```powershell
# Check AfterAll job status
gh run view <run-id> --json jobs | jq '.jobs[] | select(.name=="AfterAll-ModuleLocal") | .conclusion'
# Expected: "success"

# Check AfterAll job log for warning
gh run view <run-id> --log | grep "WARNING.*AfterAll script failed"
# Expected: Warning message appears
```

### Scenario 7: Test-ModuleLocal Fails but AfterAll Runs

**Setup**:
- Test-ModuleLocal job fails (e.g., test failures)

**Expected**:
1. BeforeAll job: Success
2. Test-ModuleLocal job: Failure
3. AfterAll job: Runs (if: always()) and succeeds

**Validation**:
```powershell
# Check workflow has failed tests but AfterAll still ran
gh run view <run-id> --json jobs | jq '.jobs[] | select(.name | contains("AfterAll")) | .conclusion'
# Expected: "success" even though workflow may have failed
```

## Quick Debug Commands

### View Composite Action

```powershell
Get-Content .github/actions/setup-test/action.yml
```

### View Workflow Changes

```powershell
git diff main..001-building-on-this .github/workflows/Test-ModuleLocal.yml
```

### Check Workflow Syntax

```powershell
# Using act (local GitHub Actions runner)
act -l --workflows .github/workflows/Test-ModuleLocal.yml
```

### View Latest Workflow Run Logs

```powershell
# Get latest run
$runId = gh run list --workflow=Test-ModuleLocal.yml --limit 1 --json databaseId --jq '.[0].databaseId'

# View full log
gh run view $runId --log

# View BeforeAll job
gh run view $runId --log | Select-String -Pattern "BeforeAll-ModuleLocal" -Context 0,20

# View AfterAll job
gh run view $runId --log | Select-String -Pattern "AfterAll-ModuleLocal" -Context 0,20
```

### Check Job Status

```powershell
gh run view $runId --json jobs | ConvertFrom-Json |
    Select-Object -ExpandProperty jobs |
    Select-Object name, conclusion, startedAt, completedAt
```

## Common Issues and Solutions

### Issue: "Action not found" Error

**Symptom**: Workflow fails with "Unable to resolve action ./.github/actions/setup-test"

**Solution**:
- Verify action.yml exists at `.github/actions/setup-test/action.yml`
- Ensure repository is checked out with `actions/checkout@v5`
- Check action path in workflow uses: `./.github/actions/setup-test` (relative path)

### Issue: "Invalid mode" Error

**Symptom**: Setup-test action fails with "Invalid mode 'X'. Mode must be 'before' or 'after'."

**Solution**:
- Verify BeforeAll job uses `mode: before`
- Verify AfterAll job uses `mode: after`
- Check for typos in mode parameter value

### Issue: Secrets Not Accessible in Scripts

**Symptom**: Scripts report environment variables are null/empty

**Solution**:
- Verify secrets are defined in repository settings
- Verify secrets are passed in `env:` block of setup-test action call
- Check secret names match exactly (case-sensitive)

### Issue: BeforeAll Failure Doesn't Stop Tests

**Symptom**: Test-ModuleLocal runs even when BeforeAll.ps1 fails

**Solution**:
- Verify BeforeAll.ps1 is throwing errors (not just Write-Error)
- Verify setup-test action mode is "before" (not "after")
- Check Test-ModuleLocal job has `needs: BeforeAll-ModuleLocal`

### Issue: AfterAll Doesn't Run When Tests Fail

**Symptom**: AfterAll job skipped when Test-ModuleLocal fails

**Solution**:
- Verify AfterAll job has `if: always()` at job level
- Verify AfterAll job has `needs: Test-ModuleLocal`
- Check workflow run to see if AfterAll was skipped or failed

### Issue: Working Directory Wrong

**Symptom**: Scripts can't find files/resources

**Solution**:
- Scripts execute in tests/ directory (via Push-Location)
- Verify scripts use relative paths from tests/ folder
- Check WorkingDirectory input is set correctly in workflow

## Success Criteria

The feature is successfully integrated when:

1. ✅ Composite action `.github/actions/setup-test/action.yml` exists
2. ✅ Test-ModuleLocal.yml uses setup-test action for BeforeAll and AfterAll
3. ✅ All 7 test scenarios pass
4. ✅ Workflow line count reduced by ~140 lines
5. ✅ Output format matches current implementation
6. ✅ Error handling behavior matches current implementation
7. ✅ No secrets exposed in logs
8. ✅ Documentation updated

## Next Steps

After quickstart validation:

1. Run comprehensive test suite across multiple repositories
2. Update Process-PSModule documentation
3. Update Template-PSModule repository
4. Create migration guide for consuming repositories
5. Tag new Process-PSModule version
6. Announce changes to users

---
**Quickstart Complete**: Use this guide to quickly validate the setup-test composite action integration.
