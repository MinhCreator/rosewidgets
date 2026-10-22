import QtQuick
import Quickshell

Item {
  id: root
  property var theme: ({})
  property var options: ({})

  readonly property real syn: 29.530588853
  readonly property bool south: options.hemisphere === "south"
  readonly property real age: {
    var d = (clk.date.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
    return ((d % syn) + syn) % syn;
  }
  readonly property real phase: age / syn
  readonly property real illum: (1 - Math.cos(2 * Math.PI * phase)) / 2
  readonly property var names: ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
    "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"]
  readonly property string phaseName: names[Math.floor(phase * 8 + 0.5) % 8]

  function until(target) { return ((target - age) % syn + syn) % syn; }
  function when(days) {
    var d = new Date(clk.date.getTime() + days * 86400000);
    return Qt.formatDate(d, "ddd d MMM");
  }

  implicitWidth: 290
  implicitHeight: 116

  SystemClock { id: clk; precision: SystemClock.Minutes }

  Canvas {
    id: cv
    width: 108; height: 108
    anchors.verticalCenter: parent.verticalCenter
    property real ph: root.phase
    property color lit: "#ece9dc"
    property color dark: root.theme.surface !== undefined ? root.theme.surface : "#313244"
    onPhChanged: requestPaint()
    onDarkChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
      var c = getContext("2d");
      c.reset();
      var r = width / 2 - 3, cx = width / 2, cy = height / 2;

      var g = c.createRadialGradient(cx, cy, r * 0.9, cx, cy, r + 3);
      g.addColorStop(0, "rgba(236,233,220,0.18)");
      g.addColorStop(1, "rgba(236,233,220,0)");
      c.fillStyle = g;
      c.beginPath(); c.arc(cx, cy, r + 3, 0, 2 * Math.PI); c.fill();

      c.fillStyle = dark;
      c.beginPath(); c.arc(cx, cy, r, 0, 2 * Math.PI); c.fill();

      var k = Math.cos(2 * Math.PI * ph);
      var s = (ph < 0.5 ? 1 : -1) * (root.south ? -1 : 1);
      var N = 48, t, i;
      c.beginPath();
      for (i = 0; i <= N; i++) {
        t = Math.PI * i / N;
        var x = cx + s * r * Math.sin(t), y = cy - r * Math.cos(t);
        if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
      }
      for (i = N; i >= 0; i--) {
        t = Math.PI * i / N;
        c.lineTo(cx + s * k * r * Math.sin(t), cy - r * Math.cos(t));
      }
      c.closePath();
      c.fillStyle = lit;
      c.fill();

      c.save();
      c.clip();
      c.fillStyle = "rgba(60,60,70,0.16)";
      var spots = [[-0.30, -0.28, 0.26], [0.18, -0.35, 0.20], [-0.12, 0.10, 0.30], [0.30, 0.22, 0.16], [-0.38, 0.40, 0.12]];
      for (var j = 0; j < spots.length; j++) {
        c.beginPath();
        c.arc(cx + spots[j][0] * r, cy + spots[j][1] * r, spots[j][2] * r, 0, 2 * Math.PI);
        c.fill();
      }
      c.restore();

      c.strokeStyle = "rgba(255,255,255,0.12)";
      c.lineWidth = 1;
      c.beginPath(); c.arc(cx, cy, r, 0, 2 * Math.PI); c.stroke();
    }
  }

  Column {
    anchors { left: cv.right; leftMargin: 18; right: parent.right; verticalCenter: parent.verticalCenter }
    spacing: 3
    Text {
      width: parent.width; elide: Text.ElideRight
      text: root.phaseName
      color: root.theme.text; font.pixelSize: 17; font.weight: Font.DemiBold; font.family: root.theme.font
    }
    Text {
      text: Math.round(root.illum * 100) + "% illuminated"
      color: root.theme.accent; font.pixelSize: 13; font.family: root.theme.font
    }
    Text {
      text: "Age " + root.age.toFixed(1) + " days"
      color: root.theme.subtext; font.pixelSize: 12; font.family: root.theme.font
    }
    Item { width: 1; height: 6 }
    Text {
      text: "Full   " + root.when(root.until(root.syn / 2))
      color: root.theme.subtext; font.pixelSize: 12; font.family: root.theme.font
    }
    Text {
      text: "New   " + root.when(root.until(root.syn))
      color: root.theme.subtext; font.pixelSize: 12; font.family: root.theme.font
    }
  }
}
