# Roland, 2026-11-15: the Bluetooth switch's knob stayed dark after its fix.
# Union, the style engine of System Settings, kept a compiled copy of the
# style from the first start in ~/.cache/union and trusted it while the
# files' modification times matched, and OSTree gives every image the same
# times. The launchers now turn that cache off (build_files/70-theme.sh); the
# copy left from the earlier image is never read again and goes.
cache="${XDG_CACHE_HOME:-${HOME}/.cache}/union"
[[ -d "${cache}" ]] || exit 0
rm -rf -- "${cache}"
