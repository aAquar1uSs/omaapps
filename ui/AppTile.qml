import QtQuick
import qs.Commons

// One app in the grid: icon over an elided name. Hover marks it selected so
// mouse and keyboard share a single highlight.
Item {
  id: tile

  required property var app
  required property string iconSource
  property bool selected: false
  property int iconSize: 64
  property color textColor: Color.menu.text
  property color selectedBackground: Color.menu.selectedBackground
  property string fontFamily: Style.font.menuFamily

  signal activated()
  signal hovered()

  Rectangle {
    anchors.fill: parent
    anchors.margins: Style.spacing.sm
    radius: Math.max(Style.cornerRadius, Style.space(12))
    color: tile.selected ? tile.selectedBackground : "transparent"
  }

  Column {
    anchors.centerIn: parent
    width: parent.width - Style.spacing.xl * 2
    spacing: Style.spacing.lg

    Image {
      anchors.horizontalCenter: parent.horizontalCenter
      width: tile.iconSize
      height: tile.iconSize
      sourceSize.width: tile.iconSize * 2
      sourceSize.height: tile.iconSize * 2
      source: tile.iconSource
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
      mipmap: true
      scale: mouse.pressed ? 0.9 : 1
      Behavior on scale { NumberAnimation { duration: 90 } }
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: tile.app ? tile.app.name : ""
      color: tile.textColor
      font.family: tile.fontFamily
      font.pixelSize: Style.font.subtitle
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: if (containsMouse) tile.hovered()
    onClicked: tile.activated()
  }
}
