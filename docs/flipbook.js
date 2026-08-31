/* Sparks & Sprites — the flipbook folio.
   104 VFX baked into transparent sprite sheets, A to Z four times — the fifth gallery
   after the elemental button bestiary, the cube codex, the glyph grimoire,
   and the locomotion lexicon. Everything before this page drew its effects
   LIVE, every frame. This page teaches the other half of real-world VFX:
   draw the animation ONCE into a strip of transparent frames (a sprite
   sheet — "flipbook" if you learned the word from Unreal), then play it
   back by doing nothing cleverer than picking which rectangle to copy.

   Every card bakes its own sheet from code when it wakes (so there are no
   image files to download), then never draws the effect again — playback
   is one drawImage per frame. The filmstrip under each card IS the actual
   baked texture, checkerboarded so you can see the transparency; the
   bright cell is the frame being shown right now.

   Every demo is one function make(u) that returns { frame(dt, t), press(x, y) }.
   The kit u:
     ctx, W, H     — the 2D context and canvas size (CSS pixels)
     GY            — the standard ground line's y (H · 0.72)
     FIRE          — ember orange   #F5A15A   (heat, impacts)
     SPARK         — mote blue      #8AD9F5   (light, water, the hero)
     MAGIC         — arcane violet  #C9A0F5   (runes, portals, heals get GOOD)
     TARGET        — attention amber #F5C169  (highlights, the strip cursor)
     GOOD, HOT     — helpers green, danger red
     INK, DIM      — plain light, and its faded cousin
     rng(seed)     — a seeded random generator (mulberry32): the SAME seed
                     gives the SAME "random" numbers, which is how a baked
                     sheet stays coherent frame to frame
     bake(n, size, draw) — the heart of the page: makes an n·size × size
                     transparent canvas, calls draw(f) once per frame with
                     the pen clipped to that frame's cell, returns the sheet.
                     The frame kit f: g (the sheet's 2D context), S (cell
                     size), c (S/2, the cell centre), i, n,
                     k  = i/(n−1) — 0..1 INCLUSIVE, for one-shots,
                     kl = i/n     — wraps cleanly,  for seamless loops,
                     and cell-local drawing helpers: dot, glow (radial
                     gradient), ring, streak (a line with round caps),
                     wedge, star(x,y,r1,r2,points,c,rot), poly
     blit(sheet, i, x, y, scale, mode) — plays frame i at x,y. mode "add"
                     composites with globalCompositeOperation "lighter"
                     (light adds up); default is normal source-over
                     (soot, paper, and smoke stay dark)
     strip(sheet, i) — draws the sheet as a filmstrip along the card's
                     bottom edge over a checkerboard, highlighting frame i
     scene()       — clears the canvas: night backdrop + ground line
     mote(x, y, s?) — the round blue hero, back from the lexicon, here to
                     stand still and receive effects with dignity
     dot, ring, label, clamp, ease, rand, TAU — the usual pocket tools

   Nothing animates until the visitor presses Run (or clicks a card awake),
   and every card rests after 60 seconds as a courtesy. */
(function () {
"use strict";
var TAU = Math.PI * 2;

var EFFECTS = [];
function def(letter, name, tag, hint, make) {
  EFFECTS.push({ letter: letter, name: name, tag: tag, hint: hint, make: make });
}

function apiFor(canvas) {
  var dpr = window.devicePixelRatio || 1;
  var W = canvas.clientWidth, H = canvas.clientHeight;
  canvas.width = Math.round(W * dpr);
  canvas.height = Math.round(H * dpr);
  var ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  var GY = H * 0.72;
  var INK = "#E8E5F4";
  var DIM = "rgba(232,229,244,0.25)";
  var FIRE = "#F5A15A";
  var SPARK = "#8AD9F5";
  var MAGIC = "#C9A0F5";
  var TARGET = "#F5C169";
  var GOOD = "#9BE28A";
  var HOT = "#F58A8A";
  function rand(a, b) { return a + Math.random() * (b - a); }
  function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
  function ease(k) { k = clamp(k, 0, 1); return k * k * (3 - 2 * k); }
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

  /* ---- the baker: draw n frames ONCE into one transparent canvas ---- */
  function bake(n, size, draw) {
    var cv = document.createElement("canvas");
    var q = 2;                                         // bake at 2× so scaled
    cv.width = n * size * q;                           // playback stays crisp
    cv.height = size * q;
    var g = cv.getContext("2d");
    g.setTransform(q, 0, 0, q, 0, 0);
    for (var i = 0; i < n; i++) {
      g.save();
      g.translate(i * size, 0);
      g.beginPath();
      g.rect(0, 0, size, size);
      g.clip();                                        // one frame cannot smear
      var f = frameKit(g, size, i, n);                 // into its neighbour
      draw(f);
      g.restore();
      g.globalCompositeOperation = "source-over";
      g.globalAlpha = 1;
    }
    return { cv: cv, n: n, size: size, q: q };
  }

  function frameKit(g, S, i, n) {
    var f = {
      g: g, S: S, c: S / 2, i: i, n: n,
      k: n > 1 ? i / (n - 1) : 0,                      // 0..1 inclusive — one-shots
      kl: i / n                                        // wraps at 1 — seamless loops
    };
    f.dot = function (x, y, r, c) {
      g.fillStyle = c;
      g.beginPath(); g.arc(x, y, Math.max(0.1, r), 0, TAU); g.fill();
    };
    f.glow = function (x, y, r, c, a) {                // c is "rgba(r,g,b," — open!
      r = Math.max(0.5, r);
      var gr = g.createRadialGradient(x, y, 0, x, y, r);
      gr.addColorStop(0, c + (a === undefined ? 0.9 : a) + ")");
      gr.addColorStop(1, c + "0)");
      g.fillStyle = gr;
      g.beginPath(); g.arc(x, y, r, 0, TAU); g.fill();
    };
    f.ring = function (x, y, r, c, w) {
      g.strokeStyle = c;
      g.lineWidth = w || 1.5;
      g.beginPath(); g.arc(x, y, Math.max(0.5, r), 0, TAU); g.stroke();
    };
    f.streak = function (x1, y1, x2, y2, c, w) {
      g.strokeStyle = c;
      g.lineWidth = w || 2;
      g.lineCap = "round";
      g.beginPath(); g.moveTo(x1, y1); g.lineTo(x2, y2); g.stroke();
      g.lineCap = "butt";
    };
    f.wedge = function (x, y, ang, len, spread, c) {
      g.fillStyle = c;
      g.beginPath();
      g.moveTo(x, y);
      g.lineTo(x + Math.cos(ang - spread) * len, y + Math.sin(ang - spread) * len);
      g.lineTo(x + Math.cos(ang + spread) * len, y + Math.sin(ang + spread) * len);
      g.closePath(); g.fill();
    };
    f.star = function (x, y, r1, r2, points, c, rot) {
      g.fillStyle = c;
      g.beginPath();
      for (var j = 0; j < points * 2; j++) {
        var r = j % 2 === 0 ? r1 : r2;
        var a = (rot || 0) + (j / (points * 2)) * TAU - TAU / 4;
        var px = x + Math.cos(a) * r, py = y + Math.sin(a) * r;
        if (j === 0) g.moveTo(px, py); else g.lineTo(px, py);
      }
      g.closePath(); g.fill();
    };
    f.poly = function (pts, c) {
      g.fillStyle = c;
      g.beginPath();
      for (var j = 0; j < pts.length; j++) {
        if (j === 0) g.moveTo(pts[j][0], pts[j][1]); else g.lineTo(pts[j][0], pts[j][1]);
      }
      g.closePath(); g.fill();
    };
    return f;
  }

  /* ---- playback: copy one rectangle. that's the whole trick ---- */
  function blit(sheet, i, x, y, scale, mode) {
    var d = sheet.size * (scale || 1);
    ctx.save();
    if (mode === "add") ctx.globalCompositeOperation = "lighter";
    ctx.drawImage(sheet.cv,
      i * sheet.size * sheet.q, 0, sheet.size * sheet.q, sheet.size * sheet.q,
      x - d / 2, y - d / 2, d, d);
    ctx.restore();
  }

  function strip(sheet, cur) {
    var x0 = 8, h = 20, y0 = H - h - 6, w = W - 16;
    var cw = w / sheet.n;
    for (var i = 0; i < sheet.n; i++) {                // checker says "transparent"
      var cx = x0 + i * cw;
      ctx.fillStyle = "#232033";
      ctx.fillRect(cx, y0, cw, h);
      ctx.fillStyle = "#2C293D";
      for (var yy = 0; yy < h; yy += 5)
        for (var xx = (yy / 5) % 2 * 5; xx < cw - 1; xx += 10)
          ctx.fillRect(cx + xx, y0 + yy, Math.min(5, cw - xx), Math.min(5, h - yy));
      ctx.drawImage(sheet.cv,
        i * sheet.size * sheet.q, 0, sheet.size * sheet.q, sheet.size * sheet.q,
        cx, y0, cw, h);
      ctx.strokeStyle = "rgba(150,145,190,0.25)";
      ctx.lineWidth = 1;
      ctx.strokeRect(cx + 0.5, y0 + 0.5, cw - 1, h - 1);
    }
    ctx.strokeStyle = TARGET;                          // the read head
    ctx.lineWidth = 1.5;
    ctx.strokeRect(x0 + cur * cw + 0.75, y0 + 0.75, cw - 1.5, h - 1.5);
  }

  function scene() {
    var g = ctx.createLinearGradient(0, 0, 0, H);      // the night backdrop
    g.addColorStop(0, "#1A1532");
    g.addColorStop(1, "#131020");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    ctx.strokeStyle = "rgba(201,196,228,0.4)";
    ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(0, GY); ctx.lineTo(W, GY); ctx.stroke();
    ctx.strokeStyle = "rgba(201,196,228,0.14)";        // the hatching that says "solid"
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (var x = 4; x < W; x += 12) { ctx.moveTo(x, GY + 2); ctx.lineTo(x - 5, GY + 7); }
    ctx.stroke();
  }
  function mote(x, y, s) {
    s = s || 9;
    ctx.fillStyle = SPARK;
    ctx.beginPath(); ctx.arc(x, y, s, 0, TAU); ctx.fill();
    ctx.fillStyle = "#131020";                         // one attentive eye
    ctx.beginPath(); ctx.arc(x + s * 0.35, y - s * 0.3, s * 0.22, 0, TAU); ctx.fill();
  }
  function dot(x, y, r, c) {
    ctx.fillStyle = c || INK;
    ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
  }
  function ring(x, y, r, c, w) {
    ctx.strokeStyle = c || DIM;
    ctx.lineWidth = w || 1;
    ctx.beginPath(); ctx.arc(x, y, Math.max(0.5, r), 0, TAU); ctx.stroke();
  }
  function label(txt, x, y, c, align) {
    ctx.fillStyle = c || "rgba(232,229,244,0.55)";
    ctx.font = "10px system-ui, sans-serif";
    ctx.textAlign = align || "left";
    ctx.fillText(txt, x, y);
    ctx.textAlign = "left";
  }
  return { ctx: ctx, W: W, H: H, GY: GY, TAU: TAU,
           INK: INK, DIM: DIM, FIRE: FIRE, SPARK: SPARK, MAGIC: MAGIC,
           TARGET: TARGET, GOOD: GOOD, HOT: HOT,
           rand: rand, clamp: clamp, ease: ease, rng: rng,
           bake: bake, blit: blit, strip: strip,
           scene: scene, mote: mote, dot: dot, ring: ring, label: label };
}

/* ============================== GLOW & FLAME ==============================
   Looping light that lives ON a body: auras, embers, engine fire, glints,
   orbiting motes. Two habits define the family. First, every phase is
   computed from kl = i/N (not i/(N−1)), so frame N would land exactly on
   frame 0 — the loop point is invisible. Second, playback uses "add"
   (globalCompositeOperation "lighter"): these frames are LIGHT, and light
   adds up where it overlaps. Chapter 3's additive lesson, now pre-baked. */

def("A", "Aura", "glow", "a breathing halo in 12 frames — phase = i/N, so the loop point is invisible", function make(u) {
  var N = 12, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    var br = 0.5 - 0.5 * Math.cos(f.kl * u.TAU);       // one full breath per lap
    f.glow(f.c, f.c, 24 + br * 9, "rgba(138,217,245,", 0.5 + br * 0.3);
    f.ring(f.c, f.c, 28 + br * 7, "rgba(138,217,245," + (0.5 + br * 0.4) + ")", 2);
    f.ring(f.c, f.c, 20 + br * 4, "rgba(232,229,244," + (0.25 + br * 0.2) + ")", 1);
  });
  var px = u.W * 0.5, py = u.GY - 22;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("loop: i = ⌊t·fps⌋ mod N — bake once, copy forever", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("E", "Embers", "glow", "ten motes rise on offset clocks — (i/N + offset) mod 1 keeps every path seamless", function make(u) {
  var N = 16, S = 96, FPS = 12;
  var R = u.rng(7);                                    // same seed → same embers,
  var emb = [];                                        // every bake, every machine
  for (var j = 0; j < 10; j++)
    emb.push({ x: 18 + R() * 60, off: R(), sway: 4 + R() * 7, r: 1.2 + R() * 2 });
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < emb.length; j++) {
      var e = emb[j];
      var p = (f.kl + e.off) % 1;                      // each ember on its own lap
      var y = f.S - 12 - p * (f.S - 22);
      var x = e.x + Math.sin(p * u.TAU * 2 + e.off * 9) * e.sway;
      var a = p < 0.15 ? p / 0.15 : 1 - (p - 0.15) / 0.85;
      f.glow(x, y, e.r * 3.2, "rgba(245,161,90,", a * 0.8);
      f.dot(x, y, e.r, "rgba(245,193,105," + a + ")");
    }
  });
  var px = u.W * 0.5, py = u.GY - 44;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5, "add");
      u.strip(sheet, i);
      u.label("seeded rng: same numbers every bake — that's what a seed is for", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 24; }
  };
});

def("F", "Flame", "glow", "three stacked glows wobbling on offset sines — fire in a 12-frame loop", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var b = f.S - 20;
    var layers = [[0, 16, "rgba(245,138,90,", 0.55], [0.9, 11, "rgba(245,161,90,", 0.75], [1.7, 7, "rgba(245,220,150,", 0.95]];
    for (var j = 0; j < layers.length; j++) {
      var L = layers[j];
      for (var s = 0; s < 3; s++) {                    // three blobs per layer,
        var h = s / 3;                                 // stacked and shrinking
        var wob = Math.sin(f.kl * u.TAU * 2 + L[0] + h * 5) * (2 + h * 6);
        f.glow(f.c + wob, b - h * 34, L[1] * (1 - h * 0.55), L[2], L[3] * (1 - h * 0.3));
      }
    }
    var tip = Math.sin(f.kl * u.TAU * 3) * 4;          // the flick at the top
    f.glow(f.c + tip, b - 40, 4, "rgba(245,220,150,", 0.7);
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py - 4, 1.5, "add");
      u.strip(sheet, i);
      u.label("chapter 6's live flame, frozen into 12 copies of itself", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 16; }
  };
});

def("G", "Glint", "glow", "a shine travels a fixed diagonal — the whole animation is one moving highlight", function make(u) {
  var N = 14, S = 96, FPS = 16;
  var sheet = u.bake(N, S, function (f) {
    var p = f.kl;                                      // the glint's trip, 0..1
    var x = 14 + p * (f.S - 28), y = f.S - 20 - p * (f.S - 40);
    var a = Math.sin(p * Math.PI);                     // bright mid-trip
    f.streak(x - 7, y + 7, x + 7, y - 7, "rgba(232,229,244," + a * 0.85 + ")", 3);
    f.streak(x - 3, y - 3, x + 3, y + 3, "rgba(232,229,244," + a * 0.6 + ")", 2);
    f.star(x, y, 8 * a, 2.4 * a, 4, "rgba(245,241,220," + a + ")", p * 1.2);
    f.glow(x, y, 10 * a, "rgba(232,229,244,", a * 0.5);
  });
  var px = u.W * 0.5, py = u.GY - 22;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12, 11);
      u.blit(sheet, i, px, py, 1.3, "add");
      u.strip(sheet, i);
      u.label("what chrome's travelling shine becomes when you bake it", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("O", "Orbit", "glow", "three motes at angle kl·2π + j·2π/3 — polar coordinates, pre-computed 16 times", function make(u) {
  var N = 16, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    f.ring(f.c, f.c, 27, "rgba(138,217,245,0.18)", 1); // the rail, barely there
    for (var j = 0; j < 3; j++) {
      var a = f.kl * u.TAU + j * u.TAU / 3;
      var x = f.c + Math.cos(a) * 27, y = f.c + Math.sin(a) * 27 * 0.55;
      for (var s = 1; s <= 3; s++) {                   // a short baked tail
        var ta = a - s * 0.22;
        f.dot(f.c + Math.cos(ta) * 27, f.c + Math.sin(ta) * 27 * 0.55,
          2.2 - s * 0.5, "rgba(138,217,245," + (0.5 - s * 0.13) + ")");
      }
      f.glow(x, y, 6, "rgba(138,217,245,", 0.8);
      f.dot(x, y, 2.6, "#E8E5F4");
    }
  });
  var px = u.W * 0.5, py = u.GY - 26;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("the ellipse squash (y × 0.55) is baked in — playback can't tilt it", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

/* ============================== HITS & SLASHES ==============================
   One-shots born at a point: play the strip once, then hold on nothing.
   The index line changes character: i = min(N−1, ⌊(t−t₀)·fps⌋) — clamp,
   don't wrap — and the LAST frame is baked empty (or nearly), so "holding
   on the final frame" and "the effect is over" are the same statement.
   Cards retrigger themselves politely; click to retrigger where you point. */

def("B", "Burst", "hit", "twelve streaks race outward and die — i clamps at N−1 instead of wrapping", function make(u) {
  var N = 10, S = 96, FPS = 20;
  var R = u.rng(11);
  var rays = [];
  for (var j = 0; j < 12; j++)
    rays.push({ a: (j / 12) * u.TAU + R() * 0.3, sp: 0.75 + R() * 0.5 });
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    if (k < 0.22) f.glow(f.c, f.c, 16 * (1 - k / 0.22), "rgba(245,241,220,", 0.95);
    for (var j = 0; j < rays.length; j++) {
      var r = rays[j];
      var d0 = Math.pow(k, 0.65) * 36 * r.sp;          // fast out, easing off
      var d1 = d0 + (1 - k) * 9 + 2;                   // streak shortens as it dies
      var a = 1 - k;
      f.streak(f.c + Math.cos(r.a) * d0, f.c + Math.sin(r.a) * d0,
        f.c + Math.cos(r.a) * d1, f.c + Math.sin(r.a) * d1,
        "rgba(245,161,90," + a + ")", 2.4 * (1 - k * 0.6));
    }
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.1) t0 = t;              // polite auto-replay
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("one-shot: i = min(N−1, ⌊(t−t₀)·fps⌋) — the last frame is baked empty", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y, t) { px = x; py = y; t0 = -9; }
  };
});

def("I", "Impact", "hit", "a thinning shock ring + a shrinking star — the standard hit, in 8 frames", function make(u) {
  var N = 8, S = 96, FPS = 24;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    f.ring(f.c, f.c, 6 + k * 34, "rgba(232,229,244," + (1 - k) + ")", 4 * (1 - k) + 0.5);
    f.star(f.c, f.c, 20 * (1 - k * 0.85), 6 * (1 - k * 0.85), 4,
      "rgba(245,241,220," + (1 - k * k) + ")", k * 0.5);
    for (var j = 0; j < 4; j++) {                      // four speedline ticks
      var a = j * u.TAU / 4 + 0.4;
      var d = 18 + k * 22;
      f.streak(f.c + Math.cos(a) * d, f.c + Math.sin(a) * d,
        f.c + Math.cos(a) * (d + 6), f.c + Math.sin(a) * (d + 6),
        "rgba(232,229,244," + (0.7 - k * 0.7) + ")", 1.5);
    }
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.0) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("8 frames at 24 fps = a 0.33 s hit — impacts like being brief", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("K", "Kapow", "hit", "a comic star pops past full size and settles — overshoot baked into the scale curve", function make(u) {
  var N = 10, S = 96, FPS = 18;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    if (k > 0.88) return;                              // baked-in disappearance
    var over = 1.7 * k * (2 - k) - 0.7 * k * k;        // rushes past 1, settles back
    var r = 30 * Math.max(0, over);
    var a = k < 0.7 ? 1 : 1 - (k - 0.7) / 0.18;
    f.star(f.c, f.c, r, r * 0.5, 9, "rgba(245,193,105," + a + ")", k * 0.35);
    f.star(f.c, f.c, r * 0.72, r * 0.36, 9, "rgba(245,138,138," + a + ")", k * 0.35);
    f.g.strokeStyle = "rgba(19,16,32," + a * 0.9 + ")";
    f.g.lineWidth = 2;
    f.g.stroke();                                      // the comic outline
  });
  var px = u.W * 0.5, py = u.GY - 40, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5);                   // source-over: paper, not light
      u.strip(sheet, i);
      u.label("played source-over — comic ink wants to stay opaque", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("N", "Nova", "hit", "flash shrinks while the ring expands — two curves crossing is the whole effect", function make(u) {
  var N = 10, S = 96, FPS = 20;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    f.glow(f.c, f.c, 20 * (1 - k), "rgba(245,241,220,", (1 - k) * 0.95);
    f.ring(f.c, f.c, 5 + u.ease(k) * 36, "rgba(245,193,105," + (1 - k) + ")", 3 * (1 - k) + 0.5);
    f.ring(f.c, f.c, 5 + u.ease(Math.max(0, k - 0.25)) * 32,
      "rgba(245,161,90," + (0.7 - k * 0.7) + ")", 1.5);
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.1) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.7, "add");
      u.strip(sheet, i);
      u.label("blit it at 3× and it's a boss death — sheets don't care about size", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("T", "Trailslash", "hit", "an arc sweeps from angle a to b — the ghost arcs behind it are baked motion blur", function make(u) {
  var N = 9, S = 96, FPS = 24;
  var A0 = -2.4, A1 = 0.5;                             // the swing, in radians
  var sheet = u.bake(N, S, function (f) {
    var k = u.ease(f.k);
    var a = A0 + (A1 - A0) * k;
    var fade = f.k < 0.75 ? 1 : 1 - (f.k - 0.75) / 0.25;
    for (var s = 0; s < 4; s++) {                      // ghosts of recent angles
      var ga = a - s * 0.28;
      if (ga < A0) continue;
      var al = fade * (0.8 - s * 0.2);
      f.g.strokeStyle = "rgba(232,229,244," + al + ")";
      f.g.lineWidth = 6 - s * 1.3;
      f.g.lineCap = "round";
      f.g.beginPath();
      f.g.arc(f.c, f.c, 30, ga - 0.5, ga + 0.08);
      f.g.stroke();
      f.g.lineCap = "butt";
    }
    var tx = f.c + Math.cos(a) * 30, ty = f.c + Math.sin(a) * 30;
    f.glow(tx, ty, 7, "rgba(245,241,220,", fade * 0.9);
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.1) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("motion blur is FREE in a flipbook — just draw where you recently were", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("X", "Xslash", "hit", "two diagonal cuts land 3 frames apart — a flipbook can stagger its own choreography", function make(u) {
  var N = 12, S = 96, FPS = 22;
  function cut(f, x1, y1, x2, y2, kk) {                // one slash, life 0..1
    if (kk <= 0 || kk >= 1) return;
    var grow = Math.min(1, kk / 0.35);                 // grows in fast…
    var fade = kk < 0.6 ? 1 : 1 - (kk - 0.6) / 0.4;    // …fades out slow
    var mx = x1 + (x2 - x1) * grow, my = y1 + (y2 - y1) * grow;
    f.streak(x1, y1, mx, my, "rgba(232,229,244," + fade + ")", 4 * fade + 0.5);
    f.streak(x1, y1, mx, my, "rgba(138,217,245," + fade * 0.5 + ")", 8 * fade + 1);
    if (grow >= 1) f.star(x2, y2, 6 * fade, 2 * fade, 4, "rgba(245,241,220," + fade + ")", 0.4);
  }
  var sheet = u.bake(N, S, function (f) {
    cut(f, 18, 20, f.S - 18, f.S - 20, f.k / 0.75);            // first: ↘
    cut(f, f.S - 18, 22, 18, f.S - 22, (f.k - 0.25) / 0.75);   // then:  ↙
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.1) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("two timelines, one strip — offset the k of each part", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

/* ============================== SMOKE, DUST & WATER ==============================
   The matter family — and the blend-mode counterexample. Soot, dust, and
   spray are not light: play them SOURCE-OVER, or your smoke will glow like
   a saint. Transparency does the real work here — half the pixels in these
   sheets are empty, which is exactly why the effect can sit over any scene. */

def("D", "Dustkick", "smoke", "six puffs shove outward from the feet — dust is a one-shot that hugs the ground", function make(u) {
  var N = 10, S = 96, FPS = 16;
  var R = u.rng(23);
  var puffs = [];
  for (var j = 0; j < 6; j++)
    puffs.push({ a: Math.PI + (j / 5) * Math.PI, sp: 0.6 + R() * 0.5, r: 4 + R() * 4 });
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    for (var j = 0; j < puffs.length; j++) {
      var p = puffs[j];
      var d = Math.pow(k, 0.6) * 26 * p.sp;
      var x = f.c + Math.cos(p.a) * d;
      var y = f.S - 16 - Math.abs(Math.sin(p.a)) * d * 0.45 - k * 4;
      var a = (1 - k) * 0.55;
      f.dot(x, y, p.r * (0.6 + k), "rgba(160,150,140," + a + ")");
      f.dot(x - 2, y - 2, p.r * (0.4 + k * 0.7), "rgba(200,190,180," + a * 0.6 + ")");
    }
  });
  var px = u.W * 0.5, py = u.GY - 30, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("source-over playback — dust is matter, not light", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = u.GY - 30; t0 = -9; }
  };
});

def("J", "Jet", "smoke", "a thruster cone: hot core loops additively-bright, exhaust puffs drift off below", function make(u) {
  var N = 12, S = 96, FPS = 16;
  var R = u.rng(31);
  var puffs = [];
  for (var j = 0; j < 7; j++)
    puffs.push({ off: R(), dx: (R() - 0.5) * 14, r: 3 + R() * 3 });
  var sheet = u.bake(N, S, function (f) {
    var top = 24;
    for (var s = 0; s < 3; s++) {                      // the hot core, wobbling
      var wob = Math.sin(f.kl * u.TAU * 2 + s * 2.1) * 2.5;
      f.glow(f.c + wob, top + 10 + s * 8, 9 - s * 2, "rgba(245,220,150,", 0.85 - s * 0.2);
      f.glow(f.c + wob, top + 12 + s * 9, 13 - s * 2, "rgba(245,161,90,", 0.4);
    }
    for (var j = 0; j < puffs.length; j++) {           // the exhaust, drifting
      var p = puffs[j];
      var q = (f.kl + p.off) % 1;
      var y = top + 26 + q * 40;
      var a = (1 - q) * 0.4;
      f.dot(f.c + p.dx * q, y, p.r * (0.7 + q), "rgba(170,165,180," + a + ")");
    }
  });
  var px = u.W * 0.5, py = u.GY - 52;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, py - 24);
      u.blit(sheet, i, px, py, 1.5, "add");
      u.strip(sheet, i);
      u.label("one sheet CAN mix light and matter — this one leans additive", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y + 10; }
  };
});

def("P", "Poof", "smoke", "five blobs swell, rise, thin to nothing — the vanish cloud every 2D game owns", function make(u) {
  var N = 10, S = 96, FPS = 15;
  var R = u.rng(41);
  var blobs = [];
  for (var j = 0; j < 5; j++)
    blobs.push({ dx: (R() - 0.5) * 20, dy: (R() - 0.5) * 12, r: 7 + R() * 6, off: R() * 0.2 });
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    for (var j = 0; j < blobs.length; j++) {
      var b = blobs[j];
      var kk = u.clamp((k - b.off) / (1 - b.off), 0, 1);
      var a = (1 - kk) * 0.6;
      if (a <= 0) continue;
      var r = b.r * (0.5 + kk * 1.1);
      f.dot(f.c + b.dx * (1 + kk * 0.5), f.c + b.dy - kk * 10, r, "rgba(185,180,195," + a + ")");
      f.dot(f.c + b.dx * (1 + kk * 0.5) - r * 0.3, f.c + b.dy - kk * 10 - r * 0.3,
        r * 0.55, "rgba(220,216,230," + a * 0.7 + ")");
    }
  });
  var vis = true, px = u.W * 0.5, py = u.GY - 26, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.4) { t0 = t; vis = !vis; }   // the mote blinks away…
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));  // …behind the poof
      u.scene();
      if (vis) u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("play a poof over any despawn and nobody asks where they went", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("R", "Ripple", "smoke", "three flat ellipses expand on offset phases — a water surface in 14 frames", function make(u) {
  var N = 14, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < 3; j++) {
      var p = (f.kl + j / 3) % 1;                      // each ring a third apart
      var r = 4 + p * 34;
      var a = (1 - p) * 0.7;
      f.g.strokeStyle = "rgba(138,217,245," + a + ")";
      f.g.lineWidth = 2 * (1 - p) + 0.5;
      f.g.beginPath();
      f.g.ellipse(f.c, f.c, r, r * 0.32, 0, 0, u.TAU); // the squash IS the surface
      f.g.stroke();
    }
  });
  var px = u.W * 0.5, py = u.GY - 2;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("waterdrops' ripple, baked — offset phases make one loop read as endless", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; }
  };
});

def("U", "Updraft", "smoke", "wind made visible: S-curved streaks rise on offset clocks and never repeat visibly", function make(u) {
  var N = 16, S = 96, FPS = 14;
  var R = u.rng(53);
  var gusts = [];
  for (var j = 0; j < 6; j++)
    gusts.push({ x: 16 + R() * 64, off: R(), amp: 3 + R() * 5 });
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < gusts.length; j++) {
      var w = gusts[j];
      var p = (f.kl + w.off) % 1;
      var y0 = f.S - 8 - p * (f.S - 16);
      var a = Math.sin(p * Math.PI) * 0.55;
      f.g.strokeStyle = "rgba(200,220,240," + a + ")";
      f.g.lineWidth = 1.5;
      f.g.beginPath();
      for (var s = 0; s <= 8; s++) {                   // a short S of streak
        var yy = y0 + s * 2.2;
        var xx = w.x + Math.sin((yy / f.S) * u.TAU * 1.5 + w.off * 7) * w.amp;
        if (s === 0) f.g.moveTo(xx, yy); else f.g.lineTo(xx, yy);
      }
      f.g.stroke();
    }
  });
  var px = u.W * 0.5, py = u.GY - 44;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5, "add");
      u.strip(sheet, i);
      u.label("16 frames hide a loop better than 8 — count the strip cells", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 20; }
  };
});

def("V", "Vortex", "smoke", "dots on a shrinking spiral — radius runs on (kl+offset) mod 1, so the drain never empties", function make(u) {
  var N = 16, S = 96, FPS = 15;
  var R = u.rng(61);
  var specks = [];
  for (var j = 0; j < 14; j++)
    specks.push({ off: R(), a0: R() * u.TAU, r: 1 + R() * 1.6 });
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < specks.length; j++) {
      var s = specks[j];
      var p = (f.kl + s.off) % 1;                      // p grows → falls inward
      var rad = 34 * (1 - p);
      var a = s.a0 + p * u.TAU * 1.6;                  // spinning faster as it falls
      var x = f.c + Math.cos(a) * rad, y = f.c + Math.sin(a) * rad * 0.75;
      var al = p < 0.1 ? p / 0.1 : (p > 0.9 ? (1 - p) / 0.1 : 1);
      f.dot(x, y, s.r * (1 - p * 0.5), "rgba(201,160,245," + al * 0.8 + ")");
    }
    f.glow(f.c, f.c, 7, "rgba(201,160,245,", 0.5);     // the hungry centre
  });
  var px = u.W * 0.5, py = u.GY - 34;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px + 34, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("every speck is born at the rim as its twin dies at the centre", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

/* ============================== MAGIC & SPARKLE ==============================
   The arcane shelf — and two special lessons. Lightning shows a flipbook
   FLICKERING: re-randomise per frame (seed + frame index) instead of
   animating smoothly, because chaos reads as energy. The magic circle
   shows two layers counter-rotating in one sheet. All additive: spells
   are made of light, whatever the lore department claims. */

def("H", "Heal", "magic", "green sparkles and little plusses rise off the patient — kind VFX, offset clocks again", function make(u) {
  var N = 14, S = 96, FPS = 13;
  var R = u.rng(71);
  var bits = [];
  for (var j = 0; j < 9; j++)
    bits.push({ x: 24 + R() * 48, off: R(), plus: j % 3 === 0, r: 1.5 + R() * 1.5 });
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < bits.length; j++) {
      var b = bits[j];
      var p = (f.kl + b.off) % 1;
      var y = f.S - 14 - p * (f.S - 26);
      var a = Math.sin(p * Math.PI);
      if (b.plus) {                                    // a tiny medical plus
        f.streak(b.x - 3, y, b.x + 3, y, "rgba(155,226,138," + a + ")", 2);
        f.streak(b.x, y - 3, b.x, y + 3, "rgba(155,226,138," + a + ")", 2);
      } else {
        f.star(b.x, y, 4 * a, 1.2 * a, 4, "rgba(155,226,138," + a + ")", p * 2);
      }
      f.glow(b.x, y, 5 * a, "rgba(155,226,138,", a * 0.4);
    }
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5, "add");
      u.strip(sheet, i);
      u.label("same rig as Embers, recoloured and slowed — palettes are half of VFX", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 26; }
  };
});

def("L", "Lightning", "magic", "a fresh jagged path EVERY frame — seed + i, because chaos reads as energy", function make(u) {
  var N = 10, S = 96, FPS = 24;
  function bolt(f, seed, x0, y0, x1, y1, wid, alpha) {
    var R = u.rng(seed);
    var pts = [[x0, y0]];
    var steps = 7;
    for (var s = 1; s < steps; s++) {
      var q = s / steps;
      pts.push([x0 + (x1 - x0) * q + (R() - 0.5) * 22 * (1 - Math.abs(q - 0.5)),
                y0 + (y1 - y0) * q]);
    }
    pts.push([x1, y1]);
    f.g.strokeStyle = "rgba(232,229,244," + alpha + ")";
    f.g.lineWidth = wid;
    f.g.lineJoin = "round";
    f.g.beginPath();
    for (var j = 0; j < pts.length; j++)
      j === 0 ? f.g.moveTo(pts[j][0], pts[j][1]) : f.g.lineTo(pts[j][0], pts[j][1]);
    f.g.stroke();
    return pts;
  }
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    if (k > 0.8) return;                               // over, holding on empty
    var a = k < 0.5 ? 1 : 1 - (k - 0.5) / 0.3;
    var pts = bolt(f, 100 + f.i, f.c + 8, 6, f.c, f.S - 18, 2.5, a);           // new path
    bolt(f, 200 + f.i, f.c + 8, 6, f.c - 18, f.S - 30, 1.2, a * 0.5);          // per frame!
    f.g.strokeStyle = "rgba(138,217,245," + a * 0.4 + ")";
    f.g.lineWidth = 6;
    f.g.beginPath();
    for (var j = 0; j < pts.length; j++)
      j === 0 ? f.g.moveTo(pts[j][0], pts[j][1]) : f.g.lineTo(pts[j][0], pts[j][1]);
    f.g.stroke();
    f.glow(f.c, f.S - 18, 9 * a, "rgba(232,229,244,", a * 0.9);
  });
  var px = u.W * 0.5, py = u.GY - 46, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.3) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("smooth flipbooks interpolate; electric ones re-roll the dice per frame", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 12; t0 = -9; }
  };
});

def("M", "Magicircle", "magic", "two rune rings counter-rotate in one sheet — layers cost nothing once baked", function make(u) {
  var N = 16, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    var a0 = f.kl * u.TAU;                             // one full turn per loop —
    f.g.save();                                        // so frame N = frame 0
    f.g.translate(f.c, f.c);
    f.g.scale(1, 0.5);                                 // laid flat on the floor
    f.ring(0, 0, 34, "rgba(201,160,245,0.8)", 1.5);
    f.ring(0, 0, 24, "rgba(201,160,245,0.5)", 1);
    for (var j = 0; j < 8; j++) {                      // outer runes, clockwise
      var a = a0 + j * u.TAU / 8;
      var x = Math.cos(a) * 34, y = Math.sin(a) * 34;
      f.streak(x - 3, y - 3, x + 3, y + 3, "rgba(232,229,244,0.85)", 1.5);
      f.streak(x - 3, y + 3, x + 3, y - 3, "rgba(232,229,244,0.85)", 1.5);
    }
    for (var j2 = 0; j2 < 5; j2++) {                   // inner ticks, ANTI-clockwise
      var b = -a0 * 2 + j2 * u.TAU / 5;
      f.dot(Math.cos(b) * 24, Math.sin(b) * 24, 2.4, "rgba(245,193,105,0.9)");
    }
    f.g.restore();
    var br = 0.5 + 0.5 * Math.sin(f.kl * u.TAU * 2);
    f.glow(f.c, f.c, 12 + br * 4, "rgba(201,160,245,", 0.3 + br * 0.2);
  });
  var px = u.W * 0.5, py = u.GY - 4;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.7, "add");
      u.mote(px, u.GY - 14);                           // standing IN the circle
      u.strip(sheet, i);
      u.label("blit-below, hero, blit-above — flipbooks sort like any sprite", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; }
  };
});

def("S", "Sparkle", "magic", "eight twinkles, each on its own phase of the same 14-frame clock", function make(u) {
  var N = 14, S = 96, FPS = 13;
  var R = u.rng(83);
  var tw = [];
  for (var j = 0; j < 8; j++)
    tw.push({ x: 14 + R() * 68, y: 14 + R() * 68, off: R(), r: 3.5 + R() * 4 });
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < tw.length; j++) {
      var s = tw[j];
      var p = (f.kl + s.off) % 1;
      var a = Math.pow(Math.sin(p * Math.PI), 2);      // sharp little blink
      if (a < 0.03) continue;
      f.star(s.x, s.y, s.r * a, s.r * 0.28 * a, 4, "rgba(245,241,220," + a + ")", p);
      f.glow(s.x, s.y, s.r * 1.6 * a, "rgba(138,217,245,", a * 0.4);
    }
  });
  var px = u.W * 0.5, py = u.GY - 34;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("pickups, treasure, freshly-mopped floors — the universal shine", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("W", "Warp", "magic", "a portal: the rim wobbles on a 2-lobe sine while inner arcs spiral — all in 16 frames", function make(u) {
  var N = 16, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var a0 = f.kl * u.TAU;
    f.g.strokeStyle = "rgba(201,160,245,0.9)";
    f.g.lineWidth = 2.5;
    f.g.beginPath();
    for (var j = 0; j <= 40; j++) {                    // the wobbling rim
      var a = (j / 40) * u.TAU;
      var r = 30 + Math.sin(a * 2 + a0 * 2) * 3;       // 2 lobes × 2 laps = seamless
      var x = f.c + Math.cos(a) * r * 0.62, y = f.c + Math.sin(a) * r;
      j === 0 ? f.g.moveTo(x, y) : f.g.lineTo(x, y);
    }
    f.g.closePath(); f.g.stroke();
    for (var s = 0; s < 3; s++) {                      // falling-inward arcs
      var p = (f.kl + s / 3) % 1;
      var rr = 26 * (1 - p);
      f.g.strokeStyle = "rgba(138,217,245," + (1 - p) * 0.7 + ")";
      f.g.lineWidth = 1.5;
      f.g.beginPath();
      f.g.ellipse(f.c, f.c, rr * 0.62, rr, 0, a0 * 3 + p * 2, a0 * 3 + p * 2 + 2.2);
      f.g.stroke();
    }
    f.glow(f.c, f.c, 10, "rgba(201,160,245,", 0.35);
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px + 40, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("wobble lobes × laps must divide evenly or the loop pops — try breaking it", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("Z", "Zap", "magic", "short arcs crackle AROUND the body, re-rolled each frame like Lightning's little sibling", function make(u) {
  var N = 12, S = 96, FPS = 18;
  var sheet = u.bake(N, S, function (f) {
    var R = u.rng(900 + f.i);                          // fresh chaos per frame
    var strong = f.i % 4 === 0;                        // every 4th frame surges
    for (var j = 0; j < 5; j++) {
      var a = R() * u.TAU;
      var r0 = 16 + R() * 10;
      var x0 = f.c + Math.cos(a) * r0, y0 = f.c + Math.sin(a) * r0;
      var x1 = x0 + (R() - 0.5) * 16, y1 = y0 + (R() - 0.5) * 16;
      var xm = (x0 + x1) / 2 + (R() - 0.5) * 8, ym = (y0 + y1) / 2 + (R() - 0.5) * 8;
      var al = (strong ? 0.95 : 0.55) * (0.6 + R() * 0.4);
      f.g.strokeStyle = "rgba(138,217,245," + al + ")";
      f.g.lineWidth = strong ? 2 : 1.2;
      f.g.beginPath(); f.g.moveTo(x0, y0); f.g.lineTo(xm, ym); f.g.lineTo(x1, y1); f.g.stroke();
    }
    if (strong) f.glow(f.c, f.c, 20, "rgba(138,217,245,", 0.3);
  });
  var px = u.W * 0.5, py = u.GY - 26;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5, "add");
      u.strip(sheet, i);
      u.label("a stun state you can leave running on any enemy — it's just a loop", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

/* ============================== SPEECH & CELEBRATION ==============================
   The juice layer: effects that talk to the PLAYER rather than the world.
   Confetti says "you did it", the pop-up punctuation says "I noticed you",
   the shout says "someone is loud". Mostly source-over — paper and ink —
   and mostly one-shots, because a reaction that loops stops being one. */

def("C", "Confetti", "speech", "fourteen paper flecks on ballistic arcs, tumbling by k — a celebration in 14 frames", function make(u) {
  var N = 14, S = 96, FPS = 15;
  var R = u.rng(93);
  var cols = ["#F58A8A", "#F5C169", "#9BE28A", "#8AD9F5", "#C9A0F5"];
  var bits = [];
  for (var j = 0; j < 14; j++)
    bits.push({ vx: (R() - 0.5) * 46, vy: -30 - R() * 26, spin: (R() - 0.5) * 14,
                c: cols[j % cols.length], w: 3 + R() * 3, h: 2 + R() * 2 });
  var sheet = u.bake(N, S, function (f) {
    var k = f.k, T = k * 1.15;                         // T = the fleck's flight time
    for (var j = 0; j < bits.length; j++) {
      var b = bits[j];
      var x = f.c + b.vx * T;
      var y = f.S - 26 + b.vy * T + 42 * T * T;        // v·t + ½g·t² — real ballistics
      var a = k < 0.75 ? 1 : 1 - (k - 0.75) / 0.25;
      f.g.save();
      f.g.translate(x, y);
      f.g.rotate(b.spin * T);
      f.g.globalAlpha = a;
      f.g.fillStyle = b.c;
      f.g.fillRect(-b.w / 2, -b.h / 2, b.w, b.h);      // paper is a rectangle
      f.g.restore();
      f.g.globalAlpha = 1;
    }
  });
  var px = u.W * 0.5, py = u.GY - 44, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.3) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("gravity baked at 42 px/s² — physics happened, once, at bake time", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("Q", "Question", "speech", "a ? pops up with overshoot and hangs — punctuation as a status effect", function make(u) {
  var N = 12, S = 96, FPS = 16;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    if (k > 0.9) return;
    var over = k < 0.3 ? (k / 0.3) * 1.25 - Math.pow(k / 0.3, 2) * 0.25 : 1;  // pop past 1
    var a = k < 0.65 ? 1 : 1 - (k - 0.65) / 0.25;
    var bob = k > 0.3 ? Math.sin((k - 0.3) * u.TAU * 1.4) * 2 : 0;
    f.g.save();
    f.g.translate(f.c, f.c + 8 + bob);
    f.g.scale(over, over);
    f.g.globalAlpha = a;
    f.g.font = "700 44px 'Spline Sans Mono', Consolas, monospace";
    f.g.textAlign = "center";
    f.g.textBaseline = "middle";
    f.g.lineWidth = 6;
    f.g.strokeStyle = "#131020";                       // ink outline first,
    f.g.strokeText("?", 0, 0);
    f.g.fillStyle = "#F5C169";                         // then the paint
    f.g.fillText("?", 0, 0);
    f.g.restore();
    f.g.globalAlpha = 1;
  });
  var px = u.W * 0.5, py = u.GY - 58, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.4);
      u.strip(sheet, i);
      u.label("glyphs bake like anything else — the sheet doesn't know it's a letter", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("Y", "Yell", "speech", "three arc-triplets ripple outward from the mouth — sound, drawn — plus speedline ticks", function make(u) {
  var N = 12, S = 96, FPS = 16;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var mx = 24, my = f.c;                             // the mouth, facing right
    for (var j = 0; j < 3; j++) {
      var p = k - j * 0.18;                            // three staggered waves
      if (p <= 0 || p > 0.85) continue;
      var r = 8 + p * 40;
      var a = (1 - p / 0.85) * 0.9;
      f.g.strokeStyle = "rgba(245,193,105," + a + ")";
      f.g.lineWidth = 2.5 * (1 - p * 0.6);
      f.g.lineCap = "round";
      f.g.beginPath(); f.g.arc(mx, my, r, -0.6, 0.6); f.g.stroke();
      f.g.beginPath(); f.g.arc(mx, my, r * 0.8, -0.45, 0.45); f.g.stroke();
      f.g.lineCap = "butt";
    }
    if (k < 0.3) {                                     // the first-instant ticks
      var a2 = 1 - k / 0.3;
      for (var s = -1; s <= 1; s++)
        f.streak(mx + 4, my + s * 9, mx + 12, my + s * 13, "rgba(232,229,244," + a2 + ")", 1.5);
    }
  });
  var px = u.W * 0.5 + 14, py = u.GY - 24, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(px - 14, u.GY - 12);
      u.blit(sheet, i, px + 10, py, 1.5, "add");
      u.strip(sheet, i);
      u.label("pair it with chapter 7's blips and the yell becomes audible", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

/* ============================== THE SECOND LAP ==============================
   The alphabet, again — 26 more sheets, so every letter owns two effects.
   Nothing new is needed to make them: the same baker, the same two index
   lines, the same five families. That's the quiet point of the second lap —
   once the machinery exists, another 26 effects is just another 26 ideas. */

/* ---- glow & flame, lap two ---- */

def("A", "Afterimage", "glow", "a dasher laps an ellipse; its ghosts are just 'where I recently was', baked", function make(u) {
  var N = 16, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    for (var s = 4; s >= 0; s--) {                     // ghosts first, head last
      var p = f.kl - s * 0.045;
      var a = p * u.TAU;
      var x = f.c + Math.cos(a) * 30, y = f.c + Math.sin(a) * 16;
      var al = 1 - s * 0.22;
      f.glow(x, y, (7 - s) * al, "rgba(138,217,245,", al * 0.7);
      f.dot(x, y, (5 - s * 0.8) * al, "rgba(138,217,245," + al + ")");
      if (s === 0) f.dot(x + 1.8, y - 1.5, 1.3, "#131020");   // the eye
    }
  });
  var px = u.W * 0.5, py = u.GY - 34;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("the lexicon's dash + chapter 6's afterimage, married and frozen", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("C", "Comet", "glow", "a head on a tilted ellipse, a tail of samples taken BACKWARD along the same path", function make(u) {
  var N = 16, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    function pos(p) {
      var a = p * u.TAU;
      return [f.c + Math.cos(a) * 31, f.c + Math.sin(a) * 19 - Math.cos(a) * 6];
    }
    for (var s = 9; s >= 1; s--) {                     // the tail, thinning
      var q = pos(f.kl - s * 0.022);
      var al = 1 - s / 10;
      f.dot(q[0], q[1], 2.6 * al + 0.4, "rgba(245,193,105," + al * 0.8 + ")");
    }
    var h = pos(f.kl);
    f.glow(h[0], h[1], 9, "rgba(245,220,150,", 0.9);
    f.star(h[0], h[1], 5, 1.6, 4, "rgba(245,241,220,0.95)", f.kl * 2);
  });
  var px = u.W * 0.5, py = u.GY - 36;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Afterimage's trick at a different tempo — tails are backward sampling", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("E", "Eclipse", "glow", "a dark disc crosses a glow on cos(kl·2π) — passing twice per lap makes the loop seamless", function make(u) {
  var N = 16, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    var x = Math.cos(f.kl * u.TAU) * 40;               // sweeps right-left-right
    var near = Math.max(0, 1 - Math.abs(x) / 16);      // 1 at totality
    f.glow(f.c, f.c, 20 + near * 8, "rgba(245,220,150,", 0.7 + near * 0.3);
    f.dot(f.c, f.c, 13, "rgba(245,220,150,0.95)");
    if (near > 0.2)                                    // the corona spikes
      for (var j = 0; j < 8; j++) {
        var a = j * u.TAU / 8 + 0.4;
        f.streak(f.c + Math.cos(a) * 16, f.c + Math.sin(a) * 16,
          f.c + Math.cos(a) * (16 + near * 9), f.c + Math.sin(a) * (16 + near * 9),
          "rgba(245,241,220," + near * 0.8 + ")", 1.5);
      }
    f.dot(f.c + x, f.c, 12, "rgba(19,16,32,0.96)");    // the moon, opaque on purpose
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5);                   // source-over: the moon must occlude
      u.strip(sheet, i);
      u.label("one OPAQUE pixel patch inside a light effect forces source-over playback", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("F", "Fireflies", "glow", "six wanderers on Lissajous paths — whole-number frequencies, or the loop tears", function make(u) {
  var N = 16, S = 96, FPS = 12;
  var R = u.rng(107);
  var flies = [];
  for (var j = 0; j < 6; j++)
    flies.push({ a: 1 + Math.floor(R() * 2), b: 1 + Math.floor(R() * 3),
                 pa: R() * u.TAU, pb: R() * u.TAU, blink: 2 + Math.floor(R() * 2), off: R() });
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < flies.length; j++) {
      var y = flies[j];
      var x = f.c + Math.sin(y.a * f.kl * u.TAU + y.pa) * 30;
      var yy = f.c + Math.sin(y.b * f.kl * u.TAU + y.pb) * 24;
      var a = Math.pow(0.5 + 0.5 * Math.sin(y.blink * f.kl * u.TAU + y.off * 9), 3);
      f.glow(x, yy, 6 * a + 1, "rgba(215,245,140,", a * 0.8);
      f.dot(x, yy, 1.4, "rgba(245,245,200," + (0.3 + a * 0.7) + ")");
    }
  });
  var px = u.W * 0.5, py = u.GY - 38;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("the lexicon's Eight, moonlighting — integer frequencies close every path", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("W", "Wisp", "glow", "a bobbing ghost with a phase-lagged tail — hello, little sibling from the Godot demo", function make(u) {
  var N = 12, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    var bob = Math.sin(f.kl * u.TAU) * 4;
    f.glow(f.c, f.c - 6 + bob, 16, "rgba(220,225,245,", 0.8);       // the head
    f.glow(f.c, f.c + 6 + bob * 0.8, 12, "rgba(220,225,245,", 0.7); // the body
    for (var s = 1; s <= 3; s++) {                     // the tail curls a beat behind
      var lag = Math.sin((f.kl - s * 0.09) * u.TAU) * 4;
      f.glow(f.c + Math.sin(s * 1.8) * 3.5, f.c + 14 + s * 5 + lag * 0.6,
        7 - s * 1.7, "rgba(220,225,245,", 0.55 - s * 0.14);
    }
    f.dot(f.c - 4, f.c - 7 + bob, 1.8, "rgba(80,200,240,0.95)");    // two calm eyes
    f.dot(f.c + 4, f.c - 7 + bob, 1.8, "rgba(80,200,240,0.95)");
  });
  var px = u.W * 0.5, py = u.GY - 38;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("the flipbook_vfx wisp (Godot, menu key H), waving from the web", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

/* ---- hits & slashes, lap two ---- */

def("I", "Iceshard", "hit", "crystals grow, gleam once, then shatter — three acts staggered inside one strip", function make(u) {
  var N = 12, S = 96, FPS = 18;
  var R = u.rng(113);
  var spikes = [];
  for (var j = 0; j < 5; j++)
    spikes.push({ a: (j / 5) * u.TAU - 0.5 + R() * 0.4, len: 20 + R() * 10 });
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    if (k < 0.55) {                                    // act 1: growth
      var g = u.ease(k / 0.55);
      for (var j = 0; j < spikes.length; j++) {
        var s = spikes[j];
        var tx = f.c + Math.cos(s.a) * s.len * g, ty = f.c + Math.sin(s.a) * s.len * g;
        f.streak(f.c, f.c, tx, ty, "rgba(190,230,250,0.9)", 3.5 * g + 0.5);
        f.streak(f.c, f.c, tx, ty, "rgba(138,217,245,0.5)", 7 * g + 1);
      }
      if (k > 0.4) f.star(f.c, f.c, 8, 2.5, 4, "rgba(245,251,255," + (k - 0.4) / 0.15 * 0.9 + ")", 0.3);
    } else if (k < 0.9) {                              // act 2 + 3: shatter, scatter
      var sc = (k - 0.55) / 0.35;
      for (var j2 = 0; j2 < spikes.length; j2++) {
        var s2 = spikes[j2];
        var d = s2.len * (0.6 + sc * 0.9);
        var x = f.c + Math.cos(s2.a) * d, y = f.c + Math.sin(s2.a) * d + sc * sc * 10;
        f.star(x, y, 4 * (1 - sc), 1.4 * (1 - sc), 4, "rgba(190,230,250," + (1 - sc) + ")", sc * 3 + j2);
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("grow → gleam → shatter: three acts, one clamp index", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("M", "Meteor", "hit", "falls for 60% of the strip, lands for the rest — the impact frame is a hard cut", function make(u) {
  var N = 12, S = 96, FPS = 20;
  var x0 = 14, y0 = 10, x1 = 60, y1 = 74;              // the flight line
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    if (k < 0.6) {                                     // flight: head + trailing fire
      var p = k / 0.6;
      var x = x0 + (x1 - x0) * p, y = y0 + (y1 - y0) * p;
      f.streak(x - 10, y - 14, x, y, "rgba(245,161,90,0.7)", 5);
      f.streak(x - 16, y - 23, x, y, "rgba(245,138,90,0.35)", 8);
      f.glow(x, y, 8, "rgba(245,220,150,", 0.95);
    } else {                                           // landing: flash, ring, debris
      var q = (k - 0.6) / 0.4;
      if (q < 0.35) f.glow(x1, y1, 16 * (1 - q / 0.35), "rgba(245,241,220,", 0.95);
      f.ring(x1, y1, 4 + q * 26, "rgba(245,193,105," + (1 - q) + ")", 3 * (1 - q) + 0.5);
      for (var j = 0; j < 5; j++) {
        var a = Math.PI + (j / 4) * Math.PI + 0.3;
        var d = q * 22;
        f.dot(x1 + Math.cos(a) * d, y1 + Math.sin(a) * d - q * (1 - q) * 18,
          2.2 * (1 - q), "rgba(245,161,90," + (1 - q) + ")");
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 40, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.3) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5 + 30, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("watch the strip: the cut from flight to flash IS the impact", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("P", "Pop", "hit", "a bubble inflates past its nerve and becomes droplets — matter changing state mid-strip", function make(u) {
  var N = 10, S = 96, FPS = 18;
  var R = u.rng(127);
  var drops = [];
  for (var j = 0; j < 8; j++)
    drops.push({ a: (j / 8) * u.TAU + R() * 0.4, sp: 0.7 + R() * 0.5 });
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    if (k < 0.55) {                                    // inflating, increasingly nervous
      var p = k / 0.55;
      var r = 8 + p * 15;
      var wob = Math.sin(p * 26) * p * 2.5;
      f.ring(f.c, f.c, r + wob, "rgba(138,217,245,0.9)", 2);
      f.dot(f.c - r * 0.35, f.c - r * 0.4, 2.2, "rgba(245,251,255,0.8)");
    } else {                                           // the pop
      var q = (k - 0.55) / 0.45;
      for (var j2 = 0; j2 < drops.length; j2++) {
        var d2 = drops[j2];
        var d = 23 * d2.sp * Math.pow(q, 0.7) + 4;
        f.dot(f.c + Math.cos(d2.a) * d, f.c + Math.sin(d2.a) * d + q * q * 8,
          2 * (1 - q) + 0.3, "rgba(138,217,245," + (1 - q) + ")");
      }
      if (q < 0.3) f.ring(f.c, f.c, 23 + q * 20, "rgba(245,251,255," + (0.3 - q) / 0.3 * 0.7 + ")", 1.5);
    }
  });
  var px = u.W * 0.5, py = u.GY - 36, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("the wobble before the pop is the tell — anticipation, baked", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("Q", "Quake", "hit", "cracks spider outward frame by frame — a one-shot that draws MORE as it ages, not less", function make(u) {
  var N = 12, S = 96, FPS = 16;
  function crack(f, seed, x0, y0, ang, reach) {
    var R = u.rng(seed);                               // same seed every frame:
    var x = x0, y = y0, a = ang;                       // the crack path is stable,
    var steps = Math.floor(reach * 7);                 // only its LENGTH grows
    for (var s = 0; s < steps; s++) {
      var nx = x + Math.cos(a) * 5, ny = y + Math.sin(a) * 2.2;
      f.streak(x, y, nx, ny, "rgba(30,24,48,0.9)", 2.2 - s * 0.18);
      f.streak(x, y, nx, ny, "rgba(201,196,228,0.25)", 3.6 - s * 0.2);
      x = nx; y = ny; a += (R() - 0.5) * 1.1;
    }
    return [x, y];
  }
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var reach = u.ease(Math.min(1, k / 0.7));
    for (var j = 0; j < 4; j++) {
      var tip = crack(f, 500 + j, f.c, f.S - 26, j * u.TAU / 4 + 0.4, reach);
      if (k > 0.15 && k < 0.85)                        // dust breathes at the tips
        f.dot(tip[0], tip[1] - 3, 3 * Math.sin(k * Math.PI), "rgba(160,150,140,0.35)");
    }
    if (k > 0.85)                                      // and everything settles
      for (var j2 = 0; j2 < 4; j2++)
        crack(f, 500 + j2, f.c, f.S - 26, j2 * u.TAU / 4 + 0.4, 1);
  });
  var px = u.W * 0.5, py = u.GY - 30, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.4) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("same seed each frame + growing step count = a crack that remembers itself", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = u.GY - 30; t0 = -9; }
  };
});

def("U", "Uppercut", "hit", "Trailslash turned vertical: a rising arc, speedlines, and a star at the apex", function make(u) {
  var N = 10, S = 96, FPS = 22;
  var A0 = 2.6, A1 = -1.2;                             // bottom-left, swinging up
  var sheet = u.bake(N, S, function (f) {
    var k = u.ease(f.k);
    var a = A0 + (A1 - A0) * k;
    var fade = f.k < 0.7 ? 1 : 1 - (f.k - 0.7) / 0.3;
    for (var s = 0; s < 4; s++) {
      var ga = a + s * 0.3;
      if (ga > A0) continue;
      f.g.strokeStyle = "rgba(232,229,244," + fade * (0.85 - s * 0.2) + ")";
      f.g.lineWidth = 6 - s * 1.3;
      f.g.lineCap = "round";
      f.g.beginPath();
      f.g.arc(f.c + 8, f.c + 8, 30, ga - 0.1, ga + 0.45);
      f.g.stroke();
      f.g.lineCap = "butt";
    }
    for (var v = 0; v < 3; v++)                        // vertical speedlines
      f.streak(20 + v * 8, f.S - 18 - k * 20, 20 + v * 8, f.S - 8 - k * 20,
        "rgba(138,217,245," + fade * 0.5 + ")", 1.4);
    if (f.k > 0.5) {
      var q = (f.k - 0.5) / 0.5;
      f.star(f.c + 8 + Math.cos(A1) * 30, f.c + 8 + Math.sin(A1) * 30,
        7 * (1 - q) + 1, 2.4 * (1 - q) + 0.3, 4, "rgba(245,241,220," + fade + ")", q);
    }
  });
  var px = u.W * 0.5, py = u.GY - 40, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.1) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("rotate a baked effect by re-baking, not by rotating the blit — pixels blur", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("X", "Xstamp", "hit", "an X slams down with a squash on landing — scale drawn INTO the frames, not onto them", function make(u) {
  var N = 10, S = 96, FPS = 18;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    if (k > 0.9) return;
    var sc, sy;
    if (k < 0.35) { sc = 2 - k / 0.35; sy = 1; }       // falling in, oversized
    else if (k < 0.55) { sc = 1; sy = 1 - Math.sin((k - 0.35) / 0.2 * Math.PI) * 0.25; }  // squash!
    else { sc = 1; sy = 1; }
    var a = k < 0.75 ? 1 : 1 - (k - 0.75) / 0.15;
    var L = 17 * sc;
    f.g.save();
    f.g.translate(f.c, f.c);
    f.g.scale(1, sy);
    f.g.globalAlpha = a * (k < 0.35 ? 0.35 + k : 1);
    f.streak(-L, -L, L, L, "rgba(245,138,138,1)", 8);
    f.streak(-L, L, L, -L, "rgba(245,138,138,1)", 8);
    f.streak(-L, -L, L, L, "rgba(19,16,32,0.9)", 3);
    f.g.restore();
    f.g.globalAlpha = 1;
    if (k > 0.35 && k < 0.7)                           // the landing dust ring
      f.ring(f.c, f.c + 14, (k - 0.35) * 60, "rgba(160,150,140," + (0.7 - k) + ")", 2);
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5);
      u.strip(sheet, i);
      u.label("squash-and-stretch survives baking — it's just geometry per frame", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

/* ---- smoke, dust & water, lap two ---- */

def("B", "Bubbles", "smoke", "six risers wobble up on offset clocks and pop into ticks at the surface", function make(u) {
  var N = 16, S = 96, FPS = 12;
  var R = u.rng(131);
  var bubs = [];
  for (var j = 0; j < 6; j++)
    bubs.push({ x: 20 + R() * 56, off: R(), r: 2.5 + R() * 3, sway: 3 + R() * 4 });
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < bubs.length; j++) {
      var b = bubs[j];
      var p = (f.kl + b.off) % 1;
      var y = f.S - 12 - p * (f.S - 28);
      var x = b.x + Math.sin(p * u.TAU * 2 + b.off * 8) * b.sway;
      if (p < 0.85) {
        f.ring(x, y, b.r * (0.7 + p * 0.5), "rgba(138,217,245," + (0.4 + p * 0.4) + ")", 1.3);
        f.dot(x - b.r * 0.3, y - b.r * 0.35, 0.9, "rgba(245,251,255,0.7)");
      } else {                                         // the pop: four tiny ticks
        var q = (p - 0.85) / 0.15;
        for (var s = 0; s < 4; s++) {
          var a = s * u.TAU / 4 + 0.6;
          f.dot(x + Math.cos(a) * (b.r + q * 4), y + Math.sin(a) * (b.r + q * 4),
            0.8 * (1 - q), "rgba(138,217,245," + (1 - q) + ")");
        }
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5, "add");
      u.strip(sheet, i);
      u.label("each riser carries its whole life — birth, wobble, pop — in one lap", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 20; }
  };
});

def("D", "Drip", "smoke", "form, stretch, fall, splash — the classic animation exercise, twelve frames long", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var topY = 14, floorY = f.S - 16;
    if (k < 0.4) {                                     // forming: a swelling drop
      var p = k / 0.4;
      var r = 2 + p * 3.5;
      f.dot(f.c, topY + r, r, "rgba(138,217,245,0.9)");
      f.streak(f.c, topY, f.c, topY + r * (1 + p), "rgba(138,217,245,0.7)", 2 + p);
    } else if (k < 0.7) {                              // falling: stretched by speed
      var q = (k - 0.4) / 0.3;
      var y = topY + 8 + u.ease(q) * (floorY - topY - 10);
      f.g.save();
      f.g.translate(f.c, y);
      f.g.scale(0.7, 1.5);                             // the classic falling squash
      f.dot(0, 0, 4.5, "rgba(138,217,245,0.9)");
      f.g.restore();
    } else {                                           // splash: crown + ripple
      var s = (k - 0.7) / 0.3;
      for (var j = 0; j < 5; j++) {
        var a = Math.PI + (j / 4) * Math.PI;
        f.dot(f.c + Math.cos(a) * s * 14, floorY + Math.sin(a) * s * 9 + s * s * 6,
          1.6 * (1 - s), "rgba(138,217,245," + (1 - s) + ")");
      }
      f.g.strokeStyle = "rgba(138,217,245," + (1 - s) * 0.8 + ")";
      f.g.lineWidth = 1.5;
      f.g.beginPath();
      f.g.ellipse(f.c, floorY + 2, 4 + s * 16, (4 + s * 16) * 0.3, 0, 0, u.TAU);
      f.g.stroke();
    }
  });
  var px = u.W * 0.5, py = u.GY - 40, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5 + 30, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("every animation course starts here; now it's a texture", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("G", "Geyser", "smoke", "a water column erupts, crowns, and rains back down its own sides", function make(u) {
  var N = 12, S = 96, FPS = 16;
  var R = u.rng(139);
  var spray = [];
  for (var j = 0; j < 8; j++)
    spray.push({ dx: (R() - 0.5) * 26, off: R() * 0.3, sp: 0.7 + R() * 0.6 });
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var base = f.S - 12;
    var h = u.ease(Math.min(1, k / 0.45)) * 52 * (k < 0.75 ? 1 : 1 - (k - 0.75) / 0.35);
    for (var s = 0; s < Math.floor(h / 6); s++)        // the column, stacked
      f.glow(f.c + Math.sin(s * 2 + k * 9) * 1.5, base - s * 6,
        7 - s * 0.45, "rgba(138,217,245,", 0.7 - s * 0.04);
    if (k > 0.3)                                       // the crown spray, falling
      for (var j2 = 0; j2 < spray.length; j2++) {
        var p2 = spray[j2];
        var q = Math.max(0, (k - 0.3 - p2.off) / 0.7);
        if (q <= 0 || q >= 1) continue;
        f.dot(f.c + p2.dx * q * p2.sp, base - h - 2 + (q * q * 40 - q * 18),
          1.8 * (1 - q * 0.6), "rgba(190,235,250," + (1 - q) + ")");
      }
  });
  var px = u.W * 0.5, py = u.GY - 40, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.4) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5 + 34, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Waterdrops' physics, Flame's stacking — recipes compose", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("J", "Jelly", "smoke", "a blob hops on pure squash-and-stretch — volume conserved, sx = 1/sy", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var ph = f.kl * u.TAU;
    var sy = 1 + Math.sin(ph) * 0.28;                  // stretch…
    var sx = 1 / sy;                                   // …never gains volume
    var hop = Math.max(0, Math.sin(ph)) * 10;          // airborne while stretched
    var base = f.S - 20;
    f.dot(f.c, base + 4, 11 * sx * Math.max(0, 1 - hop / 8) * 0.5 + 3, "rgba(19,16,32,0.3)");  // shadow
    f.g.save();
    f.g.translate(f.c, base - 9 * sy - hop);
    f.g.scale(sx, sy);
    f.dot(0, 0, 11, "rgba(155,226,138,0.85)");
    f.dot(-3.5, -3.5, 3.2, "rgba(220,250,210,0.6)");   // the wet highlight
    f.g.restore();
    f.dot(f.c - 3.5 * sx, base - 11 * sy - hop, 1.5, "#131020");   // eyes ride the squash
    f.dot(f.c + 3.5 * sx, base - 11 * sy - hop, 1.5, "#131020");
  });
  var px = u.W * 0.5, py = u.GY - 26;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("squash × stretch = 1 — the volume rule that sells all boing", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("L", "Leaves", "smoke", "five leaves tumble down on offset clocks, swaying wider than they fall", function make(u) {
  var N = 16, S = 96, FPS = 12;
  var R = u.rng(149);
  var cols = ["rgba(214,168,120,", "rgba(196,140,90,", "rgba(155,180,110,"];
  var lvs = [];
  for (var j = 0; j < 5; j++)
    lvs.push({ x: 18 + R() * 60, off: R(), sway: 8 + R() * 8, spin: 2 + Math.floor(R() * 2), c: cols[j % 3] });
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < lvs.length; j++) {
      var L = lvs[j];
      var p = (f.kl + L.off) % 1;
      var y = 10 + p * (f.S - 22);
      var x = L.x + Math.sin(p * u.TAU * 2 + L.off * 7) * L.sway;
      var rot = p * u.TAU * L.spin;
      var a = p < 0.1 ? p / 0.1 : (p > 0.85 ? (1 - p) / 0.15 : 1);
      f.g.save();
      f.g.translate(x, y);
      f.g.rotate(rot);
      f.g.scale(1, 0.45 + 0.55 * Math.abs(Math.cos(rot)));   // the flat-side flip
      f.dot(0, 0, 3.6, L.c + a * 0.9 + ")");
      f.g.restore();
    }
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("the y-scale flip fakes 3D tumbling on a 2D leaf — free depth", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 20; }
  };
});

def("R", "Rain", "smoke", "eight fast streaks, each ending in a micro-splash exactly where it lands", function make(u) {
  var N = 12, S = 96, FPS = 16;
  var R = u.rng(151);
  var drops = [];
  for (var j = 0; j < 8; j++)
    drops.push({ x: 10 + R() * 76, off: R() });
  var sheet = u.bake(N, S, function (f) {
    var floor = f.S - 14;
    for (var j = 0; j < drops.length; j++) {
      var d = drops[j];
      var p = (f.kl + d.off) % 1;
      if (p < 0.75) {                                  // falling: a slanted streak
        var y = 6 + (p / 0.75) * (floor - 14);
        f.streak(d.x + 2, y, d.x, y + 9, "rgba(150,200,245,0.7)", 1.4);
      } else {                                         // landed: a widening tick-pair
        var q = (p - 0.75) / 0.25;
        f.streak(d.x - 2 - q * 3, floor - q * 3, d.x - 1, floor, "rgba(150,200,245," + (1 - q) + ")", 1);
        f.streak(d.x + 1, floor, d.x + 2 + q * 3, floor - q * 3, "rgba(150,200,245," + (1 - q) + ")", 1);
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("75% of each clock falls, 25% splashes — one particle, two costumes", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 20; }
  };
});

def("S", "Snow", "smoke", "eight flakes drift on lazy sines — Rain with the clock geared way down", function make(u) {
  var N = 16, S = 96, FPS = 10;
  var R = u.rng(157);
  var flakes = [];
  for (var j = 0; j < 8; j++)
    flakes.push({ x: 10 + R() * 76, off: R(), sway: 5 + R() * 6, r: 1.2 + R() * 1.4 });
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < flakes.length; j++) {
      var s = flakes[j];
      var p = (f.kl + s.off) % 1;
      var y = 6 + p * (f.S - 16);
      var x = s.x + Math.sin(p * u.TAU * 2 + s.off * 9) * s.sway;
      var a = p < 0.1 ? p / 0.1 : (p > 0.9 ? (1 - p) / 0.1 : 1);
      f.dot(x, y, s.r, "rgba(240,244,252," + a * 0.85 + ")");
      if (s.r > 2)                                     // the big ones get arms
        for (var m = 0; m < 3; m++) {
          var am = m * Math.PI / 3 + p * 2;
          f.streak(x - Math.cos(am) * s.r * 1.8, y - Math.sin(am) * s.r * 1.8,
            x + Math.cos(am) * s.r * 1.8, y + Math.sin(am) * s.r * 1.8,
            "rgba(240,244,252," + a * 0.5 + ")", 0.8);
        }
    }
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("same rig as Rain at 10 fps and half the fall — tempo is weather", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 20; }
  };
});

def("T", "Tornado", "smoke", "five stacked ellipses lag each other's sway — a funnel from phase offsets alone", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var base = f.S - 16;
    for (var s = 0; s < 5; s++) {                      // widest at the top
      var h = s / 4;
      var y = base - 6 - h * 46;
      var w = 5 + h * 22;
      var x = f.c + Math.sin(f.kl * u.TAU + s * 0.9) * (2 + h * 5);  // the lagging sway
      f.g.strokeStyle = "rgba(190,185,205," + (0.75 - h * 0.25) + ")";
      f.g.lineWidth = 2.2 - h * 0.8;
      f.g.beginPath();
      f.g.ellipse(x, y, w, w * 0.3, 0, 0, u.TAU);
      f.g.stroke();
    }
    for (var d = 0; d < 3; d++) {                      // circling debris
      var p = (f.kl * 2 + d / 3) % 1;
      var lev = 0.3 + d * 0.25;
      var rr = 5 + lev * 22;
      f.dot(f.c + Math.cos(p * u.TAU) * rr, base - 6 - lev * 46 + Math.sin(p * u.TAU) * rr * 0.3,
        1.6, "rgba(214,168,120,0.8)");
    }
  });
  var px = u.W * 0.5, py = u.GY - 34;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px + 38, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Vortex stood upright — the sway lag per level IS the funnel", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

/* ---- magic & sparkle, lap two ---- */

def("O", "Omen", "magic", "an eye opens, stares, drifts, closes — a one-shot that plays a MOOD, not a bang", function make(u) {
  var N = 12, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    if (k > 0.92) return;
    var open = k < 0.25 ? u.ease(k / 0.25) : (k > 0.7 ? u.ease((0.92 - k) / 0.22) : 1);
    var a = Math.min(1, open + 0.1);
    var w = 26, h = 14 * open;
    f.g.strokeStyle = "rgba(201,160,245," + a * 0.9 + ")";
    f.g.lineWidth = 2;
    f.g.beginPath();                                   // two lids
    f.g.moveTo(f.c - w, f.c);
    f.g.quadraticCurveTo(f.c, f.c - h * 2, f.c + w, f.c);
    f.g.quadraticCurveTo(f.c, f.c + h * 2, f.c - w, f.c);
    f.g.stroke();
    if (open > 0.3) {
      var drift = k > 0.35 && k < 0.6 ? Math.sin((k - 0.35) * 12) * 3 : 0;   // it LOOKS at you
      f.ring(f.c + drift, f.c, 7 * open, "rgba(245,193,105," + a + ")", 2);
      f.dot(f.c + drift, f.c, 2.6 * open, "rgba(245,241,220," + a + ")");
      f.glow(f.c, f.c, 20, "rgba(201,160,245,", open * 0.3);
    }
  });
  var px = u.W * 0.5, py = u.GY - 48, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.6) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5, "add");
      u.strip(sheet, i);
      u.label("slow one-shots read as omens; fast ones as hits — fps is tone", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("V", "Venom", "magic", "a puddle bubbles while sluggish drips feed it — poison as a patient loop", function make(u) {
  var N = 14, S = 96, FPS = 11;
  var R = u.rng(163);
  var bubs = [];
  for (var j = 0; j < 5; j++)
    bubs.push({ dx: (R() - 0.5) * 34, off: R(), r: 1.6 + R() * 2 });
  var sheet = u.bake(N, S, function (f) {
    var pool = f.S - 22;
    f.g.strokeStyle = "rgba(155,226,138,0.8)";
    f.g.lineWidth = 2;
    f.g.beginPath();
    f.g.ellipse(f.c, pool, 24, 7.5, 0, 0, u.TAU);
    f.g.stroke();
    f.glow(f.c, pool, 14, "rgba(155,226,138,", 0.3);
    var dp = f.kl;                                     // one slow drip per lap
    if (dp < 0.55) {
      var stretch = dp / 0.55;
      f.dot(f.c - 8, 18 + stretch * (pool - 24), 2.4 + stretch, "rgba(155,226,138,0.9)");
      f.streak(f.c - 8, 16, f.c - 8, 18 + stretch * 6, "rgba(155,226,138,0.5)", 1.5);
    } else if (dp < 0.7) {
      var sp = (dp - 0.55) / 0.15;                     // the splat ring
      f.ring(f.c - 8, pool, sp * 8, "rgba(200,245,180," + (1 - sp) + ")", 1.2);
    }
    for (var j2 = 0; j2 < bubs.length; j2++) {         // the simmer
      var b = bubs[j2];
      var p = (f.kl + b.off) % 1;
      var a = Math.sin(p * Math.PI);
      f.ring(f.c + b.dx, pool - p * 5, b.r * a, "rgba(200,245,180," + a * 0.7 + ")", 1);
    }
  });
  var px = u.W * 0.5, py = u.GY - 26;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px + 34, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("11 fps on purpose — poison should feel a little too slow", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

/* ---- speech & celebration, lap two ---- */

def("H", "Hearts", "speech", "three hearts rise, sway, and pulse — affection on offset clocks", function make(u) {
  var N = 14, S = 96, FPS = 12;
  function heart(f, x, y, r, a) {
    f.dot(x - r * 0.5, y - r * 0.35, r * 0.55, "rgba(245,138,160," + a + ")");
    f.dot(x + r * 0.5, y - r * 0.35, r * 0.55, "rgba(245,138,160," + a + ")");
    f.poly([[x - r, y - r * 0.15], [x + r, y - r * 0.15], [x, y + r]], "rgba(245,138,160," + a + ")");
  }
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < 3; j++) {
      var p = (f.kl + j / 3) % 1;
      var y = f.S - 16 - p * (f.S - 30);
      var x = f.c + Math.sin(p * u.TAU + j * 2) * 9;
      var a = Math.sin(p * Math.PI);
      var pulse = 1 + Math.sin(p * u.TAU * 3) * 0.12;  // the heartbeat
      heart(f, x, y, (4 + j) * pulse * (0.6 + a * 0.4), a);
    }
  });
  var px = u.W * 0.5, py = u.GY - 44;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5);
      u.strip(sheet, i);
      u.label("two discs + a triangle = a heart; three phases = a feeling", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 26; }
  };
});

def("K", "Knockstars", "speech", "the dizzy halo: stars circle a tilted ellipse overhead, blinking as they lap", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var cy = f.c + 4;
    f.g.strokeStyle = "rgba(245,193,105,0.2)";
    f.g.lineWidth = 1;
    f.g.beginPath();
    f.g.ellipse(f.c, cy, 26, 9, 0, 0, u.TAU);
    f.g.stroke();
    for (var j = 0; j < 3; j++) {
      var p = (f.kl + j / 3) % 1;
      var a = p * u.TAU;
      var x = f.c + Math.cos(a) * 26, y = cy + Math.sin(a) * 9;
      var front = Math.sin(a) > 0;                     // nearer half = bigger
      var r = front ? 5.5 : 3.8;
      f.star(x, y, r, r * 0.42, 5, "rgba(245,193,105," + (front ? 0.95 : 0.6) + ")", p * 5);
    }
  });
  var px = u.W * 0.5, py = u.GY - 52;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.4, "add");
      u.strip(sheet, i);
      u.label("park it over any stunned head — the loop does the acting", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("N", "Notes", "speech", "three music notes drift up on sway — a disc, a stem, a flag, a song", function make(u) {
  var N = 16, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < 3; j++) {
      var p = (f.kl + j / 3) % 1;
      var y = f.S - 18 - p * (f.S - 32);
      var x = f.c - 10 + j * 10 + Math.sin(p * u.TAU + j * 2.1) * 7;
      var a = Math.sin(p * Math.PI);
      var col = "rgba(232,229,244," + a + ")";
      f.dot(x, y, 3, col);                             // the head
      f.streak(x + 2.6, y - 1, x + 2.6, y - 12, col, 1.6);        // the stem
      f.wedge(x + 2.6, y - 12, 0.5, 6, 0.5, col);      // the flag
    }
  });
  var px = u.W * 0.5, py = u.GY - 46;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5);
      u.strip(sheet, i);
      u.label("chapter 7 makes the sound; this sheet is what the sound looks like", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 26; }
  };
});

def("Y", "Yoyo", "speech", "drop, sleep, snap back — a piecewise clock where each act gets its own easing", function make(u) {
  var N = 16, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var p = f.kl;
    var topY = 14, botY = f.S - 22;
    var y, spin = 0;
    if (p < 0.3) y = topY + u.ease(p / 0.3) * (botY - topY);          // the drop
    else if (p < 0.6) { y = botY; spin = (p - 0.3) / 0.3; }           // the sleep
    else if (p < 0.85) y = botY - u.ease((p - 0.6) / 0.25) * (botY - topY);  // the snap
    else y = topY;                                                    // the rest
    f.streak(f.c, topY - 6, f.c, y - 6, "rgba(201,196,228,0.6)", 1);  // the string
    f.dot(f.c, y, 7, "rgba(245,138,138,0.95)");
    f.ring(f.c, y, 7, "rgba(19,16,32,0.5)", 1.5);
    f.dot(f.c, y, 2, "rgba(245,241,220,0.9)");
    if (spin > 0)                                      // sleeping = spin ticks
      for (var s = 0; s < 3; s++) {
        var a = spin * 15 + s * u.TAU / 3;
        f.streak(f.c + Math.cos(a) * 9, y + Math.sin(a) * 9,
          f.c + Math.cos(a) * 12, y + Math.sin(a) * 12, "rgba(245,193,105,0.7)", 1.2);
      }
  });
  var px = u.W * 0.5, py = u.GY - 44;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.5);
      u.strip(sheet, i);
      u.label("four acts on one kl clock — piecewise phases are choreography", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("Z", "Zzz", "speech", "three Z glyphs climb a sleepy sine, each bigger than the last", function make(u) {
  var N = 14, S = 96, FPS = 10;
  var sheet = u.bake(N, S, function (f) {
    for (var j = 0; j < 3; j++) {
      var p = (f.kl + j / 3) % 1;
      var y = f.S - 20 - p * (f.S - 34);
      var x = f.c - 6 + Math.sin(p * u.TAU + j) * 8 + j * 4;
      var a = Math.sin(p * Math.PI) * 0.9;
      var fs = 10 + p * 10 + j * 2;                    // grows as it floats
      f.g.save();
      f.g.translate(x, y);
      f.g.rotate(Math.sin(p * u.TAU * 2) * 0.2);
      f.g.globalAlpha = a;
      f.g.font = "700 " + Math.round(fs) + "px 'Spline Sans Mono', Consolas, monospace";
      f.g.textAlign = "center";
      f.g.textBaseline = "middle";
      f.g.fillStyle = "#C9C4E4";
      f.g.fillText("Z", 0, 0);
      f.g.restore();
      f.g.globalAlpha = 1;
    }
  });
  var px = u.W * 0.5, py = u.GY - 48;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5);
      u.strip(sheet, i);
      u.label("10 fps — sleep is the one effect that should feel like low fps", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 30; }
  };
});

/* ============================== THE GENRE LAPS (3 & 4) ==============================
   The alphabet twice more — 52 sheets flavoured by genre: sci-fi & glitch,
   fantasy & adventure, action & arcade, cozy & minimal, goofy & playful.
   This half of the folio is a picture-book first: find the visual you were
   imagining, open its code, turn its numbers. Only a handful of cards
   introduce genuinely new machinery (Axolotl's attach-and-sync, Beam's
   start/loop/end triple, Runner's two-clip atlas, Waddle's ping-pong index,
   Glitch's per-frame clocks, Tempo's three read speeds) — every other card
   names the older card it borrows from. */

/* ---- lap three ---- */

def("A", "Axolotl", "cozy", "a swimmer crosses on a loop while a SECOND sheet tracks it — sparkles synced to its turns", function make(u) {
  var CN = 8, S = 96, FPS = 10;
  var critter = u.bake(CN, S, function (f) {          // the swimmer, facing right
    var w = Math.sin(f.kl * u.TAU);
    for (var s = 0; s < 5; s++) {                     // the tail, wiggling behind
      var q = s / 4;
      f.dot(f.c - 6 - s * 5, f.c + Math.sin(f.kl * u.TAU - q * 2.4) * (2 + q * 5),
        5 - s, "rgba(245,182,193," + (0.9 - q * 0.4) + ")");
    }
    f.dot(f.c + 6, f.c + w * 1.5, 9, "rgba(245,182,193,0.95)");     // the head
    for (var g = -1; g <= 1; g++) {                   // the famous gills
      f.streak(f.c + 9, f.c - 6 + w, f.c + 15 + g * 2, f.c - 11 + g * 3 + w, "rgba(240,130,150,0.9)", 2);
      f.streak(f.c + 9, f.c + 6 + w, f.c + 15 + g * 2, f.c + 11 + g * 3 + w, "rgba(240,130,150,0.9)", 2);
    }
    f.dot(f.c + 9, f.c - 2 + w * 1.5, 1.5, "#131020");
    f.dot(f.c + 4, f.c + 4 + w * 1.5, 1.8, "rgba(255,220,228,0.8)"); // a happy cheek
  });
  var SPN = 10;
  var spark = u.bake(SPN, S, function (f) {           // the second sheet — a passenger
    for (var j = 0; j < 5; j++) {
      var p = (f.kl + j / 5) % 1;
      var a = Math.pow(Math.sin(p * Math.PI), 2);
      f.star(f.c + Math.cos(j * 2.4) * 18, f.c + Math.sin(j * 2.9) * 12 - p * 8,
        4 * a, 1.2 * a, 4, "rgba(245,241,220," + a + ")", p * 3);
    }
  });
  var burstT = -9, wantBurst = false;
  return {
    frame: function (dt, t) {
      if (wantBurst) { burstT = t; wantBurst = false; }
      u.scene();
      var P = 8;                                      // one full crossing = 8 s
      var ph = (t % P) / P;
      var tri = ph < 0.5 ? ph * 2 : 2 - ph * 2;       // there and back again
      var x = 34 + tri * (u.W - 68);
      var y = u.GY - 34 + Math.sin(t * 2) * 4;
      var dir = ph < 0.5 ? 1 : -1;
      u.ctx.save();                                   // face the way you swim
      if (dir < 0) { u.ctx.translate(x * 2, 0); u.ctx.scale(-1, 1); }
      u.blit(critter, Math.floor(t * FPS) % CN, x, y, 1.15);
      u.ctx.restore();
      // THE SYNC: the sparkle sheet borrows the swimmer's x, y, AND clock —
      // it lights for 0.6 s after each turn (and whenever you click)
      var since = Math.min(ph, Math.abs(ph - 0.5), 1 - ph) * P;
      if (since < 0.6 || t - burstT < 0.6)
        u.blit(spark, Math.floor(t * 16) % SPN, x, y - 4, 1.2, "add");
      u.strip(critter, Math.floor(t * FPS) % CN);
      u.label("two sheets, one clock: position AND timing are just shared variables", u.W / 2, u.H - 34, null, "center");
    },
    press: function () { wantBurst = true; }          // sparkles on demand, too
  };
});

def("B", "Beam", "scifi", "start → loop → end, three segments in ONE strip — the industry anatomy of a sustained effect", function make(u) {
  var NI = 6, NL = 8, NO = 6, N = NI + NL + NO, S = 96, FPS = 14;
  var Y = 48, X0 = 12, X1 = 86;
  var sheet = u.bake(N, S, function (f) {
    var i = f.i;
    if (i < NI) {                                     // START: gather + extend
      var p = i / (NI - 1);
      f.glow(X0, Y, 5 + p * 7, "rgba(138,217,245,", 0.5 + p * 0.5);
      f.streak(X0, Y, X0 + p * (X1 - X0), Y, "rgba(138,217,245," + p * 0.8 + ")", 1 + p * 2);
    } else if (i < NI + NL) {                         // LOOP: seamless pulse + ridges
      var q = (i - NI) / NL;
      var w = 3.4 + Math.sin(q * u.TAU) * 0.8;
      f.streak(X0, Y, X1, Y, "rgba(138,217,245,0.45)", w * 2.6);
      f.streak(X0, Y, X1, Y, "rgba(232,240,250,0.95)", w);
      for (var j = 0; j < 4; j++) {                   // travelling energy ridges
        var rp = (q + j / 4) % 1;
        f.glow(X0 + rp * (X1 - X0), Y, 6, "rgba(232,240,250,", 0.8 * (1 - rp * 0.3));
      }
      f.glow(X0, Y, 11, "rgba(138,217,245,", 0.9);
      f.glow(X1, Y, 8, "rgba(232,240,250,", 0.85);    // the hit point blooms
    } else {                                          // END: thin + break to motes
      var r = (i - NI - NL) / (NO - 1);
      f.streak(X0, Y, X1, Y, "rgba(138,217,245," + (1 - r) * 0.8 + ")", 3.4 * (1 - r) + 0.3);
      for (var m = 0; m < 6; m++)
        f.dot(X0 + (m / 5) * (X1 - X0), Y + (m % 2 ? -1 : 1) * r * 8,
          1.8 * (1 - r) + 0.2, "rgba(138,217,245," + (1 - r) + ")");
      f.glow(X0, Y, 8 * (1 - r), "rgba(138,217,245,", (1 - r) * 0.7);
    }
  });
  var mode = 0, m0 = 0, wantOut = false;              // 0 in · 1 loop · 2 out · 3 rest
  return {
    frame: function (dt, t) {
      if (wantOut && mode === 1) { mode = 2; m0 = t; wantOut = false; }
      var ts = t - m0, i;
      if (mode === 0 && ts * FPS >= NI) { mode = 1; m0 = t; ts = 0; }
      if (mode === 2 && ts * FPS >= NO + 0.5 * FPS) { mode = 3; m0 = t; ts = 0; }
      if (mode === 3 && ts > 0.9) { mode = 0; m0 = t; ts = 0; }
      if (mode === 0) i = Math.min(NI - 1, Math.floor(ts * FPS));
      else if (mode === 1) i = NI + Math.floor(ts * FPS) % NL;
      else if (mode === 2) i = NI + NL + Math.min(NO - 1, Math.floor(ts * FPS));
      else i = N - 1;
      u.scene(); u.mote(u.W * 0.82, u.GY - 12);
      u.blit(sheet, i, u.W * 0.45, u.GY - 40, 1.7, "add");
      u.strip(sheet, i);
      u.label("watch the read head: intro once, loop while held, outro on click", u.W / 2, u.H - 34, null, "center");
    },
    press: function () { wantOut = true; }            // click = release the trigger
  };
});

def("C", "Chargeup", "fantasy", "motes fall INWARD and the core brightens — a burst with the film run backwards", function make(u) {
  var N = 12, S = 96, FPS = 16;
  var R = u.rng(211);
  var motes = [];
  for (var j = 0; j < 10; j++)
    motes.push({ a: R() * u.TAU, r0: 26 + R() * 14, off: R() * 0.3 });
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    for (var j = 0; j < motes.length; j++) {
      var m = motes[j];
      var p = u.clamp((k - m.off) / (1 - m.off), 0, 1);
      var r = m.r0 * (1 - p);                         // anticipation = convergence
      if (r < 2) continue;
      var a = m.a + p * 1.6;
      f.dot(f.c + Math.cos(a) * r, f.c + Math.sin(a) * r, 1.6 + p, "rgba(201,160,245," + (0.4 + p * 0.6) + ")");
    }
    f.glow(f.c, f.c, 4 + k * 13, "rgba(201,160,245,", 0.3 + k * 0.7);
    if (k > 0.85) f.star(f.c, f.c, 12, 4, 4, "rgba(245,241,220," + (k - 0.85) / 0.15 + ")", 0.3);
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Burst's arithmetic with (1−p) where p was — reverse the radius, get anticipation", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("D", "Dash", "arcade", "smear frames: the middle of the strip is one long stretched drawing, not a blur filter", function make(u) {
  var N = 10, S = 96, FPS = 22;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var x0 = 16, x1 = f.S - 18;
    var x = x0 + u.ease(k) * (x1 - x0);
    if (k > 0.2 && k < 0.7) {                         // THE SMEAR: body becomes a streak
      var st = x0 + u.ease(Math.max(0, k - 0.25)) * (x1 - x0);
      f.streak(st, f.c, x, f.c, "rgba(138,217,245,0.55)", 12);
      f.streak(st, f.c, x, f.c, "rgba(232,240,250,0.8)", 5);
    } else if (k >= 0.7) {
      f.dot(x1, f.c, 8, "rgba(138,217,245,0.95)");    // arrived, whole again
      f.dot(x1 + 2.5, f.c - 2.5, 1.8, "#131020");
      var q = (k - 0.7) / 0.3;
      for (var s = 0; s < 3; s++)                     // settling speed ticks
        f.streak(x1 - 14 - s * 6, f.c - 6 + s * 6, x1 - 20 - s * 6 - q * 6, f.c - 6 + s * 6,
          "rgba(232,240,250," + (1 - q) * 0.6 + ")", 1.5);
    } else {
      f.dot(x, f.c, 8, "rgba(138,217,245,0.95)");     // wind-up
      f.dot(x + 2.5, f.c - 2.5, 1.8, "#131020");
    }
  });
  var px = u.W * 0.5, py = u.GY - 30, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.1) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("hand-drawn animation's oldest cheat, sitting plainly in the filmstrip", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("E", "Explosion", "arcade", "TWO sheets, one event: an additive fireball under a source-over smoke ring", function make(u) {
  var N = 12, S = 96, FPS = 16;
  var fire = u.bake(N, S, function (f) {
    var k = f.k;
    if (k > 0.7) return;
    var p = k / 0.7;
    f.glow(f.c, f.c, 10 + p * 22, "rgba(245,138,90,", (1 - p) * 0.9);
    f.glow(f.c, f.c - p * 6, 7 + p * 12, "rgba(245,193,105,", (1 - p));
    if (p < 0.3) f.glow(f.c, f.c, 14 * (1 - p / 0.3), "rgba(245,241,220,", 0.95);
    for (var j = 0; j < 6; j++) {
      var a = (j / 6) * u.TAU + 0.5;
      f.dot(f.c + Math.cos(a) * p * 30, f.c + Math.sin(a) * p * 26 - p * 4,
        2.2 * (1 - p), "rgba(245,161,90," + (1 - p) + ")");
    }
  });
  var smoke = u.bake(N, S, function (f) {
    var k = f.k;
    var p = u.clamp((k - 0.25) / 0.75, 0, 1);         // the smoke arrives late
    if (p <= 0) return;
    for (var j = 0; j < 7; j++) {
      var a = (j / 7) * u.TAU + 0.2;
      var d = 8 + p * 24;
      f.dot(f.c + Math.cos(a) * d, f.c + Math.sin(a) * d * 0.8 - p * 8,
        (5 + j % 3 * 2) * (0.5 + p * 0.8), "rgba(120,112,125," + (1 - p) * 0.55 + ")");
    }
  });
  var px = u.W * 0.5, py = u.GY - 36, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.3) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5 + 38, u.GY - 12);
      u.blit(smoke, i, px, py, 1.7);                  // matter first,
      u.blit(fire, i, px, py, 1.7, "add");            // light on top
      u.strip(fire, i);
      u.label("real explosions ship as layers — each sheet keeps its own blend", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("F", "Fireworks", "arcade", "a rocket, then a burst whose sparks droop and twinkle — three staggered children in one strip", function make(u) {
  var N = 16, S = 96, FPS = 15;
  var R = u.rng(223);
  var sparks = [];
  for (var j = 0; j < 14; j++)
    sparks.push({ a: (j / 14) * u.TAU + R() * 0.3, sp: 0.7 + R() * 0.5, tw: R() });
  var AX = 48, AY = 26;                               // the apex
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    if (k < 0.3) {                                    // child 1: the rocket
      var p = k / 0.3;
      var y = f.S - 10 - p * (f.S - 10 - AY);
      f.streak(AX - 2, y + 4, AX - 2 + Math.sin(p * 9) * 1.5, y + 12, "rgba(245,193,105,0.8)", 2);
      f.dot(AX, y, 2.2, "rgba(245,241,220,0.95)");
    } else if (k < 0.45) {                            // child 2: the flash
      f.glow(AX, AY, 14 * (1 - (k - 0.3) / 0.15 * 0.4), "rgba(245,241,220,", 0.95);
    }
    if (k >= 0.38) {                                  // child 3: the bloom
      var q = (k - 0.38) / 0.62;
      for (var j2 = 0; j2 < sparks.length; j2++) {
        var s = sparks[j2];
        var d = 30 * s.sp * Math.pow(q, 0.6);
        var x = AX + Math.cos(s.a) * d;
        var y2 = AY + Math.sin(s.a) * d * 0.9 + q * q * 16;      // gravity droops
        var tw = q > 0.5 ? Math.pow(0.5 + 0.5 * Math.sin(q * 40 + s.tw * 9), 2) : 1;
        f.dot(x, y2, 1.7 * (1 - q * 0.7), "rgba(245,138,160," + (1 - q) * tw + ")");
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 44, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.4) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.7, "add");
      u.strip(sheet, i);
      u.label("Xslash staggered two timelines; this strip conducts three", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("G", "Glitch", "scifi", "frames own their own clocks: long calm holds, then 60-millisecond corruption", function make(u) {
  var N = 8, S = 96;
  var DUR = [0.55, 0.5, 0.06, 0.09, 0.45, 0.06, 0.08, 0.5];   // seconds PER FRAME
  var TOTAL = DUR.reduce(function (a, b) { return a + b; }, 0);
  function glyph(f, dx, dy, col) {                    // the "signal" being broken
    f.ring(f.c + dx, f.c + dy, 16, col, 3);
    f.streak(f.c - 8 + dx, f.c + 6 + dy, f.c + 8 + dx, f.c + 6 + dy, col, 3);
    f.dot(f.c - 6 + dx, f.c - 4 + dy, 2.5, col);
    f.dot(f.c + 6 + dx, f.c - 4 + dy, 2.5, col);
  }
  var sheet = u.bake(N, S, function (f) {
    var R = u.rng(700 + f.i);
    if (f.i === 2) {                                  // RGB split
      glyph(f, -3, 0, "rgba(245,90,120,0.8)");
      glyph(f, 3, 0, "rgba(90,245,230,0.8)");
      glyph(f, 0, 0, "rgba(232,229,244,0.9)");
    } else if (f.i === 3) {                           // sliced + shoved
      glyph(f, 0, 0, "rgba(232,229,244,0.9)");
      for (var s = 0; s < 3; s++) {
        var y = 20 + R() * 56, h = 4 + R() * 6;
        f.g.save();
        f.g.beginPath(); f.g.rect(0, y, f.S, h); f.g.clip();
        f.g.translate((R() - 0.5) * 18, 0);
        glyph(f, 0, 0, "rgba(138,217,245,0.9)");
        f.g.restore();
      }
    } else if (f.i === 5) {                           // negative flash
      f.g.fillStyle = "rgba(232,229,244,0.85)";
      f.g.fillRect(8, 8, f.S - 16, f.S - 16);
      glyph(f, 0, 0, "rgba(19,16,32,0.95)");
    } else if (f.i === 6) {                           // whole-frame shove + static
      glyph(f, 6, -3, "rgba(232,229,244,0.8)");
      for (var d = 0; d < 40; d++)
        f.dot(R() * f.S, R() * f.S, 0.8, "rgba(232,229,244," + R() * 0.5 + ")");
    } else {                                          // the calm frames
      glyph(f, 0, 0, "rgba(232,229,244,0.9)");
    }
  });
  var px = u.W * 0.5, py = u.GY - 38;
  return {
    frame: function (dt, t) {
      var tt = t % TOTAL, i = 0;                      // scan the uneven clocks
      while (i < N - 1 && tt >= DUR[i]) { tt -= DUR[i]; i++; }
      u.scene();
      u.blit(sheet, i, px, py, 1.5);
      u.strip(sheet, i);
      u.label("a DUR[] array instead of one fps — the strip's cells are not equal anymore", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("H", "Hologram", "scifi", "scanlines + flicker + a rolling band — solid art wearing a broken-projector costume", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var R = u.rng(730 + f.i);
    var flick = R() < 0.15 ? 0.35 : 1;                // occasional dropout
    var a = (0.55 + Math.sin(f.kl * u.TAU) * 0.1) * flick;
    var wob = (R() - 0.5) * 1.5;
    f.dot(f.c + wob, f.c - 6, 11, "rgba(120,220,245," + a * 0.6 + ")");   // the figure
    f.dot(f.c + wob, f.c + 9, 8, "rgba(120,220,245," + a * 0.5 + ")");
    f.dot(f.c + wob - 4, f.c - 8, 1.6, "rgba(230,250,255," + a + ")");
    f.dot(f.c + wob + 4, f.c - 8, 1.6, "rgba(230,250,255," + a + ")");
    f.g.globalAlpha = a * 0.5;
    f.g.strokeStyle = "rgba(19,16,32,0.9)";           // the scanlines
    f.g.lineWidth = 1;
    f.g.beginPath();
    for (var y = 24; y < f.S - 16; y += 3) { f.g.moveTo(f.c - 16, y); f.g.lineTo(f.c + 16, y); }
    f.g.stroke();
    f.g.globalAlpha = 1;
    var band = 22 + f.kl * 44;                        // the rolling bright band
    f.streak(f.c - 15, band, f.c + 15, band, "rgba(230,250,255," + a * 0.7 + ")", 2.5);
    f.wedge(f.c, f.S - 10, -u.TAU / 4, 30, 0.45, "rgba(120,220,245," + a * 0.15 + ")");   // projector cone
    f.dot(f.c, f.S - 9, 2.5, "rgba(230,250,255," + a + ")");
  });
  var px = u.W * 0.5, py = u.GY - 36;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Zap's per-frame dice, rolled for dropouts instead of arcs", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("I", "Itemget", "arcade", "the treasure lift: a gem rises, spins by x-scale, and announces itself with rays", function make(u) {
  var N = 14, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var y = f.S - 24 - u.ease(Math.min(1, k / 0.5)) * 30;
    var spin = Math.cos(k * u.TAU * 2);               // fake 3D: |cos| as width
    var wpx = Math.max(0.15, Math.abs(spin)) * 10;
    var col = spin > 0 ? "rgba(138,217,245,0.95)" : "rgba(100,180,220,0.95)";
    f.poly([[f.c - wpx, y], [f.c, y - 12], [f.c + wpx, y], [f.c, y + 12]], col);
    f.dot(f.c - wpx * 0.3, y - 4, 1.6, "rgba(245,251,255,0.9)");
    if (k > 0.4) {                                    // the announcement
      var q = (k - 0.4) / 0.6;
      for (var j = 0; j < 6; j++) {
        var a = (j / 6) * u.TAU - u.TAU / 4;
        var d0 = 16 + q * 10, d1 = d0 + 7 * Math.sin(q * Math.PI);
        f.streak(f.c + Math.cos(a) * d0, y + Math.sin(a) * d0,
          f.c + Math.cos(a) * d1, y + Math.sin(a) * d1, "rgba(245,241,220," + Math.sin(q * Math.PI) * 0.9 + ")", 1.8);
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 40, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.3) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.5, "add");
      u.strip(sheet, i);
      u.label("Leaves' y-flip trick turned sideways: |cos| width = a spinning gem", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("J", "Jackpot", "arcade", "three reels stop one after another — staggered clocks, then the payout flash", function make(u) {
  var N = 16, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var stops = [0.35, 0.55, 0.75];
    var win = k > 0.8;
    for (var w = 0; w < 3; w++) {
      var x = f.c + (w - 1) * 22;
      f.g.strokeStyle = "rgba(201,196,228,0.7)";
      f.g.lineWidth = 1.5;
      f.g.strokeRect(x - 9, f.c - 12, 18, 24);
      if (k < stops[w]) {                             // still spinning: blurred symbols
        for (var s = 0; s < 3; s++)
          f.streak(x - 5, f.c - 8 + ((f.i * 7 + s * 8 + w * 5) % 22), x + 5, f.c - 8 + ((f.i * 7 + s * 8 + w * 5) % 22),
            "rgba(232,229,244,0.5)", 2.5);
      } else {                                        // stopped: the star lands
        f.star(x, f.c, 6.5, 2.6, 5, "rgba(245,193,105," + (win ? 1 : 0.85) + ")", 0.3);
        if (k - stops[w] < 0.08)                      // the little settle blink
          f.ring(x, f.c, 10, "rgba(245,241,220,0.8)", 1.5);
      }
    }
    if (win) {                                        // JACKPOT: rim bulbs
      var q = (k - 0.8) / 0.2;
      for (var b = 0; b < 10; b++) {
        var on = (b + f.i) % 2 === 0;
        f.dot(14 + b * 7.5, 20, on ? 2.2 : 1.2, "rgba(245,193,105," + (on ? 0.95 : 0.4) + ")");
        f.dot(14 + b * 7.5, f.S - 18, on ? 2.2 : 1.2, "rgba(245,193,105," + (on ? 0.95 : 0.4) + ")");
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 40, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.5) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("three sub-clocks stopping in sequence — suspense is a stagger", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("K", "Kettle", "cozy", "steam curls from the spout on offset clocks; every few laps, the whistle lines shiver", function make(u) {
  var N = 16, S = 96, FPS = 10;
  var R = u.rng(233);
  var puffs = [];
  for (var j = 0; j < 5; j++) puffs.push({ off: R(), amp: 2 + R() * 3 });
  var sheet = u.bake(N, S, function (f) {
    var bx = f.c - 4, by = f.S - 26;                  // the kettle body
    f.dot(bx, by, 15, "rgba(180,175,195,0.9)");
    f.g.fillStyle = "rgba(180,175,195,0.9)";
    f.g.fillRect(bx - 5, by - 21, 10, 6);             // the lid
    f.dot(bx, by - 22, 2.5, "rgba(140,135,155,0.9)");
    f.streak(bx + 13, by - 6, bx + 22, by - 12, "rgba(180,175,195,0.9)", 5);   // the spout
    var sx = bx + 23, sy = by - 13;
    for (var j2 = 0; j2 < puffs.length; j2++) {       // the steam
      var p = (f.kl + puffs[j2].off) % 1;
      var y = sy - p * 34;
      var x = sx + Math.sin(p * u.TAU * 1.5 + j2 * 2) * puffs[j2].amp + p * 4;
      f.dot(x, y, 2 + p * 3, "rgba(232,235,244," + Math.sin(p * Math.PI) * 0.4 + ")");
    }
    if (f.i % 8 < 2)                                  // the periodic whistle
      for (var s = 0; s < 2; s++)
        f.streak(sx + 4 + s * 4, sy - 4 - s * 3, sx + 8 + s * 4, sy - 8 - s * 3, "rgba(245,241,220,0.7)", 1.4);
  });
  var px = u.W * 0.5, py = u.GY - 34;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Updraft's rig, domesticated — 10 fps is kitchen tempo", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("L", "Levelup", "arcade", "a column of light sweeps up carrying chevrons — the ceremony every RPG owes its players", function make(u) {
  var N = 14, S = 96, FPS = 16;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var a = k < 0.15 ? k / 0.15 : (k > 0.75 ? (1 - k) / 0.25 : 1);
    f.g.save();
    var grad = f.g.createLinearGradient(0, f.S, 0, 0);
    grad.addColorStop(0, "rgba(245,193,105," + a * 0.35 + ")");
    grad.addColorStop(1, "rgba(245,193,105,0)");
    f.g.fillStyle = grad;
    f.g.fillRect(f.c - 13, 6, 26, f.S - 16);          // the column
    f.g.restore();
    for (var j = 0; j < 3; j++) {                     // rising chevrons
      var p = (k * 1.4 + j / 3) % 1;
      var y = f.S - 14 - p * (f.S - 26);
      var al = Math.sin(p * Math.PI) * a;
      f.streak(f.c - 8, y + 5, f.c, y - 2, "rgba(245,220,150," + al + ")", 2.5);
      f.streak(f.c, y - 2, f.c + 8, y + 5, "rgba(245,220,150," + al + ")", 2.5);
    }
    for (var s = 0; s < 4; s++) {                     // stray celebration stars
      var sp = (k * 1.2 + s / 4) % 1;
      f.star(f.c + (s % 2 ? 16 : -16), f.S - 16 - sp * 50, 3 * Math.sin(sp * Math.PI) * a,
        1 * Math.sin(sp * Math.PI), 4, "rgba(245,241,220," + Math.sin(sp * Math.PI) * a + ")", sp * 3);
    }
  });
  var px = u.W * 0.5, py = u.GY - 40, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Heal's rise + Yell's ceremony, aimed straight up", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; t0 = -9; }
  };
});

def("M", "Mist", "fantasy", "three fog banks drift at three speeds — the parallax whisper, baked flat", function make(u) {
  var N = 16, S = 96, FPS = 10;
  var sheet = u.bake(N, S, function (f) {
    var layers = [[0.5, 62, 0.28, 9], [1, 52, 0.22, 12], [1.6, 42, 0.16, 15]];
    for (var L = 0; L < layers.length; L++) {
      var lay = layers[L];
      for (var b = 0; b < 3; b++) {
        var p = (f.kl * lay[0] + b / 3) % 1;          // integer speed multiples loop
        var x = p * (f.S + 40) - 20;
        var a = Math.sin(p * Math.PI) * lay[2];
        f.dot(x, lay[1] + Math.sin(b * 3 + L) * 4, lay[3], "rgba(200,200,220," + a + ")");
        f.dot(x + 10, lay[1] + 3, lay[3] * 0.7, "rgba(200,200,220," + a * 0.8 + ")");
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 26;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.9);
      u.strip(sheet, i);
      u.label("near drifts fast, far drifts slow — chapter 4's parallax in one texture", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("N", "Neon", "scifi", "a sign buzzes awake: dark, sputter, half-lit, ON — then holds its hum", function make(u) {
  var N = 14, S = 96, FPS = 12;
  function tube(f, a, hum) {                          // the tube: a rounded zigzag
    var pts = [[20, 60], [34, 34], [48, 60], [62, 34], [76, 60]];
    f.g.strokeStyle = "rgba(245,110,180," + a * 0.35 + ")";
    f.g.lineWidth = 7;
    f.g.lineJoin = "round"; f.g.lineCap = "round";
    f.g.beginPath();
    for (var j = 0; j < pts.length; j++) j ? f.g.lineTo(pts[j][0], pts[j][1]) : f.g.moveTo(pts[j][0], pts[j][1]);
    f.g.stroke();
    f.g.strokeStyle = "rgba(255,190,225," + a + ")";
    f.g.lineWidth = 2.5;
    f.g.stroke();
    f.g.lineCap = "butt";
    if (hum) f.ring(48, 47, 34 + Math.sin(hum) * 1.5, "rgba(245,110,180," + a * 0.15 + ")", 8);
  }
  var sheet = u.bake(N, S, function (f) {
    var R = u.rng(760 + f.i);
    var i = f.i;
    if (i === 0) tube(f, 0.08, 0);
    else if (i === 1) tube(f, R() * 0.7, 0);          // sputter
    else if (i === 2) tube(f, 0.1, 0);
    else if (i === 3) tube(f, R() * 0.9, 0);          // sputter harder
    else if (i === 4) tube(f, 0.55, 0);               // half-lit
    else tube(f, 0.92 + Math.sin(f.kl * u.TAU * 2) * 0.06, f.kl * u.TAU);  // ON, humming
  });
  var px = u.W * 0.5, py = u.GY - 42;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("the loop hides its own intro: frames 0-4 buzz, the rest hum", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("O", "Oldfilm", "scifi", "grain re-rolled per frame, a wandering scratch, and the whole image jittering in the gate", function make(u) {
  var N = 12, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    var R = u.rng(790 + f.i);
    var jx = (R() - 0.5) * 2, jy = (R() - 0.5) * 1.5; // gate weave
    f.dot(f.c + jx, f.c + jy - 4, 12, "rgba(216,210,190,0.85)");    // the "footage":
    f.dot(f.c + jx, f.c + jy + 12, 8, "rgba(216,210,190,0.75)");    // a pale figure
    f.dot(f.c + jx - 4, f.c + jy - 6, 1.6, "rgba(40,36,30,0.9)");
    f.dot(f.c + jx + 4, f.c + jy - 6, 1.6, "rgba(40,36,30,0.9)");
    for (var g = 0; g < 26; g++)                      // the grain, never the same
      f.dot(R() * f.S, R() * f.S, 0.7, "rgba(30,26,22," + R() * 0.5 + ")");
    if (R() < 0.4) {                                  // the scratch
      var x = 14 + R() * 68;
      f.streak(x, 6, x + (R() - 0.5) * 4, f.S - 6, "rgba(30,26,22,0.5)", 1);
    }
    f.ring(f.c, f.c, 43, "rgba(20,17,14,0.5)", 14);   // vignette corners
  });
  var px = u.W * 0.5, py = u.GY - 36;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Lightning's lesson wearing sepia: age is chaos re-rolled per frame", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("P", "Pixelate", "scifi", "the mosaic transition: the same face at 4-, 8-, 16-pixel chunks and back", function make(u) {
  var N = 12, S = 96, FPS = 12;
  function face(px2, py2) {                           // the source, as a function
    var d = Math.sqrt((px2 - 0.5) * (px2 - 0.5) + (py2 - 0.42) * (py2 - 0.42));
    if (d > 0.32) return null;
    if ((Math.abs(px2 - 0.38) < 0.05 && Math.abs(py2 - 0.36) < 0.05) ||
        (Math.abs(px2 - 0.62) < 0.05 && Math.abs(py2 - 0.36) < 0.05)) return [19, 16, 32];
    if (py2 > 0.5 && py2 < 0.56 && px2 > 0.4 && px2 < 0.6) return [19, 16, 32];
    return [138, 217, 245];
  }
  var sheet = u.bake(N, S, function (f) {
    var lvl = 0.5 - 0.5 * Math.cos(f.kl * u.TAU);     // 0 sharp → 1 chunky → 0
    var cell = Math.max(2, Math.round(2 + lvl * 14)); // the chunk size
    for (var y = 8; y < f.S - 8; y += cell)
      for (var x = 8; x < f.S - 8; x += cell) {
        var s = face((x + cell / 2 - 8) / (f.S - 16), (y + cell / 2 - 8) / (f.S - 16));
        if (!s) continue;
        f.g.fillStyle = "rgba(" + s[0] + "," + s[1] + "," + s[2] + ",0.95)";
        f.g.fillRect(x, y, cell - 0.5, cell - 0.5);
      }
  });
  var px = u.W * 0.5, py = u.GY - 38;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.5);
      u.strip(sheet, i);
      u.label("sample the SAME picture at a coarser grid — resolution as an animation dial", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("Q", "Quicksand", "fantasy", "a slow spiral of sand dashes, and something important sinking into it", function make(u) {
  var N = 14, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var cy = f.c + 10;
    for (var ring2 = 0; ring2 < 3; ring2++) {         // the swirl: dashed ellipses
      var rr = 26 - ring2 * 7;
      for (var dsh = 0; dsh < 8; dsh++) {
        var a = f.kl * u.TAU * (1 + ring2 * 0.5) + (dsh / 8) * u.TAU;
        f.streak(f.c + Math.cos(a) * rr, cy + Math.sin(a) * rr * 0.32,
          f.c + Math.cos(a + 0.3) * rr, cy + Math.sin(a + 0.3) * rr * 0.32,
          "rgba(214,190,130," + (0.6 - ring2 * 0.12) + ")", 2);
      }
    }
    var sink = u.ease(k) * 14;                        // the sinking crate
    f.g.save();
    f.g.beginPath(); f.g.rect(0, 0, f.S, cy + 2); f.g.clip();      // below = swallowed
    f.g.fillStyle = "rgba(184,148,95,0.95)";
    f.g.fillRect(f.c - 8, cy - 16 + sink, 16, 16);
    f.g.strokeStyle = "rgba(120,92,55,0.9)";
    f.g.strokeRect(f.c - 8, cy - 16 + sink, 16, 16);
    f.g.restore();
    if (f.i % 4 === 0)                                // a struggling bubble
      f.ring(f.c + 12, cy - 2, 2.5, "rgba(214,190,130,0.7)", 1);
  });
  var px = u.W * 0.5, py = u.GY - 26, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.6) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5 + 38, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("a clip() region eats the crate — Vortex flattened into the ground plane", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; t0 = -9; }
  };
});

def("R", "Runner", "fantasy", "TWO clips in one atlas — a right-facing run and a left-facing run, switched at the edges", function make(u) {
  var NC = 8, N = 16, S = 96, FPS = 12;
  function drawRunner(f, flip) {                      // one gait frame, either facing
    var m = function (x) { return flip ? f.S - x : x; };
    var ph = (f.i % NC) / NC * u.TAU;
    var bob = Math.abs(Math.sin(ph)) * -3;
    f.dot(m(f.c), f.c + bob - 4, 8, "rgba(155,226,138,0.95)");
    f.dot(m(f.c + 3), f.c + bob - 6, 1.6, "#131020");
    for (var leg = 0; leg < 2; leg++) {               // two swinging legs
      var la = Math.sin(ph + leg * Math.PI) * 0.9;
      f.streak(m(f.c), f.c + bob + 3,
        m(f.c + Math.sin(la) * 9), f.c + 14 + Math.abs(Math.cos(la)) * 2,
        "rgba(155,226,138,0.9)", 3);
    }
    if (f.i % 2 === 0) f.dot(m(f.c - 12), f.c + 15, 2, "rgba(160,150,140,0.4)");  // heel dust
  }
  var sheet = u.bake(N, S, function (f) {
    drawRunner(f, f.i >= NC);                         // frames 0-7 face right, 8-15 left
  });
  var x = u.W * 0.3, dir = 1;
  return {
    frame: function (dt, t) {
      u.scene();
      x += dir * 46 * dt;
      if (x > u.W - 40) { dir = -1; x = u.W - 40; }   // the edge flips the CLIP,
      if (x < 40) { dir = 1; x = 40; }                // not the pixels
      var i = (dir > 0 ? 0 : NC) + Math.floor(t * FPS) % NC;
      u.blit(sheet, i, x, u.GY - 22, 1.4);
      u.strip(sheet, i);
      u.label("one texture, two animations — rows-as-clips is how real atlases work", u.W / 2, u.H - 34, null, "center");
    },
    press: function (px2) { dir = px2 > x ? 1 : -1; }
  };
});

def("S", "Shield", "arcade", "a hex barrier takes the hit: flash at the impact point, ripple across the dome", function make(u) {
  var N = 12, S = 96, FPS = 20;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var a = 1 - k * 0.6;
    f.g.strokeStyle = "rgba(138,217,245," + a * 0.7 + ")";
    f.g.lineWidth = 2;
    f.g.beginPath();                                  // the dome (a hex arc)
    for (var j = 0; j <= 6; j++) {
      var ang = Math.PI + (j / 6) * Math.PI;
      var wob = k < 0.3 ? Math.sin(k * 30 + j) * (0.3 - k) * 8 : 0;   // it shudders
      var x = f.c + Math.cos(ang) * (30 + wob), y = f.S - 18 + Math.sin(ang) * (30 + wob);
      j ? f.g.lineTo(x, y) : f.g.moveTo(x, y);
    }
    f.g.stroke();
    var hx = f.c + 21, hy = f.S - 18 - 21;            // the impact corner
    if (k < 0.35) f.glow(hx, hy, 12 * (1 - k / 0.35), "rgba(245,241,220,", 0.95);
    var rp = u.ease(k);                               // the ripple runs the rim
    var ra = Math.PI + rp * Math.PI;
    f.glow(f.c + Math.cos(ra) * 30, f.S - 18 + Math.sin(ra) * 30, 6, "rgba(138,217,245,", (1 - k) * 0.9);
  });
  var px = u.W * 0.5, py = u.GY - 24, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Impact's flash + Glint's traveller, bent around a dome", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; t0 = -9; }
  };
});

def("T", "Tempo", "cozy", "ONE sheet, three clocks: 6, 12, and 24 fps side by side — speed is a playback dial", function make(u) {
  var N = 12, S = 96;
  var sheet = u.bake(N, S, function (f) {             // a 4-blade pinwheel:
    var rot = f.kl * u.TAU / 4;                       // quarter-turn per lap = seamless
    for (var b = 0; b < 4; b++) {
      var a = rot + b * u.TAU / 4;
      f.wedge(f.c, f.c, a, 26, 0.35, ["rgba(245,138,138,0.9)", "rgba(245,193,105,0.9)", "rgba(155,226,138,0.9)", "rgba(138,217,245,0.9)"][b]);
    }
    f.dot(f.c, f.c, 4, "rgba(232,229,244,0.95)");
  });
  return {
    frame: function (dt, t) {
      u.scene();
      var speeds = [6, 12, 24];
      for (var s = 0; s < 3; s++) {
        var x = u.W * (0.2 + s * 0.3);
        u.blit(sheet, Math.floor(t * speeds[s]) % N, x, u.GY - 40, 1.05);
        u.label(speeds[s] + " fps", x, u.GY - 2, "rgba(245,193,105,0.9)", "center");
      }
      u.strip(sheet, Math.floor(t * 12) % N);
      u.label("smoothness lives in N (bake-time); speed lives in fps (play-time)", u.W / 2, u.H - 34, null, "center");
    },
    press: function () {}
  };
});

def("U", "UFO", "scifi", "a saucer bobs while its rim lights chase and the tractor beam breathes", function make(u) {
  var N = 16, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    var bob = Math.sin(f.kl * u.TAU) * 3;
    var cy = 30 + bob;
    var pulse = 0.5 + 0.5 * Math.sin(f.kl * u.TAU * 2);
    f.wedge(f.c, cy + 4, u.TAU / 4, 46, 0.32, "rgba(155,226,138," + (0.1 + pulse * 0.15) + ")");   // the beam
    f.g.fillStyle = "rgba(180,185,205,0.95)";
    f.g.beginPath();
    f.g.ellipse(f.c, cy, 22, 7, 0, 0, u.TAU);         // the hull
    f.g.fill();
    f.dot(f.c, cy - 6, 8, "rgba(138,217,245,0.55)");  // the dome
    for (var b2 = 0; b2 < 6; b2++) {                  // rim lights, chasing
      var on = (b2 + f.i) % 6 < 2;
      f.dot(f.c - 17 + b2 * 7, cy + 3, on ? 2.2 : 1.2, "rgba(245,193,105," + (on ? 0.95 : 0.35) + ")");
    }
    f.dot(f.c + Math.sin(f.kl * u.TAU) * 4, cy + 34, 3, "rgba(155,226,138," + pulse * 0.7 + ")");  // the abductee-to-be
  });
  var px = u.W * 0.5, py = u.GY - 44;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("three clocks in one loop: bob ×1, pulse ×2, lights stepping — all on kl", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("V", "Vapor", "scifi", "concentric blobs breathing through a colour cycle — the trippy shelf's slow exhale", function make(u) {
  var N = 16, S = 96, FPS = 10;
  var cols = ["245,110,180", "201,160,245", "138,217,245", "155,226,138", "245,193,105"];
  var sheet = u.bake(N, S, function (f) {
    for (var ring2 = 4; ring2 >= 0; ring2--) {
      var p = (f.kl + ring2 / 5) % 1;
      var r = 6 + p * 34;
      var col = cols[(ring2 + Math.floor(f.kl * 5)) % 5];        // the hue walks
      var a = Math.sin(p * Math.PI) * 0.4;
      f.g.strokeStyle = "rgba(" + col + "," + a + ")";
      f.g.lineWidth = 5;
      f.g.beginPath();
      for (var j = 0; j <= 30; j++) {                 // blobby, not perfect
        var ang = (j / 30) * u.TAU;
        var rr = r + Math.sin(ang * 3 + p * 6) * r * 0.12;
        var x = f.c + Math.cos(ang) * rr, y = f.c + Math.sin(ang) * rr;
        j ? f.g.lineTo(x, y) : f.g.moveTo(x, y);
      }
      f.g.closePath(); f.g.stroke();
    }
  });
  var px = u.W * 0.5, py = u.GY - 38;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Ripple's phase offsets + a palette that rotates one slot per lap", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("W", "Waddle", "goofy", "the THIRD index line: i bounces off the ends, so 6 frames play as 10 — and the walk goes with it", function make(u) {
  var NC = 6, S = 96, FPS = 8;
  var sheet = u.bake(NC, S, function (f) {            // a penguin mid-waddle,
    var lean = (f.i / (NC - 1) - 0.5) * 0.5;          // leaning further per frame
    f.g.save();
    f.g.translate(f.c, f.S - 30);
    f.g.rotate(lean);
    f.g.fillStyle = "rgba(40,44,66,0.95)";
    f.g.beginPath(); f.g.ellipse(0, 0, 13, 17, 0, 0, u.TAU); f.g.fill();
    f.g.fillStyle = "rgba(232,235,244,0.95)";
    f.g.beginPath(); f.g.ellipse(0, 4, 8, 11, 0, 0, u.TAU); f.g.fill();
    f.dot(-3.5, -9, 1.6, "#E8E5F4"); f.dot(3.5, -9, 1.6, "#E8E5F4");
    f.dot(-3.5, -9, 0.8, "#131020"); f.dot(3.5, -9, 0.8, "#131020");
    f.wedge(0, -5, u.TAU / 4, 6, 0.5, "rgba(245,161,90,0.95)");
    f.g.restore();
    var lift = Math.abs(f.i / (NC - 1) - 0.5) * 2;    // the off foot lifts
    f.dot(f.c - 6, f.S - 12 - (1 - lift) * 3, 3, "rgba(245,161,90,0.95)");
    f.dot(f.c + 6, f.S - 12 - lift * 3, 3, "rgba(245,161,90,0.95)");
  });
  var born = null;
  return {
    frame: function (dt, t) {
      u.scene();
      var p = Math.floor(t * FPS) % (2 * NC - 2);     // ← the ping-pong line
      var i = p < NC ? p : 2 * NC - 2 - p;
      var span = u.W - 80;
      var wp = (t * 26) % (span * 2);                 // the path ping-pongs too
      var x = 40 + (wp < span ? wp : span * 2 - wp);
      u.blit(sheet, i, x, u.GY - 26, 1.35);
      u.strip(sheet, i);
      u.label("i = p < N ? p : 2N−2−p — no reversed copy of the sheet needed", u.W / 2, u.H - 34, null, "center");
    },
    press: function () {}
  };
});

def("X", "Xylophone", "goofy", "five bars light in sequence, each hit popping its own note — a melody as a stagger", function make(u) {
  var N = 15, S = 96, FPS = 12;
  var order = [0, 2, 4, 3, 1];                        // the little tune
  var sheet = u.bake(N, S, function (f) {
    var step = Math.floor(f.kl * 5);                  // which bar is being struck
    var within = (f.kl * 5) % 1;
    for (var b = 0; b < 5; b++) {
      var x = 16 + b * 16;
      var hot = order[step] === b;
      var h = 34 - b * 4;
      f.g.fillStyle = hot ? "rgba(245,193,105," + (1 - within * 0.5) + ")" :
        "rgba(" + [138, 155, 201, 245, 245][b] + "," + [217, 226, 160, 193, 138][b] + "," + [245, 138, 245, 105, 138][b] + ",0.8)";
      f.g.fillRect(x - 6, f.c + 8 - h / 2, 12, h);
      if (hot && within < 0.5) {                      // the note pops off the bar
        var ny = f.c - h / 2 - within * 16;
        f.dot(x, ny, 2.4, "rgba(232,229,244," + (1 - within * 2) + ")");
        f.streak(x + 2, ny, x + 2, ny - 7, "rgba(232,229,244," + (1 - within * 2) + ")", 1.3);
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 34;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Jackpot's stagger playing music — an order[] array is a melody", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("Y", "Yarn", "cozy", "a yarn ball rocks, its loose thread wiggles — and every few seconds, a paw", function make(u) {
  var N = 16, S = 96, FPS = 11;
  var sheet = u.bake(N, S, function (f) {
    var rock = Math.sin(f.kl * u.TAU) * 0.18;
    var bx = f.c, by = f.S - 26;
    f.g.save();
    f.g.translate(bx, by);
    f.g.rotate(rock);
    f.dot(0, 0, 14, "rgba(245,138,160,0.95)");        // the ball
    for (var w = 0; w < 3; w++)                       // the windings
      f.ring(0, 0, 13 - w * 1.5, "rgba(220,110,135,0.7)", 1.2);
    f.g.restore();
    f.g.strokeStyle = "rgba(245,138,160,0.85)";       // the loose thread
    f.g.lineWidth = 1.5;
    f.g.beginPath();
    f.g.moveTo(bx + 12, by + 6);
    for (var s2 = 1; s2 <= 6; s2++)
      f.g.lineTo(bx + 12 + s2 * 5, by + 8 + Math.sin(f.kl * u.TAU * 2 + s2) * 3);
    f.g.stroke();
    if (f.i >= 11 && f.i <= 13) {                     // the paw, on schedule
      var pp = (f.i - 11) / 2;
      var reach = Math.sin(pp * Math.PI);
      f.dot(bx - 22 + reach * 9, by - 10 - reach * 4, 5.5, "rgba(232,229,244,0.95)");
      for (var toe = 0; toe < 3; toe++)
        f.dot(bx - 25 + reach * 9 + toe * 3, by - 15 - reach * 4, 1.4, "rgba(200,196,215,0.9)");
    }
  });
  var px = u.W * 0.5, py = u.GY - 30;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Kettle's whistle trick: a guest that only exists in frames 11-13", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("Z", "Zoom", "arcade", "speedlines converge on the middle while the subject swells — the camera never moved", function make(u) {
  var N = 10, S = 96, FPS = 20;
  var R = u.rng(251);
  var lines = [];
  for (var j = 0; j < 14; j++) lines.push({ a: R() * u.TAU, off: R() });
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    for (var j2 = 0; j2 < lines.length; j2++) {       // the converging streaks
      var L = lines[j2];
      var p = (k * 2 + L.off) % 1;
      var d0 = 46 - p * 26, d1 = d0 - 8 - p * 6;
      f.streak(f.c + Math.cos(L.a) * d0, f.c + Math.sin(L.a) * d0,
        f.c + Math.cos(L.a) * d1, f.c + Math.sin(L.a) * d1,
        "rgba(232,229,244," + (0.25 + p * 0.5) + ")", 1.5);
    }
    var sc = 1 + u.ease(k) * 0.9;                     // the subject swells
    f.dot(f.c, f.c, 8 * sc, "rgba(138,217,245,0.95)");
    f.dot(f.c + 2.5 * sc, f.c - 2.5 * sc, 1.8 * sc, "#131020");
    if (k > 0.8) f.ring(f.c, f.c, 8 * sc + 4, "rgba(245,241,220," + (k - 0.8) * 4 + ")", 2);
  });
  var px = u.W * 0.5, py = u.GY - 36, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.1) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("cheap perspective, exhibit one: lines toward a point + scale = a lens", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

/* ---- lap four ---- */

def("A", "Anticipation", "arcade", "crouch, HOLD, launch — the hold is just the same drawing baked three times", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var i = f.i, base = f.S - 18;
    function guy(y, sx, sy, dust) {
      f.g.save();
      f.g.translate(f.c, base - 9 * sy - y);
      f.g.scale(sx, sy);
      f.dot(0, 0, 9, "rgba(138,217,245,0.95)");
      f.dot(3, -3, 1.8, "#131020");
      f.g.restore();
      if (dust) for (var d = 0; d < 3; d++)
        f.dot(f.c - 10 + d * 10, base + 3, 2.5 * dust, "rgba(160,150,140," + dust * 0.4 + ")");
    }
    if (i < 2) guy(0, 1, 1, 0);                       // standing
    else if (i < 6) guy(0, 1.25, 0.7, 0);             // THE HOLD: 4 identical crouches
    else if (i < 10) {                                // launch, stretched
      var q = (i - 6) / 3;
      guy(q * 40, 0.75, 1.35, 1 - q);
    } else guy(44, 1, 1, 0);                          // gone off the top
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("count the identical strip cells — 'on threes' is Glitch's DUR[] spelled in copies", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; t0 = -9; }
  };
});

def("B", "Bounceball", "goofy", "the ball arcs, the SHADOW stays on the floor and shrinks with height — that's the whole 3D", function make(u) {
  var N = 14, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var kl = f.kl, base = f.S - 14;
    var hop = Math.abs(Math.sin(kl * u.TAU));         // two bounces per lap
    var x = 16 + kl * (f.S - 32);
    var h = hop * 34;
    var squash = h < 4 ? 0.6 : 1;                     // flat at the floor
    f.g.beginPath();                                  // the shadow: height's witness
    f.g.ellipse(x, base + 3, 8 * (1 - h / 50), 2.6 * (1 - h / 50), 0, 0, u.TAU);
    f.g.fillStyle = "rgba(19,16,32," + (0.45 - h / 120) + ")";
    f.g.fill();
    f.g.save();
    f.g.translate(x, base - 6 - h);
    f.g.scale(1 / squash, squash);
    f.dot(0, 0, 7, "rgba(245,138,138,0.95)");
    f.dot(-2, -2, 2, "rgba(255,210,210,0.8)");
    f.g.restore();
  });
  var px = u.W * 0.5, py = u.GY - 30;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("cheap perspective, exhibit two: a grounded shadow sells any altitude", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("C", "Cauldron", "fantasy", "green bubbles, a lazy stir, and every eighth frame a star escapes the brew", function make(u) {
  var N = 16, S = 96, FPS = 11;
  var R = u.rng(307);
  var bubs = [];
  for (var j = 0; j < 6; j++) bubs.push({ dx: (R() - 0.5) * 22, off: R(), r: 1.5 + R() * 2 });
  var sheet = u.bake(N, S, function (f) {
    var cy = f.S - 26;
    f.g.fillStyle = "rgba(45,42,60,0.95)";
    f.g.beginPath();
    f.g.ellipse(f.c, cy + 6, 20, 12, 0, 0, Math.PI);  // the pot
    f.g.fill();
    f.g.fillRect(f.c - 20, cy, 40, 7);
    f.g.beginPath();                                  // the brew surface, stirring
    f.g.ellipse(f.c, cy, 17, 5, 0, 0, u.TAU);
    f.g.fillStyle = "rgba(120,220,120,0.85)";
    f.g.fill();
    var sa = f.kl * u.TAU;
    f.dot(f.c + Math.cos(sa) * 9, cy + Math.sin(sa) * 2.5, 2, "rgba(200,250,180,0.8)");
    for (var b = 0; b < bubs.length; b++) {           // rising brew bubbles
      var p = (f.kl + bubs[b].off) % 1;
      var y = cy - 2 - p * 24;
      var a = Math.sin(p * Math.PI);
      f.ring(f.c + bubs[b].dx * (0.6 + p * 0.5), y, bubs[b].r * (0.6 + p), "rgba(155,226,138," + a * 0.8 + ")", 1.2);
    }
    if (f.i % 8 === 0)                                // the escaping star
      f.star(f.c + 8, cy - 30, 4, 1.4, 5, "rgba(245,241,220,0.9)", 0.5);
  });
  var px = u.W * 0.5, py = u.GY - 32;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Venom's simmer with a schedule — the star is Yarn's paw, refluffed", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("D", "Doorway", "fantasy", "a door swings by x-scale while light spills through the widening gap", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var open = u.ease(Math.min(1, k / 0.7));
    var fx = f.c - 16, fw = 32, fh = 52, fy = f.S - 16 - fh;
    if (open > 0.05) {                                // the light wedge
      f.g.save();
      var grad = f.g.createLinearGradient(fx, 0, fx + fw + open * 20, 0);
      grad.addColorStop(0, "rgba(245,220,150," + open * 0.55 + ")");
      grad.addColorStop(1, "rgba(245,220,150,0)");
      f.g.fillStyle = grad;
      f.g.beginPath();
      f.g.moveTo(fx + 2, fy + 2);
      f.g.lineTo(fx + fw + open * 26, fy - open * 6);
      f.g.lineTo(fx + fw + open * 34, fy + fh + open * 8);
      f.g.lineTo(fx + 2, fy + fh);
      f.g.closePath(); f.g.fill();
      f.g.restore();
      for (var m = 0; m < 3; m++)                     // dust motes in the light
        f.dot(fx + 12 + m * 9 + open * 8, fy + 14 + ((f.i * 3 + m * 17) % 30), 1, "rgba(245,241,220," + open * 0.6 + ")");
    }
    f.g.strokeStyle = "rgba(201,196,228,0.8)";        // the frame
    f.g.lineWidth = 3;
    f.g.strokeRect(fx, fy, fw, fh);
    var dw = fw * (1 - open * 0.85);                  // the door: thinner = swung
    f.g.fillStyle = "rgba(110,80,52,0.95)";
    f.g.fillRect(fx, fy, dw, fh);
    if (dw > 5) f.dot(fx + dw - 4, fy + fh / 2, 1.8, "rgba(245,193,105,0.9)");
  });
  var px = u.W * 0.5, py = u.GY - 40, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.8) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5 - 40, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Itemget's |cos| trick on a hinge — width IS the swing angle", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; t0 = -9; }
  };
});

def("E", "Enchant", "fantasy", "runes light along the blade base-to-tip, then the whole edge takes the glow", function make(u) {
  var N = 14, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var bx = f.c - 14, by = f.S - 20;                 // blade from here…
    var tx = f.c + 20, ty = 18;                       // …to here
    f.g.strokeStyle = "rgba(201,196,228,0.9)";        // the blade
    f.g.lineWidth = 5;
    f.g.lineCap = "round";
    f.g.beginPath(); f.g.moveTo(bx, by); f.g.lineTo(tx, ty); f.g.stroke();
    f.g.lineCap = "butt";
    f.streak(bx - 7, by + 2, bx + 7, by - 6, "rgba(150,120,80,0.95)", 4);   // the guard
    var lit = u.ease(Math.min(1, k / 0.65));          // how far the magic reached
    for (var r = 0; r < 5; r++) {                     // five runes on the flat
      var q = (r + 0.5) / 5;
      if (q > lit) continue;
      var x = bx + (tx - bx) * q, y = by + (ty - by) * q;
      var age = u.clamp((lit - q) * 5, 0, 1);
      f.star(x - 4, y - 4, 3 * age, 1 * age, 4, "rgba(201,160,245," + (0.5 + age * 0.5) + ")", r);
    }
    if (k > 0.65) {                                   // the edge takes the glow
      var g2 = (k - 0.65) / 0.35;
      f.streak(bx, by, tx, ty, "rgba(201,160,245," + g2 * 0.6 + ")", 9);
      f.glow(tx, ty, 8 * g2, "rgba(201,160,245,", g2 * 0.9);
    }
  });
  var px = u.W * 0.5, py = u.GY - 38, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.5) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Xylophone's sequence walking a line instead of a keyboard", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("F", "Frostcreep", "fantasy", "ice claims the cell left to right — same seed every frame, longer branches every frame", function make(u) {
  var N = 12, S = 96, FPS = 14;
  function fern(f, seed, x0, y0, reach) {
    var R = u.rng(seed);
    var x = x0, y = y0, a = (R() - 0.5) * 0.8;
    var steps = Math.floor(reach * 8);
    for (var s = 0; s < steps; s++) {
      var nx = x + Math.cos(a) * 6, ny = y + Math.sin(a) * 6;
      f.streak(x, y, nx, ny, "rgba(190,230,250,0.85)", 2 - s * 0.15);
      if (s % 2 === 0) {                              // side needles
        f.streak(nx, ny, nx + Math.cos(a + 1.1) * 4, ny + Math.sin(a + 1.1) * 4, "rgba(190,230,250,0.6)", 1);
        f.streak(nx, ny, nx + Math.cos(a - 1.1) * 4, ny + Math.sin(a - 1.1) * 4, "rgba(190,230,250,0.6)", 1);
      }
      x = nx; y = ny; a += (R() - 0.5) * 0.7;
    }
    return [x, y];
  }
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var reach = u.ease(Math.min(1, k / 0.85));
    for (var j = 0; j < 5; j++) {
      var tip = fern(f, 820 + j, 8, 18 + j * 15, reach);
      if (k > 0.3 && k < 0.9)                         // gleams at the growing tips
        f.star(tip[0], tip[1], 2.5 * Math.sin(k * Math.PI), 0.9, 4, "rgba(245,251,255,0.8)", j);
    }
    if (k >= 0.85)                                    // fully claimed: a cold sheen
      f.glow(f.c, f.c, 38, "rgba(190,230,250,", (k - 0.85) / 0.15 * 0.15);
  });
  var px = u.W * 0.5, py = u.GY - 36, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.8) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene(); u.mote(u.W * 0.5, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Quake's remembering-crack, grown into dissolve's cold cousin", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("G", "Gears", "goofy", "two gears mesh — per lap, each turns a whole number of teeth, so the loop never skips", function make(u) {
  var N = 16, S = 96, FPS = 12;
  function gear(f, cx, cy, r, teeth, rot, col) {
    for (var t2 = 0; t2 < teeth; t2++) {
      var a = rot + (t2 / teeth) * u.TAU;
      f.streak(cx + Math.cos(a) * r, cy + Math.sin(a) * r,
        cx + Math.cos(a) * (r + 5), cy + Math.sin(a) * (r + 5), col, 4);
    }
    f.ring(cx, cy, r, col, 3);
    f.dot(cx, cy, 3, col);
  }
  var sheet = u.bake(N, S, function (f) {
    // big: 12 teeth, 1 tooth-pitch per lap · small: 6 teeth, 2 pitches per lap
    gear(f, f.c - 12, f.c + 6, 20, 12, f.kl * (u.TAU / 12), "rgba(201,196,228,0.9)");
    gear(f, f.c + 22, f.c - 12, 11, 6, -f.kl * (u.TAU / 6) * 2 + 0.26, "rgba(245,193,105,0.9)");
  });
  var px = u.W * 0.5, py = u.GY - 36;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.5);
      u.strip(sheet, i);
      u.label("Fireflies' integer rule in metal: rotate by whole tooth-pitches per lap", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("H", "Heartbeat", "cozy", "an EKG write-head sweeps the cell; the spike happens at the same phase every lap", function make(u) {
  var N = 16, S = 96, FPS = 12;
  function ekg(x) {                                   // the trace, as a function of x
    var q = x / 96;
    if (q > 0.4 && q < 0.46) return -26 * Math.sin((q - 0.4) / 0.06 * Math.PI);
    if (q > 0.46 && q < 0.52) return 10 * Math.sin((q - 0.46) / 0.06 * Math.PI);
    if (q > 0.6 && q < 0.72) return -6 * Math.sin((q - 0.6) / 0.12 * Math.PI);
    return Math.sin(q * 40) * 0.8;
  }
  var sheet = u.bake(N, S, function (f) {
    var hx = f.kl * f.S;                              // the write head
    f.g.strokeStyle = "rgba(155,226,138,0.9)";
    f.g.lineWidth = 1.8;
    f.g.beginPath();
    for (var x = 0; x < f.S; x += 2) {
      var age = (hx - x + f.S) % f.S;                 // older = fainter
      if (age > f.S * 0.85) continue;
      f.g.globalAlpha = 1 - age / (f.S * 0.85);
      var y = f.c + ekg(x);
      x === 0 ? f.g.moveTo(x, y) : f.g.lineTo(x, y);
    }
    f.g.stroke();
    f.g.globalAlpha = 1;
    f.glow(hx, f.c + ekg(hx), 5, "rgba(155,226,138,", 0.9);
  });
  var px = u.W * 0.5, py = u.GY - 38;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.7, "add");
      u.strip(sheet, i);
      u.label("Glint's traveller carrying a graph — trails by alpha-per-age", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("I", "Invaders", "arcade", "the original flipbook was TWO frames — arms up, arms down — and it conquered Earth", function make(u) {
  var N = 8, S = 96, FPS = 4;
  function alien(f, cx, cy, up, col) {
    f.g.fillStyle = col;
    f.g.fillRect(cx - 7, cy - 5, 14, 7);              // the body
    f.g.fillRect(cx - 10, cy - 2, 3, 4);
    f.g.fillRect(cx + 7, cy - 2, 3, 4);
    f.g.fillRect(cx - 5, cy - 8, 3, 3);               // the eyes' brow
    f.g.fillRect(cx + 2, cy - 8, 3, 3);
    var ly = up ? cy + 3 : cy + 5;                    // THE two-frame difference
    f.g.fillRect(cx - 9, ly, 3, 3);
    f.g.fillRect(cx + 6, ly, 3, 3);
    f.g.fillStyle = "#131020";
    f.g.fillRect(cx - 4, cy - 3, 2, 2);
    f.g.fillRect(cx + 2, cy - 3, 2, 2);
  }
  var sheet = u.bake(N, S, function (f) {
    var up = f.i % 2 === 0;
    var sx = [0, 5, 10, 5, 0, -5, -10, -5][f.i];      // the fleet shuffles
    for (var r = 0; r < 2; r++)
      for (var c2 = 0; c2 < 3; c2++)
        alien(f, 24 + c2 * 24 + sx, 30 + r * 22, up,
          r === 0 ? "rgba(155,226,138,0.95)" : "rgba(138,217,245,0.95)");
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.5);
      u.strip(sheet, i);
      u.label("N = 2 poses at 4 fps carried a whole genre — start smaller than you think", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("J", "Jump", "arcade", "hang time is frame count: the apex owns a third of the strip on purpose", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var i = f.i, base = f.S - 16;
    var ys = [0, 0, 14, 30, 39, 42, 42, 42, 39, 30, 14, 2];      // apex frames 5-7
    var y = ys[i];
    var sy = i < 2 ? 0.75 : (i === 2 || i === 3 ? 1.25 : (i === 11 ? 0.7 : 1));
    f.g.beginPath();
    f.g.ellipse(f.c, base + 3, 7 * (1 - y / 60), 2.2 * (1 - y / 60), 0, 0, u.TAU);
    f.g.fillStyle = "rgba(19,16,32,0.4)";
    f.g.fill();
    f.g.save();
    f.g.translate(f.c, base - 8 * sy - y);
    f.g.scale(1 / sy, sy);
    f.dot(0, 0, 8, "rgba(245,193,105,0.95)");
    f.dot(2.5, -2.5, 1.8, "#131020");
    f.g.restore();
    if (i === 11) for (var d = 0; d < 3; d++)         // landing dust
      f.dot(f.c - 10 + d * 10, base + 2, 2.5, "rgba(160,150,140,0.4)");
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.2) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("the ys[] table IS the animation — three 42s in a row are the hang", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; t0 = -9; }
  };
});

def("K", "Kaleido", "goofy", "one wedge of doodles, mirrored six ways — draw a sixth, get a mandala", function make(u) {
  var N = 16, S = 96, FPS = 10;
  var sheet = u.bake(N, S, function (f) {
    var R = u.rng(340);                               // ONE seed: the doodles are
    var doodles = [];                                 // fixed, only the wheel turns
    for (var j = 0; j < 5; j++)
      doodles.push({ r: 8 + R() * 28, a: R() * (u.TAU / 6), s: 1.5 + R() * 2.5,
                     c: ["rgba(245,138,160,0.8)", "rgba(138,217,245,0.8)", "rgba(245,193,105,0.8)"][j % 3] });
    for (var seg = 0; seg < 6; seg++) {
      var flip = seg % 2 === 1;                       // alternate segments mirror
      for (var d = 0; d < doodles.length; d++) {
        var dd = doodles[d];
        var a = (flip ? -dd.a : dd.a) + seg * (u.TAU / 6) + f.kl * u.TAU / 6;
        f.dot(f.c + Math.cos(a) * dd.r, f.c + Math.sin(a) * dd.r, dd.s, dd.c);
        f.ring(f.c + Math.cos(a) * dd.r, f.c + Math.sin(a) * dd.r, dd.s + 1.5, dd.c, 0.8);
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 38;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("rotate by 2π/6 per lap and the sixfold pattern loops on itself", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("L", "Lantern", "fantasy", "paper lanterns climb the night on offset clocks, each flame flickering its own warmth", function make(u) {
  var N = 16, S = 96, FPS = 10;
  var R = u.rng(347);
  var lans = [];
  for (var j = 0; j < 3; j++) lans.push({ x: 22 + j * 26, off: R(), sway: 3 + R() * 3 });
  var sheet = u.bake(N, S, function (f) {
    for (var j2 = 0; j2 < lans.length; j2++) {
      var L = lans[j2];
      var p = (f.kl + L.off) % 1;
      var y = f.S - 12 - p * (f.S - 20);
      var x = L.x + Math.sin(p * u.TAU + j2 * 2) * L.sway;
      var a = Math.sin(p * Math.PI);
      var flick = 0.8 + Math.sin(f.kl * u.TAU * 3 + j2 * 4) * 0.2;
      f.glow(x, y, 9 * a * flick, "rgba(245,161,90,", a * 0.5);
      f.g.fillStyle = "rgba(245,138,90," + a * 0.85 + ")";
      f.g.beginPath();
      f.g.ellipse(x, y, 5, 7, 0, 0, u.TAU);           // the paper body
      f.g.fill();
      f.streak(x - 4, y - 6, x + 4, y - 6, "rgba(120,80,50," + a * 0.9 + ")", 1.5);
      f.streak(x - 4, y + 6, x + 4, y + 6, "rgba(120,80,50," + a * 0.9 + ")", 1.5);
      f.dot(x, y + 1, 1.8, "rgba(245,241,200," + a * flick + ")");
    }
  });
  var px = u.W * 0.5, py = u.GY - 42;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Embers, grown up and given paper coats", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y - 20; }
  };
});

def("M", "Mushroom", "fantasy", "sproing: the cap overshoots on the way up, and spores puff at full height", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k, base = f.S - 14;
    var over = k < 0.5 ? (k / 0.5) * 1.3 - Math.pow(k / 0.5, 2) * 0.3 : 1 + Math.sin((k - 0.5) * 12) * 0.04 * (1 - k);
    var h = 26 * Math.max(0, over);
    if (h < 2) { f.dot(f.c, base, 3, "rgba(214,190,170,0.8)"); return; }
    f.g.fillStyle = "rgba(232,220,205,0.95)";
    f.g.fillRect(f.c - 3.5, base - h * 0.6, 7, h * 0.6);         // the stem
    f.g.fillStyle = "rgba(245,110,110,0.95)";
    f.g.beginPath();                                  // the cap
    f.g.ellipse(f.c, base - h * 0.6, 16 * Math.min(1, over), 10 * Math.min(1, over), 0, Math.PI, 0);
    f.g.fill();
    f.dot(f.c - 6, base - h * 0.6 - 4, 2.2, "rgba(255,235,235,0.9)");
    f.dot(f.c + 5, base - h * 0.6 - 2, 1.7, "rgba(255,235,235,0.9)");
    if (k > 0.45 && k < 0.8) {                        // the spore puff
      var q = (k - 0.45) / 0.35;
      for (var s = 0; s < 4; s++)
        f.dot(f.c - 12 + s * 8, base - h - 4 - q * 8, 1.2 * (1 - q), "rgba(232,220,205," + (1 - q) * 0.7 + ")");
    }
  });
  var px = u.W * 0.5, py = u.GY - 30, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.6) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Kapow's overshoot curve, gone botanical", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = u.GY - 30; t0 = -9; }
  };
});

def("N", "Nebula", "scifi", "translucent dust arms turn at three speeds around a bright core, seeded stars behind", function make(u) {
  var N = 16, S = 96, FPS = 9;
  var R = u.rng(353);
  var stars = [];
  for (var j = 0; j < 12; j++) stars.push({ x: R() * 96, y: R() * 96, tw: R() });
  var sheet = u.bake(N, S, function (f) {
    for (var s = 0; s < stars.length; s++) {          // the star field twinkles
      var st = stars[s];
      var a = 0.3 + 0.5 * Math.pow(Math.sin((f.kl + st.tw) * u.TAU) * 0.5 + 0.5, 2);
      f.dot(st.x, st.y, 0.8, "rgba(232,229,244," + a + ")");
    }
    var cols = ["rgba(201,160,245,", "rgba(138,217,245,", "rgba(245,138,180,"];
    for (var arm = 0; arm < 3; arm++) {               // the dust arms
      var rot = f.kl * u.TAU * (arm === 1 ? 2 : 1) * (arm === 2 ? -1 : 1);
      for (var b = 0; b < 4; b++) {
        var a2 = rot + arm * 2.1 + b * 0.5;
        var r = 10 + b * 6;
        f.dot(f.c + Math.cos(a2) * r, f.c + Math.sin(a2) * r * 0.7,
          7 - b, cols[arm] + (0.14 - b * 0.02) + ")");
      }
    }
    f.glow(f.c, f.c, 8, "rgba(245,241,220,", 0.7);    // the core
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.7, "add");
      u.strip(sheet, i);
      u.label("integer spin ratios (1, 2, −1) keep three arms on one seamless lap", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("O", "Odometer", "arcade", "the ones digit rolls continuously; the tens only tick when it laps — a carry, drawn", function make(u) {
  var N = 20, S = 96, FPS = 10;
  var sheet = u.bake(N, S, function (f) {
    var y0 = f.c - 11, h = 22;
    function window2(cx, val, slide) {                // one digit drum
      f.g.fillStyle = "rgba(28,24,44,0.95)";
      f.g.fillRect(cx - 9, y0, 18, h);
      f.g.strokeStyle = "rgba(201,196,228,0.6)";
      f.g.strokeRect(cx - 9, y0, 18, h);
      f.g.save();
      f.g.beginPath(); f.g.rect(cx - 9, y0, 18, h); f.g.clip();
      f.g.fillStyle = "#F5C169";
      f.g.font = "700 16px 'Spline Sans Mono', Consolas, monospace";
      f.g.textAlign = "center";
      f.g.textBaseline = "middle";
      f.g.fillText(String(Math.floor(val) % 10), cx, y0 + h / 2 + slide * h);
      f.g.fillText(String((Math.floor(val) + 1) % 10), cx, y0 + h / 2 + (slide - 1) * h);
      f.g.restore();
    }
    var ones = f.kl * 2 * 10 % 10;                    // two full drums per lap
    window2(f.c + 22, ones, ones % 1);
    var tens = f.kl * 2;                              // ticks only at the carry
    var tslide = ones > 9 ? ones - 9 : 0;
    window2(f.c, tens, tslide);
    window2(f.c - 22, 0, 0);
  });
  var px = u.W * 0.5, py = u.GY - 38;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("clip() windows + sliding glyphs — every score counter is this", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("P", "Portalhop", "scifi", "shrink into the left ring, grow out of the right — one loop, an infinite commute", function make(u) {
  var N = 16, S = 96, FPS = 13;
  var sheet = u.bake(N, S, function (f) {
    var kl = f.kl;
    var LX = 22, RX = 74, PY = f.c + 8;
    function portal(x, col, active) {
      f.g.strokeStyle = col + (0.5 + active * 0.5) + ")";
      f.g.lineWidth = 2.5;
      f.g.beginPath();
      f.g.ellipse(x, PY, 7 + active * 2, 16 + active * 3, 0, 0, u.TAU);
      f.g.stroke();
    }
    var inPhase = kl < 0.5;
    var q = (kl % 0.5) / 0.5;
    portal(LX, "rgba(138,217,245,", inPhase ? Math.sin(q * Math.PI) : 0);
    portal(RX, "rgba(245,161,90,", !inPhase ? Math.sin(q * Math.PI) : 0);
    var sc, x;
    if (inPhase) { sc = 1 - u.ease(q); x = LX + (1 - q) * 14; } // shrinking in
    else { sc = u.ease(q); x = RX - (1 - q) * -14 + (q - 1) * 14; x = RX + q * 14 - 14; } // growing out
    if (sc > 0.05) {
      f.dot(x, PY, 6 * sc, "rgba(155,226,138,0.95)");
      f.dot(x + 2 * sc, PY - 2 * sc, 1.4 * sc, "#131020");
    }
  });
  var px = u.W * 0.5, py = u.GY - 34;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.7, "add");
      u.strip(sheet, i);
      u.label("exit scale = 1 − entry scale — conservation of critter", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("Q", "Quill", "fantasy", "a feather writes a flourish that stays written — the line only ever gets longer", function make(u) {
  var N = 14, S = 96, FPS = 12;
  function path(q) {                                  // the flourish, 0..1 → x,y
    var x = 16 + q * 60;
    var y = 54 + Math.sin(q * u.TAU * 1.5) * 12 * (1 - q * 0.4) - q * 8;
    return [x, y];
  }
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    var reach = u.ease(Math.min(1, k / 0.8));
    f.g.strokeStyle = "rgba(60,50,90,0.9)";           // the ink so far
    f.g.lineWidth = 2;
    f.g.lineCap = "round";
    f.g.beginPath();
    for (var q = 0; q <= reach; q += 0.02) {
      var p = path(q);
      q === 0 ? f.g.moveTo(p[0], p[1]) : f.g.lineTo(p[0], p[1]);
    }
    f.g.stroke();
    f.g.lineCap = "butt";
    if (k < 0.85) {                                   // the quill at the write head
      var tip = path(reach);
      f.streak(tip[0], tip[1], tip[0] + 8, tip[1] - 18, "rgba(232,229,244,0.95)", 2.5);
      f.wedge(tip[0] + 8, tip[1] - 18, -1.9, 10, 0.35, "rgba(232,229,244,0.9)");
      if (f.i % 3 === 0) f.dot(tip[0] + 1, tip[1] + 2, 1, "rgba(60,50,90,0.7)");   // a spot of ink
    }
  });
  var px = u.W * 0.5, py = u.GY - 38, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.8) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Frostcreep with penmanship — reveals are growth played as writing", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

def("R", "Retrowave", "scifi", "the road to the horizon: rows accelerate and spread as they near — perspective from ONE curve", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var HOR = 40;                                     // the horizon line
    f.dot(f.c, HOR - 8, 13, "rgba(245,138,160,0.85)");           // the sun…
    f.g.fillStyle = "rgba(19,16,32,0.95)";
    for (var band = 0; band < 3; band++)              // …with its missing bands
      f.g.fillRect(f.c - 14, HOR - 8 + band * 4 + 1, 28, 1.8);
    f.streak(6, HOR, f.S - 6, HOR, "rgba(245,110,180,0.8)", 1.5);
    for (var v = -4; v <= 4; v++)                     // converging verticals
      f.streak(f.c + v * 3, HOR, f.c + v * 16, f.S - 4, "rgba(138,217,245,0.5)", 1);
    for (var r = 0; r < 5; r++) {                     // rows sliding toward us
      var p = (f.kl + r / 5) % 1;
      var y = HOR + p * p * (f.S - HOR - 4);          // p² = the perspective curve
      f.streak(6, y, f.S - 6, y, "rgba(138,217,245," + (0.25 + p * 0.6) + ")", 0.8 + p * 1.6);
    }
  });
  var px = u.W * 0.5, py = u.GY - 36;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.7, "add");
      u.strip(sheet, i);
      u.label("cheap perspective, exhibit three: y = horizon + p² — the square is the depth", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("S", "Springcoil", "goofy", "compress, tremble, LAUNCH, then ring down like a struck ruler", function make(u) {
  var N = 14, S = 96, FPS = 16;
  function coil(f, x, y0, h, w) {
    f.g.strokeStyle = "rgba(201,196,228,0.9)";
    f.g.lineWidth = 2.5;
    f.g.beginPath();
    for (var s = 0; s <= 24; s++) {
      var q = s / 24;
      f.g.lineTo(x + Math.sin(q * u.TAU * 4) * w, y0 - q * h);
    }
    f.g.stroke();
  }
  var sheet = u.bake(N, S, function (f) {
    var i = f.i, base = f.S - 12;
    var h, star = -1;
    if (i < 3) h = 34 - i * 8;                        // compressing
    else if (i < 5) h = 10 + (i - 3) * 1.5;           // the tremble
    else {                                            // launch + ring-down
      var q = (i - 5) / 8;
      h = 34 + Math.sin(q * u.TAU * 1.5) * 14 * Math.exp(-q * 2.5);   // damped!
      star = q;
    }
    coil(f, f.c, base, h, 9 + (34 - h) * 0.25);
    if (star >= 0) {
      var sy = base - 40 - u.ease(Math.min(1, star * 1.4)) * 34;
      f.star(f.c, sy, 6, 2.2, 5, "rgba(245,193,105," + (1 - star * 0.6) + ")", star * 4);
    } else {
      f.star(f.c, base - h - 6, 6, 2.2, 5, "rgba(245,193,105,0.95)", 0.3);
    }
  });
  var px = u.W * 0.5, py = u.GY - 32, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.4) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("sin·e^−t — the lexicon's damped spring, four frames of it", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; t0 = -9; }
  };
});

def("T", "Teleport", "scifi", "one dissolve sheet, two directions: forward = leave, REVERSED = arrive", function make(u) {
  var N = 10, S = 96, FPS = 16;
  var R = u.rng(367);
  var bits = [];
  for (var j = 0; j < 12; j++)
    bits.push({ a: R() * u.TAU, r: 3 + R() * 8, sp: 0.5 + R() });
  var sheet = u.bake(N, S, function (f) {             // baked ONCE, as "leaving"
    var k = f.k;
    if (k < 0.25) {
      f.dot(f.c, f.c, 9 * (1 - k / 0.25 * 0.3), "rgba(138,217,245,0.95)");
      f.dot(f.c + 3, f.c - 3, 1.8, "#131020");
    }
    for (var j2 = 0; j2 < bits.length; j2++) {        // the body becomes motes
      var b = bits[j2];
      var p = u.clamp((k - 0.15) / 0.85, 0, 1);
      if (p <= 0) continue;
      f.dot(f.c + Math.cos(b.a) * b.r * (1 + p), f.c + Math.sin(b.a) * b.r - p * 26 * b.sp,
        2 * (1 - p), "rgba(138,217,245," + (1 - p) + ")");
    }
  });
  var t0 = -9, AX = u.W * 0.3, BX = u.W * 0.7;
  return {
    frame: function (dt, t) {
      var CY = u.GY - 30;
      if (t - t0 > 2 * N / FPS + 1.6) t0 = t;
      var ts = (t - t0) * FPS;
      u.scene();
      if (ts < N) {                                   // leaving: play forward at A
        u.blit(sheet, Math.min(N - 1, Math.floor(ts)), AX, CY, 1.5, "add");
        u.strip(sheet, Math.min(N - 1, Math.floor(ts)));
      } else if (ts < 2 * N) {                        // arriving: SAME sheet, reversed, at B
        var i = N - 1 - Math.min(N - 1, Math.floor(ts - N));
        u.blit(sheet, i, BX, CY, 1.5, "add");
        u.strip(sheet, i);
      } else {                                        // arrived, briefly whole
        u.blit(sheet, 0, BX, CY, 1.5, "add");
        u.strip(sheet, 0);
      }
      u.label("i and N−1−i — a departure is an arrival read right-to-left", u.W / 2, u.H - 34, null, "center");
    },
    press: function () { t0 = -9; }
  };
});

def("U", "Umbrella", "cozy", "rain meets a dome and becomes deflection ticks and edge drips", function make(u) {
  var N = 14, S = 96, FPS = 13;
  var R = u.rng(373);
  var drops = [];
  for (var j = 0; j < 7; j++) drops.push({ x: 14 + R() * 68, off: R() });
  var sheet = u.bake(N, S, function (f) {
    var uy = f.c + 2;
    f.g.fillStyle = "rgba(245,138,138,0.95)";
    f.g.beginPath();                                  // the dome
    f.g.arc(f.c, uy, 24, Math.PI, 0);
    f.g.fill();
    for (var rib = 0; rib <= 3; rib++)
      f.streak(f.c - 24 + rib * 16, uy, f.c - 24 + rib * 16, uy - 2, "rgba(200,105,105,0.9)", 1.5);
    f.streak(f.c, uy, f.c, uy + 26, "rgba(201,196,228,0.9)", 2);   // the handle
    f.g.beginPath();
    f.g.arc(f.c + 4, uy + 26, 4, 0, Math.PI);
    f.g.strokeStyle = "rgba(201,196,228,0.9)";
    f.g.stroke();
    for (var d2 = 0; d2 < drops.length; d2++) {
      var dr = drops[d2];
      var p = (f.kl + dr.off) % 1;
      var hitY = uy - Math.sqrt(Math.max(0, 576 - (dr.x - f.c) * (dr.x - f.c)));
      var over = Math.abs(dr.x - f.c) < 23;
      var floorY2 = over ? hitY : f.S - 8;
      var y = 4 + p * (floorY2 - 8);
      if (y < floorY2 - 3) {
        f.streak(dr.x + 1, y, dr.x, y + 6, "rgba(150,200,245,0.7)", 1.2);
      } else if (over) {                              // deflected off the dome
        var side = dr.x < f.c ? -1 : 1;
        f.streak(dr.x, hitY, dr.x + side * 4, hitY - 3, "rgba(150,200,245," + (1 - p) + ")", 1);
      }
    }
    var edgeP = (f.kl * 2) % 1;                       // the patient edge drip
    f.dot(f.c + 24, uy + 2 + edgeP * 20, 1.5, "rgba(150,200,245," + (1 - edgeP) + ")");
  });
  var px = u.W * 0.5, py = u.GY - 38;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Rain's clocks, interrupted by geometry — collision baked as an if", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("V", "Victory", "arcade", "rays wheel behind a cup while sparkles and confetti recycle — a finale built of old parts", function make(u) {
  var N = 16, S = 96, FPS = 13;
  var R = u.rng(379);
  var conf = [];
  for (var j = 0; j < 8; j++)
    conf.push({ x: 12 + R() * 72, off: R(), c: ["#F58A8A", "#9BE28A", "#8AD9F5", "#C9A0F5"][j % 4] });
  var sheet = u.bake(N, S, function (f) {
    for (var ray = 0; ray < 8; ray++) {               // the wheeling rays
      var a = f.kl * u.TAU / 8 + ray * u.TAU / 8;     // one spoke-step per lap
      f.wedge(f.c, f.c - 2, a, 42, 0.14, "rgba(245,193,105,0.14)");
    }
    f.g.fillStyle = "rgba(245,193,105,0.95)";         // the cup
    f.g.beginPath();
    f.g.moveTo(f.c - 11, f.c - 14);
    f.g.quadraticCurveTo(f.c, f.c + 4, f.c + 11, f.c - 14);
    f.g.closePath(); f.g.fill();
    f.g.fillRect(f.c - 3, f.c - 2, 6, 8);
    f.g.fillRect(f.c - 8, f.c + 6, 16, 3);
    f.dot(f.c - 4, f.c - 10, 1.8, "rgba(255,240,210,0.9)");
    var tw = Math.pow(Math.sin(f.kl * u.TAU * 2), 2); // the glint, twice a lap
    f.star(f.c + 8, f.c - 12, 5 * tw, 1.6 * tw, 4, "rgba(245,241,220," + tw + ")", f.kl * 3);
    for (var c2 = 0; c2 < conf.length; c2++) {        // recycling confetti
      var p = (f.kl + conf[c2].off) % 1;
      var col = conf[c2].c;
      f.g.save();
      f.g.translate(conf[c2].x, 6 + p * (f.S - 12));
      f.g.rotate(p * 9 + c2);
      f.g.globalAlpha = Math.sin(p * Math.PI);
      f.g.fillStyle = col;
      f.g.fillRect(-2, -1.3, 4, 2.6);
      f.g.restore();
      f.g.globalAlpha = 1;
    }
  });
  var px = u.W * 0.5, py = u.GY - 40;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene(); u.mote(px, u.GY - 12);
      u.blit(sheet, i, px, py, 1.6, "add");
      u.strip(sheet, i);
      u.label("Orbit's wheel + Sparkle's blink + Confetti's flutter — a finale is a chord", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("W", "Wormhole", "scifi", "rings grow toward you from a point — scale-through-time IS the tunnel", function make(u) {
  var N = 16, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    for (var ring2 = 5; ring2 >= 0; ring2--) {
      var p = (f.kl + ring2 / 6) % 1;
      var r = 2 + Math.pow(p, 2.2) * 44;              // slow far away, fast up close
      var a = p < 0.15 ? p / 0.15 : (p > 0.85 ? (1 - p) / 0.15 : 1);
      var drift = Math.sin(p * 5 + f.kl * u.TAU) * p * 3;         // the tunnel bends
      f.ring(f.c + drift, f.c + drift * 0.5, r, "rgba(201,160,245," + a * 0.8 + ")", 1 + p * 2.5);
      if (ring2 % 2 === 0)
        f.ring(f.c + drift, f.c + drift * 0.5, r * 0.92, "rgba(138,217,245," + a * 0.4 + ")", 1);
    }
    f.glow(f.c, f.c, 6, "rgba(245,241,220,", 0.8);    // the far end
  });
  var px = u.W * 0.5, py = u.GY - 38;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.7, "add");
      u.strip(sheet, i);
      u.label("cheap perspective, exhibit four: p^2.2 growth reads as flying INTO it", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("X", "Xray", "scifi", "every sixth frame swaps the body for its bones — the two-frame damage flash, medically enhanced", function make(u) {
  var N = 12, S = 96, FPS = 14;
  var sheet = u.bake(N, S, function (f) {
    var xr = f.i % 6 === 0;                           // the flash frames
    if (!xr) {
      f.dot(f.c, f.c - 4, 11, "rgba(138,217,245,0.95)");          // the body
      f.dot(f.c, f.c + 11, 8, "rgba(138,217,245,0.9)");
      f.dot(f.c + 4, f.c - 6, 1.8, "#131020");
      f.dot(f.c - 4, f.c - 6, 1.8, "#131020");
    } else {
      f.g.fillStyle = "rgba(232,240,250,0.9)";        // the negative flash
      f.g.fillRect(f.c - 18, f.c - 20, 36, 42);
      var bone = "rgba(19,16,32,0.9)";                // and the skeleton
      f.ring(f.c, f.c - 5, 6, bone, 2);
      f.streak(f.c, f.c + 1, f.c, f.c + 14, bone, 2.5);
      f.streak(f.c - 7, f.c + 4, f.c + 7, f.c + 4, bone, 2);
      f.streak(f.c - 6, f.c + 8, f.c + 6, f.c + 8, bone, 2);
      f.dot(f.c - 2.5, f.c - 6, 1.6, bone);
      f.dot(f.c + 2.5, f.c - 6, 1.6, bone);
    }
  });
  var px = u.W * 0.5, py = u.GY - 36;
  return {
    frame: function (dt, t) {
      var i = Math.floor(t * FPS) % N;
      u.scene();
      u.blit(sheet, i, px, py, 1.5);
      u.strip(sheet, i);
      u.label("Invaders' two-pose lesson at combat speed — a swap IS an effect", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; }
  };
});

def("Y", "Yolk", "goofy", "tip, crack, split, plop — and then the yolk blinks at you", function make(u) {
  var N = 14, S = 96, FPS = 12;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k, base = f.S - 16;
    if (k < 0.55) {                                   // the egg, tipping + cracking
      var tip = Math.sin(Math.min(1, k / 0.3) * Math.PI) * 0.2 + (k > 0.3 ? (k - 0.3) * 1.2 : 0);
      f.g.save();
      f.g.translate(f.c, base - 13);
      f.g.rotate(tip);
      f.g.fillStyle = "rgba(240,235,222,0.95)";
      f.g.beginPath(); f.g.ellipse(0, 0, 10, 13, 0, 0, u.TAU); f.g.fill();
      if (k > 0.2) {                                  // the crack spreads
        var cr = Math.min(1, (k - 0.2) / 0.3);
        f.g.strokeStyle = "rgba(120,110,95,0.9)";
        f.g.lineWidth = 1;
        f.g.beginPath();
        f.g.moveTo(-8, 0);
        for (var s = 1; s <= Math.floor(cr * 5); s++)
          f.g.lineTo(-8 + s * 3.2, (s % 2 ? -2.5 : 2.5));
        f.g.stroke();
      }
      f.g.restore();
    } else {                                          // the plop + the blink
      var q = (k - 0.55) / 0.45;
      f.g.fillStyle = "rgba(240,235,222,0.9)";        // shell halves, fallen
      f.g.beginPath(); f.g.ellipse(f.c - 13, base - 3, 7, 5, -0.4, Math.PI, 0); f.g.fill();
      f.g.beginPath(); f.g.ellipse(f.c + 13, base - 3, 7, 5, 0.4, Math.PI, 0); f.g.fill();
      var wob = 1 + Math.sin(q * 12) * 0.15 * (1 - q);
      f.g.beginPath();                                // the white
      f.g.ellipse(f.c, base - 2, 15 * wob, 5 / wob, 0, 0, u.TAU);
      f.g.fillStyle = "rgba(245,242,235,0.9)";
      f.g.fill();
      f.dot(f.c, base - 5, 6.5 * wob, "rgba(245,193,60,0.98)");   // the yolk
      var blink = q > 0.5 && q < 0.62;                // the googly moment
      if (blink) {
        f.streak(f.c - 2.5, base - 7, f.c - 0.5, base - 7, "#131020", 1.2);
        f.streak(f.c + 0.5, base - 7, f.c + 2.5, base - 7, "#131020", 1.2);
      } else {
        f.dot(f.c - 1.8, base - 7, 1.1, "#131020");
        f.dot(f.c + 1.8, base - 7, 1.1, "#131020");
      }
    }
  });
  var px = u.W * 0.5, py = u.GY - 30, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 1.8) t0 = t;
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Drip's four acts with comedic casting — the blink is two frames", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = u.GY - 30; t0 = -9; }
  };
});

def("Z", "Zen", "cozy", "a rake draws its rings around the stone at 8 fps, and then everything simply rests", function make(u) {
  var N = 16, S = 96, FPS = 8;
  var sheet = u.bake(N, S, function (f) {
    var k = f.k;
    f.g.fillStyle = "rgba(90,86,105,0.95)";           // the stone
    f.g.beginPath();
    f.g.ellipse(f.c + 6, f.c + 2, 9, 6.5, 0.3, 0, u.TAU);
    f.g.fill();
    f.dot(f.c + 3, f.c - 1, 2, "rgba(130,126,145,0.8)");
    var reach = u.ease(Math.min(1, k / 0.8));         // the rake's progress
    for (var ring2 = 0; ring2 < 3; ring2++) {
      var rr = 15 + ring2 * 8;
      var end = u.clamp(reach * 3 - ring2, 0, 1);     // rings draw in sequence
      if (end <= 0) continue;
      f.g.strokeStyle = "rgba(214,205,185,0.6)";
      f.g.lineWidth = 1.2;
      for (var line = -1; line <= 1; line++) {        // the rake has three teeth
        f.g.beginPath();
        f.g.ellipse(f.c + 6, f.c + 2, rr + line * 2.2, (rr + line * 2.2) * 0.62, 0.3,
          -u.TAU / 4, -u.TAU / 4 + end * u.TAU);
        f.g.stroke();
      }
    }
    if (k < 0.8) {                                    // the rake tip itself
      var a = -u.TAU / 4 + u.clamp(reach * 3 - Math.min(2, Math.floor(reach * 3)), 0, 1) * u.TAU;
      var rr2 = 15 + Math.min(2, Math.floor(reach * 3)) * 8;
      f.dot(f.c + 6 + Math.cos(a) * rr2, f.c + 2 + Math.sin(a) * rr2 * 0.62, 1.8, "rgba(232,229,244,0.8)");
    }
  });
  var px = u.W * 0.5, py = u.GY - 34, t0 = -9;
  return {
    frame: function (dt, t) {
      if (t - t0 > N / FPS + 2.5) t0 = t;             // a long, unhurried rest
      var i = Math.min(N - 1, Math.floor((t - t0) * FPS));
      u.scene();
      u.blit(sheet, i, px, py, 1.6);
      u.strip(sheet, i);
      u.label("Quill's reveal at garden speed — the folio closes at 8 fps, on purpose", u.W / 2, u.H - 34, null, "center");
    },
    press: function (x, y) { px = x; py = y; t0 = -9; }
  };
});

/* ============================== the page runner ============================== */

var FAMILY_ORDER = [
  ["glow", "Glow & flame", "seamless loops of light — phase = i/N, played additively"],
  ["hit", "Hits & slashes", "one-shots born at a point — clamp the index, bake the last frame empty"],
  ["smoke", "Smoke, dust & water", "matter, not light — source-over playback, transparency doing the real work"],
  ["magic", "Magic & sparkle", "offset clocks, counter-rotating layers, and per-frame chaos"],
  ["speech", "Speech & celebration", "effects that talk to the player — paper, ink, and punctuation"],
  ["scifi", "Sci-fi & glitch", "beams, portals, static, neon — plus the start/loop/end triple and frames that own their own clocks"],
  ["fantasy", "Fantasy & adventure", "charge-ups, frost, doors, quills — and a two-clip atlas running the width of its card"],
  ["arcade", "Action & arcade", "explosions, jackpots, invaders — loud, brief, layered, and staggered"],
  ["cozy", "Cozy & minimal", "axolotls, kettles, zen sand — soft clocks, and one sheet playing at three speeds"],
  ["goofy", "Goofy & playful", "waddles, yolks, springs — squash, stretch, ping-pong, and comedy timing"]
];

var grid = document.getElementById("folio");
var statusEl = document.getElementById("status");
var runAllBtn = document.getElementById("runall");
var stopAllBtn = document.getElementById("stopall");
var cards = [];

function buildCard(effect) {
  var card = document.createElement("div");
  card.className = "bcard";
  var canvas = document.createElement("canvas");
  canvas.title = effect.name + " — click to wake it, click again to move or retrigger it";
  card.appendChild(canvas);
  var meta = document.createElement("div");
  meta.className = "meta";
  var b = document.createElement("b");
  b.textContent = effect.letter + " · " + effect.name;
  var a = document.createElement("a");
  a.href = "#editor";
  a.textContent = "open code ⤵";
  meta.appendChild(b);
  meta.appendChild(a);
  card.appendChild(meta);
  var hint = document.createElement("p");
  hint.className = "bhint";
  hint.textContent = effect.hint;
  card.appendChild(hint);

  var st = { effect: effect, canvas: canvas, u: null, inst: null, running: false, elapsed: 0, visible: true };
  cards.push(st);
  canvas.__st = st;

  a.addEventListener("click", function () { openInEditor(effect); });
  canvas.addEventListener("pointerdown", function (e) {
    var rect = canvas.getBoundingClientRect();
    var mx = e.clientX - rect.left, my = e.clientY - rect.top;
    if (!st.running) startCard(st);
    if (st.inst && st.inst.press) {
      try { st.inst.press(mx, my); } catch (err) { failCard(st, err); }
    }
  });
  return card;
}

function placeholder(st) {
  var u = apiFor(st.canvas);
  u.scene();
  u.ctx.fillStyle = "rgba(232,229,244,0.14)";
  u.ctx.font = "700 " + Math.round(u.H * 0.5) + "px 'Spline Sans Mono', Consolas, monospace";
  u.ctx.textAlign = "center";
  u.ctx.textBaseline = "middle";
  u.ctx.fillText(st.effect.letter, u.W / 2, u.H * 0.52);
  u.ctx.fillStyle = "rgba(230,227,242,0.55)";
  u.ctx.font = "12px system-ui, sans-serif";
  u.ctx.textBaseline = "alphabetic";
  u.ctx.fillText("▶ click to bake + play", u.W / 2, u.H * 0.16);
  u.ctx.textAlign = "left";
}

function startCard(st) {
  var u = apiFor(st.canvas);
  st.u = u;
  try { st.inst = st.effect.make(u); } catch (err) { failCard(st, err); return; }
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

function ensureLoop() {
  if (rafId === null) { lastTs = null; rafId = requestAnimationFrame(tick); }
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
    st.elapsed += dt;
    try { st.inst.frame(dt, st.elapsed); } catch (err) { failCard(st, err); continue; }
    if (st.elapsed > 60) restCard(st);
  }
  if (any) rafId = requestAnimationFrame(tick);
  else { rafId = null; updateStatus(); }
}

function updateStatus() {
  var n = 0;
  for (var i = 0; i < cards.length; i++) if (cards[i].running) n++;
  if (n !== lastCount) {
    lastCount = n;
    statusEl.textContent = n === 0 ? "" : n + " of " + cards.length + " sheets playing";
  }
}

runAllBtn.addEventListener("click", function () {
  for (var i = 0; i < cards.length; i++) startCard(cards[i]);
});
stopAllBtn.addEventListener("click", function () {
  for (var i = 0; i < cards.length; i++) cards[i].running = false;
  updateStatus();
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
  small.textContent = list.length + " sheets — " + fam[2];
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
var current = { effect: EFFECTS[0] };
var pv = { inst: null, raf: null, elapsed: 0 };

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
  u.scene();
  u.ctx.fillStyle = "rgba(232,229,244,0.12)";
  u.ctx.font = "700 " + Math.round(u.H * 0.45) + "px 'Spline Sans Mono', Consolas, monospace";
  u.ctx.textAlign = "center";
  u.ctx.textBaseline = "middle";
  u.ctx.fillText(current.effect.letter, u.W / 2, u.H * 0.52);
  u.ctx.fillStyle = "rgba(230,227,242,0.6)";
  u.ctx.font = "15px system-ui, sans-serif";
  u.ctx.textBaseline = "alphabetic";
  u.ctx.fillText("Press ▶ Run — the sheet bakes fresh from your edits.", u.W / 2, u.H * 0.14);
  u.ctx.textAlign = "left";
}

function openInEditor(effect) {
  current = { effect: effect };
  edname.textContent = effect.letter + " · " + effect.name + " — " + effect.hint;
  codeBox.value = dedent(effect.make.toString());
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
  pv.elapsed = 0;
  var last = null;
  function step(ts) {
    if (last === null) last = ts;
    var dt = Math.min(0.05, (ts - last) / 1000);
    last = ts;
    pv.elapsed += dt;
    try { pv.inst.frame(dt, pv.elapsed); }
    catch (e) { errBox.textContent = "The code hit a snag mid-frame: " + e.message; stopPreview(); return; }
    if (pv.elapsed < 60) pv.raf = requestAnimationFrame(step);
    else pv.raf = null;
  }
  pv.raf = requestAnimationFrame(step);
}

runBtn.addEventListener("click", runPreview);
stopBtn.addEventListener("click", stopPreview);
resetBtn.addEventListener("click", function () {
  stopPreview();
  openInEditor(current.effect);
});
cv.addEventListener("pointerdown", function (e) {
  if (!pv.inst || !pv.inst.press) return;
  var r = cv.getBoundingClientRect();
  try { pv.inst.press(e.clientX - r.left, e.clientY - r.top); }
  catch (err) { errBox.textContent = "The press handler hit a snag: " + err.message; }
});

openInEditor(EFFECTS[0]);

/* expose a tiny hook for the automated smoke test (harmless in normal use) */
window.__folio = { EFFECTS: EFFECTS, apiFor: apiFor, cards: cards };
})();
