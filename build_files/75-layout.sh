#!/usr/bin/bash
# Layout (T007) and Windows keys (T008). The bar, dock, window buttons and hot
# corners are config files under system_files; this sets the shortcuts that
# come from desktop files: Meta+Space for KRunner, like Spotlight, and the
# Windows keys below.
set -euo pipefail

sed -i 's/^X-KDE-Shortcuts=Alt+Space,Alt+F2,Search$/&,Meta+Space/' /usr/share/kglobalaccel/org.kde.krunner.desktop
grep -q '^X-KDE-Shortcuts=.*,Meta+Space$' /usr/share/kglobalaccel/org.kde.krunner.desktop

# Windows keys (T008): Meta+Shift+S cuts out a region (Snipping Tool),
# Ctrl+Shift+Esc opens the System Monitor (Task Manager).
spectacle=/usr/share/applications/org.kde.spectacle.desktop
sed -i -e 's/^X-KDE-Shortcuts=Print,Meta+Shift+S$/X-KDE-Shortcuts=Print/' \
    -e 's/^X-KDE-Shortcuts=Meta+Shift+Print$/&,Meta+Shift+S/' "${spectacle}"
grep -qx 'X-KDE-Shortcuts=Meta+Shift+Print,Meta+Shift+S' "${spectacle}"
for f in /usr/share/applications/org.kde.plasma-systemmonitor.desktop /usr/share/kglobalaccel/org.kde.plasma-systemmonitor.desktop; do
    sed -i 's/^X-KDE-Shortcuts=Meta+Esc$/&,Ctrl+Shift+Esc/' "${f}"
    grep -qx 'X-KDE-Shortcuts=Meta+Esc,Ctrl+Shift+Esc' "${f}"
done

# Ark logo on the launcher (T009): our icon files went in after whitesur.sh
# built the caches.
for theme in hicolor WhiteSur WhiteSur-dark; do
    gtk-update-icon-cache -f -q "/usr/share/icons/${theme}"
done
