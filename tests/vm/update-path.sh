#!/usr/bin/bash
# Update path (T051): a VM installed from the previous ArkadeOS build is used
# a little (a setting changed, a file saved), then updates to the new build
# without reinstalling. After the reboot it runs the new build, reaches the
# desktop, and the user's setting, file and apps are still there.
# Usage: update-path.sh <raw disk> <root ssh private key> <out dir> <push command>
set -euo pipefail

disk=$1 key=$2 out=$3 push=$4
mkdir -p "${out}"
out=$(readlink -f "${out}")
qmp=${out}/qmp.sock

ssh_vm() {
    ssh -n -i "${key}" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o LogLevel=ERROR root@127.0.0.1 "$@"
}
shot() {
    printf '%s\n' '{"execute":"qmp_capabilities"}' \
        "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"${out}/$1.ppm\"}}" |
        socat - "UNIX-CONNECT:${qmp}" >/dev/null
    sleep 1
    convert "${out}/$1.ppm" "${out}/$1.png" && rm "${out}/$1.ppm"
}
wait_ssh() {
    local ok=0
    for _ in $(seq 150); do
        if ssh_vm true 2>/dev/null; then ok=$((ok + 1)); [[ ${ok} -ge 3 ]] && return 0; else ok=0; fi
        sleep 5
    done
    echo "no SSH answer from the VM" >&2
    return 1
}
failed=0
check() {
    if ssh_vm "$2" >/dev/null 2>&1; then echo "ok $1" >> "${out}/update-path.txt"
    else echo "FAILED $1" >> "${out}/update-path.txt"; failed=1; fi
}
desktop() {
    for _ in $(seq 60); do
        ssh_vm 'pgrep -u arkade -x plasmashell' >/dev/null && return 0
        sleep 5
    done
    return 1
}

qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 8G -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive file="${disk}",if=virtio,format=raw \
    -device virtio-vga -display none \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 \
    -serial file:"${out}/serial.log" -qmp unix:"${qmp}",server,nowait \
    -daemonize -pidfile "${out}/qemu.pid"
wait_ssh
ssh_vm "timeout 600 systemctl is-system-running --wait" || true

# The previous build in use: a user with a changed setting and a file.
ssh_vm 'useradd -m -G wheel arkade &&
    mkdir -p /etc/plasmalogin.conf.d &&
    printf "[Autologin]\nUser=arkade\nSession=plasma.desktop\n" > /etc/plasmalogin.conf.d/00-vm-test.conf &&
    systemctl restart plasmalogin'
desktop || { shot old-desktop-missing; echo "FAILED desktop on the previous build" >> "${out}/update-path.txt"; exit 1; }
sleep 30
shot old-desktop
ssh_vm 'runuser -u arkade -- kwriteconfig6 --file kwinrc --group Windows --key FocusPolicy FocusFollowsMouse &&
    runuser -u arkade -- sh -c "echo keep > /home/arkade/keep.txt"'
before=$(ssh_vm "bootc status --json | jq -r .status.booted.image.imageDigest")
ssh_vm 'flatpak list --app --columns=application' | sort > "${out}/apps-before.txt" || true

# The update, the way a user gets it.
eval "${push}"
ssh_vm 'bootc upgrade' > "${out}/upgrade.txt" 2>&1 || true
ssh_vm 'systemctl reboot' || true
sleep 40
wait_ssh
ssh_vm "timeout 600 systemctl is-system-running --wait" || true
ssh_vm 'systemctl --failed --no-legend --plain' | tee "${out}/failed-units.txt"
desktop || shot new-desktop-missing
sleep 30
shot new-desktop
ssh_vm 'flatpak list --app --columns=application' | sort > "${out}/apps-after.txt" || true

check "runs the new build" "test \"\$(bootc status --json | jq -r .status.booted.image.imageDigest)\" != '${before}' &&
    test -f /usr/share/arkadeos/apps.list"
check "desktop starts" 'pgrep -u arkade -x plasmashell'
check "no failed services" 'test -z "$(systemctl --failed --no-legend --plain)"'
check "user setting kept" 'test "$(runuser -u arkade -- kreadconfig6 --file kwinrc --group Windows --key FocusPolicy)" = FocusFollowsMouse'
check "user file kept" 'test -f /home/arkade/keep.txt'
check "update steps ran for the user" 'test -d /home/arkade/.local/state/arkadeos/migrations'
check "previous build kept to go back to" 'test "$(bootc status --json | jq -r .status.rollback.image.imageDigest)" = '"'${before}'"
if ! cmp -s "${out}/apps-before.txt" "${out}/apps-after.txt"; then
    comm -23 "${out}/apps-before.txt" "${out}/apps-after.txt" | grep -q . &&
        { echo "FAILED apps kept: $(comm -23 "${out}/apps-before.txt" "${out}/apps-after.txt" | tr '\n' ' ')" >> "${out}/update-path.txt"; failed=1; }
fi
kill "$(cat "${out}/qemu.pid")" || true
cat "${out}/update-path.txt"
exit "${failed}"
