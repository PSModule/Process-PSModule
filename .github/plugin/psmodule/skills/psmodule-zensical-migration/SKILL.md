---
name: psmodule-zensical-migration
description: Migrate a PSModule repository from MkDocs to Zensical using the Process-PSModule documentation design as the default while preserving content, navigation, assets, and repository-specific behavior.
---

# Migrate PSModule documentation from MkDocs to Zensical

Use this skill when a PSModule repository has a legacy MkDocs configuration,
usually `.github/mkdocs.yml`, or needs its documentation site aligned with the
Process-PSModule Zensical design. Keep the migration limited to documentation
integration. Do not rewrite module code or tests unless a documentation build
requires a directly related fix.

## Source-of-truth design

Use the current
[`Process-PSModule` `docs/zensical.toml`](https://github.com/PSModule/Process-PSModule/blob/main/docs/zensical.toml)
as the default style and configuration baseline. Reuse its behavior rather than
inventing a second theme:

- `docs_dir = "content"` with content under `docs/content/`.
- `docs/overrides/` as the custom theme directory.
- `docs/overrides/assets/stylesheets/navigation.css` for navigation styling.
- `docs/overrides/assets/` and any repository-owned `docs/assets/` directory
  when present as the asset source of truth.
- Mona Sans text and Source Code Pro code fonts.
- Material-style GitHub/link icons, light/dark/system palette toggles,
  black/slate/light-blue colors, and the established navigation features.
- Instant navigation, prefetch/preview/progress, tabs, tracking, top navigation,
  search, code copy, tooltips, table of contents, and footer behavior.
- TOC, attribute lists, abbreviations, admonitions, definition lists,
  footnotes, tables, HTML-in-Markdown, details, superfences, task lists, and
  snippets extensions.
- Mermaid fenced blocks and the shared abbreviations snippet.
- Existing social links, consent configuration, site metadata, edit URI, and
  custom tablesort JavaScript where those features apply.

Customize only repository identity and content-specific values such as
`site_name`, `site_url`, `repo_name`, `repo_url`, `edit_uri`, copyright, social
links, and `nav`. Do not remove a default feature merely because the old
MkDocs site did not use it.

## Inspect before changing

Inventory the existing repository and record:

1. Local guidance, branch state, and documentation build commands.
2. `.github/mkdocs.yml`, any `mkdocs.yml`, and any existing Zensical config.
3. The Markdown content root, includes/snippets, templates, media, and assets.
4. `theme`, `theme.custom_dir`, `extra_css`, `extra_javascript`, `plugins`,
   `markdown_extensions`, `nav`, `extra`, and `watch` settings.
5. Links, anchors, generated API/help pages, redirects, and CI publishing steps.
6. Existing custom CSS, JavaScript, templates, logos, favicons, and fonts.

Do not assume every consumer has a `docs/` tree. If documentation is absent,
create it only when the requested scope includes documentation migration. If
the repository already uses Zensical, compare it with the Process-PSModule
baseline and make only the required alignment changes.

## Target layout

For the Process-PSModule documentation contract, use:

```text
docs/
├── content/
├── overrides/
│   └── assets/
│       ├── javascripts/
│       └── stylesheets/
└── zensical.toml
```

Keep existing content under `docs/content/`, custom templates under
`docs/overrides/`, and theme assets under `docs/overrides/assets/`. A separate
`docs/assets/` directory is optional for static content assets. Do not create a
parallel MkDocs theme or leave two active site configurations.

The current `PSModule/Template-PSModule` repository historically stores a
starter `.github/zensical.toml` and may not contain a `docs/` tree. When the
consumer upgrade explicitly requires the Process-PSModule `docs/` contract,
move the template settings and custom assets into `docs/` and remove the
obsolete active configuration only after the site builds. When that contract
is not in scope, preserve a working template layout and report the difference
instead of moving files speculatively.

## MkDocs-to-Zensical mapping

Translate behavior, not just filenames:

| MkDocs | Zensical |
| --- | --- |
| `site_name`, `site_url` | `[project]` metadata |
| `docs_dir` | `[project].docs_dir` |
| `repo_name`, `repo_url`, `edit_uri` | `[project]` metadata |
| `nav` | `nav = [...]` TOML entries |
| `theme.name` | `[project.theme]` settings |
| `theme.custom_dir` | `[project.theme].custom_dir` |
| `theme.logo`, `theme.favicon` | `[project.theme]` paths |
| `theme.features` | `[project.theme].features` |
| `theme.palette` | `[[project.theme.palette]]` tables |
| `extra_css`, `extra_javascript` | `[project]` arrays |
| `markdown_extensions` | `[project.markdown_extensions.*]` tables |
| `plugins: search` | `[project.plugins.search]` |
| `extra.social` | `[[project.extra.social]]` |
| `watch` | `[project].watch` |

Preserve Markdown semantics while checking extensions that affect formatting:
admonitions, fenced code, tables, task lists, definition lists, attributes,
snippets, Mermaid, and anchor/permalink behavior. Fix only documented
Zensical incompatibilities; do not silently change headings or links to hide
build failures.

## Content and link migration

- Preserve page paths and navigation labels where possible.
- Keep explicit `nav` entries for important landing pages and references.
- Resolve relative links from the new `docs/content/` root.
- Recheck fragment anchors because heading and permalink behavior can differ.
- Move includes/snippets to the configured Zensical location and update every
  reference.
- Keep generated API/help inputs in their framework-owned locations.
- Preserve images and downloads; update paths rather than deleting assets.
- Keep custom templates only when they are still required by the migrated site.

## Validation

Run repository-native checks and the smallest targeted site checks first:

1. Parse the new `docs/zensical.toml` and verify all configured paths exist.
2. Confirm no active `mkdocs.yml` or MkDocs workflow remains.
3. Check every navigation target, image, download, include, and fragment link.
4. Run the existing documentation lint and link checks.
5. Build the site:

   ```powershell
   Push-Location docs
   zensical build --clean
   Pop-Location
   ```

6. Review the generated site for navigation, search, palette toggles, fonts,
   logo/favicon, custom navigation behavior, code blocks, Mermaid, and social
   links.
7. Run the repository's existing Process-PSModule workflow validation when the
   documentation is part of that pipeline.

Do not claim success if the site builds while links, assets, navigation, or
publishing behavior are broken. Report intentionally deferred pages,
unsupported extensions, and unrelated pre-existing failures.

## References

- [Process-PSModule Zensical configuration](https://github.com/PSModule/Process-PSModule/blob/main/docs/zensical.toml)
- [Process-PSModule documentation overrides](https://github.com/PSModule/Process-PSModule/tree/main/docs/overrides)
- [Process-PSModule override assets](https://github.com/PSModule/Process-PSModule/tree/main/docs/overrides/assets)
- [PSModule repository standard](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/reference/repository-standard.md)
- [PSModule documentation model](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/guides/structuring-your-module.md)
- [Zensical setup basics](https://zensical.org/docs/setup/basics/)
