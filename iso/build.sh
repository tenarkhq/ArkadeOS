#!/usr/bin/bash
# Builds the ArkadeOS installer ISO (T022) from Fedora's network installer:
# our kickstart, ArkadeOS names in the boot menu and in the installer.
# Runs in a Fedora container (lorax for mkksiso); no root and no loop devices:
# the EFI boot image is edited with mtools instead of being rebuilt.
#   iso/build.sh <out.iso> [tag] [extra kickstart prepended, for tests]
# ISO_CMDLINE adds boot options; ISO_AUTOBOOT=1 boots the install entry at
# once (tests).
set -euo pipefail

out=$(readlink -f "$1") tag=${2:-stable} extra=${3:-}
here=$(dirname "$(readlink -f "$0")")
fedora=44
netinst=Fedora-Everything-netinst-x86_64-44-1.7.iso
base=https://download.fedoraproject.org/pub/fedora/linux/releases/${fedora}/Everything/x86_64/iso
cache=${ISO_CACHE:-${HOME}/.cache/arkadeos-iso}
mkdir -p "${cache}"

if [[ ! -f "${cache}/${netinst}" ]]; then
    curl -fL --retry 3 -o "${cache}/${netinst}.part" "${base}/${netinst}"
    mv "${cache}/${netinst}.part" "${cache}/${netinst}"
fi
curl -fsSL --retry 3 -o "${cache}/CHECKSUM" "${base}/Fedora-Everything-${fedora}-1.7-x86_64-CHECKSUM"
(cd "${cache}" && grep "SHA256 (${netinst})" CHECKSUM | sha256sum -c -)

work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT
{
    [[ -n "${extra}" ]] && cat "${extra}"
    sed "s/@TAG@/${tag}/" "${here}/arkadeos.ks"
} > "${work}/arkadeos.ks"
cp "${here}/buildstamp.sh" "${work}/"

${PODMAN:-podman} run --rm -v "${work}:/work" -v "${cache}:/cache:ro" -v "$(dirname "${out}"):/out" \
    "registry.fedoraproject.org/fedora:${fedora}" bash -euo pipefail -c "
    dnf -y -q install lorax xorriso squashfs-tools cpio mtools >/dev/null 2>&1
    cd /work
    # The installer calls itself ArkadeOS (.buildstamp in an updates image).
    bash buildstamp.sh /cache/${netinst} updates.img
    mkdir -p /work/tmp
    mkksiso --tmp /work/tmp --skip-mkefiboot --ks arkadeos.ks --updates updates.img \
        ${ISO_CMDLINE:+-c \"${ISO_CMDLINE}\"} -V ArkadeOS /cache/${netinst} /work/stage.iso
    # Boot menus: ArkadeOS instead of Fedora (UEFI and BIOS).
    for cfg in EFI/BOOT/grub.cfg boot/grub2/grub.cfg; do
        mkdir -p \$(dirname \$cfg)
        xorriso -osirrox on -indev /work/stage.iso -extract /\$cfg \$cfg >/dev/null 2>&1 || continue
        chmod u+w \$cfg
        sed -i 's/Fedora 44/ArkadeOS/g; s/Fedora/ArkadeOS/g' \$cfg
        if [ \"${ISO_AUTOBOOT:-}\" = 1 ]; then
            sed -i 's/^set default=.*/set default=\"0\"/; s/^set timeout=.*/set timeout=1/' \$cfg
        fi
    done
    grep -q 'Install ArkadeOS' EFI/BOOT/grub.cfg
    grep -q 'inst.ks=' EFI/BOOT/grub.cfg
    # UEFI boots from the FAT image appended to the ISO (GPT partition 2),
    # which has its own copy of the menu.
    set -- \$(xorriso -indev /work/stage.iso -report_system_area plain 2>/dev/null |
        awk '/^GPT start and size : +2 / { print \$(NF-1), \$NF }')
    dd if=/work/stage.iso of=efi.img bs=512 skip=\$1 count=\$2 status=none
    mdir -i efi.img ::EFI/BOOT >/dev/null
    mcopy -o -i efi.img EFI/BOOT/grub.cfg ::EFI/BOOT/grub.cfg
    mtype -i efi.img ::EFI/BOOT/grub.cfg | grep -q 'Install ArkadeOS'
    maps=\"-map EFI/BOOT/grub.cfg /EFI/BOOT/grub.cfg\"
    [ -f boot/grub2/grub.cfg ] && maps=\"\$maps -map boot/grub2/grub.cfg /boot/grub2/grub.cfg\"
    xorriso -indev /work/stage.iso -outdev /out/$(basename "${out}") -boot_image any replay \
        -append_partition 2 0xef efi.img \$maps >/dev/null 2>&1
    # Whoever runs this can clean up the work folder afterwards (root podman too).
    chmod -R a+rwX /work
"
ls -la "${out}"
