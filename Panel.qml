import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Bar button + panel for workspace-audio. The daemon (bin/workspace-audio)
// ships with the plugin and is started from here; it publishes its state to
// $XDG_RUNTIME_DIR/workspace-audio.json, which this widget follows.
Panel {
  id: root
  moduleName: "rustyhammer.workspace-audio"
  ipcTarget: "rustyhammer.workspace-audio"

  readonly property string script: String(Qt.resolvedUrl("bin/workspace-audio")).replace(/^file:\/\//, "")
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  property bool daemonUp: false
  property bool enabled: true
  property var globalApps: []
  property var streams: []

  readonly property int mutedCount: {
    var n = 0
    for (var i = 0; i < streams.length; i++) if (streams[i].auto) n++
    return n
  }
  readonly property string iconGlyph: enabled ? "󰓃" : "󰴸"
  readonly property color dim: Qt.darker(root.barForeground, 1.4)

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // Status comes from a file another process writes: validate and bound it.
  function readStatus(raw) {
    var d = null
    try { d = JSON.parse(raw) } catch (e) { d = null }
    if (!d || typeof d !== "object") { daemonUp = false; return }
    daemonUp = true
    enabled = d.enabled !== false
    globalApps = Array.isArray(d.global)
      ? d.global.slice(0, 50).map(function(a) { return String(a).slice(0, 80) }) : []
    streams = Array.isArray(d.streams) ? d.streams.slice(0, 30).map(function(s) {
      return {
        name: String(s && s.name || "?").slice(0, 80),
        cls: String(s && s["class"] || "").slice(0, 80),
        ws: s && typeof s.ws === "number" ? s.ws : null,
        global: !!(s && s.global),
        muted: !!(s && s.muted),
        auto: !!(s && s.auto)
      }
    }) : []
  }

  function wa(args) { Quickshell.execDetached(["python3", root.script].concat(args)) }
  function startDaemon() { wa(["daemon"]) }   // no-op when it already runs
  function setEnabled(on) { root.enabled = on; wa([on ? "on" : "off"]) }
  function toggleGlobal(cls) { if (cls) wa(["global", cls]) }

  function streamDetail(s) {
    var where = s.ws !== null ? strings.t("workspace").arg(Commons.I18n.formatNumber(s.ws)) : strings.t("noWindow")
    if (s.global) return strings.t("stateGlobal").arg(where)
    if (s.auto) return strings.t("stateAuto").arg(where)
    if (s.muted) return strings.t("stateManual").arg(where)
    return strings.t("stateAudible").arg(where)
  }

  Component.onCompleted: startDaemon()

  // Bring the daemon back if it ever stops.
  Timer {
    interval: 30000
    repeat: true
    running: !root.daemonUp
    onTriggered: root.startDaemon()
  }

  FileView {
    // No shared fallback such as /tmp: the daemon refuses to run without a
    // private runtime dir, so there is nothing to follow then.
    path: Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/workspace-audio.json" : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readStatus(text())
    onLoadFailed: root.readStatus("")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.iconGlyph
    foreground: !root.enabled || !root.daemonUp ? root.dim
      : (root.mutedCount > 0 ? Commons.Color.accent : root.barForeground)
    slotSize: Style.bar.iconSlot
    tooltipText: !root.daemonUp ? strings.t("tooltipDown")
      : root.enabled ? strings.t("tooltipOn") : strings.t("tooltipOff")
    onPressed: function(b) {
      if (b === Qt.RightButton) root.setEnabled(!root.enabled)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onCloseRequested: root.close()
      onActivateRequested: root.setEnabled(!root.enabled)
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        PanelHero {
          foreground: root.barForeground
          fontFamily: root.fontFamily
          title: strings.t("title")
          meta: (!root.daemonUp ? strings.t("metaDown")
            : root.enabled ? strings.t("metaOn") : strings.t("metaOff")).toUpperCase()
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: root.iconGlyph
              color: root.barForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              checked: root.enabled
              foreground: root.barForeground
              onToggled: root.setEnabled(!root.enabled)
            }
          }
        }

        PanelSeparator { foreground: root.barForeground }

        PanelSectionHeader {
          text: strings.t("playing")
          foreground: root.barForeground
          fontFamily: root.fontFamily
        }

        InfoText {
          visible: root.streams.length === 0
          text: strings.t("nothingPlaying")
          opacity: 0.6
        }

        Repeater {
          model: root.streams
          Item {
            required property var modelData
            width: column.width
            implicitHeight: Math.max(labels.implicitHeight, everywhere.implicitHeight)

            Column {
              id: labels
              anchors.left: parent.left
              anchors.right: everywhere.visible ? everywhere.left : parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              InfoText {
                width: parent.width
                text: modelData.name
                font.bold: true
                opacity: modelData.auto ? 0.6 : 1
              }
              InfoText {
                width: parent.width
                text: root.streamDetail(modelData)
                font.pixelSize: Style.font.caption
                opacity: 0.6
              }
            }

            // Only static, translated text goes into the shared Button.
            Button {
              id: everywhere
              visible: modelData.cls !== ""
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: strings.t("everywhere")
              tooltipText: modelData.global ? strings.t("everywhereOff") : strings.t("everywhereOn")
              iconText: modelData.global ? "󰕾" : "󰝟"
              fontSize: Style.font.bodySmall
              foreground: root.barForeground
              fontFamily: root.fontFamily
              bordered: true
              active: modelData.global
              onClicked: root.toggleGlobal(modelData.cls)
            }
          }
        }

        PanelSeparator { foreground: root.barForeground }

        PanelSectionHeader {
          text: strings.t("everywhereHeader")
          foreground: root.barForeground
          fontFamily: root.fontFamily
        }

        InfoText {
          visible: root.globalApps.length === 0
          text: strings.t("noApps")
          opacity: 0.6
        }

        Repeater {
          model: root.globalApps
          Item {
            required property var modelData
            width: column.width
            implicitHeight: Math.max(appName.implicitHeight, removeBtn.implicitHeight)

            InfoText {
              id: appName
              anchors.left: parent.left
              anchors.right: removeBtn.left
              anchors.verticalCenter: parent.verticalCenter
              text: modelData
            }
            Button {
              id: removeBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰅖"
              tooltipText: strings.t("remove")
              foreground: root.barForeground
              fontFamily: root.fontFamily
              onClicked: root.toggleGlobal(modelData)
            }
          }
        }

        InfoText {
          width: column.width
          wrapMode: Text.WordWrap
          font.pixelSize: Style.font.caption
          opacity: 0.5
          text: strings.t("hint")
        }
      }
    }
  }

  component InfoText: Text {
    textFormat: Text.PlainText
    color: root.barForeground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }
}
