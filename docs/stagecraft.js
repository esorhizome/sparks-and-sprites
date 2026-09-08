/* Sparks & Sprites — the stagecraft almanac.
   One small scene — a sky, a hill line, a ground, a lamp, a crate, a tree,
   and a hero sprite with a run cycle — and 104 things that happen TO the
   scene rather than to a character: the screen itself bending (CRT curves,
   dither, palette cycling, chromatic splits, radial blur, god rays,
   grading, grain, tape damage), the sprite's own skin (frozen, poisoned,
   jelly, swaying, X-rayed, reflected, nine-sliced, toon-lined, holographic),
   light and what it cannot reach (visibility polygons, fog of war,
   torches, night, lightning, stealth meters, bloom), weapons and the
   marks they leave (muzzle flashes, casings, tracers, decals, splats,
   debris, fuses, telegraphs), water and weather (spring surfaces, foam,
   puddles, rain on the lens, wind, seasons, growth, wildfire, lava, cloud
   shadows), particle machinery (pools, pixel emitters, collisions,
   sub-emitters, forces, shapes, sorting, shatter, cracks, sword arcs,
   timelines, layers, budgets), the HUD (health bars with ghost chunks,
   radial cooldowns, odometers, XP overflow, off-screen arrows, speech
   bubbles, hit markers, damage arcs, toasts, minimaps, placement ghosts,
   rarity glow, boss bars), and the sound half (panning, footsteps,
   beep-speak, synth recipes, engines, noise beds, muffles, reverb,
   adaptive music, lookahead scheduling, voice quotas, analysers, rumble).
   The seventh gallery: after the elemental button bestiary, the cube
   codex, the glyph grimoire, the locomotion lexicon, the flipbook folio
   and the depth atlas. A to Z four times, every card with a RHYME (the
   same effect with two or three dials turned), so the page holds 208.

   Every demo is one function make(u) that returns { frame(dt, t), press(x, y) }
   — plus drag: true when press is a continuous control. Its dials sit at
   the top in a D = { … } object; a rhyme is that object with a few values
   swapped. The kit u:
     ctx, W, H, TAU — the 2D context and canvas size (CSS pixels)
     GY            — the ground line's y (H · 0.8)
     ---- palette ----
     INK, DIM      — plain light, and its faded cousin
     NIGHT         — the dark paper behind everything      #131020
     HERO          — the sprite's shirt blue               #8AD9F5
     SUN           — amber: light, warmth, targets        #F5C169
     FIRE, SPARK   — flame orange, spark yellow
     HOT           — damage, danger                        #F58A8A
     GOOD          — safe, healthy, allowed                #9BE28A
     MAGIC         — spells, ghosts, weirdness             #C9A0F5
     WATER         — water, ice, cold                      #4FA3D8
     BONE          — structure, HUD frames                 #C9C4E4
     ---- numbers ----
     rand(a,b), rng(seed) — random, and seeded random (mulberry32)
     noise(x), noise2(x,y) — smooth value noise in −1..1, one- and two-dimensional
     len, clamp, lerp, ease (smoothstep), smooth(rate, dt) (the framerate-proof lerp factor)
     ---- colour ----
     col(c) → [r,g,b,a] · rgba(c, a) · mix(a, b, k) · shade(c, k) · hsl(h, s, l, a)
     ---- the scene ----
     stage(o)      — clears the canvas and paints the SCENE: a sky gradient,
                     far hills, a ground band. o.night 0..1 darkens toward
                     night; o.plain = true paints only the night paper +
                     graph paper (a neutral stage for HUD and audio cards)
     ground(y?)    — a floor line with hatching (defaults to GY)
     hero(x, y, o) — the protagonist, feet at (x, y): a code-drawn sprite
                     with hair, eyes, a shirt, legs. o.face ±1, o.pose
                     "stand" | "run" | "jump" | "hurt" | "crouch", o.frame (a
                     clock for the run cycle), o.s (unit size, default from H),
                     o.tint (colour string: painted over the body),
                     o.alpha, o.rot (radians about the feet)
     heroSprite(o) — the same hero drawn ALONE onto a cached offscreen
                     canvas → { cv, w, h, ax, ay, s } (ax, ay = the feet
                     anchor inside the sprite). Read its pixels with
                     pixelsOf(cv) for emit-from-pixels, silhouettes,
                     gradient maps, shatter
     tree(x,y,s,c?) lamp(x,y,lit?) crate(x,y,s) wall(x,y,w,h) house(x,y,w,h,lit?)
                   — props, all drawn from code
     ---- drawing ----
     dot, ring, line, rect, poly(pts, c, stroke?), arrow, ellipse(x,y,rx,ry,c)
     glow(x,y,r,c,a?) — a soft radial glow (uses the current composite op)
     label(txt,x,y,c?,align?) — a small annotation; text(txt,x,y,size,c?,align?,bold?)
     ---- layers & pixels (the shader half, spelled in canvas) ----
     layer(name)   — a cached offscreen canvas the size of the stage,
                     { cv, ctx, W, H } — draw the scene into it, mask it,
                     punch light holes in it, then draw it onto ctx
     pix(scale, fn, smooth?) — a SCREEN PASS: copies the whole canvas into
                     a small buffer (W·scale × H·scale), calls fn(data, w, h)
                     on its RGBA bytes, and draws it back stretched. Chunky
                     (nearest) unless smooth is true. scale 0.25–0.5 keeps
                     it cheap: a 250×170 card at 0.5 is 10 k pixels
     pixelsOf(cv)  — the ImageData of an offscreen canvas (its own pixel size)
     cutLight(L, x, y, r, soft?, a?) — punch a soft radial hole of light
                     into a darkness layer L (destination-out)
     visPoly(px, py, segs) — the VISIBILITY POLYGON from (px, py) against
                     wall segments [[x1,y1,x2,y2], …] plus the stage border:
                     returns [[x,y], …] sorted by angle (fill it for light
                     or line of sight)
     ---- sound (a courtesy, never a requirement) ----
     audio()       — the shared AudioContext, created on first call, or null
                     where the browser has none. Only call from press()
     tone(o)       — one synthesized voice: { freq, slideTo, type, dur, vol,
                     pan (−1..1), attack, decayTo } — silent without audio
     noiseBurst(o) — filtered noise: { dur, vol, lowpass, highpass, pan, sweepTo }
     beep(freq, dur, type) — the short version of tone
     spectrum()    — 32 bins of the current output (Uint8Array), zeros
                     when silent or without audio — for audio-reactive cards
     voices()      — how many synthesized voices are sounding right now
   Every card must draw something worth looking at with NO audio at all.

   Nothing animates until the visitor presses Run (or clicks a card awake),
   and every card rests after 60 seconds as a courtesy. Cards that flash the
   whole frame are opt-in (warnOf): they show a notice until clicked. */
(function () {
"use strict";
var TAU = Math.PI * 2;

var EFFECTS = [];
function def(letter, name, tag, hint, make) {
  EFFECTS.push({ letter: letter, name: name, tag: tag, hint: hint, make: make });
}

/* A RHYME is the same effect with two or three dials turned — a palette, a
   speed, a count, a mode — and nothing else. Every card keeps its dials in
   a  D = { … }  object at the top of make(u); the rhyme is a short object
   naming only the values that move. The runtime rebuilds the card's source
   with those values swapped in (see rhymeSource), so the editor shows the
   pair as a literal diff, and Godot does the same thing as a dictionary
   merge on right-click. */
function rhymeOf(orig, name, hint, dials) {
  for (var i = 0; i < EFFECTS.length; i++)
    if (EFFECTS[i].name === orig) {
      EFFECTS[i].rhyme = { name: name, hint: hint, dials: dials, orig: EFFECTS[i] };
      return;
    }
  throw new Error("rhymeOf: no card named " + orig);
}

/* A WARNING marks a card that must be opted into: it never starts with
   "Run all" — it shows a plain notice instead, and runs only when clicked.
   Used for the cards that flash the whole frame (lightning, muzzle flash),
   for photosensitive readers. */
function warnOf(name, text) {
  for (var i = 0; i < EFFECTS.length; i++)
    if (EFFECTS[i].name === name) { EFFECTS[i].warn = text; return; }
  throw new Error("warnOf: no card named " + name);
}

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

function makeOf(v) {
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

/* ---- the shared audio graph: one context, one master gain, one analyser ---- */
var AUDIO = { ac: null, master: null, analyser: null, bins: null, voices: 0, tried: false };
function audioContext() {
  if (AUDIO.ac) return AUDIO.ac;
  if (AUDIO.tried) return null;
  AUDIO.tried = true;
  var AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return null;
  try {
    var ac = new AC();
    var master = ac.createGain();
    master.gain.value = 0.35;
    var an = ac.createAnalyser();
    an.fftSize = 64;
    an.smoothingTimeConstant = 0.7;
    master.connect(an).connect(ac.destination);
    AUDIO.ac = ac; AUDIO.master = master; AUDIO.analyser = an;
    AUDIO.bins = new Uint8Array(an.frequencyBinCount);
  } catch (e) { return null; }
  return AUDIO.ac;
}
function voiceEnd(node, at) {                            // count voices honestly
  AUDIO.voices++;
  var done = false;
  function end() { if (!done) { done = true; AUDIO.voices = Math.max(0, AUDIO.voices - 1); } }
  node.onended = end;
  return end;
}
function panner(ac, pan) {
  if (!ac.createStereoPanner) return null;
  var p = ac.createStereoPanner();
  p.pan.value = Math.max(-1, Math.min(1, pan || 0));
  return p;
}
function playTone(o) {
  var ac = audioContext();
  if (!ac || !(o.freq > 0)) return;
  try {
    if (ac.state === "suspended") ac.resume();
    var t0 = ac.currentTime + (o.at || 0), dur = o.dur || 0.15, vol = o.vol === undefined ? 0.2 : o.vol;
    var osc = ac.createOscillator(), g = ac.createGain();
    osc.type = o.type || "square";
    osc.frequency.setValueAtTime(o.freq, t0);
    if (o.slideTo > 0) osc.frequency.exponentialRampToValueAtTime(o.slideTo, t0 + dur);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0002, vol), t0 + (o.attack || 0.006));
    g.gain.exponentialRampToValueAtTime(Math.max(0.0001, o.decayTo || 0.0001), t0 + dur);
    var p = panner(ac, o.pan);
    if (p) osc.connect(g).connect(p).connect(AUDIO.master); else osc.connect(g).connect(AUDIO.master);
    osc.start(t0); osc.stop(t0 + dur + 0.03);
    voiceEnd(osc);
  } catch (e) { /* audio is a courtesy */ }
}
var NOISE_BUF = null;
function playNoise(o) {
  var ac = audioContext();
  if (!ac) return;
  try {
    if (ac.state === "suspended") ac.resume();
    if (!NOISE_BUF) {
      NOISE_BUF = ac.createBuffer(1, ac.sampleRate * 2, ac.sampleRate);
      var d = NOISE_BUF.getChannelData(0);
      for (var i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    }
    var t0 = ac.currentTime + (o.at || 0), dur = o.dur || 0.3, vol = o.vol === undefined ? 0.2 : o.vol;
    var src = ac.createBufferSource(); src.buffer = NOISE_BUF; src.loop = true;
    src.playbackRate.value = o.rate || 1;
    var g = ac.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0002, vol), t0 + (o.attack || 0.005));
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    var node = src;
    if (o.lowpass > 0) {
      var lp = ac.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.setValueAtTime(o.lowpass, t0);
      if (o.sweepTo > 0) lp.frequency.exponentialRampToValueAtTime(o.sweepTo, t0 + dur);
      node.connect(lp); node = lp;
    }
    if (o.highpass > 0) {
      var hp = ac.createBiquadFilter(); hp.type = "highpass"; hp.frequency.value = o.highpass;
      node.connect(hp); node = hp;
    }
    var p = panner(ac, o.pan);
    if (p) node.connect(g).connect(p).connect(AUDIO.master); else node.connect(g).connect(AUDIO.master);
    src.start(t0); src.stop(t0 + dur + 0.03);
    voiceEnd(src);
  } catch (e) { /* audio is a courtesy */ }
}
var ZERO_BINS = new Uint8Array(32);
function spectrumNow() {
  if (!AUDIO.analyser) return ZERO_BINS;
  AUDIO.analyser.getByteFrequencyData(AUDIO.bins);
  return AUDIO.bins;
}

function apiFor(canvas) {
  var dpr = window.devicePixelRatio || 1;
  var W = canvas.clientWidth, H = canvas.clientHeight;
  canvas.width = Math.round(W * dpr);
  canvas.height = Math.round(H * dpr);
  var ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  var GY = H * 0.8;
  var INK = "#E8E5F4";
  var DIM = "rgba(232,229,244,0.25)";
  var NIGHT = "#131020";
  var HERO = "#8AD9F5";
  var SUN = "#F5C169";
  var FIRE = "#F58A5A";
  var SPARK = "#FFE9A8";
  var HOT = "#F58A8A";
  var GOOD = "#9BE28A";
  var MAGIC = "#C9A0F5";
  var WATER = "#4FA3D8";
  var BONE = "#C9C4E4";

  /* ---- numbers ---- */
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
  function hash2(i, j) { var s = Math.sin(i * 127.1 + j * 269.5 + 311.7) * 43758.5453; return s - Math.floor(s); }
  function noise(x) {                                  // value noise: random heights at the
    var i = Math.floor(x), f = x - i, k = f * f * (3 - 2 * f);   // integers, smoothstepped between
    return (hash(i) + (hash(i + 1) - hash(i)) * k) * 2 - 1;
  }
  function noise2(x, y) {                              // the same idea on a grid of corners
    var i = Math.floor(x), j = Math.floor(y), fx = x - i, fy = y - j;
    var kx = fx * fx * (3 - 2 * fx), ky = fy * fy * (3 - 2 * fy);
    var a = hash2(i, j), b = hash2(i + 1, j), c = hash2(i, j + 1), d = hash2(i + 1, j + 1);
    var top = a + (b - a) * kx, bot = c + (d - c) * kx;
    return (top + (bot - top) * ky) * 2 - 1;
  }
  function len(x, y) { return Math.sqrt(x * x + y * y); }
  function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
  function lerp(a, b, k) { return a + (b - a) * k; }
  function ease(k) { k = clamp(k, 0, 1); return k * k * (3 - 2 * k); }
  function smooth(rate, dt) { return 1 - Math.exp(-rate * dt); }

  /* ---- colour ---- */
  var colCache = {};
  function col(c) {                                    // "#rgb" / "#rrggbb" / "rgb()" / "rgba()" → [r,g,b,a]
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

  /* ---- the scene ---- */
  var hillSeed = 7;
  function stage(o) {
    o = o || {};
    if (o.plain) {
      var g0 = ctx.createLinearGradient(0, 0, 0, H);
      g0.addColorStop(0, "#1A1532"); g0.addColorStop(1, NIGHT);
      ctx.fillStyle = g0; ctx.fillRect(0, 0, W, H);
      ctx.strokeStyle = "rgba(150,145,190,0.07)"; ctx.lineWidth = 1;
      ctx.beginPath();
      for (var gx = 26; gx < W; gx += 26) { ctx.moveTo(gx, 0); ctx.lineTo(gx, H); }
      for (var gy = 26; gy < H; gy += 26) { ctx.moveTo(0, gy); ctx.lineTo(W, gy); }
      ctx.stroke();
      return;
    }
    var n = clamp(o.night || 0, 0, 1);
    var top = mix("#3B6FC4", "#0B0A1E", n), bot = mix("#CFE0F5", "#1E1A3A", n);
    var g = ctx.createLinearGradient(0, 0, 0, GY);
    g.addColorStop(0, top); g.addColorStop(1, bot);
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, GY + 1);
    ctx.fillStyle = mix("#6E8FB8", "#15132A", n);      // far hills: one noise line
    ctx.beginPath(); ctx.moveTo(0, GY);
    for (var x = 0; x <= W; x += 6) ctx.lineTo(x, GY - H * (0.08 + 0.07 * (noise(x / W * 3 + hillSeed) * 0.5 + 0.5)));
    ctx.lineTo(W, GY); ctx.closePath(); ctx.fill();
    ctx.fillStyle = mix("#4B7A5A", "#12111F", n);      // near hills
    ctx.beginPath(); ctx.moveTo(0, GY);
    for (var x2 = 0; x2 <= W; x2 += 6) ctx.lineTo(x2, GY - H * (0.02 + 0.05 * (noise(x2 / W * 5 + hillSeed * 3) * 0.5 + 0.5)));
    ctx.lineTo(W, GY); ctx.closePath(); ctx.fill();
    var gg = ctx.createLinearGradient(0, GY, 0, H);    // the ground band
    gg.addColorStop(0, mix("#5D8A4A", "#1A1830", n)); gg.addColorStop(1, mix("#3E5F33", NIGHT, n));
    ctx.fillStyle = gg; ctx.fillRect(0, GY, W, H - GY);
    ctx.strokeStyle = mix("rgba(20,40,20,0.5)", "rgba(201,196,228,0.35)", n);
    ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(0, GY); ctx.lineTo(W, GY); ctx.stroke();
  }
  function ground(gy) {
    gy = gy === undefined ? GY : gy;
    ctx.strokeStyle = "rgba(201,196,228,0.5)"; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(W, gy); ctx.stroke();
    ctx.strokeStyle = "rgba(201,196,228,0.16)"; ctx.lineWidth = 1;
    ctx.beginPath();
    for (var x = 4; x < W; x += 12) { ctx.moveTo(x, gy + 2); ctx.lineTo(x - 5, gy + 8); }
    ctx.stroke();
  }

  /* the hero: a 10 × 16 unit pixel sprite, feet at (x, y). every part is a
     rect on a unit grid, so it stays crisp at any unit size s. */
  function heroUnit() { return Math.max(2, Math.round(H / 60)); }
  function drawHero(c, x, y, o) {
    o = o || {};
    var s = o.s || heroUnit(), face = o.face || 1, pose = o.pose || "stand", f = o.frame || 0;
    var skin = "#F2C9A0", hair = SUN, shirt = o.shirt || HERO, pants = "#4A4470", shoe = "#2B2440";
    var bob = 0, legA = 0, legB = 0, armA = 0, armB = 0, squat = 0;
    if (pose === "run") { var ph = f * 9; bob = Math.abs(Math.sin(ph)) * 0.6; legA = Math.round(Math.sin(ph) * 2); legB = -legA; armA = -legA; armB = legA; }
    else if (pose === "jump") { legA = -1; legB = 1; armA = -3; armB = -3; }
    else if (pose === "hurt") { armA = -2; armB = -2; }
    else if (pose === "crouch") { squat = 4; }
    else { bob = Math.sin(f * 2) * 0.25; }
    c.save();
    c.translate(x, y);
    if (o.rot) c.rotate(o.rot);
    c.scale(face, 1);
    if (o.alpha !== undefined) c.globalAlpha = (c.globalAlpha || 1) * o.alpha;
    function R(ux, uy, uw, uh, colr) { c.fillStyle = colr; c.fillRect(ux * s, (uy - bob + squat) * s, uw * s, uh * s); }
    // legs (drawn first so the body overlaps them)
    R(-3 + legA, -5 + squat * 0, 3, 5 - squat, pants); R(0 + legB, -5, 3, 5 - squat, pants);
    R(-3 + legA, -1, 3, 1, shoe); R(0 + legB, -1, 3, 1, shoe);
    // body
    R(-4, -11, 8, 6, shirt);
    // arms
    R(-6, -11 + armA * 0.5, 2, 4, shirt); R(4, -11 + armB * 0.5, 2, 4, shirt);
    R(-6, -7 + armA * 0.5, 2, 1, skin); R(4, -7 + armB * 0.5, 2, 1, skin);
    // head
    R(-4, -16, 8, 5, skin);
    R(-4, -17, 8, 2, hair); R(-5, -16, 1, 3, hair); R(4, -16, 1, 2, hair);
    // eyes (facing +x)
    R(0, -14, 1, 1, pose === "hurt" ? HOT : "#2B2440"); R(2, -14, 1, 1, pose === "hurt" ? HOT : "#2B2440");
    if (pose === "hurt") { R(-1, -13, 5, 1, HOT); }
    if (o.tint) { c.globalCompositeOperation = "source-atop"; c.fillStyle = o.tint; c.fillRect(-6 * s, -17 * s, 12 * s, 17 * s + 2); }
    c.restore();
  }
  function hero(x, y, o) { drawHero(ctx, x, y, o); }
  var spriteCache = {};
  function heroSprite(o) {
    o = o || {};
    var s = o.s || heroUnit();
    var key = [s, o.face || 1, o.pose || "stand", Math.round((o.frame || 0) * 10) / 10, o.tint || "", o.shirt || ""].join("|");
    if (spriteCache[key]) return spriteCache[key];
    var cv = document.createElement("canvas");
    var w = 14 * s, h = 19 * s, ax = 7 * s, ay = 18 * s;
    cv.width = w; cv.height = h;
    var c = cv.getContext("2d");
    var oo = {}; for (var k in o) oo[k] = o[k];
    oo.s = s; oo.alpha = 1; oo.rot = 0;
    drawHero(c, ax, ay, oo);
    var out = { cv: cv, w: w, h: h, ax: ax, ay: ay, s: s };
    spriteCache[key] = out;
    return out;
  }

  /* props */
  function tree(x, y, s, c) {
    ctx.fillStyle = "#5A3E2B"; ctx.fillRect(x - s * 0.08, y - s * 0.55, s * 0.16, s * 0.55);
    ctx.fillStyle = c || "#3E7A48";
    ctx.beginPath(); ctx.moveTo(x, y - s * 1.3); ctx.lineTo(x + s * 0.45, y - s * 0.55); ctx.lineTo(x - s * 0.45, y - s * 0.55); ctx.closePath(); ctx.fill();
    ctx.beginPath(); ctx.moveTo(x, y - s * 1.05); ctx.lineTo(x + s * 0.36, y - s * 0.4); ctx.lineTo(x - s * 0.36, y - s * 0.4); ctx.closePath(); ctx.fill();
  }
  function lamp(x, y, lit) {
    var h = H * 0.3;
    ctx.fillStyle = "#3A3355"; ctx.fillRect(x - 2, y - h, 4, h);
    ctx.fillRect(x - 8, y - h - 3, 16, 4);
    ctx.fillStyle = lit === false ? "#3A3355" : SUN;
    ctx.beginPath(); ctx.arc(x, y - h - 8, 5, 0, TAU); ctx.fill();
  }
  function crate(x, y, s) {
    ctx.fillStyle = "#8A6A3E"; ctx.fillRect(x - s / 2, y - s, s, s);
    ctx.strokeStyle = "#5A3E2B"; ctx.lineWidth = Math.max(1, s * 0.08);
    ctx.strokeRect(x - s / 2 + 1, y - s + 1, s - 2, s - 2);
    ctx.beginPath(); ctx.moveTo(x - s / 2, y - s); ctx.lineTo(x + s / 2, y); ctx.moveTo(x + s / 2, y - s); ctx.lineTo(x - s / 2, y); ctx.stroke();
  }
  function wall(x, y, w, h) {
    ctx.fillStyle = "#6E6890"; ctx.fillRect(x, y, w, h);
    ctx.strokeStyle = "rgba(19,16,32,0.5)"; ctx.lineWidth = 1;
    ctx.beginPath();
    for (var yy = y; yy < y + h; yy += 8) { ctx.moveTo(x, yy); ctx.lineTo(x + w, yy); }
    ctx.stroke();
  }
  function house(x, y, w, h, lit) {
    ctx.fillStyle = "#4A4470"; ctx.fillRect(x, y - h, w, h);
    ctx.fillStyle = "#6E3A3A";
    ctx.beginPath(); ctx.moveTo(x - 4, y - h); ctx.lineTo(x + w / 2, y - h - h * 0.5); ctx.lineTo(x + w + 4, y - h); ctx.closePath(); ctx.fill();
    ctx.fillStyle = lit ? SUN : "#2B2440";
    ctx.fillRect(x + w * 0.2, y - h * 0.7, w * 0.22, h * 0.28);
    ctx.fillRect(x + w * 0.58, y - h * 0.7, w * 0.22, h * 0.28);
  }

  /* ---- drawing ---- */
  function dot(x, y, r, c) { ctx.fillStyle = c || INK; ctx.beginPath(); ctx.arc(x, y, Math.max(0.1, r), 0, TAU); ctx.fill(); }
  function ring(x, y, r, c, w) { ctx.strokeStyle = c || DIM; ctx.lineWidth = w || 1; ctx.beginPath(); ctx.arc(x, y, Math.max(0.5, r), 0, TAU); ctx.stroke(); }
  function line(x1, y1, x2, y2, c, w) { ctx.strokeStyle = c || INK; ctx.lineWidth = w || 1; ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); }
  function rect(x, y, w, h, c) { ctx.fillStyle = c || INK; ctx.fillRect(x, y, w, h); }
  function ellipse(x, y, rx, ry, c) { ctx.fillStyle = c || INK; ctx.beginPath(); ctx.ellipse(x, y, Math.max(0.1, rx), Math.max(0.1, ry), 0, 0, TAU); ctx.fill(); }
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
    ctx.strokeStyle = c || INK; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
    if (d < 3) return;
    var hx = dx / d, hy = dy / d, s = Math.min(6, d * 0.4);
    ctx.beginPath();
    ctx.moveTo(x2, y2);
    ctx.lineTo(x2 - hx * s - hy * s * 0.55, y2 - hy * s + hx * s * 0.55);
    ctx.lineTo(x2 - hx * s + hy * s * 0.55, y2 - hy * s - hx * s * 0.55);
    ctx.closePath(); ctx.fillStyle = c || INK; ctx.fill();
  }
  function glow(x, y, r, c, a) {
    r = Math.max(1, r);
    var g = ctx.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, rgba(c, a === undefined ? 0.8 : a));
    g.addColorStop(0.5, rgba(c, (a === undefined ? 0.8 : a) * 0.35));
    g.addColorStop(1, rgba(c, 0));
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
  }
  function label(txt, x, y, c, align) {
    ctx.fillStyle = c || "rgba(232,229,244,0.55)";
    ctx.font = "10px system-ui, sans-serif";
    ctx.textAlign = align || "left";
    ctx.fillText(txt, x, y);
    ctx.textAlign = "left";
  }
  function text(txt, x, y, size, c, align, bold) {
    ctx.fillStyle = c || INK;
    ctx.font = (bold ? "700 " : "") + (size || 12) + "px system-ui, sans-serif";
    ctx.textAlign = align || "left";
    ctx.fillText(txt, x, y);
    ctx.textAlign = "left";
  }

  /* ---- layers & pixels ---- */
  var layers = {};
  function layer(name) {
    var L = layers[name];
    if (L && L.W === W && L.H === H) return L;
    var cv = document.createElement("canvas");
    cv.width = Math.max(1, Math.round(W)); cv.height = Math.max(1, Math.round(H));
    L = { cv: cv, ctx: cv.getContext("2d"), W: W, H: H };
    layers[name] = L;
    return L;
  }
  var pixBuf = null;
  function pix(scale, fn, smoothBack) {
    scale = clamp(scale || 0.5, 0.05, 1);
    var w = Math.max(1, Math.round(W * scale)), h = Math.max(1, Math.round(H * scale));
    if (!pixBuf) { pixBuf = document.createElement("canvas"); }
    if (pixBuf.width !== w || pixBuf.height !== h) { pixBuf.width = w; pixBuf.height = h; }
    var pc = pixBuf.getContext("2d");
    pc.imageSmoothingEnabled = true;
    pc.clearRect(0, 0, w, h);
    pc.drawImage(canvas, 0, 0, w, h);                  // the whole canvas, shrunk
    var img = pc.getImageData(0, 0, w, h);
    fn(img.data, w, h);
    pc.putImageData(img, 0, 0);
    ctx.save();
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.globalAlpha = 1; ctx.globalCompositeOperation = "source-over";
    ctx.imageSmoothingEnabled = !!smoothBack;
    ctx.drawImage(pixBuf, 0, 0, W, H);                 // back, stretched
    ctx.restore();
  }
  function pixelsOf(cv) { return cv.getContext("2d").getImageData(0, 0, cv.width, cv.height); }
  function cutLight(L, x, y, r, soft, a) {
    var c = L.ctx;
    r = Math.max(1, r);
    c.save();
    c.globalCompositeOperation = "destination-out";
    var g = c.createRadialGradient(x, y, 0, x, y, r);
    var s = soft === undefined ? 0.5 : clamp(soft, 0, 1);
    g.addColorStop(0, "rgba(0,0,0," + (a === undefined ? 1 : a) + ")");
    g.addColorStop(Math.max(0.01, 1 - s), "rgba(0,0,0," + (a === undefined ? 1 : a) * 0.6 + ")");
    g.addColorStop(1, "rgba(0,0,0,0)");
    c.fillStyle = g;
    c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill();
    c.restore();
  }
  /* the visibility polygon: cast a ray toward every wall corner (and a hair
     either side of it), keep the nearest hit per ray, sort by angle. */
  function raySeg(px, py, dx, dy, s) {
    var x3 = s[0], y3 = s[1], x4 = s[2], y4 = s[3];
    var den = dx * (y4 - y3) - dy * (x4 - x3);
    if (Math.abs(den) < 1e-9) return Infinity;
    var t = ((x3 - px) * (y4 - y3) - (y3 - py) * (x4 - x3)) / den;
    var u = ((x3 - px) * dy - (y3 - py) * dx) / den;
    return (t > 0 && u >= 0 && u <= 1) ? t : Infinity;
  }
  function visPoly(px, py, segs) {
    var all = segs.concat([[0, 0, W, 0], [W, 0, W, H], [W, H, 0, H], [0, H, 0, 0]]);
    var angles = [];
    for (var i = 0; i < all.length; i++) {
      var s = all[i];
      for (var e = 0; e < 2; e++) {
        var a = Math.atan2(s[1 + e * 2] - py, s[e * 2] - px);
        angles.push(a - 1e-4, a, a + 1e-4);
      }
    }
    var out = [];
    for (var k = 0; k < angles.length; k++) {
      var dx = Math.cos(angles[k]), dy = Math.sin(angles[k]), best = Infinity;
      for (var j = 0; j < all.length; j++) { var t = raySeg(px, py, dx, dy, all[j]); if (t < best) best = t; }
      if (!isFinite(best)) best = W + H;
      out.push([px + dx * best, py + dy * best, angles[k]]);
    }
    out.sort(function (p, q) { return p[2] - q[2]; });
    return out;
  }

  /* ---- sound ---- */
  function audio() { return audioContext(); }
  function tone(o) { playTone(o || {}); }
  function noiseBurst(o) { playNoise(o || {}); }
  function beep(freq, dur, type) { playTone({ freq: freq, dur: dur || 0.12, type: type || "triangle", vol: 0.12 }); }
  function spectrum() { return spectrumNow(); }
  function voices() { return AUDIO.voices; }

  return { ctx: ctx, W: W, H: H, GY: GY, TAU: TAU, dpr: dpr,
           INK: INK, DIM: DIM, NIGHT: NIGHT, HERO: HERO, SUN: SUN, FIRE: FIRE, SPARK: SPARK, HOT: HOT, GOOD: GOOD, MAGIC: MAGIC, WATER: WATER, BONE: BONE,
           rand: rand, rng: rng, noise: noise, noise2: noise2, len: len, clamp: clamp, lerp: lerp, ease: ease, smooth: smooth,
           col: col, rgba: rgba, mix: mix, shade: shade, hsl: hsl,
           stage: stage, ground: ground, hero: hero, heroSprite: heroSprite, tree: tree, lamp: lamp, crate: crate, wall: wall, house: house,
           dot: dot, ring: ring, line: line, rect: rect, ellipse: ellipse, poly: poly, arrow: arrow, glow: glow, label: label, text: text,
           layer: layer, pix: pix, pixelsOf: pixelsOf, cutLight: cutLight, visPoly: visPoly,
           audio: audio, tone: tone, noiseBurst: noiseBurst, beep: beep, spectrum: spectrum, voices: voices };
}

var FAMILY_ORDER = [
  ["screen", "Screen & post-process", "the whole frame bent after the fact — wipes, CRT curves, dither, palettes that cycle, RGB splits, distortion, radial blur, god rays, grades, grain, tape damage"],
  ["skin", "Sprite & material shaders", "the sprite's own skin — frozen and petrified, poisoned, jelly, swaying, X-rayed, reflected, sheared into a shadow, pixel-perfect, nine-sliced, toon-lined, under water, holographic"],
  ["light", "Lighting & visibility", "light and what it cannot reach — visibility polygons, fog of war, torches, night overlays, lightning, stealth meters, shafts, dusk windows, blob shadows, bloom, room lights, zones"],
  ["impact", "Weapons, impacts & decals", "the fire() event and the marks it leaves — muzzle flash, casings, tracers, impacts by material, decal buffers, footprints, splats, debris, chain reactions, fuses, grenades, telegraphs, tells"],
  ["weather", "Water, weather & nature", "the outdoors as systems — spring water, floating, foam lines, puddles, rain on the lens, snow prints, reeds, wind, seasons, growth, wildfire, lava, cloud shadows"],
  ["particles", "Particle mechanics", "the machinery under every effect — pools, pixel emitters, colliding particles, sub-emitters, forces, shape emitters, depth sorting, shatter, cracks, sword arcs, timelines, layers, budgets"],
  ["hud", "UI & HUD feedback", "the interface as an effect — ghost health, radial cooldowns, odometers, XP overflow, off-screen arrows, speech bubbles, hit markers, damage arcs, toasts, minimaps, placement ghosts, rarity, boss bars"],
  ["audio", "SFX & audio", "the sound half, drawn — panning, footsteps, beep-speak, synth recipes, engines, noise beds, muffles, reverb, adaptive music, lookahead scheduling, voice quotas, analysers, rumble"]
];

/* ============================== SCREEN & POST-PROCESS ==============================
   Things done to the FRAME after the scene is finished. The picture is drawn,
   then read back — as a captured layer (layer) or as bytes (pix) — and bent:
   a mask wipes it, a vignette rims it, a CRT curves and stripes it, a
   threshold matrix dithers it, a palette snaps it or cycles under it, the
   colour channels slide apart, a distortion field pushes its texels, samples
   are averaged toward a centre (zoom blur, god rays), a curve regrades it,
   grain and scratches age it, a tape corrupts it. Every card is the same two
   lines — draw the scene, then fn(data, w, h) over its bytes at scale ≤ 0.5 —
   which is what a fragment shader does, spelled slowly enough to read. */

def("I", "Iris", "screen", "the old frame is captured, then a MASK eats it away over the new scene — iris, dissolve, checker, curtain, slide, swirl — press to cut now", function (u) {
  var D = { kind: "cycle",      // "iris" | "dissolve" | "checker" | "curtain" | "slide" | "swirl" — or "cycle" through all six
            kinds: ["iris", "dissolve", "checker", "curtain", "slide", "swirl"],
            hold: 2.4,          // seconds each scene sits before the next cut
            dur: 1.1,           // seconds one transition takes
            cells: 14,          // dissolve / checker cells across the width
            turns: 3,           // laps of the swirl's spiral
            label: "frame = new scene + old frame · mask(k) — the shape of the hole IS the transition" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, lamp, crate, glow, layer, label, ease, clamp, rng, ring, rect, dot, SUN, DIM } = u;
  // a SCREEN TRANSITION never touches either scene. the frame about to leave
  // is COPIED into a layer, the new scene is drawn underneath it, and a hole
  // is cut out of the copy (destination-out) that grows with k = 0 → 1. the
  // whole family is one question — what shape is the hole: a circle (iris),
  // cells in a hashed order (pixel dissolve), squares growing in two waves
  // (checkerboard), a rect opening from the centre (curtain), the copy just
  // translated (slide), ring-sectors sweeping lap by lap (swirl). chapter
  // 03's masks and the folio's Pixelate, grown into a cut between scenes.
  const seed = rng(11), order = [];
  for (let i = 0; i < 1024; i++) order.push(seed());   // each cell's dissolve threshold, fixed
  let scene = 0, k = -1, wait = D.hold * 0.5, ki = 0, kindCur = D.kinds[0];
  let cx = W / 2, cy = H * 0.45, rmax = 1, hx = W * 0.3, hdir = 1;
  function drawScene(s, t) {
    stage({ night: s ? 0.85 : 0 });
    tree(W * 0.16, GY, H * 0.28, s ? "#1E2A24" : "#3E7A48");
    crate(W * 0.82, GY, H * 0.12);
    if (s) { ctx.globalCompositeOperation = "lighter"; glow(W * 0.62, GY - H * 0.3 - 8, H * 0.35, SUN, 0.5); ctx.globalCompositeOperation = "source-over"; }
    lamp(W * 0.62, GY, !!s);
    hero(hx, GY, { pose: "run", frame: t, face: hdir });
  }
  function hole(c, e) {                                // the revealed region, drawn into the copy as a cut
    const cw = W / Math.max(1, D.cells), rows = Math.ceil(H / cw) + 1, n = Math.max(1, D.turns | 0);
    c.beginPath();
    if (kindCur === "iris") { c.arc(cx, cy, Math.max(0.1, e * rmax), 0, TAU); c.fill(); }
    else if (kindCur === "dissolve") {
      for (let j = 0; j < rows; j++) for (let i = 0; i < D.cells; i++)
        if (order[(j * 37 + i * 11) % 1024] < e) c.rect(i * cw, j * cw, cw + 0.5, cw + 0.5);
      c.fill();
    } else if (kindCur === "checker") {
      for (let j = 0; j < rows; j++) for (let i = 0; i < D.cells; i++) {
        const s = clamp(e * 2 - ((i + j) & 1), 0, 1) * cw;   // odd cells start half a transition later
        if (s > 0) c.rect(i * cw + (cw - s) / 2, j * cw + (cw - s) / 2, s, s);
      }
      c.fill();
    } else if (kindCur === "curtain") { c.rect(W / 2 - e * W / 2, 0, e * W, H); c.fill(); }
    else if (kindCur === "swirl") {
      for (let j = 0; j < n; j++) {                     // band j opens only after j full laps
        const sweep = clamp(e * n * TAU - j * TAU, 0, TAU);
        if (sweep <= 0.001) continue;
        const r0 = j / n * rmax, r1 = (j + 1) / n * rmax;
        c.beginPath(); c.arc(cx, cy, r1, 0, sweep); c.arc(cx, cy, Math.max(0.1, r0), sweep, 0, true); c.closePath(); c.fill();
      }
    }
  }
  return {
    press(x, y) { cx = x; cy = y; if (k >= 0) k = -1; wait = 0; },
    frame(dt, t) {
      hx += hdir * W * 0.16 * dt; if (hx > W * 0.78) hdir = -1; else if (hx < W * 0.22) hdir = 1;
      const OLD = layer("irisOld"), CUT = layer("irisCut");
      if (k < 0) {
        wait -= dt;
        drawScene(scene, t);
        if (wait <= 0) {                                // the cut starts: capture this frame, flip the scene
          OLD.ctx.clearRect(0, 0, W, H); OLD.ctx.drawImage(ctx.canvas, 0, 0, W, H);
          kindCur = D.kind === "cycle" ? D.kinds[ki++ % D.kinds.length] : D.kind;
          const mx = Math.max(cx, W - cx), my = Math.max(cy, H - cy);
          rmax = Math.sqrt(mx * mx + my * my) + 2;      // the far corner, so the hole can reach it
          scene = 1 - scene; k = 0;
        }
      }
      if (k >= 0) {
        k = Math.min(1, k + dt / Math.max(0.05, D.dur));
        const e = ease(k);
        drawScene(scene, t);                            // the new scene, underneath
        if (kindCur === "slide") ctx.drawImage(OLD.cv, e * W, 0, W, H);   // the copy simply moves
        else {
          const c = CUT.ctx;
          c.globalCompositeOperation = "source-over"; c.clearRect(0, 0, W, H); c.drawImage(OLD.cv, 0, 0);
          c.globalCompositeOperation = "destination-out"; c.fillStyle = "#000";
          hole(c, e);                                   // ← the mask: a hole cut in the old frame
          c.globalCompositeOperation = "source-over";
          ctx.drawImage(CUT.cv, 0, 0, W, H);
        }
        if (kindCur === "iris" || kindCur === "swirl") { ring(cx, cy, e * rmax, "rgba(245,193,105,0.6)", 1); dot(cx, cy, 2, SUN); }
        rect(W * 0.3, 8, W * 0.4, 3, "rgba(232,229,244,0.15)"); rect(W * 0.3, 8, W * 0.4 * k, 3, SUN);
        label(kindCur + "  k = " + k.toFixed(2), W / 2, 22, null, "center");
        if (k >= 1) { k = -1; wait = D.hold; }
      } else label("hold " + Math.max(0, wait).toFixed(1) + " s · next: " + (D.kind === "cycle" ? D.kinds[ki % D.kinds.length] : D.kind), W / 2, 22, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Iris", "Irisout", "one slow spiral wipe, three laps out from the centre, a long hold either side — the RPG battle entry", { kind: "swirl", dur: 2.6, hold: 3.2 });

def("H", "Hurt", "screen", "red edges whose alpha follows health, pulsing on a heartbeat that quickens as health falls — the atlas's Vignette, wounded — press to take a hit", function (u) {
  var D = { hitEvery: 2.6,      // seconds between the slime's lunges
            dmg: 0.24,          // health lost per hit (of 1)
            regen: 0.05,        // health regrown per second, once left alone
            inner: 0.45,        // where the red starts, as a fraction of the corner radius
            maxA: 0.9,          // the vignette's alpha at zero health
            bpmLow: 45, bpmHigh: 170,   // the heartbeat at full health, and at none
            colour: "#D8262E",  // the edge colour
            frost: 0,           // 0..1: ice creeping in at the corners as health falls
            label: "α = maxA · (1 − hp)^1.2 · beat(φ)  ·  bpm = lerp(45, 170, 1 − hp)" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, lamp, crate, label, text, rect, dot, ellipse, poly, rgba, mix, lerp, clamp, len, rng, GOOD, HOT, DIM, BONE } = u;
  // the DAMAGE VIGNETTE is the atlas's Vignette with its alpha wired to a
  // number: a radial gradient, clear inside, colour at the corners, its
  // strength (1 − hp)^1.2 so it barely shows above half health and floods
  // below a quarter. the LOW-HEALTH PULSE is a heartbeat — two bumps per
  // beat, exp(−p²·90) and a smaller echo — whose rate rises as health falls,
  // so the screen's breathing tells you the number before the bar does. a
  // hit adds a flash and a shake; regen drains the whole thing back.
  const R = rng(5), ice = [];
  for (let i = 0; i < 28; i++) ice.push({ c: i & 3, a: R() * TAU / 4, l: 0.08 + R() * 0.12, w: 0.5 + R() });
  const trace = new Float32Array(72);
  let hp = 1, phase = 0, flash = 0, since = 9, lunge = 0, timer = 1.2, ti = 0;
  function hit() { hp = Math.max(0.04, hp - D.dmg); flash = 1; lunge = 1; since = 0; }
  return {
    press() { hit(); },
    frame(dt, t) {
      timer -= dt; if (timer <= 0) { hit(); timer = D.hitEvery; }
      since += dt; if (since > 1.5) hp = Math.min(1, hp + D.regen * dt);   // regen, once left alone
      flash = Math.max(0, flash - dt * 3); lunge = Math.max(0, lunge - dt * 2.5);
      const bpm = lerp(D.bpmLow, D.bpmHigh, 1 - hp);   // the rate follows the wound
      phase += bpm / 60 * dt;
      const p = phase % 1;
      const beat = Math.exp(-p * p * 90) + 0.55 * Math.exp(-(p - 0.2) * (p - 0.2) * 90);   // lub, dub
      const a = clamp(D.maxA * Math.pow(1 - hp, 1.2) * (0.45 + 0.55 * beat) + flash * 0.5, 0, 1);
      ctx.save(); ctx.translate(flash * 4 * Math.sin(t * 70), 0);   // the hit shake
      stage({ night: 0.2 }); tree(W * 0.14, GY, H * 0.26); lamp(W * 0.88, GY, true); crate(W * 0.7, GY, H * 0.11);
      const hx = W * 0.4, ex = lerp(W * 0.76, hx + H * 0.1, Math.sin(lunge * Math.PI));
      ellipse(ex, GY - H * 0.045, H * 0.06, H * 0.045, HOT); dot(ex - H * 0.025, GY - H * 0.06, 1.5, "#2B2440"); dot(ex - H * 0.005, GY - H * 0.06, 1.5, "#2B2440");
      hero(hx, GY, { pose: flash > 0.55 ? "hurt" : "stand", frame: t, face: 1 });
      ctx.restore();
      const Rc = len(W / 2, H / 2) * 1.02;             // the vignette: clear inside, colour at the corners
      const g = ctx.createRadialGradient(W / 2, H / 2, Rc * D.inner, W / 2, H / 2, Rc);
      g.addColorStop(0, rgba(D.colour, 0)); g.addColorStop(0.6, rgba(D.colour, a * 0.45)); g.addColorStop(1, rgba(D.colour, a));
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      if (D.frost > 0) {                               // frost: a pale rim plus crystals growing in from the corners
        const fa = clamp(D.frost * (1 - hp) * 0.95, 0, 1);
        const fg = ctx.createRadialGradient(W / 2, H / 2, Rc * 0.55, W / 2, H / 2, Rc);
        fg.addColorStop(0, "rgba(220,240,255,0)"); fg.addColorStop(1, "rgba(225,242,255," + fa + ")");
        ctx.fillStyle = fg; ctx.fillRect(0, 0, W, H);
        ctx.strokeStyle = "rgba(235,248,255," + fa * 0.8 + ")";
        for (let i = 0; i < ice.length; i++) {
          const c = ice[i], x0 = (c.c & 1) ? W : 0, y0 = (c.c & 2) ? H : 0;
          const ang = c.a + ((c.c & 1) ? Math.PI / 2 : 0) + ((c.c & 2) ? -Math.PI / 2 : 0) + ((c.c === 3) ? Math.PI : 0);
          const L = c.l * W * (0.4 + 0.6 * (1 - hp));
          ctx.lineWidth = c.w; ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x0 + Math.cos(ang) * L, y0 + Math.sin(ang) * L); ctx.stroke();
        }
      }
      const bw = W * 0.34;                             // the health bar, and the heart that beats with the screen
      rect(10, 10, bw, 7, "rgba(19,16,32,0.7)"); rect(10, 10, bw * hp, 7, mix(HOT, GOOD, hp));
      ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.strokeRect(10.5, 10.5, bw, 7);
      const hcx = 10 + bw + 14, hcy = 13, hr = 4.5 * (1 + beat * 0.35 * (0.4 + 0.6 * (1 - hp)));
      dot(hcx - hr * 0.5, hcy - hr * 0.25, hr * 0.55, D.colour); dot(hcx + hr * 0.5, hcy - hr * 0.25, hr * 0.55, D.colour);
      poly([[hcx - hr * 1.02, hcy - hr * 0.05], [hcx + hr * 1.02, hcy - hr * 0.05], [hcx, hcy + hr]], D.colour);
      label(Math.round(bpm) + " bpm", hcx + 12, 17, DIM);
      trace[ti] = beat; ti = (ti + 1) % trace.length; // the pulse, as a trace
      const x0 = W * 0.58, x1 = W * 0.96;
      ctx.strokeStyle = rgba(D.colour, 0.9); ctx.lineWidth = 1; ctx.beginPath();
      for (let i = 0; i < trace.length; i++) { const v = trace[(ti + i) % trace.length]; const x = x0 + (x1 - x0) * i / (trace.length - 1), y = 24 - v * 12; if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y); }
      ctx.stroke();
      label("hp " + hp.toFixed(2) + "  α " + a.toFixed(2), 10, 30, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Hurt", "Hypothermia", "blue edges, a slow heavy pulse and frost creeping in at the corners — cold, not blood", { colour: "#4FA3D8", bpmHigh: 75, frost: 1 });

def("C", "Crt", "screen", "CRT: sample from uv + uv·|uv|²·curve (the barrel), darken every other row, stripe RGB phosphors, rim with a vignette — press to change the curve", function (u) {
  var D = { curve: 0.12,        // how much the corners bend inward
            curves: [0.04, 0.12, 0.22, 0.34],   // what a press cycles through
            scan: 0.35,         // scanline darkness (every other row)
            mask: 0.18,         // the RGB phosphor stripe strength
            vig: 0.4,           // corner darkening
            bloom: 0.3,         // how much bright neighbours bleed sideways
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "uv' = uv + uv·|uv|²·curve · row % 2 → ×(1 − scan) · col % 3 → rgb mask" };
  const { ctx, W, H, GY, stage, hero, tree, lamp, crate, glow, pix, label, rect, line, SUN, DIM, BONE } = u;
  // a CRT in one pass over the bytes. BARREL CURVATURE is a lookup: the
  // output pixel at uv (−1..1) reads the SOURCE at uv + uv·|uv|²·curve, so
  // the corners reach past the picture and go black — the bezel appears by
  // itself. SCANLINES darken every other row of the small buffer; the
  // PHOSPHOR MASK boosts one channel per column (r, g, b, r, g, b…); the
  // VIGNETTE multiplies by 1 − vig·|uv|⁴; a hair of BLOOM adds the bright
  // left and right neighbours. the folio's Hologram, grown to a whole frame.
  let curve = D.curve, src = null, hx = W * 0.3, hdir = 1;
  return {
    press() { curve = D.curves[(D.curves.indexOf(curve) + 1) % D.curves.length]; },
    frame(dt, t) {
      hx += hdir * W * 0.15 * dt; if (hx > W * 0.8) hdir = -1; else if (hx < W * 0.2) hdir = 1;
      stage({ night: 0.35 });
      tree(W * 0.15, GY, H * 0.28); crate(W * 0.84, GY, H * 0.12);
      ctx.globalCompositeOperation = "lighter"; glow(W * 0.6, GY - H * 0.3 - 8, H * 0.32, SUN, 0.5); ctx.globalCompositeOperation = "source-over";
      lamp(W * 0.6, GY, true);
      hero(hx, GY, { pose: "run", frame: t, face: hdir });
      pix(D.scale, (d, w, h) => {                       // ← the pass
        if (!src || src.length !== d.length) src = new Uint8ClampedArray(d.length);
        src.set(d);                                     // read from the copy, write to the frame
        const iw = 2 / w, ih = 2 / h, last = src.length - 4;
        for (let y = 0; y < h; y++) {
          const v = (y + 0.5) * ih - 1, rowK = (y & 1) ? 1 - D.scan : 1;
          for (let x = 0; x < w; x++) {
            const uu = (x + 0.5) * iw - 1, r2 = uu * uu + v * v, f = 1 + curve * r2;
            const su = uu * f, sv = v * f, o = (y * w + x) * 4;
            if (su < -1 || su > 1 || sv < -1 || sv > 1) { d[o] = d[o + 1] = d[o + 2] = 8; d[o + 3] = 255; continue; }   // past the picture: bezel
            const sx = Math.min(w - 1, ((su + 1) * 0.5 * w) | 0), sy = Math.min(h - 1, ((sv + 1) * 0.5 * h) | 0);
            const si = (sy * w + sx) * 4, lo = Math.max(0, si - 8), hi = Math.min(last, si + 8);
            const bright = (src[lo] + src[lo + 1] + src[lo + 2] + src[hi] + src[hi + 1] + src[hi + 2]) / 6;
            const add = D.bloom * Math.max(0, bright - 150), vig = (1 - D.vig * r2 * r2 * 0.25) * rowK, m = x % 3;
            d[o] = src[si] * vig * (1 + (m === 0 ? D.mask : -D.mask * 0.5)) + add;
            d[o + 1] = src[si + 1] * vig * (1 + (m === 1 ? D.mask : -D.mask * 0.5)) + add;
            d[o + 2] = src[si + 2] * vig * (1 + (m === 2 ? D.mask : -D.mask * 0.5)) + add;
            d[o + 3] = 255;
          }
        }
      });
      ctx.strokeStyle = "rgba(201,196,228,0.35)"; ctx.lineWidth = 2; ctx.strokeRect(1, 1, W - 2, H - 2);   // the set's frame
      rect(W - 34, 8, 4, 12, "#F55"); rect(W - 30, 8, 4, 12, "#5F5"); rect(W - 26, 8, 4, 12, "#55F");      // the mask, enlarged
      label("mask", W - 22, 18, DIM);
      label("curve " + curve.toFixed(2) + " · scan " + D.scan + " · " + Math.round(W * D.scale) + "×" + Math.round(H * D.scale), 8, 18, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Crt", "Cathode", "a strong curve and heavy scanlines, no phosphor mask — the arcade cabinet from across the room", { curve: 0.3, scan: 0.6, mask: 0 });

def("O", "Ordered", "screen", "ordered dither: a Bayer matrix of thresholds tiled over the frame quantises brightness to on/off — the Game Boy look — press to cycle 2×2 / 4×4 / 8×8", function (u) {
  var D = { size: 4,            // the Bayer matrix: 2, 4 or 8
            sizes: [2, 4, 8],   // what a press cycles through
            levels: 4,          // output shades (2 = 1-bit)
            dark: "#0F380F", light: "#9BBC0F",   // the two ends of the shade ramp
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "q = ⌊v⌋ + (frac(v) > (M[y%n][x%n] + ½) / n²) · v = lum · (levels − 1)" };
  const { ctx, W, H, GY, stage, hero, tree, lamp, crate, pix, label, text, rect, col, mix, DIM, BONE } = u;
  // ORDERED DITHER trades shades for pattern. a BAYER MATRIX is an n×n grid
  // of thresholds arranged so every 2×2 block already holds a spread of
  // values (built recursively: [[0,2],[3,1]], then each cell ×4 + that same
  // pattern). tile it over the frame; a pixel turns on where its brightness
  // beats the threshold under it. with more than two levels the same test
  // decides between the two nearest shades. no memory, no neighbours — one
  // lookup per pixel — which is why a 1989 hand-held could afford it.
  function bayer(n) {                                  // the recursive matrix, flattened to thresholds
    let m = [[0]], s = 1;
    while (s < n) {
      const nm = [];
      for (let y = 0; y < s * 2; y++) { nm.push([]); for (let x = 0; x < s * 2; x++) nm[y].push(m[y % s][x % s] * 4 + [0, 2, 3, 1][(y < s ? 0 : 2) + (x < s ? 0 : 1)]); }
      m = nm; s *= 2;
    }
    const thr = new Float32Array(n * n);
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) thr[y * n + x] = (m[y][x] + 0.5) / (n * n);
    return { m: m, thr: thr };
  }
  let n = D.size, B = bayer(n), hx = W * 0.3, hdir = 1;
  const L = Math.max(1, (D.levels | 0) - 1), ramp = [];
  for (let q = 0; q <= L; q++) ramp.push(col(mix(D.dark, D.light, q / L)));
  return {
    press() { n = D.sizes[(D.sizes.indexOf(n) + 1) % D.sizes.length]; B = bayer(n); },
    frame(dt, t) {
      hx += hdir * W * 0.15 * dt; if (hx > W * 0.8) hdir = -1; else if (hx < W * 0.2) hdir = 1;
      stage({ night: 0.1 });
      tree(W * 0.15, GY, H * 0.28); crate(W * 0.84, GY, H * 0.12); lamp(W * 0.62, GY, true);
      hero(hx, GY, { pose: "run", frame: t, face: hdir });
      const thr = B.thr;
      pix(D.scale, (d, w, h) => {                       // ← the pass
        for (let y = 0; y < h; y++) {
          const ty = (y % n) * n;
          for (let x = 0; x < w; x++) {
            const o = (y * w + x) * 4;
            const v = (0.299 * d[o] + 0.587 * d[o + 1] + 0.114 * d[o + 2]) / 255 * L;
            const b = v | 0, q = Math.min(L, b + (v - b > thr[ty + (x % n)] ? 1 : 0));   // the threshold under this pixel decides
            const c = ramp[q];
            d[o] = c[0]; d[o + 1] = c[1]; d[o + 2] = c[2]; d[o + 3] = 255;
          }
        }
      });
      const cell = n === 2 ? H * 0.07 : n === 4 ? H * 0.05 : H * 0.03, x0 = 8, y0 = 8;   // the matrix, drawn as a tile
      for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
        const k = B.m[y][x] / (n * n);
        rect(x0 + x * cell, y0 + y * cell, cell, cell, "rgba(" + Math.round(40 + 200 * k) + "," + Math.round(40 + 200 * k) + "," + Math.round(40 + 200 * k) + ",0.95)");
        if (n <= 4) text(B.m[y][x], x0 + x * cell + cell / 2, y0 + y * cell + cell * 0.72, cell * 0.55, k > 0.5 ? "#222" : "#EEE", "center");
      }
      ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.strokeRect(x0 + 0.5, y0 + 0.5, n * cell, n * cell);
      label("M " + n + "×" + n + " · " + D.levels + " levels", x0 + n * cell + 6, y0 + 10, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Ordered", "Obsidian", "1-bit, near-black on the same pale green, at a fifth of the resolution — a pocket LCD, two colours and a coarse grid", { levels: 2, scale: 0.22, dark: "#15161A" });

def("Q", "Quantise", "screen", "palette quantise: every pixel snaps to the nearest of N colours — by luma or by RGB distance — the swatches drawn — press to cycle palettes", function (u) {
  var D = { palette: ["#0F380F", "#306230", "#8BAC0F", "#9BBC0F"],   // the starting palette: four Game Boy greens
            more: [["#000000", "#1D2B53", "#7E2553", "#008751", "#AB5236", "#5F574F", "#C2C3C7", "#FFF1E8", "#FF004D", "#FFA300", "#FFEC27", "#00E436", "#29ADFF", "#83769C", "#FF77A8", "#FFCCAA"],   // a 16-colour fantasy console
                   ["#000000", "#0000AA", "#00AA00", "#00AAAA", "#AA0000", "#AA00AA", "#AA5500", "#AAAAAA", "#555555", "#5555FF", "#55FF55", "#55FFFF", "#FF5555", "#FF55FF", "#FFFF55", "#FFFFFF"],   // the 16 EGA colours
                   ["#2B0F54", "#AB1F65", "#FF4F69", "#FFF7F8", "#FF8142", "#FFDA45", "#3368DC", "#49E7EC"]],   // eight, hot
            mode: "luma",       // "luma": by brightness rank · "nearest": by RGB distance
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "luma: p[⌊L · N⌋] (sorted by brightness)  ·  nearest: argminᵢ |rgb − pᵢ|²" };
  const { ctx, W, H, GY, stage, hero, tree, lamp, crate, dot, pix, label, rect, col, hsl, DIM, BONE } = u;
  // PALETTE QUANTISE: the frame may only use N colours. two ways to choose.
  // by LUMA: sort the palette by brightness and index it with the pixel's
  // brightness — cheap, and it keeps gradients ordered, which is why the
  // Game Boy greens read as shading. by NEAREST: the palette colour with the
  // smallest squared RGB distance — right for coloured palettes, and worth
  // a lookup table (here 5 bits per channel, filled as pixels arrive) so the
  // per-pixel cost stays one read. no dither: the bands are the point.
  const list = [D.palette].concat(D.more), lut = new Uint8Array(32768);
  let pal = [], byLum = [], pi = 0, hx = W * 0.3, hdir = 1;
  function use(p) {
    pal = p.map(col);
    byLum = pal.slice().sort((a, b) => (0.299 * a[0] + 0.587 * a[1] + 0.114 * a[2]) - (0.299 * b[0] + 0.587 * b[1] + 0.114 * b[2]));
    lut.fill(255);                                     // 255 = not looked up yet
  }
  use(list[0]);
  return {
    press() { pi = (pi + 1) % list.length; use(list[pi]); },
    frame(dt, t) {
      hx += hdir * W * 0.15 * dt; if (hx > W * 0.8) hdir = -1; else if (hx < W * 0.2) hdir = 1;
      stage({ night: 0 });
      for (let i = 0; i < 6; i++) dot(W * (0.12 + i * 0.15), H * 0.22 + Math.sin(t * 1.3 + i) * H * 0.05, H * 0.05, hsl(i * 60, 0.8, 0.6));   // test colours
      tree(W * 0.15, GY, H * 0.28); crate(W * 0.84, GY, H * 0.12); lamp(W * 0.62, GY, true);
      hero(hx, GY, { pose: "run", frame: t, face: hdir });
      const N = pal.length, luma = D.mode === "luma";
      pix(D.scale, (d, w, h) => {                       // ← the pass
        for (let o = 0; o < d.length; o += 4) {
          const r = d[o], g = d[o + 1], b = d[o + 2];
          let c;
          if (luma) c = byLum[Math.min(N - 1, ((0.299 * r + 0.587 * g + 0.114 * b) / 256 * N) | 0)];
          else {
            const key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
            let ci = lut[key];
            if (ci === 255) {                          // first time this colour bucket is seen: search
              let best = 1e9; ci = 0;
              for (let i = 0; i < N; i++) { const dr = pal[i][0] - r, dg = pal[i][1] - g, db = pal[i][2] - b, dd = dr * dr + dg * dg + db * db; if (dd < best) { best = dd; ci = i; } }
              lut[key] = ci;
            }
            c = pal[ci];
          }
          d[o] = c[0]; d[o + 1] = c[1]; d[o + 2] = c[2];
        }
      });
      const sw = Math.min(10, (W - 20) / N), show = luma ? byLum : pal;   // the swatches, in the order the pass uses them
      for (let i = 0; i < N; i++) rect(8 + i * sw, H - 30, sw - 1, 9, "rgb(" + show[i][0] + "," + show[i][1] + "," + show[i][2] + ")");
      ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.strokeRect(7.5, H - 30.5, N * sw, 10);
      label(D.mode + " · N = " + N + (luma ? " · dark → light" : " · 5-bit LUT"), 10 + N * sw, H - 22, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Quantise", "Quartz", "eight pastel colours chosen by RGB distance — a candy palette in nearest mode", { palette: ["#F6E7EE", "#F2C4D8", "#C9B6E4", "#A8D8EA", "#B5EAD7", "#FFF3B0", "#FFC6A5", "#7C6C8C"], mode: "nearest" });

def("C", "Cycle", "screen", "palette cycling: the picture is indices, not colours; shift the palette each frame and the still waterfall flows (Mark Ferrari) — press to reverse", function (u) {
  var D = { palette: "water",   // which palette the indices look up: "water" | "fire"
            palettes: { water: ["#0B2A5C", "#123C7A", "#1A4E98", "#2261B4", "#2F78CC", "#4A93DD", "#6FB0EA", "#9CCDF4", "#D7ECFB", "#FFFFFF", "#7FB6E8", "#3D7EC9"],
                        fire: ["#1A0700", "#3A0E00", "#6A1A00", "#9A2E00", "#C64A08", "#E8701A", "#F79A2A", "#FFC24A", "#FFE58A", "#FFF7C8", "#F5A030", "#C04010"] },
            speed: 7,           // palette entries shifted per second (negative flows the other way)
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "colour = pal[(index + shift) mod n] — the pixels never move, the palette does" };
  const { ctx, W, H, GY, stage, hero, layer, pix, label, rect, ellipse, poly, col, noise, noise2, DIM, BONE, SUN } = u;
  // PALETTE CYCLING is the oldest animation that draws nothing. the picture
  // is an INDEX MAP — every pixel stores a number, not a colour — and the
  // colour lives in a PALETTE the screen reads through. rotate the palette
  // by one entry per tick and every band moves one step, forever, for free.
  // here the map is drawn ONCE into a layer with the index hidden in the red
  // channel (r = i·16, g = 0, b = 255 as the marker); the pass finds those
  // pixels and looks them up through the shifted palette. the folio's Vapor
  // did the same with rows; Mark Ferrari did whole skies.
  let L = null, shift = 0, dir = 1, hx = W * 0.72, hdir = -1;
  const x0 = W * 0.38, x1 = W * 0.56, yt = H * 0.12, pcx = W * 0.47, pcy = GY + (H - GY) * 0.45, prx = W * 0.22, pry = (H - GY) * 0.5;
  function build(Lr, n) {                              // the index map: a waterfall column and a pool of rings
    const w = Lr.cv.width, h = Lr.cv.height, img = Lr.ctx.createImageData(w, h), d = img.data;
    for (let x = 0; x < w; x++) {
      const streak = (noise(x * 0.09 + 3) * 0.5 + 0.5) * 6;   // each column its own offset: vertical streaks
      for (let y = 0; y < h; y++) {
        let idx = -1;
        if (x >= x0 && x <= x1 && y >= yt && y <= GY + 2) {
          const edge = Math.min(x - x0, x1 - x) / Math.max(1, x1 - x0);
          idx = Math.floor(y / H * 26 + streak + noise2(x * 0.12, y * 0.06) * 1.5 + (edge < 0.08 ? 3 : 0));
        } else if (y >= GY) {
          const dx = (x - pcx) / prx, dy = (y - pcy) / pry, dd = Math.sqrt(dx * dx + dy * dy);
          if (dd < 1) idx = Math.floor(dd * 10 + noise2(x * 0.05, y * 0.1) * 0.8);
        }
        if (idx >= 0) { idx = ((idx % n) + n) % n; const o = (y * w + x) * 4; d[o] = idx * 16; d[o + 1] = 0; d[o + 2] = 255; d[o + 3] = 255; }
      }
    }
    Lr.ctx.putImageData(img, 0, 0);
  }
  return {
    press() { dir = -dir; },
    frame(dt, t) {
      const P = D.palettes[D.palette] || D.palettes.water, n = P.length, pal = P.map(col);
      const Lr = layer("cycleIdx");
      if (Lr !== L) { L = Lr; build(L, n); }           // once per size
      hx += hdir * W * 0.12 * dt; if (hx > W * 0.92) hdir = -1; else if (hx < W * 0.62) hdir = 1;
      shift -= D.speed * dir * dt;                     // ← the whole animation
      const off = ((Math.floor(shift) % n) + n) % n;
      stage({ night: 0.15 });
      ctx.drawImage(L.cv, 0, 0, W, H);                 // the still picture
      hero(hx, GY, { pose: "run", frame: t, face: hdir });
      pix(D.scale, (d, w, h) => {                       // ← the pass: the palette lookup
        for (let o = 0; o < d.length; o += 4) {
          if (d[o + 2] > 225 && d[o + 1] < 30) {        // an indexed pixel
            const c = pal[(((d[o] + 8) >> 4) % n + off) % n];
            d[o] = c[0]; d[o + 1] = c[1]; d[o + 2] = c[2];
          }
        }
      });
      const rock = "#3A3550";                          // the cliff, drawn over the map's seams
      rect(x0 - 9, yt - H * 0.1, 9, GY - yt + H * 0.1, rock); rect(x1, yt - H * 0.1, 9, GY - yt + H * 0.1, rock);
      rect(x0 - 9, yt - H * 0.1, x1 - x0 + 18, H * 0.1 - 2, rock);
      for (let i = 0; i <= 8; i++) { const a = Math.PI * i / 8; ellipse(pcx + Math.cos(a) * prx * 1.02, pcy + Math.sin(a) * pry * 1.02 - (H - GY) * 0.45 + (H - GY) * 0.45, W * 0.022, H * 0.014, rock); }
      const sw = Math.min(9, (W * 0.6) / n);           // the palette strip, rotating
      for (let i = 0; i < n; i++) { const c = pal[(i + off) % n]; rect(8 + i * sw, H - 30, sw - 1, 9, "rgb(" + c[0] + "," + c[1] + "," + c[2] + ")"); }
      ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.strokeRect(7.5, H - 30.5, n * sw, 10);
      poly([[8 + sw / 2 - 3, H - 33], [8 + sw / 2 + 3, H - 33], [8 + sw / 2, H - 30]], SUN);
      label("index 0 → pal[" + off + "] · " + (dir > 0 ? "→" : "←") + " " + Math.abs(D.speed) + "/s", 12 + n * sw, H - 22, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Cycle", "Campfire", "the same index map through a fire palette, shifting the other way and faster — the waterfall becomes a column of flame", { palette: "fire", speed: -12 });

def("X", "Xsplit", "screen", "chromatic aberration: R and B read from offsets that grow toward the edges, G in place — the grimoire's RGB split, frame-wide — press: split by distance", function (u) {
  var D = { split: 0.05,        // the offset at the corners, as a fraction of the buffer width
            power: 2,           // how the offset grows with distance from the centre (|uv|^power)
            pulse: 0,           // 0..1: a glitch pulse that tears rows sideways every pulseEvery seconds
            pulseEvery: 1.6,
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "o = split · |uv|^p · û   ·   R(p − o)  G(p)  B(p + o)" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, lamp, crate, glow, dot, pix, label, arrow, len, clamp, rand, SUN, DIM } = u;
  // CHROMATIC ABERRATION is a lens failing to focus every wavelength at the
  // same spot: red lands a little outside, blue a little inside. as a pass
  // it is three reads instead of one — red from p − o, green from p, blue
  // from p + o — where o points away from the centre and GROWS with
  // |uv|^power, so the middle stays sharp and the corners fringe. the
  // grimoire split one glyph; here the whole frame is the glyph. the pulse
  // tears rows sideways for a few frames — the "glitch" everyone means.
  let split = D.split, g = 0, timer = D.pulseEvery, seed = 1, src = null, hx = W * 0.3, hdir = 1;
  const rowOff = new Float32Array(512);
  return {
    press(x, y) { split = clamp(len(x - W / 2, y - H / 2) / (0.5 * Math.min(W, H)), 0, 1) * 0.2; },
    frame(dt, t) {
      hx += hdir * W * 0.15 * dt; if (hx > W * 0.8) hdir = -1; else if (hx < W * 0.2) hdir = 1;
      timer -= dt; if (timer <= 0) { timer = D.pulseEvery; if (D.pulse > 0) { g = D.pulse; seed = (Math.random() * 1e9) >>> 0; } }
      g = Math.max(0, g - dt * 4);
      stage({ night: 0.6 });
      dot(W * 0.8, H * 0.18, H * 0.05, "#F4F1E0");
      for (let i = 0; i < 12; i++) dot((i * 0.083 + 0.03) * W, H * (0.06 + ((i * 7) % 5) * 0.06), 1, "#FFF");
      tree(W * 0.15, GY, H * 0.28); crate(W * 0.84, GY, H * 0.12);
      ctx.globalCompositeOperation = "lighter"; glow(W * 0.6, GY - H * 0.3 - 8, H * 0.32, SUN, 0.5); ctx.globalCompositeOperation = "source-over";
      lamp(W * 0.6, GY, true);
      hero(hx, GY, { pose: "run", frame: t, face: hdir });
      pix(D.scale, (d, w, h) => {                       // ← the pass
        if (!src || src.length !== d.length) src = new Uint8ClampedArray(d.length);
        src.set(d);
        const cx = w / 2, cy = h / 2, sp = split * w, hp = D.power * 0.5;
        let s = seed;
        for (let y = 0; y < h; y++) {                   // the glitch: some 4-row bands get a sideways tear
          s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
          if (g > 0 && (y & 3) === 0) rowOff[y >> 2] = ((s >>> 8) & 255) < 90 ? (((s >>> 16) & 255) / 255 - 0.5) * 2 * g * w * 0.15 : 0;
        }
        for (let y = 0; y < h; y++) {
          const vv = (y - cy) / cy, ro = g > 0 ? rowOff[Math.min(511, y >> 2)] : 0;
          for (let x = 0; x < w; x++) {
            const uu = (x - cx) / cx, r2 = uu * uu + vv * vv, r = Math.sqrt(r2), o = (y * w + x) * 4;
            let ox = 0, oy = 0;
            if (r > 1e-4) { const f = sp * Math.pow(r2, hp) / r; ox = uu * f; oy = vv * f; }   // o = split·|uv|^p·û
            const xr = Math.max(0, Math.min(w - 1, (x - ox + ro + 0.5) | 0)), yr = Math.max(0, Math.min(h - 1, (y - oy + 0.5) | 0));
            const xb = Math.max(0, Math.min(w - 1, (x + ox - ro + 0.5) | 0)), yb = Math.max(0, Math.min(h - 1, (y + oy + 0.5) | 0));
            d[o] = src[(yr * w + xr) * 4];              // red from p − o
            d[o + 1] = src[o + 1];                      // green in place
            d[o + 2] = src[(yb * w + xb) * 4 + 2];      // blue from p + o
          }
        }
      });
      const pts = [[0.12, 0.14], [0.88, 0.14], [0.12, 0.86], [0.88, 0.86], [0.5, 0.5]];   // the offset vector, at five places
      for (let i = 0; i < pts.length; i++) {
        const px = pts[i][0] * W, py = pts[i][1] * H, uu = (px - W / 2) / (W / 2), vv = (py - H / 2) / (H / 2), r = len(uu, vv);
        if (r < 1e-3) { dot(px, py, 2, DIM); continue; }
        const f = split * W * Math.pow(r * r, D.power * 0.5) / r;   // in canvas pixels
        arrow(px, py, px - uu * f, py - vv * f, "rgba(255,80,80,0.9)");
        arrow(px, py, px + uu * f, py + vv * f, "rgba(90,140,255,0.9)");
      }
      label("split " + split.toFixed(3) + " · |uv|^" + D.power + (g > 0 ? " · glitch " + g.toFixed(2) : ""), 8, 18, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Xsplit", "Xtreme", "a huge split and a glitch pulse that tears rows sideways — the broken-lens boss intro", { split: 0.18, pulse: 1 });

def("R", "Refract", "screen", "distortion: each texel is read from p − field(p) — heat noise over a fire, an expanding shockwave ring, water rows (ch06's shockwave) — press to fire one", function (u) {
  var D = { kind: "heat",       // the standing field: "heat" (noise above a fire) | "water" (sine rows below a line) | "none"
            amp: 0.03,          // the standing field's push, as a fraction of the buffer width
            ringAmp: 0.05,      // a shockwave's push at birth
            ringW: 0.07,        // a ring's thickness, of the width
            ringSpeed: 0.7,     // how fast a ring grows, in widths per second
            ringEvery: 2.2,     // autopilot: one shockwave every so often
            waterY: 0.5,        // the water line, as a fraction of H (kind "water")
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "p' = p − field(p) · shock: amp·sin(π(d − r)/w)·r̂ · heat: noise(p, t) · water: sin rows" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, crate, glow, ring, rect, line, dot, pix, label, noise2, rand, clamp, FIRE, SUN, SPARK, WATER, DIM } = u;
  // SCREEN-SPACE DISTORTION: every output pixel reads the scene from
  // somewhere slightly else, p − field(p). the picture is untouched; only
  // the READ ADDRESSES bend. HEAT is a noise field inside a cone above the
  // fire, scrolling upward and fading with height (the bestiary's Heat haze,
  // as a pass). a SHOCKWAVE is a ring: inside its band the push is radial,
  // amp·sin(π·(d − r)/w), so the ring magnifies on one side and shrinks on
  // the other as it grows — chapter 06's ring made of displacement. WATER
  // is the cheapest: one sine per row, one per column, below a line.
  const rings = [];
  let timer = 0.8, src = null, hx = W * 0.65, hdir = 1;
  const fx = W * 0.3, fy = GY - 4;
  function shock(x, y) { rings.push({ x: x, y: y, r: 2, a: D.ringAmp }); if (rings.length > 6) rings.shift(); }
  return {
    press(x, y) { shock(x, y); },
    frame(dt, t) {
      hx += hdir * W * 0.12 * dt; if (hx > W * 0.9) hdir = -1; else if (hx < W * 0.5) hdir = 1;
      timer -= dt;
      if (timer <= 0) { timer = D.ringEvery; shock(rand(W * 0.1, W * 0.9), D.kind === "water" ? rand(H * D.waterY, H * 0.95) : rand(H * 0.2, H * 0.8)); }
      const rmax = W * 0.6;
      for (let i = rings.length - 1; i >= 0; i--) { const q = rings[i]; q.r += D.ringSpeed * W * dt; if (q.r > rmax) rings.splice(i, 1); }
      stage({ night: D.kind === "heat" ? 0.55 : 0.1 });
      tree(W * 0.12, GY, H * 0.26); crate(W * 0.86, GY, H * 0.11);
      if (D.kind === "heat") {                         // the campfire: logs and three flickering glows
        rect(fx - H * 0.06, GY - H * 0.02, H * 0.12, H * 0.02, "#5A3E2B"); rect(fx - H * 0.05, GY - H * 0.035, H * 0.1, H * 0.015, "#4A2E1B");
        ctx.globalCompositeOperation = "lighter";
        const fl = 0.8 + 0.2 * Math.sin(t * 17) * Math.sin(t * 5.3);
        glow(fx, fy - H * 0.05, H * 0.16 * fl, FIRE, 0.9); glow(fx + Math.sin(t * 9) * 3, fy - H * 0.09, H * 0.09 * fl, SUN, 0.9); glow(fx, fy - H * 0.11, H * 0.04, SPARK, 1);
        ctx.globalCompositeOperation = "source-over";
      }
      hero(hx, GY, { pose: "run", frame: t, face: hdir });
      if (D.kind === "water") { rect(0, H * D.waterY, W, H - H * D.waterY, "rgba(79,163,216,0.35)"); line(0, H * D.waterY, W, H * D.waterY, "rgba(215,236,251,0.8)", 1.5); }
      const kind = D.kind, wy = H * D.waterY, R = rings.length;
      pix(D.scale, (d, w, h) => {                       // ← the pass
        if (!src || src.length !== d.length) src = new Uint8ClampedArray(d.length);
        src.set(d);
        const s = w / W, fxb = fx * s, fyb = fy * s, wyb = wy * s, amp = D.amp * w, rw = Math.max(1, D.ringW * w);
        const rowS = new Float32Array(h), colS = new Float32Array(w);
        if (kind === "water") { for (let y = 0; y < h; y++) rowS[y] = Math.sin(y * 0.5 + t * 3); for (let x = 0; x < w; x++) colS[x] = Math.sin(x * 0.3 - t * 2); }
        for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
          let dx = 0, dy = 0;
          if (kind === "heat" && y < fyb) {             // inside the cone above the fire: scrolling noise
            const spread = w * 0.06 + (fyb - y) * 0.5, nx = (x - fxb) / spread;
            if (nx > -1 && nx < 1) {
              const wgt = (1 - nx * nx) * clamp(1 - (fyb - y) / (h * 0.8), 0, 1) * clamp((fyb - y) / (h * 0.06), 0, 1);
              dx = noise2(x * 0.3, y * 0.3 - t * 7) * amp * wgt; dy = noise2(x * 0.3 + 9, y * 0.3 - t * 7) * amp * 0.5 * wgt;
            }
          } else if (kind === "water" && y > wyb) { dx = (rowS[y] + colS[x]) * amp * 0.5; dy = rowS[y] * amp * 0.25; }
          for (let i = 0; i < R; i++) {                 // every live ring: a radial push inside its band
            const q = rings[i], ddx = x - q.x * s, ddy = y - q.y * s, dd = Math.sqrt(ddx * ddx + ddy * ddy), band = dd - q.r * s;
            if (band > -rw && band < rw && dd > 1e-3) { const k = Math.sin(Math.PI * band / rw) * q.a * w * (1 - q.r / rmax); dx += k * ddx / dd; dy += k * ddy / dd; }
          }
          const sx = Math.max(0, Math.min(w - 1, (x - dx + 0.5) | 0)), sy = Math.max(0, Math.min(h - 1, (y - dy + 0.5) | 0));
          const o = (y * w + x) * 4, si = (sy * w + sx) * 4;
          d[o] = src[si]; d[o + 1] = src[si + 1]; d[o + 2] = src[si + 2];
        }
      });
      for (let i = 0; i < rings.length; i++) { const q = rings[i]; ring(q.x, q.y, q.r, "rgba(245,193,105," + (0.7 * (1 - q.r / rmax)) + ")", 1); }
      if (kind === "heat") {                           // the cone, dashed
        ctx.setLineDash([3, 4]); ctx.strokeStyle = "rgba(245,138,90,0.5)"; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(fx - W * 0.06, fy); ctx.lineTo(fx - W * 0.06 - (fy - H * 0.05) * 0.5, H * 0.05); ctx.moveTo(fx + W * 0.06, fy); ctx.lineTo(fx + W * 0.06 + (fy - H * 0.05) * 0.5, H * 0.05); ctx.stroke();
        ctx.setLineDash([]);
        label("noise cone", fx, H * 0.09, "rgba(245,138,90,0.7)", "center");
      }
      if (kind === "water") label("sin rows below y = " + D.waterY + "H", W * 0.02, wy - 4, "rgba(215,236,251,0.7)");
      label("rings " + rings.length + " · w = " + D.ringW + "W", 8, 18, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Refract", "Ripplewave", "kind water: the lower half refracts on sine rows, and slow rings spread from every drop", { kind: "water", ringSpeed: 0.22, ringEvery: 1.6 });

def("Z", "Zoomblur", "screen", "radial blur: average N samples along the line to a centre — speed lines when the hero dashes, the folio's Zoom as a pass — press to set the centre", function (u) {
  var D = { samples: 8,         // reads per pixel along the line to the centre
            strength: 0.35,     // how far toward the centre the last sample sits (fraction of the distance)
            dashEvery: 2.6,     // seconds between dashes
            dashDur: 0.45,      // how long a dash (and full blur) lasts
            dashSpeed: 1.6,     // the dash, in widths per second
            decay: 4,           // how fast the blur fades after (per second)
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "out = mean₀..N of src(p + (c − p) · i/N · reach)  ·  reach = strength · amount" };
  const { ctx, W, H, GY, stage, hero, tree, lamp, crate, ring, line, dot, rect, pix, label, DIM, SUN, HERO } = u;
  // RADIAL (zoom) BLUR: for every pixel, walk N steps along the line from
  // it to a CENTRE and average what you find. near the centre the steps
  // are tiny, so it stays sharp; at the edges they stretch into streaks —
  // the camera rushing forward, or the folio's Zoom happening to the whole
  // frame. the amount is an envelope: it slams to 1 while the hero dashes
  // and decays exponentially after, so the blur reads as speed, not as a
  // filter left on. N is the cost — 8 reads per pixel here.
  let hx = W * 0.25, hdir = 1, amount = 0, dashing = 0, timer = 1, cx = W * 0.6, cy = H * 0.5, userT = 0, src = null;
  return {
    press(x, y) { cx = x; cy = y; userT = 8; },
    frame(dt, t) {
      timer -= dt; userT -= dt;
      if (timer <= 0) {                                // a dash: the centre goes where the hero is heading
        timer = D.dashEvery; dashing = D.dashDur;
        if (userT <= 0) { cx = hx + hdir * W * 0.3; cy = GY - H * 0.12; }
      }
      if (dashing > 0) { dashing -= dt; hx += hdir * W * D.dashSpeed * dt; amount = Math.min(1, amount + dt * 14); }
      else { hx += hdir * W * 0.1 * dt; amount *= Math.exp(-D.decay * dt); }
      if (hx > W * 0.85) { hx = W * 0.85; hdir = -1; } else if (hx < W * 0.15) { hx = W * 0.15; hdir = 1; }
      stage({ night: 0.25 });
      tree(W * 0.15, GY, H * 0.28); crate(W * 0.84, GY, H * 0.12); lamp(W * 0.5, GY, true);
      for (let i = 0; i < 5; i++) dot(W * (0.1 + i * 0.2), H * 0.2 + (i % 2) * H * 0.1, 2, "#FFF");
      hero(hx, GY, { pose: dashing > 0 ? "jump" : "run", frame: t, face: hdir });
      const N = Math.max(1, D.samples | 0), reach = D.strength * amount;
      if (amount > 0.02) pix(D.scale, (d, w, h) => {   // ← the pass (skipped when there is nothing to blur)
        if (!src || src.length !== d.length) src = new Uint8ClampedArray(d.length);
        src.set(d);
        const s = w / W, cxb = cx * s, cyb = cy * s;
        for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
          const dx = (cxb - x) * reach / N, dy = (cyb - y) * reach / N;
          let r = 0, g = 0, b = 0;
          for (let i = 0; i < N; i++) {                 // N reads along the line to the centre
            const sx = Math.max(0, Math.min(w - 1, (x + dx * i + 0.5) | 0)), sy = Math.max(0, Math.min(h - 1, (y + dy * i + 0.5) | 0)), si = (sy * w + sx) * 4;
            r += src[si]; g += src[si + 1]; b += src[si + 2];
          }
          const o = (y * w + x) * 4;
          d[o] = r / N; d[o + 1] = g / N; d[o + 2] = b / N;
        }
      });
      ring(cx, cy, 6, SUN, 1.5); line(cx - 10, cy, cx + 10, cy, SUN); line(cx, cy - 10, cx, cy + 10, SUN);   // the centre
      const pts = [[0.1, 0.12], [0.9, 0.12], [0.1, 0.7]];   // three sample lines, N dots each
      for (let i = 0; i < pts.length; i++) {
        const px = pts[i][0] * W, py = pts[i][1] * H;
        line(px, py, px + (cx - px) * reach, py + (cy - py) * reach, "rgba(138,217,245,0.5)", 1);
        for (let k = 0; k < N; k++) dot(px + (cx - px) * reach * k / N, py + (cy - py) * reach * k / N, 1.3, HERO);
      }
      rect(8, 10, W * 0.25, 4, "rgba(232,229,244,0.15)"); rect(8, 10, W * 0.25 * amount, 4, SUN);
      label("amount " + amount.toFixed(2) + " · N = " + N, 8, 24, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Zoomblur", "Zoomimpact", "a hard hit instead of a dash: strong blur that slams in for a frame and decays away — the impact frame", { strength: 0.75, dashDur: 0.06, decay: 2.2 });

def("G", "Godrays", "screen", "god rays: threshold the bright pixels, smear them toward the sun, add them back — the trees cut the shafts (the atlas's Motes) — press to move the sun", function (u) {
  var D = { threshold: 205,     // luminance above this counts as light
            samples: 12,        // steps toward the sun per pixel
            density: 0.7,       // how far toward the sun the last step reaches (fraction of the distance)
            weight: 0.6,        // how much of the smear is added back
            decay: 0.9,         // each step counts this much less than the last
            sunY: 0.32,         // the sun's height, as a fraction of H
            sunCol: "#FFF0B8",  // the colour the rays add
            drift: 0.05,        // the sun's wander, in cycles per second
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "bright = lum > T · rays = Σᵢ bright(p + (sun − p)·i/N·density)·decayⁱ · out = src + w·rays" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, crate, glow, dot, ring, line, pix, label, col, clamp, DIM } = u;
  // GOD RAYS (crepuscular rays) are a radial blur that only the light is
  // allowed into. THRESHOLD: a mask of the pixels brighter than T — the sun
  // and little else. SMEAR: from every pixel, step toward the sun's screen
  // position N times, summing the mask with a decay per step. ADD: pour the
  // sum back onto the frame in the sun's colour. anything dark between a
  // pixel and the sun (the trees, the hero) leaves a hole in its sum, and
  // those holes are the shafts. the atlas's Motes, made of light itself.
  let ux = W * 0.5, uy = H * D.sunY, bright = null, hx = W * 0.4, hdir = 1;
  return {
    press(x, y) { ux = x; uy = clamp(y, H * 0.05, GY - H * 0.05); },
    frame(dt, t) {
      hx += hdir * W * 0.12 * dt; if (hx > W * 0.8) hdir = -1; else if (hx < W * 0.2) hdir = 1;
      const sx = ux + Math.sin(t * D.drift * TAU) * W * 0.22, sy = uy + Math.cos(t * D.drift * TAU * 0.7) * H * 0.04;
      stage({ night: 0.4 });
      glow(sx, sy, H * 0.3, D.sunCol, 0.55); dot(sx, sy, H * 0.06, "#FFFDF0");   // the sun: the only thing past the threshold
      const dark = "#141C18";
      tree(W * 0.18, GY, H * 0.42, dark); tree(W * 0.36, GY - 2, H * 0.32, dark); tree(W * 0.66, GY, H * 0.46, dark); tree(W * 0.86, GY - 2, H * 0.3, dark);
      crate(W * 0.52, GY, H * 0.1);
      hero(hx, GY, { pose: "run", frame: t, face: hdir });
      const N = Math.max(1, D.samples | 0), c = col(D.sunCol), T = D.threshold;
      pix(D.scale, (d, w, h) => {                       // ← the pass
        if (!bright || bright.length !== w * h) bright = new Uint8Array(w * h);
        for (let i = 0, o = 0; i < w * h; i++, o += 4) bright[i] = (0.299 * d[o] + 0.587 * d[o + 1] + 0.114 * d[o + 2]) > T ? 1 : 0;   // the threshold mask
        const s = w / W, sxb = sx * s, syb = sy * s;
        for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
          const dx = (sxb - x) * D.density / N, dy = (syb - y) * D.density / N;
          let acc = 0, wgt = 1;
          for (let i = 1; i <= N; i++) {                // step toward the sun, summing the mask
            const px = (x + dx * i + 0.5) | 0, py = (y + dy * i + 0.5) | 0;
            if (px >= 0 && px < w && py >= 0 && py < h) acc += bright[py * w + px] * wgt;
            wgt *= D.decay;
          }
          const k = acc / N * D.weight, o = (y * w + x) * 4;
          d[o] += c[0] * k; d[o + 1] += c[1] * k; d[o + 2] += c[2] * k;   // added back, in the sun's colour
        }
      });
      ring(sx, sy, H * 0.075, "rgba(245,193,105,0.7)", 1); label("lum > " + T, sx, sy - H * 0.09, "rgba(245,193,105,0.8)", "center");
      const pts = [[0.06, 0.94], [0.94, 0.92]];        // two sample rays, N dots each
      for (let i = 0; i < pts.length; i++) {
        const px = pts[i][0] * W, py = pts[i][1] * H;
        line(px, py, px + (sx - px) * D.density, py + (sy - py) * D.density, "rgba(255,240,184,0.35)", 1);
        for (let k = 1; k <= N; k++) dot(px + (sx - px) * D.density * k / N, py + (sy - py) * D.density * k / N, 1.2, "rgba(255,240,184," + Math.pow(D.decay, k) + ")");
      }
      label("N = " + N + " · density " + D.density + " · decay " + D.decay, 8, 18, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Godrays", "Gloaming", "a low red sun and long dim rays through the trees — the last light of the day", { sunCol: "#FF6A45", sunY: 0.64, density: 0.95 });

def("K", "Kelvin", "screen", "colour grading: saturation, then a per-channel curve — contrast, warmth, posterise — the three curves drawn (the atlas's Old photo, live) — press to cycle", function (u) {
  var D = { grade: "none",      // the preset in use: "none" | "sepia" | "night" | "danger" | "posterise" | "custom"
            presets: { none:      { contrast: 1,    sat: 1,    warm: 0,     levels: 0 },
                       sepia:     { contrast: 1.05, sat: 0.12, warm: 0.55,  levels: 0 },
                       night:     { contrast: 0.9,  sat: 0.5,  warm: -0.8,  levels: 0 },
                       danger:    { contrast: 1.25, sat: 0.55, warm: 0.9,   levels: 0 },
                       posterise: { contrast: 1.1,  sat: 1.3,  warm: 0,     levels: 4 } },
            custom: { contrast: 1, sat: 1, warm: 0, levels: 0 },   // the "custom" grade: yours to turn
            order: ["none", "sepia", "night", "danger", "posterise"],   // what a press cycles through
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "c' = lum + (c − lum)·sat → LUTc: (c' − 128)·contrast + 128 ± warm → ⌊·L⌋/L" };
  const { ctx, W, H, GY, stage, hero, tree, lamp, crate, dot, rect, pix, label, text, hsl, DIM, BONE } = u;
  // COLOUR GRADING is a function of colour applied to every pixel, and most
  // of it is PER-CHANNEL: contrast (stretch about the middle), warmth (a
  // Kelvin-ish tilt: red up and blue down, or the reverse), and POSTERISE
  // (round to L steps). anything per-channel can be baked into three
  // 256-entry LOOKUP TABLES — the three curves drawn at the top right — so
  // the pass is three reads. SATURATION mixes channels (toward or away from
  // the pixel's luminance), so it runs first, before the tables. the atlas
  // faked an old photo with a tint; this is the tint as arithmetic.
  const lut = new Uint8Array(768);
  let cur = D.grade;
  function build() {
    const p = cur === "custom" ? D.custom : (D.presets[cur] || D.presets.none), L = Math.max(0, (p.levels | 0) - 1);
    for (let c = 0; c < 3; c++) for (let v = 0; v < 256; v++) {
      let x = (v - 128) * p.contrast + 128 + p.warm * (c === 0 ? 45 : c === 2 ? -45 : -6);
      if (L > 0) x = Math.round(x / 255 * L) / L * 255;   // posterise: L steps
      lut[c * 256 + v] = x < 0 ? 0 : x > 255 ? 255 : x;
    }
    return p;
  }
  let P = build(), hx = W * 0.3, hdir = 1;
  return {
    press() { const cyc = D.order.indexOf(D.grade) < 0 ? D.order.concat([D.grade]) : D.order; cur = cyc[(cyc.indexOf(cur) + 1) % cyc.length]; P = build(); },
    frame(dt, t) {
      hx += hdir * W * 0.15 * dt; if (hx > W * 0.8) hdir = -1; else if (hx < W * 0.2) hdir = 1;
      stage({ night: 0 });
      for (let i = 0; i < 6; i++) dot(W * (0.12 + i * 0.15), H * 0.22 + Math.sin(t * 1.3 + i) * H * 0.05, H * 0.05, hsl(i * 60, 0.8, 0.6));
      tree(W * 0.15, GY, H * 0.28); crate(W * 0.84, GY, H * 0.12); lamp(W * 0.62, GY, true);
      hero(hx, GY, { pose: "run", frame: t, face: hdir });
      const sat = P.sat;
      pix(D.scale, (d, w, h) => {                       // ← the pass
        for (let o = 0; o < d.length; o += 4) {
          const r = d[o], g = d[o + 1], b = d[o + 2], lum = 0.299 * r + 0.587 * g + 0.114 * b;
          let r2 = lum + (r - lum) * sat, g2 = lum + (g - lum) * sat, b2 = lum + (b - lum) * sat;   // saturation first
          r2 = r2 < 0 ? 0 : r2 > 255 ? 255 : r2; g2 = g2 < 0 ? 0 : g2 > 255 ? 255 : g2; b2 = b2 < 0 ? 0 : b2 > 255 ? 255 : b2;
          d[o] = lut[r2 | 0]; d[o + 1] = lut[256 + (g2 | 0)]; d[o + 2] = lut[512 + (b2 | 0)];   // then the three curves
        }
      });
      const gs = Math.max(20, H * 0.15), gx0 = W - 8 - gs * 3 - 8, gy0 = 8, cols = ["#F55", "#5F5", "#58F"];   // the three curves
      for (let c = 0; c < 3; c++) {
        const gx = gx0 + c * (gs + 4);
        rect(gx, gy0, gs, gs, "rgba(19,16,32,0.6)");
        ctx.strokeStyle = "rgba(201,196,228,0.3)"; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(gx, gy0 + gs); ctx.lineTo(gx + gs, gy0); ctx.stroke();   // identity
        ctx.strokeStyle = cols[c]; ctx.lineWidth = 1.5; ctx.beginPath();
        for (let i = 0; i <= 16; i++) { const v = i * 255 / 16, y = gy0 + gs - lut[c * 256 + (v | 0)] / 255 * gs, x = gx + i / 16 * gs; if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y); }
        ctx.stroke();
      }
      text(cur, 8, 20, 13, BONE, "left", true);
      label("contrast " + P.contrast + " · sat " + P.sat + " · warm " + P.warm + (P.levels > 1 ? " · L " + P.levels : ""), 8, 32, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Kelvin", "Kodachrome", "the custom grade: high saturation, warm, six posterise levels — slide film", { grade: "custom", custom: { contrast: 1.15, sat: 1.7, warm: 0.35, levels: 6 } });

def("Y", "Yesteryear", "screen", "film grain, live: per-pixel noise, an exposure flicker, gate weave (the frame jitters a pixel), wandering scratches — the folio's Oldfilm — press: grain / static", function (u) {
  var D = { mode: "grain",      // "grain" (film) | "static" (TV snow)
            grain: 0.2,         // noise amplitude, of full brightness
            snow: 0.7,          // static mode: how much of the picture the snow replaces
            scratches: 3,       // vertical scratches wandering at once
            weave: 1.5,         // GATE WEAVE: the frame jitters by up to this many canvas pixels
            weaveHz: 14,        // how often the weave picks a new offset
            flicker: 0.1,       // exposure flicker, ± this fraction
            sepia: 0,           // 0..1: pull colours toward an old print
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "v' = v(p + weave) · flicker + (n − ½)·grain → sepia   ·   scratches wander on noise" };
  const { ctx, W, H, GY, stage, hero, tree, lamp, crate, line, dot, rect, ring, pix, label, noise, rand, DIM, BONE, SUN } = u;
  // FILM GRAIN is noise added per pixel PER FRAME — never the same twice,
  // which is the whole difference from a grain texture pasted on top. the
  // pass also does GATE WEAVE (read the source a pixel or so off, the
  // offset re-rolled a few times a second: the film not sitting still in
  // the gate), an exposure FLICKER (one multiplier per frame from slow
  // noise), and a SEPIA pull toward an old print. STATIC swaps the grain
  // for TV snow that replaces the picture. the scratches are lines drawn
  // after the pass, wandering on noise — the folio's Oldfilm, live.
  let mode = D.mode, src = null, jx = 0, jy = 0, wt = 0, frame = 0, hx = W * 0.3, hdir = 1;
  return {
    press() { mode = mode === "grain" ? "static" : "grain"; },
    frame(dt, t) {
      frame++;
      hx += hdir * W * 0.15 * dt; if (hx > W * 0.8) hdir = -1; else if (hx < W * 0.2) hdir = 1;
      wt -= dt; if (wt <= 0) { wt = 1 / Math.max(0.1, D.weaveHz); jx = rand(-1, 1) * D.weave; jy = rand(-1, 1) * D.weave; }
      const flick = 1 + D.flicker * noise(t * 13);
      stage({ night: 0.15 });
      tree(W * 0.15, GY, H * 0.28); crate(W * 0.84, GY, H * 0.12); lamp(W * 0.62, GY, true);
      hero(hx, GY, { pose: "run", frame: t, face: hdir });
      const grainA = D.grain * 255, snow = mode === "static" ? D.snow : 0, sep = D.sepia;
      pix(D.scale, (d, w, h) => {                       // ← the pass
        if (!src || src.length !== d.length) src = new Uint8ClampedArray(d.length);
        src.set(d);
        const s = w / W, jxb = Math.round(jx * s), jyb = Math.round(jy * s);
        let seed = (frame * 7919 + 17) >>> 0;
        for (let y = 0; y < h; y++) {
          const sy = Math.max(0, Math.min(h - 1, y + jyb));
          for (let x = 0; x < w; x++) {
            const sx = Math.max(0, Math.min(w - 1, x + jxb)), si = (sy * w + sx) * 4, o = (y * w + x) * 4;
            seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;   // one fresh random per pixel per frame
            const n = seed >>> 24;
            let r, g, b;
            if (snow > 0) { r = src[si] * (1 - snow) + n * snow; g = src[si + 1] * (1 - snow) + n * snow; b = src[si + 2] * (1 - snow) + n * snow; }
            else { const gr = (n - 128) / 128 * grainA; r = src[si] * flick + gr; g = src[si + 1] * flick + gr; b = src[si + 2] * flick + gr; }
            if (sep > 0) { const lum = 0.299 * r + 0.587 * g + 0.114 * b; r += (lum * 1.15 - r) * sep; g += (lum * 0.95 - g) * sep; b += (lum * 0.7 - b) * sep; }
            d[o] = r; d[o + 1] = g; d[o + 2] = b;
          }
        }
      });
      for (let i = 0; i < D.scratches; i++) {           // scratches: thin lines that wander and blink
        const x = W * (0.08 + ((i * 0.37) % 0.84)) + noise(t * 2.5 + i * 7) * W * 0.03;
        const on = noise(t * 9 + i * 3.1);
        if (on > 0.05) line(x, 0, x, H, "rgba(255,244,225," + (0.25 + on * 0.3) + ")", 1);
        else if (on < -0.5) line(x + 2, 0, x + 2, H, "rgba(20,12,10,0.5)", 1);
      }
      if (noise(t * 21) > 0.6) dot(W * (0.5 + noise(t * 3) * 0.4), H * (0.5 + noise(t * 4 + 5) * 0.4), 2, "#1A1410");   // a dust speck
      rect(8, 8, 18, 18, "rgba(19,16,32,0.6)"); ring(17, 17, 6, "rgba(201,196,228,0.35)", 1); dot(17 + jx * 3, 17 + jy * 3, 2, SUN);   // the weave, magnified ×3
      label("weave (" + jx.toFixed(1) + ", " + jy.toFixed(1) + ") px", 30, 14, DIM);
      rect(30, 19, W * 0.2, 3, "rgba(232,229,244,0.15)"); rect(30, 19, W * 0.2 * (flick - 0.8) / 0.4, 3, SUN); label("flicker " + flick.toFixed(2), 30 + W * 0.2 + 4, 23, DIM);
      label(mode === "static" ? "static: v = lerp(v, n, " + D.snow + ")" : "grain σ " + D.grain, 8, 40, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Yesteryear", "Yellowed", "a sepia tint, seven scratches and a slow weave — the reel left in the attic", { sepia: 0.85, scratches: 7, weaveHz: 3 });

def("M", "Mosh", "screen", "VHS / datamosh: row blocks of the held frame shifted, a rolling tracking bar, chroma bleed, a frame-hold — the grimoire's Sync loss, live — press to corrupt", function (u) {
  var D = { every: 2.4,         // autopilot: seconds between corruptions
            hold: 0.45,         // FRAME-HOLD: how long the last good frame is shown instead of the live one
            block: 8,           // row block height, canvas pixels
            shift: 0.1,         // a displaced block's slide, as a fraction of the width
            bleed: 2,           // chroma offset in buffer pixels (R left, B right)
            track: 0.35,        // the tracking bar's strength
            trackSpeed: 0.2,    // how fast the bar rolls, screens per second
            scale: 0.5,         // the pixel pass runs at this fraction of the canvas
            label: "rows[b] ← x − shift·hash(b) · R(x − bleed) G(x) B(x + bleed) · hold: show frame t−1" };
  const { ctx, W, H, GY, stage, hero, tree, lamp, crate, glow, layer, pix, label, text, arrow, rect, line, rng, SUN, DIM, HOT } = u;
  // tape damage, as three separate lies. a FRAME-HOLD: the decoder lost a
  // frame, so it shows the previous one again (a layer kept from last
  // frame) while the world moves on — release it and the picture jumps.
  // BLOCK DISPLACEMENT: rows in blocks of `block` pixels slide sideways by
  // a hashed amount that decays — the datamosh smear. And always on: a
  // TRACKING BAR rolling up the frame (rows jittered, brightened, noisy),
  // CHROMA BLEED (red read a little left, blue a little right — the tape
  // stored colour at lower resolution), and head-switching noise on the
  // bottom rows. the grimoire's Sync loss and the folio's Glitch, live.
  const blk = new Float32Array(64);
  let corrupt = 0, holdT = 0, timer = D.every * 0.6, havePrev = false, src = null, hx = W * 0.3, hdir = 1;
  function corruptNow() {
    corrupt = 1; holdT = D.hold;
    const R = rng((Math.random() * 1e9) >>> 0);
    for (let i = 0; i < 64; i++) blk[i] = R() < 0.55 ? (R() - 0.5) * 2 : 0;   // which blocks slide, and how far
  }
  return {
    press() { corruptNow(); },
    frame(dt, t) {
      timer -= dt; if (timer <= 0) { corruptNow(); timer = D.every; }
      holdT = Math.max(0, holdT - dt); corrupt = Math.max(0, corrupt - dt * 1.6);
      hx += hdir * W * 0.15 * dt; if (hx > W * 0.8) hdir = -1; else if (hx < W * 0.2) hdir = 1;
      const P = layer("moshPrev"), holding = holdT > 0 && havePrev;
      if (holding) ctx.drawImage(P.cv, 0, 0, W, H);   // the FRAME-HOLD: last good frame again
      else {
        stage({ night: 0.5 });
        tree(W * 0.15, GY, H * 0.28); crate(W * 0.84, GY, H * 0.12);
        ctx.globalCompositeOperation = "lighter"; glow(W * 0.6, GY - H * 0.3 - 8, H * 0.32, SUN, 0.5); ctx.globalCompositeOperation = "source-over";
        lamp(W * 0.6, GY, true);
        hero(hx, GY, { pose: "run", frame: t, face: hdir });
        text("PLAY ▶", 10, 20, 11, "#FFFFFF", "left", true);
        P.ctx.clearRect(0, 0, W, H); P.ctx.drawImage(ctx.canvas, 0, 0, W, H); havePrev = true;   // keep this frame for the next hold
      }
      const trackY = ((t * D.trackSpeed) % 1 + 1) % 1, cor = corrupt;
      pix(D.scale, (d, w, h) => {                       // ← the pass
        if (!src || src.length !== d.length) src = new Uint8ClampedArray(d.length);
        src.set(d);
        const s = w / W, bb = Math.max(1, D.block * s), ty = trackY * h, bandH = Math.max(2, h * 0.09);
        let seed = ((t * 1000) | 0) >>> 0;
        for (let y = 0; y < h; y++) {
          seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
          const bi = (y / bb) | 0, dband = Math.abs(y - ty), inBand = dband < bandH, k = inBand ? 1 - dband / bandH : 0;
          let rs = 0;
          if (cor > 0) rs += blk[bi & 63] * D.shift * w * cor;                                   // block displacement
          if (inBand) rs += ((seed >>> 8) / 16777216 - 0.5) * w * 0.08 * k * D.track;             // the tracking bar jitters its rows
          if (y >= h - 3) rs += ((seed >>> 4) / 268435456 - 0.5) * w * 0.12;                      // head-switching noise
          const bl = Math.round(D.bleed * (inBand ? 3 : 1)), row = y * w, gain = 1 + 0.6 * k * D.track;
          for (let x = 0; x < w; x++) {
            const xr = Math.max(0, Math.min(w - 1, (x - rs - bl + 0.5) | 0)), xg = Math.max(0, Math.min(w - 1, (x - rs + 0.5) | 0)), xb = Math.max(0, Math.min(w - 1, (x - rs + bl + 0.5) | 0));
            const o = (row + x) * 4;
            d[o] = src[(row + xr) * 4] * gain; d[o + 1] = src[(row + xg) * 4 + 1] * gain; d[o + 2] = src[(row + xb) * 4 + 2] * gain;
          }
        }
      });
      const bb = Math.max(1, D.block);                 // the displaced blocks, marked at the left edge
      if (cor > 0) for (let bi = 0; bi * bb < H && bi < 64; bi++) if (blk[bi] !== 0) { const y = bi * bb + bb / 2, dx = blk[bi] * D.shift * W * cor; arrow(6, y, 6 + dx, y, "rgba(245,138,138,0.8)"); }
      line(W - 6, trackY * H - H * 0.09, W - 6, trackY * H + H * 0.09, SUN, 2); label("tracking", W - 10, trackY * H + 3, "rgba(245,193,105,0.8)", "right");
      if (holding) text("HOLD  frame t−1", W / 2, H * 0.14, 12, HOT, "center", true);
      label("bleed " + D.bleed + "px · block " + D.block + " · " + (cor > 0 ? "corrupt " + cor.toFixed(2) : "clean"), 8, 34, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Mosh", "Magnetic", "tracking only: no block shifts, no hold, a hair of bleed — a worn tape playing fine", { shift: 0, hold: 0, bleed: 1 });
/* ============================== SPRITE & MATERIAL SHADERS ==============================
   The sprite's own skin. Nothing in this family moves the hero differently —
   it changes what the pixels ARE: brightness remapped through a palette
   (frozen, stone, gold, ghost), a tint whose alpha rides a wave (poisoned,
   burning, stunned), rows of the sprite slid sideways by a sine or by height
   (jelly, wind, grass), a mask borrowed from another shape (the X-ray
   silhouette, the wet-floor reflection, the sheared shadow), nearest versus
   bilinear and rotation snapped to steps, a panel cut into nine, lighting
   quantised into bands, water bending what lies behind it, and a hologram of
   scanlines and a dilated rim. Every one is a fragment shader spelled in
   canvas: strips, clips, composite operations and ImageData. */

def("F", "Frozen", "skin", "GRADIENT MAP: each pixel's brightness picks a colour on a 4-stop palette, swept up from the feet — ch03's palette swap, per pixel — press to freeze / thaw", function (u) {
  var D = { state: "frozen",         // frozen / petrified / gilded / ghost — a palette + an overlay each
            states: { frozen:    { map: ["#16224E", "#3B7FC8", "#A8E4F8", "#FFFFFF"], overlay: "frost",  alpha: 1 },
                      petrified: { map: ["#1A181C", "#4E4A52", "#8E8A90", "#DCD8D4"], overlay: "cracks", alpha: 1 },
                      gilded:    { map: ["#4A2A08", "#B8781E", "#F2C25A", "#FFF4C0"], overlay: "sheen",  alpha: 1 },
                      ghost:     { map: ["#2A3A5A", "#6A9AC8", "#C8E8F8", "#FFFFFF"], overlay: "none",   alpha: 0.45 } },
            sweep: 1.2,              // seconds for the freeze line to climb from the feet to the hair
            hold: 2.6,               // seconds held in the state before it thaws
            free: 3.2,               // seconds of free running between applications
            speed: 0.28,             // run speed, screens per second
            label: "lum = .299r + .587g + .114b → map[lum·3] · clip: y > feet − k·h" };
  const { ctx, W, H, GY, stage, hero, heroSprite, layer, label, text, rect, line, clamp, col, rng, INK, DIM } = u;
  // a STATE SHADER does not change the drawing — it changes what the pixels
  // ARE. read the sprite's own pixels, take each one's brightness (the
  // luminance formula) and use it as a position along a four-stop palette: a
  // GRADIENT MAP. dark hair becomes deep ice-blue, the pale face near white,
  // and every state — frozen, stone, gold, ghost — is only a different palette
  // plus an overlay pattern stamped source-atop. the FREEZE-IN SWEEP is a clip
  // rectangle whose top climbs from the feet. chapter 03's palette swap, done
  // per pixel instead of per colour; the mapped sprite is built once and cached.
  const S = D.states[D.state] || D.states.frozen;
  const stops = S.map.map(col);
  let phase = "free", timer = 0, k = 0, fz = 0, x = W * 0.3, dir = 1, built = "";
  function frameOf(clock) { return (Math.floor(clock * 12) % 7) / 10; }
  function build(spr) {
    const key = D.state + "|" + spr.s + "|" + fz + "|" + dir;
    const L = layer("frozen-map");
    if (built === key) return L;
    built = key;
    const c = L.ctx, w = spr.w, h = spr.h;
    c.save(); c.globalCompositeOperation = "source-over"; c.globalAlpha = 1;
    c.clearRect(0, 0, w, h);
    c.drawImage(spr.cv, 0, 0);
    const img = c.getImageData(0, 0, w, h), d = img.data;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] === 0) continue;
      const lum = (0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]) / 255;   // brightness → position on the map
      const p = clamp(lum, 0, 0.999) * (stops.length - 1), j = Math.floor(p), f = p - j;
      const a = stops[j], b = stops[j + 1];
      d[i] = a[0] + (b[0] - a[0]) * f; d[i + 1] = a[1] + (b[1] - a[1]) * f; d[i + 2] = a[2] + (b[2] - a[2]) * f;
    }
    c.putImageData(img, 0, 0);
    c.globalCompositeOperation = "source-atop";        // the overlay lands only on sprite pixels
    const R = rng(11);
    if (S.overlay === "frost") {
      c.strokeStyle = "rgba(255,255,255,0.35)"; c.lineWidth = 1;
      c.beginPath();
      for (let q = -h; q < w; q += Math.max(3, spr.s * 1.5)) { c.moveTo(q, 0); c.lineTo(q + h, h); }
      c.stroke();
      c.fillStyle = "rgba(255,255,255,0.9)";
      for (let n = 0; n < 14; n++) c.fillRect(Math.floor(R() * w), Math.floor(R() * h), 1, 1);
    } else if (S.overlay === "cracks") {
      c.strokeStyle = "rgba(0,0,0,0.65)"; c.lineWidth = 1;
      for (let n = 0; n < 4; n++) {
        let cx = R() * w, cy = R() * h;
        c.beginPath(); c.moveTo(cx, cy);
        for (let m = 0; m < 5; m++) { cx += (R() - 0.5) * w * 0.4; cy += (R() - 0.3) * h * 0.25; c.lineTo(cx, cy); }
        c.stroke();
      }
    } else if (S.overlay === "sheen") {
      const g = c.createLinearGradient(0, 0, w, h);
      g.addColorStop(0, "rgba(255,255,255,0)"); g.addColorStop(0.42, "rgba(255,255,255,0)");
      g.addColorStop(0.5, "rgba(255,255,255,0.6)"); g.addColorStop(0.58, "rgba(255,255,255,0)"); g.addColorStop(1, "rgba(255,255,255,0)");
      c.fillStyle = g; c.fillRect(0, 0, w, h);
    }
    c.restore();
    return L;
  }
  return {
    press() {
      if (phase === "free" || phase === "thaw") { phase = "freeze"; timer = k * D.sweep; }
      else { phase = "thaw"; timer = (1 - k) * D.sweep; }
    },
    frame(dt, t) {
      stage({ night: 0.15 });
      timer += dt;
      if (phase === "free") {
        x += dir * W * D.speed * dt;
        if (x > W * 0.85) { x = W * 0.85; dir = -1; }
        if (x < W * 0.15) { x = W * 0.15; dir = 1; }
        fz = frameOf(t); k = 0;
        if (timer > D.free) { phase = "freeze"; timer = 0; }
      } else if (phase === "freeze") { k = clamp(timer / D.sweep, 0, 1); if (k >= 1) { phase = "hold"; timer = 0; } }
      else if (phase === "hold") { k = 1; if (timer > D.hold) { phase = "thaw"; timer = 0; } }
      else { k = 1 - clamp(timer / D.sweep, 0, 1); if (k <= 0) { k = 0; phase = "free"; timer = 0; } }
      const spr = heroSprite({ pose: "run", frame: fz, face: dir });
      const x0 = x - spr.ax, y0 = GY - spr.ay, lineY = y0 + (1 - k) * spr.h;
      if (k < 1) {                                       // the unfrozen part: the ordinary hero, clipped above the line
        ctx.save(); ctx.beginPath(); ctx.rect(x0 - 2, y0 - 2, spr.w + 4, Math.max(0, lineY - y0 + 2)); ctx.clip();
        hero(x, GY, { pose: "run", frame: fz, face: dir });
        ctx.restore();
      }
      if (k > 0) {                                       // the frozen part: the gradient-mapped copy, clipped below it
        const L = build(spr);
        ctx.save(); ctx.beginPath(); ctx.rect(x0 - 2, lineY, spr.w + 4, y0 + spr.h - lineY + 2); ctx.clip();
        ctx.globalAlpha = S.alpha;
        ctx.drawImage(L.cv, 0, 0, spr.w, spr.h, x0, y0, spr.w, spr.h);
        ctx.restore();
        if (k < 1) {
          line(x0 - 6, lineY, x0 + spr.w + 6, lineY, "rgba(255,255,255,0.85)", 1);
          label("k = " + k.toFixed(2), x0 + spr.w + 9, lineY + 3, DIM);
        }
      }
      // the map itself: luminance 0 → 1 along the bottom axis, the four stops above it
      const bw = W * 0.3, bx = 10, by = 12;
      const g = ctx.createLinearGradient(bx, 0, bx + bw, 0);
      for (let i = 0; i < S.map.length; i++) g.addColorStop(i / (S.map.length - 1), S.map[i]);
      ctx.fillStyle = g; ctx.fillRect(bx, by, bw, 6);
      for (let i = 0; i < S.map.length; i++) rect(bx + i / (S.map.length - 1) * bw - 1, by - 2, 2, 10, INK);
      label("lum 0", bx, by + 18, DIM); label("1", bx + bw, by + 18, DIM, "right");
      text(D.state + " · " + S.overlay, bx, by + 30, 10, INK);
      label(phase, x, y0 - 8, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Frozen", "Fossil", "the petrified palette with its cracks, a slow sweep and a long hold — turned to stone, and staying that way", { state: "petrified", sweep: 3.2, hold: 4.5 });

def("F", "Flicker", "skin", "STATUS TINTS: one colour per status, its alpha on a wave — poison a slow sine, burning a fast one, stun a hard blink — stacked source-atop — press to cycle", function (u) {
  var D = { statuses: { poison:  { colour: "#7FE07A", wave: "sine",   rate: 0.7, min: 0.12, max: 0.5,  glyph: "☠" },
                        burning: { colour: "#FF8A3A", wave: "sine",   rate: 3.2, min: 0.2,  max: 0.6,  glyph: "▲", embers: true },
                        stunned: { colour: "#FFFFFF", wave: "square", rate: 4,   min: 0,    max: 0.75, glyph: "★", halt: true } },
            cycleEvery: 2.6,         // seconds between autopilot status changes
            pace: 0.12,              // the hero's walking speed, screens per second
            night: 0.25,             // how dark the stage is
            label: "α = min + (max − min)·wave(t·rate) · tint: source-atop, one fill per status" };
  const { ctx, W, H, GY, TAU, stage, heroSprite, layer, label, text, dot, rgba, rand, NIGHT, DIM, INK } = u;
  // chapter 03 tinted a sprite by filling over it SOURCE-ATOP — the fill lands
  // only where the sprite already has pixels. a STATUS is that fill with a
  // colour of its own and an alpha that rides a WAVE: poison a slow sine,
  // burning a fast one with embers, stunned a hard square-wave blink. statuses
  // STACK because each fill sits atop the last; the icons above the head list
  // the stack, and the little scopes on the right draw each wave as it plays.
  const names = Object.keys(D.statuses);
  const combos = [[names[0]], [names[1]], [names[2]], [names[0], names[1]], [names[1], names[2]], [names[0], names[1], names[2]], []]
    .map(c => c.filter(n => n !== undefined));
  let combo = 0, autoT = 0, x = W * 0.4, dir = 1, emit = 0;
  const parts = [];
  for (let i = 0; i < 28; i++) parts.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, life: 0, drop: false, c: "#fff" });
  function frameOf(clock) { return (Math.floor(clock * 12) % 7) / 10; }
  function wave(st, clock) {
    const ph = clock * st.rate;
    if (st.wave === "square") return (ph % 1) < 0.5 ? 1 : 0;
    if (st.wave === "saw") return 1 - (ph % 1);
    return 0.5 + 0.5 * Math.sin(ph * TAU);
  }
  return {
    press() { combo = (combo + 1) % combos.length; autoT = -3; },
    frame(dt, t) {
      stage({ night: D.night });
      autoT += dt;
      if (autoT > D.cycleEvery) { autoT = 0; combo = (combo + 1) % combos.length; }
      const active = combos[combo].map(n => D.statuses[n]).filter(s => s);
      let halt = false, slow = 1, sparks = false, drops = false;
      for (const st of active) { if (st.halt) halt = true; if (st.slow) slow *= st.slow; if (st.embers) sparks = true; if (st.drops) drops = true; }
      if (!halt) {
        x += dir * W * D.pace * slow * dt;
        if (x > W * 0.62) { x = W * 0.62; dir = -1; }
        if (x < W * 0.22) { x = W * 0.22; dir = 1; }
      }
      const spr = heroSprite({ pose: halt ? "hurt" : "run", frame: halt ? 0 : frameOf(t), face: dir });
      const x0 = x - spr.ax, y0 = GY - spr.ay;
      // the tint stack, built in a layer: the sprite, then one source-atop fill per status
      const L = layer("status-tint"), c = L.ctx;
      c.clearRect(x0 - 2, y0 - 2, spr.w + 4, spr.h + 4);
      c.drawImage(spr.cv, x0, y0);
      c.globalCompositeOperation = "source-atop";
      for (const st of active) {
        const a = st.min + (st.max - st.min) * wave(st, t);
        c.fillStyle = rgba(st.colour, a); c.fillRect(x0, y0, spr.w, spr.h);
      }
      c.globalCompositeOperation = "source-over";
      ctx.drawImage(L.cv, x0, y0, spr.w, spr.h, x0, y0, spr.w, spr.h);
      // particles: embers rise off a burning body, drops fall off a soaked one
      emit += dt * ((sparks ? 12 : 0) + (drops ? 10 : 0));
      while (emit > 1) {
        emit -= 1;
        const p = parts.find(q => !q.on);
        if (!p) break;
        const isDrop = drops && (!sparks || Math.random() < 0.5);
        const st = active.find(s => isDrop ? s.drops : s.embers) || active[0];
        p.on = true; p.drop = isDrop; p.x = x0 + rand(2, spr.w - 2); p.y = y0 + rand(2, spr.h - 4); p.life = rand(0.4, 0.9);
        p.vx = rand(-8, 8); p.vy = isDrop ? rand(10, 30) : rand(-40, -18); p.c = st ? st.colour : "#fff";
      }
      for (const p of parts) {
        if (!p.on) continue;
        p.life -= dt; if (p.life <= 0) { p.on = false; continue; }
        if (p.drop) p.vy += 140 * dt; else p.vy -= 20 * dt;
        p.x += p.vx * dt; p.y += p.vy * dt;
        if (p.y > GY) { p.on = false; continue; }
        dot(p.x, p.y, p.drop ? 1.4 : 1.2 + p.life, rgba(p.c, Math.min(1, p.life * 1.6)));
      }
      // the icons above the head: the stack, in order
      const s = spr.s;
      for (let i = 0; i < active.length; i++) {
        const st = active[i], ix = x + (i - (active.length - 1) / 2) * s * 4.2, iy = y0 - s * 3;
        dot(ix, iy, s * 1.7, st.colour);
        text(st.glyph, ix, iy + s * 0.8, s * 2.2, NIGHT, "center", true);
      }
      // the scopes: each active wave over the last 1.5 s, the playhead at the right edge
      const bw = W * 0.26, bh = H * 0.07, bx = W - bw - 8;
      for (let i = 0; i < active.length; i++) {
        const st = active[i], by = 10 + i * (bh + 14);
        ctx.strokeStyle = "rgba(232,229,244,0.15)"; ctx.lineWidth = 1; ctx.strokeRect(bx, by, bw, bh);
        ctx.strokeStyle = st.colour; ctx.lineWidth = 1.2; ctx.beginPath();
        for (let j = 0; j <= 30; j++) {
          const a = st.min + (st.max - st.min) * wave(st, t - 1.5 + j / 30 * 1.5);
          const px = bx + j / 30 * bw, py = by + bh - a * bh;
          if (j === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        }
        ctx.stroke();
        label(names[Object.values(D.statuses).indexOf(st)] + " · " + st.wave + " " + st.rate + " Hz", bx, by + bh + 10, DIM);
      }
      if (!active.length) label("no status — press to add one", W - 8, 18, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Flicker", "Frostbite", "the cold stack — chilled (a slow pale pulse), soaked (deep blue, dripping), slowed (a purple sawtooth that halves the walk)", {
  statuses: { chilled: { colour: "#BFEFFF", wave: "sine", rate: 0.35, min: 0.2, max: 0.55, glyph: "❄" },
              soaked:  { colour: "#3A78D8", wave: "sine", rate: 1.1, min: 0.25, max: 0.5, glyph: "●", drops: true },
              slowed:  { colour: "#9A7AE0", wave: "saw", rate: 0.5, min: 0.1, max: 0.6, glyph: "◔", slow: 0.45 } },
  night: 0.55 });

def("J", "Jelly", "skin", "a WOBBLE shader: the sprite in strips, each slid by sin(y·k + t·w)·amp — jelly, heat, underwater — the bestiary's heat haze on a body — press to poke", function (u) {
  var D = { mode: "jelly",           // jelly (a poke's wobble decays) / heat / underwater
            modes: { jelly:      { amp: 0.22, k: 1.6, w: 16, decay: 3.2, pin: 1 },
                     heat:       { amp: 0.05, k: 4.0, w: 30, decay: 0,   pin: 0 },
                     underwater: { amp: 0.12, k: 1.2, w: 4,  decay: 0,   pin: 0 } },
            ampScale: 1,             // multiplies every mode's amplitude
            speedScale: 1,           // multiplies every mode's w
            strip: 0.5,              // strip height in sprite units (0.5 = two strips per pixel row)
            pokeEvery: 2.6,          // seconds between autopilot pokes
            label: "x' = x + sin(y·k + t·w) · amp · env(y)" };
  const { ctx, W, H, GY, TAU, stage, heroSprite, label, text, line, rect, glow, dot, rgba, rand, FIRE, WATER, DIM, INK } = u;
  // a VERTEX SHADER moves where pixels land, not what they are. in 2D the
  // cheapest version is horizontal STRIPS: draw the sprite one thin row at a
  // time, each row shifted sideways by a sine of its height and the clock.
  // JELLY pins the feet (the envelope grows with height) and lets the
  // amplitude decay after a poke; HEAT is a tiny, fast, everywhere shimmer —
  // the bestiary's heat haze applied to a body; UNDERWATER is big and slow.
  // the curve beside the sprite is the offset itself, row by row.
  const unit = Math.max(2, Math.round(H / 60)), S = unit * 2;
  let age = 9, autoT = 0;
  const bubbles = [];
  for (let i = 0; i < 10; i++) bubbles.push({ x: rand(0, W), y: rand(0, GY), r: rand(1, 3), v: rand(8, 20) });
  return {
    press() { age = 0; autoT = 0; },
    frame(dt, t) {
      const m = D.modes[D.mode] || D.modes.jelly;
      stage({ night: D.mode === "underwater" ? 0.4 : 0.1 });
      autoT += dt; age += dt;
      if (autoT > D.pokeEvery) { autoT = 0; age = 0; }
      if (D.mode === "underwater") {
        rect(0, 0, W, H, rgba(WATER, 0.28));
        for (const b of bubbles) { b.y -= b.v * dt; if (b.y < 0) { b.y = GY; b.x = rand(0, W); } ctx.strokeStyle = "rgba(255,255,255,0.35)"; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, TAU); ctx.stroke(); }
      }
      const spr = heroSprite({ s: S, pose: "stand", frame: 0 });
      const x = W * 0.42, x0 = x - spr.ax, y0 = GY - spr.ay;
      if (D.mode === "heat") { glow(x, GY + 2, spr.w * 0.9, FIRE, 0.7); for (let i = 0; i < 5; i++) dot(x + rand(-spr.w * 0.4, spr.w * 0.4), GY - rand(0, spr.h * 0.5), 1.2, rgba(FIRE, 0.5)); }
      // the amplitude: a decaying poke for jelly, a constant plus a decaying poke bonus otherwise
      const amp = m.amp * D.ampScale * spr.w * (m.decay > 0 ? Math.exp(-m.decay * age) : 1 + 1.5 * Math.exp(-3 * age));
      const w = m.w * D.speedScale, sh = Math.max(1, S * D.strip), n = Math.ceil(spr.h / sh);
      const gx = x0 + spr.w + W * 0.12;
      ctx.strokeStyle = "rgba(232,229,244,0.2)"; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(gx, y0); ctx.lineTo(gx, y0 + spr.h); ctx.stroke();
      ctx.strokeStyle = INK; ctx.lineWidth = 1.2; ctx.beginPath();
      for (let j = 0; j < n; j++) {
        const sy = j * sh, yf = (sy + sh / 2) / spr.h;      // 0 at the hair, 1 at the feet
        const env = m.pin ? 1 - yf : 1;                     // pinned feet: the top wobbles, the feet stay
        const off = Math.sin(yf * m.k * TAU + t * w) * amp * env;
        ctx.drawImage(spr.cv, 0, sy, spr.w, Math.min(sh, spr.h - sy), x0 + off, y0 + sy, spr.w, Math.min(sh, spr.h - sy));
        if (j === 0) ctx.moveTo(gx + off, y0 + sy + sh / 2); else ctx.lineTo(gx + off, y0 + sy + sh / 2);
      }
      ctx.stroke();
      label("offset(y)", gx, y0 - 6, DIM, "center");
      text(D.mode, 10, 18, 11, INK, "left", true);
      label("amp " + (amp / spr.w).toFixed(2) + "·w  k " + m.k + "  w " + w.toFixed(1) + (m.decay ? "  decay " + m.decay : ""), 10, 32, DIM);
      if (age < 0.4) label("poke", x, y0 - 10, "rgba(245,138,138," + (1 - age / 0.4) + ")", "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Jelly", "Jiggly", "underwater, twice the amplitude and half the speed — the whole body swaying like weed in a slow current", { mode: "underwater", ampScale: 2.2, speedScale: 0.6 });

def("S", "Sway", "skin", "WIND SWAY: strips slide by noise(t + x) · distance-from-pivot^p — a tree, a banner and a hanging sign bend most at the far end — press to gust from that side", function (u) {
  var D = { amp: 0.06,               // full-wind displacement at the tip, as a fraction of H
            freq: 0.5,               // how fast the noise wind changes
            power: 1.6,              // displacement ∝ height^power: a bending trunk, not a hinge
            strips: 14,              // strips per object
            gust: 2.2,               // a gust's peak strength, in wind units
            gustDecay: 1.1,          // how fast a gust dies, per second
            autoGust: 3.6,           // seconds between autopilot gusts
            broken: false,           // a torn banner instead of a whole one
            label: "dx = wind(t, x) · (h / H)^p · amp · wind = noise(t·f + x) + gust" };
  const { ctx, W, H, GY, stage, layer, label, text, line, arrow, rect, noise, clamp, rand, BONE, HOT, SUN, DIM, INK } = u;
  // everything that stands in the wind is drawn ONCE, upright, into a layer;
  // every frame it is copied back in horizontal STRIPS, each slid sideways by
  // the wind times how far it is from its PIVOT. a tree and a banner pivot at
  // the ground, so the top moves most (∝ height^p — a bend, not a hinge); the
  // sign hangs from its bracket, so its bottom moves most. the wind is one
  // noise value sampled at the clock plus each object's x, so they never
  // agree exactly, and a GUST is a spike added on top that decays.
  const objs = [
    { kind: "base", x: W * 0.2,  x0: W * 0.07, w: W * 0.26, top: GY - H * 0.56, bot: GY },
    { kind: "base", x: W * 0.5,  x0: W * 0.47, w: W * 0.19, top: GY - H * 0.58, bot: GY },
    { kind: "hang", x: W * 0.83, x0: W * 0.78, w: W * 0.2,  top: GY - H * 0.5,  bot: GY - H * 0.5 + H * 0.24 } ];
  let srcW = 0, gustA = 0, gustDir = 1, autoT = 0;
  function build() {
    const L = layer("sway-src");
    if (srcW === L.W) return L;
    srcW = L.W;
    const c = L.ctx;
    c.clearRect(0, 0, L.W, L.H);
    let o = objs[0];                                     // the tree: trunk + two canopy triangles
    c.fillStyle = "#5A3E2B"; c.fillRect(o.x - W * 0.012, o.top + H * 0.2, W * 0.024, GY - o.top - H * 0.2);
    c.fillStyle = "#3E7A48";
    c.beginPath(); c.moveTo(o.x, o.top); c.lineTo(o.x + W * 0.11, o.top + H * 0.3); c.lineTo(o.x - W * 0.11, o.top + H * 0.3); c.closePath(); c.fill();
    c.beginPath(); c.moveTo(o.x, o.top + H * 0.12); c.lineTo(o.x + W * 0.125, o.top + H * 0.42); c.lineTo(o.x - W * 0.125, o.top + H * 0.42); c.closePath(); c.fill();
    o = objs[1];                                         // the banner: a pole and a cloth to its right
    c.fillStyle = BONE; c.fillRect(o.x - 1.5, o.top, 3, GY - o.top);
    c.fillStyle = HOT;
    const cw = W * 0.14, ch = D.broken ? H * 0.11 : H * 0.24;
    c.beginPath(); c.moveTo(o.x + 1, o.top + 3); c.lineTo(o.x + cw, o.top + 3);
    if (D.broken) { for (let i = 0; i < 6; i++) c.lineTo(o.x + cw - (i + 1) * cw / 6, o.top + 3 + ch - (i % 2) * H * 0.045); }
    else { c.lineTo(o.x + cw, o.top + 3 + ch); c.lineTo(o.x + cw * 0.7, o.top + 3 + ch * 0.8); c.lineTo(o.x + 1, o.top + 3 + ch); }
    c.closePath(); c.fill();
    o = objs[2];                                         // the sign: two chains and a board (the bracket is drawn live, it does not move)
    c.strokeStyle = BONE; c.lineWidth = 1;
    c.beginPath(); c.moveTo(o.x - W * 0.04, o.top); c.lineTo(o.x - W * 0.04, o.top + H * 0.06); c.moveTo(o.x + W * 0.04, o.top); c.lineTo(o.x + W * 0.04, o.top + H * 0.06); c.stroke();
    c.fillStyle = "#8A6A3E"; c.fillRect(o.x - W * 0.045, o.top + H * 0.06, W * 0.09, H * 0.16);
    c.fillStyle = SUN; c.font = "700 " + Math.round(H * 0.06) + "px system-ui, sans-serif"; c.textAlign = "center";
    c.fillText("INN", o.x, o.top + H * 0.16);
    return L;
  }
  return {
    press(x) { gustDir = x < W / 2 ? 1 : -1; gustA = 1; autoT = 0; },
    frame(dt, t) {
      stage({ night: 0.1 });
      const L = build();
      autoT += dt;
      if (autoT > D.autoGust) { autoT = 0; gustA = 1; gustDir = Math.random() < 0.5 ? 1 : -1; }
      gustA = Math.max(0, gustA - dt * D.gustDecay);
      const gust = gustDir * D.gust * gustA * gustA;      // the spike: peaks at once, dies as a square
      const s = objs[2];                                   // the bracket: post + arm, rigid
      rect(s.x - W * 0.09, s.top - 2, W * 0.012, GY - s.top + 2, "#4A4470"); rect(s.x - W * 0.09, s.top - 3, W * 0.14, 3, "#4A4470");
      let windC = 0;
      for (const o of objs) {
        const wind = clamp(noise(t * D.freq + o.x / W * 1.7) + gust, -2.5, 2.5);
        if (o === objs[1]) windC = wind;
        const n = Math.max(2, Math.round(D.strips)), span = o.bot - o.top, sh = span / n;
        for (let j = 0; j < n; j++) {
          const sy = o.top + j * sh;
          const f = o.kind === "base" ? 1 - (j + 0.5) / n : (j + 0.5) / n;     // distance from the pivot, 0..1
          const dx = wind * (o.kind === "base" ? Math.pow(f, D.power) : f * 0.6) * D.amp * H;
          ctx.drawImage(L.cv, o.x0, sy, o.w, sh + 0.6, o.x0 + dx, sy, o.w, sh + 0.6);
        }
        line(o.x, o.kind === "base" ? o.bot : o.top, o.x, o.kind === "base" ? o.top : o.bot, "rgba(232,229,244,0.12)", 1);   // the rest line
      }
      const ax = W * 0.5, ay = H * 0.1;                    // the wind, as an arrow
      arrow(ax - windC * W * 0.08, ay, ax + windC * W * 0.08, ay, gustA > 0.05 ? HOT : INK);
      label("wind " + windC.toFixed(2) + (gustA > 0.05 ? " (gust)" : ""), ax, ay - 6, DIM, "center");
      label("pivot: base — dx ∝ h^" + D.power, objs[0].x, GY + 14, DIM, "center");
      label("pivot: top — dx ∝ depth", objs[2].x, objs[2].bot + 12, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Sway", "Storm", "more than twice the amplitude, a wind that changes three times as fast, and the banner torn — the night the sign came down", { amp: 0.14, freq: 1.5, broken: true });

def("G", "Grass", "skin", "INTERACTIVE GRASS: every blade is a chain of angles on the lexicon's Damp spring — the root pushed away from the nearest body, each joint above chasing the one below on its own quicker, under-damped spring, so the tip lags and whips through after the body has passed — drag to walk the hero through", function (u) {
  var D = { blades: 70,              // blades per 250 px of width
            k: 60,                   // the root spring's stiffness
            damp: 12,                // its damping (2√k would be critical)
            joints: 3,               // segments per blade: the root + the joints that follow it (1 = the old rigid needle)
            tip: 1.4,                // each joint's k as a multiple of the one below: above 1 because the segment above is lighter — the same bend rights it faster
            tipdamp: 0.4,            // a joint's damping, as a fraction of ITS OWN critical — well under 1, so the tip overshoots the root and whips through
            lean: 1.1,               // the most a body can push a blade, radians
            reach: 0.09,             // a body's push radius, as a fraction of W
            wind: 0.15,              // the resting lean the wind asks for, radians
            speed: 0.3,              // the hero's run, screens per second
            palette: ["#3E8A38", "#8ED45E"],
            label: "root: θ'' = k·(rest + push − θ) − damp·θ' · joint j: θⱼ'' = kⱼ·(θⱼ₋₁ − θⱼ) − dⱼ·θⱼ' · kⱼ = tip·kⱼ₋₁ · dⱼ = tipdamp·2√kⱼ" };
  const { ctx, W, H, GY, TAU, stage, hero, label, text, poly, ring, line, clamp, mix, rng, noise, DIM, INK, SUN } = u;
  // each blade of grass is a short CHAIN of angles from vertical. the root is
  // one rule: a damped spring toward a resting angle (the lexicon's Damp).
  // the wind moves the rest a little; a BODY nearby pushes the rest away from
  // itself, harder the closer it is, and when the body has passed the spring
  // brings the root back, overshooting a touch because the damping is a
  // little under critical. every JOINT above the root is the same spring
  // again, its rest the angle of the segment below it, quicker (k · tip: the
  // segment above is lighter, so k here is stiffness PER inertia) and much
  // less damped (tipdamp of its own critical) — so the tip lags the root on
  // the way out and whips through it on the way back: real grass is a
  // cantilever, clamped at the ground, that rings from the top.
  // a blade is drawn as a tapered polygon along its segments; the marked
  // blade shows its root θ and its tip θ.
  const n = Math.max(8, Math.round(D.blades * W / 250)), R = rng(5);
  const J = Math.max(1, Math.floor(D.joints));
  const bx = new Float32Array(n), bh = new Float32Array(n), th = new Float32Array(n), om = new Float32Array(n), col = [];
  const tj = new Float32Array(n * (J - 1)), oj = new Float32Array(n * (J - 1));   // joint angles + velocities, blade-major: [i * (J − 1) + j]
  for (let i = 0; i < n; i++) {
    bx[i] = W * 0.02 + R() * W * 0.96; bh[i] = H * (0.07 + R() * 0.1);
    col.push(mix(D.palette[0], D.palette[1], R()));
  }
  let hx = W * 0.2, tx = W * 0.8, dir = 1, autoT = 0, manual = 0;
  function frameOf(clock) { return (Math.floor(clock * 12) % 7) / 10; }
  return {
    drag: true,
    press(x) { tx = clamp(x, W * 0.04, W * 0.96); manual = 4; },
    frame(dt, t) {
      stage({ night: 0.1 });
      manual -= dt; autoT += dt;
      if (manual <= 0 && Math.abs(tx - hx) < 4) tx = hx < W / 2 ? W * 0.9 : W * 0.1;   // autopilot: the far side
      const d = tx - hx, step = W * D.speed * dt;
      if (Math.abs(d) > step) { hx += Math.sign(d) * step; dir = d > 0 ? 1 : -1; } else hx = tx;
      const moving = Math.abs(d) > 1, reach = W * D.reach;
      // the joints up a blade are stiffer than the root (k · tip per joint), and a
      // symplectic step is only stable while √k·h < 2 and damp·h < 2 — so a coarse
      // frame is cut into substeps of at most 0.02 s (S·Substep): one step at 60 fps
      const sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      let near = 0, nearD = 1e9;
      for (let i = 0; i < n; i++) {
        let rest = noise(t * 1.3 + bx[i] / W * 4) * D.wind;
        const dx = bx[i] - hx, ad = Math.abs(dx);
        if (ad < reach) rest += (dx < 0 ? -1 : 1) * D.lean * (1 - ad / reach);   // the push: away from the body
        if (ad < nearD) { nearD = ad; near = i; }
        for (let s = 0; s < sub; s++) {
          om[i] += (D.k * (rest - th[i]) - D.damp * om[i]) * h;
          th[i] = clamp(th[i] + om[i] * h, -1.5, 1.5);
          let below = th[i], kj = D.k;                    // the joints: each chases the segment below
          for (let j = 0; j < J - 1; j++) {
            kj *= D.tip;                                  // quicker with every joint up the blade (lighter segment, same bend)
            const dj = D.tipdamp * 2 * Math.sqrt(kj), idx = i * (J - 1) + j;   // a fraction of THIS joint's critical damping
            oj[idx] += (kj * (below - tj[idx]) - dj * oj[idx]) * h;
            tj[idx] = clamp(tj[idx] + oj[idx] * h, -1.6, 1.6);
            below = tj[idx];
          }
        }
      }
      const hw = Math.max(1, H * 0.006);
      let pts = null;                                       // the marked blade's joints, base → tip, kept for the readout
      for (let pass = 0; pass < 2; pass++) {              // odd blades behind the hero, even ones in front
        if (pass === 1) hero(hx, GY, { pose: moving ? "run" : "stand", frame: moving ? frameOf(t) : 0, face: dir });
        for (let i = pass; i < n; i += 2) {
          // walk the chain: each segment is bh / J long at its own angle. the
          // polygon goes up the left side, round the tip and down the right, the
          // half-width shrinking to nothing at the tip.
          const seg = bh[i] / J;
          let px = bx[i], py = GY;
          const left = [[bx[i] - hw, GY + 1]], right = [[bx[i] + hw, GY + 1]], chain = [[px, py]];
          for (let j = 0; j < J; j++) {
            const a = j === 0 ? th[i] : tj[i * (J - 1) + j - 1];
            px += Math.sin(a) * seg; py -= Math.cos(a) * seg;
            chain.push([px, py]);
            if (j < J - 1) {
              const w = hw * (1 - (j + 1) / J), sx = Math.cos(a) * w, sy = Math.sin(a) * w;
              left.push([px - sx, py - sy]); right.push([px + sx, py + sy]);
            }
          }
          left.push([px, py]);                              // the tip, shared by both sides
          right.reverse();
          poly(left.concat(right), col[i]);
          if (i === near) pts = chain;
        }
      }
      const i = near, tipA = J === 1 ? th[i] : tj[i * (J - 1) + J - 2];   // the marked blade: its root θ and its tip θ
      line(bx[i], GY, bx[i], GY - bh[i], "rgba(232,229,244,0.3)", 1);
      for (let j = 0; pts && j < pts.length - 1; j++) line(pts[j][0], pts[j][1], pts[j + 1][0], pts[j + 1][1], SUN, 1);
      ctx.strokeStyle = SUN; ctx.lineWidth = 1; ctx.beginPath();
      ctx.arc(bx[i], GY, bh[i] * 0.35, -Math.PI / 2, -Math.PI / 2 + th[i], th[i] < 0); ctx.stroke();
      label(J === 1 ? "θ = " + th[i].toFixed(2) : "θ₀ " + th[i].toFixed(2) + " · θtip " + tipA.toFixed(2), bx[i], GY - bh[i] - 6, SUN, "center");
      ring(hx, GY, reach, "rgba(245,193,105,0.25)");
      label("reach", hx + reach + 3, GY - 3, DIM);
      text(n + " blades · " + J + " segs · k " + D.k + " · damp " + D.damp + " (crit " + (2 * Math.sqrt(D.k)).toFixed(1) + ")", 10, 18, 10, INK);
      if (J > 1) label("joints: k ×" + D.tip + " each · damp " + D.tipdamp + " of their own critical", 10, 32, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Grass", "Gale", "stiff dry stalks under a strong wind — a hard spring that barely gives to the body, joints almost as stiff as the root, and a resting lean the whole field agrees on", { k: 150, wind: 0.55, tip: 0.8, tipdamp: 0.9, palette: ["#A89048", "#E2CB6C"] });

def("X", "Xray", "skin", "SILHOUETTE THROUGH WALLS: the hero, then the wall, then hero ∩ wall (source-in on the wall's mask) as a flat fill or a dilated outline — press to toggle", function (u) {
  var D = { mode: "outline",         // outline / flat
            colour: "#8AD9F5",       // the silhouette's colour
            alpha: 0.8,              // its opacity
            thick: 1.5,              // outline thickness, px
            pulse: 0,                // Hz of an alpha pulse (0 = steady); > 0 also adds a glow
            speed: 0.24,             // the hero's walk, screens per second
            label: "1 hero · 2 wall · 3 wall-mask ∘ source-in hero → flat | dilate − self = outline" };
  const { ctx, W, H, GY, TAU, stage, hero, heroSprite, wall, layer, label, text, line, rect, clamp, rgba, DIM, INK } = u;
  // the X-RAY is three draws and two masks. draw the hero, then the wall over
  // it — the hidden part is gone. now, in a layer: paint the wall's SHAPE, then
  // draw the hero SOURCE-IN, which keeps only the hero pixels that land where
  // the wall is: the occluded part, as a cut-out. fill that cut-out flat with
  // one colour and draw it back (chapter 03's tint), or DILATE it — the same
  // cut-out drawn eight times, one pixel each way — and cut the original out of
  // that (destination-out) to leave the ring: an outline (the atlas's Xray).
  const pillars = [{ x: W * 0.55, y: GY - H * 0.62, w: W * 0.13, h: H * 0.62 }, { x: W * 0.2, y: GY - H * 0.42, w: W * 0.045, h: H * 0.42 }];
  let x = W * 0.05, dir = 1;
  function frameOf(clock) { return (Math.floor(clock * 12) % 7) / 10; }
  return {
    press() { D.mode = D.mode === "outline" ? "flat" : "outline"; },
    frame(dt, t) {
      stage({ night: 0.3 });
      x += dir * W * D.speed * dt;
      if (x > W * 0.94) { x = W * 0.94; dir = -1; }
      if (x < W * 0.06) { x = W * 0.06; dir = 1; }
      const fr = frameOf(t), spr = heroSprite({ pose: "run", frame: fr, face: dir });
      hero(x, GY, { pose: "run", frame: fr, face: dir });                       // 1: the hero
      for (const p of pillars) wall(p.x, p.y, p.w, p.h);                        // 2: the walls, over it
      const x0 = Math.round(x - spr.ax), y0 = Math.round(GY - spr.ay), w = spr.w, h = spr.h, m = Math.ceil(D.thick) + 2;
      const L = layer("xray-cut"), c = L.ctx;                                   // 3: the cut-out
      c.clearRect(x0 - m, y0 - m, w + m * 2, h + m * 2);
      c.fillStyle = "#000";
      for (const p of pillars) c.fillRect(p.x, p.y, p.w, p.h);                  //   the wall's shape…
      c.globalCompositeOperation = "source-in";
      c.drawImage(spr.cv, x0, y0);                                              //   …keeps only the hero pixels inside it
      c.fillStyle = D.colour; c.fillRect(x0, y0, w, h);                         //   flattened to one colour
      c.globalCompositeOperation = "source-over";
      const pulse = D.pulse > 0 ? 0.65 + 0.35 * Math.sin(t * D.pulse * TAU) : 1;
      let src = L;
      if (D.mode === "outline") {                                               // dilate, then subtract the original: the ring
        const O = layer("xray-ring"), oc = O.ctx, th = D.thick;
        oc.clearRect(x0 - m, y0 - m, w + m * 2, h + m * 2);
        for (let i = 0; i < 8; i++) {
          const a = i / 8 * TAU;
          oc.drawImage(L.cv, x0, y0, w, h, x0 + Math.cos(a) * th, y0 + Math.sin(a) * th, w, h);
        }
        oc.globalCompositeOperation = "destination-out";
        oc.drawImage(L.cv, x0, y0, w, h, x0, y0, w, h);
        oc.globalCompositeOperation = "source-over";
        src = O;
      }
      if (D.pulse > 0) {                                                        // the glow: the cut-out, faint, spread
        ctx.globalAlpha = 0.18 * pulse; ctx.globalCompositeOperation = "lighter";
        for (let i = 0; i < 4; i++) { const a = i / 4 * TAU; ctx.drawImage(L.cv, x0 - m, y0 - m, w + m * 2, h + m * 2, x0 - m + Math.cos(a) * 3, y0 - m + Math.sin(a) * 3, w + m * 2, h + m * 2); }
        ctx.globalCompositeOperation = "source-over";
      }
      ctx.globalAlpha = D.alpha * pulse;
      ctx.drawImage(src.cv, x0 - m, y0 - m, w + m * 2, h + m * 2, x0 - m, y0 - m, w + m * 2, h + m * 2);
      ctx.globalAlpha = 1;
      ctx.strokeStyle = "rgba(232,229,244,0.18)"; ctx.lineWidth = 1; ctx.strokeRect(x0 - 0.5, y0 - 0.5, w + 1, h + 1);
      for (const p of pillars) label("wall", p.x + p.w / 2, p.y - 4, DIM, "center");
      text("mode: " + D.mode + (D.mode === "outline" ? " · " + D.thick + " px" : ""), 10, 18, 11, INK);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Xray", "Xspectral", "a magic-purple flat silhouette that pulses and glows — the hero's soul seen through stone", { mode: "flat", colour: "#C9A0F5", pulse: 1.4 });

def("W", "Wetfloor", "skin", "2D REFLECTION: the scene above the line copied, drawn flipped in strips below it, faded by depth and wobbled by a sine — the atlas's Mirror, wet — press to splash", function (u) {
  var D = { wobble: 3,               // sideways wobble at full depth, px
            k: 0.25,                 // wobble waves per px of depth
            w: 5,                    // wobble speed, radians per second
            alpha: 0.55,             // the reflection's strength at the line
            depth: 1,                // where the fade reaches zero, as a fraction of the floor's height
            strip: 2,                // strip height, px
            splashEvery: 3.2,        // seconds between autopilot splashes
            splash: 5,               // extra wobble a splash adds, px
            label: "y' = 2·GY − y · α = alpha·(1 − depth) · x' = x + sin(y·k + t·w)·wobble" };
  const { ctx, W, H, GY, TAU, stage, hero, lamp, crate, layer, label, text, line, rect, clamp, DIM, INK, NIGHT } = u;
  // a reflection in 2D is the scene drawn TWICE: once upright, once mirrored
  // about the ground line — the atlas's Mirror. here the upright pass is
  // copied out of the canvas into a layer, then copied back one thin STRIP at
  // a time from the mirrored row, so each strip can (1) fade with depth — the
  // gradient mask — and (2) slide sideways by a sine of its depth and the
  // clock, more the deeper it is: a wet floor. a splash raises the wobble for
  // a moment and rings spread on the line. no wobble and a short fade = polish.
  let x = W * 0.35, dir = 1, autoT = 0, boost = 0;
  const rings = [];
  for (let i = 0; i < 5; i++) rings.push({ on: false, x: 0, age: 0 });
  function frameOf(clock) { return (Math.floor(clock * 12) % 7) / 10; }
  function splash(px) { boost = 1; const r = rings.find(q => !q.on) || rings[0]; r.on = true; r.x = px; r.age = 0; }
  return {
    press(px) { splash(clamp(px, 10, W - 10)); autoT = 0; },
    frame(dt, t) {
      stage({ night: 0.45 });
      autoT += dt; boost = Math.max(0, boost - dt * 0.9);
      if (autoT > D.splashEvery) { autoT = 0; splash(x); }
      x += dir * W * 0.2 * dt;
      if (x > W * 0.8) { x = W * 0.8; dir = -1; }
      if (x < W * 0.15) { x = W * 0.15; dir = 1; }
      lamp(W * 0.22, GY, true); crate(W * 0.72, GY, H * 0.14);
      hero(x, GY, { pose: "run", frame: frameOf(t), face: dir });
      const cv = ctx.canvas, L = layer("wet-scene");                              // the upright pass, copied out
      L.ctx.drawImage(cv, 0, 0, cv.width, cv.height * GY / H, 0, 0, W, GY);
      rect(0, GY + 1, W, H - GY, "rgba(19,16,32,0.55)");                          // the floor itself, dark and wet
      const floor = H - GY, wob = D.wobble + D.splash * boost, fade = Math.max(0.05, D.depth) * floor;
      for (let dy = 0; dy < floor; dy += D.strip) {                               // the mirrored pass, strip by strip
        const sy = GY - dy - D.strip;
        if (sy < 0) break;
        const a = D.alpha * Math.max(0, 1 - dy / fade);
        if (a <= 0.005) break;
        const dx = Math.sin(dy * D.k + t * D.w) * wob * (0.3 + dy / floor);
        ctx.globalAlpha = a;
        ctx.drawImage(L.cv, 0, sy, W, D.strip, dx, GY + 1 + dy, W, D.strip);
      }
      ctx.globalAlpha = 1;
      for (const r of rings) {                                                    // splash rings on the line
        if (!r.on) continue;
        r.age += dt; if (r.age > 1.2) { r.on = false; continue; }
        const rr = 4 + r.age * W * 0.12;
        ctx.strokeStyle = "rgba(232,229,244," + (0.7 * (1 - r.age / 1.2)) + ")"; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.ellipse(r.x, GY + 1, rr, rr * 0.22, 0, 0, TAU); ctx.stroke();
      }
      const bx = W - 14, bh = floor - 6;                                          // the mask: α against depth, at the right edge
      for (let i = 0; i < 12; i++) rect(bx, GY + 3 + i / 12 * bh, 6, bh / 12 - 1, "rgba(232,229,244," + (D.alpha * Math.max(0, 1 - (i + 0.5) / 12 * floor / fade)) + ")");
      label("α", bx - 3, GY + 12, DIM, "right");
      label("wobble " + wob.toFixed(1) + " px" + (boost > 0.05 ? " · splash" : ""), 10, GY + 14, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Wetfloor", "Waxfloor", "no wobble at all and a fade that ends a third of the way down — the sharp, short mirror of a polished hall", { wobble: 0, depth: 0.4, splash: 0 });

def("S", "Skewshadow", "skin", "SKEWED DROP SHADOW: the sprite redrawn dark through a shear + squash matrix — c = (Sx − x)/(GY − Sy) follows the sun across the sky — press to place the sun", function (u) {
  var D = { squash: 0.28,            // the shadow's height as a fraction of the sprite's (the ground plane, foreshortened)
            maxShear: 4,             // the longest shadow, in heights per height
            alpha: 0.5,              // the shadow's darkness
            day: 14,                 // seconds for the sun to cross the sky
            source: "sun",           // sun (far, arcing) / lamp (near, fixed — shadows point away from it)
            night: 0,                // how dark the stage is
            speed: 0.22,             // the hero's run, screens per second
            label: "ctx.transform(face, 0, c, −squash, x, GY) · c = (Sx − x) / (GY − Sy)" };
  const { ctx, W, H, GY, stage, hero, heroSprite, layer, label, text, line, dot, glow, rect, clamp, SUN, DIM, INK, NIGHT } = u;
  // any sprite can cast a shadow of itself: draw it again through a MATRIX
  // that keeps x, squashes y toward the ground (the floor is seen edge-on, so
  // height becomes a little depth) and SHEARS it sideways by the light. the
  // shear c is the sun's geometry: a point h above the feet lands h·c to the
  // side, away from the sun, so a low sun throws a long shadow — the
  // grimoire's Long shadow, the atlas's Longshadow, now driven by a clock. the
  // thin line runs from the light through the head to the shadow's tip.
  const built = [0, 0, 0, 0, 0, 0, 0];
  let th = 0.2, Sx = W * 0.3, Sy = H * 0.2, manual = 0, x = W * 0.5, dir = 1, lampX = W * 0.72;
  const lampY = () => GY - H * 0.3 - 8;
  function frameOf(clock) { return (Math.floor(clock * 12) % 7) / 10; }
  function darkOf(spr, fi) {                             // the sprite as a black cut-out, one cached slot per run frame
    const L = layer("shadow-dark"), c = L.ctx, cx = (fi % 4) * spr.w, cy = Math.floor(fi / 4) * spr.h;
    if (built[fi] !== spr.s) {
      built[fi] = spr.s;
      c.save(); c.globalCompositeOperation = "source-over"; c.clearRect(cx, cy, spr.w, spr.h);
      c.drawImage(spr.cv, cx, cy);
      c.globalCompositeOperation = "source-in"; c.fillStyle = "#0A0812"; c.fillRect(cx, cy, spr.w, spr.h);
      c.restore();
    }
    return { L: L, cx: cx, cy: cy };
  }
  function shadowMatrix(ox) {                            // the shear for an object standing at ox
    const ly = D.source === "lamp" ? lampY() : Sy, lx = D.source === "lamp" ? lampX : Sx;
    return clamp((lx - ox) / Math.max(H * 0.05, GY - ly), -D.maxShear, D.maxShear);
  }
  return {
    press(px, py) {
      if (D.source === "lamp") { lampX = clamp(px, W * 0.1, W * 0.9); return; }
      Sx = clamp(px, 0, W); Sy = clamp(py, H * 0.03, GY - H * 0.1); manual = 5;
      th = clamp(Math.acos(clamp(-(Sx - W / 2) / (W * 0.55), -1, 1)), 0.06 * Math.PI, 0.94 * Math.PI);
    },
    frame(dt, t) {
      const lampMode = D.source === "lamp";
      stage({ night: lampMode ? Math.max(D.night, 0.8) : D.night });
      manual -= dt;
      if (!lampMode && manual <= 0) {
        th += dt * Math.PI / D.day;
        if (th > 0.94 * Math.PI) th = 0.06 * Math.PI;
        Sx = W / 2 - Math.cos(th) * W * 0.55; Sy = GY - Math.sin(th) * H * 0.75 - H * 0.05;
      }
      x += dir * W * D.speed * dt;
      if (x > W * 0.9) { x = W * 0.9; dir = -1; }
      if (x < W * 0.1) { x = W * 0.1; dir = 1; }
      const fr = frameOf(t), spr = heroSprite({ pose: "run", frame: fr, face: 1 }), fi = Math.round(fr * 10);
      const Lx = lampMode ? lampX : Sx, Ly = lampMode ? lampY() : Sy;
      function alphaAt(ox) { return lampMode ? D.alpha * clamp(1.2 - Math.abs(ox - Lx) / (W * 0.45), 0, 1) : D.alpha * (0.55 + 0.45 * Math.sin(th)); }
      if (lampMode) glow(Lx, Ly, H * 0.4, SUN, 0.35);
      // the crate's shadow: its square through the same matrix
      const cs = H * 0.14, cxp = W * 0.3, cc = shadowMatrix(cxp);
      ctx.save(); ctx.globalAlpha = alphaAt(cxp); ctx.transform(1, 0, cc, -D.squash, cxp, GY);
      ctx.fillStyle = "#0A0812"; ctx.fillRect(-cs / 2, -cs, cs, cs); ctx.restore();
      // the lamp post's shadow (in sun mode the lamp is just another object)
      if (!lampMode) {
        const lc = shadowMatrix(lampX), lh = H * 0.3;
        ctx.save(); ctx.globalAlpha = alphaAt(lampX); ctx.transform(1, 0, lc, -D.squash, lampX, GY);
        ctx.fillStyle = "#0A0812"; ctx.fillRect(-2, -lh, 4, lh); ctx.fillRect(-8, -lh - 3, 16, 4); ctx.restore();
      }
      // the hero's shadow: the black cut-out through the matrix, mirrored by face
      const c = shadowMatrix(x), dk = darkOf(spr, fi);
      ctx.save(); ctx.globalAlpha = alphaAt(x); ctx.transform(dir, 0, c, -D.squash, x, GY);
      ctx.drawImage(dk.L.cv, dk.cx, dk.cy, spr.w, spr.h, -spr.ax, -spr.ay, spr.w, spr.h); ctx.restore();
      u.crate(cxp, GY, cs);
      u.lamp(lampX, GY, lampMode);
      hero(x, GY, { pose: "run", frame: fr, face: dir });
      // the geometry: light → head → shadow tip
      const hh = 17 * spr.s, tipx = x - c * hh, tipy = GY + D.squash * hh;
      line(Lx, Ly, x, GY - hh, "rgba(245,193,105,0.35)", 1); line(x, GY - hh, tipx, tipy, "rgba(245,193,105,0.35)", 1);
      dot(tipx, tipy, 2, SUN);
      if (!lampMode) { glow(Sx, Sy, H * 0.12, SUN, 0.6); dot(Sx, Sy, H * 0.03, "#FFF3D0"); }
      label("c = " + c.toFixed(2), x, GY + D.squash * hh + 12, DIM, "center");
      text(D.source + (lampMode ? " at x " + Math.round(lampX) : " θ " + (th / Math.PI * 180).toFixed(0) + "°"), 10, 18, 10, INK);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Skewshadow", "Streetlamp", "the light is a lamp, near and fixed: every shadow points away from it and grows as the hero walks off — press moves the lamp", { source: "lamp", squash: 0.34, night: 0.85 });

def("P", "Pixelperfect", "skin", "PIXEL-PERFECT: ×2.5 bilinear at a half pixel vs ×3 nearest at whole pixels; a rotating copy melts unless snapped to steps or turned as texels — press to cycle", function (u) {
  var D = { zoom: 3,                 // the integer zoom (crisp)
            blurZoom: 2.5,           // the fractional zoom (soft)
            steps: 16,               // rotation steps for the snapped copy
            mode: "steps",           // the fourth copy: steps / chunky / smooth
            modes: ["steps", "chunky", "smooth"],
            spin: 0.7,               // radians per second
            bob: 3,                  // the soft copy's fractional bob, px
            label: "nearest + integer zoom + ⌊pivot⌋ = crisp · rotate the texels, not the pixels" };
  const { ctx, W, H, GY, TAU, stage, heroSprite, layer, label, text, dot, line, rect, DIM, INK, SUN, HOT } = u;
  // pixel art stays pixel art under three rules. scale by an INTEGER, with
  // NEAREST sampling (bilinear at ×2.5 smears every edge across two pixels);
  // put the pivot on a WHOLE pixel (a half-pixel bob shimmers); and never
  // rotate the enlarged image — the big pixels tear into sub-pixel stairs, the
  // "melt". either snap the angle to a few STEPS, or rotate the tiny source
  // texture first and enlarge THAT: every pixel of the result is still a
  // texel. chapter 09's №4, the lexicon's Quantize, applied to a sprite.
  const s0 = Math.max(1, Math.round(H / 170));            // the texel: the sprite is drawn at this unit and enlarged
  function frameOf(clock) { return (Math.floor(clock * 12) % 7) / 10; }
  let ang = 0;
  return {
    press() { D.mode = D.modes[(D.modes.indexOf(D.mode) + 1) % D.modes.length]; },
    frame(dt, t) {
      stage({ plain: true });
      ang += dt * D.spin;
      const spr = heroSprite({ s: s0, pose: "run", frame: frameOf(t) }), w0 = spr.w, h0 = spr.h, z = D.zoom;
      const cy = H * 0.5, cols = [0.125, 0.375, 0.625, 0.875].map(k => W * k);
      // 1: ×2.5 bilinear, pivot at a half pixel, bobbing by fractions
      ctx.imageSmoothingEnabled = true;
      const by = Math.sin(t * 2) * D.bob;
      ctx.drawImage(spr.cv, cols[0] - w0 * D.blurZoom / 2 + 0.5, cy - h0 * D.blurZoom / 2 + by, w0 * D.blurZoom, h0 * D.blurZoom);
      dot(cols[0] + 0.5, cy + by, 1.5, HOT);
      // 2: ×3 nearest, pivot rounded to a whole pixel
      ctx.imageSmoothingEnabled = false;
      const px = Math.round(cols[1] - w0 * z / 2), py = Math.round(cy - h0 * z / 2 + by);
      ctx.drawImage(spr.cv, px, py, w0 * z, h0 * z);
      dot(px + w0 * z / 2, py + h0 * z / 2, 1.5, SUN);
      // 3: the melt — the enlarged image rotated freely
      ctx.save(); ctx.translate(cols[2], cy); ctx.rotate(ang);
      ctx.drawImage(spr.cv, -w0 * z / 2, -h0 * z / 2, w0 * z, h0 * z); ctx.restore();
      // 4: the fix, by mode
      let sub = "";
      if (D.mode === "steps") {
        const a = Math.round(ang / (TAU / D.steps)) * (TAU / D.steps);
        ctx.save(); ctx.translate(cols[3], cy); ctx.rotate(a);
        ctx.drawImage(spr.cv, -w0 * z / 2, -h0 * z / 2, w0 * z, h0 * z); ctx.restore();
        sub = "snapped to " + D.steps + " steps";
      } else if (D.mode === "chunky") {                    // rotate the 1× texture in a layer, then enlarge with nearest
        const L = layer("pp-rot"), c = L.ctx, r0 = Math.ceil(Math.sqrt(w0 * w0 + h0 * h0)) + 2;
        c.clearRect(0, 0, r0, r0);
        c.save(); c.imageSmoothingEnabled = false; c.translate(r0 / 2, r0 / 2); c.rotate(ang);
        c.drawImage(spr.cv, -w0 / 2, -h0 / 2); c.restore();
        ctx.drawImage(L.cv, 0, 0, r0, r0, Math.round(cols[3] - r0 * z / 2), Math.round(cy - r0 * z / 2), r0 * z, r0 * z);
        sub = "texels rotated, then ×" + z;
      } else {
        ctx.imageSmoothingEnabled = true;
        ctx.save(); ctx.translate(cols[3], cy); ctx.rotate(ang);
        ctx.drawImage(spr.cv, -w0 * z / 2, -h0 * z / 2, w0 * z, h0 * z); ctx.restore();
        sub = "bilinear, free angle";
      }
      ctx.imageSmoothingEnabled = true;
      const ly = cy + h0 * z / 2 + 16;
      label("×" + D.blurZoom + " bilinear", cols[0], ly, DIM, "center"); label("pivot x + .5", cols[0], ly + 12, HOT, "center");
      label("×" + z + " nearest", cols[1], ly, DIM, "center"); label("pivot ⌊x⌋", cols[1], ly + 12, SUN, "center");
      label("rotate ×" + z, cols[2], ly, DIM, "center"); label("the melt", cols[2], ly + 12, HOT, "center");
      label(D.mode, cols[3], ly, INK, "center"); label(sub, cols[3], ly + 12, DIM, "center");
      text("texel = " + s0 + " px · sprite " + w0 + "×" + h0, 10, 18, 10, INK);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Pixelperfect", "Purist", "eight rotation steps and a ×4 zoom — the strict pixel-art rule, where every turn is a 45° and every pixel is four", { steps: 8, zoom: 4 });

def("N", "Nineslice", "skin", "9-SLICE: one panel texture cut into corners, edges and centre — corners copied as-is, edges stretched one way, the centre both — drag to resize the panel", function (u) {
  var D = { tile: 0.28,              // the source texture's size, as a fraction of H
            border: 0.25,            // the cut, as a fraction of the tile (corner size)
            style: "metal",          // metal / parchment
            breathe: 1,              // how much the panel breathes on autopilot (0 = still)
            period: 3.4,             // seconds per breath
            label: "9 draws: corners 1:1 · edges stretched along · centre stretched both ways" };
  const { ctx, W, H, TAU, stage, layer, label, text, line, rect, clamp, BONE, SUN, DIM, INK } = u;
  // a panel texture stretched whole gets fat, blurry corners. cut it into
  // NINE regions by two horizontal and two vertical lines at the border: the
  // four CORNERS are drawn at their own size, the four EDGES are stretched
  // only along their length, and the CENTRE is stretched both ways. nine
  // drawImage calls, one source texture drawn once and cached, any size of
  // panel with crisp corners. the small copy at the top right is the naive
  // stretch of the same texture, for comparison; the thin lines are the cuts.
  let builtKey = "", cx = W * 0.5, cy = H * 0.46, pw = W * 0.5, ph = H * 0.5, manual = 0;
  function build(T, B) {
    const L = layer("nine-src");
    const key = T + "|" + B + "|" + D.style + "|" + L.W;
    if (builtKey === key) return L;
    builtKey = key;
    const c = L.ctx;
    c.clearRect(0, 0, T + 2, T + 2);
    if (D.style === "parchment") {
      c.fillStyle = "#E8D8A8"; c.fillRect(0, 0, T, T);
      c.fillStyle = "rgba(120,80,30,0.12)";
      for (let i = 0; i < 40; i++) c.fillRect((i * 37) % T, (i * 53) % T, 2, 1);
      c.strokeStyle = "#7A4A22"; c.lineWidth = Math.max(1, B * 0.12);
      c.strokeRect(B * 0.3, B * 0.3, T - B * 0.6, T - B * 0.6);
      c.lineWidth = 1; c.strokeRect(B * 0.55, B * 0.55, T - B * 1.1, T - B * 1.1);
      c.fillStyle = "#7A4A22";
      for (const [qx, qy] of [[B * 0.3, B * 0.3], [T - B * 0.3, B * 0.3], [B * 0.3, T - B * 0.3], [T - B * 0.3, T - B * 0.3]]) { c.beginPath(); c.arc(qx, qy, B * 0.22, 0, TAU); c.fill(); }
    } else {
      const g = c.createLinearGradient(0, 0, 0, T);
      g.addColorStop(0, "#3A3560"); g.addColorStop(1, "#221E3C");
      c.fillStyle = g; c.fillRect(0, 0, T, T);
      c.strokeStyle = "#8C86B0"; c.lineWidth = Math.max(1, B * 0.18); c.strokeRect(B * 0.25, B * 0.25, T - B * 0.5, T - B * 0.5);
      c.strokeStyle = "#5A5480"; c.lineWidth = 1; c.strokeRect(B * 0.62, B * 0.62, T - B * 1.24, T - B * 1.24);
      c.fillStyle = "#C9C4E4";
      for (const [qx, qy] of [[B * 0.5, B * 0.5], [T - B * 0.5, B * 0.5], [B * 0.5, T - B * 0.5], [T - B * 0.5, T - B * 0.5]]) { c.beginPath(); c.arc(qx, qy, B * 0.16, 0, TAU); c.fill(); }
    }
    return L;
  }
  function nine(L, T, B, x, y, w, h) {                     // the nine draws
    const sx = [0, B, T - B, T], sy = sx, dx = [x, x + B, x + w - B, x + w], dy = [y, y + B, y + h - B, y + h];
    for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) {
      const sw = sx[i + 1] - sx[i], sh = sy[j + 1] - sy[j], dw = dx[i + 1] - dx[i], dh = dy[j + 1] - dy[j];
      if (dw > 0 && dh > 0) ctx.drawImage(L.cv, sx[i], sy[j], sw, sh, dx[i], dy[j], dw, dh);
    }
  }
  return {
    drag: true,
    press(x, y) { pw = clamp(Math.abs(x - cx) * 2, H * 0.2, W * 0.9); ph = clamp(Math.abs(y - cy) * 2, H * 0.2, H * 0.78); manual = 4; },
    frame(dt, t) {
      stage({ plain: true });
      const T = Math.max(12, Math.round(H * D.tile)), B = Math.max(3, Math.round(T * D.border)), L = build(T, B);
      manual -= dt;
      if (manual <= 0) {
        const k = Math.sin(t * TAU / D.period) * D.breathe;
        pw = W * 0.48 + k * W * 0.16; ph = H * 0.42 + Math.cos(t * TAU / D.period * 0.7) * D.breathe * H * 0.14;
      }
      const w = Math.max(2 * B + 2, Math.round(pw)), h = Math.max(2 * B + 2, Math.round(ph));
      const x = Math.round(cx - w / 2), y = Math.round(cy - h / 2);
      ctx.imageSmoothingEnabled = false;
      nine(L, T, B, x, y, w, h);
      ctx.imageSmoothingEnabled = true;
      ctx.strokeStyle = "rgba(245,193,105,0.5)"; ctx.lineWidth = 1; ctx.beginPath();  // the cuts on the panel
      for (const q of [x + B + 0.5, x + w - B - 0.5]) { ctx.moveTo(q, y); ctx.lineTo(q, y + h); }
      for (const q of [y + B + 0.5, y + h - B - 0.5]) { ctx.moveTo(x, q); ctx.lineTo(x + w, q); }
      ctx.stroke();
      text(w + " × " + h, cx, cy + 4, 11, D.style === "parchment" ? "#5A3A18" : INK, "center", true);
      // the source, with its cuts, at the top left; the naive stretch at the top right
      const tx = 8, ty = 8;
      ctx.drawImage(L.cv, 0, 0, T, T, tx, ty, T, T);
      ctx.strokeStyle = SUN; ctx.beginPath();
      for (const q of [tx + B + 0.5, tx + T - B - 0.5]) { ctx.moveTo(q, ty); ctx.lineTo(q, ty + T); }
      for (const q of [ty + B + 0.5, ty + T - B - 0.5]) { ctx.moveTo(tx, q); ctx.lineTo(tx + T, q); }
      ctx.stroke();
      label("source " + T + " px · cut " + B, tx, ty + T + 11, DIM);
      const nw = Math.round(w * 0.32), nh = Math.round(h * 0.32), nx = W - nw - 8, ny = 8;
      ctx.drawImage(L.cv, 0, 0, T, T, nx, ny, nw, nh);
      label("stretched whole", W - 8, ny + nh + 11, "rgba(245,138,138,0.8)", "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Nineslice", "Ninescroll", "a parchment panel with a border a third of the tile — the same nine cuts, a thicker frame and curled corners that never stretch", { style: "parchment", border: 0.34 });

def("O", "Outline", "skin", "TOON SHADING: n·l quantised into bands, a specular cap, an edge where nz is small, and an inverted hull drawn larger behind — press to move the light", function (u) {
  var D = { bands: 3,                // how many lighting steps
            edge: 0.3,               // pixels whose normal's z is below this are the outline
            hull: 3,                 // the inverted hull: a darker copy this many px larger, behind
            colour: "#E8705A",       // the ball's colour
            spec: 0.93,              // n·h above this is the highlight
            lz: 0.6,                 // how much the light faces the viewer
            orbit: 0.6,              // radians per second of the light's orbit
            label: "band = ⌊(n·l)·bands⌋ / bands · edge: n.z < e · hull: r + h behind" };
  const { ctx, W, H, TAU, stage, layer, label, text, dot, line, ring, rect, clamp, col, shade, INK, DIM, SUN } = u;
  // chapter 11 shaded a ball with a smooth gradient of n·l; TOON shading
  // keeps the same n·l and QUANTISES it — floor it into a few bands — so the
  // light falls in steps like ink washes. the outline comes twice: an
  // INVERTED HULL, the same shape drawn larger and darker behind (the classic
  // 3D trick), and a NORMAL-EDGE test, where any pixel whose normal points
  // mostly sideways (n.z small) is painted the line colour. the ball is a
  // small pixel buffer, computed every frame and stretched up — the atlas's
  // Orb, with its gradient snapped to a staircase.
  const cx = W * 0.5, cy = H * 0.47, r = Math.min(W, H) * 0.24;
  const N = clamp(Math.round(r * 2), 48, 120);
  const base = col(D.colour);
  const idx = [], nxs = [], nys = [], nzs = [];        // the sphere's normals, computed once: only the disc's pixels
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
    const nx = (i + 0.5) / N * 2 - 1, ny = (j + 0.5) / N * 2 - 1, rr = nx * nx + ny * ny;
    if (rr > 1) continue;
    idx.push((j * N + i) * 4); nxs.push(nx); nys.push(ny); nzs.push(Math.sqrt(1 - rr));
  }
  const IDX = Int32Array.from(idx), NX = Float32Array.from(nxs), NY = Float32Array.from(nys), NZ = Float32Array.from(nzs);
  const bR = new Uint8Array(16), bG = new Uint8Array(16), bB = new Uint8Array(16);
  let img = null, lx = 0.6, ly = -0.5, manual = 0;
  return {
    press(px, py) {
      const dx = (px - cx) / r, dy = (py - cy) / r, d = Math.sqrt(dx * dx + dy * dy) || 1, m = Math.min(d, 0.95);
      lx = dx / d * m; ly = dy / d * m; manual = 5;
    },
    frame(dt, t) {
      stage({ plain: true });
      manual -= dt;
      if (manual <= 0) { const a = t * D.orbit; lx = Math.cos(a) * 0.75; ly = Math.sin(a) * 0.75 - 0.15; }
      const lz = Math.max(0.05, D.lz), ll = Math.sqrt(lx * lx + ly * ly + lz * lz);
      const Lx = lx / ll, Ly = ly / ll, Lz = lz / ll;                          // the light, normalised
      const hl = Math.sqrt(Lx * Lx + Ly * Ly + (Lz + 1) * (Lz + 1));           // the half vector, toward the viewer
      const Hx = Lx / hl, Hy = Ly / hl, Hz = (Lz + 1) / hl;
      const L = layer("toon"), c = L.ctx;
      if (!img || img.width !== N) { img = c.createImageData(N, N); for (let k = 0; k < IDX.length; k++) img.data[IDX[k] + 3] = 255; }
      const d = img.data, bands = Math.min(16, Math.max(1, Math.round(D.bands))), edge = D.edge, spec = D.spec;
      for (let b = 0; b < bands; b++) {                                          // the staircase: one colour per band
        const k = 0.3 + 0.7 * (bands > 1 ? b / (bands - 1) : 1);
        bR[b] = base[0] * k; bG[b] = base[1] * k; bB[b] = base[2] * k;
      }
      for (let k = 0; k < IDX.length; k++) {
        const p = IDX[k], nx = NX[k], ny = NY[k], nz = NZ[k];
        let cr, cg, cb;
        if (nz < edge) { cr = 22; cg = 14; cb = 30; }                            // the normal-edge outline
        else if (nx * Hx + ny * Hy + nz * Hz > spec) { cr = 255; cg = 250; cb = 235; }   // the specular cap
        else {
          let ndl = nx * Lx + ny * Ly + nz * Lz; if (ndl < 0) ndl = 0;
          let b = (ndl * bands) | 0; if (b >= bands) b = bands - 1;              // ⌊(n·l)·bands⌋
          cr = bR[b]; cg = bG[b]; cb = bB[b];
        }
        d[p] = cr; d[p + 1] = cg; d[p + 2] = cb;
      }
      c.putImageData(img, 0, 0);
      ctx.fillStyle = "rgba(0,0,0,0.35)"; ctx.beginPath(); ctx.ellipse(cx - Lx * r * 0.4, cy + r * 1.08, r * 0.9, r * 0.16, 0, 0, TAU); ctx.fill();
      dot(cx, cy, r + D.hull, "rgb(22,14,30)");                                  // the inverted hull, behind
      ctx.imageSmoothingEnabled = true;
      ctx.drawImage(L.cv, 0, 0, N, N, cx - r, cy - r, r * 2, r * 2);
      const px = cx + Lx * r * 1.6, py = cy + Ly * r * 1.6;                     // the light itself
      dot(px, py, 3, "#FFF3D0"); line(px, py, cx + Lx * r, cy + Ly * r, "rgba(245,193,105,0.35)", 1);
      // the legend: n·l from 0 to 1, cut into bands
      const bw = W * 0.34, bx = 10, by = 14;
      for (let b = 0; b < bands; b++) {
        const k = 0.3 + 0.7 * (bands > 1 ? b / (bands - 1) : 1);
        rect(bx + b / bands * bw, by, bw / bands - 1, 7, "rgb(" + Math.round(base[0] * k) + "," + Math.round(base[1] * k) + "," + Math.round(base[2] * k) + ")");
      }
      label("n·l 0", bx, by + 18, DIM); label("1", bx + bw, by + 18, DIM, "right");
      text(bands + " bands · edge n.z < " + D.edge + " · hull " + D.hull + " px", bx, by + 32, 10, INK);
      label(N + "² buffer, every frame", W - 8, 18, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Outline", "Origami", "two bands and a thick line on cream — the paper look, where light is either on or off", { bands: 2, hull: 5, colour: "#F0D8A0" });

def("U", "Undersea", "skin", "WATER REFRACTION: what lies below the surface, redrawn in strips pushed by scrolling noise; CAUSTICS = two noise fields multiplied, thresholded — press to drop a pebble", function (u) {
  var D = { level: 0.5,              // the water's surface, as a fraction of H
            amp: 0.02,               // refraction push at full noise, as a fraction of H
            k: 0.06,                 // noise waves per px of depth
            speed: 0.7,              // how fast the noise field scrolls
            tint: "#4FA3D8",         // the water's colour
            tintA: 0.32,             // how much of it
            thr: 0.5,                // caustic threshold: n₁·n₂ above this is bright
            cScale: 0.09,            // caustic cell size (bigger = smaller cells)
            cSpeed: 0.4,             // caustic drift speed
            strip: 2,                // refraction strip height, px
            pebbleEvery: 3,          // seconds between autopilot pebbles
            label: "x' = x + noise(y·k, t)·amp · caustic = (n₁·n₂ > thr) added on the floor" };
  const { ctx, W, H, GY, TAU, stage, hero, crate, layer, label, text, line, rect, clamp, noise2, rgba, rand, DIM, INK } = u;
  // water bends what is behind it. copy the part of the scene below the
  // surface out of the canvas, then draw it back in horizontal STRIPS, each
  // slid sideways by a noise field that scrolls with the clock — the same
  // strip trick as Jelly, driven by noise instead of a sine (the atlas's
  // Undertow, live). CAUSTICS are the light the surface focuses on the
  // floor: two noise fields at different scales, multiplied, and everything
  // above a threshold painted bright and added. a pebble rings the surface
  // and, for a moment, pushes the strips harder.
  let x = W * 0.3, dir = 1, autoT = 0, boost = 0, cimg = null;
  const CW = 64, CH = 24, FW = CW * 2, FH = CH * 2, rings = [];
  const F1 = new Float32Array(FW * FH), F2 = new Float32Array(FW * FH);      // the two noise fields, sampled once, twice the buffer's size
  for (let j = 0; j < FH; j++) for (let i = 0; i < FW; i++) {
    F1[j * FW + i] = 0.5 + 0.5 * noise2(i * D.cScale, j * D.cScale * 2.2);
    F2[j * FW + i] = 0.5 + 0.5 * noise2(i * D.cScale * 1.37 + 7, j * D.cScale * 2.9 + 3);
  }
  for (let i = 0; i < 6; i++) rings.push({ on: false, x: 0, age: 0 });
  const bubbles = [];
  for (let i = 0; i < 8; i++) bubbles.push({ x: 0, y: 0, r: 1, v: 10, on: false });
  function frameOf(clock) { return (Math.floor(clock * 12) % 7) / 10; }
  function pebble(px) { boost = 1; const r = rings.find(q => !q.on) || rings[0]; r.on = true; r.x = px; r.age = 0; }
  return {
    press(px) { pebble(clamp(px, 8, W - 8)); autoT = 0; },
    frame(dt, t) {
      stage({ night: 0.1 });
      autoT += dt; boost = Math.max(0, boost - dt * 1.2);
      if (autoT > D.pebbleEvery) { autoT = 0; pebble(rand(W * 0.1, W * 0.9)); }
      x += dir * W * 0.14 * dt;
      if (x > W * 0.8) { x = W * 0.8; dir = -1; }
      if (x < W * 0.2) { x = W * 0.2; dir = 1; }
      const wy = Math.round(H * D.level);
      crate(W * 0.75, GY, H * 0.15);
      hero(x, GY, { pose: "run", frame: frameOf(t), face: dir });
      // the refraction: copy everything below the surface, draw it back in pushed strips
      const cv = ctx.canvas, L = layer("sea-back");
      L.ctx.drawImage(cv, 0, cv.height * wy / H, cv.width, cv.height * (H - wy) / H, 0, wy, W, H - wy);
      const amp = D.amp * H * (1 + 2.5 * boost);
      ctx.strokeStyle = "rgba(232,229,244,0.5)"; ctx.lineWidth = 1; ctx.beginPath();
      for (let y = wy; y < H; y += D.strip) {
        const dx = noise2(y * D.k, t * D.speed + y * 0.003) * amp;
        ctx.drawImage(L.cv, 0, y, W, D.strip, dx, y, W, D.strip);
        if (y === wy) ctx.moveTo(8 + dx, y); else ctx.lineTo(8 + dx, y);        // the push, drawn as a curve at the left edge
      }
      ctx.stroke();
      rect(0, wy, W, H - wy, rgba(D.tint, D.tintA));
      // the caustics: a small buffer of n₁·n₂, thresholded, added on the floor band
      const C = layer("sea-caustic"), cc = C.ctx;
      if (!cimg) cimg = cc.createImageData(CW, CH);
      // the two fields drift against each other (a slow ping-pong through the spare half), multiplied, thresholded
      const d = cimg.data, ph = t * D.cSpeed, thr = D.thr, gain = 420 / Math.max(0.05, 1 - thr);
      const o1 = (CW - 1) * (0.5 + 0.5 * Math.sin(ph)), o2 = (CW - 1) * (0.5 - 0.5 * Math.sin(ph * 0.71 + 1));
      const o3 = Math.floor(CH * (0.5 + 0.5 * Math.sin(ph * 0.53 + 2))), o4 = Math.floor(CH * (0.5 - 0.5 * Math.cos(ph * 0.37)));
      const i1 = Math.floor(o1), f1 = o1 - i1, i2 = Math.floor(o2), f2 = o2 - i2;
      for (let j = 0; j < CH; j++) {
        const r1 = (j + o3) * FW + i1, r2 = (j + o4) * FW + i2;
        for (let i = 0; i < CW; i++) {
          const n1 = F1[r1 + i] + (F1[r1 + i + 1] - F1[r1 + i]) * f1, n2 = F2[r2 + i] + (F2[r2 + i + 1] - F2[r2 + i]) * f2;
          const v = n1 * n2 - thr, p = (j * CW + i) * 4;
          d[p] = 220; d[p + 1] = 245; d[p + 2] = 255; d[p + 3] = v > 0 ? Math.min(255, v * gain) : 0;
        }
      }
      cc.putImageData(cimg, 0, 0);
      ctx.globalCompositeOperation = "lighter"; ctx.globalAlpha = 0.7;
      ctx.drawImage(C.cv, 0, 0, CW, CH, 0, GY, W, H - GY);
      ctx.globalAlpha = 1; ctx.globalCompositeOperation = "source-over";
      // the surface line and the rings
      ctx.strokeStyle = "rgba(232,229,244,0.75)"; ctx.lineWidth = 1.5; ctx.beginPath();
      for (let sx = 0; sx <= W; sx += 6) { const sy = wy + Math.sin(sx * 0.05 + t * 2) * 1.2; if (sx === 0) ctx.moveTo(sx, sy); else ctx.lineTo(sx, sy); }
      ctx.stroke();
      for (const r of rings) {
        if (!r.on) continue;
        r.age += dt; if (r.age > 1.4) { r.on = false; continue; }
        const rr = 3 + r.age * W * 0.1;
        ctx.strokeStyle = "rgba(232,229,244," + (0.8 * (1 - r.age / 1.4)) + ")"; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.ellipse(r.x, wy, rr, rr * 0.25, 0, 0, TAU); ctx.stroke();
      }
      for (const b of bubbles) {                                                 // a few bubbles off the wader
        if (!b.on) { if (Math.random() < dt * 0.6) { b.on = true; b.x = x + rand(-6, 6); b.y = GY - rand(4, 14); b.r = rand(1, 2.2); b.v = rand(14, 26); } continue; }
        b.y -= b.v * dt; b.x += Math.sin(t * 5 + b.r) * 8 * dt;
        if (b.y < wy) { b.on = false; continue; }
        ctx.strokeStyle = "rgba(255,255,255,0.5)"; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, TAU); ctx.stroke();
      }
      label("push(y)", 8, wy - 5, DIM);
      label("caustics: n₁·n₂ > " + D.thr, W / 2, GY + 12, DIM, "center");
      text("amp " + amp.toFixed(1) + " px" + (boost > 0.05 ? " · pebble" : ""), 10, 18, 10, INK);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Undersea", "Ultramarine", "the water up to the hero's chin, a deep blue tint and caustics that drift at a third of the speed — the bottom of the lake", { level: 0.32, tint: "#1C3BA8", cSpeed: 0.14 });

def("H", "Hologram", "skin", "HOLOGRAM: the sprite tinted source-atop, scanlines scrolled over it, a rim from dilate − self, alpha flickering on noise, added over a projector — press to glitch", function (u) {
  var D = { hue: 192,                // the hologram's colour, degrees
            alpha: 0.7,              // its base opacity
            scan: 3,                 // scanline spacing, px
            scanA: 0.45,             // scanline darkness
            rim: 1.5,                // the rim's thickness, px
            flicker: 0.25,           // how deep the flicker cuts (0..1)
            flickerRate: 14,         // how fast the flicker noise runs
            glitchEvery: 3.6,        // seconds between autopilot glitches
            glitchLen: 0.35,         // seconds a glitch lasts
            split: 4,                // slice offset during a glitch, px
            label: "α·flick(noise) · tint source-atop · scanlines every 3 px · rim = dilate − self · lighter" };
  const { ctx, W, H, GY, TAU, stage, heroSprite, layer, label, text, line, dot, glow, ellipse, hsl, noise, rand, DIM, INK } = u;
  // the folio's Hologram was a baked sheet; this one is built live from five
  // cheap passes on the sprite's pixels. TINT: a source-atop fill in the
  // hologram's hue. SCANLINES: dark one-pixel rows, also source-atop, scrolling
  // upward. RIM: the sprite drawn four times one pixel out (a dilate), with
  // the sprite itself cut back out — the bright edge of rim_glow.gdshader.
  // FLICKER: the whole thing's alpha rides a fast noise, with rare dropouts.
  // and it is drawn LIGHTER, so it adds to the dark room instead of covering
  // it: light, not paint. a GLITCH slices it into rows and shoves them.
  let glitch = 0, autoT = 0, face = 1;
  const slices = [];
  for (let i = 0; i < 6; i++) slices.push({ y: 0, h: 0, dx: 0 });
  function reslice(h) { for (const s of slices) { s.y = rand(0, h); s.h = rand(2, h * 0.15); s.dx = rand(-1, 1) * D.split; } }
  return {
    press() { glitch = D.glitchLen; autoT = 0; face = -face; },
    frame(dt, t) {
      stage({ night: 0.75 });
      autoT += dt;
      if (autoT > D.glitchEvery) { autoT = 0; glitch = D.glitchLen; }
      const spr = heroSprite({ pose: "stand", frame: 0, face: face }), w = spr.w, h = spr.h;
      const px = W * 0.5, py = GY - H * 0.16 + Math.sin(t * 1.3) * H * 0.012;   // floating above the lens
      const x0 = Math.round(px - spr.ax), y0 = Math.round(py - spr.ay);
      const hue = D.hue + Math.sin(t * 0.7) * 8, tint = hsl(hue, 0.9, 0.62), rimC = hsl(hue, 1, 0.85);
      // the projector: a base, a lens, and the cone of light up to the sprite
      ellipse(px, GY, W * 0.11, H * 0.022, "#2B2640"); ellipse(px, GY - 2, W * 0.09, H * 0.016, "#3A3355");
      const cone = ctx.createLinearGradient(0, GY, 0, y0);
      cone.addColorStop(0, hsl(hue, 0.9, 0.7, 0.35)); cone.addColorStop(1, hsl(hue, 0.9, 0.7, 0));
      ctx.fillStyle = cone; ctx.beginPath(); ctx.moveTo(px - 3, GY - 3); ctx.lineTo(x0 - 2, y0); ctx.lineTo(x0 + w + 2, y0); ctx.lineTo(px + 3, GY - 3); ctx.closePath(); ctx.fill();
      glow(px, GY - 3, W * 0.06, tint, 0.8);
      // pass 1 + 2, in a layer: tint, then scanlines, both source-atop
      const L = layer("holo"), c = L.ctx, m = Math.ceil(D.rim) + 1;
      c.clearRect(x0 - m, y0 - m, w + m * 2, h + m * 2);
      c.drawImage(spr.cv, x0, y0);
      c.globalCompositeOperation = "source-atop";
      c.fillStyle = tint; c.globalAlpha = 0.8; c.fillRect(x0, y0, w, h);
      c.globalAlpha = D.scanA; c.fillStyle = "#000";
      const scan = Math.max(1.5, D.scan), off = (t * 12) % scan;
      for (let yy = y0 + h - off; yy > y0 - scan; yy -= scan) c.fillRect(x0, yy, w, 1);
      c.globalAlpha = 1; c.globalCompositeOperation = "source-over";
      // pass 3: the rim — dilate the tinted sprite, subtract itself
      const R = layer("holo-rim"), rc = R.ctx;
      rc.clearRect(x0 - m, y0 - m, w + m * 2, h + m * 2);
      for (let i = 0; i < 4; i++) { const a = i / 4 * TAU; rc.drawImage(L.cv, x0, y0, w, h, x0 + Math.cos(a) * D.rim, y0 + Math.sin(a) * D.rim, w, h); }
      rc.globalCompositeOperation = "destination-out"; rc.drawImage(L.cv, x0, y0, w, h, x0, y0, w, h);
      rc.globalCompositeOperation = "source-in"; rc.fillStyle = rimC; rc.fillRect(x0 - m, y0 - m, w + m * 2, h + m * 2);
      rc.globalCompositeOperation = "source-over";
      // pass 4: flicker, then pass 5: draw both, lighter
      let flick = 1 - D.flicker * (0.5 + 0.5 * noise(t * D.flickerRate));
      if (noise(t * D.flickerRate * 0.7 + 40) > 0.82) flick *= 0.35;           // the dropout
      glitch = Math.max(0, glitch - dt);
      if (glitch > 0 && Math.random() < 0.5) reslice(h);
      ctx.globalCompositeOperation = "lighter";
      ctx.globalAlpha = D.alpha * flick;
      if (glitch > 0) {                                                         // sliced: rows shoved sideways, a ghost copy either side
        ctx.globalAlpha = D.alpha * flick * 0.35;
        ctx.drawImage(L.cv, x0, y0, w, h, x0 - D.split, y0, w, h); ctx.drawImage(L.cv, x0, y0, w, h, x0 + D.split, y0, w, h);
        ctx.globalAlpha = D.alpha * flick;
        let yy = 0;
        for (const s of slices.slice().sort((a, b) => a.y - b.y)) {
          const sy = Math.max(yy, Math.min(h, Math.floor(s.y))), sh = Math.max(0, Math.min(h - sy, Math.ceil(s.h)));
          if (sy > yy) ctx.drawImage(L.cv, x0, y0 + yy, w, sy - yy, x0, y0 + yy, w, sy - yy);
          if (sh > 0) ctx.drawImage(L.cv, x0, y0 + sy, w, sh, x0 + s.dx, y0 + sy, w, sh);
          yy = sy + sh;
        }
        if (yy < h) ctx.drawImage(L.cv, x0, y0 + yy, w, h - yy, x0, y0 + yy, w, h - yy);
      } else ctx.drawImage(L.cv, x0 - m, y0 - m, w + m * 2, h + m * 2, x0 - m, y0 - m, w + m * 2, h + m * 2);
      ctx.globalAlpha = D.alpha * flick * 0.9;
      ctx.drawImage(R.cv, x0 - m, y0 - m, w + m * 2, h + m * 2, x0 - m, y0 - m, w + m * 2, h + m * 2);
      ctx.globalAlpha = 1; ctx.globalCompositeOperation = "source-over";
      // the flicker, drawn: a bar of α
      const bw = W * 0.28, bx = 10, by = 14;
      ctx.strokeStyle = "rgba(232,229,244,0.2)"; ctx.lineWidth = 1; ctx.strokeRect(bx, by, bw, 6);
      ctx.fillStyle = tint; ctx.fillRect(bx, by, bw * D.alpha * flick, 6);
      label("α " + (D.alpha * flick).toFixed(2) + (glitch > 0 ? " · glitch" : ""), bx, by + 18, DIM);
      text("hue " + Math.round(hue) + "° · scan " + D.scan + " px · rim " + D.rim, bx, by + 32, 10, INK);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Hologram", "Haunt", "a green, slow-breathing ghost of a hologram — faint scanlines and a flicker that drifts instead of buzzing", { hue: 125, flickerRate: 2.5, scanA: 0.2 });
/* ============================== LIGHTING & VISIBILITY ==============================
   Light, and what it cannot reach. A 2D game has no photons: "lit" is a
   dark layer with holes punched in it, "shadow" is the part of the room a
   ray from the light never arrived at, "night" is a blue multiply with
   additive windows, and "bloom" is the bright parts drawn again, blurred,
   on top. This family spells each of those in canvas — the visibility
   polygon (a ray to every corner, sorted by angle), fog of war (a grid that
   remembers), a torch that shakes in the hand, torchlight whose shadows
   breathe, a day → night slider, lightning that decays exponentially, a
   stealth meter that fills inside a view cone, light shafts with dust,
   dusk windows on staggered timers, blob shadows that tilt to the slope,
   selective bloom, rooms that wake when entered, and colour-coded zones. */

def("V", "Visibility", "light", "a ray to every wall corner (±ε), the hits sorted by angle and filled as a fan — the lexicon's Xmarks, fired a hundred times — press to set the light", function (u) {
  var D = { cone: 360,          // degrees the light can see: 360 = all round, less = a clipped wedge
            speed: 0.35,        // the wander rate (a Lissajous of t)
            reach: 0.85,        // light radius inside the polygon, of W
            rays: true,         // draw every ray and the corner it reaches
            hold: 4,            // seconds a pressed light stays put before wandering again
            label: "ray → every corner ±ε · sort by θ · fill the fan" };
  const { ctx, W, H, TAU, stage, wall, hero, layer, visPoly, cutLight, dot, ring, label, len, smooth, rgba, SUN, SPARK, INK, DIM } = u;
  // a VISIBILITY POLYGON is what one point can see. the lexicon's Xmarks asked
  // "where does this ray first hit?" once; here it is asked for every wall
  // corner, plus a hair to either side of each (so a ray slides past the
  // corner and finds the wall behind it), and the hits, sorted by angle, are
  // the polygon's vertices. fill the fan and you have light with shadows;
  // test a point against it and you have line of sight. the kit's visPoly
  // does the casting — this card draws what it did.
  const S = H / 170;
  const blocks = [[0.22, 0.30, 0.06, 0.28], [0.52, 0.60, 0.17, 0.08], [0.72, 0.16, 0.05, 0.26]];   // x, y, w, h of W and H
  const segs = [], corners = [];
  for (let b = 0; b < blocks.length; b++) {
    const x = blocks[b][0] * W, y = blocks[b][1] * H, w = blocks[b][2] * W, h = blocks[b][3] * H;
    segs.push([x, y, x + w, y], [x + w, y, x + w, y + h], [x + w, y + h, x, y + h], [x, y + h, x, y]);
    corners.push([x, y], [x + w, y], [x + w, y + h], [x, y + h]);
  }
  const half = Math.min(180, D.cone) * Math.PI / 360, coned = D.cone < 360;
  const hs = Math.max(1, Math.round(H / 110));
  let lx = W * 0.5, ly = H * 0.5, px = 0, py = 0, hold = 0, head = 0, lastX = lx, lastY = ly;
  function pathOf(c, pts) {
    c.beginPath(); c.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) c.lineTo(pts[i][0], pts[i][1]);
    c.closePath();
  }
  return {
    press(x, y) { px = x; py = y; hold = D.hold; },
    frame(dt, t) {
      stage({ night: 0.85 });
      hold = Math.max(0, hold - dt);
      const gx = hold > 0 ? px : W * (0.5 + 0.34 * Math.sin(t * D.speed));
      const gy = hold > 0 ? py : H * (0.45 + 0.22 * Math.sin(t * D.speed * 0.73 + 1.3));
      const k = smooth(6, dt);
      lx += (gx - lx) * k; ly += (gy - ly) * k;
      const vx = lx - lastX, vy = ly - lastY; lastX = lx; lastY = ly;
      if (len(vx, vy) > 0.05 * S) {                    // the wedge faces the way the light moves
        const d = Math.atan2(vy, vx) - head;
        head += Math.atan2(Math.sin(d), Math.cos(d)) * smooth(4, dt);
      }
      const pts = visPoly(lx, ly, segs);               // ← the whole trick, once per frame
      for (let b = 0; b < blocks.length; b++) wall(blocks[b][0] * W, blocks[b][1] * H, blocks[b][2] * W, blocks[b][3] * H);
      const L = layer("dark"), c = L.ctx;              // darkness, with the polygon cut out of it
      c.globalCompositeOperation = "source-over"; c.globalAlpha = 1;
      c.clearRect(0, 0, W, H);
      c.fillStyle = "rgba(8,6,20,0.9)"; c.fillRect(0, 0, W, H);
      c.save();
      pathOf(c, pts); c.clip();
      if (coned) { c.beginPath(); c.moveTo(lx, ly); c.arc(lx, ly, W + H, head - half, head + half); c.closePath(); c.clip(); }
      cutLight(L, lx, ly, W * D.reach, 0.7, 1);
      c.restore();
      ctx.drawImage(L.cv, 0, 0, W, H);
      if (D.rays) {                                    // the rays, as one path
        ctx.strokeStyle = rgba(SUN, 0.14); ctx.lineWidth = 1;
        ctx.beginPath();
        for (let i = 0; i < pts.length; i++) {
          if (coned) { const d = pts[i][2] - head; if (Math.abs(Math.atan2(Math.sin(d), Math.cos(d))) > half) continue; }
          ctx.moveTo(lx, ly); ctx.lineTo(pts[i][0], pts[i][1]);
        }
        ctx.stroke();
        let hit = 0;
        for (let q = 0; q < corners.length; q++) {     // a corner counts as hit when a ray ends on it
          const cx = corners[q][0], cy = corners[q][1];
          let on = false;
          for (let i = 0; i < pts.length && !on; i++) if (len(pts[i][0] - cx, pts[i][1] - cy) < 1.5) on = true;
          if (on) { hit++; dot(cx, cy, 2 * S, SPARK); }
        }
        label(pts.length + " rays · " + hit + " corners hit", W / 2, 12 * S, DIM, "center");
      }
      ctx.strokeStyle = rgba(SUN, 0.35); ctx.lineWidth = 1;   // the polygon's edge: where the shadows start
      pathOf(ctx, pts); ctx.stroke();
      if (coned) hero(lx, ly + 14 * hs, { s: hs, face: Math.cos(head) < 0 ? -1 : 1 });   // a guard: the eyes are the light
      else { dot(lx, ly, 3 * S, INK); ring(lx, ly, 6 * S, rgba(SUN, 0.6), 1.5); }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Visibility", "Viewcone", "the same polygon clipped to a 70° wedge that faces the way it walks — a guard's sight, shadows and all", { cone: 70, speed: 0.2 });

def("F", "Fogofwar", "light", "a grid that remembers: UNSEEN black, SEEN dim, VISIBLE a soft hole round the hero — the map fills in as it explores — press to send the hero", function (u) {
  var D = { cols: 20,           // fog tiles across (rows follow the aspect)
            sight: 0.17,        // sight radius, of W
            memory: 0,          // seconds a seen tile stays remembered (0 = forever)
            speed: 0.16,        // hero speed, of W per second
            dim: 0.55,          // darkness of a remembered tile (unseen is 0.97)
            label: "tile ∈ {unseen, seen, visible} · visible if |eye − tile| < r" };
  const { ctx, W, H, TAU, stage, hero, tree, crate, layer, cutLight, rect, ring, label, rng, len, clamp, lerp, rgba, INK, DIM } = u;
  // FOG OF WAR is three states per tile. VISIBLE: inside the sight radius
  // right now. SEEN: it was visible once, so the map is remembered but the
  // tile is dimmed (and nothing that moves is drawn there). UNSEEN: black.
  // the overlay is one layer: every tile painted at its darkness, then one
  // soft hole erased around the eye so the visible disc has no stair-steps.
  // a memory dial lets remembered tiles fade back toward unseen.
  const S = H / 170, tw = W / D.cols, rows = Math.ceil(H / tw), n = D.cols * rows;
  const last = new Float32Array(n);                    // when each tile was last visible (−1 = never)
  for (let i = 0; i < n; i++) last[i] = -1;
  const R = rng(3), props = [];
  for (let i = 0; i < 10; i++) props.push({ k: i % 3, x: W * (0.05 + R() * 0.9), y: H * (0.2 + R() * 0.75) });
  const hs = Math.max(1, Math.round(H / 100));
  let hx = W * 0.15, hy = H * 0.5, tx = W * 0.6, ty = H * 0.4, face = 1, clock = 0, idle = 0;
  return {
    press(x, y) { tx = clamp(x, 8, W - 8); ty = clamp(y, H * 0.15, H - 6); idle = 0; },
    frame(dt, t) {
      const dx = tx - hx, dy = ty - hy, d = len(dx, dy), moving = d > 1.5;
      if (moving) { const sp = Math.min(d, W * D.speed * dt); hx += dx / d * sp; hy += dy / d * sp; if (Math.abs(dx) > 1) face = dx < 0 ? -1 : 1; clock += dt; }
      else { idle += dt; if (idle > 0.7) { idle = 0; tx = W * (0.06 + R() * 0.88); ty = H * (0.18 + R() * 0.76); } }
      const r = W * D.sight, ex = hx, ey = hy - 5 * hs;  // the eye
      for (let j = 0; j < rows; j++) for (let i = 0; i < D.cols; i++)
        if (len((i + 0.5) * tw - ex, (j + 0.5) * tw - ey) < r) last[j * D.cols + i] = t;
      stage({ plain: true });
      rect(0, 0, W, H, "rgba(52,92,54,0.85)");           // the map: grass ...
      rect(0, H * 0.62, W, H * 0.08, "rgba(58,120,190,0.9)");   // ... a river ...
      rect(W * 0.42, H * 0.6, W * 0.05, H * 0.12, "#7A5A3A");   // ... and a bridge
      for (let p = 0; p < props.length; p++) {
        const o = props[p];
        if (o.k === 0) tree(o.x, o.y, H * 0.14); else if (o.k === 1) crate(o.x, o.y, H * 0.06); else rect(o.x - 6 * S, o.y - 4 * S, 12 * S, 8 * S, "#6E6890");
      }
      hero(hx, hy, { face: face, pose: moving ? "run" : "stand", frame: clock, s: hs });
      const L = layer("fog"), c = L.ctx;
      c.globalCompositeOperation = "source-over"; c.globalAlpha = 1;
      c.clearRect(0, 0, W, H);
      let seen = 0;
      for (let j = 0; j < rows; j++) for (let i = 0; i < D.cols; i++) {
        const l = last[j * D.cols + i];
        let a = 0.97;
        if (l >= 0) { a = D.dim; if (D.memory > 0) a = lerp(D.dim, 0.97, clamp((t - l) / D.memory, 0, 1)); if (a < 0.96) seen++; }
        c.fillStyle = "rgba(10,8,22," + a.toFixed(3) + ")";
        c.fillRect(i * tw, j * tw, tw + 0.5, tw + 0.5);
      }
      cutLight(L, ex, ey, r * 1.05, 0.45, 1);         // the soft hole: visible, right now
      ctx.drawImage(L.cv, 0, 0, W, H);
      ring(ex, ey, r, rgba(INK, 0.2));
      const sw = 7 * S, ly0 = 6 * S;                   // the legend
      rect(6 * S, ly0, sw, sw, "rgba(10,8,22,0.97)"); label("unseen", 6 * S + sw + 3, ly0 + sw - 1, DIM);
      rect(6 * S, ly0 + sw + 3, sw, sw, "rgba(10,8,22," + D.dim + ")"); label("seen", 6 * S + sw + 3, ly0 + 2 * sw + 2, DIM);
      rect(6 * S, ly0 + 2 * sw + 6, sw, sw, "rgba(232,229,244,0.15)"); label("visible", 6 * S + sw + 3, ly0 + 3 * sw + 5, DIM);
      label("explored " + Math.round(seen / n * 100) + "%", W - 6, 12, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Fogofwar", "Foglift", "a sight radius half again as wide, and remembered tiles that fade back to black over six seconds — a map you have to keep walking", { sight: 0.27, memory: 6 });

def("T", "Torch", "light", "a feathered wedge with falloff, erased from a darkness layer; the aim shakes like a hand, a battery dims it — atlas Spotlight, held — drag to aim", function (u) {
  var D = { half: 22,           // half-angle of the beam, degrees
            reach: 0.8,         // beam length, of W
            jitter: 1,          // hand shake: how much noise rides on the aim
            soft: 0.5,          // how much of the beam's width is feathered edge (0..1)
            battery: 25,        // seconds from full to flat, then a fresh cell goes in
            dark: 0.94,         // the darkness layer's alpha
            label: "wedge θ ± half · α(d) falloff · θ += noise(t)·jitter · × battery" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, crate, layer, cutLight, line, rect, dot, label, noise, smooth, rgba, SUN, SPARK, INK, DIM, HOT, GOOD } = u;
  // a FLASHLIGHT is a darkness layer (one near-black rect) with a cone erased
  // out of it. the cone is four nested wedges, each a little narrower and
  // each erased again, so the edge feathers; a radial gradient along the beam
  // is the falloff. the hand adds two noises to the aim — a slow drift and a
  // fast tremor — and a battery scales the whole erase: dying cells flicker.
  const S = H / 170, hs = Math.max(2, Math.round(H / 60));
  const hx = W * 0.17, ox = hx + 5 * hs, oy = GY - 8 * hs;
  let aim = -0.15, goal = -0.15, hold = 0, bat = 1, swap = 0;
  return {
    drag: true,
    press(x, y) { goal = Math.atan2(y - oy, x - ox); hold = 3; },
    frame(dt, t) {
      stage({ night: 0.92 });
      hold = Math.max(0, hold - dt);
      if (hold <= 0) goal = -0.12 + Math.sin(t * 0.5) * 0.4 + Math.sin(t * 0.21 + 2) * 0.25;   // the idle sweep
      const da = goal - aim; aim += Math.atan2(Math.sin(da), Math.cos(da)) * smooth(5, dt);
      if (swap > 0) { swap -= dt; if (swap <= 0) bat = 1; }
      else { bat -= dt / Math.max(1, D.battery); if (bat <= 0) { bat = 0; swap = 1; } }
      const dying = (bat < 0.25 && bat > 0) ? 0.55 + 0.45 * (noise(t * 17) * 0.5 + 0.5) : 1;
      const bright = bat <= 0 ? 0 : (0.3 + 0.7 * bat) * dying;
      const jit = (noise(t * 7.3) * 0.02 + noise(t * 1.7 + 40) * 0.05) * D.jitter;
      const th = aim + jit, half = D.half * Math.PI / 180, R = W * D.reach;
      tree(W * 0.55, GY, H * 0.3); tree(W * 0.88, GY, H * 0.24); crate(W * 0.72, GY, H * 0.1);
      hero(hx, GY, { face: Math.cos(th) < 0 ? -1 : 1 });
      const L = layer("dark"), c = L.ctx;
      c.globalCompositeOperation = "source-over"; c.globalAlpha = 1;
      c.clearRect(0, 0, W, H);
      c.fillStyle = "rgba(6,5,16," + D.dark + ")"; c.fillRect(0, 0, W, H);
      if (bright > 0) {
        c.globalCompositeOperation = "destination-out";
        const g = c.createRadialGradient(ox, oy, 0, ox, oy, R);
        g.addColorStop(0, "rgba(0,0,0,1)"); g.addColorStop(0.4, "rgba(0,0,0,0.75)"); g.addColorStop(1, "rgba(0,0,0,0)");
        c.fillStyle = g;
        const N = 4;
        for (let i = 0; i < N; i++) {                  // nested wedges: the edge is erased once, the core four times
          const h = half * (1 - D.soft * i / N);
          c.globalAlpha = bright * 0.45;
          c.beginPath(); c.moveTo(ox, oy); c.arc(ox, oy, R, th - h, th + h); c.closePath(); c.fill();
        }
        c.globalAlpha = 1; c.globalCompositeOperation = "source-over";
        cutLight(L, ox, oy, 14 * S, 0.5, 0.7 * bright);   // spill around the hand
      }
      ctx.drawImage(L.cv, 0, 0, W, H);
      line(ox, oy, ox + Math.cos(th - half) * R, oy + Math.sin(th - half) * R, rgba(SUN, 0.18));   // the wedge's edges, thin
      line(ox, oy, ox + Math.cos(th + half) * R, oy + Math.sin(th + half) * R, rgba(SUN, 0.18));
      ctx.save(); ctx.translate(ox, oy); ctx.rotate(th);
      rect(-4 * S, -2 * S, 9 * S, 4 * S, "#3A3355");
      if (bright > 0) dot(5 * S, 0, 2.2 * S, rgba(SPARK, bright));
      ctx.restore();
      const bw = 34 * S, bx = W - bw - 8 * S, by = 8 * S;   // the battery
      ctx.strokeStyle = rgba(INK, 0.5); ctx.lineWidth = 1; ctx.strokeRect(bx, by, bw, 8 * S);
      rect(bx + bw, by + 2 * S, 2 * S, 4 * S, rgba(INK, 0.5));
      rect(bx + 1, by + 1, (bw - 2) * bat, 8 * S - 2, bat < 0.25 ? HOT : GOOD);
      label(swap > 0 ? "swapping cells…" : "battery " + Math.round(bat * 100) + "%", bx - 4, by + 8 * S - 1, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Torch", "Tunnelvision", "an 8° beam, a hand that shakes three times as hard, cells that last twelve seconds — the horror flashlight", { half: 8, jitter: 3, battery: 12 });

def("U", "Umbra", "light", "a flickering point light PLUS its visibility polygon — the pillars' shadows breathe with the flame (atlas Candle, in a room) — press to move the torch", function (u) {
  var D = { colour: "#F5C169",  // the light's colour
            reach: 0.7,         // falloff radius, of W
            flicker: 1,         // how much the flame breathes and the light point jitters
            soft: 0.6,          // the falloff's softness (cutLight's soft)
            drift: 1,           // how far the torch wanders around its base
            label: "lit = visPoly(torch) ∩ falloff(d) · torch += noise(t)·flicker" };
  const { ctx, W, H, GY, TAU, stage, wall, hero, layer, visPoly, cutLight, glow, line, label, noise, smooth, rgba, DIM } = u;
  // TORCHLIGHT WITH SHADOWS is Visibility with a colour and a pulse: the
  // polygon says where the light can reach, a radial falloff says how much,
  // and the darkness layer is erased by their intersection. the flame
  // breathes (a noise on the radius) and the light POINT jitters by a couple
  // of pixels, so every shadow edge moves — that is what makes fire read as
  // fire. a warm glow clipped to the same polygon tints what it lights.
  const S = H / 170;
  const pillars = [[0.30, 0.42, 0.05], [0.56, 0.26, 0.06], [0.80, 0.50, 0.07]];   // x, top y, w — standing on the floor
  const segs = [];
  for (let p = 0; p < pillars.length; p++) {
    const x = pillars[p][0] * W, y = pillars[p][1] * H, w = pillars[p][2] * W;
    segs.push([x, y, x + w, y], [x + w, y, x + w, GY], [x + w, GY, x, GY], [x, GY, x, y]);
  }
  let bx = W * 0.45, by = H * 0.5, lx = bx, ly = by;
  function pathOf(c, pts) {
    c.beginPath(); c.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) c.lineTo(pts[i][0], pts[i][1]);
    c.closePath();
  }
  return {
    press(x, y) { bx = x; by = Math.min(y, GY - 4 * S); },
    frame(dt, t) {
      stage({ night: 0.95 });
      const f = D.flicker;
      const flick = 1 - 0.18 * f * (0.5 - 0.5 * noise(t * 11 + 3));           // the flame's breath
      const gx = bx + Math.cos(t * 0.5) * W * 0.05 * D.drift + noise(t * 9 + 7) * 2.5 * S * f;
      const gy = by + Math.sin(t * 0.37) * H * 0.04 * D.drift + noise(t * 9 + 20) * 2.5 * S * f;
      lx += (gx - lx) * smooth(8, dt); ly += (gy - ly) * smooth(8, dt);
      const pts = visPoly(lx, ly, segs);
      for (let p = 0; p < pillars.length; p++) wall(pillars[p][0] * W, pillars[p][1] * H, pillars[p][2] * W, GY - pillars[p][1] * H);
      hero(W * 0.14, GY, { face: 1 });
      const R = W * D.reach * flick;
      ctx.save(); pathOf(ctx, pts); ctx.clip();       // the light's colour, only where it reaches
      glow(lx, ly, R * 0.9, D.colour, 0.3);
      ctx.restore();
      const L = layer("dark"), c = L.ctx;              // darkness minus (polygon ∩ falloff)
      c.globalCompositeOperation = "source-over"; c.globalAlpha = 1;
      c.clearRect(0, 0, W, H);
      c.fillStyle = "rgba(6,5,16,0.93)"; c.fillRect(0, 0, W, H);
      c.save(); pathOf(c, pts); c.clip();
      cutLight(L, lx, ly, R, D.soft, 1);
      c.restore();
      ctx.drawImage(L.cv, 0, 0, W, H);
      ctx.strokeStyle = rgba(D.colour, 0.25); ctx.lineWidth = 1;   // the shadow edges
      pathOf(ctx, pts); ctx.stroke();
      line(lx, ly + 2 * S, lx, ly + 12 * S, "#5A3E2B", 2 * S);   // the torch
      ctx.globalCompositeOperation = "lighter";
      glow(lx, ly, 7 * S * flick, D.colour, 0.9); glow(lx, ly - 2 * S, 3 * S, "#FFF6D8", 0.9);
      ctx.globalCompositeOperation = "source-over";
      label("flame " + flick.toFixed(2), lx, ly - 12 * S, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Umbra", "Ultraviolet", "a cold purple light with a hard falloff and almost no flicker — the shadows stand still and cut like paper", { colour: "#B070FF", soft: 0.05, flicker: 0.15 });


def("N", "Night", "light", "a blue MULTIPLY layer over the day, holes cut for lamps and windows, additive glows through them (ch03 additive, atlas Lantern) — drag: time of day", function (u) {
  var D = { tint: "#1B2A7A",    // the night's colour
            depth: 0.82,        // how dark full night gets (the layer's alpha at midnight)
            lamps: ["#F5C169", "#F5C169"],   // the two street lamps' colours
            day: 18,            // seconds for a full day
            hold: 4,            // seconds a dragged time of day holds before the clock resumes
            label: "scene × tint·n − holes(lamps) + lighter glows" };
  const { ctx, W, H, GY, TAU, stage, hero, house, lamp, tree, layer, cutLight, glow, dot, line, label, clamp, rgba, INK, DIM, SUN } = u;
  // a NIGHT OVERLAY is the cheapest lighting there is: one blue rect drawn
  // with MULTIPLY (it darkens toward blue, never lightens), and a HOLE cut
  // out of it (destination-out) around every light source so the scene keeps
  // its day colours there. an ADDITIVE glow (chapter 03's "lighter") over the
  // hole gives the lamp its colour. n runs 0 at noon to 1 at midnight and
  // scales all three, so one number is the whole time of day.
  const S = H / 170;
  const lampsX = [W * 0.32, W * 0.72], lampY = GY - H * 0.3 - 8;   // the kit lamp's bulb sits 0.3 H + 8 above its foot
  const houses = [[W * 0.06, W * 0.16], [W * 0.5, W * 0.15], [W * 0.84, W * 0.13]], hh = H * 0.22;
  let tod = 0.1, hold = 0;                             // 0 = noon, 0.5 = midnight
  return {
    drag: true,
    press(x, y) { tod = clamp(x / W, 0, 1) * 0.5; hold = D.hold; },
    frame(dt, t) {
      hold = Math.max(0, hold - dt);
      if (hold <= 0) tod = (tod + dt / Math.max(1, D.day)) % 1;
      const n = 0.5 - 0.5 * Math.cos(tod * TAU);
      stage({ night: n * 0.8 });
      const a = tod * TAU;                             // the sun and the moon on one wheel
      const sx = W * 0.5 - Math.sin(a) * W * 0.4, sy = H * 0.55 - Math.cos(a) * H * 0.45;
      glow(sx, sy, 16 * S, SUN, 0.8); dot(sx, sy, 6 * S, "#FFF4D0");
      dot(W * 0.5 + Math.sin(a) * W * 0.4, H * 0.55 + Math.cos(a) * H * 0.45, 5 * S, "#E0E4F5");
      tree(W * 0.4, GY, H * 0.28);
      const lit = [];                                  // this frame's light sources: x, y, r, colour, isLamp
      for (let i = 0; i < houses.length; i++) {
        const on = n > 0.5 + i * 0.06;
        house(houses[i][0], GY, houses[i][1], hh, on);
        if (on) { lit.push([houses[i][0] + houses[i][1] * 0.31, GY - hh * 0.56, W * 0.07, SUN, false]); lit.push([houses[i][0] + houses[i][1] * 0.69, GY - hh * 0.56, W * 0.07, SUN, false]); }
      }
      for (let i = 0; i < lampsX.length; i++) {
        const on = n > 0.38 + i * 0.05;
        lamp(lampsX[i], GY, on);
        if (on) lit.push([lampsX[i], lampY, W * 0.16, D.lamps[i % D.lamps.length], true]);
      }
      hero(W * 0.62, GY, { face: -1 });
      const L = layer("night"), c = L.ctx;             // the tint, then the holes
      c.globalCompositeOperation = "source-over"; c.globalAlpha = 1;
      c.clearRect(0, 0, W, H);
      c.fillStyle = rgba(D.tint, n * D.depth); c.fillRect(0, 0, W, H);
      for (let i = 0; i < lit.length; i++) cutLight(L, lit[i][0], lit[i][1], lit[i][2], 0.6, 0.9);
      ctx.globalCompositeOperation = "multiply";
      ctx.drawImage(L.cv, 0, 0, W, H);
      ctx.globalCompositeOperation = "lighter";        // the additive half
      for (let i = 0; i < lit.length; i++) {
        glow(lit[i][0], lit[i][1], lit[i][2] * 1.1, lit[i][3], 0.35 * n);
        if (lit[i][4]) dot(lit[i][0], lit[i][1], 4 * S, lit[i][3]);
      }
      ctx.globalCompositeOperation = "source-over";
      const bx = 10 * S, bw = W - 20 * S, by = H - 20 * S;   // the slider
      line(bx, by, bx + bw, by, rgba(INK, 0.35));
      const k = tod <= 0.5 ? tod * 2 : (1 - tod) * 2;
      dot(bx + bw * k, by, 3 * S, INK);
      label("noon", bx, by - 4, DIM); label("midnight", bx + bw, by - 4, DIM, "right");
      label("n = " + n.toFixed(2) + " · " + lit.length + " holes", W / 2, by - 4, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Night", "Neonnight", "a deeper violet dark with one magenta and one cyan lamp — the same holes, a different city", { tint: "#2A0A3A", lamps: ["#FF3AC8", "#3AF0FF"], depth: 0.92 });

def("Z", "Zap", "light", "a white layer whose alpha decays exponentially, a jagged bolt, thunder that arrives late (distance ÷ sound speed, as a bar) — press to strike now", function (u) {
  var D = { peak: 0.85,         // the flash's brightness at the strike
            decay: 9,           // per second: a ← a·e^(−decay·dt)
            every: 5.5,         // seconds between autopilot strikes (± a third)
            delay: 2.4,         // seconds of thunder delay per stage-width of distance
            distant: false,     // true: bolts stay behind the hills, dim and short
            rumble: 1.6,        // seconds the thunder lasts
            label: "flash: a ← a·e^(−k·dt) · thunder after 0.3 + |x − hero|/W · delay" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, house, rect, line, label, rand, noise, noiseBurst, clamp, rgba, INK, DIM, HOT, SPARK } = u;
  // LIGHTNING is an exponential decay you can see: the strike sets a = 1 and
  // every frame multiplies it by e^(−k·dt), so the flash is framerate-proof
  // and never quite reaches zero. the bolt is a random walk downward with two
  // branches. thunder is the same event arriving late: light is instant,
  // sound crosses the stage at "delay" seconds per width, so a bar counts
  // the distance down and the rumble lands when it fills (the atlas's
  // Stormfront had the flash; this has the timing). sound only after a press.
  const S = H / 170, hx = W * 0.3;
  const pending = [];
  let fa = 0, ba = 0, bolt = null, nextAt = 3, armed = false, rumble = 0;
  function strike(x) {
    x = clamp(x, 6, W - 6);
    const bottom = D.distant ? GY - H * 0.14 : GY, nseg = 11, spread = W * (D.distant ? 0.012 : 0.035);
    const main = [];
    let px = x + rand(-W * 0.05, W * 0.05);
    for (let i = 0; i <= nseg; i++) { if (i > 0 && i < nseg) px += rand(-spread, spread); main.push([i === nseg ? x : px, bottom * i / nseg]); }
    const branches = [];
    for (let b = 0; b < 2; b++) {
      const p = main[3 + b * 3], dir = b === 0 ? -1 : 1, br = [p];
      let qx = p[0], qy = p[1];
      for (let i = 0; i < 3; i++) { qx += dir * rand(spread * 0.6, spread * 1.6); qy += bottom / nseg * rand(0.5, 1); br.push([qx, qy]); }
      branches.push(br);
    }
    bolt = { main: main, branches: branches };
    ba = 1; fa = 1;
    const dist = D.distant ? 1.5 : Math.abs(x - hx) / W, at = 0.3 + dist * D.delay;
    if (pending.length < 4) pending.push({ at: at, total: at });
  }
  function stroke(pts, c, w) {
    ctx.strokeStyle = c; ctx.lineWidth = w; ctx.lineJoin = "round";
    ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
    ctx.stroke();
  }
  return {
    press(x, y) { armed = true; strike(x); nextAt = D.every * rand(0.8, 1.3); },
    frame(dt, t) {
      nextAt -= dt;
      if (nextAt <= 0) { strike(rand(W * 0.1, W * 0.9)); nextAt = D.every * rand(0.7, 1.3); }
      fa *= Math.exp(-D.decay * dt);                   // ← the decay
      ba = Math.max(0, ba - dt * 5);
      stage({ night: 0.85 });
      house(W * 0.62, GY, W * 0.16, H * 0.22, false); tree(W * 0.85, GY, H * 0.3);
      hero(hx + (rumble > 0 ? noise(t * 30) * 1.5 * S : 0), GY, { face: 1, pose: fa > 0.3 ? "hurt" : "stand" });
      if (bolt && ba > 0.02) {
        const a = D.distant ? 0.5 : 1;
        stroke(bolt.main, rgba(SPARK, ba * a * 0.3), 6 * S);
        stroke(bolt.main, rgba("#FFFFFF", ba * a), 1.6 * S);
        for (let b = 0; b < bolt.branches.length; b++) stroke(bolt.branches[b], rgba(SPARK, ba * a * 0.8), 1 * S);
      }
      if (fa > 0.003) rect(0, 0, W, H, "rgba(255,255,255," + (fa * D.peak).toFixed(3) + ")");   // the flash
      for (let i = pending.length - 1; i >= 0; i--) {  // thunder in flight
        pending[i].at -= dt;
        if (pending[i].at <= 0) {
          pending.splice(i, 1); rumble = D.rumble;
          if (armed) noiseBurst({ dur: D.rumble, vol: 0.22, lowpass: 260, sweepTo: 70 });
        }
      }
      rumble = Math.max(0, rumble - dt);
      const bw = W * 0.34, bx = 8 * S, by = H - 22 * S;   // the thunder bar
      ctx.strokeStyle = rgba(INK, 0.4); ctx.lineWidth = 1; ctx.strokeRect(bx, by, bw, 6 * S);
      for (let i = 0; i < pending.length; i++) rect(bx + 1, by + 1, (bw - 2) * (1 - pending[i].at / pending[i].total), 6 * S - 2, rgba(INK, 0.35));
      if (rumble > 0) for (let k = 0; k < 12; k++) rect(bx + 1 + k * (bw - 2) / 12, by + 3 * S - noise(t * 40 + k * 3) * 4 * S * rumble / D.rumble, (bw - 2) / 12 - 1, 1.5 * S, HOT);
      label(rumble > 0 ? "thunder!" : (pending.length ? "sound travelling…" : "quiet"), bx + bw + 4, by + 6 * S - 1, DIM);
      const gw = 40 * S, gx = W - gw - 8 * S, gy = 8 * S, gh = 16 * S;   // the decay curve, with the flash's value on it
      ctx.strokeStyle = rgba(INK, 0.3); ctx.lineWidth = 1; ctx.beginPath();
      for (let i = 0; i <= 20; i++) ctx.lineTo(gx + gw * i / 20, gy + gh * (1 - Math.exp(-D.decay * i / 20 * 0.6)));
      ctx.stroke();
      line(gx, gy + gh * (1 - fa), gx + gw, gy + gh * (1 - fa), rgba(SPARK, 0.7));
      label("a = " + fa.toFixed(2), gx + gw, gy + gh + 10, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Zap", "Zephyrstorm", "the storm on the far side of the hills: short dim bolts behind the ridge, a third of the flash, thunder that takes nine seconds", { peak: 0.3, distant: true, delay: 6 });
warnOf("Zap", "contains flashing light");

def("S", "Stealth", "light", "a meter that fills while the hero stands in a guard's VIEW CONE, faster up close, drains outside: the ? then the ! (lexicon Ghost) — drag the hero", function (u) {
  var D = { guards: 1,          // how many guards (up to two)
            cone: 64,           // view cone width, degrees
            range: 0.42,        // how far a guard sees, of W
            fill: 0.8,          // meter per second at the edge of the range (doubles up close)
            drain: 0.7,         // meter per second lost when unseen
            sweep: 0.9,         // how fast the gaze sweeps (rad/s of a sine)
            hold: 4,            // seconds a dragged hero holds before it paces again
            label: "m += dt·fill·(2 − d/range) in the cone · m −= dt·drain outside" };
  const { ctx, W, H, GY, TAU, stage, hero, crate, line, rect, text, label, len, clamp, rgba, SUN, HOT, GOOD, INK, DIM } = u;
  // a DETECTION METER turns the lexicon's Ghost test (in the cone if
  // gaze · dir > cos(half)) from a yes/no into a number that accumulates:
  // inside the cone it fills at a rate that grows as the distance shrinks,
  // outside it drains. half full shows the "?" (the guard is suspicious),
  // full shows the "!" (found) and the level resets. a crate between eye
  // and hero blocks the line (one segment-vs-rect test), so cover counts.
  const S = H / 170, hs = Math.max(2, Math.round(H / 60));
  const gx = [W * 0.7, W * 0.22], gph = [0, 2.1], gface = [-1, 1];
  const cx = W * 0.47, cw = H * 0.1;                    // the cover crate
  const half = D.cone * Math.PI / 360, range = W * D.range;
  const meters = [0, 0];
  let hx = W * 0.35, tx = hx, hold = 0, clock = 0, alert = 0, caught = 0, face = 1;
  function blocked(ex, ey, px, py) {                   // does the crate stand between the eye and the point?
    if ((cx - ex) * (cx - px) > 0) return false;
    const k = (cx - ex) / ((px - ex) || 1e-6), y = ey + (py - ey) * k;
    return y > GY - cw && y < GY;
  }
  return {
    drag: true,
    press(x, y) { tx = clamp(x, 8, W - 8); hold = D.hold; },
    frame(dt, t) {
      stage({ night: 0.55 });
      hold = Math.max(0, hold - dt);
      if (hold <= 0) tx = W * (0.5 + 0.42 * Math.sin(t * 0.22));
      const dx = tx - hx, moving = Math.abs(dx) > 1;
      if (moving) { const sp = Math.min(Math.abs(dx), W * 0.16 * dt); hx += Math.sign(dx) * sp; face = dx < 0 ? -1 : 1; clock += dt; }
      crate(cx, GY, cw);
      const chestX = hx, chestY = GY - 9 * hs;
      let worst = 0;
      for (let g = 0; g < Math.min(2, D.guards); g++) {
        const ex = gx[g], ey = GY - 14 * hs;
        const base = gface[g] > 0 ? 0 : Math.PI;
        const h = alert > 0 ? Math.atan2(chestY - ey, chestX - ex) : base + Math.sin(t * D.sweep + gph[g]) * 0.75;
        const dxh = chestX - ex, dyh = chestY - ey, d = len(dxh, dyh) || 1;
        const dotp = (dxh * Math.cos(h) + dyh * Math.sin(h)) / d;   // ← the Ghost test
        const seen = alert <= 0 && d < range && dotp > Math.cos(half) && !blocked(ex, ey, chestX, chestY);
        if (seen) meters[g] = Math.min(1, meters[g] + dt * D.fill * (2 - d / range));
        else if (alert <= 0) meters[g] = Math.max(0, meters[g] - dt * D.drain);
        worst = Math.max(worst, meters[g]);
        const col = alert > 0 ? HOT : (seen ? SUN : INK);
        ctx.fillStyle = rgba(col, alert > 0 ? 0.22 : 0.06 + 0.16 * meters[g]);
        ctx.beginPath(); ctx.moveTo(ex, ey); ctx.arc(ex, ey, range, h - half, h + half); ctx.closePath(); ctx.fill();
        line(ex, ey, ex + Math.cos(h - half) * range, ey + Math.sin(h - half) * range, rgba(col, 0.35));
        line(ex, ey, ex + Math.cos(h + half) * range, ey + Math.sin(h + half) * range, rgba(col, 0.35));
        hero(ex, GY, { face: Math.cos(h) < 0 ? -1 : 1, shirt: "#4A4470", tint: alert > 0 ? rgba(HOT, 0.4) : undefined });
        if (alert > 0) text("!", ex, GY - 19 * hs, 14 * S, HOT, "center", true);
        else if (meters[g] > 0.5) text("?", ex, GY - 19 * hs, 14 * S, SUN, "center", true);
      }
      if (worst >= 1 && alert <= 0) { alert = 2.5; caught++; }
      if (alert > 0) { alert -= dt; if (alert <= 0) { meters[0] = 0; meters[1] = 0; } }
      hero(hx, GY, { face: face, pose: moving ? "run" : "stand", frame: clock });
      const mw = 26 * S, mx = hx - mw / 2, my = GY - 20 * hs;   // the meter above the hero
      ctx.strokeStyle = rgba(INK, 0.5); ctx.lineWidth = 1; ctx.strokeRect(mx, my, mw, 4 * S);
      rect(mx + 1, my + 1, (mw - 2) * worst, 4 * S - 2, worst < 0.5 ? GOOD : (worst < 1 ? SUN : HOT));
      line(mx + mw / 2, my - 1, mx + mw / 2, my + 4 * S + 1, rgba(INK, 0.6));
      label("?", mx + mw / 2, my - 3, DIM, "center"); label("!", mx + mw, my - 3, DIM, "center");
      label("caught ×" + caught, W - 6, 12, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Stealth", "Sentinel", "two guards sweeping out of phase and a meter that fills two and a half times as fast — the level where you wait for both to look away", { guards: 2, fill: 2 });

def("V", "Volumetric", "light", "translucent QUADS from each window along the sun's direction, fading with length, dust that stays inside (atlas Motes, angled) — press: sun by x", function (u) {
  var D = { windows: 3,         // how many windows in the back wall
            width: 0.09,        // a window's width, of W
            tilt: 0.4,          // the idle sun's swing, radians from vertical
            drift: 0.2,         // how fast the idle sun swings
            haze: 0.4,          // the shaft's alpha at the window
            dust: 70,           // motes, shared across the shafts
            hold: 5,            // seconds a pressed angle holds
            label: "quad = window ⊕ sunDir·L · α fades along L · motes ∈ quad" };
  const { ctx, W, H, GY, TAU, stage, hero, crate, rect, line, dot, arrow, label, rng, noise, clamp, rgba, SUN, DIM } = u;
  // LIGHT SHAFTS are geometry, not blur: each window's two top corners are
  // pushed along the sun's direction until they meet the floor, and the four
  // points make a quad filled with one linear gradient (bright at the window,
  // gone at the floor) drawn with "lighter". the dust is parametric — a mote
  // is (which shaft, how far along, how far across), so it can never leave
  // the light; the atlas's Motes did this for one vertical shaft.
  const S = H / 170;
  const wy0 = H * 0.1, wy1 = H * 0.24, ww = W * D.width, Lf = GY - wy0;
  const wins = [];
  const nw = Math.max(1, D.windows);
  for (let i = 0; i < nw; i++) wins.push(W * (0.5 + (i - (nw - 1) / 2) * 0.28) - ww / 2);
  const R = rng(5), motes = [];
  for (let i = 0; i < D.dust; i++) motes.push({ w: i % nw, s: R(), v: R(), sp: 0.03 + R() * 0.05, ph: R() * 100 });
  let ang = 0, held = 0, hold = 0;
  return {
    press(x, y) { held = (clamp(x / W, 0, 1) - 0.5) * 1.2; hold = D.hold; },
    frame(dt, t) {
      hold = Math.max(0, hold - dt);
      const goal = hold > 0 ? held : D.tilt * Math.sin(t * D.drift);
      ang += (goal - ang) * Math.min(1, dt * 3);
      const tanA = Math.tan(clamp(ang, -1.1, 1.1)), sinA = Math.sin(ang), cosA = Math.cos(ang);
      stage({ night: 0.93 });
      rect(0, 0, W, GY, "rgba(40,34,62,0.7)");        // the back wall
      crate(W * 0.28, GY, H * 0.11);
      hero(W * 0.6, GY, { face: -1 });
      ctx.globalCompositeOperation = "lighter";
      for (let i = 0; i < wins.length; i++) {          // one quad per window
        const xl = wins[i], xr = xl + ww;
        const g = ctx.createLinearGradient(0, wy0, 0, GY);
        g.addColorStop(0, rgba(SUN, D.haze)); g.addColorStop(1, rgba(SUN, 0));
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.moveTo(xl, wy0); ctx.lineTo(xr, wy0); ctx.lineTo(xr + Lf * tanA, GY); ctx.lineTo(xl + Lf * tanA, GY); ctx.closePath(); ctx.fill();
        ctx.fillStyle = rgba(SUN, D.haze * 0.5);      // the pool where it lands
        ctx.beginPath(); ctx.ellipse(xl + ww / 2 + Lf * tanA, GY, ww * 0.9, 3 * S, 0, 0, TAU); ctx.fill();
      }
      for (let i = 0; i < motes.length; i++) {         // dust: parametric, so it stays inside
        const m = motes[i];
        m.s += m.sp * dt; if (m.s > 1) m.s -= 1;
        const v = clamp(m.v + 0.08 * noise(t * 0.3 + m.ph), 0, 1);
        const xl = wins[m.w] || wins[0];
        const x = xl + v * ww + m.s * Lf * tanA, y = wy0 + m.s * Lf;
        const tw = 0.5 + 0.5 * noise(t * 2 + m.ph);
        dot(x, y, (0.8 + tw) * S, rgba("#FFF4D0", D.haze * 1.4 * (1 - m.s * 0.8) * tw));
      }
      ctx.globalCompositeOperation = "source-over";
      for (let i = 0; i < wins.length; i++) {          // the windows themselves
        rect(wins[i], wy0, ww, wy1 - wy0, "#FFF0C8");
        line(wins[i] + ww / 2, wy0, wins[i] + ww / 2, wy1, "#2B2440", 1.5 * S);
        line(wins[i], (wy0 + wy1) / 2, wins[i] + ww, (wy0 + wy1) / 2, "#2B2440", 1.5 * S);
      }
      const ax = W - 22 * S, ay = 8 * S;               // the sun's direction
      arrow(ax, ay, ax + sinA * 16 * S, ay + cosA * 16 * S, SUN);
      label("sun " + Math.round(ang * 180 / Math.PI) + "°", ax - 4, ay + 10, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Volumetric", "Vault", "one narrow slit high in the wall and twice the dust, thick as smoke — a tomb, opened", { windows: 1, width: 0.05, dust: 160, haze: 0.55 });


def("D", "Dusk", "light", "windows switching on at STAGGERED thresholds as the sky darkens on a clock, headlights on a far road (atlas Skyline, timed) — press to jump to dusk", function (u) {
  var D = { day: 26,            // seconds from noon to full night
            houses: 6,          // houses in the row
            stagger: 0.35,      // the spread of the window thresholds (each in 0.35 .. 0.35 + stagger)
            cars: 3,            // cars on the road
            reverse: false,     // true: the clock runs night → day (windows go off)
            hold: 3,            // seconds the end of the cycle holds before it wraps
            label: "window_i lights when n > thr_i · thr_i ∈ [0.35, 0.35 + stagger] · headlights at n > 0.3" };
  const { ctx, W, H, GY, TAU, stage, house, rect, dot, line, glow, ring, label, rng, clamp, ease, mix, rgba, SUN, SPARK, HOT, INK, DIM } = u;
  // DISTANT LIGHTS are the cheapest "a town lives here": every window owns a
  // THRESHOLD on the night value n, drawn once from a seeded random, and
  // switches on (with a short ease, so it does not pop) the moment n passes
  // it. one clock drives the sky, the windows, the stars, and the headlights
  // — the atlas's Skyline had the lit windows; this has the evening they
  // switch on in. reverse the clock and the same thresholds give you dawn.
  const S = H / 170, R = rng(11);
  const hw = W * 0.8 / D.houses * 0.68, hh = H * 0.2, road = H * 0.9;
  const hs = [], thr = [];
  for (let i = 0; i < D.houses; i++) { hs.push(W * (0.08 + i * 0.84 / D.houses)); thr.push([0.35 + D.stagger * R(), 0.35 + D.stagger * R()]); }
  const stars = []; for (let i = 0; i < 30; i++) stars.push([R() * W, R() * H * 0.5, R() * 10]);
  const cars = []; for (let i = 0; i < D.cars; i++) cars.push({ x: R() * W, v: W * (0.06 + R() * 0.08), dir: R() < 0.5 ? -1 : 1 });
  let clock = 0;
  return {
    press() { clock = (D.reverse ? 0.25 : 0.3) * D.day; },
    frame(dt, t) {
      const cycle = D.day + D.hold;
      clock += dt; if (clock > cycle) clock -= cycle;
      let n = clamp(clock / D.day, 0, 1);
      if (D.reverse) n = 1 - n;
      stage({ night: n });
      for (let i = 0; i < stars.length; i++) dot(stars[i][0], stars[i][1], 0.8 * S, rgba(INK, clamp((n - 0.55) / 0.4, 0, 1) * (0.5 + 0.4 * Math.sin(t * 2 + stars[i][2]))));
      for (let i = 0; i < hs.length; i++) {            // the houses, then their windows by threshold
        house(hs[i], GY, hw, hh, false);
        for (let w = 0; w < 2; w++) {
          const b = ease((n - thr[i][w]) / 0.03);      // 0 → 1 across a sliver of n: on, without a pop
          const wx = hs[i] + hw * (w ? 0.58 : 0.2), wy = GY - hh * 0.7;
          rect(wx, wy, hw * 0.22, hh * 0.28, mix("#2B2440", SUN, b));
          if (b > 0) { ctx.globalCompositeOperation = "lighter"; glow(wx + hw * 0.11, wy + hh * 0.14, hw * 0.45, SUN, 0.3 * b); ctx.globalCompositeOperation = "source-over"; }
        }
      }
      rect(0, road - 4 * S, W, 8 * S, "rgba(20,18,34,0.85)");   // the far road
      const beams = n > 0.3;
      for (let i = 0; i < cars.length; i++) {
        const c = cars[i];
        c.x += c.v * c.dir * dt;
        if (c.x > W + 30 * S) c.x = -30 * S; else if (c.x < -30 * S) c.x = W + 30 * S;
        rect(c.x - 7 * S, road - 4 * S, 14 * S, 4 * S, "#3A3355");
        dot(c.x - 4 * S, road, 1.2 * S, "#1A1830"); dot(c.x + 4 * S, road, 1.2 * S, "#1A1830");
        if (beams) {
          const fx = c.x + c.dir * 7 * S, k = clamp((n - 0.3) / 0.2, 0, 1);
          ctx.fillStyle = rgba(SPARK, 0.12 * k);      // the beam: a triangle ahead of the car
          ctx.beginPath(); ctx.moveTo(fx, road - 2 * S); ctx.lineTo(fx + c.dir * 26 * S, road - 6 * S); ctx.lineTo(fx + c.dir * 26 * S, road + 3 * S); ctx.closePath(); ctx.fill();
          dot(fx, road - 2 * S, 1.3 * S, rgba(SPARK, k)); dot(c.x - c.dir * 7 * S, road - 2 * S, 1 * S, rgba(HOT, k));
        }
      }
      const bx = 10 * S, bw = W - 20 * S, by = H - 20 * S;   // the threshold strip
      line(bx, by, bx + bw, by, rgba(INK, 0.35));
      for (let i = 0; i < thr.length; i++) for (let w = 0; w < 2; w++) line(bx + bw * thr[i][w], by - 3 * S, bx + bw * thr[i][w], by + 3 * S, n > thr[i][w] ? SUN : DIM);
      dot(bx + bw * n, by, 3 * S, INK);
      label("n = " + n.toFixed(2), bx + bw * n, by - 6, DIM, "center");
      label(D.reverse ? "night → day" : "noon → night", bx + bw, by - 6, DIM, "right");
      ring(W - 16 * S, 14 * S, 8 * S, rgba(INK, 0.4));   // the clock
      line(W - 16 * S, 14 * S, W - 16 * S + Math.sin(clock / cycle * TAU) * 7 * S, 14 * S - Math.cos(clock / cycle * TAU) * 7 * S, INK, 1.5);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Dusk", "Dawnbreak", "the same thresholds with the clock run backward: a black sky lightening, windows going out one by one, headlights switching off", { reverse: true, day: 20 });

def("B", "Blobshadow", "light", "the blob sits where a GROUND RAYCAST under the hero lands, tilts to the surface NORMAL, shrinks with height (atlas Contact, on a hill) — press to jump", function (u) {
  var D = { size: 1,            // the blob's radius at rest, × 10 px (scaled)
            shrink: 0.6,        // how much of the radius is lost at the top of the jump
            soft: 0.5,          // the blob's edge: 0 hard, 1 all gradient
            jumpH: 0.26,        // jump apex, of H
            speed: 0.22,        // run speed, of W per second
            g: 2.2,             // gravity, × H per s²
            hill: 0.2,          // the hill's height, of H
            label: "ray ↓ hits g(x) · tilt = atan g′(x) · r = r₀·(1 − shrink·h/hmax)" };
  const { ctx, W, H, GY, TAU, stage, hero, arrow, line, dot, label, clamp, rgba, INK, DIM, GOOD } = u;
  // a BLOB SHADOW does not need a light: it needs to know where the ground
  // is UNDER the sprite. cast a ray straight down from the feet (here the
  // ground is a function, so the hit is g(x) directly), read the slope there
  // (g′(x), the lexicon's Normals) and rotate the ellipse to lie on it; the
  // height above the hit shrinks and fades it, as the atlas's Contact did on
  // flat ground. the shadow is what tells the eye where the jump will land.
  const S = H / 170, G = H * D.g, hmax = H * D.jumpH;
  const c1 = W * 0.58, w1 = W * 0.16, c2 = W * 0.2, w2 = W * 0.1;
  function g(x) { const a = (x - c1) / w1, b = (x - c2) / w2; return GY - H * D.hill * (Math.exp(-a * a) + 0.4 * Math.exp(-b * b)); }
  function gp(x) { const a = (x - c1) / w1, b = (x - c2) / w2; return -H * D.hill * (Math.exp(-a * a) * (-2 * a / w1) + 0.4 * Math.exp(-b * b) * (-2 * b / w2)); }
  let x = W * 0.05, y = g(x), vy = 0, air = false, clock = 0, autoOK = true;
  function jump() { if (!air) { air = true; vy = -Math.sqrt(2 * G * hmax); } }
  return {
    press() { jump(); },
    frame(dt, t) {
      stage({ night: 0.1 });
      x += W * D.speed * dt; clock += dt;
      if (x > W + 20) { x = -20; autoOK = true; }
      const gy = g(x);
      if (air) { y += vy * dt; vy += G * dt; if (y >= gy && vy > 0) { y = gy; air = false; } }
      else { y = gy; if (autoOK && x > W * 0.33) { autoOK = false; jump(); } }
      ctx.fillStyle = "#4E7A44";                       // the hill
      ctx.beginPath(); ctx.moveTo(0, GY + 1);
      for (let xx = 0; xx <= W; xx += 4) ctx.lineTo(xx, g(xx));
      ctx.lineTo(W, GY + 1); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = "rgba(20,40,20,0.5)"; ctx.lineWidth = 1.5;
      ctx.beginPath(); for (let xx = 0; xx <= W; xx += 4) ctx.lineTo(xx, g(xx)); ctx.stroke();
      const h = Math.max(0, gy - y), k = clamp(h / hmax, 0, 1);
      const slope = gp(x), tilt = Math.atan(slope), nl = Math.sqrt(slope * slope + 1);
      const rx = 10 * S * D.size * (1 - D.shrink * k), ry = rx * 0.35, alpha = 0.6 * (1 - 0.65 * k);
      ctx.save(); ctx.translate(x, gy); ctx.rotate(tilt); ctx.scale(1, ry / rx);   // the blob, on the slope
      if (D.soft > 0) {
        const gr = ctx.createRadialGradient(0, 0, 0, 0, 0, rx);
        gr.addColorStop(0, "rgba(0,0,0," + alpha.toFixed(3) + ")"); gr.addColorStop(Math.max(0.01, 1 - D.soft), "rgba(0,0,0," + (alpha * 0.9).toFixed(3) + ")"); gr.addColorStop(1, "rgba(0,0,0,0)");
        ctx.fillStyle = gr;
      } else ctx.fillStyle = "rgba(0,0,0," + alpha.toFixed(3) + ")";
      ctx.beginPath(); ctx.arc(0, 0, rx, 0, TAU); ctx.fill();
      ctx.restore();
      if (air) {                                       // the ray, the hit, the normal
        ctx.setLineDash([3 * S, 3 * S]); line(x, y, x, gy, rgba(INK, 0.6)); ctx.setLineDash([]);
        label("h = " + Math.round(h), x + 6 * S, y + (gy - y) / 2 + 3, DIM);
      }
      dot(x, gy, 1.8 * S, INK);
      arrow(x, gy, x + slope / nl * 14 * S, gy - 1 / nl * 14 * S, GOOD);
      hero(x, y, { face: 1, pose: air ? "jump" : "run", frame: clock });
      label("tilt " + Math.round(tilt * 180 / Math.PI) + "° · r " + rx.toFixed(1), W / 2, 12 * S, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Blobshadow", "Brightnoon", "half the blob, nearly gone at the apex, with a hard edge — the sun straight overhead", { size: 0.55, shrink: 0.85, soft: 0.1 });

def("B", "Bloom", "light", "a GLOW MASK: only bulbs and the laser go to a layer, blurred by offset copies and added back; the scene stays crisp (ch06 glow) — press to hang a bulb", function (u) {
  var D = { radius: 5,          // blur radius, px (scaled to the card)
            strength: 1,        // how much of the blur is added back
            mask: "emitters",   // "emitters": only the light sources bloom · "all": the whole frame does
            laser: true,        // a sweeping laser among the emitters
            max: 8,             // hung bulbs kept (the oldest falls when a new one comes)
            label: "mask → Σ offset copies (r, then 2r) → lighter × strength" };
  const { ctx, W, H, GY, TAU, stage, hero, lamp, tree, layer, line, rect, label, rgba, SUN, HOT, SPARK, INK, DIM } = u;
  // SELECTIVE BLOOM is a question of WHAT gets blurred. chapter 06 glowed a
  // whole sprite; a real bloom pass would blur everything above a brightness
  // threshold, and the cheap 2D answer is to skip the threshold: draw only
  // the things that should glow (the EMITTERS) into their own layer, blur
  // that — eight offset copies at 1/8 alpha, twice — and add it back with
  // "lighter". the scene underneath never blurs. mask: "all" shows the
  // difference: the whole frame goes to the blur, and everything overexposes.
  const S = H / 170, r = D.radius * S;
  const posts = [W * 0.25, W * 0.75], postY = GY - H * 0.3 - 8, bulbs = [];
  const lx0 = W * 0.06, ly0 = H * 0.12;
  function emitters(c, hitX) {                         // ONLY the light sources
    c.fillStyle = SUN;
    for (let i = 0; i < posts.length; i++) { c.beginPath(); c.arc(posts[i], postY, 5, 0, TAU); c.fill(); }
    for (let i = 0; i < bulbs.length; i++) { c.beginPath(); c.arc(bulbs[i][0], bulbs[i][1], 3.5 * S, 0, TAU); c.fill(); }
    if (D.laser) {
      c.strokeStyle = HOT; c.lineWidth = 1.5 * S;
      c.beginPath(); c.moveTo(lx0, ly0); c.lineTo(hitX, GY); c.stroke();
      c.fillStyle = SPARK; c.beginPath(); c.arc(hitX, GY, 3 * S, 0, TAU); c.fill();
    }
  }
  function blurInto(dst, src, rad) {                   // eight copies around a ring, added at 1/8 each
    const c = dst.ctx;
    c.globalCompositeOperation = "source-over"; c.globalAlpha = 1; c.clearRect(0, 0, W, H);
    c.globalCompositeOperation = "lighter"; c.globalAlpha = 1 / 8;
    for (let i = 0; i < 8; i++) { const a = i * TAU / 8; c.drawImage(src.cv, Math.cos(a) * rad, Math.sin(a) * rad, W, H); }
    c.globalAlpha = 1; c.globalCompositeOperation = "source-over";
  }
  return {
    press(x, y) { if (bulbs.length >= D.max) bulbs.shift(); bulbs.push([x, Math.min(y, GY - 6 * S)]); },
    frame(dt, t) {
      stage({ night: 0.75 });
      tree(W * 0.55, GY, H * 0.3);
      for (let i = 0; i < posts.length; i++) lamp(posts[i], GY, true);
      hero(W * 0.42, GY, { face: 1 });
      const ang = 0.9 + Math.sin(t * 0.7) * 0.45, hitX = lx0 + Math.cos(ang) * (GY - ly0) / Math.sin(ang);   // the laser turret's floor hit
      rect(lx0 - 5 * S, ly0 - 4 * S, 10 * S, 8 * S, "#3A3355");
      for (let i = 0; i < bulbs.length; i++) line(bulbs[i][0], 0, bulbs[i][0], bulbs[i][1], rgba(INK, 0.35));
      emitters(ctx, hitX);                             // crisp, in the scene
      const E = layer("emit"), B1 = layer("blur1"), B2 = layer("blur2");
      E.ctx.globalCompositeOperation = "source-over"; E.ctx.globalAlpha = 1; E.ctx.clearRect(0, 0, W, H);
      if (D.mask === "all") E.ctx.drawImage(ctx.canvas, 0, 0, W, H); else emitters(E.ctx, hitX);
      blurInto(B1, E, r); blurInto(B2, B1, r * 2);
      ctx.globalCompositeOperation = "lighter";
      ctx.globalAlpha = Math.min(1, D.strength); ctx.drawImage(B2.cv, 0, 0, W, H);
      ctx.globalAlpha = Math.min(1, D.strength * 0.5); ctx.drawImage(B1.cv, 0, 0, W, H);
      ctx.globalAlpha = 1; ctx.globalCompositeOperation = "source-over";
      const iw = W * 0.24, ih = iw * H / W, ix = W - iw - 6 * S, iy = 6 * S;   // the inset: the mask itself
      rect(ix, iy, iw, ih, "rgba(0,0,0,0.6)");
      ctx.drawImage(E.cv, ix, iy, iw, ih);
      ctx.strokeStyle = rgba(INK, 0.4); ctx.lineWidth = 1; ctx.strokeRect(ix, iy, iw, ih);
      label("mask: " + D.mask, ix + iw / 2, iy + ih + 10, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Bloom", "Blaze", "no mask at all: the whole frame goes to the blur and comes back added — the overexposed look, every edge haloed", { mask: "all", strength: 0.75, radius: 7 });

def("I", "Interior", "light", "four rooms, each dark until ENTERED: a hard-edged rect light per room that wakes on a tween (lexicon Zones, indoors) — press to send the hero there", function (u) {
  var D = { wake: 0.7,          // seconds for a room's light to come up
            linger: 0,          // seconds after leaving before a room fades (0 = it stays lit)
            fade: 1.2,          // seconds for a room to fade back to dark
            speed: 0.2,         // walk speed, of W per second
            dark: 0.9,          // an unlit room's overlay alpha
            label: "lit_i → 1 over wake s while hero ∈ room_i · α_i = dark·(1 − lit_i)" };
  const { ctx, W, H, GY, TAU, stage, hero, crate, tree, rect, line, dot, glow, label, clamp, ease, smooth, rgba, SUN, INK, DIM } = u;
  // ROOM-BASED LIGHTING skips the physics: the level is a list of RECTS, each
  // with one number, lit, that tweens toward 1 while the hero is inside it.
  // the overlay is a hard-edged dark rect per room at alpha dark·(1 − lit),
  // so a doorway is a sharp line between a lit room and a black one — the
  // lexicon's Zones, with a light instead of a state. a linger dial lets
  // rooms forget you: they fade back to dark a few seconds after you leave.
  const S = H / 170, hs = Math.max(2, Math.round(H / 60));
  const x0 = W * 0.08, x1 = W * 0.92, top = H * 0.12, mid = (top + GY) / 2, xm = (x0 + x1) / 2;
  const rooms = [{ x: x0, y: mid, w: xm - x0, h: GY - mid }, { x: xm, y: mid, w: x1 - xm, h: GY - mid },
                 { x: xm, y: top, w: x1 - xm, h: mid - top }, { x: x0, y: top, w: xm - x0, h: mid - top }];
  const ladder = [x1 - W * 0.05, x0 + W * 0.05];     // up on the right, down on the left
  const lit = [0, 0, 0, 0], away = [0, 0, 0, 0];
  let hx = x0 + W * 0.1, hy = GY, floor = 0, target = 1, tour = 1, phase = "walk", wait = 0, clock = 0, face = 1;
  function roomOf(x, fl) { return fl === 0 ? (x < xm ? 0 : 1) : (x < xm ? 3 : 2); }
  return {
    press(x, y) { target = roomOf(clamp(x, x0, x1), y < mid ? 1 : 0); tour = target; phase = "walk"; wait = 0; },
    frame(dt, t) {
      stage({ night: 0.6 });
      const tfloor = target >= 2 ? 1 : 0;
      if (phase === "walk") {
        const wx = tfloor !== floor ? ladder[tfloor === 1 ? 0 : 1] : rooms[target].x + rooms[target].w / 2;
        const dx = wx - hx;
        if (Math.abs(dx) > 1.5) { const sp = Math.min(Math.abs(dx), W * D.speed * dt); hx += Math.sign(dx) * sp; face = dx < 0 ? -1 : 1; clock += dt; }
        else if (tfloor !== floor) phase = "climb";
        else { phase = "idle"; wait = 1.6; }
      } else if (phase === "climb") {
        const ty = tfloor === 1 ? mid : GY;
        hy += (ty - hy) * smooth(4, dt);
        if (Math.abs(ty - hy) < 1) { hy = ty; floor = tfloor; phase = "walk"; }
      } else { wait -= dt; if (wait <= 0) { tour = (tour + 1) % 4; target = tour; phase = "walk"; } }
      const here = roomOf(hx, hy < (mid + GY) / 2 ? 1 : 0);
      for (let i = 0; i < 4; i++) {                    // ← the whole lighting model
        if (i === here) { lit[i] = Math.min(1, lit[i] + dt / Math.max(0.05, D.wake)); away[i] = 0; }
        else { away[i] += dt; if (D.linger > 0 && away[i] > D.linger) lit[i] = Math.max(0, lit[i] - dt / Math.max(0.05, D.fade)); }
      }
      rect(x0 - 3 * S, top - 3 * S, x1 - x0 + 6 * S, GY - top + 3 * S, "#4A4470");   // the house
      ctx.fillStyle = "#6E3A3A"; ctx.beginPath(); ctx.moveTo(x0 - 6 * S, top - 3 * S); ctx.lineTo(xm, top - H * 0.1); ctx.lineTo(x1 + 6 * S, top - 3 * S); ctx.closePath(); ctx.fill();
      for (let i = 0; i < 4; i++) rect(rooms[i].x, rooms[i].y, rooms[i].w, rooms[i].h, i % 2 ? "#8A82B0" : "#7E7AA8");
      line(x0, mid, x1, mid, "#2B2440", 2 * S); line(xm, top, xm, GY, "#2B2440", 2 * S);
      for (let l = 0; l < 2; l++) for (let k = 0; k < 6; k++) line(ladder[l] - 4 * S, mid + k * (GY - mid) / 6, ladder[l] + 4 * S, mid + k * (GY - mid) / 6, rgba(INK, 0.3));
      crate(x0 + W * 0.12, GY, H * 0.1);              // furniture, one per room
      rect(xm + W * 0.06, GY - 9 * S, 22 * S, 3 * S, "#5A3E2B"); rect(xm + W * 0.06, GY - 9 * S, 2 * S, 9 * S, "#5A3E2B"); rect(xm + W * 0.06 + 20 * S, GY - 9 * S, 2 * S, 9 * S, "#5A3E2B");
      rect(xm + W * 0.06, mid - 7 * S, 26 * S, 7 * S, "#6E3A3A"); rect(xm + W * 0.06, mid - 10 * S, 8 * S, 3 * S, "#E8E5F4");
      tree(x0 + W * 0.1, mid, H * 0.1);
      for (let i = 0; i < 4; i++) {                    // a bulb per room, brightening with lit
        const bx = rooms[i].x + rooms[i].w / 2, by = rooms[i].y + 4 * S;
        glow(bx, by, rooms[i].w * 0.5, SUN, 0.35 * lit[i]); dot(bx, by, 2 * S, lit[i] > 0.05 ? SUN : "#2B2440");
      }
      hero(hx, hy, { face: face, pose: phase === "walk" ? "run" : "stand", frame: clock, s: Math.max(1, Math.round(hs * 0.7)) });
      for (let i = 0; i < 4; i++) {                    // the overlay: hard-edged, one alpha per room
        rect(rooms[i].x, rooms[i].y, rooms[i].w, rooms[i].h, "rgba(10,8,22," + (D.dark * (1 - ease(lit[i]))).toFixed(3) + ")");
        label("lit " + lit[i].toFixed(2), rooms[i].x + 4, rooms[i].y + 11, i === here ? SUN : DIM);
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Interior", "Infrared", "rooms that forget you: two seconds after you leave, a room fades back to black — only where you are is ever lit", { linger: 2, fade: 1.5 });

def("Z", "Zonelight", "light", "colour-coded light: the tint says safe or danger before the enemy does; zones pulse, an enemy patrols the red, the hero wears the tint — press to move", function (u) {
  var D = { zones: [{ x: 0, w: 0.34, kind: "safe" }, { x: 0.34, w: 0.36, kind: "danger" }, { x: 0.7, w: 0.3, kind: "safe" }],   // x, w of W
            colours: { safe: "#9BE28A", danger: "#F58A8A" },
            pulse: 1.2,         // danger's pulse rate, Hz (safe pulses at half)
            soft: 0,            // how much of a zone's width is feathered edge (0 = hard)
            entryFlash: 0,      // seconds a danger zone flares when the hero steps in (0 = never)
            speed: 0.18,        // hero speed, of W per second
            hold: 4,            // seconds a pressed target holds before the pacing resumes
            label: "tint = colours[zone(x)] · α = base + pulse·sin(t·rate)" };
  const { ctx, W, H, GY, TAU, stage, hero, glow, rect, dot, text, label, clamp, rgba, HOT, INK, DIM } = u;
  // COLOUR-CODED LIGHT is a rule made visible: every zone is a column of
  // tinted light ("lighter", so it brightens what it covers) and the tint IS
  // the message — green for safe, red for danger — read from across the
  // room before the enemy is. the hero picks up the tint of the zone it
  // stands in (chapter 03's tint, driven by position), and danger pulses
  // twice as fast as safe, so the rhythm says it too.
  const S = H / 170, hs = Math.max(2, Math.round(H / 60));
  let dz = -1; for (let i = 0; i < D.zones.length; i++) if (D.zones[i].kind === "danger" && dz < 0) dz = i;
  const eb0 = dz >= 0 ? D.zones[dz].x * W + 6 * hs : 6 * hs, eb1 = dz >= 0 ? (D.zones[dz].x + D.zones[dz].w) * W - 6 * hs : W - 6 * hs;
  let hx = W * 0.12, tx = hx, hold = 0, clock = 0, face = 1, zone = -1, flash = 0, hits = 0, hitT = 0, ex = (eb0 + eb1) / 2, edir = 1;
  function zoneAt(x) { for (let i = 0; i < D.zones.length; i++) if (x >= D.zones[i].x * W && x < (D.zones[i].x + D.zones[i].w) * W) return i; return -1; }
  return {
    press(x, y) { tx = clamp(x, 8, W - 8); hold = D.hold; },
    frame(dt, t) {
      stage({ night: 0.75 });
      hold = Math.max(0, hold - dt);
      if (hold <= 0) tx = W * (0.5 + 0.44 * Math.sin(t * 0.2));
      const dx = tx - hx, moving = Math.abs(dx) > 1;
      if (moving) { const sp = Math.min(Math.abs(dx), W * D.speed * dt); hx += Math.sign(dx) * sp; face = dx < 0 ? -1 : 1; clock += dt; }
      const zi = zoneAt(hx);
      if (zi !== zone) { zone = zi; if (zi >= 0 && D.zones[zi].kind === "danger") flash = D.entryFlash; }
      flash = Math.max(0, flash - dt);
      ex += edir * W * 0.12 * dt;                      // the enemy's patrol
      if (ex > eb1) { ex = eb1; edir = -1; } else if (ex < eb0) { ex = eb0; edir = 1; }
      hitT = Math.max(0, hitT - dt);
      if (zi === dz && dz >= 0 && Math.abs(hx - ex) < 6 * hs && hitT <= 0) { hits++; hitT = 0.8; tx = clamp(hx - face * W * 0.25, 8, W - 8); hold = 1.5; }
      ctx.globalCompositeOperation = "lighter";
      for (let i = 0; i < D.zones.length; i++) {       // the columns of light
        const z = D.zones[i], col = D.colours[z.kind] || INK, danger = z.kind === "danger";
        const zx = z.x * W, zw = z.w * W;
        let a = 0.12 + 0.05 * Math.sin(t * TAU * D.pulse * (danger ? 1 : 0.5));
        if (danger && i === zi && D.entryFlash > 0) a += 0.35 * flash / D.entryFlash;
        if (D.soft > 0) {
          const g = ctx.createLinearGradient(zx, 0, zx + zw, 0);
          g.addColorStop(0, rgba(col, 0)); g.addColorStop(D.soft / 2, rgba(col, a)); g.addColorStop(1 - D.soft / 2, rgba(col, a)); g.addColorStop(1, rgba(col, 0));
          ctx.fillStyle = g;
        } else ctx.fillStyle = rgba(col, a);
        ctx.fillRect(zx, H * 0.22, zw, H - H * 0.22);
        glow(zx + zw / 2, H * 0.2, zw * 0.5, col, 0.4); dot(zx + zw / 2, H * 0.2, 2 * S, col);   // the lamp that makes it
        text(z.kind, zx + zw / 2, H * 0.34, 10 * S, rgba(col, 0.9), "center", true);
      }
      ctx.globalCompositeOperation = "source-over";
      hero(ex, GY, { face: edir, shirt: "#5A2A3A", tint: rgba(HOT, 0.45), pose: "run", frame: clock });
      const zc = zi >= 0 ? D.colours[D.zones[zi].kind] : null;
      hero(hx, GY, { face: face, pose: hitT > 0.5 ? "hurt" : (moving ? "run" : "stand"), frame: clock, tint: hitT > 0.5 ? rgba(HOT, 0.8) : (zc ? rgba(zc, 0.4) : undefined) });
      label(zi >= 0 ? "zone: " + D.zones[zi].kind : "zone: none", hx, GY - 20 * hs, zc || DIM, "center");
      label("hits ×" + hits, W - 6, 12, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Zonelight", "Zonewarn", "the danger zone flares for half a second when the hero steps in, and every edge is feathered — the level that warns you", { entryFlash: 0.6, soft: 0.5 });
/* ============================== WEAPONS, IMPACTS & DECALS ==============================
   Everything here begins with one EVENT — fire(), break(), light() — and the
   rest is what the event leaves behind. A muzzle flash is a two-frame sprite,
   a one-frame light and a recoil, all spawned by one call; a tracer is a line
   that lives three frames; an impact is a LOOKUP — the material the ray hit
   picks sparks, dust, chips or a ring; a decal is a stamp in a RING BUFFER that
   forgets the oldest; footprints are stamped by distance, not time; splats obey
   the hit normal, then gravity; debris bounces exactly once; barrels chain by
   radius and delay; fuses, grenades, telegraphs and tells are TIMERS YOU CAN
   SEE — the danger drawn before the hit, so the hit reads as fair. */

def("M", "Muzzle", "impact", "one fire() spawns a 2-frame flash, a 1-frame light, smoke and recoil — the shot as a timeline (ch06 sparks) — press to fire toward your click", function (u) {
  var D = { every: 1.2,         // autopilot: seconds between shots
            frameLen: 0.033,    // one "frame" of the flash sprite, in seconds
            flashFrames: 2,     // the flash sprite lives this many frames
            size: 1,            // flash size multiplier
            light: 0.28,        // the one-frame light: alpha of the whole-screen wash
            recoil: 0.4,        // barrel kick, as a fraction of its length
            spring: 22,         // how fast the barrel returns, per second
            smoke: 14,          // puffs per shot
            smokeLife: 1.0,     // seconds a puff lives
            label: "fire() → flash sprite · 1-frame light · recoil · smoke" };
  const { ctx, W, H, GY, TAU, stage, hero, crate, tree, glow, dot, ring, line, rect, label, text, rand, clamp, smooth, noiseBurst, SUN, SPARK, FIRE, DIM, BONE } = u;
  // a MUZZLE FLASH is not one thing: fire() is an EVENT that spawns four
  // short-lived things at once — a flash SPRITE that lives two frames (big,
  // then small), a LIGHT that lives one frame and paints the ground, a smoke
  // puff that lives a second, and a RECOIL that kicks the barrel back and
  // springs it home. chapter 06's sparks were the smoke; the strip at the top
  // is the timeline of one shot, so you can see how short "short" is.
  const s = Math.max(2, Math.round(H / 60)), hx = W * 0.26, L = 8 * s;
  let timer = D.every * 0.6, shotT = 9, kick = 0, aim = -0.2, rot = 0, armed = false;
  let tx = W * 0.8, ty = GY - H * 0.15;
  const pool = [];
  for (let i = 0; i < 60; i++) pool.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, life: 0, r: 1 });
  let pi = 0;
  function muzzle() { const px = hx + 4 * s, py = GY - 9 * s; return [px + Math.cos(aim) * (L - kick), py + Math.sin(aim) * (L - kick), px, py]; }
  function fire() {
    shotT = 0; rot = rand(0, TAU); kick = L * D.recoil;
    const m = muzzle();
    for (let i = 0; i < D.smoke; i++) {
      const p = pool[pi]; pi = (pi + 1) % pool.length;
      const a = aim + rand(-0.5, 0.5), v = rand(0.04, 0.22) * W;
      p.on = true; p.x = m[0]; p.y = m[1]; p.vx = Math.cos(a) * v; p.vy = Math.sin(a) * v - H * 0.04; p.life = 1; p.r = rand(0.6, 1.4) * s;
    }
    if (armed) noiseBurst({ dur: 0.12, vol: 0.14, lowpass: 2200, sweepTo: 300 });
  }
  return {
    press(x, y) {
      const m = muzzle();
      aim = Math.atan2(y - m[3], x - m[2]); tx = x; ty = y; armed = true; fire(); timer = 0;
    },
    frame(dt, t) {
      timer += dt; shotT += dt;
      if (timer > D.every) {                           // autopilot: a new target, a shot
        timer = 0; tx = rand(W * 0.55, W * 0.95); ty = rand(H * 0.2, GY);
        const m = muzzle(); aim = Math.atan2(ty - m[3], tx - m[2]); fire();
      }
      kick -= kick * smooth(D.spring, dt);
      stage({ night: 0.6 });
      tree(W * 0.9, GY, H * 0.28); crate(W * 0.7, GY, s * 5);
      const m = muzzle();
      const fi = Math.floor(shotT / D.frameLen);       // which frame of the shot we are on
      if (fi < 1) {                                    // the ONE-FRAME light: it paints the ground and the air
        ctx.globalCompositeOperation = "lighter";
        ctx.save(); ctx.translate(m[0], GY); ctx.scale(1, 0.35); glow(0, 0, W * 0.3 * D.size, SUN, 0.7); ctx.restore();
        glow(m[0], m[1], W * 0.35 * D.size, SUN, 0.5);
        rect(0, 0, W, H, "rgba(255,230,170," + D.light + ")");
        ctx.globalCompositeOperation = "source-over";
      }
      hero(hx - kick * 0.2, GY, { face: 1, pose: "stand", frame: t });
      ctx.save(); ctx.translate(m[2], m[3]); ctx.rotate(aim); ctx.translate(-kick, 0);   // the barrel, kicked back by RECOIL
      ctx.fillStyle = "#2B2440"; ctx.fillRect(0, -1.1 * s, L, 2.1 * s); ctx.fillRect(1.5 * s, 0, 2 * s, 3 * s);
      ctx.restore();
      if (fi < D.flashFrames) {                        // the flash SPRITE: frame 0 big, later frames smaller
        const r = s * 4.5 * D.size * (fi === 0 ? 1 : 0.55), a = fi === 0 ? 1 : 0.8;
        ctx.globalCompositeOperation = "lighter";
        ctx.fillStyle = "rgba(255,238,180," + a + ")";
        ctx.save(); ctx.translate(m[0], m[1]); ctx.rotate(aim + rot * 0.1);
        ctx.beginPath();
        for (let i = 0; i < 10; i++) { const rr = i % 2 ? r * 0.35 : (i === 0 ? r * 1.6 : r); const th = i / 10 * TAU; ctx.lineTo(Math.cos(th) * rr, Math.sin(th) * rr); }
        ctx.closePath(); ctx.fill();
        ctx.restore();
        dot(m[0], m[1], r * 0.3, "#FFFFFF");
        ctx.globalCompositeOperation = "source-over";
      }
      for (const p of pool) {                          // the SMOKE: the longest-lived part of the shot
        if (!p.on) continue;
        p.life -= dt / D.smokeLife; if (p.life <= 0) { p.on = false; continue; }
        p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= Math.max(0, 1 - 2 * dt); p.vy -= H * 0.03 * dt; p.r += s * 1.2 * dt;
        dot(p.x, p.y, p.r, "rgba(190,186,210," + p.life * 0.3 + ")");
      }
      ring(tx, ty, s * 1.2, shotT < 0.12 ? SPARK : DIM, 1);
      if (shotT < 0.12) dot(tx, ty, s * 0.8 * (1 - shotT * 6), SPARK);
      const x0 = W * 0.09, x1 = W * 0.92, span = Math.max(D.smokeLife, D.frameLen * D.flashFrames * 4, 0.5), y0 = 10;   // the TIMELINE of one shot
      const rows = [["flash", D.frameLen * D.flashFrames, SPARK], ["light", D.frameLen, SUN], ["recoil", 3 / D.spring, BONE], ["smoke", D.smokeLife, "#9A96B0"]];
      for (let i = 0; i < rows.length; i++) {
        const y = y0 + i * 8;
        text(rows[i][0], x0 - 3, y + 4, 7, DIM, "right");
        rect(x0, y, x1 - x0, 4, "rgba(232,229,244,0.08)");
        rect(x0, y, Math.max(1.5, (x1 - x0) * clamp(rows[i][1] / span, 0, 1)), 4, rows[i][2]);
      }
      const ph = x0 + (x1 - x0) * clamp(shotT / span, 0, 1);
      line(ph, y0 - 3, ph, y0 + rows.length * 8, "rgba(245,138,138,0.9)", 1);
      text(shotT < span ? (shotT * 1000).toFixed(0) + " ms" : "…", ph + 3, y0 + rows.length * 8 + 1, 7, "rgba(245,138,138,0.9)");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Muzzle", "Musket", "one big slow flash — four frames at twice the length — and a cloud of smoke that hangs: black powder", { size: 1.9, frameLen: 0.06, smoke: 40 });
warnOf("Muzzle", "contains flashing light");

def("E", "Eject", "impact", "casings are tiny bodies: thrown sideways, they bounce with restitution and spin, then rest — lexicon Bounce with a tink — press to fire", function (u) {
  var D = { every: 0.45,        // autopilot: seconds between shots
            rest: 0.45,         // restitution: how much of the fall speed survives a bounce
            friction: 0.6,      // what a bounce keeps of the sideways speed and the spin
            g: 2.0,             // gravity, in H per second²
            eject: 0.22,        // ejection speed sideways, in W per second
            spin: 30,           // max spin, radians per second
            settle: 2.5,        // seconds a resting casing stays before it fades
            label: "on ground: vy ← −e·vy · vx ← μ·vx · ω ← μ·ω" };
  const { ctx, W, H, GY, TAU, stage, hero, ground, dot, line, rect, arrow, label, text, rand, tone, SUN, SPARK, DIM, BONE } = u;
  // every SHELL CASING is a small rigid body with three numbers: a velocity,
  // a spin, and a RESTITUTION e. the ground flips the vertical speed and
  // multiplies it by e (lexicon Bounce), friction μ eats the sideways speed
  // and the spin, and once the bounce is smaller than a pixel the casing
  // lies flat and waits to fade. the first bounce is the tink. the pool is
  // 40 casings, reused oldest-first — a belt of them costs nothing.
  const s = Math.max(2, Math.round(H / 60)), hx = W * 0.3, L = 8 * s, G = H * D.g;
  const pool = [];
  for (let i = 0; i < 40; i++) pool.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, rot: 0, vr: 0, bounces: 0, restT: 0, age: 0 });
  let pi = 0, timer = 0, kick = 0, flash = 0, armed = false, tinkGap = 0, fired = 0, last = null;
  function fire() {
    const p = pool[pi]; pi = (pi + 1) % pool.length;
    p.on = true; p.x = hx + 5 * s; p.y = GY - 10 * s; p.vx = -W * D.eject * rand(0.6, 1.1); p.vy = -H * rand(0.6, 0.95);
    p.rot = 0; p.vr = rand(-D.spin, D.spin); p.bounces = 0; p.restT = 0; p.age = 0;
    kick = L * 0.3; flash = 0.04; fired++; last = p;
  }
  return {
    press() { armed = true; fire(); timer = 0; },
    frame(dt, t) {
      timer += dt; tinkGap += dt;
      if (timer > D.every) { timer = 0; fire(); }
      kick *= Math.max(0, 1 - 18 * dt); flash -= dt;
      stage({ night: 0.35 }); ground();
      hero(hx - kick * 0.2, GY, { face: 1, pose: "stand", frame: t });
      ctx.fillStyle = "#2B2440"; ctx.fillRect(hx + 4 * s - kick, GY - 10 * s, L, 2 * s); ctx.fillRect(hx + 5.5 * s - kick, GY - 8 * s, 2 * s, 3 * s);
      if (flash > 0) { ctx.globalCompositeOperation = "lighter"; dot(hx + 4 * s + L, GY - 9 * s, s * 2.2, SPARK); ctx.globalCompositeOperation = "source-over"; }
      let alive = 0;
      for (const p of pool) {
        if (!p.on) continue;
        alive++; p.age += dt;
        if (p.restT > 0) {                             // at rest: wait, then fade
          p.restT += dt;
          if (p.restT > D.settle + 0.6) { p.on = false; continue; }
        } else {
          p.vy += G * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
          if (p.y >= GY) {
            p.y = GY;
            if (p.vy > H * 0.12) {                     // a real bounce: flip, scale by e, eat some μ
              p.vy = -p.vy * D.rest; p.vx *= D.friction; p.vr *= D.friction; p.bounces++;
              if (p.bounces === 1 && armed && tinkGap > 0.12) { tinkGap = 0; tone({ freq: rand(2300, 3100), slideTo: 1900, type: "triangle", dur: 0.07, vol: 0.08, pan: (p.x / W - 0.5) * 1.6 }); }
            } else { p.vy = 0; p.vx = 0; p.vr = 0; p.restT = 0.001; p.rot = Math.round(p.rot / Math.PI) * Math.PI; }
          }
          if (p.x < s || p.x > W - s) { p.vx = -p.vx * D.rest; p.x = Math.max(s, Math.min(W - s, p.x)); }
        }
        const a = p.restT > D.settle ? Math.max(0, 1 - (p.restT - D.settle) / 0.6) : 1;
        ctx.save(); ctx.translate(p.x, p.y - s * 0.35); ctx.rotate(p.rot); ctx.globalAlpha = a;
        ctx.fillStyle = "#D8A84A"; ctx.fillRect(-s * 0.9, -s * 0.35, s * 1.8, s * 0.7);
        ctx.fillStyle = "#8A6420"; ctx.fillRect(-s * 0.9, -s * 0.35, s * 0.4, s * 0.7);
        ctx.restore();
        if (p.bounces === 0 && p === last && p.age < 0.3) arrow(p.x, p.y - s, p.x + p.vx * 0.12, p.y - s + p.vy * 0.12, SUN);
      }
      if (last && last.on && last.bounces > 0 && last.age < 1.2) text("bounce " + last.bounces + "  ×e", last.x, last.y - s * 2.5, 8, "rgba(245,193,105,0.9)", "center");
      text("e = " + D.rest + "   μ = " + D.friction + "   pool " + alive + "/" + pool.length + "   fired " + fired, W * 0.5, 14, 8, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Eject", "Empties", "a belt-fed stream — a shot every tenth of a second — and casings that never fade, so the pool of forty piles up and steals its oldest", { every: 0.09, settle: 40, rest: 0.3 });

def("T", "Tracer", "impact", "instant hits made visible: a line from the muzzle to the ray's hit point that lives 3 frames (lexicon Xmarks) — press to fire at your click", function (u) {
  var D = { every: 0.6,         // autopilot: seconds between shots
            frames: 3,          // a plain tracer lives this many FRAMES, not seconds
            glowEvery: 0,       // every n-th shot glows and lingers (0 = never)
            linger: 0.8,        // seconds a glowing tracer takes to fade
            spread: 0.04,       // aim error, radians
            label: "hit = nearest t over segments · plain tracer: alpha = frames left / 3" };
  const { ctx, W, H, GY, TAU, stage, hero, crate, wall, ground, dot, ring, line, rect, arrow, glow, label, text, rand, len, SUN, SPARK, HOT, DIM, BONE } = u;
  // a hitscan shot arrives the same frame it leaves, so there is nothing to
  // see. the TRACER is the fix: cast one RAY against every terrain segment
  // (lexicon Xmarks), keep the nearest hit, and draw a line from muzzle to
  // hit point for three frames — counted in frames, because that is what the
  // eye reads. the dim rings are the other candidates the ray crossed; the
  // bright one is the minimum t. every n-th shot can glow and linger instead.
  const s = Math.max(2, Math.round(H / 60)), hx = W * 0.14, L = 8 * s;
  const cx = W * 0.6, cs = s * 6, wx = W * 0.86, ww = s * 4, wh = H * 0.42;
  const segs = [[0, GY, W, GY], [cx - cs / 2, GY - cs, cx + cs / 2, GY - cs], [cx - cs / 2, GY - cs, cx - cs / 2, GY],
                [wx, GY - wh, wx + ww, GY - wh], [wx, GY - wh, wx, GY], [0, 0, W, 0], [W, 0, W, H], [0, 0, 0, H]];
  const tracers = [], sparks = [];
  for (let i = 0; i < 24; i++) sparks.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, life: 0 });
  let si = 0, timer = 0, aim = -0.1, kick = 0, shots = 0, cand = [], candT = 9, tx = W * 0.7, ty = GY - H * 0.2;
  function muzzle() { const px = hx + 4 * s, py = GY - 9 * s; return [px + Math.cos(aim) * (L - kick), py + Math.sin(aim) * (L - kick), px, py]; }
  function hitSeg(px, py, dx, dy, g) {
    const x3 = g[0], y3 = g[1], x4 = g[2], y4 = g[3], den = dx * (y4 - y3) - dy * (x4 - x3);
    if (Math.abs(den) < 1e-9) return Infinity;
    const t = ((x3 - px) * (y4 - y3) - (y3 - py) * (x4 - x3)) / den, w = ((x3 - px) * dy - (y3 - py) * dx) / den;
    return (t > 0 && w >= 0 && w <= 1) ? t : Infinity;
  }
  function fire() {
    const m = muzzle(), a = aim + rand(-D.spread, D.spread), dx = Math.cos(a), dy = Math.sin(a);
    let best = Infinity, bi = -1; cand = [];
    for (let i = 0; i < segs.length; i++) { const t = hitSeg(m[0], m[1], dx, dy, segs[i]); if (isFinite(t)) { cand.push([m[0] + dx * t, m[1] + dy * t]); if (t < best) { best = t; bi = i; } } }
    if (!isFinite(best)) best = W;
    const g = segs[bi < 0 ? 0 : bi]; let nx = g[3] - g[1], ny = -(g[2] - g[0]); const nl = len(nx, ny) || 1; nx /= nl; ny /= nl;
    if (nx * dx + ny * dy > 0) { nx = -nx; ny = -ny; }
    shots++;
    const glowing = D.glowEvery > 0 && shots % D.glowEvery === 0;
    tracers.push({ x1: m[0], y1: m[1], x2: m[0] + dx * best, y2: m[1] + dy * best, left: D.frames, age: 0, glow: glowing, nx: nx, ny: ny });
    if (tracers.length > 8) tracers.shift();
    for (let i = 0; i < 6; i++) { const p = sparks[si]; si = (si + 1) % sparks.length; const v = rand(0.1, 0.3) * W, ang = Math.atan2(ny, nx) + rand(-0.9, 0.9); p.on = true; p.x = m[0] + dx * best; p.y = m[1] + dy * best; p.vx = Math.cos(ang) * v; p.vy = Math.sin(ang) * v; p.life = 1; }
    kick = L * 0.25; candT = 0;
  }
  return {
    press(x, y) { const m = muzzle(); aim = Math.atan2(y - m[3], x - m[2]); tx = x; ty = y; fire(); timer = 0; },
    frame(dt, t) {
      timer += dt; candT += dt; kick *= Math.max(0, 1 - 16 * dt);
      if (timer > D.every) { timer = 0; tx = rand(W * 0.4, W * 0.98); ty = rand(H * 0.15, GY); const m = muzzle(); aim = Math.atan2(ty - m[3], tx - m[2]); fire(); }
      stage({ night: 0.5 }); ground();
      crate(cx, GY, cs); wall(wx, GY - wh, ww, wh);
      const m = muzzle();
      hero(hx - kick * 0.2, GY, { face: 1, pose: "stand", frame: t });
      ctx.save(); ctx.translate(m[2], m[3]); ctx.rotate(aim); ctx.translate(-kick, 0);
      ctx.fillStyle = "#2B2440"; ctx.fillRect(0, -1.1 * s, L, 2.1 * s); ctx.fillRect(1.5 * s, 0, 2 * s, 3 * s); ctx.restore();
      ring(tx, ty, s, DIM, 1);
      if (candT < 0.5) for (const c of cand) ring(c[0], c[1], s * 1.1, "rgba(232,229,244," + (0.5 - candT) + ")", 1);   // every segment the ray crossed
      ctx.globalCompositeOperation = "lighter";
      for (let i = tracers.length - 1; i >= 0; i--) {
        const tr = tracers[i];
        let a;
        if (tr.glow) { tr.age += dt; a = 1 - tr.age / D.linger; } else { a = tr.left / D.frames; tr.left--; }
        if (a <= 0) { tracers.splice(i, 1); continue; }
        if (tr.glow) { line(tr.x1, tr.y1, tr.x2, tr.y2, "rgba(245,138,90," + a * 0.5 + ")", s * 1.4); glow(tr.x2, tr.y2, s * 4, SUN, a * 0.8); }
        line(tr.x1, tr.y1, tr.x2, tr.y2, "rgba(255,240,190," + a + ")", 1.5);
        line(tr.x1, tr.y1, tr.x2, tr.y2, "rgba(255,255,255," + a * 0.8 + ")", 0.6);
        if (i === tracers.length - 1) {
          ctx.globalCompositeOperation = "source-over";
          ring(tr.x2, tr.y2, s * 1.4, SPARK, 1.5); arrow(tr.x2, tr.y2, tr.x2 + tr.nx * s * 4, tr.y2 + tr.ny * s * 4, SUN);
          text(tr.glow ? "lingers " + Math.max(0, D.linger - tr.age).toFixed(2) + " s" : tr.left + " f left", (tr.x1 + tr.x2) / 2, (tr.y1 + tr.y2) / 2 - 6, 8, "rgba(255,240,190,0.95)", "center");
          ctx.globalCompositeOperation = "lighter";
        }
      }
      for (const p of sparks) { if (!p.on) continue; p.life -= dt * 4; if (p.life <= 0) { p.on = false; continue; } p.x += p.vx * dt; p.y += p.vy * dt; p.vy += H * 1.5 * dt; dot(p.x, p.y, 1, "rgba(255,233,168," + p.life + ")"); }
      ctx.globalCompositeOperation = "source-over";
      text("shots " + shots + (D.glowEvery > 0 ? " · every " + D.glowEvery + "rd glows" : "") + " · segments " + segs.length, W / 2, 14, 8, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Tracer", "Tracerfire", "every third round is a real tracer — it glows orange and lingers a second while the plain rounds still vanish in three frames", { glowEvery: 3, linger: 1.0, every: 0.35 });

def("I", "Impact", "impact", "the hit normal and a material lookup pick the effect — sparks, dust, chips or a ring (codex Hit spark) — press to shoot the panel under your click", function (u) {
  var D = { materials: [ { name: "metal", fx: "sparks", c: "#9AA3B5" },     // the LOOKUP TABLE: material → effect
                         { name: "stone", fx: "dust",   c: "#7B7686" },
                         { name: "wood",  fx: "chips",  c: "#8A6A3E" },
                         { name: "water", fx: "ring",   c: "#3E7FB0" } ],
            every: 1.1,         // autopilot: seconds between shots
            count: 14,          // particles per hit (scaled per effect)
            g: 1.8,             // gravity, in H per second²
            night: 0.2,
            label: "ray → hit point + normal n · table[material] → effect" };
  const { ctx, W, H, GY, TAU, stage, hero, dot, ring, line, rect, arrow, poly, label, text, rand, len, clamp, mix, shade, SPARK, SUN, DIM, BONE, INK } = u;
  // an IMPACT is two facts and a table. the ray gives a HIT POINT and the
  // surface's NORMAL n (perpendicular to the segment it struck); the surface
  // names a MATERIAL; a LOOKUP TABLE turns the material into an effect —
  // sparks that fly off n and fall (codex Hit spark), dust that drifts, chips
  // that tumble, a ring that spreads on water. same bullet, four answers.
  // the table is drawn top-right; the row that fired lights up.
  const s = Math.max(2, Math.round(H / 60)), ly = GY - H * 0.3, hx = W * 0.11, L = 8 * s, G = H * D.g;
  const x0 = W * 0.26, pw = (W - x0) / 4;
  const panels = [];
  for (let i = 0; i < 4; i++) {
    const a = x0 + i * pw, b = a + pw;
    const ya = i === 1 ? GY : (i === 3 ? GY + s * 0.8 : GY), yb = i === 1 ? GY - H * 0.07 : ya;   // stone is a ramp, water sits lower
    let nx = yb - ya, ny = -(b - a); const nl = len(nx, ny) || 1; nx /= nl; ny /= nl; if (ny > 0) { nx = -nx; ny = -ny; }
    panels.push({ a: a, b: b, ya: ya, yb: yb, nx: nx, ny: ny });
  }
  const pool = [];
  for (let i = 0; i < 120; i++) pool.push({ on: false, kind: "", x: 0, y: 0, vx: 0, vy: 0, life: 0, rot: 0, vr: 0, c: "", r: 1 });
  let pi = 0;
  const rings = [];
  let timer = 0.4, aim = 0.5, kick = 0, lastHit = null, hitT = 9, lastRow = -1, trace = 0, tr = [0, 0, 0, 0];
  function muzzle() { const px = hx + 4 * s, py = ly - 9 * s; return [px + Math.cos(aim) * (L - kick), py + Math.sin(aim) * (L - kick), px, py]; }
  function spawn(kind, x, y, nx, ny, mat) {
    const na = Math.atan2(ny, nx);
    const n = kind === "sparks" ? D.count : kind === "dust" ? Math.round(D.count * 0.7) : Math.round(D.count * 0.5);
    for (let i = 0; i < n; i++) {
      const p = pool[pi]; pi = (pi + 1) % pool.length;
      p.on = true; p.kind = kind; p.x = x; p.y = y; p.life = 1; p.rot = rand(0, TAU);
      if (kind === "sparks") { const a = na + rand(-1.1, 1.1), v = rand(0.25, 0.6) * W; p.vx = Math.cos(a) * v; p.vy = Math.sin(a) * v; p.c = SPARK; p.r = 1; }
      else if (kind === "dust") { const a = na + rand(-1.4, 1.4), v = rand(0.03, 0.09) * W; p.vx = Math.cos(a) * v; p.vy = Math.sin(a) * v; p.c = shade(mat.c, 0.35); p.r = rand(0.8, 1.6) * s; }
      else { const a = na + rand(-0.9, 0.9), v = rand(0.12, 0.35) * W; p.vx = Math.cos(a) * v; p.vy = Math.sin(a) * v; p.vr = rand(-14, 14); p.c = shade(mat.c, rand(-0.3, 0.3)); p.r = rand(0.5, 1.1) * s; }
    }
  }
  function shoot(px) {
    px = clamp(px, x0 + 2, W - 2);
    const idx = Math.min(3, Math.floor((px - x0) / pw)), P = panels[idx], mat = D.materials[idx] || D.materials[0];
    const k = (px - P.a) / (P.b - P.a), hy = P.ya + (P.yb - P.ya) * k;
    const m = muzzle(); aim = Math.atan2(hy - m[3], px - m[2]); kick = L * 0.25;
    const m2 = muzzle(); tr = [m2[0], m2[1], px, hy]; trace = 2;
    lastHit = { x: px, y: hy, nx: P.nx, ny: P.ny, fx: mat.fx }; hitT = 0; lastRow = idx;
    if (mat.fx === "ring") { rings.push({ x: px, y: hy, age: 0, c: mat.c }); if (rings.length > 6) rings.shift(); spawn("dust", px, hy, P.nx, P.ny, { c: mat.c }); }
    else spawn(mat.fx, px, hy, P.nx, P.ny, mat);
  }
  return {
    press(x, y) { shoot(x); timer = 0; },
    frame(dt, t) {
      timer += dt; hitT += dt; kick *= Math.max(0, 1 - 16 * dt);
      if (timer > D.every) { timer = 0; shoot(rand(x0, W)); }
      stage({ night: D.night });
      for (let i = 0; i < 4; i++) {                    // the four panels, each its own material
        const P = panels[i], mat = D.materials[i] || D.materials[0];
        poly([[P.a, P.ya], [P.b, P.yb], [P.b, H], [P.a, H]], mat.c);
        if (mat.fx === "chips") for (let x = P.a + s; x < P.b; x += s * 2.2) line(x, P.ya + 1, x, H, "rgba(0,0,0,0.18)", 1);
        if (mat.fx === "sparks") line(P.a + 2, P.ya + s * 0.6, P.b - 2, P.yb + s * 0.6, "rgba(255,255,255,0.25)", 1);
        if (mat.fx === "ring") { rect(P.a, P.ya - s, s * 0.6, H - P.ya + s, "#4A4470"); rect(P.b - s * 0.6, P.ya - s, s * 0.6, H - P.ya + s, "#4A4470"); }
        line(P.a, P.ya, P.b, P.yb, "rgba(255,255,255,0.35)", 1.5);
        text(mat.name, (P.a + P.b) / 2, Math.max(P.ya, P.yb) + 11, 8, "rgba(255,255,255,0.75)", "center");
      }
      rect(0, ly, W * 0.22, GY - ly, "#4A4470"); line(0, ly, W * 0.22, ly, BONE, 1);   // the ledge the shooter stands on
      const m = muzzle();
      hero(hx - kick * 0.2, ly, { face: 1, pose: "stand", frame: t });
      ctx.save(); ctx.translate(m[2], m[3]); ctx.rotate(aim); ctx.translate(-kick, 0);
      ctx.fillStyle = "#2B2440"; ctx.fillRect(0, -1.1 * s, L, 2.1 * s); ctx.fillRect(1.5 * s, 0, 2 * s, 3 * s); ctx.restore();
      if (trace > 0) { trace--; line(tr[0], tr[1], tr[2], tr[3], "rgba(255,240,190," + (0.4 + trace * 0.3) + ")", 1.2); }
      for (let i = rings.length - 1; i >= 0; i--) {   // water: a ring that spreads on the surface plane
        const r = rings[i]; r.age += dt; const k = r.age / 1.1; if (k >= 1) { rings.splice(i, 1); continue; }
        ctx.strokeStyle = "rgba(255,255,255," + (1 - k) * 0.8 + ")"; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.ellipse(r.x, r.y, Math.max(0.5, pw * 0.45 * k), Math.max(0.3, s * 0.9 * k), 0, 0, TAU); ctx.stroke();
      }
      for (const p of pool) {
        if (!p.on) continue;
        const rate = p.kind === "sparks" ? 2.4 : p.kind === "dust" ? 1.1 : 1.3;
        p.life -= dt * rate; if (p.life <= 0) { p.on = false; continue; }
        if (p.kind === "dust") { p.vx *= Math.max(0, 1 - 1.5 * dt); p.vy -= H * 0.02 * dt; p.r += s * 0.8 * dt; }
        else { p.vy += G * dt; }
        p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
        if (p.kind !== "dust" && p.y > GY + s) { p.y = GY + s; p.vy = 0; p.vx *= 0.5; p.vr = 0; }
        if (p.kind === "sparks") { ctx.globalCompositeOperation = "lighter"; line(p.x, p.y, p.x - p.vx * 0.02, p.y - p.vy * 0.02, "rgba(255,233,168," + p.life + ")", 1.2); ctx.globalCompositeOperation = "source-over"; }
        else if (p.kind === "dust") dot(p.x, p.y, p.r, p.c.replace(/[\d.]+\)$/, (p.life * 0.35) + ")"));
        else { ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.globalAlpha = Math.min(1, p.life * 2); ctx.fillStyle = p.c; ctx.fillRect(-p.r, -p.r * 0.5, p.r * 2, p.r); ctx.restore(); }
      }
      if (lastHit && hitT < 0.6) {                     // the normal, where it acts
        arrow(lastHit.x, lastHit.y, lastHit.x + lastHit.nx * s * 5, lastHit.y + lastHit.ny * s * 5, SUN);
        text("n", lastHit.x + lastHit.nx * s * 6, lastHit.y + lastHit.ny * s * 6 + 3, 9, SUN, "center");
      }
      const tx = W * 0.62, ty = 8, rw = W * 0.34, rh = 9;      // the lookup table, drawn
      rect(tx - 3, ty - 2, rw + 6, rh * 4 + 4, "rgba(19,16,32,0.55)");
      for (let i = 0; i < 4; i++) {
        const mat = D.materials[i] || D.materials[0], y = ty + i * rh, hot = i === lastRow && hitT < 0.5;
        if (hot) rect(tx - 3, y - 1, rw + 6, rh, "rgba(245,193,105,0.35)");
        rect(tx, y + 1, 6, 6, mat.c);
        text(mat.name + " → " + mat.fx, tx + 10, y + 7, 8, hot ? INK : BONE);
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Impact", "Icefield", "the same ray and the same table with cold rows: ice throws shards, frost and snow puff white, slush rings — a winter level's lookup", { materials: [ { name: "ice", fx: "chips", c: "#BFE6F7" }, { name: "frost", fx: "dust", c: "#DDE9F2" }, { name: "snow", fx: "dust", c: "#F1F5F9" }, { name: "slush", fx: "ring", c: "#8FB9D4" } ], night: 0.5 });

def("D", "Decals", "impact", "holes and scorch marks in a ring buffer of N — newest overwrites oldest, which fades first (codex Ground crack) — press to stamp at your click", function (u) {
  var D = { n: 12,              // the RING BUFFER holds this many decals
            fade: 3,            // once full, the oldest few slots dim in steps toward the exit
            every: 0.9,         // autopilot: seconds between stamps
            kind: "bullet",     // "bullet": holes and scorch marks · "chalk": chalk scribbles
            scorchEvery: 4,     // every n-th bullet stamp is a scorch mark
            size: 1,
            label: "slot = head mod N · head++ · alpha by age rank" };
  const { ctx, W, H, GY, TAU, stage, hero, wall, crate, layer, dot, ring, line, rect, arrow, label, text, rand, rng, clamp, smooth, SUN, HOT, DIM, BONE, INK } = u;
  // decals are cheap to draw and expensive to keep, so a game keeps N of
  // them in a RING BUFFER: stamp number k lives in slot k mod N, and when the
  // buffer is full the newest simply overwrites the oldest. here the doomed
  // slots dim by AGE RANK so you can watch the queue advance. the buffer is
  // one offscreen layer drawn UNDER the hero and the props — a decal is part
  // of the wall, not of the world (codex Ground crack was one such stamp).
  const s = Math.max(2, Math.round(H / 60)), hx = W * 0.14, L = 8 * s, wx = W * 0.36, wy = H * 0.14;
  const N = Math.max(1, Math.round(D.n));
  const slots = [];
  for (let i = 0; i < N; i++) slots.push({ on: false, x: 0, y: 0, kind: "hole", seed: 0, a: 0, seq: 0 });
  let head = 0, stamped = 0, timer = 0.3, aim = -0.1, kick = 0, trace = 0, tr = [0, 0, 0, 0], dirty = true;
  const Lr = layer("decals");
  function muzzle() { const px = hx + 4 * s, py = GY - 9 * s; return [px + Math.cos(aim) * (L - kick), py + Math.sin(aim) * (L - kick), px, py]; }
  function stamp(x, y) {
    const sl = slots[head % N];
    stamped++; head++;
    sl.on = true; sl.x = x; sl.y = y; sl.seq = stamped; sl.seed = stamped * 31 + 7; sl.a = 0;
    sl.kind = D.kind === "chalk" ? (stamped % 2 ? "circle" : "cross") : (stamped % D.scorchEvery === 0 ? "scorch" : "hole");
    const m = muzzle(); aim = Math.atan2(y - m[3], x - m[2]); kick = L * 0.25;
    const m2 = muzzle(); tr = [m2[0], m2[1], x, y]; trace = 2; dirty = true;
  }
  function draw(c, sl) {
    const R = rng(sl.seed), r = s * 0.9 * D.size;
    c.save(); c.translate(sl.x, sl.y); c.globalAlpha = sl.a;
    if (sl.kind === "hole") {
      c.fillStyle = "rgba(255,255,255,0.18)"; c.beginPath(); c.arc(0, 0, r * 1.7, 0, TAU); c.fill();
      c.fillStyle = "#16121E"; c.beginPath(); c.arc(0, 0, r, 0, TAU); c.fill();
      c.strokeStyle = "rgba(20,16,30,0.7)"; c.lineWidth = 1;
      for (let i = 0; i < 3; i++) { const a = R() * TAU, l = r * (1.5 + R() * 2); c.beginPath(); c.moveTo(Math.cos(a) * r, Math.sin(a) * r); c.lineTo(Math.cos(a) * l, Math.sin(a) * l); c.stroke(); }
    } else if (sl.kind === "scorch") {
      const g = c.createRadialGradient(0, 0, 0, 0, 0, r * 4); g.addColorStop(0, "rgba(10,8,14,0.9)"); g.addColorStop(0.5, "rgba(20,14,20,0.5)"); g.addColorStop(1, "rgba(20,14,20,0)");
      c.fillStyle = g; c.beginPath(); c.arc(0, 0, r * 4, 0, TAU); c.fill();
    } else {
      c.strokeStyle = "rgba(245,243,250,0.9)"; c.lineWidth = 1.6; c.lineCap = "round";
      if (sl.kind === "circle") { c.beginPath(); for (let i = 0; i <= 14; i++) { const a = i / 14 * TAU * 1.08, rr = r * 2.2 * (0.85 + R() * 0.3); c.lineTo(Math.cos(a) * rr, Math.sin(a) * rr); } c.stroke(); }
      else { const k = r * 2; c.beginPath(); c.moveTo(-k + R() * 2, -k); c.lineTo(k, k + R() * 2); c.moveTo(k, -k + R() * 2); c.lineTo(-k + R() * 2, k); c.stroke(); }
    }
    c.restore();
  }
  return {
    press(x, y) { stamp(clamp(x, wx, W - 2), clamp(y, wy, H - 2)); timer = 0; },
    frame(dt, t) {
      timer += dt; kick *= Math.max(0, 1 - 16 * dt);
      if (timer > D.every) { timer = 0; stamp(rand(wx + s, W - s), rand(wy + s, GY + (H - GY) * 0.7)); }
      const count = Math.min(stamped, N), oldest = stamped - count + 1;   // ranks: 0 = the oldest kept
      let moving = false;
      for (const sl of slots) {
        if (!sl.on) continue;
        const rank = sl.seq - oldest;
        const target = count < N ? 1 : clamp((rank + 1) / D.fade, 0, 1);
        const d = target - sl.a; sl.a += d * smooth(6, dt);
        if (Math.abs(d) > 0.004) moving = true;
      }
      if (dirty || moving) {                           // rebuild the buffer layer only when something changed
        Lr.ctx.clearRect(0, 0, W, H);
        for (const sl of slots) if (sl.on) draw(Lr.ctx, sl);
        dirty = false;
      }
      stage({ night: 0.35 });
      wall(wx, wy, W - wx, GY - wy);
      ctx.drawImage(Lr.cv, 0, 0, W, H);                // the decals: under everything that moves
      crate(W * 0.62, GY, s * 5);
      const m = muzzle();
      hero(hx - kick * 0.2, GY, { face: 1, pose: "stand", frame: t });
      ctx.save(); ctx.translate(m[2], m[3]); ctx.rotate(aim); ctx.translate(-kick, 0);
      ctx.fillStyle = "#2B2440"; ctx.fillRect(0, -1.1 * s, L, 2.1 * s); ctx.fillRect(1.5 * s, 0, 2 * s, 3 * s); ctx.restore();
      if (trace > 0) { trace--; line(tr[0], tr[1], tr[2], tr[3], "rgba(255,240,190," + (0.4 + trace * 0.3) + ")", 1.2); }
      const bx = W * 0.06, bw = W * 0.88 / N, by = 6, bh = 9;   // the ring buffer, drawn slot by slot
      for (let i = 0; i < N; i++) {
        const sl = slots[i], x = bx + i * bw;
        rect(x + 1, by, bw - 2, bh, sl.on ? "rgba(245,193,105," + (0.15 + sl.a * 0.75) + ")" : "rgba(232,229,244,0.08)");
        if (sl.on && sl.seq === oldest && count >= N) text("old", x + bw / 2, by + bh + 8, 7, HOT, "center");
      }
      const hxx = bx + (head % N) * bw + bw / 2;
      arrow(hxx, by + bh + 9, hxx, by + bh + 1, SUN);
      text("head", hxx + 3, by + bh + 12, 7, SUN);
      text("stamped " + stamped + " · kept " + count + "/" + N, W - 6, by + bh + 12, 8, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Decals", "Doodles", "chalk circles and crosses in a buffer of only five — the limit shows: the sixth scribble wipes the first", { kind: "chalk", n: 5, every: 0.6 });

def("M", "Marks", "impact", "footprints and tyre tracks stamped per stride of distance, not time, fading with age (codex Skid smoke) — press to send the hero", function (u) {
  var D = { stride: 0.055,      // W between footprints — a stamp per stride, never per frame
            tyre: 0.018,        // W between tyre-track dashes
            life: 6,            // seconds a mark takes to fade to nothing
            size: 1,            // print width multiplier
            palette: ["#E9EEF5", "#93A6BE"],   // the ground, and the mark pressed into it
            speed: 0.28,        // hero speed, W per second
            carSpeed: 0.2,      // car speed, W per second
            label: "stamp when Σ|dx| ≥ stride · alpha = 1 − age / life" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, dot, line, rect, ellipse, label, text, rand, clamp, rgba, shade, SUN, DIM, BONE, HOT } = u;
  // footprints stamped every frame become a smear; stamped every N seconds
  // they drift apart when the hero speeds up. the honest rule is DISTANCE: add
  // up |dx| and stamp a print each time the sum passes one stride (a tyre
  // track is the same rule with a shorter stride, twice — once per wheel).
  // every mark remembers its birth; alpha = 1 − age/life, and the graph at
  // the top-right plots each living mark on that line as it slides off.
  const s = Math.max(2, Math.round(H / 60)), roadY = GY + (H - GY) * 0.62;
  const prints = [], tyres = [];
  for (let i = 0; i < 80; i++) prints.push({ on: false, x: 0, y: 0, age: 0, side: 0 });
  for (let i = 0; i < 140; i++) tyres.push({ on: false, x: 0, y: 0, age: 0 });
  let pi = 0, ti = 0, hx = W * 0.3, tx = W * 0.75, acc = 0, steps = 0, face = 1, dist = 0;
  let carX = -W * 0.1, carAcc = 0;
  return {
    press(x) { tx = clamp(x, s * 3, W - s * 3); },
    frame(dt, t) {
      const dx = clamp(tx - hx, -1, 1) * W * D.speed * dt * (Math.abs(tx - hx) > s ? 1 : 0);
      hx += dx; acc += Math.abs(dx); dist += Math.abs(dx);
      if (Math.abs(dx) > 1e-6) face = dx > 0 ? 1 : -1;
      if (Math.abs(tx - hx) <= s && rand(0, 1) < dt * 0.8) tx = rand(s * 4, W - s * 4);   // autopilot: a new destination
      while (acc >= W * D.stride) {                    // the rule: one print per stride of DISTANCE
        acc -= W * D.stride; steps++;
        const p = prints[pi]; pi = (pi + 1) % prints.length;
        p.on = true; p.x = hx - face * s * 1.5; p.y = GY + (steps % 2 ? 1 : -1) * s * 0.7 + s * 0.5; p.age = 0; p.side = steps % 2;
      }
      const cdx = W * D.carSpeed * dt; carX += cdx; carAcc += cdx;
      if (carX > W * 1.15) carX = -W * 0.15;
      while (carAcc >= W * D.tyre) {
        carAcc -= W * D.tyre;
        for (let w = 0; w < 2; w++) { const q = tyres[ti]; ti = (ti + 1) % tyres.length; q.on = true; q.x = carX + (w ? -3.5 : 3.5) * s; q.y = roadY; q.age = 0; }
      }
      stage({ night: 0.15 });
      const gg = ctx.createLinearGradient(0, GY, 0, H); gg.addColorStop(0, D.palette[0]); gg.addColorStop(1, shade(D.palette[0], -0.25));
      ctx.fillStyle = gg; ctx.fillRect(0, GY, W, H - GY);
      tree(W * 0.08, GY, H * 0.22, "#5E8A6A"); tree(W * 0.92, GY, H * 0.26, "#5E8A6A");
      let live = 0;
      for (const p of prints) {
        if (!p.on) continue;
        p.age += dt; const a = 1 - p.age / D.life; if (a <= 0) { p.on = false; continue; }
        live++;
        ellipse(p.x, p.y, s * 1.3 * D.size, s * 0.6 * D.size, rgba(D.palette[1], a));
      }
      for (const q of tyres) {
        if (!q.on) continue;
        q.age += dt; const a = 1 - q.age / D.life; if (a <= 0) { q.on = false; continue; }
        rect(q.x - s * 0.9, q.y - s * 0.35 * D.size, s * 1.8, s * 0.7 * D.size, rgba(D.palette[1], a * 0.9));
      }
      hero(hx, GY, { face: face, pose: Math.abs(tx - hx) > s ? "run" : "stand", frame: dist / (s * 3) });
      ctx.fillStyle = HOT; ctx.fillRect(carX - 5 * s, roadY - 4.5 * s, 10 * s, 3 * s);   // the car
      ctx.fillRect(carX - 3 * s, roadY - 6.5 * s, 5 * s, 2.2 * s);
      dot(carX - 3.5 * s, roadY - s, s * 1.1, "#2B2440"); dot(carX + 3.5 * s, roadY - s, s * 1.1, "#2B2440");
      const gx = W - 72, gy = 8, gw = 62, gh = 24;     // the age fade, drawn: alpha against age
      rect(gx - 4, gy - 3, gw + 8, gh + 16, "rgba(19,16,32,0.55)");
      line(gx, gy, gx, gy + gh, DIM, 1); line(gx, gy + gh, gx + gw, gy + gh, DIM, 1);
      line(gx, gy, gx + gw, gy + gh, SUN, 1.2);
      for (const p of prints) if (p.on) dot(gx + gw * clamp(p.age / D.life, 0, 1), gy + gh * clamp(p.age / D.life, 0, 1), 1.5, BONE);
      text("a = 1 − age/" + D.life + " s", gx + gw / 2, gy + gh + 10, 7, DIM, "center");
      text("prints " + live + " · steps " + steps + " · stride " + Math.round(W * D.stride) + " px", 6, 14, 8, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Marks", "Mudtrack", "dark mud instead of snow — wide prints that take sixteen seconds to dry out, so the whole route stays written", { palette: ["#6E5137", "#2A1B0F"], life: 16, size: 1.6 });

def("I", "Ink", "impact", "a blob on the far side of the hit normal, drips that grow down — blood, ink or paint by one dial (grimoire Wet paint) — press to splat at your click", function (u) {
  var D = { colour: "#D8323C",  // the liquid
            paper: "#5E5880",   // the wall it lands on
            push: 0.03,         // W: how far past the hit point the blob's centre lands (along the shot)
            blobs: 8,           // circles per splat
            size: 1,
            drips: 3,           // drips per splat
            drip: 1.0,          // drip growth, in H per second
            dry: 14,            // seconds for the layer to wash back to clean
            every: 1.3,         // autopilot: seconds between splats
            label: "centre = hit − n · push · drip: y += rate·dt, width ↓" };
  const { ctx, W, H, GY, TAU, stage, hero, layer, dot, line, rect, arrow, label, text, rand, len, clamp, rgba, SUN, DIM, BONE } = u;
  // a SPLAT has two halves. the stamp: a cluster of circles whose centre
  // sits on the FAR SIDE of the hit normal — the liquid keeps the shot's
  // momentum past the point of contact, so the blob smears away from the
  // shooter. the drips: gravity takes over; a few threads grow downward
  // each frame, thinning as they go. both live on one persistent layer
  // (grimoire Wet paint), which dries by washing itself out a little a frame.
  const s = Math.max(2, Math.round(H / 60)), hx = W * 0.12, L = 8 * s, wy = H * 0.1;
  const Lr = layer("ink");
  const drips = [];
  for (let i = 0; i < 40; i++) drips.push({ on: false, x: 0, y: 0, w: 0, rate: 0, remain: 0 });
  let di = 0, timer = 0.5, aim = -0.1, kick = 0, last = null, hitT = 9, splats = 0;
  function muzzle() { const px = hx + 4 * s, py = GY - 9 * s; return [px + Math.cos(aim) * (L - kick), py + Math.sin(aim) * (L - kick), px, py]; }
  function splat(x, y) {
    x = clamp(x, s * 2, W - s * 2); y = clamp(y, wy + s, GY - s);
    const m = muzzle(); aim = Math.atan2(y - m[3], x - m[2]); kick = L * 0.25;
    let dx = x - m[2], dy = y - m[3]; const dl = len(dx, dy) || 1; dx /= dl; dy /= dl;
    const nx = -dx, ny = -dy;                          // the wall's normal faces the shooter
    const cx = x - nx * W * D.push, cy = y - ny * W * D.push, r = s * 1.6 * D.size;
    const c = Lr.ctx;
    c.fillStyle = D.colour;
    c.beginPath(); c.arc(x, y, r * 0.8, 0, TAU); c.fill();
    let lowX = cx, lowY = cy;
    for (let i = 0; i < D.blobs; i++) {                // circles clustered past the hit, stretched along the shot
      const k = rand(-0.4, 1.2), off = rand(-1, 1) * r * 0.9;
      const bx = cx + dx * k * r * 1.6 - dy * off, by = cy + dy * k * r * 1.6 + dx * off, br = r * rand(0.3, 1) * (1 - Math.abs(k) * 0.35);
      c.beginPath(); c.arc(bx, by, Math.max(0.5, br), 0, TAU); c.fill();
      if (by + br > lowY) { lowY = by + br; lowX = bx; }
    }
    for (let i = 0; i < D.drips; i++) {
      const d = drips[di]; di = (di + 1) % drips.length;
      d.on = true; d.x = i === 0 ? lowX : cx + rand(-1, 1) * r * 1.4; d.y = lowY - r * 0.3; d.w = r * rand(0.35, 0.6); d.rate = H * D.drip * rand(0.06, 0.14); d.remain = H * rand(0.05, 0.16) * D.drip;
    }
    last = { x: x, y: y, nx: nx, ny: ny, cx: cx, cy: cy }; hitT = 0; splats++;
  }
  return {
    press(x, y) { splat(x, y); timer = 0; },
    frame(dt, t) {
      timer += dt; hitT += dt; kick *= Math.max(0, 1 - 16 * dt);
      if (timer > D.every) { timer = 0; splat(rand(W * 0.35, W * 0.95), rand(wy + H * 0.08, GY - H * 0.08)); }
      const c = Lr.ctx;
      c.globalCompositeOperation = "destination-out"; c.fillStyle = "rgba(0,0,0," + clamp(dt / D.dry, 0, 1) + ")"; c.fillRect(0, 0, W, H);   // drying: the layer washes itself out
      c.globalCompositeOperation = "source-over";
      c.strokeStyle = D.colour; c.lineCap = "round";
      for (const d of drips) {                         // the drips grow INTO the layer, a segment a frame
        if (!d.on) continue;
        const dy = d.rate * dt;
        c.lineWidth = Math.max(0.5, d.w); c.beginPath(); c.moveTo(d.x, d.y); c.lineTo(d.x, d.y + dy); c.stroke();
        d.y += dy; d.remain -= dy; d.w *= Math.max(0, 1 - 0.6 * dt); d.rate *= Math.max(0, 1 - 0.25 * dt);
        if (d.remain <= 0 || d.w < 0.4 || d.y > GY - 1) d.on = false;
      }
      stage({ night: 0.3 });
      rect(0, wy, W, GY - wy, D.paper);                // the wall
      ctx.strokeStyle = "rgba(0,0,0,0.12)"; ctx.lineWidth = 1; ctx.beginPath();
      for (let y = wy + 14; y < GY; y += 14) { ctx.moveTo(0, y); ctx.lineTo(W, y); } ctx.stroke();
      ctx.drawImage(Lr.cv, 0, 0, W, H);
      for (const d of drips) if (d.on) dot(d.x, d.y, d.w * 0.75, D.colour);   // the bead at each drip's tip
      const m = muzzle();
      hero(hx - kick * 0.2, GY, { face: 1, pose: "stand", frame: t });
      ctx.save(); ctx.translate(m[2], m[3]); ctx.rotate(aim); ctx.translate(-kick, 0);
      ctx.fillStyle = "#2B2440"; ctx.fillRect(0, -1.1 * s, L, 2.1 * s); ctx.fillRect(1.5 * s, 0, 2 * s, 3 * s); ctx.restore();
      if (last && hitT < 0.7) {                        // the normal, and the far side of it
        const a = 1 - hitT / 0.7;
        arrow(last.x, last.y, last.x + last.nx * s * 5, last.y + last.ny * s * 5, rgba(SUN, a));
        text("n", last.x + last.nx * s * 6.5, last.y + last.ny * s * 6.5 + 3, 9, rgba(SUN, a), "center");
        ctx.setLineDash([2, 3]); line(last.x, last.y, last.cx, last.cy, rgba(BONE, a), 1); ctx.setLineDash([]);
        text("far side", last.cx, last.cy - s * 2.2 * D.size, 8, rgba(BONE, a), "center");
      }
      text("splats " + splats + " · colour " + D.colour + " · dries in " + D.dry + " s", W / 2, 14, 8, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Ink", "Inkwell", "black ink on cream paper with drips twice as eager — a calligrapher's accident", { colour: "#14121A", paper: "#EFE6D0", drip: 2.2 });

def("R", "Rubble", "impact", "a block breaks into 4–8 chunks with random spin and gravity that bounce once, then fade (folio Explosion) — press to break a block at your click", function (u) {
  var D = { pieces: [4, 8],     // how many chunks a block breaks into (min, max)
            g: 2.0,             // gravity, in H per second²
            spin: 9,            // max spin, radians per second
            rest: 0.4,          // restitution of the one bounce
            size: 1,            // block and chunk size multiplier
            colour: "#8A6A3E",  // the block's material
            hold: 0.8,          // seconds a settled chunk lies still before fading
            fade: 1.0,          // seconds the fade takes
            respawn: 3,         // seconds before a broken block is back
            every: 2.2,         // autopilot: seconds between breaks
            label: "v += g·dt · θ += ω·dt · bounce ×1 (e) → hold → fade" };
  const { ctx, W, H, GY, TAU, stage, hero, ground, dot, ring, line, rect, label, text, rand, clamp, shade, rgba, SUN, DIM, BONE } = u;
  // DEBRIS is the cheapest physics there is: a handful of quads with a
  // velocity, a spin, and gravity. the rule that sells it is ONE BOUNCE —
  // the first ground contact flips vy by e and halves the spin, the second
  // stops the chunk dead — then a short hold and a fade, so the ground never
  // fills up. the chunks are cut from the block's own rectangle, so their
  // colours and sizes agree with what broke (lexicon Knock did the push).
  const s = Math.max(2, Math.round(H / 60)), G = H * D.g, B = s * 5 * D.size;
  const blocks = [];
  for (let i = 0; i < 4; i++) blocks.push({ x: W * (0.24 + i * 0.2), gone: 0 });
  const pool = [];
  for (let i = 0; i < 48; i++) pool.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, rot: 0, vr: 0, r: 1, c: "", life: 1, bounced: 0, still: 0, pts: [0, 0, 0, 0, 0, 0, 0, 0] });
  const dust = [];
  for (let i = 0; i < 36; i++) dust.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, life: 0, r: 1 });
  const marks = [];
  let pi = 0, du = 0, timer = 1, broken = 0, lastN = 0;
  function shatter(x, y) {
    const n = Math.round(rand(D.pieces[0], D.pieces[1])); lastN = n; broken++;
    for (let i = 0; i < n; i++) {
      const p = pool[pi]; pi = (pi + 1) % pool.length;
      p.on = true; p.x = x + rand(-B * 0.4, B * 0.4); p.y = y - rand(B * 0.1, B * 0.9);
      p.vx = rand(-0.25, 0.25) * W; p.vy = -rand(0.3, 0.9) * H; p.rot = rand(0, TAU); p.vr = rand(-D.spin, D.spin);
      p.r = B * rand(0.16, 0.32); p.c = shade(D.colour, rand(-0.3, 0.25)); p.life = 1; p.bounced = 0; p.still = 0;
      for (let k = 0; k < 4; k++) { const a = k / 4 * TAU + rand(-0.4, 0.4), rr = p.r * rand(0.6, 1.1); p.pts[k * 2] = Math.cos(a) * rr; p.pts[k * 2 + 1] = Math.sin(a) * rr; }
    }
    for (let i = 0; i < Math.round(6 * D.size); i++) { const d = dust[du]; du = (du + 1) % dust.length; d.on = true; d.x = x + rand(-B * 0.5, B * 0.5); d.y = y - rand(0, B * 0.6); d.vx = rand(-0.06, 0.06) * W; d.vy = -rand(0.02, 0.08) * H; d.life = 1; d.r = s * rand(0.8, 1.6); }
  }
  return {
    press(x) {
      let best = null, bd = Infinity;
      for (const b of blocks) { const d = Math.abs(b.x - x); if (!b.gone && d < bd) { bd = d; best = b; } }
      if (best) { best.gone = D.respawn; shatter(best.x, GY); } else shatter(clamp(x, B, W - B), GY);
      timer = 0;
    },
    frame(dt, t) {
      timer += dt;
      if (timer > D.every) { timer = 0; const alive = blocks.filter(b => !b.gone); if (alive.length) { const b = alive[Math.floor(rand(0, alive.length)) % alive.length]; b.gone = D.respawn; shatter(b.x, GY); } }
      stage({ night: 0.3 }); ground();
      hero(W * 0.08, GY, { face: 1, pose: "stand", frame: t });
      for (const b of blocks) {                        // the blocks: a crate look in the material's colour
        if (b.gone > 0) { b.gone -= dt; if (b.gone > 0) continue; b.gone = 0; }
        ctx.fillStyle = D.colour; ctx.fillRect(b.x - B / 2, GY - B, B, B);
        ctx.strokeStyle = shade(D.colour, -0.4); ctx.lineWidth = Math.max(1, B * 0.08);
        ctx.strokeRect(b.x - B / 2 + 1, GY - B + 1, B - 2, B - 2);
        ctx.beginPath(); ctx.moveTo(b.x - B / 2, GY - B); ctx.lineTo(b.x + B / 2, GY); ctx.moveTo(b.x + B / 2, GY - B); ctx.lineTo(b.x - B / 2, GY); ctx.stroke();
      }
      for (const d of dust) { if (!d.on) continue; d.life -= dt * 0.9; if (d.life <= 0) { d.on = false; continue; } d.x += d.vx * dt; d.y += d.vy * dt; d.r += s * 0.9 * dt; dot(d.x, d.y, d.r, "rgba(200,190,180," + d.life * 0.3 + ")"); }
      let flying = 0, bounced = 0, fading = 0;
      for (const p of pool) {
        if (!p.on) continue;
        if (p.bounced < 2) {
          p.vy += G * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
          if (p.y >= GY - p.r * 0.5) {
            p.y = GY - p.r * 0.5;
            if (p.bounced === 0 && p.vy > H * 0.1) { p.vy = -p.vy * D.rest; p.vx *= 0.6; p.vr *= 0.5; p.bounced = 1; marks.push({ x: p.x, age: 0 }); if (marks.length > 12) marks.shift(); }
            else { p.bounced = 2; p.vy = 0; p.vx = 0; p.vr = 0; }
          }
          if (p.x < p.r || p.x > W - p.r) { p.vx = -p.vx * D.rest; p.x = clamp(p.x, p.r, W - p.r); }
          if (p.bounced === 1) bounced++; else flying++;
        } else {
          p.still += dt;
          if (p.still > D.hold) { p.life -= dt / D.fade; fading++; if (p.life <= 0) { p.on = false; continue; } }
        }
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.globalAlpha = Math.max(0, p.life);
        ctx.fillStyle = p.c; ctx.beginPath(); ctx.moveTo(p.pts[0], p.pts[1]); for (let k = 1; k < 4; k++) ctx.lineTo(p.pts[k * 2], p.pts[k * 2 + 1]); ctx.closePath(); ctx.fill();
        ctx.restore();
      }
      for (let i = marks.length - 1; i >= 0; i--) { const mk = marks[i]; mk.age += dt; if (mk.age > 0.4) { marks.splice(i, 1); continue; } ring(mk.x, GY, s * 2 * mk.age / 0.4 + 1, rgba(SUN, 1 - mk.age / 0.4), 1); }
      text("last break: " + lastN + " chunks · flying " + flying + " · bounced " + bounced + " · fading " + fading, W / 2, 14, 8, DIM, "center");
      text("e = " + D.rest + " · ω ≤ " + D.spin + " rad/s · g = " + D.g + " H/s²", W / 2, 25, 8, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Rubble", "Rockfall", "grey stone blocks nearly twice the size, chunks that do not spin, and more dust — a quarry, not a crate", { spin: 0, size: 1.7, colour: "#7E7A86" });

def("K", "Kaboom", "impact", "a blast radius lights every barrel inside it after a delay — a queue of timed detonations, dominoes too (lexicon Knock) — press to light a barrel", function (u) {
  var D = { barrels: 7,         // barrels in the field
            radius: 0.15,       // blast radius, in W
            delay: 0.35,        // seconds a barrel inside a blast waits before it goes
            fuse: 0.7,          // seconds a hand-lit barrel takes
            respawn: 4,         // seconds after the last blast before the field resets
            dominoes: 8,
            tip: 0.12,          // seconds between one domino's fall and the next
            every: 3.5,         // autopilot: seconds between lightings
            night: 0.4,
            label: "d(b, blast) < R → queue(now + delay) · domino i+1 at t_i + tip" };
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, line, rect, glow, label, text, rand, rng, len, clamp, ease, rgba, FIRE, SPARK, SUN, HOT, DIM, BONE } = u;
  // a CHAIN REACTION is a queue. a blast at (x, y) with radius R asks every
  // barrel "are you inside?" and the ones that are get an entry — barrel,
  // time = now + delay — in a list sorted by time. dominoes are the same
  // list with a fixed tip interval instead of a radius test: a QUEUE OF TIMED
  // FALLS (lexicon Knock and Newton did the shove; this is the scheduling).
  // the queue is drawn at the top, so you can read the doom before it lands.
  const s = Math.max(2, Math.round(H / 60)), bw = s * 3, bh = s * 4.5, R = W * D.radius;
  const seed = rng(3), NB = Math.max(1, Math.round(D.barrels)), ND = Math.max(1, Math.round(D.dominoes));
  const barrels = [], dominoes = [];
  for (let i = 0; i < NB; i++) barrels.push({ x: W * (0.05 + 0.58 * (i + 0.5) / NB) + (seed() - 0.5) * W * 0.03, alive: true, fuse: -1 });
  const dx0 = W * 0.7, dw = (W * 0.95 - dx0) / ND, dh = s * 5;
  for (let i = 0; i < ND; i++) dominoes.push({ x: dx0 + i * dw, k: 0, going: false });
  const queue = [], blasts = [], smoke = [];
  for (let i = 0; i < 40; i++) smoke.push({ on: false, x: 0, y: 0, vy: 0, life: 0, r: 1 });
  let si = 0, timer = 1.5, quiet = 0, fadeIn = 1;
  function enqueue(kind, i, wait) {
    for (const q of queue) if (q.kind === kind && q.i === i) return;
    queue.push({ kind: kind, i: i, left: wait }); queue.sort((a, b) => a.left - b.left);
  }
  function blast(x, y) {
    blasts.push({ x: x, y: y, age: 0 });
    for (let i = 0; i < 6; i++) { const p = smoke[si]; si = (si + 1) % smoke.length; p.on = true; p.x = x + rand(-bw, bw); p.y = y - rand(0, bh); p.vy = -rand(0.03, 0.09) * H; p.life = 1; p.r = s * rand(1, 2); }
    for (let i = 0; i < NB; i++) { const b = barrels[i]; if (b.alive && len(b.x - x, GY - bh / 2 - y) < R) enqueue("barrel", i, D.delay); }   // the radius test
    if (!dominoes[0].going && len(dominoes[0].x - x, GY - dh / 2 - y) < R) enqueue("domino", 0, D.delay);
    quiet = 0;
  }
  function light(i) { if (barrels[i].alive && barrels[i].fuse < 0) { enqueue("barrel", i, D.fuse); barrels[i].fuse = D.fuse; quiet = 0; } }
  function reset() { for (const b of barrels) { b.alive = true; b.fuse = -1; } for (const d of dominoes) { d.k = 0; d.going = false; } queue.length = 0; fadeIn = 0; }
  return {
    press(x) { let best = -1, bd = Infinity; for (let i = 0; i < NB; i++) { const d = Math.abs(barrels[i].x - x); if (barrels[i].alive && d < bd) { bd = d; best = i; } } if (best >= 0) light(best); timer = 0; },
    frame(dt, t) {
      timer += dt; quiet += dt; fadeIn = Math.min(1, fadeIn + dt * 2);
      const anyAlive = barrels.some(b => b.alive);
      if (timer > D.every && queue.length === 0 && anyAlive) { timer = 0; const alive = []; for (let i = 0; i < NB; i++) if (barrels[i].alive) alive.push(i); light(alive[Math.floor(rand(0, alive.length)) % alive.length]); }
      if (queue.length === 0 && quiet > D.respawn && (!anyAlive || dominoes[ND - 1].going)) reset();
      for (let i = queue.length - 1; i >= 0; i--) {   // the queue: fire whatever is due
        const q = queue[i]; q.left -= dt;
        if (q.left > 0) continue;
        queue.splice(i, 1);
        if (q.kind === "barrel") { const b = barrels[q.i]; if (b.alive) { b.alive = false; b.fuse = -1; blast(b.x, GY - bh / 2); } }
        else { const d = dominoes[q.i]; if (!d.going) { d.going = true; if (q.i + 1 < ND) enqueue("domino", q.i + 1, D.tip); } }
      }
      for (const b of barrels) if (b.fuse > 0) b.fuse -= dt;
      stage({ night: D.night }); ground();
      for (const b of barrels) {
        if (!b.alive) continue;
        ctx.globalAlpha = fadeIn;
        ctx.fillStyle = "#8A3A3A"; ctx.fillRect(b.x - bw / 2, GY - bh, bw, bh);
        ctx.fillStyle = "#4A2A2A"; ctx.fillRect(b.x - bw / 2, GY - bh * 0.7, bw, s * 0.5); ctx.fillRect(b.x - bw / 2, GY - bh * 0.3, bw, s * 0.5);
        ctx.globalAlpha = 1;
        let due = -1; for (const q of queue) if (q.kind === "barrel" && q.i === barrels.indexOf(b)) due = q.left;
        if (due >= 0) { const w = bw * 1.4; rect(b.x - w / 2, GY - bh - s * 1.6, w, s * 0.6, "rgba(232,229,244,0.2)"); rect(b.x - w / 2, GY - bh - s * 1.6, w * clamp(due / Math.max(D.delay, D.fuse), 0, 1), s * 0.6, HOT); if (t * 12 % 2 < 1) dot(b.x, GY - bh - s * 0.4, s * 0.5, SPARK); }
      }
      for (let i = 0; i < ND; i++) {                   // dominoes fall about their base corner
        const d = dominoes[i];
        if (d.going) d.k = Math.min(1, d.k + dt / 0.35);
        ctx.save(); ctx.translate(d.x + s * 0.5, GY); ctx.rotate(ease(d.k) * 1.25); ctx.globalAlpha = fadeIn;
        ctx.fillStyle = BONE; ctx.fillRect(-s * 0.5, -dh, s, dh); ctx.fillStyle = "#2B2440"; ctx.fillRect(-s * 0.15, -dh * 0.55, s * 0.3, s * 0.3);
        ctx.restore();
      }
      for (const p of smoke) { if (!p.on) continue; p.life -= dt * 0.6; if (p.life <= 0) { p.on = false; continue; } p.y += p.vy * dt; p.r += s * 0.8 * dt; dot(p.x, p.y, p.r, "rgba(90,80,90," + p.life * 0.45 + ")"); }
      ctx.globalCompositeOperation = "lighter";
      for (let i = blasts.length - 1; i >= 0; i--) {  // the blast: a fireball, and the honest radius ring
        const b = blasts[i]; b.age += dt; const k = b.age / 0.7; if (k >= 1) { blasts.splice(i, 1); continue; }
        if (k < 0.3) glow(b.x, b.y, Math.min(R * 0.6, W * 0.16) * (0.5 + k), FIRE, 0.9 * (1 - k / 0.3));
        ring(b.x, b.y, R * Math.min(1, k * 3), rgba(SUN, (1 - k) * 0.9), 1.5);
      }
      ctx.globalCompositeOperation = "source-over";
      for (const b of blasts) { ctx.setLineDash([3, 4]); ring(b.x, b.y, R, rgba(SUN, 0.5 * (1 - b.age / 0.7)), 1); ctx.setLineDash([]); text("R", b.x + R + 3, b.y + 3, 8, rgba(SUN, 1 - b.age / 0.7)); }
      let qx = 6;                                      // the queue, drawn in order
      text("queue:", qx, 14, 8, DIM); qx += 36;
      if (!queue.length) text("empty", qx, 14, 8, DIM);
      for (let i = 0; i < queue.length && qx < W - 30; i++) { const q = queue[i]; const tag = (q.kind === "barrel" ? "B" : "D") + (q.i + 1) + " " + q.left.toFixed(2); rect(qx - 2, 5, tag.length * 4.6 + 4, 11, q.kind === "barrel" ? "rgba(245,138,138,0.35)" : "rgba(201,196,228,0.3)"); text(tag, qx, 14, 8, BONE); qx += tag.length * 4.6 + 8; }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Kaboom", "Krakatoa", "a radius half the stage and a second's delay before each barrel answers — the slow doom you can count down", { radius: 0.5, delay: 1.1, respawn: 6 });

def("W", "Wick", "impact", "a spark walks a Bézier rope at a fixed rate, trailing smoke — a timer you can see (lexicon Path); it pops and resets — press to light or hurry it", function (u) {
  var D = { kind: "fuse",       // "fuse": a rope to a bomb · "candle": a wick burning down a candle, wax creeping down the sides
            burn: 4,            // seconds the whole length takes at the plain rate
            hurry: 3,           // a press while lit multiplies the rate by this
            path: [[0.08, 0.6], [0.24, 0.05], [0.5, 0.98], [0.8, 0.7]],   // the rope's cubic Bézier: start, two controls, end — fractions of W and H
            sparks: 40,         // sparks thrown per second while lit
            smoke: 8,           // puffs per second
            pause: 1.4,         // seconds between the pop and the next lighting
            label: "p(u) = Σ Bᵢ(u)·Pᵢ · u from the arc-length table · s += (L / burn)·dt" };
  const { ctx, W, H, GY, TAU, stage, hero, ground, dot, ring, line, rect, glow, label, text, rand, clamp, len, noise, rgba, SUN, SPARK, FIRE, DIM, BONE } = u;
  // a FUSE is a timer drawn as a distance: the spark moves along the rope at
  // a constant rate, so the rope left over IS the time left. the rope is one
  // cubic Bézier (lexicon Path), but a Bézier's parameter u is not distance —
  // the curve bunches near its controls — so the curve is sampled into 48
  // straight pieces and the spark walks the ARC-LENGTH table instead. the
  // spark is chapter 06's sparks with a smoke trail; the pop at the end is
  // small and local. a candle is the same clock stood upright.
  const s = Math.max(2, Math.round(H / 60)), N = 48, candle = D.kind === "candle";
  const P = D.path, pts = [], cum = [0];
  for (let i = 0; i <= N; i++) {                       // sample the curve, then the running length
    const k = i / N, a = (1 - k) * (1 - k) * (1 - k), b = 3 * (1 - k) * (1 - k) * k, c = 3 * (1 - k) * k * k, d = k * k * k;
    pts.push([W * (a * P[0][0] + b * P[1][0] + c * P[2][0] + d * P[3][0]), H * (a * P[0][1] + b * P[1][1] + c * P[2][1] + d * P[3][1])]);
    if (i > 0) cum.push(cum[i - 1] + len(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
  }
  const L = Math.max(1, cum[N]), end = pts[N];
  function at(dist) {                                  // the point a distance along the rope
    dist = clamp(dist, 0, L);
    let i = 1; while (i < N && cum[i] < dist) i++;
    const k = (dist - cum[i - 1]) / Math.max(1e-6, cum[i] - cum[i - 1]);
    return [pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * k, pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * k];
  }
  const sparks = [], puffs = [], drips = [];
  for (let i = 0; i < 40; i++) sparks.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, life: 0 });
  for (let i = 0; i < 40; i++) puffs.push({ on: false, x: 0, y: 0, vy: 0, life: 0, r: 1 });
  for (let i = 0; i < 14; i++) drips.push({ on: false, x: 0, y: 0, stop: 0, r: 1 });
  let si = 0, pu = 0, dr = 0, lit = false, popped = false, hurried = false, pos = 0, idleT = 0.4, popT = 0, sinceReset = 9, pops = 0;
  let sparkAcc = 0, smokeAcc = 0, dripAcc = 0;
  function puff(x, y, big) { const p = puffs[pu]; pu = (pu + 1) % puffs.length; p.on = true; p.x = x + rand(-1, 1) * s * (big ? 2 : 0.5); p.y = y; p.vy = -rand(0.03, 0.08) * H; p.life = 1; p.r = s * (big ? rand(1.5, 2.5) : rand(0.5, 0.9)); }
  function light() { lit = true; popped = false; pos = 0; hurried = false; }
  function pop() {
    lit = false; popped = true; popT = 0; pops++;
    for (let i = 0; i < (candle ? 4 : 14); i++) puff(end[0], end[1], true);
    if (!candle) for (let i = 0; i < 24; i++) { const p = sparks[si]; si = (si + 1) % sparks.length; const a = rand(0, TAU), v = rand(0.2, 0.6) * W; p.on = true; p.x = end[0]; p.y = end[1]; p.vx = Math.cos(a) * v; p.vy = Math.sin(a) * v; p.life = 1; }
  }
  function reset() { popped = false; pos = 0; idleT = 0; sinceReset = 0; for (const d of drips) d.on = false; }
  return {
    press() { if (popped) { popT = D.pause; } else if (!lit) light(); else hurried = true; },
    frame(dt, t) {
      sinceReset += dt;
      if (!lit && !popped) { idleT += dt; if (idleT > 1) light(); }   // autopilot: it lights itself
      const rate = L / Math.max(0.1, D.burn) * (hurried ? D.hurry : 1);
      if (lit) {
        pos += rate * dt;
        const p = at(pos);
        if (!candle) { sparkAcc = Math.min(8, sparkAcc + dt * D.sparks); while (sparkAcc >= 1) { sparkAcc -= 1; const q = sparks[si]; si = (si + 1) % sparks.length; const a = rand(0, TAU), v = rand(0.05, 0.25) * W; q.on = true; q.x = p[0]; q.y = p[1]; q.vx = Math.cos(a) * v; q.vy = Math.sin(a) * v - H * 0.1; q.life = 1; } }
        smokeAcc = Math.min(4, smokeAcc + dt * D.smoke * (candle ? 0.3 : 1)); while (smokeAcc >= 1) { smokeAcc -= 1; puff(p[0], p[1] - s, false); }
        if (candle) { dripAcc = Math.min(2, dripAcc + dt * 0.9); while (dripAcc >= 1) { dripAcc -= 1; const d = drips[dr]; dr = (dr + 1) % drips.length; d.on = true; d.x = p[0] + (rand(0, 1) < 0.5 ? -1 : 1) * s * 1.6; d.y = p[1] + s; d.stop = rand(d.y + s, GY - s * 0.5); d.r = s * 0.35; } }
        if (pos >= L) pop();
      }
      if (popped) { popT += dt; if (popT >= D.pause) reset(); }
      const left = lit ? (L - pos) / rate : (popped ? 0 : D.burn);
      stage({ night: 0.55 }); ground();
      hero(W * 0.92, GY, { face: -1, pose: lit && left < 0.6 && !candle ? "crouch" : "stand", frame: t });
      const fade = clamp(sinceReset / 0.4, 0, 1);      // the fuse fades back in after a pop
      if (candle) {                                    // the candle: a body from the flame down, on a saucer
        const p = at(pos), cx = pts[0][0], topY = lit ? p[1] : (popped ? end[1] : pts[0][1]);
        ctx.globalAlpha = fade;
        rect(cx - s * 3, GY - s * 0.9, s * 6, s * 0.9, BONE);
        rect(cx - s * 1.7, topY, s * 3.4, GY - s * 0.9 - topY, "#EFE6D0");
        rect(cx - s * 1.7, topY, s * 0.6, GY - s * 0.9 - topY, "rgba(0,0,0,0.12)");
        for (const d of drips) { if (!d.on) continue; if (d.y < d.stop) { d.y = Math.min(d.stop, d.y + H * 0.03 * dt); d.r = Math.min(s * 0.7, d.r + s * 0.15 * dt); } dot(d.x, d.y, d.r, "#F6EEDC"); rect(d.x - d.r * 0.5, topY + s, d.r, Math.max(0, d.y - topY - s), "#F6EEDC"); }
        line(cx, topY - s * 1.6, cx, topY, "#2B2440", Math.max(1, s * 0.4));
        ctx.globalAlpha = 1;
      } else {                                         // the rope: ash behind the spark, hemp ahead of it
        ctx.globalAlpha = fade;
        ctx.setLineDash([2, 3]); ctx.strokeStyle = "rgba(90,84,100,0.8)"; ctx.lineWidth = Math.max(1, s * 0.45); ctx.beginPath();
        ctx.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i <= N && cum[i] <= pos; i++) ctx.lineTo(pts[i][0], pts[i][1]); ctx.stroke(); ctx.setLineDash([]);
        const p = at(pos);
        ctx.strokeStyle = "#8A6A3E"; ctx.lineWidth = Math.max(1.5, s * 0.9); ctx.lineCap = "round"; ctx.beginPath(); ctx.moveTo(p[0], p[1]);
        for (let i = 1; i <= N; i++) if (cum[i] > pos) ctx.lineTo(pts[i][0], pts[i][1]);
        if (popped) { ctx.beginPath(); ctx.moveTo(end[0], end[1]); }
        ctx.stroke(); ctx.lineCap = "butt";
        if (!popped) { dot(end[0], end[1], s * 2.6, "#1E1A2A"); dot(end[0] - s * 0.8, end[1] - s * 0.9, s * 0.6, "rgba(255,255,255,0.35)"); }
        ctx.globalAlpha = 1;
      }
      for (const p of puffs) { if (!p.on) continue; p.life -= dt * 0.7; if (p.life <= 0) { p.on = false; continue; } p.y += p.vy * dt; p.r += s * 0.7 * dt; dot(p.x + noise(p.y * 0.05) * s, p.y, p.r, "rgba(170,165,190," + p.life * 0.35 + ")"); }
      if (lit) {                                       // the spark, or the flame
        const p = at(pos);
        ctx.globalCompositeOperation = "lighter";
        if (candle) { const fl = 1 + noise(t * 9) * 0.25; glow(p[0], p[1] - s, s * 6 * fl, SUN, 0.45); ctx.globalCompositeOperation = "source-over"; dot(p[0] + noise(t * 13) * s * 0.3, p[1] - s * 1.6, s * 1.1 * fl, FIRE); dot(p[0], p[1] - s * 1.1, s * 0.5, SPARK); }
        else { glow(p[0], p[1], s * 4.5 + noise(t * 30) * s, SUN, 0.7); ctx.globalCompositeOperation = "source-over"; dot(p[0], p[1], s * 0.9, "#FFFFFF"); }
        text(left.toFixed(1) + " s", p[0], p[1] - s * 3.5, 9, SPARK, "center");
      }
      ctx.globalCompositeOperation = "lighter";
      for (const q of sparks) { if (!q.on) continue; q.life -= dt * 3; if (q.life <= 0) { q.on = false; continue; } q.x += q.vx * dt; q.y += q.vy * dt; q.vy += H * 1.6 * dt; line(q.x, q.y, q.x - q.vx * 0.015, q.y - q.vy * 0.015, "rgba(255,233,168," + q.life + ")", 1.2); }
      if (popped && !candle && popT < 0.35) { const k = popT / 0.35; glow(end[0], end[1], W * 0.16 * (0.6 + k), FIRE, (1 - k) * 0.9); ring(end[0], end[1], W * 0.2 * k + 1, rgba(SUN, 1 - k), 1.5); }
      ctx.globalCompositeOperation = "source-over";
      const x0 = W * 0.1, x1 = W * 0.9, y0 = 8, bw = x1 - x0;   // the burn-down bar: the rope's length as a bar, one tick per plain second
      rect(x0, y0, bw, 5, "rgba(232,229,244,0.1)");
      rect(x0, y0, bw * clamp((L - pos) / L, 0, 1) * (popped ? 0 : 1), 5, hurried ? FIRE : SUN);
      if (D.burn <= 30) for (let i = 1; i < D.burn; i++) line(x0 + bw * i / D.burn, y0, x0 + bw * i / D.burn, y0 + 5, "rgba(19,16,32,0.6)", 1);
      text("burn " + D.burn + " s · L = " + Math.round(L) + " px" + (hurried ? " · hurried ×" + D.hurry : "") + " · " + (popped ? (candle ? "guttered" : "pop!") : lit ? "lit" : "unlit") + " · " + pops + " so far", W / 2, y0 + 15, 8, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Wick", "Waxwick", "the same clock stood upright: a wick twelve seconds down a candle, wax creeping down the sides, and a gutter of smoke instead of a bang", { kind: "candle", burn: 12, path: [[0.5, 0.32], [0.5, 0.45], [0.5, 0.6], [0.5, 0.74]] });

def("G", "Grenade", "impact", "fuse runs from the pin: arc preview while held, bounces, blast — cook too long, it goes off in hand (lexicon Bounce) — drag to aim, let go to throw", function (u) {
  var D = { kind: "frag",       // "frag": a flash and shrapnel · "gas": a cloud that lingers
            fuse: 3,            // seconds from the pin to the blast
            throwV: 1.1,        // throw speed at a full-length aim, in H per second
            g: 2.2,             // gravity, in H per second²
            rest: 0.45,         // restitution: what a bounce keeps of the vertical speed
            friction: 0.7,      // what a bounce keeps of the sideways speed
            release: 0.15,      // seconds without a press = you let go
            cloud: 4,           // gas only: seconds the cloud lingers
            cook: [0.3, 3.4],   // autopilot: how long it holds a live grenade (min, max) — past the fuse it cooks off
            every: 2.4,         // autopilot: seconds between throws
            label: "fuse −= dt from the pull · preview = the same integrator run ahead · vy ← −e·vy" };
  const { ctx, W, H, GY, TAU, stage, hero, crate, ground, dot, ring, line, rect, arrow, glow, label, text, rand, clamp, len, rgba, SUN, FIRE, HOT, GOOD, DIM, BONE } = u;
  // the grenade's clock starts when the PIN comes out and nothing after that
  // stops it — so COOKING (holding a live one) trades your safety for a
  // blast that lands with less time for anyone to run. while it is held, the
  // ARC PREVIEW runs the very same integrator the throw will use (lexicon
  // Jump's parabola, Bounce's restitution) two seconds ahead and marks the
  // point on that arc where the fuse would run out. hold past the fuse and
  // it goes off in your hand; the meter by the hero is the only warning.
  const s = Math.max(2, Math.round(H / 60)), G = H * D.g, R = s * 1.2, hx = W * 0.16, cx = W * 0.62, cs = s * 6;
  const gas = D.kind === "gas";
  let phase = "idle", fuseLeft = 0, since = 0, held = 0, cookFor = 1, manual = false, timer = D.every * 0.6;
  let ax = 0, ay = 0, rot = 0, vr = 0, fxT = 9, fxX = 0, fxY = 0, hurtT = 0, throws = 0, cooked = 0, lastCook = 0;
  const body = { x: 0, y: 0, vx: 0, vy: 0, b: 0 }, pv = { x: 0, y: 0, vx: 0, vy: 0, b: 0 };
  const sparks = [], puffs = [];
  for (let i = 0; i < 24; i++) sparks.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, life: 0 });
  for (let i = 0; i < 40; i++) puffs.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, age: 0, r: 1 });
  let si = 0, pu = 0;
  function hand() { return [hx + 5 * s, GY - 11 * s]; }
  function pull() { phase = "held"; fuseLeft = D.fuse; since = 0; held = 0; }
  function aimAt(x, y) {
    const h = hand(); let dx = x - h[0], dy = y - h[1]; const d = len(dx, dy) || 1, k = clamp(d / (W * 0.45), 0.15, 1);
    ax = dx / d * k * H * D.throwV; ay = dy / d * k * H * D.throwV;
  }
  function step(o, dt) {                               // one integrator step, shared by the flight and the preview
    o.vy += G * dt; o.x += o.vx * dt; o.y += o.vy * dt;
    if (o.y > GY - R) { o.y = GY - R; if (o.vy > H * 0.08) { o.vy = -o.vy * D.rest; o.vx *= D.friction; o.b++; } else { o.vy = 0; o.vx *= Math.max(0, 1 - 3 * dt); } }
    if (o.x < R) { o.x = R; o.vx = Math.abs(o.vx) * D.rest; } else if (o.x > W - R) { o.x = W - R; o.vx = -Math.abs(o.vx) * D.rest; }
    const l = cx - cs / 2 - R, r = cx + cs / 2 + R, top = GY - cs - R;   // the crate: a box to bounce off
    if (o.x > l && o.x < r && o.y > top) {
      const px = Math.min(o.x - l, r - o.x), py = o.y - top;
      if (py < px) { o.y = top; if (o.vy > 0) { o.vy = -o.vy * D.rest; o.vx *= D.friction; o.b++; } }
      else if (o.x < cx) { o.x = l; o.vx = -Math.abs(o.vx) * D.rest; } else { o.x = r; o.vx = Math.abs(o.vx) * D.rest; }
    }
  }
  function throwIt() { const h = hand(); phase = "flying"; body.x = h[0]; body.y = h[1]; body.vx = ax; body.vy = ay; body.b = 0; vr = rand(-12, 12); throws++; lastCook = held; }
  function detonate(x, y, inHand) {
    phase = "done"; fxT = 0; fxX = x; fxY = y;
    if (inHand) { cooked++; hurtT = 0.8; }
    if (gas) for (let i = 0; i < 24; i++) { const p = puffs[pu]; pu = (pu + 1) % puffs.length; const a = rand(0, TAU), v = rand(0.02, 0.12) * W; p.on = true; p.x = x; p.y = y; p.vx = Math.cos(a) * v; p.vy = Math.sin(a) * v * 0.5 - H * 0.02; p.age = 0; p.r = s * rand(1.5, 3); }
    else for (let i = 0; i < 20; i++) { const p = sparks[si]; si = (si + 1) % sparks.length; const a = rand(0, TAU), v = rand(0.25, 0.7) * W; p.on = true; p.x = x; p.y = y; p.vx = Math.cos(a) * v; p.vy = Math.sin(a) * v; p.life = 1; }
  }
  function grenade(x, y, r, a) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(r); ctx.globalAlpha = a === undefined ? 1 : a;
    ctx.fillStyle = gas ? "#5A7A5A" : "#3F4A3A"; ctx.beginPath(); ctx.arc(0, 0, R, 0, TAU); ctx.fill();
    ctx.fillStyle = "#9A9AA8"; ctx.fillRect(-R * 0.4, -R * 1.4, R * 0.8, R * 0.6);
    ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(R * 0.4, -R * 1.2); ctx.lineTo(R * 1.3, -R * 0.4); ctx.stroke();
    ctx.restore();
  }
  return {
    drag: true,
    press(x, y) { if (phase === "idle" || phase === "done") { pull(); manual = true; } if (phase === "held") { aimAt(x, y); since = 0; manual = true; } },
    frame(dt, t) {
      timer += dt; hurtT -= dt; fxT += dt;
      if (phase === "idle" && timer > D.every) { timer = 0; manual = false; pull(); cookFor = rand(D.cook[0], D.cook[1]); aimAt(rand(W * 0.45, W * 0.95), rand(H * 0.1, GY - H * 0.25)); }
      if (phase === "held") {
        fuseLeft -= dt; held += dt; since += dt;
        if (fuseLeft <= 0) { const h = hand(); detonate(h[0], h[1], true); }
        else if (manual ? since > D.release : held > cookFor) throwIt();
      }
      if (phase === "flying") { fuseLeft -= dt; step(body, dt); rot += vr * dt; if (body.b > 0) vr *= Math.max(0, 1 - 2 * dt); if (fuseLeft <= 0) detonate(body.x, body.y, false); }
      if (phase === "done" && fxT > (gas ? D.cloud : 0.9)) { phase = "idle"; timer = Math.min(timer, D.every * 0.6); }
      stage({ night: 0.4 }); ground(); crate(cx, GY, cs);
      const h = hand();
      hero(hx, GY, { face: 1, pose: hurtT > 0 ? "hurt" : "stand", frame: t });
      if (phase === "held") {                          // the preview: run the integrator ahead and mark where the fuse ends
        pv.x = h[0]; pv.y = h[1]; pv.vx = ax; pv.vy = ay; pv.b = 0;
        const steps = 100, boomStep = Math.floor(fuseLeft * 50);
        let bx = -1, by = -1;
        for (let i = 1; i <= steps; i++) {
          step(pv, 0.02);
          if (i % 4 === 0) dot(pv.x, pv.y, 1.2, "rgba(232,229,244," + (0.8 - i / steps * 0.6) + ")");
          if (i === boomStep) { bx = pv.x; by = pv.y; }
        }
        if (bx >= 0) { ring(bx, by, s * 2.5, HOT, 1.5); text("boom", bx, by - s * 3.2, 8, HOT, "center"); }
        else text("boom later →", pv.x, pv.y - s * 2.5, 8, "rgba(245,138,138,0.7)", "center");
        arrow(h[0], h[1], h[0] + ax * 0.1, h[1] + ay * 0.1, SUN);
        grenade(h[0], h[1], 0);
        const mw = s * 8;                              // the cook meter: how much fuse is left while it is still in the hand
        rect(h[0] - mw / 2, h[1] - s * 4.2, mw, s * 0.8, "rgba(232,229,244,0.15)");
        rect(h[0] - mw / 2, h[1] - s * 4.2, mw * clamp(fuseLeft / D.fuse, 0, 1), s * 0.8, fuseLeft < 1 ? HOT : SUN);
        text("cooking " + held.toFixed(2) + " s · " + fuseLeft.toFixed(2) + " left", h[0], h[1] - s * 5.2, 8, fuseLeft < 1 ? HOT : BONE, "center");
      }
      if (phase === "flying") {
        grenade(body.x, body.y, rot);
        rect(body.x - s * 3, body.y - s * 3.2, s * 6, s * 0.7, "rgba(232,229,244,0.15)");
        rect(body.x - s * 3, body.y - s * 3.2, s * 6 * clamp(fuseLeft / D.fuse, 0, 1), s * 0.7, fuseLeft < 1 ? HOT : SUN);
        text(fuseLeft.toFixed(2) + " s", body.x, body.y - s * 4, 8, BONE, "center");
      }
      if (gas) {                                       // the cloud: puffs that spread, then thin out over D.cloud
        for (const p of puffs) { if (!p.on) continue; p.age += dt; const k = p.age / D.cloud; if (k >= 1) { p.on = false; continue; } p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= Math.max(0, 1 - 0.8 * dt); if (p.y > GY - p.r * 0.4) p.vy = -Math.abs(p.vy) * 0.3; p.r += s * 1.2 * dt; dot(p.x, p.y, p.r, rgba(GOOD, (1 - k) * 0.35)); }
      } else {
        ctx.globalCompositeOperation = "lighter";
        if (fxT < 0.35) { const k = fxT / 0.35; glow(fxX, fxY, W * 0.15 * (0.6 + k), FIRE, (1 - k) * 0.9); ring(fxX, fxY, W * 0.18 * k + 1, rgba(SUN, 1 - k), 1.5); }
        for (const p of sparks) { if (!p.on) continue; p.life -= dt * 2.2; if (p.life <= 0) { p.on = false; continue; } p.x += p.vx * dt; p.y += p.vy * dt; p.vy += H * 1.4 * dt; if (p.y > GY) { p.y = GY; p.vy = -p.vy * 0.4; } line(p.x, p.y, p.x - p.vx * 0.02, p.y - p.vy * 0.02, "rgba(255,233,168," + p.life + ")", 1.2); }
        ctx.globalCompositeOperation = "source-over";
      }
      if (hurtT > 0) text("cooked off in hand", hx, GY - s * 20, 9, HOT, "center");
      text("fuse " + D.fuse + " s · throws " + throws + " · cooked off " + cooked + (throws ? " · last cooked " + lastCook.toFixed(2) + " s" : ""), W / 2, 14, 8, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Grenade", "Gasbomb", "the same pin, arc and bounces, but the payload is a cloud: puffs that spread for six seconds instead of a flash — cook it and it lands ready", { kind: "gas", cloud: 6, fuse: 2.5 });

def("A", "Aoe", "impact", "circle, cone or line fills over the windup, then hits — danger you can read (ch14 telegraph); the hero steps out once it reacts — press to place one", function (u) {
  var D = { windup: 1.2,        // seconds a telegraph fills before it hits
            shape: "cycle",     // "circle" | "cone" | "line" | "cycle" through all three
            count: 1,           // telegraphs per cast, staggered
            gap: 1.0,           // seconds between casts
            radius: 0.13,       // circle radius, in W
            cone: 0.45,         // cone half-angle, radians
            range: 0.5,         // cone and line reach, in W
            width: 0.06,        // line width, in W
            react: 0.35,        // hero's reaction time before it starts to step out
            speed: 0.3,         // hero's escape speed, in W per second
            label: "fill = age / windup → hit at 1 · inside(shape, hero) ? hit : dodged" };
  const { ctx, W, H, GY, TAU, stage, hero, dot, ring, line, rect, label, text, rand, clamp, len, rgba, HOT, SUN, GOOD, MAGIC, DIM, BONE } = u;
  // an AoE TELEGRAPH draws the hit before it lands: the shape's outline is
  // the promise, the FILL is the clock — it grows from the centre (or from
  // the caster) as age/windup, and the hit comes exactly at full. the hero
  // reads it too: after a REACTION TIME it steps out along the shortest way
  // (away from a circle's centre, across a cone's or a line's aim), so a
  // long windup is a dodge and a short one is a hit — the same shape, and
  // the fairness lives entirely in the number. the ground is a plane seen
  // at a squash of 0.35, so circles are the ellipses a floor would show.
  const s = Math.max(2, Math.round(H / 60)), SQ = 0.35, ZM = (H - GY) / SQ * 0.92, KINDS = ["circle", "cone", "line"];
  const ex = W * 0.82, ez = ZM * 0.5;
  let hx = W * 0.4, hz = ZM * 0.5, face = 1, hurtT = 0, moving = false, castT = D.gap * 0.5, next = 0, hits = 0, dodged = 0, casts = 0;
  const tgs = [];
  for (let i = 0; i < 8; i++) tgs.push({ on: false, kind: "circle", x: 0, z: 0, ax: 1, az: 0, age: 0, res: "" });
  let ti = 0;
  function sy(z) { return GY + z * SQ; }
  function cast(kind, tx, tz, delay) {
    const g = tgs[ti]; ti = (ti + 1) % tgs.length;
    g.on = true; g.kind = kind; g.age = -delay; g.res = ""; casts++;
    if (kind === "circle") { g.x = tx; g.z = tz; g.ax = 1; g.az = 0; }
    else { g.x = ex; g.z = ez; const dx = tx - ex, dz = tz - ez, d = len(dx, dz) || 1; g.ax = dx / d; g.az = dz / d; }
  }
  function inside(g, px, pz) {
    const dx = px - g.x, dz = pz - g.z;
    if (g.kind === "circle") return len(dx, dz) < W * D.radius;
    const along = dx * g.ax + dz * g.az, perp = -dx * g.az + dz * g.ax;
    if (g.kind === "line") return along > 0 && along < W * D.range && Math.abs(perp) < W * D.width / 2;
    return along > 0 && len(dx, dz) < W * D.range && Math.abs(Math.atan2(perp, along)) < D.cone;
  }
  function out(g, px, pz) {                            // the shortest way out: away from the centre, or across the aim
    const dx = px - g.x, dz = pz - g.z;
    if (g.kind === "circle") { const d = len(dx, dz); return d < 1e-6 ? [0, 1] : [dx / d, dz / d]; }
    const perp = -dx * g.az + dz * g.ax, sg = perp >= 0 ? 1 : -1;
    return [-g.az * sg, g.ax * sg];
  }
  function nextKind() { const k = D.shape === "cycle" ? KINDS[next % 3] : D.shape; next++; return KINDS.indexOf(k) < 0 ? "circle" : k; }
  function volley(tx, tz) {
    const n = Math.max(1, Math.round(D.count));
    for (let i = 0; i < n; i++) cast(nextKind(), clamp(tx + (i ? rand(-1, 1) * W * 0.12 : 0), s * 2, W - s * 2), clamp(tz + (i ? rand(-1, 1) * ZM * 0.3 : 0), 0, ZM), i * 0.15);
  }
  function shape(g, frac) {                            // the shape as a path, at a fraction of its full size
    const r = W * D.radius, rg = W * D.range, hw = W * D.width / 2;
    ctx.beginPath();
    if (g.kind === "circle") { ctx.ellipse(g.x, sy(g.z), Math.max(0.5, r * frac), Math.max(0.5, r * frac * SQ), 0, 0, TAU); return; }
    if (g.kind === "line") { const px = -g.az * hw, pz = g.ax * hw, lx = g.ax * rg * frac, lz = g.az * rg * frac; ctx.moveTo(g.x + px, sy(g.z + pz)); ctx.lineTo(g.x + lx + px, sy(g.z + lz + pz)); ctx.lineTo(g.x + lx - px, sy(g.z + lz - pz)); ctx.lineTo(g.x - px, sy(g.z - pz)); ctx.closePath(); return; }
    const a0 = Math.atan2(g.az, g.ax); ctx.moveTo(g.x, sy(g.z));
    for (let i = 0; i <= 12; i++) { const a = a0 - D.cone + D.cone * 2 * i / 12; ctx.lineTo(g.x + Math.cos(a) * rg * frac, sy(g.z + Math.sin(a) * rg * frac)); }
    ctx.closePath();
  }
  function drawTg(g, newest) {
    const k = clamp(g.age / D.windup, 0, 1), hitK = g.age > D.windup ? (g.age - D.windup) / 0.35 : -1;
    shape(g, 1); ctx.fillStyle = "rgba(245,138,138,0.12)"; ctx.fill(); ctx.strokeStyle = rgba(HOT, hitK < 0 ? 0.9 : 0.9 * (1 - hitK)); ctx.lineWidth = 1.2; ctx.stroke();
    if (hitK < 0) { shape(g, k); ctx.fillStyle = "rgba(245,138,138,0.38)"; ctx.fill(); }
    else { shape(g, 1); ctx.fillStyle = "rgba(255,255,255," + (1 - hitK) * 0.7 + ")"; ctx.fill(); }
    if (newest && hitK < 0) text(Math.round(k * 100) + "%", g.kind === "circle" ? g.x : g.x + g.ax * W * D.range * 0.5, sy(g.kind === "circle" ? g.z : g.z + g.az * W * D.range * 0.5) - 4, 8, HOT, "center");
    if (hitK >= 0 && g.res) text(g.res, g.kind === "circle" ? g.x : g.x + g.ax * W * D.range * 0.5, sy(g.kind === "circle" ? g.z : g.z + g.az * W * D.range * 0.5) - 4, 9, g.res === "hit" ? HOT : GOOD, "center");
  }
  return {
    press(x, y) { volley(clamp(x, s * 2, W - s * 2), clamp((y - GY) / SQ, 0, ZM)); castT = 0; },
    frame(dt, t) {
      castT += dt; hurtT -= dt;
      let active = false; for (const g of tgs) if (g.on && g.age < D.windup) active = true;
      if (!active && castT > D.gap) { castT = 0; volley(hx + rand(-1, 1) * W * 0.05, hz); }   // autopilot: the caster aims at the hero
      let mx = 0, mz = 0; moving = false;              // the hero: step out of every shape it has had time to read
      for (const g of tgs) { if (!g.on || g.age < D.react || g.age >= D.windup || !inside(g, hx, hz)) continue; const o = out(g, hx, hz); mx += o[0]; mz += o[1]; }
      const ml = len(mx, mz);
      if (ml > 1e-6) { moving = true; hx = clamp(hx + mx / ml * W * D.speed * dt, s * 3, W * 0.72); hz = clamp(hz + mz / ml * W * D.speed * dt, 0, ZM); if (Math.abs(mx) > 0.2) face = mx > 0 ? 1 : -1; }
      let newest = null;
      for (const g of tgs) {
        if (!g.on) continue;
        const was = g.age; g.age += dt;
        if (was < D.windup && g.age >= D.windup) { if (inside(g, hx, hz)) { hits++; hurtT = 0.5; g.res = "hit"; } else { dodged++; g.res = "dodged"; } }
        if (g.age > D.windup + 0.35) g.on = false;
        else if (g.age >= 0 && g.age < D.windup && (!newest || g.age < newest.age)) newest = g;
      }
      stage({ night: 0.45 });
      for (let i = 0; i <= 4; i++) line(0, sy(ZM * i / 4), W, sy(ZM * i / 4), "rgba(232,229,244,0.07)", 1);   // the floor's depth lines
      for (const g of tgs) if (g.on && g.age >= 0) drawTg(g, g === newest);
      const drawHero = () => hero(hx, sy(hz), { face: face, pose: hurtT > 0 ? "hurt" : (moving ? "run" : "stand"), frame: t });
      const drawEnemy = () => {                        // the caster: a hooded shape, lit while a telegraph fills
        const ey = sy(ez);
        if (active) { ctx.globalCompositeOperation = "lighter"; dot(ex, ey, s * 4, rgba(MAGIC, 0.25)); ctx.globalCompositeOperation = "source-over"; }
        ctx.fillStyle = "#2B2440"; ctx.beginPath(); ctx.ellipse(ex, ey - s * 6, s * 3.6, s * 6.2, 0, 0, TAU); ctx.fill();
        dot(ex - s * 1.2, ey - s * 9, s * 0.7, active ? HOT : MAGIC); dot(ex + s * 1.2, ey - s * 9, s * 0.7, active ? HOT : MAGIC);
        line(ex + s * 3.5, ey, ex + s * 3.5, ey - s * 13, "#5A3E2B", Math.max(1, s * 0.5)); dot(ex + s * 3.5, ey - s * 13, s * 1.1, active ? HOT : MAGIC);
      };
      if (hz < ez) { drawHero(); drawEnemy(); } else { drawEnemy(); drawHero(); }
      if (moving) { const o = [mx / Math.max(ml, 1e-6), mz / Math.max(ml, 1e-6)]; line(hx, sy(hz), hx + o[0] * s * 5, sy(hz + o[1] * s * 5), GOOD, 1.2); }
      text("hits " + hits + " · dodged " + dodged, 6, 14, 8, DIM);
      text("windup " + D.windup + " s · react " + D.react + " s · " + (D.count > 1 ? D.count + " at once" : D.shape), W - 6, 14, 8, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Aoe", "Ambush", "half-second windups, three shapes at once with overlaps — the way out of one is into the next, and the hero's reaction time is suddenly the whole game", { windup: 0.5, count: 3, gap: 0.7 });

def("T", "Tell", "impact", "before each swing the enemy flashes white and leans back 0.2 s — the tell: a dodge inside it is safe, a late one is hit (lexicon Cat) — press to dodge", function (u) {
  var D = { tell: 0.2,          // seconds of the wind-up: the flash and the lean
            lean: 0.35,         // radians the body leans back at the tell's peak
            tint: "white",      // "white" flash or "red" tint during the tell
            strike: 0.1,        // seconds the swing takes to land
            recover: 0.7,       // seconds the enemy hangs after a swing
            every: 1.6,         // seconds between attacks
            dodgeLen: 0.35,     // seconds a dodge's safe window lasts
            react: 0.25,        // the hero's reaction time (± a little noise)
            label: "tell → strike → recover · safe if dodge ≤ land ≤ dodge + dodgeLen" };
  const { ctx, W, H, GY, TAU, stage, hero, ground, dot, ring, line, rect, label, text, rand, clamp, ease, lerp, mix, shade, rgba, HOT, SUN, GOOD, DIM, BONE, INK } = u;
  // a TELL is the attack's promise: for D.tell seconds before the swing the
  // enemy's body goes white (chapter 03's hit-flash, worn early) and LEANS
  // BACK about its feet — two cues, so it reads in the corner of the eye.
  // the dodge is a window: a hop with dodgeLen seconds of safety. the swing
  // lands at tell + strike; the hero is safe if that instant falls inside its
  // window — start too late and you are hit, too early and the window has
  // closed again (lexicon Cat's i-frames). the hero here has a REACTION
  // TIME, so with a short tell it is often late, and with a long one it can
  // wait and time the hop; the bar at the top shows where each dodge fell.
  const s = Math.max(2, Math.round(H / 60)), hx = W * 0.36, ex = W * 0.62, body = "#6E4A8A";
  let phase = "idle", pt = D.every * 0.4, clock = 0, tellStart = -99, plan = 0, planned = false;
  let dodgeT = 0, dodgeStart = -99, hurtT = 0, shake = 0, hits = 0, dodged = 0, lastRes = "", lastAt = 0, lastWhy = "", lastManual = false;
  function startDodge(manual) { if (dodgeT > 0) return; dodgeT = D.dodgeLen; dodgeStart = clock; lastManual = manual; if (manual) planned = false; }
  return {
    press() { startDodge(true); },
    frame(dt, t) {
      pt += dt; clock += dt; dodgeT -= dt; hurtT -= dt; shake *= Math.max(0, 1 - 8 * dt);
      if (phase === "idle" && pt > D.every) {          // the tell begins; the hero plans its hop: no faster than its reaction, else just before the swing
        phase = "tell"; pt = 0; tellStart = clock; planned = true;
        plan = Math.max(D.react + rand(-0.12, 0.12), D.tell - 0.1 + rand(-0.08, 0.08));
      }
      if (phase === "tell") { if (planned && pt >= plan) { planned = false; startDodge(false); } if (pt > D.tell) { phase = "strike"; pt = 0; } }
      else if (phase === "strike" && pt > D.strike) {  // the swing lands: is the hero inside its window?
        const land = clock, safe = dodgeStart <= land && land <= dodgeStart + D.dodgeLen;
        lastAt = dodgeStart - tellStart; lastRes = safe ? "dodged" : "hit";
        lastWhy = safe ? "" : (dodgeStart < tellStart - 0.5 ? "no dodge" : (dodgeStart > land ? "too late" : "too early"));
        if (safe) dodged++; else { hits++; hurtT = 0.5; shake = 1; }
        phase = "recover"; pt = 0; planned = false;
      }
      else if (phase === "recover" && pt > D.recover) { phase = "idle"; pt = 0; }
      const k = phase === "tell" ? ease(pt / D.tell) : phase === "strike" ? 1 - pt / D.strike * 1.4 : phase === "recover" ? lerp(-0.4, 0, ease(pt / D.recover)) : 0;
      const armA = phase === "tell" ? lerp(0.3, -2.4, ease(pt / D.tell)) : phase === "strike" ? lerp(-2.4, 1.3, clamp(pt / D.strike, 0, 1)) : phase === "recover" ? lerp(1.3, 0.3, ease(pt / D.recover)) : 0.3;
      const tintK = phase === "tell" ? (pt < 0.034 ? 1 : 0.85) : 0;
      const fill = tintK > 0 ? mix(body, D.tint === "red" ? HOT : "#FFFFFF", tintK) : body;
      stage({ night: 0.4 }); ground();
      const dk = dodgeT > 0 ? 1 - dodgeT / D.dodgeLen : 1, hop = Math.sin(Math.PI * clamp(dk, 0, 1)), sx = (rand(-1, 1) * shake * 2);
      if (dodgeT > 0) ring(hx, GY, s * 3, rgba(GOOD, 0.5), 1);
      hero(hx - hop * s * 7 + sx, GY - hop * s * 3, { face: 1, pose: hurtT > 0 ? "hurt" : dodgeT > 0 ? "crouch" : "stand", frame: t });
      ctx.save(); ctx.translate(ex, GY); ctx.rotate(D.lean * k);   // the enemy leans about its feet
      ctx.fillStyle = shade(body, -0.3); ctx.fillRect(-3 * s, -3 * s, 2 * s, 3 * s); ctx.fillRect(s, -3 * s, 2 * s, 3 * s);
      ctx.fillStyle = fill; ctx.beginPath(); ctx.ellipse(0, -8 * s, 4.5 * s, 6 * s, 0, 0, TAU); ctx.fill();
      ctx.fillStyle = tintK > 0 ? HOT : "#FFFFFF"; ctx.beginPath(); ctx.arc(-1.6 * s, -9.5 * s, s * 0.9, 0, TAU); ctx.fill();
      ctx.fillStyle = "#1A1020"; ctx.beginPath(); ctx.arc(-1.9 * s, -9.5 * s, s * 0.45, 0, TAU); ctx.fill();
      ctx.translate(-3 * s, -9 * s); ctx.rotate(armA);
      ctx.fillStyle = fill; ctx.fillRect(-s * 0.7, 0, s * 1.4, 6 * s);
      ctx.fillStyle = "#5A3E2B"; ctx.fillRect(-s * 1.3, 5 * s, s * 2.6, 3 * s);
      ctx.restore();
      if (phase === "tell") { text("tell " + (pt).toFixed(2) + " / " + D.tell + " s", ex, GY - s * 17, 8, INK, "center"); text("lean " + (D.lean * k).toFixed(2) + " rad", ex, GY - s * 15.4, 7, DIM, "center"); }
      if (phase === "recover" && pt < 0.5) text(lastRes === "hit" ? "hit!" : "miss", hx + s * 2, GY - s * 19, 10, lastRes === "hit" ? HOT : GOOD, "center");
      const x0 = W * 0.08, x1 = W * 0.92, y0 = 8, total = D.tell + D.strike + D.recover, px = (x1 - x0) / total;   // the attack as a bar, and the dodge window under it
      rect(x0, y0, D.tell * px, 5, "rgba(232,229,244,0.85)"); rect(x0 + D.tell * px, y0, D.strike * px, 5, HOT); rect(x0 + (D.tell + D.strike) * px, y0, D.recover * px, 5, "rgba(232,229,244,0.15)");
      text("tell", x0, y0 + 14, 7, DIM); text("land", x0 + (D.tell + D.strike) * px, y0 + 14, 7, HOT, "center"); text("recover", x1, y0 + 14, 7, DIM, "right");
      if (dodgeStart > tellStart - 0.5 && tellStart > -1) {
        const a = clamp(dodgeStart - tellStart, 0, total), b = clamp(dodgeStart - tellStart + D.dodgeLen, 0, total);
        if (b > a) rect(x0 + a * px, y0 + 6, (b - a) * px, 3, lastManual ? SUN : GOOD);
      }
      if (phase !== "idle") { const rel = phase === "tell" ? pt : phase === "strike" ? D.tell + pt : D.tell + D.strike + pt; const hxp = x0 + clamp(rel, 0, total) * px; line(hxp, y0 - 2, hxp, y0 + 10, INK, 1); }
      text("hits " + hits + " · dodged " + dodged + (lastRes ? " · last: " + lastRes + (lastWhy ? " (" + lastWhy + ")" : "") + " at +" + lastAt.toFixed(2) + " s" : ""), W / 2, y0 + 25, 8, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Tell", "Telegraphed", "a tutorial boss: a tell three times as long with a deep lean — the hero has time to wait and hop just before the swing, and nearly always does", { tell: 0.6, lean: 0.7, every: 2.4 });
/* ============================== WATER, WEATHER & NATURE ==============================
   The outdoors as SYSTEMS rather than paintings. Water is a row of springs
   that pass their motion sideways; a float reads that surface and pushes it
   back; the shoreline is a slow sine the sand remembers; puddles and a wet
   lens are the flip-and-clip mirror trick worn by a hundred small mirrors.
   Snow is a height field that deepens where feet fall, reeds are springs on
   an angle, wind is a region with an envelope, a year is one clock driving
   every leaf, a fern is a rule string, wildfire and lava are cellular grids,
   and the cheapest "outdoors" of all is a scrolling noise mask on the ground. */

def("W", "Wavesprings", "weather", "a row of springs, each pulled to rest and toward its neighbours — one kick becomes a wave that travels, spreads and settles (lexicon Damp) — press to splash at x", function (u) {
  var D = { n: 40,              // springs across the width
            tension: 60,        // k: the pull back to the rest level, per second²
            damping: 2.5,       // c: velocity bleed, per second
            spread: 18,         // s: the pull toward each neighbour, per second²
            level: 0.68,        // the rest surface, of H
            splash: 0.9,        // a drop's kick, in H per second
            every: 2.6,         // seconds between the autopilot's drops
            label: "a = −k·y − c·v + s·(yL + yR − 2y)" };
  const { ctx, W, H, TAU, stage, dot, line, label, clamp, rand, rgba, SUN, INK } = u;
  // the surface is n SPRINGS (Damp's a = ω²(target − y) − 2ζω·v), one per
  // column, each resting on the water line. alone they would only bob in
  // place; the SPREAD term pulls every spring toward its two neighbours, and
  // that coupling is what turns one kick into a wave that travels outward,
  // bounces off the banks and dies down — Terraria's water in forty numbers.
  // drawn as the dots it really is, with the rest line dashed behind them.
  let ys = [], vs = [], drops = [], clock = 0;
  for (let i = 0; i < D.n; i++) { ys.push(0); vs.push(0); }
  function kick(x, v) {
    const i = clamp(Math.round(x / W * (D.n - 1)), 0, D.n - 1);
    vs[i] += v;
    if (i > 0) vs[i - 1] += v * 0.5;
    if (i < D.n - 1) vs[i + 1] += v * 0.5;
  }
  function drop(x, y) { if (drops.length < 8) drops.push({ x: x, y: y, vy: 0 }); }
  return {
    press(x, y) { drop(clamp(x, 2, W - 2), Math.min(y, H * D.level - 6)); },
    frame(dt, t) {
      stage({ night: 0.15 });
      const rest = H * D.level, dx = W / (D.n - 1);
      clock += dt;
      if (clock > D.every) { clock = 0; drop(rand(W * 0.1, W * 0.9), H * 0.08); }
      for (let d = drops.length - 1; d >= 0; d--) {          // a pebble falls, then kicks the spring it lands on
        const p = drops[d];
        p.vy += H * 2.4 * dt; p.y += p.vy * dt;
        const i = clamp(Math.round(p.x / W * (D.n - 1)), 0, D.n - 1);
        if (p.y >= rest + ys[i]) { kick(p.x, H * D.splash * clamp(p.vy / (H * 1.5), 0.3, 1.4)); drops.splice(d, 1); }
        else dot(p.x, p.y, 2.5, INK);
      }
      for (let i = 0; i < D.n; i++) {                        // the whole physics: one acceleration per spring
        const yl = ys[i > 0 ? i - 1 : i], yr = ys[i < D.n - 1 ? i + 1 : i];
        vs[i] += (-D.tension * ys[i] - D.damping * vs[i] + D.spread * (yl + yr - 2 * ys[i])) * dt;
      }
      for (let i = 0; i < D.n; i++) ys[i] = clamp(ys[i] + vs[i] * dt, -H * 0.3, H * 0.3);
      ctx.fillStyle = "rgba(79,163,216,0.55)";               // the water body under the surface
      ctx.beginPath(); ctx.moveTo(0, rest + ys[0]);
      for (let i = 1; i < D.n; i++) ctx.lineTo(i * dx, rest + ys[i]);
      ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = "rgba(232,229,244,0.7)"; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(0, rest + ys[0]);
      for (let i = 1; i < D.n; i++) ctx.lineTo(i * dx, rest + ys[i]);
      ctx.stroke();
      ctx.setLineDash([3, 5]); line(0, rest, W, rest, "rgba(232,229,244,0.25)"); ctx.setLineDash([]);
      for (let i = 0; i < D.n; i++)                          // the springs: brighter where they move faster
        dot(i * dx, rest + ys[i], 1.7, rgba(SUN, 0.45 + clamp(Math.abs(vs[i]) / (H * 0.6), 0, 0.55)));
      label("k " + D.tension + " · c " + D.damping + " · spread " + D.spread + " · " + D.n + " springs", W / 2, 14, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Wavesprings", "Wobblepool", "low tension, heavy spread, little damping — a kick barely dents it but the whole pool rolls together like syrup", { tension: 10, spread: 70, damping: 1.4 });

def("J", "Jetsam", "weather", "floating on that water: each body rises by how deep it sits and drives the springs under it with its own motion — buoyancy both ways (lexicon Yacht) — press to drop a crate", function (u) {
  var D = { n: 36, tension: 50, damping: 2.2, spread: 16,   // the Wavesprings surface
            level: 0.66,        // the rest surface, of H
            density: 0.45,      // 0..1: how much of a float sits under the line at rest
            push: 4,            // how hard a moving float drives the springs beneath it
            drag: 3,            // water drag on a float, per second
            count: 2,           // floats at the start: a crate, then a barrel, alternating
            size: 1,            // float size, ×
            chop: 0,            // a constant wind ripple laid on the surface, px
            dive: 4,            // seconds between the hero's leaps
            label: "a = g·(1 − depth ÷ (h·density))   spring.v += vy·push" };
  const { ctx, W, H, TAU, stage, hero, crate, dot, line, label, clamp, rand, rgba, BONE, INK } = u;
  // Wavesprings' surface again, with bodies on it. a float reads the surface
  // HEIGHT under it (between two springs); the part of it below that line is
  // its submerged depth, and BUOYANCY pushes up in proportion — the body
  // settles where the upthrust equals its weight (that ratio is density).
  // the other way round, a float moving down drives its springs down, so a
  // drop makes a wave and every bob leaves ripples. Yacht rode a wave that
  // was a formula; here the wave is ridden AND made.
  const G = H * 2.4, dx = W / (D.n - 1);
  let ys = [], vs = [], floats = [], diveClock = 0, nextKind = 0;
  for (let i = 0; i < D.n; i++) { ys.push(0); vs.push(0); }
  function add(kind, x, y) {
    const s = H * 0.11 * D.size;
    const f = { kind: kind, x: x, y: y, vy: 0, vx: 0, w: kind === "barrel" ? s * 0.8 : s, h: kind === "hero" ? H * 0.16 : s, face: 1 };
    if (floats.length >= 8) { let k = 0; while (k < floats.length && floats[k].kind === "hero") k++; floats.splice(k, 1); }
    floats.push(f);
    return f;
  }
  for (let c = 0; c < D.count; c++) add(c % 2 ? "barrel" : "crate", W * (0.2 + 0.6 * (c + 0.5) / D.count), H * 0.2);
  const heroF = add("hero", W * 0.5, H * 0.3);
  function surf(x, t) {                                    // the surface height under x, interpolated
    const q = clamp(x / dx, 0, D.n - 1.001), i = Math.floor(q), f = q - i;
    return H * D.level + ys[i] + (ys[i + 1] - ys[i]) * f + D.chop * Math.sin(x * 0.06 - t * 4);
  }
  return {
    press(x, y) { add(nextKind++ % 2 ? "barrel" : "crate", clamp(x, 10, W - 10), Math.min(y, H * D.level - 10)); },
    frame(dt, t) {
      stage({ night: 0.1 });
      diveClock += dt;
      for (let k = 0; k < floats.length; k++) {
        const f = floats[k], h = surf(f.x, t), depth = clamp(f.y - h, 0, f.h);
        let a = G;
        if (depth > 0) {
          a -= G * depth / (f.h * D.density);                // upthrust grows with depth: the whole buoyancy law
          f.vy -= f.vy * clamp(D.drag * dt, 0, 1);
          f.vx -= f.vx * clamp(D.drag * dt, 0, 1);
          const i0 = clamp(Math.floor((f.x - f.w / 2) / dx), 0, D.n - 1), i1 = clamp(Math.ceil((f.x + f.w / 2) / dx), 0, D.n - 1);
          for (let i = i0; i <= i1; i++) vs[i] += f.vy * D.push * dt;   // and the float drives the springs beneath it
        }
        f.vy += a * dt; f.y += f.vy * dt; f.x += f.vx * dt;
        if (f.y > H + f.h) { f.y = H; f.vy = 0; }
        if (f.x < f.w / 2) { f.x = f.w / 2; f.vx = Math.abs(f.vx); }
        if (f.x > W - f.w / 2) { f.x = W - f.w / 2; f.vx = -Math.abs(f.vx); }
        if (f.kind === "hero" && depth > 0 && diveClock > D.dive && Math.abs(f.vy) < H * 0.2) {   // the hero leaps out and lands again
          diveClock = 0; f.vy = -H * 1.4; f.vx = rand(-1, 1) * H * 0.5; f.face = f.vx < 0 ? -1 : 1;
        }
      }
      for (let i = 0; i < D.n; i++) {
        const yl = ys[i > 0 ? i - 1 : i], yr = ys[i < D.n - 1 ? i + 1 : i];
        vs[i] += (-D.tension * ys[i] - D.damping * vs[i] + D.spread * (yl + yr - 2 * ys[i])) * dt;
      }
      for (let i = 0; i < D.n; i++) ys[i] = clamp(ys[i] + vs[i] * dt, -H * 0.3, H * 0.3);
      for (let k = 0; k < floats.length; k++) {              // the bodies, tilted to the local slope
        const f = floats[k], sl = Math.atan2(surf(f.x + 6, t) - surf(f.x - 6, t), 12);
        if (f.kind === "hero") { hero(f.x, f.y, { face: f.face, pose: f.vy < -H * 0.1 ? "jump" : "stand", frame: t, rot: sl * 0.4 }); continue; }
        ctx.save(); ctx.translate(f.x, f.y); ctx.rotate(sl * 0.7);
        if (f.kind === "crate") crate(0, 0, f.w);
        else {
          ctx.fillStyle = "#7A5230"; ctx.fillRect(-f.w / 2, -f.h, f.w, f.h);
          ctx.fillStyle = BONE; ctx.fillRect(-f.w / 2, -f.h * 0.78, f.w, 2); ctx.fillRect(-f.w / 2, -f.h * 0.28, f.w, 2);
        }
        ctx.restore();
      }
      ctx.fillStyle = "rgba(79,163,216,0.5)";                // the water over them: what is below the line reads as submerged
      ctx.beginPath(); ctx.moveTo(0, surf(0, t));
      for (let x = 4; x <= W; x += 4) ctx.lineTo(x, surf(x, t));
      ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = "rgba(232,229,244,0.65)"; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(0, surf(0, t));
      for (let x = 4; x <= W; x += 4) ctx.lineTo(x, surf(x, t));
      ctx.stroke();
      for (let k = 0; k < floats.length; k++) {              // the depth each float reads, as a tick
        const f = floats[k], h = surf(f.x, t), depth = clamp(f.y - h, 0, f.h);
        if (depth > 0.5) line(f.x + f.w / 2 + 3, h, f.x + f.w / 2 + 3, h + depth, rgba(INK, 0.6), 1);
      }
      label("density " + D.density + " · push " + D.push + " · " + floats.length + " floats", W / 2, 14, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Jetsam", "Junkraft", "eight small floats on a choppy surface — every bob drives the springs, so the raft of junk makes its own weather", { count: 8, size: 0.5, chop: 2 });

def("W", "Waterline", "weather", "where water meets shore: a foam line that advances and retreats on a slow sine, and a wet band behind it that dries as it is left (atlas Tide) — press to push a big wave", function (u) {
  var D = { shore: 0.62,       // the slope runs from the left edge up to this fraction of W
            tide: 0.55,        // radians per second of the in-out sine
            reach: 0.3,        // how far the sine carries the edge, of the slope
            surge: 0.3,        // what a press adds to the reach
            dry: 6,            // seconds for wet sand to fade back
            cols: 48,          // wet-memory columns along the slope
            sea: "#2E7FB8", sand: "#D8C08A", wet: "#6A4A28",
            label: "edge = slope⁻¹(level(t)) · wet α = 1 − age ÷ dry" };
  const { ctx, W, H, GY, TAU, stage, hero, dot, line, label, clamp, rgba, mix, shade, INK } = u;
  // seen from the side: a beach is a SLOPE and the sea is a flat LEVEL that
  // rises and falls on a slow sine. the WATERLINE is simply where the level
  // meets the slope, so it runs up the beach and back. two things make it
  // read as surf rather than a moving rectangle: FOAM, a bright line at the
  // edge that is thickest while the water advances, and the WET BAND — every
  // column of sand remembers when it was last covered and darkens by that age,
  // drying over D.dry seconds. Tide's trick, turned on its side.
  let lastT = [], surgeAt = -99, prevR = 0.5, foam = 0;
  for (let c = 0; c < D.cols; c++) lastT.push(-99);
  const lowY = H * 0.97;
  function sandY(x) { const sx = W * D.shore; return x >= sx ? GY : lowY + (GY - lowY) * (x / sx); }
  return {
    press() { surgeAt = -1; },                            // set on the next frame's clock
    frame(dt, t) {
      if (surgeAt === -1) surgeAt = t;
      stage({ night: 0.05 });
      const sx = W * D.shore;
      const r = clamp(0.5 + D.reach * Math.sin(t * D.tide) + D.surge * Math.exp(-(t - surgeAt) * 1.4) * (t >= surgeAt ? 1 : 0), 0.05, 0.95);
      const level = lowY + (GY - lowY) * r, edge = sx * r;
      const adv = (r - prevR) / Math.max(dt, 1e-3); prevR = r;
      foam += (clamp(adv * 6, 0, 1) - foam) * clamp(dt * 3, 0, 1);   // foam blooms on the advance, lingers a moment
      ctx.fillStyle = D.sand;                                        // the beach: the slope, then the flat
      ctx.beginPath(); ctx.moveTo(0, lowY); ctx.lineTo(sx, GY); ctx.lineTo(W, GY); ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath(); ctx.fill();
      const cw = sx / D.cols;
      for (let c = 0; c < D.cols; c++) {                             // the wet memory, column by column
        const x0 = c * cw, x1 = x0 + cw;
        if (x0 + cw * 0.5 <= edge) lastT[c] = t;
        const a = clamp(1 - (t - lastT[c]) / D.dry, 0, 1) * 0.6;
        if (a <= 0) continue;
        ctx.fillStyle = rgba(D.wet, a);
        ctx.beginPath(); ctx.moveTo(x0, sandY(x0)); ctx.lineTo(x1 + 0.5, sandY(x1)); ctx.lineTo(x1 + 0.5, sandY(x1) + 7); ctx.lineTo(x0, sandY(x0) + 7); ctx.closePath(); ctx.fill();
      }
      ctx.fillStyle = rgba(D.sea, 0.78);                             // the sea: a level cut off by the slope
      ctx.beginPath(); ctx.moveTo(0, level);
      for (let x = 0; x <= edge; x += 4) ctx.lineTo(x, level + Math.sin(x * 0.08 - t * 3) * 1.2 * (1 - x / Math.max(edge, 1)));
      ctx.lineTo(edge, level); ctx.lineTo(0, lowY); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = rgba(INK, 0.25 + foam * 0.7); ctx.lineWidth = 1 + foam * 3;   // the foam line at the edge
      ctx.beginPath(); ctx.moveTo(Math.max(0, edge - W * 0.12 * (0.4 + foam)), level); ctx.lineTo(edge, level); ctx.stroke();
      for (let k = 0; k < 5; k++) dot(edge - k * 5 - 2, level - 1 + Math.sin(t * 5 + k) * 1.2, 1.2 + foam * 1.5, rgba(INK, 0.5 + foam * 0.5));
      hero(W * 0.82, GY, { face: -1, pose: "stand", frame: t });
      line(edge, level, edge, H * 0.3, rgba(INK, 0.18), 1);          // the edge's x, read off the slope
      label("level " + Math.round(r * 100) + "% · foam " + Math.round(foam * 100) + "%", edge, H * 0.28, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Waterline", "Wintersurf", "a slow grey sea that takes a long time to dry — the same slope and sine, at a colder pace", { tide: 0.25, dry: 14, sea: "#5A6E80" });

def("P", "Puddle", "weather", "flat ellipses that reflect: the flipped sprite (Wetfloor's trick, the atlas's Mirror) clipped to each puddle, sky in the rest, rain rings on top — press to toggle the rain", function (u) {
  var D = { puddles: [[0.2, 0.1, 0.11, 0.028], [0.54, 0.16, 0.16, 0.036], [0.83, 0.07, 0.08, 0.02]],   // x (of W), depth into the ground band (of H), rx (of W), ry (of H)
            rain: true,        // rings and streaks
            rate: 12,          // rain rings per second
            ringLife: 1.1,     // seconds a ring lives
            wobble: 2,         // px the reflection sways
            sheen: 0,          // 0..1: an oily rainbow over the water
            refA: 0.6,         // reflection strength
            night: 0.45,
            label: "clip(ellipse) → draw scene flipped about GY · ring r = age/life" };
  const { ctx, W, H, GY, TAU, stage, heroSprite, hero, lamp, tree, label, clamp, rand, rgba, hsl, noise2, INK, SUN } = u;
  // a puddle is a MIRROR you can only see through a hole: clip to the
  // ellipse, then draw the sprite FLIPPED about the ground line (translate
  // to 2·GY, scale y by −1 — the same flip-and-clip as the atlas's Mirror),
  // faded, with a sine sway. the sky's reflection is a lighter gradient in
  // the same clip. RAIN RINGS are ellipses that grow and fade, squashed by
  // the puddle's own aspect so they lie on the ground. the sprite comes from
  // heroSprite() so the flipped copy is one drawImage.
  let rings = [], rain = D.rain, acc = 0;
  for (let i = 0; i < 40; i++) rings.push({ p: 0, ox: 0, oy: 0, age: 9 });
  return {
    press() { rain = !rain; },
    frame(dt, t) {
      stage({ night: D.night });
      const lx = W * 0.68, hx = W * 0.5 + Math.sin(t * 0.5) * W * 0.3, face = Math.cos(t * 0.5) < 0 ? -1 : 1;
      const f = Math.floor((t * 10) % 7) * 0.1;               // the run frame, quantised so the sprite cache stays small
      tree(W * 0.12, GY, H * 0.32); lamp(lx, GY, true);
      const sp = heroSprite({ pose: "run", frame: f });
      if (rain) { acc += dt * D.rate; }
      while (acc >= 1) {                                       // a new ring in a random puddle
        acc -= 1;
        let oldest = 0; for (let i = 1; i < rings.length; i++) if (rings[i].age > rings[oldest].age) oldest = i;
        const r = rings[oldest]; r.p = Math.floor(rand(0, D.puddles.length)); r.ox = rand(-0.7, 0.7); r.oy = rand(-0.7, 0.7); r.age = 0;
      }
      for (let k = 0; k < D.puddles.length; k++) {
        const P = D.puddles[k], px = W * P[0], py = GY + H * P[1], rx = W * P[2], ry = H * P[3];
        ctx.save();
        ctx.beginPath(); ctx.ellipse(px, py, rx, ry, 0, 0, TAU); ctx.clip();
        const g = ctx.createLinearGradient(0, py - ry, 0, py + ry);     // the sky, upside down
        g.addColorStop(0, "rgba(120,150,200,0.55)"); g.addColorStop(1, "rgba(40,50,90,0.8)");
        ctx.fillStyle = g; ctx.fillRect(px - rx, py - ry, rx * 2, ry * 2);
        const sway = Math.sin(t * 3 + k) * D.wobble;
        ctx.save();
        ctx.globalAlpha = D.refA;
        ctx.translate(sway, 2 * GY); ctx.scale(1, -1);                     // the flip about the ground line
        lamp(lx, GY, true);
        ctx.translate(hx, GY); ctx.scale(face, 1);
        ctx.drawImage(sp.cv, -sp.ax, -sp.ay);
        ctx.restore();
        if (D.sheen > 0) {                                                 // petrol: hue bands from a noise field, screened on
          ctx.globalCompositeOperation = "screen";
          const bw = Math.max(3, rx / 8);
          for (let x = px - rx; x < px + rx; x += bw) {
            const n = noise2(x / (rx * 0.6) + k * 3, t * 0.15), hue = (n * 0.5 + 0.5) * 300 + t * 20;
            ctx.fillStyle = hsl(hue % 360, 0.9, 0.55, D.sheen * 0.45);
            ctx.fillRect(x, py - ry, bw + 0.5, ry * 2);
          }
          ctx.globalCompositeOperation = "source-over";
        }
        for (let i = 0; i < rings.length; i++) {                           // rings squashed by the puddle's aspect
          const r = rings[i];
          if (r.p !== k || r.age >= D.ringLife) continue;
          const q = r.age / D.ringLife, rr = q * rx * 0.45;
          ctx.strokeStyle = rgba(INK, (1 - q) * 0.7); ctx.lineWidth = 1;
          ctx.beginPath(); ctx.ellipse(px + r.ox * rx, py + r.oy * ry, Math.max(0.5, rr), Math.max(0.3, rr * ry / rx), 0, 0, TAU); ctx.stroke();
        }
        ctx.restore();
        ctx.strokeStyle = "rgba(232,229,244,0.18)"; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.ellipse(px, py, rx, ry, 0, 0, TAU); ctx.stroke();
      }
      for (let i = 0; i < rings.length; i++) rings[i].age += dt;
      hero(hx, GY, { face: face, pose: "run", frame: f });
      if (rain) {                                                          // streaks: clock-driven, so a skip costs nothing
        ctx.strokeStyle = "rgba(200,220,255,0.35)"; ctx.lineWidth = 1; ctx.beginPath();
        for (let i = 0; i < 28; i++) {
          const x = ((i * 137.5) % W + t * 30) % W, y = ((i * 71.3 + t * H * 2.2) % (H + 20)) - 10;
          ctx.moveTo(x, y); ctx.lineTo(x - 2, y + H * 0.05);
        }
        ctx.stroke();
      }
      label(rain ? "rain on · " + D.rate + " rings/s" : (D.sheen > 0 ? "no rain · oil sheen " + D.sheen : "rain off"), W / 2, 14, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Puddle", "Petrol", "no rain, a still mirror, and an oily rainbow screened over it — hue bands from a slow noise field", { rain: false, sheen: 0.7, wobble: 0.6 });

def("L", "Lens", "weather", "rain on the camera glass: drops bead, merge, and run once heavy enough, each a tiny upside-down lens on the scene behind, leaving a trail (bestiary Rain on glass) — press to wipe", function (u) {
  var D = { kind: "rain",      // "rain" | "snow": what lands on the glass
            rate: 6,           // new drops per second
            slideR: 3.2,       // a drop heavier than this runs
            slideSpeed: 14,    // run speed per unit of extra radius, px/s
            mag: 0.5,          // the lens shrink: the drop shows a wider patch of scene, flipped
            evap: 0.35,        // px of radius lost per second (the trail dries)
            melt: 2.5,         // snow: seconds a flake keeps before it becomes water
            wipeTime: 0.7,     // seconds for one wiper sweep
            label: "drop = clip(circle) · drawImage(scene, flipped, ÷mag)" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, lamp, layer, dot, line, label, clamp, rand, rgba, noise, INK } = u;
  // a raindrop on a lens is a small LENS: clip to its circle and draw the
  // scene layer through it flipped and shrunk, so each drop carries an
  // upside-down world. drops have a radius that stands in for mass: they
  // sit until they are heavier than slideR, then RUN downward, wandering on
  // noise, swallowing what they touch and shedding a trail of small beads
  // that dry (evaporate) behind them. the WIPER is a pivoting arm: anything
  // between last frame's angle and this one's is gone.
  const U = H / 170;
  let drops = [], wipe = -1, wipePrev = 0, id = 0;
  function spawn(x, y, r, flake) { if (drops.length >= 44) drops.shift(); drops.push({ x: x, y: y, r: r, flake: flake ? D.melt : 0, id: id++, tr: 0 }); }
  const pivX = () => W / 2, pivY = () => H * 1.06, armLen = () => H * 1.0;
  function angOf(x, y) { return Math.atan2(y - pivY(), x - pivX()); }
  return {
    press() { if (wipe < 0) { wipe = 0; wipePrev = -Math.PI * 0.92; } },
    frame(dt, t) {
      stage({ night: 0.25 });
      tree(W * 0.15, GY, H * 0.3); lamp(W * 0.8, GY, true);
      hero(W * 0.5 + Math.sin(t * 0.7) * W * 0.2, GY, { face: Math.cos(t * 0.7) < 0 ? -1 : 1, pose: "run", frame: t });
      if (D.kind === "snow") {                                     // falling flakes / rain streaks in the scene, clock-driven
        for (let i = 0; i < 30; i++) dot(((i * 97.3) % W + Math.sin(t + i) * 8 + W) % W, ((i * 53.7 + t * H * 0.25) % (H + 10)) - 5, 1.3 * U, "rgba(240,240,255,0.7)");
      } else {
        ctx.strokeStyle = "rgba(200,220,255,0.3)"; ctx.lineWidth = 1; ctx.beginPath();
        for (let i = 0; i < 30; i++) { const x = ((i * 137.5) % W), y = ((i * 71.3 + t * H * 2.5) % (H + 20)) - 10; ctx.moveTo(x, y); ctx.lineTo(x - 2, y + H * 0.06); }
        ctx.stroke();
      }
      const L = layer("lensScene");                                // the scene, captured once, for every drop to refract
      L.ctx.clearRect(0, 0, W, H); L.ctx.drawImage(ctx.canvas, 0, 0, W, H);
      for (let k = 0; k < D.rate * dt; k += 1) if (Math.random() < Math.min(1, D.rate * dt - k)) spawn(rand(0, W), rand(0, H), rand(1.4, 3.4) * U, D.kind === "snow");
      for (let i = drops.length - 1; i >= 0; i--) {                // physics: melt, run, wander, shed, dry
        const d = drops[i];
        if (d.flake > 0) { d.flake -= dt; continue; }
        const extra = d.r - D.slideR * U;
        if (extra > 0) {
          const v = D.slideSpeed * extra * U;
          d.y += v * dt; d.x += noise(d.y * 0.04 + d.id * 3.1) * v * 0.5 * dt;
          d.tr += v * dt;
          if (d.tr > d.r * 2.2) { d.tr = 0; spawn(d.x + rand(-1, 1), d.y - d.r, d.r * 0.32, false); d.r -= d.r * 0.04; }
        } else d.r -= D.evap * U * dt;
        if (d.r < 0.6 || d.y > H + d.r) { drops.splice(i, 1); continue; }
        for (let j = drops.length - 1; j >= 0; j--) {              // merge: the bigger swallows the smaller
          if (j === i) continue;
          const e = drops[j], dd = Math.hypot(d.x - e.x, d.y - e.y);
          if (dd < (d.r + e.r) * 0.8 && e.r <= d.r && e.flake <= 0) { d.r = Math.min(9 * U, Math.sqrt(d.r * d.r + e.r * e.r)); drops.splice(j, 1); if (j < i) i--; }
        }
      }
      if (wipe >= 0) {                                             // the wiper sweeps; drops in its sector are gone
        wipe += dt / D.wipeTime;
        const a = -Math.PI * 0.92 + Math.PI * 0.84 * clamp(wipe, 0, 1);
        for (let i = drops.length - 1; i >= 0; i--) { const q = angOf(drops[i].x, drops[i].y); if (q >= wipePrev && q <= a && Math.hypot(drops[i].x - pivX(), drops[i].y - pivY()) < armLen()) drops.splice(i, 1); }
        wipePrev = a;
        if (wipe >= 1) wipe = -1;
        ctx.fillStyle = "rgba(255,255,255,0.05)";
        ctx.beginPath(); ctx.moveTo(pivX(), pivY()); ctx.arc(pivX(), pivY(), armLen(), Math.max(a - 0.35, -Math.PI * 0.92), a); ctx.closePath(); ctx.fill();
        line(pivX(), pivY(), pivX() + Math.cos(a) * armLen(), pivY() + Math.sin(a) * armLen(), "#2B2440", 4 * U);
      }
      for (let i = 0; i < drops.length; i++) {                     // draw: each drop is a lens on the captured scene
        const d = drops[i], r = Math.max(0.6, d.r);
        if (d.flake > 0) {
          ctx.fillStyle = rgba("#F4F6FF", clamp(d.flake / D.melt, 0.3, 1));
          ctx.beginPath(); ctx.arc(d.x, d.y, r, 0, TAU); ctx.fill();
          continue;
        }
        ctx.save();
        ctx.beginPath(); ctx.arc(d.x, d.y, r, 0, TAU); ctx.clip();
        ctx.translate(d.x, d.y); ctx.scale(1, -1);
        const src = r / Math.max(0.15, D.mag);
        ctx.drawImage(L.cv, clamp(d.x - src, 0, W), clamp(d.y - src, 0, H), Math.max(1, Math.min(2 * src, W)), Math.max(1, Math.min(2 * src, H)), -r, -r, 2 * r, 2 * r);
        ctx.restore();
        ctx.strokeStyle = "rgba(255,255,255,0.35)"; ctx.lineWidth = 0.8;
        ctx.beginPath(); ctx.arc(d.x, d.y, r, -2.4, -1.0); ctx.stroke();   // a highlight arc
      }
      label(D.kind + " · " + drops.length + " drops · run above r " + D.slideR, W / 2, 14, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Lens", "Lenssnow", "flakes that land white, sit for a moment, then melt into clear beads that run — the same lens with a countdown in front of it", { kind: "snow", melt: 2.2, rate: 5 });

def("Y", "Yeti", "weather", "footprints in snow: each plant stamps a print and deepens a height field under it, so a path walked twice is darker than one walked once (Marks) — press to send the hero", function (u) {
  var D = { cols: 48, rows: 10,   // the height field over the ground band
            step: 0.28,           // how much one plant deepens a cell
            stride: 0.06,         // distance between plants, of W
            fade: 30,             // seconds a print's own outline lasts
            refill: 0,            // depth lost per second (wind filling the prints)
            surface: "snow",      // "snow" | "sand": the palette
            path: [[0.12, 0.3], [0.85, 0.3], [0.85, 0.75], [0.12, 0.75]],   // waypoints: x of W, y within the ground band
            speed: 0.22,          // of W per second
            label: "depth[c][r] += step per plant · colour = mix(surface, shade, depth)" };
  const { ctx, W, H, GY, TAU, stage, hero, ellipse, label, clamp, rgba, mix, len, rand } = u;
  // a footprint is a DECAL stamped by distance moved (Marks); the trail is a
  // HEIGHT FIELD — a coarse grid over the ground where every plant adds
  // depth, clamped at 1. the grid is painted by depth, so the first pass
  // leaves faint prints and the tenth a trodden groove; on sand the wind
  // pays it back a little every second (refill), and the trail heals. the
  // prints themselves are small ellipses that age out; the field remembers.
  let field = [], prints = [], wp = 0, acc = 0, foot = 0, hx = W * D.path[0][0], hy = 0, target = null, face = 1;
  for (let i = 0; i < D.cols * D.rows; i++) field.push(0);
  for (let i = 0; i < 90; i++) prints.push({ x: 0, y: 0, a: 0, age: 99 });
  const band = () => H - GY;
  hy = GY + band() * D.path[0][1];
  const pal = { snow: ["#F0F2FA", "#8A94B8", "#4A4470"], sand: ["#E2C98A", "#9A7A40", "#5A4020"] };
  return {
    press(x, y) { target = [clamp(x, 8, W - 8), clamp(y, GY + 4, H - 6)]; },
    frame(dt, t) {
      stage({ night: 0.1 });
      const P = pal[D.surface] || pal.snow, cw = W / D.cols, ch = band() / D.rows;
      const goal = target || [W * D.path[wp][0], GY + band() * D.path[wp][1]];
      const dx = goal[0] - hx, dy = goal[1] - hy, d = len(dx, dy), stepLen = Math.min(d, W * D.speed * dt);
      if (d < 3) { if (target) target = null; else wp = (wp + 1) % D.path.length; }
      else { hx += dx / d * stepLen; hy += dy / d * stepLen; face = dx < 0 ? -1 : 1; acc += stepLen; }
      if (acc >= W * D.stride) {                                       // a plant: stamp a print, deepen the field
        acc = 0; foot = 1 - foot;
        const nx = d > 0 ? -dy / d : 0, ny = d > 0 ? dx / d : 1, off = (foot ? 1 : -1) * 4;
        const px = hx + nx * off, py = hy + ny * off;
        let old = 0; for (let i = 1; i < prints.length; i++) if (prints[i].age > prints[old].age) old = i;
        prints[old].x = px; prints[old].y = py; prints[old].a = Math.atan2(dy, dx); prints[old].age = 0;
        const c = clamp(Math.floor(px / cw), 0, D.cols - 1), r = clamp(Math.floor((py - GY) / ch), 0, D.rows - 1);
        field[r * D.cols + c] = Math.min(1, field[r * D.cols + c] + D.step);
        const r2 = clamp(r + (foot ? 1 : -1), 0, D.rows - 1);                 // the print's edge bleeds into the next row
        field[r2 * D.cols + c] = Math.min(1, field[r2 * D.cols + c] + D.step * 0.4);
      }
      ctx.fillStyle = P[0]; ctx.fillRect(0, GY, W, band());               // the surface, then the field painted by depth
      for (let r = 0; r < D.rows; r++) for (let c = 0; c < D.cols; c++) {
        const i = r * D.cols + c;
        if (D.refill > 0) field[i] = Math.max(0, field[i] - D.refill * dt);
        if (field[i] <= 0.01) continue;
        ctx.fillStyle = rgba(P[1], field[i] * 0.75);
        ctx.fillRect(c * cw, GY + r * ch, cw + 0.5, ch + 0.5);
      }
      for (let i = 0; i < prints.length; i++) {                             // the prints: ovals along the heading
        const p = prints[i]; p.age += dt;
        const a = clamp(1 - p.age / D.fade, 0, 1) * 0.55;
        if (a <= 0) continue;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.a);
        ellipse(0, 0, 3.2, 1.8, rgba(P[2], a));
        ctx.restore();
      }
      if (D.refill > 0) {                                                  // blown sand, clock-driven
        ctx.strokeStyle = rgba(P[0], 0.5); ctx.lineWidth = 1; ctx.beginPath();
        for (let i = 0; i < 14; i++) { const x = ((i * 91.7 + t * W * 0.6) % (W + 30)) - 15, y = GY + ((i * 37.1) % band()); ctx.moveTo(x, y); ctx.lineTo(x + 12, y - 1); }
        ctx.stroke();
      }
      ctx.strokeStyle = "rgba(19,16,32,0.25)"; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(0, GY); ctx.lineTo(W, GY); ctx.stroke();
      hero(hx, hy, { face: face, pose: "run", frame: t });
      let trod = 0; for (let i = 0; i < field.length; i++) if (field[i] > 0.05) trod++;
      const g = ctx.createLinearGradient(W - 70, 0, W - 10, 0); g.addColorStop(0, P[0]); g.addColorStop(1, P[1]);   // the depth scale
      ctx.fillStyle = g; ctx.fillRect(W - 70, 8, 60, 6);
      label("0", W - 72, 22, null, "right"); label("1 trodden", W - 8, 22, null, "right");
      label(D.surface + " · " + trod + " cells marked" + (D.refill ? " · refill " + D.refill + "/s" : ""), 8, 14);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Yeti", "Yellowsand", "dune sand: the same height field, but the wind pays back a little depth every second, so old trails heal and only the walked one stays", { surface: "sand", refill: 0.12, fade: 10 });

def("Q", "Quiver", "weather", "reeds: every blade is a spring on an angle, leaning on wind noise and parting from whoever walks through, with a rustle meter (Grass) — press to walk through at x", function (u) {
  var D = { blades: 60,        // reeds across the stage
            height: 1,         // blade height, × (of 0.28 H)
            k: 40,             // angle spring stiffness
            c: 3.5,            // angle damping
            wind: 0.18,        // radians the wind leans them by
            windSpeed: 0.7,    // how fast the noise scrolls
            part: 0.9,         // radians the hero pushes a blade aside
            reach: 0.09,       // the hero's push radius, of W
            walk: 0.16,        // hero speed, of W per second
            label: "θ'' = k·(target − θ) − c·θ' · target = wind·noise + part·(away from hero)" };
  const { ctx, W, H, GY, TAU, stage, hero, line, label, clamp, rng, noise, noiseBurst, rgba, shade, GOOD, INK } = u;
  // Grass bent blades away from the body with a damped spring on an angle;
  // reeds add the WIND: the spring's target is noise(t·speed + x) scaled by
  // D.wind, so neighbours lean together in slow waves, plus a push AWAY
  // from the hero that fades with distance. the RUSTLE is the sum of every
  // blade's angular speed — a meter you can watch, and after the first press
  // a short filtered noise burst whenever it spikes (rate-limited).
  const R = rng(11), blades = [];
  for (let i = 0; i < D.blades; i++) blades.push({ x: (i + 0.5) / D.blades * W + (R() - 0.5) * 6, h: (0.7 + R() * 0.6), th: 0, w: 0, hue: R() });
  let hx = W * 0.2, dir = 1, goal = null, armed = false, cool = 0, rustle = 0;
  return {
    press(x) { armed = true; goal = clamp(x, 8, W - 8); },
    frame(dt, t) {
      stage({ night: 0.12 });
      const g = goal === null ? (dir > 0 ? W - 10 : 10) : goal;
      const dx = g - hx, sp = W * D.walk * dt;
      if (Math.abs(dx) <= sp) { hx = g; if (goal !== null) goal = null; else dir = -dir; } else hx += Math.sign(dx) * sp;
      const face = dx < 0 ? -1 : 1, reach = W * D.reach;
      let sum = 0;
      for (let i = 0; i < blades.length; i++) {
        const b = blades[i];
        let target = noise(t * D.windSpeed + b.x / W * 3) * D.wind;
        const d = b.x - hx, ad = Math.abs(d);
        if (ad < reach) target += (d < 0 ? -1 : 1) * D.part * (1 - ad / reach);    // parting: away from the body
        b.w += (D.k * (target - b.th) - D.c * b.w) * dt;                                // the spring, on an angle
        b.th += b.w * dt; b.th = clamp(b.th, -1.4, 1.4);
        sum += Math.abs(b.w);
      }
      rustle += (sum / blades.length - rustle) * clamp(dt * 8, 0, 1);
      cool -= dt;
      if (armed && rustle > 0.9 && cool <= 0) { cool = 0.45; noiseBurst({ dur: 0.22, vol: 0.07, lowpass: 3200, highpass: 700, sweepTo: 1200 }); }
      const behind = [], front = [];                                                       // reeds behind the hero, then the hero, then the rest
      for (let i = 0; i < blades.length; i++) (blades[i].x < hx - 4 ? behind : front).push(blades[i]);
      const draw = (b) => {                                                                // a tapered blade bent by θ
        const hgt = H * 0.28 * D.height * b.h, s = Math.sin(b.th), c = Math.cos(b.th);
        const tx = b.x + s * hgt, ty = GY - c * hgt, cx = b.x + s * hgt * 0.35, cy = GY - hgt * 0.55;
        ctx.fillStyle = shade(GOOD, -0.45 + b.hue * 0.3 + s * 0.2);
        ctx.beginPath(); ctx.moveTo(b.x - 2, GY); ctx.quadraticCurveTo(cx - 1, cy, tx, ty); ctx.quadraticCurveTo(cx + 1, cy, b.x + 2, GY); ctx.closePath(); ctx.fill();
      };
      for (let i = 0; i < behind.length; i++) draw(behind[i]);
      hero(hx, GY, { face: face, pose: "run", frame: t });
      for (let i = 0; i < front.length; i++) draw(front[i]);
      ctx.strokeStyle = rgba(INK, 0.3); ctx.lineWidth = 1; ctx.beginPath();                 // the wind noise, as a graph
      for (let x = 0; x <= W; x += 6) ctx.lineTo(x, H * 0.12 - noise(t * D.windSpeed + x / W * 3) * H * 0.04);
      ctx.stroke();
      label("wind", 4, H * 0.12 - 4);
      const m = clamp(rustle / 2.5, 0, 1);                                                   // the rustle meter
      ctx.fillStyle = rgba(INK, 0.15); ctx.fillRect(W - 66, 8, 58, 6);
      ctx.fillStyle = rgba(m > 0.36 ? GOOD : INK, 0.8); ctx.fillRect(W - 66, 8, 58 * m, 6);
      label("rustle", W - 8, 22, null, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Quiver", "Quillfield", "tall stiff reeds under a slow wind — a high spring constant snaps them back, so the parting is a clean V that closes behind", { height: 1.7, k: 110, windSpeed: 0.25 });

def("U", "Updraft", "weather", "wind zones: regions that carry leaves, dust and the hero, each gust an attack / sustain / release envelope drawn as a graph (lexicon Vectorfield, Conveyor) — press to gust now", function (u) {
  var D = { zones: [{ x: 0.08, y: 0.35, w: 0.5, h: 0.45, dx: 1, dy: 0 }, { x: 0.68, y: 0.05, w: 0.18, h: 0.75, dx: 0, dy: -1 }],   // fractions of W, H; a unit direction
            force: 2.2,        // peak push, in H per second²
            idle: 0.12,        // the breeze between gusts, as a fraction of force
            attack: 0.4, sustain: 1.2, release: 1.6,   // the envelope, seconds
            every: 5,          // seconds between autopilot gusts
            drag: 1.6,         // air drag on debris, per second
            leaves: 60, dust: 70,
            label: "a = zone.dir · force · env(t) − drag·v   env: A / S / R" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, arrow, dot, label, clamp, rand, rng, noise, rgba, SUN, GOOD, INK, BONE } = u;
  // a wind zone is a RECTANGLE with a direction (Vectorfield, drawn with
  // arrows). its strength is not a number but an ENVELOPE: a gust attacks
  // over A seconds, holds for S, and releases over R — the same shape a
  // synth uses for loudness. debris inside a zone accelerates along its
  // direction times the envelope, minus drag; leaves also feel gravity so
  // they settle when the gust ends, and the up-zone lifts the hero off the
  // ground while it blows. between gusts a small idle breeze keeps it alive.
  const R = rng(3), parts = [];
  for (let i = 0; i < D.leaves + D.dust; i++) parts.push({ x: R() * W, y: GY - R() * H * 0.5, vx: 0, vy: 0, leaf: i < D.leaves, s: R() });
  let gustAt = -99, clock = D.every - 1, hx = W * 0.3, hy = GY, hvy = 0, face = 1;
  function env(age) {
    if (age < 0) return 0;
    if (age < D.attack) return age / D.attack;
    if (age < D.attack + D.sustain) return 1;
    return clamp(1 - (age - D.attack - D.sustain) / D.release, 0, 1);
  }
  function inZone(z, x, y) { return x >= z.x * W && x <= (z.x + z.w) * W && y >= z.y * H && y <= (z.y + z.h) * H; }
  return {
    press() { gustAt = -1; },
    frame(dt, t) {
      if (gustAt === -1) gustAt = t;
      clock += dt; if (clock > D.every) { clock = 0; gustAt = t; }
      stage({ night: 0.1 });
      tree(W * 0.9, GY, H * 0.3);
      const e = env(t - gustAt), g = D.idle + (1 - D.idle) * e, F = H * D.force;
      for (let k = 0; k < D.zones.length; k++) {                        // the zones and their arrow fields
        const z = D.zones[k];
        ctx.fillStyle = rgba(z.dy < 0 ? GOOD : SUN, 0.06 + g * 0.08); ctx.fillRect(z.x * W, z.y * H, z.w * W, z.h * H);
        ctx.strokeStyle = rgba(INK, 0.15); ctx.lineWidth = 1; ctx.strokeRect(z.x * W, z.y * H, z.w * W, z.h * H);
        const nx = Math.max(1, Math.round(z.w * W / 34)), ny = Math.max(1, Math.round(z.h * H / 30)), al = 6 + g * 12;
        for (let i = 0; i < nx; i++) for (let j = 0; j < ny; j++) {
          const ax = z.x * W + (i + 0.5) / nx * z.w * W, ay = z.y * H + (j + 0.5) / ny * z.h * H;
          arrow(ax - z.dx * al / 2, ay - z.dy * al / 2, ax + z.dx * al / 2, ay + z.dy * al / 2, rgba(INK, 0.25 + g * 0.4));
        }
      }
      for (let i = 0; i < parts.length; i++) {                          // debris under the field
        const p = parts[i];
        let ax = 0, ay = p.leaf ? H * 0.5 : 0;
        for (let k = 0; k < D.zones.length; k++) { const z = D.zones[k]; if (inZone(z, p.x, p.y)) { ax += z.dx * F * g; ay += z.dy * F * g; } }
        ax += noise(t * 2 + p.s * 40) * H * 0.3 * g; ay += noise(t * 2 + p.s * 40 + 9) * H * 0.3 * g;
        p.vx += (ax - D.drag * p.vx) * dt; p.vy += (ay - D.drag * p.vy) * dt;
        p.x += p.vx * dt; p.y += p.vy * dt;
        if (p.y > GY) { p.y = GY; p.vy = 0; p.vx *= 0.8; }
        if (p.x > W + 6) p.x -= W + 12; else if (p.x < -6) p.x += W + 12;
        if (p.y < -10) { p.y = GY - 1; p.x = rand(0, W); p.vy = 0; }
        if (p.leaf) { ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.vx * 0.02 + p.s * 6); ctx.fillStyle = p.s < 0.5 ? "#D89A4A" : "#B8643A"; ctx.fillRect(-3, -1.5, 6, 3); ctx.restore(); }
        else dot(p.x, p.y, 1, rgba(BONE, 0.5));
      }
      let hax = 0, lift = false;                                         // the hero: pushed sideways, lifted in an up-zone
      for (let k = 0; k < D.zones.length; k++) { const z = D.zones[k]; if (inZone(z, hx, hy - H * 0.08)) { hax += z.dx * F * g; if (z.dy < 0 && e > 0.2) lift = true; } }
      hx += (W * 0.08 * face + hax * 0.25) * dt;
      if (hx > W * 0.92) { hx = W * 0.92; face = -1; } if (hx < W * 0.05) { hx = W * 0.05; face = 1; }
      hvy += (lift ? -H * 1.6 * e : H * 2.2) * dt; hvy *= 0.96;
      hy = clamp(hy + hvy * dt, H * 0.15, GY); if (hy >= GY) hvy = Math.min(hvy, 0);
      hero(hx, hy, { face: face, pose: hy < GY - 2 ? "jump" : "run", frame: t });
      const gx = W - 78, gy = 8, gw = 70, gh = 26, total = D.attack + D.sustain + D.release;   // the envelope, with a playhead
      ctx.fillStyle = "rgba(19,16,32,0.55)"; ctx.fillRect(gx, gy, gw, gh);
      ctx.strokeStyle = rgba(SUN, 0.9); ctx.lineWidth = 1.2; ctx.beginPath();
      ctx.moveTo(gx, gy + gh); ctx.lineTo(gx + gw * D.attack / total, gy + 2); ctx.lineTo(gx + gw * (D.attack + D.sustain) / total, gy + 2); ctx.lineTo(gx + gw, gy + gh); ctx.stroke();
      const age = t - gustAt;
      if (age >= 0 && age <= total) { const px = gx + gw * age / total; ctx.strokeStyle = INK; ctx.beginPath(); ctx.moveTo(px, gy); ctx.lineTo(px, gy + gh); ctx.stroke(); }
      label("A " + D.attack + " S " + D.sustain + " R " + D.release, gx + gw, gy + gh + 11, null, "right");
      label("gust " + Math.round(e * 100) + "%", 8, 14);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Updraft", "Upwell", "one tall column blowing straight up — leaves rise, hang while the envelope holds, and rain back down on the release", { zones: [{ x: 0.36, y: 0.02, w: 0.28, h: 0.78, dx: 0, dy: -1 }], force: 3, sustain: 2 });

def("Y", "Year", "weather", "seasons on one clock: buds, green, a turn to red and a fall, snow that settles and melts — every leaf reads the same phase (atlas Nightfall) — press to advance the season", function (u) {
  var D = { year: 20,          // seconds per year
            leaves: 56,        // leaves in the canopy
            snow: 1,           // snowfall density, ×
            fallDur: 0.08,     // of the year a leaf spends falling
            label: "p = (t ÷ year) mod 1 → colour(p), fallen(p), snow(p): one clock, every state" };
  const { ctx, W, H, GY, TAU, stage, hero, dot, line, ellipse, label, clamp, rng, mix, rgba, ease, GOOD, HOT, SUN, INK } = u;
  // Nightfall turned one clock into five palettes; a YEAR is the same idea
  // with more states. the phase p runs 0..1 and every leaf is a pure
  // function of it: size grows in spring, colour turns from green toward
  // red as autumn passes the leaf's own turn time, then from its fallAt it
  // slides to the ground on a sway, and lies there as litter. snow is a
  // second function of p — settling through winter, melting in the first
  // weeks of spring. nothing is remembered, so a skip costs nothing.
  const R = rng(21), leaves = [], tx = W * 0.32, cr = H * 0.2;
  for (let i = 0; i < D.leaves; i++) {
    const a = R() * TAU, r = Math.sqrt(R()) * cr;
    leaves.push({ ox: Math.cos(a) * r * 1.15, oy: Math.sin(a) * r * 0.8 - cr * 0.1, turn: 0.5 + R() * 0.12, fallAt: 0.58 + R() * 0.16, hue: R(), landX: (R() - 0.5) * cr * 3, ph: R() * TAU });
  }
  let shift = 0, lastT = 0;
  const names = ["spring", "summer", "autumn", "winter"];
  return {
    press() { const p = ((lastT / D.year + shift) % 1 + 1) % 1; shift += 0.25 - (p % 0.25) + 0.002; },   // snap to the next quarter
    frame(dt, t) {
      lastT = t;
      const p = ((t / D.year + shift) % 1 + 1) % 1;
      const snow = p > 0.75 ? ease((p - 0.75) / 0.14) : (p < 0.09 ? ease(1 - p / 0.09) : 0);   // settles late, melts early
      const cold = p > 0.7 ? ease((p - 0.7) / 0.1) : (p < 0.1 ? ease(1 - p / 0.1) : 0);
      stage({ night: 0.08 + cold * 0.22 });
      ctx.fillStyle = rgba("#F0F2FA", snow * 0.92); ctx.fillRect(0, GY, W, H - GY);          // snow on the ground
      ctx.fillStyle = "#5A3E2B";                                                              // trunk and three branches
      ctx.fillRect(tx - cr * 0.09, GY - cr * 1.3, cr * 0.18, cr * 1.3);
      line(tx, GY - cr * 1.1, tx - cr * 0.7, GY - cr * 1.7, "#5A3E2B", 3); line(tx, GY - cr * 1.2, tx + cr * 0.75, GY - cr * 1.75, "#5A3E2B", 3); line(tx, GY - cr * 1.3, tx, GY - cr * 2.1, "#5A3E2B", 3);
      const cy = GY - cr * 1.7;
      for (let i = 0; i < leaves.length; i++) {
        const L = leaves[i];
        const size = p < 0.2 ? ease(p / 0.2) : 1;                                              // buds grow through spring
        const turn = clamp((p - L.turn) / 0.14, 0, 1);                                         // green → orange → red
        const colr = turn < 0.5 ? mix(GOOD, SUN, turn * 2) : mix(SUN, HOT, (turn - 0.5) * 2);
        const q = clamp((p - L.fallAt) / D.fallDur, 0, 1);                                     // falling: canopy → ground
        if (p < 0.02 && q > 0) continue;
        const sx = tx + L.ox + Math.sin(q * 6 + L.ph) * 8 * q * (1 - q) * 4 + L.landX * q;
        const sy = cy + L.oy + (GY - 2 - (cy + L.oy)) * ease(q);
        const litter = q >= 1;
        if (litter && p < 0.4) continue;                                                       // last year's litter is gone by mid-spring
        const a = litter ? clamp(1 - snow * 1.2, 0, 1) * 0.8 : 1;
        if (a <= 0) continue;
        const rr = (2.2 + L.hue * 1.6) * size * (H / 170);
        ellipse(sx, sy, rr, rr * (litter ? 0.5 : 0.8), rgba(p < 0.2 ? mix("#9BE28A", "#E2F5A0", 0.4) : colr, a));
      }
      if (snow > 0.05) {                                                                        // snow caps on the branches
        ctx.strokeStyle = rgba("#F0F2FA", snow); ctx.lineWidth = 3 * snow; ctx.lineCap = "round";
        ctx.beginPath(); ctx.moveTo(tx - cr * 0.7, GY - cr * 1.72); ctx.lineTo(tx, GY - cr * 1.14); ctx.moveTo(tx, GY - cr * 1.24); ctx.lineTo(tx + cr * 0.75, GY - cr * 1.79); ctx.stroke();
        ctx.lineCap = "butt";
      }
      if (p > 0.76 || p < 0.03) {                                                               // falling flakes, clock-driven
        const n = Math.round(30 * D.snow);
        for (let i = 0; i < n; i++) dot(((i * 97.3) % W + Math.sin(t + i) * 10 + W) % W, ((i * 53.7 + t * H * 0.2) % (H + 10)) - 5, 1.3, "rgba(240,242,250,0.8)");
      }
      hero(W * 0.7, GY, { face: -1, pose: "stand", frame: t });
      const rx = W - 26, ry = 26, rr = 16;                                                      // the year ring
      const cols = ["#9BE28A", "#F5C169", "#F58A5A", "#C9C4E4"];
      for (let s = 0; s < 4; s++) { ctx.strokeStyle = rgba(cols[s], 0.7); ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(rx, ry, rr, -Math.PI / 2 + s * Math.PI / 2, -Math.PI / 2 + (s + 1) * Math.PI / 2 - 0.05); ctx.stroke(); }
      line(rx, ry, rx + Math.cos(p * TAU - Math.PI / 2) * rr, ry + Math.sin(p * TAU - Math.PI / 2) * rr, INK, 1.5);
      label(names[Math.floor(p * 4) % 4] + " · " + Math.round(p * 100) + "%", rx, ry + rr + 12, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Year", "Yearfast", "a six-second year, thick snow — the same clock spun fast enough to watch the whole cycle in one breath", { year: 6, snow: 2.5, fallDur: 0.12 });

def("U", "Unfurl", "weather", "plant growth: a seed → sprout → bloom timeline, and beside it an L-system fern that grows branch by branch from a rule string (lexicon Vine, folio Mushroom) — press to replant", function (u) {
  var D = { rule: "F[+F]F[-F]F",   // the rewrite for every F
            depth: 4,              // rewrites (capped at 5)
            angle: 25,             // degrees per + or −
            speed: 1,              // growth speed, ×
            grow: 9,               // seconds for the fern to finish
            stages: [1.5, 3.5, 6], // seconds: sprout, leaves, bloom
            plants: 1,             // ferns
            label: "F → rule, depth times · turtle: F draws, ± turns, [ ] branches · revealed = progress · total" };
  const { ctx, W, H, GY, TAU, stage, dot, line, label, clamp, rng, rgba, mix, ease, GOOD, SUN, HOT, INK } = u;
  // an L-SYSTEM is a string that rewrites itself: every F becomes the rule,
  // depth times, and a turtle reads the result — F draws, + and − turn by
  // the angle, [ saves the turtle and ] restores it (that is a branch). the
  // string is expanded once; the turtle's segments are stored in order and
  // REVEALED as the clock advances, so the fern grows the way it was written,
  // one branch at a time. the pot plant beside it is the plain version:
  // three stages on a timer, each a tween. press replants both.
  let segs = [], total = 0, born = 0, seed = 1, jit = [];
  function build() {
    const depth = clamp(Math.round(D.depth), 1, 5);
    let s = "F";
    for (let d = 0; d < depth; d++) { let out = ""; for (let i = 0; i < s.length; i++) out += s[i] === "F" ? D.rule : s[i]; s = out; }
    segs = []; const R = rng(seed);
    const stack = []; let x = 0, y = 0, a = -Math.PI / 2, lv = 0;
    for (let i = 0; i < s.length; i++) {
      const ch = s[i];
      if (ch === "F") { const nx = x + Math.cos(a), ny = y + Math.sin(a); segs.push([x, y, nx, ny, lv]); x = nx; y = ny; }
      else if (ch === "+") a += (D.angle + (R() - 0.5) * 6) * Math.PI / 180;
      else if (ch === "-") a -= (D.angle + (R() - 0.5) * 6) * Math.PI / 180;
      else if (ch === "[") { stack.push([x, y, a, lv]); lv++; if (stack.length > 64) break; }
      else if (ch === "]" && stack.length) { const st = stack.pop(); x = st[0]; y = st[1]; a = st[2]; lv = st[3]; }
    }
    total = segs.length;
    let maxY = 0; for (let i = 0; i < segs.length; i++) if (-segs[i][3] > maxY) maxY = -segs[i][3];
    born = Math.max(1, maxY);
  }
  build();
  let t0 = 0, lastT = 0;
  return {
    press() { seed = (seed * 7 + 3) % 1000; t0 = lastT; build(); },
    frame(dt, t) {
      lastT = t;
      stage({ night: 0.05 });
      const age = (t - t0) * D.speed;
      const scale = H * 0.72 / born;
      for (let k = 0; k < D.plants; k++) {                                            // the fern(s): segments revealed in order
        const bx = W * (D.plants === 1 ? 0.66 : 0.4 + 0.5 * k / (D.plants - 1)), prog = clamp(age / D.grow, 0, 1);
        const n = Math.floor(prog * total), frac = prog * total - n;
        ctx.lineCap = "round";
        for (let i = 0; i < Math.min(n + 1, total); i++) {
          const s = segs[i], f = i < n ? 1 : frac;
          ctx.strokeStyle = mix("#3E7A48", GOOD, s[4] / 4); ctx.lineWidth = Math.max(0.8, 3 - s[4] * 0.6);
          ctx.beginPath(); ctx.moveTo(bx + s[0] * scale, GY + s[1] * scale); ctx.lineTo(bx + (s[0] + (s[2] - s[0]) * f) * scale, GY + (s[1] + (s[3] - s[1]) * f) * scale); ctx.stroke();
        }
        ctx.lineCap = "butt";
        if (n < total) dot(bx + segs[n][0] * scale, GY + segs[n][1] * scale, 2, SUN);       // the growing tip
      }
      const px = W * 0.22, S = D.stages;                                                 // the pot plant: three tweens
      ctx.fillStyle = "#7A5230"; ctx.fillRect(px - 14, GY - 16, 28, 16); ctx.fillStyle = "#3A2A20"; ctx.fillRect(px - 12, GY - 16, 24, 4);
      const s1 = ease(age / S[0]), s2 = ease((age - S[0]) / (S[1] - S[0])), s3 = ease((age - S[1]) / (S[2] - S[1]));
      const stemH = H * 0.2 * s1 + H * 0.12 * s2;
      dot(px, GY - 14, 3 * (1 - s1) + 1, "#9A7A40");
      line(px, GY - 14, px, GY - 14 - stemH, "#3E7A48", 2.5);
      for (let k = 0; k < 2; k++) {                                                      // two leaves unfold in stage two
        const ly = GY - 14 - stemH * 0.55, dir = k ? 1 : -1, ll = 14 * s2;
        ctx.fillStyle = GOOD; ctx.beginPath(); ctx.ellipse(px + dir * ll * 0.6, ly, Math.max(0.1, ll * 0.6), Math.max(0.1, 4 * s2), dir * 0.5, 0, TAU); ctx.fill();
      }
      for (let k = 0; k < 6; k++) {                                                      // the bloom: petals scale in stage three
        const a = k / 6 * TAU + t * 0.2, pr = 7 * s3;
        dot(px + Math.cos(a) * pr, GY - 14 - stemH + Math.sin(a) * pr, Math.max(0.1, 4 * s3), HOT);
      }
      dot(px, GY - 14 - stemH, 3 * s3 + 0.1, SUN);
      const stage_ = age < S[0] ? "seed" : age < S[1] ? "sprout" : age < S[2] ? "leaves" : "bloom";
      const bw = W * 0.3, bx0 = px - bw / 2, by0 = H * 0.1;                                // the stage bar
      ctx.fillStyle = rgba(INK, 0.12); ctx.fillRect(bx0, by0, bw, 5);
      ctx.fillStyle = rgba(SUN, 0.8); ctx.fillRect(bx0, by0, bw * clamp(age / S[2], 0, 1), 5);
      for (let k = 0; k < S.length; k++) line(bx0 + bw * S[k] / S[2], by0 - 2, bx0 + bw * S[k] / S[2], by0 + 7, rgba(INK, 0.5), 1);
      label(stage_ + " · " + age.toFixed(1) + " s", px, by0 + 18, null, "center");
      label("F → " + D.rule + " · θ " + D.angle + "° · depth " + clamp(Math.round(D.depth), 1, 5) + " · " + Math.min(total, Math.floor(clamp(age / D.grow, 0, 1) * total)) + "/" + total, W * 0.66, H * 0.1 + 4, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Unfurl", "Undergrowth", "three ferns from the same rule at a wider angle and twice the speed — the string is identical, the turtle turns harder", { plants: 3, speed: 2, angle: 38 });

def("K", "Kindle", "weather", "wildfire on a grid: burning cells ignite neighbours with a probability the wind tilts, burn for a while, leave ash that regrows (atlas Wildfire) — press to ignite at your click", function (u) {
  var D = { cols: 40, rows: 14,   // the meadow grid
            spread: 0.32,         // chance per tick that a burning cell lights a neighbour
            tick: 0.14,           // seconds per simulation step
            burn: 1.6,            // seconds a cell burns
            ash: true,            // leave ash (else the ground shows straight through)
            regrow: 9,            // seconds until ash is grass again
            wind: 0.55,           // 0..1: how much the wind tilts the odds
            windDir: 0,           // degrees, 0 = blowing to the right
            every: 4,             // seconds of quiet before the autopilot strikes a match
            label: "p(n) = spread · (1 + wind · dir·n̂)   burn → ash → grass" };
  const { ctx, W, H, GY, TAU, stage, arrow, label, clamp, rng, rand, rgba, mix, noise2, FIRE, SPARK, GOOD, INK } = u;
  // a CELLULAR grid: every cell is grass, burning (with a timer) or ash.
  // each tick, a burning cell rolls a die for each of its four neighbours
  // — the chance is D.spread, multiplied up for the neighbour downwind and
  // down for the one upwind (the dot product of the wind and the direction
  // to it). fire burns out after D.burn seconds and leaves ash that regrows,
  // so the field never runs out. the odds table is drawn beside the wind.
  const N = D.cols * D.rows, st = [], tm = [], hue = [];
  const R = rng(5);
  for (let i = 0; i < N; i++) { st.push(0); tm.push(0); hue.push(R()); }
  let acc = 0, quiet = 0;
  const y0 = () => GY - H * 0.22;
  function ignite(c, r) { if (c < 0 || r < 0 || c >= D.cols || r >= D.rows) return; const i = r * D.cols + c; if (st[i] === 0) { st[i] = 1; tm[i] = D.burn; } }
  const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  function step() {
    const wx = Math.cos(D.windDir * Math.PI / 180), wy = Math.sin(D.windDir * Math.PI / 180);
    const lit = [];
    for (let i = 0; i < N; i++) if (st[i] === 1) lit.push(i);
    for (let k = 0; k < lit.length; k++) {
      const i = lit[k], c = i % D.cols, r = (i - c) / D.cols;
      for (let d = 0; d < 4; d++) {
        const p = D.spread * clamp(1 + D.wind * (dirs[d][0] * wx + dirs[d][1] * wy), 0, 2);
        if (Math.random() < p) ignite(c + dirs[d][0], r + dirs[d][1]);
      }
    }
  }
  return {
    press(x, y) { const cw = W / D.cols, ch = (H - y0()) / D.rows; ignite(Math.floor(x / cw), Math.floor((y - y0()) / ch)); },
    frame(dt, t) {
      stage({ night: 0.2 });
      const cw = W / D.cols, ch = (H - y0()) / D.rows, top = y0();
      acc += dt;
      let loops = 0;
      while (acc >= D.tick && loops++ < 4) { acc -= D.tick; step(); }
      let burning = 0;
      for (let i = 0; i < N; i++) {                                    // timers: burning → ash → grass
        if (st[i] === 1) { burning++; tm[i] -= dt; if (tm[i] <= 0) { st[i] = D.ash ? 2 : 0; tm[i] = D.regrow; } }
        else if (st[i] === 2) { tm[i] -= dt; if (tm[i] <= 0) st[i] = 0; }
      }
      quiet = burning ? 0 : quiet + dt;
      if (quiet > D.every) { quiet = 0; ignite(Math.floor(rand(0, D.cols)), Math.floor(rand(0, D.rows))); }
      for (let r = 0; r < D.rows; r++) for (let c = 0; c < D.cols; c++) {   // paint the grid by state
        const i = r * D.cols + c, x = c * cw, y = top + r * ch;
        if (st[i] === 0) ctx.fillStyle = mix("#4E8A3E", GOOD, hue[i] * 0.35);
        else if (st[i] === 1) { const f = tm[i] / D.burn; ctx.fillStyle = mix(FIRE, SPARK, 0.5 + 0.5 * Math.sin(t * 17 + hue[i] * 30)); ctx.fillRect(x, y, cw + 0.5, ch + 0.5); ctx.fillStyle = rgba("#2A1A10", 1 - f); }
        else { const f = tm[i] / D.regrow; ctx.fillStyle = mix("#4E8A3E", "#3A3A3E", clamp(f * 1.4, 0, 1)); }
        ctx.fillRect(x, y, cw + 0.5, ch + 0.5);
        if (st[i] === 1) { ctx.fillStyle = rgba(SPARK, 0.8); const fh = ch * (0.6 + 0.4 * Math.sin(t * 23 + hue[i] * 50)); ctx.beginPath(); ctx.moveTo(x + cw * 0.2, y + ch); ctx.lineTo(x + cw * 0.5, y + ch - fh); ctx.lineTo(x + cw * 0.8, y + ch); ctx.closePath(); ctx.fill(); }
      }
      const wx = Math.cos(D.windDir * Math.PI / 180), wy = Math.sin(D.windDir * Math.PI / 180), ax = W - 30, ay = 22;   // the wind and its odds
      arrow(ax - wx * 14, ay - wy * 14, ax + wx * 14, ay + wy * 14, INK);
      label("wind " + D.wind, ax, ay + 20, null, "center");
      label("p→ " + (D.spread * (1 + D.wind)).toFixed(2) + " · p← " + (D.spread * (1 - D.wind)).toFixed(2) + " · p↕ " + D.spread.toFixed(2), 8, 14);
      label(burning + " burning · burn " + D.burn + " s" + (D.ash ? " · ash " + D.regrow + " s" : " · no ash"), 8, 27);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Kindle", "Kilnwind", "a gale: the odds downwind nearly double and upwind nearly vanish, cells burn out in half a second and leave no ash — a fire that runs, not one that smoulders", { wind: 0.9, burn: 0.5, ash: false });

def("L", "Lava", "weather", "lava on a grid: a slow flow down the slope, a crust that darkens wherever it stops moving (age → colour), heat haze in strips above, embers (the atlas's Lava sea) — press to pour at your click", function (u) {
  var D = { cols: 40, rows: 12,   // the rock field
            flow: 0.35,           // fraction of a height difference that moves per tick
            tick: 0.1,            // seconds per flow step
            crust: 4,             // seconds still before a cell crusts over
            cool: 10,             // seconds after crusting until it is dark rock and gone
            slope: 1.4,           // terrain drop across the width, in lava units
            channel: 0,           // 0..1: how deep a trench runs across the middle
            pour: 1.2,            // lava units per pour
            every: 1.5,           // seconds between the vent's pours
            label: "Δ = flow · (h+a − hₙ−aₙ)   colour = f(still age) → crust" };
  const { ctx, W, H, GY, TAU, stage, layer, dot, label, clamp, rng, rand, rgba, mix, noise, noise2, SPARK, FIRE, INK } = u;
  // a HEIGHT-FIELD FLOW: every cell has terrain height h and lava amount a;
  // each tick, lava moves from a cell to lower neighbours by a fraction of
  // the surface difference (h + a). a cell's STILL AGE counts up while
  // nothing moves through it, and the colour is a function of that age —
  // yellow when moving, red as it slows, black CRUST once it passes D.crust,
  // and after D.cool it is rock and leaves the simulation. crusted cells no
  // longer flow, so new lava runs around them — the tube. the HEAT HAZE is
  // the band above the field copied out in strips and pushed by noise.
  const N = D.cols * D.rows, h = [], a = [], age = [], da = [], rock = [], R = rng(9);
  for (let i = 0; i < N; i++) {
    const c = i % D.cols, r = (i - c) / D.cols;
    const trench = D.channel * 3 * Math.exp(-Math.pow((r - D.rows * 0.5) / 1.6, 2));
    h.push(-D.slope * c / D.cols + noise2(c * 0.35, r * 0.35 + 7) * 0.25 - trench);
    a.push(0); age.push(0); da.push(0);
    rock.push(rgba("#000000", 0.25 * clamp(-h[i] / (D.slope + 3), 0, 1) + 0.1 * (noise2(c * 0.7, r * 0.7) * 0.5 + 0.5)));   // the rock shade never changes: build it once
  }
  const embers = [];
  for (let i = 0; i < 40; i++) embers.push({ x: 0, y: 0, vy: 0, life: 0 });
  let acc = 0, vent = 0;
  const y0 = () => GY - H * 0.2;
  function addAt(c, r, amt) { if (c < 0 || r < 0 || c >= D.cols || r >= D.rows) return; const i = r * D.cols + c; if (age[i] < D.crust) { a[i] += amt; age[i] = 0; } }
  function step() {
    for (let i = 0; i < N; i++) da[i] = 0;
    for (let i = 0; i < N; i++) {
      if (a[i] < 0.02 || age[i] >= D.crust) continue;
      const c = i % D.cols, r = (i - c) / D.cols, hs = h[i] + a[i];
      let out = 0;
      const nb = [c > 0 ? i - 1 : -1, c < D.cols - 1 ? i + 1 : -1, r > 0 ? i - D.cols : -1, r < D.rows - 1 ? i + D.cols : -1];
      for (let k = 0; k < 4; k++) {
        const j = nb[k]; if (j < 0 || age[j] >= D.crust) continue;
        const diff = hs - (h[j] + a[j]);
        if (diff <= 0) continue;
        const m = Math.min(D.flow * diff * 0.25, a[i] * 0.24);
        da[j] += m; out += m;
      }
      da[i] -= out;
    }
    for (let i = 0; i < N; i++) {
      if (Math.abs(da[i]) > 0.004) age[i] = 0;
      a[i] = Math.max(0, a[i] + da[i]);
    }
  }
  return {
    press(x, y) { const cw = W / D.cols, ch = (H - y0()) / D.rows; addAt(Math.floor(x / cw), Math.floor((y - y0()) / ch), D.pour); },
    frame(dt, t) {
      stage({ night: 0.6 });
      const top = y0(), cw = W / D.cols, ch = (H - top) / D.rows;
      vent += dt; if (vent > D.every) { vent = 0; addAt(1, Math.floor(D.rows * 0.5), D.pour); }
      acc += dt; let loops = 0;
      while (acc >= D.tick && loops++ < 4) { acc -= D.tick; step(); }
      let hot = 0;
      ctx.fillStyle = "#1E1A2A"; ctx.fillRect(0, top, W, H - top);
      for (let i = 0; i < N; i++) {
        const c = i % D.cols, r = (i - c) / D.cols, x = c * cw, y = top + r * ch;
        ctx.fillStyle = rock[i];                                                     // the rock, darker downhill
        ctx.fillRect(x, y, cw + 0.5, ch + 0.5);
        if (a[i] < 0.02) continue;
        age[i] += dt;
        if (age[i] > D.crust + D.cool) { a[i] = 0; age[i] = 0; continue; }          // cold rock: out of the simulation
        const q = clamp(age[i] / D.crust, 0, 1), cool = clamp((age[i] - D.crust) / D.cool, 0, 1);
        if (q < 0.5) hot++;
        let colr = q < 0.4 ? mix(SPARK, FIRE, q / 0.4) : q < 1 ? mix(FIRE, "#7A1A10", (q - 0.4) / 0.6) : mix("#7A1A10", "#2A1E22", cool);
        ctx.fillStyle = rgba(colr, clamp(0.5 + a[i] * 0.6, 0, 1));
        ctx.fillRect(x, y, cw + 0.5, ch + 0.5);
        if (q < 0.4 && Math.random() < 0.02) { const e = embers[Math.floor(rand(0, embers.length))]; if (e.life <= 0) { e.x = x + cw / 2; e.y = y; e.vy = -H * rand(0.15, 0.35); e.life = 1; } }
      }
      for (let i = 0; i < embers.length; i++) {
        const e = embers[i]; if (e.life <= 0) continue;
        e.life -= dt * 0.8; e.y += e.vy * dt; e.x += noise(e.y * 0.05 + i) * 20 * dt;
        dot(e.x, e.y, 1.2, rgba(SPARK, clamp(e.life, 0, 1)));
      }
      const heat = clamp(hot / (N * 0.06), 0, 1);                                     // the haze: strips of the band above, pushed by noise
      if (heat > 0.02) {
        const L = layer("lavaHaze"), hy = top - H * 0.16, hh = H * 0.2;
        L.ctx.clearRect(0, 0, W, H); L.ctx.drawImage(ctx.canvas, 0, 0, W, H);
        for (let y = hy; y < hy + hh; y += 3) {
          const k = (y - hy) / hh, off = noise(y * 0.08 + t * 3.5) * 4 * heat * k;
          ctx.drawImage(L.cv, 0, y, W, 3, off, y, W, 3);
        }
      }
      label(hot + " cells moving · crust after " + D.crust + " s · flow " + D.flow, 8, 14);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Lava", "Lavatube", "a deep trench across the field: fast flow, quick crust — the lava runs down the channel and roofs itself over into a tube", { channel: 1, flow: 0.8, crust: 1.2 });

def("C", "Cloudshadow", "weather", "cloud shadows: a scrolling noise mask multiplied over the ground, with clouds drawn overhead from the same field (ch04 noise) — press to send the wind toward your click", function (u) {
  var D = { scale: 0.9,        // noise feature size, of W
            speed: 0.06,       // scroll speed, of W per second
            threshold: 0.15,   // noise above this is cloud
            soft: 0.35,        // the width of the mask's edge (0 = hard)
            dark: 0.45,        // shadow strength
            cols: 36, rows: 7, // the ground mask grid
            label: "shadow α = smoothstep(thr, thr+soft, noise2(x+wind·t, y)) · dark" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, crate, arrow, label, clamp, noise2, rgba, INK } = u;
  // the cheapest outdoors cue there is: a NOISE FIELD scrolled by the wind,
  // thresholded into blobs, MULTIPLIED over the ground as darkness. the
  // clouds above are the same field sampled along a band of the sky, so
  // their shapes and the shadows drifting under them agree. the mask is a
  // coarse grid of rectangles — a few hundred alpha fills — and it darkens
  // the hero and props too, because it is drawn after them. press turns the
  // wind vector toward the click; both layers turn together.
  let ox = 0, oy = 0, wx = 1, wy = 0.25;
  const shades = [];                                                                 // the mask quantised to 16 alphas, built once
  for (let i = 0; i <= 16; i++) shades.push(rgba("#0A0A1E", i / 16 * D.dark));
  function mask(nx, ny) {                                                            // one octave of value noise, thresholded: the whole mask
    const n = noise2(nx, ny);
    return D.soft <= 0 ? (n > D.threshold ? 1 : 0) : clamp((n - D.threshold) / D.soft, 0, 1);
  }
  return {
    press(x, y) { const dx = x - W / 2, dy = y - H / 2, d = Math.hypot(dx, dy) || 1; wx = dx / d; wy = dy / d * 0.4; },
    frame(dt, t) {
      ox += wx * D.speed * dt * W / (D.scale * W); oy += wy * D.speed * dt * W / (D.scale * W);
      stage({ night: 0.05 });
      const s = D.scale * W;
      for (let i = 0; i < 26; i++) {                                                   // clouds: the field sampled along the sky band
        const cx = (i + 0.5) / 26 * W, ny = 0.5;
        for (let j = 0; j < 3; j++) {
          const m = mask(cx / s + ox, ny + j * 0.15 + oy);
          if (m <= 0.05) continue;
          ctx.fillStyle = rgba("#F4F4FF", 0.35 + m * 0.5);
          ctx.beginPath(); ctx.arc(cx, H * (0.12 + j * 0.05), (6 + m * 9) * (H / 170), 0, TAU); ctx.fill();
        }
      }
      tree(W * 0.15, GY, H * 0.3); crate(W * 0.78, GY, H * 0.11);
      hero(W * 0.5 + Math.sin(t * 0.5) * W * 0.2, GY, { face: Math.cos(t * 0.5) < 0 ? -1 : 1, pose: "run", frame: t });
      const cw = W / D.cols, top = GY - H * 0.16, ch = (H - top) / D.rows;                // the mask over the ground band (and the hero's feet)
      for (let r = 0; r < D.rows; r++) for (let c = 0; c < D.cols; c++) {
        const x = c * cw, y = top + r * ch;
        const m = mask(x / s + ox, 0.5 + (r / D.rows) * 0.45 + oy);
        if (m <= 0.02) continue;
        ctx.fillStyle = shades[Math.round(m * 16)];
        ctx.fillRect(x, y, cw + 0.5, ch + 0.5);
      }
      arrow(W - 40, 22, W - 40 + wx * 22, 22 + wy * 22 / 0.4 * 0.6, INK);
      label("wind", W - 40, 40, null, "center");
      label("thr " + D.threshold + " · soft " + D.soft + " · dark " + D.dark, 8, 14);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Cloudshadow", "Cumulus", "big slow clouds with hard-edged shadows — the same field at twice the scale, thresholded with no soft edge", { scale: 2.2, speed: 0.035, soft: 0 });
/* ============================== PARTICLE MECHANICS ==============================
   The machinery under every effect. Chapter 06's Sparks taught the four
   lines of particle physics and Waterdrops made a particle's death an
   event; this family is everything that grows around those lines once a
   game has a hundred effects at once: pools and free lists (never allocate
   in the loop), emitters that read a sprite's own pixels, particles that
   collide and pile up, particles that emit particles, force lists, shape
   emitters, depth sorting and soft edges, Voronoi shatter, branching
   cracks, sword ribbons, timelines as data, world-versus-screen layers,
   and the budget that decides who gets to exist. Every card draws the
   mechanism beside the pretty part: the slot grid, the emitter tree, the
   force chips, the playhead, the priority table. */

def("P", "Pool", "particles", "OBJECT POOLING: N particles made once, lent out by a free list — the slot grid lights while they live, allocations stay 0 — press to burst there", function (u) {
  var D = { size: 64,          // particles made once, at the start
            burst: 20,         // particles asked for per burst
            every: 1.5,        // seconds between autopilot bursts
            gravity: 1.3,      // ×H per second²
            life: 1.1,         // seconds a particle lives
            speed: 0.55,       // burst speed, ×H per second
            steal: false,      // when the free list is empty: false = refuse, true = evict the oldest
            label: "spawn: i = free.pop() · die: free.push(i) · allocations: 0" };
  const { ctx, W, H, GY, TAU, stage, dot, ring, rect, label, rand, SPARK, HOT, GOOD, BONE } = u;
  // a POOL is a box of N particles made ONCE. a FREE LIST — a stack of the idle
  // slots' indices — hands out a slot on spawn (free.pop()) and takes it back
  // when the particle dies (free.push(i)). nothing is created after the first
  // frame, so the garbage collector never has a reason to stall the game. the
  // naive version — new Particle() per spawn — counts up forever in red; the
  // pool's counter stays at zero. when the free list runs dry the honest move
  // is to REFUSE the spawn, or, with steal on, to evict the oldest and reuse it.
  const P = [], free = [];
  for (let i = 0; i < D.size; i++) { P.push({ x: 0, y: 0, vx: 0, vy: 0, age: 0, life: 1, born: 0, on: false }); free.push(i); }
  let naive = 0, refused = 0, stolen = 0, clock = 0, spawnT = 0, lastX = W * 0.4, lastY = H * 0.5, flash = 0;
  function spawn(x, y) {
    naive++;                                           // what new Particle() would have cost
    let i;
    if (free.length) i = free.pop();                   // the whole trick
    else if (D.steal) {
      let best = -1, bt = Infinity;
      for (let k = 0; k < P.length; k++) if (P[k].on && P[k].born < bt) { bt = P[k].born; best = k; }
      if (best < 0) return;
      i = best; stolen++;
    } else { refused++; return; }
    const p = P[i], a = rand(0, TAU), sp = rand(0.2, 1) * H * D.speed;
    p.x = x; p.y = y; p.vx = Math.cos(a) * sp; p.vy = Math.sin(a) * sp - H * 0.2;
    p.age = 0; p.life = D.life * rand(0.6, 1); p.born = clock; p.on = true;
  }
  function burst(x, y) { for (let k = 0; k < D.burst; k++) spawn(x, y); lastX = x; lastY = y; flash = 1; }
  return {
    press(x, y) { burst(x, y); spawnT = 0; },
    frame(dt, t) {
      stage({ night: 0.35 });
      clock += dt; spawnT += dt;
      if (spawnT > D.every) { spawnT = 0; burst(rand(W * 0.1, W * 0.6), rand(H * 0.25, H * 0.6)); }
      flash = Math.max(0, flash - dt * 3);
      const g = H * D.gravity;
      let alive = 0;
      for (let i = 0; i < P.length; i++) {
        const p = P[i];
        if (!p.on) continue;
        p.age += dt;
        if (p.age >= p.life) { p.on = false; free.push(i); continue; }   // die = give the slot back
        p.vy += g * dt; p.x += p.vx * dt; p.y += p.vy * dt;
        if (p.y > GY) { p.y = GY; p.vy *= -0.4; p.vx *= 0.7; }
        alive++;
        const k = 1 - p.age / p.life;
        dot(p.x, p.y, 1.5 + k * 1.5, "rgba(255,233,168," + (0.3 + k * 0.7) + ")");
      }
      if (flash > 0) ring(lastX, lastY, (1 - flash) * 18, "rgba(255,233,168," + flash * 0.6 + ")", 1);
      // the pool itself: one slot per particle, lit while it lives
      const cols = Math.ceil(Math.sqrt(D.size)), rows = Math.ceil(D.size / cols);
      const cell = Math.min(W * 0.32 / cols, H * 0.4 / rows), gx = W - 8 - cols * cell, gy = 14;
      for (let i = 0; i < D.size; i++) {
        const cx = gx + (i % cols) * cell, cy = gy + Math.floor(i / cols) * cell;
        rect(cx + 0.5, cy + 0.5, Math.max(0.5, cell - 1.5), Math.max(0.5, cell - 1.5), P[i].on ? SPARK : "rgba(201,196,228,0.16)");
      }
      label("alive " + alive + " / " + D.size + " · free " + free.length, gx + cols * cell, gy + rows * cell + 11, BONE, "right");
      // the two counters: the pool versus new Particle() every time
      label("pool: allocations 0 since start", 8, 14, GOOD);
      label("naive: new Particle() × " + naive, 8, 26, HOT);
      if (D.steal) label("stolen " + stolen + " (oldest evicted)", 8, 38, "rgba(245,193,105,0.8)");
      else if (refused) label("refused " + refused + " (free list empty)", 8, 38, "rgba(245,193,105,0.8)");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Pool", "Puddlepool", "a pool of twelve that starves in one burst — every newcomer steals the oldest slot, so the tail of each burst eats its head", { size: 12, burst: 10, steal: true });

def("D", "Disintegrate", "particles", "EMIT FROM A SPRITE'S PIXELS: pixelsOf reads the hero's opaque pixels; each becomes a particle that flies off and reassembles — press to send it there", function (u) {
  var D = { mode: "disintegrate",   // "disintegrate" (feet first, blown away) / "teleport" (a vertical streak) / "assemble" (rain in, top first)
            hold: 1.6,     // seconds whole between trips
            fly: 1.2,      // seconds for the pixels to leave, and again to arrive
            scatter: 0.45, // how far the pixels roam, ×H
            wind: 0.5,     // the disintegrate drift, ×W
            label: "pixelsOf(sprite): one particle per opaque pixel · k = ease(p·1.8 − delay)" };
  const { ctx, W, H, GY, stage, hero, heroSprite, pixelsOf, rect, label, rand, clamp, ease, noise, BONE, DIM } = u;
  // the sprite is drawn once to a tiny offscreen canvas at UNIT size 1 (14 × 19
  // px) and pixelsOf() reads it back: every opaque pixel becomes a particle
  // carrying its colour and its home offset — the source grid sits in the
  // corner, magnified. a trip is one clock p: 0 → 1 the pixels LEAVE for a
  // scattered spot, the hero's home moves, 1 → 0 they ARRIVE. each pixel waits
  // its own DELAY, ordered by row (feet first to disintegrate, top first to
  // assemble), and the mode decides where "scattered" is. the codex's Teleport
  // blink and the grimoire's Dust burst are this trick with one mode each.
  const sp = heroSprite({ s: 1 }), img = pixelsOf(sp.cv), s = Math.max(2, Math.round(H / 60));
  const px = [];
  for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) {
    const o = (y * img.width + x) * 4;
    if (img.data[o + 3] < 128) continue;
    px.push({ ox: x - sp.ax, oy: y - sp.ay, row: y / img.height, j: rand(0, 1), sx: 0, sy: 0, d: 0,
              c: "rgb(" + img.data[o] + "," + img.data[o + 1] + "," + img.data[o + 2] + ")" });
  }
  let hx = W * 0.3, phase = 0, p = 0, timer = 0, nextX = W * 0.7;   // phase 0 whole · 1 leaving · 2 arriving
  function plan() {                                    // every pixel's scattered spot and delay for this trip
    for (const q of px) {
      if (D.mode === "teleport") { q.sx = q.ox * s * 0.4; q.sy = -H * D.scatter - q.j * H * 0.3; q.d = q.j * 0.2; }
      else if (D.mode === "assemble") { q.sx = rand(-1, 1) * W * 0.3; q.sy = -H * D.scatter * rand(0.5, 1.4); q.d = (1 - q.row) * 0.6 + q.j * 0.2; }
      else { q.sx = q.ox * s + W * D.wind * rand(0.4, 1) + noise(q.j * 9) * W * 0.1; q.sy = -H * D.scatter * rand(0.3, 1) + q.oy * s * 0.5; q.d = (1 - q.row) * 0.6 + q.j * 0.2; }
    }
  }
  plan();
  function go() { if (phase === 0) { phase = 1; p = 0; plan(); } }
  return {
    press(x, y) { nextX = clamp(x, W * 0.1, W * 0.9); go(); },
    frame(dt, t) {
      stage({ night: 0.4 });
      timer += dt;
      if (phase === 0 && timer > D.hold) go();
      if (phase === 1) { p = Math.min(1, p + dt / D.fly); if (p >= 1) { phase = 2; hx = nextX; nextX = rand(W * 0.15, W * 0.85); } }
      else if (phase === 2) { p = Math.max(0, p - dt / D.fly); if (p <= 0) { phase = 0; timer = 0; } }
      if (phase === 0) hero(hx, GY, { pose: "stand", frame: t });
      else {
        for (const q of px) {                          // each pixel between home and scattered by its own eased clock
          const k = ease(p * 1.8 - q.d);
          if (k <= 0 && D.mode !== "teleport") { rect(hx + q.ox * s, GY + q.oy * s, s, s, q.c); continue; }
          const x = hx + q.ox * s + (q.sx - q.ox * s) * k, y = GY + q.oy * s + (q.sy - q.oy * s) * k;
          ctx.globalAlpha = clamp(1 - k, 0, 1);
          if (D.mode === "teleport") rect(x, y - s * 5 * k * (1 - k), s, s * (1 + 10 * k * (1 - k)), q.c);
          else rect(x, y, s, s, q.c);
          ctx.globalAlpha = 1;
        }
      }
      // the source: the 14 × 19 sprite the particles were read from
      ctx.save(); ctx.imageSmoothingEnabled = false;
      ctx.drawImage(sp.cv, 8, 14, sp.w * 2, sp.h * 2);
      ctx.restore();
      ctx.strokeStyle = DIM; ctx.lineWidth = 1; ctx.strokeRect(7.5, 13.5, sp.w * 2 + 1, sp.h * 2 + 1);
      label(sp.w + "×" + sp.h + " px → " + px.length + " particles", 8, sp.h * 2 + 26, BONE);
      label(D.mode + " · " + (phase === 0 ? "whole" : phase === 1 ? "leaving p=" + p.toFixed(2) : "arriving p=" + p.toFixed(2)), W - 8, 14, BONE, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Disintegrate", "Dustup", "the assemble mode, slowly: the pixels rain in from a wide cloud above and lock in top row first — a summoning", { mode: "assemble", fly: 2, scatter: 0.6 });

def("H", "Hail", "particles", "PARTICLES THAT COLLIDE: each stone tests the ground, two blocks and a slope, bounces by e, rubs by μ, piles up, then rain — press to drop hail there", function (u) {
  var D = { n: 200,          // the pool
            rate: 45,        // stones per second from the sky
            gravity: 1.7,    // ×H per second²
            bounce: 0.5,     // restitution e: the share of normal speed kept
            friction: 0.75,  // μ: the share of tangential speed kept per hit
            bounces: 8,      // hits before a stone gives up
            melt: 2.5,       // seconds a resting stone lasts
            rainAfter: 6,    // seconds of hail, then as many of rain, forever
            size: 2.2,       // stone radius, px at card size
            label: "v' = v − (1+e)(v·n)n · vₜ ·= μ · rest when |v| < ε" };
  const { ctx, W, H, GY, stage, wall, poly, dot, line, arrow, label, rand, clamp, len, WATER, BONE, DIM, INK } = u;
  // chapter 06's sparks fell through the floor; these stop. each particle
  // carries a radius and asks three questions a frame: am I below the GROUND,
  // inside a BLOCK, under the SLOPE? a hit pushes it out along the surface
  // NORMAL n, reflects the normal part of its velocity scaled by RESTITUTION e,
  // and scales the tangential part by FRICTION μ (the lexicon's Bounce, with a
  // second axis). when a stone's speed falls under ε it RESTS — that is how
  // piles form in corners. every few seconds the sky switches to rain: thin,
  // no restitution, dead on the first touch (the codex's Stage rain).
  const r = D.size * H / 170;
  const blocks = [{ x: W * 0.1, y: GY - H * 0.2, w: W * 0.2, h: H * 0.2 }, { x: W * 0.7, y: GY - H * 0.11, w: W * 0.13, h: H * 0.11 }];
  const slope = [W * 0.3, GY - H * 0.2, W * 0.56, GY];   // x1, y1, x2, y2 — down to the right
  const sn = (function () { const dx = slope[2] - slope[0], dy = slope[3] - slope[1], L = Math.max(1e-6, len(dx, dy)); return [-dy / L, dx / L]; })();
  if (sn[1] > 0) { sn[0] = -sn[0]; sn[1] = -sn[1]; }  // the normal points up
  const P = [];
  for (let i = 0; i < D.n; i++) P.push({ x: 0, y: 0, vx: 0, vy: 0, hits: 0, rest: 0, rain: false, on: false });
  let acc = 0, clock = 0, hit = { x: 0, y: 0, nx: 0, ny: -1, age: 9 }, dropX = -1, dropT = 0;
  function spawn(x, y, rain) {
    for (let i = 0; i < P.length; i++) if (!P[i].on) {
      const p = P[i]; p.x = x; p.y = y; p.vx = rand(-0.05, 0.05) * W; p.vy = rain ? H * 1.2 : rand(0, 0.2) * H;
      p.hits = 0; p.rest = 0; p.rain = rain; p.on = true; return;
    }
  }
  function collide(p, nx, ny, push) {                  // push out along n, reflect, rub
    p.x += nx * push; p.y += ny * push;
    const vn = p.vx * nx + p.vy * ny;
    if (vn < 0) {
      const tx = -ny, ty = nx, vt = (p.vx * tx + p.vy * ty) * D.friction;
      const vn2 = (Math.abs(vn) < H * 0.06) ? 0 : -vn * D.bounce;   // too slow to bounce: settle
      p.vx = vn2 * nx + vt * tx; p.vy = vn2 * ny + vt * ty;
      p.hits++;
      hit.x = p.x; hit.y = p.y; hit.nx = nx; hit.ny = ny; hit.age = 0;
    }
    return true;
  }
  return {
    press(x, y) { dropX = x; dropT = 0.7; for (let k = 0; k < 12; k++) spawn(x + rand(-8, 8), Math.min(y, GY - 4), false); },
    frame(dt, t) {
      stage({ night: 0.5 });
      clock += dt; hit.age += dt; dropT -= dt;
      const raining = (clock % (D.rainAfter * 2)) > D.rainAfter;
      acc += D.rate * (raining ? 2 : 1) * dt;
      while (acc >= 1) { acc -= 1; spawn(rand(0, W), -4, raining); }
      if (dropT > 0) { for (let k = 0; k < 2; k++) spawn(dropX + rand(-10, 10), 0, false); }
      const g = H * D.gravity;
      let alive = 0, resting = 0;
      for (let i = 0; i < P.length; i++) {
        const p = P[i];
        if (!p.on) continue;
        if (p.rest > 0) {                               // a resting stone: no physics, just melting
          p.rest += dt;
          if (p.rest > D.melt) { p.on = false; continue; }
          resting++; alive++;
          dot(p.x, p.y, r, "rgba(200,230,255,0.85)");
          continue;
        }
        p.vy += g * dt; p.x += p.vx * dt; p.y += p.vy * dt;
        let touched = false;
        if (p.y + r > GY) touched = collide(p, 0, -1, GY - (p.y + r));
        for (const b of blocks) {
          if (p.x + r <= b.x || p.x - r >= b.x + b.w || p.y + r <= b.y || p.y - r >= b.y + b.h) continue;
          const top = p.y + r - b.y, left = p.x + r - b.x, right = b.x + b.w - (p.x - r), bot = b.y + b.h - (p.y - r);
          const m = Math.min(top, left, right, bot);
          if (m === top) touched = collide(p, 0, -1, -top);
          else if (m === left) touched = collide(p, -1, 0, -left);
          else if (m === right) touched = collide(p, 1, 0, -right);
          else touched = collide(p, 0, 1, -bot);
        }
        if (p.x >= slope[0] && p.x <= slope[2]) {
          const ly = slope[1] + (p.x - slope[0]) / (slope[2] - slope[0]) * (slope[3] - slope[1]);
          if (p.y + r > ly && p.y - r < ly + 10) touched = collide(p, sn[0], sn[1], -(p.y + r - ly) * -sn[1]) ;
        }
        if (touched && p.rain) { p.on = false; u.ring(p.x, p.y, 3, "rgba(200,230,255,0.5)", 1); continue; }
        if (p.hits > D.bounces || p.x < -10 || p.x > W + 10 || p.y > H + 10) { p.on = false; continue; }
        if (touched && Math.abs(p.vy) < H * 0.02 && Math.abs(p.vx) < H * 0.02 && p.y + r > GY - 1) p.rest = 0.001;
        alive++;
        if (p.rain) line(p.x, p.y, p.x - p.vx * 0.02, p.y - p.vy * 0.02, "rgba(170,210,255,0.6)", 1);
        else dot(p.x, p.y, r, "rgba(220,240,255,0.95)");
      }
      // the colliders, and the last hit's normal
      for (const b of blocks) wall(b.x, b.y, b.w, b.h);
      poly([[slope[0], slope[1]], [slope[2], slope[3]], [slope[0], slope[3]]], "#5E5880");
      line(slope[0], slope[1], slope[2], slope[3], BONE, 1.5);
      if (hit.age < 0.5) arrow(hit.x, hit.y, hit.x + hit.nx * 16, hit.y + hit.ny * 16, "rgba(245,193,105," + (1 - hit.age * 2) + ")");
      label((raining ? "rain" : "hail") + " · alive " + alive + " · resting " + resting + " · e " + D.bounce + " μ " + D.friction, 8, 14, BONE);
      label("n", hit.x + hit.nx * 20, hit.y + hit.ny * 20 + 3, "rgba(245,193,105," + clamp(1 - hit.age * 2, 0, 1) + ")", "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Hail", "Hailstorm", "three times the stones, heavier, and each one dies on its first bounce — a hard rattle instead of a pile", { rate: 140, gravity: 2.6, bounces: 1 });

def("S", "Subemitter", "particles", "SUB-EMITTERS: a rocket that emits smoke, dies into sparks that emit embers and pop — the emitter tree drawn — press to launch a rocket there", function (u) {
  var D = { depth: 2,          // levels of the tree allowed to emit (the rocket is level 0)
            every: 2.4,        // seconds between autopilot launches
            speed: 0.9,        // rocket speed, ×H per second
            gravity: 1.2,      // on sparks and embers, ×H per second²
            chain: false,      // sparks die into more sparks instead of a pop
            tree: { rocket: { trail: "smoke", rate: 45, death: "spark", burst: 18 },
                    spark:  { trail: "ember", rate: 16, death: "pop", burst: 1 },
                    smoke: {}, ember: {}, pop: {} },
            label: "p.acc += rate·dt → emit(trail) · on death → burst(kind, n) · level < depth" };
  const { ctx, W, H, GY, TAU, stage, dot, ring, glow, line, label, rand, clamp, SPARK, FIRE, HOT, BONE, DIM, INK } = u;
  // Waterdrops made a particle's death an EVENT; here the event spawns more
  // particles, and so can its life. every particle carries a kind and a LEVEL;
  // the tree (a plain object in D) says what each kind trails while alive
  // (rate per second, banked in an accumulator) and what it bursts into when
  // it dies. one pool serves all five kinds; a particle only emits while its
  // level is under depth, so the tree cannot recurse into a pool-emptying
  // storm — when the pool is full, spawns are refused and counted.
  const N = 300, P = [];
  for (let i = 0; i < N; i++) P.push({ kind: "", level: 0, x: 0, y: 0, vx: 0, vy: 0, age: 0, life: 1, acc: 0, on: false });
  const counts = { rocket: 0, smoke: 0, spark: 0, ember: 0, pop: 0 };
  let refused = 0, timer = 1.5, tx = W * 0.6, ty = H * 0.3;
  function spawn(kind, level, x, y, vx, vy) {
    for (let i = 0; i < N; i++) if (!P[i].on) {
      const p = P[i];
      p.kind = kind; p.level = level; p.x = x; p.y = y; p.vx = vx; p.vy = vy; p.age = 0; p.acc = 0; p.on = true;
      p.life = kind === "rocket" ? 9 : kind === "smoke" ? rand(0.7, 1.2) : kind === "spark" ? rand(0.5, 0.9) : kind === "ember" ? rand(0.25, 0.45) : 0.25;
      return p;
    }
    refused++; return null;
  }
  function launch(x, y) {
    const x0 = W * 0.2, y0 = GY, dx = x - x0, dy = y - y0, d = Math.max(1, Math.sqrt(dx * dx + dy * dy)), v = H * D.speed;
    const p = spawn("rocket", 0, x0, y0, dx / d * v, dy / d * v);
    if (p) p.life = d / v;                             // it dies exactly at the target
    tx = x; ty = y;
  }
  function die(p) {
    const node = D.tree[p.kind] || {};
    const chain = p.kind === "spark" && D.chain;
    const kind = chain ? "spark" : node.death, n = chain ? 3 : (node.burst || 0);
    if (!kind || p.level >= D.depth) return;
    for (let k = 0; k < n; k++) {
      const a = rand(0, TAU), s = (kind === "spark" ? rand(0.2, 0.7) : 0.05) * H;
      spawn(kind, p.level + 1, p.x, p.y, Math.cos(a) * s, Math.sin(a) * s - (kind === "spark" ? H * 0.1 : 0));
    }
  }
  return {
    press(x, y) { launch(x, clamp(y, 10, GY - 10)); timer = 0; },
    frame(dt, t) {
      stage({ night: 0.85 });
      timer += dt;
      if (timer > D.every) { timer = 0; launch(rand(W * 0.35, W * 0.9), rand(H * 0.12, H * 0.5)); }
      for (const k in counts) counts[k] = 0;
      const g = H * D.gravity;
      for (let i = 0; i < N; i++) {
        const p = P[i];
        if (!p.on) continue;
        p.age += dt;
        if (p.age >= p.life) { p.on = false; die(p); continue; }
        const node = D.tree[p.kind] || {};
        if (node.trail && p.level < D.depth) {          // the trail: banked spawns
          p.acc += node.rate * dt;
          while (p.acc >= 1) { p.acc -= 1; spawn(node.trail, p.level + 1, p.x, p.y, rand(-0.03, 0.03) * H, rand(-0.06, 0) * H); }
        }
        if (p.kind === "spark" || p.kind === "ember") p.vy += g * dt;
        if (p.kind === "smoke") p.vy -= H * 0.05 * dt;
        p.x += p.vx * dt; p.y += p.vy * dt;
        counts[p.kind]++;
        const k = 1 - p.age / p.life;
        if (p.kind === "rocket") { glow(p.x, p.y, 8, SPARK, 0.6); dot(p.x, p.y, 2.2, INK); }
        else if (p.kind === "smoke") dot(p.x, p.y, 2 + (1 - k) * 6, "rgba(160,160,190," + k * 0.25 + ")");
        else if (p.kind === "spark") dot(p.x, p.y, 1.8, "rgba(255,233,168," + (0.4 + k * 0.6) + ")");
        else if (p.kind === "ember") dot(p.x, p.y, 1.1, "rgba(245,138,90," + k + ")");
        else ring(p.x, p.y, (1 - k) * 7, "rgba(255,233,168," + k * 0.7 + ")", 1);
      }
      ring(tx, ty, 4, DIM, 1);
      // the emitter tree, as it runs
      const tr = D.tree, x0 = 8, lh = 11;
      let y = 14;
      function row(txt, alive, lvl, colr) { label(txt, x0 + lvl * 10, y, lvl < D.depth ? (colr || BONE) : DIM); if (alive !== null) label("×" + alive, x0 + 118, y, colr || BONE); y += lh; }
      row("rocket  L0", counts.rocket, 0, INK);
      row("├ trail " + tr.rocket.trail + " " + tr.rocket.rate + "/s", counts.smoke, 1);
      row("└ death " + tr.rocket.death + " ×" + tr.rocket.burst, counts.spark, 1, SPARK);
      row("├ trail " + tr.spark.trail + " " + tr.spark.rate + "/s", counts.ember, 2, FIRE);
      row("└ death " + (D.chain ? "spark ×3" : tr.spark.death), D.chain ? null : counts.pop, 2);
      label("depth " + D.depth + " · pool " + (counts.rocket + counts.smoke + counts.spark + counts.ember + counts.pop) + "/" + N + (refused ? " · refused " + refused : ""), x0, y + 2, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Subemitter", "Sparklers", "sparks that die into sparks, three levels deep — the same tree with chain on and one more level of depth; the pool fills and refuses", { depth: 3, chain: true });

def("V", "Vortex", "particles", "FORCE LISTS: wind, vortex, attractor, turbulence — one list per emitter, summed into one acceleration; drawn as chips — press to move the vortex there", function (u) {
  var D = { n: 220,            // the pool
            rate: 70,          // particles per second from the left edge
            life: 3,           // seconds each lives
            drag: 0.6,         // velocity bleed per second
            radius: 0.36,      // a positional force's reach, ×H
            forces: [ { kind: "wind", strength: 0.35 },                     // a constant push to the right, ×H/s²
                      { kind: "vortex", strength: 1.6, x: 0.55, y: 0.42 },  // a swirl about a point (x, y are fractions of W, H)
                      { kind: "attract", strength: 0.5, x: 0.84, y: 0.62 }, // a pull toward a point; it swallows what arrives
                      { kind: "turbulence", strength: 0.9 } ],              // a noise field, no centre
            label: "a = Σ force(kind, strength, p) · v += a·dt · v ·= 1 − drag·dt" };
  const { ctx, W, H, GY, TAU, stage, dot, ring, arrow, rect, label, rand, clamp, len, noise, noise2, rgba, BONE, WATER, MAGIC, GOOD, DIM, INK, SPARK } = u;
  // chapter 06 gave every particle one force: gravity. a FORCE LIST gives an
  // emitter any number, each a plain record { kind, strength } — WIND is a
  // constant vector, a VORTEX pushes sideways around a point (the lexicon's
  // Whirlpool) and a little inward, an ATTRACTOR pulls straight in (Magnet)
  // and swallows what reaches it, TURBULENCE reads a noise field at the
  // particle's position. each frame the list is summed into one acceleration,
  // the velocity bleeds by drag so nothing runs away, and one sample particle
  // shows its terms as arrows in the colour of the chip that made them.
  const N = D.n, P = [];
  for (let i = 0; i < N; i++) P.push({ x: 0, y: 0, vx: 0, vy: 0, age: 0, life: 1, on: false });
  const F = [];
  for (let i = 0; i < D.forces.length; i++) {
    const f = D.forces[i], pos = f.x !== undefined;
    F.push({ kind: f.kind, strength: f.strength, pos: pos, bx: (pos ? f.x : 0.5) * W, by: (pos ? f.y : 0.5) * H, x: 0, y: 0, ax: 0, ay: 0, seed: i * 7 });
  }
  const COL = { wind: BONE, vortex: WATER, attract: MAGIC, turbulence: GOOD };
  const R = H * D.radius, VMAX = H * 1.6;
  let acc = 0, pick = 0, drained = 0;
  function apply(f, p, t) {                          // one force's push on p, written into f.ax / f.ay; false = swallowed
    f.ax = 0; f.ay = 0;
    if (f.kind === "wind") { f.ax = f.strength * H; return true; }
    if (f.kind === "turbulence") {
      const k = 3.4 / H;
      f.ax = noise2(p.x * k + t * 0.5, p.y * k) * f.strength * H * 2;
      f.ay = noise2(p.x * k + 40, p.y * k - t * 0.5) * f.strength * H * 2;
      return true;
    }
    const dx = f.x - p.x, dy = f.y - p.y, d = Math.max(1, len(dx, dy)), fall = clamp(1.4 - d / R, 0, 1);
    if (f.kind === "attract") {
      if (d < 3 + f.strength * 2) return false;      // it arrived: drained
      f.ax = dx / d * f.strength * H * 2.5 * fall; f.ay = dy / d * f.strength * H * 2.5 * fall;
      return true;
    }
    f.ax = (-dy / d * f.strength * 2.5 + dx / d * f.strength * 0.5) * H * fall;   // vortex: mostly sideways, a little in
    f.ay = (dx / d * f.strength * 2.5 + dy / d * f.strength * 0.5) * H * fall;
    return true;
  }
  return {
    press(x, y) {
      const posF = F.filter(function (f) { return f.pos; });
      if (!posF.length) return;
      const f = posF[pick++ % posF.length];
      f.bx = clamp(x, 4, W - 4); f.by = clamp(y, 4, GY - 4);
    },
    frame(dt, t) {
      stage({ night: 0.6 });
      for (let i = 0; i < F.length; i++) {             // positional forces drift a little about their base
        const f = F[i];
        f.x = f.bx + noise(t * 0.12 + f.seed) * W * 0.06; f.y = f.by + noise(t * 0.1 + f.seed + 3) * H * 0.05;
      }
      acc += D.rate * dt;
      while (acc >= 1) {
        acc -= 1;
        for (let i = 0; i < N; i++) if (!P[i].on) {
          const p = P[i]; p.x = rand(0, W * 0.04); p.y = rand(H * 0.1, GY - 4); p.vx = H * 0.1; p.vy = 0; p.age = 0; p.life = D.life * rand(0.7, 1.1); p.on = true; break;
        }
      }
      const keep = clamp(1 - D.drag * dt, 0, 1);
      let alive = 0, sample = -1;
      for (let i = 0; i < N; i++) {
        const p = P[i];
        if (!p.on) continue;
        p.age += dt;
        if (p.age >= p.life || p.x > W + 6 || p.x < -6 || p.y > GY || p.y < -6) { p.on = false; continue; }
        let ax = 0, ay = 0, gone = false;
        for (let k = 0; k < F.length; k++) {
          if (!apply(F[k], p, t)) { gone = true; break; }
          ax += F[k].ax; ay += F[k].ay;
        }
        if (gone) { p.on = false; drained++; continue; }
        p.vx = (p.vx + ax * dt) * keep; p.vy = (p.vy + ay * dt) * keep;
        const v = len(p.vx, p.vy);
        if (v > VMAX) { p.vx *= VMAX / v; p.vy *= VMAX / v; }
        p.x += p.vx * dt; p.y += p.vy * dt;
        alive++;
        if (sample < 0 && p.age > 0.4 && p.x > W * 0.2) sample = i;
        const k = 1 - p.age / p.life;
        dot(p.x, p.y, 1.4 + k * 0.8, "rgba(255,233,168," + (0.25 + k * 0.6) + ")");
      }
      // the positional forces on the stage: a swirl ring, a drain
      for (let i = 0; i < F.length; i++) {
        const f = F[i];
        if (!f.pos) continue;
        const c = COL[f.kind] || INK;
        ring(f.x, f.y, R, rgba(c, 0.18), 1);
        if (f.kind === "vortex") {
          for (let k = 0; k < 3; k++) { const a = t * 1.5 + k * TAU / 3, r0 = R * 0.45; arrow(f.x + Math.cos(a) * r0, f.y + Math.sin(a) * r0, f.x + Math.cos(a + 0.5) * r0, f.y + Math.sin(a + 0.5) * r0, rgba(c, 0.7)); }
        } else {
          dot(f.x, f.y, 3, c);
          for (let k = 0; k < 4; k++) { const a = k * TAU / 4 + t; arrow(f.x + Math.cos(a) * R * 0.5, f.y + Math.sin(a) * R * 0.5, f.x + Math.cos(a) * R * 0.25, f.y + Math.sin(a) * R * 0.25, rgba(c, 0.6)); }
        }
      }
      // the sample particle: each force's term as an arrow
      if (sample >= 0) {
        const p = P[sample];
        ring(p.x, p.y, 4, INK, 1);
        for (let k = 0; k < F.length; k++) { apply(F[k], p, t); arrow(p.x, p.y, p.x + F[k].ax * 0.07, p.y + F[k].ay * 0.07, COL[F[k].kind] || INK); }
      }
      // the chips: the force list as the emitter holds it
      let cx = 8;
      for (let i = 0; i < F.length; i++) {
        const f = F[i], txt = f.kind + " " + f.strength, w = 10 + txt.length * 5.4, c = COL[f.kind] || INK;
        rect(cx, 6, w, 13, rgba(c, 0.18)); ctx.strokeStyle = rgba(c, 0.7); ctx.lineWidth = 1; ctx.strokeRect(cx + 0.5, 6.5, w - 1, 12);
        label(txt, cx + 5, 16, c);
        cx += w + 4;
      }
      label("alive " + alive + "/" + N + (drained ? " · drained " + drained : ""), W - 8, H - 20, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Vortex", "Vacuum", "attractors only, and strong: two drains and no wind — everything that spawns curves in and is swallowed; the drained counter is the whole picture", { forces: [{ kind: "attract", strength: 2.4, x: 0.5, y: 0.42 }, { kind: "attract", strength: 1.4, x: 0.82, y: 0.68 }], rate: 110 });

def("E", "Emitters", "particles", "SHAPE EMITTERS: spawn points sample an outlined shape — point, line, ring, rect, arc, path — and launch along its normal — press to cycle the shape", function (u) {
  var D = { shape: "point",    // the starting shape
            shapes: ["point", "line", "ring", "rect", "arc", "path"],   // the cycle
            every: 2.4,        // seconds per shape on autopilot
            rate: 90,          // particles per second
            life: 1.3,         // seconds each lives
            rise: 0.22,        // launch speed along the normal, ×H per second
            size: 0.2,         // the shape's radius, ×H
            colour: "#FFE9A8",
            formula: { point: "p = c", line: "p = c + (2u − 1)·R·x̂", ring: "p = c + R·(cos θ, sin θ)", rect: "p = c + (2u − 1, 2v − 1)·½size",
                       arc: "θ = θ₀ + u·(θ₁ − θ₀) · p = c + R·(cos θ, sin θ)", path: "p = B(u) = Σ Bᵢ(u)·Pᵢ · n̂ = ⟂B′(u)" },
            label: "spawn: (p, n̂) = shape(u) · v = n̂·rise" };
  const { ctx, W, H, GY, TAU, stage, dot, ring, line, label, rand, clamp, len, rgba, BONE, DIM, INK } = u;
  // chapter 06 emitted from a point. a SHAPE EMITTER asks the shape for a
  // random point (one number u, or two) and for the NORMAL there, and launches
  // along the normal — so a ring breathes outward, an arc fans, a line curtains
  // up and a path (a cubic Bézier, sampled by u) sheds sideways. the shape is
  // half the effect: the same particle on a ring is a portal, on a line a
  // waterfall, on a rect a snowfield. the codex's Fire spin was a ring emitter
  // with a spin; here the outline is drawn so the sample points can be read.
  const N = 200, P = [];
  for (let i = 0; i < N; i++) P.push({ x: 0, y: 0, vx: 0, vy: 0, age: 0, life: 1, on: false });
  const cx = W * 0.5, cy = H * 0.48, R = H * D.size;
  const B = [[-1.3, 0.5], [-0.7, -1.4], [0.7, 1.4], [1.3, -0.5]];     // the path's control points, ×R
  let si = Math.max(0, D.shapes.indexOf(D.shape)), timer = 0, acc = 0;
  const out = { x: 0, y: 0, nx: 0, ny: -1 };
  function sample(shape) {                             // a point on the shape (about the centre) and its normal
    const u0 = rand(0, 1);
    out.nx = 0; out.ny = -1;
    if (shape === "line") { out.x = (u0 * 2 - 1) * R * 1.3; out.y = 0; }
    else if (shape === "ring") { const a = u0 * TAU; out.x = Math.cos(a) * R; out.y = Math.sin(a) * R; out.nx = Math.cos(a); out.ny = Math.sin(a); }
    else if (shape === "rect") { out.x = (u0 * 2 - 1) * R * 1.3; out.y = (rand(0, 1) * 2 - 1) * R * 0.6; }
    else if (shape === "arc") { const a = Math.PI + u0 * Math.PI; out.x = Math.cos(a) * R; out.y = Math.sin(a) * R; out.nx = Math.cos(a); out.ny = Math.sin(a); }
    else if (shape === "path") {
      const v = 1 - u0, b0 = v * v * v, b1 = 3 * u0 * v * v, b2 = 3 * u0 * u0 * v, b3 = u0 * u0 * u0;
      out.x = (b0 * B[0][0] + b1 * B[1][0] + b2 * B[2][0] + b3 * B[3][0]) * R;
      out.y = (b0 * B[0][1] + b1 * B[1][1] + b2 * B[2][1] + b3 * B[3][1]) * R;
      const dx = 3 * v * v * (B[1][0] - B[0][0]) + 6 * v * u0 * (B[2][0] - B[1][0]) + 3 * u0 * u0 * (B[3][0] - B[2][0]);
      const dy = 3 * v * v * (B[1][1] - B[0][1]) + 6 * v * u0 * (B[2][1] - B[1][1]) + 3 * u0 * u0 * (B[3][1] - B[2][1]);
      const L = Math.max(1e-6, len(dx, dy));
      out.nx = -dy / L; out.ny = dx / L;
      if (out.ny > 0) { out.nx = -out.nx; out.ny = -out.ny; }   // the upward-facing normal
    }
    else { out.x = 0; out.y = 0; }
  }
  function outline(shape) {
    ctx.strokeStyle = DIM; ctx.lineWidth = 1; ctx.setLineDash([3, 3]);
    ctx.beginPath();
    if (shape === "point") { ctx.moveTo(cx - 5, cy); ctx.lineTo(cx + 5, cy); ctx.moveTo(cx, cy - 5); ctx.lineTo(cx, cy + 5); }
    else if (shape === "line") { ctx.moveTo(cx - R * 1.3, cy); ctx.lineTo(cx + R * 1.3, cy); }
    else if (shape === "ring") ctx.arc(cx, cy, R, 0, TAU);
    else if (shape === "rect") ctx.rect(cx - R * 1.3, cy - R * 0.6, R * 2.6, R * 1.2);
    else if (shape === "arc") ctx.arc(cx, cy, R, Math.PI, TAU);
    else { ctx.moveTo(cx + B[0][0] * R, cy + B[0][1] * R); ctx.bezierCurveTo(cx + B[1][0] * R, cy + B[1][1] * R, cx + B[2][0] * R, cy + B[2][1] * R, cx + B[3][0] * R, cy + B[3][1] * R); }
    ctx.stroke(); ctx.setLineDash([]);
    if (shape === "path") for (let k = 0; k < 4; k++) dot(cx + B[k][0] * R, cy + B[k][1] * R, 1.6, DIM);
  }
  function next() { si = (si + 1) % Math.max(1, D.shapes.length); timer = 0; }
  return {
    press() { next(); },
    frame(dt, t) {
      stage({ night: 0.7 });
      timer += dt;
      if (timer > D.every) next();
      const shape = D.shapes[si] || "point";
      outline(shape);
      acc += D.rate * dt;
      let lastX = cx, lastY = cy, lastNx = 0, lastNy = -1;
      while (acc >= 1) {
        acc -= 1;
        for (let i = 0; i < N; i++) if (!P[i].on) {
          const p = P[i]; sample(shape);
          p.x = cx + out.x; p.y = cy + out.y;
          p.vx = out.nx * H * D.rise + rand(-0.02, 0.02) * H; p.vy = out.ny * H * D.rise + rand(-0.02, 0.02) * H;
          p.age = 0; p.life = D.life * rand(0.7, 1.2); p.on = true;
          lastX = p.x; lastY = p.y; lastNx = out.nx; lastNy = out.ny;
          break;
        }
      }
      let alive = 0;
      for (let i = 0; i < N; i++) {
        const p = P[i];
        if (!p.on) continue;
        p.age += dt;
        if (p.age >= p.life) { p.on = false; continue; }
        p.x += p.vx * dt; p.y += p.vy * dt;
        alive++;
        const k = 1 - p.age / p.life;
        dot(p.x, p.y, 1 + k * 1.6, rgba(D.colour, 0.15 + k * 0.7));
      }
      // the last sample: its point and normal
      ring(lastX, lastY, 3, INK, 1);
      line(lastX, lastY, lastX + lastNx * 12, lastY + lastNy * 12, INK, 1);
      // the cycle, the current shape lit
      let x0 = 8;
      for (let k = 0; k < D.shapes.length; k++) { const on = k === si; label(D.shapes[k], x0, 14, on ? INK : DIM); x0 += D.shapes[k].length * 5.6 + 8; }
      label(D.formula[shape] || "", W / 2, cy + R * 1.5 + 12, BONE, "center");
      label("rate " + D.rate + "/s · alive " + alive + " · rise " + D.rise, W - 8, H - 20, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Emitters", "Edgeglow", "ring and arc only, slow and violet, the motes barely leaving the line — a portal breathing rather than a fountain", { shapes: ["ring", "arc"], rise: 0.05, colour: "#C9A0F5" });

def("Z", "Zsort", "particles", "Z-SORT & SOFT PARTICLES: the same puffs twice — left in pool order with a hard floor cut, right sorted by z and faded at the ground — press to scatter", function (u) {
  var D = { n: 70,             // puffs (drawn twice)
            size: 1,           // ×
            alpha: 0.6,        // a near puff's strength
            soft: 0.1,         // the fade band above the floor, ×H
            sink: 0.035,       // downward drift, ×H per second
            life: 7,           // seconds before a puff is respawned
            label: "order = sort(z) far → near · α(y) → 0 as y → floor" };
  const { ctx, W, H, GY, TAU, stage, rect, line, label, rand, clamp, mix, rgba, BONE, DIM, INK, HOT, GOOD } = u;
  // two mistakes a puff can make, and their fixes, side by side. every puff
  // carries a Z (0 far, 1 near): near ones are bigger and brighter (the atlas's
  // Volumes). drawn in POOL ORDER (left) a far puff can paint over a near one
  // and the cloud flickers as slots are reused; SORTED BY Z each frame (right)
  // near always covers far. and where a puff crosses the floor the left half
  // shows the HARD CUT of an intersection; the right fades its alpha to zero
  // over a soft band above the floor — SOFT PARTICLES, the depth-buffer trick
  // done with a distance. the strips at the top are the draw order's z values.
  const N = D.n, P = [], order = [], half = W / 2;
  for (let i = 0; i < N; i++) { P.push({ x: 0, y: 0, z: 0, vx: 0, vy: 0, age: 0, r: 1 }); order.push(i); }
  function spawn(p, fresh) {
    p.x = rand(0, half); p.y = fresh ? rand(H * 0.25, GY + H * 0.03) : rand(H * 0.2, H * 0.45); p.z = rand(0, 1);
    p.vx = rand(-0.02, 0.02) * W; p.vy = 0; p.age = rand(0, fresh ? D.life : 0.5);
    p.r = H * 0.05 * D.size * (0.4 + p.z * 1.1);
  }
  for (let i = 0; i < N; i++) spawn(P[i], true);
  function puff(p, ox, soft) {
    let a = D.alpha * (0.35 + p.z * 0.65) * clamp(Math.min(p.age * 2, (D.life - p.age) * 1.5), 0, 1);
    if (a <= 0.005) return;
    const c = mix("#4A4A6E", "#E6E2F2", p.z);
    if (soft && p.y + p.r > GY - H * D.soft) {           // near the floor: a vertical fade to zero at the ground
      const g = ctx.createLinearGradient(0, GY - H * D.soft, 0, GY);
      g.addColorStop(0, rgba(c, a)); g.addColorStop(1, rgba(c, 0));
      ctx.fillStyle = g;
    } else ctx.fillStyle = rgba(c, a);
    ctx.beginPath(); ctx.arc(ox + p.x, p.y, p.r, 0, TAU); ctx.fill();
  }
  return {
    press(x, y) {
      const lx = x % half;
      for (let i = 0; i < N; i++) {
        const p = P[i], dx = p.x - lx, dy = p.y - y, d = Math.max(4, Math.sqrt(dx * dx + dy * dy));
        const k = clamp(1 - d / (H * 0.5), 0, 1) * H * 0.9;
        p.vx += dx / d * k; p.vy += dy / d * k;
      }
    },
    frame(dt, t) {
      stage({ night: 0.55 });
      const keep = clamp(1 - 2.5 * dt, 0, 1);
      for (let i = 0; i < N; i++) {
        const p = P[i];
        p.age += dt;
        if (p.age > D.life) spawn(p, false);
        p.vx *= keep; p.vy *= keep;
        p.x += p.vx * dt; p.y += (p.vy + H * D.sink + Math.sin(t * 0.7 + i) * H * 0.01) * dt;
        if (p.x < 0) { p.x = 0; p.vx = Math.abs(p.vx); } else if (p.x > half) { p.x = half; p.vx = -Math.abs(p.vx); }
        if (p.y - p.r > GY + H * 0.02) spawn(p, false);
      }
      order.sort(function (a, b) { return P[a].z - P[b].z; });   // far first, so near paints last
      // left: pool order, clipped hard at the floor
      ctx.save(); ctx.beginPath(); ctx.rect(0, 0, half, GY); ctx.clip();
      for (let i = 0; i < N; i++) puff(P[i], 0, false);
      ctx.restore();
      // right: sorted, soft at the floor
      ctx.save(); ctx.beginPath(); ctx.rect(half, 0, half, H); ctx.clip();
      for (let k = 0; k < N; k++) puff(P[order[k]], half, true);
      ctx.restore();
      line(half, 0, half, H, DIM, 1);
      // the draw order's z, as strips: jagged on the left, a ramp on the right
      const sw = Math.max(1, (half - 16) / N), sh = H * 0.07;
      for (let k = 0; k < N; k++) {
        rect(8 + k * sw, 22 + sh * (1 - P[k].z), Math.max(0.5, sw - 0.5), sh * P[k].z, rgba(HOT, 0.6));
        rect(half + 8 + k * sw, 22 + sh * (1 - P[order[k]].z), Math.max(0.5, sw - 0.5), sh * P[order[k]].z, rgba(GOOD, 0.6));
      }
      label("pool order · hard cut", 8, 14, HOT);
      label("sorted by z · soft floor", half + 8, 14, GOOD);
      label("soft band", W - 8, GY - H * D.soft - 3, DIM, "right");
      line(half, GY - H * D.soft, W, GY - H * D.soft, "rgba(155,226,138,0.3)", 1);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Zsort", "Zfog", "many faint puffs, large and slow — a fog bank, where the left half's popping order and hard floor line are the whole tell", { n: 160, alpha: 0.16, size: 1.9 });

def("V", "Voronoi", "particles", "VORONOI SHATTER: seeds claim the sprite's pixel blocks by nearest seed; each cell flies as one rigid piece from the impact — press to shatter there", function (u) {
  var D = { target: "hero",    // "hero" (the sprite's own pixels) / "pane" (a sheet of glass)
            cells: 9,          // seeds, so pieces
            fling: 0.7,        // ×H per second, away from the impact
            spin: 6,           // radians per second, at most
            gravity: 1.6,      // ×H per second²
            hold: 2.2,         // seconds whole before the autopilot breaks it
            fade: 1.8,         // seconds the pieces last
            tinkle: false,     // glass tones on the break (after the first press)
            label: "cell(b) = argminᵢ |b − seedᵢ| · piece = rigid body of its blocks" };
  const { ctx, W, H, GY, TAU, stage, heroSprite, pixelsOf, rect, dot, ring, line, label, rand, clamp, hsl, rgba, tone, INK, BONE, DIM, SPARK, WATER } = u;
  // the bestiary's Crumble broke a button into a grid; a VORONOI shatter
  // breaks along cells instead, and cells look like glass. scatter a few SEEDS
  // over the sprite's box; every pixel block belongs to its NEAREST seed
  // (Disintegrate's pixelsOf gives the blocks). each cell is then one rigid
  // PIECE — a position, a velocity, a spin — carrying its blocks with it, flung
  // away from the impact point, falling, bouncing once, fading. while whole,
  // the map is shown: each block tinted by its cell, the seeds as dots, so the
  // pieces that fly are the ones you were already looking at.
  const s = Math.max(2, Math.round(H / 60)), blocks = [];
  if (D.target === "pane") {
    for (let y = 0; y < 19; y++) for (let x = 0; x < 14; x++)
      blocks.push({ ox: x - 7, oy: y - 18, cell: 0, c: "rgba(" + (150 + x * 5) + "," + (200 + y * 2) + ",255," + (0.35 + ((x + y) % 3) * 0.1).toFixed(2) + ")" });
  } else {
    const sp = heroSprite({ s: 1 }), img = pixelsOf(sp.cv);
    for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) {
      const o = (y * img.width + x) * 4;
      if (img.data[o + 3] < 128) continue;
      blocks.push({ ox: x - sp.ax, oy: y - sp.ay, cell: 0, c: "rgb(" + img.data[o] + "," + img.data[o + 1] + "," + img.data[o + 2] + ")" });
    }
  }
  const hx = W * 0.5, seeds = [], pieces = [];
  for (let i = 0; i < D.cells; i++) { seeds.push({ x: 0, y: 0 }); pieces.push({ x: 0, y: 0, vx: 0, vy: 0, rot: 0, vr: 0, cx: 0, cy: 0, n: 0, bounced: false }); }
  let phase = 0, timer = 0, age = 0, ix = hx, iy = GY - 9 * s, armed = false;
  function reseed() {                                  // new seeds, and every block re-assigned to its nearest
    for (let i = 0; i < D.cells; i++) { seeds[i].x = rand(-7, 7); seeds[i].y = rand(-18, 0); }
    for (let k = 0; k < D.cells; k++) { pieces[k].cx = 0; pieces[k].cy = 0; pieces[k].n = 0; }
    for (let b = 0; b < blocks.length; b++) {
      const q = blocks[b];
      let best = 0, bd = Infinity;
      for (let i = 0; i < D.cells; i++) { const dx = q.ox + 0.5 - seeds[i].x, dy = q.oy + 0.5 - seeds[i].y, d = dx * dx + dy * dy; if (d < bd) { bd = d; best = i; } }
      q.cell = best;
      pieces[best].cx += q.ox + 0.5; pieces[best].cy += q.oy + 0.5; pieces[best].n++;
    }
    for (let k = 0; k < D.cells; k++) { const p = pieces[k], n = Math.max(1, p.n); p.cx /= n; p.cy /= n; }
  }
  reseed();
  function shatter(x, y) {
    ix = x; iy = y; phase = 1; age = 0;
    for (let k = 0; k < D.cells; k++) {
      const p = pieces[k];
      p.x = hx + p.cx * s; p.y = GY + p.cy * s; p.rot = 0; p.bounced = false;
      const dx = p.x - x, dy = p.y - y, d = Math.max(4, Math.sqrt(dx * dx + dy * dy)), sp = H * D.fling * rand(0.5, 1) / (1 + d / (H * 0.25));
      p.vx = dx / d * sp; p.vy = dy / d * sp - H * 0.25; p.vr = rand(-1, 1) * D.spin;
    }
    if (armed && D.tinkle) for (let k = 0; k < 3; k++) tone({ freq: rand(1800, 3400), dur: 0.14, type: "sine", vol: 0.07, at: k * 0.05 });
  }
  return {
    press(x, y) {
      armed = true;
      if (phase === 0) shatter(clamp(x, hx - 8 * s, hx + 8 * s), clamp(y, GY - 19 * s, GY));
      else for (let k = 0; k < D.cells; k++) { const p = pieces[k], dx = p.x - x, dy = p.y - y, d = Math.max(4, Math.sqrt(dx * dx + dy * dy)); p.vx += dx / d * H * 0.3; p.vy += dy / d * H * 0.3 - H * 0.15; p.bounced = false; }
    },
    frame(dt, t) {
      stage({ night: 0.45 });
      const paneA = D.target === "pane" ? 1 : 1;
      if (phase === 0) {
        timer += dt;
        const fadeIn = clamp(timer * 3, 0, 1);
        ctx.globalAlpha = fadeIn;
        for (let b = 0; b < blocks.length; b++) { const q = blocks[b]; rect(hx + q.ox * s, GY + q.oy * s, s, s, q.c); }
        for (let b = 0; b < blocks.length; b++) { const q = blocks[b]; rect(hx + q.ox * s, GY + q.oy * s, s, s, hsl((q.cell * 47) % 360, 0.7, 0.6, 0.28)); }
        for (let i = 0; i < D.cells; i++) dot(hx + seeds[i].x * s, GY + seeds[i].y * s, 1.8, SPARK);
        ctx.globalAlpha = 1;
        if (timer > D.hold) shatter(hx + rand(-4, 4) * s, GY - rand(4, 14) * s);
      } else {
        age += dt;
        const g = H * D.gravity, a = clamp(1 - (age - D.fade * 0.5) / (D.fade * 0.5), 0, 1);
        for (let k = 0; k < D.cells; k++) {
          const p = pieces[k];
          if (!p.n) continue;
          p.vy += g * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
          if (p.y > GY) {
            p.y = GY;
            if (!p.bounced) { p.vy *= -0.35; p.vx *= 0.6; p.vr *= 0.5; p.bounced = true; }
            else { p.vy = 0; p.vx *= 0.9; p.vr *= 0.9; }
          }
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.globalAlpha = a * paneA;
          for (let b = 0; b < blocks.length; b++) { const q = blocks[b]; if (q.cell !== k) continue; ctx.fillStyle = q.c; ctx.fillRect((q.ox - p.cx) * s, (q.oy - p.cy) * s, s + 0.3, s + 0.3); }
          ctx.restore();
        }
        if (age < 0.4) { const k = 1 - age / 0.4; ring(ix, iy, (1 - k) * 22, rgba(SPARK, k), 1.5); for (let r = 0; r < 6; r++) line(ix, iy, ix + Math.cos(r * TAU / 6) * 6 * k, iy + Math.sin(r * TAU / 6) * 6 * k, rgba(INK, k), 1); }
        if (age > D.fade) { phase = 0; timer = 0; reseed(); }
      }
      // the seeds' map, magnified in the corner
      const ms = Math.max(1.5, s * 0.6), mx = 10, my = 14;
      ctx.strokeStyle = DIM; ctx.lineWidth = 1; ctx.strokeRect(mx - 0.5, my - 0.5, 14 * ms + 1, 19 * ms + 1);
      for (let b = 0; b < blocks.length; b++) { const q = blocks[b]; rect(mx + (q.ox + 7) * ms, my + (q.oy + 18) * ms, ms, ms, hsl((q.cell * 47) % 360, 0.7, 0.55, 0.9)); }
      for (let i = 0; i < D.cells; i++) dot(mx + (seeds[i].x + 7) * ms, my + (seeds[i].y + 18) * ms, 1.2, INK);
      label(D.cells + " seeds · " + blocks.length + " blocks · " + (phase === 0 ? "whole" : "pieces " + age.toFixed(1) + "s"), mx, my + 19 * ms + 12, BONE);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Voronoi", "Vitrine", "a sheet of glass in thirty-six small cells, with a tinkle after your first press — the same seeds and pieces, a museum case instead of a hero", { target: "pane", cells: 36, tinkle: true });

def("C", "Cracks", "particles", "CRACK GENERATION: a branching random walk from the impact — each tip steps, jitters, thins by decay and sometimes forks — press to crack there", function (u) {
  var D = { surface: "stone",  // "stone" / "glass" / "ice": the slab and the crack's colour
            branches: 10,      // live tips allowed at once
            start: 4,          // tips a fresh impact begins with
            decay: 0.94,       // width kept per step
            fork: 0.12,        // chance per step that a tip forks
            jitter: 0.5,       // radians of wander per step
            speed: 150,        // px per second a tip advances, at card size
            width: 2.6,        // starting width, px
            every: 2.4,        // seconds between the autopilot's impacts
            hits: 3,           // impacts before the slab is replaced
            label: "tip: p += step·(cos θ, sin θ) · θ += U(−j, j) · w ·= decay · fork with P" };
  const { ctx, W, H, GY, TAU, stage, layer, rect, dot, line, label, rand, clamp, rgba, BONE, DIM, INK, SPARK } = u;
  // the codex's Ground crack was a drawing; this one is GROWN. an impact starts
  // a few TIPS, each a position, a heading θ and a width w. every step a tip
  // moves a few pixels along θ, nudges θ by a random amount (the RANDOM WALK),
  // multiplies w by decay (the THINNING) and, with a small chance, FORKS: a
  // child tip leaves at an angle with a fraction of the width. a tip dies when
  // it is too thin or leaves the slab. segments are stroked once into a cached
  // layer as they appear — nothing is redrawn — so the picture can hold
  // thousands of them for the price of one drawImage.
  const L = layer("cracks"), lc = L.ctx, k = H / 170;
  const slab = { x: W * 0.12, y: H * 0.1, w: W * 0.76, h: GY - H * 0.1 };
  const tips = [];
  for (let i = 0; i < D.branches; i++) tips.push({ x: 0, y: 0, a: 0, w: 0, on: false });
  let acc = 0, timer = 0, hits = 0, segs = 0, live = 0, fadeK = 1, done = 0, sample = 0;
  const look = { stone: { fill: "#6E6890", crack: "rgba(20,16,32,0.95)", edge: "rgba(232,229,244,0.35)" },
                 glass: { fill: "rgba(140,190,240,0.3)", crack: "rgba(255,255,255,0.9)", edge: "rgba(255,255,255,0.12)" },
                 ice: { fill: "rgba(200,232,255,0.55)", crack: "rgba(255,255,255,0.95)", edge: "rgba(120,180,240,0.35)" } };
  const S = look[D.surface] || look.stone;
  function inSlab(x, y) { return x > slab.x && x < slab.x + slab.w && y > slab.y && y < slab.y + slab.h; }
  function impact(x, y) {
    if (fadeK < 1) return;
    x = clamp(x, slab.x + 4, slab.x + slab.w - 4); y = clamp(y, slab.y + 4, slab.y + slab.h - 4);
    let placed = 0;
    for (let i = 0; i < tips.length && placed < D.start; i++) if (!tips[i].on) {
      const tp = tips[i]; tp.x = x; tp.y = y; tp.a = rand(0, TAU); tp.w = D.width * k; tp.on = true; placed++;
    }
    hits++; timer = 0;
    lc.fillStyle = S.crack; lc.beginPath(); lc.arc(x, y, 2 * k, 0, TAU); lc.fill();
  }
  function step(tp) {
    const st = 4 * k, nx = tp.x + Math.cos(tp.a) * st, ny = tp.y + Math.sin(tp.a) * st;
    lc.lineCap = "round";
    lc.strokeStyle = S.edge; lc.lineWidth = tp.w + 2; lc.beginPath(); lc.moveTo(tp.x + 1, tp.y + 1); lc.lineTo(nx + 1, ny + 1); lc.stroke();
    lc.strokeStyle = S.crack; lc.lineWidth = tp.w; lc.beginPath(); lc.moveTo(tp.x, tp.y); lc.lineTo(nx, ny); lc.stroke();
    tp.x = nx; tp.y = ny; tp.a += rand(-D.jitter, D.jitter); tp.w *= D.decay; segs++;
    if (tp.w < 0.35 || !inSlab(nx, ny)) { tp.on = false; return; }
    if (Math.random() < D.fork) for (let i = 0; i < tips.length; i++) if (!tips[i].on) {   // a fork: a thinner child at an angle
      const c = tips[i]; c.x = nx; c.y = ny; c.a = tp.a + (Math.random() < 0.5 ? -1 : 1) * rand(0.4, 1.1); c.w = tp.w * 0.7; c.on = true;
      tp.w *= 0.85; break;
    }
  }
  return {
    press(x, y) { impact(x, y); },
    frame(dt, t) {
      stage({ night: 0.35 });
      rect(slab.x, slab.y, slab.w, slab.h, S.fill);
      ctx.strokeStyle = rgba(BONE, 0.4); ctx.lineWidth = 1; ctx.strokeRect(slab.x + 0.5, slab.y + 0.5, slab.w - 1, slab.h - 1);
      timer += dt;
      if (fadeK >= 1 && timer > D.every && hits < D.hits) impact(rand(slab.x + 10, slab.x + slab.w - 10), rand(slab.y + 10, slab.y + slab.h - 10));
      acc = Math.min(acc + D.speed * k * dt, 24 * k);
      live = 0;
      while (acc >= 4 * k) { acc -= 4 * k; for (let i = 0; i < tips.length; i++) if (tips[i].on) step(tips[i]); }
      for (let i = 0; i < tips.length; i++) if (tips[i].on) { live++; sample = i; }
      if (hits >= D.hits && live === 0) {                // the slab is spent: fade the layer, then a fresh one
        done += dt;
        if (done > 1) fadeK = Math.max(0, fadeK - dt * 2);
        if (fadeK <= 0) { lc.clearRect(0, 0, L.W, L.H); hits = 0; segs = 0; done = 0; timer = 0; fadeK = 1; }
      }
      ctx.save(); ctx.globalAlpha = fadeK; ctx.drawImage(L.cv, 0, 0, W, H); ctx.restore();
      for (let i = 0; i < tips.length; i++) if (tips[i].on) dot(tips[i].x, tips[i].y, 1.6, SPARK);
      if (live) { const tp = tips[sample]; label("w " + tp.w.toFixed(2) + " θ " + ((tp.a % TAU + TAU) % TAU).toFixed(2), tp.x + 6, tp.y - 4, SPARK); }
      label(D.surface + " · tips " + live + "/" + D.branches + " · segments " + segs + " · hits " + hits + "/" + D.hits, 8, 14, BONE);
      label("decay " + D.decay + " · fork " + D.fork + " · jitter " + D.jitter, W - 8, 14, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Cracks", "Crazing", "thin ice: many fine tips that fork often and thin fast — a web of hairlines instead of a few fat fractures", { surface: "ice", branches: 22, fork: 0.3, width: 1.4 });

def("A", "Arc", "particles", "SWORD ARC RIBBON: the blade's hilt and tip sampled into a ring of N pairs as it swings; quads between neighbours fade by age — press to swing at it", function (u) {
  var D = { n: 24,             // sample pairs kept
            step: 0.12,        // radians the blade must turn before a new sample
            fade: 0.32,        // seconds a sample lasts
            rise: 0,           // samples drift upward, ×H per second
            colour: "#8AD9F5",
            swing: 0.26,       // seconds per swing
            every: 1.3,        // seconds between autopilot swings
            blade: 0.4,        // blade length, ×H
            hilt: 0.09,        // the hilt's distance from the pivot, ×H
            label: "quad(hilt[i], tip[i], tip[i+1], hilt[i+1]) · α = 1 − age ÷ fade" };
  const { ctx, W, H, GY, TAU, stage, hero, dot, line, label, rand, clamp, ease, rgba, DIM, INK } = u;
  // chapter 06 trailed a point; a blade is a LINE, so the trail is a RIBBON.
  // every time the blade has turned by step, two points are pushed into a ring
  // buffer: where the HILT is and where the TIP is. between each neighbouring
  // pair a QUAD is filled — hilt[i], tip[i], tip[i+1], hilt[i+1] — with a
  // gradient from faint at the hilt to bright at the tip, and an alpha that
  // falls with the sample's age. the folio's Trailslash was this baked into
  // frames; here the buffer is drawn as the dots it is, so the quads can be
  // counted. a fast swing spreads samples wide; a slow one packs them.
  const S = [];
  for (let i = 0; i < D.n; i++) S.push({ hx: 0, hy: 0, tx: 0, ty: 0, t0: -99 });
  const swings = [[-2.5, 0.5], [0.7, -2.6], [-1.3, 1.1], [1.6, -2.0]];
  const hx = W * 0.42, px = hx + 5 * Math.max(2, Math.round(H / 60)), py = GY - 10 * Math.max(2, Math.round(H / 60));
  let a0 = -2.5, a1 = 0.5, k = 1, timer = 0, head = 0, lastA = 99, sw = 0, clock = 0;
  function angle() { return a0 + (a1 - a0) * ease(k); }
  function begin(from, to) { a0 = from; a1 = to; k = 0; timer = 0; }
  return {
    press(x, y) {
      const target = Math.atan2(y - py, x - px), cur = angle();
      let from = cur;
      if (Math.abs(target - cur) < 1) from = target + (target > -Math.PI / 2 ? -2.2 : 2.2);
      begin(from, target);
    },
    frame(dt, t) {
      stage({ night: 0.5 });
      clock += dt; timer += dt;
      if (k < 1) k = Math.min(1, k + dt / D.swing);
      else if (timer > D.every) { sw = (sw + 1) % swings.length; begin(swings[sw][0], swings[sw][1]); }
      const a = angle(), ca = Math.cos(a), sa = Math.sin(a);
      if (Math.abs(a - lastA) >= D.step) {              // a new pair for the ring buffer
        const s = S[head]; head = (head + 1) % D.n; lastA = a;
        s.hx = px + ca * H * D.hilt; s.hy = py + sa * H * D.hilt; s.tx = px + ca * H * D.blade; s.ty = py + sa * H * D.blade; s.t0 = clock;
      }
      // the ribbon: quads between neighbouring samples, oldest first
      let quads = 0;
      for (let i = 0; i < D.n - 1; i++) {
        const p = S[(head + i) % D.n], q = S[(head + i + 1) % D.n];
        const ap = 1 - (clock - p.t0) / D.fade, aq = 1 - (clock - q.t0) / D.fade;
        if (ap <= 0 || aq <= 0 || q.t0 < p.t0) continue;
        const al = clamp(Math.min(ap, aq), 0, 1), lift = D.rise * H * (clock - q.t0);
        const g = ctx.createLinearGradient((p.hx + q.hx) / 2, (p.hy + q.hy) / 2 - lift, (p.tx + q.tx) / 2, (p.ty + q.ty) / 2 - lift);
        g.addColorStop(0, rgba(D.colour, al * 0.08)); g.addColorStop(1, rgba(D.colour, al * 0.85));
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.moveTo(p.hx, p.hy - lift); ctx.lineTo(p.tx, p.ty - lift); ctx.lineTo(q.tx, q.ty - lift); ctx.lineTo(q.hx, q.hy - lift); ctx.closePath(); ctx.fill();
        line(p.tx, p.ty - lift, q.tx, q.ty - lift, rgba("#FFFFFF", al * 0.6), 1);
        quads++;
      }
      for (let i = 0; i < D.n; i++) { const s = S[i], al = 1 - (clock - s.t0) / D.fade; if (al > 0) { dot(s.tx, s.ty - D.rise * H * (clock - s.t0), 1.2, rgba(INK, al * 0.7)); dot(s.hx, s.hy - D.rise * H * (clock - s.t0), 1, rgba(INK, al * 0.4)); } }
      hero(hx, GY, { pose: "stand", frame: t });
      line(px + ca * H * D.hilt, py + sa * H * D.hilt, px + ca * H * D.blade, py + sa * H * D.blade, INK, 2.5);
      line(px + ca * H * D.hilt - sa * 5, py + sa * H * D.hilt + ca * 5, px + ca * H * D.hilt + sa * 5, py + sa * H * D.hilt - ca * 5, "#8A6A3E", 2);
      label("θ " + a.toFixed(2) + " · " + quads + " quads · step " + D.step + " · fade " + D.fade + "s", 8, 14, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Arc", "Afterburn", "a fiery ribbon that lingers four times longer and rises as it fades — the same quads, wearing smoke", { fade: 1.3, rise: 0.12, colour: "#F58A5A" });

def("K", "Keyframes", "particles", "EFFECT SEQUENCING: the effect is data — [{at, do}, …] — and one runner fires each cue as the playhead passes it; timeline drawn — press to play there", function (u) {
  var D = { seq: [ { at: 0, do: "flash" }, { at: 0.05, do: "burst" }, { at: 0.1, do: "smoke" }, { at: 0.2, do: "ring" } ],
            every: 2.4,        // seconds between autopilot plays
            speed: 1,          // playback rate
            tail: 0.5,         // seconds of timeline shown after the last cue
            label: "while (seq[i].at ≤ t) fire(seq[i++].do) · t += dt·speed" };
  const { ctx, W, H, GY, TAU, stage, dot, ring, glow, line, rect, label, rand, clamp, rgba, SPARK, FIRE, BONE, DIM, INK, HOT } = u;
  // an explosion is not one effect but a SEQUENCE: a flash, then sparks, then
  // smoke, then a ring, each a few frames apart. write that down as data — a
  // list of { at, do } — and one RUNNER plays any list: it keeps a clock and an
  // index, and every frame fires every cue whose time has come. the folio's
  // Beam was a sequence baked into a sprite sheet; this one is edited by
  // changing numbers. four runners can play at once (each with its own
  // playhead), and the same particle pool serves all their cues.
  const N = 180, P = [];
  for (let i = 0; i < N; i++) P.push({ kind: "", x: 0, y: 0, vx: 0, vy: 0, age: 0, life: 1, on: false });
  const runs = [], flashes = [], rings = [];
  for (let i = 0; i < 4; i++) { runs.push({ x: 0, y: 0, t: 0, i: 0, on: false }); flashes.push({ x: 0, y: 0, age: 9 }); rings.push({ x: 0, y: 0, age: 9 }); }
  let timer = 1.5, last = -1, T = 1;
  for (let i = 0; i < D.seq.length; i++) T = Math.max(T, D.seq[i].at + D.tail);
  function spawn(kind, x, y, n, sp) {
    for (let k = 0, i = 0; k < n && i < N; i++) if (!P[i].on) {
      const p = P[i], a = rand(0, TAU), v = rand(0.3, 1) * sp;
      p.kind = kind; p.x = x; p.y = y; p.vx = Math.cos(a) * v; p.vy = Math.sin(a) * v - (kind === "smoke" ? H * 0.1 : 0);
      p.age = 0; p.life = kind === "smoke" ? rand(0.8, 1.4) : rand(0.4, 0.8); p.on = true; k++;
    }
  }
  function oldest(list) { let o = 0; for (let i = 1; i < list.length; i++) if (list[i].age > list[o].age) o = i; return list[o]; }
  function fire(cue, x, y) {                            // the cue names are the whole vocabulary
    if (cue === "flash") { const f = oldest(flashes); f.x = x; f.y = y; f.age = 0; }
    else if (cue === "burst") spawn("spark", x, y, 16, H * 0.7);
    else if (cue === "smoke") spawn("smoke", x, y, 8, H * 0.12);
    else if (cue === "ring") { const r = oldest(rings); r.x = x; r.y = y; r.age = 0; }
  }
  function play(x, y) {
    let r = null;
    for (let i = 0; i < runs.length; i++) if (!runs[i].on) { r = runs[i]; break; }
    if (!r) r = runs[0];
    r.x = x; r.y = y; r.t = 0; r.i = 0; r.on = true; last = runs.indexOf(r);
  }
  return {
    press(x, y) { play(x, clamp(y, H * 0.25, GY)); timer = 0; },
    frame(dt, t) {
      stage({ night: 0.6 });
      timer += dt;
      if (timer > D.every) { timer = 0; play(rand(W * 0.15, W * 0.85), rand(H * 0.3, GY - 4)); }
      for (let k = 0; k < runs.length; k++) {           // the runner: one loop, any sequence
        const r = runs[k];
        if (!r.on) continue;
        r.t += dt * D.speed;
        while (r.i < D.seq.length && D.seq[r.i].at <= r.t) { fire(D.seq[r.i].do, r.x, r.y); r.i++; }
        if (r.t > T) r.on = false;
      }
      for (let k = 0; k < flashes.length; k++) { const f = flashes[k]; f.age += dt; if (f.age < 0.15) glow(f.x, f.y, H * 0.22 * (1 - f.age / 0.15 * 0.5), SPARK, 0.9 * (1 - f.age / 0.15)); }
      const g = H * 1.4;
      for (let i = 0; i < N; i++) {
        const p = P[i];
        if (!p.on) continue;
        p.age += dt;
        if (p.age >= p.life) { p.on = false; continue; }
        if (p.kind === "spark") p.vy += g * dt; else { p.vx *= clamp(1 - dt, 0, 1); }
        p.x += p.vx * dt; p.y += p.vy * dt;
        const k = 1 - p.age / p.life;
        if (p.kind === "spark") dot(p.x, p.y, 1.2 + k, rgba(SPARK, 0.3 + k * 0.7));
        else dot(p.x, p.y, 2 + (1 - k) * 7, "rgba(160,160,190," + k * 0.3 + ")");
      }
      for (let k = 0; k < rings.length; k++) { const r = rings[k]; r.age += dt; if (r.age < 0.5) ring(r.x, r.y, r.age / 0.5 * H * 0.18, rgba(INK, 1 - r.age / 0.5), 2); }
      // the timeline: cues as ticks, a playhead per runner, the sequence as text
      const x0 = 14, x1 = W - 14, y0 = 22;
      line(x0, y0, x1, y0, BONE, 1);
      const lr = last >= 0 ? runs[last] : null;
      for (let i = 0; i < D.seq.length; i++) {
        const c = D.seq[i], x = x0 + (x1 - x0) * c.at / T, lit = lr && lr.on && lr.i > i;
        line(x, y0 - 4, x, y0 + 4, lit ? SPARK : BONE, lit ? 2 : 1);
        label(c.do, x, y0 + (i % 2 ? 24 : 14), lit ? SPARK : DIM, "center");
        label(c.at + "s", x, y0 - 7, DIM, "center");
      }
      for (let k = 0; k < runs.length; k++) { const r = runs[k]; if (r.on) { const x = x0 + (x1 - x0) * clamp(r.t / T, 0, 1); line(x, y0 - 6, x, y0 + 6, k === last ? INK : rgba(INK, 0.35), 1.5); } }
      let txt = "seq = [";
      for (let i = 0; i < D.seq.length; i++) txt += (i ? ", " : "") + "{at " + D.seq[i].at + ", do " + D.seq[i].do + "}";
      label(txt + "]", W / 2, H - 20, DIM, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Keyframes", "Kickoff", "the same runner on a slower, spaced-out list with a double ring at the end — the cues are readable one at a time", { seq: [{ at: 0, do: "flash" }, { at: 0.3, do: "burst" }, { at: 0.6, do: "smoke" }, { at: 0.9, do: "ring" }, { at: 1.15, do: "ring" }], every: 3.4 });

def("L", "Layers", "particles", "SCREEN vs WORLD SPACE: a world-parented spark scrolls with the camera, the HUD flash does not, a misparented twin slides off — drag to pan the camera", function (u) {
  var D = { space: "world",    // where hit sparks live: "world" (draw at x − cam) / "screen" (draw at x) / "double" (x − 2·Δcam, the classic bug)
            ghost: "double",   // a faint twin spawned in a mistaken space, or "none"
            pan: 0.28,         // the autopilot's camera sway, ×W
            every: 1.5,        // seconds between hits
            run: 0.22,         // the hero's speed, ×W per second
            label: "world: draw(x − cam) · screen: draw(x) · double: draw(x − 2·Δcam)" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, crate, dot, line, rect, label, rand, clamp, rgba, SPARK, HOT, BONE, DIM, INK, GOOD } = u;
  // every effect lives in a LAYER, and the layer decides what the camera does
  // to it (chapter 03's layering). a hit spark belongs to the WORLD: it is
  // stored in world x and drawn at x − camera, so it stays on the hero as the
  // view pans. a damage flash belongs to the SCREEN: stored and drawn in screen
  // x, it ignores the camera. the classic mistake is a world effect parented
  // to a node that already follows the camera — it scrolls TWICE, sliding off
  // its owner at the camera's speed; the faint red twin here is that bug,
  // spawned beside every correct spark so the two can be watched part.
  const N = 120, P = [];
  for (let i = 0; i < N; i++) P.push({ x: 0, y: 0, vx: 0, vy: 0, age: 0, life: 1, on: false, space: "world", cam0: 0, ghost: false });
  let wx = W * 0.4, cam = 0, hold = 0, holdT = 0, timer = 0, hud = 0, hits = 0;
  function sparks(space, ghost) {
    const sx = wx - cam, sy = GY - H * 0.12;
    for (let k = 0, i = 0; k < 12 && i < N; i++) if (!P[i].on) {
      const p = P[i], a = rand(-Math.PI, 0), v = rand(0.2, 0.6) * H;
      p.x = space === "world" ? wx : sx; p.y = sy; p.vx = Math.cos(a) * v; p.vy = Math.sin(a) * v;
      p.age = 0; p.life = rand(0.5, 0.9); p.on = true; p.space = space; p.cam0 = cam; p.ghost = ghost; k++;
    }
  }
  function hit() { sparks(D.space, false); if (D.ghost !== "none" && D.ghost !== D.space) sparks(D.ghost, true); hud = 1; hits++; timer = 0; }
  return {
    drag: true,
    press(x, y) { hold = (x / W - 0.5) * W * 0.9; holdT = 1.5; },
    frame(dt, t) {
      stage({ night: 0.3 });
      wx += W * D.run * dt; timer += dt; holdT -= dt;
      const want = wx - W * 0.45 + (holdT > 0 ? hold : Math.sin(t * 0.6) * W * D.pan);
      cam += (want - cam) * clamp(dt * 6, 0, 1);
      // the world layer: props at world x, the ground's hatching, the hero
      const sp = W * 0.5, k0 = Math.floor(cam / sp) - 1;
      for (let k = k0; k < k0 + 5; k++) { const x = k * sp - cam; if (k % 2) tree(x, GY, H * 0.3); else crate(x + sp * 0.3, GY, H * 0.09); }
      ctx.strokeStyle = "rgba(201,196,228,0.16)"; ctx.lineWidth = 1; ctx.beginPath();
      for (let x = -((cam % 12) + 12) % 12; x < W; x += 12) { ctx.moveTo(x, GY + 2); ctx.lineTo(x - 5, GY + 8); }
      ctx.stroke();
      const hx = wx - cam;
      hero(hx, GY, { pose: "run", frame: t });
      if (timer > D.every) hit();
      for (let i = 0; i < N; i++) {
        const p = P[i];
        if (!p.on) continue;
        p.age += dt;
        if (p.age >= p.life) { p.on = false; continue; }
        p.vy += H * 1.2 * dt; p.x += p.vx * dt; p.y += p.vy * dt;
        const dx = p.space === "world" ? p.x - cam : p.space === "screen" ? p.x : p.x - 2 * (cam - p.cam0);
        const k = 1 - p.age / p.life;
        dot(dx, p.y, 1.2 + k, p.ghost ? rgba(HOT, 0.25 + k * 0.4) : rgba(SPARK, 0.3 + k * 0.7));
      }
      // the screen layer: a damage vignette and a hit marker that ignore the camera
      hud = Math.max(0, hud - dt * 3);
      if (hud > 0) { ctx.strokeStyle = rgba(HOT, hud * 0.5); ctx.lineWidth = 10; ctx.strokeRect(0, 0, W, H); }
      rect(8, 6, 40, 12, "rgba(19,16,32,0.6)"); label("HIT " + hits, 12, 15, hud > 0 ? HOT : BONE);
      // the two layers, as a legend
      const lx = W - 8, ly = 14;
      label("screen layer: vignette, HIT counter", lx, ly, GOOD, "right");
      label("world layer: ground, hero, sparks (" + D.space + ")", lx, ly + 12, SPARK, "right");
      if (D.ghost !== "none" && D.ghost !== D.space) label("the bug: sparks in " + D.ghost + " space", lx, ly + 24, HOT, "right");
      label("camera x " + Math.round(cam) + (holdT > 0 ? " (held)" : ""), lx, ly + 36, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Layers", "Lockstep", "the wrong version: sparks kept in screen space, no twin — they stay where they were born while the hero and the world slide out from under them", { space: "screen", ghost: "none" });

def("B", "Budget", "particles", "EFFECT BUDGETS: every emitter has a priority; the meter counts the living, past the budget the worst priority is culled first — press to spawn a burst", function (u) {
  var D = { budget: 150,       // particles allowed alive at once (the pool holds 300)
            burst: 110,        // an explosion's size
            ambient: 45,       // dust per second, the lowest priority
            every: 5,          // seconds between autopilot explosions
            table: [ { name: "hero hits", pri: 1 }, { name: "enemy hits", pri: 2 }, { name: "explosion", pri: 3 }, { name: "ambient dust", pri: 4 } ],
            label: "spawn(p): alive < budget ? slot : cull(worst > p) ? slot : refuse" };
  const { ctx, W, H, GY, TAU, stage, hero, dot, rect, line, label, rand, clamp, noise, rgba, SPARK, HOT, FIRE, BONE, DIM, INK, GOOD } = u;
  // chapter 16 kept a budget table for the whole game; this is the particle
  // row of it. every emitter carries a PRIORITY (1 matters most). a spawn takes
  // a free slot while the alive count is under the BUDGET; past it, the spawn
  // may CULL a living particle of worse priority and take its slot, and if
  // none exists it is REFUSED — so when an explosion lands, the ambient dust
  // is what vanishes, and the hero's own hits always get through. the meter
  // is the count stacked by priority against the budget line; the table shows
  // who was culled or refused in the last moment.
  const N = 300, P = [], counts = [0, 0, 0, 0, 0], em = [];
  for (let i = 0; i < N; i++) P.push({ pri: 4, x: 0, y: 0, vx: 0, vy: 0, age: 0, life: 1, born: 0, on: false });
  for (let i = 0; i < D.table.length; i++) em.push({ name: D.table[i].name, pri: D.table[i].pri, culled: 0, refused: 0, flag: 0, kind: "" });
  const COLS = [null, SPARK, HOT, FIRE, "rgba(201,196,228,0.5)"];
  let clock = 0, acc = 0, heroT = 0, enemyT = 0.9, boomT = 2, alive = 0;
  function flag(pri, what) { for (let i = 0; i < em.length; i++) if (em[i].pri === pri) { em[i][what]++; em[i].flag = 0.6; } }
  function spawn(pri, x, y, vx, vy, life) {
    let slot = -1;
    if (alive < D.budget) { for (let i = 0; i < N; i++) if (!P[i].on) { slot = i; break; } }
    if (slot < 0) {                                       // over budget: cull the worst priority's oldest, if it is worse than us
      let worst = -1;
      for (let q = 4; q > pri; q--) if (counts[q] > 0) { worst = q; break; }
      if (worst < 0) { flag(pri, "refused"); return; }
      let bt = Infinity;
      for (let i = 0; i < N; i++) if (P[i].on && P[i].pri === worst && P[i].born < bt) { bt = P[i].born; slot = i; }
      if (slot < 0) { flag(pri, "refused"); return; }
      counts[worst]--; alive--; flag(worst, "culled");
    }
    const p = P[slot];
    p.pri = pri; p.x = x; p.y = y; p.vx = vx; p.vy = vy; p.age = 0; p.life = life; p.born = clock; p.on = true;
    counts[pri]++; alive++;
  }
  function burst(pri, x, y, n, sp) { for (let k = 0; k < n; k++) { const a = rand(0, TAU), v = rand(0.3, 1) * sp; spawn(pri, x, y, Math.cos(a) * v, Math.sin(a) * v - H * 0.15, rand(0.5, 1)); } }
  const hx = W * 0.3, ex = W * 0.72;
  return {
    press(x, y) { burst(3, x, clamp(y, H * 0.4, GY), D.burst, H * 0.8); boomT = 0; },
    frame(dt, t) {
      stage({ night: 0.5 });
      clock += dt; heroT += dt; enemyT += dt; boomT += dt;
      if (heroT > 1.2) { heroT = 0; burst(1, hx, GY - H * 0.12, 12, H * 0.5); }
      if (enemyT > 1.8) { enemyT = 0; burst(2, ex, GY - H * 0.1, 10, H * 0.45); }
      if (boomT > D.every) { boomT = 0; burst(3, rand(W * 0.2, W * 0.8), rand(H * 0.45, GY - 4), D.burst, H * 0.8); }
      acc += D.ambient * dt;
      while (acc >= 1) { acc -= 1; spawn(4, rand(0, W), rand(H * 0.4, GY), 0, -H * 0.04, rand(1.5, 2.5)); }
      hero(hx, GY, { pose: "stand", frame: t });
      rect(ex - 6, GY - 16, 12, 16, "#6E3A3A"); dot(ex - 2, GY - 11, 1.2, INK); dot(ex + 2, GY - 11, 1.2, INK);
      const g = H * 1.3;
      for (let i = 0; i < N; i++) {
        const p = P[i];
        if (!p.on) continue;
        p.age += dt;
        if (p.age >= p.life) { p.on = false; counts[p.pri]--; alive--; continue; }
        if (p.pri < 4) { p.vy += g * dt; if (p.y > GY) { p.y = GY; p.vy *= -0.3; } }
        else p.vx = noise(p.y * 0.05 + t) * H * 0.05;
        p.x += p.vx * dt; p.y += p.vy * dt;
        const k = 1 - p.age / p.life;
        dot(p.x, p.y, p.pri < 4 ? 1.2 + k : 1, p.pri < 4 ? rgba(COLS[p.pri], 0.3 + k * 0.7) : rgba(BONE, k * 0.45));
      }
      // the meter: alive by priority against the budget line, on the pool's full width
      const mx = 8, mw = W - 16, my = 8, mh = 7;
      rect(mx, my, mw, mh, "rgba(201,196,228,0.12)");
      let x = mx;
      for (let q = 1; q <= 4; q++) { const w = mw * counts[q] / N; rect(x, my, w, mh, COLS[q]); x += w; }
      const bx = mx + mw * D.budget / N;
      line(bx, my - 3, bx, my + mh + 3, HOT, 1.5);
      label("budget " + D.budget, bx, my + mh + 12, HOT, bx > W * 0.8 ? "right" : "center");
      label("alive " + alive + " / pool " + N, W - 8, my + mh + 12, DIM, "right");
      // the priority table
      for (let i = 0; i < em.length; i++) {
        const e = em[i], y = my + mh + 24 + i * 11;
        e.flag = Math.max(0, e.flag - dt);
        rect(mx, y - 7, 6, 6, COLS[e.pri]);
        label(e.pri + " " + e.name, mx + 10, y, e.flag > 0 ? HOT : BONE);
        label("×" + counts[e.pri], mx + 88, y, BONE);
        if (e.flag > 0) label(e.culled > e.refused ? "CULLED" : "REFUSED", mx + 118, y, HOT);
        else if (e.culled || e.refused) label("culled " + e.culled + " · refused " + e.refused, mx + 118, y, DIM);
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Budget", "Bargain", "a budget of thirty: the dust never gets a slot, the enemy's hits are culled by every explosion, and only the hero's own sparks always land", { budget: 30, burst: 60 });
/* ============================== UI & HUD FEEDBACK ==============================
   The interface as an effect. A HUD is not a picture of the game's numbers —
   it is a set of small machines that LAG, CLAMP, PROJECT and QUEUE those
   numbers so a human can read them at speed: a health bar whose ghost drains
   after the hit, a cooldown wiped by an angle, digits that roll toward a
   score, an XP bar that carries its remainder, arrows clamped to the edge of
   the view, bubbles projected from world to screen every frame, a reticle
   that blooms, damage arcs that point, toasts that stack, a radar sweep, a
   placement ghost snapped to a grid, a rarity sheen, a boss bar that breaks.
   Every card here runs a tiny autopilot game that feeds its HUD element
   events, and draws the mechanism beside the element. */

def("H", "Healthbar", "hud", "red snaps to the new health; a white ghost waits, then drains after it — the chunk you just lost, visible; heals run ahead in green — press to hit", function (u) {
  var D = { max: 100,           // hit points
            hitEvery: 1.7,      // autopilot: seconds between hits
            hitMin: 8,          // damage per hit, from...
            hitMax: 26,         // ...to
            healEvery: 5.5,     // autopilot: seconds between heals
            heal: 34,           // hit points per heal
            delay: 0.25,        // the ghost waits this long before it moves
            drain: 0.5,         // then crosses the chunk in this many seconds
            segments: 0,        // 0 = a smooth bar; N = tick marks every max/N
            label: "red = hp (snaps) · ghost waits delay s, then → hp over drain s" };
  const { ctx, W, H, GY, TAU, stage, hero, rect, line, arrow, ring, text, label, rand, clamp, HOT, GOOD, INK, DIM, BONE } = u;
  // the lexicon's Lerp card taught the lag; here the lag IS the information.
  // the red bar snaps to hp the instant a hit lands (the truth, never late).
  // a second value, the GHOST, remembers where the bar WAS: it waits a beat
  // (delay) and then slides to hp over drain seconds, so the white gap
  // between them is the damage you just took, held on screen long enough to
  // read. a heal is the same machine mirrored: hp jumps up, the ghost lags
  // below it, and the gap is painted green — "this much is arriving".
  let hp = D.max, ghost = D.max, since = 9, chunk = 0, hitT = 0.6, healT = 2, hurt = 0;
  const N = 120, hist = new Float32Array(N * 2);
  let head = 0, sampleT = 0;
  for (let i = 0; i < N; i++) { hist[i * 2] = D.max; hist[i * 2 + 1] = D.max; }
  function change(d) { hp = clamp(hp + d, 0, D.max); since = 0; chunk = Math.abs(ghost - hp); }
  function hit() { change(-rand(D.hitMin, D.hitMax)); hurt = 0.35; }
  return {
    press() { hit(); },
    frame(dt, t) {
      stage({ plain: true });
      hitT += dt; if (hitT > D.hitEvery) { hitT = 0; hit(); }
      healT += dt; if (healT > D.healEvery || (hp <= 0 && healT > 1.2)) { healT = 0; change(D.heal); }
      since += dt; hurt = Math.max(0, hurt - dt);
      if (ghost !== hp && since >= D.delay) {          // the ghost: wait, then cross the chunk
        const v = (Math.max(chunk, 1) / Math.max(0.01, D.drain)) * dt;
        ghost = ghost > hp ? Math.max(hp, ghost - v) : Math.min(hp, ghost + v);
      }
      sampleT += dt;
      for (let n = 0; sampleT > 0.025 && n < 8; n++) { sampleT -= 0.025; hist[head * 2] = hp; hist[head * 2 + 1] = ghost; head = (head + 1) % N; }
      // the hero takes it
      const blink = hurt > 0 && Math.floor(hurt * 24) % 2 === 0;
      hero(W * 0.5, GY, { pose: hp <= 0 ? "crouch" : (hurt > 0 ? "hurt" : "stand"), frame: t, tint: blink ? "rgba(245,138,138,0.75)" : undefined });
      // the bar
      const bx = W * 0.1, by = H * 0.12, bw = W * 0.8, bh = H * 0.08, k = bw / D.max;
      rect(bx, by, bw, bh, "rgba(0,0,0,0.55)");
      rect(bx, by, Math.min(hp, ghost) * k, bh, HOT);
      const sz = Math.max(9, H * 0.06);
      if (ghost > hp) {                                // damage: the white ghost chunk
        rect(bx + hp * k, by, (ghost - hp) * k, bh, "rgba(255,255,255,0.88)");
        label("ghost −" + Math.round(ghost - hp), bx + (hp + ghost) * 0.5 * k, by + bh + 11, INK, "center");
      } else if (hp > ghost) {                         // heal: the bar lags, the gap is green
        rect(bx + ghost * k, by, (hp - ghost) * k, bh, GOOD);
        label("heal +" + Math.round(hp - ghost), bx + (hp + ghost) * 0.5 * k, by + bh + 11, GOOD, "center");
      }
      for (let i = 1; i < D.segments; i++) line(bx + i * bw / D.segments, by, bx + i * bw / D.segments, by + bh, "rgba(19,16,32,0.8)", 1.5);
      ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.strokeRect(bx, by, bw, bh);
      text(Math.round(hp) + " / " + D.max, bx + bw, by - 3, sz, BONE, "right");
      text("hp", bx, by - 3, sz, HOT);
      if (ghost !== hp && since < D.delay) {           // the wait, drawn as a tiny countdown
        const wx = bx + Math.max(hp, ghost) * k + 10, wy = by + bh / 2;
        ring(wx, wy, 4, DIM, 1);
        ctx.strokeStyle = INK; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(wx, wy, 4, -TAU / 4, -TAU / 4 + TAU * (since / D.delay)); ctx.stroke();
        label("wait", wx + 7, wy + 3, DIM);
      }
      // the history: hp (red) and ghost (white) over the last 3 s — the step and the lag
      const gx = W * 0.62, gy = H * 0.5, gw = W * 0.3, gh = H * 0.22;
      rect(gx, gy, gw, gh, "rgba(0,0,0,0.3)");
      ctx.lineWidth = 1.5;
      for (let ch = 0; ch < 2; ch++) {
        ctx.strokeStyle = ch ? "rgba(255,255,255,0.8)" : HOT;
        ctx.beginPath();
        for (let i = 0; i < N; i++) {
          const j = ((head + i) % N) * 2 + ch;
          const x = gx + gw * i / (N - 1), y = gy + gh - gh * hist[j] / D.max;
          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
      }
      label("last 3 s", gx, gy - 3, DIM);
      arrow(W * 0.28, H * 0.5, W * 0.28, by + bh + 2, DIM);
      label("snaps", W * 0.28, H * 0.5 + 11, HOT, "center");
      label("lags", W * 0.4, H * 0.5 + 11, INK, "center");
      arrow(W * 0.4, H * 0.5, W * 0.4, by + bh + 2, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Healthbar", "Hardcore", "no ghost delay and a near-instant drain on a bar cut into ten segments — the roguelike that refuses to soften the blow", { delay: 0, drain: 0.08, segments: 10 });

def("R", "Radial", "hud", "a conic wipe counts each cooldown down from 12 o'clock — angle = 2π · remaining/cooldown — and pops when ready — press to use the one under your click", function (u) {
  var D = { cooldowns: [2, 4.5, 8],  // seconds, one per ability icon
            dir: 1,                 // 1 = the wipe uncovers clockwise, −1 = counter-clockwise
            size: 0.16,             // icon half-size, of H
            pop: 0.3,               // the scale punch when an ability comes ready
            glowReady: false,       // a pulsing glow behind ready icons
            autoEvery: 1.2,         // autopilot: seconds between uses
            label: "sweep = 2π · remaining / cooldown, from 12 o'clock · 0 → pop" };
  const { ctx, W, H, TAU, stage, ring, line, poly, dot, glow, text, label, rand, rgba, beep, SUN, HERO, MAGIC, GOOD, BONE, INK, DIM, HOT } = u;
  // chapter 03's masks, on a clock. the locked part of the icon is a dark
  // PIE SLICE: one arc from the top (−90°) sweeping an angle proportional to
  // the time left — remaining / cooldown of a full turn — clipped to the
  // icon. as the number falls the slice thins, its leading edge is the hand
  // of a clock, and at zero the icon POPS (a scale punch and a ring, the
  // bestiary's Radiant decay) so the eye is told "ready" without reading.
  const n = D.cooldowns.length, cols = [SUN, HERO, MAGIC, GOOD];
  const rem = [], pop = [], jig = [], bursts = [];
  for (let i = 0; i < n; i++) { rem.push(i === 0 ? 0 : D.cooldowns[i] * (0.3 + 0.3 * i)); pop.push(9); jig.push(0); }
  let autoT = 0;
  function use(i, byHand) {
    if (rem[i] > 0) { jig[i] = 0.3; return; }         // not ready: a refusal jiggle
    rem[i] = D.cooldowns[i]; bursts.push({ i: i, age: 0 });
    if (bursts.length > 8) bursts.shift();
    if (byHand) beep(520 + i * 140, 0.07, "triangle");
  }
  function rr(x, y, w, h, r) {
    ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
  }
  function glyph(i, r, c) {
    if (i % 3 === 0) { line(-r * 0.45, r * 0.45, r * 0.45, -r * 0.45, c, 3); line(-r * 0.05, -r * 0.05, -r * 0.35, -r * 0.35, c, 1); line(-r * 0.3, r * 0.05, -r * 0.05, r * 0.3, c, 3); }
    else if (i % 3 === 1) poly([[-r * 0.45, -r * 0.45], [r * 0.45, -r * 0.45], [r * 0.45, r * 0.05], [0, r * 0.5], [-r * 0.45, r * 0.05]], c);
    else poly([[-r * 0.1, -r * 0.55], [r * 0.35, -r * 0.1], [r * 0.05, -r * 0.1], [r * 0.15, r * 0.55], [-r * 0.35, 0], [-r * 0.05, 0]], c);
  }
  function xOf(i) { return W * (0.5 + (i - (n - 1) / 2) * 0.27); }
  return {
    press(x) {
      let best = 0, bd = 1e9;
      for (let i = 0; i < n; i++) { const d = Math.abs(xOf(i) - x); if (d < bd) { bd = d; best = i; } }
      use(best, true);
    },
    frame(dt, t) {
      stage({ plain: true });
      autoT += dt;
      if (autoT > D.autoEvery) {                       // autopilot: use something that is ready
        autoT = 0;
        const ready = [];
        for (let i = 0; i < n; i++) if (rem[i] <= 0) ready.push(i);
        if (ready.length) use(ready[Math.floor(rand(0, ready.length)) % ready.length]);
      }
      const r = H * D.size, y = H * 0.44, sz = Math.max(9, H * 0.06);
      let shownAngle = 0;
      for (let i = 0; i < n; i++) {
        if (rem[i] > 0) { rem[i] -= dt; if (rem[i] <= 0) { rem[i] = 0; pop[i] = 0; } }
        pop[i] += dt; jig[i] = Math.max(0, jig[i] - dt);
        const x = xOf(i), c = cols[i % cols.length], cd = D.cooldowns[i];
        const s = 1 + D.pop * Math.sin(Math.min(1, pop[i] / 0.35) * Math.PI);
        const dx = jig[i] > 0 ? Math.sin(jig[i] * 60) * 3 : 0;
        ctx.save();
        ctx.translate(x + dx, y); ctx.scale(s, s);
        if (D.glowReady && rem[i] <= 0) glow(0, 0, r * 1.7, c, 0.35 + 0.15 * Math.sin(t * 4 + i));
        rr(-r, -r, 2 * r, 2 * r, r * 0.25);
        ctx.fillStyle = "#262040"; ctx.fill();
        ctx.strokeStyle = rem[i] > 0 ? "rgba(201,196,228,0.4)" : c; ctx.lineWidth = rem[i] > 0 ? 1 : 2; ctx.stroke();
        glyph(i, r, rem[i] > 0 ? "rgba(201,196,228,0.5)" : c);
        if (rem[i] > 0) {                              // the locked slice: one arc from the top
          const frac = rem[i] / Math.max(0.01, cd), a1 = -TAU / 4 + D.dir * TAU * frac;
          ctx.save();
          rr(-r, -r, 2 * r, 2 * r, r * 0.25); ctx.clip();
          ctx.fillStyle = "rgba(0,0,0,0.62)";
          ctx.beginPath(); ctx.moveTo(0, 0); ctx.arc(0, 0, r * 1.6, -TAU / 4, a1, D.dir < 0); ctx.closePath(); ctx.fill();
          line(0, 0, Math.cos(a1) * r * 1.5, Math.sin(a1) * r * 1.5, "rgba(255,255,255,0.7)", 1.5);
          ctx.restore();
          text(rem[i].toFixed(1), 0, r * 0.32, r * 0.85, INK, "center", true);
          if (i === 0 || shownAngle === 0) shownAngle = TAU * frac;
        }
        ctx.restore();
        label(cd + " s", x, y + r + 12, DIM, "center");
        if (rem[i] <= 0) label("ready", x, y - r - 5, c, "center");
      }
      for (let b = bursts.length - 1; b >= 0; b--) {   // the ready ring, expanding
        const k = bursts[b]; k.age += dt;
        if (k.age > 0.5) { bursts.splice(b, 1); continue; }
        ring(xOf(k.i), y, r * (1 + k.age * 2), rgba(cols[k.i % cols.length], 1 - k.age / 0.5), 2);
      }
      // the angle, named
      const ax = W * 0.12, ay = H * 0.82;
      ring(ax, ay, 9, DIM, 1);
      ctx.strokeStyle = SUN; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(ax, ay, 9, -TAU / 4, -TAU / 4 + D.dir * shownAngle, D.dir < 0); ctx.stroke();
      label("θ = " + Math.round(shownAngle / TAU * 360) + "°", ax + 14, ay + 4, SUN);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Radial", "Rune", "the wipe runs counter-clockwise and a ready rune breathes a glow behind its icon, with a bigger pop — the spellbook's version", { dir: -1, glowReady: true, pop: 0.5 });

def("O", "Odometer", "hud", "a score tweens to its value with an ease-out and comma grouping; each drum slides only on its carry — the folio's Odometer, live — press to add score", function (u) {
  var D = { tween: 0.9,          // seconds from the old value to the new
            gainMin: 80,         // a gain, from...
            gainMax: 3600,       // ...to
            autoEvery: 2.4,      // autopilot: seconds between gains
            snap: false,         // true = no tween, the value jumps
            punch: 0,            // a scale punch on each gain (0 = none)
            digits: 7,           // drums on the counter
            label: "shown = from + (to − from) · (1 − (1 − k)³) · drum i slides on its carry" };
  const { ctx, W, H, stage, rect, line, dot, text, label, rand, clamp, beep, SUN, INK, DIM, BONE, GOOD } = u;
  // a COUNT-UP is a tween between two numbers: k runs 0 → 1 over tween
  // seconds, an ease-out (1 − (1 − k)³) makes the last digits settle
  // slowly, and the number you draw is shown, never the target. the
  // drums are the folio's Odometer: the ones drum slides by frac(shown);
  // a higher drum only slides during the last tenth of the drum beneath
  // it — the CARRY, drawn. commas are placed every third drum from the right.
  let target = 12480, from = target, shown = target, k = 1, autoT = 0, punchT = 9;
  const pops = [];
  function fmt(n) { return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ","); }
  function add(n, hand) {
    from = shown; target += n; k = 0; punchT = 0;
    pops.push({ n: n, age: 0 }); if (pops.length > 5) pops.shift();
    if (D.snap) shown = target;
    if (hand) beep(880, 0.06, "square");
  }
  return {
    press() { add(Math.round(rand(D.gainMin, D.gainMax)), true); },
    frame(dt, t) {
      stage({ plain: true });
      autoT += dt; if (autoT > D.autoEvery) { autoT = 0; add(Math.round(rand(D.gainMin, D.gainMax))); }
      const cap = Math.pow(10, D.digits);
      if (target >= cap) { target %= cap; from = 0; shown = target; k = 1; }
      if (D.snap) { shown = target; k = 1; }
      else { k = Math.min(1, k + dt / Math.max(0.01, D.tween)); shown = from + (target - from) * (1 - Math.pow(1 - k, 3)); }
      punchT += dt;
      // the drums
      const dw = Math.min(W * 0.08, H * 0.13), dh = dw * 1.4, commas = Math.floor((D.digits - 1) / 3);
      const total = D.digits * dw + commas * dw * 0.4, x0 = W / 2 - total / 2, cy = H * 0.36;
      const s = 1 + D.punch * Math.exp(-punchT * 9);
      ctx.save();
      ctx.translate(W / 2, cy); ctx.scale(s, s); ctx.translate(-W / 2, -cy);
      ctx.font = "700 " + (dw * 1.05) + "px 'Spline Sans Mono', Consolas, monospace";
      ctx.textAlign = "center"; ctx.textBaseline = "middle";
      let cur = x0;
      for (let i = D.digits - 1; i >= 0; i--) {
        const p = Math.pow(10, i), q = shown / p, d = Math.floor(q) % 10;
        const slide = i === 0 ? q - Math.floor(q) : clamp((q - Math.floor(q)) * p - (p - 1), 0, 1);
        const lead = i > 0 && Math.floor(q) === 0;
        rect(cur, cy - dh / 2, dw, dh, "rgba(28,24,44,0.95)");
        ctx.save();
        ctx.beginPath(); ctx.rect(cur, cy - dh / 2, dw, dh); ctx.clip();
        ctx.fillStyle = lead ? "rgba(245,193,105,0.25)" : SUN;
        ctx.fillText(String(d), cur + dw / 2, cy + slide * dh);
        ctx.fillText(String((d + 1) % 10), cur + dw / 2, cy + (slide - 1) * dh);
        ctx.restore();
        ctx.strokeStyle = "rgba(201,196,228,0.5)"; ctx.lineWidth = 1; ctx.strokeRect(cur, cy - dh / 2, dw, dh);
        if (slide > 0.001 && slide < 0.999 && i > 0) label("carry", cur + dw / 2, cy - dh / 2 - 4, GOOD, "center");
        cur += dw;
        if (i > 0 && i % 3 === 0) { ctx.fillStyle = BONE; ctx.fillText(",", cur + dw * 0.2, cy + dh * 0.3); cur += dw * 0.4; }
      }
      ctx.restore();
      ctx.textBaseline = "alphabetic";
      const sz = Math.max(9, H * 0.06);
      text("target " + fmt(target), W / 2, cy + dh / 2 + sz * 1.4, sz, BONE, "center");
      // the easing, graphed, with k on it
      const gx = W * 0.1, gy = H * 0.6, gw = W * 0.3, gh = H * 0.2;
      rect(gx, gy, gw, gh, "rgba(0,0,0,0.3)");
      ctx.strokeStyle = DIM; ctx.lineWidth = 1; ctx.beginPath();
      for (let i = 0; i <= 20; i++) { const kk = i / 20, e = D.snap ? (kk > 0 ? 1 : 0) : 1 - Math.pow(1 - kk, 3); const x = gx + gw * kk, y = gy + gh - gh * e; if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y); }
      ctx.stroke();
      const ek = D.snap ? 1 : 1 - Math.pow(1 - k, 3);
      dot(gx + gw * k, gy + gh - gh * ek, 3, SUN);
      label("k = " + k.toFixed(2) + (D.snap ? " (snap)" : " · tween " + D.tween + " s"), gx, gy + gh + 11, DIM);
      // the gains, rising like the grimoire's Rise up
      for (let i = pops.length - 1; i >= 0; i--) {
        const p = pops[i]; p.age += dt;
        if (p.age > 1.2) { pops.splice(i, 1); continue; }
        const e = 1 - Math.pow(1 - Math.min(1, p.age / 1.2), 2);
        ctx.globalAlpha = 1 - p.age / 1.2;
        text("+" + fmt(p.n), W * 0.75, cy + dh / 2 + sz * 3 - e * H * 0.22, sz * 1.2, GOOD, "center", true);
        ctx.globalAlpha = 1;
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Odometer", "Overdrive", "no tween: the value snaps and the whole counter takes a scale punch instead — the arcade cabinet's way of saying more", { snap: true, punch: 0.4, autoEvery: 1.2 });

def("X", "Xpbar", "hud", "the bar fills, flashes, levels up and carries the remainder into a longer bar — need(L) grows by a ratio each level — press to gain xp", function (u) {
  var D = { base: 100,           // xp needed for level 2
            growth: 1.4,         // each level needs this many times more
            gainMin: 15,         // a gain, from...
            gainMax: 60,         // ...to
            autoEvery: 1.1,      // autopilot: seconds between gains
            fillTime: 0.45,      // a whole bar fills in this many seconds
            flash: 0.3,          // the level-up flash, seconds
            label: "need(L) = base · growth^(L−1) · shown ≥ need → L+1, xp −= need (the carry)" };
  const { ctx, W, H, GY, stage, hero, rect, line, ring, text, label, rand, clamp, ease, tone, SUN, GOOD, HERO, INK, BONE, DIM, SPARK } = u;
  // two numbers: xp (the truth, it may run far past the bar) and shown (the
  // bar, which fills toward xp at a steady rate). when shown reaches the
  // threshold the bar FLASHES, the level ticks, and BOTH subtract need — the
  // remainder is carried into the next bar, which is longer, because
  // need(L) is a geometric series. a big gain can lap several bars in a row:
  // each lap is one flash, one carry. the column of light is the folio's Levelup.
  let level = 1, xp = 0, shown = 0, flashT = 9, upT = 9, autoT = 0, armed = false, carry = 0, carryT = 9;
  const pops = [];
  function need(L) { return Math.round(D.base * Math.pow(D.growth, L - 1)); }
  function gain(n) { xp += n; pops.push({ n: n, age: 0 }); if (pops.length > 5) pops.shift(); }
  return {
    press() { armed = true; gain(Math.round(rand(D.gainMin, D.gainMax))); },
    frame(dt, t) {
      stage({ plain: true });
      autoT += dt; if (autoT > D.autoEvery) { autoT = 0; gain(Math.round(rand(D.gainMin, D.gainMax))); }
      let nd = need(level);
      const rate = nd / Math.max(0.05, D.fillTime);
      if (shown < xp) shown = Math.min(xp, shown + rate * dt);
      if (shown >= nd - 1e-6 && xp >= nd) {            // LEVEL UP: flash, tick, carry the rest
        xp -= nd; shown = 0; level++; flashT = 0; upT = 0; carry = xp; carryT = 0;
        if (armed) tone({ freq: 523, slideTo: 1046, dur: 0.22, type: "triangle", vol: 0.1 });
        if (level > 40) { level = 1; xp = Math.min(xp, 40); }
        nd = need(level);
      }
      flashT += dt; upT += dt; carryT += dt;
      const sz = Math.max(9, H * 0.06);
      const bx = W * 0.22, by = H * 0.2, bw = W * 0.68, bh = H * 0.075;
      rect(bx, by, bw, bh, "rgba(0,0,0,0.55)");
      rect(bx, by, bw * clamp(shown / nd, 0, 1), bh, HERO);
      if (flashT < D.flash) rect(bx, by, bw, bh, "rgba(255,255,255," + (0.9 * (1 - flashT / D.flash)) + ")");
      ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.strokeRect(bx, by, bw, bh);
      text(Math.floor(Math.min(shown, xp)) + " / " + nd, bx + bw, by - 3, sz, BONE, "right");
      if (xp > nd) text("overflow +" + Math.round(xp - nd) + " → carries", bx + bw, by + bh + sz * 1.2, sz, SUN, "right");
      if (carryT < 1.6) { ctx.globalAlpha = 1 - carryT / 1.6; text("carried " + Math.round(carry), bx + 4, by + bh + sz * 1.2 + carryT * 4, sz, GOOD); ctx.globalAlpha = 1; }
      // the level badge, punching on the tick
      const ps = 1 + 0.4 * Math.sin(Math.min(1, upT / 0.35) * Math.PI);
      const cxb = bx - bh * 1.2, cyb = by + bh / 2;
      ctx.save(); ctx.translate(cxb, cyb); ctx.scale(ps, ps);
      ctx.fillStyle = "#262040"; ctx.beginPath(); ctx.arc(0, 0, bh * 0.95, 0, Math.PI * 2); ctx.fill();
      ring(0, 0, bh * 0.95, upT < 0.35 ? SPARK : SUN, 1.5);
      text("Lv " + level, 0, bh * 0.35, bh * 0.9, INK, "center", true);
      ctx.restore();
      // the ladder: the next thresholds, each longer than the last
      const lx = W * 0.5, ly = H * 0.42, lw = W * 0.4, lh = H * 0.045, top = need(level + 4);
      for (let j = 0; j < 5; j++) {
        const L = level + j, w = lw * need(L) / top, y = ly + j * (lh + 3);
        rect(lx, y, w, lh, j === 0 ? "rgba(138,217,245,0.6)" : "rgba(201,196,228,0.25)");
        label("L" + L + " needs " + need(L), lx + w + 4, y + lh - 1, j === 0 ? HERO : DIM);
      }
      label("need(L) grows ×" + D.growth, lx, ly - 4, DIM);
      // the hero and the folio's column of light
      const hx = W * 0.22;
      if (upT < 1) {
        const a = upT < 0.15 ? upT / 0.15 : (1 - upT) / 0.85;
        const g = ctx.createLinearGradient(0, GY, 0, GY - H * 0.45);
        g.addColorStop(0, "rgba(245,193,105," + (a * 0.4) + ")"); g.addColorStop(1, "rgba(245,193,105,0)");
        ctx.fillStyle = g; ctx.fillRect(hx - H * 0.07, GY - H * 0.45, H * 0.14, H * 0.45);
        for (let j = 0; j < 3; j++) {
          const p = (upT * 1.4 + j / 3) % 1, y = GY - 8 - p * H * 0.35, al = Math.sin(p * Math.PI) * a;
          line(hx - 6, y + 4, hx, y - 2, "rgba(245,220,150," + al + ")", 2); line(hx, y - 2, hx + 6, y + 4, "rgba(245,220,150," + al + ")", 2);
        }
      }
      hero(hx, GY, { pose: upT < 0.5 ? "jump" : "stand", frame: t });
      for (let i = pops.length - 1; i >= 0; i--) {
        const p = pops[i]; p.age += dt;
        if (p.age > 1) { pops.splice(i, 1); continue; }
        ctx.globalAlpha = 1 - p.age; text("+" + p.n + " xp", hx + H * 0.12, GY - H * 0.3 - p.age * H * 0.1, sz, GOOD); ctx.globalAlpha = 1;
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Xpbar", "Xpsurge", "gains ten times bigger and a bar that fills in a quarter second — several level-ups lap through one bar, carry after carry", { gainMin: 150, gainMax: 420, fillTime: 0.25 });

def("O", "Offscreen", "hud", "targets orbit outside the view; each is clamped to the view's edge and an arrow points from there, with the distance — press to add one that way", function (u) {
  var D = { targets: 3,          // orbiting targets at the start
            orbitX: 0.4,         // orbit radius, of W...
            orbitY: 0.42,        // ...and of H
            wobble: 0.3,         // the radius breathes by this fraction (so targets visit the view)
            speed: 0.45,         // radians per second, roughly
            margin: 12,          // arrows sit this far inside the view's edge
            style: "arrow",      // "arrow" = edge arrows · "radar" = a ring of blips
            radarR: 0.16,        // the radar ring radius, of H
            label: "p' = clamp(p, view ± margin) · arrow angle = atan2(p − p') · d = |p − p'|" };
  const { ctx, W, H, TAU, stage, hero, rect, line, ring, dot, poly, text, label, rand, clamp, len, rgba, HOT, SUN, HERO, GOOD, MAGIC, BONE, INK, DIM } = u;
  // the lexicon's Xhair aimed at a thing on screen; this is for the thing
  // that is not. the middle rectangle is the VIEW (the player's screen); the
  // targets live in the world around it. CLAMP each target's position into
  // the view (minus a margin) — that is where its arrow sits — and point
  // the arrow along the vector from the clamped point back to the true
  // position; that vector's length is the distance you print. a target that
  // wanders into the view needs no arrow, so it simply gets drawn.
  const v = { x0: W * 0.22, y0: H * 0.17, x1: W * 0.78, y1: H * 0.8 };
  const cx = (v.x0 + v.x1) / 2, cy = (v.y0 + v.y1) / 2;
  const cols = [HOT, SUN, MAGIC, GOOD], targets = [];
  function add(a) {
    targets.push({ a: a, w: rand(0.6, 1.4) * D.speed * (rand(0, 1) < 0.5 ? -1 : 1), ph: rand(0, TAU), wf: rand(0.3, 0.7), c: cols[targets.length % cols.length], x: 0, y: 0 });
    if (targets.length > 8) targets.shift();
  }
  for (let i = 0; i < D.targets; i++) add(i * TAU / Math.max(1, D.targets) + 0.4);
  return {
    press(x, y) { add(Math.atan2(y - cy, x - cx)); },
    frame(dt, t) {
      stage({ plain: true });
      rect(v.x0, v.y0, v.x1 - v.x0, v.y1 - v.y0, "rgba(255,255,255,0.05)");
      ctx.strokeStyle = BONE; ctx.lineWidth = 1.5; ctx.strokeRect(v.x0, v.y0, v.x1 - v.x0, v.y1 - v.y0);
      label("the view", v.x0 + 4, v.y0 + 11, DIM);
      hero(cx, cy + H * 0.12, { frame: t });
      const m = D.margin, rr = H * D.radarR, rcx = v.x1 - rr - 5, rcy = v.y0 + rr + 5;
      const range = Math.max(W * D.orbitX, H * D.orbitY) * (1 + D.wobble);
      if (D.style === "radar") {
        ctx.fillStyle = "rgba(0,0,0,0.5)"; ctx.beginPath(); ctx.arc(rcx, rcy, rr, 0, TAU); ctx.fill();
        ring(rcx, rcy, rr, BONE, 1); ring(rcx, rcy, rr * 0.5, DIM, 1);
        line(rcx, rcy, rcx + Math.cos(t * 1.6) * rr, rcy + Math.sin(t * 1.6) * rr, GOOD, 1);
        dot(rcx, rcy, 2, HERO);
      }
      for (let i = 0; i < targets.length; i++) {
        const g = targets[i];
        g.a += g.w * dt;
        const k = 1 + D.wobble * Math.sin(t * g.wf + g.ph);
        g.x = cx + Math.cos(g.a) * W * D.orbitX * k; g.y = cy + Math.sin(g.a) * H * D.orbitY * k;
        const inside = g.x > v.x0 + m && g.x < v.x1 - m && g.y > v.y0 + m && g.y < v.y1 - m;
        // the world: the target itself, dim when outside the view
        poly([[g.x, g.y - 6], [g.x + 5, g.y], [g.x, g.y + 6], [g.x - 5, g.y]], inside ? g.c : rgba(g.c, 0.3));
        if (inside) { dot(g.x - 1.5, g.y - 1, 1, "#131020"); continue; }
        // the clamp, the arrow, the distance
        const qx = clamp(g.x, v.x0 + m, v.x1 - m), qy = clamp(g.y, v.y0 + m, v.y1 - m);
        const ang = Math.atan2(g.y - qy, g.x - qx), d = len(g.x - qx, g.y - qy);
        if (D.style === "radar") {
          const kk = rr / range, bx = rcx + (g.x - cx) * kk, by = rcy + (g.y - cy) * kk;
          const bd = len(bx - rcx, by - rcy), sc = bd > rr - 2 ? (rr - 2) / bd : 1;
          dot(rcx + (bx - rcx) * sc, rcy + (by - rcy) * sc, 2.5, g.c);
          if (i === 0) { ctx.setLineDash([2, 3]); line(rcx, rcy, g.x, g.y, rgba(g.c, 0.35), 1); ctx.setLineDash([]); }
          continue;
        }
        ctx.save(); ctx.translate(qx, qy); ctx.rotate(ang);
        poly([[7, 0], [-4, -5], [-2, 0], [-4, 5]], g.c);
        ctx.restore();
        label(Math.round(d / 4) + " m", qx + (qx < cx ? 10 : -10), qy + (qy < cy ? 14 : -6), g.c, qx < cx ? "left" : "right");
        if (i === 0) {                                 // one target annotated in full
          ctx.setLineDash([2, 3]); line(qx, qy, g.x, g.y, rgba(g.c, 0.45), 1); ctx.setLineDash([]);
          ring(qx, qy, 4, INK, 1);
          label("p'", qx + (qx < cx ? 10 : -10), qy + (qy < cy ? 26 : -18), INK, qx < cx ? "left" : "right");
          label("p", g.x + 8, g.y - 8, DIM);
        }
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Offscreen", "Overwatch", "the same targets on a radar ring in the view's corner — a scaled position clamped to the ring's edge instead of the screen's — five of them", { style: "radar", targets: 5 });

def("A", "Anchor", "hud", "speech bubbles project a world point to the screen each frame — the tail stays on the speaker as the camera pans, the box clamps to the view — drag", function (u) {
  var D = { world: 2.4,          // the world is this many screens wide
            speakers: 3,         // talking NPCs
            style: "bubble",     // "bubble" = a typed speech box · "tag" = a name tag with a leader line
            boxW: 0.32,          // widest box, of W
            margin: 6,           // the box never comes closer than this to the view's edge
            autoPan: 0.35,       // autopilot camera sweep, radians per second
            cps: 16,             // typed characters per second
            hold: 2.2,           // seconds a finished line stays up
            label: "sx = wx − cam · box.x = clamp(sx − w/2, m, W − w − m) · tail → (sx, head)" };
  const { ctx, W, H, GY, stage, hero, tree, crate, house, rect, line, poly, dot, text, label, clamp, smooth, rng, HERO, SUN, GOOD, MAGIC, HOT, BONE, INK, DIM } = u;
  // the grimoire's Dialogue box sat still; a game's bubbles are pinned to
  // moving things. every frame: PROJECT the speaker's world x to the screen
  // (sx = wx − cam), put the box above the head, then CLAMP the box inside
  // the view — the tail is drawn last, from the box's bottom edge (its base
  // clamped inside the box) to the head, so it stretches and leans instead
  // of leaving. an off-screen speaker keeps a box at the edge, tail pointing out.
  const WORLD = W * D.world, seed = rng(11);
  const names = ["Mira", "Otto", "Pip", "Sol", "Vex"], shirts = [HERO, GOOD, MAGIC, SUN, HOT];
  const lines = [["hello there!", "the box clamps to the view", "my tail stays on me"], ["pan the camera", "not the words", "world → screen, every frame"], ["sx = wx − cam", "that is the projection", "bye!"], ["still anchored", "even off-screen"], ["look up"]];
  const sp = [], props = [];
  for (let i = 0; i < D.speakers; i++) sp.push({ wx: WORLD * (0.12 + 0.76 * (D.speakers > 1 ? i / (D.speakers - 1) : 0.5)), name: names[i % 5], shirt: shirts[i % 5], set: lines[i % 5], li: 0, prog: i * 3, hold: 0, bx: 0, by: 0, bw: 0, bh: 0, tw: 0, face: i % 2 ? -1 : 1 });
  for (let i = 0; i < 14; i++) props.push({ wx: seed() * WORLD, kind: seed() < 0.6 ? 0 : (seed() < 0.5 ? 1 : 2), s: 0.6 + seed() * 0.6 });
  let cam = 0, camT = 0, lastPress = -9, now = 0;
  const words = [];
  function wrap(txt, maxW) {                            // greedy word wrap into at most three lines
    words.length = 0;
    const ws = txt.split(" "); let cur = "";
    for (let i = 0; i < ws.length; i++) {
      const tryS = cur ? cur + " " + ws[i] : ws[i];
      if (ctx.measureText(tryS).width > maxW && cur) { words.push(cur); cur = ws[i]; } else cur = tryS;
      if (words.length === 3) break;
    }
    if (cur && words.length < 3) words.push(cur);
    return words;
  }
  return {
    drag: true,
    press(x) { camT = clamp(x / W, 0, 1) * (WORLD - W); lastPress = now; },
    frame(dt, t) {
      now = t;
      if (t - lastPress > 3) camT = (WORLD - W) * (0.5 + 0.5 * Math.sin(t * D.autoPan));
      cam += (camT - cam) * smooth(4, dt);
      stage();
      for (let i = 0; i < props.length; i++) {
        const p = props[i], x = p.wx - cam;
        if (x < -60 || x > W + 60) continue;
        if (p.kind === 0) tree(x, GY, H * 0.16 * p.s); else if (p.kind === 1) crate(x, GY, H * 0.09 * p.s); else house(x, GY, H * 0.18, H * 0.16, true);
      }
      const s = Math.max(2, Math.round(H / 60)), headY = GY - 17 * s, sz = Math.max(9, H * 0.058), m = D.margin;
      ctx.font = sz + "px system-ui, sans-serif";
      for (let i = 0; i < sp.length; i++) {
        const k = sp[i], sx = k.wx - cam;
        if (sx > -30 && sx < W + 30) hero(sx, GY, { shirt: k.shirt, face: k.face, frame: t });
        const line0 = k.set[k.li % k.set.length];
        k.prog += dt * D.cps;
        if (k.prog >= line0.length) { k.hold += dt; if (k.hold > D.hold) { k.hold = 0; k.prog = 0; k.li++; } }
        // the projection and the clamp
        if (D.style === "tag") {
          ctx.font = sz + "px system-ui, sans-serif";
          k.bw = ctx.measureText(k.name).width + sz; k.bh = sz * 1.5;
        } else {
          const ls = wrap(line0, W * D.boxW - sz);
          k.tw = 0; for (let j = 0; j < ls.length; j++) k.tw = Math.max(k.tw, ctx.measureText(ls[j]).width);
          k.bw = Math.min(W - 2 * m, k.tw + sz * 1.1); k.bh = ls.length * sz * 1.25 + sz * 0.7;
        }
        k.bx = clamp(sx - k.bw / 2, m, Math.max(m, W - k.bw - m));
        k.by = headY - sz * 1.1 - k.bh - (D.style === "tag" ? sz * 0.6 : 0);
        for (let j = 0; j < i; j++) {                   // stacked when two boxes collide
          const o = sp[j];
          if (k.bx < o.bx + o.bw && k.bx + k.bw > o.bx && Math.abs(k.by - o.by) < k.bh) k.by = o.by - k.bh - 3;
        }
        const tipX = clamp(sx, 3, W - 3);
        if (D.style === "tag") {
          line(clamp(sx, k.bx + 4, k.bx + k.bw - 4), k.by + k.bh, tipX, headY - 2, BONE, 1);
          dot(tipX, headY - 2, 2, k.shirt);
          rect(k.bx, k.by, k.bw, k.bh, "rgba(20,16,38,0.9)");
          ctx.strokeStyle = k.shirt; ctx.lineWidth = 1; ctx.strokeRect(k.bx, k.by, k.bw, k.bh);
          text(k.name, k.bx + k.bw / 2, k.by + k.bh - sz * 0.4, sz, INK, "center");
        } else {
          const tb = clamp(sx, k.bx + sz, k.bx + k.bw - sz);
          poly([[tb - sz * 0.45, k.by + k.bh - 1], [tb + sz * 0.45, k.by + k.bh - 1], [tipX, headY - 2]], "rgba(20,16,38,0.92)");
          line(tb - sz * 0.45, k.by + k.bh - 1, tipX, headY - 2, BONE, 1); line(tb + sz * 0.45, k.by + k.bh - 1, tipX, headY - 2, BONE, 1);
          rect(k.bx, k.by, k.bw, k.bh, "rgba(20,16,38,0.92)");
          ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.strokeRect(k.bx, k.by, k.bw, k.bh);
          const ls = wrap(line0, W * D.boxW - sz);
          let shownChars = Math.floor(k.prog);
          for (let j = 0; j < ls.length; j++) {
            const part = ls[j].slice(0, Math.max(0, shownChars)); shownChars -= ls[j].length + 1;
            text(part, k.bx + sz * 0.55, k.by + sz * 1.2 + j * sz * 1.25, sz, INK);
          }
          if (k.prog >= line0.length && Math.sin(t * 4) > 0) poly([[k.bx + k.bw - sz, k.by + k.bh - sz * 0.5], [k.bx + k.bw - sz * 0.4, k.by + k.bh - sz * 0.5], [k.bx + k.bw - sz * 0.7, k.by + k.bh - sz * 0.15]], BONE);
        }
        if (i === 0) label("sx = " + Math.round(k.wx) + " − " + Math.round(cam) + " = " + Math.round(sx), W / 2, H - 20, DIM, "center");
      }
      // the world strip: the whole world, the window, the speakers
      const bw = W * 0.8, bx0 = W * 0.1, by0 = 8;
      line(bx0, by0, bx0 + bw, by0, DIM, 1);
      poly([[bx0 + cam / WORLD * bw, by0 - 4], [bx0 + (cam + W) / WORLD * bw, by0 - 4], [bx0 + (cam + W) / WORLD * bw, by0 + 4], [bx0 + cam / WORLD * bw, by0 + 4]], "rgba(232,229,244,0.5)", true);
      for (let i = 0; i < sp.length; i++) dot(bx0 + sp[i].wx / WORLD * bw, by0, 2.5, sp[i].shirt);
      label("cam = " + Math.round(cam), bx0, by0 + 14, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Anchor", "Annotate", "name tags instead of speech: a small label with a thin leader line to each head, still projected and clamped every frame", { style: "tag", boxW: 0.16 });

def("X", "Xhair", "hud", "a reticle whose spread blooms per shot and shrinks at rest; shots land inside it, a hit flashes an X marker — press to fire, hold to keep firing", function (u) {
  var D = { spreadMin: 5,        // the tightest reticle, px
            spreadMax: 42,       // the widest, px
            bloom: 7,            // px added per shot
            recover: 28,         // px removed per second at rest
            fireRate: 9,         // shots per second while held
            marker: 0.22,        // the hit marker's life, seconds
            autoEvery: 2.6,      // autopilot: seconds between bursts
            burst: 6,            // shots per autopilot burst
            targetR: 0.075,      // the bullseye radius, of H
            label: "spread += bloom per shot · spread −= recover · dt · shot = c + disc(spread)" };
  const { ctx, W, H, TAU, stage, ring, line, dot, rect, text, label, rand, clamp, len, smooth, HOT, SUN, INK, DIM, BONE, GOOD } = u;
  // the lexicon's Xhair followed a target; this one tells the truth about
  // aim. SPREAD is a radius: every shot adds bloom to it, every idle second
  // takes recover off it, clamped between min and max — so the reticle's
  // four ticks walk outward while you hold fire and creep back when you
  // stop. each shot lands at a random point INSIDE that disc (√rand keeps
  // it uniform). a shot inside the bullseye paints the HIT MARKER: four
  // short diagonals that flash for marker seconds. the graph is spread(t).
  let cx = W / 2, cy = H * 0.45, spread = D.spreadMin, lastPress = -9, now = 0, acc = 0, autoT = 1.5, pending = 0, shots = 0, hits = 0, marker = 9, holding = false, tx = cx, ty = cy;
  const holes = [], N = 120, hist = new Float32Array(N);
  let head = 0, sampleT = 0;
  function fire() {
    const r = spread * Math.sqrt(Math.random()), a = Math.random() * TAU;
    const sx = cx + Math.cos(a) * r, sy = cy + Math.sin(a) * r;
    shots++;
    if (len(sx - tx, sy - ty) < H * D.targetR) { hits++; marker = 0; }
    holes.push({ x: sx, y: sy, age: 0 }); if (holes.length > 40) holes.shift();
    spread = Math.min(D.spreadMax, spread + D.bloom);
  }
  return {
    drag: true,
    press(x, y) {
      cx = x; cy = y;
      if (now - lastPress > 0.3) { fire(); acc = 0; }  // the first shot of a hold lands at once
      lastPress = now;
    },
    frame(dt, t) {
      now = t; holding = (t - lastPress) < 0.12;
      tx = W / 2 + Math.sin(t * 0.6) * W * 0.28; ty = H * 0.45 + Math.sin(t * 0.9 + 1) * H * 0.16;
      if (!holding) {
        autoT += dt;
        if (autoT > D.autoEvery && pending === 0) { autoT = 0; pending = D.burst; }
        if (t - lastPress > 1.5) { cx += (tx - cx) * smooth(3, dt); cy += (ty - cy) * smooth(3, dt); }
      }
      if (holding || pending > 0) {
        acc += dt * D.fireRate;
        for (let n = 0; acc >= 1 && n < 8; n++) { acc -= 1; fire(); if (pending > 0) pending--; if (pending === 0 && !holding) { acc = 0; break; } }
      } else acc = 0;
      spread = Math.max(D.spreadMin, spread - D.recover * dt);
      marker += dt;
      sampleT += dt;
      for (let n = 0; sampleT > 0.033 && n < 6; n++) { sampleT -= 0.033; hist[head] = spread; head = (head + 1) % N; }
      stage({ plain: true });
      // the bullseye, the holes
      const tr = H * D.targetR;
      dot(tx, ty, tr, BONE); dot(tx, ty, tr * 0.66, HOT); dot(tx, ty, tr * 0.33, BONE);
      for (let i = holes.length - 1; i >= 0; i--) {
        const h = holes[i]; h.age += dt;
        if (h.age > 2.5) { holes.splice(i, 1); continue; }
        dot(h.x, h.y, 2, "rgba(0,0,0," + (0.75 * (1 - h.age / 2.5)) + ")");
      }
      // the reticle: four ticks at the spread radius, a faint disc
      ctx.setLineDash([3, 4]); ring(cx, cy, spread, DIM, 1); ctx.setLineDash([]);
      line(cx - spread - 9, cy, cx - spread - 2, cy, INK, 2); line(cx + spread + 2, cy, cx + spread + 9, cy, INK, 2);
      line(cx, cy - spread - 9, cx, cy - spread - 2, INK, 2); line(cx, cy + spread + 2, cx, cy + spread + 9, INK, 2);
      dot(cx, cy, 1.5, INK);
      if (marker < D.marker) {                         // the hit marker
        const k = marker / D.marker, r0 = 4 + k * 5, r1 = r0 + 7, c = "rgba(255,255,255," + (1 - k) + ")";
        for (let q = 0; q < 4; q++) { const a = TAU / 8 + q * TAU / 4; line(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0, cx + Math.cos(a) * r1, cy + Math.sin(a) * r1, c, 2.5); }
      }
      label("spread " + Math.round(spread) + " px", cx + spread + 12, cy - 6, SUN);
      // spread(t)
      const gx = W * 0.05, gy = H * 0.62, gw = W * 0.3, gh = H * 0.2;
      rect(gx, gy, gw, gh, "rgba(0,0,0,0.3)");
      ctx.strokeStyle = SUN; ctx.lineWidth = 1.5; ctx.beginPath();
      for (let i = 0; i < N; i++) { const x = gx + gw * i / (N - 1), y = gy + gh - gh * clamp(hist[(head + i) % N] / D.spreadMax, 0, 1); if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y); }
      ctx.stroke();
      line(gx, gy + gh - gh * D.spreadMin / D.spreadMax, gx + gw, gy + gh - gh * D.spreadMin / D.spreadMax, DIM, 1);
      label("spread, last 4 s · min " + D.spreadMin + " · max " + D.spreadMax, gx, gy - 3, DIM);
      text("hits " + hits + " / " + shots, W - 8, 14, Math.max(9, H * 0.06), BONE, "right");
      if (holding || pending > 0) label("firing", W - 8, 26, HOT, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Xhair", "Xactshot", "a tiny maximum spread, two pixels of bloom and a slow recovery, two shots a second — the sniper's reticle, patient and exact", { spreadMax: 12, bloom: 2, recover: 9, fireRate: 2 });

def("D", "Damagearc", "hud", "a red arc on the screen edge at the angle of whoever hit you, fading and turning with them — the atlas's Vignette aimed — press to attack from there", function (u) {
  var D = { attackers: 3,        // circling enemies
            orbit: 0.36,         // their orbit radius, of W
            width: 0.7,          // arc width, radians
            fade: 1.3,           // seconds an arc takes to fade
            hitEvery: 0.9,       // autopilot: seconds between lunges
            dmg: 0.12,           // health lost per hit, of 1
            regen: 0.03,         // health regained per second
            ringBelow: 0,        // below this health the whole ring pulses (0 = never)
            inset: 9,            // the arc ellipse sits this far inside the frame
            label: "θ = atan2(attacker − player) · arc θ ± width/2 · α = 1 − age/fade" };
  const { ctx, W, H, GY, TAU, stage, hero, ellipse, ring, line, arrow, dot, poly, rect, text, label, rand, clamp, len, rgba, HOT, FIRE, INK, DIM, BONE, GOOD, SPARK } = u;
  // the atlas's Vignette darkened every edge equally; this one darkens ONE
  // direction. when a hit lands, take the angle from the player to the
  // attacker (atan2), and stroke an arc of width radians around that angle
  // on an ellipse hugging the screen's edge. the arc's alpha is 1 − age/fade,
  // and while its attacker is alive the angle is re-read every frame, so the
  // arc TURNS with them — you learn where they are, not where they were.
  // below ringBelow health the whole ellipse pulses: the low-health ring.
  const px = W / 2, feet = GY - H * 0.04, s = Math.max(2, Math.round(H / 60)), chest = feet - 9 * s;
  const att = [], arcs = [], shots = [];
  for (let i = 0; i < D.attackers; i++) att.push({ a: i * TAU / D.attackers, w: rand(0.3, 0.6) * (i % 2 ? 1 : -1), lunge: 9, x: 0, y: 0 });
  let hp = 1, hitT = 0, hurt = 0, last = -1;
  function hitFrom(ang, src) {
    arcs.push({ ang: ang, age: 0, src: src }); if (arcs.length > 10) arcs.shift();
    hp = Math.max(0, hp - D.dmg); hurt = 0.3; last = arcs.length - 1;
  }
  return {
    press(x, y) { shots.push({ x: x, y: y, age: 0, ang: Math.atan2(y - chest, x - px) }); if (shots.length > 6) shots.shift(); },
    frame(dt, t) {
      stage({ night: 0.45 });
      hitT += dt;
      if (hitT > D.hitEvery && att.length) { hitT = 0; const a = att[Math.floor(rand(0, att.length)) % att.length]; if (a.lunge > 1) a.lunge = 0; }
      hp = Math.min(1, hp + D.regen * dt); hurt = Math.max(0, hurt - dt);
      for (let i = 0; i < att.length; i++) {           // the orbit, on the ground plane
        const a = att[i]; a.a += a.w * dt;
        const prev = a.lunge; a.lunge += dt;
        const k = a.lunge < 0.5 ? Math.sin(a.lunge / 0.5 * Math.PI) * 0.72 : 0;
        a.x = px + Math.cos(a.a) * W * D.orbit * (1 - k); a.y = feet + Math.sin(a.a) * H * 0.12 * (1 - k);
        if (prev < 0.25 && a.lunge >= 0.25) hitFrom(a.a, i);   // the strike lands mid-lunge
      }
      for (let i = shots.length - 1; i >= 0; i--) {    // a press: a projectile flies in
        const sh = shots[i]; sh.age += dt;
        if (sh.age >= 0.35) { hitFrom(sh.ang, -1); shots.splice(i, 1); continue; }
        const k = sh.age / 0.35, x = sh.x + (px - sh.x) * k, y = sh.y + (chest - sh.y) * k;
        line(x - (px - sh.x) * 0.08, y - (chest - sh.y) * 0.08, x, y, FIRE, 2); dot(x, y, 3, SPARK);
      }
      ellipse(px, feet + 2, W * D.orbit + 12, H * 0.13, "rgba(0,0,0,0.25)");
      const drawAtt = (a) => { poly([[a.x, a.y - 12], [a.x + 8, a.y - 4], [a.x, a.y + 2], [a.x - 8, a.y - 4]], a.lunge < 0.5 ? FIRE : HOT); dot(a.x - 2, a.y - 6, 1.2, "#131020"); dot(a.x + 2, a.y - 6, 1.2, "#131020"); };
      for (let i = 0; i < att.length; i++) if (att[i].y < feet) drawAtt(att[i]);
      hero(px, feet, { pose: hurt > 0 ? "hurt" : "stand", frame: t, tint: hurt > 0.2 ? "rgba(245,138,138,0.7)" : undefined });
      for (let i = 0; i < att.length; i++) if (att[i].y >= feet) drawAtt(att[i]);
      // the arcs on the screen's edge
      const cx = W / 2, cy = H / 2, rx = W / 2 - D.inset, ry = H / 2 - D.inset, lw = H * 0.045;
      for (let i = arcs.length - 1; i >= 0; i--) {
        const c = arcs[i]; c.age += dt;
        if (c.age > D.fade) { arcs.splice(i, 1); if (last >= i) last--; continue; }
        if (c.src >= 0 && c.src < att.length) c.ang = Math.atan2(att[c.src].y - feet, att[c.src].x - px) ;
        const al = 1 - c.age / D.fade;
        ctx.strokeStyle = rgba(HOT, al * 0.3); ctx.lineWidth = lw * 2.2;
        ctx.beginPath(); ctx.ellipse(cx, cy, Math.max(1, rx - lw * 0.6), Math.max(1, ry - lw * 0.6), 0, c.ang - D.width / 2, c.ang + D.width / 2); ctx.stroke();
        ctx.strokeStyle = rgba(HOT, al); ctx.lineWidth = lw;
        ctx.beginPath(); ctx.ellipse(cx, cy, rx, ry, 0, c.ang - D.width / 2, c.ang + D.width / 2); ctx.stroke();
      }
      if (last >= 0 && last < arcs.length) {           // the newest arc, annotated
        const c = arcs[last];
        const ex = cx + Math.cos(c.ang) * rx * 0.75, ey = cy + Math.sin(c.ang) * ry * 0.75;
        arrow(px, chest, ex, ey, rgba(INK, 0.6));
        label("θ = " + Math.round(((c.ang / TAU * 360) % 360 + 360) % 360) + "°", ex, ey - 6, INK, "center");
      }
      if (hp < D.ringBelow) {                          // the low-health ring
        const pulse = 0.5 + 0.5 * Math.sin(t * 7);
        ctx.strokeStyle = rgba(HOT, 0.2 + 0.45 * pulse); ctx.lineWidth = lw * 0.8;
        ctx.beginPath(); ctx.ellipse(cx, cy, rx, ry, 0, 0, TAU); ctx.stroke();
        text("LOW", W / 2, H * 0.22, Math.max(10, H * 0.08), rgba(HOT, 0.5 + 0.5 * pulse), "center", true);
      }
      rect(W * 0.3, H * 0.9, W * 0.4, 5, "rgba(0,0,0,0.5)"); rect(W * 0.3, H * 0.9, W * 0.4 * hp, 5, hp < 0.3 ? HOT : GOOD);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Damagearc", "Deathring", "health barely regenerates, so it lives below the line where the whole ring pulses — the arcs still point, over a heartbeat of red", { ringBelow: 0.5, regen: 0.005, hitEvery: 1.2 });

def("T", "Toast", "hud", "notifications slide in from the right, stack upward as new ones arrive below, and slide out on timers; the rest wait in a queue — press to post one", function (u) {
  var D = { life: 2.8,           // seconds a toast stays
            slide: 0.22,         // the slide in / out, seconds
            gap: 4,              // px between stacked toasts
            shown: 4,            // slots on screen; the rest wait in the queue
            autoEvery: 1.3,      // autopilot: seconds between posts
            mode: "stack",       // "stack" = a column of toasts · "ticker" = one scrolling line
            width: 0.46,         // toast width, of W
            label: "slot i: y = base − i · (h + gap) · x eases in over slide s · out after life s" };
  const { ctx, W, H, stage, rect, line, text, label, rand, ease, smooth, SUN, HERO, MAGIC, GOOD, HOT, BONE, INK, DIM } = u;
  // the grimoire's Rise up was one phrase arriving; a toast system is a
  // QUEUE feeding a small number of SLOTS. a new toast takes slot 0 (the
  // bottom) and the older ones are pushed up — each toast's y is a target
  // (base − i·(h + gap)) that it lerps toward, so the push is a motion, not
  // a jump. x eases in over slide seconds, holds for life, eases out; when a
  // slot frees, the queue's head moves in. the ticker is the same queue on
  // one line: items append to the right and scroll left until they are gone.
  const MSGS = [["+25 gold", SUN], ["quest updated", HERO], ["achievement: first blood", MAGIC], ["Mira joined the party", GOOD], ["low battery", HOT], ["autosaving…", BONE], ["new recipe: ember stew", SUN], ["3 unread letters", HERO], ["level 7 reached", MAGIC], ["storm incoming", HOT]];
  const queue = [], live = [], tick = [];
  let autoT = 0;
  function post() { queue.push(MSGS[Math.floor(rand(0, MSGS.length)) % MSGS.length]); if (queue.length > 6) queue.shift(); }
  function rr(x, y, w, h, r) {
    ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
  }
  return {
    press() { post(); },
    frame(dt, t) {
      stage({ plain: true });
      autoT += dt; if (autoT > D.autoEvery) { autoT = 0; post(); }
      const sz = Math.max(9, H * 0.062), h = sz * 2, bw = W * D.width, bx = W - bw - 8, base = H * 0.86 - h;
      ctx.font = sz + "px system-ui, sans-serif";
      if (D.mode === "ticker") {
        const y = H * 0.86, speed = W / Math.max(0.5, D.life);
        let lastEnd = 0;
        for (let i = 0; i < tick.length; i++) lastEnd = Math.max(lastEnd, tick[i].x + tick[i].w);
        if (queue.length && lastEnd < W - 20) { const m = queue.shift(); tick.push({ m: m, x: Math.max(W, lastEnd + sz * 3), w: ctx.measureText(m[0]).width + sz }); }
        rect(0, y - h * 0.6, W, h * 0.9, "rgba(0,0,0,0.5)");
        line(0, y - h * 0.6, W, y - h * 0.6, BONE, 1); line(0, y + h * 0.3, W, y + h * 0.3, BONE, 1);
        for (let i = tick.length - 1; i >= 0; i--) {
          const k = tick[i]; k.x -= speed * dt;
          if (k.x + k.w < 0) { tick.splice(i, 1); continue; }
          rect(k.x, y - sz * 0.5, 3, sz * 0.9, k.m[1]);
          text(k.m[0], k.x + 8, y + sz * 0.3, sz, INK);
        }
        label("← " + Math.round(speed) + " px/s · a message lives one screen width", 8, y - h * 0.75, DIM);
      } else {
        for (let i = 0; i < D.shown; i++) {           // the slots, outlined
          const y = base - i * (h + D.gap);
          ctx.setLineDash([2, 3]); ctx.strokeStyle = "rgba(201,196,228,0.25)"; ctx.lineWidth = 1; ctx.strokeRect(bx, y, bw, h); ctx.setLineDash([]);
          label("slot " + i, bx - 6, y + h * 0.65, DIM, "right");
        }
        if (live.length < D.shown && queue.length) { const m = queue.shift(); live.unshift({ m: m, age: 0, y: base + h + D.gap }); }
        for (let i = live.length - 1; i >= 0; i--) {
          const k = live[i]; k.age += dt;
          const ty = base - i * (h + D.gap);
          k.y += (ty - k.y) * smooth(14, dt);
          let off;
          if (k.age < D.slide) off = (1 - ease(k.age / D.slide)) * (bw + 12);
          else if (k.age > D.life) { const k2 = (k.age - D.life) / Math.max(0.01, D.slide); if (k2 >= 1) { live.splice(i, 1); continue; } off = ease(k2) * (bw + 12); }
          else off = 0;
          const x = bx + off;
          rr(x, k.y, bw, h, 4); ctx.fillStyle = "rgba(20,16,38,0.94)"; ctx.fill(); ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.stroke();
          rect(x, k.y, 3, h, k.m[1]);
          text(k.m[0], x + 9, k.y + h * 0.62, sz, INK);
          rect(x + 3, k.y + h - 2, (bw - 6) * (1 - Math.min(1, k.age / D.life)), 2, k.m[1]);
        }
      }
      // the queue, drawn
      const qx = 8, qy = H * 0.12;
      text("queue " + queue.length + (D.mode === "ticker" ? " · on the line " + tick.length : " · shown " + live.length + " / " + D.shown), qx, qy, sz, BONE);
      for (let i = 0; i < queue.length; i++) {
        const y = qy + 8 + i * (sz * 1.4);
        rect(qx, y, 3, sz, queue[i][1]);
        label(queue[i][0], qx + 8, y + sz * 0.85, "rgba(232,229,244,0.4)");
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Toast", "Ticker", "the same queue on a single scrolling line — items append to the right and crawl left, each living one screen width", { mode: "ticker", life: 4.5 });

def("M", "Minimap", "hud", "a scaled copy of the world in the corner with a radar sweep — a blip lights as the wedge passes and fades until the next pass — press to add a blip", function (u) {
  var D = { size: 0.3,           // the map is the world scaled by this
            period: 3,           // seconds per sweep revolution
            fade: 2.4,           // a blip fades out over this long after the sweep
            blips: 6,            // enemies at the start
            speed: 0.12,         // enemy walking speed, screens per second
            mode: "sweep",       // "sweep" = the rotating wedge reveals · "motion" = only movers show
            label: "map = origin + world · k · blip α = 1 − (t − seenAt) / fade" };
  const { ctx, W, H, GY, TAU, stage, hero, tree, rect, line, ring, dot, poly, text, label, rand, clamp, len, rng, rgba, HOT, HERO, GOOD, BONE, INK, DIM } = u;
  // the lexicon's Camera drew a world strip; a MINIMAP is the same idea in
  // two axes: map = origin + world · k, one multiply per point. the radar
  // SWEEP is the bestiary's Lighthouse turned into a rule: a blip is only
  // stamped when the sweep angle crosses its bearing from the player, then
  // its alpha decays until the next pass — so what you see is a memory,
  // period seconds stale at worst. the motion tracker is a different rule
  // on the same map: a blip shows only while its enemy moves.
  const seed = rng(5), yTop = GY - H * 0.26, yBot = H - 8;
  const en = [], trees = [];
  for (let i = 0; i < 5; i++) trees.push({ x: seed() * W, y: yTop - 10 + seed() * 20, s: 0.14 + seed() * 0.06 });
  function addEnemy(x, y) { en.push({ x: x, y: y, tx: x, ty: y, rest: rand(0, 3), moving: false, seenAt: -99, sitter: rand(0, 1) < 0.35 }); if (en.length > 12) en.shift(); }
  for (let i = 0; i < D.blips; i++) addEnemy(rand(W * 0.05, W * 0.95), rand(yTop, yBot));
  let hx = W * 0.3, hdir = 1, sweep = 0;
  const k = D.size, mw = W * k, mh = H * k, mx0 = W - mw - 6, my0 = 6;
  return {
    press(x, y) {
      let wx = x, wy = y;
      if (x >= mx0 && x <= mx0 + mw && y >= my0 && y <= my0 + mh) { wx = (x - mx0) / k; wy = (y - my0) / k; }
      addEnemy(clamp(wx, 4, W - 4), clamp(wy, yTop, yBot));
    },
    frame(dt, t) {
      stage();
      const hy = GY + H * 0.02;
      hx += hdir * W * 0.18 * dt; if (hx > W * 0.9) hdir = -1; if (hx < W * 0.1) hdir = 1;
      const prev = sweep; sweep += TAU / Math.max(0.2, D.period) * dt;
      const adv = sweep - prev;
      for (let i = 0; i < en.length; i++) {            // wander: walk to a spot, rest, repeat
        const e = en[i];
        if (e.moving) {
          const dx = e.tx - e.x, dy = e.ty - e.y, d = len(dx, dy), v = W * D.speed * dt;
          if (d <= v || d < 0.01) { e.x = e.tx; e.y = e.ty; e.moving = false; e.rest = rand(1, e.sitter ? 7 : 3); }
          else { e.x += dx / d * v; e.y += dy / d * v; }
        } else { e.rest -= dt; if (e.rest <= 0) { e.moving = true; e.tx = clamp(e.x + rand(-W * 0.3, W * 0.3), 4, W - 4); e.ty = clamp(e.y + rand(-H * 0.15, H * 0.15), yTop, yBot); } }
        if (D.mode === "motion") { if (e.moving) e.seenAt = t; }
        else {                                         // did the sweep cross this bearing this frame?
          const b = Math.atan2(e.y - hy, e.x - hx);
          let da = (b - prev) % TAU; if (da < 0) da += TAU;
          if (da <= adv) e.seenAt = t;
        }
      }
      for (let i = 0; i < trees.length; i++) tree(trees[i].x, trees[i].y, H * trees[i].s);
      // the world: enemies dim until seen, the hero patrolling
      let heroDrawn = false;
      const order = en.slice().sort((a, b) => a.y - b.y);
      for (let i = 0; i < order.length; i++) {
        const e = order[i];
        if (!heroDrawn && e.y > hy) { hero(hx, hy, { pose: "run", frame: t, face: hdir }); heroDrawn = true; }
        const vis = clamp(1 - (t - e.seenAt) / D.fade, 0, 1);
        poly([[e.x, e.y - 11], [e.x + 7, e.y - 4], [e.x, e.y], [e.x - 7, e.y - 4]], rgba(HOT, 0.3 + 0.7 * vis));
        dot(e.x - 2, e.y - 6, 1.2, "#131020"); dot(e.x + 2, e.y - 6, 1.2, "#131020");
      }
      if (!heroDrawn) hero(hx, hy, { pose: "run", frame: t, face: hdir });
      // the map
      rect(mx0, my0, mw, mh, "rgba(10,8,22,0.88)");
      ctx.save(); ctx.beginPath(); ctx.rect(mx0, my0, mw, mh); ctx.clip();
      line(mx0, my0 + GY * k, mx0 + mw, my0 + GY * k, DIM, 1);
      for (let i = 0; i < trees.length; i++) dot(mx0 + trees[i].x * k, my0 + trees[i].y * k, 1.5, GOOD);
      const phx = mx0 + hx * k, phy = my0 + hy * k;
      if (D.mode === "sweep") {
        const R = mw + mh;
        for (let j = 0; j < 10; j++) {                // the wedge: ten slices, brighter toward the edge
          const a0 = sweep - 0.9 + j * 0.09, a1 = a0 + 0.1;
          ctx.fillStyle = rgba(GOOD, 0.03 + j * 0.03);
          ctx.beginPath(); ctx.moveTo(phx, phy); ctx.arc(phx, phy, R, a0, a1); ctx.closePath(); ctx.fill();
        }
        line(phx, phy, phx + Math.cos(sweep) * R, phy + Math.sin(sweep) * R, GOOD, 1);
      }
      for (let i = 0; i < en.length; i++) {
        const e = en[i], vis = clamp(1 - (t - e.seenAt) / D.fade, 0, 1);
        if (vis <= 0) continue;
        const bxm = mx0 + e.x * k, bym = my0 + e.y * k;
        dot(bxm, bym, 2.2, rgba(HOT, vis));
        if (D.mode === "motion" && e.moving) ring(bxm, bym, 3 + ((t * 2) % 1) * 5, rgba(HOT, 0.6 * (1 - (t * 2) % 1)), 1);
      }
      dot(phx, phy, 2.5, HERO); line(phx, phy, phx + hdir * 5, phy, HERO, 1.5);
      ctx.restore();
      ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.strokeRect(mx0, my0, mw, mh);
      label("k = " + D.size, mx0, my0 + mh + 11, DIM);
      label(D.mode === "sweep" ? "sweep every " + D.period + " s" : "motion only", mx0 + mw, my0 + mh + 11, GOOD, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Minimap", "Motiontracker", "no sweep: a blip is stamped only while its enemy moves and fades fast when it stops — the Aliens tracker, eight contacts", { mode: "motion", fade: 1.1, blips: 8 });

def("G", "Ghostplacement", "hud", "build mode: a ghost snapped to the grid, green where it fits, red where it overlaps; autopilot builds — drag to move the ghost, let go to place", function (u) {
  var D = { cell: 0.09,          // grid cell, of H
            pieceW: 3,           // the piece, in cells...
            pieceH: 1,           // ...wide and tall (a press on a blocked spot rotates it)
            autoEvery: 1.4,      // autopilot: seconds between placements
            prefill: 6,          // pieces already on the plot
            moveRate: 7,         // how fast the cursor glides to its target
            label: "gx = round((x − ox) / cell − w/2) · valid = in bounds ∧ every cell free" };
  const { ctx, W, H, stage, rect, line, dot, ring, text, label, rand, clamp, smooth, rng, rgba, GOOD, HOT, SUN, HERO, MAGIC, BONE, INK, DIM } = u;
  // the lexicon's Grid quantised a position; a PLACEMENT GHOST quantises a
  // whole footprint. the cursor is continuous; the ghost's cell is
  // round((x − ox)/cell − w/2), and its VALIDITY is one test — inside the
  // grid, and no footprint cell already occupied (a byte per cell). the
  // tint is chapter 03's: the same shape painted green or red tells the
  // rule before you press. letting go places; a blocked spot rotates instead.
  const cell = Math.max(6, H * D.cell), cols = Math.max(4, Math.floor(W * 0.92 / cell)), rows = Math.max(3, Math.floor(H * 0.64 / cell));
  const ox = (W - cols * cell) / 2, oy = H * 0.14, occ = new Uint8Array(cols * rows), pieces = [], palette = [SUN, HERO, MAGIC, "#8A6A3E", GOOD];
  const bad = [];
  let pw = D.pieceW, ph = D.pieceH, fx = W / 2, fy = H / 2, tx = fx, ty = fy, heldT = 0, autoT = 0, lastPress = -9, now = 0, filled = 0, clearedT = 9, nColor = 0;
  function fits(gx, gy, w, h) {
    bad.length = 0;
    let ok = gx >= 0 && gy >= 0 && gx + w <= cols && gy + h <= rows;
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      const cx = gx + i, cy = gy + j;
      if (cx < 0 || cy < 0 || cx >= cols || cy >= rows) continue;
      if (occ[cy * cols + cx]) { ok = false; bad.push(cx, cy); }
    }
    return ok;
  }
  function place(gx, gy, w, h) {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) occ[(gy + j) * cols + gx + i] = 1;
    pieces.push({ gx: gx, gy: gy, w: w, h: h, c: palette[nColor++ % palette.length], age: 0 });
    filled += w * h;
  }
  const seed = rng(3);
  for (let n = 0; n < D.prefill * 6 && pieces.length < D.prefill; n++) {
    const w = seed() < 0.5 ? pw : ph, h = w === pw ? ph : pw;
    const gx = Math.floor(seed() * cols), gy = Math.floor(seed() * rows);
    if (fits(gx, gy, w, h)) place(gx, gy, w, h);
  }
  function rotate() { const q = pw; pw = ph; ph = q; }
  return {
    drag: true,
    press(x, y) {
      tx = x; ty = y;
      if (now - lastPress > 0.3) { fx = x; fy = y; }
      lastPress = now; heldT = 0.15;
    },
    frame(dt, t) {
      now = t;
      stage({ plain: true });
      fx += (tx - fx) * smooth(D.moveRate, dt); fy += (ty - fy) * smooth(D.moveRate, dt);
      const gx = Math.round((fx - ox) / cell - pw / 2), gy = Math.round((fy - oy) / cell - ph / 2);
      const valid = fits(gx, gy, pw, ph);
      if (t - lastPress > 2.5) {                       // autopilot: glide, place or rotate, pick anew
        autoT += dt;
        if (autoT > D.autoEvery) {
          autoT = 0;
          if (valid) place(gx, gy, pw, ph); else rotate();
          tx = ox + (Math.floor(rand(0, cols)) + 0.5) * cell; ty = oy + (Math.floor(rand(0, rows)) + 0.5) * cell;
        }
      }
      if (heldT > 0) { heldT -= dt; if (heldT <= 0) { if (valid) place(gx, gy, pw, ph); else rotate(); } }
      if (filled > cols * rows * 0.62) { occ.fill(0); pieces.length = 0; filled = 0; clearedT = 0; }
      clearedT += dt;
      // the grid
      ctx.strokeStyle = "rgba(201,196,228,0.14)"; ctx.lineWidth = 1; ctx.beginPath();
      for (let i = 0; i <= cols; i++) { ctx.moveTo(ox + i * cell, oy); ctx.lineTo(ox + i * cell, oy + rows * cell); }
      for (let j = 0; j <= rows; j++) { ctx.moveTo(ox, oy + j * cell); ctx.lineTo(ox + cols * cell, oy + j * cell); }
      ctx.stroke();
      ctx.strokeStyle = BONE; ctx.strokeRect(ox, oy, cols * cell, rows * cell);
      for (let i = 0; i < pieces.length; i++) {        // placed pieces, popping in
        const p = pieces[i]; p.age += dt;
        const s = 1 + 0.25 * Math.sin(Math.min(1, p.age / 0.25) * Math.PI);
        const x = ox + p.gx * cell, y = oy + p.gy * cell, w = p.w * cell, h = p.h * cell;
        ctx.save(); ctx.translate(x + w / 2, y + h / 2); ctx.scale(s, s);
        rect(-w / 2 + 1, -h / 2 + 1, w - 2, h - 2, p.c);
        ctx.strokeStyle = "rgba(19,16,32,0.6)"; ctx.lineWidth = 1; ctx.strokeRect(-w / 2 + 1, -h / 2 + 1, w - 2, h - 2);
        ctx.restore();
      }
      // the ghost
      const gc = valid ? GOOD : HOT, x = ox + gx * cell, y = oy + gy * cell, w = pw * cell, h = ph * cell;
      rect(x, y, w, h, rgba(gc, 0.3));
      ctx.strokeStyle = gc; ctx.lineWidth = 1.5; ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
      for (let i = 0; i < bad.length; i += 2) {        // the overlapping cells, crossed
        const bxp = ox + bad[i] * cell, byp = oy + bad[i + 1] * cell;
        line(bxp + 3, byp + 3, bxp + cell - 3, byp + cell - 3, HOT, 1.5); line(bxp + cell - 3, byp + 3, bxp + 3, byp + cell - 3, HOT, 1.5);
      }
      ctx.setLineDash([2, 3]); line(fx, fy, x + w / 2, y + h / 2, DIM, 1); ctx.setLineDash([]);
      dot(fx, fy, 2.5, INK); ring(fx, fy, 5, INK, 1);
      const sz = Math.max(9, H * 0.058);
      text("gx " + gx + " · gy " + gy + " · " + pw + "×" + ph + (valid ? " · valid" : " · blocked"), ox, oy - 4, sz, gc);
      text(pieces.length + " placed · " + Math.round(filled / (cols * rows) * 100) + "% full", ox + cols * cell, oy - 4, sz, DIM, "right");
      if (clearedT < 1.2) { ctx.globalAlpha = 1 - clearedT / 1.2; text("plot cleared", W / 2, H / 2, sz * 1.4, INK, "center", true); ctx.globalAlpha = 1; }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Ghostplacement", "Gardenplot", "a 2×1 bed on a much tighter grid — more cells, more collisions, the same green-or-red answer", { pieceW: 2, pieceH: 1, cell: 0.065 });

def("J", "Jewel", "hud", "four inventory cards, each with a colour by tier and a sheen that sweeps its border — the bestiary's Chrome sweep worn as rarity — press to reroll", function (u) {
  var D = { tiers: ["common", "rare", "epic", "legendary"],
            colours: ["#B9B4D0", "#4FA3D8", "#C9A0F5", "#F5C169"],
            odds: [0.5, 0.28, 0.15, 0.07],   // reroll weights per tier
            period: 2.4,         // seconds per sheen pass
            band: 0.3,           // sheen band width, of the card width
            rerollEvery: 3.6,    // autopilot: seconds between rerolls
            junk: false,         // true = everything common but one card
            label: "sheen u = ((t − i·0.4) / period) mod 1 · the band is a clip · glow ∝ tier" };
  const { ctx, W, H, TAU, stage, rect, line, dot, poly, glow, text, label, rand, clamp, rgba, mix, BONE, INK, DIM, SPARK } = u;
  // rarity is a lookup: tier → colour, and tier → how much light the card
  // is allowed. the SHEEN is the bestiary's Chrome sweep: a diagonal band
  // whose position u runs 0 → 1 over period seconds, used as a CLIP — inside
  // it the border is re-stroked white and the face brightened; outside it
  // nothing. common cards never sweep; epic and legendary also get a
  // breathing glow behind them. a reroll flips each card on its x axis and
  // swaps the tier at the half-turn, when the card is edge-on.
  const cards = [];
  for (let i = 0; i < 4; i++) cards.push({ tier: i, next: i, flip: 9 });
  let autoT = 0;
  function pick() {
    const r = rand(0, 1); let acc = 0;
    for (let i = 0; i < D.odds.length; i++) { acc += D.odds[i]; if (r < acc) return i; }
    return 0;
  }
  function roll() {
    const star = Math.floor(rand(0, 4)) % 4;
    for (let i = 0; i < 4; i++) { cards[i].next = D.junk ? (i === star ? 1 + Math.floor(rand(0, 3)) % 3 : 0) : pick(); cards[i].flip = 0; }
  }
  function rr(x, y, w, h, r) {
    ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
  }
  roll(); for (let i = 0; i < 4; i++) { cards[i].tier = cards[i].next; cards[i].flip = 9; }
  return {
    press() { roll(); },
    frame(dt, t) {
      stage({ plain: true });
      autoT += dt; if (autoT > D.rerollEvery) { autoT = 0; roll(); }
      const cw = Math.min(W * 0.18, H * 0.3), ch = cw * 1.3, cy = H * 0.45, sz = Math.max(9, H * 0.058);
      for (let i = 0; i < 4; i++) {
        const c = cards[i], cx = W * (0.5 + (i - 1.5) * 0.22);
        const prev = c.flip; c.flip += dt;
        if (prev < 0.25 && c.flip >= 0.25) c.tier = c.next;   // edge-on: swap
        const sx = c.flip < 0.5 ? Math.abs(Math.cos(c.flip / 0.5 * Math.PI)) : 1;
        const tier = c.tier, col = D.colours[tier % D.colours.length], name = D.tiers[tier % D.tiers.length];
        ctx.save(); ctx.translate(cx, cy); ctx.scale(Math.max(0.02, sx), 1);
        if (tier >= 2) glow(0, 0, cw * 0.95, col, (tier === 3 ? 0.4 : 0.22) + 0.12 * Math.sin(t * 3 + i));
        rr(-cw / 2, -ch / 2, cw, ch, 5); ctx.fillStyle = "#221D38"; ctx.fill();
        ctx.strokeStyle = col; ctx.lineWidth = tier === 3 ? 2.5 : (tier === 0 ? 1 : 2); ctx.stroke();
        const gs = cw * (0.22 + 0.05 * tier);          // the gem, bigger by tier
        poly([[0, -gs], [gs * 0.8, -gs * 0.3], [gs * 0.5, gs * 0.7], [-gs * 0.5, gs * 0.7], [-gs * 0.8, -gs * 0.3]], col);
        poly([[0, -gs], [gs * 0.8, -gs * 0.3], [0, -gs * 0.3]], mix(col, "#FFFFFF", 0.45));
        poly([[-gs * 0.8, -gs * 0.3], [0, -gs * 0.3], [-gs * 0.5, gs * 0.7]], mix(col, "#000000", 0.25));
        if (tier === 3) for (let q = 0; q < 3; q++) { const a = t * 1.5 + q * TAU / 3; dot(Math.cos(a) * cw * 0.36, Math.sin(a) * ch * 0.36, 1.5 + Math.sin(t * 6 + q) * 0.8, SPARK); }
        if (tier > 0) {                                // the sheen: a clipped re-stroke
          const uu = (((t - i * 0.4) / Math.max(0.2, D.period)) % 1 + 1) % 1;
          const span = cw + ch, s0 = -span / 2 + uu * span, bw = cw * D.band / 2;
          ctx.save();
          ctx.beginPath(); ctx.moveTo(s0 - bw + ch * 0.35, -ch); ctx.lineTo(s0 + bw + ch * 0.35, -ch); ctx.lineTo(s0 + bw - ch * 0.35, ch); ctx.lineTo(s0 - bw - ch * 0.35, ch); ctx.closePath(); ctx.clip();
          rr(-cw / 2, -ch / 2, cw, ch, 5); ctx.fillStyle = "rgba(255,255,255," + (0.05 * tier) + ")"; ctx.fill();
          ctx.strokeStyle = "rgba(255,255,255," + (0.5 + 0.17 * tier) + ")"; ctx.lineWidth = 2 + tier; ctx.stroke();
          ctx.restore();
        }
        ctx.restore();
        text(name, cx, cy + ch / 2 + sz * 1.3, sz, col, "center", tier >= 2);
        label("tier " + tier, cx, cy + ch / 2 + sz * 2.4, DIM, "center");
        // u for this card, as a tiny bar
        const uu2 = (((t - i * 0.4) / Math.max(0.2, D.period)) % 1 + 1) % 1;
        rect(cx - cw / 2, cy - ch / 2 - 8, cw, 2, "rgba(201,196,228,0.2)");
        if (tier > 0) rect(cx - cw / 2 + cw * uu2 - 1, cy - ch / 2 - 9, 2, 4, col);
      }
      label("u", W * (0.5 - 1.5 * 0.22) - cw / 2 - 4, cy - ch / 2 - 5, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Jewel", "Junkloot", "every drop common but one — the sweep runs on that card alone, a little faster, and the eye goes straight to it", { junk: true, period: 1.6 });

def("B", "Bossbar", "hud", "segments fill on the intro, shake on every hit and break off as each phase ends — the grimoire's Earthquake on a strip — press to hit the boss", function (u) {
  var D = { phases: 3,           // segments on the bar
            intro: 2,            // seconds the intro fill takes
            shake: 6,            // px of shake on a hit
            decay: 7,            // the shake's decay rate, per second
            hitEvery: 0.75,      // autopilot: seconds between hits
            dmgMin: 5,           // damage per hit, from...
            dmgMax: 11,          // ...to (the bar holds 100)
            name: "GLOOMWARDEN",
            label: "intro: seg i fills at i/phases · hit: dx = shake · e^(−decay·age) · sin(50·age) · empty seg falls" };
  const { ctx, W, H, GY, TAU, stage, hero, rect, line, dot, ellipse, poly, text, label, rand, clamp, ease, rgba, HOT, FIRE, SUN, INK, BONE, DIM, MAGIC, GOOD, SPARK } = u;
  // three moments, three mechanisms. the INTRO is a tween: an eased clock
  // from 0 to phases, and segment i is as full as clamp(clock − i, 0, 1) —
  // they fill one after another. a HIT is the grimoire's Earthquake on the
  // bar alone: dx = shake · e^(−decay·age) · sin(50·age), a ring that dies.
  // a PHASE ends when its segment empties: the segment becomes a falling
  // body (velocity, gravity, spin, fade — the bestiary's Ice cracks) and the
  // next one takes the hits. the boss is one big shape with a flash tint.
  const cols = [HOT, FIRE, SUN, MAGIC, GOOD], falling = [], seg = [];
  let state = "intro", st = 0, cur = 0, shakeAge = 9, flash = 9, hitT = 0, slash = 9;
  const hpPer = 100 / Math.max(1, D.phases);
  function reset() { state = "intro"; st = 0; seg.length = 0; for (let i = 0; i < D.phases; i++) seg.push(1); cur = D.phases - 1; falling.length = 0; }
  reset();
  function geom() {
    const bx = W * 0.1, bw = W * 0.8, by = H * 0.15, bh = H * 0.06, gap = 3;
    return { bx: bx, bw: bw, by: by, bh: bh, gap: gap, sw: (bw - gap * (D.phases - 1)) / D.phases };
  }
  function hit() {
    if (state !== "fight") return;
    shakeAge = 0; flash = 0; slash = 0;
    seg[cur] -= rand(D.dmgMin, D.dmgMax) / hpPer;
    if (seg[cur] <= 0) {                               // the segment breaks off
      seg[cur] = 0;
      const g = geom();
      falling.push({ i: cur, x: g.bx + cur * (g.sw + g.gap), y: g.by, w: g.sw, h: g.bh, vx: rand(20, 60), vy: -rand(40, 90), rot: 0, vr: rand(-4, 4), age: 0 });
      if (falling.length > 6) falling.shift();
      cur--;
      if (cur < 0) { state = "dead"; st = 0; }
    }
  }
  return {
    press() { hit(); },
    frame(dt, t) {
      stage({ night: 0.6 });
      st += dt; shakeAge += dt; flash += dt; slash += dt;
      if (state === "intro" && st > D.intro + 0.4) { state = "fight"; st = 0; hitT = 0; }
      if (state === "fight") { hitT += dt; if (hitT > D.hitEvery) { hitT = 0; hit(); } }
      if (state === "dead" && st > 2.5) reset();
      const g = geom(), sz = Math.max(9, H * 0.062);
      const dx = D.shake * Math.exp(-D.decay * shakeAge) * Math.sin(50 * shakeAge), dy = dx * 0.4;
      // the boss and the hero
      const bob = Math.sin(t * 2) * 3, bx0 = W * 0.64, dead = state === "dead";
      const al = dead ? Math.max(0, 1 - st / 2) : 1, sink = dead ? st * H * 0.1 : 0;
      ctx.save(); ctx.globalAlpha = al;
      ellipse(bx0, GY + 2, W * 0.14, H * 0.03, "rgba(0,0,0,0.35)");
      const bodyC = flash < 0.1 ? "#F4F0FF" : (state === "fight" && cur < D.phases - 1 ? "#3A2246" : "#2A2246");
      ellipse(bx0, GY - H * 0.2 + bob + sink, W * 0.13, H * 0.2, bodyC);
      poly([[bx0 - W * 0.1, GY - H * 0.34 + bob + sink], [bx0 - W * 0.04, GY - H * 0.3 + bob + sink], [bx0 - W * 0.1, GY - H * 0.25 + bob + sink]], bodyC);
      poly([[bx0 + W * 0.1, GY - H * 0.34 + bob + sink], [bx0 + W * 0.04, GY - H * 0.3 + bob + sink], [bx0 + W * 0.1, GY - H * 0.25 + bob + sink]], bodyC);
      const eye = 2 + (D.phases - 1 - cur) * 1.2;
      dot(bx0 - W * 0.04, GY - H * 0.26 + bob + sink, eye, flash < 0.1 ? "#131020" : HOT); dot(bx0 + W * 0.04, GY - H * 0.26 + bob + sink, eye, flash < 0.1 ? "#131020" : HOT);
      ctx.restore();
      hero(W * 0.24, GY, { pose: slash < 0.2 ? "jump" : "stand", frame: t });
      if (slash < 0.2) { ctx.strokeStyle = rgba(SPARK, 1 - slash / 0.2); ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(bx0 - W * 0.08, GY - H * 0.22, H * 0.12, -TAU * 0.3, TAU * 0.05); ctx.stroke(); }
      // the bar
      const fillClock = state === "intro" ? ease(st / Math.max(0.1, D.intro)) * D.phases : D.phases;
      ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.strokeRect(g.bx + dx - 2, g.by + dy - 2, g.bw + 4, g.bh + 4);
      for (let i = 0; i < D.phases; i++) {
        const x = g.bx + i * (g.sw + g.gap) + dx, y = g.by + dy;
        rect(x, y, g.sw, g.bh, "rgba(0,0,0,0.5)");
        if (seg[i] <= 0) continue;
        const f = clamp(fillClock - i, 0, 1) * seg[i], c = cols[i % cols.length];
        rect(x, y, g.sw * f, g.bh, c);
        rect(x, y, g.sw * f, g.bh * 0.3, "rgba(255,255,255,0.18)");
        if (i === cur && flash < 0.12 && state === "fight") rect(x, y, g.sw * f, g.bh, "rgba(255,255,255," + (0.7 * (1 - flash / 0.12)) + ")");
      }
      const nameA = state === "intro" ? ease(st / 0.6) : 1, nameY = g.by - 6 - (1 - nameA) * 14;
      ctx.globalAlpha = nameA;
      text(dead ? "DEFEATED" : D.name, g.bx + dx, nameY + dy, sz * 1.15, INK, "left", true);
      ctx.globalAlpha = 1;
      text(state === "intro" ? "intro " + Math.round(fillClock / D.phases * 100) + "%" : (dead ? "" : "phase " + (D.phases - cur) + " / " + D.phases), g.bx + g.bw, g.by - 6, sz, cols[Math.max(0, cur) % cols.length], "right");
      if (shakeAge < 0.6) label("dx = " + dx.toFixed(1) + " px", g.bx + g.bw / 2, g.by + g.bh + 12, SUN, "center");
      for (let i = falling.length - 1; i >= 0; i--) { // the broken segments fall away
        const f = falling[i]; f.age += dt; f.vy += H * 2.4 * dt; f.x += f.vx * dt; f.y += f.vy * dt; f.rot += f.vr * dt;
        if (f.age > 1.4 || f.y > H + 20) { falling.splice(i, 1); continue; }
        ctx.save(); ctx.globalAlpha = Math.max(0, 1 - f.age / 1.4); ctx.translate(f.x + f.w / 2, f.y + f.h / 2); ctx.rotate(f.rot);
        rect(-f.w / 2, -f.h / 2, f.w, f.h, cols[f.i % cols.length]);
        ctx.restore();
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Bossbar", "Behemoth", "five phases, a four-second intro that fills them one by one, and twice the shake — the raid boss whose bar is a ceremony", { phases: 5, intro: 4, shake: 12 });
/* ============================== SFX & AUDIO ==============================
   The sound half, drawn. Every card here is a picture of a mechanism that
   is usually invisible: a panner and a distance curve, the contact frame
   that fires a footstep, a blip per letter, six envelopes, an engine's
   rpm-to-pitch line, LFOs on a noise filter, a lowpass cutoff sliding on a
   spectrum, a feedback delay, three music layers gated by intensity, the
   lookahead window on the audio clock, voice slots being stolen, an
   analyser's bins, and two rumble motors. Sound is a courtesy: nothing here
   makes a noise until you press it (browsers insist, and so do we), the
   volumes stay low, and every card is worth watching with the speakers off.
   It grows from chapter 07 — the blip, the pitch randomisation, the bus. */

def("P", "Positional", "audio", "pan follows x, gain falls with distance, pitch bends with closing speed — a siren crosses; three meters draw it — press to place the listener", function (u) {
  var D = { speed: 0.28,        // the car's speed, screens per second
            refDist: 0.25,      // the distance (of W) where the gain has fallen to half
            soundSpeed: 1.4,    // the speed of sound, screens per second — tiny on purpose so the doppler shows
            baseHz: 520,        // the siren's low note...
            wobbleHz: 150,      // ...and how far the high note sits above it
            every: 0.28,        // seconds between siren voices after the first press
            vol: 0.2,
            label: "pan = dx/(W/2) · gain = 1/(1+(d/ref)²) · f′ = f·c/(c − v_closing)"
  };
  const { ctx, W, H, GY, TAU, stage, hero, dot, ring, line, rect, arrow, label, text, clamp, tone, HOT, WATER, SUN, BONE, DIM, INK } = u;
  // POSITIONAL AUDIO is three numbers read off the geometry every frame.
  // PAN is the source's x relative to the listener, squashed to −1..1.
  // ATTENUATION is a distance curve: 1/(1+(d/ref)²) is one; engines call
  // theirs "inverse", "linear", "logarithmic". DOPPLER is the pitch shift
  // from closing speed: f′ = f·c/(c − v), where v is the source's speed
  // TOWARD the listener (positive = approaching = higher). chapter 07's
  // AudioStreamPlayer2D / spatialBlend do exactly this behind the curtain.
  let armed = false, cx = -40, dir = 1, lx = W * 0.5, sirenT = 0, hi = false;
  let pan = 0, gain = 0, dop = 1, flash = 0;
  const ry = GY - H * 0.1;                             // the road, a little behind the hero
  function meterBox(x, y, w, h, title) {
    rect(x, y, w, h, "rgba(19,16,32,0.55)");
    ctx.strokeStyle = "rgba(201,196,228,0.35)"; ctx.lineWidth = 1; ctx.strokeRect(x, y, w, h);
    label(title, x + 4, y + 11, DIM);
  }
  return {
    press(x) { armed = true; lx = clamp(x, 20, W - 20); },
    frame(dt, t) {
      stage({ night: 0.35 });
      cx += dir * W * D.speed * dt;
      if (cx > W + 50) dir = -1; else if (cx < -50) dir = 1;
      const ly = GY - H * 0.12;                        // the listener's ears
      const dx = cx - lx, dy = ry - 6 - ly;
      const d = Math.max(1, Math.sqrt(dx * dx + dy * dy));
      pan = clamp(dx / (W * 0.5), -1, 1);
      const ref = Math.max(1, W * D.refDist);
      gain = 1 / (1 + (d / ref) * (d / ref));
      const vx = dir * W * D.speed;                    // the source's velocity
      const closing = vx * (-dx / d);                  // ...projected on the line to the ear
      const c = Math.max(1, W * D.soundSpeed);
      dop = c / Math.max(c * 0.25, c - closing);       // f′/f, guarded so it can never blow up
      sirenT += dt; flash = Math.max(0, flash - dt * 4);
      if (armed && sirenT >= D.every) {                // one siren voice per tick, panned and attenuated
        sirenT = 0; hi = !hi; flash = 1;
        const f = (D.baseHz + (hi ? D.wobbleHz : 0)) * dop;
        tone({ freq: f, slideTo: f * (hi ? 0.97 : 1.03), type: "triangle", dur: D.every * 1.4, vol: D.vol * gain, pan: pan, attack: 0.02 });
      }
      // the road, the car, the listener
      rect(0, ry - 5, W, 10, "rgba(45,40,70,0.9)");
      ctx.setLineDash([6, 8]); line(0, ry, W, ry, "rgba(232,229,244,0.25)", 1); ctx.setLineDash([]);
      const cw = W * 0.12, ch = H * 0.06;
      rect(cx - cw / 2, ry - 4 - ch, cw, ch, WATER);
      rect(cx - cw * 0.3, ry - 4 - ch * 1.7, cw * 0.55, ch * 0.7, "#2B2440");
      dot(cx - cw * 0.3, ry - 2, ch * 0.3, "#2B2440"); dot(cx + cw * 0.3, ry - 2, ch * 0.3, "#2B2440");
      dot(cx, ry - 4 - ch * 1.8, 3, hi ? HOT : WATER);  // the light bar, hee-haw
      if (flash > 0) ring(cx, ry - 4 - ch * 1.8, 3 + (1 - flash) * 14, hi ? "rgba(245,138,138," + flash * 0.6 + ")" : "rgba(79,163,216," + flash * 0.6 + ")", 1.5);
      ctx.setLineDash([3, 4]); line(cx, ry - 4 - ch / 2, lx, ly, DIM, 1); ctx.setLineDash([]);
      label("d = " + Math.round(d), (cx + lx) / 2, (ry + ly) / 2 - 6, DIM, "center");
      hero(lx, GY, { face: cx > lx ? 1 : -1, frame: t });
      ring(lx, ly, 6 + Math.sin(t * 6) * 2, "rgba(232,229,244,0.35)", 1);
      label("listener", lx, GY + 12, DIM, "center");
      // three meters: pan, gain, pitch
      const mw = W * 0.28, mh = H * 0.2, my = 6, gap = (W - mw * 3) / 4;
      let mx = gap;
      meterBox(mx, my, mw, mh, "pan " + pan.toFixed(2));
      line(mx + 8, my + mh * 0.62, mx + mw - 8, my + mh * 0.62, BONE, 1);
      label("L", mx + 6, my + mh - 4, DIM); label("R", mx + mw - 6, my + mh - 4, DIM, "right");
      dot(mx + mw / 2 + pan * (mw / 2 - 10), my + mh * 0.62, 4, SUN);
      mx += mw + gap;
      meterBox(mx, my, mw, mh, "gain " + gain.toFixed(2));
      rect(mx + 8, my + mh * 0.5, mw - 16, mh * 0.3, "rgba(201,196,228,0.15)");
      rect(mx + 8, my + mh * 0.5, (mw - 16) * gain, mh * 0.3, SUN);
      mx += mw + gap;
      meterBox(mx, my, mw, mh, "pitch ×" + dop.toFixed(2));
      const nx = mx + mw / 2, ny = my + mh - 4, nr = mh * 0.6;
      ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(nx, ny, nr, Math.PI, TAU); ctx.stroke();
      const na = Math.PI + clamp((dop - 0.5) / 1.0, 0, 1) * Math.PI;   // 0.5× .. 1.5× across the dial
      line(nx, ny, nx + Math.cos(na) * nr, ny + Math.sin(na) * nr, closing > 0 ? HOT : WATER, 2);
      label("1×", nx, ny - nr - 3, DIM, "center");
      arrow(cx, ry + 14, cx + dir * 22, ry + 14, INK);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Positional", "Prowler", "a slow pass with a low engine note and sound that travels slowly — the doppler bends the pitch hard as it passes", { speed: 0.14, soundSpeed: 0.45, baseHz: 110 });

def("F", "Footsteps", "audio", "the band under the foot picks the recipe — grass, stone, wood, water — and the run cycle's contact frame fires it — press to send the hero across", function (u) {
  var D = { bands: ["grass", "stone", "wood", "water"],
            recipes: { grass: { lowpass: 1600, highpass: 300, dur: 0.08, vol: 0.12, rate: 1.0 },
                       stone: { lowpass: 5000, highpass: 900, dur: 0.05, vol: 0.16, rate: 1.2 },
                       wood:  { lowpass: 700,  highpass: 80,  dur: 0.11, vol: 0.18, rate: 0.6 },
                       water: { lowpass: 2600, highpass: 400, dur: 0.2,  vol: 0.14, rate: 0.9, sweepTo: 500 } },
            colours: ["#5D8A4A", "#8A8AA0", "#8A6A3E", "#4FA3D8"],
            speed: 0.22,        // the hero's pace, screens per second
            cadence: 1.0,       // the run cycle's clock rate (the kit's frame clock)
            legs: 2,            // plants per stride: two for a runner, four for a trot
            humanise: 0.1,      // ± pitch randomisation on every plant
            label: "plant event → recipe[band(x)] · rate × (1 ± humanise)"
  };
  const { ctx, W, H, GY, TAU, stage, hero, dot, ring, rect, line, label, text, clamp, rand, noiseBurst, SUN, BONE, DIM, HOT } = u;
  // a footstep is an EVENT, not a loop: the run cycle has a CONTACT FRAME
  // where a foot lands (the kit's leg swing is sin(frame·9), so a plant is
  // every crossing of ±1), and that instant fires ONE sound. which sound is
  // a SURFACE LOOKUP under the foot — four noise recipes here, four sample
  // sets in a shipped game — and chapter 07's one-line trick, a random pitch
  // on every play, keeps forty steps from sounding like a machine gun. the
  // lexicon's Gait knows the cycle; this card listens to it.
  let armed = false, hx = -20, dir = 1, fc = 0, lastK = 0, led = 0;
  const plants = [];                                   // recent plants: { t, band }
  function bandAt(x) { return clamp(Math.floor(x / W * D.bands.length), 0, D.bands.length - 1); }
  return {
    press(x) { armed = true; dir = x > hx ? 1 : -1; },
    frame(dt, t) {
      stage();
      const bw = W / D.bands.length;
      for (let i = 0; i < D.bands.length; i++) {       // the surface bands, drawn on the ground
        rect(i * bw, GY, bw, H - GY, D.colours[i]);
        rect(i * bw, GY - 2, bw, 3, "rgba(19,16,32,0.35)");
        label(D.bands[i], i * bw + bw / 2, GY + 16, "rgba(19,16,32,0.75)", "center");
      }
      hx += dir * W * D.speed * dt;
      if (hx > W + 24) dir = -1; else if (hx < -24) dir = 1;
      fc += dt * D.cadence;
      const ph = fc * 9;                               // the kit's swing phase
      const k = Math.floor((ph - Math.PI / 2) / (Math.PI * 2 / D.legs));   // which plant we are on
      if (k !== lastK) {                               // the contact frame: fire the event
        lastK = k; led = 1;
        const b = bandAt(hx), name = D.bands[b], r = D.recipes[name];
        plants.push({ t: t, band: b });
        if (plants.length > 24) plants.shift();
        if (armed && r) noiseBurst({ dur: r.dur, vol: r.vol, lowpass: r.lowpass, highpass: r.highpass, sweepTo: r.sweepTo,
                                     rate: r.rate * (1 + rand(-D.humanise, D.humanise)), pan: clamp(hx / W * 2 - 1, -1, 1) });
      }
      led = Math.max(0, led - dt * 6);
      const b = bandAt(clamp(hx, 0, W - 1)), name = D.bands[b], r = D.recipes[name];
      if (led > 0) ring(hx, GY, 3 + (1 - led) * 12, "rgba(232,229,244," + led * 0.8 + ")", 1.5);
      hero(hx, GY - (name === "water" ? 3 : 0), { pose: "run", frame: fc, face: dir });
      // the recipe card for the band underfoot, and the plant LED
      const px = 8, py = 8, pw = W * 0.46, phh = H * 0.3;
      rect(px, py, pw, phh, "rgba(19,16,32,0.6)");
      ctx.strokeStyle = "rgba(201,196,228,0.35)"; ctx.lineWidth = 1; ctx.strokeRect(px, py, pw, phh);
      text(name, px + 6, py + 13, 11, D.colours[b], "left", true);
      dot(px + pw - 10, py + 9, 4, led > 0 ? SUN : "rgba(245,193,105,0.2)");
      label("plant", px + pw - 18, py + 12, DIM, "right");
      const rows = [["lowpass", r.lowpass / 6000], ["highpass", r.highpass / 6000], ["dur", r.dur / 0.25], ["vol", r.vol / 0.25]];
      for (let i = 0; i < rows.length; i++) {
        const yy = py + 20 + i * ((phh - 24) / rows.length);
        label(rows[i][0], px + 6, yy + 8, DIM);
        rect(px + pw * 0.42, yy + 1, pw * 0.52, 7, "rgba(201,196,228,0.12)");
        rect(px + pw * 0.42, yy + 1, pw * 0.52 * clamp(rows[i][1], 0, 1), 7, D.colours[b]);
      }
      // the last few plants on a timeline, coloured by band
      const tx0 = W * 0.56, tw = W * 0.4, ty = H * 0.16;
      line(tx0, ty, tx0 + tw, ty, DIM, 1);
      label("plants, last 4 s", tx0, ty - 6, DIM);
      for (let i = 0; i < plants.length; i++) {
        const age = t - plants[i].t;
        if (age > 4) continue;
        dot(tx0 + tw * (1 - age / 4), ty, 3, D.colours[plants[i].band]);
      }
      label("legs " + D.legs + " · " + (9 * D.cadence / (Math.PI * 2 / D.legs)).toFixed(1) + " plants/s", tx0, ty + 16, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Footsteps", "Fourlegs", "a trotting animal — four plants per stride at a quicker clock, so the surface changes voice twice as often", { legs: 4, cadence: 0.8, speed: 0.3 });

def("N", "Natter", "audio", "a blip per typed letter, pitched by the character — vowels sing (sine), consonants click (square) — press for the next line", function (u) {
  var D = { lines: ["Hello, traveller.", "The bridge is out again!", "Take the long way round...", "Mind the frogs."],
            base: 300,          // the character's voice: its lowest blip, Hz
            range: 0.6,         // how far above base a letter can sit (× base)
            cps: 6,             // characters per second
            blipEvery: 1,       // sound every nth letter — keeps the voice count polite
            vowelDur: 0.09,     // a vowel rings...
            consDur: 0.04,      // ...a consonant clicks
            hold: 1.6,          // seconds a finished line stays before the next
            vol: 0.12,
            label: "f = base · (1 + hash(letter) · range) · vowel ? sine : square"
  };
  const { ctx, W, H, GY, TAU, stage, hero, dot, rect, line, label, text, clamp, tone, MAGIC, BONE, DIM, INK, SUN } = u;
  // BEEP-SPEAK (Animal Crossing, Undertale, Celeste) is a typewriter with a
  // sound per letter. the letter's code picks a PITCH inside the character's
  // range — a hash, so the same word always sings the same tune — and its
  // class picks the WAVE: vowels get a longer sine, consonants a short square
  // click, spaces are silence. a whole cast of voices is one dial pair
  // (base, range) per character. the grimoire's Typewriter owns the cursor.
  let armed = false, li = 0, shown = 0, charT = 0, holdT = 0, mouth = 0;
  const strip = [];                                    // recent blips: { k, vowel }
  let cur = "";                                        // the letter being typed, for the caption
  function pitchOf(ch) { const c = ch.toLowerCase().charCodeAt(0); return ((c * 37 + 11) % 17) / 16; }
  function isVowel(ch) { return "aeiou".indexOf(ch.toLowerCase()) >= 0; }
  function isLetter(ch) { return /[a-z]/i.test(ch); }
  function wrap(s, maxChars) {
    const words = s.split(" "), out = []; let row = "";
    for (const w of words) { if ((row + " " + w).trim().length > maxChars && row) { out.push(row); row = w; } else row = (row + " " + w).trim(); }
    if (row) out.push(row);
    return out;
  }
  let typed = 0;                                       // letters typed so far, for blipEvery
  return {
    press() { armed = true; li = (li + 1) % D.lines.length; shown = 0; holdT = 0; charT = 0; },
    frame(dt, t) {
      stage({ plain: true });
      const lineS = D.lines[li];
      if (shown < lineS.length) {
        charT += dt;
        const ch = lineS[shown];
        const pause = (ch === "." || ch === "!" || ch === "?") ? 3 : (ch === "," ? 2 : 1);
        if (charT >= pause / Math.max(0.1, D.cps)) {
          charT = 0; shown++; cur = ch;
          if (isLetter(ch)) {
            typed++;
            const k = pitchOf(ch), v = isVowel(ch), f = D.base * (1 + k * D.range);
            strip.push({ k: k, vowel: v }); if (strip.length > 28) strip.shift();
            mouth = v ? 0.25 : 0.1;
            if (armed && typed % Math.max(1, D.blipEvery) === 0)
              tone({ freq: f, type: v ? "sine" : "square", dur: v ? D.vowelDur : D.consDur, vol: D.vol * (v ? 1 : 0.7), attack: 0.004 });
          }
        }
      } else { holdT += dt; if (holdT > D.hold) { li = (li + 1) % D.lines.length; shown = 0; holdT = 0; } }
      mouth = Math.max(0, mouth - dt);
      // the speaker and the bubble
      const hxp = W * 0.16;
      hero(hxp, GY, { frame: t, face: 1 });
      if (mouth > 0) rect(hxp - 2, GY - H * 0.2, 4, 2 + mouth * 12, "#2B2440");
      const bx = W * 0.3, by = H * 0.12, bw = W * 0.62, bh = H * 0.36;
      ctx.fillStyle = "rgba(232,229,244,0.95)"; ctx.beginPath();
      ctx.moveTo(bx + 6, by); ctx.lineTo(bx + bw - 6, by); ctx.quadraticCurveTo(bx + bw, by, bx + bw, by + 6);
      ctx.lineTo(bx + bw, by + bh - 6); ctx.quadraticCurveTo(bx + bw, by + bh, bx + bw - 6, by + bh);
      ctx.lineTo(bx + 18, by + bh); ctx.lineTo(bx + 4, by + bh + 12); ctx.lineTo(bx + 10, by + bh);
      ctx.lineTo(bx + 6, by + bh); ctx.quadraticCurveTo(bx, by + bh, bx, by + bh - 6); ctx.lineTo(bx, by + 6); ctx.quadraticCurveTo(bx, by, bx + 6, by);
      ctx.closePath(); ctx.fill();
      const fs = Math.max(10, Math.round(H / 15));
      const rows = wrap(lineS.slice(0, shown), Math.max(6, Math.floor((bw - 16) / (fs * 0.55))));
      for (let i = 0; i < rows.length; i++) text(rows[i], bx + 8, by + fs + 4 + i * (fs + 3), fs, "#2B2440");
      if (shown < lineS.length && Math.floor(t * 4) % 2 === 0) rect(bx + 8 + (rows.length ? rows[rows.length - 1].length : 0) * fs * 0.55, by + 6 + (rows.length ? rows.length - 1 : 0) * (fs + 3), 2, fs, "#2B2440");
      // the pitch strip: one bar per blip, vowels violet, consonants bone
      const sx = W * 0.3, sy = H * 0.86, sw = W * 0.62, sh = H * 0.2;
      line(sx, sy, sx + sw, sy, DIM, 1);
      label("base " + D.base + " Hz", sx, sy + 12, DIM);
      label("+" + Math.round(D.range * 100) + "%", sx + sw, sy - sh - 2, DIM, "right");
      const bwid = sw / 28;
      for (let i = 0; i < strip.length; i++) {
        const s = strip[i], hgt = 4 + s.k * (sh - 4);
        rect(sx + i * bwid + 1, sy - hgt, Math.max(1, bwid - 2), hgt, s.vowel ? MAGIC : BONE);
      }
      if (isLetter(cur)) {
        const f = Math.round(D.base * (1 + pitchOf(cur) * D.range));
        text(cur + " → " + f + " Hz " + (isVowel(cur) ? "sine" : "square"), W * 0.16, H * 0.12, 11, isVowel(cur) ? MAGIC : BONE, "center");
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Natter", "Nasal", "a high squeaky voice typing fast — twice the base pitch, eleven letters a second, a blip on every other one", { base: 640, cps: 11, blipEvery: 2 });

def("E", "Envelopes", "audio", "six recipes beyond the blip — explosion, jump, hurt, pickup, whistle, boing — each a pitch and gain envelope, drawn — press to play the one you click", function (u) {
  var D = { recipes: [ { name: "explosion", kind: "noise", lowpass: 2600, sweepTo: 120, dur: 0.55, vol: 0.22 },
                       { name: "jump", kind: "tone", wave: "square", f0: 200, f1: 620, dur: 0.16, vol: 0.14 },
                       { name: "hurt", kind: "tone", wave: "square", f0: 340, f1: 90, dur: 0.22, vol: 0.14 },
                       { name: "pickup", kind: "arp", wave: "triangle", notes: [523, 659, 784, 1047], step: 0.055, dur: 0.09, vol: 0.14 },
                       { name: "whistle", kind: "tone", wave: "sine", f0: 320, f1: 1400, dur: 0.5, vol: 0.16, attack: 0.05 },
                       { name: "boing", kind: "tone", wave: "sawtooth", f0: 260, f1: 60, dur: 0.38, vol: 0.12, attack: 0.01 } ],
            wave: "auto",       // "auto" keeps each recipe's own wave; "square" forces the NES kit
            stretch: 1,         // × every duration
            every: 1.5,         // seconds between the autopilot's plays
            fLo: 50, fHi: 2000, // the pitch axis, Hz, drawn on a log scale
            label: "gain: 0 → vol in attack, → 0 by dur · pitch: f0 → f1 (exponential)"
  };
  const { ctx, W, H, TAU, stage, rect, line, dot, label, text, clamp, tone, noiseBurst, SUN, HOT, MAGIC, WATER, GOOD, FIRE, BONE, DIM } = u;
  // chapter 07's blip is one oscillator with a GAIN ENVELOPE (up fast, down
  // slowly) and a PITCH ENVELOPE (f0 sliding to f1). every classic effect
  // is those two curves with different numbers: a jump slides up, a hurt is
  // a square falling, a whistle is a long sine sweep, a boing is a sawtooth
  // dropping, a pickup is the same blip four times up an ARPEGGIO, and an
  // explosion swaps the oscillator for noise and sweeps a LOWPASS instead of
  // a pitch. each panel draws the two curves; a play sweeps a playhead over them.
  let armed = false, clock = 0, next = 0, playing = null;
  const colours = [FIRE, GOOD, HOT, SUN, WATER, MAGIC];
  function lengthOf(r) { return (r.kind === "arp" ? r.notes.length * r.step + r.dur : r.dur) * D.stretch; }
  function sound(r) {
    const s = D.stretch, wave = D.wave === "auto" ? r.wave : D.wave;
    if (r.kind === "noise") noiseBurst({ dur: r.dur * s, vol: r.vol, lowpass: r.lowpass, sweepTo: r.sweepTo });
    else if (r.kind === "arp") for (let k = 0; k < r.notes.length; k++) tone({ freq: r.notes[k], type: wave, dur: r.dur * s, vol: r.vol, at: k * r.step * s });
    else tone({ freq: r.f0, slideTo: r.f1, type: wave, dur: r.dur * s, vol: r.vol, attack: (r.attack || 0.006) * s });
  }
  function play(i, t) { playing = { i: i, t0: t }; if (armed) sound(D.recipes[i]); }
  function fy(f, y0, h) { const lo = Math.log(D.fLo), hi = Math.log(D.fHi); return y0 + h - h * clamp((Math.log(Math.max(1, f)) - lo) / (hi - lo), 0, 1); }
  function gainAt(r, tau, total) {                     // the kit's envelope: exp up in attack, exp down to dur
    const a = (r.attack || 0.006) * D.stretch;
    if (tau < a) return tau / a;
    return Math.pow(0.0005, (tau - a) / Math.max(0.001, total - a));
  }
  return {
    press(x, y) {
      armed = true;
      const cols = 3, rows = 2, gx0 = 6, gy0 = 20, gw = (W - 12) / cols, gh = (H - 40) / rows;
      const c = clamp(Math.floor((x - gx0) / gw), 0, cols - 1), r = clamp(Math.floor((y - gy0) / gh), 0, rows - 1);
      const i = r * cols + c;
      if (i < D.recipes.length) { play(i, -1); clock = 0; }
    },
    frame(dt, t) {
      stage({ plain: true });
      if (playing && playing.t0 === -1) playing.t0 = t;
      clock += dt;
      if (clock >= D.every) { clock = 0; play(next, t); next = (next + 1) % D.recipes.length; }
      if (playing && t - playing.t0 > lengthOf(D.recipes[playing.i]) + 0.15) playing = null;
      const cols = 3, gx0 = 6, gy0 = 20, gw = (W - 12) / cols, gh = (H - 40) / 2;
      for (let i = 0; i < D.recipes.length; i++) {
        const r = D.recipes[i], px = gx0 + (i % cols) * gw + 3, py = gy0 + Math.floor(i / cols) * gh + 3, pw = gw - 6, ph = gh - 6;
        const on = playing && playing.i === i, col = colours[i % colours.length];
        rect(px, py, pw, ph, on ? "rgba(232,229,244,0.1)" : "rgba(19,16,32,0.55)");
        ctx.strokeStyle = on ? col : "rgba(201,196,228,0.3)"; ctx.lineWidth = on ? 1.5 : 1; ctx.strokeRect(px, py, pw, ph);
        text(r.name, px + 4, py + 11, 10, col, "left", true);
        const wave = r.kind === "noise" ? "noise" : (D.wave === "auto" ? r.wave : D.wave);
        const total = lengthOf(r), ay = py + 16, ah = ph - 22, n = 24;
        // the gain envelope, filled
        ctx.fillStyle = "rgba(201,196,228,0.18)"; ctx.beginPath(); ctx.moveTo(px + 4, ay + ah);
        for (let k = 0; k <= n; k++) {
          const tau = total * k / n; let g;
          if (r.kind === "arp") { const inn = tau % (r.step * D.stretch), idx = Math.floor(tau / (r.step * D.stretch)); g = idx < r.notes.length ? gainAt(r, inn, r.dur * D.stretch) : 0; }
          else g = gainAt(r, tau, total);
          ctx.lineTo(px + 4 + (pw - 8) * k / n, ay + ah - ah * clamp(g, 0, 1));
        }
        ctx.lineTo(px + pw - 4, ay + ah); ctx.closePath(); ctx.fill();
        // the pitch (or cutoff) curve, exponential between f0 and f1
        ctx.strokeStyle = col; ctx.lineWidth = 1.5; ctx.beginPath();
        if (r.kind === "arp") {
          for (let k = 0; k < r.notes.length; k++) {
            const x0 = px + 4 + (pw - 8) * (k * r.step * D.stretch) / total, x1 = px + 4 + (pw - 8) * ((k * r.step + r.dur) * D.stretch) / total;
            ctx.moveTo(x0, fy(r.notes[k], ay, ah)); ctx.lineTo(Math.min(x1, px + pw - 4), fy(r.notes[k], ay, ah));
          }
        } else {
          const f0 = r.kind === "noise" ? r.lowpass : r.f0, f1 = r.kind === "noise" ? r.sweepTo : r.f1;
          for (let k = 0; k <= n; k++) {
            const f = f0 * Math.pow(f1 / f0, k / n), xx = px + 4 + (pw - 8) * k / n, yy = fy(f, ay, ah);
            if (k === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
          }
        }
        ctx.stroke();
        label(wave, px + 4, py + ph - 3, DIM);
        label(Math.round(total * 1000) + " ms", px + pw - 4, py + ph - 3, DIM, "right");
        if (on) {                                     // the playhead
          const k = clamp((t - playing.t0) / total, 0, 1), xx = px + 4 + (pw - 8) * k;
          line(xx, ay, xx, ay + ah, "rgba(232,229,244,0.8)", 1);
          dot(xx, ay + ah - ah * (r.kind === "arp" ? 1 : clamp(gainAt(r, k * total, total), 0, 1)), 2.5, col);
        }
      }
      label("wave " + D.wave + " · stretch ×" + D.stretch, W / 2, 13, null, "center");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Envelopes", "Eightbit", "square waves only and every envelope shortened — the same six recipes played by a NES", { wave: "square", stretch: 0.6, every: 1.1 });

def("E", "Engine", "audio", "an oscillator whose pitch and volume follow speed — rpm for every vehicle; a car accelerates and brakes on autopilot — drag to throttle", function (u) {
  var D = { wave: "sawtooth",   // the engine's oscillator
            idleHz: 55,         // the note at idle...
            pitchRange: 3.2,    // ...and how many times higher it climbs at top speed
            vol: 0.16,          // the gain at top speed (idleVol at rest)
            idleVol: 0.05,
            seg: 0.25,          // seconds per overlapping tone segment after the first press
            accel: 0.45,        // how fast speed chases the throttle upward, per second
            brake: 0.9,         // ...and downward
            idleRpm: 900, maxRpm: 7000,
            manual: 4,          // seconds a drag's throttle holds before the autopilot takes back the wheel
            label: "f = idle · (1 + speed · range) · gain = lerp(idleVol, vol, speed)"
  };
  const { ctx, W, H, GY, TAU, stage, rect, line, dot, ring, label, text, clamp, lerp, smooth, rand, tone, SUN, HOT, WATER, BONE, DIM, INK } = u;
  // an ENGINE HUM is a continuous oscillator with two lines through it:
  // pitch rises with speed (an rpm curve), gain rises with speed (a throttle
  // curve). a shipped game loops a sample and moves playbackRate along the
  // same line. the kit's voices are one-shot, so after the first press the
  // hum is re-triggered in short OVERLAPPING segments — each one slides from
  // this frame's pitch to the next one's guess, so the joins vanish. the
  // lexicon's Vehicle and Motor knew the speed; this card lets you hear it.
  let armed = false, speed = 0, throttle = 0, manualT = 0, auto = 0, segT = 0, road = 0, lastSeg = 0, wheel = 0, exhaust = 0;
  function freqOf(s) { return D.idleHz * (1 + s * D.pitchRange); }
  return {
    drag: true,
    press(x) { armed = true; throttle = clamp(x / W, 0, 1); manualT = D.manual; },
    frame(dt, t) {
      stage({ night: 0.2 });
      if (manualT > 0) manualT -= dt;
      else {                                            // the autopilot's throttle: a slow cycle of pull, cruise, brake
        auto += dt; const ph = auto % 9;
        throttle = ph < 3 ? 1 : (ph < 5.5 ? 0.55 : (ph < 7 ? 0 : 0.25));
      }
      const rate = throttle > speed ? D.accel : D.brake;
      speed += (throttle - speed) * smooth(rate * 2.2, dt);
      speed = clamp(speed, 0, 1);
      const f = freqOf(speed), g = lerp(D.idleVol, D.vol, speed), rpm = lerp(D.idleRpm, D.maxRpm, speed);
      segT += dt;
      if (armed && segT >= D.seg) {                     // one overlapping segment per tick, sliding toward the guess
        segT = 0;
        const guess = clamp(speed + (speed - lastSeg), 0, 1); lastSeg = speed;
        tone({ freq: f, slideTo: freqOf(guess), type: D.wave, dur: D.seg * 1.8, vol: g, attack: D.seg * 0.6, decayTo: g * 0.3 });
      }
      // the road scrolls under a fixed car
      road = (road + speed * W * 0.9 * dt) % 40; wheel += speed * 14 * dt;
      const ry = GY - H * 0.04;
      rect(0, ry - 6, W, 12, "rgba(45,40,70,0.95)");
      ctx.setLineDash([16, 24]); ctx.lineDashOffset = road; line(0, ry, W, ry, "rgba(232,229,244,0.3)", 1); ctx.setLineDash([]); ctx.lineDashOffset = 0;
      const cx = W * 0.42, cw = W * 0.16, ch = H * 0.07;
      const tilt = (throttle - speed) * 0.08;           // the nose lifts under throttle, dips under brake
      ctx.save(); ctx.translate(cx, ry - 3); ctx.rotate(-tilt);
      rect(-cw / 2, -ch, cw, ch, HOT);
      rect(-cw * 0.28, -ch * 1.75, cw * 0.5, ch * 0.75, "#2B2440");
      for (let w = -1; w <= 1; w += 2) {
        dot(w * cw * 0.32, 2, ch * 0.34, "#2B2440"); dot(w * cw * 0.32, 2, ch * 0.16, BONE);
        line(w * cw * 0.32, 2, w * cw * 0.32 + Math.cos(wheel) * ch * 0.3, 2 + Math.sin(wheel) * ch * 0.3, "#2B2440", 1.5);
      }
      ctx.restore();
      exhaust += dt * (2 + speed * 10);
      if (throttle > speed + 0.05) for (let k = 0; k < 3; k++) { const a = ((exhaust + k * 0.33) % 1); dot(cx - cw / 2 - 4 - a * 18, ry - 4 - a * 6 + Math.sin(a * 9) * 2, 1.5 + a * 3, "rgba(201,196,228," + (0.4 * (1 - a)) + ")"); }
      // the rpm gauge: an arc, a redline, a needle
      const gx = W - H * 0.22 - 6, gy = H * 0.3, gr = H * 0.19;
      ctx.fillStyle = "rgba(19,16,32,0.6)"; ctx.beginPath(); ctx.arc(gx, gy, gr + 6, Math.PI * 0.75, Math.PI * 2.25); ctx.lineTo(gx, gy); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = BONE; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(gx, gy, gr, Math.PI * 0.75, Math.PI * 2.05); ctx.stroke();
      ctx.strokeStyle = HOT; ctx.beginPath(); ctx.arc(gx, gy, gr, Math.PI * 2.05, Math.PI * 2.25); ctx.stroke();
      for (let k = 0; k <= 7; k++) { const a = Math.PI * 0.75 + Math.PI * 1.5 * k / 7; line(gx + Math.cos(a) * (gr - 4), gy + Math.sin(a) * (gr - 4), gx + Math.cos(a) * gr, gy + Math.sin(a) * gr, BONE, 1); }
      const na = Math.PI * 0.75 + Math.PI * 1.5 * clamp((rpm - 0) / 8000, 0, 1);
      line(gx, gy, gx + Math.cos(na) * (gr - 2), gy + Math.sin(na) * (gr - 2), SUN, 2); dot(gx, gy, 3, SUN);
      label(Math.round(rpm) + " rpm", gx, gy + gr + 4, BONE, "center");
      // the two lines through the engine: pitch and gain against speed
      const px = 8, py = 8, pw = W * 0.36, ph = H * 0.3;
      rect(px, py, pw, ph, "rgba(19,16,32,0.6)"); ctx.strokeStyle = "rgba(201,196,228,0.3)"; ctx.lineWidth = 1; ctx.strokeRect(px, py, pw, ph);
      label("speed →", px + pw - 4, py + ph - 3, DIM, "right");
      line(px + 4, py + ph - 4, px + pw - 4, py + 6, SUN, 1.5);                         // pitch: a straight line
      line(px + 4, py + ph - 4 - (ph - 10) * D.idleVol / 0.25, px + pw - 4, py + ph - 4 - (ph - 10) * D.vol / 0.25, WATER, 1.5);   // gain: another
      const sx = px + 4 + (pw - 8) * speed;
      line(sx, py + 4, sx, py + ph - 4, "rgba(232,229,244,0.4)", 1);
      dot(sx, py + ph - 4 - (ph - 10) * speed, 3, SUN); dot(sx, py + ph - 4 - (ph - 10) * g / 0.25, 3, WATER);
      label(Math.round(f) + " Hz", px + 4, py + 11, SUN); label("gain " + g.toFixed(2), px + 4, py + 21, WATER);
      // the throttle bar
      const tx = 8, ty = H * 0.46, tw = W * 0.36;
      rect(tx, ty, tw, 8, "rgba(201,196,228,0.15)"); rect(tx, ty, tw * throttle, 8, manualT > 0 ? HOT : BONE);
      rect(tx + tw * speed - 1, ty - 2, 2, 12, INK);
      label("throttle " + throttle.toFixed(2) + (manualT > 0 ? " (yours)" : " (auto)") + " · speed " + speed.toFixed(2), tx, ty + 20, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Engine", "Electric", "a sine whine that starts high and climbs higher, quieter than the petrol note — the same two lines, a different motor", { wave: "sine", idleHz: 240, vol: 0.09 });

def("N", "Noisebed", "audio", "wind, rain, surf and fire are one noise source under a filter, with slow LFOs on the cutoff and the gain — the curves drawn — press for the next bed", function (u) {
  var D = { beds: { wind: { lowpass: 900, highpass: 120, lfo: 0.13, depth: 0.8, glfo: 0.21, gdepth: 0.6, vol: 0.14, rate: 0.7 },
                    rain: { lowpass: 6000, highpass: 1500, lfo: 0.5, depth: 0.25, glfo: 1.3, gdepth: 0.25, vol: 0.12, rate: 1.4 },
                    surf: { lowpass: 1400, highpass: 200, lfo: 0.09, depth: 0.9, glfo: 0.09, gdepth: 0.8, vol: 0.16, rate: 0.8 },
                    fire: { lowpass: 2400, highpass: 300, lfo: 0.9, depth: 0.5, glfo: 2.2, gdepth: 0.45, vol: 0.12, rate: 1.0 } },
            order: ["wind", "rain", "surf", "fire"],
            bed: "wind",        // the bed to start on
            second: "",         // a second bed layered underneath, always on ("" for none)
            lfoScale: 1,        // × every LFO rate
            grain: 0.4,         // seconds between overlapping noise grains after the first press
            every: 7,           // seconds before the autopilot moves to the next bed
            label: "cutoff = lp · 2^(depth · sin 2π·lfo·t) · gain = vol · (1 − gdepth · (1 − sin 2π·glfo·t)/2)"
  };
  const { ctx, W, H, TAU, stage, rect, line, dot, label, text, clamp, noise, noiseBurst, SUN, WATER, FIRE, BONE, DIM, INK, GOOD } = u;
  // every ambience bed is the same trick: WHITE NOISE through a highpass and
  // a LOWPASS, with two slow LFOs — one wandering the cutoff (the "whoosh"
  // of wind, the roll of surf), one wandering the gain (gusts, the wave's
  // rise). the recipe is six numbers, so wind, rain, surf and fire are four
  // rows of a table. the kit's noise is one-shot, so after the first press
  // the bed is a train of overlapping GRAINS, each sweeping its cutoff from
  // this tick's value to the next one's. chapter 07 called this "synthesize".
  let armed = false, idx = Math.max(0, D.order.indexOf(D.bed)), clock = 0, grainT = 0;
  function cutoff(b, tt) { return b.lowpass * Math.pow(2, b.depth * Math.sin(TAU * b.lfo * D.lfoScale * tt)); }
  function gain(b, tt) { const s = Math.sin(TAU * b.glfo * D.lfoScale * tt) * 0.75 + noise(tt * b.glfo * D.lfoScale * 3 + 7) * 0.25; return b.vol * (1 - b.gdepth * (1 - s) / 2); }
  function fx(f, x0, w) { return x0 + w * clamp((Math.log(Math.max(20, f)) - Math.log(40)) / (Math.log(12000) - Math.log(40)), 0, 1); }
  const colourOf = { wind: BONE, rain: WATER, surf: GOOD, fire: FIRE };
  function panel(name, b, x0, y0, w, h, tt, main) {
    const col = colourOf[name] || SUN, cut = cutoff(b, tt), g = gain(b, tt);
    rect(x0, y0, w, h, "rgba(19,16,32,0.6)"); ctx.strokeStyle = "rgba(201,196,228,0.3)"; ctx.lineWidth = 1; ctx.strokeRect(x0, y0, w, h);
    text(name + (main ? "" : " (under)"), x0 + 4, y0 + 11, 10, col, "left", true);
    // left: the filter's response on a log frequency axis, cutoff moving
    const fw = w * 0.42, fy0 = y0 + 16, fh = h - 22;
    label("hp " + b.highpass, x0 + 4, y0 + h - 3, DIM); label("lp " + Math.round(cut), x0 + fw, y0 + h - 3, col, "right");
    ctx.fillStyle = "rgba(201,196,228,0.14)"; ctx.beginPath(); ctx.moveTo(x0 + 4, fy0 + fh);
    for (let k = 0; k <= 30; k++) {
      const f = 40 * Math.pow(300, k / 30);
      const hpk = 1 / Math.sqrt(1 + Math.pow(b.highpass / f, 4)), lpk = 1 / Math.sqrt(1 + Math.pow(f / cut, 4));
      ctx.lineTo(fx(f, x0 + 4, fw - 8), fy0 + fh - fh * hpk * lpk * g / 0.25);
    }
    ctx.lineTo(x0 + fw - 4, fy0 + fh); ctx.closePath(); ctx.fill();
    line(fx(cut, x0 + 4, fw - 8), fy0, fx(cut, x0 + 4, fw - 8), fy0 + fh, col, 1.5);
    // right: the two LFO curves over an 8-second window with the playhead
    const lx = x0 + fw + 6, lw = w - fw - 10, span = 8;
    for (let row = 0; row < 2; row++) {
      const ry0 = fy0 + row * (fh / 2), rh = fh / 2 - 3;
      label(row ? "gain lfo " + (b.glfo * D.lfoScale).toFixed(2) + " Hz" : "cutoff lfo " + (b.lfo * D.lfoScale).toFixed(2) + " Hz", lx, ry0 + 8, DIM);
      ctx.strokeStyle = row ? col : "rgba(232,229,244,0.6)"; ctx.lineWidth = 1; ctx.beginPath();
      for (let k = 0; k <= 32; k++) {
        const tk = tt - span * 0.7 + span * k / 32;
        const v = row ? gain(b, tk) / b.vol : (Math.log(cutoff(b, tk) / b.lowpass) / Math.LN2 / Math.max(0.05, b.depth) + 1) / 2;
        const xx = lx + lw * k / 32, yy = ry0 + rh - (rh - 9) * clamp(v, 0, 1);
        if (k === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
      }
      ctx.stroke();
      const pxh = lx + lw * 0.7;
      line(pxh, ry0 + 8, pxh, ry0 + rh, "rgba(232,229,244,0.35)", 1);
      dot(pxh, ry0 + rh - (rh - 9) * clamp(row ? g / b.vol : (Math.log(cut / b.lowpass) / Math.LN2 / Math.max(0.05, b.depth) + 1) / 2, 0, 1), 2.5, col);
    }
  }
  function grains(b, tt) {
    noiseBurst({ dur: D.grain * 2.4, vol: clamp(gain(b, tt), 0, 0.25), lowpass: cutoff(b, tt), sweepTo: cutoff(b, tt + D.grain), highpass: b.highpass, rate: b.rate, attack: D.grain * 0.8 });
  }
  return {
    press() { armed = true; idx = (idx + 1) % D.order.length; clock = 0; },
    frame(dt, t) {
      stage({ plain: true });
      clock += dt;
      if (clock >= D.every) { clock = 0; idx = (idx + 1) % D.order.length; }
      const name = D.order[idx], b = D.beds[name], b2 = D.second ? D.beds[D.second] : null;
      grainT += dt;
      if (armed && grainT >= D.grain) { grainT = 0; grains(b, t); if (b2) grains(b2, t); }
      const ph = b2 ? (H - 34) / 2 : H - 34;
      panel(name, b, 6, 18, W - 12, ph - 4, t, true);
      if (b2) panel(D.second, b2, 6, 18 + ph, W - 12, ph - 4, t, false);
      // a strip of pictograms: which bed is on, and the countdown to the next
      for (let i = 0; i < D.order.length; i++) {
        const x = W * 0.5 + (i - (D.order.length - 1) / 2) * 44;
        label(D.order[i], x, 12, i === idx ? (colourOf[D.order[i]] || SUN) : DIM, "center");
        if (i === idx) rect(x - 18, 14, 36 * clamp(1 - clock / D.every, 0, 1), 1.5, colourOf[D.order[i]] || SUN);
      }
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Noisebed", "Nightrain", "rain on top and distant surf underneath, both LFOs slowed — the same two filters, at night", { bed: "rain", second: "surf", lfoScale: 0.4 });

def("Q", "Quiet", "audio", "a lowpass slides shut when the hero is under water — the 'you are somewhere else' filter; its cutoff drawn on a spectrum — press to dive or surface", function (u) {
  var D = { mode: "water",      // "water": the hero dives; "door": the cutoff follows distance behind a door
            openHz: 12000,      // the cutoff with nothing in the way...
            closedHz: 380,      // ...and fully muffled
            slide: 5,           // how fast the cutoff slides, per second
            every: 3.5,         // seconds between the autopilot's dives and surfacings
            tick: 0.45,         // seconds between the world's noise ticks after the first press
            range: 0.5,         // door mode: the distance (of W) over which the muffle closes fully
            bars: 24,
            label: "cutoff = open · (closed/open)^m · |H(f)| = 1/√(1 + (f/cutoff)⁴)"
  };
  const { ctx, W, H, GY, TAU, stage, hero, wall, rect, line, dot, label, text, clamp, lerp, smooth, rand, noise, noiseBurst, WATER, SUN, HOT, BONE, DIM, INK } = u;
  // MUFFLE is one LOWPASS on the whole SFX bus (chapter 07's buses): its
  // cutoff slides from wide open to a few hundred hertz and the world goes
  // distant — under water, behind a door, on the pause screen. the drawn
  // spectrum is what the filter does: the response |H(f)| falls off above
  // the cutoff, so the high bars die first. m is the muffle amount, and the
  // cutoff moves along a LOG scale (the ear hears octaves), which is why the
  // formula is a power and not a lerp.
  let armed = false, m = 0, under = false, clock = 0, tickT = 0, hx = W * 0.3, hy = GY, tx = W * 0.75;
  const shape = [];
  for (let i = 0; i < 32; i++) shape.push(0.35 + 0.65 * Math.pow(1 - i / 32, 1.6) * (0.7 + 0.3 * Math.sin(i * 1.7)));
  function fOf(i) { return 40 * Math.pow(400, (i + 0.5) / D.bars); }
  return {
    press(x) {
      armed = true;
      if (D.mode === "door") tx = clamp(x, 16, W - 16); else { under = !under; clock = 0; }
    },
    frame(dt, t) {
      let target;
      if (D.mode === "door") {
        stage({ night: 0.35 });
        hx += clamp(tx - hx, -1, 1) * Math.min(Math.abs(tx - hx), W * 0.22 * dt);
        if (Math.abs(tx - hx) < 2) { clock += dt; if (clock > D.every * 0.6) { clock = 0; tx = rand(W * 0.08, W * 0.92); } }
        const doorX = W * 0.5, behind = clamp((hx - doorX) / (W * D.range), 0, 1);
        target = hx > doorX ? 0.45 + 0.55 * behind : 0;
        wall(doorX - 3, GY - H * 0.42, 6, H * 0.42);
        rect(doorX - 3, GY - H * 0.2, 6, H * 0.2, "#5A3E2B"); dot(doorX + 1.5, GY - H * 0.1, 1.2, SUN);
        hero(hx, GY, { face: tx > hx ? 1 : -1, pose: Math.abs(tx - hx) > 2 ? "run" : "stand", frame: t });
        dot(W * 0.12, GY - H * 0.14, 4, BONE); label("listener", W * 0.12, GY + 12, DIM, "center");
        ctx.setLineDash([3, 4]); line(W * 0.12, GY - H * 0.14, hx, GY - H * 0.14, DIM, 1); ctx.setLineDash([]);
        label(hx > doorX ? "behind the door · " + Math.round(behind * 100) + "% of range" : "same room", (W * 0.12 + hx) / 2, GY - H * 0.16, DIM, "center");
      } else {
        stage({ night: 0.15 });
        clock += dt;
        if (clock >= D.every) { clock = 0; under = !under; }
        const px = W * 0.4;
        rect(px, GY, W - px, H - GY, WATER);
        rect(px - 4, GY - 4, 4, H - GY + 4, "#5A3E2B");
        const goalX = under ? W * 0.68 : px - 12, goalY = under ? GY + H * 0.11 : GY - 4;
        hx += (goalX - hx) * smooth(4, dt); hy += (goalY - hy) * smooth(3, dt);
        target = under ? 1 : 0;
        hero(hx, hy, { face: under ? 1 : 1, pose: under ? "jump" : "stand", frame: t });
        rect(px, GY, W - px, H - GY, "rgba(79,163,216,0.45)");   // the water over the hero
        for (let k = 0; k < 6; k++) { const a = (t * 0.4 + k * 0.17) % 1; if (hy > GY) dot(hx + Math.sin(k * 5 + t) * 6, hy - H * 0.16 - a * (hy - GY + H * 0.16), 1 + k % 2, "rgba(232,229,244," + (0.5 * (1 - a)) + ")"); }
        line(px, GY, W, GY, "rgba(232,229,244,0.6)", 1.5);
        label(under ? "under water" : "on the pier", hx, H - 20, DIM, "center");
      }
      m += (target - m) * smooth(D.slide, dt);
      m = clamp(m, 0, 1);
      const cut = D.openHz * Math.pow(D.closedHz / D.openHz, m);
      tickT += dt;
      if (armed && tickT >= D.tick) {                     // the world's ticks: noise through the muffle
        tickT = 0;
        noiseBurst({ dur: 0.22, vol: 0.12, lowpass: cut, highpass: 150, rate: rand(0.8, 1.25), pan: rand(-0.6, 0.6) });
      }
      if (m > 0.02) rect(0, 0, W, H, "rgba(30,60,110," + (0.35 * m) + ")");   // the screen goes distant too
      // the spectrum: the world's bars, filtered by |H(f)|, and the cutoff line
      const sx = 8, sy = 8, sw = W * 0.55, sh = H * 0.32, bw = sw / D.bars;
      rect(sx, sy, sw, sh, "rgba(19,16,32,0.6)"); ctx.strokeStyle = "rgba(201,196,228,0.3)"; ctx.lineWidth = 1; ctx.strokeRect(sx, sy, sw, sh);
      for (let i = 0; i < D.bars; i++) {
        const f = fOf(i), h0 = shape[i] * (0.75 + 0.25 * noise(i * 0.7 + t * 4)), Hf = 1 / Math.sqrt(1 + Math.pow(f / cut, 4));
        const x = sx + i * bw + 1;
        rect(x, sy + sh - 2 - (sh - 14) * h0, bw - 2, (sh - 14) * h0, "rgba(201,196,228,0.12)");
        rect(x, sy + sh - 2 - (sh - 14) * h0 * Hf, bw - 2, (sh - 14) * h0 * Hf, f > cut ? "rgba(79,163,216,0.7)" : SUN);
      }
      const cx = sx + sw * clamp(Math.log(cut / 40) / Math.log(400), 0, 1);
      line(cx, sy + 2, cx, sy + sh - 2, HOT, 1.5);
      label(Math.round(cut) + " Hz", cx + (cx > sx + sw * 0.6 ? -3 : 3), sy + 11, HOT, cx > sx + sw * 0.6 ? "right" : "left");
      label("m " + m.toFixed(2), sx + 4, sy + sh - 4, DIM);
      label("40", sx + 2, sy + sh + 10, DIM); label("16k", sx + sw, sy + sh + 10, DIM, "right");
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Quiet", "Quietroom", "the hero behind a door — the cutoff follows how far past it he walks, and the listener stays put", { mode: "door", closedHz: 250, range: 0.4 });

def("Y", "Yodel", "audio", "a feedback delay whose mix rises inside the cave — a shout returns at delay·k, each fb times quieter, drawn as fading copies — press to shout", function (u) {
  var D = { delay: 0.32,        // seconds between echoes
            feedback: 0.55,     // each echo × this
            caveMix: 0.75,      // the echo level deep in the cave...
            openMix: 0.05,      // ...and in the open
            maxEchoes: 5,
            every: 2.6,         // seconds between the autopilot's shouts
            caveX: 0.55,        // the cave mouth, of W
            f0: 520, f1: 380, dur: 0.24, vol: 0.18,
            label: "y(t) = x(t) + Σ mix · fb^(k−1) · x(t − k·delay)"
  };
  const { ctx, W, H, GY, TAU, stage, hero, tree, rect, line, dot, ring, label, text, clamp, lerp, ease, tone, MAGIC, SUN, BONE, DIM, INK, NIGHT } = u;
  // an ECHO is a DELAY LINE with FEEDBACK: the shout goes into a buffer,
  // comes out delay seconds later at mix, and a share (fb) of that goes back
  // in — so echo k arrives at k·delay, fb times quieter than the last. a
  // REVERB ZONE is just the mix dial tied to where the hero stands: near
  // zero in the open, high inside the cave, sliding across the mouth. the
  // kit has no tape loop, so the echoes are booked ahead with tone()'s at:
  // the same schedule the delay line would produce, drawn as ghost heroes.
  let armed = false, hx = W * 0.2, dir = 1, clock = 0, mix = 0, want = false;
  const pending = [], fired = [];
  function shout(t) {
    const pan = clamp(hx / W * 2 - 1, -1, 1);
    for (let k = 0; k <= D.maxEchoes; k++) {
      const g = k === 0 ? 1 : mix * Math.pow(D.feedback, k - 1);
      if (g < 0.03) break;
      pending.push({ at: t + k * D.delay, g: g, k: k, x: hx });
      if (armed) tone({ freq: D.f0 * Math.pow(0.985, k), slideTo: D.f1, type: "triangle", dur: D.dur, vol: clamp(D.vol * g, 0, 0.25), pan: k ? pan * 0.3 + 0.5 : pan, attack: 0.02 });
    }
  }
  return {
    press() { armed = true; want = true; clock = 0; },
    frame(dt, t) {
      stage({ night: 0.3 });
      if (want) { want = false; shout(t); }
      const cx = W * D.caveX;
      // the cave: a dark arch over the right of the stage
      ctx.fillStyle = "#2A2440"; ctx.beginPath(); ctx.moveTo(cx, GY); ctx.quadraticCurveTo(cx + W * 0.02, H * 0.2, cx + W * 0.2, H * 0.18); ctx.lineTo(W, H * 0.16); ctx.lineTo(W, GY); ctx.closePath(); ctx.fill();
      ctx.fillStyle = NIGHT; ctx.beginPath(); ctx.moveTo(cx + 8, GY); ctx.quadraticCurveTo(cx + W * 0.06, H * 0.3, cx + W * 0.22, H * 0.28); ctx.lineTo(W, H * 0.27); ctx.lineTo(W, GY); ctx.closePath(); ctx.fill();
      tree(W * 0.08, GY, H * 0.3);
      hx += dir * W * 0.12 * dt;
      if (hx > W * 0.9) dir = -1; else if (hx < W * 0.14) dir = 1;
      const depth = clamp((hx - cx) / (W * 0.12), 0, 1);
      mix = lerp(D.openMix, D.caveMix, ease(depth));
      clock += dt;
      if (clock >= D.every) { clock = 0; shout(t); }
      for (let i = pending.length - 1; i >= 0; i--) if (pending[i].at <= t) { const e = pending[i]; e.t0 = t; fired.push(e); pending.splice(i, 1); }
      while (fired.length > 12) fired.shift();
      if (pending.length > 24) pending.splice(0, pending.length - 24);
      hero(hx, GY, { face: dir, pose: "run", frame: t });
      for (let i = fired.length - 1; i >= 0; i--) {     // each echo: a ghost of the shouter, deeper in, fading
        const e = fired[i], age = t - e.t0, life = 0.7;
        if (age > life) { fired.splice(i, 1); continue; }
        const a = e.g * (1 - age / life);
        if (e.k === 0) { ring(e.x, GY - H * 0.22, 4 + age * 40, "rgba(245,193,105," + a * 0.8 + ")", 1.5); text("hey!", e.x, GY - H * 0.3 - age * 10, 11, SUN, "center", true); continue; }
        const gx = clamp(cx + W * 0.085 * e.k, 0, W - 10);
        hero(gx, GY, { face: -1, pose: "stand", alpha: a * 0.8, tint: "rgba(201,160,245,0.6)", frame: 0 });
        label("×" + e.g.toFixed(2), gx, GY - H * 0.3 - (e.k % 2) * 11, "rgba(201,160,245," + a + ")", "center");
        ring(gx, GY - H * 0.22, 4 + age * 30, "rgba(201,160,245," + a * 0.6 + ")", 1);
      }
      // the delay line: a loop with a write head, the feedback path, and the mix
      const bx = 8, by = 8, bw = W * 0.5, bh = 12;
      rect(bx, by, bw, bh, "rgba(19,16,32,0.6)"); ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.strokeRect(bx, by, bw, bh);
      const head = (t / D.delay) % 1;
      rect(bx + bw * head - 1, by - 2, 2, bh + 4, SUN);
      for (let k = 0; k < pending.length; k++) { const e = pending[k], frac = clamp(1 - (e.at - t) / D.delay, 0, 1); if (e.at - t <= D.delay) dot(bx + bw * ((head + 1 - frac + 1) % 1), by + bh / 2, 2.5, MAGIC); }
      label("delay " + D.delay + " s", bx, by + bh + 11, DIM);
      ctx.strokeStyle = MAGIC; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(bx + bw, by + bh / 2); ctx.lineTo(bx + bw + 8, by + bh / 2); ctx.lineTo(bx + bw + 8, by + bh + 18); ctx.lineTo(bx - 6, by + bh + 18); ctx.lineTo(bx - 6, by + bh / 2); ctx.lineTo(bx, by + bh / 2); ctx.stroke();
      label("fb " + D.feedback, bx + bw + 12, by + bh + 21, MAGIC);
      const mxp = W * 0.62, mw = W * 0.3;
      rect(mxp, by + 2, mw, 8, "rgba(201,196,228,0.15)"); rect(mxp, by + 2, mw * mix, 8, MAGIC);
      label("mix " + mix.toFixed(2) + (depth > 0.5 ? " · cave" : " · open"), mxp, by + 21, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Yodel", "Yawningcave", "a long delay and high feedback — the shout comes back five times over three seconds, a canyon rather than a cave", { delay: 0.6, feedback: 0.82, caveMix: 0.92 });

def("J", "Jukebox", "audio", "three music layers fade in with intensity, sections switch on the bar, stingers land on the beat — meters draw it — press to raise the intensity", function (u) {
  var D = { tempo: 100,         // beats per minute; a step is an eighth
            steps: 8,           // steps per bar
            patterns: { drums: [1, 0, 2, 0, 1, 0, 2, 2], bass: [1, 0, 0, 1, 0, 1, 0, 0], lead: [0, 0, 1, 0, 1, 0, 0, 1] },
            bassNotes: [110, 131, 98, 147], leadNotes: [440, 523, 587, 659, 784],
            thresholds: [0, 0.35, 0.7],   // the intensity at which each layer starts to fade in
            fade: 1.5,          // the fade rate, per second
            floor: 0,           // the lowest intensity the autopilot drifts to
            drift: 0.06,        // intensity per second, the autopilot's triangle wave
            sectionEvery: 4,    // bars between A ↔ B requests
            stingerEvery: 4,    // bars between stingers (on the downbeat)
            vol: 0.12,
            label: "gain_i → clamp((I − thr_i)/0.25) · switch on step 0 · stinger on the beat"
  };
  const { ctx, W, H, TAU, stage, rect, line, dot, label, text, clamp, smooth, tone, noiseBurst, SUN, HOT, WATER, GOOD, MAGIC, BONE, DIM, INK } = u;
  // ADAPTIVE MUSIC has two axes. VERTICAL: the track is several layers
  // playing in sync, and an INTENSITY number decides how many you hear —
  // each layer's gain chases clamp((I − threshold)/0.25), so drums come
  // first, then bass, then the lead (chapter 07's fade). HORIZONTAL: a
  // request to change section waits for the BAR LINE, so A becomes B on
  // step 0 and never mid-phrase. a STINGER is a one-shot hit booked for the
  // next beat. the sequencer runs silently until the first press.
  let armed = false, step = -1, stepT = 0, bar = 0, section = 0, pendingSection = false, stinger = 0, stingerReq = false;
  let intensity = 0.2, target = 0.2, idle = 99, dirI = 1;
  const layers = ["drums", "bass", "lead"], gains = [0, 0, 0], colours = [HOT, WATER, MAGIC];
  const flashes = [0, 0, 0];
  function stepDur() { return 60 / D.tempo / 2; }
  function playStep(s) {
    const p = D.patterns;
    for (let i = 0; i < layers.length; i++) {
      const hit = p[layers[i]][s % p[layers[i]].length];
      if (!hit || gains[i] < 0.05) continue;
      flashes[i] = 1;
      if (!armed) continue;
      const v = D.vol * gains[i];
      if (i === 0) { if (hit === 1) noiseBurst({ dur: 0.12, vol: v * 1.4, lowpass: 220, sweepTo: 60 }); else noiseBurst({ dur: 0.04, vol: v * 0.6, highpass: 6000 }); }
      else if (i === 1) tone({ freq: D.bassNotes[(Math.floor(s / 2) + section * 2) % D.bassNotes.length], type: "square", dur: 0.22, vol: v, decayTo: v * 0.2 });
      else tone({ freq: D.leadNotes[(s * 2 + bar + section * 2) % D.leadNotes.length], type: "triangle", dur: 0.2, vol: v });
    }
  }
  function playStinger() {
    stinger = 1;
    if (!armed) return;
    tone({ freq: section ? 659 : 523, type: "sawtooth", dur: 0.35, vol: 0.1, attack: 0.01 });
    tone({ freq: section ? 988 : 784, type: "sawtooth", dur: 0.35, vol: 0.08, attack: 0.01, at: 0.02 });
  }
  return {
    press() { armed = true; idle = 0; target = target + 0.34 > 1.01 ? 0 : clamp(target + 0.34, 0, 1); stingerReq = true; },
    frame(dt, t) {
      stage({ plain: true });
      idle += dt;
      if (idle > 6) {                                     // the autopilot: a slow triangle between floor and 1
        target += dirI * D.drift * dt;
        if (target > 1) { target = 1; dirI = -1; } else if (target < D.floor) { target = D.floor; dirI = 1; }
      }
      target = clamp(Math.max(target, D.floor), 0, 1);
      intensity += (target - intensity) * smooth(3, dt);
      for (let i = 0; i < 3; i++) {
        const want = clamp((intensity - D.thresholds[i]) / 0.25, 0, 1);
        gains[i] += clamp(want - gains[i], -D.fade * dt, D.fade * dt);
        flashes[i] = Math.max(0, flashes[i] - dt * 8);
      }
      stinger = Math.max(0, stinger - dt * 3);
      stepT += dt;
      if (stepT > stepDur() * 4) stepT = stepDur();      // a long skip: resync rather than replay every step
      let guard = 0;
      while (stepT >= stepDur() && guard++ < 4) {
        stepT -= stepDur();
        step = (step + 1) % D.steps;
        if (step === 0) {
          bar++;
          if (pendingSection) { section = 1 - section; pendingSection = false; }
          if (bar % D.sectionEvery === 0) pendingSection = true;
          if (bar % D.stingerEvery === 0) stingerReq = true;
        }
        if (stingerReq && step % 2 === 0) { stingerReq = false; playStinger(); }
        playStep(step);
      }
      // the lanes: one row per layer, a cell per step, lit by the pattern and dimmed by the gain
      const lx = W * 0.24, lw = W * 0.5, ly0 = 24, lh = (H * 0.52) / 3, cw = lw / D.steps;
      for (let i = 0; i < 3; i++) {
        const y = ly0 + i * lh, p = D.patterns[layers[i]];
        text(layers[i], lx - 6, y + lh * 0.55, 10, colours[i], "right", true);
        for (let s = 0; s < D.steps; s++) {
          const hit = p[s % p.length], x = lx + s * cw;
          rect(x + 1, y + 3, cw - 2, lh - 6, "rgba(19,16,32,0.6)");
          if (hit) rect(x + 1, y + 3, cw - 2, lh - 6, "rgba(" + (i === 0 ? "245,138,138" : i === 1 ? "79,163,216" : "201,160,245") + "," + (0.15 + 0.75 * gains[i] * (hit === 2 ? 0.6 : 1)) + ")");
          if (s === step) { ctx.strokeStyle = flashes[i] > 0 && hit ? INK : "rgba(232,229,244,0.5)"; ctx.lineWidth = flashes[i] > 0 && hit ? 2 : 1; ctx.strokeRect(x + 1, y + 3, cw - 2, lh - 6); }
        }
        const mx = lx + lw + 10, mw = W * 0.16;          // the gain meter
        rect(mx, y + lh * 0.35, mw, lh * 0.3, "rgba(201,196,228,0.15)"); rect(mx, y + lh * 0.35, mw * gains[i], lh * 0.3, colours[i]);
        label(gains[i].toFixed(2), mx + mw + 3, y + lh * 0.62, DIM);
      }
      const px = lx + (step + clamp(stepT / stepDur(), 0, 1)) * cw;   // the playhead
      line(px, ly0, px, ly0 + lh * 3, "rgba(232,229,244,0.7)", 1);
      // the intensity slider with the three thresholds
      const sx = 14, sy = ly0, sh = lh * 3;
      rect(sx, sy, 8, sh, "rgba(201,196,228,0.15)"); rect(sx, sy + sh * (1 - intensity), 8, sh * intensity, SUN);
      for (let i = 0; i < 3; i++) { const ty = sy + sh * (1 - D.thresholds[i]); line(sx - 3, ty, sx + 11, ty, colours[i], 1); }
      rect(sx - 2, sy + sh * (1 - target) - 1, 12, 2, INK);
      label("I " + intensity.toFixed(2), sx + 14, sy + sh * (1 - intensity) + 4, DIM);
      // the bar counter, the section and the pending switch, the stinger
      text("bar " + bar + " · step " + (step + 1) + "/" + D.steps, W * 0.24, 14, 11, BONE, "left", true);
      text("section " + (section ? "B" : "A") + (pendingSection ? " → " + (section ? "A" : "B") + " on the bar" : ""), W - 8, 14, 10, pendingSection ? SUN : DIM, "right");
      if (stinger > 0) { rect(0, 0, W, H, "rgba(245,193,105," + stinger * 0.12 + ")"); text("stinger", W / 2, H * 0.86, 12 + stinger * 4, SUN, "center", true); }
      label(D.tempo + " bpm · fade " + D.fade + "/s · " + (idle > 6 ? "autopilot" : "yours"), W * 0.24, H - 22, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Jukebox", "Jamsession", "every layer on from the start, a fast tempo and a stinger on every bar — the boss fight's music", { tempo: 130, floor: 1, stingerEvery: 1 });

def("L", "Lookahead", "audio", "notes booked ahead on the audio clock, never fired from a frame — a frame-timed metronome vs a scheduled one, errors measured — press to start/stop", function (u) {
  var D = { bpm: 120,
            lookahead: 0.1,     // seconds ahead the scheduler books notes
            window: 4,          // seconds of history drawn
            msSpan: 60,         // the error axis, ± ms
            fLow: 330, fHigh: 660, vol: 0.12,
            label: "while (due < now + lookahead) book(due)  vs  if (t ≥ due) play()"
  };
  const { ctx, W, H, TAU, stage, rect, line, dot, ring, label, text, clamp, audio, tone, SUN, HOT, GOOD, BONE, DIM, INK } = u;
  // a frame runs when the browser gets round to it — 16 ms apart, 50 under
  // load — so a metronome that plays "when t passes the beat" is late by a
  // random slice of a frame, and the ear hears the slop. the LOOKAHEAD
  // SCHEDULER (Chris Wilson's "a tale of two clocks") asks a different
  // question each frame: is any beat due inside the next lookahead seconds?
  // if so, book it on the AUDIO CLOCK at its exact time and move on. the
  // frame's jitter never reaches the note; the price is that a booked note
  // cannot be unbooked — press stop and the window still plays out.
  let armed = false, running = true, dueF = 0.5, dueS = 0.5, lastPress = -9;
  const beatsF = [], beatsS = [], queue = [];
  let sumF = 0, nF = 0, maxF = 0;
  function period() { return 60 / D.bpm; }
  return {
    press() {
      armed = true; running = !running;
      if (running) { dueF = -1; dueS = -1; }
    },
    frame(dt, t) {
      stage({ plain: true });
      if (dueF === -1) { dueF = t + period(); dueS = t + period(); }
      const p = period();
      if (running) {
        if (t - dueF > 2) dueF = t;                         // a long skip: resync, do not replay the gap
        if (t >= dueF) {                                    // the frame-timed one: fires late by the frame's slice
          const err = t - dueF;
          beatsF.push({ t: t, err: err }); sumF += err; nF++; maxF = Math.max(maxF, err);
          if (armed) tone({ freq: D.fLow, type: "square", dur: 0.05, vol: D.vol, pan: -0.5 });
          dueF += p; if (t >= dueF) dueF = t + p;
        }
        if (t - dueS > 2) dueS = t;
        let guard = 0;
        while (dueS < t + D.lookahead && guard++ < 8) {     // the scheduled one: book everything inside the window
          queue.push({ due: dueS, booked: t });
          if (armed) tone({ freq: D.fHigh, type: "square", dur: 0.05, vol: D.vol, pan: 0.5, at: Math.max(0, dueS - t) });
          dueS += p;
        }
      }
      for (let i = queue.length - 1; i >= 0; i--) if (queue[i].due <= t) { beatsS.push({ t: queue[i].due, err: 0, late: queue[i].due - queue[i].booked }); queue.splice(i, 1); }
      while (beatsF.length && t - beatsF[0].t > D.window) beatsF.shift();
      while (beatsS.length && t - beatsS[0].t > D.window) beatsS.shift();
      // two rows: a time ruler with ideal beats, the fired beats, and each one's error as a bar
      const rows = [["frame-timed", beatsF, HOT], ["scheduled · lookahead " + Math.round(D.lookahead * 1000) + " ms", beatsS, GOOD]];
      const x0 = 10, x1 = W - 10, tw = x1 - x0, nowX = x0 + tw * 0.78;
      function xOf(tt) { return nowX - (t - tt) / D.window * tw * 0.78; }
      for (let r = 0; r < 2; r++) {
        const y = 22 + r * (H * 0.42), col = rows[r][2], beats = rows[r][1];
        text(rows[r][0], x0, y, 10, col, "left", true);
        const ry = y + 6, rh = H * 0.085;
        rect(x0, ry, tw, rh, "rgba(19,16,32,0.6)");
        for (let k = -20; k <= 4; k++) {                    // the ideal grid
          const tb = Math.floor(t / p) * p + k * p, xx = xOf(tb);
          if (xx >= x0 && xx <= x1) line(xx, ry, xx, ry + rh, "rgba(201,196,228,0.18)", 1);
        }
        line(nowX, ry - 3, nowX, ry + rh + 3, INK, 1); label("now", nowX + 3, ry - 2, DIM);
        if (r === 1) {                                     // the lookahead window and the booked notes inside it
          const wx = nowX + D.lookahead / D.window * tw * 0.78;
          rect(nowX, ry, Math.min(wx, x1) - nowX, rh, "rgba(155,226,138,0.15)");
          for (let k = 0; k < queue.length; k++) { const xx = xOf(queue[k].due); if (xx <= x1) ring(xx, ry + rh / 2, 3, col, 1.5); }
        }
        for (let k = 0; k < beats.length; k++) dot(xOf(beats[k].t), ry + rh / 2, 3, col);
        // the error bars below: last 16 beats, ms
        const ey = ry + rh + 5, eh = H * 0.1, n = Math.min(16, beats.length), ew = (tw - 34) / 16, ex0 = x0 + 34;
        line(ex0, ey + eh, x1, ey + eh, "rgba(201,196,228,0.3)", 1);
        for (let k = 0; k < n; k++) {
          const b = beats[beats.length - n + k], hgt = clamp(b.err * 1000 / D.msSpan, 0, 1) * eh;
          rect(ex0 + k * ew + 1, ey + eh - hgt, ew - 2, hgt, col);
        }
        let mean = 0; for (let k = 0; k < beats.length; k++) mean += beats[k].err; mean = beats.length ? mean / beats.length : 0;
        label(r === 0 ? "error: mean " + (mean * 1000).toFixed(1) + " ms · max " + (maxF * 1000).toFixed(0) + " ms" : "error: 0 ms (booked " + Math.round(D.lookahead * 1000) + " ms early) · " + queue.length + " in the window", x0, ey + eh + 11, DIM);
        label("0", ex0 - 3, ey + eh + 3, DIM, "right"); label(D.msSpan + " ms", ex0 - 3, ey + 7, DIM, "right");
      }
      const ac = audio();
      text(running ? "running · " + D.bpm + " bpm" : "stopped" + (queue.length ? " — " + queue.length + " booked note" + (queue.length > 1 ? "s" : "") + " still due" : ""), W - 8, 14, 10, running ? SUN : HOT, "right");
      label(ac ? "audio clock " + ac.currentTime.toFixed(2) + " s" : "audio clock: none here (silent)", x0, 14, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Lookahead", "Latency", "a slow beat and a huge window — robust against any hitch, but stop and the booked notes keep coming for half a second", { lookahead: 0.6, bpm: 90 });

def("Q", "Quota", "audio", "a cap per sound and a pool of players — over the cap the oldest (or quietest) is stolen; the slots draw it — press for a burst of 20 requests", function (u) {
  var D = { slots: 6,           // the pool of players
            cap: 3,             // instances per sound
            steal: "oldest",    // "oldest" | "quietest" | "newest" (newest = the request is refused)
            burst: 20,          // requests a press queues...
            burstSpan: 0.5,     // ...spread over this many seconds
            rate: 2.5,          // the autopilot's requests per second
            sounds: { coin: { f0: 880, f1: 1320, wave: "triangle", dur: 0.6, vol: 0.12 }, hit: { f0: 220, f1: 70, wave: "square", dur: 0.7, vol: 0.14 } },
            maxPerSec: 6,       // the audio side's courtesy cap on real tones
            label: "count(name) ≥ cap ? steal(policy) : free slot ?: steal(all) · steals shown red"
  };
  const { ctx, W, H, TAU, stage, rect, line, dot, ring, label, text, clamp, rand, tone, SUN, HOT, WATER, GOOD, BONE, DIM, INK } = u;
  // every mixer has a POOL of players and a QUOTA per sound. a request finds
  // its sound's live count: under the cap and a free slot → play; at the cap
  // → STEAL one of its own (the oldest, or the quietest by current level) or
  // refuse the newcomer; pool full → steal across all sounds. twenty coins
  // in a frame cost three voices, not twenty. this page's Pool did the same
  // for particles. the kit cannot cut a voice short, so the audio side plays
  // only the accepted requests, at most six a second.
  let armed = false, acc = 0, burstLeft = 0, burstAcc = 0, tokens = 0, requests = 0, steals = 0, refused = 0;
  const slots = [], log = [];
  for (let i = 0; i < 24; i++) slots.push(null);
  const names = ["coin", "hit"], colours = { coin: SUN, hit: WATER };
  function level(v, t) { const k = clamp(1 - (t - v.born) / D.sounds[v.name].dur, 0, 1); return v.vol * k * k; }
  function victim(list, t) {
    let best = -1;
    for (let i = 0; i < D.slots; i++) {
      const v = slots[i]; if (!v || (list && v.name !== list)) continue;
      if (best < 0) { best = i; continue; }
      if (D.steal === "quietest" ? level(v, t) < level(slots[best], t) : v.born < slots[best].born) best = i;
    }
    return best;
  }
  function request(name, t) {
    requests++;
    let count = 0, free = -1;
    for (let i = 0; i < D.slots; i++) { const v = slots[i]; if (!v) { if (free < 0) free = i; } else if (v.name === name) count++; }
    let slot = free, stolen = false;
    if (count >= D.cap) {
      if (D.steal === "newest") { refused++; log.push({ t: t, name: name, kind: "refused" }); if (log.length > 40) log.shift(); return; }
      slot = victim(name, t); stolen = true;
    } else if (free < 0) { slot = victim(null, t); stolen = true; }
    if (slot < 0) return;
    if (stolen) steals++;
    slots[slot] = { name: name, born: t, vol: rand(0.45, 1), flash: stolen ? 1 : 0 };
    log.push({ t: t, name: name, kind: stolen ? "stole" : "ok" }); if (log.length > 40) log.shift();
    if (armed && tokens >= 1) {
      tokens -= 1; const s = D.sounds[name];
      tone({ freq: s.f0, slideTo: s.f1, type: s.wave, dur: Math.min(0.3, s.dur), vol: s.vol * (0.6 + 0.4 * slots[slot].vol) });
    }
  }
  return {
    press() { armed = true; burstLeft += D.burst; },
    frame(dt, t) {
      stage({ plain: true });
      tokens = Math.min(D.maxPerSec, tokens + dt * D.maxPerSec);
      acc += dt * D.rate;
      while (acc >= 1) { acc -= 1; request(Math.random() < 0.6 ? "coin" : "hit", t); }
      if (burstLeft > 0) {
        burstAcc += dt * D.burst / Math.max(0.05, D.burstSpan);
        while (burstAcc >= 1 && burstLeft > 0) { burstAcc -= 1; burstLeft--; request(Math.random() < 0.7 ? "coin" : "hit", t); }
      }
      for (let i = 0; i < D.slots; i++) { const v = slots[i]; if (v) { v.flash = Math.max(0, v.flash - dt * 3); if (t - v.born > D.sounds[v.name].dur) slots[i] = null; } }
      // the slots: one box per player, its level bar decaying, red when it was just stolen
      const n = Math.max(1, D.slots), sw = Math.min(W * 0.14, (W - 24) / n), sx0 = (W - sw * n) / 2, sy = H * 0.24, sh = H * 0.3;
      for (let i = 0; i < n; i++) {
        const x = sx0 + i * sw, v = slots[i];
        rect(x + 2, sy, sw - 4, sh, "rgba(19,16,32,0.6)");
        ctx.strokeStyle = v && v.flash > 0 ? "rgba(245,138,138," + v.flash + ")" : "rgba(201,196,228,0.3)"; ctx.lineWidth = v && v.flash > 0 ? 2 : 1; ctx.strokeRect(x + 2, sy, sw - 4, sh);
        label("" + (i + 1), x + sw / 2, sy + sh + 11, DIM, "center");
        if (!v) continue;
        const lv = level(v, t) / 1;
        rect(x + 5, sy + sh - 3 - (sh - 16) * lv, sw - 10, (sh - 16) * lv, colours[v.name]);
        label(v.name, x + sw / 2, sy + 11, colours[v.name], "center");
        if (v.flash > 0) text("stolen", x + sw / 2, sy - 4, 9, HOT, "center", true);
      }
      // the counts per sound against the cap
      let cc = 0, hc = 0;
      for (let i = 0; i < n; i++) if (slots[i]) { if (slots[i].name === "coin") cc++; else hc++; }
      text("coin " + cc + "/" + D.cap, W * 0.3, 16, 11, SUN, "center", true);
      text("hit " + hc + "/" + D.cap, W * 0.7, 16, 11, WATER, "center", true);
      label("pool " + (cc + hc) + "/" + D.slots + " · steal " + D.steal, W / 2, 30, DIM, "center");
      // the request stream: a tick per request over the last 3 s, red for steals, hollow for refusals
      const ly = H * 0.72, lx0 = 12, lw = W - 24;
      line(lx0, ly, lx0 + lw, ly, "rgba(201,196,228,0.3)", 1);
      for (let i = 0; i < log.length; i++) {
        const e = log[i], age = t - e.t; if (age > 3) continue;
        const x = lx0 + lw * (1 - age / 3);
        if (e.kind === "refused") ring(x, ly, 3, HOT, 1); else dot(x, ly, e.kind === "stole" ? 3 : 2, e.kind === "stole" ? HOT : colours[e.name]);
      }
      label("requests " + requests + " · steals " + steals + " · refused " + refused + (burstLeft ? " · burst: " + burstLeft + " to go" : ""), lx0, ly + 14, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Quota", "Quietquota", "a cap of two in a pool of four, and the newest request is the one refused — the strict mixer that never cuts a playing sound", { cap: 2, steal: "newest", slots: 4 });

def("A", "Analyser", "audio", "spectrum() feeds bar heights, a glow and a camera pulse — the music drives the picture; without audio a fake beat drives it — press to play/stop", function (u) {
  var D = { bpm: 112,
            bars: 16,           // bars drawn (32 bins, two per bar)
            shape: "bars",      // "bars" | "ring" — a waveform ring around the hero
            attack: 30,         // how fast a bar rises, per second
            release: 6,         // ...and falls
            pulse: 0.05,        // camera scale per unit of bass
            glowR: 0.45,        // the glow radius, of H, at full bass
            label: "h_i ← max(bin_i, h_i · e^(−release·dt)) · scale = 1 + bass · pulse"
  };
  const { ctx, W, H, GY, TAU, stage, hero, ground, rect, line, dot, glow, label, text, clamp, noise, spectrum, tone, noiseBurst, SUN, HOT, MAGIC, WATER, BONE, DIM, INK } = u;
  // an ANALYSER node sits at the end of the graph and hands back the output's
  // SPECTRUM as bins; anything can read them — bar heights, a glow's radius,
  // a camera zoom on the bass. the visual half needs ENVELOPE FOLLOWING: a
  // bar jumps up to a loud bin and falls slowly, or it flickers. here the
  // low bins become "bass" and scale the whole scene (chapter 11's music
  // visualiser, made a camera). with no audio the same pattern is faked
  // from the beat clock, so the picture never depends on the speakers.
  let armed = false, playing = true, beatT = 0, beat = 0, kick = 0, hat = 0, bass = 0, hue = 0;
  const h = [], fake = new Uint8Array(32);
  for (let i = 0; i < 32; i++) h.push(0);
  function period() { return 60 / D.bpm; }
  return {
    press() { armed = true; playing = !playing; },
    frame(dt, t) {
      beatT += dt;
      if (beatT > period() * 4) beatT = period();
      let guard = 0;
      while (beatT >= period() / 2 && guard++ < 4) {        // an eighth-note clock: kicks on the beat, hats off it
        beatT -= period() / 2; beat = (beat + 1) % 8;
        if (!playing) continue;
        if (beat % 2 === 0) { kick = 1; if (armed) tone({ freq: 150, slideTo: 45, type: "sine", dur: 0.18, vol: 0.22 }); if (armed && beat % 4 === 0) tone({ freq: beat === 0 ? 82 : 98, type: "square", dur: 0.3, vol: 0.1 }); }
        else { hat = 1; if (armed) noiseBurst({ dur: 0.04, vol: 0.06, highpass: 6000 }); }
      }
      kick = Math.max(0, kick - dt * 6); hat = Math.max(0, hat - dt * 14);
      const real = spectrum(); let live = false;
      for (let i = 0; i < 32; i++) if (real[i] > 4) { live = true; break; }
      for (let i = 0; i < 32; i++) {                       // the fake beat: a kick low, a bass hump, hats high
        const v = playing ? 255 * clamp(kick * Math.exp(-i / 2.2) + kick * 0.7 * Math.exp(-(i - 3) * (i - 3) / 3) + hat * 0.6 * Math.exp(-(i - 22) * (i - 22) / 24) + 0.04 + 0.03 * noise(i * 0.8 + t * 5), 0, 1) : 255 * (0.03 + 0.02 * noise(i * 0.8 + t * 2));
        fake[i] = v;
      }
      const bins = live ? real : fake;
      bass = 0;
      for (let i = 0; i < 32; i++) {
        const target = bins[i] / 255;
        h[i] = target > h[i] ? h[i] + (target - h[i]) * clamp(D.attack * dt, 0, 1) : h[i] * Math.exp(-D.release * dt);
        if (i < 4) bass += h[i] / 4;
      }
      hue += dt * 20;
      // the scene, scaled about its centre by the bass: the camera pulse
      ctx.save();
      ctx.translate(W / 2, H / 2); ctx.scale(1 + bass * D.pulse, 1 + bass * D.pulse); ctx.translate(-W / 2, -H / 2);
      stage({ plain: true });
      const hx = W / 2, hy = GY;
      ctx.globalCompositeOperation = "lighter";
      glow(hx, hy - H * 0.14, H * (0.1 + D.glowR * bass), MAGIC, 0.5);
      ctx.globalCompositeOperation = "source-over";
      if (D.shape === "ring") {                             // a smooth waveform ring: the bins mirrored round a circle
        const r0 = H * 0.2, amp = H * 0.16, n = D.bars;
        ctx.strokeStyle = SUN; ctx.lineWidth = 2; ctx.beginPath();
        for (let k = 0; k <= n * 2; k++) {
          const i = k < n ? k : n * 2 - k, a = -Math.PI / 2 + TAU * k / (n * 2);
          const idx = Math.min(31, i * 2), v = (h[idx] + h[Math.min(31, idx + 1)]) / 2;
          const r = r0 + amp * v, x = hx + Math.cos(a) * r, y = hy - H * 0.14 + Math.sin(a) * r;
          if (k === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.closePath(); ctx.stroke();
        ctx.strokeStyle = "rgba(245,193,105,0.25)"; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(hx, hy - H * 0.14, r0, 0, TAU); ctx.stroke();
      } else {
        const bw = (W - 20) / D.bars, base = H * 0.86, maxH = H * 0.5;
        for (let i = 0; i < D.bars; i++) {
          const idx = Math.min(31, Math.floor(i * 32 / D.bars)), v = (h[idx] + h[Math.min(31, idx + 1)]) / 2;
          const x = 10 + i * bw, hh = Math.max(1, maxH * v);
          rect(x + 1, base - hh, bw - 2, hh, i < 4 ? HOT : (i < 10 ? SUN : WATER));
          rect(x + 1, base - hh - 2, bw - 2, 1.5, INK);    // the peak cap
        }
        line(10, base, W - 10, base, "rgba(201,196,228,0.4)", 1);
      }
      hero(hx, hy, { pose: "run", frame: t * (playing ? 1 : 0.2), face: 1 });
      ctx.restore();
      // the readouts
      text(playing ? "playing · " + D.bpm + " bpm" : "stopped", 8, 14, 10, playing ? SUN : HOT, "left", true);
      label(live ? "live spectrum" : "fake beat (no audio yet)", W - 8, 14, live ? MAGIC : DIM, "right");
      const mx = 8, my = 22, mw = W * 0.3;
      rect(mx, my, mw, 6, "rgba(201,196,228,0.15)"); rect(mx, my, mw * clamp(bass, 0, 1), 6, HOT);
      label("bass " + bass.toFixed(2) + " → scale ×" + (1 + bass * D.pulse).toFixed(3), mx, my + 16, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Analyser", "Ambientwaves", "a smooth waveform ring around the hero instead of bars — slow release, a gentle pulse", { shape: "ring", release: 2.5, pulse: 0.02 });

def("R", "Rumble", "audio", "gamepad rumble and phone vibration as two motors, low and high, with intensity envelopes over time, fired by landings and hits — press for a pattern", function (u) {
  var D = { patterns: { land: [[0, 0, 0.12, 1.0], [1, 0, 0.05, 0.4]],
                        hit: [[1, 0, 0.06, 1.0], [0, 0.03, 0.2, 0.7], [1, 0.16, 0.05, 0.5]],
                        heartbeat: [[0, 0, 0.1, 0.8], [0, 0.25, 0.1, 0.5]],
                        pickup: [[1, 0, 0.04, 0.6], [1, 0.08, 0.04, 0.9]] },   // pulse = [motor 0 low / 1 high, at, dur, strength]
            order: ["heartbeat", "pickup", "land", "hit"],   // what a press cycles through
            motorFilter: "both",  // "both" | "low" | "high": which motors a pattern may use
            stretch: 1,           // × every pulse's time
            shake: 2.5,           // camera shake, px per unit of intensity
            jumpEvery: 2.1, hitEvery: 3.3,
            lowHz: 55, highHz: 170, vol: 0.14,
            label: "motor_m(t) = max over pulses of a · [at ≤ t < at + dur] · navigator.vibrate([on, off, …])"
  };
  const { ctx, W, H, GY, TAU, stage, hero, ground, rect, line, dot, ring, label, text, clamp, rand, tone, SUN, HOT, WATER, MAGIC, BONE, DIM, INK } = u;
  // a gamepad has two MOTORS — a heavy low-frequency one for weight and a
  // light high-frequency one for texture — and a haptic PATTERN is a list
  // of pulses: (motor, start, duration, strength). a phone has one motor and
  // takes the same list flattened into vibrate([on, off, on, …]) ms. the
  // envelope is the picture: at any instant each motor runs at the strongest
  // pulse covering it. chapter 06's screen shake is the third motor here,
  // scaled by the same envelope. the tones after the first press are the
  // motors hummed at their two pitches.
  let armed = false, hx = W * 0.3, vy = 0, hy = GY, jumpT = 0, hitT = 1.5, hurt = 0, next = 0, lastName = "", lastVib = "", want = "";
  const events = [];
  const G = H * 2.4;
  function allowed(m) { return D.motorFilter === "both" || (D.motorFilter === "low" ? m === 0 : m === 1); }
  function trigger(name, t) {
    const p = D.patterns[name]; if (!p) return;
    lastName = name;
    const ons = [];
    for (let i = 0; i < p.length; i++) {
      const m = p[i][0]; if (!allowed(m)) continue;
      const at = p[i][1] * D.stretch, dur = Math.max(0.02, p[i][2] * D.stretch), a = p[i][3];
      events.push({ m: m, at: t + at, dur: dur, a: a });
      ons.push([at, dur]);
      if (armed) tone({ freq: m ? D.highHz : D.lowHz, type: m ? "triangle" : "sine", dur: Math.max(0.06, dur), vol: clamp(D.vol * a, 0, 0.25), attack: 0.01, at: at });
    }
    ons.sort(function (a, b) { return a[0] - b[0]; });        // the phone's flat list: on, off, on...
    const vib = [];
    for (let i = 0; i < ons.length; i++) { vib.push(Math.round(ons[i][1] * 1000)); if (i + 1 < ons.length) vib.push(Math.max(0, Math.round((ons[i + 1][0] - ons[i][0] - ons[i][1]) * 1000))); }
    lastVib = "vibrate([" + vib.join(", ") + "])";
    if (events.length > 40) events.splice(0, events.length - 40);
  }
  function motor(m, tt) { let a = 0; for (let i = 0; i < events.length; i++) { const e = events[i]; if (e.m === m && tt >= e.at && tt < e.at + e.dur) a = Math.max(a, e.a); } return a; }
  return {
    press() { armed = true; want = D.order[next % D.order.length]; next++; },
    frame(dt, t) {
      if (want) { trigger(want, t); want = ""; }
      // the hero: runs on the spot, jumps on a timer and lands, takes a hit on another
      jumpT += dt; hitT += dt;
      if (jumpT >= D.jumpEvery && hy >= GY) { jumpT = 0; vy = -Math.sqrt(2 * G * H * 0.22); }
      vy += G * dt; hy += vy * dt;
      let landed = false;
      if (hy >= GY) { if (vy > H * 0.5) landed = true; hy = GY; vy = 0; }
      if (landed) trigger("land", t);
      if (hitT >= D.hitEvery) { hitT = 0; trigger("hit", t); hurt = 0.35; }
      hurt = Math.max(0, hurt - dt);
      const lo = motor(0, t), hi = motor(1, t), inten = Math.max(lo, hi);
      ctx.save();
      ctx.translate(rand(-1, 1) * inten * D.shake, rand(-1, 1) * inten * D.shake);
      stage({ night: 0.25 });
      if (hitT < 0.3) { const px = W * 0.9 - (hitT / 0.3) * (W * 0.6 - 10); if (px > hx + 8) dot(px, GY - H * 0.16, 3, HOT); }
      hero(hx, hy, { pose: hurt > 0 ? "hurt" : (hy < GY ? "jump" : "run"), frame: t, face: 1 });
      ctx.restore();
      // the two motors on a pad, sized and jittered by their intensity
      const px = W * 0.7, py = H * 0.2, pw = W * 0.24, ph = H * 0.16;
      ctx.fillStyle = "rgba(19,16,32,0.7)"; ctx.beginPath(); ctx.roundRect ? ctx.roundRect(px, py, pw, ph, 8) : ctx.rect(px, py, pw, ph); ctx.fill();
      ctx.strokeStyle = BONE; ctx.lineWidth = 1; ctx.stroke();
      const mA = [lo, hi];
      for (let m = 0; m < 2; m++) {
        const cx = px + pw * (0.25 + 0.5 * m) + rand(-1, 1) * mA[m] * 2, cy = py + ph * 0.55 + rand(-1, 1) * mA[m] * 2;
        dot(cx, cy, ph * 0.18 + mA[m] * ph * 0.14, m ? "rgba(79,163,216," + (0.25 + 0.75 * mA[m]) + ")" : "rgba(245,138,138," + (0.25 + 0.75 * mA[m]) + ")");
        ring(cx, cy, ph * 0.22, m ? WATER : HOT, 1);
        label(m ? "high" : "low", cx, py + ph + 10, m ? WATER : HOT, "center");
      }
      // the envelopes over time: history left of now, booked pulses to the right
      const ex = 8, ey = 8, ew = W * 0.56, eh = H * 0.34, span = 2, nowX = ex + ew * 0.7;
      rect(ex, ey, ew, eh, "rgba(19,16,32,0.6)"); ctx.strokeStyle = "rgba(201,196,228,0.3)"; ctx.lineWidth = 1; ctx.strokeRect(ex, ey, ew, eh);
      for (let m = 0; m < 2; m++) {
        const ry = ey + 4 + m * (eh / 2), rh = eh / 2 - 8;
        label(m ? "high motor" : "low motor", ex + 4, ry + 8, m ? WATER : HOT);
        ctx.fillStyle = m ? "rgba(79,163,216,0.6)" : "rgba(245,138,138,0.6)";
        for (let i = 0; i < events.length; i++) {
          const e = events[i]; if (e.m !== m) continue;
          const x0 = nowX - (t - e.at) / span * ew * 0.7, x1 = nowX - (t - e.at - e.dur) / span * ew * 0.7;
          const cx0 = clamp(x0, ex, ex + ew), cx1 = clamp(x1, ex, ex + ew);
          if (cx1 > cx0) ctx.fillRect(cx0, ry + rh - rh * e.a, cx1 - cx0, rh * e.a);
        }
        line(ex, ry + rh, ex + ew, ry + rh, "rgba(201,196,228,0.25)", 1);
      }
      line(nowX, ey, nowX, ey + eh, INK, 1); label("now", nowX + 3, ey + eh - 3, DIM);
      // the phone: the same pattern as a flat ms list
      const fx = W * 0.7, fy = H * 0.5, fw = W * 0.24, fh = H * 0.2;
      ctx.fillStyle = "rgba(19,16,32,0.7)"; ctx.beginPath(); ctx.roundRect ? ctx.roundRect(fx, fy, fw, fh, 5) : ctx.rect(fx, fy, fw, fh); ctx.fill();
      ctx.strokeStyle = inten > 0 ? SUN : BONE; ctx.lineWidth = 1; ctx.stroke();
      ctx.save(); ctx.translate(rand(-1, 1) * inten * 2, 0);
      label(lastName || "—", fx + fw / 2, fy + fh * 0.4, SUN, "center");
      ctx.restore();
      label(lastVib ? lastVib.slice(0, Math.floor(fw / 5)) : "vibrate([])", fx + fw / 2, fy + fh * 0.75, DIM, "center");
      label("motors: " + D.motorFilter + " · stretch ×" + D.stretch + " · shake " + inten.toFixed(2), 8, H - 22, DIM);
      label(D.label, W / 2, H - 8, null, "center");
    }
  };
});
rhymeOf("Rumble", "Rattle", "the high motor only and every pulse cut short — sharp little rattles instead of thuds, with a harder shake", { motorFilter: "high", stretch: 0.45, shake: 4 });
/* ============================== the page runner ============================== */

var grid = document.getElementById("almanac");
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

  var st = { effect: effect, canvas: canvas, u: null, inst: null, running: false, elapsed: 0, visible: true, useRhyme: false, pressed: false, down: false, armed: !effect.warn };
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
    if (!st.armed) {                                   // an opt-in card: the first click only arms it
      st.armed = true;
      st.pressed = true;
      startCard(st);
      return;
    }
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
  u.stage({ plain: true });
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

/* the opt-in notice: static (nothing here may flash) and honest */
function warning(u, text) {
  var c = u.ctx;
  u.stage({ plain: true });
  c.strokeStyle = "#F5C169"; c.lineWidth = 2;
  c.strokeRect(10, 10, u.W - 20, u.H - 20);
  c.fillStyle = "#F5C169";
  c.font = "700 15px system-ui, sans-serif";
  c.textAlign = "center"; c.textBaseline = "middle";
  c.fillText("⚠ " + text, u.W / 2, u.H * 0.4);
  c.fillStyle = "rgba(232,229,244,0.85)";
  c.font = "12px system-ui, sans-serif";
  c.fillText("this card does not start on its own", u.W / 2, u.H * 0.58);
  c.fillText("click to show it (you can look away first)", u.W / 2, u.H * 0.7);
  c.textAlign = "left"; c.textBaseline = "alphabetic";
}

function startCard(st) {
  var u = apiFor(st.canvas);
  st.u = u;
  if (!st.armed) {                                     // opt-in cards wait for a click
    st.running = false;
    st.inst = null;
    warning(u, st.effect.warn);
    updateStatus();
    return;
  }
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
    statusEl.textContent = n === 0 ? "" : n + " of " + cards.length + " effects awake";
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
  small.textContent = list.length + " effects (+" + list.filter(function (e) { return e.rhyme; }).length + " rhymes) — " + fam[2];
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
  u.stage({ plain: true });
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
  edname.textContent = (current.useRhyme
    ? effect.letter + " · " + v.name + " — a rhyme of " + effect.name + " — " + v.hint
    : effect.letter + " · " + v.name + " — " + v.hint) + (effect.warn ? "  ⚠ " + effect.warn + " — Run starts it" : "");
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
window.__almanac = { EFFECTS: EFFECTS, apiFor: apiFor, cards: cards, makeOf: makeOf, sourceOf: sourceOf };
})();
