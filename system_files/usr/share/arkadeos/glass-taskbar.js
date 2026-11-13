// Run once per user by the migration step 008-glass.sh, through
// PlasmaShell.evaluateScript (T086, Roland, 2026-11-13): the ArkadeOS taskbar
// becomes the glass bar a new user gets (the layout of org.arkadeos.light):
// flush with the screen's edge, the ArkadeOS mark lit as the menu, the apps
// in the middle close together, the tray and clock in a glass capsule (the
// tray's own spacing: glass-tray.js, once the bar is up). Only a bar with
// ArkadeOS's own widgets is rebuilt, keeping its app icons and their
// settings; on one the user changed, only the edge and the menu's mark
// change. The desktop's wallpaper becomes Égkék where it
// is still the earlier ArkadeOS default.
var ours = ["org.kde.plasma.kickoff", "org.kde.plasma.icontasks", "org.kde.plasma.marginsseparator",
            "org.arkadeos.power", "org.kde.plasma.systemtray", "org.kde.plasma.digitalclock",
            "org.kde.plasma.showdesktop", "org.kde.plasma.panelspacer", "org.arkadeos.capsule"]
panels().forEach(function (panel) {
    if (panel.location !== "bottom" || panel.widgets("org.kde.plasma.icontasks").length === 0)
        return
    var all = panel.widgets()
    var plain = all.every(function (w) { return ours.indexOf(w.type) >= 0 })
    panel.floating = false
    panel.widgets("org.kde.plasma.kickoff").forEach(function (w) {
        w.currentConfigGroup = ["General"]
        if (w.readConfig("icon", "") === "arkadeos-launcher" || w.readConfig("icon", "") === "")
            w.writeConfig("icon", "arkadeos-launcher-glow")
    })
    // The app icons close together (Small spacing), where still at Normal.
    panel.widgets("org.kde.plasma.icontasks").forEach(function (w) {
        w.currentConfigGroup = ["General"]
        if (Number(w.readConfig("iconSpacing", 1)) === 1)
            w.writeConfig("iconSpacing", 0)
    })
    if (!plain || panel.widgets("org.kde.plasma.panelspacer").length > 0)
        return
    var kept = {}
    panel.widgets("org.kde.plasma.icontasks").forEach(function (w) {
        w.currentConfigGroup = ["General"]
        w.configKeys.forEach(function (k) { kept[k] = w.readConfig(k) })
    })
    var height = panel.height
    panel.remove()
    var bar = new Panel
    bar.location = "bottom"
    bar.height = height
    bar.floating = false
    var launcher = bar.addWidget("org.kde.plasma.kickoff")
    launcher.currentConfigGroup = ["General"]
    launcher.writeConfig("icon", "arkadeos-launcher-glow")
    bar.addWidget("org.kde.plasma.panelspacer")
    var tasks = bar.addWidget("org.kde.plasma.icontasks")
    tasks.currentConfigGroup = ["General"]
    for (var k in kept)
        tasks.writeConfig(k, kept[k])
    tasks.reloadConfig()
    bar.addWidget("org.kde.plasma.panelspacer")
    bar.addWidget("org.arkadeos.power")
    bar.addWidget("org.kde.plasma.systemtray")
    var clock = bar.addWidget("org.kde.plasma.digitalclock")
    clock.currentConfigGroup = ["Appearance"]
    clock.writeConfig("dateDisplayFormat", 1)
    clock.writeConfig("autoFontAndSize", false)
    clock.writeConfig("fontSize", 10)
    bar.addWidget("org.kde.plasma.showdesktop")
    bar.addWidget("org.arkadeos.capsule")
})
desktops().forEach(function (d) {
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]
    var image = d.readConfig("Image", "")
    if (image === "" || image === "file:///usr/share/wallpapers/ArkadeOS/" || image === "file:///usr/share/wallpapers/ArkadeOS")
        d.writeConfig("Image", "file:///usr/share/wallpapers/ArkadeOS-Egkek/")
})
