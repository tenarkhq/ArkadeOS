#!/usr/bin/bash
# Keeps rarely used services installed but off (T002, T050).
set -euo pipefail

for unit in rpm-ostree-countme.timer flatpak-add-fedora-repos.service \
            cups.service cups.path cups-browsed.service ModemManager.service \
            raid-check.timer mdmonitor.service lvm2-monitor.service ds-inhibit.service; do
    systemctl disable "${unit}" || echo "not in the base image: ${unit}"
done
# ds-inhibit starts when a PlayStation controller is connected
# (90-arkadeos-ds-inhibit.rules).
udevadm verify /usr/lib/udev/rules.d/90-arkadeos-ds-inhibit.rules
systemctl enable cups.socket
# T080: machines on the old arkadeos-nvidia name follow arkadeos.
systemctl enable arkadeos-image-name.service

# KDE Connect: off until it is switched on in the ArkadeOS Portal.
kdeconnect=/etc/xdg/autostart/org.kde.kdeconnect.daemon.desktop
if [[ -f "${kdeconnect}" ]]; then
    sed -i -e '/^Hidden=/d' -e '/^\[Desktop Entry\]/a Hidden=true' "${kdeconnect}"
fi

# Xwayland Video Bridge no longer starts at every login: Discord and the
# browsers share the screen through Wayland's own way, and KDE has stopped
# working on the bridge. It stays installed (xwaylandvideobridge starts it).
bridge=/etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop
if [[ -f "${bridge}" ]]; then
    sed -i -e '/^Hidden=/d' -e '/^\[Desktop Entry\]/a Hidden=true' "${bridge}"
fi

# The key remapper (input-remapper) costs nothing for a user without presets
# (T050). Its udev rule starts a Python program for every keyboard, mouse and
# controller, at boot and whenever one is connected: now only while its
# service runs (/run/input-remapper, input-remapper.service.d). Its autostart
# entry asks for presets only where there are any (input-remapper-autoload).
rules=/usr/lib/udev/rules.d/99-input-remapper.rules
autoload=/etc/xdg/autostart/input-remapper-autoload.desktop
grep -q '^ACTION=="add", SUBSYSTEM=="input", .*, RUN+="/bin/input-remapper-control --command autoload' "${rules}"
sed -i 's|, RUN+="/bin/input-remapper-control --command autoload|, TEST=="/run/input-remapper"&|' "${rules}"
grep -q ', TEST=="/run/input-remapper", RUN+="/bin/input-remapper-control --command autoload' "${rules}"
udevadm verify "${rules}"
grep -q '^Exec=.*input-remapper-control --command autoload' "${autoload}"
sed -i 's|^Exec=.*|Exec=/usr/libexec/arkadeos/input-remapper-autoload|' "${autoload}"
systemctl is-enabled input-remapper.service
