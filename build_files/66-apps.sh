#!/usr/bin/bash
# Apps (T014-T018, T021, T041): Battle.net and WowUp launchers, Flathub apps installed at
# first boot (arkadeos-apps), per-user setup at login (Steam shortcuts,
# microphone filter, dock stores).
set -euo pipefail

systemctl enable arkadeos-apps.service
systemctl --global enable arkadeos-session-setup.service arkadeos-session-setup.path
desktop-file-validate /usr/share/applications/org.arkadeos.BattleNet.desktop \
    /usr/share/applications/org.arkadeos.WowUp.desktop /usr/share/applications/org.arkadeos.AntiCheat.desktop \
    /usr/share/applications/org.arkadeos.WebApp.desktop /usr/share/applications/org.arkadeos.Tiling.desktop

# T041: VLC opens videos (and its own formats); KDE's list points them at
# Haruna, which ArkadeOS does not install.
grep -q '^\[Default Applications\]' /etc/xdg/mimeapps.list
for mime in $(grep -oE '^video/[^=]+' /usr/share/applications/kde-mimeapps.list) \
    video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg video/ogg \
    video/x-flv video/x-ms-wmv video/mp2t application/x-matroska application/vnd.rn-realmedia; do
    grep -q "^${mime}=" /etc/xdg/mimeapps.list || echo "${mime}=org.videolan.VLC.desktop" >> /etc/xdg/mimeapps.list
done
grep -qx 'video/mp4=org.videolan.VLC.desktop' /etc/xdg/mimeapps.list
