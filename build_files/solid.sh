#!/usr/bin/bash
# Rebuilds the base's own kf6-solid with ArkadeOS's patch (T069,
# patches/solid-composefs-root.patch): Dolphin showed "0 B free" for every
# folder. Runs in a throwaway build stage; only the built packages leave it.
#   solid.sh <out dir>
set -euo pipefail

out=$1 top=/tmp/rpm
patch=$(dirname "$(readlink -f "$0")")/patches/solid-composefs-root.patch
nevr=$(rpm -q --qf '%{VERSION}-%{RELEASE}' kf6-solid)
mkdir -p "${out}" "${top}/SOURCES"
dnf -y -q install rpm-build 'dnf5-command(builddep)' >/dev/null
cd /tmp
dnf -y -q download --source --enablerepo=fedora-source,updates-source "kf6-solid-${nevr}"
rpm -i --define "_topdir ${top}" "kf6-solid-${nevr}.src.rpm"
spec=${top}/SPECS/kf6-solid.spec
cp "${patch}" "${top}/SOURCES/"
# The patch goes after the spec's own sources; %autosetup applies every Patch.
grep -q '^%autosetup' "${spec}"
last=$(grep -n '^Source[0-9]*:' "${spec}" | tail -1 | cut -d: -f1)
sed -i "${last}a Patch9000: $(basename "${patch}")" "${spec}"
dnf -y -q builddep "${spec}" >/dev/null
# The release gets .arkadeos, so the package is newer than the base's own.
rpmbuild -bb --nocheck --quiet --define "_topdir ${top}" \
    --define "dist $(rpm -E %dist).arkadeos" "${spec}"
find "${top}/RPMS" -name "kf6-solid-${nevr%.*}*.rpm" ! -name '*debug*' ! -name '*devel*' -exec cp {} "${out}/" \;
ls "${out}"/kf6-solid-*.rpm
