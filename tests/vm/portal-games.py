"""Portal Games tab check (T055): lists the factory, own and Steam games,
writes a choice, adds and removes a program. Runs as the user, offscreen."""
import importlib.machinery
import os
import sys
from pathlib import Path

os.environ["QT_QPA_PLATFORM"] = "offscreen"
home = Path.home()
steam = home / ".local/share/Steam/steamapps"
steam.mkdir(parents=True, exist_ok=True)
(steam / "appmanifest_1091500.acf").write_text('"AppState"\n{\n\t"appid"\t\t"1091500"\n\t"name"\t\t"Cyberpunk 2077"\n}\n')
(steam / "appmanifest_1493710.acf").write_text('"AppState"\n{\n\t"appid"\t\t"1493710"\n\t"name"\t\t"Proton Experimental"\n}\n')

portal = importlib.machinery.SourceFileLoader("portal", "/usr/bin/arkadeos-portal").load_module()
from PySide6.QtWidgets import QApplication  # noqa: E402

app = QApplication(sys.argv)
tab = portal.GamesTab()
rows = {r[0]: r for r in tab.rows()}
assert "Wow.exe" in rows and rows["Wow.exe"][3] == "wow", rows
assert "1091500" in rows and "1493710" not in rows, rows
own = portal.USER_GAMES
i = [tab.table.cellWidget(n, 0).text() for n in range(tab.table.rowCount())].index(
    next(t for t in [tab.table.cellWidget(n, 0).text() for n in range(tab.table.rowCount())] if "1091500" in t))
combo = tab.table.cellWidget(i, 2)
combo.setCurrentIndex(combo.findData("balanced"))
assert "1091500=balanced" in own.read_text(), own.read_text()
tab.name.setText("Diablo IV")
tab.add_program()
assert "Diablo IV.exe=gaming" in own.read_text(), own.read_text()
assert portal.GamesTab().rows() and any(r[0] == "Diablo IV.exe" and r[5] for r in tab.rows())
tab.remove("Diablo IV.exe")
assert "Diablo IV.exe" not in own.read_text(), own.read_text()
combo = tab.table.cellWidget(i, 2)
combo.setCurrentIndex(0)
assert "1091500" not in own.read_text(), own.read_text()
print("portal games ok")
