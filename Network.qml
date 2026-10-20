import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var theme: ({})
  property var options: ({})
  property bool wifiOn: false
  property string ssid: ""
  property int strength: 0
  property bool btOn: false
  property var btDevs: []

  readonly property bool fluid: true
  implicitWidth: 280
  implicitHeight: 2 * 56 + 10

  function parse(t) {
    var w = false, s = "", g = 0, b = false, devs = [];
    t.split("\n").forEach(function (l) {
      if (l.indexOf("W:") === 0) w = l.slice(2).trim() === "enabled";
      else if (l.indexOf("A:yes:") === 0) {
        var r = l.slice(6), p = r.indexOf(":");
        g = parseInt(r.slice(0, p)) || 0;
        s = r.slice(p + 1).replace(/\\:/g, ":");
      }
      else if (l.indexOf("B:") === 0) b = l.slice(2).trim() === "yes";
      else if (l.indexOf("D:") === 0) devs.push(l.slice(2).trim());
    });
    wifiOn = w; ssid = s; strength = g; btOn = b; btDevs = devs;
  }

  Process {
    id: proc
    command: ["sh", "-c", "echo W:$(nmcli radio wifi 2>/dev/null); nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi list --rescan no 2>/dev/null | grep '^yes' | head -1 | sed 's/^/A:/'; echo B:$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}'); bluetoothctl devices Connected 2>/dev/null | sed 's/^Device [0-9A-Fa-f:]* /D:/'"]
    stdout: StdioCollector { onStreamFinished: root.parse(text) }
  }
  Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!proc.running) proc.running = true }
  Timer { id: soon; interval: 800; onTriggered: if (!proc.running) proc.running = true }

  component Glyph: Canvas {
    property string kind: "wifi"
    property color col: "white"
    onColChanged: requestPaint()
    onKindChanged: requestPaint()
    onPaint: {
      var c = getContext("2d");
      c.reset();
      c.strokeStyle = col; c.fillStyle = col; c.lineWidth = 2.2; c.lineCap = "round"; c.lineJoin = "round";
      var w = width, h = height;
      if (kind === "wifi") {
        var cx = w / 2, cy = h * 0.78;
        c.beginPath(); c.arc(cx, cy, 1.7, 0, 2 * Math.PI); c.fill();
        for (var i = 1; i <= 3; i++) { c.beginPath(); c.arc(cx, cy, i * h * 0.2, -Math.PI * 0.8, -Math.PI * 0.2); c.stroke(); }
      } else {
        c.beginPath();
        c.moveTo(w * 0.28, h * 0.3); c.lineTo(w * 0.72, h * 0.7); c.lineTo(w * 0.5, h * 0.9);
        c.lineTo(w * 0.5, h * 0.1); c.lineTo(w * 0.72, h * 0.3); c.lineTo(w * 0.28, h * 0.7);
        c.stroke();
      }
    }
  }

  component Tile: Rectangle {
    property var th
    property string kind
    property bool on
    property string title
    property string sub
    signal clicked()
    width: parent ? parent.width : 280
    height: 56
    radius: 16
    color: th.surface
    Rectangle {
      id: dot
      anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
      width: 36; height: 36; radius: 18
      color: on ? th.accent : th.border
      Glyph { anchors.centerIn: parent; width: 20; height: 20; kind: parent.parent.kind; col: on ? th.accent_fg : th.subtext }
    }
    Column {
      anchors { left: dot.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
      Text { text: title; color: th.text; font.pixelSize: 14; font.weight: Font.DemiBold; font.family: th.font }
      Text { width: parent.width; elide: Text.ElideRight; text: sub; color: th.subtext; font.pixelSize: 12; font.family: th.font }
    }
    MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
  }

  Column {
    width: parent.width
    spacing: 10
    Tile {
      th: root.theme; kind: "wifi"; on: root.wifiOn; title: "Wi-Fi"
      sub: !root.wifiOn ? "Off" : (root.ssid !== "" ? root.ssid + "  \u00B7  " + root.strength + "%" : "Not connected")
      onClicked: { Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"]); soon.restart(); }
    }
    Tile {
      th: root.theme; kind: "bt"; on: root.btOn; title: "Bluetooth"
      sub: !root.btOn ? "Off" : (root.btDevs.length > 0 ? root.btDevs.join(", ") : "On")
      onClicked: { Quickshell.execDetached(["bluetoothctl", "power", root.btOn ? "off" : "on"]); soon.restart(); }
    }
  }
}
