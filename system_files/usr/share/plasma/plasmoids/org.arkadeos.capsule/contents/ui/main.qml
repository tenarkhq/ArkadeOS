pragma ComponentBehavior: Bound
/*
 * ArkadeOS Glass (T086): the glass capsule of the taskbar Roland picked
 * (design C, https://claude.ai/artifact/A9QNLgyxWb3rFxzpJJBJs8): the tray and
 * the clock sit in one pill of lighter glass, 30 px tall, with a lit rim.
 * Plasma has no background per widget, so this widget draws it behind the
 * widgets before it on the panel, back to the previous spacer. Outside edit
 * mode it is a strip of the pill's own air at its end; in edit mode an icon,
 * so that it can be moved or removed like any widget.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property bool hu: Qt.locale().name.startsWith("hu")
    readonly property bool editing: Plasmoid.containment?.corona?.editMode ?? false
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
        || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical
    // The design's pill: 30 px across, and as much glass beyond the first
    // widget as this widget's own strip gives at the other end.
    readonly property int thick: 30
    readonly property int pad: 6
    // Where a capsule ends: the panel's spacers and another capsule.
    readonly property var stops: ["org.kde.plasma.panelspacer", "org.kde.plasma.marginsseparator", "org.arkadeos.capsule"]

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: Plasmoid.title
    toolTipSubText: hu ? "Üvegkapszula az előtte álló elemek mögött, az előző térközig"
                       : "A glass capsule behind the widgets before it, back to the previous spacer"

    fullRepresentation: Item {
        id: strip
        readonly property int size: root.editing ? Kirigami.Units.iconSizes.smallMedium : root.pad
        Layout.minimumWidth: root.horizontal ? strip.size : -1
        Layout.preferredWidth: root.horizontal ? strip.size : -1
        Layout.maximumWidth: root.horizontal ? strip.size : -1
        Layout.minimumHeight: root.horizontal ? -1 : strip.size
        Layout.preferredHeight: root.horizontal ? -1 : strip.size
        Layout.maximumHeight: root.horizontal ? -1 : strip.size

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.smallMedium
            height: width
            source: Plasmoid.icon
            visible: root.editing
        }
    }

    // The panel's own layout: its children are the widgets' holders.
    property Item layout: null
    function findLayout() {
        let item = root.parent
        while (item) {
            if (item instanceof GridLayout)
                return item
            item = item.parent
        }
        return null
    }
    onParentChanged: layout = findLayout()
    Component.onCompleted: layout = findLayout()
    Timer {
        interval: 1000
        repeat: true
        running: root.inPanel && root.layout === null
        onTriggered: root.layout = root.findLayout()
    }

    // This widget's holder and the visible widgets before it, back to a stop.
    readonly property var group: {
        if (!inPanel || !layout)
            return null
        const holders = []
        for (let i = 0; i < layout.children.length; i++) {
            const c = layout.children[i]
            if (c.isAppletContainer && c.applet)
                holders.push(c)
        }
        holders.sort((a, b) => a.index - b.index)
        const me = holders.findIndex(c => c.applet === root || c.applet.Plasmoid?.id === Plasmoid.id)
        if (me < 0)
            return null
        const members = []
        for (let i = me - 1; i >= 0; i--) {
            if (stops.indexOf(holders[i].applet.Plasmoid?.pluginName ?? "") >= 0)
                break
            if (holders[i].visible)
                members.unshift(holders[i])
        }
        return members.length ? { own: holders[me], first: members[0] } : null
    }

    Rectangle {
        parent: root.layout ? root.layout.parent : root
        z: root.layout ? root.layout.z - 1 : 0
        visible: box.width > 0
        // One reading of the group, so that its two ends never come from
        // two different moments (one of them null) while widgets change.
        readonly property rect box: {
            const g = root.group
            const l = root.layout
            if (!g || !l || !g.first || !g.own)
                return Qt.rect(0, 0, 0, 0)
            const f = g.first, o = g.own
            const across = Math.min(root.thick, root.horizontal ? f.height : f.width)
            return root.horizontal
                ? Qt.rect(l.x + f.x - root.pad, l.y + f.y + (f.height - across) / 2, o.x + o.width - f.x + root.pad, across)
                : Qt.rect(l.x + f.x + (f.width - across) / 2, l.y + f.y - root.pad, across, o.y + o.height - f.y + root.pad)
        }
        x: box.x
        y: box.y
        width: box.width
        height: box.height
        readonly property real across: root.horizontal ? height : width
        radius: across / 2
        // As in the design: white glass at 10 %, its rim at 25 %.
        color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.25)
    }
}
