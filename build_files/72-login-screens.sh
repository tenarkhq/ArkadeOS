#!/usr/bin/bash
# ArkadeOS Glass login and lock screens (T086 round 8, approved 2026-11-14,
# "így jó" on canvas page 8). The login screen (Plasma Login Manager) and the
# lock screen build on the same Breeze components: the clock, the user card
# (SessionManagementScreen) and the round buttons (ActionButton). Patching
# them here gives both screens the approved look: a thin clock, a glass card
# behind the face and the password, glass circle buttons and the Start mark in
# the top left corner. Their wallpaper is Égkék (kscreenlockerrc and
# /usr/lib/plasmalogin/plasmalogin.conf.d/20-arkadeos.conf); the status icons
# stay in Plasma's footer at the bottom.
set -euo pipefail

components=/usr/lib64/qt6/qml/org/kde/breeze/components
# The module prefers its compiled-in copies; without the prefer line Qt loads
# the files on disk, which are the patched ones below.
sed -i '/^prefer /d' "${components}/qmldir"
! grep -q '^prefer' "${components}/qmldir"

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
        height: gu * 15.5
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
test -s /usr/share/icons/arkadeos-glass-dark/marks/m/arkadeos-logo.svg
