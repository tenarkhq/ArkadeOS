#!/bin/bash
# Draft pictures for Roland (2026-11-13, "nézzük meg a bett blurt"): the
# desktop as it is, then with Better Blur DX. Runs in the VM as the user;
# the test takes the pictures between the steps.
#   draft.sh setup         window places, the same in every picture
#   draft.sh look <theme>  light|dark as it is now (KWin's own blur, on as on a real card)
#   draft.sh blur <theme>  Better Blur DX with see-through colours
#   draft.sh apps          Dolphin, System Settings and Konsole, opened again
set -u
D=/tmp/draft
kwin() { busctl --user call org.kde.KWin "$@"; }
case "$1" in
setup)
    cp $D/kwinrulesrc ~/.config/kwinrulesrc
    kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel false
    kwin /KWin org.kde.KWin reconfigure ;;
look)
    plasma-apply-lookandfeel -a "org.arkadeos.$2.desktop"
    kwriteconfig6 --file kwinrc --group Plugins --key better_blur_dxEnabled false
    kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true
    kwin /Effects org.kde.kwin.Effects unloadEffect s better_blur_dx
    kwin /Effects org.kde.kwin.Effects loadEffect s blur
    rm -f ~/.config/konsolerc
    sleep 10 ;;
blur)
    tag=Light; [ "$2" = dark ] && tag=Dark
    mkdir -p ~/.local/share/color-schemes ~/.local/share/konsole
    python3 $D/scheme.py "/usr/share/color-schemes/Breeze${tag}.colors" \
        ~/.local/share/color-schemes/ArkadeOSGlass${tag}.colors "ArkadeOS Glass ${tag}"
    plasma-apply-colorscheme "ArkadeOSGlass${tag}"
    cp $D/ArkadeGlass.colorscheme $D/Glass.profile ~/.local/share/konsole/
    kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile Glass.profile
    g="--file kwinrc --group Effect-better-blur-dx"
    kwriteconfig6 $g --key BlurStrength 12
    kwriteconfig6 $g --key NoiseStrength 2
    kwriteconfig6 $g --key Saturation 130
    kwriteconfig6 $g --key CornerRadius 6
    kwriteconfig6 $g --key WindowClasses "$(printf 'org.kde.dolphin\norg.kde.systemsettings\norg.kde.konsole\ndolphin\nsystemsettings\nkonsole')"
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
    sleep 5 ;;
apps)
    pkill -x dolphin; pkill -x systemsettings; pkill -x konsole; sleep 3
    nohup dolphin /usr/share/wallpapers > /dev/null 2>&1 &
    sleep 5
    nohup systemsettings kcm_colors > /dev/null 2>&1 &
    sleep 5
    nohup konsole -e bash -c 'fastfetch; exec sleep 3000' > /dev/null 2>&1 &
    sleep 15 ;;
esac
echo "== $*: effects loaded: $(kwin /Effects org.kde.kwin.Effects isEffectLoaded s blur) blur, $(kwin /Effects org.kde.kwin.Effects isEffectLoaded s better_blur_dx) better_blur_dx"
