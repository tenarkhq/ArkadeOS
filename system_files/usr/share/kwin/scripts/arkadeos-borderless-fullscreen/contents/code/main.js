// A game in borderless windowed full screen (WoW's "Windowed (Fullscreen)")
// is a plain window the size of the screen; KWin keeps the top bar and the
// dock above it (T070). Such a window is made full screen, so the bars go
// under it as with real full screen. A game that turns windowed again asks
// for a frame and a smaller size, and Wine takes the full-screen state back.
function covers(w) {
    if (!w.output) {
        return false;
    }
    var g = w.frameGeometry, o = w.output.geometry;
    return g.x <= o.x && g.y <= o.y && g.x + g.width >= o.x + o.width && g.y + g.height >= o.y + o.height;
}

function check(w) {
    if (w.normalWindow && w.noBorder && !w.fullScreen && w.fullScreenable && covers(w)) {
        w.fullScreen = true;
    }
}

function watch(w) {
    if (!w.normalWindow || w.resourceClass == "plasmashell") {
        return;
    }
    w.frameGeometryChanged.connect(function () { check(w); });
    check(w);
}

workspace.windowAdded.connect(watch);
workspace.windowList().forEach(watch);
