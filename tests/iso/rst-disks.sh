#!/usr/bin/bash
# T054: two 4 GB test disks with an Intel RST (IMSM) mirror on them, as the
# RST firmware setup makes it, for the installer test (run.sh, RST=1).
#   tests/iso/rst-disks.sh OUT
# Writes OUT/rst0.raw, OUT/rst1.raw and OUT/rst-serials (the disk serials the
# RST data names; the VM's disks must carry the same ones).
# Made outside the installer: Fedora 44's mdadm 4.3 cannot make the first
# volume in a new RST container (it takes one disk only, then fails without a
# word); 4.4 and later can. Reading and assembling one works with 4.3.
# Needs sudo and docker (the GitHub runner).
set -euo pipefail
out=$1
mkdir -p "${out}"
truncate -s 4G "${out}/rst0.raw" "${out}/rst1.raw"
a=$(sudo losetup -f --show "${out}/rst0.raw")
b=$(sudo losetup -f --show "${out}/rst1.raw")
trap 'sudo losetup -d "${a}" "${b}" 2>/dev/null || true' EXIT
sudo modprobe raid1 || true
# No RST controller here: IMSM_NO_PLATFORM and IMSM_TEST_OROM stand in for
# one; loop disks have no serial, so their names serve as one.
sudo timeout 600 docker run --rm --privileged -v /dev:/dev -e A="${a}" -e B="${b}" \
    registry.fedoraproject.org/fedora:44 bash -euc '
    # mdadm 4.3 for its mdmon and run-time setup, 4.5 to make the volume.
    dnf -yq install mdadm gcc make systemd-devel git >/dev/null
    git clone -q --depth 1 -b mdadm-4.5 https://github.com/md-raid-utilities/mdadm /src 2>/dev/null
    make -s -C /src CWFLAGS="-Wall -Wno-error -fPIE" mdadm >/dev/null 2>&1
    mkdir -p /run/mdadm
    export IMSM_NO_PLATFORM=1 IMSM_TEST_OROM=1 MDADM_NO_SYSTEMCTL=1 IMSM_DEVNAME_AS_SERIAL=1
    m=/src/mdadm
    $m --create /dev/md/imsm0 --run -e imsm -n 2 "$A" "$B"
    $m --create /dev/md/Volume0 --run --assume-clean -l 1 -n 2 /dev/md/imsm0
    cat /proc/mdstat
    $m -E "$A" | grep -i serial
    $m -S /dev/md/Volume0
    $m -S /dev/md/imsm0' > "${out}/rst-disks.log"
# With IMSM_DEVNAME_AS_SERIAL the serials are the loop disks' names.
printf '%s\n' "${a}" "${b}" > "${out}/rst-serials"
cat "${out}/rst-serials"
