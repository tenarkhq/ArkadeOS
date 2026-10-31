#!/usr/bin/bash
# Installs ArkadeOS from the ISO in a VM without any input, boots the
# installed system and checks it got the right image (T022).
# Usage: run.sh <iso> <root ssh private key> <out dir> <expected image>
set -euo pipefail

iso=$1 key=$2 out=$3 expect=$4
mkdir -p "${out}"
out=$(readlink -f "${out}")
qmp=${out}/qmp.sock
disk=${out}/disk.qcow2
qemu-img create -q -f qcow2 "${disk}" 60G
cp /usr/share/OVMF/OVMF_VARS_4M.fd "${out}/vars.fd"

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
# Types text on the VM keyboard (lower-case letters, digits, minus), then Enter.
type_line() {
    local keys="" c
    for (( i = 0; i < ${#1}; i++ )); do
        c=${1:i:1}
        [[ "${c}" == - ]] && c=minus
        keys+="{\"execute\":\"send-key\",\"arguments\":{\"keys\":[{\"type\":\"qcode\",\"data\":\"${c}\"}]}}"$'\n'
    done
    keys+='{"execute":"send-key","arguments":{"keys":[{"type":"qcode","data":"ret"}]}}'
    printf '%s\n%s\n' '{"execute":"qmp_capabilities"}' "${keys}" | socat - "UNIX-CONNECT:${qmp}" >/dev/null
}

step "installing from the ISO"
# -no-reboot: the installer's reboot ends this QEMU, the next one boots the disk.
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 8G -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file="${out}/vars.fd" \
    -drive file="${disk}",if=virtio,format=qcow2 \
    -cdrom "${iso}" -boot once=d -no-reboot \
    -device virtio-vga -display none -nic user,model=virtio-net-pci \
    -serial file:"${out}/install-serial.log" -qmp unix:"${qmp}",server,nowait \
    -pidfile "${out}/qemu.pid" &
qemu=$!
for i in $(seq 1 120); do
    sleep 30
    kill -0 "${qemu}" 2>/dev/null || break
    (( i % 4 == 0 )) && shot "install-$((i / 2))min"
done
if kill -0 "${qemu}" 2>/dev/null; then
    shot install-timeout
    kill "${qemu}"
    echo "FAILED install did not finish in 60 minutes" | tee "${out}/result.txt"
    exit 1
fi

step "booting the installed system"
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 8G -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file="${out}/vars.fd" \
    -drive file="${disk}",if=virtio,format=qcow2 \
    -device virtio-vga -display none \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 \
    -serial file:"${out}/serial.log" -qmp unix:"${qmp}",server,nowait \
    -daemonize -pidfile "${out}/qemu.pid"
# T024: the disk is encrypted; its password is typed at the boot screen.
ok=0 typed=0
for n in $(seq 150); do
    if ssh_vm true 2>/dev/null; then ok=$((ok + 1)); [[ ${ok} -ge 3 ]] && break; else ok=0; fi
    if [[ -n "${LUKS_PASSWORD:-}" && ${typed} -lt 3 && $((n % 6)) == 0 ]]; then
        shot "unlock-${n}"
        type_line "${LUKS_PASSWORD}"
        typed=$((typed + 1))
    fi
    sleep 5
done
ssh_vm "timeout 600 systemctl is-system-running --wait" || true
shot installed
failed=0
check() {
    local r="ok"
    ssh_vm "$2" >/dev/null 2>&1 || { r=FAILED; failed=1; }
    echo "${r} $1" | tee -a "${out}/result.txt"
}
ssh_vm 'bootc status; cat /etc/arkadeos/installed-image; findmnt -R /; lsblk -f' > "${out}/installed.txt" 2>&1 || true
check "installed and booted" 'grep -qx "PRETTY_NAME=\"ArkadeOS\"" /usr/lib/os-release'
check "right image for the graphics card (${expect})" "test \"\$(cat /etc/arkadeos/installed-image)\" = '${expect}'"
check "updates from the registry, signature checked" "bootc status --json | jq -e '.spec.image.image == \"${expect}\" and .spec.image.signature != null and .spec.image.signature != \"insecure\"'"
check "user account" 'id arkade && id -nG arkade | grep -qw wheel'
check "home on its own subvolume" 'btrfs subvolume show /var/home'
[[ -n "${LUKS_PASSWORD:-}" ]] && check "disk encrypted (LUKS)" 'lsblk -nro FSTYPE | grep -qx crypto_LUKS'
check "firewall on, ArkadeOS zone" 'firewall-cmd --state && test "$(firewall-cmd --get-default-zone)" = ArkadeOS'
ssh_vm 'journalctl -b --no-pager -p warning' > "${out}/journal-warnings.txt" 2>&1 || true
kill "$(cat "${out}/qemu.pid")" || true
cat "${out}/result.txt"
exit "${failed}"
