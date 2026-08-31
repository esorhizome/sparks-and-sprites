/* Sparks & Sprites — the flipbook folio.
   26 VFX baked into transparent sprite sheets, A to Z — the fifth gallery
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

/* ============================== the page runner ============================== */

var FAMILY_ORDER = [
  ["glow", "Glow & flame", "seamless loops of light — phase = i/N, played additively"],
  ["hit", "Hits & slashes", "one-shots born at a point — clamp the index, bake the last frame empty"],
  ["smoke", "Smoke, dust & water", "matter, not light — source-over playback, transparency doing the real work"],
  ["magic", "Magic & sparkle", "offset clocks, counter-rotating layers, and per-frame chaos"],
  ["speech", "Speech & celebration", "effects that talk to the player — paper, ink, and punctuation"]
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
