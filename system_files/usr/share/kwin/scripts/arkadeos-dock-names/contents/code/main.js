// ArkadeOS dock names (T068): reports each new window to arkadeos-dock-names,
// which gives a window whose app has no menu entry under its name a hidden
// one, so it can be pinned on the dock and keeps its icon there.
function report(w) {
    if (!w.normalWindow || w.skipTaskbar) {
        return;
    }
    callDBus("org.arkadeos.DockNames", "/org/arkadeos/DockNames", "org.arkadeos.DockNames",
             "WindowAdded", w.resourceClass || "", w.desktopFileName || "", w.pid || 0, w.caption || "");
}
workspace.windowAdded.connect(report);
workspace.windowList().forEach(report);
