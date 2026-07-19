# Inject-SiteScripts

Injects JavaScript snippets from `.github/scripts/site-injectors/*.js` into generated HTML files.

## Inputs

- `SitePath` (required): Path to generated site output.
- `WorkflowPath` (optional, default `_wf`): Path where workflow repository is checked out.

## Usage

```yaml
- name: Inject shared site scripts
  uses: ./_wf/.github/actions/Inject-SiteScripts
  with:
    SitePath: ./_site
    WorkflowPath: _wf
```
