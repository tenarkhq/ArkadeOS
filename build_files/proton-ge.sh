#!/usr/bin/bash
# Makes one GE-Proton release for every user, where Steam finds it next to
# its own Proton versions (T003), under OUT in a side stage of the build: the
# Containerfile copies it in as a layer of its own, the same bytes for the
# same release whatever else changed in the image (T076).
# Usage: proton-ge.sh <GE-ProtonX-Y> <OUT>
set -euo pipefail
umask 022
source "$(dirname "$0")/stage.sh"

version=$1 out=$2
dir=/usr/share/steam/compatibilitytools.d
url=https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${version}

cd /tmp
file=${version}-x86_64.tar.gz
curl -fsSL --retry 3 -o "${file}" "${url}/${file}"
expected=$(curl -fsSL --retry 3 "${url}/${version}-x86_64.sha512sum" | cut -d' ' -f1)
echo "${expected}  ${file}" | sha512sum -c -

# The files live under /usr/lib/wine, where Fedora's base policy labels
# Wine's libraries textrel_shlib_t (60-gaming.sh checks it). A derived image's
# own policy rules do not label its files (Fedora ostree SIG issue 45), and
# with lib_t SELinux stops 32-bit programs (the Battle.net installer) with
# execmod. Steam and umu find them in compatibilitytools.d through a bind
# mount: Steam's runtime container takes Proton from there, but not from a
# link into the rest of /usr.
lib=/usr/lib/wine/ge-proton
units=/usr/lib/systemd/system
mkdir -p "${out}${dir}" "${out}${lib}" "${out}${units}/local-fs.target.wants"
tar -xzf "${file}" --no-same-owner -C "${out}${lib}"
rm "${file}"
for d in "${out}${lib}"/*; do
    name=$(basename "${d}")
    where=${dir}/${name}
    mkdir "${out}${where}"
    unit=$(systemd-escape -p --suffix=mount "${where}")
    cat > "${out}${units}/${unit}" <<UNIT
[Unit]
Description=GE-Proton under Wine's SELinux labels (proton-ge.sh)
DefaultDependencies=no
Before=local-fs.target

[Mount]
What=${lib}/${name}
Where=${where}
Type=none
Options=bind

[Install]
WantedBy=local-fs.target
UNIT
    ln -s "../${unit}" "${out}${units}/local-fs.target.wants/${unit}"
done
settle
ls "${out}${dir}" "${out}${units}/local-fs.target.wants"
