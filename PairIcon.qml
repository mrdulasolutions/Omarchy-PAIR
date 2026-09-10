import QtQuick
import qs.Commons

Item {
  id: root

  property real iconSize: Style.bar.iconCanvas
  property color fallbackColor: Color.foreground
  property string fallbackFontFamily: Style.font.family
  property color healthColor: "#3ea072"
  property bool showHealth: true

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize

  Image {
    id: mark
    anchors.fill: parent
    anchors.margins: Math.max(1, root.width * 0.08)
    source: Qt.resolvedUrl("nvpair.png")
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: true
    visible: status === Image.Ready
  }

  Text {
    anchors.centerIn: parent
    visible: mark.status !== Image.Ready
    text: "󰢮"
    color: root.fallbackColor
    font.family: root.fallbackFontFamily
    font.pixelSize: Math.max(10, root.iconSize * 0.9)
  }

  Rectangle {
    visible: root.showHealth
    width: Math.max(7, root.width * 0.38)
    height: width
    radius: width / 2
    color: root.healthColor
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    border.width: 1
    border.color: Color.background
  }
}
