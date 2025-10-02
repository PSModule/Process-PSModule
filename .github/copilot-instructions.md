# Process-PSModule Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-10-01

## Active Technologies

- PowerShell 7.4+ (GitHub Actions composite actions) + PSModule/GitHub-Script@v1, PSModule/Install-PSModuleHelpers@v1 (001-building-on-this)

## Project Structure

```plaintext
src/
tests/
```

## Commands

Add commands for PowerShell 7.4+ (GitHub Actions composite actions)

## Code Style

PowerShell 7.4+ (GitHub Actions composite actions): Follow standard conventions

## Recent Changes

- 001-building-on-this: Added PowerShell 7.4+ (GitHub Actions composite actions) + PSModule/GitHub-Script@v1, PSModule/Install-PSModuleHelpers@v1

<!-- MANUAL ADDITIONS START -->

## Terminal Commands

When executing terminal commands (using `run_in_terminal` or similar tools):
- **ALWAYS** prefix shell commands with `pwsh` unless it's a GitHub MCP call
- This applies to all PowerShell scripts, git commands, and other shell operations
- Exception: GitHub MCP Server calls should use their native format without `pwsh` prefix

Examples:
```bash
# Correct - PowerShell script
pwsh -Command "& './.specify/scripts/powershell/setup-plan.ps1' -Json"

# Correct - Git command
pwsh -Command "git status"

# Correct - Any shell command
pwsh -Command "ls -Recurse"

# Exception - GitHub MCP calls (no pwsh prefix)
gh issue create --title "Feature" --body "Description"
```

## Other instructions

| Tech | Instruction file |
|------|------------------|
| PowerShell | [pwsh.instructions.md](./instructions/pwsh.instructions.md) |
| Markdown | [md.instructions.md](./instructions/md.instructions.md) |

<!-- MANUAL ADDITIONS END -->
