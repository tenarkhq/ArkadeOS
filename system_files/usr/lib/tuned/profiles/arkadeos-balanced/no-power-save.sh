#!/usr/bin/bash
# In the Kiegyensúlyozott mode (Portal) the devices save power on the charger
# too: nothing is kept awake here. Gaming, Max and WoW run their own copy and
# keep everything awake in both modes.
[[ "$(/usr/libexec/arkadeos/mode pick keep save)" == save ]] && exit 0
ARKADEOS_KEEP_PCI_PM=1 exec /usr/libexec/arkadeos/no-power-save "$@"
