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
# T026: the Portal opens by itself on the first login as the choice screen.
shot portal-first-run
if ssh_vm 'pgrep -u arkade -f "arkadeos-portal --first-run"' >/dev/null; then
    echo "ok Portal choice screen on the first login" >> "${out}/apps.txt"
else
    echo "FAILED Portal choice screen on the first login" >> "${out}/apps.txt"
fi
ssh_vm 'pkill -u arkade -f "arkadeos-portal --first-run"' || true
sleep 3
shot desktop

# T050: idle load of the fresh desktop, a minute after login: memory, CPU,
# running services and the heaviest processes, for comparison between runs.
sleep 40
ssh_vm 'echo "== memory (MiB)"; free -m; echo "== load"; cat /proc/loadavg; echo "== CPU over 10 s"; vmstat 10 2 | tail -1
    echo "== running system services"; systemctl list-units --type=service --state=running --no-legend --plain | cut -d" " -f1
    echo "== running user services"; systemctl --user -M arkade@ list-units --type=service --state=running --no-legend --plain | cut -d" " -f1
    echo "== top memory"; ps -eo rss,comm --sort=-rss | head -15' > "${out}/idle.txt" 2>&1 || true
uid=$(ssh_vm 'id -u arkade')
session="runuser -u arkade -- env HOME=/home/arkade USER=arkade XDG_RUNTIME_DIR=/run/user/${uid} WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 XDG_SESSION_TYPE=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus"
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
check "ArkadeOS version: the Fedora it is built on, then the build" '. /usr/lib/os-release; [[ "${VERSION}" =~ ^${VERSION_ID}\.[0-9]{8}$ ]]'
check "boot menu entry named ArkadeOS (system-release)" 'grep -qx "ArkadeOS release [0-9]*" /etc/system-release'
check "ArkadeOS boot screen" "plymouth-set-default-theme | grep -qx arkadeos && grep -qw splash /proc/cmdline"
check "Ark wallpaper and launcher logo" "f=${home}/plasma-org.kde.plasma.desktop-appletsrc &&
    grep -qx 'Image=file:///usr/share/wallpapers/ArkadeOS/' \$f && grep -qx icon=arkadeos-launcher \$f"
check "ArkadeOS trash in every WhiteSur variant" 'for t in WhiteSur WhiteSur-dark WhiteSur-light; do cmp -s /usr/share/icons/$t/places/scalable/user-trash.svg /usr/share/arkadeos/icons/user-trash.svg &&
    cmp -s /usr/share/icons/$t/places/scalable/user-trash-full.svg /usr/share/arkadeos/icons/user-trash-full.svg || exit 1; done'
check "dark lock screen" "${session} kreadconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image | grep -q ArkadeOS-Lock"
# No idle lock during the test (the lock screen itself is checked above).
ssh_vm "${session} kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false" || true
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
# T069: apps in the Kvantum WhiteSur style, dark with the dark look; a new
# Dolphin shows it (Kvantum does not restyle running apps).
sleep 20
check "Kvantum WhiteSurDark with the dark look" "cat ${home}/kdeglobals ${home}/kdedefaults/kdeglobals | grep -qx widgetStyle=kvantum &&
    grep -qx theme=WhiteSurDark ${home}/Kvantum/kvantum.kvconfig"
check "Finder-like sidebar: Games in it, Remote and Recent hidden" "grep -q 'href=\"file:///home/arkade/Games\"' ${home%/.config}/.local/share/user-places.xbel &&
    grep -q '<GroupState-Remote-IsHidden>true' ${home%/.config}/.local/share/user-places.xbel &&
    grep -q '<GroupState-RecentlySaved-IsHidden>true' ${home%/.config}/.local/share/user-places.xbel"
check "blue sidebar icons, thin Dolphin status bar" 'grep -q ColorScheme-Highlight /usr/share/icons/WhiteSur/places/16/user-home.svg &&
    grep -qx ShowStatusBar=FullWidth /etc/xdg/dolphinrc'
ssh_vm "pkill -u arkade -x dolphin; sleep 2; nohup ${session} dolphin >/dev/null 2>&1 &"
sleep 10
shot dolphin-dark
ssh_vm "${session} plasma-apply-lookandfeel -a org.arkadeos.light.desktop; sleep 15; pkill -u arkade -x dolphin; sleep 2; nohup ${session} dolphin >/dev/null 2>&1 &" || true
sleep 20
shot dolphin-light
check "Kvantum WhiteSur with the light look" "grep -qx theme=WhiteSur ${home}/Kvantum/kvantum.kvconfig"

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
ppd_set balanced
check "power saving back after Gaming" 'test ! -e /run/arkadeos/no-power-save.saved'
ssh_vm 'd=/run/nps-test; mkdir -p $d/module/pcie_aspm/parameters $d/bus/pci/devices/0000:00:01.0/power \
    $d/bus/usb/devices/1-1/power $d/class/scsi_host/host0 $d/module/snd_hda_intel/parameters &&
    echo default > $d/module/pcie_aspm/parameters/policy && echo auto > $d/bus/pci/devices/0000:00:01.0/power/control &&
    echo auto > $d/bus/usb/devices/1-1/power/control && echo 1 > $d/module/snd_hda_intel/parameters/power_save &&
    echo med_power_with_dipm > $d/class/scsi_host/host0/link_power_management_policy'
check "no power saving: ASPM, USB, SATA, sound, then back" 'd=/run/nps-test; export ARKADEOS_SYS=$d;
    /usr/libexec/arkadeos/no-power-save start && test "$(cat $d/module/pcie_aspm/parameters/policy)" = performance &&
    test "$(cat $d/bus/usb/devices/1-1/power/control)" = on && test "$(cat $d/module/snd_hda_intel/parameters/power_save)" = 0 &&
    test "$(cat $d/class/scsi_host/host0/link_power_management_policy)" = max_performance &&
    /usr/libexec/arkadeos/no-power-save stop && test "$(cat $d/module/pcie_aspm/parameters/policy)" = default &&
    test "$(cat $d/bus/usb/devices/1-1/power/control)" = auto && test "$(cat $d/class/scsi_host/host0/link_power_management_policy)" = med_power_with_dipm'
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
# T055: World of Warcraft (Wow.exe under Wine) switches WoW on by itself,
# then Balanced comes back. Stand-ins for its wineserver, Battle.net.exe
# (Gaming first, as on a real machine) and Wow.exe 12 s later.
ssh_vm "nohup sh -c 'for i in \$(seq 20); do tuned-adm active; ${session} busctl --user get-property org.freedesktop.Notifications \
    /org/freedesktop/Notifications org.freedesktop.Notifications Inhibited; sleep 3; done' > /tmp/wow.log 2>&1 &"
ssh_vm "${session} bash -c '(exec -a wineserver sleep 45) & (exec -a Battle.net.exe sleep 45) & sleep 12; (exec -a Wow.exe sleep 30) & wait'" || true
check "World of Warcraft on WoW" 'grep -q arkadeos-wow /tmp/wow.log'
# The released Gaming hold must not put Balanced back under WoW (2026-11-01).
check "WoW stays on while the game runs" 'test "$(grep -c arkadeos-wow /tmp/wow.log)" -ge 6'
# T062: notifications wait while a game runs, and come again after.
check "do not disturb while a game runs" 'grep -qx "b true" /tmp/wow.log'
sleep 20
check "Balanced after World of Warcraft" 'tuned-adm active | grep -q arkadeos-balanced && test ! -e /run/arkadeos/power-wow'
check "notifications back after the game" "${session} busctl --user get-property org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications Inhibited | grep -qx 'b false'"

# T068: a window whose app has no menu entry under its name gets a hidden one,
# so it can be pinned on the dock. A Windows program in the Battle.net prefix
# stands in for a Battle.net game: it starts through Battle.net, with its own
# icon.
check "dock names script in KWin" "${session} busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting isScriptLoaded s arkadeos-dock-names | grep -qx 'b true'"
ssh_vm "cd /home/arkade && nohup ${session} DISPLAY=:0 GAMEID=umu-default PROTONPATH=${proton} WINEPREFIX=/home/arkade/Games/battlenet \
    timeout 300 umu-run notepad > /tmp/notepad.log 2>&1 &"
for _ in $(seq 40); do
    sleep 5
    ssh_vm 'test -f /home/arkade/.local/share/applications/notepad.exe.desktop' && break
done
check "Battle.net game window gets a dock entry" 'f=/home/arkade/.local/share/applications/notepad.exe.desktop;
    grep -qx Exec=arkadeos-battlenet $f && grep -qx StartupWMClass=notepad.exe $f && grep -qx NoDisplay=true $f &&
    grep -q "^Icon=/home/arkade/.local/share/icons/hicolor/256x256/apps/notepad.exe.png" $f'
check "every window so far has a dock entry" "${session} /usr/libexec/arkadeos/dock-names --check && test -s /home/arkade/.local/state/arkadeos/dock-names.json"
ssh_vm "cat /home/arkade/.local/state/arkadeos/dock-names.json; ${session} journalctl --user -u arkadeos-dock-names --no-pager | tail -20" > "${out}/dock-names.txt" 2>&1 || true
ssh_vm "pkill -u arkade -f notepad; ${session} WINEPREFIX=/home/arkade/Games/battlenet ${proton}/files/bin/wineserver -k" || true
sleep 20

step "apps"
# T014: Battle.net on the image's GE-Proton, its installer reachable, and in
# Steam Game Mode (a Steam account folder stands in for a Steam login).
check "Battle.net launcher on GE-Proton" "${session} arkadeos-battlenet --check | grep -q '^proton=.*GE-Proton'"
check "Battle.net installer reachable" "curl -fsSL -o /dev/null -r 0-0 \"\$(grep -o 'https://downloader[^\"]*' /usr/bin/arkadeos-store)\""
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
    grep -qx Icon=/home/arkade/.local/share/icons/hicolor/256x256/apps/chrome-arktest-Default.png $f'
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
ssh_vm "cat /home/arkade/.local/state/arkadeos/dock-names.json" > "${out}/dock-names-apps.txt" 2>&1 || true
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
# Flatpak lets the desktop session's admin users install without a password;
# this shell is not that session, so root installs here.
check "Portal: Flatpak app in and out" "/usr/libexec/arkadeos/portal-item vesktop install &&
    test \$(${portal} vesktop status) = on &&
    /usr/libexec/arkadeos/portal-item vesktop remove && test \$(${portal} vesktop status) = off"
check "Portal: store launcher in and out" "${portal} ea install && test \$(${portal} ea status) = on &&
    test -f /home/arkade/.local/share/applications/org.arkadeos.EA.desktop &&
    ${portal} ea remove && test \$(${portal} ea status) = off"
check "Portal: Battle.net hidden and back" "${portal} battlenet remove && test \$(${portal} battlenet status) = off &&
    ${portal} battlenet install && test \$(${portal} battlenet status) = on"
check "Portal: switch item (tiling)" "${portal} tiling install && test \$(${portal} tiling status) = on &&
    ${portal} tiling remove && test \$(${portal} tiling status) = off"
check "Portal: AI pack not installed by default" "test \$(${portal} ollama status) = off && test \$(${portal} claude-code status) = off"
check "Portal: first-start choice saved" "/usr/libexec/arkadeos/apps-choose discord nonsense vlc &&
    test \"\$(cat /etc/arkadeos/apps)\" = \"\$(printf 'discord\\nvlc')\""
check "Portal: first-boot apps installed once, never again" "grep -qx vlc /var/lib/arkadeos/apps-done"
check "Portal: channel and graphics image" "test \$(arkadeos-update channel) = test && test \$(arkadeos-update gpu) = other"
check "Portal: desktop defaults restored" "runuser -u arkade -- sh -c 'rm -rf /tmp/rt && mkdir -p /tmp/rt/data &&
    cp -r /home/arkade/.config /tmp/rt/config &&
    XDG_CONFIG_HOME=/tmp/rt/config XDG_DATA_HOME=/tmp/rt/data /usr/libexec/arkadeos/reset-desktop' &&
    ls /tmp/rt/data/arkadeos/reset-*/kdeglobals && ! test -e /tmp/rt/config/kdeglobals"
ssh_vm "nohup ${session} arkadeos-portal >/tmp/portal.log 2>&1 & echo \$! > /tmp/portal.pid"
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
ssh_vm 'kill $(cat /tmp/portal.pid)' || true

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
check "game folders carry a SELinux label" '! stat -c %C /home/arkade/Games /home/arkade/.local/share/Steam | grep -q unlabeled_t'
if [[ -n "${UPDATE_PUSH:-}" ]]; then
    before=$(ssh_vm "bootc status --json | jq -r .status.booted.image.imageDigest")
    ssh_vm 'echo keep > /home/arkade/keep.txt'
    eval "${UPDATE_PUSH}"
    ssh_vm 'bootc upgrade' > "${out}/update.txt" 2>&1 || true
    ssh_vm 'rpm-ostree status' >> "${out}/update.txt" 2>&1 || true
    check "update waits for the reboot" 'test "$(bootc status --json | jq -r .status.staged.image.imageDigest)" != null'
    # T048: the top bar says so, once.
    ssh_vm "timeout 15 ${session} arkadeos-update notify" || true
    shot update-ready
    check "update ready message" 'test -s /home/arkade/.local/state/arkadeos/update-notified'
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
kill "$(cat "${out}/qemu.pid")" || true

cat "${out}/apps.txt"
exit "${failed}"
