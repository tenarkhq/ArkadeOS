# Roland, 2026-11-03: the ArkadeOS menu leaves the top bar and becomes the
# dock's first icon, Game Mode (gone from the image) leaves the dock, the
# Portal joins it. The desktop must be running: until it answers, the step
# fails and runs again at the next login.
js=$(cat /usr/share/arkadeos/dock-menu.js)
for _ in $(seq 30); do
    busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "${js}" \
        &>/dev/null && exit 0
    sleep 2
done
exit 1
