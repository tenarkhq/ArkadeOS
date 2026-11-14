"""The ArkadeOS boot animation, the drawing itself (round 8b; Roland, 2026-11-14:
"ennél vmi látványosabb boot animáció kell", then "így jó").

Sparks rush in from the dark, the six crystal bezel pieces of the Start mark
fly in and lock with a glint each, the gem ignites with a flash, a flare across
the screen and two hexagonal shock waves, the rays shoot out and the ARKADEOS
word comes up. While the machine boots, a light runs round the mark's 36 ticks,
a sheen sweeps the bezel, slow beams turn behind it and motes drift out.

scene() returns the drawing as an animated SVG (CSS keyframes) on a 1180 x 664
screen; the design canvas shows it, the CSS variable --t freezes it at a moment
(with --ps: paused). Every part is a layer (data-l) whose own motion is kept
in GEO, so art/boot-sprites.js can render each layer once and the Plymouth
script (art/boot.script.in) can move it with the same timing.

Usage: boot_scene.py <out.html> <out.json>  (the page the sprite renderer loads)
"""
import json
import math
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glass_craft as K  # noqa: E402

T = 9.0                      # the preview's cycle; on the machine the opening runs once
W, H, SIZE = 1180, 664, 230  # the design screen and the mark's size on it
CX, CY = W / 2, H * 0.46
OUT = (0.16, 0.84, 0.24, 1)
IN = (0.6, 0, 0.9, 0.45)
POP = (0.3, 1.6, 0.5, 1)
WAVE = (0.2, 0.7, 0.3, 1)
EASE = {"linear": (0, 0, 1, 1), "ease-out": (0, 0, 0.58, 1), "ease-in": (0.42, 0, 1, 1), "ease-in-out": (0.42, 0, 0.58, 1),
        "out": OUT, "in": IN, "pop": POP, "wave": WAVE}
f = K.f
rnd = random.Random(7)
_KF = []
_n = [0]
GEO = {"screen": [W, H], "center": [CX, CY], "size": SIZE, "ease": EASE, "gates": {}}


def css_ease(name):
    if name in (None, "linear"):
        return None
    if name in ("ease-out", "ease-in", "ease-in-out"):
        return name
    return "cubic-bezier({},{},{},{})".format(*EASE[name])


def kf(frames):
    """Keyframes from (seconds, css, easing name to the next) on the T cycle; returns the name."""
    _n[0] += 1
    name = f"ba{_n[0]}"
    if frames[-1][0] < T:
        frames = list(frames) + [(T, frames[-1][1], None)]
    out = []
    for t, css, ease in frames:
        e = css_ease(ease)
        out.append(f"{100 * t / T:.3f}% {{ {css};{f' animation-timing-function: {e};' if e else ''} }}")
    _KF.append(f"@keyframes {name} {{ {' '.join(out)} }}")
    return name


def A(name, d=0.0, dur=None, extra=""):
    s = f"animation-name: {name}; --d: {d:.3f}s"
    if dur:
        s += f"; --dur: {dur:.3f}s"
    return f' class="{"bl" if dur else "ba"}" style="{s}{extra}"'


def gate(layer, frames):
    """A layer's opacity over time: (seconds, opacity, easing to the next)."""
    GEO["gates"][layer] = [[t, v, e or "linear"] for t, v, e in frames]
    return f' data-l="{layer}"' + A(kf([(t, f"opacity: {v}", e) for t, v, e in frames]))


def mark():
    """The Start mark, every part a layer (120 units)."""
    vo, vr, vi = (K.hexv(R, K.POINTY) for R in (48, 45, 42))
    tone = {"B": "#f4fbff", "M1": "#a9daf9", "M2": "#86c4f1", "D": "#2f6fa9"}
    outer_t = ["B", "M1", "D", "D", "M1", "B"]
    inner_t = ["D", "M2", "B", "B", "M2", "D"]
    s = []
    # halo and the dark chamber come up as the pieces lock
    s.append(f'<g{gate("halo", [(0, 0, None), (1.55, 0, "ease-out"), (2.3, 1, None)])}><circle cx="60" cy="60" r="60" fill="url(#haloD)"/></g>')
    s.append(f'<g{gate("chamber", [(0, 0, None), (1.2, 0, "ease-out"), (1.6, 1, None)])}>'
             f'<path d="{K.poly(vi)}" fill="url(#chamD)"/>'
             f'<path d="{K.poly(K.hexv(37.5, K.POINTY))}" fill="none" stroke="#9fd3f8" stroke-opacity=".45" stroke-width=".4" stroke-linejoin="round"/></g>')
    # the core's bloom: flares at ignition, then breathes (2.4 s)
    s.append(f'<g{gate("bloom", [(0, 0, None), (1.62, 0, "ease-out"), (1.8, 1, "ease-in-out"), (2.6, 0.55, None)])}>'
             f'<circle cx="60" cy="60" r="32" fill="url(#bloomD)"{A("breathe", 0, 2.4)}/></g>')
    GEO["breathe"] = {"period": 2.4, "low": 0.55}
    # ticks: dim, then a light runs round them (the loading sign, 1.6 s a lap)
    tks = []
    ap = 37.5 * math.cos(math.radians(30))
    step = 37.5 / 8
    for k in range(6):
        a = math.radians(60 * k)
        n = (math.cos(a), math.sin(a))
        t = (-n[1], n[0])
        M = (60 + ap * n[0], 60 + ap * n[1])
        for i, L in {1: 1.2, 2: 2.0, 3: 1.2}.items():
            for sg in (1, -1):
                d = sg * i * step
                p = (M[0] + d * t[0], M[1] + d * t[1])
                q = (p[0] - L * n[0], p[1] - L * n[1])
                ang = (math.degrees(math.atan2(p[1] - 60, p[0] - 60)) + 90) % 360
                tks.append((ang, f"M{K.pt(p)}L{K.pt(q)}", ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)))
    tks.sort()
    GEO["ticks"] = [[round(c[0], 3), round(c[1], 3)] for _, _, c in tks]
    GEO["chase"] = {"period": 1.6, "tail": 0.34}
    s.append(f'<g{gate("ticks", [(0, 0, None), (1.5, 0, "ease-out"), (2.0, 1, None)])}>'
             f'<path d="{"".join(d for _, d, _ in tks)}" fill="none" stroke="#bfe6ff" stroke-opacity=".45" stroke-width=".4" stroke-linecap="round"/></g>')
    lit = [f'<path d="{d}"{A("chase", i / len(tks) * 1.6, 1.6)}/>' for i, (_, d, _) in enumerate(tks)]
    s.append(f'<g{gate("lit", [(0, 0, None), (2.3, 0, "ease-out"), (2.7, 1, None)])}>'
             f'<g fill="none" stroke="#8fd0ff" stroke-width="2.4" stroke-linecap="round" filter="url(#soft2)">{"".join(lit)}</g>'
             f'<g fill="none" stroke="#ffffff" stroke-width=".8" stroke-linecap="round">{"".join(lit)}</g></g>')
    # rays shoot out of the gem (a short sequence, rendered frame by frame)
    rp = K.ray(17.4, ap - 0.6, 0.8, 0.12)
    rays = []
    for k in range(6):
        nm = kf([(0, "transform: scaleX(.05) scaleY(.4); opacity: 0", None), (1.78 + 0.02 * k, "transform: scaleX(.05) scaleY(.4); opacity: 0", "out"),
                 (2.15 + 0.02 * k, "transform: scaleX(1.08) scaleY(1.3); opacity: 1", "ease-out"), (2.45, "transform: none; opacity: 1", None)])
        rays.append(f'<g transform="rotate({60 * k} 60 60)"><path d="{rp}" fill="url(#rayD)"{A(nm, extra="; transform-origin: 60px 60px")}/></g>')
    s.append(f'<g data-l="rays">{"".join(rays)}</g>')
    GEO["rays"] = {"from": 1.78, "to": 2.46}
    # the bezel: six pieces fly in along their normals and lock
    GEO["pieces"] = []
    for k in range(6):
        nx = (k + 1) % 6
        am = math.radians(-60 + 60 * k)
        dx, dy = 70 * math.cos(am), 70 * math.sin(am)
        rot = 18 if k % 2 else -18
        t0, t1 = 0.85 + 0.08 * k, 1.45 + 0.08 * k
        nm = kf([(0, f"transform: translate({f(dx)}px, {f(dy)}px) rotate({rot}deg); opacity: 0", None),
                 (t0, f"transform: translate({f(dx)}px, {f(dy)}px) rotate({rot}deg); opacity: 0", "out"),
                 (t0 + 0.12, "opacity: 1", "out"), (t1, "transform: none; opacity: 1", None)])
        mid = ((vo[k][0] + vo[nx][0]) / 2, (vo[k][1] + vo[nx][1]) / 2)
        GEO["pieces"].append({"t0": t0, "t1": t1, "fade": 0.12, "dx": round(dx, 3), "dy": round(dy, 3), "rot": rot,
                              "pivot": [round(mid[0], 3), round(mid[1], 3)]})
        s.append(f'<g data-l="piece{k}"{A(nm, extra=f"; transform-origin: {f(mid[0])}px {f(mid[1])}px")}>'
                 f'<path d="{K.poly([vo[k], vo[nx], vr[nx], vr[k]])}" fill="{tone[outer_t[k]]}"/>'
                 f'<path d="{K.poly([vr[k], vr[nx], vi[nx], vi[k]])}" fill="{tone[inner_t[k]]}"/></g>')
    # ...the seams close and the edges catch the light
    s.append(f'<g{gate("ridge", [(0, 0, None), (1.85, 0, "ease-out"), (2.2, 1, None)])}>'
             f'<path d="{K.poly(vr)}" fill="none" stroke="url(#ridgeD)" stroke-width=".45" stroke-linejoin="round"/>'
             f'<path d="{K.poly(vo)}" fill="none" stroke="url(#ridgeD)" stroke-opacity=".5" stroke-width=".35" stroke-linejoin="round"/>'
             f'<path d="{K.poly(vi)}" fill="none" stroke="#bfe6ff" stroke-opacity=".55" stroke-width=".5" stroke-linejoin="round"/></g>')
    # the sheen that sweeps the bezel while loading (2.8 s, moving for 55 % of it)
    s.append(f'<clipPath id="bzClip"><path d="{K.poly(vo)}{K.poly(vi)}" fill-rule="evenodd" clip-rule="evenodd"/></clipPath>')
    s.append(f'<g clip-path="url(#bzClip)"{gate("sheen", [(0, 0, None), (2.4, 0, None), (2.6, 1, None)])}>'
             f'<g transform="rotate(25 60 60)"><rect x="-30" y="-20" width="26" height="160" fill="url(#sheenG)"{A("sweep", 0, 2.8)}/></g></g>')
    GEO["sweep"] = {"period": 2.8, "moving": 0.55, "travel": 200}
    # the gem ignites
    gem = K.resolve("".join(K._gem(16, 8, 1.0, 17.5)), "dk")
    nm = kf([(0, "transform: scale(0); opacity: 0", None), (1.62, "transform: scale(0); opacity: 0", "pop"),
             (1.95, "transform: scale(1); opacity: 1", None)])
    s.append(f'<g data-l="gem"{A(nm, extra="; transform-origin: 60px 60px")}>{gem}</g>')
    GEO["gem"] = {"from": 1.62, "to": 1.95, "ease": "pop"}
    # glints at the ray tips, lit as each piece locks, then twinkling (2.2 s)
    GEO["glints"] = []
    for k in range(6):
        p = K.P(ap, 60 * k)
        t1 = 1.45 + 0.08 * k
        nm = kf([(0, "transform: scale(0); opacity: 0", None), (t1 - 0.02, "transform: scale(0); opacity: 0", "ease-out"),
                 (t1 + 0.1, "transform: scale(2.4); opacity: 1", "ease-in"), (t1 + 0.45, "transform: scale(1); opacity: 1", None)])
        GEO["glints"].append({"p": [round(p[0], 3), round(p[1], 3)], "lit": t1, "twinkle": round(0.37 * k, 3)})
        o = f"; transform-origin: {f(p[0])}px {f(p[1])}px"
        s.append(f'<g data-l="glint{k}"{A(nm, extra=o)}><g{A("twinkle", 0.37 * k, 2.2, o)}>'
                 f'<circle cx="{f(p[0])}" cy="{f(p[1])}" r="2.6" fill="url(#glintD)"/>'
                 f'<path d="M{f(p[0] - 4)} {f(p[1])}H{f(p[0] + 4)}M{f(p[0])} {f(p[1] - 4)}V{f(p[1] + 4)}" stroke="#ffffff" stroke-width=".35" stroke-linecap="round" opacity=".8"/>'
                 f'<circle cx="{f(p[0])}" cy="{f(p[1])}" r=".7" fill="#ffffff"/></g></g>')
    GEO["twinkle"] = {"period": 2.2, "keys": [[0, 1, 1], [0.12, 1.7, 1], [0.3, 0.85, 0.7], [1, 1, 1]]}
    # ignition: flash and two hexagonal shock waves
    s.append(f'<circle data-l="flash" cx="60" cy="60" r="40" fill="url(#flashG)"'
             f'{A(kf([(0, "transform: scale(.1); opacity: 0", None), (1.66, "transform: scale(.1); opacity: 0", "ease-out"), (1.76, "transform: scale(.9); opacity: 1", "ease-out"), (2.4, "transform: scale(2.6); opacity: 0", None)]), extra="; transform-origin: 60px 60px")}/>')
    GEO["flash"] = [[1.66, 0.1, 0, "ease-out"], [1.76, 0.9, 1, "ease-out"], [2.4, 2.6, 0, "linear"]]
    GEO["shocks"] = []
    for i in range(2):
        t0 = 1.72 + 0.14 * i
        s.append(f'<path data-l="shock{i}" d="{K.poly(vo)}" fill="none" stroke="{"#bfe6ff" if i == 0 else "#5aaeea"}" stroke-width="{1.6 - 0.6 * i}" stroke-linejoin="round"'
                 f'{A(kf([(0, "transform: scale(1); opacity: 0", None), (t0 - 0.01, "transform: scale(1); opacity: 0", None), (t0, "transform: scale(1); opacity: .95", "wave"), (t0 + 0.9, f"transform: scale({2.9 + 0.5 * i}); opacity: 0", None)]), extra="; transform-origin: 60px 60px")}/>')
        GEO["shocks"].append([[t0, 1, 0.95, "wave"], [t0 + 0.9, 2.9 + 0.5 * i, 0, "linear"]])
    return "".join(s)


DEFS = "".join(K.DEFS[i] for i in ("haloD", "chamD", "bloomD", "rayD", "glintD", "ridgeD", "tableD", "soft", "soft2")) + (
    '<linearGradient id="sheenG" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffffff" stop-opacity="0"/>'
    '<stop offset=".5" stop-color="#ffffff" stop-opacity=".75"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient>'
    '<radialGradient id="flashG"><stop offset="0" stop-color="#ffffff"/><stop offset=".35" stop-color="#d9f1ff" stop-opacity=".8"/>'
    '<stop offset="1" stop-color="#5aaeea" stop-opacity="0"/></radialGradient>'
    '<linearGradient id="sparkG" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffffff"/><stop offset=".25" stop-color="#bfe6ff" stop-opacity=".8"/>'
    '<stop offset="1" stop-color="#5aaeea" stop-opacity="0"/></linearGradient>'
    '<radialGradient id="ambG"><stop offset="0" stop-color="#2f7fc4" stop-opacity=".55"/><stop offset=".45" stop-color="#16456e" stop-opacity=".22"/>'
    '<stop offset="1" stop-color="#0a1826" stop-opacity="0"/></radialGradient>'
    '<linearGradient id="beamG" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8fd0ff" stop-opacity=".26"/>'
    '<stop offset=".5" stop-color="#5aaeea" stop-opacity=".1"/><stop offset="1" stop-color="#5aaeea" stop-opacity="0"/></linearGradient>'
    '<linearGradient id="flareG" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#5aaeea" stop-opacity="0"/>'
    '<stop offset=".5" stop-color="#ffffff"/><stop offset="1" stop-color="#5aaeea" stop-opacity="0"/></linearGradient>'
    '<filter id="beamBlur" filterUnits="userSpaceOnUse" x="-2000" y="-2000" width="4000" height="4000"><feGaussianBlur stdDeviation="6"/></filter>'
    '<filter id="spkGlow" filterUnits="userSpaceOnUse" x="-2000" y="-2000" width="6000" height="6000">'
    '<feGaussianBlur stdDeviation="2.2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')

SPARK_DURS = (0.5, 0.62, 0.75)
SPARK = [kf([(0, "transform: translateX(var(--r0)) scaleX(.12); opacity: 0", None), (0.1, "opacity: 1", "in"),
             (dur, "transform: translateX(var(--r1)) scaleX(1); opacity: 1", None), (dur + 0.06, "transform: translateX(var(--r1)) scaleX(.2); opacity: 0", None),
             (T, "opacity: 0", None)]) for dur in SPARK_DURS]

KF_LOOPS = """
@keyframes spin { to { transform: rotate(360deg) } }
@keyframes breathe { 0%,100% { opacity: .55 } 50% { opacity: 1 } }
@keyframes chase { 0% { opacity: 1 } 34% { opacity: 0 } 100% { opacity: 0 } }
@keyframes sweep { 0% { transform: translateX(0) } 55%,100% { transform: translateX(200px) } }
@keyframes twinkle { 0%,100% { transform: scale(1); opacity: 1 } 12% { transform: scale(1.7); opacity: 1 } 30% { transform: scale(.85); opacity: .7 } }
@keyframes mote { 0% { transform: translateX(var(--r0)); opacity: 0 } 15% { opacity: var(--o) } 100% { transform: translateX(var(--r1)); opacity: 0 } }
.ba { animation-duration: 9s; animation-iteration-count: infinite; animation-fill-mode: both; animation-timing-function: linear;
      animation-delay: calc(var(--d, 0s) - var(--t, 0s)); animation-play-state: var(--ps, running) }
.bl { animation-duration: var(--dur); animation-iteration-count: infinite; animation-fill-mode: both; animation-timing-function: ease-in-out;
      animation-delay: calc(var(--d, 0s) - var(--t, 0s)); animation-play-state: var(--ps, running) }
"""


def scene(word=True):
    """The whole animated drawing as an <svg> (W x H units, filling its box)."""
    size = SIZE
    s = [f'<svg viewBox="0 0 {W} {H}" width="100%" height="100%" preserveAspectRatio="xMidYMid slice" style="display: block" aria-label="ArkadeOS boot animation">'
         f'<defs>{DEFS}</defs><rect data-l="bg" width="{W}" height="{H}" fill="#000"/>']
    master = kf([(0, "opacity: 0", None), (0.15, "opacity: 1", None), (8.35, "opacity: 1", "ease-in"), (8.9, "opacity: 0", None), (T, "opacity: 0", None)])
    s.append(f'<g data-m="1"{A(master)}>')
    # ambient light: wakes at ignition, then stays as a faint glow
    s.append(f'<circle cx="{f(CX)}" cy="{f(CY)}" r="{f(size * 2.4)}" fill="url(#ambG)"'
             f'{gate("amb", [(0, 0, None), (1.62, 0, "ease-out"), (1.85, 1, "ease-in-out"), (3.2, 0.55, None)])}/>')
    # slow beams of light behind the mark once it is lit (a turn in 36 s)
    beams = []
    for k in range(6):
        a = 30 + 60 * k
        L, w = size * 2.7, size * 0.16
        beams.append(f'<path d="M0 {f(-w * 0.12)}L{f(L)} {f(-w)}L{f(L)} {f(w)}L0 {f(w * 0.12)}Z" fill="url(#beamG)" transform="rotate({a})"/>')
    s.append(f'<g transform="translate({f(CX)} {f(CY)})"{gate("beams", [(0, 0, None), (1.75, 0, "ease-out"), (2.0, 1, "ease-in-out"), (3.0, 0.6, None)])}>'
             f'<g filter="url(#beamBlur)"><g{A("spin", 0, 36, "; animation-timing-function: linear")}>{"".join(beams)}</g></g></g>')
    GEO["spin"] = 36
    # sparks rushing in from the dark
    sp, GEO["sparks"] = [], []
    for i in range(46):
        a = rnd.uniform(0, 360)
        r0 = rnd.uniform(0.55, 1.05) * math.hypot(W, H) / 2
        r1 = size * rnd.uniform(0.34, 0.5)
        L = rnd.uniform(26, 70)
        d = rnd.uniform(0.15, 1.05)
        w = rnd.choice((1.2, 1.6, 2.2))
        j = rnd.randrange(3)
        GEO["sparks"].append({"a": round(a, 3), "r0": round(r0, 2), "r1": round(r1, 2), "L": round(L, 2), "w": w, "d": round(d, 3), "dur": SPARK_DURS[j]})
        sp.append(f'<g transform="translate({f(CX)} {f(CY)}) rotate({f(a)})"><rect x="0" y="{f(-w / 2)}" width="{f(L)}" height="{f(w)}" rx="{f(w / 2)}" fill="url(#sparkG)"'
                  f'{A(SPARK[j], d, extra=f"; --r0: {f(r0)}px; --r1: {f(r1)}px")}/></g>')
    s.append(f'<g data-l="sparks" filter="url(#spkGlow)">{"".join(sp)}</g>')
    # drifting motes while loading
    mo, GEO["motes"] = [], []
    for i in range(34):
        a = rnd.uniform(0, 360)
        dur = rnd.uniform(3.5, 7)
        r = rnd.uniform(0.7, 1.8)
        dl = -rnd.uniform(0, dur)
        r0, r1, o = size * rnd.uniform(0.55, 0.8), size * rnd.uniform(1.6, 2.9), rnd.uniform(0.35, 0.9)
        GEO["motes"].append({"a": round(a, 3), "dur": round(dur, 3), "d": round(dl, 3), "r": round(r, 2), "r0": round(r0, 2), "r1": round(r1, 2), "o": round(o, 2)})
        mo.append(f'<g transform="translate({f(CX)} {f(CY)}) rotate({f(a)})"><circle cx="0" cy="0" r="{f(r)}" fill="#bfe6ff"'
                  f'{A("mote", dl, dur, f"; --r0: {f(r0)}px; --r1: {f(r1)}px; --o: {o:.2f}; animation-timing-function: linear")}/></g>')
    s.append(f'<g{gate("motes", [(0, 0, None), (2.2, 0, None), (3.0, 1, None)])}>{"".join(mo)}</g>')
    # the mark
    s.append(f'<svg x="{f(CX - size / 2)}" y="{f(CY - size / 2)}" width="{f(size)}" height="{f(size)}" viewBox="0 0 120 120" overflow="visible">{mark()}</svg>')
    # the flare across the screen at ignition
    s.append(f'<g transform="translate({f(CX)} {f(CY)})"><rect data-l="flare0" x="{f(-W * 0.42)}" y="-1.5" width="{f(W * 0.84)}" height="3" fill="url(#flareG)"'
             f'{A(kf([(0, "transform: scaleX(0); opacity: 0", None), (1.66, "transform: scaleX(0); opacity: 0", "out"), (1.8, "transform: scaleX(1); opacity: 1", "ease-in"), (2.5, "transform: scaleX(1.15); opacity: 0", None)]), extra="; transform-origin: 0px 0px")}/>'
             f'<rect data-l="flare1" x="{f(-W * 0.2)}" y="-7" width="{f(W * 0.4)}" height="14" fill="url(#flareG)" filter="url(#beamBlur)"'
             f'{A(kf([(0, "transform: scaleX(0); opacity: 0", None), (1.66, "transform: scaleX(0); opacity: 0", "out"), (1.82, "transform: scaleX(1); opacity: .7", "ease-in"), (2.4, "transform: scaleX(1.2); opacity: 0", None)]), extra="; transform-origin: 0px 0px")}/></g>')
    GEO["flares"] = [[[1.66, 0, 0, "out"], [1.8, 1, 1, "ease-in"], [2.5, 1.15, 0, "linear"]],
                     [[1.66, 0, 0, "out"], [1.82, 1, 0.7, "ease-in"], [2.4, 1.2, 0, "linear"]]]
    # the word, once the light is up
    GEO["word"] = {"from": 2.35, "to": 3.1, "opacity": 0.92, "rise": 8, "ease": "out", "y": round(CY + size * 0.86, 2)}
    if word:
        s.append(f'<text data-l="word" x="{f(CX)}" y="{f(CY + size * 0.5 + size * 0.36)}" text-anchor="middle" font-family="Inter, system-ui, sans-serif" font-weight="300" '
                 f'font-size="{f(size * 0.15)}" letter-spacing="{f(size * 0.15 * 0.34)}" fill="#eef6fd"'
                 f'{A(kf([(0, "opacity: 0; transform: translateY(8px)", None), (2.35, "opacity: 0; transform: translateY(8px)", "out"), (3.1, "opacity: .92; transform: none", None)]))}>ARKADEOS</text>')
    s.append("</g></svg>")
    return "".join(s)


def css():
    return KF_LOOPS + "\n".join(_KF)


def prefixed(svg, pfx="ba-"):
    """The drawing with its ids prefixed, to sit beside other drawings on one page."""
    for i in sorted(set(re.findall(r'id="([^"]+)"', svg)), key=len, reverse=True):
        svg = svg.replace(f'id="{i}"', f'id="{pfx}{i}"').replace(f"url(#{i})", f"url(#{pfx}{i})")
    return svg


if __name__ == "__main__":
    svg = scene()
    page = (f'<!doctype html><html><head><meta charset="utf-8"><style>html,body{{margin:0;background:transparent}}'
            f'@font-face{{font-family:Inter;font-weight:300;src:url("{os.environ.get("INTER_LIGHT", "/usr/share/fonts/rsms-inter-fonts/Inter-Light.ttf")}")}}'
            f'#s{{position:fixed;inset:0}}{css()}</style><style id="ov"></style></head><body><div id="s">{svg}</div></body></html>')
    open(sys.argv[1], "w").write(page)
    json.dump(GEO, open(sys.argv[2], "w"), indent=1)
    print("scene", len(svg), "layers", len(set(re.findall(r'data-l="([^"]+)"', svg))))
