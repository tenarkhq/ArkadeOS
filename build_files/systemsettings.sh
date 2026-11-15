#!/usr/bin/bash
# System Settings with the see-through sidebar of ArkadeOS Glass (T086,
# Roland, 2026-11-15: "hol az aero?"). Its sidebar is a Qt Quick view inside
# a widget window: the Darkly style makes the window see-through and KWin
# blurs behind it, but Qt draws such a view as a solid block unless the
# program asks otherwise, and the sidebar's pages paint a solid list colour.
# patches/systemsettings-glass-sidebar.patch changes both, so the sidebar
# shows the window's glass as Dolphin's does; the settings pages stay solid.
# Built from the base's own source package (the same version and Fedora
# patches as the installed one) in a throwaway stage; only the program
# leaves it, in the place of the package's own.
#   systemsettings.sh <out dir>
set -euo pipefail
source "$(dirname "$0")/stage.sh"

out=$1 top=/tmp/rpm
patch=$(dirname "$(readlink -f "$0")")/patches/systemsettings-glass-sidebar.patch
nevr=$(rpm -q --qf '%{VERSION}-%{RELEASE}' plasma-systemsettings)
mkdir -p "${top}/SOURCES"
dnf -y -q install rpm-build 'dnf5-command(builddep)' >/dev/null
cd /tmp
# Fedora's repositories keep only the newest update; the base may still have
# the one before it, whose source package stays in Fedora's build system.
src=plasma-systemsettings-${nevr}.src.rpm
dnf -y -q download --source --enablerepo=fedora-source,updates-source "plasma-systemsettings-${nevr}" 2>/dev/null || true
if [[ ! -f "${src}" ]]; then
    curl -fsSL --retry 3 -o "${src}" \
        "https://kojipkgs.fedoraproject.org/packages/plasma-systemsettings/${nevr%-*}/${nevr##*-}/src/${src}"
fi
[[ "$(rpm -K --nosignature "${src}")" == *"digests OK"* ]]
rpm -i --define "_topdir ${top}" "${src}"
spec=${top}/SPECS/plasma-systemsettings.spec
cp "${patch}" "${top}/SOURCES/"
# The patch goes after the spec's own sources; %autosetup applies every Patch.
grep -q '^%autosetup.*-p1' "${spec}"
last=$(grep -n '^Source[0-9]*:' "${spec}" | tail -1 | cut -d: -f1)
sed -i "${last}a Patch9000: $(basename "${patch}")" "${spec}"
dnf -y -q builddep "${spec}" >/dev/null
rpmbuild -bb --nocheck --quiet --define "_topdir ${top}" "${spec}"
built=$(find "${top}/RPMS" -name 'plasma-systemsettings-[0-9]*.rpm' ! -name '*debug*' | head -1)
mkdir -p /tmp/unpacked
(cd /tmp/unpacked && rpm2cpio "${built}" | cpio -idm --quiet ./usr/bin/systemsettings)
install -D -m 755 /tmp/unpacked/usr/bin/systemsettings "${out}/usr/bin/systemsettings"
# %autosetup applies the patch or fails the build; the program is a new one.
if cmp -s /usr/bin/systemsettings "${out}/usr/bin/systemsettings"; then exit 1; fi
settle
ls -la "${out}/usr/bin/systemsettings"
