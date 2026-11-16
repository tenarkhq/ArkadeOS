# Roland, 2026-11-16: ArkadeOS Dark is the default, without the day/night
# switch („ez legyen a default. alapba nincs automata váltás sötét és világos
# között”, „sötét a default”). A user still on the old default (an ArkadeOS
# theme, the day/night switch on as the image had it) gets ArkadeOS Dark.
# Whoever turned the switch off keeps their look: picking a theme in System
# Settings turns it off too. Applying the theme writes the switch off into the
# user's file; that line goes again, so the image's default stays in charge.
# Before the desktop starts: in a running session Plasma's day/night switcher,
# started with the switch on, writes the line back (VM test, 2026-11-16), and
# the login would show the light look first.
cfg="${XDG_CONFIG_HOME:-${HOME}/.config}"
# The look the session would read: Plasma puts kdedefaults before /etc/xdg.
export XDG_CONFIG_DIRS="${cfg}/kdedefaults:${XDG_CONFIG_DIRS:-/etc/xdg}"
own=$(awk -F= '/^\[/ { kde = ($0 == "[KDE]") } kde && $1 == "AutomaticLookAndFeel" { v = $2 } END { print v }' "${cfg}/kdeglobals" 2>/dev/null || true)
[[ "${own}" == false ]] && exit 0
lnf=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)
case "${lnf}" in
    org.arkadeos.light.desktop | org.arkadeos.dark.desktop | "")
        QT_QPA_PLATFORM=offscreen plasma-apply-lookandfeel -a org.arkadeos.dark.desktop >/dev/null 2>&1 || exit 1
        # The line is taken out of the file: kwriteconfig6 --delete would
        # write AutomaticLookAndFeel[$d] instead, which hides the image's
        # value too (the key then reads empty, not false).
        sed -i '/^\[KDE\]$/,/^\[/{/^AutomaticLookAndFeel\(\[\$[a-z]\]\)\?\(=\|$\)/d}' "${cfg}/kdeglobals" ;;
esac
exit 0
