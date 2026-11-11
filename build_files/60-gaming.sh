#!/usr/bin/bash
# Gaming layer (T003): scheduler and GameMode. Proton-GE comes in as its own
# image layer, made by proton-ge.sh.
set -euo pipefail

systemctl enable scx_loader.service

# GE-Proton is there, under the label Wine's libraries need (proton-ge.sh),
# with its place where Steam and umu look for it.
for d in /usr/lib/wine/ge-proton/*; do
    [[ -x "${d}/proton" ]]
    matchpathcon "${d}/files/lib/wine/i386-windows/ntdll.dll" | grep -q textrel_shlib_t
    where=/usr/share/steam/compatibilitytools.d/$(basename "${d}")
    [[ -d "${where}" ]]
    [[ -L "/usr/lib/systemd/system/local-fs.target.wants/$(systemd-escape -p --suffix=mount "${where}")" ]]
done

# GameMode comes from packages/install.sh. No full-screen Steam session (Game
# Mode): Roland, 2026-11-03, the desktop is the only session.
rpm -q gamemode gamemode.i686 >/dev/null
! rpm -q gamescope-session-steam >/dev/null
