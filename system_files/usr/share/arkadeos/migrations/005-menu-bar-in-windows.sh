# Roland, 2026-11-04: with the taskbar, apps show their menu (File, Edit...)
# in the window again; Ctrl+M hides it. Dolphin hides it on its first start,
# so it gets its first-start state (only the Places panel) with the menu on.
# Konsole keeps Bazzite's setting, no menu bar.
set_default dolphinrc MainWindow MenuBar Disabled Enabled
if [[ -z "$(kreadconfig6 --file "${cfg}/dolphinrc" --group General --key Version)" ]]; then
    kwriteconfig6 --file "${cfg}/dolphinrc" --group General --key Version 202
fi
state="${XDG_STATE_HOME:-${HOME}/.local/state}/dolphinstaterc"
if [[ ! -e "${state}" ]]; then
    mkdir -p "$(dirname "${state}")"
    cp /usr/share/arkadeos/dolphinstaterc "${state}"
fi
