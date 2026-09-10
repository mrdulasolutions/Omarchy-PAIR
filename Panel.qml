import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Helper popup only. The bar chip and live PAIR status live in BarWidget.qml.
Panel {
  id: root
  moduleName: "io.github.mrdulasolutions.pair"
  ipcTarget: "io.github.mrdulasolutions.pair"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var host: hostWidget

  readonly property string pairIcon: host && host.pairIcon ? host.pairIcon : "󰢮"
  readonly property bool pairInstalled: host ? host.pairInstalled === true : false
  readonly property bool pairRunning: host ? host.pairRunning === true : false
  readonly property bool pairReady: host ? host.pairReady === true : false
  readonly property bool busy: host ? host.busy === true : false
  readonly property bool pairUpdateAvailable: host ? host.pairUpdateAvailable === true : false
  readonly property bool pairFirewallBlocked: host ? host.pairFirewallBlocked === true : false
  readonly property string pairVersion: host && host.pairVersion ? host.pairVersion : ""
  readonly property string pairLatest: host && host.pairLatest ? host.pairLatest : ""
  readonly property string pairGpuNote: host && host.pairGpuNote ? host.pairGpuNote : ""
  readonly property string pairOllama: host && host.pairOllama ? host.pairOllama : "http://127.0.0.1:11434"
  readonly property string pairOpenai: host && host.pairOpenai ? host.pairOpenai : "http://127.0.0.1:1234"
  readonly property string lastError: host && host.lastError ? host.lastError : ""
  readonly property string heroMeta: host && host.heroMeta ? host.heroMeta : "NOT INSTALLED"
  readonly property string heroDetail: host && host.heroDetail ? host.heroDetail : ""
  readonly property string primaryLabel: host && host.primaryLabel ? host.primaryLabel : "Install NVIDIA PAIR"
  readonly property string primaryIcon: host && host.primaryIcon ? host.primaryIcon : "󰇚"
  readonly property string statusText: host && host.statusText ? host.statusText : "Checking NVIDIA PAIR…"
  readonly property var updater: host && host.updater ? host.updater : Model.updateAction({}, false)

  readonly property string focusAction: host && host.focusAction ? host.focusAction : "primary"
  readonly property bool cursorActive: host ? host.cursorActive === true : false

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property color contentUrgent: bar && bar.urgent ? bar.urgent : Color.urgent
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
    if (host && typeof host.refresh === "function") host.refresh(true)
    if (host && typeof host.probe === "function") host.probe()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setHost(name, value) {
    if (host) host[name] = value
  }

  function runPrimary() {
    if (host && typeof host.runPrimary === "function") host.runPrimary()
  }

  function runUpdate() {
    if (host && typeof host.runUpdate === "function") host.runUpdate()
  }

  function runFirewall() {
    if (host && typeof host.runCtl === "function") host.runCtl(["firewall"])
  }

  function activateCursor() {
    if (host && typeof host.activateCursor === "function") host.activateCursor()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
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
          root.setHost("cursorActive", true)
          return
        }
        if (dy !== 0 || dx !== 0) {
          var next = "primary"
          if (root.focusAction === "primary") next = "update"
          else if (root.focusAction === "update") next = "firewall"
          root.setHost("focusAction", next)
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
          visible: root.pairReady
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
          text: root.primaryLabel
          iconText: root.primaryIcon
          iconSpinning: root.busy
          enabled: !root.busy
          hasCursor: root.cursorActive && root.focusAction === "primary"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          bordered: true
          onClicked: root.runPrimary()
          onHovered: function(isHovered) {
            if (isHovered) {
              root.setHost("cursorActive", true)
              root.setHost("focusAction", "primary")
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
              root.setHost("cursorActive", true)
              root.setHost("focusAction", "update")
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
          onClicked: root.runFirewall()
          onHovered: function(isHovered) {
            if (isHovered) {
              root.setHost("cursorActive", true)
              root.setHost("focusAction", "firewall")
            }
          }
        }
      }
    }
  }
}
