#!/usr/bin/bash
# Gaming layer (T003): scheduler and GameMode. Proton-GE is installed in its
# own image layer by proton-ge.sh.
set -euo pipefail

systemctl enable scx_loader.service

dnf5 -y install --setopt=install_weak_deps=False gamemode gamemode.i686
