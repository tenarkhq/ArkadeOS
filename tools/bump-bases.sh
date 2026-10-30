#!/usr/bin/bash
# Pins every base in bases.txt to the digest its tag points at now.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp)
while read -r image ref; do
    if [[ -z "${image}" || "${image}" == \#* ]]; then
        printf '%s\n' "${image}${ref:+ ${ref}}" >> "${tmp}"
        continue
    fi
    tagged=${ref%@*}
    digest=$(skopeo inspect --no-tags --format '{{.Digest}}' "docker://${tagged}")
    printf '%s %s@%s\n' "${image}" "${tagged}" "${digest}" >> "${tmp}"
done < bases.txt
mv "${tmp}" bases.txt
git --no-pager diff --stat bases.txt
