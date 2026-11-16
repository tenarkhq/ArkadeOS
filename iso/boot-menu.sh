#!/usr/bin/bash
# The installer ISO's boot menu (T022): ArkadeOS instead of Fedora, and the
# channel to install picked right there (Roland, 2026-11-16: "nem egyszerűbb
# majd egy iso amiben telepítéskor választható h melyik csatornát
# telepítse?"). The first entry installs the ISO's own channel; the entry
# after it installs the other one through the kickstart's arkadeos.tag boot
# option. A test ISO for one build gets no second entry.
#   boot-menu.sh <grub.cfg> <tag>
set -euo pipefail
cfg=$1 tag=$2
sed -i 's/Fedora 44/ArkadeOS/g; s/Fedora/ArkadeOS/g' "${cfg}"
case "${tag}" in
    stable) other=testing title="Install ArkadeOS - testing channel (newest builds)" ;;
    testing) other=stable title="Install ArkadeOS - stable channel" ;;
    *) exit 0 ;;
esac
awk -v other="${other}" -v title="${title}" '
    BEGIN { q = "\047"; name = q "Install ArkadeOS" q }
    !done && index($0, "menuentry " name) == 1 { inblock = 1 }
    inblock { block[++n] = $0 }
    { print }
    inblock && /^}/ {
        inblock = 0; done = 1
        for (i = 1; i <= n; i++) {
            line = block[i]
            if (i == 1) line = "menuentry " q title q substr(line, length("menuentry " name) + 1)
            else if (line ~ /^[ \t]*linux/) line = line " arkadeos.tag=" other
            print line
        }
    }' "${cfg}" > "${cfg}.new"
cat "${cfg}.new" > "${cfg}"
grep -q "arkadeos.tag=${other}" "${cfg}"
