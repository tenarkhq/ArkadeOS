#!/usr/bin/bash
# Languages (T010): English and Hungarian. Plasma and the apps carry their own
# translations; this adds the Hungarian spelling and hyphenation dictionaries.
set -euo pipefail

dnf5 -y install --setopt=install_weak_deps=False langpacks-hu hunspell-hu hyphen-hu
rpm -q hunspell-hu hyphen-hu
