/*
 * ArkadeOS power profile switch (T012) for the top bar: shows the current
 * profile and why it was switched automatically, and switches by hand.
 * arkadeos-power (T011) does the work.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string profile: "balanced"
    property string auto: ""
    property bool onBattery: false

    // English and Hungarian (T010); the rest of the system follows the locale too.
    readonly property bool hu: Qt.locale().name.startsWith("hu")
    function tr(en, hun) { return hu ? hun : en }

    readonly property var names: ({
        battery: tr("Battery", "Akku"),
        balanced: tr("Balanced", "Kiegyensúlyozott"),
        gaming: "Gaming",
        max: "Max"
    })
    readonly property var icons: ({
        battery: "power-profile-power-saver-symbolic",
        balanced: "power-profile-balanced-symbolic",
        gaming: "power-profile-performance-symbolic",
        max: "power-profile-performance-symbolic"
    })
    readonly property string autoText: auto === "game" ? tr("Automatic: a game is running", "Automatikus: játék fut")
        : auto === "battery" ? tr("Automatic: running on battery", "Automatikus: akkuról megy")
        : ""

    Plasmoid.icon: icons[profile]
    Plasmoid.title: tr("Power profile", "Energiaprofil")
    toolTipMainText: names[profile]
    toolTipSubText: autoText

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.endsWith("status")) {
                parse(data["stdout"])
            } else {
                refresh()
            }
        }
    }

    function parse(out) {
        out.split("\n").forEach(line => {
            const [key, value] = line.split("=")
            if (key === "profile") profile = value
            else if (key === "auto") auto = value
            else if (key === "on_battery") onBattery = value === "true"
        })
    }
    function refresh() { exec.connectSource("arkadeos-power status") }
    function setProfile(name) { exec.connectSource("arkadeos-power set " + name) }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        spacing: Kirigami.Units.smallSpacing

        PlasmaExtras.Heading {
            level: 4
            text: root.tr("Power profile", "Energiaprofil")
        }
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            visible: root.autoText !== ""
            text: root.autoText
            opacity: 0.7
            wrapMode: Text.Wrap
        }
        Repeater {
            model: ["battery", "balanced", "gaming", "max"]
            PlasmaComponents3.RadioDelegate {
                required property string modelData
                Layout.fillWidth: true
                icon.name: root.icons[modelData]
                text: root.names[modelData] + (modelData === "max" ? root.tr(" (charger only)", " (csak töltőn)") : "")
                checked: root.profile === modelData
                enabled: modelData !== "max" || !root.onBattery
                onClicked: root.setProfile(modelData)
            }
        }
    }
}
