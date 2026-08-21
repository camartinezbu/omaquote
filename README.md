# Quote of the Day for Omarchy Quattro

A native-style Omarchy Quattro bar plugin that displays a daily quote from ZenQuotes.

The panel includes the quote, author information from Wikipedia, quick copy and refresh actions, and optional explanation through Omarchy's configured default agent.

## Install

Review this repository before installation, then run:

```sh
omarchy plugin add https://github.com/camartinezbu/omaquote.git --enable
```

You can also install it through Omarchy's plugin interface using this repository:

```text
https://github.com/camartinezbu/omaquote.git
```

## Remove

Remove the plugin with:

```sh
omarchy plugin remove omaquote
```

This disables the plugin and removes its installed plugin files.

## Dependencies

The plugin uses:

- `bash`
- `curl`
- `jq`
- `wl-copy`

These are used for fetching and processing quotes, retrieving author information, and copying quotes to the clipboard.

The plugin does not install dependencies itself.

## Usage

Click the bar icon to open or close the Quote of the Day panel.

Right-click the icon to open the current author's Wikipedia page.

Middle-click the icon to refresh the quote and open the panel.

### Keyboard controls

```text
Left / Right or h / l   Select an action
Up / Down or j / k      Scroll
Return / Space          Activate selected action
Tab / Shift+Tab         Switch neighboring panels
Escape                  Close the panel

c                       Copy quote
w                       Open Wikipedia biography
e                       Explain with default agent
r                       Refresh quote
z                       Open ZenQuotes source
```

## IPC

The plugin exposes the `omaquote` IPC target.

```sh
omarchy-shell omaquote open
omarchy-shell omaquote close
omarchy-shell omaquote refresh
omarchy-shell omaquote biography
omarchy-shell omaquote copy
omarchy-shell omaquote explain
```

## Data and privacy

The plugin contacts ZenQuotes to retrieve the daily quote and English Wikipedia to resolve author information.

A local JSON cache is used so the quote does not need to be fetched repeatedly during the same day.

The **Explain** action checks Omarchy's configured default agent. It is only invoked after explicit user input and sends the displayed quote and author to:

```sh
omarchy agent prompt
```

If no default agent is configured, the Explain action is unavailable.

## Development

The repository root is the plugin root. `manifest.json` must remain at the root.

```text
.
├── manifest.json
├── BarWidget.qml
├── Panel.qml
├── fetch-quote
├── README.md
└── LICENSE
```

To validate a local checkout:

```sh
omarchy plugin validate .
```

## License

MIT
