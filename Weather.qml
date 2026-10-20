import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var theme: ({})
  property var options: ({})
  property var data: null
  property string error: ""
  readonly property bool imp: options.units === "imperial"
  readonly property string loc: options.location || ""
  readonly property var gl: glyph(data ? data.desc : "")

  readonly property bool fluid: true
  implicitWidth: 300
  implicitHeight: 196

  function glyph(desc) {
    var d = (desc || "").toLowerCase();
    if (d.indexOf("thunder") >= 0) return ["\u26A1\uFE0E", theme.yellow];
    if (/snow|sleet|blizzard|ice/.test(d)) return ["\u2744\uFE0E", theme.teal];
    if (/rain|drizzle|shower/.test(d)) return ["\u2602\uFE0E", theme.blue];
    if (/fog|mist|haze/.test(d)) return ["\u224B", theme.subtext];
    if (/sun|clear/.test(d)) return ["\u2600\uFE0E", theme.yellow];
    return ["\u2601\uFE0E", theme.subtext];
  }
  function parse(t) {
    try {
      var j = JSON.parse(t), c = j.current_condition[0];
      root.data = {
        area: j.nearest_area[0].areaName[0].value,
        temp: imp ? c.temp_F : c.temp_C,
        feels: imp ? c.FeelsLikeF : c.FeelsLikeC,
        desc: c.weatherDesc[0].value,
        hum: c.humidity,
        wind: imp ? c.windspeedMiles + " mph" : c.windspeedKmph + " km/h",
        days: j.weather.slice(0, 3).map(function (w) {
          return { date: w.date, hi: imp ? w.maxtempF : w.maxtempC, lo: imp ? w.mintempF : w.mintempC };
        })
      };
      root.error = "";
    } catch (e) { if (!root.data) root.error = "No data"; }
  }
  function refresh() { if (!proc.running) proc.running = true; }
  onImpChanged: refresh()
  onLocChanged: refresh()

  Process {
    id: proc
    command: ["curl", "-sf", "-m", "10", "https://wttr.in/" + encodeURIComponent(root.loc) + "?format=j1"]
    stdout: StdioCollector { onStreamFinished: root.parse(text) }
    onExited: code => { if (code !== 0 && !root.data) root.error = "Offline"; }
  }
  Timer { interval: 1800000; running: true; repeat: true; onTriggered: root.refresh() }
  Timer { interval: 500; running: true; onTriggered: root.refresh() }

  Text {
    anchors.centerIn: parent
    visible: root.data === null
    text: root.error || "Loading\u2026"
    color: root.theme.subtext; font.pixelSize: 14; font.family: root.theme.font
  }

  Column {
    width: parent.width
    visible: root.data !== null
    spacing: 4
    Item {
      width: parent.width; height: 78
      Column {
        anchors.verticalCenter: parent.verticalCenter
        Text { text: root.data ? root.data.area : ""; color: root.theme.subtext; font.pixelSize: 13; font.weight: Font.DemiBold; font.family: root.theme.font }
        Text { text: root.data ? root.data.temp + "\u00B0" : ""; color: root.theme.text; font.pixelSize: 52; font.weight: Font.Light; font.family: root.theme.font }
      }
      Text {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: root.gl[0]; color: root.gl[1]; font.pixelSize: 54
      }
    }
    Text { text: root.data ? root.data.desc : ""; color: root.theme.text; font.pixelSize: 15; font.weight: Font.Medium; font.family: root.theme.font }
    Text {
      text: root.data ? "Feels " + root.data.feels + "\u00B0  \u00B7  " + root.data.hum + "%  \u00B7  " + root.data.wind : ""
      color: root.theme.subtext; font.pixelSize: 12; font.family: root.theme.font
    }
    Item { width: 1; height: 6 }
    Rectangle { width: parent.width; height: 1; color: root.theme.border }
    Item { width: 1; height: 4 }
    Row {
      width: parent.width
      Repeater {
        model: root.data ? root.data.days : []
        Item {
          required property var modelData
          width: parent.width / 3; height: 38
          Column {
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd")
              color: root.theme.accent; font.pixelSize: 12; font.weight: Font.DemiBold; font.family: root.theme.font
            }
            Row {
              spacing: 6
              Text { text: modelData.hi + "\u00B0"; color: root.theme.text; font.pixelSize: 13; font.family: root.theme.font }
              Text { text: modelData.lo + "\u00B0"; color: root.theme.subtext; font.pixelSize: 13; font.family: root.theme.font }
            }
          }
        }
      }
    }
  }
}
