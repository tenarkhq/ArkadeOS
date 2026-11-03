#!/usr/bin/bash
# Languages (T010): English and Hungarian. Plasma and the apps carry their own
# translations; this adds the Hungarian spelling and hyphenation dictionaries.
set -euo pipefail

# The packages come from packages/install.sh.
rpm -q langpacks-hu hunspell-hu hyphen-hu
