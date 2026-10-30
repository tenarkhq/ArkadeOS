#!/usr/bin/bash
# Builds the ArkadeOS installer ISO (T022) from Fedora's network installer:
# our kickstart, ArkadeOS names in the boot menu and in the installer.
# Runs in a privileged Fedora container (lorax for mkksiso, which needs loop
# devices); PODMAN="sudo podman" where podman itself is not root.
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

podman run --rm -v "${work}:/work" -v "${cache}:/cache:ro" -v "$(dirname "${out}"):/out" \
    "registry.fedoraproject.org/fedora:${fedora}" bash -euo pipefail -c "
    dnf -y -q install lorax xorriso squashfs-tools cpio >/dev/null 2>&1
    cd /work
    # The installer calls itself ArkadeOS (.buildstamp in an updates image).
    bash buildstamp.sh /cache/${netinst} updates.img
    mkksiso --ks arkadeos.ks --updates updates.img ${ISO_CMDLINE:+-c \"${ISO_CMDLINE}\"} -V ArkadeOS \
        /cache/${netinst} /work/stage.iso
    # Boot menu: ArkadeOS instead of Fedora.
    xorriso -osirrox on -indev /work/stage.iso -extract /EFI/BOOT/grub.cfg grub.cfg >/dev/null 2>&1
    chmod u+w grub.cfg
    sed -i 's/Fedora 44/ArkadeOS/g; s/Fedora/ArkadeOS/g' grub.cfg
    grep -q 'Install ArkadeOS' grub.cfg
    if [ \"${ISO_AUTOBOOT:-}\" = 1 ]; then
        sed -i 's/^set default=.*/set default=\"0\"/; s/^set timeout=.*/set timeout=1/' grub.cfg
    fi
    xorriso -indev /work/stage.iso -outdev /out/$(basename "${out}") -boot_image any replay \
        -map grub.cfg /EFI/BOOT/grub.cfg >/dev/null 2>&1
"
ls -la "${out}"
