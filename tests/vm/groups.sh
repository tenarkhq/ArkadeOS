#!/usr/bin/bash
# The VM test parts the changes between two commits reach (run.sh,
# TEST_GROUPS), printed as a comma list. A file this does not know, or one
# that every part stands on (the image build, the boot, the services), means
# all of them; a change in run.sh means the part the changed lines are in.
# Parts that are wrongly left out still run at night: the nightly build runs
# every part, and only a build that passed them all becomes stable.
#   groups.sh <from commit> <to commit>
set -euo pipefail

from=$1 to=$2
run=tests/vm/run.sh

declare -A want=()
all=0
add() { for g in "$@"; do want[${g}]=1; done; }

# The part of run.sh each changed line is in: between "if want <part>" and
# "fi # <part>"; lines outside the parts run every time anyway.
run_parts() {
    git diff -U0 "${from}" "${to}" -- "${run}" | sed -n 's/^@@ .* +\([0-9]*\).* @@.*/\1/p' |
        while read -r n; do
            git show "${to}:${run}" | awk -v n="${n}" '
                NR > n { exit }
                /^if want [a-z-]+; then$/ { part = $3; sub(/;$/, "", part) }
                /^fi # / { if (NR < n) part = "" }
                END { if (part != "") print part }'
        done
}

while read -r f; do
    [[ -z "${f}" ]] && continue
    case "${f}" in
        "${run}") add $(run_parts) ;;
        # How the image is built and published, not what is in it: the
        # update from a registry is what it can break.
        .github/workflows/build.yml) add update update-path ;;
        # Not in the image.
        *.md | docs/* | art/* | iso/* | tests/iso/* | .github/workflows/iso.yml | \
        .github/workflows/promote.yml | .github/workflows/prefetch.yml | tools/prefetch.py | \
        tests/vm/groups.sh) ;;
        # Portal-picked parts have their own test (choices.sh), the update
        # from the previous build its own (update-path.sh).
        tests/vm/choices.sh) add choices ;;
        tests/vm/update-path.sh) add update-path ;;
        tests/vm/portal-games.py | tests/vm/portal-update.py | tests/vm/apps.txt) add apps ;;
        tests/vm/proton-test.bat | tests/vm/kwin-probe*) add games ;;
        # The look: theme, icons, wallpapers, taskbar, app style.
        build_files/70-theme.sh | build_files/75-layout.sh | tests/vm/taskbar.py | \
        build_files/solid.sh | build_files/patches/* | \
        system_files/usr/share/plasma/* | system_files/usr/share/icons/* | \
        system_files/usr/share/wallpapers/* | system_files/usr/share/plymouth/* | \
        system_files/usr/libexec/arkadeos/session-setup | system_files/usr/libexec/arkadeos/places-setup | \
        system_files/usr/libexec/arkadeos/root-hidden | system_files/usr/libexec/arkadeos/desktop-setup | \
        system_files/usr/lib/systemd/system/arkadeos-root-hidden.service) add look games ;;
        # KWin scripts: window rules, dock names, borderless full screen.
        system_files/usr/share/kwin/* | system_files/usr/libexec/arkadeos/dock-names) add games apps ;;
        # Power profiles, laptops' and makers' parts, lighting.
        build_files/62-power.sh | build_files/63-*.sh | build_files/64-peripherals.sh | \
        system_files/usr/lib/tuned/* | system_files/etc/tuned/* | system_files/usr/lib/sysctl.d/* | \
        system_files/usr/bin/arkadeos-power | system_files/usr/bin/arkadeos-vendor | system_files/usr/bin/arkadeos-rgb | \
        system_files/usr/libexec/arkadeos/lamparray | system_files/usr/lib/udev/rules.d/90-arkadeos-lamparray.rules | \
        system_files/usr/libexec/arkadeos/power-* | system_files/usr/libexec/arkadeos/gpu-cap | \
        system_files/usr/libexec/arkadeos/no-power-save | system_files/usr/libexec/arkadeos/vendor-* | \
        system_files/usr/libexec/arkadeos/asus-defaults | system_files/usr/libexec/arkadeos/x3d-vcache) add power games apps ;;
        # Games: Proton, the game watcher and its profiles.
        build_files/60-gaming.sh | build_files/proton-ge.sh | \
        system_files/usr/libexec/arkadeos/game-profile | system_files/usr/libexec/arkadeos/no-game-running) add games power ;;
        # Apps, stores, the Portal.
        build_files/66-apps.sh | build_files/69-desktop-extras.sh | \
        system_files/usr/bin/arkadeos-portal | system_files/usr/libexec/arkadeos/portal-item | \
        system_files/usr/libexec/arkadeos/apps-* | \
        system_files/usr/libexec/arkadeos/ai-desktop | system_files/usr/lib/systemd/user/arkadeos-ai-update.* | \
        system_files/usr/share/arkadeos/portal/* | system_files/etc/xdg/autostart/* | \
        system_files/usr/bin/arkadeos-airplay | system_files/usr/bin/arkadeos-anticheat | \
        system_files/usr/bin/arkadeos-battlenet | system_files/usr/bin/arkadeos-ea | system_files/usr/bin/arkadeos-ubisoft | \
        system_files/usr/bin/arkadeos-store | system_files/usr/bin/arkadeos-wowup | system_files/usr/bin/arkadeos-webapp | \
        system_files/usr/bin/arkadeos-tiling | system_files/usr/bin/arkadeos-firmware | system_files/usr/bin/arkadeos-monitor) add apps choices ;;
        # The login screen.
        system_files/usr/lib/plasmalogin/*) add look ;;
        # Updates, rollback, reset, the boot menu.
        build_files/68-updates.sh | system_files/usr/bin/arkadeos-update | \
        system_files/usr/libexec/arkadeos/migrate | system_files/usr/libexec/arkadeos/reset-* | \
        system_files/usr/libexec/arkadeos/home-snapshots | system_files/usr/libexec/arkadeos/windows-entry) add update update-path apps ;;
        *) all=1 ;;
    esac
done < <(git diff --name-only "${from}" "${to}")

if (( all )); then
    echo all
elif (( ${#want[@]} == 0 )); then
    # Only the boot and the desktop, which run every time.
    echo none
else
    (IFS=,; echo "${!want[*]}")
fi
