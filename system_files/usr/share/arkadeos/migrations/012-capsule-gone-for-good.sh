# Roland, 2026-11-15: after the update the capsule's place stayed on his
# taskbar as an error ("A kért komponens nem található: org.arkadeos.capsule";
# its package left the image with step 010). Plasma answers scripts before it
# has loaded its panels, and step 010, run right at login on his fast laptop,
# found no panel, removed nothing and counted as done. This step waits until
# the taskbar is loaded, then removes the capsule.
js='var bars = 0, removed = 0;
panels().forEach(function (p) {
    if (p.widgets("org.kde.plasma.icontasks").length > 0)
        bars++;
    p.widgets("org.arkadeos.capsule").forEach(function (w) { w.remove(); removed++ });
});
print("bars=" + bars + " removed=" + removed);'
for _ in $(seq 60); do
    out=$(busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "${js}" 2>/dev/null) &&
        [[ "${out}" == *bars=[1-9]* ]] && exit 0
    sleep 2
done
exit 1
