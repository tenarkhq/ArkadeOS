# Roland, 2026-11-04: KDE's Breeze look instead of WhiteSur, and one taskbar
# at the bottom instead of the top bar and the dock. The ArkadeOS global
# theme (light or dark, as the user had it) is applied again, now with
# Breeze in it; the panels are rebuilt with the user's own app icons. A new
# user already has all this, and the script leaves such a desktop alone.
# Applying a theme turns the day/night switch off: it is put back as it was.
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
set_default kwinrc org.kde.kdecoration2 ButtonsOnLeft XIA M
set_default kwinrc org.kde.kdecoration2 ButtonsOnRight "" IAX
for f in "${cfg}/gtk-3.0/settings.ini" "${cfg}/gtk-4.0/settings.ini"; do
    [[ -f "${f}" ]] && sed -i 's/^gtk-theme-name=WhiteSur-.*/gtk-theme-name=Breeze/' "${f}"
done
if [[ "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)" == "'WhiteSur-"* ]]; then
    gsettings set org.gnome.desktop.interface gtk-theme Breeze
    gsettings set org.gnome.desktop.interface icon-theme breeze
    gsettings set org.gnome.desktop.interface cursor-theme breeze_cursors
fi
# The desktop must be running: until it answers, the step fails and runs
# again at the next login.
js=$(cat /usr/share/arkadeos/taskbar.js)
for _ in $(seq 30); do
    busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "${js}" \
        &>/dev/null && exit 0
    sleep 2
done
exit 1
