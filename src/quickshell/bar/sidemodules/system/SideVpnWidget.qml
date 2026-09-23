import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"

Rectangle {
    id: sideVpnRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property real targetY: 0
    property bool showLayout: moduleActive && (!barWindow || (barWindow.isStartupReady && barWindow.isDataReady))
    property alias vpnPill: vpnBtn
    property bool isVpnOn: false
    property string vpnStatus: "Off"
    property string vpnIcon: isVpnOn ? "󰒄" : "󰌆"
    property color vpnAccent: (typeof ThemeBackend !== "undefined" && ThemeBackend.peach !== undefined) ? ThemeBackend.peach : "#f5a97f"

    property real targetWidth: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    property real targetHeight: (moduleActive && vpnBtn.height > 0) ? (vpnBtn.height + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0

    width: targetWidth
    height: targetHeight

    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    x: barWindow ? ((barWindow.baseOffsetX !== undefined ? barWindow.baseOffsetX : 0) + (barWindow.barHeight - width) / 2) : 0
    y: targetY
    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    clip: true

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Component.onCompleted: {
        updateVpnData();
    }

    onModuleActiveChanged: {
        if (moduleActive) {
            updateVpnData();
            vpnPollerTimer.restart();
        } else {
            vpnPollerTimer.stop();
        }
    }

    Timer {
        id: vpnPollerTimer
        interval: 3500
        running: sideVpnRoot.moduleActive
        repeat: true
        onTriggered: sideVpnRoot.updateVpnData()
    }

    Process {
        id: vpnStatusChecker
        command: ["bash", "-c", "if command -v warp-cli &>/dev/null; then warp-cli status 2>/dev/null; else echo 'disconnected'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text.toLowerCase().trim();
                if (text.indexOf("connected") !== -1 && text.indexOf("disconnected") === -1) {
                    sideVpnRoot.isVpnOn = true;
                    sideVpnRoot.vpnStatus = "Connected";
                } else {
                    sideVpnRoot.isVpnOn = false;
                    sideVpnRoot.vpnStatus = "Off";
                }
            }
        }
    }

    function updateVpnData() {
        if (!vpnStatusChecker.running) {
            vpnStatusChecker.running = true;
        }
    }

    IconButton {
        id: vpnBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(sideVpnRoot.isCompact ? 28 : 30) : (sideVpnRoot.isCompact ? 28 : 30)
        height: barWindow ? barWindow.s(sideVpnRoot.isCompact ? 28 : 30) : (sideVpnRoot.isCompact ? 28 : 30)
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
        buttonIcon: sideVpnRoot.vpnIcon
        iconFontSize: barWindow ? barWindow.s(sideVpnRoot.isCompact ? 14 : 15) : (sideVpnRoot.isCompact ? 14 : 15)
        accentColor: sideVpnRoot.isVpnOn ? (sideVpnRoot.isCompact ? Qt.lighter(sideVpnRoot.vpnAccent, 1.08) : sideVpnRoot.vpnAccent) : (sideVpnRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
        textColor: sideVpnRoot.isVpnOn ? ThemeBackend.base : (sideVpnRoot.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.atlanticDir + "/scripts/qs_manager.sh toggle network vpn"])
    }
}
