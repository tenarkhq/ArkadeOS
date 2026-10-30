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

# Presses keys together on the VM keyboard, e.g. key meta_l shift s.
key() {
    local keys
    keys=$(printf '{"type":"qcode","data":"%s"},' "$@")
    printf '%s\n' '{"execute":"qmp_capabilities"}' \
        "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[${keys%,}],\"hold-time\":${HOLD:-100}}}" |
        socat - "UNIX-CONNECT:${qmp}" >/dev/null
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

# T009: the boot screen, caught while the system starts.
for n in 1 2 3 4; do
    sleep 5
    shot "boot-${n}"
done

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
session="runuser -u arkade -- env XDG_RUNTIME_DIR=/run/user/${uid} WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 XDG_SESSION_TYPE=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus"
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

check() {
    if ssh_vm "$2" >/dev/null 2>&1; then
        echo "ok $1" >> "${out}/apps.txt"
    else
        echo "FAILED $1" >> "${out}/apps.txt"
        failed=1
    fi
}

step "look"
# T006: WhiteSur global theme applied at first login, day/night switch on.
home=/home/arkade/.config
check "WhiteSur global theme" "grep -qE '^org\.arkadeos\.(light|dark)\.desktop' ${home}/kdedefaults/package &&
    grep -qE '^ColorScheme=WhiteSur(Dark)?$' ${home}/kdedefaults/kdeglobals"
check "day/night switch on" "test \"\$(${session} kreadconfig6 --group KDE --key AutomaticLookAndFeel)\" = true"
check "Inter font" "fc-list : family | grep -qx Inter"
check "GTK WhiteSur" "grep -qx gtk-theme-name=WhiteSur-Light ${home}/gtk-3.0/settings.ini && test -f /usr/share/themes/WhiteSur-Light/gtk-3.0/gtk.css"
# T007: the first login built the bar and the dock from our layout.
check "top bar and dock" "f=${home}/plasma-org.kde.plasma.desktop-appletsrc &&
    for w in kickoff appmenu systemtray digitalclock kickerdash icontasks trash; do grep -qx plugin=org.kde.plasma.\$w \$f || exit 1; done"
# T009: ArkadeOS name, boot screen, wallpaper, launcher logo, lock screen.
check "ArkadeOS name" "grep -qx 'PRETTY_NAME=\"ArkadeOS\"' /usr/lib/os-release"
check "ArkadeOS boot screen" "plymouth-set-default-theme | grep -qx arkadeos && grep -qw splash /proc/cmdline"
check "Ark wallpaper and launcher logo" "f=${home}/plasma-org.kde.plasma.desktop-appletsrc &&
    grep -qx 'Image=file:///usr/share/wallpapers/ArkadeOS/' \$f && grep -qx icon=arkadeos-launcher \$f"
check "dark lock screen" "${session} kreadconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image | grep -q ArkadeOS-Lock"
# T010: Hungarian is complete, our own texts included.
check "Hungarian language" "rpm -q hunspell-hu && test -f /usr/share/locale/hu/LC_MESSAGES/dolphin.mo &&
    grep -q '^Name\\[hu\\]=' /usr/share/applications/org.arkadeos.GameMode.desktop &&
    grep -q 'xml:lang=\"hu\"' /usr/share/polkit-1/actions/org.arkadeos.session.policy &&
    grep -q 'Name\\[hu\\]' /usr/share/plasma/look-and-feel/org.arkadeos.light.desktop/metadata.json"
check "window buttons on the left" "test \"\$(${session} kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft)\" = XIA"
# Apps get the Plasma session variables, as when started from the menu.
# Both themes with Dolphin open in front: the day/night switch must restyle
# running apps, not only new ones. (System Settings is left out: Plasma does
# not restyle it on the fly.)
ssh_vm "pkill -u arkade -x konsole; pkill -u arkade -x systemsettings; pkill -u arkade -x dolphin" || true
ssh_vm "nohup ${session} dolphin >/dev/null 2>&1 &"
sleep 10
for variant in light dark; do
    ssh_vm "${session} plasma-apply-lookandfeel -a org.arkadeos.${variant}.desktop" > "${out}/look-${variant}.log" 2>&1 || true
    sleep 10
    shot "look-${variant}"
    ssh_vm "grep -A3 '^\\[Colors:Window\\]' ${home}/kdeglobals; cat ${home}/kdedefaults/kdeglobals" >> "${out}/look-${variant}.log" 2>&1 || true
done
check "dark theme applied" "grep -qx ColorScheme=WhiteSurDark ${home}/kdedefaults/kdeglobals &&
    grep -A3 '^\\[Colors:Window\\]' ${home}/kdeglobals | grep -qx BackgroundNormal=54,54,54"

# T010: the same Dolphin in Hungarian.
ssh_vm "pkill -u arkade -x dolphin" || true
ssh_vm "nohup ${session} LANG=hu_HU.UTF-8 LANGUAGE=hu dolphin >/dev/null 2>&1 &"
sleep 10
shot hungarian

step "windows keys"
# T008: the Windows shortcuts, pressed on the VM keyboard with Dolphin in front.
key meta_l up
sleep 3
shot win-up
check "Meta+Up maximises" "${session} kreadconfig6 --file kglobalshortcutsrc --group kwin --key 'Window Maximize' | grep -q '^Meta+Up'"
key meta_l down
sleep 3
key meta_l v
sleep 3
shot win-v
check "Meta+V clipboard" "${session} kreadconfig6 --file kglobalshortcutsrc --group plasmashell --key show-on-mouse-pos | grep -q '^Meta+V'"
key esc
HOLD=4000 key alt tab &
sleep 2
shot alt-tab
wait
sleep 2
key ctrl shift esc
sleep 10
shot ctrl-shift-esc
check "Ctrl+Shift+Esc System Monitor" 'pgrep -u arkade -f plasma-systemmonitor'
ssh_vm "pkill -u arkade -f plasma-systemmonitor" || true
key meta_l shift s
sleep 5
shot win-shift-s
check "Meta+Shift+S screenshot" 'pgrep -u arkade -x spectacle'
key esc
ssh_vm "pkill -u arkade -x spectacle" || true

step "gaming features"
check "scx_lavd scheduler running" 'grep -qx lavd /sys/kernel/sched_ext/root/ops || grep -q lavd /sys/kernel/sched_ext/root/ops'
check "NTSYNC device" 'test -c /dev/ntsync'
check "GameMode installed" 'command -v gamemoded'
check "GE-Proton for every user" 'ls -d /usr/share/steam/compatibilitytools.d/GE-Proton*/proton'
check "controller drivers" 'for m in xpad hid_playstation hid_nintendo xone_gip; do modinfo -F filename $m || exit 1; done'

step "running a Windows program with GE-Proton"
# umu-launcher is how ArkadeOS starts non-Steam games (Battle.net). The first
# run downloads the Steam Linux Runtime.
proton=$(ssh_vm 'ls -d /usr/share/steam/compatibilitytools.d/GE-Proton* | sort -V | tail -1')
ssh_vm "echo $(base64 -w0 "${here}/proton-test.bat") | base64 -d > /home/arkade/proton-test.bat && chown arkade: /home/arkade/proton-test.bat"
ssh_vm "cd /home/arkade && ${session} DISPLAY=:0 GAMEID=umu-default PROTONPATH=${proton} WINEPREFIX=/home/arkade/proton-test \
    timeout 900 umu-run /home/arkade/proton-test.bat" > "${out}/proton.log" 2>&1 || true
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
