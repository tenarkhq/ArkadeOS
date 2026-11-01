// VM test only: prints what KWin sees of the borderless test window (T070).
workspace.windowList().forEach(function (w) {
    if (String(w.caption).indexOf("arkadeos-borderless") < 0) {
        return;
    }
    var a;
    try {
        a = JSON.stringify(workspace.clientArea(KWin.MaximizeArea, w));
    } catch (e) {
        a = "error " + e;
    }
    print("kwin-probe class=" + w.resourceClass + " normal=" + w.normalWindow + " noBorder=" + w.noBorder +
          " fullScreen=" + w.fullScreen + " fullScreenable=" + w.fullScreenable + " maximizable=" + w.maximizable +
          " output=" + (w.output ? JSON.stringify(w.output.geometry) : "none") +
          " frame=" + JSON.stringify(w.frameGeometry) + " maximizeArea=" + a);
});
