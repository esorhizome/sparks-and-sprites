/* Sparks & Sprites — the glyph grimoire.
   One phrase ("just this") and 104 ways for it to arrive, breathe, glow,
   scramble, and misbehave — programmatic text animation, the third gallery
   after the elemental button bestiary and the cube codex. If the bestiary
   was buttons possessed by elements and the codex was effects worn by a
   character, the grimoire is what a phrase can DO: weight and glow,
   typewriters and fades, scrambles, waves, arrivals, spins, inks, shakes,
   strokes, particles, shadows.

   Every effect is one function make(u) that returns { frame(dt, t), press(x, y) }.
   The kit u:
     ctx, W, H     — the 2D context and canvas size (CSS pixels)
     MID           — the phrase's baseline y (a little below centre)
     BASE          — the phrase's resting font size for this canvas
     PHRASE        — "just this" (change it — everything is measured, not
                     hard-coded, so any short phrase works)
     INK, DIM      — the resting text colour, and its faded cousin
     font(w, s)    — a canvas font string: weight w (300–700 render as real
                     weights of Spline Sans Mono; "i400" italicizes), size s
     layout(s, sp, w) — the heart of the kit: measures PHRASE at size s
                     (default BASE) with sp extra px between letters, and
                     returns one entry per character:
                       { ch, i, n, x, cx, w, y }
                     x is the letter's left edge, cx its centre, w its width,
                     y the shared baseline, i/n its index/count. Draw a plain
                     letter with ctx.fillText(L.ch, L.x, L.y); draw a
                     transformed one by translating to (L.cx, L.y) and
                     filling at (-L.w/2, 0). NOTE: layout() sets ctx.font as
                     a side effect — call it, then draw.
     stage()       — clears the canvas: night backdrop + a faint baseline rule
     glow(x,y,r,c) — a soft radial glow (colour string with its own alpha)
     scramble()    — one random wrong glyph (from GLYPHS)
     rand(a, b), TAU

   Nothing animates until the visitor presses Run (or clicks a card awake),
   and every card rests after 60 seconds as a courtesy. */
(function () {
"use strict";
var TAU = Math.PI * 2;
var PHRASE = "just this";
var GLYPHS = "abcdefghjkmnpqrstuvwxyz023456789#%&@+=?";

var EFFECTS = [];
function def(name, tag, hint, make) {
  EFFECTS.push({ name: name, tag: tag, hint: hint, make: make });
}

/* A RHYME is the same effect with two or three dials turned — a palette, a
   speed, a direction, a count — proof that understanding one recipe buys
   you a whole neighbourhood of others. Each card's ⇄ button swaps original
   and rhyme; the rhyme's hint names exactly which dials moved. */
function rhymeOf(orig, name, hint, make) {
  for (var i = 0; i < EFFECTS.length; i++)
    if (EFFECTS[i].name === orig) {
      EFFECTS[i].rhyme = { name: name, hint: hint, make: make };
      return;
    }
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
  ctx.textAlign = "left";
  ctx.textBaseline = "alphabetic";
  var MID = H * 0.54;
  var BASE = Math.min(H * 0.30, W * 0.135);
  var INK = "#E8E5F4";
  var DIM = "rgba(232,229,244,0.22)";
  function rand(a, b) { return a + Math.random() * (b - a); }
  function font(w, s) {
    w = w === undefined ? 400 : w;
    var italic = "";
    if (typeof w === "string" && w.charAt(0) === "i") { italic = "italic "; w = +w.slice(1) || 400; }
    return italic + w + " " + (s === undefined ? BASE : s) + "px 'Spline Sans Mono', Consolas, monospace";
  }
  function layout(size, spacing, weight) {
    size = size === undefined ? BASE : size;
    spacing = spacing || 0;
    ctx.font = font(weight === undefined ? 400 : weight, size);
    var ws = [], total = 0, i;
    for (i = 0; i < PHRASE.length; i++) {
      ws[i] = ctx.measureText(PHRASE[i]).width;
      total += ws[i] + (i ? spacing : 0);
    }
    var x = (W - total) / 2, out = [];
    for (i = 0; i < PHRASE.length; i++) {
      out.push({ ch: PHRASE[i], i: i, n: PHRASE.length, x: x, cx: x + ws[i] / 2, w: ws[i], y: MID });
      x += ws[i] + spacing;
    }
    return out;
  }
  function stage() {
    ctx.fillStyle = "#131020";
    ctx.fillRect(0, 0, W, H);
    var g = ctx.createLinearGradient(0, 0, 0, H);   // the night backdrop
    g.addColorStop(0, "#1A1532");
    g.addColorStop(1, "#131020");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    ctx.strokeStyle = "rgba(150,145,190,0.14)";      // the faint baseline rule
    ctx.lineWidth = 1;
    ctx.setLineDash([2, 5]);
    ctx.beginPath();
    ctx.moveTo(W * 0.08, MID + BASE * 0.28);
    ctx.lineTo(W * 0.92, MID + BASE * 0.28);
    ctx.stroke();
    ctx.setLineDash([]);
  }
  function glow(x, y, r, colour) {
    var g = ctx.createRadialGradient(x, y, 0, x, y, Math.max(1, r));
    g.addColorStop(0, colour);
    g.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(x, y, Math.max(1, r), 0, TAU); ctx.fill();
  }
  function scramble() { return GLYPHS[Math.floor(Math.random() * GLYPHS.length)]; }
  return { ctx: ctx, W: W, H: H, MID: MID, BASE: BASE, PHRASE: PHRASE, GLYPHS: GLYPHS,
           INK: INK, DIM: DIM, rand: rand, TAU: TAU,
           font: font, layout: layout, stage: stage, glow: glow, scramble: scramble };
}

/* ============================== WEIGHT & WIDTH ============================== */

def("Crescendo", "weight", "thin, then bold, then bolder, then bolder-and-larger — press to peak at once", function (u) {
  const { ctx, W, H, MID, BASE, INK, rand, TAU, font, layout, stage } = u;
  // the voice clears its throat: 300 → 700, then keeps swelling by size + stroke
  let p = 0, hold = 0;
  return {
    press() { p = 1; hold = 0.8; },
    frame(dt, t) {
      stage();
      if (hold > 0) hold -= dt;
      else p = (p + dt * 0.22) % 1.3;      // the slow climb, with a beat of rest at the top
      const k = Math.min(1, p);
      const weight = 300 + Math.round(k * 4) * 100;        // 300,400,500,600,700 — real font weights
      const size = BASE * (1 + Math.max(0, k - 0.75) * 0.6); // the last quarter also grows
      const L = layout(size, 0, weight);
      ctx.fillStyle = INK;
      ctx.strokeStyle = INK;
      ctx.lineWidth = Math.max(0.01, (k - 0.85) * BASE * 0.12);  // past 700, the stroke fattens on
      for (const l of L) {
        ctx.fillText(l.ch, l.x, l.y);
        if (k > 0.85) ctx.strokeText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Breathing weight", "weight", "the whole phrase inhales toward bold and exhales toward thin", function (u) {
  const { ctx, INK, BASE, font, layout, stage, TAU } = u;
  let boost = 0;
  return {
    press() { boost = 1; },              // a startled deep breath
    frame(dt, t) {
      stage();
      boost = Math.max(0, boost - dt * 0.8);
      const k = 0.5 + 0.5 * Math.sin(t * TAU / 4.2) ;      // one breath every ~4 seconds
      const weight = 300 + Math.round((k + boost * 0.5) * 4) * 100;
      const L = layout(BASE * (1 + boost * 0.06), 0, Math.min(700, weight));
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Fat press", "weight", "every press feeds it a weight step; left alone, it slims back down", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let fat = 0;                            // 0..4 → weights 300..700
  return {
    press() { fat = Math.min(4, fat + 1); },
    frame(dt, t) {
      stage();
      fat = Math.max(0, fat - dt * 0.35);                  // the slow diet
      const L = layout(BASE, 0, 300 + Math.round(fat) * 100);
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      ctx.fillStyle = "rgba(232,229,244,0.35)";
      ctx.font = "10px system-ui, sans-serif";
      ctx.fillText("weight " + (300 + Math.round(fat) * 100), 8, 14);
    }
  };
});

def("Stretch", "weight", "condensed to expanded and back — press slams it wide", function (u) {
  const { ctx, INK, BASE, layout, stage, TAU } = u;
  let slam = 0;
  return {
    press() { slam = 1; },
    frame(dt, t) {
      stage();
      slam = Math.max(0, slam - dt * 1.4);
      const sx = 0.72 + 0.28 * (0.5 + 0.5 * Math.sin(t * TAU / 5)) + slam * 0.34;
      const L = layout(BASE, 0, 500);
      ctx.fillStyle = INK;
      for (const l of L) {                 // each letter widens about its own centre…
        ctx.save();
        ctx.translate(W_centre(l, sx), l.y); // …and the row respreads from the phrase's middle
        ctx.scale(sx, 1);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
      function W_centre(l, s) {            // respread: letter centres scaled about phrase centre
        const mid = (L[0].x + L[L.length - 1].x + L[L.length - 1].w) / 2;
        return mid + (l.cx - mid) * s;
      }
    }
  };
});

def("Heavy word", "weight", "the emphasis strolls from word to word, one bold at a time", function (u) {
  const { ctx, INK, DIM, BASE, PHRASE, layout, stage } = u;
  let which = 0, timer = 0;
  const starts = [0];                      // word boundaries, found once
  for (let i = 0; i < PHRASE.length; i++) if (PHRASE[i] === " ") starts.push(i + 1);
  function wordOf(i) { let w = 0; for (let s = 1; s < starts.length; s++) if (i >= starts[s]) w = s; return w; }
  return {
    press() { which = (which + 1) % starts.length; timer = 0; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (timer > 1.8) { timer = 0; which = (which + 1) % starts.length; }
      const L = layout(BASE, 0, 700);      // measure at bold so nothing shifts when emphasis lands
      for (const l of L) {
        const bold = wordOf(l.i) === which;
        ctx.font = u.font(bold ? 700 : 300, BASE);
        ctx.fillStyle = bold ? INK : "rgba(232,229,244,0.6)";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Weight wave", "weight", "a bold spotlight travels through the letters like a wave down a rope", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let speed = 1;
  return {
    press() { speed = 3.5; },              // hurry the wave for a while
    frame(dt, t) {
      stage();
      speed = Math.max(1, speed - dt * 1.2);
      const L = layout(BASE, 0, 700);
      const centre = (t * speed * 0.9) % 2 - 0.5;          // sweeps past both ends
      for (const l of L) {
        const d = Math.abs(l.i / (l.n - 1) - centre);
        const k = Math.max(0, 1 - d * 3);                  // near the wave = heavy
        ctx.font = u.font(300 + Math.round(k * 4) * 100, BASE * (1 + k * 0.12));
        ctx.fillStyle = INK;
        ctx.fillText(l.ch, l.cx - ctx.measureText(l.ch).width / 2, l.y);
      }
    }
  };
});

def("Iron & feather", "weight", "alternate letters heavy and light, trading places on a beat", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let flip = 0, timer = 0;
  return {
    press() { flip = 1 - flip; timer = 0; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (timer > 1.2) { timer = 0; flip = 1 - flip; }
      const L = layout(BASE, 0, 700);
      for (const l of L) {
        const heavy = (l.i % 2) === flip;
        ctx.font = u.font(heavy ? 700 : 300, BASE);
        ctx.fillStyle = heavy ? INK : "rgba(232,229,244,0.72)";
        // iron sits on the line; the feather floats a hair above it
        ctx.fillText(l.ch, l.x, l.y - (heavy ? 0 : BASE * 0.05));
      }
    }
  };
});

/* ============================== GLOW & NEON ============================== */

def("Candleglow", "glow", "a soft warm halo that flickers like a small flame — press to flare", function (u) {
  const { ctx, W, MID, BASE, INK, rand, layout, stage, glow } = u;
  let flare = 0, wick = 0;
  return {
    press() { flare = 1; },
    frame(dt, t) {
      stage();
      flare = Math.max(0, flare - dt * 1.2);
      wick += (rand(-1, 1) - wick) * Math.min(1, dt * 6);  // the flicker, smoothed
      const a = 0.10 + 0.03 * wick + flare * 0.22;
      ctx.globalCompositeOperation = "lighter";
      glow(W / 2, MID - BASE * 0.3, BASE * (2.6 + wick * 0.2 + flare * 1.4), "rgba(255,190,110," + a + ")");
      ctx.globalCompositeOperation = "source-over";
      const L = layout();
      ctx.fillStyle = "#F6EBD8";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Halo lift", "glow", "a moderate cool glow on a slow three-second breath — press to double it", function (u) {
  const { ctx, W, MID, BASE, layout, stage, glow, TAU } = u;
  let lift = 0;
  return {
    press() { lift = 1; },
    frame(dt, t) {
      stage();
      lift = Math.max(0, lift - dt * 0.7);
      const breath = 1 + 0.03 * Math.sin(t * TAU / 3);     // the ±3% breath, borrowed from the halo demo
      ctx.globalCompositeOperation = "lighter";
      glow(W / 2, MID - BASE * 0.3, BASE * 3.4 * breath * (1 + lift), "rgba(140,170,255," + (0.16 + lift * 0.14) + ")");
      glow(W / 2, MID - BASE * 0.3, BASE * 1.7 * breath, "rgba(190,210,255,0.13)");
      ctx.globalCompositeOperation = "source-over";
      const L = layout();
      ctx.fillStyle = "#E4EAFF";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Supernova", "glow", "a big glow that nearly swallows the letters — press to send out a ring", function (u) {
  const { ctx, W, MID, BASE, layout, stage, glow, TAU } = u;
  let rings = [];
  return {
    press() { rings.push({ r: BASE, a: 0.8 }); },
    frame(dt, t) {
      stage();
      ctx.globalCompositeOperation = "lighter";
      glow(W / 2, MID - BASE * 0.3, BASE * 5.2, "rgba(255,235,200,0.20)");
      glow(W / 2, MID - BASE * 0.3, BASE * 2.6, "rgba(255,250,235," + (0.28 + 0.05 * Math.sin(t * 2)) + ")");
      for (const r of rings) {
        r.r += dt * BASE * 4; r.a -= dt * 0.7;
        if (r.a > 0) {
          ctx.strokeStyle = "rgba(255,240,210," + r.a + ")";
          ctx.lineWidth = 2;
          ctx.beginPath(); ctx.arc(W / 2, MID - BASE * 0.3, r.r, 0, TAU); ctx.stroke();
        }
      }
      rings = rings.filter(r => r.a > 0);
      ctx.globalCompositeOperation = "source-over";
      const L = layout(BASE, 0, 700);
      ctx.fillStyle = "#FFF9EC";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Neon sign", "glow", "a magenta storefront tube — now and then one letter buzzes out", function (u) {
  const { ctx, BASE, rand, layout, stage, glow } = u;
  let dead = -1, deadT = 0, allFlick = 0;
  return {
    press() { allFlick = 0.7; },           // the whole sign stutters, then steadies
    frame(dt, t) {
      stage();
      allFlick = Math.max(0, allFlick - dt);
      deadT -= dt;
      if (deadT <= 0) { dead = Math.random() < 0.55 ? Math.floor(rand(0, 9)) : -1; deadT = rand(0.06, dead >= 0 ? 0.3 : 2.4); }
      const L = layout(BASE, 0, 500);
      for (const l of L) {
        if (l.ch === " ") continue;
        let on = l.i !== dead;
        if (allFlick > 0 && Math.random() < 0.4) on = !on;
        ctx.globalCompositeOperation = "lighter";
        if (on) glow(l.cx, l.y - BASE * 0.32, BASE * 0.9, "rgba(255,80,200,0.30)");
        ctx.globalCompositeOperation = "source-over";
        ctx.font = u.font(500, BASE);
        ctx.fillStyle = on ? "#FFB6E9" : "rgba(120,60,100,0.5)";
        ctx.fillText(l.ch, l.x, l.y);
        ctx.strokeStyle = on ? "rgba(255,150,225,0.9)" : "rgba(120,60,100,0.4)";
        ctx.lineWidth = 1;
        ctx.strokeText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Ember text", "glow", "lit from within — heat shimmer rises off the letters", function (u) {
  const { ctx, BASE, INK, rand, layout, stage, glow } = u;
  let motes = [];
  return {
    press() {                              // stoke it: a burst of sparks
      const L = layout();
      for (let i = 0; i < 14; i++) {
        const l = L[Math.floor(rand(0, L.length))];
        motes.push({ x: l.cx + rand(-4, 4), y: l.y - rand(0, BASE * 0.6), vy: rand(-42, -20), life: 1 });
      }
    },
    frame(dt, t) {
      stage();
      const L = layout(BASE, 0, 600);
      if (Math.random() < 0.35) {
        const l = L[Math.floor(rand(0, L.length))];
        if (l.ch !== " ") motes.push({ x: l.cx + rand(-3, 3), y: l.y - rand(0, BASE * 0.5), vy: rand(-26, -12), life: 0.8 });
      }
      ctx.globalCompositeOperation = "lighter";
      for (const l of L) {
        if (l.ch === " ") continue;        // each letter holds a coal at a slightly different heat
        const heat = 0.5 + 0.5 * Math.sin(t * 1.7 + l.i * 1.31);
        glow(l.cx, l.y - BASE * 0.28, BASE * 0.65, "rgba(255," + Math.round(90 + heat * 90) + ",40," + (0.18 + heat * 0.14) + ")");
      }
      for (const m of motes) {
        m.y += m.vy * dt; m.x += Math.sin(m.y * 0.15) * 12 * dt; m.life -= dt * 1.1;
        if (m.life > 0) glow(m.x, m.y, 2.5 + m.life * 2, "rgba(255,160,70," + m.life * 0.7 + ")");
      }
      motes = motes.filter(m => m.life > 0);
      ctx.globalCompositeOperation = "source-over";
      for (const l of L) {
        const heat = 0.5 + 0.5 * Math.sin(t * 1.7 + l.i * 1.31);
        ctx.fillStyle = "rgb(255," + Math.round(170 + heat * 60) + "," + Math.round(110 + heat * 60) + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Beacon sweep", "glow", "a lighthouse beam crosses the phrase, lighting letters as it passes", function (u) {
  const { ctx, W, MID, BASE, DIM, layout, stage, glow } = u;
  let hurry = 0;
  return {
    press() { hurry = 1; },
    frame(dt, t) {
      stage();
      hurry = Math.max(0, hurry - dt * 0.5);
      const bx = W * (0.5 + 0.55 * Math.sin(t * (0.8 + hurry * 2.2)));   // the beam's centre
      ctx.globalCompositeOperation = "lighter";
      glow(bx, MID - BASE * 0.3, BASE * 2.2, "rgba(255,245,200,0.22)");
      ctx.globalCompositeOperation = "source-over";
      const L = layout();
      for (const l of L) {
        const k = Math.max(0, 1 - Math.abs(l.cx - bx) / (BASE * 2.2));
        ctx.fillStyle = k > 0.02 ? "rgba(255,248,220," + Math.min(1, 0.25 + k) + ")" : DIM;
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Chromatic halo", "glow", "the glow splits into red, green, and blue rings that drift and re-merge", function (u) {
  const { ctx, W, MID, BASE, layout, stage, glow, TAU } = u;
  let snap = 0;
  return {
    press() { snap = 1; },                 // pull the channels back together
    frame(dt, t) {
      stage();
      snap = Math.max(0, snap - dt * 0.8);
      const drift = BASE * 0.5 * (0.5 + 0.5 * Math.sin(t * 0.7)) * (1 - snap);
      const cx = W / 2, cy = MID - BASE * 0.3;
      ctx.globalCompositeOperation = "lighter";
      glow(cx - drift, cy, BASE * 2.2, "rgba(255,60,90,0.16)");
      glow(cx + drift * 0.5, cy - drift * 0.6, BASE * 2.2, "rgba(70,255,140,0.14)");
      glow(cx + drift * 0.5, cy + drift * 0.6, BASE * 2.2, "rgba(80,120,255,0.18)");
      ctx.globalCompositeOperation = "source-over";
      const L = layout();
      ctx.fillStyle = "#F2F0FA";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

/* ============================== TYPEWRITERS ============================== */

def("Typewriter", "type", "letter by letter, block caret and all — press to retype", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // the classic: an integer count of visible letters, advanced on a timer
  let shown = 0, timer = 0, rest = 0;
  return {
    press() { shown = 0; timer = 0; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (shown < L.length) {
        timer += dt;
        if (timer > 0.12) { timer = 0; shown++; }
      } else {
        rest += dt;                        // done: sit with it a moment, then retype
        if (rest > 3.5) { rest = 0; shown = 0; }
      }
      ctx.fillStyle = INK;
      for (const l of L) if (l.i < shown) ctx.fillText(l.ch, l.x, l.y);
      if (Math.sin(t * 7) > -0.2) {        // the caret blinks — a block after the last letter
        const cx = shown < L.length ? L[shown].x : L[L.length - 1].x + L[L.length - 1].w + 2;
        ctx.fillRect(cx, L[0].y - BASE * 0.72, BASE * 0.5, BASE * 0.82);
      }
    }
  };
});

def("Hesitant typist", "type", "types unevenly — thinks before words, hovers mid-phrase", function (u) {
  const { ctx, INK, BASE, PHRASE, rand, layout, stage } = u;
  let shown = 0, wait = 0.3;
  function delayFor(i) {                   // the hesitation is all in this one function
    if (i >= PHRASE.length) return 0;
    if (PHRASE[i] === " ") return rand(0.5, 1.1);          // breathe before the next word
    if (Math.random() < 0.15) return rand(0.4, 0.9);       // …or just lose the thread briefly
    return rand(0.05, 0.22);
  }
  return {
    press() { shown = 0; wait = 0.2; },
    frame(dt, t) {
      stage();
      const L = layout();
      wait -= dt;
      if (wait <= 0) {
        if (shown < L.length) {            // one more letter, then decide how long to dither
          shown++;
          wait = shown === L.length ? 4 : delayFor(shown);
        } else { shown = 0; wait = 0.3; }  // rested long enough — begin again
      }
      ctx.fillStyle = INK;
      for (const l of L) if (l.i < shown) ctx.fillText(l.ch, l.x, l.y);
      if (Math.sin(t * 6) > 0) {
        const cx = shown < L.length ? L[shown].x : L[L.length - 1].x + L[L.length - 1].w + 2;
        ctx.fillRect(cx, L[0].y + 3, BASE * 0.5, 2);       // a thin underline caret — less sure of itself
      }
    }
  };
});

def("Backspace & correct", "type", "types a wrong letter now and then, notices, backspaces, fixes it", function (u) {
  const { ctx, INK, BASE, PHRASE, rand, scramble, layout, stage } = u;
  let typed = "", wrong = false, wait = 0.3, rest = 0;
  return {
    press() { typed = ""; wrong = false; rest = 0; wait = 0.2; },
    frame(dt, t) {
      stage();
      const L = layout();
      wait -= dt;
      if (wait <= 0) {
        if (wrong) { typed = typed.slice(0, -1); wrong = false; wait = 0.22; }   // the backspace
        else if (typed.length < PHRASE.length) {
          if (Math.random() < 0.18) { typed += scramble(); wrong = true; wait = rand(0.3, 0.55); }  // the slip (and the noticing)
          else { typed += PHRASE[typed.length]; wait = rand(0.07, 0.16); }
        } else { rest += dt; if (rest > 3) { typed = ""; rest = 0; } wait = 0.1; }
      }
      ctx.fillStyle = INK;
      for (let i = 0; i < typed.length; i++) {
        const bad = wrong && i === typed.length - 1;
        ctx.fillStyle = bad ? "#E89A9A" : INK;
        ctx.fillText(typed[i], L[i].x, L[i].y);
      }
      if (Math.sin(t * 7) > -0.2 && typed.length <= L.length) {
        const cx = typed.length < L.length ? L[typed.length].x : L[L.length - 1].x + L[L.length - 1].w + 2;
        ctx.fillStyle = INK;
        ctx.fillRect(cx, L[0].y - BASE * 0.72, BASE * 0.5, BASE * 0.82);
      }
    }
  };
});

def("Word by word", "type", "whole words appear at a time, each with a small settle", function (u) {
  const { ctx, INK, BASE, PHRASE, layout, stage } = u;
  const starts = [0];
  for (let i = 0; i < PHRASE.length; i++) if (PHRASE[i] === " ") starts.push(i + 1);
  let shown = 0, timer = 0, pop = 0;
  function wordOf(i) { let w = 0; for (let s = 1; s < starts.length; s++) if (i >= starts[s]) w = s; return w; }
  return {
    press() { shown = 0; timer = 0; },
    frame(dt, t) {
      stage();
      timer += dt; pop = Math.max(0, pop - dt * 3);
      if (timer > (shown < starts.length ? 0.9 : 3.2)) {
        timer = 0;
        shown = shown < starts.length ? shown + 1 : 0;
        pop = 1;
      }
      const L = layout();
      for (const l of L) {
        const w = wordOf(l.i);
        if (w >= shown) continue;
        const fresh = (w === shown - 1) ? pop : 0;         // the newest word lands a touch large
        ctx.save();
        ctx.translate(l.cx, l.y);
        ctx.scale(1 + fresh * 0.12, 1 + fresh * 0.12);
        ctx.fillStyle = INK;
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Teletype", "type", "each letter slams in and jolts the whole line — newsroom urgency", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  let shown = 0, timer = 0, jolt = 0, rest = 0;
  return {
    press() { shown = 0; rest = 0; },
    frame(dt, t) {
      stage();
      jolt = Math.max(0, jolt - dt * 6);
      const L = layout(BASE, 0, 600);
      if (shown < L.length) {
        timer += dt;
        if (timer > 0.09) { timer = 0; shown++; jolt = 1; }
      } else { rest += dt; if (rest > 3) { rest = 0; shown = 0; } }
      ctx.save();
      ctx.translate(rand(-1, 1) * jolt * 2.5, rand(-1, 1) * jolt * 1.5);   // the machine kicks
      ctx.fillStyle = INK;
      for (const l of L) if (l.i < shown) ctx.fillText(l.ch, l.x, l.y);
      ctx.restore();
    }
  };
});

def("Dialogue box", "type", "an RPG text box fills slowly — press to fast-forward, like every player ever", function (u) {
  const { ctx, W, H, MID, INK, BASE, PHRASE, layout, stage } = u;
  let progress = 0, fast = false, rest = 0;
  return {
    press() {
      if (progress < PHRASE.length) fast = true;           // first press: hurry
      else { progress = 0; fast = false; rest = 0; }       // at the ▼: next page (same page, this being a demo)
    },
    frame(dt, t) {
      stage();
      const L = layout(BASE * 0.85);
      // the box
      const bx = W * 0.06, by = MID - BASE * 1.1, bw = W * 0.88, bh = BASE * 1.9;
      ctx.fillStyle = "rgba(20,16,38,0.85)";
      ctx.fillRect(bx, by, bw, bh);
      ctx.strokeStyle = "rgba(190,185,225,0.7)";
      ctx.lineWidth = 1.5;
      ctx.strokeRect(bx, by, bw, bh);
      if (progress < L.length) progress += dt * (fast ? 60 : 9);
      else { rest += dt; if (rest > 4) { rest = 0; progress = 0; fast = false; } }
      ctx.fillStyle = INK;
      for (const l of L) if (l.i < progress) ctx.fillText(l.ch, l.x, l.y);
      if (progress >= L.length && Math.sin(t * 4) > 0) {   // the patient ▼
        ctx.beginPath();
        ctx.moveTo(bx + bw - 16, by + bh - 12);
        ctx.lineTo(bx + bw - 8, by + bh - 12);
        ctx.lineTo(bx + bw - 12, by + bh - 6);
        ctx.fill();
      }
    }
  };
});

def("Two hands", "type", "typed from both ends at once, meeting in the middle", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let steps = 0, timer = 0, rest = 0;
  return {
    press() { steps = 0; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      const need = Math.ceil(L.length / 2);
      if (steps < need) {
        timer += dt;
        if (timer > 0.16) { timer = 0; steps++; }
      } else { rest += dt; if (rest > 3.2) { rest = 0; steps = 0; } }
      ctx.fillStyle = INK;
      for (const l of L)
        if (l.i < steps || l.i >= L.length - steps) ctx.fillText(l.ch, l.x, l.y);
      if (steps < need && Math.sin(t * 7) > -0.2) {        // two carets, closing in
        ctx.fillRect(L[steps].x, L[0].y - BASE * 0.72, BASE * 0.45, BASE * 0.82);
        const r = L[L.length - 1 - steps];
        ctx.fillRect(r.x + r.w - BASE * 0.45, r.y - BASE * 0.72, BASE * 0.45, BASE * 0.82);
      }
    }
  };
});

def("Dictation", "type", "an underline sweeps ahead and the letters catch up in little bursts", function (u) {
  const { ctx, INK, DIM, BASE, rand, layout, stage } = u;
  let sweep = 0, shown = 0, burst = 0, rest = 0;
  return {
    press() { sweep = 0; shown = 0; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (shown >= L.length) { rest += dt; if (rest > 3) { rest = 0; sweep = 0; shown = 0; } }
      else {
        sweep = Math.min(L.length, sweep + dt * 6);        // the pen runs ahead…
        burst -= dt;
        if (burst <= 0 && shown < Math.floor(sweep)) {     // …the voice catches up in bursts
          shown = Math.min(Math.floor(sweep), shown + Math.floor(rand(1, 3.5)));
          burst = rand(0.2, 0.5);
        }
      }
      for (const l of L) {
        if (l.ch === " ") continue;
        if (l.i < shown) { ctx.fillStyle = INK; ctx.fillText(l.ch, l.x, l.y); }
        else if (l.i < sweep) {            // swept but unspoken: the waiting underline
          ctx.fillStyle = DIM;
          ctx.fillRect(l.x, l.y + 4, l.w * 0.8, 2);
        }
      }
    }
  };
});

/* ============================== FADES & PULSES ============================== */

def("Firefly pulse", "fade", "dim to visible and back, the whole phrase on one slow pulse — press to hold it bright", function (u) {
  const { ctx, BASE, layout, stage, TAU } = u;
  let hold = 0;
  return {
    press() { hold = 2.5; },
    frame(dt, t) {
      stage();
      hold = Math.max(0, hold - dt);
      const a = hold > 0 ? 1 : 0.08 + 0.92 * Math.pow(0.5 + 0.5 * Math.sin(t * TAU / 3.6), 2);
      const L = layout();
      ctx.fillStyle = "rgba(232,229,244," + a + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Fade in order", "fade", "letters fade up left to right, hold, then fade away the same way", function (u) {
  const { ctx, BASE, layout, stage } = u;
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      const inEnd = L.length * 0.14 + 0.5;                 // when the last letter is fully up
      const cycle = inEnd + 2 + inEnd + 1;                 // in, hold, out, dark
      const c = clock % cycle;
      for (const l of L) {
        let a;
        if (c < inEnd + 2) a = Math.min(1, Math.max(0, (c - l.i * 0.14) / 0.5));
        else a = 1 - Math.min(1, Math.max(0, (c - (inEnd + 2) - l.i * 0.14) / 0.5));
        ctx.fillStyle = "rgba(232,229,244," + a + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Fade lottery", "fade", "letters fade in, but the order is drawn from a hat — press to reshuffle", function (u) {
  const { ctx, BASE, PHRASE, rand, layout, stage } = u;
  let order = [], clock = 0;
  function shuffle() {
    order = PHRASE.split("").map((_, i) => i);
    for (let i = order.length - 1; i > 0; i--) {
      const j = Math.floor(rand(0, i + 1));
      const k = order[i]; order[i] = order[j]; order[j] = k;
    }
  }
  shuffle();
  return {
    press() { shuffle(); clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const cycle = order.length * 0.16 + 3;
      if (clock > cycle) { clock = 0; shuffle(); }         // every round is a new drawing
      const L = layout();
      for (const l of L) {
        const rank = order.indexOf(l.i);
        const a = Math.min(1, Math.max(0, (clock - rank * 0.16) / 0.45));
        ctx.fillStyle = "rgba(232,229,244," + a + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Fluorescent", "fade", "an old tube starting up: erratic stutters, then steady light", function (u) {
  const { ctx, W, MID, BASE, rand, layout, stage, glow } = u;
  let phase = 0, level = 0, next = 0;
  return {
    press() { phase = 0; level = 0; },     // flip the switch again
    frame(dt, t) {
      stage();
      phase += dt;
      if (phase < 2.2) {                   // the struggle
        next -= dt;
        if (next <= 0) { level = Math.random() < 0.55 ? rand(0.5, 1) : rand(0, 0.15); next = rand(0.03, 0.22); }
      } else level = Math.min(1, level + dt * 2);          // the hum settles
      ctx.globalCompositeOperation = "lighter";
      glow(W / 2, MID - BASE * 0.3, BASE * 3, "rgba(200,255,235," + level * 0.14 + ")");
      ctx.globalCompositeOperation = "source-over";
      const L = layout();
      ctx.fillStyle = "rgba(225,255,242," + (0.06 + level * 0.94) + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      if (phase > 8) phase = 0;            // and every so often, the tube gives out and tries again
    }
  };
});

def("Tide", "fade", "an opacity wave flows through the letters, endlessly", function (u) {
  const { ctx, BASE, layout, stage } = u;
  let speed = 1;
  return {
    press() { speed = 3; },
    frame(dt, t) {
      stage();
      speed = Math.max(1, speed - dt);
      const L = layout();
      for (const l of L) {
        const a = 0.15 + 0.85 * Math.pow(0.5 + 0.5 * Math.sin(t * 2 * speed - l.i * 0.7), 1.5);
        ctx.fillStyle = "rgba(200,225,255," + a + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Afterimage", "fade", "a bright blink, then the long retinal fade — press to blink again", function (u) {
  const { ctx, BASE, layout, stage } = u;
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 7) age = 0;                // it re-blinks on its own, eventually
      const a = age < 0.12 ? 1 : Math.max(0.03, Math.exp(-(age - 0.12) * 0.9));
      const L = layout(BASE, 0, age < 0.12 ? 700 : 400);   // the flash is bold; the ghost is thin
      ctx.fillStyle = "rgba(240,238,255," + a + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Half-light", "fade", "odd and even letters trade visibility in a slow crossfade", function (u) {
  const { ctx, BASE, layout, stage, TAU } = u;
  let hurry = 0;
  return {
    press() { hurry = 2; },
    frame(dt, t) {
      stage();
      hurry = Math.max(0, hurry - dt);
      const k = 0.5 + 0.5 * Math.sin(t * TAU / (hurry > 0 ? 1 : 4));   // the trade
      const L = layout();
      for (const l of L) {
        const a = 0.1 + 0.9 * (l.i % 2 === 0 ? k : 1 - k);
        ctx.fillStyle = "rgba(232,229,244," + a + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

/* ============================== GROW & SHRINK ============================== */

def("Heartbeat", "scale", "the phrase expands and shrinks on a lub-dub — press to race it", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  let race = 0;
  return {
    press() { race = 2.5; },
    frame(dt, t) {
      stage();
      race = Math.max(0, race - dt);
      const bpm = race > 0 ? 150 : 62;
      const beat = (t * bpm / 60) % 1;     // lub at 0, dub at 0.28, long rest after
      const k = Math.max(Math.exp(-beat * 14), 0.72 * Math.exp(-Math.max(0, beat - 0.28) * 14) * (beat > 0.28 ? 1 : 0));
      const s = 1 + k * 0.16;
      const L = layout(BASE, 0, 500);
      ctx.fillStyle = INK;
      for (const l of L) {
        ctx.save();
        const mid = W / 2;
        ctx.translate(mid + (l.cx - mid) * s, l.y);        // scale about the phrase's centre
        ctx.scale(s, s);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Pop-in", "scale", "letters pop in one by one with a springy overshoot", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      const cycle = L.length * 0.11 + 3.4;
      if (clock > cycle) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        const a = (clock - l.i * 0.11) / 0.4;              // each letter's own little life
        if (a <= 0) continue;
        const s = a >= 1 ? 1 : 1.75 * a * Math.exp(1 - 1.75 * a) * 1.55;   // overshoot then settle
        ctx.save();
        ctx.translate(l.cx, l.y);
        ctx.scale(Math.max(0.01, s), Math.max(0.01, s));
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Rubber band", "scale", "press to stretch it tall — it springs back with a jelly wobble", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let vy = 0, sy = 1;                      // a spring in one dimension
  return {
    press() { vy = 9; },                   // yank
    frame(dt, t) {
      stage();
      const k = 90, damp = 6;              // stiffness and calm-down, the two spring dials
      vy += (1 - sy) * k * dt - vy * damp * dt;
      sy += vy * dt;
      const sx = 1 / Math.max(0.4, Math.sqrt(sy));         // conserve area: taller means narrower
      const L = layout(BASE, 0, 600);
      ctx.fillStyle = INK;
      for (const l of L) {
        ctx.save();
        const mid = (L[0].x + L[L.length - 1].x + L[L.length - 1].w) / 2;
        ctx.translate(mid + (l.cx - mid) * sx, l.y);
        ctx.scale(sx, sy);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Zoom arrival", "scale", "arrives from enormous — rushes past, then settles into place", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 6) age = 0;
      const p = Math.min(1, age / 0.9);
      const e = 1 - Math.pow(1 - p, 3);    // ease-out cubic: fast arrival, gentle landing
      const s = 6 - 5 * e - Math.max(0, (1 - e) - 0.85) * 8;
      const a = Math.min(1, p * 2);
      const L = layout(BASE, 0, 600);
      ctx.fillStyle = "rgba(232,229,244," + a + ")";
      const mid = u.W / 2;
      for (const l of L) {
        ctx.save();
        ctx.translate(mid + (l.cx - mid) * s, l.y - (s - 1) * BASE * 0.3);
        ctx.scale(s, s);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Accordion", "scale", "the letter-spacing squeezes shut and wheezes open, letters leaning as it goes", function (u) {
  const { ctx, INK, BASE, layout, stage, TAU } = u;
  let push = 0;
  return {
    press() { push = 1; },
    frame(dt, t) {
      stage();
      push = Math.max(0, push - dt * 0.9);
      const k = 0.5 + 0.5 * Math.sin(t * TAU / 4.6 + push * 3);
      const spacing = -BASE * 0.18 + k * BASE * 0.5;       // from overlapped to airy
      const L = layout(BASE, spacing, 500);
      ctx.fillStyle = INK;
      for (const l of L) {
        ctx.save();
        ctx.translate(l.cx, l.y);
        ctx.rotate((k - 0.5) * 0.14 * (l.i % 2 ? 1 : -1)); // the bellows lean
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Pinpoint", "scale", "the whole phrase grows out of a single point of light", function (u) {
  const { ctx, W, MID, INK, BASE, layout, stage, glow } = u;
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 6.5) age = 0;
      const p = Math.min(1, age / 1.4);
      const e = p * p * (3 - 2 * p);       // smoothstep: born slow, grows sure
      ctx.globalCompositeOperation = "lighter";
      glow(W / 2, MID - BASE * 0.3, 4 + (1 - e) * BASE, "rgba(220,210,255," + (0.7 - e * 0.55) + ")");
      ctx.globalCompositeOperation = "source-over";
      if (e <= 0.02) return;
      const L = layout(BASE, 0, 500);
      ctx.fillStyle = "rgba(232,229,244," + e + ")";
      const mid = W / 2;
      for (const l of L) {
        ctx.save();
        ctx.translate(mid + (l.cx - mid) * e, l.y);
        ctx.scale(Math.max(0.01, e), Math.max(0.01, e));
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Giant's whisper", "scale", "swells until it barely fits, then snaps small and starts over", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  let s = 0.6, snap = 0;
  return {
    press() { snap = 1; },                 // pop it early
    frame(dt, t) {
      stage();
      if (snap > 0) { s = 0.6; snap = 0; }
      s += dt * 0.16;                      // the slow, oblivious swell
      if (s > 1.45) s = 0.6;
      const L = layout(BASE * s, 0, s > 1.2 ? 700 : 400);  // it even leans bold near the brim
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      if (s > 1.2) {                       // the walls it's about to meet
        ctx.strokeStyle = "rgba(232,229,244," + ((s - 1.2) * 1.2) + ")";
        ctx.lineWidth = 1;
        ctx.strokeRect(2, 2, W - 4, u.H - 4);
      }
    }
  };
});

/* ============================== SCRAMBLES & DECODES ============================== */

def("Decoder", "scramble", "a1h7 8u3d — random letters churn, resolving one by one into the phrase", function (u) {
  const { ctx, INK, DIM, BASE, PHRASE, scramble, layout, stage } = u;
  // the churn is honest randomness; the resolve is just an index that grows
  let fixed = 0, timer = 0, churn = [], churnT = 0, rest = 0;
  return {
    press() { fixed = 0; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      churnT += dt;
      if (churnT > 0.05) {                 // refresh the wrong letters at 20fps — readable churn
        churnT = 0;
        churn = L.map(() => scramble());
      }
      if (fixed < L.length) {
        timer += dt;
        if (timer > 0.22) { timer = 0; fixed++; }
      } else { rest += dt; if (rest > 3.2) { rest = 0; fixed = 0; } }
      for (const l of L) {
        if (l.ch === " ") continue;
        const done = l.i < fixed;
        ctx.fillStyle = done ? INK : "rgba(150,220,180,0.75)";
        ctx.fillText(done ? l.ch : churn[l.i], l.x, l.y);
      }
    }
  };
});

def("Slot machine", "scramble", "each column scrolls a strip of glyphs, stopping left to right on the right one", function (u) {
  const { ctx, INK, BASE, GLYPHS, rand, layout, stage } = u;
  let reels = null, rest = 0, spinT = 0;
  function spinUp(L) {
    reels = L.map(l => ({ v: rand(14, 20), off: rand(0, GLYPHS.length), stopAt: 0.8 + l.i * 0.28, done: false }));
    spinT = 0;
  }
  return {
    press() { reels = null; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!reels) spinUp(L);
      spinT += dt;
      const lh = BASE * 1.08;              // the strip's line height
      for (const l of L) {
        if (l.ch === " ") continue;
        const r = reels[l.i];
        if (!r.done) {
          if (spinT > r.stopAt) r.v = Math.max(0, r.v - dt * 30);        // the brake
          r.off += r.v * dt;
          if (spinT > r.stopAt && r.v < 0.8) { r.done = true; r.off = 0; }
        }
        ctx.save();                        // each column is its own little window
        ctx.beginPath();
        ctx.rect(l.x - 2, l.y - BASE * 0.95, l.w + 4, BASE * 1.35);
        ctx.clip();
        if (r.done) {
          ctx.fillStyle = INK;
          ctx.fillText(l.ch, l.x, l.y);
        } else {
          const frac = r.off % 1;
          for (let k = -1; k <= 1; k++) {  // three glyphs of the passing strip
            const gi = (Math.floor(r.off) + k + GLYPHS.length * 4) % GLYPHS.length;
            ctx.fillStyle = "rgba(180,220,255," + (0.75 - Math.abs(k - frac) * 0.3) + ")";
            ctx.fillText(GLYPHS[gi], l.x, l.y + (k - frac) * lh);
          }
        }
        ctx.restore();
      }
      if (reels.every((r, i) => L[i].ch === " " || r.done)) {
        rest += dt;
        if (rest > 3) { reels = null; rest = 0; }
      }
    }
  };
});

def("Jumble home", "scramble", "the right letters in the wrong places drift home to correct placement", function (u) {
  const { ctx, W, H, INK, BASE, rand, layout, stage } = u;
  let pts = null, going = 0, rest = 0;
  function scatter(L) {
    pts = L.map(l => ({ x: rand(W * 0.08, W * 0.85), y: rand(H * 0.15, H * 0.85), r: rand(-1.5, 1.5) }));
    going = 0; rest = 0;
  }
  return {
    press() { pts = null; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!pts) scatter(L);
      going += dt;
      const p = Math.min(1, Math.max(0, (going - 0.7) / 1.6));           // a beat of pure jumble first
      const e = p * p * (3 - 2 * p);
      ctx.fillStyle = INK;
      for (const l of L) {
        const s = pts[l.i];
        const x = s.x + (l.cx - s.x) * e;
        const y = s.y + (l.y - s.y) * e;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(s.r * (1 - e));         // they also un-tilt as they arrive
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
      if (p >= 1) { rest += dt; if (rest > 3) pts = null; }
    }
  };
});

def("Matrix rain", "scramble", "glyph rain falls; the phrase crystallizes out of the downpour", function (u) {
  const { ctx, W, H, BASE, GLYPHS, rand, scramble, layout, stage } = u;
  const cols = Math.floor(W / 12);
  let drops = [], born = 0, resolve = 0;
  for (let i = 0; i < cols; i++) drops.push({ x: 6 + i * 12, y: rand(-H, H), v: rand(40, 110) });
  return {
    press() { resolve = 0; },              // dissolve back into the rain, then re-crystallize
    frame(dt, t) {
      stage();
      resolve += dt;
      ctx.font = "12px 'Spline Sans Mono', monospace";
      for (const d of drops) {             // the rain never stops; the phrase just outshines it
        d.y += d.v * dt;
        if (d.y > H + 20) { d.y = rand(-40, -10); d.v = rand(40, 110); }
        ctx.fillStyle = "rgba(90,200,120,0.35)";
        ctx.fillText(scramble(), d.x, d.y);
        ctx.fillStyle = "rgba(160,255,190,0.5)";
        ctx.fillText(scramble(), d.x, d.y - 14);
      }
      const L = layout();
      for (const l of L) {
        if (l.ch === " ") continue;
        const k = Math.min(1, Math.max(0, (resolve - 1 - l.i * 0.18) / 0.8));
        if (k <= 0) continue;
        ctx.font = u.font(500, BASE);
        ctx.fillStyle = "rgba(200,255,215," + k + ")";
        ctx.fillText(k < 1 && Math.random() < 0.3 ? scramble() : l.ch, l.x, l.y);
      }
      if (resolve > 9) resolve = 0;
    }
  };
});

def("Anagram walk", "scramble", "the letters keep trading places — press to send them all home", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  let perm = null, from = null, lerp = 1, wait = 0.5, home = 0;
  return {
    press() { home = 3; },                 // three seconds of correct spelling, as a treat
    frame(dt, t) {
      stage();
      const L = layout();
      if (!perm) { perm = L.map((_, i) => i); from = perm.slice(); }
      home = Math.max(0, home - dt);
      lerp = Math.min(1, lerp + dt * 1.6);
      wait -= dt;
      if (wait <= 0 && lerp >= 1 && home <= 0) {           // pick two letters and swap their slots
        from = perm.slice();
        const a = Math.floor(rand(0, L.length)), b = Math.floor(rand(0, L.length));
        const k = perm[a]; perm[a] = perm[b]; perm[b] = k;
        lerp = 0; wait = rand(0.3, 0.9);
      }
      const target = home > 0 ? L.map((_, i) => i) : perm;
      ctx.fillStyle = home > 0 ? "rgba(180,240,200,1)" : INK;
      for (const l of L) {
        const slotNow = target[l.i], slotWas = from[l.i];
        const e = lerp * lerp * (3 - 2 * lerp);
        const x = L[slotWas].cx + (L[slotNow].cx - L[slotWas].cx) * e;
        const arc = Math.sin(e * Math.PI) * (slotNow === slotWas ? 0 : BASE * 0.5);
        ctx.save();
        ctx.translate(x, l.y - arc);       // swaps travel over the line, politely
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Static tune", "scramble", "tuning a radio: a dial sweeps, and where it points, noise becomes words", function (u) {
  const { ctx, W, INK, BASE, rand, scramble, layout, stage } = u;
  let dial = 0, dir = 1;
  return {
    press() { dir = -dir; },               // sweep back the other way
    frame(dt, t) {
      stage();
      dial += dir * dt * 0.35;
      if (dial > 1.3) { dial = 1.3; dir = -1; }
      if (dial < -0.3) { dial = -0.3; dir = 1; }
      const fx = W * dial;                 // the tuned spot
      const L = layout();
      for (const l of L) {
        if (l.ch === " ") continue;
        const k = Math.max(0, 1 - Math.abs(l.cx - fx) / (W * 0.22));     // clarity near the dial
        const clear = k > rand(0, 1) * 0.9;
        ctx.fillStyle = clear ? "rgba(232,229,244," + (0.3 + k * 0.7) + ")" : "rgba(150,145,190,0.4)";
        const jitter = (1 - k) * rand(-1.5, 1.5);
        ctx.fillText(clear ? l.ch : scramble(), l.x, l.y + jitter);
      }
      ctx.fillStyle = "rgba(180,220,255,0.5)";             // the dial's needle, below the line
      ctx.fillRect(fx - 1, u.MID + BASE * 0.5, 2, BASE * 0.3);
    }
  };
});

def("Cipher wheel", "scramble", "every letter steps through the alphabet until it lands on the right one", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  const AL = "abcdefghijklmnopqrstuvwxyz";
  let offs = null, rest = 0;
  return {
    press() { offs = null; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!offs) offs = L.map(() => Math.floor(rand(6, 22)));            // steps still to walk
      let allDone = true;
      for (const l of L) {
        if (l.ch === " ") continue;
        const idx = AL.indexOf(l.ch.toLowerCase());
        if (offs[l.i] > 0) {
          allDone = false;
          offs[l.i] -= dt * 9;             // the wheel turns…
          if (offs[l.i] < 0) offs[l.i] = 0;
        }
        const stepsLeft = Math.ceil(offs[l.i]);
        const showIdx = idx < 0 ? 0 : (idx - stepsLeft + AL.length * 4) % AL.length;
        const settled = stepsLeft === 0;
        ctx.fillStyle = settled ? INK : "rgba(230,200,150,0.75)";
        ctx.fillText(idx < 0 ? l.ch : AL[showIdx], l.x, l.y);
      }
      if (allDone) { rest += dt; if (rest > 3.2) { offs = null; rest = 0; } }
    }
  };
});

def("Number station", "scramble", "cold digits cycle in every slot; press, and the words come through", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  let clear = 0, digits = [], dT = 0;
  return {
    press() { clear = 4; },                // the signal, briefly, means something
    frame(dt, t) {
      stage();
      clear = Math.max(0, clear - dt);
      dT += dt;
      const L = layout();
      if (dT > 0.14) { dT = 0; digits = L.map(() => Math.floor(rand(0, 10))); }
      for (const l of L) {
        if (l.ch === " ") continue;
        if (clear > 0.4 || (clear > 0 && Math.random() < 0.7)) {
          ctx.fillStyle = "rgba(200,235,255,0.95)";
          ctx.fillText(l.ch, l.x, l.y);
        } else {
          ctx.fillStyle = "rgba(140,170,200,0.6)";
          ctx.fillText("" + digits[l.i], l.x, l.y);
        }
      }
      ctx.fillStyle = "rgba(140,170,200,0.35)";
      ctx.font = "10px 'Spline Sans Mono', monospace";
      ctx.fillText(clear > 0 ? "— signal —" : "— numbers —", 8, 14);
    }
  };
});

/* ============================== WAVES & BOUNCES ============================== */

def("Sine wave", "wave", "the letters ride a rolling sine — press to steepen the sea", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let amp = 1;
  return {
    press() { amp = 2.6; },
    frame(dt, t) {
      stage();
      amp = Math.max(1, amp - dt * 1.1);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const y = Math.sin(t * 2.4 - l.i * 0.65) * BASE * 0.16 * amp;
        const tilt = Math.cos(t * 2.4 - l.i * 0.65) * 0.12 * amp;        // letters lean into the slope
        ctx.save();
        ctx.translate(l.cx, l.y + y);
        ctx.rotate(tilt);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Stadium wave", "wave", "one letter jumps, then the next — the crowd goes around forever", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let extra = 0;
  return {
    press() { extra = 1; },                // everyone jumps at once
    frame(dt, t) {
      stage();
      extra = Math.max(0, extra - dt * 1.8);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const phase = (t * 1.1 - l.i * 0.09) % 1;          // each letter's turn comes around
        const jump = phase < 0.22 ? Math.sin(phase / 0.22 * Math.PI) : 0;
        const k = Math.max(jump, extra);
        const squash = 1 - k * 0.18;       // they crouch as they land
        ctx.save();
        ctx.translate(l.cx, l.y - k * BASE * 0.5);
        ctx.scale(1 + k * 0.1, squash + k * 0.35);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Bounce-in", "wave", "letters drop from above and bounce twice before settling", function (u) {
  const { ctx, INK, BASE, H, layout, stage } = u;
  let clock = 0;
  function bounceY(a) {                    // a: seconds since this letter's drop began
    if (a < 0) return -1.4;                // still waiting upstairs
    const g = 9, e = 0.45;                 // gravity and restitution, in phrase-heights
    let v = 0, y = -1.4, tt = a;           // simulate cheaply: three parabolic hops
    for (let hop = 0; hop < 4; hop++) {
      const tImpact = (Math.sqrt(v * v + 2 * g * -y) - v) / g;
      if (tt < tImpact) return y + v * tt + 0.5 * g * tt * tt;
      tt -= tImpact; v = -(v + g * tImpact) * e; y = 0;
      if (Math.abs(v) < 0.3) return 0;
    }
    return 0;
  }
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (clock > L.length * 0.09 + 4) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        const y = bounceY(clock - l.i * 0.09);
        if (y <= -1.39) continue;
        const vNear = Math.abs(y) < 0.02;  // squash only at the floor
        ctx.save();
        ctx.translate(l.cx, l.y + y * BASE * 1.2);
        if (vNear) ctx.scale(1.12, 0.88);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Jelly", "wave", "hovers with a wobble — press somewhere and a ripple runs through from there", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  let waves = [];
  return {
    press(x) { waves.push({ x: x === undefined ? W / 2 : x, age: 0 }); },
    frame(dt, t) {
      stage();
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        let y = Math.sin(t * 3 + l.i * 1.7) * BASE * 0.03;               // the resting wobble
        let s = 1;
        for (const w of waves) {           // every live ripple pushes as it passes
          const d = Math.abs(l.cx - w.x);
          const front = w.age * W * 0.9;
          const k = Math.exp(-Math.pow((d - front) / (BASE * 1.2), 2)) * Math.max(0, 1 - w.age * 1.2);
          y -= k * BASE * 0.35;
          s += k * 0.2;
        }
        ctx.save();
        ctx.translate(l.cx, l.y + y);
        ctx.scale(s, 2 - s);               // bulge one way, squeeze the other
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
      for (const w of waves) w.age += dt;
      waves = waves.filter(w => w.age < 1.2);
    }
  };
});

def("Pendulum", "wave", "each letter hangs from its top corner and swings — never quite in step", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let push = 0;
  return {
    press() { push = 1; },
    frame(dt, t) {
      stage();
      push = Math.max(0, push - dt * 0.5);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        // period drifts with index — neighbours slowly fall out of phase, like real pendulums
        const a = Math.sin(t * (2 + l.i * 0.13)) * (0.12 + push * 0.35);
        ctx.save();
        ctx.translate(l.cx, l.y - BASE * 0.75);            // the pivot, above the letter
        ctx.rotate(a);
        ctx.fillText(l.ch, -l.w / 2, BASE * 0.75);
        ctx.restore();
      }
    }
  };
});

def("Buoy", "wave", "the letters float on unseen water — bobbing, tilting, drifting a little", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let chop = 0;
  return {
    press() { chop = 1; },                 // a boat went past
    frame(dt, t) {
      stage();
      chop = Math.max(0, chop - dt * 0.4);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const k = 1 + chop * 2;
        const y = (Math.sin(t * 1.3 + l.i * 0.9) * 0.5 + Math.sin(t * 2.7 + l.i * 2.3) * 0.3) * BASE * 0.12 * k;
        const tilt = Math.sin(t * 1.1 + l.i * 1.4) * 0.09 * k;
        ctx.save();
        ctx.translate(l.cx, l.y + y);
        ctx.rotate(tilt);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Skip rope", "wave", "the whole line is a turning rope — the middle swings widest", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let speed = 1;
  return {
    press() { speed = 2.2; },
    frame(dt, t) {
      stage();
      speed = Math.max(1, speed - dt * 0.8);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const arc = Math.sin(l.i / (l.n - 1) * Math.PI);   // pinned at both ends
        const y = Math.sin(t * 3.2 * speed) * arc * BASE * 0.42;
        const sx = 1 - Math.abs(Math.sin(t * 3.2 * speed)) * arc * 0.12; // foreshortening as it turns
        ctx.save();
        ctx.translate(l.cx, l.y + y);
        ctx.scale(1, Math.max(0.5, sx));
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Ripple press", "wave", "still water — press anywhere and rings of motion radiate through the letters", function (u) {
  const { ctx, W, INK, DIM, BASE, MID, layout, stage, TAU } = u;
  let drops = [];
  return {
    press(x, y) { drops.push({ x: x === undefined ? W / 2 : x, y: y === undefined ? MID : y, age: 0 }); },
    frame(dt, t) {
      stage();
      const L = layout();
      for (const d of drops) {             // the visible rings, for honesty
        d.age += dt;
        const r = d.age * W * 0.6;
        ctx.strokeStyle = "rgba(160,190,255," + Math.max(0, 0.4 - d.age * 0.33) + ")";
        ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(d.x, d.y, r, 0, TAU); ctx.stroke();
      }
      ctx.fillStyle = INK;
      for (const l of L) {
        let y = 0;
        for (const d of drops) {
          const dist = Math.hypot(l.cx - d.x, l.y - BASE * 0.3 - d.y);
          const front = d.age * W * 0.6;
          y -= Math.exp(-Math.pow((dist - front) / (BASE * 0.9), 2)) * Math.max(0, 1 - d.age * 0.8) * BASE * 0.3;
        }
        ctx.fillText(l.ch, l.x, l.y + y);
      }
      drops = drops.filter(d => d.age < 1.4);
      if (drops.length === 0 && Math.floor(t) % 5 === 4 && (t % 1) < dt) // the pond drips on its own when ignored
        drops.push({ x: W * (0.3 + 0.4 * Math.random()), y: MID - BASE, age: 0 });
    }
  };
});

/* ============================== ARRIVALS ============================== */

def("Roll call", "slide", "letters slide in from the left, one after another, and take their places", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (clock > L.length * 0.1 + 4) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (clock - l.i * 0.1) / 0.55));
        if (p <= 0) continue;
        const e = 1 - Math.pow(1 - p, 3);
        const x = -BASE + (l.cx + BASE) * e;               // from just off the left edge
        ctx.globalAlpha = Math.min(1, p * 2);
        ctx.save();
        ctx.translate(x, l.y);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
        ctx.globalAlpha = 1;
      }
    }
  };
});

def("Rain down", "slide", "letters fall into place from above, staggered like weather", function (u) {
  const { ctx, INK, BASE, H, rand, layout, stage } = u;
  let clock = 0, stagger = null;
  return {
    press() { clock = 0; stagger = null; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (!stagger) stagger = L.map(() => rand(0, 0.9));   // the weather is not a metronome
      if (clock > 5) { clock = 0; stagger = null; return; }
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (clock - stagger[l.i]) / 0.6));
        if (p <= 0) continue;
        const e = p * p;                   // accelerating, like falling things do
        const y = -H * 0.4 + (l.y + H * 0.4) * e;
        ctx.globalAlpha = Math.min(1, p * 3);
        ctx.fillText(l.ch, l.x, y);
        ctx.globalAlpha = 1;
      }
    }
  };
});

def("Rise up", "slide", "credits-style: the phrase rises from below and eases to a stop", function (u) {
  const { ctx, INK, BASE, H, layout, stage } = u;
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 6) age = 0;
      const p = Math.min(1, age / 1.3);
      const e = 1 - Math.pow(1 - p, 2);
      const dy = (1 - e) * H * 0.55;
      const L = layout();
      ctx.fillStyle = "rgba(232,229,244," + Math.min(1, p * 1.6) + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y + dy);
    }
  };
});

def("Crossroads", "slide", "odd letters arrive from the left, even from the right, interleaving", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 5.5) age = 0;
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (age - l.i * 0.05) / 0.8));
        const e = 1 - Math.pow(1 - p, 3);
        const fromX = l.i % 2 === 0 ? -BASE : W + BASE;
        const x = fromX + (l.cx - fromX) * e;
        ctx.globalAlpha = Math.min(1, p * 2.5);
        ctx.save(); ctx.translate(x, l.y); ctx.fillText(l.ch, -l.w / 2, 0); ctx.restore();
        ctx.globalAlpha = 1;
      }
    }
  };
});

def("Compass", "slide", "every letter flies in from its own compass point — press to redraw the winds", function (u) {
  const { ctx, W, H, INK, BASE, rand, layout, stage } = u;
  let age = 0, dirs = null;
  return {
    press() { age = 0; dirs = null; },
    frame(dt, t) {
      stage();
      age += dt;
      const L = layout();
      if (!dirs) dirs = L.map(() => rand(0, u.TAU));       // each letter is assigned a wind
      if (age > 5.5) { age = 0; dirs = null; return; }
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (age - l.i * 0.04) / 0.9));
        const e = 1 - Math.pow(1 - p, 3);
        const R = Math.max(W, H) * 0.6;
        const x = l.cx + Math.cos(dirs[l.i]) * R * (1 - e);
        const y = l.y + Math.sin(dirs[l.i]) * R * (1 - e);
        ctx.globalAlpha = Math.min(1, p * 2);
        ctx.save(); ctx.translate(x, y); ctx.fillText(l.ch, -l.w / 2, 0); ctx.restore();
        ctx.globalAlpha = 1;
      }
    }
  };
});

def("Tracking", "slide", "cinematic titles: the letters begin far apart and drift together", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 7) age = 0;
      const p = Math.min(1, age / 2.4);
      const e = 1 - Math.pow(1 - p, 2);
      const spacing = BASE * 0.55 * (1 - e);               // the whole effect is one number
      const L = layout(BASE * (0.92 + e * 0.08), spacing, 300);
      ctx.fillStyle = "rgba(232,229,244," + (0.25 + 0.75 * e) + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Whoosh", "slide", "the phrase streaks in fast from the left, speed lines and all", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 4.5) age = 0;
      const p = Math.min(1, age / 0.55);
      const e = 1 - Math.pow(1 - p, 4);    // very fast, very sudden stop
      const dx = (1 - e) * -W * 0.9;
      const L = layout(BASE, 0, 600);
      if (p < 1) {                         // the streaks live only during the travel
        ctx.strokeStyle = "rgba(180,200,255," + (1 - p) * 0.5 + ")";
        ctx.lineWidth = 2;
        for (const l of L) {
          if (l.ch === " " || l.i % 2) continue;
          ctx.beginPath();
          ctx.moveTo(l.cx + dx - BASE * 2.2 * (1 - e), l.y - BASE * 0.3);
          ctx.lineTo(l.cx + dx, l.y - BASE * 0.3);
          ctx.stroke();
        }
      }
      const lean = (1 - e) * -0.35;        // it leans back against its own speed
      ctx.fillStyle = INK;
      for (const l of L) {
        ctx.save();
        ctx.translate(l.cx + dx, l.y);
        ctx.transform(1, 0, lean, 1, 0, 0);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Conveyor", "slide", "letters ride a belt across the card, pause to spell the phrase, then ride on", function (u) {
  const { ctx, W, INK, DIM, BASE, layout, stage } = u;
  const PERIOD = 7;                        // seconds per full crossing
  let shift = 0;
  return {
    press() { shift = 0.4; },              // nudge the belt
    frame(dt, t) {
      stage();
      shift = Math.max(0, shift - dt);
      const tt = (t * (shift > 0 ? 2.5 : 1)) % PERIOD;
      // piecewise: enter (0–2), dwell (2–5), leave (5–7)
      let dx;
      if (tt < 2) dx = (1 - easeOut(tt / 2)) * W * 0.75;
      else if (tt < 5) dx = 0;
      else dx = -easeIn((tt - 5) / 2) * W * 0.75;
      function easeOut(p) { return 1 - Math.pow(1 - p, 3); }
      function easeIn(p) { return p * p * p; }
      const L = layout();
      ctx.fillStyle = tt >= 2 && tt < 5 ? INK : "rgba(232,229,244,0.75)";
      for (const l of L) ctx.fillText(l.ch, l.x + dx, l.y);
      ctx.fillStyle = DIM;                 // the belt itself, rolling dots
      for (let x = (t * 40) % 14 - 14; x < W; x += 14)
        ctx.fillRect(x, u.MID + BASE * 0.45, 5, 2);
    }
  };
});

/* ============================== SPINS & FLIPS ============================== */

def("Split-flap", "spin", "the airport board: every slot flips through glyphs until the right one clacks in", function (u) {
  const { ctx, INK, BASE, GLYPHS, rand, layout, stage } = u;
  let slots = null, rest = 0;
  return {
    press() { slots = null; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!slots) slots = L.map(l => ({ flips: Math.floor(rand(3, 10)) + l.i, phase: 0, cur: Math.floor(rand(0, GLYPHS.length)) }));
      let allDone = true;
      for (const l of L) {
        if (l.ch === " ") continue;
        const s = slots[l.i];
        if (s.flips > 0) {
          allDone = false;
          s.phase += dt * 9;               // one flip ≈ a ninth of a second
          if (s.phase >= 1) { s.phase = 0; s.flips--; s.cur = (s.cur + 1) % GLYPHS.length; }
        }
        const showing = s.flips > 0 ? GLYPHS[s.cur] : l.ch;
        const sy = s.flips > 0 ? Math.abs(Math.cos(s.phase * Math.PI)) : 1;    // the flap turning edge-on
        // the plate behind the letter
        ctx.fillStyle = "rgba(35,30,58,0.9)";
        ctx.fillRect(l.x - 2, l.y - BASE * 0.8, l.w + 4, BASE * 1.05);
        ctx.strokeStyle = "rgba(150,145,190,0.3)";
        ctx.lineWidth = 1;
        ctx.strokeRect(l.x - 2, l.y - BASE * 0.8, l.w + 4, BASE * 1.05);
        ctx.beginPath();                   // the split line
        ctx.moveTo(l.x - 2, l.y - BASE * 0.28); ctx.lineTo(l.x + l.w + 2, l.y - BASE * 0.28);
        ctx.stroke();
        ctx.save();
        ctx.translate(l.cx, l.y - BASE * 0.28);
        ctx.scale(1, Math.max(0.06, sy));
        ctx.fillStyle = s.flips > 0 ? "rgba(232,229,244,0.85)" : INK;
        ctx.fillText(showing, -l.w / 2, BASE * 0.28);
        ctx.restore();
      }
      if (allDone) { rest += dt; if (rest > 3.2) { slots = null; rest = 0; } }
    }
  };
});

def("Coin spin", "spin", "each letter spins like a flipped coin and lands face-up, left to right", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (clock > L.length * 0.12 + 4) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (clock - l.i * 0.12) / 0.7));
        if (p <= 0) continue;
        const spins = 2.5;                 // total half-turns before landing
        const sx = Math.cos(p < 1 ? (1 - Math.pow(1 - p, 2)) * spins * Math.PI : 0);
        ctx.save();
        ctx.translate(l.cx, l.y);
        ctx.scale(Math.max(0.05, Math.abs(sx)), 1);        // |cos| — the coin never truly vanishes
        ctx.globalAlpha = 0.4 + 0.6 * Math.abs(sx);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
        ctx.globalAlpha = 1;
      }
    }
  };
});

def("Cartwheel", "spin", "letters roll in from the left like wheels, spinning as they travel", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (clock > L.length * 0.08 + 4) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (clock - l.i * 0.08) / 0.8));
        if (p <= 0) continue;
        const e = 1 - Math.pow(1 - p, 3);
        const x = -BASE + (l.cx + BASE) * e;
        const rot = (1 - e) * -Math.PI * 3;                // unrolls as it arrives
        ctx.save();
        ctx.translate(x, l.y - BASE * 0.3);
        ctx.rotate(rot);
        ctx.fillText(l.ch, -l.w / 2, BASE * 0.3);
        ctx.restore();
      }
    }
  };
});

def("Revolving door", "spin", "letters orbit in along an arc, swinging around into their slots", function (u) {
  const { ctx, W, INK, BASE, MID, layout, stage } = u;
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (clock > L.length * 0.07 + 4.2) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (clock - l.i * 0.07) / 1));
        if (p <= 0) continue;
        const e = 1 - Math.pow(1 - p, 3);
        const a = (1 - e) * Math.PI;       // half a revolution to arrive
        const r = (1 - e) * BASE * 2.2;
        const x = l.cx + Math.sin(a * 2) * r;
        const y = l.y - Math.sin(a) * r;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate((1 - e) * Math.PI * 2);
        ctx.globalAlpha = Math.min(1, p * 2);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
        ctx.globalAlpha = 1;
      }
    }
  };
});

def("Clock hands", "spin", "every letter starts at its own wrong hour and rotates upright", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  let angles = null, clock = 0;
  return {
    press() { angles = null; clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (!angles) angles = L.map(() => rand(-Math.PI, Math.PI));
      if (clock > 6) { clock = 0; angles = null; return; }
      const p = Math.min(1, clock / 2);
      const e = p * p * (3 - 2 * p);
      ctx.fillStyle = INK;
      for (const l of L) {
        ctx.save();
        ctx.translate(l.cx, l.y - BASE * 0.3);             // rotate about the letter's middle
        ctx.rotate(angles[l.i] * (1 - e));
        ctx.fillText(l.ch, -l.w / 2, BASE * 0.3);
        ctx.restore();
      }
    }
  };
});

def("Tumble dry", "spin", "letters tumble weightless in the drum — press to give them gravity and a baseline", function (u) {
  const { ctx, W, H, INK, BASE, rand, layout, stage } = u;
  let bods = null, settle = 0;
  return {
    press() { settle = 4; },               // gravity, briefly
    frame(dt, t) {
      stage();
      const L = layout();
      if (!bods) bods = L.map(l => ({
        x: rand(W * 0.2, W * 0.8), y: rand(H * 0.2, H * 0.7),
        vx: rand(-30, 30), vy: rand(-30, 30), a: rand(0, u.TAU), va: rand(-3, 3)
      }));
      settle = Math.max(0, settle - dt);
      ctx.fillStyle = INK;
      for (const l of L) {
        const b = bods[l.i];
        if (settle > 0) {                  // ease home, straighten up
          b.x += (l.cx - b.x) * Math.min(1, dt * 5);
          b.y += (l.y - b.y) * Math.min(1, dt * 5);
          b.a += (0 - b.a) * Math.min(1, dt * 5);
        } else {                           // drift and bounce off the drum walls
          b.x += b.vx * dt; b.y += b.vy * dt; b.a += b.va * dt;
          if (b.x < BASE || b.x > W - BASE) b.vx *= -1;
          if (b.y < BASE || b.y > H - BASE * 0.5) b.vy *= -1;
        }
        ctx.save();
        ctx.translate(b.x, b.y);
        ctx.rotate(b.a);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Orbit assembly", "spin", "the letters circle the centre in a ring, then spiral into their slots", function (u) {
  const { ctx, W, INK, BASE, MID, layout, stage, TAU } = u;
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      if (clock > 8) clock = 0;
      const L = layout();
      const p = Math.min(1, Math.max(0, (clock - 1.2) / 1.8));           // orbit first, then land
      const e = p * p * (3 - 2 * p);
      ctx.fillStyle = INK;
      for (const l of L) {
        const baseA = l.i / l.n * TAU + clock * 1.4;       // the carousel
        const r = BASE * 2 * (1 - e);
        const x = (W / 2) * (1 - e) + l.cx * e + Math.cos(baseA) * r;
        const y = (MID - BASE * 0.3) * (1 - e) + l.y * e + Math.sin(baseA) * r * 0.5;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate((1 - e) * Math.sin(baseA) * 0.4);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

/* ============================== INK & COLOUR ============================== */

def("Rainbow ride", "color", "a rainbow slides along the letters, wrapping around forever", function (u) {
  const { ctx, BASE, layout, stage } = u;
  let speed = 1;
  return {
    press() { speed = 3; },
    frame(dt, t) {
      stage();
      speed = Math.max(1, speed - dt);
      const L = layout(BASE, 0, 600);
      for (const l of L) {
        const hue = (t * 60 * speed + l.i * 36) % 360;
        ctx.fillStyle = "hsl(" + hue + ", 85%, 70%)";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Gold sheen", "color", "a specular gleam sweeps across gold letters, like light down a ring", function (u) {
  const { ctx, W, BASE, layout, stage } = u;
  let sweep = 0;
  return {
    press() { sweep = -0.3; },             // restart the gleam
    frame(dt, t) {
      stage();
      sweep = sweep === undefined ? 0 : sweep;
      sweep += dt * 0.55;
      if (sweep > 1.6) sweep = -0.3;       // a pause between passes
      const gx = W * sweep;
      const L = layout(BASE, 0, 700);
      for (const l of L) {
        const k = Math.exp(-Math.pow((l.cx - gx) / (BASE * 0.9), 2));
        const r = Math.round(200 + k * 55), g = Math.round(165 + k * 85), b = Math.round(70 + k * 150);
        ctx.fillStyle = "rgb(" + r + "," + g + "," + b + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Fire ink", "color", "each letter burns — white-hot at the base, orange at the tips, always moving", function (u) {
  const { ctx, BASE, rand, layout, stage, glow } = u;
  return {
    press() {},                            // fire needs no instruction
    frame(dt, t) {
      stage();
      const L = layout(BASE, 0, 600);
      for (const l of L) {
        if (l.ch === " ") continue;
        const flick = 0.5 + 0.5 * Math.sin(t * 9 + l.i * 2.7) * Math.sin(t * 5.3 + l.i);
        const g = ctx.createLinearGradient(0, l.y, 0, l.y - BASE * 0.85);  // per-letter vertical fire
        g.addColorStop(0, "rgb(255,240,200)");
        g.addColorStop(0.55, "rgb(255," + Math.round(140 + flick * 60) + ",40)");
        g.addColorStop(1, "rgba(255,60,20," + (0.55 + flick * 0.4) + ")");
        ctx.fillStyle = g;
        ctx.fillText(l.ch, l.x, l.y + Math.sin(t * 7 + l.i * 1.3) * 1.2);
      }
      ctx.globalCompositeOperation = "lighter";
      glow(u.W / 2, u.MID - BASE * 0.3, BASE * 3, "rgba(255,120,40,0.10)");
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Ocean ink", "color", "blues and greens flow through the phrase like water over stones", function (u) {
  const { ctx, BASE, layout, stage } = u;
  let stir = 0;
  return {
    press() { stir = 1.5; },
    frame(dt, t) {
      stage();
      stir = Math.max(0, stir - dt);
      const L = layout(BASE, 0, 500);
      for (const l of L) {
        const k = 0.5 + 0.5 * Math.sin(t * (1.2 + stir) + l.i * 0.8);
        const k2 = 0.5 + 0.5 * Math.sin(t * 0.7 + l.i * 1.9 + 2);
        ctx.fillStyle = "rgb(" + Math.round(50 + k2 * 60) + "," + Math.round(140 + k * 80) + "," + Math.round(190 + k * 60) + ")";
        ctx.fillText(l.ch, l.x, l.y + Math.sin(t * 1.6 + l.i * 0.8) * BASE * 0.04);
      }
    }
  };
});

def("Misprint", "color", "cyan, magenta, and yellow plates breathe in and out of register", function (u) {
  const { ctx, BASE, layout, stage, TAU } = u;
  let align = 0;
  return {
    press() { align = 2.5; },              // the pressman leans on the machine — perfect register, briefly
    frame(dt, t) {
      stage();
      align = Math.max(0, align - dt);
      const off = align > 0 ? 0 : BASE * 0.06 * (1 + Math.sin(t * TAU / 5)); // drift 0..12% of size
      const L = layout(BASE, 0, 700);
      ctx.globalCompositeOperation = "lighter";            // additive: where plates agree, white
      const plates = [
        ["rgba(80,220,255,0.85)", -off, off * 0.4],
        ["rgba(255,80,200,0.85)", off, -off * 0.3],
        ["rgba(255,235,90,0.85)", off * 0.3, off * 0.8]
      ];
      for (const [col, dx, dy] of plates) {
        ctx.fillStyle = col;
        for (const l of L) ctx.fillText(l.ch, l.x + dx, l.y + dy);
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Highlighter", "color", "a marker swipes through behind the words — press for a fresh colour", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  const colours = ["rgba(255,235,90,0.4)", "rgba(120,255,160,0.35)", "rgba(255,140,200,0.35)", "rgba(120,210,255,0.35)"];
  let ci = 0, sweep = 0;
  return {
    press() { ci = (ci + 1) % colours.length; sweep = 0; },
    frame(dt, t) {
      stage();
      sweep = Math.min(1.15, sweep + dt * 1.1);
      if (sweep >= 1.15) { /* rests swiped until pressed or looped */ }
      if (sweep >= 1.15 && (t % 6) < dt) sweep = 0;        // re-swipe on its own, occasionally
      const L = layout();
      const x0 = L[0].x - 4, x1 = L[L.length - 1].x + L[L.length - 1].w + 4;
      const wave = Math.min(1, sweep);
      ctx.fillStyle = colours[ci];
      // the marker band, with a slightly ragged leading edge
      const lead = x0 + (x1 - x0) * wave;
      ctx.beginPath();
      ctx.moveTo(x0, L[0].y - BASE * 0.62);
      ctx.lineTo(lead + Math.sin(t * 20) * 2, L[0].y - BASE * 0.62 + rand(-1, 1));
      ctx.lineTo(lead + Math.sin(t * 17) * 2, L[0].y + BASE * 0.18);
      ctx.lineTo(x0, L[0].y + BASE * 0.18);
      ctx.fill();
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Ink bleed", "color", "the letters arrive as watery stains and slowly saturate into solid ink", function (u) {
  const { ctx, BASE, rand, layout, stage } = u;
  let age = 0, seeds = null;
  return {
    press() { age = 0; seeds = null; },
    frame(dt, t) {
      stage();
      age += dt;
      const L = layout(BASE, 0, 600);
      if (!seeds) seeds = L.map(() => rand(0, 1.2));
      if (age > 8) { age = 0; seeds = null; return; }
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (age - seeds[l.i]) / 3));
        if (p <= 0) continue;
        // young ink: wide, soft, pale — old ink: tight, dark
        const blur = (1 - p) * BASE * 0.35;
        ctx.save();
        ctx.shadowColor = "rgba(90,110,200," + (0.5 + p * 0.5) + ")";
        ctx.shadowBlur = blur;
        ctx.fillStyle = "rgba(120,140,230," + (0.25 + p * 0.75) + ")";
        ctx.fillText(l.ch, l.x, l.y);
        if (p > 0.6) {                     // the core sets
          ctx.shadowBlur = 0;
          ctx.fillStyle = "rgba(200,210,255," + (p - 0.6) * 2.2 + ")";
          ctx.fillText(l.ch, l.x, l.y);
        }
        ctx.restore();
      }
    }
  };
});

def("Mood ring", "color", "the phrase drifts through moods — colour, pace, and posture together", function (u) {
  const { ctx, BASE, layout, stage, TAU } = u;
  const MOODS = [
    { name: "calm", col: [150, 200, 255], pace: 0.6, lift: 0 },
    { name: "joy", col: [255, 220, 120], pace: 1.6, lift: 0.08 },
    { name: "wist", col: [190, 160, 230], pace: 0.4, lift: -0.04 },
    { name: "alert", col: [255, 140, 120], pace: 2.4, lift: 0.02 }
  ];
  let mi = 0, blend = 1, timer = 0;
  return {
    press() { mi = (mi + 1) % MOODS.length; blend = 0; timer = 0; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (timer > 5) { timer = 0; mi = (mi + 1) % MOODS.length; blend = 0; }
      blend = Math.min(1, blend + dt * 0.8);
      const from = MOODS[(mi + MOODS.length - 1) % MOODS.length], to = MOODS[mi];
      const mix = (a, b) => a + (b - a) * blend;
      const col = [0, 1, 2].map(i => Math.round(mix(from.col[i], to.col[i])));
      const pace = mix(from.pace, to.pace), lift = mix(from.lift, to.lift);
      const L = layout();
      ctx.fillStyle = "rgb(" + col.join(",") + ")";
      for (const l of L) {
        const y = Math.sin(t * TAU * pace / 4 + l.i * 0.5) * BASE * 0.05 * pace - lift * BASE;
        ctx.fillText(l.ch, l.x, l.y + y);
      }
      ctx.fillStyle = "rgba(232,229,244,0.35)";
      ctx.font = "10px system-ui, sans-serif";
      ctx.fillText("mood: " + to.name, 8, 14);
    }
  };
});

/* ============================== SHAKES & GLITCHES ============================== */

def("Cold shiver", "shake", "a fine tremble, with a proper shiver running through now and then", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  let shiver = 0, next = 2;
  return {
    press() { shiver = 1; },
    frame(dt, t) {
      stage();
      next -= dt;
      if (next <= 0) { shiver = 1; next = rand(2.5, 5); }
      shiver = Math.max(0, shiver - dt * 1.5);
      const L = layout();
      ctx.fillStyle = "#D8E4F2";
      for (const l of L) {
        const base = 0.5;                  // the ever-present tremble, in px
        const wave = Math.max(0, Math.sin(shiver * Math.PI)) *          // the travelling shiver
          Math.exp(-Math.pow(l.i / l.n - (1 - shiver), 2) * 8) * 3;
        ctx.fillText(l.ch, l.x + rand(-1, 1) * (base + wave), l.y + rand(-1, 1) * (base + wave));
      }
    }
  };
});

def("Earthquake", "shake", "press for the quake — trauma squared, then the slow settle", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  let trauma = 0;
  return {
    press() { trauma = 1; },
    frame(dt, t) {
      stage();
      trauma = Math.max(0, trauma - dt * 0.7);
      const sh = trauma * trauma;          // the chapter-06 lesson: shake by trauma², not trauma
      const dx = rand(-1, 1) * sh * BASE * 0.5, dy = rand(-1, 1) * sh * BASE * 0.3;
      const rot = rand(-1, 1) * sh * 0.06;
      ctx.save();
      ctx.translate(u.W / 2 + dx, u.MID + dy);
      ctx.rotate(rot);
      ctx.translate(-u.W / 2, -u.MID);
      const L = layout(BASE, 0, sh > 0.3 ? 700 : 400);     // it clenches while shaking
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      ctx.restore();
      if (sh > 0.05) {                     // dust from the ceiling
        ctx.fillStyle = "rgba(200,190,170," + sh * 0.5 + ")";
        for (let i = 0; i < 3; i++) ctx.fillRect(rand(0, u.W), rand(0, u.H), 1.5, 1.5);
      }
    }
  };
});

def("RGB split", "shake", "the channels tear apart in glitch bursts and heal — press for a big one", function (u) {
  const { ctx, BASE, rand, layout, stage } = u;
  let burst = 0, next = 1.5;
  return {
    press() { burst = 1; },
    frame(dt, t) {
      stage();
      next -= dt;
      if (next <= 0) { burst = Math.max(burst, rand(0.2, 0.5)); next = rand(0.8, 2.4); }
      burst = Math.max(0, burst - dt * 2);
      const off = burst * BASE * 0.25 * (Math.random() < 0.2 ? 2 : 1);   // occasional double-tear
      const L = layout(BASE, 0, 600);
      ctx.globalCompositeOperation = "lighter";
      ctx.fillStyle = "rgba(255,60,80,0.9)";
      for (const l of L) ctx.fillText(l.ch, l.x - off, l.y + off * 0.2);
      ctx.fillStyle = "rgba(60,255,120,0.9)";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      ctx.fillStyle = "rgba(80,120,255,0.9)";
      for (const l of L) ctx.fillText(l.ch, l.x + off, l.y - off * 0.2);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Scanline slice", "shake", "horizontal slices of the phrase shear sideways for a frame or two", function (u) {
  const { ctx, W, INK, BASE, MID, rand, layout, stage } = u;
  let jolt = 0;
  return {
    press() { jolt = 1; },
    frame(dt, t) {
      stage();
      jolt = Math.max(0, jolt - dt * 3);
      // draw the phrase to look at, then re-draw slices of it displaced
      const L = layout(BASE, 0, 600);
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      const slices = 4;
      const top = MID - BASE * 0.85, hgt = BASE * 1.2;
      for (let i = 0; i < slices; i++) {
        const on = jolt > 0 ? Math.random() < 0.8 : Math.random() < 0.04;
        if (!on) continue;
        const sy = top + (i / slices) * hgt;
        const sh = hgt / slices;
        const dx = rand(-1, 1) * (4 + jolt * BASE * 0.5);
        const img = ctx.getImageData(0, sy * (window.devicePixelRatio || 1), ctx.canvas.width, Math.max(1, sh * (window.devicePixelRatio || 1)));
        ctx.putImageData(img, dx * (window.devicePixelRatio || 1), sy * (window.devicePixelRatio || 1));
      }
    }
  };
});

def("Corruption", "shake", "letters flicker into blocks and wrong glyphs, one frame at a time", function (u) {
  const { ctx, INK, BASE, rand, scramble, layout, stage } = u;
  let sick = 0.08;                         // baseline corruption probability
  return {
    press() { sick = 0.6; },               // a bad sector
    frame(dt, t) {
      stage();
      sick = Math.max(0.08, sick - dt * 0.4);
      const L = layout();
      for (const l of L) {
        if (l.ch === " ") continue;
        const r = Math.random();
        if (r < sick * 0.4) {              // a block
          ctx.fillStyle = "rgba(180,220,160,0.8)";
          ctx.fillRect(l.x, l.y - BASE * 0.68, l.w * 0.9, BASE * 0.74);
        } else if (r < sick) {             // a wrong glyph
          ctx.fillStyle = "rgba(180,220,160,0.9)";
          ctx.fillText(scramble(), l.x, l.y);
        } else {
          ctx.fillStyle = INK;
          ctx.fillText(l.ch, l.x, l.y);
        }
      }
    }
  };
});

def("Nervous", "shake", "the letters fidget — leaning, drifting, never quite holding still", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let calm = 0;
  return {
    press() { calm = 3; },                 // a deep breath: stillness, briefly
    frame(dt, t) {
      stage();
      calm = Math.max(0, calm - dt);
      const k = calm > 0 ? 0.15 : 1;
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        // smooth pseudo-noise from stacked sines — jitter without randomness
        const nx = (Math.sin(t * 3.1 + l.i * 7.3) + Math.sin(t * 5.7 + l.i * 3.1)) * 0.8 * k;
        const ny = (Math.sin(t * 2.7 + l.i * 5.9) + Math.sin(t * 6.3 + l.i * 2.3)) * 0.6 * k;
        const na = Math.sin(t * 2.2 + l.i * 4.7) * 0.06 * k;
        ctx.save();
        ctx.translate(l.cx + nx, l.y + ny);
        ctx.rotate(na);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

def("Sync loss", "shake", "the picture rolls like a TV losing vertical hold, then locks back on", function (u) {
  const { ctx, W, H, INK, BASE, rand, layout, stage } = u;
  let roll = 0, v = 0;
  return {
    press() { v = H * 3; },                // spin the v-hold knob
    frame(dt, t) {
      stage();
      v = Math.max(0, v - dt * H * 2.2);
      roll = (roll + v * dt) % H;
      if (v <= 0 && roll > 0) roll = Math.abs(roll) < 2 ? 0 : roll * Math.pow(0.02, dt);  // snap the lock
      const L = layout(BASE, 0, 500);
      ctx.fillStyle = INK;
      for (const pass of [0, 1]) {         // the frame and its wraparound twin
        const dy = -roll + pass * H;
        for (const l of L) ctx.fillText(l.ch, l.x, l.y + dy);
        if (v > 0) {                       // the torn sync bar between frames
          ctx.fillStyle = "rgba(150,145,190,0.25)";
          ctx.fillRect(0, dy - BASE * 1.6, W, 6);
          ctx.fillStyle = INK;
        }
      }
      if (v > 0 && Math.random() < 0.3) {  // static in the tear
        ctx.fillStyle = "rgba(200,200,220,0.3)";
        for (let i = 0; i < 12; i++) ctx.fillRect(rand(0, W), rand(0, H), 2, 1);
      }
    }
  };
});

/* ============================== STROKES & OUTLINES ============================== */

def("Pen stroke", "stroke", "the letters write themselves on — a dash crawling along each glyph's path", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 7) age = 0;
      const L = layout(BASE, 0, 500);
      ctx.strokeStyle = INK;
      ctx.lineWidth = 1.4;
      const per = BASE * 7;                // a generous guess at one glyph's path length
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (age - l.i * 0.22) / 1.4));
        if (p <= 0) continue;
        // the trick: a dash as long as p·path, then a gap longer than any glyph
        ctx.setLineDash([per * p, per * 4]);
        ctx.strokeText(l.ch, l.x, l.y);
        if (p >= 1) {                      // finished letters get their fill
          ctx.setLineDash([]);
          ctx.fillStyle = "rgba(232,229,244,0.9)";
          ctx.fillText(l.ch, l.x, l.y);
        }
      }
      ctx.setLineDash([]);
    }
  };
});

def("Hollow to solid", "stroke", "outlines first; then the ink rises inside them like a filling glass", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 7) age = 0;
      const L = layout(BASE, 0, 600);
      ctx.strokeStyle = "rgba(232,229,244,0.8)";
      ctx.lineWidth = 1.2;
      for (const l of L) ctx.strokeText(l.ch, l.x, l.y);
      const fill = Math.min(1, Math.max(0, (age - 0.8) / 2.2));          // the rising level
      if (fill > 0) {
        ctx.save();
        ctx.beginPath();                   // clip to everything below the ink line
        const level = u.MID + BASE * 0.14 - fill * BASE * 0.95;
        ctx.rect(0, level, W, u.H - level);
        ctx.clip();
        ctx.fillStyle = INK;
        for (const l of L) ctx.fillText(l.ch, l.x, l.y);
        ctx.restore();
        if (fill < 1) {                    // the meniscus
          ctx.fillStyle = "rgba(180,200,255,0.5)";
          ctx.fillRect(L[0].x, level - 1, L[L.length - 1].x + L[L.length - 1].w - L[0].x, 1.5);
        }
      }
    }
  };
});

def("Marching ants", "stroke", "a dashed outline crawls around every letter, single file, forever", function (u) {
  const { ctx, BASE, layout, stage } = u;
  let speed = 1;
  return {
    press() { speed = 4; },                // the ants hurry when startled
    frame(dt, t) {
      stage();
      speed = Math.max(1, speed - dt * 1.5);
      const L = layout(BASE, 0, 600);
      ctx.strokeStyle = "rgba(232,229,244,0.9)";
      ctx.lineWidth = 1.2;
      ctx.setLineDash([4, 4]);
      ctx.lineDashOffset = -t * 20 * speed;                // the entire march is this one line
      for (const l of L) ctx.strokeText(l.ch, l.x, l.y);
      ctx.setLineDash([]);
      ctx.fillStyle = "rgba(232,229,244,0.14)";            // a whisper of fill so it reads
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Underline writer", "stroke", "the underline draws itself first; the letters fade in above it, riding its wake", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 6.5) age = 0;
      const L = layout();
      const x0 = L[0].x, x1 = L[L.length - 1].x + L[L.length - 1].w;
      const p = Math.min(1, age / 1.2);
      const e = 1 - Math.pow(1 - p, 3);
      const tip = x0 + (x1 - x0) * e;
      ctx.strokeStyle = "rgba(180,200,255,0.9)";           // the pen line
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(x0, L[0].y + 6);
      ctx.lineTo(tip, L[0].y + 6);
      ctx.stroke();
      for (const l of L) {                 // letters appear where the pen has already passed
        const k = Math.min(1, Math.max(0, (tip - l.cx) / (BASE * 1.5) + 0.5));
        ctx.fillStyle = "rgba(232,229,244," + k + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Double stroke", "stroke", "an inner line and an outer line, breathing in opposite phase", function (u) {
  const { ctx, BASE, layout, stage, TAU } = u;
  let surge = 0;
  return {
    press() { surge = 1; },
    frame(dt, t) {
      stage();
      surge = Math.max(0, surge - dt);
      const k = 0.5 + 0.5 * Math.sin(t * TAU / 3);
      const L = layout(BASE, 0, 700);
      ctx.lineJoin = "round";
      ctx.strokeStyle = "rgba(120,150,255," + (0.35 + (1 - k) * 0.4 + surge * 0.25) + ")";   // outer breathes out
      ctx.lineWidth = 3.5 + (1 - k) * 2.5 + surge * 3;
      for (const l of L) ctx.strokeText(l.ch, l.x, l.y);
      ctx.strokeStyle = "rgba(232,229,244," + (0.5 + k * 0.5) + ")";                          // inner breathes in
      ctx.lineWidth = 1.1;
      for (const l of L) ctx.strokeText(l.ch, l.x, l.y);
    }
  };
});

def("Strike & fix", "stroke", "a line strikes the phrase out; thinks better of it; retracts", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let phase = 0;                           // 0..1 strike, 1..2 regret, 2..3 retract, then rest
  return {
    press() { phase = 0; },
    frame(dt, t) {
      stage();
      phase += dt * 0.8;
      if (phase > 4.2) phase = 0;
      const L = layout();
      const x0 = L[0].x - 3, x1 = L[L.length - 1].x + L[L.length - 1].w + 3;
      let strike = 0;
      if (phase < 1) strike = 1 - Math.pow(1 - phase, 3);
      else if (phase < 2) strike = 1;
      else if (phase < 3) strike = 1 - (phase - 2);
      // struck letters slump a little
      for (const l of L) {
        const covered = l.cx < x0 + (x1 - x0) * strike;
        ctx.fillStyle = covered ? "rgba(232,229,244,0.45)" : INK;
        ctx.fillText(l.ch, l.x, l.y + (covered ? 1.5 : 0));
      }
      if (strike > 0) {
        ctx.strokeStyle = "rgba(230,150,150,0.9)";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(x0, L[0].y - BASE * 0.26);
        ctx.lineTo(x0 + (x1 - x0) * strike, L[0].y - BASE * 0.26 + Math.sin(strike * 9) * 1.5);
        ctx.stroke();
      }
    }
  };
});

def("Chalk dust", "stroke", "chalk letters with a rough, restless edge — dust drifts off them as they stand", function (u) {
  const { ctx, BASE, rand, layout, stage } = u;
  let motes = [], slam = 0;
  return {
    press() {                              // clap the erasers
      slam = 1;
      const L = layout();
      for (let i = 0; i < 20; i++) {
        const l = L[Math.floor(rand(0, L.length))];
        motes.push({ x: l.cx + rand(-6, 6), y: l.y - rand(0, BASE * 0.6), vx: rand(-20, 20), vy: rand(-10, 26), life: 1 });
      }
    },
    frame(dt, t) {
      stage();
      slam = Math.max(0, slam - dt);
      const L = layout(BASE, 0, 500);
      ctx.strokeStyle = "rgba(240,238,232,0.85)";
      ctx.lineWidth = 1.3;
      ctx.setLineDash([3, 2]);             // the grain of the board
      ctx.lineDashOffset = Math.floor(t * 8) * 1.7;        // quantized: chalk doesn't glide
      for (const l of L) ctx.strokeText(l.ch, l.x, l.y);
      ctx.setLineDash([]);
      if (Math.random() < 0.25) {          // ambient dust
        const l = L[Math.floor(rand(0, L.length))];
        motes.push({ x: l.cx + rand(-4, 4), y: l.y + rand(-BASE * 0.4, 2), vx: rand(-4, 4), vy: rand(4, 14), life: 0.8 });
      }
      ctx.fillStyle = "rgba(240,238,232,0.5)";
      for (const m of motes) {
        m.x += m.vx * dt; m.y += m.vy * dt; m.vy += 8 * dt; m.life -= dt * 0.9;
        if (m.life > 0) ctx.fillRect(m.x, m.y, 1.5, 1.5);
      }
      motes = motes.filter(m => m.life > 0);
    }
  };
});

/* ============================== DUST & PARTICLES ============================== */

def("Star assembly", "particle", "motes stream toward the letter slots; where they gather, letters appear", function (u) {
  const { ctx, W, H, INK, BASE, rand, layout, stage, glow } = u;
  let motes = [], arrived = null, age = 0;
  return {
    press() { arrived = null; age = 0; motes = []; },
    frame(dt, t) {
      stage();
      age += dt;
      const L = layout();
      if (!arrived) arrived = L.map(() => 0);
      if (age > 8) { arrived = L.map(() => 0); age = 0; motes = []; }
      if (motes.length < 40 && age < 3) {  // recruit from the edges
        const l = L[Math.floor(rand(0, L.length))];
        if (l.ch !== " ") motes.push({ x: rand(0, 1) < 0.5 ? rand(-10, 0) : rand(W, W + 10), y: rand(0, H), tx: l.cx, ty: l.y - BASE * 0.3, ti: l.i, life: 1 });
      }
      ctx.globalCompositeOperation = "lighter";
      for (const m of motes) {
        m.x += (m.tx - m.x) * Math.min(1, dt * 2.2);
        m.y += (m.ty - m.y) * Math.min(1, dt * 2.2);
        glow(m.x, m.y, 2.5, "rgba(220,220,255,0.8)");
        if (Math.abs(m.x - m.tx) < 2 && Math.abs(m.y - m.ty) < 2) { arrived[m.ti] += dt * 2; m.life = 0; }
      }
      motes = motes.filter(m => m.life > 0);
      ctx.globalCompositeOperation = "source-over";
      for (const l of L) {                 // letters condense out of gathered light
        const k = Math.min(1, arrived[l.i]);
        if (k <= 0) continue;
        ctx.fillStyle = "rgba(232,229,244," + k + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Dust burst", "particle", "press and the letters explode into dust — which drifts back and reforms them", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  let dust = [], gone = 0;
  return {
    press() {
      const L = layout();
      dust = [];
      for (const l of L) {
        if (l.ch === " ") continue;
        for (let i = 0; i < 6; i++)        // six grains per letter remember where home is
          dust.push({ x: l.cx + rand(-l.w, l.w) * 0.4, y: l.y - rand(0, BASE * 0.6),
                      vx: rand(-70, 70), vy: rand(-90, 20), hx: l.cx + rand(-l.w, l.w) * 0.3, hy: l.y - rand(0, BASE * 0.6) });
      }
      gone = 1;
    },
    frame(dt, t) {
      stage();
      const L = layout();
      if (gone > 0) {
        gone = Math.min(2.4, gone + dt);
        const homing = gone > 1.2;         // first they scatter; then they remember
        ctx.fillStyle = "rgba(220,215,240,0.8)";
        for (const d of dust) {
          if (homing) {
            d.x += (d.hx - d.x) * Math.min(1, dt * 3);
            d.y += (d.hy - d.y) * Math.min(1, dt * 3);
          } else {
            d.x += d.vx * dt; d.y += d.vy * dt; d.vy += 60 * dt;
            d.vx *= Math.pow(0.4, dt); d.vy *= Math.pow(0.4, dt);
          }
          ctx.fillRect(d.x, d.y, 1.8, 1.8);
        }
        const k = Math.max(0, (gone - 1.9) * 2);           // the reformed phrase fades up
        if (k > 0) {
          ctx.fillStyle = "rgba(232,229,244," + Math.min(1, k) + ")";
          for (const l of L) ctx.fillText(l.ch, l.x, l.y);
        }
        if (gone >= 2.4) { gone = 0; dust = []; }
      } else {
        ctx.fillStyle = INK;
        for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Sparkle crown", "particle", "little four-point twinkles pop over the letters, one place at a time", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  let sparks = [], shower = 0;
  function twinkle(x, y, size, a) {
    ctx.strokeStyle = "rgba(255,250,220," + a + ")";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x - size, y); ctx.lineTo(x + size, y);
    ctx.moveTo(x, y - size); ctx.lineTo(x, y + size);
    ctx.stroke();
  }
  return {
    press() { shower = 1; },
    frame(dt, t) {
      stage();
      shower = Math.max(0, shower - dt);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      if (Math.random() < 0.15 + shower * 0.8) {
        const l = L[Math.floor(rand(0, L.length))];
        sparks.push({ x: l.cx + rand(-l.w * 0.5, l.w * 0.5), y: l.y - rand(BASE * 0.2, BASE * 0.95), life: 1, s: rand(2, 4.5) });
      }
      for (const s of sparks) {
        s.life -= dt * 1.6;
        if (s.life > 0) twinkle(s.x, s.y, s.s * Math.sin(s.life * Math.PI), s.life);
      }
      sparks = sparks.filter(s => s.life > 0);
    }
  };
});

def("Electron letters", "particle", "two motes orbit every letter like electrons — press and they all break orbit", function (u) {
  const { ctx, INK, BASE, rand, layout, stage, glow, TAU } = u;
  let flung = 0;
  return {
    press() { flung = 1; },
    frame(dt, t) {
      stage();
      flung = Math.max(0, flung - dt * 0.7);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      ctx.globalCompositeOperation = "lighter";
      for (const l of L) {
        if (l.ch === " ") continue;
        for (let e = 0; e < 2; e++) {
          const a = t * (2.2 + e * 0.9) + l.i * 1.3 + e * Math.PI;
          const r = (BASE * 0.55 + e * 3) * (1 + flung * 2.5);           // orbits balloon when flung
          const x = l.cx + Math.cos(a) * r;
          const y = l.y - BASE * 0.3 + Math.sin(a) * r * 0.55;
          glow(x, y, 2.5, "rgba(160,220,255," + (0.8 - flung * 0.3) + ")");
        }
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Snow fill", "particle", "snow settles on the letters, whitening them from the top down", function (u) {
  const { ctx, W, DIM, BASE, rand, layout, stage } = u;
  let flakes = [], depth = 0;
  return {
    press() { depth = 0; },                // brush the snow off
    frame(dt, t) {
      stage();
      depth = Math.min(1, depth + dt * 0.06);              // the slow accumulation
      if (flakes.length < 30 && Math.random() < 0.5)
        flakes.push({ x: rand(0, W), y: -4, v: rand(14, 30), drift: rand(0.5, 2) });
      ctx.fillStyle = "rgba(240,245,255,0.8)";
      for (const f of flakes) {
        f.y += f.v * dt; f.x += Math.sin(f.y * 0.08) * f.drift * dt * 10;
        ctx.fillRect(f.x, f.y, 1.8, 1.8);
      }
      flakes = flakes.filter(f => f.y < u.H + 4);
      const L = layout(BASE, 0, 600);
      for (const l of L) {                 // dim letters, snowier from the top
        ctx.fillStyle = DIM;
        ctx.fillText(l.ch, l.x, l.y);
        ctx.save();
        ctx.beginPath();                   // clip the snowy cap: top `depth` of the letter height
        ctx.rect(l.x - 1, l.y - BASE * 0.75, l.w + 2, BASE * 0.85 * depth);
        ctx.clip();
        ctx.fillStyle = "rgba(245,250,255,0.95)";
        ctx.fillText(l.ch, l.x, l.y);
        ctx.restore();
      }
    }
  };
});

def("Ember decay", "particle", "the letters smoulder away into rising embers, then heal, on a loop", function (u) {
  const { ctx, INK, BASE, rand, layout, stage, glow, TAU } = u;
  let embers = [];
  return {
    press() {},                            // decay keeps its own schedule
    frame(dt, t) {
      stage();
      const L = layout();
      const cycle = (t % 7) / 7;           // 0..1: whole → gone → whole
      const burn = cycle < 0.5 ? cycle * 2 : (1 - cycle) * 2;            // how much is burned away
      for (const l of L) {
        if (l.ch === " ") continue;
        const litFrom = l.y - BASE * 0.75 + BASE * 0.85 * (1 - burn);    // the burn line climbs
        ctx.save();
        ctx.beginPath();
        ctx.rect(l.x - 1, litFrom, l.w + 2, BASE);         // below the line: still whole
        ctx.clip();
        ctx.fillStyle = INK;
        ctx.fillText(l.ch, l.x, l.y);
        ctx.restore();
        if (burn > 0.02 && burn < 0.98 && Math.random() < 0.3) {         // sparks at the burn line
          embers.push({ x: l.cx + rand(-l.w * 0.4, l.w * 0.4), y: litFrom, vy: rand(-30, -14), life: 1 });
          ctx.globalCompositeOperation = "lighter";
          glow(l.cx, litFrom, 4, "rgba(255,140,60,0.5)");
          ctx.globalCompositeOperation = "source-over";
        }
      }
      ctx.globalCompositeOperation = "lighter";
      for (const e of embers) {
        e.y += e.vy * dt; e.x += Math.sin(e.y * 0.2) * 8 * dt; e.life -= dt * 1.3;
        if (e.life > 0) glow(e.x, e.y, 2 + e.life * 2, "rgba(255,150,60," + e.life * 0.8 + ")");
      }
      embers = embers.filter(e => e.life > 0);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Rain reveal", "particle", "rain streaks fall; letters show where the rain is touching them — press for a downpour", function (u) {
  const { ctx, W, H, DIM, BASE, rand, layout, stage } = u;
  let drops = [], pour = 0, wet = null;
  return {
    press() { pour = 1.6; },
    frame(dt, t) {
      stage();
      pour = Math.max(0, pour - dt);
      const L = layout();
      if (!wet) wet = L.map(() => 0);
      if (Math.random() < 0.35 + pour * 1.5)
        drops.push({ x: rand(0, W), y: -10, v: rand(160, 260) });
      ctx.strokeStyle = "rgba(150,190,255,0.5)";
      ctx.lineWidth = 1.2;
      for (const d of drops) {
        d.y += d.v * dt;
        ctx.beginPath(); ctx.moveTo(d.x, d.y - 10); ctx.lineTo(d.x, d.y); ctx.stroke();
        for (const l of L)                 // a streak passing through a letter wets it
          if (Math.abs(d.x - l.cx) < l.w * 0.7 && d.y > l.y - BASE && d.y < l.y + 4)
            wet[l.i] = Math.min(1, wet[l.i] + dt * 8);
      }
      drops = drops.filter(d => d.y < H + 12);
      for (const l of L) {
        wet[l.i] = Math.max(0, wet[l.i] - dt * 0.25);      // it dries
        ctx.fillStyle = wet[l.i] > 0.02 ? "rgba(200,220,255," + (0.15 + wet[l.i] * 0.85) + ")" : DIM;
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Confetti pop", "particle", "press: confetti and a little hop of celebration — idle, the occasional stray fleck", function (u) {
  const { ctx, W, INK, BASE, rand, layout, stage, TAU } = u;
  let confetti = [], hop = 0;
  const COLS = ["#FF8FA3", "#FFD166", "#8FE3B0", "#8FB7FF", "#E3A8FF"];
  return {
    press() {
      hop = 1;
      for (let i = 0; i < 26; i++)
        confetti.push({ x: W / 2 + rand(-BASE, BASE), y: u.MID + rand(-4, 4),
                        vx: rand(-90, 90), vy: rand(-160, -60), a: rand(0, TAU), va: rand(-8, 8),
                        col: COLS[Math.floor(rand(0, COLS.length))], life: 1 });
    },
    frame(dt, t) {
      stage();
      hop = Math.max(0, hop - dt * 2.2);
      if (Math.random() < 0.02)            // a stray fleck, even between parties
        confetti.push({ x: rand(0, W), y: -4, vx: rand(-6, 6), vy: rand(20, 40), a: rand(0, TAU), va: rand(-3, 3),
                        col: COLS[Math.floor(rand(0, COLS.length))], life: 1 });
      for (const c of confetti) {
        c.x += c.vx * dt; c.y += c.vy * dt; c.vy += 150 * dt; c.a += c.va * dt; c.life -= dt * 0.5;
        c.vx *= Math.pow(0.5, dt);
        if (c.life > 0) {
          ctx.save();
          ctx.translate(c.x, c.y);
          ctx.rotate(c.a);
          ctx.globalAlpha = Math.min(1, c.life * 2);
          ctx.fillStyle = c.col;
          ctx.fillRect(-2.5, -1.5, 5, 3);
          ctx.restore();
          ctx.globalAlpha = 1;
        }
      }
      confetti = confetti.filter(c => c.life > 0 && c.y < u.H + 8);
      const jump = Math.sin(Math.min(1, 1 - hop) * Math.PI) * hop * BASE * 0.4;
      const L = layout(BASE, 0, hop > 0 ? 700 : 400);
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y - jump * Math.sin(l.i / (l.n - 1) * Math.PI));
    }
  };
});

/* ============================== DEPTH & SHADOW ============================== */

def("Long shadow", "shadow", "a sun crosses the sky; the letters' long shadows wheel and stretch with it", function (u) {
  const { ctx, W, INK, BASE, MID, layout, stage, glow } = u;
  let hurry = 0;
  return {
    press() { hurry = 2; },                // time-lapse
    frame(dt, t) {
      stage();
      hurry = Math.max(0, hurry - dt);
      const day = t * (0.15 + hurry * 0.5);
      const sunA = (day % 1) * Math.PI;    // sunrise to sunset, left to right
      const sx = W / 2 - Math.cos(sunA) * W * 0.45, sy = MID - BASE * 2.2 - Math.sin(sunA) * BASE;
      ctx.globalCompositeOperation = "lighter";
      glow(sx, sy, BASE * 0.9, "rgba(255,220,140,0.5)");
      ctx.globalCompositeOperation = "source-over";
      const L = layout(BASE, 0, 700);
      const dirX = Math.cos(sunA);         // shadows point away from the sun
      const len = BASE * (0.4 + Math.abs(Math.cos(sunA)) * 1.4);         // longest at the day's edges
      const steps = 9;
      for (let s = steps; s > 0; s--) {    // the long shadow is a stack of offset copies
        const k = s / steps;
        ctx.fillStyle = "rgba(8,6,16," + (0.35 * (1 - k) + 0.08) + ")";
        for (const l of L) ctx.fillText(l.ch, l.x + dirX * len * k, l.y + len * k * 0.35);
      }
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Stack extrude", "shadow", "a 3D stack of copies gives the phrase thickness — press to slam it deep", function (u) {
  const { ctx, INK, BASE, layout, stage, TAU } = u;
  let slam = 0;
  return {
    press() { slam = 1; },
    frame(dt, t) {
      stage();
      slam = Math.max(0, slam - dt * 1.2);
      const depth = 5 + Math.sin(t * TAU / 4) * 2 + slam * 8;            // the breathing thickness
      const L = layout(BASE, 0, 700);
      for (let d = Math.round(depth); d > 0; d--) {
        const k = d / depth;
        ctx.fillStyle = "rgb(" + Math.round(40 + (1 - k) * 40) + "," + Math.round(35 + (1 - k) * 35) + "," + Math.round(70 + (1 - k) * 60) + ")";
        for (const l of L) ctx.fillText(l.ch, l.x + d * 0.8, l.y + d * 0.8);
      }
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Echo trail", "shadow", "the phrase drifts, and fading echoes of where it was follow behind", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let hist = [];                           // a short memory of positions — the trail lesson, for text
  return {
    press() { hist = []; },
    frame(dt, t) {
      stage();
      const dx = Math.sin(t * 0.9) * BASE * 0.8;           // the wander
      const dy = Math.sin(t * 1.7) * BASE * 0.22;
      hist.push({ dx: dx, dy: dy });
      if (hist.length > 14) hist.shift();
      const L = layout();
      for (let h = 0; h < hist.length - 1; h += 3) {       // every third memory, dimmer with age
        const k = h / hist.length;
        ctx.fillStyle = "rgba(150,160,255," + k * 0.16 + ")";
        for (const l of L) ctx.fillText(l.ch, l.x + hist[h].dx, l.y + hist[h].dy);
      }
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x + dx, l.y + dy);
    }
  };
});

def("Spotlight", "shadow", "darkness, and one wandering pool of light — press to call it to your cursor", function (u) {
  const { ctx, W, H, BASE, MID, rand, layout, stage, glow } = u;
  let lx = null, ly, tx, ty, called = 0;
  return {
    press(x, y) { tx = x === undefined ? W / 2 : x; ty = y === undefined ? MID : y; called = 2; },
    frame(dt, t) {
      stage();
      if (lx === null) { lx = W * 0.3; ly = MID; tx = W * 0.7; ty = MID; }
      called = Math.max(0, called - dt);
      if (called <= 0) {                   // the light wanders on its own
        tx = W / 2 + Math.sin(t * 0.6) * W * 0.32;
        ty = MID - BASE * 0.3 + Math.sin(t * 1.1) * BASE * 0.5;
      }
      lx += (tx - lx) * Math.min(1, dt * 3);
      ly += (ty - ly) * Math.min(1, dt * 3);
      const R = BASE * 1.9;
      const L = layout();
      for (const l of L) {                 // lit letters emerge; the rest stay night
        const d = Math.hypot(l.cx - lx, (l.y - BASE * 0.3) - ly);
        const k = Math.max(0, 1 - d / R);
        if (k <= 0.01) continue;
        ctx.fillStyle = "rgba(255,250,230," + Math.min(1, k * 1.6) + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
      ctx.globalCompositeOperation = "lighter";
      glow(lx, ly, R, "rgba(255,245,210,0.13)");
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Emboss", "shadow", "pressed into the paper — highlight above, shadow below; press to pop it out", function (u) {
  const { ctx, BASE, layout, stage } = u;
  let out = 0;
  return {
    press() { out = 2.5; },                // raised, for a moment
    frame(dt, t) {
      stage();
      out = Math.max(0, out - dt);
      const raised = out > 0 ? 1 : -1;     // engraved by default
      const d = 1.4;
      const L = layout(BASE, 0, 700);
      ctx.fillStyle = "rgba(20,16,34,0.9)";                // the letters themselves: paper-dark
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      ctx.fillStyle = "rgba(255,255,255," + (0.18 + Math.abs(Math.sin(t * 0.7)) * 0.05) + ")";  // light edge
      for (const l of L) ctx.fillText(l.ch, l.x - d * raised, l.y - d * raised);
      ctx.fillStyle = "rgba(0,0,0,0.55)";                  // dark edge
      for (const l of L) ctx.fillText(l.ch, l.x + d * raised, l.y + d * raised);
      ctx.fillStyle = "rgba(43,38,66,1)";                  // re-fill the face over the edges
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

def("Underglow", "shadow", "footlights: lit from below, shadows thrown up, with a stagey flicker", function (u) {
  const { ctx, W, BASE, MID, rand, layout, stage, glow } = u;
  let dim = 0;
  return {
    press() { dim = 1.4; },                // someone leaned on the dimmer
    frame(dt, t) {
      stage();
      dim = Math.max(0, dim - dt);
      const lampY = MID + BASE * 0.5;
      const flick = 0.85 + 0.15 * Math.sin(t * 11) * Math.sin(t * 6.3);
      const level = flick * (dim > 0 ? 0.25 : 1);
      ctx.globalCompositeOperation = "lighter";
      for (let i = 0; i < 4; i++)          // the row of footlights
        glow(W * (0.2 + i * 0.2), lampY, BASE * 0.8, "rgba(255,210,130," + 0.18 * level + ")");
      ctx.globalCompositeOperation = "source-over";
      const L = layout(BASE, 0, 600);
      ctx.fillStyle = "rgba(10,8,20," + (0.5 * level) + ")";             // shadow goes UP
      for (const l of L) ctx.fillText(l.ch, l.x, l.y - BASE * 0.14);
      for (const l of L) {                 // brighter toward the bottom of each letter
        const g = ctx.createLinearGradient(0, l.y - BASE * 0.8, 0, l.y);
        g.addColorStop(0, "rgba(120,90,60," + (0.35 + level * 0.2) + ")");
        g.addColorStop(1, "rgba(255,225,170," + (0.5 + level * 0.5) + ")");
        ctx.fillStyle = g;
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

def("Split shadow", "shadow", "two coloured lights, two shadows — they circle the phrase in opposite directions", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  let spin = 1;
  return {
    press() { spin = 3.5; },
    frame(dt, t) {
      stage();
      spin = Math.max(1, spin - dt * 1.4);
      const a1 = t * 0.8 * spin, a2 = -t * 0.6 * spin + 2;
      const L = layout(BASE, 0, 600);
      ctx.fillStyle = "rgba(255,80,110,0.4)";              // shadow from the cyan light
      for (const l of L) ctx.fillText(l.ch, l.x + Math.cos(a1) * 4, l.y + Math.sin(a1) * 3);
      ctx.fillStyle = "rgba(80,200,255,0.4)";              // shadow from the red light
      for (const l of L) ctx.fillText(l.ch, l.x + Math.cos(a2) * 4, l.y + Math.sin(a2) * 3);
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

/* ==================== THE RHYMES — same spells, dials turned ====================
   Each rhyme is a near-copy of its original with two or three dials moved:
   a palette, a speed, a direction, a count. Toggle ⇄ on any card, then open
   both sources — the delta is named in the opening comment. One understood
   spell is a whole spellbook. */

rhymeOf("Crescendo", "Diminuendo", "the same staircase walked down — bold and large first, thinning to a whisper", function (u) {
  const { ctx, W, H, MID, BASE, INK, rand, TAU, font, layout, stage } = u;
  // dials moved: direction reversed (k → 1-k) · press drops to the whisper instead of the peak
  let p = 0, hold = 0;
  return {
    press() { p = 1; hold = 0.8; },
    frame(dt, t) {
      stage();
      if (hold > 0) hold -= dt;
      else p = (p + dt * 0.22) % 1.3;
      const k = 1 - Math.min(1, p);        // the only real change: start loud, end soft
      const weight = 300 + Math.round(k * 4) * 100;
      const size = BASE * (1 + Math.max(0, k - 0.75) * 0.6);
      const L = layout(size, 0, weight);
      ctx.fillStyle = INK;
      ctx.strokeStyle = INK;
      ctx.lineWidth = Math.max(0.01, (k - 0.85) * BASE * 0.12);
      for (const l of L) {
        ctx.fillText(l.ch, l.x, l.y);
        if (k > 0.85) ctx.strokeText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Breathing weight", "Panting", "the same breath at a sprint — four times faster, half as deep", function (u) {
  const { ctx, INK, BASE, font, layout, stage, TAU } = u;
  // dials moved: period 4.2s → 1.1s · range 300–700 → 400–600 · press catches the breath (slows it)
  let calm = 0;
  return {
    press() { calm = 3; },
    frame(dt, t) {
      stage();
      calm = Math.max(0, calm - dt);
      const period = calm > 0 ? 4.2 : 1.1;
      const k = 0.5 + 0.5 * Math.sin(t * TAU / period);
      const weight = 400 + Math.round(k * 2) * 100;
      const L = layout(BASE, 0, weight);
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Fat press", "Crash diet", "inverted — it drifts toward heavy on its own, and every press slims it", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: press −1 step instead of +1 · drift +0.35/s toward fat instead of thin
  let fat = 4;
  return {
    press() { fat = Math.max(0, fat - 1); },
    frame(dt, t) {
      stage();
      fat = Math.min(4, fat + dt * 0.35);
      const L = layout(BASE, 0, 300 + Math.round(fat) * 100);
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      ctx.fillStyle = "rgba(232,229,244,0.35)";
      ctx.font = "10px system-ui, sans-serif";
      ctx.fillText("weight " + (300 + Math.round(fat) * 100), 8, 14);
    }
  };
});

rhymeOf("Stretch", "Squeeze", "the same slider pushed the other way — it lives condensed, and the press crushes tighter", function (u) {
  const { ctx, W, INK, BASE, layout, stage, TAU } = u;
  // dials moved: range 0.72–1.0 → 0.55–0.85 · slam +0.34 → −0.22 (a crush, not a splay)
  let slam = 0;
  return {
    press() { slam = 1; },
    frame(dt, t) {
      stage();
      slam = Math.max(0, slam - dt * 1.4);
      const sx = 0.55 + 0.30 * (0.5 + 0.5 * Math.sin(t * TAU / 5)) - slam * 0.22;
      const L = layout(BASE, 0, 500);
      const mid = (L[0].x + L[L.length - 1].x + L[L.length - 1].w) / 2;
      ctx.fillStyle = INK;
      for (const l of L) {
        ctx.save();
        ctx.translate(mid + (l.cx - mid) * sx, l.y);
        ctx.scale(sx, 1);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Heavy word", "Whispered word", "the walking emphasis turned inside out — one word goes quiet and italic", function (u) {
  const { ctx, INK, BASE, PHRASE, layout, stage } = u;
  // dials moved: emphasis bold → italic-thin-dim · the rest stays at full voice
  let which = 0, timer = 0;
  const starts = [0];
  for (let i = 0; i < PHRASE.length; i++) if (PHRASE[i] === " ") starts.push(i + 1);
  function wordOf(i) { let w = 0; for (let s = 1; s < starts.length; s++) if (i >= starts[s]) w = s; return w; }
  return {
    press() { which = (which + 1) % starts.length; timer = 0; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (timer > 1.8) { timer = 0; which = (which + 1) % starts.length; }
      const L = layout(BASE, 0, 500);
      for (const l of L) {
        const hush = wordOf(l.i) === which;
        ctx.font = u.font(hush ? "i300" : 500, BASE);
        ctx.fillStyle = hush ? "rgba(232,229,244,0.4)" : INK;
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Weight wave", "Undertow", "the travelling spotlight pulls weight OUT — a wave of lightness through a bold line", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: resting weight 300 → 700 · the wave subtracts weight and size instead of adding
  let speed = 1;
  return {
    press() { speed = 3.5; },
    frame(dt, t) {
      stage();
      speed = Math.max(1, speed - dt * 1.2);
      const L = layout(BASE, 0, 700);
      const centre = (t * speed * 0.9) % 2 - 0.5;
      for (const l of L) {
        const d = Math.abs(l.i / (l.n - 1) - centre);
        const k = Math.max(0, 1 - d * 3);
        ctx.font = u.font(700 - Math.round(k * 4) * 100, BASE * (1 - k * 0.1));
        ctx.fillStyle = INK;
        ctx.fillText(l.ch, l.cx - ctx.measureText(l.ch).width / 2, l.y);
      }
    }
  };
});

rhymeOf("Iron & feather", "Every third", "the same trade with a longer stride — heaviness walks in threes, twice as fast", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: stride 2 → 3 · beat 1.2s → 0.5s
  let step = 0, timer = 0;
  return {
    press() { step = (step + 1) % 3; timer = 0; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (timer > 0.5) { timer = 0; step = (step + 1) % 3; }
      const L = layout(BASE, 0, 700);
      for (const l of L) {
        const heavy = (l.i % 3) === step;
        ctx.font = u.font(heavy ? 700 : 300, BASE);
        ctx.fillStyle = heavy ? INK : "rgba(232,229,244,0.72)";
        ctx.fillText(l.ch, l.x, l.y - (heavy ? 0 : BASE * 0.05));
      }
    }
  };
});

rhymeOf("Candleglow", "Ghostglow", "the same flame gone cold — dim, slow, and blue at the edges", function (u) {
  const { ctx, W, MID, BASE, rand, layout, stage, glow } = u;
  // dials moved: palette warm → cold · flicker smoothing ×3 slower · flare = a shiver (wider, fainter)
  let flare = 0, wick = 0;
  return {
    press() { flare = 1; },
    frame(dt, t) {
      stage();
      flare = Math.max(0, flare - dt * 0.6);
      wick += (rand(-1, 1) - wick) * Math.min(1, dt * 2);
      const a = 0.06 + 0.02 * wick + flare * 0.10;
      ctx.globalCompositeOperation = "lighter";
      glow(W / 2, MID - BASE * 0.3, BASE * (2.6 + wick * 0.2 + flare * 2.4), "rgba(140,190,255," + a + ")");
      ctx.globalCompositeOperation = "source-over";
      const L = layout();
      ctx.fillStyle = "rgba(210,230,255,0.85)";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Halo lift", "Heartbeat halo", "the same halo on a lub-dub — two quick pulses, then the long rest", function (u) {
  const { ctx, W, MID, BASE, layout, stage, glow } = u;
  // dials moved: waveform sine → double-pulse · palette cool → warm
  let lift = 0;
  return {
    press() { lift = 1; },
    frame(dt, t) {
      stage();
      lift = Math.max(0, lift - dt * 0.7);
      const beat = (t * 62 / 60) % 1;      // the same clock a heart keeps
      const k = Math.max(Math.exp(-beat * 14), 0.7 * (beat > 0.28 ? Math.exp(-(beat - 0.28) * 14) : 0));
      ctx.globalCompositeOperation = "lighter";
      glow(W / 2, MID - BASE * 0.3, BASE * (2.6 + k * 1.2) * (1 + lift), "rgba(255,150,140," + (0.13 + k * 0.10 + lift * 0.1) + ")");
      ctx.globalCompositeOperation = "source-over";
      const L = layout();
      ctx.fillStyle = "#FFE9E4";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Supernova", "Black sun", "inverted — a dark core wearing a bright rim, and the rings run inward", function (u) {
  const { ctx, W, MID, BASE, layout, stage, glow, TAU } = u;
  // dials moved: glow polarity inverted (dark centre, lit rim) · press rings travel IN, not out
  let rings = [];
  return {
    press() { rings.push({ r: BASE * 4.5, a: 0.8 }); },
    frame(dt, t) {
      stage();
      const cx = W / 2, cy = MID - BASE * 0.3;
      ctx.globalCompositeOperation = "lighter";
      glow(cx, cy, BASE * 4.6, "rgba(200,170,255,0.16)"); // the corona
      ctx.globalCompositeOperation = "source-over";
      glow(cx, cy, BASE * 2.4, "rgba(8,5,16," + (0.75 + 0.05 * Math.sin(t * 2)) + ")");  // the dark heart
      ctx.globalCompositeOperation = "lighter";
      for (const r of rings) {
        r.r -= dt * BASE * 3; r.a -= dt * 0.5;             // falling home
        if (r.a > 0 && r.r > 2) {
          ctx.strokeStyle = "rgba(210,180,255," + r.a + ")";
          ctx.lineWidth = 2;
          ctx.beginPath(); ctx.arc(cx, cy, r.r, 0, TAU); ctx.stroke();
        }
      }
      rings = rings.filter(r => r.a > 0 && r.r > 2);
      ctx.globalCompositeOperation = "source-over";
      const L = layout(BASE, 0, 700);
      ctx.strokeStyle = "rgba(220,190,255,0.9)";           // rim-lit letters over the void
      ctx.lineWidth = 1.2;
      for (const l of L) ctx.strokeText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Neon sign", "Broken neon", "cyan, and one letter is properly broken — it buzzes until you press to heal it", function (u) {
  const { ctx, BASE, rand, layout, stage, glow } = u;
  // dials moved: palette magenta → cyan · the failure is pinned to one letter · press heals instead of stuttering
  const BROKEN = 2;                        // this letter has seen things
  let heal = 0;
  return {
    press() { heal = 3; },
    frame(dt, t) {
      stage();
      heal = Math.max(0, heal - dt);
      const L = layout(BASE, 0, 500);
      for (const l of L) {
        if (l.ch === " ") continue;
        let on = true;
        if (l.i === BROKEN && heal <= 0) on = Math.random() < 0.45;      // the buzz
        ctx.globalCompositeOperation = "lighter";
        if (on) glow(l.cx, l.y - BASE * 0.32, BASE * 0.9, "rgba(80,230,255,0.28)");
        ctx.globalCompositeOperation = "source-over";
        ctx.font = u.font(500, BASE);
        ctx.fillStyle = on ? "#BFF4FF" : "rgba(50,90,110,0.5)";
        ctx.fillText(l.ch, l.x, l.y);
        ctx.strokeStyle = on ? "rgba(150,240,255,0.9)" : "rgba(50,90,110,0.4)";
        ctx.lineWidth = 1;
        ctx.strokeText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Ember text", "Frost light", "the same inner light gone cold — the shimmer sinks instead of rising", function (u) {
  const { ctx, BASE, rand, layout, stage, glow } = u;
  // dials moved: palette ember → frost · motes fall (vy flipped) · pulse ×0.6 slower
  let motes = [];
  return {
    press() {
      const L = layout();
      for (let i = 0; i < 14; i++) {
        const l = L[Math.floor(rand(0, L.length))];
        motes.push({ x: l.cx + rand(-4, 4), y: l.y - rand(0, BASE * 0.6), vy: rand(14, 30), life: 1 });
      }
    },
    frame(dt, t) {
      stage();
      const L = layout(BASE, 0, 600);
      if (Math.random() < 0.35) {
        const l = L[Math.floor(rand(0, L.length))];
        if (l.ch !== " ") motes.push({ x: l.cx + rand(-3, 3), y: l.y - rand(BASE * 0.3, BASE * 0.8), vy: rand(8, 18), life: 0.8 });
      }
      ctx.globalCompositeOperation = "lighter";
      for (const l of L) {
        if (l.ch === " ") continue;
        const chill = 0.5 + 0.5 * Math.sin(t * 1.0 + l.i * 1.31);
        glow(l.cx, l.y - BASE * 0.28, BASE * 0.65, "rgba(150,200,255," + (0.12 + chill * 0.10) + ")");
      }
      for (const m of motes) {
        m.y += m.vy * dt; m.x += Math.sin(m.y * 0.15) * 8 * dt; m.life -= dt * 1.1;
        if (m.life > 0) glow(m.x, m.y, 2 + m.life * 2, "rgba(180,220,255," + m.life * 0.6 + ")");
      }
      motes = motes.filter(m => m.life > 0);
      ctx.globalCompositeOperation = "source-over";
      for (const l of L) {
        const chill = 0.5 + 0.5 * Math.sin(t * 1.0 + l.i * 1.31);
        ctx.fillStyle = "rgb(" + Math.round(180 + chill * 40) + "," + Math.round(210 + chill * 30) + ",255)";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Beacon sweep", "Lighthouse", "the same beam at sea pace — half the speed, nearly twice the width", function (u) {
  const { ctx, W, MID, BASE, DIM, layout, stage, glow } = u;
  // dials moved: sweep speed ×0.5 · beam width ×1.8 · a faint fog ring added around the lamp
  let hurry = 0;
  return {
    press() { hurry = 1; },
    frame(dt, t) {
      stage();
      hurry = Math.max(0, hurry - dt * 0.5);
      const bx = W * (0.5 + 0.55 * Math.sin(t * (0.4 + hurry * 1.1)));
      ctx.globalCompositeOperation = "lighter";
      glow(bx, MID - BASE * 0.3, BASE * 4.0, "rgba(255,245,200,0.13)");
      glow(bx, MID - BASE * 0.3, BASE * 1.4, "rgba(255,250,225,0.15)");
      ctx.globalCompositeOperation = "source-over";
      const L = layout();
      for (const l of L) {
        const k = Math.max(0, 1 - Math.abs(l.cx - bx) / (BASE * 4.0));
        ctx.fillStyle = k > 0.02 ? "rgba(255,248,220," + Math.min(1, 0.25 + k) + ")" : DIM;
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Chromatic halo", "Duotone drift", "two inks instead of three — teal and orange, drifting apart on one axis", function (u) {
  const { ctx, W, MID, BASE, layout, stage, glow } = u;
  // dials moved: plates 3 → 2 · drift becomes horizontal-only · speed ×0.6
  let snap = 0;
  return {
    press() { snap = 1; },
    frame(dt, t) {
      stage();
      snap = Math.max(0, snap - dt * 0.8);
      const drift = BASE * 0.6 * (0.5 + 0.5 * Math.sin(t * 0.42)) * (1 - snap);
      const cx = W / 2, cy = MID - BASE * 0.3;
      ctx.globalCompositeOperation = "lighter";
      glow(cx - drift, cy, BASE * 2.2, "rgba(60,210,200,0.18)");
      glow(cx + drift, cy, BASE * 2.2, "rgba(255,150,70,0.18)");
      ctx.globalCompositeOperation = "source-over";
      const L = layout();
      ctx.fillStyle = "#F2F0FA";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Typewriter", "Heavy typewriter", "the same machine with weight behind it — slower, bold, each letter lands with a stamp", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: cadence 0.12s → 0.22s · weight 400 → 700 · each arrival punches the frame
  let shown = 0, timer = 0, rest = 0, punch = 0;
  return {
    press() { shown = 0; timer = 0; rest = 0; },
    frame(dt, t) {
      stage();
      punch = Math.max(0, punch - dt * 8);
      const L = layout(BASE, 0, 700);
      if (shown < L.length) {
        timer += dt;
        if (timer > 0.22) { timer = 0; shown++; punch = 1; }
      } else { rest += dt; if (rest > 3.5) { rest = 0; shown = 0; } }
      ctx.save();
      ctx.translate(rand(-1, 1) * punch * 1.5, punch * 2);               // the whole page takes the hit
      ctx.fillStyle = INK;
      for (const l of L) {
        if (l.i >= shown) continue;
        const fresh = l.i === shown - 1 ? punch : 0;
        ctx.save();
        ctx.translate(l.cx, l.y);
        ctx.scale(1 + fresh * 0.25, 1 + fresh * 0.25);     // the stamp, mid-landing
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
      if (Math.sin(t * 7) > -0.2) {
        const cx = shown < L.length ? L[shown].x : L[L.length - 1].x + L[L.length - 1].w + 2;
        ctx.fillRect(cx, L[0].y - BASE * 0.72, BASE * 0.5, BASE * 0.82);
      }
      ctx.restore();
    }
  };
});

rhymeOf("Hesitant typist", "Confident typist", "no hesitation at all — a steady clip and a proud underline flourish at the end", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: delays flattened to one fast beat · the dithering removed · a flourish added at the end
  let shown = 0, wait = 0.2, flourish = 0;
  return {
    press() { shown = 0; wait = 0.15; flourish = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      wait -= dt;
      if (wait <= 0) {
        if (shown < L.length) { shown++; wait = 0.06; if (shown === L.length) { flourish = 0.001; wait = 3.5; } }
        else { shown = 0; flourish = 0; wait = 0.15; }
      }
      if (flourish > 0) flourish = Math.min(1, flourish + dt * 2.5);
      ctx.fillStyle = INK;
      for (const l of L) if (l.i < shown) ctx.fillText(l.ch, l.x, l.y);
      if (flourish > 0) {                  // the underline, drawn like a signature
        const x0 = L[0].x, x1 = L[L.length - 1].x + L[L.length - 1].w;
        ctx.strokeStyle = "rgba(180,210,255,0.9)";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(x0, L[0].y + 7);
        ctx.lineTo(x0 + (x1 - x0) * flourish, L[0].y + 7 + Math.sin(flourish * 7) * 2);
        ctx.stroke();
      }
    }
  };
});

rhymeOf("Backspace & correct", "Overtype", "no backspace on this machine — mistakes stay, struck through, corrected above", function (u) {
  const { ctx, INK, BASE, PHRASE, rand, scramble, layout, stage } = u;
  // dials moved: correction policy — the error is kept (struck + small fix above) instead of erased
  let typed = [], wait = 0.3, rest = 0;    // typed: {ch, bad}
  return {
    press() { typed = []; rest = 0; wait = 0.2; },
    frame(dt, t) {
      stage();
      const L = layout();
      wait -= dt;
      if (wait <= 0) {
        if (typed.length < PHRASE.length) {
          const bad = Math.random() < 0.18 && PHRASE[typed.length] !== " ";
          typed.push({ ch: bad ? scramble() : PHRASE[typed.length], bad: bad });
          wait = rand(0.07, 0.18);
        } else { rest += dt; if (rest > 3.2) { typed = []; rest = 0; } wait = 0.1; }
      }
      for (let i = 0; i < typed.length; i++) {
        const l = L[i], e = typed[i];
        ctx.fillStyle = e.bad ? "rgba(232,229,244,0.5)" : INK;
        ctx.fillText(e.ch, l.x, l.y);
        if (e.bad) {                       // the strike, and the correction squeezed in above
          ctx.strokeStyle = "rgba(230,150,150,0.9)";
          ctx.lineWidth = 1.5;
          ctx.beginPath(); ctx.moveTo(l.x - 1, l.y - BASE * 0.26); ctx.lineTo(l.x + l.w + 1, l.y - BASE * 0.3); ctx.stroke();
          ctx.font = u.font(400, BASE * 0.55);
          ctx.fillStyle = INK;
          ctx.fillText(PHRASE[i], l.cx - l.w * 0.25, l.y - BASE * 0.75);
          ctx.font = u.font(400, BASE);
        }
      }
      if (Math.sin(t * 7) > -0.2 && typed.length < L.length) {
        ctx.fillStyle = INK;
        ctx.fillRect(L[typed.length].x, L[0].y - BASE * 0.72, BASE * 0.5, BASE * 0.82);
      }
    }
  };
});

rhymeOf("Word by word", "Line by line", "coarser grain — the phrase arrives as two half-lines, each sliding up as a block", function (u) {
  const { ctx, INK, BASE, PHRASE, layout, stage } = u;
  // dials moved: granularity word → half-phrase · arrivals slide up instead of popping
  const split = PHRASE.indexOf(" ") + 1;   // everything before/after the first space
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      if (clock > 6) clock = 0;
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const half = l.i < split ? 0 : 1;
        const p = Math.min(1, Math.max(0, (clock - 0.3 - half * 1.1) / 0.7));
        if (p <= 0) continue;
        const e = 1 - Math.pow(1 - p, 3);
        ctx.globalAlpha = e;
        ctx.fillText(l.ch, l.x, l.y + (1 - e) * BASE * 0.9);
        ctx.globalAlpha = 1;
      }
    }
  };
});

rhymeOf("Teletype", "Telegraph", "dots and dashes tick in above each letter before it resolves — the jolt halved", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: a morse tick precedes each arrival · jolt ×0.5 · cadence slightly uneven
  let shown = 0, timer = 0, jolt = 0, rest = 0, tick = 0;
  return {
    press() { shown = 0; rest = 0; },
    frame(dt, t) {
      stage();
      jolt = Math.max(0, jolt - dt * 6);
      const L = layout(BASE, 0, 600);
      if (shown < L.length) {
        timer += dt;
        tick = timer / 0.16;               // 0..1 while this letter's code is arriving
        if (timer > rand(0.14, 0.2)) { timer = 0; shown++; jolt = 0.5; }
      } else { rest += dt; if (rest > 3) { rest = 0; shown = 0; } }
      ctx.save();
      ctx.translate(rand(-1, 1) * jolt * 1.2, rand(-1, 1) * jolt * 0.7);
      ctx.fillStyle = INK;
      for (const l of L) if (l.i < shown) ctx.fillText(l.ch, l.x, l.y);
      if (shown < L.length) {              // the incoming code: dot or dash, by parity
        const l = L[shown];
        ctx.fillStyle = "rgba(180,220,255,0.9)";
        if (l.i % 2) ctx.fillRect(l.cx - 4, l.y - BASE * 1.05, 8, 2);    // dash
        else ctx.fillRect(l.cx - 1.5, l.y - BASE * 1.05, 3, 3);          // dot
      }
      ctx.restore();
    }
  };
});

rhymeOf("Dialogue box", "Villain dialogue", "the same box gone wrong — red trim, trembling letters, and no hurrying it", function (u) {
  const { ctx, W, H, MID, INK, BASE, PHRASE, rand, layout, stage } = u;
  // dials moved: palette → red · letters tremble as they sit · fast-forward disabled (the villain talks at their own pace)
  let progress = 0, rest = 0;
  return {
    press() { if (progress >= PHRASE.length) { progress = 0; rest = 0; } },
    frame(dt, t) {
      stage();
      const L = layout(BASE * 0.85);
      const bx = W * 0.06, by = MID - BASE * 1.1, bw = W * 0.88, bh = BASE * 1.9;
      ctx.fillStyle = "rgba(30,10,16,0.9)";
      ctx.fillRect(bx, by, bw, bh);
      ctx.strokeStyle = "rgba(235,90,90,0.8)";
      ctx.lineWidth = 1.5;
      ctx.strokeRect(bx, by, bw, bh);
      if (progress < L.length) progress += dt * 6;         // slower, and it will not be rushed
      else { rest += dt; if (rest > 4) { rest = 0; progress = 0; } }
      ctx.fillStyle = "#F2C8C8";
      for (const l of L)
        if (l.i < progress)
          ctx.fillText(l.ch, l.x + rand(-0.7, 0.7), l.y + rand(-0.7, 0.7));
      if (progress >= L.length && Math.sin(t * 8) > 0) {
        ctx.fillStyle = "rgba(235,90,90,0.9)";
        ctx.beginPath();
        ctx.moveTo(bx + bw - 16, by + bh - 12);
        ctx.lineTo(bx + bw - 8, by + bh - 12);
        ctx.lineTo(bx + bw - 12, by + bh - 6);
        ctx.fill();
      }
    }
  };
});

rhymeOf("Two hands", "The race", "the two ends type at different speeds — the meeting point lands somewhere new each run", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: symmetric cadence → independent speeds per side, re-rolled each run
  let left = 0, right = 0, lWait = 0, rWait = 0, speeds = null, rest = 0;
  return {
    press() { left = right = 0; speeds = null; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!speeds) speeds = { l: rand(0.08, 0.2), r: rand(0.08, 0.2) };
      const total = L.length;
      if (left + right < total) {
        lWait -= dt; rWait -= dt;
        if (lWait <= 0 && left + right < total) { left++; lWait = speeds.l; }
        if (rWait <= 0 && left + right < total) { right++; rWait = speeds.r; }
      } else { rest += dt; if (rest > 3.2) { left = right = 0; speeds = null; rest = 0; } }
      ctx.fillStyle = INK;
      for (const l of L)
        if (l.i < left || l.i >= total - right) ctx.fillText(l.ch, l.x, l.y);
      if (left + right < total && Math.sin(t * 7) > -0.2) {
        ctx.fillStyle = speeds.l <= speeds.r ? INK : "rgba(232,229,244,0.5)";   // the faster hand glows brighter
        ctx.fillRect(L[left].x, L[0].y - BASE * 0.72, BASE * 0.45, BASE * 0.82);
        ctx.fillStyle = speeds.r < speeds.l ? INK : "rgba(232,229,244,0.5)";
        const r = L[total - 1 - right];
        ctx.fillRect(r.x + r.w - BASE * 0.45, r.y - BASE * 0.72, BASE * 0.45, BASE * 0.82);
      }
    }
  };
});

rhymeOf("Dictation", "Redaction", "inverted — the phrase starts as black bars, and the sweep un-redacts it", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: underline → covering bar · reveal replaces conceal · sweep steady, not bursty
  let sweep = 0, rest = 0;
  return {
    press() { sweep = 0; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (sweep < L.length) sweep += dt * 3.2;
      else { rest += dt; if (rest > 3.4) { sweep = 0; rest = 0; } }
      for (const l of L) {
        if (l.ch === " ") continue;
        if (l.i < sweep) { ctx.fillStyle = INK; ctx.fillText(l.ch, l.x, l.y); }
        else {                             // still classified
          ctx.fillStyle = "rgba(40,36,66,0.95)";
          ctx.fillRect(l.x - 1, l.y - BASE * 0.68, l.w + 2, BASE * 0.78);
        }
      }
    }
  };
});

rhymeOf("Firefly pulse", "Slow breath", "the same pulse at rest — twice the period, and it never goes fully dark", function (u) {
  const { ctx, BASE, layout, stage, TAU } = u;
  // dials moved: period 3.6s → 8s · floor 0.08 → 0.35 · press holds the DIM instead of the bright
  let hold = 0;
  return {
    press() { hold = 2.5; },
    frame(dt, t) {
      stage();
      hold = Math.max(0, hold - dt);
      const a = hold > 0 ? 0.35 : 0.35 + 0.65 * Math.pow(0.5 + 0.5 * Math.sin(t * TAU / 8), 2);
      const L = layout();
      ctx.fillStyle = "rgba(232,229,244," + a + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Fade in order", "Fade out of order", "inverted — the phrase stands whole, and random letters briefly step out", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: polarity flipped (visible is the resting state) · order randomized · one absence at a time
  let away = -1, phase = 0;
  return {
    press() { phase = 0; away = -1; },
    frame(dt, t) {
      stage();
      const L = layout();
      phase -= dt;
      if (phase <= 0) { away = Math.floor(rand(0, L.length)); phase = rand(0.8, 1.8); }
      for (const l of L) {
        const gone = l.i === away ? Math.min(1, Math.sin(Math.min(1, 1 - phase / 1.8) * Math.PI) * 1.4) : 0;
        ctx.fillStyle = "rgba(232,229,244," + (1 - gone * 0.95) + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Fade lottery", "Roll call", "the same random order, but strictly one at a time — each to full before the next", function (u) {
  const { ctx, BASE, PHRASE, rand, layout, stage } = u;
  // dials moved: overlap removed (fades queue instead of cascading) · each fade ×2 faster
  let order = [], clock = 0;
  function shuffle() {
    order = PHRASE.split("").map((_, i) => i);
    for (let i = order.length - 1; i > 0; i--) {
      const j = Math.floor(rand(0, i + 1));
      const k = order[i]; order[i] = order[j]; order[j] = k;
    }
  }
  shuffle();
  return {
    press() { shuffle(); clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const per = 0.24;                    // one letter's whole turn
      const cycle = order.length * per + 3;
      if (clock > cycle) { clock = 0; shuffle(); }
      const L = layout();
      for (const l of L) {
        const rank = order.indexOf(l.i);
        const a = Math.min(1, Math.max(0, (clock - rank * per) / per));  // no overlap: turns, not waves
        ctx.fillStyle = "rgba(232,229,244," + a + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Fluorescent", "Dying tube", "the timeline reversed — steady light degrades into stutter, fails, tries again", function (u) {
  const { ctx, W, MID, BASE, rand, layout, stage, glow } = u;
  // dials moved: start steady → end dark (the original's struggle, played backwards)
  let phase = 0, level = 1, next = 0;
  return {
    press() { phase = 0; level = 1; },
    frame(dt, t) {
      stage();
      phase += dt;
      if (phase < 3) level = Math.min(1, level + dt);      // the good years
      else if (phase < 6) {                // the decline
        next -= dt;
        if (next <= 0) { level = Math.random() < 0.6 ? rand(0.4, 0.9) : rand(0, 0.2); next = rand(0.04, 0.3); }
      } else level = Math.max(0, level - dt * 3);          // the end
      if (phase > 7.5) phase = 0;          // …and someone replaces the starter
      ctx.globalCompositeOperation = "lighter";
      glow(W / 2, MID - BASE * 0.3, BASE * 3, "rgba(200,255,235," + level * 0.14 + ")");
      ctx.globalCompositeOperation = "source-over";
      const L = layout();
      ctx.fillStyle = "rgba(225,255,242," + (0.06 + level * 0.94) + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Tide", "Rip tide", "two waves in opposite directions, interfering — some letters get caught between", function (u) {
  const { ctx, BASE, layout, stage } = u;
  // dials moved: a second, counter-travelling wave added · palette cooled further
  let speed = 1;
  return {
    press() { speed = 3; },
    frame(dt, t) {
      stage();
      speed = Math.max(1, speed - dt);
      const L = layout();
      for (const l of L) {
        const w1 = 0.5 + 0.5 * Math.sin(t * 2 * speed - l.i * 0.7);
        const w2 = 0.5 + 0.5 * Math.sin(t * 1.3 * speed + l.i * 0.9);    // the undertow, running back
        const a = 0.1 + 0.9 * Math.pow(w1 * w2, 1.2);      // only where both agree is it bright
        ctx.fillStyle = "rgba(170,215,255," + a + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Afterimage", "Double exposure", "the blink leaves an offset ghost that outlives the phrase itself", function (u) {
  const { ctx, BASE, layout, stage } = u;
  // dials moved: a displaced second exposure added · the ghost decays SLOWER than the main image
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 7) age = 0;
      const aMain = age < 0.12 ? 1 : Math.max(0.02, Math.exp(-(age - 0.12) * 1.4));
      const aGhost = age < 0.12 ? 0.4 : Math.max(0.02, Math.exp(-(age - 0.12) * 0.5)) * 0.5;
      const L = layout(BASE, 0, 400);
      ctx.fillStyle = "rgba(180,190,255," + aGhost + ")";
      for (const l of L) ctx.fillText(l.ch, l.x + BASE * 0.14, l.y - BASE * 0.1);
      ctx.fillStyle = "rgba(240,238,255," + aMain + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Half-light", "Checkerboard", "the crossfade replaced with a snap — the trade happens all at once, twice as often", function (u) {
  const { ctx, BASE, layout, stage } = u;
  // dials moved: crossfade → hard snap · period 4s → 0.9s
  let flip = 0, timer = 0;
  return {
    press() { flip = 1 - flip; timer = 0; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (timer > 0.9) { timer = 0; flip = 1 - flip; }
      const L = layout();
      for (const l of L) {
        const on = (l.i % 2) === flip;
        ctx.fillStyle = "rgba(232,229,244," + (on ? 1 : 0.12) + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Heartbeat", "Sigh", "one slow swell every few seconds, with a small droop after — the tired rhyme", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  // dials moved: waveform lub-dub → single slow swell · a droop added on the exhale
  let race = 0;
  return {
    press() { race = 2.5; },
    frame(dt, t) {
      stage();
      race = Math.max(0, race - dt);
      const period = race > 0 ? 2 : 5.5;
      const ph = (t % period) / period;
      const swell = Math.sin(Math.min(1, ph * 2.2) * Math.PI);           // in… and out
      const droop = Math.max(0, ph - 0.6) * BASE * 0.16;   // the shoulders drop
      const s = 1 + swell * 0.1;
      const L = layout(BASE, 0, 400);
      ctx.fillStyle = INK;
      for (const l of L) {
        ctx.save();
        const mid = W / 2;
        ctx.translate(mid + (l.cx - mid) * s, l.y + droop);
        ctx.scale(s, s);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Pop-in", "Deflate-in", "arrivals reversed — letters appear huge and translucent, shrinking into place", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: scale direction 0→1 becomes 2.4→1 · arrival fades in from thin air
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      const cycle = L.length * 0.11 + 3.4;
      if (clock > cycle) clock = 0;
      for (const l of L) {
        const a = (clock - l.i * 0.11) / 0.5;
        if (a <= 0) continue;
        const p = Math.min(1, a);
        const e = 1 - Math.pow(1 - p, 3);
        const s = 2.4 - 1.4 * e;
        ctx.globalAlpha = e;
        ctx.save();
        ctx.translate(l.cx, l.y);
        ctx.scale(s, s);
        ctx.fillStyle = INK;
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
        ctx.globalAlpha = 1;
      }
    }
  };
});

rhymeOf("Rubber band", "Pancake", "the same spring turned sideways — the press squashes it flat and wide", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: yank axis vertical → horizontal (sy ↔ sx) · yank −: a squash, not a stretch
  let vx = 0, sx = 1;
  return {
    press() { vx = -7; },                  // flatten
    frame(dt, t) {
      stage();
      const k = 90, damp = 6;
      vx += (1 - sx) * k * dt - vx * damp * dt;
      sx += vx * dt;
      const sy = 1 / Math.max(0.4, Math.sqrt(Math.abs(sx) || 0.4));
      const L = layout(BASE, 0, 600);
      ctx.fillStyle = INK;
      const mid = (L[0].x + L[L.length - 1].x + L[L.length - 1].w) / 2;
      for (const l of L) {
        ctx.save();
        ctx.translate(mid + (l.cx - mid) * Math.max(0.3, sx), l.y);
        ctx.scale(Math.max(0.3, sx), sy);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Zoom arrival", "Zoom departure", "the timeline reversed — it stands a while, then rushes past the camera and is gone", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: settle-then-leave instead of arrive-then-settle · it fades as it grows PAST you
  let age = 0;
  return {
    press() { age = 10; },                 // leave NOW
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 6) age = 0;
      const p = Math.min(1, Math.max(0, (age - 2.2) / 0.9));
      const e = p * p * p;                 // slow start, violent exit
      const s = 1 + e * 7;
      const a = 1 - p;
      const L = layout(BASE, 0, 600);
      ctx.fillStyle = "rgba(232,229,244," + a + ")";
      const mid = u.W / 2;
      for (const l of L) {
        ctx.save();
        ctx.translate(mid + (l.cx - mid) * s, l.y + (s - 1) * BASE * 0.2);
        ctx.scale(s, s);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Accordion", "Bellows", "the squeeze turned vertical — the phrase flattens and huffs back to height", function (u) {
  const { ctx, INK, BASE, layout, stage, TAU } = u;
  // dials moved: axis horizontal spacing → vertical scale · the lean becomes a bob
  let push = 0;
  return {
    press() { push = 1; },
    frame(dt, t) {
      stage();
      push = Math.max(0, push - dt * 0.9);
      const k = 0.5 + 0.5 * Math.sin(t * TAU / 4.6 + push * 3);
      const sy = 0.45 + k * 0.65;
      const L = layout(BASE, 0, 500);
      ctx.fillStyle = INK;
      for (const l of L) {
        ctx.save();
        ctx.translate(l.cx, l.y);
        ctx.scale(1, sy);
        ctx.fillText(l.ch, -l.w / 2, Math.sin(t * 3 + l.i) * 1.5);       // the huff
        ctx.restore();
      }
    }
  };
});

rhymeOf("Pinpoint", "Horizon", "born from a line instead of a point — the phrase unfolds vertically like a sunrise", function (u) {
  const { ctx, W, MID, INK, BASE, layout, stage, glow } = u;
  // dials moved: source geometry point → horizontal line · the glow becomes a band
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 6.5) age = 0;
      const p = Math.min(1, age / 1.4);
      const e = p * p * (3 - 2 * p);
      const y0 = MID - BASE * 0.3;
      ctx.globalCompositeOperation = "lighter";            // the line of first light
      const g = ctx.createLinearGradient(0, y0 - 6, 0, y0 + 6);
      g.addColorStop(0, "rgba(255,220,150,0)");
      g.addColorStop(0.5, "rgba(255,220,150," + (0.5 - e * 0.4) + ")");
      g.addColorStop(1, "rgba(255,220,150,0)");
      ctx.fillStyle = g;
      ctx.fillRect(W * 0.1, y0 - 6, W * 0.8, 12);
      ctx.globalCompositeOperation = "source-over";
      if (e <= 0.02) return;
      const L = layout();
      ctx.fillStyle = "rgba(250,240,220," + e + ")";
      for (const l of L) {
        ctx.save();
        ctx.translate(l.cx, y0);
        ctx.scale(1, Math.max(0.01, e));   // unfolds upward and downward from the line
        ctx.fillText(l.ch, -l.w / 2, BASE * 0.3);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Giant's whisper", "Whisper's giant", "the loop reversed — it snaps huge, then spends its time shrinking back down", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  // dials moved: grow-then-snap → snap-then-shrink · the bold moment moves to the start
  let s = 1.45, snap = 0;
  return {
    press() { snap = 1; },
    frame(dt, t) {
      stage();
      if (snap > 0) { s = 1.45; snap = 0; }
      s -= dt * 0.16;
      if (s < 0.6) s = 1.45;
      const L = layout(BASE * s, 0, s > 1.2 ? 700 : 400);
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Decoder", "Encoder", "run backwards — a clean phrase corrupts letter by letter into cipher, then returns", function (u) {
  const { ctx, INK, BASE, scramble, layout, stage } = u;
  // dials moved: resolve direction flipped (readable → cipher) · the cycle breathes both ways
  let lost = 0, timer = 0, churn = [], churnT = 0, dir = 1;
  return {
    press() { dir = -dir; },               // reverse the machine mid-run
    frame(dt, t) {
      stage();
      const L = layout();
      churnT += dt;
      if (churnT > 0.05) { churnT = 0; churn = L.map(() => scramble()); }
      timer += dt;
      if (timer > 0.22) {
        timer = 0;
        lost += dir;
        if (lost >= L.length) { lost = L.length; dir = -1; }
        if (lost <= 0) { lost = 0; dir = 1; }
      }
      for (const l of L) {
        if (l.ch === " ") continue;
        const gone = l.i < lost;
        ctx.fillStyle = gone ? "rgba(230,170,150,0.75)" : INK;
        ctx.fillText(gone ? churn[l.i] : l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Slot machine", "Jackpot", "the reels spin faster and all brake at the same instant — then the win flash", function (u) {
  const { ctx, W, MID, INK, BASE, GLYPHS, rand, layout, stage, glow } = u;
  // dials moved: staggered stops → one shared stop · spin speed ×1.6 · a payout flash added
  let reels = null, rest = 0, spinT = 0, flash = 0;
  function spinUp(L) {
    reels = L.map(() => ({ v: rand(24, 30), off: rand(0, GLYPHS.length), done: false }));
    spinT = 0; flash = 0;
  }
  return {
    press() { reels = null; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!reels) spinUp(L);
      spinT += dt;
      const lh = BASE * 1.08;
      const STOP = 1.6;                    // everyone, together
      let allDone = true;
      for (const l of L) {
        if (l.ch === " ") continue;
        const r = reels[l.i];
        if (!r.done) {
          if (spinT > STOP) r.v = Math.max(0, r.v - dt * 40);
          r.off += r.v * dt;
          if (spinT > STOP && r.v < 0.8) { r.done = true; r.off = 0; if (reels.every((x, i) => L[i].ch === " " || x.done)) flash = 1; }
        }
        if (!r.done) allDone = false;
        ctx.save();
        ctx.beginPath();
        ctx.rect(l.x - 2, l.y - BASE * 0.95, l.w + 4, BASE * 1.35);
        ctx.clip();
        if (r.done) {
          ctx.fillStyle = INK;
          ctx.fillText(l.ch, l.x, l.y);
        } else {
          const frac = r.off % 1;
          for (let k = -1; k <= 1; k++) {
            const gi = (Math.floor(r.off) + k + GLYPHS.length * 4) % GLYPHS.length;
            ctx.fillStyle = "rgba(255,215,140," + (0.75 - Math.abs(k - frac) * 0.3) + ")";
            ctx.fillText(GLYPHS[gi], l.x, l.y + (k - frac) * lh);
          }
        }
        ctx.restore();
      }
      if (flash > 0) {                     // the house pays out in light
        ctx.globalCompositeOperation = "lighter";
        glow(W / 2, MID - BASE * 0.3, BASE * 4 * (1.4 - flash), "rgba(255,215,120," + flash * 0.4 + ")");
        ctx.globalCompositeOperation = "source-over";
        flash = Math.max(0, flash - dt * 1.2);
      }
      if (allDone) { rest += dt; if (rest > 3) { reels = null; rest = 0; } }
    }
  };
});

rhymeOf("Jumble home", "Scatter", "the loop inverted — it rests assembled, and the press is what throws it", function (u) {
  const { ctx, W, H, INK, BASE, rand, layout, stage } = u;
  // dials moved: driven by press instead of a cycle · scatter is an explosion, not a shuffle
  let pts = null, thrown = 0;
  return {
    press() {
      const L = layout();
      pts = L.map(l => ({ x: l.cx + rand(-1, 1) * W * 0.3, y: l.y + rand(-1, 1) * H * 0.45, r: rand(-2, 2) }));
      thrown = 1;
    },
    frame(dt, t) {
      stage();
      const L = layout();
      thrown = Math.max(0, thrown - dt * 0.55);
      const e = 1 - Math.pow(thrown, 2);   // eases home as thrown decays
      ctx.fillStyle = INK;
      for (const l of L) {
        const s = pts ? pts[l.i] : null;
        const x = s ? s.x + (l.cx - s.x) * e : l.cx;
        const y = s ? s.y + (l.y - s.y) * e : l.y;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(s ? s.r * (1 - e) : 0);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Matrix rain", "Blossom rain", "the rain warms and reverses — petals drift UP, and the phrase blooms out of them", function (u) {
  const { ctx, W, H, BASE, rand, scramble, layout, stage } = u;
  // dials moved: palette green → pink · fall direction flipped · resolve softer (no flicker)
  const cols = Math.floor(W / 12);
  let drops = [], resolve = 0;
  for (let i = 0; i < cols; i++) drops.push({ x: 6 + i * 12, y: rand(0, H), v: rand(24, 70) });
  return {
    press() { resolve = 0; },
    frame(dt, t) {
      stage();
      resolve += dt;
      ctx.font = "12px 'Spline Sans Mono', monospace";
      for (const d of drops) {
        d.y -= d.v * dt;                   // upward, unhurried
        if (d.y < -20) { d.y = H + rand(10, 40); d.v = rand(24, 70); }
        ctx.fillStyle = "rgba(255,150,190,0.3)";
        ctx.fillText(scramble(), d.x, d.y);
        ctx.fillStyle = "rgba(255,200,220,0.45)";
        ctx.fillText(scramble(), d.x, d.y + 14);
      }
      const L = layout();
      for (const l of L) {
        if (l.ch === " ") continue;
        const k = Math.min(1, Math.max(0, (resolve - 1 - l.i * 0.18) / 1.2));
        if (k <= 0) continue;
        ctx.font = u.font(500, BASE);
        ctx.fillStyle = "rgba(255,225,235," + k + ")";
        ctx.fillText(l.ch, l.x, l.y);      // no flicker: blossoms open once
      }
      if (resolve > 9) resolve = 0;
    }
  };
});

rhymeOf("Anagram walk", "Neighbour swap", "only adjacent letters trade, twice as often — the phrase stays almost readable", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: swap distance any → adjacent only · rate ×2 · the travel arc lowered
  let perm = null, from = null, lerp = 1, wait = 0.3, home = 0;
  return {
    press() { home = 3; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!perm) { perm = L.map((_, i) => i); from = perm.slice(); }
      home = Math.max(0, home - dt);
      lerp = Math.min(1, lerp + dt * 3);
      wait -= dt;
      if (wait <= 0 && lerp >= 1 && home <= 0) {
        from = perm.slice();
        const a = Math.floor(rand(0, L.length - 1)), b = a + 1;          // the whole dial: b = a+1
        const k = perm[a]; perm[a] = perm[b]; perm[b] = k;
        lerp = 0; wait = rand(0.15, 0.45);
      }
      const target = home > 0 ? L.map((_, i) => i) : perm;
      ctx.fillStyle = home > 0 ? "rgba(180,240,200,1)" : INK;
      for (const l of L) {
        const slotNow = target[l.i], slotWas = from[l.i];
        const e = lerp * lerp * (3 - 2 * lerp);
        const x = L[slotWas].cx + (L[slotNow].cx - L[slotWas].cx) * e;
        const arc = Math.sin(e * Math.PI) * (slotNow === slotWas ? 0 : BASE * 0.22);
        ctx.save();
        ctx.translate(x, l.y - arc);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Static tune", "Ghost signal", "tuned letters LINGER after the dial moves on — the broadcast refuses to die", function (u) {
  const { ctx, W, INK, BASE, rand, scramble, layout, stage } = u;
  // dials moved: persistence added (clarity decays slowly instead of following the dial) · sweep ×0.6
  let dial = 0, dir = 1, mem = null;
  return {
    press() { dir = -dir; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!mem) mem = L.map(() => 0);
      dial += dir * dt * 0.21;
      if (dial > 1.3) { dial = 1.3; dir = -1; }
      if (dial < -0.3) { dial = -0.3; dir = 1; }
      const fx = W * dial;
      for (const l of L) {
        if (l.ch === " ") continue;
        const k = Math.max(0, 1 - Math.abs(l.cx - fx) / (W * 0.22));
        mem[l.i] = Math.max(mem[l.i] - dt * 0.12, k);      // the ghost: clarity is remembered
        const c = mem[l.i];
        const clear = c > rand(0, 1) * 0.7;
        ctx.fillStyle = clear ? "rgba(232,229,244," + (0.3 + c * 0.7) + ")" : "rgba(150,145,190,0.4)";
        ctx.fillText(clear ? l.ch : scramble(), l.x, l.y + (1 - c) * rand(-1.5, 1.5));
      }
      ctx.fillStyle = "rgba(180,220,255,0.5)";
      ctx.fillRect(fx - 1, u.MID + BASE * 0.5, 2, BASE * 0.3);
    }
  };
});

rhymeOf("Cipher wheel", "Countdown", "letters land when their digit hits zero — every slot counts down from nine", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: alphabet wheel → digits 9..0 · spin variable → fixed count, staggered start
  let counts = null, rest = 0;
  return {
    press() { counts = null; rest = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!counts) counts = L.map(l => 9 + l.i * 2);       // later letters start higher
      let allDone = true;
      for (const l of L) {
        if (l.ch === " ") continue;
        if (counts[l.i] > 0) {
          allDone = false;
          counts[l.i] -= dt * 7;
          if (counts[l.i] < 0) counts[l.i] = 0;
        }
        const c = Math.ceil(counts[l.i]);
        if (c > 0) {
          ctx.fillStyle = "rgba(230,200,150,0.75)";
          ctx.fillText("" + (c % 10), l.x, l.y);
        } else {
          ctx.fillStyle = INK;
          ctx.fillText(l.ch, l.x, l.y);
        }
      }
      if (allDone) { rest += dt; if (rest > 3.2) { counts = null; rest = 0; } }
    }
  };
});

rhymeOf("Number station", "Morse station", "dots and dashes instead of digits — and the press decodes one word at a time", function (u) {
  const { ctx, INK, BASE, PHRASE, rand, layout, stage } = u;
  // dials moved: glyph set digits → morse marks · resolve granularity all-at-once → word by word
  const starts = [0];
  for (let i = 0; i < PHRASE.length; i++) if (PHRASE[i] === " ") starts.push(i + 1);
  let clearWords = 0, fade = 0, marks = [], mT = 0;
  function wordOf(i) { let w = 0; for (let s = 1; s < starts.length; s++) if (i >= starts[s]) w = s; return w; }
  return {
    press() { clearWords = Math.min(starts.length, clearWords + 1); fade = 6; },
    frame(dt, t) {
      stage();
      fade -= dt;
      if (fade <= 0 && clearWords > 0) { clearWords = 0; }               // the station goes dark again
      mT += dt;
      const L = layout();
      if (mT > 0.2) { mT = 0; marks = L.map(() => Math.random() < 0.5); }
      for (const l of L) {
        if (l.ch === " ") continue;
        if (wordOf(l.i) < clearWords) {
          ctx.fillStyle = "rgba(200,235,255,0.95)";
          ctx.fillText(l.ch, l.x, l.y);
        } else {
          ctx.fillStyle = "rgba(140,170,200,0.7)";
          if (marks[l.i]) ctx.fillRect(l.cx - 4, l.y - BASE * 0.3, 8, 2);            // dash
          else ctx.fillRect(l.cx - 1.5, l.y - BASE * 0.3, 3, 3);                     // dot
        }
      }
      ctx.fillStyle = "rgba(140,170,200,0.35)";
      ctx.font = "10px 'Spline Sans Mono', monospace";
      ctx.fillText(clearWords > 0 ? "— decoding —" : "— traffic —", 8, 14);
    }
  };
});

rhymeOf("Sine wave", "Standing wave", "the travel removed — fixed nodes and antinodes, physics-classroom style", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: phase travel removed (position sets amplitude, not phase) · amp ×1.4
  let amp = 1;
  return {
    press() { amp = 2.6; },
    frame(dt, t) {
      stage();
      amp = Math.max(1, amp - dt * 1.1);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const envelope = Math.sin(l.i / (l.n - 1) * Math.PI * 2);        // two nodes across the phrase
        const y = Math.sin(t * 3) * envelope * BASE * 0.22 * amp;
        ctx.fillText(l.ch, l.x, l.y + y);
      }
    }
  };
});

rhymeOf("Stadium wave", "The dip", "the jump turned upside down — each letter ducks in turn instead", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: direction up → down · the squash happens at the top, not the floor
  let extra = 0;
  return {
    press() { extra = 1; },
    frame(dt, t) {
      stage();
      extra = Math.max(0, extra - dt * 1.8);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const phase = (t * 1.1 - l.i * 0.09) % 1;
        const duck = phase < 0.22 ? Math.sin(phase / 0.22 * Math.PI) : 0;
        const k = Math.max(duck, extra);
        ctx.save();
        ctx.translate(l.cx, l.y + k * BASE * 0.3);
        ctx.scale(1 + k * 0.15, 1 - k * 0.3);              // flattening as it ducks
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Bounce-in", "Moon bounce", "gravity quartered, bounces livelier — the same drop on a smaller world", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: gravity 9 → 2.2 · restitution 0.45 → 0.6 · stagger widened
  let clock = 0;
  function bounceY(a) {
    if (a < 0) return -1.4;
    const g = 2.2, e = 0.6;
    let v = 0, y = -1.4, tt = a;
    for (let hop = 0; hop < 5; hop++) {
      const tImpact = (Math.sqrt(v * v + 2 * g * -y) - v) / g;
      if (tt < tImpact) return y + v * tt + 0.5 * g * tt * tt;
      tt -= tImpact; v = -(v + g * tImpact) * e; y = 0;
      if (Math.abs(v) < 0.2) return 0;
    }
    return 0;
  }
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (clock > L.length * 0.18 + 8) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        const y = bounceY(clock - l.i * 0.18);
        if (y <= -1.39) continue;
        ctx.save();
        ctx.translate(l.cx, l.y + y * BASE * 1.2);
        if (Math.abs(y) < 0.02) ctx.scale(1.06, 0.94);     // gentler squash: the landings are soft up here
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Jelly", "Set gelatin", "the resting wobble dies away to stillness — until a press jiggles it twice as hard", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  // dials moved: idle wobble decays to zero · press ripple amplitude ×2
  let waves = [], calm = 0;
  return {
    press(x) { waves.push({ x: x === undefined ? W / 2 : x, age: 0 }); calm = 0; },
    frame(dt, t) {
      stage();
      calm = Math.min(1, calm + dt * 0.25);                // stillness earns itself back
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        let y = Math.sin(t * 3 + l.i * 1.7) * BASE * 0.03 * (1 - calm);
        let s = 1;
        for (const w of waves) {
          const d = Math.abs(l.cx - w.x);
          const front = w.age * W * 0.9;
          const k = Math.exp(-Math.pow((d - front) / (BASE * 1.2), 2)) * Math.max(0, 1 - w.age * 1.2);
          y -= k * BASE * 0.7;
          s += k * 0.4;
        }
        ctx.save();
        ctx.translate(l.cx, l.y + y);
        ctx.scale(s, 2 - s);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
      for (const w of waves) w.age += dt;
      waves = waves.filter(w => w.age < 1.2);
    }
  };
});

rhymeOf("Pendulum", "Metronome", "all the pendulums lock into sync, and the swing ticks in quantized beats", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: per-letter drift removed (one shared period) · motion quantized to ticks
  let push = 0;
  return {
    press() { push = 1; },
    frame(dt, t) {
      stage();
      push = Math.max(0, push - dt * 0.5);
      const beat = Math.round(Math.sin(t * 3.2) * 2) / 2;  // −1, −0.5, 0, 0.5, 1: the escapement
      const a = beat * (0.12 + push * 0.2);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        ctx.save();
        ctx.translate(l.cx, l.y - BASE * 0.75);
        ctx.rotate(a);
        ctx.fillText(l.ch, -l.w / 2, BASE * 0.75);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Buoy", "Storm swell", "the same sea in worse weather — bigger, faster, with spray at the crests", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: amplitude ×2.5 · speed ×1.7 · spray flecks added at wave tops
  let chop = 0, spray = [];
  return {
    press() { chop = 1; },
    frame(dt, t) {
      stage();
      chop = Math.max(0, chop - dt * 0.4);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const k = (1 + chop * 1.5) * 2.5;
        const y = (Math.sin(t * 2.2 + l.i * 0.9) * 0.5 + Math.sin(t * 4.6 + l.i * 2.3) * 0.3) * BASE * 0.12 * k;
        const tilt = Math.sin(t * 1.9 + l.i * 1.4) * 0.14 * (1 + chop);
        if (y < -BASE * 0.22 && Math.random() < 0.1)       // a crest breaks
          spray.push({ x: l.cx + rand(-3, 3), y: l.y + y - BASE * 0.5, vx: rand(-20, 20), vy: rand(-40, -10), life: 0.7 });
        ctx.save();
        ctx.translate(l.cx, l.y + y);
        ctx.rotate(tilt);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
      ctx.fillStyle = "rgba(200,225,255,0.7)";
      for (const s of spray) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 90 * dt; s.life -= dt * 1.4;
        if (s.life > 0) ctx.fillRect(s.x, s.y, 1.6, 1.6);
      }
      spray = spray.filter(s => s.life > 0);
    }
  };
});

rhymeOf("Skip rope", "Double dutch", "two ropes in counter-phase — odd letters ride one, even letters the other", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: a second rope added at opposite phase · turn rate ×1.25
  let speed = 1;
  return {
    press() { speed = 2.2; },
    frame(dt, t) {
      stage();
      speed = Math.max(1, speed - dt * 0.8);
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const arc = Math.sin(l.i / (l.n - 1) * Math.PI);
        const phase = t * 4 * speed + (l.i % 2 ? Math.PI : 0);           // the second rope
        const y = Math.sin(phase) * arc * BASE * 0.34;
        ctx.save();
        ctx.translate(l.cx, l.y + y);
        ctx.scale(1, Math.max(0.5, 1 - Math.abs(Math.sin(phase)) * arc * 0.12));
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Ripple press", "Stone skip", "one press throws a skipping stone — three splashes in a row, each smaller", function (u) {
  const { ctx, W, INK, BASE, MID, layout, stage, TAU } = u;
  // dials moved: one drop → three, spaced and delayed like a skipping stone · rings ×0.7 smaller
  let drops = [];
  return {
    press(x, y) {
      const sx = x === undefined ? W * 0.25 : x;
      for (let s = 0; s < 3; s++)          // each skip lands further along, later, smaller
        drops.push({ x: sx + s * W * 0.22, y: MID - BASE * 0.5, age: -s * 0.35, k: 1 - s * 0.3 });
    },
    frame(dt, t) {
      stage();
      const L = layout();
      for (const d of drops) {
        d.age += dt;
        if (d.age < 0) continue;
        const r = d.age * W * 0.5 * d.k;
        ctx.strokeStyle = "rgba(160,190,255," + Math.max(0, 0.4 - d.age * 0.33) * d.k + ")";
        ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(d.x, d.y, r, 0, TAU); ctx.stroke();
      }
      ctx.fillStyle = INK;
      for (const l of L) {
        let y = 0;
        for (const d of drops) {
          if (d.age < 0) continue;
          const dist = Math.hypot(l.cx - d.x, l.y - BASE * 0.3 - d.y);
          const front = d.age * W * 0.5 * d.k;
          y -= Math.exp(-Math.pow((dist - front) / (BASE * 0.9), 2)) * Math.max(0, 1 - d.age * 0.8) * BASE * 0.22 * d.k;
        }
        ctx.fillText(l.ch, l.x, l.y + y);
      }
      drops = drops.filter(d => d.age < 1.4);
    }
  };
});

rhymeOf("Roll call", "Roll away", "the arrival plus its departure — it assembles, holds, then slides off stage right", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  // dials moved: an exit phase added after the dwell · exit accelerates instead of easing
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      const inDone = L.length * 0.1 + 0.55;
      const exitAt = inDone + 2;
      if (clock > exitAt + 1.4) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        let x = l.cx, alpha = 1;
        if (clock < exitAt) {              // the borrowed arrival
          const p = Math.min(1, Math.max(0, (clock - l.i * 0.1) / 0.55));
          if (p <= 0) continue;
          const e = 1 - Math.pow(1 - p, 3);
          x = -BASE + (l.cx + BASE) * e;
          alpha = Math.min(1, p * 2);
        } else {                           // the new exit — last letters leave first
          const p = Math.min(1, Math.max(0, (clock - exitAt - (L.length - 1 - l.i) * 0.06) / 0.6));
          const e = p * p * p;
          x = l.cx + e * (W + BASE - l.cx);
          alpha = 1 - p * 0.6;
        }
        ctx.globalAlpha = alpha;
        ctx.save(); ctx.translate(x, l.y); ctx.fillText(l.ch, -l.w / 2, 0); ctx.restore();
        ctx.globalAlpha = 1;
      }
    }
  };
});

rhymeOf("Rain down", "Snowfall", "the same weather, slower and softer — flakes sway as they settle in", function (u) {
  const { ctx, INK, BASE, H, rand, layout, stage } = u;
  // dials moved: fall speed ×0.35 · a sideways sway added · stagger doubled
  let clock = 0, stagger = null;
  return {
    press() { clock = 0; stagger = null; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (!stagger) stagger = L.map(() => rand(0, 1.8));
      if (clock > 8) { clock = 0; stagger = null; return; }
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (clock - stagger[l.i]) / 1.7));
        if (p <= 0) continue;
        const e = p * p * (3 - 2 * p);     // smooth, not accelerating — snow has no hurry
        const y = -H * 0.4 + (l.y + H * 0.4) * e;
        const sway = Math.sin((1 - p) * 6 + l.i) * (1 - p) * BASE * 0.4;
        ctx.globalAlpha = Math.min(1, p * 3);
        ctx.fillText(l.ch, l.x + sway, y);
        ctx.globalAlpha = 1;
      }
    }
  };
});

rhymeOf("Rise up", "From the deep", "the same rise from much further down — slow, and blue until it surfaces", function (u) {
  const { ctx, BASE, H, layout, stage } = u;
  // dials moved: distance ×1.6 · duration ×2 · a depth tint that clears on arrival
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 8) age = 0;
      const p = Math.min(1, age / 2.6);
      const e = 1 - Math.pow(1 - p, 2);
      const dy = (1 - e) * H * 0.9;
      const L = layout();
      const r = Math.round(120 + e * 112), g = Math.round(160 + e * 69), b = 244;
      ctx.fillStyle = "rgba(" + r + "," + g + "," + b + "," + Math.min(1, p * 1.4) + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y + dy);
    }
  };
});

rhymeOf("Crossroads", "Zipper", "the same interleave rotated ninety degrees — odd from above, even from below", function (u) {
  const { ctx, H, INK, BASE, layout, stage } = u;
  // dials moved: axis horizontal → vertical · arrivals overlap more tightly
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 5.5) age = 0;
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (age - l.i * 0.03) / 0.8));
        const e = 1 - Math.pow(1 - p, 3);
        const fromY = l.i % 2 === 0 ? -BASE : H + BASE;
        const y = fromY + (l.y - fromY) * e;
        ctx.globalAlpha = Math.min(1, p * 2.5);
        ctx.fillText(l.ch, l.x, y);
        ctx.globalAlpha = 1;
      }
    }
  };
});

rhymeOf("Compass", "Vortex", "the winds tamed into one spiral — every letter takes the same corkscrew in", function (u) {
  const { ctx, W, H, INK, BASE, layout, stage } = u;
  // dials moved: random directions → one shared spiral path · rotation added during travel
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 5.5) { age = 0; return; }
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (age - l.i * 0.05) / 1.1));
        if (p <= 0) continue;
        const e = 1 - Math.pow(1 - p, 3);
        const a = (1 - e) * Math.PI * 2.5 + l.i;           // the corkscrew
        const R = (1 - e) * Math.max(W, H) * 0.5;
        const x = l.cx + Math.cos(a) * R;
        const y = l.y + Math.sin(a) * R * 0.6;
        ctx.globalAlpha = Math.min(1, p * 2);
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate((1 - e) * 2);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
        ctx.globalAlpha = 1;
      }
    }
  };
});

rhymeOf("Tracking", "Compression", "the spacing dial pushed the other way — letters start overlapped and spread apart", function (u) {
  const { ctx, BASE, layout, stage } = u;
  // dials moved: spacing wide → negative (overlap) at the start · the fade begins brighter
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 7) age = 0;
      const p = Math.min(1, age / 2.4);
      const e = 1 - Math.pow(1 - p, 2);
      const spacing = -BASE * 0.42 * (1 - e);              // from a pile-up to clean air
      const L = layout(BASE, spacing, 300);
      ctx.fillStyle = "rgba(232,229,244," + (0.55 + 0.45 * e) + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Whoosh", "Drift in", "the same journey with the engine off — from the right, slow, no streaks", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  // dials moved: side right → left of travel flipped · speed ×0.2 · streaks removed · lean removed
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 7) age = 0;
      const p = Math.min(1, age / 2.8);
      const e = 1 - Math.pow(1 - p, 2);    // long, airless glide
      const dx = (1 - e) * W * 0.5;
      const L = layout(BASE, 0, 300);
      ctx.fillStyle = "rgba(232,229,244," + (0.2 + 0.8 * e) + ")";
      for (const l of L) ctx.fillText(l.ch, l.x + dx, l.y);
    }
  };
});

rhymeOf("Conveyor", "Return belt", "the belt reversed and impatient — right to left, with half the dwell", function (u) {
  const { ctx, W, INK, DIM, BASE, layout, stage } = u;
  // dials moved: direction flipped · dwell 3s → 1.5s · belt dots run the other way
  const PERIOD = 5.5;
  let shift = 0;
  return {
    press() { shift = 0.4; },
    frame(dt, t) {
      stage();
      shift = Math.max(0, shift - dt);
      const tt = (t * (shift > 0 ? 2.5 : 1)) % PERIOD;
      function easeOut(p) { return 1 - Math.pow(1 - p, 3); }
      function easeIn(p) { return p * p * p; }
      let dx;
      if (tt < 2) dx = -(1 - easeOut(tt / 2)) * W * 0.75;  // enter from the right… which is the left of before
      else if (tt < 3.5) dx = 0;
      else dx = easeIn((tt - 3.5) / 2) * W * 0.75;
      const L = layout();
      ctx.fillStyle = tt >= 2 && tt < 3.5 ? INK : "rgba(232,229,244,0.75)";
      for (const l of L) ctx.fillText(l.ch, l.x + dx, l.y);
      ctx.fillStyle = DIM;
      for (let x = 14 - (t * 40) % 14; x < W; x += 14)     // the dots march leftward now
        ctx.fillRect(x, u.MID + BASE * 0.45, 5, 2);
    }
  };
});

rhymeOf("Split-flap", "Broken flap", "the board settles — except one stubborn slot that flips until you press it home", function (u) {
  const { ctx, INK, BASE, GLYPHS, rand, layout, stage } = u;
  // dials moved: one slot's flip count is infinite until pressed · everyone else lands sooner
  const STUCK = 5;
  let slots = null, fixed = false;
  return {
    press() { fixed = true; },             // the technician thumps the board
    frame(dt, t) {
      stage();
      const L = layout();
      if (!slots) slots = L.map(l => ({ flips: l.i === STUCK ? Infinity : Math.floor(rand(2, 7)), phase: 0, cur: Math.floor(rand(0, GLYPHS.length)) }));
      for (const l of L) {
        if (l.ch === " ") continue;
        const s = slots[l.i];
        if (l.i === STUCK && fixed && s.flips > 3) s.flips = 3;          // the thump takes effect
        if (s.flips > 0) {
          s.phase += dt * 9;
          if (s.phase >= 1) { s.phase = 0; s.flips--; s.cur = (s.cur + 1) % GLYPHS.length; }
        }
        const showing = s.flips > 0 ? GLYPHS[s.cur] : l.ch;
        const sy = s.flips > 0 ? Math.abs(Math.cos(s.phase * Math.PI)) : 1;
        ctx.fillStyle = "rgba(35,30,58,0.9)";
        ctx.fillRect(l.x - 2, l.y - BASE * 0.8, l.w + 4, BASE * 1.05);
        ctx.strokeStyle = "rgba(150,145,190,0.3)";
        ctx.lineWidth = 1;
        ctx.strokeRect(l.x - 2, l.y - BASE * 0.8, l.w + 4, BASE * 1.05);
        ctx.beginPath();
        ctx.moveTo(l.x - 2, l.y - BASE * 0.28); ctx.lineTo(l.x + l.w + 2, l.y - BASE * 0.28);
        ctx.stroke();
        ctx.save();
        ctx.translate(l.cx, l.y - BASE * 0.28);
        ctx.scale(1, Math.max(0.06, sy));
        ctx.fillStyle = s.flips > 0 ? "rgba(232,229,244,0.85)" : INK;
        ctx.fillText(showing, -l.w / 2, BASE * 0.28);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Coin spin", "Wobbly coin", "each landing wobbles like a real dropped coin before it lies flat", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: clean settle → decaying wobble after landing · spins reduced
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (clock > L.length * 0.12 + 5) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        const a = clock - l.i * 0.12;
        if (a <= 0) continue;
        let sx;
        if (a < 0.7) {                     // the spin, as before but shorter
          const p = a / 0.7;
          sx = Math.cos((1 - Math.pow(1 - p, 2)) * 1.5 * Math.PI);
        } else {                           // the wobble: rattling toward flat
          const w = a - 0.7;
          sx = 1 - Math.abs(Math.sin(w * 14)) * Math.exp(-w * 2.2) * 0.5;
        }
        ctx.save();
        ctx.translate(l.cx, l.y);
        ctx.scale(Math.max(0.05, Math.abs(sx)), 1);
        ctx.globalAlpha = 0.4 + 0.6 * Math.abs(sx);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
        ctx.globalAlpha = 1;
      }
    }
  };
});

rhymeOf("Cartwheel", "Backflip", "from the other wing, spinning the other way, with a showy overshoot at the end", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  // dials moved: side left → right · rotation sign flipped · an overshoot roll added at arrival
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (clock > L.length * 0.08 + 4) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        const p = Math.min(1, Math.max(0, (clock - (L.length - 1 - l.i) * 0.08) / 0.8));
        if (p <= 0) continue;
        const e = 1 - Math.pow(1 - p, 3);
        const x = W + BASE - (W + BASE - l.cx) * e;
        const over = p >= 1 ? 0 : Math.sin(p * Math.PI) * 0.15;          // the flourish
        const rot = (1 - e) * Math.PI * 3 + over;
        ctx.save();
        ctx.translate(x, l.y - BASE * 0.3);
        ctx.rotate(rot);
        ctx.fillText(l.ch, -l.w / 2, BASE * 0.3);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Revolving door", "Saloon door", "the arrival swings past centre and back, losing a little each pass", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: eased landing → decaying oscillation · orbit radius halved
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const L = layout();
      if (clock > L.length * 0.07 + 5) clock = 0;
      ctx.fillStyle = INK;
      for (const l of L) {
        const a = clock - l.i * 0.07;
        if (a <= 0) continue;
        // a damped swing about the resting spot
        const swing = Math.cos(a * 7) * Math.exp(-a * 1.8);
        const x = l.cx + swing * BASE * 1.1;
        const rot = swing * 0.6;
        ctx.globalAlpha = Math.min(1, a * 3);
        ctx.save();
        ctx.translate(x, l.y);
        ctx.rotate(rot);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
        ctx.globalAlpha = 1;
      }
    }
  };
});

rhymeOf("Clock hands", "Compass rose", "they never settle upright — all the letters align to one slowly turning angle", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: target upright → a shared, slowly rotating tilt · press re-scatters
  let angles = null, blend = 0;
  return {
    press() { angles = null; blend = 0; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!angles) angles = L.map(() => rand(-Math.PI, Math.PI));
      blend = Math.min(1, blend + dt * 0.5);
      const shared = Math.sin(t * 0.5) * 0.4;              // the rose, breathing round
      const e = blend * blend * (3 - 2 * blend);
      ctx.fillStyle = INK;
      for (const l of L) {
        const a = angles[l.i] * (1 - e) + shared * e;
        ctx.save();
        ctx.translate(l.cx, l.y - BASE * 0.3);
        ctx.rotate(a);
        ctx.fillText(l.ch, -l.w / 2, BASE * 0.3);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Tumble dry", "Zero-g", "no walls, no bounces — the letters wrap around the card until gravity is switched on", function (u) {
  const { ctx, W, H, INK, BASE, rand, layout, stage } = u;
  // dials moved: wall bounce → wraparound · drift ×0.6 slower · press lands with one bounce
  let bods = null, settle = 0;
  return {
    press() { settle = 4; },
    frame(dt, t) {
      stage();
      const L = layout();
      if (!bods) bods = L.map(l => ({
        x: rand(0, W), y: rand(0, H),
        vx: rand(-18, 18), vy: rand(-18, 18), a: rand(0, u.TAU), va: rand(-2, 2), vv: 0
      }));
      settle = Math.max(0, settle - dt);
      ctx.fillStyle = INK;
      for (const l of L) {
        const b = bods[l.i];
        if (settle > 0) {                  // gravity on: fall to the baseline, one soft bounce
          b.vv += 260 * dt;
          b.y += b.vv * dt;
          if (b.y > l.y) { b.y = l.y; b.vv = -b.vv * 0.35; }
          b.x += (l.cx - b.x) * Math.min(1, dt * 4);
          b.a += (0 - b.a) * Math.min(1, dt * 4);
        } else {
          b.vv = 0;
          b.x = (b.x + b.vx * dt + W) % W; // the wrap IS the dial
          b.y = (b.y + b.vy * dt + H) % H;
          b.a += b.va * dt;
        }
        ctx.save();
        ctx.translate(b.x, b.y);
        ctx.rotate(b.a);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Orbit assembly", "Comet tail", "the same orbit, slower, with each letter trailing a tail of fading ghosts", function (u) {
  const { ctx, W, INK, BASE, MID, layout, stage, TAU } = u;
  // dials moved: orbit speed ×0.7 · a ghost trail added · landing delayed
  let clock = 0, hist = [];
  return {
    press() { clock = 0; hist = []; },
    frame(dt, t) {
      stage();
      clock += dt;
      if (clock > 10) { clock = 0; hist = []; }
      const L = layout();
      const p = Math.min(1, Math.max(0, (clock - 2) / 2.2));
      const e = p * p * (3 - 2 * p);
      const frame = [];
      for (const l of L) {
        const baseA = l.i / l.n * TAU + clock * 1.0;
        const r = BASE * 2 * (1 - e);
        const x = (W / 2) * (1 - e) + l.cx * e + Math.cos(baseA) * r;
        const y = (MID - BASE * 0.3) * (1 - e) + l.y * e + Math.sin(baseA) * r * 0.5;
        frame.push({ x: x, y: y, ch: l.ch, w: l.w });
      }
      hist.push(frame);
      if (hist.length > 10) hist.shift();
      for (let h = 0; h < hist.length - 1; h += 3) {       // the tail
        const k = h / hist.length;
        ctx.fillStyle = "rgba(170,180,255," + k * 0.18 * (1 - e) + ")";
        for (const f of hist[h]) ctx.fillText(f.ch, f.x - f.w / 2, f.y);
      }
      ctx.fillStyle = INK;
      for (const f of frame) ctx.fillText(f.ch, f.x - f.w / 2, f.y);
    }
  };
});

rhymeOf("Rainbow ride", "Grayscale ride", "the same ride with the saturation at zero — proof that hue was only one dial", function (u) {
  const { ctx, BASE, layout, stage } = u;
  // dials moved: saturation 85% → 0% (a travelling lightness wave carries the motion instead)
  let speed = 1;
  return {
    press() { speed = 3; },
    frame(dt, t) {
      stage();
      speed = Math.max(1, speed - dt);
      const L = layout(BASE, 0, 600);
      for (const l of L) {
        const lum = 35 + 55 * (0.5 + 0.5 * Math.sin((t * 60 * speed + l.i * 36) / 180 * Math.PI));
        ctx.fillStyle = "hsl(0, 0%, " + lum + "%)";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Gold sheen", "Tarnish", "the sweep inverted — a shadow crosses silver letters instead of a gleam crossing gold", function (u) {
  const { ctx, W, BASE, layout, stage } = u;
  // dials moved: metal gold → silver · the sweep darkens instead of brightening · speed ×0.7
  let sweep = -0.3;
  return {
    press() { sweep = -0.3; },
    frame(dt, t) {
      stage();
      sweep += dt * 0.38;
      if (sweep > 1.6) sweep = -0.3;
      const gx = W * sweep;
      const L = layout(BASE, 0, 700);
      for (const l of L) {
        const k = Math.exp(-Math.pow((l.cx - gx) / (BASE * 0.9), 2));    // k now dims
        const v = Math.round(205 - k * 130);
        ctx.fillStyle = "rgb(" + v + "," + v + "," + Math.round(v * 1.06) + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Fire ink", "Ember ink", "the fire banked for the night — a dim smoulder that only pops now and then", function (u) {
  const { ctx, BASE, rand, layout, stage, glow } = u;
  // dials moved: brightness ×0.4 · flicker slowed ×3 · occasional single-letter flare added
  let flare = -1, flareT = 0;
  return {
    press() { flareT = 0; flare = Math.floor(rand(0, 9)); },
    frame(dt, t) {
      stage();
      flareT += dt;
      const L = layout(BASE, 0, 600);
      if (flareT > rand(2, 4)) { flareT = 0; flare = Math.floor(rand(0, L.length)); }
      for (const l of L) {
        if (l.ch === " ") continue;
        const slow = 0.5 + 0.5 * Math.sin(t * 3 + l.i * 2.7);
        const hot = l.i === flare && flareT < 0.8 ? 1 - flareT : 0;      // the pop
        const g = ctx.createLinearGradient(0, l.y, 0, l.y - BASE * 0.85);
        g.addColorStop(0, "rgba(180,120,80," + (0.7 + hot * 0.3) + ")");
        g.addColorStop(1, "rgba(120,40,20," + (0.5 + slow * 0.2 + hot * 0.5) + ")");
        ctx.fillStyle = g;
        ctx.fillText(l.ch, l.x, l.y);
        if (hot > 0) {
          ctx.globalCompositeOperation = "lighter";
          glow(l.cx, l.y - BASE * 0.3, BASE * hot, "rgba(255,150,60," + hot * 0.4 + ")");
          ctx.globalCompositeOperation = "source-over";
        }
      }
    }
  };
});

rhymeOf("Ocean ink", "Lagoon", "the same water at half speed in pastel — nothing here is in a hurry", function (u) {
  const { ctx, BASE, layout, stage } = u;
  // dials moved: palette deepwater → pastel · speed ×0.5 · bob halved
  let stir = 0;
  return {
    press() { stir = 1.5; },
    frame(dt, t) {
      stage();
      stir = Math.max(0, stir - dt);
      const L = layout(BASE, 0, 500);
      for (const l of L) {
        const k = 0.5 + 0.5 * Math.sin(t * (0.6 + stir * 0.5) + l.i * 0.8);
        const k2 = 0.5 + 0.5 * Math.sin(t * 0.35 + l.i * 1.9 + 2);
        ctx.fillStyle = "rgb(" + Math.round(150 + k2 * 40) + "," + Math.round(210 + k * 30) + "," + Math.round(220 + k * 25) + ")";
        ctx.fillText(l.ch, l.x, l.y + Math.sin(t * 0.8 + l.i * 0.8) * BASE * 0.02);
      }
    }
  };
});

rhymeOf("Misprint", "Bad pressman", "the offsets doubled and stepped — the plates jump between misalignments", function (u) {
  const { ctx, BASE, layout, stage, TAU } = u;
  // dials moved: drift smooth → quantized jumps · offset ×2 · the press-to-align dial removed (he cannot fix it)
  let seed = 0;
  return {
    press() { seed++; },                   // he tries something; it becomes a different misalignment
    frame(dt, t) {
      stage();
      const step = Math.floor(t * 1.5) + seed;             // a new offset every 2/3 second
      const rng = (n) => (Math.sin(n * 127.1 + 311.7) * 43758.5453) % 1;
      const off = BASE * 0.13;
      const L = layout(BASE, 0, 700);
      ctx.globalCompositeOperation = "lighter";
      const plates = [
        ["rgba(80,220,255,0.85)", rng(step) * off, rng(step + 9) * off],
        ["rgba(255,80,200,0.85)", rng(step + 3) * off, rng(step + 5) * off],
        ["rgba(255,235,90,0.85)", rng(step + 7) * off, rng(step + 2) * off]
      ];
      for (const [col, dx, dy] of plates) {
        ctx.fillStyle = col;
        for (const l of L) ctx.fillText(l.ch, l.x + dx, l.y + dy);
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

rhymeOf("Highlighter", "Redactor", "the marker turned censor — a black bar sweeps in and stays until pressed away", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: colour → black, opaque · the band covers instead of underlays · press lifts it
  let sweep = 0, lifting = 0;
  return {
    press() { lifting = 0.001; },
    frame(dt, t) {
      stage();
      const L = layout();
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      if (lifting > 0) {
        lifting = Math.min(1, lifting + dt * 1.2);
        if (lifting >= 1) { lifting = 0; sweep = 0; }
      } else sweep = Math.min(1, sweep + dt * 0.9);
      const x0 = L[0].x - 4, x1 = L[L.length - 1].x + L[L.length - 1].w + 4;
      const from = lifting > 0 ? x0 + (x1 - x0) * lifting : x0;          // the lift is another sweep
      ctx.fillStyle = "rgba(12,10,22,0.96)";
      ctx.fillRect(from, L[0].y - BASE * 0.66, (x0 + (x1 - x0) * sweep) - from, BASE * 0.85);
    }
  };
});

rhymeOf("Ink bleed", "Ink dry", "run in reverse — solid letters dry out into pale, blurred stains", function (u) {
  const { ctx, BASE, rand, layout, stage } = u;
  // dials moved: direction reversed (solid → stain) · the drying is uneven per letter
  let age = 0, seeds = null;
  return {
    press() { age = 0; seeds = null; },
    frame(dt, t) {
      stage();
      age += dt;
      const L = layout(BASE, 0, 600);
      if (!seeds) seeds = L.map(() => rand(0, 1.2));
      if (age > 8) { age = 0; seeds = null; return; }
      for (const l of L) {
        const p = 1 - Math.min(1, Math.max(0, (age - seeds[l.i]) / 3.5));          // p: how much ink remains
        ctx.save();
        ctx.shadowColor = "rgba(90,110,200," + (0.5 + p * 0.5) + ")";
        ctx.shadowBlur = (1 - p) * BASE * 0.35;
        ctx.fillStyle = "rgba(120,140,230," + (0.18 + p * 0.82) + ")";
        ctx.fillText(l.ch, l.x, l.y);
        if (p > 0.6) {
          ctx.shadowBlur = 0;
          ctx.fillStyle = "rgba(200,210,255," + (p - 0.6) * 2.2 + ")";
          ctx.fillText(l.ch, l.x, l.y);
        }
        ctx.restore();
      }
    }
  };
});

rhymeOf("Mood ring", "Alarm", "two moods only — long calm, sudden ALERT, no blending between them", function (u) {
  const { ctx, BASE, layout, stage, TAU } = u;
  // dials moved: moods 4 → 2 · crossfade → hard snap · alert adds a flash border
  let alert = false, timer = 0;
  return {
    press() { alert = !alert; timer = 0; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (timer > (alert ? 2 : 6)) { timer = 0; alert = !alert; }        // alarms are brief; calm is long
      const L = layout(BASE, 0, alert ? 700 : 400);
      if (alert) {
        ctx.fillStyle = Math.sin(t * 12) > 0 ? "rgb(255,120,100)" : "rgb(255,170,150)";
        for (const l of L) ctx.fillText(l.ch, l.x, l.y + Math.sin(t * 24 + l.i) * 1.2);
        ctx.strokeStyle = "rgba(255,120,100," + (0.4 + 0.3 * Math.sin(t * 12)) + ")";
        ctx.lineWidth = 2;
        ctx.strokeRect(3, 3, u.W - 6, u.H - 6);
      } else {
        ctx.fillStyle = "rgb(150,200,255)";
        for (const l of L) ctx.fillText(l.ch, l.x, l.y + Math.sin(t * 0.8 + l.i * 0.5) * BASE * 0.02);
      }
    }
  };
});

rhymeOf("Cold shiver", "Swelter", "randomness swapped for heat haze — a smooth, sinuous wobble rising off the words", function (u) {
  const { ctx, BASE, layout, stage } = u;
  // dials moved: random jitter → smooth stacked sines · axis mostly vertical · warm tint
  let heat = 1;
  return {
    press() { heat = 2.2; },
    frame(dt, t) {
      stage();
      heat = Math.max(1, heat - dt * 0.5);
      const L = layout();
      ctx.fillStyle = "#F2E2CE";
      for (const l of L) {
        const y = (Math.sin(t * 4 + l.i * 1.8) + Math.sin(t * 6.7 + l.i * 0.7) * 0.5) * heat;
        const sx = 1 + Math.sin(t * 5 + l.i * 2.3) * 0.03 * heat;        // the shimmer stretch
        ctx.save();
        ctx.translate(l.cx, l.y + y);
        ctx.scale(sx, 1);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Earthquake", "Aftershocks", "one press buys three quakes — each smaller, each a little later", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: one shock → a scheduled series of three · magnitude decays per shock
  let shocks = [];
  return {
    press() { shocks = [{ at: 0, mag: 1 }, { at: 1.4, mag: 0.55 }, { at: 2.6, mag: 0.3 }].map(s => ({ ...s, age: 0 })); },
    frame(dt, t) {
      stage();
      let trauma = 0;
      for (const s of shocks) {
        s.age += dt;
        const local = s.age - s.at;
        if (local > 0) trauma = Math.max(trauma, Math.max(0, s.mag - local * 0.7));
      }
      shocks = shocks.filter(s => s.age < s.at + 2);
      const sh = trauma * trauma;
      const dx = rand(-1, 1) * sh * BASE * 0.5, dy = rand(-1, 1) * sh * BASE * 0.3;
      ctx.save();
      ctx.translate(u.W / 2 + dx, u.MID + dy);
      ctx.rotate(rand(-1, 1) * sh * 0.06);
      ctx.translate(-u.W / 2, -u.MID);
      const L = layout(BASE, 0, sh > 0.3 ? 700 : 400);
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      ctx.restore();
    }
  };
});

rhymeOf("RGB split", "CMY split", "printers' inks instead of screen light — and the tear runs vertically", function (u) {
  const { ctx, BASE, rand, layout, stage } = u;
  // dials moved: palette RGB → CMY over multiply-ish alpha · tear axis horizontal → vertical
  let burst = 0, next = 1.5;
  return {
    press() { burst = 1; },
    frame(dt, t) {
      stage();
      next -= dt;
      if (next <= 0) { burst = Math.max(burst, rand(0.2, 0.5)); next = rand(0.8, 2.4); }
      burst = Math.max(0, burst - dt * 2);
      const off = burst * BASE * 0.25;
      const L = layout(BASE, 0, 600);
      ctx.globalCompositeOperation = "lighter";
      ctx.fillStyle = "rgba(90,230,230,0.8)";              // cyan
      for (const l of L) ctx.fillText(l.ch, l.x + off * 0.2, l.y - off);
      ctx.fillStyle = "rgba(230,90,230,0.8)";              // magenta
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      ctx.fillStyle = "rgba(235,235,100,0.8)";             // yellow
      for (const l of L) ctx.fillText(l.ch, l.x - off * 0.2, l.y + off);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

rhymeOf("Scanline slice", "Venetian", "continuous and orderly — thin bands shear alternately left and right, like blinds", function (u) {
  const { ctx, INK, BASE, MID, layout, stage } = u;
  // dials moved: random trigger → continuous · displacement alternates by band parity · amplitude gentled
  let tilt = 0;
  return {
    press() { tilt = 1; },
    frame(dt, t) {
      stage();
      tilt = Math.max(0, tilt - dt * 0.8);
      const L = layout(BASE, 0, 600);
      const bands = 6;
      const top = MID - BASE * 0.85, hgt = BASE * 1.2;
      for (let i = 0; i < bands; i++) {    // draw the phrase once per band, clipped, sheared
        const sy = top + (i / bands) * hgt, sh = hgt / bands;
        const dx = Math.sin(t * 1.8) * (3 + tilt * 8) * (i % 2 ? 1 : -1);
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, sy, u.W, sh + 0.5);
        ctx.clip();
        ctx.fillStyle = INK;
        for (const l of L) ctx.fillText(l.ch, l.x + dx, l.y);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Corruption", "Censorship", "the noise organized — blocks sweep across word by word, then release", function (u) {
  const { ctx, INK, BASE, PHRASE, layout, stage } = u;
  // dials moved: random per-letter → an orderly sweep by word · blocks solid, not flickering
  const starts = [0];
  for (let i = 0; i < PHRASE.length; i++) if (PHRASE[i] === " ") starts.push(i + 1);
  function wordOf(i) { let w = 0; for (let s = 1; s < starts.length; s++) if (i >= starts[s]) w = s; return w; }
  let clock = 0;
  return {
    press() { clock = 0; },
    frame(dt, t) {
      stage();
      clock += dt;
      const period = (starts.length + 2) * 1.1;
      if (clock > period) clock = 0;
      const censored = Math.floor(clock / 1.1) - 1;        // which word is currently blocked (−1 = none yet)
      const L = layout();
      for (const l of L) {
        if (l.ch === " ") continue;
        if (wordOf(l.i) === censored) {
          ctx.fillStyle = "rgba(40,36,66,0.95)";
          ctx.fillRect(l.x - 1, l.y - BASE * 0.68, l.w + 2, BASE * 0.78);
        } else {
          ctx.fillStyle = INK;
          ctx.fillText(l.ch, l.x, l.y);
        }
      }
    }
  };
});

rhymeOf("Nervous", "Drunk", "the fidget slowed and widened — big slow sways, letters leaning on their neighbours", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: speed ×0.3 · amplitude ×4 · neighbour coupling added (each letter follows the one before)
  let sober = 0;
  return {
    press() { sober = 3; },                // a coffee
    frame(dt, t) {
      stage();
      sober = Math.max(0, sober - dt);
      const k = sober > 0 ? 0.15 : 1;
      const L = layout();
      ctx.fillStyle = INK;
      let lean = 0;
      for (const l of L) {
        lean = lean * 0.6 + Math.sin(t * 0.9 + l.i * 1.9) * 0.4;         // it leans where its neighbour leant
        const nx = Math.sin(t * 1.1 + l.i * 2.1) * 3 * k;
        const ny = Math.sin(t * 0.8 + l.i * 1.3) * 2.4 * k;
        ctx.save();
        ctx.translate(l.cx + nx, l.y + ny);
        ctx.rotate(lean * 0.18 * k);
        ctx.fillText(l.ch, -l.w / 2, 0);
        ctx.restore();
      }
    }
  };
});

rhymeOf("Sync loss", "Interlace", "the roll traded for a comb — odd and even letters split apart and zip together", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: vertical roll → static comb offset · press zips instead of rolling
  let split = 1, k = 1;
  return {
    press() { split = split > 0.5 ? 0 : 1; },              // zip / unzip
    frame(dt, t) {
      stage();
      // ease toward the current state — the zip is the animation
      k += (split - k) * Math.min(1, dt * 4);
      const L = layout(BASE, 0, 500);
      ctx.fillStyle = INK;
      for (const l of L) {
        const dy = (l.i % 2 ? 1 : -1) * k * BASE * 0.22;
        ctx.fillText(l.ch, l.x, l.y + dy);
      }
      if (k > 0.1) {                       // the faint scanline hint while split
        ctx.fillStyle = "rgba(150,145,190," + k * 0.12 + ")";
        for (let y = 0; y < u.H; y += 4) ctx.fillRect(0, y, u.W, 1);
      }
    }
  };
});

rhymeOf("Pen stroke", "Eraser", "written in full, then erased letter by letter from the right — and rewritten", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: direction reversed (it consumes) · order right-to-left · the fill goes first
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 8) age = 0;
      const L = layout(BASE, 0, 500);
      const per = BASE * 7;
      for (const l of L) {
        const ri = L.length - 1 - l.i;     // erase from the right
        const p = Math.min(1, Math.max(0, (age - 1.5 - ri * 0.22) / 1.2));         // p: how erased
        if (p >= 1) continue;
        if (p <= 0) {
          ctx.fillStyle = "rgba(232,229,244,0.9)";
          ctx.fillText(l.ch, l.x, l.y);
        } else {                           // partially erased: the outline retreats
          ctx.strokeStyle = "rgba(232,229,244," + (0.9 - p * 0.6) + ")";
          ctx.lineWidth = 1.4;
          ctx.setLineDash([per * (1 - p), per * 4]);
          ctx.strokeText(l.ch, l.x, l.y);
          ctx.setLineDash([]);
        }
      }
    }
  };
});

rhymeOf("Hollow to solid", "Drain", "the glass empties — filled letters drain from the top, leaving outlines", function (u) {
  const { ctx, W, INK, BASE, layout, stage } = u;
  // dials moved: fill direction reversed (full → empty) · the meniscus falls
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 7) age = 0;
      const L = layout(BASE, 0, 600);
      ctx.strokeStyle = "rgba(232,229,244,0.8)";
      ctx.lineWidth = 1.2;
      for (const l of L) ctx.strokeText(l.ch, l.x, l.y);
      const fill = 1 - Math.min(1, Math.max(0, (age - 0.8) / 2.2));      // the only changed line
      if (fill > 0) {
        ctx.save();
        ctx.beginPath();
        const level = u.MID + BASE * 0.14 - fill * BASE * 0.95;
        ctx.rect(0, level, W, u.H - level);
        ctx.clip();
        ctx.fillStyle = INK;
        for (const l of L) ctx.fillText(l.ch, l.x, l.y);
        ctx.restore();
        if (fill < 1) {
          ctx.fillStyle = "rgba(180,200,255,0.5)";
          ctx.fillRect(L[0].x, level - 1, L[L.length - 1].x + L[L.length - 1].w - L[0].x, 1.5);
        }
      }
    }
  };
});

rhymeOf("Marching ants", "Queen ant", "the column thins to a single bright runner orbiting each letter", function (u) {
  const { ctx, BASE, layout, stage } = u;
  // dials moved: dash pattern 4/4 → one long runner with a huge gap · speed ×0.6 · a soft fill restored
  let speed = 1;
  return {
    press() { speed = 4; },
    frame(dt, t) {
      stage();
      speed = Math.max(1, speed - dt * 1.5);
      const L = layout(BASE, 0, 600);
      ctx.fillStyle = "rgba(232,229,244,0.25)";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      ctx.strokeStyle = "rgba(255,230,150,0.95)";
      ctx.lineWidth = 1.6;
      ctx.setLineDash([BASE * 0.5, BASE * 6]);             // one runner, one long silence
      ctx.lineDashOffset = -t * 12 * speed;
      for (const l of L) ctx.strokeText(l.ch, l.x, l.y);
      ctx.setLineDash([]);
    }
  };
});

rhymeOf("Underline writer", "Brackets", "two lines draw from the outside in, and the letters appear between them", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: one line → two (above and below) · direction both-ends-inward · letters reveal outside-in
  let age = 0;
  return {
    press() { age = 0; },
    frame(dt, t) {
      stage();
      age += dt;
      if (age > 6.5) age = 0;
      const L = layout();
      const x0 = L[0].x, x1 = L[L.length - 1].x + L[L.length - 1].w;
      const mid = (x0 + x1) / 2;
      const p = Math.min(1, age / 1.2);
      const e = 1 - Math.pow(1 - p, 3);
      const reach = (x1 - x0) / 2 * e;
      ctx.strokeStyle = "rgba(180,200,255,0.9)";
      ctx.lineWidth = 2;
      ctx.beginPath();                     // over-line from the left, underline from the right
      ctx.moveTo(x0, L[0].y - BASE * 0.85); ctx.lineTo(x0 + reach * 2, L[0].y - BASE * 0.85);
      ctx.moveTo(x1, L[0].y + 6); ctx.lineTo(x1 - reach * 2, L[0].y + 6);
      ctx.stroke();
      for (const l of L) {                 // outermost letters first
        const fromEdge = Math.min(l.cx - x0, x1 - l.cx) / (x1 - x0) * 2; // 0 at the ends, 1 in the middle
        const k = Math.min(1, Math.max(0, (e - fromEdge) * 3 + 0.2));
        ctx.fillStyle = "rgba(232,229,244," + k + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Double stroke", "Triple echo", "three outlines expanding outward in staggered phase, like rings from a bell", function (u) {
  const { ctx, BASE, layout, stage, TAU } = u;
  // dials moved: strokes 2 → 3 · counter-phase breathing → outward travel · press strikes the bell
  let strike = 0;
  return {
    press() { strike = 1; },
    frame(dt, t) {
      stage();
      strike = Math.max(0, strike - dt * 0.8);
      const L = layout(BASE, 0, 700);
      ctx.lineJoin = "round";
      for (let e = 2; e >= 0; e--) {       // outermost first
        const ph = ((t * 0.8 + e / 3) % 1);                // each echo a third of a cycle apart
        const w = 1 + ph * (5 + strike * 6);
        const a = (1 - ph) * (0.35 + strike * 0.3);
        ctx.strokeStyle = "rgba(160,190,255," + a + ")";
        ctx.lineWidth = w;
        for (const l of L) ctx.strokeText(l.ch, l.x, l.y);
      }
      ctx.fillStyle = "rgba(232,229,244,0.95)";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Strike & fix", "Proud correction", "the line goes UNDER, and the phrase straightens up instead of slumping", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: line position strike → underline · letters lift (+approve) instead of slump · palette warm
  let phase = 0;
  return {
    press() { phase = 0; },
    frame(dt, t) {
      stage();
      phase += dt * 0.8;
      if (phase > 4.2) phase = 0;
      const L = layout();
      const x0 = L[0].x - 3, x1 = L[L.length - 1].x + L[L.length - 1].w + 3;
      let line = 0;
      if (phase < 1) line = 1 - Math.pow(1 - phase, 3);
      else if (phase < 3) line = 1;
      else line = Math.max(0, 1 - (phase - 3));
      for (const l of L) {
        const blessed = l.cx < x0 + (x1 - x0) * line;
        ctx.fillStyle = blessed ? "#F4E9C8" : INK;
        ctx.font = u.font(blessed ? 600 : 400, BASE);
        ctx.fillText(l.ch, l.x, l.y - (blessed ? 1.5 : 0));              // it stands taller when approved
      }
      if (line > 0) {
        ctx.strokeStyle = "rgba(240,210,130,0.9)";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(x0, L[0].y + 6);
        ctx.lineTo(x0 + (x1 - x0) * line, L[0].y + 6);
        ctx.stroke();
      }
    }
  };
});

rhymeOf("Chalk dust", "Wet paint", "the dust becomes drips — paint runs down from the letters in slow threads", function (u) {
  const { ctx, BASE, rand, layout, stage } = u;
  // dials moved: particles rise/drift → drip straight down · grain removed (wet paint is smooth) · palette
  let drips = [];
  return {
    press() {                              // a fresh coat: more drips
      const L = layout();
      for (let i = 0; i < 8; i++) {
        const l = L[Math.floor(rand(0, L.length))];
        if (l.ch !== " ") drips.push({ x: l.cx + rand(-l.w * 0.3, l.w * 0.3), y: l.y + 2, v: rand(4, 14), len: 0, life: 1 });
      }
    },
    frame(dt, t) {
      stage();
      const L = layout(BASE, 0, 600);
      ctx.fillStyle = "#9FD8C8";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      if (Math.random() < 0.06) {
        const l = L[Math.floor(rand(0, L.length))];
        if (l.ch !== " ") drips.push({ x: l.cx + rand(-l.w * 0.3, l.w * 0.3), y: l.y + 1, v: rand(3, 9), len: 0, life: 1 });
      }
      ctx.strokeStyle = "rgba(159,216,200,0.7)";
      ctx.lineWidth = 2;
      for (const d of drips) {
        d.len += d.v * dt;
        d.v *= Math.pow(0.7, dt);          // drips slow as they thin
        d.life -= dt * 0.2;
        ctx.beginPath();
        ctx.moveTo(d.x, d.y);
        ctx.lineTo(d.x, d.y + d.len);
        ctx.stroke();
        ctx.fillStyle = "rgba(159,216,200,0.8)";
        ctx.fillRect(d.x - 1.2, d.y + d.len, 2.4, 2.4);    // the bead at the tip
      }
      drips = drips.filter(d => d.life > 0 && d.y + d.len < u.H);
    }
  };
});

rhymeOf("Star assembly", "Star scatter", "the cycle reversed — the phrase stands, sheds its letters as motes, and regathers", function (u) {
  const { ctx, W, H, INK, BASE, rand, layout, stage, glow } = u;
  // dials moved: converge → shed (targets swapped with sources) · the phrase dims as it sheds
  let motes = [], solidity = 1, phase = 0;
  return {
    press() { phase = 3; },                // shed early
    frame(dt, t) {
      stage();
      phase += dt;
      if (phase > 9) phase = 0;
      const shedding = phase > 3 && phase < 6;
      const L = layout();
      if (shedding) {
        solidity = Math.max(0, solidity - dt * 0.5);
        if (Math.random() < 0.7) {
          const l = L[Math.floor(rand(0, L.length))];
          if (l.ch !== " ") motes.push({ x: l.cx, y: l.y - BASE * 0.3,
            tx: rand(0, 1) < 0.5 ? rand(-20, 0) : rand(W, W + 20), ty: rand(0, H), life: 1 });
        }
      } else solidity = Math.min(1, solidity + dt * 0.6);
      ctx.globalCompositeOperation = "lighter";
      for (const m of motes) {
        m.x += (m.tx - m.x) * Math.min(1, dt * 1.2);
        m.y += (m.ty - m.y) * Math.min(1, dt * 1.2);
        m.life -= dt * 0.5;
        if (m.life > 0) glow(m.x, m.y, 2.5, "rgba(220,220,255," + m.life * 0.8 + ")");
      }
      motes = motes.filter(m => m.life > 0);
      ctx.globalCompositeOperation = "source-over";
      ctx.fillStyle = "rgba(232,229,244," + solidity + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Dust burst", "Bubble burst", "gravity flipped — the letters burst into bubbles that rise and pop", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: dust grains → bubbles (outlined circles) · gravity flipped · pops at the top
  let bubbles = [], gone = 0;
  return {
    press() {
      const L = layout();
      bubbles = [];
      for (const l of L) {
        if (l.ch === " ") continue;
        for (let i = 0; i < 4; i++)
          bubbles.push({ x: l.cx + rand(-l.w, l.w) * 0.4, y: l.y - rand(0, BASE * 0.6),
                         vx: rand(-15, 15), vy: rand(-40, -15), r: rand(2, 5), life: rand(0.8, 1.6) });
      }
      gone = 2.2;
    },
    frame(dt, t) {
      stage();
      const L = layout();
      if (gone > 0) {
        gone -= dt;
        ctx.strokeStyle = "rgba(180,220,255,0.8)";
        ctx.lineWidth = 1;
        for (const b of bubbles) {
          b.x += b.vx * dt + Math.sin(b.y * 0.1) * 6 * dt;
          b.y += b.vy * dt;
          b.life -= dt;
          if (b.life > 0) {
            ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, u.TAU); ctx.stroke();
          } else if (b.life > -0.15) {     // the pop: a brief star
            ctx.beginPath();
            ctx.moveTo(b.x - b.r, b.y); ctx.lineTo(b.x + b.r, b.y);
            ctx.moveTo(b.x, b.y - b.r); ctx.lineTo(b.x, b.y + b.r);
            ctx.stroke();
          }
        }
        bubbles = bubbles.filter(b => b.life > -0.15);
        const k = Math.max(0, 1 - gone * 1.4);             // the phrase seeps back
        ctx.fillStyle = "rgba(232,229,244," + Math.min(1, Math.max(0, k)) + ")";
        for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      } else {
        ctx.fillStyle = INK;
        for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Sparkle crown", "Frost sparkle", "cold twinkles at half the rate — and the letters blush blue where they land", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: palette warm → ice · rate ×0.5 · a per-letter chill tint that fades
  let sparks = [], chill = null, shower = 0;
  return {
    press() { shower = 1; },
    frame(dt, t) {
      stage();
      shower = Math.max(0, shower - dt);
      const L = layout();
      if (!chill) chill = L.map(() => 0);
      if (Math.random() < 0.08 + shower * 0.5) {
        const i = Math.floor(rand(0, L.length));
        const l = L[i];
        sparks.push({ x: l.cx + rand(-l.w * 0.5, l.w * 0.5), y: l.y - rand(BASE * 0.2, BASE * 0.95), life: 1, s: rand(2, 4.5) });
        chill[i] = 1;
      }
      for (const l of L) {
        chill[l.i] = Math.max(0, chill[l.i] - dt * 0.5);
        const c = chill[l.i];
        ctx.fillStyle = "rgb(" + Math.round(232 - c * 60) + "," + Math.round(229 - c * 20) + ",255)";
        ctx.fillText(l.ch, l.x, l.y);
      }
      ctx.strokeStyle = "rgba(200,230,255,0.9)";
      ctx.lineWidth = 1;
      for (const s of sparks) {
        s.life -= dt * 1.1;
        if (s.life > 0) {
          const size = s.s * Math.sin(s.life * Math.PI);
          ctx.beginPath();
          ctx.moveTo(s.x - size, s.y); ctx.lineTo(s.x + size, s.y);
          ctx.moveTo(s.x, s.y - size); ctx.lineTo(s.x, s.y + size);
          ctx.moveTo(s.x - size * 0.6, s.y - size * 0.6); ctx.lineTo(s.x + size * 0.6, s.y + size * 0.6);   // frost gets diagonals
          ctx.moveTo(s.x - size * 0.6, s.y + size * 0.6); ctx.lineTo(s.x + size * 0.6, s.y - size * 0.6);
          ctx.stroke();
        }
      }
      sparks = sparks.filter(s => s.life > 0);
    }
  };
});

rhymeOf("Electron letters", "Moth lamp", "the orbits abandoned — the motes crowd toward one drifting lamp instead", function (u) {
  const { ctx, INK, BASE, rand, layout, stage, glow } = u;
  // dials moved: per-letter orbits → shared attraction point · letters brighten near the lamp
  let moths = null;
  return {
    press() { moths = null; },             // startle them into new positions
    frame(dt, t) {
      stage();
      const L = layout();
      if (!moths) moths = L.map(() => ({ x: rand(0, u.W), y: rand(0, u.H), vx: 0, vy: 0 }));
      const lampX = u.W / 2 + Math.sin(t * 0.5) * u.W * 0.3;             // the lamp strolls
      const lampY = u.MID - BASE * 1.1 + Math.sin(t * 0.9) * BASE * 0.4;
      for (const l of L) {
        const k = Math.max(0, 1 - Math.abs(l.cx - lampX) / (BASE * 2.5));
        ctx.fillStyle = "rgba(232,229,244," + (0.35 + k * 0.65) + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
      ctx.globalCompositeOperation = "lighter";
      glow(lampX, lampY, BASE * 0.9, "rgba(255,230,160,0.35)");
      for (const m of moths) {             // clumsy attraction, moth-style
        m.vx += (lampX - m.x) * 2.2 * dt + rand(-1, 1) * 30 * dt;
        m.vy += (lampY - m.y) * 2.2 * dt + rand(-1, 1) * 30 * dt;
        m.vx *= Math.pow(0.5, dt); m.vy *= Math.pow(0.5, dt);
        m.x += m.vx * dt; m.y += m.vy * dt;
        glow(m.x, m.y, 2, "rgba(255,235,180,0.7)");
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

rhymeOf("Snow fill", "Sandstorm", "the snow turned sideways and hostile — grit streams past and scours the letters pale", function (u) {
  const { ctx, W, DIM, BASE, rand, layout, stage } = u;
  // dials moved: fall vertical → horizontal stream · fill-up → scour (brightness worn away per letter)
  let grains = [], worn = null;
  return {
    press() { worn = null; },              // the wind drops for a moment; the letters recover
    frame(dt, t) {
      stage();
      const L = layout(BASE, 0, 600);
      if (!worn) worn = L.map(() => 0);
      if (grains.length < 40)
        grains.push({ x: -4, y: rand(0, u.H), v: rand(120, 240), life: 1 });
      ctx.fillStyle = "rgba(225,200,150,0.7)";
      for (const g of grains) {
        g.x += g.v * dt; g.y += Math.sin(g.x * 0.05) * 10 * dt;
        ctx.fillRect(g.x, g.y, 2.2, 1.2);
        for (const l of L)                 // grit wears the letters as it passes
          if (Math.abs(g.y - (l.y - BASE * 0.3)) < BASE * 0.5 && Math.abs(g.x - l.cx) < l.w)
            worn[l.i] = Math.min(1, worn[l.i] + dt * 2);
      }
      grains = grains.filter(g => g.x < W + 6);
      for (const l of L) {
        worn[l.i] = Math.max(0, worn[l.i] - dt * 0.1);
        const wgt = worn[l.i];
        ctx.fillStyle = "rgba(" + Math.round(232 - wgt * 30) + "," + Math.round(229 - wgt * 45) + "," + Math.round(244 - wgt * 90) + "," + (1 - wgt * 0.55) + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Ember decay", "Ash rain", "the burn eats downward instead, and ash falls where embers rose", function (u) {
  const { ctx, INK, BASE, rand, layout, stage } = u;
  // dials moved: burn direction bottom-up → top-down · particles rise → fall · palette ember → ash
  let ash = [];
  return {
    press() {},
    frame(dt, t) {
      stage();
      const L = layout();
      const cycle = (t % 7) / 7;
      const burn = cycle < 0.5 ? cycle * 2 : (1 - cycle) * 2;
      for (const l of L) {
        if (l.ch === " ") continue;
        const burnLine = l.y - BASE * 0.75 + BASE * 0.85 * burn;         // the line DESCENDS
        ctx.save();
        ctx.beginPath();
        ctx.rect(l.x - 1, burnLine, l.w + 2, BASE);        // below the line survives
        ctx.clip();
        ctx.fillStyle = INK;
        ctx.fillText(l.ch, l.x, l.y);
        ctx.restore();
        if (burn > 0.02 && burn < 0.98 && Math.random() < 0.25)
          ash.push({ x: l.cx + rand(-l.w * 0.4, l.w * 0.4), y: burnLine, vy: rand(10, 26), life: 1 });
      }
      ctx.fillStyle = "rgba(170,165,160,0.6)";
      for (const a of ash) {
        a.y += a.vy * dt; a.x += Math.sin(a.y * 0.15 + a.x) * 6 * dt; a.life -= dt * 0.8;
        if (a.life > 0) ctx.fillRect(a.x, a.y, 1.8, 1.8);
      }
      ash = ash.filter(a => a.life > 0 && a.y < u.H);
    }
  };
});

rhymeOf("Rain reveal", "Sun shower", "gold light instead of rain — and what it reveals takes much longer to fade", function (u) {
  const { ctx, W, H, DIM, BASE, rand, layout, stage } = u;
  // dials moved: palette rain → sunlight · fall speed ×0.5 · dry-out ×5 slower
  let rays = [], pour = 0, lit = null;
  return {
    press() { pour = 1.6; },
    frame(dt, t) {
      stage();
      pour = Math.max(0, pour - dt);
      const L = layout();
      if (!lit) lit = L.map(() => 0);
      if (Math.random() < 0.25 + pour * 1.2)
        rays.push({ x: rand(0, W), y: -10, v: rand(80, 130) });
      ctx.strokeStyle = "rgba(255,220,130,0.45)";
      ctx.lineWidth = 1.4;
      for (const r of rays) {
        r.y += r.v * dt;
        ctx.beginPath(); ctx.moveTo(r.x, r.y - 14); ctx.lineTo(r.x, r.y); ctx.stroke();
        for (const l of L)
          if (Math.abs(r.x - l.cx) < l.w * 0.7 && r.y > l.y - BASE && r.y < l.y + 4)
            lit[l.i] = Math.min(1, lit[l.i] + dt * 8);
      }
      rays = rays.filter(r => r.y < H + 12);
      for (const l of L) {
        lit[l.i] = Math.max(0, lit[l.i] - dt * 0.05);      // sunlight lingers
        ctx.fillStyle = lit[l.i] > 0.02 ? "rgba(255,240,200," + (0.15 + lit[l.i] * 0.85) + ")" : DIM;
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Confetti pop", "Streamers", "ribbons instead of flecks — fewer, longer, floatier, twice the hang-time", function (u) {
  const { ctx, W, INK, BASE, rand, layout, stage, TAU } = u;
  // dials moved: flecks → ribbon segments with a waving tail · count ÷2 · gravity ÷3
  let ribbons = [], hop = 0;
  const COLS = ["#FF8FA3", "#FFD166", "#8FE3B0", "#8FB7FF", "#E3A8FF"];
  return {
    press() {
      hop = 1;
      for (let i = 0; i < 10; i++)
        ribbons.push({ x: W / 2 + rand(-BASE, BASE), y: u.MID, vx: rand(-50, 50), vy: rand(-110, -50),
                       ph: rand(0, TAU), col: COLS[Math.floor(rand(0, COLS.length))], life: 2 });
    },
    frame(dt, t) {
      stage();
      hop = Math.max(0, hop - dt * 1.4);
      for (const r of ribbons) {
        r.x += r.vx * dt; r.y += r.vy * dt; r.vy += 50 * dt; r.ph += dt * 9; r.life -= dt * 0.5;
        r.vx *= Math.pow(0.6, dt);
        if (r.life > 0) {
          ctx.strokeStyle = r.col;
          ctx.globalAlpha = Math.min(1, r.life);
          ctx.lineWidth = 2.5;
          ctx.beginPath();                 // the tail waves behind the head
          ctx.moveTo(r.x, r.y);
          for (let s = 1; s <= 4; s++)
            ctx.lineTo(r.x - r.vx * 0.02 * s + Math.sin(r.ph + s) * 3, r.y - r.vy * 0.02 * s - s * 3);
          ctx.stroke();
          ctx.globalAlpha = 1;
        }
      }
      ribbons = ribbons.filter(r => r.life > 0 && r.y < u.H + 20);
      const jump = Math.sin(Math.min(1, 1 - hop) * Math.PI) * hop * BASE * 0.3;
      const L = layout(BASE, 0, hop > 0 ? 700 : 400);
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y - jump * Math.sin(l.i / (l.n - 1) * Math.PI));
    }
  };
});

rhymeOf("Long shadow", "Moon shadow", "the same sky at night — a cool moon, a slower arc, and longer shadows", function (u) {
  const { ctx, W, INK, BASE, MID, layout, stage, glow } = u;
  // dials moved: palette sun → moon · arc speed ×0.4 · shadow length ×1.5
  let hurry = 0;
  return {
    press() { hurry = 2; },
    frame(dt, t) {
      stage();
      hurry = Math.max(0, hurry - dt);
      const night = t * (0.06 + hurry * 0.2);
      const moonA = (night % 1) * Math.PI;
      const mx = W / 2 - Math.cos(moonA) * W * 0.45, my = MID - BASE * 2.2 - Math.sin(moonA) * BASE;
      ctx.globalCompositeOperation = "lighter";
      glow(mx, my, BASE * 0.7, "rgba(200,215,255,0.45)");
      ctx.globalCompositeOperation = "source-over";
      const L = layout(BASE, 0, 700);
      const dirX = Math.cos(moonA);
      const len = BASE * (0.6 + Math.abs(Math.cos(moonA)) * 2.1);
      const steps = 9;
      for (let s = steps; s > 0; s--) {
        const k = s / steps;
        ctx.fillStyle = "rgba(4,6,20," + (0.4 * (1 - k) + 0.1) + ")";
        for (const l of L) ctx.fillText(l.ch, l.x + dirX * len * k, l.y + len * k * 0.35);
      }
      ctx.fillStyle = "#C9D4F2";           // moonlit ink
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Stack extrude", "Staircase", "the smooth extrusion quantized — chunky steps down and to the right, twice as deep", function (u) {
  const { ctx, INK, BASE, layout, stage, TAU } = u;
  // dials moved: offset per copy 0.8px → 3px hard steps · depth ×2 · the breath removed (stairs hold still)
  let slam = 0;
  return {
    press() { slam = 1; },
    frame(dt, t) {
      stage();
      slam = Math.max(0, slam - dt * 1.2);
      const depth = Math.round(8 + slam * 6);
      const L = layout(BASE, 0, 700);
      for (let d = depth; d > 0; d--) {
        const k = d / depth;
        const v = Math.round(30 + (1 - k) * 50);
        ctx.fillStyle = "rgb(" + v + "," + Math.round(v * 0.9) + "," + Math.round(v * 1.5) + ")";
        for (const l of L) ctx.fillText(l.ch, l.x + d * 3, l.y + d * 3);
      }
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

rhymeOf("Echo trail", "Premonition", "the memory runs the wrong way — the ghosts arrive BEFORE the phrase does", function (u) {
  const { ctx, INK, BASE, layout, stage } = u;
  // dials moved: history → future (the drift is predictable, so the ghosts lead) · tint warmed
  return {
    press() {},
    frame(dt, t) {
      stage();
      const L = layout();
      function driftAt(tt) {
        return { dx: Math.sin(tt * 0.9) * BASE * 0.8, dy: Math.sin(tt * 1.7) * BASE * 0.22 };
      }
      for (let f = 4; f >= 1; f--) {       // where it WILL be, faint and expectant
        const d = driftAt(t + f * 0.12);
        ctx.fillStyle = "rgba(255,200,150," + (0.16 - f * 0.03) + ")";
        for (const l of L) ctx.fillText(l.ch, l.x + d.dx, l.y + d.dy);
      }
      const now = driftAt(t);
      ctx.fillStyle = INK;
      for (const l of L) ctx.fillText(l.ch, l.x + now.dx, l.y + now.dy);
    }
  };
});

rhymeOf("Spotlight", "Searchlights", "two beams instead of one — a letter needs BOTH to be truly seen", function (u) {
  const { ctx, W, H, BASE, MID, layout, stage, glow } = u;
  // dials moved: lights 1 → 2, crossing paths · full brightness needs the overlap · press summons both
  let called = 0, cx1 = 0, cx2 = 0, tx = 0;
  return {
    press(x) { tx = x === undefined ? W / 2 : x; called = 2; },
    frame(dt, t) {
      stage();
      called = Math.max(0, called - dt);
      const a1 = called > 0 ? tx : W / 2 + Math.sin(t * 0.7) * W * 0.34;
      const a2 = called > 0 ? tx : W / 2 + Math.sin(t * 0.47 + 2.1) * W * 0.34;
      cx1 += (a1 - cx1) * Math.min(1, dt * 3);
      cx2 += (a2 - cx2) * Math.min(1, dt * 3);
      const R = BASE * 2.1, cy = MID - BASE * 0.3;
      const L = layout();
      for (const l of L) {
        const k1 = Math.max(0, 1 - Math.abs(l.cx - cx1) / R);
        const k2 = Math.max(0, 1 - Math.abs(l.cx - cx2) / R);
        const k = Math.max(k1, k2) * 0.35 + Math.min(k1, k2) * 0.65;     // the overlap is what counts
        if (k <= 0.01) continue;
        ctx.fillStyle = "rgba(255,250,230," + Math.min(1, k * 1.8) + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
      ctx.globalCompositeOperation = "lighter";
      glow(cx1, cy, R, "rgba(200,230,255,0.10)");
      glow(cx2, cy, R, "rgba(255,235,200,0.10)");
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

rhymeOf("Emboss", "Deep engrave", "cut twice as deep, the face darker — and the press planes it flush instead of raising it", function (u) {
  const { ctx, BASE, layout, stage } = u;
  // dials moved: depth ×2 · face darkened · press → flat (no relief at all), not raised
  let flat = 0;
  return {
    press() { flat = 2.5; },
    frame(dt, t) {
      stage();
      flat = Math.max(0, flat - dt);
      const d = flat > 0 ? 0 : 2.8;
      const L = layout(BASE, 0, 700);
      ctx.fillStyle = "rgba(14,11,26,0.95)";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      if (d > 0) {
        ctx.fillStyle = "rgba(255,255,255,0.16)";
        for (const l of L) ctx.fillText(l.ch, l.x + d, l.y + d);
        ctx.fillStyle = "rgba(0,0,0,0.7)";
        for (const l of L) ctx.fillText(l.ch, l.x - d, l.y - d);
        ctx.fillStyle = "rgba(30,26,50,1)";
        for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      } else {
        ctx.fillStyle = "rgba(80,74,110,1)";               // planed flush: just barely there
        for (const l of L) ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Underglow", "Chandelier", "the light moved overhead and set swinging — the shadows swing the other way", function (u) {
  const { ctx, W, BASE, MID, layout, stage, glow } = u;
  // dials moved: light below → above, on a swinging chain · shadow direction follows the swing
  let push = 0;
  return {
    press() { push = 1; },                 // set it swinging harder
    frame(dt, t) {
      stage();
      push = Math.max(0, push - dt * 0.3);
      const swing = Math.sin(t * 1.7) * (0.3 + push * 0.7);
      const lx = W / 2 + swing * W * 0.25;
      const ly = MID - BASE * 2.4;
      ctx.strokeStyle = "rgba(150,145,190,0.4)";           // the chain
      ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(W / 2, 0); ctx.lineTo(lx, ly); ctx.stroke();
      ctx.globalCompositeOperation = "lighter";
      glow(lx, ly, BASE * 1.1, "rgba(255,225,160,0.5)");
      ctx.globalCompositeOperation = "source-over";
      const L = layout(BASE, 0, 600);
      const shadowDx = -swing * BASE * 0.5;                // shadows lean away from the lamp
      ctx.fillStyle = "rgba(10,8,20,0.5)";
      for (const l of L) ctx.fillText(l.ch, l.x + shadowDx, l.y + BASE * 0.12);
      for (const l of L) {
        const k = Math.max(0, 1 - Math.abs(l.cx - lx) / (W * 0.5));
        ctx.fillStyle = "rgba(255,240,210," + (0.4 + k * 0.6) + ")";
        ctx.fillText(l.ch, l.x, l.y);
      }
    }
  };
});

rhymeOf("Split shadow", "Eclipse", "the two shadows drawn together — they align behind the phrase, darken, and part", function (u) {
  const { ctx, INK, BASE, layout, stage, TAU } = u;
  // dials moved: independent orbits → one coupled orbit that periodically aligns · a darkening at totality
  let hurry = 0;
  return {
    press() { hurry = 2; },
    frame(dt, t) {
      stage();
      hurry = Math.max(0, hurry - dt);
      const ph = t * (0.5 + hurry * 0.8);
      const sep = Math.abs(Math.sin(ph));  // 0 at totality
      const a = ph * 1.3;
      const L = layout(BASE, 0, 600);
      const totality = 1 - sep;
      ctx.fillStyle = "rgba(255,80,110," + (0.35 + totality * 0.2) + ")";
      for (const l of L) ctx.fillText(l.ch, l.x + Math.cos(a) * 5 * sep, l.y + Math.sin(a) * 4 * sep);
      ctx.fillStyle = "rgba(80,200,255," + (0.35 + totality * 0.2) + ")";
      for (const l of L) ctx.fillText(l.ch, l.x - Math.cos(a) * 5 * sep, l.y - Math.sin(a) * 4 * sep);
      const ink = Math.round(232 - totality * 120);        // the phrase dims at totality
      ctx.fillStyle = "rgb(" + ink + "," + Math.round(ink * 0.98) + "," + Math.round(ink * 1.05) + ")";
      for (const l of L) ctx.fillText(l.ch, l.x, l.y);
    }
  };
});

/* ============================== the page runner ============================== */

var FAMILY_ORDER = [
  ["weight", "Weight & width", "thin to bold to bolder — the voice clearing its throat"],
  ["glow", "Glow & neon", "soft light, hard light, storefront light"],
  ["type", "Typewriters", "letter by letter, in all the typist's moods"],
  ["fade", "Fades & pulses", "dim to visible and back — breath as opacity"],
  ["scale", "Grow & shrink", "text that swells, pops, and exhales"],
  ["scramble", "Scrambles & decodes", "wrong letters on their way to right ones"],
  ["wave", "Waves & bounces", "the baseline as a trampoline"],
  ["slide", "Arrivals", "letters travelling to their places"],
  ["spin", "Spins & flips", "split-flaps, coins, revolving doors"],
  ["color", "Ink & colour", "rainbows, metals, fires, and misprints"],
  ["shake", "Shakes & glitches", "jitter, corruption, and the settle after"],
  ["stroke", "Strokes & outlines", "hollow letters, and the pen still writing"],
  ["particle", "Dust & particles", "letters assembled from, and lost to, sparks"],
  ["shadow", "Depth & shadow", "long shadows, stacked extrusions, moving lights"]
];

var grid = document.getElementById("grimoire");
var statusEl = document.getElementById("status");
var runAllBtn = document.getElementById("runall");
var stopAllBtn = document.getElementById("stopall");
var cards = [];

function buildCard(effect) {
  var card = document.createElement("div");
  card.className = "bcard";
  var canvas = document.createElement("canvas");
  canvas.title = effect.name + " — click to wake it, click again to trigger it";
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

  var st = { effect: effect, canvas: canvas, u: null, inst: null, running: false, elapsed: 0, visible: true, useRhyme: false };
  st.refresh = function () {
    var v = variantOf(st);
    b.textContent = v.name;
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
    startCard(st);                         // seeing the change at once IS the lesson
  });
  a.addEventListener("click", function () { openInEditor(effect, st.useRhyme); });
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
  u.stage();
  u.ctx.fillStyle = u.DIM;
  var L = u.layout();
  for (var i = 0; i < L.length; i++) u.ctx.fillText(L[i].ch, L[i].x, L[i].y);
  u.ctx.fillStyle = "rgba(230,227,242,0.55)";
  u.ctx.font = "12px system-ui, sans-serif";
  u.ctx.textAlign = "center";
  u.ctx.fillText("▶ click to wake", u.W / 2, u.H * 0.16);
  u.ctx.textAlign = "left";
}

function startCard(st) {
  var u = apiFor(st.canvas);
  st.u = u;
  try { st.inst = variantOf(st).make(u); } catch (err) { failCard(st, err); return; }
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
  c.shadowBlur = 0;
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
  small.textContent = list.length + " effects — " + fam[2];
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
  u.stage();
  u.ctx.fillStyle = u.DIM;
  var L = u.layout();
  for (var i = 0; i < L.length; i++) u.ctx.fillText(L[i].ch, L[i].x, L[i].y);
  u.ctx.fillStyle = "rgba(230,227,242,0.6)";
  u.ctx.font = "15px system-ui, sans-serif";
  u.ctx.textAlign = "center";
  u.ctx.fillText("Press ▶ Run — nothing moves until you do.", u.W / 2, u.H * 0.18);
  u.ctx.textAlign = "left";
}

function openInEditor(effect, useRhyme) {
  current = { effect: effect, useRhyme: !!(useRhyme && effect.rhyme) };
  var v = current.useRhyme ? effect.rhyme : effect;
  edname.textContent = current.useRhyme
    ? v.name + " — a rhyme of " + effect.name + " — " + v.hint
    : v.name + " — " + v.hint;
  codeBox.value = dedent(v.make.toString());
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
  openInEditor(current.effect, current.useRhyme);
});
cv.addEventListener("pointerdown", function (e) {
  if (!pv.inst || !pv.inst.press) return;
  var r = cv.getBoundingClientRect();
  try { pv.inst.press(e.clientX - r.left, e.clientY - r.top); }
  catch (err) { errBox.textContent = "The press handler hit a snag: " + err.message; }
});

openInEditor(EFFECTS[0]);

/* expose a tiny hook for the automated smoke test (harmless in normal use) */
window.__grimoire = { EFFECTS: EFFECTS, apiFor: apiFor, cards: cards };
})();
