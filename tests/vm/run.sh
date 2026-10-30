#!/usr/bin/bash
# Boots an installed disk of an ArkadeOS image in QEMU and checks that it reaches
# the desktop and that the programs in apps.txt start (T004).
# Usage: run.sh <raw disk> <root ssh private key> <out dir>
set -euo pipefail

disk=$1 key=$2 out=$3
here=$(dirname "$(readlink -f "$0")")
mkdir -p "${out}"
# QEMU runs detached from this folder, so it needs absolute paths.
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

step() { echo "$(date -u +%T) $*"; }

step "boot"
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 8G -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive file="${disk}",if=virtio,format=raw \
    -device virtio-vga -display none \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 \
    -serial file:"${out}/serial.log" -qmp unix:"${qmp}",server,nowait \
    -daemonize -pidfile "${out}/qemu.pid"

# SSH counts as up after three answers in a row: Bazzite's first-boot setup
# may still reboot the machine once.
wait_ssh() {
    local ok=0
    for _ in $(seq 150); do
        if ssh_vm true 2>/dev/null; then
            ok=$((ok + 1))
            [[ ${ok} -ge 3 ]] && return 0
        else
            ok=0
        fi
        sleep 5
    done
    echo "no SSH answer from the VM" >&2
    return 1
}

step "waiting for ssh"
wait_ssh

step "waiting for boot to finish"
state=$(ssh_vm "timeout 600 systemctl is-system-running --wait" || true)
step "system state: ${state}"
ssh_vm 'systemctl --failed --no-legend --plain' | tee "${out}/failed-units.txt"
shot login

step "logging in to the desktop"
# Test-only user with automatic login; the disk never leaves the test job.
ssh_vm 'useradd -m -G wheel arkade &&
    mkdir -p /etc/plasmalogin.conf.d &&
    printf "[Autologin]\nUser=arkade\nSession=plasma.desktop\n" > /etc/plasmalogin.conf.d/00-vm-test.conf &&
    systemctl restart plasmalogin'
for _ in $(seq 60); do
    ssh_vm 'pgrep -u arkade -x plasmashell' >/dev/null && break
    sleep 5
done
ssh_vm 'pgrep -u arkade -x plasmashell' >/dev/null || { shot desktop-missing; echo "plasmashell did not start" >&2; exit 1; }
sleep 20
shot desktop

uid=$(ssh_vm 'id -u arkade')
session="runuser -u arkade -- env XDG_RUNTIME_DIR=/run/user/${uid} WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus"
failed=0
while read -r app; do
    [[ -z "${app}" || "${app}" == \#* ]] && continue
    step "starting ${app}"
    ssh_vm "nohup ${session} ${app} >/tmp/${app%% *}.log 2>&1 & echo \$! > /tmp/${app%% *}.pid"
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

step "gaming features"
check() {
    if ssh_vm "$2" >/dev/null 2>&1; then
        echo "ok $1" >> "${out}/apps.txt"
    else
        echo "FAILED $1" >> "${out}/apps.txt"
        failed=1
    fi
}
check "scx_lavd scheduler running" 'grep -qx lavd /sys/kernel/sched_ext/root/ops || grep -q lavd /sys/kernel/sched_ext/root/ops'
check "NTSYNC device" 'test -c /dev/ntsync'
check "GameMode installed" 'command -v gamemoded'
check "GE-Proton for every user" 'ls -d /usr/share/steam/compatibilitytools.d/GE-Proton*/proton'
check "controller drivers" 'for m in xpad hid_playstation hid_nintendo xone_gip; do modinfo -F filename $m || exit 1; done'

step "running a Windows program with GE-Proton"
# umu-launcher is how ArkadeOS starts non-Steam games (Battle.net). The first
# run downloads the Steam Linux Runtime.
proton=$(ssh_vm 'ls -d /usr/share/steam/compatibilitytools.d/GE-Proton* | sort -V | tail -1')
ssh_vm "${session} DISPLAY=:0 GAMEID=umu-default PROTONPATH=${proton} WINEPREFIX=/home/arkade/proton-test \
    timeout 900 umu-run cmd /c 'echo ArkadeOS> C:\\proton-ok.txt'" > "${out}/proton.log" 2>&1 || true
shot proton
check "Windows program ran with GE-Proton" 'grep -q ArkadeOS /home/arkade/proton-test/drive_c/proton-ok.txt'

step "switching to Game Mode"
ssh_vm "PKEXEC_UID=${uid} /usr/libexec/arkadeos/session-select game"
sleep 45
shot game-mode
if ssh_vm 'pgrep -u arkade -x gamescope || pgrep -u arkade -f gamescope-wl' >/dev/null; then
    echo "ok game mode (gamescope running)" >> "${out}/apps.txt"
else
    # A VM has no GPU that Gamescope can drive; only the switch back is required.
    echo "info game mode: gamescope not running in the VM" >> "${out}/apps.txt"
fi

step "switching back to the desktop"
ssh_vm "PKEXEC_UID=${uid} /usr/libexec/arkadeos/session-select desktop"
for _ in $(seq 24); do
    sleep 5
    ssh_vm 'pgrep -u arkade -x plasmashell' >/dev/null && break
done
sleep 10
if ssh_vm 'pgrep -u arkade -x plasmashell' >/dev/null; then
    shot back-to-desktop
    echo "ok back to the desktop" >> "${out}/apps.txt"
else
    shot back-to-desktop-failed
    echo "FAILED back to the desktop" >> "${out}/apps.txt"
    failed=1
fi
ssh_vm 'test ! -e /etc/plasmalogin.conf.d/zz-arkadeos-session.conf' ||
    { echo "FAILED one-time login left behind" >> "${out}/apps.txt"; failed=1; }

ssh_vm 'journalctl -b --no-pager -p warning' > "${out}/journal-warnings.txt" || true
ssh_vm 'systemd-analyze; systemd-analyze blame | head -30; free -m' > "${out}/boot.txt" || true
kill "$(cat "${out}/qemu.pid")" || true

cat "${out}/apps.txt"
exit "${failed}"
