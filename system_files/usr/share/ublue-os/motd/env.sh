#!/usr/bin/env sh
# ArkadeOS terminal welcome (T073), in place of Bazzite's: the image and the
# channel actually running (read from the booted deployment, the image's own
# file only says what it was built as), ArkadeOS texts and tips, Hungarian
# when the system speaks Hungarian. KEEP THIS SMALL: it runs in every new
# terminal.
_motd_info="${MOTD_IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
_motd_dep=$(sed -n 's/.*ostree=\([^ ]*\).*/\1/p' /proc/cmdline 2>/dev/null)
_motd_ref=""
if [ -n "${_motd_dep}" ]; then
  _motd_ref=$(sed -n 's/^container-image-reference=//p' "$(readlink -f "/sysroot${_motd_dep}").origin" 2>/dev/null)
fi
[ -n "${_motd_ref}" ] || _motd_ref="$(jq -rc '."image-ref"' "${_motd_info}"):$(jq -rc '."image-tag"' "${_motd_info}")"
export MOTD_IMAGE_NAME="$(printf '%s' "${_motd_ref}" | sed -e 's@^ostree-[a-z-]*:@@' -e 's@^docker://@@')"
export MOTD_IMAGE_VERSION="$(jq -rc '."version"' "${_motd_info}")"
case "${LC_MESSAGES:-${LANG:-C}}" in
  hu*) _motd_lang=hu ;;
  *) _motd_lang=en ;;
esac
export MOTD_TEMPLATE_FILE="${MOTD_TEMPLATE_FILE:-/usr/share/arkadeos/motd/template.${_motd_lang}.md}"
export MOTD_TIP="${MOTD_TIP:-"$(cat /usr/share/arkadeos/motd/tips/${_motd_lang}/*.md 2>/dev/null | shuf -n 1)"}"
export GLOW_STYLE="${GLOW_STYLE:-/usr/share/arkadeos/motd/style.json}"
if [ -f /etc/motd.d/boot-status ] && ! grep -q "status is GREEN" /etc/motd.d/boot-status; then
  export MOTD_GREENBOOT="$(cat /etc/motd.d/boot-status)"
elif [ "${_motd_lang}" = hu ]; then
  export MOTD_GREENBOOT='Rendszer: rendben 󰄳'
else
  export MOTD_GREENBOOT='System: healthy 󰄳'
fi
unset _motd_info _motd_dep _motd_ref _motd_lang
