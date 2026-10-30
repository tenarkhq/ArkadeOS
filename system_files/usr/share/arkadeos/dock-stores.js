// Run by session-setup through PlasmaShell.evaluateScript: adds installed
// stores to the dock and removes uninstalled ones. arkadeosKnownStores keeps
// which stores the dock has already offered, so a store the user removed
// from the dock is not added again.
var present = @PRESENT@
panels().forEach(function (panel) {
    panel.widgets("org.kde.plasma.icontasks").forEach(function (w) {
        w.currentConfigGroup = ["General"]
        var launchers = w.readConfig("launchers", [])
        if (typeof launchers === "string")
            launchers = launchers ? launchers.split(",") : []
        var known = String(w.readConfig("arkadeosKnownStores", ""))
        known = known ? known.split(",") : []
        var changed = false
        for (var store in present) {
            var at = launchers.indexOf(store), k = known.indexOf(store)
            if (present[store]) {
                if (at < 0 && k < 0) {
                    // after the last store already on the dock
                    var pos = 0
                    for (var other in present) {
                        var j = launchers.indexOf(other)
                        if (j + 1 > pos) pos = j + 1
                    }
                    launchers.splice(pos || Math.min(2, launchers.length), 0, store)
                    changed = true
                }
                if (k < 0) known.push(store)
            } else {
                if (at >= 0) { launchers.splice(at, 1); changed = true }
                if (k >= 0) known.splice(k, 1)
            }
        }
        w.writeConfig("arkadeosKnownStores", known.join(","))
        if (changed) {
            w.writeConfig("launchers", launchers)
            w.reloadConfig()
        }
    })
})
