# Roland, 2026-11-22: "az értesítéseknek kellene egy fix gomb a tálcán, mert
# így elvesznek, beleértve a claude is. (codex is)". The notifications bell
# stays on the tray (glass-tray.js adds it to the shown items unless the user
# hid it). Once the desktop has loaded its taskbar; glass-tray.js says "wait"
# while an older Plasma's inner tray is not there yet, then the step fails
# and runs again at the next login.
for _ in $(seq 15); do
    out=$(/usr/libexec/arkadeos/plasma-script /usr/share/arkadeos/glass-tray.js) && [[ "${out}" == *done* ]] && exit 0
    sleep 2
done
exit 1
