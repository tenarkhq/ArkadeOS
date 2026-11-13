# Sourced by Plasma at login, before the desktop starts (T069). KDE keeps the
# icons it has drawn in ~/.cache/icon-cache.kcache and redraws them only when
# an icon folder's date changes; on ArkadeOS every system file keeps the same
# date, so a new image's icons never showed. When the image's icons differ
# from the last login's, the cache goes. ArkadeOS's own icons (the ArkadeOS
# Glass tray and app icons, T086; ours in hicolor) count by their drawing
# too: a redrawn icon keeps its name.
_arkadeos_key=$(cat /usr/share/icons/*/icon-theme.cache /usr/share/icons/arkadeos-glass/*/*/*.svg \
    /usr/share/icons/hicolor/scalable/apps/arkadeos-*.svg 2>/dev/null | md5sum | cut -d' ' -f1)
_arkadeos_stamp="${XDG_CACHE_HOME:-${HOME}/.cache}/arkadeos/icons-key"
if [ "$(cat "${_arkadeos_stamp}" 2>/dev/null)" != "${_arkadeos_key}" ]; then
    rm -f "${XDG_CACHE_HOME:-${HOME}/.cache}/icon-cache.kcache"
    mkdir -p "$(dirname "${_arkadeos_stamp}")" && echo "${_arkadeos_key}" > "${_arkadeos_stamp}"
fi
unset _arkadeos_key _arkadeos_stamp
