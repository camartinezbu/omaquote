import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "omaquote"
  ipcTarget: "omaquote"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false

  // The bar tracks BarWidget.qml, not this nested panel. Using the host widget
  // as the identity gives Quattro the same popout ownership, open indicator,
  // numbered-hotkey routing and Tab handoff model as first-party panels.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string helperPath: Qt.resolvedUrl("fetch-quote").toString().replace(/^file:\/\//, "")
  readonly property int desiredWidth: Style.space(380)
  readonly property int maximumHeight: Style.space(350)

  property bool loading: false
  property bool hasQuote: false
  property string errorMessage: ""
  property string statusText: ""
  property string pendingAction: ""
  property var quoteData: ({})

  // Ask Omarchy itself which default agent is configured. The canonical
  // getter prints nothing when the user has not picked one yet.
  property string defaultAgent: ""
  property bool agentChecked: false
  readonly property bool hasDefaultAgent: root.agentChecked && root.defaultAgent !== ""

  property bool cursorActive: false
  property int selectedAction: 0
  readonly property int actionCount: 4

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // Mouse/open API retained for compatibility with the panel base shape.
  function open() {
    root.openedFromHotkey = false
    root.cursorActive = false
    root.setCenterHoverRevealSuppressed(false)
    root.checkDefaultAgent()
    root.controller.show()
    root.loadQuote(false)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // Native shell/hotkey path, mirroring first-party panel behavior.
  function openFromHotkey() {
    root.openedFromHotkey = true
    root.cursorActive = true
    root.selectedAction = 0
    root.checkDefaultAgent()
    root.controller.show()
    root.loadQuote(false)

    Qt.callLater(function() {
      if (root.opened) root.setCenterHoverRevealSuppressed(true)
      keyCatcher.forceActiveFocus()
    })
  }

  function openWithRefresh() {
    root.openedFromHotkey = false
    root.cursorActive = false
    root.setCenterHoverRevealSuppressed(false)
    root.checkDefaultAgent()
    root.controller.show()
    root.loadQuote(true)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function checkDefaultAgent() {
    if (agentProc.running) return
    root.agentChecked = false
    agentProc.running = true
  }

  function hasWikipedia() {
    return root.hasQuote && String(root.quoteData.wiki_url || "") !== ""
  }

  function actionAvailable(index) {
    if (index === 0) return root.hasQuote
    if (index === 1) return root.hasWikipedia()
    if (index === 2) return root.hasQuote && root.hasDefaultAgent
    if (index === 3) return !root.loading
    return false
  }

  function ensureSelectedActionAvailable() {
    if (root.actionAvailable(root.selectedAction)) return
    for (var i = 0; i < root.actionCount; i++) {
      if (root.actionAvailable(i)) {
        root.selectedAction = i
        return
      }
    }
  }

  function loadQuote(forceRefresh) {
    if (quoteProc.running) return
    root.loading = true
    root.errorMessage = ""
    quoteProc.command = forceRefresh
      ? ["bash", root.helperPath, "--refresh"]
      : ["bash", root.helperPath]
    quoteProc.running = true
  }

  function quoteText() {
    return root.hasQuote ? String(root.quoteData.quote || "") : ""
  }

  function authorText() {
    return root.hasQuote ? String(root.quoteData.author || "") : ""
  }

  function biographyDescription() {
    return root.hasQuote ? String(root.quoteData.wiki_description || "") : ""
  }

  function setStatus(text) {
    root.statusText = text
    statusTimer.restart()
  }

  function copyQuote() {
    var q = root.quoteText()
    var a = root.authorText()
    if (!q) return
    Quickshell.execDetached(["wl-copy", q + "\n\n— " + a])
    root.setStatus("Copied")
  }

  function openBiography() {
    if (!root.hasQuote) return
    var url = String(root.quoteData.wiki_url || "")
    if (url) Qt.openUrlExternally(url)
    else root.setStatus("No Wikipedia page found")
  }

  function openSource() {
    Qt.openUrlExternally(String(root.quoteData.source_url || "https://zenquotes.io/"))
  }

  function explainQuote() {
    if (!root.hasQuote) return

    if (!root.agentChecked) {
      root.pendingAction = "explain"
      root.checkDefaultAgent()
      root.setStatus("Checking default agent…")
      return
    }

    if (!root.hasDefaultAgent) {
      root.setStatus("Choose a default agent in Setup > Defaults > Agent")
      return
    }

    var prompt = "Explain this quote attributed to " + root.authorText()
      + ":\n\n\"" + root.quoteText() + "\"\n\n"
      + "Give concise historical context, interpret the idea, and say whether "
      + "the attribution or original source is well established. Answer only; "
      + "do not modify files or system settings."
    Quickshell.execDetached(["omarchy", "agent", "prompt", prompt])
    root.setStatus("Opened default agent")
  }

  function runOrDefer(action) {
    if ((action === "explain" || action === "ask") && !root.agentChecked)
      root.checkDefaultAgent()

    if (root.hasQuote) {
      if (action === "biography") root.openBiography()
      else if (action === "copy") root.copyQuote()
      else if (action === "explain" || action === "ask") root.explainQuote()
      return
    }

    root.pendingAction = action
    root.loadQuote(false)
  }

  function biographyWhenReady() { root.runOrDefer("biography") }
  function copyWhenReady() { root.runOrDefer("copy") }
  function explainWhenReady() { root.runOrDefer("explain") }
  function askWhenReady() { root.runOrDefer("explain") }

  function executePendingAction() {
    var action = root.pendingAction
    root.pendingAction = ""
    if (action === "biography") root.openBiography()
    else if (action === "copy") root.copyQuote()
    else if (action === "explain" || action === "ask") root.explainQuote()
  }

  function moveAction(delta) {
    root.cursorActive = true
    var candidate = root.selectedAction
    for (var i = 0; i < root.actionCount; i++) {
      candidate = (candidate + root.actionCount + delta) % root.actionCount
      if (root.actionAvailable(candidate)) {
        root.selectedAction = candidate
        return
      }
    }
  }

  function scrollContent(delta) {
    if (quoteScroll.contentHeight <= quoteScroll.height) return
    var step = Style.space(44)
    var target = quoteScroll.contentY + delta * step
    quoteScroll.contentY = Math.max(0, Math.min(target, quoteScroll.contentHeight - quoteScroll.height))
  }

  function runSelectedAction() {
    if (!root.cursorActive || !root.actionAvailable(root.selectedAction)) return
    if (root.selectedAction === 0) root.copyQuote()
    else if (root.selectedAction === 1) root.openBiography()
    else if (root.selectedAction === 2) root.explainQuote()
    else if (root.selectedAction === 3) root.loadQuote(true)
  }

  function handleTextKey(text) {
    var key = String(text || "").toLowerCase()
    if (key === "c") root.copyQuote()
    else if (key === "w") root.openBiography()
    else if (key === "e") root.explainQuote()
    else if (key === "r") root.loadQuote(true)
    else if (key === "z") root.openSource()
  }

  Process {
    id: agentProc
    command: ["omarchy-default-agent"]

    stdout: StdioCollector {
      id: agentOutput
      waitForEnd: true
    }

    onExited: function(exitCode) {
      root.defaultAgent = exitCode === 0 ? String(agentOutput.text || "").trim() : ""
      root.agentChecked = true
      if (root.pendingAction === "explain" && root.hasQuote)
        root.executePendingAction()
      Qt.callLater(root.ensureSelectedActionAvailable)
    }
  }

  Process {
    id: quoteProc

    stdout: StdioCollector {
      id: quoteOutput
      waitForEnd: true
    }

    stderr: StdioCollector {
      id: quoteError
      waitForEnd: true
    }

    onExited: function(exitCode) {
      root.loading = false

      if (exitCode !== 0) {
        root.errorMessage = String(quoteError.text || "Could not load today's quote.").trim()
        root.pendingAction = ""
        return
      }

      try {
        root.quoteData = JSON.parse(quoteOutput.text)
        root.hasQuote = Boolean(root.quoteData.quote && root.quoteData.author)
        if (!root.hasQuote)
          root.errorMessage = "The quote provider returned incomplete data."
        else {
          root.executePendingAction()
          Qt.callLater(root.ensureSelectedActionAvailable)
        }
      } catch (error) {
        root.hasQuote = false
        root.errorMessage = "The quote response could not be read."
        root.pendingAction = ""
      }

      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  Timer {
    id: statusTimer
    interval: 1600
    onTriggered: root.statusText = ""
  }

  // Keep the direct target used by the existing prototype, but route its
  // panel lifecycle through the same hotkey path as first-party plugins.
  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.openWithRefresh() }
    function biography(): void { root.biographyWhenReady() }
    function copy(): void { root.copyWhenReady() }
    function explain(): void { root.explainWhenReady() }
    // Backward-compatible alias for pre-0.2.5 scripts.
    function ask(): void { root.explainWhenReady() }
  }

  Component.onCompleted: root.checkDefaultAgent()

  onOpenedChanged: {
    if (opened) {
      quoteScroll.contentY = 0
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  KeyboardPanel {
    id: quotePanel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: quotePanel.fittedContentWidth(root.desiredWidth)
    contentHeight: quotePanel.fittedContentHeight(contentColumn.implicitHeight, root.maximumHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveAction(dx)
        if (dy !== 0) root.scrollContent(dy)
      }
      onActivateRequested: root.runSelectedAction()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { root.handleTextKey(text) }

      Flickable {
        id: quoteScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar {
          policy: quoteScroll.contentHeight > quoteScroll.height
                  ? ScrollBar.AsNeeded
                  : ScrollBar.AlwaysOff
        }

        Column {
          id: contentColumn
          width: quoteScroll.width
          spacing: Style.space(8)

          Row {
            width: parent.width
            spacing: Style.space(8)

            Item {
              // Same Nerd Font quote glyph as the bar icon, but with more
              // optical weight in the opened panel header.
              width: Style.space(32)
              height: Style.space(32)
              anchors.verticalCenter: parent.verticalCenter

              OpticalGlyph {
                anchors.fill: parent
                text: "󰝗"
                fontFamily: root.contentFontFamily
                fontSize: Style.bar.iconFont * 1.65
                color: Color.accent
              }
            }

            Column {
              width: parent.width - Style.space(40)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: "Quote of the Day"
                textFormat: Text.PlainText
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                width: parent.width
                text: root.loading
                      ? "FETCHING…"
                      : String(root.quoteData.provider_date
                               || root.quoteData.fetched_utc_day
                               || "TODAY").toUpperCase()
                textFormat: Text.PlainText
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.0
              }
            }
          }

          PanelSeparator { foreground: root.contentForeground }

          Text {
            visible: root.errorMessage === "" && root.hasQuote
            width: parent.width
            text: root.quoteText()
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            lineHeight: 1.12
          }

          Text {
            visible: root.errorMessage === "" && root.hasQuote
            width: parent.width
            text: "— " + root.authorText()
            textFormat: Text.PlainText
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            horizontalAlignment: Text.AlignRight
          }

          Text {
            visible: root.errorMessage === "" && root.biographyDescription() !== ""
            width: parent.width
            text: root.biographyDescription()
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            color: Qt.darker(root.contentForeground, 1.35)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
          }

          Text {
            visible: root.loading && !root.hasQuote
            width: parent.width
            text: "Loading today's quote…"
            textFormat: Text.PlainText
            color: Qt.darker(root.contentForeground, 1.35)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            visible: root.errorMessage !== ""
            width: parent.width
            text: root.errorMessage
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }

          PanelSeparator { foreground: root.contentForeground }

          Text {
            id: statusMessage
            visible: root.statusText !== "" || (root.hasQuote && root.quoteData.stale === true)
            width: parent.width
            text: root.statusText !== ""
                  ? root.statusText
                  : "Cached · offline"
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }

          Item {
            id: actionArea
            width: parent.width
            implicitHeight: actionRow.implicitHeight

            Row {
              id: actionRow
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.controlGap

              Button {
                id: copyButton
                text: ""
                foreground: root.contentForeground
                horizontalPadding: Style.space(9)
                verticalPadding: Style.space(4)
                implicitWidth: Math.max(Style.space(58), copyContent.implicitWidth + horizontalPadding * 2)
                implicitHeight: copyContent.implicitHeight + verticalPadding * 2
                hasCursor: root.cursorActive && root.selectedAction === 0 && root.actionAvailable(0)
                enabled: root.hasQuote
                opacity: root.actionAvailable(0) ? 1.0 : 0.45

                Column {
                  id: copyContent
                  anchors.centerIn: parent
                  spacing: Style.space(1)
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Copy"
                    color: copyButton.foreground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "c"
                    color: Qt.darker(root.contentForeground, 1.65)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                onHovered: function(value) {
                  if (value && root.actionAvailable(0)) {
                    root.cursorActive = true
                    root.selectedAction = 0
                  }
                }
                onClicked: root.copyQuote()
              }

              Button {
                id: wikipediaButton
                text: ""
                foreground: root.contentForeground
                horizontalPadding: Style.space(9)
                verticalPadding: Style.space(4)
                implicitWidth: Math.max(Style.space(82), wikipediaContent.implicitWidth + horizontalPadding * 2)
                implicitHeight: wikipediaContent.implicitHeight + verticalPadding * 2
                hasCursor: root.cursorActive && root.selectedAction === 1 && root.actionAvailable(1)
                enabled: root.hasQuote
                opacity: root.actionAvailable(1) ? 1.0 : 0.45
                tooltipText: root.actionAvailable(1)
                             ? "Open author biography"
                             : "No Wikipedia page found"

                Column {
                  id: wikipediaContent
                  anchors.centerIn: parent
                  spacing: Style.space(1)
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Wikipedia"
                    color: wikipediaButton.foreground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "w"
                    color: Qt.darker(root.contentForeground, 1.65)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                onHovered: function(value) {
                  if (value && root.actionAvailable(1)) {
                    root.cursorActive = true
                    root.selectedAction = 1
                  }
                }
                onClicked: root.openBiography()
              }

              Button {
                id: explainButton
                text: ""
                foreground: root.contentForeground
                horizontalPadding: Style.space(9)
                verticalPadding: Style.space(4)
                implicitWidth: Math.max(Style.space(52), explainContent.implicitWidth + horizontalPadding * 2)
                implicitHeight: explainContent.implicitHeight + verticalPadding * 2
                hasCursor: root.cursorActive && root.selectedAction === 2 && root.actionAvailable(2)
                enabled: root.hasQuote
                opacity: root.actionAvailable(2) ? 1.0 : 0.45
                tooltipText: !root.hasQuote
                             ? "Waiting for quote"
                             : !root.agentChecked
                               ? "Checking default agent…"
                               : root.hasDefaultAgent
                                 ? "Explain with " + root.defaultAgent
                                 : "Choose a default agent in Setup > Defaults > Agent"

                Column {
                  id: explainContent
                  anchors.centerIn: parent
                  spacing: Style.space(1)
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Explain"
                    color: explainButton.foreground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "e"
                    color: Qt.darker(root.contentForeground, 1.65)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                onHovered: function(value) {
                  if (value && root.actionAvailable(2)) {
                    root.cursorActive = true
                    root.selectedAction = 2
                  }
                }
                onClicked: root.explainQuote()
              }

              Button {
                id: refreshButton
                text: ""
                foreground: root.contentForeground
                horizontalPadding: Style.space(9)
                verticalPadding: Style.space(4)
                implicitWidth: Math.max(Style.space(66), refreshContent.implicitWidth + horizontalPadding * 2)
                implicitHeight: refreshContent.implicitHeight + verticalPadding * 2
                hasCursor: root.cursorActive && root.selectedAction === 3 && root.actionAvailable(3)
                enabled: !root.loading
                opacity: root.actionAvailable(3) ? 1.0 : 0.45

                Column {
                  id: refreshContent
                  anchors.centerIn: parent
                  spacing: Style.space(1)
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.loading ? "Refresh…" : "Refresh"
                    color: refreshButton.foreground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "r"
                    color: Qt.darker(root.contentForeground, 1.65)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                onHovered: function(value) {
                  if (value && root.actionAvailable(3)) {
                    root.cursorActive = true
                    root.selectedAction = 3
                  }
                }
                onClicked: root.loadQuote(true)
              }
            }
          }

          Item {
            id: footerArea
            width: parent.width
            implicitHeight: Math.max(navigationHint.implicitHeight, sourceButton.implicitHeight)

            Text {
              id: navigationHint
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              text: "↑/↓ scroll   ←/→ move   esc close"
              textFormat: Text.PlainText
              color: Qt.darker(root.contentForeground, 1.45)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            Button {
              id: sourceButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "ZenQuotes"
              foreground: Qt.darker(root.contentForeground, 1.4)
              fontFamily: root.contentFontFamily
              fontSize: Style.font.caption
              horizontalPadding: Style.space(4)
              verticalPadding: Style.space(2)
              tooltipText: "Quote source · press z"
              onClicked: root.openSource()
            }
          }
        }
      }
    }
  }
}
