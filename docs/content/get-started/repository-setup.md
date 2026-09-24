---
title: Repository setup
description: Configure GitHub Pages, `PSGALLERY_API_KEY`, permissions, and the caller workflow so Process-PSModule can build and publish the module.
---

# Repository setup

Do this once per module repository, after creating it from
[Template-PSModule](https://github.com/PSModule/Template-PSModule). The template supplies the initial repository
files and framework wiring; this guide verifies the standard baseline and configures its external services.

## 1. Complete the module repository baseline

Before configuring the pipeline:

1. Replace every template token, including the README and `.github/zensical.toml`.
2. Remove scaffold functions, tests, and examples that do not belong to the module.
3. Set the repository description and its `Type` custom property to `Module`; retain `main` as the default branch.
4. Confirm the required community, governance, agent, dependency-update, and workflow files are present.
5. Confirm the README follows the module start-page requirements, including `Install-PSResource` installation guidance.
6. Keep `.github/PSModule.yml` limited to settings that override the framework defaults.

[Repository standard](../reference/repository-standard.md) defines the required files, metadata, and README shape.

## 2. Enable GitHub Pages

Enable GitHub Pages in the repository settings and set it to deploy from **GitHub Actions**.

This creates an environment called `github-pages` that GitHub deploys the documentation site to.

<details><summary>Within the <code>github-pages</code> environment, remove the branch protection for <code>main</code>.</summary>
  <img src="../media/pagesEnvironment.png" alt="Remove the branch protection on main">
</details>

## 3. Configure workflow secrets

Create these repository or organization Actions secrets:

| Secret | Purpose |
| --- | --- |
| `PSGALLERY_API_KEY` | An [API key](https://www.powershellgallery.com/account/apikeys) authorized to manage the module on the PowerShell Gallery. |
| `SHELLY_CLIENT_ID` | The GitHub App client ID that the caller maps to `GitHubAppClientId`. |
| `SHELLY_PRIVATE_KEY` | The GitHub App private key that the caller maps to `GitHubAppPrivateKey`. |

Use a glob pattern for PowerShell Gallery API-key permissions and store `PSGALLERY_API_KEY` at the organization level
when several modules share it. For Dependabot pull requests, add all three secrets to the Dependabot secret store.
[GitHub App authentication](../guides/github-app-authentication.md) defines the App permissions and token boundaries.

## 4. Verify the caller workflow

The template supplies `.github/workflows/Process-PSModule.yml`. Replace the caller with this standard form:

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
  queue: ${{ github.event_name == 'pull_request' && 'single' || 'max' }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  Process-PSModule:
    permissions:
      contents: read
      pages: write
      id-token: write
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
```

Every permission on the calling job is required. GitHub App installation tokens perform repository writes. A push to
`main` publishes a stable release after the full pipeline passes; the pull-request trigger handles CI, prereleases,
and prerelease cleanup. See
[Workflow inputs](../reference/workflow-inputs.md) for what each permission is used for, and
[Calling the workflow](../guides/calling-the-workflow.md) for passing test secrets and variables.

The caller-level concurrency block retains production, dispatch, and scheduled work in the maximum native queue while
replacing obsolete activity for the same pull request. Its fallback expression uses the pull-request number for every
pull-request action, including `closed`; other events use their Git ref. Keep its group distinct from the reusable
workflow's prefixed group.

## 5. Configure the settings file

The template supplies `.github/PSModule.yml`. Keep only the overrides the module needs; an empty file is valid when a
hand-built repository needs no overrides:

```yaml
Name: null
```

See [Settings](../reference/settings.md) for the full contract and
[Configuring the pipeline](../guides/configuring-the-pipeline.md) for worked examples.

## 6. Configure the documentation site

The template builds documentation with [Zensical](https://zensical.org/) from `.github/zensical.toml`. Replace each
template token with the module's name, owner, and repository URL.

## Next

Open a pull request and let the pipeline run — see [Your first release](your-first-release.md).
