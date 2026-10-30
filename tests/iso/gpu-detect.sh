#!/usr/bin/bash
# The installer's graphics card check (T022) against made-up PCI devices: a VM
# cannot show an NVIDIA card, so the image choice is tested here.
set -euo pipefail

ks=$(dirname "$(readlink -f "$0")")/../../iso/arkadeos.ks
pre=$(mktemp -d)
trap 'rm -rf "${pre}"' EXIT
sed -n '/^%pre/,/^%end/p' "${ks}" | sed '1d;$d' | sed 's/@TAG@/stable/' > "${pre}/pre.sh"
failed=0

case_() {  # name, expected image, cmdline, then class:vendor pairs
    local name=$1 want=$2 cmdline=$3 root="${pre}/$1"
    shift 3
    mkdir -p "${root}/sys/bus/pci/devices"
    local n=0
    for dev in "$@"; do
        mkdir -p "${root}/sys/bus/pci/devices/0000:0${n}:00.0"
        echo "${dev%%:*}" > "${root}/sys/bus/pci/devices/0000:0${n}:00.0/class"
        echo "${dev##*:}" > "${root}/sys/bus/pci/devices/0000:0${n}:00.0/vendor"
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
# 1002 AMD, 8086 Intel, 1af4 virtio.
case_ nvidia-desktop ghcr.io/tenarkhq/arkadeos-nvidia:stable "" 0x030000:0x10de 0x020000:0x8086
case_ amd-desktop ghcr.io/tenarkhq/arkadeos:stable "" 0x030000:0x1002
case_ intel-igpu-nvidia-dgpu ghcr.io/tenarkhq/arkadeos-nvidia:stable "" 0x030000:0x8086 0x030200:0x10de
case_ amd-igpu-only-laptop ghcr.io/tenarkhq/arkadeos:stable "" 0x030000:0x1002 0x040300:0x1002
case_ nvidia-audio-only ghcr.io/tenarkhq/arkadeos:stable "" 0x030000:0x8086 0x040300:0x10de
case_ vm ghcr.io/tenarkhq/arkadeos:stable "" 0x030000:0x1af4
case_ testing-channel ghcr.io/tenarkhq/arkadeos:testing "quiet arkadeos.tag=testing" 0x030000:0x1002
case_ image-override ghcr.io/tenarkhq/arkadeos:stable "arkadeos.image=arkadeos" 0x030000:0x10de
exit "${failed}"
