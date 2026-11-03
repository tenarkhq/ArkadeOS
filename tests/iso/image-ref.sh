#!/usr/bin/bash
# The image the installer pulls (T022): the one image for every graphics card
# (T080), the channel and the image from the boot options. Made-up PCI devices:
# a VM cannot show an NVIDIA card.
set -euo pipefail

ks=$(dirname "$(readlink -f "$0")")/../../iso/arkadeos.ks
pre=$(mktemp -d)
trap 'rm -rf "${pre}"' EXIT
sed -n '/^%pre.*arkadeos-pre.log/,/^%end/p' "${ks}" | sed '1d;$d' | sed 's/@TAG@/stable/' > "${pre}/pre.sh"
failed=0

case_() {  # name, expected image, cmdline, then class:vendor:device triples
    local name=$1 want=$2 cmdline=$3 root="${pre}/$1"
    shift 3
    mkdir -p "${root}/sys/bus/pci/devices"
    local n=0
    for dev in "$@"; do
        mkdir -p "${root}/sys/bus/pci/devices/0000:0${n}:00.0"
        IFS=: read -r class vendor device <<< "${dev}"
        echo "${class}" > "${root}/sys/bus/pci/devices/0000:0${n}:00.0/class"
        echo "${vendor}" > "${root}/sys/bus/pci/devices/0000:0${n}:00.0/vendor"
        echo "${device:-0x0001}" > "${root}/sys/bus/pci/devices/0000:0${n}:00.0/device"
        n=$((n + 1))
    done
    echo "${cmdline}" > "${root}/cmdline"
    ARKADEOS_SYSFS="${root}/sys" ARKADEOS_CMDLINE="${root}/cmdline" ARKADEOS_TMP="${root}" bash "${pre}/pre.sh" >/dev/null
    if [[ "$(cat "${root}/arkadeos-image")" == "${want}" ]] &&
        grep -q -- "--url=${want} " "${root}/arkadeos-image.ks"; then
        echo "ok ${name}"
    else
        echo "FAILED ${name}: got $(cat "${root}/arkadeos-image"), want ${want}"
        failed=1
    fi
}

# class 0x030000 VGA, 0x030200 3D controller (laptop dGPU); vendors: 10de NVIDIA,
# 1002 AMD, 8086 Intel. NVIDIA devices: 0x2684 RTX 4090, 0x2860 RTX 4070 laptop.
case_ nvidia-desktop ghcr.io/tenarkhq/arkadeos:stable "" 0x030000:0x10de:0x2684 0x020000:0x8086
case_ amd-desktop ghcr.io/tenarkhq/arkadeos:stable "" 0x030000:0x1002:0x744c
case_ intel-igpu-nvidia-dgpu ghcr.io/tenarkhq/arkadeos:stable "" 0x030000:0x8086:0x7d55 0x030200:0x10de:0x2860
case_ testing-channel ghcr.io/tenarkhq/arkadeos:testing "quiet arkadeos.tag=testing" 0x030000:0x1002:0x744c
case_ image-override ghcr.io/tenarkhq/arkadeos-nvidia:stable "arkadeos.image=arkadeos-nvidia" 0x030000:0x10de:0x2684
exit "${failed}"
