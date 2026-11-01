// A game in borderless windowed full screen (WoW's "Windowed (Fullscreen)")
// is a plain window the size of the screen; KWin keeps the top bar and the
// dock above it (T070), or fits it between them as a maximized window. Such
// a game window is made full screen, so the bars go under it as with real
// full screen. A game that turns windowed again asks for a frame and a
// smaller size, and Wine takes the full-screen state back.
// Games only (a Windows program or a Steam game): a frameless app such as
// Discord, maximized by its user, stays a maximized window.
var LAUNCHERS = ["battle.net.exe", "eadesktop.exe", "upc.exe", "ubisoftconnect.exe", "steam.exe", "explorer.exe"];

function game(w) {
    var c = String(w.resourceClass).toLowerCase();
    return (/\.exe$/.test(c) && LAUNCHERS.indexOf(c) < 0) || /^steam_app_\d+$/.test(c);
}

function fills(g, a) {
    return g.x <= a.x && g.y <= a.y && g.x + g.width >= a.x + a.width && g.y + g.height >= a.y + a.height;
}

function check(w) {
    if (!w.output || !w.normalWindow || !w.noBorder || w.fullScreen || !w.fullScreenable) {
        return;
    }
    var g = w.frameGeometry;
    if (fills(g, w.output.geometry) || fills(g, workspace.clientArea(KWin.MaximizeArea, w))) {
        w.fullScreen = true;
    }
}

function watch(w) {
    if (!w.normalWindow || !game(w)) {
        return;
    }
    w.frameGeometryChanged.connect(function () { check(w); });
    check(w);
}

workspace.windowAdded.connect(watch);
workspace.windowList().forEach(watch);
