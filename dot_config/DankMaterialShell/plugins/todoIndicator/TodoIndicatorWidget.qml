import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "todo-indicator"

    // Counts from `todo-calendar --status` -> {"daily":N,"monthly":N,"yearly":N}
    property int dailyCount: 0
    property int monthlyCount: 0
    property int yearlyCount: 0

    // Red when there are unsolved monthly todos, green otherwise.
    property bool hasMonthly: monthlyCount > 0
    property color statusColor: hasMonthly ? Theme.error : Theme.success

    function refresh() {
        statusProcess.running = true
    }

    Process {
        id: statusProcess
        command: ["todo-calendar", "--status"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return
                try {
                    const d = JSON.parse(text.trim())
                    root.dailyCount = d.daily || 0
                    root.monthlyCount = d.monthly || 0
                    root.yearlyCount = d.yearly || 0
                } catch (e) {
                    console.warn("todoIndicator: parse failed:", e, text)
                }
            }
        }
    }

    // Poll periodically; also refresh on load.
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    // Open the calendar; refresh shortly after in case todos changed.
    pillClickAction: () => {
        Quickshell.execDetached(["foot", "todo-calendar"])
        reopenTimer.start()
    }

    Timer {
        id: reopenTimer
        interval: 1500
        repeat: false
        onTriggered: root.refresh()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.hasMonthly ? "event_busy" : "event_available"
                size: Theme.fontSizeLarge
                color: root.statusColor
                filled: true
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.monthlyCount > 0
                text: root.monthlyCount
                color: root.statusColor
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    verticalBarPill: Component {
        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: root.hasMonthly ? "event_busy" : "event_available"
            size: Theme.fontSizeLarge
            color: root.statusColor
            filled: true
        }
    }
}
