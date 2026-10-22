import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
  id: root

  property var theme: ({})
  property var options: ({})

  readonly property var player: {
    var players = Mpris.players.values

    for (var i = 0; i < players.length; i++) {
      if (players[i].isPlaying)
        return players[i]
    }

    return players.length > 0 ? players[0] : null
  }

  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string album: player ? (player.trackAlbum || "") : ""

  readonly property int dur:
  player && player.lengthSupported
    ? Math.round(player.length)
    : 0

  readonly property string key: title + "|" + artist

  readonly property real pos:
  player && player.positionSupported ? player.position : 0

  readonly property real offset: Number(options.lyrics_offset) || 0

  readonly property bool showTitle: options.show_title !== false

  readonly property string align:
  options.text_align === "left" || options.text_align === "right"
    ? options.text_align
    : "center"

  readonly property color textColor:
  Qt.color(theme.text || "#cdd6f4")

  readonly property color subtextColor:
  Qt.color(theme.subtext || "#6c7086")

  readonly property color accentColor:
  Qt.color(theme.accent || "#f5c2e7")

  property var lines: []
  property string status: "Nothing playing"
  property string reqKey: ""

  readonly property real rowH: 36
  readonly property int visibleRows: 5

  readonly property int idx: {
    var p = pos + offset
    var n = lines.length
    var lo = 0
    var hi = n - 1
    var result = -1

    while (lo <= hi) {
      var mid = (lo + hi) >> 1

      if (lines[mid].t <= p) {
        result = mid
        lo = mid + 1
      } else {
        hi = mid - 1
      }
    }

    return result
  }

  readonly property real scrollPos: {
    var i = idx
    var n = lines.length

    if (i < 0)
      return 0

    var t = pos + offset
    var t0 = lines[i].t
    var t1 = i + 1 < n ? lines[i + 1].t : t0 + 4
    var gap = t1 - t0
    var window = Math.min(gap * 0.5, 1.2)

    if (window <= 0 || t <= t1 - window)
      return i

    var f = Math.max(
      0,
      Math.min(1, (t - (t1 - window)) / window)
    )

    f = f * f * (3 - 2 * f)

    return i + f
  }

  implicitWidth: 420
  implicitHeight: (showTitle ? 46 : 0) + visibleRows * rowH

  function parseLrc(s) {
    var out = []
    var inputLines = s.split(/\r?\n/)

    for (var i = 0; i < inputLines.length; i++) {
      var rest = inputLines[i]
      var tags = []
      var match

      while ((match = rest.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*/))) {
        tags.push(Number(match[1]) * 60 + Number(match[2]))
        rest = rest.slice(match[0].length)
      }

      var txt = rest.trim()

      for (var k = 0; k < tags.length; k++) {
        out.push({
          t: tags[k],
          s: txt === "" ? "\u266A" : txt
        })
      }
    }

    out.sort(function(a, b) {
      return a.t - b.t
    })

    return out
  }

  function apply(rec) {
    if (rec && rec.syncedLyrics) {
      var parsed = parseLrc(rec.syncedLyrics)

      if (parsed.length > 0) {
        lines = parsed
        status = ""
        return true
      }
    }

    return false
  }

  function args(url, withExtra) {
    var a = [
      "curl",
      "-sf",
      "-m", "10",
      "-A", "rosewidgets",
      "-G", url,
      "--data-urlencode", "track_name=" + title,
      "--data-urlencode", "artist_name=" + artist
    ]

    if (withExtra && album !== "")
      a.push("--data-urlencode", "album_name=" + album)

    if (withExtra && dur > 0)
      a.push("--data-urlencode", "duration=" + dur)

    return a
  }

  function load() {
    lines = []

    if (title === "") {
      status = "Nothing playing"
      return
    }

    status = "Searching lyrics..."
    debounce.restart()
  }

  onKeyChanged: load()
  Component.onCompleted: load()

  FrameAnimation {
    running: root.player !== null
      && root.player.isPlaying
      && root.lines.length > 0

    onTriggered: {
      if (root.player && root.player.positionSupported)
        root.player.positionChanged()
    }
  }

  Timer {
    id: debounce

    interval: 350

    onTriggered: {
      if (getProc.running || searchProc.running) {
        restart()
        return
      }

      if (root.title === "")
        return

      root.reqKey = root.key

      getProc.command = root.args(
        "https://lrclib.net/api/get",
        true
      )

      getProc.running = true
    }
  }

  Process {
    id: getProc

    stdout: StdioCollector {
      onStreamFinished: {
        if (root.reqKey !== root.key)
          return

        var ok = false

        try {
          var result = JSON.parse(text)

          if (result.instrumental) {
            root.status = "Instrumental"
            return
          }

          ok = root.apply(result)
        } catch (e) {
        }

        if (!ok) {
          searchProc.command = root.args(
            "https://lrclib.net/api/search",
            false
          )

          searchProc.running = true
        }
      }
    }
  }

  Process {
    id: searchProc

    stdout: StdioCollector {
      onStreamFinished: {
        if (root.reqKey !== root.key)
          return

        var ok = false

        try {
          var results = JSON.parse(text)
          var best = null
          var bestDifference = 1e9

          for (var i = 0; i < results.length; i++) {
            var item = results[i]

            if (!item.syncedLyrics)
              continue

            var difference =
            root.dur > 0 && item.duration
              ? Math.abs(item.duration - root.dur)
              : 0

            if (difference < bestDifference) {
              bestDifference = difference
              best = item
            }
          }

          ok = root.apply(best)
        } catch (e) {
        }

        if (!ok)
          root.status = "No synced lyrics found"
      }
    }
  }

  Column {
    visible: root.showTitle

    width: parent.width
    height: 46
    spacing: 1

    Text {
      width: parent.width

      text: root.title || "Lyrics"
      color: root.textColor

      elide: Text.ElideRight

      font.pixelSize: 15
      font.weight: Font.DemiBold
      font.family: root.theme.font || "sans-serif"
    }

    Text {
      width: parent.width

      text: root.artist
      color: root.subtextColor

      elide: Text.ElideRight

      font.pixelSize: 12
      font.family: root.theme.font || "sans-serif"
    }
  }

  Item {
    id: body

    y: root.showTitle ? 46 : 0

    width: parent.width
    height: root.visibleRows * root.rowH

    Text {
      anchors.centerIn: parent

      visible: root.lines.length === 0

      text: root.status
      color: root.subtextColor

      font.pixelSize: 14
      font.family: root.theme.font || "sans-serif"
    }

    Item {
      id: list

      visible: root.lines.length > 0

      anchors.fill: parent
      clip: true

      Item {
        id: column

        width: parent.width
        height: root.lines.length * root.rowH

        y: (list.height - root.rowH) / 2
        - root.scrollPos * root.rowH

        Repeater {
          model: root.lines

          Item {
            id: lyricRow

            required property var modelData
            required property int index

            y: index * root.rowH

            width: column.width
            height: root.rowH

            Text {
              id: lineTxt

              anchors {
                fill: parent

                leftMargin:
                root.align === "left" ? 14 : 4

                rightMargin:
                root.align === "right" ? 14 : 4
              }

              horizontalAlignment:
              root.align === "left"
                ? Text.AlignLeft
                : root.align === "right"
                ? Text.AlignRight
                : Text.AlignHCenter

              verticalAlignment: Text.AlignVCenter

              text: lyricRow.modelData.s
              elide: Text.ElideRight

              font.family:
              root.theme.font || "sans-serif"

              font.pixelSize: 16

              font.weight:
              lyricRow.index === root.idx
                ? Font.DemiBold
                : Font.Normal

              color:
              lyricRow.index === root.idx
                ? root.accentColor
                : root.subtextColor

              opacity:
              lyricRow.index === root.idx
                ? 1.0
                : 0.38

              Behavior on opacity {
                NumberAnimation {
                  duration: 180
                  easing.type: Easing.OutCubic
                }
              }

              Behavior on color {
                ColorAnimation {
                  duration: 180
                  easing.type: Easing.OutCubic
                }
              }
            }

            MouseArea {
              anchors.fill: parent

              onClicked: {
                if (root.player && root.player.canSeek) {
                  root.player.position = Math.max(
                    0,
                    lyricRow.modelData.t - root.offset
                  )
                }
              }
            }
          }
        }
      }
    }
  }
}
