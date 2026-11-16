# Roland, 2026-11-16: ArkadeOS Dark is the default, without the day/night
# switch („ez legyen a default. alapba nincs automata váltás sötét és világos
# között”, „sötét a default”). A user still on the old default (an ArkadeOS
# theme, the day/night switch on as the image had it) gets ArkadeOS Dark.
# Whoever turned the switch off keeps their look: picking a theme in System
# Settings turns it off too. Applying the theme writes the switch off into the
# user's file; that line goes again, so the image's default stays in charge.
cfg="${XDG_CONFIG_HOME:-${HOME}/.config}/kdeglobals"
own=$(awk -F= '/^\[/ { kde = ($0 == "[KDE]") } kde && $1 == "AutomaticLookAndFeel" { v = $2 } END { print v }' "${cfg}" 2>/dev/null || true)
[[ "${own}" == false ]] && exit 0
lnf=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)
case "${lnf}" in
    org.arkadeos.light.desktop | org.arkadeos.dark.desktop | "")
        plasma-apply-lookandfeel -a org.arkadeos.dark.desktop >/dev/null || exit 1
        kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --delete ;;
esac
exit 0
