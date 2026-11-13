#!/usr/bin/bash
# Better Blur DX (T086): KWin's blur with force blur for the ArkadeOS Glass
# frame and its adjustable strength, colour and corners. A KWin effect works
# only with the exact KWin it was built for, so it is built here from the
# pinned upstream release against the image's own KWin, in a throwaway stage;
# only the two plugins leave it.
#   better-blur.sh <out dir>
set -euo pipefail
source "$(dirname "$0")/stage.sh"

out=$1
tag=v2.6.0 commit=811bce88af12b15be01d1b388dc5174451450362
kwin=$(rpm -q --qf '%{VERSION}-%{RELEASE}' kwin)
dnf -y -q install git cmake extra-cmake-modules gcc-c++ "kwin-devel-${kwin}" kf6-kwindowsystem-devel \
    plasma-workspace-devel libplasma-devel qt6-qtbase-private-devel qt6-qtbase-devel kf6-knotifications-devel \
    kf6-kio-devel kf6-kcrash-devel kf6-ki18n-devel kf6-kguiaddons-devel libepoxy-devel kf6-kglobalaccel-devel \
    kf6-kcmutils-devel kf6-kconfigwidgets-devel kf6-kdeclarative-devel kdecoration-devel wayland-devel libdrm-devel >/dev/null
git clone -q --depth 1 --branch "${tag}" https://github.com/xarblu/kwin-effects-better-blur-dx /tmp/bbdx
test "$(git -C /tmp/bbdx rev-parse HEAD)" = "${commit}"
cmake -S /tmp/bbdx -B /tmp/bbdx/build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build /tmp/bbdx/build -j"$(nproc)" >/dev/null
DESTDIR=/tmp/stage cmake --install /tmp/bbdx/build >/dev/null
mkdir -p "${out}/usr/lib64/qt6/plugins/kwin/effects/plugins" "${out}/usr/lib64/qt6/plugins/kwin/effects/configs"
cp /tmp/stage/usr/lib64/qt6/plugins/kwin/effects/plugins/better_blur_dx.so "${out}/usr/lib64/qt6/plugins/kwin/effects/plugins/"
cp /tmp/stage/usr/lib64/qt6/plugins/kwin/effects/configs/kwin_better_blur_dx_config.so "${out}/usr/lib64/qt6/plugins/kwin/effects/configs/"
# Its source and licence go with it (GPL-3.0).
mkdir -p "${out}/usr/share/licenses/kwin-effects-better-blur-dx"
cp /tmp/bbdx/LICENSE "${out}/usr/share/licenses/kwin-effects-better-blur-dx/" 2>/dev/null ||
    cp /tmp/bbdx/COPYING "${out}/usr/share/licenses/kwin-effects-better-blur-dx/"
echo "Better Blur DX ${tag} (${commit}), https://github.com/xarblu/kwin-effects-better-blur-dx, built for KWin ${kwin}" \
    > "${out}/usr/share/licenses/kwin-effects-better-blur-dx/SOURCE"
settle
ls -la "${out}/usr/lib64/qt6/plugins/kwin/effects/plugins/"
