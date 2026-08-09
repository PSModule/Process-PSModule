# Template Quickstart

Start new modules from the PSModule template repository:

- [Template-PSModule](https://github.com/PSModule/Template-PSModule)

## Quickstart

1. Create a new repository from the template.
2. Replace placeholder metadata and remove scaffold sample files.
3. Add your first public command and tests.
4. Validate `.github/PSModule.yml` defaults for your module.
5. Open a draft pull request and run the full pipeline.

If the module needs several interdependent commands before it is usable at all, see [Module Bootstrap](module-bootstrap.md) instead of shipping them as one command per step.

## Expected outcomes

- repository follows Process-PSModule structure
- module can be built and tested in CI
- release strategy is ready when functionality is implemented

For framework-level practices, refer to [MSX Ways of Working](https://msxorg.github.io/docs/Ways-of-Working/).
