#!/usr/bin/bash
# Languages (T010): English and Hungarian. Plasma and the apps carry their own
# translations; this adds the Hungarian spelling and hyphenation dictionaries.
set -euo pipefail

# The packages come from packages/install.sh.
rpm -q langpacks-hu hunspell-hu hyphen-hu

# Dolphin 26.08's new "Create missing folder" button has no Hungarian
# translation at KDE yet (Roland's screenshot, 2026-11-15). It goes into
# Dolphin's Hungarian catalogue until KDE's own arrives.
# (Through a file, not a pipe: grep -q ending the pipe early is a failure
# under pipefail.)
mo=/usr/share/locale/hu/LC_MESSAGES/dolphin.mo
po=$(mktemp --suffix=.po)
msgunfmt "${mo}" -o "${po}"
if ! grep -q '^msgid "Create missing folder"$' "${po}"; then
    printf '\nmsgctxt "@action"\nmsgid "Create missing folder"\nmsgstr "Hiányzó mappa létrehozása"\n' >> "${po}"
    msgfmt -o "${mo}" "${po}"
    msgunfmt "${mo}" -o "${po}"
fi
grep -q '^msgid "Create missing folder"$' "${po}"
rm -f "${po}"

# Pasting into the terminal (Roland, 2026-11-15): Fedora's bash has
# readline's bracketed paste off, and a paste reached bash with the
# terminal's ^[[200~ markers around it, so the command broke. On, bash takes
# the paste as text and runs it only on Enter.
if ! grep -qx 'set enable-bracketed-paste on' /etc/inputrc; then
    printf '\n# ArkadeOS: a paste is taken as text and runs on Enter.\nset enable-bracketed-paste on\n' >> /etc/inputrc
fi
grep -qx 'set enable-bracketed-paste on' /etc/inputrc
