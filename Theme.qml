pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "toml.js" as Toml

Singleton {
  id: root
  readonly property var fallback: ({
    bg: "#1e1e2e", surface: "#313244", border: "#45475a",
    text: "#cdd6f4", subtext: "#a6adc8", accent: "#f5c2e7", accent_fg: "#11111b",
    green: "#a6e3a1", yellow: "#f9e2af", red: "#f38ba8", blue: "#89b4fa",
    purple: "#cba6f7", peach: "#fab387", teal: "#94e2d5",
    shadow: "#80000000", radius: 22, font: "Inter"
  })
  property var custom: ({})
  readonly property var cur: Object.assign({}, fallback, custom)

  FileView {
    path: Config.ready ? Config.dir + "/themes/" + Config.themeName + ".toml" : ""
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.custom = Toml.parse(text())
    onLoadFailed: root.custom = ({})
  }
}
