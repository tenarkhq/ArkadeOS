// Boot screen (T082, Fénycsíkok): renders the ArkadeOS wordmark's letters,
// their glows and the light streaks as PNG sprites, and writes the Plymouth
// script that moves them. Approved draft: four streaks in the Ark colours race
// through the wordmark and light the letters in their colour, the last in
// white; then a white streak runs through it until the desktop comes.
//
//   node art/boot-sprites.js <wordmark.svg> <theme dir>
//
// Needs playwright-core and a Chrome (PLAYWRIGHT_CORE, CHROME). The sprites
// are drawn for a 3840 px wide screen; the script scales them to the screen.
const fs = require('fs');
const path = require('path');
const { chromium } = require(process.env.PLAYWRIGHT_CORE || 'playwright-core');

const [svgFile, outDir] = process.argv.slice(2);
const d = fs.readFileSync(svgFile, 'utf8').match(/<path[^>]*?d="([^"]+)"/)[1];

const S = 720 / 305;  // px per wordmark unit: 720 px wide on a 3840 px screen
const COLORS = { rose: '#F43F5E', amber: '#F59E0B', green: '#22C55E', lavender: '#C9CCF2', white: '#F4F4F6' };
const MARGIN = { dim: 2, base: 10, hot: 40, streak: 18 };

function page(d, S, COLORS, MARGIN) {
    const letters = d.split(/Z\s+M/).map((p, i, a) => (i ? 'M' : '') + p + (i < a.length - 1 ? 'Z' : ''));
    const ns = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(ns, 'svg');
    document.body.appendChild(svg);
    const boxes = letters.map(l => {
        const p = document.createElementNS(ns, 'path');
        p.setAttribute('d', l); svg.appendChild(p);
        const b = p.getBBox(); return { x: b.x, y: b.y, w: b.width, h: b.height };
    });
    const out = {};
    const sprite = (name, w, h, draw) => {
        const c = document.createElement('canvas');
        c.width = Math.ceil(w * S); c.height = Math.ceil(h * S);
        const x = c.getContext('2d'); x.scale(S, S); draw(x);
        out[name] = c.toDataURL('image/png');
    };
    letters.forEach((l, i) => {
        const b = boxes[i], p = new Path2D(l);
        for (const [kind, m] of [['dim', MARGIN.dim], ['base', MARGIN.base], ['hot', MARGIN.hot]]) {
            const cols = kind === 'dim' ? { white: COLORS.white } : COLORS;
            for (const [cn, col] of Object.entries(cols)) {
                sprite(kind === 'dim' ? `dim-${i}` : `${kind}-${i}-${cn}`, b.w + 2 * m, b.h + 2 * m, x => {
                    x.translate(m - b.x, m - b.y);
                    x.fillStyle = col;
                    if (kind !== 'dim') {
                        x.shadowColor = cn === 'white' ? COLORS.rose : col;
                        x.shadowBlur = (kind === 'base' ? 6 : 32) * S;
                    }
                    x.fill(p);
                    if (kind === 'hot') x.fill(p);
                });
            }
        }
    });
    // A streak: a 140-unit tail fading in, a white head at its right end.
    const streak = (name, col, len, thick) => sprite(name, len + 6 + 2 * MARGIN.streak, thick + 1 + 2 * MARGIN.streak, x => {
        x.translate(MARGIN.streak, MARGIN.streak);
        const g = x.createLinearGradient(0, 0, len, 0);
        g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, col);
        x.shadowColor = col; x.shadowBlur = 14 * S;
        x.fillStyle = g; x.fillRect(0, .3, len, thick);
        x.fillStyle = '#fff'; x.fillRect(len - 6, 0, 6, thick + .6);
    });
    Object.entries(COLORS).forEach(([cn, col]) => streak(`streak-${cn}`, col, 140, 2.2));
    streak('chase', '#ffffff', 110, 1.6);
    // The update progress bar: stretched by the script.
    for (const [name, col] of [['bar-back', '#2A2A30'], ['bar', '#F4F4F6']]) {
        const c = document.createElement('canvas'); c.width = c.height = 4;
        const x = c.getContext('2d'); x.fillStyle = col; x.fillRect(0, 0, 4, 4);
        out[name] = c.toDataURL('image/png');
    }
    return { out, boxes };
}

(async () => {
    const browser = await chromium.launch({ executablePath: process.env.CHROME });
    const p = await browser.newPage();
    const args = [d, S, COLORS, MARGIN].map(v => JSON.stringify(v)).join(', ');
    const { out, boxes } = await p.evaluate(`(${page})(${args})`);
    await browser.close();
    for (const f of fs.readdirSync(outDir)) if (/^(dim|base|hot|streak|chase|bar)[-.]/.test(f)) fs.unlinkSync(path.join(outDir, f));
    for (const [name, url] of Object.entries(out))
        fs.writeFileSync(path.join(outDir, `${name}.png`), Buffer.from(url.split(',')[1], 'base64'));
    const tpl = fs.readFileSync(path.join(__dirname, 'boot.script.in'), 'utf8');
    const num = v => v.toFixed(3);
    const data = [
        `S4K = ${num(S)};`,
        ...boxes.map((b, i) => `box[${i}].x = ${num(b.x)}; box[${i}].y = ${num(b.y)};`),
        `margin.dim = ${MARGIN.dim}; margin.base = ${MARGIN.base}; margin.hot = ${MARGIN.hot}; margin.streak = ${MARGIN.streak};`,
    ].join('\n');
    fs.writeFileSync(path.join(outDir, 'arkadeos.script'), tpl.replace('#@SPRITES@', data));
    console.log(`${Object.keys(out).length} sprites, ${boxes.length} letters`);
})();
