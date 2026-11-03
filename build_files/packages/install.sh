#!/usr/bin/bash
# The image's packages, in an image layer of their own (T081): it is rebuilt
# only when the base or a script in this folder changes, not on every change
# to ArkadeOS's own files, which build.sh adds on top in a few minutes. What
# each package is for, and how it is set up, is in the numbered scripts.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
nodeps=(--setopt=install_weak_deps=False)

# T002: the Bazzite parts ArkadeOS does not need.
bash "${here}/remove.sh"

# T003 (60-gaming.sh): GameMode and the Steam Game Mode session.
dnf5 -y install "${nodeps[@]}" gamemode gamemode.i686
dnf5 -y install --enable-repo=terra "${nodeps[@]}" gamescope-session gamescope-session-steam

# T013 (63-asus.sh): asusctl and ROG Control Center. The COPRs go after use:
# the image brings updates, not dnf on the installed system.
dnf5 -y copr enable lukenukem/asus-linux
dnf5 -y install "${nodeps[@]}" asusctl asusctl-rog-gui
dnf5 -y copr disable lukenukem/asus-linux
rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lukenukem:asus-linux.repo

# T046, T047: Lenovo Legion and MSI; their driver is signed with the
# ArkadeOS module key (its certificate, also in system_files).
install -Dm0644 "${here}/arkadeos-mok.der" /etc/pki/arkadeos/arkadeos-mok.der
bash "${here}/legion-msi.sh"

# T042-T045, T052 (64-peripherals.sh): RGB, mice, AIO coolers, fan curves.
dnf5 -y install "${nodeps[@]}" openrgb piper libratbag-ratbagd solaar solaar-udev liquidctl
dnf5 -y copr enable codifryed/CoolerControl
dnf5 -y install "${nodeps[@]}" coolercontrol coolercontrold
dnf5 -y copr disable codifryed/CoolerControl
rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:codifryed:CoolerControl.repo

# T010 (65-language.sh): Hungarian spelling and hyphenation.
dnf5 -y install "${nodeps[@]}" langpacks-hu hunspell-hu hyphen-hu

# T033 (69-desktop-extras.sh): LACT.
dnf5 -y copr enable ilyaz/LACT
dnf5 -y install "${nodeps[@]}" lact
dnf5 -y copr disable ilyaz/LACT
rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ilyaz:LACT.repo

# T038: Polonium, a pinned release checked against its checksum.
polonium_version=1.2.2
polonium_sha256=2609ae7a85d90bd16144dd1fef6dbab44d5f48c25169da264c15809e7763d7f7
tmp=$(mktemp -d)
curl -fsSL --retry 3 -o "${tmp}/polonium.kwinscript" \
    "https://github.com/zeroxoneafour/polonium/releases/download/v${polonium_version}/polonium.kwinscript"
echo "${polonium_sha256}  ${tmp}/polonium.kwinscript" | sha256sum -c -
mkdir -p /usr/share/kwin/scripts/polonium
unzip -q "${tmp}/polonium.kwinscript" -d "${tmp}"
cp -r "${tmp}/pkg/." /usr/share/kwin/scripts/polonium/
rm -rf "${tmp}"

# T040: AirPlay receive (UxPlay, Shairport Sync).
dnf5 -y install "${nodeps[@]}" uxplay shairport-sync

# T020: what Toshy (Mac keyboard, chosen in the Portal) builds against. Its
# setup layers whatever is missing with rpm-ostree, which would slow every
# update and need a reboot; with these in the image it layers nothing.
toshy_pkgs=(cairo-devel cairo-gobject-devel dbus-daemon dbus-devel evtest gcc git
    gobject-introspection-devel libappindicator-gtk3 libinput-utils libjpeg-turbo-devel
    libnotify libxkbcommon-devel python3-dbus python3-devel python3-pip python3-tkinter
    systemd-devel wayland-devel xset zenity)
dnf5 -y install "${nodeps[@]}" "${toshy_pkgs[@]}"
rpm -q "${toshy_pkgs[@]}" >/dev/null

# T006, T069 (70-theme.sh): the Inter font, the Kvantum app style, and Solid
# rebuilt with ArkadeOS's patch (solid.sh, its own build stage).
dnf5 -y install "${nodeps[@]}" rsms-inter-fonts kvantum
dnf -y -q install /solid/kf6-solid-*.rpm
