#!/usr/bin/bash
# Makes an installer updates image whose .buildstamp names the product
# ArkadeOS, so the installer's screens say ArkadeOS, not Fedora.
#   buildstamp.sh <netinst.iso> <updates.img>
set -euo pipefail

iso=$1 out=$(readlink -f "$2")
tmp=$(mktemp -d)
xorriso -osirrox on -indev "${iso}" -extract /images/install.img "${tmp}/install.img" >/dev/null 2>&1
unsquashfs -q -no-xattrs -d "${tmp}/root" "${tmp}/install.img" .buildstamp
mkdir -p "${tmp}/upd"
sed -e 's/^Product=.*/Product=ArkadeOS/' -e 's/^IsFinal=.*/IsFinal=True/' \
    -e 's|^BugURL=.*|BugURL=https://github.com/tenarkhq/ArkadeOS/issues|' \
    "${tmp}/root/.buildstamp" > "${tmp}/upd/.buildstamp"
grep -q '^Product=ArkadeOS' "${tmp}/upd/.buildstamp"
(cd "${tmp}/upd" && find . | cpio -o -H newc --quiet | gzip -9) > "${out}"
rm -rf "${tmp}"
