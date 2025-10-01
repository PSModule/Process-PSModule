# Data Model: Local GitHub Composite Action for BeforeAll/AfterAll Test Scripts

**Feature**: 001-building-on-this
**Date**: October 1, 2025

## Overview

This document defines the data structures, contracts, and entities for the setup-test composite action. Since this is a GitHub Actions component, the "data model" consists of action inputs, outputs, and the contract between the action and its callers.

## Entities

### 1. Setup-Test Composite Action

**Location**: `.github/actions/setup-test/action.yml`

**Description**: A local GitHub composite action that discovers and executes either BeforeAll.ps1 or AfterAll.ps1 scripts in the root tests folder based on a mode parameter.

**Inputs**:

| Name | Type | Required | Default | Description | Validation |
|------|------|----------|---------|-------------|------------|
| mode | string | Yes | N/A | Execution mode controlling script discovery and error handling | Must be "before" or "after" |
| Debug | boolean | No | false | Enable debug output | N/A |
| Verbose | boolean | No | false | Enable verbose output | N/A |
| Prerelease | boolean | No | false | Use prerelease version of GitHub module | N/A |
| Version | string | No | '' | Exact version of GitHub module to install | N/A |
| WorkingDirectory | string | No | '.' | Working directory where script will run from | N/A |

**Environment Variables** (passed as secrets from caller):

| Name | Description | Required |
|------|-------------|----------|
| TEST_APP_ENT_CLIENT_ID | Client ID of Enterprise GitHub App for tests | No |
| TEST_APP_ENT_PRIVATE_KEY | Private key of Enterprise GitHub App for tests | No |
| TEST_APP_ORG_CLIENT_ID | Client ID of Organization GitHub App for tests | No |
| TEST_APP_ORG_PRIVATE_KEY | Private key of Organization GitHub App for tests | No |
| TEST_USER_ORG_FG_PAT | Fine-grained PAT with org access for tests | No |
| TEST_USER_USER_FG_PAT | Fine-grained PAT with user account access for tests | No |
| TEST_USER_PAT | Classic PAT for tests | No |
| GITHUB_TOKEN | GitHub Actions token | No |

**Outputs**: None (action success/failure is the primary output)

**Behavior Contract**:

1. **When mode = "before"**:
   - Look for `tests/BeforeAll.ps1` (root tests folder only)
   - If tests directory not found: Exit successfully with message
   - If BeforeAll.ps1 not found: Exit successfully with message
   - If BeforeAll.ps1 found: Execute with all environment variables
   - On script success: Complete successfully
   - On script failure: Fail the job with error message

2. **When mode = "after"**:
   - Look for `tests/AfterAll.ps1` (root tests folder only)
   - If tests directory not found: Exit successfully with message
   - If AfterAll.ps1 not found: Exit successfully with message
   - If AfterAll.ps1 found: Execute with all environment variables
   - On script success: Complete successfully
   - On script failure: Log warning but complete successfully

3. **Common Behaviors** (both modes):
   - Change to tests directory before script execution
   - Restore previous directory after execution (via finally block)
   - Output wrapped in LogGroup for formatted logs
   - Provide clear status messages at each step
   - All environment variables accessible to scripts

**Dependencies**:
- PSModule/Install-PSModuleHelpers@v1 (installs PSModule helper functions)
- PSModule/GitHub-Script@v1 (provides PowerShell execution environment with LogGroup)

**Error Handling**:

| Scenario | Mode "before" | Mode "after" |
|----------|---------------|--------------|
| No tests directory | Success + message | Success + message |
| Script not found | Success + message | Success + message |
| Script execution failure | Job failure + error | Success + warning |
| Script execution success | Success | Success |

### 2. Test Script Files

**BeforeAll.ps1**:
- **Location**: `tests/BeforeAll.ps1` (root tests folder only)
- **Purpose**: Setup external test resources before all test matrix jobs - resources that are independent of test platform/OS
- **Intended Use**: Deploy cloud infrastructure via APIs, create external database instances, initialize test data in third-party services
- **NOT Intended For**: OS-specific dependencies, platform-specific test files, test-specific resources for individual matrix combinations
- **Execution Context**: Runs in tests directory with full access to environment secrets
- **Error Handling**: Failures halt testing workflow
- **Example Use Cases**: Deploy Azure/AWS resources via APIs, create external PostgreSQL databases, initialize SaaS test accounts

**AfterAll.ps1**:
- **Location**: `tests/AfterAll.ps1` (root tests folder only)
- **Purpose**: Cleanup external test resources after all test matrix jobs - resources that are independent of test platform/OS
- **Intended Use**: Remove cloud infrastructure via APIs, delete external database instances, cleanup test data in third-party services
- **NOT Intended For**: OS-specific cleanup, platform-specific file removal, test-specific cleanup for individual matrix combinations
- **Execution Context**: Runs in tests directory with full access to environment secrets
- **Error Handling**: Failures logged but don't halt workflow
- **Example Use Cases**: Delete Azure/AWS resources via APIs, remove external databases, cleanup SaaS test accounts

**Script Contract**:
- Scripts can access all environment variables (secrets)
- Scripts execute in tests directory (via Push-Location)
- Scripts should use Write-Host for output (not Write-Verbose)
- Scripts can call other scripts in tests directory
- Scripts can use PowerShell 7.4+ features
- Scripts should handle their own internal errors gracefully

### 3. Workflow Integration Contract

**BeforeAll-ModuleLocal Job**:
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

**AfterAll-ModuleLocal Job**:
```yaml
AfterAll-ModuleLocal:
  name: AfterAll-ModuleLocal
  runs-on: ubuntu-latest
  needs:
    - Test-ModuleLocal
  if: always()  # Always run cleanup even if tests fail
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

**Job Dependencies**:
- BeforeAll-ModuleLocal: No dependencies (runs first)
- Test-ModuleLocal: Depends on BeforeAll-ModuleLocal
- AfterAll-ModuleLocal: Depends on Test-ModuleLocal, always runs (if: always())

## State Transitions

Since this is a stateless action, state transitions describe the execution flow:

```
[Start]
  → Check inputs.mode validation
  → mode = "before" or "after"

[Mode Validated]
  → Call Install-PSModuleHelpers
  → Initialize GitHub-Script environment

[Environment Ready]
  → Check tests directory exists

[Tests Directory Check]
  → Not Found → [Exit Success with Message]
  → Found → [Script Discovery]

[Script Discovery]
  → mode="before" → Look for tests/BeforeAll.ps1
  → mode="after" → Look for tests/AfterAll.ps1

[Script Check]
  → Not Found → [Exit Success with Message]
  → Found → [Execute Script]

[Execute Script]
  → Push-Location to tests/
  → Run script with environment variables
  → mode="before" + Error → [Job Failure]
  → mode="before" + Success → [Exit Success]
  → mode="after" + Error → [Log Warning] → [Exit Success]
  → mode="after" + Success → [Exit Success]
  → Pop-Location (in finally block)
```

## Validation Rules

### Input Validation

1. **mode parameter**: Must be exactly "before" or "after" (case-sensitive)
   - Invalid values should cause action failure with clear error message
   - Implemented via PowerShell conditional logic

2. **Configuration parameters**: All optional with documented defaults
   - Debug, Verbose, Prerelease: boolean values
   - Version: string (empty or valid version)
   - WorkingDirectory: string (valid path)

### Runtime Validation

1. **tests directory**:
   - Resolved via `Resolve-Path 'tests' -ErrorAction SilentlyContinue`
   - Missing directory is valid (exit success with message)

2. **Script file**:
   - Tested via `Test-Path $scriptPath -PathType Leaf`
   - Missing script is valid (exit success with message)

3. **Script execution**:
   - mode="before": Wrapped in try/catch, throw on error
   - mode="after": Wrapped in try/catch, Write-Warning on error

## Integration Points

### Upstream Dependencies

1. **Workflow Inputs**: Test-ModuleLocal.yml passes configuration inputs
2. **Workflow Secrets**: Test-ModuleLocal.yml passes secret environment variables
3. **File System**: Repository must be checked out (`actions/checkout@v5`)

### Downstream Dependencies

1. **PSModule/Install-PSModuleHelpers@v1**: Must run before GitHub-Script
2. **PSModule/GitHub-Script@v1**: Provides PowerShell execution environment
3. **Test Scripts**: Optional BeforeAll.ps1/AfterAll.ps1 in tests/ folder

### Output Contract

The action provides output via:
1. **Exit Code**: 0 for success, non-zero for failure (mode="before" only)
2. **Console Output**: Formatted messages via LogGroup
3. **GitHub Actions Status**: Job success/failure reflected in workflow UI

### Log Output Format

All output wrapped in LogGroup with title based on mode:
- mode="before": "Running BeforeAll Setup Scripts"
- mode="after": "Running AfterAll Teardown Scripts"

Standard messages:
- No tests directory: "No tests directory found - exiting successfully"
- No script found: "No [BeforeAll|AfterAll].ps1 script found - exiting successfully"
- Script execution start: "Running [BeforeAll|AfterAll] setup/teardown script: [path]"
- Script execution success: "[BeforeAll|AfterAll] script completed successfully: [path]"
- Script execution error (before): "BeforeAll script failed: [path] - [error]"
- Script execution error (after): "AfterAll script failed: [path] - [error]" (as warning)

## Non-Functional Requirements

### Performance
- Action invocation overhead: <2 seconds (Install-PSModuleHelpers + GitHub-Script startup)
- Script discovery: <100ms (single file check)
- Total execution time: Script runtime + overhead

### Reliability
- Action must handle missing directories/files gracefully
- Action must always restore working directory (via finally block)
- Action must propagate errors correctly based on mode
- AfterAll mode must ensure cleanup always runs (if: always())

### Maintainability
- Single source of truth for setup/teardown logic
- Clear separation of concerns (action vs scripts)
- Reusable across workflows
- Documented inputs and behavior

### Security
- Secrets passed as environment variables (not in action inputs)
- Scripts run in isolated job context
- No secret values logged (use Write-Host for non-sensitive output)
- Standard GitHub Actions security model applies

---
**Data Model Complete**: All entities, contracts, and validation rules documented. Ready for contract generation.
