# T068: dock entries written before 2026-11-01 carried a Windows path's
# backslashes unescaped (KDE could not read them), and a Steam shortcut's
# window (steam_app_default) started its program without Steam. Those
# entries go; the dock writes them again, right, when the window next opens.
apps="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"
for f in "${apps}"/*.desktop; do
    [[ -f "${f}" ]] && grep -qx 'X-ArkadeOS-DockName=true' "${f}" || continue
    if grep -qP '(?<!\\)\\(?![\\\s])' "${f}" || [[ "$(basename "${f}")" == steam_app_default.desktop ]]; then
        rm -f "${f}"
    fi
done
