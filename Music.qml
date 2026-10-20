import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris

Item {
  id: root
  property var theme: ({})
  property var options: ({})
  readonly property var player: {
    var l = Mpris.players.values;
    for (var i = 0; i < l.length; i++) if (l[i].isPlaying) return l[i];
    return l.length > 0 ? l[0] : null;
  }
  readonly property real len: player && player.lengthSupported ? player.length : 0
  readonly property real pos: player && player.positionSupported ? player.position : 0
  function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2); }

  readonly property bool fluid: true
  implicitWidth: 340
  implicitHeight: 112

  Timer {
    running: root.player !== null && root.player.isPlaying
    interval: 1000; repeat: true
    onTriggered: root.player.positionChanged()
  }

  component Btn: Text {
    id: b
    signal clicked()
    property color fg: "white"
    color: fg; font.pixelSize: 20
    opacity: ma.pressed ? 0.5 : 1
    MouseArea { id: ma; anchors.fill: parent; anchors.margins: -8; onClicked: b.clicked() }
  }

  Item {
    id: art
    width: 96; height: 96
    anchors.verticalCenter: parent.verticalCenter
    Rectangle {
      anchors.fill: parent; radius: 14; color: root.theme.surface
      Text { anchors.centerIn: parent; text: "♪"; font.pixelSize: 38; color: root.theme.subtext }
    }
    Image {
      id: img
      anchors.fill: parent; visible: false; asynchronous: true
      sourceSize.width: 200; sourceSize.height: 200
      fillMode: Image.PreserveAspectCrop
      source: root.player ? root.player.trackArtUrl : ""
    }
    Item {
      id: mask
      anchors.fill: parent; visible: false; layer.enabled: true
      Rectangle { anchors.fill: parent; radius: 14 }
    }
    MultiEffect {
      anchors.fill: parent
      visible: img.status === Image.Ready
      source: img; maskEnabled: true; maskSource: mask
    }
  }

  Column {
    anchors { left: art.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
    spacing: 2
    Text {
      width: parent.width; elide: Text.ElideRight
      text: root.player ? (root.player.trackTitle || "Unknown") : "Nothing playing"
      color: root.theme.text; font.pixelSize: 16; font.weight: Font.DemiBold; font.family: root.theme.font
    }
    Text {
      width: parent.width; elide: Text.ElideRight
      text: root.player ? (root.player.trackArtist || "") : ""
      color: root.theme.subtext; font.pixelSize: 13; font.family: root.theme.font
    }
    Item { width: 1; height: 6 }
    Item {
      width: parent.width; height: 14
      Rectangle {
        y: 5; width: parent.width; height: 4; radius: 2; color: root.theme.surface
        Rectangle {
          height: parent.height; radius: 2; color: root.theme.accent
          width: root.len > 0 ? parent.width * Math.min(1, root.pos / root.len) : 0
        }
      }
      MouseArea {
        anchors.fill: parent
        onClicked: m => { if (root.player && root.player.canSeek && root.len > 0) root.player.position = m.x / width * root.len; }
      }
    }
    Item {
      width: parent.width; height: 12
      Text { text: root.fmt(root.pos); color: root.theme.subtext; font.pixelSize: 10; font.family: root.theme.font }
      Text { anchors.right: parent.right; text: root.fmt(root.len); color: root.theme.subtext; font.pixelSize: 10; font.family: root.theme.font }
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 26
      Btn { fg: root.theme.text; text: "\u23EE\uFE0E"; onClicked: if (root.player) root.player.previous() }
      Btn { fg: root.theme.text; text: root.player && root.player.isPlaying ? "\u23F8\uFE0E" : "\u25B6\uFE0E"; onClicked: if (root.player) root.player.togglePlaying() }
      Btn { fg: root.theme.text; text: "\u23ED\uFE0E"; onClicked: if (root.player) root.player.next() }
    }
  }
}
