#!/usr/bin/bash
# Lenovo Legion and MSI laptops (T046, T047), in place of Legion Space /
# Lenovo Vantage and MSI Center:
# - LenovoLegionLinux: the legion-laptop driver (fan curves, modes, battery
#   care) built here against the image's kernel, so every kernel update brings
#   a matching one, and its app (legion_gui, legiond).
# - MControlCenter on the kernel's msi-ec driver.
# Both from their maintained COPRs; their packages list build tools as runtime
# needs, so the apps are installed with their real runtime parts only. Nothing
# runs unless that maker's parts are on (arkadeos-vendor).
set -euo pipefail

kver=$(ls /usr/lib/modules | head -1)
work=$(mktemp -d)
coprs=(francoism/lenovolegionlinux teackot/msi)
for c in "${coprs[@]}"; do dnf5 -y copr enable "${c}"; done
dnf5 -y download --arch x86_64 --destdir "${work}" dkms-LenovoLegionLinux python-LenovoLegionLinux mcontrolcenter
dnf5 -y install --setopt=install_weak_deps=False \
    python3-pyqt6 python3-pyyaml python3-argcomplete python3-pillow "python3dist(darkdetect)" inih qt6-qtbase-gui
rpm -i --nodeps "${work}"/python-LenovoLegionLinux-*.x86_64.rpm "${work}"/mcontrolcenter-*.x86_64.rpm

# The driver: built with the base's kernel-devel, signed with the ArkadeOS
# module key when the build has it (Secure Boot only loads signed drivers;
# the key is enrolled with the installer or when Legion parts are turned on).
(cd "${work}" && rpm2cpio dkms-LenovoLegionLinux-*.x86_64.rpm | cpio -idm --quiet)
src=$(ls -d "${work}"/usr/src/LenovoLegionLinux-*)
make -s -C "/usr/lib/modules/${kver}/build" M="${src}" modules
if [[ -s /run/secrets/mok ]]; then
    "/usr/lib/modules/${kver}/build/scripts/sign-file" sha256 /run/secrets/mok \
        /etc/pki/arkadeos/arkadeos-mok.der "${src}/legion-laptop.ko"
    modinfo -F signer "${src}/legion-laptop.ko"
else
    echo "::warning::legion-laptop not signed: no module key in this build"
fi
install -Dm0644 "${src}/legion-laptop.ko" "/usr/lib/modules/${kver}/extra/legion-laptop/legion-laptop.ko"
depmod -a "${kver}"

# Off until the maker is chosen: the driver does not load by itself, the
# services stay masked (vendor-set unmasks them).
echo "blacklist legion-laptop" > /usr/lib/modprobe.d/50-arkadeos-legion.conf
for unit in legiond.service legiond-onresume.service legiond-cpuset.timer legiond-cpuset.service; do
    systemctl mask "${unit}"
done

for c in "${coprs[@]}"; do
    dnf5 -y copr disable "${c}"
    rm -f "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${c%/*}:${c#*/}.repo"
done
rm -rf "${work}"
