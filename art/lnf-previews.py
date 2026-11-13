"""The ArkadeOS global themes' previews (T086, Roland, 2026-11-13: "a
beállítások ablakot is rendbe rakhatnád"): System Settings shows them on its
first page and in Global Theme, so they show the ArkadeOS Glass desktop, not
the earlier one. Made from the VM test's glass scenes (glass-light.png,
glass-dark.png, 1280x800): cut to 16:9 keeping the taskbar, then 600x337
(preview.png) and 1920x1080 (fullscreenpreview.jpg). Needs Pillow (the art
container). Usage: lnf-previews.py <light.png> <dark.png> <look-and-feel folder>"""
import os
import sys

from PIL import Image

light, dark, lnf = sys.argv[1:4]
for look, src in (("light", light), ("dark", dark)):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    cut = h - round(w * 9 / 16)
    im = im.crop((0, cut, w, h))
    out = os.path.join(lnf, f"org.arkadeos.{look}.desktop", "contents", "previews")
    im.resize((600, 337), Image.LANCZOS).save(os.path.join(out, "preview.png"), optimize=True)
    im.resize((1920, 1080), Image.LANCZOS).save(os.path.join(out, "fullscreenpreview.jpg"), quality=88, optimize=True)
print("ok")
