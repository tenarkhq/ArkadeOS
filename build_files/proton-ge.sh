#!/usr/bin/bash
# Installs one GE-Proton release for every user, where Steam finds it next to
# its own Proton versions (T003). Usage: proton-ge.sh <GE-ProtonX-Y>
set -euo pipefail

version=$1
dir=/usr/share/steam/compatibilitytools.d
url=https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${version}

cd /tmp
file=${version}-x86_64.tar.gz
curl -fsSL --retry 3 -o "${file}" "${url}/${file}"
expected=$(curl -fsSL --retry 3 "${url}/${version}-x86_64.sha512sum" | cut -d' ' -f1)
echo "${expected}  ${file}" | sha512sum -c -

mkdir -p "${dir}"
tar -xzf "${file}" -C "${dir}"
rm "${file}"
ls "${dir}"
