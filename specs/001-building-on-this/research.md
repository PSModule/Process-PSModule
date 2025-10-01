# Research: Local GitHub Composite Action for BeforeAll/AfterAll Test Scripts

**Feature**: 001-building-on-this
**Date**: October 1, 2025

## Overview

This document consolidates research findings for creating a local GitHub composite action to encapsulate the BeforeAll and AfterAll test setup/teardown logic currently inline in Test-ModuleLocal.yml.

## Research Tasks

### Task 1: GitHub Composite Action Structure and Syntax Best Practices

**Decision**: Use GitHub composite action format with a single action that accepts a mode parameter to control behavior.

**Rationale**:
- Composite actions are ideal for encapsulating reusable workflow steps
- Single action with mode parameter (before/after) is cleaner than two separate actions
- Composite actions support inputs, environment variables, and can call other actions
- Local composite actions don't require publishing to marketplace

**Alternatives Considered**:
- Separate actions for BeforeAll and AfterAll: Rejected due to code duplication
- Reusable workflow instead of composite action: Rejected because composite actions are more lightweight for step-level reuse
- JavaScript/TypeScript action: Rejected because PowerShell logic is already implemented and tested

**Key Patterns**:
```yaml
name: 'Action Name'
description: 'Action description'
inputs:
  parameter-name:
    description: 'Parameter description'
    required: true/false
    default: 'value'
runs:
  using: 'composite'
  steps:
    - name: Step Name
      shell: bash
      run: |
        echo "Commands"
    - uses: other/action@v1
      with:
        input: value
```

**References**:
- GitHub Actions documentation: Creating composite actions
- Current inline implementation in Test-ModuleLocal.yml (lines 67-158, 234-314)

### Task 2: Error Handling Patterns in GitHub Composite Actions

**Decision**: Use mode parameter to control error handling behavior:
- Mode "before": Standard error propagation (script failures fail the job)
- Mode "after": Continue on error (log warnings but complete successfully)

**Rationale**:
- BeforeAll scripts must fail the workflow if setup fails (tests can't run without proper setup)
- AfterAll scripts should not fail the workflow (cleanup is best-effort, workflow may already be failing)
- Current implementation uses try/catch with throw for BeforeAll, Write-Warning for AfterAll
- Composite actions naturally propagate exit codes unless explicitly handled

**Alternatives Considered**:
- `continue-on-error: true` at step level: Not granular enough (applies to entire step)
- `if: always()` with exit code manipulation: More complex than try/catch pattern
- Separate error handling in caller workflow: Violates encapsulation principle

**Implementation Pattern**:
```powershell
# Mode "before" - throw on error
try {
    & $beforeAllScript
} catch {
    Write-Error "BeforeAll script failed: $_ "
    throw
}

# Mode "after" - warn on error
try {
    & $afterAllScript
} catch {
    Write-Warning "AfterAll script failed: $_"
    # Don't throw - continue execution
}
```

**References**:
- Current Test-ModuleLocal.yml implementation (lines 136-143 for BeforeAll, lines 290-296 for AfterAll)
- GitHub Actions error handling documentation

### Task 3: Mode/Parameter-Based Behavior Patterns in Reusable Actions

**Decision**: Use a required "mode" input parameter with validation and conditional logic.

**Rationale**:
- Single source of truth for script discovery and execution logic
- Mode parameter controls: script name (BeforeAll.ps1 vs AfterAll.ps1) and error handling behavior
- Reduces maintenance burden compared to duplicate actions
- Clear contract: mode must be "before" or "after"

**Alternatives Considered**:
- Two separate actions: Rejected due to 90% code duplication
- Auto-detect mode from context: Rejected as too implicit and error-prone
- Mode with default value: Rejected to enforce explicit caller intent

**Implementation Pattern**:
```yaml
inputs:
  mode:
    description: 'Script execution mode: "before" or "after"'
    required: true

steps:
  - name: Execute Script
    shell: pwsh
    run: |
      $scriptName = if ('${{ inputs.mode }}' -eq 'before') { 'BeforeAll.ps1' } else { 'AfterAll.ps1' }
      # Use $scriptName for discovery and execution
```

**References**:
- PSModule action patterns (GitHub-Script, Install-PSModuleHelpers)
- Action input validation best practices

### Task 4: Integration Patterns for PSModule Actions

**Decision**: Use PSModule/GitHub-Script@v1 for PowerShell execution with PSModule/Install-PSModuleHelpers@v1 for dependencies.

**Rationale**:
- Maintains consistency with current Test-ModuleLocal.yml implementation
- GitHub-Script provides LogGroup helper for formatted output
- GitHub-Script handles PowerShell version and environment setup
- Install-PSModuleHelpers ensures required modules are available
- Both actions are already used in BeforeAll-ModuleLocal and AfterAll-ModuleLocal jobs

**Alternatives Considered**:
- Direct PowerShell execution with `shell: pwsh`: Loses LogGroup formatting and helper functions
- Custom PowerShell setup: Reinvents functionality already in PSModule/GitHub-Script
- Different action versions: Should use v1 for stability

**Integration Pattern**:
```yaml
steps:
  - uses: PSModule/Install-PSModuleHelpers@v1

  - uses: PSModule/GitHub-Script@v1
    env:
      # Pass all secrets as environment variables
    with:
      Name: Setup-Test
      ShowInfo: false
      ShowOutput: true
      Debug: ${{ inputs.Debug }}
      Verbose: ${{ inputs.Verbose }}
      Version: ${{ inputs.Version }}
      Prerelease: ${{ inputs.Prerelease }}
      WorkingDirectory: ${{ inputs.WorkingDirectory }}
      Script: |
        # PowerShell script here
```

**References**:
- PSModule/GitHub-Script@v1 action.yml
- PSModule/Install-PSModuleHelpers@v1 action.yml
- Current Test-ModuleLocal.yml usage (lines 70-82, 86-158, 240-252, 256-314)

### Task 5: Current Test-ModuleLocal.yml BeforeAll/AfterAll Implementation Analysis

**Decision**: Per clarification session, only support BeforeAll.ps1 and AfterAll.ps1 in the root tests folder, not nested directories.

**Rationale**:
- Clarification session confirmed: "Scripts only supported in root tests folder - no nested directory support"
- Current implementation searches nested directories but this is not the desired behavior
- Simplified implementation reduces complexity and maintenance
- Matches common use case (single setup/teardown per repository)

**Current Implementation Issues**:
- BeforeAll-ModuleLocal and AfterAll-ModuleLocal contain identical helper function `Find-TestDirectories`
- Both jobs iterate through all test folders and process scripts
- Logic is duplicated between the two jobs (160+ lines each)
- The recursive search adds unnecessary complexity

**Simplified Implementation**:
```powershell
# Only check root tests folder
$testsPath = Resolve-Path 'tests' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
if (-not $testsPath) {
    Write-Host 'No tests directory found - exiting successfully'
    exit 0
}

$scriptPath = Join-Path $testsPath "$scriptName"  # BeforeAll.ps1 or AfterAll.ps1
if (-not (Test-Path $scriptPath -PathType Leaf)) {
    Write-Host "No $scriptName script found - exiting successfully"
    exit 0
}

# Execute the script with appropriate error handling based on mode
```

**Migration Impact**:
- Existing repositories with nested BeforeAll/AfterAll scripts will need to consolidate to root tests folder
- This is a breaking change but aligns with clarified requirements
- Documentation will need to specify the single-script-per-type limitation

**References**:
- Feature spec clarifications (Session 2025-10-01)
- Test-ModuleLocal.yml lines 86-158 (BeforeAll) and 256-314 (AfterAll)
- FR-003, FR-004 from feature specification

## Technical Decisions Summary

| Decision Area | Choice | Key Rationale |
|--------------|--------|---------------|
| Action Type | Composite action with mode parameter | Reusability without code duplication |
| Error Handling | Mode-based: throw for "before", warn for "after" | Matches current behavior and use case requirements |
| Script Discovery | Root tests folder only (tests/BeforeAll.ps1, tests/AfterAll.ps1) | Clarification session decision, simplifies implementation |
| PowerShell Execution | PSModule/GitHub-Script@v1 | Consistency with existing implementation |
| Helper Dependencies | PSModule/Install-PSModuleHelpers@v1 | Required for PSModule helper functions |
| Action Location | `.github/actions/setup-test/action.yml` | Clarification session decision |
| Input Parameters | mode (required), Debug, Verbose, Prerelease, Version, WorkingDirectory | Matches Test-ModuleLocal.yml inputs |
| Environment Secrets | All test secrets passed as env vars | Required for script execution |

## Implementation Guidance

### Composite Action Structure

The composite action should:
1. Accept all required inputs (mode, configuration, secrets)
2. Call Install-PSModuleHelpers for dependencies
3. Call GitHub-Script with inline PowerShell that:
   - Wraps logic in LogGroup for formatted output
   - Checks for tests directory existence
   - Looks for script in root tests folder only (tests/BeforeAll.ps1 or tests/AfterAll.ps1)
   - Executes script with Push-Location/Pop-Location
   - Handles errors based on mode (throw vs warn)
   - Provides clear status messages

### Test-ModuleLocal.yml Integration

The workflow should:
1. Keep BeforeAll-ModuleLocal and AfterAll-ModuleLocal job structure
2. Replace inline GitHub-Script step with call to `.github/actions/setup-test`
3. Pass mode parameter ("before" or "after")
4. Pass through all inputs and secrets
5. Maintain `if: always()` on AfterAll-ModuleLocal job

### Testing Strategy

Validation should include:
1. Repository with no tests folder → success with appropriate message
2. Repository with tests folder but no BeforeAll.ps1/AfterAll.ps1 → success with appropriate message
3. Repository with BeforeAll.ps1 that succeeds → job succeeds
4. Repository with BeforeAll.ps1 that fails → job fails with error message
5. Repository with AfterAll.ps1 that succeeds → job succeeds
6. Repository with AfterAll.ps1 that fails → job succeeds with warning message
7. All secrets accessible in scripts
8. Output format matches current implementation

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Breaking change for nested scripts | High | Document requirement, provide migration guide |
| Error handling regression | High | Comprehensive testing of both modes |
| Secret exposure in logs | Medium | Use Write-Host not Write-Verbose for secret-related messages |
| Action version pinning | Low | Use @v1 tags for PSModule actions |

## Next Steps

This research informs Phase 1 design artifacts:
- data-model.md: Define composite action inputs/outputs contract
- contracts/: Define action.yml structure
- quickstart.md: Integration steps for Test-ModuleLocal.yml
- tasks.md: Implementation task breakdown

---
**Research Complete**: All technical decisions documented and justified. Ready for Phase 1 design.
