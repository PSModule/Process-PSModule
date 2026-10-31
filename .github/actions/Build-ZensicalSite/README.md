# Build-ZensicalSite

Builds Zensical documentation site output at `<working-directory>/.PSModule/site/_site`.

## Inputs

- `WorkingDirectory` (required): Build working directory.

## Usage

```yaml
- name: Build documentation site with Zensical
  uses: ./_wf/.github/actions/Build-ZensicalSite
  with:
    WorkingDirectory: .
```
