#!/usr/bin/bash
# Darkly (T086, Roland, 2026-11-14: "ez is illeszkedhetne rendesen a glasshoz
# ... nem csak egy fejléccel ... de ez igaz minden ablakra"): the widget
# style of every KDE window in ArkadeOS Glass. A fork of Breeze (through
# Lightly) that draws a window's background, sidebars, menu bar and toolbars
# see-through where the colour scheme says so, over the blur behind it
# (Better Blur DX); file lists and text stay solid. One change of ours: the
# toolbars take the window's colour, not the title area's (below). Colours come from the
# colour scheme, so the day/night switch restyles open windows too (Kvantum
# could not, T006). Built here from the pinned upstream release against the
# image's own Qt and Frameworks, in a throwaway stage; only the style and its
# settings page leave it (ArkadeOS keeps its own window frame).
#   darkly.sh <out dir>
set -euo pipefail
source "$(dirname "$0")/stage.sh"

out=$1
tag=v0.5.44 commit=473e799bae82a90d1752372acd3890c5adaed507
dnf -y -q install git cmake extra-cmake-modules gcc-c++ qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
    qt6-qtsvg-devel kf6-kconfig-devel kf6-kconfigwidgets-devel kf6-kcoreaddons-devel kf6-kguiaddons-devel kf6-ki18n-devel \
    kf6-kiconthemes-devel kf6-kwindowsystem-devel kf6-kcmutils-devel kf6-frameworkintegration-devel kf6-kirigami-devel \
    kdecoration-devel kf6-kcolorscheme-devel >/dev/null
git clone -q --depth 1 --branch "${tag}" https://github.com/Bali10050/Darkly /tmp/darkly
test "$(git -C /tmp/darkly rev-parse HEAD)" = "${commit}"
# ArkadeOS Glass (Roland, 2026-11-14, the approved design: "az átlátszóság
# az elvárás", "homogén konzisztens megjelenést"): only the title bar and the
# menu bar wear the sky-blue glass; the toolbars wear the window's own
# see-through neutral smoke, like the sidebars and the status bar. Upstream
# paints the toolbars in the title area's colour; this one line changes that.
python3 - /tmp/darkly/kstyle/darklystyle.cpp <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
old = """    // menubar and toolbar background should match for consistency
    QColor opacityBackground(
        _toolsAreaManager->palette().color((widget->isActiveWindow() || _matchInactiveTitleBar) ? QPalette::Active : QPalette::Inactive, QPalette::Window));"""
new = """    // ArkadeOS: the toolbar in the window's own colour, not the title area's
    QColor opacityBackground(
        widget->window()->palette().color((widget->isActiveWindow() || _matchInactiveTitleBar) ? QPalette::Active : QPalette::Inactive, QPalette::Window));"""
assert text.count(old) == 1, "Darkly's toolbar background moved: check the ArkadeOS patch"
open(path, "w").write(text.replace(old, new))
PY
cmake -S /tmp/darkly -B /tmp/darkly/build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_QT5=OFF -DBUILD_QT6=ON -DWITH_DECORATIONS=OFF -DBUILD_TESTING=OFF >/dev/null
cmake --build /tmp/darkly/build -j"$(nproc)" >/dev/null
DESTDIR=/tmp/stage cmake --install /tmp/darkly/build >/dev/null
for f in usr/lib64/qt6/plugins/styles/darkly6.so usr/lib64/qt6/plugins/kstyle_config/darklystyleconfig.so; do
    install -D -m 755 "/tmp/stage/${f}" "${out}/${f}"
done
install -D -m 644 /tmp/stage/usr/share/kstyle/themes/darkly.themerc "${out}/usr/share/kstyle/themes/darkly.themerc"
# Its source and licence go with it (GPL-2.0-or-later).
mkdir -p "${out}/usr/share/licenses/darkly"
cp /tmp/darkly/COPYING "${out}/usr/share/licenses/darkly/"
echo "Darkly ${tag} (${commit}), https://github.com/Bali10050/Darkly, built for Qt $(rpm -q --qf '%{VERSION}' qt6-qtbase)" \
    > "${out}/usr/share/licenses/darkly/SOURCE"
settle
ls -la "${out}/usr/lib64/qt6/plugins/styles/"
