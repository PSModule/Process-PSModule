# Process-PSModule

Process-PSModule is the corner-stone of the PSModule framework — an end-to-end GitHub Actions workflow that builds, tests, versions, documents, and publishes PowerShell modules to the PowerShell Gallery.

Documentation site generation is powered by Zensical. Repositories define site configuration in `zensical.toml`.

## Documentation

The full documentation is published at:

📖 **[Process-PSModule documentation](https://psmodule.io/docs/)**

It covers getting started, the pipeline stages, usage, configuration, repository structure, and the principles behind the framework.

## Reusable workflow secrets (GitHub App auth)

When calling `./.github/workflows/workflow.yml`, pass the PowerShell Gallery API key and GitHub App credentials using these reusable-workflow secret names:

- `PSGALLERY_API_KEY`
- `GitHubAppClientId`
- `GitHubAppPrivateKey`

Consumer repositories can keep their own secret names and map them in the caller workflow, for example:

```yaml
jobs:
  ProcessPSModule:
    uses: ./.github/workflows/workflow.yml
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
```

This is a required contract. `PSGALLERY_API_KEY` publishes the module to the PowerShell Gallery; the GitHub App credentials mint an installation token for GitHub operations via `GH_TOKEN`, with no `github.token` fallback in that path. This is a breaking rename from the previous `APIKey`/`APIKEY` workflow secret.

See the [GitHub App authentication guide](https://psmodule.io/docs/guides/github-app-authentication/) for the caller mapping, per-workflow permissions and repository scoping, and token injection details.
