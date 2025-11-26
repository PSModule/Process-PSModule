# GitHub Copilot Instructions for Process-PSModule

## Terminal Commands

- Prefer MCP server calls over command-line tools when possible.
- When running scripts within the [scripts](../.specify/scripts/) folder, just run them directly (shell is default PowerShell).
- For other commands, send them into `pwsh -Command` to ensure proper execution.

### Quoting in PowerShell

Proper quoting is essential in PowerShell to prevent parsing errors and ensure correct command execution.

- **Direct script execution**: Scripts run directly in PowerShell use standard PowerShell quoting rules. Double quotes expand variables and expressions, while single quotes are literal. No additional shell escaping is needed.

- **Via `pwsh -Command`**: Commands are passed as strings to PowerShell. Enclose the entire command in single quotes to treat it as a literal string. Escape single quotes within the command by doubling them (e.g., `It's` becomes `It''s`). Use double quotes within the command for variable expansion, but ensure the outer single quotes protect the string from shell interpretation.

For arguments containing single quotes, prefer double-quoting the argument inside the command string.

Example: `pwsh -Command 'Write-Host "I''m Groot"'`
