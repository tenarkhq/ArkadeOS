# Roland, 2026-11-14 (T086): "csak az ikonok ... ez a kényszeres kapszula sem
# kell". The glass capsule widget behind the tray, clock and show-desktop
# button leaves the taskbar; the icons stay where they are. The desktop must
# be running: until it answers, the step fails and runs again at the next
# login.
js='panels().forEach(function (p) { p.widgets("org.arkadeos.capsule").forEach(function (w) { w.remove() }) })'
for _ in $(seq 30); do
    busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "${js}" &>/dev/null && exit 0
    sleep 2
done
exit 1
