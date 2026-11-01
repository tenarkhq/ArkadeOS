// VM test only: what KWin sees of the borderless test window (T070), each step
// of the full-screen script's check on its own; the lines go to
// kwin-probe-log.py.
function log(text) {
    callDBus("org.arkadeos.Probe", "/", "org.arkadeos.Probe", "Log", "kwin-probe " + text);
}

function step(name, f) {
    try {
        log(name + "=" + JSON.stringify(f()));
    } catch (e) {
        log(name + " error " + e);
    }
}

log("windows=" + workspace.windowList().length);
workspace.windowList().forEach(function (w) {
    if (String(w.caption).indexOf("arkadeos-borderless") < 0) {
        return;
    }
    step("class", function () { return String(w.resourceClass); });
    step("normal", function () { return w.normalWindow; });
    step("noBorder", function () { return w.noBorder; });
    step("fullScreen", function () { return w.fullScreen; });
    step("fullScreenable", function () { return w.fullScreenable; });
    step("output", function () { return w.output ? w.output.geometry : null; });
    step("frame", function () { return w.frameGeometry; });
    step("client", function () { return w.clientGeometry; });
    step("MaximizeArea", function () { return KWin.MaximizeArea; });
    step("maximizeArea", function () { return workspace.clientArea(KWin.MaximizeArea, w); });
    w.fullScreen = true;
    step("fullScreen after setting it", function () { return w.fullScreen; });
});
