"""Portal update progress check: reads uupd's journal lines (in the form uupd
1.5.7 and bootc 1.17 write them, 2026-11-12; the 2026-11-02 lines of the ASUS
laptop too) and shows the running, finished and failed states. Then the
System page itself, with the machine's own commands: the version lines and
the newest version of the channel under them. Runs as the user, offscreen;
saves each state as a picture into the folder given as the first argument."""
import importlib.machinery
import importlib.util
import json
import os
import re
import sys
import time

os.environ["QT_QPA_PLATFORM"] = "offscreen"
# The Portal has no .py name: loaded from its file as a module.
loader = importlib.machinery.SourceFileLoader("portal", "/usr/bin/arkadeos-portal")
portal = importlib.util.module_from_spec(importlib.util.spec_from_loader("portal", loader))
loader.exec_module(portal)
from PySide6.QtWidgets import QApplication  # noqa: E402

GB = 10 ** 9
TOTAL = 5600 * 10 ** 6


def updating(title, description, done, step):
    """uupd's line for a step; its own percentage gives every step a quarter."""
    return json.dumps({"level": "INFO", "msg": "Updating", "module": title.lower(), "status": "running",
                       "output": f"Updating {title} ({description})", "title": title, "description": description,
                       "progress": done, "total": 4, "step_progress": step,
                       "overall": round((done + step / 100) / 4 * 100)}, separators=(",", ":"))


def pulling(got, layers):
    """bootc's download line inside uupd's: canonical JSON (keys in ABC order)
    with every layer fetched so far."""
    subtasks = [{"bytes": 21000000, "bytesCached": 0, "bytesTotal": 21000000, "description": f"layer: sha256:{i:014x}",
                 "id": f"sha256:{i:014x}", "subtask": "layer"} for i in range(layers)]
    event = {"bytes": got, "bytesCached": 100 * 10 ** 6, "bytesTotal": TOTAL,
             "description": "Pulling Image: sha256:" + "b" * 64, "id": "sha256:" + "b" * 64, "steps": layers,
             "stepsCached": 4, "stepsTotal": 257, "subtasks": subtasks, "task": "pulling", "type": "ProgressBytes"}
    return json.dumps({"level": "INFO", "msg": "Command output", "module": "system", "status": "running",
                       "output": json.dumps(event, separators=(",", ":"), sort_keys=True)}, separators=(",", ":"))


START = [updating("System", "Bootc", 0, 0)]
DOWNLOAD = START + [pulling(int(1.2 * GB), 55), updating("System", "Downloading", 0, 1.2 * GB / TOTAL * 80)]
# Near the end the line lists some 250 layers, tens of kilobytes; the journal
# cuts a line at 48K (here at 20 000 characters), and what is left of it is
# no JSON any more.
CUT = pulling(int(5.5 * GB), 252)[:20000]
LATE = DOWNLOAD + [CUT, updating("System", "Downloading", 0, 78.6)]
DEPLOY = LATE + [updating("System", "Importing", 0, 80), "Starting syncfs for system repo",
                 updating("System", "Deploying", 0, 92.5),
                 '{"level":"INFO","msg":"System module has completed.","module":"system","status":"finished","exit_code":0}']
APPS = DEPLOY + [updating("Brew", "CLI Apps", 1, 97.5), updating("Flatpak", "System Apps", 2, 97.5),
                 updating("Flatpak", "Apps for User: arkade", 3, 97.5)]
DONE = APPS + ['{"level":"INFO","msg":"Updates Completed Successfully"}']
FAIL = '{"level":"ERROR","msg":"module_fail","module":"brew","context":"CLI Apps","status":"failed","exit_code":1,"cli":"brew upgrade"}'
# 2026-11-02, the ASUS laptop: an older uupd, without bootc's own lines.
OLD = [
    '{"level":"INFO","msg":"Updating","title":"System","description":"Downloading","progress":0,"total":4,"step_progress":79.61371896607194,"overall":20}',
    '{"level":"INFO","msg":"Updating","title":"Flatpak","description":"Apps for User: arkade","progress":3,"total":4,"step_progress":97.5,"overall":99}',
    '{"level":"ERROR","msg":"module_fail","module":"Brew","cli":"brew upgrade"}',
]

seen = portal.parse_update_log(START)
assert (seen["step"], seen["stage"], seen["bytes"]) == (0, "check", None), seen
assert seen["text"] in ("System: looking for a new version", "Rendszer: új verzió keresése"), seen["text"]
seen = portal.parse_update_log(DOWNLOAD)
assert (seen["step"], seen["stage"], seen["bytes"], seen["total"]) == (0, "download", int(1.2 * GB), TOTAL), seen
assert seen["text"] in ("System: download", "Rendszer: letöltés"), seen["text"]
try:
    json.loads(CUT)
    raise SystemExit("the cut line is still JSON")
except ValueError:
    pass
assert len(pulling(int(5.5 * GB), 252)) > 30000 and portal.parse_update_log(LATE)["bytes"] == int(5.5 * GB)
seen = portal.parse_update_log(DEPLOY)
assert (seen["step"], seen["stage"]) == (0, "deploy"), seen
seen = portal.parse_update_log(APPS)
assert (seen["step"], seen["stage"], seen["failed"]) == (3, "", []), seen
assert portal.parse_update_log(DONE + [FAIL])["failed"] == ["Homebrew"]
seen = portal.parse_update_log(OLD)
assert (seen["step"], seen["failed"]) == (3, ["Homebrew"]), seen
# Read a piece at a time, as the page does: the same as in one go.
seen = portal.new_progress()
for line in DONE:
    portal.parse_update_log([line], seen)
assert seen == portal.parse_update_log(DONE), seen

out = sys.argv[1]
app = QApplication(sys.argv)
box = portal.UpdateProgress()
box.resize(560, box.sizeHint().height())
started, ended = 1793645520, 1793646420


def show(name, lines, kind, staged="", now=0.0):
    s = portal.parse_update_log(lines)
    s.update(kind=kind, started=started, ended=ended, staged=staged)
    box.show_state(s, now)
    box.show()
    app.processEvents()
    assert box.isVisible()
    box.grab().save(f"{out}/portal-update-{name}.png")
    return box.title.text()


def busy():
    return box.bar.minimum() == 0 and box.bar.maximum() == 0


title = show("check", START, "running")
assert busy() and not box.percent.isVisible(), "no percentage before the download"
# The download: the bytes, their percentage, and the time left from the speed
# between two readings (0.4 GB in 10 seconds: 4.0 GB take 100 seconds more).
title = show("running", DOWNLOAD, "running", now=100.0)
assert box.percent.text() == "21%" and box.bar.value() == 21 and not busy(), (box.percent.text(), box.bar.value())
assert "1,2 / 5,6 GB" in title or "1.2 / 5.6 GB" in title, title
assert "perc" not in title and "min" not in title, title
title = show("running", START + [pulling(int(1.6 * GB), 75), updating("System", "Downloading", 0, 22.9)], "running", now=110.0)
assert box.percent.text() == "28%", box.percent.text()
assert "kb. 2 perc van hátra" in title or "about 2 min left" in title, title
title = show("deploy", DEPLOY, "running", now=400.0)
assert busy() and not box.percent.isVisible(), "no percentage while it installs"
assert title in ("System: install", "Rendszer: telepítés"), title
title = show("apps", APPS, "running", now=460.0)
assert busy() and title in ("Updating own apps", "Saját appok frissítése"), title
show("done-restart", DONE, "done", "45.20261112.1")
assert box.bar.value() == 100 and not busy()
show("done", DONE, "done")
title = show("failed", DONE + [FAIL], "failed")
assert "Homebrew" in title, title
idle = portal.new_progress()
idle.update(kind="idle", staged="", started=0, ended=0)
box.show_state(idle)
assert not box.isVisible()

# An update that did not start because a game ran: said only while a game
# still runs, with what counts as the game. systemd keeps the result until
# the update's next start, hours after the game.
skipped = "ActiveState=inactive\nResult=exec-condition\nExecMainStartTimestamp=\nInactiveEnterTimestamp=@1793646420"
real_run, real_game = portal.run, portal.running_game
portal.run = lambda *args: skipped if args[0] == "systemctl" else ""
portal.running_game = lambda: None
assert portal.update_state(portal.UpdateLog())["kind"] == "idle"
portal.running_game = lambda: "wow.exe"
state = portal.update_state(portal.UpdateLog())
assert state["kind"] == "skipped", state
box.show_state(state)
box.show()
app.processEvents()
assert "(wow.exe)" in box.title.text(), box.title.text()
box.grab().save(f"{out}/portal-update-skipped.png")
portal.run, portal.running_game = real_run, real_game

# The System page: the running version, and the newest one of the channel,
# looked up by itself when the page is made (Roland, 2026-11-12).
page = portal.SystemTab()
page.resize(720, 600)
page.show()
deadline = time.monotonic() + 60
while page.looking and time.monotonic() < deadline:
    app.processEvents()
    time.sleep(0.1)
lines = re.sub(r"<[^>]+>|&nbsp;", " ", page.version.text())
assert not page.looking, "the channel's answer did not come"
assert re.search(r"(Running|Fut):\s+\d+\.\d{8}", lines), lines
assert re.search(r"(Newest available|Legfrissebb elérhető):\s+\d+\.\d{8}", lines), lines
app.processEvents()
page.grab().save(f"{out}/portal-system.png")
print("portal update ok")
