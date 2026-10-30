#!/usr/bin/bash
# Look (T006): the WhiteSur files come from whitesur.sh in their own layer;
# this adds the Kvantum style engine, the Inter font and the GTK defaults.
set -euo pipefail

dnf5 -y install --setopt=install_weak_deps=False kvantum rsms-inter-fonts
glib-compile-schemas /usr/share/glib-2.0/schemas
