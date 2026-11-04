# Roland, 2026-11-04 (T079): the Codex CLI from OpenAI's own installer, like
# the Claude CLI; a Homebrew Codex moves over, its settings in ~/.codex stay.
# Without the network it fails and runs again at the next login.
if [[ ! -x "${HOME}/.local/bin/codex" ]] && /home/linuxbrew/.linuxbrew/bin/brew list codex &>/dev/null; then
    timeout 300 /usr/libexec/arkadeos/portal-item codex install
fi
