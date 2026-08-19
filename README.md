# Quote of the Day for Omarchy Quattro

A third-party Omarchy `bar-widget` that follows the same bar-panel integration contract as first-party panel widgets. It fetches the daily quote from ZenQuotes, caches it once per UTC day, resolves the author through English Wikipedia, adds Wikipedia's one-line description when available, and can send the displayed quote to Omarchy's configured default agent.

## Repository layout

The repository root is the plugin root. `manifest.json` must remain at the root.

```text
.
├── manifest.json
├── BarWidget.qml
├── Panel.qml
├── fetch-quote
├── README.md
└── .gitignore
```

## Dependencies

The helper uses `bash`, `curl`, and `jq`. Copying uses `wl-copy`. The plugin never installs dependencies itself; Omarchy plugin installation only clones, validates, and enables plugin files.

## Install

Use the native Omarchy menu to install the plugin from this repository or run:

```bash
omarchy plugin add https://github.com/camartinezbu/omaquote.git --enable
```

## Manual development install

From the repository root:

```bash
mkdir -p ~/.config/omarchy/plugins/qotd.zenquotes
cp -a manifest.json BarWidget.qml Panel.qml fetch-quote README.md .gitignore \
  ~/.config/omarchy/plugins/qotd.zenquotes/
chmod +x ~/.config/omarchy/plugins/qotd.zenquotes/fetch-quote

omarchy plugin validate ~/.config/omarchy/plugins/qotd.zenquotes
omarchy-shell shell rescanPlugins
omarchy plugin enable qotd.zenquotes
```

## Hotkwys

```text
Left/Right or h/l     select an action
Up/Down or j/k        scroll long content
Return/Space          activate selected action
Tab / Shift+Tab       switch neighboring panels
Escape                close
c                     copy quote
w                     Wikipedia biography
e                     explain with default agent
r                     refresh
z                     ZenQuotes source
```

Mouse behavior:

```text
Left click             toggle panel
Right click            open biography
Middle click           force refresh and open panel
```

The plugin also registers its own target for quote-specific actions:

```bash
omarchy-shell qotd.zenquotes open
omarchy-shell qotd.zenquotes close
omarchy-shell qotd.zenquotes refresh
omarchy-shell qotd.zenquotes biography
omarchy-shell qotd.zenquotes copy
omarchy-shell qotd.zenquotes explain
omarchy-shell qotd.zenquotes ask   # backward-compatible alias
```
## Data and privacy

The helper calls ZenQuotes for the daily quote and English Wikipedia for author resolution and description. It stores one local JSON cache file. The Explain action checks `omarchy-default-agent` on every panel open. If no default agent is selected, Explain is visibly unavailable and keyboard navigation skips it. When available, it runs only after explicit user input and invokes `omarchy agent prompt` with the displayed quote and author.

## License

This project is licensed under the MIT License.
