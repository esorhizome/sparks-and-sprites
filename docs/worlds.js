/* Sparks & Sprites — the world workshop.
   Thirteen generators — the arithmetic that makes places: points that keep
   their distance, caves grown from noise, rooms carved by halving, mazes
   with two personalities, tiles chosen by their neighbours' rules, tiles
   picked by a bitmask, regions by nearest seed, a side-view terrain from
   layered noise, trees from a rewrite rule, loot from weighted dice, waves
   from a director's curve, a world folded into a save, and one seed that
   reproduces everything. The eighth gallery, and the first one about the
   WORLD rather than the things in it. Every card hides a RHYME (the same
   generator with two or three dials turned), so the page holds 26 worlds.

   Every demo is one function make(u) that returns { frame(dt, t), press(x, y) }
   — plus drag: true when press is continuous. Its dials sit at the top in
   a D = { … } object; a rhyme is that object with a few values swapped.
   The kit u is the lexicon's kit (the night stage, the mote, the drawing
   pocket tools, rand / rng / noise) plus the world tools:
     noise2(x, y)  — smooth 2-D value noise in −1..1
     cells(cols, rows, fill?) — a grid { cols, rows, a: Float32Array }, get(x,y) /
                     set(x,y,v) with out-of-range reads returning fill (default 0)
     drawCells(g, x0, y0, cw, ch, colourOf) — paint a grid: colourOf(v, x, y)
                     returns a colour string or null (skip)
     mix(a, b, k), rgba(c, a), shade(c, k), hsl(h, s, l, a) — colour helpers
     shuffle(arr, r?) — Fisher–Yates in place (r = a seeded rng function)
     beep(freq, dur, type) — a courtesy tone, only ever after a press
     mote(x, y, ang) — the lexicon's protagonist, for scale and for walking the worlds

   Nothing animates until the visitor presses Run (or clicks a card awake),
   and every card rests after 60 seconds as a courtesy. */
(function () {
"use strict";
var TAU = Math.PI * 2;

var EFFECTS = [];
function def(letter, name, tag, hint, make) {
  EFFECTS.push({ letter: letter, name: name, tag: tag, hint: hint, make: make });
}

/* A RHYME is the same motion with two or three dials turned — a speed, a
   count, a stiffness, a palette — and nothing else. Every card keeps its
   dials in a  D = { … }  object at the top of make(u); the rhyme is a
   short object naming only the values that move. The runtime rebuilds the
   card's source with those values swapped in (see rhymeSource), so the
   editor shows the pair as a literal diff, and Godot does the same thing
   as a dictionary merge on right-click. Understanding one recipe buys the
   whole neighbourhood. */
function rhymeOf(orig, name, hint, dials) {
  for (var i = 0; i < EFFECTS.length; i++)
    if (EFFECTS[i].name === orig) {
      EFFECTS[i].rhyme = { name: name, hint: hint, dials: dials, orig: EFFECTS[i] };
      return;
    }
  throw new Error("rhymeOf: no card named " + orig);
}

/* Rewrite a card's source so its D = { … } literal is wrapped in
   Object.assign(…, { the moved dials }). Braces inside strings and //
   comments are skipped; the D literal itself must be plain data. */
function rhymeSource(src, dials) {
  var m = src.match(/(\b(?:var|const|let)\s+D\s*=\s*)\{/);
  if (!m) throw new Error("rhymeSource: no  D = { … }  block found");
  var start = m.index + m[0].length - 1, depth = 0, i = start, q = null;
  for (; i < src.length; i++) {
    var ch = src[i];
    if (q) { if (ch === "\\") i++; else if (ch === q) q = null; continue; }
    if (ch === "/" && src[i + 1] === "/") { i = src.indexOf("\n", i); if (i < 0) i = src.length; continue; }
    if (ch === '"' || ch === "'" || ch === "`") { q = ch; continue; }
    if (ch === "{") depth++;
    else if (ch === "}") { depth--; if (depth === 0) break; }
  }
  var keys = Object.keys(dials), moved = [];
  for (var k = 0; k < keys.length; k++) moved.push(keys[k] + ": " + JSON.stringify(dials[keys[k]]));
  return src.slice(0, m.index) + m[1] + "Object.assign(" + src.slice(start, i + 1) +
         ", {   // the rhyme: only these dials moved\n    " + moved.join(",\n    ") + "\n  })" + src.slice(i + 1);
}

function makeOf(v) {                                    // a variant's make(), built lazily for rhymes
  if (v.make) return v.make;
  var src = rhymeSource(v.orig.make.toString(), v.dials);
  v.source = src;
  v.make = new Function("return (" + src + "\n)")();
  return v.make;
}
function sourceOf(v) {
  if (v.source) return v.source;
  if (v.make && !v.orig) return v.make.toString();
  makeOf(v);
  return v.source;
}
function variantOf(st) {
  return (st.useRhyme && st.effect.rhyme) ? st.effect.rhyme : st.effect;
}

function apiFor(canvas) {
  var dpr = window.devicePixelRatio || 1;
  var W = canvas.clientWidth, H = canvas.clientHeight;
  canvas.width = Math.round(W * dpr);
  canvas.height = Math.round(H * dpr);
  var ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  var GY = H * 0.78;
  var INK = "#E8E5F4";
  var DIM = "rgba(232,229,244,0.25)";
  var MOVER = "#8AD9F5";
  var TARGET = "#F5C169";
  var BONE = "#C9C4E4";
  var GOOD = "#9BE28A";
  var HOT = "#F58A8A";
  var MAGIC = "#C9A0F5";
  function rand(a, b) { return a + Math.random() * (b - a); }
  function rng(seed) {                                 // mulberry32 — tiny, seeded,
    var s = seed >>> 0;                                // identical on every machine
    return function () {
      s = (s + 0x6D2B79F5) >>> 0;
      var z = s;
      z = Math.imul(z ^ (z >>> 15), z | 1);
      z ^= z + Math.imul(z ^ (z >>> 7), z | 61);
      return ((z ^ (z >>> 14)) >>> 0) / 4294967296;
    };
  }
  function hash(i) { var s = Math.sin(i * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s); }
  function noise(x) {                                  // value noise: random heights at the
    var i = Math.floor(x), f = x - i, k = f * f * (3 - 2 * f);   // integers, smoothstepped between
    return (hash(i) + (hash(i + 1) - hash(i)) * k) * 2 - 1;
  }
  function len(x, y) { return Math.sqrt(x * x + y * y); }
  function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
  function lerp(a, b, k) { return a + (b - a) * k; }
  function ease(k) { k = clamp(k, 0, 1); return k * k * (3 - 2 * k); }
  function smooth(rate, dt) { return 1 - Math.exp(-rate * dt); }
  function wrapAngle(a) {
    while (a > Math.PI) a -= TAU;
    while (a < -Math.PI) a += TAU;
    return a;
  }
  function stage() {
    var g = ctx.createLinearGradient(0, 0, 0, H);      // the night backdrop
    g.addColorStop(0, "#1A1532");
    g.addColorStop(1, "#131020");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    ctx.strokeStyle = "rgba(150,145,190,0.07)";        // faint graph paper —
    ctx.lineWidth = 1;                                 // this page is a maths page
    ctx.beginPath();
    for (var x = 26; x < W; x += 26) { ctx.moveTo(x, 0); ctx.lineTo(x, H); }
    for (var y = 26; y < H; y += 26) { ctx.moveTo(0, y); ctx.lineTo(W, y); }
    ctx.stroke();
  }
  function ground(gy) {
    gy = gy === undefined ? GY : gy;
    ctx.strokeStyle = "rgba(201,196,228,0.5)";
    ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(W, gy); ctx.stroke();
    ctx.strokeStyle = "rgba(201,196,228,0.16)";        // the hatching that says "solid"
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (var x = 4; x < W; x += 12) { ctx.moveTo(x, gy + 2); ctx.lineTo(x - 5, gy + 8); }
    ctx.stroke();
  }
  function dot(x, y, r, c) {
    ctx.fillStyle = c || INK;
    ctx.beginPath(); ctx.arc(x, y, Math.max(0.1, r), 0, TAU); ctx.fill();
  }
  function ring(x, y, r, c, w) {
    ctx.strokeStyle = c || DIM;
    ctx.lineWidth = w || 1;
    ctx.beginPath(); ctx.arc(x, y, Math.max(0.5, r), 0, TAU); ctx.stroke();
  }
  function line(x1, y1, x2, y2, c, w) {
    ctx.strokeStyle = c || INK;
    ctx.lineWidth = w || 1;
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  }
  function rect(x, y, w, h, c) {
    ctx.fillStyle = c || INK;
    ctx.fillRect(x, y, w, h);
  }
  function poly(pts, c, stroke) {
    if (!pts.length) return;
    ctx.beginPath();
    ctx.moveTo(pts[0][0], pts[0][1]);
    for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
    ctx.closePath();
    if (stroke) { ctx.strokeStyle = c || INK; ctx.lineWidth = stroke === true ? 1 : stroke; ctx.stroke(); }
    else { ctx.fillStyle = c || INK; ctx.fill(); }
  }
  function arrow(x1, y1, x2, y2, c) {
    var dx = x2 - x1, dy = y2 - y1, d = len(dx, dy);
    ctx.strokeStyle = c || INK;
    ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
    if (d < 3) return;                                 // too short to deserve a head
    var hx = dx / d, hy = dy / d, s = Math.min(6, d * 0.4);
    ctx.beginPath();
    ctx.moveTo(x2, y2);
    ctx.lineTo(x2 - hx * s - hy * s * 0.55, y2 - hy * s + hx * s * 0.55);
    ctx.lineTo(x2 - hx * s + hy * s * 0.55, y2 - hy * s - hx * s * 0.55);
    ctx.closePath();
    ctx.fillStyle = c || INK;
    ctx.fill();
  }
  function mote(x, y, ang, c, s) {
    s = s || 8;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(ang || 0);
    ctx.fillStyle = c || MOVER;
    ctx.beginPath(); ctx.arc(0, 0, s, 0, TAU); ctx.fill();
    ctx.beginPath();                                   // the nose — heading made visible
    ctx.moveTo(s * 0.45, -s * 0.6);
    ctx.lineTo(s * 1.5, 0);
    ctx.lineTo(s * 0.45, s * 0.6);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = "#131020";                         // one attentive eye
    ctx.beginPath(); ctx.arc(s * 0.38, -s * 0.3, s * 0.22, 0, TAU); ctx.fill();
    ctx.restore();
  }
  function beep(freq, dur, type) {                     // one WebAudio voice, made on first use
    var AC = window.AudioContext || window.webkitAudioContext;
    if (!AC || !(freq > 0)) return;
    try {
      if (!apiFor.ac) apiFor.ac = new AC();
      var ac = apiFor.ac;
      if (ac.state === "suspended") ac.resume();
      var o = ac.createOscillator(), g = ac.createGain(), t0 = ac.currentTime;
      o.type = type || "triangle";
      o.frequency.setValueAtTime(freq, t0);
      g.gain.setValueAtTime(0.0001, t0);
      g.gain.exponentialRampToValueAtTime(0.12, t0 + 0.008);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + (dur || 0.12));
      o.connect(g).connect(ac.destination);
      o.start(t0); o.stop(t0 + (dur || 0.12) + 0.02);
    } catch (e) { /* audio is a courtesy, never a requirement */ }
  }
  function hash2(i, j) { var s = Math.sin(i * 127.1 + j * 269.5 + 311.7) * 43758.5453; return s - Math.floor(s); }
  function noise2(x, y) {                              // value noise on a grid of corners
    var i = Math.floor(x), j = Math.floor(y), fx = x - i, fy = y - j;
    var kx = fx * fx * (3 - 2 * fx), ky = fy * fy * (3 - 2 * fy);
    var a = hash2(i, j), b = hash2(i + 1, j), c = hash2(i, j + 1), d = hash2(i + 1, j + 1);
    var top = a + (b - a) * kx, bot = c + (d - c) * kx;
    return (top + (bot - top) * ky) * 2 - 1;
  }
  function cells(cols, rows, fill) {
    var g = { cols: cols, rows: rows, fill: fill || 0, a: new Float32Array(cols * rows) };
    if (fill) g.a.fill(fill);
    g.get = function (x, y) { return (x < 0 || y < 0 || x >= cols || y >= rows) ? g.fill : g.a[y * cols + x]; };
    g.set = function (x, y, v) { if (x >= 0 && y >= 0 && x < cols && y < rows) g.a[y * cols + x] = v; };
    return g;
  }
  function drawCells(g, x0, y0, cw, ch, colourOf) {
    for (var y = 0; y < g.rows; y++) for (var x = 0; x < g.cols; x++) {
      var c = colourOf(g.a[y * g.cols + x], x, y);
      if (c) { ctx.fillStyle = c; ctx.fillRect(x0 + x * cw, y0 + y * ch, cw + 0.5, ch + 0.5); }
    }
  }
  var colCache = {};
  function col(c) {
    if (Array.isArray(c)) return c;
    if (colCache[c]) return colCache[c];
    var out = [0, 0, 0, 1], m;
    if (c[0] === "#") {
      var h = c.slice(1);
      if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
      out = [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16), 1];
    } else if ((m = c.match(/rgba?\(([^)]+)\)/))) {
      var p = m[1].split(",").map(parseFloat);
      out = [p[0], p[1], p[2], p.length > 3 ? p[3] : 1];
    }
    colCache[c] = out;
    return out;
  }
  function rgba(c, a) { var v = col(c); return "rgba(" + Math.round(v[0]) + "," + Math.round(v[1]) + "," + Math.round(v[2]) + "," + (a === undefined ? v[3] : a) + ")"; }
  function mix(a, b, k) {
    var p = col(a), q = col(b); k = clamp(k, 0, 1);
    return "rgba(" + Math.round(p[0] + (q[0] - p[0]) * k) + "," + Math.round(p[1] + (q[1] - p[1]) * k) + "," + Math.round(p[2] + (q[2] - p[2]) * k) + "," + (p[3] + (q[3] - p[3]) * k) + ")";
  }
  function shade(c, k) { return k >= 0 ? mix(c, "#FFFFFF", k) : mix(c, "#000000", -k); }
  function hsl(h, s, l, a) { return "hsla(" + h + "," + Math.round(s * 100) + "%," + Math.round(l * 100) + "%," + (a === undefined ? 1 : a) + ")"; }
  function shuffle(arr, r) {
    r = r || Math.random;
    for (var i = arr.length - 1; i > 0; i--) { var j = Math.floor(r() * (i + 1)); var tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp; }
    return arr;
  }
  function label(txt, x, y, c, align) {
    ctx.fillStyle = c || "rgba(232,229,244,0.55)";
    ctx.font = "10px system-ui, sans-serif";
    ctx.textAlign = align || "left";
    ctx.fillText(txt, x, y);
    ctx.textAlign = "left";
  }
  return { ctx: ctx, W: W, H: H, GY: GY, TAU: TAU,
           INK: INK, DIM: DIM, MOVER: MOVER, TARGET: TARGET, BONE: BONE, GOOD: GOOD, HOT: HOT, MAGIC: MAGIC,
           rand: rand, rng: rng, noise: noise, len: len, clamp: clamp, lerp: lerp, ease: ease,
           smooth: smooth, wrapAngle: wrapAngle, beep: beep, noise2: noise2, cells: cells, drawCells: drawCells,
           col: col, rgba: rgba, mix: mix, shade: shade, hsl: hsl, shuffle: shuffle,
           stage: stage, ground: ground, dot: dot, ring: ring, line: line, rect: rect, poly: poly,
           arrow: arrow, mote: mote, label: label };
}

var FAMILY_ORDER = [
  ["scatter", "Scatter & noise", "places from randomness with rules — points that keep their distance, a ground line from layered noise, regions by nearest seed, trees from a rewrite rule"],
  ["rooms", "Rooms, caves & mazes", "places from grids — caves grown by a neighbour rule, rooms carved by halving, mazes with two personalities, tiles chosen by constraint, tiles picked by a bitmask"],
  ["dice", "Dice, waves & saves", "the arithmetic around the world — weighted loot and fair bags, a director's spawn curve, the world folded into a save, and one seed for everything"]
];

/* ───────────────────────── SCATTER & NOISE ─────────────────────────
   Places from randomness with rules. A plain random() clumps; every
   generator here adds one rule to it — keep your distance, add the
   octaves, take the nearest seed, rewrite the string — and a place
   appears. Four cards: Poisson, Terrain, Voronoi, Lsystem. Each one
   is seeded, so the world you see is the world everyone sees. */

def("P", "Poisson", "scatter", "random points that keep a minimum distance r (bridson's grid + active list) — next to a plain scatter that clumps — drag to set r", function (u) {
  var D = { r: 0.085,            // the minimum distance, as a fraction of W
            k: 12,               // candidates thrown around an active point before it retires
            perBeat: 3,          // active points tried per beat
            beat: 0.04,          // seconds per beat
            rest: 2.2,           // seconds to admire it before the next seed
            rMin: 0.02, rMax: 0.22,   // what a drag may set r to
            seed: 3,
            label: "every pair ≥ r apart · grid cell = r/√2 · k = 12 tries" };
  const { ctx, W, H, TAU, stage, dot, ring, line, rect, label, rng, len, clamp, MOVER, TARGET, HOT, GOOD, BONE, DIM } = u;
  // POISSON-DISC scattering. a plain random() puts trees on top of trees;
  // bridson's trick keeps every pair at least r apart and stays fast: a
  // grid of cells r/√2 wide holds at most ONE point each, so "is anything
  // within r?" is a look at the 5×5 cells around you. an ACTIVE list holds
  // points that may still have room beside them; pick one, throw k
  // candidates into the ring r..2r around it, keep the first that fits,
  // and retire the point when all k miss. the strip on the right is the
  // same count of points with no rule — the ch04 starfield, clumps and all.
  const mw = Math.floor(W * 0.7), mh = H - 20, sx = mw + 8, sw = W - sx - 2;
  let rFrac = D.r, seed = D.seed;
  let r, cell, gw, gh, grid, px, py, n, act, nAct, naive, nClose, close;
  let r1, r2, tried, last, lastAdd, flash, acc, restT, done;
  function reset() {
    r = clamp(rFrac, D.rMin, D.rMax) * W;
    cell = r / Math.SQRT2;
    gw = Math.max(1, Math.ceil(mw / cell)); gh = Math.max(1, Math.ceil(mh / cell));
    grid = new Int32Array(gw * gh).fill(-1);
    px = new Float32Array(gw * gh); py = new Float32Array(gw * gh);
    act = new Int32Array(gw * gh); n = 0; nAct = 0;
    naive = new Float32Array(gw * gh * 2); nClose = 0; close = [];
    r1 = rng(seed); r2 = rng(seed + 99);
    tried = []; last = -1; lastAdd = -1; flash = 0; acc = 0; restT = 0; done = false;
    add(r1() * mw, r1() * mh);                         // the first point: anywhere
  }
  function fits(x, y) {
    const gx = Math.floor(x / cell), gy = Math.floor(y / cell);
    for (let j = Math.max(0, gy - 2); j <= Math.min(gh - 1, gy + 2); j++)
      for (let i = Math.max(0, gx - 2); i <= Math.min(gw - 1, gx + 2); i++) {
        const p = grid[j * gw + i];
        if (p >= 0 && len(px[p] - x, py[p] - y) < r) return false;
      }
    return true;
  }
  function add(x, y) {
    if (n >= px.length) return -1;
    const gx = clamp(Math.floor(x / cell), 0, gw - 1), gy = clamp(Math.floor(y / cell), 0, gh - 1);
    if (grid[gy * gw + gx] >= 0) return -1;            // one point per cell, always
    px[n] = x; py[n] = y; grid[gy * gw + gx] = n; act[nAct++] = n;
    const nx = r2() * sw, ny = r2() * mh;              // the naive twin: one uniform point
    for (let i = 0; i < n; i++)                        // count its clumps — pairs closer than r
      if (len(naive[i * 2] - nx, naive[i * 2 + 1] - ny) < r) { nClose++; if (close.length < 400) close.push(i, n); }
    naive[n * 2] = nx; naive[n * 2 + 1] = ny;
    lastAdd = n; flash = 1;
    return n++;
  }
  function step() {
    if (nAct === 0) { done = true; return; }
    const ai = Math.floor(r1() * nAct), p = act[ai];
    last = p; tried.length = 0;
    let found = false;
    for (let j = 0; j < D.k; j++) {
      const a = r1() * TAU, d = r * (1 + r1());        // the ring r..2r around the active point
      const x = px[p] + Math.cos(a) * d, y = py[p] + Math.sin(a) * d;
      if (x >= 0 && y >= 0 && x < mw && y < mh && fits(x, y)) { add(x, y); found = true; break; }
      tried.push(x, y);
    }
    if (!found) { act[ai] = act[--nAct]; if (nAct === 0) done = true; }   // all k missed: retire it
  }
  reset();
  return {
    drag: true,
    press(x, y) {
      rFrac = clamp(len(x - mw / 2, y - mh / 2) / W, D.rMin, D.rMax);   // r = how far you are from the centre
      reset();
    },
    frame(dt, t) {
      stage();
      flash = Math.max(0, flash - dt * 4);
      if (!done) {
        acc += dt;
        let guard = 0;
        while (acc >= D.beat && guard++ < 12) { acc -= D.beat; for (let i = 0; i < D.perBeat && !done; i++) step(); }
      } else if ((restT += dt) > D.rest) { seed++; reset(); }
      ctx.strokeStyle = "rgba(150,145,190,0.12)";      // bridson's grid: one point per cell at most
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let i = 1; i < gw; i++) { ctx.moveTo(i * cell, 0); ctx.lineTo(i * cell, mh); }
      for (let j = 1; j < gh; j++) { ctx.moveTo(0, j * cell); ctx.lineTo(mw, j * cell); }
      ctx.stroke();
      line(mw + 4, 0, mw + 4, mh, "rgba(201,196,228,0.2)");
      const pr = Math.max(1.2, r * 0.11);
      for (let i = 0; i < n; i++) dot(px[i], py[i], pr, BONE);
      for (let i = 0; i < nAct; i++) dot(px[act[i]], py[act[i]], pr, MOVER);      // still active: may have room
      if (!done && last >= 0) {
        ring(px[last], py[last], r, TARGET, 1.2);       // nothing may land inside r …
        ring(px[last], py[last], 2 * r, DIM, 1);        // … candidates are thrown out to 2r
        for (let i = 0; i < tried.length; i += 2) ring(tried[i], tried[i + 1], pr + 1, HOT, 1);
        label("r", px[last] + r * 0.7 + 2, py[last] - 3, TARGET);
      }
      if (lastAdd >= 0 && flash > 0) ring(px[lastAdd], py[lastAdd], pr + 2 + (1 - flash) * 6, GOOD, 1.5);
      for (let i = 0; i < n; i++) dot(sx + naive[i * 2], naive[i * 2 + 1], pr, BONE);   // the naive strip
      for (let i = 0; i + 1 < close.length; i += 2)
        line(sx + naive[close[i] * 2], naive[close[i] * 2 + 1], sx + naive[close[i + 1] * 2], naive[close[i + 1] * 2 + 1], HOT, 1);
      label("poisson · " + n + " points · " + nAct + " active", 4, 11, null);
      label("naive · " + nClose + " too close", W - 4, 11, HOT, "right");
      label(D.label + " · r = " + Math.round(r) + "px", W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Poisson", "Pinprick", "a tiny r and a faster hand — hundreds of points, evenly strewn: a star field with no clumps", { r: 0.022, perBeat: 14 });

def("T", "Terrain", "scatter", "a side-view ground from layered 1-d noise — octaves at doubling frequency and halving amplitude, biomes by height — press to reroll", function (u) {
  var D = { octaves: 5,          // noise layers, added one per beat
            persistence: 0.5,    // each octave's amplitude, as a fraction of the last
            scale: 2.6,          // cycles of the first octave across the width
            height: 0.5,         // the terrain's full range, as a fraction of H
            sea: 0.4, sand: 0.47, grass: 0.66, rock: 0.82,   // biome bands, in 0..1 of the range
            beat: 0.7,           // seconds between octaves
            rest: 2.4,           // seconds to rest on the finished ground
            walk: 0.09,          // the mote's pace, in widths per second
            seed: 11,
            palette: "temperate",
            palettes: { temperate: ["#3A6FB5", "#E2C98A", "#6FAF5E", "#8C8698", "#F0F2FA"], snow: ["#4A6E9C", "#B9C4D6", "#DCE6F2", "#9AA3B8", "#FFFFFF"] },
            label: "h(x) = Σ noise(x·2ⁱ) · ½ⁱ · biome by height band" };
  const { ctx, W, H, stage, line, rect, mote, label, rng, noise, clamp, rgba, DIM, BONE } = u;
  // 1-D NOISE TERRAIN. one octave of smooth noise is a rolling hill; add a
  // second at twice the frequency and half the amplitude and the hill
  // grows bumps; a third adds pebbles. that sum is LAYERED (fractal) noise,
  // and the ½ⁱ is the persistence — the depth atlas's Knoll had one layer,
  // this ground has five. the height then picks the BIOME: below the sea
  // line is water, a thin band above it sand, then grass, rock, snow. the
  // seed only shifts where each octave is read from, so the same seed is
  // the same coastline on every machine.
  const base = H - 22, top = 14, cols = Math.ceil(W / 2) + 1;
  const h = new Float32Array(cols), pal = D.palettes[D.palette] || D.palettes.temperate;
  let seed = D.seed, off = [], shown = 1, acc = 0, restT = 0, wx = 0;
  function reroll() { const r = rng(seed); off = []; for (let o = 0; o < D.octaves; o++) off.push(r() * 1000); shown = 1; acc = 0; restT = 0; build(); }
  function build() {                                   // the sum of the octaves shown so far
    let norm = 0, amp = 1;
    for (let o = 0; o < shown; o++) { norm += amp; amp *= D.persistence; }
    for (let i = 0; i < cols; i++) {
      let v = 0; amp = 1;
      for (let o = 0; o < shown; o++) { v += noise((i * 2 / W) * D.scale * (1 << o) + off[o]) * amp; amp *= D.persistence; }
      h[i] = clamp(0.5 + 0.5 * v / Math.max(1e-6, norm), 0, 1);
    }
  }
  const yOf = (hn) => base - hn * H * D.height;
  function biome(hn) { return hn < D.sea ? 0 : hn < D.sand ? 1 : hn < D.grass ? 2 : hn < D.rock ? 3 : 4; }
  reroll();
  return {
    press() { seed++; reroll(); },
    frame(dt, t) {
      stage();
      if (shown < D.octaves) { if ((acc += dt) >= D.beat) { acc = 0; shown++; build(); } }
      else if ((restT += dt) > D.rest) { seed++; reroll(); }
      const yw = yOf(D.sea);
      for (let i = 0; i < cols - 1; i++) {             // the ground, coloured by band
        const y = yOf(h[i]);
        rect(i * 2, y, 2.5, base - y, pal[biome(h[i])]);
      }
      rect(0, yw, W, base - yw, rgba(pal[0], 0.45));    // the sea fills every dip below the line
      line(0, yw, W, yw, rgba(pal[0], 0.9), 1);
      let amp = 1;                                     // the octaves, faintly, under the sum
      for (let o = 0; o < D.octaves; o++) {
        const mid = yOf(0.5), on = o < shown;
        ctx.strokeStyle = on ? "rgba(232,229,244,0.22)" : "rgba(232,229,244,0.06)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let i = 0; i < cols; i++) {
          const y = mid - noise((i * 2 / W) * D.scale * (1 << o) + off[o]) * amp * H * D.height * 0.5;
          if (i === 0) ctx.moveTo(0, y); else ctx.lineTo(i * 2, y);
        }
        ctx.stroke();
        label("×" + (o === 0 ? "1" : "½" + (o > 1 ? "^" + o : "")), W - 4, top + 10 + o * 11, on ? BONE : DIM, "right");
        amp *= D.persistence;
      }
      wx = (wx + dt * D.walk * W) % W;                 // the mote walks the ground it is given
      const i = clamp(Math.floor(wx / 2), 1, cols - 2);
      const gy = Math.min(yOf(h[i]), yw), ang = Math.atan2(yOf(h[i + 1]) - yOf(h[i - 1]), 4);
      mote(wx, gy - 7, h[i] < D.sea ? 0 : ang);
      label("octaves " + shown + " / " + D.octaves + " · persistence " + D.persistence, 4, 11);
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Terrain", "Tundra", "three octaves, half the range and a snow palette — a flat white plain with a low grey sea", { octaves: 3, height: 0.3, palette: "snow" });

def("V", "Voronoi", "scatter", "every cell takes the colour of its nearest seed — biomes, territories, shattered glass — press to add a seed where you click", function (u) {
  var D = { cols: 56, rows: 36,       // the grid
            seeds: 9,                 // seeds to start with
            metric: "euclid",         // "euclid" or "manhattan" — the meaning of nearest
            drift: 1.4,               // seed speed, in cells per second, once the sweep is done
            rowsPerBeat: 2, beat: 0.03,   // the sweep that assigns rows
            rest: 3.2,                // seconds of drifting before the next seed
            maxSeeds: 40,
            seed: 5,
            palette: "biome",         // "biome" or "glass"
            label: "each cell → its nearest seed" };
  const { ctx, W, H, stage, dot, line, ring, drawCells, cells, label, rng, hsl, clamp, INK, TARGET, DIM } = u;
  // VORONOI regions. drop N seeds; every point in the plane belongs to the
  // seed it is NEAREST to, and the plane shatters into N cells with straight
  // shared edges. on a grid it is nothing but a loop: for every cell, find
  // the closest seed. change what "closest" means — the almanac's shatter
  // used √(dx² + dy²); |dx| + |dy| (manhattan) gives diamond cells with
  // 45° edges — and the same seeds draw a different country. the sweep
  // line is the loop doing its work, row by row.
  const gw = W, gh = H - 18, cw = gw / D.cols, ch = gh / D.rows;
  const g = cells(D.cols, D.rows); g.a.fill(-1);
  let seed = D.seed, S = [], row = 0, acc = 0, restT = 0;
  function colourOf(i, r) {
    if (D.palette === "glass") return hsl(185 + r() * 40, 0.35, 0.45 + r() * 0.35);
    const hues = [205, 95, 42, 130, 28, 170, 80];     // sea, grass, sand, forest, clay, marsh, meadow
    return hsl(hues[i % hues.length] + (r() - 0.5) * 16, 0.45, 0.3 + r() * 0.16);
  }
  function plant() {
    const r = rng(seed); S = [];
    for (let i = 0; i < D.seeds; i++) S.push({ x: r() * D.cols, y: r() * D.rows, vx: (r() - 0.5) * 2, vy: (r() - 0.5) * 2, c: colourOf(i, r) });
    row = 0; acc = 0; restT = 0;
  }
  function dist(s, x, y) {
    const dx = Math.abs(x + 0.5 - s.x), dy = Math.abs(y + 0.5 - s.y);
    return D.metric === "manhattan" ? dx + dy : Math.sqrt(dx * dx + dy * dy);
  }
  function nearest(x, y) {
    let bi = 0, bd = Infinity;
    for (let i = 0; i < S.length; i++) { const d = dist(S[i], x, y); if (d < bd) { bd = d; bi = i; } }
    return bi;
  }
  function assignRow(y) { for (let x = 0; x < D.cols; x++) g.set(x, y, nearest(x, y)); }
  plant();
  return {
    press(x, y) {
      if (S.length >= D.maxSeeds) S.shift();
      S.push({ x: clamp(x / cw, 0, D.cols), y: clamp(y / ch, 0, D.rows), vx: 0, vy: 0, c: colourOf(S.length, rng(seed + S.length)) });
      row = 0; acc = 0;                                // sweep again, with the new seed in the running
    },
    frame(dt, t) {
      stage();
      if (row < D.rows) {
        acc += dt;
        let guard = 0;
        while (acc >= D.beat && row < D.rows && guard++ < 20) { acc -= D.beat; for (let k = 0; k < D.rowsPerBeat && row < D.rows; k++) assignRow(row++); }
      } else {
        for (const s of S) {                           // the seeds drift and the borders follow
          s.x += s.vx * D.drift * dt; s.y += s.vy * D.drift * dt;
          if (s.x < 0 || s.x > D.cols) s.vx = -s.vx; if (s.y < 0 || s.y > D.rows) s.vy = -s.vy;
          s.x = clamp(s.x, 0, D.cols); s.y = clamp(s.y, 0, D.rows);
        }
        for (let y = 0; y < D.rows; y++) assignRow(y);
        if ((restT += dt) > D.rest) { seed++; plant(); g.a.fill(-1); }
      }
      drawCells(g, 0, 0, cw, ch, (v) => v < 0 ? null : S[v].c);
      ctx.strokeStyle = "rgba(19,16,32,0.55)";         // the shared edges: where the owner changes
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let y = 0; y < D.rows; y++) for (let x = 0; x < D.cols; x++) {
        const v = g.get(x, y); if (v < 0) continue;
        if (x + 1 < D.cols && g.get(x + 1, y) !== v && g.get(x + 1, y) >= 0) { ctx.moveTo((x + 1) * cw, y * ch); ctx.lineTo((x + 1) * cw, (y + 1) * ch); }
        if (y + 1 < D.rows && g.get(x, y + 1) !== v && g.get(x, y + 1) >= 0) { ctx.moveTo(x * cw, (y + 1) * ch); ctx.lineTo((x + 1) * cw, (y + 1) * ch); }
      }
      ctx.stroke();
      for (const s of S) dot(s.x * cw, s.y * ch, 2.5, INK);
      const hx = D.cols >> 1, hy = row < D.rows ? row : D.rows >> 1;   // one cell shows its measurement
      if (row < D.rows) line(0, row * ch, W, row * ch, TARGET, 1.5);
      const s = S[nearest(hx, hy)], cx = (hx + 0.5) * cw, cy = (hy + 0.5) * ch, sx = s.x * cw, sy = s.y * ch;
      ring(cx, cy, Math.max(2, cw * 0.4), TARGET, 1.5);
      if (D.metric === "manhattan") { line(cx, cy, sx, cy, TARGET, 1); line(sx, cy, sx, sy, TARGET, 1); }
      else line(cx, cy, sx, sy, TARGET, 1);
      label("d = " + dist(s, hx, hy).toFixed(1), (cx + sx) / 2 + 4, (cy + sy) / 2 - 4, TARGET);
      label(S.length + " seeds · " + D.metric, 4, 11);
      label(D.label + " · " + (D.metric === "manhattan" ? "d = |dx| + |dy|" : "d = √(dx² + dy²)"), W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Voronoi", "Vitreous", "manhattan distance, three times the seeds and a glass palette — diamond shards with 45° edges", { metric: "manhattan", seeds: 26, palette: "glass" });

def("L", "Lsystem", "scatter", "a string rewritten by one rule, drawn by a turtle (F forward, ± turn, [ ] push/pop) — a plant in four iterations — press to regrow", function (u) {
  var D = { axiom: "F",
            rule: "F[+F]F[-F]F",   // what every F becomes, each iteration
            angle: 25,             // degrees per + or −
            iters: 4,              // iterations, one per beat
            jitter: 7,             // degrees of random angle on each regrowth
            beat: 0.9,             // seconds per iteration (the segments are revealed across it)
            rest: 2.4,
            maxLen: 20000,         // the string stops growing past this
            seed: 2,
            label: "turtle: F forward · + − turn by angle · [ ] push / pop" };
  const { ctx, W, H, stage, label, rng, clamp, mix, BONE, GOOD, TARGET } = u;
  // L-SYSTEMS. a plant is a sentence: start with the AXIOM "F" and apply
  // the RULE to every F at once — "F[+F]F[-F]F" says "grow, branch left,
  // grow, branch right, grow". four rounds of that is a string of fifteen
  // hundred letters. a TURTLE reads it: F draws a step, + and − turn it by
  // the angle, [ remembers where it stands and ] jumps back there, which
  // is how a branch ends and the trunk continues. the lexicon's Vine was
  // one chain; this is the grammar that draws the whole hedge.
  const areaW = W - 16, areaH = H - 34;
  let seed = D.seed, ang = D.angle, iter = 0, str = "", segs = [], acc = 0, restT = 0, fit = { s: 1, x: 0, y: 0 };
  function expand(s) {
    let out = "";
    for (let i = 0; i < s.length; i++) { out += s[i] === "F" ? D.rule : s[i]; if (out.length > D.maxLen) return s; }
    return out;
  }
  function trace() {                                   // the turtle's walk, in unit steps
    segs = [];
    let x = 0, y = 0, a = -Math.PI / 2, depth = 0;
    const stack = [], da = ang * Math.PI / 180;
    let minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (let i = 0; i < str.length; i++) {
      const c = str[i];
      if (c === "F") {
        const nx = x + Math.cos(a), ny = y + Math.sin(a);
        segs.push(x, y, nx, ny, depth); x = nx; y = ny;
        if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y;
      } else if (c === "+") a += da;
      else if (c === "-") a -= da;
      else if (c === "[") { stack.push(x, y, a); depth++; }
      else if (c === "]" && stack.length) { a = stack.pop(); y = stack.pop(); x = stack.pop(); depth--; }
    }
    const bw = Math.max(1e-3, maxX - minX), bh = Math.max(1e-3, maxY - minY);
    fit.s = Math.min(areaW / bw, areaH / bh) * 0.94;   // fit the drawing to the card, whatever the rule
    fit.x = W / 2 - (minX + maxX) / 2 * fit.s;
    fit.y = H - 24 - maxY * fit.s;
  }
  function regrow() { const r = rng(seed); ang = D.angle + (r() * 2 - 1) * D.jitter; iter = 0; str = D.axiom; acc = 0; restT = 0; trace(); }
  regrow();
  return {
    press() { seed++; regrow(); },
    frame(dt, t) {
      stage();
      if (iter < D.iters) { if ((acc += dt) >= D.beat) { acc = 0; iter++; str = expand(str); trace(); } }
      else if ((restT += dt) > D.rest) { seed++; regrow(); }
      const count = segs.length / 5, k = iter < D.iters ? clamp(acc / D.beat, 0, 1) : 1;
      const show = iter === 0 ? count : Math.floor(count * Math.max(k, 0.02));   // each iteration is revealed as it grows
      let curDepth = -1;
      for (let i = 0; i < show; i++) {
        const d = segs[i * 5 + 4];
        if (d !== curDepth) {
          if (curDepth >= 0) ctx.stroke();
          curDepth = d;
          ctx.strokeStyle = mix(BONE, GOOD, clamp(d / 4, 0, 1));
          ctx.lineWidth = Math.max(0.6, 2.4 - d * 0.5);
          ctx.beginPath();
        }
        ctx.moveTo(fit.x + segs[i * 5] * fit.s, fit.y + segs[i * 5 + 1] * fit.s);
        ctx.lineTo(fit.x + segs[i * 5 + 2] * fit.s, fit.y + segs[i * 5 + 3] * fit.s);
      }
      if (curDepth >= 0) ctx.stroke();
      label("F → " + D.rule, 4, 11, TARGET);
      label("n = " + iter + " · |s| = " + str.length + " · angle " + ang.toFixed(1) + "°", W - 4, 11, null, "right");
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Lsystem", "Lichen", "a different rule and a narrower angle — a bushy coral that splits three ways at every joint", { rule: "FF-[-F+F+F]+[+F-F-F]", angle: 22, iters: 3 });
/* ───────────────────────── ROOMS, CAVES & MAZES ─────────────────────────
   Places from grids. A grid is the cheapest world there is — a row of
   numbers per row of tiles — and every generator here is one rule run
   over it: ask the neighbours, halve the rectangle, carve to the next
   cell, keep only the tiles the rules still allow, sum the neighbours
   into an index. Five cards: Caves, Bsp, Maze, Wfc, Autotile. All seeded. */

def("C", "Caves", "rooms", "random fill, then \"a cell is rock if 5+ of its 8 neighbours are rock\", four times — press to regrow", function (u) {
  var D = { cols: 48, rows: 30,   // the grid
            fill: 0.45,           // the chance a cell starts as rock
            rule: 5,              // rock if this many neighbours (of 8) are rock
            passes: 4,            // smoothing passes, animated one per beat
            beat: 0.55,           // seconds per pass
            rest: 2.4,            // seconds to rest in the finished cave
            seed: 7,
            label: "rock if neighbours ≥ rule · open if ≤ rule − 2 · then keep the largest region" };
  const { ctx, W, H, stage, cells, drawCells, rng, label, mote, clamp, DIM, BONE, HOT, TARGET, GOOD } = u;
  // CELLULAR AUTOMATA. start from noise — every cell is rock with chance
  // fill — then run one rule over the whole grid a few times: "count the
  // 8 neighbours; rock if rule or more of them are rock, open if two
  // fewer, otherwise stay as you are" (a majority vote, counting yourself).
  // lonely rocks vanish, lonely gaps fill, and the noise rounds itself
  // into caverns — the falling-sand idea (lexicon Sand) with a vote in
  // place of gravity. beyond the edge counts as rock, so the cave is
  // closed. the last step is a FLOOD FILL: label every open region, keep
  // the biggest, and turn the rest back to rock so nothing is unreachable.
  const cw = W / D.cols, ch = (H - 18) / D.rows, N = D.cols * D.rows;
  let g = cells(D.cols, D.rows), g2 = cells(D.cols, D.rows);
  g.fill = 1; g2.fill = 1;                             // off the map is rock
  const lab = new Int32Array(N), stack = new Int32Array(N);
  let seed = D.seed, r, pass, acc, restT, hx, hy, hn, kept, dropped, homeX, homeY, sp;
  function count(x, y) {
    let n = 0;
    for (let j = -1; j <= 1; j++) for (let i = -1; i <= 1; i++) if ((i || j) && g.get(x + i, y + j) === 1) n++;
    return n;
  }
  function watch() {                                   // a cell to watch: one sitting right on the rule's edge
    hx = 1 + Math.floor(r() * (D.cols - 2)); hy = 1 + Math.floor(r() * (D.rows - 2));
    for (let tries = 0; tries < 40; tries++) {
      const x = 1 + Math.floor(r() * (D.cols - 2)), y = 1 + Math.floor(r() * (D.rows - 2)), n = count(x, y);
      if (n >= D.rule - 2 && n <= D.rule) { hx = x; hy = y; break; }
    }
    hn = count(hx, hy);
  }
  function regrow() {
    r = rng(seed); pass = 0; acc = 0; restT = 0; kept = 0; dropped = 0; homeX = -1;
    for (let i = 0; i < N; i++) g.a[i] = r() < D.fill ? 1 : 0;
    watch();
  }
  function verdict(x, y, n) { return n >= D.rule ? 1 : n <= D.rule - 2 ? 0 : g.get(x, y); }   // rock · open · unchanged
  function smoothPass() {                              // every cell asks its eight neighbours at once
    for (let y = 0; y < D.rows; y++) for (let x = 0; x < D.cols; x++) g2.a[y * D.cols + x] = verdict(x, y, count(x, y));
    const tmp = g; g = g2; g2 = tmp;
    watch();
  }
  function visit(c, id) { if (g.a[c] === 0 && !lab[c]) { lab[c] = id; stack[sp++] = c; } }
  function keepLargest() {
    lab.fill(0);
    let best = 0, bestSize = 0, id = 0;
    for (let s = 0; s < N; s++) {
      if (g.a[s] !== 0 || lab[s]) continue;
      id++; sp = 0; stack[sp++] = s; lab[s] = id;
      let size = 0;
      while (sp) {
        const c = stack[--sp], x = c % D.cols, y = (c - x) / D.cols;
        size++;
        if (x > 0) visit(c - 1, id);
        if (x < D.cols - 1) visit(c + 1, id);
        if (y > 0) visit(c - D.cols, id);
        if (y < D.rows - 1) visit(c + D.cols, id);
      }
      if (size > bestSize) { bestSize = size; best = id; }
    }
    kept = bestSize; dropped = 0;
    for (let i = 0; i < N; i++) if (g.a[i] === 0 && lab[i] !== best) { g.a[i] = 2; dropped++; }   // doomed: the small pockets
    for (let tries = 0; tries < 60 && homeX < 0; tries++) {   // somewhere in the kept region to stand
      const c = Math.floor(r() * N);
      if (g.a[c] === 0) { homeX = c % D.cols; homeY = (c - homeX) / D.cols; }
    }
    if (homeX < 0) for (let c = 0; c < N; c++) if (g.a[c] === 0) { homeX = c % D.cols; homeY = (c - homeX) / D.cols; break; }
  }
  function seal() { for (let i = 0; i < N; i++) if (g.a[i] === 2) g.a[i] = 1; }
  regrow();
  return {
    press() { seed++; regrow(); },
    frame(dt, t) {
      stage();
      const last = D.passes + 2;                       // passes, then the flood, then the sealing
      if (pass < last) {
        if ((acc += dt) >= D.beat) {
          acc = 0; pass++;
          if (pass <= D.passes) smoothPass();
          else if (pass === D.passes + 1) keepLargest();
          else seal();
        }
      } else if ((restT += dt) > D.rest) { seed++; regrow(); }
      drawCells(g, 0, 0, cw, ch, (v) => v === 1 ? "rgba(201,196,228,0.5)" : v === 2 ? "rgba(245,138,138,0.45)" : null);
      if (pass < D.passes) {                           // the rule, on one cell
        ctx.strokeStyle = TARGET; ctx.lineWidth = 1.5;
        ctx.strokeRect((hx - 1) * cw, (hy - 1) * ch, cw * 3, ch * 3);
        const v = verdict(hx, hy, hn);
        ctx.fillStyle = hn >= D.rule ? HOT : hn <= D.rule - 2 ? GOOD : TARGET;
        ctx.fillRect(hx * cw, hy * ch, cw, ch);
        ctx.fillStyle = "#131020";
        ctx.font = "bold " + Math.round(clamp(ch * 0.95, 7, 13)) + "px system-ui, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(hn, (hx + 0.5) * cw, (hy + 0.5) * ch + ch * 0.35);
        ctx.textAlign = "left";
        const txt = hn + " of 8 " + (hn >= D.rule ? "≥ " + D.rule + " → rock" : hn <= D.rule - 2 ? "≤ " + (D.rule - 2) + " → open" : "= " + hn + " → stays " + (v ? "rock" : "open"));
        const right = hx < D.cols * 0.6;
        label(txt, right ? (hx + 2.2) * cw : (hx - 1.2) * cw, (hy + 0.5) * ch + 3, TARGET, right ? "left" : "right");
      } else if (homeX >= 0 && pass > D.passes) mote((homeX + 0.5) * cw, (homeY + 0.5) * ch, 0, undefined, Math.min(cw, ch) * 0.9);
      const stageTxt = pass === 0 ? "random fill " + Math.round(D.fill * 100) + "%" :
                       pass <= D.passes ? "pass " + pass + " / " + D.passes :
                       pass === D.passes + 1 ? "flood fill: keep " + kept + ", drop " + dropped + " cells" : "sealed · " + kept + " open cells";
      label(stageTxt, 4, 11, pass === D.passes + 1 ? HOT : null);
      label(D.label + " · rule " + D.rule + " · ×" + D.passes, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Caves", "Catacombs", "a denser fill and fewer passes, so the rock never rounds off — narrow winding tunnels instead of caverns", { fill: 0.52, passes: 2 });

def("B", "Bsp", "rooms", "halve the map, halve the halves; a room in every leaf; siblings joined by a corridor, bottom up — press to resplit", function (u) {
  var D = { cols: 48, rows: 30,      // the map
            depth: 4,                // how many times a half is halved again
            minLeaf: 7,              // a leaf is never narrower than this
            roomMin: 3, roomMax: 12, // room sides, in cells (also capped by the leaf)
            corridor: "bent",        // "bent": an L between any two rooms · "straight": the pair that lines up
            beat: 0.3,               // seconds per split
            rest: 2.6,
            seed: 3,
            label: "split 35–65 % · room per leaf · join siblings" };
  const { ctx, W, H, stage, cells, drawCells, rng, label, line, dot, rect, clamp, DIM, BONE, MOVER, TARGET, GOOD } = u;
  // BINARY SPACE PARTITION. cut the map in two somewhere between 35 and
  // 65 %; cut each half again; stop after depth cuts or when a piece is
  // too thin. every leaf gets one room that fits inside it, so rooms never
  // overlap by construction. then walk the tree back up: every internal
  // node joins a room from its left child to a room from its right child,
  // so the whole dungeon is connected without a search. the tree on the
  // right is the same map as a family — the map is the tree, flattened.
  const mw = W * 0.74, mh = H - 18, cw = mw / D.cols, ch = mh / D.rows, tx0 = mw + 10, tw = W - tx0 - 4;
  const g = cells(D.cols, D.rows);
  let seed = D.seed, r, nodes, events, ev, acc, restT, leaves, curSplit;
  function makeNode(x, y, w, h, d) { return { x: x, y: y, w: w, h: h, d: d, a: null, b: null, room: null, split: null, rooms: [], tx: 0 }; }
  function build() {
    r = rng(seed); g.a.fill(0); events = []; ev = 0; acc = 0; restT = 0; curSplit = null;
    const root = makeNode(0, 0, D.cols, D.rows, 0);
    nodes = [root];
    const queue = [root];
    while (queue.length) {                             // breadth first, so the splits animate coarse to fine
      const n = queue.shift();
      if (n.d >= D.depth) continue;
      const canV = n.w >= 2 * D.minLeaf, canH = n.h >= 2 * D.minLeaf;
      if (!canV && !canH) continue;
      const vert = canV && canH ? (n.w / n.h > 1.25 ? true : n.h / n.w > 1.25 ? false : r() < 0.5) : canV;
      const span = vert ? n.w : n.h, lo = Math.max(D.minLeaf, Math.floor(span * 0.35)), hi = Math.min(span - D.minLeaf, Math.ceil(span * 0.65));
      const at = lo + Math.floor(r() * Math.max(1, hi - lo + 1));
      n.split = { vert: vert, at: at };
      n.a = vert ? makeNode(n.x, n.y, at, n.h, n.d + 1) : makeNode(n.x, n.y, n.w, at, n.d + 1);
      n.b = vert ? makeNode(n.x + at, n.y, n.w - at, n.h, n.d + 1) : makeNode(n.x, n.y + at, n.w, n.h - at, n.d + 1);
      nodes.push(n.a, n.b); queue.push(n.a, n.b);
      events.push({ kind: "split", node: n });
    }
    leaves = 0;
    let slot = 0;
    (function place(n) {                               // rooms in the leaves, and a column for the tree drawing
      if (!n.a) {
        const hi = Math.max(1, Math.min(D.roomMax, n.w - 2)), hj = Math.max(1, Math.min(D.roomMax, n.h - 2));
        const rw = Math.min(hi, D.roomMin + Math.floor(r() * Math.max(1, hi - D.roomMin + 1)));
        const rh = Math.min(hj, D.roomMin + Math.floor(r() * Math.max(1, hj - D.roomMin + 1)));
        const rx = n.x + 1 + Math.floor(r() * Math.max(1, n.w - 1 - rw)), ry = n.y + 1 + Math.floor(r() * Math.max(1, n.h - 1 - rh));
        n.room = { x: rx, y: ry, w: rw, h: rh };
        n.rooms = [n.room]; n.tx = slot++; leaves++;
        return;
      }
      place(n.a); place(n.b);
      n.rooms = n.a.rooms.concat(n.b.rooms);
      n.tx = (n.a.tx + n.b.tx) / 2;
    })(root);
    events.push({ kind: "rooms" });
    for (let d = D.depth - 1; d >= 0; d--) {           // corridors: deepest siblings first
      const level = [];
      for (const n of nodes) if (n.a && n.d === d) level.push(n);
      if (level.length) events.push({ kind: "join", nodes: level });
    }
  }
  function carveRoom(m) { for (let y = m.y; y < m.y + m.h; y++) for (let x = m.x; x < m.x + m.w; x++) g.set(x, y, 1); }
  function carveH(x1, x2, y) { for (let x = Math.min(x1, x2); x <= Math.max(x1, x2); x++) if (g.get(x, y) === 0) g.set(x, y, 2); }
  function carveV(y1, y2, x) { for (let y = Math.min(y1, y2); y <= Math.max(y1, y2); y++) if (g.get(x, y) === 0) g.set(x, y, 2); }
  function join(n) {
    const vert = n.split.vert;
    let ra = null, rb = null, best = 0;
    if (D.corridor === "straight")                     // the pair of rooms that overlap most across the cut
      for (const p of n.a.rooms) for (const q of n.b.rooms) {
        const ov = vert ? Math.min(p.y + p.h, q.y + q.h) - Math.max(p.y, q.y) : Math.min(p.x + p.w, q.x + q.w) - Math.max(p.x, q.x);
        if (ov > best) { best = ov; ra = p; rb = q; }
      }
    if (!ra) { ra = n.a.rooms[Math.floor(r() * n.a.rooms.length)]; rb = n.b.rooms[Math.floor(r() * n.b.rooms.length)]; }
    const ax = ra.x + (ra.w >> 1), ay = ra.y + (ra.h >> 1), bx = rb.x + (rb.w >> 1), by = rb.y + (rb.h >> 1);
    if (best > 0) {                                    // a straight run through the shared band
      if (vert) { const y = Math.max(ra.y, rb.y) + Math.floor(r() * best); carveH(ax, bx, y); }
      else { const x = Math.max(ra.x, rb.x) + Math.floor(r() * best); carveV(ay, by, x); }
    } else if (r() < 0.5) { carveH(ax, bx, ay); carveV(ay, by, bx); }   // an L, elbow on one side …
    else { carveV(ay, by, ax); carveH(ax, bx, by); }                    // … or the other
  }
  function fire(e) {
    if (e.kind === "split") { curSplit = e.node; e.node.fired = true; }
    else if (e.kind === "rooms") { for (const n of nodes) if (n.room) carveRoom(n.room); curSplit = null; }
    else for (const n of e.nodes) join(n);
  }
  build();
  return {
    press() { seed++; build(); },
    frame(dt, t) {
      stage();
      if (ev < events.length) { if ((acc += dt) >= D.beat) { acc = 0; fire(events[ev++]); } }
      else if ((restT += dt) > D.rest) { seed++; build(); }
      drawCells(g, 0, 0, cw, ch, (v) => v === 1 ? "rgba(201,196,228,0.55)" : v === 2 ? "rgba(138,217,245,0.45)" : null);
      let splits = 0;
      for (let i = 0; i < ev; i++) {                   // every cut so far, the newest in amber
        const e = events[i];
        if (e.kind !== "split") continue;
        splits++;
        const n = e.node, s = n.split, hot = n === curSplit;
        if (s.vert) line((n.x + s.at) * cw, n.y * ch, (n.x + s.at) * cw, (n.y + n.h) * ch, hot ? TARGET : "rgba(245,193,105,0.22)", hot ? 1.5 : 1);
        else line(n.x * cw, (n.y + s.at) * ch, (n.x + n.w) * cw, (n.y + s.at) * ch, hot ? TARGET : "rgba(245,193,105,0.22)", hot ? 1.5 : 1);
        if (hot) label((s.vert ? "x = " : "y = ") + (s.vert ? n.x + s.at : n.y + s.at) + " (" + Math.round(s.at / (s.vert ? n.w : n.h) * 100) + " %)",
                       clamp((n.x + (s.vert ? s.at : n.w / 2)) * cw + 3, 0, mw - 60), clamp((n.y + (s.vert ? 1.5 : s.at)) * ch - 3, 10, mh), TARGET);
      }
      const dy = (mh - 20) / Math.max(1, D.depth), dx = tw / Math.max(1, leaves);   // the tree, small, beside the map
      const px = (n) => tx0 + (n.tx + 0.5) * dx, py = (n) => 10 + n.d * dy;
      for (const n of nodes) {
        if (!n.a || !n.fired) continue;                // a branch appears with its cut
        line(px(n), py(n), px(n.a), py(n.a), DIM); line(px(n), py(n), px(n.b), py(n.b), DIM);
      }
      for (const n of nodes) {
        if (n.a) dot(px(n), py(n), n === curSplit ? 3 : 1.8, n === curSplit ? TARGET : BONE);
        else if (g.get(n.room.x, n.room.y) === 1) rect(px(n) - 1.5, py(n) - 1.5, 3, 3, BONE);   // a leaf with its room
        else dot(px(n), py(n), 1.2, DIM);
      }
      line(mw + 4, 0, mw + 4, mh, "rgba(201,196,228,0.2)");
      label("splits " + splits + " · leaves " + leaves + " · " + D.corridor, 4, 11);
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Bsp", "Bunker", "one more level of cuts, tiny rooms and straight corridors — a bunker's cell block", { depth: 5, minLeaf: 5, roomMax: 4, corridor: "straight" });

def("M", "Maze", "rooms", "one grid, two carvers — the backtracker digs long winding halls, prim's picks any frontier cell and branches — press to carve again", function (u) {
  var D = { cols: 24, rows: 15,      // cells (each keeps four wall bits)
            algo: "backtracker",     // "backtracker" or "prim"
            perBeat: 2, beat: 0.03,  // cells carved per beat
            rest: 2.6,
            seed: 5,
            label: "backtracker: go deep, back up · prim: any frontier cell" };
  const { ctx, W, H, stage, rng, label, dot, mote, line, clamp, DIM, BONE, MOVER, TARGET, HOT } = u;
  // MAZE CARVING. every cell starts walled on four sides; a carver visits
  // cells and knocks down the wall between each new cell and the one it
  // came from, so the maze is a tree — one route between any two cells.
  // the RECURSIVE BACKTRACKER keeps a stack: go to a random unvisited
  // neighbour, and when there is none, back up. it commits, so halls are
  // long. PRIM'S keeps a FRONTIER — every unvisited cell touching the
  // carved part — and picks any of them, so it branches everywhere and
  // halls are short. the dead-end count is the fingerprint: the Astar
  // card would find these mazes very different to search.
  const N = D.cols * D.rows, cw = W / D.cols, ch = (H - 18) / D.rows;
  const open = new Uint8Array(N), seen = new Uint8Array(N), stack = new Int32Array(N), front = new Int32Array(N), inFront = new Uint8Array(N);
  const DX = [0, 1, 0, -1], DY = [-1, 0, 1, 0], BIT = [1, 2, 4, 8], OPP = [4, 8, 1, 2];   // n e s w
  let seed = D.seed, r, sp, nf, head, headDir, carved, done, acc, restT;
  const nbrs = [];
  function idx(x, y) { return y * D.cols + x; }
  function carve() {
    r = rng(seed); open.fill(0); seen.fill(0); inFront.fill(0); sp = 0; nf = 0; carved = 1; done = false; acc = 0; restT = 0; headDir = 1;
    const s = idx(Math.floor(r() * D.cols), Math.floor(r() * D.rows));
    seen[s] = 1; head = s;
    if (D.algo === "prim") addFrontier(s); else stack[sp++] = s;
  }
  function addFrontier(c) {
    const x = c % D.cols, y = (c - x) / D.cols;
    for (let d = 0; d < 4; d++) {
      const nx = x + DX[d], ny = y + DY[d];
      if (nx < 0 || ny < 0 || nx >= D.cols || ny >= D.rows) continue;
      const n = idx(nx, ny);
      if (!seen[n] && !inFront[n]) { inFront[n] = 1; front[nf++] = n; }
    }
  }
  function link(c, d) {                                // knock the wall between c and its neighbour in direction d
    const n = c + DX[d] + DY[d] * D.cols;
    open[c] |= BIT[d]; open[n] |= OPP[d];
    return n;
  }
  function step() {
    if (D.algo === "prim") {
      if (nf === 0) { done = true; return; }
      const i = Math.floor(r() * nf), c = front[i];
      front[i] = front[--nf]; inFront[c] = 0;
      const x = c % D.cols, y = (c - x) / D.cols;
      nbrs.length = 0;
      for (let d = 0; d < 4; d++) {                    // the carved cells it touches: pick one to join
        const nx = x + DX[d], ny = y + DY[d];
        if (nx >= 0 && ny >= 0 && nx < D.cols && ny < D.rows && seen[idx(nx, ny)]) nbrs.push(d);
      }
      const d = nbrs[Math.floor(r() * nbrs.length)];
      link(c, d); seen[c] = 1; carved++; head = c; headDir = (d + 2) % 4;
      addFrontier(c);
    } else {
      if (sp === 0) { done = true; return; }
      const c = stack[sp - 1], x = c % D.cols, y = (c - x) / D.cols;
      nbrs.length = 0;
      for (let d = 0; d < 4; d++) {
        const nx = x + DX[d], ny = y + DY[d];
        if (nx >= 0 && ny >= 0 && nx < D.cols && ny < D.rows && !seen[idx(nx, ny)]) nbrs.push(d);
      }
      if (nbrs.length === 0) { sp--; head = sp ? stack[sp - 1] : c; return; }   // a dead end: back up
      const d = nbrs[Math.floor(r() * nbrs.length)], n = link(c, d);
      seen[n] = 1; stack[sp++] = n; carved++; head = n; headDir = d;
    }
  }
  carve();
  return {
    press() { seed++; carve(); },
    frame(dt, t) {
      stage();
      if (!done) {
        acc += dt;
        let guard = 0;
        while (acc >= D.beat && !done && guard++ < 30) { acc -= D.beat; for (let i = 0; i < D.perBeat && !done; i++) step(); }
      } else if ((restT += dt) > D.rest) { seed++; carve(); }
      ctx.fillStyle = "rgba(0,0,0,0.28)";              // unvisited: still solid
      for (let c = 0; c < N; c++) if (!seen[c]) { const x = c % D.cols; ctx.fillRect(x * cw, ((c - x) / D.cols) * ch, cw + 0.5, ch + 0.5); }
      ctx.strokeStyle = "rgba(201,196,228,0.7)"; ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.rect(0.5, 0.5, D.cols * cw - 1, D.rows * ch - 1);
      for (let c = 0; c < N; c++) {                    // each cell owns its east and south wall
        const x = c % D.cols, y = (c - x) / D.cols;
        if (!(open[c] & 2) && x < D.cols - 1) { ctx.moveTo((x + 1) * cw, y * ch); ctx.lineTo((x + 1) * cw, (y + 1) * ch); }
        if (!(open[c] & 4) && y < D.rows - 1) { ctx.moveTo(x * cw, (y + 1) * ch); ctx.lineTo((x + 1) * cw, (y + 1) * ch); }
      }
      ctx.stroke();
      let dead = 0;
      for (let c = 0; c < N; c++) { const o = open[c]; if (o === 1 || o === 2 || o === 4 || o === 8) dead++; }
      if (!done) {
        if (D.algo === "prim") { for (let i = 0; i < nf; i++) { const c = front[i], x = c % D.cols; dot((x + 0.5) * cw, ((c - x) / D.cols + 0.5) * ch, Math.min(cw, ch) * 0.18, TARGET); } }
        else if (sp > 1) {                             // the stack: the way back
          ctx.strokeStyle = "rgba(138,217,245,0.5)"; ctx.lineWidth = Math.max(1, cw * 0.18);
          ctx.beginPath();
          for (let i = 0; i < sp; i++) { const c = stack[i], x = c % D.cols, px = (x + 0.5) * cw, py = ((c - x) / D.cols + 0.5) * ch; if (i) ctx.lineTo(px, py); else ctx.moveTo(px, py); }
          ctx.stroke();
        }
      }
      const hx = head % D.cols, hy = (head - hx) / D.cols;
      mote((hx + 0.5) * cw, (hy + 0.5) * ch, [-Math.PI / 2, 0, Math.PI / 2, Math.PI][headDir], undefined, Math.min(cw, ch) * 0.28);
      label(D.algo + " · " + carved + " / " + N + (D.algo === "prim" ? " · frontier " + nf : " · stack " + sp), 4, 11);
      label("dead ends: " + dead, W - 4, 11, done ? HOT : null, "right");
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Maze", "Meander", "prim's carver on a bigger grid — short branchy halls and a swarm of dead ends", { algo: "prim", cols: 32, rows: 20 });

def("W", "Wfc", "rooms", "each cell holds every tile it could still be; collapse the least undecided one, propagate the rules, repeat — press to collapse from your click", function (u) {
  var D = { cols: 32, rows: 20,
            tiles: ["water", "sand", "grass"],
            colours: ["#3A6FB5", "#E2C98A", "#6FAF5E"],
            weights: [2, 2, 3],                                  // how much each tile wants to be picked
            rules: [[0, 0], [0, 1], [1, 1], [1, 2], [2, 2]],     // the pairs that may touch
            perBeat: 4, beat: 0.03,                              // cells collapsed per beat
            rest: 2.6,
            seed: 4,
            label: "lowest entropy first · propagate · contradiction → restart" };
  const { ctx, W, H, stage, rng, label, ring, rect, line, clamp, rgba, DIM, BONE, TARGET, HOT, GOOD } = u;
  // WAVE FUNCTION COLLAPSE, the simple tiled kind. every cell begins as a
  // SUPERPOSITION — a bitmask of every tile it could still be. each step
  // picks the cell with the LOWEST ENTROPY (fewest options left, ties at
  // random), COLLAPSES it to one tile by weight, and PROPAGATES: each
  // neighbour drops any option no longer allowed next to what remains,
  // and if it changed, its neighbours check again. a cell left with zero
  // options is a CONTRADICTION; the honest fix is to start over. the
  // rule table in the corner is the whole world's grammar: five pairs.
  const N = D.cols * D.rows, T = D.tiles.length, cw = W / D.cols, ch = (H - 18) / D.rows;
  const opt = new Uint8Array(N), queue = new Int32Array(N), queued = new Uint8Array(N), allow = [];
  const FULL = (1 << T) - 1;
  for (let a = 0; a < T; a++) { allow[a] = 0; for (const p of D.rules) { if (p[0] === a) allow[a] |= 1 << p[1]; if (p[1] === a) allow[a] |= 1 << p[0]; } }
  let seed = D.seed, r, left, restarts, last, lastE, acc, restT, flash;
  function bits(m) { let n = 0; while (m) { n += m & 1; m >>= 1; } return n; }
  function reset(fresh) { if (fresh) { r = rng(seed); restarts = 0; } opt.fill(FULL); left = N; last = -1; lastE = 0; acc = 0; restT = 0; }
  function propagate(c0) {
    let qn = 0; queue[qn++] = c0; queued[c0] = 1;
    let ok = true;
    for (let qi = 0; qi < qn; qi++) {
      const c = queue[qi], x = c % D.cols, y = (c - x) / D.cols;
      let m = 0;
      for (let t = 0; t < T; t++) if (opt[c] & (1 << t)) m |= allow[t];   // what may sit beside what remains
      const nb = [x > 0 ? c - 1 : -1, x < D.cols - 1 ? c + 1 : -1, y > 0 ? c - D.cols : -1, y < D.rows - 1 ? c + D.cols : -1];
      for (let k = 0; k < 4; k++) {
        const n = nb[k]; if (n < 0) continue;
        const nm = opt[n] & m;
        if (nm !== opt[n]) {
          if (bits(opt[n]) > 1 && bits(nm) === 1) left--;
          opt[n] = nm;
          if (nm === 0) ok = false;
          if (!queued[n] && qn < N) { queued[n] = 1; queue[qn++] = n; }
        }
      }
    }
    for (let i = 0; i < qn; i++) queued[queue[i]] = 0;
    return ok;
  }
  function collapse(c) {                               // one tile, by weight, from what is left
    let total = 0;
    for (let t = 0; t < T; t++) if (opt[c] & (1 << t)) total += D.weights[t];
    let v = r() * total, pick = 0;
    for (let t = 0; t < T; t++) if (opt[c] & (1 << t)) { pick = t; v -= D.weights[t]; if (v <= 0) break; }
    lastE = bits(opt[c]); last = c;
    opt[c] = 1 << pick; left--;
    if (!propagate(c)) { restarts++; flash = 1; reset(false); }
  }
  function step() {
    if (left <= 0) return;
    let best = 99, ties = 0, pick = -1;
    for (let c = 0; c < N; c++) {                      // the lowest entropy, ties broken by the seed
      const e = bits(opt[c]);
      if (e < 2) continue;
      if (e < best) { best = e; ties = 1; pick = c; }
      else if (e === best && r() * ++ties < 1) pick = c;
    }
    if (pick < 0) { left = 0; return; }
    collapse(pick);
  }
  reset(true);
  return {
    press(x, y) {
      reset(true);                                     // the same seed, but your cell goes first
      collapse(clamp(Math.floor(y / ch), 0, D.rows - 1) * D.cols + clamp(Math.floor(x / cw), 0, D.cols - 1));
    },
    frame(dt, t) {
      stage();
      flash = Math.max(0, (flash || 0) - dt * 1.5);
      if (left > 0) {
        acc += dt;
        let guard = 0;
        while (acc >= D.beat && left > 0 && guard++ < 30) { acc -= D.beat; for (let i = 0; i < D.perBeat && left > 0; i++) step(); }
      } else if ((restT += dt) > D.rest) { seed++; reset(true); }
      const fs = clamp(cw * 0.75, 6, 11), allDigits = fs >= 7;
      ctx.font = fs + "px system-ui, sans-serif"; ctx.textAlign = "center";
      const lx = last >= 0 ? last % D.cols : -9, ly = last >= 0 ? (last - lx) / D.cols : -9;
      for (let c = 0; c < N; c++) {
        const x = c % D.cols, y = (c - x) / D.cols, m = opt[c], e = bits(m);
        if (e === 1) { ctx.fillStyle = D.colours[31 - Math.clz32(m)]; ctx.fillRect(x * cw, y * ch, cw + 0.5, ch + 0.5); }
        else {
          ctx.fillStyle = "rgba(232,229,244," + (0.04 + (T - e) * 0.07) + ")";   // fewer options: brighter
          ctx.fillRect(x * cw, y * ch, cw + 0.5, ch + 0.5);
          if (allDigits || Math.abs(x - lx) <= 1 && Math.abs(y - ly) <= 1) { ctx.fillStyle = "rgba(232,229,244,0.6)"; ctx.fillText(e, (x + 0.5) * cw, (y + 0.5) * ch + fs * 0.35); }
        }
      }
      ctx.textAlign = "left";
      if (last >= 0) {
        ctx.strokeStyle = TARGET; ctx.lineWidth = 1.5;
        ctx.strokeRect(lx * cw, ly * ch, cw, ch);
        label("e = " + lastE + " → " + D.tiles[31 - Math.clz32(opt[last] || 1)], clamp((lx + 1.3) * cw, 0, W - 70), clamp((ly + 0.5) * ch + 3, 10, H - 20), TARGET);
      }
      const s = clamp(W * 0.028, 6, 12), tx = W - (T + 1) * s - 6, ty = 4;   // the rule table
      rect(tx - 2, ty - 2, (T + 1) * s + 4, (T + 1) * s + 4, "rgba(19,16,32,0.75)");
      for (let a = 0; a < T; a++) { rect(tx + (a + 1) * s, ty, s - 1, s - 1, D.colours[a]); rect(tx, ty + (a + 1) * s, s - 1, s - 1, D.colours[a]); }
      for (let a = 0; a < T; a++) for (let b = 0; b < T; b++) {
        const ok = (allow[a] >> b) & 1;
        if (ok) rect(tx + (b + 1) * s + 1, ty + (a + 1) * s + 1, s - 3, s - 3, GOOD);
        else line(tx + (b + 1) * s + 2, ty + (a + 1) * s + s / 2, tx + (b + 2) * s - 3, ty + (a + 1) * s + s / 2, HOT, 1);
      }
      if (flash > 0) label("contradiction — restart", W / 2, H / 2, rgba(HOT, Math.min(1, flash)), "center");
      label(left > 0 ? "undecided " + left + " / " + N : "done · " + N + " cells", 4, 11);
      label("restarts " + restarts, 4, 22, restarts ? HOT : DIM);
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Wfc", "Wetlands", "a rule set that lets grass meet water and keeps sand rare — lakes with reeds instead of beaches", { weights: [5, 1, 2], rules: [[0, 0], [0, 1], [1, 1], [0, 2], [2, 2]] });

def("A", "Autotile", "rooms", "sum the wall neighbours into a bitmask (n1 e2 s4 w8); that index picks the tile, so edges and corners resolve themselves — drag to paint walls", function (u) {
  var D = { cols: 24, rows: 15,
            bits: 4,                   // 4: edges only (16 tiles) · 8: corners too (47 tiles)
            fill: 0.46,                // the seeded layout: chance a cell starts as wall
            smooth: 1,                 // neighbour-rule passes that round the layout off
            perBeat: 5, beat: 0.03,    // tiles laid per beat while the layout grows
            rest: 3,
            hold: 5,                   // seconds a painted map is kept before the next seed
            palette: "wall",           // "wall" or "island"
            palettes: { wall: ["#1A1532", "#8E88AC", "#E8E5F4", "#3E3960"], island: ["#2E5F9E", "#D9C48C", "#F7F1E0", "#A8925C"] },   // floor, tile, rim, inner corner
            seed: 6,
            label: "index = n·1 + e·2 + s·4 + w·8 → tile" };
  const { ctx, W, H, stage, rng, shuffle, label, clamp, rgba, DIM, TARGET, GOOD } = u;
  // AUTOTILING. a wall tile does not know what it looks like; its
  // neighbours decide. ask the four sides "are you a wall too?" and sum
  // the yeses with place values — north 1, east 2, south 4, west 8 — and
  // the BITMASK is a number from 0 to 15 that names exactly which edges
  // need a rim. paint one wall and the tiles around it change their own
  // index, so corners and ends resolve themselves. with 8 bits the
  // diagonals join in (only where both of their edges are walls), and
  // inner corners get their notch — the 47-tile "blob" set.
  const N = D.cols * D.rows, cw = W / D.cols, ch = (H - 18) / D.rows, pal = D.palettes[D.palette] || D.palettes.wall;
  const edge = D.palette === "island" ? 0 : 1;         // off the map: more wall, or open sea
  const target = new Uint8Array(N), g = new Uint8Array(N), tmp = new Uint8Array(N), mask = new Uint8Array(N), flash = new Float32Array(N);
  let order = [], seed = D.seed, laid, acc, restT, holdT, last, mode, sincePress;
  const wallAt = (x, y) => (x < 0 || y < 0 || x >= D.cols || y >= D.rows) ? edge : g[y * D.cols + x];
  function layout() {
    const r = rng(seed);
    for (let i = 0; i < N; i++) target[i] = r() < D.fill ? 1 : 0;
    for (let p = 0; p < D.smooth; p++) {               // the Caves rule, once or twice, so the walls come in blobs
      for (let y = 0; y < D.rows; y++) for (let x = 0; x < D.cols; x++) {
        let n = 0;
        for (let j = -1; j <= 1; j++) for (let i = -1; i <= 1; i++) if (i || j) { const xx = x + i, yy = y + j; n += (xx < 0 || yy < 0 || xx >= D.cols || yy >= D.rows) ? edge : target[yy * D.cols + xx]; }
        tmp[y * D.cols + x] = n >= 5 ? 1 : 0;
      }
      target.set(tmp);
    }
    order = [];
    for (let i = 0; i < N; i++) if (target[i]) order.push(i);
    shuffle(order, r);
    g.fill(0); laid = 0; acc = 0; restT = 0; holdT = 0; last = -1; sincePress = 9;
    remask();
  }
  function maskOf(x, y) {
    const n = wallAt(x, y - 1), e = wallAt(x + 1, y), s = wallAt(x, y + 1), w = wallAt(x - 1, y);
    if (D.bits !== 8) return n + e * 2 + s * 4 + w * 8;
    return n + e * 4 + s * 16 + w * 64 +               // corners count only between two present edges
           (n && e && wallAt(x + 1, y - 1) ? 2 : 0) + (e && s && wallAt(x + 1, y + 1) ? 8 : 0) +
           (s && w && wallAt(x - 1, y + 1) ? 32 : 0) + (w && n && wallAt(x - 1, y - 1) ? 128 : 0);
  }
  function remask() {
    for (let y = 0; y < D.rows; y++) for (let x = 0; x < D.cols; x++) {
      const i = y * D.cols + x, m = g[i] ? maskOf(x, y) : 0;
      if (g[i] && m !== mask[i]) flash[i] = 1;         // its index changed: a neighbour arrived or left
      mask[i] = m;
    }
  }
  layout();
  return {
    drag: true,
    press(x, y) {
      const cx = clamp(Math.floor(x / cw), 0, D.cols - 1), cy = clamp(Math.floor(y / ch), 0, D.rows - 1), i = cy * D.cols + cx;
      if (sincePress > 0.3) mode = g[i] ? 0 : 1;       // a fresh press toggles what it lands on; a drag keeps painting the same
      sincePress = 0;
      if (laid < order.length) { for (const c of order) g[c] = 1; laid = order.length; }   // finish the growth, then paint on it
      g[i] = mode; last = i; holdT = D.hold; restT = 0;
      remask();
    },
    frame(dt, t) {
      stage();
      sincePress += dt;
      for (let i = 0; i < N; i++) if (flash[i] > 0) flash[i] = Math.max(0, flash[i] - dt * 2.5);
      if (laid < order.length) {
        acc += dt;
        let guard = 0;
        while (acc >= D.beat && laid < order.length && guard++ < 30) { acc -= D.beat; for (let k = 0; k < D.perBeat && laid < order.length; k++) { last = order[laid++]; g[last] = 1; } }
        remask();
      } else if (holdT > 0) holdT -= dt;
      else if ((restT += dt) > D.rest) { seed++; layout(); }
      const fs = clamp(cw * 0.5, 6, 10), digits = fs >= 7, rim = Math.max(1.5, Math.min(cw, ch) * 0.16);
      ctx.fillStyle = pal[0]; ctx.fillRect(0, 0, D.cols * cw, D.rows * ch);
      ctx.font = fs + "px system-ui, sans-serif"; ctx.textAlign = "center";
      for (let y = 0; y < D.rows; y++) for (let x = 0; x < D.cols; x++) {
        const i = y * D.cols + x;
        if (!g[i]) continue;
        const px = x * cw, py = y * ch, m = mask[i];
        const n = m & 1, e = D.bits === 8 ? m & 4 : m & 2, s = D.bits === 8 ? m & 16 : m & 4, w = D.bits === 8 ? m & 64 : m & 8;
        ctx.fillStyle = flash[i] > 0 ? rgba(GOOD, 0.35 + flash[i] * 0.5) : pal[1];
        ctx.fillRect(px, py, cw + 0.5, ch + 0.5);
        ctx.fillStyle = pal[2];                        // a rim on every side that faces the floor
        if (!n) ctx.fillRect(px, py, cw + 0.5, rim);
        if (!s) ctx.fillRect(px, py + ch - rim, cw + 0.5, rim + 0.5);
        if (!w) ctx.fillRect(px, py, rim, ch + 0.5);
        if (!e) ctx.fillRect(px + cw - rim, py, rim + 0.5, ch + 0.5);
        if (D.bits === 8) {                            // inner corners: two edges present, the diagonal missing
          ctx.fillStyle = pal[3];
          if (n && e && !(m & 2)) ctx.fillRect(px + cw - rim, py, rim + 0.5, rim);
          if (e && s && !(m & 8)) ctx.fillRect(px + cw - rim, py + ch - rim, rim + 0.5, rim + 0.5);
          if (s && w && !(m & 32)) ctx.fillRect(px, py + ch - rim, rim, rim + 0.5);
          if (w && n && !(m & 128)) ctx.fillRect(px, py, rim, rim);
        }
        if (digits) { ctx.fillStyle = "rgba(19,16,32,0.7)"; ctx.fillText(m, px + cw / 2, py + ch / 2 + fs * 0.35); }
      }
      ctx.textAlign = "left";
      if (last >= 0 && g[last]) {                      // the sum, spelt out on the newest tile
        const lx = last % D.cols, ly = (last - lx) / D.cols, m = mask[last], parts = [];
        const names = D.bits === 8 ? ["n", "ne", "e", "se", "s", "sw", "w", "nw"] : ["n", "e", "s", "w"];
        for (let b = 0; b < names.length; b++) if (m & (1 << b)) parts.push(names[b] + "·" + (1 << b));
        ctx.strokeStyle = TARGET; ctx.lineWidth = 1.5;
        ctx.strokeRect((lx - 1) * cw, (ly - 1) * ch, cw * 3, ch * 3);
        const right = lx < D.cols * 0.55;
        label((parts.length ? parts.join(" + ") : "none") + " = " + m, right ? (lx + 2.3) * cw : (lx - 1.3) * cw, clamp((ly + 0.5) * ch + 3, 10, H - 22), TARGET, right ? "left" : "right");
      }
      label(D.bits + "-bit · " + (D.bits === 8 ? 47 : 16) + " tiles · " + (laid < order.length ? "laying " + laid + " / " + order.length : holdT > 0 ? "yours" : "seed " + seed), 4, 11);
      label(D.label + (D.bits === 8 ? " · + corners 2 · 8 · 32 · 128" : ""), W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Autotile", "Archipelago", "eight bits, so the corners join in, and an island palette — sand meets sea and the beaches draw their own bends", { bits: 8, palette: "island", smooth: 2 });
/* ───────────────────────── DICE, WAVES & SAVES ─────────────────────────
   The arithmetic around the world. Not the map but the things that
   decide what falls out of a chest, when the next wave comes, how a
   world folds into a file and back, and the one number that makes all
   of it repeatable: the seed. Four cards: Dice, Horde, Save, Seed.
   Every "random" here is rng(seed), so every visitor sees the same luck. */

def("D", "Dice", "dice", "loot by weight (a bar per rarity), a shuffle bag that empties before it repeats, and a pity timer that fattens the rare weight — press to roll ten", function (u) {
  var D = { names: ["common", "uncommon", "rare", "legendary"],
            weights: [60, 28, 10, 2],       // the loot table
            bag: [0, 0, 0, 0, 0, 1, 1, 2],  // the shuffle bag's contents, by rarity index
            pityMax: 60,                    // a legendary is forced when the drought reaches this
            pityRamp: 0.1,                  // extra legendary weight per dry roll
            every: 0.28,                    // seconds between rolls
            rolls: 80,                      // rolls per seed before the counts reset
            rest: 2.4,
            seed: 12,
            label: "roll × Σw · walk the cumulative · the bag is fair · pity is kind" };
  const { ctx, W, H, stage, rng, shuffle, label, rect, line, poly, dot, clamp, rgba, DIM, BONE, GOOD, MOVER, MAGIC, TARGET, HOT } = u;
  // WEIGHTED RANDOM. lay the weights end to end — 60, 28, 10, 2 — roll a
  // number from 0 to their sum, and walk along until the roll is spent:
  // the segment you stop in is the drop. that is every loot table. it is
  // fair on average and cruel in the moment, so games add two kindnesses.
  // a SHUFFLE BAG holds the drops as tokens, shuffled, and hands them out
  // until empty — every rarity arrives exactly its share per bag. a PITY
  // TIMER counts dry rolls and adds to the rare weight each time, forcing
  // it at a cap. the seed (ch01) makes even the luck reproducible.
  const K = D.names.length, cols = [BONE, GOOD, MOVER, MAGIC], counts = [], bagCounts = [];
  let seed = D.seed, r, done, pity, forced, roll, bagOrder, bagIdx, refills, lastW, lastB, acc, restT, tick;
  function reset() {
    r = rng(seed); done = 0; pity = 0; forced = 0; refills = 0; bagIdx = 0; bagOrder = []; lastW = -1; lastB = -1; acc = 0; restT = 0; tick = 0;
    roll = { v: 0, total: 1, at: 0 };
    for (let i = 0; i < K; i++) { counts[i] = 0; bagCounts[i] = 0; }
  }
  function legendaryW() { return D.weights[K - 1] + pity * D.pityRamp; }
  function once() {
    let total = 0;                                     // the weighted pick, with pity on the last weight
    for (let i = 0; i < K; i++) total += i === K - 1 ? legendaryW() : D.weights[i];
    const v = r() * total;
    let pick = K - 1, acc2 = 0;
    for (let i = 0; i < K; i++) { const w = i === K - 1 ? legendaryW() : D.weights[i]; if (v < acc2 + w) { pick = i; break; } acc2 += w; }
    let wasForced = false;
    if (pity >= D.pityMax && pick !== K - 1) { pick = K - 1; wasForced = true; forced++; }
    roll = { v: v, total: total, at: v / Math.max(1e-6, total), forced: wasForced };
    if (pick === K - 1) pity = 0; else pity++;
    counts[pick]++; lastW = pick;
    if (bagIdx >= bagOrder.length) { bagOrder = shuffle(D.bag.slice(), r); bagIdx = 0; refills++; }   // the bag: refill only when empty
    lastB = bagOrder[bagIdx++]; bagCounts[lastB]++;
    done++; tick = 1;
  }
  reset();
  return {
    press() { for (let i = 0; i < 10 && done < D.rolls; i++) once(); },
    frame(dt, t) {
      stage();
      tick = Math.max(0, tick - dt * 5);
      if (done < D.rolls) { if ((acc += dt) >= D.every) { acc = 0; once(); } }
      else if ((restT += dt) > D.rest) { seed++; reset(); }
      const x0 = 8, bw = W - 16, y1 = 24, bh = Math.max(6, H * 0.055);
      let total = 0;
      for (let i = 0; i < K; i++) total += i === K - 1 ? legendaryW() : D.weights[i];
      let x = x0;                                      // the cumulative bar: the weights laid end to end
      for (let i = 0; i < K; i++) {
        const w = (i === K - 1 ? legendaryW() : D.weights[i]) / total * bw;
        rect(x, y1, w, bh, rgba(cols[i], i === lastW ? 0.95 : 0.45));
        x += w;
      }
      const px = x0 + clamp(roll.at, 0, 1) * bw;
      poly([[px, y1 - 5], [px - 4, y1 - 11], [px + 4, y1 - 11]], roll.forced ? HOT : TARGET);
      line(px, y1 - 5, px, y1 + bh, roll.forced ? HOT : TARGET, 1.5);
      label("roll " + roll.v.toFixed(1) + " of " + total.toFixed(1) + " → " + (lastW >= 0 ? D.names[lastW] : "…") + (roll.forced ? " (forced)" : ""), x0, 11, roll.forced ? HOT : null);
      label(done + " / " + D.rolls, W - 8, 11, null, "right");
      const hy = y1 + bh + 10, hh = Math.max(10, H * 0.17), colW = bw / (K * 2 + 1);   // histograms: weighted vs bag, expected as a tick
      for (let i = 0; i < K; i++) {
        const cx = x0 + colW * (i * 2 + 1), n = Math.max(1, done);
        const wh = counts[i] / n * hh * 1.6, bhh = bagCounts[i] / n * hh * 1.6;
        rect(cx, hy + hh - Math.min(hh, wh), colW * 0.45, Math.min(hh, wh), rgba(cols[i], 0.85));
        rect(cx + colW * 0.5, hy + hh - Math.min(hh, bhh), colW * 0.45, Math.min(hh, bhh), rgba(cols[i], 0.4));
        const ex = hy + hh - Math.min(hh, D.weights[i] / total * hh * 1.6);
        line(cx - 2, ex, cx + colW, ex, DIM, 1);      // where the weight says the column should be
        if (W > 400) label(D.names[i] + " " + counts[i] + "·" + bagCounts[i], cx, hy + hh + 10, cols[i]);
        else label(D.names[i][0] + counts[i] + "·" + bagCounts[i], cx, hy + hh + 10, cols[i]);
      }
      label("weighted · bag", W - 8, hy + hh + 10, DIM, "right");
      const by = hy + hh + 22, chip = Math.min(bw / (D.bag.length + 2), H * 0.06);   // the bag, emptying token by token
      label("bag " + (bagOrder.length - bagIdx) + " / " + D.bag.length + " left · refills " + refills, x0, by - 2);
      for (let i = 0; i < bagOrder.length; i++) {
        const cx = x0 + chip * 0.5 + i * chip * 1.15, cy = by + chip * 0.6, drawn = i < bagIdx;
        if (drawn) { ctx.strokeStyle = rgba(cols[bagOrder[i]], 0.35); ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(cx, cy, chip * 0.42, 0, u.TAU); ctx.stroke(); }
        else dot(cx, cy, chip * 0.42 * (i === bagIdx ? 1 + tick * 0.3 : 1), cols[bagOrder[i]]);
      }
      const py = by + chip * 1.4 + 12, pw = bw;        // the pity meter
      rect(x0, py, pw, 5, "rgba(232,229,244,0.1)");
      rect(x0, py, pw * clamp(pity / Math.max(1, D.pityMax), 0, 1), 5, pity >= D.pityMax * 0.75 ? HOT : MAGIC);
      label("pity " + pity + " / " + D.pityMax + " · legendary weight " + D.weights[K - 1] + " + " + pity + "×" + D.pityRamp + " = " + legendaryW().toFixed(1) + (forced ? " · forced ×" + forced : ""), x0, py - 3, MAGIC);
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Dice", "Drops", "a short, steep pity timer — the legendary weight climbs fast and is forced within twenty rolls", { pityMax: 20, pityRamp: 0.6 });

def("H", "Horde", "dice", "a director's curve — intensity over time, peaks and rests — sets the spawn rate; enemies enter off-screen and march on the base — press to spike it", function (u) {
  var D = { period: 12,          // seconds per wave cycle
            peaks: 4,            // bursts per cycle
            peakH: 1,            // the tallest burst
            peakW: 0.55,         // a burst's width, in seconds
            floor: 0.06,         // intensity between bursts — the trickle
            rate: 5,             // spawns per second at intensity 1
            speed: 0.13,         // enemy speed, in widths per second
            spikeH: 1.2, spikeDecay: 1.6,   // what a press adds, and how fast it fades per second
            maxE: 70,
            seed: 9,
            label: "spawns/s = rate × intensity(t) · spawn off-screen · march to the base" };
  const { ctx, W, H, stage, rng, label, line, dot, ring, rect, arrow, mote, len, clamp, rgba, DIM, BONE, HOT, TARGET, MOVER, GOOD } = u;
  // a SPAWN DIRECTOR. the horde is not a list of enemies, it is a CURVE:
  // intensity against time, a few seeded bumps on a low floor, and the
  // director reads it — spawns per second = rate × intensity — so the
  // pressure has PACING: a rush, a breath, a bigger rush. spawn points
  // sit just outside the screen rectangle, so enemies enter rather than
  // appear, and every one of them marches toward the base like the
  // lexicon's Zombies and Invaders. each cycle draws a fresh curve from
  // the next seed; a press adds a spike where the playhead is.
  const gy0 = 14, gh = H * 0.26, sy0 = gy0 + gh + 8, sx0 = W * 0.13, sx1 = W * 0.87, sy1 = H - 20;
  const bx = W / 2, by = sy1 - 12;
  let seed = D.seed, peaks = [], spawners = [], tau = 0, spike = 0, acc = 0, reached = 0, hit = 0, r2 = rng(D.seed + 1);
  const E = [];
  function curve() {
    const r = rng(seed); peaks = []; spawners = [];
    for (let i = 0; i < D.peaks; i++) peaks.push({ c: (i + 0.2 + r() * 0.6) / D.peaks * D.period, h: D.peakH * (0.55 + 0.45 * r()) });
    const m = W * 0.06;
    spawners.push({ x: sx0 - m, y: sy0 + (0.2 + r() * 0.5) * (sy1 - sy0) });
    spawners.push({ x: sx1 + m, y: sy0 + (0.2 + r() * 0.5) * (sy1 - sy0) });
    spawners.push({ x: sx0 + (0.2 + r() * 0.6) * (sx1 - sx0), y: sy0 - m });
  }
  function base(x) {                                   // the seeded curve, wrapped so the cycle joins up
    let v = D.floor;
    for (const p of peaks) { let d = x - p.c; d -= D.period * Math.round(d / D.period); v += p.h * Math.exp(-(d * d) / (D.peakW * D.peakW)); }
    return v;
  }
  curve();
  return {
    press() { spike += D.spikeH; },
    frame(dt, t) {
      stage();
      tau += dt;
      if (tau >= D.period) { tau -= D.period; seed++; curve(); }   // a new wave from the next seed
      spike = Math.max(0, spike - spike * D.spikeDecay * dt);
      hit = Math.max(0, hit - dt * 3);
      const inten = base(tau) + spike;
      acc += inten * D.rate * dt;
      let guard = 0;
      while (acc >= 1 && guard++ < 20) {                // spawn: a seeded point, a nudge, a heading for the base
        acc -= 1;
        const s = spawners[Math.floor(r2() * spawners.length)];
        if (E.length >= D.maxE) E.shift();
        E.push({ x: s.x + (r2() - 0.5) * W * 0.04, y: s.y + (r2() - 0.5) * H * 0.06, w: r2() * 6.28, k: 0.8 + r2() * 0.4 });
      }
      for (let i = E.length - 1; i >= 0; i--) {
        const e = E[i], dx = bx - e.x, dy = by - e.y, d = Math.max(1e-6, len(dx, dy)), v = D.speed * W * e.k * dt;
        e.w += dt * 6;
        e.x += dx / d * v + Math.cos(e.w) * v * 0.3; e.y += dy / d * v + Math.sin(e.w) * v * 0.3;
        if (d < 10) { E.splice(i, 1); reached++; hit = 1; }
      }
      const top = D.peakH * 1.15 + D.floor + 0.6;      // the graph
      const gx = (x) => 8 + x / D.period * (W - 16), gyv = (v) => gy0 + gh - clamp(v / top, 0, 1.4) * gh;
      line(8, gy0 + gh, W - 8, gy0 + gh, DIM);
      ctx.strokeStyle = BONE; ctx.lineWidth = 1.5; ctx.beginPath();
      const n = Math.max(40, Math.floor(W / 3));
      for (let i = 0; i <= n; i++) { const x = i / n * D.period, y = gyv(base(x)); if (i) ctx.lineTo(gx(x), y); else ctx.moveTo(gx(x), y); }
      ctx.stroke();
      line(gx(tau), gy0, gx(tau), gy0 + gh, TARGET, 1);                  // the playhead …
      if (spike > 0.01) line(gx(tau), gyv(base(tau)), gx(tau), gyv(inten), HOT, 3);   // … and the spike on top of the curve
      dot(gx(tau), gyv(inten), 3, spike > 0.01 ? HOT : TARGET);
      label("intensity " + inten.toFixed(2) + " → " + (inten * D.rate).toFixed(1) + " / s", clamp(gx(tau) + 6, 4, W - 110), gy0 + 8, TARGET);
      label("t = " + tau.toFixed(1) + " / " + D.period + " s · wave " + seed, W - 8, gy0 + gh + 10, null, "right");
      ctx.strokeStyle = "rgba(201,196,228,0.35)"; ctx.lineWidth = 1; ctx.setLineDash([4, 3]);   // the screen: what the player sees
      ctx.strokeRect(sx0, sy0, sx1 - sx0, sy1 - sy0);
      ctx.setLineDash([]);
      label("screen", sx0 + 4, sy1 - 4, DIM);
      for (const s of spawners) { ring(s.x, s.y, 5, HOT, 1.2); arrow(s.x, s.y, s.x + (bx - s.x) * 0.12, s.y + (by - s.y) * 0.12, rgba(HOT, 0.6)); }
      for (const e of E) { const a = Math.atan2(by - e.y, bx - e.x); dot(e.x, e.y, 3, HOT); dot(e.x + Math.cos(a) * 3.5, e.y + Math.sin(a) * 3.5, 1.5, HOT); }
      if (hit > 0) ring(bx, by, 10 + (1 - hit) * 14, rgba(HOT, hit), 2);
      mote(bx, by, -Math.PI / 2, MOVER, 7);
      label(E.length + " alive · reached " + reached, sx0 + 4, sy0 + 10, null);
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Horde", "Hush", "two small peaks in a long cycle — most of the time is rest, and the trickle is the tension: a stealth game's pacing", { peaks: 2, peakH: 0.4, period: 20 });

def("S", "Save", "dice", "the state as JSON text (right there in the panel), three slots, a version field and a migration when an old save loads — press to save / load a slot", function (u) {
  var D = { slots: 3,
            version: 2,               // what this build writes
            legacy: { version: 1, x: 8, y: 2, hp: 4, day: 2 },   // an old save already in slot 1: no coins, no pos array
            cols: 12, rows: 7,        // the tiny world
            coins: 7,                 // coins a day
            step: 0.45,               // seconds per world step on autopilot
            autoSave: 3.4,            // seconds between the autopilot's saves
            autoLoad: 8.5,            // seconds between the autopilot's loads
            deleteOnLoad: false,      // the roguelike rule: a loaded save is gone
            scroll: 10,               // json panel scroll, px per second
            run: 30,                  // seconds per run before a new game (next seed)
            seed: 21,
            label: "state → JSON.stringify → slot · load → JSON.parse → migrate(v)" };
  const { ctx, W, H, stage, rng, label, rect, dot, line, mote, clamp, rgba, DIM, BONE, TARGET, GOOD, HOT, MOVER, MAGIC } = u;
  // SAVE & LOAD. the whole game is a plain object — position, hp, coins,
  // the day, which coins are taken — and JSON.stringify turns it into
  // text; that text is the save. loading is JSON.parse and then the
  // careful part: MIGRATION. the save carries a VERSION, and when an old
  // one arrives (slot 1 holds a v1 save with x, y and no coins) the loader
  // fills in what the new build expects — pos = [x, y], coins = 0 — and
  // stamps the new version. ch09 wrote the rules; this card shows the
  // text moving. the world walks on autopilot so the state keeps changing.
  const ww = W * 0.52, wh = H * 0.5, cw = ww / D.cols, ch = wh / D.rows, px0 = ww + 8, pw = W - px0 - 4;
  const slots = [], notes = [];
  let seed = D.seed, r, st, taken, stepT, saveT, loadT, runT, nextSlot, scrollY, lastAct;
  for (let i = 0; i < D.slots; i++) slots.push(null);
  slots[0] = { text: JSON.stringify(D.legacy), v: 1, glow: 0 };
  function coinsOf(s) {                                // the day's coins come from the seed, so a save need not list them
    const rr = rng(s.seed * 31 + s.day), out = [];
    for (let i = 0; i < D.coins; i++) out.push(Math.floor(rr() * D.cols) + Math.floor(rr() * D.rows) * D.cols);
    return out;
  }
  function newGame() {
    r = rng(seed);
    st = { version: D.version, seed: seed, day: 1, hp: 5, coins: 0, pos: [Math.floor(r() * D.cols), Math.floor(r() * D.rows)], taken: [] };
    stepT = 0; saveT = 0; loadT = 0; runT = 0; nextSlot = 1 % D.slots; scrollY = 0; lastAct = "new game · seed " + seed;
  }
  function migrate(s) {                                // an older save, brought up to date one version at a time
    const from = s.version === undefined ? 0 : s.version, fixes = [];
    if (from < 1) { s.version = 1; }
    if (s.version < 2) {
      if (s.pos === undefined) { s.pos = [s.x === undefined ? 0 : s.x, s.y === undefined ? 0 : s.y]; delete s.x; delete s.y; fixes.push("pos = [x, y]"); }
      if (s.coins === undefined) { s.coins = 0; fixes.push("coins = 0"); }
      if (s.taken === undefined) { s.taken = []; fixes.push("taken = []"); }
      if (s.seed === undefined) { s.seed = seed; fixes.push("seed = " + seed); }
      s.version = 2;
    }
    if (typeof s.hp !== "number" || !isFinite(s.hp)) s.hp = 5;
    if (!Array.isArray(s.pos) || s.pos.length !== 2) s.pos = [0, 0];
    s.pos[0] = clamp(s.pos[0] | 0, 0, D.cols - 1); s.pos[1] = clamp(s.pos[1] | 0, 0, D.rows - 1);
    s.day = Math.max(1, s.day | 0); s.coins = Math.max(0, s.coins | 0);
    if (!Array.isArray(s.taken)) s.taken = [];
    return from < D.version ? "migrated v" + from + " → v" + D.version + ": " + fixes.join(", ") : null;
  }
  function save(i) {
    slots[i] = { text: JSON.stringify(st), v: st.version, glow: 1 };
    lastAct = "saved slot " + (i + 1) + " · " + slots[i].text.length + " chars";
    nextSlot = (i + 1) % D.slots;
  }
  function load(i) {
    const s = slots[i]; if (!s) return;
    let obj;
    try { obj = JSON.parse(s.text); } catch (e) { obj = {}; }
    const note = migrate(obj);
    st = obj; s.glow = -1;
    lastAct = "loaded slot " + (i + 1) + (note ? " · " + note : " · v" + D.version + ", nothing to migrate");
    if (note) notes.push({ txt: note, t: 3 });
    if (D.deleteOnLoad) { slots[i] = null; lastAct += " · slot deleted"; }
  }
  function worldStep() {                               // autopilot: walk to the nearest coin left today
    const coins = coinsOf(st);
    let bi = -1, bd = 1e9;
    for (let i = 0; i < coins.length; i++) {
      if (st.taken.indexOf(i) >= 0) continue;
      const cx = coins[i] % D.cols, cy = (coins[i] - cx) / D.cols, d = Math.abs(cx - st.pos[0]) + Math.abs(cy - st.pos[1]);
      if (d < bd) { bd = d; bi = i; }
    }
    if (bi < 0) { st.day++; st.taken = []; st.hp = Math.min(5, st.hp + 1); return; }   // all taken: a new day, new coins
    const cx = coins[bi] % D.cols, cy = (coins[bi] - cx) / D.cols;
    if (cx !== st.pos[0]) st.pos[0] += cx > st.pos[0] ? 1 : -1; else if (cy !== st.pos[1]) st.pos[1] += cy > st.pos[1] ? 1 : -1;
    if (st.pos[0] === cx && st.pos[1] === cy) { st.taken.push(bi); st.coins++; if (r() < 0.25) st.hp = Math.max(1, st.hp - 1); }
  }
  newGame();
  return {
    press(x, y) {
      const sw = ww / D.slots, sy = wh + 14;
      if (y > sy && y < sy + 26 && x < ww) { const i = clamp(Math.floor(x / sw), 0, D.slots - 1); if (slots[i]) load(i); else save(i); }
      else save(nextSlot);
    },
    frame(dt, t) {
      stage();
      if ((stepT += dt) >= D.step) { stepT = 0; worldStep(); }
      if ((saveT += dt) >= D.autoSave) { saveT = 0; save(nextSlot); }
      if ((loadT += dt) >= D.autoLoad) {               // the autopilot loads a filled slot now and then
        loadT = 0;
        for (let k = 0; k < D.slots; k++) { const i = (nextSlot + k) % D.slots; if (slots[i]) { load(i); break; } }
      }
      if ((runT += dt) >= D.run) { seed++; newGame(); }
      for (const n of notes) n.t -= dt;
      while (notes.length && notes[0].t <= 0) notes.shift();
      const coins = coinsOf(st);                       // the tiny world
      ctx.strokeStyle = "rgba(150,145,190,0.18)"; ctx.lineWidth = 1; ctx.strokeRect(0.5, 0.5, ww - 1, wh - 1);
      for (let i = 0; i < coins.length; i++) if (st.taken.indexOf(i) < 0) { const cx = coins[i] % D.cols; dot((cx + 0.5) * cw, ((coins[i] - cx) / D.cols + 0.5) * ch, Math.min(cw, ch) * 0.22, TARGET); }
      mote((st.pos[0] + 0.5) * cw, (st.pos[1] + 0.5) * ch, 0, undefined, Math.min(cw, ch) * 0.36);
      for (let i = 0; i < 5; i++) dot(6 + i * 8, wh - 7, 2.5, i < st.hp ? HOT : "rgba(245,138,138,0.2)");
      label("day " + st.day + " · coins " + st.coins, ww - 4, wh - 4, null, "right");
      const sw = ww / D.slots, sy = wh + 14;           // the slots
      for (let i = 0; i < D.slots; i++) {
        const s = slots[i], x = i * sw + 2;
        if (s) s.glow = s.glow > 0 ? Math.max(0, s.glow - dt * 1.5) : Math.min(0, s.glow + dt * 1.5);
        rect(x, sy, sw - 4, 26, s ? (s.glow > 0 ? rgba(GOOD, 0.15 + s.glow * 0.4) : s.glow < 0 ? rgba(MOVER, 0.15 - s.glow * 0.4) : "rgba(232,229,244,0.08)") : "rgba(0,0,0,0.25)");
        label("slot " + (i + 1) + (s ? " · v" + s.v : ""), x + 4, sy + 11, s ? (s.v < D.version ? TARGET : BONE) : DIM);
        label(s ? (s.v < D.version ? "old format" : s.text.length + " chars") : "empty", x + 4, sy + 22, DIM);
      }
      label(lastAct, 4, sy + 38, null);
      rect(px0, 0, pw, H - 18, "rgba(0,0,0,0.3)");     // the json panel, the actual text, scrolling
      const fs = clamp(W * 0.034, 8, 12), lh = fs + 2, lines = JSON.stringify(st, null, 1).split("\n");
      const span = lines.length * lh + lh * 2;
      scrollY = (scrollY + D.scroll * dt) % span;
      ctx.save(); ctx.beginPath(); ctx.rect(px0, 0, pw, H - 18); ctx.clip();
      ctx.font = fs + "px ui-monospace, Consolas, monospace";
      for (let k = -1; k <= 1; k++) for (let i = 0; i < lines.length; i++) {
        const y = 12 + i * lh - scrollY + k * span;
        if (y < -lh || y > H) continue;
        ctx.fillStyle = lines[i].indexOf('"version"') >= 0 ? TARGET : lines[i].indexOf('"coins"') >= 0 || lines[i].indexOf('"pos"') >= 0 ? GOOD : "rgba(232,229,244,0.75)";
        ctx.fillText(lines[i].slice(0, Math.floor(pw / (fs * 0.6))), px0 + 4, y);
      }
      ctx.restore();
      for (let i = 0; i < notes.length; i++) label(notes[i].txt, W / 2, H / 2 + i * 12, rgba(MAGIC, Math.min(1, notes[i].t)), "center");
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Save", "Suspend", "one slot, and it is deleted the moment it is loaded — the roguelike's suspend rule: no scumming", { slots: 1, deleteOnLoad: true });

def("S", "Seed", "dice", "one seed reproduces the whole map — same seed, identical panels; seed + 1, another world; the rng's first numbers shown — press for the next seed", function (u) {
  var D = { seed: 4477,
            offsets: [0, 0, 1],          // each panel's seed, relative to the typed one: same, same, next
            cols: 14, rows: 9,
            scale: 0.38,                 // noise zoom
            sea: -0.15, grass: 0.25, wood: 0.55,   // height bands
            houses: 3,
            perBeat: 6, beat: 0.03,      // cells revealed per beat, in reading order
            typeBeat: 0.08,              // seconds per typed character
            rest: 3,
            label: "rng(seed) → the same numbers → the same world, on every machine" };
  const { ctx, W, H, stage, rng, noise2, label, rect, dot, clamp, DIM, BONE, TARGET, GOOD, HOT } = u;
  // a SEEDED WORLD. rng(seed) is mulberry32: a few shifts and multiplies
  // on one 32-bit number, and the sequence it spits out is the same on
  // every machine that starts from the same seed (ch01). feed every
  // choice the generator makes — where the noise is read from, where the
  // houses go — from that one stream and the whole world is one number
  // long: "try seed 4477" is the entire map. the first panels share a
  // seed, so they match to the cell; the last one is off by one, and
  // nothing matches. the four decimals under each are the stream itself.
  const P = D.offsets.length, gap = 6, pw = (W - gap * (P + 1)) / P, ph = Math.min(pw * D.rows / D.cols, H * 0.5), cw = pw / D.cols, ch = ph / D.rows;
  const py0 = 30, N = D.cols * D.rows;
  let seed = D.seed, worlds = [], typed = 0, shown = 0, acc = 0, restT = 0, text = "";
  function world(s) {                                  // everything about a panel comes from rng(s)
    const r = rng(s), first = [r(), r(), r(), r()], ox = first[0] * 100, oy = first[1] * 100, cells = new Uint8Array(N), houses = [];
    for (let y = 0; y < D.rows; y++) for (let x = 0; x < D.cols; x++) {
      const v = noise2(x * D.scale + ox, y * D.scale + oy);
      cells[y * D.cols + x] = v < D.sea ? 0 : v < D.grass ? 1 : v < D.wood ? 2 : 3;
    }
    for (let i = 0; i < D.houses; i++) { const c = Math.floor(r() * N); if (cells[c] === 1) houses.push(c); }
    return { seed: s, first: first, cells: cells, houses: houses };
  }
  function grow() { worlds = []; for (const o of D.offsets) worlds.push(world(seed + o)); text = "try seed " + seed; typed = 0; shown = 0; acc = 0; restT = 0; }
  grow();
  const COL = ["#3A6FB5", "#6FAF5E", "#3E7A3A", "#8C8698"];
  return {
    press() { seed++; grow(); },
    frame(dt, t) {
      stage();
      if (typed < text.length) { if ((acc += dt) >= D.typeBeat) { acc = 0; typed++; } }
      else if (shown < N) {
        acc += dt;
        let guard = 0;
        while (acc >= D.beat && shown < N && guard++ < 30) { acc -= D.beat; shown = Math.min(N, shown + D.perBeat); }
      } else if ((restT += dt) > D.rest) { seed++; grow(); }
      ctx.font = "bold 12px ui-monospace, Consolas, monospace"; ctx.fillStyle = TARGET;   // the seed, typed
      ctx.fillText(text.slice(0, typed) + (typed < text.length && Math.floor(t * 4) % 2 ? "▍" : ""), gap, 16);
      const fs = clamp(pw * 0.06, 7, 10), nums = pw > 150 ? 4 : 2;
      for (let p = 0; p < P; p++) {
        const w = worlds[p], x0 = gap + p * (pw + gap);
        rect(x0, py0, pw, ph, "rgba(0,0,0,0.25)");
        for (let c = 0; c < shown; c++) { const x = c % D.cols; rect(x0 + x * cw, py0 + ((c - x) / D.cols) * ch, cw + 0.5, ch + 0.5, COL[w.cells[c]]); }
        for (const hc of w.houses) if (hc < shown) { const x = hc % D.cols; dot(x0 + (x + 0.5) * cw, py0 + ((hc - x) / D.cols + 0.5) * ch, Math.min(cw, ch) * 0.3, BONE); }
        const same = p > 0 && D.offsets[p] === D.offsets[p - 1];
        label("seed " + w.seed + (same ? " again" : ""), x0 + pw / 2, py0 + ph + 11, typed >= text.length ? BONE : DIM, "center");
        ctx.font = fs + "px ui-monospace, Consolas, monospace"; ctx.fillStyle = "rgba(232,229,244,0.5)"; ctx.textAlign = "center";
        ctx.fillText(w.first.slice(0, nums).map((v) => v.toFixed(4)).join(" ") + " …", x0 + pw / 2, py0 + ph + 22);
        ctx.textAlign = "left";
        if (p > 0) {                                   // between the panels: the verdict
          const cellsSame = worlds[p].cells.every((v, i) => v === worlds[p - 1].cells[i]);
          label(cellsSame ? "=" : "≠", x0 - gap / 2, py0 + ph / 2 + 5, cellsSame ? GOOD : HOT, "center");
        }
      }
      label(shown < N && typed >= text.length ? "building " + shown + " / " + N : shown >= N ? "same seed, same map — off by one, another world" : "", W - gap, 16, null, "right");
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Seed", "Sibling", "three consecutive seeds side by side — neighbours in number, strangers on the map", { offsets: [0, 1, 2] });
/* ============================== the page runner ============================== */

var grid = document.getElementById("workshop");
var statusEl = document.getElementById("status");
var runAllBtn = document.getElementById("runall");
var stopAllBtn = document.getElementById("stopall");
var cards = [];

function buildCard(effect) {
  var card = document.createElement("div");
  card.className = "bcard";
  var canvas = document.createElement("canvas");
  canvas.title = effect.letter + " · " + effect.name + " — click to wake it; click again to poke it";
  card.appendChild(canvas);
  var meta = document.createElement("div");
  meta.className = "meta";
  var b = document.createElement("b");
  var links = document.createElement("span");
  var r = document.createElement("a");
  r.href = "javascript:void(0)";
  r.className = "rhyme";
  var a = document.createElement("a");
  a.href = "#editor";
  a.textContent = "open code ⤵";
  links.appendChild(r);
  links.appendChild(document.createTextNode(" · "));
  links.appendChild(a);
  meta.appendChild(b);
  meta.appendChild(links);
  card.appendChild(meta);
  var hint = document.createElement("p");
  hint.className = "bhint";
  card.appendChild(hint);

  var st = { effect: effect, canvas: canvas, u: null, inst: null, running: false, elapsed: 0, visible: true, useRhyme: false, pressed: false, down: false };
  st.refresh = function () {
    var v = variantOf(st);
    b.textContent = effect.letter + " · " + v.name;
    hint.textContent = v.hint;
    r.textContent = st.useRhyme ? "⇄ the original" : "⇄ its rhyme";
    r.style.display = effect.rhyme ? "" : "none";
  };
  st.refresh();
  cards.push(st);
  canvas.__st = st;

  r.addEventListener("click", function () {
    st.useRhyme = !st.useRhyme && !!effect.rhyme;
    st.refresh();
    startCard(st);                                     // seeing the change at once IS the lesson
  });
  a.addEventListener("click", function () { openInEditor(effect, st.useRhyme); });
  function pressAt(e) {
    var rect = canvas.getBoundingClientRect();
    var mx = e.clientX - rect.left, my = e.clientY - rect.top;
    if (st.inst && st.inst.press) {
      try { st.inst.press(mx, my); } catch (err) { failCard(st, err); }
    }
  }
  canvas.addEventListener("pointerdown", function (e) {
    if (!st.running) startCard(st);
    st.pressed = true;                                 // the hint badge has done its job
    st.down = true;
    pressAt(e);
  });
  canvas.addEventListener("pointermove", function (e) {   // drag = an invisible slider,
    if (st.down && st.inst && st.inst.drag) pressAt(e);    // for cards whose press is continuous
  });
  ["pointerup", "pointercancel", "pointerleave"].forEach(function (ev) {
    canvas.addEventListener(ev, function () { st.down = false; });
  });
  return card;
}

/* a small pulsing badge, top-right, until the card has been touched once —
   so nobody has to guess that a motion can be poked or dragged */
function badge(u, drag, t) {
  var c = u.ctx, txt = drag ? "← drag →" : "click ✦";
  c.save();
  c.globalCompositeOperation = "source-over";
  c.globalAlpha = 0.6 + 0.3 * Math.sin(t * 3);
  c.font = "11px system-ui, sans-serif";
  var w = c.measureText(txt).width + 14, x = u.W - w - 8, y = 8;
  c.fillStyle = "rgba(10,8,20,0.7)";
  c.beginPath();
  if (c.roundRect) c.roundRect(x, y, w, 18, 9); else c.rect(x, y, w, 18);
  c.fill();
  c.fillStyle = "#F5C169";
  c.textAlign = "center"; c.textBaseline = "middle";
  c.fillText(txt, x + w / 2, y + 9.5);
  c.restore();
  c.textAlign = "left"; c.textBaseline = "alphabetic";
}

function placeholder(st) {
  var u = apiFor(st.canvas);
  u.stage();
  u.ctx.fillStyle = "rgba(232,229,244,0.14)";
  u.ctx.font = "700 " + Math.round(u.H * 0.5) + "px 'Spline Sans Mono', Consolas, monospace";
  u.ctx.textAlign = "center";
  u.ctx.textBaseline = "middle";
  u.ctx.fillText(st.effect.letter, u.W / 2, u.H * 0.56);
  u.ctx.fillStyle = "rgba(230,227,242,0.55)";
  u.ctx.font = "12px system-ui, sans-serif";
  u.ctx.textBaseline = "alphabetic";
  u.ctx.fillText("▶ click to wake", u.W / 2, u.H * 0.16);
  u.ctx.textAlign = "left";
}

function startCard(st) {
  var u = apiFor(st.canvas);
  st.u = u;
  try { st.inst = makeOf(variantOf(st))(u); } catch (err) { failCard(st, err); return; }
  st.elapsed = 0;
  st.running = true;
  ensureLoop();
  updateStatus();
}

function failCard(st, err) {
  st.running = false;
  st.inst = null;
  var u = apiFor(st.canvas);
  u.ctx.fillStyle = "#131020";
  u.ctx.fillRect(0, 0, u.W, u.H);
  u.ctx.fillStyle = "#D6A878";
  u.ctx.font = "12px system-ui, sans-serif";
  u.ctx.textAlign = "center";
  u.ctx.fillText("⚠ " + err.message, u.W / 2, u.H / 2);
  u.ctx.textAlign = "left";
  if (window.console) console.error("[" + st.effect.name + "]", err);
  updateStatus();
}

function restCard(st) {
  st.running = false;
  var c = st.u.ctx;
  c.globalCompositeOperation = "source-over";
  c.globalAlpha = 1;
  c.setLineDash([]);
  c.lineWidth = 1;
  c.fillStyle = "rgba(19,16,32,0.6)";
  c.fillRect(0, 0, st.u.W, st.u.H);
  c.fillStyle = "rgba(230,227,242,0.8)";
  c.font = "12px system-ui, sans-serif";
  c.textAlign = "center";
  c.textBaseline = "middle";
  c.fillText("resting — click to wake again", st.u.W / 2, st.u.H / 2);
  c.textAlign = "left";
  c.textBaseline = "alphabetic";
  updateStatus();
}

var rafId = null, lastTs = null, lastCount = -1;
var tempo = 1;   // the page-wide time-lapse dial (×1 / ×2 / ×4): extra SUBSTEPS per frame, so
                 // springs and verlet piles stay stable — the same lesson S·Substep teaches

function ensureLoop() {
  if (rafId === null) { lastTs = null; rafId = requestAnimationFrame(tick); }
}

function stepCard(st, dt) {
  var c = st.u.ctx;
  for (var k = 0; k < tempo; k++) {
    st.elapsed += dt;
    c.globalCompositeOperation = "source-over";        // every frame starts clean,
    c.globalAlpha = 1;                                 // whatever the last one left
    c.setLineDash([]);
    st.inst.frame(dt, st.elapsed);
  }
}

function tick(ts) {
  var dt = lastTs === null ? 0.016 : Math.min(0.05, (ts - lastTs) / 1000);
  lastTs = ts;
  var any = false;
  for (var i = 0; i < cards.length; i++) {
    var st = cards[i];
    if (!st.running) continue;
    any = true;
    if (!st.visible) continue;
    try { stepCard(st, dt); } catch (err) { failCard(st, err); continue; }
    if (!st.pressed) badge(st.u, !!st.inst.drag, st.elapsed);
    if (st.elapsed > 60 * tempo) restCard(st);
  }
  if (any) rafId = requestAnimationFrame(tick);
  else { rafId = null; updateStatus(); }
}

function updateStatus() {
  var n = 0;
  for (var i = 0; i < cards.length; i++) if (cards[i].running) n++;
  if (n !== lastCount) {
    lastCount = n;
    statusEl.textContent = n === 0 ? "" : n + " of " + cards.length + " worlds awake";
  }
}

runAllBtn.addEventListener("click", function () {
  for (var i = 0; i < cards.length; i++) startCard(cards[i]);
});
stopAllBtn.addEventListener("click", function () {
  for (var i = 0; i < cards.length; i++) cards[i].running = false;
  updateStatus();
});
[1, 2, 4].forEach(function (k) {                       // tempo buttons: a time-lapse for skimming
  var btn = document.getElementById("tempo" + k);
  if (!btn) return;
  btn.addEventListener("click", function () {
    tempo = k;
    [1, 2, 4].forEach(function (j) { var b2 = document.getElementById("tempo" + j); if (b2) b2.classList.toggle("primary", j === k); });
  });
});

var io = null;
if ("IntersectionObserver" in window) {
  io = new IntersectionObserver(function (entries) {
    for (var i = 0; i < entries.length; i++)
      entries[i].target.__st.visible = entries[i].isIntersecting;
  }, { rootMargin: "120px" });
}

FAMILY_ORDER.forEach(function (fam) {
  var list = EFFECTS.filter(function (e) { return e.tag === fam[0]; });
  if (!list.length) return;
  var h = document.createElement("h2");
  h.className = "family";
  h.textContent = fam[1] + " ";
  var small = document.createElement("small");
  small.textContent = list.length + " worlds (+" + list.filter(function (e) { return e.rhyme; }).length + " rhymes) — " + fam[2];
  h.appendChild(small);
  grid.appendChild(h);
  var wrap = document.createElement("div");
  wrap.className = "bcards";
  grid.appendChild(wrap);
  list.forEach(function (effect) {
    wrap.appendChild(buildCard(effect));
  });
});

cards.forEach(function (st) {
  placeholder(st);
  if (io) io.observe(st.canvas);
});

/* ============================== the editor ============================== */

var codeBox = document.getElementById("code");
var runBtn = document.getElementById("run");
var stopBtn = document.getElementById("stop");
var resetBtn = document.getElementById("reset");
var errBox = document.getElementById("err");
var cv = document.getElementById("cv");
var edname = document.getElementById("edname");
var current = { effect: EFFECTS[0], useRhyme: false };
var pv = { inst: null, raf: null, elapsed: 0, u: null, pressed: false, down: false };

function dedent(src) {
  var lines = src.split("\n");
  var min = Infinity;
  for (var i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue;
    var n = lines[i].match(/^\s*/)[0].length;
    if (n < min) min = n;
  }
  if (!isFinite(min) || min === 0) return src;
  for (var j = 1; j < lines.length; j++) lines[j] = lines[j].slice(min);
  return lines.join("\n");
}

function previewHint() {
  var u = apiFor(cv);
  u.stage();
  u.ctx.fillStyle = "rgba(232,229,244,0.12)";
  u.ctx.font = "700 " + Math.round(u.H * 0.45) + "px 'Spline Sans Mono', Consolas, monospace";
  u.ctx.textAlign = "center";
  u.ctx.textBaseline = "middle";
  u.ctx.fillText(current.effect.letter, u.W / 2, u.H * 0.56);
  u.ctx.fillStyle = "rgba(230,227,242,0.6)";
  u.ctx.font = "15px system-ui, sans-serif";
  u.ctx.textBaseline = "alphabetic";
  u.ctx.fillText("Press ▶ Run — nothing moves until you do.", u.W / 2, u.H * 0.14);
  u.ctx.textAlign = "left";
}

function openInEditor(effect, useRhyme) {
  current = { effect: effect, useRhyme: !!(useRhyme && effect.rhyme) };
  var v = current.useRhyme ? effect.rhyme : effect;
  edname.textContent = current.useRhyme
    ? effect.letter + " · " + v.name + " — a rhyme of " + effect.name + " — " + v.hint
    : effect.letter + " · " + v.name + " — " + v.hint;
  var src;
  try { src = sourceOf(v); } catch (e) { src = "// " + e.message; }
  codeBox.value = dedent(src);
  stopPreview();
  errBox.textContent = "";
  previewHint();
}

function stopPreview() {
  if (pv.raf) cancelAnimationFrame(pv.raf);
  pv.raf = null;
  pv.inst = null;
}

function runPreview() {
  stopPreview();
  errBox.textContent = "";
  var makeFn;
  try { makeFn = new Function("return (" + codeBox.value + "\n)")(); }
  catch (e) { errBox.textContent = "The code hit a snag (totally fixable): " + e.message; return; }
  if (typeof makeFn !== "function") {
    errBox.textContent = "The code should be a single  function (u) { … }  expression.";
    return;
  }
  var u = apiFor(cv), inst;
  try { inst = makeFn(u); } catch (e) {
    errBox.textContent = "The code hit a snag (totally fixable): " + e.message;
    return;
  }
  if (!inst || typeof inst.frame !== "function") {
    errBox.textContent = "make(u) should return an object with a frame(dt, t) method.";
    return;
  }
  pv.inst = inst;
  pv.u = u;
  pv.elapsed = 0;
  pv.pressed = false;
  var last = null;
  function step(ts) {
    if (last === null) last = ts;
    var dt = Math.min(0.05, (ts - last) / 1000);
    last = ts;
    try {
      for (var k = 0; k < tempo; k++) {
        pv.elapsed += dt;
        u.ctx.globalCompositeOperation = "source-over";
        u.ctx.globalAlpha = 1;
        u.ctx.setLineDash([]);
        pv.inst.frame(dt, pv.elapsed);
      }
    } catch (e) { errBox.textContent = "The code hit a snag mid-frame: " + e.message; stopPreview(); return; }
    if (!pv.pressed) badge(u, !!pv.inst.drag, pv.elapsed);
    if (pv.elapsed < 60 * tempo) pv.raf = requestAnimationFrame(step);
    else pv.raf = null;
  }
  pv.raf = requestAnimationFrame(step);
}

runBtn.addEventListener("click", runPreview);
stopBtn.addEventListener("click", stopPreview);
resetBtn.addEventListener("click", function () {
  stopPreview();
  openInEditor(current.effect, current.useRhyme);
});
function previewPress(e) {
  if (!pv.inst || !pv.inst.press) return;
  var r = cv.getBoundingClientRect();
  try { pv.inst.press(e.clientX - r.left, e.clientY - r.top); }
  catch (err) { errBox.textContent = "The press handler hit a snag: " + err.message; }
}
cv.addEventListener("pointerdown", function (e) { pv.pressed = true; pv.down = true; previewPress(e); });
cv.addEventListener("pointermove", function (e) { if (pv.down && pv.inst && pv.inst.drag) previewPress(e); });
["pointerup", "pointercancel", "pointerleave"].forEach(function (ev) { cv.addEventListener(ev, function () { pv.down = false; }); });

openInEditor(EFFECTS[0], false);

/* expose a tiny hook for the automated smoke test (harmless in normal use) */
window.__workshop = { EFFECTS: EFFECTS, apiFor: apiFor, cards: cards, makeOf: makeOf, sourceOf: sourceOf };
})();
