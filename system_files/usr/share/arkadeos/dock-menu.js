// Run once per user by the migration step 003-menu-on-dock.sh, through
// PlasmaShell.evaluateScript (Roland, 2026-11-03): the ArkadeOS menu leaves
// the top bar and becomes the dock's first icon, Game Mode leaves the dock,
// the Portal joins it before System Settings. A panel cannot move a widget,
// so the dock's own widgets are taken off and put back after the menu, with
// their settings; anything else the user put on the dock stays where it is.
// The menu and the app grid get pictures as big as the app icons.
var gameMode = "applications:org.arkadeos.GameMode.desktop"
var portal = "applications:org.arkadeos.Portal.desktop"
var ours = ["org.kde.plasma.kickerdash", "org.kde.plasma.icontasks",
            "org.kde.plasma.marginsseparator", "org.kde.plasma.trash"]

function settings(w) {
    var kept = {}
    w.currentConfigGroup = ["General"]
    w.configKeys.forEach(function (k) { kept[k] = w.readConfig(k) })
    return kept
}

panels().forEach(function (panel) {
    var onDock = panel.widgets("org.kde.plasma.icontasks").length > 0
    if (!onDock) {
        panel.widgets("org.kde.plasma.kickoff").forEach(function (w) { w.remove() })
        return
    }
    if (panel.widgets("org.kde.plasma.kickoff").length > 0)
        return
    var back = []
    ours.forEach(function (type) {
        panel.widgets(type).forEach(function (w) {
            back.push({ type: type, settings: settings(w) })
            w.remove()
        })
    })
    var menu = panel.addWidget("org.kde.plasma.kickoff")
    menu.currentConfigGroup = ["General"]
    menu.writeConfig("icon", "/usr/share/arkadeos/icons/dock-menu.svg")
    back.forEach(function (b) {
        var w = panel.addWidget(b.type)
        w.currentConfigGroup = ["General"]
        for (var k in b.settings) {
            var v = b.settings[k]
            if (k === "launchers") {
                v = typeof v === "string" ? (v ? v.split(",") : []) : v
                v = v.filter(function (l) { return l !== gameMode })
                if (v.indexOf(portal) < 0) {
                    var at = v.indexOf("applications:systemsettings.desktop")
                    v.splice(at < 0 ? v.length : at, 0, portal)
                }
            }
            w.writeConfig(k, v)
        }
        // The app grid's picture as big as the app icons (70-theme.sh),
        // unless the user chose a picture of their own.
        if (b.type === "org.kde.plasma.kickerdash" && b.settings.useCustomButtonImage !== "true"
                && b.settings.useCustomButtonImage !== true) {
            w.writeConfig("useCustomButtonImage", true)
            w.writeConfig("customButtonImage", "/usr/share/arkadeos/icons/dock-app-grid.svg")
        }
        w.reloadConfig()
    })
})
