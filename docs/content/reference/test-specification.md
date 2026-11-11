# PowerShell Function Test Specification

## Overview

This specification defines the Pester test hierarchy, input guidance, and coverage requirements for PowerShell functions.

## Test Structure

Organize each function's Pester tests in the following hierarchy:

### 1. Module-Level `Describe`

- The outermost `Describe` block corresponds to the module.
- Use the prefix of the function name's noun part as the module name.

### 2. Function-Level `Describe`

- Give each function in the module its own `Describe` block.
- Use the full function name as the block name.

### 3. Use Case `Context`

- Group each use case in a `Context` block.
- The context name starts with the function name followed by a descriptive test case identifier.
  - Example: `Get-Uri - simple usage`
  - Example: `Get-Uri - Pipeline usage`
  - Example: `Get-Uri - ParameterSet: Detailed`

### 4. Functional `It` Statements

- Each `It` block tests one aspect of the function's behavior.
- The name follows the format: `FunctionName - <expected behavior>`
  - Example: `Get-Uri - gets the URI object when provided a string`
  - Example: `Get-Uri - returns $null when input is empty`
  - Example: `Get-Uri - throws error on invalid input`

### 5. Test Guidelines

- **No Mocks**: Do not use mocks in tests.
- **Real Inputs**: Tests should use actual inputs and expected outputs.
- **Comprehensive Coverage**: Tests must cover all function behavior, including edge cases.

## Example Test Structure

```pwsh
Describe 'Uri' {
    Describe 'Get-Uri' {
        Context 'Get-Uri - simple usage' {
            It 'Get-Uri - gets the URI object when provided a string' {
                $result = Get-Uri -InputString 'https://example.com'
                $result | Should -BeOfType [System.Uri]
            }
        }

        Context 'Get-Uri - Pipeline usage' {
            It 'Get-Uri - processes input from the pipeline' {
                $result = 'https://example.com' | Get-Uri
                $result | Should -BeOfType [System.Uri]
            }
        }
    }
}
```

The example groups `Get-Uri` tests under the `Uri` module and uses separate contexts for direct and pipeline input.
