// Run once per user by the migration step 004-breeze-taskbar.sh, through
// PlasmaShell.evaluateScript (Roland, 2026-11-04): the top bar and the dock
// become one taskbar at the bottom, as the layout gives a new user. The
// dock's app icons and their settings stay; Game Mode (gone from the image)
// leaves, the Portal joins before System Settings. Panels the user added
// stay as they are.
var gameMode = "applications:org.arkadeos.GameMode.desktop"
var portal = "applications:org.arkadeos.Portal.desktop"
var bars = [], docks = []
panels().forEach(function (panel) {
    if (panel.widgets("org.kde.plasma.appmenu").length > 0)
        bars.push(panel)
    else if (panel.widgets("org.kde.plasma.icontasks").length > 0 && panel.lengthMode === "fit")
        docks.push(panel)
})
if (bars.length > 0 || docks.length > 0) {
    var kept = {}
    docks.forEach(function (dock) {
        dock.widgets("org.kde.plasma.icontasks").forEach(function (w) {
            w.currentConfigGroup = ["General"]
            w.configKeys.forEach(function (k) { kept[k] = w.readConfig(k) })
        })
    })
    bars.concat(docks).forEach(function (p) { p.remove() })

    var panel = new Panel
    panel.location = "bottom"
    panel.height = 2 * Math.floor(gridUnit * 2.5 / 2)
    var launcher = panel.addWidget("org.kde.plasma.kickoff")
    launcher.currentConfigGroup = ["General"]
    launcher.writeConfig("icon", "arkadeos-launcher")
    var tasks = panel.addWidget("org.kde.plasma.icontasks")
    tasks.currentConfigGroup = ["General"]
    for (var k in kept) {
        var v = kept[k]
        if (k === "launchers") {
            v = typeof v === "string" ? (v ? v.split(",") : []) : v
            v = v.filter(function (l) { return l !== gameMode })
            if (v.indexOf(portal) < 0) {
                var at = v.indexOf("applications:systemsettings.desktop")
                v.splice(at < 0 ? v.length : at, 0, portal)
            }
        }
        tasks.writeConfig(k, v)
    }
    tasks.reloadConfig()
    panel.addWidget("org.kde.plasma.marginsseparator")
    panel.addWidget("org.arkadeos.power")
    panel.addWidget("org.kde.plasma.systemtray")
    panel.addWidget("org.kde.plasma.digitalclock")
    panel.addWidget("org.kde.plasma.showdesktop")
}
