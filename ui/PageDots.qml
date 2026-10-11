pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

// Launchpad page indicator; click a dot to jump to that page.
Row {
  id: dots

  property int count: 0
  property int current: 0
  property color color: Color.menu.text
  property int dotSize: Style.space(8)

  signal pageClicked(int page)

  spacing: dotSize
  visible: count > 1

  Repeater {
    model: dots.count

    Item {
      id: dot
      required property int index
      width: dots.dotSize * 2
      height: dots.dotSize * 2

      Rectangle {
        anchors.centerIn: parent
        width: dots.dotSize
        height: dots.dotSize
        radius: dots.dotSize / 2
        color: dots.color
        opacity: dot.index === dots.current ? 0.9 : 0.3
        Behavior on opacity { NumberAnimation { duration: 150 } }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: dots.pageClicked(dot.index)
      }
    }
  }
}
