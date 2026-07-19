# Structure-Site

Prepares site content and writes a resolved Zensical config file under `outputs/site`.

## Inputs

- `WorkingDirectory` (required): Build working directory.
- `Name` (optional): Module name override.

## Usage

```yaml
- name: Structure site
  uses: ./_wf/.github/actions/Structure-Site
  with:
    WorkingDirectory: .
    Name: MyModule
```
