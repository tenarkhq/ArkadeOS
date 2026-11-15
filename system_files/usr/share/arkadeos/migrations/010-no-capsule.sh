# Roland, 2026-11-14 (T086): "csak az ikonok ... ez a kényszeres kapszula sem
# kell". The glass capsule widget behind the tray, clock and show-desktop
# button leaves the taskbar; the icons stay where they are. Once the desktop
# has loaded its taskbar (plasma-script); until then the step fails and runs
# again at the next login. (Early step 001 takes the capsule out of the
# layout file before the desktop starts; this finds nothing left then.)
echo 'panels().forEach(function (p) { p.widgets("org.arkadeos.capsule").forEach(function (w) { w.remove() }) })' |
    /usr/libexec/arkadeos/plasma-script - >/dev/null
