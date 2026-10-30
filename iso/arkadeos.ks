# ArkadeOS installer (T022): Fedora's network installer with this kickstart.
# The user picks language, disk (also "next to Windows", T023) and account as
# usual; the system itself is the ArkadeOS image that fits the graphics card,
# pulled from the registry:
#   NVIDIA card (also next to an Intel/AMD iGPU)  ->  arkadeos-nvidia
#   AMD or Intel only                              ->  arkadeos
# Boot options override it: arkadeos.image=<name>, arkadeos.tag=<tag>.

%pre --erroronfail --log=/tmp/arkadeos-pre.log
#!/bin/bash
tag=@TAG@
image=
for arg in $(cat "${ARKADEOS_CMDLINE:-/proc/cmdline}"); do
    case "${arg}" in
        arkadeos.tag=*) tag=${arg#*=} ;;
        arkadeos.image=*) image=${arg#*=} ;;
    esac
done
if [ -z "${image}" ]; then
    image=arkadeos
    for dev in "${ARKADEOS_SYSFS:-/sys}"/bus/pci/devices/*; do
        case "$(cat "${dev}/class")" in
            0x03*) [ "$(cat "${dev}/vendor")" = 0x10de ] && image=arkadeos-nvidia ;;
        esac
    done
fi
ref="ghcr.io/tenarkhq/${image}:${tag}"
echo "ArkadeOS image: ${ref}"
echo "${ref}" > "${ARKADEOS_TMP:-/tmp}/arkadeos-image"
# The installer pulls with Fedora's trust settings; the installed system
# checks ArkadeOS's signature from then on (bootc switch below).
echo "ostreecontainer --url=${ref} --transport=registry --no-signature-verification" > "${ARKADEOS_TMP:-/tmp}/arkadeos-image.ks"
%end

%include /tmp/arkadeos-image.ks

%post --nochroot --erroronfail --log=/mnt/sysimage/var/log/arkadeos-install.log
mkdir -p /mnt/sysimage/etc/arkadeos
cp /tmp/arkadeos-image /mnt/sysimage/etc/arkadeos/installed-image
%end

%post --erroronfail --log=/var/log/arkadeos-install-chroot.log
ref=$(cat /etc/arkadeos/installed-image)
# Updates come from the registry, with ArkadeOS's signature checked.
bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry "${ref}"
# Secure Boot: queue the key the drivers are signed with. At the first reboot
# a blue screen (MokManager) asks: Enroll MOK -> Continue -> Yes, password
# universalblue. arkadeos-secureboot reminds the user if it was skipped.
if mokutil --sb-state 2>/dev/null | grep -q enabled; then
    mokutil --timeout -1 || true
    printf 'universalblue\nuniversalblue\n' | mokutil --import /etc/pki/akmods/certs/akmods-ublue.der || true
fi
%end
