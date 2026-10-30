#!/usr/bin/bash
# Keeps rarely used services installed but off (T002, T050).
set -euo pipefail

for unit in rpm-ostree-countme.timer flatpak-add-fedora-repos.service \
            cups.service cups.path cups-browsed.service ModemManager.service; do
    systemctl disable "${unit}" || echo "not in the base image: ${unit}"
done
systemctl enable cups.socket

# KDE Connect: off until it is switched on in the ArkadeOS Portal.
kdeconnect=/etc/xdg/autostart/org.kde.kdeconnect.daemon.desktop
if [[ -f "${kdeconnect}" ]]; then
    sed -i -e '/^Hidden=/d' -e '/^\[Desktop Entry\]/a Hidden=true' "${kdeconnect}"
fi
