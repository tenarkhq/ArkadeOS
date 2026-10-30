#!/usr/bin/bash
# Layout (T007): the bar, dock, window buttons and hot corners are config files
# under system_files; this adds Meta+Space for KRunner, like Spotlight.
set -euo pipefail

sed -i 's/^X-KDE-Shortcuts=Alt+Space,Alt+F2,Search$/&,Meta+Space/' /usr/share/kglobalaccel/org.kde.krunner.desktop
grep -q '^X-KDE-Shortcuts=.*,Meta+Space$' /usr/share/kglobalaccel/org.kde.krunner.desktop
