"""ArkadeOS colour schemes with see-through backgrounds: Breeze Light/Dark with
an alpha on the background colours (the text stays solid)."""
import re
import sys

ALPHA = {"Window": 204, "Header": 204, "Header][Inactive": 204, "View": 219, "Tooltip": 230, "Complementary": 220}
src, dst, name = sys.argv[1:4]
group, out = None, []
for line in open(src, encoding="utf-8"):
    m = re.match(r"^\[Colors:(.+)\]\s*$", line)
    if line.startswith("["):
        group = m.group(1) if m else None
    k = re.match(r"^(BackgroundNormal|BackgroundAlternate)=(\d+),(\d+),(\d+)\s*$", line)
    if k and group in ALPHA:
        line = f"{k.group(1)}={k.group(2)},{k.group(3)},{k.group(4)},{ALPHA[group]}\n"
    if line.startswith("Name="):
        line = f"Name={name}\n"
    out.append(line)
open(dst, "w", encoding="utf-8").write("".join(out))
