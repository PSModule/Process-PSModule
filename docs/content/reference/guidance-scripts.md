---
title: PowerShell guidance scripts
description: Reference PowerShell scripts that demonstrate implementation patterns used by the PSModule framework.
---

# PowerShell guidance scripts

The [guidance directory](https://github.com/PSModule/Process-PSModule/tree/main/guidance) contains runnable reference scripts for common PowerShell implementation patterns. They are framework learning assets, not Process-PSModule module source, so they are intentionally kept outside `src/` and are not included in a module manifest.

Run an individual script only when its scenario is suitable for the local environment. Several scripts create temporary files, make web requests, or measure execution time.

| Script | Focus |
| --- | --- |
| `Add-Array.ps1` | Array and generic list population |
| `Add-HashTable.ps1` | Hashtable population styles |
| `Add-String.ps1` | String construction approaches |
| `Caller.ps1` | Caller discovery through the PowerShell call stack |
| `ClassExtension.ps1` | Class inheritance and base-method invocation |
| `Loops.ps1` | Loop and function-call overhead |
| `Out-Null.ps1` | Discarding command output |
| `PipelineExecution.ps1` | Pipeline parameter evaluation and lifecycle blocks |
| `PSCallStack.ps1` | Nested-call stack inspection |
| `PSCmdlet.ps1` | The `$PSCmdlet` variable at nested call levels |
| `PSModuleTest.psm1` | Module-component import and exports |
| `Read-File.ps1` | File-reading approaches |
| `root.ps1` | Nested PSScriptAnalyzer binary-module loading |
| `WebCalls.ps1` | Web-request protocol comparisons |

## Maintenance

The files were imported byte-for-byte from [`PSModule/docs/guidance`](https://github.com/PSModule/docs/tree/main/guidance). When that published set changes, import the complete current file from its Git blob into this directory and preserve its contents. Keep this index synchronized with the directory so users can discover every available script.
