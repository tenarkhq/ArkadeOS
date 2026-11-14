// Run by the migration step 008-glass.sh after glass-taskbar.js, through
// PlasmaShell.evaluateScript (T086, Roland, 2026-11-13: "esetleg ezek is
// lehetnének picit sűrűbben de ne nagyon"): the tray's icons a little closer
// together, Small spacing (4 px apart, not 8), where still at Normal. Plasma
// 6.8 keeps the tray's settings in the tray widget's own General group; an
// older Plasma kept them on an inner containment the widget names
// (SystrayContainmentId), made only once the bar is up: until then this
// prints "wait" and the step asks again. Also for a new user, whose bar the
// layout script built.
var waiting = false
panels().forEach(function (panel) {
    if (panel.location !== "bottom")
        return
    panel.widgets("org.kde.plasma.systemtray").forEach(function (w) {
        var inner = w.readConfig("SystrayContainmentId")
        var tray = inner ? desktopById(inner) : w
        if (!tray) {
            waiting = true
            return
        }
        tray.currentConfigGroup = ["General"]
        if (Number(tray.readConfig("iconSpacing", 2)) === 2)
            tray.writeConfig("iconSpacing", 1)
    })
})
print(waiting ? "wait" : "done")
