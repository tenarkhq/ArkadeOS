#!/usr/bin/bash
# Gaming layer (T003): scheduler and GameMode. Proton-GE is installed in its
# own image layer by proton-ge.sh.
set -euo pipefail

systemctl enable scx_loader.service

# GameMode comes from packages/install.sh. No full-screen Steam session (Game
# Mode): Roland, 2026-11-03, the desktop is the only session.
rpm -q gamemode gamemode.i686 >/dev/null
! rpm -q gamescope-session-steam >/dev/null
