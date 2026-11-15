# A terminal opened in the home folder starts in its real path,
# /var/home/<user> (/home is a link to /var/home on ArkadeOS), so the prompt
# showed that path instead of ~ (Roland, 2026-11-15). The shell moves to the
# same folder under the home's own name.
if [ -n "${PS1-}" ] && [ -n "${HOME-}" ]; then
    _arkadeos_real=$(cd "${HOME}" 2>/dev/null && pwd -P)
    case "${PWD}/" in
        "${HOME}"/*) ;;
        "${_arkadeos_real}"/*)
            [ -n "${_arkadeos_real}" ] && [ "${_arkadeos_real}" != "${HOME}" ] &&
                cd "${HOME}${PWD#"${_arkadeos_real}"}" 2>/dev/null ;;
    esac
    unset _arkadeos_real
fi
