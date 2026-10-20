pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "toml.js" as Toml

Singleton {
  id: root
  readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/rosewidgets"
  property bool ready: false
  property string raw: ""
  property var general: ({})
  property var widgets: ({})
  property var ids: []
  property var sizes: ({})
  readonly property int cardPad: 18
  property var naturals: ({})
  property var drag: ({})
  property bool editMode: false
  property var customs: []
  property var themes: []
  readonly property string themeName: general.theme || "catppuccin-mocha-pink"

  readonly property bool autoTile: general.autotile === true
  readonly property string tileCorner: general.tile_corner || "bottom-right"
  readonly property real tileGap: general.tile_gap !== undefined ? Number(general.tile_gap) : 20
  readonly property real tileMargin: general.tile_margin !== undefined ? Number(general.tile_margin) : 24
  readonly property var tiles: autoTile ? computeTiles() : ({})
  readonly property var catalog: [
    { type: "clock", name: "Clock", desc: "Time and date" },
    { type: "music", name: "Music", desc: "Now playing (MPRIS)" },
    { type: "calendar", name: "Calendar", desc: "Month view" },
    { type: "stats", name: "System stats", desc: "CPU, RAM, disk, temperature" },
    { type: "weather", name: "Weather", desc: "Current + 3-day forecast" },
    { type: "network", name: "Wi-Fi + Bluetooth", desc: "Status and quick toggles" }
  ]
  readonly property var allWidgets: catalog.concat(customs.map(function (s) { return { type: s, name: s, desc: "Custom QML widget" }; }))

  readonly property string defaultConfig: `# RoseWidgets config. Positions/sizes are rewritten automatically in edit mode.
# Edit this file and changes apply live.

[general]
theme = "catppuccin-mocha-pink"   # any file in ~/.config/rosewidgets/themes/<name>.toml
monitor = ""            # output name, empty = first monitor
autotile = false        # true = stack-tile widgets in a screen corner
# tile_corner = "bottom-right"   # bottom-right | bottom-left | top-right | top-left
# tile_gap = 20
# tile_margin = 24

[widgets.clock1]
type = "clock"
x = 60
y = 60

[widgets.music1]
type = "music"
x = 60
y = 250
`

  Process {
    running: true
    command: ["mkdir", "-p", root.dir + "/widgets", root.dir + "/themes"]
    onExited: root.ready = true
  }

  FileView {
    id: file
    path: root.ready ? root.dir + "/config.toml" : ""
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.apply(text())
    onLoadFailed: err => {
      if (err === FileViewError.FileNotFound) { root.apply(root.defaultConfig); file.setText(root.defaultConfig); }
    }
  }

  Process {
    id: scanProc
    command: ["sh", "-c", 'cd "$1" || exit; for f in widgets/*.qml; do [ -e "$f" ] && echo "w:$(basename "$f" .qml)"; done; for f in themes/*.toml; do [ -e "$f" ] && echo "t:$(basename "$f" .toml)"; done', "sh", root.dir]
    stdout: StdioCollector {
      onStreamFinished: {
        var L = text.split("\n");
        root.customs = L.filter(s => s.indexOf("w:") === 0).map(s => s.slice(2));
        root.themes = L.filter(s => s.indexOf("t:") === 0).map(s => s.slice(2));
      }
    }
  }
  function scan() { scanProc.running = true; }

  function apply(text) {
    if (text === raw) return;
    var d;
    try { d = Toml.parse(text); } catch (e) { console.warn("rosewidgets: bad config", e); return; }
    raw = text;
    general = d.general || {};
    widgets = d.widgets || {};
    var n = Object.keys(widgets);
    if (JSON.stringify(n) !== JSON.stringify(ids)) ids = n;
  }
  function commit(t) { apply(t); file.setText(t); }

  function pos(id) {
    if (drag.id === id) return { x: drag.x, y: drag.y };
    if (autoTile && tiles[id]) return { x: tiles[id].x, y: tiles[id].y };
    var c = widgets[id] || {};
    return { x: c.x !== undefined ? c.x : 60, y: c.y !== undefined ? c.y : 60 };
  }
  function size(id) {
    if (drag.id === id && drag.resized) return { w: drag.w, h: drag.h };
    if (autoTile && tiles[id]) return { w: tiles[id].w, h: tiles[id].h };
    var c = widgets[id] || {};
    return { w: c.width || 0, h: c.height || 0 };
  }
  function rect(id) {
    var p = pos(id), e = size(id), s = sizes[id] || { w: 0, h: 0 };
    return { x: p.x, y: p.y, w: e.w || s.w, h: e.h || s.h };
  }

  function setPos(id, x, y) {
    var ws = widgets, c = ws[id];
    if (!c) return;
    c.x = Math.round(x); c.y = Math.round(y);
    widgets = ws; widgetsChanged();
    raw = Toml.setKeys(raw, "widgets." + id, { x: c.x, y: c.y });
    file.setText(raw);
  }
  function setRect(id, x, y, w, h) {
    var ws = widgets, c = ws[id];
    if (!c) return;
    c.x = Math.round(x); c.y = Math.round(y); c.width = Math.round(w); c.height = Math.round(h);
    widgets = ws; widgetsChanged();
    raw = Toml.setKeys(raw, "widgets." + id, { x: c.x, y: c.y, width: c.width, height: c.height });
    file.setText(raw);
  }

  function addWidget(type) {
    var n = 1;
    while (widgets[type + n]) n++;
    var id = type + n, scr = monitor();
    var x = Math.round((scr ? scr.width : 1200) / 2 - 150 + (n - 1) * 24);
    var y = Math.round((scr ? scr.height : 800) / 2 - 100 + (n - 1) * 24);
    commit(raw.replace(/\s*$/, "") + "\n\n[widgets." + id + "]\ntype = \"" + type + "\"\nx = " + x + "\ny = " + y + "\n");
  }
  function removeWidget(id) { commit(Toml.removeSection(raw, "widgets." + id)); }
  function setGeneral(kv) {
    var t = raw;
    if (!/^\[general\]/m.test(t)) t = t.replace(/\s*$/, "") + "\n\n[general]\n";
    commit(Toml.setKeys(t, "general", kv));
  }
  function setTheme(name) { setGeneral({ theme: name }); }
  function setAutoTile(on) { setGeneral({ autotile: on }); }

  function tileOrder() {
    var saved = Array.isArray(general.tile_order) ? general.tile_order : [];
    var out = saved.filter(function (i, k) { return ids.indexOf(i) >= 0 && saved.indexOf(i) === k; });
    ids.forEach(function (i) { if (out.indexOf(i) < 0) out.push(i); });
    return out;
  }
  function computeTiles() {
    var scr = monitor();
    if (!scr) return ({});
    var W = scr.width, H = scr.height, g = tileGap, m = tileMargin, P = cardPad, maxScale = 1.25;
    var right = tileCorner.indexOf("right") >= 0, bottom = tileCorner.indexOf("bottom") >= 0;
    var avail = H - 2 * m;
    function itemH(it, mw) { return Math.round((it.fluid ? it.nh : it.nh * mw / it.nw) + 2 * P); }
    function fits(items, mw) {
      var tot = 0;
      for (var i = 0; i < items.length; i++) {
        if (!items[i].fluid && mw / items[i].nw > maxScale) return false;
        tot += itemH(items[i], mw) + (i > 0 ? g : 0);
      }
      return tot <= avail;
    }
    var cols = [], cur = null;
    tileOrder().forEach(function (id) {
      var n = naturals[id] || { w: 120, h: 60, fluid: false };
      var it = { id: id, nw: n.w, nh: n.h, fluid: n.fluid === true };
      if (cur) {
        var mw = Math.max(cur.mw, it.nw), trial = cur.items.concat([it]);
        if (fits(trial, mw)) { cur.items = trial; cur.mw = mw; return; }
      }
      cur = { items: [it], mw: it.nw };
      cols.push(cur);
    });
    var out = {}, off = 0;
    cols.forEach(function (col) {
      var cardW = Math.round(col.mw + 2 * P);
      var cx = Math.round(right ? W - m - off - cardW : m + off);
      var y = bottom ? H - m : m;
      col.items.forEach(function (it) {
        var h = itemH(it, col.mw);
        if (bottom) { y -= h; out[it.id] = { x: cx, y: Math.round(y), w: cardW, h: h }; y -= g; }
        else { out[it.id] = { x: cx, y: Math.round(y), w: cardW, h: h }; y += h + g; }
      });
      off += cardW + g;
    });
    return out;
  }
  function nearestTile(mx, my) {
    var best = "", bd = 1e18;
    for (var id in tiles) {
      var t = tiles[id], dx = mx - (t.x + t.w / 2), dy = my - (t.y + t.h / 2), d = dx * dx + dy * dy;
      if (d < bd) { bd = d; best = id; }
    }
    return best;
  }
  function moveTile(id, targetId) {
    var o = tileOrder(), i = o.indexOf(id), j = o.indexOf(targetId);
    if (i < 0 || j < 0 || i === j) return;
    o.splice(i, 1); o.splice(j, 0, id);
    setGeneral({ tile_order: o });
  }

  function reportNatural(id, w, h, fluid) {
    var n = naturals; n[id] = { w: w, h: h, fluid: fluid }; naturals = n; naturalsChanged();
  }
  function reportSize(id, w, h) {
    var s = sizes; s[id] = { w: w, h: h }; sizes = s; sizesChanged();
  }
  function monitor() {
    var m = general.monitor;
    var f = Quickshell.screens.find(function (s) { return s.name === m; });
    return f || Quickshell.screens[0];
  }
}
