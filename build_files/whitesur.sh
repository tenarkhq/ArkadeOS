#!/usr/bin/bash
# WhiteSur look (T006): KDE parts, GTK, icons and cursor, from pinned upstream
# commits. Runs in its own image layer, like Proton-GE, so the build server
# reuses it until a pin changes. Apple artwork stays out: no wallpapers, no
# look-and-feel previews, no Apple logo icons (our own global themes are in
# system_files/usr/share/plasma/look-and-feel).
set -euo pipefail

# repo commit sha256-of-tarball
PINS=(
    "WhiteSur-kde cf4df59ce91004f7ea39358b1b8ff917d5c329f7 afc06ef1c21ec316f7a7c51b36bee650d0394cf60ed8302802b3c16c0cc9ba5e"
    "WhiteSur-gtk-theme 99247ecd219bdc1c7409baff062b4aafcf1102a7 5c450592ff55bcae98b19d6408d1462288d81e8787b5ef3a96b445a1a35429d2"
    "WhiteSur-icon-theme 73d8040da51a9ed74e47c7366e7e9ff437601a5c 96661649071d8a9664b40d42abea75286175234473106156e9a4b25f54e6cb0c"
    "WhiteSur-cursors e190baf618ed95ee217d2fd45589bd309b37672b 35c817c2c26bc4d2c06801cfe6c924a068ad771d3846c5203b04d1c893dd5664"
)

src=/tmp/whitesur
mkdir -p "${src}"
for pin in "${PINS[@]}"; do
    read -r repo commit sum <<<"${pin}"
    curl -fsSL --retry 3 -o "${src}/${repo}.tar.gz" "https://github.com/vinceliuice/${repo}/archive/${commit}.tar.gz"
    echo "${sum}  ${src}/${repo}.tar.gz" | sha256sum -c -
    mkdir "${src}/${repo}"
    tar -xzf "${src}/${repo}.tar.gz" -C "${src}/${repo}" --strip-components=1
done

# KDE: colour schemes, Plasma styles, window decorations, Kvantum (light and
# dark of each).
kde=${src}/WhiteSur-kde
install -d /usr/share/color-schemes /usr/share/plasma/desktoptheme /usr/share/aurorae/themes /usr/share/Kvantum
cp "${kde}"/color-schemes/{WhiteSur,WhiteSurDark}.colors /usr/share/color-schemes/
for variant in WhiteSur WhiteSur-dark; do
    cp -r "${kde}/plasma/desktoptheme/${variant}" /usr/share/plasma/desktoptheme/
    cp -r "${kde}"/plasma/desktoptheme/{icons,weather} "/usr/share/plasma/desktoptheme/${variant}/"
    # start.svg is an Apple logo; without it Plasma uses the icon theme's logo
    rm "/usr/share/plasma/desktoptheme/${variant}/icons/start.svg"

    theme=/usr/share/aurorae/themes/${variant}
    cp -r "${kde}/aurorae/main/${variant}" "${theme}"
    cp "${kde}"/aurorae/common/assets"${variant#WhiteSur}"/*.svg "${theme}/"
    cp "${kde}"/aurorae/{metadata.desktop,metadata.json} "${theme}/"
    cp "${kde}/aurorae/main/${variant}rc" "${theme}/${variant}rc"
    sed -i "s/WhiteSur/${variant}/g" "${theme}/metadata.desktop" "${theme}/metadata.json"
done
cp -r "${kde}/Kvantum/WhiteSur" /usr/share/Kvantum/

# GTK 2, 3 and 4 from the prebuilt release; the GNOME Shell, Cinnamon and
# other desktop parts (with the Apple activities icon) are left out.
for variant in Light Dark; do
    tar -xJf "${src}/WhiteSur-gtk-theme/release/WhiteSur-${variant}.tar.xz" -C /usr/share/themes \
        "WhiteSur-${variant}/index.theme" "WhiteSur-${variant}/gtk-2.0" \
        "WhiteSur-${variant}/gtk-3.0" "WhiteSur-${variant}/gtk-4.0"
done

# Icons: WhiteSur, WhiteSur-light, WhiteSur-dark; -a uses the non-Finder file
# manager icons. Most start-here icons and folder-apple are Apple logos: they
# go, and the menu button falls back to Breeze's logo until T009 brings ours.
bash "${src}/WhiteSur-icon-theme/install.sh" -d /usr/share/icons -a
find /usr/share/icons/WhiteSur /usr/share/icons/WhiteSur-light /usr/share/icons/WhiteSur-dark \
    \( -name 'start-here*' -o -name 'folder-apple*' \) -delete
find /usr/share/icons/WhiteSur /usr/share/icons/WhiteSur-light /usr/share/icons/WhiteSur-dark -xtype l -delete
for theme in WhiteSur WhiteSur-light WhiteSur-dark; do
    gtk-update-icon-cache -f -q "/usr/share/icons/${theme}"
done

cp -r "${src}/WhiteSur-cursors/dist" /usr/share/icons/WhiteSur-cursors

rm -rf "${src}"
