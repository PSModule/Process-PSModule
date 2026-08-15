# PSModule process plugin

This repository hosts the `psmodule` GitHub Copilot CLI marketplace and its
`psmodule-process` plugin. The marketplace and plugin are owned and released
with the PSModule process.

## Install through the marketplace

Register this repository's marketplace and install the plugin:

```console
copilot plugin marketplace add https://github.com/PSModule/Process-PSModule.git
copilot plugin install psmodule-process
```

## Install directly

Install the plugin directly from this repository:

```console
copilot plugin install PSModule/Process-PSModule:.github/plugin/plugins/psmodule-process
```

The plugin provides the
[`pester-migration`](./plugins/psmodule-process/skills/pester-migration/SKILL.md)
skill for migrating every Pester test set in a PSModule repository to Pester
6.1.0. Verify the installation with:

```console
copilot plugin list
/skills list
```

The marketplace catalog is in [`marketplace.json`](./marketplace.json), and
plugin metadata is in
[`plugin.json`](./plugins/psmodule-process/plugin.json).
