// Boot screen (round 8b, approved 2026-11-14; round 9, art/boot_iris.py, builds
// on these sprites and replaces the script, so run that after this): renders every layer of the boot
// animation (art/boot_scene.py) as PNG sprites and writes the Plymouth script
// that moves them with the drawing's own timing (art/boot.script.in).
//
//   python3 art/boot_scene.py <scene.html> <geo.json>
//   node art/boot-sprites.js <scene.html> <geo.json> <theme dir>
//
// Needs playwright-core and a Chrome (PLAYWRIGHT_CORE, CHROME). The sprites are
// drawn for a 2560 x 1440 screen; the script scales them to the screen. Each
// sprite's centre is its anchor: the script places it by that point.
const fs = require('fs');
const path = require('path');
const { chromium } = require(process.env.PLAYWRIGHT_CORE || 'playwright-core');

const [sceneFile, geoFile, outDir] = process.argv.slice(2);
const G = JSON.parse(fs.readFileSync(geoFile, 'utf8'));
const [W, H] = G.screen, [CX, CY] = G.center, U = G.size / 120;
const VW = 2560, VH = 1440, R = VW / W, OY = (VH - H * R) / 2;
const mk = (mx, my) => [CX + (mx - 60) * U, CY + (my - 60) * U];   // mark units -> design units

const PIECE_STEPS = 7, PIECE_DEG = 3;                       // 0, 3 ... 18 degrees
const GLINT = [0.2, 0.32, 0.45, 0.6, 0.75, 0.88, 1, 1.2, 1.45, 1.7, 2.05, 2.5, 3.1, 4.1];
const GEM = [0.12, 0.25, 0.4, 0.55, 0.7, 0.82, 0.92, 1, 1.06, 1.12];
const RAYS_FPS = 25, SHEEN_STEPS = 33, SHOCK_STEPS = 14, SPARK_SX = [0.4, 1];
const DOTS = [0.7, 1.25, 1.8];

const shots = [];   // [file, density, anchor x, anchor y] in design units
const v = n => Math.round(n * 1000) / 1000;

(async () => {
    const browser = await chromium.launch({ executablePath: process.env.CHROME });
    const pages = {};
    for (const d of [1, 0.5, 0.25, 0.125]) {
        pages[d] = await browser.newPage({ viewport: { width: VW, height: VH }, deviceScaleFactor: d });
        await pages[d].goto('file://' + path.resolve(sceneFile), { waitUntil: 'load' });
        await pages[d].evaluate(() => document.fonts.ready);
    }
    for (const f of fs.readdirSync(outDir)) if (/\.png$/.test(f) && !/^(entry|lock|bullet)\.png$/.test(f)) fs.unlinkSync(path.join(outDir, f));

    // One layer, everything else hidden, at moment t, with extra CSS; the clip
    // is a box of half-size (hw, hh) design units around the anchor (ax, ay).
    async function shot(name, layer, { t = 5, css = '', ax, ay, hw, hh = hw, density = 1, inject = '' }) {
        const p = pages[density];
        const sel = Array.isArray(layer) ? layer : [layer];
        const show = sel.map(l => `[data-l="${l}"], [data-l="${l}"] *`).join(', ');
        await p.evaluate(([css, t, inject]) => {
            document.getElementById('ov').textContent = css;
            const s = document.getElementById('s');
            s.style.setProperty('--t', t + 's'); s.style.setProperty('--ps', 'paused');
            document.querySelectorAll('[data-inject]').forEach(e => e.remove());
            if (inject) document.querySelector('#s > svg').insertAdjacentHTML('beforeend', inject);
            return new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
        }, [`[data-m] { animation: none !important; opacity: 1 !important } [data-l] { visibility: hidden !important }
            ${show} { visibility: visible !important } ${css}`, t, inject]);
        const px = ax * R, py = ay * R + OY, w = Math.ceil(hw * R), h = Math.ceil(hh * R);
        const clip = { x: Math.round(px) - w, y: Math.round(py) - h, width: 2 * w, height: 2 * h };
        await p.screenshot({ path: path.join(outDir, name + '.png'), clip, omitBackground: true });
        shots.push([name, density, v(ax + (clip.x + w - px) / R), v(ay + (clip.y + h - py) / R)]);
    }
    const still = l => `[data-l="${l}"] { animation: none !important; opacity: 1 !important }`;
    const M = 64 * U;   // half-size of the box round the mark

    // the background light and the beams: soft, so drawn at a quarter
    await shot('amb', 'amb', { css: still('amb'), ax: W / 2, ay: H / 2, hw: W / 2, hh: H / 2, density: 0.125 });
    for (let i = 0; i < 12; i++)
        await shot(`beams-${i}`, 'beams', { t: i * 5 / 360 * G.spin, css: still('beams'), ax: W / 2, ay: H / 2, hw: W / 2, hh: H / 2, density: 0.125 });
    // the still parts of the mark, shown and hidden by the script
    await shot('halo', 'halo', { css: still('halo'), ax: CX, ay: CY, hw: M, density: 0.5 });
    for (const l of ['chamber', 'ticks', 'ridge'])
        await shot(l, l, { css: still(l), ax: CX, ay: CY, hw: M });
    await shot('bloom', 'bloom', { css: still('bloom') + ' [data-l="bloom"] circle { animation: none !important; opacity: 1 !important }', ax: CX, ay: CY, hw: 40 * U, density: 0.5 });
    // the 36 ticks, lit one by one
    for (let i = 0; i < G.ticks.length; i++) {
        const [x, y] = mk(...G.ticks[i]);
        await shot(`tick-${i}`, 'lit', { css: still('lit') + ` [data-l="lit"] path { animation: none !important; opacity: 1 !important }
            [data-l="lit"] path:not(:nth-child(${i + 1})) { visibility: hidden !important }`, ax: x, ay: y, hw: 5 * U });
    }
    // the rays, frame by frame
    const nRays = Math.round((G.rays.to - G.rays.from) * RAYS_FPS) + 1;
    for (let i = 0; i < nRays; i++)
        await shot(`rays-${i}`, 'rays', { t: G.rays.from + i / RAYS_FPS, ax: CX, ay: CY, hw: 42 * U });
    // the six bezel pieces, turned in steps about their pivot
    for (let k = 0; k < 6; k++) {
        const pc = G.pieces[k], [x, y] = mk(...pc.pivot);
        for (let s = 0; s < PIECE_STEPS; s++)
            await shot(`piece${k}-${s}`, `piece${k}`, { css: `[data-l="piece${k}"] { animation: none !important; opacity: 1 !important; transform: rotate(${Math.sign(pc.rot) * s * PIECE_DEG}deg) !important }`, ax: x, ay: y, hw: 31 * U });
    }
    // a glint and the gem at their scales
    {
        const [x, y] = mk(...G.glints[0].p);
        for (let i = 0; i < GLINT.length; i++)
            await shot(`glint-${i}`, 'glint0', { css: `[data-l="glint0"] { animation: none !important; opacity: 1 !important; transform: scale(${GLINT[i]}) !important }
                [data-l="glint0"] > g { animation: none !important; opacity: 1 !important; transform: none !important }`, ax: x, ay: y, hw: (4.6 * GLINT[i] + 1) * U });
        for (let i = 0; i < GEM.length; i++)
            await shot(`gem-${i}`, 'gem', { css: `[data-l="gem"] { animation: none !important; opacity: 1 !important; transform: scale(${GEM[i]}) !important }`, ax: CX, ay: CY, hw: 26 * GEM[i] * U + 2 });
    }
    // the sheen across the bezel
    for (let i = 0; i < SHEEN_STEPS; i++)
        await shot(`sheen-${i}`, 'sheen', { css: still('sheen') + ` [data-l="sheen"] rect { animation: none !important; transform: translateX(${v(G.sweep.travel * i / (SHEEN_STEPS - 1))}px) !important }`, ax: CX, ay: CY, hw: 50 * U });
    // ignition: the flash (soft, at half), the shock waves, the flares
    await shot('flash', 'flash', { css: '[data-l="flash"] { animation: none !important; opacity: 1 !important; transform: scale(2.6) !important }', ax: CX, ay: CY, hw: 106 * U, density: 0.25 });
    for (let i = 0; i < 2; i++) {
        const top = G.shocks[i][1][1];
        for (let j = 0; j < SHOCK_STEPS; j++) {
            const sc = 1 + (top - 1) * j / (SHOCK_STEPS - 1);
            await shot(`shock${i}-${j}`, `shock${i}`, { css: `[data-l="shock${i}"] { animation: none !important; opacity: 1 !important; transform: scale(${v(sc)}) !important }`, ax: CX, ay: CY, hw: (48 * sc + 2) * U, density: 0.5 });
        }
    }
    await shot('flare0', 'flare0', { css: '[data-l="flare0"] { animation: none !important; opacity: 1 !important; transform: none !important }', ax: CX, ay: CY, hw: W * 0.43, hh: 4 });
    await shot('flare1', 'flare1', { css: '[data-l="flare1"] { animation: none !important; opacity: 1 !important; transform: none !important }', ax: CX, ay: CY, hw: W * 0.22, hh: 26, density: 0.5 });
    // the word
    await shot('word', 'word', { css: '[data-l="word"] { animation: none !important; opacity: 1 !important; transform: none !important }', ax: CX, ay: G.word.y - G.size * 0.055, hw: G.size * 0.75, hh: G.size * 0.09 });
    // the sparks, each in its direction, short and long
    for (let i = 0; i < G.sparks.length; i++) {
        const s = G.sparks[i];
        for (let j = 0; j < SPARK_SX.length; j++)
            await shot(`spark${i}-${j}`, 'sparks', { css: `[data-l="sparks"] > g:not(:nth-child(${i + 1})), [data-l="sparks"] > g:not(:nth-child(${i + 1})) * { visibility: hidden !important }
                [data-l="sparks"] rect { animation: none !important; opacity: 1 !important; transform: scaleX(${SPARK_SX[j]}) !important }`, ax: CX, ay: CY, hw: s.L * SPARK_SX[j] + 9 });
    }
    // motes, the prompt's glass field, its lock and dots, the update bar
    for (let i = 0; i < DOTS.length; i++)
        await shot(`dot-${i}`, 'dot', { ax: CX, ay: CY, hw: 3, inject: `<circle data-inject="1" data-l="dot" cx="${CX}" cy="${CY}" r="${DOTS[i]}" fill="#bfe6ff"/>` });
    const FW = 280, FH = 43, FY = G.word.y + 14;
    await shot('entry', 'ui', { ax: CX, ay: FY, hw: FW / 2 + 1, hh: FH / 2 + 1, inject: `<rect data-inject="1" data-l="ui" x="${CX - FW / 2 + .4}" y="${FY - FH / 2 + .4}" width="${FW - .8}" height="${FH - .8}" rx="12.7" fill="#0a1420" fill-opacity=".45" stroke="#bfe6ff" stroke-opacity=".28" stroke-width=".8"/>` });
    await shot('lock', 'ui', { ax: CX, ay: FY, hw: 13, inject: `<g data-inject="1" data-l="ui" transform="translate(${CX - 11.4} ${FY - 11.4}) scale(1.04)" fill="none" stroke="#cfe6f8" stroke-width="1.5"><rect x="5" y="9.75" width="12" height="8.5" rx="2"/><path d="M7.75 9.75V7.5a3.25 3.25 0 0 1 6.5 0v2.25" stroke-linecap="round"/></g>` });
    await shot('bullet', 'ui', { ax: CX, ay: FY, hw: 6, inject: `<circle data-inject="1" data-l="ui" cx="${CX}" cy="${FY}" r="4.4" fill="#e6f4fe"/>` });
    await shot('bar-back', 'ui', { ax: CX, ay: FY, hw: 115, hh: 1.5, inject: `<rect data-inject="1" data-l="ui" x="${CX - 115}" y="${FY - 1}" width="230" height="2" rx="1" fill="#ffffff" fill-opacity=".14"/>` });
    await shot('bar', 'ui', { ax: CX, ay: FY, hw: 115, hh: 1.5, inject: `<defs data-inject="1"><linearGradient id="barG"><stop offset="0" stop-color="#5aaeea"/><stop offset="1" stop-color="#bfe6ff"/></linearGradient></defs><rect data-inject="1" data-l="ui" x="${CX - 115}" y="${FY - 1}" width="230" height="2" rx="1" fill="url(#barG)"/>` });
    await browser.close();

    // the script: the drawing's numbers, then art/boot.script.in
    const L = [];
    const arr = (name, a) => a.forEach((x, i) => L.push(`${name}[${i}] = ${typeof x === 'string' ? JSON.stringify(x) : v(x)};`));
    L.push(`DW = ${W}; DH = ${H}; DCX = ${v(CX)}; DCY = ${v(CY)}; MU = ${v(U)}; RENDER = ${v(R)};`);
    shots.forEach(([n, d, x, y]) => L.push(`spr["${n}"].d = ${d}; spr["${n}"].x = ${x}; spr["${n}"].y = ${y};`));
    for (const [n, e] of Object.entries(G.ease)) L.push(`bez["${n}"][0] = ${e[0]}; bez["${n}"][1] = ${e[1]}; bez["${n}"][2] = ${e[2]}; bez["${n}"][3] = ${e[3]};`);
    for (const [n, fr] of Object.entries(G.gates)) fr.forEach((k, i) => L.push(`gate["${n}"][${i}].t = ${v(k[0])}; gate["${n}"][${i}].v = ${v(k[1])}; gate["${n}"][${i}].e = "${k[2]}";`));
    for (const [n, fr] of Object.entries(G.gates)) L.push(`gate["${n}"].n = ${fr.length};`);
    G.ticks.forEach((p, i) => L.push(`tick[${i}].x = ${v(mk(...p)[0])}; tick[${i}].y = ${v(mk(...p)[1])};`));
    L.push(`TICKS = ${G.ticks.length}; CHASE = ${G.chase.period}; TAIL = ${G.chase.tail};`);
    L.push(`BREATHE = ${G.breathe.period}; BREATHE_LOW = ${G.breathe.low}; SPIN = ${G.spin};`);
    L.push(`RAYS_FROM = ${G.rays.from}; RAYS_FPS = ${RAYS_FPS}; RAYS_N = ${nRays};`);
    G.pieces.forEach((p, k) => { const [x, y] = mk(...p.pivot); L.push(`piece[${k}].t0 = ${v(p.t0)}; piece[${k}].t1 = ${v(p.t1)}; piece[${k}].fade = ${p.fade}; piece[${k}].dx = ${v(p.dx * U)}; piece[${k}].dy = ${v(p.dy * U)}; piece[${k}].rot = ${Math.abs(p.rot)}; piece[${k}].x = ${v(x)}; piece[${k}].y = ${v(y)};`); });
    L.push(`PIECE_STEPS = ${PIECE_STEPS}; PIECE_DEG = ${PIECE_DEG};`);
    G.glints.forEach((g, k) => { const [x, y] = mk(...g.p); L.push(`glint[${k}].x = ${v(x)}; glint[${k}].y = ${v(y)}; glint[${k}].lit = ${v(g.lit)}; glint[${k}].tw = ${g.twinkle};`); });
    arr('glint_scale', GLINT); L.push(`GLINT_N = ${GLINT.length}; TWINKLE = ${G.twinkle.period};`);
    G.twinkle.keys.forEach((k, i) => L.push(`twk[${i}].p = ${k[0]}; twk[${i}].s = ${k[1]}; twk[${i}].o = ${k[2]};`));
    arr('gem_scale', GEM); L.push(`GEM_N = ${GEM.length}; GEM_FROM = ${G.gem.from}; GEM_TO = ${G.gem.to};`);
    L.push(`SWEEP = ${G.sweep.period}; SWEEP_MOVING = ${G.sweep.moving}; SHEEN_N = ${SHEEN_STEPS};`);
    G.flash.forEach((k, i) => L.push(`flash[${i}].t = ${k[0]}; flash[${i}].s = ${k[1]}; flash[${i}].o = ${k[2]}; flash[${i}].e = "${k[3]}";`));
    G.shocks.forEach((sh, i) => sh.forEach((k, j) => L.push(`shock[${i}][${j}].t = ${v(k[0])}; shock[${i}][${j}].s = ${v(k[1])}; shock[${i}][${j}].o = ${k[2]}; shock[${i}][${j}].e = "${k[3]}";`)));
    L.push(`SHOCK_N = ${SHOCK_STEPS};`);
    G.flares.forEach((fl, i) => fl.forEach((k, j) => L.push(`flare[${i}][${j}].t = ${k[0]}; flare[${i}][${j}].s = ${k[1]}; flare[${i}][${j}].o = ${k[2]}; flare[${i}][${j}].e = "${k[3]}";`)));
    L.push(`WORD_FROM = ${G.word.from}; WORD_TO = ${G.word.to}; WORD_OPACITY = ${G.word.opacity}; WORD_RISE = ${G.word.rise};`);
    G.sparks.forEach((s, i) => L.push(`spark[${i}].a = ${s.a}; spark[${i}].r0 = ${s.r0}; spark[${i}].r1 = ${s.r1}; spark[${i}].d = ${s.d}; spark[${i}].dur = ${s.dur};`));
    L.push(`SPARKS = ${G.sparks.length};`);
    G.motes.forEach((m, i) => L.push(`mote[${i}].a = ${m.a}; mote[${i}].dur = ${m.dur}; mote[${i}].d = ${m.d}; mote[${i}].r0 = ${m.r0}; mote[${i}].r1 = ${m.r1}; mote[${i}].o = ${m.o}; mote[${i}].dot = ${DOTS.reduce((b, r, j) => Math.abs(r - m.r) < Math.abs(DOTS[b] - m.r) ? j : b, 0)};`));
    L.push(`MOTES = ${G.motes.length}; FIELD_Y = ${v(FY)};`);
    const tpl = fs.readFileSync(path.join(__dirname, 'boot.script.in'), 'utf8');
    fs.writeFileSync(path.join(outDir, 'arkadeos.script'), tpl.replace('#@SPRITES@', L.join('\n')));
    console.log(`${shots.length} sprites`);
})();
