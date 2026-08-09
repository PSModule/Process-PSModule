---
title: Workflow inputs
description: The inputs, secrets, and permissions declared by the Process-PSModule reusable workflow.
---

# Workflow inputs

The reusable workflow lives at `PSModule/Process-PSModule/.github/workflows/workflow.yml`. This page is the exact
interface it exposes to a caller workflow. For how to wire it up, see
[Calling the workflow](../guides/calling-the-workflow.md).

## Inputs

| Name | Type | Description | Required | Default |
| ---- | ---- | ----------- | -------- | ------- |
| `SettingsPath` | `string` | The path to the settings file. All workflow configuration is controlled through this settings file. | `false` | `.github/PSModule.yml` |
| `Debug` | `boolean` | Enable debug output. | `false` | `false` |
| `Verbose` | `boolean` | Enable verbose output. | `false` | `false` |
| `Version` | `string` | Specifies the version of the GitHub module to be installed. The value must be an exact version. | `false` | `''` |
| `Prerelease` | `boolean` | Whether to use a prerelease version of the 'GitHub' module. | `false` | `false` |
| `WorkingDirectory` | `string` | The path to the root of the repo. | `false` | `'.'` |
| `ImportantFilePatterns` | `string` | Newline-separated list of regular expression patterns that identify important files. Changes matching these patterns trigger build, test, and publish stages. When set, fully replaces the defaults. | `false` | `^src/\n^README\.md$` |

## Secrets

The workflow declares four workflow-call secrets, which keeps the calling workflow in full control of the
credentials that are exposed. `secrets: inherit` is intentionally not required.

| Name | Location | Description | Required |
| ---- | -------- | ----------- | -------- |
| `APIKey` | GitHub secrets | The API key for the PowerShell Gallery, used to publish the module. | Yes |
| `GitHubAppClientId` | GitHub secrets | The GitHub App client ID used to mint scoped installation tokens for GitHub API operations. Map Shelly's `SHELLY_CLIENT_ID` in the caller. | Yes |
| `GitHubAppPrivateKey` | GitHub secrets | The GitHub App private key used to mint scoped installation tokens for GitHub API operations. Map Shelly's `SHELLY_PRIVATE_KEY` in the caller. | Yes |
| `TestData` | GitHub secrets | A single-line JSON object with `secrets` and `variables` maps, exposed as environment variables to the module test jobs. Values under `secrets` are masked; values under `variables` are not. | No |

See [passing test data](../guides/calling-the-workflow.md#passing-test-data) for how to build the `TestData` value.

## Workflow `github.token` permissions

The following permissions are needed by the caller workflow's default `github.token` for operations that do not use
Shelly, such as linting and GitHub Pages deployment:

```yaml
permissions:
  contents: write      # to checkout the repo and create releases on the repo
  pull-requests: write # to write comments to PRs
  statuses: write      # to update the status of the workflow from linter
  pages: write         # to deploy to Pages
  id-token: write      # to verify the Pages deployment originates from an appropriate source
```

For more info, see [Deploy GitHub Pages site](https://github.com/marketplace/actions/deploy-github-pages-site).

## GitHub App permissions

The `permissions:` block above does not apply to Shelly's installation tokens. Shelly needs only the repository
permissions documented in [GitHub App authentication](../guides/github-app-authentication.md#github-app-installation-permissions):
Contents: write, Pull requests: write, and automatically granted Metadata: read. Each job requests a smaller,
repository-scoped subset when it mints its token.
