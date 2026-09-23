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
    id: vpnWidgetRoot
    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property bool isVpnOn: false
    property string vpnStatus: "Off"
    property string vpnIcon: isVpnOn ? "󰒄" : "󰌆"
    property string vpnLabel: isVpnOn ? "WARP" : "Off"
    property color vpnAccent: (typeof ThemeBackend !== "undefined" && ThemeBackend.peach !== undefined) ? ThemeBackend.peach : "#f5a97f"
    property real targetX: 0
    property bool showLayout: moduleActive && (barWindow ? (barWindow.isStartupReady && barWindow.isDataReady) : true)
    property alias vpnPill: vpnPill

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
        running: vpnWidgetRoot.moduleActive
        repeat: true
        onTriggered: vpnWidgetRoot.updateVpnData()
    }

    Process {
        id: vpnStatusChecker
        command: ["bash", "-c", "if command -v warp-cli &>/dev/null; then warp-cli status 2>/dev/null; else echo 'disconnected'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text.toLowerCase().trim();
                if (text.indexOf("connecting") !== -1) {
                    vpnWidgetRoot.isVpnOn = false;
                    vpnWidgetRoot.vpnStatus = "Connecting";
                    vpnWidgetRoot.vpnLabel = "Connecting...";
                } else if (text.indexOf("connected") !== -1 && text.indexOf("disconnected") === -1) {
                    vpnWidgetRoot.isVpnOn = true;
                    vpnWidgetRoot.vpnStatus = "Connected";
                    vpnWidgetRoot.vpnLabel = "WARP";
                } else {
                    vpnWidgetRoot.isVpnOn = false;
                    vpnWidgetRoot.vpnStatus = "Off";
                    vpnWidgetRoot.vpnLabel = "Off";
                }
            }
        }
    }

    function updateVpnData() {
        if (!vpnStatusChecker.running) {
            vpnStatusChecker.running = true;
        }
    }

    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }
    height: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    y: barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - height) / 2 : 0
    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    clip: true

    property real targetWidth: (moduleActive && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    width: targetWidth

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    transform: Translate {
        x: vpnWidgetRoot.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        property int pillHeight: barWindow ? barWindow.s(vpnWidgetRoot.isCompact ? 28 : 30) : (vpnWidgetRoot.isCompact ? 28 : 30)

        ClickButton {
            id: vpnPill
            property bool initAnimTrigger: vpnWidgetRoot.showLayout
            property bool isActive: vpnWidgetRoot.isVpnOn

            height: sysLayout.pillHeight
            maxWidth: barWindow ? barWindow.s(vpnWidgetRoot.isCompact ? 156 : 160) : (vpnWidgetRoot.isCompact ? 156 : 160)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            horizontalPadding: barWindow ? barWindow.s(vpnWidgetRoot.isCompact ? 10 : 12) : (vpnWidgetRoot.isCompact ? 10 : 12)
            buttonIcon: vpnWidgetRoot.vpnIcon
            iconFontSize: barWindow ? barWindow.s(vpnWidgetRoot.isCompact ? 14 : 15) : (vpnWidgetRoot.isCompact ? 14 : 15)
            buttonText: vpnWidgetRoot.vpnLabel
            textFontSize: barWindow ? barWindow.s(vpnWidgetRoot.isCompact ? 11 : 12) : (vpnWidgetRoot.isCompact ? 11 : 12)
            accentColor: isActive ? (vpnWidgetRoot.isCompact ? Qt.lighter(vpnWidgetRoot.vpnAccent, 1.08) : vpnWidgetRoot.vpnAccent) : (vpnWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
            textColor: isActive ? ThemeBackend.base : (vpnWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

            property real targetWidth: implicitWidth
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: vpnPill.initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.atlanticDir + "/scripts/qs_manager.sh toggle network vpn"])
        }
    }
}
