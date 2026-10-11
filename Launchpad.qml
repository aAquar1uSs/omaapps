pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import "ui" as Views
import "ui/Paging.js" as Paging
import "ui/Apps.js" as Apps

// Launchpad-style full-screen app grid, an `overlay` plugin. Apps come straight
// from DesktopEntries, filtered like the Omarchy launcher (NoDisplay,
// launcher.hides, entries hidden for this desktop). Summon with:
//   omarchy-shell shell summon io.github.aaquar1uss.omaapps '{}'
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string filterText: ""
  property var apps: []
  property int selectedIndex: -1
  property int currentPage: 0
  property var swipeState: Paging.newSwipe()
  property var configuredHides: ({})
  property var desktopHides: ({})

  readonly property string pluginId: (root.manifest && root.manifest.id) || "io.github.aaquar1uss.omaapps"

  // Touchpad paging feel: wheel units to cross, quiet time that ends a
  // gesture's kinetic tail, and the gap after which small scrolls reset.
  readonly property var swipeOptions: ({ threshold: 100, cooldown: 280, idle: 160 })

  property color foreground: Color.menu.text
  property color selectedBackground: Color.menu.selectedBackground
  property color scrim: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.93)
  property string fontFamily: Style.font.menuFamily

  readonly property int iconSize: Style.space(64)
  readonly property int cellWidth: Math.round(iconSize * 2.4)
  readonly property int cellHeight: iconSize + Style.font.subtitle * 2 + Style.spacing.lg * 4
  readonly property var shape: Paging.gridShape(pager.width, pager.height, cellWidth, cellHeight)
  readonly property int perPage: shape.columns * shape.rows
  readonly property var pages: Paging.paginate(root.apps, root.perPage)

  function open(payloadJson) {
    root.filterText = ""
    root.selectedIndex = -1
    root.swipeState = Paging.newSwipe()
    root.refresh()
    root.opened = true
    root.goToPage(0, false)
    intro.restart()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function refresh() {
    var hidden = ({})
    for (var a in root.configuredHides) hidden[a] = true
    for (var b in root.desktopHides) hidden[b] = true
    root.apps = Apps.list(DesktopEntries.applications.values || [], root.filterText, hidden)
    if (root.selectedIndex >= root.apps.length) root.selectedIndex = root.apps.length - 1
  }

  function iconFor(icon) {
    var value = String(icon || "")
    if (value.charAt(0) === "/") return "file://" + value
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    var themed = value ? Quickshell.iconPath(value, true) : ""
    return themed || Quickshell.iconPath("application-x-executable", true)
  }

  function setFilter(text) {
    root.filterText = text
    root.refresh()
    root.selectedIndex = text && root.apps.length > 0 ? 0 : -1
    root.goToPage(0, false)
  }

  function goToPage(page, animate) {
    var target = Paging.clampPage(page, root.pages.length)
    root.currentPage = target
    if (animate === false) pager.positionViewAtIndex(target, ListView.Beginning)
    pager.currentIndex = target
  }

  function stepPage(step) {
    if (step === 0) return
    root.goToPage(root.currentPage + step, true)
    if (root.selectedIndex >= 0) root.selectedIndex = Math.min(root.apps.length - 1, root.currentPage * root.perPage)
  }

  function moveSelection(dx, dy) {
    // The first arrow press only lights up the current page's first tile.
    var next = root.selectedIndex < 0
      ? Math.min(root.apps.length - 1, root.currentPage * root.perPage)
      : Paging.moveIndex(root.selectedIndex, dx, dy, root.shape.columns, root.shape.rows, root.apps.length)
    root.selectedIndex = next
    if (next >= 0) {
      var page = Math.floor(next / root.perPage)
      if (page !== root.currentPage) root.goToPage(page, true)
    }
  }

  function launch(app) {
    if (!app) return
    // Same launch path as the Omarchy launcher: a scope under
    // app-graphical.slice, and gtk-launch resolves the desktop id.
    Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", app.id + ".desktop"])
    root.dismiss()
  }

  function activateSelection() {
    if (root.selectedIndex >= 0) root.launch(root.apps[root.selectedIndex])
    else if (root.filterText && root.apps.length > 0) root.launch(root.apps[0])
  }

  function onWheel(event) {
    // Touchpads report horizontal swipes on x; a mouse wheel only has y.
    var delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
    if (delta === 0) return
    var result = Paging.swipe(root.swipeState, delta, Date.now(), root.swipeOptions)
    root.swipeState = result.state
    root.stepPage(result.step)
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() {
      hiddenScan.running = true
      if (root.opened) root.refresh()
    }
  }

  FileView {
    path: root.omarchyPath + "/default/omarchy/launcher.hides"
    watchChanges: true
    printErrors: false
    onLoaded: root.configuredHides = Apps.parseIds(text())
    onFileChanged: reload()
    onLoadFailed: root.configuredHides = ({})
  }

  // Entries hidden for this desktop (Hidden, OnlyShowIn, NotShowIn), using the
  // same scan script as the Omarchy launcher.
  Process {
    id: hiddenScan
    running: true
    command: [
      root.omarchyPath + "/shell/services/hidden-entries.sh",
      [Quickshell.env("XDG_CURRENT_DESKTOP"), Quickshell.env("XDG_SESSION_DESKTOP"), Quickshell.env("DESKTOP_SESSION")]
        .filter(function(v) { return String(v || "").length > 0 }).join(":")
    ]
    stdout: StdioCollector {
      onStreamFinished: root.desktopHides = Apps.parseIds(text)
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omaapps"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        var key = event.key
        if (key === Qt.Key_Escape) {
          if (root.filterText) root.setFilter("")
          else root.dismiss()
        } else if (Util.editsFilter(event, root.filterText)) {
          root.setFilter(Util.editedFilter(event, root.filterText))
        } else if (key === Qt.Key_Left) {
          root.moveSelection(-1, 0)
        } else if (key === Qt.Key_Right) {
          root.moveSelection(1, 0)
        } else if (key === Qt.Key_Up) {
          root.moveSelection(0, -1)
        } else if (key === Qt.Key_Down) {
          root.moveSelection(0, 1)
        } else if (key === Qt.Key_PageUp) {
          root.stepPage(-1)
        } else if (key === Qt.Key_PageDown) {
          root.stepPage(1)
        } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
          root.activateSelection()
        } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) > 32 && event.text.charCodeAt(0) !== 127
                   || event.text === " " && root.filterText) {
          root.setFilter(root.filterText + event.text)
        } else {
          return
        }
        event.accepted = true
      }
    }

    Item {
      id: content
      anchors.fill: parent
      anchors.topMargin: Style.space(48)
      anchors.bottomMargin: Style.space(32)
      transformOrigin: Item.Center

      ParallelAnimation {
        id: intro
        NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "scale"; from: 1.06; to: 1; duration: 200; easing.type: Easing.OutCubic }
      }

      Rectangle {
        id: search
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(Style.space(320), parent.width - Style.space(32))
        height: Style.font.heading + Style.spacing.controlPaddingY * 2 + Style.spacing.sm * 2
        radius: height / 2
        color: root.selectedBackground
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

        Row {
          anchors.centerIn: parent
          width: parent.width - Style.spacing.xxl * 2
          spacing: Style.spacing.lg

          Text {
            id: glyph
            text: ""
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            width: parent.width - glyph.width - parent.spacing
            textFormat: Text.PlainText
            text: root.filterText || "Search"
            color: root.foreground
            opacity: root.filterText ? 1 : 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideLeft
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      ListView {
        id: pager
        anchors.top: search.bottom
        anchors.topMargin: Style.space(32)
        anchors.bottom: dots.top
        anchors.bottomMargin: Style.space(16)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(parent.width * 0.08)
        anchors.rightMargin: Math.round(parent.width * 0.08)
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 260
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: root.pages.length
        onCurrentIndexChanged: root.currentPage = currentIndex

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) { root.onWheel(event) }
        }

        delegate: Item {
          id: page
          required property int index
          width: pager.width
          height: pager.height

          MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
          }

          // Positioned as if every page were full, so partial pages and search
          // results keep tiles in the same slots instead of re-centering.
          Grid {
            x: Math.round((page.width - root.shape.columns * root.cellWidth) / 2)
            y: Math.round((page.height - root.shape.rows * root.cellHeight) / 2)
            columns: root.shape.columns

            Repeater {
              model: root.pages[page.index] || []

              Views.AppTile {
                required property var modelData
                required property int index
                readonly property int globalIndex: page ? page.index * root.perPage + index : -1

                width: root.cellWidth
                height: root.cellHeight
                app: modelData
                iconSource: root.iconFor(modelData.icon)
                iconSize: root.iconSize
                selected: root.selectedIndex === globalIndex
                textColor: root.foreground
                selectedBackground: root.selectedBackground
                fontFamily: root.fontFamily
                onHovered: root.selectedIndex = globalIndex
                onActivated: root.launch(modelData)
              }
            }
          }
        }
      }

      Text {
        anchors.centerIn: pager
        visible: root.apps.length === 0
        textFormat: Text.PlainText
        text: root.filterText ? "No apps match “" + root.filterText + "”" : "No apps found"
        color: root.foreground
        opacity: 0.7
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
      }

      Views.PageDots {
        id: dots
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        count: root.pages.length
        current: root.currentPage
        color: root.foreground
        onPageClicked: function(page) { root.goToPage(page, true) }
      }
    }
  }
}
