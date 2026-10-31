#!/usr/bin/bash
# Desktop extras: LACT GPU control (T033), Polonium auto-tiling, off by
# default (T038), AirPlay receive and send, off by default (T040), what
# Toshy needs (T020).
set -euo pipefail

# T033: LACT from its author's COPR; lactd applies the GPU settings at boot.
dnf5 -y copr enable ilyaz/LACT
dnf5 -y install --setopt=install_weak_deps=False lact
dnf5 -y copr disable ilyaz/LACT
rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ilyaz:LACT.repo
systemctl enable lactd.service

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
test -f /usr/share/kwin/scripts/polonium/metadata.json

# T040: UxPlay (screen and sound from iPhone/Mac), Shairport Sync (AirPlay
# sound), PipeWire RAOP (sound to AirPlay speakers and Apple TV). Off until
# switched on (arkadeos-airplay on), as nothing runs in the background
# unasked (T050).
dnf5 -y install --setopt=install_weak_deps=False uxplay shairport-sync
test -f /usr/share/pipewire/pipewire.conf.avail/50-raop.conf

# T020: what Toshy (Mac keyboard, chosen in the Portal) builds against. Its
# setup layers whatever is missing with rpm-ostree, which would slow every
# update and need a reboot; with these in the image it layers nothing.
toshy_pkgs=(cairo-devel cairo-gobject-devel dbus-daemon dbus-devel evtest gcc git
    gobject-introspection-devel libappindicator-gtk3 libinput-utils libjpeg-turbo-devel
    libnotify libxkbcommon-devel python3-dbus python3-devel python3-pip python3-tkinter
    systemd-devel wayland-devel xset zenity)
dnf5 -y install --setopt=install_weak_deps=False "${toshy_pkgs[@]}"
rpm -q "${toshy_pkgs[@]}" >/dev/null
