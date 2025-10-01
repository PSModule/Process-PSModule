# Contract: PowerShell Script Implementation

**Context**: Embedded PowerShell script within Setup-Test composite action
**Execution Environment**: PSModule/GitHub-Script@v1 (PowerShell 7.4+)
**Purpose**: Discover and execute BeforeAll.ps1 or AfterAll.ps1 based on mode parameter

## Script Structure Contract

The PowerShell script embedded in the composite action's GitHub-Script step must follow this structure:

```powershell
LogGroup "Running [BeforeAll|AfterAll] [Setup|Teardown] Scripts" {
    # 1. Determine script name based on mode
    # 2. Validate tests directory exists
    # 3. Check if target script exists
    # 4. Execute script with appropriate error handling
}
```

## Implementation Specification

### Section 1: Mode-Based Configuration

```powershell
# Determine script name and log group title based on mode
$mode = '${{ inputs.mode }}'
$scriptName = switch ($mode) {
    'before' { 'BeforeAll.ps1' }
    'after' { 'AfterAll.ps1' }
    default {
        Write-Error "Invalid mode '$mode'. Mode must be 'before' or 'after'."
        exit 1
    }
}

$logGroupTitle = switch ($mode) {
    'before' { 'Running BeforeAll Setup Scripts' }
    'after' { 'Running AfterAll Teardown Scripts' }
}
```

**Contract**:
- mode parameter must be validated
- Invalid mode must exit with error code 1
- scriptName must be exactly "BeforeAll.ps1" or "AfterAll.ps1"
- logGroupTitle must match current Test-ModuleLocal.yml format

### Section 2: Tests Directory Discovery

```powershell
# Locate the tests directory
$testsPath = Resolve-Path 'tests' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
if (-not $testsPath) {
    Write-Host 'No tests directory found - exiting successfully'
    exit 0
}
Write-Host "Tests found at [$testsPath]"
```

**Contract**:
- Use Resolve-Path with -ErrorAction SilentlyContinue
- Missing tests directory is success (exit 0)
- Found tests directory must be logged with full path in brackets

### Section 3: Script File Discovery

```powershell
# Check if the target script exists in root tests folder
$scriptPath = Join-Path $testsPath $scriptName
if (-not (Test-Path $scriptPath -PathType Leaf)) {
    Write-Host "No $scriptName script found - exiting successfully"
    exit 0
}
```

**Contract**:
- Script must be in root tests folder only (no nested search)
- Use Join-Path for path construction
- Use Test-Path with -PathType Leaf to ensure it's a file
- Missing script is success (exit 0)
- Message format: "No {scriptName} script found - exiting successfully"

### Section 4: Script Execution (Mode "before")

```powershell
if ($mode -eq 'before') {
    Write-Host "Running BeforeAll setup script: $scriptPath"
    try {
        Push-Location $testsPath
        & $scriptPath
        Write-Host "BeforeAll script completed successfully: $scriptPath"
    } catch {
        Write-Error "BeforeAll script failed: $scriptPath - $_"
        throw
    } finally {
        Pop-Location
    }
}
```

**Contract**:
- Log script execution start with full path
- Push-Location to tests directory before execution
- Use call operator (&) to execute script
- On success: Log completion with full path
- On error: Log error with full path and error message
- Throw exception to fail the job
- Always Pop-Location in finally block

### Section 5: Script Execution (Mode "after")

```powershell
if ($mode -eq 'after') {
    Write-Host "Running AfterAll teardown script: $scriptPath"
    try {
        Push-Location $testsPath
        & $scriptPath
        Write-Host "AfterAll script completed successfully: $scriptPath"
    } catch {
        Write-Warning "AfterAll script failed: $scriptPath - $_"
        # Don't throw - continue execution for cleanup
    } finally {
        Pop-Location
    }
}
```

**Contract**:
- Log script execution start with full path
- Push-Location to tests directory before execution
- Use call operator (&) to execute script
- On success: Log completion with full path
- On error: Log warning (not error) with full path and error message
- Do NOT throw exception (allow job to succeed)
- Always Pop-Location in finally block

## Complete Script Contract

The complete embedded script must be:

```powershell
$mode = '${{ inputs.mode }}'
$scriptName = switch ($mode) {
    'before' { 'BeforeAll.ps1' }
    'after' { 'AfterAll.ps1' }
    default {
        Write-Error "Invalid mode '$mode'. Mode must be 'before' or 'after'."
        exit 1
    }
}

$logGroupTitle = switch ($mode) {
    'before' { 'Running BeforeAll Setup Scripts' }
    'after' { 'Running AfterAll Teardown Scripts' }
}

LogGroup $logGroupTitle {
    # Locate the tests directory
    $testsPath = Resolve-Path 'tests' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
    if (-not $testsPath) {
        Write-Host 'No tests directory found - exiting successfully'
        exit 0
    }
    Write-Host "Tests found at [$testsPath]"

    # Check if the target script exists in root tests folder
    $scriptPath = Join-Path $testsPath $scriptName
    if (-not (Test-Path $scriptPath -PathType Leaf)) {
        Write-Host "No $scriptName script found - exiting successfully"
        exit 0
    }

    # Execute the script with mode-appropriate error handling
    if ($mode -eq 'before') {
        Write-Host "Running BeforeAll setup script: $scriptPath"
        try {
            Push-Location $testsPath
            & $scriptPath
            Write-Host "BeforeAll script completed successfully: $scriptPath"
        } catch {
            Write-Error "BeforeAll script failed: $scriptPath - $_"
            throw
        } finally {
            Pop-Location
        }
    } elseif ($mode -eq 'after') {
        Write-Host "Running AfterAll teardown script: $scriptPath"
        try {
            Push-Location $testsPath
            & $scriptPath
            Write-Host "AfterAll script completed successfully: $scriptPath"
        } catch {
            Write-Warning "AfterAll script failed: $scriptPath - $_"
            # Don't throw - continue execution for cleanup
        } finally {
            Pop-Location
        }
    }
}
```

## Execution Context Contract

### Environment Variables Available

All environment variables passed by the caller are available:
- TEST_APP_ENT_CLIENT_ID
- TEST_APP_ENT_PRIVATE_KEY
- TEST_APP_ORG_CLIENT_ID
- TEST_APP_ORG_PRIVATE_KEY
- TEST_USER_ORG_FG_PAT
- TEST_USER_USER_FG_PAT
- TEST_USER_PAT
- GITHUB_TOKEN

### Working Directory

- Initial: WorkingDirectory input (default '.')
- During script execution: tests/ (via Push-Location)
- After execution: Restored (via Pop-Location in finally)

### PowerShell Version

- PowerShell 7.4+ (provided by GitHub-Script)
- Modern PowerShell syntax allowed
- No PowerShell 5.1 compatibility required

## Error Handling Contract

### Mode "before" - Fail Fast

| Scenario | Action | Exit Code |
|----------|--------|-----------|
| Invalid mode | Write-Error + exit 1 | 1 |
| No tests directory | Write-Host + exit 0 | 0 |
| No script | Write-Host + exit 0 | 0 |
| Script error | Write-Error + throw | Non-zero |
| Script success | Write-Host + continue | 0 |

### Mode "after" - Continue on Error

| Scenario | Action | Exit Code |
|----------|--------|-----------|
| Invalid mode | Write-Error + exit 1 | 1 |
| No tests directory | Write-Host + exit 0 | 0 |
| No script | Write-Host + exit 0 | 0 |
| Script error | Write-Warning + continue | 0 |
| Script success | Write-Host + continue | 0 |

## Output Messages Contract

All messages must match this exact format:

| Message Type | Format | Example |
|-------------|--------|---------|
| Invalid mode | `Invalid mode '{mode}'. Mode must be 'before' or 'after'.` | `Invalid mode 'setup'. Mode must be 'before' or 'after'.` |
| No tests dir | `No tests directory found - exiting successfully` | N/A |
| Tests found | `Tests found at [{path}]` | `Tests found at [C:\repo\tests]` |
| No script | `No {scriptName} script found - exiting successfully` | `No BeforeAll.ps1 script found - exiting successfully` |
| Script start | `Running {BeforeAll\|AfterAll} {setup\|teardown} script: {path}` | `Running BeforeAll setup script: C:\repo\tests\BeforeAll.ps1` |
| Script success | `{BeforeAll\|AfterAll} script completed successfully: {path}` | `BeforeAll script completed successfully: C:\repo\tests\BeforeAll.ps1` |
| Script error (before) | `BeforeAll script failed: {path} - {error}` | `BeforeAll script failed: C:\repo\tests\BeforeAll.ps1 - Access denied` |
| Script error (after) | `AfterAll script failed: {path} - {error}` | `AfterAll script failed: C:\repo\tests\AfterAll.ps1 - Resource not found` |

## Testing Contract

The script must be testable via these scenarios:

1. **Test: Invalid mode**
   - Input: mode = "setup"
   - Expected: Error message, exit code 1

2. **Test: No tests directory**
   - Input: mode = "before", no tests/ folder
   - Expected: Success message, exit code 0

3. **Test: No BeforeAll.ps1**
   - Input: mode = "before", tests/ exists, no BeforeAll.ps1
   - Expected: Success message, exit code 0

4. **Test: No AfterAll.ps1**
   - Input: mode = "after", tests/ exists, no AfterAll.ps1
   - Expected: Success message, exit code 0

5. **Test: BeforeAll.ps1 succeeds**
   - Input: mode = "before", tests/BeforeAll.ps1 exists and succeeds
   - Expected: Success messages, exit code 0

6. **Test: BeforeAll.ps1 fails**
   - Input: mode = "before", tests/BeforeAll.ps1 exists and throws
   - Expected: Error message, exit code non-zero

7. **Test: AfterAll.ps1 succeeds**
   - Input: mode = "after", tests/AfterAll.ps1 exists and succeeds
   - Expected: Success messages, exit code 0

8. **Test: AfterAll.ps1 fails**
   - Input: mode = "after", tests/AfterAll.ps1 exists and throws
   - Expected: Warning message, exit code 0

9. **Test: Working directory restored**
   - Input: Any valid mode and script
   - Expected: Pop-Location always called (verify in finally block)

10. **Test: Environment variables accessible**
    - Input: Script that reads environment variables
    - Expected: Variables accessible in script execution context

## Compatibility Contract

### Differences from Current Implementation

| Aspect | Current (Test-ModuleLocal.yml) | New (setup-test action) |
|--------|-------------------------------|-------------------------|
| Script discovery | Recursive (nested directories) | Root tests folder only |
| Multiple scripts | Processes all found scripts | Single script per mode |
| Find-TestDirectories | Helper function included | Not needed (root only) |
| Processed directories tracking | Tracks unique directories | Not needed (single script) |
| Output format | LogGroup with iteration details | LogGroup with single script |

### Breaking Changes

1. **Nested script support removed**: Only tests/BeforeAll.ps1 and tests/AfterAll.ps1 are supported
   - Migration: Consolidate nested scripts into root tests/ folder
   - Rationale: Per clarification session, nested scripts not required

2. **Single script execution**: Only one BeforeAll.ps1 and one AfterAll.ps1 per repository
   - Migration: Merge multiple scripts into single consolidated script
   - Rationale: Simplifies implementation and matches common use case

### Preserved Behaviors

1. **Error handling**: mode="before" throws, mode="after" warns - unchanged
2. **Working directory**: Push-Location/Pop-Location pattern - unchanged
3. **Environment variables**: All secrets accessible - unchanged
4. **Output format**: LogGroup wrapper with status messages - unchanged
5. **Missing directory/script handling**: Success with messages - unchanged

---
**Script Contract Complete**: Ready for implementation and testing.
