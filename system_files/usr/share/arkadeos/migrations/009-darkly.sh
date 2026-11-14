# Roland, 2026-11-14 (T086): the whole window is one glass, toolbar, menus
# and sidebar as much as the title bar ("nem homogén a UI ... legyen
# egységesen kezelve"). The Darkly style and the new window colours come with
# the ArkadeOS global theme, so it is applied again where the user still has
# it with ArkadeOS's earlier Breeze style. Another global theme or a style
# the user picked stays. Applying a theme turns the day/night switch off: it
# is put back as it was.
lnf=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)
case "${lnf}" in
    org.arkadeos.light.desktop | org.arkadeos.dark.desktop) ;;
    *) exit 0 ;;
esac
style=$(cat "${cfg}/kdeglobals" "${cfg}/kdedefaults/kdeglobals" 2>/dev/null | grep -m1 '^widgetStyle=' | cut -d= -f2)
[[ -z "${style}" || "${style}" == Breeze ]] || exit 0
auto=$(kreadconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel)
plasma-apply-lookandfeel -a "${lnf}" >/dev/null || exit 1
if [[ -n "${auto}" ]]; then
    kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel "${auto}"
else
    kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --delete
fi
# A Breeze the earlier theme wrote into the user's own file would still win.
set_default kdeglobals KDE widgetStyle Breeze Darkly
