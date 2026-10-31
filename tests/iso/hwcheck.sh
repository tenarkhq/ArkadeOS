#!/usr/bin/bash
# The installer's hardware check (T053) against made-up machines: AMD RAID
# mode, an old NVIDIA card, a network chip without driver, Secure Boot,
# BitLocker. A VM shows none of these, so they are tested here.
set -euo pipefail

ks=$(dirname "$(readlink -f "$0")")/../../iso/arkadeos.ks
pre=$(mktemp -d)
trap 'rm -rf "${pre}"' EXIT
sed -n '/^%pre.*arkadeos-hwcheck.log/,/^%end/p' "${ks}" | sed '1d;$d' > "${pre}/check.sh"
failed=0

# name, expected exit code, text the output must have ("" = no findings),
# cmdline, extra (secureboot, notpm, bitlocker, faststartup), then class:vendor:device[:nodriver]
case_() {
    local name=$1 want_rc=$2 want=$3 cmdline=$4 extra=$5 root="${pre}/$1" n=0 rc=0
    shift 5
    mkdir -p "${root}/sys/bus/pci/devices" "${root}/sys/class/tpm/tpm0" "${root}/sys/firmware/efi/efivars"
    for dev in "$@"; do
        local d="${root}/sys/bus/pci/devices/0000:0${n}:00.0"
        mkdir -p "${d}"
        IFS=: read -r class vendor device nodriver <<< "${dev}"
        echo "${class}" > "${d}/class"; echo "${vendor}" > "${d}/vendor"; echo "${device:-0x0001}" > "${d}/device"
        [[ -n "${nodriver}" ]] || ln -s "${root}" "${d}/driver"
        n=$((n + 1))
    done
    [[ "${extra}" == *secureboot* ]] && printf '\x07\x00\x00\x00\x01' > "${root}/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"
    [[ "${extra}" == *notpm* ]] && rm -rf "${root}/sys/class/tpm/tpm0"
    if [[ "${extra}" == *bitlocker* ]]; then printf 'vfat\nBitLocker\nntfs\n' > "${root}/lsblk"; else printf 'vfat\nntfs\n' > "${root}/lsblk"; fi
    mkdir -p "${root}/ntfs/c"
    [[ "${extra}" == *faststartup* ]] && printf 'HIBR\0\0\0\0' > "${root}/ntfs/c/hiberfil.sys"
    [[ "${extra}" == *shutdown* ]] && printf '\0\0\0\0\0\0\0\0' > "${root}/ntfs/c/hiberfil.sys"
    echo "${cmdline}" > "${root}/cmdline"
    ARKADEOS_SYSFS="${root}/sys" ARKADEOS_CMDLINE="${root}/cmdline" ARKADEOS_TMP="${root}" ARKADEOS_LSBLK="${root}/lsblk" ARKADEOS_NTFS="${root}/ntfs" \
        bash "${pre}/check.sh" > "${root}/out" 2>&1 || rc=$?
    if [[ "${rc}" == "${want_rc}" ]] && { [[ -z "${want}" && ! -s "${root}/arkadeos-hwcheck.txt" ]] ||
        { [[ -n "${want}" ]] && grep -q -- "${want}" "${root}/out"; }; }; then
        echo "ok ${name}"
    else
        echo "FAILED ${name}: exit ${rc} (want ${want_rc}); output:"; cat "${root}/out"
        failed=1
    fi
}

# class 0x010400 RAID, 0x010601 AHCI, 0x028000 Wi-Fi, 0x020000 Ethernet;
# vendors 1022 AMD, 8086 Intel, 10de NVIDIA, 10ec Realtek, 14c3 MediaTek.
case_ clean 0 "" "" "" 0x010601:0x1022 0x030000:0x1002:0x744c 0x028000:0x8086:0x2725
case_ amd-raid-stops 1 "bcdedit /set {current} safeboot minimal" "" "" 0x010400:0x1022:0x7916 0x030000:0x1002:0x744c
case_ amd-raid-skip 0 "" "quiet arkadeos.hwcheck=off" "" 0x010400:0x1022:0x7916
case_ intel-rst-goes 0 "" "" "" 0x010400:0x8086:0xa77f 0x030000:0x8086:0xa7a0
case_ old-nvidia 0 "nouveau" "" "" 0x030000:0x10de:0x1b80
case_ unknown-wifi 0 "14c3:7927 hálózati chiphez még nincs driver" "" "" 0x028000:0x14c3:0x7927:nodriver
case_ secure-boot 0 "universalblue" "" secureboot 0x010601:0x8086
case_ no-tpm 0 "Nincs TPM" "" notpm 0x010601:0x8086
case_ bitlocker 0 "BitLocker" "" bitlocker 0x010601:0x8086
case_ windows-fast-startup 0 "Gyors rendszerindítás" "" faststartup 0x010601:0x8086
case_ windows-shut-down 0 "" "" shutdown 0x010601:0x8086
exit "${failed}"
