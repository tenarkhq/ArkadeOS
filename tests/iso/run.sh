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
# T061: a software TPM 2.0, kept from the install to the installed system.
mkdir -p "${out}/tpm"
tpm=()
start_tpm() {
    swtpm socket --tpm2 --tpmstate dir="${out}/tpm" --ctrl type=unixio,path="${out}/tpm.sock" --daemon
    tpm=(-chardev socket,id=chrtpm,path="${out}/tpm.sock" -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-crb,tpmdev=tpm0)
}

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

# T054: with RST=1 the installer also gets two SATA disks with an Intel RST
# (IMSM) mirror on them, made by rst-disks.sh as the RST firmware would have,
# under the disk serials it names. QEMU has no RST controller, so the test ISO
# boots with mdadm.imsm.test=1 (iso.yml).
rst=()
if [[ "${RST:-}" == 1 ]]; then
    tests/iso/rst-disks.sh "${out}"
    for n in 0 1; do
        rst+=(-drive "if=none,id=rst${n},format=raw,file=${out}/rst${n}.raw"
              -device "ide-hd,bus=ide.$((n + 4)),drive=rst${n},serial=$(sed -n "$((n + 1))p" "${out}/rst-serials")")
    done
fi

step "installing from the ISO"
start_tpm
# -no-reboot: the installer's reboot ends this QEMU, the next one boots the disk.
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 8G -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file="${out}/vars.fd" \
    -drive file="${disk}",if=virtio,format=qcow2 \
    "${rst[@]}" "${tpm[@]}" -cdrom "${iso}" -boot once=d -no-reboot \
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
start_tpm
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 8G -machine q35 "${tpm[@]}" \
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
check "installer's nouveau.modeset=0 left behind" '! grep -qw nouveau.modeset=0 /proc/cmdline'
check "starts to the login screen" 'test "$(systemctl get-default)" = graphical.target && systemctl is-active display-manager'
# T026: the installer's app choice reached the system and is what gets installed.
check "installer's app choice saved" 'test "$(cat /etc/arkadeos/apps)" = "$(printf "firefox\nheroic\nqbittorrent")" &&
    test ! -s /etc/arkadeos/vendor && test -f /etc/arkadeos/apps-from-installer'
check "chosen apps installed, the rest not" 'for i in $(seq 90); do
        systemctl show -P ActiveState arkadeos-apps.service | grep -qx inactive && break; sleep 10; done
    flatpak info --system org.mozilla.firefox && flatpak info --system com.heroicgameslauncher.hgl &&
    flatpak info --system org.qbittorrent.qBittorrent && ! flatpak info --system com.google.Chrome'
if [[ "${RST:-}" == 1 ]]; then
    ssh_vm 'cat /etc/arkadeos-rst.txt' > "${out}/rst.txt" 2>&1 || true
    check "installer sees the Intel RST array" 'grep -q imsm /etc/arkadeos-rst.txt &&
        sed -n "/== installer storage/,/== now/p" /etc/arkadeos-rst.txt | grep -qi -E "Volume0|mdbiosraidarray"'
fi
# auto.ks asks for UTC on purpose: ArkadeOS keeps local time anyway.
check "hardware clock on local time" 'test "$(timedatectl show -p LocalRTC --value)" = yes'
check "firewall on, ArkadeOS zone" 'firewall-cmd --state && test "$(firewall-cmd --get-default-zone)" = ArkadeOS'
ssh_vm 'journalctl -b --no-pager -p warning' > "${out}/journal-warnings.txt" 2>&1 || true
# T061: once the disk password is given, the TPM opens the disk: the next
# boot reaches the system with no password typed.
if [[ -n "${LUKS_PASSWORD:-}" ]]; then
    check "disk set to open with the TPM" "echo '${LUKS_PASSWORD}' | /usr/libexec/arkadeos/tpm-unlock enroll &&
        test \"\$(/usr/libexec/arkadeos/tpm-unlock status)\" = on"
    ssh_vm 'systemctl reboot' || true
    sleep 30
    r=FAILED
    for n in $(seq 60); do
        if ssh_vm true 2>/dev/null; then r=ok; break; fi
        sleep 5
    done
    [[ "${r}" == ok ]] || { failed=1; shot tpm-boot; }
    echo "${r} disk opens with the TPM, no password typed" | tee -a "${out}/result.txt"
    check "the password still opens the disk too" "printf %s '${LUKS_PASSWORD}' | cryptsetup open --test-passphrase --key-file=- \
        \$(lsblk -nrpo NAME,FSTYPE | awk '\$2 == \"crypto_LUKS\" {print \$1; exit}')"
fi
kill "$(cat "${out}/qemu.pid")" || true
cat "${out}/result.txt"
exit "${failed}"
