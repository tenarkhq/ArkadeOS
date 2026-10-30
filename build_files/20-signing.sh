#!/usr/bin/bash
# Trusts the ArkadeOS signing key for ghcr.io/tenarkhq, so `bootc upgrade` and
# `bootc switch` only accept images built and signed by this repository.
set -euo pipefail

install -Dm0644 "${CTX}/cosign.pub" /etc/pki/containers/arkadeos.pub

entry='[{"type":"sigstoreSigned","keyPath":"/etc/pki/containers/arkadeos.pub","signedIdentity":{"type":"matchRepository"}}]'
found=0
for policy in /etc/containers/policy.json /usr/etc/containers/policy.json; do
    [[ -f "${policy}" ]] || continue
    jq --argjson e "${entry}" '.transports.docker["ghcr.io/tenarkhq"] = $e' "${policy}" > "${policy}.new"
    mv "${policy}.new" "${policy}"
    found=1
done
if [[ "${found}" -eq 0 ]]; then
    echo "no containers policy.json in the base image" >&2
    exit 1
fi
