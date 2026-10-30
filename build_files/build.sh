#!/usr/bin/bash
# Runs inside the image build. Each step is its own script under build_files/.
set -euo pipefail

CTX=/ctx
export CTX

for step in "${CTX}"/build_files/[0-9][0-9]-*.sh; do
    echo "::group::${step##*/}"
    bash "${step}"
    echo "::endgroup::"
done
