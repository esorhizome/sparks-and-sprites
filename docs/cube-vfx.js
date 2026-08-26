/* Sparks & Sprites — the cube codex.
   One protagonist (a cube with eyes, pacing its stage) and 104 effects that
   attach to it, launch from it, or happen to it — the character-VFX answer
   to the elemental button bestiary. Decorations, neutral energy, fighting
   moves: if this were a fighting game or a 2D open world, these are the
   effects a character wears.

   Every effect is one function make(u) that returns { frame(dt, t), press(x, y) }.
   The kit u:
     ctx, W, H     — the 2D context and canvas size (CSS pixels)
     G             — the ground's y (the stage floor line)
     C             — the cube: { x, y, s, face, vx, t, pace, hop, lean,
                       alpha, tint, spin } — y is its feet, s its side,
                       face is ±1. Effects may set pace=false and drive x/vx
                       themselves, or set alpha/tint/spin for costume work;
                       the kit resets nothing — put it back when you're done.
     stage()       — clears the canvas: backdrop band + floor + ground line
     tickCube(dt)  — the patrol: a slow stroll with a walk-bob and a lean
     drawCube()    — shadow, body, eyes — call it BETWEEN your background
                     and foreground layers; the sandwich is the layering
     glow(x,y,r,c) — a soft radial glow (colour string with its own alpha)
     rand(a, b), TAU

   Nothing animates until the visitor presses Run (or clicks a card awake),
   and every card rests after 60 seconds as a courtesy. */
(function () {
"use strict";
var TAU = Math.PI * 2;

var EFFECTS = [];
function def(name, tag, hint, make) {
  EFFECTS.push({ name: name, tag: tag, hint: hint, make: make });
}

function apiFor(canvas) {
  var dpr = window.devicePixelRatio || 1;
  var W = canvas.clientWidth, H = canvas.clientHeight;
  canvas.width = Math.round(W * dpr);
  canvas.height = Math.round(H * dpr);
  var ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  var G = H * 0.8;
  var C = { x: W * 0.5, y: G, s: Math.max(16, H * 0.17), face: 1, vx: 0,
            t: Math.random() * 9, pace: true, hop: 0, lean: 0,
            alpha: 1, tint: null, spin: 0 };
  function rand(a, b) { return a + Math.random() * (b - a); }
  function tickCube(dt) {
    C.t += dt;
    if (C.pace) {                          // the stroll: there and back again
      var nx = W / 2 + Math.sin(C.t * 0.55) * W * 0.2;
      C.vx = (nx - C.x) / Math.max(dt, 1e-4);
      if (Math.abs(C.vx) > 2) C.face = C.vx > 0 ? 1 : -1;
      C.x = nx;
    } else {
      C.x += C.vx * dt;
    }
    var stride = Math.min(1, Math.abs(C.vx) / 30);
    C.hop = Math.abs(Math.sin(C.t * 4.2)) * C.s * 0.07 * stride;
    C.lean = Math.max(-0.14, Math.min(0.14, C.vx * 0.002));
  }
  function drawCube() {
    if (C.alpha <= 0.01) return;
    var s = C.s;
    ctx.save();
    ctx.globalAlpha *= C.alpha;
    ctx.fillStyle = "rgba(0,0,0,0.35)";    // the grounding shadow
    ctx.beginPath();
    ctx.ellipse(C.x, C.y + 2, s * 0.5, s * 0.14, 0, 0, TAU);
    ctx.fill();
    ctx.translate(C.x, C.y - C.hop);
    ctx.rotate(C.lean + C.spin);
    ctx.fillStyle = C.tint || "#4A4370";
    ctx.strokeStyle = "rgba(190,185,225,0.7)";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.rect(-s / 2, -s, s, s);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#F0EEFF";             // two earnest eyes, looking ahead
    var ex = C.face * s * 0.13;
    ctx.fillRect(ex - s * 0.17 - 1.5, -s * 0.68, 3, 4.5);
    ctx.fillRect(ex + s * 0.17 - 1.5, -s * 0.68, 3, 4.5);
    ctx.restore();
  }
  function stage() {
    ctx.fillStyle = "#131020";
    ctx.fillRect(0, 0, W, H);
    var g = ctx.createLinearGradient(0, 0, 0, G);   // the backdrop band
    g.addColorStop(0, "#1A1532");
    g.addColorStop(1, "#131020");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, G);
    ctx.fillStyle = "#1C1830";                       // the floor
    ctx.fillRect(0, G, W, H - G);
    ctx.strokeStyle = "rgba(150,145,190,0.35)";
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, G); ctx.lineTo(W, G); ctx.stroke();
  }
  function glow(x, y, r, colour) {
    var g = ctx.createRadialGradient(x, y, 0, x, y, Math.max(1, r));
    g.addColorStop(0, colour);
    g.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(x, y, Math.max(1, r), 0, TAU); ctx.fill();
  }
  function twinkle(x, y, size, colour) {   // a 4-point sparkle, everywhere useful
    ctx.strokeStyle = colour;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x - size, y); ctx.lineTo(x + size, y);
    ctx.moveTo(x, y - size); ctx.lineTo(x, y + size);
    ctx.stroke();
  }
  return { ctx: ctx, W: W, H: H, G: G, C: C, rand: rand, TAU: TAU,
           stage: stage, tickCube: tickCube, drawCube: drawCube,
           glow: glow, twinkle: twinkle };
}

/* ============================== FIRE ATTACKS ============================== */

def("Fireburst", "fire", "ember flecks idle at its fists; press for the radial explosion", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let parts = [], flash = 0;
  return {
    press() {
      flash = 1;
      for (let i = 0; i < 26; i++) {
        const th = rand(0, TAU), v = rand(50, 190);
        parts.push({ x: C.x, y: C.y - C.s * 0.5, vx: Math.cos(th) * v, vy: Math.sin(th) * v - 30, life: 1 });
      }
    },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (Math.random() < 0.25)            // the idle: embers at the fists
        parts.push({ x: C.x + C.face * C.s * 0.55, y: C.y - C.s * 0.35,
                     vx: rand(-8, 8), vy: rand(-30, -12), life: 0.6 });
      drawCube();
      ctx.globalCompositeOperation = "lighter";
      if (flash > 0) {
        glow(C.x, C.y - C.s * 0.5, C.s * (2.5 - flash), "rgba(255,180,80," + flash * 0.7 + ")");
        flash = Math.max(0, flash - dt * 2.5);
      }
      for (const p of parts) {
        p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 160 * dt; p.life -= dt * 1.3;
        if (p.life > 0) glow(p.x, p.y, 4 + p.life * 4, "rgba(255," + Math.round(120 + p.life * 100) + ",50," + p.life * 0.8 + ")");
      }
      parts = parts.filter(p => p.life > 0 && p.y < G + 6);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Flamethrower", "fire", "a pilot light waits; press for the cone of fire", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let stream = 0, parts = [];
  return {
    press() { stream = 1.2; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      const hx = C.x + C.face * C.s * 0.6, hy = C.y - C.s * 0.45;
      ctx.globalCompositeOperation = "lighter";
      glow(hx, hy, 4 + Math.sin(t * 12) * 1.5, "rgba(255,190,90,0.8)");   // the pilot
      if (stream > 0) {
        stream -= dt;
        for (let i = 0; i < 4; i++)
          parts.push({ x: hx, y: hy, vx: C.face * rand(140, 220), vy: rand(-28, 28), life: rand(0.4, 0.8) });
      }
      for (const p of parts) {
        p.x += p.vx * dt; p.y += p.vy * dt; p.vy -= 26 * dt; p.life -= dt * 1.5;
        if (p.life > 0)
          glow(p.x, p.y, 5 + (1 - p.life) * 10, "rgba(255," + Math.round(90 + p.life * 140) + ",40," + p.life * 0.6 + ")");
      }
      parts = parts.filter(p => p.life > 0);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Meteor call", "fire", "press to call a meteor down on the spot you click", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let meteors = [], debris = [], shake = 0;
  return {
    press(x) {
      meteors.push({ x: (x || C.x) + 40, y: -20, tx: x || C.x, life: 1 });
    },
    frame(dt, t) {
      stage();
      const sh = shake * shake * 5;
      ctx.save();
      ctx.translate(rand(-sh, sh), rand(-sh, sh));
      tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      glow(C.x, C.y - C.s * 1.6, 6, "rgba(255,120,60," + (0.2 + 0.15 * Math.sin(t * 3)) + ")");
      for (const m of meteors) {           // dive at 60°, explode on the floor
        m.x -= 90 * dt; m.y += 200 * dt;
        glow(m.x, m.y, 9, "rgba(255,200,120,0.9)");
        ctx.strokeStyle = "rgba(255,140,60,0.6)";
        ctx.lineWidth = 3;
        ctx.beginPath(); ctx.moveTo(m.x + 18, m.y - 40); ctx.lineTo(m.x, m.y); ctx.stroke();
        if (m.y >= G - 4) {
          shake = 1;
          for (let i = 0; i < 16; i++)
            debris.push({ x: m.x, y: G, vx: rand(-120, 120), vy: rand(-180, -40), life: 1 });
          m.y = 1e9;
        }
      }
      meteors = meteors.filter(m => m.y < H + 40);
      for (const d of debris) {
        d.x += d.vx * dt; d.y += d.vy * dt; d.vy += 320 * dt; d.life -= dt * 1.2;
        if (d.life > 0) glow(d.x, d.y, 3.5, "rgba(255,150,70," + d.life + ")");
      }
      debris = debris.filter(d => d.life > 0);
      ctx.globalCompositeOperation = "source-over";
      ctx.restore();
      shake = Math.max(0, shake - dt * 1.6);
    }
  };
});

def("Flame aura", "fire", "the cube smoulders as it strolls; press to flare", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let parts = [], flare = 0;
  return {
    press() { flare = 1; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (Math.random() < 0.6 + flare)
        parts.push({ x: C.x + rand(-C.s * 0.5, C.s * 0.5), y: C.y - rand(0, C.s),
                     life: 1, r: rand(3, 6) * (1 + flare) });
      ctx.globalCompositeOperation = "lighter";
      for (const p of parts) {             // rise, shrink, fade — chapter 6's flame
        p.y -= 42 * dt; p.x += Math.sin(p.y * 0.2) * 14 * dt; p.life -= dt * 1.5;
        if (p.life > 0)
          glow(p.x, p.y, p.r * p.life + 1, "rgba(255," + Math.round(100 + p.life * 120) + ",45," + p.life * 0.55 + ")");
      }
      parts = parts.filter(p => p.life > 0);
      ctx.globalCompositeOperation = "source-over";
      drawCube();
      flare = Math.max(0, flare - dt * 1.4);
    }
  };
});

def("Ember dash", "fire", "press and it dashes, leaving a road of embers", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let dash = 0, parts = [];
  return {
    press() {
      if (dash <= 0) { dash = 0.35; C.pace = false; C.vx = C.face * 420; }
    },
    frame(dt, t) {
      stage();
      if (dash > 0) {
        dash -= dt;
        for (let i = 0; i < 3; i++)
          parts.push({ x: C.x + rand(-4, 4), y: C.y - rand(2, C.s * 0.8), life: 1 });
        if (C.x < C.s || C.x > W - C.s || dash <= 0) {   // stop at walls or timeout
          dash = 0; C.pace = true;
          C.x = Math.max(C.s, Math.min(W - C.s, C.x));
        }
      }
      tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      if (Math.random() < 0.1)             // idle: a single ember drips
        parts.push({ x: C.x, y: C.y - 2, life: 0.7 });
      for (const p of parts) {
        p.y -= 20 * dt; p.life -= dt * 1.6;
        if (p.life > 0) glow(p.x, p.y, 3 + p.life * 3, "rgba(255,140,60," + p.life * 0.8 + ")");
      }
      parts = parts.filter(p => p.life > 0);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Fire spin", "fire", "press: a spinning ring of flame blooms outward", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let ring = -1, a0 = 0;
  return {
    press() { ring = 0; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (ring >= 0) {
        ring += dt * 1.4;
        a0 += dt * 14;
        C.spin = Math.sin(Math.min(1, ring) * Math.PI) * 0.5;   // the cube twirls too
        if (ring > 1) { ring = -1; C.spin = 0; }
      }
      drawCube();
      ctx.globalCompositeOperation = "lighter";
      glow(C.x, C.y - C.s * 0.5, C.s * 0.5, "rgba(255,120,50,0.10)");     // heat idle
      if (ring >= 0) {
        const r = 10 + ring * C.s * 2.6;
        for (let i = 0; i < 10; i++) {     // ten flame tongues on the ring
          const th = a0 + i / 10 * TAU;
          glow(C.x + Math.cos(th) * r, C.y - C.s * 0.4 + Math.sin(th) * r * 0.4,
               7 * (1 - ring * 0.6), "rgba(255," + Math.round(200 - ring * 120) + ",70," + (0.8 - ring * 0.6) + ")");
        }
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Dragon breath", "fire", "press: a huge cone of fire, with honest recoil", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let breath = 0, parts = [];
  return {
    press() { breath = 0.9; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (breath > 0) {
        breath -= dt;
        C.lean = -C.face * 0.12;           // recoil: lean away from the blast
        for (let i = 0; i < 6; i++) {
          const spread = rand(-0.35, 0.35);
          parts.push({ x: C.x + C.face * C.s * 0.5, y: C.y - C.s * 0.55,
                       vx: C.face * Math.cos(spread) * rand(180, 300), vy: Math.sin(spread) * 160,
                       life: rand(0.5, 0.9) });
        }
      }
      drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (const p of parts) {
        p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt * 1.4;
        if (p.life > 0)
          glow(p.x, p.y, 6 + (1 - p.life) * 14, "rgba(255," + Math.round(80 + p.life * 160) + ",40," + p.life * 0.55 + ")");
      }
      parts = parts.filter(p => p.life > 0);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Phoenix guard", "fire", "feather embers orbit; press and a wing shields the front", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let guard = 0;
  const feathers = [];
  for (let i = 0; i < 7; i++) feathers.push({ a: rand(0, TAU), v: rand(0.8, 1.4) });
  return {
    press() { guard = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (const f of feathers) {          // the idle orbit of feather-embers
        f.a += f.v * dt;
        const x = C.x + Math.cos(f.a) * C.s * 1.1;
        const y = C.y - C.s * 0.5 + Math.sin(f.a) * C.s * 0.7;
        ctx.save();
        ctx.translate(x, y); ctx.rotate(f.a);
        ctx.fillStyle = "rgba(255,150,70,0.6)";
        ctx.beginPath(); ctx.ellipse(0, 0, 2, 5.5, 0, 0, TAU); ctx.fill();
        ctx.restore();
      }
      if (guard > 0) {                     // the wing: layered arcs, front side
        guard = Math.max(0, guard - dt * 0.8);
        for (let k = 0; k < 4; k++) {
          ctx.strokeStyle = "rgba(255," + (150 + k * 20) + ",80," + guard * 0.7 + ")";
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.ellipse(C.x + C.face * C.s * 0.9, C.y - C.s * 0.55,
                      C.s * (0.5 + k * 0.16), C.s * (0.9 + k * 0.2), 0,
                      C.face > 0 ? -1.4 : Math.PI - 1.4, C.face > 0 ? 1.4 : Math.PI + 1.4);
          ctx.stroke();
        }
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

/* ============================== WATER ATTACKS ============================== */

def("Waterhose", "water", "it drips politely; press for the arcing jet", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let jet = 0, drops = [], splashes = [];
  return {
    press() { jet = 1.1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      const hx = C.x + C.face * C.s * 0.6, hy = C.y - C.s * 0.5;
      if (Math.random() < 0.06)            // the idle drip
        drops.push({ x: hx, y: hy, vx: C.face * 10, vy: 10, life: 1 });
      if (jet > 0) {
        jet -= dt;
        for (let i = 0; i < 3; i++)
          drops.push({ x: hx, y: hy, vx: C.face * rand(190, 240), vy: rand(-150, -120), life: 1.6 });
      }
      for (const d of drops) {             // projectile water: gravity does the arc
        d.x += d.vx * dt; d.y += d.vy * dt; d.vy += 300 * dt; d.life -= dt * 0.8;
        if (d.y >= G) {                    // landing = a splash event
          for (let i = 0; i < 3; i++)
            splashes.push({ x: d.x, y: G, vx: rand(-50, 50), vy: rand(-90, -30), life: 0.6 });
          d.life = 0;
        }
        if (d.life > 0) {
          ctx.fillStyle = "rgba(120,190,240,0.85)";
          ctx.beginPath(); ctx.ellipse(d.x, d.y, 2, 3.2, 0, 0, TAU); ctx.fill();
        }
      }
      drops = drops.filter(d => d.life > 0);
      for (const s of splashes) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 260 * dt; s.life -= dt * 1.6;
        if (s.life > 0) { ctx.fillStyle = "rgba(170,220,250," + s.life + ")"; ctx.fillRect(s.x, s.y, 2, 2); }
      }
      splashes = splashes.filter(s => s.life > 0);
    }
  };
});

def("Bubble shield", "water", "a shimmering bubble around it; press to pop and reform", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let up = 1, reform = 0, drops = [];
  return {
    press() {
      if (up < 1) return;
      up = 0; reform = 1.4;
      for (let i = 0; i < 18; i++) {
        const th = rand(0, TAU);
        drops.push({ x: C.x + Math.cos(th) * C.s, y: C.y - C.s * 0.5 + Math.sin(th) * C.s,
                     vx: Math.cos(th) * rand(40, 90), vy: Math.sin(th) * rand(40, 90), life: 1 });
      }
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      reform = Math.max(0, reform - dt);
      if (reform <= 0) up = Math.min(1, up + dt * 1.5);
      if (up > 0.05) {                     // the bubble: rim + drifting highlight
        const r = C.s * 1.25 * up;
        ctx.strokeStyle = "rgba(150,210,245," + 0.55 * up + ")";
        ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.ellipse(C.x, C.y - C.s * 0.5, r, r * 1.05, 0, 0, TAU); ctx.stroke();
        ctx.strokeStyle = "rgba(255,255,255," + 0.5 * up + ")";
        const ha = t * 0.8;
        ctx.beginPath(); ctx.ellipse(C.x, C.y - C.s * 0.5, r * 0.85, r * 0.9, 0, ha, ha + 0.7); ctx.stroke();
      }
      for (const d of drops) {
        d.x += d.vx * dt; d.y += d.vy * dt; d.vy += 150 * dt; d.life -= dt * 1.4;
        if (d.life > 0) { ctx.fillStyle = "rgba(170,220,250," + d.life + ")"; ctx.fillRect(d.x, d.y, 2, 2); }
      }
      drops = drops.filter(d => d.life > 0);
    }
  };
});

def("Splash stomp", "water", "press: a hop, a landing, and rings across the wet floor", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let jump = -1, rings = [], drops = [];
  return {
    press() { if (jump < 0) jump = 0; },
    frame(dt, t) {
      stage(); tickCube(dt);
      // the puddle it always carries
      ctx.fillStyle = "rgba(90,150,210,0.20)";
      ctx.beginPath(); ctx.ellipse(C.x, G + 3, C.s * 1.1, 4, 0, 0, TAU); ctx.fill();
      if (jump >= 0) {                     // hop arc; landing throws the splash
        jump += dt * 2.4;
        C.y = G - Math.sin(Math.min(1, jump) * Math.PI) * C.s * 1.4;
        if (jump >= 1) {
          C.y = G; jump = -1;
          rings.push({ r: 4, life: 1 });
          for (let i = 0; i < 12; i++)
            drops.push({ x: C.x, y: G, vx: rand(-110, 110), vy: rand(-160, -50), life: 1 });
        }
      }
      drawCube();
      for (const ring of rings) {
        ring.r += 90 * dt; ring.life -= dt * 1.4;
        if (ring.life > 0) {
          ctx.strokeStyle = "rgba(150,210,245," + ring.life * 0.8 + ")";
          ctx.lineWidth = 1.6;
          ctx.beginPath(); ctx.ellipse(C.x, G + 2, ring.r, ring.r * 0.25, 0, 0, TAU); ctx.stroke();
        }
      }
      rings = rings.filter(r => r.life > 0);
      for (const d of drops) {
        d.x += d.vx * dt; d.y += d.vy * dt; d.vy += 300 * dt; d.life -= dt * 1.5;
        if (d.life > 0) { ctx.fillStyle = "rgba(170,220,250," + d.life + ")"; ctx.fillRect(d.x, d.y, 2, 2); }
      }
      drops = drops.filter(d => d.life > 0);
    }
  };
});

def("Rain cloud pet", "water", "a loyal cloud follows overhead, drizzling; press: downpour", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let cx = 0, pour = 0, rain = [];
  return {
    press() { pour = 1.2; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      cx += (C.x - cx) * Math.min(1, dt * 3);          // the cloud lags, loyally
      const cy = C.y - C.s * 2.1 + Math.sin(t * 1.3) * 2;
      for (let i = 0; i < 5; i++) {
        ctx.fillStyle = "rgba(120,125,155,0.9)";
        ctx.beginPath();
        ctx.arc(cx + (i - 2) * 8, cy + Math.sin(i * 2.3) * 2.5, 7 + (i % 2) * 2, 0, TAU);
        ctx.fill();
      }
      if (Math.random() < 0.25 + pour)
        rain.push({ x: cx + rand(-16, 16), y: cy + 8, life: 1 });
      if (pour > 0) pour -= dt;
      for (const r of rain) {
        r.y += 170 * dt;
        if (r.y >= C.y - C.s && Math.abs(r.x - C.x) < C.s * 0.5) r.y = 1e9;   // bonk
        if (r.y >= G) r.y = 1e9;
        ctx.strokeStyle = "rgba(150,200,240,0.6)";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(r.x, r.y - 5); ctx.lineTo(r.x, r.y); ctx.stroke();
      }
      rain = rain.filter(r => r.y < H);
    }
  };
});

def("Water whip", "water", "press: a sinuous lash of water snaps forward", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let lash = -1, drops = [];
  return {
    press() { if (lash < 0) lash = 0; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      const hx = C.x + C.face * C.s * 0.5, hy = C.y - C.s * 0.6;
      if (lash >= 0) {
        lash += dt * 2.2;
        const k = Math.min(1, lash);       // reach: out fast, ease at the tip
        const reach = Math.sin(k * Math.PI) * C.s * 3.2;
        ctx.strokeStyle = "rgba(130,200,245,0.85)";
        ctx.lineWidth = 4;
        ctx.lineCap = "round";
        ctx.beginPath();
        ctx.moveTo(hx, hy);
        for (let i = 1; i <= 10; i++) {    // the whip: a sine that travels
          const q = i / 10;
          ctx.lineTo(hx + C.face * reach * q,
                     hy + Math.sin(q * 6 - lash * 10) * 8 * (1 - q * 0.4));
        }
        ctx.stroke();
        if (Math.random() < 0.6)
          drops.push({ x: hx + C.face * reach, y: hy, vx: rand(-30, 30), vy: rand(-40, 20), life: 0.6 });
        if (lash >= 1) lash = -1;
      } else {                             // the idle sway of a coiled whip
        ctx.strokeStyle = "rgba(130,200,245,0.5)";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(hx, hy);
        ctx.quadraticCurveTo(hx + C.face * 8, hy + 10 + Math.sin(t * 2) * 2, hx + C.face * 3, hy + 18);
        ctx.stroke();
      }
      for (const d of drops) {
        d.x += d.vx * dt; d.y += d.vy * dt; d.vy += 200 * dt; d.life -= dt * 1.8;
        if (d.life > 0) { ctx.fillStyle = "rgba(170,220,250," + d.life + ")"; ctx.fillRect(d.x, d.y, 2, 2); }
      }
      drops = drops.filter(d => d.life > 0);
    }
  };
});

def("Geyser", "water", "the ground bubbles somewhere; press to erupt it where you click", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let gx = 0, geysers = [];
  return {
    press(x) { geysers.push({ x: x || gx, life: 1 }); },
    frame(dt, t) {
      stage();
      gx = W / 2 + Math.sin(t * 0.3 + 2) * W * 0.3;   // the wandering weak spot
      if (Math.random() < 0.15) {
        ctx.strokeStyle = "rgba(150,210,245,0.5)";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(gx + rand(-6, 6), G - 1, rand(1.5, 3), Math.PI, TAU); ctx.stroke();
      }
      tickCube(dt); drawCube();
      for (const g of geysers) {           // the column: a jet of stacked blobs
        g.life -= dt * 0.7;
        if (g.life <= 0) continue;
        const hgt = Math.sin(Math.min(1, (1 - g.life) * 3) * Math.PI * 0.5) * C.s * 2.8 * Math.min(1, g.life * 2);
        for (let i = 0; i < 8; i++) {
          const q = i / 8;
          ctx.fillStyle = "rgba(140,205,245," + (0.55 - q * 0.3) + ")";
          ctx.beginPath();
          ctx.ellipse(g.x + Math.sin(t * 20 + i) * 2, G - hgt * q, 6 - q * 2, 9, 0, 0, TAU);
          ctx.fill();
        }
        glow(g.x, G - hgt, 10, "rgba(190,230,250,0.5)");
      }
      geysers = geysers.filter(g => g.life > 0);
    }
  };
});

def("Mist veil", "water", "fog clings to it; press to vanish into the mist a moment", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let veil = 0;
  const wisps = [];
  for (let i = 0; i < 6; i++) wisps.push({ a: rand(0, TAU), v: rand(0.3, 0.7), r: rand(10, 18) });
  return {
    press() { veil = 1; },
    frame(dt, t) {
      stage(); tickCube(dt);
      C.alpha = veil > 0.25 ? 0.15 : 1;    // gone while the veil is thick
      drawCube();
      C.alpha = 1;
      for (const wsp of wisps) {           // the clinging fog
        wsp.a += wsp.v * dt;
        const x = C.x + Math.cos(wsp.a) * C.s * (1 + veil);
        const y = C.y - C.s * 0.5 + Math.sin(wsp.a) * C.s * 0.6;
        glow(x, y, wsp.r * (1 + veil * 1.6), "rgba(180,200,225," + (0.10 + veil * 0.14) + ")");
      }
      veil = Math.max(0, veil - dt * 0.8);
    }
  };
});

def("Tidal push", "water", "press: a wall of water rolls forward off the stage", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let waves = [], foam = [];
  return {
    press() { waves.push({ x: C.x + C.face * C.s * 0.7, dir: C.face, life: 1 }); },
    frame(dt, t) {
      stage(); tickCube(dt);
      // idle: ankle-high lapping around the cube
      ctx.strokeStyle = "rgba(130,190,235,0.35)";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.ellipse(C.x, G + 1, C.s * (0.8 + Math.sin(t * 2) * 0.1), 3, 0, Math.PI, TAU);
      ctx.stroke();
      drawCube();
      for (const w of waves) {             // the wall: a moving hump of arcs
        w.x += w.dir * 150 * dt; w.life -= dt * 0.55;
        if (w.life <= 0) continue;
        const hgt = C.s * 1.3 * Math.min(1, w.life * 1.6);
        for (let k = 0; k < 4; k++) {
          ctx.strokeStyle = "rgba(120,190,240," + (0.6 - k * 0.12) * w.life + ")";
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.ellipse(w.x - w.dir * k * 5, G, 14 + k * 4, Math.max(0.5, hgt - k * 5), 0, Math.PI, TAU);
          ctx.stroke();
        }
        if (Math.random() < 0.5)
          foam.push({ x: w.x + rand(-8, 8), y: G - hgt, vx: w.dir * 40, vy: rand(-40, 0), life: 0.7 });
      }
      waves = waves.filter(w => w.life > 0);
      for (const f of foam) {
        f.x += f.vx * dt; f.y += f.vy * dt; f.vy += 160 * dt; f.life -= dt * 1.6;
        if (f.life > 0) { ctx.fillStyle = "rgba(220,240,255," + f.life + ")"; ctx.fillRect(f.x, f.y, 2, 2); }
      }
      foam = foam.filter(f => f.life > 0);
    }
  };
});

/* ============================== LIGHTNING ============================== */

def("Sky bolt", "bolt", "a cloud broods; press to call the bolt down where you click", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let bolts = [], flash = 0;
  return {
    press(x) { bolts.push({ x: x || C.x, life: 1 }); flash = 1; },
    frame(dt, t) {
      stage();
      if (flash > 0.6) {                   // the whole sky answers
        ctx.fillStyle = "rgba(200,210,240," + (flash - 0.6) + ")";
        ctx.fillRect(0, 0, W, H);
      }
      for (let i = 0; i < 4; i++) {        // the brooding cloud bank
        ctx.fillStyle = "rgba(70,72,95,0.9)";
        ctx.beginPath();
        ctx.arc(W * 0.2 + i * W * 0.2, 12 + Math.sin(t + i) * 2, 12, 0, TAU);
        ctx.fill();
      }
      tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (const b of bolts) {             // jagged march, sky to floor
        b.life -= dt * 3;
        if (b.life <= 0) continue;
        ctx.strokeStyle = "rgba(220,230,255," + b.life + ")";
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        let px = b.x, py = 16;
        ctx.moveTo(px, py);
        while (py < G) { px += rand(-9, 9); py += rand(10, 20); ctx.lineTo(px, py); }
        ctx.stroke();
        glow(b.x, G, 14, "rgba(200,220,255," + b.life * 0.7 + ")");
      }
      bolts = bolts.filter(b => b.life > 0);
      ctx.globalCompositeOperation = "source-over";
      flash = Math.max(0, flash - dt * 3);
    }
  };
});

def("Chain zap", "bolt", "small arcs crawl on it; press and the charge hops forward in a chain", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let chain = -1;
  function jag(x0, y0, x1, y1, a) {
    ctx.strokeStyle = "rgba(180,210,255," + a + ")";
    ctx.lineWidth = 1.6;
    ctx.beginPath(); ctx.moveTo(x0, y0);
    for (let i = 1; i <= 4; i++) {
      const k = i / 4;
      ctx.lineTo(x0 + (x1 - x0) * k + rand(-4, 4), y0 + (y1 - y0) * k + rand(-4, 4));
    }
    ctx.stroke();
  }
  return {
    press() { chain = 0; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      if (Math.random() < 0.3)             // idle: a crawl across the body
        jag(C.x + rand(-C.s, C.s) * 0.5, C.y - rand(0, C.s),
            C.x + rand(-C.s, C.s) * 0.5, C.y - rand(0, C.s), 0.7);
      if (chain >= 0) {
        chain += dt * 3;
        const hops = Math.min(3, Math.floor(chain) + 1);
        let px = C.x, py = C.y - C.s * 0.5;
        for (let i = 0; i < hops; i++) {   // each hop lands a bit further out
          const nx = C.x + C.face * C.s * (1.4 + i * 1.3);
          const ny = G - 8 - (i % 2) * 14;
          jag(px, py, nx, ny, 1 - chain * 0.25);
          glow(nx, ny, 7, "rgba(200,220,255," + (1 - chain * 0.25) + ")");
          px = nx; py = ny;
        }
        if (chain > 3.5) chain = -1;
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Static aura", "bolt", "it crackles as it walks; press for the discharge nova", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let nova = 0;
  return {
    press() { nova = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (let i = 0; i < 3; i++)          // idle crackle: tiny random bolts
        if (Math.random() < 0.4) {
          const th = rand(0, TAU);
          const x0 = C.x + Math.cos(th) * C.s * 0.55;
          const y0 = C.y - C.s * 0.5 + Math.sin(th) * C.s * 0.55;
          ctx.strokeStyle = "rgba(190,215,255,0.8)";
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(x0, y0);
          ctx.lineTo(x0 + rand(-6, 6), y0 + rand(-6, 6));
          ctx.stroke();
        }
      if (nova > 0) {
        const r = (1 - nova) * C.s * 3.2 + 8;
        ctx.strokeStyle = "rgba(200,220,255," + nova + ")";
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        for (let i = 0; i <= 14; i++) {    // a ring with electric jitter
          const th = i / 14 * TAU;
          const rr = r + rand(-2, 2);
          const px = C.x + Math.cos(th) * rr, py = C.y - C.s * 0.5 + Math.sin(th) * rr * 0.7;
          if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        }
        ctx.stroke();
        nova = Math.max(0, nova - dt * 1.8);
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Thunder clap", "bolt", "press: hands together — flash, ring, and shock lines", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let clap = 0;
  return {
    press() { clap = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      if (Math.random() < 0.08)            // idle spark motes
        glow(C.x + rand(-C.s, C.s), C.y - rand(0, C.s * 1.4), 3, "rgba(190,215,255,0.6)");
      if (clap > 0) {
        const k = 1 - clap;
        glow(C.x, C.y - C.s * 0.6, 10 + k * 20, "rgba(230,240,255," + clap + ")");
        ctx.strokeStyle = "rgba(210,225,255," + clap * 0.9 + ")";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.ellipse(C.x, C.y - C.s * 0.6, 8 + k * C.s * 2.4, (8 + k * C.s * 2.4) * 0.6, 0, 0, TAU);
        ctx.stroke();
        for (let i = 0; i < 8; i++) {      // radial shock lines
          const th = i / 8 * TAU + 0.4;
          const r0 = 10 + k * C.s * 2, r1 = r0 + 10;
          ctx.beginPath();
          ctx.moveTo(C.x + Math.cos(th) * r0, C.y - C.s * 0.6 + Math.sin(th) * r0 * 0.6);
          ctx.lineTo(C.x + Math.cos(th) * r1, C.y - C.s * 0.6 + Math.sin(th) * r1 * 0.6);
          ctx.stroke();
        }
        clap = Math.max(0, clap - dt * 2.2);
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Charge & release", "bolt", "energy spirals IN while it waits; press to let it all out", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let charge = 0, bolt = 0;
  let orbs = [];
  return {
    press() { bolt = Math.max(0.4, charge); charge = 0; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      charge = Math.min(1, charge + dt * 0.12);        // patience accumulates
      if (Math.random() < 0.3 + charge * 0.5)
        orbs.push({ a: rand(0, TAU), r: C.s * 2.2, life: 1 });
      ctx.globalCompositeOperation = "lighter";
      for (const o of orbs) {              // the intake spiral
        o.r -= 60 * dt; o.a += 3 * dt; o.life -= dt * 0.9;
        if (o.life > 0 && o.r > 4)
          glow(C.x + Math.cos(o.a) * o.r, C.y - C.s * 0.5 + Math.sin(o.a) * o.r * 0.7,
               3, "rgba(190,215,255," + o.life * 0.8 + ")");
      }
      orbs = orbs.filter(o => o.life > 0 && o.r > 4);
      glow(C.x, C.y - C.s * 0.5, 6 + charge * 14, "rgba(200,225,255," + (0.25 + charge * 0.5) + ")");
      if (bolt > 0) {                      // the release: one thick forward bolt
        ctx.strokeStyle = "rgba(225,235,255," + Math.min(1, bolt * 2) + ")";
        ctx.lineWidth = 2 + bolt * 4;
        ctx.beginPath();
        let px = C.x + C.face * C.s * 0.5, py = C.y - C.s * 0.5;
        ctx.moveTo(px, py);
        while (px > 0 && px < W) { px += C.face * rand(14, 26); py += rand(-8, 8); ctx.lineTo(px, py); }
        ctx.stroke();
        bolt = Math.max(0, bolt - dt * 2.5);
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Volt dash", "bolt", "press: it blinks forward, leaving the zigzag it travelled", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let trail = null;
  return {
    press() {
      const from = C.x;
      let to = C.x + C.face * C.s * 3.2;
      to = Math.max(C.s, Math.min(W - C.s, to));
      C.pace = false;
      C.x = to;                            // teleport, then hand control back
      C.pace = true;
      trail = { from: from, to: to, y: C.y - C.s * 0.5, life: 1 };
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      if (Math.random() < 0.15)
        glow(C.x + rand(-C.s, C.s) * 0.6, C.y - rand(0, C.s), 3, "rgba(190,215,255,0.7)");
      if (trail) {
        trail.life -= dt * 2.2;
        if (trail.life > 0) {
          ctx.strokeStyle = "rgba(200,225,255," + trail.life + ")";
          ctx.lineWidth = 2.5;
          ctx.beginPath();
          ctx.moveTo(trail.from, trail.y);
          const n = 6;
          for (let i = 1; i <= n; i++)     // the zigzag left hanging in the air
            ctx.lineTo(trail.from + (trail.to - trail.from) * i / n,
                       trail.y + (i % 2 ? -8 : 8) + rand(-2, 2));
          ctx.stroke();
        } else trail = null;
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Orbiting sparks", "bolt", "three spark orbs circle it; press and they fire off as bolts", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  const orbs = [0, 1, 2].map(i => ({ ph: i / 3 * TAU, fired: -1 }));
  return {
    press() {
      for (const o of orbs) if (o.fired < 0) o.fired = 0;
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (const o of orbs) {
        if (o.fired < 0) {                 // orbiting duty
          const a = t * 2 + o.ph;
          const x = C.x + Math.cos(a) * C.s * 1.1;
          const y = C.y - C.s * 0.5 + Math.sin(a) * C.s * 0.6;
          glow(x, y, 5, "rgba(200,220,255,0.9)");
          o.x = x; o.y = y;
        } else {                           // fired: streak away as a mini-bolt
          o.fired += dt;
          o.x += C.face * 260 * dt;
          ctx.strokeStyle = "rgba(200,225,255," + Math.max(0, 1 - o.fired) + ")";
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(o.x - C.face * 16, o.y + rand(-3, 3));
          ctx.lineTo(o.x, o.y);
          ctx.stroke();
          if (o.fired > 1.2) { o.fired = -1; }
        }
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Storm call", "bolt", "press: three bolts, a gust of rain, one drenched hero", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let storm = 0, bolts = [], rain = [];
  return {
    press() {
      storm = 1.6;
      for (let i = 0; i < 3; i++)
        bolts.push({ x: C.x + rand(-C.s * 2.4, C.s * 2.4), delay: i * 0.25, life: 1.2 });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.05 + (storm > 0 ? 0.8 : 0))
        rain.push({ x: rand(0, W), y: -4 });
      for (const r of rain) {
        r.y += 240 * dt; r.x -= 40 * dt;
        ctx.strokeStyle = "rgba(150,180,220,0.5)";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(r.x, r.y); ctx.lineTo(r.x + 1.5, r.y - 7); ctx.stroke();
      }
      rain = rain.filter(r => r.y < G);
      ctx.globalCompositeOperation = "lighter";
      for (const b of bolts) {
        b.delay -= dt;
        if (b.delay > 0) continue;
        b.life -= dt * 3;
        if (b.life <= 0) continue;
        ctx.strokeStyle = "rgba(220,230,255," + Math.min(1, b.life) + ")";
        ctx.lineWidth = 2;
        ctx.beginPath();
        let px = b.x, py = 0;
        ctx.moveTo(px, py);
        while (py < G) { px += rand(-8, 8); py += rand(12, 22); ctx.lineTo(px, py); }
        ctx.stroke();
      }
      bolts = bolts.filter(b => b.life > 0);
      ctx.globalCompositeOperation = "source-over";
      storm = Math.max(0, storm - dt);
    }
  };
});

/* ============================== SPARKLES & CHARMS ============================== */

def("Sparkle shower", "sparkle", "the occasional twinkle; press for a shower from above", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let parts = [];
  return {
    press() {
      for (let i = 0; i < 22; i++)
        parts.push({ x: C.x + rand(-C.s * 1.6, C.s * 1.6), y: C.y - C.s * 2.4 - rand(0, 20),
                     vy: rand(40, 90), life: 1, tw: rand(4, 9) });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.06)
        parts.push({ x: C.x + rand(-C.s, C.s), y: C.y - rand(0, C.s * 1.4), vy: 8, life: 0.8, tw: rand(4, 9) });
      for (const p of parts) {
        p.y += p.vy * dt; p.life -= dt * 0.9;
        if (p.life > 0)
          twinkle(p.x, p.y, 3 * p.life, "rgba(240,225,255," + Math.max(0, Math.sin(t * p.tw)) * p.life + ")");
      }
      parts = parts.filter(p => p.life > 0 && p.y < G);
    }
  };
});

def("Pixie trail", "sparkle", "glitter sheds as it walks — by distance, not by time", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let parts = [], lastX = null, travelled = 0, swirl = 0;
  return {
    press() { swirl = 1; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (lastX === null) lastX = C.x;
      travelled += Math.abs(C.x - lastX);  // the chapter-12 rule: per pixel MOVED
      lastX = C.x;
      while (travelled > 7) {
        travelled -= 7;
        parts.push({ x: C.x + rand(-4, 4), y: C.y - rand(2, C.s * 0.8), a: rand(0, TAU), life: 1, tw: rand(4, 9) });
      }
      drawCube();
      for (const p of parts) {
        if (swirl > 0) {                   // press: everything orbits the hero
          p.a += 4 * dt;
          p.x += (C.x + Math.cos(p.a) * C.s * 1.3 - p.x) * dt * 6;
          p.y += (C.y - C.s * 0.5 + Math.sin(p.a) * C.s * 0.8 - p.y) * dt * 6;
        } else p.y -= 6 * dt;
        p.life -= dt * 0.7;
        if (p.life > 0)
          twinkle(p.x, p.y, 2.5, "rgba(240,220,255," + Math.max(0, Math.sin(t * p.tw)) * p.life + ")");
      }
      parts = parts.filter(p => p.life > 0);
      swirl = Math.max(0, swirl - dt * 0.8);
    }
  };
});

def("Star twirl", "sparkle", "one loyal star orbits; press and it spins off five more", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let flung = [];
  function star(x, y, r, rot, a) {
    ctx.fillStyle = "rgba(255,230,140," + a + ")";
    ctx.beginPath();
    for (let i = 0; i < 10; i++) {
      const rr = i % 2 === 0 ? r : r * 0.45;
      const th = rot + i / 10 * TAU;
      const px = x + Math.cos(th) * rr, py = y + Math.sin(th) * rr;
      if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    }
    ctx.closePath(); ctx.fill();
  }
  return {
    press() {
      C.spin = 0.001;                      // marks "spinning" (decays below)
      for (let i = 0; i < 5; i++) {
        const th = rand(0, TAU);
        flung.push({ x: C.x, y: C.y - C.s * 0.5, vx: Math.cos(th) * rand(60, 140),
                     vy: Math.sin(th) * rand(60, 140) - 40, rot: rand(0, TAU), life: 1 });
      }
    },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (C.spin !== 0) {                  // one full pirouette, then done
        C.spin += dt * 14;
        if (C.spin > TAU) C.spin = 0;
      }
      drawCube();
      const a = t * 1.6;
      star(C.x + Math.cos(a) * C.s * 1.2, C.y - C.s * 0.5 + Math.sin(a) * C.s * 0.7, 4, t * 3, 0.9);
      for (const f of flung) {
        f.x += f.vx * dt; f.y += f.vy * dt; f.vy += 120 * dt; f.rot += 6 * dt; f.life -= dt * 1.1;
        if (f.life > 0) star(f.x, f.y, 5, f.rot, f.life);
      }
      flung = flung.filter(f => f.life > 0);
    }
  };
});

def("Glitter burst", "sparkle", "press: an explosion of glitter right where you click", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let parts = [];
  return {
    press(x, y) {
      for (let i = 0; i < 30; i++) {
        const th = rand(0, TAU), v = rand(30, 150);
        parts.push({ x: x || C.x, y: Math.min(y || C.y - C.s, G - 4),
                     vx: Math.cos(th) * v, vy: Math.sin(th) * v, life: 1,
                     hue: rand(0, 360), tw: rand(5, 10) });
      }
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.1)             // idle shimmer on the cube's crown
        twinkle(C.x + rand(-C.s * 0.4, C.s * 0.4), C.y - C.s, 2.5, "rgba(255,240,255,0.7)");
      for (const p of parts) {
        p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 60 * dt;
        p.vx *= Math.pow(0.3, dt); p.life -= dt * 0.9;
        if (p.life > 0)
          twinkle(p.x, p.y, 3, "hsla(" + p.hue + ",90%,75%," + Math.max(0, Math.sin(t * p.tw)) * p.life + ")");
      }
      parts = parts.filter(p => p.life > 0);
    }
  };
});

def("Charm hearts", "sparkle", "a shy heart now and then; press for a whole ring of them", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let hearts = [];
  function heart(x, y, s, a) {
    ctx.fillStyle = "rgba(255,150,190," + a + ")";
    ctx.beginPath();
    ctx.arc(x - s * 0.5, y, s * 0.55, 0, TAU);
    ctx.arc(x + s * 0.5, y, s * 0.55, 0, TAU);
    ctx.moveTo(x - s, y + s * 0.2);
    ctx.lineTo(x, y + s * 1.5);
    ctx.lineTo(x + s, y + s * 0.2);
    ctx.closePath(); ctx.fill();
  }
  return {
    press() {
      for (let i = 0; i < 8; i++)
        hearts.push({ a: i / 8 * TAU, r: 6, life: 1, ring: true });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.015)
        hearts.push({ x: C.x + rand(-6, 6), y: C.y - C.s * 1.2, life: 1, ring: false });
      for (const hh of hearts) {
        hh.life -= dt * 0.8;
        if (hh.life <= 0) continue;
        if (hh.ring) {
          hh.r += 40 * dt;
          heart(C.x + Math.cos(hh.a) * hh.r, C.y - C.s * 0.5 + Math.sin(hh.a) * hh.r * 0.7, 4, hh.life);
        } else {
          hh.y -= 24 * dt;
          heart(hh.x, hh.y, 4.5, hh.life);
        }
      }
      hearts = hearts.filter(hh => hh.life > 0);
    }
  };
});

def("Confetti pop", "sparkle", "press: confetti with real flutter; idle: one lazy streamer", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let bits = [];
  const hues = [340, 45, 190, 120, 270];
  return {
    press() {
      for (let i = 0; i < 26; i++)
        bits.push({ x: C.x, y: C.y - C.s, vx: rand(-90, 90), vy: rand(-190, -80),
                    rot: rand(0, TAU), vr: rand(-8, 8), hue: hues[i % hues.length],
                    flut: rand(3, 7), life: 1 });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      // the lazy streamer: one ribbon coiling off the cube's corner
      ctx.strokeStyle = "rgba(255,190,120,0.6)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(C.x + C.s * 0.4, C.y - C.s);
      for (let i = 1; i <= 6; i++)
        ctx.lineTo(C.x + C.s * 0.4 + Math.sin(t * 2 + i) * 4, C.y - C.s + i * 4);
      ctx.stroke();
      for (const b of bits) {              // flutter = sideways sway + slow fall
        b.vy += 150 * dt;
        b.vy = Math.min(b.vy, 40);         // paper falls slowly once it opens
        b.x += (b.vx + Math.sin(t * b.flut) * 30) * dt;
        b.y += b.vy * dt;
        b.rot += b.vr * dt;
        b.vx *= Math.pow(0.4, dt);
        b.life -= dt * 0.5;
        if (b.life > 0 && b.y < G) {
          ctx.save();
          ctx.translate(b.x, b.y); ctx.rotate(b.rot);
          ctx.fillStyle = "hsla(" + b.hue + ",85%,65%," + b.life + ")";
          ctx.fillRect(-2.5, -1.5, 5, 3);
          ctx.restore();
        }
      }
      bits = bits.filter(b => b.life > 0 && b.y < G);
    }
  };
});

def("Shooting star", "sparkle", "stars cross the backdrop; press and one dives to salute the hero", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let streaks = [], dive = null, timer = 1, flash = 0;
  return {
    press() { if (!dive) dive = { x: -10, y: 10 }; },
    frame(dt, t) {
      stage();
      timer -= dt;
      if (timer <= 0) { streaks.push({ x: rand(-10, W * 0.6), y: rand(4, G * 0.3), life: 1 }); timer = rand(1.5, 3); }
      ctx.globalCompositeOperation = "lighter";
      for (const s of streaks) {
        s.x += 170 * dt; s.y += 60 * dt; s.life -= dt * 0.8;
        if (s.life > 0) {
          ctx.strokeStyle = "rgba(255,240,200," + s.life * 0.8 + ")";
          ctx.lineWidth = 1.5;
          ctx.beginPath(); ctx.moveTo(s.x - 22, s.y - 8); ctx.lineTo(s.x, s.y); ctx.stroke();
        }
      }
      streaks = streaks.filter(s => s.life > 0);
      ctx.globalCompositeOperation = "source-over";
      tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      if (dive) {                          // the summoned one aims for the cube
        const tx = C.x, ty = C.y - C.s * 1.3;
        dive.x += (tx - dive.x) * dt * 4 + 60 * dt;
        dive.y += (ty - dive.y) * dt * 4;
        glow(dive.x, dive.y, 6, "rgba(255,245,210,0.95)");
        if (Math.hypot(dive.x - tx, dive.y - ty) < 8) { dive = null; flash = 1; }
      }
      if (flash > 0) {                     // the salute: a soft blessing flash
        glow(C.x, C.y - C.s * 0.6, C.s * 1.6, "rgba(255,245,210," + flash * 0.6 + ")");
        flash = Math.max(0, flash - dt * 1.4);
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Twinkle crown", "sparkle", "a crown of twinkles bobs above; press and it flares like royalty", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let flare = 0;
  return {
    press() { flare = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      const cy = C.y - C.s * 1.35 + Math.sin(t * 1.8) * 2;
      for (let i = 0; i < 5; i++) {        // five points of the crown
        const a = t * 0.8 + i / 5 * TAU;
        const x = C.x + Math.cos(a) * C.s * 0.45;
        const y = cy + Math.sin(a) * 3;
        twinkle(x, y, 2.5 + flare * 4, "rgba(255,235,150," + (0.6 + flare * 0.4) + ")");
      }
      if (flare > 0) {
        ctx.globalCompositeOperation = "lighter";
        for (let i = 0; i < 5; i++) {      // royal rays
          const th = -Math.PI / 2 + (i - 2) * 0.35;
          ctx.strokeStyle = "rgba(255,235,150," + flare * 0.6 + ")";
          ctx.lineWidth = 1.6;
          ctx.beginPath();
          ctx.moveTo(C.x, cy);
          ctx.lineTo(C.x + Math.cos(th) * (14 + (1 - flare) * 26), cy + Math.sin(th) * (14 + (1 - flare) * 26));
          ctx.stroke();
        }
        ctx.globalCompositeOperation = "source-over";
        flare = Math.max(0, flare - dt * 1.6);
      }
    }
  };
});

/* ============================== HALOS & BLESSINGS ============================== */

def("Following halo", "halo", "the classic: an ellipse of light that follows, a beat behind", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let hx = null, pulse = 0;
  return {
    press() { pulse = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (hx === null) hx = C.x;
      hx += (C.x - hx) * Math.min(1, dt * 5);          // the loyal lag
      const hy = C.y - C.s * 1.5 + Math.sin(t * 1.2) * 2.5;
      ctx.globalCompositeOperation = "lighter";
      const breath = 1 + 0.03 * Math.sin(t * TAU / 3); // chapter 06's ±3%
      for (let k = 0; k < 3; k++) {
        ctx.strokeStyle = "rgba(255,235,170," + (0.55 - k * 0.15 + pulse * 0.3) + ")";
        ctx.lineWidth = 3 - k * 0.7;
        ctx.beginPath();
        ctx.ellipse(hx, hy, (C.s * 0.55 + k * 1.5) * breath * (1 + pulse * 0.3),
                    (C.s * 0.16 + k * 0.8) * breath, 0, 0, TAU);
        ctx.stroke();
      }
      ctx.globalCompositeOperation = "source-over";
      pulse = Math.max(0, pulse - dt * 1.6);
    }
  };
});

def("Angel wings", "halo", "wing nubs flutter at its back; press and they unfurl", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let unfurl = 0;
  function wing(side, spread, a) {
    const bx = C.x - C.face * C.s * 0.3;
    const by = C.y - C.s * 0.7;
    ctx.strokeStyle = "rgba(255,250,230," + a + ")";
    ctx.lineWidth = 2;
    for (let f = 0; f < 4; f++) {          // four feather-arcs per wing
      ctx.beginPath();
      ctx.moveTo(bx, by);
      ctx.quadraticCurveTo(
        bx - C.face * (10 + f * 8) * spread, by - (18 - f * 3) * spread,
        bx - C.face * (20 + f * 12) * spread, by - (6 - f * 4) * spread + f * 3);
      ctx.stroke();
    }
  }
  return {
    press() { unfurl = 1; },
    frame(dt, t) {
      stage(); tickCube(dt);
      const spread = 0.25 + Math.sin(t * 6) * 0.04 + unfurl * 1.1;   // nubs vs glory
      ctx.globalCompositeOperation = "lighter";
      wing(-1, Math.min(1.6, spread), 0.5 + unfurl * 0.5);
      ctx.globalCompositeOperation = "source-over";
      drawCube();
      unfurl = Math.max(0, unfurl - dt * 0.55);
    }
  };
});

def("Sanctuary ring", "halo", "holy ground travels with it; press to consecrate wider", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let wide = 0;
  return {
    press() { wide = 1; },
    frame(dt, t) {
      stage(); tickCube(dt);
      const r = C.s * (1.1 + wide * 1.3);
      ctx.globalCompositeOperation = "lighter";
      glow(C.x, G, r, "rgba(255,240,190," + (0.12 + wide * 0.12) + ")");
      ctx.strokeStyle = "rgba(255,235,170," + (0.5 + wide * 0.4) + ")";
      ctx.lineWidth = 1.6;
      ctx.beginPath(); ctx.ellipse(C.x, G + 1, r, r * 0.24, 0, 0, TAU); ctx.stroke();
      for (let i = 0; i < 6; i++) {        // rune ticks pacing the circle
        const a = t * 0.7 + i / 6 * TAU;
        const x = C.x + Math.cos(a) * r, y = G + 1 + Math.sin(a) * r * 0.24;
        ctx.fillStyle = "rgba(255,240,190," + (0.6 + wide * 0.4) + ")";
        ctx.fillRect(x - 1, y - 3, 2, 6);
      }
      ctx.globalCompositeOperation = "source-over";
      drawCube();
      wide = Math.max(0, wide - dt * 0.7);
    }
  };
});

def("Light pillar", "halo", "a soft light from above; press and the full pillar descends", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let pillar = 0, motes = [];
  return {
    press() { pillar = 1; },
    frame(dt, t) {
      stage(); tickCube(dt);
      ctx.globalCompositeOperation = "lighter";
      const w = C.s * (0.5 + pillar * 1.1);
      const a = 0.06 + pillar * 0.3;
      const grad = ctx.createLinearGradient(0, 0, 0, G);
      grad.addColorStop(0, "rgba(255,248,220," + a + ")");
      grad.addColorStop(1, "rgba(255,248,220," + a * 0.25 + ")");
      ctx.fillStyle = grad;
      ctx.beginPath();                     // a gently widening beam
      ctx.moveTo(C.x - w * 0.6, 0); ctx.lineTo(C.x + w * 0.6, 0);
      ctx.lineTo(C.x + w, G); ctx.lineTo(C.x - w, G);
      ctx.closePath(); ctx.fill();
      if (pillar > 0 && Math.random() < 0.5)
        motes.push({ x: C.x + rand(-w, w) * 0.7, y: G, life: 1 });
      for (const m of motes) {
        m.y -= 40 * dt; m.life -= dt;
        if (m.life > 0) glow(m.x, m.y, 3, "rgba(255,248,220," + m.life * 0.8 + ")");
      }
      motes = motes.filter(m => m.life > 0);
      ctx.globalCompositeOperation = "source-over";
      drawCube();
      pillar = Math.max(0, pillar - dt * 0.6);
    }
  };
});

def("Guardian orbs", "halo", "three lights keep watch; press and they snap into a shield", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let shield = 0;
  return {
    press() { shield = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      const pts = [];
      for (let i = 0; i < 3; i++) {
        let x, y;
        if (shield > 0.15) {               // formation: a triangle at the front
          const th = -Math.PI / 2 + i / 3 * TAU;
          x = C.x + C.face * C.s * 0.9 + Math.cos(th) * C.s * 0.55;
          y = C.y - C.s * 0.55 + Math.sin(th) * C.s * 0.55;
        } else {                           // patrol: a lazy orbit
          const a = t * 1.4 + i / 3 * TAU;
          x = C.x + Math.cos(a) * C.s * 1.15;
          y = C.y - C.s * 0.5 + Math.sin(a) * C.s * 0.65;
        }
        pts.push([x, y]);
        glow(x, y, 5 + shield * 3, "rgba(255,240,190,0.9)");
      }
      if (shield > 0.15) {                 // the shield face between them
        ctx.fillStyle = "rgba(255,240,190," + shield * 0.22 + ")";
        ctx.beginPath();
        ctx.moveTo(pts[0][0], pts[0][1]);
        ctx.lineTo(pts[1][0], pts[1][1]);
        ctx.lineTo(pts[2][0], pts[2][1]);
        ctx.closePath(); ctx.fill();
      }
      ctx.globalCompositeOperation = "source-over";
      shield = Math.max(0, shield - dt * 0.7);
    }
  };
});

def("Blessing rain", "halo", "light motes drift down around it; press and they all ascend", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let motes = [], rise = 0;
  return {
    press() { rise = 1.4; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.3)
        motes.push({ x: C.x + rand(-C.s * 1.8, C.s * 1.8), y: rand(0, G * 0.4), life: 1 });
      ctx.globalCompositeOperation = "lighter";
      for (const m of motes) {
        m.y += (rise > 0 ? -80 : 22) * dt; // the miracle: gravity repents
        m.life -= dt * 0.4;
        if (m.life > 0 && m.y > 0 && m.y < G)
          glow(m.x, m.y, 3.5, "rgba(255,246,210," + m.life * 0.7 + ")");
      }
      motes = motes.filter(m => m.life > 0 && m.y > -8 && m.y < G);
      ctx.globalCompositeOperation = "source-over";
      rise = Math.max(0, rise - dt);
    }
  };
});

def("Radiant burst", "halo", "a warm core glow; press for the cross-flare and ring", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let burst = 0;
  return {
    press() { burst = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      glow(C.x, C.y - C.s * 0.5, C.s * 0.8, "rgba(255,240,200," + (0.14 + 0.05 * Math.sin(t * 1.3)) + ")");
      if (burst > 0) {
        const k = 1 - burst;
        const L = 10 + k * C.s * 2.4;
        ctx.strokeStyle = "rgba(255,246,215," + burst * 0.9 + ")";
        ctx.lineWidth = 2;
        ctx.beginPath();                   // the cross-flare
        ctx.moveTo(C.x - L, C.y - C.s * 0.5); ctx.lineTo(C.x + L, C.y - C.s * 0.5);
        ctx.moveTo(C.x, C.y - C.s * 0.5 - L * 0.8); ctx.lineTo(C.x, C.y - C.s * 0.5 + L * 0.8);
        ctx.stroke();
        ctx.beginPath();
        ctx.ellipse(C.x, C.y - C.s * 0.5, L * 0.8, L * 0.5, 0, 0, TAU);
        ctx.stroke();
        burst = Math.max(0, burst - dt * 1.8);
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Saint's spotlight", "halo", "a beam from above follows it — lagging; press snaps it tight", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let sx = null, snap = 0;
  return {
    press() { snap = 1; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (sx === null) sx = C.x;
      sx += (C.x - sx) * Math.min(1, dt * (2 + snap * 12));   // press = it hurries
      ctx.globalCompositeOperation = "lighter";
      const w = C.s * (1.4 - snap * 0.6);
      ctx.fillStyle = "rgba(255,248,225," + (0.10 + snap * 0.18) + ")";
      ctx.beginPath();
      ctx.moveTo(sx - 6, 0); ctx.lineTo(sx + 6, 0);
      ctx.lineTo(sx + w, G); ctx.lineTo(sx - w, G);
      ctx.closePath(); ctx.fill();
      ctx.beginPath();                     // the pool of light on the floor
      ctx.ellipse(sx, G + 1, w, w * 0.22, 0, 0, TAU);
      ctx.fill();
      ctx.globalCompositeOperation = "source-over";
      drawCube();
      snap = Math.max(0, snap - dt * 0.8);
    }
  };
});

/* ============================== AURAS & ENERGY ============================== */

def("Power-up aura", "aura", "energy flames rise around it; press for the super surge", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let parts = [], surge = 0;
  return {
    press() { surge = 1.6; },
    frame(dt, t) {
      stage(); tickCube(dt);
      const super_ = surge > 0;
      if (Math.random() < 0.6 + (super_ ? 0.4 : 0))
        parts.push({ x: C.x + rand(-C.s * 0.7, C.s * 0.7), y: C.y, life: 1 });
      ctx.globalCompositeOperation = "lighter";
      for (const p of parts) {             // the anime updraft
        p.y -= (70 + (super_ ? 90 : 0)) * dt;
        p.x += (C.x - p.x) * dt * 2;       // flames hug the hero
        p.life -= dt * 1.4;
        if (p.life > 0)
          glow(p.x, p.y, 5 + p.life * 5,
               super_ ? "rgba(255,230,120," + p.life * 0.6 + ")" : "rgba(140,170,255," + p.life * 0.5 + ")");
      }
      parts = parts.filter(p => p.life > 0);
      ctx.globalCompositeOperation = "source-over";
      C.tint = super_ ? "#6A5FA8" : null;  // the hero glows from within too
      drawCube();
      C.tint = null;
      surge = Math.max(0, surge - dt);
    }
  };
});

def("Ki charge", "aura", "wisps spiral inward while it gathers; press to release the burst", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let wisps = [], out = [];
  return {
    press() {
      for (let i = 0; i < 16; i++) {
        const th = rand(0, TAU);
        out.push({ x: C.x, y: C.y - C.s * 0.5, vx: Math.cos(th) * rand(60, 160), vy: Math.sin(th) * rand(40, 120), life: 1 });
      }
      wisps = [];
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.4)
        wisps.push({ a: rand(0, TAU), r: C.s * 2, life: 1 });
      ctx.globalCompositeOperation = "lighter";
      for (const wsp of wisps) {           // the intake
        wsp.r -= 45 * dt; wsp.a += 2.2 * dt; wsp.life -= dt * 0.8;
        if (wsp.life > 0 && wsp.r > 3)
          glow(C.x + Math.cos(wsp.a) * wsp.r, C.y - C.s * 0.5 + Math.sin(wsp.a) * wsp.r * 0.7,
               3, "rgba(160,220,255," + wsp.life * 0.7 + ")");
      }
      wisps = wisps.filter(wsp => wsp.life > 0 && wsp.r > 3);
      for (const p of out) {               // the exhale
        p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt * 1.6;
        if (p.life > 0) glow(p.x, p.y, 4, "rgba(190,235,255," + p.life * 0.8 + ")");
      }
      out = out.filter(p => p.life > 0);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Energy shield", "aura", "a faceted bubble shimmers; press and an impact ripples across it", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let hit = 0, hitA = 0;
  return {
    press(x, y) {
      hit = 1;
      hitA = Math.atan2((y || C.y - C.s) - (C.y - C.s * 0.5), (x || C.x + C.s) - C.x);
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      const r = C.s * 1.3;
      ctx.globalCompositeOperation = "lighter";
      for (let i = 0; i < 12; i++) {       // the hex shimmer, one panel at a time
        const th = i / 12 * TAU;
        const shim = Math.max(0, Math.sin(t * 2 + i * 1.7)) * 0.25;
        let a = 0.12 + shim;
        if (hit > 0) {                     // the ripple: brightness spreads from the hit
          const d = Math.abs(((th - hitA + Math.PI * 3) % TAU) - Math.PI);
          a += Math.max(0, hit - d * 0.35) * 0.7;
        }
        ctx.strokeStyle = "rgba(140,230,210," + Math.min(1, a) + ")";
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.ellipse(C.x, C.y - C.s * 0.5, r, r * 1.05, 0, th, th + 0.42);
        ctx.stroke();
      }
      ctx.globalCompositeOperation = "source-over";
      hit = Math.max(0, hit - dt * 1.8);
    }
  };
});

def("Focus lines", "aura", "press: the world's speed lines converge on the hero", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let focus = 0;
  return {
    press() { focus = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (focus > 0) {
        ctx.strokeStyle = "rgba(230,228,245," + focus * 0.6 + ")";
        ctx.lineWidth = 1.5;
        const cx = C.x, cy = C.y - C.s * 0.5;
        for (let i = 0; i < 18; i++) {     // the manga vignette: edge → almost-centre
          const th = i / 18 * TAU + focus * 0.5;
          const rOut = Math.max(W, H);
          const rIn = C.s * (2 + focus * 2);
          ctx.beginPath();
          ctx.moveTo(cx + Math.cos(th) * rOut, cy + Math.sin(th) * rOut);
          ctx.lineTo(cx + Math.cos(th) * rIn, cy + Math.sin(th) * rIn);
          ctx.stroke();
        }
        focus = Math.max(0, focus - dt * 1.2);
      }
    }
  };
});

def("Battle glow", "aura", "a heartbeat of light; press startles it into a red flare", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let alarm = 0;
  return {
    press() { alarm = 1; },
    frame(dt, t) {
      stage(); tickCube(dt);
      const rate = 1 + alarm * 1.5;
      const cyc = (t * rate) % 1.3;
      const beat = Math.exp(-Math.pow((cyc - 0.12) * 12, 2)) + Math.exp(-Math.pow((cyc - 0.36) * 12, 2)) * 0.6;
      ctx.globalCompositeOperation = "lighter";
      glow(C.x, C.y - C.s * 0.5, C.s * (1 + beat * 0.5),
           alarm > 0 ? "rgba(255,110,110," + (0.15 + beat * 0.4) + ")"
                     : "rgba(150,170,255," + (0.10 + beat * 0.3) + ")");
      ctx.globalCompositeOperation = "source-over";
      drawCube();
      alarm = Math.max(0, alarm - dt * 0.4);
    }
  };
});

def("Overdrive", "aura", "press to TOGGLE overdrive — blue flames until you say otherwise", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let on = false, parts = [];
  return {
    press() { on = !on; },                 // a switch, not a pulse — real state
    frame(dt, t) {
      stage(); tickCube(dt);
      if (on && Math.random() < 0.8)
        parts.push({ x: C.x + rand(-C.s * 0.6, C.s * 0.6), y: C.y - rand(0, C.s), life: 1 });
      ctx.globalCompositeOperation = "lighter";
      for (const p of parts) {
        p.y -= 90 * dt; p.life -= dt * 1.8;
        if (p.life > 0) glow(p.x, p.y, 4 + p.life * 5, "rgba(110,180,255," + p.life * 0.6 + ")");
      }
      parts = parts.filter(p => p.life > 0);
      ctx.globalCompositeOperation = "source-over";
      C.tint = on ? "#39549E" : null;
      drawCube();
      C.tint = null;
    }
  };
});

def("Inner light", "aura", "cracks of light run through the cube; press and they flare", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let flare = 0;
  const cracks = [];
  for (let i = 0; i < 4; i++) {            // crack paths in cube-local space
    const pts = [{ x: rand(-0.4, 0.4), y: -rand(0, 0.9) }];
    for (let k = 0; k < 3; k++)
      pts.push({ x: pts[k].x + rand(-0.25, 0.25), y: pts[k].y + rand(-0.25, 0.25) });
    cracks.push(pts);
  }
  return {
    press() { flare = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.save();
      ctx.translate(C.x, C.y - C.hop);
      ctx.rotate(C.lean);
      ctx.globalCompositeOperation = "lighter";
      for (const pts of cracks) {          // the light inside, leaking out
        const a = 0.35 + 0.25 * Math.sin(t * 2 + pts[0].x * 9) + flare * 0.6;
        ctx.strokeStyle = "rgba(255,220,140," + Math.min(1, a) + ")";
        ctx.lineWidth = 1.2 + flare * 1.5;
        ctx.beginPath();
        ctx.moveTo(pts[0].x * C.s, pts[0].y * C.s);
        for (const p of pts) ctx.lineTo(p.x * C.s, Math.max(-C.s, Math.min(0, p.y * C.s)));
        ctx.stroke();
      }
      ctx.restore();
      ctx.globalCompositeOperation = "source-over";
      flare = Math.max(0, flare - dt * 1.6);
    }
  };
});

def("Tension sparks", "aura", "one tick of static now and then; press for the full DBZ crackle", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let tension = 0;
  function arc(cx, cy, r) {
    let px = cx + rand(-r, r), py = cy + rand(-r, r) * 0.7;
    ctx.beginPath();
    ctx.moveTo(px, py);
    for (let i = 0; i < 3; i++) { px += rand(-10, 10); py += rand(-8, 8); ctx.lineTo(px, py); }
    ctx.stroke();
  }
  return {
    press() { tension = 1.4; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      ctx.strokeStyle = "rgba(220,230,255,0.9)";
      ctx.lineWidth = 1.2;
      if (Math.random() < 0.04) arc(C.x, C.y - C.s * 0.5, C.s);          // the lone tick
      if (tension > 0) {
        for (let i = 0; i < 4; i++) if (Math.random() < 0.8) arc(C.x, C.y - C.s * 0.5, C.s * 1.3);
        tension -= dt;
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

/* ============================== MOVEMENT ============================== */

def("Afterimages", "motion", "its past selves trail behind; press for a dash of ghosts", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let ghosts = [], timer = 0, dash = 0;
  return {
    press() {
      if (dash <= 0) { dash = 0.3; C.pace = false; C.vx = C.face * 460; }
    },
    frame(dt, t) {
      stage();
      if (dash > 0) {
        dash -= dt;
        if (C.x < C.s || C.x > W - C.s || dash <= 0) {
          dash = 0; C.pace = true;
          C.x = Math.max(C.s, Math.min(W - C.s, C.x));
        }
      }
      tickCube(dt);
      timer -= dt;
      if (timer <= 0) {                    // snapshot the present for the past
        ghosts.push({ x: C.x, y: C.y, hop: C.hop, lean: C.lean, life: 1 });
        timer = dash > 0 ? 0.02 : 0.12;
      }
      for (const g of ghosts) {
        g.life -= dt * (dash > 0 ? 2 : 1.4);
        if (g.life <= 0) continue;
        ctx.save();
        ctx.globalAlpha = g.life * 0.3;
        ctx.translate(g.x, g.y - g.hop);
        ctx.rotate(g.lean);
        ctx.fillStyle = "#6A63A8";
        ctx.fillRect(-C.s / 2, -C.s, C.s, C.s);
        ctx.restore();
      }
      ghosts = ghosts.filter(g => g.life > 0);
      drawCube();
    }
  };
});

def("Double jump", "motion", "press once to jump — again mid-air for the ring-boost", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let vy = 0, airborne = false, canDouble = false, rings = [];
  return {
    press() {
      if (!airborne) { airborne = true; canDouble = true; vy = -230; }
      else if (canDouble) {                // the second jump: physics forgiven once
        canDouble = false; vy = -230;
        rings.push({ x: C.x, y: C.y, r: 4, life: 1 });
      }
    },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (airborne) {
        vy += 620 * dt;
        C.y += vy * dt;
        if (C.y >= G) { C.y = G; airborne = false; vy = 0; }
      }
      for (const r of rings) {             // the tell-tale double-jump ring
        r.r += 110 * dt; r.life -= dt * 2.2;
        if (r.life > 0) {
          ctx.strokeStyle = "rgba(200,210,255," + r.life * 0.8 + ")";
          ctx.lineWidth = 2;
          ctx.beginPath(); ctx.ellipse(r.x, r.y, r.r, r.r * 0.3, 0, 0, TAU); ctx.stroke();
        }
      }
      rings = rings.filter(r => r.life > 0);
      drawCube();
    }
  };
});

def("Landing dust", "motion", "press: a leap — the landing kicks the honest dust", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let vy = 0, airborne = false, dust = [];
  return {
    press() { if (!airborne) { airborne = true; vy = -300; } },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (airborne) {
        vy += 640 * dt;
        C.y += vy * dt;
        if (C.y >= G) {                    // impact! the dust says how hard
          C.y = G; airborne = false;
          for (let i = 0; i < 12; i++)
            dust.push({ x: C.x + rand(-4, 4), y: G,
                        vx: rand(30, 90) * (i % 2 ? 1 : -1), vy: rand(-60, -10), life: 1 });
          vy = 0;
        }
      } else if (Math.abs(C.vx) > 20 && Math.random() < 0.1)
        dust.push({ x: C.x - C.face * C.s * 0.4, y: G, vx: -C.face * rand(10, 30), vy: rand(-20, -5), life: 0.5 });
      for (const d of dust) {
        d.x += d.vx * dt; d.y += d.vy * dt; d.vy += 60 * dt;
        d.vx *= Math.pow(0.2, dt); d.life -= dt * 1.6;
        if (d.life > 0) {
          ctx.fillStyle = "rgba(160,150,180," + d.life * 0.5 + ")";
          ctx.beginPath(); ctx.arc(d.x, Math.min(d.y, G), 3 * (1.4 - d.life), 0, TAU); ctx.fill();
        }
      }
      dust = dust.filter(d => d.life > 0);
      drawCube();
    }
  };
});

def("Skid smoke", "motion", "watch its turns — every U-turn skids; press for a burnout", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let puffs = [], lastFace = 1, burnout = 0;
  return {
    press() { burnout = 0.8; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (C.face !== lastFace) {           // the moment of the turn = the skid
        lastFace = C.face;
        for (let i = 0; i < 6; i++)
          puffs.push({ x: C.x - C.face * C.s * 0.3, y: G, vx: -C.face * rand(20, 60), vy: rand(-30, -8), life: 1 });
      }
      if (burnout > 0) {
        burnout -= dt;
        puffs.push({ x: C.x + rand(-6, 6), y: G, vx: rand(-40, 40), vy: rand(-40, -10), life: 1 });
      }
      for (const p of puffs) {
        p.x += p.vx * dt; p.y += p.vy * dt;
        p.vx *= Math.pow(0.3, dt); p.life -= dt * 1.2;
        if (p.life > 0) {
          ctx.fillStyle = "rgba(170,165,190," + p.life * 0.4 + ")";
          ctx.beginPath(); ctx.arc(p.x, Math.min(p.y, G), 4 * (1.5 - p.life), 0, TAU); ctx.fill();
        }
      }
      puffs = puffs.filter(p => p.life > 0);
      drawCube();
    }
  };
});

def("Speed lines", "motion", "lines stream behind it as it moves; press: sonic sprint", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let sprint = 0;
  return {
    press() { sprint = 1; },
    frame(dt, t) {
      stage(); tickCube(dt);
      const speed = Math.min(1, Math.abs(C.vx) / 60) + sprint;
      for (let i = 0; i < 5; i++) {        // the lines live where it just was
        const y = C.y - C.s * (0.15 + i * 0.2);
        const len = (6 + i * 3) * speed * (1 + sprint * 2);
        if (len < 2) continue;
        ctx.strokeStyle = "rgba(200,205,240," + (0.2 + speed * 0.3) + ")";
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(C.x - C.face * C.s * 0.6, y);
        ctx.lineTo(C.x - C.face * (C.s * 0.6 + len), y);
        ctx.stroke();
      }
      drawCube();
      sprint = Math.max(0, sprint - dt * 1.4);
    }
  };
});

def("Teleport blink", "motion", "press: it implodes into motes and reappears where you clicked", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let parts = [], phase = 0, target = 0, arriveFlash = 0;
  return {
    press(x) {
      if (phase !== 0) return;
      phase = 1; target = Math.max(C.s, Math.min(W - C.s, x || W - C.x));
      for (let i = 0; i < 16; i++)         // the implosion: the body scatters
        parts.push({ x: C.x + rand(-C.s * 0.5, C.s * 0.5), y: C.y - rand(0, C.s),
                     tx: target, life: 1 });
      C.alpha = 0;
    },
    frame(dt, t) {
      stage(); tickCube(dt);
      ctx.globalCompositeOperation = "lighter";
      if (phase === 1) {
        let arrived = 0;
        for (const p of parts) {           // motes stream to the destination
          p.x += (p.tx - p.x) * dt * 6;
          p.y += ((C.y - C.s * 0.5) - p.y) * dt * 6;
          if (Math.abs(p.x - p.tx) < 6) arrived++;
          glow(p.x, p.y, 4, "rgba(190,180,255,0.8)");
        }
        if (arrived > 12) {                // enough of it has arrived to BE it
          phase = 0; parts = [];
          C.x = target; C.alpha = 1;
          arriveFlash = 1;
        }
      }
      if (arriveFlash > 0) {
        glow(C.x, C.y - C.s * 0.5, C.s * 1.6, "rgba(190,180,255," + arriveFlash * 0.5 + ")");
        arriveFlash = Math.max(0, arriveFlash - dt * 2);
      }
      if (Math.random() < 0.06)            // idle shimmer: it's never QUITE solid
        glow(C.x + rand(-C.s, C.s) * 0.5, C.y - rand(0, C.s), 3, "rgba(190,180,255,0.5)");
      ctx.globalCompositeOperation = "source-over";
      drawCube();
    }
  };
});

def("Backflip", "motion", "press: a full backflip with a ribbon of trail", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let flip = -1, trail = [];
  return {
    press() { if (flip < 0) flip = 0; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (flip >= 0) {
        flip += dt * 1.6;
        const k = Math.min(1, flip);
        C.y = G - Math.sin(k * Math.PI) * C.s * 1.7;
        C.spin = -C.face * k * TAU;        // one full rotation, against travel
        trail.push({ x: C.x, y: C.y - C.s * 0.5, life: 1 });
        if (flip >= 1) { flip = -1; C.y = G; C.spin = 0; }
      }
      for (const p of trail) {
        p.life -= dt * 2;
        if (p.life > 0) glow(p.x, p.y, 5, "rgba(180,200,255," + p.life * 0.4 + ")");
      }
      trail = trail.filter(p => p.life > 0);
      drawCube();
    }
  };
});

def("Wall kick", "motion", "it patrols wall to wall, kicking off each; press: super wall-jump", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let sparks = [], boost = 0, vy = 0;
  return {
    press() { boost = 1; },
    frame(dt, t) {
      stage();
      C.pace = false;                      // this hero runs, it doesn't stroll
      if (C.vx === 0) C.vx = 70;
      C.face = C.vx > 0 ? 1 : -1;
      tickCube(dt);
      if (C.x < C.s * 0.6 || C.x > W - C.s * 0.6) {      // the kick
        C.vx = -C.vx;
        C.x = Math.max(C.s * 0.6, Math.min(W - C.s * 0.6, C.x));
        for (let i = 0; i < 5; i++)
          sparks.push({ x: C.x - Math.sign(C.vx) * C.s * 0.5, y: C.y - rand(0, C.s),
                        vx: Math.sign(C.vx) * rand(30, 80), vy: rand(-40, 10), life: 1 });
        if (boost > 0) { vy = -240; boost = 0; }
      }
      vy += 600 * dt;
      C.y = Math.min(G, C.y + vy * dt);
      if (C.y >= G) vy = 0;
      // the walls themselves, so the kicks read
      ctx.fillStyle = "rgba(120,115,160,0.4)";
      ctx.fillRect(0, G - C.s * 2.4, 4, C.s * 2.4);
      ctx.fillRect(W - 4, G - C.s * 2.4, 4, C.s * 2.4);
      for (const s of sparks) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt * 2;
        if (s.life > 0) { ctx.fillStyle = "rgba(255,220,150," + s.life + ")"; ctx.fillRect(s.x, s.y, 2, 2); }
      }
      sparks = sparks.filter(s => s.life > 0);
      drawCube();
    }
  };
});

/* ============================== IMPACTS & HITS ============================== */

def("Hit spark", "impact", "it shadowboxes; press to land the classic star-flash where you click", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let hits = [], lunge = 0;
  return {
    press(x, y) {
      lunge = 1;
      hits.push({ x: x || C.x + C.face * C.s, y: Math.min(y || C.y - C.s * 0.6, G - 4), life: 1, rot: rand(0, TAU) });
    },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (lunge > 0) { C.lean = C.face * 0.18 * lunge; lunge = Math.max(0, lunge - dt * 4); }
      else if (Math.random() < 0.02) lunge = 0.4;      // the shadowboxing
      drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (const hh of hits) {             // the fighting-game star: 4 long + 4 short
        hh.life -= dt * 3;
        if (hh.life <= 0) continue;
        ctx.fillStyle = "rgba(255,245,200," + hh.life + ")";
        ctx.save();
        ctx.translate(hh.x, hh.y); ctx.rotate(hh.rot);
        ctx.beginPath();
        for (let i = 0; i < 8; i++) {
          const r = i % 2 === 0 ? 16 * (1.4 - hh.life) : 5;
          const th = i / 8 * TAU;
          const px = Math.cos(th) * r, py = Math.sin(th) * r;
          if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        }
        ctx.closePath(); ctx.fill();
        ctx.restore();
      }
      hits = hits.filter(hh => hh.life > 0);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Combo counter", "impact", "press repeatedly — the counter pops bigger with every hit", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let combo = 0, pop = 0, cool = 0;
  return {
    press() { combo++; pop = 1; cool = 1.6; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (cool > 0) { cool -= dt; if (cool <= 0) combo = 0; }   // drop the combo
      if (pop > 0 && combo > 0) C.lean = C.face * 0.15 * pop;
      drawCube();
      if (combo > 0) {
        const scale = 1 + pop * 0.6 + Math.min(combo, 12) * 0.03;
        ctx.save();
        ctx.translate(C.x, C.y - C.s * 1.7);
        ctx.scale(scale, scale);
        ctx.rotate(pop * 0.1 - 0.05);
        ctx.font = "800 14px system-ui, sans-serif";
        ctx.textAlign = "center";
        ctx.lineWidth = 3;
        ctx.strokeStyle = "rgba(40,20,60,0.9)";
        ctx.strokeText(combo + " HIT" + (combo > 1 ? "S!" : "!"), 0, 0);
        ctx.fillStyle = "hsl(" + (45 - Math.min(combo, 12) * 3) + ",95%,65%)";
        ctx.fillText(combo + " HIT" + (combo > 1 ? "S!" : "!"), 0, 0);
        ctx.restore();
      }
      pop = Math.max(0, pop - dt * 4);
    }
  };
});

def("Shockwave punch", "impact", "press: a lunge and a ring of force rolls out ahead", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let rings = [], lunge = 0, shake = 0;
  return {
    press() {
      lunge = 1; shake = 0.7;
      rings.push({ x: C.x + C.face * C.s * 0.9, dir: C.face, r: 6, life: 1 });
    },
    frame(dt, t) {
      stage();
      const sh = shake * shake * 4;
      ctx.save();
      ctx.translate(rand(-sh, sh), rand(-sh, sh));
      tickCube(dt);
      if (lunge > 0) { C.lean = C.face * 0.2 * lunge; lunge = Math.max(0, lunge - dt * 3); }
      drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (const r of rings) {
        r.x += r.dir * 70 * dt; r.r += 100 * dt; r.life -= dt * 1.6;
        if (r.life > 0) {
          ctx.strokeStyle = "rgba(230,225,255," + r.life * 0.8 + ")";
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.ellipse(r.x, C.y - C.s * 0.5, r.r * 0.5, r.r, 0, 0, TAU);
          ctx.stroke();
        }
      }
      rings = rings.filter(r => r.life > 0);
      ctx.globalCompositeOperation = "source-over";
      ctx.restore();
      shake = Math.max(0, shake - dt * 2);
    }
  };
});

def("Block clang", "impact", "press: guard up — the CLANG says the block held", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let block = 0, shards = [];
  return {
    press() {
      block = 1;
      for (let i = 0; i < 6; i++) {        // triangle sparks off the guard
        const th = rand(-1.2, 1.2);
        shards.push({ x: C.x + C.face * C.s * 0.8, y: C.y - C.s * 0.55,
                      vx: C.face * Math.cos(th) * rand(60, 140), vy: Math.sin(th) * 120, rot: rand(0, TAU), life: 1 });
      }
    },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (block > 0) C.lean = -C.face * 0.1 * block;   // braced against it
      drawCube();
      if (block > 0) {                     // the guard plate itself
        ctx.strokeStyle = "rgba(220,225,245," + Math.min(1, block * 1.4) + ")";
        ctx.lineWidth = 3.5;
        ctx.beginPath();
        ctx.moveTo(C.x + C.face * C.s * 0.75, C.y - C.s * 1.05);
        ctx.lineTo(C.x + C.face * C.s * 0.95, C.y - C.s * 0.5);
        ctx.lineTo(C.x + C.face * C.s * 0.75, C.y + 2);
        ctx.stroke();
        block = Math.max(0, block - dt * 1.8);
      }
      for (const s of shards) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 200 * dt; s.rot += 8 * dt; s.life -= dt * 2;
        if (s.life > 0) {
          ctx.save();
          ctx.translate(s.x, s.y); ctx.rotate(s.rot);
          ctx.fillStyle = "rgba(255,240,190," + s.life + ")";
          ctx.beginPath(); ctx.moveTo(0, -4); ctx.lineTo(3, 3); ctx.lineTo(-3, 3); ctx.closePath(); ctx.fill();
          ctx.restore();
        }
      }
      shards = shards.filter(s => s.life > 0);
    }
  };
});

def("Parry flash", "impact", "press: the one-frame white flash every fighting game player knows", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let parry = 0;
  return {
    press() { parry = 1; },
    frame(dt, t) {
      stage();
      // the freeze: while the flash is hot, the WORLD pauses (the cube doesn't tick)
      if (parry < 0.6) tickCube(dt);
      drawCube();
      if (parry > 0) {
        ctx.globalCompositeOperation = "lighter";
        if (parry > 0.6) {                 // frame one: everything goes white-blue
          ctx.fillStyle = "rgba(210,225,255," + (parry - 0.6) * 1.6 + ")";
          ctx.fillRect(0, 0, W, H);
        }
        ctx.strokeStyle = "rgba(190,215,255," + parry + ")";
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.ellipse(C.x + C.face * C.s * 0.6, C.y - C.s * 0.55,
                    (1 - parry) * C.s * 1.6 + 6, ((1 - parry) * C.s * 1.6 + 6) * 1.2, 0, 0, TAU);
        ctx.stroke();
        ctx.globalCompositeOperation = "source-over";
        parry = Math.max(0, parry - dt * 2.4);
      }
    }
  };
});

def("Knockback", "impact", "press: something hits IT — tumble, skid, and a proud recovery", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let tumble = -1, stars = [];
  return {
    press() {
      if (tumble < 0) {
        tumble = 0;
        C.pace = false;
        C.vx = -C.face * 220;              // knocked the way it wasn't looking
        for (let i = 0; i < 5; i++)
          stars.push({ a: rand(0, TAU), life: 1.4 });
      }
    },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (tumble >= 0) {
        tumble += dt;
        C.vx *= Math.pow(0.1, dt);         // the skid
        C.spin = -C.face * Math.min(1, tumble * 2) * TAU;   // the tumble
        C.x = Math.max(C.s, Math.min(W - C.s, C.x));
        if (tumble > 1.1) {                // the recovery pose
          tumble = -1; C.spin = 0; C.pace = true;
        }
      }
      drawCube();
      for (const s of stars) {             // dizzy stars orbit the poor head
        s.a += 5 * dt; s.life -= dt;
        if (s.life > 0) {
          const x = C.x + Math.cos(s.a) * C.s * 0.7;
          const y = C.y - C.s * 1.25 + Math.sin(s.a) * 4;
          twinkle(x, y, 3, "rgba(255,235,150," + Math.min(1, s.life) + ")");
        }
      }
      stars = stars.filter(s => s.life > 0);
    }
  };
});

def("Ground crack", "impact", "press: one punch down — the floor remembers it a while", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let cracks = [], debris = [];
  return {
    press() {
      const cx = C.x + C.face * C.s * 0.7;
      const pts = [];
      for (let i = 0; i < 5; i++) {        // each crack: a ray along the floor
        const dir = rand(0, TAU);
        pts.push({ segs: [[cx, G]], dir: dir });
        let px = cx, py = G;
        for (let k = 0; k < 3; k++) {
          px += Math.cos(dir) * rand(8, 18);
          py = G + Math.abs(Math.sin(dir)) * rand(2, 8) * (k + 1) * 0.4;
          pts[i].segs.push([px, py]);
        }
      }
      cracks.push({ pts: pts, life: 1 });
      for (let i = 0; i < 8; i++)
        debris.push({ x: cx, y: G, vx: rand(-70, 70), vy: rand(-140, -40), life: 1 });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      for (const c of cracks) {
        c.life -= dt * 0.25;               // the floor heals slowly
        if (c.life <= 0) continue;
        ctx.strokeStyle = "rgba(30,26,48," + Math.min(1, c.life * 2) + ")";
        ctx.lineWidth = 2;
        for (const ray of c.pts) {
          ctx.beginPath();
          ctx.moveTo(ray.segs[0][0], ray.segs[0][1]);
          for (const s of ray.segs) ctx.lineTo(s[0], s[1]);
          ctx.stroke();
        }
      }
      cracks = cracks.filter(c => c.life > 0);
      for (const d of debris) {
        d.x += d.vx * dt; d.y += d.vy * dt; d.vy += 300 * dt; d.life -= dt * 1.4;
        if (d.life > 0) { ctx.fillStyle = "rgba(140,130,170," + d.life + ")"; ctx.fillRect(d.x, d.y, 2.5, 2.5); }
      }
      debris = debris.filter(d => d.life > 0);
    }
  };
});

def("Stomp quake", "impact", "press: a stomp sends dust waves rolling both ways", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let waves = [], hop = -1;
  return {
    press() { if (hop < 0) hop = 0; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (hop >= 0) {
        hop += dt * 3;
        C.y = G - Math.sin(Math.min(1, hop) * Math.PI) * C.s * 0.7;
        if (hop >= 1) {
          C.y = G; hop = -1;
          waves.push({ x: C.x, dir: 1, life: 1 });
          waves.push({ x: C.x, dir: -1, life: 1 });
        }
      }
      drawCube();
      for (const w of waves) {             // each wave: a travelling dust hump
        w.x += w.dir * 130 * dt; w.life -= dt * 1.1;
        if (w.life <= 0) continue;
        for (let k = 0; k < 3; k++) {
          ctx.fillStyle = "rgba(160,150,185," + w.life * (0.35 - k * 0.09) + ")";
          ctx.beginPath();
          ctx.arc(w.x - w.dir * k * 6, G - 3 - k, 5 + k * 2, 0, TAU);
          ctx.fill();
        }
      }
      waves = waves.filter(w => w.life > 0);
    }
  };
});

/* ============================== EARTH & NATURE ============================== */

def("Rock throw", "earth", "a pebble orbits, waiting; press to lob the real boulder", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let rocks = [], shards = [];
  return {
    press() {
      rocks.push({ x: C.x + C.face * C.s * 0.5, y: C.y - C.s, vx: C.face * rand(130, 170), vy: -170, rot: 0 });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      const pa = t * 2.4;                  // the loyal pebble
      ctx.fillStyle = "#7A6E5E";
      ctx.beginPath();
      ctx.arc(C.x + Math.cos(pa) * C.s * 0.9, C.y - C.s * 0.6 + Math.sin(pa) * C.s * 0.5, 2.5, 0, TAU);
      ctx.fill();
      for (const r of rocks) {
        r.x += r.vx * dt; r.y += r.vy * dt; r.vy += 340 * dt; r.rot += 4 * dt;
        if (r.y >= G - 4) {                // shatter on landing
          for (let i = 0; i < 8; i++)
            shards.push({ x: r.x, y: G, vx: rand(-80, 80), vy: rand(-120, -30), life: 1 });
          r.y = 1e9;
        } else {
          ctx.save();
          ctx.translate(r.x, r.y); ctx.rotate(r.rot);
          ctx.fillStyle = "#7A6E5E";
          ctx.beginPath();
          ctx.moveTo(-6, -4); ctx.lineTo(5, -6); ctx.lineTo(7, 3); ctx.lineTo(-2, 6); ctx.lineTo(-7, 2);
          ctx.closePath(); ctx.fill();
          ctx.restore();
        }
      }
      rocks = rocks.filter(r => r.y < H);
      for (const s of shards) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 300 * dt; s.life -= dt * 1.5;
        if (s.life > 0) { ctx.fillStyle = "rgba(122,110,94," + s.life + ")"; ctx.fillRect(s.x, s.y, 2.5, 2.5); }
      }
      shards = shards.filter(s => s.life > 0);
    }
  };
});

def("Vine snare", "earth", "press: vines erupt where you click, writhe, and withdraw", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let snares = [];
  return {
    press(x) { snares.push({ x: x || C.x + C.face * C.s * 2, life: 1.6 }); },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      // idle: the leaf it wears
      ctx.fillStyle = "rgba(110,180,110,0.9)";
      ctx.save();
      ctx.translate(C.x + C.s * 0.25, C.y - C.s - C.hop);
      ctx.rotate(0.5 + Math.sin(t * 2) * 0.15);
      ctx.beginPath(); ctx.ellipse(3, 0, 4.5, 2, 0, 0, TAU); ctx.fill();
      ctx.restore();
      for (const sn of snares) {
        sn.life -= dt * 0.7;
        if (sn.life <= 0) continue;
        const up = Math.sin(Math.min(1, (1.6 - sn.life) * 2) * Math.PI * 0.5) * Math.min(1, sn.life * 1.8);
        for (let v = -1; v <= 1; v++) {    // three vines, braided by phase
          ctx.strokeStyle = "rgba(90,160,90," + Math.min(1, sn.life) + ")";
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.moveTo(sn.x + v * 5, G);
          for (let k = 1; k <= 6; k++) {
            const q = k / 6;
            ctx.lineTo(sn.x + v * 5 + Math.sin(q * 5 + t * 6 + v * 2) * 6 * q,
                       G - up * C.s * 1.8 * q);
          }
          ctx.stroke();
        }
      }
      snares = snares.filter(sn => sn.life > 0);
    }
  };
});

def("Leaf whirl", "earth", "leaves orbit like a green satellite belt; press for the storm", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  const leaves = [];
  for (let i = 0; i < 8; i++)
    leaves.push({ a: rand(0, TAU), r: rand(0.9, 1.3), v: rand(1, 1.8), burst: 0 });
  return {
    press() { for (const l of leaves) l.burst = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      for (const l of leaves) {
        l.burst = Math.max(0, l.burst - dt * 0.7);
        l.a += l.v * (1 + l.burst * 3) * dt;
        const r = C.s * l.r * (1 + l.burst * 1.4);
        const x = C.x + Math.cos(l.a) * r;
        const y = C.y - C.s * 0.5 + Math.sin(l.a) * r * 0.55;
        ctx.save();
        ctx.translate(x, y); ctx.rotate(l.a + t);
        ctx.fillStyle = "rgba(120,185,110,0.85)";
        ctx.beginPath(); ctx.ellipse(0, 0, 4, 1.8, 0, 0, TAU); ctx.fill();
        ctx.restore();
      }
    }
  };
});

def("Boulder shield", "earth", "press: four rocks rise and orbit as armour for a while", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let armour = 0;
  return {
    press() { armour = 3; },
    frame(dt, t) {
      stage(); tickCube(dt);
      // idle: a ring of dust at its feet, hinting at the power
      ctx.fillStyle = "rgba(150,135,120,0.15)";
      ctx.beginPath(); ctx.ellipse(C.x, G + 2, C.s * 0.9, 3, 0, 0, TAU); ctx.fill();
      drawCube();
      if (armour > 0) {
        armour -= dt;
        const rise = Math.min(1, (3 - armour) * 3);    // they LIFT into orbit
        for (let i = 0; i < 4; i++) {
          const a = t * 2.2 + i / 4 * TAU;
          const x = C.x + Math.cos(a) * C.s * 1.15;
          const y = C.y - C.s * 0.5 * rise + Math.sin(a) * C.s * 0.5 - (1 - rise) * -10;
          ctx.save();
          ctx.translate(x, y); ctx.rotate(a);
          ctx.fillStyle = "rgba(122,110,94," + Math.min(1, armour) + ")";
          ctx.beginPath();
          ctx.moveTo(-5, -3); ctx.lineTo(4, -5); ctx.lineTo(6, 3); ctx.lineTo(-3, 5);
          ctx.closePath(); ctx.fill();
          ctx.restore();
        }
      }
    }
  };
});

def("Bloom trail", "earth", "flowers open in its footsteps; press for a whole garden at once", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let blooms = [], lastX = null, travelled = 0;
  function bloom(x, big) {
    blooms.push({ x: x, open: 0, hue: rand(300, 360), big: big });
  }
  return {
    press() { for (let i = 0; i < 7; i++) bloom(C.x + rand(-C.s * 2.4, C.s * 2.4), true); },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (lastX === null) lastX = C.x;
      travelled += Math.abs(C.x - lastX);
      lastX = C.x;
      while (travelled > 26) { travelled -= 26; bloom(C.x, false); }   // per step
      for (const b of blooms) {            // petals open, linger, close
        b.open = Math.min(1, b.open + dt * (b.big ? 3 : 1.2));
        const s = (b.big ? 5 : 3.5) * b.open;
        for (let p = 0; p < 5; p++) {
          const th = p / 5 * TAU - Math.PI / 2;
          ctx.fillStyle = "hsla(" + b.hue + ",70%,75%,0.9)";
          ctx.beginPath();
          ctx.ellipse(b.x + Math.cos(th) * s * 0.7, G - 2 + Math.sin(th) * s * 0.4,
                      s * 0.5, s * 0.28, th, 0, TAU);
          ctx.fill();
        }
        ctx.fillStyle = "rgba(255,235,150,0.95)";
        ctx.beginPath(); ctx.arc(b.x, G - 2, s * 0.3, 0, TAU); ctx.fill();
      }
      if (blooms.length > 22) blooms.shift();          // the garden stays tidy
      drawCube();
    }
  };
});

def("Sand kick", "earth", "press: a spray of sand, straight at the opponent's eyes", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let grains = [];
  return {
    press() {
      C.lean = -C.face * 0.15;
      for (let i = 0; i < 24; i++)
        grains.push({ x: C.x + C.face * C.s * 0.4, y: G - 2,
                      vx: C.face * rand(80, 200), vy: rand(-120, -30), life: 1 });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.08)            // idle: sand dribbles off the cube
        grains.push({ x: C.x + rand(-C.s * 0.4, C.s * 0.4), y: C.y - C.s, vx: 0, vy: 20, life: 0.8 });
      for (const g of grains) {
        g.x += g.vx * dt; g.y += g.vy * dt; g.vy += 300 * dt; g.life -= dt * 1.4;
        if (g.y > G) g.y = G;
        if (g.life > 0) { ctx.fillStyle = "rgba(210,185,140," + g.life * 0.8 + ")"; ctx.fillRect(g.x, g.y, 1.6, 1.6); }
      }
      grains = grains.filter(g => g.life > 0);
    }
  };
});

def("Quake slam", "earth", "press: fists down — a hump of ground ROLLS away from it", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let humps = [];
  return {
    press() {
      humps.push({ x: C.x, dir: C.face, life: 1 });
    },
    frame(dt, t) {
      // draw our own floor line so it can DEFORM
      const bumps = humps.filter(hh => hh.life > 0);
      const groundAt = function (x) {
        let y = G;
        for (const hh of bumps) {
          const d = Math.abs(x - hh.x);
          y -= Math.max(0, 10 - d * 0.4) * hh.life;    // the travelling hump
        }
        return y;
      };
      stage();
      ctx.fillStyle = "#1C1830";           // repaint the floor with the wave in it
      ctx.beginPath();
      ctx.moveTo(0, H);
      for (let x = 0; x <= W; x += 4) ctx.lineTo(x, groundAt(x));
      ctx.lineTo(W, H);
      ctx.closePath(); ctx.fill();
      ctx.strokeStyle = "rgba(150,145,190,0.35)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let x = 0; x <= W; x += 4) {
        if (x === 0) ctx.moveTo(x, groundAt(x)); else ctx.lineTo(x, groundAt(x));
      }
      ctx.stroke();
      tickCube(dt);
      C.y = groundAt(C.x);                 // the hero rides its own quake
      drawCube();
      C.y = G;
      for (const hh of humps) { hh.x += hh.dir * 120 * dt; hh.life -= dt * 0.8; }
      humps = humps.filter(hh => hh.life > 0 && hh.x > -20 && hh.x < W + 20);
    }
  };
});

def("Thorn wall", "earth", "press: a fence of thorns rises ahead, holds, and sinks", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let walls = [];
  return {
    press() { walls.push({ x: C.x + C.face * C.s * 1.8, life: 2.2 }); },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      // idle: thorn nubs poking up near its feet
      ctx.strokeStyle = "rgba(110,150,90,0.5)";
      ctx.lineWidth = 1.5;
      for (let i = -1; i <= 1; i++) {
        ctx.beginPath();
        ctx.moveTo(C.x + i * 10, G);
        ctx.lineTo(C.x + i * 10 + 2, G - 4 - Math.sin(t * 2 + i) * 1);
        ctx.stroke();
      }
      for (const w of walls) {
        w.life -= dt * 0.6;
        if (w.life <= 0) continue;
        const up = Math.min(1, Math.min((2.2 - w.life) * 2.4, w.life * 2));
        for (let i = -2; i <= 2; i++) {    // five spikes, tallest centre
          const hgt = (C.s * 1.5 - Math.abs(i) * 6) * up;
          ctx.fillStyle = "rgba(95,140,80," + Math.min(1, w.life) + ")";
          ctx.beginPath();
          ctx.moveTo(w.x + i * 9 - 4, G);
          ctx.lineTo(w.x + i * 9, G - hgt);
          ctx.lineTo(w.x + i * 9 + 4, G);
          ctx.closePath(); ctx.fill();
        }
      }
      walls = walls.filter(w => w.life > 0);
    }
  };
});

/* ============================== PROJECTILES ============================== */

def("Energy ball", "shot", "a palm-flicker while it waits; press to throw the classic orb", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let orbs = [];
  return {
    press() {
      orbs.push({ x: C.x + C.face * C.s * 0.6, y: C.y - C.s * 0.5, vx: C.face * 220, trail: [] });
      C.lean = C.face * 0.15;
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      glow(C.x + C.face * C.s * 0.55, C.y - C.s * 0.45,
           3 + Math.sin(t * 9) * 1.5, "rgba(150,210,255,0.7)");
      for (const o of orbs) {
        o.x += o.vx * dt;
        o.trail.unshift({ x: o.x, y: o.y });
        if (o.trail.length > 10) o.trail.pop();
        for (let i = 0; i < o.trail.length; i++) {
          const k = 1 - i / o.trail.length;
          glow(o.trail[i].x, o.trail[i].y, 5 + k * 6, "rgba(140,205,255," + k * 0.4 + ")");
        }
        glow(o.x, o.y, 9, "rgba(210,235,255,0.95)");
      }
      orbs = orbs.filter(o => o.x > -20 && o.x < W + 20);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Beam blast", "shot", "press: the full-width beam, with charge motes while it idles", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let beam = 0;
  return {
    press() { beam = 0.8; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      if (Math.random() < 0.2)             // charge motes drifting to the palm
        glow(C.x + C.face * C.s * 0.6 + rand(-8, 8), C.y - C.s * 0.5 + rand(-8, 8),
             2.5, "rgba(180,220,255,0.7)");
      if (beam > 0) {
        const hy = C.y - C.s * 0.5;
        const x0 = C.x + C.face * C.s * 0.6;
        const thick = 8 * Math.min(1, beam * 3) * (0.7 + Math.sin(t * 30) * 0.1);
        const grad = ctx.createLinearGradient(x0, 0, x0 + C.face * W, 0);
        grad.addColorStop(0, "rgba(220,240,255,0.95)");
        grad.addColorStop(1, "rgba(140,200,255,0.4)");
        ctx.fillStyle = grad;
        ctx.fillRect(C.face > 0 ? x0 : 0, hy - thick, C.face > 0 ? W - x0 : x0, thick * 2);
        glow(x0, hy, 14 + thick, "rgba(220,240,255,0.9)");
        C.lean = -C.face * 0.12;           // recoil — beams push back
        beam -= dt;
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Homing orbs", "shot", "three orbs idle in orbit; press and they spiral out, then chase forward", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let flying = [];
  return {
    press() {
      for (let i = 0; i < 3; i++)
        flying.push({ x: C.x, y: C.y - C.s * 0.5, a: i / 3 * TAU, spiral: 0.6, dir: C.face, life: 2 });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (let i = 0; i < 3; i++) {        // the standing patrol
        const a = t * 1.8 + i / 3 * TAU;
        glow(C.x + Math.cos(a) * C.s * 0.95, C.y - C.s * 0.5 + Math.sin(a) * C.s * 0.55,
             4, "rgba(255,180,220,0.8)");
      }
      for (const f of flying) {
        if (f.spiral > 0) {                // phase 1: peel away in a spiral
          f.spiral -= dt;
          f.a += 9 * dt;
          f.x += Math.cos(f.a) * 90 * dt;
          f.y += Math.sin(f.a) * 60 * dt;
        } else {                           // phase 2: lock forward and GO
          f.x += f.dir * 240 * dt;
          f.y += (C.y - C.s * 0.5 - f.y) * dt * 2;
        }
        f.life -= dt;
        if (f.life > 0) glow(f.x, f.y, 6, "rgba(255,190,225,0.9)");
      }
      flying = flying.filter(f => f.life > 0 && f.x > -20 && f.x < W + 20);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Boomerang", "shot", "press: the glaive flies out, hangs, and comes home", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let flight = null;
  return {
    press() {
      if (!flight) flight = { p: 0, dir: C.face };
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (flight) {
        flight.p += dt * 0.9;
        const k = flight.p;                // out fast, hover, return — one cosine
        const reach = Math.sin(Math.min(1, k) * Math.PI) * C.s * 3.2;
        const x = C.x + flight.dir * reach;
        const y = C.y - C.s * 0.6 - Math.sin(Math.min(1, k) * TAU) * 8;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(t * 16);
        ctx.strokeStyle = "rgba(220,225,245,0.95)";
        ctx.lineWidth = 3;
        ctx.beginPath();                   // the glaive: a bent bar
        ctx.moveTo(-7, 3); ctx.lineTo(0, -5); ctx.lineTo(7, 3);
        ctx.stroke();
        ctx.restore();
        if (flight.p >= 1) flight = null;  // caught!
      } else {
        // idle: a glint on the stowed glaive at its hip
        ctx.strokeStyle = "rgba(220,225,245," + (0.5 + Math.sin(t * 3) * 0.3) + ")";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(C.x - C.face * C.s * 0.4 - 4, C.y - C.s * 0.3);
        ctx.lineTo(C.x - C.face * C.s * 0.4 + 4, C.y - C.s * 0.34);
        ctx.stroke();
      }
    }
  };
});

def("Laser sight", "shot", "a thin aiming line flickers ahead; press for the railgun crack", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let shot = 0;
  return {
    press() { shot = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      const hy = C.y - C.s * 0.55;
      const x0 = C.x + C.face * C.s * 0.55;
      ctx.globalCompositeOperation = "lighter";
      if (shot <= 0) {                     // the patient red line
        ctx.strokeStyle = "rgba(255,90,90," + (0.25 + Math.sin(t * 7) * 0.12) + ")";
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(x0, hy);
        ctx.lineTo(C.face > 0 ? W : 0, hy);
        ctx.stroke();
        glow(C.face > 0 ? W - 4 : 4, hy, 3, "rgba(255,120,120,0.6)");
      } else {                             // the crack: everything at once
        ctx.strokeStyle = "rgba(255,230,230," + shot + ")";
        ctx.lineWidth = 1 + shot * 5;
        ctx.beginPath();
        ctx.moveTo(x0, hy);
        ctx.lineTo(C.face > 0 ? W : 0, hy);
        ctx.stroke();
        glow(x0, hy, 12, "rgba(255,200,200," + shot + ")");
        shot = Math.max(0, shot - dt * 3);
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Charge shot", "shot", "the orb at its palm GROWS while you wait; press to fire what you saved", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let charge = 0.15, shots = [];
  return {
    press() {
      shots.push({ x: C.x + C.face * C.s * 0.6, y: C.y - C.s * 0.5,
                   vx: C.face * 200, r: 4 + charge * 14 });
      charge = 0.15;                       // patience spent; start saving again
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      charge = Math.min(1, charge + dt * 0.18);
      ctx.globalCompositeOperation = "lighter";
      glow(C.x + C.face * C.s * 0.6, C.y - C.s * 0.5,
           3 + charge * 12 + Math.sin(t * 10) * charge * 2,
           "rgba(170,255,190," + (0.4 + charge * 0.5) + ")");
      for (const s of shots) {
        s.x += s.vx * dt;
        glow(s.x, s.y, s.r, "rgba(190,255,205,0.9)");
      }
      shots = shots.filter(s => s.x > -30 && s.x < W + 30);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Spread shot", "shot", "press: a five-way fan; idle: one pellet bounces in its hand", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let pellets = [];
  return {
    press() {
      for (let i = -2; i <= 2; i++) {
        const th = i * 0.22;
        pellets.push({ x: C.x + C.face * C.s * 0.6, y: C.y - C.s * 0.55,
                       vx: C.face * Math.cos(th) * 210, vy: Math.sin(th) * 210, life: 1.4 });
      }
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      glow(C.x + C.face * C.s * 0.55, C.y - C.s * 0.45 - Math.abs(Math.sin(t * 5)) * 4,
           2.5, "rgba(255,220,150,0.8)");
      for (const p of pellets) {
        p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt;
        if (p.life > 0) glow(p.x, p.y, 4, "rgba(255,225,160,0.9)");
      }
      pellets = pellets.filter(p => p.life > 0 && p.x > -10 && p.x < W + 10);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Orbit launch", "shot", "four shards circle on duty; press launches them one — by — one", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  const shards = [0, 1, 2, 3].map(i => ({ ph: i / 4 * TAU, state: 0, x: 0, y: 0, delay: 0 }));
  return {
    press() {
      let d = 0;
      for (const s of shards)
        if (s.state === 0) { s.state = 1; s.delay = d; d += 0.15; }
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (const s of shards) {
        if (s.state === 0) {               // on duty
          const a = t * 2 + s.ph;
          s.x = C.x + Math.cos(a) * C.s * 1.05;
          s.y = C.y - C.s * 0.5 + Math.sin(a) * C.s * 0.6;
          glow(s.x, s.y, 4, "rgba(200,190,255,0.85)");
        } else {                           // countdown, then away
          s.delay -= dt;
          if (s.delay <= 0) s.x += C.face * 280 * dt;
          glow(s.x, s.y, 5, "rgba(220,210,255,0.95)");
          if (s.x < -12 || s.x > W + 12) { s.state = 0; }   // rejoin the orbit
        }
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

/* ============================== ICE ============================== */

def("Ice shards", "ice", "frost breath while it waits; press for the shard volley", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let shards = [], breath = 0;
  return {
    press() {
      for (let i = 0; i < 5; i++)
        shards.push({ x: C.x + C.face * C.s * 0.5, y: C.y - C.s * 0.6 + rand(-6, 6),
                      vx: C.face * rand(180, 240), vy: rand(-20, 20), rot: 0, life: 1.2 });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      breath += dt;
      if (breath > 2.4) breath = 0;
      if (breath < 0.6)                    // a visible cold exhale, every so often
        for (let i = 0; i < 2; i++)
          glow(C.x + C.face * (C.s * 0.5 + breath * 30 + rand(0, 6)),
               C.y - C.s * 0.6 + rand(-4, 4), 4, "rgba(200,235,255,0.14)");
      for (const s of shards) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.rot += 6 * dt; s.life -= dt;
        if (s.life > 0) {
          ctx.save();
          ctx.translate(s.x, s.y); ctx.rotate(s.rot);
          ctx.fillStyle = "rgba(190,225,255,0.9)";
          ctx.beginPath(); ctx.moveTo(6, 0); ctx.lineTo(-4, 2.5); ctx.lineTo(-4, -2.5); ctx.closePath(); ctx.fill();
          ctx.restore();
        }
      }
      shards = shards.filter(s => s.life > 0 && s.x > -10 && s.x < W + 10);
    }
  };
});

def("Frost armor", "ice", "press to TOGGLE the armor — an ice shell with honest glints", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let on = false;
  return {
    press() { on = !on; },
    frame(dt, t) {
      stage(); tickCube(dt);
      C.tint = on ? "#3E5A80" : null;
      drawCube();
      C.tint = null;
      if (on) {
        ctx.strokeStyle = "rgba(200,235,255,0.8)";     // the shell outline
        ctx.lineWidth = 2.5;
        ctx.save();
        ctx.translate(C.x, C.y - C.hop);
        ctx.rotate(C.lean);
        ctx.strokeRect(-C.s / 2 - 3, -C.s - 3, C.s + 6, C.s + 6);
        ctx.restore();
        if (Math.random() < 0.1)           // armour glint
          twinkle(C.x + rand(-C.s, C.s) * 0.5, C.y - rand(0, C.s), 3, "rgba(255,255,255,0.9)");
      }
    }
  };
});

def("Freeze stomp", "ice", "press: ice crystallises across the floor from its feet", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let sheets = [];
  return {
    press() { sheets.push({ x: C.x, spread: 4, life: 1 }); },
    frame(dt, t) {
      stage(); tickCube(dt);
      for (const sh of sheets) {
        sh.spread += 110 * dt;             // the crystallisation front
        sh.life -= dt * 0.35;
        if (sh.life <= 0) continue;
        const a = Math.min(1, sh.life * 2) * 0.5;
        ctx.fillStyle = "rgba(170,215,250," + a * 0.5 + ")";
        ctx.fillRect(sh.x - sh.spread, G, sh.spread * 2, 5);
        ctx.strokeStyle = "rgba(210,240,255," + a + ")";
        ctx.lineWidth = 1;
        for (let x = -sh.spread; x < sh.spread; x += 14) {   // frost teeth
          ctx.beginPath();
          ctx.moveTo(sh.x + x, G);
          ctx.lineTo(sh.x + x + 4, G - rand(3, 8) * Math.min(1, sh.life * 2));
          ctx.lineTo(sh.x + x + 8, G);
          ctx.stroke();
        }
      }
      sheets = sheets.filter(sh => sh.life > 0);
      drawCube();
    }
  };
});

def("Snow aura", "ice", "its own private snowfall; press for the flurry", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let flakes = [], flurry = 0;
  return {
    press() { flurry = 1.4; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.25 + (flurry > 0 ? 0.6 : 0))
        flakes.push({ x: C.x + rand(-C.s * 1.4, C.s * 1.4), y: C.y - C.s * 2, ph: rand(0, 9), life: 1 });
      for (const f of flakes) {
        f.y += 32 * dt;
        f.x += Math.sin(t * 2 + f.ph) * 10 * dt + (C.x - f.x) * dt * 0.4;   // it follows, loosely
        f.life -= dt * 0.5;
        if (f.life > 0 && f.y < G) {
          ctx.fillStyle = "rgba(235,245,255," + f.life * 0.8 + ")";
          ctx.beginPath(); ctx.arc(f.x, f.y, 1.5, 0, TAU); ctx.fill();
        }
      }
      flakes = flakes.filter(f => f.life > 0 && f.y < G);
      flurry = Math.max(0, flurry - dt);
    }
  };
});

def("Icicle drop", "ice", "press: icicles form in the air where you click, then fall and shatter", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let icicles = [], bits = [];
  return {
    press(x, y) {
      for (let i = 0; i < 3; i++)
        icicles.push({ x: (x || C.x) + (i - 1) * 12, y: Math.min(y || 30, G - 40),
                       form: 0, vy: 0 });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      for (const ic of icicles) {
        if (ic.form < 1) { ic.form += dt * 2.4; }        // materialise first…
        else { ic.vy += 500 * dt; ic.y += ic.vy * dt; }  // …then physics applies
        if (ic.y >= G - 6) {
          for (let i = 0; i < 5; i++)
            bits.push({ x: ic.x, y: G, vx: rand(-60, 60), vy: rand(-90, -20), life: 1 });
          ic.y = 1e9;
        } else {
          ctx.fillStyle = "rgba(190,225,255," + 0.9 * Math.min(1, ic.form) + ")";
          ctx.beginPath();
          ctx.moveTo(ic.x - 3, ic.y); ctx.lineTo(ic.x + 3, ic.y);
          ctx.lineTo(ic.x, ic.y + 12 * ic.form);
          ctx.closePath(); ctx.fill();
        }
      }
      icicles = icicles.filter(ic => ic.y < H);
      for (const b of bits) {
        b.x += b.vx * dt; b.y += b.vy * dt; b.vy += 280 * dt; b.life -= dt * 1.6;
        if (b.life > 0) { ctx.fillStyle = "rgba(210,240,255," + b.life + ")"; ctx.fillRect(b.x, b.y, 2, 2); }
      }
      bits = bits.filter(b => b.life > 0);
    }
  };
});

def("Glacial wall", "ice", "press: a wall of ice rises ahead — then melts, drip by drip", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let walls = [], drips = [];
  return {
    press() { walls.push({ x: C.x + C.face * C.s * 1.9, life: 3 }); },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      for (const w of walls) {
        w.life -= dt * 0.7;
        if (w.life <= 0) continue;
        const up = Math.min(1, (3 - w.life) * 3);
        const melt = Math.min(1, w.life);  // height fades as it melts
        const hgt = C.s * 1.6 * up * melt;
        ctx.fillStyle = "rgba(160,205,245,0.5)";
        ctx.fillRect(w.x - 12, G - hgt, 24, hgt);
        ctx.strokeStyle = "rgba(220,240,255,0.7)";
        ctx.lineWidth = 1.5;
        ctx.strokeRect(w.x - 12, G - hgt, 24, hgt);
        if (Math.random() < 0.3)
          drips.push({ x: w.x + rand(-12, 12), y: G - rand(0, hgt), life: 1 });
      }
      walls = walls.filter(w => w.life > 0);
      for (const d of drips) {
        d.y += 60 * dt; d.life -= dt * 2;
        if (d.life > 0 && d.y < G) {
          ctx.fillStyle = "rgba(190,225,250," + d.life + ")";
          ctx.fillRect(d.x, d.y, 1.5, 3);
        }
      }
      drips = drips.filter(d => d.life > 0 && d.y < G);
    }
  };
});

/* ============================== WIND ============================== */

def("Tornado spin", "wind", "press: it spins itself into a travelling funnel", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let storm = 0;
  return {
    press() {
      if (storm <= 0) { storm = 1; C.pace = false; C.vx = C.face * 160; }
    },
    frame(dt, t) {
      stage();
      if (storm > 0) {
        storm -= dt * 0.7;
        C.spin += dt * 22;                 // the cube IS the tornado core
        if (C.x < C.s || C.x > W - C.s) C.vx = -C.vx;
        if (storm <= 0) { C.pace = true; C.spin = 0; C.vx = 0; }
      }
      tickCube(dt); drawCube();
      if (storm > 0) {
        for (let i = 0; i < 8; i++) {      // the funnel wrapped around it
          const k = i / 7;
          const y = C.y - k * C.s * 1.9;
          const r = (C.s * 0.4 + k * C.s * 0.8);
          const a = t * 12 + i;
          ctx.strokeStyle = "rgba(190,205,225," + (0.5 - k * 0.2) * Math.min(1, storm * 2) + ")";
          ctx.lineWidth = 1.6;
          ctx.beginPath();
          ctx.ellipse(C.x, y, r, r * 0.3, 0, a, a + 3.6);
          ctx.stroke();
        }
      } else if (Math.random() < 0.1) {    // idle breeze lines
        const y = rand(G * 0.3, G * 0.9);
        ctx.strokeStyle = "rgba(180,195,220,0.25)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(rand(0, W * 0.7), y);
        ctx.lineTo(rand(0, W * 0.7) + 24, y - 2);
        ctx.stroke();
      }
    }
  };
});

def("Gust palm", "wind", "press: rings of pushed air roll forward — force you can almost see", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let rings = [];
  return {
    press() {
      for (let i = 0; i < 3; i++)
        rings.push({ x: C.x + C.face * C.s * 0.7, dir: C.face, r: 5 + i * 3, delay: i * 0.08, life: 1 });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      // idle: sleeve-flutter streaks off its trailing edge
      if (Math.abs(C.vx) > 15 && Math.random() < 0.3) {
        ctx.strokeStyle = "rgba(190,205,225,0.3)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(C.x - C.face * C.s * 0.5, C.y - rand(4, C.s * 0.8));
        ctx.lineTo(C.x - C.face * (C.s * 0.5 + 10), C.y - rand(4, C.s * 0.8));
        ctx.stroke();
      }
      for (const r of rings) {
        r.delay -= dt;
        if (r.delay > 0) continue;
        r.x += r.dir * 190 * dt; r.r += 30 * dt; r.life -= dt * 1.6;
        if (r.life > 0) {
          ctx.strokeStyle = "rgba(205,218,235," + r.life * 0.6 + ")";
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.ellipse(r.x, C.y - C.s * 0.55, r.r * 0.4, r.r, 0, 0, TAU);
          ctx.stroke();
        }
      }
      rings = rings.filter(r => r.life > 0);
    }
  };
});

def("Cyclone jump", "wind", "press: a spiral of wind corkscrews it upward, then sets it down", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let lift = -1, streaks = [];
  return {
    press() { if (lift < 0) lift = 0; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (lift >= 0) {
        lift += dt * 1.1;
        C.y = G - Math.sin(Math.min(1, lift) * Math.PI) * C.s * 2.2;
        for (let i = 0; i < 2; i++) {      // the corkscrew written in streaks
          const a = t * 14 + i * Math.PI;
          streaks.push({ x: C.x + Math.cos(a) * C.s * 0.8, y: C.y - rand(0, C.s), life: 0.5 });
        }
        if (lift >= 1) { lift = -1; C.y = G; }
      }
      for (const s of streaks) {
        s.y -= 30 * dt; s.life -= dt * 1.8;
        if (s.life > 0) {
          ctx.strokeStyle = "rgba(200,215,235," + s.life + ")";
          ctx.lineWidth = 1.4;
          ctx.beginPath(); ctx.moveTo(s.x - 5, s.y); ctx.lineTo(s.x + 5, s.y - 2); ctx.stroke();
        }
      }
      streaks = streaks.filter(s => s.life > 0);
      drawCube();
    }
  };
});

def("Wind cloak", "wind", "curved streams orbit it always; press flares the cloak into a deflect", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let deflect = 0;
  return {
    press() { deflect = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      for (let i = 0; i < 4; i++) {        // the cloak: four orbiting streams
        const a = t * 2 + i / 4 * TAU;
        const r = C.s * (0.95 + deflect * 0.7);
        ctx.strokeStyle = "rgba(195,210,232," + (0.35 + deflect * 0.45) + ")";
        ctx.lineWidth = 1.6 + deflect;
        ctx.beginPath();
        ctx.ellipse(C.x, C.y - C.s * 0.5, r, r * 0.55, 0, a, a + 1.2);
        ctx.stroke();
      }
      deflect = Math.max(0, deflect - dt * 1.4);
    }
  };
});

def("Air slash", "wind", "press: crescent blades of wind fly forward", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let blades = [];
  return {
    press() {
      for (let i = 0; i < 2; i++)
        blades.push({ x: C.x + C.face * C.s * 0.6, y: C.y - C.s * 0.55 + i * 8 - 4,
                      dir: C.face, delay: i * 0.1, life: 1 });
    },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      // idle: the blade shimmer at its side
      ctx.strokeStyle = "rgba(210,225,240," + (0.3 + Math.sin(t * 4) * 0.15) + ")";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(C.x - C.face * C.s * 0.45, C.y - C.s * 0.4, 6, -1.2, 1.2);
      ctx.stroke();
      for (const b of blades) {
        b.delay -= dt;
        if (b.delay > 0) continue;
        b.x += b.dir * 260 * dt; b.life -= dt * 1.2;
        if (b.life > 0) {
          ctx.strokeStyle = "rgba(215,228,245," + b.life * 0.9 + ")";
          ctx.lineWidth = 2.5;
          ctx.beginPath();                 // the crescent: an arc leaning forward
          ctx.arc(b.x - b.dir * 8, b.y, 11, b.dir > 0 ? -0.9 : Math.PI - 0.9, b.dir > 0 ? 0.9 : Math.PI + 0.9);
          ctx.stroke();
        }
      }
      blades = blades.filter(b => b.life > 0 && b.x > -14 && b.x < W + 14);
    }
  };
});

def("Updraft column", "wind", "press: a column of rising air where you click; idle: drifting down", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let columns = [], feathers = [];
  return {
    press(x) { columns.push({ x: x || C.x, life: 1.6 }); },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.03)            // a feather, falling as feathers do
        feathers.push({ x: rand(10, W - 10), y: -4, ph: rand(0, 9) });
      for (const f of feathers) {
        let vy = 26;
        for (const c of columns)           // the column argues with gravity
          if (Math.abs(f.x - c.x) < 16 && c.life > 0) vy = -110;
        f.y += vy * dt;
        f.x += Math.sin(t * 2 + f.ph) * 12 * dt;
        ctx.save();
        ctx.translate(f.x, f.y);
        ctx.rotate(Math.sin(t * 3 + f.ph) * 0.5);
        ctx.fillStyle = "rgba(230,235,245,0.8)";
        ctx.beginPath(); ctx.ellipse(0, 0, 3.5, 1.3, 0, 0, TAU); ctx.fill();
        ctx.restore();
      }
      feathers = feathers.filter(f => f.y > -12 && f.y < G);
      for (const c of columns) {
        c.life -= dt * 0.7;
        if (c.life <= 0) continue;
        for (let i = 0; i < 3; i++) {      // the visible rising strands
          const x = c.x + Math.sin(t * 8 + i * 2) * 6;
          const y = G - ((t * 130 + i * 40) % (G * 0.8));
          ctx.strokeStyle = "rgba(200,215,235," + Math.min(1, c.life) * 0.4 + ")";
          ctx.lineWidth = 1.4;
          ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + 2, y - 12); ctx.stroke();
        }
      }
      columns = columns.filter(c => c.life > 0);
    }
  };
});

/* ============================== DARK & VOID ============================== */

def("Shadow clone", "dark", "a dark twin mimics it, a beat late; press sends the twin ahead", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let history = [], attack = -1, ax = 0;
  return {
    press() { if (attack < 0) { attack = 0; ax = C.x; } },
    frame(dt, t) {
      stage(); tickCube(dt);
      history.push({ x: C.x, hop: C.hop, lean: C.lean });
      if (history.length > 30) history.shift();
      let cx, chop, clean;
      if (attack >= 0) {                   // the clone's independent lunge
        attack += dt * 1.4;
        ax += C.face * 260 * dt;
        cx = ax; chop = 0; clean = C.face * 0.2;
        if (attack >= 1) attack = -1;
      } else {
        const past = history[0];           // living half a second in the past
        cx = past.x; chop = past.hop; clean = past.lean;
      }
      ctx.save();                          // the twin, in silhouette
      ctx.globalAlpha = attack >= 0 ? Math.max(0, 1 - attack) * 0.8 : 0.55;
      ctx.translate(cx, C.y - chop);
      ctx.rotate(clean);
      ctx.fillStyle = "#181228";
      ctx.fillRect(-C.s / 2, -C.s, C.s, C.s);
      ctx.fillStyle = "rgba(180,120,255,0.8)";           // its eyes give it away
      ctx.fillRect(-C.s * 0.15, -C.s * 0.66, 2.5, 4);
      ctx.fillRect(C.s * 0.1, -C.s * 0.66, 2.5, 4);
      ctx.restore();
      drawCube();
    }
  };
});

def("Void grasp", "dark", "its shadow writhes; press and a dark hand rises where you click", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let hands = [];
  return {
    press(x) { hands.push({ x: x || C.x + C.face * C.s * 2, life: 1.6 }); },
    frame(dt, t) {
      stage(); tickCube(dt);
      // the writhing shadow: its ellipse breathes wrong
      ctx.fillStyle = "rgba(10,6,20,0.55)";
      ctx.beginPath();
      ctx.ellipse(C.x + Math.sin(t * 3) * 3, G + 2,
                  C.s * (0.6 + Math.sin(t * 2.3) * 0.15), 4 + Math.sin(t * 3.7) * 1.5, 0, 0, TAU);
      ctx.fill();
      drawCube();
      for (const hd of hands) {
        hd.life -= dt * 0.7;
        if (hd.life <= 0) continue;
        const up = Math.sin(Math.min(1, (1.6 - hd.life) * 2) * Math.PI * 0.5) * Math.min(1, hd.life * 2);
        ctx.strokeStyle = "rgba(30,18,50," + Math.min(1, hd.life * 1.5) + ")";
        ctx.lineWidth = 5;
        ctx.lineCap = "round";
        ctx.beginPath();                   // the wrist
        ctx.moveTo(hd.x, G);
        ctx.lineTo(hd.x, G - C.s * 1.1 * up);
        ctx.stroke();
        ctx.lineWidth = 2.5;
        for (let f = -2; f <= 2; f++) {    // five grasping fingers
          ctx.beginPath();
          ctx.moveTo(hd.x, G - C.s * 1.1 * up);
          ctx.quadraticCurveTo(hd.x + f * 5, G - C.s * (1.1 + 0.3) * up,
                               hd.x + f * 6, G - C.s * (1.1 + 0.15) * up + Math.sin(t * 6 + f) * 2);
          ctx.stroke();
        }
      }
      hands = hands.filter(hd => hd.life > 0);
    }
  };
});

def("Dark aura", "dark", "purple smoke coils off it; press for the eruption", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let parts = [], erupt = 0;
  return {
    press() { erupt = 1; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (Math.random() < 0.4 + erupt)
        parts.push({ x: C.x + rand(-C.s * 0.6, C.s * 0.6), y: C.y - rand(0, C.s),
                     r: rand(3, 6) * (1 + erupt), life: 1 });
      for (const p of parts) {
        p.y -= (26 + erupt * 60) * dt;
        p.x += Math.sin(p.y * 0.15) * 10 * dt;
        p.r += 4 * dt; p.life -= dt;
        if (p.life > 0) {
          ctx.fillStyle = "rgba(70,30,110," + p.life * 0.35 + ")";
          ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, TAU); ctx.fill();
        }
      }
      parts = parts.filter(p => p.life > 0);
      drawCube();
      erupt = Math.max(0, erupt - dt * 1.2);
    }
  };
});

def("Smoke vanish", "dark", "press: a poof of smoke — and no cube until it clears", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let puffs = [], gone = 0;
  return {
    press() {
      gone = 1;
      C.alpha = 0;
      for (let i = 0; i < 12; i++)
        puffs.push({ x: C.x + rand(-C.s * 0.5, C.s * 0.5), y: C.y - rand(0, C.s),
                     vx: rand(-40, 40), vy: rand(-50, -10), r: rand(5, 9), life: 1 });
    },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (gone > 0) {
        gone -= dt * 0.8;
        if (gone <= 0) {                   // the reappearance gets its own poof
          C.alpha = 1;
          for (let i = 0; i < 8; i++)
            puffs.push({ x: C.x + rand(-C.s * 0.4, C.s * 0.4), y: C.y - rand(0, C.s),
                         vx: rand(-25, 25), vy: rand(-30, -8), r: rand(4, 7), life: 0.8 });
        }
      } else if (Math.random() < 0.04)
        puffs.push({ x: C.x - C.face * C.s * 0.4, y: C.y - 4, vx: 0, vy: -12, r: 3, life: 0.7 });
      for (const p of puffs) {
        p.x += p.vx * dt; p.y += p.vy * dt; p.r += 6 * dt; p.life -= dt * 1.1;
        if (p.life > 0) {
          ctx.fillStyle = "rgba(60,55,80," + p.life * 0.5 + ")";
          ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, TAU); ctx.fill();
        }
      }
      puffs = puffs.filter(p => p.life > 0);
      drawCube();
    }
  };
});

def("Black hole", "dark", "press: a void opens ahead — everything leans toward it", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let hole = null, motes = [];
  return {
    press() { if (!hole) hole = { x: C.x + C.face * C.s * 2.4, y: C.y - C.s * 0.7, life: 2 }; },
    frame(dt, t) {
      stage(); tickCube(dt);
      if (hole) {
        if (Math.random() < 0.5)
          motes.push({ x: hole.x + rand(-C.s * 2, C.s * 2), y: hole.y + rand(-C.s, C.s), life: 1 });
        C.lean = Math.sign(hole.x - C.x) * 0.12;   // even the hero leans in
      }
      drawCube();
      if (hole) {
        for (const m of motes) {           // the infall
          m.x += (hole.x - m.x) * dt * 4;
          m.y += (hole.y - m.y) * dt * 4;
          m.life -= dt * 1.3;
          if (m.life > 0) { ctx.fillStyle = "rgba(170,140,220," + m.life * 0.7 + ")"; ctx.fillRect(m.x, m.y, 1.8, 1.8); }
        }
        motes = motes.filter(m => m.life > 0);
        ctx.fillStyle = "#050308";         // the void itself
        ctx.beginPath(); ctx.ellipse(hole.x, hole.y, 9, 9 * 0.7, 0, 0, TAU); ctx.fill();
        ctx.strokeStyle = "rgba(190,150,255,0.7)";
        ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.ellipse(hole.x, hole.y, 11, 7.5, 0, 0, TAU); ctx.stroke();
        hole.life -= dt;
        if (hole.life <= 0) { hole = null; motes = []; }
      }
    }
  };
});

def("Night veil", "dark", "the dark closes in — light survives only near the hero; press widens it", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let reach = 0;
  return {
    press() { reach = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      const r = C.s * (2 + reach * 1.8 + Math.sin(t * 1.2) * 0.15);
      // the veil: darkness everywhere except a soft circle around the cube
      const g = ctx.createRadialGradient(C.x, C.y - C.s * 0.5, r * 0.5, C.x, C.y - C.s * 0.5, r);
      g.addColorStop(0, "rgba(5,3,10,0)");
      g.addColorStop(1, "rgba(5,3,10,0.88)");
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, W, H);
      reach = Math.max(0, reach - dt * 0.5);
    }
  };
});

/* ============================== DECORATIONS ============================== */

def("Butterflies", "decor", "three companions flutter along; press and they scatter, then forgive", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  const flies = [];
  for (let i = 0; i < 3; i++)
    flies.push({ x: rand(0, 200), y: rand(20, 80), ph: rand(0, 9), panic: 0,
                 hue: [330, 45, 200][i] });
  return {
    press() { for (const f of flies) f.panic = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      for (const f of flies) {
        f.panic = Math.max(0, f.panic - dt * 0.5);
        const tx = C.x + Math.sin(t * 0.8 + f.ph * 3) * C.s * 1.6;
        const ty = C.y - C.s * 1.2 + Math.sin(t * 1.3 + f.ph) * 14;
        const chase = f.panic > 0 ? -3 : 1.6;          // scatter = chase reversed
        f.x += (tx - f.x) * dt * chase + Math.sin(t * 9 + f.ph) * 14 * dt;
        f.y += (ty - f.y) * dt * chase - f.panic * 40 * dt;
        f.y = Math.max(8, Math.min(G - 8, f.y));
        f.x = Math.max(4, Math.min(W - 4, f.x));
        const flap = Math.sin(t * 16 + f.ph) * 0.8;    // the wings
        for (const side of [-1, 1]) {
          ctx.fillStyle = "hsla(" + f.hue + ",75%,72%,0.9)";
          ctx.beginPath();
          ctx.ellipse(f.x + side * 2.4, f.y, 3, 1.6 + Math.abs(flap), side * flap, 0, TAU);
          ctx.fill();
        }
      }
    }
  };
});

def("Floating lanterns", "decor", "lanterns climb the night; press to release a fresh batch", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let lanterns = [];
  function release(n, fromCube) {
    for (let i = 0; i < n; i++)
      lanterns.push({ x: fromCube ? C.x + rand(-6, 6) : rand(20, W - 20),
                      y: fromCube ? C.y - C.s : G - rand(0, 30),
                      ph: rand(0, 9), life: 1 });
  }
  release(4, false);
  return {
    press() { release(3, true); },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (const l of lanterns) {
        l.y -= 14 * dt;
        l.x += Math.sin(t * 0.7 + l.ph) * 8 * dt;
        if (l.y < 14) l.life -= dt;
        glow(l.x, l.y, 8, "rgba(255,180,90," + Math.min(1, l.life) * 0.5 + ")");
        ctx.fillStyle = "rgba(255,150,70," + Math.min(1, l.life) * 0.85 + ")";
        ctx.fillRect(l.x - 2.5, l.y - 4, 5, 7);
      }
      lanterns = lanterns.filter(l => l.life > 0);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Petal fall", "decor", "cherry petals cross the stage; press for a spiral flurry", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let petals = [], spiral = 0;
  return {
    press() { spiral = 1.2; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.15 + (spiral > 0 ? 0.5 : 0))
        petals.push({ x: rand(-10, W), y: -4, ph: rand(0, 9), rot: rand(0, TAU) });
      for (const p of petals) {
        if (spiral > 0) {                  // the flurry: petals orbit the hero
          const a = Math.atan2(p.y - (C.y - C.s), p.x - C.x) + dt * 4;
          const d = Math.hypot(p.x - C.x, p.y - (C.y - C.s));
          p.x = C.x + Math.cos(a) * d * (1 - dt * 0.3);
          p.y = (C.y - C.s) + Math.sin(a) * d * (1 - dt * 0.3);
        } else {
          p.y += 22 * dt;
          p.x += (14 + Math.sin(t * 2 + p.ph) * 10) * dt;
        }
        p.rot += dt * 2;
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.rot);
        ctx.fillStyle = "rgba(255,190,210,0.85)";
        ctx.beginPath(); ctx.ellipse(0, 0, 3, 1.8, 0, 0, TAU); ctx.fill();
        ctx.restore();
      }
      petals = petals.filter(p => p.y < G && p.x < W + 14);
      spiral = Math.max(0, spiral - dt);
    }
  };
});

def("Fireflies at dusk", "decor", "they gather near whoever stands still; press = one shared flash", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let sync = 0;
  const flies = [];
  for (let i = 0; i < 9; i++)
    flies.push({ x: rand(0, 200), y: rand(20, 100), ph: rand(0, TAU), sp: rand(0.6, 1.3), wx: rand(0, 9) });
  return {
    press() { sync = 1; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      ctx.globalCompositeOperation = "lighter";
      for (const f of flies) {
        f.x += (C.x + Math.sin(f.wx * 3) * C.s * 2 - f.x) * dt * 0.4 + Math.sin(t + f.wx) * 10 * dt;
        f.y += (C.y - C.s + Math.cos(f.wx * 2) * C.s - f.y) * dt * 0.4 + Math.cos(t * 1.3 + f.wx) * 8 * dt;
        let blink = Math.pow(Math.max(0, Math.sin(t * f.sp * 2 + f.ph)), 3);
        blink = Math.max(blink, sync);
        if (blink > 0.05)
          glow(f.x, f.y, 4, "rgba(220,255,140," + blink * 0.8 + ")");
      }
      ctx.globalCompositeOperation = "source-over";
      sync = Math.max(0, sync - dt * 1.6);
    }
  };
});

def("Hero's cape", "decor", "a cape streams behind it; press for the wind-machine pose", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  const pts = [];
  for (let i = 0; i < 9; i++) pts.push({ x: 0, y: 0 });
  let gust = 0;
  return {
    press() { gust = 1.4; },
    frame(dt, t) {
      stage(); tickCube(dt);
      const ax = C.x - C.face * C.s * 0.45;            // the clasp at its shoulder
      const ay = C.y - C.s * 0.9 - C.hop;
      pts[0].x = ax; pts[0].y = ay;
      const wind = 1 + gust * 2.4 + Math.min(1, Math.abs(C.vx) / 40);
      for (let i = 1; i < pts.length; i++) {           // each point chases the last
        const tx = pts[i - 1].x - C.face * 5 * wind;
        const ty = pts[i - 1].y + 2.5 + Math.sin(t * (5 + wind) + i) * (1.5 + gust * 2);
        pts[i].x += (tx - pts[i].x) * Math.min(1, dt * 14);
        pts[i].y += (ty - pts[i].y) * Math.min(1, dt * 14);
      }
      ctx.fillStyle = "rgba(170,50,70,0.9)";           // the cape as a ribbon-fan
      ctx.beginPath();
      ctx.moveTo(ax, ay);
      for (const p of pts) ctx.lineTo(p.x, p.y);
      for (let i = pts.length - 1; i >= 0; i--) ctx.lineTo(pts[i].x, pts[i].y + 6 + i * 1.2);
      ctx.closePath(); ctx.fill();
      drawCube();
      gust = Math.max(0, gust - dt);
    }
  };
});

def("Stage rain", "decor", "rain over everything, honestly bouncing off the hero; press: downpour", function (u) {
  const { ctx, W, H, G, C, rand, TAU, stage, tickCube, drawCube, glow, twinkle } = u;
  let rain = [], bounces = [], pour = 0;
  return {
    press() { pour = 1.6; },
    frame(dt, t) {
      stage(); tickCube(dt); drawCube();
      if (Math.random() < 0.3 + (pour > 0 ? 0.6 : 0))
        rain.push({ x: rand(0, W), y: -4 });
      for (const r of rain) {
        r.y += 230 * dt;
        // the honest part: the hero's head is a real surface
        if (r.y >= C.y - C.s && r.y < C.y && Math.abs(r.x - C.x) < C.s * 0.5) {
          bounces.push({ x: r.x, y: C.y - C.s, vx: rand(-40, 40), vy: rand(-70, -30), life: 0.5 });
          r.y = 1e9;
        }
        if (r.y >= G) {
          if (Math.random() < 0.3)
            bounces.push({ x: r.x, y: G, vx: rand(-20, 20), vy: rand(-40, -15), life: 0.4 });
          r.y = 1e9;
        }
        ctx.strokeStyle = "rgba(150,180,215,0.5)";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(r.x, r.y - 6); ctx.lineTo(r.x, r.y); ctx.stroke();
      }
      rain = rain.filter(r => r.y < H);
      for (const b of bounces) {
        b.x += b.vx * dt; b.y += b.vy * dt; b.vy += 300 * dt; b.life -= dt * 2;
        if (b.life > 0) { ctx.fillStyle = "rgba(180,210,240," + b.life + ")"; ctx.fillRect(b.x, b.y, 1.6, 1.6); }
      }
      bounces = bounces.filter(b => b.life > 0);
      pour = Math.max(0, pour - dt);
    }
  };
});

/* @@EFFECTS-END@@ */

/* ============================== the page runner ============================== */

var FAMILY_ORDER = [
  ["fire", "Fire attacks", "bursts, breaths, and roads of embers"],
  ["water", "Water attacks", "hoses, geysers, and shields made of bubbles"],
  ["bolt", "Lightning", "bolts called down, charges released, dashes at storm speed"],
  ["sparkle", "Sparkles & charms", "the friendly end of the arsenal"],
  ["halo", "Halos & blessings", "lights that follow, rings that sanctify"],
  ["aura", "Auras & energy", "power-ups, shields, and anime tension"],
  ["motion", "Movement", "dashes, jumps, and the dust they kick"],
  ["impact", "Impacts & hits", "the fighting game's punctuation marks"],
  ["earth", "Earth & nature", "rocks thrown, vines called, flowers left behind"],
  ["shot", "Projectiles", "orbs, beams, boomerangs, and charged shots"],
  ["ice", "Ice", "shards, armor, and ground that freezes over"],
  ["wind", "Wind", "gusts, crescents, and one personal tornado"],
  ["dark", "Dark & void", "clones, veils, and hands from below"],
  ["decor", "Decorations", "butterflies, lanterns, petals — the stage dressed kindly"]
];

var grid = document.getElementById("codex");
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
  b.textContent = effect.name;
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
    var r = canvas.getBoundingClientRect();
    var mx = e.clientX - r.left, my = e.clientY - r.top;
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
  u.drawCube();
  u.ctx.fillStyle = "rgba(230,227,242,0.55)";
  u.ctx.font = "12px system-ui, sans-serif";
  u.ctx.textAlign = "center";
  u.ctx.fillText("▶ click to wake", u.W / 2, u.H * 0.2);
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
  if (window.console) console.error("[" + st.effect.name + "]", err);
  updateStatus();
}

function restCard(st) {
  st.running = false;
  var c = st.u.ctx;
  c.globalCompositeOperation = "source-over";
  c.globalAlpha = 1;
  c.fillStyle = "rgba(19,16,32,0.6)";
  c.fillRect(0, 0, st.u.W, st.u.H);
  c.fillStyle = "rgba(230,227,242,0.8)";
  c.font = "12px system-ui, sans-serif";
  c.textAlign = "center";
  c.textBaseline = "middle";
  c.fillText("resting — click to wake again", st.u.W / 2, st.u.H / 2);
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

if ("IntersectionObserver" in window) {
  var io = new IntersectionObserver(function (entries) {
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
var current = EFFECTS[0];
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
  u.drawCube();
  u.ctx.fillStyle = "rgba(230,227,242,0.6)";
  u.ctx.font = "15px system-ui, sans-serif";
  u.ctx.textAlign = "center";
  u.ctx.fillText("Press ▶ Run — nothing moves until you do.", u.W / 2, u.H * 0.25);
}

function openInEditor(effect) {
  current = effect;
  edname.textContent = effect.name + " — " + effect.hint;
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
  openInEditor(current);
});
cv.addEventListener("pointerdown", function (e) {
  if (!pv.inst || !pv.inst.press) return;
  var r = cv.getBoundingClientRect();
  try { pv.inst.press(e.clientX - r.left, e.clientY - r.top); }
  catch (err) { errBox.textContent = "The press handler hit a snag: " + err.message; }
});

openInEditor(EFFECTS[0]);

/* expose a tiny hook for the automated smoke test (harmless in normal use) */
window.__codex = { EFFECTS: EFFECTS, apiFor: apiFor, cards: cards };
})();
