"""ArkadeOS Glass craft (Roland, 2026-11-14): the materials and the two
marks of round 6 ("na ez egész jó lett"), shared by every icon generator so
that all icons are drawn with the same hand ("ilyen tökéletességre való
törekedéssel neki lehet állni az összes eddigi ikonnak és piktogramnak").

- Start: a crystal hexagon, a 12-facet bezel lit from the top, a gem core
  with a table and six facets, tapered rays with glints, 36 ticks.
- Portal: the same frame around a machined cool-metal gear with chamfered
  teeth, lathe rings, a bow-tie sheen and a glowing hex socket.

Each mark comes in four hand-drawn optical sizes (XL >= 160 px, L 64-159,
M 33-63, S <= 32) and two materials: "dk" for dark surfaces, "lt" for light
ones. Everything is mirror-symmetric on the hexagon's axes, light comes from
the top, nothing casts a shadow.

standalone() turns a drawing into a self-contained SVG for an icon theme:
the material table is resolved into plain attributes (no CSS variables,
rgba() split into colour and opacity) and only the gradients, filters and
clip paths it uses are copied in, so QtSvg (Plasma, Qt apps) and librsvg
(GTK apps) draw it the same way. Imported by glass-marks.py and
glass-app-icons.py; not run on its own."""
import math
import re

C = 60
POINTY, FLAT = -90, 0


def f(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def P(r, a):
    a = math.radians(a)
    return (C + r * math.cos(a), C + r * math.sin(a))


def pt(p):
    return f"{f(p[0])} {f(p[1])}"


def hexv(R, start):
    return [P(R, start + 60 * k) for k in range(6)]


def poly(ps):
    return "M" + pt(ps[0]) + "".join("L" + pt(p) for p in ps[1:]) + "Z"


# ---------------------------------------------------------------- materials
MODES = {
    "dk": {"halo": "url(#haloD)", "chamber": "url(#chamD)", "bloom": "url(#bloomD)", "hair": "rgba(159,211,248,.45)",
           "tick": "rgba(191,230,255,.5)", "ray": "url(#rayD)", "glint": "#ffffff", "glintGlow": "url(#glintD)",
           "bB": "#f4fbff", "bM1": "#a9daf9", "bM2": "#86c4f1", "bD": "#2f6fa9", "ridge": "url(#ridgeD)",
           "lip": "rgba(191,230,255,.55)", "glow": "#8fd0ff", "glowOp": ".8", "c1": "#ffffff", "c2": "#e4f5ff",
           "c3": "#a2d6f9", "c4": "#74bbf0", "table": "url(#tableD)", "fline": "rgba(255,255,255,.6)",
           "gline": "rgba(255,255,255,.75)", "edge": "url(#edgeD)", "sCore": "url(#sCoreD)", "sTable": "#ffffff",
           "gch": "url(#gchD)", "gchIn": "url(#gchInD)", "gface": "url(#gfaceD)", "hole": "url(#holeD)",
           "ring1": "rgba(255,255,255,.09)", "ring2": "rgba(10,30,50,.07)", "sheen": "rgba(255,255,255,.55)",
           "shade": "rgba(10,30,50,.16)", "grooveD": "rgba(10,30,50,.4)", "grooveL": "rgba(255,255,255,.6)"},
    "lt": {"halo": "url(#haloL)", "chamber": "url(#chamL)", "bloom": "url(#bloomL)", "hair": "rgba(27,83,144,.4)",
           "tick": "rgba(27,83,144,.45)", "ray": "url(#rayL)", "glint": "#1f64a6", "glintGlow": "url(#glintL)",
           "bB": "#5eaae6", "bM1": "#2f80c8", "bM2": "#2a74b8", "bD": "#0f3a63", "ridge": "url(#ridgeL)",
           "lip": "rgba(255,255,255,.7)", "glow": "#5aaeea", "glowOp": ".5", "c1": "#e6f4fe", "c2": "#b3dbf8",
           "c3": "#4f9ee0", "c4": "#2a77bf", "table": "url(#tableL)", "fline": "rgba(255,255,255,.85)",
           "gline": "rgba(31,100,166,.7)", "edge": "url(#edgeL)", "sCore": "url(#sCoreL)", "sTable": "#bfe2fb",
           "gch": "url(#gchL)", "gchIn": "url(#gchInL)", "gface": "url(#gfaceL)", "hole": "url(#holeL)",
           "ring1": "rgba(255,255,255,.12)", "ring2": "rgba(10,30,50,.08)", "sheen": "rgba(255,255,255,.45)",
           "shade": "rgba(10,30,50,.14)", "grooveD": "rgba(10,30,50,.45)", "grooveL": "rgba(255,255,255,.55)"},
}


def lg(id_, x1, y1, x2, y2, stops):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"{"" if a is None else f" stop-opacity=\"{a}\""}/>' for o, c, a in stops)
    return f'<linearGradient id="{id_}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def rg(id_, stops, us=None, extra=""):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"{"" if a is None else f" stop-opacity=\"{a}\""}/>' for o, c, a in stops)
    u = f' gradientUnits="userSpaceOnUse" cx="{us[0]}" cy="{us[1]}" r="{us[2]}"' if us else extra
    return f'<radialGradient id="{id_}"{u}>{s}</radialGradient>'


DEFS = {}


def define(*items):
    for item in items:
        DEFS[re.search(r'id="([^"]+)"', item).group(1)] = item


define(
    lg("edgeD", 60, 14, 60, 106, [(0, "#ffffff", None), (0.5, "#a8d8fa", None), (1, "#4f9ee0", None)]),
    lg("edgeL", 60, 14, 60, 106, [(0, "#3f93d6", None), (0.55, "#1f64a6", None), (1, "#123c63", None)]),
    rg("haloD", [(0, "#5aaeea", 0.22), (0.72, "#5aaeea", 0.07), (1, "#5aaeea", 0)], (60, 60, 60)),
    rg("haloL", [(0, "#5aaeea", 0.14), (0.72, "#5aaeea", 0.05), (1, "#5aaeea", 0)], (60, 60, 60)),
    rg("chamD", [(0, "#2a6aa3", 0.6), (0.55, "#10304d", 0.8), (1, "#081524", 0.9)], (60, 60, 42)),
    rg("chamL", [(0, "#ffffff", 0.95), (0.6, "#e4f2fd", 0.88), (1, "#c3def4", 0.85)], (60, 60, 42)),
    rg("bloomD", [(0, "#8fd0ff", 0.5), (0.5, "#5aaeea", 0.12), (1, "#5aaeea", 0)]),
    rg("bloomL", [(0, "#8fd0ff", 0.35), (1, "#8fd0ff", 0)]),
    lg("rayD", 77, 60, 92, 60, [(0, "#eaf7ff", 0.95), (1, "#8fd0ff", 0.08)]),
    lg("rayL", 77, 60, 92, 60, [(0, "#1f64a6", 0.8), (1, "#1f64a6", 0.06)]),
    rg("glintD", [(0, "#ffffff", 0.75), (1, "#8fd0ff", 0)]),
    rg("glintL", [(0, "#1f64a6", 0.45), (1, "#1f64a6", 0)]),
    lg("ridgeD", 60, 12, 60, 108, [(0, "#ffffff", 1), (1, "#ffffff", 0.18)]),
    lg("ridgeL", 60, 12, 60, 108, [(0, "#ffffff", 0.95), (1, "#ffffff", 0.25)]),
    rg("tableD", [(0, "#ffffff", None), (1, "#d8f0ff", None)], None, ' cx="0.5" cy="0.35" r="0.7"'),
    rg("tableL", [(0, "#ffffff", None), (1, "#a9d6f8", None)], None, ' cx="0.5" cy="0.35" r="0.7"'),
    lg("sCoreD", 60, 41, 60, 79, [(0, "#e0f3ff", None), (1, "#5aaeea", None)]),
    lg("sCoreL", 60, 41, 60, 79, [(0, "#4f9ee0", None), (1, "#1b5390", None)]),
    lg("gchD", 60, 31, 60, 89, [(0, "#ffffff", None), (0.4, "#d9e7f2", None), (0.7, "#7e9cb7", None), (1, "#3d5b78", None)]),
    lg("gchL", 60, 31, 60, 89, [(0, "#c7d9e8", None), (0.4, "#8aa7c0", None), (0.7, "#3e5b78", None), (1, "#1f3a55", None)]),
    lg("gchInD", 60, 50, 60, 70, [(0, "#2c4862", None), (1, "#f2f8fd", None)]),
    lg("gchInL", 60, 50, 60, 70, [(0, "#1f3a55", None), (1, "#dbe8f2", None)]),
    lg("gfaceD", 60, 34, 60, 86, [(0, "#e8f1f8", None), (1, "#9fb9cf", None)]),
    lg("gfaceL", 60, 34, 60, 86, [(0, "#a9c0d3", None), (1, "#5f7f9c", None)]),
    rg("holeD", [(0, "#ffffff", None), (0.5, "#bfe6ff", None), (1, "#4f9ee0", None)], (60, 60, 8)),
    rg("holeL", [(0, "#ffffff", None), (0.6, "#d6edfd", None), (1, "#8fc4ec", None)], (60, 60, 8)),
    '<filter id="soft" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="3.5"/></filter>',
    '<filter id="soft2" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="1.4"/></filter>',
)


# ---------------------------------------------------------------- the Start mark
def bezel(Ro, Rr, Ri):
    vo, vr, vi = hexv(Ro, POINTY), hexv(Rr, POINTY), hexv(Ri, POINTY)
    outer_tone = ["B", "M1", "D", "D", "M1", "B"]
    inner_tone = ["D", "M2", "B", "B", "M2", "D"]
    tones = {"B": [], "M1": [], "M2": [], "D": []}
    for k in range(6):
        n = (k + 1) % 6
        tones[outer_tone[k]].append(poly([vo[k], vo[n], vr[n], vr[k]]))
        tones[inner_tone[k]].append(poly([vr[k], vr[n], vi[n], vi[k]]))
    return {t: "".join(v) for t, v in tones.items()}, poly(vo), poly(vr), poly(vi)


def core(Rg, Rt):
    g, t = hexv(Rg, FLAT), hexv(Rt, FLAT)
    tone = ["c3", "c4", "c3", "c2", "c1", "c2"]
    d = {"c1": [], "c2": [], "c3": [], "c4": []}
    for k in range(6):
        n = (k + 1) % 6
        d[tone[k]].append(poly([g[k], g[n], t[n], t[k]]))
    lines = "".join("M" + pt(t[k]) + "L" + pt(g[k]) for k in range(6))
    return {k: "".join(v) for k, v in d.items()}, poly(g), poly(t), lines


def ticks(Rh, step, lens):
    ap = Rh * math.cos(math.radians(30))
    out = []
    for k in range(6):
        a = math.radians(60 * k)
        n = (math.cos(a), math.sin(a))
        t = (-n[1], n[0])
        M = (C + ap * n[0], C + ap * n[1])
        for i, L in lens.items():
            for s in (1, -1):
                d = s * i * step
                p = (M[0] + d * t[0], M[1] + d * t[1])
                q = (p[0] - L * n[0], p[1] - L * n[1])
                out.append("M" + pt(p) + "L" + pt(q))
    return "".join(out), ap


def ray(r0, r1, w0, w1):
    return poly([(C + r0, C - w0), (C + r1, C - w1), (C + r1, C + w1), (C + r0, C + w0)])


def _frame_big(lw, with_ticks, halo=True):
    bz, vo, vr, vi = bezel(48, 45, 42)
    tk, ap = ticks(37.5, 37.5 / 8, {1: 1.2, 2: 2.0, 3: 1.2})
    s = ['<circle cx="60" cy="60" r="60" style="fill: var(--halo)"/>'] if halo else []
    s += [f'<path d="{vi}" style="fill: var(--chamber)"/>',
          '<circle cx="60" cy="60" r="32" style="fill: var(--bloom)"/>',
          f'<path d="{poly(hexv(37.5, POINTY))}" fill="none" style="stroke: var(--hair)" stroke-width="{f(0.4 * lw)}" stroke-linejoin="round"/>']
    if with_ticks:
        s.append(f'<path d="{tk}" fill="none" style="stroke: var(--tick)" stroke-width="0.4" stroke-linecap="round"/>')
    return s, bz, vo, vr, vi, ap


def _rays_glints(r0, ap, lw):
    rp = ray(r0, ap - 0.6, 0.8 * lw, 0.12 * lw)
    s = []
    for k in range(6):
        tr = "" if k == 0 else f' transform="rotate({60 * k} 60 60)"'
        s.append(f'<path d="{rp}"{tr} style="fill: var(--ray)"/>')
    gl = [P(ap, 60 * k) for k in range(6)]
    s.append("".join(f'<circle cx="{f(p[0])}" cy="{f(p[1])}" r="{f(2.6 * lw ** 0.5)}" style="fill: var(--glintGlow)"/>' for p in gl))
    s.append("".join(f'<circle cx="{f(p[0])}" cy="{f(p[1])}" r="{f(0.7 * lw ** 0.5)}" style="fill: var(--glint)"/>' for p in gl))
    return s


def _bezel_layers(bz, vo, vr, vi, lw):
    s = [f'<path d="{vo}{vi}" fill-rule="evenodd" style="fill: var(--bM2)"/>']
    for t, var in (("D", "--bD"), ("M2", "--bM2"), ("M1", "--bM1"), ("B", "--bB")):
        s.append(f'<path d="{bz[t]}" style="fill: var({var})"/>')
    s.append(f'<path d="{vr}" fill="none" style="stroke: var(--ridge)" stroke-width="{f(0.45 * lw)}" stroke-linejoin="round"/>')
    s.append(f'<path d="{vo}" fill="none" style="stroke: var(--ridge)" stroke-opacity="0.5" stroke-width="{f(0.35 * lw)}" stroke-linejoin="round"/>')
    s.append(f'<path d="{vi}" fill="none" style="stroke: var(--lip)" stroke-width="{f(0.5 * lw)}" stroke-linejoin="round"/>')
    return s


def _gem(Rg, Rt, lw, glow_r):
    cf, girdle, table, flines = core(Rg, Rt)
    s = [f'<path d="{poly(hexv(glow_r, FLAT))}" filter="url(#soft)" style="fill: var(--glow); opacity: var(--glowOp)"/>',
         f'<path d="{girdle}" style="fill: var(--c3)"/>']
    for t in ("c4", "c3", "c2", "c1"):
        s.append(f'<path d="{cf[t]}" style="fill: var(--{t})"/>')
    s.append(f'<path d="{table}" style="fill: var(--table)"/>')
    if lw:
        s.append(f'<path d="{flines}{table}" fill="none" style="stroke: var(--fline)" stroke-width="{f(0.35 * lw)}" stroke-linejoin="round"/>')
    s.append(f'<path d="{girdle}" fill="none" style="stroke: var(--gline)" stroke-width="{f(0.55 * lw) if lw else "0.9"}" stroke-linejoin="round"/>')
    return s


def start(size, halo=True):
    """The Start mark at one optical size (XL, L, M, S), 120 x 120 units."""
    if size in ("XL", "L"):
        lw = 1.0 if size == "XL" else 1.5
        s, bz, vo, vr, vi, ap = _frame_big(lw, size == "XL", halo)
        s += _rays_glints(17.4, ap, lw)
        s += _bezel_layers(bz, vo, vr, vi, lw)
        s += _gem(16, 8, lw, 17.5)
        return "".join(s)
    if size == "M":
        vo, vi = poly(hexv(48, POINTY)), poly(hexv(41, POINTY))
        s = ['<circle cx="60" cy="60" r="60" style="fill: var(--halo)"/>'] if halo else []
        s += [f'<path d="{vi}" style="fill: var(--chamber)"/>',
              '<circle cx="60" cy="60" r="30" style="fill: var(--bloom)"/>',
              f'<path d="{vo}{vi}" fill-rule="evenodd" style="fill: var(--edge)"/>',
              f'<path d="{vi}" fill="none" style="stroke: var(--lip)" stroke-width="0.9" stroke-linejoin="round"/>']
        s += _gem(18, 9, 0, 19.5)
        return "".join(s)
    s = ['<circle cx="60" cy="60" r="60" style="fill: var(--halo)"/>'] if halo else []
    s += [f'<path d="{poly(hexv(46, POINTY))}" fill="none" style="stroke: var(--edge)" stroke-width="10" stroke-linejoin="round"/>',
          f'<path d="{poly(hexv(19, FLAT))}" style="fill: var(--sCore)"/>',
          f'<path d="{poly(hexv(9.5, FLAT))}" style="fill: var(--sTable)"/>']
    return "".join(s)


# ---------------------------------------------------------------- the Portal mark
def _gear_pts(Rt, Rr, ht, hr):
    d = []
    for k in range(6):
        c = -90 + 60 * k
        a0, a1, a2, a3, n = P(Rr, c - hr), P(Rt, c - ht), P(Rt, c + ht), P(Rr, c + hr), P(Rr, c + 60 - hr)
        d.append(("M" if k == 0 else "L") + pt(a0))
        d.append("L" + pt(a1))
        d.append(f"A{f(Rt)} {f(Rt)} 0 0 1 " + pt(a2))
        d.append("L" + pt(a3))
        d.append(f"A{f(Rr)} {f(Rr)} 0 0 1 " + pt(n))
    return "".join(d) + "Z"


def _inset(Rt, Rr, ht, hr, w):
    A = (Rr * math.cos(math.radians(-hr)), Rr * math.sin(math.radians(-hr)))
    B = (Rt * math.cos(math.radians(-ht)), Rt * math.sin(math.radians(-ht)))
    dx, dy = B[0] - A[0], B[1] - A[1]
    L = math.hypot(dx, dy)
    dx, dy = dx / L, dy / L
    n = (-dy, dx)
    if n[1] < 0:
        n = (dy, -dx)
    O = (A[0] + w * n[0], A[1] + w * n[1])

    def hit(R):
        b = 2 * (O[0] * dx + O[1] * dy)
        c = O[0] ** 2 + O[1] ** 2 - R * R
        s = (-b + math.sqrt(b * b - 4 * c)) / 2
        x, y = O[0] + s * dx, O[1] + s * dy
        return -math.degrees(math.atan2(y, x))
    Rt2, Rr2 = Rt - w, Rr - w
    return Rt2, Rr2, hit(Rt2), hit(Rr2)


_G = (25.5, 19, 11.5, 18)
_OUTER = _gear_pts(*_G)
_FACE = _gear_pts(*_inset(*_G, 1.8))
_GS = (28, 21, 12.5, 19)
_OUTER_S = _gear_pts(*_GS)
_FACE_S = _gear_pts(*_inset(*_GS, 3.2))
_GM = (27, 20, 12, 18.5)
_OUTER_M = _gear_pts(*_GM)
_FACE_M = _gear_pts(*_inset(*_GM, 2.4))
define(f'<clipPath id="gfClip"><path d="{_FACE}"/></clipPath>')


def _hexR(R):
    return poly(hexv(R, POINTY))


def _rev(R):
    v = hexv(R, POINTY)
    return poly([v[0]] + v[:0:-1])


def _wedge(a, half, r=30):
    return f"M60 60L{pt(P(r, a - half))}L{pt(P(r, a + half))}Z"


def _gear_big(texture):
    s = [f'<path d="{_hexR(7.6)}" style="fill: var(--hole)"/>',
         f'<path d="{_OUTER}{_rev(7.6)}" fill-rule="evenodd" style="fill: var(--gch); stroke: var(--gch)" stroke-width="1.6" stroke-linejoin="round"/>',
         f'<path d="{_hexR(9.6)}{_rev(7.6)}" fill-rule="evenodd" style="fill: var(--gchIn)"/>',
         f'<path d="{_FACE}{_rev(9.6)}" fill-rule="evenodd" style="fill: var(--gface); stroke: var(--gface)" stroke-width="0.8" stroke-linejoin="round"/>',
         '<g clip-path="url(#gfClip)">']
    if texture:
        rings = "".join(f'<circle cx="60" cy="60" r="{f(10.4 + 0.85 * j)}" style="stroke: var(--{"ring1" if j % 2 == 0 else "ring2"})"/>' for j in range(17))
        s.append(f'<g fill="none" stroke-width="0.32">{rings}</g>')
    s.append(f'<path d="{_wedge(-90, 19)}{_wedge(90, 19)}" filter="url(#soft2)" style="fill: var(--sheen)"/>')
    s.append(f'<path d="{_wedge(0, 24)}{_wedge(180, 24)}" filter="url(#soft2)" style="fill: var(--shade)"/>')
    s.append("</g>")
    s.append('<circle cx="60" cy="60" r="13.6" fill="none" style="stroke: var(--grooveD)" stroke-width="0.5" transform="translate(0 -0.3)"/>')
    s.append('<circle cx="60" cy="60" r="13.6" fill="none" style="stroke: var(--grooveL)" stroke-width="0.5" transform="translate(0 0.3)"/>')
    s.append(f'<path d="{_hexR(9.6)}" fill="none" style="stroke: var(--grooveL)" stroke-width="0.4" stroke-linejoin="round"/>')
    return s


def portal(size, halo=True):
    """The Portal mark at one optical size (XL, L, M, S), 120 x 120 units."""
    if size in ("XL", "L"):
        lw = 1.0 if size == "XL" else 1.5
        s, bz, vo, vr, vi, ap = _frame_big(lw, size == "XL", halo)
        s += _rays_glints(20.6, ap, lw)
        s += _bezel_layers(bz, vo, vr, vi, lw)
        s += _gear_big(size == "XL")
        return "".join(s)
    if size == "M":
        vo, vi = _hexR(48), _hexR(41)
        s = ['<circle cx="60" cy="60" r="60" style="fill: var(--halo)"/>'] if halo else []
        s += [f'<path d="{vi}" style="fill: var(--chamber)"/>',
              '<circle cx="60" cy="60" r="30" style="fill: var(--bloom)"/>',
              f'<path d="{vo}{vi}" fill-rule="evenodd" style="fill: var(--edge)"/>',
              f'<path d="{vi}" fill="none" style="stroke: var(--lip)" stroke-width="0.9" stroke-linejoin="round"/>',
              f'<path d="{_hexR(8.6)}" style="fill: var(--hole)"/>',
              f'<path d="{_OUTER_M}{_rev(8.6)}" fill-rule="evenodd" style="fill: var(--gch); stroke: var(--gch)" stroke-width="2" stroke-linejoin="round"/>',
              f'<path d="{_FACE_M}{_rev(11)}" fill-rule="evenodd" style="fill: var(--gface); stroke: var(--gface)" stroke-width="1" stroke-linejoin="round"/>']
        return "".join(s)
    s = ['<circle cx="60" cy="60" r="60" style="fill: var(--halo)"/>'] if halo else []
    s += [f'<path d="{_hexR(46)}" fill="none" style="stroke: var(--edge)" stroke-width="10" stroke-linejoin="round"/>',
          f'<path d="{_hexR(9.5)}" style="fill: var(--hole)"/>',
          f'<path d="{_OUTER_S}{_rev(9.5)}" fill-rule="evenodd" style="fill: var(--gch); stroke: var(--gch)" stroke-width="3" stroke-linejoin="round"/>',
          f'<path d="{_FACE_S}{_rev(12.4)}" fill-rule="evenodd" style="fill: var(--gface)"/>']
    return "".join(s)


def optical(px):
    """The optical size drawn for a target size in pixels."""
    return "XL" if px >= 160 else "L" if px >= 64 else "M" if px >= 33 else "S"


# ---------------------------------------------------------------- standalone SVG
def _paint(value):
    """A material value as (paint, opacity or None)."""
    m = re.fullmatch(r"rgba\((\d+),(\d+),(\d+),([\d.]+)\)", value)
    if m:
        r, g, b, a = m.groups()
        return f"#{int(r):02x}{int(g):02x}{int(b):02x}", float(a)
    return value, None


def resolve(body, mode):
    """The drawing with the material of mode written into plain attributes."""
    table = MODES[mode]

    def one(m):
        attrs = []
        for decl in m.group(1).split(";"):
            if not decl.strip():
                continue
            prop, val = (x.strip() for x in decl.split(":", 1))
            v = re.fullmatch(r"var\(--([A-Za-z0-9]+)\)", val)
            val = table[v.group(1)] if v else val
            if prop == "opacity":
                attrs.append(f'opacity="{val}"')
                continue
            paint, alpha = _paint(val)
            attrs.append(f'{prop}="{paint}"')
            if alpha is not None:
                attrs.append(f'{prop}-opacity="{f(alpha)}"')
        return " ".join(attrs)
    out = re.sub(r'style="([^"]*)"', one, body)
    # an opacity written twice (the drawing's own and the material's) multiplies
    def merge(tag):
        t = tag.group(0)
        for prop in ("stroke-opacity", "fill-opacity"):
            vals = re.findall(rf' {prop}="([\d.]+)"', t)
            if len(vals) > 1:
                prod = 1.0
                for v in vals:
                    prod *= float(v)
                t = re.sub(rf' {prop}="[\d.]+"', "", t)
                t = t.replace("/>", f' {prop}="{f(prod)}"/>', 1) if t.endswith("/>") else t[:-1] + f' {prop}="{f(prod)}">'
        return t
    return re.sub(r"<[a-zA-Z][^<>]*>", merge, out)


def _needed(text):
    ids, todo = [], re.findall(r"url\(#([^)]+)\)", text)
    while todo:
        i = todo.pop(0)
        if i in ids or i not in DEFS:
            continue
        ids.append(i)
        todo += re.findall(r"url\(#([^)]+)\)", DEFS[i])
    return ids


def standalone(body, mode, view=120, size=None, label=None, comment=None, extra_defs=()):
    """A self-contained SVG of a drawing (120 x 120 units unless view says)."""
    for item in extra_defs:
        define(item)
    text = resolve(body, mode)
    defs = "".join(DEFS[i] for i in _needed(text))
    px = size or view
    a = f' role="img" aria-label="{label}"' if label else ""
    c = f"<!-- {comment} -->" if comment else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {view} {view}" width="{px}" height="{px}"{a}>'
            f'{c}<defs>{defs}</defs>{text}</svg>\n')
