#!/usr/bin/bash
# ASUS laptops (T013): asusctl (fan modes, charge limit, MUX, keyboard RGB)
# and ROG Control Center from the asus-linux COPR. asusd only starts on ASUS
# hardware (its udev rule). GPU switching stays with Bazzite's own tool.
set -euo pipefail

# The packages come from packages/install.sh.
rpm -q asusctl asusctl-rog-gui >/dev/null

systemctl enable arkadeos-asus-defaults.service arkadeos-vendor.service
