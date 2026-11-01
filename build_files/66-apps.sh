#!/usr/bin/bash
# Apps (T014-T018, T021, T041): Battle.net and WowUp launchers, Flathub apps installed at
# first boot (arkadeos-apps), per-user setup at login (Steam shortcuts,
# microphone filter, dock stores).
set -euo pipefail

systemctl enable arkadeos-apps.service
systemctl --global enable arkadeos-session-setup.service arkadeos-session-setup.path
desktop-file-validate /usr/share/applications/org.arkadeos.BattleNet.desktop \
    /usr/share/applications/org.arkadeos.WowUp.desktop /usr/share/applications/org.arkadeos.AntiCheat.desktop \
    /usr/share/applications/org.arkadeos.WebApp.desktop /usr/share/applications/org.arkadeos.Tiling.desktop \
    /usr/share/applications/org.arkadeos.AirPlay.desktop /usr/share/applications/org.arkadeos.Portal.desktop \
    /etc/xdg/autostart/org.arkadeos.PortalFirstRun.desktop /usr/share/arkadeos/launchers/*.desktop

# T037: ArkadeOS Portal. Every catalog item has a known kind, and every app of
# the first-boot list is in the Portal too, so it can be removed there.
python3 -m py_compile /usr/bin/arkadeos-portal && rm -rf /usr/bin/__pycache__
awk -F'\t' '!/^#/ { if (NF != 6 || $3 !~ /^(flatpak|launcher|brew|switch|ujust|quadlet|script|fixed)$/ || seen[$1]++) { print "bad Portal item: " $0; bad = 1 } }
    END { exit bad }' /usr/share/arkadeos/portal/catalog.tsv
for id in $(grep -v '^#' /usr/share/arkadeos/apps.list | cut -d'|' -f1); do
    grep -q "^${id}"$'\t' /usr/share/arkadeos/portal/catalog.tsv
done

# T041: VLC opens videos (and its own formats); KDE's list points them at
# Haruna, which ArkadeOS does not install.
grep -q '^\[Default Applications\]' /etc/xdg/mimeapps.list
for mime in $(grep -oE '^video/[^=]+' /usr/share/applications/kde-mimeapps.list) \
    video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg video/ogg \
    video/x-flv video/x-ms-wmv video/mp2t application/x-matroska application/vnd.rn-realmedia; do
    grep -q "^${mime}=" /etc/xdg/mimeapps.list || echo "${mime}=org.videolan.VLC.desktop" >> /etc/xdg/mimeapps.list
done
grep -qx 'video/mp4=org.videolan.VLC.desktop' /etc/xdg/mimeapps.list
# Chrome opens web links, so a sign-in from an app lands in the browser the
# user is signed in to (Roland, 2026-11-01); Firefox stays installed.
for mime in x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml; do
    sed -i "/^${mime//\//\\/}=/d" /etc/xdg/mimeapps.list
    echo "${mime}=com.google.Chrome.desktop" >> /etc/xdg/mimeapps.list
done
grep -qx 'x-scheme-handler/https=com.google.Chrome.desktop' /etc/xdg/mimeapps.list
