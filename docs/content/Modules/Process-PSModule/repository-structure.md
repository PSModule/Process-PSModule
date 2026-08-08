# Process-PSModule Repository Structure

A module repository in PSModule follows a predictable structure so the framework can build and validate it consistently.

## Top-level contract

- `src/`: module source input for build
- `tests/`: Pester tests and test helpers
- `examples/`: usage examples for consumers
- `icon/`: module icon assets
- `.github/workflows/Process-PSModule.yml`: caller workflow that invokes the reusable `PSModule/Process-PSModule/.github/workflows/workflow.yml`
- `.github/PSModule.yml`: repository-level framework settings

## Source layout overview

- `src/functions/public/`: exported commands
- `src/functions/private/`: internal helpers
- `src/classes/public/`: user-facing classes
- `src/classes/private/`: internal classes
- `src/data/`: static data files
- `src/init/`: import-time initialization code
- `src/formats/`: formatting views
- `src/types/`: type metadata
- `src/variables/`: variables split by visibility

Detailed coding standards are canonical in [MSX Coding Standards](https://msxorg.github.io/docs/Coding-Standards/).
