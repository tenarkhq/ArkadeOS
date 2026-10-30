#!/usr/bin/bash
# Boots a qcow2 disk of an ArkadeOS image in QEMU and checks that it reaches
# the desktop and that the programs in apps.txt start (T004).
# Usage: run.sh <disk.qcow2> <ssh private key> <out dir>
set -euo pipefail

disk=$1 key=$2 out=$3
here=$(dirname "$(readlink -f "$0")")
mkdir -p "${out}"
qmp=${out}/qmp.sock

ssh_vm() {
    ssh -n -i "${key}" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o LogLevel=ERROR arkade@127.0.0.1 "$@"
}

shot() {
    printf '%s\n' '{"execute":"qmp_capabilities"}' \
        "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"${out}/$1.ppm\"}}" |
        socat - "UNIX-CONNECT:${qmp}" >/dev/null
    sleep 1
    convert "${out}/$1.ppm" "${out}/$1.png" && rm "${out}/$1.ppm"
}

step() { echo "$(date -u +%T) $*"; }

step "boot"
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 8G -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive file="${disk}",if=virtio,format=qcow2 \
    -device virtio-vga -display none \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 \
    -serial file:"${out}/serial.log" -qmp unix:"${qmp}",server,nowait \
    -daemonize -pidfile "${out}/qemu.pid"

step "waiting for ssh"
for _ in $(seq 120); do
    ssh_vm true 2>/dev/null && break
    sleep 5
done
ssh_vm true

step "waiting for boot to finish"
state=$(ssh_vm "timeout 600 systemctl is-system-running --wait" || true)
step "system state: ${state}"
ssh_vm 'systemctl --failed --no-legend --plain' | tee "${out}/failed-units.txt"
shot login

step "logging in to the desktop"
ssh_vm "echo arkade | sudo -S sh -c 'mkdir -p /etc/plasmalogin.conf.d && printf \"[Autologin]\nUser=arkade\nSession=plasma.desktop\n\" > /etc/plasmalogin.conf.d/zz-vm-test.conf && systemctl restart plasmalogin'" 2>/dev/null
for _ in $(seq 60); do
    ssh_vm 'pgrep -u arkade -x plasmashell' >/dev/null && break
    sleep 5
done
ssh_vm 'pgrep -u arkade -x plasmashell' >/dev/null || { shot desktop-missing; echo "plasmashell did not start" >&2; exit 1; }
sleep 20
shot desktop

session='export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus;'
failed=0
while read -r app; do
    [[ -z "${app}" || "${app}" == \#* ]] && continue
    step "starting ${app}"
    ssh_vm "${session} nohup ${app} >/tmp/${app%% *}.log 2>&1 & echo \$! > /tmp/${app%% *}.pid"
    sleep 15
    if ssh_vm "kill -0 \$(cat /tmp/${app%% *}.pid)"; then
        shot "app-${app%% *}"
        echo "ok ${app}" >> "${out}/apps.txt"
    else
        shot "app-${app%% *}-failed"
        ssh_vm "cat /tmp/${app%% *}.log" > "${out}/app-${app%% *}.log" || true
        echo "FAILED ${app}" >> "${out}/apps.txt"
        failed=1
    fi
done < "${here}/apps.txt"

ssh_vm 'journalctl -b --no-pager -p warning' > "${out}/journal-warnings.txt" || true
ssh_vm 'systemd-analyze; systemd-analyze blame | head -30; free -m' > "${out}/boot.txt" || true
kill "$(cat "${out}/qemu.pid")" || true

cat "${out}/apps.txt"
exit "${failed}"
