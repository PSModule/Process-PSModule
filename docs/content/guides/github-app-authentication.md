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

Dependabot-triggered workflows cannot read regular Actions secrets. Do not duplicate Shelly's private key into
Dependabot secrets by default: a compromised dependency update could alter workflow code that receives the key before
human review. If an organization requires the Process-PSModule workflow to run on Dependabot pull requests, its
security owners must explicitly accept that trust boundary and provision separate Dependabot secrets. Otherwise,
skip token-consuming jobs for Dependabot pull requests and run the full workflow after review or merge.

## GitHub App installation permissions

Install Shelly only on repositories that the process must manage. The complete permission baseline for the current
Process-PSModule GitHub App path is:

| Repository permission | Access | Why it is needed |
| --- | --- | --- |
| Contents | Write | Read releases during version resolution; create, upload to, and delete releases during publish and cleanup. |
| Pull requests | Write | Read pull-request files and labels; add process and release comments to pull requests. |
| Metadata | Read | Read repository description, topics, and URL while building the module manifest. This permission is granted automatically to GitHub Apps. |

Do not grant Shelly Actions, Issues, Statuses, Pages, Workflows, or administration permissions for the current
Process-PSModule GitHub App path. Those permissions are not used by installation tokens minted here.

The caller workflow's `permissions:` block is separate: it scopes only `github.token` for non-App operations such as
artifact handling, linting, and Pages deployment. It cannot expand or restrict Shelly's installation token.

## Per-workflow token scope

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
