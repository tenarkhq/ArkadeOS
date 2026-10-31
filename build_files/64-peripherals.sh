#!/usr/bin/bash
# RGB and peripherals: OpenRGB for one lighting across devices (T042, monitor
# Aura T043, keyboards T044), DDC/CI monitor control (T043), gaming mice
# (Piper/libratbag, Solaar for Logitech receivers; T045), liquidctl for AIO
# coolers and CoolerControl fan curves on desktops (T052). Input Remapper
# (macros) comes with the base image.
set -euo pipefail

dnf5 -y install --setopt=install_weak_deps=False \
    openrgb piper libratbag-ratbagd solaar solaar-udev liquidctl
# ddcutil comes from the base image (Terra's build).
command -v ddcutil
rpm -q input-remapper

# Solaar's tray app starts only while a Logitech receiver is plugged in
# (90-arkadeos-solaar.rules -> arkadeos-solaar user service), not on every
# login (T050).
rm -f /etc/xdg/autostart/solaar.desktop

# T052: CoolerControl for fan curves and AIO coolers on desktops. Its daemon
# runs only on machines without a battery (arkadeos-desktop-setup), laptops
# keep their firmware's (or asusctl's) fan control.
dnf5 -y copr enable codifryed/CoolerControl
dnf5 -y install --setopt=install_weak_deps=False coolercontrol coolercontrold
dnf5 -y copr disable codifryed/CoolerControl
rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:codifryed:CoolerControl.repo
systemctl disable coolercontrold.service
test -f /usr/lib/systemd/system/coolercontrold.service
systemctl enable arkadeos-desktop-setup.service

# T049: firmware metadata from LVFS refreshed daily; users are told about
# updates (arkadeos-firmware check).
systemctl enable fwupd-refresh.timer
systemctl --global enable arkadeos-firmware-check.timer
