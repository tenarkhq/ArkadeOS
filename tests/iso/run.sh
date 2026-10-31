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
# Presses one key on the VM keyboard (a QEMU key name: a, 1, minus, ret).
key() {
    printf '%s\n' '{"execute":"qmp_capabilities"}' \
        "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[{\"type\":\"qcode\",\"data\":\"$1\"}]}}" |
        socat - "UNIX-CONNECT:${qmp}" >/dev/null
}
# Types lower-case letters, digits and - on the VM keyboard, then Enter.
type_text() {
    local i c
    for ((i = 0; i < ${#1}; i++)); do
        c=${1:i:1}
        [[ "${c}" == - ]] && c=minus
        key "${c}"
    done
    key ret
}
step() { echo "$(date -u +%T) $*"; }

# T054: with RST=1 the installer also gets two blank SATA disks; the test
# kickstart (auto.ks) makes an Intel RST (IMSM) mirror on them before the
# installer looks at the disks, as the RST firmware would have. QEMU has no
# RST controller, so the test ISO boots with mdadm.imsm.test=1 (iso.yml).
rst=()
if [[ "${RST:-}" == 1 ]]; then
    for n in 0 1; do
        qemu-img create -q -f raw "${out}/rst${n}.raw" 4G
        rst+=(-drive "if=none,id=rst${n},format=raw,file=${out}/rst${n}.raw"
              -device "ide-hd,bus=ide.$((n + 4)),drive=rst${n},serial=ARKRST${n}")
    done
fi

step "installing from the ISO"
# -no-reboot: the installer's reboot ends this QEMU, the next one boots the disk.
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 8G -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file="${out}/vars.fd" \
    -drive file="${disk}",if=virtio,format=qcow2 \
    "${rst[@]}" -cdrom "${iso}" -boot once=d -no-reboot \
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
    -chardev socket,id=s0,path="${out}/serial.sock",server=on,wait=off,logfile="${out}/serial.log" \
    -serial chardev:s0 -qmp unix:"${qmp}",server,nowait \
    -daemonize -pidfile "${out}/qemu.pid"
# T024: the disk is encrypted; its password is given at the boot prompt.
ok=0 typed=0
for n in $(seq 150); do
    if ssh_vm true 2>/dev/null; then ok=$((ok + 1)); [[ ${ok} -ge 3 ]] && break; else ok=0; fi
    if [[ -n "${LUKS_PASSWORD:-}" && ${typed} -lt 3 && $((n % 6)) == 0 ]]; then
        # The boot screen asks for it, as on a real machine: typed on the keyboard.
        shot "unlock-${n}"
        type_text "${LUKS_PASSWORD}"
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
ssh_vm 'cat /proc/cmdline; bootc status; cat /etc/arkadeos/installed-image; findmnt -R /; lsblk -f; journalctl -b --no-pager | grep -i plymouth' > "${out}/installed.txt" 2>&1 || true
check "installed and booted" 'grep -qx "PRETTY_NAME=\"ArkadeOS\"" /usr/lib/os-release'
check "right image for the graphics card (${expect})" "test \"\$(cat /etc/arkadeos/installed-image)\" = '${expect}'"
check "updates from the registry, signature checked" "bootc status --json | jq -e '.spec.image.image == \"${expect}\" and .spec.image.signature != null and .spec.image.signature != \"insecure\"'"
check "user account" 'id arkade && id -nG arkade | grep -qw wheel'
check "home on its own subvolume" 'btrfs subvolume show /var/home'
[[ -n "${LUKS_PASSWORD:-}" ]] && check "disk encrypted (LUKS)" 'lsblk -nro FSTYPE | grep -qx crypto_LUKS'
check "boot screen arguments, as in the image" 'for a in $(grep ^kargs /usr/lib/bootc/kargs.d/10-arkadeos.toml | grep -o "[a-z0-9_.=-]*" | grep -vx -e kargs -e =);
    do grep -qw -- "$a" /proc/cmdline || exit 1; done'
check "starts to the login screen" 'test "$(systemctl get-default)" = graphical.target && systemctl is-active display-manager'
if [[ "${RST:-}" == 1 ]]; then
    ssh_vm 'cat /var/log/arkadeos-rst.txt' > "${out}/rst.txt" 2>&1 || true
    check "installer sees the Intel RST array" 'grep -q imsm /var/log/arkadeos-rst.txt &&
        grep -A3 "== installer storage" /var/log/arkadeos-rst.txt | grep -qi -E "volume0|md12[0-9]"'
fi
check "firewall on, ArkadeOS zone" 'firewall-cmd --state && test "$(firewall-cmd --get-default-zone)" = ArkadeOS'
ssh_vm 'journalctl -b --no-pager -p warning' > "${out}/journal-warnings.txt" 2>&1 || true
kill "$(cat "${out}/qemu.pid")" || true
cat "${out}/result.txt"
exit "${failed}"
