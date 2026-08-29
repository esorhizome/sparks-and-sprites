/* Sparks & Sprites — the locomotion lexicon.
   One little blue mote and 26 ways for it to move — an A-to-Z of the maths
   behind procedural animation, the fourth gallery after the elemental button
   bestiary, the cube codex, and the glyph grimoire. If the grimoire was what
   a phrase can DO, the lexicon is what a body can KNOW: sines and circles,
   springs and slopes, steering brains, joint chains, and honest physics.

   Every demo is one function make(u) that returns { frame(dt, t), press(x, y) }.
   The kit u:
     ctx, W, H     — the 2D context and canvas size (CSS pixels)
     GY            — the standard ground line's y (H · 0.78)
     MOVER         — the mote's blue      #8AD9F5   (the protagonist)
     TARGET        — "where it wants to be" amber   #F5C169
     BONE          — limbs and joints     #C9C4E4
     GOOD          — helpers, friends     #9BE28A
     HOT           — impulses, lasers     #F58A8A
     INK, DIM      — plain light, and its faded cousin
     stage()       — clears the canvas: night backdrop + faint graph paper
     ground(y?)    — a floor line with hatching (defaults to GY)
     dot(x,y,r,c)  — a filled circle
     ring(x,y,r,c,w?) — a stroked circle
     arrow(x1,y1,x2,y2,c) — a vector, drawn honestly (line + head)
     mote(x,y,ang,c?,s?)  — the protagonist: a round body, a nose showing
                     its heading, one attentive eye
     label(txt,x,y,c?,align?) — a small annotation
     len(x,y)      — √(x²+y²), the length of a vector
     clamp(v,a,b), ease(k) — the usual suspects (ease = smoothstep)
     wrapAngle(a)  — fold any angle into −π..π (for shortest-turn maths)
     rand(a,b), TAU

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
  var GY = H * 0.78;
  var INK = "#E8E5F4";
  var DIM = "rgba(232,229,244,0.25)";
  var MOVER = "#8AD9F5";
  var TARGET = "#F5C169";
  var BONE = "#C9C4E4";
  var GOOD = "#9BE28A";
  var HOT = "#F58A8A";
  function rand(a, b) { return a + Math.random() * (b - a); }
  function len(x, y) { return Math.sqrt(x * x + y * y); }
  function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
  function ease(k) { k = clamp(k, 0, 1); return k * k * (3 - 2 * k); }
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
    ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
  }
  function ring(x, y, r, c, w) {
    ctx.strokeStyle = c || DIM;
    ctx.lineWidth = w || 1;
    ctx.beginPath(); ctx.arc(x, y, Math.max(0.5, r), 0, TAU); ctx.stroke();
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
           INK: INK, DIM: DIM, MOVER: MOVER, TARGET: TARGET, BONE: BONE, GOOD: GOOD, HOT: HOT,
           rand: rand, len: len, clamp: clamp, ease: ease, wrapAngle: wrapAngle,
           stage: stage, ground: ground, dot: dot, ring: ring, arrow: arrow,
           mote: mote, label: label };
}

/* ============================== CLOCKS & CIRCLES ==============================
   Motion with NO memory: every frame, position is computed straight from the
   clock. x(t) and y(t) are formulas — nothing is remembered, nothing can
   drift, and the loop can run for a year without a bug. These are the maths
   of hovering pickups, orbiting shields, figure-eight patrols, and every
   snake that ever swam across a title screen. */

def("H", "Hover", "clocks", "y = sin(t) is a whole idle animation — press to excite it", function (u) {
  const { ctx, W, H, GY, TAU, stage, ground, mote, label } = u;
  // the entire behaviour is ONE line of maths: y = rest + sin(t·2π/period)·amp.
  // the rest is presentation: the tilt is the curve's SLOPE (its derivative,
  // cos), and the shadow shrinks as the body rises — altitude for free.
  const period = 2.8;
  let excite = 0;
  return {
    press() { excite = 1; },
    frame(dt, t) {
      stage(); ground();
      excite = Math.max(0, excite - dt * 0.45);
      const amp = H * 0.075 * (1 + excite * 1.5);
      const w = TAU / (period * (1 - excite * 0.4));   // excited = faster AND higher
      const rest = GY - H * 0.32;
      const y = rest + Math.sin(t * w) * amp;
      const tilt = Math.cos(t * w) * 0.16;             // the derivative leans the body
      const alt = (GY - y) / (GY - rest + amp);        // 0-ish at the floor, ~1 up high
      ctx.fillStyle = "rgba(0,0,0,0.4)";
      ctx.beginPath();
      ctx.ellipse(W / 2, GY - 3, 17 * (1.3 - alt * 0.55), 4, 0, 0, TAU);
      ctx.fill();
      mote(W / 2, y, tilt);
      label("y = rest + sin(t · 2π/" + period + ") · amp", W / 2, GY + 18, null, "center");
    }
  };
});

def("O", "Orbit", "clocks", "polar coordinates: one angle + one radius = a flight plan — press to reverse", function (u) {
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
      const r = Math.min(W, H) * 0.3 + Math.sin(t * 0.7) * 6;   // r can breathe too
      th += dt * 1.1 * dir;
      mth += dt * 4.6 * dir;                            // the moon runs its own, faster clock
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
      dot(x + Math.cos(mth) * 19, y + Math.sin(mth) * 19, 3.5, GOOD);
      label("x = cos(θ)·r   y = sin(θ)·r", W / 2, H - 8, null, "center");
    }
  };
});

def("E", "Eight", "clocks", "two sines at different speeds trace a figure eight — press for a new ratio", function (u) {
  const { ctx, W, H, TAU, stage, dot, mote, arrow, label, GOOD, DIM } = u;
  // a Lissajous curve: x follows cos(a·t), y follows sin(b·t). when a and b
  // are small whole numbers the path closes into a knot — 1:2 is the figure
  // eight. bosses fly these because they look deliberate and cost nothing.
  const RATIOS = [[1, 2], [3, 2], [3, 4], [2, 1]];
  let ri = 0;
  let trail = [];
  return {
    press() { ri = (ri + 1) % RATIOS.length; trail = []; },
    frame(dt, t) {
      stage();
      const a = RATIOS[ri][0], b = RATIOS[ri][1];
      const cx = W / 2, cy = H * 0.5, rx = W * 0.33, ry = H * 0.3, spd = 1.3;
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
      if (trail.length > 60) trail.shift();
      for (let i = 0; i < trail.length; i++)
        dot(trail[i][0], trail[i][1], 1.6, "rgba(138,217,245," + (i / trail.length * 0.35) + ")");
      arrow(x, y, x + vx * 0.22, y + vy * 0.22, GOOD);
      mote(x, y, Math.atan2(vy, vx));
      label("x = cos(" + a + "t)   y = sin(" + b + "t)", W / 2, 16, null, "center");
      label("the arrow is the derivative (velocity)", W / 2, H - 8, "rgba(155,226,138,0.6)", "center");
    }
  };
});

def("U", "Undulate", "clocks", "one sine, sixteen joints, phase-shifted — a swimmer — press for a burst", function (u) {
  const { ctx, W, H, TAU, stage, dot, label, MOVER, clamp } = u;
  // every segment reads the SAME sine — just a little later than the one in
  // front (a PHASE OFFSET per joint). offset in time down a line of bodies
  // = a wave travelling in space. tails, banners, caterpillars: this trick.
  const N = 16, SP = 11;
  let hx = W * 0.3, boost = 0;
  return {
    press() { boost = 1; },
    frame(dt, t) {
      stage();
      boost = Math.max(0, boost - dt * 0.55);
      const freq = 4.2 * (1 + boost * 0.9);
      const amp = H * 0.07 * (1 + boost * 0.6);
      hx += dt * (26 + boost * 130);                   // the burst is real thrust
      if (hx - N * SP > W + 20) hx = -20;              // swim off, swim back on
      const mid = H * 0.45;
      for (let i = N - 1; i >= 0; i--) {               // tail first, head on top
        const x = hx - i * SP;
        const grow = 0.35 + (i / N) * 0.9;             // the wave grows toward the tail
        const y = mid + Math.sin(t * freq - i * 0.62) * amp * grow;
        const r = 8 - i * 0.36;
        dot(x, y, Math.max(2, r), i === 0 ? MOVER : "rgba(138,217,245," + (0.75 - i * 0.035) + ")");
        if (i === 0) {                                 // the head gets the eye
          ctx.fillStyle = "#131020";
          ctx.beginPath(); ctx.arc(x + 3, y - 2.5, 1.8, 0, TAU); ctx.fill();
        }
      }
      label("segment i:  y = sin(t·f − i·0.62) · amp", W / 2, H - 8, null, "center");
    }
  };
});

def("P", "Pendulum", "clocks", "real swing vs the small-angle shortcut — press to lift both to your click", function (u) {
  const { ctx, W, H, TAU, stage, dot, ring, label, MOVER, DIM, BONE } = u;
  // the honest pendulum obeys  α = −(g/L)·sin(θ)  — a second-order
  // differential equation, solved live by integrating twice a frame:
  // ω += α·dt, then θ += ω·dt. the ghost uses the classroom shortcut
  // sin(θ) ≈ θ. watch them agree at small swings and drift apart at big
  // ones — that drift is why games integrate instead of using formulas.
  const K = 7.5, DAMP = 0.02;
  let th = 1.15, om = 0, gth = 1.15, gom = 0;
  const px = () => W / 2, py = () => H * 0.14, L = () => H * 0.56;
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

/* ============================== SLOPES & SPRINGS ==============================
   Motion WITH memory: a velocity that persists between frames, an
   acceleration that bends it. This is calculus wearing gym clothes —
   velocity is the derivative of position, acceleration the derivative of
   velocity, and "integration" just means adding them up one frame at a
   time. Every camera follow, jump arc, and satisfying UI wobble is here. */

def("L", "Lerp", "springs", "three ways to chase the same target — constant, eased, springy — press to move it", function (u) {
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
      if (timer > 2.6) { timer = 0; tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.2, H * 0.8); }
      let dx = tx - A.x, dy = ty - A.y, d = len(dx, dy);
      const step = 140 * dt;
      if (d > step) { A.x += dx / d * step; A.y += dy / d * step; }
      else { A.x = tx; A.y = ty; }                     // arrive exactly, stop dead
      const k = 1 - Math.exp(-4.2 * dt);               // framerate-proof lerp factor
      B.x += (tx - B.x) * k;
      B.y += (ty - B.y) * k;
      const w = 7.5, z = 0.55;                         // spring frequency + damping
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

def("D", "Damp", "springs", "one spring equation, three damping ratios — press to yank the target", function (u) {
  const { ctx, W, H, stage, dot, mote, label, MOVER, GOOD, HOT, TARGET } = u;
  // the spring-damper is a second-order differential equation:
  //   acceleration = ω²·(target − x) − 2·ζ·ω·velocity
  // ω sets how FAST it wants to be; ζ (zeta) sets its manners:
  //   ζ < 1 underdamped — overshoots and rings (bouncy, alive)
  //   ζ = 1 CRITICALLY DAMPED — fastest possible arrival with zero
  //         overshoot (the one cameras and cursors want)
  //   ζ > 1 overdamped — never overshoots, takes its sweet time
  const w = 8;
  const rows = [
    { z: 0.35, name: "ζ = 0.35 bouncy", c: HOT, y: 0, v: 0 },
    { z: 1.0, name: "ζ = 1 critical", c: GOOD, y: 0, v: 0 },
    { z: 2.2, name: "ζ = 2.2 sluggish", c: MOVER, y: 0, v: 0 }
  ];
  let ty = H * 0.3, timer = 0, hold = 0;
  for (const r of rows) r.y = H * 0.6;
  return {
    press(x, y) { ty = y; hold = 4; },
    frame(dt, t) {
      stage();
      if (hold > 0) hold -= dt;
      else {
        timer += dt;
        if (timer > 2.2) { timer = 0; ty = ty < H * 0.5 ? H * 0.68 : H * 0.3; }
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
      label("a = ω²(target−y) − 2ζω·v", W / 2, 14, null, "center");
    }
  };
});

def("Y", "Yaw", "springs", "a heading with a turn-rate limit — press to plant the flag", function (u) {
  const { ctx, W, H, TAU, stage, dot, ring, mote, label, wrapAngle, clamp, len, rand, TARGET, DIM } = u;
  // the mote can't teleport its direction: it stores a HEADING angle and may
  // only turn so many radians per second. atan2 (inverse trig) names the
  // angle to the flag; wrapAngle picks the short way round; the clamp is
  // the personality. the faint circles are its turning radius — aim inside
  // one and it must loop all the way around. cars, missiles, geese: this.
  let x = W * 0.3, y = H * 0.6, h = 0, timer = 0;
  let tx = W * 0.7, ty = H * 0.4;
  const SPEED = 84, TURN = 2.0;
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
      if (len(tx - x, ty - y) < 15 || timer > 7) {
        timer = 0; tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.2, H * 0.8);
      }
      const R = SPEED / TURN;                          // the physics of "too close to aim at"
      ring(x + Math.cos(h + TAU / 4) * R, y + Math.sin(h + TAU / 4) * R, R, "rgba(232,229,244,0.08)");
      ring(x + Math.cos(h - TAU / 4) * R, y + Math.sin(h - TAU / 4) * R, R, "rgba(232,229,244,0.08)");
      trail.push([x, y]);
      if (trail.length > 70) trail.shift();
      for (let i = 0; i < trail.length; i++)
        dot(trail[i][0], trail[i][1], 1.3, "rgba(138,217,245," + (i / trail.length * 0.3) + ")");
      ctx.strokeStyle = TARGET; ctx.lineWidth = 1.5;   // the flag
      ctx.beginPath(); ctx.moveTo(tx, ty + 8); ctx.lineTo(tx, ty - 10); ctx.stroke();
      ctx.fillStyle = TARGET;
      ctx.beginPath(); ctx.moveTo(tx, ty - 10); ctx.lineTo(tx + 9, ty - 6.5); ctx.lineTo(tx, ty - 3); ctx.closePath(); ctx.fill();
      mote(x, y, h);
      label("turn radius = speed ÷ turn rate ≈ " + Math.round(R) + " px", W / 2, H - 8, null, "center");
    }
  };
});

def("J", "Jump", "springs", "v₀ = √(2gh): pick the height, get the launch speed — press to set the apex", function (u) {
  const { ctx, W, H, GY, TAU, stage, ground, ring, mote, label, clamp, TARGET, DIM } = u;
  // jumps are parabolas — constant downward acceleration under a chosen
  // launch speed. games run the maths BACKWARD: designers pick the apex
  // height h, and v₀ = √(2·g·h) guarantees it. the second trick: gravity
  // is 1.7× stronger on the way down, because floaty rises and snappy
  // falls FEEL right even though physics class would object.
  const G = H * 2.4;
  let h = H * 0.36;
  let phase = "stand", timer = 0, y = GY, vy = 0;
  return {
    press(px, py) { h = clamp(GY - py, H * 0.1, H * 0.62); },
    frame(dt, t) {
      stage(); ground();
      const v0 = Math.sqrt(2 * G * h);
      const x = W / 2;
      timer += dt;
      if (phase === "stand" && timer > 0.9) { phase = "air"; vy = -v0; timer = 0; }
      if (phase === "air") {
        vy += (vy < 0 ? G : G * 1.7) * dt;             // heavier on the way down
        y += vy * dt;
        if (y >= GY) { y = GY; phase = "land"; timer = 0; }
      }
      if (phase === "land" && timer > 0.16) { phase = "stand"; timer = 0; }
      ctx.fillStyle = "rgba(232,229,244,0.18)";        // the predicted arc, while standing
      if (phase === "stand") {
        let sy = GY, sv = -v0;
        for (let i = 0; i < 46; i++) {
          sv += (sv < 0 ? G : G * 1.7) * 0.022;
          sy += sv * 0.022;
          if (sy > GY) break;
          ctx.fillRect(x - 1 + i * 0, sy, 2, 2);       // a rising-falling dotted line
        }
      }
      ring(x, GY - h, 6, TARGET, 1.5);
      label("apex h = " + Math.round(h) + " px", x + 12, GY - h + 3, "rgba(245,193,105,0.8)");
      let sx = 1, sy2 = 1;
      if (phase === "stand" && timer > 0.7) { sx = 1.12; sy2 = 0.85; }   // anticipation crouch
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

def("B", "Bounce", "springs", "restitution: every bounce keeps 62% of the energy — press to throw", function (u) {
  const { ctx, W, H, GY, stage, ground, label, rand, TAU, MOVER } = u;
  // integration plus one rule at the floor: flip the velocity and keep only
  // a fraction e of it (the RESTITUTION). heights shrink by e² per bounce —
  // energy goes with the square of speed — so the rhythm speeds up all by
  // itself, no scripting. the squash at contact is presentation, not physics.
  const G = H * 1.9, E = 0.78;
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
          if (Math.abs(vy) < H * 0.09) { vy = 0; if (Math.abs(vx) < 6) rest = 1.1; }
        }
      }
      squash = Math.max(0, squash - dt);
      const s = squash > 0 ? 1 - (squash / 0.12) * 0.35 : 1;
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

/* ============================== BRAINS & STEERING ==============================
   How enemies decide. A steering agent keeps a velocity and, each frame,
   computes a DESIRED velocity from what it wants — then applies only a
   gentle correction (desired − current, clamped). That one subtraction is
   why steered things bank, drift, and overshoot like living creatures
   instead of snapping like cursors. Everything here is vector maths:
   subtract two points to get "toward", divide by length to get a pure
   direction, multiply to choose a speed. */

def("A", "Arrive", "steer", "seek, but braking inside the amber ring — press to move the target", function (u) {
  const { ctx, W, H, stage, dot, ring, mote, arrow, label, rand, len, clamp, GOOD, HOT, TARGET } = u;
  // plain seek arrives like a dart hitting a board. ARRIVE scales the
  // desired speed down with distance inside a slow radius, so the brakes
  // come on early and the stop is a real stop. the arrows tell the story:
  // green = current velocity, red = the correction being applied.
  const MAXSP = 130, MAXF = 300, SLOW = 85;
  let x = W * 0.2, y = H * 0.7, vx = 0, vy = 0;
  let tx = W * 0.7, ty = H * 0.35, timer = 0;
  return {
    press(px, py) { tx = px; ty = py; timer = -4; },
    frame(dt, t) {
      stage();
      timer += dt;
      if (timer > 3.2) { timer = 0; tx = rand(W * 0.15, W * 0.85); ty = rand(H * 0.15, H * 0.85); }
      const dx = tx - x, dy = ty - y, d = len(dx, dy) || 1;
      const speed = MAXSP * Math.min(1, d / SLOW);     // ← the whole idea of Arrive
      const desx = dx / d * speed, desy = dy / d * speed;
      let sx = desx - vx, sy = desy - vy;              // steering = desired − current
      const sl = len(sx, sy);
      if (sl > MAXF) { sx = sx / sl * MAXF; sy = sy / sl * MAXF; }
      vx += sx * dt; vy += sy * dt;
      x += vx * dt; y += vy * dt;
      ring(tx, ty, SLOW, "rgba(245,193,105,0.25)");
      dot(tx, ty, 4, TARGET);
      arrow(x, y, x + vx * 0.35, y + vy * 0.35, GOOD);
      arrow(x, y, x + sx * 0.12, y + sy * 0.12, HOT);
      mote(x, y, Math.atan2(vy, vx));
      label("desired speed = max · min(1, distance/" + SLOW + ")", W / 2, H - 8, null, "center");
    }
  };
});

def("C", "Chase", "steer", "aim where the prey WILL be — the faint rival aims where it is — press to scatter", function (u) {
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
      wa += rand(-2.6, 2.6) * Math.sqrt(dt);           // the prey wanders...
      let fx = Math.cos(wa) * 105, fy = Math.sin(wa) * 105;
      const pd = len(smart.x - prey.x, smart.y - prey.y);
      if (pd < 95) {                                   // ...and flees the smart one
        fx += (prey.x - smart.x) / pd * 150;
        fy += (prey.y - smart.y) / pd * 150;
      }
      steer(prey, prey.x + fx, prey.y + fy, 112, 260, dt);
      const eta = pd / 95;                             // rough time-to-intercept
      const px2 = prey.x + prey.vx * eta * 0.9, py2 = prey.y + prey.vy * eta * 0.9;
      steer(smart, px2, py2, 95, 240, dt);
      steer(naive, prey.x, prey.y, 95, 240, dt);
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

def("W", "Wander", "steer", "the classic wander rig: a jittering target on a circle held out front — press to startle", function (u) {
  const { ctx, W, H, TAU, stage, dot, ring, mote, label, rand, len, DIM, TARGET } = u;
  // aimless-looking motion that never twitches: hold an invisible circle a
  // fixed distance ahead, keep a target ON its rim, and jitter that
  // target's angle a little each frame. steering at the rim point smooths
  // all the randomness through the circle's geometry. the rig is usually
  // hidden — here it's the whole show.
  const AHEAD = 46, RIM = 26;
  let x = W / 2, y = H / 2, vx = 60, vy = 0, wa = 0, burst = 0;
  return {
    press() { wa = rand(-Math.PI, Math.PI); burst = 1; },
    frame(dt, t) {
      stage();
      burst = Math.max(0, burst - dt * 0.7);
      wa += rand(-1, 1) * 3.1 * Math.sqrt(dt);         // the only randomness in the rig
      const sp = len(vx, vy) || 1;
      const hx = vx / sp, hy = vy / sp;
      const cx = x + hx * AHEAD, cy = y + hy * AHEAD;  // the guide circle, out front
      const head = Math.atan2(hy, hx);
      const tx = cx + Math.cos(head + wa) * RIM;
      const ty = cy + Math.sin(head + wa) * RIM;
      const maxsp = 85 * (1 + burst * 1.2);
      const dx = tx - x, dy = ty - y, d = len(dx, dy) || 1;
      vx += (dx / d * maxsp - vx) * 3 * dt;
      vy += (dy / d * maxsp - vy) * 3 * dt;
      x += vx * dt; y += vy * dt;
      if (x < -12) x = W + 12; if (x > W + 12) x = -12;
      if (y < -12) y = H + 12; if (y > H + 12) y = -12;
      ring(cx, cy, RIM, "rgba(232,229,244,0.2)");
      ctx.strokeStyle = DIM;
      ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(tx, ty); ctx.stroke();
      dot(tx, ty, 3.5, TARGET);
      mote(x, y, Math.atan2(vy, vx));
      label("steer at the rim dot; jitter only its angle", W / 2, H - 8, null, "center");
    }
  };
});

def("Z", "Zigzag", "steer", "a patrol path with eased legs and pauses — press to add a waypoint", function (u) {
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
      if (pts.length >= 8) pts = defaults();
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
      const legLen = len(b[0] - a[0], b[1] - a[1]);
      if (pause > 0) pause -= dt;
      else {
        k += dt * 150 / legLen;                        // constant speed, eased per leg
        if (k >= 1) {
          k = 0; pause = 0.45;                         // the corner rest
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
      gd = (gd + 110 * dt) % (total * 2);              // ghost ping-pongs by distance
      let g = gd > total ? total * 2 - gd : gd, gx = pts[0][0], gy = pts[0][1];
      for (let i = 0; i < pts.length - 1; i++) {
        const L = len(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]);
        if (g <= L) { gx = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * g / L; gy = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * g / L; break; }
        g -= L;
      }
      dot(gx, gy, 7, "rgba(232,229,244,0.18)");
      ctx.save();                                      // the saw: eased, pausing, mean
      ctx.translate(ex, ey);
      ctx.rotate(t * 9);
      ctx.fillStyle = HOT;
      ctx.beginPath(); ctx.arc(0, 0, 8, 0, TAU); ctx.fill();
      ctx.strokeStyle = HOT; ctx.lineWidth = 2;
      for (let i = 0; i < 8; i++) {
        const an = i / 8 * TAU;
        ctx.beginPath(); ctx.moveTo(Math.cos(an) * 8, Math.sin(an) * 8);
        ctx.lineTo(Math.cos(an) * 12, Math.sin(an) * 12); ctx.stroke();
      }
      ctx.restore();
      label(pts.length + "/8 waypoints · eased saw vs constant ghost", W / 2, H - 8, null, "center");
    }
  };
});

def("M", "Magnet", "steer", "inverse-square fields: dust in the pull of three magnets — press to flip them", function (u) {
  const { ctx, W, H, TAU, stage, dot, ring, label, rand, len, TARGET, HOT } = u;
  // force fields, the gravity-and-charge law: strength = k ÷ distance².
  // every grain sums one small vector per magnet, plus drag so it settles
  // instead of slingshotting forever. attractors breathe inward, the
  // repulsor breathes outward — the field, made legible.
  const mags = [
    { x: W * 0.28, y: H * 0.38, p: 1 },
    { x: W * 0.72, y: H * 0.34, p: 1 },
    { x: W * 0.5, y: H * 0.72, p: -1 }
  ];
  const dust = [];
  for (let i = 0; i < 36; i++)
    dust.push({ x: rand(0, W), y: rand(0, H), vx: 0, vy: 0 });
  return {
    press() { for (const m of mags) m.p = -m.p; },     // invert the world
    frame(dt, t) {
      stage();
      for (const g of dust) {
        for (const m of mags) {
          const dx = m.x - g.x, dy = m.y - g.y;
          const dd = dx * dx + dy * dy + 900;          // +900 softens the singularity
          const f = m.p * 26000 / dd;
          const d = Math.sqrt(dd);
          g.vx += dx / d * f * dt * 60;
          g.vy += dy / d * f * dt * 60;
          if (m.p > 0) {                               // a whisper of sideways push,
            g.vx += -dy / d * f * dt * 24;             // so grains orbit the pull
            g.vy += dx / d * f * dt * 24;              // instead of parking in it
          }
        }
        g.vx *= 1 - 0.7 * dt; g.vy *= 1 - 0.7 * dt;    // drag = the settling
        const s = len(g.vx, g.vy);
        if (s > 190) { g.vx *= 190 / s; g.vy *= 190 / s; }
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
      label("force = k ÷ distance² — flip: pull ⇄ push", W / 2, H - 8, null, "center");
    }
  };
});

def("V", "Vectorfield", "steer", "a formula turns every point into an arrow; riders obey — press to pour more in", function (u) {
  const { ctx, W, H, TAU, stage, dot, arrow, label, rand, MOVER } = u;
  // a vector field is a function from position to direction — invisible
  // level design. wind, currents, lava flows, bullet-hell patterns: define
  // angle(x, y, t), and anything dropped in follows the grain. the field
  // here slowly morphs; the arrows sample it so you can read the weather.
  function fieldAngle(x, y, t) {
    return Math.sin(x * 0.019 + t * 0.24) * 1.6 + Math.cos(y * 0.023 - t * 0.17) * 1.6;
  }
  const riders = [];
  for (let i = 0; i < 40; i++) riders.push({ x: rand(0, W), y: rand(0, H) });
  return {
    press(px, py) {
      for (let i = 0; i < 14; i++) {
        const r = riders[Math.floor(rand(0, riders.length))];
        r.x = px + rand(-8, 8); r.y = py + rand(-8, 8);
      }
    },
    frame(dt, t) {
      stage();
      for (let gx = 20; gx < W; gx += 36)
        for (let gy = 20; gy < H; gy += 36) {
          const a = fieldAngle(gx, gy, t);
          arrow(gx - Math.cos(a) * 5, gy - Math.sin(a) * 5,
                gx + Math.cos(a) * 5, gy + Math.sin(a) * 5, "rgba(232,229,244,0.16)");
        }
      for (const r of riders) {
        const a = fieldAngle(r.x, r.y, t);
        const sp = 62;
        r.x += Math.cos(a) * sp * dt;
        r.y += Math.sin(a) * sp * dt;
        if (r.x < 0) r.x = W; if (r.x > W) r.x = 0;
        if (r.y < 0) r.y = H; if (r.y > H) r.y = 0;
        ctx.strokeStyle = "rgba(138,217,245,0.5)";     // a short wake, against the grain
        ctx.beginPath(); ctx.moveTo(r.x - Math.cos(a) * 6, r.y - Math.sin(a) * 6);
        ctx.lineTo(r.x, r.y); ctx.stroke();
        dot(r.x, r.y, 2, MOVER);
      }
      label("angle(x, y, t) = sin(x·s + t) + cos(y·s − t)", W / 2, H - 8, null, "center");
    }
  };
});

def("S", "Swarm", "steer", "boids: separation + alignment + cohesion, nobody in charge — press to scare them", function (u) {
  const { ctx, W, H, TAU, stage, label, rand, len, MOVER, GOOD } = u;
  // three rules, each an average over neighbours: don't crowd (push apart
  // inside 26 px), don't stray (match nearby velocities), don't drift
  // (drop toward the local centre). no leader exists — the two green birds
  // are ordinary; follow one and watch it obey the same three nudges.
  const N = 26;
  const boids = [];
  for (let i = 0; i < N; i++)
    boids.push({ x: rand(0, W), y: rand(0, H), vx: rand(-60, 60), vy: rand(-60, 60), g: i < 2 });
  return {
    press(px, py) {
      for (const b of boids) {
        const dx = b.x - px, dy = b.y - py, d = len(dx, dy) + 4;
        b.vx += dx / d * 9000 / d;                     // fear, inverse with distance
        b.vy += dy / d * 9000 / d;
      }
    },
    frame(dt, t) {
      stage();
      for (const b of boids) {
        let sx = 0, sy = 0, ax = 0, ay = 0, cx = 0, cy = 0, n = 0;
        for (const o of boids) {
          if (o === b) continue;
          const dx = o.x - b.x, dy = o.y - b.y, d = len(dx, dy);
          if (d < 26 && d > 0) { sx -= dx / d / d; sy -= dy / d / d; }   // 1: separation
          if (d < 54) { ax += o.vx; ay += o.vy; cx += o.x; cy += o.y; n++; }
        }
        if (n) {
          b.vx += (ax / n - b.vx) * 1.4 * dt;          // 2: alignment
          b.vy += (ay / n - b.vy) * 1.4 * dt;
          b.vx += (cx / n - b.x) * 1.1 * dt;           // 3: cohesion
          b.vy += (cy / n - b.y) * 1.1 * dt;
        }
        b.vx += sx * 3400 * dt; b.vy += sy * 3400 * dt;
        const s = len(b.vx, b.vy) || 1;
        const sp = Math.min(105, Math.max(55, s));     // a floor keeps the flock flowing
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
      label("three averages over neighbours = the brain", W / 2, H - 8, null, "center");
    }
  };
});

/* ============================== CHAINS & JOINTS ==============================
   Limbs. A chain is just a list of points that promise to stay a fixed
   distance apart; INVERSE KINEMATICS is any recipe that places the joints
   so the end lands on a target. Three recipes live here — drag-follow
   (no solving at all), the Law of Cosines (exact, two bones), and FABRIK
   (iterative, any number of bones, no trig) — plus the 3D rotation maths
   that waits for you in every engine: quaternions. */

def("T", "Tentacle", "chains", "a follow-chain: the head leads, every link keeps its distance — press to point it", function (u) {
  const { ctx, W, H, TAU, stage, dot, label, rand, len, MOVER, TARGET } = u;
  // the cheapest limb in games: move the head, then walk down the chain
  // placing each link at a fixed distance from the one before, along the
  // line between them (a distance constraint, solved by pure geometry —
  // each link's position is polar-to-Cartesian from its parent). drag
  // does the animating; the sway is one small sine for life.
  const N = 18;
  const segs = [];
  for (let i = 0; i < N; i++) segs.push({ x: W / 2 - i * 9, y: H / 2 });
  let tx = W * 0.7, ty = H * 0.4, sticky = 0;
  return {
    press(px, py) { tx = px; ty = py; sticky = 3.5; },
    frame(dt, t) {
      stage();
      sticky -= dt;
      if (sticky <= 0) {                               // resume its own errand
        tx = W / 2 + Math.cos(t * 0.6) * W * 0.34;
        ty = H / 2 + Math.sin(t * 0.9) * H * 0.3;
      }
      const head = segs[0];
      const k = 1 - Math.exp(-3.2 * dt);               // the head is a lerp-follower
      head.x += (tx - head.x) * k;
      head.y += (ty - head.y) * k;
      for (let i = 1; i < N; i++) {
        const p = segs[i - 1], s = segs[i];
        const L = 10 - i * 0.28;                       // links shorten toward the tail
        let dx = s.x - p.x, dy = s.y - p.y;
        const d = len(dx, dy) || 1;
        const a = Math.atan2(dy, dx) + Math.sin(t * 3 - i * 0.5) * 0.05;  // the sway
        s.x = p.x + Math.cos(a) * L;                   // ← the whole constraint:
        s.y = p.y + Math.sin(a) * L;                   //   same direction, fixed length
      }
      for (let i = N - 1; i >= 0; i--) {
        const r = Math.max(1.6, 8.5 - i * 0.42);
        dot(segs[i].x, segs[i].y, r, i === 0 ? MOVER : "rgba(138,217,245," + (0.8 - i * 0.038) + ")");
      }
      const hd = Math.atan2(ty - head.y, tx - head.x); // the eye watches the target
      ctx.fillStyle = "#131020";
      ctx.beginPath();
      ctx.arc(head.x + Math.cos(hd) * 3.4, head.y + Math.sin(hd) * 3.4, 2, 0, TAU);
      ctx.fill();
      dot(tx, ty, 3, TARGET);
      label("each link: parent + (cos a, sin a) · length", W / 2, H - 8, null, "center");
    }
  };
});

def("I", "Ik", "chains", "two bones, one triangle, the Law of Cosines — press to re-aim and flip the elbow", function (u) {
  const { ctx, W, H, TAU, stage, dot, ring, label, clamp, len, BONE, MOVER, TARGET, DIM } = u;
  // two-bone IK is exact, no iteration: shoulder→target is a triangle with
  // sides a (upper arm), b (forearm), d (the reach), and the Law of
  // Cosines hands over the shoulder angle:
  //   cos(A) = (a² + d² − b²) / (2·a·d)
  // the ± on that angle is the ELBOW FLIP — the same hand position with
  // the joint bent the other way. arms, legs, and turrets end here.
  const sx = W * 0.34, sy = H * 0.42;
  const a = H * 0.3, b = H * 0.26;
  let flip = 1, tx = 0, ty = 0, sticky = 0;
  return {
    press(px, py) { tx = px; ty = py; sticky = 3.5; flip = -flip; },
    frame(dt, t) {
      stage();
      sticky -= dt;
      if (sticky <= 0) {
        tx = sx + Math.cos(t * 0.7) * W * 0.34;
        ty = sy + Math.sin(t * 1.1) * H * 0.28;
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
      label("cos A = (a² + d² − b²) / 2ad", W / 2, H - 8, null, "center");
    }
  };
});

def("F", "Fabrik", "chains", "IK with no trigonometry: slide joints along lines, twice, done — press to set the target", function (u) {
  const { ctx, W, H, GY, stage, ground, dot, ring, label, len, BONE, MOVER, TARGET } = u;
  // FABRIK (Forward And Backward Reaching IK): the BACKWARD pass pins the
  // hand to the target and drags the chain down toward the base; the
  // FORWARD pass re-pins the base and drags it back out. every step is
  // "project this point onto the line to its neighbour at bone length" —
  // constraint geometry, not one sine or cosine anywhere. it handles any
  // number of bones, and aims past its reach by simply straightening.
  const n = 4;
  const L = H * 0.2;
  const bx = W / 2, by = GY;
  const pts = [];
  for (let i = 0; i < n; i++) pts.push({ x: bx, y: by - i * L });
  let tx = W * 0.7, ty = H * 0.3, sticky = 0;
  function toward(from, to, dist) {                    // the one operation FABRIK owns
    const dx = to.x - from.x, dy = to.y - from.y, d = len(dx, dy) || 1;
    return { x: to.x - dx / d * dist, y: to.y - dy / d * dist };
  }
  return {
    press(px, py) { tx = px; ty = py; sticky = 3.5; },
    frame(dt, t) {
      stage(); ground();
      sticky -= dt;
      if (sticky <= 0) {
        tx = bx + Math.cos(t * 0.55) * W * 0.4;
        ty = by - H * 0.36 + Math.sin(t * 0.85) * H * 0.3;
      }
      for (let it = 0; it < 6; it++) {
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
        ctx.lineWidth = 7 - i * 1.5;
        ctx.beginPath(); ctx.moveTo(pts[i].x, pts[i].y); ctx.lineTo(pts[i + 1].x, pts[i + 1].y); ctx.stroke();
      }
      ctx.lineWidth = 1;
      ctx.lineCap = "butt";
      for (let i = 0; i < n; i++) dot(pts[i].x, pts[i].y, 4.5 - i * 0.5, i ? BONE : MOVER);
      dot(tx, ty, 3.5, TARGET);
      label("backward pass, forward pass — no angles", W / 2, H - 8, null, "center");
    }
  };
});

def("Q", "Quaternion", "chains", "slerp turns a cube the short way; lerping three angles wobbles — press for a new pose", function (u) {
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
  let ea = [0, 0, 0], eb = [rand(-2.2, 2.2), rand(-1.2, 1.2), rand(-2.2, 2.2)];
  let qa = fromEuler(0, 0, 0), qb = fromEuler(eb[0], eb[1], eb[2]);
  let k = 0, restT = 0;
  function retarget() {
    qa = slerp(qa, qb, ease(Math.min(1, k)));          // freeze wherever we are
    ea = ea.map((v, i) => v + (eb[i] - v) * ease(Math.min(1, k)));
    eb = [rand(-2.4, 2.4), rand(-1.3, 1.3), rand(-2.4, 2.4)];
    qb = fromEuler(eb[0], eb[1], eb[2]);
    k = 0;
  }
  function drawCube(q, size, col, lw) {
    const cx = W / 2, cy = H * 0.48, F = 4.2;
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
      if (k >= 1) { restT += dt; if (restT > 1.1) { restT = 0; retarget(); } }
      else k = Math.min(1, k + dt / 1.5);
      const kk = ease(k);
      const ge = ea.map((v, i) => v + (eb[i] - v) * kk);           // the naive route
      drawCube(fromEuler(ge[0], ge[1], ge[2]), H * 0.16, "rgba(232,229,244,0.2)", 1);
      drawCube(slerp(qa, qb, kk), H * 0.16, MOVER, 1.5);           // the quaternion route
      label("bright: slerp(q₁, q₂)   faint: lerping yaw/pitch/roll", W / 2, H - 8, null, "center");
    }
  };
});

/* ============================== BODIES & GROUND ==============================
   Honest physics you can read. VERLET integration stores no velocity at
   all — just where each point is and where it was last frame; the
   difference IS the velocity. Add distance constraints and you get rope,
   ragdolls, and crates; add rays and normals and bodies learn where the
   world is. The last card, Gait, spends everything the other 25 earned. */

def("R", "Ragdoll", "bodies", "verlet points + distance promises = a body — press to shove it", function (u) {
  const { ctx, W, H, GY, TAU, stage, ground, dot, label, len, BONE, MOVER } = u;
  // eleven points, eleven promises. each point remembers only where it is
  // and where it WAS — moving it is "keep drifting the way you were, plus
  // gravity" (verlet integration). then every stick between two points
  // restores its resting length, half from each end, eight times over.
  // out of nothing but that: elbows, slumping, swing. one hand is pinned
  // to a trolley gliding overhead.
  const U = H * 0.062, G = H * 2.6;
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
        p.px -= dx / d * (300 / d);
        p.py -= dy / d * (300 / d);
      }
    },
    frame(dt, t) {
      stage(); ground();
      const ax = W / 2 + Math.sin(t * 0.55) * W * 0.26, ay = H * 0.12;   // the trolley
      for (const p of pts) {
        const vx = (p.x - p.px) * 0.99, vy = (p.y - p.py) * 0.99;
        p.px = p.x; p.py = p.y;
        p.x += vx; p.y += vy + G * dt * dt;
      }
      for (let it = 0; it < 8; it++) {
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
      label("position − last position IS the velocity", W / 2, H - 8, null, "center");
    }
  };
});

def("K", "Knock", "bodies", "impulses: a shockwave edits velocities once, then physics gossips — press anywhere", function (u) {
  const { ctx, W, H, GY, TAU, stage, ground, label, rand, len, BONE, HOT } = u;
  // a FORCE nags a body every frame; an IMPULSE is one hard shove — an
  // instant change of velocity — which is how games spell explosions,
  // hits, and knockback. each crate is four verlet points, four edges and
  // two diagonals (the diagonals are what make it rigid). the shockwave
  // touches nothing but velocity: closer crates inherit more of it.
  const G = H * 2.4;
  function pt(x, y) { return { x: x, y: y, px: x, py: y }; }
  function box(cx, cy, s) {
    const p = [pt(cx - s, cy - s), pt(cx + s, cy - s), pt(cx + s, cy + s), pt(cx - s, cy + s)];
    const c = [];
    const pair = (i, j) => c.push([p[i], p[j], len(p[j].x - p[i].x, p[j].y - p[i].y)]);
    pair(0, 1); pair(1, 2); pair(2, 3); pair(3, 0); pair(0, 2); pair(1, 3);
    return { p: p, c: c };
  }
  const boxes = [box(W * 0.25, GY - 14, 13), box(W * 0.52, GY - 18, 17), box(W * 0.78, GY - 11, 10)];
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
    press(mx, my) { shock(mx, my, 380); },
    frame(dt, t) {
      stage(); ground();
      gustT -= dt;
      if (gustT <= 0) { gustT = rand(3.5, 5.5); shock(rand(0, W), GY - rand(0, 30), 210); }
      for (const bx of boxes) {
        for (const p of bx.p) {
          const vx = (p.x - p.px) * 0.99, vy = (p.y - p.py) * 0.99;
          p.px = p.x; p.py = p.y;
          p.x += vx; p.y += vy + G * dt * dt;
        }
        for (let it = 0; it < 8; it++) {
          for (const c of bx.c) {
            const a = c[0], b = c[1];
            let dx = b.x - a.x, dy = b.y - a.y;
            const d = len(dx, dy) || 1;
            const adjust = (d - c[2]) / d / 2;
            a.x += dx * adjust; a.y += dy * adjust;
            b.x -= dx * adjust; b.y -= dy * adjust;
          }
          for (const p of bx.p) {
            if (p.y > GY - 1) { p.y = GY - 1; p.x -= (p.x - p.px) * 0.55; }
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
      label("impulse ∝ 1/distance — then constraints gossip", W / 2, H - 8, null, "center");
    }
  };
});

def("X", "Xmarks", "bodies", "raycasting: where does this line first hit the world? — press to aim the beam", function (u) {
  const { ctx, W, H, TAU, stage, dot, arrow, label, wrapAngle, clamp, BONE, HOT, GOOD, INK } = u;
  // the ray-plane intersection, in 2D clothing (a wall is a line segment).
  // one denominator test per wall answers "does the beam cross it, and how
  // far along?" — keep the NEAREST hit. the wall's NORMAL (its direction
  // turned 90°) then powers the classic reflection  v − 2(v·n)n, which is
  // the same dot-product maths lasers, bullets, and bank shots all share.
  const segs = [
    [8, 8, W - 8, 8], [W - 8, 8, W - 8, H - 8], [W - 8, H - 8, 8, H - 8], [8, H - 8, 8, 8],
    [W * 0.28, H * 0.3, W * 0.44, H * 0.52], [W * 0.62, H * 0.24, W * 0.78, H * 0.3],
    [W * 0.6, H * 0.7, W * 0.85, H * 0.62]
  ];
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
    press(mx, my) { want = Math.atan2(my - oy, mx - ox); sticky = 3; },
    frame(dt, t) {
      stage();
      sticky -= dt;
      if (sticky <= 0) want = t * 0.6;                 // the idle sweep
      aim += wrapAngle(want - aim) * Math.min(1, 8 * dt);
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
        const dn = dx * hit.nx + dy * hit.ny;          // reflection: v − 2(v·n)n
        const rx = dx - 2 * dn * hit.nx, ry = dy - 2 * dn * hit.ny;
        const hit2 = cast(hit.x + rx, hit.y + ry, rx, ry);
        ctx.strokeStyle = "rgba(245,138,138,0.35)";
        ctx.beginPath(); ctx.moveTo(hit.x, hit.y);
        ctx.lineTo(hit2 ? hit2.x : hit.x + rx * 400, hit2 ? hit2.y : hit.y + ry * 400);
        ctx.stroke();
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
      label("nearest hit · green normal · faint bounce", W / 2, H - 8, null, "center");
    }
  };
});

def("N", "Normals", "bodies", "the slope, turned 90°: a walker that hugs its terrain — press to turn it around", function (u) {
  const { ctx, W, H, TAU, stage, arrow, mote, label, DIM, GOOD } = u;
  // terrain is a function y(x); its DERIVATIVE m is the slope underfoot.
  // the tangent (1, m) points along the hill, and turning it 90° gives
  // the NORMAL — the "straight up off the surface" direction that aligns
  // wheels, feet, and gun turrets to the ground they stand on. (in 3D the
  // 90° turn is done by the cross product of two surface directions.)
  const base = H * 0.62;
  function terra(x) {
    return base - Math.sin(x * 0.021) * H * 0.1 - Math.sin(x * 0.043 + 1.3) * H * 0.055
                - Math.sin(x * 0.011 + 4) * H * 0.07;
  }
  function slope(x) {                                  // the derivative, by hand
    return -Math.cos(x * 0.021) * H * 0.1 * 0.021 - Math.cos(x * 0.043 + 1.3) * H * 0.055 * 0.043
           - Math.cos(x * 0.011 + 4) * H * 0.07 * 0.011;
  }
  let wx = W * 0.2, dir = 1;
  return {
    press() { dir = -dir; },
    frame(dt, t) {
      stage();
      wx += dir * 52 * dt;
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
      label("tangent (1, m) · normal (m, −1) · m = the derivative", W / 2, H - 8, null, "center");
    }
  };
});

def("G", "Gait", "bodies", "the walk that uses it all: homes, thresholds, arcs, and a shifting body — press to send it somewhere", function (u) {
  const { ctx, W, H, GY, TAU, stage, ground, dot, ring, label, clamp, ease, BONE, MOVER, TARGET } = u;
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
  const THIGH = H * 0.17, THRESH = W * 0.1, MAXV = W * 0.36;
  let bx = W * 0.3, vx = 0, tx = W * 0.7, autoT = 0;
  const feet = [{ x: bx - 12, y: GY }, { x: bx + 12, y: GY }];
  let stepping = -1, from = 0, to = 0, k = 0, dur = 0.3;
  return {
    press(px2) { tx = clamp(px2, W * 0.08, W * 0.92); autoT = -8; },
    frame(dt, t) {
      stage(); ground();
      autoT += dt;
      if (autoT > 5) { autoT = 0; tx = W * 0.1 + Math.random() * W * 0.8; }
      const want = clamp((tx - bx) * 2, -MAXV, MAXV);
      vx += (want - vx) * Math.min(1, 5 * dt);
      bx += vx * dt;
      for (let i = 0; i < 2; i++) {
        const home = bx + (i ? 13 : -13) + vx * 0.22;  // led by velocity, not dragged
        if (stepping < 0 && Math.abs(home - feet[i].x) > THRESH) {
          stepping = i; from = feet[i].x; k = 0;
          to = home + vx * 0.1;                        // land a little ahead again
          dur = clamp(0.34 - Math.abs(vx) / MAXV * 0.16, 0.15, 0.34);  // faster walk,
        }                                              // quicker steps — stride timing
      }
      if (stepping >= 0) {
        k += dt / dur;
        const f = feet[stepping];
        f.x = from + (to - from) * ease(k);
        f.y = GY - Math.sin(clamp(k, 0, 1) * Math.PI) * (8 + Math.abs(vx) * 0.05);  // the arc
        if (k >= 1) { f.y = GY; stepping = -1; }
      }
      const planted = stepping >= 0 ? feet[1 - stepping] : null;
      const shift = planted ? (planted.x - bx) * 0.35 : 0;         // weight over the
      const hipX = bx + shift;                                     // standing foot
      const bob = stepping >= 0 ? Math.sin(clamp(k, 0, 1) * Math.PI) * 3 : 0;
      const bodyY = GY - H * 0.27 - bob;
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
      label("step past threshold · sin(k·π) arc · hips shift", W / 2, H - 8, null, "center");
    }
  };
});

/* ============================== the page runner ============================== */

var FAMILY_ORDER = [
  ["clocks", "Clocks & circles", "pure position formulas — sine, polar, phase: motion with no memory"],
  ["springs", "Slopes & springs", "velocity, acceleration, damping — calculus wearing gym clothes"],
  ["steer", "Brains & steering", "seek, wander, flock, fields — how enemies decide where to go"],
  ["chains", "Chains & joints", "limbs that reach and trail — inverse kinematics three ways"],
  ["bodies", "Bodies & ground", "verlet, impulses, rays, normals — and the walk that uses it all"]
];

var grid = document.getElementById("lexicon");
var statusEl = document.getElementById("status");
var runAllBtn = document.getElementById("runall");
var stopAllBtn = document.getElementById("stopall");
var cards = [];

function buildCard(effect) {
  var card = document.createElement("div");
  card.className = "bcard";
  var canvas = document.createElement("canvas");
  canvas.title = effect.name + " — click to wake it, click again to poke it";
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
  small.textContent = list.length + " styles — " + fam[2];
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
window.__lexicon = { EFFECTS: EFFECTS, apiFor: apiFor, cards: cards };
})();
