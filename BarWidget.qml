import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Live PAIR chip. Status and left-click live here — not in the popup —
// because a Panel used as the bar-widget entry never starts its Process
// children. Left-click is the NVIDIA tray's working action: show PAIR.
BarWidget {
  id: root
  moduleName: "io.github.mrdulasolutions.pair"

  readonly property string pairIcon: "󰢮"
  readonly property string ctlPath: String(Qt.resolvedUrl("scripts/pair-ctl")).replace(/^file:\/\//, "")
  readonly property string pluginDir: String(Qt.resolvedUrl("manifest.json")).replace(/^file:\/\//, "").replace(/\/manifest\.json$/, "")
  readonly property string homeDir: pluginDir.replace(/\/\.config\/omarchy\/plugins\/[^/]+$/, "")
  readonly property string statusPath: homeDir + "/.local/state/omarchy-pair/status.json"

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
  property bool trayHidden: false
  property var pairNodes: []
  property bool showKnownIssues: false

  readonly property bool busy: actionProc.running
  readonly property bool pairReady: pairRunning || pairInstalled
  readonly property int pairNodeCount: pairNodes && pairNodes.length ? pairNodes.length : 0
  readonly property var updater: Model.updateAction({ updateAvailable: pairUpdateAvailable, latestVersion: pairLatest }, busy && focusAction === "update")
  readonly property string heroMeta: {
    if (pairRunning && pairVersion) return "PAIR " + pairVersion.toUpperCase()
    if (pairRunning) return "RUNNING"
    if (pairInstalled) return "INSTALLED"
    return "NOT INSTALLED"
  }
  readonly property string heroDetail: {
    if (pairNodeCount > 0) return (pairRunning ? "RUNNING" : "CLUSTER") + " · " + pairNodeCount + (pairNodeCount === 1 ? " NODE" : " NODES")
    if (pairRunning) return "RUNNING"
    if (pairInstalled) return "IDLE"
    return ""
  }
  readonly property string primaryLabel: {
    if (busy && focusAction === "primary") return "Working…"
    if (pairRunning) return "Open PAIR"
    if (pairInstalled) return "Launch PAIR"
    return "Install NVIDIA PAIR"
  }
  readonly property string primaryIcon: pairRunning ? "󰏌" : (pairInstalled ? "󰐊" : "󰇚")
  readonly property string tooltipText: {
    if (busy) return "NVIDIA PAIR — " + (progressText !== "" ? progressText : "working")
    if (pairUpdateAvailable) return "NVIDIA PAIR — update " + pairLatest + " available"
    if (pairRunning && pairNodeCount > 0) return "PAIR — " + pairNodeCount + (pairNodeCount === 1 ? " node" : " nodes") + " (right-click for cluster)"
    if (pairRunning) return "PAIR — open app (right-click for cluster/install/update)"
    if (pairInstalled) return "PAIR — launch NVIDIA PAIR"
    return "PAIR — install NVIDIA PAIR"
  }
  readonly property string statusText: {
    if (busy && progressText !== "") return progressText
    if (lastError !== "") return lastError
    return pairMessage
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property real openPanelIndicatorWidth: button.width
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function jsonField(text, key) {
    var re = new RegExp('"' + key + '"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"')
    var m = String(text || "").match(re)
    if (!m) return ""
    return m[1].replace(/\\n/g, "\n").replace(/\\"/g, "\"").replace(/\\\\/g, "\\")
  }

  function applyProbe(text) {
    var t = String(text || "")
    var running = t.indexOf("RUNNING") !== -1
    var installed = running || t.indexOf("INSTALLED") !== -1
    root.pairRunning = running
    root.pairInstalled = installed
    var version = jsonField(t, "pairVersion")
    var latest = jsonField(t, "latestVersion")
    var message = jsonField(t, "message")
    var gpu = jsonField(t, "gpuNote")
    var ollama = jsonField(t, "ollama")
    var openai = jsonField(t, "openai")
    if (version !== "") root.pairVersion = version
    if (latest !== "") root.pairLatest = latest
    if (gpu !== "") root.pairGpuNote = gpu
    if (ollama.indexOf("http") === 0) root.pairOllama = ollama
    if (openai.indexOf("http") === 0) root.pairOpenai = openai
    if (t.indexOf('"updateAvailable": true') !== -1) root.pairUpdateAvailable = true
    if (t.indexOf('"updateAvailable": false') !== -1) root.pairUpdateAvailable = false
    if (t.indexOf('"firewallBlocked": true') !== -1) root.pairFirewallBlocked = true
    if (t.indexOf('"firewallBlocked": false') !== -1) root.pairFirewallBlocked = false
    if (message !== "") root.pairMessage = message
    else if (running) root.pairMessage = "PAIR is running. Left-click the chip to focus it."
    else if (installed) root.pairMessage = "PAIR is installed. Left-click the chip to launch it."
    if (running) {
      if (root.lastError.indexOf("Could not read PAIR status") === 0) root.lastError = ""
      if (!root.trayHidden) root.hideTray()
    }
  }

  function applyStatus(text) {
    var next = Model.parseStatus(text)
    if (!next || next.pluginId !== "io.github.mrdulasolutions.pair") return
    if (next.installed === true) root.pairInstalled = true
    if (next.running === true) root.pairRunning = true
    root.pairUpdateAvailable = next.updateAvailable === true
    root.pairHasGpu = next.hasNvidiaGpu === true
    root.pairVersion = String(next.pairVersion || "")
    root.pairLatest = String(next.latestVersion || "")
    if (String(next.message || "") !== "") root.pairMessage = String(next.message)
    root.pairGpuNote = String(next.gpuNote || "")
    root.pairPairingNote = String(next.pairingNote || "")
    root.pairFirewallBlocked = next.firewallBlocked === true
    root.pairOllama = String(next.endpoints && next.endpoints.ollama ? next.endpoints.ollama : root.pairOllama)
    root.pairOpenai = String(next.endpoints && next.endpoints.openai ? next.endpoints.openai : root.pairOpenai)
    if (next.ok) root.lastError = ""
    else if (!root.pairReady)
      root.lastError = next.error !== "" ? next.error : next.message
  }

  function probe() {
    if (!probeProc.running) probeProc.running = true
  }

  function refresh(checkLatestFlag) {
    probe()
    if (statusProc.running) return
    statusProc.command = checkLatestFlag
      ? ["/usr/bin/bash", root.ctlPath, "status", "--check-latest"]
      : ["/usr/bin/bash", root.ctlPath, "status"]
    statusProc.running = true
  }

  function hideTray() {
    if (!hideTrayProc.running) hideTrayProc.running = true
  }

  function runDetached(command) {
    if (root.bar && typeof root.bar.run === "function") root.bar.run(command)
    else Quickshell.execDetached(["bash", "-lc", command])
  }

  function launchPair() {
    if (root.pairRunning) {
      // Same job as NVIDIA's tray click: focus the live window, or poke
      // the desktop wrapper so Electron maps it again.
      root.runDetached('omarchy-hyprland-focus-app nvpair || "$HOME/.local/bin/nvpair-desktop"')
      root.hideTray()
      return
    }
    if (!root.pairInstalled) {
      root.togglePanel()
      return
    }
    root.runDetached('"$HOME/.local/bin/nvpair-desktop" || "$HOME/.local/opt/PAIR/nvpair" --ozone-platform-hint=auto')
    root.pairRunning = true
    root.pairMessage = "PAIR is running. Left-click the chip to focus it."
    Qt.callLater(function() {
      root.hideTray()
      root.probe()
    })
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
    if (root.pairReady) root.launchPair()
    else root.runCtl(["install"])
  }

  function runUpdate() {
    if (root.busy) return
    root.focusAction = "update"
    if (root.pairUpdateAvailable) root.runCtl(["update"])
    else root.runCtl(["status", "--check-latest"])
  }

  function applyCluster(text) {
    var nodes = Model.parseNodes(text)
    if (nodes) root.pairNodes = nodes
  }

  function refreshCluster() {
    if (!clusterProc.running) clusterProc.running = true
  }

  function toggleKnownIssues() {
    root.showKnownIssues = !root.showKnownIssues
  }

  function cycleFocusAction() {
    var order = ["primary", "update", "firewall", "issues"]
    var i = order.indexOf(root.focusAction)
    root.focusAction = order[(i < 0 ? 0 : i + 1) % order.length]
  }

  function activateCursor() {
    if (root.focusAction === "update") root.runUpdate()
    else if (root.focusAction === "firewall") root.runCtl(["firewall"])
    else if (root.focusAction === "issues") root.toggleKnownIssues()
    else root.runPrimary()
  }

  function notify(headline, body, urgency) {
    var args = ["omarchy-notification-send", "-g", root.pairIcon, "-u", urgency || "low", "--app-name", "NVIDIA PAIR", headline]
    if (body && body !== "") args.push(body)
    Quickshell.execDetached(args)
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  Component.onCompleted: {
    root.probe()
    root.hideTray()
    root.refresh(false)
    root.refreshCluster()
  }

  Process {
    id: probeProc
    command: ["/usr/bin/bash", "-c", "HOME=\"${HOME:-$(getent passwd \"$(id -u)\" | cut -d: -f6)}\"; if /usr/bin/pgrep -x nvpair >/dev/null; then printf 'RUNNING\\n'; elif /usr/bin/test -x \"$HOME/.local/opt/PAIR/nvpair\" || /usr/bin/test -x \"$HOME/.local/bin/nvpair-desktop\"; then printf 'INSTALLED\\n'; else printf 'MISSING\\n'; fi; if /usr/bin/test -f \"$HOME/.local/state/omarchy-pair/status.json\"; then /usr/bin/cat \"$HOME/.local/state/omarchy-pair/status.json\"; fi"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyProbe(text)
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.probe()
  }

  Timer {
    interval: 8000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshCluster()
  }

  Process {
    id: clusterProc
    command: ["/usr/bin/bash", root.ctlPath, "cluster"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyCluster(text)
    }
  }

  Process {
    id: statusProc
    command: ["/usr/bin/bash", root.ctlPath, "status"]
    stdout: StdioCollector {
      id: statusOut
      waitForEnd: true
      onStreamFinished: {
        if (text && String(text).trim() !== "") root.applyStatus(text)
      }
    }
    onExited: function(exitCode) {
      statusFile.reload()
      if (exitCode !== 0 && root.lastError === "" && !root.pairReady)
        root.lastError = "Could not read PAIR status (exit " + exitCode + ")."
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
      try { body = text() } catch (e) { body = "" }
      if (body && String(body).trim() !== "") root.applyStatus(body)
    }
  }

  Process {
    id: actionProc
    command: ["/usr/bin/bash", root.ctlPath, "status"]
    stdout: StdioCollector {
      id: actionOut
      waitForEnd: true
      onStreamFinished: {
        if (text && String(text).trim() !== "") root.applyStatus(text)
      }
    }
    stderr: SplitParser {
      onRead: function(line) {
        var text = String(line || "").trim()
        if (text !== "") root.progressText = text
      }
    }
    onExited: function(exitCode) {
      var out = actionOut.text ? actionOut.text : ""
      if (out !== "") root.applyStatus(out)
      root.progressText = ""
      if (exitCode === 0) {
        root.lastError = ""
        var headline = "NVIDIA PAIR"
        if (root.focusAction === "update" && !root.pairUpdateAvailable && root.pairLatest)
          headline = "PAIR is up to date"
        else if (root.pairUpdateAvailable)
          headline = "PAIR update available"
        else if (!root.pairInstalled)
          headline = "NVIDIA PAIR removed"
        root.notify(headline, root.pairMessage, "low")
        root.probe()
        return
      }
      if (root.lastError === "")
        root.lastError = root.progressText !== "" ? root.progressText : "PAIR command failed."
      root.notify("NVIDIA PAIR failed", root.lastError, "critical")
      root.probe()
    }
  }

  Process {
    id: hideTrayProc
    command: ["/usr/bin/bash", root.ctlPath, "hide-tray"]
    onExited: function(exitCode) {
      if (exitCode === 0) root.trayHidden = true
    }
  }

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

  IpcHandler {
    target: "io.github.mrdulasolutions.pair"

    function refresh(): void { root.refresh(true) }
    function install(): void { root.runCtl(["install"]) }
    function update(): void { root.runUpdate() }
    function launch(): void { root.launchPair() }
    function firewall(): void { root.runCtl(["firewall"]) }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    dimmed: root.busy || !root.pairReady
    tooltipText: root.tooltipText
    iconComponent: Component {
      PairIcon {
        anchors.fill: parent
        fallbackColor: button.foreground
        fallbackFontFamily: button.fontFamily
      }
    }
    onPressed: function(b) {
      if (b === Qt.RightButton) root.togglePanel()
      else if (b === Qt.MiddleButton) root.runUpdate()
      else if (root.pairReady) root.launchPair()
      else root.togglePanel()
    }
  }
}
