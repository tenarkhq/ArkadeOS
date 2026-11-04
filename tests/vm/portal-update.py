"""Portal update progress check: reads uupd's journal lines (taken from a real
run on the ASUS laptop, 2026-11-02) and shows the running, finished and
failed states. Runs as the user, offscreen; saves each state as a picture
into the folder given as the first argument."""
import importlib.machinery
import os
import sys

os.environ["QT_QPA_PLATFORM"] = "offscreen"
portal = importlib.machinery.SourceFileLoader("portal", "/usr/bin/arkadeos-portal").load_module()
from PySide6.QtWidgets import QApplication  # noqa: E402

LOG = [
    '{"level":"INFO","msg":"Updating","title":"System","description":"Downloading","progress":0,"total":4,"step_progress":79.61371896607194,"overall":20}',
    'Starting syncfs for system repo',
    '{"level":"INFO","msg":"Updating","title":"System","description":"Deploying","progress":0,"total":4,"step_progress":92.5,"overall":23}',
    '{"level":"INFO","msg":"Updating","title":"Brew","description":"CLI Apps","progress":1,"total":4,"step_progress":97.5,"overall":49}',
    '{"level":"INFO","msg":"Updating","title":"Flatpak","description":"System Apps","progress":2,"total":4,"step_progress":97.5,"overall":74}',
    '{"level":"INFO","msg":"Updating","title":"Flatpak","description":"Apps for User: arkade","progress":3,"total":4,"step_progress":97.5,"overall":99}',
    '{"level":"INFO","msg":"Updates Completed Successfully"}',
]
out = sys.argv[1]

step, text, overall, failed = portal.parse_update_log(LOG[:1])
assert (step, overall, failed) == (0, 20, []), (step, overall, failed)
assert text in ("System: download", "Rendszer: letöltés"), text
step, text, overall, failed = portal.parse_update_log(LOG[:5])
assert (step, overall) == (2, 74), (step, overall)
step, text, overall, failed = portal.parse_update_log(LOG)
assert (step, overall) == (3, 99), (step, overall)
fail = '{"level":"ERROR","msg":"module_fail","module":"Brew","cli":"brew upgrade"}'
assert portal.parse_update_log(LOG + [fail])[3] == ["Homebrew"]

app = QApplication(sys.argv)
box = portal.UpdateProgress()
box.resize(560, box.sizeHint().height())
started, ended = 1793645520, 1793646420
for name, lines, kind, staged in (("running", LOG[:1], "running", ""), ("apps", LOG[:6], "running", ""),
                                  ("done-restart", LOG, "done", "44.20261102"), ("done", LOG, "done", ""),
                                  ("failed", LOG + [fail], "failed", "")):
    s = dict(zip(("step", "text", "overall", "failed"), portal.parse_update_log(lines)))
    s.update(kind=kind, started=started, ended=ended, staged=staged)
    box.show_state(s)
    box.show()
    app.processEvents()
    assert box.isVisible()
    if kind == "running":
        assert box.percent.text() == f"{s['overall']}%", box.percent.text()
    box.grab().save(f"{out}/portal-update-{name}.png")
box.show_state({"kind": "idle", "staged": "", "step": None, "text": "", "overall": None, "failed": [],
                "started": 0, "ended": 0})
assert not box.isVisible()
print("portal update ok")
