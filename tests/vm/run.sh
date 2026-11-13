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
        -o ConnectTimeout=5 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 \
        -o LogLevel=ERROR root@127.0.0.1 "$@"
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
# T023: a second disk with a Windows boot partition. Its boot loader stands
# in for Windows: a small EFI program that says so on the serial line.
truncate -s 64M "${out}/windows.img"
printf 'label: gpt\nstart=2048, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B\n' | sfdisk -q "${out}/windows.img"
mkfs.vfat -F 16 --offset 2048 "${out}/windows.img" >/dev/null
mmd -i "${out}/windows.img@@1M" ::EFI ::EFI/Microsoft ::EFI/Microsoft/Boot
printf '%s\n' 'serial --unit=0 --speed=115200' 'terminal_output serial console' \
    'echo ARKADEOS-TEST-WINDOWS-STARTED' 'sleep 600' > "${out}/fake-windows.cfg"
grub-mkstandalone -O x86_64-efi -o "${out}/bootmgfw.efi" \
    "boot/grub/grub.cfg=${out}/fake-windows.cfg"
mcopy -i "${out}/windows.img@@1M" "${out}/bootmgfw.efi" ::EFI/Microsoft/Boot/
qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 8G -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive file="${disk}",if=virtio,format=raw \
    -drive file="${out}/windows.img",if=virtio,format=raw \
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
# A VM that stops answering fails here, not at the job's time limit.
[[ -n "${state}" ]] || { shot boot-stuck; echo "the VM stopped answering while booting" >&2; exit 1; }
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
# The choice screen waits for the look to settle (at most 30 s), then shows.
for _ in $(seq 15); do
    ssh_vm 'pgrep -u arkade -f "arkadeos-portal --first-run"' >/dev/null && break
    sleep 2
done
sleep 5
# T026: the Portal opens by itself on the first login as the choice screen.
shot portal-first-run
if ssh_vm 'pgrep -u arkade -f "arkadeos-portal --first-run"' >/dev/null; then
    echo "ok Portal choice screen on the first login" >> "${out}/apps.txt"
else
    echo "FAILED Portal choice screen on the first login" >> "${out}/apps.txt"
fi
# The colours when the choice screen closes: the look must have been final
# when it opened (checked below). Read before and after it is closed: the
# automatic light/dark switch can fall between the two (2026-11-12, 20:10:
# the look changed a second after the first reading, and the check failed).
colours="cat /home/arkade/.config/kdeglobals /home/arkade/.config/kdedefaults/kdeglobals 2>/dev/null |
    sed -n 's/^ColorScheme=//p' | head -1"
ssh_vm "${colours} > /tmp/portal-closed-colours" || true
ssh_vm 'pkill -u arkade -f "arkadeos-portal --first-run"' || true
ssh_vm "${colours} >> /tmp/portal-closed-colours" || true
sleep 3
shot desktop

# T050: idle load of the fresh desktop, a minute after login: memory, CPU,
# running services and the heaviest processes, for comparison between runs;
# measured on the VM that runs the look (one is enough).
if [[ ",${TEST_GROUPS:-all}," == *,all,* || ",${TEST_GROUPS}," == *,look,* ]]; then
sleep 40
ssh_vm 'echo "== memory (MiB)"; free -m; echo "== load"; cat /proc/loadavg; echo "== CPU over 10 s"; vmstat 10 2 | tail -1
    echo "== running system services"; systemctl list-units --type=service --state=running --no-legend --plain | cut -d" " -f1
    echo "== running user services"; systemctl --user -M arkade@ list-units --type=service --state=running --no-legend --plain | cut -d" " -f1
    echo "== top memory"; ps -eo rss,comm --sort=-rss | head -15' > "${out}/idle.txt" 2>&1 || true
fi
uid=$(ssh_vm 'id -u arkade')
# The session's own Wayland socket: its name is the compositor's choice, read
# from the desktop's environment. What the session has goes to the results.
wayland=$(ssh_vm "grep -z ^WAYLAND_DISPLAY= /proc/\$(pgrep -u arkade -x plasmashell | head -1)/environ | tr -d '\\0' | cut -d= -f2" || true)
ssh_vm "echo '== runtime folder'; ls -la /run/user/${uid}/; echo '== listening sockets'; ss -xlpn | grep -E 'wayland|X11|kwin' ;
    echo '== desktop environment'; tr '\\0' '\\n' < /proc/\$(pgrep -u arkade -x plasmashell | head -1)/environ | grep -E '^(WAYLAND|DISPLAY|XAUTH|XDG_|QT_|KDE_|DESKTOP)' | sort;
    echo '== compositors'; ps -eo user:12,pid,lstart,args | grep -E '[k]win_wayland|[X]wayland|[p]lasmalogin|[s]tartplasma' | cut -c1-220;
    echo '== sessions'; loginctl list-sessions --no-legend" > "${out}/session-env.txt" 2>&1 || true
session="runuser -u arkade -- env HOME=/home/arkade USER=arkade XDG_RUNTIME_DIR=/run/user/${uid} WAYLAND_DISPLAY=${wayland:-wayland-0} QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 XDG_SESSION_TYPE=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus"
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
        ssh_vm "cat /tmp/${app%% *}.log; echo '== journal'; journalctl -b --no-pager -n 30 _COMM=${app%% *};
            echo '== core dump'; coredumpctl --no-pager info ${app%% *} 2>&1 | head -70" > "${out}/app-${app%% *}.log" 2>&1 || true
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

# The Portal choice screen follows the automatic light/dark look: the last
# colours it showed are the desktop's when it closed (either reading).
check "Portal choice screen shows the desktop's look" "last=\$(${session} journalctl --user -b --no-pager |
    grep -oE 'arkadeos-portal: shows the colours .*' | tail -1) &&
    sed 's/^/arkadeos-portal: shows the colours /' /tmp/portal-closed-colours | grep -qxF \"\${last}\""
# One image for every graphics card (T080): without an NVIDIA card (the VM)
# the NVIDIA services and the settings loader at login are masked, none failed.
check "no NVIDIA service without an NVIDIA card" "! systemctl --failed --no-legend --plain | grep -qi nvidia &&
    for u in nvidia-cdi-refresh.path nvidia-cdi-refresh.service nvidia-powerd.service ublue-nvidia-flatpak-runtime-sync.service; do
        test \"\$(systemctl show -p LoadState --value \$u)\" = masked || exit 1; done &&
    test \"\$(${session} systemctl --user show -p LoadState --value 'app-nvidia\\x2dsettings\\x2dload@autostart.service')\" = masked"
# What switched the look at the first login, for comparing runs.
ssh_vm "${session} journalctl --user -b --no-pager | grep -E 'arkadeos-portal:|plasma-apply-lookandfeel|knighttime|lookandfeel'" > "${out}/look-journal.txt" 2>&1 || true

# The parts after the desktop run on their own: TEST_GROUPS lists the ones to
# run (look, keys, power, games, apps, update), "all" (the default)
# runs every one. A push runs the parts its changes reach (groups.sh), the
# nightly build all of them.
want() {
    [[ ",${TEST_GROUPS:-all}," == *,all,* || ",${TEST_GROUPS}," == *",$1,"* ]] && return 0
    echo "info skipped: $1 (not reached by the changes)" >> "${out}/apps.txt"
    return 1
}
home=/home/arkade/.config
# The look's settings are in the session's own settings folder (kdedefaults),
# which only the session's programs see: commands that need them run with
# plasmashell's XDG_CONFIG_DIRS.
plasma_dirs="\$(grep -z ^XDG_CONFIG_DIRS= /proc/\$(pgrep -u arkade -x plasmashell)/environ | tr -d '\\0')"
# No idle lock during the test (the lock screen itself is checked in look).
ssh_vm "${session} kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false" || true

if want draft; then
step "draft: Better Blur DX pictures"
# Work branch only (Roland, 2026-11-13: "nézzük meg a bett blurt"): the
# desktop as it is, then with Better Blur DX (built into the test image by
# the workflow), light and dark.
for f in draft.sh scheme.py kwinrulesrc ArkadeGlass.colorscheme Glass.profile; do
    ssh_vm "mkdir -p /tmp/draft && echo $(base64 -w0 "${here}/draft/${f}") | base64 -d > /tmp/draft/${f} && chown -R arkade: /tmp/draft"
done
draft() { ssh_vm "${session} bash /tmp/draft/draft.sh $*" >> "${out}/draft.log" 2>&1 || true; }
awake() {
    key shift
    sleep 1
    ssh_vm "loginctl unlock-sessions; ${session} kscreen-doctor --dpms on" >/dev/null 2>&1 || true
}
ssh_vm "nohup ${session} kde-inhibit --power --screenSaver sleep 3000 > /dev/null 2>&1 &"
ssh_vm "ls -la /usr/lib64/qt6/plugins/kwin/effects/plugins/ | grep -i blur" >> "${out}/draft.log" 2>&1 || true
draft setup
for theme in light dark; do
    draft look ${theme}
    draft apps
    awake
    shot draft-now-${theme}
done
for theme in dark light; do
    draft look ${theme}
    draft blur ${theme}
    draft apps
    awake
    shot draft-blur-${theme}
done
# The app menu over the windows.
ssh_vm "${session} busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell activateLauncherMenu" >> "${out}/draft.log" 2>&1 || true
sleep 4
shot draft-blur-light-menu
key esc
ssh_vm "${session} busctl --user call org.kde.KWin /KWin org.kde.KWin supportInformation" > "${out}/draft-kwin.txt" 2>&1 || true
fi # draft

if want look; then
step "look"
# T006: the ArkadeOS global theme, Breeze inside (Roland, 2026-11-04), applied
# at first login, day/night switch on; WhiteSur gone.
check "Breeze in the ArkadeOS global theme" "grep -qE '^org\.arkadeos\.(light|dark)\.desktop' ${home}/kdedefaults/package &&
    grep -qE '^ColorScheme=Breeze(Light|Dark)$' ${home}/kdedefaults/kdeglobals &&
    grep -qx widgetStyle=Breeze ${home}/kdedefaults/kdeglobals &&
    ! ls -d /usr/share/icons/WhiteSur* /usr/share/themes/WhiteSur* /usr/share/plasma/desktoptheme/WhiteSur* 2>/dev/null"
check "day/night switch on" "test \"\$(${session} kreadconfig6 --group KDE --key AutomaticLookAndFeel)\" = true"
check "Inter font" "fc-list : family | grep -qx Inter"
check "GTK Breeze" "test \"\$(${session} gsettings get org.gnome.desktop.interface gtk-theme)\" = \"'Breeze'\" &&
    test -f /usr/share/themes/Breeze/gtk-3.0/gtk.css"
# T007: the first login built the taskbar from our layout (Roland,
# 2026-11-04): the ArkadeOS menu first, the Portal among the apps.
taskbar=$(base64 -w0 "$(dirname "$0")/taskbar.py")
check "one taskbar, ArkadeOS menu first, Portal on it" "echo ${taskbar} | base64 -d | python3 - ${home}/plasma-org.kde.plasma.desktop-appletsrc"
# T009: ArkadeOS name, boot screen, wallpaper, launcher logo, lock screen.
check "ArkadeOS name" "grep -qx 'PRETTY_NAME=\"ArkadeOS\"' /usr/lib/os-release"
check "ArkadeOS version: the Fedora it is built on, then the build" '. /usr/lib/os-release; [[ "${VERSION}" =~ ^${VERSION_ID}\.[0-9]{8}(\.[0-9]+)?$ ]]'
check "boot menu entry named ArkadeOS (system-release)" 'grep -qx "ArkadeOS release [0-9]*" /etc/system-release'
check "ArkadeOS boot screen" "plymouth-set-default-theme | grep -qx arkadeos && grep -qw splash /proc/cmdline"
check "Ark wallpaper and launcher logo" "f=${home}/plasma-org.kde.plasma.desktop-appletsrc &&
    grep -qx 'Image=file:///usr/share/wallpapers/ArkadeOS/' \$f && grep -qx icon=arkadeos-launcher \$f"
check "dark lock screen" "${session} kreadconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image | grep -q ArkadeOS-Lock"
# T010: Hungarian is complete, our own texts included.
check "Hungarian language" "rpm -q hunspell-hu && test -f /usr/share/locale/hu/LC_MESSAGES/dolphin.mo &&
    grep -q 'Name\\[hu\\]' /usr/share/plasma/look-and-feel/org.arkadeos.light.desktop/metadata.json"
check "each ArkadeOS global theme has its own preview" "for v in light dark; do
    test -s /usr/share/plasma/look-and-feel/org.arkadeos.\$v.desktop/contents/previews/preview.png || exit 1; done"
# KDE's own window buttons (on the right) and screen corners (Roland, 2026-11-04).
check "window buttons and screen corners as in KDE" "! grep -qE 'ButtonsOn|ElectricBorders|Effect-overview' /etc/xdg/kwinrc &&
    test \"\$(${session} kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft)\" != XIA"
check "touchpad scrolls the natural way, the mouse does not" "test \"\$(${session} kreadconfig6 --file kcminputrc --group Libinput --group Defaults --group Touchpad --key NaturalScroll)\" = true &&
    test -z \"\$(${session} kreadconfig6 --file kcminputrc --group Libinput --group Defaults --group Pointer --key NaturalScroll)\""
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
check "dark theme applied" "grep -qx ColorScheme=BreezeDark ${home}/kdedefaults/kdeglobals &&
    grep -A3 '^\\[Colors:Window\\]' ${home}/kdeglobals | grep -qx BackgroundNormal=32,35,38"
sleep 20
check "Finder-like sidebar: Games in it, Remote and Recent hidden" "grep -qE 'href=\"file:///(var/)?home/arkade/Games\"' ${home%/.config}/.local/share/user-places.xbel &&
    grep -q '<GroupState-Remote-IsHidden>true' ${home%/.config}/.local/share/user-places.xbel &&
    grep -q '<GroupState-RecentlySaved-IsHidden>true' ${home%/.config}/.local/share/user-places.xbel"
ssh_vm "${session} systemctl --user status --no-pager arkadeos-session-setup.path arkadeos-session-setup.service;
    ${session} journalctl --user -b -u arkadeos-session-setup --no-pager | tail -60;     grep -h ColorScheme ${home}/kdeglobals ${home}/kdedefaults/kdeglobals; ls -la ${home%/.config}/.local/share/user-places.xbel ${home%/.config}/.local/state/arkadeos" > "${out}/session-setup.txt" 2>&1 || true
# Every ArkadeOS menu entry has its icon (the Battle.net one came from
# WhiteSur's icons until 11-04).
check "every ArkadeOS menu entry has its icon" 'for f in /usr/share/applications/org.arkadeos.*.desktop; do
    i=$(sed -n "s/^Icon=//p" $f | head -1);
    find /usr/share/icons/hicolor /usr/share/icons/breeze /usr/share/pixmaps -name "$i.*" | grep -q . || { echo $f; exit 1; }; done'
check "thin Dolphin status bar" 'grep -qx ShowStatusBar=FullWidth /etc/xdg/dolphinrc'
# The menu bar in the window again, Dolphin's from its first start; not in
# Konsole (Roland, 2026-11-04). A shown menu bar is the default: Dolphin drops
# MenuBar=Enabled when it closes, so the check is that it is not Disabled.
check "menu bar in Dolphin, not in Konsole" "test \"\$(${session} kreadconfig6 --file dolphinrc --group MainWindow --key MenuBar)\" != Disabled &&
    test -n \"\$(${session} kreadconfig6 --file dolphinrc --group General --key Version)\" &&
    test \"\$(${session} kreadconfig6 --file konsolerc --group MainWindow --key MenuBar)\" = Disabled"
ssh_vm "pkill -u arkade -x dolphin; sleep 2; nohup ${session} dolphin >/dev/null 2>&1 &"
sleep 10
shot dolphin-dark
ssh_vm "${session} plasma-apply-lookandfeel -a org.arkadeos.light.desktop; sleep 15; pkill -u arkade -x dolphin; sleep 2; nohup ${session} dolphin >/dev/null 2>&1 &" || true
sleep 20
shot dolphin-light
# A new image's icons reach the dock: KDE's icon cache goes when they change.
check "icon cache follows the image's icons" "test -s ${home%/.config}/.cache/arkadeos/icons-key"
# T073: the terminal welcome is ArkadeOS's and names the image actually running.
check "terminal welcome: ArkadeOS, the running image" "${session} /usr/libexec/ublue-motd > /tmp/motd.txt 2>&1;
    grep -q ArkadeOS /tmp/motd.txt && grep -q '10.0.2.2:5000/arkadeos:test' /tmp/motd.txt && ! grep -qi bazzite /tmp/motd.txt"
ssh_vm "cat /tmp/motd.txt" > "${out}/motd.txt" 2>&1 || true

# T010: the same Dolphin in Hungarian.
ssh_vm "pkill -u arkade -x dolphin" || true
ssh_vm "nohup ${session} LANG=hu_HU.UTF-8 LANGUAGE=hu dolphin >/dev/null 2>&1 &"
sleep 10
shot hungarian
fi # look

if want keys; then
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
fi # keys

if want power; then
step "gaming features"
check "scx_lavd scheduler running" 'grep -qx lavd /sys/kernel/sched_ext/root/ops || grep -q lavd /sys/kernel/sched_ext/root/ops'
check "NTSYNC device" 'test -c /dev/ntsync'
check "GameMode installed" 'command -v gamemoded'
check "GE-Proton for every user" 'ls -d /usr/share/steam/compatibilitytools.d/GE-Proton*/proton'
check "ASUS tools (start only on ASUS)" 'rpm -q asusctl asusctl-rog-gui && systemctl is-enabled arkadeos-asus-defaults.service'
# T046, T047: Legion and MSI parts in the image, hidden and stopped on a
# machine of another maker (the VM), there when the maker is turned on.
check "Legion and MSI tools (only for their maker)" 'modinfo -F filename legion-laptop && command -v legion_gui mcontrolcenter &&
    grep -qx Hidden=true /usr/local/share/applications/legion_gui.desktop &&
    grep -qx Hidden=true /usr/local/share/applications/mcontrolcenter.desktop &&
    test "$(systemctl is-enabled legiond.service)" = masked && ! lsmod | grep -q legion'
# The VM is identified as another maker's machine: Legion and MSI parts are
# refused. On a made-up Legion laptop (ARKADEOS_DMI) Legion parts go on, MSI's
# still cannot.
check "other makers' parts refused" '! /usr/libexec/arkadeos/vendor-set legion on && ! /usr/libexec/arkadeos/vendor-set msi on &&
    test "$(arkadeos-vendor legion allowed)" = no'
ssh_vm 'mkdir -p /tmp/legion-dmi && cd /tmp/legion-dmi && echo LENOVO > sys_vendor && echo 82RG > product_name &&
    echo "Legion 5 15ARH7H" > product_family && : > product_version && echo 10 > chassis_type' || true
check "Legion parts on a Legion laptop" 'export ARKADEOS_DMI=/tmp/legion-dmi; test "$(arkadeos-vendor detect)" = legion &&
    /usr/libexec/arkadeos/vendor-set legion on && ! /usr/libexec/arkadeos/vendor-set msi on &&
    test ! -e /usr/local/share/applications/legion_gui.desktop && systemctl is-enabled legiond.service | grep -qv masked &&
    grep -qx Hidden=true /usr/local/share/applications/mcontrolcenter.desktop'
ssh_vm 'ARKADEOS_DMI=/tmp/legion-dmi /usr/libexec/arkadeos/vendor-set legion off; rm -f /etc/arkadeos/vendor' || true
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
# T058: Gaming, Max and WoW keep no power saving: PCI devices awake, NMI
# watchdog off, and on a stand-in tree the rest (ASPM, USB, SATA, sound),
# all back after the profile goes.
ppd_set performance
check "Gaming: no power saving" 'test "$(sysctl -n kernel.nmi_watchdog)" = 0 &&
    ! grep -L -x on /sys/bus/pci/devices/*/power/control | grep -q . && test -s /run/arkadeos/no-power-save.saved'
# T084: huge pages for every game, a small write buffer, and ArkadeOS's own
# swappiness, not the server profile's 10.
check "Gaming: memory set for games" 'grep -q "\[always\]" /sys/kernel/mm/transparent_hugepage/enabled &&
    test "$(sysctl -n vm.dirty_bytes)" = 268435456 && test "$(sysctl -n vm.dirty_background_bytes)" = 67108864 &&
    test "$(sysctl -n vm.swappiness)" = 180'
# Balanced on the charger saves no power either, but PCI devices keep their
# own power management there (a graphics card nothing uses may sleep). Only
# Akku saves power.
ppd_set balanced
check "Balanced on the charger: no power saving" 'test -s /run/arkadeos/no-power-save.saved &&
    ! grep -q /bus/pci/ /run/arkadeos/no-power-save.saved &&
    ! grep -l -x -E "min_power|min_power_with_partial|med_power|med_power_with_dipm" \
        /sys/class/scsi_host/*/link_power_management_policy | grep -q .'
check "memory as before after Gaming, set for zram" 'grep -q "\[madvise\]" /sys/kernel/mm/transparent_hugepage/enabled &&
    test "$(sysctl -n vm.dirty_bytes)" = 0 && test "$(sysctl -n vm.swappiness)" = 180 &&
    test "$(sysctl -n vm.page-cluster)" = 0 && test "$(sysctl -n vm.watermark_scale_factor)" = 125'
ppd_set power-saver
check "power saving back on Akku" 'test ! -e /run/arkadeos/no-power-save.saved'
ppd_set balanced
ssh_vm 'd=/run/nps-test; mkdir -p $d/module/pcie_aspm/parameters $d/bus/pci/devices/0000:00:01.0/power \
    $d/bus/usb/devices/1-1/power $d/class/scsi_host/host0 $d/module/snd_hda_intel/parameters &&
    echo default > $d/module/pcie_aspm/parameters/policy && echo auto > $d/bus/pci/devices/0000:00:01.0/power/control &&
    echo auto > $d/bus/usb/devices/1-1/power/control && echo 1 > $d/module/snd_hda_intel/parameters/power_save &&
    echo med_power_with_dipm > $d/class/scsi_host/host0/link_power_management_policy'
check "no power saving: ASPM, PCI, USB, SATA, sound, then back" 'd=/run/nps-test; export ARKADEOS_SYS=$d;
    /usr/libexec/arkadeos/no-power-save start && test "$(cat $d/module/pcie_aspm/parameters/policy)" = performance &&
    test "$(cat $d/bus/pci/devices/0000:00:01.0/power/control)" = on &&
    test "$(cat $d/bus/usb/devices/1-1/power/control)" = on && test "$(cat $d/module/snd_hda_intel/parameters/power_save)" = 0 &&
    test "$(cat $d/class/scsi_host/host0/link_power_management_policy)" = max_performance &&
    /usr/libexec/arkadeos/no-power-save stop && test "$(cat $d/module/pcie_aspm/parameters/policy)" = default &&
    test "$(cat $d/bus/pci/devices/0000:00:01.0/power/control)" = auto &&
    test "$(cat $d/bus/usb/devices/1-1/power/control)" = auto && test "$(cat $d/class/scsi_host/host0/link_power_management_policy)" = med_power_with_dipm'
check "Balanced on the charger: PCI devices keep their power management" 'd=/run/nps-test; export ARKADEOS_SYS=$d ARKADEOS_KEEP_PCI_PM=1;
    /usr/libexec/arkadeos/no-power-save start && test "$(cat $d/bus/pci/devices/0000:00:01.0/power/control)" = auto &&
    test "$(cat $d/bus/usb/devices/1-1/power/control)" = on && test "$(cat $d/module/snd_hda_intel/parameters/power_save)" = 0 &&
    /usr/libexec/arkadeos/no-power-save stop && test "$(cat $d/bus/usb/devices/1-1/power/control)" = auto &&
    test ! -e $d/no-power-save.saved && test -s /run/arkadeos/no-power-save.saved'
# T057: big shader caches for every game.
check "shader cache 12 GB" "${session} systemctl --user show-environment | grep -qx __GL_SHADER_DISK_CACHE_SIZE=12000000000"
# T055: WoW, full CPU with the graphics card held back. The VM has no
# separate card, so the limit runs on a stand-in Intel and AMD tree.
ssh_vm 'mkdir -p /run/gpu-test/card0/device/hwmon/hwmon0 /run/gpu-test/card1 && cd /run/gpu-test &&
    echo PPT > card0/device/hwmon/hwmon0/power1_label && echo 150000000 > card0/device/hwmon/hwmon0/power1_cap &&
    echo 150000000 > card0/device/hwmon/hwmon0/power1_cap_default && echo 1500 > card1/gt_max_freq_mhz &&
    echo 1500 > card1/gt_RP0_freq_mhz && echo 300 > card1/gt_min_freq_mhz'
check "desktop: GPU not held back" 'ARKADEOS_DRM=/run/gpu-test /usr/libexec/arkadeos/gpu-cap start &&
    test "$(cat /run/gpu-test/card0/device/hwmon/hwmon0/power1_cap)" = 150000000 &&
    ARKADEOS_DRM=/run/gpu-test /usr/libexec/arkadeos/gpu-cap stop'
check "laptop: GPU held back to 80% and let go" 'export ARKADEOS_DRM=/run/gpu-test ARKADEOS_LAPTOP=1 && /usr/libexec/arkadeos/gpu-cap start &&
    test "$(cat /run/gpu-test/card0/device/hwmon/hwmon0/power1_cap)" = 120000000 &&
    test "$(cat /run/gpu-test/card1/gt_max_freq_mhz)" = 1200 &&
    /usr/libexec/arkadeos/gpu-cap stop &&
    test "$(cat /run/gpu-test/card0/device/hwmon/hwmon0/power1_cap)" = 150000000 &&
    test "$(cat /run/gpu-test/card1/gt_max_freq_mhz)" = 1500 && test ! -e /run/arkadeos/gpu-cap.saved'
# ASUS laptop with NVIDIA: the firmware's GPU TGP and Dynamic Boost (stand-in
# nvidia-smi that refuses -pl, as laptop GPUs do, and stand-in attributes).
ssh_vm 'mkdir -p /run/tgp-test/bin /run/tgp-test/fw/dgpu_tgp /run/tgp-test/fw/nv_dynamic_boost && cd /run/tgp-test &&
    printf "#!/bin/sh\ncase \"\$1\" in -pl) exit 1;; -L) echo GPU 0;; --query-gpu=utilization*) cat /run/tgp-test/util;; esac\n" > bin/nvidia-smi && chmod +x bin/nvidia-smi &&
    echo 115 > fw/dgpu_tgp/current_value && echo 115 > fw/dgpu_tgp/max_value && echo 55 > fw/dgpu_tgp/min_value &&
    echo 25 > fw/nv_dynamic_boost/current_value && echo 5 > fw/nv_dynamic_boost/min_value'
check "ASUS GPU TGP to 80%, Dynamic Boost off, then back" 'export PATH=/run/tgp-test/bin:$PATH ARKADEOS_FW=/run/tgp-test/fw ARKADEOS_DRM=/run/tgp-test ARKADEOS_LAPTOP=1 &&
    /usr/libexec/arkadeos/gpu-cap start && test "$(cat /run/tgp-test/fw/dgpu_tgp/current_value)" = 92 &&
    test "$(cat /run/tgp-test/fw/nv_dynamic_boost/current_value)" = 5 && /usr/libexec/arkadeos/gpu-cap stop &&
    test "$(cat /run/tgp-test/fw/dgpu_tgp/current_value)" = 115 && test "$(cat /run/tgp-test/fw/nv_dynamic_boost/current_value)" = 25'
# A card that is the bottleneck gets its power back step by step, and is held
# back again once it idles (stand-in busy figure, a look every 0.2 s).
check "GPU busy: share goes up to 100%, then back to 80%" 'export PATH=/run/tgp-test/bin:$PATH ARKADEOS_FW=/run/tgp-test/fw ARKADEOS_DRM=/run/tgp-test ARKADEOS_LAPTOP=1 ARKADEOS_GPU_CAP_INTERVAL=0.2 &&
    echo 99 > /run/tgp-test/util && /usr/libexec/arkadeos/gpu-cap start && sleep 3 &&
    test "$(cat /run/tgp-test/fw/dgpu_tgp/current_value)" = 115 && test "$(cat /run/tgp-test/fw/nv_dynamic_boost/current_value)" = 25 &&
    echo 30 > /run/tgp-test/util && sleep 8 && test "$(cat /run/tgp-test/fw/dgpu_tgp/current_value)" = 92 &&
    /usr/libexec/arkadeos/gpu-cap stop && test "$(cat /run/tgp-test/fw/dgpu_tgp/current_value)" = 115 &&
    test ! -e /run/arkadeos/gpu-cap.watch && ! pgrep -f "^/usr/bin/bash /usr/libexec/arkadeos/gpu-cap watch"'
ssh_vm /usr/libexec/arkadeos/power-set wow || true
sleep 4
check "WoW profile" 'tuned-adm active | grep -q arkadeos-wow'
check "WoW in the top-bar switch" "${session} arkadeos-power status | grep -qx profile=wow"
check "WoW: GPU limit script ran" "journalctl -b -t arkadeos-gpu-cap | grep -q 'nothing held back'"
# TuneD runs only scripts inside the profile folders; ours start from there.
check "TuneD ran every profile script" "! journalctl -b -u tuned | grep -q 'Paths outside of the profile directories'"
ssh_vm "tuned-adm active; ${session} arkadeos-power status; journalctl -b -t arkadeos-gpu-cap --no-pager;
    journalctl -b -u tuned --no-pager | tail -30" > "${out}/wow-profile.txt" 2>&1 || true
ssh_vm /usr/libexec/arkadeos/power-set balanced || true
sleep 4
check "back to Balanced after WoW" 'tuned-adm active | grep -q arkadeos-balanced && test ! -e /run/arkadeos/power-wow'
# T012: the switch sits on the taskbar and reads the profile.
check "power switch on the taskbar" "grep -qx plugin=org.arkadeos.power ${home}/plasma-org.kde.plasma.desktop-appletsrc &&
    ${session} arkadeos-power status | grep -qx profile=balanced"
check "game watcher running" 'systemctl --user -M arkade@ is-active arkadeos-game-profile.service'
# On the charger the machine never goes to sleep by itself (Roland,
# 2026-11-12); on battery Plasma's own idle sleep stays.
check "no sleep by itself on the charger" "${session} kreadconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendAction | grep -qx 0 &&
    test -z \"\$(${session} kreadconfig6 --file powerdevilrc --group Battery --group SuspendAndShutdown --key AutoSuspendAction)\""
# T050: the switch reads the profile when it changes, not every three seconds.
# A stand-in in front of arkadeos-power notes who asks for the status; the
# test's own questions come from runuser.
ssh_vm 'printf "%s\n" "#!/usr/bin/bash" \
    "[[ \"\$1\" == status ]] && echo \"\$(date +%s) \$(cat /proc/\$PPID/comm)\" >> /tmp/power-status.log" \
    "exec /usr/bin/arkadeos-power \"\$@\"" > /usr/local/bin/arkadeos-power && chmod +x /usr/local/bin/arkadeos-power'
sleep 20
check "power switch: no status question every three seconds" 'n=$(grep -vc runuser /tmp/power-status.log 2>/dev/null); test "${n:-0}" -le 2 &&
    ! journalctl -b --no-pager | grep -q "org.arkadeos.power/contents/ui/Watch.qml"'
ssh_vm 'rm -f /tmp/power-status.log'
ppd_set performance
check "power switch: a changed profile is read at once" 'grep -qv runuser /tmp/power-status.log'
ppd_set balanced
ssh_vm 'cat /tmp/power-status.log; rm -f /usr/local/bin/arkadeos-power /tmp/power-status.log;
    journalctl -b --no-pager | grep org.arkadeos.power' > "${out}/power-switch.txt" 2>&1 || true
fi # power

if want games; then
step "running a Windows program with GE-Proton"
# Profile log while the Windows program runs: Gaming must be held.
ssh_vm "nohup sh -c 'for i in \$(seq 400); do tuned-adm active; sleep 3; done' > /tmp/profiles.log 2>&1 &"
# umu-launcher is how ArkadeOS starts non-Steam games (Battle.net). The first
# run downloads the Steam Linux Runtime.
proton=$(ssh_vm 'ls -d /usr/share/steam/compatibilitytools.d/GE-Proton* | sort -V | tail -1')
ssh_vm "echo $(base64 -w0 "${here}/proton-test.bat") | base64 -d > /home/arkade/proton-test.bat && chown arkade: /home/arkade/proton-test.bat"
ssh_vm "cd /home/arkade && ${session} DISPLAY=:0 GAMEID=umu-default PROTONPATH=${proton} WINEPREFIX=/home/arkade/proton-test \
    timeout 900 umu-run /home/arkade/proton-test.bat" > "${out}/proton.log" 2>&1 || true
shot proton
check "Windows program ran with GE-Proton" 'grep -q ArkadeOS /home/arkade/proton-test/drive_c/proton-ok.txt'
# SELinux view of the Windows program run, for the results.
ssh_vm "ps -o label= -p 1; ps -eZ | awk '{print \$1}' | sort | uniq -c | sort -rn | head; ${session} id -Z;
    stat -c '%C %n' ${proton}/files/lib/wine/i386-windows/ntdll.dll /home/arkade/Games /home/arkade/.local/share/Steam;
    matchpathcon ${proton}/files/lib/wine/i386-windows/ntdll.dll; semanage fcontext -l -C;
    journalctl -b --no-pager | grep -a 'avc:.*denied' | grep -v chcon | tail -20" > "${out}/selinux.txt" 2>&1 || true
check "32-bit Windows program ran with GE-Proton" 'grep -q ArkadeOS /home/arkade/proton-test/drive_c/proton-32-ok.txt'
check "GE-Proton's Wine carries Fedora's Wine label" "stat -c %C ${proton}/files/lib/wine/i386-windows/ntdll.dll | grep -q :textrel_shlib_t:"
check "SELinux stopped no Windows program" '! journalctl -b --no-pager | grep -q "avc:.*denied.*execmod"'
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
# T050: what Wine and Proton run by themselves is no game. A third run has
# only Wine's own programs, for 15 s; beside them run Wine's services
# (lsass.exe in Wine 11) and Proton's helper (xalia.exe), as they do beside
# an open Battle.net. Those two counted as a game with this Proton: Gaming,
# and "a game is running" for the update, with no game on (Roland's report,
# 2026-11-12). Noted every 3 s: the profile, whether Wine is up, and the
# game mark if there is one.
ssh_vm "echo $(base64 -w0 "${here}/wine-own-test.bat") | base64 -d > /home/arkade/wine-own-test.bat && chown arkade: /home/arkade/wine-own-test.bat"
ssh_vm "nohup sh -c 'for i in \$(seq 15); do tuned-adm active; pgrep -x wineserver >/dev/null && echo wine=up;
    sed s/^/mark=/ /run/user/${uid}/arkadeos-game 2>/dev/null; sleep 3; done' > /tmp/wine-own.log 2>&1 &"
ssh_vm "cd /home/arkade && ${session} DISPLAY=:0 GAMEID=umu-default PROTONPATH=${proton} WINEPREFIX=/home/arkade/proton-test \
    timeout 600 umu-run /home/arkade/wine-own-test.bat" >> "${out}/proton.log" 2>&1 || true
ssh_vm 'cat /tmp/wine-own.log' > "${out}/wine-own.txt" 2>&1 || true
check "Wine's own programs ran for a while" 'grep -q ArkadeOS /home/arkade/proton-test/drive_c/wine-own-ok.txt && test "$(grep -c "^wine=up" /tmp/wine-own.log)" -ge 3'
check "Wine's own programs are no game" 'grep -q arkadeos-balanced /tmp/wine-own.log && ! grep -q arkadeos-gaming /tmp/wine-own.log && ! grep -q "^mark=" /tmp/wine-own.log'
# T084: where the processor has several groups of cores, a game on WoW runs
# on one of them. A stand-in processor for the game watcher: two groups of
# two cores, the second rated faster.
ssh_vm 'for c in 0 1 2 3; do d=/run/cpu-test/cpu$c; mkdir -p $d/cache/index3 $d/acpi_cppc; echo 16384K > $d/cache/index3/size;
    if [ $c -lt 2 ]; then echo 0-1 > $d/cache/index3/shared_cpu_list; echo 100 > $d/acpi_cppc/highest_perf;
    else echo 2-3 > $d/cache/index3/shared_cpu_list; echo 120 > $d/acpi_cppc/highest_perf; fi; done'
check "core group for a game: the faster of two" "${session} ARKADEOS_CPU=/run/cpu-test ARKADEOS_CCD_MIN_CORES=2 arkadeos-power ccd | grep -qx 'on 2-3'"
check "core group: none where the groups are too small for a game" "${session} ARKADEOS_CPU=/run/cpu-test arkadeos-power ccd | grep -qx none"
check "core group switched off and on" "${session} arkadeos-power ccd off && test -e ${home}/arkadeos/ccd-off &&
    ${session} ARKADEOS_CPU=/run/cpu-test ARKADEOS_CCD_MIN_CORES=2 arkadeos-power ccd | grep -qx 'off 2-3' &&
    ${session} arkadeos-power ccd on && test ! -e ${home}/arkadeos/ccd-off"
ssh_vm "${session} systemctl --user set-environment ARKADEOS_CPU=/run/cpu-test ARKADEOS_CCD_MIN_CORES=2 &&
    ${session} systemctl --user restart arkadeos-game-profile.service" || true
# T055: World of Warcraft (Wow.exe under Wine) switches WoW on by itself,
# then Balanced comes back. Stand-ins for what runs with Battle.net open: its
# wineserver, Battle.net.exe, Wine's service lsass.exe and Proton's helper
# xalia.exe, under the names they have on a real machine. Wow.exe comes 12 s
# later and stays 30 s; 20 s on, the CPUs it may run on are noted. Battle.net
# stays 18 s more, as it does in the tray.
ssh_vm "nohup sh -c 'for i in \$(seq 20); do tuned-adm active; ${session} busctl --user get-property org.freedesktop.Notifications \
    /org/freedesktop/Notifications org.freedesktop.Notifications Inhibited; sleep 3; done' > /tmp/wow.log 2>&1 &"
ssh_vm "${session} bash -c '(exec -a wineserver sleep 60) & (exec -a Battle.net.exe sleep 60) & (exec -a C:\\\\windows\\\\system32\\\\lsass.exe sleep 60) &
    (exec -a xalia.exe sleep 60) & sleep 12; (exec -a Wow.exe sleep 30) &
    sleep 20; grep Cpus_allowed_list /proc/\$!/status > /tmp/wow-cpus.txt; cat /run/user/\$(id -u)/arkadeos-game > /tmp/wow-mark.txt 2>&1;
    /usr/libexec/arkadeos/no-game-running > /tmp/wow-jobs.txt; echo \$? >> /tmp/wow-jobs.txt; wait'" || true
check "World of Warcraft on WoW" 'grep -q arkadeos-wow /tmp/wow.log'
# Battle.net alone is no game, before the game and after it: Roland's profile
# went to Gaming when he left WoW, and the update said a game was running
# with no game on (2026-11-12).
check "a launcher left open is no game" '! grep -q arkadeos-gaming /tmp/wow.log && test "$(grep -c arkadeos-balanced /tmp/wow.log)" -ge 3'
check "World of Warcraft on one core group" 'grep -q "Cpus_allowed_list:[[:space:]]*2-3\$" /tmp/wow-cpus.txt'
check "background jobs told to wait while the game runs" 'tail -1 /tmp/wow-jobs.txt | grep -qx 1'
# What counts as the game is written down, for the Portal and the update's
# log (Roland, 2026-11-12: "a game is running" with no game to be seen).
check "the game's name is on the mark and in the answer" 'grep -qx wow.exe /tmp/wow-mark.txt &&
    grep -qx "a game is running (wow.exe): not now" /tmp/wow-jobs.txt'
# The released Gaming hold must not put Balanced back under WoW (2026-11-01).
check "WoW stays on while the game runs" 'test "$(grep -c arkadeos-wow /tmp/wow.log)" -ge 6'
# T062: notifications wait while a game runs, and come again after.
check "do not disturb while a game runs" 'grep -qx "b true" /tmp/wow.log'
sleep 20
check "Balanced after World of Warcraft" 'tuned-adm active | grep -q arkadeos-balanced && test ! -e /run/arkadeos/power-wow'
check "background jobs may run after the game" '/usr/libexec/arkadeos/no-game-running'
check "notifications back after the game" "${session} busctl --user get-property org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications Inhibited | grep -qx 'b false'"
ssh_vm "cat /tmp/wow.log /tmp/wow-cpus.txt; tuned-adm active; ls /run/arkadeos; journalctl -b -u tuned-ppd --no-pager | tail -30;
    ${session} journalctl --user -b -u arkadeos-game-profile --no-pager | tail -40" > "${out}/wow-game.txt" 2>&1 || true
ssh_vm "${session} systemctl --user unset-environment ARKADEOS_CPU ARKADEOS_CCD_MIN_CORES &&
    ${session} systemctl --user restart arkadeos-game-profile.service" || true

# T068: a window whose app has no menu entry under its name gets a hidden one,
# so it can be pinned on the dock. A Windows program in the Battle.net prefix
# stands in for a Battle.net game: it starts through Battle.net, with its own
# icon.
# T069: the drives in the sidebar are the ones a person opens. A disk image
# laid out as Windows lays out its disk stands in for a Windows drive.
ssh_vm 'truncate -s 64M /tmp/win.img && printf "label: gpt\nsize=8M, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B\nsize=8M, type=E3C9E316-0B5C-4DB8-817D-F92DF00215AE\nsize=8M, type=DE94BBA4-06D1-4D40-A16A-BFD50179D6AC\ntype=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7\n" | sfdisk -q /tmp/win.img &&
    loop=$(losetup -fP --show /tmp/win.img) && mkfs.ntfs -Q -F ${loop}p4 >/dev/null && udevadm trigger --settle ${loop}p1 ${loop}p2 ${loop}p3 ${loop}p4 && echo ${loop} > /tmp/win.loop'
check "Windows' hidden partitions stay hidden" 'l=$(cat /tmp/win.loop); for n in 1 2 3; do udevadm info -q property ${l}p${n} | grep -qx UDISKS_IGNORE=1 || exit 1; done'
check "Windows drive named Windows" 'udevadm info -q property $(cat /tmp/win.loop)p4 | grep -qx UDISKS_NAME=Windows'
check "ArkadeOS system partitions hidden" 'p=$(findmnt -nvo SOURCE /sysroot); udevadm info -q property ${p} | grep -qx UDISKS_IGNORE=1'
check "the read-only system layer is no drive in the sidebar" "${session} solid-hardware6 details /org/kde/fstab/overlay/ | grep -q 'StorageAccess.ignored = true'"
check "Dolphin's free space is the disk's, not the system layer's" "rpm -q kf6-solid | grep -q '\\.arkadeos\\.' && grep -q /org/kde/fstab/overlay /usr/lib64/libKF6Solid.so.6"
ssh_vm 'losetup -d $(cat /tmp/win.loop); rm -f /tmp/win.img' || true
check "only the wallpapers Roland kept" 'cd /usr/share/wallpapers && test -d ArkadeOS && test -d ArkadeOS-Gauge/contents/images && for w in Fedora Altai ColorfulCups Next Path giants.jxl; do test ! -e $w || exit 1; done &&
    ! ls -d F[0-9]* /usr/share/backgrounds/f[0-9]* 2>/dev/null | grep -q .'
check "Chrome opens web links" 'grep -qx x-scheme-handler/https=com.google.Chrome.desktop /etc/xdg/mimeapps.list && ! grep -q "^x-scheme-handler/https=.*firefox" /etc/xdg/mimeapps.list'
# T071: no on-screen keyboard on its own.
check "no on-screen keyboard" "test -z \"\$(${session} kreadconfig6 --file kwinrc --group Wayland --key InputMethod)\" && ! pgrep -u arkade -x plasma-keyboard"
check "dock names script in KWin" "${session} busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting isScriptLoaded s arkadeos-dock-names | grep -qx 'b true'"
# The stand-in has no authority file for the desktop's X display, so Wine
# cannot reach the X server ("Authorization required" in its log) and draws
# through Wayland: its window then carries the program's own name
# (notepad.exe), which is what this check is about. Through Wayland the
# window comes only while the screen is on, and the screen turns itself off
# about now, ten minutes after the last key: the check failed in the runs
# where it was off (2026-11-11 23:22, 2026-11-12 18:57). So the screen is
# woken and kept on while the window is waited for.
# With the authority file Wine draws through X, and every program started
# this way has one window name, steam_app_default (2026-11-12 19:44): that
# is another case than this check's.
key shift
sleep 2
ssh_vm "loginctl unlock-sessions; ${session} kscreen-doctor --dpms on" >/dev/null 2>&1 || true
ssh_vm "nohup ${session} kde-inhibit --power --screenSaver sleep 600 > /tmp/keep-screen-on.log 2>&1 &"
sleep 3
shot battlenet-screen
ssh_vm "cd /home/arkade && nohup ${session} DISPLAY=:0 GAMEID=umu-default PROTONPATH=${proton} WINEPREFIX=/home/arkade/Games/battlenet \
    timeout 300 umu-run notepad > /tmp/notepad.log 2>&1 &"
for _ in $(seq 40); do
    sleep 5
    ssh_vm 'test -f /home/arkade/.local/share/applications/notepad.exe.desktop' && break
done
shot battlenet-window
ssh_vm "echo '== notepad log'; cat /tmp/notepad.log; echo '== programs'; ps -u arkade -o pid,etime,stat,args | grep -i -E 'wine|notepad|umu|pressure|proton|steam|bwrap|\.exe' | grep -v grep | cut -c1-260;
    echo '== memory (MiB)'; free -m; echo '== profile'; tuned-adm active; cat /sys/kernel/mm/transparent_hugepage/enabled;
    echo '== game mark'; cat /run/user/${uid}/arkadeos-game;
    echo '== game watcher'; ${session} journalctl --user -b -u arkadeos-game-profile --no-pager | tail -15;
    echo '== screen kept on'; cat /tmp/keep-screen-on.log; pgrep -u arkade -af kde-inhibit" > "${out}/battlenet-window.txt" 2>&1 || true
check "Battle.net game window gets a dock entry" 'f=/home/arkade/.local/share/applications/notepad.exe.desktop;
    grep -qx Exec=arkadeos-battlenet $f && grep -qx StartupWMClass=notepad.exe $f && grep -qx NoDisplay=true $f &&
    grep -qE "^Icon=(/var)?/home/arkade/.local/share/icons/hicolor/256x256/apps/notepad.exe.png" $f'
check "every window so far has a dock entry" "${session} /usr/libexec/arkadeos/dock-names --check && test -s /home/arkade/.local/state/arkadeos/dock-names.json"
ssh_vm "cat /home/arkade/.local/state/arkadeos/dock-names.json; ${session} journalctl --user -u arkadeos-dock-names --no-pager | tail -20" > "${out}/dock-names.txt" 2>&1 || true
ssh_vm "pkill -u arkade -f notepad; ${session} WINEPREFIX=/home/arkade/Games/battlenet ${proton}/files/bin/wineserver -k" || true
sleep 20

ssh_vm "loginctl unlock-sessions; ${session} kscreen-doctor --dpms on" >/dev/null 2>&1 || true
# T070: a borderless game window the size of the screen (a Windows game in
# windowed full screen) goes full screen, above the taskbar.
check "borderless full-screen script in KWin" "${session} busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting isScriptLoaded s arkadeos-borderless-fullscreen | grep -qx 'b true'"
ssh_vm "nohup ${session} DISPLAY=:0 XAUTHORITY=\$(ls /run/user/1000/xauth_* | head -1) GDK_BACKEND=x11 timeout 60 python3 -c '
import gi
gi.require_version(\"Gtk\", \"3.0\")
from gi.repository import Gtk, Gdk
w = Gtk.Window(title=\"arkadeos-borderless\")
w.set_wmclass(\"wowtest.exe\", \"wowtest.exe\")
r = Gdk.Display.get_default().get_monitor(0).get_geometry()
w.set_decorated(False)
w.move(r.x, r.y)
w.set_default_size(r.width, r.height)
w.show_all()
Gtk.main()' > /tmp/borderless.log 2>&1 &"
sleep 10
shot borderless
check "borderless screen-sized window runs full screen" "${session} DISPLAY=:0 XAUTHORITY=\$(ls /run/user/1000/xauth_* | head -1) xprop -name arkadeos-borderless _NET_WM_STATE | grep -q _NET_WM_STATE_FULLSCREEN"
ssh_vm "cat /tmp/borderless.log; pgrep -af arkadeos-borderless; ${session} DISPLAY=:0 XAUTHORITY=\$(ls /run/user/1000/xauth_* | head -1) xwininfo -root -tree | grep -i borderless;
    ${session} DISPLAY=:0 XAUTHORITY=\$(ls /run/user/1000/xauth_* | head -1) xprop -name arkadeos-borderless" > "${out}/borderless.txt" 2>&1 || true
# What KWin sees of the window: a test-only KWin script, its lines through a
# small session bus service (KWin keeps a script's print() out of the journal).
ssh_vm "echo $(base64 -w0 "$(dirname "$0")/kwin-probe.js") | base64 -d > /tmp/kwin-probe.js &&
    echo $(base64 -w0 "$(dirname "$0")/kwin-probe-log.py") | base64 -d > /tmp/kwin-probe-log.py && chmod 644 /tmp/kwin-probe.js /tmp/kwin-probe-log.py
    nohup ${session} python3 /tmp/kwin-probe-log.py /tmp/kwin-probe.log > /tmp/kwin-probe-log.out 2>&1 & sleep 3
    id=\$(${session} busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting loadScript ss /tmp/kwin-probe.js kwin-probe | cut -d' ' -f2)
    ${session} busctl --user call org.kde.KWin /Scripting/Script\${id} org.kde.kwin.Script run; sleep 3
    echo \"script \${id}\"; cat /tmp/kwin-probe.log /tmp/kwin-probe-log.out; pkill -u arkade -f kwin-probe-log.py" >> "${out}/borderless.txt" 2>&1 || true
ssh_vm "pkill -u arkade -f arkadeos-borderless" || true
fi # games

if want apps; then
step "apps"
# T014: Battle.net on the image's GE-Proton, its installer reachable.
check "Battle.net launcher on GE-Proton" "${session} arkadeos-battlenet --check | grep -q '^proton=.*GE-Proton'"
check "Battle.net installer reachable" "curl -fsSL -o /dev/null -r 0-0 \"\$(grep -o 'https://downloader[^\"]*' /usr/bin/arkadeos-store)\""
# T018: the EA app and Ubisoft Connect the same way.
check "EA app launcher on GE-Proton" "${session} arkadeos-ea --check | grep -q '^proton=.*GE-Proton'"
check "EA app installer reachable" "curl -fsSL -o /dev/null -r 0-0 \"\$(grep -o 'https://origin-a[^\"]*' /usr/bin/arkadeos-store)\""
check "Ubisoft Connect launcher on GE-Proton" "${session} arkadeos-ubisoft --check | grep -q '^proton=.*GE-Proton'"
check "Ubisoft Connect installer reachable" "curl -fsSL -o /dev/null -r 0-0 \"\$(grep -o 'https://static3.cdn.ubi.com[^\"]*' /usr/bin/arkadeos-store)\""
ssh_vm "systemctl --user -M arkade@ start arkadeos-session-setup.service" || true
check "Battle.net on the dock" "grep -q 'org.arkadeos.BattleNet.desktop' ${home}/plasma-org.kde.plasma.desktop-appletsrc"
# T015: WowUp (the edition with CurseForge) downloads itself and starts,
# pointed at the Battle.net folder. A file under the name of the edition this
# launcher started before is there first: it does not stay.
ssh_vm "runuser -u arkade -- sh -c 'mkdir -p /home/arkade/.local/share/arkadeos && touch /home/arkade/.local/share/arkadeos/WowUp.AppImage'"
ssh_vm "nohup ${session} arkadeos-wowup > /tmp/wowup.log 2>&1 &"
for _ in $(seq 24); do
    sleep 5
    ssh_vm 'pgrep -u arkade -f WowUp-CF.AppImage' >/dev/null && break
done
sleep 20
shot wowup
check "WowUp running" 'pgrep -u arkade -f WowUp-CF.AppImage'
check "WowUp: the edition before is gone" 'test ! -e /home/arkade/.local/share/arkadeos/WowUp.AppImage'
# The window goes under WowUp's menu entry, with its icon: the dock's helper
# saw the window's name (wowupcf) and found the entry, so it wrote none of
# its own. CurseForge's install links are WowUp's too.
check "WowUp's window is under its menu entry" "grep -qi '\"wowupcf\": true' /home/arkade/.local/state/arkadeos/dock-names.json &&
    test ! -e /home/arkade/.local/share/applications/wowupcf.desktop"
check "CurseForge install links open in WowUp" "${session} xdg-mime query default x-scheme-handler/curseforge | grep -qx org.arkadeos.WowUp.desktop"
check "WowUp finds the Battle.net folder" "grep -q 'game_path: /home/arkade/Games' ${home}/lutris/system.yml"
# T016-T017: Flathub apps installed at first boot.
for _ in $(seq 90); do
    ssh_vm 'test "$(systemctl show -P ActiveState arkadeos-apps.service)" = inactive &&
        test "$(systemctl show -P Result arkadeos-apps.service)" = success' && break
    sleep 10
done
ssh_vm 'systemctl status --no-pager arkadeos-apps.service; journalctl -b -u arkadeos-apps --no-pager | tail -40' > "${out}/apps-install.txt" 2>&1 || true
for app in org.mozilla.firefox com.google.Chrome com.discordapp.Discord com.github.wwmm.easyeffects \
    org.videolan.VLC com.vysp3r.ProtonPlus org.qbittorrent.qBittorrent; do
    check "${app} installed" "flatpak info --system ${app}"
done
# T067: Chrome may put web apps in the menu, and they stay pinned on the dock.
check "Chrome may make web app shortcuts" 'flatpak override --system --show com.google.Chrome | grep -q "~/.local/share/applications" &&
    test -d /home/arkade/.local/share/applications -a -d /home/arkade/.local/share/icons'
ssh_vm "runuser -u arkade -- bash -c 'printf \"[Desktop Entry]\\nType=Application\\nName=Test\\nExec=true\\nIcon=/home/arkade/.var/app/com.google.Chrome/data/icons/hicolor/256x256/apps/chrome-arktest-Default.png\\nStartupWMClass=crx_arktest\\n\" > /home/arkade/.local/share/applications/com.google.Chrome.flextop.chrome-arktest-Default.desktop'" || true
sleep 15
check "Chrome web app keeps its dock pin (hidden entry under the window's name)" 'f=/home/arkade/.local/share/applications/chrome-arktest-Default.desktop;
    grep -qx NoDisplay=true $f && grep -qx StartupWMClass=chrome-arktest-Default $f && grep -qx Name=Test $f &&
    grep -qxE "Icon=(/var)?/home/arkade/.local/share/icons/hicolor/256x256/apps/chrome-arktest-Default.png" $f'
# T024: Firefox, installed at first boot, sends no telemetry.
check "no Firefox telemetry" 'grep -q "toolkit.telemetry.enabled\", false" /var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/defaults/pref/02-arkadeos-privacy.js'
# T059: GPU Screen Recorder only from the Portal, not there by default.
check "GPU Screen Recorder not installed by default" '! flatpak info --system com.dec05eba.gpu_screen_recorder'
# The screen locks after five idle minutes; the app shots need the desktop.
ssh_vm 'loginctl unlock-sessions' || true
for app in org.mozilla.firefox:firefox com.google.Chrome:chrome com.discordapp.Discord:discord \
    org.qbittorrent.qBittorrent:qbittorrent; do
    ssh_vm "nohup ${session} flatpak run ${app%%:*} > /tmp/${app%%:*}.log 2>&1 &"
    sleep 25
    ssh_vm 'loginctl unlock-sessions' || true
    shot "app-${app#*:}"
    # qBittorrent starts as plain "qbittorrent" from the sandbox's PATH, not /app/...
    check "${app#*:} starts" "pgrep -u arkade -fi '/app/.*${app#*:}' || pgrep -u arkade -xi '${app#*:}'"
    ssh_vm "cat /tmp/${app%%:*}.log; ${session} flatpak ps" > "${out}/app-${app#*:}.log" 2>&1 || true
done
sleep 10
# T068: all of these apps' windows can be pinned on the dock too.
check "every app window has a dock entry" "${session} /usr/libexec/arkadeos/dock-names --check"
ssh_vm "cat /home/arkade/.local/state/arkadeos/dock-names.json; grep -H . /home/arkade/.local/share/applications/notepad.exe.desktop" > "${out}/dock-names-apps.txt" 2>&1 || true
check "microphone noise filter set up" "test -f ${home}/autostart/com.github.wwmm.easyeffects.desktop &&
    grep -q 'ArkadeOS mikrofon' /home/arkade/.var/app/com.github.wwmm.easyeffects/config/easyeffects/db/easyeffectsrc"
# It starts with the session, a little after the desktop: up to 2 minutes.
check "Easy Effects running" 'for i in $(seq 24); do pgrep -u arkade -f easyeffects && exit 0; sleep 5; done; exit 1'
ssh_vm "ls -la /home/arkade/.config/autostart; journalctl _UID=${uid} --no-pager | grep -i easyeffects | tail -60" > "${out}/easyeffects.txt" 2>&1 || true
ssh_vm "${session} pw-metadata -n settings" > "${out}/pw-settings.txt" 2>&1 || true
# PipeWire itself raises the minimum to 1024 inside a VM (its own rule for
# virtual machines), so the test checks the setting, not the running value.
check "low-latency audio" "${session} pw-config -n pipewire.conf merge context.properties | grep -Eq 'default.clock.quantum.{0,4}256'"
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
# T040: AirPlay off by default (T050); switched on: receiver running, its
# ports open, AirPlay speakers module loaded.
check "AirPlay off by default" "test \"\$(${session} arkadeos-airplay status)\" = off && ! pgrep -x uxplay"
ssh_vm "${session} arkadeos-airplay on; sleep 8" || true
check "AirPlay receiver when on" "systemctl --user -M arkade@ is-active -q arkadeos-airplay.service arkadeos-airplay-audio.service &&
    firewall-cmd --zone=ArkadeOS --query-service=arkadeos-airplay"
check "AirPlay speakers when on (PipeWire RAOP)" "${session} pw-cli ls Module | grep -q raop-discover"
ssh_vm "${session} arkadeos-airplay off" || true
# T042, T045: one lighting for all devices, following the profile; mouse and
# receiver tools installed; Solaar does not run without a Logitech receiver.
check "RGB, mouse and cooler tools" "rpm -q openrgb piper libratbag-ratbagd solaar liquidctl input-remapper && command -v ddcutil"
check "lighting follows the profile by default" "test \"\$(${session} arkadeos-rgb sync status)\" = on && ${session} arkadeos-rgb apply gaming"
check "LampArray keyboard light: quiet without such a keyboard" "${session} /usr/libexec/arkadeos/lamparray 50 ff0000 && test -f /usr/lib/udev/rules.d/90-arkadeos-lamparray.rules"
check "Solaar only with a receiver" '! pgrep -x solaar'
# T052: the VM has no battery, so it is a desktop: Quiet instead of Akku,
# CoolerControl for the fans, mainboard sensor drivers there.
check "desktop: Quiet profile name, CoolerControl" "${session} arkadeos-power status | grep -qx has_battery=false &&
    systemctl is-active -q coolercontrold.service && modinfo -F filename it87 nct6775 nct6687 asus_ec_sensors"
# T043, T049: monitor control over DDC/CI, firmware updates through fwupd.
check "monitor control (DDC/CI)" "command -v ddcutil && command -v arkadeos-monitor && lsmod | grep -q i2c_dev"
check "firmware updates (fwupd)" "systemctl is-enabled -q fwupd-refresh.timer && systemctl --user -M arkade@ is-enabled -q arkadeos-firmware-check.timer &&
    ${session} arkadeos-firmware devices"
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

# T037: the Portal installs what was left out and removes what is there.
portal="${session} /usr/libexec/arkadeos/portal-item"
check "Portal catalog" "test \$(${portal} --list | wc -l) -ge 20"
# T055: the Games tab lists the factory, own and Steam games and saves the
# choice (its own home, so the real Steam folder stays untouched).
ssh_vm "echo $(base64 -w0 "${here}/portal-games.py") | base64 -d > /tmp/portal-games.py && install -d -o arkade /tmp/pg-home"
check "Portal Games tab" "${session} env HOME=/tmp/pg-home python3 /tmp/portal-games.py | grep -qx 'portal games ok'"
# The update's step, percentage and outcome on the System tab, from uupd's
# journal lines; the pictures show each state.
ssh_vm "echo $(base64 -w0 "${here}/portal-update.py") | base64 -d > /tmp/portal-update.py && install -d -o arkade /tmp/pu"
check "Portal update progress" "${session} LANG=hu_HU.UTF-8 python3 /tmp/portal-update.py /tmp/pu | grep -qx 'portal update ok'"
for state in check running deploy apps done-restart failed skipped; do
    ssh_vm "cat /tmp/pu/portal-update-${state}.png" > "${out}/portal-update-${state}.png" 2>/dev/null || true
done
ssh_vm "cat /tmp/pu/portal-system.png" > "${out}/portal-system.png" 2>/dev/null || true
# Flatpak lets the desktop session's admin users install without a password;
# this shell is not that session, so root installs here.
check "Portal: Flatpak app in and out" "/usr/libexec/arkadeos/portal-item vesktop install &&
    test \$(${portal} vesktop status) = on &&
    /usr/libexec/arkadeos/portal-item vesktop remove && test \$(${portal} vesktop status) = off"
# SSH keys go into the agent at login (Roland, 2026-11-03; a passphrase comes
# from KWallet, asked once): a key without one stands in here.
check "SSH keys into the agent at login" "test -f /etc/xdg/autostart/org.arkadeos.SshKeys.desktop && ${session} sh -c 'mkdir -p ~/.ssh && eval \$(ssh-agent -s) >/dev/null &&
    ssh-keygen -q -t ed25519 -N \"\" -f ~/.ssh/id_vmtest && /usr/libexec/arkadeos/ssh-keys &&
    ssh-add -l | grep -qF \"\$(ssh-keygen -lf ~/.ssh/id_vmtest.pub | cut -d\" \" -f2)\"; r=\$?; ssh-agent -k >/dev/null; rm -f ~/.ssh/id_vmtest ~/.ssh/id_vmtest.pub; exit \$r'"
ssh_vm "${session} systemctl --user show-environment | grep SSH_AUTH_SOCK; ls -l /run/user/${uid}/ | grep -i -e ssh -e agent" > "${out}/ssh-agent.txt" 2>&1 || true
check "Portal: store launcher in and out" "${portal} ea install && test \$(${portal} ea status) = on &&
    test -f /home/arkade/.local/share/applications/org.arkadeos.EA.desktop &&
    ${portal} ea remove && test \$(${portal} ea status) = off"
check "Portal: Battle.net hidden and back" "${portal} battlenet remove && test \$(${portal} battlenet status) = off &&
    ${portal} battlenet install && test \$(${portal} battlenet status) = on"
check "Portal: switch item (tiling)" "${portal} tiling install && test \$(${portal} tiling status) = on &&
    ${portal} tiling remove && test \$(${portal} tiling status) = off"
check "Portal: AI tools not installed by default" "test \$(${portal} claude-code status) = off"
check "Portal: first-start choice saved" "/usr/libexec/arkadeos/apps-choose discord nonsense vlc &&
    test \"\$(cat /etc/arkadeos/apps)\" = \"\$(printf 'discord\\nvlc')\""
check "Portal: first-boot apps installed once, never again" "grep -qx vlc /var/lib/arkadeos/apps-done"
check "Portal: channel" "test \$(arkadeos-update channel) = test"
check "Portal: desktop defaults restored" "runuser -u arkade -- sh -c 'rm -rf /tmp/rt && mkdir -p /tmp/rt/data &&
    cp -r /home/arkade/.config /tmp/rt/config &&
    XDG_CONFIG_HOME=/tmp/rt/config XDG_DATA_HOME=/tmp/rt/data /usr/libexec/arkadeos/reset-desktop' &&
    ls /tmp/rt/data/arkadeos/reset-*/kdeglobals && ! test -e /tmp/rt/config/kdeglobals"
ssh_vm "nohup ${session} ${plasma_dirs} arkadeos-portal >/tmp/portal.log 2>&1 & echo \$! > /tmp/portal.pid"
sleep 15
shot portal
check "Portal window" "kill -0 \$(cat /tmp/portal.pid)"
# T051: a one-time update step changes a default the user kept, leaves a
# changed one alone, and runs only once.
check "update steps for the user's settings" "runuser -u arkade -- env HOME=/home/arkade sh -c 'mkdir -p /tmp/mig &&
    printf \"set_default arkadeos-test A kept old new\nset_default arkadeos-test A changed old new\necho x >> /tmp/mig/runs\n\" > /tmp/mig/001-test.sh &&
    kwriteconfig6 --file arkadeos-test --group A --key kept old && kwriteconfig6 --file arkadeos-test --group A --key changed mine &&
    ARKADEOS_MIGRATIONS=/tmp/mig /usr/libexec/arkadeos/migrate && ARKADEOS_MIGRATIONS=/tmp/mig /usr/libexec/arkadeos/migrate &&
    test \$(kreadconfig6 --file arkadeos-test --group A --key kept) = new &&
    test \$(kreadconfig6 --file arkadeos-test --group A --key changed) = mine && test \$(wc -l < /tmp/mig/runs) = 1'"
# T023: Windows on the other disk is in the boot menu, and the menu shows.
ssh_vm 'journalctl -b -u arkadeos-windows-entry --no-pager; lsblk -fp; cat /boot/grub2/custom.cfg' > "${out}/windows-entry.txt" 2>&1 || true
# Bazzite's own welcome window does not open: the ArkadeOS Portal does its job.
check "no Bazzite Portal" '! rpm -q bazzite-portal && ! test -e /home/arkade/.config/autostart/bazzite-portal.desktop &&
    ! pgrep -f "yafti_gt[k]"'
# Bazzite parts ArkadeOS does not carry: Waydroid, Bazzite's news, and the
# ujust commands that would undo the one image or the theme.
check "no Waydroid, Cockpit, Bazzite news or undoing commands" '! rpm -qa | grep -qiE "waydroid|cockpit|qemu-user-static" &&
    ! test -e /etc/xdg/autostart/bazzite-announcement.desktop &&
    ! ujust --summary | tr " " "\\n" | grep -qx -e toggle-nvk -e cockpit'
# T080: a machine on the old arkadeos-nvidia name follows arkadeos, same tag;
# one on arkadeos is left alone. The real bootc writes the booted deployment's
# origin, the way it does on a machine (a stand-in hid that /sysroot is
# read-only, 11-03); the VM's own origin is put back after.
check "old image name switched to the one image" 'd=$(ostree admin --print-current-dir) && cp "${d}.origin" /var/tmp/origin &&
    ARKADEOS_IMAGE_REF=ghcr.io/tenarkhq/arkadeos:stable /usr/libexec/arkadeos/image-name && cmp -s "${d}.origin" /var/tmp/origin &&
    ARKADEOS_IMAGE_REF=ghcr.io/tenarkhq/arkadeos-nvidia:testing /usr/libexec/arkadeos/image-name &&
    grep -qx "container-image-reference=ostree-image-signed:docker://ghcr.io/tenarkhq/arkadeos:testing" "${d}.origin"; r=$?;
    unshare -m -- sh -c "mount -o remount,rw /sysroot && cp /var/tmp/origin ${d}.origin" && cmp -s "${d}.origin" /var/tmp/origin &&
    test "${r}" = 0 && systemctl is-enabled arkadeos-image-name.service'
# The terminal's machine details show the ArkadeOS mark, not Bazzite's.
check "fastfetch shows the ArkadeOS mark" "runuser -u arkade -- bash -ic 'alias fastfetch' 2>/dev/null | grep -q \"='/usr/bin/fastfetch'\" &&
    runuser -u arkade -- env HOME=/home/arkade fastfetch --pipe 2>/dev/null | grep -q '▄██▀▀▀'"
check "Windows in the boot menu" "grep -q 'chainloader /EFI/Microsoft/Boot/bootmgfw.efi' /boot/grub2/custom.cfg &&
    grep -q 'set timeout=5' /boot/grub2/grub.cfg"
# T009: the boot menu's look is on /boot where GRUB reads it (its picture:
# windows-chosen.png).
check "boot menu look on /boot" "diff -r /usr/share/arkadeos/grub-theme /boot/grub2/themes/arkadeos &&
    test -s /boot/grub2/themes/arkadeos/inter-24.pf2 && grep -q 'set theme=' /boot/grub2/grub.cfg"
# T036: factory reset keeps the files and users, puts /etc back.
check "factory reset: settings back, files and users stay" "echo '# changed' >> /etc/dnf/dnf.conf && touch /etc/arkadeos-test-added &&
    runuser -u arkade -- touch /home/arkade/keep-reset.txt &&
    /usr/libexec/arkadeos/reset-system &&
    cmp /etc/dnf/dnf.conf /usr/etc/dnf/dnf.conf && ! test -e /etc/arkadeos-test-added &&
    test -f /home/arkade/keep-reset.txt && id arkade && test -f /etc/plasmalogin.conf.d/00-vm-test.conf &&
    systemctl is-enabled -q sshd.service"
# T026, T046, T047: no maker's parts on a machine that is none of them; no
# battery care switch without a battery.
check "maker parts: none detected, none running" "test \$(arkadeos-vendor detect) = other && test -z \"\$(arkadeos-vendor)\" &&
    ! systemctl is-active -q asusd.service && ${session} arkadeos-power status | grep -qx charge=none"
# T050: with the makers' parts as they should be, as at an ordinary boot,
# nothing is masked again and systemd does not read every unit file again.
# The first run here puts them in order (the factory reset above took the
# masks away), the second is the one looked at.
ssh_vm 'systemctl start arkadeos-vendor.service; sleep 2; date +%s > /tmp/vendor-again; sleep 1;
    systemctl start arkadeos-vendor.service' || true
check "maker parts in order: no unit reload" 'test -s /tmp/vendor-again &&
    ! journalctl --since "@$(cat /tmp/vendor-again)" --no-pager | grep -q "requested from client PID.*unit arkadeos-vendor.service"'
ssh_vm 'kill $(cat /tmp/portal.pid)' || true
fi # apps

step "security"
# T024: firewall on with the ArkadeOS zone (no open port range), no telemetry.
check "firewall on, ArkadeOS zone" 'firewall-cmd --state | grep -qx running && test "$(firewall-cmd --get-default-zone)" = ArkadeOS &&
    test -z "$(firewall-cmd --zone=ArkadeOS --list-ports)"'
check "no telemetry" '! grep -l "^countme=1" /etc/yum.repos.d/*.repo && ! systemctl is-enabled -q rpm-ostree-countme.timer'

# T050: nothing runs that nobody asked for. The key remapper's service starts
# only for a user with a preset, and its udev rule runs nothing without the
# service; the PlayStation controller helper waits for such a controller; the
# bridge for X11 screen sharing does not start at login (Fedora 45's base no
# longer has it).
ssh_vm 'systemctl start input-remapper.service' || true
check "key remapper off for a user without presets" '! systemctl is-active -q input-remapper.service && ! test -e /run/input-remapper &&
    grep -q "TEST==\"/run/input-remapper\", RUN+=" /usr/lib/udev/rules.d/99-input-remapper.rules &&
    grep -qx "Exec=/usr/libexec/arkadeos/input-remapper-autoload" /etc/xdg/autostart/input-remapper-autoload.desktop'
ssh_vm "${session} mkdir -p ${home}/input-remapper-2/presets/Test && ${session} touch ${home}/input-remapper-2/presets/Test/test.json &&
    systemctl start input-remapper.service; sleep 5" || true
check "key remapper runs for a user with a preset" 'systemctl is-active -q input-remapper.service && test -d /run/input-remapper'
ssh_vm "systemctl stop input-remapper.service; rm -rf ${home}/input-remapper-2/presets/Test" || true
check "PlayStation controller helper waits for a controller" '! systemctl is-active -q ds-inhibit.service &&
    ! systemctl is-enabled -q ds-inhibit.service && udevadm verify /usr/lib/udev/rules.d/90-arkadeos-ds-inhibit.rules'
check "no X11 screen-sharing bridge at login" '{ ! test -e /etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop ||
    grep -qx Hidden=true /etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop; } && ! pgrep -f "^[^ ]*xwaylandvideobridge"'
# The old image name is looked for in the origin files; bootc is not asked
# at every boot.
check "image name: bootc not asked on the one image" '! bash -x /usr/libexec/arkadeos/image-name 2>&1 | grep -q "bootc status"'

# No Game Mode (Roland, 2026-11-03): no full-screen Steam session to start.
check "no Game Mode session" '! test -e /usr/share/wayland-sessions/gamescope-session-steam.desktop && ! test -e /usr/share/applications/org.arkadeos.GameMode.desktop'

ssh_vm 'journalctl -b --no-pager -p warning' > "${out}/journal-warnings.txt" || true
ssh_vm 'findmnt -R /; btrfs subvolume list /; btrfs subvolume show /var/home' > "${out}/disk-layout.txt" 2>&1 || true
ssh_vm 'systemd-analyze; systemd-analyze blame | head -30; free -m' > "${out}/boot.txt" || true

if want update; then
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
# One snapshot a day, and the user's cache out of them: a subvolume of its
# own with the files it had. The service does it at boot; here it runs for
# the folder the first login made, and the old folder goes in the background.
check "one home snapshot a day" 'systemctl show snapper-timeline.timer -p TimersCalendar | grep -q "OnCalendar=\*-\*-\* 00:00:00" &&
    ! systemctl show snapper-timeline.timer -p TimersCalendar | grep -q "OnCalendar=\*-\*-\* \*:00:00"'
ssh_vm 'ls -A /home/arkade/.cache | wc -l > /tmp/cache-files; stat -c %U:%G:%a /home/arkade/.cache > /tmp/cache-owner;
    systemctl start arkadeos-home-cache.service;
    for i in $(seq 30); do test -e /home/arkade/.cache.arkadeos-old || break; sleep 1; done'
check "cache folder out of the home snapshots" 'btrfs subvolume show /home/arkade/.cache >/dev/null &&
    test "$(stat -c %i /home/arkade/.cache)" = 256 && test "$(stat -c %U:%G:%a /home/arkade/.cache)" = "$(cat /tmp/cache-owner)" &&
    test "$(ls -A /home/arkade/.cache | wc -l)" -ge "$(cat /tmp/cache-files)" && test "$(cat /tmp/cache-files)" -gt 0 &&
    ! stat -c %C /home/arkade/.cache | grep -q unlabeled_t && ! test -e /home/arkade/.cache.arkadeos-old &&
    ! test -e /home/arkade/.cache.arkadeos-new && systemctl is-enabled -q arkadeos-home-cache.service'
ssh_vm 'journalctl -b -u arkadeos-home-cache --no-pager; btrfs subvolume list /var/home' > "${out}/home-cache.txt" 2>&1 || true
# T050: what can wait does not run while a game runs: updates, snapshot
# cleanup, disk trim and the firmware list (fetched once a day).
check "background jobs wait for a running game" 'for u in uupd snapper-cleanup fstrim fwupd-refresh; do
    systemctl show $u.service -p ExecCondition | grep -q no-game-running || exit 1; done;
    systemctl show fwupd-refresh.timer -p TimersCalendar | grep -q "OnCalendar=\*-\*-\* 00:00:00"'
# "Restart now" in the update notice and the Portal asks Plasma's own prompt
# with a tool Fedora 45 has under one name only.
check "restart button: its tool and Plasma's prompt are there" 'command -v qdbus-qt6 >/dev/null &&
    test -e /usr/share/dbus-1/services/org.kde.LogoutPrompt.service'
check "game folders carry a SELinux label" '! stat -c %C /home/arkade/Games /home/arkade/.local/share/Steam | grep -q unlabeled_t'
if [[ -n "${UPDATE_PUSH:-}" ]]; then
    before=$(ssh_vm "bootc status --json | jq -r .status.booted.image.imageDigest")
    ssh_vm 'echo keep > /home/arkade/keep.txt'
    # The newest version on the channel, as the Portal shows it when it opens
    # (Roland, 2026-11-12): the running one, then a newer one, then the one
    # that waits for the reboot.
    check "newest available: the running one" "${session} LANG=C arkadeos-update latest | grep -qE '^Newest available: [0-9.]+ \(this one is running\)\$'"
    eval "${UPDATE_PUSH}"
    check "newest available: a newer one is out" "${session} LANG=C arkadeos-update latest > /tmp/latest.txt; test \$? = 10 &&
        grep -qE '^Newest available: [0-9.]+, newer than the running one' /tmp/latest.txt"
    ssh_vm 'bootc upgrade' > "${out}/update.txt" 2>&1 || true
    ssh_vm 'rpm-ostree status' >> "${out}/update.txt" 2>&1 || true
    check "update waits for the reboot" 'test "$(bootc status --json | jq -r .status.staged.image.imageDigest)" != null'
    check "newest available: downloaded, waits for the reboot" "${session} LANG=C arkadeos-update latest | grep -qE '^Newest available: [0-9.]+ \(downloaded, starts at the next reboot\)\$'"
    ssh_vm "cat /tmp/latest.txt; ${session} LANG=C arkadeos-update latest" >> "${out}/update.txt" 2>&1 || true
    # The Portal asks as the user, without root: running and waiting versions.
    check "update status answers the user (Portal)" "${session} LANG=C arkadeos-update status 2>&1 |
        grep -qx 'Running:  [0-9.]*' && ${session} LANG=C arkadeos-update status 2>&1 | grep -q '^At reboot: [0-9]'"
    # T048: a notification says so, once.
    ssh_vm "timeout 15 ${session} arkadeos-update notify" || true
    shot update-ready
    check "update ready message" 'test -s /home/arkade/.local/state/arkadeos/update-notified'
    # Once per build, not per version number (Roland, 2026-11-12): the next
    # look stays silent, and a build the note does not name is told again
    # (the note held the version number before, which the builds of a day shared).
    ssh_vm "mkdir -p /tmp/told && printf '#!/bin/sh\necho told >> /tmp/told/log\n' > /tmp/told/notify-send &&
        chmod 755 /tmp/told/notify-send && chown -R arkade /tmp/told"
    ssh_vm "${session} PATH=/tmp/told:/usr/bin arkadeos-update notify" || true
    check "update ready message: once for a build" 'test ! -e /tmp/told/log && grep -q "^sha256:" /home/arkade/.local/state/arkadeos/update-notified'
    ssh_vm "echo 45.20261112 > /home/arkade/.local/state/arkadeos/update-notified; ${session} PATH=/tmp/told:/usr/bin arkadeos-update notify;
        ${session} PATH=/tmp/told:/usr/bin arkadeos-update notify" || true
    check "update ready message: another build is told too" 'test "$(wc -l < /tmp/told/log)" = 1'
    ssh_vm 'rpm-ostree status' >> "${out}/update.txt" 2>&1 || true
    reboot_vm
    ssh_vm 'arkadeos-update status; journalctl -b -1 --no-pager -u ostree-finalize-staged -u bazzite-hardware-setup -u rpm-ostreed | tail -60' >> "${out}/update.txt" 2>&1 || true
    check "update running after the reboot" 'test -f /usr/share/arkadeos/update-test'
    check "user file kept through the update" 'test -f /home/arkade/keep.txt'
    ssh_vm 'bootc status; ls -la /home/arkade' >> "${out}/update.txt" 2>&1 || true
    ssh_vm 'arkadeos-update rollback --yes' >> "${out}/update.txt" 2>&1 || true
    reboot_vm
    ssh_vm 'arkadeos-update status' >> "${out}/update.txt" 2>&1 || true
    check "previous version back" "test ! -e /usr/share/arkadeos/update-test && test -f /home/arkade/keep.txt &&
        test \"\$(bootc status --json | jq -r .status.booted.image.imageDigest)\" = '${before}'"
    shot after-rollback
else
    echo "info update and rollback: no registry (UPDATE_PUSH unset)" >> "${out}/apps.txt"
fi
# T023: Windows starts from the menu. The machine is reset (as by its button,
# so it surely comes back to the menu); End is pressed for a minute (it also
# stops the countdown, so the menu waits), then Enter, and the stand-in says
# on the serial line that it started.
printf '%s\n' '{"execute":"qmp_capabilities"}' '{"execute":"system_reset"}' |
    socat - "UNIX-CONNECT:${qmp}" >/dev/null
for _ in $(seq 120); do
    key end
    sleep 0.5
done
shot windows-chosen
key ret
started=0
for _ in $(seq 60); do
    grep -qa ARKADEOS-TEST-WINDOWS-STARTED "${out}/serial.log" && { started=1; break; }
    sleep 1
done
shot windows-started
if (( started )); then echo "ok Windows starts from the boot menu" >> "${out}/apps.txt"
else echo "FAILED Windows starts from the boot menu" >> "${out}/apps.txt"; failed=1; fi
fi # update
kill "$(cat "${out}/qemu.pid")" || true

cat "${out}/apps.txt"
exit "${failed}"
