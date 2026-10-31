"""ArkadeOS wallpaper "Ark" (T009, picked by Roland from four drafts).
Renders in linear light, Display P3 primaries, 16 bits per channel.
Usage: wallpaper.py A <w> <h> <dark|light> <out.png>
(art/render-wallpaper.sh makes every size and encodes JPEG XL)."""
import struct
import sys
import zlib

import numpy as np
from PIL import Image

draft, W, H, mode, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5]
rng = np.random.default_rng(7)
S = min(W, H)  # scale unit


def lin(c):  # P3-encoded (sRGB curve) -> linear
    c = np.asarray(c, np.float32)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def enc(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


# Ark palette pushed to the edge of P3 (the mark's sRGB hexes are the anchors)
GREEN = lin([0.20, 0.90, 0.38])
AMBER = lin([1.00, 0.64, 0.05])
LAVENDER = lin([0.74, 0.74, 1.00])
ROSE = lin([1.00, 0.18, 0.36])
PAL = [GREEN, AMBER, LAVENDER, ROSE]


def blur(img, sigma):
    """Gaussian blur in the frequency domain, zero-padded so edges do not wrap."""
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
    out = np.fft.irfft2(np.fft.rfft2(p, axes=(0, 1)) * k, s=p.shape[:2], axes=(0, 1))
    return out[pad:pad + h, pad:pad + w].astype(np.float32)


def splat(canvas, xs, ys, col, weight=1.0):
    xi = np.clip(xs.astype(np.int64), 0, W - 1)
    yi = np.clip(ys.astype(np.int64), 0, H - 1)
    ok = (xs >= 0) & (xs < W) & (ys >= 0) & (ys < H)
    w = np.broadcast_to(np.asarray(weight, np.float32), xs.shape)[ok]
    for ch in range(3):
        np.add.at(canvas[..., ch], (yi[ok], xi[ok]), w * col[ch])


def glow(core):
    """Sharp core plus soft halo layers: light, not paint."""
    s = S / 1000
    return core * 0.9 + blur(core, 1.2 * s) * 1.6 + blur(core, 8 * s) * 1.2 + blur(core, 40 * s) * 0.9


canvas = np.zeros((H, W, 3), np.float32)

if draft == "A":  # Ark: four light filaments sweep in from the edges to one bright point
    cx, cy = W * 0.62, H * 0.58
    starts = [(-0.1, -0.1), (1.1, -0.15), (-0.15, 1.1), (1.1, 1.1)]
    for (sx, sy), col in zip(starts, PAL):
        for strand in range(26):
            t = np.linspace(0, 1, 9000, dtype=np.float32)
            off = (strand - 13) / 13
            bx, by = sx * W + off * S * 0.05, sy * H - off * S * 0.03
            # quadratic curve bending around the centre
            mx = (bx + cx) / 2 + (cy - by) * 0.35
            my = (by + cy) / 2 + (bx - cx) * 0.35
            x = (1 - t) ** 2 * bx + 2 * (1 - t) * t * mx + t * t * cx
            y = (1 - t) ** 2 * by + 2 * (1 - t) * t * my + t * t * cy
            fade = (t ** 1.6) * (0.25 + 0.75 * np.exp(-abs(off) * 2.5))
            splat(canvas, x, y, col, fade * 0.010 * (W / 1600))
    core = canvas
    canvas = glow(core)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.hypot(xx - cx, yy - cy) / S
    canvas += (np.exp(-(d / 0.012) ** 2) * 1.4 + np.exp(-(d / 0.05) ** 2) * 0.10)[..., None] * lin([1, 1, 1])

if mode == "light":
    # Same strokes as coloured ink on pale paper: hue kept, glow becomes tint.
    paper = lin([0.955, 0.955, 0.97])
    lum = canvas.max(axis=-1, keepdims=True)
    a = 1 - np.exp(-lum * 7)
    col = canvas / np.maximum(lum, 1e-4)
    canvas = paper * (1 - a) + col * 0.55 * a

img = enc(canvas)
arr = (img * 65535 + 0.5).astype(">u2")
# 8-bit preview next to the 16-bit master
Image.frombytes("RGB", (W, H), (img * 255 + 0.5).astype(np.uint8).tobytes()).save(out.replace(".png", ".8bit.png"))


def png16(path, a):
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(a.shape[0]))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    # cICP: Display P3 primaries (12), sRGB transfer (13), RGB, full range
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 16, 2, 0, 0, 0)) \
        + chunk(b"cICP", bytes([12, 13, 0, 1])) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    open(path, "wb").write(data)
png16(out, arr)
