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
# Wine's libraries need the label Fedora gives its own Wine; without it
# SELinux stops 32-bit programs (the Battle.net installer) with execmod.
semanage fcontext -a -t textrel_shlib_t "${dir}/[^/]+/files/lib(64)?/wine(/.*)?"
ls "${dir}"
