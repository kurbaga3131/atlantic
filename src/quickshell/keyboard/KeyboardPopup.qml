import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: kbPopupRoot
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    property real introBase: 0.0
    property string searchQuery: ""
    property string activeLayoutId: "us"
    property string activeLayoutName: "English (US)"
    property string activeKeymapRaw: ""

    readonly property var allLayouts: [
        { id: "tr", code: "tr", variant: "", name: "Türkçe Q", sub: "Turkish QWERTY", badge: "TR", flag: "🇹🇷" },
        { id: "us", code: "us", variant: "", name: "English (US)", sub: "United States QWERTY", badge: "US", flag: "🇺🇸" },
        { id: "tr-f", code: "tr", variant: "f", name: "Türkçe F", sub: "Turkish F Layout", badge: "TR-F", flag: "🇹🇷" },
        { id: "gb", code: "gb", variant: "", name: "English (UK)", sub: "United Kingdom Layout", badge: "UK", flag: "🇬🇧" },
        { id: "de", code: "de", variant: "", name: "Deutsch", sub: "German QWERTZ Layout", badge: "DE", flag: "🇩🇪" },
        { id: "fr", code: "fr", variant: "", name: "Français", sub: "French AZERTY Layout", badge: "FR", flag: "🇫🇷" },
        { id: "es", code: "es", variant: "", name: "Español", sub: "Spanish Layout", badge: "ES", flag: "🇪🇸" },
        { id: "ru", code: "ru", variant: "", name: "Русский", sub: "Russian Cyrillic Layout", badge: "RU", flag: "🇷🇺" },
        { id: "it", code: "it", variant: "", name: "Italiano", sub: "Italian Layout", badge: "IT", flag: "🇮🇹" },
        { id: "az", code: "az", variant: "", name: "Azərbaycan", sub: "Azerbaijani Layout", badge: "AZ", flag: "🇦🇿" },
        { id: "ara", code: "ara", variant: "", name: "العربية", sub: "Arabic Layout", badge: "AR", flag: "🇸🇦" }
    ]

    readonly property var filteredLayouts: {
        let q = searchQuery.toLowerCase().trim();
        if (q.length === 0) return allLayouts;
        return allLayouts.filter(function(item) {
            return item.name.toLowerCase().includes(q) ||
                   item.sub.toLowerCase().includes(q) ||
                   item.code.toLowerCase().includes(q) ||
                   item.badge.toLowerCase().includes(q);
        });
    }

    function detectActiveLayout() {
        activeDetectorProc.running = false;
        activeDetectorProc.running = true;
    }

    function applyLayout(item) {
        if (!item) return;
        activeLayoutId = item.id;
        activeLayoutName = item.name;

        if (typeof Sounds !== "undefined") {
            Sounds.playSfx("guide/barconfig/in.wav");
        }

        let scriptPath = (Caching.atlanticDir || "") + "/scripts/system/switch_kb.sh";
        switchProc.command = ["bash", scriptPath, item.code, item.variant || ""];
        switchProc.running = true;

        closeTimer.restart();
    }

    function closePopup() {
        Quickshell.execDetached(["bash", (Caching.atlanticDir || "") + "/scripts/qs_manager.sh", "close"]);
    }

    Timer {
        id: closeTimer
        interval: 380
        repeat: false
        onTriggered: kbPopupRoot.closePopup()
    }

    Process {
        id: activeDetectorProc
        running: false
        command: [
            "bash",
            "-c",
            "LC_ALL=C hyprctl devices -j 2>/dev/null | jq -r '(.keyboards[] | select(.main == true) | .active_keymap) // .keyboards[0].active_keymap // empty' | head -n1"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                kbPopupRoot.activeKeymapRaw = txt;
                let lower = txt.toLowerCase();
                if (lower.includes("turkish") || lower.includes("türk")) {
                    if (lower.includes("(f)") || lower.includes(" f")) {
                        kbPopupRoot.activeLayoutId = "tr-f";
                        kbPopupRoot.activeLayoutName = "Türkçe F";
                    } else {
                        kbPopupRoot.activeLayoutId = "tr";
                        kbPopupRoot.activeLayoutName = "Türkçe Q";
                    }
                } else if (lower.includes("german") || lower.includes("deutsch")) {
                    kbPopupRoot.activeLayoutId = "de";
                    kbPopupRoot.activeLayoutName = "Deutsch";
                } else if (lower.includes("french") || lower.includes("français")) {
                    kbPopupRoot.activeLayoutId = "fr";
                    kbPopupRoot.activeLayoutName = "Français";
                } else if (lower.includes("spanish") || lower.includes("español")) {
                    kbPopupRoot.activeLayoutId = "es";
                    kbPopupRoot.activeLayoutName = "Español";
                } else if (lower.includes("russian") || lower.includes("русский")) {
                    kbPopupRoot.activeLayoutId = "ru";
                    kbPopupRoot.activeLayoutName = "Русский";
                } else if (lower.includes("italian") || lower.includes("italiano")) {
                    kbPopupRoot.activeLayoutId = "it";
                    kbPopupRoot.activeLayoutName = "Italiano";
                } else if (lower.includes("azerbaijan")) {
                    kbPopupRoot.activeLayoutId = "az";
                    kbPopupRoot.activeLayoutName = "Azərbaycan";
                } else if (lower.includes("arabic")) {
                    kbPopupRoot.activeLayoutId = "ara";
                    kbPopupRoot.activeLayoutName = "العربية";
                } else if (lower.includes("uk") || lower.includes("united kingdom")) {
                    kbPopupRoot.activeLayoutId = "gb";
                    kbPopupRoot.activeLayoutName = "English (UK)";
                } else {
                    kbPopupRoot.activeLayoutId = "us";
                    kbPopupRoot.activeLayoutName = "English (US)";
                }
            }
        }
    }

    Process {
        id: switchProc
        running: false
        command: []
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: kbPopupRoot.visible
    }

    onVisibleChanged: {
        if (visible) {
            introAnim.restart();
            detectActiveLayout();
            searchField.text = "";
            searchField.forceActiveFocus();
        } else {
            introAnim.stop();
            introBase = 0.0;
        }
    }

    Component.onCompleted: {
        if (visible) {
            introAnim.restart();
            detectActiveLayout();
        }
    }

    ParallelAnimation {
        id: introAnim
        NumberAnimation {
            target: kbPopupRoot
            property: "introBase"
            from: 0.0
            to: 1.0
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: mainContainer
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.base
        border.color: Qt.alpha(ThemeBackend.surface1, 0.45)
        border.width: 1
        clip: true

        opacity: kbPopupRoot.introBase
        scale: 0.94 + (0.06 * kbPopupRoot.introBase)

        // Ambient orbital glow
        Rectangle {
            width: parent.width * 0.75; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(kbPopupRoot.globalOrbitAngle * 2) * kbPopupRoot.s(100)
            y: (parent.height / 2 - height / 2) + Math.sin(kbPopupRoot.globalOrbitAngle * 2) * kbPopupRoot.s(70)
            opacity: 0.07
            color: ThemeBackend.mauve
        }
        Rectangle {
            width: parent.width * 0.85; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(kbPopupRoot.globalOrbitAngle * 1.5) * kbPopupRoot.s(-100)
            y: (parent.height / 2 - height / 2) + Math.cos(kbPopupRoot.globalOrbitAngle * 1.5) * kbPopupRoot.s(-70)
            opacity: 0.05
            color: ThemeBackend.blue
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: kbPopupRoot.s(16)
            spacing: kbPopupRoot.s(12)

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: kbPopupRoot.s(12)

                Rectangle {
                    implicitWidth: kbPopupRoot.s(40)
                    implicitHeight: kbPopupRoot.s(40)
                    radius: ThemeBackend.borderRadius
                    color: Qt.alpha(ThemeBackend.mauve, 0.16)
                    border.color: Qt.alpha(ThemeBackend.mauve, 0.4)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰌌"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: kbPopupRoot.s(20)
                        color: ThemeBackend.mauve
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: kbPopupRoot.s(2)

                    Text {
                        text: typeof I18n !== "undefined" ? I18n.t("widgets.keyboard", "Keyboard Layout") : "Keyboard Layout"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: kbPopupRoot.s(15)
                        font.bold: true
                        color: ThemeBackend.text
                    }

                    RowLayout {
                        spacing: kbPopupRoot.s(6)

                        Text {
                            text: "Active:"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: kbPopupRoot.s(11)
                            color: ThemeBackend.subtext0
                        }

                        Rectangle {
                            implicitHeight: kbPopupRoot.s(18)
                            implicitWidth: activeBadgeText.implicitWidth + kbPopupRoot.s(12)
                            radius: kbPopupRoot.s(9)
                            color: Qt.alpha(ThemeBackend.mauve, 0.2)
                            border.color: Qt.alpha(ThemeBackend.mauve, 0.5)
                            border.width: 1

                            Text {
                                id: activeBadgeText
                                anchors.centerIn: parent
                                text: kbPopupRoot.activeLayoutName
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: kbPopupRoot.s(10)
                                font.bold: true
                                color: ThemeBackend.mauve
                            }
                        }
                    }
                }

                IconButton {
                    size: kbPopupRoot.s(32)
                    buttonIcon: "󰅖"
                    iconFontSize: kbPopupRoot.s(14)
                    accentColor: Qt.alpha(ThemeBackend.surface0, 0.6)
                    textColor: ThemeBackend.subtext0
                    cornerRadius: ThemeBackend.borderRadius
                    onClicked: kbPopupRoot.closePopup()
                }
            }

            // Search Bar
            Input {
                id: searchField
                Layout.fillWidth: true
                implicitHeight: kbPopupRoot.s(36)
                cornerRadius: ThemeBackend.borderRadius
                baseColor: Qt.alpha(ThemeBackend.surface0, 0.55)
                borderColor: Qt.alpha(ThemeBackend.surface1, 0.5)
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                accentColor: ThemeBackend.mauve
                placeholderText: "Search keyboard layout..."
                leadingIcon: "󰍉"
                showClearButton: true
                fontPixelSize: kbPopupRoot.s(12)
                onTextEdited: {
                    kbPopupRoot.searchQuery = text;
                }
            }

            // Layout List
            Flickable {
                id: listFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: listCol.implicitHeight + kbPopupRoot.s(8)
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    active: listFlickable.moving || listFlickable.movingVertically
                    width: kbPopupRoot.s(4)
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: kbPopupRoot.s(4)
                        radius: kbPopupRoot.s(2)
                        color: ThemeBackend.surface2
                    }
                }

                ColumnLayout {
                    id: listCol
                    width: listFlickable.width - kbPopupRoot.s(4)
                    spacing: kbPopupRoot.s(6)

                    Repeater {
                        model: kbPopupRoot.filteredLayouts

                        delegate: Rectangle {
                            id: itemCard
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: kbPopupRoot.s(52)
                            radius: ThemeBackend.borderRadius

                            readonly property bool isActive: kbPopupRoot.activeLayoutId === modelData.id
                            readonly property bool isHovered: itemMouseArea.containsMouse

                            color: isActive
                                ? Qt.alpha(ThemeBackend.mauve, 0.16)
                                : (isHovered ? Qt.alpha(ThemeBackend.surface1, 0.55) : Qt.alpha(ThemeBackend.surface0, 0.45))

                            border.color: isActive
                                ? ThemeBackend.mauve
                                : (isHovered ? Qt.alpha(ThemeBackend.mauve, 0.4) : Qt.alpha(ThemeBackend.surface1, 0.35))
                            border.width: isActive ? 1.5 : 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: kbPopupRoot.s(12)
                                anchors.rightMargin: kbPopupRoot.s(12)
                                spacing: kbPopupRoot.s(12)

                                // Flag / Badge Circle
                                Rectangle {
                                    implicitWidth: kbPopupRoot.s(36)
                                    implicitHeight: kbPopupRoot.s(36)
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: ThemeBackend.borderRadius
                                    color: isActive ? Qt.alpha(ThemeBackend.mauve, 0.25) : ThemeBackend.surface0

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.badge
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: kbPopupRoot.s(11)
                                        font.bold: true
                                        color: isActive ? ThemeBackend.mauve : ThemeBackend.text
                                    }
                                }

                                // Layout Name & Description
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: kbPopupRoot.s(1)

                                    RowLayout {
                                        spacing: kbPopupRoot.s(6)

                                        Text {
                                            text: modelData.name
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: kbPopupRoot.s(13)
                                            font.bold: true
                                            color: ThemeBackend.text
                                        }

                                        Text {
                                            text: modelData.flag
                                            font.pixelSize: kbPopupRoot.s(12)
                                        }
                                    }

                                    Text {
                                        text: modelData.sub
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: kbPopupRoot.s(10)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                // Active indicator checkmark badge
                                Rectangle {
                                    implicitWidth: kbPopupRoot.s(26)
                                    implicitHeight: kbPopupRoot.s(26)
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: kbPopupRoot.s(13)
                                    visible: isActive
                                    color: ThemeBackend.mauve

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰄬"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: kbPopupRoot.s(14)
                                        color: ThemeBackend.crust
                                        font.bold: true
                                    }
                                }

                                // Select arrow when hovered and not active
                                Text {
                                    visible: !isActive && isHovered
                                    text: "󰄾"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: kbPopupRoot.s(14)
                                    color: ThemeBackend.subtext0
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: itemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: kbPopupRoot.applyLayout(modelData)
                            }
                        }
                    }

                    // Empty search result placeholder
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: kbPopupRoot.s(120)
                        visible: kbPopupRoot.filteredLayouts.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: kbPopupRoot.s(6)

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰌌"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: kbPopupRoot.s(28)
                                color: ThemeBackend.subtext0
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "No matching keyboard layouts"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: kbPopupRoot.s(12)
                                color: ThemeBackend.subtext0
                            }
                        }
                    }
                }
            }
        }
    }
}
