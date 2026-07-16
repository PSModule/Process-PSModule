# Process-PSModule

Process-PSModule is the corner-stone of the PSModule framework — an end-to-end GitHub Actions workflow that builds, tests, versions, documents, and publishes PowerShell modules to the PowerShell Gallery.

## Documentation

The full documentation lives on the MSX / Docs site:

📖 **[Process-PSModule documentation](https://msxorg.github.io/docs/Frameworks/Process-PSModule/)**

It covers getting started, the pipeline stages, usage, configuration, repository structure, and the principles behind the framework.

## TestData phase parity

Module-local setup, test, and teardown phases use the same `TestData` contract. Values under
`secrets` are masked and values under `variables` are exported unmasked, and every key is available
as `$env:<name>` in all three phases:

- `BeforeAll-ModuleLocal` (`tests/BeforeAll.ps1`)
- `Test-ModuleLocal` (Pester module tests)
- `AfterAll-ModuleLocal` (`tests/AfterAll.ps1`)

Pass `TestData` as a single-line JSON object from the calling workflow:

```yaml
jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v6
    secrets:
      APIKey: ${{ secrets.APIKey }}
      TestData: >-
        { "secrets": { "TEST_TOKEN": "${{ secrets.TEST_TOKEN }}" },
          "variables": { "TEST_OWNER": ${{ toJSON(vars.TEST_OWNER) }} } }
```

If a key is missing in setup or teardown, verify that the caller explicitly maps `TestData` as JSON.
`secrets: inherit` only passes a repository or environment secret already named `TestData`; it does not
automatically build the JSON object from individual secrets.
