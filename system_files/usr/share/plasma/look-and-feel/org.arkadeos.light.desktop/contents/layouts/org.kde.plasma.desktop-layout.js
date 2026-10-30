// ArkadeOS desktop layout (T007): a bar on top and a dock below, as on macOS.
// Plasma runs this once, when a user first logs in. ArkadeOS Dark falls back
// to this package, so both global themes give the same layout.

// Top bar: Ark logo (opens the launcher), the active app's menu, power
// profile, tray, clock (the calendar opens from the clock).
var bar = new Panel
bar.location = "top"
bar.floating = false
bar.height = 2 * Math.ceil(gridUnit * 1.5 / 2)
var launcher = bar.addWidget("org.kde.plasma.kickoff")
launcher.currentConfigGroup = ["General"]
launcher.writeConfig("icon", "arkadeos-launcher")
bar.addWidget("org.kde.plasma.appmenu")
bar.addWidget("org.kde.plasma.panelspacer")
bar.addWidget("org.arkadeos.power")  // power profile switch (T012)
bar.addWidget("org.kde.plasma.systemtray")
bar.addWidget("org.kde.plasma.digitalclock")

// Dock: floating, centred, as wide as its icons. Stores installed later
// (Heroic) are added by session-setup (T018). Always visible; the user can
// turn on hiding in the panel settings (Roland, 2026-10-30).
var dock = new Panel
dock.location = "bottom"
dock.floating = true
dock.lengthMode = "fit"
dock.alignment = "center"
dock.hiding = "none"
dock.height = 2 * Math.ceil(gridUnit * 3 / 2)

var grid = dock.addWidget("org.kde.plasma.kickerdash")
grid.currentConfigGroup = ["General"]
grid.writeConfig("icon", "view-app-grid")

var tasks = dock.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("launchers", [
    "preferred://filemanager",
    "preferred://browser",
    "applications:steam.desktop",
    "applications:org.arkadeos.BattleNet.desktop",
    "applications:org.arkadeos.GameMode.desktop",
    "applications:net.lutris.Lutris.desktop",
    "applications:io.github.kolunmi.Bazaar.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop"
])

dock.addWidget("org.kde.plasma.marginsseparator")
dock.addWidget("org.kde.plasma.trash")

// ArkadeOS wallpaper (T009); Plasma picks the dark images with a dark theme.
var desktopsArray = desktopsForActivity(currentActivity())
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image"
    desktopsArray[j].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]
    desktopsArray[j].writeConfig("Image", "file:///usr/share/wallpapers/ArkadeOS/")
}
