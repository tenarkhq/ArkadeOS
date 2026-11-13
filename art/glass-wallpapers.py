"""ArkadeOS Glass wallpapers (T086, Roland's picks of 2026-11-13): "egkek" (the
default, matched to the glass colour), "ark-ribbons" and "ark-cross" (the
mark's colours). Like KDE's Nexus, deep black for OLED. Renders in linear
light, the drawn shapes at 2x, and writes 16-bit sRGB PNG.
Usage: glass-wallpapers.py <name> <w> <h> <dark|light> <out.png>
(art/render-glass-wallpapers.sh makes every size and encodes JPEG XL)."""
import math
import struct
import sys
import zlib

import numpy as np
from PIL import Image, ImageDraw

name, W, H, mode, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5]
SS = 2                      # supersampling of the drawn shapes
WW, HH = W * SS, H * SS
S = min(W, H)
rng = np.random.default_rng(11)


def lin(c):
    c = np.asarray(c, np.float32)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def enc(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def hexc(h):
    return lin([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)])


GREEN, AMBER, LAV, ROSE = hexc("#33e661"), hexc("#ffa30d"), hexc("#bdbdff"), hexc("#ff2e5c")
GLASS = hexc("#60aae8")


def blur(img, sigma):
    if sigma < 0.5:
        return img
    pad = int(sigma * 3)
    h, w = img.shape[:2]
    p = np.pad(img, ((pad, pad), (pad, pad)) + ((0, 0),) * (img.ndim - 2))
    fy = np.fft.fftfreq(p.shape[0]).astype(np.float32)
    fx = np.fft.rfftfreq(p.shape[1]).astype(np.float32)
    k = np.exp(-2 * np.pi ** 2 * sigma ** 2 * (fy[:, None] ** 2 + fx[None, :] ** 2))
    if img.ndim == 3:
        k = k[..., None]
    o = np.fft.irfft2(np.fft.rfft2(p, axes=(0, 1)) * k, s=p.shape[:2], axes=(0, 1))
    return o[pad:pad + h, pad:pad + w].astype(np.float32)


def down(a):
    """2x2 average: the supersampled layer at the output size."""
    return a.reshape(H, SS, W, SS, *a.shape[2:]).mean(axis=(1, 3))


def layer():
    return Image.new("F", (WW, HH), 0.0)


def arr(im):
    return down(np.asarray(im, np.float32))


def bezier(pts, n):
    """Points and unit normals of a cubic Bezier through four control points (output pixels)."""
    p = np.asarray(pts, np.float64)
    t = np.linspace(0, 1, n)[:, None]
    c = (1 - t) ** 3 * p[0] + 3 * (1 - t) ** 2 * t * p[1] + 3 * (1 - t) * t ** 2 * p[2] + t ** 3 * p[3]
    d = 3 * (1 - t) ** 2 * (p[1] - p[0]) + 6 * (1 - t) * t * (p[2] - p[1]) + 3 * t ** 2 * (p[3] - p[2])
    d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
    return c, np.stack([-d[:, 1], d[:, 0]], 1), t[:, 0]


def ribbon(pts, width, turns, colours, n=500, strips=10, phase=0.0, taper=0.0, pinch=False):
    """A glossy band along a curve that turns over itself: returns (light, cover)
    at the output size. Each strip across the band is lit by how much the band
    faces the viewer, with a bright rim on both edges and a sheen where it
    turns edge-on."""
    c, nrm, t = bezier(pts, n)
    theta = phase + turns * 2 * np.pi * t
    wid = width * (1 - taper * (2 * t - 1) ** 2)
    if pinch:
        wid = wid * np.clip((1 - t) / 0.3, 0, 1) ** 0.8
    face = np.abs(np.cos(theta))
    cols = np.asarray(colours, np.float32)
    seg = np.clip(t * (len(cols) - 1), 0, len(cols) - 1 - 1e-6)
    i0 = seg.astype(int)
    col = cols[i0] * (1 - (seg - i0))[:, None] + cols[i0 + 1] * (seg - i0)[:, None]
    chans = [layer() for _ in range(3)]
    cover = layer()
    draws = [ImageDraw.Draw(x) for x in chans]
    dc = ImageDraw.Draw(cover)
    us = np.linspace(-1, 1, strips + 1)
    # back to front: the half of the band that faces away first
    order = np.argsort(-np.sin(theta[:-1]))
    for i in order:
        for k in range(strips):
            u0, u1 = us[k], us[k + 1]
            um = (u0 + u1) / 2
            q = []
            for j, u in ((i, u0), (i + 1, u0), (i + 1, u1), (i, u1)):
                off = u * wid[j] * np.cos(theta[j])
                x, y = c[j] + nrm[j] * off
                q.append((x * SS, y * SS))
            rim = 1.0 + 1.6 * max(0.0, abs(um) - 0.78) / 0.22
            sheen = 1.0 + 1.8 * math.exp(-((face[i] - 0.18) / 0.12) ** 2)
            shade = (0.16 + 0.84 * face[i] ** 1.5) * rim * sheen
            for ch in range(3):
                draws[ch].polygon(q, fill=float(col[i][ch] * shade))
            dc.polygon(q, fill=1.0)
    light = np.stack([arr(x) for x in chans], -1)
    return light, arr(cover)


def over(canvas, light, cover):
    return canvas * (1 - cover[..., None]) + light


def glow(light, amount=1.0):
    s = S / 1000
    return (blur(light, 6 * s) * 0.55 + blur(light, 30 * s) * 0.55 + blur(light, 110 * s) * 0.45) * amount


def tri_grid(spacing, value=1.0, angle=0.0):
    """Lines of a triangle lattice, as a light mask."""
    im = layer()
    d = ImageDraw.Draw(im)
    sp = spacing * SS
    L = (WW + HH) * 1.5
    for a in (0, 60, 120):
        r = math.radians(a + angle)
        dx, dy = math.cos(r), math.sin(r)
        nx, ny = -dy, dx
        for k in range(-int(L / sp), int(L / sp) + 1):
            ox, oy = WW / 2 + nx * k * sp, HH / 2 + ny * k * sp
            d.line([(ox - dx * L, oy - dy * L), (ox + dx * L, oy + dy * L)], fill=value, width=max(1, SS))
    return arr(im)


def hub(canvas, cx, cy, size=1.0):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dd = np.hypot(xx - cx, yy - cy) / S
    return canvas + (np.exp(-(dd / (0.010 * size)) ** 2) * 1.6 + np.exp(-(dd / (0.05 * size)) ** 2) * 0.12)[..., None]


canvas = np.zeros((H, W, 3), np.float32)

if name == "ark-ribbons":
    # Four bands in the mark's colours sweep in from the corners and narrow into the hub.
    cx, cy = W * 0.6, H * 0.56
    lights = []
    specs = [((-0.15 * W, -0.05 * H), (0.2 * W, 0.05 * H), GREEN, 1.1, 0.0),
             ((1.15 * W, -0.10 * H), (0.95 * W, 0.15 * H), AMBER, 0.9, 0.7),
             ((-0.10 * W, 1.12 * H), (0.15 * W, 0.95 * H), LAV * 0.7, 1.2, 1.3),
             ((1.12 * W, 1.10 * H), (0.85 * W, 0.92 * H), ROSE, 1.0, 2.1)]
    for (sx, sy), (mx, my), col, turns, ph in specs:
        pts = [(sx, sy), (mx, my), ((mx + cx) / 2 + (cy - my) * 0.25, (my + cy) / 2 - (cx - mx) * 0.25), (cx, cy)]
        l, cv = ribbon(pts, S * 0.055, turns, [col * 0.25, col, col * 1.2], phase=ph, pinch=True)
        lights.append(l)
        canvas = over(canvas, l, cv)
    total = sum(lights)
    canvas += glow(total, 0.8)
    canvas += tri_grid(S * 0.05, 1.0)[..., None] * blur(total, S * 0.08) * 0.9
    canvas = hub(canvas, cx, cy)

elif name == "ark-cross":
    # Two broad glass-blue and rose-amber bands cross, Nexus-like, over a lit lattice.
    l1, c1 = ribbon([(-0.1 * W, 0.95 * H), (0.35 * W, 0.75 * H), (0.6 * W, 0.25 * H), (1.1 * W, 0.05 * H)], S * 0.09, 0.8, [GLASS * 0.4, GLASS, LAV], phase=0.3)
    l2, c2 = ribbon([(0.15 * W, -0.1 * H), (0.4 * W, 0.4 * H), (0.7 * W, 0.6 * H), (1.1 * W, 1.05 * H)], S * 0.075, 1.1, [ROSE * 0.5, ROSE, AMBER], phase=1.2)
    canvas = over(canvas, l1, c1)
    canvas = over(canvas, l2, c2)
    total = l1 + l2
    canvas += glow(total, 0.7)
    canvas += tri_grid(S * 0.07, 1.0, 8)[..., None] * blur(total, S * 0.12) * 0.8
    for (px, py), col in zip([(0.2, 0.2), (0.82, 0.78), (0.12, 0.7), (0.9, 0.3)], [GREEN, AMBER, LAV, ROSE]):
        canvas = hub(canvas, px * W, py * H, 0.35) * 1.0
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        canvas += np.exp(-(np.hypot(xx - px * W, yy - py * H) / (S * 0.006)) ** 2)[..., None] * col * 2.5

elif name == "egkek":
    # Matched to the glass: two bands in the glass blue and a deeper cyan, a violet edge, a faint lattice.
    l1, c1 = ribbon([(-0.1 * W, 0.3 * H), (0.35 * W, 0.15 * H), (0.55 * W, 0.85 * H), (1.1 * W, 0.7 * H)], S * 0.085, 0.9, [hexc("#1a3a7a"), GLASS, hexc("#bfe3ff")], phase=0.5)
    l2, c2 = ribbon([(0.05 * W, 1.1 * H), (0.35 * W, 0.65 * H), (0.75 * W, 0.35 * H), (1.1 * W, -0.05 * H)], S * 0.05, 1.3, [hexc("#00b3c7") * 0.6, hexc("#2fd3e0"), hexc("#7a5cff")], phase=1.6)
    canvas = over(canvas, l2, c2)
    canvas = over(canvas, l1, c1)
    total = l1 + l2
    canvas += glow(total, 0.8)
    canvas += tri_grid(S * 0.06, 1.0, 20)[..., None] * blur(total, S * 0.1) * 0.8

else:
    raise SystemExit("unknown wallpaper " + name)

if mode == "light":
    # The same light as coloured ink on pale paper: hue kept, glow becomes tint.
    paper = lin([0.955, 0.958, 0.972])
    lum = canvas.max(axis=-1, keepdims=True)
    a = 1 - np.exp(-lum * 5)
    col = canvas / np.maximum(lum, 1e-4)
    canvas = paper * (1 - a) + col * 0.6 * a

img = enc(canvas)
# Dither: half a step of noise at 8 bits, so the dark glows do not band on an 8-bit screen.
img = np.clip(img + (rng.random(img.shape, np.float32) - rng.random(img.shape, np.float32)) / 255 * 0.5, 0, 1)
a16 = (img * 65535 + 0.5).astype(">u2")
raw = b"".join(b"\x00" + a16[y].tobytes() for y in range(H))


def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)


open(out, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 16, 2, 0, 0, 0))
                      + chunk(b"sRGB", b"\x00") + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
