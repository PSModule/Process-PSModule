# Process-PSModule

Process-PSModule is the corner-stone of the PSModule framework — an end-to-end GitHub Actions workflow that builds, tests, versions, documents, and publishes PowerShell modules to the PowerShell Gallery.

Documentation site generation is powered by Zensical. Repositories define site configuration in `zensical.toml`.

## Documentation

The full documentation lives on the MSX / Docs site:

📖 **[Process-PSModule documentation](https://msxorg.github.io/docs/Frameworks/Process-PSModule/)**

It covers getting started, the pipeline stages, usage, configuration, repository structure, and the principles behind the framework.

## Reusable workflow secrets (GitHub App auth)

When calling `./.github/workflows/workflow.yml`, pass GitHub App credentials using these generic reusable-workflow secret names:

- `GitHubAppClientId`
- `GitHubAppPrivateKey`

Consumer repositories can keep their own secret names and map them in the caller workflow, for example:

```yaml
jobs:
  ProcessPSModule:
    uses: ./.github/workflows/workflow.yml
    secrets:
      GitHubAppClientId: ${{ secrets.PSMODULE_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.PSMODULE_PRIVATE_KEY }}
```

This is a required contract for GitHub operations in the reusable workflow path; a GitHub App installation token is minted and used for those steps via `GH_TOKEN`, and `github.token` fallback is intentionally not used.

See the [GitHub App authentication guide](https://psmodule.io/docs/guides/github-app-authentication/) for the caller mapping, per-workflow permissions and repository scoping, and token injection details.
