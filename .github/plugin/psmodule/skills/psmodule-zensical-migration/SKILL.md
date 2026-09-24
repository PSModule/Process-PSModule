---
name: psmodule-zensical-migration
description: Assess a PSModule repository's documentation migration to Zensical without introducing a site layout the Process-PSModule pipeline cannot publish.
---

# Assess a PSModule Zensical migration

Use this skill when a PSModule repository has a legacy MkDocs configuration or
needs its documentation site aligned with Zensical. Keep the assessment limited
to documentation integration. Do not rewrite module code or tests unless a
documentation build requires a directly related fix.

## Current Process-PSModule boundary

The module site pipeline stages generated function documentation, `README.md`,
the module icon, and `.github/zensical.toml` into `outputs/site`. It does not
stage consumer-authored `docs/content/`, `docs/overrides/`, or their assets.
Consequently, a consumer configuration that sets `docs_dir = "content"` or
`custom_dir = "overrides"` cannot be published through the current framework.

Do not move a module consumer from `.github/zensical.toml` to
`docs/zensical.toml`, or prescribe the Process-PSModule repository's
`docs/content/` design, until the framework stages those paths.

## Assess before changing

1. Read local guidance, the current documentation build command, and the
   Process-PSModule caller workflow.
2. Inventory `.github/mkdocs.yml`, `mkdocs.yml`, `.github/zensical.toml`, and
   any existing documentation sources, templates, media, and assets.
3. Identify whether documentation is published by Process-PSModule or by a
   separate repository-owned workflow.
4. Preserve module source, generated help, custom assets, navigation, and
   repository-owned workflows unless the requested migration requires them.

## Supported consumer configuration

For a Process-PSModule consumer, retain the template's
`.github/zensical.toml` configuration and the generated site layout. Do not
add a second active site configuration.

When a requested migration needs authored Markdown content or a custom theme,
record that the framework must first stage those assets into `outputs/site`.
Do not claim the migration is complete until the producer supports the target
layout and a consumer build publishes it successfully.

## Validation

1. Confirm the caller references the intended Process-PSModule version and
   retains `.github/zensical.toml`.
2. Run the consumer's existing documentation and Process-PSModule validation
   commands when available.
3. Review the generated site to confirm generated function documentation,
   `README.md`, and module assets remain present.

Report any unsupported authored-content or custom-theme requirement as a
framework gap rather than working around it with a second active
configuration.

## References

- [PSModule repository standard](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/reference/repository-standard.md)
- [PSModule workflow inputs](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/reference/workflow-inputs.md)
- [Zensical setup basics](https://zensical.org/docs/setup/basics/)
