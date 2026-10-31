#!/usr/bin/bash
# What a base update brings (T048): kernel, Mesa and NVIDIA driver versions
# of the pinned bases before and after, from bases.txt in git (HEAD) and now.
#   base-changes.sh      one line per image and package that changed
set -euo pipefail
cd "$(dirname "$0")/.."

versions() {
    podman run --rm "$1" rpm -qa --qf '%{NAME} %{VERSION}\n' |
        grep -E '^(kernel|mesa-dri-drivers|kmod-nvidia[^ ]*|nvidia-driver) ' | sort -u
}

git show HEAD:bases.txt | grep -v '^#' | while read -r image old; do
    new=$(awk -v i="${image}" '$1 == i { print $2 }' bases.txt)
    [[ -n "${old}" && "${old}" != "${new}" ]] || continue
    join -a2 -e - -o 0,1.2,2.2 <(versions "${old}") <(versions "${new}") |
        awk -v i="${image}" '$2 != $3 { print i ": " $1 " " $2 " → " $3 }'
done
