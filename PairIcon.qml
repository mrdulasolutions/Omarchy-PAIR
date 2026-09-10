import QtQuick
import qs.Commons

Item {
  id: root

  property real iconSize: Style.bar.iconCanvas
  property color fallbackColor: Color.foreground
  property string fallbackFontFamily: Style.font.family

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize

  Image {
    id: mark
    anchors.fill: parent
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
}
