import QtQuick
import Quickshell

Item {
  id: root
  property var theme: ({})
  property var options: ({})
  readonly property bool mon: (options.week_start || "monday") !== "sunday"
  property int offset: 0
  readonly property real baseCw: 34
  readonly property real cw: width > 0 ? width / 7 : baseCw
  readonly property real ch: 30
  readonly property bool fluid: true

  implicitWidth: baseCw * 7
  implicitHeight: 56 + ch * 6

  SystemClock { id: clk; precision: SystemClock.Minutes }

  readonly property var first: new Date(clk.date.getFullYear(), clk.date.getMonth() + offset, 1)
  readonly property var labels: mon ? ["M", "T", "W", "T", "F", "S", "S"] : ["S", "M", "T", "W", "T", "F", "S"]
  readonly property var cells: {
    var out = [], f = first, t = clk.date;
    var sd = (f.getDay() + (mon ? 6 : 0)) % 7;
    for (var i = 0; i < 42; i++) {
      var d = new Date(f.getFullYear(), f.getMonth(), 1 - sd + i);
      out.push({
        d: d.getDate(),
        cur: d.getMonth() === f.getMonth(),
        today: d.getFullYear() === t.getFullYear() && d.getMonth() === t.getMonth() && d.getDate() === t.getDate()
      });
    }
    return out;
  }

  Item {
    width: parent.width; height: 30
    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      Text { text: Qt.formatDate(root.first, "MMMM"); color: root.theme.accent; font.pixelSize: 17; font.weight: Font.Bold; font.family: root.theme.font }
      Text { text: Qt.formatDate(root.first, "yyyy"); color: root.theme.subtext; font.pixelSize: 17; font.family: root.theme.font }
      MouseArea { anchors.fill: parent; onClicked: root.offset = 0 }
    }
    Row {
      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
      spacing: 14
      Text { text: "\u2039"; color: root.theme.text; font.pixelSize: 24; MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.offset-- } }
      Text { text: "\u203A"; color: root.theme.text; font.pixelSize: 24; MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.offset++ } }
    }
  }
  Row {
    y: 30
    Repeater {
      model: root.labels
      Text {
        required property string modelData
        width: root.cw; height: 26
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        text: modelData; color: root.theme.subtext
        font.pixelSize: 11; font.weight: Font.DemiBold; font.family: root.theme.font
      }
    }
  }
  Grid {
    y: 56
    columns: 7
    Repeater {
      model: root.cells
      Item {
        required property var modelData
        width: root.cw; height: root.ch
        Rectangle {
          anchors.centerIn: parent
          width: 28; height: 28; radius: 14
          color: modelData.today ? root.theme.accent : "transparent"
        }
        Text {
          anchors.centerIn: parent
          text: modelData.d
          opacity: modelData.cur ? 1 : 0.35
          color: modelData.today ? root.theme.accent_fg : root.theme.text
          font.pixelSize: 13; font.weight: modelData.today ? Font.Bold : Font.Normal
          font.family: root.theme.font
        }
      }
    }
  }
}
