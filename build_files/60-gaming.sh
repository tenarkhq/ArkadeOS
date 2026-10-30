#!/usr/bin/bash
# Gaming layer (T003): scheduler and GameMode. Proton-GE is installed in its
# own image layer by proton-ge.sh.
set -euo pipefail

systemctl enable scx_loader.service

dnf5 -y install --setopt=install_weak_deps=False gamemode gamemode.i686

# Steam Game Mode: a full-screen Steam session (Gamescope) that the "Game
# Mode" launcher switches to and Steam's "Switch to Desktop" leaves.
dnf5 -y install --enable-repo=terra --setopt=install_weak_deps=False \
    gamescope-session gamescope-session-steam
sed -i -e 's/^Name=.*/Name=Steam Game Mode/' -e 's/^Comment=.*/Comment=Full-screen Steam/' \
    /usr/share/wayland-sessions/gamescope-session-steam.desktop
