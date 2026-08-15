---
title: Calling the workflow
description: How to call the Process-PSModule reusable workflow — the caller workflow, passing test secrets and variables with TestData, and important-file change detection.
---

# Calling the workflow

To use the workflow, create a new file in the `.github/workflows` directory of the module repository and add the following content.
For documentation site generation, use `zensical.toml` as the active site contract.

For the exact inputs, secrets, and permissions the reusable workflow declares, see
[Workflow inputs](../reference/workflow-inputs.md).

<details>
<summary>Workflow suggestion</summary>

```yaml
name: Process-PSModule

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
    types:
      - closed
      - opened
      - reopened
      - synchronize
      - labeled
      - unlabeled

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: false

permissions:
  contents: write
  pull-requests: write
  statuses: write
  pages: write
  id-token: write

jobs:
  Process-PSModule:
    if: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
```

</details>

Stable releases are evaluated from a push to the default branch. A merged pull request supplies its version label and
release notes; a direct default-branch push or a manual dispatch uses the default `Patch` bump and commit-based notes.
Keep the `pull_request` trigger for CI, prereleases, and prerelease cleanup.

The concurrency key keeps a pull request distinct from a default-branch push, so the close-event cleanup and the
resulting stable release do not serialize as one run. Keep `cancel-in-progress: false`: a release-capable run mutates
the PowerShell Gallery, GitHub Releases, and tags, so later runs must queue rather than interrupt it.
The reusable workflow uses its own prefixed concurrency group, so it cannot queue behind the caller while the caller
waits for it to finish.

`Process-PSModule` is PSModule-owned automation, so callers use the controlled floating major tag (`@v8`). Compatible
patch and minor releases move that tag through the release workflow. A breaking release publishes a new major tag and
uses a deliberate fleet campaign rather than moving `v8` across the breaking boundary. External actions remain pinned
to full commit SHAs.

The job condition skips fork-originated pull requests because GitHub does not expose the required repository secrets to
forks. Use a separate secret-free, read-only workflow if the repository accepts contributions from forks and requires
fork CI.

## Passing test data

The reusable workflow at `.github/workflows/workflow.yml` declares four workflow-call secrets,
which keeps the calling workflow in full control of the credentials that are exposed.
`secrets: inherit` is intentionally not required. `PSGALLERY_API_KEY` publishes to the PowerShell Gallery,
`GitHubAppClientId` and `GitHubAppPrivateKey` authenticate GitHub API operations, and `TestData`
carries everything the module's own tests need.

### Breaking change: fixed test secrets use `TestData`

The reusable workflow accepts test data through `TestData` and no longer declares or accepts the old fixed test-secret inputs:

- `TEST_APP_ENT_CLIENT_ID`
- `TEST_APP_ENT_PRIVATE_KEY`
- `TEST_APP_ORG_CLIENT_ID`
- `TEST_APP_ORG_PRIVATE_KEY`
- `TEST_USER_ORG_FG_PAT`
- `TEST_USER_USER_FG_PAT`
- `TEST_USER_PAT`

If a caller passed any of these secrets directly, place them in the `secrets` map inside `TestData`.
The environment variable names used by the tests can stay the same; only the workflow-call interface
changes:

```yaml
jobs:
  Process-PSModule:
    if: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
      TestData: >-
        { "secrets": { "TEST_USER_PAT": "${{ secrets.TEST_USER_PAT }}",
        "TEST_APP_ORG_CLIENT_ID": "${{ secrets.TEST_APP_ORG_CLIENT_ID }}" } }
```

### Passing test phase data (secrets and variables)

A single `TestData` secret lets a module expose any number of caller-defined values to its test jobs
(`BeforeAll-ModuleLocal`, `Test-ModuleLocal` and `AfterAll-ModuleLocal`) without changing the shared
workflow. It is one JSON object with two maps, so everything the tests need is visible in one place:

```json
{ "secrets": { "NAME": "value" }, "variables": { "NAME": "value" } }
```

Values under `secrets` are masked in the logs; values under `variables` are not. Build it in the
calling workflow and pass it through the `secrets:` block (so the whole blob is masked). Reference each
secret directly as `"${{ secrets.<name> }}"` and each variable as `${{ toJSON(vars.<name>) }}`. A
folded `>-` scalar keeps the source readable while producing a single-line value, as long as the JSON
content lines stay at the same indentation level:

```yaml
jobs:
  Process-PSModule:
    if: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
      TestData: >-
        { "secrets": { "CONFLUENCE_API_TOKEN": "${{ secrets.CONFLUENCE_API_TOKEN }}" },
        "variables": { "CONFLUENCE_SITE": ${{ toJSON(vars.CONFLUENCE_SITE) }},
        "CONFLUENCE_USERNAME": ${{ toJSON(vars.CONFLUENCE_USERNAME) }},
        "CONFLUENCE_SPACE_KEY": ${{ toJSON(vars.CONFLUENCE_SPACE_KEY) }} } }
```

Each entry becomes an environment variable in the test jobs, so the module's Pester tests read the
values directly:

```powershell
$env:CONFLUENCE_API_TOKEN     # from the "secrets" map (masked in logs)
$env:CONFLUENCE_SITE          # from the "variables" map (not masked)
```

The same `TestData` keys are exported before every module-local phase runs:

- `BeforeAll-ModuleLocal` runs root `tests/BeforeAll.ps1` before the module-local test matrix.
- `Test-ModuleLocal` discovers and runs module-local Pester tests recursively.
- `AfterAll-ModuleLocal` runs root `tests/AfterAll.ps1` after the module-local test matrix, including cleanup paths.

Setup and teardown detection is not recursive. These root scripts and the discovered tests should use the same environment variable names.
If `$env:<name>` is available in one phase but missing in another, treat that as a Process-PSModule
propagation bug rather than a caller contract difference.

Notes:

- The names are caller-defined; no secret or variable names are hard-coded in the shared workflow.
  Names must match `^[A-Za-z_][A-Za-z0-9_]*$` and must not override reserved variables such as `PATH`,
  `CI`, `GITHUB_*`, `RUNNER_*` or `ACTIONS_*`.
- The `TestData` validation, masking and environment export logic is shared by the ModuleLocal workflows
  through the [`PSModule/Install-PSModuleHelpers`](https://github.com/PSModule/Install-PSModuleHelpers)
  action, which installs the `Import-TestData` command each workflow runs to expose the values.
- Reference secrets as `"${{ secrets.<name> }}"` (quoted, directly) rather than
  `toJSON(secrets.<name>)`. The direct form keeps CodeQL's *excessive secrets exposure* check happy and
  works for single-line secret values. It cannot carry values that contain `"`, `\` or newlines, so
  base64-encode a multi-line or special-character secret and decode it in the test (for example
  `[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:MY_KEY_B64))`).
- Variables use `toJSON(vars.<name>)` so any characters are JSON-encoded safely; they are never masked.
  You can use the same quoted direct form as secrets (`"${{ vars.<name> }}"`) only for simple values
  that do not contain `"`, `\` or newlines.
- Provide `TestData` as a single-line value (the folded `>-` block above does this). Avoid a literal
  `|` block: GitHub registers every line of a multi-line secret as its own mask, which over-masks
  unrelated log output.
- Do not pretty-print `TestData` with nested indentation. YAML preserves more-indented lines inside a
  folded scalar, so a fully formatted JSON object can still become a multi-line secret. That makes
  GitHub register each line as its own mask, including brace-only lines such as `{`, `}` or `},`, which
  can turn unrelated log output into `***`. Keep the compact form above, or keep every JSON content
  line at the same indentation level.
- Omit `TestData` entirely when the module needs no secrets or variables. Include only the map you
  need (just `secrets`, just `variables`, or both).
- Because `secrets: inherit` is not used, only the values you list are ever exposed.
- If using `secrets: inherit` in a caller workflow, remember that GitHub only forwards secrets that
  already exist by name. It does not assemble a `TestData` JSON payload from individual secrets such as
  `TEST_USER_PAT`; the caller must still create and pass the `TestData` value explicitly.
- Organization and repository secrets and variables are supported when they are visible to the calling job.
  GitHub Environment secrets are not supported by this caller contract because a job that calls a reusable
  workflow cannot declare `environment:`.

## Important file change detection

The workflow automatically detects whether a pull request or default-branch push contains changes to "important" files
that should enter the build, test, and publish path. This prevents unnecessary work and releases when only files outside
the configured patterns are modified.

### Files that trigger the important-change path

By default, the following regular expression patterns identify important files:

| Pattern | Description |
| :--- | :---------- |
| `^src/` | Module source code |
| `^README\.md$` | Module documentation |

### Customizing important file patterns

To override the default patterns, set `ImportantFilePatterns` in your settings file (`.github/PSModule.yml`):

```yaml
ImportantFilePatterns:
  - '^src/'
  - '^README\.md$'
  - '^tests/'
  - '^\.github/PSModule\.yml$'
  - '^\.github/workflows/'
```

When configured, the provided list fully replaces the defaults. Include the default patterns in your list if you still
want them to trigger the build, test, and publish path.

Recursive [module-local test discovery](writing-module-tests.md#test-discovery) does not change this trigger.
With the defaults, a test-only change does not run the important-change build, test, and publish stages because
`^tests/` is not matched. Add `^tests/` when those changes must exercise the path, plus each settings, workflow, or
other automation path whose changes need the same validation. Include only paths that should trigger all three stages.

To disable file-change triggering entirely (so that no file changes ever trigger a release), set an empty list in the
settings file:

```yaml
ImportantFilePatterns: []
```

You can also pass patterns via the workflow input:

```yaml
jobs:
  Process:
    if: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
    with:
      ImportantFilePatterns: |
        ^src/
        ^README\.md$
        ^examples/
```

To disable triggering via the workflow input, pass an explicit empty string:

```yaml
jobs:
  process:
    if: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
    with:
      ImportantFilePatterns: ''
```

Note that omitting the `ImportantFilePatterns` key entirely causes the workflow's default patterns (`^src/` and
`^README\.md$`) to be used. The settings file takes priority over the workflow input, so set
`ImportantFilePatterns: []` in `.github/PSModule.yml` to disable triggering regardless of the workflow input.

Resolution order: settings file → workflow input → workflow input default values.

### Behavior when no important files are changed

When a pull request does not contain changes to important files:

1. A comment is automatically added to the PR listing the configured patterns and explaining why build/test stages are
   skipped
2. `Settings.Publish.Module.Resolution.ReleaseType` is `None` (and `Settings.Publish.Module.Resolution.CreateRelease` is `false`)
3. Build, test, and publish stages are skipped
4. The PR can still be merged for non-release changes (documentation updates, CI improvements, etc.)

This behavior ensures that maintenance PRs (such as updating GitHub Actions versions or fixing typos in comments)
don't create unnecessary releases in the PowerShell Gallery.
