# Build, Test, Pack, Publish

Process-PSModule orchestrates the module lifecycle through GitHub Actions.

## Flow

1. resolve settings and release intent
2. build module artifact from `src/`
3. run tests and quality checks
4. package docs/site artifacts when enabled
5. publish module and release metadata when release conditions are met

## Release behavior

Version progression is label-driven in pull requests and resolved in the plan stage.

## Validation behavior

Test and lint stages run before publish gates, and publish is blocked when required checks fail.

For complete cross-org release capability docs, use [MSX Capabilities](https://msxorg.github.io/docs/Capabilities/).
