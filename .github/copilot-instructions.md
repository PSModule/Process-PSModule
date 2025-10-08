# GitHub Copilot Instructions for Process-PSModule

## Terminal Commands

When executing terminal commands (using `run_in_terminal` or similar tools):

- Prefer MCP server calls over command-line tools when possible.
- **ALWAYS** send commands into `pwsh -Command` to ensure proper execution.
  - These commands must be enclosed in single quotes.
  - Escape any single quotes within the command by doubling them (e.g., `It's` becomes `It''s`).
  - Use double quotes for string with variables or expressions inside the single-quoted command.

## Other instructions

| Tech | Instruction file |
|------|------------------|
| PowerShell | [pwsh.instructions.md](./instructions/pwsh.instructions.md) |
| Markdown | [md.instructions.md](./instructions/md.instructions.md) |
