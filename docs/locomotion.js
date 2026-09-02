/* Sparks & Sprites — the locomotion lexicon.
   One little blue mote and 104 ways for it to move — an A-to-Z, four times
   over, of the maths behind procedural animation: the fourth gallery after
   the elemental button bestiary, the cube codex, and the glyph grimoire. If
   the grimoire was what a phrase can DO, the lexicon is what a body can
   KNOW: sines and circles, springs and slopes, headings and vehicles,
   steering brains, crowds and fields, paths and schedules, joint chains,
   honest physics — and the clock and the camera themselves.

   Laps one and two teach machinery (one concept per card); laps three and
   four are GENRE laps — sci-fi, adventure, action, fantasy, arcade, cozy,
   minimalist, glitchy, goofy — a picture-book to skim until you recognise
   the motion you were imagining. Every card also hides a RHYME: the same
   motion with two or three dials turned, and nothing else — so the page
   holds 208 movement styles.

   Every demo is one function make(u) that returns { frame(dt, t), press(x, y) }
   — plus drag: true when press is continuous (the runtime then repeats the
   press while the pointer is held). Its dials sit at the top in a
   D = { … } object; a rhyme is that object with a few values swapped.
   The kit u:
     ctx, W, H     — the 2D context and canvas size (CSS pixels)
     GY            — the standard ground line's y (H · 0.78)
     MOVER         — the mote's blue      #8AD9F5   (the protagonist)
     TARGET        — "where it wants to be" amber   #F5C169
     BONE          — limbs and joints     #C9C4E4
     GOOD          — helpers, friends     #9BE28A
     HOT           — impulses, lasers     #F58A8A
     MAGIC         — spells, ghosts       #C9A0F5
     INK, DIM      — plain light, and its faded cousin
     stage()       — clears the canvas: night backdrop + faint graph paper
     ground(y?)    — a floor line with hatching (defaults to GY)
     dot(x,y,r,c)  — a filled circle
     ring(x,y,r,c,w?) — a stroked circle
     line(x1,y1,x2,y2,c,w?) — a plain stroke
     rect(x,y,w,h,c) — a filled rectangle
     poly(pts,c,stroke?) — a filled polygon from [[x,y],…] (stroke: outline only)
     arrow(x1,y1,x2,y2,c) — a vector, drawn honestly (line + head)
     mote(x,y,ang,c?,s?)  — the protagonist: a round body, a nose showing
                     its heading, one attentive eye
     label(txt,x,y,c?,align?) — a small annotation
     len(x,y)      — √(x²+y²), the length of a vector
     clamp(v,a,b), lerp(a,b,k), ease(k) — the usual suspects (ease = smoothstep)
     smooth(rate,dt) — the framerate-proof lerp factor 1 − exp(−rate·dt)
     wrapAngle(a)  — fold any angle into −π..π (for shortest-turn maths)
     rand(a,b), rng(seed) — random, and seeded random (mulberry32: the
                     same seed gives the same numbers on every machine)
     noise(x)      — smooth 1-D value noise in −1..1 (Perlin's little cousin)
     TAU

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
           smooth: smooth, wrapAngle: wrapAngle,
           stage: stage, ground: ground, dot: dot, ring: ring, line: line, rect: rect, poly: poly,
           arrow: arrow, mote: mote, label: label };
}

var FAMILY_ORDER = [
  ["clocks", "Clocks & circles", "position is a formula of time — sine, polar, phase, nested frames: motion with no memory"],
  ["springs", "Slopes & springs", "a velocity, and something bending it — lerp, damping ratios, gravity, drag: calculus wearing gym clothes"],
  ["headings", "Headings & vehicles", "a body that remembers an angle — turn rates, look-at, thrust, wheels, banking: everything that steers like a vehicle"],
  ["steer", "Brains & steering", "a velocity plus an intention — seek, flee, pursue, wander, avoid, state machines: how enemies decide"],
  ["crowds", "Crowds & fields", "many bodies, one rule each — magnets, flow fields, flocks, herds, formations, crossings"],
  ["paths", "Paths, grids & schedules", "a route remembered — A*, Béziers, splines, lanes, hops, timetables"],
  ["chains", "Chains & joints", "a list of joints — follow-chains, two-bone IK, FABRIK, quaternions, and the creatures built from them"],
  ["bodies", "Bodies & ground", "position and last position — verlet, impulses, rays, normals, ropes, and the walk that uses it all"],
  ["time", "Time & cameras", "the clock and the window move too — timescale, hitstop, substeps, lag, quantised frames, a following camera"]
];

/* ============================== CLOCKS & CIRCLES ==============================
   Motion with NO memory: every frame, position is computed straight from the
   clock. x(t) and y(t) are formulas — nothing is remembered, nothing can
   drift, and the loop can run for a year without a bug. These are the maths
   of hovering pickups, orbiting shields, figure-eight patrols, and every
   snake that ever swam across a title screen — and, in the genre laps, of
   bullet spirals, blinking saucers, clockwork solar systems, kaleidoscopes,
   a character breathing in place, and a boat that reads the wave's slope. */

def("H", "Hover", "clocks", "y = sin(t) is a whole idle animation — press to excite it", function (u) {
  var D = { period: 2.8,        // seconds per bob
            amp: 0.075,         // bob height, as a fraction of H
            tilt: 0.16,         // how far the body leans on the slope
            rest: 0.32,         // hover height above the ground, of H
            exciteAmp: 1.5,     // what a press adds to the height...
            exciteSpeed: 0.4,   // ...and takes off the period
            decay: 0.45 };      // how fast the excitement fades, per second
  const { ctx, W, H, GY, TAU, stage, ground, mote, label } = u;
  // the entire behaviour is ONE line of maths: y = rest + sin(t·2π/period)·amp.
  // the rest is presentation: the tilt is the curve's SLOPE (its derivative,
  // cos), and the shadow shrinks as the body rises — altitude for free.
  let excite = 0;
  return {
    press() { excite = 1; },
    frame(dt, t) {
      stage(); ground();
      excite = Math.max(0, excite - dt * D.decay);
      const amp = H * D.amp * (1 + excite * D.exciteAmp);
      const w = TAU / (D.period * (1 - excite * D.exciteSpeed));   // excited = faster AND higher
      const rest = GY - H * D.rest;
      const y = rest + Math.sin(t * w) * amp;
      const tilt = Math.cos(t * w) * D.tilt;           // the derivative leans the body
      const alt = (GY - y) / (GY - rest + amp);        // 0-ish at the floor, ~1 up high
      ctx.fillStyle = "rgba(0,0,0,0.4)";
      ctx.beginPath();
      ctx.ellipse(W / 2, GY - 3, 17 * (1.3 - alt * 0.55), 4, 0, 0, TAU);
      ctx.fill();
      mote(W / 2, y, tilt);
      label("y = rest + sin(t · 2π/" + D.period + ") · amp", W / 2, GY + 18, null, "center");
    }
  };
});
rhymeOf("Hover", "Heartbeat", "the same sine at a third of the period and twice the amplitude — a pulse instead of a float", { period: 0.9, amp: 0.15 });

def("O", "Orbit", "clocks", "polar coordinates: one angle + one radius = a flight plan — press to reverse", function (u) {
  var D = { speed: 1.1,         // radians per second around the sun
            moonSpeed: 4.6,     // the moon's own, faster clock
            radius: 0.3,        // orbit radius, of min(W, H)
            breathe: 6,         // px the radius swells and shrinks by
            moonR: 19 };        // the moon's distance from the mote, px
  const { ctx, W, H, TAU, stage, dot, ring, mote, label, TARGET, GOOD, DIM } = u;
  // polar coordinates name a point by (angle θ, radius r) instead of (x, y).
  // the conversion — x = cos(θ)·r, y = sin(θ)·r — is the bridge every orbit,
  // radar sweep, and joint chain crosses. the moon shows frames NESTING:
  // it orbits the mote exactly the way the mote orbits the sun.
  let th = 0, mth = 0, dir = 1;
  return {
    press() { dir = -dir; },
    frame(dt, t) {
      stage();
      const cx = W / 2, cy = H * 0.52;
      const r = Math.min(W, H) * D.radius + Math.sin(t * 0.7) * D.breathe;   // r can breathe too
      th += dt * D.speed * dir;
      mth += dt * D.moonSpeed * dir;                    // the moon runs its own, faster clock
      const x = cx + Math.cos(th) * r;                  // ← polar → Cartesian,
      const y = cy + Math.sin(th) * r;                  //   the whole trick
      ring(cx, cy, r, "rgba(232,229,244,0.10)");
      dot(cx, cy, 7, TARGET);
      ctx.strokeStyle = DIM;
      ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(x, y); ctx.stroke();
      ctx.strokeStyle = "rgba(245,193,105,0.7)";        // the angle, drawn as an arc
      ctx.beginPath(); ctx.arc(cx, cy, 16, 0, th, dir < 0); ctx.stroke();
      label("θ", cx + 24, cy - 6, "rgba(245,193,105,0.8)");
      label("r", cx + (x - cx) * 0.55 + 6, cy + (y - cy) * 0.55, null);
      mote(x, y, th + dir * Math.PI / 2);               // heading = tangent to the circle
      dot(x + Math.cos(mth) * D.moonR, y + Math.sin(mth) * D.moonR, 3.5, GOOD);
      label("x = cos(θ)·r   y = sin(θ)·r", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Orbit", "Outrider", "a slow, stately planet with a frantic escort far out on its arm — the moon's clock outruns the mote's seven times over", { speed: 0.4, moonSpeed: 7.5, moonR: 32 });

def("E", "Eight", "clocks", "two sines at different speeds trace a figure eight — press for a new ratio", function (u) {
  var D = { ratios: [[1, 2], [3, 2], [3, 4], [2, 1]],   // the (a, b) pairs a press cycles through
            rx: 0.33, ry: 0.3,  // the knot's width and height, of W and H
            spd: 1.3,           // how fast t runs through the curve
            trail: 60 };        // frames of trail behind the mote
  const { ctx, W, H, TAU, stage, dot, mote, arrow, label, GOOD, DIM } = u;
  // a Lissajous curve: x follows cos(a·t), y follows sin(b·t). when a and b
  // are small whole numbers the path closes into a knot — 1:2 is the figure
  // eight. bosses fly these because they look deliberate and cost nothing.
  let ri = 0;
  let trail = [];
  return {
    press() { ri = (ri + 1) % D.ratios.length; trail = []; },
    frame(dt, t) {
      stage();
      const a = D.ratios[ri][0], b = D.ratios[ri][1];
      const cx = W / 2, cy = H * 0.5, rx = W * D.rx, ry = H * D.ry, spd = D.spd;
      ctx.strokeStyle = "rgba(232,229,244,0.12)";       // the whole path, previewed
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let i = 0; i <= 128; i++) {
        const s = (i / 128) * TAU;
        const px = cx + Math.cos(a * s) * rx, py = cy + Math.sin(b * s) * ry;
        if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
      }
      ctx.stroke();
      const T = t * spd;
      const x = cx + Math.cos(a * T) * rx;
      const y = cy + Math.sin(b * T) * ry;
      const vx = -Math.sin(a * T) * a * rx * spd;       // the velocity is the
      const vy = Math.cos(b * T) * b * ry * spd;        // derivative, letter for letter
      trail.push([x, y]);
      if (trail.length > D.trail) trail.shift();
      for (let i = 0; i < trail.length; i++)
        dot(trail[i][0], trail[i][1], 1.6, "rgba(138,217,245," + (i / trail.length * 0.35) + ")");
      arrow(x, y, x + vx * 0.22, y + vy * 0.22, GOOD);
      mote(x, y, Math.atan2(vy, vx));
      label("x = cos(" + a + "t)   y = sin(" + b + "t)", W / 2, 16, null, "center");
      label("the arrow is the derivative (velocity)", W / 2, H - 8, "rgba(155,226,138,0.6)", "center");
    }
  };
});
rhymeOf("Eight", "Embroidery", "bigger whole-number ratios, faster, with a long trail — the same two sines stitch dense knots instead of an eight", { ratios: [[5, 4], [5, 6], [7, 5], [3, 5]], spd: 2.2, trail: 150 });

def("U", "Undulate", "clocks", "one sine, sixteen joints, phase-shifted — a swimmer — press for a burst", function (u) {
  var D = { n: 16,              // joints
            sp: 11,             // px between joints
            freq: 4.2,          // the sine's rate, rad/s
            amp: 0.07,          // the wave's height, of H
            phase: 0.62,        // the phase offset per joint, radians
            speed: 26,          // cruising speed, px/s
            burst: 130 };       // extra speed at the top of a burst
  const { ctx, W, H, TAU, stage, dot, label, MOVER, clamp } = u;
  // every segment reads the SAME sine — just a little later than the one in
  // front (a PHASE OFFSET per joint). offset in time down a line of bodies
  // = a wave travelling in space. tails, banners, caterpillars: this trick.
  const N = D.n, SP = D.sp;
  let hx = W * 0.3, boost = 0;
  return {
    press() { boost = 1; },
    frame(dt, t) {
      stage();
      boost = Math.max(0, boost - dt * 0.55);
      const freq = D.freq * (1 + boost * 0.9);
      const amp = H * D.amp * (1 + boost * 0.6);
      hx += dt * (D.speed + boost * D.burst);          // the burst is real thrust
      if (hx - N * SP > W + 20) hx = -20;              // swim off, swim back on
      const mid = H * 0.45;
      for (let i = N - 1; i >= 0; i--) {               // tail first, head on top
        const x = hx - i * SP;
        const grow = 0.35 + (i / N) * 0.9;             // the wave grows toward the tail
        const y = mid + Math.sin(t * freq - i * D.phase) * amp * grow;
        const r = 8 - (i / N) * 5.76;                  // bodies shrink toward the tail
        dot(x, y, Math.max(2, r), i === 0 ? MOVER : "rgba(138,217,245," + (0.75 - (i / N) * 0.56) + ")");
        if (i === 0) {                                 // the head gets the eye
          ctx.fillStyle = "#131020";
          ctx.beginPath(); ctx.arc(x + 3, y - 2.5, 1.8, 0, TAU); ctx.fill();
        }
      }
      label("segment i:  y = sin(t·f − i·" + D.phase + ") · amp", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Undulate", "Undertow", "twenty-two joints, a slower sine and a smaller phase step — a long lazy eel instead of a darting swimmer", { n: 22, freq: 2.2, phase: 0.42 });

def("P", "Pendulum", "clocks", "real swing vs the small-angle shortcut — press to lift both to your click", function (u) {
  var D = { k: 7.5,             // g ÷ L, the stiffness of the swing
            damp: 0.02,         // friction on the angular speed
            theta0: 1.15,       // the starting angle, radians from straight down
            length: 0.56,       // the string, of H
            pivot: 0.14 };      // where the string hangs from, of H
  const { ctx, W, H, TAU, stage, dot, ring, label, MOVER, DIM, BONE } = u;
  // the honest pendulum obeys  α = −(g/L)·sin(θ)  — a second-order
  // differential equation, solved live by integrating twice a frame:
  // ω += α·dt, then θ += ω·dt. the ghost uses the classroom shortcut
  // sin(θ) ≈ θ. watch them agree at small swings and drift apart at big
  // ones — that drift is why games integrate instead of using formulas.
  const K = D.k, DAMP = D.damp;
  let th = D.theta0, om = 0, gth = D.theta0, gom = 0;
  const px = () => W / 2, py = () => H * D.pivot, L = () => H * D.length;
  return {
    press(x, y) {
      th = Math.atan2(x - px(), y - py());             // angle measured from "straight down"
      om = 0; gth = th; gom = 0;                       // lift both bobs there, let go
    },
    frame(dt, t) {
      stage();
      om += (-K * Math.sin(th) - DAMP * om) * dt;      // the true equation
      th += om * dt;
      gom += (-K * gth - DAMP * gom) * dt;             // the shortcut: sin(θ) → θ
      gth += gom * dt;
      const bx = px() + Math.sin(th) * L(), by = py() + Math.cos(th) * L();
      const gx = px() + Math.sin(gth) * L(), gy2 = py() + Math.cos(gth) * L();
      ctx.strokeStyle = DIM; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(px(), py()); ctx.lineTo(gx, gy2); ctx.stroke();
      ring(gx, gy2, 8, DIM, 1.5);
      ctx.strokeStyle = BONE; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(px(), py()); ctx.lineTo(bx, by); ctx.stroke();
      dot(px(), py(), 3, BONE);
      dot(bx, by, 9, MOVER);
      label("α = −(g/L)·sin θ", bx + 14, by, "rgba(138,217,245,0.75)");
      label("sin θ ≈ θ (the ghost)", gx + 12, gy2 - 10, DIM);
    }
  };
});
rhymeOf("Pendulum", "Pocketwatch", "four times the stiffness on a string less than half as long — a quick, small tick where the ghost and the truth agree", { k: 30, length: 0.24, theta0: 0.6 });

def("J", "Jitter", "clocks", "three ways to shake: white noise, value noise, summed sines — press to change the sampling rate", function (u) {
  var D = { freqs: [2.5, 9, 0.6],  // the sampling frequencies a press cycles through
            amp: 0.06,             // vertical wobble, of H
            ampX: 0.035,           // sideways wobble, of W
            sineB: 2.7,            // the second sine's rate, as a multiple of the first
            history: 48,           // frames of trace drawn under each mote
            label: "rand() · noise(t·f) · sin(t·f)+sin(2.7·t·f)" };
  const { ctx, W, H, GY, stage, ground, mote, line, label, rand, noise, MOVER, GOOD, MAGIC, DIM } = u;
  // three motes, one errand: wobble in place. WHITE NOISE draws a fresh
  // rand() every frame — no memory, so it can only twitch, whatever f is.
  // value NOISE is randomness with memory of its neighbours: smooth hills
  // between random heights, so sample it slowly (small f) for drift and
  // quickly (big f) for shiver. the summed sines are perfectly periodic —
  // organic-ish, but they repeat. the trace under each is its last y's.
  let fi = 0;
  const hist = [[], [], []];
  const names = ["white noise", "value noise", "two sines"];
  return {
    press() { fi = (fi + 1) % D.freqs.length; },
    frame(dt, t) {
      stage(); ground();
      const f = D.freqs[fi], rest = GY - H * 0.36;
      const cols = [MAGIC, MOVER, GOOD];
      for (let i = 0; i < 3; i++) {
        let nx, ny;
        if (i === 0) { nx = rand(-1, 1); ny = rand(-1, 1); }
        else if (i === 1) { nx = noise(t * f + 37); ny = noise(t * f); }
        else {
          nx = Math.sin(t * f * 1.3 + 1) * 0.6 + Math.sin(t * f * D.sineB * 1.3) * 0.4;
          ny = Math.sin(t * f) * 0.6 + Math.sin(t * f * D.sineB) * 0.4;
        }
        const cx = W * (0.2 + i * 0.3);
        const x = cx + nx * W * D.ampX, y = rest + ny * H * D.amp;
        const h = hist[i];
        h.push(ny); if (h.length > D.history) h.shift();
        const base = GY - H * 0.12, span = W * 0.1;    // the trace: a little seismograph
        line(cx - span, base, cx + span, base, "rgba(232,229,244,0.12)", 1);
        ctx.strokeStyle = "rgba(232,229,244,0.4)"; ctx.lineWidth = 1;
        ctx.beginPath();
        for (let j = 0; j < h.length; j++) {
          const tx = cx - span + (j / (D.history - 1)) * span * 2, ty = base + h[j] * H * 0.04;
          if (j) ctx.lineTo(tx, ty); else ctx.moveTo(tx, ty);
        }
        ctx.stroke();
        mote(x, y, nx * 0.3, cols[i], 7);
        label(names[i], cx, GY + 18, null, "center");
      }
      label("f = " + f, W / 2, 14, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Jitter", "Jiggle", "the same three shakers sampled four times slower and twice as wide — big lazy sways, and the white-noise mote still can't stop twitching", { freqs: [0.6, 2, 0.15], amp: 0.13, ampX: 0.09 });

def("N", "Nest", "clocks", "three frames nested: a swaying platform, a turret on it, a light on its arm — press to freeze a level", function (u) {
  var D = { sway: 0.14,         // platform drift, of W
            tilt: 0.18,         // platform rock, radians
            w1: 0.9,            // the platform's clock, rad/s
            w2: 1.6,            // the turret's clock
            w3: 6,              // the light's clock
            arm: 0.2,           // the turret's arm, of W
            r3: 0.07,           // the light's little orbit, of W
            label: "each level: parent + rotate(local, angle)" };
  const { W, H, TAU, stage, dot, ring, line, poly, mote, label, BONE, MOVER, TARGET, HOT, DIM } = u;
  // a COORDINATE SPACE is an origin plus an angle. to place a child, take its
  // local offset, rotate it by the parent's angle, add the parent's origin —
  // and the child's angle is the parent's angle plus its own. do that three
  // times and the light inherits the sway AND the spin without knowing about
  // either. every scene graph, gun turret, and moon does exactly this.
  // freezing a level stops one clock; the other two keep composing.
  const clk = [0, 0, 0];                               // three clocks, so one can stop
  let frozen = -1;
  function xf(ox, oy, a, lx, ly) {                     // ← parent + rotate(local)
    return [ox + Math.cos(a) * lx - Math.sin(a) * ly, oy + Math.sin(a) * lx + Math.cos(a) * ly];
  }
  function axes(ox, oy, a, c) {                        // a frame's x axis (bright) and y axis (faint)
    line(ox, oy, ox + Math.cos(a) * 14, oy + Math.sin(a) * 14, c, 1);
    line(ox, oy, ox - Math.sin(a) * 9, oy + Math.cos(a) * 9, DIM, 1);
  }
  const names = ["1 platform", "2 turret", "3 light"];
  return {
    press() { frozen = frozen >= 2 ? -1 : frozen + 1; },
    frame(dt, t) {
      stage();
      for (let i = 0; i < 3; i++) if (i !== frozen) clk[i] += dt;
      const p1x = W / 2 + Math.sin(clk[0] * D.w1) * W * D.sway, p1y = H * 0.56;   // frame 1
      const a1 = Math.sin(clk[0] * D.w1 + 0.7) * D.tilt;
      const hw = W * 0.16;
      poly([xf(p1x, p1y, a1, -hw, -4), xf(p1x, p1y, a1, hw, -4), xf(p1x, p1y, a1, hw, 4), xf(p1x, p1y, a1, -hw, 4)], "rgba(201,196,228,0.35)");
      const p2 = xf(p1x, p1y, a1, 0, -12);             // frame 2: the turret sits on the platform
      const a2 = a1 + clk[1] * D.w2;
      const p3 = xf(p2[0], p2[1], a2, W * D.arm, 0);   // frame 3: the tip of the turret's arm
      const a3 = a2 + clk[2] * D.w3;
      const p4 = xf(p3[0], p3[1], a3, W * D.r3, 0);    // the light, three rotations deep
      line(p2[0], p2[1], p3[0], p3[1], BONE, 2.5);
      ring(p3[0], p3[1], W * D.r3, "rgba(245,193,105,0.3)");
      line(p3[0], p3[1], p4[0], p4[1], DIM, 1);
      axes(p1x, p1y, a1, BONE); axes(p2[0], p2[1], a2, MOVER); axes(p3[0], p3[1], a3, TARGET);
      mote(p2[0], p2[1], a2);
      dot(p4[0], p4[1], 4, TARGET);
      for (let i = 0; i < 3; i++)
        label(names[i] + (frozen === i ? " · frozen" : ""), W * (0.17 + i * 0.33), 14, frozen === i ? HOT : null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Nest", "Nautilus", "the turret crawls backward while the light whirls twice as fast on a wider circle — the spiral a nested clock draws", { w2: -0.6, w3: 12, r3: 0.13 });

def("X", "Xfade", "clocks", "blending: a bounce and a hover both run every frame, the mote sits at lerp(A, B, w) — press to flip the blend", function (u) {
  var D = { wA: 3.4,            // the bounce's rate (the |sin| runs at this many rad/s)
            ampA: 0.28,         // bounce height, of H
            wB: 1.5,            // the hover's rate
            ampB: 0.05,         // hover wobble, of H
            restB: 0.32,        // hover altitude, of H
            blendTime: 1.1,     // seconds for w to travel 0 → 1
            hold: 3.2,          // seconds before it flips by itself
            label: "shown = lerp(A, B, w)   w eases 0 ⇄ 1" };
  const { W, H, GY, stage, ground, dot, line, mote, label, lerp, ease, TARGET, DIM } = u;
  // a BLEND TREE with two leaves. both motions are evaluated every frame
  // whether or not they are visible; the mote is drawn at a weighted mix,
  // and the weight w is the only thing that animates when the blend flips.
  // this is how a walk becomes a run without a pop: not by switching clips,
  // but by crossfading two positions (or two poses) with one number.
  let target = 1, k = 1, timer = 0;
  return {
    press() { target = 1 - target; timer = 0; },
    frame(dt, t) {
      stage(); ground();
      timer += dt;
      if (timer > D.hold) { timer = 0; target = 1 - target; }
      k += (target > k ? 1 : -1) * dt / D.blendTime;   // a linear ramp...
      if (k < 0) k = 0; if (k > 1) k = 1;
      const w = ease(k);                               // ...smoothstepped = an eased crossfade
      const ax = W * 0.25, ay = GY - 9 - Math.abs(Math.sin(t * D.wA)) * H * D.ampA;   // A: the bounce
      const bx = W * 0.75, by = GY - H * D.restB + Math.sin(t * D.wB) * H * D.ampB;   // B: the hover
      const x = lerp(ax, bx, w), y = lerp(ay, by, w);  // ← the blend
      line(ax, ay, bx, by, "rgba(232,229,244,0.12)", 1);
      mote(ax, ay, 0, "rgba(155,226,138,0.35)");       // the two ghosts, always computed
      mote(bx, by, 0, "rgba(201,160,245,0.35)");
      mote(x, y, 0);
      const sx0 = W * 0.25, sx1 = W * 0.75, sy = 18;   // the blend slider
      line(sx0, sy, sx1, sy, DIM, 2);
      dot(lerp(sx0, sx1, w), sy, 4, TARGET);
      label("A bounce", sx0, sy + 14, "rgba(155,226,138,0.7)", "center");
      label("B hover", sx1, sy + 14, "rgba(201,160,245,0.7)", "center");
      label("w = " + w.toFixed(2), W / 2, sy - 6, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Xfade", "Xray", "a three-second crossfade between a quick low bounce and the hover — the mix, not the ends, is what you watch", { blendTime: 2.8, wA: 6.5, ampA: 0.14 });

def("B", "Bullethell", "clocks", "nothing stored per bullet: p = origin + dir·speed·age, Orbit's polar trick spiralled — press to switch pattern", function (u) {
  var D = { golden: 2.39996,    // the GOLDEN ANGLE, radians: the spiral's step per bullet
            spin: 0.8,          // how fast the emitter's aim turns, rad/s
            interval: 0.045,    // seconds between spiral bullets
            speed: 0.42,        // bullet speed, W per second
            ringN: 14,          // bullets per ring
            ringEvery: 0.55,    // seconds between rings
            ringTwist: 0.35,    // each ring rotated a little more than the last
            label: "θᵢ = i·φ + tᵢ·spin    p = o + dir·v·age" };
  const { W, H, TAU, stage, dot, ring, mote, label, len, HOT, MAGIC, MOVER } = u;
  // no bullet has a velocity, or even a position, in memory. bullet i was
  // fired at tᵢ = i·interval, aimed at θᵢ = i·golden + tᵢ·spin, and at any
  // moment it sits at origin + (cos θᵢ, sin θᵢ)·speed·(t − tᵢ): polar →
  // Cartesian, exactly Orbit's bridge. we only count which i are still on
  // screen. the golden angle (≈137.5°) never repeats, so the spiral never
  // lines up into spokes; the ring pattern fires N at once, with a twist.
  let pattern = 0, t0 = 0, reset = false;
  return {
    press() { pattern = 1 - pattern; reset = true; },  // the new pattern starts fresh
    frame(dt, t) {
      stage();
      if (reset) { t0 = t; reset = false; }
      const ox = W / 2, oy = H * 0.46, T = t - t0;
      const v = W * D.speed, life = (len(W, H) * 0.5 + 12) / v;   // gone once past the corners
      ring(ox, oy, 7 + Math.sin(t * 5) * 1.5, MAGIC, 1.5);
      dot(ox, oy, 3, MAGIC);
      let n = 0;
      if (pattern === 0) {
        const iMax = Math.floor(T / D.interval), iMin = Math.max(0, Math.ceil((T - life) / D.interval));
        for (let i = iMin; i <= iMax; i++) {
          const ti = i * D.interval, age = T - ti, th = i * D.golden + ti * D.spin;
          dot(ox + Math.cos(th) * v * age, oy + Math.sin(th) * v * age, 2.6, HOT); n++;
        }
      } else {
        const bMax = Math.floor(T / D.ringEvery), bMin = Math.max(0, Math.ceil((T - life) / D.ringEvery));
        for (let b = bMin; b <= bMax; b++) {
          const age = T - b * D.ringEvery;
          for (let k = 0; k < D.ringN; k++) {
            const th = k * TAU / D.ringN + b * D.ringTwist;
            dot(ox + Math.cos(th) * v * age, oy + Math.sin(th) * v * age, 2.6, HOT); n++;
          }
        }
      }
      const px = W / 2 + Math.sin(t * 0.9) * W * 0.3;  // the player, weaving along the bottom
      mote(px, H * 0.86, Math.cos(t * 0.9) > 0 ? 0 : Math.PI, MOVER, 6);
      label((pattern ? "ring" : "spiral") + " · " + n + " bullets, 0 stored", W / 2, 14, null, "center");
      label(pattern ? "θₖ = k·2π/N + b·twist    p = o + dir·v·age" : D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Bullethell", "Blossom", "a 30° step instead of the golden angle, spinning slowly, and six-bullet rings — twelve straight petals that turn as one", { golden: 0.5236, spin: 0.25, ringN: 6 });

def("U", "Ufo", "clocks", "two unsynced sines to hover (Hover's alien cousin), a beam telegraph, an instant blink — press to summon it", function (u) {
  var D = { ax: 0.06,           // the sideways wobble, of W
            ay: 0.035,          // the up-down wobble, of H
            f1: 1.3,            // their rates — unsynced on purpose,
            f2: 2.1,            // so the loop never visibly repeats
            dwell: 3.2,         // seconds between blinks
            tele: 0.45 };       // the beam's warning, seconds before the blink
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, poly, label, rand, clamp, smooth, MAGIC, TARGET } = u;
  // chapter 05's alien: two sines whose rates share no simple ratio, so the
  // hover never quite repeats — the cheapest "alive". then the other kind
  // of motion: none at all. a TELEGRAPH (the beam) warns for a moment, and
  // the saucer is simply elsewhere next frame, already leaning toward its
  // new heading — a zero-duration move is still a move, and the warning is
  // what makes it fair.
  let hx = W * 0.5, hy = H * 0.4, nx = 0, ny = 0, timer = 0, lean = 0, ghost = 0, gx = 0, gy = 0;
  function pick() { nx = rand(W * 0.15, W * 0.85); ny = rand(H * 0.18, H * 0.55); }
  pick();
  return {
    press(x, y) {                                      // summon: aim the next blink here, hurry it
      nx = clamp(x, W * 0.1, W * 0.9); ny = clamp(y, H * 0.15, H * 0.6);
      timer = Math.max(timer, D.dwell - D.tele);
    },
    frame(dt, t) {
      stage(); ground();
      timer += dt;
      let x = hx + Math.sin(t * D.f1) * W * D.ax, y = hy + Math.sin(t * D.f2 + 1) * H * D.ay;
      if (timer >= D.dwell) {                          // the blink
        timer = 0; ghost = 1; gx = x; gy = y;
        lean = nx > hx ? 0.35 : -0.35;                 // reoriented instantly — no turn animation
        hx = nx; hy = ny; pick();
        x = hx + Math.sin(t * D.f1) * W * D.ax; y = hy + Math.sin(t * D.f2 + 1) * H * D.ay;
      }
      const warn = clamp((timer - (D.dwell - D.tele)) / D.tele, 0, 1);
      lean -= lean * smooth(3, dt);
      ghost = Math.max(0, ghost - dt * 2.5);
      if (warn > 0)                                    // the beam: the telegraph
        poly([[x - 5, y + 4], [x + 5, y + 4], [x + 22, GY], [x - 22, GY]], "rgba(201,160,245," + (0.06 + warn * 0.24) + ")");
      if (ghost > 0) ring(gx, gy, 12 + (1 - ghost) * 16, "rgba(201,160,245," + ghost * 0.5 + ")", 1.5);
      ring(nx, ny, 5, "rgba(245,193,105,0.35)");       // where it will be next
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(lean);
      ctx.fillStyle = MAGIC;
      ctx.beginPath(); ctx.ellipse(0, 0, 18, 5, 0, 0, TAU); ctx.fill();
      ctx.fillStyle = "rgba(232,229,244,0.7)";
      ctx.beginPath(); ctx.arc(0, -3, 7, Math.PI, 0); ctx.fill();
      for (let k = 0; k < 4; k++) {                    // rim lights on their own phases
        const b = 0.35 + 0.35 * Math.sin(t * 7 + k * 1.6);
        dot(-12 + k * 8, 1, 1.6, "rgba(245,193,105," + b + ")");
      }
      ctx.restore();
      label("x = hx + sin(" + D.f1 + "t)·a   y = hy + sin(" + D.f2 + "t)·b", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Ufo", "Unstable", "blinks three times as often with a wide, hurried wobble — a saucer that can't keep still, and can't stay", { dwell: 1.1, ax: 0.12, f2: 4.3 });

def("O", "Orrery", "clocks", "orbits on Kepler's ellipses (Orbit + Nest): faster near the sun, moons on planets — press to speed the clock", function (u) {
  var D = { a: [0.12, 0.2, 0.3],      // semi-major axes, of min(W, H)
            e: [0.1, 0.3, 0.25],      // eccentricities: 0 is a circle, near 1 a comet
            peri: [0.3, 2.2, 4.4],    // where each ellipse points its near end, radians
            rate: 0.06,               // the clock: mean motion n = rate ÷ a^1.5 (Kepler's third law)
            moons: [0, 1, 2],         // moons per planet
            moonRate: 5,              // moon radians per second
            mults: [1, 3, 9],         // what a press cycles the clock through
            label: "E − e·sin E = n·t    r = a(1 − e·cos E)" };
  const { W, H, TAU, stage, dot, ring, line, mote, label, TARGET, MOVER, BONE, GOOD, DIM } = u;
  // KEPLER: a planet on an ellipse with the sun at one FOCUS sweeps equal
  // areas in equal times — so it rushes through the near end and dawdles at
  // the far end (θ̇ ∝ 1/r²). the recipe: the mean anomaly M = n·t grows
  // evenly; solve E − e·sin E = M for the ECCENTRIC ANOMALY E (a few Newton
  // steps); then x = a(cos E − e), y = b·sin E. every body is a pure function
  // of the clock, moons included: moon = planet + rotate(local), as in Nest.
  let clk = 0, mi = 0;                                 // the clock is the only state
  function orbitPt(i, E) {                             // a point on ellipse i, relative to the sun
    const S = Math.min(W, H), a = D.a[i] * S, e = D.e[i], b = a * Math.sqrt(1 - e * e);
    const px = a * (Math.cos(E) - e), py = b * Math.sin(E);
    const c = Math.cos(D.peri[i]), s = Math.sin(D.peri[i]);
    return [px * c - py * s, px * s + py * c];
  }
  function planet(i, T) {
    const e = D.e[i], n = D.rate / Math.pow(D.a[i], 1.5);
    const M = (n * T) % TAU;
    let E = M + e * Math.sin(M);
    for (let k = 0; k < 8; k++) E -= (E - e * Math.sin(E) - M) / (1 - e * Math.cos(E));   // Newton's method
    if (!isFinite(E)) E = M;
    return orbitPt(i, E);
  }
  return {
    press() { mi = (mi + 1) % D.mults.length; },
    frame(dt, t) {
      stage();
      clk += dt * D.mults[mi];
      const sx = W / 2, sy = H * 0.5;
      for (let i = 0; i < D.a.length; i++) {
        let prev = null;                               // the guide ellipse
        for (let k = 0; k <= 40; k++) {
          const p = orbitPt(i, k / 40 * TAU);
          if (prev) line(sx + prev[0], sy + prev[1], sx + p[0], sy + p[1], "rgba(232,229,244,0.1)", 1);
          prev = p;
        }
        const p = planet(i, clk), q = planet(i, clk + 0.02);   // q − p: the velocity, by finite difference
        line(sx, sy, sx + p[0], sy + p[1], DIM, 1);    // the radius vector: short = fast
        const x = sx + p[0], y = sy + p[1];
        if (i === 1) mote(x, y, Math.atan2(q[1] - p[1], q[0] - p[0]), MOVER, 6);
        else dot(x, y, 4, BONE);
        for (let m = 0; m < D.moons[i]; m++) {
          const r = 8 + m * 5, ang = clk * D.moonRate * (1 - m * 0.4) + m * 2;
          dot(x + Math.cos(ang) * r, y + Math.sin(ang) * r, 2, GOOD);
        }
      }
      dot(sx, sy, 6, TARGET);
      ring(sx, sy, 9, "rgba(245,193,105,0.4)");
      label("clock ×" + D.mults[mi], W / 2, 14, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Orrery", "Oort", "every orbit stretched to comet eccentricity and the clock hurried — the near-sun rush becomes the whole show", { e: [0.55, 0.65, 0.6], peri: [1.0, 2.6, 5.2], rate: 0.09 });

def("M", "Mirror", "clocks", "a kaleidoscope: one Lissajous (Eight) rotated and mirrored into every wedge (Nest) — press to change the folds", function (u) {
  var D = { folds: [6, 4, 8],       // fold counts a press cycles through
            a: 2,                   // the Lissajous ratio, as in Eight
            b: 3,
            spd: 0.55,              // its speed
            rx: 0.28,               // its size, of min(W, H)
            ry: 0.28,
            trail: 40,              // frames of trail behind every clone
            label: "clone k: rotate(k·2π/N), mirror odd k" };
  const { ctx, W, H, TAU, stage, dot, line, mote, label, MAGIC } = u;
  // one body moves; N are seen. clone k takes the mote's LOCAL position
  // (relative to the centre), flips its y when k is odd (a mirror), and
  // rotates it by k·360°/N (Nest's parent + rotate(local)). because the
  // mirror alternates, every wedge shares its edges with its neighbours and
  // the picture closes on itself — a kaleidoscope, from one Lissajous.
  let fi = 0;
  const hist = [];
  return {
    press() { fi = (fi + 1) % D.folds.length; },
    frame(dt, t) {
      stage();
      const N = D.folds[fi], cx = W / 2, cy = H / 2, S = Math.min(W, H), T = t * D.spd;
      const lx = Math.cos(D.a * T) * S * D.rx, ly = Math.sin(D.b * T) * S * D.ry;   // the one real position
      const vx = -Math.sin(D.a * T) * D.a, vy = Math.cos(D.b * T) * D.b;            // its derivative
      hist.push([lx, ly]); if (hist.length > D.trail) hist.shift();
      for (let k = 0; k < N; k++) {
        const ang = k * TAU / N, c = Math.cos(ang), s = Math.sin(ang), m = k % 2 ? -1 : 1;
        line(cx, cy, cx + c * S * 0.5, cy + s * S * 0.5, "rgba(232,229,244,0.08)", 1);   // the wedge edge
        ctx.strokeStyle = k ? "rgba(201,160,245,0.45)" : "rgba(138,217,245,0.6)";
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        for (let i = 0; i < hist.length; i++) {
          const x = hist[i][0], y = hist[i][1] * m;     // mirror, then rotate, then add the centre
          const px = cx + x * c - y * s, py = cy + x * s + y * c;
          if (i) ctx.lineTo(px, py); else ctx.moveTo(px, py);
        }
        ctx.stroke();
        const y = ly * m, px = cx + lx * c - y * s, py = cy + lx * s + y * c;
        if (k) dot(px, py, 4, MAGIC);
        else mote(px, py, Math.atan2(vy, vx), null, 6);
      }
      label("N = " + N, W / 2, 14, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Mirror", "Mandala", "twelve, sixteen, ten folds of a denser 3:5 knot — the clones outnumber the wedges you can count", { folds: [12, 16, 10], a: 3, b: 5 });

def("I", "Idle", "clocks", "idle stack: breath (a sine on scale), a jittered blink, look-at eyes, a weight shift — drag to be looked at", function (u) {
  var D = { breathP: 3.4,       // seconds per breath
            breath: 0.045,      // how much the body grows, as a scale
            blinkEvery: 2.8,    // mean seconds between blinks
            blinkJitter: 1.6,   // ± seconds of randomness on that
            blinkLen: 0.12,     // a blink's length
            shiftEvery: 4,      // seconds between weight shifts
            shift: 0.05,        // how far it sways, of W
            lookRate: 6,        // how fast the eyes catch up
            label: "sy = 1 + sin(2πt/P)·a  ·  blink  ·  look-at" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, label, rand, smooth, len, MOVER, TARGET, INK } = u;
  // a still character is dead; a character with four tiny clocks is alive.
  // BREATHING is a sine on the body's scale (Hover's sine, pointed at size
  // instead of height); the BLINK is a timer with jitter, because a regular
  // blink reads as a machine; LOOK-AT points the pupils at a gaze point and
  // lerps toward it; the WEIGHT SHIFT is a slower timer toggling a lean.
  // none of them know about the others — they just add up.
  let blinkT = 2, shiftT = 3, side = 1, lean = 0, gazeT = 0, lookX = 0, lookY = 0;
  let gx = W * 0.75, gy = H * 0.3;
  return {
    drag: true,
    press(x, y) { gx = x; gy = y; gazeT = -4; },
    frame(dt, t) {
      stage(); ground();
      blinkT -= dt;
      if (blinkT <= 0) blinkT = Math.max(0.4, D.blinkEvery + rand(-D.blinkJitter, D.blinkJitter));
      const closed = blinkT < D.blinkLen;
      shiftT -= dt;
      if (shiftT <= 0) { shiftT = D.shiftEvery * rand(0.7, 1.3); side = -side; }
      lean += (side - lean) * smooth(3, dt);           // −1 … 1, eased
      gazeT += dt;
      if (gazeT > 2.6) { gazeT = 0; gx = rand(W * 0.1, W * 0.9); gy = rand(H * 0.1, H * 0.7); }   // its own curiosity
      const R = H * 0.13;
      const sy = 1 + Math.sin(t * TAU / D.breathP) * D.breath, sx = 1 / sy;   // the breath keeps its volume
      const bx = W / 2 + lean * D.shift * W, by = GY - R * sy;   // it grows up from the floor
      ctx.fillStyle = "rgba(0,0,0,0.35)";
      ctx.beginPath(); ctx.ellipse(bx, GY - 2, R * 0.9 * sx, 3.5, 0, 0, TAU); ctx.fill();
      const ey = by - R * 0.15;
      const dx = gx - bx, dy = gy - ey, d = len(dx, dy) || 1;
      lookX += (dx / d - lookX) * smooth(D.lookRate, dt);   // look-at, smoothed
      lookY += (dy / d - lookY) * smooth(D.lookRate, dt);
      line(bx, ey, gx, gy, "rgba(245,193,105,0.15)", 1);
      ctx.save();
      ctx.translate(bx, by);
      ctx.rotate(lean * 0.12);
      ctx.scale(sx, sy);
      ctx.fillStyle = MOVER;
      ctx.beginPath(); ctx.arc(0, 0, R, 0, TAU); ctx.fill();
      for (let e = -1; e <= 1; e += 2) {
        const exx = e * R * 0.34, eyy = -R * 0.15, er = R * 0.2;
        if (closed) line(exx - er, eyy, exx + er, eyy, "#131020", 2);
        else {
          dot(exx, eyy, er, INK);
          dot(exx + lookX * er * 0.45, eyy + lookY * er * 0.45, er * 0.5, "#131020");
        }
      }
      ctx.restore();
      ring(gx, gy, 5, TARGET, 1.5);
      dot(gx, gy, 2, TARGET);
      label(closed ? "blink" : "next blink in " + blinkT.toFixed(1) + " s", W / 2, 14, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Idle", "Insomniac", "the same four clocks wound tight: panting breath, blinks every second, a restless weight shift — alive, and not okay", { breathP: 1.3, blinkEvery: 0.8, shiftEvery: 1.4 });

def("Y", "Yacht", "clocks", "a boat on y = wave(x, t), tilted by its slope, the derivative (Undulate + Normals) — press for more wind", function (u) {
  var D = { lam1: 0.6,          // the two wavelengths, of W
            lam2: 0.22,
            amp1: 0.05,         // their heights, of H
            amp2: 0.018,
            w1: 1.6,            // their rates, rad/s (a wave's speed is ω ÷ k)
            w2: 3.1,
            winds: [1, 1.7, 0.55],   // wind levels a press cycles through: they scale speed and height
            mid: 0.62,          // the sea's rest level, of H
            boatX: 0.42,        // where the boat sits, of W
            label: "y = wave(x, t)    tilt = atan(dy/dx)" };
  const { ctx, W, H, TAU, stage, dot, line, poly, label, BONE, MOVER, INK } = u;
  // Undulate's trick, but the SPACE is the sea: y = Σ amp·sin(k·x − ω·t) is
  // a wave travelling at ω ÷ k pixels a second. the boat doesn't move — the
  // wave moves under it, and it sits at wave(boatX, t). its tilt is the
  // wave's SLOPE there, the derivative dy/dx — for a sine, a cos with the
  // same argument (Normals' lesson: the surface tells you which way is up).
  // foam rides each crest, which is wherever sin(k·x − ω·t) = 1.
  let wi = 0, ph = 0;                                  // ph: the wave's own clock, so a wind change never jumps
  function wave(x, wind) {
    const k1 = TAU / (D.lam1 * W), k2 = TAU / (D.lam2 * W);
    return H * D.mid - H * D.amp1 * wind * Math.sin(k1 * x - D.w1 * ph) - H * D.amp2 * wind * Math.sin(k2 * x - D.w2 * ph + 1);
  }
  function slope(x, wind) {                            // d/dx of the line above
    const k1 = TAU / (D.lam1 * W), k2 = TAU / (D.lam2 * W);
    return -H * D.amp1 * wind * k1 * Math.cos(k1 * x - D.w1 * ph) - H * D.amp2 * wind * k2 * Math.cos(k2 * x - D.w2 * ph + 1);
  }
  return {
    press() { wi = (wi + 1) % D.winds.length; },
    frame(dt, t) {
      stage();
      const wind = D.winds[wi];
      ph += dt * wind;
      const sea = [];                                  // the surface, then the water under it
      for (let x = 0; x <= W; x += 5) sea.push([x, wave(x, wind)]);
      sea.push([W, H], [0, H]);
      poly(sea, "rgba(138,217,245,0.12)");
      ctx.strokeStyle = "rgba(138,217,245,0.6)"; ctx.lineWidth = 1.5;
      ctx.beginPath();
      for (let i = 0; i < sea.length - 2; i++) { if (i) ctx.lineTo(sea[i][0], sea[i][1]); else ctx.moveTo(sea[i][0], sea[i][1]); }
      ctx.stroke();
      const L1 = D.lam1 * W, k1 = TAU / L1;
      let fx = ((Math.PI / 2 + D.w1 * ph) / k1) % L1;  // the first crest of the long wave...
      for (fx -= L1; fx < W + L1; fx += L1)            // ...and every crest after it
        for (let j = -1; j <= 1; j++) dot(fx + j * 5, wave(fx + j * 5, wind) - 2.5, 1.5, "rgba(232,229,244,0.6)");
      const bx = W * D.boatX, by = wave(bx, wind), tilt = Math.atan(slope(bx, wind));
      const sail = Math.sin(t * 0.7) * 0.5 * wind;     // the wind sine leans the sail
      ctx.save();
      ctx.translate(bx, by);
      ctx.rotate(tilt);
      poly([[-16, -2], [16, -2], [10, 6], [-10, 6]], BONE);
      line(0, -2, 0, -26, INK, 1.5);
      poly([[0, -25], [0, -6], [-(12 + sail * 8), -10]], MOVER);
      ctx.restore();
      label("wind " + wind + " · tilt " + Math.round(tilt * 180 / Math.PI) + "°", W / 2, 14, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Yacht", "Yikes", "the same sea in a squall: twice the wave height at three times the wind — the derivative goes wild and so does the boat", { winds: [2.6, 3.4, 2], amp1: 0.085 });

/* ============================== SLOPES & SPRINGS ==============================
   Motion WITH memory: a velocity that persists between frames, an
   acceleration that bends it. This is calculus wearing gym clothes —
   velocity is the derivative of position, acceleration the derivative of
   velocity, and "integration" just means adding them up one frame at a
   time. Every camera follow, jump arc, and satisfying UI wobble is here —
   and, in the later laps, the dashes, slimes, umbrellas and cat pounces
   that are the same three lines of maths wearing a costume. */

def("L", "Lerp", "springs", "three ways to chase the same target — constant, eased, springy — press to move it", function (u) {
  var D = { speed: 140, rate: 4.2, w: 7.5, z: 0.55,      // px/s, lerp rate, spring ω and ζ
            retarget: 2.6 };                             // seconds before the target hops on its own
  const { ctx, W, H, stage, dot, ring, mote, label, rand, len, GOOD, MOVER, BONE, TARGET } = u;
  // the same errand, three personalities:
  //   constant speed — move_toward: a fixed step along the line. robotic, exact.
  //   lerp-smoothing — cover a FRACTION of the remaining gap each frame:
  //     fast start, feather-soft landing (written 1−exp(−k·dt) so any
  //     framerate produces the same curve).
  //   spring — remembers a velocity, so it can OVERSHOOT and settle.
  let tx = W * 0.7, ty = H * 0.35, timer = 0;
  const A = { x: W * 0.2, y: H * 0.7 };                // constant
  const B = { x: W * 0.2, y: H * 0.5 };                // lerp
  const C = { x: W * 0.2, y: H * 0.3, vx: 0, vy: 0 };  // spring
  return {
    press(x, y) { tx = x; ty = y; timer = -3; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (timer > D.retarget) { timer = 0; tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.2, H * 0.8); }
      let dx = tx - A.x, dy = ty - A.y, d = len(dx, dy);
      const step = D.speed * dt;
      if (d > step) { A.x += dx / d * step; A.y += dy / d * step; }
      else { A.x = tx; A.y = ty; }                     // arrive exactly, stop dead
      const k = 1 - Math.exp(-D.rate * dt);            // framerate-proof lerp factor
      B.x += (tx - B.x) * k;
      B.y += (ty - B.y) * k;
      const w = D.w, z = D.z;                          // spring frequency + damping
      C.vx += ((tx - C.x) * w * w - 2 * z * w * C.vx) * dt;
      C.vy += ((ty - C.y) * w * w - 2 * z * w * C.vy) * dt;
      C.x += C.vx * dt; C.y += C.vy * dt;
      ring(tx, ty, 10, TARGET, 1.5);
      dot(tx, ty, 3, TARGET);
      mote(A.x, A.y, Math.atan2(ty - A.y, tx - A.x), GOOD, 6);
      mote(B.x, B.y, Math.atan2(ty - B.y, tx - B.x), MOVER, 6);
      mote(C.x, C.y, Math.atan2(C.vy, C.vx), BONE, 6);
      label("constant", W * 0.25, H - 8, "rgba(155,226,138,0.8)", "center");
      label("lerp", W * 0.5, H - 8, "rgba(138,217,245,0.8)", "center");
      label("spring", W * 0.75, H - 8, "rgba(201,196,228,0.8)", "center");
    }
  };
});
rhymeOf("Lerp", "Lunge", "the same three errands at a sprint — 320 px/s, a lerp rate of 11, a stiffer spring that still overshoots", { speed: 320, rate: 11, w: 13 });

def("D", "Damp", "springs", "one spring equation, three damping ratios — press to yank the target", function (u) {
  var D = { w: 8, z1: 0.35, z2: 1.0, z3: 2.2,             // ω, and the three ζ personalities
            swap: 2.2, hold: 4,                          // seconds between hops; seconds a press pins it
            label: "a = ω²(target−y) − 2ζω·v" };
  const { ctx, W, H, stage, dot, mote, label, MOVER, GOOD, HOT, TARGET } = u;
  // the spring-damper is a second-order differential equation:
  //   acceleration = ω²·(target − x) − 2·ζ·ω·velocity
  // ω sets how FAST it wants to be; ζ (zeta) sets its manners:
  //   ζ < 1 underdamped — overshoots and rings (bouncy, alive)
  //   ζ = 1 CRITICALLY DAMPED — fastest possible arrival with zero
  //         overshoot (the one cameras and cursors want)
  //   ζ > 1 overdamped — never overshoots, takes its sweet time
  const w = D.w;
  const manners = z => z < 1 ? "bouncy" : z > 1 ? "sluggish" : "critical";
  const rows = [
    { z: D.z1, name: "ζ = " + D.z1 + " " + manners(D.z1), c: HOT, y: 0, v: 0 },
    { z: D.z2, name: "ζ = " + D.z2 + " " + manners(D.z2), c: GOOD, y: 0, v: 0 },
    { z: D.z3, name: "ζ = " + D.z3 + " " + manners(D.z3), c: MOVER, y: 0, v: 0 }
  ];
  let ty = H * 0.3, timer = 0, hold = 0;
  for (const r of rows) r.y = H * 0.6;
  return {
    press(x, y) { ty = y; hold = D.hold; },
    frame(dt, t) {
      stage();
      if (hold > 0) hold -= dt;
      else {
        timer += dt;
        if (timer > D.swap) { timer = 0; ty = ty < H * 0.5 ? H * 0.68 : H * 0.3; }
      }
      ctx.strokeStyle = TARGET;
      ctx.lineWidth = 1;
      ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(0, ty); ctx.lineTo(W, ty); ctx.stroke();
      ctx.setLineDash([]);
      rows.forEach((r, i) => {
        const x = W * (0.25 + i * 0.25);
        r.v += (w * w * (ty - r.y) - 2 * r.z * w * r.v) * dt;   // the whole equation
        r.y += r.v * dt;
        ctx.strokeStyle = "rgba(232,229,244,0.12)";
        ctx.beginPath(); ctx.moveTo(x, H * 0.12); ctx.lineTo(x, H * 0.88); ctx.stroke();
        mote(x, r.y, r.v * 0.002, r.c, 7);
        label(r.name, x, H * 0.94, null, "center");
      });
      label(D.label, W / 2, 14, null, "center");
    }
  };
});
rhymeOf("Damp", "Doorbell", "a faster spring and nobody critical — three flavours of ringing, from a shiver to a slow wobble", { w: 14, z2: 0.15, z3: 0.6 });

def("J", "Jump", "springs", "v₀ = √(2gh): pick the height, get the launch speed — press to set the apex", function (u) {
  var D = { g: 2.4, apex: 0.36, fallMul: 1.7,            // gravity and apex as fractions of H; the fall multiplier
            stand: 0.9, land: 0.16 };                    // seconds standing, seconds splatted
  const { ctx, W, H, GY, TAU, stage, ground, ring, mote, label, clamp, TARGET, DIM } = u;
  // jumps are parabolas — constant downward acceleration under a chosen
  // launch speed. games run the maths BACKWARD: designers pick the apex
  // height h, and v₀ = √(2·g·h) guarantees it. the second trick: gravity
  // is 1.7× stronger on the way down, because floaty rises and snappy
  // falls FEEL right even though physics class would object.
  const G = H * D.g;
  let h = H * D.apex;
  let phase = "stand", timer = 0, y = GY, vy = 0;
  return {
    press(px, py) { h = clamp(GY - py, H * 0.1, H * 0.62); },
    frame(dt, t) {
      stage(); ground();
      const v0 = Math.sqrt(2 * G * h);
      const x = W / 2;
      timer += dt;
      if (phase === "stand" && timer > D.stand) { phase = "air"; vy = -v0; timer = 0; }
      if (phase === "air") {
        vy += (vy < 0 ? G : G * D.fallMul) * dt;       // heavier on the way down
        y += vy * dt;
        if (y >= GY) { y = GY; phase = "land"; timer = 0; }
      }
      if (phase === "land" && timer > D.land) { phase = "stand"; timer = 0; }
      ctx.fillStyle = "rgba(232,229,244,0.18)";        // the predicted arc, while standing
      if (phase === "stand") {
        let sy = GY, sv = -v0;
        for (let i = 0; i < 46; i++) {
          sv += (sv < 0 ? G : G * D.fallMul) * 0.022;
          sy += sv * 0.022;
          if (sy > GY) break;
          ctx.fillRect(x - 1 + i * 0, sy, 2, 2);       // a rising-falling dotted line
        }
      }
      ring(x, GY - h, 6, TARGET, 1.5);
      label("apex h = " + Math.round(h) + " px", x + 12, GY - h + 3, "rgba(245,193,105,0.8)");
      let sx = 1, sy2 = 1;
      if (phase === "stand" && timer > D.stand - 0.2) { sx = 1.12; sy2 = 0.85; }   // anticipation crouch
      if (phase === "air") { sy2 = 1 + Math.min(0.35, Math.abs(vy) / v0 * 0.3); sx = 1 / sy2; }
      if (phase === "land") { sx = 1.25; sy2 = 0.72; }                    // the splat
      ctx.save();
      ctx.translate(x, y - 9 * sy2);
      ctx.scale(sx, sy2);
      mote(0, 0, phase === "air" ? (vy < 0 ? -0.5 : 0.5) : 0);
      ctx.restore();
      label("v₀ = √(2·g·h) = " + Math.round(v0), W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Jump", "Joey", "kangaroo gravity — nearly twice as strong, a near-symmetric arc, and hardly a pause between hops", { g: 4.4, fallMul: 1.15, stand: 0.3 });

def("B", "Bounce", "springs", "restitution: every bounce keeps 62% of the energy — press to throw", function (u) {
  var D = { g: 1.9, e: 0.78,                             // gravity as a fraction of H; the restitution
            rest: 1.1, squash: 0.35 };                   // seconds asleep before a new drop; squash depth
  const { ctx, W, H, GY, stage, ground, label, rand, TAU, MOVER } = u;
  // integration plus one rule at the floor: flip the velocity and keep only
  // a fraction e of it (the RESTITUTION). heights shrink by e² per bounce —
  // energy goes with the square of speed — so the rhythm speeds up all by
  // itself, no scripting. the squash at contact is presentation, not physics.
  const G = H * D.g, E = D.e;
  let x = W * 0.35, y = H * 0.12, vx = 34, vy = 0, squash = 0, bounces = 0, rest = 0;
  return {
    press(px, py) { x = px; y = py; vx = rand(-70, 70); vy = rand(-60, 20); bounces = 0; rest = 0; },
    frame(dt, t) {
      stage(); ground();
      if (rest > 0) {
        rest -= dt;
        if (rest <= 0) { x = rand(W * 0.2, W * 0.8); y = H * 0.12; vx = rand(-40, 40); vy = 0; bounces = 0; }
      } else {
        vy += G * dt;
        x += vx * dt; y += vy * dt;
        if (x < 9) { x = 9; vx = -vx * E; }
        if (x > W - 9) { x = W - 9; vx = -vx * E; }
        if (y > GY - 9) {
          y = GY - 9;
          vy = -vy * E;                                // the whole law of bouncing
          vx *= 0.99;
          squash = 0.12; bounces++;
          if (Math.abs(vy) < H * 0.09) { vy = 0; if (Math.abs(vx) < 6) rest = D.rest; }
        }
      }
      squash = Math.max(0, squash - dt);
      const s = squash > 0 ? 1 - (squash / 0.12) * D.squash : 1;
      ctx.save();
      ctx.translate(x, y + (1 - s) * 9);
      ctx.scale(1 / s, s);                             // squash preserves "volume"
      ctx.fillStyle = MOVER;
      ctx.beginPath(); ctx.arc(0, 0, 9, 0, TAU); ctx.fill();
      ctx.fillStyle = "#131020";
      ctx.beginPath(); ctx.arc(2.8, -2.6, 2, 0, TAU); ctx.fill();
      ctx.restore();
      label("bounce " + bounces + " · e = " + E + " of speed → e² of height", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Bounce", "Balloon", "a quarter of the gravity and 92% restitution — a slow, tireless lollop that hardly squashes at all", { g: 0.55, e: 0.92, squash: 0.15 });

def("D", "Dash", "springs", "a burst of speed decaying by e^(−k·dt) — an ease-out with no timer — press to dash toward your click", function (u) {
  var D = { burst: 2.2, k: 6,                            // burst speed in widths per second; decay rate per second
            cooldown: 0.8, cancelAt: 0.3,                // seconds locked out; a new press cancels above this fraction of burst
            ghostGap: 7, ghostLife: 0.45,                // px between afterimages; seconds they last
            autoEvery: 1.8 };                            // seconds idle before it dashes somewhere on its own
  const { ctx, W, H, TAU, stage, ring, mote, label, rand, len, MOVER, TARGET, HOT, DIM } = u;
  // a DASH is an IMPULSE with no follow-through: SET the velocity to a burst
  // (not add — that is the difference between a dash and a shove) and let
  // it die away with v *= exp(−k·dt) every frame. that is lerp-smoothing
  // applied to speed instead of position, and it is the cheapest EASE-OUT
  // there is — fast start, feather stop, no duration to keep track of. the
  // afterimages are dropped every few px, so their spacing IS the speed
  // graph; the ring is the COOLDOWN, and a press mid-dash cancels into a new one.
  let x = W / 2, y = H * 0.5, vx = 0, vy = 0, h = 0;
  let cool = 0, idle = 0, tx = W * 0.7, ty = H * 0.4, lastGx = x, lastGy = y;
  const ghosts = [];
  function dash(px, py) {
    const moving = len(vx, vy) > D.burst * W * D.cancelAt;   // still fast: cancel into a new dash
    if (cool > 0 && !moving) return;                   // else the cooldown says no
    const dx = px - x, dy = py - y, d = len(dx, dy) || 1;
    h = Math.atan2(dy, dx);
    vx = dx / d * D.burst * W; vy = dy / d * D.burst * W;   // the impulse: velocity SET, not added
    cool = D.cooldown; idle = 0;
  }
  return {
    press(px, py) { tx = px; ty = py; dash(px, py); },
    frame(dt, t) {
      stage();
      cool = Math.max(0, cool - dt); idle += dt;
      if (idle > D.autoEvery) { tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.15, H * 0.85); dash(tx, ty); idle = 0; }
      const decay = Math.exp(-D.k * dt);               // ← the ease-out, one multiply
      vx *= decay; vy *= decay;
      x += vx * dt; y += vy * dt;
      if (x < 10) { x = 10; vx = -vx; } if (x > W - 10) { x = W - 10; vx = -vx; }
      if (y < 10) { y = 10; vy = -vy; } if (y > H - 10) { y = H - 10; vy = -vy; }
      if (len(x - lastGx, y - lastGy) > D.ghostGap) {  // drop an afterimage every few px
        ghosts.push({ x: x, y: y, h: h, age: 0 }); lastGx = x; lastGy = y;
      }
      for (const g of ghosts) g.age += dt;
      while (ghosts.length && (ghosts[0].age > D.ghostLife || ghosts.length > 40)) ghosts.shift();
      for (const g of ghosts)
        mote(g.x, g.y, g.h, "rgba(138,217,245," + (0.35 * (1 - g.age / D.ghostLife)).toFixed(3) + ")");
      ring(tx, ty, 6, TARGET, 1.5);
      if (cool > 0) {                                  // the cooldown, sweeping shut
        ctx.strokeStyle = HOT; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(x, y, 15, -TAU / 4, -TAU / 4 + TAU * (1 - cool / D.cooldown)); ctx.stroke();
      } else ring(x, y, 15, DIM);
      mote(x, y, h);
      label("v ← v · e^(−k·dt)   k = " + D.k + " /s", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Dash", "Drift", "the same burst with a lazy decay — a long skid off the walls instead of a blink, and almost no cooldown", { k: 1.6, burst: 1.2, cooldown: 0.25 });

def("E", "Ease", "springs", "five motes, one distance, five easing curves — a speed shape over a fixed duration — press to restart the race", function (u) {
  var D = { duration: 1.6, rest: 0.9,                    // seconds per race, seconds at the finish
            overshoot: 1.70158, elastic: 10,             // back-out's overshoot; elastic-out's decay
            names: ["linear", "quad in-out", "cubic out", "elastic out", "back out"],
            label: "x = start + ease(t ÷ duration) · distance" };
  const { ctx, W, H, TAU, stage, line, mote, label, clamp, MOVER, DIM } = u;
  // EASING is a shape for speed over a FIXED duration: k = t/duration runs
  // 0 → 1 like a clock, and ease(k) bends it — slow-fast-slow, a rush then
  // a glide, a wobble past the end and back. a spring needs no duration
  // (it arrives when it arrives); an ease needs no state (it arrives on the
  // dot). the faint curve under each lane is its ease(k), time along x and
  // progress up; the mote's x IS the curve's height, read sideways.
  const E = [
    k => k,
    k => k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2,
    k => 1 - Math.pow(1 - k, 3),
    k => k <= 0 ? 0 : k >= 1 ? 1 : Math.pow(2, -D.elastic * k) * Math.sin((D.elastic * k - 0.75) * (TAU / 3)) + 1,
    k => 1 + (D.overshoot + 1) * Math.pow(k - 1, 3) + D.overshoot * Math.pow(k - 1, 2)
  ];
  let clock = 0;
  const x0 = W * 0.28, x1 = W * 0.84;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      if (clock > D.duration + D.rest) clock = 0;
      const k = clamp(clock / D.duration, 0, 1);       // the clock, normalised
      const top = H * 0.08, laneH = (H * 0.84 - top) / 5;
      line(x0, top, x0, H * 0.84, DIM);
      line(x1, top, x1, H * 0.84, "rgba(245,193,105,0.4)");
      for (let i = 0; i < 5; i++) {
        const ly = top + laneH * (i + 0.5), base = top + laneH * (i + 0.95), gh = laneH * 0.7;
        ctx.strokeStyle = "rgba(232,229,244,0.16)"; ctx.lineWidth = 1;
        ctx.beginPath();
        for (let j = 0; j <= 30; j++) {
          const kk = j / 30, px = x0 + kk * (x1 - x0), py = base - E[i](kk) * gh;
          if (j) ctx.lineTo(px, py); else ctx.moveTo(px, py);
        }
        ctx.stroke();
        const tick = x0 + k * (x1 - x0);
        line(tick, base, tick, base - gh, "rgba(245,193,105,0.25)");
        label(D.names[i], 6, ly + 4, DIM);
        mote(x0 + E[i](k) * (x1 - x0), ly, 0, MOVER, 5);   // ← the whole trick
      }
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Ease", "Eager", "less than half the duration, a wilder overshoot and a longer-ringing elastic — the same five shapes, snappier", { duration: 0.7, overshoot: 2.6, elastic: 6 });

def("I", "Inertia", "springs", "one push on ice, grass and mud — three coefficients, three skids — press to push all three away from your click", function (u) {
  var D = { push: 0.85, g: 2.4,                          // push speed in widths per second; gravity as a fraction of H
            mu: [0.3, 0.9, 2.4], wall: 0.5,              // the three coefficients; restitution at the walls
            autoEvery: 3.4,                              // seconds of stillness before a push of its own
            names: ["ice", "grass", "mud"],
            label: "skid  d = v² ÷ (2·μ·g)" };
  const { W, H, stage, ring, line, mote, arrow, label, clamp, MOVER, GOOD, DIM } = u;
  // FRICTION, Coulomb's version: a sliding body feels a constant backward
  // force μ·g whatever its speed — so v shrinks by μ·g·dt every frame and
  // stops DEAD the moment it would cross zero (no asymptotic creep). the
  // COEFFICIENT μ is the surface's personality: ice 0.3, grass 0.9, mud 2.4.
  // solve v² = 2·a·d and the skid length is v²/(2μg): double the push,
  // four times the slide — the faint ring is that prediction, drawn first.
  const lanes = D.mu.map((m, i) => ({ mu: m, x: W * 0.5, v: 0, face: 1, mark: W * 0.5, y: H * (0.26 + i * 0.22) }));
  const tint = ["rgba(138,217,245,0.4)", "rgba(155,226,138,0.4)", "rgba(245,193,105,0.4)"];
  let quiet = 0, side = 1;
  function push(px) {
    for (const L of lanes) {
      const dir = L.x >= px ? 1 : -1;                  // away from the click
      L.v = dir * D.push * W;
      L.face = dir;
      L.mark = L.x + dir * (L.v * L.v) / (2 * L.mu * D.g * H);   // the skid, predicted
    }
    quiet = 0;
  }
  return {
    press(px, py) { push(px); },
    frame(dt, t) {
      stage();
      const g = D.g * H;
      let moving = false;
      for (const L of lanes) {
        if (L.v !== 0) {
          const dv = L.mu * g * dt;                    // the friction step, speed-blind
          if (Math.abs(L.v) <= dv) L.v = 0;            // would cross zero: stop dead
          else L.v -= Math.sign(L.v) * dv;
          L.x += L.v * dt;
          if (L.x < 8) { L.x = 8; L.v = -L.v * D.wall; }
          if (L.x > W - 8) { L.x = W - 8; L.v = -L.v * D.wall; }
          if (L.v !== 0) moving = true;
        }
      }
      if (!moving) { quiet += dt; if (quiet > D.autoEvery) { side = -side; push(side > 0 ? 0 : W); } }
      lanes.forEach((L, i) => {
        line(0, L.y + 8, W, L.y + 8, tint[i], 1.5);
        label(D.names[i] + "  μ = " + L.mu, 6, L.y - 9, DIM);
        ring(clamp(L.mark, 6, W - 6), L.y, 5, "rgba(232,229,244,0.35)");
        if (L.v !== 0) arrow(L.x, L.y, L.x + L.v * 0.2, L.y, GOOD);
        mote(L.x, L.y, L.face > 0 ? 0 : Math.PI, MOVER, 6);
      });
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Inertia", "Icerink", "every surface half frozen — a gentler push slides further than the hard one did, and nothing stops where you think", { mu: [0.1, 0.28, 0.6], push: 0.5 });

def("W", "Weight", "springs", "three masses on identical springs — ω = √(k/m): heavy is slow and lazy — drag to yank the shared anchor", function (u) {
  var D = { k: 60, c: 0.16,                              // the spring constant; the drag per unit of area
            masses: [1, 3, 9], radius: 5, restLen: 0.26,  // the masses; radius of a unit mass; rest length as a fraction of H
            swapEvery: 3,                                // seconds between the anchor's own yanks
            label: "ω = √(k/m)      drag = c·r²·v" };
  const { ctx, W, H, stage, dot, line, label, clamp, MOVER, BONE, DIM } = u;
  // Hooke's law says the spring force is k × stretch, and Newton's says
  // a = F/m — so the same spring on a heavier ball produces less
  // acceleration, and the natural frequency is ω = √(k/m): nine times the
  // MASS, a third of the tempo. drag here is c·r²·v (air resistance grows
  // with the cross-section), and a ball's radius grows with ∛m, so the
  // big one is slow to start AND slow to stop. the anchor bar is the input.
  const balls = D.masses.map((m, i) => ({ m: m, r: D.radius * Math.cbrt(m), x: W * (0.25 + i * 0.25), y: 0, v: 0 }));
  let anchor = H * 0.1, hold = 0, timer = 0;
  for (const b of balls) b.y = anchor + D.restLen * H;
  return {
    drag: true,
    press(px, py) { anchor = clamp(py, H * 0.06, H * 0.42); hold = 4; },
    frame(dt, t) {
      stage();
      if (hold > 0) hold -= dt;
      else { timer += dt; if (timer > D.swapEvery) { timer = 0; anchor = anchor < H * 0.2 ? H * 0.32 : H * 0.1; } }
      line(W * 0.12, anchor, W * 0.88, anchor, BONE, 2);
      for (const b of balls) {
        const rest = anchor + D.restLen * H;
        const a = (D.k * (rest - b.y) - D.c * b.r * b.r * b.v) / b.m;   // F = k·x − c·r²·v, then a = F/m
        b.v += a * dt; b.y += b.v * dt;
        ctx.strokeStyle = DIM; ctx.lineWidth = 1;      // the spring, a zigzag
        ctx.beginPath(); ctx.moveTo(b.x, anchor);
        const n = 9, top = anchor + 4, bot = b.y - b.r - 2;
        for (let i = 1; i < n; i++) ctx.lineTo(b.x + (i % 2 ? 4 : -4), top + (bot - top) * i / n);
        ctx.lineTo(b.x, b.y - b.r); ctx.stroke();
        dot(b.x, b.y, b.r, MOVER);
        label("m = " + b.m + "  ω = " + Math.sqrt(D.k / b.m).toFixed(1), b.x, H - 20, null, "center");
      }
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Weight", "Wobble", "a stiffer spring, a third of the drag and a 16× spread of mass — everything rings, and the light one shivers", { k: 190, c: 0.06, masses: [1, 4, 16] });

def("Y", "Yank", "springs", "minimum-jerk vs linear vs smoothstep, velocity plotted under each — press to set a new destination", function (u) {
  var D = { duration: 1.4, rest: 0.8,                    // seconds per reach; seconds resting at the end
            vScale: 1, size: 6,                          // height of the velocity graphs; mote size
            names: ["linear", "smoothstep", "min-jerk"],
            label: "p = 10k³ − 15k⁴ + 6k⁵     (jerk = da/dt)" };
  const { ctx, W, H, stage, dot, line, mote, label, rand, clamp, lerp, MOVER, GOOD, TARGET, DIM } = u;
  // JERK is the derivative of acceleration — how fast the force changes.
  // hands and eyes hate it, and the reach that keeps total jerk as small
  // as possible turns out to be one polynomial of k = t/duration:
  //   p = 10k³ − 15k⁴ + 6k⁵     (Flash & Hogan, 1985)
  // it starts and ends with zero velocity AND zero acceleration, so it
  // eases in and out without a single kink. smoothstep (3k² − 2k³) has
  // zero velocity at the ends but not zero acceleration — a tiny click at
  // take-off; linear is all kink. the graphs are v(k): a flat line, a
  // hump, and the taller, narrower bell that reads as a living hand.
  const P = [k => k, k => k * k * (3 - 2 * k), k => k * k * k * (10 - 15 * k + 6 * k * k)];
  const V = [k => 1, k => 6 * k * (1 - k), k => 30 * k * k * (1 - k) * (1 - k)];   // the derivatives
  const tint = ["rgba(232,229,244,0.7)", GOOD, MOVER];
  const lanes = [0, 1, 2].map(i => ({ y: H * (0.17 + i * 0.27), x: W * 0.2, from: W * 0.2 }));
  let to = W * 0.8, clock = 0;
  function go(nx) { for (const L of lanes) L.from = L.x; to = nx; clock = 0; }
  return {
    press(px, py) { go(clamp(px, W * 0.08, W * 0.92)); },
    frame(dt, t) {
      stage();
      clock += dt;
      const k = clamp(clock / D.duration, 0, 1);       // the clock, normalised
      if (clock > D.duration + D.rest) go(to < W / 2 ? rand(W * 0.6, W * 0.9) : rand(W * 0.1, W * 0.4));
      const gx0 = W * 0.2, gx1 = W * 0.86, gh = H * 0.06 * D.vScale;
      lanes.forEach((L, i) => {
        L.x = lerp(L.from, to, P[i](k));               // ← position is the polynomial of the clock
        const base = L.y + H * 0.14;                   // the velocity graph: time along, speed up
        line(gx0, base, gx1, base, "rgba(232,229,244,0.12)");
        ctx.strokeStyle = "rgba(232,229,244,0.2)"; ctx.lineWidth = 1;
        ctx.beginPath();
        for (let j = 0; j <= 24; j++) {
          const kk = j / 24, px = lerp(gx0, gx1, kk), py = base - V[i](kk) / 1.875 * gh;
          if (j) ctx.lineTo(px, py); else ctx.moveTo(px, py);
        }
        ctx.stroke();
        dot(lerp(gx0, gx1, k), base - V[i](k) / 1.875 * gh, 2, tint[i]);
        label(D.names[i], 6, L.y - 10, DIM);
        line(to, L.y - 7, to, L.y + 7, TARGET, 1.5);   // the destination tick
        mote(L.x, L.y, to >= L.from ? 0 : Math.PI, tint[i], D.size);
      });
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Yank", "Yawn", "the same three reaches at half the speed, the velocity graphs stretched tall — watch the bell of the human one", { duration: 3.2, rest: 1.6, vScale: 1.6 });

def("U", "Umbrella", "springs", "terminal velocity: a = g − c·v² settles where drag equals gravity — press to open or close the umbrella", function (u) {
  var D = { g: 1.6, cOpen: 13, cClosed: 0.4,             // gravity as a fraction of H; drag coefficients (× 1/H) open and closed
            sway: 1.2, swayAmp: 0.09, canopy: 0.1,       // sway rate, sideways drift as a fraction of H per second, canopy radius
            wait: 0.7, autoFlip: 8,                      // seconds on the ground; seconds unpressed before it flips itself
            label: "a = g − c·v²   →   terminal v = √(g/c)" };
  const { ctx, W, H, GY, stage, ground, line, rect, mote, label, rand, clamp, TARGET, HOT, DIM, BONE } = u;
  // air DRAG grows with the SQUARE of speed (twice as fast, four times the
  // push-back), so a falling body speeds up until c·v² equals g and the
  // acceleration hits zero: that speed, √(g/c), is the TERMINAL VELOCITY.
  // an open canopy has a huge c and a tiny terminal speed; fold it and c
  // drops thirtyfold. the gauge on the right shows v climbing toward the
  // amber terminal line. the sideways drift is a slow sine on the tilt.
  let x = W / 2, y = -20, vy = 0, open = true, phase = "fall", timer = 0, sincePress = 0;
  return {
    press(px, py) { open = !open; sincePress = 0; },
    frame(dt, t) {
      stage(); ground();
      const g = D.g * H, c = (open ? D.cOpen : D.cClosed) / H;
      const vt = Math.sqrt(g / c);                     // where drag and gravity cancel
      sincePress += dt; timer += dt;
      let tilt = 0;
      if (phase === "fall") {
        vy += g * dt;
        vy -= clamp(c * vy * Math.abs(vy) * dt, -Math.abs(vy), Math.abs(vy));   // drag may slow you, never reverse you
        tilt = open ? Math.sin(t * D.sway) * 0.3 : 0;
        const drift = open ? Math.sin(t * D.sway) * D.swayAmp * H : 0;
        x = clamp(x + drift * dt, W * 0.15, W * 0.85);
        y += vy * dt;
        if (y >= GY - 9) { y = GY - 9; phase = "land"; timer = 0; }
      } else if (timer > D.wait) {
        phase = "fall"; y = -20; vy = 0; x = rand(W * 0.3, W * 0.7);
        if (sincePress > D.autoFlip) open = !open;     // left alone, it shows both falls
      }
      const gx = W - 14, gTop = H * 0.15, gBot = H * 0.7;   // the speed gauge
      const vmax = Math.sqrt(g / (D.cClosed / H)) * 1.05;
      rect(gx, gTop, 5, gBot - gTop, "rgba(232,229,244,0.08)");
      const vh = clamp(vy / vmax, 0, 1) * (gBot - gTop);
      rect(gx, gBot - vh, 5, vh, HOT);
      const ty = gBot - clamp(vt / vmax, 0, 1) * (gBot - gTop);
      line(gx - 4, ty, gx + 9, ty, TARGET, 1.5);
      label("√(g/c)", gx - 6, ty + 4, "rgba(245,193,105,0.8)", "right");
      label("v", gx - 8, gBot + 4, DIM);
      const R = D.canopy * H, hx = x, hy = y - 10;     // hand, handle, canopy
      const topx = hx + Math.sin(tilt) * R * 1.5, topy = hy - Math.cos(tilt) * R * 1.5;
      line(hx, hy, topx, topy, BONE, 1.5);
      ctx.save(); ctx.translate(topx, topy); ctx.rotate(tilt);
      ctx.fillStyle = TARGET;
      if (open) {
        ctx.beginPath(); ctx.arc(0, 0, R, Math.PI, 0); ctx.closePath(); ctx.fill();
        for (let i = -1; i <= 1; i++) { ctx.beginPath(); ctx.arc(i * R * 0.67, 0, R * 0.33, 0, Math.PI); ctx.fill(); }
      } else {
        ctx.beginPath(); ctx.moveTo(0, -R * 0.3); ctx.lineTo(3, R * 0.9); ctx.lineTo(-3, R * 0.9); ctx.closePath(); ctx.fill();
      }
      ctx.restore();
      mote(x, y, 0);
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Umbrella", "Ultralight", "lighter, three times the canopy drag and a quicker sway — it drifts down like a dandelion seed", { g: 0.9, cOpen: 40, sway: 2.2 });

def("Q", "Quicksand", "springs", "drag thickens with depth; a struggle lifts, then sinks you faster — press to struggle, click above for a rope", function (u) {
  var D = { g: 0.9, c0: 4, cGrow: 14,                    // gravity as a fraction of H; drag at the surface; how fast it thickens with depth
            kick: 0.45, panicMul: 3, panicTime: 0.7,     // a struggle's upward kick (× H per second); panic gravity; seconds of panic
            autoStruggle: 1.6, drown: 0.2,               // seconds between its own struggles; depth (× H) that swallows it
            ropeSpeed: 0.5,                              // climbing speed as a fraction of H per second
            label: "a = g − c·v,    c = c₀·(1 + depth·k)" };
  const { W, H, GY, stage, ground, ring, line, rect, mote, label, rand, clamp, len, HOT, BONE, DIM } = u;
  // VISCOUS drag is proportional to the speed itself (Stokes' law: slow
  // things in thick fluids), so the sinking speed settles at g/c. here c
  // grows with depth — the deeper you are, the thicker the sand, and the
  // slower but surer you go. a struggle is an upward IMPULSE (a kick to v)
  // and its price is PANIC: gravity counts triple for a moment, because
  // churned sand flows back thicker. the only real exit is a thing to pull on.
  let x = W * 0.5, y = GY - 6, vy = 0, panic = 0, since = 0, phase = "sink", timer = 0, hang = 0;
  let ropeX = 0, ripple = 0;
  function struggle() { vy -= D.kick * H; panic = D.panicTime; since = 0; ripple = 1; }
  return {
    press(px, py) {
      if (phase === "climb" || phase === "gulp") return;
      if (py < GY - 14) { ropeX = clamp(px, 14, W - 14); phase = "climb"; hang = 0; }
      else struggle();
    },
    frame(dt, t) {
      stage();
      const g = D.g * H, surf = GY - 6;
      timer += dt; since += dt;
      panic = Math.max(0, panic - dt); ripple = Math.max(0, ripple - dt * 1.6);
      let depth = Math.max(0, y - surf);
      if (phase === "sink" || phase === "drop") {
        const c = depth > 0 ? D.c0 * (1 + depth / H * D.cGrow) : 0;   // thicker with depth; none in the air
        vy += g * (panic > 0 ? D.panicMul : 1) * dt;
        vy -= clamp(c * vy * dt, -Math.abs(vy), Math.abs(vy));       // drag ∝ v — it may slow, never reverse
        y += vy * dt;
        depth = Math.max(0, y - surf);
        if (phase === "drop" && depth > 0) { phase = "sink"; vy *= 0.3; ripple = 1; since = 0; }
        if (phase === "sink" && since > D.autoStruggle && depth > 4) struggle();   // it panics on its own
        if (depth > D.drown * H) { phase = "gulp"; timer = 0; ripple = 1; }
      } else if (phase === "climb") {                  // hand over hand up the rope
        const dx = ropeX - x, dy = H * 0.2 - y, d = len(dx, dy), step = D.ropeSpeed * H * dt;
        if (d > step) { x += dx / d * step; y += dy / d * step; }
        else { x = ropeX; y = H * 0.2; hang += dt; if (hang > 0.9) { phase = "drop"; vy = 0; since = 0; } }
      } else if (phase === "gulp" && timer > 1) {      // swallowed — and dropped in again
        phase = "drop"; x = rand(W * 0.3, W * 0.7); y = -16; vy = 0; panic = 0; since = 0;
      }
      if (phase === "climb") line(ropeX, 0, x, y - 8, BONE, 1.5);
      if (phase !== "gulp") mote(x, y, phase === "climb" || vy < -10 ? -Math.PI / 2 : 0);
      rect(0, GY, W, H - GY, "rgba(58,44,38,0.55)");   // the sand, over whatever sank (thin enough to see it go)
      ground();
      if (ripple > 0 && phase !== "climb" && phase !== "drop")
        ring(x, GY, 6 + (1 - ripple) * 14, "rgba(245,193,105," + (ripple * 0.7).toFixed(3) + ")", 1.5);
      if (panic > 0 && phase === "sink") label("!", x + 12, y - 6, HOT);
      if (phase === "sink") label("depth " + Math.round(depth) + " px", W - 6, GY - 8, DIM, "right");
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Quicksand", "Quagmire", "thicker mud: it barely sinks at all — until it struggles, and then it goes down like a stone", { c0: 9, cGrow: 30, panicMul: 6 });

def("S", "Slime", "springs", "squash & stretch from velocity — sy = 1 + |vy|·k, and sx = 1/sy keeps the volume — press to set the target", function (u) {
  var D = { g: 2.2, apex: 0.15, hop: 0.24,               // gravity and apex as fractions of H; a hop's reach as a fraction of W
            stretch: 0.3,                                // stretch at launch speed
            crouch: 0.3, splat: 0.22, sit: 0.4,          // seconds crouching, splatted, sitting
            radius: 10, label: "sy = 1 + |vy|·k      sx = 1 ÷ sy" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, label, rand, clamp, MOVER, TARGET } = u;
  // SQUASH & STRETCH, the first of the twelve animation principles, done
  // by formula: stretch along the velocity (sy grows with |vy|) and keep
  // the VOLUME constant by shrinking the other axis (sx = 1/sy). the
  // crouch before take-off is ANTICIPATION, the splat is FOLLOW-THROUGH —
  // both are just sy < 1 on a timer. the hop itself is Jump's parabola
  // (v₀ = √(2gh)) with vx chosen so it lands one hop nearer the target.
  let x = W * 0.3, y = GY, vx = 0, vy = 0, dir = 1, tx = W * 0.72;
  let phase = "sit", timer = 0, v0 = 1;
  return {
    press(px, py) { tx = clamp(px, D.radius, W - D.radius); },
    frame(dt, t) {
      stage(); ground();
      const g = D.g * H, r = D.radius;
      timer += dt;
      let sy = 1;
      if (phase === "sit" && timer > D.sit) {
        if (Math.abs(tx - x) < 6) tx = rand(W * 0.1, W * 0.9);     // reached it: a new errand
        phase = "crouch"; timer = 0;
      }
      if (phase === "crouch") {
        sy = 1 - 0.35 * Math.min(1, timer / D.crouch); // anticipation: load the spring
        if (timer > D.crouch) {
          const gap = tx - x;
          dir = gap >= 0 ? 1 : -1;
          const reach = Math.min(Math.abs(gap), D.hop * W);
          v0 = Math.sqrt(2 * g * D.apex * H);          // Jump's launch speed
          const T = 2 * v0 / g;                        // airtime: up and down
          vx = dir * reach / T; vy = -v0;
          phase = "air"; timer = 0;
        }
      }
      if (phase === "air") {
        vy += g * dt; x += vx * dt; y += vy * dt;
        sy = 1 + Math.abs(vy) / v0 * D.stretch;        // ← stretch from speed (k = stretch ÷ v₀)
        if (y >= GY) { y = GY; vx = 0; vy = 0; phase = "splat"; timer = 0; }
      }
      if (phase === "splat") {
        sy = 1 - 0.45 * (1 - Math.min(1, timer / D.splat));   // follow-through, recovering
        if (timer > D.splat) { phase = "sit"; timer = 0; }
      }
      x = clamp(x, r, W - r);
      const sx = 1 / sy;                               // ← volume preserved
      ring(tx, GY - 4, 5, TARGET, 1.5); dot(tx, GY - 4, 2, TARGET);
      ctx.save();
      ctx.translate(x, y - r * sy);                    // scale about the feet, not the centre
      ctx.scale(sx, sy);
      ctx.fillStyle = MOVER;
      ctx.beginPath(); ctx.arc(0, 0, r, 0, TAU); ctx.fill();
      ctx.fillStyle = "#131020";
      ctx.beginPath(); ctx.arc(dir * r * 0.4, -r * 0.25, r * 0.2, 0, TAU); ctx.fill();
      ctx.restore();
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Slime", "Sludge", "a heavy blob: tiny hops, long sits — the same squash rules on a much lazier body", { apex: 0.05, hop: 0.1, sit: 0.9 });

def("C", "Cat", "springs", "a pounce: a butt-wiggle crouch (anticipation), then one parabola aimed at the toy — press to move the toy", function (u) {
  var D = { g: 2.6, apex: 0.2,                           // gravity and apex as fractions of H
            sit: 1.1, crouch: 0.6, land: 0.16,           // seconds sitting, crouching, landing
            wiggle: 18, tail: 3,                         // the butt-wiggle's rate; the tail's sway rate (rad/s)
            label: "v₀ = √(2gh)      vx = distance ÷ airtime" };
  const { ctx, W, H, GY, stage, ground, dot, ring, poly, label, rand, clamp, MOVER, TARGET } = u;
  // ANTICIPATION: a motion reads better if the body first moves a little
  // the other way — the crouch loads the spring, and the butt-wiggle (a
  // quick sine, ~3 Hz) is the cat aiming. then the pounce is pure Jump:
  // pick the apex h, v₀ = √(2gh) fixes the airtime T = 2v₀/g, and
  // vx = distance/T lands it on the toy exactly. once airborne nothing can
  // be corrected — a pounce is BALLISTIC, which is why cats miss.
  let x = W * 0.25, y = GY, vx = 0, vy = 0, dir = 1, tx = W * 0.7;
  let phase = "sit", timer = 0;
  function drawCat(ox, oy, sx, sy, wig, tilt, t) {
    ctx.save();
    ctx.translate(ox, oy); ctx.rotate(tilt); ctx.scale(sx, sy);   // scale about the paws
    const bx = -dir * 8 + wig, by = -7;                // the body, behind the head
    dot(bx, by, 7, "rgba(138,217,245,0.85)");
    for (let i = 0; i < 6; i++) {                      // the tail sways on a sine
      const s = Math.sin(t * D.tail + i * 0.7) * i * 1.4;
      dot(bx - dir * (6 + i * 3.6), by - i * 2.4 - s, 2.4 - i * 0.2, "rgba(138,217,245,0.6)");
    }
    const hx = dir * 6, hy = -11;
    dot(hx, hy, 6, MOVER);
    poly([[hx - dir * 5, hy - 3], [hx - dir * 4, hy - 10], [hx - dir * 1, hy - 5]], MOVER);   // ears
    poly([[hx + dir * 1, hy - 5], [hx + dir * 4, hy - 10], [hx + dir * 5, hy - 3]], MOVER);
    dot(hx + dir * 2.4, hy - 1, 1.4, "#131020");       // the eye, on the toy
    ctx.restore();
  }
  return {
    press(px, py) { tx = clamp(px, W * 0.06, W * 0.94); },
    frame(dt, t) {
      stage(); ground();
      const g = D.g * H;
      timer += dt;
      let sx = 1, sy = 1, wig = 0, tilt = 0;
      if (phase === "sit" && timer > D.sit) {
        if (Math.abs(tx - x) < 12)                     // caught it — the toy escapes
          tx = x < W / 2 ? rand(W * 0.6, W * 0.9) : rand(W * 0.1, W * 0.4);
        phase = "crouch"; timer = 0;
      }
      if (phase === "crouch") {
        dir = tx >= x ? 1 : -1;
        sy = 0.8; sx = 1.1;
        wig = Math.sin(timer * D.wiggle) * 1.6 * Math.min(1, timer * 4);   // the quick sine
        const h = D.apex * H, v0 = Math.sqrt(2 * g * h), T = 2 * v0 / g;
        const aim = (tx - x) / T;                      // vx that lands exactly on the toy
        for (let i = 1; i < 14; i++) {                 // the predicted arc, dotted
          const k = i / 14;
          dot(x + aim * T * k, GY - 4 * h * k * (1 - k), 1.2, "rgba(232,229,244,0.3)");
        }
        if (timer > D.crouch) { vx = aim; vy = -v0; phase = "air"; timer = 0; }
      }
      if (phase === "air") {
        vy += g * dt; x += vx * dt; y += vy * dt;
        const climb = Math.atan2(-vy, Math.abs(vx));   // nose up on the rise, down on the fall
        tilt = -dir * climb * 0.5;
        sx = 1.1; sy = 0.95;
        if (y >= GY) { y = GY; vx = 0; vy = 0; phase = "land"; timer = 0; }
      }
      if (phase === "land") { sx = 1.15; sy = 0.78; if (timer > D.land) { phase = "sit"; timer = 0; } }
      x = clamp(x, 14, W - 14);
      dot(tx, GY - 4, 4, TARGET); ring(tx, GY - 4, 7, "rgba(245,193,105,0.5)");   // the toy: a ball of yarn
      drawCat(x, y, sx, sy, wig, tilt, t);
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Cat", "Cougar", "a bigger cat: a higher, floatier arc and a longer, more menacing crouch before the spring", { apex: 0.42, g: 2.0, crouch: 1.0 });

/* ============================== HEADINGS & VEHICLES ==============================
   A body that remembers an ANGLE. Position says where a thing is; a
   heading says which way it points — and a vehicle may only move the way
   it points, so every change of mind costs a turn, and the time a turn
   takes is what a reader feels as weight. Turn-rate limits, look-at
   smoothing, thrust along the nose, wheels that roll instead of slide, a
   tilt that leans into every acceleration: everything here steers. */

def("Y", "Yaw", "headings", "a heading with a turn-rate limit — press to plant the flag", function (u) {
  var D = { speed: 84, turn: 2.0,                       // px/s, and radians of turning per second
            trail: 70, retarget: 7,                     // history dots kept; seconds before a fresh flag
            label: "turn radius = speed ÷ turn rate ≈ " };
  const { ctx, W, H, TAU, stage, dot, ring, mote, label, wrapAngle, clamp, len, rand, TARGET, DIM } = u;
  // the mote can't teleport its direction: it stores a HEADING angle and may
  // only turn so many radians per second. atan2 (inverse trig) names the
  // angle to the flag; wrapAngle picks the short way round; the clamp is
  // the personality. the faint circles are its turning radius — aim inside
  // one and it must loop all the way around. cars, missiles, geese: this.
  let x = W * 0.3, y = H * 0.6, h = 0, timer = 0;
  let tx = W * 0.7, ty = H * 0.4;
  const SPEED = D.speed, TURN = D.turn;
  let trail = [];
  return {
    press(px, py) { tx = px; ty = py; timer = -6; },
    frame(dt, t) {
      stage();
      timer += dt;
      const want = Math.atan2(ty - y, tx - x);         // inverse trig: point → angle
      h += clamp(wrapAngle(want - h), -TURN * dt, TURN * dt);
      x += Math.cos(h) * SPEED * dt;                   // forward trig: angle → motion
      y += Math.sin(h) * SPEED * dt;
      if (x < -12) x = W + 12; if (x > W + 12) x = -12;
      if (y < -12) y = H + 12; if (y > H + 12) y = -12;
      if (len(tx - x, ty - y) < 15 || timer > D.retarget) {
        timer = 0; tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.2, H * 0.8);
      }
      const R = SPEED / TURN;                          // the physics of "too close to aim at"
      ring(x + Math.cos(h + TAU / 4) * R, y + Math.sin(h + TAU / 4) * R, R, "rgba(232,229,244,0.08)");
      ring(x + Math.cos(h - TAU / 4) * R, y + Math.sin(h - TAU / 4) * R, R, "rgba(232,229,244,0.08)");
      trail.push([x, y]);
      if (trail.length > D.trail) trail.shift();
      for (let i = 0; i < trail.length; i++)
        dot(trail[i][0], trail[i][1], 1.3, "rgba(138,217,245," + (i / trail.length * 0.3) + ")");
      ctx.strokeStyle = TARGET; ctx.lineWidth = 1.5;   // the flag
      ctx.beginPath(); ctx.moveTo(tx, ty + 8); ctx.lineTo(tx, ty - 10); ctx.stroke();
      ctx.fillStyle = TARGET;
      ctx.beginPath(); ctx.moveTo(tx, ty - 10); ctx.lineTo(tx + 9, ty - 6.5); ctx.lineTo(tx, ty - 3); ctx.closePath(); ctx.fill();
      mote(x, y, h);
      label(D.label + Math.round(R) + " px", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Yaw", "Yawl", "the same rule with the turn rate at 0.8 rad/s — a sailing boat that needs the whole pond to come about", { speed: 70, turn: 0.8, retarget: 9 });

def("L", "Lookat", "headings", "a turret tracks a moving target the short way round, smoothed, inside a cone — press to move the target", function (u) {
  var D = { cone: 60,                                   // the cone's half-angle, in degrees, either side of the mount
            rate: 6,                                    // smoothing rate: bigger = snappier, smaller = lazier
            barrel: 0.2,                                // barrel length as a fraction of H
            hold: 4,                                    // seconds your target stays where you put it
            label: "θ += wrap(want − θ) · (1 − e^(−rate·dt))" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, label, wrapAngle, clamp, smooth, lerp, TARGET, BONE, DIM, HOT } = u;
  // LOOK-AT is atan2 plus manners. the raw angle to a target can jump — it
  // flips from +179° to −179° as the target crosses behind — so wrapAngle
  // folds the gap into −π..π and the turret takes the SHORT ARC, closing a
  // framerate-proof fraction of it each frame (a lerp on an angle: the
  // thing engines call lerp_angle). the CONE is a clamp on the angle
  // relative to the mount: eyes, heads and turrets all have one, and past
  // its edge the turret can only wait at the rim.
  const MOUNT = -TAU / 4;                               // it is mounted facing straight up
  let ang = MOUNT, tx = W * 0.7, ty = H * 0.3, hold = 0;
  return {
    press(x, y) { tx = x; ty = y; hold = D.hold; },
    frame(dt, t) {
      stage(); ground();
      const mx = W / 2, my = GY - 4;
      hold = Math.max(0, hold - dt);
      if (hold <= 0) {                                  // an idle target crosses the sky on two sines
        const ax = W / 2 + Math.cos(t * 0.5) * W * 0.42, ay = H * 0.35 + Math.sin(t * 0.9) * H * 0.25;
        tx = lerp(tx, ax, smooth(2, dt)); ty = lerp(ty, ay, smooth(2, dt));
      }
      const cone = D.cone * Math.PI / 180;
      const raw = Math.atan2(ty - my, tx - mx);         // inverse trig: point → angle
      const off = wrapAngle(raw - MOUNT);               // the angle relative to the mount
      const rel = clamp(off, -cone, cone);              // the cone: a clamp on that angle
      const want = MOUNT + rel;
      ang += wrapAngle(want - ang) * smooth(D.rate, dt);   // the short arc, a fraction per frame
      const L = H * D.barrel, CL = H * 0.55;
      line(mx, my, mx + Math.cos(MOUNT - cone) * CL, my + Math.sin(MOUNT - cone) * CL, "rgba(232,229,244,0.14)");
      line(mx, my, mx + Math.cos(MOUNT + cone) * CL, my + Math.sin(MOUNT + cone) * CL, "rgba(232,229,244,0.14)");
      ctx.strokeStyle = "rgba(232,229,244,0.14)"; ctx.lineWidth = 1;   // the cone's rim, as an arc
      ctx.beginPath(); ctx.arc(mx, my, CL, MOUNT - cone, MOUNT + cone); ctx.stroke();
      ctx.setLineDash([3, 4]);                          // the raw angle: where atan2 says
      line(mx, my, tx, ty, "rgba(245,193,105,0.35)");
      ctx.setLineDash([]);
      ctx.fillStyle = "rgba(201,196,228,0.5)";          // the mount
      ctx.beginPath(); ctx.arc(mx, my, 9, Math.PI, 0); ctx.fill();
      line(mx, my, mx + Math.cos(ang) * L, my + Math.sin(ang) * L, BONE, 4);   // the smoothed barrel
      dot(mx, my, 4, BONE);
      dot(tx, ty, 5, TARGET);
      ring(tx, ty, 9, TARGET, 1);
      if (Math.abs(off) > cone) label("out of cone", mx + Math.cos(ang) * (L + 8), my + Math.sin(ang) * (L + 8) - 4, HOT, "center");
      label("raw " + Math.round(off * 180 / Math.PI) + "°  →  turret " + Math.round(wrapAngle(ang - MOUNT) * 180 / Math.PI) + "°", W / 2, 14, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Lookat", "Lighthouse", "a wide cone and a smoothing rate of 1 — a heavy lamp that sweeps after its target and arrives late", { cone: 150, rate: 1.0, barrel: 0.3 });

def("U", "Upright", "headings", "self-righting: a spring-damper on an angle, plus a boat doing the same on a wave — press to tip them", function (u) {
  var D = { k: 40, c: 6,                                // angular stiffness (wants to be up) and damping (hates swinging)
            kick: 4.5,                                  // radians per second a press adds
            waveAmp: 0.05, waveSpeed: 2.2,              // the boat's sea: height as a fraction of H, and its speed
            autoKick: 3.5,                              // seconds between the shoves it gives itself
            label: "α = −k·θ − c·ω   (a spring on an angle)" };
  const { ctx, W, H, GY, TAU, stage, dot, line, poly, label, clamp, MOVER, BONE, DIM } = u;
  // an ANGULAR spring-damper: Damp's equation with the angle θ in place of
  // a position and ω (angular velocity) in place of speed — α = −k·θ − c·ω,
  // integrated twice a frame like Pendulum. the capsule's "up" is fixed;
  // the boat's "up" is the wave's NORMAL, which never stops moving, so it
  // never quite settles — that lag is why boats rock. wobble toys, ships,
  // self-balancing robots, a knocked-down enemy getting up: this.
  const cap = { th: 0.35, om: 0 }, boat = { th: 0, om: 0 };
  let timer = 0, side = 1;
  function spring(b, target, dt) {
    b.om += (-D.k * (b.th - target) - D.c * b.om) * dt;
    b.th += b.om * dt;
    const lim = TAU / 4 - 0.12;                         // lying down is as far as it goes
    if (b.th > lim) { b.th = lim; b.om = Math.min(0, b.om); }
    if (b.th < -lim) { b.th = -lim; b.om = Math.max(0, b.om); }
  }
  const kx = 0.05;                                      // the wave's spatial frequency
  function wave(x, t) { return GY - H * 0.06 + Math.sin(x * kx - t * D.waveSpeed) * H * D.waveAmp; }
  function slope(x, t) { return Math.cos(x * kx - t * D.waveSpeed) * H * D.waveAmp * kx; }   // its derivative
  return {
    press(x, y) {                                       // a shove: each body falls AWAY from the click
      cap.om += (x < W * 0.27 ? 1 : -1) * D.kick;
      boat.om += (x < W * 0.72 ? 1 : -1) * D.kick;
      timer = -4;
    },
    frame(dt, t) {
      stage();
      const cx = W * 0.27, bx = W * 0.72;
      timer += dt;
      if (timer > D.autoKick) { timer = 0; side = -side; cap.om += side * D.kick; boat.om += side * D.kick * 0.6; }   // it shoves itself, alternating
      spring(cap, 0, dt);                               // "up" is 0
      spring(boat, Math.atan(slope(bx, t)), dt);        // "up" is the wave's normal
      line(0, GY, W * 0.48, GY, "rgba(201,196,228,0.5)", 1.5);   // the capsule's floor
      ctx.strokeStyle = "rgba(201,196,228,0.5)"; ctx.lineWidth = 1.5;   // the sea
      ctx.fillStyle = "rgba(138,217,245,0.08)";
      ctx.beginPath(); ctx.moveTo(W * 0.5, wave(W * 0.5, t));
      for (let x = W * 0.5 + 4; x <= W; x += 4) ctx.lineTo(x, wave(x, t));
      ctx.stroke();
      ctx.lineTo(W, H); ctx.lineTo(W * 0.5, H); ctx.closePath(); ctx.fill();
      const CL = H * 0.22;                              // the capsule: pivot at its foot
      const tx = cx + Math.sin(cap.th) * CL, ty = GY - Math.cos(cap.th) * CL;
      ctx.lineCap = "round";
      line(cx, GY - 7, tx, ty, MOVER, 14);
      ctx.lineCap = "butt";
      line(cx, GY - 7, cx + Math.sin(cap.th) * CL * 0.5, GY - 7 - Math.cos(cap.th) * CL * 0.5, "rgba(19,16,32,0.35)", 2);
      dot(tx + Math.cos(cap.th) * 3, ty + Math.sin(cap.th) * 3, 2, "#131020");
      line(cx, GY - 7, cx, GY - 7 - CL - 8, DIM);       // the "up" it wants
      const by = wave(bx, t);
      ctx.save();
      ctx.translate(bx, by);
      ctx.rotate(boat.th);
      poly([[-16, -2], [16, -2], [11, 7], [-11, 7]], MOVER);   // the hull
      line(0, -2, 0, -H * 0.16, BONE, 2);               // the mast
      poly([[0, -H * 0.16 + 2], [12, -H * 0.08], [0, -H * 0.07]], "rgba(201,196,228,0.5)");
      ctx.restore();
      line(bx, by, bx - Math.sin(Math.atan(slope(bx, t))) * 26, by - Math.cos(Math.atan(slope(bx, t))) * 26, "rgba(155,226,138,0.5)");
      label("θ = " + (cap.th * 180 / Math.PI).toFixed(0) + "°", cx, H * 0.16, DIM, "center");
      label("up = the wave's normal", bx, H * 0.16, "rgba(155,226,138,0.6)", "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Upright", "Unicycle", "a third of the stiffness and a quarter of the damping — a wobbly balancer that rings for seconds after each shove", { k: 12, c: 1.5, kick: 3 });

def("V", "Vehicle", "headings", "the bicycle model: heading turns at v/L · tan(steer) — a wheelbase, not a turn limit — press to set the goal", function (u) {
  var D = { speed: 90, wheelbase: 0.11,                 // px/s; L, the axle-to-axle distance, as a fraction of W
            lock: 35, steerRate: 5,                     // full steering lock in degrees; how fast the wheel turns (1/s)
            trail: 80,
            label: "heading += v ÷ L · tan(steer) · dt" };
  const { ctx, W, H, TAU, stage, dot, ring, line, rect, label, wrapAngle, clamp, smooth, len, rand, MOVER, BONE, TARGET, DIM } = u;
  // Yaw turned by decree; a car turns because its front wheels point
  // somewhere its body doesn't. the BICYCLE MODEL collapses four wheels to
  // two: the rear axle drives straight ahead, the front axle is turned by
  // the STEER angle, and geometry says the heading changes at v/L·tan(steer)
  // — L being the WHEELBASE. a long L or a small steering lock means a big
  // turning circle (R = L ÷ tan(steer)); and stopped dead, it cannot turn
  // at all — the difference between a car and Yaw's goose.
  let x = W * 0.3, y = H * 0.6, h = 0, steer = 0, timer = 0;
  let tx = W * 0.7, ty = H * 0.4;
  let trail = [];
  return {
    press(px, py) { tx = px; ty = py; timer = -6; },
    frame(dt, t) {
      stage();
      timer += dt;
      const L = W * D.wheelbase, LOCK = D.lock * Math.PI / 180;
      const want = Math.atan2(ty - y, tx - x);
      const wantSteer = clamp(wrapAngle(want - h), -LOCK, LOCK);   // the wheel can only turn so far
      steer += (wantSteer - steer) * smooth(D.steerRate, dt);       // and only so fast
      h += D.speed / L * Math.tan(steer) * dt;         // ← the bicycle model, whole
      x += Math.cos(h) * D.speed * dt;
      y += Math.sin(h) * D.speed * dt;
      if (x < -L) x = W + L; if (x > W + L) x = -L;
      if (y < -L) y = H + L; if (y > H + L) y = -L;
      if (len(tx - x, ty - y) < 14 || timer > 8) {
        timer = 0; tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.2, H * 0.8);
      }
      if (Math.abs(steer) > 0.03) {                     // the turning circle this steer angle buys
        const R = L / Math.tan(steer);
        ring(x - Math.sin(h) * R, y + Math.cos(h) * R, Math.abs(R), "rgba(232,229,244,0.08)");
      }
      trail.push([x, y]);
      if (trail.length > D.trail) trail.shift();
      for (let i = 0; i < trail.length; i++)
        dot(trail[i][0], trail[i][1], 1.3, "rgba(138,217,245," + (i / trail.length * 0.3) + ")");
      ring(tx, ty, 8, TARGET, 1.5);
      dot(tx, ty, 2.5, TARGET);
      const w = L * 0.36;
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(h);
      rect(-L * 0.3, -w * 0.8, L * 1.55, w * 1.6, MOVER);          // the body, rear axle at the origin
      rect(0 - 3, -w - 2, 6, 4, BONE); rect(0 - 3, w - 2, 6, 4, BONE);   // rear wheels: always straight
      for (const s of [-1, 1]) {                        // front wheels: turned by the steer angle
        ctx.save(); ctx.translate(L, s * w); ctx.rotate(steer);
        rect(-3, -2, 6, 4, BONE);
        ctx.restore();
      }
      ctx.fillStyle = "#131020";
      ctx.beginPath(); ctx.arc(L * 0.9, -w * 0.3, 2, 0, TAU); ctx.fill();
      ctx.restore();
      label("steer " + Math.round(steer * 180 / Math.PI) + "°  ·  L = " + Math.round(L) + " px", W / 2, 14, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Vehicle", "Van", "twice the wheelbase and half the steering lock — a long van whose turning circle is most of the card", { wheelbase: 0.2, lock: 18, speed: 70 });

def("M", "Motor", "headings", "rolling without slipping: ω = v ÷ r, so the big wheel turns half as fast — press to set the speed (x → speed)", function (u) {
  var D = { radius: 0.09,                               // the small wheel as a fraction of H; the big one is 2×
            accel: 110, maxSpeed: 150,                  // throttle/brake in px/s²; flat out in px/s
            spokes: 4,
            hold: 5,                                    // seconds your speed setting lasts
            label: "ω = v ÷ r   (the spokes can't lie)" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, arrow, label, clamp, MOVER, BONE, HOT, TARGET, DIM } = u;
  // ROLLING WITHOUT SLIPPING: the wheel's rim moves at the ground's speed,
  // so one rotation carries it exactly one circumference — which pins the
  // spin rate to ω = v ÷ r. it is the whole reason wheels, gears and
  // rolling balls look wrong when their spin is faked: a wheel twice as
  // wide MUST turn half as fast. the red dot is the contact point — for an
  // instant it isn't moving at all. speed changes by move_toward (Lerp).
  let x = W * 0.3, v = 0, target = D.maxSpeed * 0.6, spinS = 0, spinB = 0, timer = 0, hold = 0, sched = 0;
  const PLAN = [1, 0.35, 0, -0.5];                      // the auto schedule, as fractions of maxSpeed
  return {
    press(px, py) { target = clamp((px / W - 0.5) * 2 * D.maxSpeed, -D.maxSpeed, D.maxSpeed); hold = D.hold; },
    frame(dt, t) {
      stage(); ground();
      if (hold > 0) hold -= dt;
      else { timer += dt; if (timer > 3.5) { timer = 0; sched = (sched + 1) % PLAN.length; target = PLAN[sched] * D.maxSpeed; } }
      const dv = target - v, step = D.accel * dt;       // throttle and brake: a fixed step toward the target
      v += Math.abs(dv) < step ? dv : Math.sign(dv) * step;
      const rS = H * D.radius, rB = rS * 2;
      spinS += v / rS * dt;                             // ← ω = v ÷ r, twice
      spinB += v / rB * dt;
      x += v * dt;
      const span = rS + rB + 8;
      if (x > W + rB + 2) x = -span - rS - 2; if (x < -span - rS - 2) x = W + rB + 2;
      const xs = x + span, xb = x;                       // the big wheel leads, the small one trails
      line(xb, GY - rB, xs, GY - rS, BONE, 2);          // the axle bar joining them
      for (const wh of [[xb, rB, spinB], [xs, rS, spinS]]) {
        const wx = wh[0], r = wh[1], a = wh[2];
        ring(wx, GY - r, r, MOVER, 2.5);
        for (let i = 0; i < D.spokes; i++) {
          const sa = a + i * TAU / D.spokes;
          line(wx, GY - r, wx + Math.cos(sa) * r, GY - r + Math.sin(sa) * r, "rgba(138,217,245,0.6)", 1.5);
        }
        dot(wx, GY - r, 3, BONE);
        dot(wx, GY - 1, 2.5, HOT);                      // the contact point: momentarily at rest
        label("ω = " + (v / r).toFixed(1), wx, GY - r * 2 - 8, DIM, "center");
      }
      if (Math.abs(v) > 2) arrow(xb, GY - rB, xb + v * 0.3, GY - rB, TARGET);
      const gx = W * 0.15, gw = W * 0.7;                // the speed gauge
      line(gx, 14, gx + gw, 14, DIM);
      line(gx + gw / 2, 10, gx + gw / 2, 18, DIM);
      ring(gx + gw / 2 + target / D.maxSpeed * gw / 2, 14, 4, TARGET, 1.5);
      dot(gx + gw / 2 + v / D.maxSpeed * gw / 2, 14, 3, MOVER);
      label("v = " + Math.round(v) + " px/s", W / 2, 30, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Motor", "Moped", "half-size wheels and a frantic throttle — the spokes spin twice as fast for the same speed", { radius: 0.05, accel: 320, maxSpeed: 210 });

def("A", "Asteroids", "headings", "thrust along the nose, inertia keeps it: the autopilot turns, burns, flips to brake — press to set the target", function (u) {
  var D = { thrust: 240, turn: 4.0,                     // px/s² along the nose; rad/s of rotation
            maxSpeed: 170, arrive: 1.6,                 // the speed cap; how eagerly the pilot wants to be there
            aim: 0.5,                                   // radians of misalignment it will still burn through
            label: "v += (cos h, sin h) · thrust · dt" };
  const { ctx, W, H, TAU, stage, dot, ring, poly, arrow, label, wrapAngle, clamp, len, rand, MOVER, HOT, TARGET, DIM } = u;
  // the 1979 control scheme: rotate is free, THRUST only pushes along the
  // nose, and nothing ever slows you down but more thrust the other way.
  // the autopilot's whole brain is one subtraction — desired velocity
  // (toward the target, Arrive-style) minus current velocity — it turns
  // to face that ERROR and burns when it's roughly aligned; as it closes
  // in the error points backward, so it flips and brakes. Yaw's turn limit,
  // Inertia's memory, and the screen wraps like the arcade cabinet did.
  let x = W * 0.3, y = H * 0.5, h = 0, vx = 0, vy = 0, timer = 0;
  let tx = W * 0.72, ty = H * 0.35, burning = false;
  let trail = [];
  return {
    press(px, py) { tx = px; ty = py; timer = -6; },
    frame(dt, t) {
      stage();
      timer += dt;
      let dx = tx - x, dy = ty - y;
      let dvx = dx * D.arrive, dvy = dy * D.arrive;     // the desired velocity
      const ds = len(dvx, dvy);
      if (ds > D.maxSpeed) { dvx *= D.maxSpeed / ds; dvy *= D.maxSpeed / ds; }
      const ex = dvx - vx, ey = dvy - vy, es = len(ex, ey);   // the error: what thrust must fix
      const want = Math.atan2(ey, ex);
      const miss = wrapAngle(want - h);
      h += clamp(miss, -D.turn * dt, D.turn * dt);      // turn first (Yaw)
      burning = es > 6 && Math.abs(miss) < D.aim;
      if (burning) { vx += Math.cos(h) * D.thrust * dt; vy += Math.sin(h) * D.thrust * dt; }   // then burn
      const s = len(vx, vy);
      if (s > D.maxSpeed) { vx *= D.maxSpeed / s; vy *= D.maxSpeed / s; }
      x += vx * dt; y += vy * dt;                       // inertia: nothing else touches v
      if (x < -12) x = W + 12; if (x > W + 12) x = -12;
      if (y < -12) y = H + 12; if (y > H + 12) y = -12;
      if ((len(dx, dy) < 12 && s < 25) || timer > 9) {
        timer = 0; tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.15, H * 0.85);
      }
      trail.push([x, y]);
      if (trail.length > 60) trail.shift();
      for (let i = 0; i < trail.length; i++)
        dot(trail[i][0], trail[i][1], 1.2, "rgba(138,217,245," + (i / trail.length * 0.3) + ")");
      ring(tx, ty, 8, TARGET, 1.5);
      arrow(x, y, x + dvx * 0.25, y + dvy * 0.25, "rgba(245,193,105,0.5)");   // desired
      arrow(x, y, x + ex * 0.25, y + ey * 0.25, HOT);                          // the error it steers by
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(h);
      if (burning) {                                    // the thruster flame, flickering
        const f = 10 + rand(0, 6);
        poly([[-7, -3.5], [-7 - f, 0], [-7, 3.5]], HOT);
      }
      poly([[12, 0], [-7, -7], [-4, 0], [-7, 7]], MOVER);
      ctx.fillStyle = "#131020";
      ctx.beginPath(); ctx.arc(3, -2, 1.6, 0, TAU); ctx.fill();
      ctx.restore();
      label(burning ? "burn" : "coast", x, y - 14, burning ? HOT : DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Asteroids", "Anvil", "a third of the thrust and a slow turn — a heavy hauler that overshoots and comes back the long way", { thrust: 80, turn: 1.6, maxSpeed: 120 });

def("D", "Drone", "headings", "critical springs hold x and height; the body tilts into its acceleration, aₓ ÷ g — press to set the hover point", function (u) {
  var D = { omega: 3.5,                                 // spring frequency in rad/s, with ζ = 1 (no overshoot)
            g: 2.4,                                     // gravity as a fraction of H per s² — it sets the tilt scale
            tiltMax: 0.6,                               // radians the body may lean
            arm: 0.07,                                  // half the rotor span, as a fraction of W
            wander: 4,                                  // seconds between hover points
            label: "a = ω²(target − p) − 2ω·v   tilt = aₓ ÷ g" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, rect, arrow, label, clamp, rand, MOVER, BONE, HOT, TARGET, DIM } = u;
  // a quadcopter can only push along its own "up", so to go sideways it
  // must LEAN: the tilt that makes horizontal acceleration aₓ while still
  // holding its weight is tan(tilt) = aₓ / g — for small leans just aₓ/g.
  // here the position is held by Damp's spring at ζ = 1 (CRITICALLY
  // DAMPED, the fastest arrival with no overshoot), and the tilt is READ
  // OFF the acceleration that spring asks for — presentation derived from
  // physics, never animated. the rotor on the high side spins harder.
  let x = W * 0.3, y = H * 0.5, vx = 0, vy = 0, tx = W * 0.7, ty = H * 0.4;
  let spinL = 0, spinR = 0, timer = 0, hold = 0, tilt = 0, ax = 0, ay = 0;
  return {
    press(px, py) { tx = px; ty = clamp(py, H * 0.12, GY - H * 0.18); hold = 6; },
    frame(dt, t) {
      stage(); ground();
      if (hold > 0) hold -= dt;
      else { timer += dt; if (timer > D.wander) { timer = 0; tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.15, GY - H * 0.2); } }
      const w = D.omega, g = H * D.g;
      ax = w * w * (tx - x) - 2 * w * vx;               // ζ = 1: the damping is exactly 2ω
      ay = w * w * (ty - y) - 2 * w * vy;
      vx += ax * dt; vy += ay * dt;
      x += vx * dt; y += vy * dt;
      tilt = clamp(ax / g, -D.tiltMax, D.tiltMax);      // ← the lean, read off the acceleration
      const lift = 1 - ay / g;                          // climbing = both rotors work harder
      spinL += (18 + 10 * lift - 10 * tilt) * dt;       // leaning right: the LEFT rotor spins harder
      spinR += (18 + 10 * lift + 10 * tilt) * dt;
      ctx.setLineDash([3, 4]);
      line(tx, GY, tx, ty, "rgba(245,193,105,0.3)");
      ctx.setLineDash([]);
      ring(tx, ty, 7, TARGET, 1.5);
      const arm = W * D.arm;
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(tilt);
      rect(-arm - 4, -2, arm * 2 + 8, 4, BONE);         // the arms
      rect(-7, -6, 14, 10, MOVER);                      // the body
      for (const side of [-1, 1]) {                     // each rotor, seen edge-on: a blade whose
        const sp = side < 0 ? spinL : spinR;            // apparent length is |cos(spin)| · blade
        const bl = arm * 0.7 * Math.abs(Math.cos(sp));
        line(side * arm - bl, -5, side * arm + bl, -5, "rgba(232,229,244,0.75)", 2);
        dot(side * arm, -5, 2, BONE);
      }
      ctx.fillStyle = "#131020";
      ctx.beginPath(); ctx.arc(3, -1, 1.8, 0, TAU); ctx.fill();
      ctx.restore();
      arrow(x, y + 12, x + ax * 0.06, y + 12 + ay * 0.06, HOT);   // the acceleration the spring asks for
      label("tilt = " + Math.round(tilt * 180 / Math.PI) + "°", x, y - arm * 0.5 - 12, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Drone", "Dragonfly", "the spring at ω = 9 and a steeper lean allowed — a twitchy darter that snaps to every point and banks hard", { omega: 9, tiltMax: 1.0, wander: 2 });

def("T", "Tank", "headings", "differential drive: two track speeds make v and ω; the turret aims at your last click — press to set a destination", function (u) {
  var D = { track: 70, width: 0.13,                     // max track speed in px/s; track separation as a fraction of H
            turnGain: 3.0, turretRate: 4,               // how hard heading error becomes spin; Lookat's smoothing rate
            arrive: 0.05,                               // fraction of W inside which it stops
            label: "v = (vL + vR) ÷ 2   ω = (vR − vL) ÷ width" };
  const { ctx, W, H, TAU, stage, dot, ring, line, rect, label, wrapAngle, clamp, smooth, len, rand, MOVER, BONE, TARGET, DIM } = u;
  // DIFFERENTIAL DRIVE has no steering wheel: two tracks, two speeds, and
  // the body's motion falls out of their difference — forward speed is
  // their average, spin rate is their difference over the width. equal
  // tracks go straight, opposite tracks PIVOT on the spot (a thing Vehicle
  // can never do). the driver only ever decides vL and vR; the turret is a
  // separate heading on top, tracking its own target with Lookat's short
  // arc — one body, two angles, which is what makes a tank feel like one.
  let x = W * 0.3, y = H * 0.55, h = 0, vL = 0, vR = 0, distL = 0, distR = 0;
  let tx = W * 0.7, ty = H * 0.4, ax = W * 0.5, ay = H * 0.15, tur = 0, rest = 0;
  return {
    press(px, py) { ax = tx; ay = ty; tx = px; ty = py; rest = 0; },   // the turret keeps the old target
    frame(dt, t) {
      stage();
      const width = H * D.width;
      const dx = tx - x, dy = ty - y, d = len(dx, dy);
      const err = wrapAngle(Math.atan2(dy, dx) - h);
      let v = 0, om = 0;
      if (d > W * D.arrive) {                           // the driver's intent: a speed and a spin
        v = clamp(d * 1.5, 0, D.track) * Math.max(0, Math.cos(err));   // no driving until roughly facing it
        om = clamp(err * D.turnGain, -2 * D.track / width, 2 * D.track / width);
        rest = 0;
      } else { rest += dt; if (rest > 2) { rest = 0; ax = tx; ay = ty; tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.2, H * 0.85); } }
      vL = clamp(v - om * width / 2, -D.track, D.track);   // intent → two track speeds
      vR = clamp(v + om * width / 2, -D.track, D.track);
      v = (vL + vR) / 2;                                // ← and the honest way back: the body
      om = (vR - vL) / width;                           //   only knows what its tracks do
      h += om * dt;
      x += Math.cos(h) * v * dt; y += Math.sin(h) * v * dt;
      distL += vL * dt; distR += vR * dt;               // each tread's own odometer
      const want = Math.atan2(ay - y, ax - x);
      tur += wrapAngle(want - tur) * smooth(D.turretRate, dt);   // Lookat, verbatim
      ring(tx, ty, 8, TARGET, 1.5);
      dot(tx, ty, 2.5, TARGET);
      ring(ax, ay, 5, "rgba(245,193,105,0.5)", 1);
      ctx.setLineDash([2, 5]);
      line(x, y, ax, ay, "rgba(245,193,105,0.25)");
      ctx.setLineDash([]);
      const bl = width * 1.5, tw = width * 0.35;        // body length; tread thickness
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(h);
      for (const s of [-1, 1]) {                        // the treads, ticks scrolling by each odometer
        const cy = s * width / 2, od = s < 0 ? distL : distR;
        rect(-bl / 2, cy - tw / 2, bl, tw, "rgba(201,196,228,0.35)");
        const ph = ((od % 6) + 6) % 6;
        for (let k = -ph; k < bl; k += 6)
          if (k >= 0) line(-bl / 2 + k, cy - tw / 2, -bl / 2 + k, cy + tw / 2, BONE, 1);
      }
      rect(-bl * 0.4, -width / 2 + tw / 2, bl * 0.8, width - tw, MOVER);   // the hull
      ctx.restore();
      line(x, y, x + Math.cos(tur) * width * 1.1, y + Math.sin(tur) * width * 1.1, BONE, 3);   // the barrel
      dot(x, y, width * 0.28, "rgba(201,196,228,0.9)");
      label("vL " + Math.round(vL) + "  vR " + Math.round(vR), x, y - width - 6, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Tank", "Tortoise", "under half the track speed on a wider hull — the same two numbers buy far less spin: a slow, deliberate lumber", { track: 32, width: 0.2, turretRate: 1.5 });

def("H", "Homing", "headings", "Yaw's turn limit + Chase's prediction, a proximity fuse and a lifetime — press to fire a salvo from your click", function (u) {
  var D = { speed: 150, turn: 3.2,                      // px/s and rad/s — Yaw's two numbers, per missile
            fuse: 14, life: 5,                          // detonate within this many px; seconds before it fizzles
            salvo: 5, lead: 0.9,                        // missiles per press; how much of the prediction to trust
            label: "aim at prey + v·(d ÷ speed)·lead   fuse r" };
  const { ctx, W, H, TAU, stage, dot, ring, poly, mote, label, wrapAngle, clamp, len, rand, GOOD, HOT, TARGET, DIM } = u;
  // a homing missile is Yaw with a brain from Chase: a heading that can
  // only turn so fast, aimed not at the prey but at where the prey will be
  // (position + velocity × the time to get there). two more numbers make
  // it a game thing: a PROXIMITY FUSE (close enough counts — nobody hits a
  // moving dot exactly) and a LIFETIME, so a missile that gets out-turned
  // fizzles instead of circling for ever. the fan at launch is why salvos
  // look like salvos: the same target, different starting headings.
  const prey = { x: W * 0.6, y: H * 0.4, vx: 60, vy: 0, wa: 0 };
  let missiles = [], smoke = [], bursts = [], hits = 0, quiet = 0, puff = 0;
  function fire(fx, fy) {
    const base = Math.atan2(prey.y - fy, prey.x - fx);
    for (let i = 0; i < D.salvo; i++) {
      if (missiles.length >= 30) missiles.shift();
      const spread = (i - (D.salvo - 1) / 2) * 0.45;   // the fan
      missiles.push({ x: fx, y: fy, h: base + spread, age: 0 });
    }
  }
  return {
    press(x, y) { fire(x, y); },
    frame(dt, t) {
      stage();
      prey.wa += rand(-2.4, 2.4) * Math.sqrt(dt);       // the prey wanders (Wander's jitter)...
      let fx = Math.cos(prey.wa), fy = Math.sin(prey.wa);
      fx += (W / 2 - prey.x) / W * 1.6; fy += (H / 2 - prey.y) / H * 1.6;   // ...and leans back toward the middle
      const fl = len(fx, fy) || 1;
      prey.vx += (fx / fl * 75 - prey.vx) * 3 * dt;
      prey.vy += (fy / fl * 75 - prey.vy) * 3 * dt;
      prey.x = clamp(prey.x + prey.vx * dt, 10, W - 10);
      prey.y = clamp(prey.y + prey.vy * dt, 10, H - 10);
      quiet += dt;
      if (missiles.length === 0 && quiet > 1.6) { quiet = 0; fire(rand(0, 1) < 0.5 ? 6 : W - 6, H - 6); }
      puff += dt;
      const doPuff = puff > 0.05; if (doPuff) puff = 0;
      for (let i = missiles.length - 1; i >= 0; i--) {
        const m = missiles[i];
        m.age += dt;
        const dx = prey.x - m.x, dy = prey.y - m.y, d = len(dx, dy);
        const eta = d / D.speed;                        // time to get there, if the prey stood still
        const px = prey.x + prey.vx * eta * D.lead, py = prey.y + prey.vy * eta * D.lead;   // Chase's point
        const want = Math.atan2(py - m.y, px - m.x);
        m.h += clamp(wrapAngle(want - m.h), -D.turn * dt, D.turn * dt);   // Yaw's limit
        m.x += Math.cos(m.h) * D.speed * dt; m.y += Math.sin(m.h) * D.speed * dt;
        if (doPuff) { if (smoke.length >= 120) smoke.shift(); smoke.push({ x: m.x, y: m.y, a: 0 }); }
        if (d < D.fuse) {                               // the fuse
          hits++; missiles.splice(i, 1);
          if (bursts.length >= 8) bursts.shift();
          bursts.push({ x: m.x, y: m.y, a: 0 });
          prey.vx += dx / (d || 1) * -120; prey.vy += dy / (d || 1) * -120;   // the prey is knocked
          continue;
        }
        if (m.age > D.life || m.x < -30 || m.x > W + 30 || m.y < -30 || m.y > H + 30) missiles.splice(i, 1);   // the lifetime
        if (i === 0) ring(px, py, 5, "rgba(245,193,105,0.5)");   // one prediction, made visible
      }
      for (let i = smoke.length - 1; i >= 0; i--) {
        const s = smoke[i]; s.a += dt;
        if (s.a > 1.2) { smoke.splice(i, 1); continue; }
        dot(s.x, s.y, 1.5 + s.a * 3, "rgba(201,196,228," + (0.3 * (1 - s.a / 1.2)) + ")");
      }
      for (let i = bursts.length - 1; i >= 0; i--) {
        const b = bursts[i]; b.a += dt;
        if (b.a > 0.5) { bursts.splice(i, 1); continue; }
        ring(b.x, b.y, 6 + b.a * 50, "rgba(245,138,138," + (0.8 * (1 - b.a / 0.5)) + ")", 2);
      }
      for (const m of missiles) {
        ctx.save(); ctx.translate(m.x, m.y); ctx.rotate(m.h);
        poly([[7, 0], [-5, -3.5], [-3, 0], [-5, 3.5]], HOT);
        ctx.restore();
      }
      ring(prey.x, prey.y, D.fuse, "rgba(155,226,138,0.25)");   // the fuse radius, around the prey
      mote(prey.x, prey.y, Math.atan2(prey.vy, prey.vx), GOOD, 6);
      label("hits ×" + hits + " · " + missiles.length + " in flight", W / 2, 14, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Homing", "Hornets", "slower, but turning nearly three times as hard, in salvos of eight — a swarm that never gets out-turned", { speed: 110, turn: 9, salvo: 8 });

def("R", "Rocket", "headings", "thrust vs gravity on a shrinking mass, a slow gravity turn, a booster that falls away — press to launch again", function (u) {
  var D = { thrust: 1.2,                               // thrust ÷ weight at lift-off (1 = it just hovers)
            burn: 3.0, burn2: 2.6,                      // seconds each stage burns
            pitchRate: 14, pitchMax: 85,                // the gravity turn: degrees per second, and its limit
            g: 0.18,                                    // gravity as a fraction of H per s²
            label: "a = F ÷ m − g   m shrinks as fuel burns" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, poly, line, label, clamp, rand, MOVER, BONE, HOT, TARGET, DIM } = u;
  // Jump's parabola, but the launch speed is EARNED frame by frame: the
  // engine pushes with a fixed force F on a mass m that shrinks as fuel
  // burns, so a = F/m − g climbs while the tank drains (Newton's second law
  // with a leaky m). the GRAVITY TURN is a heading that pitches over
  // slowly so gravity itself bends the path sideways; STAGING drops the
  // empty booster — which keeps the rocket's velocity and then falls on
  // its own parabola, tumbling. in coast the nose follows the velocity.
  let phase = "pad", timer = 0, x = 0, y = 0, vx = 0, vy = 0, pitch = 0, m = 1;
  const boo = { on: false, x: 0, y: 0, vx: 0, vy: 0, a: 0, spin: 0 };
  let trail = [], puff = 0, aRead = 0;
  function reset() { phase = "pad"; timer = 0; x = W * 0.2; y = GY - 14; vx = 0; vy = 0; pitch = 0; m = 1; boo.on = false; trail = []; }
  reset();
  return {
    press() { reset(); timer = 0.9; },
    frame(dt, t) {
      stage(); ground();
      const g = H * D.g, F1 = D.thrust * g;             // F is fixed; the mass under it is not
      timer += dt;
      let F = 0;
      if (phase === "pad" && timer > 1.2) { phase = "s1"; timer = 0; }
      if (phase === "s1") {
        m = 1 - 0.5 * clamp(timer / D.burn, 0, 1); F = F1;   // stage one: half the rocket is fuel
        if (timer > D.burn) {                           // STAGING: the booster falls away
          phase = "s2"; timer = 0; m = 0.35;
          boo.on = true; boo.x = x; boo.y = y; boo.vx = vx - 12; boo.vy = vy + 10; boo.a = pitch; boo.spin = 1.4;
        }
      }
      if (phase === "s2") {
        m = 0.35 - 0.2 * clamp(timer / D.burn2, 0, 1); F = F1 * 0.32;   // a smaller engine on a lighter ship
        if (timer > D.burn2) { phase = "coast"; timer = 0; }
      }
      if (phase !== "pad" && phase !== "done") {
        if (F > 0) pitch = Math.min(pitch + D.pitchRate * Math.PI / 180 * dt, D.pitchMax * Math.PI / 180);   // the gravity turn
        else pitch = Math.atan2(vx, -vy);               // coasting: point along the velocity
        const a = F / m;                                // ← F ÷ m, the whole reason to burn fuel
        aRead = a / g;
        vx += Math.sin(pitch) * a * dt;
        vy += (-Math.cos(pitch) * a + g) * dt;          // minus gravity, straight down
        const s = Math.sqrt(vx * vx + vy * vy), cap = H * 3;
        if (s > cap) { vx *= cap / s; vy *= cap / s; }
        x += vx * dt; y += vy * dt;
        puff += dt;
        if (puff > 0.06) { puff = 0; if (trail.length >= 100) trail.shift(); trail.push([x, y]); }
        if (y > GY - 6 && vy > 0) { phase = "done"; timer = 0; }   // it came back down
        if (x > W + 40 || y < -H * 0.6 || x < -40) { phase = "done"; timer = 0; }
      }
      if (phase === "done" && timer > 1.6) reset();
      if (boo.on) {                                     // the booster: ballistic, tumbling
        boo.vy += g * dt;
        boo.x += boo.vx * dt; boo.y += boo.vy * dt; boo.a += boo.spin * dt;
        if (boo.y > GY - 4) boo.on = false;
      }
      for (let i = 0; i < trail.length; i++) dot(trail[i][0], trail[i][1], 1.3, "rgba(201,196,228," + (0.1 + i / trail.length * 0.3) + ")");
      line(W * 0.2 - 12, GY, W * 0.2 + 12, GY, BONE, 3);   // the pad
      if (boo.on) {
        ctx.save(); ctx.translate(boo.x, boo.y); ctx.rotate(boo.a);
        poly([[-4, -8], [4, -8], [4, 8], [-4, 8]], "rgba(201,196,228,0.7)");
        ctx.restore();
      }
      if (phase !== "done") {
        ctx.save(); ctx.translate(x, y); ctx.rotate(pitch);
        if (F > 0) poly([[-3, 10], [0, 16 + rand(0, 8)], [3, 10]], HOT);   // the flame
        if (phase === "pad" || phase === "s1") poly([[-4, 2], [4, 2], [4, 12], [-4, 12]], BONE);   // the booster, attached
        poly([[0, -12], [4, -4], [4, 3], [-4, 3], [-4, -4]], MOVER);
        ctx.fillStyle = "#131020";
        ctx.beginPath(); ctx.arc(1.2, -5, 1.5, 0, TAU); ctx.fill();
        ctx.restore();
        label("m " + Math.round(m * 100) + "%  a = " + (F > 0 ? aRead.toFixed(1) + "g" : "0"), x + 14, y - 6, DIM);
      }
      label(phase === "pad" ? "T − " + Math.max(0, 1.2 - timer).toFixed(1) : phase === "coast" ? "coast" : phase === "done" ? "reset…" : "stage " + (phase === "s1" ? 1 : 2), W / 2, 14, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Rocket", "Rustbucket", "barely more thrust than weight and a lazy pitch-over — it hangs above the pad, creeps up, and drifts off with nothing to spare", { thrust: 1.06, pitchRate: 9, burn: 3.6 });

def("X", "Xhair", "headings", "aim assist: the crosshair slows inside a target's ring and is pulled to its centre — drag to move the crosshair", function (u) {
  var D = { assist: 0.17,                               // the assist ring's radius, as a fraction of H
            friction: 0.35,                             // inside the ring the crosshair keeps this much of its speed
            pull: 140,                                  // px/s of magnetism at its strongest (half-way in)
            follow: 12,                                 // how fast the crosshair chases the pointer (per second)
            label: "inside r:  v × friction  +  pull → centre" };
  const { ctx, W, H, TAU, stage, dot, ring, line, label, clamp, len, rand, lerp, smooth, MOVER, BONE, TARGET, HOT, DIM } = u;
  // AIM ASSIST is two small lies the hand never notices. FRICTION: while
  // the crosshair is inside a target's ring, its speed toward the pointer
  // is scaled down, so it "sticks" as it crosses. MAGNETISM: a gentle pull
  // toward the nearest centre — Magnet's field, but shaped as a hump that
  // is zero at the centre and at the rim, so it helps without snapping
  // (Arrive's idea: brake before you get there). the pointer is honest;
  // the crosshair is the one that cheats, and the gap between them is the
  // assist made visible.
  let px = W * 0.5, py = H * 0.5, cx = px, cy = py, idle = 9;
  const targets = [];
  for (let i = 0; i < 3; i++) targets.push({ x: W * (0.2 + i * 0.3), y: H * (0.3 + i * 0.18), vx: (i % 2 ? -1 : 1) * (22 + i * 9), vy: 0, ph: i * 2.1 });
  return {
    drag: true,
    press(x, y) { px = x; py = y; idle = 0; },
    frame(dt, t) {
      stage();
      idle += dt;
      if (idle > 2) {                                   // nobody dragging: the pointer wanders on two sines
        const ax = W / 2 + Math.cos(t * 0.6) * W * 0.36, ay = H / 2 + Math.sin(t * 0.95) * H * 0.3;
        px = lerp(px, ax, smooth(1.5, dt)); py = lerp(py, ay, smooth(1.5, dt));
      }
      const r = H * D.assist;
      let near = null, nd = 1e9;
      for (const g of targets) {
        g.x += g.vx * dt;
        g.y = H * (0.25 + 0.5 * (0.5 + 0.5 * Math.sin(t * 0.4 + g.ph)));   // drifting across, gently bobbing
        if (g.x > W + 20) g.x = -20; if (g.x < -20) g.x = W + 20;
        const d = len(g.x - cx, g.y - cy);
        if (d < nd) { nd = d; near = g; }
      }
      let vx = (px - cx) * D.follow, vy = (py - cy) * D.follow;   // the honest follow: a fraction of the gap
      const inside = nd < r;
      if (inside) {
        vx *= D.friction; vy *= D.friction;             // friction: the crosshair sticks
        const k = nd / r, hump = 4 * k * (1 - k);       // the pull's shape: nothing at the centre or the rim
        const ux = (near.x - cx) / (nd || 1), uy = (near.y - cy) / (nd || 1);
        vx += ux * D.pull * hump; vy += uy * D.pull * hump;   // magnetism
      }
      cx += vx * dt; cy += vy * dt;
      cx = clamp(cx, 0, W); cy = clamp(cy, 0, H);
      for (const g of targets) {
        const hot = g === near && inside;
        ctx.setLineDash(hot ? [] : [3, 4]);
        ring(g.x, g.y, r, hot ? "rgba(245,193,105,0.6)" : "rgba(245,193,105,0.25)", hot ? 1.5 : 1);   // the assist ring
        ctx.setLineDash([]);
        dot(g.x, g.y, 7, hot ? HOT : BONE);
        ctx.fillStyle = "#131020";
        ctx.beginPath(); ctx.arc(g.x + 2.4, g.y - 2, 1.8, 0, TAU); ctx.fill();
      }
      line(cx, cy, px, py, "rgba(232,229,244,0.2)");     // the gap: the assist, made visible
      dot(px, py, 2.5, DIM);                             // the honest pointer
      ring(cx, cy, 9, MOVER, 1.5);                       // the crosshair
      line(cx - 14, cy, cx - 5, cy, MOVER, 1.5); line(cx + 5, cy, cx + 14, cy, MOVER, 1.5);
      line(cx, cy - 14, cx, cy - 5, MOVER, 1.5); line(cx, cy + 5, cx, cy + 14, MOVER, 1.5);
      label(inside ? "assisting" : "free", cx, cy - 20, inside ? TARGET : DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Xhair", "Xlock", "a bigger ring, a stickier friction and twice the pull — console-grade lock-on that all but aims for you", { assist: 0.28, friction: 0.12, pull: 300 });

def("L", "Leaf", "headings", "a leaf slides along its tilt: gravity along the face, drag across it, a sine rocks the tilt — press to drop one", function (u) {
  var D = { g: 1.4,                                     // gravity as a fraction of H per s²
            dragAcross: 9, dragAlong: 0.9,              // air resistance across the face (big) and along it (small)
            rock: 1.6, amp: 0.9,                        // the rocking sine: rad/s and radians
            pitch: 0.012,                               // how much airspeed along the face tips the leaf back
            count: 6,
            label: "along the face: g·sin θ  ·  across it: drag" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, line, poly, arrow, label, clamp, rand, GOOD, DIM } = u;
  // a leaf falls the way it does because air resists it very unequally:
  // hugely ACROSS its face, hardly at all ALONG it. so its velocity is split
  // into those two directions every frame, each damped by its own drag,
  // and gravity's pull along the tilted face makes the leaf SLIDE sideways.
  // the tilt itself is Pendulum's rock — a slow sine — plus a push-back
  // from the airspeed, so a fast slide levels the leaf and flips it the
  // other way: the flutter is that feedback loop, and nothing is scripted.
  const leaves = [];
  let next = 0;
  function spawn(l, x, y) { l.x = x; l.y = y; l.vx = 0; l.vy = 0; l.ph = rand(0, TAU); l.a = 0; l.vf = 0; }
  for (let i = 0; i < D.count; i++) { const l = {}; spawn(l, rand(W * 0.1, W * 0.9), rand(-H * 0.1, GY - H * 0.2)); leaves.push(l); }
  return {
    press(x, y) { spawn(leaves[next], x, y); next = (next + 1) % leaves.length; },
    frame(dt, t) {
      stage(); ground();
      const g = H * D.g;
      for (let i = 0; i < leaves.length; i++) {
        const l = leaves[i];
        l.a = Math.sin(t * D.rock + l.ph) * D.amp + clamp(-l.vf * D.pitch, -1.1, 1.1);   // the tilt: a sine + airspeed
        const fx = Math.cos(l.a), fy = Math.sin(l.a);   // along the face
        const nx = -fy, ny = fx;                        // across it (the normal)
        l.vy += g * dt;
        let vf = l.vx * fx + l.vy * fy;                 // split the velocity into the two directions
        let vn = l.vx * nx + l.vy * ny;
        vf *= Math.exp(-D.dragAlong * dt);              // each with its own drag
        vn *= Math.exp(-D.dragAcross * dt);
        l.vx = vf * fx + vn * nx; l.vy = vf * fy + vn * ny;   // and back together
        l.vf = vf;
        l.x += l.vx * dt; l.y += l.vy * dt;
        if (l.x < -20) l.x = W + 20; if (l.x > W + 20) l.x = -20;
        if (l.y > GY - 3) spawn(l, rand(W * 0.1, W * 0.9), -H * 0.08);   // landed: another one lets go up top
        const L = 9;
        ctx.save(); ctx.translate(l.x, l.y); ctx.rotate(l.a);
        poly([[-L, 0], [-L * 0.4, -L * 0.45], [L * 0.4, -L * 0.4], [L, 0], [L * 0.4, L * 0.4], [-L * 0.4, L * 0.45]], i === next ? "rgba(155,226,138,0.9)" : "rgba(155,226,138,0.7)");
        line(-L, 0, L, 0, "rgba(19,16,32,0.4)", 1);     // the vein: the face direction
        ctx.restore();
        if (i === 0) {                                  // one leaf shows its working
          arrow(l.x, l.y, l.x + l.vx * 0.3, l.y + l.vy * 0.3, DIM);
          line(l.x, l.y, l.x + nx * 16, l.y + ny * 16, "rgba(155,226,138,0.5)");
        }
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Leaf", "Lace", "more than twice the air resistance and a quick, small rock — a scrap of lace that shivers down instead of swooping", { dragAcross: 22, rock: 3.2, amp: 0.5 });

/* ============================== BRAINS & STEERING ==============================
   How enemies decide. A steering agent keeps a velocity and, each frame,
   computes a DESIRED velocity from what it wants — then applies only a
   gentle correction (desired − current, clamped). That one subtraction is
   why steered things bank, drift, and overshoot like living creatures
   instead of snapping like cursors. Everything here is vector maths:
   subtract two points to get "toward", divide by length to get a pure
   direction, multiply to choose a speed. Lap 2 adds the negatives (flee,
   evade), a whisker for dodging rocks, and a state machine with moods;
   the genre laps spend all of it on a ghost, a tractor beam, fireflies,
   a butterfly, a horde, and a game of volley. */

def("A", "Arrive", "steer", "seek, but braking inside the amber ring — press to move the target", function (u) {
  var D = { maxsp: 130, maxf: 300, slow: 85,            // top speed (px/s), steering clamp (px/s²), brake ring (px)
            retarget: 3.2 };                             // seconds before it picks a new spot on its own
  const { ctx, W, H, stage, dot, ring, mote, arrow, label, rand, len, clamp, GOOD, HOT, TARGET } = u;
  // plain seek arrives like a dart hitting a board. ARRIVE scales the
  // desired speed down with distance inside a slow radius, so the brakes
  // come on early and the stop is a real stop. the arrows tell the story:
  // green = current velocity, red = the correction being applied.
  let x = W * 0.2, y = H * 0.7, vx = 0, vy = 0;
  let tx = W * 0.7, ty = H * 0.35, timer = 0;
  return {
    press(px, py) { tx = px; ty = py; timer = -4; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (timer > D.retarget) { timer = 0; tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.15, H * 0.85); }
      const dx = tx - x, dy = ty - y, d = len(dx, dy) || 1;
      const speed = D.maxsp * Math.min(1, d / D.slow);  // ← the whole idea of Arrive
      const desx = dx / d * speed, desy = dy / d * speed;
      let sx = desx - vx, sy = desy - vy;              // steering = desired − current
      const sl = len(sx, sy);
      if (sl > D.maxf) { sx = sx / sl * D.maxf; sy = sy / sl * D.maxf; }
      vx += sx * dt; vy += sy * dt;
      x += vx * dt; y += vy * dt;
      ring(tx, ty, D.slow, "rgba(245,193,105,0.25)");
      dot(tx, ty, 4, TARGET);
      arrow(x, y, x + vx * 0.35, y + vy * 0.35, GOOD);
      arrow(x, y, x + sx * 0.12, y + sy * 0.12, HOT);
      mote(x, y, Math.atan2(vy, vx));
      label("desired speed = max · min(1, distance/" + D.slow + ")", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Arrive", "Ambush", "twice the speed, half the brake ring, a harder steering clamp — a lunge that leaves the braking to the last moment", { maxsp: 260, maxf: 700, slow: 40 });

def("C", "Chase", "steer", "aim where the prey WILL be — the faint rival aims where it is — press to scatter", function (u) {
  var D = { preySpeed: 112, chaseSpeed: 95,             // px/s — the prey is quicker; prediction makes up for it
            fear: 95, lead: 0.9, jitter: 2.6 };          // flee radius (px), how far ahead to aim, the prey's wobble
  const { ctx, W, H, stage, dot, ring, mote, label, rand, len, clamp, GOOD, MOVER, TARGET } = u;
  // pursuit: the smart chaser leads its target like a goalkeeper, steering
  // at prey position + prey velocity · (time to get there). the ghost
  // chaser runs exactly as fast but aims at where the prey IS — watch it
  // trail forever on curves. prediction is one multiply-add.
  function agent(x, y) { return { x: x, y: y, vx: 0, vy: 0 }; }
  const prey = agent(W * 0.6, H * 0.4);
  const smart = agent(W * 0.15, H * 0.8);
  const naive = agent(W * 0.85, H * 0.8);
  let wa = 0, caught = 0, flash = 0;
  function steer(a, tx, ty, maxsp, force, dt) {
    const dx = tx - a.x, dy = ty - a.y, d = len(dx, dy) || 1;
    a.vx += clamp(dx / d * maxsp - a.vx, -force, force) * dt * 4;
    a.vy += clamp(dy / d * maxsp - a.vy, -force, force) * dt * 4;
    const s = len(a.vx, a.vy);
    if (s > maxsp) { a.vx *= maxsp / s; a.vy *= maxsp / s; }
    a.x += a.vx * dt; a.y += a.vy * dt;
    if (a.x < 10) a.x = 10; if (a.x > W - 10) a.x = W - 10;
    if (a.y < 10) a.y = 10; if (a.y > H - 10) a.y = H - 10;
  }
  return {
    press(px, py) { prey.x = px; prey.y = py; prey.vx = rand(-90, 90); prey.vy = rand(-90, 90); },
    frame(dt, t) {
      stage();
      wa += rand(-D.jitter, D.jitter) * Math.sqrt(dt);  // the prey wanders...
      let fx = Math.cos(wa) * 105, fy = Math.sin(wa) * 105;
      const pd = len(smart.x - prey.x, smart.y - prey.y);
      if (pd < D.fear) {                                // ...and flees the smart one
        fx += (prey.x - smart.x) / pd * 150;
        fy += (prey.y - smart.y) / pd * 150;
      }
      steer(prey, prey.x + fx, prey.y + fy, D.preySpeed, 260, dt);
      const eta = pd / D.chaseSpeed;                    // rough time-to-intercept
      const px2 = prey.x + prey.vx * eta * D.lead, py2 = prey.y + prey.vy * eta * D.lead;
      steer(smart, px2, py2, D.chaseSpeed, 240, dt);
      steer(naive, prey.x, prey.y, D.chaseSpeed, 240, dt);
      if (pd < 14) { caught++; flash = 1; prey.x = rand(W * 0.1, W * 0.9); prey.y = rand(H * 0.1, H * 0.9); }
      flash = Math.max(0, flash - dt * 2);
      if (flash > 0) ring(smart.x, smart.y, 18 + (1 - flash) * 30, "rgba(245,193,105," + flash * 0.8 + ")", 2);
      ring(px2, py2, 6, "rgba(245,193,105,0.5)");      // the prediction, made visible
      ctx.setLineDash([3, 4]);
      ctx.strokeStyle = "rgba(245,193,105,0.3)";
      ctx.beginPath(); ctx.moveTo(smart.x, smart.y); ctx.lineTo(px2, py2); ctx.stroke();
      ctx.setLineDash([]);
      mote(prey.x, prey.y, Math.atan2(prey.vy, prey.vx), GOOD, 7);
      mote(smart.x, smart.y, Math.atan2(smart.vy, smart.vx), MOVER, 8);
      mote(naive.x, naive.y, Math.atan2(naive.vy, naive.vx), "rgba(232,229,244,0.28)", 8);
      label("caught ×" + caught + " · blue predicts, ghost points", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Chase", "Cheetah", "the hunters now outrun the prey and its fear ring is wider — a sprint with short, brutal catches instead of a long stalk", { chaseSpeed: 128, preySpeed: 100, fear: 130 });

def("W", "Wander", "steer", "the classic wander rig: a jittering target on a circle held out front — press to startle", function (u) {
  var D = { ahead: 46, rim: 26,                          // the guide circle: how far out front, how big (px)
            jitter: 3.1, speed: 85, turn: 3 };           // rim-angle wobble, px/s, how keenly it steers
  const { ctx, W, H, TAU, stage, dot, ring, mote, label, rand, len, DIM, TARGET } = u;
  // aimless-looking motion that never twitches: hold an invisible circle a
  // fixed distance ahead, keep a target ON its rim, and jitter that
  // target's angle a little each frame. steering at the rim point smooths
  // all the randomness through the circle's geometry. the rig is usually
  // hidden — here it's the whole show.
  let x = W / 2, y = H / 2, vx = 60, vy = 0, wa = 0, burst = 0;
  return {
    press() { wa = rand(-Math.PI, Math.PI); burst = 1; },
    frame(dt, t) {
      stage();
      burst = Math.max(0, burst - dt * 0.7);
      wa += rand(-1, 1) * D.jitter * Math.sqrt(dt);     // the only randomness in the rig
      const sp = len(vx, vy) || 1;
      const hx = vx / sp, hy = vy / sp;
      const cx = x + hx * D.ahead, cy = y + hy * D.ahead;   // the guide circle, out front
      const head = Math.atan2(hy, hx);
      const tx = cx + Math.cos(head + wa) * D.rim;
      const ty = cy + Math.sin(head + wa) * D.rim;
      const maxsp = D.speed * (1 + burst * 1.2);
      const dx = tx - x, dy = ty - y, d = len(dx, dy) || 1;
      vx += (dx / d * maxsp - vx) * D.turn * dt;
      vy += (dy / d * maxsp - vy) * D.turn * dt;
      x += vx * dt; y += vy * dt;
      if (x < -12) x = W + 12; if (x > W + 12) x = -12;
      if (y < -12) y = H + 12; if (y > H + 12) y = -12;
      ring(cx, cy, D.rim, "rgba(232,229,244,0.2)");
      ctx.strokeStyle = DIM;
      ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(tx, ty); ctx.stroke();
      dot(tx, ty, 3.5, TARGET);
      mote(x, y, Math.atan2(vy, vx));
      label("steer at the rim dot; jitter only its angle", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Wander", "Wasp", "a rim wider than the reach, twice the jitter, half again the speed — the target can swing behind it: darting and angry", { rim: 58, jitter: 6.5, speed: 125 });

def("Z", "Zigzag", "steer", "a patrol path with eased legs and pauses — press to add a waypoint", function (u) {
  var D = { speed: 150, ghost: 110,                      // px/s: the saw's leg speed, the ghost's constant speed
            pause: 0.45, spin: 9, maxPts: 8 };           // the corner rest (s), blade spin (rad/s), waypoint cap
  const { ctx, W, H, TAU, stage, dot, ring, label, ease, len, BONE, HOT, DIM } = u;
  // the humble patrol obstacle: waypoints, and a schedule for travelling
  // between them. the saw EASES each leg (slow-fast-slow) and rests at
  // corners — the ghost covers the same path at constant speed. same
  // route, entirely different menace. easing is design, not decoration.
  function defaults() {
    const pts = [];
    for (let i = 0; i < 5; i++)
      pts.push([W * (0.12 + i * 0.19), i % 2 ? H * 0.25 : H * 0.65]);
    return pts;
  }
  let pts = defaults();
  let seg = 0, dir = 1, k = 0, pause = 0;              // the eased saw
  let gd = 0;                                          // the ghost's distance along the path
  return {
    press(px, py) {
      if (pts.length >= D.maxPts) pts = defaults();
      else pts.push([px, py]);
      seg = 0; dir = 1; k = 0; pause = 0; gd = 0;
    },
    frame(dt, t) {
      stage();
      ctx.strokeStyle = "rgba(201,196,228,0.35)";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      pts.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]));
      ctx.stroke();
      pts.forEach(p => ring(p[0], p[1], 4, "rgba(201,196,228,0.5)"));
      const a = pts[seg], b = pts[seg + 1];
      const legLen = len(b[0] - a[0], b[1] - a[1]) || 1;
      if (pause > 0) pause -= dt;
      else {
        k += dt * D.speed / legLen;                    // constant speed, eased per leg
        if (k >= 1) {
          k = 0; pause = D.pause;                      // the corner rest
          seg += dir;
          if (seg > pts.length - 2) { seg = pts.length - 2; dir = -1; }
          if (seg < 0) { seg = 0; dir = 1; }
        }
      }
      // forward legs run a→b; backward legs run b→a (e2 flips the same easing)
      const e2 = dir > 0 ? ease(k) : 1 - ease(k);
      const ex = a[0] + (b[0] - a[0]) * e2, ey = a[1] + (b[1] - a[1]) * e2;
      let total = 0;
      for (let i = 0; i < pts.length - 1; i++) total += len(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]);
      total = total || 1;
      gd = (gd + D.ghost * dt) % (total * 2);          // ghost ping-pongs by distance
      let g = gd > total ? total * 2 - gd : gd, gx = pts[0][0], gy = pts[0][1];
      for (let i = 0; i < pts.length - 1; i++) {
        const L = len(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) || 1;
        if (g <= L) { gx = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * g / L; gy = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * g / L; break; }
        g -= L;
      }
      dot(gx, gy, 7, "rgba(232,229,244,0.18)");
      ctx.save();                                      // the saw: eased, pausing, mean
      ctx.translate(ex, ey);
      ctx.rotate(t * D.spin);
      ctx.fillStyle = HOT;
      ctx.beginPath(); ctx.arc(0, 0, 8, 0, TAU); ctx.fill();
      ctx.strokeStyle = HOT; ctx.lineWidth = 2;
      for (let i = 0; i < 8; i++) {
        const an = i / 8 * TAU;
        ctx.beginPath(); ctx.moveTo(Math.cos(an) * 8, Math.sin(an) * 8);
        ctx.lineTo(Math.cos(an) * 12, Math.sin(an) * 12); ctx.stroke();
      }
      ctx.restore();
      label(pts.length + "/" + D.maxPts + " waypoints · eased saw vs constant ghost", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Zigzag", "Zoom", "nearly three times the leg speed, a blink of a pause, a quicker ghost — the same route as a whip-crack instead of a plod", { speed: 420, ghost: 230, pause: 0.08 });

def("F", "Flee", "steer", "flee = seek × −1, evade = pursuit × −1, and a burrow the hunter can't enter — press to place the hunter", function (u) {
  var D = { preySpeed: 120, chaseSpeed: 95,             // px/s: the prey is quicker, the hunter leads its aim
            fear: 0.34, burrow: 0.13,                    // the fear radius (× W) and the burrow's size (× H)
            lead: 0.8, patience: 2.5 };                  // how far ahead both aim · seconds the hunter waits at the rim
  const { ctx, W, H, TAU, stage, dot, ring, mote, arrow, label, rand, len, GOOD, MOVER, HOT, TARGET, DIM, BONE } = u;
  // every steering behaviour has an evil twin: FLEE is seek with the sign
  // flipped (desired = away from the threat), EVADE is pursuit flipped —
  // run from where the hunter WILL be, not where it is. the prey only
  // bothers inside its fear radius; outside it grazes. the burrow is a
  // rule, not a force: the hunter may not step inside, so the flee vector
  // leans toward it — a flee with a plan. the hunter is the mote.
  const prey = { x: W * 0.62, y: H * 0.4, vx: 0, vy: 0 };
  const hunt = { x: W * 0.15, y: H * 0.75, vx: 0, vy: 0 };
  let gx = W * 0.5, gy = H * 0.5, graze = 0;           // the prey's grazing spot
  let bx = W * 0.5, by = H * 0.5, bored = 0, wait = 0; // the hunter's sulk spot, and its patience
  let caught = 0, flash = 0, mode = "graze";
  function steer(a, desx, desy, force, dt) {           // steering = desired − current, clamped
    let sx = desx - a.vx, sy = desy - a.vy;
    const sl = len(sx, sy);
    if (sl > force) { sx = sx / sl * force; sy = sy / sl * force; }
    a.vx += sx * dt; a.vy += sy * dt;
    a.x += a.vx * dt; a.y += a.vy * dt;
    if (a.x < 10) { a.x = 10; a.vx = Math.abs(a.vx) * 0.4; }
    if (a.x > W - 10) { a.x = W - 10; a.vx = -Math.abs(a.vx) * 0.4; }
    if (a.y < 10) { a.y = 10; a.vy = Math.abs(a.vy) * 0.4; }
    if (a.y > H - 10) { a.y = H - 10; a.vy = -Math.abs(a.vy) * 0.4; }
  }
  return {
    press(px, py) { hunt.x = px; hunt.y = py; hunt.vx = 0; hunt.vy = 0; bored = 0; wait = 0; },
    frame(dt, t) {
      stage();
      const hx = W * 0.8, hy = H * 0.72, hr = H * D.burrow;   // the burrow
      const fear = W * D.fear;
      const dx = hunt.x - prey.x, dy = hunt.y - prey.y, d = len(dx, dy) || 1;
      const hidden = len(prey.x - hx, prey.y - hy) < hr;
      let desx, desy;
      if (d < fear) {                                  // afraid: evade the hunter's FUTURE
        const eta = d / D.preySpeed;
        const fx = hunt.x + hunt.vx * eta * D.lead, fy = hunt.y + hunt.vy * eta * D.lead;
        let ax = prey.x - fx, ay = prey.y - fy;        // seek × −1: the same vector, backwards
        const al = len(ax, ay) || 1;
        ax /= al; ay /= al;
        const tx = hx - prey.x, ty = hy - prey.y, tl = len(tx, ty) || 1;
        ax += tx / tl * 0.7; ay += ty / tl * 0.7;      // ...leaning toward the burrow
        const l2 = len(ax, ay) || 1;
        desx = ax / l2 * D.preySpeed; desy = ay / l2 * D.preySpeed;
        mode = "evade";
        if (hidden) { desx = (hx - prey.x) * 3; desy = (hy - prey.y) * 3; mode = "hide"; }
      } else {                                         // calm: graze toward a lazy target
        graze -= dt;
        if (graze <= 0) { graze = rand(2, 4); gx = rand(W * 0.1, W * 0.9); gy = rand(H * 0.1, H * 0.9); }
        const gdx = gx - prey.x, gdy = gy - prey.y, gd = len(gdx, gdy) || 1;
        const sp = D.preySpeed * 0.4 * Math.min(1, gd / 40);
        desx = gdx / gd * sp; desy = gdy / gd * sp;
        mode = "graze";
      }
      steer(prey, desx, desy, 420, dt);
      if (hidden) wait += dt; else wait = 0;           // the hunter's side of the story
      if (wait > D.patience) { wait = 0; bored = 3; bx = rand(W * 0.1, W * 0.5); by = rand(H * 0.1, H * 0.9); }
      bored -= dt;
      let ex, ey;
      if (bored > 0) { ex = bx; ey = by; }             // gave up: sulk off somewhere
      else {                                           // pursuit: lead the prey (Chase's trick)
        const eta = d / D.chaseSpeed;
        ex = prey.x + prey.vx * eta * D.lead; ey = prey.y + prey.vy * eta * D.lead;
      }
      const cdx = ex - hunt.x, cdy = ey - hunt.y, cd = len(cdx, cdy) || 1;
      const csp = D.chaseSpeed * Math.min(1, cd / 30);
      steer(hunt, cdx / cd * csp, cdy / cd * csp, 320, dt);
      const rx = hunt.x - hx, ry = hunt.y - hy, rd = len(rx, ry) || 1;
      if (rd < hr + 9) {                               // the burrow rule: no hunters inside
        hunt.x = hx + rx / rd * (hr + 9); hunt.y = hy + ry / rd * (hr + 9);
        hunt.vx *= 0.3; hunt.vy *= 0.3;
      }
      if (d < 13 && !hidden) {                         // caught: back to the burrow it goes
        caught++; flash = 1;
        prey.x = hx; prey.y = hy; prey.vx = 0; prey.vy = 0;
      }
      flash = Math.max(0, flash - dt * 2);
      ctx.setLineDash([4, 4]);
      ring(hx, hy, hr, "rgba(201,196,228,0.45)", 1.5);
      ctx.setLineDash([]);
      label("burrow", hx, hy + hr + 12, DIM, "center");
      ring(prey.x, prey.y, fear, mode === "graze" ? "rgba(155,226,138,0.12)" : "rgba(155,226,138,0.3)");
      if (mode === "evade") {                          // the point it runs FROM, made visible
        const eta = d / D.preySpeed;
        const fx = hunt.x + hunt.vx * eta * D.lead, fy = hunt.y + hunt.vy * eta * D.lead;
        ring(fx, fy, 5, "rgba(245,138,138,0.6)");
        arrow(prey.x, prey.y, prey.x + desx * 0.25, prey.y + desy * 0.25, GOOD);
      }
      if (flash > 0) ring(hunt.x, hunt.y, 14 + (1 - flash) * 26, "rgba(245,138,138," + flash * 0.8 + ")", 2);
      label(mode, prey.x, prey.y - 14, "rgba(155,226,138,0.8)", "center");
      mote(prey.x, prey.y, Math.atan2(prey.vy, prey.vx), GOOD, 7);
      mote(hunt.x, hunt.y, Math.atan2(hunt.vy, hunt.vx));
      label("flee = −seek · evade = −pursue · caught ×" + caught, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Flee", "Fox", "a hunter faster than its prey, aiming further ahead, with half the patience — only the burrow saves it now, and not for long", { chaseSpeed: 140, lead: 1.3, patience: 1.2 });

def("O", "Obstacle", "steer", "a whisker feels ahead; where it crosses a rock, steer out along the normal — press to move the goal", function (u) {
  var D = { speed: 110, force: 380, whisker: 0.3,       // px/s, steering clamp (px/s²), feeler length (× W)
            avoid: 2.4, count: 3, radius: 0.1, seed: 11 };   // dodge gain, rocks, rock size (× H), the layout's seed
  const { ctx, W, H, TAU, stage, dot, ring, mote, arrow, line, label, rand, rng, len, clamp, HOT, TARGET, BONE, DIM, GOOD } = u;
  // the mote can't see; it FEELS. a WHISKER (a feeler segment) sticks out
  // along its velocity, and each frame it asks every rock: does my whisker
  // cross you? the closest point on the segment to the rock's centre is a
  // PROJECTION (one dot product, clamped to the segment); if that point
  // lies inside the rock, steer along the NORMAL — from the rock's centre
  // out through that point — and harder the nearer the crossing is. no
  // map, no pathfinding: a reflex, which is why it sometimes dithers.
  const rnd = rng(D.seed);
  const rocks = [];
  for (let i = 0; i < D.count; i++)
    rocks.push({ x: W * (0.18 + rnd() * 0.64), y: H * (0.15 + rnd() * 0.6), r: H * D.radius * (0.7 + rnd() * 0.6) });
  function clear(px, py) {                             // a spot not inside any rock
    for (const r of rocks) if (len(px - r.x, py - r.y) < r.r + 12) return false;
    return true;
  }
  function pick() {
    for (let i = 0; i < 12; i++) {
      const px = rand(W * 0.08, W * 0.92), py = rand(H * 0.1, H * 0.9);
      if (clear(px, py)) return [px, py];
    }
    return [W * 0.5, H * 0.92];
  }
  let x = W * 0.08, y = H * 0.85, vx = 40, vy = 0, timer = 0;
  let goal = pick();
  return {
    press(px, py) { goal = [px, py]; timer = -5; },
    frame(dt, t) {
      stage();
      timer += dt;
      const dx = goal[0] - x, dy = goal[1] - y, d = len(dx, dy) || 1;
      if (d < 12 || timer > 6) { goal = pick(); timer = 0; }
      const sp = D.speed * Math.min(1, d / 50);        // Arrive at the goal...
      let desx = dx / d * sp, desy = dy / d * sp;
      const v = len(vx, vy) || 1, hx = vx / v, hy = vy / v;
      const L = W * D.whisker * clamp(v / D.speed, 0.35, 1);   // ...feeling further when faster
      let hit = null;
      for (const r of rocks) {
        const cx = r.x - x, cy = r.y - y;
        const along = clamp(cx * hx + cy * hy, 0, L);  // the projection: how far down the whisker
        const qx = x + hx * along, qy = y + hy * along;
        let nx = qx - r.x, ny = qy - r.y;
        const nd = len(nx, ny);
        if (nd > r.r + 9) continue;                    // the whisker misses this rock
        if (nd < 1) { nx = -hy; ny = hx; }             // dead centre: any sideways will do
        else { nx /= nd; ny /= nd; }
        if (!hit || along < hit.along) hit = { along: along, qx: qx, qy: qy, nx: nx, ny: ny };
      }
      if (hit) {
        const urgency = 1 - hit.along / L;             // nearer crossing = harder shove
        desx += hit.nx * D.speed * D.avoid * (0.3 + urgency);
        desy += hit.ny * D.speed * D.avoid * (0.3 + urgency);
      }
      let sx = desx - vx, sy = desy - vy;              // steering = desired − current
      const sl = len(sx, sy);
      if (sl > D.force) { sx = sx / sl * D.force; sy = sy / sl * D.force; }
      vx += sx * dt; vy += sy * dt;
      const s2 = len(vx, vy);
      if (s2 > D.speed * 1.4) { vx *= D.speed * 1.4 / s2; vy *= D.speed * 1.4 / s2; }
      x += vx * dt; y += vy * dt;
      for (const r of rocks) {                         // never inside a rock, whatever happens
        const rx = x - r.x, ry = y - r.y, rd = len(rx, ry) || 1;
        if (rd < r.r + 8) { x = r.x + rx / rd * (r.r + 8); y = r.y + ry / rd * (r.r + 8); }
      }
      x = clamp(x, 8, W - 8); y = clamp(y, 8, H - 8);
      for (const r of rocks) { dot(r.x, r.y, r.r, "rgba(201,196,228,0.12)"); ring(r.x, r.y, r.r, "rgba(201,196,228,0.5)"); }
      line(x, y, x + hx * L, y + hy * L, hit ? HOT : DIM, hit ? 1.5 : 1);   // the whisker
      if (hit) {
        dot(hit.qx, hit.qy, 3, HOT);
        arrow(hit.qx, hit.qy, hit.qx + hit.nx * 22, hit.qy + hit.ny * 22, HOT);
      }
      ring(goal[0], goal[1], 7, TARGET, 1.5);
      dot(goal[0], goal[1], 2.5, TARGET);
      mote(x, y, Math.atan2(vy, vx));
      label("q = p + h·clamp((c−p)·h, 0, L); hit if |q−c|<r", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Obstacle", "Otter", "seven smaller rocks and half again the speed — a rock field threaded at a sprint, the whisker flicking side to side", { count: 7, radius: 0.06, speed: 150 });

def("Z", "Zones", "steer", "a state machine by radius: patrol → alert → chase → return, drawn as rings — press to place the player", function (u) {
  var D = { sense: 0.24, lose: 0.42,                    // the alert ring and the give-up ring (× W)
            patrol: 55, chase: 125,                     // px/s in each mood
            alert: 0.8, drift: 0.25 };                  // seconds of "!" before the chase · how briskly the player wanders
  const { ctx, W, H, TAU, stage, dot, ring, mote, line, label, rand, len, clamp, wrapAngle, noise, TARGET, HOT, GOOD, DIM, BONE } = u;
  // a STATE MACHINE is a brain with a mood: one word names what it is
  // doing, and only a few EVENTS may change the word. here the events are
  // radii. cross the sense ring and PATROL becomes ALERT — a pause with a
  // "!" that makes stealth games fair; CHASE lasts until the player leaves
  // the bigger ring; RETURN walks home, and the loop closes. every state
  // has its own speed and its own goal: the mood IS the motion.
  const posts = [[W * 0.16, H * 0.25], [W * 0.42, H * 0.8]];
  let x = posts[0][0], y = posts[0][1], h = 0, post = 1, state = "patrol", st = 0;
  let px = W * 0.75, py = H * 0.45, hold = 0, caught = 0, flash = 0;
  function walk(tx, ty, speed, dt) {                   // move toward, turning smoothly, true on arrival
    const dx = tx - x, dy = ty - y, d = len(dx, dy) || 1;
    if (d < 4) return true;
    h += wrapAngle(Math.atan2(dy, dx) - h) * Math.min(1, 8 * dt);
    const step = Math.min(d, speed * dt);
    x += dx / d * step; y += dy / d * step;
    return false;
  }
  return {
    press(cx, cy) { px = clamp(cx, 10, W - 10); py = clamp(cy, 10, H - 10); hold = 4; },
    frame(dt, t) {
      stage();
      const sense = W * D.sense, lose = W * D.lose;
      hold -= dt;
      if (hold <= 0) {                                 // the player drifts on its own, on noise
        const a = noise(t * D.drift + 3) * Math.PI * 1.5;
        px = clamp(px + Math.cos(a) * 34 * dt, 12, W - 12);
        py = clamp(py + Math.sin(a) * 34 * dt, 12, H - 12);
      }
      const d = len(px - x, py - y);
      st += dt;
      if (state === "patrol") {
        if (walk(posts[post][0], posts[post][1], D.patrol, dt)) post = 1 - post;
        if (d < sense) { state = "alert"; st = 0; }
      } else if (state === "alert") {                  // stop, turn, and count to one
        h += wrapAngle(Math.atan2(py - y, px - x) - h) * Math.min(1, 6 * dt);
        if (st > D.alert) { state = "chase"; st = 0; }
        else if (d > sense * 1.3) { state = "patrol"; st = 0; }
      } else if (state === "chase") {
        walk(px, py, D.chase, dt);
        if (d > lose) { state = "return"; st = 0; }
        if (d < 14) {                                  // tagged: the player respawns far away
          caught++; flash = 1; state = "return"; st = 0;
          px = x < W / 2 ? W * 0.85 : W * 0.15; py = rand(H * 0.15, H * 0.85); hold = 1;
        }
      } else {                                         // return: home to the nearest post
        const n = len(posts[0][0] - x, posts[0][1] - y) < len(posts[1][0] - x, posts[1][1] - y) ? 0 : 1;
        if (walk(posts[n][0], posts[n][1], D.patrol, dt)) { state = "patrol"; post = 1 - n; st = 0; }
        if (d < sense) { state = "alert"; st = 0; }
      }
      flash = Math.max(0, flash - dt * 2);
      ctx.setLineDash([3, 5]);
      line(posts[0][0], posts[0][1], posts[1][0], posts[1][1], "rgba(201,196,228,0.3)");
      ctx.setLineDash([]);
      for (const p of posts) ring(p[0], p[1], 4, "rgba(201,196,228,0.5)");
      ring(x, y, sense, state === "patrol" ? "rgba(245,193,105,0.3)" : "rgba(245,193,105,0.15)");
      ring(x, y, lose, state === "chase" ? "rgba(245,138,138,0.35)" : "rgba(245,138,138,0.1)");
      if (flash > 0) ring(x, y, 14 + (1 - flash) * 26, "rgba(245,138,138," + flash * 0.8 + ")", 2);
      ring(px, py, 8, "rgba(245,193,105,0.5)");
      dot(px, py, 4, TARGET);
      mote(x, y, h);
      const col = state === "chase" ? HOT : (state === "alert" ? TARGET : (state === "patrol" ? GOOD : BONE));
      label(state, x, y - 15, col, "center");
      if (state === "alert") {
        ctx.fillStyle = HOT;
        ctx.font = "bold 16px system-ui, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("!", x, y - 24 - Math.sin(st * 12) * 2);
        ctx.textAlign = "left";
      }
      label("sense " + Math.round(sense) + " px · lose " + Math.round(lose) + " px · tagged ×" + caught, W / 2, 14, null, "center");
      label("patrol → alert → chase → return, by radius", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Zones", "Zealot", "a sense ring twice as wide, a give-up ring it can barely leave, no pause at all — a guard that never lets go", { sense: 0.45, lose: 0.85, alert: 0.15 });

def("G", "Ghost", "steer", "it only moves behind your back: a dot product says if it's in the view cone — press to look toward your click", function (u) {
  var D = { cone: 70, speed: 70,                        // view cone width (degrees) · ghost px/s while unseen
            turn: 3.2, glance: 2.2,                     // gaze turn rate (rad/s) · seconds between glances
            boo: 12 };                                  // how close counts as a scare (px)
  const { ctx, W, H, TAU, stage, dot, ring, mote, line, label, rand, len, clamp, wrapAngle, MAGIC, MOVER, HOT, DIM } = u;
  // "is it in view?" is one DOT PRODUCT. normalise the vector to the
  // ghost, dot it with the gaze direction, and the answer is cos(angle
  // between them) — so "inside a 70° cone" is simply dot > cos(35°). the
  // ghost Arrives at the mote while that test fails and freezes the
  // instant it passes: Weeping Angels, Boo, red-light-green-light, all
  // this one comparison. the gaze looks around with Yaw's turn limit.
  const cx = W / 2, cy = H * 0.55;
  let h = 0, aim = 0, glance = 0, hold = 0;
  let gx = 0, gy = 0, gvx = 0, gvy = 0, scares = 0, flash = 0;
  function spawn() {                                   // somewhere on the rim, out of view
    const a = h + Math.PI + rand(-1, 1);
    const R = Math.max(W, H) * 0.6;
    gx = clamp(cx + Math.cos(a) * R, 6, W - 6); gy = clamp(cy + Math.sin(a) * R, 6, H - 6);
    gvx = 0; gvy = 0;
  }
  spawn();
  return {
    press(px, py) { aim = Math.atan2(py - cy, px - cx); hold = 2.5; },
    frame(dt, t) {
      stage();
      hold -= dt; glance -= dt;
      if (hold <= 0 && glance <= 0) { glance = D.glance * rand(0.6, 1.4); aim = rand(-Math.PI, Math.PI); }
      h += clamp(wrapAngle(aim - h), -D.turn * dt, D.turn * dt);   // the gaze, turn-rate limited
      const half = D.cone * Math.PI / 360;
      const dx = gx - cx, dy = gy - cy, d = len(dx, dy) || 1;
      const dotp = dx / d * Math.cos(h) + dy / d * Math.sin(h);    // ← the whole test
      const seen = dotp > Math.cos(half);
      if (seen) { gvx = 0; gvy = 0; }                  // frozen, mid-step
      else {                                           // Arrive at the mote
        const sp = D.speed * Math.min(1, d / 50);
        let sx = -dx / d * sp - gvx, sy = -dy / d * sp - gvy;
        const sl = len(sx, sy);
        if (sl > 300) { sx = sx / sl * 300; sy = sy / sl * 300; }
        gvx += sx * dt; gvy += sy * dt;
        gx += gvx * dt; gy += gvy * dt;
      }
      if (d < D.boo) { scares++; flash = 1; spawn(); }
      flash = Math.max(0, flash - dt * 1.5);
      const R = Math.max(W, H);                        // the cone, painted
      ctx.fillStyle = "rgba(232,229,244,0.06)";
      ctx.beginPath(); ctx.moveTo(cx, cy); ctx.arc(cx, cy, R, h - half, h + half); ctx.closePath(); ctx.fill();
      line(cx, cy, cx + Math.cos(h - half) * R, cy + Math.sin(h - half) * R, DIM);
      line(cx, cy, cx + Math.cos(h + half) * R, cy + Math.sin(h + half) * R, DIM);
      if (flash > 0) ring(cx, cy, 12 + (1 - flash) * 40, "rgba(201,160,245," + flash * 0.7 + ")", 2);
      const bob = seen ? 0 : Math.sin(t * 5) * 2;      // it drifts when it moves, hangs when it's caught
      const gc = seen ? "rgba(201,160,245,0.45)" : MAGIC;
      dot(gx, gy + bob, 8, gc);
      ctx.fillStyle = gc;
      ctx.fillRect(gx - 8, gy + bob, 16, 7);
      for (let i = 0; i < 3; i++) dot(gx - 5.3 + i * 5.3, gy + bob + 7, 2.7, gc);
      dot(gx - 3, gy + bob - 2, 1.6, "#131020");       // two hollow eyes
      dot(gx + 3, gy + bob - 2, 1.6, "#131020");
      if (seen) ring(gx, gy, 13, "rgba(201,160,245,0.5)");
      label("dot = " + dotp.toFixed(2), gx, gy - 16, "rgba(201,160,245,0.8)", "center");
      mote(cx, cy, h);
      label("scares ×" + scares, W / 2, 14, null, "center");
      label("seen if gaze · dir > cos(" + (D.cone / 2) + "°) → freeze", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Ghost", "Ghoul", "a cone twice as wide but a thing nearly twice as fast, a gaze that flits every second — seen more, and it still gets you", { cone: 140, speed: 130, glance: 0.9 });

def("T", "Tractorbeam", "steer", "a cone of pull: full on the axis, fading with distance, debris spirals into the hold — drag to sweep the beam", function (u) {
  var D = { half: 20, reach: 0.8,                       // cone half-angle (degrees) · beam length (× H)
            pull: 260, damp: 1.4,                       // px/s² on the axis at the ship · drag on debris (per s)
            sweep: 0.45, count: 24 };                   // idle sweep rate (rad/s) · bits of debris
  const { ctx, W, H, TAU, stage, dot, ring, mote, line, poly, label, rand, len, clamp, wrapAngle, noise, MOVER, TARGET, BONE, MAGIC, DIM } = u;
  // a force field with a SHAPE. every bit of debris asks two questions:
  // how far off the beam's axis am I (an angle — atan2, then wrapAngle),
  // and how far down it (a distance)? inside the cone the pull is
  //   F = pull · (1 − |off| ÷ half) ÷ (1 + d ÷ R)
  // — full on the axis, nothing at the rim, fading down the beam — plus a
  // nudge toward the axis so the flow funnels. outside the cone: nothing,
  // just drift. inside the hold ring a bit is caught and spirals in on
  // Orbit's polar trick with a shrinking r. this is Magnet, given an aim.
  const sx = W / 2, sy = H * 0.16;
  let beam = Math.PI / 2, aim = Math.PI / 2, hold = 0, held = 0;
  const bits = [];
  function spawn(b) { b.x = rand(0, W); b.y = rand(H * 0.35, H); b.vx = rand(-12, 12); b.vy = rand(-8, 8); b.caught = false; b.a = 0; b.r = 0; }
  for (let i = 0; i < D.count; i++) { const b = { seed: i * 9.1 }; spawn(b); bits.push(b); }
  return {
    drag: true,
    press(px, py) {
      aim = Math.PI / 2 + clamp(wrapAngle(Math.atan2(py - sy, px - sx) - Math.PI / 2), -1.35, 1.35);
      hold = 3;
    },
    frame(dt, t) {
      stage();
      hold -= dt;
      if (hold <= 0) aim = Math.PI / 2 + Math.sin(t * D.sweep) * 0.9;   // the idle sweep
      beam += wrapAngle(aim - beam) * Math.min(1, 6 * dt);
      const half = D.half * Math.PI / 180, R = H * D.reach, HOLD = 15;
      const ax = Math.cos(beam), ay = Math.sin(beam);   // the axis, and its normal
      const nx = -ay, ny = ax;
      poly([[sx, sy], [sx + Math.cos(beam - half) * R, sy + Math.sin(beam - half) * R],
            [sx + Math.cos(beam + half) * R, sy + Math.sin(beam + half) * R]], "rgba(245,193,105,0.08)");
      line(sx, sy, sx + Math.cos(beam - half) * R, sy + Math.sin(beam - half) * R, "rgba(245,193,105,0.35)");
      line(sx, sy, sx + Math.cos(beam + half) * R, sy + Math.sin(beam + half) * R, "rgba(245,193,105,0.35)");
      ctx.setLineDash([3, 5]);
      line(sx, sy, sx + ax * R, sy + ay * R, "rgba(245,193,105,0.3)");
      ctx.setLineDash([]);
      const k = Math.exp(-D.damp * dt);                 // framerate-proof drag
      for (const b of bits) {
        if (b.caught) {                                 // the spiral into the hold
          b.a += 5 * dt; b.r = Math.max(0, b.r - 12 * dt);
          b.x = sx + Math.cos(b.a) * b.r; b.y = sy + Math.sin(b.a) * b.r;
          if (b.r <= 0.5) { held++; spawn(b); }
          dot(b.x, b.y, 2.4, MAGIC);
          continue;
        }
        const dx = b.x - sx, dy = b.y - sy, d = len(dx, dy) || 1;
        const off = wrapAngle(Math.atan2(dy, dx) - beam);
        const inside = Math.abs(off) < half && d < R;
        if (inside) {
          const F = D.pull * (1 - Math.abs(off) / half) / (1 + d / (R * 0.5));   // ← the field's shape
          b.vx += -dx / d * F * dt; b.vy += -dy / d * F * dt;
          const side = dx * nx + dy * ny;              // signed distance off the axis
          b.vx += -nx * side * 2.5 * dt; b.vy += -ny * side * 2.5 * dt;   // the funnel
          if (d < HOLD) { b.caught = true; b.a = Math.atan2(dy, dx); b.r = d; }
        } else {                                       // adrift: a breath of noise
          b.vx += noise(t * 0.3 + b.seed) * 18 * dt;
          b.vy += noise(t * 0.3 + b.seed + 40) * 18 * dt;
        }
        b.vx *= k; b.vy *= k;
        const s = len(b.vx, b.vy);
        if (s > 260) { b.vx *= 260 / s; b.vy *= 260 / s; }
        b.x += b.vx * dt; b.y += b.vy * dt;
        if (b.x < -6) b.x = W + 6; if (b.x > W + 6) b.x = -6;
        if (b.y < -6) b.y = H + 6; if (b.y > H + 6) b.y = -6;
        dot(b.x, b.y, 2.2, inside ? "rgba(245,193,105,0.9)" : BONE);
      }
      ring(sx, sy, HOLD, "rgba(245,193,105,0.6)");
      mote(sx, sy, beam, MOVER, 9);
      label("F = pull·(1−|off|/half)÷(1+d/R) · held ×" + held, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Tractorbeam", "Trawler", "a cone nearly three times as wide, a weaker pull, twice the debris — a slow net that gathers, not a beam that snatches", { half: 55, pull: 150, count: 44 });

def("F", "Firefly", "steer", "wander on smooth noise, glow on a personal phase, Arrive at the lantern when lit — press to move the lantern", function (u) {
  var D = { count: 14, speed: 42,                       // fireflies · px/s
            wander: 0.35, slow: 0.3,                    // how fast the noise is sampled · the lantern's Arrive ring (× W)
            lit: 3.5, dark: 2.5, blink: 0.6 };          // the lantern's seconds on and off · glows per second
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, rect, line, label, rand, len, clamp, noise, GOOD, TARGET, BONE, DIM } = u;
  // Wander with its dice swapped for NOISE: each fly's heading is
  // noise(t · rate + its own offset) · π — smooth, never twitchy, and no
  // two alike because each samples a different stretch of the same
  // function (Jitter's lesson). the glow is a sine on a personal PHASE, so
  // the meadow twinkles instead of strobing. when the lantern is lit,
  // Arrive takes the wheel — desired = toward it, braking inside the slow
  // ring — with a little wander still mixed in, so they hover, not park.
  const flies = [];
  for (let i = 0; i < D.count; i++)
    flies.push({ x: rand(0, W), y: rand(H * 0.1, GY - 10), vx: 0, vy: 0, ph: rand(0, TAU), seed: i * 17.3 });
  let lx = W * 0.5, ly = GY - H * 0.18, clock = 0;
  return {
    press(px, py) { lx = clamp(px, 14, W - 14); ly = clamp(py, H * 0.2, GY - 12); clock = 0; },
    frame(dt, t) {
      stage(); ground();
      clock += dt;
      if (clock > D.lit + D.dark) clock -= D.lit + D.dark;
      const on = clock < D.lit;
      line(lx, GY, lx, ly + 8, BONE, 1.5);             // the lamp post
      rect(lx - 5, ly - 8, 10, 15, on ? TARGET : "rgba(245,193,105,0.3)");
      if (on) {
        ring(lx, ly, 14 + Math.sin(t * 3) * 2, "rgba(245,193,105,0.35)");
        ring(lx, ly, 24 + Math.sin(t * 3 + 1) * 3, "rgba(245,193,105,0.15)");
        ctx.setLineDash([3, 6]);
        ring(lx, ly - 14, W * D.slow, "rgba(245,193,105,0.18)");
        ctx.setLineDash([]);
      }
      for (const f of flies) {
        const a = noise(t * D.wander + f.seed) * Math.PI * 1.5;   // a smooth, personal heading
        let desx = Math.cos(a) * D.speed, desy = Math.sin(a) * D.speed * 0.6;
        if (on) {                                      // Arrive, with the wander kept as seasoning
          const dx = lx - f.x, dy = ly - 14 - f.y, d = len(dx, dy) || 1;
          const sp = D.speed * 1.6 * Math.min(1, d / (W * D.slow));
          desx = dx / d * sp + desx * 0.45; desy = dy / d * sp + desy * 0.45;
        }
        f.vx += (desx - f.vx) * Math.min(1, 2.5 * dt);
        f.vy += (desy - f.vy) * Math.min(1, 2.5 * dt);
        f.x += f.vx * dt; f.y += f.vy * dt;
        if (f.x < -8) f.x = W + 8; if (f.x > W + 8) f.x = -8;
        if (f.y < H * 0.06) { f.y = H * 0.06; f.vy = Math.abs(f.vy); }
        if (f.y > GY - 6) { f.y = GY - 6; f.vy = -Math.abs(f.vy); }
        let g = Math.max(0, Math.sin(t * TAU * D.blink + f.ph));   // the glow, on its own phase
        g = g * g;                                     // squared: short bright, long dim
        dot(f.x, f.y, 1.6 + g * 1.6, "rgba(155,226,138," + (0.25 + g * 0.7) + ")");
        if (g > 0.3) ring(f.x, f.y, 4 + g * 3, "rgba(155,226,138," + (g * 0.25) + ")");
      }
      label(on ? "lit — Arrive" : "dark — wander", lx, ly - 22, "rgba(245,193,105,0.7)", "center");
      label("h = noise(t·r + i)·π · glow = sin(t·b + φᵢ)²", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Firefly", "Flicker", "twice the flies, twice the speed, glows nearly three times as quick — a busier, sparkier meadow that mobs the lantern", { count: 30, speed: 80, blink: 1.6 });

def("B", "Butterfly", "steer", "flap impulses on a jittered timer, gravity between, a slow Arrive to the next flower — press to plant a flower", function (u) {
  var D = { kick: 0.6, gravity: 1.3,                    // a flap's upward kick (× H per s) · gravity (× H per s²)
            flap: 0.34, jitter: 0.5,                    // seconds between flaps, and how uneven they are (a fraction)
            speed: 65, linger: 1.2 };                   // px/s toward the flower · seconds sipping nectar
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, poly, label, rand, len, clamp, TARGET, GOOD, MOVER, BONE } = u;
  // why does a butterfly look nothing like a bird? IMPULSES. a bird's lift
  // is continuous; a butterfly's is a kick — an instant upward velocity
  // at every flap, gravity pulling between kicks — and the flap timer is
  // JITTERED (rand around a mean), so the sawtooth never repeats. it only
  // flaps while it's below the flower, so it bobs about the flower's
  // height instead of climbing forever. under that stagger a slow Arrive
  // tows it sideways toward the next flower; the flowers are a list,
  // visited in turn. Jitter's randomness + Arrive's intent = erratic,
  // and still gets there.
  function defaults() { return [[W * 0.2, GY - H * 0.3], [W * 0.55, GY - H * 0.5], [W * 0.85, GY - H * 0.25]]; }
  let flowers = defaults(), idx = 0;
  let x = W * 0.1, y = H * 0.3, vx = 0, vy = 0, flapT = 0.2, since = 1, linger = 0;
  return {
    press(px, py) {
      if (flowers.length >= 6) { flowers = defaults(); idx = 0; }
      flowers.push([clamp(px, 12, W - 12), clamp(py, H * 0.12, GY - 14)]);
      idx = flowers.length - 1; linger = 0;
    },
    frame(dt, t) {
      stage(); ground();
      const f = flowers[idx];
      since += dt;
      if (linger > 0) {                                // sitting: wings slowly fanning
        linger -= dt;
        x = f[0]; y = f[1] - 6; vx = 0; vy = 0;
        if (linger <= 0) { idx = (idx + 1) % flowers.length; vy = -H * D.kick; since = 0; }
      } else {
        flapT -= dt;
        if (flapT <= 0) {
          flapT = D.flap * (1 + rand(-D.jitter, D.jitter));   // the jittered timer
          if (y > f[1] - 12) {                         // only flap when below the flower
            vy = Math.min(vy, 0) * 0.3 - H * D.kick * rand(0.8, 1.2);   // ← the IMPULSE
            since = 0;
          }
        }
        vy += H * D.gravity * dt;                      // gravity between flaps
        const dx = f[0] - x, d = Math.abs(dx) || 1;
        const sp = D.speed * Math.min(1, d / 50);      // Arrive, sideways only
        vx += (dx / d * sp - vx) * Math.min(1, 2 * dt);
        x += vx * dt; y += vy * dt;
        if (y > GY - 8) { y = GY - 8; vy = Math.min(vy, 0); }
        if (y < H * 0.06) { y = H * 0.06; vy = Math.max(vy, 0); }
        x = clamp(x, 8, W - 8);
        if (Math.abs(x - f[0]) < 8 && Math.abs(y - f[1]) < 14) linger = D.linger;
      }
      flowers.forEach((p, i) => {
        line(p[0], GY, p[0], p[1] + 4, "rgba(155,226,138,0.5)", 1.5);
        ring(p[0], p[1], 5, TARGET, 1.5);
        dot(p[0], p[1], 2.5, TARGET);
        if (i === idx) ring(p[0], p[1], 10, "rgba(245,193,105,0.35)");
      });
      const s = linger > 0 ? 0.55 + 0.45 * Math.sin(t * 3)   // wing spread: a quick sweep after each kick
                           : (since < 0.22 ? 0.25 + 0.75 * Math.abs(Math.cos(since / 0.22 * Math.PI)) : 1);
      const wc = "rgba(138,217,245,0.7)";
      poly([[x, y], [x - 10 * s, y - 8], [x - 13 * s, y - 1], [x - 8 * s, y + 6]], wc);
      poly([[x, y], [x + 10 * s, y - 8], [x + 13 * s, y - 1], [x + 8 * s, y + 6]], wc);
      dot(x, y, 3, MOVER);
      label("vy = −kick on a jittered timer · g between", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Butterfly", "Bumblebee", "flaps four times as often, each half the kick, twice the drive — the sawtooth blurs into a buzzing, near-straight hover", { flap: 0.08, kick: 0.32, speed: 120 });

def("Z", "Zombies", "steer", "a horde: seek with a noisy heading, lurch on a personal timer, keep apart — press to move the player", function (u) {
  var D = { count: 16, speed: 40, lurch: 0.8,           // zombies · px/s at full lurch · lurches per second
            wobble: 0.9, sep: 18,                       // heading noise (radians) · personal space (px)
            player: 70 };                               // px/s: the player is quicker, and never rests
  const { ctx, W, H, TAU, stage, dot, ring, mote, label, rand, len, clamp, wrapAngle, noise, MAGIC, MOVER, HOT, DIM } = u;
  // Arrive's seek, degraded on purpose. each zombie aims at the player,
  // then spoils the aim with noise (a wobble on the heading, sampled at
  // its own offset), moves in LURCHES — a speed that pulses as sin² on a
  // personal timer, so the pauses are real — and keeps a little
  // separation from its neighbours (Swarm's first rule, and nothing
  // else: no alignment, no cohesion; a horde has no manners). slow,
  // uneven, many: the threat is arithmetic, not speed.
  const zs = [];
  for (let i = 0; i < D.count; i++)
    zs.push({ x: rand(0, W * 0.4), y: rand(0, H), h: 0, ph: rand(0, TAU), rate: rand(0.7, 1.3), seed: i * 7.7 });
  let px = W * 0.75, py = H * 0.5, pvx = 0, pvy = 0, pa = 0, bites = 0, flash = 0;
  return {
    press(cx, cy) { px = clamp(cx, 10, W - 10); py = clamp(cy, 10, H - 10); pvx = 0; pvy = 0; flash = 0.6; },
    frame(dt, t) {
      stage();
      let mx = 0, my = 0;                              // the horde's centre, for the player's nerves
      for (const z of zs) { mx += z.x; my += z.y; }
      mx /= zs.length; my /= zs.length;
      pa += rand(-1, 1) * 2.2 * Math.sqrt(dt);         // the player: Wander's jitter...
      let desx = Math.cos(pa) * D.player, desy = Math.sin(pa) * D.player;
      const fdx = px - mx, fdy = py - my, fd = len(fdx, fdy) || 1;
      if (fd < W * 0.45) { desx += fdx / fd * D.player * 1.2; desy += fdy / fd * D.player * 1.2; }   // ...plus flee
      desx += (W / 2 - px) * 0.5; desy += (H / 2 - py) * 0.5;       // and a leash to the middle
      pvx += (desx - pvx) * Math.min(1, 3 * dt);
      pvy += (desy - pvy) * Math.min(1, 3 * dt);
      const ps = len(pvx, pvy);
      if (ps > D.player * 1.6) { pvx *= D.player * 1.6 / ps; pvy *= D.player * 1.6 / ps; }
      px = clamp(px + pvx * dt, 10, W - 10); py = clamp(py + pvy * dt, 10, H - 10);
      let bitten = false;
      for (let i = 0; i < zs.length; i++) {
        const z = zs[i];
        const want = Math.atan2(py - z.y, px - z.x) + noise(t * 0.6 + z.seed) * D.wobble;   // aim, spoiled
        z.h += wrapAngle(want - z.h) * Math.min(1, 3 * dt);
        const pulse = Math.max(0, Math.sin(t * TAU * D.lurch * z.rate + z.ph));
        const v = D.speed * (0.08 + 0.92 * pulse * pulse);   // ← the lurch
        let sx = 0, sy = 0;
        for (let j = 0; j < zs.length; j++) {          // separation, and only separation
          if (j === i) continue;
          const o = zs[j], dx = z.x - o.x, dy = z.y - o.y, d = len(dx, dy);
          if (d < D.sep && d > 0.01) { sx += dx / d * (D.sep - d); sy += dy / d * (D.sep - d); }
        }
        z.x += (Math.cos(z.h) * v + sx * 3) * dt;
        z.y += (Math.sin(z.h) * v + sy * 3) * dt;
        z.x = clamp(z.x, 6, W - 6); z.y = clamp(z.y, 6, H - 6);
        if (len(px - z.x, py - z.y) < 11) bitten = true;
        mote(z.x, z.y, z.h, MAGIC, 6);
      }
      if (bitten) {                                    // respawn on the far side of the horde
        bites++; flash = 1;
        px = mx < W / 2 ? W * 0.88 : W * 0.12; py = rand(H * 0.15, H * 0.85); pvx = 0; pvy = 0;
      }
      flash = Math.max(0, flash - dt * 2);
      if (flash > 0) ring(px, py, 12 + (1 - flash) * 24, "rgba(245,138,138," + flash * 0.8 + ")", 2);
      mote(px, py, Math.atan2(pvy, pvx));
      label("bites ×" + bites, W / 2, 14, null, "center");
      label("v = max·sin²(t·f + φᵢ) · heading = aim + noise", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Zombies", "Zerg", "twice the horde, twice the speed, lurches four times as fast — the shuffle becomes a rush the player can't outrun", { count: 30, speed: 85, lurch: 3 });

def("V", "Volley", "steer", "paddles solve the flight for the landing point, Arrive there first, then lob it back — press to nudge the ball", function (u) {
  var D = { gravity: 2.2, apex: 0.45,                   // gravity (× H per s²) · the height every return aims for (× H)
            reach: 0.06, paddle: 0.9,                   // a paddle's half-width (× W) and top speed (× W per s)
            net: 0.22, nudge: 0.9 };                    // net height (× H) · the press's shove (× H per s)
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, rect, label, rand, len, clamp, TARGET, GOOD, MOVER, BONE, HOT, DIM } = u;
  // Chase predicted with one multiply; this predicts with the quadratic
  // formula. a ball under gravity reaches a height h below it after
  //   t = (v + √(v² + 2·g·h)) ÷ g          (solve  h = v·t + ½·g·t²  for t)
  // and its LANDING POINT is just x + vx·t — so a paddle knows where to
  // stand the moment the ball leaves the far side, and Arrives there
  // (braking, not overshooting). the return runs Jump backwards: choose
  // the apex, v₀ = √(2·g·apex) is the launch, the flight time 2·v₀ ÷ g
  // picks the vx that lands it on a spot of the paddle's choosing.
  const PY = GY - 10;
  const pads = [{ x: W * 0.22, vx: 0, side: -1, c: GOOD }, { x: W * 0.78, vx: 0, side: 1, c: MOVER }];
  let bx = W * 0.22, by = PY - 30, bvx = 0, bvy = 0, dead = 0.6, server = 0, rally = 0;
  function hit(from, side, g) {                        // launch toward a spot on the other court
    const v0 = Math.sqrt(2 * g * H * D.apex);
    const T = 2 * v0 / g;
    const tx = W / 2 - side * W * rand(0.12, 0.42);
    bvy = -v0; bvx = (tx - from) / T;
  }
  return {
    press(px, py) {
      if (dead > 0) { dead = 0; hit(bx, pads[server].side, H * D.gravity); return; }
      const dx = px - bx, dy = py - by, d = len(dx, dy) || 1;
      bvx += dx / d * H * D.nudge; bvy += dy / d * H * D.nudge;
    },
    frame(dt, t) {
      stage(); ground();
      const g = H * D.gravity, reach = W * D.reach, pspeed = W * D.paddle, netH = H * D.net;
      if (dead > 0) {
        dead -= dt;
        if (dead <= 0) { server = 1 - server; bx = pads[server].x; by = PY - 30; hit(bx, pads[server].side, g); }
      } else {
        const wasLeft = bx < W / 2;
        bvy += g * dt;
        const bs = len(bvx, bvy);
        if (bs > H * 4) { bvx *= H * 4 / bs; bvy *= H * 4 / bs; }
        bx += bvx * dt; by += bvy * dt;
        if (bx < 6) { bx = 6; bvx = Math.abs(bvx) * 0.7; }
        if (bx > W - 6) { bx = W - 6; bvx = -Math.abs(bvx) * 0.7; }
        if (wasLeft !== (bx < W / 2) && by > GY - netH) {   // into the net
          bvx = -bvx * 0.5; bx = wasLeft ? W / 2 - 6 : W / 2 + 6;
        }
        for (const p of pads)                          // a paddle under it: the return
          if (bvy > 0 && by >= PY - 6 && Math.abs(bx - p.x) < reach + 5 && (bx - W / 2) * p.side > 0) {
            by = PY - 6; hit(bx, p.side, g); rally++;
          }
        if (by > GY - 5) { dead = 1.2; rally = 0; }    // a miss: the floor
      }
      let lx = bx;
      if (dead <= 0) {                                 // the prediction, for both paddles
        const h = Math.max(0, PY - 6 - by);
        const tl = (bvy + Math.sqrt(bvy * bvy + 2 * g * h)) / g;   // ← the quadratic formula
        lx = bx + bvx * tl;
        if (lx < 6) lx = 12 - lx;                      // folded at the walls
        if (lx > W - 6) lx = 2 * (W - 6) - lx;
        lx = clamp(lx, 6, W - 6);
        ctx.fillStyle = "rgba(245,193,105,0.3)";
        for (let i = 1; i <= 16; i++) {                // the flight, dotted
          const k = tl * i / 16;
          let fx = bx + bvx * k;
          if (fx < 6) fx = 12 - fx; if (fx > W - 6) fx = 2 * (W - 6) - fx;
          ctx.fillRect(fx - 1, by + bvy * k + 0.5 * g * k * k - 1, 2, 2);
        }
        ring(lx, PY, 6, "rgba(245,193,105,0.6)", 1.5);
      }
      for (const p of pads) {                          // Arrive at the landing x, or drift home
        const mine = dead <= 0 && (lx - W / 2) * p.side > 0;
        const goal = mine ? lx : W / 2 + p.side * W * 0.28;
        const d = goal - p.x;
        const sp = pspeed * Math.min(1, Math.abs(d) / 30);
        p.vx += (Math.sign(d) * sp - p.vx) * Math.min(1, 8 * dt);
        p.x += p.vx * dt;
        p.x = p.side < 0 ? clamp(p.x, reach + 4, W / 2 - reach - 4) : clamp(p.x, W / 2 + reach + 4, W - reach - 4);
        rect(p.x - reach, PY, reach * 2, 5, p.c);
      }
      line(W / 2, GY, W / 2, GY - netH, BONE, 2);      // the net
      rect(W / 2 - 4, GY - netH - 2, 8, 3, BONE);
      dot(bx, by, 5, TARGET);
      label("rally " + rally, W / 2, 14, null, "center");
      label("t = (v + √(v² + 2gh)) ÷ g → lands at x + vx·t", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Volley", "Velocity", "twice the gravity, lower lobs, paddles half again as quick — the same maths played fast and flat", { gravity: 4.5, apex: 0.3, paddle: 1.5 });

/* ============================== CROWDS & FIELDS ==============================
   Many bodies, one rule each — or one formula over space that everything
   obeys. A crowd has no script: each grain, bird, sheep, or walker reads
   only its neighbours and the field it stands in, and the flock, the spiral,
   the formation, the tidy crossing simply HAPPEN. Magnets and vortices are
   fields (position → a push); boids, herds and crossings are neighbour
   rules (look around → a nudge); belts and marching grids are both. */

def("M", "Magnet", "crowds", "inverse-square fields: dust in the pull of three magnets — press to flip them", function (u) {
  var D = { mags: [[0.28, 0.38, 1], [0.72, 0.34, 1], [0.5, 0.72, -1]],   // x, y as fractions, then polarity
            grains: 36, strength: 26000, soften: 900, orbit: 24, drag: 0.7, maxsp: 190,
            label: "force = k ÷ distance² — flip: pull ⇄ push" };
  const { ctx, W, H, TAU, stage, dot, ring, label, rand, len, TARGET, HOT } = u;
  // force fields, the gravity-and-charge law: strength = k ÷ distance².
  // every grain sums one small vector per magnet, plus drag so it settles
  // instead of slingshotting forever. attractors breathe inward, the
  // repulsor breathes outward — the field, made legible.
  const mags = D.mags.map(m => ({ x: W * m[0], y: H * m[1], p: m[2] }));
  const dust = [];
  for (let i = 0; i < D.grains; i++)
    dust.push({ x: rand(0, W), y: rand(0, H), vx: 0, vy: 0 });
  return {
    press() { for (const m of mags) m.p = -m.p; },     // invert the world
    frame(dt, t) {
      stage();
      for (const g of dust) {
        for (const m of mags) {
          const dx = m.x - g.x, dy = m.y - g.y;
          const dd = dx * dx + dy * dy + D.soften;      // +soften tames the singularity
          const f = m.p * D.strength / dd;
          const d = Math.sqrt(dd);
          g.vx += dx / d * f * dt * 60;
          g.vy += dy / d * f * dt * 60;
          if (m.p > 0) {                               // a whisper of sideways push,
            g.vx += -dy / d * f * dt * D.orbit;        // so grains orbit the pull
            g.vy += dx / d * f * dt * D.orbit;         // instead of parking in it
          }
        }
        g.vx *= 1 - D.drag * dt; g.vy *= 1 - D.drag * dt;   // drag = the settling
        const s = len(g.vx, g.vy);
        if (s > D.maxsp) { g.vx *= D.maxsp / s; g.vy *= D.maxsp / s; }
        g.x += g.vx * dt; g.y += g.vy * dt;
        if (g.x < 0) g.x = W; if (g.x > W) g.x = 0;
        if (g.y < 0) g.y = H; if (g.y > H) g.y = 0;
        dot(g.x, g.y, 1.7, "rgba(232,229,244,0.7)");
      }
      for (const m of mags) {
        const c = m.p > 0 ? TARGET : HOT;
        const k = (t * 0.8) % 1;
        const r = m.p > 0 ? 22 - k * 14 : 8 + k * 14;  // breathe in = pull, out = push
        dot(m.x, m.y, 5, c);
        ring(m.x, m.y, r, m.p > 0 ? "rgba(245,193,105," + (0.5 - Math.abs(0.5 - k) * 0.6) + ")"
                                  : "rgba(245,138,138," + (0.55 - k * 0.5) + ")", 1.5);
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Magnet", "Moths", "twice the grains, the sideways whisper turned to a shout, half the drag — they circle the lamps and never land", { grains: 70, orbit: 110, drag: 0.35 });

def("V", "Vectorfield", "crowds", "a formula turns every point into an arrow; riders obey — press to pour more in", function (u) {
  var D = { riders: 40, speed: 62, scaleX: 0.019, scaleY: 0.023, driftX: 0.24, driftY: 0.17, swing: 1.6,
            grid: 36, pour: 14,
            label: "angle(x, y, t) = sin(x·s + t) + cos(y·s − t)" };
  const { ctx, W, H, TAU, stage, dot, arrow, label, rand, MOVER } = u;
  // a vector field is a function from position to direction — invisible
  // level design. wind, currents, lava flows, bullet-hell patterns: define
  // angle(x, y, t), and anything dropped in follows the grain. the field
  // here slowly morphs; the arrows sample it so you can read the weather.
  function fieldAngle(x, y, t) {
    return Math.sin(x * D.scaleX + t * D.driftX) * D.swing + Math.cos(y * D.scaleY - t * D.driftY) * D.swing;
  }
  const riders = [];
  for (let i = 0; i < D.riders; i++) riders.push({ x: rand(0, W), y: rand(0, H) });
  return {
    press(px, py) {
      for (let i = 0; i < D.pour; i++) {
        const r = riders[Math.floor(rand(0, riders.length))];
        r.x = px + rand(-8, 8); r.y = py + rand(-8, 8);
      }
    },
    frame(dt, t) {
      stage();
      for (let gx = 20; gx < W; gx += D.grid)
        for (let gy = 20; gy < H; gy += D.grid) {
          const a = fieldAngle(gx, gy, t);
          arrow(gx - Math.cos(a) * 5, gy - Math.sin(a) * 5,
                gx + Math.cos(a) * 5, gy + Math.sin(a) * 5, "rgba(232,229,244,0.16)");
        }
      for (const r of riders) {
        const a = fieldAngle(r.x, r.y, t);
        r.x += Math.cos(a) * D.speed * dt;
        r.y += Math.sin(a) * D.speed * dt;
        if (r.x < 0) r.x = W; if (r.x > W) r.x = 0;
        if (r.y < 0) r.y = H; if (r.y > H) r.y = 0;
        ctx.strokeStyle = "rgba(138,217,245,0.5)";     // a short wake, against the grain
        ctx.beginPath(); ctx.moveTo(r.x - Math.cos(a) * 6, r.y - Math.sin(a) * 6);
        ctx.lineTo(r.x, r.y); ctx.stroke();
        dot(r.x, r.y, 2, MOVER);
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Vectorfield", "Vertigo", "the same formula sampled three times denser and morphing four times faster — a churning, dizzy weather", { scaleX: 0.06, scaleY: 0.07, driftX: 1.1 });

def("S", "Swarm", "crowds", "boids: separation + alignment + cohesion, nobody in charge — press to scare them", function (u) {
  var D = { n: 26, sepR: 26, nbrR: 54, align: 1.4, cohere: 1.1, sepK: 3400, minsp: 55, maxsp: 105,
            fear: 9000, greens: 2,
            label: "three averages over neighbours = the brain" };
  const { ctx, W, H, TAU, stage, label, rand, len, MOVER, GOOD } = u;
  // three rules, each an average over neighbours: don't crowd (push apart
  // inside sepR px), don't stray (match nearby velocities), don't drift
  // (drop toward the local centre). no leader exists — the green birds
  // are ordinary; follow one and watch it obey the same three nudges.
  const boids = [];
  for (let i = 0; i < D.n; i++)
    boids.push({ x: rand(0, W), y: rand(0, H), vx: rand(-60, 60), vy: rand(-60, 60), g: i < D.greens });
  return {
    press(px, py) {
      for (const b of boids) {
        const dx = b.x - px, dy = b.y - py, d = len(dx, dy) + 4;
        b.vx += dx / d * D.fear / d;                   // fear, inverse with distance
        b.vy += dy / d * D.fear / d;
      }
    },
    frame(dt, t) {
      stage();
      for (const b of boids) {
        let sx = 0, sy = 0, ax = 0, ay = 0, cx = 0, cy = 0, n = 0;
        for (const o of boids) {
          if (o === b) continue;
          const dx = o.x - b.x, dy = o.y - b.y, d = len(dx, dy);
          if (d < D.sepR && d > 0) { sx -= dx / d / d; sy -= dy / d / d; }   // 1: separation
          if (d < D.nbrR) { ax += o.vx; ay += o.vy; cx += o.x; cy += o.y; n++; }
        }
        if (n) {
          b.vx += (ax / n - b.vx) * D.align * dt;      // 2: alignment
          b.vy += (ay / n - b.vy) * D.align * dt;
          b.vx += (cx / n - b.x) * D.cohere * dt;      // 3: cohesion
          b.vy += (cy / n - b.y) * D.cohere * dt;
        }
        b.vx += sx * D.sepK * dt; b.vy += sy * D.sepK * dt;
        const s = len(b.vx, b.vy) || 1;
        const sp = Math.min(D.maxsp, Math.max(D.minsp, s));   // a floor keeps the flock flowing
        b.vx *= sp / s; b.vy *= sp / s;
        b.x += b.vx * dt; b.y += b.vy * dt;
        if (b.x < -8) b.x = W + 8; if (b.x > W + 8) b.x = -8;
        if (b.y < -8) b.y = H + 8; if (b.y > H + 8) b.y = -8;
      }
      for (const b of boids) {
        ctx.save();
        ctx.translate(b.x, b.y);
        ctx.rotate(Math.atan2(b.vy, b.vx));
        ctx.fillStyle = b.g ? GOOD : MOVER;
        ctx.beginPath(); ctx.moveTo(6, 0); ctx.lineTo(-4, 3.4); ctx.lineTo(-4, -3.4);
        ctx.closePath(); ctx.fill();
        ctx.restore();
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Swarm", "Starlings", "forty birds with the alignment and cohesion nudges doubled — a tight murmuration that turns as one body", { n: 40, align: 3.2, cohere: 2.6 });

def("W", "Whirlpool", "crowds", "a vortex field: swirl ∝ 1/r plus a slow inward pull spirals debris into the eye — press to move the eye", function (u) {
  var D = { debris: 60, swirl: 2600, pull: 0.35, core: 18, rim: 0.46, maxsp: 200, grid: 34, follow: 3,
            label: "v = (swirl ÷ r) · (tangent + pull · inward)" };
  const { ctx, W, H, TAU, stage, dot, ring, arrow, label, rand, len, smooth, MAGIC, DIM } = u;
  // Vectorfield's lesson wearing Magnet's law: a VORTEX is a field whose
  // arrows run around a point with speed ∝ 1/r (the water hurries where the
  // circle is small). add a small radial share and every path becomes a
  // LOGARITHMIC SPIRAL — the same pitch at any radius. debris rides the field
  // kinematically (position += v·dt, no mass, like Vectorfield's riders);
  // whatever reaches the core is reborn at the rim, so the spiral never empties.
  let ex = W / 2, ey = H * 0.5, tx = ex, ty = ey, swallowed = 0;
  const R = () => Math.min(W, H) * D.rim;
  function field(x, y) {                               // position → velocity, the whole card
    const dx = x - ex, dy = y - ey, r = len(dx, dy) || 1;
    const vt = Math.min(D.swirl / r, D.maxsp);         // tangential speed ∝ 1/r (capped)
    return [(-dy / r - dx / r * D.pull) * vt, (dx / r - dy / r * D.pull) * vt];
  }
  const bits = [];
  function spawn(b) {
    const a = rand(0, TAU), r = R() * rand(0.9, 1.1);
    b.x = ex + Math.cos(a) * r; b.y = ey + Math.sin(a) * r; b.s = rand(1.3, 2.6);
  }
  for (let i = 0; i < D.debris; i++) { const b = {}; spawn(b); b.x = ex + (b.x - ex) * rand(0.3, 1); b.y = ey + (b.y - ey) * rand(0.3, 1); bits.push(b); }
  return {
    press(px, py) { tx = px; ty = py; },
    frame(dt, t) {
      stage();
      const k = smooth(D.follow, dt);                  // the eye glides, the water follows
      ex += (tx - ex) * k; ey += (ty - ey) * k;
      for (let gx = 17; gx < W; gx += D.grid)
        for (let gy = 17; gy < H; gy += D.grid) {
          const v = field(gx, gy), s = len(v[0], v[1]) || 1;
          arrow(gx - v[0] / s * 5, gy - v[1] / s * 5, gx + v[0] / s * 5, gy + v[1] / s * 5, "rgba(232,229,244,0.16)");
        }
      ring(ex, ey, R(), "rgba(201,160,245,0.18)");
      const n = dt > 0.03 ? 2 : 1, h = dt / n;         // a substep keeps tight turns honest
      for (const b of bits) {
        for (let i = 0; i < n; i++) {
          const v = field(b.x, b.y);
          b.x += v[0] * h; b.y += v[1] * h;
        }
        if (len(b.x - ex, b.y - ey) < D.core) { swallowed++; spawn(b); }
        const v = field(b.x, b.y), s = len(v[0], v[1]) || 1;
        ctx.strokeStyle = "rgba(232,229,244,0.35)";    // a wake along the flow
        ctx.beginPath(); ctx.moveTo(b.x - v[0] / s * 5, b.y - v[1] / s * 5); ctx.lineTo(b.x, b.y); ctx.stroke();
        dot(b.x, b.y, b.s, "rgba(232,229,244,0.75)");
      }
      for (let i = 0; i < 3; i++) {                    // the throat: three rings sinking
        const q = (t * 0.7 + i / 3) % 1;
        ring(ex, ey, D.core * (1.8 - q * 0.9), "rgba(201,160,245," + (0.15 + q * 0.5) + ")", 1.5);
      }
      dot(ex, ey, D.core * 0.45, "#131020");
      label("speed ∝ 1/r", ex + D.core + 6, ey + 3, "rgba(201,160,245,0.8)");
      label("swallowed ×" + swallowed, 8, 14, "rgba(201,160,245,0.7)");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Whirlpool", "Wormhole", "twice the swirl, a third of the pull, a wider throat — a fast tight spin that barely sinks: a wormhole's mouth", { swirl: 5200, pull: 0.12, core: 26 });

def("H", "Herd", "crowds", "Swarm's boids that also flee a dog (Magnet's repulsor); it works them into the pen — press to place the dog", function (u) {
  var D = { n: 14, sepR: 18, nbrR: 46, align: 1.2, cohere: 0.5, sepK: 900, fear: 260, dogR: 80, maxsp: 75, drag: 1.6,
            graze: 14, pen: [0.66, 0.22, 0.78], gate: [0.42, 0.68], dogEvery: 3.2, rest: 2.5,
            label: "v += flee(dog) + boids − v·drag" };
  const { ctx, W, H, TAU, stage, dot, ring, line, mote, label, rand, len, noise, smooth, BONE, HOT, TARGET, DIM } = u;
  // Swarm's three averages, slowed down and given drag so a sheep can STAND,
  // plus one more push: fear of the dog, inverse with distance (Magnet's
  // repulsor, wearing a collar). no sheep knows where the pen is — the dog
  // stands where the flock must not go, and the fence does the rest: a sheep
  // stopped by a rail feels along it toward the gap. when every sheep is in,
  // a bucket lures them back out and the whole errand starts again.
  const px0 = W * D.pen[0], py0 = H * D.pen[1], py1 = H * D.pen[2];
  const gy0 = H * D.gate[0], gy1 = H * D.gate[1], gmid = (gy0 + gy1) / 2;
  const sheep = [];
  for (let i = 0; i < D.n; i++)
    sheep.push({ x: rand(W * 0.08, W * 0.45), y: rand(H * 0.15, H * 0.85), vx: 0, vy: 0, h: 0, ph: i * 7.3 });
  const dog = { x: W * 0.1, y: H * 0.5, tx: W * 0.1, ty: H * 0.5, on: false };
  let dogTimer = D.dogEvery * 0.5, manual = 0, restTimer = 0, lure = 0, penned = 0;
  function inPen(s) { return s.x > px0 + 6 && s.y > py0 && s.y < py1; }
  return {
    press(x, y) { dog.tx = x; dog.ty = y; dog.on = true; manual = 6; lure = 0; },
    frame(dt, t) {
      stage();
      manual -= dt; dogTimer -= dt; lure -= dt;
      if (dogTimer <= 0 && manual <= 0 && lure <= 0) { // the dog's own plan: stand behind the
        dogTimer = D.dogEvery;                         // flock on the line from the gate
        let cx = 0, cy = 0, m = 0;
        for (const s of sheep) if (!inPen(s)) { cx += s.x; cy += s.y; m++; }
        if (m) {
          cx /= m; cy /= m;
          const dx = cx - (px0 - 6), dy = cy - gmid, d = len(dx, dy) || 1;
          dog.tx = cx + dx / d * D.dogR * 0.7; dog.ty = cy + dy / d * D.dogR * 0.7; dog.on = true;
        }
      }
      const kd = smooth(4, dt);
      dog.x += (dog.tx - dog.x) * kd; dog.y += (dog.ty - dog.y) * kd;
      penned = 0;
      for (const s of sheep) if (inPen(s)) penned++;
      if (penned === D.n && lure <= 0) { restTimer += dt; if (restTimer > D.rest) { restTimer = 0; lure = 3; dog.on = false; } }
      else restTimer = 0;
      const lx = px0 - W * 0.18, ly = gmid;            // the bucket, out past the gate
      for (const s of sheep) {
        let fx = 0, fy = 0, ax = 0, ay = 0, cx = 0, cy = 0, n = 0;
        for (const o of sheep) {
          if (o === s) continue;
          const dx = o.x - s.x, dy = o.y - s.y, d = len(dx, dy);
          if (d < D.sepR && d > 0) { fx -= dx / d / d * D.sepK; fy -= dy / d / d * D.sepK; }
          if (d < D.nbrR) { ax += o.vx; ay += o.vy; cx += o.x; cy += o.y; n++; }
        }
        if (n) {
          fx += (ax / n - s.vx) * D.align; fy += (ay / n - s.vy) * D.align;
          fx += (cx / n - s.x) * D.cohere; fy += (cy / n - s.y) * D.cohere;
        }
        if (dog.on) {
          const dx = s.x - dog.x, dy = s.y - dog.y, d = len(dx, dy) || 1;
          if (d < D.dogR) { fx += dx / d * D.fear * (1 - d / D.dogR); fy += dy / d * D.fear * (1 - d / D.dogR); }
        }
        if (lure > 0) { const dx = lx - s.x, dy = ly - s.y, d = len(dx, dy) || 1; fx += dx / d * 120; fy += dy / d * 120; }
        fx += noise(s.ph + t * 0.5) * D.graze;         // grazing: a slow, personal drift
        fy += noise(s.ph + 50 + t * 0.5) * D.graze;
        const inside = inPen(s);
        s.vx += fx * dt; s.vy += fy * dt;
        const dr = D.drag * (inside ? 3 : 1);          // penned sheep settle
        s.vx *= Math.max(0, 1 - dr * dt); s.vy *= Math.max(0, 1 - dr * dt);
        const sp = len(s.vx, s.vy);
        if (sp > D.maxsp) { s.vx *= D.maxsp / sp; s.vy *= D.maxsp / sp; }
        const ox = s.x, oy = s.y;
        s.x += s.vx * dt; s.y += s.vy * dt;
        if ((ox < px0) !== (s.x < px0) && (s.y < gy0 || s.y > gy1)) {   // the left rail, with its gap
          s.x = ox < px0 ? px0 - 1 : px0 + 1; s.vx = 0;
          s.vy += (gmid > s.y ? 30 : -30) * dt * 10;   // feel along the rail toward the gap
        }
        if (s.x > px0 && (oy < py0) !== (s.y < py0)) { s.y = oy < py0 ? py0 - 1 : py0 + 1; s.vy = -s.vy * 0.2; }
        if (s.x > px0 && (oy < py1) !== (s.y < py1)) { s.y = oy < py1 ? py1 - 1 : py1 + 1; s.vy = -s.vy * 0.2; }
        if (s.x < 8) { s.x = 8; s.vx = Math.abs(s.vx); } if (s.x > W - 8) { s.x = W - 8; s.vx = -Math.abs(s.vx); }
        if (s.y < 8) { s.y = 8; s.vy = Math.abs(s.vy); } if (s.y > H - 8) { s.y = H - 8; s.vy = -Math.abs(s.vy); }
        if (sp > 4) s.h = Math.atan2(s.vy, s.vx);
      }
      line(px0, py0, W, py0, "rgba(201,196,228,0.5)", 1.5);     // the pen
      line(px0, py1, W, py1, "rgba(201,196,228,0.5)", 1.5);
      line(px0, py0, px0, gy0, "rgba(201,196,228,0.5)", 1.5);
      line(px0, gy1, px0, py1, "rgba(201,196,228,0.5)", 1.5);
      for (let x = px0; x < W; x += 18) { dot(x, py0, 2, BONE); dot(x, py1, 2, BONE); }
      for (let y = py0; y < py1; y += 18) if (y < gy0 || y > gy1) dot(px0, y, 2, BONE);
      if (lure > 0) { dot(lx, ly, 4, TARGET); ring(lx, ly, 8 + (3 - lure) * 6, "rgba(245,193,105,0.4)"); }
      for (const s of sheep) {
        dot(s.x, s.y, 6, BONE);
        dot(s.x + Math.cos(s.h) * 5.5, s.y + Math.sin(s.h) * 5.5, 3, "#4A4560");   // the blackface
      }
      if (dog.on) {
        ring(dog.x, dog.y, D.dogR, "rgba(245,138,138,0.18)");
        let cx = 0, cy = 0; for (const s of sheep) { cx += s.x; cy += s.y; }
        mote(dog.x, dog.y, Math.atan2(cy / D.n - dog.y, cx / D.n - dog.x), HOT, 6);
      }
      label("penned " + penned + "/" + D.n, 8, 14, "rgba(201,196,228,0.7)");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Herd", "Hens", "more of them, twice as fast, twice as scared of the dog — a panicked flap of hens instead of a placid flock", { n: 22, fear: 620, maxsp: 140 });

def("X", "Xing", "crowds", "Obstacle, for movers: predict the closest approach to each neighbour, step aside early — press to add a walker", function (u) {
  var D = { n: 14, speed: 52, spread: 0.4, minDist: 20, horizon: 2.6, turn: 5, dodge: 260, band: [0.24, 0.76],
            label: "t* = −(r·v) ÷ (v·v) — dodge if d(t*) < r_min" };
  const { ctx, W, H, TAU, stage, dot, ring, line, mote, label, rand, len, MOVER, GOOD, HOT, DIM } = u;
  // Obstacle steered around things that stand still; a walker must dodge
  // things that MOVE, so it looks ahead. for each neighbour: relative
  // position r, relative velocity v; the TIME TO CLOSEST APPROACH is
  // t* = −(r·v)/(v·v), and r + v·t* is how near they will pass. if that is
  // under a personal radius and t* is soon, push sideways — never brake.
  // everyone has their own pace, so the crowd thins and bunches like a real one.
  const y0 = H * D.band[0], y1 = H * D.band[1];
  const walkers = [];
  function spawn(w, dir, x, y) {
    w.dir = dir; w.x = x; w.y = y; w.gy = rand(y0 + 8, y1 - 8);
    w.sp = D.speed * (1 + rand(-D.spread, D.spread));
    w.vx = dir * w.sp; w.vy = 0;
  }
  for (let i = 0; i < D.n; i++) {
    const w = {}, dir = i % 2 ? -1 : 1;
    spawn(w, dir, rand(0, W), rand(y0 + 8, y1 - 8));
    walkers.push(w);
  }
  let urgent = null;
  return {
    press(x, y) {
      const w = {};
      spawn(w, x < W / 2 ? 1 : -1, x, Math.min(y1 - 8, Math.max(y0 + 8, y)));
      walkers.push(w);
      if (walkers.length > D.n + 8) walkers.shift();   // the oldest walker goes home
    },
    frame(dt, t) {
      stage();
      line(0, y0, W, y0, "rgba(201,196,228,0.45)", 1.5);   // the kerbs
      line(0, y1, W, y1, "rgba(201,196,228,0.45)", 1.5);
      for (let x = 6; x < W; x += 24) ctx.fillStyle = "rgba(201,196,228,0.05)", ctx.fillRect(x, y0, 10, y1 - y0);
      let worst = D.minDist; urgent = null;
      for (const w of walkers) {
        const gx = w.dir > 0 ? W + 14 : -14;
        const dx = gx - w.x, dy = w.gy - w.y, d = len(dx, dy) || 1;
        let fx = (dx / d * w.sp - w.vx) * D.turn, fy = (dy / d * w.sp - w.vy) * D.turn;   // desired − current
        const s0 = len(w.vx, w.vy) || 1, px = -w.vy / s0, py = w.vx / s0;   // my left-hand side
        for (const o of walkers) {
          if (o === w) continue;
          const rx = o.x - w.x, ry = o.y - w.y, vx = o.vx - w.vx, vy = o.vy - w.vy;
          const vv = vx * vx + vy * vy;
          if (vv < 1) continue;                        // moving together: nothing to predict
          const ts = -(rx * vx + ry * vy) / vv;        // ← time to closest approach
          if (ts < 0 || ts > D.horizon) continue;      // already passed, or too far off
          const cx = rx + vx * ts, cy = ry + vy * ts, cd = len(cx, cy);
          if (cd < D.minDist) {
            const side = (px * cx + py * cy) > 0 ? -1 : 1;   // they'll pass on my left → step right
            const str = D.dodge * (1 - ts / D.horizon) * (1 - cd / D.minDist);
            fx += px * side * str; fy += py * side * str;
            if (cd < worst) { worst = cd; urgent = [w.x + w.vx * ts, w.y + w.vy * ts, o.x + o.vx * ts, o.y + o.vy * ts, w]; }
          }
          const rd = len(rx, ry) || 1;                 // the last-resort shove, if a prediction lied
          if (rd < D.minDist * 0.5) { fx -= rx / rd * D.dodge * 0.5; fy -= ry / rd * D.dodge * 0.5; }
        }
        if (w.y < y0 + 6) fy += (y0 + 6 - w.y) * 8;    // the kerbs push back softly
        if (w.y > y1 - 6) fy += (y1 - 6 - w.y) * 8;
        w.vx += fx * dt; w.vy += fy * dt;
        const s = len(w.vx, w.vy) || 1;
        const sp = Math.min(w.sp * 1.25, Math.max(w.sp * 0.7, s));   // nobody stops, nobody sprints
        w.vx *= sp / s; w.vy *= sp / s;
        w.x += w.vx * dt; w.y += w.vy * dt;
        if ((w.dir > 0 && w.x > W + 12) || (w.dir < 0 && w.x < -12))
          spawn(w, w.dir, w.dir > 0 ? -12 : W + 12, rand(y0 + 8, y1 - 8));   // across; start again
      }
      if (urgent) {                                    // the nearest miss, made visible
        ring(urgent[0], urgent[1], D.minDist / 2, "rgba(245,138,138,0.45)");
        line(urgent[0], urgent[1], urgent[2], urgent[3], "rgba(245,138,138,0.45)");
        line(urgent[4].x, urgent[4].y, urgent[0], urgent[1], DIM);
      }
      for (const w of walkers) mote(w.x, w.y, Math.atan2(w.vy, w.vx), w.dir > 0 ? MOVER : GOOD, 5);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Xing", "Xmas", "the rush: more walkers, twice the pace, a tighter personal radius — a christmas-eve crowd that never touches", { n: 22, speed: 88, minDist: 15 });

def("I", "Invaders", "crowds", "Zigzag's schedule on a grid: the formation's beat quickens as it thins — press to shoot the one you click", function (u) {
  var D = { cols: 8, rows: 4, gapX: 0.075, gapY: 0.085, step: 0.035, drop: 0.05, beat: 0.6, beatMin: 0.07,
            wobble: 2.5, regroup: 1.6,
            label: "interval = beat · alive ÷ total" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, rect, line, mote, label, len, smooth, MAGIC, HOT, MOVER } = u;
  // nothing here moves smoothly: the formation is a SCHEDULE. every
  // interval seconds it takes one step sideways; when the outermost living
  // column would leave the screen it drops a row and turns. the famous
  // trick is the tempo: interval ∝ alive ÷ total, so the last invader
  // sprints — no code for "get harder", just a timer that shrinks with the
  // count. columns wobble on a sine, so the grid reads as creatures.
  const total = D.cols * D.rows;
  const width = (D.cols - 1) * D.gapX * W;
  const fx0 = (W - width) / 2, fy0 = H * 0.1;
  let alive = [], fx = fx0, fy = fy0, dir = 1, timer = D.beat, pose = 0, regroup = 0, interval = D.beat;
  let cannonX = W / 2, cannonT = W / 2, flash = 0, hit = [0, 0];
  function reset() { alive = []; for (let i = 0; i < total; i++) alive.push(true); fx = fx0; fy = fy0; dir = 1; timer = D.beat; }
  reset();
  const ix = i => fx + (i % D.cols) * D.gapX * W, iy = i => fy + Math.floor(i / D.cols) * D.gapY * H;
  return {
    press(x, y) {
      cannonT = x;
      let best = -1, bd = 1e9;
      for (let i = 0; i < total; i++) {
        if (!alive[i]) continue;
        const dx = Math.abs(ix(i) - x), dy = Math.abs(iy(i) - y);
        if (dx < D.gapX * W / 2 && dy < D.gapY * H / 2 && dx + dy < bd) { bd = dx + dy; best = i; }
      }
      if (best >= 0) { alive[best] = false; flash = 0.18; hit = [ix(best), iy(best)]; }
    },
    frame(dt, t) {
      stage(); ground();
      let count = 0, cmin = D.cols, cmax = -1, rmax = -1;
      for (let i = 0; i < total; i++) if (alive[i]) {
        count++; const c = i % D.cols, r = Math.floor(i / D.cols);
        if (c < cmin) cmin = c; if (c > cmax) cmax = c; if (r > rmax) rmax = r;
      }
      if (count === 0) { regroup += dt; if (regroup > D.regroup) { regroup = 0; reset(); } }
      else {
        interval = Math.max(D.beatMin, D.beat * count / total);   // ← the tempo rule
        timer -= dt;
        if (timer <= 0) {
          timer += interval; pose = 1 - pose;
          const left = fx + cmin * D.gapX * W - 10, right = fx + cmax * D.gapX * W + 10;
          if ((dir > 0 && right + D.step * W > W) || (dir < 0 && left - D.step * W < 0)) { dir = -dir; fy += D.drop * H; }
          else fx += dir * D.step * W;
          if (fy + rmax * D.gapY * H > GY - 14) reset();   // landed — the invasion begins again
        }
      }
      for (let i = 0; i < total; i++) {
        if (!alive[i]) continue;
        const x = ix(i) + Math.sin(t * 3 + (i % D.cols) * 0.9) * D.wobble, y = iy(i);
        rect(x - 6, y - 3, 12, 6, MAGIC);              // a pixel invader, two poses
        rect(x - 4, y - 6, 2, 3, MAGIC); rect(x + 2, y - 6, 2, 3, MAGIC);
        rect(x - 3, y - 2, 2, 2, "#131020"); rect(x + 1, y - 2, 2, 2, "#131020");
        if (pose) { rect(x - 7, y + 3, 3, 2, MAGIC); rect(x + 4, y + 3, 3, 2, MAGIC); }
        else { rect(x - 4, y + 3, 2, 3, MAGIC); rect(x + 2, y + 3, 2, 3, MAGIC); }
      }
      cannonX += (cannonT - cannonX) * smooth(8, dt);  // the reader's ship slides to the click
      flash -= dt;
      if (flash > 0) {
        line(cannonX, GY - 10, hit[0], hit[1], HOT, 2);
        ring(hit[0], hit[1], 6 + (0.18 - flash) * 80, "rgba(245,138,138," + (flash / 0.18) + ")", 2);
      }
      mote(cannonX, GY - 8, -Math.PI / 2, MOVER, 7);
      label("interval " + interval.toFixed(2) + " s · " + count + "/" + total + " alive", 8, 14, "rgba(201,160,245,0.75)");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Invaders", "Insects", "six rows, a beat twice as fast, a deeper drop each turn — a skittering bug wall that lands in half the time", { rows: 6, beat: 0.3, drop: 0.08 });

def("C", "Conveyor", "crowds", "Vectorfield in rectangles: crates inherit the belt under them, a gate sorts the lanes — press to flip the gate", function (u) {
  var D = { speed: 64, spawnEvery: 1.15, maxCrates: 12, autoFlip: 3.6, inherit: 9, crate: 9, chevron: 16,
            belts: [[0, 0.44, 0.5, 0.14], [0.5, 0.12, 0.5, 0.14], [0.5, 0.74, 0.5, 0.14]],   // x, y, w, h as fractions
            gate: [0.5, 0.12, 0.1, 0.76],
            label: "on a belt: v += (belt.v − v) · smooth(k, dt)" };
  const { ctx, W, H, TAU, stage, dot, rect, line, poly, label, rand, len, smooth, BONE, MOVER, GOOD, TARGET, DIM } = u;
  // a belt is the simplest vector field there is: a rectangle, and one
  // velocity everywhere inside it. a crate asks "which belt am I on?" and
  // lerps its velocity toward that belt's (INHERITED velocity — Platform's
  // trick, flat). the riser at the junction is a belt too; the gate only
  // flips the sign of its velocity, and that one sign sorts the whole day's
  // cargo into two lanes. the arrows scroll so you can read the belts.
  const belts = D.belts.map(b => ({ x: W * b[0], y: H * b[1], w: W * b[2], h: H * b[3], vx: D.speed, vy: 0 }));
  const riser = { x: W * D.gate[0], y: H * D.gate[1], w: W * D.gate[2], h: H * D.gate[3], vx: 0, vy: -D.speed };
  const order = [belts[1], belts[2], riser, belts[0]];  // lanes first: the riser hands over at its ends
  const crates = [];
  let up = true, spawnT = 0, autoT = 0, manual = 0, sorted = [0, 0];
  const feedY = belts[0].y + belts[0].h / 2, gateX = riser.x;
  function on(b, c) { return c.x >= b.x && c.x <= b.x + b.w && c.y >= b.y && c.y <= b.y + b.h; }
  return {
    press() { up = !up; manual = 5; },
    frame(dt, t) {
      stage();
      manual -= dt; autoT += dt;
      if (manual <= 0 && autoT > D.autoFlip) { autoT = 0; up = !up; }   // left alone, it alternates
      riser.vy = up ? -D.speed : D.speed;
      spawnT += dt;
      if (spawnT > D.spawnEvery && crates.length < D.maxCrates) {
        spawnT = 0; crates.push({ x: -D.crate, y: feedY + rand(-2, 2), vx: D.speed, vy: 0, c: BONE, lane: -1, lost: 0 });
      }
      const k = smooth(D.inherit, dt);
      for (let i = crates.length - 1; i >= 0; i--) {
        const c = crates[i];
        let b = null;
        for (const cand of order) if (on(cand, c)) { b = cand; break; }
        if (b) {                                       // ← the whole idea: inherit the belt
          c.vx += (b.vx - c.vx) * k; c.vy += (b.vy - c.vy) * k; c.lost = 0;
          if (b === belts[1] && c.lane < 0) { c.lane = 0; c.c = GOOD; }
          if (b === belts[2] && c.lane < 0) { c.lane = 1; c.c = MOVER; }
        } else { c.vx *= 1 - 4 * dt; c.vy *= 1 - 4 * dt; c.lost += dt; }
        c.x += c.vx * dt; c.y += c.vy * dt;
        if (c.x > W + D.crate || c.lost > 3) { if (c.lane >= 0) sorted[c.lane]++; crates.splice(i, 1); }
      }
      for (let i = 0; i < crates.length; i++)          // crates don't overlap: a nudge apart
        for (let j = i + 1; j < crates.length; j++) {
          const a = crates[i], c = crates[j], dx = c.x - a.x, dy = c.y - a.y, d = len(dx, dy) || 1;
          if (d < D.crate * 1.2) { const p = (D.crate * 1.2 - d) / 2; a.x -= dx / d * p; a.y -= dy / d * p; c.x += dx / d * p; c.y += dy / d * p; }
        }
      const all = belts.concat([riser]);
      for (const b of all) {
        rect(b.x, b.y, b.w, b.h, "rgba(201,196,228,0.07)");
        line(b.x, b.y, b.x + b.w, b.y, DIM); line(b.x, b.y + b.h, b.x + b.w, b.y + b.h, DIM);
        const sp = D.chevron, off = ((t * D.speed) % sp + sp) % sp;
        if (b.vx) {                                    // scrolling chevrons: › › › ›
          const my = b.y + b.h / 2;
          for (let x = b.x + off; x < b.x + b.w - 2; x += sp) poly([[x, my - 4], [x + 4, my], [x, my + 4]], "rgba(232,229,244,0.22)", 1);
        } else {                                       // the riser's point up or down
          const mx = b.x + b.w / 2, s = up ? 1 : -1;
          for (let y = b.y + (up ? sp - off : off); y < b.y + b.h - 2; y += sp) poly([[mx - 4, y + 4 * s], [mx, y], [mx + 4, y + 4 * s]], "rgba(232,229,244,0.22)", 1);
        }
      }
      const gy = up ? riser.y + riser.h * 0.1 : riser.y + riser.h * 0.9;   // the gate paddle
      line(gateX, feedY, gateX + riser.w * 0.9, up ? feedY - riser.w * 0.6 : feedY + riser.w * 0.6, TARGET, 3);
      dot(gateX, feedY, 3.5, TARGET);
      for (const c of crates) {
        rect(c.x - D.crate / 2, c.y - D.crate / 2, D.crate, D.crate, c.c);
        line(c.x - D.crate / 2 + 2, c.y, c.x + D.crate / 2 - 2, c.y, "#131020");
      }
      label("▲ " + sorted[0], W - 8, belts[1].y - 4, "rgba(155,226,138,0.8)", "right");
      label("▼ " + sorted[1], W - 8, belts[2].y + belts[2].h + 12, "rgba(138,217,245,0.8)", "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Conveyor", "Crunch", "the same belts at 2.3× speed, a crate every half second, the gate flipping thrice as often — crunch mode", { speed: 150, spawnEvery: 0.5, autoFlip: 1.1 });

/* ============================== PATHS, GRIDS & SCHEDULES ==============================
   A route REMEMBERED. The clocks stored nothing and the springs stored a
   velocity; these bodies store a LIST — waypoints, control points, grid
   cells, floors, keyframes, throws — plus one number saying how far along
   it they are. "Where am I" becomes a bookmark instead of a coordinate: a
   distance along a spline, a cell in a maze, a beat in a timetable. A*, a
   Bézier, Frogger, Pac-Man, a lift, and a juggler are all the same
   bookmark being moved. */

def("A", "Astar", "paths", "a* on a walled grid — f = g + h, with the open and closed sets on show — press to set the goal, or to open a wall you click", function (u) {
  var D = { cols: 12, rows: 8, seed: 7, wallChance: 0.26,   // the maze: seeded, so it is the same on every visit
            greed: 1,                                        // weight on h — 1 is honest A*, more is greedy
            hopTime: 0.22, hopLift: 0.35, pause: 1.1,        // the walk: seconds per cell, lift in cells, rest at the goal
            label: "f = g + h · h = |dx| + |dy| (Manhattan)" };
  const { W, H, stage, rect, ring, line, mote, label, rng, rand, ease, clamp, MOVER, TARGET } = u;
  // PATHFINDING on a grid. every cell scores f = g + h: g is the distance
  // walked to reach it, h a HEURISTIC guess of the distance still to go —
  // Manhattan, |dx| + |dy|, which never overestimates, so the first route
  // to reach the goal is the shortest. the OPEN set (green) is the frontier
  // still to inspect; the CLOSED set (red) has been inspected. pop the
  // cheapest open cell, offer its four neighbours a better g, repeat until
  // the goal pops. weight h by more than 1 and A* turns GREEDY: fewer cells
  // inspected, no promise of shortest.
  const cols = D.cols, rows = D.rows, cw = W / cols, ch = (H - 18) / rows, N = cols * rows;
  let walls = [], state = [], path = null, pi = 0;
  let cell = [0, rows - 1], goal = [cols - 1, 0];
  let hop = null, wait = 0;
  function id(c) { return c[1] * cols + c[0]; }
  function search(from, to) {
    const g = [], came = [], open = [];
    state = [];
    for (let i = 0; i < N; i++) { g.push(Infinity); came.push(-1); state.push(0); }
    const h = (i) => (Math.abs(i % cols - to[0]) + Math.abs(Math.floor(i / cols) - to[1])) * D.greed;
    g[id(from)] = 0; open.push(id(from)); state[id(from)] = 1;
    let found = false;
    while (open.length) {
      let bi = 0;                                        // the cheapest f in the open set
      for (let i = 1; i < open.length; i++)
        if (g[open[i]] + h(open[i]) < g[open[bi]] + h(open[bi])) bi = i;
      const cur = open[bi]; open[bi] = open[open.length - 1]; open.pop();
      state[cur] = 2;                                    // inspected: closed
      if (cur === id(to)) { found = true; break; }
      const cc = cur % cols, cr = Math.floor(cur / cols);
      const nb = [[cc + 1, cr], [cc - 1, cr], [cc, cr + 1], [cc, cr - 1]];
      for (const n of nb) {
        if (n[0] < 0 || n[1] < 0 || n[0] >= cols || n[1] >= rows) continue;
        const ni = id(n);
        if (walls[ni] || state[ni] === 2) continue;
        if (g[cur] + 1 < g[ni]) {                        // a better way to reach it
          g[ni] = g[cur] + 1; came[ni] = cur;
          if (state[ni] !== 1) { state[ni] = 1; open.push(ni); }
        }
      }
    }
    if (!found) return null;
    const p = [];                                        // walk the breadcrumbs back
    for (let i = id(to); i >= 0; i = came[i]) p.push([i % cols, Math.floor(i / cols)]);
    return p.reverse();
  }
  for (let s = 0; s < 40 && !path; s++) {                // the first seed whose maze can be solved
    const r = rng(D.seed + s);
    walls = [];
    for (let i = 0; i < N; i++) walls.push(r() < D.wallChance);
    walls[id(cell)] = false; walls[id(goal)] = false;
    path = search(cell, goal);
  }
  function replan() {
    path = search(hop ? hop.to : cell, goal); pi = 0;   // mid-hop, plan from where the hop lands
    if (!path) wait = D.pause;
  }
  function newGoal() {                                   // a random open cell it can actually reach
    for (let tries = 0; tries < 20; tries++) {
      const c = [Math.floor(rand(0, cols)), Math.floor(rand(0, rows))];
      if (walls[id(c)] || (c[0] === cell[0] && c[1] === cell[1]) || !search(cell, c)) continue;
      goal = c; return;
    }
  }
  return {
    press(x, y) {
      const c = [clamp(Math.floor(x / cw), 0, cols - 1), clamp(Math.floor(y / ch), 0, rows - 1)];
      if (walls[id(c)]) walls[id(c)] = false;            // knock a wall down...
      else goal = c;                                     // ...or move the goal
      wait = 0;
      replan();
    },
    frame(dt, t) {
      stage();
      if (hop) {
        hop.k += dt / D.hopTime;
        if (hop.k >= 1) {
          cell = hop.to; hop = null; pi++;
          if (!path || pi >= path.length - 1) wait = D.pause;   // arrived: a rest
        }
      }
      if (!hop) {
        if (wait > 0) wait -= dt;
        else if (path && pi < path.length - 1) hop = { from: path[pi], to: path[pi + 1], k: 0 };
        else { newGoal(); replan(); }                    // a fresh errand
      }
      let nc = 0, no = 0;
      for (let i = 0; i < N; i++) {
        const x = (i % cols) * cw, y = Math.floor(i / cols) * ch;
        if (walls[i]) rect(x + 1, y + 1, cw - 2, ch - 2, "rgba(201,196,228,0.32)");
        else if (state[i] === 2) { nc++; rect(x + 1, y + 1, cw - 2, ch - 2, "rgba(245,138,138,0.13)"); }
        else if (state[i] === 1) { no++; rect(x + 1, y + 1, cw - 2, ch - 2, "rgba(155,226,138,0.16)"); }
      }
      const cx = (c) => (c[0] + 0.5) * cw, cy = (c) => (c[1] + 0.5) * ch;
      if (path)
        for (let i = 0; i + 1 < path.length; i++)
          line(cx(path[i]), cy(path[i]), cx(path[i + 1]), cy(path[i + 1]), "rgba(245,193,105,0.55)", 1.5);
      ring(cx(goal), cy(goal), Math.min(cw, ch) * 0.3, TARGET, 1.5);
      let mx = cx(cell), my = cy(cell), ang = 0;
      if (hop) {
        const k = ease(hop.k);
        mx = cx(hop.from) + (cx(hop.to) - cx(hop.from)) * k;
        my = cy(hop.from) + (cy(hop.to) - cy(hop.from)) * k
             - Math.sin(clamp(hop.k, 0, 1) * Math.PI) * D.hopLift * ch;   // the hop's little arc
        ang = Math.atan2(hop.to[1] - hop.from[1], hop.to[0] - hop.from[0]);
      }
      mote(mx, my, ang, MOVER, Math.min(cw, ch) * 0.26);
      label("closed " + nc + " · open " + no + (path ? " · path " + (path.length - 1) : " · no path"), W - 4, 11, null, "right");
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Astar", "Anthill", "a denser maze and a greedier h (×2.5) at scurrying speed — fewer cells inspected, and not always the shortest way", { wallChance: 0.36, greed: 2.5, hopTime: 0.1 });

def("B", "Bezier", "paths", "a cubic bézier is three lerps deep — de casteljau's scaffold drawn live at k — drag to move the nearest handle", function (u) {
  var D = { p0: [0.08, 0.76], p1: [0.2, 0.08], p2: [0.8, 0.08], p3: [0.92, 0.76],   // control points, fractions of W and H
            period: 3.2,                                   // seconds per flight, end to end
            label: "B(k): three lerps deep — de Casteljau" };
  const { ctx, W, H, stage, dot, ring, line, mote, label, lerp, len, clamp, MOVER, TARGET, BONE, GOOD } = u;
  // a BÉZIER curve is nothing but lerps. lerp along P0→P1, P1→P2, P2→P3 to
  // get three points; lerp between those to get two; lerp between those to
  // get one — that is the curve at k. this ladder is DE CASTELJAU's
  // construction, drawn here every frame (green rungs, an amber rung, the
  // mote). the handles P1 and P2 are never visited; they only pull. k runs
  // at a constant rate, so the mote hurries wherever the handles are far apart.
  const P = [D.p0, D.p1, D.p2, D.p3].map(p => [p[0] * W, p[1] * H]);
  let grab = -1, grabT = 9;
  function L(a, b, k) { return [lerp(a[0], b[0], k), lerp(a[1], b[1], k)]; }
  function ladder(k) {
    const q0 = L(P[0], P[1], k), q1 = L(P[1], P[2], k), q2 = L(P[2], P[3], k);   // one lerp deep
    const r0 = L(q0, q1, k), r1 = L(q1, q2, k);                                    // two deep
    return { q: [q0, q1, q2], r: [r0, r1], b: L(r0, r1, k) };                     // three deep: the curve
  }
  return {
    drag: true,
    press(x, y) {
      if (grabT > 0.3) {                                 // a fresh grab takes the nearest handle...
        grab = 0;
        for (let i = 1; i < 4; i++)
          if (len(P[i][0] - x, P[i][1] - y) < len(P[grab][0] - x, P[grab][1] - y)) grab = i;
      }                                                  // ...a continuing drag keeps the same one
      P[grab][0] = clamp(x, 6, W - 6); P[grab][1] = clamp(y, 6, H - 22);
      grabT = 0;
    },
    frame(dt, t) {
      stage();
      grabT += dt;
      const ph = (t / D.period) % 2, k = ph < 1 ? ph : 2 - ph;   // there and back again
      ctx.strokeStyle = "rgba(232,229,244,0.16)";        // the whole curve, previewed
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let i = 0; i <= 48; i++) {
        const b = ladder(i / 48).b;
        if (i === 0) ctx.moveTo(b[0], b[1]); else ctx.lineTo(b[0], b[1]);
      }
      ctx.stroke();
      line(P[0][0], P[0][1], P[1][0], P[1][1], "rgba(201,196,228,0.5)");   // the handles
      line(P[2][0], P[2][1], P[3][0], P[3][1], "rgba(201,196,228,0.5)");
      line(P[1][0], P[1][1], P[2][0], P[2][1], "rgba(201,196,228,0.18)");
      const s = ladder(k);
      line(s.q[0][0], s.q[0][1], s.q[1][0], s.q[1][1], "rgba(155,226,138,0.6)");   // rung one
      line(s.q[1][0], s.q[1][1], s.q[2][0], s.q[2][1], "rgba(155,226,138,0.6)");
      line(s.r[0][0], s.r[0][1], s.r[1][0], s.r[1][1], "rgba(245,193,105,0.75)");  // rung two
      for (const q of s.q) dot(q[0], q[1], 2.2, GOOD);
      for (const r of s.r) dot(r[0], r[1], 2.6, TARGET);
      for (let i = 0; i < 4; i++) {
        const hot = grab === i && grabT < 0.5;
        if (i === 0 || i === 3) dot(P[i][0], P[i][1], 3.5, hot ? TARGET : BONE);
        else ring(P[i][0], P[i][1], 4.5, hot ? TARGET : BONE, 1.5);
        label("P" + i, P[i][0] + 7, P[i][1] + 4, "rgba(201,196,228,0.7)");
      }
      const dir = ph < 1 ? 1 : -1;                       // heading = the last rung's direction
      mote(s.b[0], s.b[1], Math.atan2((s.r[1][1] - s.r[0][1]) * dir, (s.r[1][0] - s.r[0][0]) * dir));
      label("k = " + k.toFixed(2), W / 2, 14, null, "center");
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Bezier", "Barrelroll", "the handles swapped to the far corners so the curve crosses itself — a loop-the-loop, flown at a faster clip", { p1: [0.98, 0.15], p2: [0.02, 0.15], period: 2.2 });

def("P", "Path", "paths", "a catmull-rom spline walked by arc length; the ghost walks by parameter and bunches — press to add or move a waypoint", function (u) {
  var D = { pts: [[0.15, 0.5], [0.32, 0.2], [0.62, 0.24], [0.86, 0.5], [0.66, 0.8], [0.36, 0.76]],   // waypoints, a closed loop
            tension: 0.5,                                  // 0.5 is Catmull-Rom; more overshoots, less cuts corners
            speed: 0.35,                                   // fraction of W per second
            samples: 16, grab: 0.06, maxPts: 10,
            label: "arc length: s → (segment, k) via a table" };
  const { ctx, W, H, stage, dot, ring, arrow, mote, label, lerp, len, MOVER, TARGET, BONE, DIM } = u;
  // a SPLINE is a curve that visits its waypoints. this one is a cardinal
  // spline: each waypoint gets a tangent  m = tension · (next − previous)
  // and the piece between two waypoints is a HERMITE cubic built from the
  // two points and two tangents (tension 0.5 is Catmull-Rom). the catch:
  // the cubic's parameter k is not distance — equal steps of k bunch up on
  // short pieces (the faint ticks, the ghost). so measure the curve once
  // into a table of distance → (piece, k), and walk by ARC LENGTH.
  let pts = D.pts.map(p => [p[0] * W, p[1] * H]);
  let table = [], total = 1, s = 0, up = 0;
  function at(i, k) {                                    // the Hermite cubic on piece i
    const n = pts.length;
    const p0 = pts[(i - 1 + n) % n], p1 = pts[i % n], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
    const m1x = D.tension * (p2[0] - p0[0]), m1y = D.tension * (p2[1] - p0[1]);
    const m2x = D.tension * (p3[0] - p1[0]), m2y = D.tension * (p3[1] - p1[1]);
    const k2 = k * k, k3 = k2 * k;
    const h00 = 2 * k3 - 3 * k2 + 1, h10 = k3 - 2 * k2 + k, h01 = -2 * k3 + 3 * k2, h11 = k3 - k2;
    return [h00 * p1[0] + h10 * m1x + h01 * p2[0] + h11 * m2x,
            h00 * p1[1] + h10 * m1y + h01 * p2[1] + h11 * m2y];
  }
  function measure() {                                   // the arc-length table
    table = []; total = 0;
    let prev = at(0, 0);
    for (let i = 0; i < pts.length; i++)
      for (let j = 1; j <= D.samples; j++) {
        const p = at(i, j / D.samples);
        total += len(p[0] - prev[0], p[1] - prev[1]);
        table.push({ s: total, i: i, k: j / D.samples, x: p[0], y: p[1] });
        prev = p;
      }
    if (total < 1) total = 1;
  }
  function lookup(d) {                                   // distance → (piece, k) → point
    d = ((d % total) + total) % total;
    let lo = 0;
    while (lo < table.length - 1 && table[lo].s < d) lo++;
    const a = lo > 0 ? table[lo - 1] : { s: 0, i: 0, k: 0 };
    const b = table[lo];
    const f = (d - a.s) / Math.max(1e-6, b.s - a.s);
    return at(b.i, lerp(a.i === b.i ? a.k : 0, b.k, f));
  }
  measure();
  return {
    press(x, y) {
      let near = -1;
      for (let i = 0; i < pts.length; i++)
        if (len(pts[i][0] - x, pts[i][1] - y) < D.grab * W) near = i;
      if (near >= 0) { pts[near][0] = x; pts[near][1] = y; }   // move a waypoint...
      else if (pts.length >= D.maxPts) pts = D.pts.map(p => [p[0] * W, p[1] * H]);
      else {                                             // ...or add one on the nearest piece
        let bi = 0, bc = Infinity;
        for (let i = 0; i < pts.length; i++) {
          const a = pts[i], b = pts[(i + 1) % pts.length];
          const cost = len(a[0] - x, a[1] - y) + len(b[0] - x, b[1] - y) - len(b[0] - a[0], b[1] - a[1]);
          if (cost < bc) { bc = cost; bi = i; }
        }
        pts.splice(bi + 1, 0, [x, y]);
      }
      measure();
    },
    frame(dt, t) {
      stage();
      const n = pts.length;
      s = (s + D.speed * W * dt) % total;                // the bookmark: a distance
      up = (up + dt * D.speed * W / (total / n)) % n;    // the ghost's bookmark: a parameter
      ctx.strokeStyle = "rgba(232,229,244,0.2)";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(table[table.length - 1].x, table[table.length - 1].y);
      for (const e of table) ctx.lineTo(e.x, e.y);
      ctx.stroke();
      for (let i = 0; i < n; i++) {                      // equal-parameter ticks: they bunch
        for (let j = 1; j < 4; j++) { const p = at(i, j / 4); dot(p[0], p[1], 1.5, DIM); }
        const p0 = pts[(i - 1 + n) % n], p2 = pts[(i + 1) % n];   // the tangent, made visible
        arrow(pts[i][0], pts[i][1], pts[i][0] + D.tension * (p2[0] - p0[0]) * 0.3,
              pts[i][1] + D.tension * (p2[1] - p0[1]) * 0.3, "rgba(201,196,228,0.35)");
        ring(pts[i][0], pts[i][1], 4, BONE, 1.5);
      }
      const gp = at(Math.floor(up) % n, up - Math.floor(up));
      dot(gp[0], gp[1], 6, "rgba(232,229,244,0.2)");
      const p = lookup(s), q = lookup(s + 3);
      mote(p[0], p[1], Math.atan2(q[1] - p[1], q[0] - p[0]));
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Path", "Pretzel", "tension doubled and the walk faster — the spline overshoots every waypoint into loops; arc length keeps the pace honest", { tension: 1.1, speed: 0.5 });

def("K", "Kart", "paths", "rubber-band ai: speed = base + gain · gap behind the leader, nobody escapes (Path + Arrive) — press to shove the nearest kart", function (u) {
  var D = { n: 4, base: 0.3, gain: 0.4, leaderDrag: 0.9, spread: 0.12,   // speeds in W per second; the gap is a fraction of a lap
            shove: 0.5, wobble: 0.05, rx: 0.36, ry: 0.28, lanes: 7, seed: 11,   // lanes: each kart's own sideways offset, px
            label: "v = base + gain · (gap behind the leader)" };
  const { ctx, W, H, TAU, stage, dot, line, label, noise, rng, len, clamp, smooth, MOVER, TARGET, GOOD, MAGIC } = u;
  // the racing-game secret nobody admits to: RUBBER-BANDING. every kart's
  // wanted speed is base + gain · (how far behind the leader it is), and
  // the leader alone is throttled — so a straggler is quietly faster and a
  // runaway quietly slower, and the pack stays a pack. each kart also has a
  // personal speed (some are just faster), which the band overrules. the
  // track is a bookmark: one distance s along the lap, turned into (x, y).
  const cx = W / 2, cy = (H - 18) / 2 + 2;
  const a = D.rx * W, b = D.ry * (H - 18), r = Math.min(a, b), hs = Math.max(0, a - b);
  const L = 4 * hs + TAU * r;                            // lap length: two straights, two half-circles
  function place(s) {                                    // distance along the lap → x, y, heading
    s = ((s % L) + L) % L;
    if (s < 2 * hs) return [cx - hs + s, cy - r, 0];
    s -= 2 * hs;
    if (s < Math.PI * r) { const an = -Math.PI / 2 + s / r; return [cx + hs + Math.cos(an) * r, cy + Math.sin(an) * r, an + Math.PI / 2]; }
    s -= Math.PI * r;
    if (s < 2 * hs) return [cx + hs - s, cy + r, Math.PI];
    s -= 2 * hs;
    const an = Math.PI / 2 + s / r;
    return [cx - hs + Math.cos(an) * r, cy + Math.sin(an) * r, an + Math.PI / 2];
  }
  const R = rng(D.seed), COLS = [MOVER, GOOD, TARGET, MAGIC];
  const karts = [];
  for (let i = 0; i < D.n; i++)
    karts.push({ s: -i * L * 0.06, v: D.base * W, pers: (R() * 2 - 1) * D.spread,
                 lane: (R() * 2 - 1) * D.lanes, c: COLS[i % COLS.length] });
  function spot(k) {                                     // a kart's place, nudged into its own lane
    const p = place(k.s);
    return [p[0] + Math.cos(p[2] + Math.PI / 2) * k.lane, p[1] + Math.sin(p[2] + Math.PI / 2) * k.lane, p[2]];
  }
  return {
    press(x, y) {
      let best = 0, bd = Infinity;
      for (let i = 0; i < karts.length; i++) {
        const p = spot(karts[i]), d = len(p[0] - x, p[1] - y);
        if (d < bd) { bd = d; best = i; }
      }
      karts[best].v += D.shove * W;                      // an impulse — Knock's idea, on a rail
    },
    frame(dt, t) {
      stage();
      let lead = 0, last = 0;
      for (let i = 1; i < karts.length; i++) {
        if (karts[i].s > karts[lead].s) lead = i;
        if (karts[i].s < karts[last].s) last = i;
      }
      karts.forEach((k, i) => {
        const gap = (karts[lead].s - k.s) / L;           // laps behind the leader (0 for the leader)
        let want = D.base * W * (1 + k.pers) + D.gain * W * gap;   // ← the band
        if (i === lead) want *= D.leaderDrag;            // the leader is throttled
        want += noise(t * 0.8 + i * 7.3) * D.wobble * W; // a little human wobble
        k.v += (want - k.v) * smooth(2.5, dt);           // Arrive's manners: ease to the wanted speed
        k.v = clamp(k.v, 0, 2 * W);
        k.s += k.v * dt;
      });
      if (karts[last].s > L) for (const k of karts) k.s -= L;   // keep the bookmarks small
      ctx.strokeStyle = "rgba(201,196,228,0.35)";        // the track, two kerbs
      ctx.lineWidth = 1;
      for (const off of [-11, 11]) {
        ctx.beginPath();
        for (let j = 0; j <= 72; j++) {
          const p = place(j / 72 * L);
          const x = p[0] + Math.cos(p[2] + Math.PI / 2) * off, y = p[1] + Math.sin(p[2] + Math.PI / 2) * off;
          if (j === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
      }
      const sl = place(0);
      line(sl[0], sl[1] - 11, sl[0], sl[1] + 11, "rgba(232,229,244,0.5)", 2);   // the start line
      const pl = spot(karts[lead]), pt = spot(karts[last]);
      line(pl[0], pl[1], pt[0], pt[1], "rgba(245,138,138,0.3)");   // the band itself, leader to straggler
      for (const k of karts) {
        const p = spot(k);
        ctx.save();
        ctx.translate(p[0], p[1]);
        ctx.rotate(p[2]);
        ctx.fillStyle = k.c;
        ctx.fillRect(-7, -4, 14, 8);
        ctx.fillStyle = "#131020";
        ctx.fillRect(2, -2.5, 3, 5);                     // a windscreen: which way is forward
        ctx.restore();
      }
      dot(pl[0], pl[1] - 11, 2.5, TARGET);               // the leader's crown
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Kart", "Kingpin", "the band cut (gain 0, no leader throttle) and personal speeds spread wider — the quick kart laps the field, the pack strings out", { gain: 0, leaderDrag: 1, spread: 0.25 });

def("F", "Frog", "paths", "hops are fixed-clock grid steps; a log is a moving frame the frog inherits (Jump + Platform + Nest) — press to hop toward your click", function (u) {
  var D = { cols: 9, rows: 5, hopTime: 0.2, hopLift: 0.6,           // rows: a far bank, water lanes, a home bank
            logLen: 2.2, logGap: 2.4, speeds: [0.9, -1.3, 1.6],     // logs in cells; lane speeds in cells per second, top lane first
            autoWait: 0.8, seed: 5,
            label: "on a log: x += log.v · dt (a moving frame)" };
  const { W, H, stage, rect, ring, mote, label, rng, ease, lerp, clamp, MOVER } = u;
  // Frogger is two lessons in a trench coat. a HOP is a discrete step: pick
  // the cell, fly a fixed-duration arc (sin(k·π) lift, Jump's shape), land
  // exactly — no physics in between. a LOG is a moving COORDINATE FRAME:
  // while the frog sits on it, x += log.v · dt every frame, the same
  // inheritance as a moving platform (and Nest's parent + local). mid-hop
  // it belongs to no frame at all — which is why the landing has to be timed.
  const cols = D.cols, rows = D.rows, cw = W / cols, ch = (H - 18) / rows;
  const R = rng(D.seed), lanes = [];                     // each water lane: a schedule of logs
  for (let i = 0; i < rows - 2; i++) {
    const period = (D.logLen + D.logGap) * cw;
    const n = Math.ceil((W + D.logLen * cw) / period) + 1;
    lanes.push({ row: i + 1, v: D.speeds[i % D.speeds.length] * cw, period: period, n: n, phase: R() * period * n });
  }
  function logLeft(ln, j, t) {                           // log j of a lane at time t — a pure formula
    const wrap = ln.n * ln.period;
    let lx = (ln.phase + ln.v * t + j * ln.period) % wrap;
    if (lx < 0) lx += wrap;
    return lx - D.logLen * cw;
  }
  function logUnder(ln, x, t, margin) {                  // is x over a log at time t? → its velocity
    const L = D.logLen * cw;
    for (let j = 0; j < ln.n; j++) {
      const lx = logLeft(ln, j, t);
      if (x >= lx + margin && x <= lx + L - margin) return ln.v;
    }
    return null;
  }
  const cy = (r) => (r + 0.5) * ch;
  let fx = W / 2, row = rows - 1, hop = null, dead = 0, idle = 0, home = 0, crossed = 0;
  function startHop(tx, tr) {
    hop = { x0: fx, r0: row, x1: clamp(tx, cw * 0.5, W - cw * 0.5), r1: clamp(tr, 0, rows - 1), k: 0 };
    idle = 0;
  }
  function respawn() { fx = W / 2; row = rows - 1; hop = null; idle = 0; }
  return {
    press(x, y) {
      if (hop || dead > 0) return;                       // no steering mid-air
      const dx = x - fx, dy = y - cy(row);
      if (Math.abs(dx) > Math.abs(dy)) startHop(fx + (dx > 0 ? cw : -cw), row);
      else startHop(fx, row + (dy > 0 ? 1 : -1));
    },
    frame(dt, t) {
      stage();
      for (let r = 0; r < rows; r++)
        rect(0, r * ch, W, ch, (r > 0 && r < rows - 1) ? "rgba(138,217,245,0.06)" : "rgba(155,226,138,0.1)");
      for (const ln of lanes)
        for (let j = 0; j < ln.n; j++)
          rect(logLeft(ln, j, t), cy(ln.row) - ch * 0.28, D.logLen * cw, ch * 0.56, "rgba(201,196,228,0.5)");
      const water = row > 0 && row < rows - 1;
      if (dead > 0) {
        dead -= dt;
        ring(fx, cy(row), (0.7 - dead) * cw * 1.5, "rgba(245,138,138," + clamp(dead, 0, 0.7) + ")", 2);   // the splash
        if (dead <= 0) respawn();
      } else if (hop) {
        hop.k += dt / D.hopTime;
        if (hop.k >= 1) {                                // land exactly, then ask the water
          fx = hop.x1; row = hop.r1; hop = null;
          if (row > 0 && row < rows - 1 && logUnder(lanes[row - 1], fx, t, -cw * 0.15) === null) dead = 0.7;
          else if (row === 0) { crossed++; home = 0.9; }
        }
      } else {
        if (water) {
          const v = logUnder(lanes[row - 1], fx, t, -cw * 0.15);
          if (v === null) dead = 0.7;
          else fx += v * dt;                             // ← the moving frame
          if (fx < cw * 0.3 || fx > W - cw * 0.3) dead = 0.7;   // swept off the edge
        }
        if (home > 0) { home -= dt; if (home <= 0) respawn(); }
        else {
          idle += dt;
          if (idle > D.autoWait && row > 0) {            // the little brain: hop up when a log will be there
            const up = row - 1;
            if (up === 0 || logUnder(lanes[up - 1], fx, t + D.hopTime, cw * 0.25) !== null) startHop(fx, up);
            else idle = D.autoWait - 0.2;                // not yet — look again soon
          }
        }
      }
      if (dead <= 0) {
        let x = fx, y = cy(row), ang = -Math.PI / 2;
        if (hop) {
          const k = ease(hop.k);
          x = lerp(hop.x0, hop.x1, k);
          y = lerp(cy(hop.r0), cy(hop.r1), k) - Math.sin(clamp(hop.k, 0, 1) * Math.PI) * D.hopLift * ch;
          ang = Math.atan2(hop.r1 - hop.r0, hop.x1 - hop.x0);
        }
        mote(x, y, ang, MOVER, Math.min(cw, ch) * 0.24);
      }
      label("crossed ×" + crossed, W - 4, 11, null, "right");
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Frog", "Frenzy", "logs twice as fast and shorter, hops quicker — frogger on its hardest wave", { speeds: [1.8, -2.4, 3.0], logLen: 1.4, hopTime: 0.14 });

def("G", "Grid", "paths", "pac-man lanes: move_toward the next centre, turn only there, buffer the wish early (Lerp) — press to set the desired direction", function (u) {
  var D = { map: ["###########",
                  "#.........#",
                  "#.###.###.#",
                  "#.#.....#.#",
                  "#.#.###.#.#",
                  "#.........#",
                  "###########"],
            speed: 3.4,                                    // cells per second
            bufferTime: 1.2,                               // a buffered turn is forgotten after this long
            autoWait: 2.5, pelletR: 0.09,
            label: "move_toward the next centre · turn at centres" };
  const { W, H, stage, rect, dot, arrow, mote, label, rand, MOVER, TARGET, DIM } = u;
  // Pac-Man never leaves the LANE centres. the body is a bookmark — the
  // cell it left, the cell it is heading to, and k between them — and every
  // frame it move_towards the next centre (Lerp's constant-speed cousin).
  // turning is only allowed AT a centre, so the input is BUFFERED: press
  // early and the wish waits (for a while) until a lane opens that way. the
  // amber arrow is the wish, the faint one the way it is going. reversing
  // is the one exception: allowed anywhere, at once.
  const rows = D.map.length, cols = D.map[0].length, cw = W / cols, ch = (H - 18) / rows;
  const open = (c, r) => r >= 0 && r < rows && c >= 0 && c < cols && D.map[r][c] !== "#";
  let from = [1, 1], to = null, k = 0, dir = [1, 0], want = null, wantAge = 0, idle = D.autoWait + 1;
  const pellets = [];
  let left = 0;
  function refill() { left = 0; for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) { pellets[r * cols + c] = open(c, r); if (open(c, r)) left++; } }
  refill();
  function eat(c) { const i = c[1] * cols + c[0]; if (pellets[i]) { pellets[i] = false; if (--left === 0) refill(); } }
  function decide(c) {                                   // at a centre: the wish first, then straight on, then (if bored) a whim
    if (want && open(c[0] + want[0], c[1] + want[1])) { dir = want; want = null; }
    else if (idle > D.autoWait) {
      const o = [];
      for (const d of [[1, 0], [-1, 0], [0, 1], [0, -1]])
        if (open(c[0] + d[0], c[1] + d[1]) && !(d[0] === -dir[0] && d[1] === -dir[1])) o.push(d);
      dir = o.length ? o[Math.floor(rand(0, o.length))] : [-dir[0], -dir[1]];
    }
    to = open(c[0] + dir[0], c[1] + dir[1]) ? [c[0] + dir[0], c[1] + dir[1]] : null;   // a wall ahead: stop
    k = 0;
  }
  const cx = (c) => (c[0] + 0.5) * cw, cy = (c) => (c[1] + 0.5) * ch;
  return {
    press(x, y) {
      const mx = to ? cx(from) + (cx(to) - cx(from)) * k : cx(from);
      const my = to ? cy(from) + (cy(to) - cy(from)) * k : cy(from);
      const dx = x - mx, dy = y - my;
      want = Math.abs(dx) > Math.abs(dy) ? [dx > 0 ? 1 : -1, 0] : [0, dy > 0 ? 1 : -1];   // the wish, relative to the mote
      wantAge = 0; idle = 0;
    },
    frame(dt, t) {
      stage();
      wantAge += dt; idle += dt;
      if (want && wantAge > D.bufferTime) want = null;   // a stale wish is dropped
      if (to === null) { if (want || idle > D.autoWait) decide(from); }
      else {
        if (want && want[0] === -dir[0] && want[1] === -dir[1]) {   // reverse: anywhere, at once
          const tmp = from; from = to; to = tmp; k = 1 - k; dir = want; want = null;
        }
        let step = D.speed * dt;                         // move_toward, in cells
        while (to && step > 0) {
          if (step < 1 - k) { k += step; step = 0; }
          else { step -= 1 - k; from = to; eat(from); decide(from); }
        }
      }
      for (let r = 0; r < rows; r++)
        for (let c = 0; c < cols; c++) {
          if (!open(c, r)) rect(c * cw + 1, r * ch + 1, cw - 2, ch - 2, "rgba(201,196,228,0.28)");
          else if (pellets[r * cols + c]) dot((c + 0.5) * cw, (r + 0.5) * ch, D.pelletR * cw, "rgba(245,193,105,0.7)");
        }
      const mx = to ? cx(from) + (cx(to) - cx(from)) * k : cx(from);
      const my = to ? cy(from) + (cy(to) - cy(from)) * k : cy(from);
      arrow(mx, my, mx + dir[0] * cw * 0.8, my + dir[1] * ch * 0.8, DIM);
      if (want) arrow(mx, my, mx + want[0] * cw * 0.8, my + want[1] * ch * 0.8, TARGET);   // the buffered wish
      mote(mx, my, Math.atan2(dir[1], dir[0]), MOVER, Math.min(cw, ch) * 0.3);
      label("pellets " + left + (want ? " · wish buffered" : ""), W - 4, 11, null, "right");
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Grid", "Gauntlet", "a different maze with long open corridors and a faster mote — more intersections, more buffered turns", {
  map: ["###########",
        "#....#....#",
        "#.##.#.##.#",
        "#.........#",
        "#.##.#.##.#",
        "#....#....#",
        "###########"],
  speed: 5.5 });

def("P", "Platform", "paths", "a sine platform, a waypoint platform, a rider that inherits whichever it stands on (Hover + Zigzag + Jump) — press to make it jump", function (u) {
  var D = { g: 2.2, jumpH: 0.3,                                                    // gravity in H per s², the apex as a fraction of H
            platW: 0.22, sineX: 0.28, sineY: 0.66, sineAmp: 0.14, sinePeriod: 3.4,   // platform A: a sine sway
            wp: [[0.62, 0.66], [0.88, 0.52], [0.66, 0.44]], legSpeed: 0.3, legPause: 0.5,   // platform B: waypoints, eased legs
            maxKick: 0.9, autoWait: 1.4,                                             // the kick's limit (W per s), seconds before it jumps by itself
            label: "inherit v · solve T: v₀T + ½gT² = Δy" };
  const { W, H, TAU, stage, ground, rect, ring, line, dot, arrow, mote, label, ease, len, clamp, MOVER, TARGET, GOOD, HOT } = u;
  // two platforms, two schedules: A rides a sine (Hover, turned sideways),
  // B walks waypoints with eased legs and corner rests (Zigzag). the rider's
  // rule is INHERITANCE: standing on a platform it moves WITH it — its
  // velocity is the platform's, measured the honest way (this frame's
  // position minus last frame's). a jump keeps that velocity and adds a
  // KICK, sized by solving the flight time T from  v₀T + ½gT² = Δy  (Jump's
  // maths run backward) and asking where the other platform will be by then.
  const G = D.g * H, V0 = -Math.sqrt(2 * G * D.jumpH * H), PW = D.platW * W;
  const A = { x: D.sineX * W, y: D.sineY * H, vx: 0, px: 0, py: 0 };
  const wp = D.wp.map(p => [p[0] * W, p[1] * H]);
  const B = { x: wp[0][0], y: wp[0][1], vx: 0, px: 0, py: 0, seg: 0, dir: 1, k: 0, pause: 0 };
  const plats = [A, B];
  const rd = { x: A.x, y: A.y, vx: 0, vy: 0, on: 0, off: 0, stand: 0 };
  let flash = 0;
  function predictX(i, T, t) {                           // where platform i will be, T seconds from now
    if (i === 0) return D.sineX * W + Math.sin((t + T) * TAU / D.sinePeriod) * D.sineAmp * W;
    return B.x + B.vx * T;                               // B: assume it keeps its velocity
  }
  function plan(t) {                                     // the jump maths, from the rider's feet
    const tgt = 1 - rd.on, dy = plats[tgt].y - rd.y;
    const disc = V0 * V0 + 2 * G * dy;                   // v₀T + ½gT² = Δy, solved for T
    const T = disc >= 0 ? (-V0 + Math.sqrt(disc)) / G : -2 * V0 / G;   // no root: it cannot reach that height — jump anyway
    const pv = plats[rd.on].vx;
    const kick = clamp((predictX(tgt, T, t) - rd.x) / T - pv, -D.maxKick * W, D.maxKick * W);
    return { T: T, vx: pv + kick, pv: pv, kick: kick };
  }
  function jump(t) { const p = plan(t); rd.vx = p.vx; rd.vy = V0; rd.on = -1; rd.stand = 0; }
  return {
    press() { if (rd.on >= 0) jump(rd.tNow || 0); },
    frame(dt, t) {
      stage(); ground();
      dt = Math.max(dt, 1e-4); rd.tNow = t;
      A.px = A.x; A.py = A.y;                            // platform A: a sine, its velocity by difference
      A.x = D.sineX * W + Math.sin(t * TAU / D.sinePeriod) * D.sineAmp * W;
      A.vx = (A.x - A.px) / dt;
      B.px = B.x; B.py = B.y;                            // platform B: eased legs between waypoints
      const a = wp[B.seg], b = wp[B.seg + 1];
      if (B.pause > 0) B.pause -= dt;
      else {
        B.k += dt * D.legSpeed * W / Math.max(1, len(b[0] - a[0], b[1] - a[1]));
        if (B.k >= 1) {
          B.k = 0; B.pause = D.legPause; B.seg += B.dir;
          if (B.seg > wp.length - 2) { B.seg = wp.length - 2; B.dir = -1; }
          if (B.seg < 0) { B.seg = 0; B.dir = 1; }
        }
      }
      const a2 = wp[B.seg], b2 = wp[B.seg + 1], e = B.dir > 0 ? ease(B.k) : 1 - ease(B.k);
      B.x = a2[0] + (b2[0] - a2[0]) * e; B.y = a2[1] + (b2[1] - a2[1]) * e;
      B.vx = (B.x - B.px) / dt;
      const prevY = rd.y;
      if (rd.on >= 0) {                                  // standing: carried by the platform
        const p = plats[rd.on];
        rd.x = p.x + rd.off; rd.y = p.y; rd.vx = p.vx;
        rd.stand += dt;
        if (rd.stand > D.autoWait) jump(t);
      } else {                                           // airborne: plain ballistics
        rd.vy += G * dt; rd.x += rd.vx * dt; rd.y += rd.vy * dt;
        if (rd.vy > 0)
          for (let i = 0; i < 2; i++) {
            const p = plats[i];
            if (prevY <= p.py + 1 && rd.y >= p.y - 1 && Math.abs(rd.x - p.x) <= PW / 2) {
              rd.on = i; rd.off = rd.x - p.x; rd.y = p.y; rd.vy = 0; break;   // caught
            }
          }
        if (rd.y > H + 30 || rd.x < -40 || rd.x > W + 40) {   // missed: back to A
          rd.on = 0; rd.off = 0; rd.x = A.x; rd.y = A.y; rd.vy = 0; flash = 1;
        }
      }
      line(D.sineX * W - D.sineAmp * W, A.y + 3, D.sineX * W + D.sineAmp * W, A.y + 3, "rgba(232,229,244,0.12)");   // A's rail
      for (let i = 0; i + 1 < wp.length; i++) line(wp[i][0], wp[i][1] + 3, wp[i + 1][0], wp[i + 1][1] + 3, "rgba(232,229,244,0.12)");
      for (const p of wp) ring(p[0], p[1] + 3, 3, "rgba(201,196,228,0.4)");
      for (const p of plats) rect(p.x - PW / 2, p.y, PW, 5, "rgba(201,196,228,0.7)");
      if (rd.on >= 0) {                                  // the plan, previewed while it stands
        const p = plan(t);
        for (let i = 0; i <= 16; i++) {
          const tau = p.T * i / 16;
          dot(rd.x + p.vx * tau, rd.y + V0 * tau + 0.5 * G * tau * tau, 1.2, "rgba(232,229,244,0.28)");
        }
        arrow(rd.x, rd.y - 9, rd.x + p.pv * 0.35, rd.y - 9, GOOD);                     // inherited
        arrow(rd.x + p.pv * 0.35, rd.y - 9, rd.x + (p.pv + p.kick) * 0.35, rd.y - 9, HOT);   // the kick
      }
      flash = Math.max(0, flash - dt * 2);
      if (flash > 0) ring(rd.x, rd.y - 8, 12 + (1 - flash) * 20, "rgba(245,138,138," + flash * 0.7 + ")", 2);
      mote(rd.x, rd.y - 8, clamp(rd.vx * 0.002, -0.4, 0.4));
      ring(plats[1 - Math.max(0, rd.on)].x, plats[1 - Math.max(0, rd.on)].y + 2.5, 5, TARGET);
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Platform", "Parkour", "narrow platforms, a fast sway, a higher apex — the rider has to time its kicks, and every miss costs a respawn", { platW: 0.14, sinePeriod: 1.6, jumpH: 0.38 });

def("K", "Keyframe", "paths", "keyframes replay a pose list; the spring twin adapts when the target moves and the replay cannot — press to move the target", function (u) {
  var D = { keys: [[0, 0.2, 0.55], [0.8, 0.5, 0.25], [1.6, 0.8, 0.55], [2.4, 0.5, 0.82], [3.2, 0.2, 0.55]],   // time, x, y — the last key loops to the first
            easing: "smooth", tempo: 1,                    // smooth or linear between keys; playback speed
            omega: 8, zeta: 1, hold: 3,                    // the procedural twin's spring, and how long a press holds the target
            label: "lerp(keyᵢ, keyᵢ₊₁, ease(k))  vs  a spring" };
  const { ctx, W, H, stage, ring, line, mote, label, ease, lerp, len, clamp, MOVER, TARGET, BONE, HOT } = u;
  // KEYFRAME animation: an artist stores poses at fixed times, and the
  // player lerps between the two keys either side of the playhead — k is
  // how far between them, eased or linear. it replays perfectly and can do
  // nothing else. its twin is PROCEDURAL: a critically damped spring (Damp)
  // chasing the same target. move the target and the puppet keeps
  // performing its recording at empty air while the spring simply goes —
  // which is the whole reason this lexicon exists.
  const keys = D.keys, period = Math.max(0.1, keys[keys.length - 1][0]);
  let tx = keys[0][1] * W, ty = keys[0][2] * H, holdT = 0;
  const tw = { x: tx, y: ty, vx: 0, vy: 0 };
  function pose(ph) {                                    // the playhead → a pose
    let i = 0;
    while (i < keys.length - 2 && ph >= keys[i + 1][0]) i++;
    const a = keys[i], b = keys[i + 1];
    const k = clamp((ph - a[0]) / Math.max(1e-6, b[0] - a[0]), 0, 1);
    const e = D.easing === "linear" ? k : ease(k);
    return { x: lerp(a[1], b[1], e) * W, y: lerp(a[2], b[2], e) * H, i: i, k: k };
  }
  return {
    press(x, y) { tx = x; ty = y; holdT = D.hold; },
    frame(dt, t) {
      stage();
      const ph = (t * D.tempo) % period, p = pose(ph);
      if (holdT > 0) holdT -= dt;
      else { tx = p.x; ty = p.y; }                       // normally the target IS the recording
      const w = D.omega, z = D.zeta;                     // the twin: Damp's equation
      tw.vx += ((tx - tw.x) * w * w - 2 * z * w * tw.vx) * dt;
      tw.vy += ((ty - tw.y) * w * w - 2 * z * w * tw.vy) * dt;
      tw.x += tw.vx * dt; tw.y += tw.vy * dt;
      for (let i = 0; i + 1 < keys.length; i++)          // the recording, drawn
        line(keys[i][1] * W, keys[i][2] * H, keys[i + 1][1] * W, keys[i + 1][2] * H, "rgba(201,196,228,0.15)");
      for (let i = 0; i + 1 < keys.length; i++) {
        ring(keys[i][1] * W, keys[i][2] * H, 5, "rgba(201,196,228,0.35)");
        label(String(i), keys[i][1] * W + 7, keys[i][2] * H - 5, "rgba(201,196,228,0.5)");
      }
      const x0 = W * 0.1, x1 = W * 0.9, ty2 = H - 22;    // the timeline
      line(x0, ty2, x1, ty2, "rgba(201,196,228,0.4)");
      for (let i = 0; i < keys.length; i++) {
        const kx = x0 + (x1 - x0) * keys[i][0] / period;
        line(kx, ty2 - 4, kx, ty2 + 4, BONE);
      }
      const hx = x0 + (x1 - x0) * ph / period;
      line(hx, ty2 - 6, hx, ty2 + 6, TARGET, 2);
      label("key " + p.i + "→" + (p.i + 1) + "  k = " + p.k.toFixed(2), W / 2, 14, null, "center");
      if (len(p.x - tx, p.y - ty) > 8) {                 // the replay, missing its cue
        ctx.setLineDash([3, 4]);
        line(p.x, p.y, tx, ty, "rgba(245,138,138,0.6)");
        ctx.setLineDash([]);
      }
      ring(tx, ty, 9, TARGET, 1.5);
      const nk = keys[Math.min(p.i + 1, keys.length - 1)];
      mote(p.x, p.y, Math.atan2(nk[2] * H - p.y, nk[1] * W - p.x), BONE, 7);   // the puppet
      mote(tw.x, tw.y, Math.atan2(tw.vy, tw.vx), MOVER, 7);                   // the twin
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Keyframe", "Kinetoscope", "linear easing at double tempo, and a bouncy twin — the replay snaps between poses like an old film loop", { easing: "linear", tempo: 2, zeta: 0.35 });

def("E", "Elevator", "paths", "a trapezoidal velocity profile: accelerate, cruise, brake to land exactly on the floor — press to call it to the nearest floor", function (u) {
  var D = { floors: 4, accel: 1.2, vmax: 0.5,     // fractions of H per second² and per second
            dwell: 1.2, schedule: [2, 0, 3, 1],  // the floors it visits on its own, in order
            label: "accel a · cruise vmax · brake a · exact stop" };
  const { ctx, W, H, GY, stage, ground, rect, ring, dot, line, mote, label, clamp, TARGET, GOOD, DIM } = u;
  // a lift is a MOTION PROFILE: accelerate at a, cruise at vmax, brake at a
  // — a trapezoid on the velocity graph — and the whole trip is a formula
  // of the time since departure, so it stops on the floor to the pixel. a
  // short trip never reaches vmax: the trapezoid becomes a triangle, peak
  // v = √(a·d). the graph beside the shaft is the profile drawn against
  // height: v rises as √(2·a·s) out of rest and falls the same way into the
  // stop. cameras, doors, and CNC tables all move exactly like this.
  const top = H * 0.12, bot = GY, n = Math.max(2, Math.floor(D.floors));
  const fy = (i) => bot - i * (bot - top) / (n - 1);
  const a = D.accel * H, vmax = D.vmax * H;
  const sx = W * 0.28, sw = W * 0.16, carH = H * 0.1;     // the shaft
  const gx = W * 0.6, gw = W * 0.3;                      // the graph
  let floor = 0, y = fy(0), trip = null, last = null, dwell = D.dwell, si = 0, call = -1;
  function profile(d) {                                  // the plan for a trip of distance d
    let t1 = vmax / a, vp = vmax;
    if (a * t1 * t1 > d) { vp = Math.sqrt(a * d); t1 = vp / a; }   // too short for vmax: a triangle
    const tc = vp > 0 ? (d - a * t1 * t1) / vp : 0;      // the cruise
    return { d: d, t1: t1, tc: tc, vp: vp, total: 2 * t1 + tc };
  }
  function sAt(p, tau) {                                 // distance covered after tau seconds
    tau = clamp(tau, 0, p.total);
    if (tau < p.t1) return 0.5 * a * tau * tau;
    if (tau < p.t1 + p.tc) return 0.5 * a * p.t1 * p.t1 + p.vp * (tau - p.t1);
    const r = p.total - tau;
    return p.d - 0.5 * a * r * r;
  }
  function vAt(p, tau) {
    tau = clamp(tau, 0, p.total);
    if (tau < p.t1) return a * tau;
    if (tau < p.t1 + p.tc) return p.vp;
    return a * (p.total - tau);
  }
  function vAtS(p, s) {                                  // the same profile, against distance
    return Math.min(Math.sqrt(2 * a * Math.max(0, s)), p.vp, Math.sqrt(2 * a * Math.max(0, p.d - s)));
  }
  function go(f) {
    f = clamp(Math.round(f), 0, n - 1);
    if (f === floor) return;
    trip = { to: f, y0: fy(floor), sign: fy(f) < fy(floor) ? -1 : 1, p: profile(Math.abs(fy(f) - fy(floor))), tau: 0 };
    floor = f;
  }
  return {
    press(x, yy) {
      const f = clamp(Math.round((bot - yy) / (bot - top) * (n - 1)), 0, n - 1);
      if (trip) call = f;                                // moving: remember the call
      else go(f);                                        // idle: leave now
    },
    frame(dt, t) {
      stage(); ground();
      if (trip) {
        trip.tau += dt;
        y = trip.y0 + trip.sign * sAt(trip.p, trip.tau);
        if (trip.tau >= trip.p.total) { y = fy(trip.to); last = trip; trip = null; dwell = D.dwell; }   // exact
      } else {
        dwell -= dt;
        if (dwell <= 0) {
          const f = call >= 0 ? call : D.schedule[si++ % D.schedule.length];
          call = -1;
          if (clamp(Math.round(f), 0, n - 1) === floor) dwell = 0.3; else go(f);
        }
      }
      rect(sx, top - 12, sw, bot - top + 12, "rgba(150,145,190,0.08)");
      for (let i = 0; i < n; i++) {
        line(sx - 8, fy(i), sx + sw + 8, fy(i), DIM);
        label(String(i), sx - 16, fy(i) + 4, "rgba(201,196,228,0.6)");
      }
      line(sx + sw / 2, top - 12, sx + sw / 2, y - carH, DIM);      // the cable
      rect(sx + 3, y - carH, sw - 6, carH, "rgba(201,196,228,0.7)");
      mote(sx + sw / 2, y - carH / 2, 0, null, 5);
      if (!trip) ring(sx + sw / 2, y - carH / 2, carH * 0.6, GOOD);   // doors open
      if (call >= 0) ring(sx + sw + 8, fy(call), 4, TARGET, 1.5);   // a call waiting
      line(gx, top, gx, bot, DIM);                       // the graph: v against height
      label("v", gx + 3, top - 4, null);
      label("vmax", gx + gw, top - 4, null, "right");
      const pr = trip || last;
      if (pr) {
        ctx.strokeStyle = trip ? "rgba(245,193,105,0.7)" : "rgba(245,193,105,0.25)";
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        for (let j = 0; j <= 40; j++) {
          const s = pr.p.d * j / 40;
          const px = gx + vAtS(pr.p, s) / vmax * gw, py = pr.y0 + pr.sign * s;
          if (j === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        }
        ctx.stroke();
        ctx.lineWidth = 1;
      }
      if (trip) dot(gx + vAt(trip.p, trip.tau) / vmax * gw, y, 3.5, TARGET);
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Elevator", "Express", "vmax and a both far higher — the trapezoid sharpens into a spike and the car whooshes between floors", { vmax: 1.3, accel: 3.2 });

def("J", "Juggle", "paths", "a cascade: v₀ = √(2gh) and a beat that interleaves the throws, every ball a formula of t (Jump + Orbit) — press to set the height", function (u) {
  var D = { balls: 3, height: 0.42, g: 2.4, dwell: 1.0,   // apex as a fraction of H, gravity in H per s², dwell in beats
            hy: 0.7, handGap: 0.22, scoop: 0.06,          // the hands: height, half the distance between them, the scoop ellipse
            label: "v₀ = √(2gh) · beat = flight ÷ (n − dwell)" };
  const { ctx, W, H, stage, dot, ring, label, lerp, clamp, smooth, MOVER, GOOD, TARGET, MAGIC, HOT, BONE, DIM } = u;
  // a CASCADE is a timetable. every throw is Jump's parabola — v₀ = √(2gh),
  // in the air for T = 2v₀/g — and the hands alternate on a BEAT: with n
  // balls each ball flies for (n − dwell) beats, rests in the catching hand
  // for dwell beats, and is thrown again exactly n beats after its last
  // throw. that arithmetic fixes the beat at T ÷ (n − dwell), and from
  // there every ball and both hands are pure functions of the beat count —
  // no state but a clock (Orbit's lesson, worn by a juggler).
  const n = Math.max(1, Math.floor(D.balls)) | 1;        // odd counts cross between hands — force odd
  const dw = clamp(D.dwell, 0.2, Math.min(1.8, n - 0.5));
  const cx = W / 2, hyP = D.hy * H, hg = D.handGap * W, ex = D.scoop * W, ey = D.scoop * H * 0.7;
  const COLS = [MOVER, GOOD, TARGET, MAGIC, HOT];
  let h = D.height, hT = D.height, beat = 0;
  const handX = (k) => cx + (k ? hg : -hg), side = (k) => k ? 1 : -1;
  function hand(k, psi) {                                // the hand's scoop: out while empty, in while holding
    const pc = 1 - dw / 2;                               // the phase at which it catches
    const th = psi < pc ? Math.PI * psi / pc : Math.PI + Math.PI * (psi - pc) / (1 - pc);
    return [handX(k) - side(k) * ex * Math.cos(th), hyP + ey * Math.sin(th)];
  }
  return {
    press(x, y) { hT = clamp((hyP - y) / H, 0.12, 0.62); },
    frame(dt, t) {
      stage();
      h += (hT - h) * smooth(3, dt);
      const T = 2 * Math.sqrt(2 * h / D.g);              // flight time — the H's cancel
      const b = T / (n - dw);                            // the beat
      beat += dt / b;
      const G = D.g * H, v0 = G * T / 2;
      for (let k = 0; k < 2; k++) {                      // the hands' ellipses, and the hands
        ctx.strokeStyle = "rgba(232,229,244,0.12)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let j = 0; j <= 24; j++) {
          const th = j / 24 * Math.PI * 2;
          const x = handX(k) - side(k) * ex * Math.cos(th), y = hyP + ey * Math.sin(th);
          if (j === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
        let psi = ((beat - k) / 2) % 1;
        if (psi < 0) psi += 1;
        const hp = hand(k, psi);
        ring(hp[0], hp[1], 7, BONE, 2);
      }
      for (let k = 0; k < 2; k++)                        // the two flight paths, faint
        for (let j = 0; j <= 14; j++) {
          const tau = T * j / 14;
          dot(lerp(handX(k) - side(k) * ex, handX(1 - k) + side(1 - k) * ex, j / 14),
              hyP - v0 * tau + 0.5 * G * tau * tau, 1.1, DIM);
        }
      ring(cx, hyP - h * H, 4, "rgba(245,193,105,0.5)");
      label("h", cx + 8, hyP - h * H + 4, "rgba(245,193,105,0.7)");
      for (let i = 0; i < n; i++) {
        const q = Math.floor((beat - i) / n), phi = beat - i - q * n;   // beats since this ball's last throw
        const from = (((q * n + i) % 2) + 2) % 2, to = 1 - from;          // throw m comes from hand m mod 2
        let x, y;
        if (phi < n - dw) {                              // in flight: Jump's parabola, hand to hand
          const tau = phi * b;
          x = lerp(handX(from) - side(from) * ex, handX(to) + side(to) * ex, phi / (n - dw));
          y = hyP - v0 * tau + 0.5 * G * tau * tau;
        } else {                                         // held: ride the catching hand's scoop
          let psi = ((beat - to) / 2) % 1;
          if (psi < 0) psi += 1;
          const hp = hand(to, psi); x = hp[0]; y = hp[1];
        }
        dot(x, y, 6, COLS[i % COLS.length]);
      }
      label("n = " + n + " · beat = " + b.toFixed(2) + " s · T = " + T.toFixed(2) + " s", W / 2, 14, null, "center");
      label(D.label, W / 2, H - 6, null, "center");
    }
  };
});
rhymeOf("Juggle", "Jester", "five balls thrown higher — the same beat arithmetic with n = 5, a court jester's showpiece", { balls: 5, height: 0.6 });

/* ============================== CHAINS & JOINTS ==============================
   Limbs. A chain is a list of points that promise to stay a fixed distance
   apart; INVERSE KINEMATICS is any recipe that places the joints so the end
   lands on a target. Four teaching cards — drag-follow (no solving at all),
   the Law of Cosines (exact, two bones), FABRIK (iterative, no trig), and
   quaternions (3D rotation, the short way round) — then a leader-following
   ring buffer, and the creatures built from all of it: octopus, vine,
   dragon, echo, inchworm, spider, mech. Every one is a list of joints. */

def("T", "Tentacle", "chains", "a follow-chain: the head leads, every link keeps its distance — press to point it", function (u) {
  var D = { n: 18, link: 10, taper: 0.28,              // links, the base spacing (px), shrink per link
            follow: 3.2,                               // the head's lerp rate toward the target
            sway: 0.05, swayFreq: 3,                   // the little life-sine on every joint, and its tempo
            sticky: 3.5, roamX: 0.34, roamY: 0.3,      // how long a press holds; the idle wander (of W, H)
            label: "each link: parent + (cos a, sin a) · length" };
  const { ctx, W, H, TAU, stage, dot, label, rand, len, MOVER, TARGET } = u;
  // the cheapest limb in games: move the head, then walk down the chain
  // placing each link at a fixed distance from the one before, along the
  // line between them (a distance constraint, solved by pure geometry —
  // each link's position is polar-to-Cartesian from its parent). drag
  // does the animating; the sway is one small sine for life.
  const N = D.n;
  const segs = [];
  for (let i = 0; i < N; i++) segs.push({ x: W / 2 - i * 9, y: H / 2 });
  let tx = W * 0.7, ty = H * 0.4, sticky = 0;
  return {
    press(px, py) { tx = px; ty = py; sticky = D.sticky; },
    frame(dt, t) {
      stage();
      sticky -= dt;
      if (sticky <= 0) {                               // resume its own errand
        tx = W / 2 + Math.cos(t * 0.6) * W * D.roamX;
        ty = H / 2 + Math.sin(t * 0.9) * H * D.roamY;
      }
      const head = segs[0];
      const k = 1 - Math.exp(-D.follow * dt);          // the head is a lerp-follower
      head.x += (tx - head.x) * k;
      head.y += (ty - head.y) * k;
      for (let i = 1; i < N; i++) {
        const p = segs[i - 1], s = segs[i];
        const L = Math.max(2, D.link - i * D.taper);   // links shorten toward the tail
        let dx = s.x - p.x, dy = s.y - p.y;
        const d = len(dx, dy) || 1;
        const a = Math.atan2(dy, dx) + Math.sin(t * D.swayFreq - i * 0.5) * D.sway;  // the sway
        s.x = p.x + Math.cos(a) * L;                   // ← the whole constraint:
        s.y = p.y + Math.sin(a) * L;                   //   same direction, fixed length
      }
      for (let i = N - 1; i >= 0; i--) {
        const r = Math.max(1.6, 8.5 - i * 0.42);
        dot(segs[i].x, segs[i].y, r, i === 0 ? MOVER : "rgba(138,217,245," + Math.max(0.08, 0.8 - i * 0.038) + ")");
      }
      const hd = Math.atan2(ty - head.y, tx - head.x); // the eye watches the target
      ctx.fillStyle = "#131020";
      ctx.beginPath();
      ctx.arc(head.x + Math.cos(hd) * 3.4, head.y + Math.sin(hd) * 3.4, 2, 0, TAU);
      ctx.fill();
      dot(tx, ty, 3, TARGET);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Tentacle", "Thrash", "the same chain with six times the sway at three times the tempo and a keener head — a whip, not a drift", { sway: 0.3, swayFreq: 9, follow: 7 });

def("I", "Ik", "chains", "two bones, one triangle, the Law of Cosines — press to re-aim and flip the elbow", function (u) {
  var D = { shoulderX: 0.34, shoulderY: 0.42,          // the fixed joint (of W, H)
            a: 0.3, b: 0.26,                           // upper arm, forearm (of H)
            sticky: 3.5, roamX: 0.34, roamY: 0.28,     // how long a press holds; the idle wander (of W, H)
            label: "cos A = (a² + d² − b²) / 2ad" };
  const { ctx, W, H, TAU, stage, dot, ring, label, clamp, len, BONE, MOVER, TARGET, DIM } = u;
  // two-bone IK is exact, no iteration: shoulder→target is a triangle with
  // sides a (upper arm), b (forearm), d (the reach), and the Law of
  // Cosines hands over the shoulder angle:
  //   cos(A) = (a² + d² − b²) / (2·a·d)
  // the ± on that angle is the ELBOW FLIP — the same hand position with
  // the joint bent the other way. arms, legs, and turrets end here.
  const sx = W * D.shoulderX, sy = H * D.shoulderY;
  const a = H * D.a, b = H * D.b;
  let flip = 1, tx = 0, ty = 0, sticky = 0;
  return {
    press(px, py) { tx = px; ty = py; sticky = D.sticky; flip = -flip; },
    frame(dt, t) {
      stage();
      sticky -= dt;
      if (sticky <= 0) {
        tx = sx + Math.cos(t * 0.7) * W * D.roamX;
        ty = sy + Math.sin(t * 1.1) * H * D.roamY;
      }
      let dx = tx - sx, dy = ty - sy;
      const reach = clamp(len(dx, dy), Math.abs(a - b) + 2, a + b - 2);  // stay solvable
      const base = Math.atan2(dy, dx);
      const cosA = (a * a + reach * reach - b * b) / (2 * a * reach);    // Law of Cosines
      const ang = base + Math.acos(clamp(cosA, -1, 1)) * flip;
      const ex = sx + Math.cos(ang) * a, ey = sy + Math.sin(ang) * a;    // the elbow
      const hx = sx + Math.cos(base) * reach, hy = sy + Math.sin(base) * reach;
      ring(sx, sy, a + b, "rgba(232,229,244,0.08)");   // the reach envelope
      ctx.setLineDash([3, 4]);                         // the triangle being solved
      ctx.strokeStyle = DIM;
      ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(hx, hy); ctx.stroke();
      ctx.setLineDash([]);
      ctx.strokeStyle = BONE;
      ctx.lineCap = "round";
      ctx.lineWidth = 6;
      ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(ex, ey); ctx.lineTo(hx, hy); ctx.stroke();
      ctx.lineWidth = 1;
      ctx.lineCap = "butt";
      dot(sx, sy, 5, MOVER);
      dot(ex, ey, 4.5, BONE);
      dot(hx, hy, 4, TARGET);
      label("a", (sx + ex) / 2 - 10, (sy + ey) / 2, "rgba(201,196,228,0.8)");
      label("b", (ex + hx) / 2 + 8, (ey + hy) / 2, "rgba(201,196,228,0.8)");
      label("d", (sx + hx) / 2 + 6, (sy + hy) / 2 + 12, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Ik", "Insect", "a stubby upper arm and a long forearm — the same triangle, but now an insect's leg that can never fold flat", { a: 0.14, b: 0.42 });

def("F", "Fabrik", "chains", "IK with no trigonometry: slide joints along lines, twice, done — press to set the target", function (u) {
  var D = { n: 4, bone: 0.2,                           // joints, and the bone between them (of H)
            iters: 6,                                  // backward+forward passes per frame
            sticky: 3.5, roamX: 0.4, roamY: 0.3,       // how long a press holds; the idle wander (of W, H)
            label: "backward pass, forward pass — no angles" };
  const { ctx, W, H, GY, stage, ground, dot, ring, label, len, BONE, MOVER, TARGET } = u;
  // FABRIK (Forward And Backward Reaching IK): the BACKWARD pass pins the
  // hand to the target and drags the chain down toward the base; the
  // FORWARD pass re-pins the base and drags it back out. every step is
  // "project this point onto the line to its neighbour at bone length" —
  // constraint geometry, not one sine or cosine anywhere. it handles any
  // number of bones, and aims past its reach by simply straightening.
  const n = D.n;
  const L = H * D.bone;
  const bx = W / 2, by = GY;
  const pts = [];
  for (let i = 0; i < n; i++) pts.push({ x: bx, y: by - i * L });
  let tx = W * 0.7, ty = H * 0.3, sticky = 0;
  function toward(from, to, dist) {                    // the one operation FABRIK owns
    const dx = to.x - from.x, dy = to.y - from.y, d = len(dx, dy) || 1;
    return { x: to.x - dx / d * dist, y: to.y - dy / d * dist };
  }
  return {
    press(px, py) { tx = px; ty = py; sticky = D.sticky; },
    frame(dt, t) {
      stage(); ground();
      sticky -= dt;
      if (sticky <= 0) {
        tx = bx + Math.cos(t * 0.55) * W * D.roamX;
        ty = by - H * 0.36 + Math.sin(t * 0.85) * H * D.roamY;
      }
      for (let it = 0; it < D.iters; it++) {
        pts[n - 1].x = tx; pts[n - 1].y = ty;          // backward: hand on target...
        for (let i = n - 2; i >= 0; i--) {
          const q = toward(pts[i], pts[i + 1], L);
          pts[i].x = q.x; pts[i].y = q.y;              // ...each joint slides to bone length
        }
        pts[0].x = bx; pts[0].y = by;                  // forward: base back on its anchor...
        for (let i = 1; i < n; i++) {
          const q = toward(pts[i], pts[i - 1], L);
          pts[i].x = q.x; pts[i].y = q.y;
        }
      }
      ring(bx, by, L * (n - 1), "rgba(232,229,244,0.08)");
      ctx.strokeStyle = BONE;
      ctx.lineCap = "round";
      for (let i = 0; i < n - 1; i++) {
        ctx.lineWidth = Math.max(1.5, 7 - i * 1.5);
        ctx.beginPath(); ctx.moveTo(pts[i].x, pts[i].y); ctx.lineTo(pts[i + 1].x, pts[i + 1].y); ctx.stroke();
      }
      ctx.lineWidth = 1;
      ctx.lineCap = "butt";
      for (let i = 0; i < n; i++) dot(pts[i].x, pts[i].y, Math.max(1.5, 4.5 - i * 0.5), i ? BONE : MOVER);
      dot(tx, ty, 3.5, TARGET);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Fabrik", "Filament", "nine short bones instead of four long ones, ten passes a frame — the same solver, now a supple feeler", { n: 9, bone: 0.085, iters: 10 });

def("Q", "Quaternion", "chains", "slerp turns a cube the short way; lerping three angles wobbles — press for a new pose", function (u) {
  var D = { dur: 1.5, rest: 1.1,                       // seconds per blend, the pause between poses
            yawMax: 2.4, pitchMax: 1.3,                // how far a new pose may swing (radians)
            size: 0.16, persp: 4.2,                    // the cube (of H), the camera's distance in cube units
            label: "bright: slerp(q₁, q₂)   faint: lerping yaw/pitch/roll" };
  const { ctx, W, H, stage, label, rand, ease, MOVER, DIM } = u;
  // in 3D, storing rotation as three angles (yaw, pitch, roll) invites
  // trouble: blending them one-by-one takes curly detours and can gimbal-
  // lock. a QUATERNION is four numbers naming an axis and a twist about
  // it; SLERP (spherical lerp) walks between two of them along the one
  // shortest arc at constant speed. the bright cube slerps; the faint
  // ghost lerps its three euler angles — same start, same end, honest
  // difference in between.
  function qmul(a, b) {
    return [
      a[0] * b[0] - a[1] * b[1] - a[2] * b[2] - a[3] * b[3],
      a[0] * b[1] + a[1] * b[0] + a[2] * b[3] - a[3] * b[2],
      a[0] * b[2] - a[1] * b[3] + a[2] * b[0] + a[3] * b[1],
      a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0]
    ];
  }
  function axis(ax, ay, az, an) {
    const s = Math.sin(an / 2);
    return [Math.cos(an / 2), ax * s, ay * s, az * s];
  }
  function fromEuler(yaw, pitch, roll) {               // build the SAME pose both ways
    return qmul(axis(0, 1, 0, yaw), qmul(axis(1, 0, 0, pitch), axis(0, 0, 1, roll)));
  }
  function slerp(a, b, k) {
    let d = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3];
    if (d < 0) { b = b.map(v => -v); d = -d; }         // take the SHORT way round
    if (d > 0.9995) return a.map((v, i) => v + (b[i] - v) * k);
    const th = Math.acos(d), s = Math.sin(th);
    const wa = Math.sin((1 - k) * th) / s, wb = Math.sin(k * th) / s;
    return a.map((v, i) => v * wa + b[i] * wb);
  }
  function rot(q, v) {                                 // rotate a point: q · v · q⁻¹
    const p = qmul(qmul(q, [0, v[0], v[1], v[2]]), [q[0], -q[1], -q[2], -q[3]]);
    return [p[1], p[2], p[3]];
  }
  const V = [];
  for (let i = 0; i < 8; i++) V.push([(i & 1 ? 1 : -1), (i & 2 ? 1 : -1), (i & 4 ? 1 : -1)]);
  const EDGES = [[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]];
  let ea = [0, 0, 0], eb = [rand(-D.yawMax, D.yawMax), rand(-D.pitchMax, D.pitchMax), rand(-D.yawMax, D.yawMax)];
  let qa = fromEuler(0, 0, 0), qb = fromEuler(eb[0], eb[1], eb[2]);
  let k = 0, restT = 0;
  function retarget() {
    qa = slerp(qa, qb, ease(Math.min(1, k)));          // freeze wherever we are
    ea = ea.map((v, i) => v + (eb[i] - v) * ease(Math.min(1, k)));
    eb = [rand(-D.yawMax, D.yawMax), rand(-D.pitchMax, D.pitchMax), rand(-D.yawMax, D.yawMax)];
    qb = fromEuler(eb[0], eb[1], eb[2]);
    k = 0;
  }
  function drawCube(q, size, col, lw) {
    const cx = W / 2, cy = H * 0.48, F = D.persp;
    const P = V.map(v => {
      const r = rot(q, v);
      const s = F / (F + r[2]) * size;                 // a whisper of perspective
      return [cx + r[0] * s, cy + r[1] * s];
    });
    ctx.strokeStyle = col;
    ctx.lineWidth = lw;
    ctx.beginPath();
    for (const e of EDGES) { ctx.moveTo(P[e[0]][0], P[e[0]][1]); ctx.lineTo(P[e[1]][0], P[e[1]][1]); }
    ctx.stroke();
    ctx.lineWidth = 1;
  }
  return {
    press() { retarget(); restT = 0; },
    frame(dt, t) {
      stage();
      if (k >= 1) { restT += dt; if (restT > D.rest) { restT = 0; retarget(); } }
      else k = Math.min(1, k + dt / D.dur);
      const kk = ease(k);
      const ge = ea.map((v, i) => v + (eb[i] - v) * kk);           // the naive route
      drawCube(fromEuler(ge[0], ge[1], ge[2]), H * D.size, "rgba(232,229,244,0.2)", 1);
      drawCube(slerp(qa, qb, kk), H * D.size, MOVER, 1.5);         // the quaternion route
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Quaternion", "Quickstep", "the same slerp at a quarter of the duration, hardly a pause, a bigger cube — a cube dancing pose to pose", { dur: 0.4, rest: 0.3, size: 0.22 });

def("Q", "Queue", "chains", "leader following: each body steps into where the leader stood N frames ago — press to retarget the leader", function (u) {
  var D = { followers: 7, spacing: 9,                  // bodies in the line, ticks of delay between them
            buf: 160,                                  // the ring buffer's length (ticks of memory)
            speed: 75, turn: 2.6, jitter: 3.0,         // the leader: px/s, turn limit (rad/s), wander jitter
            sticky: 4,                                 // how long a press steers the leader
            label: "follower i = history[now − i · spacing]" };
  const { ctx, W, H, TAU, stage, dot, mote, label, rand, len, clamp, wrapAngle, MOVER, TARGET } = u;
  // LEADER FOLLOWING, the conga-line trick: the leader writes where it is
  // every tick into a RING BUFFER (a fixed array written round and round,
  // the index wrapping with a modulo); follower i simply reads the entry
  // from i·spacing ticks ago. no steering, no chasing — a snake body, a
  // train of ducklings, the tail of Snake itself, all for one array. the
  // ticks are fixed at 1/60 s so "frames ago" means the same at any rate.
  const TICK = 1 / 60;
  let x = W * 0.5, y = H * 0.5, h = 0, wa = 0, acc = 0, headIdx = 0, sticky = 0;
  let tx = W * 0.7, ty = H * 0.4;
  const buf = [];
  for (let i = 0; i < D.buf; i++) buf.push({ x: x, y: y, h: 0 });
  function tick() {
    wa = clamp(wa + rand(-1, 1) * D.jitter * Math.sqrt(TICK), -1.2, 1.2);   // a drifting wish to turn
    let want = h + wa;
    if (sticky > 0) want = Math.atan2(ty - y, tx - x);            // a press overrides the wish
    if (x < W * 0.1 || x > W * 0.9 || y < H * 0.12 || y > H * 0.88)
      want = Math.atan2(H / 2 - y, W / 2 - x);                    // near an edge: head home
    h += clamp(wrapAngle(want - h), -D.turn * TICK, D.turn * TICK);
    x += Math.cos(h) * D.speed * TICK;
    y += Math.sin(h) * D.speed * TICK;
    headIdx = (headIdx + 1) % D.buf;                   // ← the ring: write, then wrap
    const s = buf[headIdx]; s.x = x; s.y = y; s.h = h;
  }
  return {
    press(px, py) { tx = px; ty = py; sticky = D.sticky; },
    frame(dt, t) {
      stage();
      sticky -= dt;
      acc = Math.min(acc + dt, 0.1);
      let guard = 0;
      while (acc >= TICK && guard++ < 6) { acc -= TICK; tick(); }
      if (sticky > 0 && len(tx - x, ty - y) < 10) sticky = 0;
      for (let i = 0; i < D.buf; i += 4) dot(buf[i].x, buf[i].y, 1, "rgba(232,229,244,0.12)");   // the buffer, faintly
      for (let i = D.followers; i >= 1; i--) {         // tail first, so the front overlaps
        const back = Math.min(i * D.spacing, D.buf - 1);
        const s = buf[(headIdx - back + D.buf) % D.buf];   // ← the read: now − i·spacing, wrapped
        mote(s.x, s.y, s.h, "rgba(138,217,245," + Math.max(0.2, 0.85 - i * 0.08) + ")", Math.max(3, 7 - i * 0.4));
      }
      if (sticky > 0) dot(tx, ty, 3.5, TARGET);
      mote(x, y, h);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Queue", "Quail", "twelve followers at half the spacing and a slower stroll — a quail and her chicks, tight on her tail", { followers: 12, spacing: 4, speed: 55 });

def("O", "Octopus", "chains", "Tentacle ×8 behind a body that swims by jet pulses — Undulate's curl, Dash's decay — press to send it off", function (u) {
  var D = { arms: 8, links: 7, link: 6,                // chains, joints per chain, joint spacing (px)
            spread: 2.4,                               // how wide the arms fan across the back (radians)
            pulseEvery: 1.3, jet: 170, drag: 1.6,      // seconds between jets, the impulse (px/s), the decay rate
            curl: 0.22, curlFreq: 4,                   // the sine on every joint's angle, and its tempo
            bodyR: 11, sticky: 4,
            label: "jet: v += J·dir, then v ·= e^(−drag·dt)" };
  const { ctx, W, H, TAU, stage, dot, ring, label, len, clamp, wrapAngle, MOVER, TARGET } = u;
  // an octopus is three cards wearing a hat. the body swims by JET pulses:
  // every pulseEvery seconds an IMPULSE toward the target (Dash), and
  // between pulses only drag — v ·= e^(−k·dt) — so each squirt eases out
  // by itself. the eight arms are Tentacle's follow-chain, rooted around
  // the back of the mantle, with Undulate's phase-shifted sine on every
  // joint so they curl instead of trailing dead straight.
  let x = W * 0.4, y = H * 0.5, vx = 0, vy = 0, h = 0, pulseT = 0.6, age = 9, sticky = 0;
  let tx = W * 0.7, ty = H * 0.4;
  const arms = [];
  for (let a = 0; a < D.arms; a++) {
    const chain = [];
    for (let i = 0; i < D.links; i++) chain.push({ x: x - i * D.link, y: y });
    arms.push(chain);
  }
  return {
    press(px, py) { tx = px; ty = py; sticky = D.sticky; },
    frame(dt, t) {
      stage();
      sticky -= dt;
      if (sticky <= 0) {                               // an idle errand around the tank
        tx = W / 2 + Math.cos(t * 0.35) * W * 0.32;
        ty = H / 2 + Math.sin(t * 0.55) * H * 0.28;
      }
      const dx = tx - x, dy = ty - y, d = len(dx, dy) || 1;
      pulseT -= dt; age += dt;
      if (pulseT <= 0) {
        pulseT = D.pulseEvery; age = 0;
        const J = D.jet * clamp(d / 80, 0.25, 1);      // a softer squirt when nearly there
        vx += dx / d * J; vy += dy / d * J;            // the IMPULSE: velocity edited once
      }
      const decay = Math.exp(-D.drag * dt);            // then only drag, every frame
      vx *= decay; vy *= decay;
      x += vx * dt; y += vy * dt;
      const m = 24;
      if (x < m) { x = m; vx = Math.abs(vx) * 0.5; }
      if (x > W - m) { x = W - m; vx = -Math.abs(vx) * 0.5; }
      if (y < m) { y = m; vy = Math.abs(vy) * 0.5; }
      if (y > H - m) { y = H - m; vy = -Math.abs(vy) * 0.5; }
      if (len(vx, vy) > 8) h += wrapAngle(Math.atan2(vy, vx) - h) * Math.min(1, 6 * dt);
      const squeeze = Math.exp(-age * 5);              // the mantle contracts on each jet
      for (let a = 0; a < D.arms; a++) {
        const chain = arms[a];
        const root = h + Math.PI + ((a + 0.5) / D.arms - 0.5) * D.spread;   // rooted on the back
        chain[0].x = x + Math.cos(root) * D.bodyR * 0.8;
        chain[0].y = y + Math.sin(root) * D.bodyR * 0.8;
        for (let i = 1; i < D.links; i++) {
          const p = chain[i - 1], s = chain[i];
          let aa = Math.atan2(s.y - p.y, s.x - p.x);   // Tentacle's constraint...
          aa += wrapAngle(root - aa) * 0.08;           // ...a whisper of "trail behind"
          aa += Math.sin(t * D.curlFreq - i * 0.7 + a * 0.9) * D.curl;   // ...and Undulate's curl
          s.x = p.x + Math.cos(aa) * D.link;
          s.y = p.y + Math.sin(aa) * D.link;
        }
        for (let i = D.links - 1; i >= 0; i--)
          dot(chain[i].x, chain[i].y, Math.max(1.2, 3.6 - i * 0.4), "rgba(138,217,245," + Math.max(0.1, 0.75 - i * 0.08) + ")");
      }
      if (age < 0.35)                                  // the jet's puff, behind the mantle
        ring(x - Math.cos(h) * D.bodyR, y - Math.sin(h) * D.bodyR, 4 + age * 60, "rgba(138,217,245," + Math.max(0, 0.5 - age * 1.4) + ")");
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(h);
      ctx.scale(1 + squeeze * 0.3, 1 - squeeze * 0.25);   // squash & stretch along the jet
      ctx.fillStyle = MOVER;
      ctx.beginPath(); ctx.arc(0, 0, D.bodyR, 0, TAU); ctx.fill();
      ctx.beginPath(); ctx.arc(-D.bodyR * 0.5, 0, D.bodyR * 0.85, 0, TAU); ctx.fill();   // the mantle
      ctx.fillStyle = "#131020";
      ctx.beginPath(); ctx.arc(D.bodyR * 0.45, -D.bodyR * 0.35, 2.2, 0, TAU); ctx.fill();
      ctx.beginPath(); ctx.arc(D.bodyR * 0.45, D.bodyR * 0.35, 2.2, 0, TAU); ctx.fill();
      ctx.restore();
      dot(tx, ty, 3, TARGET);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Octopus", "Oracle", "a jet every three seconds, gentler, with twice the curl — a deep-sea oracle drifting on its own slow thoughts", { pulseEvery: 2.8, jet: 120, curl: 0.45 });

def("V", "Vine", "chains", "a chain that grows: each new joint bends from its parent toward the light, plus noise — press to move the sun", function (u) {
  var D = { seg: 0.05,                                 // joint length (of H)
            growEvery: 0.28,                           // seconds per new joint
            tropism: 0.35,                             // how much of the turn-to-light each joint takes
            curl: 0.5, maxBend: 0.7,                   // the noise wobble (rad), a joint's bend limit (rad)
            leafEvery: 3, leafSize: 0.035,             // a leaf every k joints, its length (of H)
            maxSegs: 40, reach: 14, bloomHold: 1.6,    // give up after k joints; the win radius (px); the bloom pause (s)
            sway: 0.025, rootX: 0.5,                   // the breeze (rad), where it is planted (of W)
            sticky: 8,                                 // how long a press holds the light
            label: "a = parent + (light − parent)·tropism + noise" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, poly, arrow, label, rand, len, clamp, wrapAngle, noise, GOOD, TARGET, MAGIC, DIM } = u;
  // PHOTOTROPISM, one joint at a time: a plant is a chain that adds a link
  // every so often, and each new link copies its parent's ANGLE, then turns
  // a fraction of the way toward the light (a lerp on an angle — wrapAngle
  // first) plus a little noise for the wobble real stems have. the angles
  // are the memory: the chain is re-laid from the root every frame with a
  // tiny sway, so nothing drifts. reach the light: bloom, rest, regrow.
  let angs = [], seed = 0, growT = 0, bloom = 0, won = false, sticky = 0;
  let lx = W * 0.72, ly = H * 0.2;
  const pts = [];
  function reset() { angs = []; seed = rand(0, 100); growT = 0; bloom = 0; won = false; }
  reset();
  return {
    press(px, py) { lx = px; ly = py; sticky = D.sticky; },
    frame(dt, t) {
      stage(); ground();
      sticky -= dt;
      if (sticky <= 0) {                               // the sun wanders, slowly
        lx = W / 2 + Math.cos(t * 0.23) * W * 0.36;
        ly = H * 0.3 + Math.sin(t * 0.31) * H * 0.16;
      }
      const L = H * D.seg;
      let x = W * D.rootX, y = GY;
      pts.length = 0; pts.push([x, y]);
      for (let i = 0; i < angs.length; i++) {          // re-lay the chain from its angles
        const a = angs[i] + Math.sin(t * 1.3 - i * 0.35) * D.sway * (1 + i * 0.1);
        const g = i === angs.length - 1 ? clamp(growT / D.growEvery, 0.05, 1) : 1;   // the tip grows in
        x += Math.cos(a) * L * g; y += Math.sin(a) * L * g;
        pts.push([x, y]);
      }
      if (bloom > 0) { bloom -= dt; if (bloom <= 0) reset(); }
      else {
        growT += dt;
        if (growT >= D.growEvery) {
          growT = 0;
          const parent = angs.length ? angs[angs.length - 1] : -Math.PI / 2;   // the seed points up
          const toLight = Math.atan2(ly - y, lx - x);
          const bend = wrapAngle(toLight - parent) * D.tropism            // ← phototropism
                     + noise(angs.length * 0.9 + seed) * D.curl;          // ← the wobble
          angs.push(parent + clamp(bend, -D.maxBend, D.maxBend));
        }
        if (angs.length && len(lx - x, ly - y) < D.reach) { bloom = D.bloomHold; won = true; }
        else if (angs.length >= D.maxSegs) bloom = D.bloomHold * 0.4;   // too long: wilt, try again
      }
      for (let i = 0; i < pts.length - 1; i++)
        line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], GOOD, Math.max(1, 3.5 - i * 0.07));
      for (let i = D.leafEvery; i < pts.length; i += D.leafEvery) {   // leaves, alternating sides
        const p = pts[i], q = pts[i - 1];
        const ddx = p[0] - q[0], ddy = p[1] - q[1], dd = len(ddx, ddy) || 1;
        const side = (i / D.leafEvery) % 2 ? 1 : -1;
        const nx = -ddy / dd * side, ny = ddx / dd * side, ux = ddx / dd, uy = ddy / dd;
        const s = H * D.leafSize;
        poly([[p[0], p[1]],
              [p[0] + (nx * 0.5 + ux * 0.35) * s, p[1] + (ny * 0.5 + uy * 0.35) * s],
              [p[0] + nx * s, p[1] + ny * s],
              [p[0] + (nx * 0.5 - ux * 0.35) * s, p[1] + (ny * 0.5 - uy * 0.35) * s]], "rgba(155,226,138,0.55)");
      }
      const tip = pts[pts.length - 1];
      if (bloom > 0) {
        ring(tip[0], tip[1], 5 + (D.bloomHold - bloom) * 12, won ? MAGIC : DIM, 1.5);
        dot(tip[0], tip[1], 4, won ? MAGIC : DIM);
      } else {
        const ta = Math.atan2(ly - tip[1], lx - tip[0]);   // the pull it will feel next
        arrow(tip[0], tip[1], tip[0] + Math.cos(ta) * 16, tip[1] + Math.sin(ta) * 16, DIM);
        dot(tip[0], tip[1], 2.5, MAGIC);
      }
      ring(lx, ly, 9, "rgba(245,193,105,0.35)");
      dot(lx, ly, 4, TARGET);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Vine", "Viper", "a joint every eighth of a second, triple the wobble, a weak pull to the light — a creeper that hunts, not grows", { growEvery: 0.12, curl: 1.4, tropism: 0.15 });

def("D", "Dragon", "chains", "Wander's head, Tentacle's body, Undulate's ripple; wings on that sine, fire on a timer — press to lure it", function (u) {
  var D = { n: 22, link: 9, taper: 0.18,               // body joints, their spacing (px), shrink toward the tail
            speed: 80, ahead: 40, rim: 22, jitter: 2.8,   // Wander's rig: px/s, the circle ahead, its radius, angle jitter
            undAmp: 5, undFreq: 5, undPhase: 0.55,     // Undulate's ripple: px, tempo, phase per joint
            wingAt: 6, wingSpan: 26,                   // which joint wears the wings, their reach (px)
            fireEvery: 4.5, fireDur: 1.1, fireLen: 0.2,   // the breath schedule (s) and its length (of W)
            sticky: 4,                                 // how long a lure holds
            label: "body: follow-chain + sin(t·f − i·φ) sideways" };
  const { ctx, W, H, TAU, stage, dot, poly, line, label, rand, len, noise, MOVER, MAGIC, HOT, TARGET } = u;
  // a dragon is a Wander rig with a tail. the head steers at a jittering
  // point on a circle held out front (card W); the body is Tentacle's
  // follow-chain, so every joint keeps its distance from the one ahead;
  // the ripple is Undulate's PHASE OFFSET sine, added SIDEWAYS (along each
  // joint's normal) at draw time only — the chain stays smooth, the skin
  // waves. the wings flap on the same sine as their joint, and the fire
  // is a schedule: (t mod every) < duration. no keyframes anywhere.
  let x = W * 0.5, y = H * 0.5, vx = D.speed, vy = 0, wa = 0, sticky = 0;
  let tx = 0, ty = 0;
  const WA = Math.min(D.wingAt, D.n - 2);
  const segs = [];
  for (let i = 0; i < D.n; i++) segs.push({ x: x - i * D.link, y: y });
  return {
    press(px, py) { tx = px; ty = py; sticky = D.sticky; },
    frame(dt, t) {
      stage();
      sticky -= dt;
      wa += rand(-1, 1) * D.jitter * Math.sqrt(dt);    // the only randomness in the rig
      const sp = len(vx, vy) || 1, hx = vx / sp, hy = vy / sp, head = Math.atan2(hy, hx);
      let gx = x + hx * D.ahead + Math.cos(head + wa) * D.rim;   // Wander's rim dot
      let gy = y + hy * D.ahead + Math.sin(head + wa) * D.rim;
      if (sticky > 0) { gx = tx; gy = ty; if (len(tx - x, ty - y) < 12) sticky = 0; }
      if (x < W * 0.1 || x > W * 0.9 || y < H * 0.12 || y > H * 0.88) { gx = W / 2; gy = H / 2; }
      const dx = gx - x, dy = gy - y, d = len(dx, dy) || 1;
      vx += (dx / d * D.speed - vx) * Math.min(1, 3 * dt);
      vy += (dy / d * D.speed - vy) * Math.min(1, 3 * dt);
      const s2 = len(vx, vy) || 1;
      vx *= D.speed / s2; vy *= D.speed / s2;          // a constant cruise
      x += vx * dt; y += vy * dt;
      segs[0].x = x; segs[0].y = y;
      for (let i = 1; i < D.n; i++) {                  // Tentacle's constraint, link by link
        const p = segs[i - 1], s = segs[i];
        const ddx = s.x - p.x, ddy = s.y - p.y, dd = len(ddx, ddy) || 1;
        const L = Math.max(3, D.link - i * D.taper);
        s.x = p.x + ddx / dd * L; s.y = p.y + ddy / dd * L;
      }
      const fire = (t % D.fireEvery) < D.fireDur;      // the breath is a schedule
      for (let i = D.n - 1; i >= 1; i--) {             // tail first, head on top
        const p = segs[i - 1], s = segs[i];
        const ddx = p.x - s.x, ddy = p.y - s.y, dd = len(ddx, ddy) || 1;
        const ux = ddx / dd, uy = ddy / dd, nx = -uy, ny = ux;   // toward the head, and its normal
        const off = Math.sin(t * D.undFreq - i * D.undPhase) * D.undAmp * (0.3 + i / D.n);   // the ripple
        const px = s.x + nx * off, py = s.y + ny * off;
        const r = Math.max(1.5, 8 - i * 0.32);
        if (i === WA) {                                // the wings, flapping on the same sine
          const flap = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(t * D.undFreq - i * D.undPhase));
          for (let side = -1; side <= 1; side += 2) {
            const reach = D.wingSpan * flap * side;
            poly([[px - ux * 4, py - uy * 4],
                  [px + nx * reach - ux * D.wingSpan * 0.45, py + ny * reach - uy * D.wingSpan * 0.45],
                  [px + nx * reach * 0.55 - ux * D.wingSpan * 0.9, py + ny * reach * 0.55 - uy * D.wingSpan * 0.9],
                  [px + ux * 6, py + uy * 6]], side < 0 ? "rgba(201,160,245,0.6)" : "rgba(201,160,245,0.4)");
          }
        }
        if (i % 3 === 0)                               // a spine every third joint
          poly([[px + nx * r, py + ny * r], [px + nx * (r + 5) - ux * 2, py + ny * (r + 5) - uy * 2], [px + nx * r - ux * 4, py + ny * r - uy * 4]], "rgba(201,160,245,0.7)");
        dot(px, py, r, "rgba(138,217,245," + Math.max(0.15, 0.85 - i * 0.03) + ")");
      }
      if (fire) {                                      // the lantern: dots along the heading, jittered by noise
        const mx = x + hx * 12, my = y + hy * 12, nx = -hy, ny = hx;
        for (let j = 0; j < 12; j++) {
          const k = (j + 0.5) / 12;
          const wob = noise(t * 9 + j * 1.7) * k * 10;
          dot(mx + hx * k * W * D.fireLen + nx * wob, my + hy * k * W * D.fireLen + ny * wob,
              2 + k * 4, j % 2 ? "rgba(245,138,138," + (1 - k) * 0.8 + ")" : "rgba(245,193,105," + (1 - k) * 0.8 + ")");
        }
      }
      line(x - hx * 3 - hy * 5, y - hy * 3 + hx * 5, x - hx * 10 - hy * 10, y - hy * 10 + hx * 10, MAGIC, 2);   // horns
      line(x - hx * 3 + hy * 5, y - hy * 3 - hx * 5, x - hx * 10 + hy * 10, y - hy * 10 - hx * 10, MAGIC, 2);
      u.mote(x, y, head, MOVER, 9);
      if (sticky > 0) dot(tx, ty, 3, TARGET);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Dragon", "Drake", "a twelve-joint body at nearly double the speed, breathing fire every two seconds — a small, cross, quick drake", { n: 12, speed: 130, fireEvery: 1.8 });

def("E", "Echo", "chains", "Queue's buffer, but of the whole state — pose, heading, colour — replayed by clones — press to change the spacing", function (u) {
  var D = { clones: 8, spacings: [5, 12, 24],          // ghosts, and the delays (ticks) a press cycles through
            buf: 400,                                  // ticks of memory
            a: 1, b: 2, speed: 1.1, rx: 0.36, ry: 0.32,   // the Lissajous the mote runs (radii of W, H)
            hueRate: 1.7,                              // how fast the colour cycles
            label: "clone i = state[now − i · spacing]" };
  const { ctx, W, H, TAU, stage, dot, mote, label, lerp, MOVER, MAGIC } = u;
  // MOTION ECHO: Queue kept only positions; this buffer keeps the mote's
  // whole STATE each tick — x, y, heading, and a colour phase — and N
  // clones replay it from further and further back. the lesson: "a body"
  // is just a record you can store and read late. the same trick powers
  // ghost racers, rewind, and every trippy afterimage. the colour is a
  // lerp between the blue and the violet, driven by its own slow sine.
  const TICK = 1 / 60;
  let si = 0, acc = 0, headIdx = 0, tt = 0;
  const buf = [];
  for (let i = 0; i < D.buf; i++) buf.push({ x: W / 2, y: H / 2, h: 0, c: 0 });
  function col(c, alpha) {                             // MOVER → MAGIC, channel by channel
    return "rgba(" + Math.round(lerp(138, 201, c)) + "," + Math.round(lerp(217, 160, c)) + ",245," + alpha + ")";
  }
  function tick() {
    tt += TICK;
    const T = tt * D.speed;
    const x = W / 2 + Math.cos(D.a * T) * W * D.rx;
    const y = H / 2 + Math.sin(D.b * T) * H * D.ry;
    const vx = -Math.sin(D.a * T) * D.a * W * D.rx;    // the derivative gives the heading
    const vy = Math.cos(D.b * T) * D.b * H * D.ry;
    headIdx = (headIdx + 1) % D.buf;
    const s = buf[headIdx];
    s.x = x; s.y = y; s.h = Math.atan2(vy, vx); s.c = 0.5 + 0.5 * Math.sin(tt * D.hueRate);   // ← the whole state
  }
  return {
    press() { si = (si + 1) % D.spacings.length; },
    frame(dt, t) {
      stage();
      acc = Math.min(acc + dt, 0.1);
      let guard = 0;
      while (acc >= TICK && guard++ < 6) { acc -= TICK; tick(); }
      const sp = D.spacings[si];
      for (let i = 0; i < D.buf; i += 6) dot(buf[i].x, buf[i].y, 0.8, "rgba(232,229,244,0.1)");   // the buffer
      for (let i = D.clones; i >= 1; i--) {            // oldest first, faintest
        const back = Math.min(i * sp, D.buf - 1);
        const s = buf[(headIdx - back + D.buf) % D.buf];
        mote(s.x, s.y, s.h, col(s.c, Math.max(0.12, 0.8 - i * (0.7 / D.clones))), Math.max(4, 8 - i * 0.3));
      }
      const now = buf[headIdx];
      mote(now.x, now.y, now.h, col(now.c, 1));
      label("spacing = " + sp + " ticks", W - 8, 14, null, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Echo", "Eidolon", "four ghosts up to a second and a half apart on a 1:3 knot — an eidolon trailing its own past selves", { clones: 4, spacings: [30, 60, 90], b: 3 });

def("W", "Worm", "chains", "Gait's planted foot, Undulate's arch — one anchor holds while the other slides — press to set its heading", function (u) {
  var D = { lmin: 0.12, lmax: 0.3,                     // the gap between anchors, contracted / extended (of W)
            arch: 0.2,                                 // how high the contracted body humps (of H)
            dur: 0.7, pause: 0.15,                     // seconds per slide, the rest at each swap
            links: 14, size: 5,                        // joints drawn along the arch, their radius (px)
            label: "arch ∝ (lmax − gap) · anchors swap each half" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, label, ease, clamp, MOVER, BONE, DIM } = u;
  // an INCHWORM is Gait with the legs removed: two anchors on the ground,
  // and the rule that only one ever moves. EXTEND: the rear holds, the
  // front slides forward, the hump flattens. CONTRACT: the front holds,
  // the rear slides up behind it, the hump rises. the body is not
  // simulated at all — it is an arc drawn between the anchors whose
  // height is (lmax − gap): pure geometry riding two easing curves.
  let rear = W * 0.3, front = W * 0.3 + W * D.lmin, dir = 1, wantDir = 1;
  let phase = 0, k = 0, pause = 0;                     // phase 0 = extend, 1 = contract
  return {
    press(px) { wantDir = px < (rear + front) / 2 ? -1 : 1; },
    frame(dt, t) {
      stage(); ground();
      const LMIN = W * D.lmin, LMAX = W * D.lmax;
      if (pause > 0) pause -= dt;
      else {
        k += dt / D.dur;
        const e = ease(clamp(k, 0, 1));
        if (phase === 0) front = rear + dir * (LMIN + (LMAX - LMIN) * e);   // rear holds, front slides
        else rear = front - dir * (LMAX - (LMAX - LMIN) * e);               // front holds, rear catches up
        if (k >= 1) {                                  // ← the anchor swap
          k = 0; phase = 1 - phase; pause = D.pause;
          if (phase === 0) {                           // only turn around while contracted
            if (dir > 0 && front + LMAX > W * 0.95) wantDir = -1;
            if (dir < 0 && front - LMAX < W * 0.05) wantDir = 1;
            if (wantDir !== dir) { dir = wantDir; const tmp = rear; rear = front; front = tmp; }
          }
        }
      }
      const gap = Math.abs(front - rear);
      const hump = H * D.arch * clamp((LMAX - gap) / (LMAX - LMIN), 0.12, 1);   // ← arch ∝ lmax − gap
      const holding = phase === 0 ? rear : front, sliding = phase === 0 ? front : rear;
      ring(holding, GY, 6, BONE, 1.5);
      ring(sliding, GY, 4, DIM, 1);
      label("hold", holding, GY + 18, "rgba(201,196,228,0.7)", "center");
      label("slide", sliding, GY + 18, DIM, "center");
      for (let j = 0; j < D.links; j++) {              // the arc, as a chain of dots
        const kk = j / (D.links - 1);
        const x = rear + (front - rear) * kk;
        const y = GY - Math.sin(kk * Math.PI) * hump - D.size;
        dot(x, y, D.size * (0.7 + kk * 0.3), j === D.links - 1 ? MOVER : "rgba(138,217,245," + (0.4 + kk * 0.4) + ")");
        if (j === D.links - 1) {                       // the head gets the eye
          ctx.fillStyle = "#131020";
          ctx.beginPath(); ctx.arc(x + dir * D.size * 0.4, y - D.size * 0.3, D.size * 0.28, 0, TAU); ctx.fill();
        }
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Worm", "Wiggler", "half the reach and a slide three times as quick — a busy little wiggler that never stops swapping anchors", { lmin: 0.06, lmax: 0.16, dur: 0.25 });

def("S", "Spider", "chains", "six Ik legs on a TRIPOD gait — Gait's homes and thresholds, three feet always down — press to send it off", function (u) {
  var D = { legs: 6, thigh: 0.13, shin: 0.15,          // leg count, the two bones (of H)
            spread: 0.07, hipGap: 0.02,                // foot homes and hips along the body (of W)
            thresh: 0.055, lead: 0.25,                 // Gait's step trigger (of W); how far homes lead velocity
            dur: 0.22, lift: 0.05,                     // step time (s), step arc height (of H)
            ride: 0.12, maxV: 0.3,                     // body height above the feet (of H), top speed (of W per s)
            hill: 0.05,                                // the terrain's bumps (of H)
            label: "tripod: 0,2,4 then 1,3,5 · body y = mean(feet)" };
  const { ctx, W, H, GY, TAU, stage, dot, ring, label, clamp, ease, lerp, len, rand, BONE, MOVER, TARGET } = u;
  // Gait, times three. each leg is two bones solved by the Law of Cosines
  // (card I), its knee chosen to point UP; each foot owns a HOME beside
  // its hip, pushed ahead by velocity, and steps when the home drifts
  // past a THRESHOLD. the gait is a TRIPOD: legs 0, 2, 4 fly together
  // while 1, 3, 5 hold, then swap — an insect is never off balance. the
  // body has no height of its own: it hangs a fixed ride above the MEAN
  // of its feet, so hills lift it and hollows drop it, for free.
  const N = D.legs, THIGH = H * D.thigh, SHIN = H * D.shin;
  function terra(x) { return GY - H * D.hill * (0.55 + 0.45 * Math.sin(x * 0.021 + 1) * Math.cos(x * 0.009)); }
  function off(i) { return i - (N - 1) / 2; }
  let bx = W * 0.3, vx = 0, tx = W * 0.7, autoT = 0;
  const feet = [];
  for (let i = 0; i < N; i++) {
    const fx = bx + off(i) * W * D.spread;
    feet.push({ x: fx, y: terra(fx), from: fx, fromY: terra(fx), to: fx });
  }
  let group = -1, gk = 1, next = 0;                    // which tripod is in the air, its progress, whose turn
  return {
    press(px) { tx = clamp(px, W * 0.1, W * 0.9); autoT = -8; },
    frame(dt, t) {
      stage();
      autoT += dt;
      if (autoT > 5) { autoT = 0; tx = rand(W * 0.1, W * 0.9); }
      const want = clamp((tx - bx) * 2, -W * D.maxV, W * D.maxV);
      vx += (want - vx) * Math.min(1, 5 * dt);
      bx += vx * dt;
      if (group < 0) {                                 // rule 2: does either tripod need to step?
        for (let g0 = 0; g0 < 2 && group < 0; g0++) {
          const g = (next + g0) % 2;
          let need = false;
          for (let i = g; i < N; i += 2)
            if (Math.abs(bx + off(i) * W * D.spread + vx * D.lead - feet[i].x) > W * D.thresh) need = true;
          if (need) {
            group = g; gk = 0; next = 1 - g;
            for (let i = g; i < N; i += 2) {
              const f = feet[i];
              f.from = f.x; f.fromY = f.y;
              f.to = bx + off(i) * W * D.spread + vx * (D.lead + 0.1);   // land a little ahead again
            }
          }
        }
      }
      if (group >= 0) {                                // rule 3: the whole tripod flies its arc
        gk += dt / D.dur;
        const e = ease(gk), lift = Math.sin(clamp(gk, 0, 1) * Math.PI) * H * D.lift;
        for (let i = group; i < N; i += 2) {
          const f = feet[i];
          f.x = f.from + (f.to - f.from) * e;
          f.y = lerp(f.fromY, terra(f.to), e) - lift;
        }
        if (gk >= 1) { for (let i = group; i < N; i += 2) feet[i].y = terra(feet[i].x); group = -1; }
      }
      let meanY = 0;
      for (let i = 0; i < N; i++) meanY += feet[i].y;
      meanY /= N;
      const bodyY = meanY - H * D.ride - (group >= 0 ? Math.sin(clamp(gk, 0, 1) * Math.PI) * 2 : 0);   // rule 4
      ctx.fillStyle = "rgba(150,145,190,0.13)";        // the hill itself
      ctx.strokeStyle = "rgba(201,196,228,0.55)";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, terra(0));
      for (let x = 4; x <= W; x += 4) ctx.lineTo(x, terra(x));
      ctx.stroke();
      ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath();
      ctx.fill();
      ctx.lineWidth = 1;
      for (let i = 0; i < N; i++) {                    // two-bone IK, straight from card I
        const hx = bx + off(i) * W * D.hipGap, hy = bodyY + 3;
        const f = feet[i];
        const dx = f.x - hx, dy = f.y - hy;
        const d = clamp(len(dx, dy), Math.abs(THIGH - SHIN) + 2, THIGH + SHIN - 2);
        const bse = Math.atan2(dy, dx);
        const A = Math.acos(clamp((THIGH * THIGH + d * d - SHIN * SHIN) / (2 * THIGH * d), -1, 1));
        const a1 = bse + A, a2 = bse - A;              // both elbow flips...
        const a = Math.sin(a1) < Math.sin(a2) ? a1 : a2;   // ...keep the knee that points UP
        const kx = hx + Math.cos(a) * THIGH, ky = hy + Math.sin(a) * THIGH;
        ctx.strokeStyle = BONE;
        ctx.lineCap = "round";
        ctx.lineWidth = 2.5;
        ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(kx, ky); ctx.lineTo(f.x, f.y); ctx.stroke();
        ctx.lineWidth = 1;
        ctx.lineCap = "butt";
        dot(kx, ky, 2, BONE);
        dot(f.x, f.y, 2, i % 2 === group ? "rgba(201,196,228,0.5)" : BONE);
      }
      const face = vx >= 0 ? 1 : -1;
      dot(bx - face * 9, bodyY - 2, 7.5, "rgba(138,217,245,0.8)");   // abdomen
      dot(bx, bodyY, 8, MOVER);                                       // cephalothorax
      ctx.fillStyle = "#131020";
      ctx.beginPath(); ctx.arc(bx + face * 4, bodyY - 3, 1.8, 0, TAU); ctx.fill();
      ctx.beginPath(); ctx.arc(bx + face * 6, bodyY - 0.5, 1.4, 0, TAU); ctx.fill();
      ring(tx, terra(tx) - 5, 5, TARGET, 1.5);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Spider", "Skitter", "nearly twice the speed, steps in a tenth of a second at half the threshold — a skitter, all blur and legs", { maxV: 0.55, dur: 0.11, thresh: 0.03 });

def("M", "Mech", "chains", "Gait made heavy — long slow strides, a thump that shakes the card, a Lookat cannon — press to send it somewhere", function (u) {
  var D = { thigh: 0.2,                                // each leg bone (of H)
            thresh: 0.2, maxV: 0.22,                   // Gait's step trigger and top speed (of W)
            dur: 0.55, lift: 0.07,                     // seconds per stride, the foot's arc (of H)
            hipW: 0.05, bodyH: 0.36,                   // hip spacing (of W), hip height (of H)
            shake: 6, shakeDecay: 6, shakeFreq: 40,    // the thump: px, how fast it dies (per s), its rattle (rad/s)
            dust: 7,                                   // dust dots per plant
            lean: 0.0015, aim: 5,                      // torso lean per px/s² of acceleration; the cannon's tracking rate
            label: "shake ·= e^(−k·dt) · cannon = lerp_angle" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, rect, label, clamp, ease, rand, len, wrapAngle, smooth, BONE, MOVER, TARGET, HOT } = u;
  // Gait's recipe with the numbers turned to "heavy": homes, a wide
  // threshold, slow strides, two-bone IK legs. what sells the tonnage is
  // the THUMP: on every plant a screen-shake amplitude jumps up and then
  // decays — shake ·= e^(−k·dt) — while the whole scene is drawn through
  // ctx.translate(shake · sin(fast t)); plus a puff of dust dots. the
  // torso leans into its ACCELERATION (not its speed), and the cannon is
  // Lookat: lerp_angle toward the last click at a smoothing rate.
  let bx = W * 0.35, vx = 0, pvx = 0, ax = 0, tx = W * 0.7, autoT = 0;
  let cx = W * 0.8, cy = H * 0.3, aim = 0, shake = 0;
  const feet = [{ x: bx - W * D.hipW, y: GY }, { x: bx + W * D.hipW, y: GY }];
  let stepping = -1, from = 0, to = 0, k = 0;
  const dust = [];
  function thump(x) {
    shake = D.shake;                                   // the amplitude jumps...
    for (let i = 0; i < D.dust; i++) dust.push({ x: x, y: GY, vx: rand(-60, 60), vy: rand(-90, -20), a: 1 });
    while (dust.length > 40) dust.shift();
  }
  return {
    press(px, py) { tx = clamp(px, W * 0.08, W * 0.92); autoT = -8; cx = px; cy = py; },
    frame(dt, t) {
      stage();
      autoT += dt;
      if (autoT > 6) { autoT = 0; tx = rand(W * 0.12, W * 0.88); }
      const want = clamp((tx - bx) * 1.5, -W * D.maxV, W * D.maxV);
      vx += (want - vx) * Math.min(1, 2.5 * dt);
      ax += ((vx - pvx) / Math.max(dt, 0.001) - ax) * Math.min(1, 6 * dt);   // smoothed acceleration
      pvx = vx;
      bx += vx * dt;
      for (let i = 0; i < 2; i++) {                    // Gait's rules 1 and 2: homes, threshold
        const home = bx + (i ? 1 : -1) * W * D.hipW + vx * 0.3;
        if (stepping < 0 && Math.abs(home - feet[i].x) > W * D.thresh) {
          stepping = i; from = feet[i].x; k = 0; to = home + vx * 0.15;
        }
      }
      if (stepping >= 0) {                             // rule 3: the arc — then the THUMP
        k += dt / D.dur;
        const f = feet[stepping];
        f.x = from + (to - from) * ease(k);
        f.y = GY - Math.sin(clamp(k, 0, 1) * Math.PI) * H * D.lift;
        if (k >= 1) { f.y = GY; stepping = -1; thump(f.x); }
      }
      shake *= Math.exp(-D.shakeDecay * dt);           // ...and decays, framerate-proof
      ctx.save();
      ctx.translate(Math.sin(t * D.shakeFreq) * shake, Math.cos(t * D.shakeFreq * 1.3) * shake * 0.6);
      ground();
      for (let i = dust.length - 1; i >= 0; i--) {
        const p = dust[i];
        p.vy += 200 * dt; p.x += p.vx * dt; p.y += p.vy * dt;
        if (p.y > GY) p.y = GY;
        p.a -= 1.4 * dt;
        if (p.a <= 0) { dust.splice(i, 1); continue; }
        dot(p.x, p.y, 2, "rgba(201,196,228," + p.a * 0.6 + ")");
      }
      const planted = stepping >= 0 ? feet[1 - stepping] : null;
      const hipX = bx + (planted ? (planted.x - bx) * 0.25 : 0);   // rule 4: weight over the standing foot
      const bob = stepping >= 0 ? Math.sin(clamp(k, 0, 1) * Math.PI) * 4 : 0;
      const hipY = GY - H * D.bodyH - bob;
      const THIGH = H * D.thigh;
      for (let i = 0; i < 2; i++) {                    // two-bone IK, straight from card I
        const hx = hipX + (i ? 1 : -1) * W * D.hipW * 0.5, hy = hipY;
        const f = feet[i];
        const dx = f.x - hx, dy = f.y - hy;
        const d = clamp(len(dx, dy), 4, THIGH * 2 - 2);
        const bse = Math.atan2(dy, dx);
        const cosA = clamp(d / (2 * THIGH), -1, 1);    // equal bones: the Law of Cosines simplifies
        const knee = vx >= 0 ? -1 : 1;                 // knees bend away from travel
        const a = bse + Math.acos(cosA) * knee;
        const kx = hx + Math.cos(a) * THIGH, ky = hy + Math.sin(a) * THIGH;
        ctx.strokeStyle = BONE;
        ctx.lineCap = "round";
        ctx.lineWidth = 5;
        ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(kx, ky); ctx.lineTo(f.x, f.y); ctx.stroke();
        ctx.lineWidth = 1;
        ctx.lineCap = "butt";
        rect(f.x - 7, f.y - 4, 14, 4, BONE);           // a flat, heavy foot
      }
      const lean = clamp(ax * D.lean, -0.35, 0.35);    // into the acceleration
      ctx.save();
      ctx.translate(hipX, hipY);
      ctx.rotate(lean);
      rect(-14, -28, 28, 28, MOVER);                   // the torso
      dot(0, -18, 4, "#131020");                       // the cockpit
      ctx.restore();
      const sx = hipX, sy = hipY - 18;                 // the shoulder mount
      const wantAim = Math.atan2(cy - sy, cx - sx);
      aim += wrapAngle(wantAim - aim) * smooth(D.aim, dt);   // Lookat: lerp_angle, the short way
      line(sx, sy, sx + Math.cos(aim) * 24, sy + Math.sin(aim) * 24, BONE, 4);
      dot(sx + Math.cos(aim) * 24, sy + Math.sin(aim) * 24, 2, HOT);
      ring(cx, cy, 5, "rgba(245,138,138,0.6)", 1);
      ring(tx, GY - 4, 5, TARGET, 1.5);
      ctx.restore();
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Mech", "Mantis", "short quick strides at twice the speed on a third of the threshold — a mantis, all knees and no tonnage", { dur: 0.2, thresh: 0.08, maxV: 0.45 });

/* ============================== BODIES & GROUND ==============================
   Honest physics you can read. VERLET integration stores no velocity at
   all — just where each point is and where it was last frame; the
   difference IS the velocity. Add distance constraints and you get rope,
   ragdolls, crates, jelly and kites; add rays and normals and bodies learn
   where the world is — walls to jump off, hills to roll down, flippers to
   reflect from. Gait, the graduation card, spends everything the teaching
   cards earned; the genre laps after it are that physics in costume. */

def("R", "Ragdoll", "bodies", "verlet points + distance promises = a body — press to shove it", function (u) {
  var D = { unit: 0.062, g: 2.6, damp: 0.99, rounds: 8, shove: 300,   // unit = one bone, as a fraction of H
            trolley: 0.55, swing: 0.26,                              // the overhead trolley: rate and reach
            label: "position − last position IS the velocity" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, label, len, BONE, MOVER } = u;
  // eleven points, eleven promises. each point remembers only where it is
  // and where it WAS — moving it is "keep drifting the way you were, plus
  // gravity" (verlet integration). then every stick between two points
  // restores its resting length, half from each end, eight times over.
  // out of nothing but that: elbows, slumping, swing. one hand is pinned
  // to a trolley gliding overhead.
  const U = H * D.unit, G = H * D.g;
  function pt(x, y) { return { x: x, y: y, px: x, py: y }; }
  const cx = W / 2;
  const P = {
    head: pt(cx, H * 0.2), chest: pt(cx, H * 0.2 + U), hip: pt(cx, H * 0.2 + U * 2.3),
    elbL: pt(cx - U, H * 0.24), handL: pt(cx - U * 2, H * 0.28),
    elbR: pt(cx + U, H * 0.24), handR: pt(cx + U * 2, H * 0.28),
    kneeL: pt(cx - U * 0.5, H * 0.2 + U * 3.4), footL: pt(cx - U * 0.6, H * 0.2 + U * 4.5),
    kneeR: pt(cx + U * 0.5, H * 0.2 + U * 3.4), footR: pt(cx + U * 0.6, H * 0.2 + U * 4.5)
  };
  const pts = Object.values(P);
  const C = [
    [P.head, P.chest, U], [P.chest, P.hip, U * 1.3], [P.head, P.hip, U * 2.2],
    [P.chest, P.elbL, U], [P.elbL, P.handL, U], [P.chest, P.elbR, U], [P.elbR, P.handR, U],
    [P.hip, P.kneeL, U * 1.1], [P.kneeL, P.footL, U * 1.1],
    [P.hip, P.kneeR, U * 1.1], [P.kneeR, P.footR, U * 1.1]
  ];
  return {
    press(mx, my) {
      for (const p of pts) {                           // an impulse, verlet-style:
        const dx = p.x - mx, dy = p.y - my;            // to change a velocity, you
        const d = len(dx, dy) + 20;                    // edit the PAST position
        p.px -= dx / d * (D.shove / d);
        p.py -= dy / d * (D.shove / d);
      }
    },
    frame(dt, t) {
      stage(); ground();
      const ax = W / 2 + Math.sin(t * D.trolley) * W * D.swing, ay = H * 0.12;   // the trolley
      for (const p of pts) {
        const vx = (p.x - p.px) * D.damp, vy = (p.y - p.py) * D.damp;
        p.px = p.x; p.py = p.y;
        p.x += vx; p.y += vy + G * dt * dt;
      }
      for (let it = 0; it < D.rounds; it++) {
        for (const c of C) {
          const a = c[0], b = c[1], rest = c[2];
          let dx = b.x - a.x, dy = b.y - a.y;
          const d = len(dx, dy) || 1;
          const adjust = (d - rest) / d / 2;           // half the error to each end
          a.x += dx * adjust; a.y += dy * adjust;
          b.x -= dx * adjust; b.y -= dy * adjust;
        }
        P.handR.x = ax; P.handR.y = ay;                // the pin wins every round
        for (const p of pts) {
          if (p.y > GY - 2) { p.y = GY - 2; p.x -= (p.x - p.px) * 0.4; }   // floor + friction
          if (p.y < 4) p.y = 4;
          if (p.x < 4) p.x = 4;
          if (p.x > W - 4) p.x = W - 4;
        }
      }
      ctx.strokeStyle = "rgba(232,229,244,0.25)";
      ctx.beginPath(); ctx.moveTo(ax, 0); ctx.lineTo(ax, ay); ctx.stroke();
      ctx.strokeStyle = BONE;
      ctx.lineWidth = 3;
      ctx.lineCap = "round";
      ctx.beginPath();
      for (const c of C) { ctx.moveTo(c[0].x, c[0].y); ctx.lineTo(c[1].x, c[1].y); }
      ctx.stroke();
      ctx.lineWidth = 1;
      ctx.lineCap = "butt";
      dot(P.head.x, P.head.y, 6.5, MOVER);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Ragdoll", "Ragtime", "the same puppet at half the gravity, jigged three times as fast by its trolley — it dances instead of dangling", { g: 1.1, trolley: 1.7, damp: 0.995 });

def("K", "Knock", "bodies", "impulses: a shockwave edits velocities once, then physics gossips — press anywhere", function (u) {
  var D = { g: 2.4, damp: 0.99, rounds: 8, friction: 0.55,
            press: 380, gust: 210, gustMin: 3.5, gustMax: 5.5,      // the impulse powers, and the gust timer
            sizes: [13, 17, 10],                                     // three crates, half-widths in px
            label: "impulse ∝ 1/distance — then constraints gossip" };
  const { ctx, W, H, GY, TAU, stage, ground, label, rand, len, BONE, HOT } = u;
  // a FORCE nags a body every frame; an IMPULSE is one hard shove — an
  // instant change of velocity — which is how games spell explosions,
  // hits, and knockback. each crate is four verlet points, four edges and
  // two diagonals (the diagonals are what make it rigid). the shockwave
  // touches nothing but velocity: closer crates inherit more of it.
  const G = H * D.g;
  function pt(x, y) { return { x: x, y: y, px: x, py: y }; }
  function box(cx, cy, s) {
    const p = [pt(cx - s, cy - s), pt(cx + s, cy - s), pt(cx + s, cy + s), pt(cx - s, cy + s)];
    const c = [];
    const pair = (i, j) => c.push([p[i], p[j], len(p[j].x - p[i].x, p[j].y - p[i].y)]);
    pair(0, 1); pair(1, 2); pair(2, 3); pair(3, 0); pair(0, 2); pair(1, 3);
    return { p: p, c: c };
  }
  const boxes = [box(W * 0.25, GY - D.sizes[0] - 1, D.sizes[0]), box(W * 0.52, GY - D.sizes[1] - 1, D.sizes[1]),
                 box(W * 0.78, GY - D.sizes[2] - 1, D.sizes[2])];
  const rings = [];
  let gustT = 2.5;
  function shock(sx, sy, power) {
    rings.push({ x: sx, y: sy, r: 4, a: 1 });
    for (const bx of boxes)
      for (const p of bx.p) {
        const dx = p.x - sx, dy = p.y - sy, d = len(dx, dy) + 30;
        p.px -= dx / d * (power / d);                  // the impulse: rewrite the past
        p.py += power / d * 0.5;                       // plus a hop (up = smaller y)
      }
  }
  return {
    press(mx, my) { shock(mx, my, D.press); },
    frame(dt, t) {
      stage(); ground();
      gustT -= dt;
      if (gustT <= 0) { gustT = rand(D.gustMin, D.gustMax); shock(rand(0, W), GY - rand(0, 30), D.gust); }
      for (const bx of boxes) {
        for (const p of bx.p) {
          const vx = (p.x - p.px) * D.damp, vy = (p.y - p.py) * D.damp;
          p.px = p.x; p.py = p.y;
          p.x += vx; p.y += vy + G * dt * dt;
        }
        for (let it = 0; it < D.rounds; it++) {
          for (const c of bx.c) {
            const a = c[0], b = c[1];
            let dx = b.x - a.x, dy = b.y - a.y;
            const d = len(dx, dy) || 1;
            const adjust = (d - c[2]) / d / 2;
            a.x += dx * adjust; a.y += dy * adjust;
            b.x -= dx * adjust; b.y -= dy * adjust;
          }
          for (const p of bx.p) {
            if (p.y > GY - 1) { p.y = GY - 1; p.x -= (p.x - p.px) * D.friction; }
            if (p.y < 4) p.y = 4;
            if (p.x < 4) p.x = 4;
            if (p.x > W - 4) p.x = W - 4;
          }
        }
        ctx.fillStyle = "rgba(138,217,245,0.14)";
        ctx.strokeStyle = BONE;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(bx.p[0].x, bx.p[0].y);
        for (let i = 1; i < 4; i++) ctx.lineTo(bx.p[i].x, bx.p[i].y);
        ctx.closePath(); ctx.fill(); ctx.stroke();
      }
      for (let i = rings.length - 1; i >= 0; i--) {
        const r = rings[i];
        r.r += 260 * dt; r.a -= 2.2 * dt;
        if (r.a <= 0) { rings.splice(i, 1); continue; }
        ctx.strokeStyle = "rgba(245,138,138," + r.a * 0.8 + ")";
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(r.x, r.y, r.r, 0, TAU); ctx.stroke();
      }
      ctx.lineWidth = 1;
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Knock", "Kaboom", "the same crates under two-and-a-half times the impulse and gusts every second or two — a demolition yard", { press: 900, gust: 480, gustMin: 1.2 });

def("X", "Xmarks", "bodies", "raycasting: where does this line first hit the world? — press to aim the beam", function (u) {
  var D = { sweep: 0.6, track: 8, sticky: 3, bounces: 1,             // idle sweep rate, aim smoothing, reflected legs
            walls: [[0.28, 0.3, 0.44, 0.52], [0.62, 0.24, 0.78, 0.3], [0.6, 0.7, 0.85, 0.62]],  // fractions of W,H
            label: "nearest hit · green normal · faint bounce" };
  const { ctx, W, H, TAU, stage, dot, arrow, label, wrapAngle, clamp, BONE, HOT, GOOD, INK } = u;
  // the ray-plane intersection, in 2D clothing (a wall is a line segment).
  // one denominator test per wall answers "does the beam cross it, and how
  // far along?" — keep the NEAREST hit. the wall's NORMAL (its direction
  // turned 90°) then powers the classic reflection  v − 2(v·n)n, which is
  // the same dot-product maths lasers, bullets, and bank shots all share.
  const segs = [[8, 8, W - 8, 8], [W - 8, 8, W - 8, H - 8], [W - 8, H - 8, 8, H - 8], [8, H - 8, 8, 8]];
  for (const w of D.walls) segs.push([W * w[0], H * w[1], W * w[2], H * w[3]]);
  const ox = W * 0.24, oy = H * 0.68;
  let aim = 0, sticky = 0, want = 0;
  function cast(px, py, dx, dy) {
    let best = null;
    for (const s of segs) {
      const sx = s[2] - s[0], sy = s[3] - s[1];
      const den = dx * sy - dy * sx;                   // parallel beams never land
      if (Math.abs(den) < 1e-9) continue;
      const tt = ((s[0] - px) * sy - (s[1] - py) * sx) / den;   // distance along the ray
      const ss = ((s[0] - px) * dy - (s[1] - py) * dx) / den;   // 0..1 along the wall
      if (tt > 0.5 && ss >= 0 && ss <= 1 && (!best || tt < best.t)) {
        let nx = -sy, ny = sx;                         // the wall, turned 90°
        const nl = Math.sqrt(nx * nx + ny * ny) || 1;
        nx /= nl; ny /= nl;
        if (nx * dx + ny * dy > 0) { nx = -nx; ny = -ny; }      // face the beam
        best = { t: tt, x: px + dx * tt, y: py + dy * tt, nx: nx, ny: ny };
      }
    }
    return best;
  }
  return {
    press(mx, my) { want = Math.atan2(my - oy, mx - ox); sticky = D.sticky; },
    frame(dt, t) {
      stage();
      sticky -= dt;
      if (sticky <= 0) want = t * D.sweep;             // the idle sweep
      aim += wrapAngle(want - aim) * Math.min(1, D.track * dt);
      ctx.strokeStyle = BONE;
      ctx.lineWidth = 2;
      ctx.beginPath();
      for (const s of segs) { ctx.moveTo(s[0], s[1]); ctx.lineTo(s[2], s[3]); }
      ctx.stroke();
      ctx.lineWidth = 1;
      const dx = Math.cos(aim), dy = Math.sin(aim);
      const hit = cast(ox, oy, dx, dy);
      if (hit) {
        ctx.strokeStyle = HOT;
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(ox, oy); ctx.lineTo(hit.x, hit.y); ctx.stroke();
        let hx = hit.x, hy = hit.y, rx = dx, ry = dy, h = hit;
        for (let b = 0; b < D.bounces && h; b++) {     // each reflected leg: v − 2(v·n)n
          const dn = rx * h.nx + ry * h.ny;
          const nrx = rx - 2 * dn * h.nx, nry = ry - 2 * dn * h.ny;
          rx = nrx; ry = nry;
          const h2 = cast(hx + rx, hy + ry, rx, ry);
          ctx.strokeStyle = "rgba(245,138,138," + 0.35 * Math.pow(0.7, b) + ")";
          ctx.beginPath(); ctx.moveTo(hx, hy);
          ctx.lineTo(h2 ? h2.x : hx + rx * 400, h2 ? h2.y : hy + ry * 400);
          ctx.stroke();
          if (h2) { hx = h2.x; hy = h2.y; }
          h = h2;
        }
        ctx.lineWidth = 1;
        arrow(hit.x, hit.y, hit.x + hit.nx * 22, hit.y + hit.ny * 22, GOOD);
        ctx.strokeStyle = INK;                         // X marks the spot
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(hit.x - 5, hit.y - 5); ctx.lineTo(hit.x + 5, hit.y + 5);
        ctx.moveTo(hit.x - 5, hit.y + 5); ctx.lineTo(hit.x + 5, hit.y - 5);
        ctx.stroke();
        ctx.lineWidth = 1;
      }
      dot(ox, oy, 6, HOT);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Xmarks", "Xtra", "the same beam reflected five times instead of once, sweeping twice as fast — a laser that fills the room", { bounces: 5, sweep: 1.3, label: "nearest hit, then v − 2(v·n)n, five legs deep" });

def("N", "Normals", "bodies", "the slope, turned 90°: a walker that hugs its terrain — press to turn it around", function (u) {
  var D = { speed: 52, base: 0.62,                                   // walker px/s, the hill's mean height
            hills: [[0.021, 0.1, 0], [0.043, 0.055, 1.3], [0.011, 0.07, 4]],   // sines: frequency, amp of H, phase
            label: "tangent (1, m) · normal (m, −1) · m = the derivative" };
  const { ctx, W, H, TAU, stage, arrow, mote, label, DIM, GOOD } = u;
  // terrain is a function y(x); its DERIVATIVE m is the slope underfoot.
  // the tangent (1, m) points along the hill, and turning it 90° gives
  // the NORMAL — the "straight up off the surface" direction that aligns
  // wheels, feet, and gun turrets to the ground they stand on. (in 3D the
  // 90° turn is done by the cross product of two surface directions.)
  const base = H * D.base;
  function terra(x) {
    let y = base;
    for (const h of D.hills) y -= Math.sin(x * h[0] + h[2]) * H * h[1];
    return y;
  }
  function slope(x) {                                  // the derivative, by hand
    let m = 0;
    for (const h of D.hills) m -= Math.cos(x * h[0] + h[2]) * H * h[1] * h[0];
    return m;
  }
  let wx = W * 0.2, dir = 1;
  return {
    press() { dir = -dir; },
    frame(dt, t) {
      stage();
      wx += dir * D.speed * dt;
      if (wx > W * 0.94) dir = -1;
      if (wx < W * 0.06) dir = 1;
      ctx.fillStyle = "rgba(150,145,190,0.13)";        // the hill itself
      ctx.strokeStyle = "rgba(201,196,228,0.55)";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, terra(0));
      for (let x = 4; x <= W; x += 4) ctx.lineTo(x, terra(x));
      ctx.stroke();
      ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath();
      ctx.fill();
      ctx.lineWidth = 1;
      const y = terra(wx), m = slope(wx);
      const tl = Math.sqrt(1 + m * m);
      const tx2 = 1 / tl, ty2 = m / tl;                // unit tangent (1, m)
      const nx = m / tl, ny = -1 / tl;                 // turned 90°: (m, −1) — up
      arrow(wx, y, wx + tx2 * 26 * dir, y + ty2 * 26 * dir, DIM);
      arrow(wx, y, wx + nx * 30, y + ny * 30, GOOD);
      mote(wx + nx * 9, y + ny * 9, Math.atan2(ty2 * dir, tx2 * dir));
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Normals", "Nomad", "twice the speed over hills twice as steep — the normal swings hard and the walker leans like a mountaineer", { speed: 105, hills: [[0.03, 0.17, 0], [0.07, 0.05, 1.3], [0.011, 0.09, 4]] });

def("G", "Gait", "bodies", "the walk that uses it all: homes, thresholds, arcs, and a shifting body — press to send it somewhere", function (u) {
  var D = { thigh: 0.17, thresh: 0.1, maxv: 0.36, bodyH: 0.27,      // bone, step trigger, top speed, hip height
            stance: 13, lift: 8, stepMax: 0.34, stepMin: 0.15, retarget: 5,
            label: "step past threshold · sin(k·π) arc · hips shift" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, label, clamp, ease, rand, BONE, MOVER, TARGET } = u;
  // procedural walking, the whole recipe:
  //   1. each foot owns a HOME under its hip, pushed ahead by velocity;
  //   2. when home drifts past a THRESHOLD from where the foot is planted
  //      — and the other foot is down — the foot steps;
  //   3. the step flies a PARABOLIC arc (sin(k·π) lift) to a predicted
  //      landing spot, faster when the walk is faster (stride timing);
  //   4. the BODY is carried BY the feet: its height bobs with the step,
  //      it leans into speed, and its hips shift over the planted foot
  //      (centre-of-gravity balancing). legs are two-bone Law-of-Cosines
  //      IK from card I. nothing here is animated by hand.
  const THIGH = H * D.thigh, THRESH = W * D.thresh, MAXV = W * D.maxv;
  let bx = W * 0.3, vx = 0, tx = W * 0.7, autoT = 0;
  const feet = [{ x: bx - D.stance, y: GY }, { x: bx + D.stance, y: GY }];
  let stepping = -1, from = 0, to = 0, k = 0, dur = 0.3;
  return {
    press(px2) { tx = clamp(px2, W * 0.08, W * 0.92); autoT = -8; },
    frame(dt, t) {
      stage(); ground();
      autoT += dt;
      if (autoT > D.retarget) { autoT = 0; tx = rand(W * 0.1, W * 0.9); }
      const want = clamp((tx - bx) * 2, -MAXV, MAXV);
      vx += (want - vx) * Math.min(1, 5 * dt);
      bx += vx * dt;
      for (let i = 0; i < 2; i++) {
        const home = bx + (i ? D.stance : -D.stance) + vx * 0.22;  // led by velocity, not dragged
        if (stepping < 0 && Math.abs(home - feet[i].x) > THRESH) {
          stepping = i; from = feet[i].x; k = 0;
          to = home + vx * 0.1;                        // land a little ahead again
          dur = clamp(D.stepMax - Math.abs(vx) / MAXV * (D.stepMax - D.stepMin), D.stepMin, D.stepMax);
        }                                              // faster walk, quicker steps — stride timing
      }
      if (stepping >= 0) {
        k += dt / dur;
        const f = feet[stepping];
        f.x = from + (to - from) * ease(k);
        f.y = GY - Math.sin(clamp(k, 0, 1) * Math.PI) * (D.lift + Math.abs(vx) * 0.05);  // the arc
        if (k >= 1) { f.y = GY; stepping = -1; }
      }
      const planted = stepping >= 0 ? feet[1 - stepping] : null;
      const shift = planted ? (planted.x - bx) * 0.35 : 0;         // weight over the
      const hipX = bx + shift;                                     // standing foot
      const bob = stepping >= 0 ? Math.sin(clamp(k, 0, 1) * Math.PI) * 3 : 0;
      const bodyY = GY - H * D.bodyH - bob;
      const lean = clamp(vx * 0.0035, -0.3, 0.3);
      for (let i = 0; i < 2; i++) {                    // two-bone IK, straight from card I
        const hx = hipX + (i ? 5 : -5), hy = bodyY + 8;
        const f = feet[i];
        let dx = f.x - hx, dy = f.y - hy;
        const d = clamp(Math.sqrt(dx * dx + dy * dy), 4, THIGH * 2 - 2);
        const half = THIGH;
        const bse = Math.atan2(dy, dx);
        const cosA = clamp((half * half + d * d - half * half) / (2 * half * d), -1, 1);
        const knee = vx >= 0 ? -1 : 1;                 // knees bend away from travel
        const a = bse + Math.acos(cosA) * knee;
        const kx = hx + Math.cos(a) * half, ky = hy + Math.sin(a) * half;
        ctx.strokeStyle = BONE;
        ctx.lineCap = "round";
        ctx.lineWidth = 3.5;
        ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(kx, ky); ctx.lineTo(f.x, f.y); ctx.stroke();
        ctx.lineWidth = 1;
        ctx.lineCap = "butt";
        dot(f.x, f.y - 1.5, 3, BONE);
      }
      ctx.save();
      ctx.translate(hipX, bodyY);
      ctx.rotate(lean);
      ctx.fillStyle = MOVER;
      ctx.beginPath(); ctx.arc(0, 0, 12, 0, TAU); ctx.fill();
      ctx.fillStyle = "#131020";
      const eye = vx >= 0 ? 4.5 : -4.5;
      ctx.beginPath(); ctx.arc(eye, -3.5, 2.4, 0, TAU); ctx.fill();
      ctx.restore();
      ring(tx, GY - 4, 5, TARGET, 1.5);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Gait", "Goliath", "longer thighs, a taller body and twice the step threshold — the same five rules walk like a lumbering giant", { thigh: 0.24, bodyH: 0.4, thresh: 0.19 });

def("G", "Grapple", "bodies", "raycast a hook to the ceiling, swing on one rope constraint, let go and fly — press to hook, again to release", function (u) {
  var D = { g: 2.2, damp: 0.995, reel: 0.25, minRope: 0.16,         // gravity ×H, verlet damping, winch ×H/s, shortest rope ×H
            swingTime: 2.4, restTime: 0.9, ceiling: 0.08,             // seconds hanging, seconds resting, ceiling y ×H
            ledges: [[0.12, 0.36, 0.38, 0.34], [0.62, 0.46, 0.9, 0.42]],   // hookable bars, fractions of W and H
            label: "raycast hook · rope |p − a| ≤ L · let go: fly" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, mote, label, rand, len, clamp, BONE, MOVER, TARGET, HOT, DIM } = u;
  // a grappling hook is three cards in a trench coat. FIRE: Xmarks' segment
  // test finds where the line from the mote to the click first meets the
  // ceiling or a ledge. HANG: the mote is one verlet point with a single
  // ROPE CONSTRAINT — whenever it drifts further than L from the anchor it
  // is pulled back to exactly L (a rope only ever pulls; slack costs
  // nothing). a winch shortens L, which is what turns a hang into a swing.
  // RELEASE: forget the anchor; the point keeps its velocity and flies
  // Jump's parabola for free. the faint circle is the swing, made visible.
  const G = H * D.g, R = 8, cy = H * D.ceiling;
  const segs = [[0, cy, W, cy]];
  for (const l of D.ledges) segs.push([W * l[0], H * l[1], W * l[2], H * l[3]]);
  let x = W * 0.3, y = GY - R, px = x, py = y;
  let hooked = false, ax = 0, ay = 0, L = 0, timer = 0, throwK = 1, miss = 0, mx2 = 0, my2 = 0;
  function cast(ox, oy, dx, dy) {                      // Xmarks' ray, one test per bar
    let best = null;
    for (const s of segs) {
      const sx = s[2] - s[0], sy = s[3] - s[1];
      const den = dx * sy - dy * sx;
      if (Math.abs(den) < 1e-9) continue;
      const tt = ((s[0] - ox) * sy - (s[1] - oy) * sx) / den;
      const ss = ((s[0] - ox) * dy - (s[1] - oy) * dx) / den;
      if (tt > 0.5 && ss >= 0 && ss <= 1 && (!best || tt < best.t)) best = { t: tt, x: ox + dx * tt, y: oy + dy * tt };
    }
    return best;
  }
  function fire(tx, ty) {
    const dx = tx - x, dy = ty - y, d = len(dx, dy) || 1;
    const hit = cast(x, y, dx / d, dy / d);
    if (!hit) { miss = 0.5; mx2 = tx; my2 = ty; return; }         // hooks need something to bite
    hooked = true; ax = hit.x; ay = hit.y; L = hit.t; timer = 0; throwK = 0;
  }
  return {
    press(mx, my) { if (hooked) { hooked = false; timer = 0; } else fire(mx, my); },
    frame(dt, t) {
      stage(); ground();
      timer += dt; miss = Math.max(0, miss - dt); throwK = Math.min(1, throwK + dt * 6);
      const cap = H * 0.06;                            // px per frame — nothing tunnels
      let vx = clamp((x - px) * D.damp, -cap, cap), vy = clamp((y - py) * D.damp, -cap, cap);
      px = x; py = y;
      x += vx; y += vy + G * dt * dt;
      if (hooked) {
        L = Math.max(H * D.minRope, L - H * D.reel * dt);          // the winch
        const dx = x - ax, dy = y - ay, d = len(dx, dy) || 1;
        if (d > L) { x = ax + dx / d * L; y = ay + dy / d * L; }   // ← the rope constraint
        if (timer > D.swingTime) { hooked = false; timer = 0; }
      }
      let floor = false;
      if (y > GY - R) { const vin = y - py; y = GY - R; py = y + vin * 0.3; px = x - (x - px) * 0.5; floor = true; }
      for (let i = 1; i < segs.length; i++) {          // ledges are one-way: land from above
        const s = segs[i];
        if (x < Math.min(s[0], s[2]) || x > Math.max(s[0], s[2])) continue;
        const ly = s[1] + (s[3] - s[1]) * (x - s[0]) / (s[2] - s[0]);
        if (py <= ly - R + 0.5 && y > ly - R) { const vin = y - py; y = ly - R; py = y + vin * 0.3; px = x - (x - px) * 0.5; floor = true; }
      }
      if (x < R) { const vin = x - px; x = R; px = x + vin * 0.5; }
      if (x > W - R) { const vin = x - px; x = W - R; px = x + vin * 0.5; }
      if (y < cy + R) { const vin = y - py; y = cy + R; py = y + vin * 0.5; }
      if (!hooked && floor && Math.abs(y - py) < 0.6 && timer > D.restTime)
        fire(clamp(x + rand(-W * 0.4, W * 0.4), W * 0.08, W * 0.92), cy);   // its own errand: hook the ceiling
      ctx.strokeStyle = BONE; ctx.lineWidth = 2.5;
      ctx.beginPath();
      for (const s of segs) { ctx.moveTo(s[0], s[1]); ctx.lineTo(s[2], s[3]); }
      ctx.stroke();
      ctx.lineWidth = 1;
      if (hooked) {
        ring(ax, ay, L, "rgba(245,193,105,0.18)");     // the swing circle: |p − a| = L
        line(x, y, x + (ax - x) * throwK, y + (ay - y) * throwK, TARGET, 1.5);
        dot(ax, ay, 3.5, TARGET);
        label("L = " + Math.round(L), (x + ax) / 2 + 8, (y + ay) / 2, "rgba(245,193,105,0.8)");
      }
      if (miss > 0) line(x, y, mx2, my2, "rgba(245,138,138," + miss + ")", 1);
      mote(x, y, len(x - px, y - py) > 0.4 ? Math.atan2(y - py, x - px) : 0);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Grapple", "Gibbon", "half the gravity, a slower winch and longer hangs — the same rope, swung the lazy way through a canopy", { g: 1.1, reel: 0.12, swingTime: 3.8 });

def("R", "Rope", "bodies", "a verlet rope: gravity, wind from noise, and eight rounds of distance constraints — drag to pull any point", function (u) {
  var D = { n: 14, seg: 0.045, rounds: 8, g: 2.4, damp: 0.995,       // links, link length ×H, solver passes, gravity ×H
            wind: 0.5, windRate: 0.7, weight: 3,                       // wind ×H/s², its noise speed, the bob's mass
            label: "8 rounds: each link splits its error in half" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, arrow, mote, label, len, clamp, noise, BONE, MOVER, DIM } = u;
  // Ragdoll's recipe, one link at a time. every point is verlet (where it is,
  // where it was); every link is a DISTANCE CONSTRAINT: measure the gap,
  // compare it with the rest length, move both ends to fix it. one pass
  // leaves the error smeared down the chain, so the solver runs eight ROUNDS
  // — each one halves what is left. the pin has infinite mass (it never
  // moves); the bob has mass 3, so it takes a quarter of each correction and
  // its light neighbour three quarters. the wind is one noise() call per link.
  const seg = H * D.seg, G = H * D.g;
  const pts = [], inv = [];
  for (let i = 0; i < D.n; i++) {
    pts.push({ x: W / 2, y: H * 0.06 + i * seg, px: W / 2, py: H * 0.06 + i * seg });
    inv.push(i === 0 ? 0 : (i === D.n - 1 ? 1 / D.weight : 1));   // inverse mass: 0 = pinned
  }
  let held = -1, hx = 0, hy = 0, hold = 0;
  return {
    drag: true,
    press(mx, my) {
      let best = 1, bd = 1e9;
      for (let i = 1; i < D.n; i++) { const d = len(pts[i].x - mx, pts[i].y - my); if (d < bd) { bd = d; best = i; } }
      held = best; hx = mx; hy = my; hold = 0.12;
    },
    frame(dt, t) {
      stage(); ground();
      hold -= dt;
      const cap = H * 0.05;
      for (let i = 1; i < D.n; i++) {
        const p = pts[i];
        const vx = clamp((p.x - p.px) * D.damp, -cap, cap), vy = clamp((p.y - p.py) * D.damp, -cap, cap);
        p.px = p.x; p.py = p.y;
        const wind = noise(t * D.windRate + i * 0.07) * H * D.wind;   // a breeze with memory
        p.x += vx + wind * dt * dt;
        p.y += vy + G * dt * dt;
      }
      for (let it = 0; it < D.rounds; it++) {
        for (let i = 0; i < D.n - 1; i++) {
          const a = pts[i], b = pts[i + 1];
          const dx = b.x - a.x, dy = b.y - a.y, d = len(dx, dy) || 1;
          const err = (d - seg) / d, wsum = inv[i] + inv[i + 1] || 1;
          a.x += dx * err * inv[i] / wsum; a.y += dy * err * inv[i] / wsum;         // the heavy end
          b.x -= dx * err * inv[i + 1] / wsum; b.y -= dy * err * inv[i + 1] / wsum; // moves less
        }
        if (held >= 0 && hold > 0) { const p = pts[held]; p.x = hx; p.y = hy; p.px = hx; p.py = hy; }
        for (let i = 1; i < D.n; i++) {
          const p = pts[i];
          if (p.y > GY - 2) { p.y = GY - 2; p.x -= (p.x - p.px) * 0.5; }
          if (p.x < 3) p.x = 3;
          if (p.x > W - 3) p.x = W - 3;
        }
      }
      const w0 = noise(t * D.windRate) * D.wind;
      arrow(W * 0.12, H * 0.1, W * 0.12 + w0 * 40, H * 0.1, DIM);
      label("wind", W * 0.12, H * 0.1 - 6, DIM, "center");
      ctx.strokeStyle = BONE; ctx.lineWidth = 2; ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      for (let i = 1; i < D.n; i++) ctx.lineTo(pts[i].x, pts[i].y);
      ctx.stroke();
      ctx.lineWidth = 1; ctx.lineCap = "butt";
      for (let i = 1; i < D.n - 1; i++) dot(pts[i].x, pts[i].y, 2, BONE);
      dot(pts[0].x, pts[0].y, 4, BONE);
      const e = pts[D.n - 1], f = pts[D.n - 2];
      mote(e.x, e.y, Math.atan2(e.y - f.y, e.x - f.x), MOVER, 7);
      if (held >= 0 && hold > 0) ring(hx, hy, 8, "rgba(245,193,105,0.7)", 1.5);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Rope", "Ribbon", "twenty-two shorter links in five times the wind — the plumb line becomes a streamer", { n: 22, seg: 0.03, wind: 2.4 });

def("N", "Ninja", "bodies", "wall-slide caps the fall; Jump's √(2gh) plus a sideways kick climbs the shaft wall to wall — press to jump now", function (u) {
  var D = { g: 2.2, jumpH: 0.26, kick: 0.55, slide: 0.12, slideG: 0.3,   // gravity ×H, apex ×H, kick ×W/s, slide cap ×H/s
            cling: 0.35, left: 0.3, right: 0.7,                          // seconds on the wall before it jumps; the shaft
            label: "slide: vy ≤ cap · jump: v₀ = √(2gh) + kick" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, rect, line, mote, label, clamp, rand, MOVER, BONE, HOT, DIM } = u;
  // the WALL-JUMP, the platformer's second verb. touching a wall while
  // falling caps the fall (a WALL-SLIDE: most of gravity cancelled by
  // friction); a jump off the wall reuses Jump's v₀ = √(2gh) upward and adds
  // a fixed horizontal KICK away from the wall — you cannot steer it, and
  // that is the feel. a press in mid-air is remembered until the next wall
  // (a JUMP BUFFER: input taken early, spent when it becomes legal). the
  // camera follows the climb, so the shaft is endless.
  const G = H * D.g, R = 8, lx = W * D.left, rx = W * D.right;
  let x = lx + R, y = GY - R * 3, vx = 0, vy = 0, onWall = -1, wallT = 0, buffered = false;
  let scroll = 0, floorY = GY, jx = 0, jy = 0, flash = 0;
  const trail = [];
  function jump(dir) {                                 // dir = +1 kicks to the right
    vy = -Math.sqrt(2 * G * H * D.jumpH);              // v₀ = √(2gh): the apex is chosen, not found
    vx = dir * W * D.kick;
    onWall = 0; wallT = 0; buffered = false; jx = x; jy = y; flash = 0.5;
  }
  return {
    press() { if (onWall) jump(-onWall); else buffered = true; },
    frame(dt, t) {
      stage();
      if (onWall && vy > 0) vy = Math.min(vy + G * D.slideG * dt, H * D.slide);   // the slide: gravity, mostly cancelled
      else vy += G * dt;
      x += vx * dt; y += vy * dt;
      if (x <= lx + R) { x = lx + R; vx = 0; if (!onWall) { onWall = -1; wallT = 0; } }
      else if (x >= rx - R) { x = rx - R; vx = 0; if (!onWall) { onWall = 1; wallT = 0; } }
      else onWall = 0;
      if (onWall) { wallT += dt; if (buffered || wallT > D.cling) jump(-onWall); }
      if (y > floorY - R) { y = floorY - R; jump(x < W / 2 ? 1 : -1); }    // the floor: leap for the far wall
      if (y < H * 0.45) {                              // the camera climbs with it
        const s = H * 0.45 - y;
        y += s; floorY += s; scroll += s; jy += s;
        for (const p of trail) p[1] += s;
      }
      flash = Math.max(0, flash - dt);
      trail.push([x, y]);
      if (trail.length > 40) trail.shift();
      rect(0, 0, lx, H, "rgba(150,145,190,0.13)");
      rect(rx, 0, W - rx, H, "rgba(150,145,190,0.13)");
      line(lx, 0, lx, H, BONE, 1.5); line(rx, 0, rx, H, BONE, 1.5);
      for (let yy = scroll % 26; yy < H; yy += 26) { line(lx - 7, yy, lx, yy, DIM); line(rx, yy, rx + 7, yy, DIM); }
      if (floorY < H + 10) ground(floorY);
      for (let i = 0; i < trail.length; i++)
        dot(trail[i][0], trail[i][1], 1.3, "rgba(138,217,245," + (i / trail.length * 0.3) + ")");
      if (onWall && vy > 0) {                          // slide dust
        for (let i = 0; i < 3; i++) dot(x + onWall * R, y + rand(-6, 6), 1.5, "rgba(232,229,244,0.45)");
        label("slide", x - onWall * 14, y + 4, DIM, onWall > 0 ? "right" : "left");
      }
      if (flash > 0) label("v₀ = √(2gh)", jx, jy - 12, "rgba(245,138,138," + flash * 1.6 + ")", "center");
      if (buffered) label("jump buffered", W / 2, H * 0.14, "rgba(245,193,105,0.8)", "center");
      mote(x, y, onWall ? (onWall > 0 ? Math.PI : 0) : Math.atan2(vy, vx));
      label("climbed " + Math.round(scroll) + " px", W / 2, 14, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Ninja", "Nitro", "jumps half again as high with nearly twice the kick and no time to cling — a rocket ricocheting up the shaft", { jumpH: 0.38, kick: 0.9, cling: 0.12 });

def("J", "Jelly", "bodies", "soft body: Ragdoll's verlet points in a ring, links to neighbours and centre, plus pressure — press to poke it", function (u) {
  var D = { n: 16, r: 0.14, g: 2.0, rounds: 4, damp: 0.985,          // ring points, radius ×H, gravity ×H, solver passes
            spoke: 0.12, pressure: 0.35,                              // pull toward the centre, area restoring
            poke: 900, pokeEvery: 2.8,                                // the impulse and the idle poke timer
            label: "neighbour links + spokes + pressure ∝ A₀/A" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, poly, label, rand, len, clamp, MOVER, DIM, HOT } = u;
  // a SOFT BODY is a ragdoll with no bones: a ring of verlet points and three
  // gentle promises. neighbours keep their distance (the skin); every point
  // is softly pulled toward the centroid (the SPOKES — soft, so the shape may
  // deform); and PRESSURE: measure the polygon's AREA with the shoelace
  // formula, and when it is smaller than at rest push every point outward —
  // that is what makes a poke on one side bulge out on the other. all three
  // are position corrections, never forces, so nothing can explode.
  const R = H * D.r, G = H * D.g, n = D.n;
  const pts = [];
  for (let i = 0; i < n; i++) {
    const a = i / n * TAU, x = W / 2 + Math.cos(a) * R, y = GY - R - 2 + Math.sin(a) * R;
    pts.push({ x: x, y: y, px: x, py: y });
  }
  const rest = len(pts[1].x - pts[0].x, pts[1].y - pts[0].y);      // the chord between neighbours
  function area() {                                    // the shoelace formula
    let s = 0;
    for (let i = 0; i < n; i++) { const a = pts[i], b = pts[(i + 1) % n]; s += a.x * b.y - b.x * a.y; }
    return Math.abs(s) / 2;
  }
  function centroid() {
    let cx = 0, cy = 0;
    for (const p of pts) { cx += p.x; cy += p.y; }
    return { x: cx / n, y: cy / n };
  }
  const A0 = area();
  let pokeT = 1.4, flash = 0, fx = 0, fy = 0;
  function poke(mx, my) {
    flash = 0.35; fx = mx; fy = my;
    for (const p of pts) {                             // Knock's impulse: edit the past
      const dx = p.x - mx, dy = p.y - my, d = len(dx, dy) + 16;
      p.px -= dx / d * (D.poke / d); p.py -= dy / d * (D.poke / d);
    }
  }
  return {
    press(mx, my) { poke(mx, my); },
    frame(dt, t) {
      stage(); ground();
      pokeT -= dt;
      if (pokeT <= 0) {                                // an idle finger, from above mostly
        pokeT = D.pokeEvery;
        const c = centroid(), a = rand(-Math.PI, 0);
        poke(c.x + Math.cos(a) * R * 1.2, c.y + Math.sin(a) * R * 1.2);
      }
      const cap = H * 0.05;
      for (const p of pts) {
        const vx = clamp((p.x - p.px) * D.damp, -cap, cap), vy = clamp((p.y - p.py) * D.damp, -cap, cap);
        p.px = p.x; p.py = p.y;
        p.x += vx; p.y += vy + G * dt * dt;
      }
      let c = centroid();
      for (let it = 0; it < D.rounds; it++) {
        for (let i = 0; i < n; i++) {                  // 1. the skin: distance constraints
          const a = pts[i], b = pts[(i + 1) % n];
          const dx = b.x - a.x, dy = b.y - a.y, d = len(dx, dy) || 1;
          const adj = (d - rest) / d / 2;
          a.x += dx * adj; a.y += dy * adj; b.x -= dx * adj; b.y -= dy * adj;
        }
        c = centroid();
        for (const p of pts) {                         // 2. the spokes: a soft pull to radius R
          const dx = p.x - c.x, dy = p.y - c.y, d = len(dx, dy) || 1;
          const k = (d - R) / d * D.spoke;
          p.x -= dx * k; p.y -= dy * k;
        }
        const push = clamp(A0 / (area() || 1) - 1, -0.5, 0.5) * D.pressure * R / D.rounds;   // 3. pressure
        for (const p of pts) {
          const dx = p.x - c.x, dy = p.y - c.y, d = len(dx, dy) || 1;
          p.x += dx / d * push; p.y += dy / d * push;
        }
        for (const p of pts) {
          if (p.y > GY - 2) { p.y = GY - 2; p.x -= (p.x - p.px) * 0.5; }
          if (p.y < 4) p.y = 4;
          if (p.x < 4) p.x = 4;
          if (p.x > W - 4) p.x = W - 4;
        }
      }
      const shape = [];
      for (const p of pts) shape.push([p.x, p.y]);
      poly(shape, "rgba(138,217,245,0.22)");
      for (let i = 0; i < n; i += 2) line(c.x, c.y, pts[i].x, pts[i].y, "rgba(232,229,244,0.12)");
      poly(shape, MOVER, 1.5);
      dot(c.x, c.y, 2, DIM);
      dot(c.x - R * 0.28, c.y - R * 0.1, R * 0.11, "#131020");    // two eyes ride the centroid
      dot(c.x + R * 0.28, c.y - R * 0.1, R * 0.11, "#131020");
      flash = Math.max(0, flash - dt);
      if (flash > 0) ring(fx, fy, 6 + (0.35 - flash) * 60, "rgba(245,138,138," + flash * 2 + ")", 1.5);
      label("A/A₀ = " + (area() / A0).toFixed(2), W / 2, 16, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Jelly", "Jumbo", "half again as big with a quarter of the spoke pull and less pressure — a waterbed that ripples for seconds", { r: 0.21, spoke: 0.03, pressure: 0.15 });

def("A", "Avalanche", "bodies", "boulders on Normals' hill: a = g·sin θ along the tangent, Motor's ω = v ÷ r, bumps bounce — press to drop one", function (u) {
  var D = { g: 2.0, e: 0.35, mu: 0.4, count: 5,                       // gravity ×H, bounce, rolling friction, boulders
            top: 0.28, bottom: 0.72,                                   // the slope's ends, ×H at x = 0 and x = W
            bumps: [[0.04, 0.03, 0], [0.09, 0.015, 1.3]],              // sines on the slope: frequency, amp ×H, phase
            rMin: 0.03, rMax: 0.06,                                    // boulder radii ×H
            label: "on the slope: a = g·sin θ · ω = v ÷ r" };
  const { ctx, W, H, TAU, stage, dot, line, arrow, label, rand, len, clamp, BONE, GOOD, DIM } = u;
  // Normals' hill, tilted, with bodies on it. each boulder carries a real
  // velocity and gravity; when it touches the surface, the NORMAL splits
  // that velocity in two: the part INTO the hill is reflected (times e —
  // mostly lost), the part ALONG the hill is kept minus a little friction.
  // gravity then supplies g·sin θ along the tangent every frame — the
  // rolling acceleration, straight from the physics classroom. the spin is
  // Motor's rule ω = v ÷ r: a wide boulder turns slowly. crests are convex,
  // so a fast rock leaves the ground there — the bounces are not scripted.
  const G = H * D.g;
  function terra(x) {
    let y = H * (D.top + (D.bottom - D.top) * x / W);
    for (const b of D.bumps) y -= Math.sin(x * b[0] + b[2]) * H * b[1];
    return y;
  }
  function slope(x) {                                  // the derivative, by hand
    let m = H * (D.bottom - D.top) / W;
    for (const b of D.bumps) m -= Math.cos(x * b[0] + b[2]) * H * b[1] * b[0];
    return m;
  }
  const rocks = [];
  function spawn(x, y, r) {
    const shape = [];
    for (let k = 0; k < 6; k++) shape.push(rand(0.8, 1.1));            // a lumpy hexagon
    rocks.push({ x: x, y: y, vx: 0, vy: 0, r: r, a: rand(0, TAU), w: 0, on: false, shape: shape });
  }
  for (let i = 0; i < D.count; i++) {
    const r = H * rand(D.rMin, D.rMax), x = W * (0.05 + i * 0.8 / D.count);
    spawn(x, terra(x) - r - H * rand(0, 0.15), r);
  }
  return {
    press(mx, my) {
      const r = H * rand(D.rMin, D.rMax);
      spawn(mx, Math.min(my, terra(mx) - r), r);
      if (rocks.length > 9) rocks.shift();
    },
    frame(dt, t) {
      stage();
      ctx.fillStyle = "rgba(150,145,190,0.13)";        // the hill
      ctx.strokeStyle = "rgba(201,196,228,0.55)";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, terra(0));
      for (let x = 4; x <= W; x += 4) ctx.lineTo(x, terra(x));
      ctx.stroke();
      ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath();
      ctx.fill();
      ctx.lineWidth = 1;
      let theta = 0;
      for (const b of rocks) {
        b.vy += G * dt;
        b.x += b.vx * dt; b.y += b.vy * dt;
        const gy = terra(b.x), m = slope(b.x), tl = Math.sqrt(1 + m * m);
        const tx = 1 / tl, ty = m / tl;                // Normals' tangent (1, m)…
        const nx = m / tl, ny = -1 / tl;               // …and normal (m, −1), pointing up
        b.on = false;
        if (b.y > gy - b.r) {
          b.y = gy - b.r;
          const vn = b.vx * nx + b.vy * ny;            // speed INTO the hill (negative = inward)
          if (vn < 0) { b.vx -= (1 + D.e) * vn * nx; b.vy -= (1 + D.e) * vn * ny; }   // reflect it, × e
          const vt = b.vx * tx + b.vy * ty;            // speed ALONG the hill
          const f = Math.max(0, 1 - D.mu * dt) - 1;    // rolling friction, a small bite
          b.vx += tx * vt * f; b.vy += ty * vt * f;
          b.w = vt / b.r;                              // ω = v ÷ r
          b.on = true;
          theta = Math.atan(m);
        }
        const sp = len(b.vx, b.vy), cap = H * 3;
        if (sp > cap) { b.vx *= cap / sp; b.vy *= cap / sp; }
        b.a += b.w * dt;
        if (b.x > W + b.r * 2 || b.y > H + 40) {       // off the bottom: back to the top
          b.x = -b.r; b.y = terra(0) - b.r - H * 0.12; b.vx = 0; b.vy = 0; b.w = 0;
        }
        ctx.strokeStyle = BONE; ctx.fillStyle = "rgba(201,196,228,0.22)"; ctx.lineWidth = 1.5;
        ctx.beginPath();
        for (let k = 0; k < 6; k++) {
          const an = b.a + k / 6 * TAU, rr = b.r * b.shape[k];
          if (k) ctx.lineTo(b.x + Math.cos(an) * rr, b.y + Math.sin(an) * rr);
          else ctx.moveTo(b.x + Math.cos(an) * rr, b.y + Math.sin(an) * rr);
        }
        ctx.closePath(); ctx.fill(); ctx.stroke();
        ctx.lineWidth = 1;
        line(b.x, b.y, b.x + Math.cos(b.a) * b.r * b.shape[0], b.y + Math.sin(b.a) * b.r * b.shape[0], DIM);  // the spoke shows the spin
        if (b.on) arrow(b.x - nx * b.r, b.y - ny * b.r, b.x - nx * b.r + nx * 14, b.y - ny * b.r + ny * 14, GOOD);
      }
      label("θ = " + Math.round(theta * 180 / Math.PI) + "°  ·  e = " + D.e, W - 8, 14, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Avalanche", "Alpine", "a slope twice as steep and twice the restitution — the same rocks leap where they used to roll", { top: 0.12, bottom: 0.88, e: 0.75 });

def("K", "Kite", "bodies", "Rope's string, lift = wind² · sin(angle of attack), a follow-chain tail — press to gust from your click", function (u) {
  var D = { n: 9, seg: 0.06, rounds: 6, g: 1.6, damp: 0.99,           // string links, link ×H, passes, the kite's gravity ×H
            wind: 0.5, gustiness: 0.35, lift: 40, bridle: 0.55,       // wind ×W/s, noise speed, lift gain, face tilt (rad)
            gust: 1.2, tail: 7,                                        // press gust ×W/s, tail links
            label: "F = k·|w|²·sin α along the face normal" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, poly, arrow, mote, label, len, clamp, noise, BONE, MOVER, GOOD, DIM } = u;
  // a flat plate in a wind feels one force, along its own NORMAL, of size
  // k·|w|²·sin α — α being the ANGLE OF ATTACK between the apparent wind
  // (the wind minus the kite's own velocity) and the plate. the part of
  // that force across the wind is LIFT, the part along it is DRAG: one
  // formula, both words. the BRIDLE tilts the plate a fixed angle off the
  // string, so the string (Rope's verlet chain, pinned in the flyer's
  // hand) always presents the face to the wind — and the string's pull is
  // what holds it up there; let go and it would just blow away. the tail
  // is Tentacle's follow-chain: it only remembers where the kite has been.
  const seg = H * D.seg, G = H * D.g, n = D.n;
  const hx = W * 0.22, hy = GY - 14;                   // the hand
  const pts = [];
  for (let i = 0; i < n; i++) {
    const x = hx + i * seg * 0.7, y = hy - i * seg * 0.7;
    pts.push({ x: x, y: y, px: x, py: y });
  }
  const tail = [];
  for (let i = 0; i < D.tail; i++) tail.push({ x: pts[n - 1].x - i * 6, y: pts[n - 1].y });
  let gx = 0, gy2 = 0, gustT = 0, alpha = 0, fmag = 0, nx = 0, ny = -1;
  return {
    press(mx, my) {
      const k = pts[n - 1], dx = k.x - mx, dy = k.y - my, d = len(dx, dy) || 1;
      gx = dx / d; gy2 = dy / d; gustT = 1;            // a gust blowing from the click toward the kite
    },
    frame(dt, t) {
      stage(); ground();
      gustT = Math.max(0, gustT - dt);
      const wx = W * D.wind * (1 + 0.25 * noise(t * D.gustiness)) + gx * W * D.gust * gustT;
      const wy = W * D.wind * 0.12 * noise(t * D.gustiness + 9) + gy2 * W * D.gust * gustT;
      const kite = pts[n - 1];
      const kvx = (kite.x - kite.px) / dt, kvy = (kite.y - kite.py) / dt;   // the kite's own velocity, px/s
      const ax = wx - kvx, ay = wy - kvy, al = len(ax, ay) || 1;            // the APPARENT wind
      let ux = kite.x - hx, uy = kite.y - hy; const ul = len(ux, uy) || 1; ux /= ul; uy /= ul;   // the string, hand to kite
      const cb = Math.cos(D.bridle), sb = Math.sin(D.bridle);
      nx = ux * cb + uy * sb; ny = -ux * sb + uy * cb;                       // the face normal: the string, tilted up by the bridle
      const sinA = (ax * nx + ay * ny) / al;                                 // sin α = â · n
      alpha = Math.asin(clamp(sinA, -1, 1));
      const F = D.lift * H * al * al * sinA / (W * W);                       // k·|w|²·sin α, as an acceleration
      fmag = F;
      const cap = H * 0.05;
      for (let i = 1; i < n; i++) {
        const p = pts[i], last = i === n - 1;
        const vx = clamp((p.x - p.px) * D.damp, -cap, cap), vy = clamp((p.y - p.py) * D.damp, -cap, cap);
        p.px = p.x; p.py = p.y;
        p.x += vx + (last ? F * nx : wx * 0.1) * dt * dt;                    // string links: a whisper of drag…
        p.y += vy + (last ? F * ny + G : G * 0.06) * dt * dt;                // …and almost no weight
      }
      for (let it = 0; it < D.rounds; it++) {
        for (let i = 0; i < n - 1; i++) {              // Rope's distance constraints
          const a = pts[i], b = pts[i + 1];
          const dx = b.x - a.x, dy = b.y - a.y, d = len(dx, dy) || 1;
          const err = (d - seg) / d;
          if (i === 0) { b.x -= dx * err; b.y -= dy * err; }
          else { a.x += dx * err / 2; a.y += dy * err / 2; b.x -= dx * err / 2; b.y -= dy * err / 2; }
        }
        for (let i = 1; i < n; i++) {
          const p = pts[i];
          if (p.y > GY - 3) { p.y = GY - 3; p.x -= (p.x - p.px) * 0.5; }
          if (p.y < 4) p.y = 4;
          if (p.x < 4) p.x = 4;
          if (p.x > W - 4) p.x = W - 4;
        }
      }
      tail[0].x = kite.x; tail[0].y = kite.y;
      for (let i = 1; i < tail.length; i++) {          // Tentacle's follow-chain, blown downwind
        const s = tail[i], p = tail[i - 1];
        s.x += wx * 0.25 * dt; s.y += (G * 0.15 + Math.sin(t * 5 - i) * 20) * dt;
        const a = Math.atan2(s.y - p.y, s.x - p.x);
        s.x = p.x + Math.cos(a) * 6; s.y = p.y + Math.sin(a) * 6;
      }
      arrow(W * 0.1, H * 0.1, W * 0.1 + wx * 0.12, H * 0.1 + wy * 0.12, DIM);
      label("wind", W * 0.1, H * 0.1 - 6, DIM, "center");
      ctx.strokeStyle = BONE; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y);
      for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y);
      ctx.stroke();
      ctx.strokeStyle = "rgba(245,138,138,0.6)";
      ctx.beginPath(); ctx.moveTo(tail[0].x, tail[0].y);
      for (let i = 1; i < tail.length; i++) ctx.lineTo(tail[i].x, tail[i].y);
      ctx.stroke();
      const fx = -ny, fy = nx, r1 = H * 0.05, r2 = H * 0.03;          // the face runs across the normal
      poly([[kite.x + fx * r1, kite.y + fy * r1], [kite.x + nx * r2, kite.y + ny * r2],
            [kite.x - fx * r1, kite.y - fy * r1], [kite.x - nx * r2, kite.y - ny * r2]], MOVER);
      arrow(kite.x, kite.y, kite.x + nx * F * 0.08, kite.y + ny * F * 0.08, GOOD);   // the force, along n
      label("α = " + Math.round(alpha * 180 / Math.PI) + "°", kite.x + 14, kite.y - 10, "rgba(155,226,138,0.8)");
      mote(hx, hy + 6, Math.atan2(pts[1].y - hy, pts[1].x - hx) * 0.3, MOVER, 7);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Kite", "Kestrel", "a stronger, steadier wind on a longer string — it hangs high and hardly stirs, like a hovering hawk", { wind: 0.85, gustiness: 0.06, seg: 0.08 });

def("N", "Newton", "bodies", "five Pendulums; bobs that touch and approach swap velocity, Knock's impulse at e ≈ 1 — press to lift a ball", function (u) {
  var D = { n: 5, g: 3.0, L: 0.45, r: 0.05, e: 0.98, damp: 0.12,      // bobs, gravity ×H, string ×H, bob ×H, restitution, air
            lift: 1.1, every: 7,                                       // the lift angle (rad) and the idle re-lift timer
            label: "touch + approach → swap v · e = 0.98" };
  const { ctx, W, H, TAU, stage, dot, ring, line, label, rand, len, clamp, BONE, MOVER, HOT, DIM } = u;
  // five Pendulums that can touch. each integrates α = −(g/L)·sin θ on its
  // own; the cradle is one extra rule between neighbours: if two bobs
  // OVERLAP and are APPROACHING, exchange their velocities (Knock's impulse,
  // written out for equal masses and a RESTITUTION e):
  //   v₁' = ((1−e)·v₁ + (1+e)·v₂) / 2     v₂' = ((1+e)·v₁ + (1−e)·v₂) / 2
  // at e = 1 that is a clean swap, which is why one ball in sends exactly
  // one ball out: a chain of swaps carries the speed through the middle
  // bobs in a single frame. sub-steps keep any bob from tunnelling past
  // its neighbour between two checks.
  const n = D.n, r = H * D.r, L = H * D.L, py = H * 0.14, G = H * D.g;
  const th = [], om = [], flash = [];
  for (let i = 0; i < n; i++) { th.push(0); om.push(0); flash.push(0); }
  function px(i) { return W / 2 + (i - (n - 1) / 2) * 2 * r; }        // pivots one diameter apart
  let idle = 0;
  function liftBall(i) {                               // an outer ball, plus everything between it and the edge
    if (i >= n / 2) for (let j = i; j < n; j++) { th[j] = D.lift; om[j] = 0; }
    else for (let j = 0; j <= i; j++) { th[j] = -D.lift; om[j] = 0; }
    idle = 0;
  }
  liftBall(0);
  return {
    press(mx, my) {
      let best = 0, bd = 1e9;
      for (let i = 0; i < n; i++) { const d = Math.abs(px(i) + Math.sin(th[i]) * L - mx); if (d < bd) { bd = d; best = i; } }
      liftBall(best);
    },
    frame(dt, t) {
      stage();
      idle += dt;
      if (idle > D.every) liftBall(rand(0, 1) < 0.5 ? 0 : (rand(0, 1) < 0.5 ? 1 : n - 1));
      const steps = Math.ceil(dt / 0.006), h = dt / steps;
      for (let s = 0; s < steps; s++) {
        for (let i = 0; i < n; i++) {
          om[i] += (-(G / L) * Math.sin(th[i]) - D.damp * om[i]) * h;   // Pendulum's true equation
          th[i] += om[i] * h;
        }
        for (let i = 0; i < n - 1; i++) {
          const xi = px(i) + Math.sin(th[i]) * L, xj = px(i + 1) + Math.sin(th[i + 1]) * L;
          const gap = xj - xi - 2 * r;
          if (gap < 0) {
            const dA = -gap / L / 2;                   // un-overlap, half each
            th[i] -= dA; th[i + 1] += dA;
            if (om[i] > om[i + 1]) {                   // approaching: the impulse swap
              const a = om[i], b = om[i + 1];
              om[i] = ((1 - D.e) * a + (1 + D.e) * b) / 2;
              om[i + 1] = ((1 + D.e) * a + (1 - D.e) * b) / 2;
              if (Math.abs(a - b) > 0.3) flash[i] = 0.25;
            }
          }
        }
      }
      line(px(0) - r * 1.6, py, px(n - 1) + r * 1.6, py, BONE, 2.5);
      for (let i = 0; i < n; i++) {
        const bx = px(i) + Math.sin(th[i]) * L, by = py + Math.cos(th[i]) * L;
        line(px(i), py, bx, by, "rgba(201,196,228,0.7)", 1);
        dot(bx, by, r, MOVER);
        dot(bx - r * 0.3, by - r * 0.3, r * 0.22, "rgba(255,255,255,0.35)");
        if (i < n - 1 && flash[i] > 0) {
          flash[i] -= dt;
          ring(bx + r, by, 4 + (0.25 - flash[i]) * 50, "rgba(245,138,138," + flash[i] * 3 + ")", 1.5);
        }
      }
      label("α = −(g/L)·sin θ", W - 8, py + 14, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Newton", "Nougat", "soft bobs: half the restitution and four times the air drag — the clack becomes a squelch and the row swings together", { e: 0.45, damp: 0.5, lift: 0.8, label: "touch + approach → blend v · e = 0.45" });

def("P", "Pinball", "bodies", "gravity, Xmarks' reflection off two turning flippers plus their tip speed, Knock's bumpers — press to flip", function (u) {
  var D = { g: 1.6, e: 0.6, bump: 1.4, r: 0.03,                       // gravity ×H, wall bounce, bumper kick ×H/s, ball ×H
            flipLen: 0.17, rest: 0.5, swing: 1.05, flipSpeed: 14, hold: 0.25,   // flippers: ×W, rest angle, travel, rad/s, seconds up
            bumpers: [[0.32, 0.3, 0.05], [0.62, 0.22, 0.05], [0.5, 0.46, 0.04]],  // x ×W, y ×H, radius ×H
            label: "v − (1+e)(v·n)n + the flipper's tip speed" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, arrow, label, rand, len, clamp, BONE, MOVER, TARGET, HOT, GOOD, DIM } = u;
  // Xmarks' reflection with a moving mirror. a FLIPPER is a rotating
  // segment: the ball finds the CLOSEST POINT on it, and if it is inside,
  // the normal n runs from that point to the ball. the trick that makes
  // flippers hit: reflect the ball's velocity RELATIVE to the surface (v
  // minus the flipper's own speed at the contact, ω × arm) and add the
  // surface speed back — a tip moving at 14 rad/s on a long arm flings
  // hard. bumpers are Knock: a fixed impulse away along the normal. the
  // frame is sub-stepped so a fast ball cannot tunnel through a flipper.
  const G = H * D.g, R = H * D.r, flen = W * D.flipLen;
  const left = W * 0.08, right = W * 0.92, top = H * 0.04, fy = GY - H * 0.16;
  const segs = [                                       // static rails + two flippers (w = angular speed)
    { x: left, y: GY - H * 0.3, tx: W * 0.3, ty: fy, w: 0, s: 0 },
    { x: right, y: GY - H * 0.3, tx: W * 0.7, ty: fy, w: 0, s: 0 },
    { x: W * 0.3, y: fy, tx: 0, ty: 0, w: 0, s: 1, a: D.rest },
    { x: W * 0.7, y: fy, tx: 0, ty: 0, w: 0, s: -1, a: D.rest }
  ];
  const bumps = [];
  for (const b of D.bumpers) bumps.push({ x: W * b[0], y: H * b[1], r: H * b[2], hit: 0 });
  let bx = W * 0.85, by = H * 0.12, vx = 0, vy = 0, holdT = -1, nT = 0, nx = 0, ny = 0, hx = 0, hy = 0, drains = 0;
  function spawn() { bx = W * 0.85; by = H * 0.12; vx = rand(-W * 0.12, W * 0.04); vy = 0; }
  return {
    press() { holdT = D.hold; },
    frame(dt, t) {
      stage();
      holdT -= dt; nT = Math.max(0, nT - dt);
      const want = holdT > 0 ? D.rest - D.swing : D.rest;
      for (const f of segs) if (f.s) {
        const prev = f.a;
        f.a += clamp(want - f.a, -D.flipSpeed * dt, D.flipSpeed * dt);
        f.w = (f.a - prev) / dt;                       // the flipper's angular speed
        f.tx = f.x + f.s * Math.cos(f.a) * flen; f.ty = f.y + Math.sin(f.a) * flen;
      }
      if (holdT < -0.35 && vy > 0) for (const f of segs) if (f.s) {   // its own reflexes: flip when the ball
        const ex = f.tx - f.x, ey = f.ty - f.y;                       // is over the fast, outer part of the arm
        const k = ((bx - f.x) * ex + (by - f.y) * ey) / (ex * ex + ey * ey || 1);
        if (k > 0.45 && k < 1.3 && by > f.y - H * 0.16 && by < f.ty + R) holdT = D.hold;
      }
      const steps = Math.ceil(dt / 0.008), h = dt / steps;
      for (let s = 0; s < steps; s++) {
        vy += G * h; bx += vx * h; by += vy * h;
        if (bx < left + R) { bx = left + R; vx = -vx * D.e; }
        if (bx > right - R) { bx = right - R; vx = -vx * D.e; }
        if (by < top + R) { by = top + R; vy = -vy * D.e; }
        for (const b of bumps) {                       // Knock: an impulse away along n
          const dx = bx - b.x, dy = by - b.y, d = len(dx, dy) || 1;
          if (d < b.r + R) {
            const kx = dx / d, ky = dy / d, vn = vx * kx + vy * ky, kick = H * D.bump;
            bx = b.x + kx * (b.r + R); by = b.y + ky * (b.r + R);
            if (vn < kick) { vx += (kick - vn) * kx; vy += (kick - vn) * ky; }
            b.hit = 0.2; nx = kx; ny = ky; hx = bx; hy = by; nT = 0.3;
          }
        }
        for (const f of segs) {                        // Xmarks' reflection, moving mirror
          const ex = f.tx - f.x, ey = f.ty - f.y, el = ex * ex + ey * ey || 1;
          const k = clamp(((bx - f.x) * ex + (by - f.y) * ey) / el, 0, 1);
          const cx = f.x + ex * k, cy = f.y + ey * k;
          const dx = bx - cx, dy = by - cy, d = len(dx, dy) || 1;
          if (d < R + 2.5) {
            const kx = dx / d, ky = dy / d;
            bx = cx + kx * (R + 2.5); by = cy + ky * (R + 2.5);
            const ws = f.s * f.w;                            // the mirrored flipper turns the other way
            const sx = -ws * (cy - f.y), sy = ws * (cx - f.x);   // surface speed: ω × arm
            const rx = vx - sx, ry = vy - sy, vn = rx * kx + ry * ky;
            if (vn < 0) {
              vx = rx - (1 + D.e) * vn * kx + sx;      // reflect the relative velocity, add the surface back
              vy = ry - (1 + D.e) * vn * ky + sy;
              nx = kx; ny = ky; hx = bx; hy = by; nT = 0.3;
            }
          }
        }
        const sp = len(vx, vy), cap = H * 3;
        if (sp > cap) { vx *= cap / sp; vy *= cap / sp; }
      }
      if (by > GY + R) { spawn(); drains++; }          // the drain: a new ball
      ground();
      line(left, top, left, GY - H * 0.3, BONE, 1.5); line(right, top, right, GY - H * 0.3, BONE, 1.5);
      line(left, top, right, top, BONE, 1.5);
      for (const f of segs) {
        ctx.strokeStyle = f.s ? BONE : "rgba(201,196,228,0.6)"; ctx.lineWidth = f.s ? 5 : 1.5; ctx.lineCap = "round";
        ctx.beginPath(); ctx.moveTo(f.x, f.y); ctx.lineTo(f.tx, f.ty); ctx.stroke();
        ctx.lineWidth = 1; ctx.lineCap = "butt";
        if (f.s) dot(f.x, f.y, 3, DIM);
      }
      for (const b of bumps) {
        b.hit = Math.max(0, b.hit - dt);
        if (b.hit > 0) dot(b.x, b.y, b.r, "rgba(245,138,138," + b.hit * 3 + ")");
        ring(b.x, b.y, b.r, TARGET, 1.5);
        dot(b.x, b.y, 2, TARGET);
      }
      if (nT > 0) arrow(hx, hy, hx + nx * 18, hy + ny * 18, GOOD);
      dot(bx, by, R, MOVER);
      dot(bx - R * 0.3, by - R * 0.3, R * 0.25, "rgba(255,255,255,0.4)");
      label("drained ×" + drains, W - 10, 16, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Pinball", "Pachinko", "a lighter, bouncier ball and bumpers with twice the kick — it lives up among the bumpers and rarely comes down", { g: 0.9, e: 0.9, bump: 2.6 });

def("Y", "Yoyo", "bodies", "free fall until the string is taut, then Rope's constraint; Motor's ω = v ÷ r, sleep, reel — press to throw", function (u) {
  var D = { len: 0.5, r: 0.045, g: 2.4, throw: 0.9, damp: 0.995,       // string ×H, disc ×H, gravity ×H, throw ×H/s
            sleep: 2.2, sleepDrag: 0.35, reel: 0.5, wait: 0.8,           // seconds asleep, spin decay, reel ×H/s, seconds held
            flick: 0.3,                                                  // a sideways flick at the throw ×H/s
            bob: 0.03, bobRate: 2.2,                                     // the hand rides Hover's sine
            label: "fall → taut: |p − h| ≤ L · ω = v ÷ r · sleep" };
  const { ctx, W, H, TAU, stage, dot, ring, line, mote, label, len, clamp, BONE, MOVER, TARGET, HOT, DIM } = u;
  // a yo-yo is Rope's constraint with a length that changes on a schedule.
  // THROW: the disc leaves the hand with a downward velocity and L opens to
  // the full string — free fall, the speed becoming spin at ω = v ÷ r (the
  // string unwinding off the axle: Motor's rule, read backwards). TAUT: the
  // moment |p − h| would pass L the rope constraint catches it — a jolt,
  // then a hang. SLEEP: it spins at the bottom, losing ω slowly, swinging
  // under the hand. REEL: L shrinks at a steady rate and the disc climbs
  // (the axle winding the string back in). the hand bobs on Hover's sine.
  const G = H * D.g, r = H * D.r, Lmax = H * D.len, hx = W / 2;
  let hy = H * 0.12, x = hx, y = hy + r, px = x, py = y, L = 0, state = "held", timer = 0, spin = 0, om = 0, lastDt = 1 / 60, jolt = 0, side = 1;
  function throwIt() { state = "fall"; L = Lmax; py = y - H * D.throw * lastDt; px = x - side * H * D.flick * lastDt; side = -side; timer = 0; }
  return {
    press() { if (state === "held") throwIt(); else if (state === "sleep") { state = "reel"; timer = 0; } },
    frame(dt, t) {
      stage();
      lastDt = dt; timer += dt; jolt = Math.max(0, jolt - dt);
      hy = H * 0.12 + Math.sin(t * D.bobRate) * H * D.bob;
      if (state === "held") { x = hx; y = hy + r; px = x; py = y; if (timer > D.wait) throwIt(); }
      else {
        const cap = H * 0.06;
        const vx = clamp((x - px) * D.damp, -cap, cap), vy = clamp((y - py) * D.damp, -cap, cap);
        px = x; py = y;
        x += vx; y += vy + G * dt * dt;
        if (state === "fall") om = Math.abs(y - py) / dt / r;             // ω = v ÷ r, unwinding
        if (state === "reel") { L = Math.max(0, L - H * D.reel * dt); om = H * D.reel / r; }
        if (state === "sleep") { om *= Math.exp(-D.sleepDrag * dt); if (timer > D.sleep) { state = "reel"; timer = 0; } }
        const dx = x - hx, dy = y - hy, d = len(dx, dy) || 1;
        if (d > L) {                                   // ← the rope constraint, |p − h| ≤ L
          x = hx + dx / d * L; y = hy + dy / d * L;
          if (state === "fall") { state = "sleep"; timer = 0; jolt = 0.3; }
        }
        if (state === "reel" && L <= r) { state = "held"; timer = 0; om = 0; }
        if (y > H - r) { y = H - r; py = y; }
        if (x < r) x = r; if (x > W - r) x = W - r;
      }
      spin += om * dt;
      if (state !== "held") ring(hx, hy, L, "rgba(232,229,244,0.08)");   // the reach of the string
      mote(hx, hy - 12, 0, MOVER, 8);
      line(hx, hy, x, y - r * 0.4, BONE, 1);
      dot(x, y, r, MOVER);
      ring(x, y, r * 0.72, "rgba(19,16,32,0.55)", 1.5);
      line(x + Math.cos(spin) * r * 0.85, y + Math.sin(spin) * r * 0.85, x - Math.cos(spin) * r * 0.85, y - Math.sin(spin) * r * 0.85, "#131020", 2);
      line(x + Math.cos(spin + 1.571) * r * 0.85, y + Math.sin(spin + 1.571) * r * 0.85, x - Math.cos(spin + 1.571) * r * 0.85, y - Math.sin(spin + 1.571) * r * 0.85, "#131020", 2);
      dot(x, y, r * 0.18, TARGET);                     // the axle
      if (jolt > 0) ring(x, y, r + (0.3 - jolt) * 60, "rgba(245,138,138," + jolt * 2.5 + ")", 1.5);
      label(state + "  ·  ω = " + Math.round(om) + " rad/s", x + r + 8, y + 4, state === "sleep" ? "rgba(201,160,245,0.9)" : DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Yoyo", "Yonder", "a third of the gravity, twice the nap and half the reel — it drops like a feather and dozes at the bottom", { g: 0.9, sleep: 4.5, reel: 0.25 });

/* ============================== TIME & CAMERAS ==============================
   The clock and the window are part of the motion too. Every card so far
   trusted dt; these bend it — scale it, freeze it, chop it into fixed steps,
   deliver it late, quantise it — and move the camera that frames it all.
   The reader's question, answered on camera: slower motion is NOT more
   frames. Frames are drawn at the same rate whatever happens; only the dt
   each frame feeds the simulation changes. Count the frames and see. */

def("C", "Camera", "time", "a camera with a dead zone and look-ahead follows the mote through a wider world — press to send it somewhere", function (u) {
  var D = { world: 3.2,        // the world is this many screens wide
            look: 0.2,         // LOOK-AHEAD at full speed, as a fraction of W
            dead: 0.08,        // half-width of the DEAD ZONE, as a fraction of W
            omega: 6,          // the camera spring, critically damped, this fast
            speed: 0.6,        // top speed of the mote, in screens per second
            label: "focus = mote + look-ahead · dead zone ±" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, rect, poly, arrow, mote, label, rng, rand, clamp, MOVER, TARGET, GOOD, BONE, DIM } = u;
  // a CAMERA is a point with manners. it wants a FOCUS a little ahead of the
  // mote (look-ahead: show where you are going, not where you were), it
  // ignores wobbles inside a DEAD ZONE, and it closes the rest of the gap
  // with card D's critically damped spring — ζ = 1, the one that never
  // overshoots. the world scrolls; the camera is the thing that stays put.
  // the strip at the top is the whole world; the little box is the window.
  const WORLD = W * D.world;
  const seed = rng(7);                                 // the same landmarks on every machine
  const marks = [];
  for (let i = 0; i < 28; i++) marks.push({ x: seed() * WORLD, h: 10 + seed() * H * 0.16, tree: seed() < 0.6 });
  let mx = W * 0.5, vx = 0, tx = W * 1.8, autoT = 0;
  let cx = mx, cv = 0;                                 // the camera: a world x, and a velocity
  return {
    press(px, py) { tx = clamp(cx - W / 2 + px, W * 0.1, WORLD - W * 0.1); autoT = -6; },
    frame(dt, t) {
      stage();
      autoT += dt;
      if (autoT > 4.5) { autoT = 0; tx = rand(W * 0.1, WORLD - W * 0.1); }
      const maxv = W * D.speed;
      const want = clamp((tx - mx) * 2.5, -maxv, maxv);
      vx += (want - vx) * Math.min(1, 4 * dt);
      mx += vx * dt;
      const look = (vx / maxv) * W * D.look;           // ahead, in the direction of travel
      const focus = mx + look;
      const dz = W * D.dead;
      let goal = cx;                                   // inside the dead zone: stay put
      if (focus > cx + dz) goal = focus - dz;          // outside it: move just enough
      if (focus < cx - dz) goal = focus + dz;          //   to re-contain the focus
      goal = clamp(goal, W / 2, WORLD - W / 2);        // never show past the world's edge
      const w = D.omega;
      cv += (w * w * (goal - cx) - 2 * w * cv) * dt;   // ζ = 1: the camera never overshoots
      cx += cv * dt;
      const sx = x => x - cx + W / 2;                  // world → screen: the whole scroll
      ground();
      for (const m of marks) {
        const x = sx(m.x);
        if (x < -20 || x > W + 20) continue;
        if (m.tree) { line(x, GY, x, GY - m.h * 0.45, BONE, 2); poly([[x - 7, GY - m.h * 0.4], [x + 7, GY - m.h * 0.4], [x, GY - m.h]], GOOD); }
        else rect(x - 3, GY - m.h * 0.6, 6, m.h * 0.6, BONE);
      }
      poly([[W / 2 - dz, H * 0.26], [W / 2 + dz, H * 0.26], [W / 2 + dz, GY], [W / 2 - dz, GY]], "rgba(245,193,105,0.35)", true);
      label("dead zone", W / 2, H * 0.24, "rgba(245,193,105,0.6)", "center");
      arrow(sx(mx), GY - 34, sx(focus), GY - 34, TARGET);
      if (Math.abs(look) > 8) label("look-ahead", sx(focus), GY - 40, "rgba(245,193,105,0.8)", "center");
      ring(sx(tx), GY - 4, 5, TARGET, 1.5);
      const bob = Math.abs(Math.sin(t * 11)) * Math.abs(vx) / maxv * 4;
      mote(sx(mx), GY - 10 - bob, vx < 0 ? Math.PI : 0);
      const bw = W * 0.8, bx0 = W * 0.1, by0 = 12;     // the minimap: the world, and the window
      line(bx0, by0, bx0 + bw, by0, DIM, 1);
      const winL = bx0 + (cx - W / 2) / WORLD * bw, winW = W / WORLD * bw;
      poly([[winL, by0 - 5], [winL + winW, by0 - 5], [winL + winW, by0 + 5], [winL, by0 + 5]], "rgba(232,229,244,0.5)", true);
      dot(bx0 + mx / WORLD * bw, by0, 2.5, MOVER);
      dot(bx0 + tx / WORLD * bw, by0, 2, TARGET);
      label(D.label + Math.round(dz) + " px", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Camera", "Cinematic", "a long look-ahead, no dead zone and a lazy spring — the wide, drifting follow of a film camera", { look: 0.34, dead: 0.005, omega: 2.5 });

def("H", "Hitstop", "time", "on impact the pair's clock stops for 100 ms; inside the bubble dt is ×0.2 — press to change the freeze length", function (u) {
  var D = { freezes: [0.1, 0.25, 0.5],   // the freeze lengths the press cycles through, seconds
            speed: 0.55,                 // approach speed, in screens per second
            bubble: 0.2,                 // dt multiplier inside the slow-mo bubble
            radius: 0.17,                // the bubble radius, as a fraction of W
            label: "hit: pair dt = 0 · bubble: dt × " };
  const { ctx, W, H, TAU, stage, dot, ring, line, mote, label, MOVER, HOT, MAGIC, GOOD, DIM } = u;
  // HITSTOP is the fighting-game trick: the moment two things hit, THEIR
  // clock stops for a tenth of a second while the world keeps going. nothing
  // is drawn differently — the pair simply receives dt = 0 — and the pause
  // reads as weight. the bubble is the gentler cousin: dt × 0.2 for anything
  // inside a radius. bullet time is a LOCAL TIME SCALE, not a global one; the
  // two clocks at the top drift apart by exactly the frozen seconds.
  const R = 9;
  let fi = 0, ax = R + 4, bx = W - R - 4, va = 1, vb = -1, freeze = 0, pairT = 0, hits = 0, spark = 0;
  const lane = [0, 1 / 3, 2 / 3].map(k => ({ x: W * k }));
  return {
    press() { fi = (fi + 1) % D.freezes.length; },
    frame(dt, t) {
      stage();
      const y1 = H * 0.32, y2 = H * 0.74;
      const v = W * D.speed;
      let pdt = dt;                                    // the pair's own dt
      if (freeze > 0) { freeze -= dt; pdt = 0; }       // ← the whole trick: dt = 0 for the pair
      pairT += pdt;
      ax += va * v * pdt; bx += vb * v * pdt;
      if (va > 0 && vb < 0 && bx - ax <= R * 2) {      // contact while approaching = a hit
        const mid = (ax + bx) / 2; ax = mid - R; bx = mid + R;
        va = -1; vb = 1; freeze = D.freezes[fi]; hits++; spark = 1;
      }
      if (ax < R + 4) va = 1;                          // back from the edges for another round
      if (bx > W - R - 4) vb = -1;
      spark = Math.max(0, spark - pdt * 3);            // the spark lives on the pair's clock too
      line(0, y1 + R + 3, W, y1 + R + 3, DIM, 1);
      mote(ax, y1, 0, MOVER);
      mote(bx, y1, Math.PI, HOT);
      if (spark > 0) {
        const mx = (ax + bx) / 2, sl = 6 + (1 - spark) * 10;
        for (let i = 0; i < 8; i++) {
          const an = i / 8 * TAU + 0.3;
          line(mx + Math.cos(an) * 4, y1 + Math.sin(an) * 4, mx + Math.cos(an) * sl, y1 + Math.sin(an) * sl, "rgba(245,138,138," + spark + ")", 2);
        }
      }
      if (freeze > 0) label("dt = 0 · " + Math.round(freeze * 1000) + " ms left", (ax + bx) / 2, y1 - 22, HOT, "center");
      label("world t " + t.toFixed(1) + " s", W * 0.04, H * 0.1);
      label("pair t " + pairT.toFixed(1) + " s  (−" + (t - pairT).toFixed(1) + ")", W * 0.96, H * 0.1, MOVER, "right");
      label("freeze " + Math.round(D.freezes[fi] * 1000) + " ms · hits " + hits, W / 2, y1 + R + 16, null, "center");
      const br = W * D.radius, bcx = W / 2;            // the slow-mo bubble lane
      ring(bcx, y2, br, MAGIC, 1.5);
      for (const m of lane) {
        const inside = Math.abs(m.x - bcx) < br;
        const s = inside ? D.bubble : 1;               // a local time scale
        m.x += v * 0.7 * dt * s;
        if (m.x > W + 10) m.x -= W + 20;
        mote(m.x, y2, 0, inside ? MAGIC : GOOD, 6);
        if (inside) label("dt × " + D.bubble, m.x, y2 - 12, MAGIC, "center");
      }
      label(D.label + D.bubble, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Hitstop", "Haymaker", "long freezes and a near-stopped bubble — the heavy anime hit, the pair's clock falling seconds behind the world", { freezes: [0.4, 0.8, 1.2], bubble: 0.05 });

def("S", "Substep", "time", "one spring at 60 fps and 10 fps, three ways — only the naive one diverges — press to restart the race", function (u) {
  var D = { frac: 0.1,      // the naive step: close this fraction of the gap per FRAME
            slow: 6,        // the slow simulation ticks once per this many 60ths of a second
            rate: 6.3,      // the framerate-proof rate, per second: 1 − exp(−rate·dt)
            period: 2.2,    // the target flips sides this often, seconds
            label: "gap·f per frame · gap·(1−e^(−k·dt)) · substeps" };
  const { ctx, W, H, stage, mote, label, MOVER, HOT, DIM } = u;
  // FRAMERATE INDEPENDENCE. the naive smoother  x += gap · 0.1  closes a
  // fraction per frame, so ten frames a second close far less than sixty —
  // the red curve falls behind the blue. write the fraction as
  // 1 − exp(−k·dt) and a bigger dt buys a bigger fraction: same curve at any
  // rate (k = 6.3 is the 60 fps twin of 0.1). the third way keeps the naive
  // formula but replays the missed 1/60ths: FIXED-STEP SUBSTEPS. the step
  // counters are the answer to "is it more frames": the substep panel does
  // sixty steps a second whatever the screen does.
  const N = 96, SAMP = 1 / 32;
  const gx0 = W * 0.06, gw = W * 0.7;
  const P = [{ name: "naive" }, { name: "exp" }, { name: "substep" }];
  let target = 1, flipT = 0, acc = 0, sampAcc = 0;
  function reset() {
    for (const p of P) { p.fast = 0; p.slow = 0; p.nf = 0; p.ns = 0; p.hf = []; p.hs = []; p.ht = []; }
    target = 1; flipT = 0; acc = 0; sampAcc = 0;
  }
  reset();
  function curve(hist, py, ph, c, w) {
    if (hist.length < 2) return;
    ctx.strokeStyle = c; ctx.lineWidth = w;
    ctx.beginPath();
    for (let i = 0; i < hist.length; i++) {
      const x = gx0 + (i / (N - 1)) * gw, y = py + ph - hist[i] * ph;
      if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y);
    }
    ctx.stroke();
  }
  return {
    press() { reset(); },
    frame(dt, t) {
      stage();
      flipT += dt;
      if (flipT > D.period) { flipT = 0; target = 1 - target; }
      P[0].fast += (target - P[0].fast) * D.frac;                        // naive: a fraction per frame
      P[1].fast += (target - P[1].fast) * (1 - Math.exp(-D.rate * dt));  // exp: a fraction per SECOND
      P[2].fast += (target - P[2].fast) * D.frac;                        // (the naive formula again)
      for (const p of P) p.nf++;
      acc += dt;                                       // the slow sim only ticks when
      if (acc >= D.slow / 60) {                        // enough time has piled up
        const big = acc; acc = 0;
        P[0].slow += (target - P[0].slow) * D.frac;    // same fraction, six times rarer
        P[1].slow += (target - P[1].slow) * (1 - Math.exp(-D.rate * big));   // the big dt buys a big fraction
        const n = Math.max(1, Math.round(big * 60));   // substeps: replay every missed 1/60th
        for (let i = 0; i < n; i++) P[2].slow += (target - P[2].slow) * D.frac;
        P[0].ns++; P[1].ns++; P[2].ns += n;
      }
      sampAcc += dt;
      while (sampAcc >= SAMP) {
        sampAcc -= SAMP;
        for (const p of P) {
          p.hf.push(p.fast); p.hs.push(p.slow); p.ht.push(target);
          if (p.hf.length > N) { p.hf.shift(); p.hs.shift(); p.ht.shift(); }
        }
      }
      for (let i = 0; i < 3; i++) {
        const p = P[i], py = H * 0.12 + i * H * 0.27, ph = H * 0.19;
        ctx.setLineDash([3, 3]);
        curve(p.ht, py, ph, DIM, 1);
        ctx.setLineDash([]);
        curve(p.hf, py, ph, MOVER, 1.5);
        curve(p.hs, py, ph, HOT, 1.5);
        mote(gx0 + gw + 12, py + ph - p.fast * ph, 0, MOVER, 4);
        mote(gx0 + gw + 26, py + ph - p.slow * ph, 0, HOT, 4);
        label(p.name + " · steps " + p.nf + " / " + p.ns, gx0, py - 2);
      }
      ctx.lineWidth = 1;
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Substep", "Stutter", "a 4 fps stepper against a greedier fraction — the naive curve crawls, the exp curve still lands on the same line", { slow: 15, frac: 0.2 });

def("T", "Timescale", "time", "one bouncing scene at ×0.25, ×1 and ×2 — the same frames, a different dt per frame — press to swap the scales", function (u) {
  var D = { scales: [0.25, 1, 2],   // the three TIME SCALES, left to right
            g: 1.9,                 // gravity, ×H per second²
            e: 0.8,                 // restitution (card B)
            rest: 0.8,              // seconds of SIM time the ball rests before relaunching
            label: "frames identical · sim dt = dt × scale" };
  const { ctx, W, H, GY, stage, ground, line, mote, label, MOVER, DIM } = u;
  // slow motion is not more frames. every column is drawn once per frame,
  // exactly like its neighbours — the counters prove it — but the simulation
  // in each is fed  dt × scale. a quarter of the dt per frame is a quarter of
  // the motion per frame: a TIME SCALE. the same code, the same starting
  // state, three clocks. (the ×2 column quietly halves its step twice so the
  // floor still catches the ball — substeps, card S — but it is drawn once.)
  let order = 0;
  const cw = W / 3;
  const sims = D.scales.map(() => ({ x: cw / 2, y: H * 0.3, vx: cw * 0.35, vy: 0, simT: 0, frames: 0, rest: 0, launches: 0 }));
  function stepSim(s, h) {
    s.simT += h;
    if (s.rest > 0) {
      s.rest -= h;
      if (s.rest <= 0) { s.launches++; s.vy = -Math.sqrt(2 * D.g * H * H * 0.45); s.vx = (s.launches % 2 ? -1 : 1) * cw * 0.45; }
      return;
    }
    s.vy += D.g * H * h;
    s.x += s.vx * h; s.y += s.vy * h;
    if (s.x < 9) { s.x = 9; s.vx = -s.vx * D.e; }
    if (s.x > cw - 9) { s.x = cw - 9; s.vx = -s.vx * D.e; }
    if (s.y > GY - 9) {
      s.y = GY - 9; s.vy = -s.vy * D.e; s.vx *= 0.99;
      if (Math.abs(s.vy) < H * 0.12) { s.vy = 0; s.rest = D.rest; }
    }
  }
  return {
    press() { order = (order + 1) % D.scales.length; },
    frame(dt, t) {
      stage(); ground();
      for (let i = 0; i < sims.length; i++) {
        const s = sims[i], scale = D.scales[(i + order) % D.scales.length], x0 = i * cw;
        const sdt = dt * scale;                        // ← the whole card
        const n = Math.max(1, Math.ceil(sdt / 0.02));  // substeps only for big steps
        for (let k = 0; k < n; k++) stepSim(s, sdt / n);
        s.frames++;                                    // one draw, whatever the scale
        if (i) line(x0, H * 0.05, x0, GY, DIM, 1);
        label("× " + scale, x0 + cw / 2, 13, "rgba(245,193,105,0.85)", "center");
        label("frames " + s.frames, x0 + cw / 2, 25, null, "center");
        label("sim " + s.simT.toFixed(1) + " s", x0 + cw / 2, 37, "rgba(138,217,245,0.8)", "center");
        mote(x0 + s.x, s.y, s.rest > 0 ? 0 : Math.atan2(s.vy, s.vx), MOVER, 7);
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Timescale", "Trance", "every column slower than life and the ball livelier — bullet time as a mood, the frame counters still marching in step", { scales: [0.1, 0.5, 1], e: 0.9 });

def("L", "Lag", "time", "a remote copy hears the mote 150 ms late: snap, interpolate or extrapolate — press to change the packet interval", function (u) {
  var D = { intervals: [0.15, 0.3, 0.6],   // packet intervals the press cycles through, seconds
            delay: 0.12,                   // the wire: seconds from send to arrival
            a: 0.9, b: 1.3,                // the true path, a Lissajous (card E), in rad/s
            label: "snap · interp: a packet behind · extrap: v·age" };
  const { ctx, W, H, TAU, stage, dot, ring, line, mote, label, clamp, lerp, MOVER, HOT, GOOD, MAGIC, DIM } = u;
  // network LAG: the remote machine never sees the mote, only PACKETS —
  // a position and velocity, sent every so often, arriving late. three ways
  // to cope. SNAP teleports to the newest packet (honest, jerky).
  // INTERPOLATION lerps between the last two packets, deliberately a whole
  // packet behind so it always has two to stand between (smooth, late).
  // EXTRAPOLATION — DEAD RECKONING — runs the last velocity forward by the
  // age of the data (on time, and wrong at every corner).
  const cx = W * 0.5, cy = H * 0.56, rx = W * 0.32, ry = H * 0.25;
  function truth(tt) {
    return { x: cx + Math.cos(tt * D.a) * rx, y: cy + Math.sin(tt * D.b) * ry,
             vx: -Math.sin(tt * D.a) * D.a * rx, vy: Math.cos(tt * D.b) * D.b * ry };
  }
  let ii = 0, sendT = 0, last = null, prev = null;
  const wire = [];
  return {
    press() { ii = (ii + 1) % D.intervals.length; },
    frame(dt, t) {
      stage();
      const iv = D.intervals[ii];
      sendT += dt;
      if (sendT >= iv) { sendT = 0; const p = truth(t); p.sent = t; wire.push(p); }   // a packet leaves
      while (wire.length && wire[0].sent + D.delay <= t) { prev = last; last = wire.shift(); }   // arrivals
      if (wire.length > 24) wire.shift();
      const T = truth(t);
      ctx.strokeStyle = "rgba(232,229,244,0.08)";      // the true path, previewed
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let i = 0; i <= 96; i++) {
        const q = truth(i / 96 * TAU * 10 / D.a);
        if (i) ctx.lineTo(q.x, q.y); else ctx.moveTo(q.x, q.y);
      }
      ctx.stroke();
      const wx0 = W * 0.12, wx1 = W * 0.88, wy = 16;   // the wire, with packets in flight
      line(wx0, wy, wx1, wy, DIM, 1);
      for (const p of wire) dot(lerp(wx0, wx1, clamp((t - p.sent) / D.delay, 0, 1)), wy, 2.5, "rgba(232,229,244,0.7)");
      label("every " + Math.round(iv * 1000) + " ms · wire " + Math.round(D.delay * 1000) + " ms", W / 2, wy + 14, null, "center");
      let S = T, I = T, X = T, sh = Math.atan2(T.vy, T.vx), ih = sh, xh = sh;
      if (last) {
        S = last; sh = Math.atan2(last.vy, last.vx);   // snap: the newest packet, as is
        const age = Math.min(t - last.sent, 1.5);      // dead reckoning: run the velocity forward
        X = { x: last.x + last.vx * age, y: last.y + last.vy * age }; xh = sh;
      }
      if (last && prev) {                              // interpolate: render a packet behind
        const rt = t - D.delay - iv;
        const k = clamp((rt - prev.sent) / ((last.sent - prev.sent) || 1), 0, 1);
        I = { x: lerp(prev.x, last.x, k), y: lerp(prev.y, last.y, k) };
        ih = Math.atan2(last.y - prev.y, last.x - prev.x);
      }
      ctx.setLineDash([2, 4]);                         // each copy's error, drawn
      line(S.x, S.y, T.x, T.y, "rgba(245,138,138,0.4)", 1);
      line(I.x, I.y, T.x, T.y, "rgba(155,226,138,0.4)", 1);
      line(X.x, X.y, T.x, T.y, "rgba(201,160,245,0.4)", 1);
      ctx.setLineDash([]);
      mote(S.x, S.y, sh, HOT, 6);
      mote(I.x, I.y, ih, GOOD, 6);
      mote(X.x, X.y, xh, MAGIC, 6);
      mote(T.x, T.y, Math.atan2(T.vy, T.vx));
      label("true", W * 0.04, H * 0.9, MOVER);
      label("snap", W * 0.28, H * 0.9, HOT);
      label("interp", W * 0.52, H * 0.9, GOOD);
      label("extrap", W * 0.78, H * 0.9, MAGIC);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Lag", "Lagspike", "a slow tick on a long wire — snap teleports, interp trails half a second, extrap overshoots every corner", { intervals: [0.5, 1, 1.5], delay: 0.4 });

def("Q", "Quantize", "time", "smooth, snapped to 8 fps, and snapped to 8 fps + an 8 px grid + 8 headings — press to change the frame rate", function (u) {
  var D = { fpsList: [4, 8, 12],   // the sample rates the press cycles through
            grid: 8,               // the spatial grid, in px
            dirs: 8,               // headings snapped to this many directions
            spd: 1.0,              // path speed multiplier
            label: "⌊t·fps⌋/fps · ⌊x/g⌋·g · n headings" };
  const { ctx, W, H, TAU, stage, ring, line, mote, label, MOVER, MAGIC, BONE, DIM } = u;
  // QUANTISED motion: the position is still a smooth formula of t, but the
  // t we feed it is rounded down to the last 1/8 s — stop-motion, animating
  // ON TWOS (12 fps) or on eights. the third copy also rounds its x and y to
  // an 8 px grid and its heading to 8 directions: pixel-art rules, where a
  // sprite may only stand on whole pixels and face where it has a frame for.
  // the counters count how often each copy actually changes pose per second.
  const cw = W / 3;
  const cols = [0, 1, 2].map(i => ({ cx: cw * (i + 0.5), lx: 0, ly: 0, n: 0, rate: 0 }));
  let fi = 1, sec = 0;
  function path(tt, c) {
    const rx = cw * 0.32, ry = H * 0.25;
    return { x: c.cx + Math.cos(tt * 1.1) * rx, y: H * 0.5 + Math.sin(tt * 1.7) * ry,
             h: Math.atan2(Math.cos(tt * 1.7) * 1.7 * ry, -Math.sin(tt * 1.1) * 1.1 * rx) };
  }
  return {
    press() { fi = (fi + 1) % D.fpsList.length; },
    frame(dt, t) {
      stage();
      const fps = D.fpsList[fi], g = D.grid, step = TAU / D.dirs;
      const tq = Math.floor(t * D.spd * fps) / fps;   // ← time, quantised
      sec += dt;
      const tick = sec >= 1;                           // once a second, publish the counts
      if (tick) sec -= 1;
      for (let i = 0; i < 3; i++) {
        const c = cols[i];
        let p = path(i === 0 ? t * D.spd : tq, c);
        if (i === 2) {                                 // space and heading, quantised too
          p.x = Math.round(p.x / g) * g; p.y = Math.round(p.y / g) * g;
          p.h = Math.round(p.h / step) * step;
        }
        if (Math.abs(p.x - c.lx) + Math.abs(p.y - c.ly) > 0.01) c.n++;   // a pose change
        c.lx = p.x; c.ly = p.y;
        if (tick) { c.rate = c.n; c.n = 0; }
        const x0 = i * cw;
        if (i) line(x0, H * 0.08, x0, H * 0.86, DIM, 1);
        if (i === 2)                                   // the grid the sprite must stand on
          for (let gx = Math.ceil(x0 / g) * g; gx < x0 + cw; gx += g)
            for (let gy = H * 0.12; gy < H * 0.86; gy += g) ring(gx, gy, 0.5, "rgba(232,229,244,0.14)", 1);
        mote(p.x, p.y, p.h, i === 0 ? MOVER : (i === 1 ? BONE : MAGIC), 7);
        label(i === 0 ? "smooth" : (i === 1 ? fps + " fps" : fps + " fps + grid"), c.cx, 14, null, "center");
        label(c.rate + " poses/s", c.cx, H * 0.92, null, "center");
      }
      label("⌊t·" + fps + "⌋/" + fps + " · ⌊x/" + g + "⌋·" + g + " · " + D.dirs + " headings", W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Quantize", "Quaint", "two to four frames a second, a 16 px grid and four headings — a handheld from 1989", { fpsList: [2, 3, 4], grid: 16, dirs: 4 });

def("Z", "Zap", "time", "a ring telegraphs the destination for 0.3 s, then the move takes zero frames — press to blink to your click", function (u) {
  var D = { telegraph: 0.3,   // seconds the destination ring shrinks before the blink
            fade: 0.5,        // seconds the afterimage streak lasts
            every: 2.4,       // seconds between scheduled blinks
            ghosts: 4,        // afterimages left along the streak
            label: "telegraph → move in 0 frames → afterimage" };
  const { W, H, TAU, stage, dot, ring, line, mote, label, rand, clamp, len, lerp, MAGIC } = u;
  // a TELEPORT is a motion of zero duration — and zero-duration motion still
  // needs animating, just not in between. the TELEGRAPH before (a ring
  // shrinking on the destination) tells the eye where to look; the
  // AFTERIMAGE after (a streak and fading ghosts along the line it did not
  // travel) tells the eye what just happened. neither touches the position:
  // that changes in one frame, x = dest, and the counter says so.
  let x = W * 0.3, y = H * 0.5, dx = x, dy = y, ox = x, oy = y;
  let tele = -1, fadeT = 0, timer = 0, blinks = 0, dist = 0;
  return {
    press(px, py) { dx = clamp(px, 12, W - 12); dy = clamp(py, 14, H * 0.8); tele = 0; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (tele < 0 && timer > D.every) { dx = rand(W * 0.12, W * 0.88); dy = rand(H * 0.18, H * 0.72); tele = 0; }
      if (tele >= 0) {
        tele += dt;
        if (tele >= D.telegraph) {                     // the blink: one assignment, no frames between
          ox = x; oy = y; x = dx; y = dy;
          dist = len(x - ox, y - oy); fadeT = D.fade; tele = -1; timer = 0; blinks++;
        }
      }
      fadeT = Math.max(0, fadeT - dt);
      const bob = Math.sin(t * 2.6) * 3;
      if (fadeT > 0) {
        const k = fadeT / D.fade;
        line(ox, oy, x, y, "rgba(201,160,245," + (k * 0.6) + ")", 2);
        ring(ox, oy, (1 - k) * 22, "rgba(201,160,245," + (k * 0.7) + ")", 1.5);
        for (let i = 1; i <= D.ghosts; i++) {          // afterimages: the path it did not take
          const g = i / (D.ghosts + 1);
          mote(lerp(ox, x, g), lerp(oy, y, g) + bob, Math.atan2(y - oy, x - ox), "rgba(201,160,245," + (k * 0.55 * g) + ")");
        }
      }
      if (tele >= 0) {                                 // the telegraph: look here next
        const k = tele / D.telegraph;
        ring(dx, dy, 6 + (1 - k) * 26, MAGIC, 1.5);
        dot(dx, dy, 2, MAGIC);
      }
      const face = tele >= 0 ? Math.atan2(dy - y, dx - x) : Math.atan2(y - oy, x - ox);
      mote(x, y + bob, face);
      label("blinks " + blinks + " · last: " + Math.round(dist) + " px in 0 frames", W / 2, 14, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Zap", "Zipper", "an eyeblink of telegraph and a blink every 0.7 s with a long ghost trail — the boss that will not stay put", { telegraph: 0.08, every: 0.7, ghosts: 7 });

def("R", "Rubberband", "time", "a client guesses, a server disagrees, every packet yanks it back — press to change the correction strength", function (u) {
  var D = { strengths: [1, 0.5, 0.15],  // the press cycles: 1 = snap, less = a softer yank per packet
            packet: 0.4,                // seconds between server packets
            current: 0.14,              // a sideways current the client does not know about, ×W
            a: 0.8, b: 1.1,             // the intended path, a Lissajous, in rad/s
            label: "on packet: client += (server − client) · k" };
  const { ctx, W, H, stage, dot, ring, line, mote, label, len, clamp, MOVER, TARGET, DIM } = u;
  // CLIENT-SIDE PREDICTION: the client moves the mote the instant it
  // intends to, without waiting to hear back — that is why online games
  // feel responsive. but the SERVER is the truth, and here the truth has a
  // current in it the client never modelled. every packet the client learns
  // the real position and corrects: k = 1 snaps (RUBBER-BANDING, the yank),
  // k < 1 lerps part of the way and drifts again. the band is the disagreement.
  const cx = W * 0.5, cy = H * 0.52, rx = W * 0.3, ry = H * 0.26;
  let px = cx + rx, py = cy;                           // the client starts where the path starts
  let si = 0, pk = 0, yank = 0;
  const strail = [], ctrail = [];
  return {
    press() { si = (si + 1) % D.strengths.length; },
    frame(dt, t) {
      stage();
      const vx = -Math.sin(t * D.a) * D.a * rx, vy = Math.cos(t * D.b) * D.b * ry;   // the intent
      px += vx * dt; py += vy * dt;                    // prediction: trust your own maths
      const sx = cx + Math.cos(t * D.a) * rx + Math.sin(t * 0.7) * W * D.current;    // the server: intent + current
      const sy = cy + Math.sin(t * D.b) * ry;
      const k = D.strengths[si];
      pk += dt;
      if (pk >= D.packet) {                            // a packet: the truth arrives
        pk = 0;
        const ex = sx - px, ey = sy - py;
        yank = len(ex, ey) * k;
        px += ex * k; py += ey * k;                    // ← the correction, k of the gap at once
      }
      strail.push([sx, sy]); ctrail.push([px, py]);
      if (strail.length > 48) { strail.shift(); ctrail.shift(); }
      for (let i = 0; i < strail.length; i++) {
        const a = i / strail.length;
        dot(strail[i][0], strail[i][1], 1.4, "rgba(245,193,105," + (a * 0.35) + ")");
        dot(ctrail[i][0], ctrail[i][1], 1.4, "rgba(138,217,245," + (a * 0.35) + ")");
      }
      const gap = len(sx - px, sy - py);               // the rubber band, redder as it stretches
      line(px, py, sx, sy, "rgba(245,138,138," + clamp(gap / 50, 0.25, 0.9) + ")", 1.5);
      ring(sx, sy, 7, TARGET, 1.5);
      dot(sx, sy, 2.5, TARGET);
      mote(px, py, Math.atan2(vy, vx));
      line(W * 0.1, H * 0.09, W * 0.1 + W * 0.8 * (pk / D.packet), H * 0.09, DIM, 2);   // next packet in...
      label("k = " + k + (k >= 1 ? " (snap)" : " (lerp)") + " · last yank " + Math.round(yank) + " px · gap " + Math.round(gap), W / 2, H * 0.17, null, "center");
      label("client", W * 0.06, H * 0.9, MOVER);
      label("server", W * 0.94, H * 0.9, TARGET, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Rubberband", "Rollback", "packets a second apart against a stronger unseen current — the snap is a leap, the soft modes never quite catch up", { packet: 1.0, current: 0.24, strengths: [1, 0.3, 0.1] });

/* ============================== the page runner ============================== */

var grid = document.getElementById("lexicon");
var statusEl = document.getElementById("status");
var runAllBtn = document.getElementById("runall");
var stopAllBtn = document.getElementById("stopall");
var cards = [];

function buildCard(effect) {
  var card = document.createElement("div");
  card.className = "bcard";
  var canvas = document.createElement("canvas");
  canvas.title = effect.letter + " · " + effect.name + " — click to wake it; click again to aim it, excite it, or shove it";
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
    statusEl.textContent = n === 0 ? "" : n + " of " + cards.length + " styles awake";
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
  small.textContent = list.length + " styles (+" + list.filter(function (e) { return e.rhyme; }).length + " rhymes) — " + fam[2];
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
window.__lexicon = { EFFECTS: EFFECTS, apiFor: apiFor, cards: cards, makeOf: makeOf, sourceOf: sourceOf };
})();
