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

# The profiles as TuneD puts them together with the ones they stand on: the
# performance profiles without the base's server memory values (T084),
# Balanced without its power saving (T058). A new TuneD or Bazzite profile
# that brings such a value back stops the build here.
python3 - <<'PY'
import tuned.consts as consts
import tuned.profiles as profiles
from tuned.profiles.variables import Variables
from tuned.utils.global_config import GlobalConfig

config = GlobalConfig()
dirs = config.get_list(consts.CFG_PROFILE_DIRS, consts.CFG_DEF_PROFILE_DIRS)
loader = profiles.Loader(profiles.Locator(dirs), profiles.Factory(), profiles.Merger(), config, Variables())

def options(profile, unit):
    return dict(loader.load([profile]).units[unit].options)

for name in ("arkadeos-gaming", "arkadeos-max", "arkadeos-wow"):
    assert "vm.swappiness" not in options(name, "sysctl"), name
    assert options(name, "vm") == {"transparent_hugepages": "always", "dirty_bytes": "268435456",
                                   "dirty_background_bytes": "67108864"}, name
assert options("arkadeos-balanced", "audio") == {"timeout": "0"}
assert options("arkadeos-balanced", "scsi_host") == {"alpm": "max_performance"}
print("profiles ok")
PY
