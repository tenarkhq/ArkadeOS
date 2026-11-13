// ArkadeOS desktop layout (T007): one taskbar at the bottom.
// Plasma runs this once, when a user first logs in. ArkadeOS Dark falls back
// to this package, so both global themes give the same layout.

// One taskbar at the bottom (Roland, 2026-11-04), the ArkadeOS Glass bar
// since 2026-11-13 (T086): flush with the screen's edge, the ArkadeOS mark
// alone and lit as the menu (Meta and Alt+F1 open it), the apps in the middle,
// then the power profile switch (T012), tray, clock and the show-desktop
// button in one glass capsule (org.arkadeos.capsule draws it). Stores
// installed later (Heroic) are added by session-setup (T018).
// /usr/share/arkadeos/glass-taskbar.js builds the same bar for a user who
// had the earlier one.
var panel = new Panel
panel.location = "bottom"
panel.height = 2 * Math.floor(gridUnit * 2.5 / 2)
panel.floating = false

var launcher = panel.addWidget("org.kde.plasma.kickoff")
launcher.currentConfigGroup = ["General"]
launcher.writeConfig("icon", "arkadeos-launcher-glow")

panel.addWidget("org.kde.plasma.panelspacer")
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
// The app icons close together, a slot as wide as the bar is tall (Small
// spacing; Roland, 2026-11-13: "húzzuk már összeébb").
tasks.writeConfig("iconSpacing", 0)
panel.addWidget("org.kde.plasma.panelspacer")

panel.addWidget("org.arkadeos.power")
panel.addWidget("org.kde.plasma.systemtray")
// The clock as in the design: time and date on one line, at the size of
// the tray's text, not filling the bar.
var clock = panel.addWidget("org.kde.plasma.digitalclock")
clock.currentConfigGroup = ["Appearance"]
clock.writeConfig("dateDisplayFormat", 1)
clock.writeConfig("autoFontAndSize", false)
clock.writeConfig("fontSize", 10)
panel.addWidget("org.kde.plasma.showdesktop")
panel.addWidget("org.arkadeos.capsule")

// ArkadeOS wallpaper: Égkék (T086, before it the Ark of T009); Plasma picks
// the dark images with a dark theme.
var desktopsArray = desktopsForActivity(currentActivity())
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image"
    desktopsArray[j].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]
    desktopsArray[j].writeConfig("Image", "file:///usr/share/wallpapers/ArkadeOS-Egkek/")
}
