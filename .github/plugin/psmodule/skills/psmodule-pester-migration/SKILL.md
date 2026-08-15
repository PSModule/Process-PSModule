---
name: psmodule-pester-migration
description: Migrate every Pester test set in a PSModule repository to Pester 6.1.0, preserving test intent while checking runtime, discovery, setup, mocks, data-driven tests, coverage, CI, and reporting. Use when upgrading a PSModule repository from Pester 5 or earlier, or when validating a repository-wide Pester migration.
---

# Migrate PSModule tests to Pester 6.1.0

Use this skill to migrate a PSModule repository one test set at a time. Do not
change consumer repositories while developing or validating this skill.

The primary source is the official
[Pester v5-to-v6 migration guide](https://pester.dev/docs/migrations/v5-to-v6).
The two [Awesome Copilot skills](https://github.com/github/awesome-copilot/tree/main/skills)
are secondary practical guidance only. If this skill and the official guide
differ, follow the official guide and record the decision.

## Compatibility boundary

The target is **Pester 6.1.0** on **Windows PowerShell 5.1** or **PowerShell
7.4 or later**. Upgrade one major version at a time when the source is older:
v3 to v4, v4 to v5, then v5 to v6. Do not combine unrelated test refactoring
with compatibility fixes.

Required compatibility work:

- Install and run Pester 6.1.0 on every supported runtime and CI image.
- Make every test file self-contained under v6's per-file discovery-and-run
  model. Put discovery-only data loading in `BeforeDiscovery`.
- Review hidden files and directories, including dot-prefixed paths and
  Windows Hidden items. Exclude intentional non-tests with `Run.ExcludePath`.
- Fix empty or `$null` `-ForEach` and `-TestCases`; use
  `-AllowNullOrEmptyForEach` only when empty data is intentional.
- Combine duplicate `BeforeAll`, `BeforeEach`, `AfterAll`, or `AfterEach`
  blocks in the same scope.
- Replace removed `Assert-MockCalled` and `Assert-VerifiableMock`.
- Add a default mock when a parameter-filtered mock must handle other calls.
- Review `<...>` name templates because their contents are now expressions.
- Replace `Set-ItResult -Pending` with `-Inconclusive`, `-Skipped`, or
  `It -Skip`.
- Review coverage tracer and output format settings.
- Replace removed v4-style `Invoke-Pester` parameters with
  `New-PesterConfiguration`.
- Rename a real `None` tag; in v6 it is reserved for untagged tests.

Optional v6 adoption after compatibility is green:

- Convert classic `Should -Be` assertions to `Should-Be` commands
  incrementally. Classic syntax remains supported.
- Enable `Run.Shuffle` only after proving order independence.
- Enable experimental `Run.Parallel` only after proving file isolation and
  parallel-safe resources.
- Enable `Debug.ShowStartMarkers` for diagnostic runs.

Never present optional adoption as required migration work.

## Step 1: Inventory the repository and test sets

Before editing, record the repository, branch, supported PowerShell versions,
CI workflow files, Pester installation source, and every test entry point.
Search the whole repository, not just `tests/`; framework tests, action tests,
source tests, generated test fixtures, and nested suites can use different
configuration.

```powershell
Get-ChildItem -Force
Get-ChildItem -Force -Recurse -File -Include *.Tests.ps1,*.Configuration.ps1,*.Container.ps1
Get-ChildItem -Force -Recurse -File -Include *.yml,*.yaml,*.ps1,*.psd1,*.psm1 |
    Select-String -Pattern 'Pester|Invoke-Pester|Should|BeforeDiscovery|BeforeAll|Mock'
```

For each test set, add an inventory row to the migration report:

| Field | Record |
| --- | --- |
| Test set | Relative path and purpose |
| Entry point | Workflow, action, script, or local command |
| Discovery paths | Explicit paths, recursive paths, containers, configurations |
| Pester source | Required module version, install step, lock or floating policy |
| Runtime matrix | Windows PowerShell 5.1 and/or PowerShell 7.4+ |
| Setup | Root `BeforeAll.ps1`, `Pester.BeforeContainer.ps1`, file setup |
| Data | `-ForEach`, `-TestCases`, external files, generated cases |
| Mocks | Filtered mocks, mock assertions, shared state |
| Coverage/results | Paths, formats, thresholds, uploaded artifacts |
| Baseline | Run command, result counts, known failures |

Use the inventory to find test sets that are not reachable from the default
workflow. A green workflow is not evidence that every test set was migrated.

## Test-state and data contract

Treat the test runner's prepared state as a contract, not an implementation
detail. A module-local Pester test must assume that the target, built module is
already loaded by the framework. It must not silently call `Import-Module`,
`Install-Module`, `Install-PSModule`, or dot-source the target module as a
fallback when the framework did not prepare it. A hidden import can make local
tests pass while the real workflow is misconfigured and can change the module
version or process state being tested.

This does not prohibit a test whose explicit subject is module import,
manifest validity, or module removal. Such a framework or contract test should
say so in its name and use a deliberate, isolated import as the behavior under
test. It must not become setup for unrelated tests.

Every additional fixture is also part of the test-state contract. A test set
must explicitly load its own JSON, CSV, XML, PSD1, script, or generated data,
or document which setup phase provides it. In particular, a PSD1 dataset is
not automatically loaded because it is in the repository:

```powershell
BeforeDiscovery {
    $cases = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'Data\Cases.psd1')
}
```

Record fixture ownership and availability in the inventory:

| Fixture or state | Owner | Loaded in | Required environment |
| --- | --- | --- | --- |
| Target module | Process-PSModule or explicit contract test | Framework pre-run | Built module path and version |
| PSD1/JSON/CSV data | Test set or documented setup | `BeforeDiscovery`, `BeforeAll`, or setup job | Relative path and encoding |
| Secrets/variables | Calling workflow | `Expose-TestData` and environment | `TestData` JSON contract |
| Shared service | `tests/BeforeAll.ps1` | Before module-local matrix | Deterministic run-scoped name |
| Cleanup state | `tests/AfterAll.ps1` | Always-run teardown | Same `TestData` and run identity |

Fail loudly when required data or state is absent. Do not use a broad
`try/catch`, an empty default, or an implicit import to turn a missing fixture
into a passing or skipped test.

## Process-PSModule test-adjacent surfaces

For every consumer repository, trace and record these surfaces before editing:

| Surface | Framework contract to verify | Migration check |
| --- | --- | --- |
| `PSModule/Invoke-Pester` | Installs/runs Pester and emits per-suite JSON results and coverage artifacts | Pin/verify Pester 6.1.0, map all inputs to v6 configuration, preserve suite names |
| `Test-PSModule` action | Selects `tests/Module` or `tests/SourceCode`, resolves `outputs/module` or `src`, and passes paths to `Invoke-Pester` | Confirm path selection, exclusions, module state, and test extension |
| Module-local workflow | Downloads the built module, exposes `TestData`, imports the module, then runs module tests | Tests consume the prepared module; no hidden fallback import |
| Source-code workflow | Runs source tests against the checked-out `src` path | Record how source functions/classes are loaded and which fixtures are explicit |
| `BeforeAll-ModuleLocal` | Runs exact root `tests/BeforeAll.ps1` once before module-local jobs | Put shared services/data here only when every matrix job needs them |
| `AfterAll-ModuleLocal` | Runs exact root `tests/AfterAll.ps1` with `always()` | Make cleanup safe after setup/test failure |
| `Expose-TestData` | Converts caller `TestData` JSON into environment variables | Inventory every required variable; do not confuse it with repository fixtures |
| `Get-PesterTestResults` | Downloads `*-TestResults`, expects every configured suite, and fails missing/unexecuted/failed/inconclusive results | Preserve `TestSuiteName`, matrix names, and result counts |
| `Get-PesterCodeCoverage` | Aggregates `*-CodeCoverage` JSON and writes missed-path reports and summaries | Verify JaCoCo/Cobertura format, target, paths, and v6 tracer behavior |
| `Invoke-ScriptAnalyzer` integration | Publishes `PSModuleLint-*` results alongside test results | Treat lint suites as required result artifacts, not Pester test files |
| Repository linter | Checks repository/workflow/Markdown files independently of Pester | Include skill and documentation paths in the repository lint inventory |

The current Process-PSModule flow specifically downloads the built module and
imports it before module-local tests, while `Test-PSModule` resolves source or
module paths for framework suites. The framework's own importability and
manifest tests may import/remove the module because import is their subject;
ordinary consumer tests must not copy that pattern as setup.

Record the `PSModule/Invoke-Pester` action revision separately from the Pester
module version. The current Process-PSModule workflows reference that action at
`v5.1.0`; its revision and its Pester installation policy must both be checked
when adopting Pester 6.1.0. Updating one does not prove that the other changed.

Use this per-repository checklist:

- [ ] All `*.Tests.ps1`, `*.Configuration.ps1`, and `*.Container.ps1` files,
  including action and hidden paths, are listed.
- [ ] Each test set is mapped to `Module`, `SourceCode`, action, or external
  invocation and its `Run.Path`/`Run.ExcludePath` is recorded.
- [ ] The built target module is loaded by the framework before module-local
  tests; tests do not silently load it themselves.
- [ ] Source-code test loading is explicit and documented separately from the
  module-local contract.
- [ ] Every PSD1, JSON, CSV, XML, script, generated fixture, secret, variable,
  and service dependency has an owner and loading phase.
- [ ] `BeforeAll.ps1`, `AfterAll.ps1`, and `Pester.BeforeContainer.ps1` paths
  and scope are recorded.
- [ ] `Invoke-Pester` action inputs, Pester version, suite names, result paths,
  coverage paths, filters, and output formats are recorded.
- [ ] `Get-PesterTestResults` expected artifact names include source, framework,
  module, and linter suites.
- [ ] Coverage aggregation and its missed-path report are validated.
- [ ] Local, CI, and linter runs use the same intended fixture and module state.

## Step 2: Check versions, runtime, and CI

Run the baseline on the current version before changing files. Save the command,
Pester version, runtime, OS, result counts, and known failures.

```powershell
Get-Module Pester -ListAvailable | Sort-Object Version -Descending |
    Select-Object Name, Version, Path
(Get-Module Pester).Version
$PSVersionTable | Select-Object PSVersion, PSEdition, OS
Invoke-Pester -Path ./tests -Output Detailed
```

Pin the target during migration so local and CI results are comparable:

```powershell
Install-Module Pester -RequiredVersion 6.1.0 -Force
Import-Module Pester -RequiredVersion 6.1.0 -Force
```

On Windows PowerShell 5.1, use `-SkipPublisherCheck` only when required to
install a newer Pester beside the inbox Pester 3. Do not hide an installation
failure. Verify the imported module is 6.1.0, not merely that a 6.x package is
available.

Update each CI installation and invocation. Prefer an explicit requirement in
test files when that is the repository convention:

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0'; MaximumVersion = '6.1.0' }
```

If the repository intentionally floats patch releases within the major, record
that policy and use `ModuleVersion = '6.0.0'; MaximumVersion = '6.*'` instead.
The migration acceptance run must still use 6.1.0.

## Step 3: Migrate discovery, setup, and isolation

Pester 6 discovers and runs one file before moving to the next. A file cannot
depend on top-level state created while another file was discovered. Import
modules and define file-local discovery data in the file that uses them:

```powershell
BeforeDiscovery {
    $cases = Get-Content -Raw -Path (Join-Path $PSScriptRoot 'cases.json') |
        ConvertFrom-Json
}

BeforeAll {
    # Consume the module loaded by the framework.
    $command = Get-Command -Name Get-MyThing -ErrorAction Stop
}

Describe 'My command' {
    It 'handles <Name>' -ForEach $cases {
        Get-MyThing -Name $Name | Should -Be 'ok'
    }
}
```

Use `$PSScriptRoot` for fixture paths. Do not rely on
`$MyInvocation.MyCommand.Path`, the current directory, another test file's
variables, or discovery order. If the command check fails, fix the workflow's
module preparation rather than adding an import to this test.
Repository-wide bootstrap that every worker needs belongs in
`Pester.BeforeContainer.ps1` at the repository root. Keep it deterministic and
idempotent.

Check the complete recursive path set. Pester 6 includes hidden files and
directories by default, while `.git`, `.svn`, and `.hg` remain excluded. A
newly discovered hidden test is an intended compatibility change: fix it or
exclude it explicitly, rather than assuming it should remain invisible.

For every test set, run one file directly and then the complete set. This
isolates discovery failures from cross-file assumptions:

```powershell
Invoke-Pester -Path ./tests/Example.Tests.ps1 -Output Detailed
Invoke-Pester -Path ./tests -Output Detailed
```

## Step 4: Fix v6 breaking changes

### Data-driven tests

Pester 6 throws for `$null` or an empty `-ForEach`/`-TestCases`. Prefer fixing
the data-loading path. If empty data is a valid result, state that intent:

```powershell
Describe 'Optional cases' -ForEach $cases -AllowNullOrEmptyForEach {
    It 'runs when a case exists' {}
}
```

Use the local opt-in before the run-wide
`$config.Run.FailOnNullOrEmptyForEach = $false`; the latter can hide a broken
data source.

### Setup and teardown blocks

Each block can contain only one `BeforeAll`, `BeforeEach`, `AfterAll`, and
`AfterEach` at its scope. Combine duplicate blocks and preserve their required
ordering explicitly. Do not move discovery-time test generation into
`BeforeAll`; use `BeforeDiscovery` for that.

### Mocks

Replace removed assertions:

```powershell
# Old
Assert-MockCalled Get-Thing -Times 1 -Exactly
Assert-VerifiableMock

# v6
Should -Invoke Get-Thing -Times 1 -Exactly
Should -InvokeVerifiable
```

In v6, a call that matches no `-ParameterFilter` no longer falls through to
the real command. Add an unfiltered default mock when other calls are valid:

```powershell
Mock Get-Thing { 'default' }
Mock Get-Thing -ParameterFilter { $Name -eq 'a' } -MockWith { 'a' }
```

Keep mocks and their assertions in the scope where the code under test invokes
them. A migration must not accidentally allow a real external call.

### Pending tests

`Set-ItResult -Pending` is removed. Use the result that expresses the intent:

```powershell
It 'is not implemented yet' {
    Set-ItResult -Inconclusive -Because 'not implemented yet'
}
```

Use `-Skip` when the test must not run, and `-Inconclusive` when the result
should be reported for follow-up.

### Name templates

In v6, every `<...>` token in a `Describe`, `Context`, or `It` name is
evaluated as a PowerShell expression in the test scope. Review arithmetic,
method calls, and expressions that were literal in v5. Escape a leading `<`
when literal text is intended:

```powershell
It 'adds up to `<($a + $b)`>' -ForEach @{ a = 1; b = 2 } {}
```

Keep names stable and useful for CI result reporting.

### Tags

`None` is reserved, case-insensitively, to select tests with no inherited or
local tags. Rename a tag that relied on the old literal meaning and update
filters and reports.

### Coverage

Pester 6 uses the Profiler tracer by default and `CodeCoverage.UseBreakpoints`
defaults to `$false`. Keep the new default unless compatibility with historical
coverage numbers requires:

```powershell
$config.CodeCoverage.UseBreakpoints = $true
```

`CoverageGutters` is removed. Use `JaCoCo` or `Cobertura`; coverage paths are
already relative to `Run.RepoRoot`.

## Step 5: Standardize Invoke-Pester configuration

Legacy v4 parameters such as `-Script`, `-OutputFile`, `-OutputFormat`,
`-EnableExit`, and direct coverage switches are removed. Use one configuration
object for scripted and CI runs:

```powershell
$config = New-PesterConfiguration
$config.Run.Path = @('./tests')
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'

$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = './artifacts/pester-results.xml'
$config.TestResult.OutputFormat = 'NUnitXml'

$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @('./src')
$config.CodeCoverage.OutputFormat = 'JaCoCo'

Invoke-Pester -Configuration $config
```

Set `Run.ExcludePath` for intentional exclusions, and keep paths relative to
the repository root where CI and local runs share the same layout. Do not
disable failures globally to make a migration green.

## Step 6: Optional v6 features

Only after the serial suite matches the baseline may a repository evaluate:

```powershell
$config.Run.Shuffle = $true
$config.Run.Parallel = $true
```

`Run.Shuffle` detects order dependence. Fix order dependence rather than
permanently suppressing it. `Run.Parallel` is experimental and runs files in
separate runspaces. Prove that setup, mocks, environment variables, ports,
temporary paths, external resources, and cleanup are isolated. Use
`Pester.BeforeContainer.ps1` for shared bootstrap and `#pester:no-parallel`
only for a documented exception. Compare serial and parallel result counts and
artifacts.

The optional `Should-*` commands are a separate modernization. Classic
`Should -Be` remains valid in v6:

```powershell
$value | Should -Be 1       # compatible and may remain
$value | Should-Be 1        # optional v6 style
```

If converting, review behavior rather than applying a blind rename:

- `Should -Not -Be` becomes `Should-NotBe`.
- Truthy/falsy expectations may need `Should-BeTruthy` or `Should-BeFalsy`;
  strict boolean assertions are different.
- `Should -BeNullOrEmpty` has different intents: null, empty string, empty
  collection, or falsy.
- Collection comparisons use collection assertions and may need `-Actual`
  because pipeline input is unwrapped.
- `Should -Exist` and file-content assertions can remain classic.

Adopt this style incrementally and report intentionally unchanged assertions.

## Step 7: Validate and report

Run the migrated test set in this order:

1. Every discovered file directly, including hidden paths and files selected
   by configuration or container scripts.
2. Each test set serially with Pester 6.1.0.
3. Each supported PowerShell runtime and CI operating system.
4. Coverage and test-result generation with the same configuration CI uses.
5. Optional shuffle and parallel runs, only if the repository opted in.

For every run, record the command, runtime, Pester version, path, passed,
failed, skipped, inconclusive, not-run, coverage summary, and artifact paths.
Compare against the baseline and investigate changed counts. A report should
include:

```text
Repository:
Target: Pester 6.1.0
Test set:
Runtime / OS:
Baseline:
Serial result:
Coverage / result artifacts:
Required compatibility fixes:
Optional v6 features enabled:
Known limitations or deferred work:
```

Review the diff for test-intent changes, accidental real calls, path assumptions,
and generated artifacts before committing. Make small commits by file or
concern so a failed migration is easy to bisect.

## References

- [Pester v5-to-v6 migration](https://pester.dev/docs/migrations/v5-to-v6)
- [Pester installation and compatibility](https://pester.dev/docs/introduction/installation)
- [Pester configuration](https://pester.dev/docs/usage/configuration)
- [Pester data-driven tests](https://pester.dev/docs/usage/data-driven-tests)
- [Pester mocking](https://pester.dev/docs/usage/mocking)
- [Pester parallel execution](https://pester.dev/docs/usage/parallel)
- [Pester code coverage](https://pester.dev/docs/usage/code-coverage)
- [Pester test results](https://pester.dev/docs/usage/test-results)
- [Pester Should assertions](https://pester.dev/docs/assertions/should-command)
- [Awesome Copilot pester-migration](https://github.com/github/awesome-copilot/tree/main/skills/pester-migration)
- [Awesome Copilot pester-should-migration](https://github.com/github/awesome-copilot/tree/main/skills/pester-should-migration)
