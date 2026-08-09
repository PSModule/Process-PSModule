---
title: GitHub App authentication
description: Configure the GitHub App secrets and understand token scope and injection in Process-PSModule workflows.
---

# GitHub App authentication

The repository API operations in the Plan, Build-Module, and Publish-Module workflows use short-lived GitHub App
installation tokens. These workflows do not use `github.token` as a fallback for those operations.

## Caller secret contract

The reusable workflow declares two required secrets at its `workflow_call` boundary:

| Name | Purpose |
| --- | --- |
| `GitHubAppClientId` | The GitHub App client ID passed to the token action. |
| `GitHubAppPrivateKey` | The GitHub App private key passed to the token action. |

The names are the reusable workflow contract, not a requirement for the caller's repository or organization secret
names. Map the caller's secrets explicitly:

```yaml
jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v5
    secrets:
      APIKey: ${{ secrets.APIKey }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
```

The root reusable workflow forwards these two values to the Plan, Build-Module, and Publish-Module reusable jobs.
Do not use `secrets: inherit` as a substitute for this mapping.

For Dependabot pull requests, create `SHELLY_CLIENT_ID` and `SHELLY_PRIVATE_KEY` as Dependabot secrets as well as
Actions secrets. Dependabot-triggered workflows cannot read regular Actions secrets, so the GitHub App token cannot
be minted without separate Dependabot secret values.

## Token scope

Each job mints its own token with the repository that triggered the workflow:
`${{ github.event.repository.name }}`.

| Workflow | Requested repository permissions | GitHub operations |
| --- | --- | --- |
| Plan | `contents: read`, `pull-requests: write` | Read repository settings and version data, inspect pull-request files and labels, and write planning comments or labels. |
| Build-Module | `metadata: read` | Read repository metadata while building the module manifest. |
| Publish-Module | `contents: write`, `pull-requests: write` | Create and upload releases, write pull-request comments, and clean up prereleases. |

The GitHub App installation must grant the permissions requested by each job. Keep the installation and token scope
limited to the repository set required by the workflow; add broader repository access only when a workflow explicitly
needs cross-repository operations.

The scopes have separate ceilings:

- `permissions:` on the caller workflow controls the default `github.token`; it does not expand an App installation
  token.
- The App installation permissions are the maximum permissions any token from that installation can receive.
- The `repositories` input limits the repositories available to the minted token.
- Each `permission-<scope>` input requests only the subset needed by that job.

## Token injection

The token action is pinned and exposes its output only to the steps that need GitHub API access:

```yaml
- name: Create GitHub App token
  id: App-Token
  uses: actions/create-github-app-token@fee1f7d63c2ff003460e3d139729b119787bc349 # v2
  with:
    app-id: ${{ secrets.GitHubAppClientId }}
    private-key: ${{ secrets.GitHubAppPrivateKey }}
    repositories: ${{ github.event.repository.name }}
    permission-metadata: read

- name: Use the token
  env:
    GH_TOKEN: ${{ steps.App-Token.outputs.token }}
  run: gh repo view
```

Process-PSModule does not set this token as a job-wide environment variable. It injects `GH_TOKEN` on the Get-Settings
and Resolve-Version steps in Plan, the Build-PSModule step in Build-Module, and the Publish-PSModule and cleanup steps
in Publish-Module. Keep GitHub App tokens step-scoped when adding new API calls.
