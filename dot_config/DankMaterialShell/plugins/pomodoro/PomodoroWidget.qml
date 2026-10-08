import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "pomodoro.js" as P

PluginComponent {
    id: root

    layerNamespacePlugin: "pomodoro"

    // Settings, edited in the right-click popout. Output names from `niri msg outputs`.
    readonly property int workMin: pluginData.workMinutes ?? 25
    readonly property int breakMin: pluginData.breakMinutes ?? 5
    readonly property int startHour: pluginData.startHour ?? 9
    readonly property int endHour: pluginData.endHour ?? 17
    readonly property string overlayScreen: pluginData.screen ?? "DP-2"
    readonly property var cfg: ({ work: workMin * 60000, brk: breakMin * 60000, startHour: startHour, endHour: endHour })

    // The bar runs one instance per monitor; plugin state keeps them in sync
    // and survives shell restarts.
    property var st: P.reset()
    property real now: Date.now()

    readonly property var v: P.view(st, now, cfg)
    readonly property bool running: v.running
    readonly property bool active: v.active
    readonly property bool done: v.done
    readonly property bool warn: v.warn
    readonly property real nextBreak: P.nextBreak(now, cfg)
    readonly property string phase: v.phase
    readonly property string label: P.format(v.remaining)
    readonly property string icon: v.auto && !active ? "timer_off" : phase === "break" ? "coffee" : "timer"
    readonly property color accent: done ? Theme.error : warn || phase === "break" ? Theme.success : Theme.primary
    // Connector names shift with the dock (DP-2 one day, DP-4 the next), so the
    // setting also matches the model; nothing matching falls back to the last screen.
    readonly property var overlayTarget: Quickshell.screens.find(s => s.name === overlayScreen || s.model === overlayScreen)
        ?? Quickshell.screens[Quickshell.screens.length - 1]
    readonly property bool ownsOverlay: !!parentScreen && parentScreen.name === overlayTarget?.name

    function load() {
        if (pluginService)
            st = pluginService.loadPluginState("pomodoro", "timer", P.reset())
        now = Date.now()
    }

    function save(s) {
        pluginService?.savePluginState("pomodoro", "timer", s)
    }

    function setSetting(key, value) {
        pluginService?.savePluginData(pluginId, key, value)
    }

    Component.onCompleted: load()
    onPluginServiceChanged: load()

    Connections {
        target: root.pluginService
        function onPluginStateChanged(id) {
            if (id === "pomodoro")
                root.load()
        }
    }

    // Only the overlay owner notifies, so there's one notification and sound, not one per bar.
    // Clips from home-cluster/config/terran-voice: "Need a light?" = pomodoro starts, "Fire it up!" = back to work.
    function notify(text, sound) {
        if (!ownsOverlay)
            return
        Quickshell.execDetached(["notify-send", "-t", "20000", "-a", "Pomodoro", text])
        Quickshell.execDetached(["paplay", Qt.resolvedUrl("sounds/" + sound + ".wav").toString().replace("file://", "")])
    }

    // Always ticking: the schedule has to notice when working hours begin.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            const prev = root.v
            root.now = Date.now()
            if (prev.auto && root.v.auto && root.running && prev.phase !== root.phase)
                root.phase === "break" ? root.notify("Pomodoro — take a break", "need-a-light")
                                       : root.notify("Back to work", "fire-it-up")
        }
    }

    onDoneChanged: {
        if (done)
            phase === "work" ? notify("Work done — take a break", "need-a-light")
                             : notify("Break over — back to work", "fire-it-up")
    }

    pillClickAction: () => save(P.click(st, Date.now(), cfg))
    // ponytail: triggerPopout() runs pillClickAction whenever one is set, so unset it for this call
    pillRightClickAction: () => {
        const click = pillClickAction
        pillClickAction = null
        triggerPopout()
        pillClickAction = click
    }

    popoutWidth: 340
    popoutContent: Component {
        PopoutComponent {
            headerText: "Pomodoro"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    text: {
                        const hm = t => Qt.formatTime(new Date(t), "HH:mm")
                        if (root.v.auto && root.phase === "break")
                            return "Pomodoro now · back to work " + hm(root.now + root.v.remaining)
                        if (root.nextBreak === 0)
                            return "Schedule off"
                        return "Next pomodoro " + hm(root.nextBreak) + " (" + P.until(root.nextBreak - root.now) + ")"
                            + " · back to work " + hm(root.nextBreak + root.cfg.brk)
                    }
                    wrapMode: Text.WordWrap
                    width: parent.width
                    color: Theme.primary
                    font.pixelSize: Theme.fontSizeLarge
                }

                StyledText {
                    text: "Work " + root.workMin + " min"
                    color: Theme.surfaceText
                }
                DankSlider {
                    width: parent.width
                    minimum: 1
                    maximum: 90
                    value: root.workMin
                    unit: " min"
                    onSliderValueChanged: v => root.setSetting("workMinutes", v)
                }

                StyledText {
                    text: "Break " + root.breakMin + " min"
                    color: Theme.surfaceText
                }
                DankSlider {
                    width: parent.width
                    minimum: 1
                    maximum: 30
                    value: root.breakMin
                    unit: " min"
                    onSliderValueChanged: v => root.setSetting("breakMinutes", v)
                }

                StyledText {
                    text: "Schedule " + root.startHour + ":00 – " + root.endHour + ":00 (same hour = off)"
                    color: Theme.surfaceText
                }
                DankSlider {
                    width: parent.width
                    minimum: 0
                    maximum: 23
                    value: root.startHour
                    unit: " h"
                    leftIcon: "wb_sunny"
                    onSliderValueChanged: v => root.setSetting("startHour", v)
                }
                DankSlider {
                    width: parent.width
                    minimum: 1
                    maximum: 24
                    value: root.endHour
                    unit: " h"
                    leftIcon: "bedtime"
                    onSliderValueChanged: v => root.setSetting("endHour", v)
                }

                DankDropdown {
                    width: parent.width
                    text: "Overlay monitor"
                    options: Quickshell.screens.map(s => s.name)
                    currentValue: root.overlayScreen
                    onValueChanged: v => root.setSetting("screen", v)
                }

                DankButton {
                    text: "Reset (also turns the schedule back on)"
                    iconName: "restart_alt"
                    onClicked: {
                        root.save(P.reset())
                        root.closePopout()
                    }
                }
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                size: Theme.fontSizeLarge
                color: root.active ? root.accent : Theme.surfaceText
                filled: root.running
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.active
                text: root.label
                color: root.accent
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    verticalBarPill: Component {
        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: root.icon
            size: Theme.fontSizeLarge
            color: root.active ? root.accent : Theme.surfaceText
            filled: root.running
        }
    }

    LazyLoader {
        active: root.ownsOverlay && root.v.overlay

        PanelWindow {
            screen: root.parentScreen
            WlrLayershell.namespace: "dms:plugins:pomodoro-overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusiveZone: 0
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                top: true
                right: true
            }
            margins {
                top: 80
                right: 40
            }
            implicitWidth: timeText.implicitWidth + 64
            implicitHeight: timeText.implicitHeight + 24
            color: "transparent"
            mask: Region {} // click-through

            Rectangle {
                id: badge
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: root.done ? root.accent : Theme.withAlpha(Theme.surfaceContainer, 0.75)

                StyledText {
                    id: timeText
                    anchors.centerIn: parent
                    text: root.label
                    color: root.done ? Theme.surfaceContainer : root.accent
                    font.pixelSize: 96
                    font.weight: Font.Bold
                }
            }

            // Steady during the break; blinks in the last minutes before it, or when a manual timer is up.
            SequentialAnimation {
                running: root.done || root.warn
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { target: badge; property: "opacity"; to: 0.1; duration: 250 }
                NumberAnimation { target: badge; property: "opacity"; to: 1; duration: 250 }
            }
        }
    }
}
