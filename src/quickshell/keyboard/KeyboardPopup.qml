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
    property string activeLayoutId: "tr"
    property string activeLayoutName: "Turkish (Q)"
    property string activeKeymapRaw: ""

    readonly property var allLayouts: [
        { id: "tr", code: "tr", variant: "", name: "Turkish (Q)", sub: "Turkish QWERTY", badge: "TR", flag: "🇹🇷" },
        { id: "us", code: "us", variant: "", name: "English (US)", sub: "United States QWERTY", badge: "US", flag: "🇺🇸" },
        { id: "tr-f", code: "tr", variant: "f", name: "Turkish (F)", sub: "Turkish F Layout", badge: "TR-F", flag: "🇹🇷" },
        { id: "gb", code: "gb", variant: "", name: "English (UK)", sub: "United Kingdom Layout", badge: "UK", flag: "🇬🇧" },
        { id: "de", code: "de", variant: "", name: "German", sub: "German QWERTZ Layout", badge: "DE", flag: "🇩🇪" },
        { id: "fr", code: "fr", variant: "", name: "French", sub: "French AZERTY Layout", badge: "FR", flag: "🇫🇷" },
        { id: "es", code: "es", variant: "", name: "Spanish", sub: "Spanish Layout", badge: "ES", flag: "🇪🇸" },
        { id: "ru", code: "ru", variant: "", name: "Russian", sub: "Russian Cyrillic Layout", badge: "RU", flag: "🇷🇺" },
        { id: "it", code: "it", variant: "", name: "Italian", sub: "Italian Layout", badge: "IT", flag: "🇮🇹" }
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

        let code = item.code;
        let variant = item.variant || "";
        let id = item.id;
        let dir = (typeof Caching !== "undefined" && Caching.atlanticDir) ? Caching.atlanticDir : "";

        let cmd = `
mkdir -p "$HOME/.cache/atlantic" 2>/dev/null
echo "${id}" > "$HOME/.cache/atlantic/current_layout.txt" 2>/dev/null || true

for s in "${dir}/scripts/system/switch_kb.sh" "$HOME/.local/share/atlantic/src/scripts/system/switch_kb.sh" "/usr/local/share/atlantic/src/scripts/system/switch_kb.sh"; do
    if [ -f "$s" ]; then
        bash "$s" "${code}" "${variant}"
        exit 0
    fi
done

if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || pgrep -x Hyprland &>/dev/null; then
    hyprctl keyword input:kb_layout "${code}" >/dev/null 2>&1 || true
    if [ -n "${variant}" ]; then
        hyprctl keyword input:kb_variant "${variant}" >/dev/null 2>&1 || true
    else
        hyprctl keyword input:kb_variant "" >/dev/null 2>&1 || true
    fi
    hyprctl devices -j 2>/dev/null | jq -r '.keyboards[].name // empty' 2>/dev/null | while read -r kb; do
        [ -n "$kb" ] || continue
        hyprctl keyword "device:$kb:kb_layout" "${code}" >/dev/null 2>&1 || true
        hyprctl keyword "device[$kb]:kb_layout" "${code}" >/dev/null 2>&1 || true
        hyprctl switchxkblayout "$kb" 0 >/dev/null 2>&1 || true
    done
    hyprctl switchxkblayout all 0 >/dev/null 2>&1 || true
    if [ -f "$HOME/.config/hypr/config/settings.lua" ]; then
        sed -i -E 's/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*"[^"]*"/    kb_layout = "${code}"/' "$HOME/.config/hypr/config/settings.lua" 2>/dev/null || true
    fi
    hyprctl reload >/dev/null 2>&1 || true
elif [ -n "$NIRI_SOCKET" ] || pgrep -x niri &>/dev/null; then
    niri msg action switch-layout "${code}" >/dev/null 2>&1 || true
elif [ -n "$SWAYSOCK" ] || pgrep -x sway &>/dev/null; then
    swaymsg input "type:keyboard" xkb_layout "${code}" >/dev/null 2>&1 || true
fi

if command -v setxkbmap &>/dev/null; then
    if [ -n "${variant}" ]; then
        setxkbmap -layout "${code}" -variant "${variant}" >/dev/null 2>&1 || true
    else
        setxkbmap -layout "${code}" >/dev/null 2>&1 || true
    fi
fi
`;
        Quickshell.execDetached(["bash", "-c", cmd]);

        closeTimer.restart();
    }

    function closePopup() {
        let dir = (typeof Caching !== "undefined" && Caching.atlanticDir) ? Caching.atlanticDir : "";
        let runClose = `
for s in "${dir}/scripts/qs_manager.sh" "$HOME/.local/share/atlantic/src/scripts/qs_manager.sh" "/usr/local/share/atlantic/src/scripts/qs_manager.sh"; do
    if [ -f "$s" ]; then
        bash "$s" close
        exit 0
    fi
done
quickshell ipc call main handleCommand close "" "" 2>/dev/null || true
`;
        Quickshell.execDetached(["bash", "-c", runClose]);
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
            `
if [ -f "$HOME/.cache/atlantic/current_layout.txt" ]; then
    cat "$HOME/.cache/atlantic/current_layout.txt"
fi
if command -v hyprctl &>/dev/null && { [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || pgrep -x Hyprland &>/dev/null; }; then
    LC_ALL=C hyprctl devices -j 2>/dev/null | jq -r '
      ([ .keyboards[] | select(.main == true) ][0] // .keyboards[0]) as $kb |
      if $kb then (($kb.active_keymap // "") + " " + ($kb.layout // "") + " " + ($kb.variant // "")) else empty end
    '
elif command -v niri &>/dev/null && { [ -n "$NIRI_SOCKET" ] || pgrep -x niri &>/dev/null; }; then
    niri msg -j keyboard-layouts 2>/dev/null | jq -r '.names[.current_idx] // empty'
elif command -v swaymsg &>/dev/null && { [ -n "$SWAYSOCK" ] || pgrep -x sway &>/dev/null; }; then
    swaymsg -t get_inputs 2>/dev/null | jq -r '[.[] | select(.type == "keyboard" and .xkb_active_layout_name != null)][0].xkb_active_layout_name // empty'
fi
if [ -f "$HOME/.config/hypr/config/settings.lua" ]; then
    grep -E '^[[:space:]]*kb_layout[[:space:]]*=' "$HOME/.config/hypr/config/settings.lua" | head -n1
fi
            `
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                kbPopupRoot.activeKeymapRaw = txt;
                let lower = txt.toLowerCase();
                if (lower.includes("tr-f") || lower.includes("turkish (f)") || lower.includes("turkish f") || (lower.includes("turkish") && lower.includes(" f")) || (lower.includes(" tr") && lower.includes(" f"))) {
                    kbPopupRoot.activeLayoutId = "tr-f";
                    kbPopupRoot.activeLayoutName = "Turkish (F)";
                } else if (lower.includes("turkish") || lower.includes("türk") || lower.includes("\"tr\"") || lower.includes(" tr") || lower === "tr" || lower.startsWith("tr ") || lower.startsWith("tr\n")) {
                    kbPopupRoot.activeLayoutId = "tr";
                    kbPopupRoot.activeLayoutName = "Turkish (Q)";
                } else if (lower.includes("german") || lower.includes("deutsch") || lower.includes("\"de\"") || lower.includes(" de") || lower === "de" || lower.startsWith("de ") || lower.startsWith("de\n")) {
                    kbPopupRoot.activeLayoutId = "de";
                    kbPopupRoot.activeLayoutName = "German";
                } else if (lower.includes("french") || lower.includes("français") || lower.includes("\"fr\"") || lower.includes(" fr") || lower === "fr" || lower.startsWith("fr ") || lower.startsWith("fr\n")) {
                    kbPopupRoot.activeLayoutId = "fr";
                    kbPopupRoot.activeLayoutName = "French";
                } else if (lower.includes("spanish") || lower.includes("español") || lower.includes("\"es\"") || lower.includes(" es") || lower === "es" || lower.startsWith("es ") || lower.startsWith("es\n")) {
                    kbPopupRoot.activeLayoutId = "es";
                    kbPopupRoot.activeLayoutName = "Spanish";
                } else if (lower.includes("russian") || lower.includes("русский") || lower.includes("\"ru\"") || lower.includes(" ru") || lower === "ru" || lower.startsWith("ru ") || lower.startsWith("ru\n")) {
                    kbPopupRoot.activeLayoutId = "ru";
                    kbPopupRoot.activeLayoutName = "Russian";
                } else if (lower.includes("italian") || lower.includes("italiano") || lower.includes("\"it\"") || lower.includes(" it") || lower === "it" || lower.startsWith("it ") || lower.startsWith("it\n")) {
                    kbPopupRoot.activeLayoutId = "it";
                    kbPopupRoot.activeLayoutName = "Italian";
                } else if (lower.includes("uk") || lower.includes("united kingdom") || lower.includes("\"gb\"") || lower.includes(" gb") || lower === "gb" || lower.startsWith("gb ") || lower.startsWith("gb\n")) {
                    kbPopupRoot.activeLayoutId = "gb";
                    kbPopupRoot.activeLayoutName = "English (UK)";
                } else if (lower.includes("us") || lower.includes("united states") || lower.includes("\"us\"") || lower.includes(" us") || lower === "us") {
                    kbPopupRoot.activeLayoutId = "us";
                    kbPopupRoot.activeLayoutName = "English (US)";
                } else {
                    kbPopupRoot.activeLayoutId = "tr";
                    kbPopupRoot.activeLayoutName = "Turkish (Q)";
                }
            }
        }
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
                        text: "Keyboard Layout"
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
                                : (isHovered ? Qt.alpha(ThemeBackend.surface1, 0.5) : Qt.alpha(ThemeBackend.surface0, 0.35))

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

                                // Flag / Badge Pill Box (consistent width and border on every item)
                                Rectangle {
                                    implicitWidth: kbPopupRoot.s(42)
                                    implicitHeight: kbPopupRoot.s(32)
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                                    radius: ThemeBackend.borderRadius
                                    color: isActive ? Qt.alpha(ThemeBackend.mauve, 0.25) : Qt.alpha(ThemeBackend.surface1, 0.5)
                                    border.color: isActive ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface2, 0.5)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.badge
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: kbPopupRoot.s(11)
                                        font.bold: true
                                        color: isActive ? ThemeBackend.mauve : ThemeBackend.text
                                    }
                                }

                                // Layout Name & Description - Firmly Left-Aligned
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                                    spacing: kbPopupRoot.s(2)

                                    RowLayout {
                                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                                        spacing: kbPopupRoot.s(6)

                                        Text {
                                            text: modelData.name
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: kbPopupRoot.s(13)
                                            font.bold: true
                                            color: ThemeBackend.text
                                            horizontalAlignment: Text.AlignLeft
                                        }

                                        Text {
                                            text: modelData.flag
                                            font.pixelSize: kbPopupRoot.s(12)
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                                        text: modelData.sub
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: kbPopupRoot.s(10)
                                        color: ThemeBackend.subtext0
                                        horizontalAlignment: Text.AlignLeft
                                    }
                                }

                                // Right-side action container (always fixed size for perfect horizontal rhythm)
                                Item {
                                    implicitWidth: kbPopupRoot.s(28)
                                    implicitHeight: kbPopupRoot.s(28)
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                                    // Active checkmark badge
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: kbPopupRoot.s(26)
                                        height: kbPopupRoot.s(26)
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
                                        anchors.centerIn: parent
                                        visible: !isActive && isHovered
                                        text: "󰄾"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: kbPopupRoot.s(14)
                                        color: ThemeBackend.subtext0
                                    }
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
