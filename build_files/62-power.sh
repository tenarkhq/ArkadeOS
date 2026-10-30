#!/usr/bin/bash
# Power profiles (T011): the profiles and helpers are files under
# system_files; this turns on the game watcher for every user.
set -euo pipefail

systemctl --global enable arkadeos-game-profile.service
systemctl is-enabled tuned.service tuned-ppd.service

# tuned-ppd refuses to start on a bad mapping (unknown or repeated profiles):
# load ppd.conf the way it does, against the installed TuneD profiles.
python3 - <<'PY'
import os
from tuned.ppd.config import PPDConfig

class Profiles:
    def profiles(self):
        dirs = ["/usr/lib/tuned/profiles", "/etc/tuned/profiles"]
        return [p for d in dirs if os.path.isdir(d) for p in os.listdir(d)]

PPDConfig("/etc/tuned/ppd.conf", Profiles())
print("ppd.conf ok")
PY
