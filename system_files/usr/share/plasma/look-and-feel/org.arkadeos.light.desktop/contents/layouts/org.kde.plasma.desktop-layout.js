// ArkadeOS desktop layout (T007): one taskbar at the bottom.
// Plasma runs this once, when a user first logs in. ArkadeOS Dark falls back
// to this package, so both global themes give the same layout.

// One taskbar at the bottom, KDE's own arrangement (Roland, 2026-11-04): the
// ArkadeOS menu (Ark logo; Meta and Alt+F1 open it), the apps, the power
// profile switch (T012), tray, clock and the show-desktop button. Stores
// installed later (Heroic) are added by session-setup (T018).
var panel = new Panel
panel.location = "bottom"
panel.height = 2 * Math.floor(gridUnit * 2.5 / 2)

var launcher = panel.addWidget("org.kde.plasma.kickoff")
launcher.currentConfigGroup = ["General"]
launcher.writeConfig("icon", "arkadeos-launcher")

var tasks = panel.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("launchers", [
    "preferred://filemanager",
    "preferred://browser",
    "applications:steam.desktop",
    "applications:org.arkadeos.BattleNet.desktop",
    "applications:net.lutris.Lutris.desktop",
    "applications:io.github.kolunmi.Bazaar.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:org.arkadeos.Portal.desktop",
    "applications:systemsettings.desktop"
])

panel.addWidget("org.kde.plasma.marginsseparator")
panel.addWidget("org.arkadeos.power")
panel.addWidget("org.kde.plasma.systemtray")
panel.addWidget("org.kde.plasma.digitalclock")
panel.addWidget("org.kde.plasma.showdesktop")

// ArkadeOS wallpaper (T009); Plasma picks the dark images with a dark theme.
var desktopsArray = desktopsForActivity(currentActivity())
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image"
    desktopsArray[j].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]
    desktopsArray[j].writeConfig("Image", "file:///usr/share/wallpapers/ArkadeOS/")
}
