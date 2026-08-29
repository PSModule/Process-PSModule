# PSModule process plugin

This repository hosts the `psmodule` GitHub Copilot CLI marketplace and its
`psmodule` plugin. The marketplace and plugin are owned and released
with the PSModule process.

## Install through the marketplace

Register this repository's marketplace and install the plugin:

```console
copilot plugin marketplace add https://github.com/PSModule/Process-PSModule.git
copilot plugin install psmodule
```

## Install directly

Install the plugin directly from this repository:

```console
copilot plugin install PSModule/Process-PSModule:.github/plugin/psmodule
```

The plugin provides the
[`psmodule-pester-migration`](./psmodule/skills/psmodule-pester-migration/SKILL.md)
skill for migrating every Pester test set in a PSModule repository to Pester
6.1.0, and the
[`psmodule-v8-upgrade`](./psmodule/skills/psmodule-v8-upgrade/SKILL.md)
skill for upgrading Process-PSModule consumer repositories to framework v8.
It also provides
[`psmodule-zensical-migration`](./psmodule/skills/psmodule-zensical-migration/SKILL.md)
for migrating legacy MkDocs sites to the standard Zensical design, and
[`psmodule-template-reconciliation`](./psmodule/skills/psmodule-template-reconciliation/SKILL.md)
for comparing or reconciling module repositories with the current
Template-PSModule baseline.
Verify the installation with:

```console
copilot plugin list
/skills list
```

The marketplace catalog is in [`marketplace.json`](./marketplace.json), and
plugin metadata is in
[`plugin.json`](./psmodule/plugin.json).
