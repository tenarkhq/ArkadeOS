"""ArkadeOS colour schemes with see-through parts: Breeze Light/Dark with an
alpha on some background colours (the text stays solid).
MODE aero: only the title bars (Header, WM) are glass, as on Windows 7, with
ALPHA (0-255, default 150); TINT r,g,b gives the glass a colour (Aero blue).
MODE content: the window backgrounds too (the first draft)."""
import os
import re
import sys

MODES = {
    "aero": dict.fromkeys(("Header", "Header][Inactive", "WM"), int(os.environ.get("ALPHA", 150))),
    "content": {"Window": 204, "Header": 204, "Header][Inactive": 204, "View": 219, "Tooltip": 230, "Complementary": 220},
}
ALPHA = MODES[os.environ.get("MODE", "aero")]
src, dst, name = sys.argv[1:4]
group, out = None, []
for line in open(src, encoding="utf-8"):
    if line.startswith("["):
        m = re.match(r"^\[(?:Colors:)?(.+)\]\s*$", line)
        group = m.group(1) if m else None
    k = re.match(r"^(BackgroundNormal|BackgroundAlternate|activeBackground|inactiveBackground)=(\d+),(\d+),(\d+)\s*$", line)
    if k and group in ALPHA:
        rgb = f"{k.group(2)},{k.group(3)},{k.group(4)}"
        if os.environ.get("TINT"):
            rgb = os.environ["TINT"]
        line = f"{k.group(1)}={rgb},{ALPHA[group]}\n"
    if line.startswith("Name="):
        line = f"Name={name}\n"
    out.append(line)
open(dst, "w", encoding="utf-8").write("".join(out))
