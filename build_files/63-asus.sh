#!/usr/bin/bash
# ASUS laptops (T013): asusctl (fan modes, charge limit, MUX, keyboard RGB)
# and ROG Control Center from the asus-linux COPR. asusd only starts on ASUS
# hardware (its udev rule). GPU switching stays with Bazzite's own tool.
set -euo pipefail

dnf5 -y copr enable lukenukem/asus-linux
dnf5 -y install --setopt=install_weak_deps=False asusctl asusctl-rog-gui
# The image brings updates, not dnf on the installed system.
dnf5 -y copr disable lukenukem/asus-linux
rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lukenukem:asus-linux.repo

systemctl enable arkadeos-asus-defaults.service
