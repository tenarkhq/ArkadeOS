#!/usr/bin/bash
# ArkadeOS Glass login and lock screens (T086 round 8, approved 2026-11-14,
# "így jó" on canvas page 8). The login screen (Plasma Login Manager) and the
# lock screen build on the same Breeze components: the clock, the user card
# (SessionManagementScreen) and the round buttons (ActionButton). Patching
# them here gives both screens the approved look: a thin clock, a glass card
# behind the face and the password, the password as a dark glass field with a
# blue arrow key, glass circle buttons and the Start mark in the top left
# corner. Their wallpaper is Égkék (kscreenlockerrc and
# /usr/lib/plasmalogin/plasmalogin.conf.d/20-arkadeos.conf); the status icons
# stay in Plasma's footer at the bottom.
set -euo pipefail

components=/usr/lib64/qt6/qml/org/kde/breeze/components
# The module prefers its compiled-in copies; without the prefer line Qt loads
# the files on disk, which are the patched ones below.
sed -i '/^prefer /d' "${components}/qmldir"
if grep -q '^prefer' "${components}/qmldir"; then exit 1; fi

COMPONENTS="${components}" python3 - <<'PY'
import os

d = os.environ["COMPONENTS"]


def patch(name, pairs):
    p = os.path.join(d, name)
    s = open(p).read()
    for old, new in pairs:
        assert s.count(old) == 1, (name, old)
        s = s.replace(old, new, 1)
    open(p, "w").write(s)


# The glass card behind the face, the name and the password field (the
# approved render: rgba(45,81,110,.42), a white .16 rim, round corners), and
# the Start mark in the corner of the screen.
card = """    // ArkadeOS Glass (T086 round 8): the glass card behind the user and the
    // password, and the Start mark in the top left corner of the screen.
    Rectangle {
        id: arkadeosCard
        readonly property real gu: Kirigami.Units.gridUnit
        visible: root.showUserList
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 - gu * 10.5
        width: Math.min(parent.width - gu * 2, gu * 20)
        // Down to just under the fields: the lock screen's sit lower than
        // the login screen's, and a message above them pushes them down.
        height: Math.max(gu * 15.5, prompts.y + innerLayout.parent.y + innerLayout.y + innerLayout.height + gu * 0.9 - y)
        radius: gu * 1.1
        color: Qt.rgba(45 / 255, 81 / 255, 110 / 255, 0.42)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
    }
    Image {
        parent: root.Window.contentItem
        z: 1000
        visible: root.visible
        opacity: root.opacity
        x: Kirigami.Units.gridUnit
        y: Kirigami.Units.gridUnit
        width: Kirigami.Units.gridUnit * 2.2
        height: width
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
        source: "file:///usr/share/icons/arkadeos-glass-dark/marks/m/arkadeos-logo.svg"
    }

    // The fields under the face (the password, and the user name where the
    // login screen asks for it) are dark glass with a light rim, and the
    // arrow button next to the password is a blue glass key with a white
    // arrow (the approved render: rgba(10,20,32,.45), rim rgba(191,230,255,
    // .28), placeholder #9fb7cc, key #6fb8ef to #2f78bd). The login screen's
    // own QML is compiled into its greeter, so the fields are found here, in
    // the screen both the login and the lock screen are built on.
    // The field takes its height and text margins from its background
    // (Plasma's TextField reads background.margins), so the glass brings
    // the render's: 2.2 units high, the text 0.65 units from the rim.
    Component {
        id: arkadeosFieldGlass
        Rectangle {
            readonly property real gu: Kirigami.Units.gridUnit
            readonly property QtObject margins: QtObject {
                readonly property real left: Math.round(Kirigami.Units.gridUnit * 0.65)
                readonly property real right: left
                readonly property real top: Math.round(Kirigami.Units.gridUnit * 0.3)
                readonly property real bottom: top
            }
            implicitWidth: gu * 8 + margins.left + margins.right
            implicitHeight: Math.round(gu * 2.2)
            radius: Math.round(height * 0.26)
            color: Qt.rgba(10 / 255, 20 / 255, 32 / 255, 0.45)
            border.width: 1
            border.color: Qt.rgba(191 / 255, 230 / 255, 1, 0.28)
        }
    }
    Component {
        id: arkadeosKeyGlass
        Rectangle {
            radius: Math.round(height * 0.25)
            opacity: parent && parent.down ? 0.8 : 1
            gradient: Gradient {
                GradientStop { position: 0; color: "#6fb8ef" }
                GradientStop { position: 1; color: "#2f78bd" }
            }
        }
    }
    function arkadeosGlass(item) {
        const kids = item.children;
        let password = false;
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i].echoMode === TextInput.Password) {
                password = true;
            }
        }
        for (let i = 0; i < kids.length; ++i) {
            const c = kids[i];
            if (c.echoMode !== undefined && c.placeholderTextColor !== undefined) {
                c.background = arkadeosFieldGlass.createObject(c);
                c.color = "#ffffff";
                c.placeholderTextColor = "#9fb7cc";
                c.Kirigami.Theme.inherit = false;
                c.Kirigami.Theme.textColor = "#ffffff";
            } else if (password && c.icon !== undefined && c.flat !== undefined) {
                c.background = arkadeosKeyGlass.createObject(c);
                // The render's arrow (a shaft and a head; Breeze only has a
                // chevron); like the original, no icon when it shows text.
                // (A file named like a theme icon, arrow-right.svg, would be
                // swapped for that theme icon by the icon loader.)
                const key = c;
                const arrow = () => {
                    key.icon.name = "";
                    key.icon.source = key.text.length > 0 ? "" : "file:///usr/share/arkadeos/login/arkadeos-key-" + (key.LayoutMirroring.enabled ? "left" : "right") + ".svg";
                };
                arrow();
                c.textChanged.connect(arrow);
                c.icon.width = Math.round(Kirigami.Units.gridUnit);
                c.icon.height = c.icon.width;
                c.icon.color = "#ffffff";
                c.Kirigami.Theme.inherit = false;
                c.Kirigami.Theme.textColor = "#ffffff";
            } else {
                arkadeosGlass(c);
            }
        }
    }
    Component.onCompleted: arkadeosGlass(innerLayout)

    UserList {
"""
patch("SessionManagementScreen.qml", [
    ("import QtQuick\n", "import QtQuick\nimport QtQuick.Window\n"),
    ("    UserList {\n", card),
])

# Glass circle buttons (Sleep, Restart, Shut down...): a 2.4-unit circle of
# white .08 (.16 under the pointer) with a white .18 rim, a smaller icon.
patch("ActionButton.qml", [
    ("    icon.width: Kirigami.Units.iconSizes.large\n    icon.height: Kirigami.Units.iconSizes.large\n",
     "    icon.width: Kirigami.Units.iconSizes.smallMedium\n    icon.height: Kirigami.Units.iconSizes.smallMedium\n"),
    ("    padding: Kirigami.Units.smallSpacing\n",
     "    padding: Math.round((Kirigami.Units.gridUnit * 2.4 - Kirigami.Units.iconSizes.smallMedium) / 2)\n"),
    ("""        color: root.softwareRendering ? Kirigami.Theme.backgroundColor : Kirigami.Theme.textColor
        opacity: {
            if (root.activeFocus || root.hovered) {
                return root.softwareRendering ? 0.8 : 0.15
            }
            return root.softwareRendering ? 0.6 : 0
        }
""", """        // ArkadeOS Glass (T086 round 8): a glass circle, always visible
        color: root.softwareRendering ? Kirigami.Theme.backgroundColor : Qt.rgba(1, 1, 1, root.activeFocus || root.hovered ? 0.16 : 0.08)
        border.width: root.softwareRendering ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        opacity: root.softwareRendering ? (root.activeFocus || root.hovered ? 0.8 : 0.6) : 1
"""),
])

# The thin clock of the approved render instead of the heavy one.
patch("Clock.qml", [
    ("        font.weight: Font.DemiBold\n        font.letterSpacing: -3.0\n",
     "        font.weight: Font.ExtraLight\n        font.letterSpacing: -1.0\n"),
])
PY

grep -q arkadeosCard "${components}/SessionManagementScreen.qml"
grep -q arkadeosFieldGlass "${components}/SessionManagementScreen.qml"
test -s /usr/share/icons/arkadeos-glass-dark/marks/m/arkadeos-logo.svg
test -s /usr/share/arkadeos/login/arkadeos-key-right.svg
test -s /usr/share/arkadeos/login/arkadeos-key-left.svg
