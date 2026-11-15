# Before the desktop starts: widgets whose package has left the image leave
# the taskbar and desktop settings, so Plasma never shows their error
# placeholder (Roland, 2026-11-15, on the capsule's error icon appearing at
# login and vanishing a moment later). The capsule went on 2026-11-14 (T086).
f="${cfg}/plasma-org.kde.plasma.desktop-appletsrc"
[[ -f "${f}" ]] || exit 0
python3 -I /usr/libexec/arkadeos/applets-remove "${f}" org.arkadeos.capsule
