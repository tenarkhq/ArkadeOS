#!/usr/bin/bash
# Gaming layer (T003): scheduler and GameMode. Proton-GE is installed in its
# own image layer by proton-ge.sh.
set -euo pipefail

systemctl enable scx_loader.service

# GameMode and the Steam Game Mode session come from packages/install.sh.
rpm -q gamemode gamemode.i686 gamescope-session gamescope-session-steam >/dev/null

# Steam Game Mode: a full-screen Steam session (Gamescope) that the "Game
# Mode" launcher switches to and Steam's "Switch to Desktop" leaves.
sed -i -e 's/^Name=.*/Name=Steam Game Mode/' -e 's/^Comment=.*/Comment=Full-screen Steam/' \
    /usr/share/wayland-sessions/gamescope-session-steam.desktop
