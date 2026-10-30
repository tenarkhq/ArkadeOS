#!/usr/bin/bash
# Power profiles (T011): the profiles and helpers are files under
# system_files; this turns on the game watcher for every user.
set -euo pipefail

systemctl --global enable arkadeos-game-profile.service
systemctl is-enabled tuned.service tuned-ppd.service
