/* Sparks & Sprites — the elemental button bestiary.
   104 buttons, each a static loop (alive at rest) + a thank-you (press reaction).

   Every effect is one function make(u) that returns { frame(dt, t), press(x, y) }.
   The kit u holds everything the effect may touch, so each one is self-contained
   and can be lifted into the editor (or your own project) as-is:
     ctx            — the 2D canvas context
     W, H           — canvas size in CSS pixels
     B              — the button rectangle: { x, y, w, h, cx, cy, r }
     rand(a, b)     — random number between a and b
     rr(x,y,w,h,r)  — begins a rounded-rect path on ctx
     face(f, s)     — draws the standard button face (fill f, optional stroke s)
     label(txt, c)  — centred caption on the face
     TAU            — one full turn (2π)

   Nothing animates until the visitor presses Run (or clicks a button awake),
   and every button rests again after 60 seconds as a courtesy. */
(function () {
"use strict";
var TAU = Math.PI * 2;

var EFFECTS = [];
function def(name, tag, hint, make) {
  EFFECTS.push({ name: name, tag: tag, hint: hint, make: make });
}

/* Build the kit for one canvas. Called fresh on every start, so effects
   always begin from a clean, correctly-sized surface. */
function apiFor(canvas) {
  var dpr = window.devicePixelRatio || 1;
  var W = canvas.clientWidth, H = canvas.clientHeight;
  canvas.width = Math.round(W * dpr);
  canvas.height = Math.round(H * dpr);
  var ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  var bw = Math.min(W * 0.62, 230), bh = Math.min(H * 0.46, 60);
  var B = { w: bw, h: bh, x: (W - bw) / 2, y: (H - bh) / 2, cx: W / 2, cy: H / 2, r: 14 };
  function rand(a, b) { return a + Math.random() * (b - a); }
  function rr(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }
  function face(fill, stroke) {
    rr(B.x, B.y, B.w, B.h, B.r);
    ctx.fillStyle = fill || "rgba(16,13,28,0.85)";
    ctx.fill();
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1.5; ctx.stroke(); }
  }
  function label(text, fill) {
    ctx.fillStyle = fill || "#EDEBFF";
    ctx.font = "600 " + Math.max(11, Math.round(B.h * 0.3)) + "px system-ui, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(text, B.cx, B.cy + 1);
  }
  return { ctx: ctx, W: W, H: H, B: B, rand: rand, rr: rr, face: face, label: label, TAU: TAU };
}

/* ============================== FIRE ============================== */

def("Candleflame", "fire", "small flames lick the bottom edge; press to flare them tall", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let flare = 0;                          // press → 1, cools back to 0
  const wicks = [];                       // one little flame per wick point
  for (let x = B.x + 10; x < B.x + B.w - 6; x += 14) wicks.push({ x: x, seed: rand(0, 9) });
  return {
    press() { flare = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(30,16,14,0.92)", "rgba(255,160,90,0.5)");
      label("IGNITE", "#FFD9B0");
      ctx.globalCompositeOperation = "lighter";
      for (const wk of wicks) {           // two sine speeds = candle flicker
        const flick = Math.sin(t * 9 + wk.seed) * 0.5 + Math.sin(t * 23 + wk.seed * 3) * 0.5;
        const h = (10 + flick * 3) * (1 + flare * 2.2);
        const y0 = B.y + B.h - 2;
        const g = ctx.createRadialGradient(wk.x, y0, 1, wk.x, y0 - h * 0.4, Math.max(4, h));
        g.addColorStop(0, "rgba(255,220,130,0.8)");
        g.addColorStop(0.5, "rgba(255,120,40,0.35)");
        g.addColorStop(1, "rgba(255,60,20,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.ellipse(wk.x, y0 - h * 0.45, 5, Math.max(2, h * 0.7), 0, 0, TAU); ctx.fill();
      }
      ctx.globalCompositeOperation = "source-over";
      flare = Math.max(0, flare - dt * 1.6);
    }
  };
});

def("Inferno", "fire", "the whole face burns from within; press for an ember burst", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  const flames = [];                      // rising fire blobs, clipped to the face
  let embers = [];                        // press → free-flying embers
  return {
    press() {
      for (let i = 0; i < 22; i++)
        embers.push({ x: rand(B.x, B.x + B.w), y: rand(B.y, B.y + B.h),
                      vx: rand(-70, 70), vy: rand(-140, -30), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("#1C0E0B");
      if (Math.random() < 0.5)
        flames.push({ x: rand(B.x + 6, B.x + B.w - 6), y: B.y + B.h, r: rand(5, 10), life: 1 });
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      ctx.globalCompositeOperation = "lighter";
      for (const f of flames) {           // rise, wobble, shrink, fade — chapter 6's flame
        f.y -= 40 * dt; f.x += Math.sin(f.y * 0.15) * 20 * dt; f.life -= dt * 0.9;
        if (f.life <= 0) continue;
        const r = f.r * (0.4 + f.life);
        const g = ctx.createRadialGradient(f.x, f.y, 0, f.x, f.y, r);
        g.addColorStop(0, "rgba(255,210,110," + 0.55 * f.life + ")");
        g.addColorStop(1, "rgba(255,70,20,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(f.x, f.y, r, 0, TAU); ctx.fill();
      }
      ctx.restore();
      for (let i = flames.length - 1; i >= 0; i--) if (flames[i].life <= 0) flames.splice(i, 1);
      ctx.globalCompositeOperation = "lighter";
      for (const e of embers) {
        e.x += e.vx * dt; e.y += e.vy * dt; e.vy += 60 * dt; e.life -= dt * 1.1;
        if (e.life > 0) { ctx.fillStyle = "rgba(255,180,90," + e.life + ")"; ctx.fillRect(e.x, e.y, 2, 2); }
      }
      embers = embers.filter(e => e.life > 0);
      ctx.globalCompositeOperation = "source-over";
      label("BURN", "#FFE7C2");
      ctx.strokeStyle = "rgba(255,120,50,0.6)"; ctx.lineWidth = 1.5;
      rr(B.x, B.y, B.w, B.h, B.r); ctx.stroke();
    }
  };
});

def("Ember bed", "fire", "coals pulse under a dark crust; press to stoke them", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let stoke = 0;
  const coals = [];
  for (let i = 0; i < 26; i++)
    coals.push({ x: rand(B.x + 8, B.x + B.w - 8), y: rand(B.y + 8, B.y + B.h - 8),
                 r: rand(2, 5), ph: rand(0, TAU), sp: rand(0.6, 1.6) });
  let sparks = [];
  return {
    press() {
      stoke = 1;
      for (let i = 0; i < 8; i++)
        sparks.push({ x: rand(B.x, B.x + B.w), y: B.y + rand(0, B.h), vy: rand(-60, -25), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("#191014", "rgba(120,60,40,0.6)");
      ctx.globalCompositeOperation = "lighter";
      for (const c of coals) {            // each coal breathes at its own pace
        const a = Math.max(0, (0.25 + 0.35 * Math.sin(t * c.sp + c.ph)) + stoke * 0.5);
        const g = ctx.createRadialGradient(c.x, c.y, 0, c.x, c.y, c.r * (2 + stoke * 2));
        g.addColorStop(0, "rgba(255,140,60," + a + ")");
        g.addColorStop(1, "rgba(200,40,10,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(c.x, c.y, c.r * (2 + stoke * 2), 0, TAU); ctx.fill();
      }
      for (const s of sparks) {
        s.y += s.vy * dt; s.x += Math.sin(s.y * 0.2) * 12 * dt; s.life -= dt * 1.4;
        if (s.life > 0) { ctx.fillStyle = "rgba(255,200,120," + s.life + ")"; ctx.fillRect(s.x, s.y, 2, 2); }
      }
      sparks = sparks.filter(s => s.life > 0);
      ctx.globalCompositeOperation = "source-over";
      label("STOKE", "rgba(255,220,190," + (0.75 + stoke * 0.25) + ")");
      stoke = Math.max(0, stoke - dt * 1.2);
    }
  };
});

def("Fireball", "fire", "a fireball orbits with a tail; press and it dives through the centre", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  const tail = [];                        // recent positions = the tail
  let dive = 0;                           // >0 while diving through the button
  let boom = [];
  return {
    press() { if (dive <= 0) dive = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const a = t * 2.2;
      let fx, fy;
      if (dive > 0) {                     // straight line through the centre
        dive -= dt * 1.4;
        const p = 1 - Math.max(0, dive);  // 0 → 1 across the dive
        fx = (B.cx - B.w) + p * B.w * 2; fy = B.cy;
        if (Math.abs(fx - B.cx) < 8 && boom.length === 0)
          for (let i = 0; i < 16; i++) {
            const th = rand(0, TAU);
            boom.push({ x: B.cx, y: B.cy, vx: Math.cos(th) * rand(40, 130), vy: Math.sin(th) * rand(40, 130), life: 1 });
          }
      } else {
        fx = B.cx + Math.cos(a) * (B.w * 0.62);
        fy = B.cy + Math.sin(a) * (B.h * 1.05);
      }
      tail.unshift({ x: fx, y: fy });
      if (tail.length > 22) tail.pop();
      face("rgba(24,14,20,0.9)", "rgba(255,150,80,0.45)");
      label("COMET", "#FFDFC0");
      ctx.globalCompositeOperation = "lighter";
      for (let i = tail.length - 1; i >= 0; i--) {
        const k = 1 - i / tail.length;    // head bright, tail faint
        const g = ctx.createRadialGradient(tail[i].x, tail[i].y, 0, tail[i].x, tail[i].y, 6 + k * 8);
        g.addColorStop(0, "rgba(255,220,140," + 0.5 * k + ")");
        g.addColorStop(1, "rgba(255,80,20,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(tail[i].x, tail[i].y, 6 + k * 8, 0, TAU); ctx.fill();
      }
      for (const b of boom) {
        b.x += b.vx * dt; b.y += b.vy * dt; b.life -= dt * 1.6;
        if (b.life > 0) { ctx.fillStyle = "rgba(255,190,110," + b.life + ")"; ctx.fillRect(b.x, b.y, 2.5, 2.5); }
      }
      boom = boom.filter(b => b.life > 0);
      if (dive <= 0 && boom.length === 0) dive = 0;
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Backdraft", "fire", "smoke curls quietly… press to ignite the whoosh", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  let smoke = [], fire = [], whoosh = 0;
  return {
    press() { whoosh = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,16,24,0.92)", "rgba(160,150,170,0.35)");
      label("BACKDRAFT", "#D8D2E0");
      if (Math.random() < 0.12)
        smoke.push({ x: rand(B.x + 10, B.x + B.w - 10), y: B.y + 4, r: rand(3, 6), life: 1 });
      for (const s of smoke) {            // lazy grey curls off the top edge
        s.y -= 14 * dt; s.x += Math.sin(s.y * 0.1 + s.r) * 10 * dt;
        s.r += 4 * dt; s.life -= dt * 0.5;
        if (s.life > 0) {
          ctx.fillStyle = "rgba(150,150,160," + 0.13 * s.life + ")";
          ctx.beginPath(); ctx.arc(s.x, s.y, s.r, 0, TAU); ctx.fill();
        }
      }
      smoke = smoke.filter(s => s.life > 0);
      if (whoosh > 0) {                   // the ignition: fire floods upward once
        whoosh -= dt * 0.9;
        if (Math.random() < 0.9)
          fire.push({ x: rand(B.x, B.x + B.w), y: B.y + B.h, r: rand(6, 12), life: 1 });
      }
      ctx.save();
      rr(B.x - 4, B.y - 26, B.w + 8, B.h + 30, B.r); ctx.clip();
      ctx.globalCompositeOperation = "lighter";
      for (const f of fire) {
        f.y -= 90 * dt; f.life -= dt * 1.3;
        if (f.life <= 0) continue;
        const g = ctx.createRadialGradient(f.x, f.y, 0, f.x, f.y, f.r);
        g.addColorStop(0, "rgba(255,200,100," + 0.6 * f.life + ")");
        g.addColorStop(1, "rgba(255,60,10,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(f.x, f.y, f.r, 0, TAU); ctx.fill();
      }
      ctx.restore();
      ctx.globalCompositeOperation = "source-over";
      fire = fire.filter(f => f.life > 0);
    }
  };
});

def("Heat haze", "fire", "the caption shimmers like air over asphalt; press for a heat wave", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  let wave = 0;                           // press → a strong ripple passes through
  return {
    press() { wave = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(34,20,14,0.92)", "rgba(255,140,70,0.45)");
      // draw the label in thin horizontal strips, each pushed sideways a little
      const strips = 8, sh = B.h / strips;
      for (let i = 0; i < strips; i++) {
        const y0 = B.y + i * sh;
        const off = Math.sin(t * 6 + i * 1.1) * (0.8 + wave * 5);
        ctx.save();
        ctx.beginPath(); ctx.rect(B.x, y0, B.w, sh + 0.5); ctx.clip();
        ctx.translate(off, 0);
        label("MIRAGE", "#FFC9A0");
        ctx.restore();
      }
      ctx.globalCompositeOperation = "lighter";  // faint rising warmth above the face
      for (let i = 0; i < 3; i++) {
        const hx = B.x + B.w * (0.25 + i * 0.25) + Math.sin(t * 3 + i * 2) * 6;
        const hy = B.y - 6 - ((t * 18 + i * 13) % 22);
        ctx.fillStyle = "rgba(255,160,80,0.05)";
        ctx.beginPath(); ctx.arc(hx, hy, 8, 0, u.TAU); ctx.fill();
      }
      ctx.globalCompositeOperation = "source-over";
      wave = Math.max(0, wave - dt * 2.2);
    }
  };
});

def("Solar flare", "fire", "prominences erupt off the rim; press for a coronal mass ejection", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let arcs = [];
  function erupt(big) {
    const th = rand(0, TAU);
    const x0 = B.cx + Math.cos(th) * B.w * 0.5, y0 = B.cy + Math.sin(th) * B.h * 0.62;
    arcs.push({ x0: x0, y0: y0, th: th, h: big ? rand(28, 44) : rand(10, 20), life: 1, big: big });
  }
  return {
    press() { for (let i = 0; i < 4; i++) erupt(true); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      ctx.globalCompositeOperation = "lighter";  // the sun's rim glow
      const g = ctx.createRadialGradient(B.cx, B.cy, B.w * 0.28, B.cx, B.cy, B.w * 0.62);
      g.addColorStop(0, "rgba(255,140,40,0.35)");
      g.addColorStop(1, "rgba(255,60,10,0)");
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, W, H);
      if (Math.random() < 0.03) erupt(false);
      for (const a of arcs) {             // each prominence is one quadratic loop
        a.life -= dt * (a.big ? 0.55 : 0.9);
        if (a.life <= 0) continue;
        const lift = a.h * Math.sin(Math.min(1, 1 - a.life) * Math.PI);
        const nx = Math.cos(a.th), ny = Math.sin(a.th);
        ctx.strokeStyle = "rgba(255,170,70," + 0.7 * a.life + ")";
        ctx.lineWidth = a.big ? 2.5 : 1.5;
        ctx.beginPath();
        ctx.moveTo(a.x0 - ny * 8, a.y0 + nx * 8);
        ctx.quadraticCurveTo(a.x0 + nx * lift, a.y0 + ny * lift, a.x0 + ny * 8, a.y0 - nx * 8);
        ctx.stroke();
      }
      arcs = arcs.filter(a => a.life > 0);
      ctx.globalCompositeOperation = "source-over";
      face("rgba(40,16,8,0.9)", "rgba(255,170,80,0.7)");
      label("FLARE", "#FFE2B8");
    }
  };
});

def("Magma veins", "fire", "lava glows through cracks in dark crust; press to surge", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  let surge = 0;
  const veins = [];                       // each vein: a jagged polyline across the face
  for (let v = 0; v < 4; v++) {
    const pts = [];
    let x = B.x, y = rand(B.y + 6, B.y + B.h - 6);
    while (x < B.x + B.w) {
      pts.push({ x: x, y: y });
      x += rand(10, 22); y += rand(-8, 8);
      y = Math.min(B.y + B.h - 4, Math.max(B.y + 4, y));
    }
    pts.push({ x: B.x + B.w, y: y });
    veins.push({ pts: pts, ph: rand(0, 9) });
  }
  return {
    press() { surge = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("#171017");
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      ctx.lineCap = "round";
      for (const v of veins) {            // glow crawls along each vein
        for (let i = 0; i < v.pts.length - 1; i++) {
          const a = Math.max(0.08, 0.5 + 0.5 * Math.sin(t * 2 + v.ph + i * 0.7)) * (0.5 + surge);
          ctx.strokeStyle = "rgba(255," + Math.round(90 + surge * 90) + ",30," + Math.min(1, a) + ")";
          ctx.lineWidth = 1.5 + surge * 2 + Math.sin(t * 3 + i) * 0.5;
          ctx.beginPath();
          ctx.moveTo(v.pts[i].x, v.pts[i].y);
          ctx.lineTo(v.pts[i + 1].x, v.pts[i + 1].y);
          ctx.stroke();
        }
      }
      ctx.restore();
      label("MAGMA", "rgba(255,215,180,0.9)");
      surge = Math.max(0, surge - dt * 1.1);
    }
  };
});

def("Meteor watch", "fire", "shooting stars streak past; press to call a shower", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  let meteors = [], timer = 0;
  const stars = [];
  for (let i = 0; i < 30; i++) stars.push({ x: rand(0, W), y: rand(0, H), a: rand(0.1, 0.5) });
  function spawn() {
    meteors.push({ x: rand(-20, W * 0.7), y: rand(-20, H * 0.3), v: rand(160, 260), life: 1 });
  }
  return {
    press() { for (let i = 0; i < 6; i++) spawn(); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      for (const s of stars) { ctx.fillStyle = "rgba(220,220,255," + s.a + ")"; ctx.fillRect(s.x, s.y, 1.5, 1.5); }
      timer -= dt;
      if (timer <= 0) { spawn(); timer = rand(1.5, 3.5); }
      ctx.globalCompositeOperation = "lighter";
      for (const m of meteors) {          // 45° streak with a gradient tail
        m.x += m.v * dt; m.y += m.v * 0.55 * dt; m.life -= dt * 0.7;
        if (m.life <= 0) continue;
        const g = ctx.createLinearGradient(m.x, m.y, m.x - 34, m.y - 19);
        g.addColorStop(0, "rgba(255,230,180," + 0.9 * m.life + ")");
        g.addColorStop(1, "rgba(255,120,40,0)");
        ctx.strokeStyle = g; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(m.x, m.y); ctx.lineTo(m.x - 34, m.y - 19); ctx.stroke();
      }
      ctx.globalCompositeOperation = "source-over";
      meteors = meteors.filter(m => m.life > 0 && m.x < W + 40 && m.y < H + 40);
      face("rgba(18,14,30,0.88)", "rgba(255,190,120,0.5)");
      label("WISH", "#FFE9CC");
    }
  };
});

def("Phoenix", "fire", "flame feathers spiral upward; press and the wings beat out", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let feathers = [], wings = 0;
  return {
    press() { wings = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      if (Math.random() < 0.35)
        feathers.push({ a: rand(0, TAU), y: B.cy + B.h * 0.6, spin: rand(1.5, 3), life: 1 });
      face("rgba(28,12,16,0.9)", "rgba(255,120,60,0.55)");
      label("RISE", "#FFD7B0");
      ctx.globalCompositeOperation = "lighter";
      for (const f of feathers) {         // spiral: angle turns while the point climbs
        f.a += f.spin * dt; f.y -= 26 * dt; f.life -= dt * 0.6;
        if (f.life <= 0) continue;
        const rx = B.w * 0.55, x = B.cx + Math.cos(f.a) * rx;
        ctx.fillStyle = "rgba(255," + Math.round(120 + 100 * f.life) + ",60," + 0.5 * f.life + ")";
        ctx.beginPath(); ctx.ellipse(x, f.y, 2.2, 6, Math.sin(f.a) * 0.6, 0, TAU); ctx.fill();
      }
      if (wings > 0) {                    // two flame arcs sweep out like wingbeats
        wings -= dt * 1.1;
        const spread = (1 - Math.max(0, wings)) * B.w * 0.85;
        for (const side of [-1, 1]) {
          ctx.strokeStyle = "rgba(255,150,60," + Math.max(0, wings) * 0.8 + ")";
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.moveTo(B.cx, B.cy);
          ctx.quadraticCurveTo(B.cx + side * spread * 0.7, B.cy - B.h * 1.3,
                               B.cx + side * spread, B.cy - B.h * 0.2);
          ctx.stroke();
        }
      }
      feathers = feathers.filter(f => f.life > 0);
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

/* ============================== LIGHTNING ============================== */

def("Static charge", "lightning", "tiny crackles bite the edges; press for a bolt across the face", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  let crackles = [], bolt = null, flash = 0;
  function edgePoint() {                  // a random spot on the button's border
    const side = Math.floor(rand(0, 4));
    if (side === 0) return { x: rand(B.x, B.x + B.w), y: B.y };
    if (side === 1) return { x: rand(B.x, B.x + B.w), y: B.y + B.h };
    if (side === 2) return { x: B.x, y: rand(B.y, B.y + B.h) };
    return { x: B.x + B.w, y: rand(B.y, B.y + B.h) };
  }
  return {
    press() {
      flash = 1;
      const pts = [{ x: B.x - 6, y: B.cy }];
      let x = B.x;                        // jagged march, left edge to right edge
      while (x < B.x + B.w) { x += rand(10, 20); pts.push({ x: x, y: B.cy + rand(-14, 14) }); }
      pts.push({ x: B.x + B.w + 6, y: B.cy });
      bolt = { pts: pts, life: 1 };
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(16,18,34,0.92)", "rgba(140,170,255," + (0.4 + flash * 0.6) + ")");
      label("CHARGE", "#D6E0FF");
      if (Math.random() < 0.25) {
        const p = edgePoint();
        crackles.push({ x: p.x, y: p.y, life: 0.18 });
      }
      ctx.globalCompositeOperation = "lighter";
      for (const c of crackles) {         // three-segment micro-bolts
        c.life -= dt;
        if (c.life <= 0) continue;
        ctx.strokeStyle = "rgba(180,210,255,0.9)"; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(c.x, c.y);
        let px = c.x, py = c.y;
        for (let i = 0; i < 3; i++) { px += rand(-6, 6); py += rand(-6, 6); ctx.lineTo(px, py); }
        ctx.stroke();
      }
      crackles = crackles.filter(c => c.life > 0);
      if (bolt) {
        bolt.life -= dt * 3;
        if (bolt.life > 0) {
          ctx.strokeStyle = "rgba(220,235,255," + bolt.life + ")"; ctx.lineWidth = 2.5;
          ctx.beginPath(); ctx.moveTo(bolt.pts[0].x, bolt.pts[0].y);
          for (const p of bolt.pts) ctx.lineTo(p.x + rand(-1, 1), p.y + rand(-1, 1));
          ctx.stroke();
        } else bolt = null;
      }
      ctx.globalCompositeOperation = "source-over";
      flash = Math.max(0, flash - dt * 3);
    }
  };
});

def("Tesla ring", "lightning", "an arc dances between button and outer ring; press fires them all", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let burst = 0;
  function arcAt(theta, bright) {         // jagged line: face border → outer ring
    const x0 = B.cx + Math.cos(theta) * B.w * 0.48, y0 = B.cy + Math.sin(theta) * B.h * 0.52;
    const x1 = B.cx + Math.cos(theta) * B.w * 0.72, y1 = B.cy + Math.sin(theta) * B.h * 1.05;
    ctx.strokeStyle = "rgba(170,200,255," + bright + ")";
    ctx.lineWidth = 1.4;
    ctx.beginPath(); ctx.moveTo(x0, y0);
    for (let i = 1; i <= 4; i++) {
      const k = i / 4;
      ctx.lineTo(x0 + (x1 - x0) * k + rand(-3, 3), y0 + (y1 - y0) * k + rand(-3, 3));
    }
    ctx.stroke();
  }
  return {
    press() { burst = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      ctx.strokeStyle = "rgba(120,150,230,0.35)"; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.ellipse(B.cx, B.cy, B.w * 0.72, B.h * 1.05, 0, 0, TAU); ctx.stroke();
      face("rgba(14,16,30,0.92)", "rgba(150,180,255,0.6)");
      label("TESLA", "#DCE6FF");
      ctx.globalCompositeOperation = "lighter";
      arcAt(t * 1.6, 0.8);                // the dancer makes its rounds
      if (Math.random() < 0.05) arcAt(rand(0, TAU), 0.6);
      if (burst > 0) {
        for (let i = 0; i < 8; i++) arcAt(i / 8 * TAU + t, burst);
        burst = Math.max(0, burst - dt * 2.2);
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Storm cloud", "lightning", "a cloud broods overhead; press and it strikes the button", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let strike = 0, flicker = 0;
  const puffs = [];
  for (let i = 0; i < 5; i++)
    puffs.push({ dx: (i - 2) * 13, dy: rand(-4, 4), r: rand(9, 14) });
  return {
    press() { strike = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const cy = B.y - 22 + Math.sin(t * 0.8) * 2;
      if (Math.random() < 0.01) flicker = 0.5;    // the cloud mutters to itself
      if (flicker > 0) {
        ctx.globalCompositeOperation = "lighter";
        ctx.fillStyle = "rgba(190,200,255," + flicker * 0.5 + ")";
        ctx.beginPath(); ctx.arc(B.cx + rand(-14, 14), cy, 16, 0, TAU); ctx.fill();
        ctx.globalCompositeOperation = "source-over";
        flicker = Math.max(0, flicker - dt * 2);
      }
      for (const p of puffs) {
        ctx.fillStyle = "rgba(90,95,120,0.9)";
        ctx.beginPath(); ctx.arc(B.cx + p.dx, cy + p.dy, p.r, 0, TAU); ctx.fill();
      }
      const hit = strike > 0.55;          // bolt exists for the first beat of the strike
      face(hit ? "rgba(120,130,180,0.95)" : "rgba(20,20,36,0.92)",
           "rgba(150,170,255," + (0.4 + strike * 0.6) + ")");
      label("STORM", hit ? "#10122A" : "#D8DFFF");
      if (hit) {
        ctx.globalCompositeOperation = "lighter";
        ctx.strokeStyle = "rgba(230,240,255," + strike + ")"; ctx.lineWidth = 2.5;
        ctx.beginPath(); ctx.moveTo(B.cx + rand(-6, 6), cy + 10);
        let px = B.cx, py = cy + 10;
        while (py < B.y) { px += rand(-8, 8); py += rand(5, 10); ctx.lineTo(px, py); }
        ctx.stroke();
        ctx.globalCompositeOperation = "source-over";
      }
      strike = Math.max(0, strike - dt * 1.8);
    }
  };
});

def("Circuit trace", "lightning", "pulses travel etched copper paths; press to send them all at once", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  const paths = [];                       // manhattan wires with measured lengths
  for (let p = 0; p < 5; p++) {
    const pts = [{ x: B.x, y: rand(B.y + 6, B.y + B.h - 6) }];
    let x = B.x;
    while (x < B.x + B.w - 12) {
      x += rand(16, 34);
      pts.push({ x: Math.min(x, B.x + B.w), y: pts[pts.length - 1].y });
      if (Math.random() < 0.7 && x < B.x + B.w - 12) {
        const ny = rand(B.y + 6, B.y + B.h - 6);
        pts.push({ x: Math.min(x, B.x + B.w), y: ny });
      }
    }
    let len = 0;
    const seg = [0];
    for (let i = 1; i < pts.length; i++) {
      len += Math.abs(pts[i].x - pts[i - 1].x) + Math.abs(pts[i].y - pts[i - 1].y);
      seg.push(len);
    }
    paths.push({ pts: pts, seg: seg, len: len, d: rand(0, len), v: rand(30, 60) });
  }
  function pointAt(path, d) {             // walk the wire to distance d
    for (let i = 1; i < path.pts.length; i++) {
      if (d <= path.seg[i]) {
        const k = (d - path.seg[i - 1]) / Math.max(1e-6, path.seg[i] - path.seg[i - 1]);
        return { x: path.pts[i - 1].x + (path.pts[i].x - path.pts[i - 1].x) * k,
                 y: path.pts[i - 1].y + (path.pts[i].y - path.pts[i - 1].y) * k };
      }
    }
    return path.pts[path.pts.length - 1];
  }
  let surge = 0;
  return {
    press() { surge = 1; for (const p of paths) p.d = 0; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("#0E1A16", "rgba(90,220,170," + (0.4 + surge * 0.6) + ")");
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      for (const p of paths) {
        ctx.strokeStyle = "rgba(70,160,120," + (0.35 + surge * 0.4) + ")";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(p.pts[0].x, p.pts[0].y);
        for (const q of p.pts) ctx.lineTo(q.x, q.y);
        ctx.stroke();
        p.d += p.v * (1 + surge * 3) * dt;
        if (p.d > p.len) p.d = 0;
        const pos = pointAt(p, p.d);
        ctx.globalCompositeOperation = "lighter";
        ctx.fillStyle = "rgba(140,255,200," + (0.8 + surge * 0.2) + ")";
        ctx.fillRect(pos.x - 1.5, pos.y - 1.5, 3, 3);
        ctx.globalCompositeOperation = "source-over";
      }
      ctx.restore();
      label("BOOT", "#C8F5E2");
      surge = Math.max(0, surge - dt * 0.9);
    }
  };
});

def("Plasma globe", "lightning", "filaments wander from the core; press and they chase your finger", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  const fils = [];
  for (let i = 0; i < 6; i++) fils.push({ a: rand(0, TAU), va: rand(-0.8, 0.8) });
  let target = null, hold = 0;
  return {
    press(x, y) { target = { x: x, y: y }; hold = 0.9; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,10,30,0.92)", "rgba(220,140,255,0.5)");
      ctx.globalCompositeOperation = "lighter";
      const g = ctx.createRadialGradient(B.cx, B.cy, 0, B.cx, B.cy, 16);
      g.addColorStop(0, "rgba(255,190,255,0.9)");
      g.addColorStop(1, "rgba(200,80,255,0)");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(B.cx, B.cy, 16, 0, TAU); ctx.fill();
      hold = Math.max(0, hold - dt);
      if (hold <= 0) target = null;
      for (const f of fils) {             // each filament: a jagged reach for the rim
        f.a += f.va * dt;
        let ex, ey;
        if (target) { ex = target.x + rand(-4, 4); ey = target.y + rand(-4, 4); }
        else { ex = B.cx + Math.cos(f.a) * B.w * 0.48; ey = B.cy + Math.sin(f.a) * B.h * 0.5; }
        ctx.strokeStyle = "rgba(235,170,255," + (target ? 0.95 : 0.55) + ")";
        ctx.lineWidth = 1.2;
        ctx.beginPath(); ctx.moveTo(B.cx, B.cy);
        for (let k = 1; k <= 5; k++) {
          const q = k / 5;
          ctx.lineTo(B.cx + (ex - B.cx) * q + rand(-4, 4) * Math.sin(q * Math.PI),
                     B.cy + (ey - B.cy) * q + rand(-4, 4) * Math.sin(q * Math.PI));
        }
        ctx.stroke();
      }
      ctx.globalCompositeOperation = "source-over";
      label("PLASMA", "#F3D9FF");
    }
  };
});

def("Neon flicker", "lightning", "a buzzing neon tube border; press to steady it for a moment", function (u) {
  const { ctx, W, H, B, rand, rr, label } = u;
  let dropout = 0, steady = 0;
  return {
    press() { steady = 2; dropout = 0; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      if (steady <= 0 && dropout <= 0 && Math.random() < 0.02) dropout = rand(0.04, 0.16);
      dropout = Math.max(0, dropout - dt);
      steady = Math.max(0, steady - dt);
      const buzz = steady > 0 ? 1 : 0.82 + Math.sin(t * 120) * 0.06;  // mains hum
      const on = dropout <= 0 ? buzz : 0.08;
      ctx.globalCompositeOperation = "lighter";
      rr(B.x, B.y, B.w, B.h, B.r);
      ctx.strokeStyle = "rgba(255,80,180," + on * 0.25 + ")"; ctx.lineWidth = 9; ctx.stroke();
      rr(B.x, B.y, B.w, B.h, B.r);
      ctx.strokeStyle = "rgba(255,170,220," + on + ")"; ctx.lineWidth = 2; ctx.stroke();
      label("OPEN", "rgba(255,190,230," + on + ")");
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("EMP", "lightning", "shockwave rings pulse outward; press for the big one", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let rings = [], timer = 1, sparks = [];
  return {
    press() {
      rings.push({ r: 6, v: 120, life: 1, big: true });
      for (let i = 0; i < 10; i++) {
        const th = rand(0, TAU);
        sparks.push({ x: B.cx, y: B.cy, vx: Math.cos(th) * rand(60, 150), vy: Math.sin(th) * rand(60, 150), life: 1 });
      }
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(12,20,26,0.92)", "rgba(120,230,255,0.5)");
      label("PULSE", "#CFF4FF");
      timer -= dt;
      if (timer <= 0) { rings.push({ r: 6, v: 60, life: 1, big: false }); timer = 2.5; }
      ctx.globalCompositeOperation = "lighter";
      for (const ring of rings) {         // 12-sided ring with electric jitter
        ring.r += ring.v * dt; ring.life -= dt * (ring.big ? 0.7 : 1);
        if (ring.life <= 0) continue;
        ctx.strokeStyle = "rgba(140,235,255," + ring.life * (ring.big ? 0.95 : 0.5) + ")";
        ctx.lineWidth = ring.big ? 2.5 : 1.2;
        ctx.beginPath();
        for (let i = 0; i <= 12; i++) {
          const th = i / 12 * TAU, j = Math.sin(t * 40 + i * 7) * 2;
          const px = B.cx + Math.cos(th) * (ring.r + j) * 1.4;
          const py = B.cy + Math.sin(th) * (ring.r + j) * 0.75;
          if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        }
        ctx.stroke();
      }
      for (const s of sparks) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt * 1.8;
        if (s.life > 0) { ctx.fillStyle = "rgba(180,240,255," + s.life + ")"; ctx.fillRect(s.x, s.y, 2, 2); }
      }
      ctx.globalCompositeOperation = "source-over";
      rings = rings.filter(r => r.life > 0);
      sparks = sparks.filter(s => s.life > 0);
    }
  };
});

def("Van de Graaff", "lightning", "charged hairs wave off the top edge; press to discharge", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  const hairs = [];
  for (let x = B.x + 8; x < B.x + B.w - 6; x += 9)
    hairs.push({ x: x, len: rand(10, 20), ph: rand(0, 9) });
  let zap = 0;
  return {
    press() { zap = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(24,20,32,0.92)", "rgba(200,190,255,0.5)");
      label("HAIR-RAISER", "#E4DEFF");
      ctx.globalCompositeOperation = "lighter";
      for (const hair of hairs) {
        const sway = zap > 0 ? rand(-10, 10)                       // discharge: chaos
                             : Math.sin(t * 2 + hair.ph) * 5;      // idle: gentle wave
        const a = zap > 0 ? 0.9 : 0.45;
        ctx.strokeStyle = "rgba(210,200,255," + a + ")";
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(hair.x, B.y + 1);
        ctx.quadraticCurveTo(hair.x + sway * 0.5, B.y - hair.len * 0.6,
                             hair.x + sway, B.y - hair.len * (zap > 0 ? 1.5 : 1));
        ctx.stroke();
        if (zap > 0 && Math.random() < 0.2) {
          ctx.fillStyle = "rgba(255,255,255," + zap + ")";
          ctx.fillRect(hair.x + sway - 1, B.y - hair.len - rand(0, 8), 2, 2);
        }
      }
      ctx.globalCompositeOperation = "source-over";
      zap = Math.max(0, zap - dt * 2.5);
    }
  };
});

/* ============================== WATER ============================== */

def("Bubble tank", "water", "bubbles wobble upward inside; press to pop them all", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  let bubbles = [], pops = [];
  function spawn(atBottom) {
    bubbles.push({ x: rand(B.x + 8, B.x + B.w - 8),
                   y: atBottom ? B.y + B.h - 4 : rand(B.y + 8, B.y + B.h - 4),
                   r: rand(2, 6), ph: rand(0, 9) });
  }
  for (let i = 0; i < 10; i++) spawn(false);
  return {
    press() {
      for (const b of bubbles) pops.push({ x: b.x, y: b.y, r: b.r, life: 1 });
      bubbles = [];
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(10,26,40,0.94)", "rgba(110,190,230,0.5)");
      if (bubbles.length < 10 && Math.random() < 0.15) spawn(true);
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      for (const b of bubbles) {          // rise + sideways wobble
        b.y -= (8 + b.r * 2) * dt;
        const x = b.x + Math.sin(t * 2 + b.ph) * 3;
        if (b.y < B.y + b.r) { pops.push({ x: x, y: B.y + b.r, r: b.r, life: 1 }); b.y = -99; continue; }
        ctx.strokeStyle = "rgba(170,220,250,0.7)"; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(x, b.y, b.r, 0, TAU); ctx.stroke();
        ctx.strokeStyle = "rgba(255,255,255,0.8)";  // the little highlight arc
        ctx.beginPath(); ctx.arc(x - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.4, -2.4, -0.8); ctx.stroke();
      }
      bubbles = bubbles.filter(b => b.y > 0);
      for (const p of pops) {             // a pop is an expanding broken ring
        p.life -= dt * 3; p.r += 14 * dt;
        if (p.life <= 0) continue;
        ctx.strokeStyle = "rgba(220,245,255," + p.life + ")"; ctx.lineWidth = 1;
        for (let k = 0; k < 4; k++) {
          ctx.beginPath(); ctx.arc(p.x, p.y, p.r, k * 1.7, k * 1.7 + 0.9); ctx.stroke();
        }
      }
      pops = pops.filter(p => p.life > 0);
      ctx.restore();
      label("AQUARIUM", "#CFEFFF");
    }
  };
});

def("Fizz", "water", "champagne streams of micro-bubbles; press to overflow with foam", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  let fizz = [], foam = [];
  const jets = [];
  for (let i = 0; i < 4; i++) jets.push(B.x + B.w * (0.18 + i * 0.21));
  return {
    press() {
      for (let i = 0; i < 26; i++)
        foam.push({ x: rand(B.x, B.x + B.w), y: B.y + rand(-2, 4),
                    vx: rand(-24, 24), vy: rand(-50, -10), r: rand(2, 4.5), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(40,30,10,0.9)", "rgba(255,220,140,0.5)");
      for (const jx of jets)
        if (Math.random() < 0.7) fizz.push({ x: jx + rand(-2, 2), y: B.y + B.h - 3, life: 1 });
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      for (const f of fizz) {
        f.y -= 55 * dt; f.x += Math.sin(f.y * 0.4) * 6 * dt; f.life -= dt * 0.8;
        if (f.life > 0 && f.y > B.y) {
          ctx.fillStyle = "rgba(255,240,190," + 0.6 * f.life + ")";
          ctx.fillRect(f.x, f.y, 1.5, 1.5);
        }
      }
      ctx.restore();
      fizz = fizz.filter(f => f.life > 0 && f.y > B.y - 2);
      for (const p of foam) {             // foam escapes the glass — no clip
        p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 30 * dt; p.life -= dt * 0.9;
        if (p.life > 0) {
          ctx.fillStyle = "rgba(255,250,235," + 0.7 * p.life + ")";
          ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, TAU); ctx.fill();
        }
      }
      foam = foam.filter(p => p.life > 0);
      label("CHEERS", "#FFF2CE");
    }
  };
});

def("Ripple pool", "water", "the face is still water; press to drop a stone in", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  let rings = [], timer = 2;
  return {
    press(x, y) {
      const cx = Math.min(B.x + B.w, Math.max(B.x, x));
      const cy = Math.min(B.y + B.h, Math.max(B.y, y));
      rings.push({ x: cx, y: cy, r: 2, life: 1, big: true });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const g = ctx.createLinearGradient(0, B.y, 0, B.y + B.h);
      g.addColorStop(0, "#10344A");
      g.addColorStop(1, "#0A2033");
      face(g, "rgba(140,200,230,0.5)");
      timer -= dt;
      if (timer <= 0) {                   // the pool ripples on its own, gently
        rings.push({ x: rand(B.x + 10, B.x + B.w - 10), y: rand(B.y + 8, B.y + B.h - 8), r: 1, life: 0.6, big: false });
        timer = rand(1.5, 3);
      }
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      for (const ring of rings) {         // concentric ellipses, squashed = perspective
        ring.r += (ring.big ? 40 : 16) * dt; ring.life -= dt * (ring.big ? 0.8 : 0.5);
        if (ring.life <= 0) continue;
        ctx.strokeStyle = "rgba(190,230,250," + ring.life * 0.8 + ")";
        ctx.lineWidth = ring.big ? 1.8 : 1;
        for (let k = 0; k < 2; k++) {
          ctx.beginPath();
          ctx.ellipse(ring.x, ring.y, Math.max(0.5, ring.r - k * 6), Math.max(0.3, (ring.r - k * 6) * 0.45), 0, 0, u.TAU);
          ctx.stroke();
        }
      }
      ctx.restore();
      rings = rings.filter(r => r.life > 0);
      const wob = rings.some(r => r.big) ? Math.sin(t * 20) * 1.5 : 0;
      ctx.save(); ctx.translate(0, wob);
      label("POND", "#D8F0FC");
      ctx.restore();
    }
  };
});

def("Rain on glass", "water", "droplets bead and run; press to sweep the wiper", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  let drops = [], wiper = -1;
  for (let i = 0; i < 18; i++)
    drops.push({ x: rand(B.x + 4, B.x + B.w - 4), y: rand(B.y + 4, B.y + B.h - 4), r: rand(1, 3), run: 0 });
  return {
    press() { wiper = 0; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(16,26,38,0.94)", "rgba(150,190,220,0.5)");
      label("DRIZZLE", "rgba(210,230,245,0.85)");
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      if (drops.length < 22 && Math.random() < 0.2)
        drops.push({ x: rand(B.x + 4, B.x + B.w - 4), y: rand(B.y + 4, B.y + B.h - 4), r: rand(1, 3), run: 0 });
      for (const d of drops) {
        if (d.run <= 0 && Math.random() < 0.005) d.run = rand(0.5, 1.2);
        if (d.run > 0) {                  // a heavy drop breaks loose and slides
          d.run -= dt; d.y += 30 * dt; d.x += Math.sin(d.y * 0.5) * 4 * dt;
          ctx.strokeStyle = "rgba(160,200,230,0.25)"; ctx.lineWidth = d.r;
          ctx.beginPath(); ctx.moveTo(d.x, d.y - 6); ctx.lineTo(d.x, d.y); ctx.stroke();
        }
        ctx.fillStyle = "rgba(190,220,245,0.6)";
        ctx.beginPath(); ctx.arc(d.x, d.y, d.r, 0, TAU); ctx.fill();
        ctx.fillStyle = "rgba(255,255,255,0.5)";
        ctx.fillRect(d.x - d.r * 0.4, d.y - d.r * 0.4, 0.8, 0.8);
      }
      drops = drops.filter(d => d.y < B.y + B.h + 4);
      if (wiper >= 0) {                   // wiper: a rotating arm wipes drops away
        wiper += dt * 2.2;
        const a = -0.4 + wiper * 2.4;     // sweep angle across the face
        const px = B.x + B.w * (wiper / 1.1), armY = B.y + B.h;
        ctx.strokeStyle = "rgba(200,210,225,0.9)"; ctx.lineWidth = 3;
        ctx.beginPath(); ctx.moveTo(px, armY); ctx.lineTo(px - Math.sin(a) * 8, B.y); ctx.stroke();
        drops = drops.filter(d => Math.abs(d.x - px) > 10);
        if (wiper > 1.2) wiper = -1;
      }
      ctx.restore();
    }
  };
});

def("Waterline", "water", "half-full of sloshing liquid; press to slosh it hard", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  let tilt = 0, tiltV = 0;                // spring-damper on the surface's lean
  return {
    press() { tiltV += rand(1.2, 2) * (Math.random() < 0.5 ? -1 : 1); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(14,20,30,0.94)", "rgba(120,200,220,0.55)");
      tiltV += -tilt * 26 * dt;           // spring pulls level…
      tiltV *= Math.pow(0.3, dt);         // …friction calms it
      tilt += tiltV * dt;
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      const lv = B.y + B.h * 0.45;        // resting waterline
      ctx.beginPath();
      ctx.moveTo(B.x, B.y + B.h);
      for (let x = B.x; x <= B.x + B.w; x += 4) {
        const k = (x - B.cx) / B.w;       // lean + two ripple harmonics
        const y = lv + k * tilt * 60 + Math.sin(x * 0.11 + t * 3) * 1.5 + Math.sin(x * 0.23 - t * 5) * 0.8;
        ctx.lineTo(x, y);
      }
      ctx.lineTo(B.x + B.w, B.y + B.h);
      ctx.closePath();
      const g = ctx.createLinearGradient(0, lv, 0, B.y + B.h);
      g.addColorStop(0, "rgba(70,180,220,0.85)");
      g.addColorStop(1, "rgba(20,90,140,0.9)");
      ctx.fillStyle = g; ctx.fill();
      ctx.strokeStyle = "rgba(200,240,255,0.8)"; ctx.lineWidth = 1.2; ctx.stroke();
      ctx.restore();
      label("SLOSH", "#DFF4FF");
    }
  };
});

def("Whirlpool", "water", "a slow spiral current; press to tighten the drain", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let spin = 1, motes = [];
  for (let i = 0; i < 26; i++)
    motes.push({ a: rand(0, TAU), r: rand(10, B.w * 0.7), v: rand(0.5, 1.2) });
  return {
    press() { spin = 3.2; },
    frame(dt, t) {
      // translucent wash instead of a clear = every mote leaves a current-line
      ctx.fillStyle = "rgba(20,17,31,0.28)"; ctx.fillRect(0, 0, W, H);
      spin += (1 - spin) * dt * 0.8;      // drains back to lazy
      for (const m of motes) {
        m.a += m.v * spin * dt;
        m.r -= 3.5 * spin * dt;           // the inward pull
        if (m.r < 6) { m.r = B.w * rand(0.55, 0.72); m.a = rand(0, TAU); }
        const x = B.cx + Math.cos(m.a) * m.r;
        const y = B.cy + Math.sin(m.a) * m.r * 0.55;
        ctx.fillStyle = "rgba(140,210,235,0.7)";
        ctx.fillRect(x, y, 1.6, 1.6);
      }
      face("rgba(10,22,34," + (0.55 + (spin - 1) * 0.1) + ")", "rgba(130,200,230,0.55)");
      label("DRAIN", "#D5EEFA");
    }
  };
});

def("Spring tide", "water", "waves lap below; press and one crashes right over", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let surgeAmt = 0, foam = [];
  return {
    press() {
      surgeAmt = 1;
      for (let i = 0; i < 14; i++)
        foam.push({ x: rand(B.x, B.x + B.w), y: B.y + rand(-6, 10),
                    vx: rand(-30, 30), vy: rand(-70, -20), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,18,34,0.92)", "rgba(140,200,235,0.5)");
      label("TIDE", "#D8EFFC");
      const base = H * 0.86 - Math.sin(t * 0.5) * 6;   // the slow tide itself
      const lift = surgeAmt * (B.h + 30);              // press: water climbs the button
      for (let layer = 0; layer < 2; layer++) {        // two wave layers, offset phase
        ctx.fillStyle = layer === 0 ? "rgba(40,120,180,0.45)" : "rgba(80,180,230,0.5)";
        ctx.beginPath();
        ctx.moveTo(0, H);
        for (let x = 0; x <= W; x += 5) {
          const y = base - lift - layer * 5 + Math.sin(x * 0.05 + t * (2 + layer)) * 4;
          ctx.lineTo(x, y);
        }
        ctx.lineTo(W, H);
        ctx.closePath(); ctx.fill();
      }
      for (const f of foam) {
        f.x += f.vx * dt; f.y += f.vy * dt; f.vy += 90 * dt; f.life -= dt * 1.1;
        if (f.life > 0) {
          ctx.fillStyle = "rgba(235,250,255," + 0.8 * f.life + ")";
          ctx.beginPath(); ctx.arc(f.x, f.y, 1.8, 0, TAU); ctx.fill();
        }
      }
      foam = foam.filter(f => f.life > 0);
      surgeAmt = Math.max(0, surgeAmt - dt * 0.7);
    }
  };
});

def("Deep sea", "water", "marine snow drifts past a jellyfish; press for a biolume flash", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let flash = 0;
  const snow = [];
  for (let i = 0; i < 26; i++) snow.push({ x: rand(0, W), y: rand(0, H), v: rand(3, 9) });
  return {
    press() { flash = 1; },
    frame(dt, t) {
      const g = ctx.createLinearGradient(0, 0, 0, H);
      g.addColorStop(0, "#0A1626");
      g.addColorStop(1, "#050A14");
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      for (const s of snow) {             // marine snow: dust that never hurries
        s.y += s.v * dt; s.x += Math.sin(t + s.y * 0.05) * 2 * dt;
        if (s.y > H) { s.y = -2; s.x = rand(0, W); }
        ctx.fillStyle = "rgba(180,200,220," + (0.25 + flash * 0.5) + ")";
        ctx.fillRect(s.x, s.y, 1.2, 1.2);
      }
      const jx = W * 0.5 + Math.sin(t * 0.4) * W * 0.3;
      const jy = H * 0.3 + Math.sin(t * 0.9) * 8 - Math.max(0, Math.sin(t * 1.8)) * 6;
      ctx.globalCompositeOperation = "lighter";
      const jg = ctx.createRadialGradient(jx, jy, 0, jx, jy, 14 + flash * 10);
      jg.addColorStop(0, "rgba(140,230,255," + (0.5 + flash * 0.5) + ")");
      jg.addColorStop(1, "rgba(60,140,255,0)");
      ctx.fillStyle = jg;
      ctx.beginPath(); ctx.arc(jx, jy, 14 + flash * 10, 0, TAU); ctx.fill();
      ctx.strokeStyle = "rgba(140,220,255," + (0.35 + flash * 0.5) + ")";
      ctx.lineWidth = 1;
      for (let k = -2; k <= 2; k++) {     // tentacles: sinuous trailing lines
        ctx.beginPath(); ctx.moveTo(jx + k * 3, jy + 6);
        ctx.quadraticCurveTo(jx + k * 5 + Math.sin(t * 3 + k) * 4, jy + 16,
                             jx + k * 6 + Math.sin(t * 2 + k * 2) * 6, jy + 26);
        ctx.stroke();
      }
      ctx.globalCompositeOperation = "source-over";
      face("rgba(8,16,30," + (0.9 - flash * 0.25) + ")", "rgba(120,200,255," + (0.4 + flash * 0.6) + ")");
      label("ABYSS", "rgba(200,235,255," + (0.8 + flash * 0.2) + ")");
      flash = Math.max(0, flash - dt * 1.2);
    }
  };
});

def("Waterfall", "water", "a sheet of water pours down the face; press to splash the base", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  let streaks = [], splash = [];
  return {
    press() {
      for (let i = 0; i < 16; i++)
        splash.push({ x: rand(B.x, B.x + B.w), y: B.y + B.h,
                      vx: rand(-50, 50), vy: rand(-90, -30), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(14,24,34,0.94)", "rgba(150,210,235,0.5)");
      if (Math.random() < 0.8)
        streaks.push({ x: rand(B.x + 3, B.x + B.w - 3), y: B.y - 4, v: rand(90, 150), len: rand(8, 18) });
      ctx.save();
      rr(B.x, B.y - 6, B.w, B.h + 6, B.r); ctx.clip();
      for (const s of streaks) {
        s.y += s.v * dt;
        ctx.strokeStyle = "rgba(170,220,245,0.5)"; ctx.lineWidth = 1.2;
        ctx.beginPath(); ctx.moveTo(s.x, s.y - s.len); ctx.lineTo(s.x, s.y); ctx.stroke();
      }
      ctx.restore();
      streaks = streaks.filter(s => s.y - s.len < B.y + B.h);
      ctx.fillStyle = "rgba(160,215,240,0.2)";        // mist pool at the base
      ctx.beginPath();
      ctx.ellipse(B.cx, B.y + B.h + 4, B.w * 0.5 + Math.sin(t * 2) * 4, 5, 0, 0, u.TAU);
      ctx.fill();
      for (const p of splash) {
        p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 160 * dt; p.life -= dt * 1.4;
        if (p.life > 0) { ctx.fillStyle = "rgba(210,240,255," + p.life + ")"; ctx.fillRect(p.x, p.y, 1.8, 1.8); }
      }
      splash = splash.filter(p => p.life > 0);
      label("FALLS", "#DFF3FF");
    }
  };
});

def("Squirt", "water", "a drip forms at the corner; press to fire the water jet", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let dripSize = 0, jets = [];
  return {
    press() {
      for (let i = 0; i < 20; i++)
        jets.push({ x: B.x + 4, y: B.y + B.h - 4,
                    vx: rand(120, 190), vy: rand(-160, -110), life: 1 });
      dripSize = 0;
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(16,22,34,0.94)", "rgba(130,200,235,0.5)");
      label("SQUIRT", "#D9F0FE");
      dripSize += dt * 0.8;               // the drip swells at the corner…
      const dx = B.x + 4, dy = B.y + B.h - 2;
      if (dripSize > 2.6) {               // …and lets go on its own
        jets.push({ x: dx, y: dy, vx: rand(-5, 5), vy: 30, life: 1.4 });
        dripSize = 0;
      }
      ctx.fillStyle = "rgba(150,210,240,0.85)";
      ctx.beginPath();
      ctx.ellipse(dx, dy + dripSize, 2 + dripSize * 0.8, 2.5 + dripSize * 1.4, 0, 0, TAU);
      ctx.fill();
      for (const j of jets) {             // projectile droplets, gravity included
        j.x += j.vx * dt; j.y += j.vy * dt; j.vy += 220 * dt; j.life -= dt * 0.9;
        if (j.life > 0) {
          ctx.fillStyle = "rgba(170,225,250," + Math.min(1, j.life) + ")";
          ctx.beginPath(); ctx.arc(j.x, j.y, 1.8, 0, TAU); ctx.fill();
        }
      }
      jets = jets.filter(j => j.life > 0 && j.y < H + 8);
    }
  };
});

/* ============================== MERCURY & METAL ============================== */

def("Mercury beads", "metal", "quicksilver beads roam and merge; press to scatter them", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  const beads = [];
  for (let i = 0; i < 7; i++)
    beads.push({ x: rand(B.x + 12, B.x + B.w - 12), y: rand(B.y + 10, B.y + B.h - 10),
                 vx: rand(-12, 12), vy: rand(-8, 8), r: rand(3.5, 7) });
  return {
    press() {
      for (const b of beads) { b.vx = rand(-90, 90); b.vy = rand(-70, 70); }
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(26,28,34,0.95)", "rgba(190,200,215,0.5)");
      label("HG", "rgba(225,232,240,0.9)");
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      for (const b of beads) {            // drift, slow, bounce off the walls
        b.x += b.vx * dt; b.y += b.vy * dt;
        b.vx *= Math.pow(0.5, dt); b.vy *= Math.pow(0.5, dt);
        b.vx += rand(-6, 6) * dt * 10; b.vy += rand(-5, 5) * dt * 10;
        if (b.x < B.x + b.r) { b.x = B.x + b.r; b.vx = Math.abs(b.vx); }
        if (b.x > B.x + B.w - b.r) { b.x = B.x + B.w - b.r; b.vx = -Math.abs(b.vx); }
        if (b.y < B.y + b.r) { b.y = B.y + b.r; b.vy = Math.abs(b.vy); }
        if (b.y > B.y + B.h - b.r) { b.y = B.y + B.h - b.r; b.vy = -Math.abs(b.vy); }
      }
      ctx.lineCap = "round";
      for (let i = 0; i < beads.length; i++)          // necks between close beads
        for (let j = i + 1; j < beads.length; j++) {
          const a = beads[i], b = beads[j];
          const d = Math.hypot(a.x - b.x, a.y - b.y);
          if (d < (a.r + b.r) * 1.7) {
            ctx.strokeStyle = "rgba(200,208,220,0.85)";
            ctx.lineWidth = Math.min(a.r, b.r) * 1.1;
            ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
          }
        }
      for (const b of beads) {            // each bead: grey ball + specular dot
        const g = ctx.createRadialGradient(b.x - b.r * 0.3, b.y - b.r * 0.35, 0.5, b.x, b.y, b.r);
        g.addColorStop(0, "#F2F6FA");
        g.addColorStop(0.5, "#B9C2CE");
        g.addColorStop(1, "#6F7885");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, TAU); ctx.fill();
      }
      ctx.restore();
    }
  };
});

def("Quicksilver trail", "metal", "a metal drop orbits, beading behind itself; press for speed", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let speed = 1, drops = [], a = 0;
  return {
    press() { speed = 3.4; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(24,26,32,0.94)", "rgba(190,200,215,0.5)");
      label("ORBIT", "rgba(228,234,242,0.9)");
      speed += (1 - speed) * dt * 0.9;
      a += speed * 1.8 * dt;
      const x = B.cx + Math.cos(a) * B.w * 0.6;
      const y = B.cy + Math.sin(a) * B.h * 0.95;
      if (Math.random() < 0.5) drops.push({ x: x, y: y, r: rand(1.5, 3.2), life: 1 });
      for (const d of drops) {            // the trail beads up and shrinks away
        d.life -= dt * 0.8; d.y += 4 * dt;
        if (d.life <= 0) continue;
        const g = ctx.createRadialGradient(d.x - d.r * 0.3, d.y - d.r * 0.3, 0.3, d.x, d.y, d.r * d.life);
        g.addColorStop(0, "rgba(240,245,250," + d.life + ")");
        g.addColorStop(1, "rgba(110,120,135," + d.life * 0.8 + ")");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(d.x, d.y, Math.max(0.4, d.r * d.life), 0, TAU); ctx.fill();
      }
      drops = drops.filter(d => d.life > 0);
      const g = ctx.createRadialGradient(x - 2, y - 2, 0.5, x, y, 6);
      g.addColorStop(0, "#FFFFFF");
      g.addColorStop(0.55, "#C4CCD8");
      g.addColorStop(1, "#767E8C");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(x, y, 6, 0, TAU); ctx.fill();
    }
  };
});

def("Chrome sweep", "metal", "a mirror sheen crosses every few seconds; press for a double flash", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  let sweeps = [{ p: -0.3, v: 0.5 }], timer = 3;
  return {
    press() { sweeps.push({ p: -0.3, v: 2.2 }, { p: 1.3, v: -2.2 }); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const base = ctx.createLinearGradient(0, B.y, 0, B.y + B.h);   // banded metal
      base.addColorStop(0, "#3A3F48");
      base.addColorStop(0.45, "#20242C");
      base.addColorStop(0.55, "#14171E");
      base.addColorStop(1, "#2C313A");
      face(base, "rgba(200,210,225,0.6)");
      label("CHROME", "#E8EDF4");
      timer -= dt;
      if (timer <= 0) { sweeps.push({ p: -0.3, v: 0.5 }); timer = rand(2.5, 4); }
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      ctx.globalCompositeOperation = "lighter";
      for (const s of sweeps) {           // a tilted white band, driven across
        s.p += s.v * dt;
        const x = B.x + B.w * s.p;
        const g = ctx.createLinearGradient(x - 18, 0, x + 18, 0);
        g.addColorStop(0, "rgba(255,255,255,0)");
        g.addColorStop(0.5, "rgba(255,255,255,0.5)");
        g.addColorStop(1, "rgba(255,255,255,0)");
        ctx.fillStyle = g;
        ctx.save();
        ctx.translate(x, B.cy); ctx.rotate(-0.35); ctx.translate(-x, -B.cy);
        ctx.fillRect(x - 24, B.y - 20, 48, B.h + 40);
        ctx.restore();
      }
      ctx.restore();
      ctx.globalCompositeOperation = "source-over";
      sweeps = sweeps.filter(s => s.p > -0.4 && s.p < 1.4);
    }
  };
});

def("Molten drip", "metal", "gold gathers and drips off the bottom edge; press to pour", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let hangs = [], falls = [], pour = 0;
  return {
    press() { pour = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(40,26,10,0.94)", "rgba(255,190,90,0.6)");
      label("SMELT", "#FFE9BE");
      const rate = pour > 0 ? 0.5 : 0.03;
      if (Math.random() < rate)
        hangs.push({ x: rand(B.x + 8, B.x + B.w - 8), s: 0 });
      ctx.globalCompositeOperation = "lighter";
      for (const hd of hangs) {           // a drop grows until it must let go
        hd.s += dt * (pour > 0 ? 3 : 0.8);
        const y = B.y + B.h;
        const g = ctx.createRadialGradient(hd.x, y + hd.s, 0, hd.x, y + hd.s, 3 + hd.s);
        g.addColorStop(0, "rgba(255,230,140,0.95)");
        g.addColorStop(1, "rgba(255,120,20,0.2)");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.ellipse(hd.x, y + hd.s, 2 + hd.s * 0.5, 2.5 + hd.s, 0, 0, TAU);
        ctx.fill();
        if (hd.s > 3) { falls.push({ x: hd.x, y: y + hd.s, vy: 30, life: 1 }); hd.s = -99; }
      }
      hangs = hangs.filter(hd => hd.s > -1);
      for (const f of falls) {
        f.y += f.vy * dt; f.vy += 220 * dt; f.life -= dt * 0.6;
        if (f.life > 0 && f.y < H + 6) {
          ctx.fillStyle = "rgba(255,200,90," + f.life + ")";
          ctx.beginPath(); ctx.ellipse(f.x, f.y, 2, 3.4, 0, 0, TAU); ctx.fill();
        }
      }
      falls = falls.filter(f => f.life > 0 && f.y < H + 6);
      ctx.globalCompositeOperation = "source-over";
      pour = Math.max(0, pour - dt * 0.8);
    }
  };
});

def("Forge", "metal", "the steel breathes from black to orange heat; press to hammer it", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let strike = 0, sparks = [];
  return {
    press() {
      strike = 1;
      for (let i = 0; i < 18; i++) {
        const th = rand(-Math.PI, 0);     // sparks fly up and out
        sparks.push({ x: B.cx, y: B.cy, vx: Math.cos(th) * rand(50, 170), vy: Math.sin(th) * rand(40, 150), life: 1 });
      }
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const heat = 0.5 + 0.5 * Math.sin(t * 0.7);      // the slow bellows cycle
      const r = Math.round(30 + heat * 200 + strike * 25);
      const gn = Math.round(16 + heat * 90 + strike * 120);
      const bl = Math.round(20 + strike * 200);
      face("rgb(" + Math.min(255, r) + "," + Math.min(255, gn) + "," + Math.min(255, bl) + ")",
           "rgba(255,200,140,0.5)");
      label("STRIKE", heat > 0.5 || strike > 0 ? "#2A1408" : "#FFD9A8");
      ctx.globalCompositeOperation = "lighter";
      for (const s of sparks) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 260 * dt; s.life -= dt * 1.5;
        if (s.life > 0) {
          ctx.strokeStyle = "rgba(255,210,120," + s.life + ")";
          ctx.lineWidth = 1.4;
          ctx.beginPath(); ctx.moveTo(s.x, s.y);
          ctx.lineTo(s.x - s.vx * 0.03, s.y - s.vy * 0.03); ctx.stroke();
        }
      }
      ctx.globalCompositeOperation = "source-over";
      sparks = sparks.filter(s => s.life > 0);
      strike = Math.max(0, strike - dt * 2.5);
    }
  };
});

def("Rivet gleam", "metal", "corner rivets glint in turn; press and all four fire", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  const rivets = [
    { x: B.x + 10, y: B.y + 9 }, { x: B.x + B.w - 10, y: B.y + 9 },
    { x: B.x + B.w - 10, y: B.y + B.h - 9 }, { x: B.x + 10, y: B.y + B.h - 9 }
  ];
  let all = 0;
  return {
    press() { all = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const g = ctx.createLinearGradient(0, B.y, 0, B.y + B.h);
      g.addColorStop(0, "#454B55");
      g.addColorStop(1, "#23272E");
      face(g, "rgba(180,190,205,0.6)");
      label("RIVETED", "#E6EBF2");
      const active = Math.floor(t * 1.2) % 4;          // whose turn to shine
      const phase = (t * 1.2) % 1;
      rivets.forEach(function (rv, i) {
        ctx.fillStyle = "#5C636E";
        ctx.beginPath(); ctx.arc(rv.x, rv.y, 3.4, 0, TAU); ctx.fill();
        ctx.strokeStyle = "rgba(255,255,255,0.25)";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(rv.x, rv.y, 3.4, -2.5, -0.8); ctx.stroke();
        let glint = i === active ? Math.max(0, Math.sin(phase * Math.PI)) : 0;
        glint = Math.max(glint, all);
        if (glint > 0.02) {               // a four-point star flare
          ctx.globalCompositeOperation = "lighter";
          ctx.strokeStyle = "rgba(255,255,255," + glint * 0.9 + ")";
          ctx.lineWidth = 1.2;
          const L = 6 + glint * 6;
          ctx.beginPath();
          ctx.moveTo(rv.x - L, rv.y); ctx.lineTo(rv.x + L, rv.y);
          ctx.moveTo(rv.x, rv.y - L); ctx.lineTo(rv.x, rv.y + L);
          ctx.stroke();
          ctx.globalCompositeOperation = "source-over";
        }
      });
      all = Math.max(0, all - dt * 1.6);
    }
  };
});

def("Liquid chrome", "metal", "the mirror surface undulates; press to send it wobbling", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  let wob = 0, wobV = 0;
  return {
    press() { wobV += 8; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      wobV += -wob * 30 * dt; wobV *= Math.pow(0.25, dt); wob += wobV * dt;
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      // the surface: horizontal mirror bands whose boundary rolls with sin waves
      for (let y = 0; y < B.h; y += 3) {
        const k = y / B.h;
        const shift = Math.sin(k * 6 + t * 1.5) * (3 + wob * 4) + Math.sin(k * 13 - t * 2.3) * 1.5;
        const bright = 0.5 + 0.5 * Math.sin(k * 9 + shift * 0.35 + t * 0.7);
        const v = Math.round(40 + bright * 170);
        ctx.fillStyle = "rgb(" + v + "," + (v + 6) + "," + (v + 14) + ")";
        ctx.fillRect(B.x + shift, B.y + y, B.w, 3.2);
      }
      ctx.restore();
      rr(B.x, B.y, B.w, B.h, B.r);
      ctx.strokeStyle = "rgba(220,228,240,0.7)"; ctx.lineWidth = 1.5; ctx.stroke();
      label("MELT", "rgba(20,24,30,0.85)");
    }
  };
});

def("Magnetite", "metal", "iron filings comb themselves along a turning field; press to flip the poles", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  const filings = [];
  for (let i = 0; i < 90; i++)
    filings.push({ x: rand(B.x + 4, B.x + B.w - 4), y: rand(B.y + 4, B.y + B.h - 4) });
  let flip = 0, kick = 0;
  return {
    press() { flip += Math.PI; kick = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,20,26,0.95)", "rgba(170,180,195,0.5)");
      const fa = t * 0.5 + flip;          // the field's slow rotation (+ press flips)
      const px = B.cx + Math.cos(fa) * B.w * 0.4;      // north pole
      const py = B.cy + Math.sin(fa) * B.h * 0.35;
      const qx = B.cx - Math.cos(fa) * B.w * 0.4;      // south pole
      const qy = B.cy - Math.sin(fa) * B.h * 0.35;
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      ctx.strokeStyle = "rgba(200,205,215," + (0.5 + kick * 0.4) + ")";
      ctx.lineWidth = 1;
      for (const f of filings) {          // each filing aligns to the dipole sum
        const a1 = Math.atan2(f.y - py, f.x - px);
        const a2 = Math.atan2(qy - f.y, qx - f.x);
        const a = Math.atan2(Math.sin(a1) + Math.sin(a2), Math.cos(a1) + Math.cos(a2));
        const L = 2.6 + kick * 1.4;
        ctx.beginPath();
        ctx.moveTo(f.x - Math.cos(a) * L, f.y - Math.sin(a) * L);
        ctx.lineTo(f.x + Math.cos(a) * L, f.y + Math.sin(a) * L);
        ctx.stroke();
      }
      ctx.restore();
      label("POLARITY", "#DFE5EC");
      kick = Math.max(0, kick - dt * 1.8);
    }
  };
});

/* ============================== ICE & FROST ============================== */

def("Frostbite", "ice", "frost fingers creep in from the border; press to shatter them", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  const fingers = [];                     // each: a branching polyline aimed inward
  for (let i = 0; i < 14; i++) {
    const onTop = Math.random() < 0.5;
    const x0 = rand(B.x + 4, B.x + B.w - 4);
    const y0 = onTop ? B.y : B.y + B.h;
    const dir = onTop ? 1 : -1;
    const pts = [{ x: x0, y: y0 }];
    let x = x0, y = y0;
    for (let s = 0; s < 4; s++) {
      x += rand(-6, 6); y += dir * rand(3, 7);
      pts.push({ x: x, y: y });
    }
    fingers.push({ pts: pts, ph: rand(0, 5) });
  }
  let grow = 0.4, shatter = [];
  return {
    press() {
      for (const f of fingers)
        shatter.push({ x: f.pts[2].x, y: f.pts[2].y, vx: rand(-50, 50), vy: rand(-50, 50), life: 1 });
      grow = 0;
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(14,22,34,0.94)", "rgba(170,220,250,0.6)");
      label("FROST", "#E2F3FF");
      grow = Math.min(1, grow + dt * 0.12);            // frost regrows patiently
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      ctx.strokeStyle = "rgba(200,235,255,0.75)";
      ctx.lineWidth = 1;
      for (const f of fingers) {
        const n = 1 + Math.floor(grow * (f.pts.length - 1) + Math.sin(t + f.ph) * 0.4);
        ctx.beginPath(); ctx.moveTo(f.pts[0].x, f.pts[0].y);
        for (let i = 1; i < Math.min(f.pts.length, Math.max(1, n) + 1); i++) {
          ctx.lineTo(f.pts[i].x, f.pts[i].y);
          if (i > 1) {                    // side twigs make it read as frost
            ctx.moveTo(f.pts[i].x, f.pts[i].y);
            ctx.lineTo(f.pts[i].x + rand(-3, 3), f.pts[i].y + rand(-3, 3));
            ctx.moveTo(f.pts[i].x, f.pts[i].y);
          }
        }
        ctx.stroke();
      }
      ctx.restore();
      for (const s of shatter) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt * 1.8;
        if (s.life > 0) { ctx.fillStyle = "rgba(210,240,255," + s.life + ")"; ctx.fillRect(s.x, s.y, 2, 2); }
      }
      shatter = shatter.filter(s => s.life > 0);
    }
  };
});

def("Snowdrift", "ice", "snow settles on the top edge; press to shake it off", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  const flakes = [];
  for (let i = 0; i < 22; i++) flakes.push({ x: rand(0, W), y: rand(0, H), v: rand(10, 24), ph: rand(0, 9) });
  const cols = 24, pile = new Array(cols).fill(0);
  let shake = 0, tossed = [];
  return {
    press() {
      shake = 1;
      for (let i = 0; i < cols; i++) {
        if (pile[i] > 0.5)
          tossed.push({ x: B.x + (i + 0.5) * B.w / cols, y: B.y - pile[i],
                        vx: rand(-40, 40), vy: rand(-60, -20), life: 1 });
        pile[i] = 0;
      }
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const jx = shake > 0 ? rand(-2, 2) * shake : 0;
      ctx.save();
      ctx.translate(jx, 0);
      face("rgba(18,24,38,0.94)", "rgba(190,220,250,0.55)");
      label("SNOW DAY", "#EAF4FF");
      ctx.fillStyle = "rgba(240,248,255,0.95)";        // the drift itself
      ctx.beginPath();
      ctx.moveTo(B.x, B.y);
      for (let i = 0; i < cols; i++)
        ctx.lineTo(B.x + (i + 0.5) * B.w / cols, B.y - pile[i]);
      ctx.lineTo(B.x + B.w, B.y);
      ctx.closePath(); ctx.fill();
      ctx.restore();
      for (const f of flakes) {           // fall with a lazy sway
        f.y += f.v * dt; f.x += Math.sin(t + f.ph) * 8 * dt;
        if (f.y > B.y - 1 && f.y < B.y + 6 && f.x > B.x && f.x < B.x + B.w) {
          const c = Math.floor((f.x - B.x) / B.w * cols);
          if (c >= 0 && c < cols) pile[c] = Math.min(9, pile[c] + 0.8);
          f.y = -3; f.x = rand(0, W);
        }
        if (f.y > H) { f.y = -3; f.x = rand(0, W); }
        ctx.fillStyle = "rgba(235,245,255,0.8)";
        ctx.beginPath(); ctx.arc(f.x, f.y, 1.4, 0, TAU); ctx.fill();
      }
      for (const p of tossed) {
        p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 120 * dt; p.life -= dt * 1.2;
        if (p.life > 0) { ctx.fillStyle = "rgba(240,248,255," + p.life + ")"; ctx.fillRect(p.x, p.y, 2, 2); }
      }
      tossed = tossed.filter(p => p.life > 0);
      shake = Math.max(0, shake - dt * 3);
    }
  };
});

def("Ice cracks", "ice", "clear ice, quiet glints; press and cracks race out, then refreeze", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  let cracks = [], freeze = 0;
  return {
    press(x, y) {
      const cx = Math.min(B.x + B.w - 4, Math.max(B.x + 4, x || B.cx));
      const cy = Math.min(B.y + B.h - 4, Math.max(B.y + 4, y || B.cy));
      cracks = [];
      for (let i = 0; i < 7; i++) {       // each crack: a jagged ray from the hit
        const th = rand(0, u.TAU), pts = [{ x: cx, y: cy }];
        let px = cx, py = cy, a = th;
        for (let s = 0; s < 5; s++) {
          a += rand(-0.5, 0.5);
          px += Math.cos(a) * rand(6, 14); py += Math.sin(a) * rand(4, 9);
          pts.push({ x: px, y: py });
        }
        cracks.push(pts);
      }
      freeze = 1;
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const g = ctx.createLinearGradient(B.x, B.y, B.x + B.w, B.y + B.h);
      g.addColorStop(0, "rgba(160,210,245,0.35)");
      g.addColorStop(0.5, "rgba(120,180,225,0.22)");
      g.addColorStop(1, "rgba(170,220,250,0.35)");
      face(g, "rgba(200,235,255,0.7)");
      label("THIN ICE", "rgba(20,40,60,0.85)");
      if (Math.random() < 0.02) {         // idle: a passing internal glint
        ctx.strokeStyle = "rgba(255,255,255,0.5)";
        ctx.lineWidth = 1;
        const gx = rand(B.x + 8, B.x + B.w - 8), gy = rand(B.y + 6, B.y + B.h - 6);
        ctx.beginPath(); ctx.moveTo(gx - 4, gy + 3); ctx.lineTo(gx + 4, gy - 3); ctx.stroke();
      }
      if (freeze > 0) {
        freeze = Math.max(0, freeze - dt * 0.45);      // the slow refreeze
        ctx.save();
        rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
        ctx.strokeStyle = "rgba(235,248,255," + freeze * 0.95 + ")";
        ctx.lineWidth = 1.2;
        const reveal = Math.min(1, (1 - freeze) * 6);  // cracks race out fast
        for (const pts of cracks) {
          ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y);
          const n = Math.max(2, Math.ceil(reveal * pts.length));
          for (let i = 1; i < n && i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
          ctx.stroke();
        }
        ctx.restore();
      }
    }
  };
});

def("Glacier", "ice", "the shelf calves small bergs; press for a big one", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let bergs = [], timer = 3, splashes = [];
  function calve(big) {
    const n = big ? 3 : 1;
    for (let i = 0; i < n; i++) {
      const verts = [];
      for (let k = 0; k < 5; k++) verts.push({ a: k / 5 * TAU, r: rand(3, big ? 8 : 5) });
      bergs.push({ x: B.x + B.w - 4, y: rand(B.y + 4, B.y + B.h - 6),
                   vx: rand(14, 30), vy: rand(4, 14), rot: 0, vr: rand(-1.5, 1.5),
                   verts: verts, life: 1 });
    }
    for (let i = 0; i < 5 * n; i++)
      splashes.push({ x: B.x + B.w + rand(0, 8), y: B.y + B.h - 4, vx: rand(0, 40), vy: rand(-40, -8), life: 1 });
  }
  return {
    press() { calve(true); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const g = ctx.createLinearGradient(0, B.y, 0, B.y + B.h);
      g.addColorStop(0, "#E8F4FC");
      g.addColorStop(0.15, "#BBD9EE");
      g.addColorStop(1, "#6D9CC0");
      face(g, "rgba(230,245,255,0.8)");
      label("CALVE", "rgba(20,45,70,0.85)");
      timer -= dt;
      if (timer <= 0) { calve(false); timer = rand(2.5, 5); }
      for (const bg of bergs) {           // drift off, rotating, fading
        bg.x += bg.vx * dt; bg.y += bg.vy * dt; bg.rot += bg.vr * dt; bg.life -= dt * 0.4;
        if (bg.life <= 0) continue;
        ctx.save();
        ctx.translate(bg.x, bg.y); ctx.rotate(bg.rot);
        ctx.fillStyle = "rgba(205,230,248," + bg.life * 0.95 + ")";
        ctx.beginPath();
        bg.verts.forEach(function (v, i) {
          const px = Math.cos(v.a) * v.r, py = Math.sin(v.a) * v.r;
          if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        });
        ctx.closePath(); ctx.fill();
        ctx.restore();
      }
      bergs = bergs.filter(bg => bg.life > 0);
      for (const s of splashes) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 110 * dt; s.life -= dt * 1.6;
        if (s.life > 0) { ctx.fillStyle = "rgba(220,240,255," + s.life + ")"; ctx.fillRect(s.x, s.y, 1.6, 1.6); }
      }
      splashes = splashes.filter(s => s.life > 0);
    }
  };
});

def("Aurora", "ice", "curtains of light ripple overhead; press to set the sky alight", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  let blaze = 0;
  return {
    press() { blaze = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#0D1220"; ctx.fillRect(0, 0, W, H);
      ctx.globalCompositeOperation = "lighter";
      const hues = [150, 180, 280];       // green, teal, violet curtains
      for (let c = 0; c < 3; c++) {
        const baseY = B.y - 14 - c * 6;
        for (let x = 0; x < W; x += 4) {  // each curtain: vertical strands on a sine path
          const sway = Math.sin(x * 0.03 + t * (0.6 + c * 0.3) + c * 2) * 8;
          const hgt = 14 + Math.sin(x * 0.05 - t * (0.8 + blaze * 2) + c) * 8 + blaze * 14;
          const a = Math.max(0, 0.05 + 0.05 * Math.sin(x * 0.02 + t + c * 3) + blaze * 0.1);
          ctx.strokeStyle = "hsla(" + (hues[c] + blaze * 40 * Math.sin(t * 3)) + ",90%,65%," + a + ")";
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.moveTo(x + sway, baseY);
          ctx.lineTo(x + sway * 1.4, baseY - hgt);
          ctx.stroke();
        }
      }
      ctx.globalCompositeOperation = "source-over";
      face("rgba(16,20,36,0.92)", "rgba(160,230,200,0.55)");
      label("BOREALIS", "#D8F5E8");
      blaze = Math.max(0, blaze - dt * 0.7);
    }
  };
});

def("Hailstorm", "ice", "hail bounces off the button; press for a violent burst", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let stones = [], flash = 0;
  function drop() {
    stones.push({ x: rand(B.x - 10, B.x + B.w + 10), y: -4, vx: rand(-8, 8), vy: rand(80, 140), r: rand(1.5, 3) });
  }
  return {
    press() { flash = 1; for (let i = 0; i < 14; i++) drop(); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(22,26,40," + (0.94 - flash * 0.2) + ")", "rgba(190,215,245," + (0.5 + flash * 0.5) + ")");
      label("HAIL", "#E6EFFA");
      if (Math.random() < 0.1) drop();
      for (const s of stones) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 60 * dt;
        // bounce off the button's top face
        if (s.vy > 0 && s.y > B.y - s.r && s.y < B.y + 6 && s.x > B.x && s.x < B.x + B.w) {
          s.vy = -s.vy * rand(0.35, 0.55); s.vx += rand(-20, 20);
        }
        ctx.fillStyle = "rgba(225,240,255,0.9)";
        ctx.beginPath(); ctx.arc(s.x, s.y, s.r, 0, TAU); ctx.fill();
      }
      stones = stones.filter(s => s.y < H + 6);
      flash = Math.max(0, flash - dt * 2.5);
    }
  };
});

def("Frozen core", "ice", "a cold heart pulses inside; press for a ring of frost spikes", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let burst = 0;
  const mist = [];
  for (let i = 0; i < 10; i++) mist.push({ x: rand(B.x, B.x + B.w), y: B.y + B.h + rand(0, 8), v: rand(4, 10) });
  return {
    press() { burst = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,30,48,0.7)", "rgba(170,215,250,0.6)");
      ctx.globalCompositeOperation = "lighter";
      const pulse = 0.5 + 0.5 * Math.sin(t * 1.4);     // the cold heartbeat
      const rr2 = B.h * (0.5 + pulse * 0.3) + burst * 12;
      const g = ctx.createRadialGradient(B.cx, B.cy, 0, B.cx, B.cy, rr2);
      g.addColorStop(0, "rgba(190,235,255," + (0.35 + pulse * 0.25 + burst * 0.4) + ")");
      g.addColorStop(1, "rgba(90,160,230,0)");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(B.cx, B.cy, rr2, 0, TAU); ctx.fill();
      if (burst > 0) {                    // spikes: 10 short frozen rays
        ctx.strokeStyle = "rgba(220,245,255," + burst + ")";
        ctx.lineWidth = 1.6;
        for (let i = 0; i < 10; i++) {
          const th = i / 10 * TAU;
          const r0 = 14 + (1 - burst) * 30, r1 = r0 + 10;
          ctx.beginPath();
          ctx.moveTo(B.cx + Math.cos(th) * r0 * 1.5, B.cy + Math.sin(th) * r0 * 0.8);
          ctx.lineTo(B.cx + Math.cos(th) * r1 * 1.5, B.cy + Math.sin(th) * r1 * 0.8);
          ctx.stroke();
        }
      }
      for (const m of mist) {             // cold air falls, not rises
        m.y += m.v * dt;
        if (m.y > H + 4) { m.y = B.y + B.h; m.x = rand(B.x, B.x + B.w); }
        ctx.fillStyle = "rgba(170,210,245,0.12)";
        ctx.beginPath(); ctx.arc(m.x, m.y, 4, 0, TAU); ctx.fill();
      }
      ctx.globalCompositeOperation = "source-over";
      label("CRYO", "#DFF2FF");
      burst = Math.max(0, burst - dt * 1.6);
    }
  };
});

def("Blizzard", "ice", "sideways snow, shivering caption; press for a whiteout", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  let white = 0;
  const streaks = [];
  for (let i = 0; i < 30; i++) streaks.push({ x: rand(0, W), y: rand(0, H), v: rand(90, 190) });
  return {
    press() { white = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const gust = 0.6 + 0.4 * Math.sin(t * 0.9);      // the wind comes in waves
      face("rgba(20,24,38,0.94)", "rgba(200,220,245,0.5)");
      ctx.save();
      ctx.translate(rand(-0.8, 0.8), rand(-0.8, 0.8)); // the shiver
      label("BRRR", "#EFF6FF");
      ctx.restore();
      for (const s of streaks) {
        s.x -= s.v * gust * dt;
        if (s.x < -10) { s.x = W + 10; s.y = rand(0, H); }
        ctx.strokeStyle = "rgba(235,245,255," + 0.5 * gust + ")";
        ctx.lineWidth = 1.2;
        ctx.beginPath(); ctx.moveTo(s.x, s.y); ctx.lineTo(s.x + 9, s.y - 2); ctx.stroke();
      }
      if (white > 0) {                    // the whiteout swallows everything briefly
        ctx.fillStyle = "rgba(240,246,252," + Math.min(0.95, white * 1.2) + ")";
        ctx.fillRect(0, 0, W, H);
        white = Math.max(0, white - dt * 1.1);
      }
    }
  };
});

/* ============================== EARTH & STONE ============================== */

def("Fault line", "earth", "a glowing crack crosses the face; press for the earthquake", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  const crack = [];                       // the fault: one jagged line, fixed at birth
  let x = B.x, y = B.cy + rand(-6, 6);
  while (x < B.x + B.w) { crack.push({ x: x, y: y }); x += rand(8, 18); y += rand(-6, 6); }
  crack.push({ x: B.x + B.w, y: y });
  let quake = 0, debris = [];
  return {
    press() {
      quake = 1;
      for (let i = 0; i < 10; i++)
        debris.push({ x: rand(B.x, B.x + B.w), y: B.y + B.h, vx: rand(-30, 30), vy: rand(-80, -20), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const sh = quake * quake * 5;       // trauma² — the kind screen-shake rule
      ctx.save();
      ctx.translate(rand(-sh, sh), rand(-sh, sh));
      face("#241D18", "rgba(200,170,130,0.5)");
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      const glow = 0.45 + 0.3 * Math.sin(t * 1.8) + quake * 0.5;
      ctx.strokeStyle = "rgba(255,150,60," + Math.min(1, glow) + ")";
      ctx.lineWidth = 1.6 + quake * 2;
      ctx.beginPath(); ctx.moveTo(crack[0].x, crack[0].y);
      for (const p of crack) ctx.lineTo(p.x, p.y);
      ctx.stroke();
      ctx.restore();
      label("RICHTER", "#EADFC8");
      ctx.restore();
      for (const d of debris) {
        d.x += d.vx * dt; d.y += d.vy * dt; d.vy += 200 * dt; d.life -= dt * 1.2;
        if (d.life > 0) { ctx.fillStyle = "rgba(180,150,110," + d.life + ")"; ctx.fillRect(d.x, d.y, 2.4, 2.4); }
      }
      debris = debris.filter(d => d.life > 0);
      quake = Math.max(0, quake - dt * 1.4);
    }
  };
});

def("Crumble", "earth", "press and the face collapses into rubble — then rebuilds itself", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  const cols = 8, rows = 3, shards = [];
  const sw = B.w / cols, sh = B.h / rows;
  for (let cx = 0; cx < cols; cx++)
    for (let cy = 0; cy < rows; cy++)
      shards.push({ hx: B.x + cx * sw, hy: B.y + cy * sh,   // home position
                    x: 0, y: 0, vx: 0, vy: 0, rot: 0, vr: 0 });
  let mode = "solid", modeT = 0;          // solid → falling → rising → solid
  return {
    press() {
      if (mode !== "solid") return;
      mode = "falling"; modeT = 0;
      for (const s of shards) {
        s.x = s.hx; s.y = s.hy;
        s.vx = rand(-20, 20); s.vy = rand(-40, 10);
        s.rot = 0; s.vr = rand(-3, 3);
      }
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      modeT += dt;
      if (mode === "solid") {
        face("#2A2118", "rgba(190,160,120,0.55)");
        label("CRUMBLE", "#E8DCC8");
        if (Math.random() < 0.05) {       // idle dust falls from the underside
          ctx.fillStyle = "rgba(170,150,120,0.5)";
          ctx.fillRect(rand(B.x, B.x + B.w), B.y + B.h + rand(0, 4), 1.5, 1.5);
        }
      } else if (mode === "falling") {
        for (const s of shards) {
          s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 240 * dt; s.rot += s.vr * dt;
        }
        if (modeT > 1.1) { mode = "rising"; modeT = 0; }
      } else {                            // rising: ease every shard home
        const k = Math.min(1, modeT / 0.8);
        const e = 1 - Math.pow(1 - k, 3); // ease-out — repentant rubble
        for (const s of shards) {
          s.x += (s.hx - s.x) * e; s.y += (s.hy - s.y) * e; s.rot *= (1 - e);
        }
        if (k >= 1) mode = "solid";
      }
      if (mode !== "solid") {
        for (const s of shards) {
          ctx.save();
          ctx.translate(s.x + sw / 2, s.y + sh / 2);
          ctx.rotate(s.rot);
          ctx.fillStyle = "#2A2118";
          ctx.strokeStyle = "rgba(190,160,120,0.4)";
          ctx.fillRect(-sw / 2 + 0.5, -sh / 2 + 0.5, sw - 1, sh - 1);
          ctx.strokeRect(-sw / 2 + 0.5, -sh / 2 + 0.5, sw - 1, sh - 1);
          ctx.restore();
        }
      }
    }
  };
});

def("Sandstorm", "earth", "grains stream past and gnaw the edges; press for a gust", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  let gust = 0;
  const grains = [];
  for (let i = 0; i < 60; i++) grains.push({ x: rand(0, W), y: rand(0, H), v: rand(30, 90) });
  return {
    press() { gust = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("#33281B", "rgba(220,190,140,0.5)");
      label("ERODE", "#EFE2C8");
      // the erosion: sand-coloured nicks chewing the lit border
      ctx.fillStyle = "#14111F";
      for (let i = 0; i < 14; i++) {
        const ex = B.x + ((i * 37 + Math.floor(t * 2) * 13) % B.w);
        const top = i % 2 === 0;
        ctx.fillRect(ex, top ? B.y - 1 : B.y + B.h - 1, 3 + Math.sin(t + i) * 1.5, 2);
      }
      const wind = 1 + gust * 3;
      for (const gr of grains) {
        gr.x += gr.v * wind * dt; gr.y += Math.sin(gr.x * 0.05) * 10 * dt;
        if (gr.x > W + 4) { gr.x = -4; gr.y = rand(0, H); }
        ctx.fillStyle = "rgba(225,195,140," + (0.25 + gust * 0.4) + ")";
        ctx.fillRect(gr.x, gr.y, 1.6, 1.2);
      }
      gust = Math.max(0, gust - dt * 1.2);
    }
  };
});

def("Landslide", "earth", "pebbles trickle down the face; press to let the whole slope go", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let pebbles = [], slide = 0;
  function spawn() {
    pebbles.push({ x: rand(B.x + 4, B.x + B.w - 4), y: B.y + 2, vy: rand(10, 30), r: rand(1.2, 2.6) });
  }
  return {
    press() { slide = 1; for (let i = 0; i < 20; i++) spawn(); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const lean = slide * Math.sin(t * 30) * 0.01;    // the ground itself trembles
      ctx.save();
      ctx.translate(B.cx, B.cy); ctx.rotate(lean); ctx.translate(-B.cx, -B.cy);
      face("#2B2117", "rgba(200,170,130,0.5)");
      label("SCREE", "#E9DCC6");
      ctx.restore();
      if (Math.random() < 0.06 + slide * 0.5) spawn();
      for (const p of pebbles) {          // roll down the face, drop off the edge
        p.y += p.vy * dt; p.vy += 60 * dt;
        p.x += Math.sin(p.y * 0.3) * 6 * dt;
        ctx.fillStyle = "rgba(190,165,130,0.85)";
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, TAU); ctx.fill();
      }
      pebbles = pebbles.filter(p => p.y < H + 4);
      slide = Math.max(0, slide - dt * 1.1);
    }
  };
});

def("Geode", "earth", "plain rock outside; press to split it open on the sparkle", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  let open = 0, opening = false;
  const glitter = [];
  for (let i = 0; i < 16; i++)
    glitter.push({ x: rand(B.x + 14, B.x + B.w - 14), y: rand(B.y + 8, B.y + B.h - 8), ph: rand(0, 9) });
  return {
    press() { opening = true; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      if (opening) open = Math.min(1, open + dt * 2.4);
      else open = Math.max(0, open - dt * 1.2);
      if (open >= 1) opening = false;     // fully open → the slow close takes over
      const gap = open * 14;
      if (open > 0.05) {                  // the amethyst interior, revealed
        ctx.save();
        rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
        const g = ctx.createLinearGradient(0, B.y, 0, B.y + B.h);
        g.addColorStop(0, "#3A2358");
        g.addColorStop(1, "#1D1030");
        ctx.fillStyle = g;
        ctx.fillRect(B.x, B.y, B.w, B.h);
        ctx.globalCompositeOperation = "lighter";
        for (const gl of glitter) {
          const a = Math.max(0, Math.sin(t * 4 + gl.ph)) * open;
          ctx.fillStyle = "rgba(220,180,255," + a + ")";
          ctx.beginPath();
          ctx.moveTo(gl.x, gl.y - 3); ctx.lineTo(gl.x + 2, gl.y);
          ctx.lineTo(gl.x, gl.y + 3); ctx.lineTo(gl.x - 2, gl.y);
          ctx.closePath(); ctx.fill();
        }
        ctx.globalCompositeOperation = "source-over";
        ctx.restore();
      }
      // the two rock halves slide apart around the treasure
      for (const side of [-1, 1]) {
        ctx.save();
        ctx.beginPath();
        ctx.rect(side < 0 ? 0 : B.cx + gap / 2, 0, B.cx - gap / 2, H);
        ctx.clip();
        ctx.translate(side * gap / 2, 0);
        face("#2E2620", "rgba(180,160,140,0.5)");
        if (open < 0.4) label("GEODE", "#E5DACB");
        ctx.restore();
      }
    }
  };
});

def("Tectonic", "earth", "three plates drift and grind; press to collide them", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  let clash = 0, uplift = [];
  return {
    press() {
      clash = 1;
      for (let i = 0; i < 8; i++)
        uplift.push({ x: B.x + B.w * (0.33 + (i % 2) * 0.34) + rand(-4, 4), y: B.cy,
                      vy: rand(-50, -20), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const pw = B.w / 3;
      for (let p = 0; p < 3; p++) {       // each plate drifts on its own clock
        let off = Math.sin(t * (0.4 + p * 0.2) + p * 2) * 2;
        off += clash * (p === 1 ? 0 : (p === 0 ? 3 : -3));  // press: outer plates shove in
        ctx.save();
        ctx.beginPath();
        ctx.rect(B.x + p * pw, B.y - 8, pw, B.h + 16);
        ctx.clip();
        ctx.translate(off, Math.sin(t * 0.6 + p) * 1);
        face("#28211A", "rgba(190,165,125,0.5)");
        label("PANGAEA", "#E8DCC8");
        ctx.restore();
        if (p < 2) {                      // the grinding seams
          const sx = B.x + (p + 1) * pw;
          ctx.strokeStyle = "rgba(255,140,60," + (0.2 + clash * 0.7) + ")";
          ctx.lineWidth = 1 + clash * 2;
          ctx.beginPath(); ctx.moveTo(sx, B.y); ctx.lineTo(sx, B.y + B.h); ctx.stroke();
        }
      }
      for (const up of uplift) {          // mountains, in miniature and in a hurry
        up.y += up.vy * dt; up.vy *= Math.pow(0.1, dt); up.life -= dt * 0.9;
        if (up.life > 0) {
          ctx.fillStyle = "rgba(200,175,135," + up.life + ")";
          ctx.beginPath();
          ctx.moveTo(up.x - 4, up.y + 4); ctx.lineTo(up.x, up.y - 4); ctx.lineTo(up.x + 4, up.y + 4);
          ctx.closePath(); ctx.fill();
        }
      }
      uplift = uplift.filter(up => up.life > 0);
      clash = Math.max(0, clash - dt * 1.3);
    }
  };
});

def("Quicksand", "earth", "the caption is slowly sinking; press to pull it back out", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  let sink = 0, splash = [];
  return {
    press() {
      sink = Math.max(-6, sink - 14);     // yanked out (a little above the line)
      for (let i = 0; i < 10; i++)
        splash.push({ x: B.cx + rand(-30, 30), y: B.cy + 6, vx: rand(-30, 30), vy: rand(-60, -20), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("#3A2E1C", "rgba(210,180,130,0.5)");
      sink = Math.min(B.h * 0.75, sink + dt * 1.6);    // the sand always wins, slowly
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      ctx.save();
      ctx.translate(0, sink);
      label("HELP", "#F0E4C8");
      ctx.restore();
      // the sand surface sits above the sinking text, swallowing it
      ctx.fillStyle = "#4A3B24";
      ctx.beginPath();
      ctx.moveTo(B.x, B.y + B.h);
      ctx.lineTo(B.x, B.cy + 8);
      for (let x = B.x; x <= B.x + B.w; x += 6)
        ctx.lineTo(x, B.cy + 8 + Math.sin(x * 0.15 + t * 1.2) * 1.5);
      ctx.lineTo(B.x + B.w, B.y + B.h);
      ctx.closePath(); ctx.fill();
      // ripple rings where the text goes under
      if (Math.random() < 0.04) {
        ctx.strokeStyle = "rgba(220,195,140,0.4)"; ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.ellipse(B.cx + rand(-20, 20), B.cy + 8, rand(4, 9), 2, 0, 0, TAU);
        ctx.stroke();
      }
      ctx.restore();
      for (const s of splash) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 140 * dt; s.life -= dt * 1.4;
        if (s.life > 0) { ctx.fillStyle = "rgba(200,170,120," + s.life + ")"; ctx.fillRect(s.x, s.y, 2, 2); }
      }
      splash = splash.filter(s => s.life > 0);
    }
  };
});

def("Boulder", "earth", "a boulder patrols overhead; press and it drops on the button", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let bx = -12, by = 16, vy = 0, falling = false, rot = 0, squash = 0, dust = [];
  return {
    press() { if (!falling) { falling = true; vy = 0; } },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("#2A231C", "rgba(190,165,130,0.55)");
      label("LOOK UP", "#E8DCC8");
      if (!falling) {
        bx += 40 * dt; rot += 3 * dt;     // patrol left → right, then wrap
        if (bx > W + 12) bx = -12;
      } else {
        vy += 500 * dt; by += vy * dt; rot += 6 * dt;
        if (by > B.y - 8) {               // impact!
          if (vy > 60) {
            squash = 1;
            for (let i = 0; i < 10; i++)
              dust.push({ x: bx + rand(-6, 6), y: B.y, vx: rand(-60, 60), vy: rand(-40, -5), life: 1 });
            vy = -vy * 0.4;               // one bounce…
          } else { falling = false; by = 16; vy = 0; } // …then back on patrol
          by = Math.min(by, B.y - 8);
        }
      }
      squash = Math.max(0, squash - dt * 4);
      ctx.save();
      ctx.translate(bx, by); ctx.rotate(rot);
      ctx.scale(1 + squash * 0.3, 1 - squash * 0.3);
      ctx.fillStyle = "#57493A";
      ctx.beginPath(); ctx.arc(0, 0, 8, 0, TAU); ctx.fill();
      ctx.fillStyle = "rgba(30,24,18,0.5)";          // craters
      ctx.beginPath(); ctx.arc(-2.5, -2, 1.6, 0, TAU); ctx.fill();
      ctx.beginPath(); ctx.arc(3, 1.5, 1.2, 0, TAU); ctx.fill();
      ctx.restore();
      for (const d of dust) {
        d.x += d.vx * dt; d.y += d.vy * dt; d.vy += 80 * dt; d.life -= dt * 1.8;
        if (d.life > 0) { ctx.fillStyle = "rgba(180,160,130," + d.life * 0.7 + ")"; ctx.fillRect(d.x, d.y, 2, 2); }
      }
      dust = dust.filter(d => d.life > 0);
    }
  };
});

/* ============================== AIR & WIND ============================== */

def("Zephyr", "air", "breeze lines curve around the button; press for a gust", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  let gust = 0;
  const winds = [];
  for (let i = 0; i < 8; i++)
    winds.push({ p: rand(0, 1), lane: rand(-1, 1), v: rand(0.2, 0.4) });
  return {
    press() { gust = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,26,34,0.92)", "rgba(170,210,230,0.5)");
      label("BREEZE", "#DEF0F8");
      for (const wd of winds) {           // each line flows left→right, bending around the face
        wd.p += wd.v * (1 + gust * 3) * dt;
        if (wd.p > 1.15) { wd.p = -0.15; wd.lane = rand(-1, 1); }
        const x = W * wd.p;
        const dodge = Math.exp(-Math.pow((x - B.cx) / (B.w * 0.45), 2));  // bulge near the button
        const y = B.cy + wd.lane * (B.h * 0.35 + dodge * B.h * 0.75 * Math.sign(wd.lane || 1));
        ctx.strokeStyle = "rgba(190,225,245," + (0.3 + gust * 0.4) + ")";
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.moveTo(x - 14 - gust * 10, y + 2);
        ctx.quadraticCurveTo(x - 6, y - 1, x, y);
        ctx.stroke();
      }
      gust = Math.max(0, gust - dt * 1.3);
    }
  };
});

def("Cyclone", "air", "a pet tornado wanders beside the button; press to feed it", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let power = 0, debris = [];
  return {
    press() {
      power = 1;
      for (let i = 0; i < 10; i++)
        debris.push({ a: rand(0, TAU), h: rand(0, 1), va: rand(3, 7), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,24,32,0.92)", "rgba(180,200,220,0.5)");
      label("TWISTER", "#E2EBF2");
      const cx = B.cx + Math.sin(t * 0.5) * B.w * 0.55;   // the wander
      const baseY = B.y + B.h + 6, topY = B.y - 18 - power * 8;
      const size = 1 + power * 0.8;
      for (let i = 0; i < 9; i++) {       // the funnel: stacked rotating dashes
        const k = i / 8;                  // 0 = ground, 1 = top
        const y = baseY + (topY - baseY) * k;
        const r = (2 + k * 14) * size;
        const a = t * (6 - k * 2) + i;
        ctx.strokeStyle = "rgba(200,215,230," + (0.5 - k * 0.25 + power * 0.3) + ")";
        ctx.lineWidth = 1.4;
        ctx.beginPath();
        ctx.ellipse(cx + Math.sin(t * 2 + k * 3) * 3, y, r, r * 0.3, 0, a, a + 4);
        ctx.stroke();
      }
      for (const d of debris) {           // debris caught in the spin
        d.a += d.va * dt; d.h += dt * 0.5; d.life -= dt * 0.7;
        if (d.life <= 0 || d.h > 1) continue;
        const y = baseY + (topY - baseY) * d.h;
        const r = (2 + d.h * 14) * size;
        ctx.fillStyle = "rgba(190,180,160," + d.life * 0.8 + ")";
        ctx.fillRect(cx + Math.cos(d.a) * r, y + Math.sin(d.a) * r * 0.3, 2, 2);
      }
      debris = debris.filter(d => d.life > 0 && d.h <= 1);
      power = Math.max(0, power - dt * 0.6);
    }
  };
});

def("Smoke signal", "air", "one puff at a time drifts up; press to send three fast", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let puffs = [], timer = 1, queue = 0, qTimer = 0;
  function puff() {
    puffs.push({ x: B.cx + rand(-4, 4), y: B.y - 2, r: 4, life: 1 });
  }
  return {
    press() { queue = 3; qTimer = 0; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(24,20,26,0.92)", "rgba(200,190,200,0.5)");
      label("SIGNAL", "#E8E2E8");
      timer -= dt;
      if (timer <= 0) { puff(); timer = rand(1.8, 2.6); }
      if (queue > 0) {                    // the pressed message: three quick puffs
        qTimer -= dt;
        if (qTimer <= 0) { puff(); queue--; qTimer = 0.22; }
      }
      for (const p of puffs) {            // rise, spread, thin out
        p.y -= 22 * dt; p.r += 7 * dt; p.x += Math.sin(p.y * 0.15) * 6 * dt;
        p.life -= dt * 0.55;
        if (p.life <= 0) continue;
        ctx.fillStyle = "rgba(200,195,205," + 0.3 * p.life + ")";
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, TAU); ctx.fill();
      }
      puffs = puffs.filter(p => p.life > 0);
    }
  };
});

def("Fog bank", "air", "fog drifts across and hides the caption; press to part it", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let part = 0;
  const blobs = [];
  for (let i = 0; i < 6; i++)
    blobs.push({ ox: rand(-B.w, B.w), oy: rand(-10, 10), r: rand(14, 26), v: rand(6, 14) });
  return {
    press() { part = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(22,24,32,0.92)", "rgba(190,200,215,0.5)");
      label("PEA SOUP", "#E4E8EE");
      for (const b of blobs) {
        b.ox += b.v * dt;
        if (b.ox > B.w) b.ox = -B.w;      // loop the drift
        let x = B.cx + b.ox * 0.6;
        const push = part * 30 * Math.sign(b.ox || 1); // press shoves fog outward
        x += push;
        const a = 0.16 * (1 - part * 0.8);
        const g = ctx.createRadialGradient(x, B.cy + b.oy, 0, x, B.cy + b.oy, b.r);
        g.addColorStop(0, "rgba(210,215,225," + a + ")");
        g.addColorStop(1, "rgba(210,215,225,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(x, B.cy + b.oy, b.r, 0, TAU); ctx.fill();
      }
      part = Math.max(0, part - dt * 0.5);
    }
  };
});

def("Updraft", "air", "leaves ride a thermal past the button; press for a flurry", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  let leaves = [];
  function leaf(burst) {
    leaves.push({ x: rand(B.x - 20, B.x + B.w + 20), y: H + 6,
                  v: rand(26, 50) * (burst ? 1.8 : 1), ph: rand(0, 9),
                  rot: rand(0, 6), vr: rand(-4, 4),
                  col: Math.random() < 0.5 ? "150,190,90" : "210,160,70" });
  }
  return {
    press() { for (let i = 0; i < 12; i++) leaf(true); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(18,26,20,0.92)", "rgba(170,210,150,0.5)");
      label("THERMAL", "#E2F0D8");
      if (Math.random() < 0.05) leaf(false);
      for (const lf of leaves) {          // up on the thermal, swaying, spinning
        lf.y -= lf.v * dt; lf.x += Math.sin(t * 2 + lf.ph) * 16 * dt; lf.rot += lf.vr * dt;
        ctx.save();
        ctx.translate(lf.x, lf.y); ctx.rotate(lf.rot);
        ctx.fillStyle = "rgba(" + lf.col + ",0.85)";
        ctx.beginPath(); ctx.ellipse(0, 0, 3.4, 1.6, 0, 0, u.TAU); ctx.fill();
        ctx.restore();
      }
      leaves = leaves.filter(lf => lf.y > -8);
    }
  };
});

def("Vacuum", "air", "dust drifts inward forever; press to slam the airlock", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let suck = 0, ringR = 0;
  const motes = [];
  function reset(m) {
    const th = rand(0, TAU);
    m.x = B.cx + Math.cos(th) * W * 0.55; m.y = B.cy + Math.sin(th) * H * 0.55;
  }
  for (let i = 0; i < 30; i++) { const m = {}; reset(m); m.x = rand(0, W); m.y = rand(0, H); motes.push(m); }
  return {
    press() { suck = 1; ringR = W * 0.5; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(18,20,28,0.94)", "rgba(160,180,210,0.5)");
      label("INHALE", "#DCE6F2");
      const pull = 12 + suck * 260;       // px/s toward the centre
      for (const m of motes) {
        const dx = B.cx - m.x, dy = B.cy - m.y;
        const d = Math.max(4, Math.hypot(dx, dy));
        m.x += dx / d * pull * dt; m.y += dy / d * pull * dt;
        if (d < 10) reset(m);
        ctx.fillStyle = "rgba(180,195,215," + (0.3 + suck * 0.5) + ")";
        ctx.fillRect(m.x, m.y, 1.5, 1.5);
      }
      if (suck > 0) {                     // the implosion ring, closing in
        ringR = Math.max(0, ringR - 300 * dt);
        ctx.strokeStyle = "rgba(190,210,235," + suck * 0.6 + ")";
        ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.ellipse(B.cx, B.cy, ringR * 1.4, ringR * 0.8, 0, 0, TAU); ctx.stroke();
        suck = Math.max(0, suck - dt * 0.9);
      }
    }
  };
});

def("Sonic boom", "air", "speed lines shiver behind it; press to break the barrier", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let boom = 0;
  return {
    press() { boom = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const lean = 1.5 + boom * 4;        // the button strains forward
      for (let i = 0; i < 6; i++) {       // trailing speed lines
        const y = B.y + (i + 0.5) * B.h / 6;
        const len = 10 + Math.sin(t * 9 + i * 2) * 4 + boom * 26;
        ctx.strokeStyle = "rgba(180,200,225," + (0.25 + boom * 0.5) + ")";
        ctx.lineWidth = 1.2;
        ctx.beginPath(); ctx.moveTo(B.x - 4, y); ctx.lineTo(B.x - 4 - len, y); ctx.stroke();
      }
      ctx.save();
      ctx.translate(lean, 0);
      face("rgba(20,22,32,0.94)", "rgba(190,210,235,0.6)");
      label("MACH 1", "#E4ECF6");
      ctx.restore();
      if (boom > 0) {                     // the cone: flattened rings bursting backward
        ctx.strokeStyle = "rgba(220,235,255," + boom * 0.8 + ")";
        ctx.lineWidth = 2;
        const k = 1 - boom;
        for (let r = 0; r < 3; r++) {
          const rad = 10 + k * 70 + r * 12;
          ctx.beginPath();
          ctx.ellipse(B.x + B.w + 6, B.cy, rad * 0.5, rad, 0, -1.2, 1.2);
          ctx.stroke();
        }
        boom = Math.max(0, boom - dt * 1.4);
      }
    }
  };
});

def("Windsock", "air", "a ribbon streams from the corner; press to spike the wind", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  const N = 12, pts = [];
  for (let i = 0; i < N; i++) pts.push({ x: B.x + B.w, y: B.y + 8 });
  let wind = 1;
  return {
    press() { wind = 3.5; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,24,30,0.92)", "rgba(190,205,225,0.5)");
      label("GALE", "#E2EAF4");
      wind += (1 - wind) * dt * 0.8;
      // the ribbon: each point chases the one before it, plus wind and flutter
      pts[0].x = B.x + B.w - 2; pts[0].y = B.y + 8;
      for (let i = 1; i < N; i++) {
        const tx = pts[i - 1].x + 6 * wind;
        const ty = pts[i - 1].y + Math.sin(t * (6 + wind * 2) + i * 0.9) * (2.2 + wind);
        pts[i].x += (tx - pts[i].x) * Math.min(1, dt * 14);
        pts[i].y += (ty - pts[i].y) * Math.min(1, dt * 14);
      }
      ctx.strokeStyle = "rgba(255,150,90,0.9)";
      ctx.lineWidth = 3;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      for (const p of pts) ctx.lineTo(p.x, p.y);
      ctx.stroke();
    }
  };
});

/* ============================== LIGHT & GLOW ============================== */

def("Breath", "light", "the classic: glow expands, then dims, forever; press to bloom", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let bloom = 0;
  return {
    press() { bloom = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const breath = 0.5 + 0.5 * Math.sin(t * 1.1);    // ±, slow as sleep
      const r = B.h * (0.8 + breath * 0.35) + bloom * 30;
      ctx.globalCompositeOperation = "lighter";
      const g = ctx.createRadialGradient(B.cx, B.cy, 0, B.cx, B.cy, r);
      g.addColorStop(0, "rgba(150,160,255," + (0.28 + breath * 0.18 + bloom * 0.4) + ")");
      g.addColorStop(1, "rgba(90,99,200,0)");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(B.cx, B.cy, r, 0, TAU); ctx.fill();
      ctx.globalCompositeOperation = "source-over";
      face("rgba(18,14,32,0.88)", "rgba(180,190,255," + (0.4 + breath * 0.3 + bloom * 0.3) + ")");
      label("BREATHE", "#E6E8FF");
      bloom = Math.max(0, bloom - dt * 1.1);
    }
  };
});

def("Heartbeat", "light", "lub-dub from within; press to startle it", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let rate = 1, startle = 0;
  return {
    press() { startle = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      rate = 1 + startle * 1.4;           // a startled heart races, then calms
      startle = Math.max(0, startle - dt * 0.35);
      const cycle = (t * rate) % 1.2;     // two thumps early in each cycle
      const lub = Math.exp(-Math.pow((cycle - 0.12) * 14, 2));
      const dub = Math.exp(-Math.pow((cycle - 0.38) * 14, 2)) * 0.7;
      const beat = lub + dub;
      ctx.globalCompositeOperation = "lighter";
      const g = ctx.createRadialGradient(B.cx, B.cy, 0, B.cx, B.cy, B.h * 0.9);
      g.addColorStop(0, "rgba(255,110,140," + (0.12 + beat * 0.5) + ")");
      g.addColorStop(1, "rgba(200,40,80,0)");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(B.cx, B.cy, B.h * 0.9, 0, TAU); ctx.fill();
      ctx.globalCompositeOperation = "source-over";
      const s = 1 + beat * 0.03;          // the face itself swells a hair
      ctx.save();
      ctx.translate(B.cx, B.cy); ctx.scale(s, s); ctx.translate(-B.cx, -B.cy);
      face("rgba(30,14,22,0.9)", "rgba(255,150,170," + (0.4 + beat * 0.5) + ")");
      label("ALIVE", "#FFDDE6");
      ctx.restore();
    }
  };
});

def("Halo orbit", "light", "a bright bead rides the border; press and it splits into three", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let split = 0;
  return {
    press() { split = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(18,16,30,0.92)", "rgba(200,190,255,0.4)");
      label("SAINT", "#EAE4FF");
      ctx.globalCompositeOperation = "lighter";
      const n = split > 0 ? 3 : 1;
      for (let k = 0; k < n; k++) {       // beads share the ellipse, evenly phased
        const a = t * 2 + k * (TAU / 3) * Math.min(1, split * 2);
        const x = B.cx + Math.cos(a) * B.w * 0.55;
        const y = B.cy + Math.sin(a) * B.h * 0.85;
        const g = ctx.createRadialGradient(x, y, 0, x, y, 9);
        g.addColorStop(0, "rgba(255,250,220,0.95)");
        g.addColorStop(1, "rgba(255,220,140,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(x, y, 9, 0, TAU); ctx.fill();
        // a short arc-tail behind each bead
        ctx.strokeStyle = "rgba(255,235,180,0.5)";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.ellipse(B.cx, B.cy, B.w * 0.55, B.h * 0.85, 0, a - 0.7, a);
        ctx.stroke();
      }
      ctx.globalCompositeOperation = "source-over";
      split = Math.max(0, split - dt * 0.25);
    }
  };
});

def("Lens flare", "light", "a flare drifts across on schedule; press for the full anamorphic", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let big = 0, bx = 0, by = 0;
  return {
    press(x, y) { big = 1; bx = x || B.cx; by = y || B.cy; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(16,16,28,0.92)", "rgba(180,200,235,0.45)");
      label("CINEMA", "#E2EAF8");
      ctx.globalCompositeOperation = "lighter";
      const p = (t * 0.18) % 1.4 - 0.2;   // the scheduled pass, corner to corner
      const fx = W * p, fy = H * (0.2 + p * 0.5);
      const spots = [1, 0.5, -0.4, -0.9]; // ghosts along the lens axis
      for (const s of spots) {
        const gx = fx + (B.cx - fx) * (1 - s), gy = fy + (B.cy - fy) * (1 - s);
        const g = ctx.createRadialGradient(gx, gy, 0, gx, gy, 7 * Math.abs(s) + 3);
        g.addColorStop(0, "rgba(180,210,255," + 0.22 * Math.abs(s) + ")");
        g.addColorStop(1, "rgba(120,160,255,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(gx, gy, 7 * Math.abs(s) + 3, 0, TAU); ctx.fill();
      }
      ctx.strokeStyle = "rgba(200,225,255,0.35)";      // the horizontal streak
      ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(fx - 22, fy); ctx.lineTo(fx + 22, fy); ctx.stroke();
      if (big > 0) {                      // press: the money shot
        ctx.strokeStyle = "rgba(160,200,255," + big * 0.9 + ")";
        ctx.lineWidth = 2.5;
        ctx.beginPath(); ctx.moveTo(bx - 70 * (1.2 - big), by); ctx.lineTo(bx + 70 * (1.2 - big), by); ctx.stroke();
        const g = ctx.createRadialGradient(bx, by, 0, bx, by, 24);
        g.addColorStop(0, "rgba(230,240,255," + big * 0.8 + ")");
        g.addColorStop(1, "rgba(150,190,255,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(bx, by, 24, 0, TAU); ctx.fill();
        big = Math.max(0, big - dt * 1.6);
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Lighthouse", "light", "the beam sweeps round and round; press to aim it at your click", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let aim = null, hold = 0, a = 0;
  return {
    press(x, y) { aim = Math.atan2((y || 0) - B.cy, (x || 1) - B.cx); hold = 1.5; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      hold = Math.max(0, hold - dt);
      if (hold > 0 && aim !== null) {     // ease toward the demanded angle
        let d = aim - a;
        while (d > Math.PI) d -= TAU;
        while (d < -Math.PI) d += TAU;
        a += d * Math.min(1, dt * 8);
      } else a += dt * 1.5;
      ctx.globalCompositeOperation = "lighter";
      const bright = hold > 0 ? 0.4 : 0.22;
      const g = ctx.createRadialGradient(B.cx, B.cy, 0, B.cx, B.cy, W * 0.55);
      g.addColorStop(0, "rgba(255,240,190," + bright + ")");
      g.addColorStop(1, "rgba(255,220,150,0)");
      ctx.fillStyle = g;
      ctx.beginPath();                    // the wedge
      ctx.moveTo(B.cx, B.cy);
      ctx.arc(B.cx, B.cy, W * 0.55, a - 0.22, a + 0.22);
      ctx.closePath(); ctx.fill();
      ctx.globalCompositeOperation = "source-over";
      face("rgba(20,18,30,0.9)", "rgba(255,235,190," + (0.4 + (hold > 0 ? 0.4 : 0)) + ")");
      label("KEEPER", "#FFF2D6");
    }
  };
});

def("Firefly jar", "light", "fireflies blink on their own clocks; press to sync them once", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  const flies = [];
  for (let i = 0; i < 12; i++)
    flies.push({ x: rand(B.x + 8, B.x + B.w - 8), y: rand(B.y + 6, B.y + B.h - 6),
                 ph: rand(0, TAU), sp: rand(0.7, 1.4), wx: rand(0, 9), wy: rand(0, 9) });
  let sync = 0;
  return {
    press() { sync = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(14,20,16,0.94)", "rgba(190,230,160,0.5)");
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      ctx.globalCompositeOperation = "lighter";
      for (const f of flies) {
        f.x += Math.sin(t * 0.7 + f.wx) * 6 * dt;      // aimless jar-wandering
        f.y += Math.cos(t * 0.9 + f.wy) * 5 * dt;
        // blink: own phase normally; sync forces everyone bright together
        let blink = Math.max(0, Math.sin(t * f.sp * 2 + f.ph));
        blink = Math.pow(blink, 3);
        blink = Math.max(blink, sync);
        const g = ctx.createRadialGradient(f.x, f.y, 0, f.x, f.y, 5);
        g.addColorStop(0, "rgba(220,255,140," + blink * 0.9 + ")");
        g.addColorStop(1, "rgba(180,255,80,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(f.x, f.y, 5, 0, TAU); ctx.fill();
      }
      ctx.globalCompositeOperation = "source-over";
      ctx.restore();
      label("JAR", "rgba(230,250,210,0.85)");
      sync = Math.max(0, sync - dt * 1.5);
    }
  };
});

def("Prism", "light", "white light splits into drifting rainbow bands; press to sweep", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  let sweep = -1;
  return {
    press() { sweep = 0; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,20,28,0.94)", "rgba(220,220,235,0.5)");
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      ctx.globalCompositeOperation = "lighter";
      // the white beam entering at the left edge
      ctx.fillStyle = "rgba(255,255,255,0.5)";
      ctx.fillRect(B.x, B.cy - 2, 12, 4);
      for (let i = 0; i < 6; i++) {       // six bands fanning out
        const hue = i * 52 + Math.sin(t * 0.7) * 14;
        const spreadY = (i - 2.5) * (5 + Math.sin(t * 0.9) * 1.4);
        ctx.strokeStyle = "hsla(" + hue + ",95%,62%,0.5)";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(B.x + 12, B.cy);
        ctx.lineTo(B.x + B.w, B.cy + spreadY);
        ctx.stroke();
      }
      if (sweep >= 0) {                   // press: a rainbow wall crosses the face
        sweep += dt * 1.8;
        const x = B.x + B.w * sweep;
        for (let i = 0; i < 6; i++) {
          ctx.fillStyle = "hsla(" + i * 52 + ",95%,60%,0.5)";
          ctx.fillRect(x - i * 5, B.y, 4, B.h);
        }
        if (sweep > 1.3) sweep = -1;
      }
      ctx.globalCompositeOperation = "source-over";
      ctx.restore();
      label("REFRACT", "#F0F0FA");
    }
  };
});

def("Spotlight", "light", "roaming lights reveal pieces of the caption; press for house lights", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  let house = 0;
  return {
    press() { house = 1.6; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(8,8,14,0.96)", "rgba(120,120,150,0.4)");
      house = Math.max(0, house - dt);
      const spots = [
        { x: B.cx + Math.sin(t * 0.9) * B.w * 0.3, y: B.cy + Math.cos(t * 0.7) * B.h * 0.3, r: 16 },
        { x: B.cx + Math.sin(t * 0.6 + 3) * B.w * 0.35, y: B.cy + Math.cos(t * 1.1 + 1) * B.h * 0.25, r: 13 }
      ];
      // the caption exists only where light falls (plus during house lights)
      ctx.save();
      if (house <= 0) {
        ctx.beginPath();
        for (const s of spots) { ctx.moveTo(s.x + s.r, s.y); ctx.arc(s.x, s.y, s.r, 0, TAU); }
        ctx.clip();
      }
      label("ON STAGE", "#F5EFD8");
      ctx.restore();
      ctx.globalCompositeOperation = "lighter";
      for (const s of spots) {            // the pools of light themselves
        const g = ctx.createRadialGradient(s.x, s.y, 0, s.x, s.y, s.r * 1.6);
        g.addColorStop(0, "rgba(255,245,210," + (0.2 + house * 0.15) + ")");
        g.addColorStop(1, "rgba(255,235,170,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(s.x, s.y, s.r * 1.6, 0, TAU); ctx.fill();
      }
      if (house > 0) {
        ctx.fillStyle = "rgba(255,245,215," + Math.min(0.2, house * 0.15) + ")";
        rr(B.x, B.y, B.w, B.h, B.r); ctx.fill();
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Glowworm", "light", "a worm of light inches along the border; press and it sprints a lap", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let p = 0, sprint = 0;
  const trail = [];
  return {
    press() { sprint = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(16,20,16,0.94)", "rgba(150,200,140,0.35)");
      label("INCH", "#E0F2DC");
      sprint = Math.max(0, sprint - dt * 0.45);
      p += dt * (0.25 + sprint * 1.6);    // laps per second
      const a = p * TAU;
      const x = B.cx + Math.cos(a) * B.w * 0.52;
      const y = B.cy + Math.sin(a) * B.h * 0.62;
      trail.push({ x: x, y: y, life: 1 });
      if (trail.length > 40) trail.shift();
      ctx.globalCompositeOperation = "lighter";
      for (const seg of trail) {          // the glow lingers where it has been
        seg.life -= dt * 0.5;
        if (seg.life <= 0) continue;
        ctx.fillStyle = "rgba(190,255,150," + seg.life * 0.35 + ")";
        ctx.beginPath(); ctx.arc(seg.x, seg.y, 3, 0, TAU); ctx.fill();
      }
      const g = ctx.createRadialGradient(x, y, 0, x, y, 7);
      g.addColorStop(0, "rgba(230,255,190,0.95)");
      g.addColorStop(1, "rgba(160,255,110,0)");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(x, y, 7, 0, TAU); ctx.fill();
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Supernova", "light", "it charges for six slow seconds, then releases; press to detonate now", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let charge = 0, nova = 0, ring = 0;
  return {
    press() { nova = 1; ring = 4; charge = 0; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      if (nova <= 0) {
        charge += dt / 6;                 // the six-second gather
        if (charge >= 1) { nova = 1; ring = 4; charge = 0; }
      }
      ctx.globalCompositeOperation = "lighter";
      const coreR = 6 + charge * 16 + nova * 30;
      const coreA = 0.25 + charge * 0.55 + nova * 0.2;
      const g = ctx.createRadialGradient(B.cx, B.cy, 0, B.cx, B.cy, coreR);
      g.addColorStop(0, "rgba(255,250,230," + Math.min(1, coreA) + ")");
      g.addColorStop(1, "rgba(255,180,90,0)");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(B.cx, B.cy, coreR, 0, TAU); ctx.fill();
      if (nova > 0) {                     // release: ring + radial streaks
        ring += 90 * dt;
        ctx.strokeStyle = "rgba(255,235,190," + nova * 0.8 + ")";
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.ellipse(B.cx, B.cy, ring * 1.5, ring * 0.85, 0, 0, TAU); ctx.stroke();
        for (let i = 0; i < 8; i++) {
          const th = i / 8 * TAU + 0.4;
          ctx.strokeStyle = "rgba(255,220,150," + nova * 0.6 + ")";
          ctx.lineWidth = 1.4;
          ctx.beginPath();
          ctx.moveTo(B.cx + Math.cos(th) * coreR * 0.8, B.cy + Math.sin(th) * coreR * 0.5);
          ctx.lineTo(B.cx + Math.cos(th) * (coreR + ring), B.cy + Math.sin(th) * (coreR + ring) * 0.6);
          ctx.stroke();
        }
        nova = Math.max(0, nova - dt * 0.9);
      }
      ctx.globalCompositeOperation = "source-over";
      face("rgba(24,18,30,0.82)", "rgba(255,220,170," + (0.35 + charge * 0.5) + ")");
      label(nova > 0 ? "NOVA" : "CHARGING", "#FFF0D8");
    }
  };
});

/* ============================== SPARKS ============================== */

def("Grindstone", "sparks", "the wheel throws sparks off one corner; press to lean in", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let sparks = [], lean = 0;
  function shed(n) {
    for (let i = 0; i < n; i++)
      sparks.push({ x: B.x + B.w - 6, y: B.y + B.h - 4,
                    vx: rand(30, 120), vy: rand(-100, -20), life: rand(0.5, 1) });
  }
  return {
    press() { lean = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(26,24,28,0.94)", "rgba(200,190,180,0.5)");
      label("GRIND", "#EEE8E0");
      // the wheel itself, spinning at the corner
      ctx.save();
      ctx.translate(B.x + B.w - 4, B.y + B.h - 2);
      ctx.rotate(t * (7 + lean * 8));
      ctx.fillStyle = "#4A4650";
      ctx.beginPath(); ctx.arc(0, 0, 7, 0, TAU); ctx.fill();
      ctx.strokeStyle = "rgba(220,215,225,0.6)"; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(-7, 0); ctx.lineTo(7, 0); ctx.moveTo(0, -7); ctx.lineTo(0, 7); ctx.stroke();
      ctx.restore();
      if (Math.random() < 0.25 + lean * 0.7) shed(lean > 0 ? 4 : 1);
      ctx.globalCompositeOperation = "lighter";
      for (const s of sparks) {           // chapter 6's four lines, verbatim
        s.x += s.vx * dt; s.y += s.vy * dt;
        s.vy += 300 * dt; s.life -= dt * 1.4;
        if (s.life > 0) {
          ctx.strokeStyle = "rgba(255," + Math.round(150 + s.life * 100) + ",60," + s.life + ")";
          ctx.lineWidth = 1.3;
          ctx.beginPath(); ctx.moveTo(s.x, s.y); ctx.lineTo(s.x - s.vx * 0.02, s.y - s.vy * 0.02); ctx.stroke();
        }
      }
      ctx.globalCompositeOperation = "source-over";
      sparks = sparks.filter(s => s.life > 0);
      lean = Math.max(0, lean - dt * 1.2);
    }
  };
});

def("Sparkler", "sparks", "a fizzing point rides the border; press to light a second one", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let second = 0;
  function fizz(x, y) {
    ctx.strokeStyle = "rgba(255,230,170,0.9)";
    ctx.lineWidth = 1;
    for (let i = 0; i < 7; i++) {         // radial fizz-lines, new every frame
      const th = rand(0, TAU), L = rand(3, 10);
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + Math.cos(th) * L, y + Math.sin(th) * L);
      ctx.stroke();
    }
  }
  return {
    press() { second = 5; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(22,18,26,0.94)", "rgba(255,210,150,0.4)");
      label("FIZZ", "#FFEED4");
      ctx.globalCompositeOperation = "lighter";
      const a = t * 1.3;
      fizz(B.cx + Math.cos(a) * B.w * 0.52, B.cy + Math.sin(a) * B.h * 0.62);
      if (second > 0) {
        fizz(B.cx + Math.cos(a + Math.PI) * B.w * 0.52, B.cy + Math.sin(a + Math.PI) * B.h * 0.62);
        second -= dt;
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Flint", "sparks", "dead still until struck — press for the strike", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let sparks = [], flash = 0;
  return {
    press() {
      flash = 1;
      for (let i = 0; i < 20; i++) {
        const th = rand(-2.6, -0.5);      // a directed cone, up and right
        const v = rand(60, 220);
        sparks.push({ x: B.x + 14, y: B.y + B.h - 8,
                      vx: Math.cos(th) * v, vy: Math.sin(th) * v, life: rand(0.4, 1) });
      }
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      // this species is the pure thank-you: no idle loop at all
      face("rgba(24,22,26," + (0.94 - flash * 0.3) + ")", "rgba(190,180,170," + (0.4 + flash * 0.6) + ")");
      label("STRIKE", "#EAE4DC");
      if (Math.random() < 0.008) {        // …except one shy glint, rarely
        ctx.fillStyle = "rgba(255,255,255,0.7)";
        ctx.fillRect(B.x + 13, B.y + B.h - 9, 2, 2);
      }
      ctx.globalCompositeOperation = "lighter";
      for (const s of sparks) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 260 * dt; s.life -= dt * 1.7;
        if (s.life > 0) {
          ctx.strokeStyle = "rgba(255,210,130," + s.life + ")";
          ctx.lineWidth = 1.2;
          ctx.beginPath(); ctx.moveTo(s.x, s.y); ctx.lineTo(s.x - s.vx * 0.015, s.y - s.vy * 0.015); ctx.stroke();
        }
      }
      ctx.globalCompositeOperation = "source-over";
      sparks = sparks.filter(s => s.life > 0);
      flash = Math.max(0, flash - dt * 4);
    }
  };
});

def("Welding seam", "sparks", "an arc crawls the border leaving cooling metal; press for spatter", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let p = 0, seam = [], spatter = [];
  return {
    press() {
      const a = p * TAU;
      const x = B.cx + Math.cos(a) * B.w * 0.52, y = B.cy + Math.sin(a) * B.h * 0.62;
      for (let i = 0; i < 12; i++)
        spatter.push({ x: x, y: y, vx: rand(-90, 90), vy: rand(-90, 40), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(22,22,28,0.94)", "rgba(170,175,190,0.45)");
      label("WELD", "#E6E8EE");
      p = (p + dt * 0.12) % 1;            // slow, patient work
      const a = p * TAU;
      const x = B.cx + Math.cos(a) * B.w * 0.52, y = B.cy + Math.sin(a) * B.h * 0.62;
      seam.push({ x: x, y: y, age: 0 });
      if (seam.length > 110) seam.shift();
      for (const s of seam) {             // the seam cools white → orange → dull red
        s.age += dt;
        const k = Math.min(1, s.age / 4);
        const rC = Math.round(255 - k * 130);
        const gC = Math.round(230 - k * 190);
        const bC = Math.round(170 - k * 140);
        ctx.fillStyle = "rgb(" + rC + "," + gC + "," + bC + ")";
        ctx.fillRect(s.x - 1, s.y - 1, 2.4, 2.4);
      }
      ctx.globalCompositeOperation = "lighter";
      const g = ctx.createRadialGradient(x, y, 0, x, y, 8 + rand(0, 3));
      g.addColorStop(0, "rgba(240,250,255,0.95)");     // the arc: painfully bright
      g.addColorStop(1, "rgba(140,180,255,0)");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(x, y, 10, 0, TAU); ctx.fill();
      for (const sp of spatter) {
        sp.x += sp.vx * dt; sp.y += sp.vy * dt; sp.vy += 240 * dt; sp.life -= dt * 1.6;
        if (sp.life > 0) { ctx.fillStyle = "rgba(255,200,120," + sp.life + ")"; ctx.fillRect(sp.x, sp.y, 2, 2); }
      }
      ctx.globalCompositeOperation = "source-over";
      spatter = spatter.filter(sp => sp.life > 0);
    }
  };
});

def("Fountain", "sparks", "a firework fountain plays over the button; press for three rockets", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let jets = [], rockets = [];
  return {
    press() {
      for (let i = 0; i < 3; i++)
        rockets.push({ x: rand(B.x, B.x + B.w), y: rand(8, B.y - 20), fuse: i * 0.16, burst: [] });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,16,28,0.92)", "rgba(255,200,130,0.45)");
      label("FIESTA", "#FFEFD2");
      const swell = 0.5 + 0.5 * Math.sin(t * 0.8);     // the fountain breathes
      if (Math.random() < 0.4 + swell * 0.4)
        jets.push({ x: B.cx + rand(-4, 4), y: B.y - 2,
                    vx: rand(-30, 30), vy: rand(-110, -60) * (0.7 + swell * 0.5), life: 1 });
      ctx.globalCompositeOperation = "lighter";
      for (const j of jets) {
        j.x += j.vx * dt; j.y += j.vy * dt; j.vy += 170 * dt; j.life -= dt * 1.1;
        if (j.life > 0) { ctx.fillStyle = "rgba(255,215,130," + j.life + ")"; ctx.fillRect(j.x, j.y, 1.8, 1.8); }
      }
      jets = jets.filter(j => j.life > 0);
      for (const rk of rockets) {         // fuse burns, then the sphere of stars
        rk.fuse -= dt;
        if (rk.fuse <= 0 && rk.burst.length === 0)
          for (let i = 0; i < 16; i++) {
            const th = i / 16 * TAU;
            rk.burst.push({ x: rk.x, y: rk.y, vx: Math.cos(th) * rand(40, 80), vy: Math.sin(th) * rand(40, 80), life: 1 });
          }
        for (const bs of rk.burst) {
          bs.x += bs.vx * dt; bs.y += bs.vy * dt; bs.vy += 60 * dt; bs.life -= dt * 1.2;
          if (bs.life > 0) { ctx.fillStyle = "rgba(255,170,200," + bs.life + ")"; ctx.fillRect(bs.x, bs.y, 2, 2); }
        }
      }
      ctx.globalCompositeOperation = "source-over";
      rockets = rockets.filter(rk => rk.fuse > 0 || rk.burst.some(bs => bs.life > 0));
    }
  };
});

def("Pixie dust", "sparks", "glitter sheds off the caption; press to stir a spiral of it", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let dust = [], spiral = 0;
  return {
    press() { spiral = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(24,18,32,0.92)", "rgba(230,190,255,0.5)");
      label("PIXIE", "#F4E2FF");
      if (Math.random() < 0.35)
        dust.push({ x: B.cx + rand(-34, 34), y: B.cy + rand(-6, 6),
                    a: rand(0, TAU), life: 1, tw: rand(4, 9) });
      ctx.globalCompositeOperation = "lighter";
      for (const d of dust) {
        if (spiral > 0) {                 // the stir: everything orbits the centre
          d.a += 4 * dt;
          const rr2 = 18 + (1 - d.life) * 26;
          d.x = B.cx + Math.cos(d.a) * rr2 * 1.6;
          d.y = B.cy + Math.sin(d.a) * rr2 * 0.8;
        } else { d.y += 14 * dt; d.x += Math.sin(t * 3 + d.tw) * 5 * dt; }
        d.life -= dt * 0.5;
        if (d.life <= 0) continue;
        const twinkle = Math.max(0, Math.sin(t * d.tw)) * d.life;
        ctx.strokeStyle = "rgba(240,210,255," + twinkle + ")";
        ctx.lineWidth = 1;
        ctx.beginPath();                  // a tiny 4-point star
        ctx.moveTo(d.x - 2.5, d.y); ctx.lineTo(d.x + 2.5, d.y);
        ctx.moveTo(d.x, d.y - 2.5); ctx.lineTo(d.x, d.y + 2.5);
        ctx.stroke();
      }
      ctx.globalCompositeOperation = "source-over";
      dust = dust.filter(d => d.life > 0);
      spiral = Math.max(0, spiral - dt * 0.7);
    }
  };
});

/* ============================== COSMIC & VOID ============================== */

def("Black hole", "cosmic", "stars spiral into it forever; press to feed the accretion disk", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let feed = 0;
  const stars = [];
  for (let i = 0; i < 40; i++)
    stars.push({ a: rand(0, TAU), r: rand(20, W * 0.5), v: rand(0.4, 1) });
  return {
    press() { feed = 1; },
    frame(dt, t) {
      ctx.fillStyle = "rgba(8,7,14,0.4)"; ctx.fillRect(0, 0, W, H);   // streaky fade
      const pull = 1 + feed * 3;
      for (const s of stars) {
        s.a += s.v * pull * (30 / Math.max(12, s.r)) * dt;   // closer = faster
        s.r -= (2 + feed * 22) * dt;
        if (s.r < 10) { s.r = W * rand(0.35, 0.5); s.a = rand(0, TAU); }
        const x = B.cx + Math.cos(s.a) * s.r;
        const y = B.cy + Math.sin(s.a) * s.r * 0.55;
        ctx.fillStyle = "rgba(220,215,255," + (0.5 + feed * 0.4) + ")";
        ctx.fillRect(x, y, 1.5, 1.5);
      }
      ctx.globalCompositeOperation = "lighter";        // the lensed photon ring
      ctx.strokeStyle = "rgba(255,190,120," + (0.5 + feed * 0.5) + ")";
      ctx.lineWidth = 2 + feed * 2;
      ctx.beginPath(); ctx.ellipse(B.cx, B.cy, B.w * 0.36, B.h * 0.62, 0, 0, TAU); ctx.stroke();
      ctx.globalCompositeOperation = "source-over";
      face("rgba(0,0,0,0.95)", "rgba(90,80,120,0.6)");
      label("EVENT HORIZON", "rgba(200,190,230,0.75)");
      feed = Math.max(0, feed - dt * 0.8);
    }
  };
});

def("Galaxy", "cosmic", "a two-armed spiral turns behind the face; press to spin it up", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let spin = 1, a0 = 0;
  const arms = [];
  for (let arm = 0; arm < 2; arm++)
    for (let i = 0; i < 40; i++) {
      const d = i / 40;
      arms.push({ d: d, off: arm * Math.PI + d * 3.4 + rand(-0.18, 0.18), r: 8 + d * W * 0.42 });
    }
  return {
    press() { spin = 4; },
    frame(dt, t) {
      ctx.fillStyle = "#0B0A16"; ctx.fillRect(0, 0, W, H);
      spin += (1 - spin) * dt * 0.7;
      a0 += spin * 0.3 * dt;
      ctx.globalCompositeOperation = "lighter";
      const cg = ctx.createRadialGradient(B.cx, B.cy, 0, B.cx, B.cy, 16);
      cg.addColorStop(0, "rgba(255,240,210,0.7)");     // the old, yellow core
      cg.addColorStop(1, "rgba(255,220,170,0)");
      ctx.fillStyle = cg;
      ctx.beginPath(); ctx.arc(B.cx, B.cy, 16, 0, TAU); ctx.fill();
      for (const s of arms) {             // young blue stars out in the arms
        const a = a0 + s.off;
        const x = B.cx + Math.cos(a) * s.r;
        const y = B.cy + Math.sin(a) * s.r * 0.5;
        ctx.fillStyle = "rgba(" + Math.round(170 + s.d * 60) + "," + Math.round(190 + s.d * 40) + ",255," + (0.65 - s.d * 0.35) + ")";
        ctx.fillRect(x, y, 1.6, 1.6);
      }
      ctx.globalCompositeOperation = "source-over";
      face("rgba(14,12,26,0.82)", "rgba(170,180,255,0.45)");
      label("SPIRAL", "#E4E6FF");
    }
  };
});

def("Nebula", "cosmic", "gas clouds slowly morph; press to ignite a newborn star", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let born = [];
  const gas = [
    { hue: 280, ph: 0 }, { hue: 320, ph: 2 }, { hue: 190, ph: 4 }, { hue: 250, ph: 5 }
  ];
  return {
    press() {
      born.push({ x: B.cx + rand(-B.w * 0.4, B.w * 0.4), y: B.cy + rand(-B.h, B.h), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#0B0A16"; ctx.fillRect(0, 0, W, H);
      ctx.globalCompositeOperation = "lighter";
      for (const g of gas) {              // each cloud breathes and drifts
        const x = B.cx + Math.sin(t * 0.21 + g.ph) * B.w * 0.34;
        const y = B.cy + Math.cos(t * 0.16 + g.ph * 2) * B.h * 0.8;
        const r = 26 + Math.sin(t * 0.3 + g.ph) * 8;
        const gr = ctx.createRadialGradient(x, y, 0, x, y, r);
        gr.addColorStop(0, "hsla(" + g.hue + ",80%,60%,0.13)");
        gr.addColorStop(1, "hsla(" + g.hue + ",80%,60%,0)");
        ctx.fillStyle = gr;
        ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
      }
      for (const s of born) {             // ignition: a point flares, then settles
        s.life -= dt * 0.4;
        if (s.life <= 0) continue;
        const flare = Math.max(0, Math.sin((1 - s.life) * Math.PI));
        ctx.fillStyle = "rgba(255,255,240," + (0.4 + flare * 0.6) + ")";
        ctx.fillRect(s.x - 1, s.y - 1, 2.5, 2.5);
        ctx.strokeStyle = "rgba(255,255,240," + flare * 0.6 + ")";
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(s.x - 6 * flare, s.y); ctx.lineTo(s.x + 6 * flare, s.y);
        ctx.moveTo(s.x, s.y - 6 * flare); ctx.lineTo(s.x, s.y + 6 * flare);
        ctx.stroke();
      }
      born = born.filter(s => s.life > 0);
      ctx.globalCompositeOperation = "source-over";
      face("rgba(16,12,28,0.8)", "rgba(210,170,255,0.45)");
      label("STELLAR NURSERY", "rgba(240,225,255,0.85)");
    }
  };
});

def("Constellation", "cosmic", "stars connect into a figure, redrawn each pass; press for a new one", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  const stars = [];
  for (let i = 0; i < 14; i++)
    stars.push({ x: rand(B.x + 8, B.x + B.w - 8), y: rand(B.y + 6, B.y + B.h - 6), tw: rand(2, 6) });
  let figure = [], age = 0;
  function redraw() {
    figure = [];
    let idx = Math.floor(rand(0, stars.length));
    for (let i = 0; i < 5; i++) {         // a five-star figure, nearest-neighbour-ish
      figure.push(idx);
      idx = (idx + Math.floor(rand(1, 5))) % stars.length;
    }
    age = 0;
  }
  redraw();
  return {
    press() { redraw(); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(12,12,26,0.95)", "rgba(150,160,220,0.5)");
      age += dt;
      if (age > 5) redraw();              // the sky rearranges itself, patiently
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      for (const s of stars) {
        const a = 0.35 + 0.5 * Math.max(0, Math.sin(t * s.tw));
        ctx.fillStyle = "rgba(230,235,255," + a + ")";
        ctx.fillRect(s.x - 0.8, s.y - 0.8, 1.8, 1.8);
      }
      const reveal = Math.min(1, age / 1.6);           // the figure inks itself in
      ctx.strokeStyle = "rgba(180,200,255," + (0.6 - age * 0.08) + ")";
      ctx.lineWidth = 1;
      ctx.beginPath();
      const segs = Math.max(1, Math.floor(reveal * (figure.length - 1) + 1));
      ctx.moveTo(stars[figure[0]].x, stars[figure[0]].y);
      for (let i = 1; i < segs && i < figure.length; i++)
        ctx.lineTo(stars[figure[i]].x, stars[figure[i]].y);
      ctx.stroke();
      ctx.restore();
      label("MYTHOLOGY", "rgba(225,230,255,0.8)");
    }
  };
});

def("Eclipse", "cosmic", "the moon crosses the sun on a slow orbit; press to jump to totality", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let jump = 0;
  return {
    press() { jump = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const sx = B.cx, sy = B.y - 20, srad = 11;
      // the transit: moon slides across on a slow cosine; press parks it dead centre
      let mx = sx + Math.cos(t * 0.35) * 34;
      if (jump > 0) mx = sx + (mx - sx) * (1 - jump);
      const cover = Math.max(0, 1 - Math.abs(mx - sx) / (srad * 2));  // 1 = totality
      ctx.globalCompositeOperation = "lighter";
      const g = ctx.createRadialGradient(sx, sy, srad * 0.5, sx, sy, srad * (2 + cover * 2.4));
      g.addColorStop(0, "rgba(255,240,200," + (0.5 - cover * 0.25) + ")");
      g.addColorStop(1, "rgba(255,200,120,0)");
      ctx.fillStyle = g;                  // corona: biggest at totality
      ctx.beginPath(); ctx.arc(sx, sy, srad * (2 + cover * 2.4), 0, TAU); ctx.fill();
      ctx.fillStyle = "rgba(255,235,190,0.95)";
      ctx.beginPath(); ctx.arc(sx, sy, srad, 0, TAU); ctx.fill();
      ctx.globalCompositeOperation = "source-over";
      ctx.fillStyle = "#14111F";          // the moon is a hole in the light
      ctx.beginPath(); ctx.arc(mx, sy, srad * 0.96, 0, TAU); ctx.fill();
      face("rgba(20,16,30," + (0.9 - cover * 0.3) + ")", "rgba(255,225,170," + (0.35 + cover * 0.55) + ")");
      label(cover > 0.85 ? "TOTALITY" : "TRANSIT", "#FFF0D2");
      jump = Math.max(0, jump - dt * 0.5);
    }
  };
});

def("Wormhole", "cosmic", "rings fall inward down the throat; press to reverse the flow", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let dir = -1, revT = 0;                 // -1 = inward, +1 = outward
  const rings = [];
  for (let i = 0; i < 7; i++) rings.push({ k: i / 7 });
  return {
    press() { dir = 1; revT = 2; },
    frame(dt, t) {
      ctx.fillStyle = "rgba(10,9,18,0.55)"; ctx.fillRect(0, 0, W, H);
      revT -= dt;
      if (revT <= 0) dir = -1;
      for (const ring of rings) {         // k runs 1 → 0 (in) or 0 → 1 (out)
        ring.k += dir * -0.25 * dt;
        if (ring.k <= 0) ring.k += 1;
        if (ring.k > 1) ring.k -= 1;
        const rw = B.w * 0.15 + ring.k * W * 0.42;
        const a = Math.sin(ring.k * Math.PI) * 0.55;   // faint at both ends
        ctx.strokeStyle = "hsla(" + (255 + ring.k * 60) + ",80%,65%," + a + ")";
        ctx.lineWidth = 1.6;
        ctx.beginPath(); ctx.ellipse(B.cx, B.cy, rw, rw * 0.5, 0, 0, TAU); ctx.stroke();
      }
      face("rgba(14,10,26,0.85)", "rgba(190,160,255,0.5)");
      label("THROAT", "#EBE0FF");
    }
  };
});

def("Antimatter", "cosmic", "the button phase-inverts in waves; press to annihilate a pair", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  let pairs = [], flash = 0;
  return {
    press() {
      flash = 1;
      for (let i = 0; i < 5; i++) {
        const th = rand(0, TAU), v = rand(50, 110);
        // matter and antimatter part ways at birth, in exactly opposite directions
        pairs.push({ x: B.cx, y: B.cy, vx: Math.cos(th) * v, vy: Math.sin(th) * v, life: 1, anti: false });
        pairs.push({ x: B.cx, y: B.cy, vx: -Math.cos(th) * v, vy: -Math.sin(th) * v, life: 1, anti: true });
      }
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,16,30,0.94)", "rgba(200,200,230,0.5)");
      label("CPT", "#E6E6F4");
      // the inversion pulse: a "difference" white bar drifts over the face
      const px = B.x + ((t * 30) % (B.w + 40)) - 20;
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      ctx.globalCompositeOperation = "difference";
      ctx.fillStyle = "rgba(255,255,255," + (0.75 + flash * 0.25) + ")";
      ctx.fillRect(px, B.y, 16 + flash * B.w, B.h);
      ctx.restore();
      ctx.globalCompositeOperation = "lighter";
      for (const pt of pairs) {
        pt.x += pt.vx * dt; pt.y += pt.vy * dt; pt.life -= dt * 1.3;
        if (pt.life > 0) {
          ctx.fillStyle = pt.anti ? "rgba(255,150,220," + pt.life + ")" : "rgba(150,230,255," + pt.life + ")";
          ctx.fillRect(pt.x, pt.y, 2.2, 2.2);
        }
      }
      ctx.globalCompositeOperation = "source-over";
      pairs = pairs.filter(pt => pt.life > 0);
      flash = Math.max(0, flash - dt * 2.5);
    }
  };
});

def("Comet loop", "cosmic", "a comet rounds the button like a tiny sun; press to split its tail", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let split = 0, a = 0;
  const tail = [];
  return {
    press() { split = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(16,14,28,0.92)", "rgba(180,210,255,0.45)");
      label("PERIHELION", "rgba(220,235,255,0.85)");
      // Kepler, loosely: the comet hurries when close to the "sun" (the button)
      const e = 0.55 + 0.35 * Math.cos(a);
      a += (1.2 + (1 - e)) * dt * 1.6;
      const x = B.cx + Math.cos(a) * B.w * 0.62;
      const y = B.cy + Math.sin(a) * B.h * 1.1;
      tail.unshift({ x: x, y: y });
      if (tail.length > 26) tail.pop();
      ctx.globalCompositeOperation = "lighter";
      for (let i = 1; i < tail.length; i++) {
        const k = 1 - i / tail.length;
        ctx.strokeStyle = "rgba(170,215,255," + k * 0.5 * (1 + split * 0.6) + ")";
        ctx.lineWidth = 1.4;
        ctx.beginPath(); ctx.moveTo(tail[i - 1].x, tail[i - 1].y); ctx.lineTo(tail[i].x, tail[i].y);
        if (split > 0) {                  // the second, ion tail — pushed outward
          const ox = (tail[i].x - B.cx) * 0.12 * split, oy = (tail[i].y - B.cy) * 0.12 * split;
          ctx.moveTo(tail[i - 1].x + ox, tail[i - 1].y + oy);
          ctx.lineTo(tail[i].x + ox * 1.2, tail[i].y + oy * 1.2);
        }
        ctx.stroke();
      }
      const g = ctx.createRadialGradient(x, y, 0, x, y, 6);
      g.addColorStop(0, "rgba(235,245,255,0.95)");
      g.addColorStop(1, "rgba(160,200,255,0)");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(x, y, 6, 0, TAU); ctx.fill();
      ctx.globalCompositeOperation = "source-over";
      split = Math.max(0, split - dt * 0.45);
    }
  };
});

/* ============================== NATURE & GROWTH ============================== */

def("Vine growth", "nature", "vines wind along the border, leafing as they go; press to bloom", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  const nodes = [];                       // points along the border ellipse
  for (let i = 0; i <= 40; i++) {
    const a = -Math.PI / 2 + i / 40 * TAU;
    nodes.push({ x: B.cx + Math.cos(a) * B.w * 0.54 + Math.sin(i * 2.2) * 2,
                 y: B.cy + Math.sin(a) * B.h * 0.72 + Math.cos(i * 1.7) * 2,
                 leaf: i % 5 === 2, la: rand(0, TAU) });
  }
  let bloom = 0;
  return {
    press() { bloom = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(16,24,16,0.94)", "rgba(140,190,120,0.4)");
      label("GARDEN", "#DFF0D6");
      const grow = Math.min(1, t / 6);    // six patient seconds to circle once
      const n = Math.max(2, Math.floor(grow * nodes.length));
      ctx.strokeStyle = "rgba(120,180,90,0.9)";
      ctx.lineWidth = 1.8;
      ctx.beginPath();
      ctx.moveTo(nodes[0].x, nodes[0].y);
      for (let i = 1; i < n; i++) ctx.lineTo(nodes[i].x, nodes[i].y);
      ctx.stroke();
      for (let i = 0; i < n; i++) {
        const nd = nodes[i];
        if (!nd.leaf) continue;
        const sway = Math.sin(t * 1.5 + nd.la) * 0.2;
        ctx.save();
        ctx.translate(nd.x, nd.y);
        ctx.rotate(nd.la + sway);
        ctx.fillStyle = "rgba(140,200,100,0.85)";
        ctx.beginPath(); ctx.ellipse(4, 0, 4, 2, 0, 0, TAU); ctx.fill();
        if (bloom > 0) {                  // five petals, conjured by the press
          ctx.fillStyle = "rgba(255,190,220," + bloom + ")";
          for (let p = 0; p < 5; p++) {
            ctx.rotate(TAU / 5);
            ctx.beginPath(); ctx.ellipse(0, 3.4 * bloom, 1.6, 2.6, 0, 0, TAU); ctx.fill();
          }
        }
        ctx.restore();
      }
      bloom = Math.max(0, bloom - dt * 0.35);
    }
  };
});

def("Pollen field", "nature", "spores hang in the light; press to puff them everywhere", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  const motes = [];
  for (let i = 0; i < 24; i++)
    motes.push({ x: rand(0, W), y: rand(0, H), vx: 0, vy: 0, ph: rand(0, TAU) });
  return {
    press() {
      for (const m of motes) {            // radial shove from the button's centre
        const dx = m.x - B.cx, dy = m.y - B.cy;
        const d = Math.max(8, Math.hypot(dx, dy));
        m.vx += dx / d * 130; m.vy += dy / d * 130;
      }
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(26,24,14,0.92)", "rgba(220,200,130,0.45)");
      label("ACHOO", "#F2E8C8");
      ctx.globalCompositeOperation = "lighter";
      for (const m of motes) {
        m.x += (m.vx + Math.sin(t * 0.8 + m.ph) * 4) * dt;
        m.y += (m.vy + Math.cos(t * 0.6 + m.ph) * 3 - 2) * dt;
        m.vx *= Math.pow(0.25, dt); m.vy *= Math.pow(0.25, dt);
        if (m.x < -4) m.x = W + 4; if (m.x > W + 4) m.x = -4;
        if (m.y < -4) m.y = H + 4; if (m.y > H + 4) m.y = -4;
        const g = ctx.createRadialGradient(m.x, m.y, 0, m.x, m.y, 3);
        g.addColorStop(0, "rgba(240,225,150,0.6)");
        g.addColorStop(1, "rgba(240,225,150,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(m.x, m.y, 3, 0, TAU); ctx.fill();
      }
      ctx.globalCompositeOperation = "source-over";
    }
  };
});

def("Mycelium", "nature", "threads creep across the dark; press to pulse light down the network", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  const threads = [];                     // a branching tree from the left edge
  function branch(x, y, a, depth) {
    if (depth > 3 || x > B.x + B.w) return;
    const pts = [{ x: x, y: y }];
    let px = x, py = y, pa = a;
    for (let s = 0; s < 5; s++) {
      pa += rand(-0.4, 0.4);
      px += Math.cos(pa) * rand(8, 14); py += Math.sin(pa) * rand(3, 6);
      py = Math.min(B.y + B.h - 3, Math.max(B.y + 3, py));
      pts.push({ x: px, y: py });
    }
    threads.push({ pts: pts, d0: rand(0, 1) });
    if (Math.random() < 0.8) branch(px, py, pa + rand(-0.9, 0.9), depth + 1);
  }
  for (let i = 0; i < 4; i++) branch(B.x, rand(B.y + 6, B.y + B.h - 6), rand(-0.3, 0.3), 0);
  let pulse = -1;
  return {
    press() { pulse = 0; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(14,14,20,0.95)", "rgba(190,180,220,0.35)");
      const grow = Math.min(1, t / 5);
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      if (pulse >= 0) pulse += dt * 1.4;  // the light-front's position, 0 → 1+
      for (const th of threads) {
        const n = Math.max(2, Math.floor(grow * th.pts.length));
        for (let i = 1; i < n; i++) {
          const k = i / th.pts.length;
          let a = 0.22;
          if (pulse >= 0) {               // brighten near the travelling front
            const d = Math.abs(k - pulse);
            a += Math.max(0, 0.75 - d * 4);
          }
          ctx.strokeStyle = "rgba(200,190,235," + a + ")";
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(th.pts[i - 1].x, th.pts[i - 1].y);
          ctx.lineTo(th.pts[i].x, th.pts[i].y);
          ctx.stroke();
        }
      }
      if (pulse > 1.4) pulse = -1;
      ctx.restore();
      label("WOOD WIDE WEB", "rgba(225,220,240,0.8)");
    }
  };
});

def("Swarm", "nature", "a loose swarm orbits the hive; press to scatter it", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  const bees = [];
  for (let i = 0; i < 22; i++)
    bees.push({ a: rand(0, TAU), r: rand(0.6, 1.15), va: rand(0.8, 1.6),
                wob: rand(0, 9), panic: 0 });
  return {
    press() { for (const bee of bees) bee.panic = 1 + rand(0, 0.5); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(30,24,10,0.92)", "rgba(230,190,90,0.5)");
      label("HIVE", "#F4E6BE");
      for (const bee of bees) {
        bee.panic = Math.max(0, bee.panic - dt * 0.6);
        bee.a += bee.va * (1 + bee.panic * 2.5) * dt;
        const wob = Math.sin(t * 7 + bee.wob) * 3;
        const rr2 = (B.w * 0.42 * bee.r) * (1 + bee.panic * 1.1);
        const x = B.cx + Math.cos(bee.a) * (rr2 + wob) * 1.35;
        const y = B.cy + Math.sin(bee.a) * (rr2 + wob) * 0.62;
        ctx.fillStyle = "rgba(240,200,80,0.9)";
        ctx.fillRect(x - 1, y - 1, 2.4, 1.8);
        ctx.strokeStyle = "rgba(240,200,80,0.25)";     // a hint of flight path
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(x - Math.cos(bee.a) * 4, y - Math.sin(bee.a) * 2);
        ctx.lineTo(x, y);
        ctx.stroke();
      }
    }
  };
});

def("Rainforest", "nature", "drips and falling leaves; press for the downpour", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let drips = [], leaves = [], pour = 0;
  return {
    press() { pour = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(14,26,18,0.94)", "rgba(120,190,140,0.5)");
      label("CANOPY", "#D8EEDD");
      if (Math.random() < 0.06 + pour * 0.6)
        drips.push({ x: rand(B.x, B.x + B.w), y: B.y + B.h, vy: rand(30, 60) });
      if (Math.random() < 0.02 + pour * 0.12)
        leaves.push({ x: rand(0, W), y: -4, ph: rand(0, 9), rot: rand(0, 6) });
      for (const d of drips) {            // water off the leaf edge (the button)
        d.y += d.vy * dt; d.vy += 220 * dt;
        ctx.fillStyle = "rgba(150,220,190,0.8)";
        ctx.beginPath(); ctx.ellipse(d.x, d.y, 1.2, 2.6, 0, 0, TAU); ctx.fill();
      }
      drips = drips.filter(d => d.y < H + 6);
      for (const lf of leaves) {
        lf.y += 26 * dt; lf.x += Math.sin(t * 1.6 + lf.ph) * 14 * dt; lf.rot += dt * 2;
        ctx.save();
        ctx.translate(lf.x, lf.y); ctx.rotate(lf.rot);
        ctx.fillStyle = "rgba(110,180,110,0.8)";
        ctx.beginPath(); ctx.ellipse(0, 0, 3.6, 1.7, 0, 0, TAU); ctx.fill();
        ctx.restore();
      }
      leaves = leaves.filter(lf => lf.y < H + 6);
      pour = Math.max(0, pour - dt * 0.5);
    }
  };
});

def("Sea sparkle", "nature", "an unseen current wakes glowing algae; press to stir the water", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let burst = [];
  return {
    press(x, y) {
      for (let i = 0; i < 16; i++) {
        const th = rand(0, TAU);
        burst.push({ x: (x || B.cx) + Math.cos(th) * rand(0, 6), y: (y || B.cy) + Math.sin(th) * rand(0, 5),
                     vx: Math.cos(th) * rand(10, 50), vy: Math.sin(th) * rand(8, 30), life: 1 });
      }
    },
    frame(dt, t) {
      ctx.fillStyle = "rgba(6,12,20,0.22)"; ctx.fillRect(0, 0, W, H);  // slow-fade water
      // the invisible current: a Lissajous point that leaves a bioluminescent wake
      const cx = B.cx + Math.sin(t * 0.7) * B.w * 0.55;
      const cy = B.cy + Math.sin(t * 1.1 + 1.3) * B.h * 1.05;
      ctx.globalCompositeOperation = "lighter";
      const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, 8);
      g.addColorStop(0, "rgba(120,240,255,0.5)");
      g.addColorStop(1, "rgba(40,160,220,0)");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(cx, cy, 8, 0, TAU); ctx.fill();
      if (Math.random() < 0.5) {
        ctx.fillStyle = "rgba(150,245,255,0.8)";
        ctx.fillRect(cx + rand(-5, 5), cy + rand(-4, 4), 1.4, 1.4);
      }
      for (const b of burst) {
        b.x += b.vx * dt; b.y += b.vy * dt; b.life -= dt * 0.9;
        if (b.life > 0) { ctx.fillStyle = "rgba(140,240,255," + b.life * 0.9 + ")"; ctx.fillRect(b.x, b.y, 1.6, 1.6); }
      }
      burst = burst.filter(b => b.life > 0);
      ctx.globalCompositeOperation = "source-over";
      face("rgba(8,16,26,0.6)", "rgba(110,210,235,0.5)");
      label("NOCTILUCA", "rgba(200,245,255,0.85)");
    }
  };
});

/* ============================== ACID & GOO ============================== */

def("Acid bath", "acid", "green liquid simmers in the lower third; press for a violent boil", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  let bubbles = [], boil = 0, drips = [];
  return {
    press() { boil = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(18,24,14,0.94)", "rgba(150,230,90,0.5)");
      const level = B.y + B.h * 0.62;     // the acid line
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      ctx.fillStyle = "rgba(90,190,40,0.55)";
      ctx.beginPath();
      ctx.moveTo(B.x, B.y + B.h);
      ctx.lineTo(B.x, level);
      for (let x = B.x; x <= B.x + B.w; x += 5)
        ctx.lineTo(x, level + Math.sin(x * 0.2 + t * (3 + boil * 6)) * (1 + boil * 3));
      ctx.lineTo(B.x + B.w, B.y + B.h);
      ctx.closePath(); ctx.fill();
      if (Math.random() < 0.2 + boil * 0.7)
        bubbles.push({ x: rand(B.x + 4, B.x + B.w - 4), y: B.y + B.h - 2, r: rand(1.5, 3.5) });
      for (const b of bubbles) {
        b.y -= (14 + boil * 30) * dt;
        if (b.y < level) { b.y = -99; continue; }      // pops at the surface
        ctx.strokeStyle = "rgba(190,255,130,0.7)";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, TAU); ctx.stroke();
      }
      bubbles = bubbles.filter(b => b.y > 0);
      ctx.restore();
      if (Math.random() < 0.02 + boil * 0.1)           // the acid eats its way out
        drips.push({ x: rand(B.x + 6, B.x + B.w - 6), y: B.y + B.h, vy: 10 });
      for (const d of drips) {
        d.y += d.vy * dt; d.vy += 70 * dt;
        ctx.fillStyle = "rgba(140,230,80,0.8)";
        ctx.beginPath(); ctx.ellipse(d.x, d.y, 1.4, 2.8, 0, 0, TAU); ctx.fill();
      }
      drips = drips.filter(d => d.y < H + 6);
      label("CAUSTIC", "#DDF7C2");
      boil = Math.max(0, boil - dt * 0.8);
    }
  };
});

def("Miasma", "acid", "a sickly haze breathes around it; press to blow the cloud away", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let clear = 0;
  const wisps = [];
  for (let i = 0; i < 9; i++) wisps.push({ a: rand(0, TAU), r: rand(0.9, 1.3), v: rand(0.2, 0.5), ph: rand(0, 9) });
  return {
    press() { clear = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,24,16,0.94)", "rgba(170,200,110,0.45)");
      label("QUARANTINE", "rgba(225,240,190,0.85)");
      ctx.globalCompositeOperation = "lighter";
      for (const wsp of wisps) {          // wisps orbit lazily, breathing in size
        wsp.a += wsp.v * dt;
        const push = 1 + clear * 2.2;     // press shoves the orbit outward
        const x = B.cx + Math.cos(wsp.a) * B.w * 0.5 * wsp.r * push;
        const y = B.cy + Math.sin(wsp.a) * B.h * 0.75 * wsp.r * push;
        const r = 12 + Math.sin(t * 0.9 + wsp.ph) * 4;
        const a = 0.09 * (1 - clear * 0.85);
        const g = ctx.createRadialGradient(x, y, 0, x, y, r);
        g.addColorStop(0, "rgba(180,220,90," + a + ")");
        g.addColorStop(1, "rgba(140,190,60,0)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
      }
      ctx.globalCompositeOperation = "source-over";
      clear = Math.max(0, clear - dt * 0.4);           // the haze always returns
    }
  };
});

def("Slime coat", "acid", "goo drips off the face at its own pace; press to jiggle it", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  const sags = [];                        // hanging points along the bottom edge
  for (let i = 0; i <= 10; i++)
    sags.push({ k: i / 10, sag: rand(2, 7), ph: rand(0, 9), v: 0, off: 0 });
  return {
    press() { for (const s of sags) s.v += rand(30, 60); },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(18,26,16,0.94)", "rgba(140,220,110,0.4)");
      label("SQUISH", "rgba(20,40,20,0.9)");
      for (const s of sags) {             // each point is its own little spring
        s.v += -s.off * 40 * dt; s.v *= Math.pow(0.2, dt); s.off += s.v * dt;
      }
      ctx.fillStyle = "rgba(120,210,90,0.55)";
      ctx.beginPath();                    // the coat: a lid plus drooping lobes
      ctx.moveTo(B.x, B.y);
      ctx.lineTo(B.x + B.w, B.y);
      for (let i = sags.length - 1; i >= 0; i--) {
        const s = sags[i];
        const x = B.x + s.k * B.w;
        const y = B.y + B.h + s.sag + Math.sin(t * 1.1 + s.ph) * 1.5 + s.off;
        ctx.quadraticCurveTo(x + 4, B.y + B.h - 2, x, y);
      }
      ctx.closePath(); ctx.fill();
      // highlight: goo is shiny
      ctx.strokeStyle = "rgba(220,255,190,0.35)";
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(B.x + 8, B.y + 4); ctx.lineTo(B.x + B.w * 0.4, B.y + 4); ctx.stroke();
    }
  };
});

def("Venom", "acid", "two fangs drip; press and they spit an arc", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let drops = [], spit = [], hitFlash = 0;
  const fangs = [B.cx - 22, B.cx + 22];
  return {
    press() {
      for (const fx of fangs)
        spit.push({ x: fx, y: B.y + 10, vx: rand(-25, 25), vy: rand(-90, -60), life: 1 });
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(24,18,26,0.94)", "rgba(180,140,220," + (0.45 + hitFlash * 0.5) + ")");
      label("FANG", hitFlash > 0 ? "#B6FF9E" : "#E8DCF4");
      for (const fx of fangs) {           // the fangs, points down, just inside the top edge
        ctx.fillStyle = "#E8E4EE";
        ctx.beginPath();
        ctx.moveTo(fx - 4, B.y + 1); ctx.lineTo(fx + 4, B.y + 1); ctx.lineTo(fx, B.y + 12);
        ctx.closePath(); ctx.fill();
        if (Math.random() < 0.008)
          drops.push({ x: fx, y: B.y + 12, vy: 8 });
      }
      for (const d of drops) {
        d.y += d.vy * dt; d.vy += 90 * dt;
        ctx.fillStyle = "rgba(170,255,110,0.85)";
        ctx.beginPath(); ctx.ellipse(d.x, d.y, 1.3, 2.4, 0, 0, TAU); ctx.fill();
      }
      drops = drops.filter(d => d.y < H + 4);
      for (const s of spit) {             // venom lobbed in an arc — gravity does the art
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 150 * dt; s.life -= dt * 0.8;
        if (s.y > B.cy && s.vy > 0) { hitFlash = 1; s.life = 0; }  // lands on the face
        if (s.life > 0) {
          ctx.fillStyle = "rgba(170,255,110," + s.life + ")";
          ctx.beginPath(); ctx.arc(s.x, s.y, 2, 0, TAU); ctx.fill();
        }
      }
      spit = spit.filter(s => s.life > 0);
      hitFlash = Math.max(0, hitFlash - dt * 2);
    }
  };
});

def("Radiant decay", "acid", "three glow sectors rotate like a warning; press for geiger crackle", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let crackle = 0, ticks = [];
  return {
    press() { crackle = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      ctx.globalCompositeOperation = "lighter";
      const spin = t * (0.6 + crackle * 2) * (crackle > 0 ? -1 : 1);
      for (let s = 0; s < 3; s++) {       // the trefoil, abstracted to light
        const a0 = spin + s * (TAU / 3);
        const g = ctx.createRadialGradient(B.cx, B.cy, 4, B.cx, B.cy, B.w * 0.55);
        g.addColorStop(0, "rgba(200,255,80," + (0.16 + crackle * 0.16) + ")");
        g.addColorStop(1, "rgba(160,230,40,0)");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.moveTo(B.cx, B.cy);
        ctx.arc(B.cx, B.cy, B.w * 0.55, a0, a0 + TAU / 6);
        ctx.closePath(); ctx.fill();
      }
      if (crackle > 0 && Math.random() < crackle * 0.8)
        ticks.push({ x: B.cx + rand(-B.w, B.w) * 0.55, y: B.cy + rand(-B.h, B.h), life: 0.25 });
      for (const tk of ticks) {           // each tick: one hard, brief dot
        tk.life -= dt;
        if (tk.life > 0) { ctx.fillStyle = "rgba(230,255,150,0.95)"; ctx.fillRect(tk.x, tk.y, 2.5, 2.5); }
      }
      ticks = ticks.filter(tk => tk.life > 0);
      ctx.globalCompositeOperation = "source-over";
      face("rgba(20,24,10,0.88)", "rgba(200,240,90,0.55)");
      label("HALF-LIFE", "#EDFAC8");
      crackle = Math.max(0, crackle - dt * 0.7);
    }
  };
});

def("Ectoplasm", "acid", "a ghost drifts through the button; press to startle it away", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let gx = -30, spooked = 0;
  return {
    press() { spooked = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(20,22,26," + (0.94 - spooked * 0.2) + ")", "rgba(190,230,210,0.4)");
      label("BOO", "#E0F2E8");
      gx += (16 + spooked * 220) * dt;    // spooked ghosts leave in a hurry
      if (gx > W + 40) { gx = -40; spooked = Math.max(0, spooked - 0.99); }
      const gy = B.cy + Math.sin(t * 1.3) * 10 - spooked * 12;
      const inFace = gx > B.x && gx < B.x + B.w;
      const a = (inFace ? 0.18 : 0.34) + spooked * 0.2;   // fades while phasing through
      ctx.globalCompositeOperation = "lighter";
      const g = ctx.createRadialGradient(gx, gy, 0, gx, gy, 15);
      g.addColorStop(0, "rgba(190,255,225," + a + ")");
      g.addColorStop(1, "rgba(120,220,180,0)");
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(gx, gy, 15, 0, TAU); ctx.fill();
      ctx.strokeStyle = "rgba(190,255,225," + a * 0.8 + ")";
      ctx.lineWidth = 1.4;
      for (let k = -1; k <= 1; k++) {     // trailing wisps
        ctx.beginPath();
        ctx.moveTo(gx + k * 4, gy + 8);
        ctx.quadraticCurveTo(gx + k * 6 - 6, gy + 14, gx + k * 7 - 12, gy + 12 + Math.sin(t * 5 + k) * 3);
        ctx.stroke();
      }
      ctx.globalCompositeOperation = "source-over";
      spooked = Math.max(0, spooked - dt * 0.25);
    }
  };
});

/* ============================== CRYSTAL ============================== */

def("Facet glint", "crystal", "cut faces catch the light in turn; press for the full cascade", function (u) {
  const { ctx, W, H, B, rand, rr, face, label } = u;
  const facets = [];                      // triangles tiled across the face
  const cols2 = 7, rows2 = 2;
  for (let i = 0; i < cols2; i++)
    for (let j = 0; j < rows2; j++)
      for (let half = 0; half < 2; half++) {
        const x0 = B.x + i * B.w / cols2, y0 = B.y + j * B.h / rows2;
        const x1 = x0 + B.w / cols2, y1 = y0 + B.h / rows2;
        facets.push({
          pts: half === 0 ? [[x0, y0], [x1, y0], [x0, y1]] : [[x1, y0], [x1, y1], [x0, y1]],
          ph: rand(0, 9), base: rand(0.06, 0.16)
        });
      }
  let cascade = -1;
  return {
    press() { cascade = 0; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("#1A1430", "rgba(200,180,255,0.5)");
      if (cascade >= 0) cascade += dt * 2.2;
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      for (const f of facets) {
        let glint = Math.pow(Math.max(0, Math.sin(t * 0.8 + f.ph)), 8) * 0.6;
        if (cascade >= 0) {               // the wave: brightness sweeps left → right
          const k = (f.pts[0][0] - B.x) / B.w;
          glint += Math.max(0, 0.8 - Math.abs(k - cascade) * 5);
        }
        ctx.fillStyle = "rgba(210,190,255," + Math.min(1, f.base + glint) + ")";
        ctx.beginPath();
        ctx.moveTo(f.pts[0][0], f.pts[0][1]);
        ctx.lineTo(f.pts[1][0], f.pts[1][1]);
        ctx.lineTo(f.pts[2][0], f.pts[2][1]);
        ctx.closePath(); ctx.fill();
      }
      if (cascade > 1.4) cascade = -1;
      ctx.restore();
      label("BRILLIANT", "rgba(30,20,50,0.9)");
    }
  };
});

def("Resonance", "crystal", "shards hum in a travelling wave; press to ring them like a bell", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  const shards = [];
  for (let i = 0; i < 12; i++) {
    const a = i / 12 * TAU;
    shards.push({ a: a, len: rand(7, 12), ring: 0 });
  }
  let ringWave = -1;
  return {
    press() { ringWave = 0; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(16,20,32,0.92)", "rgba(150,220,240,0.5)");
      label("CHIME", "#D8F2FA");
      if (ringWave >= 0) ringWave += dt * 8;           // the strike runs round the circle
      for (let i = 0; i < shards.length; i++) {
        const s = shards[i];
        const hum = Math.sin(t * 4 - i * 0.8) * 0.06;  // the idle travelling wave
        let excite = 0;
        if (ringWave >= 0) {
          const d = Math.abs(i - ringWave % shards.length);
          excite = Math.max(0, 1 - Math.min(d, shards.length - d) * 0.6);
        }
        const scale = 1 + hum + excite * 0.45;
        const x0 = B.cx + Math.cos(s.a) * B.w * 0.56;
        const y0 = B.cy + Math.sin(s.a) * B.h * 0.78;
        ctx.save();
        ctx.translate(x0, y0);
        ctx.rotate(s.a + Math.PI / 2);
        ctx.fillStyle = "rgba(170,230,250," + (0.5 + excite * 0.5) + ")";
        ctx.beginPath();                  // an elongated diamond
        ctx.moveTo(0, -s.len * scale);
        ctx.lineTo(2.4, 0); ctx.lineTo(0, s.len * scale * 0.4); ctx.lineTo(-2.4, 0);
        ctx.closePath(); ctx.fill();
        ctx.restore();
      }
      if (ringWave > shards.length * 2) ringWave = -1;
    }
  };
});

def("Stalactites", "crystal", "crystals lengthen from above; press to snap them loose", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  const spikes = [];
  for (let x = B.x + 8; x < B.x + B.w - 4; x += 13)
    spikes.push({ x: x, max: rand(8, 18), len: rand(2, 6), rate: rand(0.5, 1.2) });
  let falling = [], glitter = [];
  return {
    press() {
      for (const s of spikes) {
        if (s.len > 4)
          falling.push({ x: s.x, y: s.len, vy: 0, len: s.len });
        s.len = 2;
      }
    },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      face("rgba(18,18,34,0.92)", "rgba(190,200,255,0.5)");
      label("CAVERN", "#E4E8FF");
      for (const s of spikes) {           // growth measured in patience
        s.len = Math.min(s.max, s.len + s.rate * dt);
        ctx.fillStyle = "rgba(200,210,255,0.75)";
        ctx.beginPath();
        ctx.moveTo(s.x - 2.6, 0); ctx.lineTo(s.x + 2.6, 0); ctx.lineTo(s.x, s.len);
        ctx.closePath(); ctx.fill();
        if (s.len > s.max * 0.95 && Math.random() < 0.01)
          glitter.push({ x: s.x, y: s.len + 2, life: 1 });   // a drip of light
      }
      for (const f of falling) {
        f.vy += 300 * dt; f.y += f.vy * dt;
        ctx.fillStyle = "rgba(200,210,255,0.85)";
        ctx.beginPath();
        ctx.moveTo(f.x - 2, f.y - f.len * 0.5); ctx.lineTo(f.x + 2, f.y - f.len * 0.5); ctx.lineTo(f.x, f.y);
        ctx.closePath(); ctx.fill();
        if (f.y > H - 2) {                // shatter sparkle at the floor
          for (let i = 0; i < 5; i++)
            glitter.push({ x: f.x + rand(-6, 6), y: H - 3, life: 1 });
          f.vy = -9999;                   // mark for removal
        }
      }
      falling = falling.filter(f => f.vy > -9000);
      ctx.globalCompositeOperation = "lighter";
      for (const gl of glitter) {
        gl.life -= dt * 2;
        if (gl.life > 0) { ctx.fillStyle = "rgba(230,238,255," + gl.life + ")"; ctx.fillRect(gl.x, gl.y, 2, 2); }
      }
      ctx.globalCompositeOperation = "source-over";
      glitter = glitter.filter(gl => gl.life > 0);
    }
  };
});

def("Opal", "crystal", "iridescent bands roll across the face; press for a colour shockwave", function (u) {
  const { ctx, W, H, B, rand, rr, face, label, TAU } = u;
  let shock = -1, sx = 0, sy = 0;
  return {
    press(x, y) { shock = 0; sx = x || B.cx; sy = y || B.cy; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      ctx.save();
      rr(B.x, B.y, B.w, B.h, B.r); ctx.clip();
      if (shock >= 0) shock += dt * 130;  // the ripple's radius, in pixels
      for (let x = 0; x < B.w; x += 4) {  // interference: two hue waves beating
        let hue = 180 + Math.sin(x * 0.05 + t * 0.8) * 60 + Math.sin(x * 0.11 - t * 0.5) * 40;
        let light = 55;
        if (shock >= 0) {                 // the shockwave bends hue near its ring
          const d = Math.abs(Math.hypot(B.x + x - sx, B.cy - sy) - shock);
          if (d < 16) { hue += (16 - d) * 8; light += (16 - d) * 1.5; }
        }
        ctx.fillStyle = "hsl(" + hue + ",65%," + light + "%)";
        ctx.fillRect(B.x + x, B.y, 4.5, B.h);
      }
      if (shock > B.w * 1.2) shock = -1;
      ctx.restore();
      rr(B.x, B.y, B.w, B.h, B.r);
      ctx.strokeStyle = "rgba(255,255,255,0.6)"; ctx.lineWidth = 1.5; ctx.stroke();
      label("OPALESCE", "rgba(30,20,40,0.85)");
    }
  };
});

/* ============================== WEATHER ============================== */

def("Monsoon", "weather", "slanted rain and mutter-lightning; press for the thunderclap", function (u) {
  const { ctx, W, H, B, rand, face, label } = u;
  let clap = 0;
  const rain = [];
  for (let i = 0; i < 34; i++) rain.push({ x: rand(0, W), y: rand(0, H), v: rand(140, 220) });
  return {
    press() { clap = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      if (clap > 0.7 || (clap <= 0 && Math.random() < 0.006)) {     // sheet lightning
        ctx.fillStyle = "rgba(200,210,240," + (clap > 0 ? clap * 0.35 : 0.18) + ")";
        ctx.fillRect(0, 0, W, H);
      }
      const sh = clap * clap * 4;
      ctx.save();
      ctx.translate(rand(-sh, sh), rand(-sh, sh));
      face("rgba(18,20,32,0.94)", "rgba(160,180,220," + (0.45 + clap * 0.5) + ")");
      label("MONSOON", "#DDE6F5");
      ctx.restore();
      for (const r of rain) {
        r.x -= r.v * 0.35 * dt; r.y += r.v * dt;
        if (r.y > H) { r.y = -4; r.x = rand(0, W + 30); }
        ctx.strokeStyle = "rgba(160,190,230,0.5)";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(r.x, r.y); ctx.lineTo(r.x + 2.5, r.y - 8); ctx.stroke();
      }
      clap = Math.max(0, clap - dt * 1.8);
    }
  };
});

def("Dust devil", "weather", "a whirl crosses the scene; press and it engulfs the button", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let grow = 0;
  return {
    press() { grow = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const dx = grow > 0.2 ? B.cx : ((t * 30) % (W + 60)) - 30;    // press pins it on the button
      const size = 1 + grow * 2.4;
      const wobble = grow * Math.sin(t * 25) * 1.5;    // the label trembles inside it
      ctx.save();
      ctx.translate(wobble, 0);
      face("rgba(26,22,16,0.92)", "rgba(200,175,130,0.5)");
      label("DUST UP", "#EDE0C8");
      ctx.restore();
      for (let i = 0; i < 10; i++) {      // the devil: rotating dust dashes in a column
        const k = i / 9;
        const y = H - 8 - k * (H - 20);
        const r = (3 + k * 9) * size;
        const a = t * 9 - k * 2;
        ctx.strokeStyle = "rgba(210,185,140," + (0.4 - k * 0.2 + grow * 0.2) + ")";
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.ellipse(dx + Math.sin(t * 4 + k * 5) * 2, y, r, r * 0.28, 0, a, a + 3.6);
        ctx.stroke();
      }
      grow = Math.max(0, grow - dt * 0.5);
    }
  };
});

def("Double rainbow", "weather", "light rain, and sometimes an arc; press for both at once", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let show = 0, dbl = 0;
  const rain = [];
  for (let i = 0; i < 14; i++) rain.push({ x: rand(0, W), y: rand(0, H), v: rand(50, 90) });
  return {
    press() { show = 1; dbl = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      // the scheduled appearance: fade in around every eighth second decade
      const cyc = (t % 8) / 8;
      const sched = Math.max(0, Math.sin(cyc * Math.PI) - 0.6) * 2.5;
      const vis = Math.max(sched, show);
      for (const r of rain) {
        r.y += r.v * dt * (1 - dbl * 0.8);             // press hushes the rain
        if (r.y > H) { r.y = -3; r.x = rand(0, W); }
        ctx.strokeStyle = "rgba(150,180,210,0.35)";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(r.x, r.y); ctx.lineTo(r.x + 0.5, r.y - 5); ctx.stroke();
      }
      if (vis > 0.02) {
        const hues = [0, 30, 55, 120, 210, 260, 285];
        for (let arc = 0; arc < (dbl > 0 ? 2 : 1); arc++) {
          for (let i = 0; i < 7; i++) {   // seven stripes, honestly ordered
            const rr2 = B.w * (0.42 + arc * 0.16) + i * 2.6;
            const a = arc === 1 ? vis * dbl * 0.35 : vis * 0.5;     // the echo is fainter
            ctx.strokeStyle = "hsla(" + hues[arc === 1 ? 6 - i : i] + ",85%,60%," + a + ")";
            ctx.lineWidth = 2.4;
            ctx.beginPath();
            ctx.arc(B.cx, B.y + B.h + 10, rr2, Math.PI + 0.35, TAU - 0.35);
            ctx.stroke();
          }
        }
      }
      face("rgba(20,20,30,0.92)", "rgba(200,210,235,0.5)");
      label("LUCKY", "#E8ECF6");
      show = Math.max(0, show - dt * 0.3);
      dbl = Math.max(0, dbl - dt * 0.3);
    }
  };
});

def("Tempest", "weather", "wind, rain, and flicker all at once; press for the eye of the storm", function (u) {
  const { ctx, W, H, B, rand, face, label, TAU } = u;
  let eye = 0;
  const rain = [], streaks = [];
  for (let i = 0; i < 24; i++) rain.push({ x: rand(0, W), y: rand(0, H), v: rand(150, 230) });
  for (let i = 0; i < 7; i++) streaks.push({ x: rand(0, W), y: rand(0, H), v: rand(110, 190) });
  return {
    press() { eye = 1; },
    frame(dt, t) {
      ctx.fillStyle = "#14111F"; ctx.fillRect(0, 0, W, H);
      const storm = 1 - eye;              // everything scales down inside the eye
      if (Math.random() < 0.008 * storm) {
        ctx.fillStyle = "rgba(190,200,235,0.2)"; ctx.fillRect(0, 0, W, H);
      }
      for (const s of streaks) {          // horizontal wind
        s.x -= s.v * storm * dt;
        if (s.x < -14) { s.x = W + 14; s.y = rand(0, H); }
        ctx.strokeStyle = "rgba(170,190,215," + 0.3 * storm + ")";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(s.x, s.y); ctx.lineTo(s.x + 12, s.y - 1); ctx.stroke();
      }
      for (const r of rain) {             // slanted rain
        r.x -= r.v * 0.4 * storm * dt; r.y += r.v * storm * dt + 4 * dt;
        if (r.y > H) { r.y = -4; r.x = rand(0, W + 40); }
        ctx.strokeStyle = "rgba(150,180,215," + 0.45 * storm + ")";
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(r.x, r.y); ctx.lineTo(r.x + 3, r.y - 8); ctx.stroke();
      }
      const lean = Math.sin(t * 11) * 1.2 * storm;     // straining in the gusts
      ctx.save();
      ctx.translate(lean, 0);
      face("rgba(18,20,30,0.94)", "rgba(180,200,230," + (0.45 + eye * 0.4) + ")");
      label(eye > 0.4 ? "THE EYE" : "TEMPEST", "#E2EAF4");
      ctx.restore();
      if (eye > 0) {                      // the eerie calm ring
        ctx.strokeStyle = "rgba(220,235,255," + eye * 0.35 + ")";
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.ellipse(B.cx, B.cy, B.w * 0.62 + (1 - eye) * 30, B.h * 0.95 + (1 - eye) * 20, 0, 0, TAU);
        ctx.stroke();
        eye = Math.max(0, eye - dt * 0.45);
      }
    }
  };
});

/* @@EFFECTS-END@@ */

/* ============================== the page runner ============================== */

var FAMILY_ORDER = [
  ["fire", "Fire", "heat, flame, and things that remember being flame"],
  ["lightning", "Lightning", "charge, arc, and the crack of discharge"],
  ["water", "Water", "bubbles, ripples, rain, and everything that sloshes"],
  ["metal", "Mercury & metal", "beads, chrome, forge-heat, and molten drips"],
  ["ice", "Ice & frost", "crystals, snow, auroras, and the patience of glaciers"],
  ["earth", "Earth & stone", "cracks, crumbles, sand, and tectonic grudges"],
  ["air", "Air & wind", "gusts, vortices, smoke, and fog with opinions"],
  ["light", "Light & glow", "breath, heartbeat, halo, and the lighthouse sweep"],
  ["sparks", "Sparks", "the grindstone, the sparkler, the flint, the weld"],
  ["cosmic", "Cosmic & void", "black holes, nebulae, eclipses, and antimatter"],
  ["nature", "Nature & growth", "vines, spores, swarms, and glowing tides"],
  ["acid", "Acid & goo", "things that bubble, drip, and should not be touched"],
  ["crystal", "Crystal", "facets, resonance, and iridescence"],
  ["weather", "Weather", "whole skies compressed into one button"]
];

var grid = document.getElementById("bestiary");
var statusEl = document.getElementById("status");
var runAllBtn = document.getElementById("runall");
var stopAllBtn = document.getElementById("stopall");
var cards = [];

function buildCard(effect) {
  var card = document.createElement("div");
  card.className = "bcard";
  var canvas = document.createElement("canvas");
  canvas.title = effect.name + " — click to wake it, click again to press it";
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
  u.ctx.fillStyle = "#14111F";
  u.ctx.fillRect(0, 0, u.W, u.H);
  u.face("rgba(255,255,255,0.04)", "rgba(255,255,255,0.14)");
  u.label("▶", "rgba(230,227,242,0.55)");
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
  u.ctx.fillStyle = "#14111F";
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
  c.fillStyle = "rgba(20,17,31,0.6)";
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
    if (!st.visible) continue;            // offscreen buttons wait politely
    st.elapsed += dt;
    try { st.inst.frame(dt, st.elapsed); } catch (err) { failCard(st, err); continue; }
    if (st.elapsed > 60) restCard(st);    // the 60-second courtesy nap
  }
  if (any) rafId = requestAnimationFrame(tick);
  else { rafId = null; updateStatus(); }
}

function updateStatus() {
  var n = 0;
  for (var i = 0; i < cards.length; i++) if (cards[i].running) n++;
  if (n !== lastCount) {
    lastCount = n;
    statusEl.textContent = n === 0 ? "" : n + " of " + cards.length + " buttons awake";
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
  small.textContent = list.length + " buttons — " + fam[2];
  h.appendChild(small);
  grid.appendChild(h);
  var wrap = document.createElement("div");
  wrap.className = "bcards";
  grid.appendChild(wrap);
  list.forEach(function (effect) {
    var card = buildCard(effect);
    wrap.appendChild(card);
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
  u.ctx.fillStyle = "#14111F";
  u.ctx.fillRect(0, 0, u.W, u.H);
  u.ctx.fillStyle = "rgba(230,227,242,0.6)";
  u.ctx.font = "15px system-ui, sans-serif";
  u.ctx.textAlign = "center";
  u.ctx.fillText("Press ▶ Run — nothing moves until you do.", u.W / 2, u.H / 2);
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
window.__bestiary = { EFFECTS: EFFECTS, apiFor: apiFor, cards: cards };
})();
