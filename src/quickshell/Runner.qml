import QtQuick
import Quickshell
import "."

Scope {
    id: runnerRoot

    property string targetFile: Quickshell.env("ATLANTIC_TARGET_FILE") || ""

    Loader {
        active: runnerRoot.targetFile !== ""
        source: runnerRoot.targetFile
    }
}
