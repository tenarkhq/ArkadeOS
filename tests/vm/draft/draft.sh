#!/bin/bash
# Draft pictures for Roland (2026-11-13: "nézzük meg a bett blurt", then "hol
# átlátszó a tálca v az ablakok fejléce? mint a windows7nél anno"): the
# desktop as it is, then Aero-style glass with Better Blur DX: the taskbar and
# the title bars see-through and blurred, the window contents solid. Runs in
# the VM as the user; the test takes the pictures between the steps.
#   draft.sh setup              window places, the same in every picture
#   draft.sh wall <name>        wallpaper from /usr/share/wallpapers
#   draft.sh look <theme>       light|dark as it is now (KWin's own blur, on as on a real card)
#   draft.sh aero <theme> <alpha> [r,g,b]   glass title bars and taskbar
#   draft.sh apps               Dolphin, System Settings and Konsole, opened again
set -u
D=/tmp/draft
kwin() { busctl --user call org.kde.KWin "$@"; }
panel() {  # 0 adaptive (Plasma's own), 2 translucent
    local ids
    ids=$(sed -n 's/^\[PlasmaViews\]\[Panel \([0-9]*\)\]$/\1/p' ~/.config/plasmashellrc 2>/dev/null | sort -u)
    for i in ${ids:-1 2 3 4}; do
        kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $i" --key panelOpacity "$1"
    done
    systemctl --user restart plasma-plasmashell.service || { kquitapp6 plasmashell; sleep 2; nohup plasmashell > /dev/null 2>&1 & }
    sleep 15
}
case "$1" in
setup)
    cp $D/kwinrulesrc ~/.config/kwinrulesrc
    kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel false
    kwin /KWin org.kde.KWin reconfigure ;;
wall)
    plasma-apply-wallpaperimage "/usr/share/wallpapers/$2"
    sleep 3 ;;
look)
    plasma-apply-lookandfeel -a "org.arkadeos.$2.desktop"
    kwriteconfig6 --file kwinrc --group Plugins --key better_blur_dxEnabled false
    kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true
    kwin /Effects org.kde.kwin.Effects unloadEffect s better_blur_dx
    kwin /Effects org.kde.kwin.Effects loadEffect s blur
    panel 0 ;;
aero)
    tag=Light; [ "$2" = dark ] && tag=Dark
    name="ArkadeOS Glass ${tag} ${3}${4:+ tint}"
    file="ArkadeOSGlass${tag}${3}${4:+Tint}"
    mkdir -p ~/.local/share/color-schemes
    MODE=aero ALPHA="$3" TINT="${4:-}" python3 $D/scheme.py "/usr/share/color-schemes/Breeze${tag}.colors" \
        ~/.local/share/color-schemes/${file}.colors "${name}"
    plasma-apply-colorscheme "${file}"
    g="--file kwinrc --group Effect-better-blur-dx"
    kwriteconfig6 $g --key BlurStrength 12
    kwriteconfig6 $g --key NoiseStrength 2
    kwriteconfig6 $g --key Saturation 140
    kwriteconfig6 $g --key CornerRadius 6
    kwriteconfig6 $g --key WindowClasses ""
    kwriteconfig6 $g --key BlurMatching true
    kwriteconfig6 $g --key BlurNonMatching false
    kwriteconfig6 $g --key BlurDecorations true
    kwriteconfig6 $g --key BlurMenus true
    kwriteconfig6 $g --key BlurDocks true
    kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
    kwriteconfig6 --file kwinrc --group Plugins --key better_blur_dxEnabled true
    kwin /Effects org.kde.kwin.Effects unloadEffect s blur
    kwin /Effects org.kde.kwin.Effects loadEffect s better_blur_dx
    kwin /Effects org.kde.kwin.Effects reconfigureEffect s better_blur_dx
    panel 2 ;;
apps)
    pkill -x dolphin; pkill -x systemsettings; pkill -x konsole; sleep 3
    nohup dolphin /usr/share/wallpapers > /dev/null 2>&1 &
    sleep 5
    nohup systemsettings kcm_colors > /dev/null 2>&1 &
    sleep 5
    nohup konsole -e bash -c 'fastfetch; exec sleep 3000' > /dev/null 2>&1 &
    sleep 15 ;;
esac
echo "== $*: blur $(kwin /Effects org.kde.kwin.Effects isEffectLoaded s blur), better_blur_dx $(kwin /Effects org.kde.kwin.Effects isEffectLoaded s better_blur_dx), panel $(grep -h panelOpacity ~/.config/plasmashellrc 2>/dev/null | sort -u | tr '\n' ' ')"
