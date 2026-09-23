import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import "../"
import "../reusables"

Item {
    id: welcomeTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex

    property bool revealed: false
    opacity: revealed ? 1.0 : 0.0
    property real slideY: revealed ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    function activateTab() {
        revealed = true;
        logoFillLevel = 0.0;
        logoFillAnim.restart();
    }

    onVisibleChanged: {
        if (visible) activateTab();
    }

    Component.onCompleted: {
        if (visible) activateTab();
    }

    property real titleWavePhase: 0.0
    NumberAnimation on titleWavePhase {
        running: welcomeTabRoot.visible
        loops: Animation.Infinite
        from: 0
        to: Math.PI * 2
        duration: 7000
    }

    component StartButtonContent : Item {
        id: bRoot
        property color textColor: ThemeBackend.blue
        property real fillLevel: 0.0
        property bool isHovered: false

        RowLayout {
            anchors.centerIn: parent
            spacing: rootObj.s(10)

            Text {
                id: iconText
                text: "󰐊"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: rootObj.s(18)
                color: bRoot.textColor
                Behavior on color { ColorAnimation { duration: 150 } }

                property real charNorm: 0.15
                property real bump: bRoot.fillLevel > 0.001 && bRoot.fillLevel < 0.999
                                    ? Math.exp(-Math.pow((bRoot.fillLevel - charNorm) * 12, 2))
                                    : 0.0

                transform: [
                    Translate { y: -iconText.bump * rootObj.s(2.5) },
                    Scale { origin.x: width / 2; origin.y: height / 2; xScale: 1.0 + iconText.bump * 0.08; yScale: 1.0 + iconText.bump * 0.08 }
                ]
            }

            Row {
                spacing: 0
                Repeater {
                    model: Array.from(I18n.t("guide.welcome.start_tutorial"))
                    Text {
                        id: charText
                        required property string modelData
                        required property int index

                        text: modelData === " " ? "\u00A0" : modelData
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: rootObj.s(14)

                        color: bRoot.textColor
                        Behavior on color { ColorAnimation { duration: 150 } }

                        property real charNorm: 0.25 + (index / 14) * 0.65
                        property real bump: bRoot.fillLevel > 0.001 && bRoot.fillLevel < 0.999
                                            ? Math.exp(-Math.pow((bRoot.fillLevel - charNorm) * 12, 2))
                                            : 0.0

                        transform: [
                            Translate { y: -charText.bump * rootObj.s(2.5) },
                            Scale { origin.x: width / 2; origin.y: height / 2; xScale: 1.0 + charText.bump * 0.08; yScale: 1.0 + charText.bump * 0.08 }
                        ]
                    }
                }
            }
        }
    }

    Connections {
        target: rootObj
        function onActivationCounterChanged() {
            if (welcomeTabRoot.visible) {
                activateTab();
            }
        }
    }

    property real logoFillLevel: 0.0

    NumberAnimation {
        id: logoFillAnim
        target: welcomeTabRoot
        property: "logoFillLevel"
        from: 0.0
        to: 1.15
        duration: 6500
        easing.type: Easing.OutCubic
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: rootObj.s(25)

        Item {
            id: logoContainer
            Layout.alignment: Qt.AlignHCenter
            width: rootObj.s(240)
            height: rootObj.s(240)

            Rectangle {
                anchors.centerIn: parent
                width: rootObj.s(210)
                height: rootObj.s(210)
                radius: width / 2
                color: "transparent"
                layer.enabled: true
                layer.smooth: true

                Image {
                    anchors.fill: parent
                    anchors.margins: -rootObj.s(12)
                    source: "file://" + rootObj.appPaths.atlanticDir + "/assets/logo.png"
                    sourceSize: Qt.size(512, 512)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    antialiasing: true
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: rootObj.s(4)

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 0

                property string mainTitle: I18n.t("guide.about.title")
                property string verText: " v" + (Updater.localVersion !== "..." ? Updater.localVersion : (rootObj.dotsVersion !== "Loading..." && rootObj.dotsVersion !== I18n.t("guide.about.loading") ? rootObj.dotsVersion : "..."))
                property string fullText: mainTitle + verText

                Repeater {
                    model: Array.from(parent.fullText)
                    Text {
                        required property string modelData
                        required property int index

                        text: modelData === " " ? "\u00A0" : modelData
                        font.family: ThemeBackend.fontFamily
                        font.weight: index < 8 ? Font.Black : Font.Bold
                        font.pixelSize: index < 8 ? rootObj.s(32) : rootObj.s(14)
                        color: index < 8 ? ThemeBackend.sapphire : ThemeBackend.subtext0

                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: index < 8 ? 0 : rootObj.s(4)

                        transform: Translate {
                            y: Math.sin(welcomeTabRoot.titleWavePhase - index * 0.35) * rootObj.s(2.5)
                        }
                    }
                }
            }

            Text {
                text: I18n.t("guide.welcome.by_author", { author: "kravorx" })
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(14)
                color: ThemeBackend.subtext0
                Layout.alignment: Qt.AlignHCenter
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: rootObj.s(16)

            ClickButton {
                id: aboutBtn
                Layout.preferredWidth: rootObj.s(130)
                Layout.preferredHeight: rootObj.s(48)
                horizontalPadding: rootObj.s(12)
                cornerRadius: rootObj.s(12)
                buttonText: I18n.t("guide.welcome.about")
                textFontSize: rootObj.s(14)
                buttonIcon: ""
                iconFontSize: rootObj.s(16)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text

                onTriggered: rootObj.gotoTab("About")
            }
        }
    }
}
