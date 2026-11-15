// Run by session-setup at each login through plasma-script: the taskbar
// clock at the size of the tray's text and in the system font's normal
// weight (Roland, 2026-11-15: big and thin on his laptop). @SIZE@ is the
// point size for this screen (clock-size), 0 when the screen is not known.
// KDE's clock keeps its weight as Qt 5 wrote it (50 for normal), which Qt 6
// reads as thinner than Thin; 400 is Qt 6's normal. Only a clock in the fixed
// size ArkadeOS gives it is touched, and its size only while it is the one
// ArkadeOS set: a size or weight the user picked stays.
var size = @SIZE@
panels().forEach(function (panel) {
    panel.widgets("org.kde.plasma.digitalclock").forEach(function (w) {
        w.currentConfigGroup = ["Appearance"]
        if (String(w.readConfig("autoFontAndSize", true)) !== "false")
            return
        var changed = false
        if (Number(w.readConfig("fontWeight", 50)) === 50) {
            w.writeConfig("fontWeight", 400)
            changed = true
        }
        var ours = Number(w.readConfig("arkadeosFontSize", 10))
        if (size > 0 && Number(w.readConfig("fontSize", 10)) === ours && ours !== size) {
            w.writeConfig("fontSize", size)
            w.writeConfig("arkadeosFontSize", size)
            changed = true
        }
        if (changed)
            w.reloadConfig()
    })
})
