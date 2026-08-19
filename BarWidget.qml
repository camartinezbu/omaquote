import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "qotd.zenquotes"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle)
      panelLoader.item.toggle()
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.openWithRefresh)
      panelLoader.item.openWithRefresh()
  }

  function biography() {
    if (panelLoader.item && panelLoader.item.biographyWhenReady)
      panelLoader.item.biographyWhenReady()
  }

  // Native bar-panel shape contract. Bar.qml uses these members for
  // Super+Ctrl+1-9, shell summon/hide/toggle, panel indicators and routing
  // the panel instance on the focused monitor.
  readonly property bool opened: panelLoader.item
                                 ? panelLoader.item.opened === true
                                 : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey)
      panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close)
      panelLoader.item.close()
  }

  // Forward the popout handoff state to the bar-widget identity. This is the
  // same contract first-party panel widgets use when Tab switches panels.
  readonly property bool popoutSwitchClosing: panelLoader.item
                                                ? panelLoader.item.popoutSwitchClosing === true
                                                : false

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch)
      panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false

    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Nerd Fonts Material Design `format_quote_open` has substantially more
    // optical mass than a typographic curly quote, so it reads at the same
    // scale as the first-party status icons.
    text: "󰝗"
    slotSize: Style.bar.statusSlot
    fontSize: Style.bar.iconFont * 1.12
    tooltipText: "Quote of the Day"

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.biography()
      else if (mouseButton === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
