import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.mrdulasolutions.pair"
  ipcTarget: "io.github.mrdulasolutions.pair"
  manageIpc: false

  readonly property var barIdentity: root
  readonly property string pairIcon: "󰢮"
  readonly property string ctlPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl"
  readonly property string statusPath: Quickshell.env("HOME") + "/.local/state/omarchy-pair/status.json"

  property var status: Model.emptyStatus()
  property bool pairInstalled: false
  property bool pairRunning: false
  property bool pairUpdateAvailable: false
  property bool pairHasGpu: false
  property string pairVersion: ""
  property string pairLatest: ""
  property string pairMessage: "Checking NVIDIA PAIR…"
  property string pairGpuNote: ""
  property string pairPairingNote: ""
  property bool pairFirewallBlocked: false
  property string pairOllama: "http://127.0.0.1:11434"
  property string pairOpenai: "http://127.0.0.1:1234"
  property string progressText: ""
  property string lastError: ""
  property string focusAction: "primary"
  property bool cursorActive: false
  property bool busy: actionProc.running
  property bool pairProcessAlive: false
  readonly property bool hideChip: pairProcessAlive && !root.opened && !busy

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property color contentUrgent: bar && bar.urgent ? bar.urgent : Color.urgent
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var primary: Model.primaryAction({ installed: pairInstalled, running: pairRunning }, busy)
  readonly property var updater: Model.updateAction({ updateAvailable: pairUpdateAvailable, latestVersion: pairLatest }, busy)
  readonly property string heroMeta: Model.versionLabel({ installed: pairInstalled, pairVersion: pairVersion })
  readonly property string heroDetail: pairRunning ? "RUNNING" : (pairInstalled ? "IDLE" : "")
  readonly property string tooltipText: {
    if (busy) return "NVIDIA PAIR — " + (progressText !== "" ? progressText : "working")
    if (pairUpdateAvailable) return "NVIDIA PAIR — update " + pairLatest + " available"
    if (pairProcessAlive || pairRunning) return "PAIR helper — NVIDIA tray is the official app icon"
    if (pairInstalled) return "PAIR helper — launch NVIDIA PAIR"
    return "PAIR helper — install NVIDIA PAIR"
  }
  readonly property string statusText: {
    if (busy && progressText !== "") return progressText
    if (lastError !== "") return lastError
    return pairMessage
  }

  implicitWidth: hideChip ? 0 : button.implicitWidth
  implicitHeight: hideChip ? 0 : button.implicitHeight
  visible: !hideChip

  function open() {
    root.controller.show()
    refresh(false)
    checkLatest()
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function applyStatus(text) {
    var next = Model.parseStatus(text)
    if (!next || next.pluginId !== "io.github.mrdulasolutions.pair") return
    root.status = next
    root.pairInstalled = next.installed === true
    root.pairRunning = next.running === true
    root.pairUpdateAvailable = next.updateAvailable === true
    root.pairHasGpu = next.hasNvidiaGpu === true
    root.pairVersion = String(next.pairVersion || "")
    root.pairLatest = String(next.latestVersion || "")
    root.pairMessage = String(next.message || "")
    root.pairGpuNote = String(next.gpuNote || "")
    root.pairPairingNote = String(next.pairingNote || "")
    root.pairFirewallBlocked = next.firewallBlocked === true
    root.pairOllama = String(next.endpoints && next.endpoints.ollama ? next.endpoints.ollama : root.pairOllama)
    root.pairOpenai = String(next.endpoints && next.endpoints.openai ? next.endpoints.openai : root.pairOpenai)
    if (next.ok) root.lastError = ""
    else root.lastError = next.error !== "" ? next.error : next.message
  }

  function refresh(checkLatestFlag) {
    if (statusProc.running) return
    statusProc.command = checkLatestFlag
      ? ["/usr/bin/bash", root.ctlPath, "status", "--check-latest"]
      : ["/usr/bin/bash", root.ctlPath, "status"]
    statusProc.running = true
  }

  function checkLatest() {
    if (latestProc.running) return
    latestProc.running = true
  }

  function runCtl(args) {
    if (root.busy) return
    root.lastError = ""
    root.progressText = ""
    var cmd = ["/usr/bin/bash", root.ctlPath]
    for (var i = 0; i < args.length; i++) cmd.push(args[i])
    actionProc.command = cmd
    actionProc.running = true
  }

  function runPrimary() {
    if (root.busy) return
    if (!root.pairInstalled) runCtl(["install"])
    else runCtl(["launch"])
  }

  function runUpdate() {
    if (root.busy) return
    if (root.pairUpdateAvailable) runCtl(["update"])
    else refresh(true)
  }

  function activateCursor() {
    if (root.focusAction === "update") runUpdate()
    else if (root.focusAction === "firewall") runCtl(["firewall"])
    else runPrimary()
  }

  function notify(headline, body, urgency) {
    var args = ["omarchy-notification-send", "-g", root.pairIcon, "-u", urgency || "low", "--app-name", "NVIDIA PAIR", headline]
    if (body && body !== "") args.push(body)
    Quickshell.execDetached(args)
  }

  IpcHandler {
    target: "io.github.mrdulasolutions.pair"

    function refresh(): void { root.refresh(true) }
    function install(): void { root.runCtl(["install"]) }
    function update(): void { root.runCtl(["update"]) }
    function launch(): void { root.runCtl(["launch"]) }
    function firewall(): void { root.runCtl(["firewall"]) }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.pairIcon
    dimmed: !root.pairInstalled || root.busy
    tooltipText: root.tooltipText
    onPressed: function(b) {
      if (b === Qt.RightButton) root.runPrimary()
      else if (b === Qt.MiddleButton) root.runUpdate()
      else root.toggle()
    }
  }

  FileView {
    id: statusFile
    path: root.statusPath
    preload: true
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var body = ""
      try { body = text() } catch (e) { body = text }
      if (body && String(body).trim() !== "") root.applyStatus(body)
    }
  }

  Process {
    id: statusProc
    command: ["/usr/bin/bash", root.ctlPath, "status"]
    stdout: StdioCollector {
      id: statusOut
      waitForEnd: true
    }
    onExited: function(exitCode) {
      var out = statusOut.text ? statusOut.text : ""
      if (out !== "") root.applyStatus(out)
      statusFile.reload()
      if (exitCode !== 0 && root.lastError === "" && !root.pairInstalled)
        root.lastError = "Could not read PAIR status (exit " + exitCode + ")."
    }
  }

  Process {
    id: latestProc
    command: ["/usr/bin/bash", root.ctlPath, "status", "--check-latest"]
    stdout: StdioCollector {
      id: latestOut
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0 && latestOut.text) root.applyStatus(latestOut.text)
      statusFile.reload()
    }
  }

  Process {
    id: actionProc
    command: ["/usr/bin/bash", root.ctlPath, "status"]
    stdout: StdioCollector {
      id: actionOut
      waitForEnd: true
    }
    stderr: SplitParser {
      onRead: function(line) {
        var text = String(line || "").trim()
        if (text !== "") root.progressText = text
      }
    }
    onExited: function(exitCode) {
      root.applyStatus(actionOut.text)
      root.progressText = ""
      if (exitCode === 0) {
        root.lastError = ""
        if (!root.pairInstalled)
          root.notify("NVIDIA PAIR removed", "", "low")
        else if (root.pairRunning)
          root.notify("NVIDIA PAIR", root.pairMessage, "low")
        else
          root.notify("NVIDIA PAIR " + (root.pairVersion || ""), root.pairMessage, "low")
        return
      }
      if (root.lastError === "")
        root.lastError = root.progressText !== "" ? root.progressText : "PAIR command failed."
      root.notify("NVIDIA PAIR failed", root.lastError, "critical")
    }
  }

  Timer {
    interval: 2500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!aliveProc.running) aliveProc.running = true
  }

  Process {
    id: aliveProc
    command: ["pgrep", "-f", "/.local/opt/PAIR/nvpair"]
    onExited: function(code) { root.pairProcessAlive = (code === 0) }
  }

  Component.onCompleted: Qt.callLater(function() {
    statusFile.reload()
    var body = ""
    try { body = statusFile.text() } catch (e) { body = "" }
    if (body && String(body).trim() !== "") root.applyStatus(body)
    root.refresh(false)
  })

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root.barIdentity
    bar: root.bar
    open: root.opened && root.bar
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) {
          root.cursorActive = true
          return
        }
        if (dy !== 0 || dx !== 0) {
          if (root.focusAction === "primary") root.focusAction = "update"
          else if (root.focusAction === "update") root.focusAction = "firewall"
          else root.focusAction = "primary"
        }
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        PanelHero {
          title: "NVIDIA PAIR"
          meta: root.heroMeta
          detail: root.heroDetail
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          iconComponent: Component {
            Text {
              text: root.pairIcon
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        Text {
          width: parent.width
          text: root.statusText
          color: root.lastError !== "" ? root.contentUrgent : Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          visible: root.pairGpuNote !== ""
          text: root.pairGpuNote
          color: Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Column {
          width: parent.width
          visible: true
          spacing: Style.space(6)

          Text {
            text: "KNOWN ISSUES"
            color: Qt.darker(root.contentForeground, 1.45)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
          }

          Text {
            width: parent.width
            text: "Omarchy ufw drops inbound PAIR. If another PC never shows a PIN on this machine, or pairing closes with “already in another cluster”, allow LAN TCP 14318–14323 and UDP 5353."
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: "Leave cluster on both machines first. Keep one PIN open until the peer appears. Pairing does not need a local LLM."
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        Column {
          width: parent.width
          visible: root.pairInstalled
          spacing: Style.space(4)

          Text {
            text: "LOCAL ENDPOINTS"
            color: Qt.darker(root.contentForeground, 1.45)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
          }

          Text {
            width: parent.width
            text: "Ollama  " + root.pairOllama
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: "OpenAI  " + root.pairOpenai
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        Button {
          width: parent.width
          text: root.primary.label
          iconText: root.primary.icon
          iconSpinning: root.busy
          enabled: !root.busy
          hasCursor: root.cursorActive && root.focusAction === "primary"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          bordered: true
          onClicked: root.runPrimary()
          onHovered: function(isHovered) {
            if (isHovered) {
              root.cursorActive = true
              root.focusAction = "primary"
            }
          }
        }

        Button {
          width: parent.width
          text: root.updater.label
          iconText: root.updater.icon
          iconSpinning: root.busy && root.focusAction === "update"
          enabled: !root.busy
          hasCursor: root.cursorActive && root.focusAction === "update"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          bordered: true
          onClicked: root.runUpdate()
          onHovered: function(isHovered) {
            if (isHovered) {
              root.cursorActive = true
              root.focusAction = "update"
            }
          }
        }

        Button {
          width: parent.width
          visible: true
          text: root.pairFirewallBlocked ? "Allow PAIR on LAN" : "Check PAIR firewall"
          iconText: "󰦝"
          enabled: !root.busy
          hasCursor: root.cursorActive && root.focusAction === "firewall"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          bordered: true
          onClicked: root.runCtl(["firewall"])
          onHovered: function(isHovered) {
            if (isHovered) {
              root.cursorActive = true
              root.focusAction = "firewall"
            }
          }
        }
      }
    }
  }
}
