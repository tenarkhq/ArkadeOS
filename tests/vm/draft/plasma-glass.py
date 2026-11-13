"""An ArkadeOS Glass Plasma style for the draft: Breeze's own (default), with
the see-through taskbar and popups more see-through (Aero), in the user's
folder. Usage: plasma-glass.py <taskbar opacity> <popup opacity>"""
import gzip
import json
import shutil
import sys
from pathlib import Path

src = Path("/usr/share/plasma/desktoptheme/default")
dst = Path.home() / ".local/share/plasma/desktoptheme/arkadeos-glass"
shutil.rmtree(dst, ignore_errors=True)
shutil.copytree(src, dst)
meta = json.loads((dst / "metadata.json").read_text())
meta["KPlugin"] = {k: v for k, v in meta["KPlugin"].items() if not k.startswith("Name[") and not k.startswith("Description[")}
meta["KPlugin"]["Id"] = "arkadeos-glass"
meta["KPlugin"]["Name"] = "ArkadeOS Glass"
(dst / "metadata.json").write_text(json.dumps(meta, indent=4))
for name, value in (("panel-background", sys.argv[1]), ("background", sys.argv[2])):
    f = dst / "translucent" / "widgets" / f"{name}.svgz"
    if not f.exists():
        f = dst / "translucent" / "dialogs" / f"{name}.svgz"
    if not f.exists():
        continue
    svg = gzip.decompress(f.read_bytes()).decode()
    n = svg.count("opacity:0.85")
    f.write_bytes(gzip.compress(svg.replace("opacity:0.85", f"opacity:{value}").encode()))
    print(f"{f.relative_to(dst)}: {n} places at {value}")
