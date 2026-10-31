#!/usr/bin/bash
# The parts a user picks on the choice screen or later in the Portal (T019,
# T020, T035): each one is installed the way the Portal installs it and then
# has to work: OBS starts, Sunshine serves its page, Decky Loader runs, the
# Mac keyboard (Toshy) runs without layering packages, Ollama answers, Open
# WebUI serves its page, the command-line AI tools start.
# Usage: choices.sh <raw disk> <root ssh private key> <out dir>
set -euo pipefail

disk=$1 key=$2 out=$3
mkdir -p "${out}"
out=$(readlink -f "${out}")
qmp=${out}/qmp.sock

ssh_vm() {
    ssh -n -i "${key}" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o LogLevel=ERROR -o ServerAliveInterval=30 root@127.0.0.1 "$@"
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
key() {
    local keys
    keys=$(printf '{"type":"qcode","data":"%s"},' "$@")
    printf '%s\n' '{"execute":"qmp_capabilities"}' \
        "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[${keys%,}]}}" |
        socat - "UNIX-CONNECT:${qmp}" >/dev/null
}
step() { echo "$(date -u +%T) $*"; }
failed=0
check() {
    if ssh_vm "$2" >/dev/null 2>&1; then echo "ok $1" | tee -a "${out}/choices.txt"
    else echo "FAILED $1" | tee -a "${out}/choices.txt"; failed=1; fi
}
# Polls a check for up to $3 seconds: services take a while to come up.
check_wait() {
    local end=$(( $(date +%s) + $3 ))
    until ssh_vm "$2" >/dev/null 2>&1; do
        if (( $(date +%s) > end )); then echo "FAILED $1" | tee -a "${out}/choices.txt"; failed=1; return; fi
        sleep 10
    done
    echo "ok $1" | tee -a "${out}/choices.txt"
}

step "boot"
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 12G -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive file="${disk}",if=virtio,format=raw \
    -device virtio-vga -display none \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 \
    -serial file:"${out}/serial.log" -qmp unix:"${qmp}",server,nowait \
    -daemonize -pidfile "${out}/qemu.pid"
wait_ssh
ssh_vm "timeout 600 systemctl is-system-running --wait" || true

step "logging in to the desktop"
# Test-only user with automatic login, and sudo and polkit without a password
# in place of the password prompts the installers show; the disk never leaves
# the test job.
ssh_vm 'useradd -m -G wheel arkade &&
    echo "arkade ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/00-vm-test &&
    printf "polkit.addRule(function(action, subject) { if (subject.user == \"arkade\") return polkit.Result.YES; });\n" > /etc/polkit-1/rules.d/00-vm-test.rules &&
    mkdir -p /etc/plasmalogin.conf.d &&
    printf "[Autologin]\nUser=arkade\nSession=plasma.desktop\n" > /etc/plasmalogin.conf.d/00-vm-test.conf &&
    systemctl restart plasmalogin'
for _ in $(seq 60); do
    ssh_vm 'pgrep -u arkade -x plasmashell' >/dev/null && break
    sleep 5
done
ssh_vm 'pkill -u arkade -f "arkadeos-portal --first-run"' || true
uid=$(ssh_vm 'id -u arkade')
# The user's session without a display: the Portal then runs installers
# inline instead of in a terminal window. It starts in the user's home, as
# the Portal does.
user="runuser -u arkade -- env -C /home/arkade HOME=/home/arkade USER=arkade XDG_RUNTIME_DIR=/run/user/${uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus PATH=/home/arkade/.local/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin"
gui="runuser -u arkade -- env -C /home/arkade HOME=/home/arkade USER=arkade XDG_RUNTIME_DIR=/run/user/${uid} WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus"
portal="${user} /usr/libexec/arkadeos/portal-item"
install() {  # item, seconds; the log goes to the results
    step "installing $1"
    ssh_vm "yes | timeout $2 ${portal} $1 install" > "${out}/install-$1.log" 2>&1 || true
    ssh_vm "test \"\$(${portal} $1 status)\" = on" >/dev/null 2>&1 || echo "  $1: not on after install" | tee -a "${out}/choices.txt"
}
deployments() { ssh_vm 'rpm-ostree status --json | jq -c "[.deployments[] | .\"requested-packages\"] | add // []"'; }
layered_before=$(deployments)

# T020: streaming.
install obs 900
ssh_vm "${gui} sh -c 'flatpak run com.obsproject.Studio >/tmp/obs.log 2>&1 &'" || true
check_wait "OBS starts" 'pgrep -u arkade -x obs' 120
sleep 10
shot obs
ssh_vm 'pkill -u arkade -f com.obsproject.Studio' || true
install sunshine 900
# Sunshine asks once to share the screen (the desktop's own dialog); the
# user says yes.
sleep 20
shot sunshine-ask
key ret
sleep 5
shot sunshine-after
check_wait "Sunshine running, its page answers" "systemctl --user -M arkade@ is-active app-dev.lizardbyte.app.Sunshine &&
    curl -ks -o /dev/null https://127.0.0.1:47990/" 180
ssh_vm "${user} systemctl --user status --no-pager app-dev.lizardbyte.app.Sunshine; journalctl _UID=${uid} --no-pager | grep -i sunshine | tail -80; tail -80 /home/arkade/.var/app/dev.lizardbyte.app.Sunshine/config/sunshine/sunshine.log; ss -ltnp" > "${out}/sunshine.txt" 2>&1 || true

# T020: Mac keyboard.
install toshy 1500
check_wait "Mac keyboard (Toshy) running" "systemctl --user -M arkade@ is-active toshy-config.service" 120

# T035: Decky Loader.
install decky 900
check_wait "Decky Loader running" 'systemctl is-active plugin_loader.service' 120

# T035: another Proton version, put where ProtonPlus puts it, then picked for
# a store in its own window (the newly installed one is listed first: Home,
# Space to select, Enter). Steam lists the same folder in a game's
# Compatibility settings.
step "installing another Proton"
ssh_vm "${user} sh -c 'image=\$(basename /usr/share/steam/compatibilitytools.d/GE-Proton*) &&
    tag=\$(curl -fsSL \"https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases?per_page=5\" |
        jq -r --arg i \"\$image\" \"[.[] | select(.tag_name != \\\$i)][0].tag_name\") &&
    mkdir -p ~/.local/share/Steam/compatibilitytools.d &&
    curl -fsSL \"https://github.com/GloriousEggroll/proton-ge-custom/releases/download/\$tag/\$tag.tar.gz\" |
        tar -xz -C ~/.local/share/Steam/compatibilitytools.d && echo \$tag'" > "${out}/proton-install.log" 2>&1 || true
other=$(tail -1 "${out}/proton-install.log")
check "another Proton installed" "test -x /home/arkade/.local/share/Steam/compatibilitytools.d/${other}/proton"
ssh_vm "${gui} sh -c 'arkadeos-store ea --choose-proton >/tmp/choose.log 2>&1 &'" || true
sleep 8
shot proton-choose
key home; sleep 1; key spc; sleep 1; key ret
sleep 3
check "Proton picked for a store" "${user} arkadeos-store ea --check | grep -qx 'proton=/home/arkade/.local/share/Steam/compatibilitytools.d/${other}'"

# T019: the AI pack.
install ollama 1800
check "Ollama answers" "curl -fs http://127.0.0.1:11434/api/generate -d '{\"model\":\"qwen3:4b\",\"prompt\":\"Hi\",\"stream\":false,\"options\":{\"num_predict\":3}}' | jq -e .response"
ssh_vm "${user} systemctl --user status --no-pager ollama; ${user} podman ps -a; ${user} podman exec ollama ollama list; ${user} podman logs --tail 40 ollama" > "${out}/ollama.txt" 2>&1 || true
install open-webui 1200
check_wait "Open WebUI page answers" 'curl -fs -o /dev/null http://127.0.0.1:3000/' 600
shot open-webui
install claude-code 600
check "Claude Code starts" "${user} claude --version"
install codex 900
check "Codex starts" "${user} codex --version"
install gemini 900
check "Gemini CLI starts" "${user} gemini --version"
install gh 600
check "GitHub CLI starts" "${user} gh --version"

# Nothing above may layer packages on the system: updates stay image-only.
layered_after=$(deployments)
echo "layered before: ${layered_before} after: ${layered_after}" > "${out}/layered.txt"
check "no packages layered on the system" "test '${layered_after}' = '${layered_before}'"
ssh_vm 'systemctl --failed --no-legend --plain; systemctl --user -M arkade@ --failed --no-legend --plain' > "${out}/failed-units.txt" 2>&1 || true

kill "$(cat "${out}/qemu.pid")" || true
cat "${out}/choices.txt"
exit "${failed}"
