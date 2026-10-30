#!/usr/bin/bash
# Apps (T014-T018, T021): Battle.net and WowUp launchers, Flathub apps installed at
# first boot (arkadeos-apps), per-user setup at login (Steam shortcuts,
# microphone filter, dock stores).
set -euo pipefail

systemctl enable arkadeos-apps.service
systemctl --global enable arkadeos-session-setup.service arkadeos-session-setup.path
desktop-file-validate /usr/share/applications/org.arkadeos.BattleNet.desktop \
    /usr/share/applications/org.arkadeos.WowUp.desktop /usr/share/applications/org.arkadeos.AntiCheat.desktop
