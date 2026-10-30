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
HOLD=6000 key alt tab &
sleep 1
shot alt-tab-1
sleep 2
shot alt-tab-2
wait
sleep 2
key ctrl shift esc
sleep 25
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
check "ASUS tools (start only on ASUS)" 'rpm -q asusctl asusctl-rog-gui && systemctl is-enabled arkadeos-asus-defaults.service'
check "controller drivers" 'for m in xpad hid_playstation hid_nintendo xone_gip; do modinfo -F filename $m || exit 1; done'

step "power profiles"
# T011: the standard switch drives our profiles, Max is set by hand.
ppd_set() {
    ssh_vm "busctl set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s $1"
    sleep 4
}
ppd_set power-saver
check "Akku profile" 'tuned-adm active | grep -q arkadeos-battery'
ppd_set balanced
check "Balanced profile" 'tuned-adm active | grep -q arkadeos-balanced'
ssh_vm /usr/libexec/arkadeos/power-set max || true
sleep 4
check "Max profile" 'tuned-adm active | grep -q arkadeos-max'
ssh_vm /usr/libexec/arkadeos/power-set balanced || true
sleep 4
check "back to Balanced" 'tuned-adm active | grep -q arkadeos-balanced && test ! -e /run/arkadeos/power-max'
# T012: the switch sits in the top bar and reads the profile.
check "power switch in the top bar" "grep -qx plugin=org.arkadeos.power ${home}/plasma-org.kde.plasma.desktop-appletsrc &&
    ${session} arkadeos-power status | grep -qx profile=balanced"
check "game watcher running" 'systemctl --user -M arkade@ is-active arkadeos-game-profile.service'
# Profile log while the Windows program below runs: Gaming must be held.
ssh_vm "nohup sh -c 'for i in \$(seq 400); do tuned-adm active; sleep 3; done' > /tmp/profiles.log 2>&1 &"

step "running a Windows program with GE-Proton"
# umu-launcher is how ArkadeOS starts non-Steam games (Battle.net). The first
# run downloads the Steam Linux Runtime.
proton=$(ssh_vm 'ls -d /usr/share/steam/compatibilitytools.d/GE-Proton* | sort -V | tail -1')
ssh_vm "echo $(base64 -w0 "${here}/proton-test.bat") | base64 -d > /home/arkade/proton-test.bat && chown arkade: /home/arkade/proton-test.bat"
ssh_vm "cd /home/arkade && ${session} DISPLAY=:0 GAMEID=umu-default PROTONPATH=${proton} WINEPREFIX=/home/arkade/proton-test \
    timeout 900 umu-run /home/arkade/proton-test.bat" > "${out}/proton.log" 2>&1 || true
shot proton
check "Windows program ran with GE-Proton" 'grep -q ArkadeOS /home/arkade/proton-test/drive_c/proton-ok.txt'
check "Gaming while a game runs" 'grep -q arkadeos-gaming /tmp/profiles.log'
sleep 20
check "Balanced after the game" 'tuned-adm active | grep -q arkadeos-balanced'
# T034: a second game set to Akku in its launch options (as in Steam:
# ARKADEOS_PROFILE=battery %command%) runs on Akku, then Balanced comes back.
ssh_vm "cd /home/arkade && ${session} DISPLAY=:0 ARKADEOS_PROFILE=battery GAMEID=umu-default PROTONPATH=${proton} \
    WINEPREFIX=/home/arkade/proton-test timeout 600 umu-run /home/arkade/proton-test.bat" >> "${out}/proton.log" 2>&1 || true
check "per-game profile: Akku game on Akku" 'grep -q arkadeos-battery /tmp/profiles.log'
sleep 20
check "Balanced after the Akku game" 'tuned-adm active | grep -q arkadeos-balanced'

step "apps"
# T014: Battle.net on the image's GE-Proton, its installer reachable, and in
# Steam Game Mode (a Steam account folder stands in for a Steam login).
check "Battle.net launcher on GE-Proton" "${session} arkadeos-battlenet --check | grep -q '^proton=.*GE-Proton'"
check "Battle.net installer reachable" "curl -fsSL -o /dev/null -r 0-0 \"\$(grep -o 'https://downloader[^\"]*' /usr/bin/arkadeos-battlenet)\""
ssh_vm "pkill -u arkade -x steam; sleep 5; runuser -u arkade -- mkdir -p /home/arkade/.local/share/Steam/userdata/1234/config &&
    systemctl --user -M arkade@ start arkadeos-session-setup.service" || true
check "Battle.net in Steam Game Mode" 'grep -qa arkadeos-battlenet /home/arkade/.local/share/Steam/userdata/1234/config/shortcuts.vdf'
check "Battle.net on the dock" "grep -q 'org.arkadeos.BattleNet.desktop' ${home}/plasma-org.kde.plasma.desktop-appletsrc"
# T015: WowUp downloads itself and starts, pointed at the Battle.net folder.
ssh_vm "nohup ${session} arkadeos-wowup > /tmp/wowup.log 2>&1 &"
for _ in $(seq 24); do
    sleep 5
    ssh_vm 'pgrep -u arkade -f WowUp.AppImage' >/dev/null && break
done
sleep 20
shot wowup
check "WowUp running" 'pgrep -u arkade -f WowUp.AppImage'
check "WowUp finds the Battle.net folder" "grep -q 'game_path: /home/arkade/Games' ${home}/lutris/system.yml"
# T016-T017: Flathub apps installed at first boot.
for _ in $(seq 90); do
    ssh_vm 'test "$(systemctl show -P ActiveState arkadeos-apps.service)" = inactive &&
        test "$(systemctl show -P Result arkadeos-apps.service)" = success' && break
    sleep 10
done
ssh_vm 'systemctl status --no-pager arkadeos-apps.service; journalctl -b -u arkadeos-apps --no-pager | tail -40' > "${out}/apps-install.txt" 2>&1 || true
for app in org.mozilla.firefox com.google.Chrome com.discordapp.Discord com.github.wwmm.easyeffects \
    org.videolan.VLC com.vysp3r.ProtonPlus; do
    check "${app} installed" "flatpak info --system ${app}"
done
for app in org.mozilla.firefox:firefox com.google.Chrome:chrome com.discordapp.Discord:discord; do
    ssh_vm "nohup ${session} flatpak run ${app%%:*} > /tmp/${app%%:*}.log 2>&1 &"
    sleep 25
    shot "app-${app#*:}"
    check "${app#*:} starts" "pgrep -u arkade -fi '/app/.*${app#*:}'"
done
sleep 10
check "microphone noise filter set up" "test -f ${home}/autostart/com.github.wwmm.easyeffects.desktop &&
    grep -q 'ArkadeOS mikrofon' /home/arkade/.var/app/com.github.wwmm.easyeffects/config/easyeffects/db/easyeffectsrc"
check "Easy Effects running" 'pgrep -u arkade -f easyeffects'
check "low-latency audio" "${session} pw-metadata -n settings | grep -q \"clock.quantum' value:'256'\""
# T041: VLC plays videos by default.
check "VLC opens videos" "test \"\$(${session} xdg-mime query default video/mp4)\" = org.videolan.VLC.desktop"
# T033: LACT GPU control daemon.
check "LACT running" 'rpm -q lact && systemctl is-active -q lactd.service'
# T038: auto-tiling off by default, on with the switch.
check "auto-tiling off by default" "test \"\$(${session} arkadeos-tiling status)\" = off"
ssh_vm "${session} arkadeos-tiling on; sleep 3; for i in 1 2; do nohup ${session} konsole >/dev/null 2>&1 & sleep 3; done; sleep 5" || true
shot tiling-on
check "auto-tiling on" "${session} busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting isScriptLoaded s polonium | grep -q true"
ssh_vm "${session} arkadeos-tiling off; pkill -u arkade -x konsole" || true
# T039: a website as an app on the dock.
ssh_vm "${session} arkadeos-webapp add 'ArkadeOS GitHub' https://github.com/tenarkhq/ArkadeOS" || true
check "web app in the menu and on the dock" "test -f /home/arkade/.local/share/applications/arkadeos-webapp-arkadeos-github.desktop && sleep 3 &&
    grep -q arkadeos-webapp-arkadeos-github.desktop ${home}/plasma-org.kde.plasma.desktop-appletsrc"
ssh_vm "nohup ${session} gtk-launch arkadeos-webapp-arkadeos-github > /tmp/webapp.log 2>&1 &"
sleep 20
shot webapp
check "web app starts" "pgrep -u arkade -f 'class=arkadeos-webapp-arkadeos-github'"
# T040: AirPlay receiver running, its ports open; AirPlay speakers module on.
check "AirPlay receiver" "systemctl --user -M arkade@ is-active -q arkadeos-airplay.service arkadeos-airplay-audio.service &&
    firewall-cmd --zone=ArkadeOS --query-service=arkadeos-airplay && rpm -q shairport-sync"
check "AirPlay speakers (PipeWire RAOP)" "${session} pw-cli ls Module | grep -q raop-discover"
# T021: anti-cheat answer with its source.
check "anti-cheat check" "${session} arkadeos-anticheat valorant | grep -q '✘ Valorant' &&
    ${session} arkadeos-anticheat 'world of warcraft' | grep -q 'areweanticheatyet.com'"
# T018: a store appears on the dock when installed, goes when removed.
ssh_vm "runuser -u arkade -- sh -c 'mkdir -p /home/arkade/.local/share/applications &&
    sed s/^Name=.*/Name=Heroic/ /usr/share/applications/steam.desktop > /home/arkade/.local/share/applications/com.heroicgameslauncher.hgl.desktop' &&
    systemctl --user -M arkade@ start arkadeos-session-setup.service && sleep 5" || true
check "installed store added to the dock" "grep -q com.heroicgameslauncher.hgl.desktop ${home}/plasma-org.kde.plasma.desktop-appletsrc"
shot dock-heroic
ssh_vm "rm /home/arkade/.local/share/applications/com.heroicgameslauncher.hgl.desktop &&
    systemctl --user -M arkade@ start arkadeos-session-setup.service && sleep 5" || true
check "removed store gone from the dock" "! grep -q 'launchers=.*com.heroicgameslauncher.hgl' ${home}/plasma-org.kde.plasma.desktop-appletsrc"

step "security"
# T024: firewall on with the ArkadeOS zone (no open port range), no telemetry.
check "firewall on, ArkadeOS zone" 'firewall-cmd --state | grep -qx running && test "$(firewall-cmd --get-default-zone)" = ArkadeOS &&
    test -z "$(firewall-cmd --zone=ArkadeOS --list-ports)"'
check "no telemetry" '! grep -l "^countme=1" /etc/yum.repos.d/*.repo && ! systemctl is-enabled -q rpm-ostree-countme.timer &&
    grep -q "toolkit.telemetry.enabled\", false" /var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/defaults/pref/02-arkadeos-privacy.js'

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
ssh_vm 'findmnt -R /; btrfs subvolume list /; btrfs subvolume show /var/home' > "${out}/disk-layout.txt" 2>&1 || true
ssh_vm 'systemd-analyze; systemd-analyze blame | head -30; free -m' > "${out}/boot.txt" || true

step "update and rollback"
# T025: the VM pulls an update (the same image plus a marker file) from the
# runner's registry, starts it at the reboot, then goes back to the previous
# version. The user's files stay through both.
reboot_vm() {
    ssh_vm 'systemctl reboot' || true
    sleep 40
    wait_ssh
    ssh_vm "timeout 600 systemctl is-system-running --wait" || true
}
check "daily updates on (system and apps)" 'systemctl is-enabled -q uupd.timer && systemctl is-active -q uupd.timer'
check "home snapshots" 'snapper -c home list | grep -q "ArkadeOS: first snapshot" &&
    btrfs subvolume show /home/arkade/Games'
if [[ -n "${UPDATE_PUSH:-}" ]]; then
    before=$(ssh_vm "bootc status --json | jq -r .status.booted.image.imageDigest")
    ssh_vm 'echo keep > /home/arkade/keep.txt'
    eval "${UPDATE_PUSH}"
    ssh_vm 'bootc upgrade' > "${out}/update.txt" 2>&1 || true
    check "update waits for the reboot" 'test "$(bootc status --json | jq -r .status.staged.image.imageDigest)" != null'
    reboot_vm
    ssh_vm 'arkadeos-update status' >> "${out}/update.txt" 2>&1 || true
    check "update running after the reboot" 'test -f /usr/share/arkadeos/update-test && test -f /home/arkade/keep.txt'
    ssh_vm 'arkadeos-update rollback --yes' >> "${out}/update.txt" 2>&1 || true
    reboot_vm
    ssh_vm 'arkadeos-update status' >> "${out}/update.txt" 2>&1 || true
    check "previous version back" "test ! -e /usr/share/arkadeos/update-test && test -f /home/arkade/keep.txt &&
        test \"\$(bootc status --json | jq -r .status.booted.image.imageDigest)\" = '${before}'"
    shot after-rollback
else
    echo "info update and rollback: no registry (UPDATE_PUSH unset)" >> "${out}/apps.txt"
fi
kill "$(cat "${out}/qemu.pid")" || true

cat "${out}/apps.txt"
exit "${failed}"
