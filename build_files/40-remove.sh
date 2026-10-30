#!/usr/bin/bash
# Removes the Bazzite parts ArkadeOS does not need (T002). Fails when the
# removal would take anything else with it, so a Bazzite update cannot
# silently remove more than this list.
set -euo pipefail

remove=(
    # Steam Deck parts of the desktop image
    jupiter-sd-mounting-btrfs
    steamdeck-kde-presets-desktop
    # Android container
    waydroid
    waydroid-selinux
    # ROM file previews
    rom-properties
    rom-properties-common
    rom-properties-kf6
    rom-properties-utils
    # Enterprise login (LDAP, Active Directory)
    sssd-client
    sssd-common
    sssd-kcm
    sssd-krb5-common
    sssd-nfs-idmap
    # Toolbox; Distrobox stays
    toolbox
    # Hyper-V and VMware guest tools
    hyperv-daemons
    hyperv-daemons-license
    hypervfcopyd
    hypervkvpd
    hypervvssd
    open-vm-tools
    open-vm-tools-desktop
)

installed=()
for pkg in "${remove[@]}"; do
    if rpm -q --quiet "${pkg}"; then
        installed+=("${pkg}")
    else
        echo "not in the base image: ${pkg}"
    fi
done
[[ ${#installed[@]} -gt 0 ]] || exit 0

rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/before
dnf5 -y remove --no-autoremove "${installed[@]}"
rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/after

printf '%s\n' "${installed[@]}" | sort -u > /tmp/wanted
extra=$(comm -23 /tmp/before /tmp/after | comm -23 - /tmp/wanted)
if [[ -n "${extra}" ]]; then
    echo "removal took packages outside the list:" >&2
    echo "${extra}" >&2
    exit 1
fi

# dnf leaves runtime state in /run, which bootc lint rejects.
rm -rf /run/dnf /run/selinux-policy
