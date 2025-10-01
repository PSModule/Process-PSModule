# Contract: Setup-Test Composite Action

**File**: `.github/actions/setup-test/action.yml`
**Type**: GitHub Actions Composite Action
**Purpose**: Execute BeforeAll.ps1 or AfterAll.ps1 test setup/teardown scripts based on mode parameter

## Action Definition Contract

This is the contract specification for the composite action. The actual implementation will be in `.github/actions/setup-test/action.yml`.

```yaml
name: 'Setup-Test'
description: 'Execute BeforeAll or AfterAll test setup/teardown scripts based on mode parameter'
author: 'PSModule'

inputs:
  mode:
    description: 'Execution mode: "before" (BeforeAll.ps1) or "after" (AfterAll.ps1)'
    required: true

  Debug:
    description: 'Enable debug output'
    required: false
    default: 'false'

  Verbose:
    description: 'Enable verbose output'
    required: false
    default: 'false'

  Prerelease:
    description: 'Use prerelease version of GitHub module'
    required: false
    default: 'false'

  Version:
    description: 'Exact version of GitHub module to install'
    required: false
    default: ''

  WorkingDirectory:
    description: 'Working directory where script will run from'
    required: false
    default: '.'

runs:
  using: 'composite'
  steps:
    - name: Install-PSModuleHelpers
      uses: PSModule/Install-PSModuleHelpers@v1

    - name: Execute Setup/Teardown Script
      uses: PSModule/GitHub-Script@v1
      with:
        Name: 'Setup-Test-${{ inputs.mode }}'
        ShowInfo: false
        ShowOutput: true
        Debug: ${{ inputs.Debug }}
        Verbose: ${{ inputs.Verbose }}
        Prerelease: ${{ inputs.Prerelease }}
        Version: ${{ inputs.Version }}
        WorkingDirectory: ${{ inputs.WorkingDirectory }}
        Script: |
          # PowerShell script implementation
          # See script-implementation.md for detailed script logic
```

## Inputs Contract

### Required Inputs

| Input | Type | Validation | Example |
|-------|------|------------|---------|
| mode | string | Must be "before" or "after" | "before" |

### Optional Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| Debug | boolean | false | Enable debug output |
| Verbose | boolean | false | Enable verbose output |
| Prerelease | boolean | false | Use prerelease GitHub module |
| Version | string | '' | Exact GitHub module version |
| WorkingDirectory | string | '.' | Script working directory |

## Environment Variables Contract

The action expects these environment variables to be set by the caller (passed as secrets):

| Variable | Purpose | Required |
|----------|---------|----------|
| TEST_APP_ENT_CLIENT_ID | Enterprise GitHub App client ID | Optional |
| TEST_APP_ENT_PRIVATE_KEY | Enterprise GitHub App private key | Optional |
| TEST_APP_ORG_CLIENT_ID | Organization GitHub App client ID | Optional |
| TEST_APP_ORG_PRIVATE_KEY | Organization GitHub App private key | Optional |
| TEST_USER_ORG_FG_PAT | Fine-grained PAT with org access | Optional |
| TEST_USER_USER_FG_PAT | Fine-grained PAT with user access | Optional |
| TEST_USER_PAT | Classic PAT | Optional |
| GITHUB_TOKEN | GitHub Actions token | Optional |

**Note**: All environment variables are optional. Scripts may require specific variables based on their test requirements.

## Outputs Contract

**No outputs**: This action communicates results via exit codes and console output.

- **Success**: Exit code 0 (action step shows green checkmark)
- **Failure**: Exit code non-zero (action step shows red X) - only for mode="before" with script errors

## Behavior Contract

### Mode: "before"

**Purpose**: Execute BeforeAll.ps1 setup script before tests

**Execution Flow**:
1. Check if tests directory exists
   - Not found → Exit 0 with message "No tests directory found - exiting successfully"
2. Check if tests/BeforeAll.ps1 exists
   - Not found → Exit 0 with message "No BeforeAll.ps1 script found - exiting successfully"
3. Execute tests/BeforeAll.ps1
   - Change to tests directory
   - Run script with environment variables
   - On success → Exit 0 with message "BeforeAll script completed successfully: [path]"
   - On failure → Exit non-zero with error "BeforeAll script failed: [path] - [error]"
   - Always restore previous directory (via finally block)

**Error Handling**: Script failures cause job failure (errors propagated)

### Mode: "after"

**Purpose**: Execute AfterAll.ps1 teardown script after tests

**Execution Flow**:
1. Check if tests directory exists
   - Not found → Exit 0 with message "No tests directory found - exiting successfully"
2. Check if tests/AfterAll.ps1 exists
   - Not found → Exit 0 with message "No AfterAll.ps1 script found - exiting successfully"
3. Execute tests/AfterAll.ps1
   - Change to tests directory
   - Run script with environment variables
   - On success → Exit 0 with message "AfterAll script completed successfully: [path]"
   - On failure → Exit 0 with warning "AfterAll script failed: [path] - [error]"
   - Always restore previous directory (via finally block)

**Error Handling**: Script failures logged as warnings but don't cause job failure (exit 0)

## Output Format Contract

All output wrapped in LogGroup with title based on mode:

**Mode "before"**: `LogGroup "Running BeforeAll Setup Scripts" { ... }`

**Mode "after"**: `LogGroup "Running AfterAll Teardown Scripts" { ... }`

### Standard Output Messages

| Scenario | Output Message | Level |
|----------|---------------|-------|
| No tests directory | "No tests directory found - exiting successfully" | Info |
| Tests directory found | "Tests found at [$testsPath]" | Info |
| Script not found (before) | "No BeforeAll.ps1 script found - exiting successfully" | Info |
| Script not found (after) | "No AfterAll.ps1 script found - exiting successfully" | Info |
| Script execution start | "Running [BeforeAll\|AfterAll] setup/teardown script: $scriptPath" | Info |
| Script success | "[BeforeAll\|AfterAll] script completed successfully: $scriptPath" | Info |
| Script failure (before) | "BeforeAll script failed: $scriptPath - $_" | Error |
| Script failure (after) | "AfterAll script failed: $scriptPath - $_" | Warning |

## Caller Integration Contract

### Example: BeforeAll-ModuleLocal Job

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

### Example: AfterAll-ModuleLocal Job

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

**Required Caller Setup**:
1. Repository must be checked out (actions/checkout@v5)
2. All required secrets must be passed as environment variables
3. AfterAll-ModuleLocal job must have `if: always()` to ensure cleanup runs
4. AfterAll-ModuleLocal step should also have `if: always()` for resilience

## Validation Contract

### Pre-Execution Validation

1. **mode parameter**: Action script will validate mode is "before" or "after"
   - Invalid mode → Error with message about valid values
2. **Repository checkout**: Caller responsibility to run actions/checkout@v5
3. **Working directory**: GitHub-Script handles WorkingDirectory validation

### Runtime Validation

1. **tests directory**: Action validates existence via Resolve-Path
2. **Script file**: Action validates existence via Test-Path
3. **Script execution**: Action wraps in try/catch for error handling

### Post-Execution Validation

1. **Working directory restore**: Guaranteed via try/finally block
2. **Exit code**: 0 for success, non-zero for failure (mode="before" only)
3. **Output completeness**: All status messages logged to console

## Dependencies Contract

### Action Dependencies

1. **PSModule/Install-PSModuleHelpers@v1**
   - Must run before GitHub-Script step
   - Provides PSModule helper functions
   - No inputs required

2. **PSModule/GitHub-Script@v1**
   - Executes PowerShell script
   - Provides LogGroup helper
   - Receives all action inputs and environment variables

### Script Dependencies

Scripts (BeforeAll.ps1, AfterAll.ps1) can assume:
1. PowerShell 7.4+ environment
2. All environment variables are set
3. Execution directory is tests/
4. PSModule helpers are available
5. ubuntu-latest runner environment

## Error Handling Contract

### Mode "before" Error Handling

| Error Scenario | Handling | Exit Code | Job Status |
|----------------|----------|-----------|------------|
| Invalid mode | Error message + exit | Non-zero | Failed |
| No tests directory | Info message + exit | 0 | Success |
| No BeforeAll.ps1 | Info message + exit | 0 | Success |
| Script execution error | Error message + throw | Non-zero | Failed |
| Script execution success | Info message + exit | 0 | Success |

### Mode "after" Error Handling

| Error Scenario | Handling | Exit Code | Job Status |
|----------------|----------|-----------|------------|
| Invalid mode | Error message + exit | Non-zero | Failed |
| No tests directory | Info message + exit | 0 | Success |
| No AfterAll.ps1 | Info message + exit | 0 | Success |
| Script execution error | Warning message + exit | 0 | Success |
| Script execution success | Info message + exit | 0 | Success |

### Error Messages Contract

**Invalid Mode**:

```plaintext
Invalid mode '$mode'. Mode must be 'before' or 'after'.
```

**Script Execution Error (before)**:

```plaintext
BeforeAll script failed: [absolute-path] - [error-message]
```

**Script Execution Error (after)**:

```plaintext
WARNING: AfterAll script failed: [absolute-path] - [error-message]
```

## Performance Contract

| Metric | Target | Notes |
|--------|--------|-------|
| Action invocation overhead | <2 seconds | Install-PSModuleHelpers + GitHub-Script startup |
| Script discovery time | <100ms | Single Resolve-Path + Test-Path |
| Total execution time | Script runtime + overhead | Depends on script complexity |

## Security Contract

1. **Secrets**: Passed as environment variables, not logged
2. **Script execution**: Runs in isolated job context on ubuntu-latest
3. **Working directory**: Restored via finally block (no directory escape)
4. **Output sanitization**: Caller responsibility to avoid logging secrets in scripts

---
**Contract Complete**: Ready for test implementation and integration.
