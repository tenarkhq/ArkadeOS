#!/usr/bin/bash
# Languages (T010): English and Hungarian. Plasma and the apps carry their own
# translations; this adds the Hungarian spelling and hyphenation dictionaries.
set -euo pipefail

# The packages come from packages/install.sh.
rpm -q langpacks-hu hunspell-hu hyphen-hu

# Dolphin 26.08's new "Create missing folder" button has no Hungarian
# translation at KDE yet (Roland's screenshot, 2026-11-15). It goes into
# Dolphin's Hungarian catalogue until KDE's own arrives.
mo=/usr/share/locale/hu/LC_MESSAGES/dolphin.mo
if ! msgunfmt "${mo}" | grep -q '^msgid "Create missing folder"$'; then
    po=$(mktemp --suffix=.po)
    msgunfmt "${mo}" -o "${po}"
    printf '\nmsgctxt "@action"\nmsgid "Create missing folder"\nmsgstr "Hiányzó mappa létrehozása"\n' >> "${po}"
    msgfmt -o "${mo}" "${po}"
    rm -f "${po}"
fi
msgunfmt "${mo}" | grep -q '^msgid "Create missing folder"$'

# Pasting into the terminal (Roland, 2026-11-15): Fedora turns readline's
# bracketed paste off in /etc/inputrc, and a paste reached bash with the
# terminal's ^[[200~ markers around it, so the command broke. On, bash takes
# the paste as text and runs it only on Enter.
sed -i 's/^set enable-bracketed-paste off$/set enable-bracketed-paste on/' /etc/inputrc
grep -q '^set enable-bracketed-paste on$' /etc/inputrc
