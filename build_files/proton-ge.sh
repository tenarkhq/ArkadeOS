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

# The files live under /usr/lib/wine, where Fedora's base policy labels
# Wine's libraries textrel_shlib_t; Steam finds them through a link. A
# derived image's own policy rules do not label its files (Fedora ostree SIG
# issue 45), and with lib_t SELinux stops 32-bit programs (the Battle.net
# installer) with execmod.
lib=/usr/lib/wine/ge-proton
mkdir -p "${dir}" "${lib}"
tar -xzf "${file}" -C "${lib}"
rm "${file}"
for d in "${lib}"/*; do
    ln -s "${d}" "${dir}/$(basename "${d}")"
done
matchpathcon "${lib}"/*/files/lib/wine/i386-windows/ntdll.dll | grep -q textrel_shlib_t
ls "${dir}"
