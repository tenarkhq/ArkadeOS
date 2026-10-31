/*
 * ArkadeOS power profile switch (T012) for the top bar: shows the current
 * profile and why it was switched automatically, and switches by hand.
 * Below it the lighting (T042): colours following the profile, on or off,
 * and OpenRGB for the details; battery care on laptops. arkadeos-power (T011)
 * and arkadeos-rgb do the work.
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
    property bool rgbSync: false
    property bool hasBattery: true
    property string charge: "none"

    // English and Hungarian (T010); the rest of the system follows the locale too.
    readonly property bool hu: Qt.locale().name.startsWith("hu")
    function tr(en, hun) { return hu ? hun : en }

    readonly property var names: ({
        // A desktop has no battery: the same profile is called Quiet (T052).
        battery: hasBattery ? tr("Battery", "Akku") : tr("Quiet", "Csendes"),
        balanced: tr("Balanced", "Kiegyensúlyozott"),
        gaming: "Gaming",
        max: "Max",
        wow: "WoW"
    })
    readonly property var icons: ({
        battery: "power-profile-power-saver-symbolic",
        balanced: "power-profile-balanced-symbolic",
        gaming: "power-profile-performance-symbolic",
        max: "power-profile-performance-symbolic",
        wow: "power-profile-performance-symbolic"
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
            else if (key === "rgb") rgbSync = value === "on"
            else if (key === "has_battery") hasBattery = value === "true"
            else if (key === "charge") charge = value
        })
    }
    function refresh() { exec.connectSource("arkadeos-power status") }
    function setProfile(name) { exec.connectSource("arkadeos-power set " + name) }
    function setCharge(on) { exec.connectSource("arkadeos-power charge " + (on ? "on" : "off")) }
    function setRgbSync(on) { exec.connectSource("arkadeos-rgb sync " + (on ? "on" : "off")) }

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
            model: ["battery", "balanced", "gaming", "max", "wow"]
            PlasmaComponents3.RadioDelegate {
                required property string modelData
                Layout.fillWidth: true
                icon.name: root.icons[modelData]
                text: root.names[modelData] + (modelData === "max" ? root.tr(" (charger only)", " (csak töltőn)")
                    : modelData === "wow" ? root.tr(" (full CPU, GPU held back)", " (teljes CPU, visszafogott GPU)") : "")
                checked: root.profile === modelData
                enabled: modelData !== "max" || !root.onBattery
                onClicked: root.setProfile(modelData)
            }
        }

        // Battery care (T013, T046, T047): charging stops at 80%.
        PlasmaComponents3.Switch {
            Layout.fillWidth: true
            visible: root.charge !== "none"
            text: root.tr("Battery care: charge to 80%", "Akkukímélés: töltés 80%-ig")
            checked: root.charge === "on"
            onToggled: root.setCharge(checked)
        }

        Kirigami.Separator { Layout.fillWidth: true }
        PlasmaComponents3.Switch {
            Layout.fillWidth: true
            text: root.tr("Lighting follows the profile", "A világítás követi a profilt")
            checked: root.rgbSync
            onToggled: root.setRgbSync(checked)
        }
        PlasmaComponents3.Button {
            Layout.fillWidth: true
            icon.name: "preferences-desktop-color"
            text: root.tr("Lighting settings (OpenRGB)", "Világítás beállításai (OpenRGB)")
            onClicked: exec.connectSource("gtk-launch org.openrgb.OpenRGB")
        }
    }
}
