# Roland, 2026-11-13 (T086): the ArkadeOS Glass look. The ArkadeOS global
# theme (light or dark, as the user had it) is applied again, now with the
# glass frame, colours and Plasma style; the taskbar becomes the glass bar
# and the wallpaper Égkék where it was still ArkadeOS's default (both in
# glass-taskbar.js). Another global theme the user picked stays. Applying a
# theme turns the day/night switch off: it is put back as it was.
lnf=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)
auto=$(kreadconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel)
case "${lnf}" in
    org.arkadeos.light.desktop | org.arkadeos.dark.desktop)
        plasma-apply-lookandfeel -a "${lnf}" >/dev/null
        if [[ -n "${auto}" ]]; then
            kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel "${auto}"
        else
            kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --delete
        fi ;;
esac
# The desktop must be running: until it answers, the step fails and runs
# again at the next login.
js=$(cat /usr/share/arkadeos/glass-taskbar.js)
for _ in $(seq 30); do
    busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "${js}" \
        &>/dev/null && exit 0
    sleep 2
done
exit 1
