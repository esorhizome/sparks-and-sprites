/* Sparks & Sprites — the depth atlas.
   104 illusions of depth on a flat plane, A to Z four times — and every card
   hides a RHYME (the same picture with two or three dials turned), so the
   page holds 208 pictures. The sixth gallery, after the elemental button
   bestiary, the cube codex, the glyph grimoire, the locomotion lexicon,
   and the flipbook folio.

   Every gallery before this one asked "how does it MOVE?" This one asks
   "how does it look ROUND, FAR, LIT, or SOLID — on a surface that has no
   third axis?" The answer is always a gradient of something: of colour
   (a sky), of contrast (a mountain range fading into the air), of
   brightness across a form (a ball), of three flat shades meeting at an
   edge (a cube), of size-brightness-speed together (smoke near and far),
   of blur (focus), of darkness on the ground (a shadow). None of it needs
   a camera, a mesh, or a light — which is the point: a 2D game or a web
   page gets the depth without paying for the dimension.

   Every demo is one function make(u) that returns { frame(dt, t), press(x, y) }.
   The kit u:
     ctx, W, H     — the 2D context and canvas size (CSS pixels)
     TAU           — 2π
     rand(a, b), clamp(v, lo, hi), lerp(a, b, k), ease(k), rng(seed)
                   — the usual pocket tools (rng = seeded mulberry32: the
                     same seed gives the same "random" numbers everywhere)
     ---- colour ----
     col(c)        — parse "#rgb", "#rrggbb", "rgb()", "rgba()" → [r,g,b,a]
     rgba(c, a)    — the colour c with alpha a, as an "rgba(...)" string
     mix(a, b, k)  — the colour k of the way from a to b (k 0..1)
     shade(c, k)   — k > 0 lightens toward white, k < 0 darkens toward black
     hsl(h, s, l, a) — an "hsla(...)" string (h in degrees, s/l in 0..1)
     ---- gradients (the whole gallery in three calls) ----
     lin(x0, y0, x1, y1, stops) — a linear gradient. stops is either
                     [c0, c1, c2…] (evenly spaced) or [[k, c], [k, c]…]
     rad(x, y, r, stops, ox, oy) — a radial gradient centred at x,y with
                     radius r; ox,oy (optional) move the INNER point — that
                     offset is what turns a disc into a lit ball
     sky(stops)    — fill the whole canvas top → bottom with a gradient
     fog(c, depth, air) — atmospheric perspective: c mixed toward the air
                     colour by depth (0 = here, 1 = the horizon)
     ---- forms ----
     sphere(x, y, r, c, lx, ly, o) — a shaded ball. lx,ly (−1..1) say where
                     the light is; o.rim adds a back-light rim, o.spec a hot
                     highlight, o.dark sets the shadow-side colour
     cyl(x, y, w, h, c, lx) — a vertical cylinder: a horizontal gradient
                     dark → light → dark is the entire trick
     cube(x, y, s, c, o) — an isometric cube standing on its base point
                     x,y. Three flat shades: top (lit), left (mid), right
                     (dark). o.h stretches it into a block; o.top/left/right
                     override the shades
     iso(ix, iy, iz) — project isometric grid coordinates to the canvas
                     (ix runs right-and-down, iy left-and-down, iz up)
     shadow(x, y, rx, ry, a) — a soft ground ellipse (radial falloff)
     soft(x, y, r, c, a) — a glow: radial falloff from c at alpha a to nothing
     poly(pts, c), dot(x, y, r, c), line(x1, y1, x2, y2, c, w)
     ground(y, c) — a flat floor from y down
     label(txt, x, y, c, align) — small caption text
     ---- palette ----
     INK, DIM, NIGHT, SUN, FIRE, SPARK, MAGIC, GOOD, HOT

   Nothing animates until the visitor presses Run (or clicks a card awake),
   and every card rests after 60 seconds as a courtesy. */
(function () {
"use strict";
var TAU = Math.PI * 2;

var EFFECTS = [];
function def(letter, name, tag, hint, make) {
  EFFECTS.push({ letter: letter, name: name, tag: tag, hint: hint, make: make });
}

/* A RHYME is the same picture with two or three dials turned — a palette,
   a speed, a count, a direction — and nothing else. Each card's ⇄ button
   swaps original and rhyme in place; the rhyme's opening comment names
   exactly which dials moved. Understanding one recipe buys the whole
   neighbourhood. */
function rhymeOf(orig, name, hint, make) {
  for (var i = 0; i < EFFECTS.length; i++)
    if (EFFECTS[i].name === orig) {
      EFFECTS[i].rhyme = { name: name, hint: hint, make: make };
      return;
    }
}

/* A WARNING marks a card that must be opted into: it never starts with
   "Run all" — it shows a plain notice instead, and runs only when clicked.
   Used for the one strobe in the atlas (Xenon), for photosensitive readers. */
function warnOf(name, text) {
  for (var i = 0; i < EFFECTS.length; i++)
    if (EFFECTS[i].name === name) { EFFECTS[i].warn = text; return; }
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
  var INK = "#E8E5F4";
  var DIM = "rgba(232,229,244,0.25)";
  var NIGHT = "#131020";
  var SUN = "#F5C169";
  var FIRE = "#F5A15A";
  var SPARK = "#8AD9F5";
  var MAGIC = "#C9A0F5";
  var GOOD = "#9BE28A";
  var HOT = "#F58A8A";
  function rand(a, b) { return a + Math.random() * (b - a); }
  function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
  function lerp(a, b, k) { return a + (b - a) * k; }
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

  /* ---- colour: everything is [r, g, b, a] underneath ---- */
  var colCache = {};
  function col(c) {
    if (Array.isArray(c)) return c;
    var hit = colCache[c];
    if (hit) return hit;
    var out = [0, 0, 0, 1];
    if (c[0] === "#") {
      var h = c.slice(1);
      if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
      out = [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16), 1];
    } else if (c.slice(0, 3) === "hsl") {             // hsl(a): convert, so mix/shade work on it too
      var p = c.match(/[\d.]+/g) || [0, 0, 0, 1];
      var hh = (+p[0] % 360 + 360) % 360 / 360, ss = +p[1] / 100, ll = +p[2] / 100;
      var q = ll < 0.5 ? ll * (1 + ss) : ll + ss - ll * ss, pp = 2 * ll - q;
      var hue2 = function (t) {
        t = (t + 1) % 1;
        if (t < 1 / 6) return pp + (q - pp) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return pp + (q - pp) * (2 / 3 - t) * 6;
        return pp;
      };
      out = [hue2(hh + 1 / 3) * 255, hue2(hh) * 255, hue2(hh - 1 / 3) * 255, p.length > 3 ? +p[3] : 1];
    } else {
      var m = c.match(/[\d.]+/g) || [0, 0, 0, 1];
      out = [+m[0], +m[1], +m[2], m.length > 3 ? +m[3] : 1];
    }
    colCache[c] = out;
    return out;
  }
  function str(v) {
    return "rgba(" + Math.round(v[0]) + "," + Math.round(v[1]) + "," + Math.round(v[2]) + "," + (+v[3].toFixed(3)) + ")";
  }
  function rgba(c, a) { var v = col(c); return str([v[0], v[1], v[2], a === undefined ? v[3] : a]); }
  function mix(a, b, k) {
    var p = col(a), q = col(b); k = clamp(k, 0, 1);
    return str([p[0] + (q[0] - p[0]) * k, p[1] + (q[1] - p[1]) * k, p[2] + (q[2] - p[2]) * k, p[3] + (q[3] - p[3]) * k]);
  }
  function shade(c, k) {
    var v = col(c);
    if (k >= 0) return str([v[0] + (255 - v[0]) * k, v[1] + (255 - v[1]) * k, v[2] + (255 - v[2]) * k, v[3]]);
    return str([v[0] * (1 + k), v[1] * (1 + k), v[2] * (1 + k), v[3]]);
  }
  function hsl(h, s, l, a) {
    return "hsla(" + (h % 360) + "," + Math.round(s * 100) + "%," + Math.round(l * 100) + "%," + (a === undefined ? 1 : a) + ")";
  }

  /* ---- gradients: the three calls the whole gallery is made of ---- */
  function stopsOn(g, stops) {
    for (var i = 0; i < stops.length; i++) {
      var s = stops[i];
      if (Array.isArray(s)) g.addColorStop(clamp(s[0], 0, 1), s[1]);
      else g.addColorStop(stops.length === 1 ? 0 : i / (stops.length - 1), s);
    }
    return g;
  }
  function lin(x0, y0, x1, y1, stops) {
    return stopsOn(ctx.createLinearGradient(x0, y0, x1, y1), stops);
  }
  function rad(x, y, r, stops, ox, oy) {
    r = Math.max(0.5, r);
    return stopsOn(ctx.createRadialGradient(x + (ox || 0), y + (oy || 0), 0, x, y, r), stops);
  }
  function sky(stops) {
    ctx.fillStyle = lin(0, 0, 0, H, stops);
    ctx.fillRect(0, 0, W, H);
  }
  function fog(c, depth, air) {                        // the air is a colour you
    return mix(c, air || "#9FB3D9", clamp(depth, 0, 1)); // look THROUGH — more of it,
  }                                                    // farther away

  /* ---- forms: gradients folded into shapes ---- */
  function sphere(x, y, r, c, lx, ly, o) {
    o = o || {};
    lx = lx === undefined ? -0.5 : lx; ly = ly === undefined ? -0.5 : ly;
    var dark = o.dark || shade(c, -0.75);
    var g = rad(x, y, r * 1.05, [[0, shade(c, o.spec === undefined ? 0.35 : o.spec)], [0.35, c], [0.8, shade(c, -0.35)], [1, dark]], lx * r * 0.55, ly * r * 0.55);
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
    if (o.rim) {                                       // light leaking round the back edge
      var rg = rad(x, y, r, [[0.72, rgba(o.rim, 0)], [1, rgba(o.rim, 0.85)]], -lx * r * 0.35, -ly * r * 0.35);
      ctx.fillStyle = rg;
      ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
    }
  }
  function cyl(x, y, w, h, c, lx) {
    lx = lx === undefined ? -0.3 : lx;
    var hi = clamp(0.5 + lx * 0.4, 0.05, 0.95);
    ctx.fillStyle = lin(x - w / 2, 0, x + w / 2, 0, [[0, shade(c, -0.55)], [hi, shade(c, 0.3)], [1, shade(c, -0.7)]]);
    ctx.fillRect(x - w / 2, y - h, w, h);
  }
  function iso(ix, iy, iz, s) {                        // 2:1 isometric projection
    s = s || 1;
    return [(ix - iy) * 0.866 * s, (ix + iy) * 0.5 * s - iz * s];
  }
  function cube(x, y, s, c, o) {
    o = o || {};
    var h = o.h === undefined ? s : o.h;
    var top = o.top || shade(c, 0.32), left = o.left || c, right = o.right || shade(c, -0.42);
    var dx = 0.866 * s, dy = 0.5 * s;
    poly([[x, y], [x - dx, y - dy], [x - dx, y - dy - h], [x, y - h]], left);
    poly([[x, y], [x + dx, y - dy], [x + dx, y - dy - h], [x, y - h]], right);
    poly([[x, y - h], [x - dx, y - dy - h], [x, y - 2 * dy - h], [x + dx, y - dy - h]], top);
  }
  function shadow(x, y, rx, ry, a) {
    a = a === undefined ? 0.45 : a;
    ctx.save();
    ctx.translate(x, y); ctx.scale(1, Math.max(0.01, ry / rx));
    ctx.fillStyle = rad(0, 0, rx, [[0, "rgba(0,0,0," + a + ")"], [0.6, "rgba(0,0,0," + a * 0.6 + ")"], [1, "rgba(0,0,0,0)"]]);
    ctx.beginPath(); ctx.arc(0, 0, rx, 0, TAU); ctx.fill();
    ctx.restore();
  }
  function soft(x, y, r, c, a) {
    r = Math.max(0.5, r);
    ctx.fillStyle = rad(x, y, r, [[0, rgba(c, a === undefined ? 0.9 : a)], [1, rgba(c, 0)]]);
    ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
  }
  function poly(pts, c) {
    ctx.fillStyle = c;
    ctx.beginPath();
    for (var j = 0; j < pts.length; j++) {
      if (j === 0) ctx.moveTo(pts[j][0], pts[j][1]); else ctx.lineTo(pts[j][0], pts[j][1]);
    }
    ctx.closePath(); ctx.fill();
  }
  function dot(x, y, r, c) {
    ctx.fillStyle = c || INK;
    ctx.beginPath(); ctx.arc(x, y, Math.max(0.1, r), 0, TAU); ctx.fill();
  }
  function line(x1, y1, x2, y2, c, w) {
    ctx.strokeStyle = c || DIM;
    ctx.lineWidth = w || 1;
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  }
  function ground(y, c) {
    ctx.fillStyle = c || "#0E0B1A";
    ctx.fillRect(0, y, W, H - y);
  }
  function label(txt, x, y, c, align) {                // wraps onto two lines when the
    ctx.font = "10px system-ui, sans-serif";           // card is narrower than the sentence
    ctx.textAlign = align || "left";
    var lines = [txt], maxW = W - 14;
    if (ctx.measureText(txt).width > maxW) {
      var mid = Math.floor(txt.length / 2), i = txt.lastIndexOf(" ", mid), j = txt.indexOf(" ", mid);
      var cut = (i < 0 || (j >= 0 && j - mid < mid - i)) ? j : i;
      if (cut > 0) lines = [txt.slice(0, cut), txt.slice(cut + 1)];
      if (ctx.measureText(lines[0]).width > maxW || ctx.measureText(lines[lines.length - 1]).width > maxW)
        ctx.font = "9px system-ui, sans-serif";
    }
    for (var k = 0; k < lines.length; k++) {
      var ly = y - (lines.length - 1 - k) * 11;
      ctx.fillStyle = "rgba(10,8,20,0.55)";            // a shadow so bright skies stay legible
      ctx.fillText(lines[k], x + 0.7, ly + 0.7);
      ctx.fillStyle = c || "rgba(232,229,244,0.75)";
      ctx.fillText(lines[k], x, ly);
    }
    ctx.textAlign = "left";
  }
  return { ctx: ctx, W: W, H: H, TAU: TAU,
           INK: INK, DIM: DIM, NIGHT: NIGHT, SUN: SUN, FIRE: FIRE, SPARK: SPARK, MAGIC: MAGIC, GOOD: GOOD, HOT: HOT,
           rand: rand, clamp: clamp, lerp: lerp, ease: ease, rng: rng,
           col: col, rgba: rgba, mix: mix, shade: shade, hsl: hsl,
           lin: lin, rad: rad, sky: sky, fog: fog,
           sphere: sphere, cyl: cyl, iso: iso, cube: cube, shadow: shadow, soft: soft,
           poly: poly, dot: dot, line: line, ground: ground, label: label };
}

var FAMILY_ORDER = [
  ["sky", "Skies & horizons", "a vertical gradient is a clock and a compass — sunrise, dusk, weather, and the colour of air"],
  ["far", "Distance & atmosphere", "far things are paler, bluer, softer, slower — the mountain range is a gradient of contrast"],
  ["round", "Rounded forms", "one radial gradient with its centre pushed toward the light — that offset IS the roundness"],
  ["facet", "Facets & blocks", "three flat shades meeting at an edge — a cube from squares, and the whole isometric world"],
  ["light", "Light sources", "suns, stars, flames, tubes — a bright core, a falloff, and the light it throws on things"],
  ["volume", "Volumes near & far", "smoke, flame, sparkle sorted by depth — the near ones bigger, brighter, faster; the far ones fading into the air"],
  ["wave", "Waves & ribbons", "a surface shaded by which way it faces — travelling sines, twisting strips, rows of sea receding"],
  ["shadow", "Shadows & focus", "where the light can't reach, and where the eye can't focus — the two cheapest depth cues there are"]
];

/* ============================== SKIES & HORIZONS ==============================
   A vertical gradient is the oldest depth trick there is: the sky is
   darker straight up (less air) and paler at the horizon (you are looking
   through more of it). Move the colours and the same gradient becomes a
   clock — night, dawn, noon, dusk — or a weather report. Twelve pictures,
   each one a list of colour stops and a rule for moving them. */

def("A", "Aurora", "sky", "curtains of light: one thin vertical gradient per strip, its top and bottom riding slow sines — colour is position, motion is phase", function make(u) {
  var D = { sky: ["#07071A", "#0E1230"], hi: "#5AF0AA", lo: "#9A5AF0",   // the two aurora colours
            strips: 48, speed: 0.6, glow: 0.7 };
  var R = u.rng(3), stars = [];
  for (var j = 0; j < 40; j++) stars.push([R() * u.W, R() * u.H * 0.7, 0.4 + R() * 1.1]);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      for (var j = 0; j < stars.length; j++)
        u.dot(stars[j][0], stars[j][1], stars[j][2], u.rgba(u.INK, 0.35 + 0.35 * Math.sin(t * 2 + j)));
      var sw = u.W / D.strips;
      for (var i = 0; i < D.strips; i++) {
        var k = i / D.strips, x = i * sw;
        var top = u.H * (0.16 + 0.08 * Math.sin(k * 5 + t * D.speed * 2) + 0.04 * Math.sin(k * 11 - t * D.speed * 3));
        var bot = u.H * (0.62 + 0.05 * Math.sin(k * 3 + t * D.speed));
        var a = D.glow * (0.5 + 0.45 * Math.sin(k * 9 + t * D.speed * 4));   // each strip breathes on its own phase
        u.ctx.fillStyle = u.lin(0, top, 0, bot, [[0, u.rgba(D.lo, 0)], [0.35, u.rgba(D.lo, a * 0.8)], [0.7, u.rgba(D.hi, a)], [1, u.rgba(D.hi, 0)]]);
        u.ctx.fillRect(x, top, sw + 1, bot - top);
      }
      u.ground(u.H * 0.86, "#04040C");
      u.label("one gradient per strip — the curtain is 48 gradients standing side by side", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.speed = 0.15 + (x / u.W) * 1.2; }        // click right = a windier night
  };
});

def("B", "Bluehour", "sky", "the twenty minutes after sunset: indigo above, a warm sliver at the horizon, and stars arriving one by one as the gradient darkens", function make(u) {
  var D = { top: "#0B0F3A", mid: "#2A3F8F", horizon: "#E8A07A", ground: "#06060F",
            minutes: 8, stars: 70 };                                     // how long the hour lasts, in seconds
  var R = u.rng(11), stars = [];
  for (var j = 0; j < D.stars; j++) stars.push([R() * u.W, R() * u.H * 0.75, 0.4 + R() * 1.0, R()]);
  var k = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      k = u.clamp((t % (D.minutes * 1.4)) / D.minutes, 0, 1);            // 0 = just after sunset, 1 = night
      var top = u.mix(D.top, "#030312", k), mid = u.mix(D.mid, "#0B1040", k), hor = u.mix(D.horizon, "#3A2A4F", k);
      u.sky([[0, top], [0.55, mid], [0.86, hor], [1, u.mix(hor, D.ground, 0.5)]]);
      for (var j = 0; j < stars.length; j++) {
        var s = stars[j], born = s[3] * 0.9;                             // each star has its own arrival time
        if (k > born) u.dot(s[0], s[1], s[2], u.rgba(u.INK, u.clamp((k - born) * 6, 0, 0.9) * (0.6 + 0.4 * Math.sin(t * 3 + j))));
      }
      u.poly([[0, u.H * 0.86], [u.W * 0.2, u.H * 0.78], [u.W * 0.45, u.H * 0.83], [u.W * 0.7, u.H * 0.76], [u.W, u.H * 0.82], [u.W, u.H], [0, u.H]], D.ground);
      u.label("the warm sliver is the sun, below the horizon, still lighting the air above it", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.minutes = 4 + (x / u.W) * 24; }         // click left = a fast dusk
  };
});

def("D", "Dawn", "sky", "sunrise as a clock: four palette keyframes for the top and four for the horizon, mixed by time — the sun is just a disc that climbs while the colours change", function make(u) {
  var D = { tops: ["#05051A", "#2A1E5A", "#5A7FD0", "#6FA8E8"],          // night → violet → morning → day
            hors: ["#1A1030", "#C2507A", "#F5A15A", "#CFE6F5"],
            length: 9, sunSize: 0.09, sea: true };
  var scrub = null;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var k = scrub !== null ? scrub : (0.5 - 0.5 * Math.cos((t / D.length) * u.TAU * 0.5)) ;   // eases 0→1, then rests at day
      var seg = u.clamp(k * 3, 0, 2.999), i = Math.floor(seg), f = seg - i;
      var top = u.mix(D.tops[i], D.tops[i + 1], f), hor = u.mix(D.hors[i], D.hors[i + 1], f);
      var GY = u.H * 0.72;
      u.sky([[0, top], [0.7, hor], [1, hor]]);
      var sy = GY + u.H * 0.12 - k * u.H * 0.45, sx = u.W * 0.62, r = u.W * D.sunSize;
      u.soft(sx, sy, r * 5, "#FFD9A0", 0.25 + k * 0.25);                 // the glow arrives before the disc
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, 0, u.W, GY); u.ctx.clip();
      u.ctx.fillStyle = u.rad(sx, sy, r, ["#FFF3D0", "#FFC879"]);
      u.ctx.beginPath(); u.ctx.arc(sx, sy, r, 0, u.TAU); u.ctx.fill();
      u.ctx.restore();
      if (D.sea) {
        u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.shade(hor, -0.35), u.shade(top, -0.5)]);
        u.ctx.fillRect(0, GY, u.W, u.H - GY);
        u.ctx.save(); u.ctx.translate(sx, GY); u.ctx.scale(1, (u.H - GY) / (r * 1.6));   // the sun's reflection: one soft
        u.soft(0, 0, r * 1.6, "#FFD9A0", 0.55 * u.clamp(1.4 - k, 0, 1));                // glow stretched down the water
        u.ctx.restore();
      }
      u.label("mix(keyframe[i], keyframe[i+1], f) — the whole sunrise is one lerp between palettes", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { scrub = x / u.W; }                          // click = scrub the hour by x
  };
});

def("E", "Eventide", "sky", "sunset is dawn played backwards with a redder palette — and an afterglow band that outlives the sun", function make(u) {
  var D = { tops: ["#5A8FD8", "#3A4A9A", "#2A1E4A", "#08081C"],          // day → dusk → violet → night
            hors: ["#B8D8F5", "#F58A5A", "#C2507A", "#2A1A3A"],
            length: 9, sunSize: 0.09, afterglow: "#F5C169" };
  var scrub = null;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var k = scrub !== null ? scrub : (0.5 - 0.5 * Math.cos((t / D.length) * u.TAU * 0.5));
      var seg = u.clamp(k * 3, 0, 2.999), i = Math.floor(seg), f = seg - i;
      var top = u.mix(D.tops[i], D.tops[i + 1], f), hor = u.mix(D.hors[i], D.hors[i + 1], f);
      var GY = u.H * 0.72;
      u.sky([[0, top], [0.7, hor], [1, hor]]);
      var glow = Math.sin(u.clamp(k, 0, 1) * Math.PI);                  // the afterglow peaks mid-sunset
      u.ctx.fillStyle = u.lin(0, GY - u.H * 0.2, 0, GY, [[0, u.rgba(D.afterglow, 0)], [1, u.rgba(D.afterglow, glow * 0.6)]]);
      u.ctx.fillRect(0, GY - u.H * 0.2, u.W, u.H * 0.2);
      var sy = GY - u.H * 0.4 + k * u.H * 0.52, sx = u.W * 0.38, r = u.W * D.sunSize;
      u.soft(sx, Math.min(sy, GY), r * 5, "#FFB070", 0.3 * (1 - k * 0.6));
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, 0, u.W, GY); u.ctx.clip();
      u.ctx.fillStyle = u.rad(sx, sy, r, ["#FFE9B0", "#FF8A50"]);
      u.ctx.beginPath(); u.ctx.arc(sx, sy, r * (1 + k * 0.25), 0, u.TAU); u.ctx.fill();   // low suns look bigger
      u.ctx.restore();
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.shade(hor, -0.4), "#06060F"]);
      u.ctx.fillRect(0, GY, u.W, u.H - GY);
      u.label("same clock as Dawn, keyframes reversed — a sunset is a data change, not a new program", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { scrub = x / u.W; }
  };
});

def("G", "Goldenhour", "sky", "a low sun paints everything on one side gold and the other side violet — the hills are HORIZONTAL gradients from lit to shadowed", function make(u) {
  var D = { sky: ["#3A3F8F", "#E8A868", "#FFD9A0"], lit: "#F5C169", shade: "#3A2A5A",
            hills: 4, sunX: 0.12 };
  var R = u.rng(21), hills = [];
  for (var j = 0; j < D.hills; j++) hills.push({ y: 0.55 + j * 0.1, amp: 0.05 + R() * 0.04, ph: R() * 9, f: 1.5 + R() * 2 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]], [1, D.sky[2]]]);
      var sx = u.W * D.sunX, sy = u.H * 0.46;
      u.soft(sx, sy, u.W * 0.5, "#FFD9A0", 0.35);
      u.dot(sx, sy, u.W * 0.05, "#FFF3D0");
      for (var j = 0; j < hills.length; j++) {
        var h = hills[j], depth = 1 - j / hills.length;                 // far hills are LESS lit and paler
        var a = u.mix(D.lit, D.sky[1], depth * 0.5), b = u.mix(D.shade, D.sky[0], depth * 0.4);
        u.ctx.fillStyle = u.lin(sx, 0, u.W, 0, [[0, a], [1, b]]);         // lit side toward the sun
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += 6)
          u.ctx.lineTo(x, u.H * (h.y + Math.sin(x / u.W * h.f * u.TAU + h.ph + t * 0.05) * h.amp));
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      u.label("light has a direction: a horizontal gradient from gold to violet tells the eye where the sun is", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.sunX = x / u.W; }                        // move the sun along the horizon
  };
});

def("H", "Haze", "sky", "heat haze: the horizon band is cut into thin slices and each slice slides sideways on a sine — the shimmer grows toward the ground", function make(u) {
  var D = { sky: ["#3A6FD0", "#9FC8F0", "#F5E1B0"], sand: "#D9A86A", far: "#B9A8C8",
            heat: 1.0, slices: 26 };
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.55, D.sky[1]], [0.7, D.sky[2]]]);
      var GY = u.H * 0.7, band = u.H * 0.16;
      for (var i = 0; i < D.slices; i++) {                              // the far dunes, sliced thin
        var k = i / D.slices, y = GY - band + k * band, hgt = band / D.slices + 1;
        var jitter = Math.sin(t * 6 + k * 14) * D.heat * 6 * k + Math.sin(t * 9.3 + k * 31) * D.heat * 3 * k;
        u.ctx.fillStyle = u.mix(D.far, D.sky[2], (1 - k) * 0.7);          // near the sky it fades INTO the sky
        u.ctx.beginPath(); u.ctx.moveTo(-20, y + hgt);
        for (var x = -20; x <= u.W + 20; x += 10)
          u.ctx.lineTo(x + jitter, y - Math.max(0, Math.sin(x * 0.02 + 1) * 10 + Math.sin(x * 0.05) * 6) * (1 - k * 0.6));
        u.ctx.lineTo(u.W + 20, y + hgt); u.ctx.closePath(); u.ctx.fill();
      }
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.shade(D.sand, 0.15), u.shade(D.sand, -0.3)]);
      u.ctx.fillRect(0, GY, u.W, u.H - GY);
      u.label("distortion by slicing — no shader, just rows that disagree about where they are", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.heat = 0.2 + (x / u.W) * 2.2; }         // click right = hotter
  };
});

def("N", "Nebula", "sky", "a gas cloud is soft radial blobs in three depth layers — far ones small and dim, near ones big and bright — drifting at speeds that match their depth", function make(u) {
  var D = { sky: ["#05040F", "#0F0A22"], hues: [270, 320, 200],          // violet, magenta, cyan
            blobs: 34, drift: 2.5, seed: 5 };
  var R = u.rng(D.seed), blobs = [];
  for (var j = 0; j < D.blobs; j++)
    blobs.push({ x: R() * u.W, y: R() * u.H, z: R(), hue: D.hues[j % D.hues.length] + R() * 30, ph: R() * 9 });
  blobs.sort(function (a, b) { return a.z - b.z; });                     // far first, near last — painter's order
  var R2 = u.rng(D.seed + 1), stars = [];
  for (var s = 0; s < 60; s++) stars.push([R2() * u.W, R2() * u.H, 0.3 + R2() * 0.9]);
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      for (var s = 0; s < stars.length; s++) u.dot(stars[s][0], stars[s][1], stars[s][2], u.rgba(u.INK, 0.5));
      for (var j = 0; j < blobs.length; j++) {
        var b = blobs[j], z = b.z;                                       // z: 0 far … 1 near
        var x = b.x + Math.sin(t * 0.1 * D.drift + b.ph) * (4 + z * 18), y = b.y + Math.cos(t * 0.07 * D.drift + b.ph) * (3 + z * 10);
        u.soft(x, y, u.W * (0.06 + z * 0.16), u.hsl(b.hue, 0.7, 0.55), 0.05 + z * 0.16);
      }
      u.label("depth = size × brightness × speed, all from one number z", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { for (var j = 0; j < blobs.length; j++) { blobs[j].x += (x - u.W / 2) * 0.05 * blobs[j].z; blobs[j].y += (y - u.H / 2) * 0.05 * blobs[j].z; } }   // near blobs move more — parallax
  };
});

def("N", "Nightfall", "sky", "a full day in 14 seconds: five palettes on a circular clock, the sun and moon on opposite arcs, stars fading in with the dark", function make(u) {
  var D = { tops: ["#6FA8E8", "#4A6FC8", "#2A1E5A", "#05051A", "#2A1E5A"],   // noon → golden → dusk → night → dawn (wraps)
            hors: ["#CFE6F5", "#F5C169", "#C2507A", "#1A1030", "#F5A15A"],
            day: 14 };
  var R = u.rng(8), stars = [];
  for (var j = 0; j < 60; j++) stars.push([R() * u.W, R() * u.H * 0.7, 0.4 + R() * 1.0]);
  var offset = 0, lastT = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      lastT = t;
      var k = ((t + offset) / D.day) % 1, n = D.tops.length;
      var seg = k * n, i = Math.floor(seg) % n, f = seg - Math.floor(seg);
      var top = u.mix(D.tops[i], D.tops[(i + 1) % n], f), hor = u.mix(D.hors[i], D.hors[(i + 1) % n], f);
      var GY = u.H * 0.74;
      u.sky([[0, top], [0.75, hor]]);
      var dark = u.clamp(1 - Math.abs(k - 0.7) * 3.2, 0, 1);            // stars only around the night keyframe
      for (var j = 0; j < stars.length; j++) u.dot(stars[j][0], stars[j][1], stars[j][2], u.rgba(u.INK, dark * (0.5 + 0.4 * Math.sin(t * 3 + j))));
      var sx = u.W / 2 + Math.sin(k * u.TAU) * u.W * 0.42, sy = GY - Math.cos(k * u.TAU) * u.H * 0.6;   // sun: overhead at k = 0
      var mx = u.W / 2 - Math.sin(k * u.TAU) * u.W * 0.42, my = GY + Math.cos(k * u.TAU) * u.H * 0.6;   // moon: opposite
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, 0, u.W, GY); u.ctx.clip();
      u.soft(sx, sy, u.W * 0.2, "#FFD9A0", 0.35);
      u.dot(sx, sy, u.W * 0.045, "#FFF3D0");
      u.dot(mx, my, u.W * 0.03, "#E8E5F4");
      u.dot(mx + u.W * 0.012, my - u.W * 0.008, u.W * 0.024, u.mix(top, hor, 0.3));   // a crescent: one disc bites another
      u.ctx.restore();
      u.ground(GY, "#06060F");
      u.label("the clock is circular: keyframe[i] → keyframe[(i+1) mod n], so midnight wraps to dawn", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { offset = (x / u.W) * D.day - lastT; }      // click = set the hour by x
  };
});

def("O", "Overcast", "sky", "a grey day is bands of cloud, each a gradient with a lighter far edge, drifting at speeds that say how far away they are", function make(u) {
  var D = { top: "#5A6478", bottom: "#B8BFCC", cloud: "#7A8396", bands: 6, wind: 1.6, sunbreak: 0 };
  var R = u.rng(13), bands = [];
  for (var j = 0; j < D.bands; j++) bands.push({ y: 0.08 + j * 0.11, h: 0.08 + R() * 0.06, ph: R() * 9, f: 1 + R() * 1.5 });
  var sun = null;
  return {
    frame: function (dt, t) {
      u.sky([D.top, D.bottom]);
      for (var j = 0; j < bands.length; j++) {
        var b = bands[j], depth = j / bands.length;                     // top bands are far (thin, pale, slow)
        var speed = (0.2 + depth * 1.2) * D.wind, x0 = (t * speed * 20 + b.ph * 40) % (u.W + 200) - 100;
        var y = u.H * b.y, h = u.H * b.h;
        var c = u.mix(u.shade(D.cloud, 0.35), u.shade(D.cloud, -0.3), depth * 0.8);
        u.ctx.fillStyle = u.lin(0, y, 0, y + h, [[0, u.shade(c, 0.25)], [0.6, c], [1, u.shade(c, -0.25)]]);   // lit on top, dark underneath
        u.ctx.beginPath(); u.ctx.moveTo(-200, y + h);
        for (var x = -200; x <= u.W + 200; x += 12)
          u.ctx.lineTo(x, y + Math.sin((x - x0) * 0.02 * b.f) * h * 0.4 + Math.sin((x - x0) * 0.05) * h * 0.15);
        u.ctx.lineTo(u.W + 200, y + h); u.ctx.closePath(); u.ctx.fill();
      }
      if (sun) u.soft(sun[0], sun[1], u.W * 0.35, "#FFF3D0", 0.5);       // a sunbreak: one soft radial patch
      u.ground(u.H * 0.85, "#3A3F50");
      u.label("clouds are gradients too: lit on top, dark underneath, paler the farther they are", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { sun = sun ? null : [x, y]; }                // click = the sun breaks through here
  };
});

def("R", "Rainbow", "sky", "a bow is seven concentric arcs of hue, alpha fading at both edges — a gradient bent into a circle, drawn where the light isn't", function make(u) {
  var D = { sky: ["#4A6FA8", "#9FB8D8", "#D9E3F0"], width: 0.12, alpha: 0.55, secondary: true, speed: 1 };
  var cx = u.W * 0.5, cy = u.H * 0.95;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]], [1, D.sky[2]]]);
      var grow = u.ease(t * 0.35 * D.speed), r0 = u.H * 0.5, w = u.H * D.width, n = 28;
      u.ctx.lineCap = "butt";
      for (var pass = 0; pass < (D.secondary ? 2 : 1); pass++) {
        var R0 = pass === 0 ? r0 : r0 * 1.32, alpha = pass === 0 ? D.alpha : D.alpha * 0.28;
        for (var i = 0; i < n; i++) {
          var k = i / n, hue = pass === 0 ? 280 - k * 280 : k * 280;   // the secondary bow runs backwards
          var edge = Math.sin(k * Math.PI);                              // soft at both rims
          u.ctx.strokeStyle = u.hsl(hue, 0.9, 0.6, alpha * edge);
          u.ctx.lineWidth = w / n + 0.6;
          u.ctx.beginPath(); u.ctx.arc(cx, cy, R0 + k * w, Math.PI, Math.PI + Math.PI * grow); u.ctx.stroke();
        }
      }
      u.ground(u.H * 0.86, "#2F4A3A");
      u.label("hsl(hue, …) sweeping 280 → 0 across 28 arcs — colour AS a coordinate", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { cx = x; }                                   // the bow stays opposite the sun; move it
  };
});

def("T", "Twilight", "sky", "the Belt of Venus: a pink band floating above a blue-grey band (the Earth's own shadow) — two horizontal gradients stacked, rising as the sun sinks", function make(u) {
  var D = { top: "#2A3A8F", pink: "#E8A0B8", shadow: "#4A5A8A", horizon: "#F5D9B0", length: 9 };
  var scrub = null;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var k = scrub !== null ? scrub : (0.5 - 0.5 * Math.cos((t / D.length) * Math.PI));   // 0 → 1 and rests
      var GY = u.H * 0.74, band = GY - u.H * 0.28 * k;                  // the shadow's top edge rises
      u.sky([[0, u.mix(D.top, "#0A0F3A", k * 0.7)], [u.clamp(band / u.H - 0.12, 0, 1), u.mix(D.pink, "#5A3A6A", k * 0.6)],
             [u.clamp(band / u.H, 0, 1), u.mix(D.shadow, "#1A2040", k * 0.5)], [GY / u.H, u.mix(D.horizon, "#3A3A5A", k * 0.8)]]);
      u.ground(GY, "#06060F");
      u.poly([[0, GY], [u.W * 0.3, GY - 6], [u.W * 0.5, GY - 14], [u.W * 0.62, GY - 4], [u.W, GY - 10], [u.W, u.H], [0, u.H]], "#06060F");
      u.label("the grey band IS the planet's shadow on its own air — depth you can see from the ground", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { scrub = x / u.W; }
  };
});

def("Z", "Zenith", "sky", "the plainest sky: deep blue overhead, pale at the horizon, because you look through more air sideways — plus a bright patch that follows the sun", function make(u) {
  var D = { zenith: "#1E4FB8", horizon: "#CFE6F5", sunGlow: "#FFF3D0", sunX: 0.7, sunY: 0.25 };
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.zenith], [0.85, D.horizon]]);
      var sx = u.W * D.sunX, sy = u.H * D.sunY;
      u.soft(sx, sy, u.W * 0.55, D.sunGlow, 0.35);                       // air near the sun scatters brighter
      u.soft(sx, sy, u.W * 0.1, D.sunGlow, 0.9);
      u.ground(u.H * 0.85, "#4A7A5A");
      u.ctx.fillStyle = u.lin(0, u.H * 0.85, 0, u.H, ["#6A9A6A", "#3A5A3A"]);   // even the grass is a gradient
      u.ctx.fillRect(0, u.H * 0.85, u.W, u.H * 0.15);
      u.label("zenith → horizon: more air = paler and whiter. That one gradient is 'outdoors'", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.sunX = x / u.W; D.sunY = y / u.H; }
  };
});

/* ---- the rhymes: same pictures, two or three dials moved ---- */

rhymeOf("Aurora", "Glitch aurora", "the same curtains in magenta and cyan, 16 fat strips instead of 48, three times the speed — coarse and twitchy", function make(u) {
  // rhyme of Aurora: dials moved — hi/lo palette, strips 48 → 16, speed 0.35 → 1.1
  var D = { sky: ["#07071A", "#0E1230"], hi: "#40F0F0", lo: "#F040C0",
            strips: 16, speed: 1.1, glow: 0.8 };
  var R = u.rng(3), stars = [];
  for (var j = 0; j < 40; j++) stars.push([R() * u.W, R() * u.H * 0.7, 0.4 + R() * 1.1]);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      for (var j = 0; j < stars.length; j++)
        u.dot(stars[j][0], stars[j][1], stars[j][2], u.rgba(u.INK, 0.35 + 0.35 * Math.sin(t * 2 + j)));
      var sw = u.W / D.strips;
      for (var i = 0; i < D.strips; i++) {
        var k = i / D.strips, x = i * sw;
        var top = u.H * (0.16 + 0.08 * Math.sin(k * 5 + t * D.speed * 2) + 0.04 * Math.sin(k * 11 - t * D.speed * 3));
        var bot = u.H * (0.62 + 0.05 * Math.sin(k * 3 + t * D.speed));
        var a = D.glow * (0.5 + 0.45 * Math.sin(k * 9 + t * D.speed * 4));
        u.ctx.fillStyle = u.lin(0, top, 0, bot, [[0, u.rgba(D.lo, 0)], [0.35, u.rgba(D.lo, a * 0.8)], [0.7, u.rgba(D.hi, a)], [1, u.rgba(D.hi, 0)]]);
        u.ctx.fillRect(x, top, sw + 1, bot - top);
      }
      u.ground(u.H * 0.86, "#04040C");
      u.label("fewer strips = the same gradients, now visible as bars — the seams become the style", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.speed = 0.15 + (x / u.W) * 1.2; }
  };
});

rhymeOf("Bluehour", "Alien bluehour", "the same dusk under a green sky with a copper horizon, twice as many stars, and the hour over in six seconds", function make(u) {
  // rhyme of Bluehour: dials moved — top/mid/horizon palette, stars 70 → 140, minutes 14 → 6
  var D = { top: "#0A2A1A", mid: "#2A7A5A", horizon: "#E89A5A", ground: "#06060F",
            minutes: 6, stars: 140 };
  var R = u.rng(11), stars = [];
  for (var j = 0; j < D.stars; j++) stars.push([R() * u.W, R() * u.H * 0.75, 0.4 + R() * 1.0, R()]);
  var k = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      k = u.clamp((t % (D.minutes * 1.4)) / D.minutes, 0, 1);
      var top = u.mix(D.top, "#030312", k), mid = u.mix(D.mid, "#0B1040", k), hor = u.mix(D.horizon, "#3A2A4F", k);
      u.sky([[0, top], [0.55, mid], [0.86, hor], [1, u.mix(hor, D.ground, 0.5)]]);
      for (var j = 0; j < stars.length; j++) {
        var s = stars[j], born = s[3] * 0.9;
        if (k > born) u.dot(s[0], s[1], s[2], u.rgba(u.INK, u.clamp((k - born) * 6, 0, 0.9) * (0.6 + 0.4 * Math.sin(t * 3 + j))));
      }
      u.poly([[0, u.H * 0.86], [u.W * 0.2, u.H * 0.78], [u.W * 0.45, u.H * 0.83], [u.W * 0.7, u.H * 0.76], [u.W, u.H * 0.82], [u.W, u.H], [0, u.H]], D.ground);
      u.label("a sky is a palette: change three hex codes and you are on another planet", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.minutes = 4 + (x / u.W) * 24; }
  };
});

rhymeOf("Dawn", "Candy dawn", "the same sunrise in pastel — mint to peach to cream — a sun twice as big, and no sea", function make(u) {
  // rhyme of Dawn: dials moved — both palettes, sunSize 0.09 → 0.18, sea true → false
  var D = { tops: ["#3A2A5A", "#8A6AB8", "#A8D8C8", "#BFE8F5"],
            hors: ["#5A3A6A", "#F5A0B8", "#FFD0A0", "#FFF3E0"],
            length: 9, sunSize: 0.18, sea: false };
  var scrub = null;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var k = scrub !== null ? scrub : (0.5 - 0.5 * Math.cos((t / D.length) * u.TAU * 0.5)) ;
      var seg = u.clamp(k * 3, 0, 2.999), i = Math.floor(seg), f = seg - i;
      var top = u.mix(D.tops[i], D.tops[i + 1], f), hor = u.mix(D.hors[i], D.hors[i + 1], f);
      var GY = u.H * 0.72;
      u.sky([[0, top], [0.7, hor], [1, hor]]);
      var sy = GY + u.H * 0.12 - k * u.H * 0.45, sx = u.W * 0.62, r = u.W * D.sunSize;
      u.soft(sx, sy, r * 5, "#FFD9A0", 0.25 + k * 0.25);
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, 0, u.W, GY); u.ctx.clip();
      u.ctx.fillStyle = u.rad(sx, sy, r, ["#FFF3D0", "#FFC879"]);
      u.ctx.beginPath(); u.ctx.arc(sx, sy, r, 0, u.TAU); u.ctx.fill();
      u.ctx.restore();
      if (D.sea) {
        u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.shade(hor, -0.35), u.shade(top, -0.5)]);
        u.ctx.fillRect(0, GY, u.W, u.H - GY);
      } else {
        u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.shade(hor, -0.15), u.shade(hor, -0.45)]);   // a pastel meadow instead
        u.ctx.fillRect(0, GY, u.W, u.H - GY);
      }
      u.label("desaturate the keyframes and the same sunrise turns cozy — palette is genre", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { scrub = x / u.W; }
  };
});

rhymeOf("Eventide", "Desert eventide", "the same sunset over sand — ochre and rust palette, a huge low sun, and a copper afterglow", function make(u) {
  // rhyme of Eventide: dials moved — both palettes, sunSize 0.09 → 0.16, afterglow colour
  var D = { tops: ["#8AAED8", "#C8785A", "#5A2A3A", "#0A0810"],
            hors: ["#F5D9B0", "#F5A15A", "#B85A3A", "#2A1A1A"],
            length: 9, sunSize: 0.16, afterglow: "#F58A5A" };
  var scrub = null;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var k = scrub !== null ? scrub : (0.5 - 0.5 * Math.cos((t / D.length) * u.TAU * 0.5));
      var seg = u.clamp(k * 3, 0, 2.999), i = Math.floor(seg), f = seg - i;
      var top = u.mix(D.tops[i], D.tops[i + 1], f), hor = u.mix(D.hors[i], D.hors[i + 1], f);
      var GY = u.H * 0.72;
      u.sky([[0, top], [0.7, hor], [1, hor]]);
      var glow = Math.sin(u.clamp(k, 0, 1) * Math.PI);
      u.ctx.fillStyle = u.lin(0, GY - u.H * 0.2, 0, GY, [[0, u.rgba(D.afterglow, 0)], [1, u.rgba(D.afterglow, glow * 0.6)]]);
      u.ctx.fillRect(0, GY - u.H * 0.2, u.W, u.H * 0.2);
      var sy = GY - u.H * 0.4 + k * u.H * 0.52, sx = u.W * 0.38, r = u.W * D.sunSize;
      u.soft(sx, Math.min(sy, GY), r * 5, "#FFB070", 0.3 * (1 - k * 0.6));
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, 0, u.W, GY); u.ctx.clip();
      u.ctx.fillStyle = u.rad(sx, sy, r, ["#FFE9B0", "#FF8A50"]);
      u.ctx.beginPath(); u.ctx.arc(sx, sy, r * (1 + k * 0.25), 0, u.TAU); u.ctx.fill();
      u.ctx.restore();
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.shade(hor, -0.2), "#1A0E0A"]);   // sand, not sea
      u.ctx.fillRect(0, GY, u.W, u.H - GY);
      u.label("a bigger disc and a warmer ramp: the sun 'nearer' the ground reads as hotter and heavier", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { scrub = x / u.W; }
  };
});

rhymeOf("Goldenhour", "Silver hour", "the same low light in greyscale — a white sun, eight thin hills, a minimalist print", function make(u) {
  // rhyme of Goldenhour: dials moved — palette to greys, hills 4 → 8
  var D = { sky: ["#3A3A44", "#8A8A96", "#D8D8E0"], lit: "#E8E8F0", shade: "#22222A",
            hills: 8, sunX: 0.12 };
  var R = u.rng(21), hills = [];
  for (var j = 0; j < D.hills; j++) hills.push({ y: 0.5 + j * 0.055, amp: 0.03 + R() * 0.03, ph: R() * 9, f: 1.5 + R() * 2 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]], [1, D.sky[2]]]);
      var sx = u.W * D.sunX, sy = u.H * 0.5;
      u.soft(sx, sy, u.W * 0.5, "#FFFFFF", 0.3);
      u.dot(sx, sy, u.W * 0.05, "#FFFFFF");
      for (var j = 0; j < hills.length; j++) {
        var h = hills[j], depth = 1 - j / hills.length;
        var a = u.mix(D.lit, D.sky[1], depth * 0.5), b = u.mix(D.shade, D.sky[0], depth * 0.4);
        u.ctx.fillStyle = u.lin(sx, 0, u.W, 0, [[0, a], [1, b]]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += 6)
          u.ctx.lineTo(x, u.H * (h.y + Math.sin(x / u.W * h.f * u.TAU + h.ph + t * 0.05) * h.amp));
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      u.label("remove the hue and the depth is still there — value does the work, colour is decoration", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.sunX = x / u.W; }
  };
});

rhymeOf("Haze", "Cold haze", "the same shimmer over ice — a blue-white palette, half the heat, twice the slices", function make(u) {
  // rhyme of Haze: dials moved — palette to arctic, heat 1.0 → 0.5, slices 26 → 52
  var D = { sky: ["#1E3A7A", "#8AB8E8", "#E8F0F8"], sand: "#C8DCEC", far: "#A8C0D8",
            heat: 0.5, slices: 52 };
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.55, D.sky[1]], [0.7, D.sky[2]]]);
      var GY = u.H * 0.7, band = u.H * 0.16;
      for (var i = 0; i < D.slices; i++) {
        var k = i / D.slices, y = GY - band + k * band, hgt = band / D.slices + 1;
        var jitter = Math.sin(t * 6 + k * 14) * D.heat * 6 * k + Math.sin(t * 9.3 + k * 31) * D.heat * 3 * k;
        u.ctx.fillStyle = u.mix(D.far, D.sky[2], (1 - k) * 0.7);
        u.ctx.beginPath(); u.ctx.moveTo(-20, y + hgt);
        for (var x = -20; x <= u.W + 20; x += 10)
          u.ctx.lineTo(x + jitter, y - Math.max(0, Math.sin(x * 0.02 + 1) * 10 + Math.sin(x * 0.05) * 6) * (1 - k * 0.6));
        u.ctx.lineTo(u.W + 20, y + hgt); u.ctx.closePath(); u.ctx.fill();
      }
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.shade(D.sand, 0.15), u.shade(D.sand, -0.3)]);
      u.ctx.fillRect(0, GY, u.W, u.H - GY);
      u.label("thinner slices, gentler sway: the same distortion reads as cold air instead of heat", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.heat = 0.2 + (x / u.W) * 2.2; }
  };
});

rhymeOf("Nebula", "Ink nebula", "the same cloud in two inks — indigo and rust — with 60 blobs and a slower drift; a different seed, so a different cloud", function make(u) {
  // rhyme of Nebula: dials moved — hues, blobs 34 → 60, drift 1.0 → 0.4, seed 5 → 9
  var D = { sky: ["#0A0A10", "#14121C"], hues: [230, 20],
            blobs: 60, drift: 1.0, seed: 9 };
  var R = u.rng(D.seed), blobs = [];
  for (var j = 0; j < D.blobs; j++)
    blobs.push({ x: R() * u.W, y: R() * u.H, z: R(), hue: D.hues[j % D.hues.length] + R() * 30, ph: R() * 9 });
  blobs.sort(function (a, b) { return a.z - b.z; });
  var R2 = u.rng(D.seed + 1), stars = [];
  for (var s = 0; s < 60; s++) stars.push([R2() * u.W, R2() * u.H, 0.3 + R2() * 0.9]);
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      for (var s = 0; s < stars.length; s++) u.dot(stars[s][0], stars[s][1], stars[s][2], u.rgba(u.INK, 0.5));
      for (var j = 0; j < blobs.length; j++) {
        var b = blobs[j], z = b.z;
        var x = b.x + Math.sin(t * 0.1 * D.drift + b.ph) * (4 + z * 18), y = b.y + Math.cos(t * 0.07 * D.drift + b.ph) * (3 + z * 10);
        u.soft(x, y, u.W * (0.06 + z * 0.16), u.hsl(b.hue, 0.6, 0.45), 0.05 + z * 0.16);
      }
      u.label("the seed is a dial too — same recipe, a different sky every time you change it", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { for (var j = 0; j < blobs.length; j++) { blobs[j].x += (x - u.W / 2) * 0.05 * blobs[j].z; blobs[j].y += (y - u.H / 2) * 0.05 * blobs[j].z; } }
  };
});

rhymeOf("Nightfall", "Fast-forward night", "the same day in six seconds instead of 24, with a purple-and-teal palette — a time-lapse", function make(u) {
  // rhyme of Nightfall: dials moved — day 24 → 6, both palettes
  var D = { tops: ["#3AA8C8", "#2A6FA8", "#3A1E6A", "#05051A", "#4A1E5A"],
            hors: ["#B8F0F0", "#F5C169", "#D050A0", "#1A1030", "#F58A8A"],
            day: 6 };
  var R = u.rng(8), stars = [];
  for (var j = 0; j < 60; j++) stars.push([R() * u.W, R() * u.H * 0.7, 0.4 + R() * 1.0]);
  var offset = 0, lastT = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      lastT = t;
      var k = ((t + offset) / D.day) % 1, n = D.tops.length;
      var seg = k * n, i = Math.floor(seg) % n, f = seg - Math.floor(seg);
      var top = u.mix(D.tops[i], D.tops[(i + 1) % n], f), hor = u.mix(D.hors[i], D.hors[(i + 1) % n], f);
      var GY = u.H * 0.74;
      u.sky([[0, top], [0.75, hor]]);
      var dark = u.clamp(1 - Math.abs(k - 0.7) * 3.2, 0, 1);
      for (var j = 0; j < stars.length; j++) u.dot(stars[j][0], stars[j][1], stars[j][2], u.rgba(u.INK, dark * (0.5 + 0.4 * Math.sin(t * 3 + j))));
      var sx = u.W / 2 + Math.sin(k * u.TAU) * u.W * 0.42, sy = GY - Math.cos(k * u.TAU) * u.H * 0.6;
      var mx = u.W / 2 - Math.sin(k * u.TAU) * u.W * 0.42, my = GY + Math.cos(k * u.TAU) * u.H * 0.6;
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, 0, u.W, GY); u.ctx.clip();
      u.soft(sx, sy, u.W * 0.2, "#FFD9A0", 0.35);
      u.dot(sx, sy, u.W * 0.045, "#FFF3D0");
      u.dot(mx, my, u.W * 0.03, "#E8E5F4");
      u.dot(mx + u.W * 0.012, my - u.W * 0.008, u.W * 0.024, u.mix(top, hor, 0.3));
      u.ctx.restore();
      u.ground(GY, "#06060F");
      u.label("one number (day) sets the tempo — a time-lapse is the same clock read faster", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { offset = (x / u.W) * D.day - lastT; }
  };
});

rhymeOf("Overcast", "Stormfront", "the same cloud bands, near-black, in a gale — with a flash every few seconds that lights their undersides", function make(u) {
  // rhyme of Overcast: dials moved — palette to storm greys, wind 1.0 → 3.0, sunbreak becomes lightning
  var D = { top: "#1A1E2A", bottom: "#4A5060", cloud: "#2A2F3A", bands: 6, wind: 3.0, flashEvery: 3.5 };
  var R = u.rng(13), bands = [];
  for (var j = 0; j < D.bands; j++) bands.push({ y: 0.08 + j * 0.11, h: 0.08 + R() * 0.06, ph: R() * 9, f: 1 + R() * 1.5 });
  var flashAt = -9, lastT = 0;
  return {
    frame: function (dt, t) {
      lastT = t;
      if (t - flashAt > D.flashEvery) flashAt = t + R() * 1.5;         // the next flash, a little unpredictable
      var flash = u.clamp(1 - (t - flashAt) * 6, 0, 1);                  // a flash decays in ~1/6 s
      u.sky([u.mix(D.top, "#8A90B0", flash * 0.5), u.mix(D.bottom, "#C8CCE0", flash * 0.6)]);
      for (var j = 0; j < bands.length; j++) {
        var b = bands[j], depth = j / bands.length;
        var speed = (0.2 + depth * 1.2) * D.wind, x0 = (t * speed * 20 + b.ph * 40) % (u.W + 200) - 100;
        var y = u.H * b.y, h = u.H * b.h;
        var c = u.mix(u.shade(D.cloud, 0.35), u.shade(D.cloud, -0.3), depth * 0.8);
        u.ctx.fillStyle = u.lin(0, y, 0, y + h, [[0, u.shade(c, 0.1)], [0.6, c], [1, u.mix(u.shade(c, -0.3), "#E8E8FF", flash * 0.8)]]);   // lightning lights the UNDERSIDE
        u.ctx.beginPath(); u.ctx.moveTo(-200, y + h);
        for (var x = -200; x <= u.W + 200; x += 12)
          u.ctx.lineTo(x, y + Math.sin((x - x0) * 0.02 * b.f) * h * 0.4 + Math.sin((x - x0) * 0.05) * h * 0.15);
        u.ctx.lineTo(u.W + 200, y + h); u.ctx.closePath(); u.ctx.fill();
      }
      u.ground(u.H * 0.85, u.mix("#14161E", "#5A6070", flash));
      u.label("the flash swaps which edge of each band is lit — light from below is the whole storm", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { flashAt = lastT; }                         // click = lightning, now
  };
});

rhymeOf("Rainbow", "Moonbow", "the same bow at night — a quarter of the alpha, no secondary bow, drawn twice as slowly under stars", function make(u) {
  // rhyme of Rainbow: dials moved — sky palette to night, alpha 0.55 → 0.14, secondary true → false, speed 1 → 0.5
  var D = { sky: ["#05051A", "#151838", "#2A2A4F"], width: 0.12, alpha: 0.14, secondary: false, speed: 0.5 };
  var cx = u.W * 0.5, cy = u.H * 0.95;
  var R = u.rng(4), stars = [];
  for (var j = 0; j < 50; j++) stars.push([R() * u.W, R() * u.H * 0.8, 0.4 + R() * 1.0]);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]], [1, D.sky[2]]]);
      for (var j = 0; j < stars.length; j++) u.dot(stars[j][0], stars[j][1], stars[j][2], u.rgba(u.INK, 0.5 + 0.4 * Math.sin(t * 2 + j)));
      u.dot(u.W * 0.5, u.H * 0.12, u.W * 0.035, "#F0EEFF");             // the moon the bow belongs to
      var grow = u.ease(t * 0.35 * D.speed), r0 = u.H * 0.5, w = u.H * D.width, n = 28;
      for (var pass = 0; pass < (D.secondary ? 2 : 1); pass++) {
        var R0 = pass === 0 ? r0 : r0 * 1.32, alpha = pass === 0 ? D.alpha : D.alpha * 0.28;
        for (var i = 0; i < n; i++) {
          var k = i / n, hue = pass === 0 ? 280 - k * 280 : k * 280;
          var edge = Math.sin(k * Math.PI);
          u.ctx.strokeStyle = u.hsl(hue, 0.6, 0.7, alpha * edge);
          u.ctx.lineWidth = w / n + 0.6;
          u.ctx.beginPath(); u.ctx.arc(cx, cy, R0 + k * w, Math.PI, Math.PI + Math.PI * grow); u.ctx.stroke();
        }
      }
      u.ground(u.H * 0.86, "#0A1410");
      u.label("alpha is a dial: at 0.14 the same hues read as a ghost — moonlight is just less of it", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { cx = x; }
  };
});

rhymeOf("Twilight", "Cyber twilight", "the same two bands in neon — hot pink over electric blue over a black horizon — a synthwave poster", function make(u) {
  // rhyme of Twilight: dials moved — all four colours, length 18 → 10
  var D = { top: "#0A0020", pink: "#FF2A9A", shadow: "#1A5AFF", horizon: "#000000", length: 10 };
  var scrub = null;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var k = scrub !== null ? scrub : (0.5 - 0.5 * Math.cos((t / D.length) * Math.PI));
      var GY = u.H * 0.74, band = GY - u.H * 0.28 * k;
      u.sky([[0, u.mix(D.top, "#000010", k * 0.7)], [u.clamp(band / u.H - 0.12, 0, 1), u.mix(D.pink, "#7A1A5A", k * 0.6)],
             [u.clamp(band / u.H, 0, 1), u.mix(D.shadow, "#0A1A60", k * 0.5)], [GY / u.H, D.horizon]]);
      for (var i = 0; i < 9; i++) u.line(0, GY + i * i * 2.2, u.W, GY + i * i * 2.2, u.rgba("#FF2A9A", 0.6 - i * 0.05), 1);   // a floor grid receding
      u.ground(u.H * 0.98, "#000000");
      u.label("saturate the bands to neon and the same physics becomes a genre", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { scrub = x / u.W; }
  };
});

rhymeOf("Zenith", "Martian zenith", "the same clear sky on Mars: butterscotch overhead, blue near the small sun — the gradient runs the other way", function make(u) {
  // rhyme of Zenith: dials moved — zenith/horizon colours swapped in character, sunGlow to pale blue
  var D = { zenith: "#C8925A", horizon: "#E8C8A0", sunGlow: "#B8D8FF", sunX: 0.7, sunY: 0.25 };
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.zenith], [0.85, D.horizon]]);
      var sx = u.W * D.sunX, sy = u.H * D.sunY;
      u.soft(sx, sy, u.W * 0.4, D.sunGlow, 0.35);                        // Martian dust scatters BLUE near the sun
      u.soft(sx, sy, u.W * 0.06, "#FFFFFF", 0.9);
      u.ground(u.H * 0.85, "#8A4A2A");
      u.ctx.fillStyle = u.lin(0, u.H * 0.85, 0, u.H, ["#B86A3A", "#5A2A1A"]);
      u.ctx.fillRect(0, u.H * 0.85, u.W, u.H * 0.15);
      u.label("the physics is the same gradient; only the air's colour changed — dust, not nitrogen", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.sunX = x / u.W; D.sunY = y / u.H; }
  };
});

/* ============================ DISTANCE & ATMOSPHERE ============================
   You never see a far thing directly — you see it THROUGH the air between
   you, and air has a colour. So far things are mixed toward that colour:
   paler, bluer, lower in contrast. Add three cheaper cues that ride along
   with distance — smaller, packed closer together, sliding slower when the
   camera moves — and a flat canvas gets a horizon. Every card here is
   u.fog(colour, depth, air) plus one of those cues, and the depth is a single
   number per thing. Thirteen pictures, most of them mountains. */

def("A", "Alps", "far", "six mountain silhouettes, each mixed toward the sky by depth — the far ones nearly dissolve; press slides the camera and the near ridge moves most", function make(u) {
  var D = { sky: ["#5A82C8", "#C8DCEE"], rock: "#262A42", air: "#B4C8E2",   // the air is what far rock turns into
            layers: 6, jag: 1.0, drift: 0.4, seed: 7 };
  var R = u.rng(D.seed), L = [];
  for (var j = 0; j < D.layers; j++) {                                   // j = 0 is the farthest ridge
    var depth = D.layers > 1 ? 1 - j / (D.layers - 1) : 0;              // 1 = at the horizon, 0 = here
    L.push({ depth: depth, base: 0.36 + j * 0.085, amp: (0.05 + j * 0.018) * D.jag,
             f: [1.2 + R() * 1.4, 2.6 + R() * 2.4, 6 + R() * 5], ph: [R() * 9, R() * 9, R() * 9] });
  }
  var cam = 0, aim = 0;
  function ridge(l, x) {                                                 // three sines summed = a jagged skyline
    var k = x / u.W;
    return u.H * (l.base - l.amp * (0.55 * Math.sin(k * l.f[0] * u.TAU + l.ph[0]) + 0.35 * Math.abs(Math.sin(k * l.f[1] * u.TAU + l.ph[1])) + 0.1 * Math.sin(k * l.f[2] * u.TAU + l.ph[2])));
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);                          // the camera glides, it doesn't jump
      u.sky([[0, D.sky[0]], [0.65, D.sky[1]]]);
      for (var j = 0; j < L.length; j++) {
        var l = L[j], near = 1 - l.depth;
        var shift = (cam * 0.35 + t * D.drift * 0.03) * near * u.W;     // parallax: near ridges slide farther
        u.ctx.fillStyle = u.fog(D.rock, l.depth * 0.92, D.air);          // the depth IS the amount of air in front
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += 4) u.ctx.lineTo(x, ridge(l, x + shift));
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      u.label("same rock, more air: fog(rock, depth) — six shades of one colour is a mountain range", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }               // click = look left or right
  };
});

def("C", "Canyon", "far", "cliff walls step in from both sides toward a bright far gap: each nearer pair is darker and warmer, and dust pools between them; press sets the dust", function make(u) {
  var D = { sky: ["#6A90CC", "#F8E8C8"], rock: "#8A4630", air: "#EED2A8", dust: 1.0, pairs: 6, seed: 5 };
  var R = u.rng(D.seed), walls = [], HY = u.H * 0.6;
  for (var j = 0; j < D.pairs; j++) {                                    // j = 0 is the farthest pair
    var p = D.pairs > 1 ? j / (D.pairs - 1) : 1;                         // 0 far … 1 near
    walls.push({ p: p, inner: 0.05 + p * p * 0.43, top: 0.5 - p * 0.8, bot: 0.6 + p * p * 0.5,
                 kink: (R() - 0.5) * 0.06, ledge: 0.25 + R() * 0.45 });  // kink: how far the edge leans; ledge: where it steps
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.58, D.sky[1]]]);
      u.soft(u.W / 2, HY, u.W * 0.28, "#FFF6DC", 0.7);                   // the gap glows: it is the far end, so it is the brightest
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.fog(D.rock, 0.7, D.air), u.shade(D.rock, -0.5)]);   // the floor fogs toward the far end too
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (var j = 0; j < walls.length; j++) {
        var w = walls[j], c = u.fog(u.shade(D.rock, -w.p * 0.55), (1 - w.p) * 0.85 * D.dust, D.air);   // nearer: darker; farther: more air
        for (var side = -1; side <= 1; side += 2) {                      // the same wall, mirrored
          var xi = u.W * (0.5 + side * w.inner), xo = u.W * (0.5 + side * 0.6), top = u.H * w.top, bot = u.H * w.bot;
          u.poly([[xo, top], [xi + side * w.kink * u.W, top], [xi, top + (bot - top) * w.ledge], [xi + side * w.kink * u.W * 0.5, bot], [xo, bot]], c);
        }
        u.ctx.fillStyle = u.lin(0, u.H * 0.2, 0, u.H * w.bot, [[0, u.rgba(D.air, 0)], [1, u.rgba(D.air, 0.22 * D.dust * (1 - w.p))]]);   // dust settles in front of each pair, thickest far back
        u.ctx.fillRect(0, u.H * 0.2, u.W, u.H * w.bot - u.H * 0.2);
      }
      u.label("every step nearer takes away air and adds contrast — turn the dust up and the far walls go first", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.dust = 0.2 + (x / u.W) * 1.6; }         // click right = a dustier day
  };
});

def("D", "Dunes", "far", "dune crests stacked back to a pale horizon: each a horizontal gradient, lit side to shadow side, fading to peach with distance; press moves the sun", function make(u) {
  var D = { sky: ["#6A9AD8", "#F5DDB8"], sand: "#D89A52", shade: "#7A3E22", air: "#F2D8B8",
            dunes: 7, sunX: 0.15, seed: 9 };
  var R = u.rng(D.seed), dunes = [];
  for (var j = 0; j < D.dunes; j++) dunes.push({ base: 0.45 + j * 0.07, amp: 0.05 + j * 0.02, f: 0.7 + R() * 1.0, ph: R() * 9 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.5, D.sky[1]]]);
      var fromLeft = D.sunX < 0.5;
      for (var j = 0; j < dunes.length; j++) {
        var d = dunes[j], depth = dunes.length > 1 ? 1 - j / (dunes.length - 1) : 0;
        var lit = u.fog(u.shade(D.sand, 0.18), depth * 0.85, D.air), dark = u.fog(D.shade, depth * 0.85, D.air);   // both sides fog together
        var crest = 0.3 + 0.1 * Math.sin(t * 0.3 + j * 1.3);             // the bright crest drifts slowly along the dune
        u.ctx.fillStyle = u.lin(fromLeft ? 0 : u.W, 0, fromLeft ? u.W : 0, 0, [[0, lit], [crest, u.shade(lit, 0.1)], [1, dark]]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += 4) {
          var k = x / u.W, bump = Math.pow(0.5 + 0.5 * Math.sin(k * d.f * u.TAU + d.ph), 1.6);   // rounded crest, sharp trough
          u.ctx.lineTo(x, u.H * (d.base - d.amp * bump));
        }
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      u.label("far dunes lose their shadow side first: fog eats contrast before it eats colour", u.W / 2, u.H - 8, "rgba(40,20,10,0.65)", "center");
    },
    press: function (x, y) { D.sunX = x / u.W; }                        // click = put the sun on that side
  };
});

def("F", "Fjord", "far", "fogged mountain layers over still water, each mirrored below the line — the reflection darker and fading down under a gradient mask; press for wind", function make(u) {
  var D = { sky: ["#7A9AC8", "#D8E4EE"], rock: "#2C3446", air: "#C0D0E0", water: "#1E2A3E",
            layers: 4, wind: 0.3, seed: 12 };
  var R = u.rng(D.seed), L = [], WL = u.H * 0.6;                         // WL: the waterline
  for (var j = 0; j < D.layers; j++)
    L.push({ base: 0.5 + j * 0.03, amp: 0.1 + j * 0.06, f: [1 + R() * 1.2, 3 + R() * 3], ph: [R() * 9, R() * 9],
             depth: D.layers > 1 ? 1 - j / (D.layers - 1) : 0 });
  function ridge(l, x) {
    var k = x / u.W;
    return u.H * (l.base - l.amp * (0.6 * Math.abs(Math.sin(k * l.f[0] * u.TAU + l.ph[0])) + 0.4 * Math.abs(Math.sin(k * l.f[1] * u.TAU + l.ph[1]))));
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]]]);
      u.ctx.fillStyle = u.lin(0, WL, 0, u.H, [u.mix(D.sky[1], D.water, 0.3), D.water]);
      u.ctx.fillRect(0, WL, u.W, u.H - WL);
      for (var j = 0; j < L.length; j++) {
        var l = L[j], c = u.fog(D.rock, l.depth * 0.9, D.air), x;
        u.ctx.fillStyle = c;
        u.ctx.beginPath(); u.ctx.moveTo(0, WL);
        for (x = 0; x <= u.W; x += 4) u.ctx.lineTo(x, ridge(l, x));
        u.ctx.lineTo(u.W, WL); u.ctx.closePath(); u.ctx.fill();
        u.ctx.fillStyle = u.shade(c, -0.25);                             // the reflection: the same ridge, flipped and darker
        u.ctx.beginPath(); u.ctx.moveTo(-10, WL);
        for (x = 0; x <= u.W; x += 4) {
          var y = 2 * WL - ridge(l, x), wob = Math.sin(y * 0.25 + t * 2.5) * D.wind * 3 * ((y - WL) / u.H) * 10;   // ripples smear it sideways, more the lower you look
          u.ctx.lineTo(x + wob, y);
        }
        u.ctx.lineTo(u.W + 10, WL); u.ctx.closePath(); u.ctx.fill();
      }
      u.ctx.fillStyle = u.lin(0, WL, 0, u.H, [[0, u.rgba(D.water, 0.1)], [1, u.rgba(D.water, 0.9)]]);   // the mask: reflections fade the farther below the line
      u.ctx.fillRect(0, WL, u.W, u.H - WL);
      u.label("a reflection is the picture flipped, darkened, and faded by one vertical gradient — the fog comes along for free", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = 0.1 + (x / u.W) * 2.5; }         // click right = wind on the water
  };
});

def("I", "Icebergs", "far", "three rows of bergs over a mist band: the far row is smaller, paler, and heaves slower — one number z sets size, colour, and how quickly a berg answers the swell, overshooting the crest and tipping after it; press pans", function make(u) {
  var D = { sky: ["#4A6A9A", "#C8D8E8"], ice: "#DCEAF5", sea: "#2A4A6A", air: "#B8C8D8", mist: "#FFFFFF",
            perRow: 5, rows: 3, seed: 21,
            swell: 2.0,              // a berg's heave rate, rad/s (√k) at z = 0.5 — the near row is quicker, the far row slower
            damp: 0.3,               // heave damping as a fraction of critical: well under 1, so a berg overshoots the water line and settles
            roll: 0.03 };            // radians of tilt per px/s of heave — a second spring chases the heave velocity, so a berg tips after it rises
  var R = u.rng(D.seed), bergs = [], HY = u.H * 0.55;
  for (var r = 0; r < D.rows; r++)                                       // r = 0 far … rows-1 near
    for (var i = 0; i < D.perRow; i++) {
      var z = D.rows > 1 ? r / (D.rows - 1) : 1, pts = [], n = 5 + Math.floor(R() * 3);   // z: 0 far … 1 near
      for (var k = 0; k < n; k++) pts.push([(k / (n - 1)) * 2 - 1, -(0.2 + R() * 0.8) * Math.sin(k / (n - 1) * Math.PI)]);   // a jagged lump, unit sized
      bergs.push({ z: z, x: (i + R() * 0.8) / D.perRow, pts: pts, ph: R() * 9, s: 0.5 + R() * 0.7 });
    }
  var nb = bergs.length, hy = new Float32Array(nb), hv = new Float32Array(nb), rl = new Float32Array(nb), rv = new Float32Array(nb);   // heave (px off the still line) + velocity, roll (radians) + velocity
  for (var q = 0; q < nb; q++) hy[q] = Math.sin(bergs[q].ph) * (0.5 + bergs[q].z * 2.5);   // start ON the water, so nothing lurches at t = 0
  var cam = 0, aim = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      // the sine field is the SWELL — the water line each berg wants — and a
      // berg is a damped spring toward it: it has mass, so it lags the crest,
      // overshoots it, and settles back (damping well under critical). k grows
      // with z (√k = swell · (0.5 + z)): the near row answers the water at
      // once, the far row is slow to follow — the same z that sets size and
      // colour sets how quickly a thing moves. the roll is a second spring
      // whose rest is the heave VELOCITY, so a berg tips after it rises.
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, j, s;     // substeps of ≤ 0.02 s: symplectic euler wants √k·h < 2
      var kr = 16, dr = 0.4 * 2 * Math.sqrt(kr);                          // the roll spring: k 16, damping 0.4 of critical — lags the heave
      for (j = 0; j < nb; j++) {
        var bg = bergs[j], zz = bg.z, w0 = D.swell * (0.5 + zz), kk = w0 * w0, dd = D.damp * 2 * w0;
        var rest = Math.sin(t * (0.4 + zz * 0.9) + bg.ph) * (0.5 + zz * 2.5);   // the swell: near water moves faster and farther
        for (s = 0; s < sub; s++) {
          hv[j] += (kk * (rest - hy[j]) - dd * hv[j]) * h; hy[j] = u.clamp(hy[j] + hv[j] * h, -u.H * 0.1, u.H * 0.1);
          rv[j] += (kr * (hv[j] * D.roll - rl[j]) - dr * rv[j]) * h; rl[j] = u.clamp(rl[j] + rv[j] * h, -0.4, 0.4);
        }
      }
      u.sky([[0, D.sky[0]], [0.55, D.sky[1]]]);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.mix(D.sea, D.air, 0.6), D.sea]);   // the sea is paler at the horizon too
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (j = 0; j < nb; j++) {
        var b = bergs[j], z = b.z;
        if (j === D.perRow) {                                            // after the far row: the mist band lies over it
          u.ctx.fillStyle = u.lin(0, HY - u.H * 0.06, 0, HY + u.H * 0.1, [[0, u.rgba(D.mist, 0)], [0.5, u.rgba(D.mist, 0.7)], [1, u.rgba(D.mist, 0)]]);
          u.ctx.fillRect(0, HY - u.H * 0.06, u.W, u.H * 0.16);
        }
        var size = u.W * (0.03 + z * 0.09) * b.s;
        var y = HY + z * z * u.H * 0.32 + hy[j];                         // the still line plus the spring's heave
        var x = b.x * u.W + cam * (0.1 + z * 0.5) * u.W * 0.5, pts = [], k;
        var cs = Math.cos(rl[j]), sn = Math.sin(rl[j]);                  // the roll: the lump turns about its waterline
        for (k = 0; k < b.pts.length; k++) {
          var px = b.pts[k][0] * size, py = b.pts[k][1] * size;
          pts.push([x + px * cs - py * sn, y - (px * sn + py * cs) * 0.3]);   // a squashed, flipped reflection first
        }
        u.poly(pts, u.rgba(u.shade(D.ice, -0.5), 0.35));
        for (k = 0; k < b.pts.length; k++) {
          var qx = b.pts[k][0] * size, qy = b.pts[k][1] * size;
          pts[k] = [x + qx * cs - qy * sn, y + qx * sn + qy * cs];
        }
        u.poly(pts, u.fog(D.ice, (1 - z) * 0.8, D.air));
      }
      u.label("z does three jobs at once — size, colour toward the air, and k: y'' = k·(swell − y) − damp·y', stiffer near — far things are slow", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }               // click = pan; near rows slide most
  };
});

def("K", "Knoll", "far", "rolling hills, each a gradient-filled sine, warm green near and blue-grey far — the sheep shrink with their hills, and amble: each picks a spot, walks there, and stands; press pans the camera", function make(u) {
  var D = { sky: ["#7AAAE0", "#DDE8F0"], grass: "#4A8A3A", air: "#B8C8DC", sheep: "#F5F2E8",
            hills: 6, flock: 5, step: 3, seed: 33,                        // step: how often the curve is sampled, in px
            roam: 8,                 // how far from home a sheep will pick its next spot, px on the nearest hill — the far hills shrink it
            pace: 2.0,               // a sheep's spring toward its spot: √k, rad/s — a slow amble
            damp: 0.6,               // as a fraction of critical: under 1, so a sheep overshoots its spot by a step and shuffles back
            pick: 3 };               // seconds between one sheep changing its mind, give or take half
  var R = u.rng(D.seed), hills = [];
  for (var j = 0; j < D.hills; j++) {                                    // j = 0 is the farthest hill
    var h = { base: 0.38 + j * 0.1, amp: 0.03 + j * 0.012, f: 0.8 + R() * 1.2, ph: R() * 9,
              depth: D.hills > 1 ? 1 - j / (D.hills - 1) : 0, sheep: [] };
    for (var s = 0; s < D.flock; s++) h.sheep.push([R(), 0, 0, 0, R() * D.pick]);   // home (along the hill), offset px, velocity, the spot it picked, seconds until it picks again
    hills.push(h);
  }
  var cam = 0, aim = 0;
  function top(h, x) { return u.H * (h.base - h.amp * (1 + Math.sin((x / u.W) * h.f * u.TAU + h.ph))); }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      // a sheep has a spot it has decided to stand on — a random step from
      // home, re-picked every few seconds — and walks there on a damped
      // spring: it ambles, overshoots by a step (damping under critical),
      // shuffles back, and stands until it changes its mind. the step shrinks
      // with the hill's depth, so the far flock barely stirs: wander is a
      // depth cue too, and now it is a walk, not a sine.
      var kk = D.pace * D.pace, dd = D.damp * 2 * D.pace, sub = Math.max(1, Math.ceil(dt * 50)), hh = dt / sub;   // substeps of ≤ 0.02 s
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]]]);
      for (var j = 0; j < hills.length; j++) {
        var h = hills[j], near = 1 - h.depth, shift = cam * near * u.W * 0.3;   // parallax by depth
        var c = u.fog(D.grass, h.depth * 0.85, D.air);
        u.ctx.fillStyle = u.lin(0, u.H * (h.base - h.amp * 2), 0, u.H * (h.base + 0.1), [u.shade(c, 0.2), u.shade(c, -0.25)]);   // lit at the crest, dark in the fold
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += D.step) { var y = top(h, x + shift); u.ctx.lineTo(x, y); u.ctx.lineTo(x + D.step, y); }
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
        for (var s = 0; s < h.sheep.length; s++) {                       // sheep stand on the curve, so they inherit its depth
          var sh = h.sheep[s];
          sh[4] -= dt;
          if (sh[4] <= 0) { sh[4] = D.pick * (0.5 + R()); sh[3] = (R() - 0.5) * 2 * D.roam * near; }   // a new spot: a step from home, shorter on far hills
          for (var q = 0; q < sub; q++) { sh[2] += (kk * (sh[3] - sh[1]) - dd * sh[2]) * hh; sh[1] = u.clamp(sh[1] + sh[2] * hh, -D.roam * 2, D.roam * 2); }
          var sx = sh[0] * u.W * 1.2 - u.W * 0.1 + sh[1] - shift, r = 0.8 + near * 2.4;
          u.dot(sx, top(h, sx + shift) - r * 0.5, r, u.fog(D.sheep, h.depth * 0.7, D.air));
        }
      }
      u.label("a sheep is a dot with a depth: radius, colour, and how far it roams all shrink with the hill — x'' = k·(spot − x) − damp·x'", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }               // click = pan the camera
  };
});

def("M", "Mesa", "far", "flat-topped rock stacks in rows that bunch toward the horizon — smaller, paler, closer together — shadows only at the near feet; press moves the sun", function make(u) {
  var D = { sky: ["#5A8AD0", "#F2D9B0"], rock: "#B0603A", sand: "#D8A870", air: "#E8CDB0",
            rows: 6, perRow: 3, sunX: 0.1, seed: 17 };
  var R = u.rng(D.seed), HY = u.H * 0.48, mesas = [];
  for (var r = 0; r < D.rows; r++) {
    var p = (r + 1) / D.rows;                                            // 0 far … 1 near (rows go far → near, painter's order)
    for (var i = 0; i < D.perRow; i++)
      mesas.push({ p: p, x: (i + 0.2 + R() * 0.6) / D.perRow + (R() - 0.5) * 0.1, w: 0.7 + R() * 0.6, h: 0.6 + R() * 0.8 });
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.48, D.sky[1]]]);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.fog(D.sand, 0.8, D.air), D.sand]);   // even the flat ground fogs toward the horizon
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      var sun = D.sunX < 0.5 ? 1 : -1;                                   // +1: lit from the left
      for (var j = 0; j < mesas.length; j++) {
        var m = mesas[j], p = m.p, y = HY + p * p * u.H * 0.48;          // p²: rows bunch up near the horizon
        var s = 0.12 + p * 0.88, w = u.W * 0.11 * s * m.w, h = u.H * 0.14 * s * m.h, x = m.x * u.W;
        var c = u.fog(D.rock, (1 - p) * 0.9, D.air);
        if (p > 0.5) u.shadow(x + sun * w * 1.1, y - h * 0.04, w * 1.4, h * 0.2, 0.35 * (p - 0.5) * 2);   // a long shadow: only the near rows earn one
        u.poly([[x - w, y], [x - w * 0.7, y - h], [x, y - h], [x, y]], u.shade(c, sun > 0 ? 0.12 : -0.3));   // lit half
        u.poly([[x, y], [x, y - h], [x + w * 0.7, y - h], [x + w, y]], u.shade(c, sun > 0 ? -0.3 : 0.12));   // shadow half
      }
      u.label("horizon + p²: the rows squeeze together as they recede, and the far ones lose their shadows to the air", u.W / 2, u.H - 8, "rgba(40,20,10,0.65)", "center");
    },
    press: function (x, y) { D.sunX = x / u.W; }                        // click = move the sun to that side
  };
});

def("P", "Pines", "far", "rows of triangle trees: each row back is smaller, packed tighter, and mixed further into the fog — press moves the camera and the rows slide by depth", function make(u) {
  var D = { sky: ["#8AA8C8", "#E4ECF2"], pine: "#16302A", air: "#D0DCE6", rows: 6, seed: 4 };
  var R = u.rng(D.seed), rows = [], HY = u.H * 0.42;
  for (var r = 0; r < D.rows; r++) {
    var p = D.rows > 1 ? r / (D.rows - 1) : 1, row = { p: p, trees: [] };   // 0 far … 1 near
    var gap = u.W * (0.035 + p * p * 0.11), n = Math.ceil(u.W * 1.6 / gap);   // near rows: wider gaps, fewer trees
    for (var i = 0; i < n; i++) row.trees.push([i * gap + (R() - 0.5) * gap * 0.6, 0.7 + R() * 0.6]);   // x, and a height wobble
    row.period = n * gap;
    rows.push(row);
  }
  var cam = 0, aim = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      u.sky([[0, D.sky[0]], [0.5, D.sky[1]]]);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [D.air, u.shade(D.air, -0.2)]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (var r = 0; r < rows.length; r++) {
        var row = rows[r], p = row.p, y = HY + p * p * u.H * 0.55;        // p²: the ground lines bunch toward the horizon
        var hgt = u.H * (0.03 + p * p * 0.42), half = hgt * 0.32;
        var c = u.fog(D.pine, (1 - p) * 0.9, D.air), shift = cam * p * u.W * 0.35;   // near rows slide farthest
        u.ctx.fillStyle = u.lin(0, y - 4, 0, y + 8, [[0, u.rgba(D.air, 0)], [1, u.rgba(D.air, 0.5 * (1 - p))]]);   // a breath of ground haze under each row
        u.ctx.fillRect(0, y - 4, u.W, 12);
        for (var i = 0; i < row.trees.length; i++) {
          var x = ((row.trees[i][0] + shift) % row.period + row.period) % row.period - u.W * 0.3, h = hgt * row.trees[i][1];
          u.poly([[x - half, y], [x, y - h], [x + half, y]], c);
        }
      }
      u.label("size, spacing, colour, and parallax all come from the row's p — four cues, one number", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }               // click = pan; the near row runs, the far row crawls
  };
});

def("Q", "Quay", "far", "harbour posts marching to a vanishing point: spacing shrinks as p², heights shrink with it, colour fogs, ripples only near; press moves the point", function make(u) {
  var D = { sky: ["#3A4A7A", "#E8B890"], water: "#22304A", post: "#3A2A1E", air: "#C8A898",
            posts: 14, jitter: 0, vpX: 0.62 };                            // jitter: 0 = still posts
  var HY = u.H * 0.45;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.45, D.sky[1]]]);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.mix(D.sky[1], D.water, 0.4), D.water]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      u.soft(u.W * D.vpX, HY, u.W * 0.25, "#FFD9A0", 0.35);              // the sun sits on the vanishing point
      for (var i = 0; i < D.posts; i++) {
        var p = D.posts > 1 ? i / (D.posts - 1) : 1, q = p * p;          // p: 0 far … 1 near; q bunches the far posts together
        var x = u.lerp(u.W * D.vpX, u.W * 0.12, q) + Math.sin(t * 40 + i * 7) * D.jitter * 6 * q, y = HY + q * u.H * 0.55;
        var h = 2 + q * u.H * 0.36, w = 1 + q * 7, c = u.fog(D.post, (1 - q) * 0.9, D.air);
        u.ctx.fillStyle = u.rgba(c, 0.35); u.ctx.fillRect(x - w / 2, y, w, h * 0.5);   // reflection: a faint stub straight down
        u.cyl(x, y, w, h, c, -0.4);
        if (q > 0.3) for (var k = 0; k < 3; k++) {                       // ripples: rings born at the foot, fading as they grow
          var g = (t * 0.5 + k / 3 + i * 0.13) % 1;
          u.ctx.strokeStyle = u.rgba("#FFFFFF", (1 - g) * 0.35 * q); u.ctx.lineWidth = 1;
          u.ctx.beginPath(); u.ctx.ellipse(x, y + 1, (0.5 + g * 3) * w, (0.5 + g * 3) * w * 0.3, 0, 0, u.TAU); u.ctx.stroke();
        }
      }
      u.label("horizon + p²: the same step in p is a smaller step on screen the farther back you go — perspective in one line", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.vpX = x / u.W; }                         // click = move the vanishing point
  };
});

def("R", "Ridgeline", "far", "one ridge drawn four times, deeper each time, contrast falling — near is nearly black, far is nearly sky; press turns the fog off and the depth goes", function make(u) {
  var D = { sky: ["#6A88B8", "#E0E8F0"], rock: "#14161E", air: "#C4D2E0", copies: 4, seed: 2 };
  var R = u.rng(D.seed), f = [1.1 + R() * 0.8, 2.7 + R() * 1.5, 7 + R() * 4], ph = [R() * 9, R() * 9, R() * 9];
  var fogOn = true;
  function ridge(x) {                                                    // one shape, unit height, reused for every copy
    var k = x / u.W;
    return 0.5 * Math.sin(k * f[0] * u.TAU + ph[0]) + 0.35 * Math.abs(Math.sin(k * f[1] * u.TAU + ph[1])) + 0.15 * Math.sin(k * f[2] * u.TAU + ph[2]);
  }
  return {
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]]]);
      for (var j = 0; j < D.copies; j++) {                               // j = 0 farthest
        var depth = D.copies > 1 ? 1 - j / (D.copies - 1) : 0, base = 0.45 + j * 0.12, amp = 0.09 + j * 0.03;
        var shift = j * u.W * 0.23 + t * 2 * (1 - depth);                // the same shape slid along — and creeping, faster when near
        u.ctx.fillStyle = fogOn ? u.fog(D.rock, depth * 0.9, D.air) : D.rock;   // the whole lesson is this one line
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += 4) u.ctx.lineTo(x, u.H * (base - amp * ridge(x + shift)));
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      u.label(fogOn ? "fog on: four ridges, each a step farther into the air — press to switch it off"
                    : "fog off: the same four shapes read as ONE black cut-out — the depth WAS the contrast", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { fogOn = !fogOn; }                          // click = toggle the air
  };
});

def("S", "Skyline", "far", "a city in three planes: the far one pale, flat, and slow; the near one dark with lit windows — colour, speed, and detail from one z; press pans", function make(u) {
  var D = { sky: ["#1A1E4A", "#7A4A7A", "#F5A070"], tower: "#1A1828", air: "#9A7090", window: "#F5C169",
            perPlane: 12, maxH: 0.55, seed: 44 };
  var R = u.rng(D.seed), B = [], GY = u.H * 0.88, period = u.W * 1.5;
  for (var pl = 0; pl < 3; pl++)                                         // pl = 0 far … 2 near
    for (var i = 0; i < D.perPlane; i++) {
      var z = pl / 2, w = u.W * (0.035 + z * 0.05) * (0.6 + R() * 0.8), h = u.H * D.maxH * (0.3 + z * 0.7) * (0.5 + R() * 0.5);
      var b = { z: z, x: (i + R() * 0.7) / D.perPlane * period, w: w, h: h, win: [] };
      if (z === 1)                                                       // only the near plane is close enough to show windows
        for (var wx = 3; wx < w - 3; wx += u.W * 0.014) for (var wy = 4; wy < h - 3; wy += u.H * 0.03)
          if (R() < 0.55) b.win.push([wx, wy]);
      B.push(b);
    }
  var cam = 0, aim = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      u.sky([[0, D.sky[0]], [0.55, D.sky[1]], [0.88, D.sky[2]]]);
      for (var i = 0; i < B.length; i++) {
        var b = B[i], z = b.z, base = GY - (1 - z) * u.H * 0.05;         // far planes stand a little higher: nearer the horizon
        var x = ((b.x + cam * (0.1 + z * 0.4) * u.W + t * (1 + z * 6)) % period + period) % period - u.W * 0.25;   // the near plane slides six times faster
        u.ctx.fillStyle = u.fog(D.tower, (1 - z) * 0.85, D.air);
        u.ctx.fillRect(x, base - b.h, b.w, b.h);
        for (var k = 0; k < b.win.length; k++) {
          u.ctx.fillStyle = u.rgba(D.window, 0.55 + 0.4 * Math.sin(t * 0.8 + k * 1.7 + i));   // each window on its own dimmer
          u.ctx.fillRect(x + b.win[k][0], base - b.h + b.win[k][1], u.W * 0.007, u.H * 0.014);
        }
      }
      u.ground(GY, "#0A0A14");
      u.label("three planes, one z: colour toward the air, speed, and detail all fall off together — windows are a near-only luxury", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }               // click = pan the camera
  };
});

def("V", "Valley", "far", "two slopes meet in a V, five pairs deep: mist pools in the bottom as a soft band and the far end is the brightest thing; press sets the mist level", function make(u) {
  var D = { sky: ["#8AA8D0", "#F5EAD8"], hill: "#243E30", air: "#D8DAD4", mist: "#F0F0F4",
            pairs: 5, mistY: 0.62, seed: 6 };                             // mistY: where the mist's surface sits
  var R = u.rng(D.seed), P = [];
  for (var j = 0; j < D.pairs; j++) {
    var p = D.pairs > 1 ? j / (D.pairs - 1) : 1;                         // 0 far … 1 near
    P.push({ p: p, edgeY: 0.36 * (1 - Math.pow(p, 1.5)), notchY: 0.55 + p * 0.5,   // near arms start higher and dive deeper
             bump: 0.02 + R() * 0.06, at: 0.3 + R() * 0.3 });            // a shoulder on the slope, and where it sits
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.55, D.sky[1]]]);
      u.soft(u.W / 2, u.H * 0.52, u.W * 0.3, "#FFF8E8", 0.7);            // the far end: the brightest thing in the picture
      var mistAt = Math.floor(D.pairs * 0.6);
      for (var j = 0; j < P.length; j++) {
        var s = P[j], c = u.fog(D.hill, (1 - s.p) * 0.9, D.air);
        if (j === mistAt) {                                              // mist pools in the bottom, between the far and the near pairs
          var my = u.H * D.mistY;
          u.ctx.fillStyle = u.lin(0, my - u.H * 0.16, 0, u.H, [[0, u.rgba(D.mist, 0)], [0.45, u.rgba(D.mist, 0.8)], [1, u.rgba(D.mist, 0.4)]]);
          u.ctx.fillRect(0, my - u.H * 0.16, u.W, u.H);
        }
        for (var side = 0; side < 2; side++) {                           // the same slope, mirrored about the centre
          var m = side ? -1 : 1, o = side ? u.W : 0;
          u.poly([[o - m * 2, u.H * s.edgeY], [o + m * s.at * u.W * 0.5, u.H * (u.lerp(s.edgeY, s.notchY, s.at) - s.bump)],
                  [o + m * (u.W * 0.5 + 1), u.H * s.notchY], [o + m * (u.W * 0.5 + 1), u.H + 2], [o - m * 2, u.H + 2]], c);
        }
      }
      u.label("mist is fog that pooled: a gradient band the near slopes rise out of and the far ones sink into", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.mistY = u.clamp(y / u.H, 0.45, 0.9); }  // click = set the mist's surface by y
  };
});

def("W", "Woodland", "far", "trunks at random depths, sorted far to near: the near ones wide, dark, and sharp; the far ones thin and pale behind a low ground fog; press pans", function make(u) {
  var D = { sky: ["#1E3A2E", "#8AA890"], bark: "#2A1E16", air: "#9AB0A0", fog: "#C8D8CC",
            trees: 28, tall: 1.1, cap: null, seed: 8 };                  // cap: a colour turns every trunk into a mushroom
  var R = u.rng(D.seed), T = [], HY = u.H * 0.4;
  for (var i = 0; i < D.trees; i++) T.push({ x: R(), z: R() });
  T.sort(function (a, b) { return a.z - b.z; });                          // far first — painter's order
  var cam = 0, aim = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      u.sky([[0, D.sky[0]], [0.55, D.sky[1]], [1, u.shade(D.sky[1], -0.3)]]);
      var fogged = false;
      for (var i = 0; i < T.length; i++) {
        var tr = T[i], z = tr.z;                                          // 0 far … 1 near
        if (!fogged && z > 0.45) {                                        // the ground fog lies between the far and the near trunks
          fogged = true;
          u.ctx.fillStyle = u.lin(0, HY - u.H * 0.05, 0, u.H, [[0, u.rgba(D.fog, 0)], [0.35, u.rgba(D.fog, 0.75)], [1, u.rgba(D.fog, 0.3)]]);
          u.ctx.fillRect(0, HY - u.H * 0.05, u.W, u.H);
        }
        var y = HY + z * z * u.H * 0.62, h = u.H * (0.2 + z * z * D.tall), w = 1.5 + z * z * u.W * 0.07;
        var x = (tr.x - 0.5) * u.W * 1.3 + u.W / 2 + cam * (0.05 + z * 0.4) * u.W;   // parallax: near trunks slide most
        var c = u.fog(D.bark, (1 - z) * 0.9, D.air);
        u.cyl(x, y, w, h, c, -0.4);
        if (D.cap) u.sphere(x, y - h, w * 1.6 + 3, u.fog(D.cap, (1 - z) * 0.9, D.air), -0.5, -0.6);
      }
      u.label("sort by z, draw far first: width, darkness, and sharpness all grow toward you — the fog sits where z is small", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }               // click = pan the camera
  };
});

/* ---- the rhymes: same pictures, two or three dials moved ---- */

rhymeOf("Alps", "Neon ridges", "the same six ridges under a black sky, fogging toward cyan instead of blue — a synth poster from one changed colour", function make(u) {
  // rhyme of Alps: dials moved — sky/rock/air palette, layers 6 → 4, drift 0.15 → 0.6
  var D = { sky: ["#050515", "#160E3A"], rock: "#2A0A4A", air: "#3AF0E0",
            layers: 4, jag: 1.0, drift: 0.6, seed: 7 };
  var R = u.rng(D.seed), L = [];
  for (var j = 0; j < D.layers; j++) {
    var depth = D.layers > 1 ? 1 - j / (D.layers - 1) : 0;
    L.push({ depth: depth, base: 0.36 + j * 0.085, amp: (0.05 + j * 0.018) * D.jag,
             f: [1.2 + R() * 1.4, 2.6 + R() * 2.4, 6 + R() * 5], ph: [R() * 9, R() * 9, R() * 9] });
  }
  var cam = 0, aim = 0;
  function ridge(l, x) {
    var k = x / u.W;
    return u.H * (l.base - l.amp * (0.55 * Math.sin(k * l.f[0] * u.TAU + l.ph[0]) + 0.35 * Math.abs(Math.sin(k * l.f[1] * u.TAU + l.ph[1])) + 0.1 * Math.sin(k * l.f[2] * u.TAU + l.ph[2])));
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      u.sky([[0, D.sky[0]], [0.65, D.sky[1]]]);
      for (var j = 0; j < L.length; j++) {
        var l = L[j], near = 1 - l.depth;
        var shift = (cam * 0.35 + t * D.drift * 0.03) * near * u.W;
        u.ctx.fillStyle = u.fog(D.rock, l.depth * 0.92, D.air);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += 4) u.ctx.lineTo(x, ridge(l, x + shift));
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      u.label("the air can be any colour — fog toward cyan and the far ridges glow; the rule didn't change, the air did", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Canyon", "Ice canyon", "the same walls in four blues, thicker air — a minimalist print where the far gap is almost paper-white", function make(u) {
  // rhyme of Canyon: dials moved — sky/rock/air palette, dust 1.0 → 1.5, pairs 6 → 4
  var D = { sky: ["#3A5A9A", "#EEF4FA"], rock: "#3A5A8A", air: "#E8F0F8", dust: 1.5, pairs: 4, seed: 5 };
  var R = u.rng(D.seed), walls = [], HY = u.H * 0.6;
  for (var j = 0; j < D.pairs; j++) {
    var p = D.pairs > 1 ? j / (D.pairs - 1) : 1;
    walls.push({ p: p, inner: 0.05 + p * p * 0.43, top: 0.5 - p * 0.8, bot: 0.6 + p * p * 0.5,
                 kink: (R() - 0.5) * 0.06, ledge: 0.25 + R() * 0.45 });
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.58, D.sky[1]]]);
      u.soft(u.W / 2, HY, u.W * 0.28, "#FFFFFF", 0.7);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.fog(D.rock, 0.7, D.air), u.shade(D.rock, -0.5)]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (var j = 0; j < walls.length; j++) {
        var w = walls[j], c = u.fog(u.shade(D.rock, -w.p * 0.55), (1 - w.p) * 0.85 * D.dust, D.air);
        for (var side = -1; side <= 1; side += 2) {
          var xi = u.W * (0.5 + side * w.inner), xo = u.W * (0.5 + side * 0.6), top = u.H * w.top, bot = u.H * w.bot;
          u.poly([[xo, top], [xi + side * w.kink * u.W, top], [xi, top + (bot - top) * w.ledge], [xi + side * w.kink * u.W * 0.5, bot], [xo, bot]], c);
        }
        u.ctx.fillStyle = u.lin(0, u.H * 0.2, 0, u.H * w.bot, [[0, u.rgba(D.air, 0)], [1, u.rgba(D.air, 0.22 * D.dust * (1 - w.p))]]);
        u.ctx.fillRect(0, u.H * 0.2, u.W, u.H * w.bot - u.H * 0.2);
      }
      u.label("four pairs instead of six: fewer, bigger steps in contrast — the recession reads as a print, not a photo", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.dust = 0.2 + (x / u.W) * 1.6; }
  };
});

rhymeOf("Dunes", "Moon dunes", "the same dunes in greyscale under a black sky — no air, so the far ones fade DOWN into the dark instead of up into peach", function make(u) {
  // rhyme of Dunes: dials moved — palette to greys, air to near-black, dunes 7 → 4
  var D = { sky: ["#030306", "#16161E"], sand: "#A8A8A8", shade: "#1A1A1E", air: "#1E1E26",
            dunes: 4, sunX: 0.15, seed: 9 };
  var R = u.rng(D.seed), dunes = [];
  for (var j = 0; j < D.dunes; j++) dunes.push({ base: 0.45 + j * 0.07, amp: 0.05 + j * 0.02, f: 0.7 + R() * 1.0, ph: R() * 9 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.5, D.sky[1]]]);
      var fromLeft = D.sunX < 0.5;
      for (var j = 0; j < dunes.length; j++) {
        var d = dunes[j], depth = dunes.length > 1 ? 1 - j / (dunes.length - 1) : 0;
        var lit = u.fog(u.shade(D.sand, 0.18), depth * 0.85, D.air), dark = u.fog(D.shade, depth * 0.85, D.air);
        var crest = 0.3 + 0.1 * Math.sin(t * 0.3 + j * 1.3);
        u.ctx.fillStyle = u.lin(fromLeft ? 0 : u.W, 0, fromLeft ? u.W : 0, 0, [[0, lit], [crest, u.shade(lit, 0.1)], [1, dark]]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += 4) {
          var k = x / u.W, bump = Math.pow(0.5 + 0.5 * Math.sin(k * d.f * u.TAU + d.ph), 1.6);
          u.ctx.lineTo(x, u.H * (d.base - d.amp * bump));
        }
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      u.label("'fog' really means 'toward the background' — set the air to black and distance darkens instead of paling", u.W / 2, u.H - 8, "rgba(10,10,14,0.7)", "center");
    },
    press: function (x, y) { D.sunX = x / u.W; }
  };
});

rhymeOf("Fjord", "Rose fjord", "the same fjord at a pink evening — rose air, plum rock, wine-dark water — and a breeze already on it", function make(u) {
  // rhyme of Fjord: dials moved — sky/rock/air/water palette, wind 0.3 → 1.2
  var D = { sky: ["#E8A0B8", "#FFE4D0"], rock: "#5A3A5A", air: "#F0C8D0", water: "#4A2A48",
            layers: 4, wind: 1.2, seed: 12 };
  var R = u.rng(D.seed), L = [], WL = u.H * 0.6;
  for (var j = 0; j < D.layers; j++)
    L.push({ base: 0.5 + j * 0.03, amp: 0.1 + j * 0.06, f: [1 + R() * 1.2, 3 + R() * 3], ph: [R() * 9, R() * 9],
             depth: D.layers > 1 ? 1 - j / (D.layers - 1) : 0 });
  function ridge(l, x) {
    var k = x / u.W;
    return u.H * (l.base - l.amp * (0.6 * Math.abs(Math.sin(k * l.f[0] * u.TAU + l.ph[0])) + 0.4 * Math.abs(Math.sin(k * l.f[1] * u.TAU + l.ph[1]))));
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]]]);
      u.ctx.fillStyle = u.lin(0, WL, 0, u.H, [u.mix(D.sky[1], D.water, 0.3), D.water]);
      u.ctx.fillRect(0, WL, u.W, u.H - WL);
      for (var j = 0; j < L.length; j++) {
        var l = L[j], c = u.fog(D.rock, l.depth * 0.9, D.air), x;
        u.ctx.fillStyle = c;
        u.ctx.beginPath(); u.ctx.moveTo(0, WL);
        for (x = 0; x <= u.W; x += 4) u.ctx.lineTo(x, ridge(l, x));
        u.ctx.lineTo(u.W, WL); u.ctx.closePath(); u.ctx.fill();
        u.ctx.fillStyle = u.shade(c, -0.25);
        u.ctx.beginPath(); u.ctx.moveTo(-10, WL);
        for (x = 0; x <= u.W; x += 4) {
          var y = 2 * WL - ridge(l, x), wob = Math.sin(y * 0.25 + t * 2.5) * D.wind * 3 * ((y - WL) / u.H) * 10;
          u.ctx.lineTo(x + wob, y);
        }
        u.ctx.lineTo(u.W + 10, WL); u.ctx.closePath(); u.ctx.fill();
      }
      u.ctx.fillStyle = u.lin(0, WL, 0, u.H, [[0, u.rgba(D.water, 0.1)], [1, u.rgba(D.water, 0.9)]]);
      u.ctx.fillRect(0, WL, u.W, u.H - WL);
      u.label("warm the air and the fjord is an evening — the reflection follows for free, it is the same mask", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = 0.1 + (x / u.W) * 2.5; }
  };
});

rhymeOf("Icebergs", "Lava islands", "the same three rows, values flipped — black rock on a bright lava sea, smoke for mist, seven to a row", function make(u) {
  // rhyme of Icebergs: dials moved — ice/sea/air/mist palette inverted, perRow 5 → 7
  var D = { sky: ["#1A0808", "#5A1A10"], ice: "#241816", sea: "#F5601A", air: "#8A3020", mist: "#FFB060",
            perRow: 7, rows: 3, seed: 21,
            swell: 2.0, damp: 0.3, roll: 0.03 };                          // the same springs: heave rate, damping of critical, tilt per px/s
  var R = u.rng(D.seed), bergs = [], HY = u.H * 0.55;
  for (var r = 0; r < D.rows; r++)
    for (var i = 0; i < D.perRow; i++) {
      var z = D.rows > 1 ? r / (D.rows - 1) : 1, pts = [], n = 5 + Math.floor(R() * 3);
      for (var k = 0; k < n; k++) pts.push([(k / (n - 1)) * 2 - 1, -(0.2 + R() * 0.8) * Math.sin(k / (n - 1) * Math.PI)]);
      bergs.push({ z: z, x: (i + R() * 0.8) / D.perRow, pts: pts, ph: R() * 9, s: 0.5 + R() * 0.7 });
    }
  var nb = bergs.length, hy = new Float32Array(nb), hv = new Float32Array(nb), rl = new Float32Array(nb), rv = new Float32Array(nb);
  for (var q = 0; q < nb; q++) hy[q] = Math.sin(bergs[q].ph) * (0.5 + bergs[q].z * 2.5);
  var cam = 0, aim = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, j, s;
      var kr = 16, dr = 0.4 * 2 * Math.sqrt(kr);
      for (j = 0; j < nb; j++) {
        var bg = bergs[j], zz = bg.z, w0 = D.swell * (0.5 + zz), kk = w0 * w0, dd = D.damp * 2 * w0;
        var rest = Math.sin(t * (0.4 + zz * 0.9) + bg.ph) * (0.5 + zz * 2.5);
        for (s = 0; s < sub; s++) {
          hv[j] += (kk * (rest - hy[j]) - dd * hv[j]) * h; hy[j] = u.clamp(hy[j] + hv[j] * h, -u.H * 0.1, u.H * 0.1);
          rv[j] += (kr * (hv[j] * D.roll - rl[j]) - dr * rv[j]) * h; rl[j] = u.clamp(rl[j] + rv[j] * h, -0.4, 0.4);
        }
      }
      u.sky([[0, D.sky[0]], [0.55, D.sky[1]]]);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.mix(D.sea, D.air, 0.6), D.sea]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (j = 0; j < nb; j++) {
        var b = bergs[j], z = b.z;
        if (j === D.perRow) {
          u.ctx.fillStyle = u.lin(0, HY - u.H * 0.06, 0, HY + u.H * 0.1, [[0, u.rgba(D.mist, 0)], [0.5, u.rgba(D.mist, 0.7)], [1, u.rgba(D.mist, 0)]]);
          u.ctx.fillRect(0, HY - u.H * 0.06, u.W, u.H * 0.16);
        }
        var size = u.W * (0.03 + z * 0.09) * b.s;
        var y = HY + z * z * u.H * 0.32 + hy[j];
        var x = b.x * u.W + cam * (0.1 + z * 0.5) * u.W * 0.5, pts = [], k;
        var cs = Math.cos(rl[j]), sn = Math.sin(rl[j]);
        for (k = 0; k < b.pts.length; k++) {
          var px = b.pts[k][0] * size, py = b.pts[k][1] * size;
          pts.push([x + px * cs - py * sn, y - (px * sn + py * cs) * 0.3]);
        }
        u.poly(pts, u.rgba(u.shade(D.ice, -0.5), 0.35));
        for (k = 0; k < b.pts.length; k++) {
          var qx = b.pts[k][0] * size, qy = b.pts[k][1] * size;
          pts[k] = [x + qx * cs - qy * sn, y + qx * sn + qy * cs];
        }
        u.poly(pts, u.fog(D.ice, (1 - z) * 0.8, D.air));
      }
      u.label("dark on bright instead of bright on dark — z still runs the show: size, smoke, and speed", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Knoll", "Pixel knoll", "the same hills sampled every 22 px — three chunky staircases in arcade green, two sheep each", function make(u) {
  // rhyme of Knoll: dials moved — step 3 → 22, hills 6 → 3, flock 5 → 2, palette to arcade
  var D = { sky: ["#3A78F0", "#9AE0FF"], grass: "#3AC83A", air: "#7AB8F0", sheep: "#FFFFFF",
            hills: 3, flock: 2, step: 22, seed: 33,
            roam: 8, pace: 2.0, damp: 0.6, pick: 3 };                    // the same amble: roam px, spring rate, damping of critical, seconds between spots
  var R = u.rng(D.seed), hills = [];
  for (var j = 0; j < D.hills; j++) {
    var h = { base: 0.38 + j * 0.1, amp: 0.03 + j * 0.012, f: 0.8 + R() * 1.2, ph: R() * 9,
              depth: D.hills > 1 ? 1 - j / (D.hills - 1) : 0, sheep: [] };
    for (var s = 0; s < D.flock; s++) h.sheep.push([R(), 0, 0, 0, R() * D.pick]);
    hills.push(h);
  }
  var cam = 0, aim = 0;
  function top(h, x) { return u.H * (h.base - h.amp * (1 + Math.sin((x / u.W) * h.f * u.TAU + h.ph))); }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      var kk = D.pace * D.pace, dd = D.damp * 2 * D.pace, sub = Math.max(1, Math.ceil(dt * 50)), hh = dt / sub;
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]]]);
      for (var j = 0; j < hills.length; j++) {
        var h = hills[j], near = 1 - h.depth, shift = cam * near * u.W * 0.3;
        var c = u.fog(D.grass, h.depth * 0.85, D.air);
        u.ctx.fillStyle = u.lin(0, u.H * (h.base - h.amp * 2), 0, u.H * (h.base + 0.1), [u.shade(c, 0.2), u.shade(c, -0.25)]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += D.step) { var y = top(h, x + shift); u.ctx.lineTo(x, y); u.ctx.lineTo(x + D.step, y); }
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
        for (var s = 0; s < h.sheep.length; s++) {
          var sh = h.sheep[s];
          sh[4] -= dt;
          if (sh[4] <= 0) { sh[4] = D.pick * (0.5 + R()); sh[3] = (R() - 0.5) * 2 * D.roam * near; }
          for (var q = 0; q < sub; q++) { sh[2] += (kk * (sh[3] - sh[1]) - dd * sh[2]) * hh; sh[1] = u.clamp(sh[1] + sh[2] * hh, -D.roam * 2, D.roam * 2); }
          var sx = sh[0] * u.W * 1.2 - u.W * 0.1 + sh[1] - shift, r = 0.8 + near * 2.4;
          u.dot(sx, top(h, sx + shift) - r * 0.5, r, u.fog(D.sheep, h.depth * 0.7, D.air));
        }
      }
      u.label("sample the curve every 22 px and the hill is a staircase — chunkier steps, same fog toward the sky", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Mesa", "Gumdrop mesa", "the same rock stacks in candy pink on a sugar plain — four rows, two to a row, the far ones melting into pink air", function make(u) {
  // rhyme of Mesa: dials moved — sky/rock/sand/air palette, rows 6 → 4, perRow 3 → 2
  var D = { sky: ["#8AD0FF", "#FFE8F0"], rock: "#F06AA8", sand: "#F5D0E8", air: "#FFE8F0",
            rows: 4, perRow: 2, sunX: 0.1, seed: 17 };
  var R = u.rng(D.seed), HY = u.H * 0.48, mesas = [];
  for (var r = 0; r < D.rows; r++) {
    var p = (r + 1) / D.rows;
    for (var i = 0; i < D.perRow; i++)
      mesas.push({ p: p, x: (i + 0.2 + R() * 0.6) / D.perRow + (R() - 0.5) * 0.1, w: 0.7 + R() * 0.6, h: 0.6 + R() * 0.8 });
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.48, D.sky[1]]]);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.fog(D.sand, 0.8, D.air), D.sand]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      var sun = D.sunX < 0.5 ? 1 : -1;
      for (var j = 0; j < mesas.length; j++) {
        var m = mesas[j], p = m.p, y = HY + p * p * u.H * 0.48;
        var s = 0.12 + p * 0.88, w = u.W * 0.11 * s * m.w, h = u.H * 0.14 * s * m.h, x = m.x * u.W;
        var c = u.fog(D.rock, (1 - p) * 0.9, D.air);
        if (p > 0.5) u.shadow(x + sun * w * 1.1, y - h * 0.04, w * 1.4, h * 0.2, 0.35 * (p - 0.5) * 2);
        u.poly([[x - w, y], [x - w * 0.7, y - h], [x, y - h], [x, y]], u.shade(c, sun > 0 ? 0.12 : -0.3));
        u.poly([[x, y], [x, y - h], [x + w * 0.7, y - h], [x + w, y]], u.shade(c, sun > 0 ? -0.3 : 0.12));
      }
      u.label("candy or canyon, the rows still bunch as p² — the palette is a costume, the perspective is the body", u.W / 2, u.H - 8, "rgba(80,20,50,0.6)", "center");
    },
    press: function (x, y) { D.sunX = x / u.W; }
  };
});

rhymeOf("Pines", "Snow pines", "the same rows in snow light — slate trees, near-white air — eight rows deep, and the far ones are simply gone", function make(u) {
  // rhyme of Pines: dials moved — sky/pine/air palette, rows 6 → 8
  var D = { sky: ["#B8C8D8", "#F8FAFC"], pine: "#3A4A5A", air: "#EEF2F6", rows: 8, seed: 4 };
  var R = u.rng(D.seed), rows = [], HY = u.H * 0.42;
  for (var r = 0; r < D.rows; r++) {
    var p = D.rows > 1 ? r / (D.rows - 1) : 1, row = { p: p, trees: [] };
    var gap = u.W * (0.035 + p * p * 0.11), n = Math.ceil(u.W * 1.6 / gap);
    for (var i = 0; i < n; i++) row.trees.push([i * gap + (R() - 0.5) * gap * 0.6, 0.7 + R() * 0.6]);
    row.period = n * gap;
    rows.push(row);
  }
  var cam = 0, aim = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      u.sky([[0, D.sky[0]], [0.5, D.sky[1]]]);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [D.air, u.shade(D.air, -0.2)]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (var r = 0; r < rows.length; r++) {
        var row = rows[r], p = row.p, y = HY + p * p * u.H * 0.55;
        var hgt = u.H * (0.03 + p * p * 0.42), half = hgt * 0.32;
        var c = u.fog(D.pine, (1 - p) * 0.9, D.air), shift = cam * p * u.W * 0.35;
        u.ctx.fillStyle = u.lin(0, y - 4, 0, y + 8, [[0, u.rgba(D.air, 0)], [1, u.rgba(D.air, 0.5 * (1 - p))]]);
        u.ctx.fillRect(0, y - 4, u.W, 12);
        for (var i = 0; i < row.trees.length; i++) {
          var x = ((row.trees[i][0] + shift) % row.period + row.period) % row.period - u.W * 0.3, h = hgt * row.trees[i][1];
          u.poly([[x - half, y], [x, y - h], [x + half, y]], c);
        }
      }
      u.label("brighter air is stronger fog: with near-white air the back rows vanish in three steps instead of six", u.W / 2, u.H - 8, "rgba(30,40,50,0.65)", "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Quay", "Glitch quay", "the same posts in neon on black water, shaking — the jitter is scaled by the same p² as everything else, so the near ones shake most", function make(u) {
  // rhyme of Quay: dials moved — jitter 0 → 1, sky/water/post/air palette to neon
  var D = { sky: ["#0A0A1A", "#2A1050"], water: "#08101A", post: "#20F0D0", air: "#5A2A9A",
            posts: 14, jitter: 1, vpX: 0.62 };
  var HY = u.H * 0.45;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.45, D.sky[1]]]);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.mix(D.sky[1], D.water, 0.4), D.water]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      u.soft(u.W * D.vpX, HY, u.W * 0.25, "#F040C0", 0.35);
      for (var i = 0; i < D.posts; i++) {
        var p = D.posts > 1 ? i / (D.posts - 1) : 1, q = p * p;
        var x = u.lerp(u.W * D.vpX, u.W * 0.12, q) + Math.sin(t * 40 + i * 7) * D.jitter * 6 * q, y = HY + q * u.H * 0.55;
        var h = 2 + q * u.H * 0.36, w = 1 + q * 7, c = u.fog(D.post, (1 - q) * 0.9, D.air);
        u.ctx.fillStyle = u.rgba(c, 0.35); u.ctx.fillRect(x - w / 2, y, w, h * 0.5);
        u.cyl(x, y, w, h, c, -0.4);
        if (q > 0.3) for (var k = 0; k < 3; k++) {
          var g = (t * 0.5 + k / 3 + i * 0.13) % 1;
          u.ctx.strokeStyle = u.rgba("#FFFFFF", (1 - g) * 0.35 * q); u.ctx.lineWidth = 1;
          u.ctx.beginPath(); u.ctx.ellipse(x, y + 1, (0.5 + g * 3) * w, (0.5 + g * 3) * w * 0.3, 0, 0, u.TAU); u.ctx.stroke();
        }
      }
      u.label("even the glitch obeys perspective: shake × p² — far posts barely tremble, near ones rattle", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.vpX = x / u.W; }
  };
});

rhymeOf("Ridgeline", "Acid ridgeline", "the same ridge seven times, violet rock fogging toward lime under a hot-pink sky — the contrast ladder, in a trippy key", function make(u) {
  // rhyme of Ridgeline: dials moved — sky/rock/air palette, copies 4 → 7
  var D = { sky: ["#F0F040", "#FF60C0"], rock: "#2A0A5A", air: "#40FFC0", copies: 7, seed: 2 };
  var R = u.rng(D.seed), f = [1.1 + R() * 0.8, 2.7 + R() * 1.5, 7 + R() * 4], ph = [R() * 9, R() * 9, R() * 9];
  var fogOn = true;
  function ridge(x) {
    var k = x / u.W;
    return 0.5 * Math.sin(k * f[0] * u.TAU + ph[0]) + 0.35 * Math.abs(Math.sin(k * f[1] * u.TAU + ph[1])) + 0.15 * Math.sin(k * f[2] * u.TAU + ph[2]);
  }
  return {
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]]]);
      for (var j = 0; j < D.copies; j++) {
        var depth = D.copies > 1 ? 1 - j / (D.copies - 1) : 0, base = 0.45 + j * 0.07, amp = 0.09 + j * 0.02;
        var shift = j * u.W * 0.23 + t * 2 * (1 - depth);
        u.ctx.fillStyle = fogOn ? u.fog(D.rock, depth * 0.9, D.air) : D.rock;
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += 4) u.ctx.lineTo(x, u.H * (base - amp * ridge(x + shift)));
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      u.label(fogOn ? "seven copies: the contrast steps down one notch per copy — that ladder is the depth, whatever the hues"
                    : "fog off: seven shapes, one violet cut-out — the ladder is gone and so is the distance", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { fogOn = !fogOn; }
  };
});

rhymeOf("Skyline", "Cozy village", "the same three planes, half as many buildings at a third of the height, lit warm — a village at dusk instead of a city", function make(u) {
  // rhyme of Skyline: dials moved — perPlane 12 → 6, maxH 0.55 → 0.2, sky/tower/air/window palette warmed
  var D = { sky: ["#2A2A5A", "#8A5A7A", "#F5B080"], tower: "#3A2A2A", air: "#B08A98", window: "#FFD080",
            perPlane: 6, maxH: 0.2, seed: 44 };
  var R = u.rng(D.seed), B = [], GY = u.H * 0.88, period = u.W * 1.5;
  for (var pl = 0; pl < 3; pl++)
    for (var i = 0; i < D.perPlane; i++) {
      var z = pl / 2, w = u.W * (0.035 + z * 0.05) * (0.6 + R() * 0.8), h = u.H * D.maxH * (0.3 + z * 0.7) * (0.5 + R() * 0.5);
      var b = { z: z, x: (i + R() * 0.7) / D.perPlane * period, w: w, h: h, win: [] };
      if (z === 1)
        for (var wx = 3; wx < w - 3; wx += u.W * 0.014) for (var wy = 4; wy < h - 3; wy += u.H * 0.03)
          if (R() < 0.55) b.win.push([wx, wy]);
      B.push(b);
    }
  var cam = 0, aim = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      u.sky([[0, D.sky[0]], [0.55, D.sky[1]], [0.88, D.sky[2]]]);
      for (var i = 0; i < B.length; i++) {
        var b = B[i], z = b.z, base = GY - (1 - z) * u.H * 0.05;
        var x = ((b.x + cam * (0.1 + z * 0.4) * u.W + t * (1 + z * 6)) % period + period) % period - u.W * 0.25;
        u.ctx.fillStyle = u.fog(D.tower, (1 - z) * 0.85, D.air);
        u.ctx.fillRect(x, base - b.h, b.w, b.h);
        for (var k = 0; k < b.win.length; k++) {
          u.ctx.fillStyle = u.rgba(D.window, 0.55 + 0.4 * Math.sin(t * 0.8 + k * 1.7 + i));
          u.ctx.fillRect(x + b.win[k][0], base - b.h + b.win[k][1], u.W * 0.007, u.H * 0.014);
        }
      }
      u.ground(GY, "#0A0A14");
      u.label("shorter, fewer, warmer: scale is a dial and the depth recipe is untouched — a village is a small city", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Valley", "Ember valley", "the same V under a smoke sky, with glowing orange mist pooled deep in the bottom — the far end burns instead of shining", function make(u) {
  // rhyme of Valley: dials moved — sky/hill/air/mist palette to embers, mistY 0.62 → 0.7
  var D = { sky: ["#2A0A10", "#7A2A18"], hill: "#1A0A08", air: "#7A3020", mist: "#FF8A30",
            pairs: 5, mistY: 0.7, seed: 6 };
  var R = u.rng(D.seed), P = [];
  for (var j = 0; j < D.pairs; j++) {
    var p = D.pairs > 1 ? j / (D.pairs - 1) : 1;
    P.push({ p: p, edgeY: 0.36 * (1 - Math.pow(p, 1.5)), notchY: 0.55 + p * 0.5,
             bump: 0.02 + R() * 0.06, at: 0.3 + R() * 0.3 });
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.55, D.sky[1]]]);
      u.soft(u.W / 2, u.H * 0.52, u.W * 0.3, "#FFB060", 0.7);
      var mistAt = Math.floor(D.pairs * 0.6);
      for (var j = 0; j < P.length; j++) {
        var s = P[j], c = u.fog(D.hill, (1 - s.p) * 0.9, D.air);
        if (j === mistAt) {
          var my = u.H * D.mistY;
          u.ctx.fillStyle = u.lin(0, my - u.H * 0.16, 0, u.H, [[0, u.rgba(D.mist, 0)], [0.45, u.rgba(D.mist, 0.8)], [1, u.rgba(D.mist, 0.4)]]);
          u.ctx.fillRect(0, my - u.H * 0.16, u.W, u.H);
        }
        for (var side = 0; side < 2; side++) {
          var m = side ? -1 : 1, o = side ? u.W : 0;
          u.poly([[o - m * 2, u.H * s.edgeY], [o + m * s.at * u.W * 0.5, u.H * (u.lerp(s.edgeY, s.notchY, s.at) - s.bump)],
                  [o + m * (u.W * 0.5 + 1), u.H * s.notchY], [o + m * (u.W * 0.5 + 1), u.H + 2], [o - m * 2, u.H + 2]], c);
        }
      }
      u.label("fog can glow: the mist band is the same gradient, only now it is brighter than what is behind it", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.mistY = u.clamp(y / u.H, 0.45, 0.9); }
  };
});

rhymeOf("Woodland", "Mushroom wood", "the same trunks, pale and half as tall, each wearing a red cap — one dial turns a forest into a fairy ring in violet fog", function make(u) {
  // rhyme of Woodland: dials moved — cap null → red, tall 1.1 → 0.45, sky/bark/air/fog palette to violet
  var D = { sky: ["#1A1030", "#4A3A6A"], bark: "#E8D8C0", air: "#6A5A8A", fog: "#8A70B0",
            trees: 28, tall: 0.45, cap: "#E04A4A", seed: 8 };
  var R = u.rng(D.seed), T = [], HY = u.H * 0.4;
  for (var i = 0; i < D.trees; i++) T.push({ x: R(), z: R() });
  T.sort(function (a, b) { return a.z - b.z; });
  var cam = 0, aim = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      cam += (aim - cam) * Math.min(1, dt * 3);
      u.sky([[0, D.sky[0]], [0.55, D.sky[1]], [1, u.shade(D.sky[1], -0.3)]]);
      var fogged = false;
      for (var i = 0; i < T.length; i++) {
        var tr = T[i], z = tr.z;
        if (!fogged && z > 0.45) {
          fogged = true;
          u.ctx.fillStyle = u.lin(0, HY - u.H * 0.05, 0, u.H, [[0, u.rgba(D.fog, 0)], [0.35, u.rgba(D.fog, 0.75)], [1, u.rgba(D.fog, 0.3)]]);
          u.ctx.fillRect(0, HY - u.H * 0.05, u.W, u.H);
        }
        var y = HY + z * z * u.H * 0.62, h = u.H * (0.2 + z * z * D.tall), w = 1.5 + z * z * u.W * 0.07;
        var x = (tr.x - 0.5) * u.W * 1.3 + u.W / 2 + cam * (0.05 + z * 0.4) * u.W;
        var c = u.fog(D.bark, (1 - z) * 0.9, D.air);
        u.cyl(x, y, w, h, c, -0.4);
        if (D.cap) u.sphere(x, y - h, w * 1.6 + 3, u.fog(D.cap, (1 - z) * 0.9, D.air), -0.5, -0.6);
      }
      u.label("a cap is one branch; the fog is the same — the far caps go violet before you can tell they were red", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { aim = (x / u.W - 0.5) * 2; }
  };
});
/* ============================== ROUNDED FORMS ==============================
   A disc becomes a ball the moment its radial gradient stops being centred:
   push the bright inner point toward the light and the eye supplies the
   third axis for free. Everything here is that one move — a ball, a
   squeezed ball (egg, airship), a ball cut in half (dome), a stack of
   horizontal bands (column, urn), a ball wearing stripes (planet), a ball
   made of mirror (quicksilver). Thirteen pictures; every one has a light
   direction you can move, and watches where the highlight, the core
   shadow, the rim light and the contact shadow go when you do. */

def("O", "Orb", "round", "one big ball: a radial gradient with its inner point pushed toward the light — that offset IS the roundness; the contact shadow leans the other way", function make(u) {
  var D = { bg: ["#1C1A32", "#0B0A16"], ball: "#5A8FE8", rim: "#8AD9F5", spec: 0.5,   // spec: how hot the highlight is (0 = matte)
            lx: -0.55, ly: -0.6, shadowA: 0.55 };                                      // lx, ly: where the light is (−1..1)
  var cx = u.W * 0.5, cy = u.H * 0.46, r = Math.min(u.W, u.H) * 0.27, GY = cy + r * 1.12;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(GY, "#0A0916");
      u.shadow(cx - D.lx * r * 0.6, GY, r * 1.1, r * 0.26, D.shadowA);                // the contact shadow leans AWAY from the light
      u.sphere(cx, cy, r, D.ball, D.lx, D.ly, { spec: D.spec, rim: D.rim });          // one radial gradient, inner point offset by lx, ly
      var px = cx + D.lx * r * 1.7, py = cy + D.ly * r * 1.7;                          // the light itself: a tiny dot, so you can see the pairing
      u.soft(px, py, r * 0.25, "#FFF3D0", 0.7); u.dot(px, py, 2.5, "#FFF9E8");
      u.label("highlight toward the light, core shadow opposite, rim light on the far edge — the offset is the roundness", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (r * 1.7), -1, 1); D.ly = u.clamp((y - cy) / (r * 1.7), -1, 1); }   // click = put the light there
  };
});

def("C", "Column", "round", "three pillars: a horizontal gradient dark → light → dark is the entire cylinder — plus a paler ellipse on top so the lid reads as flat", function make(u) {
  var D = { bg: ["#2A2444", "#151226"], stone: "#B8A88C", cols: 3, capLight: 0.45,   // capLight: how much brighter the lid is than the side
            lx: -0.3 };                                                             // lx: where the bright stripe sits, −1 left … 1 right
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      var GY = u.H * 0.8, h = u.H * 0.5, w = u.W / (D.cols * 2.4);
      u.ground(GY, "#0E0C1A");
      for (var i = 0; i < D.cols; i++) {
        var x = u.W * (i + 0.5) / D.cols;
        u.shadow(x - D.lx * w * 1.2, GY, w * 1.3, w * 0.32, 0.5);                 // each pillar's contact shadow, leaning away from the light
        u.cyl(x, GY, w, h, D.stone, D.lx);                                          // dark → light → dark; the darkest stripe is the terminator
        u.ctx.fillStyle = u.shade(D.stone, D.capLight);                             // the lid faces up, so it catches the most light
        u.ctx.beginPath(); u.ctx.ellipse(x, GY - h, w / 2, w * 0.18, 0, 0, u.TAU); u.ctx.fill();
        u.ctx.fillStyle = u.shade(D.stone, -0.5);                                   // the base ring, curving into shadow
        u.ctx.beginPath(); u.ctx.ellipse(x, GY, w / 2, w * 0.18, 0, 0, Math.PI); u.ctx.fill();
      }
      u.label("a cylinder is one horizontal gradient: bright where it faces the lamp, dark where it turns away", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x / u.W - 0.5) * 2, -1, 1); }        // click where the light is
  };
});

def("D", "Dome", "round", "a hemisphere on a plinth: half a shaded ball above a clip line, a short cylinder it sits on, and a cast shadow that says how tall it is", function make(u) {
  var D = { bg: ["#3A4A6A", "#1A1E30"], dome: "#C8B8A0", base: "#6A6A78", slit: null,   // slit: x of a dark slot in the dome (share of r), or null for none
            lx: -0.6, ly: -0.5 };
  var cx = u.W * 0.5, r = Math.min(u.W, u.H) * 0.3, by = u.H * 0.66;                     // by: the line the dome stands on
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(u.H * 0.72, "#14121F");
      u.shadow(cx - D.lx * r * 1.1, by + r * 0.16, r * 1.3, r * 0.32, 0.5);            // the cast shadow: it leans away, and it is as long as the dome is tall
      u.cyl(cx, by + r * 0.16, r * 2.6, r * 0.16, D.base, D.lx);                        // the plinth is a very short cylinder
      u.ctx.fillStyle = u.shade(D.base, 0.3);
      u.ctx.beginPath(); u.ctx.ellipse(cx, by, r * 1.3, r * 0.3, 0, 0, u.TAU); u.ctx.fill();   // its lid, lit from above
      u.ctx.save(); u.ctx.beginPath(); u.ctx.ellipse(cx, by, r, r * 0.22, 0, 0, u.TAU); u.ctx.clip();
      u.sphere(cx, by, r, D.dome, D.lx, D.ly, { spec: 0.4 });                          // the dome's lower rim, curving toward us
      u.ctx.restore();
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, 0, u.W, by); u.ctx.clip();
      u.sphere(cx, by, r, D.dome, D.lx, D.ly, { spec: 0.4 });                          // the dome itself: a ball with its lower half clipped off
      if (D.slit !== null) u.poly([[cx + D.slit * r - r * 0.05, by], [cx + D.slit * r + r * 0.05, by], [cx + D.slit * r * 0.3 + r * 0.03, by - r * 0.99], [cx + D.slit * r * 0.3 - r * 0.03, by - r * 0.99]], "#08080F");
      u.ctx.restore();
      u.label("half a sphere is still a sphere: the highlight, terminator and cast shadow all agree on one light", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (r * 1.6), -1, 1); D.ly = u.clamp((y - (by - r * 0.4)) / (r * 1.6), -1, 1); }
  };
});

def("E", "Egg", "round", "an egg is a ball under ctx.scale(0.76, 1): the same offset gradient, squeezed — a warm shadow side, a soft ground shadow, and a rock that rings down like a real egg on its base; a press flicks it", function make(u) {
  var D = { bg: ["#EAD8C0", "#C8A888"], shell: "#F2E4CC", dark: "#8A5A3A", spec: 0.4,   // dark: the shadow side — warm, because the ground bounces light into it
            squeeze: 0.76, lx: -0.5, ly: -0.6,                                        // squeeze: width ÷ height
            rock: 5.2,               // the rocking rate, rad/s: √k — an egg on its curved base has a definite period (2π/rock)
            damp: 0.15,              // as a fraction of critical: well under 1, so each rock is a little smaller than the last
            kick: 1.5,               // the angular velocity a press flicks in, rad/s
            idle: 4 };               // seconds between the small random nudges that keep it rocking between presses
  var cx = u.W * 0.5, cy = u.H * 0.47, r = Math.min(u.W, u.H) * 0.3, GY = cy + r * 1.02;
  var ang = 0.12, av = 0, cool = 0, nudge = D.idle * 0.5;                              // the rock: angle, angular velocity, the press cooldown, seconds to the next nudge
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(GY, "#8A6A50");
      // an egg on its curved base is a pendulum: tip it and gravity rights
      // it, but it overshoots and rocks back, each swing a little smaller — a
      // damped spring on the angle, k = rock², damping a fraction of critical.
      // a press is a flick: it adds angular velocity, never sets the angle; a
      // small random nudge every few seconds keeps it alive between presses.
      var k = D.rock * D.rock, d = D.damp * 2 * D.rock, sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;   // substeps of ≤ 0.02 s
      cool -= dt; nudge -= dt;
      if (nudge <= 0) { nudge = D.idle * u.rand(0.6, 1.4); av += u.rand(-0.5, 0.5) * D.kick; }
      for (var s = 0; s < sub; s++) { av += (-k * ang - d * av) * h; ang = u.clamp(ang + av * h, -0.55, 0.55); }
      var a = ang;                                                                     // the rock, in radians
      var llx = D.lx * Math.cos(a) + D.ly * Math.sin(a), lly = -D.lx * Math.sin(a) + D.ly * Math.cos(a);   // the light, seen from the egg's own tilted frame
      u.shadow(cx - D.lx * r * 0.5 + a * r * 2, GY, r * 0.9, r * 0.2, 0.4);
      u.ctx.save(); u.ctx.translate(cx, cy); u.ctx.rotate(a); u.ctx.scale(D.squeeze, 1);
      u.sphere(0, 0, r, D.shell, llx, lly, { dark: D.dark, spec: D.spec });           // one ball, squeezed: the gradient squeezes with it
      u.ctx.restore();
      u.label("the shadow side is warm, not black — bounced light fills it; the highlight stays with the lamp, not the egg (θ'' = −rock²·θ − damp·θ')", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) {                                                           // click = move the lamp, and flick the egg away from the pointer
      D.lx = u.clamp((x - cx) / (r * 1.6), -1, 1); D.ly = u.clamp((y - cy) / (r * 1.6), -1, 1);
      if (cool <= 0) { av += (x < cx ? 1 : -1) * D.kick; cool = 0.4; }               // one flick per press, not one per dragged frame
    }
  };
});

def("E", "Eyeball", "round", "a white ball with an iris disc that saccades to look at you — the pupil overshoots a touch and settles, the highlight stays put on the light's side, and that difference sells the roundness", function make(u) {
  var D = { bg: ["#2A1E3A", "#120C1E"], white: "#F2EEF0", hue: 200, asp: 1.0,   // hue: the iris; asp: pupil width ÷ height — 1 is round, 0.25 is a cat's slit
            lx: -0.5, ly: -0.55,
            follow: 6,               // how quickly the eye turns: √k, rad/s — the pupil's spring toward where it wants to look
            damp: 0.6 };             // as a fraction of critical: under 1, so a saccade overshoots by a few percent and settles
  var cx = u.W * 0.5, cy = u.H * 0.47, r = Math.min(u.W, u.H) * 0.3;
  var tx = 0.25, ty = 0.1, px = 0.25, py = 0.1, vx = 0, vy = 0;                 // where it wants to look, where the pupil actually is, and how fast it is moving
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(cy + r * 1.1, "#0C0A16");
      u.shadow(cx - D.lx * r * 0.6, cy + r * 1.1, r * 1.05, r * 0.25, 0.5);
      u.sphere(cx, cy, r, D.white, D.lx, D.ly, { spec: 0.15, dark: "#8A7A8A" });
      // the pupil is a damped spring on its position (Yolk's spring, in two
      // axes): a press moves the TARGET, the pupil accelerates toward it,
      // overshoots by a few percent because the damping is under critical,
      // and settles — a saccade. Cat eye's higher follow is a stiffer spring:
      // the same overshoot, over in half the time — snap and settle.
      var k = D.follow * D.follow, d = D.damp * 2 * D.follow, sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;   // substeps of ≤ 0.02 s
      for (var s = 0; s < sub; s++) {
        vx += (k * (tx - px) - d * vx) * h; vy += (k * (ty - py) - d * vy) * h;
        px = u.clamp(px + vx * h, -1.1, 1.1); py = u.clamp(py + vy * h, -1.1, 1.1);
      }
      var dd = Math.sqrt(px * px + py * py), sq = 1 - 0.35 * dd, ang = Math.atan2(py, px);   // the iris foreshortens as it turns toward the edge
      var ix = cx + px * r * 0.5, iy = cy + py * r * 0.5, ir = r * 0.42;
      u.ctx.save(); u.ctx.translate(ix, iy);
      u.ctx.rotate(ang); u.ctx.scale(sq, 1); u.ctx.rotate(-ang);                            // squeeze along the look direction only
      u.ctx.fillStyle = u.rad(0, 0, ir, [[0, u.hsl(D.hue, 0.6, 0.55)], [0.7, u.hsl(D.hue, 0.7, 0.35)], [1, u.hsl(D.hue, 0.5, 0.12)]]);
      u.ctx.beginPath(); u.ctx.arc(0, 0, ir, 0, u.TAU); u.ctx.fill();                       // the iris: a centred radial — it is flat, painted ON the ball
      u.ctx.fillStyle = "#08060C";
      u.ctx.beginPath(); u.ctx.ellipse(0, 0, ir * 0.42 * D.asp, ir * 0.42, 0, 0, u.TAU); u.ctx.fill();
      u.ctx.restore();
      u.soft(cx + D.lx * r * 0.5, cy + D.ly * r * 0.5, r * 0.16, "#FFFFFF", 0.95);        // the highlight belongs to the light, not to the eye
      u.label("the iris slides, the highlight doesn't — a highlight is the lamp's reflection, so it stays on the lamp's side", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { tx = u.clamp((x - cx) / r, -1, 1); ty = u.clamp((y - cy) / r, -1, 1); }   // click = look there
  };
});

def("J", "Jupiter", "round", "a banded planet: flat wobbly stripes clipped to a disc, then one radial gradient — clear in the middle, dark at the rim, offset toward the sun — lays the roundness on top", function make(u) {
  var D = { bg: ["#050510", "#0B0A18"], bands: ["#D9B48A", "#A8734A", "#E8D2B0", "#B8865A", "#F0E0C8", "#8A5A3A", "#D9B48A", "#C29060", "#E8D2B0"],
            spot: "#C05A3A", night: "#050510", speed: 0.5, lx: -0.6, ly: -0.3 };   // speed: how fast the bands slide
  var cx = u.W * 0.5, cy = u.H * 0.48, r = Math.min(u.W, u.H) * 0.36;
  var R = u.rng(7), stars = [];
  for (var s = 0; s < 40; s++) stars.push([R() * u.W, R() * u.H, 0.3 + R() * 1.0]);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      for (var s = 0; s < stars.length; s++) u.dot(stars[s][0], stars[s][1], stars[s][2], u.rgba(u.INK, 0.6));
      u.ctx.save(); u.ctx.beginPath(); u.ctx.arc(cx, cy, r, 0, u.TAU); u.ctx.clip();
      var n = D.bands.length, bh = (2 * r) / n;
      for (var i = 0; i < n; i++) {                                                 // each band: a strip with a wobbly top, painted top → bottom
        var top = cy - r + i * bh, sp = D.speed * (1 + (i % 3) * 0.7) * (i % 2 ? 1 : -1);   // neighbours slide at different speeds and directions
        u.ctx.fillStyle = D.bands[i];
        u.ctx.beginPath(); u.ctx.moveTo(cx - r, cy + r);
        for (var x = cx - r; x <= cx + r + 8; x += 8)
          u.ctx.lineTo(x, top + Math.sin(x / r * 3 + t * sp) * bh * 0.25 + Math.sin(x / r * 7 - t * sp * 1.7) * bh * 0.1);
        u.ctx.lineTo(cx + r + 8, cy + r); u.ctx.closePath(); u.ctx.fill();
      }
      var sx = cx + ((t * D.speed * 0.3 * r) % (2.6 * r)) - 1.3 * r;                 // the great spot, crossing and wrapping
      u.ctx.fillStyle = D.spot; u.ctx.beginPath(); u.ctx.ellipse(sx, cy + r * 0.3, r * 0.22, r * 0.12, 0, 0, u.TAU); u.ctx.fill();
      u.ctx.fillStyle = u.rad(cx, cy, r * 1.02, [[0, "rgba(255,240,220,0.18)"], [0.45, "rgba(0,0,0,0)"], [0.8, "rgba(5,5,16,0.55)"], [1, u.rgba(D.night, 0.98)]], D.lx * r * 0.5, D.ly * r * 0.5);
      u.ctx.fillRect(cx - r, cy - r, 2 * r, 2 * r);                                  // the roundness: one overlay, clear in the middle, dark at the rim, shifted toward the sun
      u.ctx.restore();
      u.label("the stripes are flat; the dark overlay is the whole sphere — the terminator is where it fades to night", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (r * 1.6), -1, 1); D.ly = u.clamp((y - cy) / (r * 1.6), -1, 1); }
  };
});

def("L", "Lozenge", "round", "a capsule: a cylinder between two half-balls, all shaded from ONE light — it turns slowly, but the highlight stays on the light's side", function make(u) {
  var D = { bg: ["#1E2A3A", "#0C1018"], pill: "#E86A8A", spin: 0.6, len: 1.8,   // len: the body's length in radii; spin: turns per second-ish
            lx: -0.5, ly: -0.6 };
  var cx = u.W * 0.5, cy = u.H * 0.45, r = Math.min(u.W, u.H) * 0.15, GY = u.H * 0.82;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(GY, "#08090F");
      var a = t * D.spin, L = r * D.len, ca = Math.cos(a), sa = Math.sin(a);
      var llx = D.lx * ca + D.ly * sa, lly = -D.lx * sa + D.ly * ca;               // the light, seen from the pill's own turning frame
      u.shadow(cx - D.lx * r * 0.8, GY, L * Math.abs(ca) * 0.5 + r * 1.2, r * 0.35, 0.45);   // the shadow is as long as the pill looks
      u.ctx.save(); u.ctx.translate(cx, cy); u.ctx.rotate(a);
      var hi = u.clamp(0.5 + lly * 0.28, 0.05, 0.95);                              // the body's bright stripe, lined up with the caps' highlight
      u.ctx.fillStyle = u.lin(0, -r, 0, r, [[0, u.shade(D.pill, -0.55)], [hi, u.shade(D.pill, 0.35)], [u.clamp(hi + 0.3, 0, 1), D.pill], [1, u.shade(D.pill, -0.75)]]);
      u.ctx.fillRect(-L / 2, -r, L, 2 * r);                                        // the body: a cylinder lying down, so its gradient runs across
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(-L / 2 - r - 1, -r - 1, r + 1, 2 * r + 2); u.ctx.clip();
      u.sphere(-L / 2, 0, r, D.pill, llx, lly); u.ctx.restore();                  // the left cap: half a ball
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(L / 2, -r - 1, r + 1, 2 * r + 2); u.ctx.clip();
      u.sphere(L / 2, 0, r, D.pill, llx, lly); u.ctx.restore();                   // the right cap
      u.ctx.restore();
      u.label("three shapes, one light: the caps' highlight and the body's bright stripe meet because they agree on lx, ly", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (r * 3), -1, 1); D.ly = u.clamp((y - cy) / (r * 3), -1, 1); }
  };
});

def("P", "Pearl", "round", "a small ball with a wide soft highlight, a rim light from behind, and two hues bleeding across the highlight — nacre is a sphere plus a colour shift", function make(u) {
  var D = { bg: ["#2A1A2E", "#0E0812"], pearl: "#E8E0E6", rim: "#F5C0E0", dark: "#8A7A90",   // rim: the back-light colour leaking round the edge
            hueA: 320, hueB: 190, cushion: "#3A1A34", lx: -0.45, ly: -0.55 };               // hueA, hueB: the two tints either side of the highlight
  var cx = u.W * 0.5, cy = u.H * 0.5, r = Math.min(u.W, u.H) * 0.2, GY = cy + r * 0.85;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ctx.fillStyle = u.rad(cx, GY + r * 0.5, u.W * 0.7, [[0, u.shade(D.cushion, 0.25)], [0.5, D.cushion], [1, u.shade(D.cushion, -0.6)]], D.lx * u.W * 0.2, -r);
      u.ctx.beginPath(); u.ctx.ellipse(cx, GY + r * 0.5, u.W * 0.7, r * 1.6, 0, 0, u.TAU); u.ctx.fill();   // the cushion: a soft mound, lit from the same side
      u.ctx.fillRect(0, GY + r * 0.5, u.W, u.H);
      u.shadow(cx - D.lx * r * 0.4, GY, r * 1.1, r * 0.3, 0.6);                                   // the dent it sits in — a contact shadow, tight and dark
      u.sphere(cx, cy, r, D.pearl, D.lx, D.ly, { spec: 0.55, rim: D.rim, dark: D.dark });
      var hx = cx + D.lx * r * 0.5, hy = cy + D.ly * r * 0.5;
      u.ctx.save(); u.ctx.beginPath(); u.ctx.arc(cx, cy, r, 0, u.TAU); u.ctx.clip();
      u.soft(hx - r * 0.2, hy + r * 0.15, r * 0.6, u.hsl(D.hueA, 0.8, 0.7), 0.35);              // two hues, one each side of the highlight
      u.soft(hx + r * 0.25, hy - r * 0.1, r * 0.6, u.hsl(D.hueB, 0.8, 0.7), 0.35);
      u.soft(hx, hy, r * 0.4, "#FFFFFF", 0.7);                                                    // the highlight itself: wide and soft, because nacre is not glass
      u.ctx.restore();
      u.label("rim light: a little light round the back edge lifts the ball off what's behind it — wide highlight = soft surface", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (r * 2.5), -1, 1); D.ly = u.clamp((y - cy) / (r * 2.5), -1, 1); }
  };
});

def("Q", "Quicksilver", "round", "mirror ball beside matte ball: the matte one is a smooth radial; the mirror one is a sky band over a dark ground band, clipped to the disc, plus one sharp white dot", function make(u) {
  var D = { bg: ["#2E3444", "#141824"], matte: "#7A8494", skyHi: "#DCE8F5", skyLo: "#8AA0C0",   // what the mirror ball reflects: a sky…
            groundHi: "#5A4A3A", groundLo: "#141010", lx: -0.5, ly: -0.55 };                    // …over a ground
  var r = Math.min(u.W, u.H) * 0.2, cy = u.H * 0.47, ax = u.W * 0.28, bx = u.W * 0.72, GY = cy + r * 1.15;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(GY, "#0C0D14");
      u.shadow(ax - D.lx * r * 0.6, GY, r * 1.05, r * 0.25, 0.5);
      u.shadow(bx - D.lx * r * 0.6, GY, r * 1.05, r * 0.25, 0.5);
      u.sphere(ax, cy, r, D.matte, D.lx, D.ly, { spec: 0.4 });                                 // matte: the light spreads over the surface
      u.ctx.save(); u.ctx.beginPath(); u.ctx.arc(bx, cy, r, 0, u.TAU); u.ctx.clip();
      var hz = cy + r * 0.12;                                                                   // the reflected horizon, a little below centre
      u.ctx.fillStyle = u.lin(0, cy - r, 0, hz, [[0, D.skyLo], [1, D.skyHi]]);                // the sky, reflected: dark overhead, pale at the horizon
      u.ctx.fillRect(bx - r, cy - r, 2 * r, hz - (cy - r));
      u.ctx.fillStyle = u.lin(0, hz, 0, cy + r, [[0, D.groundHi], [1, D.groundLo]]);
      u.ctx.fillRect(bx - r, hz, 2 * r, cy + r - hz);                                           // the ground, reflected: warm near the horizon, black below
      u.ctx.fillStyle = u.rad(bx, cy, r * 1.02, [[0.6, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,0.55)"]], D.lx * r * 0.3, D.ly * r * 0.3);
      u.ctx.fillRect(bx - r, cy - r, 2 * r, 2 * r);                                             // the rim darkens as the mirror curves away
      u.dot(bx + D.lx * r * 0.55, cy + D.ly * r * 0.55, r * 0.09, "#FFFFFF");                 // mirror: the light itself, tiny and sharp
      u.ctx.restore();
      u.label("matte", ax, cy - r - 8, null, "center"); u.label("mirror", bx, cy - r - 8, null, "center");
      u.label("same ball, two materials: a wide highlight says rough, a pinpoint highlight and a horizon say mirror", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - u.W / 2) / (u.W * 0.5), -1, 1); D.ly = u.clamp((y - cy) / (r * 2), -1, 1); }
  };
});

def("T", "Torus", "round", "a ring shaded as a donut: one radial gradient whose stops peak at the tube's middle radius, pushed toward the light — plus a dark wash across the far half", function make(u) {
  var D = { bg: ["#1A2230", "#0A0E16"], tube: "#E8A040", dark: "#3A2010", fat: 0.42,   // fat: tube radius ÷ ring radius; dark: the colour at both edges of the tube
            spin: 0.7, sprinkles: 0 };                                                   // spin: how fast the light circles; sprinkles: 0 for a plain ring
  var cx = u.W * 0.5, cy = u.H * 0.46, Ro = Math.min(u.W, u.H) * 0.34;
  var a = Ro * D.fat / (1 + D.fat), Rc = Ro - a, Ri = Rc - a;                            // tube radius, the tube's centre radius, the hole's radius
  var R = u.rng(5), sp = [];
  for (var j = 0; j < D.sprinkles; j++) { var an = R() * u.TAU, rr = Rc + (R() - 0.5) * a * 1.3; sp.push([cx + Math.cos(an) * rr, cy + Math.sin(an) * rr, R() * u.TAU, u.hsl(R() * 360, 0.85, 0.6)]); }
  var phase = 0, lastT = 0;
  function ring() { u.ctx.beginPath(); u.ctx.arc(cx, cy, Ro, 0, u.TAU); u.ctx.arc(cx, cy, Ri, 0, u.TAU, true); }   // outer edge, then the hole drawn backwards
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      lastT = t;
      u.sky(D.bg);
      var GY = cy + Ro * 1.1; u.ground(GY, "#07080E");
      var ang = t * D.spin + phase, lx = Math.cos(ang) * 0.7, ly = Math.sin(ang) * 0.7;   // the light circles slowly; the ring itself never moves
      u.shadow(cx - lx * Ro * 0.4, GY, Ro * 1.1, Ro * 0.22, 0.5);
      ring();
      u.ctx.fillStyle = u.rad(cx, cy, Ro, [[Ri / Ro, D.dark], [(Rc - a * 0.35) / Ro, u.shade(D.tube, 0.4)], [Rc / Ro, D.tube], [(Rc + a * 0.6) / Ro, u.shade(D.tube, -0.3)], [1, D.dark]], lx * a * 0.9, ly * a * 0.9);
      u.ctx.fill();                                                                       // dark at the hole, bright at the tube's crown, dark at the outer edge
      ring();
      u.ctx.fillStyle = u.lin(cx + lx / 0.7 * Ro, cy + ly / 0.7 * Ro, cx - lx / 0.7 * Ro, cy - ly / 0.7 * Ro, [[0, "rgba(0,0,0,0)"], [0.5, "rgba(0,0,0,0.08)"], [1, "rgba(0,0,0,0.55)"]]);
      u.ctx.fill();                                                                       // the far half turns away from the light: one linear wash
      for (var s = 0; s < sp.length; s++) {
        u.ctx.save(); u.ctx.translate(sp[s][0], sp[s][1]); u.ctx.rotate(sp[s][2]);
        u.ctx.fillStyle = sp[s][3]; u.ctx.fillRect(-a * 0.14, -a * 0.05, a * 0.28, a * 0.1); u.ctx.restore();
      }
      u.label("on the lit side the crown sits toward the outside, on the far side toward the hole — the offset does that for free", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { phase = Math.atan2(y - cy, x - cx) - lastT * D.spin; }        // click = put the light on that side
  };
});

def("U", "Urn", "round", "a vase from a lathe: 40 thin slices, each as wide as a profile function says, each a horizontal dark → light → dark cylinder gradient — round things from stacked rings", function make(u) {
  var D = { bg: ["#3A3048", "#16121E"], clay: "#B86A48", band: "#4A2A24", slices: 40,   // band: a painted stripe round the belly; slices: how thin the rings are
            lx: -0.35, ly: -0.5 };
  var cx = u.W * 0.5, top = u.H * 0.12, bot = u.H * 0.8, Hh = bot - top, wmax = Math.min(u.W * 0.2, Hh * 0.36);   // wmax: the belly's half-width
  function prof(k) {                                                                     // k: 0 at the lip … 1 at the foot → half-width, as a share of wmax
    if (k < 0.05) return 0.44;                                                           // the lip
    if (k < 0.2) return 0.3 + (k - 0.05) * 0.4;                                          // the neck, widening
    if (k < 0.86) return 0.36 + 0.64 * Math.sin((k - 0.2) / 0.66 * Math.PI);            // the belly: half a sine
    if (k < 0.94) return 0.3;                                                            // the stem
    return 0.46;                                                                         // the foot
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(bot, "#0E0B14");
      u.shadow(cx - D.lx * wmax * 0.8, bot, wmax * 1.4, wmax * 0.3, 0.5);
      var sh = Hh / D.slices;
      for (var i = 0; i < D.slices; i++) {
        var k = (i + 0.5) / D.slices, w = prof(k) * wmax * 2;
        var c = u.shade(i > D.slices * 0.5 && i < D.slices * 0.58 ? D.band : D.clay, -D.ly * (0.5 - k) * 0.4);   // slices nearer a high light are a little brighter
        u.cyl(cx, top + (i + 1) * sh + 0.6, w, sh + 0.6, c, D.lx);                        // one short cylinder per slice; the widths draw the vase
      }
      u.ctx.fillStyle = u.shade(D.clay, -0.65);                                            // the mouth: we look down into the dark inside
      u.ctx.beginPath(); u.ctx.ellipse(cx, top, prof(0) * wmax * 0.85, sh * 1.2, 0, 0, u.TAU); u.ctx.fill();
      u.label("every slice is the Column trick; stack them at different widths and the highlight runs down the vase in one line", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (u.W * 0.4), -1, 1); D.ly = u.clamp((y - (top + bot) / 2) / (Hh * 0.6), -1, 1); }
  };
});

def("Y", "Yolk", "round", "a fried egg: the white is a radial gradient that fades to nothing at its edge (that IS the translucency), the yolk a squashed ball with a hot highlight — tap it and it wobbles", function make(u) {
  var D = { pan: ["#3A3236", "#1A1618"], white: "#FFFBF2", yolk: "#F5A623", yolkDark: "#B85A10", spec: 0.7,   // spec: how hot the highlight is — wet things are hot
            size: 1.0, speckles: 0, lx: -0.5, ly: -0.6 };                                                   // size: the whole egg; speckles: dots on the white
  var cx = u.W * 0.5, cy = u.H * 0.5, rw = Math.min(u.W, u.H) * 0.36 * D.size, ry = rw * 0.42;              // rw: the white's radius; ry: the yolk's
  var R = u.rng(9), spk = [];
  for (var j = 0; j < D.speckles; j++) { var an = R() * u.TAU, d = 0.55 + R() * 0.4; spk.push([cx + Math.cos(an) * rw * 1.15 * d, cy + Math.sin(an) * rw * 0.8 * d, 0.6 + R() * 1.2]); }
  var jig = 0, vel = 0;                                                                                       // the spring: how squashed the yolk is, and how fast that's changing
  return {
    frame: function (dt, t) {
      u.ctx.fillStyle = u.rad(cx, cy, u.W * 0.7, D.pan); u.ctx.fillRect(0, 0, u.W, u.H);                    // the pan, lit from the middle
      vel += (-jig * 90 - vel * 5) * dt; jig = u.clamp(jig + vel * dt, -0.45, 0.45);                          // stiffness 90, damping 5
      u.ctx.save(); u.ctx.translate(cx, cy); u.ctx.scale(1.25, 0.9);
      u.ctx.fillStyle = u.rad(0, 0, rw, [[0, D.white], [0.7, D.white], [0.88, u.rgba(D.white, 0.8)], [1, u.rgba(D.white, 0)]]);   // the white thins to nothing at its edge
      u.ctx.beginPath();
      for (var i = 0; i <= 24; i++) { var an = i / 24 * u.TAU, rr = rw * (0.9 + 0.1 * Math.sin(an * 3 + 1) + 0.05 * Math.sin(an * 5)); u.ctx.lineTo(Math.cos(an) * rr, Math.sin(an) * rr); }
      u.ctx.closePath(); u.ctx.fill();
      u.ctx.restore();
      for (var s = 0; s < spk.length; s++) u.dot(spk[s][0], spk[s][1], spk[s][2], "#6A4A3A");
      u.shadow(cx - D.lx * ry * 0.3, cy + ry * 0.55, ry * 1.1, ry * 0.4, 0.25);                             // the yolk's contact shadow on the white
      u.ctx.save(); u.ctx.translate(cx, cy + ry * 0.1); u.ctx.scale(1 + jig, 0.78 - jig);                  // squash one way, stretch the other: volume looks kept
      u.sphere(0, 0, ry, D.yolk, D.lx, D.ly, { spec: D.spec, dark: D.yolkDark });                           // the yolk: a ball, flattened
      u.ctx.restore();
      u.label("glossy = a tight hot highlight, matte = a wide one; the white's soft edge is the cheapest translucency there is", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { vel += 2.5; }                                                                   // a poke; the spring takes it from here
  };
});

def("Z", "Zeppelin", "round", "an airship is a ball under ctx.scale(2.4, 1): one stretched radial gradient, a gondola, two fins — all lit from one side — riding the air on a spring, nose tipping up as it climbs, and a faint shadow on the cloud floor far below", function make(u) {
  var D = { sky: ["#6FA8E8", "#CFE6F5"], hull: "#D8D0C0", hullDark: "#4A5060", gondola: "#3A3038",   // hullDark: the shadow side, cool because the sky lights it
            stretch: 2.4, speed: 1.0, lx: -0.5, ly: -0.6,                                            // stretch: length ÷ height; speed: the drift
            buoy: 4,                 // the hull's spring toward the air it floats in: k — how stiffly it holds its height
            damp: 0.35,              // as a fraction of critical: under 1, so the hull overshoots each gust and settles back
            pitch: 0.25,             // radians of nose-up per hull-height-per-second of climb — a second spring chases the vertical velocity
            gust: 0.7 };             // the slow air's rate, rad/s — the rest the bob chases (a sine of the clock is the INPUT, not the answer)
  var r = Math.min(u.W, u.H) * 0.11, cy = u.H * 0.4, GY = u.H * 0.78;
  var R = u.rng(6), puffs = [];
  for (var j = 0; j < 12; j++) puffs.push([R() * u.W, GY + R() * (u.H - GY) * 0.6, u.W * (0.06 + R() * 0.08)]);
  var bob = 0, bv = 0, pt = 0, pv = 0, cool = 0;                                                    // the bob (px off cy) + velocity, the pitch (radians) + velocity, the press cooldown
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ctx.fillStyle = u.lin(0, GY - 10, 0, u.H, ["#F5F7FA", "#B8C8DC"]); u.ctx.fillRect(0, GY, u.W, u.H - GY);   // the cloud floor
      for (var j = 0; j < puffs.length; j++) u.soft(puffs[j][0], puffs[j][1], puffs[j][2], "#FFFFFF", 0.7);
      // the airship floats on a spring: the slow gust is the REST (the air
      // it wants to sit in), and the hull chases it with mass — under-damped,
      // so it overshoots each rise and settles back. the pitch is a second,
      // quicker spring whose rest is the climb rate, so the nose tips up while
      // it rises and drops after the top: follow-through, not decoration.
      var rest = (Math.sin(t * D.gust) + 0.4 * Math.sin(t * D.gust * 2.3 + 1)) * r * 0.25;      // the gust: two slow sines, the air's own motion
      var k = D.buoy, d = D.damp * 2 * Math.sqrt(k), kp = 9, dp = 0.5 * 2 * 3;                   // the pitch spring: k 9, half critical — it lags the climb
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;                                  // substeps of ≤ 0.02 s
      cool -= dt;
      for (var s = 0; s < sub; s++) {
        bv += (k * (rest - bob) - d * bv) * h; bob = u.clamp(bob + bv * h, -r, r);
        pv += (kp * (bv / r * D.pitch - pt) - dp * pv) * h; pt = u.clamp(pt + pv * h, -0.35, 0.35);   // climbing is bv < 0 on screen, so the nose (at +x) lifts
      }
      var span = u.W + r * D.stretch * 2.6, bx = ((t * D.speed * 40) % span) - r * D.stretch * 1.3;               // drifts across, then wraps
      var by = cy + bob;
      var llx = D.lx * Math.cos(pt) + D.ly * Math.sin(pt), lly = -D.lx * Math.sin(pt) + D.ly * Math.cos(pt);       // the light, seen from the tilted hull
      u.shadow(bx - D.lx * r * 0.5, GY + 6, r * D.stretch * 0.9, r * 0.28, 0.18);                                  // far below: faint and soft, like the clouds it lands on
      u.ctx.save(); u.ctx.translate(bx, by); u.ctx.rotate(pt);                                                       // the whole ship pitches together
      var tail = -r * D.stretch * 0.75;
      u.poly([[tail, -r * 0.4], [tail - r * 0.9, -r * 1.3], [tail - r * 0.55, 0]], u.shade(D.hull, 0.1));            // the top fin faces the light…
      u.poly([[tail, r * 0.4], [tail - r * 0.9, r * 1.3], [tail - r * 0.55, 0]], u.shade(D.hull, -0.5));             // …the bottom fin doesn't
      u.ctx.save(); u.ctx.scale(D.stretch, 1);
      u.sphere(0, 0, r, D.hull, llx, lly, { dark: D.hullDark, spec: 0.3 });                                         // the hull: one ball, stretched — the gradient stretches with it
      u.ctx.restore();
      u.ctx.fillStyle = D.gondola; u.ctx.fillRect(-r * 0.5, r * 0.85, r, r * 0.35);                                // the gondola hangs under the belly
      u.ctx.restore();
      u.label("one light for everything: hull, fins and gondola agree, and the shadow is faint because the floor is far — y'' = buoy·(gust − y) − damp·y'", u.W / 2, u.H - 8, "rgba(20,24,40,0.75)", "center");   // dark ink: the floor is pale
    },
    press: function (x, y) {                                                                                         // click = move the lamp, and an updraft under the hull
      D.lx = u.clamp((x - u.W / 2) / (u.W * 0.5), -1, 1); D.ly = u.clamp((y - cy) / (r * 3), -1, 1);
      if (cool <= 0) { bv -= r * 1.5; cool = 1.2; }                                                                 // one lift per press, not one per dragged frame
    }
  };
});

/* ---- the rhymes: same pictures, two or three dials moved ---- */

rhymeOf("Orb", "Matte orb", "the same ball with the highlight turned off and no rim light — chalk instead of plastic; a minimalist print", function make(u) {
  // rhyme of Orb: dials moved — spec 0.5 → 0, rim → none, ball/bg palette to pale greys, shadowA 0.55 → 0.7
  var D = { bg: ["#ECEAF0", "#C8C6D0"], ball: "#D8D6DE", rim: null, spec: 0,
            lx: -0.55, ly: -0.6, shadowA: 0.7 };
  var cx = u.W * 0.5, cy = u.H * 0.46, r = Math.min(u.W, u.H) * 0.27, GY = cy + r * 1.12;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(GY, "#0A0916");
      u.shadow(cx - D.lx * r * 0.6, GY, r * 1.1, r * 0.26, D.shadowA);                // the contact shadow leans AWAY from the light
      u.sphere(cx, cy, r, D.ball, D.lx, D.ly, { spec: D.spec, rim: D.rim });          // one radial gradient, inner point offset by lx, ly
      var px = cx + D.lx * r * 1.7, py = cy + D.ly * r * 1.7;                          // the light itself: a tiny dot, so you can see the pairing
      u.soft(px, py, r * 0.25, "#FFF3D0", 0.7); u.dot(px, py, 2.5, "#FFF9E8");
      u.label("spec 0, no rim: with no highlight the core shadow does all the work — value alone makes a ball", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (r * 1.7), -1, 1); D.ly = u.clamp((y - cy) / (r * 1.7), -1, 1); }   // click = put the light there
  };
});

rhymeOf("Column", "Marble columns", "the same pillars in pale marble, five instead of three, with softer lids — a colonnade", function make(u) {
  // rhyme of Column: dials moved — stone → marble, cols 3 → 5, capLight 0.45 → 0.3, bg palette
  var D = { bg: ["#D8DCE8", "#8A90A8"], stone: "#E8E4DC", cols: 5, capLight: 0.3,
            lx: -0.3 };
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      var GY = u.H * 0.8, h = u.H * 0.5, w = u.W / (D.cols * 2.4);
      u.ground(GY, "#0E0C1A");
      for (var i = 0; i < D.cols; i++) {
        var x = u.W * (i + 0.5) / D.cols;
        u.shadow(x - D.lx * w * 1.2, GY, w * 1.3, w * 0.32, 0.5);                 // each pillar's contact shadow, leaning away from the light
        u.cyl(x, GY, w, h, D.stone, D.lx);                                          // dark → light → dark; the darkest stripe is the terminator
        u.ctx.fillStyle = u.shade(D.stone, D.capLight);                             // the lid faces up, so it catches the most light
        u.ctx.beginPath(); u.ctx.ellipse(x, GY - h, w / 2, w * 0.18, 0, 0, u.TAU); u.ctx.fill();
        u.ctx.fillStyle = u.shade(D.stone, -0.5);                                   // the base ring, curving into shadow
        u.ctx.beginPath(); u.ctx.ellipse(x, GY, w / 2, w * 0.18, 0, 0, Math.PI); u.ctx.fill();
      }
      u.label("paler stone, five pillars: the bright stripe sits on the same side of every one — one light, many cylinders", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x / u.W - 0.5) * 2, -1, 1); }        // click where the light is
  };
});

rhymeOf("Dome", "Observatory", "the same dome at night, steel-blue, with one dark slot cut into it — the slot is the only flat thing in the picture", function make(u) {
  // rhyme of Dome: dials moved — bg/dome/base palette to night, slit null → 0.15
  var D = { bg: ["#05061A", "#141838"], dome: "#8A93A8", base: "#3A3E50", slit: 0.15,
            lx: -0.6, ly: -0.5 };
  var cx = u.W * 0.5, r = Math.min(u.W, u.H) * 0.3, by = u.H * 0.66;                     // by: the line the dome stands on
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(u.H * 0.72, "#14121F");
      u.shadow(cx - D.lx * r * 1.1, by + r * 0.16, r * 1.3, r * 0.32, 0.5);            // the cast shadow: it leans away, and it is as long as the dome is tall
      u.cyl(cx, by + r * 0.16, r * 2.6, r * 0.16, D.base, D.lx);                        // the plinth is a very short cylinder
      u.ctx.fillStyle = u.shade(D.base, 0.3);
      u.ctx.beginPath(); u.ctx.ellipse(cx, by, r * 1.3, r * 0.3, 0, 0, u.TAU); u.ctx.fill();   // its lid, lit from above
      u.ctx.save(); u.ctx.beginPath(); u.ctx.ellipse(cx, by, r, r * 0.22, 0, 0, u.TAU); u.ctx.clip();
      u.sphere(cx, by, r, D.dome, D.lx, D.ly, { spec: 0.4 });                          // the dome's lower rim, curving toward us
      u.ctx.restore();
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, 0, u.W, by); u.ctx.clip();
      u.sphere(cx, by, r, D.dome, D.lx, D.ly, { spec: 0.4 });                          // the dome itself: a ball with its lower half clipped off
      if (D.slit !== null) u.poly([[cx + D.slit * r - r * 0.05, by], [cx + D.slit * r + r * 0.05, by], [cx + D.slit * r * 0.3 + r * 0.03, by - r * 0.99], [cx + D.slit * r * 0.3 - r * 0.03, by - r * 0.99]], "#08080F");
      u.ctx.restore();
      u.label("a night palette and one dark slot: the slot is flat, so it reads as a cut INTO the round", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (r * 1.6), -1, 1); D.ly = u.clamp((y - (by - r * 0.4)) / (r * 1.6), -1, 1); }
  };
});

rhymeOf("Egg", "Dragon egg", "the same egg in dark red lacquer with a hotter highlight, narrower and slower — a fantasy prop", function make(u) {
  // rhyme of Egg: dials moved — shell/dark/bg palette to dark red, spec 0.4 → 0.9, squeeze 0.76 → 0.72, rock 5.2 → 3.0 (a heavier egg rocks slower)
  var D = { bg: ["#2A0A10", "#0C0406"], shell: "#7A1424", dark: "#200408", spec: 0.9,
            squeeze: 0.72, lx: -0.5, ly: -0.6,
            rock: 3.0, damp: 0.15, kick: 1.5, idle: 4 };                              // the same spring, slower: rate rad/s, damping of critical, flick rad/s, nudge seconds
  var cx = u.W * 0.5, cy = u.H * 0.47, r = Math.min(u.W, u.H) * 0.3, GY = cy + r * 1.02;
  var ang = 0.12, av = 0, cool = 0, nudge = D.idle * 0.5;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(GY, "#8A6A50");
      var k = D.rock * D.rock, d = D.damp * 2 * D.rock, sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      cool -= dt; nudge -= dt;
      if (nudge <= 0) { nudge = D.idle * u.rand(0.6, 1.4); av += u.rand(-0.5, 0.5) * D.kick; }
      for (var s = 0; s < sub; s++) { av += (-k * ang - d * av) * h; ang = u.clamp(ang + av * h, -0.55, 0.55); }
      var a = ang;                                                                     // the rock, in radians
      var llx = D.lx * Math.cos(a) + D.ly * Math.sin(a), lly = -D.lx * Math.sin(a) + D.ly * Math.cos(a);   // the light, seen from the egg's own tilted frame
      u.shadow(cx - D.lx * r * 0.5 + a * r * 2, GY, r * 0.9, r * 0.2, 0.4);
      u.ctx.save(); u.ctx.translate(cx, cy); u.ctx.rotate(a); u.ctx.scale(D.squeeze, 1);
      u.sphere(0, 0, r, D.shell, llx, lly, { dark: D.dark, spec: D.spec });           // one ball, squeezed: the gradient squeezes with it
      u.ctx.restore();
      u.label("a darker shell with a hotter highlight reads as lacquer — spec is the material dial; a slower rock reads as heavier", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) {
      D.lx = u.clamp((x - cx) / (r * 1.6), -1, 1); D.ly = u.clamp((y - cy) / (r * 1.6), -1, 1);
      if (cool <= 0) { av += (x < cx ? 1 : -1) * D.kick; cool = 0.4; }
    }
  };
});

rhymeOf("Eyeball", "Cat eye", "the same eye in yellow-green with a slit pupil (an ellipse squeezed to a quarter width) that snaps to the pointer", function make(u) {
  // rhyme of Eyeball: dials moved — hue 200 → 85, asp 1.0 → 0.25, white → cream, follow 6 → 12 (a stiffer spring: snap and settle)
  var D = { bg: ["#1A1A0E", "#0A0A06"], white: "#E8E0C8", hue: 85, asp: 0.25,
            lx: -0.5, ly: -0.55, follow: 12, damp: 0.6 };
  var cx = u.W * 0.5, cy = u.H * 0.47, r = Math.min(u.W, u.H) * 0.3;
  var tx = 0.25, ty = 0.1, px = 0.25, py = 0.1, vx = 0, vy = 0;                 // where it wants to look, where the pupil actually is, and how fast it is moving
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(cy + r * 1.1, "#0C0A16");
      u.shadow(cx - D.lx * r * 0.6, cy + r * 1.1, r * 1.05, r * 0.25, 0.5);
      u.sphere(cx, cy, r, D.white, D.lx, D.ly, { spec: 0.15, dark: "#8A7A8A" });
      var k = D.follow * D.follow, d = D.damp * 2 * D.follow, sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      for (var s = 0; s < sub; s++) {
        vx += (k * (tx - px) - d * vx) * h; vy += (k * (ty - py) - d * vy) * h;
        px = u.clamp(px + vx * h, -1.1, 1.1); py = u.clamp(py + vy * h, -1.1, 1.1);
      }
      var dd = Math.sqrt(px * px + py * py), sq = 1 - 0.35 * dd, ang = Math.atan2(py, px);   // the iris foreshortens as it turns toward the edge
      var ix = cx + px * r * 0.5, iy = cy + py * r * 0.5, ir = r * 0.42;
      u.ctx.save(); u.ctx.translate(ix, iy);
      u.ctx.rotate(ang); u.ctx.scale(sq, 1); u.ctx.rotate(-ang);                            // squeeze along the look direction only
      u.ctx.fillStyle = u.rad(0, 0, ir, [[0, u.hsl(D.hue, 0.6, 0.55)], [0.7, u.hsl(D.hue, 0.7, 0.35)], [1, u.hsl(D.hue, 0.5, 0.12)]]);
      u.ctx.beginPath(); u.ctx.arc(0, 0, ir, 0, u.TAU); u.ctx.fill();                       // the iris: a centred radial — it is flat, painted ON the ball
      u.ctx.fillStyle = "#08060C";
      u.ctx.beginPath(); u.ctx.ellipse(0, 0, ir * 0.42 * D.asp, ir * 0.42, 0, 0, u.TAU); u.ctx.fill();
      u.ctx.restore();
      u.soft(cx + D.lx * r * 0.5, cy + D.ly * r * 0.5, r * 0.16, "#FFFFFF", 0.95);        // the highlight belongs to the light, not to the eye
      u.label("the pupil is an ellipse dial: asp 0.25 makes a slit, and the slit slides under a highlight that never moves", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { tx = u.clamp((x - cx) / r, -1, 1); ty = u.clamp((y - cy) / r, -1, 1); }   // click = look there
  };
});

rhymeOf("Jupiter", "Candy planet", "the same striped planet in pastels with a pink spot, bands sliding twice as fast — cozy sci-fi", function make(u) {
  // rhyme of Jupiter: dials moved — bands/spot/night/bg palette to pastel, speed 0.25 → 0.6
  var D = { bg: ["#1A1030", "#2A1E4A"], bands: ["#F5C0D8", "#B8E8F5", "#FFF0B8", "#C8F5C8", "#F5D0F5", "#B8D8F5", "#FFD8C0", "#D8F5E8", "#F5C0D8"],
            spot: "#FF7AA8", night: "#1A1030", speed: 0.6, lx: -0.6, ly: -0.3 };
  var cx = u.W * 0.5, cy = u.H * 0.48, r = Math.min(u.W, u.H) * 0.36;
  var R = u.rng(7), stars = [];
  for (var s = 0; s < 40; s++) stars.push([R() * u.W, R() * u.H, 0.3 + R() * 1.0]);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      for (var s = 0; s < stars.length; s++) u.dot(stars[s][0], stars[s][1], stars[s][2], u.rgba(u.INK, 0.6));
      u.ctx.save(); u.ctx.beginPath(); u.ctx.arc(cx, cy, r, 0, u.TAU); u.ctx.clip();
      var n = D.bands.length, bh = (2 * r) / n;
      for (var i = 0; i < n; i++) {                                                 // each band: a strip with a wobbly top, painted top → bottom
        var top = cy - r + i * bh, sp = D.speed * (1 + (i % 3) * 0.7) * (i % 2 ? 1 : -1);   // neighbours slide at different speeds and directions
        u.ctx.fillStyle = D.bands[i];
        u.ctx.beginPath(); u.ctx.moveTo(cx - r, cy + r);
        for (var x = cx - r; x <= cx + r + 8; x += 8)
          u.ctx.lineTo(x, top + Math.sin(x / r * 3 + t * sp) * bh * 0.25 + Math.sin(x / r * 7 - t * sp * 1.7) * bh * 0.1);
        u.ctx.lineTo(cx + r + 8, cy + r); u.ctx.closePath(); u.ctx.fill();
      }
      var sx = cx + ((t * D.speed * 0.3 * r) % (2.6 * r)) - 1.3 * r;                 // the great spot, crossing and wrapping
      u.ctx.fillStyle = D.spot; u.ctx.beginPath(); u.ctx.ellipse(sx, cy + r * 0.3, r * 0.22, r * 0.12, 0, 0, u.TAU); u.ctx.fill();
      u.ctx.fillStyle = u.rad(cx, cy, r * 1.02, [[0, "rgba(255,240,220,0.18)"], [0.45, "rgba(0,0,0,0)"], [0.8, "rgba(5,5,16,0.55)"], [1, u.rgba(D.night, 0.98)]], D.lx * r * 0.5, D.ly * r * 0.5);
      u.ctx.fillRect(cx - r, cy - r, 2 * r, 2 * r);                                  // the roundness: one overlay, clear in the middle, dark at the rim, shifted toward the sun
      u.ctx.restore();
      u.label("pastel stripes, same dark overlay — the roundness lives in the overlay, not in the colours", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (r * 1.6), -1, 1); D.ly = u.clamp((y - cy) / (r * 1.6), -1, 1); }
  };
});

rhymeOf("Lozenge", "Pixel pill", "the same capsule in arcade green, shorter and spinning four times as fast — a power-up", function make(u) {
  // rhyme of Lozenge: dials moved — pill/bg palette to arcade, spin 0.3 → 1.2, len 1.8 → 1.2
  var D = { bg: ["#0A0A14", "#101020"], pill: "#3AF06A", spin: 1.2, len: 1.2,
            lx: -0.5, ly: -0.6 };
  var cx = u.W * 0.5, cy = u.H * 0.45, r = Math.min(u.W, u.H) * 0.15, GY = u.H * 0.82;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(GY, "#08090F");
      var a = t * D.spin, L = r * D.len, ca = Math.cos(a), sa = Math.sin(a);
      var llx = D.lx * ca + D.ly * sa, lly = -D.lx * sa + D.ly * ca;               // the light, seen from the pill's own turning frame
      u.shadow(cx - D.lx * r * 0.8, GY, L * Math.abs(ca) * 0.5 + r * 1.2, r * 0.35, 0.45);   // the shadow is as long as the pill looks
      u.ctx.save(); u.ctx.translate(cx, cy); u.ctx.rotate(a);
      var hi = u.clamp(0.5 + lly * 0.28, 0.05, 0.95);                              // the body's bright stripe, lined up with the caps' highlight
      u.ctx.fillStyle = u.lin(0, -r, 0, r, [[0, u.shade(D.pill, -0.55)], [hi, u.shade(D.pill, 0.35)], [u.clamp(hi + 0.3, 0, 1), D.pill], [1, u.shade(D.pill, -0.75)]]);
      u.ctx.fillRect(-L / 2, -r, L, 2 * r);                                        // the body: a cylinder lying down, so its gradient runs across
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(-L / 2 - r - 1, -r - 1, r + 1, 2 * r + 2); u.ctx.clip();
      u.sphere(-L / 2, 0, r, D.pill, llx, lly); u.ctx.restore();                  // the left cap: half a ball
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(L / 2, -r - 1, r + 1, 2 * r + 2); u.ctx.clip();
      u.sphere(L / 2, 0, r, D.pill, llx, lly); u.ctx.restore();                   // the right cap
      u.ctx.restore();
      u.label("arcade green, a shorter body, four times the spin — the highlight still refuses to turn with the pill", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (r * 3), -1, 1); D.ly = u.clamp((y - cy) / (r * 3), -1, 1); }
  };
});

rhymeOf("Pearl", "Black pearl", "the same pearl in near-black on a leather cushion, with a cyan rim and violet-green tints — a pirate's prize", function make(u) {
  // rhyme of Pearl: dials moved — pearl/dark/cushion/bg palette to dark, rim → cyan, hueA 320 → 260, hueB 190 → 160
  var D = { bg: ["#1A1410", "#080604"], pearl: "#2A2A38", rim: "#8AD9F5", dark: "#08080E",
            hueA: 260, hueB: 160, cushion: "#4A2A18", lx: -0.45, ly: -0.55 };
  var cx = u.W * 0.5, cy = u.H * 0.5, r = Math.min(u.W, u.H) * 0.2, GY = cy + r * 0.85;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ctx.fillStyle = u.rad(cx, GY + r * 0.5, u.W * 0.7, [[0, u.shade(D.cushion, 0.25)], [0.5, D.cushion], [1, u.shade(D.cushion, -0.6)]], D.lx * u.W * 0.2, -r);
      u.ctx.beginPath(); u.ctx.ellipse(cx, GY + r * 0.5, u.W * 0.7, r * 1.6, 0, 0, u.TAU); u.ctx.fill();   // the cushion: a soft mound, lit from the same side
      u.ctx.fillRect(0, GY + r * 0.5, u.W, u.H);
      u.shadow(cx - D.lx * r * 0.4, GY, r * 1.1, r * 0.3, 0.6);                                   // the dent it sits in — a contact shadow, tight and dark
      u.sphere(cx, cy, r, D.pearl, D.lx, D.ly, { spec: 0.55, rim: D.rim, dark: D.dark });
      var hx = cx + D.lx * r * 0.5, hy = cy + D.ly * r * 0.5;
      u.ctx.save(); u.ctx.beginPath(); u.ctx.arc(cx, cy, r, 0, u.TAU); u.ctx.clip();
      u.soft(hx - r * 0.2, hy + r * 0.15, r * 0.6, u.hsl(D.hueA, 0.8, 0.7), 0.35);              // two hues, one each side of the highlight
      u.soft(hx + r * 0.25, hy - r * 0.1, r * 0.6, u.hsl(D.hueB, 0.8, 0.7), 0.35);
      u.soft(hx, hy, r * 0.4, "#FFFFFF", 0.7);                                                    // the highlight itself: wide and soft, because nacre is not glass
      u.ctx.restore();
      u.label("a dark pearl is mostly rim light and colour shift — take the base colour away and the edge still says round", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (r * 2.5), -1, 1); D.ly = u.clamp((y - cy) / (r * 2.5), -1, 1); }
  };
});

rhymeOf("Quicksilver", "Gold ball", "the same two balls in gold: the mirror reflects a warm sky and a bronze ground, the matte one is brass", function make(u) {
  // rhyme of Quicksilver: dials moved — matte/skyHi/skyLo/groundHi/groundLo/bg palette to golds
  var D = { bg: ["#3A2A18", "#141008"], matte: "#C89A3A", skyHi: "#FFF0C0", skyLo: "#D8A040",
            groundHi: "#6A3A10", groundLo: "#1A0C04", lx: -0.5, ly: -0.55 };
  var r = Math.min(u.W, u.H) * 0.2, cy = u.H * 0.47, ax = u.W * 0.28, bx = u.W * 0.72, GY = cy + r * 1.15;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(GY, "#0C0D14");
      u.shadow(ax - D.lx * r * 0.6, GY, r * 1.05, r * 0.25, 0.5);
      u.shadow(bx - D.lx * r * 0.6, GY, r * 1.05, r * 0.25, 0.5);
      u.sphere(ax, cy, r, D.matte, D.lx, D.ly, { spec: 0.4 });                                 // matte: the light spreads over the surface
      u.ctx.save(); u.ctx.beginPath(); u.ctx.arc(bx, cy, r, 0, u.TAU); u.ctx.clip();
      var hz = cy + r * 0.12;                                                                   // the reflected horizon, a little below centre
      u.ctx.fillStyle = u.lin(0, cy - r, 0, hz, [[0, D.skyLo], [1, D.skyHi]]);                // the sky, reflected: dark overhead, pale at the horizon
      u.ctx.fillRect(bx - r, cy - r, 2 * r, hz - (cy - r));
      u.ctx.fillStyle = u.lin(0, hz, 0, cy + r, [[0, D.groundHi], [1, D.groundLo]]);
      u.ctx.fillRect(bx - r, hz, 2 * r, cy + r - hz);                                           // the ground, reflected: warm near the horizon, black below
      u.ctx.fillStyle = u.rad(bx, cy, r * 1.02, [[0.6, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,0.55)"]], D.lx * r * 0.3, D.ly * r * 0.3);
      u.ctx.fillRect(bx - r, cy - r, 2 * r, 2 * r);                                             // the rim darkens as the mirror curves away
      u.dot(bx + D.lx * r * 0.55, cy + D.ly * r * 0.55, r * 0.09, "#FFFFFF");                 // mirror: the light itself, tiny and sharp
      u.ctx.restore();
      u.label("matte", ax, cy - r - 8, null, "center"); u.label("mirror", bx, cy - r - 8, null, "center");
      u.label("tint the reflected sky and ground and the mirror turns to gold — a metal is whatever it reflects, warmed", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - u.W / 2) / (u.W * 0.5), -1, 1); D.ly = u.clamp((y - cy) / (r * 2), -1, 1); }
  };
});

rhymeOf("Torus", "Doughnut", "the same ring with pink icing, brown edges, a fatter tube and 28 sprinkles — goofy and edible", function make(u) {
  // rhyme of Torus: dials moved — tube/dark/bg palette to pastry, fat 0.42 → 0.5, spin 0.4 → 0.25, sprinkles 0 → 28
  var D = { bg: ["#F5E6D8", "#D8C0A8"], tube: "#F58AB8", dark: "#8A5A30", fat: 0.5,
            spin: 0.25, sprinkles: 28 };
  var cx = u.W * 0.5, cy = u.H * 0.46, Ro = Math.min(u.W, u.H) * 0.34;
  var a = Ro * D.fat / (1 + D.fat), Rc = Ro - a, Ri = Rc - a;                            // tube radius, the tube's centre radius, the hole's radius
  var R = u.rng(5), sp = [];
  for (var j = 0; j < D.sprinkles; j++) { var an = R() * u.TAU, rr = Rc + (R() - 0.5) * a * 1.3; sp.push([cx + Math.cos(an) * rr, cy + Math.sin(an) * rr, R() * u.TAU, u.hsl(R() * 360, 0.85, 0.6)]); }
  var phase = 0, lastT = 0;
  function ring() { u.ctx.beginPath(); u.ctx.arc(cx, cy, Ro, 0, u.TAU); u.ctx.arc(cx, cy, Ri, 0, u.TAU, true); }   // outer edge, then the hole drawn backwards
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      lastT = t;
      u.sky(D.bg);
      var GY = cy + Ro * 1.1; u.ground(GY, "#07080E");
      var ang = t * D.spin + phase, lx = Math.cos(ang) * 0.7, ly = Math.sin(ang) * 0.7;   // the light circles slowly; the ring itself never moves
      u.shadow(cx - lx * Ro * 0.4, GY, Ro * 1.1, Ro * 0.22, 0.5);
      ring();
      u.ctx.fillStyle = u.rad(cx, cy, Ro, [[Ri / Ro, D.dark], [(Rc - a * 0.35) / Ro, u.shade(D.tube, 0.4)], [Rc / Ro, D.tube], [(Rc + a * 0.6) / Ro, u.shade(D.tube, -0.3)], [1, D.dark]], lx * a * 0.9, ly * a * 0.9);
      u.ctx.fill();                                                                       // dark at the hole, bright at the tube's crown, dark at the outer edge
      ring();
      u.ctx.fillStyle = u.lin(cx + lx / 0.7 * Ro, cy + ly / 0.7 * Ro, cx - lx / 0.7 * Ro, cy - ly / 0.7 * Ro, [[0, "rgba(0,0,0,0)"], [0.5, "rgba(0,0,0,0.08)"], [1, "rgba(0,0,0,0.55)"]]);
      u.ctx.fill();                                                                       // the far half turns away from the light: one linear wash
      for (var s = 0; s < sp.length; s++) {
        u.ctx.save(); u.ctx.translate(sp[s][0], sp[s][1]); u.ctx.rotate(sp[s][2]);
        u.ctx.fillStyle = sp[s][3]; u.ctx.fillRect(-a * 0.14, -a * 0.05, a * 0.28, a * 0.1); u.ctx.restore();
      }
      u.label("pink crown, brown edges, 28 sprinkles: each sprinkle is a flat dash, so only the shading says the ring is fat", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { phase = Math.atan2(y - cy, x - cx) - lastT * D.spin; }        // click = put the light on that side
  };
});

rhymeOf("Urn", "Sci-fi canister", "the same lathe profile in steel with a neon band and 24 fat slices — the rings now show, on purpose", function make(u) {
  // rhyme of Urn: dials moved — clay/band/bg palette to steel + neon, slices 40 → 24
  var D = { bg: ["#0A1420", "#04080E"], clay: "#6A7A8A", band: "#40F0F0", slices: 24,
            lx: -0.35, ly: -0.5 };
  var cx = u.W * 0.5, top = u.H * 0.12, bot = u.H * 0.8, Hh = bot - top, wmax = Math.min(u.W * 0.2, Hh * 0.36);   // wmax: the belly's half-width
  function prof(k) {                                                                     // k: 0 at the lip … 1 at the foot → half-width, as a share of wmax
    if (k < 0.05) return 0.44;                                                           // the lip
    if (k < 0.2) return 0.3 + (k - 0.05) * 0.4;                                          // the neck, widening
    if (k < 0.86) return 0.36 + 0.64 * Math.sin((k - 0.2) / 0.66 * Math.PI);            // the belly: half a sine
    if (k < 0.94) return 0.3;                                                            // the stem
    return 0.46;                                                                         // the foot
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(bot, "#0E0B14");
      u.shadow(cx - D.lx * wmax * 0.8, bot, wmax * 1.4, wmax * 0.3, 0.5);
      var sh = Hh / D.slices;
      for (var i = 0; i < D.slices; i++) {
        var k = (i + 0.5) / D.slices, w = prof(k) * wmax * 2;
        var c = u.shade(i > D.slices * 0.5 && i < D.slices * 0.58 ? D.band : D.clay, -D.ly * (0.5 - k) * 0.4);   // slices nearer a high light are a little brighter
        u.cyl(cx, top + (i + 1) * sh + 0.6, w, sh + 0.6, c, D.lx);                        // one short cylinder per slice; the widths draw the vase
      }
      u.ctx.fillStyle = u.shade(D.clay, -0.65);                                            // the mouth: we look down into the dark inside
      u.ctx.beginPath(); u.ctx.ellipse(cx, top, prof(0) * wmax * 0.85, sh * 1.2, 0, 0, u.TAU); u.ctx.fill();
      u.label("steel grey, a neon band, 24 fatter slices — the same lathe, now visibly a stack of rings", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lx = u.clamp((x - cx) / (u.W * 0.4), -1, 1); D.ly = u.clamp((y - (top + bot) / 2) / (Hh * 0.6), -1, 1); }
  };
});

rhymeOf("Yolk", "Quail yolk", "the same fried egg at two-thirds size with 30 speckles on the white and a deeper orange yolk — a smaller breakfast", function make(u) {
  // rhyme of Yolk: dials moved — size 1.0 → 0.62, speckles 0 → 30, yolk → deeper orange, spec 0.7 → 0.8, pan palette
  var D = { pan: ["#4A4238", "#1E1A14"], white: "#FFFBF2", yolk: "#E88A10", yolkDark: "#B85A10", spec: 0.8,
            size: 0.62, speckles: 30, lx: -0.5, ly: -0.6 };
  var cx = u.W * 0.5, cy = u.H * 0.5, rw = Math.min(u.W, u.H) * 0.36 * D.size, ry = rw * 0.42;              // rw: the white's radius; ry: the yolk's
  var R = u.rng(9), spk = [];
  for (var j = 0; j < D.speckles; j++) { var an = R() * u.TAU, d = 0.55 + R() * 0.4; spk.push([cx + Math.cos(an) * rw * 1.15 * d, cy + Math.sin(an) * rw * 0.8 * d, 0.6 + R() * 1.2]); }
  var jig = 0, vel = 0;                                                                                       // the spring: how squashed the yolk is, and how fast that's changing
  return {
    frame: function (dt, t) {
      u.ctx.fillStyle = u.rad(cx, cy, u.W * 0.7, D.pan); u.ctx.fillRect(0, 0, u.W, u.H);                    // the pan, lit from the middle
      vel += (-jig * 90 - vel * 5) * dt; jig = u.clamp(jig + vel * dt, -0.45, 0.45);                          // stiffness 90, damping 5
      u.ctx.save(); u.ctx.translate(cx, cy); u.ctx.scale(1.25, 0.9);
      u.ctx.fillStyle = u.rad(0, 0, rw, [[0, D.white], [0.7, D.white], [0.88, u.rgba(D.white, 0.8)], [1, u.rgba(D.white, 0)]]);   // the white thins to nothing at its edge
      u.ctx.beginPath();
      for (var i = 0; i <= 24; i++) { var an = i / 24 * u.TAU, rr = rw * (0.9 + 0.1 * Math.sin(an * 3 + 1) + 0.05 * Math.sin(an * 5)); u.ctx.lineTo(Math.cos(an) * rr, Math.sin(an) * rr); }
      u.ctx.closePath(); u.ctx.fill();
      u.ctx.restore();
      for (var s = 0; s < spk.length; s++) u.dot(spk[s][0], spk[s][1], spk[s][2], "#6A4A3A");
      u.shadow(cx - D.lx * ry * 0.3, cy + ry * 0.55, ry * 1.1, ry * 0.4, 0.25);                             // the yolk's contact shadow on the white
      u.ctx.save(); u.ctx.translate(cx, cy + ry * 0.1); u.ctx.scale(1 + jig, 0.78 - jig);                  // squash one way, stretch the other: volume looks kept
      u.sphere(0, 0, ry, D.yolk, D.lx, D.ly, { spec: D.spec, dark: D.yolkDark });                           // the yolk: a ball, flattened
      u.ctx.restore();
      u.label("smaller, speckled: the speckles are flat dots on the white, and the yolk's highlight is still what says ball", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { vel += 2.5; }                                                                   // a poke; the spring takes it from here
  };
});

rhymeOf("Zeppelin", "Steampunk zeppelin", "the same airship in brass under a sepia sky, longer and drifting at half speed — Victorian sci-fi", function make(u) {
  // rhyme of Zeppelin: dials moved — sky/hull/hullDark/gondola palette to brass + sepia, stretch 2.4 → 2.8, speed 0.6 → 0.25
  var D = { sky: ["#A88A5A", "#E8D8B8"], hull: "#B8863A", hullDark: "#3A2810", gondola: "#4A3018",
            stretch: 2.8, speed: 0.25, lx: -0.5, ly: -0.6,
            buoy: 4, damp: 0.35, pitch: 0.25, gust: 0.7 };                                       // the same springs: bob stiffness, damping of critical, nose-up per climb, the air's rate
  var r = Math.min(u.W, u.H) * 0.11, cy = u.H * 0.4, GY = u.H * 0.78;
  var R = u.rng(6), puffs = [];
  for (var j = 0; j < 12; j++) puffs.push([R() * u.W, GY + R() * (u.H - GY) * 0.6, u.W * (0.06 + R() * 0.08)]);
  var bob = 0, bv = 0, pt = 0, pv = 0, cool = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ctx.fillStyle = u.lin(0, GY - 10, 0, u.H, ["#F5F7FA", "#B8C8DC"]); u.ctx.fillRect(0, GY, u.W, u.H - GY);   // the cloud floor
      for (var j = 0; j < puffs.length; j++) u.soft(puffs[j][0], puffs[j][1], puffs[j][2], "#FFFFFF", 0.7);
      var rest = (Math.sin(t * D.gust) + 0.4 * Math.sin(t * D.gust * 2.3 + 1)) * r * 0.25;
      var k = D.buoy, d = D.damp * 2 * Math.sqrt(k), kp = 9, dp = 0.5 * 2 * 3;
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      cool -= dt;
      for (var s = 0; s < sub; s++) {
        bv += (k * (rest - bob) - d * bv) * h; bob = u.clamp(bob + bv * h, -r, r);
        pv += (kp * (bv / r * D.pitch - pt) - dp * pv) * h; pt = u.clamp(pt + pv * h, -0.35, 0.35);
      }
      var span = u.W + r * D.stretch * 2.6, bx = ((t * D.speed * 40) % span) - r * D.stretch * 1.3;               // drifts across, then wraps
      var by = cy + bob;
      var llx = D.lx * Math.cos(pt) + D.ly * Math.sin(pt), lly = -D.lx * Math.sin(pt) + D.ly * Math.cos(pt);
      u.shadow(bx - D.lx * r * 0.5, GY + 6, r * D.stretch * 0.9, r * 0.28, 0.18);                                  // far below: faint and soft, like the clouds it lands on
      u.ctx.save(); u.ctx.translate(bx, by); u.ctx.rotate(pt);
      var tail = -r * D.stretch * 0.75;
      u.poly([[tail, -r * 0.4], [tail - r * 0.9, -r * 1.3], [tail - r * 0.55, 0]], u.shade(D.hull, 0.1));            // the top fin faces the light…
      u.poly([[tail, r * 0.4], [tail - r * 0.9, r * 1.3], [tail - r * 0.55, 0]], u.shade(D.hull, -0.5));             // …the bottom fin doesn't
      u.ctx.save(); u.ctx.scale(D.stretch, 1);
      u.sphere(0, 0, r, D.hull, llx, lly, { dark: D.hullDark, spec: 0.3 });                                         // the hull: one ball, stretched — the gradient stretches with it
      u.ctx.restore();
      u.ctx.fillStyle = D.gondola; u.ctx.fillRect(-r * 0.5, r * 0.85, r, r * 0.35);                                // the gondola hangs under the belly
      u.ctx.restore();
      u.label("brass and sepia, a longer hull, half the drift — the stretched gradient stretches as far as you like", u.W / 2, u.H - 8, "rgba(20,24,40,0.75)", "center");   // dark ink: the floor is pale
    },
    press: function (x, y) {
      D.lx = u.clamp((x - u.W / 2) / (u.W * 0.5), -1, 1); D.ly = u.clamp((y - cy) / (r * 3), -1, 1);
      if (cool <= 0) { bv -= r * 1.5; cool = 1.2; }
    }
  };
});
/* ============================== FACETS & BLOCKS ==============================
   Three flat shades meeting at an edge — that is a cube, and a cube is the
   whole isometric world. No gradient inside a face: the light is ONE
   direction (upper-left, always), so the top is lit, the left is the colour
   itself, the right is dark. Keep that rule across every block in the
   picture and the blocks share a world; draw the far ones first and they
   stack. Thirteen pictures, each one a list of faces and an order. */

def("B", "Block", "facet", "one cube, three flat shades: top lit, left the colour itself, right dark — an edge is where two shades meet; press moves the light round", function make(u) {
  var D = { sky: ["#1A1830", "#2A2848"], floor: "#1A1A2E", col: "#6A8FD8",
            size: 0.22, alpha: 1, edge: 0 };                               // size = cube edge as a fraction of W; alpha = face opacity; edge = outline alpha (0 = none)
  var lights = [[-1, -1], [1, -1], [-1, 1], [1, 1]];                        // where the light sits: upper-left, upper-right, lower-left, lower-right
  var li = 0;
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = u.W * D.size, dx = 0.866 * s, dy = 0.5 * s, h = s;
      var x = u.W / 2, y = u.H * 0.8, L = lights[li];
      u.ground(y - dy * 2.4, D.floor);
      var kTop = L[1] < 0 ? 0.32 : 0;                                      // light from above: the top is the lit face
      var kL = L[0] < 0 ? (L[1] < 0 ? 0 : 0.32) : -0.42;                   // the face toward the light is lit or mid...
      var kR = L[0] > 0 ? (L[1] < 0 ? 0 : 0.32) : -0.42;                   // ...the face away from it is dark
      var lp = [x + L[0] * u.W * 0.36, y - h / 2 - dy / 2 + L[1] * u.H * 0.28];   // the light itself, so you can see it move
      u.soft(lp[0], lp[1], u.W * 0.1, "#FFF3D0", 0.7);
      u.shadow(x - L[0] * dx * 0.25, y - dy * 0.35, dx * 1.5, dy * 1.5, 0.5);    // contact shadow, nudged away from the light
      u.cube(x, y, s, D.col, { top: u.rgba(u.shade(D.col, kTop), D.alpha), left: u.rgba(u.shade(D.col, kL), D.alpha), right: u.rgba(u.shade(D.col, kR), D.alpha) });
      if (D.edge > 0) {                                                      // outlines: all twelve edges, the hidden three included
        var F = [x, y], Lc = [x - dx, y - dy], Rc = [x + dx, y - dy], B = [x, y - 2 * dy];
        var E = [[F, Lc], [F, Rc], [Lc, B], [Rc, B]];
        for (var i = 0; i < 4; i++) { var a = E[i][0], b = E[i][1]; u.line(a[0], a[1], b[0], b[1], u.rgba(u.INK, D.edge)); u.line(a[0], a[1] - h, b[0], b[1] - h, u.rgba(u.INK, D.edge)); }
        var V = [F, Lc, Rc, B];
        for (var j = 0; j < 4; j++) u.line(V[j][0], V[j][1], V[j][0], V[j][1] - h, u.rgba(u.INK, D.edge));
      }
      function name(k) { return k > 0.1 ? "lit" : (k < -0.1 ? "dark" : "mid"); }
      u.label(name(kTop), x, y - h - dy + 3, u.rgba(u.INK, 0.85), "center");
      u.label(name(kL), x - dx / 2, y - dy / 2 - h / 2 + 3, u.rgba(u.INK, 0.85), "center");
      u.label(name(kR), x + dx / 2, y - dy / 2 - h / 2 + 3, u.rgba(u.INK, 0.85), "center");
      u.label("three flat shades = a solid; no gradient inside a face, only at the edges between them", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { li = (li + 1) % 4; }                          // walk the light round the four corners
  };
});

def("G", "Gem", "facet", "a faceted stone: each triangle is one flat shade set by how squarely it faces the light — the stone turns and the shades walk round it; press to nudge it and it spins up, then coasts back down", function make(u) {
  var D = { sky: ["#0E0C1E", "#1E1A36"], col: "#5AC8E8", spin: 0.7,
            sides: 6, crown: 0.45, pav: 1.1,                                // crown/pav = the point above / below the rim, in radii
            kick: 3, drag: 1.2,                                             // kick = angular velocity a full-width press adds, rad/s; drag = how fast that nudge coasts down, per second
            bob: 8, bobdamp: 0.08 };                                        // bob = the float's spring stiffness; bobdamp = its damping as a fraction of critical (tiny: it keeps bobbing)
  var Lt = [-0.5, 0.75, 0.45], ln = Math.sqrt(Lt[0] * Lt[0] + Lt[1] * Lt[1] + Lt[2] * Lt[2]);
  Lt = [Lt[0] / ln, Lt[1] / ln, Lt[2] / ln];                                // the light: upper-left, a little toward us
  // the stone turns at its idle rate (spin) plus whatever a nudge left it:
  // a press adds angular VELOCITY, not an angle, and drag eats a share of
  // it every step, so the stone spins up and coasts back down to its idle
  // turn instead of jumping. the float is a spring around a rest height,
  // damped far under critical, so it bobs for a long while and a press
  // bumps it — nothing here is a sine of the clock.
  var ang = 0, angv = 0, bob = 0, bobv = 0.5;                                // the turn, the nudge's leftover rate, the float (in radii) and its rate
  function facets(a) {                                                       // rebuild the triangles for rotation a
    var n = D.sides, rim = [], out = [];
    for (var i = 0; i < n; i++) { var q = a + i / n * u.TAU; rim.push([Math.cos(q), 0, Math.sin(q)]); }
    for (var j = 0; j < n; j++) {
      out.push([[0, D.crown, 0], rim[j], rim[(j + 1) % n]]);                // crown: rim to the top point
      out.push([[0, -D.pav, 0], rim[(j + 1) % n], rim[j]]);                  // pavilion: rim to the bottom point
    }
    return out;
  }
  return {
    frame: function (dt, t) {
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      var bd = D.bobdamp * 2 * Math.sqrt(D.bob);                             // the float's damping, from its fraction of critical
      for (var s = 0; s < sub; s++) {
        angv -= angv * D.drag * h; ang += (D.spin + angv) * h;              // idle rate + the nudge, which drag wears away
        bobv += (-D.bob * bob - bd * bobv) * h; bob = u.clamp(bob + bobv * h, -0.3, 0.3);
      }
      ang = ang % u.TAU;
      u.sky(D.sky);
      var r = Math.min(u.W, u.H) * 0.26, cx = u.W / 2, cy = u.H * 0.46 + bob * r * 0.4;
      var F = facets(ang), cz = (D.crown - D.pav) / 2, best = null;
      for (var i = 0; i < F.length; i++) {
        var p = F[i], e1 = [p[1][0] - p[0][0], p[1][1] - p[0][1], p[1][2] - p[0][2]], e2 = [p[2][0] - p[0][0], p[2][1] - p[0][1], p[2][2] - p[0][2]];
        var nx = e1[1] * e2[2] - e1[2] * e2[1], ny = e1[2] * e2[0] - e1[0] * e2[2], nz = e1[0] * e2[1] - e1[1] * e2[0];
        var m = Math.sqrt(nx * nx + ny * ny + nz * nz) || 1; nx /= m; ny /= m; nz /= m;
        var gx = (p[0][0] + p[1][0] + p[2][0]) / 3, gy = (p[0][1] + p[1][1] + p[2][1]) / 3 - cz, gz = (p[0][2] + p[1][2] + p[2][2]) / 3;
        if (nx * gx + ny * gy + nz * gz < 0) { nx = -nx; ny = -ny; nz = -nz; }   // the normal must point OUT of the stone
        p.k = nx * Lt[0] + ny * Lt[1] + nz * Lt[2];                          // −1..1: how squarely this facet faces the light
        p.z = gz;
        if (!best || p.k > best.k) best = p;
      }
      F.sort(function (A, B) { return A.z - B.z; });                         // far facets first — painter's order
      u.shadow(cx, cy + r * D.pav * 0.85 + r * 0.2, r * 0.8, r * 0.22, 0.4);
      for (var f = 0; f < F.length; f++) {
        var q = F[f], pts = [];
        for (var j = 0; j < 3; j++) pts.push([cx + q[j][0] * r, cy - q[j][1] * r * 0.8 + q[j][2] * r * 0.35]);   // tilted: we look down a little
        u.poly(pts, u.shade(D.col, q.k * 0.5));
      }
      if (best.k > 0.8) u.soft(cx + (best[0][0] + best[1][0] + best[2][0]) / 3 * r, cy - (best[0][1] + best[1][1] + best[2][1]) / 3 * r * 0.8 + best.z * r * 0.35, r * 0.4, "#FFFFFF", (best.k - 0.8) * 3);   // the facet squarest to the light sparkles
      u.label("shade = how squarely the face meets the light — turning changes nothing but that; the turn is a rate a nudge adds to and drag wears down", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { angv += (x / u.W - 0.5) * 2 * D.kick; bobv -= 0.6; }   // a nudge: angular velocity, left or right of centre — and a bump to the float
  };
});

def("H", "Hexprism", "facet", "a six-sided column: the hexagon top is the lit shade, each visible side a shade set by which way it faces — press turns it 60°: it swings past, rocks back, and the shades walk round", function make(u) {
  var D = { sky: ["#141226", "#26223E"], floor: "#1A1A2C", cols: ["#B87A5A"],
            count: 1, h: 0.5, r: 0.16, every: 2,                          // count of prisms; h and r as fractions of H and W; every = seconds between idle turns
            k: 64, zeta: 0.4 };                                             // k = the turn's spring stiffness for a column of height h (taller = heavier = softer); zeta = damping as a fraction of critical — under 1, so it turns past the detent and rocks back
  var R = u.rng(7), prisms = [];
  for (var i = 0; i < D.count; i++) prisms.push({ x: (i + 0.5) / D.count, h: D.h * (D.count > 1 ? 0.55 + R() * 0.7 : 1), c: D.cols[i % D.cols.length] });
  // a press moves the DETENT — the angle the column wants — on by 60°. the
  // column itself has an angular velocity and a spring toward the detent,
  // damped under critical, so it swings past, rocks back and settles rather
  // than easing in. every column keeps its own angle and rate, and a taller
  // column is a heavier one (a softer spring per height), so the rhyme's
  // five columns share one detent and arrive on their own phases.
  var turn = new Float32Array(prisms.length), om = new Float32Array(prisms.length), target = 0, nextAt = D.every;   // each column's angle and angular velocity; the shared detent
  return {
    frame: function (dt, t) {
      if (t > nextAt) { target += u.TAU / 6; nextAt = t + D.every; }        // the idle turn: the detent moves on
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      for (var p = 0; p < prisms.length; p++) {
        var kp = D.k * D.h / prisms[p].h, dp = D.zeta * 2 * Math.sqrt(kp);   // a taller column: more inertia, so a softer spring — and its own critical damping
        for (var s = 0; s < sub; s++) { om[p] += (kp * (target - turn[p]) - dp * om[p]) * h; turn[p] += om[p] * h; }
      }
      u.sky(D.sky);
      var gy = u.H * 0.82;
      u.ground(gy - u.H * 0.22, D.floor);
      for (var p = 0; p < prisms.length; p++) {
        var P = prisms[p], cx = u.W * P.x, r = u.W * D.r / (D.count > 1 ? Math.sqrt(D.count) * 0.8 : 1), hp = u.H * P.h, tp = turn[p];
        u.shadow(cx + r * 0.35, gy, r * 1.4, r * 0.6, 0.45);
        var v = [];
        for (var i = 0; i < 6; i++) { var q = tp + i * u.TAU / 6; v.push([cx + Math.cos(q) * r, gy + Math.sin(q) * r * 0.5]); }
        for (var j = 0; j < 6; j++) {
          var A = v[j], B = v[(j + 1) % 6], mid = tp + (j + 0.5) * u.TAU / 6;   // the direction this side faces
          if (Math.sin(mid) <= 0) continue;                                 // it faces away from us
          u.poly([A, B, [B[0], B[1] - hp], [A[0], A[1] - hp]], u.shade(P.c, -0.21 - 0.21 * Math.cos(mid)));   // facing left = the colour, facing right = dark
        }
        var top = [];
        for (var k = 0; k < 6; k++) top.push([v[k][0], v[k][1] - hp]);
        u.poly(top, u.shade(P.c, 0.32));
      }
      u.label("one rule for every side — shade by the way it faces — and the top stays lit whatever the turn; the turn is a spring to a detent, so it overshoots", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { target += u.TAU / 6; nextAt += D.every; }       // one more sixth of a turn: the detent moves, the spring does the rest
  };
});

def("I", "Isotile", "facet", "an isometric floor: diamonds in two alternating colours with a darker line on their right and bottom edges — and a ball whose shadow never leaves the floor; click and it rolls there, a little past, and settles", function make(u) {
  var D = { sky: ["#141226", "#221E3A"], a: "#6A8ACF", b: "#8AA6DF", edge: -0.45, ball: "#F58A8A",
            n: 8, speed: 0.6, glow: 0,                                     // n tiles a side; glow = a warm torch tint over the floor (0 = none)
            k: 36, zeta: 0.5 };                                             // k = the pull toward where the ball is going; zeta = damping as a fraction of critical — under 1, so it rolls a little past and settles back
  // the ball has a velocity: a spring pulls it toward its aim (a click, or
  // the idle circle) and damping under critical lets it roll a little past
  // and come back — it arrives like a ball, not like a cursor. the shadow is
  // drawn at the ball's grid position on the floor whatever the ball does,
  // which is the lesson.
  var ball = { x: 4, y: 4 }, vel = { x: 0, y: 0 }, target = null;           // grid position, grid velocity (cells per second), the clicked aim
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = Math.min(u.W * 0.065, u.H * 0.1), ox = u.W / 2, oy = u.H * 0.12;
      function P(ix, iy, iz) { var p = u.iso(ix, iy, iz || 0, s); return [ox + p[0], oy + p[1]]; }
      for (var iy = 0; iy < D.n; iy++) for (var ix = 0; ix < D.n; ix++) {
        var c = (ix + iy) % 2 ? D.a : D.b, q = [P(ix, iy), P(ix + 1, iy), P(ix + 1, iy + 1), P(ix, iy + 1)];
        u.poly(q, c);
        u.line(q[1][0], q[1][1], q[2][0], q[2][1], u.shade(c, D.edge), 1);   // the right edge and the bottom edge, darker:
        u.line(q[3][0], q[3][1], q[2][0], q[2][1], u.shade(c, D.edge), 1);   // a tile has a tiny thickness, and it faces the same light
      }
      if (D.glow > 0) u.soft(ox, oy + s * D.n * 0.5, s * D.n * 0.75, "#F5A15A", D.glow);
      var ax = D.n / 2 + 2.6 * Math.cos(t * D.speed), ay = D.n / 2 + 2.6 * Math.sin(t * D.speed);   // the idle path: a circle
      if (target) { ax = target.x; ay = target.y; if (Math.abs(ax - ball.x) + Math.abs(ay - ball.y) < 0.05 && Math.abs(vel.x) + Math.abs(vel.y) < 0.3) target = null; }   // there, and at rest: back to the idle path
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      var damp = D.zeta * 2 * Math.sqrt(D.k);                                // damping from its fraction of critical
      for (var st = 0; st < sub; st++) {
        vel.x += (D.k * (ax - ball.x) - damp * vel.x) * h; vel.y += (D.k * (ay - ball.y) - damp * vel.y) * h;
        ball.x = u.clamp(ball.x + vel.x * h, 0.3, D.n - 0.3); ball.y = u.clamp(ball.y + vel.y * h, 0.3, D.n - 0.3);   // the floor has an edge
      }
      var g = P(ball.x, ball.y), rb = s * 0.45;
      u.shadow(g[0], g[1], rb * 1.15, rb * 0.55, 0.5);                       // the shadow sits ON the floor: that is what keeps the ball on it
      u.sphere(g[0], g[1] - rb, rb, D.ball, -0.5, -0.6, { spec: 0.5 });
      u.label("two colours and a dark right-and-bottom edge make a floor; the shadow glues the ball to it — the ball is a spring toward its aim, so it overshoots", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) {                                                 // click = roll the ball there (screen → iso grid): the aim moves, the spring does the rolling
      var s = Math.min(u.W * 0.065, u.H * 0.1), sx = x - u.W / 2, sy = y - u.H * 0.12;
      target = { x: u.clamp((sx / (0.866 * s) + 2 * sy / s) / 2, 0.5, D.n - 0.5), y: u.clamp((2 * sy / s - sx / (0.866 * s)) / 2, 0.5, D.n - 0.5) };
    }
  };
});

def("K", "Keep", "facet", "a castle tower from stacked blocks: one tall block, small blocks for the battlements, a dark doorway — every face obeys the same light, so it is one building; press a side and the wind turns: the flag falls slack and whips round", function make(u) {
  var D = { sky: ["#2A3A6A", "#8AA0C8"], floor: "#3A5A3A", stone: "#9A8E86", flag: "#F58A8A",
            h: 2.4, wind: 1,                                               // h = tower height in widths; wind = the wind asked for: sign = direction, size = strength
            k: 50, zeta: 0.35, lag: 2.5, droop: 0.25, flap: 0.12 };            // k = the flag tip's stiffness; zeta = damping as a fraction of critical (under 1: it whips past); lag = how fast the wind at the flag catches up with the dial, per second; droop = gravity's pull on the tip against a unit wind; flap = the flutter, radians per unit wind
  var sunL = true, w = D.wind, th = Math.atan2(D.droop, D.wind), om = 0;   // the wind at the flag (it lags the dial); the tip's angle from the pole (0 = streaming right, π/2 = hanging, π = streaming left) and its rate
  // the flag is one angle at its tip. the wind the flag feels chases the
  // wind you asked for (a lag, not a switch), and the tip is a spring toward
  // the angle wind and gravity agree on — straight downwind, drooping a
  // little. flip the wind and that rest angle walks through 'hanging
  // straight down' as the lagging wind passes zero, and the under-damped tip
  // whips through the slack after it: a flag turning round, not a flag
  // mirrored. the flutter is a small forcing on the same spring, quicker
  // in more wind.
  function blk(x, y, s, c, h) {                                              // a block under THIS picture's sun — mirrored when the sun is on the right
    u.cube(x, y, s, c, { h: h, left: sunL ? c : u.shade(c, -0.42), right: sunL ? u.shade(c, -0.42) : c });
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      var damp = D.zeta * 2 * Math.sqrt(D.k);                                // damping from its fraction of critical
      for (var st = 0; st < sub; st++) {
        w += (D.wind - w) * D.lag * h;                                       // the wind at the flag catches up with the dial
        var rest = Math.atan2(D.droop, w) + Math.sin(t * 9 * Math.abs(w)) * D.flap * Math.abs(w);   // downwind and a little down (π/2 when the wind is nil), plus the flutter
        om += (D.k * (rest - th) - damp * om) * h; th = u.clamp(th + om * h, -0.8, u.TAU / 2 + 0.8);
      }
      u.sky(D.sky);
      var s = Math.min(u.W * 0.16, u.H * 0.14), dx = 0.866 * s, dy = 0.5 * s, h2 = s * D.h;
      var x = u.W / 2, y = u.H * 0.84, m = s / 5;
      u.ground(y - dy * 2.6, D.floor);
      u.soft(sunL ? u.W * 0.1 : u.W * 0.9, u.H * 0.12, u.W * 0.14, "#FFF3D0", 0.8);
      u.shadow(x + (sunL ? 1 : -1) * dx * 0.9, y - dy * 0.5, dx * 2.4, dy * 1.5, 0.4);
      blk(x - dx * 1.3, y - dy * 0.9, s * 0.7, D.stone, s * 0.8);            // an annex, behind-left — drawn first
      blk(x, y, s, D.stone, h2);                                              // the tower
      var f1 = 0.36, f2 = 0.64, dh = s * 0.55;                                // the doorway, on the left face
      u.poly([[x - dx * f1, y - dy * f1], [x - dx * f2, y - dy * f2], [x - dx * f2, y - dy * f2 - dh], [x - dx * f1, y - dy * f1 - dh]], "#0E0B1A");
      var ox = x, oy = y - h2 - 2 * dy;                                       // the top face's back corner: origin for the battlements
      var cells = [[0, 0], [0, 2], [2, 0], [0, 4], [4, 0], [2, 4], [4, 2], [4, 4]];   // rim cells of a 5×5 top, already sorted back → front
      for (var i = 0; i < cells.length; i++) { var p = u.iso(cells[i][0] + 1, cells[i][1] + 1, 0, m); blk(ox + p[0], oy + p[1], m, D.stone, m * 1.2); }
      var px = x, py = y - h2 - dy, ph = s * 0.9;                             // the flag pole, on the top's centre
      u.line(px, py, px, py - ph, "#3A3040", 1.5);
      u.poly([[px, py - ph], [px + Math.cos(th) * s * 0.52, py - ph + Math.sin(th) * s * 0.52], [px, py - ph + s * 0.32]], D.flag);   // the flag: pole top, the tip at its angle, the pole a little down
      u.label("one sun for every block — tower, battlements, annex all agree on the dark side, so they are one building; the flag is a spring on a lagging wind", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { sunL = x < u.W / 2; D.wind = (x < u.W / 2 ? 1 : -1) * Math.abs(D.wind); }   // click a side = the sun (and the wind) come from there; the flag finds out through the lag
  };
});

def("P", "Pyramid", "facet", "two triangles, one lit and one dark, plus a shadow stretched along the ground away from the light — press moves the sun and both swap", function make(u) {
  var D = { sky: ["#3A6FD0", "#C8DCF0"], sand: "#D9A86A", col: "#D9A86A",
            size: 0.19, h: 1.1, shadowA: 0.42 };                              // size = one footprint edge in W; h = apex height in edges; shadowA = how dark the shadow
  var lx = -0.7, ly = -0.6;                                                  // the sun: −1..1 across the picture, −1 high … 0.4 low
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = u.W * D.size, dx = 0.866 * s, dy = 0.5 * s, h = s * D.h;
      var x = u.W / 2, y = u.H * 0.8;
      var F = [x, y], L = [x - dx, y - dy], R = [x + dx, y - dy], B = [x, y - 2 * dy], A = [x, y - dy - h];
      u.ground(y - dy * 2.6, D.sand);
      var sun = [u.W / 2 + lx * u.W * 0.45, u.H * 0.3 + ly * u.H * 0.25];
      u.soft(sun[0], sun[1], u.W * 0.16, "#FFF3D0", 0.85);
      var vx = x - sun[0], vy = (y - dy) - sun[1], vl = Math.sqrt(vx * vx + vy * vy) || 1;   // from the sun through the pyramid
      var len = h * (1.7 + ly * 1.2), S = [x + vx / vl * len, y - dy + vy / vl * len * 0.5];   // a low sun throws a long shadow; ground squashes y by half
      var shade = u.mix(D.sand, "#000000", D.shadowA), base = [F, L, B, R];
      for (var i = 0; i < 4; i++) u.poly([base[i], base[(i + 1) % 4], S], shade);   // a fan of opaque triangles = the shadow's hull
      u.poly(base, shade);
      var kl = u.lerp(0.28, -0.42, (lx + 1) / 2) - ly * 0.06, kr = u.lerp(-0.42, 0.28, (lx + 1) / 2) - ly * 0.06;   // the face toward the sun is lit
      u.poly([L, F, A], u.shade(D.col, kl));
      u.poly([F, R, A], u.shade(D.col, kr));
      u.label("the shadow points away from the light, the lit face points toward it — two cues the eye checks against each other", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { lx = u.clamp((x / u.W - 0.5) * 2, -1, 1); ly = u.clamp((y / u.H - 0.4) * 2, -1, 0.4); }   // put the sun where you click
  };
});

def("Q", "Quilt", "facet", "a patchwork of bumps and dents: a bump is a low block; a dent is the SAME three shades with left and right swapped — press to move the ripple", function make(u) {
  var D = { sky: ["#1A1430", "#2C2448"], col: "#C88AA0",
            n: 6, amp: 0.45, speed: 1.2, flat: 0.15 };                       // amp = bump height in tile widths; speed of the ripple; flat = dead band where a tile stays level
  var org = { x: D.n / 2, y: D.n / 2 };
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = Math.min(u.W * 0.08, u.H * 0.1), ox = u.W / 2, oy = u.H * 0.5 - s * D.n * 0.5 + s * 0.2;
      var top = u.shade(D.col, 0.32), mid = D.col, dark = u.shade(D.col, -0.42);
      function P(ix, iy, dz) { var p = u.iso(ix, iy, 0, s); return [ox + p[0], oy + p[1] + (dz || 0)]; }
      for (var sum = 0; sum <= 2 * (D.n - 1); sum++) for (var ix = 0; ix < D.n; ix++) {   // painter's order: back rows (small ix+iy) first
        var iy = sum - ix; if (iy < 0 || iy >= D.n) continue;
        var d = Math.sqrt((ix + 0.5 - org.x) * (ix + 0.5 - org.x) + (iy + 0.5 - org.y) * (iy + 0.5 - org.y));
        var z = Math.sin(d * 1.3 - t * D.speed);                             // −1..1: the ripple
        var B = P(ix, iy), Lc = P(ix, iy + 1), Rc = P(ix + 1, iy), F = P(ix + 1, iy + 1);
        if (z > D.flat) u.cube(F[0], F[1], s, D.col, { h: (z - D.flat) * s * D.amp });   // a bump: a low block, lit top, mid left, dark right
        else if (z < -D.flat) {                                                // a dent: the two back walls, then the sunken floor
          var dp = (-z - D.flat) * s * D.amp;
          u.poly([B, Lc, [Lc[0], Lc[1] + dp], [B[0], B[1] + dp]], dark);       // the back-left wall faces right → dark
          u.poly([B, Rc, [Rc[0], Rc[1] + dp], [B[0], B[1] + dp]], mid);        // the back-right wall faces left → mid
          u.poly([[B[0], B[1] + dp], [Lc[0], Lc[1] + dp], [F[0], F[1] + dp], [Rc[0], Rc[1] + dp]], top);
        } else u.poly([B, Lc, F, Rc], top);                                    // level: just the lit shade
      }
      u.label("swap the shades and the bump becomes a dent — the eye only knows the light comes from the upper-left", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) {                                                   // click = the ripple starts here (screen → iso grid)
      var s = Math.min(u.W * 0.08, u.H * 0.1), sx = x - u.W / 2, sy = y - (u.H * 0.5 - s * D.n * 0.5 + s * 0.2);
      org = { x: u.clamp((sx / (0.866 * s) + 2 * sy / s) / 2, 0, D.n), y: u.clamp((2 * sy / s - sx / (0.866 * s)) / 2, 0, D.n) };
    }
  };
});

def("S", "Stairs", "facet", "blocks of climbing height drawn left to right: lit tops, mid sides, dark ends — and a ball hopping down step by step under gravity: it lands, squashes, bounces once, and its shadow lands on each step with it", function make(u) {
  var D = { sky: ["#1A1E36", "#3A3F60"], floor: "#1A1A2C", cols: ["#8A8FA8"], ball: "#F5C169",
            n: 7, rise: 0.55, hop: 0.55, tempo: 1.6,                      // rise (keep ≥ 0.5 so each step hides the last one's end) and hop in step widths; tempo = hops per second, near enough — it sets the gravity, and the bounces add a little
            bounce: 0.35, squash: 0.3, dwell: 0.12, rest: 1.0 };              // bounce = restitution: the share of the landing speed that comes back up; squash = how flat a full landing presses the ball, of its radius; dwell = seconds it sits before the next hop; rest = seconds at the bottom before it starts over
  // the ball is a body: gravity pulls it down every step, and a step top is a
  // floor — when it arrives moving down it bounces with restitution (a share
  // of the speed comes back up, most is lost) until the bounce is too small
  // to matter, then it sits a moment and launches the next hop: an upward
  // speed for the hop height it wants, and just enough sideways to land on
  // the next step's middle. gravity is chosen from the tempo so a hop takes
  // about a beat. a landing also kicks a stiff, quick squash spring (a cycle
  // of about 150 ms) that flattens the ball and lets it ring back round.
  var ix = D.n - 1 + 0.4, vx = 0, z = D.n * D.rise, vz = 0, air = false, wait = 0;   // place along the stairs (cells) and its rate; height (cells) and its rate; in flight?; the timer on the ground
  var sq = 0, sqv = 0, SQW = 40, SQD = 0.4 * 2 * SQW;                        // the squash and its rate; the squash spring's rate (40 rad/s) and damping (0.4 of critical)
  return {
    frame: function (dt, t) {
      var n = D.n, rise = D.rise;
      var g = Math.pow((Math.sqrt(2 * D.hop) + Math.sqrt(2 * (D.hop + rise))) * D.tempo * 1.3, 2);   // gravity from the tempo: a hop's flight is (√2h + √2(h+r)) / √g, and the 1.3 leaves room for the bounces
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      for (var s = 0; s < sub; s++) {
        if (air) {
          vz -= g * h; z += vz * h; ix += vx * h;
          var under = u.clamp(Math.floor(ix), 0, n - 1), top = (under + 1) * rise;   // the step beneath: its top is the floor here
          if (z <= top && vz < 0) {
            z = top; var vin = -vz;
            vz = vin * D.bounce; vx *= D.bounce;                             // restitution: a share comes back up, and the run mostly dies
            sqv -= D.squash * 2 * SQW * Math.min(1, vin / Math.sqrt(2 * g * (D.hop + rise)));   // the landing kicks the squash, by how hard it hit (1 = a full hop's landing)
            if (vz * vz < 2 * g * 0.03) { vz = 0; vx = 0; air = false; wait = under === 0 ? D.rest : D.dwell; }   // a bounce under 0.03 cells: it has landed
          }
        } else {
          wait -= h;
          if (wait <= 0) {
            var on = u.clamp(Math.floor(ix), 0, n - 1);
            if (on === 0) { ix = n - 1 + 0.4; z = n * rise; }                 // the bottom: start over at the top
            else {
              vz = Math.sqrt(2 * g * D.hop);                                   // up: enough for the hop height
              var T = (vz + Math.sqrt(vz * vz + 2 * g * rise)) / g;             // how long until it is one step lower
              vx = (on - 1 + 0.4 - ix) / T; air = true;                        // across: enough to land on the next step's middle
            }
          }
        }
        sqv += (-SQW * SQW * sq - SQD * sqv) * h; sq = u.clamp(sq + sqv * h, -0.45, 0.45);
      }
      u.sky(D.sky);
      var sz = Math.min(u.W * 0.11, u.H * 0.12), rs = sz * rise;
      var ox = u.W / 2 - (n - 1) * 0.866 * sz / 2, oy = u.H * 0.88 - (n + 1) * 0.5 * sz;
      function P(px, py, pz) { var p = u.iso(px, py, pz || 0, sz); return [ox + p[0], oy + p[1]]; }
      u.ground(oy + sz * 0.4, D.floor);
      for (var i = 0; i < n; i++) { var f = P(i + 1, 1); u.cube(f[0], f[1], sz, D.cols[i % D.cols.length], { h: (i + 1) * rs }); }   // left to right = back to front
      var below = u.clamp(Math.floor(ix), 0, n - 1), topZ = (below + 1) * rise, lift = z - topZ;   // the step directly beneath the ball, and how far above it we are
      var gp = P(ix, 0.78, topZ), r = sz * 0.27;
      u.shadow(gp[0], gp[1], r * 1.2 / (1 + lift), r * 0.55 / (1 + lift), 0.5 / (1 + lift));   // higher = a smaller, fainter shadow
      var bp = P(ix, 0.78, z);
      u.ctx.save(); u.ctx.translate(bp[0], bp[1]); u.ctx.scale(1 - sq, 1 + sq);   // the squash, about the contact point: flatter one way, wider the other
      u.sphere(0, -r, r, D.ball, -0.5, -0.6, { spec: 0.5 });
      u.ctx.restore();
      u.label("seven blocks that agree about the light, drawn back to front — the shadow says which step the ball is over; the ball: gravity, a floor, restitution", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.tempo = 0.8 + (x / u.W) * 2; if (!air) wait = 0; }   // click = hop now (or start over, from the bottom); click right = a quicker descent
  };
});

def("V", "Voxels", "facet", "a little tree of cubes, sorted far to near before drawing — press turns it a quarter: it swings past and rings back, and the same cubes are re-sorted and re-drawn all the way", function make(u) {
  var D = { sky: ["#141226", "#26223E"], floor: "#1A1A2C", n: 5, every: 2,   // n = grid size; every = seconds between idle quarter-turns
            k: 60, zeta: 0.4,                                               // k = the turn's spring stiffness; zeta = damping as a fraction of critical — under 1, so the turn overshoots and rings back
            vox: [[2, 2, 0, "#8A5A3A"], [2, 2, 1, "#8A5A3A"],                 // [ix, iy, iz, colour] — the trunk...
                  [1, 1, 2, "#4A9A5A"], [2, 1, 2, "#5AAA6A"], [3, 1, 2, "#4A9A5A"], [1, 2, 2, "#5AAA6A"], [2, 2, 2, "#4A9A5A"], [3, 2, 2, "#5AAA6A"], [1, 3, 2, "#4A9A5A"], [2, 3, 2, "#5AAA6A"], [3, 3, 2, "#4A9A5A"],   // ...the canopy...
                  [2, 1, 3, "#6ABA7A"], [1, 2, 3, "#5AAA6A"], [2, 2, 3, "#6ABA7A"], [3, 2, 3, "#5AAA6A"], [2, 3, 3, "#6ABA7A"], [2, 2, 4, "#7ACA8A"]] };   // ...and the crown
  // the turn is an angle with an angular velocity: a press (or the idle
  // timer) moves the detent a quarter on, and a spring, damped under
  // critical, swings the tree toward it — past it, and back. every cube's
  // ix/iy is the grid turned by that angle about its centre (at exactly 90°
  // that is the old quarter-turn: (ix, iy) → (n−1−iy, ix)), and the depth
  // sort works off those interpolated ix/iy, so the order re-sorts itself
  // all the way through the swing and the overshoot.
  var turns = 0, turnAt = -9, lastT = 0, phi = 0, omg = 0;                  // quarter-turns asked for; the angle the tree is at, and its rate
  return {
    frame: function (dt, t) {
      lastT = t;
      if (t - turnAt > D.every) { turnAt = t; turns++; }                    // an idle quarter-turn now and then
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      var damp = D.zeta * 2 * Math.sqrt(D.k), tgt = turns * u.TAU / 4;      // damping from its fraction of critical; the detent
      for (var s = 0; s < sub; s++) { omg += (D.k * (tgt - phi) - damp * omg) * h; phi += omg * h; }
      u.sky(D.sky);
      var m = Math.min(u.W * 0.075, u.H * 0.085), ox = u.W / 2, oy = u.H * 0.54;
      u.ground(oy - m * 1.5, D.floor);
      var c = (D.n - 1) / 2, cs = Math.cos(phi), sn = Math.sin(phi), list = [];
      for (var i = 0; i < D.vox.length; i++) {
        var v = D.vox[i], dx = v[0] - c, dy = v[1] - c;                       // the cell turned by phi about the grid's centre
        list.push({ ix: c + dx * cs - dy * sn, iy: c + dx * sn + dy * cs, iz: v[2], c: v[3] });
      }
      list.sort(function (A, B) { return (A.ix + A.iy + A.iz * 0.001) - (B.ix + B.iy + B.iz * 0.001); });   // far first, then low first
      u.shadow(ox, oy, m * 2.1, m * 1.05, 0.4);
      for (var j = 0; j < list.length; j++) {
        var q = list[j], sp = u.iso(q.ix + 1 - D.n / 2, q.iy + 1 - D.n / 2, q.iz, m);   // base point = the cell's front corner, centred on the grid
        u.cube(ox + sp[0], oy + sp[1], m, q.c);
      }
      u.label("sort by ix+iy, then by height, then just draw — the order IS the depth; a turn is a spring to a detent, and the sort follows it through the overshoot", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { turnAt = lastT; turns++; }                       // one quarter-turn, now: the detent moves, the spring swings to it
  };
});

def("W", "Wedge", "facet", "a ramp: the slope is one lit face growing lighter toward you, the end is one dark face — a block slides down, faster and faster, rolls out along the floor and stops; its shadow slides with it", function make(u) {
  var D = { sky: ["#1E1C34", "#3A3858"], floor: "#1A1A2C", col: "#7AA0C8", block: "#F58A8A",
            len: 3, h: 1.4, speed: 0.8,                                  // len = ramp length in cells; h = the high end in cells; speed = the clock: gravity and grip scale with speed², so a higher speed is the same slide, quicker
            g: 9, grip: 12, rest: 0.6 };                                     // g = gravity, cells/s² (at speed 1); grip = the floor's braking at the bottom, cells/s²; rest = seconds it lies at the end before starting over
  // the block has a speed along the slope: gravity's share along the incline
  // (g·sin θ) grows it every step, so it starts slow and arrives fast. at the
  // bottom the speed turns flat (its along-the-floor part survives, the rest
  // is lost in the bump) and the floor's grip takes it off, so the block
  // rolls out past the ramp and stops where its speed ran out. it rests a
  // moment, then goes back to the top for another run.
  var iy = 0, v = 0, flat = false, wait = 0;                                 // place along the ramp (cells), speed (cells/s, along the slope, then the floor), on the floor yet?, the rest timer
  return {
    frame: function (dt, t) {
      var th = Math.atan2(D.h, D.len), g = D.g * D.speed * D.speed, grip = D.grip * D.speed * D.speed, mu = 0.45;   // the slope's angle; gravity and grip on this card's clock
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      for (var st = 0; st < sub; st++) {
        if (wait > 0) { wait -= h; if (wait <= 0) { iy = 0; v = 0; flat = false; } }   // rested: start over at the top
        else if (!flat) {
          v += g * Math.sin(th) * h; iy += v * Math.cos(th) * h;             // down the incline: only gravity's share along it
          if (iy + mu * 0.5 >= D.len) { flat = true; v *= Math.cos(th); }     // the block's middle passes the bottom edge: onto the floor
        } else {
          v = Math.max(0, v - grip * h); iy = Math.min(iy + v * h, D.len + 3);   // the roll-out: grip takes the speed off
          if (v === 0) wait = D.rest;
        }
      }
      u.sky(D.sky);
      var s = Math.min(u.W * 0.13, u.H * 0.16), ox = u.W / 2 + s * 0.4, oy = u.H * 0.84 - (D.len + 1) * 0.5 * s;
      function P(ix, py, iz) { var p = u.iso(ix, py, iz || 0, s); return [ox + p[0], oy + p[1]]; }
      u.ground(oy - s * 0.3, D.floor);
      u.poly([P(1, 0, 0), P(1, 0, D.h), P(1, D.len, 0)], u.shade(D.col, -0.42));   // the end face: vertical, facing right → dark
      var a = P(0.5, 0, D.h), b = P(0.5, D.len, 0);
      u.poly([P(0, 0, D.h), P(1, 0, D.h), P(1, D.len, 0), P(0, D.len, 0)], u.lin(a[0], a[1], b[0], b[1], [u.shade(D.col, 0.32), u.shade(D.col, 0.5)]));   // the slope: lit, lighter as it nears you
      var z = D.h * Math.max(0, 1 - (iy + mu * 0.5) / D.len);                // the slope's height under the block's middle — nil once it is on the floor
      var sh = P(0.5 + mu * 0.75, iy + mu * 0.5 + 0.15, z - 0.05);
      u.shadow(sh[0], sh[1], s * mu * 1.1, s * mu * 0.55, 0.45);             // the shadow rides the slope with it
      var f = P(0.5 + mu / 2, iy + mu, z);
      u.cube(f[0], f[1], s * mu, D.block);
      u.label("one lit face, one dark face, and a shadow that keeps up — that is a ramp and a thing on it; the thing: g·sin θ down the slope, grip on the floor", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) {                                                 // click right = a faster clock; click = a shove down the slope, or a fresh run if it is resting
      D.speed = 0.3 + (x / u.W) * 0.9;
      if (wait > 0) { iy = 0; v = 0; flat = false; wait = 0; } else v += D.g * 0.2;
    }
  };
});

def("X", "Xylophone", "facet", "eight flat blocks receding toward the back, each drawn a little smaller than the one before — size shrinking with distance is the cue; press a bar and it rings: it dips, springs back and fades, the long front bars slower than the short ones at the back", function make(u) {
  var D = { sky: ["#1A1430", "#2C2448"], floor: "#1A1A2C", cols: ["#F55A5A", "#F5A15A", "#F5E06A", "#9BE28A", "#5AD9D9", "#6A9AF5", "#B08AF5", "#F58AD0"],
            n: 8, shrink: 0.07, thick: 0.28, jitter: 0, beat: 0.45,        // shrink per bar toward the back; thick = bar height; jitter = height wobble; beat = seconds per note
            ring: 8, decay: 0.06, kick: 3 };                                 // ring = the front bar's rate, radians per second (a shorter bar rings quicker, by 1/length²); decay = damping as a fraction of critical — tiny, so a bar rings for seconds; kick = the mallet: the speed a strike gives a bar, bar sizes per second
  // each bar is a spring: a strike gives it a velocity downward, and a
  // spring with almost no damping brings it back and past, over and over,
  // fading — a bar rings. the rate is the bar's own: a short bar is a stiff
  // bar (k ∝ 1/length²), so the back bars ring quick and die soon, and the
  // long front bar rings low and slow. the top's flash is the ring's
  // energy, so it fades with the sound rather than on a timer.
  var tune = [0, 2, 4, 7, 4, 2, 1, 3, 5, 3], seq = 0, nextAt = 0, rows = [];
  var yo = new Float32Array(D.n), yv = new Float32Array(D.n);               // each bar's offset (in bar sizes, down = positive) and its rate
  function bar(x, y, L, wd, hz, s, c, kTop) {                                // a long block by hand: (x, y) is its front corner, L along ix, wd along iy
    var Lc = [x - L * 0.866 * s, y - L * 0.5 * s], Rc = [x + wd * 0.866 * s, y - wd * 0.5 * s], B = [Lc[0] + Rc[0] - x, Lc[1] + Rc[1] - y];
    u.poly([[x, y], Lc, [Lc[0], Lc[1] - hz], [x, y - hz]], c);                // left face: the colour
    u.poly([[x, y], Rc, [Rc[0], Rc[1] - hz], [x, y - hz]], u.shade(c, -0.42)); // right end: dark
    u.poly([[x, y - hz], [Lc[0], Lc[1] - hz], [B[0], B[1] - hz], [Rc[0], Rc[1] - hz]], u.shade(c, kTop));   // top: lit (or ringing)
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      if (t > nextAt) { yv[tune[seq % tune.length]] += D.kick; seq++; nextAt = t + D.beat; }   // the tune plays itself: each note is a strike
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      u.sky(D.sky);
      var s = Math.min(u.W * 0.08, u.H * 0.13), baseY = u.H * 0.86;
      u.ground(baseY - s * 4.5, D.floor);
      rows = [];
      for (var i = D.n - 1; i >= 0; i--) {                                    // back bar first
        var sc = 1 - i * D.shrink, si = s * sc, L = 4.2 - i * 0.3, wd = 0.8;
        var om = D.ring * (4.2 / L) * (4.2 / L), k = om * om, dp = D.decay * 2 * om;   // this bar's rate: stiffer the shorter it is; its damping from the fraction of critical
        for (var st = 0; st < sub; st++) { yv[i] += (-k * yo[i] - dp * yv[i]) * h; yo[i] = u.clamp(yo[i] + yv[i] * h, -1, 1); }
        var off = u.iso(0, -i * 1.2, 0, s), x = u.W / 2 - s * 2.2 + (L - wd) * 0.433 * si + off[0], y = baseY + off[1] + yo[i] * si;
        var hz = si * D.thick * (1 + D.jitter * Math.sin(t * 13 + i * 5));
        var flash = u.clamp(Math.sqrt(yo[i] * yo[i] + (yv[i] / om) * (yv[i] / om)) * om / D.kick, 0, 1), c = D.cols[i % D.cols.length];   // the ring's energy, 1 at a fresh strike
        if (flash > 0.02) u.soft(x - L * 0.433 * si, y - L * 0.25 * si - hz, si * 1.4, c, flash * 0.6);
        bar(x, y, L, wd, hz, si, c, 0.32 + 0.45 * flash);
        rows.push([i, y - L * 0.25 * si - hz]);                               // remember where each bar sits, for clicking
      }
      u.label("no perspective maths — each bar is drawn a little smaller than the one in front, and the eye reads distance; each bar is a spring that rings at its own rate", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) {                                                 // click = strike the bar nearest that height: a velocity, and the spring rings it
      var best = 0, bd = 1e9;
      for (var i = 0; i < rows.length; i++) { var d = Math.abs(rows[i][1] - y); if (d < bd) { bd = d; best = rows[i][0]; } }
      yv[best] += D.kick;
    }
  };
});

def("Y", "Yurt", "facet", "a round tent: the wall is a cylinder (dark → light → dark across), the roof a cone (the same band pinched into a triangle) — press moves the light and both slide", function make(u) {
  var D = { sky: ["#2A3A6A", "#B8C8E0"], floor: "#5A6A4A", wall: "#D9C8A8", roof: "#A85A4A", door: "#3A2A1A",
            roofH: 0.55, smoke: 6 };                                          // roofH = cone height in wall widths (low = a dome-ish cap); smoke = how many puffs
  var lx = -0.35;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var w = u.W * 0.36, hgt = u.H * 0.26, cx = u.W / 2, gy = u.H * 0.84;
      u.ground(gy - u.H * 0.18, D.floor);
      u.shadow(cx - lx * w * 0.3, gy, w * 0.72, w * 0.16, 0.45);              // the contact shadow leans away from the light
      u.cyl(cx, gy, w, hgt, D.wall, lx);
      u.cyl(cx, gy - hgt * 0.72, w, hgt * 0.07, u.shade(D.wall, -0.3), lx);  // a decorative band — the same gradient, so the same roundness
      var rw = w * 0.62, ry = gy - hgt + hgt * 0.04, top = ry - w * D.roofH, hi = u.clamp(0.5 + lx * 0.4, 0.05, 0.95);
      u.poly([[cx - rw, ry], [cx, top], [cx + rw, ry]], u.lin(cx - rw, 0, cx + rw, 0, [[0, u.shade(D.roof, -0.55)], [hi, u.shade(D.roof, 0.3)], [1, u.shade(D.roof, -0.7)]]));   // the cone: the cylinder's band, in a triangle
      var dw = w * 0.16, dh = hgt * 0.5, dx = cx - w * 0.04;
      u.ctx.fillStyle = D.door; u.ctx.fillRect(dx - dw / 2, gy - dh, dw, dh);
      u.dot(dx, gy - dh, dw / 2, D.door);                                     // an arched door
      for (var i = 0; i < D.smoke; i++) {                                     // smoke: puffs that grow and fade as they rise
        var p = (t * 0.3 + i / D.smoke) % 1, sx = cx + p * w * 0.25 + Math.sin(p * 7 + i) * w * 0.05, sy = top - p * u.H * 0.24;
        u.soft(sx, sy, w * 0.03 + p * w * 0.09, "#E8E5F4", (1 - p) * 0.35);
      }
      u.label("cylinder and cone are the same horizontal band — dark, light, dark — one in a rectangle, one pinched to a point", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { lx = u.clamp((x / u.W - 0.5) * 2, -1, 1); }     // the light slides to where you click
  };
});

def("Z", "Ziggurat", "facet", "five blocks, each smaller and centred on the last: the same three shades on every tier and one long ground shadow — press swaps the sun to the other side", function make(u) {
  var D = { sky: ["#F5A15A", "#F5D9B0"], sand: "#C8945A", col: "#B87A4A",
            tiers: 5, step: 0.17, h: 0.22, shadowA: 0.35, glow: 0 };          // step = how much each tier shrinks; h = tier height in widths; glow = neon edge alpha (0 = none)
  var sunL = true;
  function blk(x, y, s, c, h) {                                              // a block under THIS picture's sun — mirrored when the sun is on the right
    u.cube(x, y, s, c, { h: h, left: sunL ? c : u.shade(c, -0.42), right: sunL ? u.shade(c, -0.42) : c });
  }
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = Math.min(u.W * 0.34, u.H * 0.42), dx = 0.866 * s, dy = 0.5 * s, h = s * D.h;
      var x = u.W / 2, y = u.H * 0.84, dir = sunL ? 1 : -1;
      u.ground(y - dy * 2.4, D.sand);
      u.soft(sunL ? u.W * 0.1 : u.W * 0.9, u.H * 0.16, u.W * 0.16, "#FFF3D0", 0.9);
      var L = s * 1.5, vx = dir * L, vy = L * 0.22;                           // the shadow runs away from the sun, a little toward us
      u.poly([[x, y], [x + dir * dx, y - dy], [x + dir * dx + vx * 0.7, y - dy + vy * 0.7], [x + vx, y + vy]], u.rgba("#000000", D.shadowA));
      for (var k = 0; k < D.tiers; k++) {
        var sz = s * (1 - k * D.step), yk = y - k * h - 0.5 * (s - sz);       // each tier centred on the one below
        blk(x, yk, sz, u.mix(D.col, u.shade(D.col, 0.2), k / D.tiers), h);
        if (D.glow > 0) {                                                      // neon: the top's four edges, lit
          var ex = 0.866 * sz, ey = 0.5 * sz, ty = yk - h, E = [[x, ty], [x - ex, ty - ey], [x, ty - 2 * ey], [x + ex, ty - ey]];
          for (var e = 0; e < 4; e++) u.line(E[e][0], E[e][1], E[(e + 1) % 4][0], E[(e + 1) % 4][1], u.rgba("#40F0F0", D.glow), 1.5);
        }
      }
      u.label("five tiers, one sun: every tier is lit on the same side — swap the sun and all five swap together", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { sunL = !sunL; }                                  // the sun crosses the sky
  };
});

/* ---- the rhymes: same pictures, two or three dials moved ---- */

rhymeOf("Block", "Glass block", "the same cube at half opacity with all twelve edges drawn — you see through it, and the three shades still make it a solid", function make(u) {
  // rhyme of Block: dials moved — col to pale ice, alpha 1 → 0.55, edge 0 → 0.7
  var D = { sky: ["#1A1830", "#2A2848"], floor: "#1A1A2E", col: "#BFE6F5",
            size: 0.22, alpha: 0.55, edge: 0.7 };
  var lights = [[-1, -1], [1, -1], [-1, 1], [1, 1]];                        // where the light sits: upper-left, upper-right, lower-left, lower-right
  var li = 0;
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = u.W * D.size, dx = 0.866 * s, dy = 0.5 * s, h = s;
      var x = u.W / 2, y = u.H * 0.8, L = lights[li];
      u.ground(y - dy * 2.4, D.floor);
      var kTop = L[1] < 0 ? 0.32 : 0;                                      // light from above: the top is the lit face
      var kL = L[0] < 0 ? (L[1] < 0 ? 0 : 0.32) : -0.42;                   // the face toward the light is lit or mid...
      var kR = L[0] > 0 ? (L[1] < 0 ? 0 : 0.32) : -0.42;                   // ...the face away from it is dark
      var lp = [x + L[0] * u.W * 0.36, y - h / 2 - dy / 2 + L[1] * u.H * 0.28];   // the light itself, so you can see it move
      u.soft(lp[0], lp[1], u.W * 0.1, "#FFF3D0", 0.7);
      u.shadow(x - L[0] * dx * 0.25, y - dy * 0.35, dx * 1.5, dy * 1.5, 0.5);    // contact shadow, nudged away from the light
      u.cube(x, y, s, D.col, { top: u.rgba(u.shade(D.col, kTop), D.alpha), left: u.rgba(u.shade(D.col, kL), D.alpha), right: u.rgba(u.shade(D.col, kR), D.alpha) });
      if (D.edge > 0) {                                                      // outlines: all twelve edges, the hidden three included
        var F = [x, y], Lc = [x - dx, y - dy], Rc = [x + dx, y - dy], B = [x, y - 2 * dy];
        var E = [[F, Lc], [F, Rc], [Lc, B], [Rc, B]];
        for (var i = 0; i < 4; i++) { var a = E[i][0], b = E[i][1]; u.line(a[0], a[1], b[0], b[1], u.rgba(u.INK, D.edge)); u.line(a[0], a[1] - h, b[0], b[1] - h, u.rgba(u.INK, D.edge)); }
        var V = [F, Lc, Rc, B];
        for (var j = 0; j < 4; j++) u.line(V[j][0], V[j][1], V[j][0], V[j][1] - h, u.rgba(u.INK, D.edge));
      }
      function name(k) { return k > 0.1 ? "lit" : (k < -0.1 ? "dark" : "mid"); }
      u.label(name(kTop), x, y - h - dy + 3, u.rgba(u.INK, 0.85), "center");
      u.label(name(kL), x - dx / 2, y - dy / 2 - h / 2 + 3, u.rgba(u.INK, 0.85), "center");
      u.label(name(kR), x + dx / 2, y - dy / 2 - h / 2 + 3, u.rgba(u.INK, 0.85), "center");
      u.label("half opacity and the edges drawn: see-through, and still a solid — the shades did the work, the outline just agrees", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { li = (li + 1) % 4; }                          // walk the light round the four corners
  };
});

rhymeOf("Gem", "Ruby cut", "the same stone in red, turning three times as fast — the facets flicker past the light instead of drifting; a nudge still spins it up and coasts down", function make(u) {
  // rhyme of Gem: dials moved — col to ruby, sky to a dark wine, spin 0.4 → 1.4
  var D = { sky: ["#1A0810", "#2E1020"], col: "#E0305A", spin: 1.4,
            sides: 6, crown: 0.45, pav: 1.1,                                // crown/pav = the point above / below the rim, in radii
            kick: 3, drag: 1.2,                                             // kick = angular velocity a full-width press adds, rad/s; drag = how fast that nudge coasts down, per second
            bob: 8, bobdamp: 0.08 };                                        // bob = the float's spring stiffness; bobdamp = its damping as a fraction of critical (tiny: it keeps bobbing)
  var Lt = [-0.5, 0.75, 0.45], ln = Math.sqrt(Lt[0] * Lt[0] + Lt[1] * Lt[1] + Lt[2] * Lt[2]);
  Lt = [Lt[0] / ln, Lt[1] / ln, Lt[2] / ln];                                // the light: upper-left, a little toward us
  // the stone turns at its idle rate (spin) plus whatever a nudge left it:
  // a press adds angular VELOCITY, not an angle, and drag eats a share of
  // it every step, so the stone spins up and coasts back down to its idle
  // turn instead of jumping. the float is a spring around a rest height,
  // damped far under critical, so it bobs for a long while and a press
  // bumps it — nothing here is a sine of the clock.
  var ang = 0, angv = 0, bob = 0, bobv = 0.5;                                // the turn, the nudge's leftover rate, the float (in radii) and its rate
  function facets(a) {                                                       // rebuild the triangles for rotation a
    var n = D.sides, rim = [], out = [];
    for (var i = 0; i < n; i++) { var q = a + i / n * u.TAU; rim.push([Math.cos(q), 0, Math.sin(q)]); }
    for (var j = 0; j < n; j++) {
      out.push([[0, D.crown, 0], rim[j], rim[(j + 1) % n]]);                // crown: rim to the top point
      out.push([[0, -D.pav, 0], rim[(j + 1) % n], rim[j]]);                  // pavilion: rim to the bottom point
    }
    return out;
  }
  return {
    frame: function (dt, t) {
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      var bd = D.bobdamp * 2 * Math.sqrt(D.bob);                             // the float's damping, from its fraction of critical
      for (var s = 0; s < sub; s++) {
        angv -= angv * D.drag * h; ang += (D.spin + angv) * h;              // idle rate + the nudge, which drag wears away
        bobv += (-D.bob * bob - bd * bobv) * h; bob = u.clamp(bob + bobv * h, -0.3, 0.3);
      }
      ang = ang % u.TAU;
      u.sky(D.sky);
      var r = Math.min(u.W, u.H) * 0.26, cx = u.W / 2, cy = u.H * 0.46 + bob * r * 0.4;
      var F = facets(ang), cz = (D.crown - D.pav) / 2, best = null;
      for (var i = 0; i < F.length; i++) {
        var p = F[i], e1 = [p[1][0] - p[0][0], p[1][1] - p[0][1], p[1][2] - p[0][2]], e2 = [p[2][0] - p[0][0], p[2][1] - p[0][1], p[2][2] - p[0][2]];
        var nx = e1[1] * e2[2] - e1[2] * e2[1], ny = e1[2] * e2[0] - e1[0] * e2[2], nz = e1[0] * e2[1] - e1[1] * e2[0];
        var m = Math.sqrt(nx * nx + ny * ny + nz * nz) || 1; nx /= m; ny /= m; nz /= m;
        var gx = (p[0][0] + p[1][0] + p[2][0]) / 3, gy = (p[0][1] + p[1][1] + p[2][1]) / 3 - cz, gz = (p[0][2] + p[1][2] + p[2][2]) / 3;
        if (nx * gx + ny * gy + nz * gz < 0) { nx = -nx; ny = -ny; nz = -nz; }   // the normal must point OUT of the stone
        p.k = nx * Lt[0] + ny * Lt[1] + nz * Lt[2];                          // −1..1: how squarely this facet faces the light
        p.z = gz;
        if (!best || p.k > best.k) best = p;
      }
      F.sort(function (A, B) { return A.z - B.z; });                         // far facets first — painter's order
      u.shadow(cx, cy + r * D.pav * 0.85 + r * 0.2, r * 0.8, r * 0.22, 0.4);
      for (var f = 0; f < F.length; f++) {
        var q = F[f], pts = [];
        for (var j = 0; j < 3; j++) pts.push([cx + q[j][0] * r, cy - q[j][1] * r * 0.8 + q[j][2] * r * 0.35]);   // tilted: we look down a little
        u.poly(pts, u.shade(D.col, q.k * 0.5));
      }
      if (best.k > 0.8) u.soft(cx + (best[0][0] + best[1][0] + best[2][0]) / 3 * r, cy - (best[0][1] + best[1][1] + best[2][1]) / 3 * r * 0.8 + best.z * r * 0.35, r * 0.4, "#FFFFFF", (best.k - 0.8) * 3);   // the facet squarest to the light sparkles
      u.label("a red palette and a faster turn — the same triangles; only the dot product with the light moves, and a nudge coasts down the same way", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { angv += (x / u.W - 0.5) * 2 * D.kick; bobv -= 0.6; }   // a nudge: angular velocity, left or right of centre — and a bump to the float
  };
});

rhymeOf("Hexprism", "Basalt columns", "five grey columns of different heights, side by side, all sent round together — the tall ones lag and rock longer, so they settle on their own phases: a rock shelf from one rule", function make(u) {
  // rhyme of Hexprism: dials moved — cols to three greys, count 1 → 5, h 0.5 → 0.42
  var D = { sky: ["#141226", "#26223E"], floor: "#1A1A2C", cols: ["#4A4A52", "#5A5A62", "#3E3E46"],
            count: 5, h: 0.42, r: 0.16, every: 3,                          // count of prisms; h and r as fractions of H and W; every = seconds between idle turns
            k: 64, zeta: 0.4 };                                             // k = the turn's spring stiffness for a column of height h (taller = heavier = softer); zeta = damping as a fraction of critical — under 1, so it turns past the detent and rocks back
  var R = u.rng(7), prisms = [];
  for (var i = 0; i < D.count; i++) prisms.push({ x: (i + 0.5) / D.count, h: D.h * (D.count > 1 ? 0.55 + R() * 0.7 : 1), c: D.cols[i % D.cols.length] });
  // a press moves the DETENT — the angle the column wants — on by 60°. the
  // column itself has an angular velocity and a spring toward the detent,
  // damped under critical, so it swings past, rocks back and settles rather
  // than easing in. every column keeps its own angle and rate, and a taller
  // column is a heavier one (a softer spring per height), so the rhyme's
  // five columns share one detent and arrive on their own phases.
  var turn = new Float32Array(prisms.length), om = new Float32Array(prisms.length), target = 0, nextAt = D.every;   // each column's angle and angular velocity; the shared detent
  return {
    frame: function (dt, t) {
      if (t > nextAt) { target += u.TAU / 6; nextAt = t + D.every; }        // the idle turn: the detent moves on
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      for (var p = 0; p < prisms.length; p++) {
        var kp = D.k * D.h / prisms[p].h, dp = D.zeta * 2 * Math.sqrt(kp);   // a taller column: more inertia, so a softer spring — and its own critical damping
        for (var s = 0; s < sub; s++) { om[p] += (kp * (target - turn[p]) - dp * om[p]) * h; turn[p] += om[p] * h; }
      }
      u.sky(D.sky);
      var gy = u.H * 0.82;
      u.ground(gy - u.H * 0.22, D.floor);
      for (var p = 0; p < prisms.length; p++) {
        var P = prisms[p], cx = u.W * P.x, r = u.W * D.r / (D.count > 1 ? Math.sqrt(D.count) * 0.8 : 1), hp = u.H * P.h, tp = turn[p];
        u.shadow(cx + r * 0.35, gy, r * 1.4, r * 0.6, 0.45);
        var v = [];
        for (var i = 0; i < 6; i++) { var q = tp + i * u.TAU / 6; v.push([cx + Math.cos(q) * r, gy + Math.sin(q) * r * 0.5]); }
        for (var j = 0; j < 6; j++) {
          var A = v[j], B = v[(j + 1) % 6], mid = tp + (j + 0.5) * u.TAU / 6;   // the direction this side faces
          if (Math.sin(mid) <= 0) continue;                                 // it faces away from us
          u.poly([A, B, [B[0], B[1] - hp], [A[0], A[1] - hp]], u.shade(P.c, -0.21 - 0.21 * Math.cos(mid)));   // facing left = the colour, facing right = dark
        }
        var top = [];
        for (var k = 0; k < 6; k++) top.push([v[k][0], v[k][1] - hp]);
        u.poly(top, u.shade(P.c, 0.32));
      }
      u.label("five columns, different heights, one light and one detent — the grey rule is still a rule, and each column swings to it at its own pace", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { target += u.TAU / 6; nextAt += D.every; }       // one more sixth of a turn: the detent moves, the spring does the rest
  };
});

rhymeOf("Isotile", "Dungeon floor", "the same floor in dark stone under a torch — a warm glow laid over the tiles, the edge lines cut deeper; the ball still rolls past its mark and settles", function make(u) {
  // rhyme of Isotile: dials moved — a/b to dark stone, edge −0.45 → −0.6, glow 0 → 0.35
  var D = { sky: ["#0A0812", "#161222"], a: "#3A3640", b: "#4A4650", edge: -0.6, ball: "#9BE28A",
            n: 8, speed: 0.6, glow: 0.35,                                     // n tiles a side; glow = a warm torch tint over the floor (0 = none)
            k: 36, zeta: 0.5 };                                             // k = the pull toward where the ball is going; zeta = damping as a fraction of critical — under 1, so it rolls a little past and settles back
  // the ball has a velocity: a spring pulls it toward its aim (a click, or
  // the idle circle) and damping under critical lets it roll a little past
  // and come back — it arrives like a ball, not like a cursor. the shadow is
  // drawn at the ball's grid position on the floor whatever the ball does,
  // which is the lesson.
  var ball = { x: 4, y: 4 }, vel = { x: 0, y: 0 }, target = null;           // grid position, grid velocity (cells per second), the clicked aim
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = Math.min(u.W * 0.065, u.H * 0.1), ox = u.W / 2, oy = u.H * 0.12;
      function P(ix, iy, iz) { var p = u.iso(ix, iy, iz || 0, s); return [ox + p[0], oy + p[1]]; }
      for (var iy = 0; iy < D.n; iy++) for (var ix = 0; ix < D.n; ix++) {
        var c = (ix + iy) % 2 ? D.a : D.b, q = [P(ix, iy), P(ix + 1, iy), P(ix + 1, iy + 1), P(ix, iy + 1)];
        u.poly(q, c);
        u.line(q[1][0], q[1][1], q[2][0], q[2][1], u.shade(c, D.edge), 1);   // the right edge and the bottom edge, darker:
        u.line(q[3][0], q[3][1], q[2][0], q[2][1], u.shade(c, D.edge), 1);   // a tile has a tiny thickness, and it faces the same light
      }
      if (D.glow > 0) u.soft(ox, oy + s * D.n * 0.5, s * D.n * 0.75, "#F5A15A", D.glow);
      var ax = D.n / 2 + 2.6 * Math.cos(t * D.speed), ay = D.n / 2 + 2.6 * Math.sin(t * D.speed);   // the idle path: a circle
      if (target) { ax = target.x; ay = target.y; if (Math.abs(ax - ball.x) + Math.abs(ay - ball.y) < 0.05 && Math.abs(vel.x) + Math.abs(vel.y) < 0.3) target = null; }   // there, and at rest: back to the idle path
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      var damp = D.zeta * 2 * Math.sqrt(D.k);                                // damping from its fraction of critical
      for (var st = 0; st < sub; st++) {
        vel.x += (D.k * (ax - ball.x) - damp * vel.x) * h; vel.y += (D.k * (ay - ball.y) - damp * vel.y) * h;
        ball.x = u.clamp(ball.x + vel.x * h, 0.3, D.n - 0.3); ball.y = u.clamp(ball.y + vel.y * h, 0.3, D.n - 0.3);   // the floor has an edge
      }
      var g = P(ball.x, ball.y), rb = s * 0.45;
      u.shadow(g[0], g[1], rb * 1.15, rb * 0.55, 0.5);                       // the shadow sits ON the floor: that is what keeps the ball on it
      u.sphere(g[0], g[1] - rb, rb, D.ball, -0.5, -0.6, { spec: 0.5 });
      u.label("dark stone under a torch: the warm tint sits on top of the tiles, and the edge lines still say 'floor' — the ball's spring is the same", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) {                                                 // click = roll the ball there (screen → iso grid): the aim moves, the spring does the rolling
      var s = Math.min(u.W * 0.065, u.H * 0.1), sx = x - u.W / 2, sy = y - u.H * 0.12;
      target = { x: u.clamp((sx / (0.866 * s) + 2 * sy / s) / 2, 0.5, D.n - 0.5), y: u.clamp((2 * sy / s - sx / (0.866 * s)) / 2, 0.5, D.n - 0.5) };
    }
  };
});

rhymeOf("Keep", "Sci-fi silo", "the same tower in steel blue, half again as tall, with a cyan beacon for a flag — a launch silo from castle parts; the beacon still drops slack and whips round when the wind turns", function make(u) {
  // rhyme of Keep: dials moved — palette to steel and night, h 2.4 → 3.4, wind 1 → −1
  var D = { sky: ["#0A0F2A", "#2A3A6A"], floor: "#1A2030", stone: "#7A9AB8", flag: "#40F0F0",
            h: 3.4, wind: -1,                                               // h = tower height in widths; wind = the wind asked for: sign = direction, size = strength
            k: 50, zeta: 0.35, lag: 2.5, droop: 0.25, flap: 0.12 };            // k = the flag tip's stiffness; zeta = damping as a fraction of critical (under 1: it whips past); lag = how fast the wind at the flag catches up with the dial, per second; droop = gravity's pull on the tip against a unit wind; flap = the flutter, radians per unit wind
  var sunL = true, w = D.wind, th = Math.atan2(D.droop, D.wind), om = 0;   // the wind at the flag (it lags the dial); the tip's angle from the pole (0 = streaming right, π/2 = hanging, π = streaming left) and its rate
  // the flag is one angle at its tip. the wind the flag feels chases the
  // wind you asked for (a lag, not a switch), and the tip is a spring toward
  // the angle wind and gravity agree on — straight downwind, drooping a
  // little. flip the wind and that rest angle walks through 'hanging
  // straight down' as the lagging wind passes zero, and the under-damped tip
  // whips through the slack after it: a flag turning round, not a flag
  // mirrored. the flutter is a small forcing on the same spring, quicker
  // in more wind.
  function blk(x, y, s, c, h) {                                              // a block under THIS picture's sun — mirrored when the sun is on the right
    u.cube(x, y, s, c, { h: h, left: sunL ? c : u.shade(c, -0.42), right: sunL ? u.shade(c, -0.42) : c });
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      var damp = D.zeta * 2 * Math.sqrt(D.k);                                // damping from its fraction of critical
      for (var st = 0; st < sub; st++) {
        w += (D.wind - w) * D.lag * h;                                       // the wind at the flag catches up with the dial
        var rest = Math.atan2(D.droop, w) + Math.sin(t * 9 * Math.abs(w)) * D.flap * Math.abs(w);   // downwind and a little down (π/2 when the wind is nil), plus the flutter
        om += (D.k * (rest - th) - damp * om) * h; th = u.clamp(th + om * h, -0.8, u.TAU / 2 + 0.8);
      }
      u.sky(D.sky);
      var s = Math.min(u.W * 0.16, u.H * 0.14), dx = 0.866 * s, dy = 0.5 * s, h2 = s * D.h;
      var x = u.W / 2, y = u.H * 0.84, m = s / 5;
      u.ground(y - dy * 2.6, D.floor);
      u.soft(sunL ? u.W * 0.1 : u.W * 0.9, u.H * 0.12, u.W * 0.14, "#FFF3D0", 0.8);
      u.shadow(x + (sunL ? 1 : -1) * dx * 0.9, y - dy * 0.5, dx * 2.4, dy * 1.5, 0.4);
      blk(x - dx * 1.3, y - dy * 0.9, s * 0.7, D.stone, s * 0.8);            // an annex, behind-left — drawn first
      blk(x, y, s, D.stone, h2);                                              // the tower
      var f1 = 0.36, f2 = 0.64, dh = s * 0.55;                                // the doorway, on the left face
      u.poly([[x - dx * f1, y - dy * f1], [x - dx * f2, y - dy * f2], [x - dx * f2, y - dy * f2 - dh], [x - dx * f1, y - dy * f1 - dh]], "#0E0B1A");
      var ox = x, oy = y - h2 - 2 * dy;                                       // the top face's back corner: origin for the battlements
      var cells = [[0, 0], [0, 2], [2, 0], [0, 4], [4, 0], [2, 4], [4, 2], [4, 4]];   // rim cells of a 5×5 top, already sorted back → front
      for (var i = 0; i < cells.length; i++) { var p = u.iso(cells[i][0] + 1, cells[i][1] + 1, 0, m); blk(ox + p[0], oy + p[1], m, D.stone, m * 1.2); }
      var px = x, py = y - h2 - dy, ph = s * 0.9;                             // the flag pole, on the top's centre
      u.line(px, py, px, py - ph, "#3A3040", 1.5);
      u.poly([[px, py - ph], [px + Math.cos(th) * s * 0.52, py - ph + Math.sin(th) * s * 0.52], [px, py - ph + s * 0.32]], D.flag);   // the flag: pole top, the tip at its angle, the pole a little down
      u.label("steel blue and taller, the flag a beacon — the light rule did not change, so it is still one building; the same spring on the same lagging wind", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { sunL = x < u.W / 2; D.wind = (x < u.W / 2 ? 1 : -1) * Math.abs(D.wind); }   // click a side = the sun (and the wind) come from there; the flag finds out through the lag
  };
});

rhymeOf("Pyramid", "Snow pyramid", "the same pyramid in white on white — a paler shadow, faces that barely differ — a low-contrast world with the same two cues", function make(u) {
  // rhyme of Pyramid: dials moved — palette to snow, col to near-white, shadowA 0.42 → 0.25
  var D = { sky: ["#8AB0E0", "#E8F0F8"], sand: "#E8F0F8", col: "#DDE8F5",
            size: 0.19, h: 1.1, shadowA: 0.25 };
  var lx = -0.7, ly = -0.6;                                                  // the sun: −1..1 across the picture, −1 high … 0.4 low
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = u.W * D.size, dx = 0.866 * s, dy = 0.5 * s, h = s * D.h;
      var x = u.W / 2, y = u.H * 0.8;
      var F = [x, y], L = [x - dx, y - dy], R = [x + dx, y - dy], B = [x, y - 2 * dy], A = [x, y - dy - h];
      u.ground(y - dy * 2.6, D.sand);
      var sun = [u.W / 2 + lx * u.W * 0.45, u.H * 0.3 + ly * u.H * 0.25];
      u.soft(sun[0], sun[1], u.W * 0.16, "#FFF3D0", 0.85);
      var vx = x - sun[0], vy = (y - dy) - sun[1], vl = Math.sqrt(vx * vx + vy * vy) || 1;   // from the sun through the pyramid
      var len = h * (1.7 + ly * 1.2), S = [x + vx / vl * len, y - dy + vy / vl * len * 0.5];   // a low sun throws a long shadow; ground squashes y by half
      var shade = u.mix(D.sand, "#000000", D.shadowA), base = [F, L, B, R];
      for (var i = 0; i < 4; i++) u.poly([base[i], base[(i + 1) % 4], S], shade);   // a fan of opaque triangles = the shadow's hull
      u.poly(base, shade);
      var kl = u.lerp(0.28, -0.42, (lx + 1) / 2) - ly * 0.06, kr = u.lerp(-0.42, 0.28, (lx + 1) / 2) - ly * 0.06;   // the face toward the sun is lit
      u.poly([L, F, A], u.shade(D.col, kl));
      u.poly([F, R, A], u.shade(D.col, kr));
      u.label("white on white: the shadow is paler and the faces nearly match — less contrast, the same two cues", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { lx = u.clamp((x / u.W - 0.5) * 2, -1, 1); ly = u.clamp((y / u.H - 0.4) * 2, -1, 0.4); }   // put the sun where you click
  };
});

rhymeOf("Quilt", "Circuit board", "the same patchwork in green, rippling three times as fast with a wide dead band — fewer, sharper bumps read as chips on a board", function make(u) {
  // rhyme of Quilt: dials moved — palette to board green, speed 1.2 → 3, flat 0.15 → 0.35, amp 0.45 → 0.3
  var D = { sky: ["#061A10", "#0C2818"], col: "#3A9A5A",
            n: 6, amp: 0.3, speed: 3, flat: 0.35 };
  var org = { x: D.n / 2, y: D.n / 2 };
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = Math.min(u.W * 0.08, u.H * 0.1), ox = u.W / 2, oy = u.H * 0.5 - s * D.n * 0.5 + s * 0.2;
      var top = u.shade(D.col, 0.32), mid = D.col, dark = u.shade(D.col, -0.42);
      function P(ix, iy, dz) { var p = u.iso(ix, iy, 0, s); return [ox + p[0], oy + p[1] + (dz || 0)]; }
      for (var sum = 0; sum <= 2 * (D.n - 1); sum++) for (var ix = 0; ix < D.n; ix++) {   // painter's order: back rows (small ix+iy) first
        var iy = sum - ix; if (iy < 0 || iy >= D.n) continue;
        var d = Math.sqrt((ix + 0.5 - org.x) * (ix + 0.5 - org.x) + (iy + 0.5 - org.y) * (iy + 0.5 - org.y));
        var z = Math.sin(d * 1.3 - t * D.speed);                             // −1..1: the ripple
        var B = P(ix, iy), Lc = P(ix, iy + 1), Rc = P(ix + 1, iy), F = P(ix + 1, iy + 1);
        if (z > D.flat) u.cube(F[0], F[1], s, D.col, { h: (z - D.flat) * s * D.amp });   // a bump: a low block, lit top, mid left, dark right
        else if (z < -D.flat) {                                                // a dent: the two back walls, then the sunken floor
          var dp = (-z - D.flat) * s * D.amp;
          u.poly([B, Lc, [Lc[0], Lc[1] + dp], [B[0], B[1] + dp]], dark);       // the back-left wall faces right → dark
          u.poly([B, Rc, [Rc[0], Rc[1] + dp], [B[0], B[1] + dp]], mid);        // the back-right wall faces left → mid
          u.poly([[B[0], B[1] + dp], [Lc[0], Lc[1] + dp], [F[0], F[1] + dp], [Rc[0], Rc[1] + dp]], top);
        } else u.poly([B, Lc, F, Rc], top);                                    // level: just the lit shade
      }
      u.label("green and quick with a wide dead band — the same swapped shades, now reading as chips and sockets", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) {                                                   // click = the ripple starts here (screen → iso grid)
      var s = Math.min(u.W * 0.08, u.H * 0.1), sx = x - u.W / 2, sy = y - (u.H * 0.5 - s * D.n * 0.5 + s * 0.2);
      org = { x: u.clamp((sx / (0.866 * s) + 2 * sy / s) / 2, 0, D.n), y: u.clamp((2 * sy / s - sx / (0.866 * s)) / 2, 0, D.n) };
    }
  };
});

rhymeOf("Stairs", "Candy stairs", "the same staircase in four pastels with a ball that hops twice as high and faster — it lands harder, so it squashes and bounces more, and the shadow shrinks more, so the bounce reads taller", function make(u) {
  // rhyme of Stairs: dials moved — palette to pastels (four step colours), ball to lilac, hop 0.55 → 1.2, tempo 1.6 → 2.2
  var D = { sky: ["#F5D0E0", "#F5E8F0"], floor: "#E8C8D8", cols: ["#F5A0B8", "#A0D8F5", "#F5E0A0", "#B8F0B0"], ball: "#C9A0F5",
            n: 7, rise: 0.55, hop: 1.2, tempo: 2.2,                      // rise (keep ≥ 0.5 so each step hides the last one's end) and hop in step widths; tempo = hops per second, near enough — it sets the gravity, and the bounces add a little
            bounce: 0.35, squash: 0.3, dwell: 0.12, rest: 1.0 };              // bounce = restitution: the share of the landing speed that comes back up; squash = how flat a full landing presses the ball, of its radius; dwell = seconds it sits before the next hop; rest = seconds at the bottom before it starts over
  // the ball is a body: gravity pulls it down every step, and a step top is a
  // floor — when it arrives moving down it bounces with restitution (a share
  // of the speed comes back up, most is lost) until the bounce is too small
  // to matter, then it sits a moment and launches the next hop: an upward
  // speed for the hop height it wants, and just enough sideways to land on
  // the next step's middle. gravity is chosen from the tempo so a hop takes
  // about a beat. a landing also kicks a stiff, quick squash spring (a cycle
  // of about 150 ms) that flattens the ball and lets it ring back round.
  var ix = D.n - 1 + 0.4, vx = 0, z = D.n * D.rise, vz = 0, air = false, wait = 0;   // place along the stairs (cells) and its rate; height (cells) and its rate; in flight?; the timer on the ground
  var sq = 0, sqv = 0, SQW = 40, SQD = 0.4 * 2 * SQW;                        // the squash and its rate; the squash spring's rate (40 rad/s) and damping (0.4 of critical)
  return {
    frame: function (dt, t) {
      var n = D.n, rise = D.rise;
      var g = Math.pow((Math.sqrt(2 * D.hop) + Math.sqrt(2 * (D.hop + rise))) * D.tempo * 1.3, 2);   // gravity from the tempo: a hop's flight is (√2h + √2(h+r)) / √g, and the 1.3 leaves room for the bounces
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      for (var s = 0; s < sub; s++) {
        if (air) {
          vz -= g * h; z += vz * h; ix += vx * h;
          var under = u.clamp(Math.floor(ix), 0, n - 1), top = (under + 1) * rise;   // the step beneath: its top is the floor here
          if (z <= top && vz < 0) {
            z = top; var vin = -vz;
            vz = vin * D.bounce; vx *= D.bounce;                             // restitution: a share comes back up, and the run mostly dies
            sqv -= D.squash * 2 * SQW * Math.min(1, vin / Math.sqrt(2 * g * (D.hop + rise)));   // the landing kicks the squash, by how hard it hit (1 = a full hop's landing)
            if (vz * vz < 2 * g * 0.03) { vz = 0; vx = 0; air = false; wait = under === 0 ? D.rest : D.dwell; }   // a bounce under 0.03 cells: it has landed
          }
        } else {
          wait -= h;
          if (wait <= 0) {
            var on = u.clamp(Math.floor(ix), 0, n - 1);
            if (on === 0) { ix = n - 1 + 0.4; z = n * rise; }                 // the bottom: start over at the top
            else {
              vz = Math.sqrt(2 * g * D.hop);                                   // up: enough for the hop height
              var T = (vz + Math.sqrt(vz * vz + 2 * g * rise)) / g;             // how long until it is one step lower
              vx = (on - 1 + 0.4 - ix) / T; air = true;                        // across: enough to land on the next step's middle
            }
          }
        }
        sqv += (-SQW * SQW * sq - SQD * sqv) * h; sq = u.clamp(sq + sqv * h, -0.45, 0.45);
      }
      u.sky(D.sky);
      var sz = Math.min(u.W * 0.11, u.H * 0.12), rs = sz * rise;
      var ox = u.W / 2 - (n - 1) * 0.866 * sz / 2, oy = u.H * 0.88 - (n + 1) * 0.5 * sz;
      function P(px, py, pz) { var p = u.iso(px, py, pz || 0, sz); return [ox + p[0], oy + p[1]]; }
      u.ground(oy + sz * 0.4, D.floor);
      for (var i = 0; i < n; i++) { var f = P(i + 1, 1); u.cube(f[0], f[1], sz, D.cols[i % D.cols.length], { h: (i + 1) * rs }); }   // left to right = back to front
      var below = u.clamp(Math.floor(ix), 0, n - 1), topZ = (below + 1) * rise, lift = z - topZ;   // the step directly beneath the ball, and how far above it we are
      var gp = P(ix, 0.78, topZ), r = sz * 0.27;
      u.shadow(gp[0], gp[1], r * 1.2 / (1 + lift), r * 0.55 / (1 + lift), 0.5 / (1 + lift));   // higher = a smaller, fainter shadow
      var bp = P(ix, 0.78, z);
      u.ctx.save(); u.ctx.translate(bp[0], bp[1]); u.ctx.scale(1 - sq, 1 + sq);   // the squash, about the contact point: flatter one way, wider the other
      u.sphere(0, -r, r, D.ball, -0.5, -0.6, { spec: 0.5 });
      u.ctx.restore();
      u.label("pastel steps, a higher hop — the shadow shrinks more when the ball is higher, so the bounce reads taller; a harder landing, a deeper squash", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.tempo = 0.8 + (x / u.W) * 2; if (!air) wait = 0; }   // click = hop now (or start over, from the bottom); click right = a quicker descent
  };
});

rhymeOf("Voxels", "Voxel cactus", "a different list of cubes — a cactus with two arms and a flower — under a desert sky; the sort, the shades and the swinging turn are untouched", function make(u) {
  // rhyme of Voxels: dials moved — vox to a cactus list, sky and floor to desert
  var D = { sky: ["#F5C169", "#F5E0B0"], floor: "#C8945A", n: 5, every: 3,
            k: 60, zeta: 0.4,
            vox: [[2, 2, 0, "#4A9A5A"], [2, 2, 1, "#4A9A5A"], [2, 2, 2, "#5AAA6A"], [2, 2, 3, "#5AAA6A"],
                  [1, 2, 1, "#4A9A5A"], [0, 2, 1, "#4A9A5A"], [0, 2, 2, "#5AAA6A"],
                  [3, 2, 2, "#5AAA6A"], [4, 2, 2, "#5AAA6A"], [4, 2, 3, "#6ABA7A"], [2, 2, 4, "#F58AB8"]] };
  // the turn is an angle with an angular velocity: a press (or the idle
  // timer) moves the detent a quarter on, and a spring, damped under
  // critical, swings the tree toward it — past it, and back. every cube's
  // ix/iy is the grid turned by that angle about its centre (at exactly 90°
  // that is the old quarter-turn: (ix, iy) → (n−1−iy, ix)), and the depth
  // sort works off those interpolated ix/iy, so the order re-sorts itself
  // all the way through the swing and the overshoot.
  var turns = 0, turnAt = -9, lastT = 0, phi = 0, omg = 0;                  // quarter-turns asked for; the angle the tree is at, and its rate
  return {
    frame: function (dt, t) {
      lastT = t;
      if (t - turnAt > D.every) { turnAt = t; turns++; }                    // an idle quarter-turn now and then
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      var damp = D.zeta * 2 * Math.sqrt(D.k), tgt = turns * u.TAU / 4;      // damping from its fraction of critical; the detent
      for (var s = 0; s < sub; s++) { omg += (D.k * (tgt - phi) - damp * omg) * h; phi += omg * h; }
      u.sky(D.sky);
      var m = Math.min(u.W * 0.075, u.H * 0.085), ox = u.W / 2, oy = u.H * 0.54;
      u.ground(oy - m * 1.5, D.floor);
      var c = (D.n - 1) / 2, cs = Math.cos(phi), sn = Math.sin(phi), list = [];
      for (var i = 0; i < D.vox.length; i++) {
        var v = D.vox[i], dx = v[0] - c, dy = v[1] - c;                       // the cell turned by phi about the grid's centre
        list.push({ ix: c + dx * cs - dy * sn, iy: c + dx * sn + dy * cs, iz: v[2], c: v[3] });
      }
      list.sort(function (A, B) { return (A.ix + A.iy + A.iz * 0.001) - (B.ix + B.iy + B.iz * 0.001); });   // far first, then low first
      u.shadow(ox, oy, m * 2.1, m * 1.05, 0.4);
      for (var j = 0; j < list.length; j++) {
        var q = list[j], sp = u.iso(q.ix + 1 - D.n / 2, q.iy + 1 - D.n / 2, q.iz, m);   // base point = the cell's front corner, centred on the grid
        u.cube(ox + sp[0], oy + sp[1], m, q.c);
      }
      u.label("a different list of cubes, the same sort and the same three shades — the data is the dial; the turn still overshoots and rings back", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { turnAt = lastT; turns++; }                       // one quarter-turn, now: the detent moves, the spring swings to it
  };
});

rhymeOf("Wedge", "Skate ramp", "the same ramp in concrete grey, lower and faster, under a day sky — a skate ramp with a gold block for a board that rolls out and stops on the flat", function make(u) {
  // rhyme of Wedge: dials moved — palette to concrete and day, h 1.4 → 1.0, speed 0.8 → 0.9
  var D = { sky: ["#6FA8E8", "#CFE6F5"], floor: "#4A4A52", col: "#8A8A92", block: "#F5C169",
            len: 3, h: 1.0, speed: 0.9,                                  // len = ramp length in cells; h = the high end in cells; speed = the clock: gravity and grip scale with speed², so a higher speed is the same slide, quicker
            g: 9, grip: 12, rest: 0.6 };                                     // g = gravity, cells/s² (at speed 1); grip = the floor's braking at the bottom, cells/s²; rest = seconds it lies at the end before starting over
  // the block has a speed along the slope: gravity's share along the incline
  // (g·sin θ) grows it every step, so it starts slow and arrives fast. at the
  // bottom the speed turns flat (its along-the-floor part survives, the rest
  // is lost in the bump) and the floor's grip takes it off, so the block
  // rolls out past the ramp and stops where its speed ran out. it rests a
  // moment, then goes back to the top for another run.
  var iy = 0, v = 0, flat = false, wait = 0;                                 // place along the ramp (cells), speed (cells/s, along the slope, then the floor), on the floor yet?, the rest timer
  return {
    frame: function (dt, t) {
      var th = Math.atan2(D.h, D.len), g = D.g * D.speed * D.speed, grip = D.grip * D.speed * D.speed, mu = 0.45;   // the slope's angle; gravity and grip on this card's clock
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      for (var st = 0; st < sub; st++) {
        if (wait > 0) { wait -= h; if (wait <= 0) { iy = 0; v = 0; flat = false; } }   // rested: start over at the top
        else if (!flat) {
          v += g * Math.sin(th) * h; iy += v * Math.cos(th) * h;             // down the incline: only gravity's share along it
          if (iy + mu * 0.5 >= D.len) { flat = true; v *= Math.cos(th); }     // the block's middle passes the bottom edge: onto the floor
        } else {
          v = Math.max(0, v - grip * h); iy = Math.min(iy + v * h, D.len + 3);   // the roll-out: grip takes the speed off
          if (v === 0) wait = D.rest;
        }
      }
      u.sky(D.sky);
      var s = Math.min(u.W * 0.13, u.H * 0.16), ox = u.W / 2 + s * 0.4, oy = u.H * 0.84 - (D.len + 1) * 0.5 * s;
      function P(ix, py, iz) { var p = u.iso(ix, py, iz || 0, s); return [ox + p[0], oy + p[1]]; }
      u.ground(oy - s * 0.3, D.floor);
      u.poly([P(1, 0, 0), P(1, 0, D.h), P(1, D.len, 0)], u.shade(D.col, -0.42));   // the end face: vertical, facing right → dark
      var a = P(0.5, 0, D.h), b = P(0.5, D.len, 0);
      u.poly([P(0, 0, D.h), P(1, 0, D.h), P(1, D.len, 0), P(0, D.len, 0)], u.lin(a[0], a[1], b[0], b[1], [u.shade(D.col, 0.32), u.shade(D.col, 0.5)]));   // the slope: lit, lighter as it nears you
      var z = D.h * Math.max(0, 1 - (iy + mu * 0.5) / D.len);                // the slope's height under the block's middle — nil once it is on the floor
      var sh = P(0.5 + mu * 0.75, iy + mu * 0.5 + 0.15, z - 0.05);
      u.shadow(sh[0], sh[1], s * mu * 1.1, s * mu * 0.55, 0.45);             // the shadow rides the slope with it
      var f = P(0.5 + mu / 2, iy + mu, z);
      u.cube(f[0], f[1], s * mu, D.block);
      u.label("concrete grey, lower, faster — the lit slope and the dark end are the same two faces; a lower ramp, a shorter roll-out", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) {                                                 // click right = a faster clock; click = a shove down the slope, or a fresh run if it is resting
      D.speed = 0.3 + (x / u.W) * 0.9;
      if (wait > 0) { iy = 0; v = 0; flat = false; wait = 0; } else v += D.g * 0.2;
    }
  };
});

rhymeOf("Xylophone", "Glitch keys", "the same bars in two neon hues, heights jittering, the tune at three times the beat — struck bars ring over each other; the sizes still shrink to the back, so the depth survives", function make(u) {
  // rhyme of Xylophone: dials moved — cols to cyan/magenta (two, alternating), jitter 0 → 0.35, beat 0.45 → 0.18
  var D = { sky: ["#050510", "#101028"], floor: "#0A0A18", cols: ["#40F0F0", "#F040C0"],
            n: 8, shrink: 0.07, thick: 0.28, jitter: 0.35, beat: 0.18,        // shrink per bar toward the back; thick = bar height; jitter = height wobble; beat = seconds per note
            ring: 8, decay: 0.06, kick: 3 };                                 // ring = the front bar's rate, radians per second (a shorter bar rings quicker, by 1/length²); decay = damping as a fraction of critical — tiny, so a bar rings for seconds; kick = the mallet: the speed a strike gives a bar, bar sizes per second
  // each bar is a spring: a strike gives it a velocity downward, and a
  // spring with almost no damping brings it back and past, over and over,
  // fading — a bar rings. the rate is the bar's own: a short bar is a stiff
  // bar (k ∝ 1/length²), so the back bars ring quick and die soon, and the
  // long front bar rings low and slow. the top's flash is the ring's
  // energy, so it fades with the sound rather than on a timer.
  var tune = [0, 2, 4, 7, 4, 2, 1, 3, 5, 3], seq = 0, nextAt = 0, rows = [];
  var yo = new Float32Array(D.n), yv = new Float32Array(D.n);               // each bar's offset (in bar sizes, down = positive) and its rate
  function bar(x, y, L, wd, hz, s, c, kTop) {                                // a long block by hand: (x, y) is its front corner, L along ix, wd along iy
    var Lc = [x - L * 0.866 * s, y - L * 0.5 * s], Rc = [x + wd * 0.866 * s, y - wd * 0.5 * s], B = [Lc[0] + Rc[0] - x, Lc[1] + Rc[1] - y];
    u.poly([[x, y], Lc, [Lc[0], Lc[1] - hz], [x, y - hz]], c);                // left face: the colour
    u.poly([[x, y], Rc, [Rc[0], Rc[1] - hz], [x, y - hz]], u.shade(c, -0.42)); // right end: dark
    u.poly([[x, y - hz], [Lc[0], Lc[1] - hz], [B[0], B[1] - hz], [Rc[0], Rc[1] - hz]], u.shade(c, kTop));   // top: lit (or ringing)
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      if (t > nextAt) { yv[tune[seq % tune.length]] += D.kick; seq++; nextAt = t + D.beat; }   // the tune plays itself: each note is a strike
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
      u.sky(D.sky);
      var s = Math.min(u.W * 0.08, u.H * 0.13), baseY = u.H * 0.86;
      u.ground(baseY - s * 4.5, D.floor);
      rows = [];
      for (var i = D.n - 1; i >= 0; i--) {                                    // back bar first
        var sc = 1 - i * D.shrink, si = s * sc, L = 4.2 - i * 0.3, wd = 0.8;
        var om = D.ring * (4.2 / L) * (4.2 / L), k = om * om, dp = D.decay * 2 * om;   // this bar's rate: stiffer the shorter it is; its damping from the fraction of critical
        for (var st = 0; st < sub; st++) { yv[i] += (-k * yo[i] - dp * yv[i]) * h; yo[i] = u.clamp(yo[i] + yv[i] * h, -1, 1); }
        var off = u.iso(0, -i * 1.2, 0, s), x = u.W / 2 - s * 2.2 + (L - wd) * 0.433 * si + off[0], y = baseY + off[1] + yo[i] * si;
        var hz = si * D.thick * (1 + D.jitter * Math.sin(t * 13 + i * 5));
        var flash = u.clamp(Math.sqrt(yo[i] * yo[i] + (yv[i] / om) * (yv[i] / om)) * om / D.kick, 0, 1), c = D.cols[i % D.cols.length];   // the ring's energy, 1 at a fresh strike
        if (flash > 0.02) u.soft(x - L * 0.433 * si, y - L * 0.25 * si - hz, si * 1.4, c, flash * 0.6);
        bar(x, y, L, wd, hz, si, c, 0.32 + 0.45 * flash);
        rows.push([i, y - L * 0.25 * si - hz]);                               // remember where each bar sits, for clicking
      }
      u.label("jittered heights and a frantic beat — the sizes still shrink to the back, so the depth survives the glitch; the bars ring over one another", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) {                                                 // click = strike the bar nearest that height: a velocity, and the spring rings it
      var best = 0, bd = 1e9;
      for (var i = 0; i < rows.length; i++) { var d = Math.abs(rows[i][1] - y); if (d < bd) { bd = d; best = rows[i][0]; } }
      yv[best] += D.kick;
    }
  };
});

rhymeOf("Yurt", "Igloo dome", "the same tent in white on blue with a squat roof and almost no smoke — the cone reads as a dome the moment it gets low", function make(u) {
  // rhyme of Yurt: dials moved — palette to snow and ice, roofH 0.55 → 0.22, smoke 6 → 2
  var D = { sky: ["#1E3A7A", "#8AB8E8"], floor: "#E8F0F8", wall: "#E8F0F8", roof: "#D8E8F5", door: "#2A3A5A",
            roofH: 0.22, smoke: 2 };
  var lx = -0.35;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var w = u.W * 0.36, hgt = u.H * 0.26, cx = u.W / 2, gy = u.H * 0.84;
      u.ground(gy - u.H * 0.18, D.floor);
      u.shadow(cx - lx * w * 0.3, gy, w * 0.72, w * 0.16, 0.45);              // the contact shadow leans away from the light
      u.cyl(cx, gy, w, hgt, D.wall, lx);
      u.cyl(cx, gy - hgt * 0.72, w, hgt * 0.07, u.shade(D.wall, -0.3), lx);  // a decorative band — the same gradient, so the same roundness
      var rw = w * 0.62, ry = gy - hgt + hgt * 0.04, top = ry - w * D.roofH, hi = u.clamp(0.5 + lx * 0.4, 0.05, 0.95);
      u.poly([[cx - rw, ry], [cx, top], [cx + rw, ry]], u.lin(cx - rw, 0, cx + rw, 0, [[0, u.shade(D.roof, -0.55)], [hi, u.shade(D.roof, 0.3)], [1, u.shade(D.roof, -0.7)]]));   // the cone: the cylinder's band, in a triangle
      var dw = w * 0.16, dh = hgt * 0.5, dx = cx - w * 0.04;
      u.ctx.fillStyle = D.door; u.ctx.fillRect(dx - dw / 2, gy - dh, dw, dh);
      u.dot(dx, gy - dh, dw / 2, D.door);                                     // an arched door
      for (var i = 0; i < D.smoke; i++) {                                     // smoke: puffs that grow and fade as they rise
        var p = (t * 0.3 + i / D.smoke) % 1, sx = cx + p * w * 0.25 + Math.sin(p * 7 + i) * w * 0.05, sy = top - p * u.H * 0.24;
        u.soft(sx, sy, w * 0.03 + p * w * 0.09, "#E8E5F4", (1 - p) * 0.35);
      }
      u.label("white on blue with a squat roof — the same band, pinched less, and the cone reads as a dome", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { lx = u.clamp((x / u.W - 0.5) * 2, -1, 1); }     // the light slides to where you click
  };
});

rhymeOf("Ziggurat", "Neon temple", "the same five tiers at night in violet, every top edge glowing cyan, a deeper shadow — the edges were where the shades met all along", function make(u) {
  // rhyme of Ziggurat: dials moved — palette to night violet, glow 0 → 0.9, shadowA 0.35 → 0.5
  var D = { sky: ["#0A0A1E", "#1A1035"], sand: "#0E0B1A", col: "#5A2A7A",
            tiers: 5, step: 0.17, h: 0.22, shadowA: 0.5, glow: 0.9 };
  var sunL = true;
  function blk(x, y, s, c, h) {                                              // a block under THIS picture's sun — mirrored when the sun is on the right
    u.cube(x, y, s, c, { h: h, left: sunL ? c : u.shade(c, -0.42), right: sunL ? u.shade(c, -0.42) : c });
  }
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = Math.min(u.W * 0.34, u.H * 0.42), dx = 0.866 * s, dy = 0.5 * s, h = s * D.h;
      var x = u.W / 2, y = u.H * 0.84, dir = sunL ? 1 : -1;
      u.ground(y - dy * 2.4, D.sand);
      u.soft(sunL ? u.W * 0.1 : u.W * 0.9, u.H * 0.16, u.W * 0.16, "#FFF3D0", 0.9);
      var L = s * 1.5, vx = dir * L, vy = L * 0.22;                           // the shadow runs away from the sun, a little toward us
      u.poly([[x, y], [x + dir * dx, y - dy], [x + dir * dx + vx * 0.7, y - dy + vy * 0.7], [x + vx, y + vy]], u.rgba("#000000", D.shadowA));
      for (var k = 0; k < D.tiers; k++) {
        var sz = s * (1 - k * D.step), yk = y - k * h - 0.5 * (s - sz);       // each tier centred on the one below
        blk(x, yk, sz, u.mix(D.col, u.shade(D.col, 0.2), k / D.tiers), h);
        if (D.glow > 0) {                                                      // neon: the top's four edges, lit
          var ex = 0.866 * sz, ey = 0.5 * sz, ty = yk - h, E = [[x, ty], [x - ex, ty - ey], [x, ty - 2 * ey], [x + ex, ty - ey]];
          for (var e = 0; e < 4; e++) u.line(E[e][0], E[e][1], E[(e + 1) % 4][0], E[(e + 1) % 4][1], u.rgba("#40F0F0", D.glow), 1.5);
        }
      }
      u.label("in the dark the shades go quiet and the glowing edges take over — the edges were where the shades met all along", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { sunL = !sunL; }                                  // the sun crosses the sky
  };
});

/* ================================ LIGHT SOURCES ================================
   A light source is four things drawn in order: a hot core, a radial falloff
   around it, the light it THROWS onto whatever is nearby (a gradient on the
   wall or floor that follows the source), and — usually — additive blending,
   so that overlapping glows brighten instead of covering each other. Draw the
   light with globalCompositeOperation = "lighter"; switch back to "source-over"
   before drawing anything solid. Thirteen sources, sun to strobe. */

def("S", "Sun", "light", "a disc with limb darkening, a corona of stacked glows added together, slow faint rays — and a wide soft that brightens the sky around it", function make(u) {
  var D = { sky: ["#0B1030", "#2A4F9A"], core: "#FFFBE8", disc: "#FFD070", limb: "#F08A30", corona: "#FFC060",
            size: 0.13, layers: 4, rays: 12, spin: 0.2 };                  // disc radius as a fraction of the width
  var sx = u.W * 0.5, sy = u.H * 0.45;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var r = u.W * D.size, c = u.ctx;
      u.soft(sx, sy, u.W * 0.8, D.corona, 0.22);                          // the thrown light: the air near the sun is paler
      c.globalCompositeOperation = "lighter";                             // light adds; it never darkens
      for (var i = 0; i < D.layers; i++)                                  // corona: each layer wider and fainter
        u.soft(sx, sy, r * (1.4 + i * 0.7) * (1 + 0.03 * Math.sin(t * 1.3 + i)), D.corona, 0.28 - i * 0.05);
      c.save(); c.translate(sx, sy); c.rotate(t * D.spin);
      for (var j = 0; j < D.rays; j++) {                                  // rays: thin triangles fading outward
        c.rotate(u.TAU / D.rays);
        var len = r * (2.2 + 0.6 * Math.sin(t * 0.7 + j * 2.1));
        c.fillStyle = u.lin(0, 0, len, 0, [[0, u.rgba(D.corona, 0.22)], [1, u.rgba(D.corona, 0)]]);
        c.beginPath(); c.moveTo(r * 0.9, -r * 0.08); c.lineTo(len, 0); c.lineTo(r * 0.9, r * 0.08); c.fill();
      }
      c.restore();
      c.globalCompositeOperation = "source-over";                         // back to normal for the matter
      c.fillStyle = u.rad(sx, sy, r, [[0, D.core], [0.55, D.disc], [1, D.limb]]);   // limb darkening: bright centre, dim edge
      c.beginPath(); c.arc(sx, sy, r, 0, u.TAU); c.fill();
      u.label("core → falloff → thrown light: the disc is one radial, the corona four more, added", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { sx = x; sy = y; }                            // click = put the sun there
  };
});

def("C", "Candle", "light", "a flame is two glows and a bright tip, wobbling; the wall is lit by a radial that flickers with it, the wax a cylinder lit from the flame side", function make(u) {
  var D = { wall: "#1A1424", flame: "#FFB040", tip: "#FFF6D8", blue: "#5A8AFF", wax: "#E8DCC0",
            wobble: 1.0, reach: 0.55, count: 1 };                           // reach: how far the wall is lit
  var cx = u.W * 0.5, top = u.H * 0.5, floor = u.H * 0.8;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.ctx.fillStyle = D.wall; u.ctx.fillRect(0, 0, u.W, u.H);
      u.ground(floor, "#100C18");
      for (var i = 0; i < D.count; i++) {
        var x0 = cx + (i - (D.count - 1) / 2) * u.W * 0.16, ph = i * 2.3;
        var w = Math.sin(t * 9 * D.wobble + ph) * 0.6 + Math.sin(t * 23 * D.wobble + ph) * 0.4;   // two sines that disagree = wobble
        var fx = x0 + w * u.W * 0.012, fy = top - u.H * 0.07, flick = 0.85 + 0.15 * Math.sin(t * 13 * D.wobble + ph);
        u.soft(fx, fy, u.W * D.reach * flick, D.flame, 0.5 / D.count);    // the thrown light on the wall, breathing with the flame
        u.soft(fx, floor, u.W * 0.25, D.flame, 0.25 * flick);            // and a pool on the table
        u.cyl(x0, floor, u.W * 0.08, floor - top, D.wax, w * 0.5);        // the wax: lit from whichever side the flame leans
        u.line(x0, top, x0, fy + u.H * 0.03, "#3A2A20", 1.5);            // the wick
        u.ctx.globalCompositeOperation = "lighter";
        u.soft(fx, fy + u.H * 0.03, u.W * 0.02, D.blue, 0.6);            // the blue base
        u.soft(fx, fy, u.W * 0.05 * flick, D.flame, 0.7);                // the body glow
        u.soft(fx + w * 2, fy - u.H * 0.025, u.W * 0.02, D.tip, 0.9);    // the hot tip
        u.ctx.globalCompositeOperation = "source-over";
      }
      u.label("three soft radials added = a flame; a fourth on the wall, following it = the light it throws", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { cx = x; top = u.clamp(y, u.H * 0.3, u.H * 0.7); }   // click = move the candle, taller or shorter
  };
});

def("E", "Eclipse", "light", "a dark disc over a bright corona: streaky glows and thin radial lines, added, breathing slowly — the sky darkens as totality nears (press x scrubs)", function make(u) {
  var D = { sky: "#2A4F9A", dark: "#05050F", corona: "#FFF4E0", moon: "#0A0A12",
            size: 0.14, moonSize: 1.02, streaks: 28, breath: 0.4 };        // moonSize > 1 = total; < 1 = annular
  var k = 0.85, cx = u.W * 0.5, cy = u.H * 0.45;                           // k: 0 = full sun, 1 = totality
  var R = u.rng(7), st = [];
  for (var j = 0; j < D.streaks; j++) st.push({ a: R() * u.TAU, len: 1.4 + R() * 1.6, ph: R() * 9 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([u.mix(D.sky, D.dark, k), u.mix(u.shade(D.sky, 0.3), u.shade(D.dark, 0.1), k)]);   // the day drains out
      var r = u.W * D.size, c = u.ctx, br = 1 + 0.06 * Math.sin(t * D.breath * u.TAU);
      c.globalCompositeOperation = "lighter";
      u.soft(cx, cy, r * 3.2 * br, D.corona, 0.18 * k);                   // the corona only shows once the disc is dark
      u.soft(cx, cy, r * 1.8 * br, D.corona, 0.35 * k);
      for (var i = 0; i < st.length; i++) {                               // streaks: thin lines from the rim outward
        var s = st[i], a = 0.25 * k * (0.6 + 0.4 * Math.sin(t * 0.8 + s.ph));
        u.line(cx + Math.cos(s.a) * r * 1.02, cy + Math.sin(s.a) * r * 1.02,
               cx + Math.cos(s.a) * r * s.len * br, cy + Math.sin(s.a) * r * s.len * br, u.rgba(D.corona, a), 1);
      }
      c.globalCompositeOperation = "source-over";
      u.dot(cx, cy, r, "#FFF0C0");                                         // the sun's disc
      u.dot(cx + (1 - k) * r * 2.2, cy - (1 - k) * r * 0.4, r * D.moonSize, D.moon);   // the moon slides across it
      u.label("the corona was always there — the source has to be covered before its falloff can be seen", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { k = x / u.W; }                                // click = scrub toward totality by x
  };
});

def("F", "Flare", "light", "a lens flare: soft discs and rings strung along the line from the sun through the canvas centre, sizes and hues varying, plus one horizontal streak", function make(u) {
  var D = { sky: ["#1A2A5A", "#6A9AD0"], sun: "#FFF8E0", hues: [40, 200, 300, 160], ghosts: 7,
            streak: "#9AC8FF", streakLen: 0.9, hex: false };                // hex: true draws the ghosts as hexagons
  var sx = u.W * 0.3, sy = u.H * 0.3;
  var R = u.rng(4), gh = [];
  for (var j = 0; j < D.ghosts; j++) gh.push({ k: -0.6 + R() * 2.4, r: 0.02 + R() * 0.07, ring: R() < 0.4, hue: D.hues[j % D.hues.length] + R() * 20 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.poly([[0, u.H * 0.82], [u.W * 0.3, u.H * 0.7], [u.W * 0.55, u.H * 0.78], [u.W * 0.8, u.H * 0.66], [u.W, u.H * 0.74], [u.W, u.H], [0, u.H]], "#0E1428");
      var c = u.ctx, cx = u.W / 2, cy = u.H / 2;
      u.soft(sx, sy, u.W * 0.6, D.sun, 0.35);                              // the thrown light: haze around the sun
      c.globalCompositeOperation = "lighter";
      u.soft(sx, sy, u.W * 0.08, D.sun, 1);
      c.save(); c.translate(sx, sy); c.scale(1, 0.05);                     // the anamorphic streak: a glow squashed flat
      u.soft(0, 0, u.W * D.streakLen, D.streak, 0.6); c.restore();
      for (var i = 0; i < gh.length; i++) {                                // ghosts: mirrored through the centre by factor k
        var g = gh[i], px = cx + (cx - sx) * g.k, py = cy + (cy - sy) * g.k, r = u.W * g.r;
        var col = u.hsl(g.hue, 0.8, 0.65);
        if (g.ring) { c.strokeStyle = u.rgba(col, 0.35); c.lineWidth = r * 0.25; c.beginPath(); c.arc(px, py, r, 0, u.TAU); c.stroke(); }
        else if (D.hex) { var pts = []; for (var h = 0; h < 6; h++) pts.push([px + Math.cos(h * u.TAU / 6) * r, py + Math.sin(h * u.TAU / 6) * r]); u.poly(pts, u.rgba(col, 0.3)); }
        else u.soft(px, py, r, col, 0.45);
      }
      c.globalCompositeOperation = "source-over";
      u.label("every ghost sits at centre + (centre − sun) × k — move the sun and the whole chain re-aims", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { sx = x; sy = y; }                            // click = move the sun; the chain follows
  };
});

def("H", "Hearth", "light", "a dark room lit by one warm radial centred on the fire; the fire is stacked glows, the light flickers, two blocks throw long soft shadows away from it", function make(u) {
  var D = { sky: ["#0A0810", "#0A0810"], mantle: "#2A1C1A", warm: "#FF9A40", hot: "#FFE0A0",
            flicker: 1.0, reach: 0.9 };                                      // mantle: null = no fireplace (outdoors)
  var fx = u.W * 0.5, fy = u.H * 0.72;
  var blocks = [[0.2, 0.05], [0.78, 0.06]];                                 // two furniture blocks: x, half-width
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ground(fy, "#0E0A12");
      var f = 0.8 + 0.2 * (Math.sin(t * 7 * D.flicker) * 0.5 + Math.sin(t * 17 * D.flicker) * 0.3 + Math.sin(t * 31 * D.flicker) * 0.2);   // amplitude noise
      u.soft(fx, fy, u.W * D.reach * f, D.warm, 0.55);                     // the thrown light: one radial over wall AND floor
      if (D.mantle) {                                                       // the fireplace: a dark opening in a lit surround
        u.ctx.fillStyle = u.rad(fx, fy - u.H * 0.08, u.W * 0.22, [[0, u.shade(D.mantle, 0.5)], [1, D.mantle]]);
        u.ctx.fillRect(fx - u.W * 0.15, fy - u.H * 0.26, u.W * 0.3, u.H * 0.26);
        u.ctx.fillStyle = "#05040A"; u.ctx.fillRect(fx - u.W * 0.1, fy - u.H * 0.18, u.W * 0.2, u.H * 0.18);
      }
      u.ctx.globalCompositeOperation = "lighter";
      u.soft(fx, fy - u.H * 0.03, u.W * 0.09 * f, D.warm, 0.8);            // the fire: three glows stacked
      u.soft(fx, fy - u.H * 0.06, u.W * 0.05 * f, D.hot, 0.8);
      u.soft(fx, fy - u.H * 0.01, u.W * 0.05, "#FF5020", 0.6);
      u.ctx.globalCompositeOperation = "source-over";
      for (var i = 0; i < blocks.length; i++) {
        var bx = u.W * blocks[i][0], bw = u.W * blocks[i][1], dir = bx > fx ? 1 : -1, len = u.W * 0.3 * f;
        var sh = u.lin(bx, 0, bx + dir * len, 0, [[0, "rgba(0,0,0,0.6)"], [1, "rgba(0,0,0,0)"]]);   // a long shadow, fading with distance
        u.poly([[bx - bw, fy], [bx + bw, fy], [bx + bw + dir * len, fy + u.H * 0.07], [bx - bw + dir * len, fy + u.H * 0.07]], sh);
        var lit = u.mix("#3A2A2A", D.warm, 0.5 * f), dark = "#120C10";
        u.ctx.fillStyle = u.lin(bx - bw, 0, bx + bw, 0, dir > 0 ? [lit, dark] : [dark, lit]);   // the face toward the fire is lit
        u.ctx.fillRect(bx - bw, fy - u.H * 0.1, bw * 2, u.H * 0.1);
      }
      u.label("one radial lights wall and floor at once; shadows point away from it and fade with length", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { fx = x; }                                     // click = move the fire along the floor
  };
});

def("K", "Kiln", "light", "a chamber glowing from within: a hot radial inside a dark box, breathing; embers drifting out; a wedge of glow spilling onto the floor", function make(u) {
  var D = { bg: ["#0C0A10", "#100D14"], brick: "#3A2A28", hot: "#FFD070", heat: "#FF6A20",
            period: 2.0, embers: 24, drift: 1.0 };                           // period: seconds per breath
  var kx = u.W * 0.5, fy = u.H * 0.75;
  var R = u.rng(5), em = [];
  for (var j = 0; j < D.embers; j++) em.push({ ph: R(), spd: 0.12 + R() * 0.12, dx: (R() - 0.5) * u.W * 0.2, s: 0.6 + R() * 1.2 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(fy, "#0A080E");
      var br = 0.7 + 0.3 * (0.5 + 0.5 * Math.sin(t * u.TAU / D.period)), c = u.ctx;   // the heat breathes
      c.fillStyle = u.rad(kx, fy - u.H * 0.1, u.W * 0.3, [[0, u.mix(D.brick, D.heat, 0.45 * br)], [1, D.brick]]);   // the box, lit near its mouth
      c.fillRect(kx - u.W * 0.18, fy - u.H * 0.42, u.W * 0.36, u.H * 0.42);
      c.fillStyle = u.rad(kx, fy - u.H * 0.04, u.W * 0.11, [[0, D.hot], [0.5, u.mix(D.heat, "#3A0A00", 1 - br)], [1, "#200400"]]);   // the interior: a hot radial
      c.beginPath(); c.moveTo(kx - u.W * 0.07, fy); c.lineTo(kx - u.W * 0.07, fy - u.H * 0.12);
      c.arc(kx, fy - u.H * 0.12, u.W * 0.07, Math.PI, 0); c.lineTo(kx + u.W * 0.07, fy); c.fill();
      c.save(); c.beginPath(); c.moveTo(kx - u.W * 0.07, fy); c.lineTo(kx + u.W * 0.07, fy);   // the spill: a wedge clipped on the floor
      c.lineTo(kx + u.W * 0.32, u.H); c.lineTo(kx - u.W * 0.32, u.H); c.clip();
      u.soft(kx, fy, u.H * 0.32, D.heat, 0.6 * br); c.restore();
      c.globalCompositeOperation = "lighter";
      for (var i = 0; i < em.length; i++) {                                 // embers: born at the mouth, fading as they rise
        var e = em[i], life = (t * e.spd * D.drift + e.ph) % 1;
        u.dot(kx + e.dx * life + Math.sin(t * 2 + e.ph * 9) * 3, fy - u.H * 0.04 - life * u.H * 0.4, e.s, u.rgba(D.hot, (1 - life) * 0.9));
      }
      c.globalCompositeOperation = "source-over";
      u.label("light from inside a box: the core is hidden, so the falloff and the spill do all the telling", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { kx = x; }                                     // click = slide the kiln along the floor
  };
});

def("L", "Lantern", "light", "a paper lantern: a warm gradient shell with dark ribs, lit by a core inside, hanging from a hook as a real pendulum — press to move the hook and the lantern trails behind, swings through and rings down; the pool of light on the ground moves with it", function make(u) {
  var D = { sky: ["#0A0818", "#1A1030"], paper: "#FF8A3A", core: "#FFF0C0", ribs: 7,
            sway: 1.0, count: 1, rise: 0,                                    // sway: how hard the breeze pushes; rise > 0: the lanterns float upward and wrap
            swing: 2.2,              // the pendulum's natural rate, rad/s: √(g/L) — set by the string, not by the clock
            damp: 0.18,              // as a fraction of critical: well under 1, so a lantern rings down over several swings
            hook: 3,                 // the hook's own spring toward where a press asked for: k (critically damped, so it eases and never overshoots)
            wind: 0.5 };             // the breeze's push on a lantern, rad/s², times sway — the only thing that stirs it between presses
  var px = u.W * 0.5, py = u.H * 0.12, GY = u.H * 0.82;
  var ht = px, hv = 0;                                                       // where the hook is asked to be, and how fast it is moving
  var nl = Math.max(1, D.count), th = new Float32Array(nl), om = new Float32Array(nl);   // each lantern's angle from the vertical + angular velocity
  for (var q = 0; q < nl; q++) th[q] = 0.12 * (q % 2 ? -1 : 1);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ground(GY, "#0C0A14");
      // each lantern is a real pendulum: θ'' = −(g/L)·sin θ − c·θ' − (a_hook/L)·cos θ.
      // gravity rights it (g/L = swing²), a little damping bleeds each swing,
      // and the hook's own ACCELERATION drives it: a press does not move the
      // hook — it moves the hook's target, the hook springs there (critically
      // damped, so it eases), and the lantern, left behind, swings out and
      // rings down. a soft breeze (two slow sines: an input, not the answer)
      // keeps the lanterns stirring between presses.
      var L = u.H * 0.32, g = D.swing * D.swing, cc = D.damp * 2 * D.swing, kh = D.hook, dh = 2 * Math.sqrt(kh);
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, s, i;        // substeps of ≤ 0.02 s: symplectic euler wants √k·h < 2
      for (s = 0; s < sub; s++) {
        var ah = kh * (ht - px) - dh * hv;                                  // the hook's acceleration this step — what the string passes down
        hv += ah * h; px += hv * h;
        for (i = 0; i < nl; i++) {
          var breeze = D.wind * D.sway * (0.6 * Math.sin(t * 0.9 + i * 2) + 0.4 * Math.sin(t * 1.7 + i));
          om[i] += (-g * Math.sin(th[i]) - cc * om[i] - ah / L * Math.cos(th[i]) + breeze) * h;
          th[i] = u.clamp(th[i] + om[i] * h, -1.2, 1.2);
        }
      }
      var c = u.ctx, rw = u.W * 0.085, rh = u.H * 0.12;
      for (i = 0; i < nl; i++) {
        var ang = th[i];
        var hook = px + (i - (nl - 1) / 2) * u.W * 0.17, lx = hook + Math.sin(ang) * L;
        var ly = py + Math.cos(ang) * L - D.rise * ((t * 0.06 + i * 0.37) % 1) * u.H * 0.5;
        var hk = u.clamp((GY - ly - rh) / (u.H * 0.6), 0, 1);              // how high above the ground: 0 low, 1 high
        c.save(); c.translate(lx, GY); c.scale(1, 0.3);                     // the pool: wider and fainter the higher the lamp
        u.soft(0, 0, u.W * (0.15 + hk * 0.3), D.paper, 0.55 * (1 - hk)); c.restore();
        if (!D.rise) u.line(hook, py, lx, ly - rh, "rgba(232,229,244,0.35)", 1);   // the string
        c.globalCompositeOperation = "lighter";
        u.soft(lx, ly, rw * 3, D.paper, 0.35);                              // the halo round the shell
        c.globalCompositeOperation = "source-over";
        c.save(); c.translate(lx, ly); c.scale(1, rh / rw);                 // the shell: a radial lit from a core inside
        c.fillStyle = u.rad(0, 0, rw, [[0, D.core], [0.45, D.paper], [1, u.shade(D.paper, -0.45)]]);
        c.beginPath(); c.arc(0, 0, rw, 0, u.TAU); c.fill();
        for (var j = 0; j < D.ribs; j++) {                                  // ribs: thin dark verticals across the shell
          var xr = -rw + (j + 0.5) * (2 * rw / D.ribs), yr = Math.sqrt(Math.max(0, rw * rw - xr * xr));
          u.line(xr, -yr, xr, yr, "rgba(0,0,0,0.25)", 1);
        }
        c.restore();
        c.fillStyle = "#2A1A14"; c.fillRect(lx - rw * 0.3, ly - rh - 3, rw * 0.6, 4); c.fillRect(lx - rw * 0.3, ly + rh - 1, rw * 0.6, 4);   // cap and base
      }
      u.label("a shell is a radial with the core inside it; the pool below is the same light, arriving late — θ'' = −swing²·sin θ − damp·θ' − a_hook/L·cos θ", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { ht = x; }                                     // click = ask the hook to go there; it eases, the lantern trails, the pool follows
  };
});

def("M", "Moonphases", "light", "a sphere shaded by a light that orbits over time — the terminator moves new → crescent → half → full; one offset radial plus one dark disc", function make(u) {
  var D = { sky: ["#03030A", "#0B0B1E"], moons: ["#D8D8E0"], dark: "#0E0E1A", glow: "#B8C8FF",
            size: 0.2, month: 8, count: 1 };                                // month: seconds for one full cycle
  var phase = null;
  var R = u.rng(12), stars = [];
  for (var j = 0; j < 50; j++) stars.push([R() * u.W, R() * u.H, 0.3 + R() * 1.0]);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      for (var s = 0; s < stars.length; s++) u.dot(stars[s][0], stars[s][1], stars[s][2], u.rgba(u.INK, 0.4 + 0.3 * Math.sin(t * 2 + s)));
      var k0 = phase !== null ? phase : (t / D.month) % 1;                 // 0 new → 0.25 first quarter → 0.5 full → 1 new
      for (var i = 0; i < D.count; i++) {
        var k = (k0 + i * 0.3) % 1, mx = u.W * (0.5 + (i - (D.count - 1) / 2) * 0.42), my = u.H * 0.45;
        var r = u.W * D.size * (1 - i * 0.35), col = D.moons[i % D.moons.length];
        var f = 0.5 - 0.5 * Math.cos(k * u.TAU);                           // the lit fraction: 0 new, 1 full
        var dir = k < 0.5 ? 1 : -1, lx = Math.sin(k * u.TAU);             // waxing lights the right edge, waning the left
        u.soft(mx, my, r * 2.6, D.glow, 0.18 * f);                         // the thrown light: the sky glows by how full it is
        u.sphere(mx, my, r, col, lx, -0.2, { spec: 0.15 });                // the shading follows the light like any ball
        u.dot(mx - dir * (f * 2 * r), my, r * 1.01, D.dark);               // the shadow disc slides off as the moon fills
        u.dot(mx, my, r, u.rgba(col, 0.08 * (1 - f)));                     // earthshine: the dark side is not quite black
      }
      u.label("the terminator IS the sphere: a shading offset plus a sliding dark disc, nothing else", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { phase = x / u.W; }                            // click = set the phase by x
  };
});

def("N", "Neon", "light", "a neon sign: one path stroked four times, wider and fainter each pass (the falloff), added; it flickers; the wall gets a glow of the same hue", function make(u) {
  var D = { wall: "#141018", tube: "#FF2A8A", passes: 4, flicker: 0.15, wobble: 0 };   // flicker: chance per tick of a dim moment
  var R = u.rng(9), flick = 1, nextAt = 0, ox = 0, oy = 0;
  var pts = [];
  for (var i = 0; i <= 40; i++) pts.push([u.W * (0.2 + 0.6 * i / 40), u.H * 0.45 + Math.sin(i * 0.9) * u.H * 0.1 + Math.sin(i * 0.37) * u.H * 0.05]);   // a word-like squiggle
  function trace(c, jx, jy) { c.beginPath(); for (var i = 0; i < pts.length; i++) { if (i === 0) c.moveTo(pts[i][0] + jx, pts[i][1] + jy); else c.lineTo(pts[i][0] + jx, pts[i][1] + jy); } c.stroke(); }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var c = u.ctx;
      c.fillStyle = D.wall; c.fillRect(0, 0, u.W, u.H);
      if (t > nextAt) { flick = R() < D.flicker ? 0.2 + R() * 0.5 : 1; nextAt = t + 0.08 + R() * 0.3; }   // a tube does not fade — it stutters
      for (var b = 0; b < 6; b++) u.line(0, u.H * 0.14 * b, u.W, u.H * 0.14 * b, "rgba(255,255,255,0.03)", 1);   // brick courses, barely there
      u.soft(u.W / 2 + ox, u.H * 0.45 + oy, u.W * 0.6, D.tube, 0.35 * flick);   // the wall glow: the thrown light
      u.ground(u.H * 0.85, "#0A080C");
      c.save(); c.translate(u.W / 2 + ox, u.H * 0.85); c.scale(1, 0.25); u.soft(0, 0, u.W * 0.4, D.tube, 0.2 * flick); c.restore();   // a smear on the wet floor
      c.globalCompositeOperation = "lighter";
      c.lineCap = "round"; c.lineJoin = "round";
      for (var p = D.passes - 1; p >= 0; p--) {                            // widest and faintest first, hot core last
        var jx = ox + D.wobble * (R() - 0.5) * 4, jy = oy + D.wobble * (R() - 0.5) * 4;
        c.lineWidth = 2 + p * p * 3;                                        // 2, 5, 14, 29 — the falloff is repetition
        c.strokeStyle = u.rgba(p === 0 ? u.shade(D.tube, 0.6) : D.tube, (p === 0 ? 0.95 : 0.4 / p) * flick);
        trace(c, jx, jy);
      }
      c.globalCompositeOperation = "source-over";
      u.label("one path, four strokes: a thin white-hot core, then wider fainter halos — added, not layered", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { ox = x - u.W / 2; oy = y - u.H * 0.45; }    // click = hang the sign there; the glow follows
  };
});

def("Q", "Quasar", "light", "a hot core, two opposite jets (glows stretched with ctx.scale), and a torus-like accretion ring — all added, slowly rotating; pure light, no matter", function make(u) {
  var D = { sky: ["#020208", "#0A0618"], core: "#FFFFFF", jet: "#7AB8FF", disc: "#FF8A5A",
            spin: 0.35, jetLen: 0.45, pulse: 0 };                            // pulse: seconds per beat (0 = steady)
  var cx = u.W / 2, cy = u.H * 0.48;
  var R = u.rng(17), stars = [];
  for (var j = 0; j < 70; j++) stars.push([R() * u.W, R() * u.H, 0.3 + R() * 0.9]);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      for (var s = 0; s < stars.length; s++) u.dot(stars[s][0], stars[s][1], stars[s][2], u.rgba(u.INK, 0.5));
      var c = u.ctx, amp = D.pulse > 0 ? 0.15 + 0.85 * Math.pow(0.5 + 0.5 * Math.cos(t * u.TAU / D.pulse), 8) : 1;   // a beat: a sharpened cosine
      c.save(); c.translate(cx, cy); c.rotate(t * D.spin + 0.5);
      c.globalCompositeOperation = "lighter";
      c.save(); c.scale(1, 0.32);                                           // the accretion ring: glows squashed into a torus
      u.soft(0, 0, u.W * 0.3, D.disc, 0.18);
      for (var i = 0; i < 3; i++) { c.strokeStyle = u.rgba(D.disc, 0.35 - i * 0.1); c.lineWidth = u.W * (0.02 + i * 0.025); c.beginPath(); c.arc(0, 0, u.W * 0.15, 0, u.TAU); c.stroke(); }
      c.restore();
      for (var sgn = -1; sgn <= 1; sgn += 2) {                              // the jets: glows stretched along the spin axis
        c.save(); c.scale(0.28, 1);
        u.soft(0, sgn * u.H * D.jetLen * 0.55, u.H * D.jetLen * 0.6, D.jet, 0.35 * amp);
        u.soft(0, sgn * u.H * D.jetLen * 0.25, u.H * D.jetLen * 0.3, D.jet, 0.45 * amp);
        c.restore();
      }
      u.soft(0, 0, u.W * 0.12, D.jet, 0.5 * amp);                          // the core: two glows, the inner one white
      u.soft(0, 0, u.W * 0.04, D.core, amp);
      c.globalCompositeOperation = "source-over";
      c.restore();
      u.label("additive only: nothing here is solid, so every overlap is brighter — that IS how light behaves", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { cx = x; cy = y; }                            // click = move the engine
  };
});

def("R", "Rimlight", "light", "a backlit figure: a dark silhouette (sphere + body) with a bright rim on the edge nearest the light, a soft light behind — press moves the light", function make(u) {
  var D = { sky: ["#0C0A1A", "#241A3A"], ground: "#0A0812", light: "#FFE8B0", body: "#1A1424", rim: "#FFE8B0", size: 0.11 };
  var lx = u.W * 0.72, ly = u.H * 0.3, GY = u.H * 0.8;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ground(GY, D.ground);
      u.soft(lx, ly, u.W * 0.55, D.light, 0.5);                            // the source and its falloff, behind everything
      u.soft(lx, ly, u.W * 0.12, D.light, 0.95);
      var hx = u.W * 0.5, hy = u.H * 0.42, r = u.W * D.size;
      var dx = lx - hx, dy = ly - hy, len = Math.sqrt(dx * dx + dy * dy) || 1; dx /= len; dy /= len;   // unit vector toward the light
      u.shadow(hx - dx * u.W * 0.18, GY + 3, r * 1.8, r * 0.4, 0.5);        // the cast shadow points away from the light
      var side = dx >= 0 ? 1 : 0, edge = 0.12 * Math.abs(dx) + 0.02;       // the body's rim: a sliver on the light's side
      u.ctx.fillStyle = u.lin(hx - r * 1.1, 0, hx + r * 1.1, 0, side ? [[0, D.body], [1 - edge, D.body], [1, u.rgba(D.rim, 0.85)]] : [[0, u.rgba(D.rim, 0.85)], [edge, D.body], [1, D.body]]);
      u.ctx.fillRect(hx - r * 1.1, hy + r * 0.9, r * 2.2, GY - hy - r * 0.9);
      u.sphere(hx, hy, r, D.body, dx, dy, { rim: D.rim, spec: 0.05, dark: "#0A0810" });   // the head: dark ball, rim toward the light
      u.label("the rim is the edge nearest the light — a thin bright arc says 'lit from behind' on its own", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { lx = x; ly = y; }                            // click = move the light; the rim turns to face it
  };
});

def("U", "Ultraviolet", "light", "a blacklight room: a thin violet tube, its falloff on the wall, and only certain shapes glow — saturated additive violet and green with soft halos", function make(u) {
  var D = { room: "#07050C", tube: "#B08CFF", tubeCore: "#F0E8FF", glowA: "#8A3AFF", glowB: "#3AFF9A",
            reach: 0.55, shapes: 7, bob: 0 };                                 // bob > 0: the shapes drift as if floating
  var tx = u.W * 0.5, ty = u.H * 0.12;
  var R = u.rng(6), sh = [];
  for (var j = 0; j < D.shapes; j++) sh.push({ x: 0.1 + R() * 0.8, y: 0.35 + R() * 0.45, r: 0.015 + R() * 0.03, a: R() < 0.5, ph: R() * 9 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var c = u.ctx, hum = 1 + 0.05 * Math.sin(t * 40);                      // a tube hums: a fast tiny shiver in brightness
      c.fillStyle = D.room; c.fillRect(0, 0, u.W, u.H);
      u.soft(tx, ty, u.W * D.reach, D.tube, 0.35 * hum);                    // the falloff on the wall
      u.ground(u.H * 0.82, "#05040A");
      c.fillStyle = "#100C16"; c.fillRect(u.W * 0.1, u.H * 0.6, u.W * 0.25, u.H * 0.22); c.fillRect(u.W * 0.65, u.H * 0.66, u.W * 0.2, u.H * 0.16);   // dull matter: it does NOT glow
      c.globalCompositeOperation = "lighter";
      for (var i = 0; i < sh.length; i++) {                                 // the things that fluoresce
        var s = sh[i], col = s.a ? D.glowA : D.glowB, a = 0.6 + 0.3 * Math.sin(t * 1.5 + s.ph);
        var x = u.W * s.x + D.bob * Math.sin(t * 0.7 + s.ph) * u.W * 0.03, y = u.H * s.y + D.bob * Math.cos(t * 0.5 + s.ph) * u.H * 0.03;
        u.soft(x, y, u.W * s.r * 2.6, col, 0.35 * a * hum);
        u.dot(x, y, u.W * s.r, u.rgba(col, 0.95));
      }
      c.save(); c.translate(tx, ty); c.scale(1, 0.18); u.soft(0, 0, u.W * 0.32, D.tube, 0.6 * hum); c.restore();   // the tube's own halo, squashed flat
      c.globalCompositeOperation = "source-over";
      c.fillStyle = D.tubeCore; c.fillRect(tx - u.W * 0.28, ty - 2, u.W * 0.56, 4);   // the hard core: a thin bar
      u.label("under a black light only the fluorescent things are bright — glow is a property of the object", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { tx = x; ty = y; }                            // click = move the tube
  };
});

def("X", "Xenon", "light", "a strobe tube: a hard white bar, a blue-white falloff, a short pulse every 1.5 s that lights the whole scene for an instant; dim in between", function make(u) {
  var D = { room: "#0A0A12", flash: "#DCEBFF", bar: "#FFFFFF", every: 1.5, decay: 9, auto: true };   // decay: how fast a flash dies (per second)
  var tx = u.W * 0.5, ty = u.H * 0.2, GY = u.H * 0.8, lastFlash = -9, lastT = 0;
  var blocks = [[0.22, 0.05], [0.5, 0.045], [0.76, 0.055]];               // three boxes on the floor, for the flash to find
  return {
    frame: function (dt, t) {
      lastT = t;
      if (D.auto && t - lastFlash >= D.every) lastFlash = Math.floor(t / D.every) * D.every;
      var p = Math.exp(-Math.max(0, t - lastFlash) * D.decay), c = u.ctx;  // the pulse: 1 at the flash, gone in a tenth of a second
      c.fillStyle = D.room; c.fillRect(0, 0, u.W, u.H);
      u.ground(GY, "#07070E");
      u.soft(tx, ty, u.W * 1.1, D.flash, 0.12 + 0.88 * p);                 // the thrown light: the whole room, for an instant
      for (var i = 0; i < blocks.length; i++) {
        var bx = u.W * blocks[i][0], s = u.W * blocks[i][1], dir = (bx - tx) / (u.W * 0.5);
        u.shadow(bx + dir * s * 3 * p, GY + 2, s * 2, s * 0.5, 0.55 * p);   // hard shadows appear only while the flash is on
        u.cube(bx, GY, s, u.mix("#2A2A3A", D.flash, 0.1 + 0.7 * p));
      }
      c.globalCompositeOperation = "lighter";
      c.save(); c.translate(tx, ty); c.scale(1, 0.2); u.soft(0, 0, u.W * 0.35, D.flash, 0.3 + 0.7 * p); c.restore();   // the tube's falloff
      c.globalCompositeOperation = "source-over";
      c.fillStyle = u.rgba(D.bar, 0.5 + 0.5 * p); c.fillRect(tx - u.W * 0.2, ty - 2, u.W * 0.4, 4);   // the hard core: a bar, dim when off
      u.label("a flash is the falloff with its alpha on a clock — the scene exists only while the light does", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { tx = x; ty = y; lastFlash = lastT; }         // click = move the tube and fire it now
  };
});

/* ---- the rhymes: same pictures, two or three dials moved ---- */

rhymeOf("Sun", "Red giant", "the same sun swollen and cooled — a crimson palette, a disc almost twice as wide, six corona layers, a slower spin", function make(u) {
  // rhyme of Sun: dials moved — palette to reds, size 0.13 → 0.22, layers 4 → 6, spin 0.08 → 0.03
  var D = { sky: ["#0A0508", "#3A0A14"], core: "#FFE0B0", disc: "#FF6A3A", limb: "#8A1A10", corona: "#FF5A3A",
            size: 0.22, layers: 6, rays: 12, spin: 0.03 };
  var sx = u.W * 0.5, sy = u.H * 0.45;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var r = u.W * D.size, c = u.ctx;
      u.soft(sx, sy, u.W * 0.8, D.corona, 0.22);
      c.globalCompositeOperation = "lighter";
      for (var i = 0; i < D.layers; i++)
        u.soft(sx, sy, r * (1.4 + i * 0.7) * (1 + 0.03 * Math.sin(t * 1.3 + i)), D.corona, 0.28 - i * 0.04);
      c.save(); c.translate(sx, sy); c.rotate(t * D.spin);
      for (var j = 0; j < D.rays; j++) {
        c.rotate(u.TAU / D.rays);
        var len = r * (2.2 + 0.6 * Math.sin(t * 0.7 + j * 2.1));
        c.fillStyle = u.lin(0, 0, len, 0, [[0, u.rgba(D.corona, 0.22)], [1, u.rgba(D.corona, 0)]]);
        c.beginPath(); c.moveTo(r * 0.9, -r * 0.08); c.lineTo(len, 0); c.lineTo(r * 0.9, r * 0.08); c.fill();
      }
      c.restore();
      c.globalCompositeOperation = "source-over";
      c.fillStyle = u.rad(sx, sy, r, [[0, D.core], [0.55, D.disc], [1, D.limb]]);
      c.beginPath(); c.arc(sx, sy, r, 0, u.TAU); c.fill();
      u.label("a star's age is three hex codes and a radius — the limb darkening is the same ramp, redder", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { sx = x; sy = y; }
  };
});

rhymeOf("Candle", "Birthday candles", "the same flame three times over in pastel — pink wax, a cream wall, each flame wobbling on its own phase", function make(u) {
  // rhyme of Candle: dials moved — count 1 → 3, wall/wax palette to pastel, reach 0.55 → 0.4
  var D = { wall: "#3A2A44", flame: "#FFC070", tip: "#FFF6D8", blue: "#8AB0FF", wax: "#F5B8D0",
            wobble: 1.0, reach: 0.4, count: 3 };
  var cx = u.W * 0.5, top = u.H * 0.5, floor = u.H * 0.8;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.ctx.fillStyle = D.wall; u.ctx.fillRect(0, 0, u.W, u.H);
      u.ground(floor, "#2A1E30");
      for (var i = 0; i < D.count; i++) {
        var x0 = cx + (i - (D.count - 1) / 2) * u.W * 0.16, ph = i * 2.3;
        var w = Math.sin(t * 9 * D.wobble + ph) * 0.6 + Math.sin(t * 23 * D.wobble + ph) * 0.4;
        var fx = x0 + w * u.W * 0.012, fy = top - u.H * 0.07, flick = 0.85 + 0.15 * Math.sin(t * 13 * D.wobble + ph);
        u.soft(fx, fy, u.W * D.reach * flick, D.flame, 0.5 / D.count);
        u.soft(fx, floor, u.W * 0.25, D.flame, 0.25 * flick);
        u.cyl(x0, floor, u.W * 0.08, floor - top, D.wax, w * 0.5);
        u.line(x0, top, x0, fy + u.H * 0.03, "#3A2A20", 1.5);
        u.ctx.globalCompositeOperation = "lighter";
        u.soft(fx, fy + u.H * 0.03, u.W * 0.02, D.blue, 0.6);
        u.soft(fx, fy, u.W * 0.05 * flick, D.flame, 0.7);
        u.soft(fx + w * 2, fy - u.H * 0.025, u.W * 0.02, D.tip, 0.9);
        u.ctx.globalCompositeOperation = "source-over";
      }
      u.label("three sources = three overlapping falloffs; additive, they sum into one warm wall", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { cx = x; top = u.clamp(y, u.H * 0.3, u.H * 0.7); }
  };
});

rhymeOf("Eclipse", "Ring of fire", "the same eclipse, annular — the moon a touch too small, so a thin bright ring survives, with a bigger orange corona and more streaks", function make(u) {
  // rhyme of Eclipse: dials moved — moonSize 1.02 → 0.9, corona colour to orange, streaks 28 → 40
  var D = { sky: "#2A4F9A", dark: "#05050F", corona: "#FFB060", moon: "#0A0A12",
            size: 0.14, moonSize: 0.9, streaks: 40, breath: 0.4 };
  var k = 0.85, cx = u.W * 0.5, cy = u.H * 0.45;
  var R = u.rng(7), st = [];
  for (var j = 0; j < D.streaks; j++) st.push({ a: R() * u.TAU, len: 1.4 + R() * 1.6, ph: R() * 9 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([u.mix(D.sky, D.dark, k), u.mix(u.shade(D.sky, 0.3), u.shade(D.dark, 0.1), k)]);
      var r = u.W * D.size, c = u.ctx, br = 1 + 0.06 * Math.sin(t * D.breath * u.TAU);
      c.globalCompositeOperation = "lighter";
      u.soft(cx, cy, r * 3.2 * br, D.corona, 0.18 * k);
      u.soft(cx, cy, r * 1.8 * br, D.corona, 0.35 * k);
      for (var i = 0; i < st.length; i++) {
        var s = st[i], a = 0.25 * k * (0.6 + 0.4 * Math.sin(t * 0.8 + s.ph));
        u.line(cx + Math.cos(s.a) * r * 1.02, cy + Math.sin(s.a) * r * 1.02,
               cx + Math.cos(s.a) * r * s.len * br, cy + Math.sin(s.a) * r * s.len * br, u.rgba(D.corona, a), 1);
      }
      c.globalCompositeOperation = "source-over";
      u.dot(cx, cy, r, "#FFF0C0");
      u.dot(cx + (1 - k) * r * 2.2, cy - (1 - k) * r * 0.4, r * D.moonSize, D.moon);
      u.label("one radius dial: a moon at 0.9 of the sun leaves a ring of core showing round the dark", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { k = x / u.W; }
  };
});

rhymeOf("Flare", "Anime flare", "the same chain of ghosts, twelve of them, hexagonal and pink — the sun a hot pastel, the streak lilac", function make(u) {
  // rhyme of Flare: dials moved — ghosts 7 → 12, hex false → true, hues/palette to pink
  var D = { sky: ["#2A1A4A", "#C86AA8"], sun: "#FFF0F8", hues: [330, 300, 350, 280], ghosts: 12,
            streak: "#E8B0FF", streakLen: 0.9, hex: true };
  var sx = u.W * 0.3, sy = u.H * 0.3;
  var R = u.rng(4), gh = [];
  for (var j = 0; j < D.ghosts; j++) gh.push({ k: -0.6 + R() * 2.4, r: 0.02 + R() * 0.07, ring: R() < 0.4, hue: D.hues[j % D.hues.length] + R() * 20 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.poly([[0, u.H * 0.82], [u.W * 0.3, u.H * 0.7], [u.W * 0.55, u.H * 0.78], [u.W * 0.8, u.H * 0.66], [u.W, u.H * 0.74], [u.W, u.H], [0, u.H]], "#1A0E28");
      var c = u.ctx, cx = u.W / 2, cy = u.H / 2;
      u.soft(sx, sy, u.W * 0.6, D.sun, 0.35);
      c.globalCompositeOperation = "lighter";
      u.soft(sx, sy, u.W * 0.08, D.sun, 1);
      c.save(); c.translate(sx, sy); c.scale(1, 0.05);
      u.soft(0, 0, u.W * D.streakLen, D.streak, 0.6); c.restore();
      for (var i = 0; i < gh.length; i++) {
        var g = gh[i], px = cx + (cx - sx) * g.k, py = cy + (cy - sy) * g.k, r = u.W * g.r;
        var col = u.hsl(g.hue, 0.8, 0.65);
        if (g.ring) { c.strokeStyle = u.rgba(col, 0.35); c.lineWidth = r * 0.25; c.beginPath(); c.arc(px, py, r, 0, u.TAU); c.stroke(); }
        else if (D.hex) { var pts = []; for (var h = 0; h < 6; h++) pts.push([px + Math.cos(h * u.TAU / 6) * r, py + Math.sin(h * u.TAU / 6) * r]); u.poly(pts, u.rgba(col, 0.3)); }
        else u.soft(px, py, r, col, 0.45);
      }
      c.globalCompositeOperation = "source-over";
      u.label("hard hexagons instead of soft discs: the ghosts now say 'lens' — the geometry is the same", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { sx = x; sy = y; }
  };
});

rhymeOf("Hearth", "Campfire night", "the same fire outdoors — a night-sky palette, no fireplace, the two blocks now logs — and the same long shadows across the grass", function make(u) {
  // rhyme of Hearth: dials moved — sky palette to night, mantle → null (no fireplace), reach 0.9 → 0.7
  var D = { sky: ["#05051A", "#1A2040"], mantle: null, warm: "#FF9A40", hot: "#FFE0A0",
            flicker: 1.0, reach: 0.7 };
  var fx = u.W * 0.5, fy = u.H * 0.72;
  var blocks = [[0.2, 0.05], [0.78, 0.06]];
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ground(fy, "#0A1410");
      var f = 0.8 + 0.2 * (Math.sin(t * 7 * D.flicker) * 0.5 + Math.sin(t * 17 * D.flicker) * 0.3 + Math.sin(t * 31 * D.flicker) * 0.2);
      u.soft(fx, fy, u.W * D.reach * f, D.warm, 0.55);
      if (D.mantle) {
        u.ctx.fillStyle = u.rad(fx, fy - u.H * 0.08, u.W * 0.22, [[0, u.shade(D.mantle, 0.5)], [1, D.mantle]]);
        u.ctx.fillRect(fx - u.W * 0.15, fy - u.H * 0.26, u.W * 0.3, u.H * 0.26);
        u.ctx.fillStyle = "#05040A"; u.ctx.fillRect(fx - u.W * 0.1, fy - u.H * 0.18, u.W * 0.2, u.H * 0.18);
      }
      u.ctx.globalCompositeOperation = "lighter";
      u.soft(fx, fy - u.H * 0.03, u.W * 0.09 * f, D.warm, 0.8);
      u.soft(fx, fy - u.H * 0.06, u.W * 0.05 * f, D.hot, 0.8);
      u.soft(fx, fy - u.H * 0.01, u.W * 0.05, "#FF5020", 0.6);
      u.ctx.globalCompositeOperation = "source-over";
      for (var i = 0; i < blocks.length; i++) {
        var bx = u.W * blocks[i][0], bw = u.W * blocks[i][1], dir = bx > fx ? 1 : -1, len = u.W * 0.3 * f;
        var sh = u.lin(bx, 0, bx + dir * len, 0, [[0, "rgba(0,0,0,0.6)"], [1, "rgba(0,0,0,0)"]]);
        u.poly([[bx - bw, fy], [bx + bw, fy], [bx + bw + dir * len, fy + u.H * 0.07], [bx - bw + dir * len, fy + u.H * 0.07]], sh);
        var lit = u.mix("#3A2A2A", D.warm, 0.5 * f), dark = "#120C10";
        u.ctx.fillStyle = u.lin(bx - bw, 0, bx + bw, 0, dir > 0 ? [lit, dark] : [dark, lit]);
        u.ctx.fillRect(bx - bw, fy - u.H * 0.1, bw * 2, u.H * 0.1);
      }
      u.label("take the walls away and the light still tells the room's shape — by what it reaches", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { fx = x; }
  };
});

rhymeOf("Kiln", "Iron forge", "the same chamber running hotter — blue-white heat, a breath every 1.2 s instead of 3, forty sparks instead of two dozen embers", function make(u) {
  // rhyme of Kiln: dials moved — hot/heat palette to blue-white, period 3.0 → 1.2, embers 24 → 40
  var D = { bg: ["#08090E", "#0C0E14"], brick: "#2A2C34", hot: "#E8F4FF", heat: "#5A9AFF",
            period: 1.2, embers: 40, drift: 1.4 };
  var kx = u.W * 0.5, fy = u.H * 0.75;
  var R = u.rng(5), em = [];
  for (var j = 0; j < D.embers; j++) em.push({ ph: R(), spd: 0.12 + R() * 0.12, dx: (R() - 0.5) * u.W * 0.2, s: 0.6 + R() * 1.2 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.bg);
      u.ground(fy, "#08080C");
      var br = 0.7 + 0.3 * (0.5 + 0.5 * Math.sin(t * u.TAU / D.period)), c = u.ctx;
      c.fillStyle = u.rad(kx, fy - u.H * 0.1, u.W * 0.3, [[0, u.mix(D.brick, D.heat, 0.45 * br)], [1, D.brick]]);
      c.fillRect(kx - u.W * 0.18, fy - u.H * 0.42, u.W * 0.36, u.H * 0.42);
      c.fillStyle = u.rad(kx, fy - u.H * 0.04, u.W * 0.11, [[0, D.hot], [0.5, u.mix(D.heat, "#0A1A3A", 1 - br)], [1, "#040A20"]]);
      c.beginPath(); c.moveTo(kx - u.W * 0.07, fy); c.lineTo(kx - u.W * 0.07, fy - u.H * 0.12);
      c.arc(kx, fy - u.H * 0.12, u.W * 0.07, Math.PI, 0); c.lineTo(kx + u.W * 0.07, fy); c.fill();
      c.save(); c.beginPath(); c.moveTo(kx - u.W * 0.07, fy); c.lineTo(kx + u.W * 0.07, fy);
      c.lineTo(kx + u.W * 0.32, u.H); c.lineTo(kx - u.W * 0.32, u.H); c.clip();
      u.soft(kx, fy, u.H * 0.32, D.heat, 0.6 * br); c.restore();
      c.globalCompositeOperation = "lighter";
      for (var i = 0; i < em.length; i++) {
        var e = em[i], life = (t * e.spd * D.drift + e.ph) % 1;
        u.dot(kx + e.dx * life + Math.sin(t * 2 + e.ph * 9) * 3, fy - u.H * 0.04 - life * u.H * 0.4, e.s, u.rgba(D.hot, (1 - life) * 0.9));
      }
      c.globalCompositeOperation = "source-over";
      u.label("hotter reads as bluer and faster — temperature is a hue dial and a period dial", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { kx = x; }
  };
});

rhymeOf("Lantern", "Sky lanterns", "the same shell five times, cut loose and rising — no strings, gentler sway, and the pools on the ground widening and fading as they climb", function make(u) {
  // rhyme of Lantern: dials moved — count 1 → 5, rise 0 → 1, sway 1.0 → 0.5 (half the breeze), paper colour
  var D = { sky: ["#0A0818", "#1A1030"], paper: "#FFB050", core: "#FFF0C0", ribs: 7,
            sway: 0.5, count: 5, rise: 1,
            swing: 2.2, damp: 0.18, hook: 3, wind: 0.5 };                    // the same pendulum: rate rad/s, damping of critical, the hook's k, the breeze rad/s²
  var px = u.W * 0.5, py = u.H * 0.12, GY = u.H * 0.82;
  var ht = px, hv = 0;
  var nl = Math.max(1, D.count), th = new Float32Array(nl), om = new Float32Array(nl);
  for (var q = 0; q < nl; q++) th[q] = 0.12 * (q % 2 ? -1 : 1);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ground(GY, "#0C0A14");
      var L = u.H * 0.32, g = D.swing * D.swing, cc = D.damp * 2 * D.swing, kh = D.hook, dh = 2 * Math.sqrt(kh);
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, s, i;
      for (s = 0; s < sub; s++) {
        var ah = kh * (ht - px) - dh * hv;
        hv += ah * h; px += hv * h;
        for (i = 0; i < nl; i++) {
          var breeze = D.wind * D.sway * (0.6 * Math.sin(t * 0.9 + i * 2) + 0.4 * Math.sin(t * 1.7 + i));
          om[i] += (-g * Math.sin(th[i]) - cc * om[i] - ah / L * Math.cos(th[i]) + breeze) * h;
          th[i] = u.clamp(th[i] + om[i] * h, -1.2, 1.2);
        }
      }
      var c = u.ctx, rw = u.W * 0.085, rh = u.H * 0.12;
      for (i = 0; i < nl; i++) {
        var ang = th[i];
        var hook = px + (i - (nl - 1) / 2) * u.W * 0.17, lx = hook + Math.sin(ang) * L;
        var ly = py + Math.cos(ang) * L - D.rise * ((t * 0.06 + i * 0.37) % 1) * u.H * 0.5;
        var hk = u.clamp((GY - ly - rh) / (u.H * 0.6), 0, 1);
        c.save(); c.translate(lx, GY); c.scale(1, 0.3);
        u.soft(0, 0, u.W * (0.15 + hk * 0.3), D.paper, 0.55 * (1 - hk)); c.restore();
        if (!D.rise) u.line(hook, py, lx, ly - rh, "rgba(232,229,244,0.35)", 1);
        c.globalCompositeOperation = "lighter";
        u.soft(lx, ly, rw * 3, D.paper, 0.35);
        c.globalCompositeOperation = "source-over";
        c.save(); c.translate(lx, ly); c.scale(1, rh / rw);
        c.fillStyle = u.rad(0, 0, rw, [[0, D.core], [0.45, D.paper], [1, u.shade(D.paper, -0.45)]]);
        c.beginPath(); c.arc(0, 0, rw, 0, u.TAU); c.fill();
        for (var j = 0; j < D.ribs; j++) {
          var xr = -rw + (j + 0.5) * (2 * rw / D.ribs), yr = Math.sqrt(Math.max(0, rw * rw - xr * xr));
          u.line(xr, -yr, xr, yr, "rgba(0,0,0,0.25)", 1);
        }
        c.restore();
        c.fillStyle = "#2A1A14"; c.fillRect(lx - rw * 0.3, ly - rh - 3, rw * 0.6, 4); c.fillRect(lx - rw * 0.3, ly + rh - 1, rw * 0.6, 4);
      }
      u.label("the higher the source, the wider and fainter its pool — height is written on the ground", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { ht = x; }                                     // click = ask the (invisible) hook to go there; the lanterns trail
  };
});

rhymeOf("Moonphases", "Twin moons", "the same terminator on two moons of another world — one rose, one teal, the small one a third of a cycle ahead — and a faster month", function make(u) {
  // rhyme of Moonphases: dials moved — count 1 → 2, moons palette to rose + teal, month 12 → 7
  var D = { sky: ["#0A0410", "#1E0A24"], moons: ["#F0B8C8", "#8AE0D0"], dark: "#120A18", glow: "#F0C8E0",
            size: 0.2, month: 7, count: 2 };
  var phase = null;
  var R = u.rng(12), stars = [];
  for (var j = 0; j < 50; j++) stars.push([R() * u.W, R() * u.H, 0.3 + R() * 1.0]);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      for (var s = 0; s < stars.length; s++) u.dot(stars[s][0], stars[s][1], stars[s][2], u.rgba(u.INK, 0.4 + 0.3 * Math.sin(t * 2 + s)));
      var k0 = phase !== null ? phase : (t / D.month) % 1;
      for (var i = 0; i < D.count; i++) {
        var k = (k0 + i * 0.3) % 1, mx = u.W * (0.5 + (i - (D.count - 1) / 2) * 0.42), my = u.H * 0.45;
        var r = u.W * D.size * (1 - i * 0.35), col = D.moons[i % D.moons.length];
        var f = 0.5 - 0.5 * Math.cos(k * u.TAU);
        var dir = k < 0.5 ? 1 : -1, lx = Math.sin(k * u.TAU);
        u.soft(mx, my, r * 2.6, D.glow, 0.18 * f);
        u.sphere(mx, my, r, col, lx, -0.2, { spec: 0.15 });
        u.dot(mx - dir * (f * 2 * r), my, r * 1.01, D.dark);
        u.dot(mx, my, r, u.rgba(col, 0.08 * (1 - f)));
      }
      u.label("two spheres, one rule: each shadow line is the same offset, just read at a different k", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { phase = x / u.W; }
  };
});

rhymeOf("Neon", "Broken neon", "the same sign dying — cyan, stuttering seven ticks in ten, its halos jittering out of register with the core", function make(u) {
  // rhyme of Neon: dials moved — tube colour to cyan, flicker 0.15 → 0.7, wobble 0 → 1
  var D = { wall: "#101418", tube: "#30E8FF", passes: 4, flicker: 0.7, wobble: 1 };
  var R = u.rng(9), flick = 1, nextAt = 0, ox = 0, oy = 0;
  var pts = [];
  for (var i = 0; i <= 40; i++) pts.push([u.W * (0.2 + 0.6 * i / 40), u.H * 0.45 + Math.sin(i * 0.9) * u.H * 0.1 + Math.sin(i * 0.37) * u.H * 0.05]);
  function trace(c, jx, jy) { c.beginPath(); for (var i = 0; i < pts.length; i++) { if (i === 0) c.moveTo(pts[i][0] + jx, pts[i][1] + jy); else c.lineTo(pts[i][0] + jx, pts[i][1] + jy); } c.stroke(); }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var c = u.ctx;
      c.fillStyle = D.wall; c.fillRect(0, 0, u.W, u.H);
      if (t > nextAt) { flick = R() < D.flicker ? 0.2 + R() * 0.5 : 1; nextAt = t + 0.08 + R() * 0.3; }
      for (var b = 0; b < 6; b++) u.line(0, u.H * 0.14 * b, u.W, u.H * 0.14 * b, "rgba(255,255,255,0.03)", 1);
      u.soft(u.W / 2 + ox, u.H * 0.45 + oy, u.W * 0.6, D.tube, 0.35 * flick);
      u.ground(u.H * 0.85, "#080A0C");
      c.save(); c.translate(u.W / 2 + ox, u.H * 0.85); c.scale(1, 0.25); u.soft(0, 0, u.W * 0.4, D.tube, 0.2 * flick); c.restore();
      c.globalCompositeOperation = "lighter";
      c.lineCap = "round"; c.lineJoin = "round";
      for (var p = D.passes - 1; p >= 0; p--) {
        var jx = ox + D.wobble * (R() - 0.5) * 4, jy = oy + D.wobble * (R() - 0.5) * 4;
        c.lineWidth = 2 + p * p * 3;
        c.strokeStyle = u.rgba(p === 0 ? u.shade(D.tube, 0.6) : D.tube, (p === 0 ? 0.95 : 0.4 / p) * flick);
        trace(c, jx, jy);
      }
      c.globalCompositeOperation = "source-over";
      u.label("jitter each pass a few pixels and the halos slip off the core — 'broken' is a wobble dial", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { ox = x - u.W / 2; oy = y - u.H * 0.45; }
  };
});

rhymeOf("Quasar", "Crab pulsar", "the same core and jets spinning thirteen times faster and beating once every 0.9 s — a lighthouse in cyan and violet", function make(u) {
  // rhyme of Quasar: dials moved — pulse 0 → 0.9, spin 0.15 → 2.0, jet/disc palette to cyan + violet
  var D = { sky: ["#020208", "#0A0618"], core: "#FFFFFF", jet: "#40F0FF", disc: "#9A5AFF",
            spin: 2.0, jetLen: 0.45, pulse: 0.9 };
  var cx = u.W / 2, cy = u.H * 0.48;
  var R = u.rng(17), stars = [];
  for (var j = 0; j < 70; j++) stars.push([R() * u.W, R() * u.H, 0.3 + R() * 0.9]);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      for (var s = 0; s < stars.length; s++) u.dot(stars[s][0], stars[s][1], stars[s][2], u.rgba(u.INK, 0.5));
      var c = u.ctx, amp = D.pulse > 0 ? 0.15 + 0.85 * Math.pow(0.5 + 0.5 * Math.cos(t * u.TAU / D.pulse), 8) : 1;
      c.save(); c.translate(cx, cy); c.rotate(t * D.spin + 0.5);
      c.globalCompositeOperation = "lighter";
      c.save(); c.scale(1, 0.32);
      u.soft(0, 0, u.W * 0.3, D.disc, 0.18);
      for (var i = 0; i < 3; i++) { c.strokeStyle = u.rgba(D.disc, 0.35 - i * 0.1); c.lineWidth = u.W * (0.02 + i * 0.025); c.beginPath(); c.arc(0, 0, u.W * 0.15, 0, u.TAU); c.stroke(); }
      c.restore();
      for (var sgn = -1; sgn <= 1; sgn += 2) {
        c.save(); c.scale(0.28, 1);
        u.soft(0, sgn * u.H * D.jetLen * 0.55, u.H * D.jetLen * 0.6, D.jet, 0.35 * amp);
        u.soft(0, sgn * u.H * D.jetLen * 0.25, u.H * D.jetLen * 0.3, D.jet, 0.45 * amp);
        c.restore();
      }
      u.soft(0, 0, u.W * 0.12, D.jet, 0.5 * amp);
      u.soft(0, 0, u.W * 0.04, D.core, amp);
      c.globalCompositeOperation = "source-over";
      c.restore();
      u.label("a pulse is alpha on a sharpened cosine — the beam is the same glow, seen only when it points at you", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { cx = x; cy = y; }
  };
});

rhymeOf("Rimlight", "Sunset silhouette", "the same backlit figure at dusk — an orange-to-violet sky, a low amber sun, a warm rim, a smaller head", function make(u) {
  // rhyme of Rimlight: dials moved — sky/ground palette to sunset, light + rim to amber, size 0.11 → 0.09
  var D = { sky: ["#3A2A6A", "#F58A5A"], ground: "#1A1020", light: "#FFB060", body: "#1A1020", rim: "#FFC070", size: 0.09 };
  var lx = u.W * 0.72, ly = u.H * 0.3, GY = u.H * 0.8;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ground(GY, D.ground);
      u.soft(lx, ly, u.W * 0.55, D.light, 0.5);
      u.soft(lx, ly, u.W * 0.12, D.light, 0.95);
      var hx = u.W * 0.5, hy = u.H * 0.42, r = u.W * D.size;
      var dx = lx - hx, dy = ly - hy, len = Math.sqrt(dx * dx + dy * dy) || 1; dx /= len; dy /= len;
      u.shadow(hx - dx * u.W * 0.18, GY + 3, r * 1.8, r * 0.4, 0.5);
      var side = dx >= 0 ? 1 : 0, edge = 0.12 * Math.abs(dx) + 0.02;
      u.ctx.fillStyle = u.lin(hx - r * 1.1, 0, hx + r * 1.1, 0, side ? [[0, D.body], [1 - edge, D.body], [1, u.rgba(D.rim, 0.85)]] : [[0, u.rgba(D.rim, 0.85)], [edge, D.body], [1, D.body]]);
      u.ctx.fillRect(hx - r * 1.1, hy + r * 0.9, r * 2.2, GY - hy - r * 0.9);
      u.sphere(hx, hy, r, D.body, dx, dy, { rim: D.rim, spec: 0.05, dark: "#0A0810" });
      u.label("a warm rim against a warm sky: the silhouette reads as evening from the rim's colour alone", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { lx = x; ly = y; }
  };
});

rhymeOf("Ultraviolet", "Bioluminescent bay", "the same dark room underwater — teal and green glows, sixteen of them, bobbing on slow sines; the tube is now the moon on the surface", function make(u) {
  // rhyme of Ultraviolet: dials moved — palette to teal/underwater, shapes 7 → 16, bob 0 → 1, reach 0.55 → 0.7
  var D = { room: "#03101A", tube: "#6AC8FF", tubeCore: "#E8F8FF", glowA: "#20E0FF", glowB: "#40FFB0",
            reach: 0.7, shapes: 16, bob: 1 };
  var tx = u.W * 0.5, ty = u.H * 0.12;
  var R = u.rng(6), sh = [];
  for (var j = 0; j < D.shapes; j++) sh.push({ x: 0.1 + R() * 0.8, y: 0.35 + R() * 0.45, r: 0.015 + R() * 0.03, a: R() < 0.5, ph: R() * 9 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var c = u.ctx, hum = 1 + 0.05 * Math.sin(t * 40);
      c.fillStyle = D.room; c.fillRect(0, 0, u.W, u.H);
      u.soft(tx, ty, u.W * D.reach, D.tube, 0.35 * hum);
      u.ground(u.H * 0.82, "#02080E");
      c.fillStyle = "#061620"; c.fillRect(u.W * 0.1, u.H * 0.6, u.W * 0.25, u.H * 0.22); c.fillRect(u.W * 0.65, u.H * 0.66, u.W * 0.2, u.H * 0.16);
      c.globalCompositeOperation = "lighter";
      for (var i = 0; i < sh.length; i++) {
        var s = sh[i], col = s.a ? D.glowA : D.glowB, a = 0.6 + 0.3 * Math.sin(t * 1.5 + s.ph);
        var x = u.W * s.x + D.bob * Math.sin(t * 0.7 + s.ph) * u.W * 0.03, y = u.H * s.y + D.bob * Math.cos(t * 0.5 + s.ph) * u.H * 0.03;
        u.soft(x, y, u.W * s.r * 2.6, col, 0.35 * a * hum);
        u.dot(x, y, u.W * s.r, u.rgba(col, 0.95));
      }
      c.save(); c.translate(tx, ty); c.scale(1, 0.18); u.soft(0, 0, u.W * 0.32, D.tube, 0.6 * hum); c.restore();
      c.globalCompositeOperation = "source-over";
      c.fillStyle = D.tubeCore; c.fillRect(tx - u.W * 0.28, ty - 2, u.W * 0.56, 4);
      u.label("swap violet for teal and the black light is seawater — the glowing things still make the scene", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { tx = x; ty = y; }
  };
});

rhymeOf("Xenon", "Camera flash", "the same tube fired by hand — no clock, one warm-white flash per press, dying a little slower so the shadows linger", function make(u) {
  // rhyme of Xenon: dials moved — auto true → false, flash colour to warm white, decay 9 → 5
  var D = { room: "#0A0A12", flash: "#FFE8C8", bar: "#FFFFFF", every: 1.5, decay: 5, auto: false };
  var tx = u.W * 0.5, ty = u.H * 0.2, GY = u.H * 0.8, lastFlash = -9, lastT = 0;
  var blocks = [[0.22, 0.05], [0.5, 0.045], [0.76, 0.055]];
  return {
    frame: function (dt, t) {
      lastT = t;
      if (D.auto && t - lastFlash >= D.every) lastFlash = Math.floor(t / D.every) * D.every;
      var p = Math.exp(-Math.max(0, t - lastFlash) * D.decay), c = u.ctx;
      c.fillStyle = D.room; c.fillRect(0, 0, u.W, u.H);
      u.ground(GY, "#07070E");
      u.soft(tx, ty, u.W * 1.1, D.flash, 0.12 + 0.88 * p);
      for (var i = 0; i < blocks.length; i++) {
        var bx = u.W * blocks[i][0], s = u.W * blocks[i][1], dir = (bx - tx) / (u.W * 0.5);
        u.shadow(bx + dir * s * 3 * p, GY + 2, s * 2, s * 0.5, 0.55 * p);
        u.cube(bx, GY, s, u.mix("#2A2A3A", D.flash, 0.1 + 0.7 * p));
      }
      c.globalCompositeOperation = "lighter";
      c.save(); c.translate(tx, ty); c.scale(1, 0.2); u.soft(0, 0, u.W * 0.35, D.flash, 0.3 + 0.7 * p); c.restore();
      c.globalCompositeOperation = "source-over";
      c.fillStyle = u.rgba(D.bar, 0.5 + 0.5 * p); c.fillRect(tx - u.W * 0.2, ty - 2, u.W * 0.4, 4);
      u.label("click to fire: the same pulse, now on your clock — a flash is a light with a very short life", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { tx = x; ty = y; lastFlash = lastT; }
  };
});

warnOf("Xenon", "contains flashing light");   // the strobe (and its Camera-flash rhyme) is opt-in: click to show
/* ============================== VOLUMES NEAR & FAR ==============================
   Smoke, flame, sparkle, fog: things without edges. What makes a puff of
   smoke look NEAR is not one cue but five moving together — bigger, darker
   (or brighter, if it glows), faster, firmer-edged, and less mixed with the
   colour of the air. So every particle here carries one number, z (0 = far,
   1 = near), and everything else is read off it. Sort far → near before
   drawing so the near ones cover the far ones (the painter's order). Volumes
   made of light (flame, sparkle, steam) are drawn with "lighter" so they add
   up hot where they overlap; volumes made of matter (smoke, ash, dust, fog)
   cover instead. The three canonical cards are Plume (smoke), Blaze (flame)
   and Glitter (sparkle) — the other ten are the same rule in other clothes. */

def("A", "Ash", "volume", "flakes falling over a burnt-out night: one z per flake sets size, greyness, speed and a touch of blur — near ones big and fast, far ones tiny and slow; press sets a wind, and the light far flakes take it first, the heavy near ones a second or two later", function make(u) {
  var D = { sky: ["#0A0608", "#2A1410"], glow: "#F58A4A", near: "#E8E4E0", far: "#5A5458",   // flake colour up close / far off
            flakes: 80, fall: 0.35, wind: 0, seed: 31,
            gust: 0.25,              // the sideways speed a full wind asks of a flake, screens per second
            response: 1,             // how quickly the lightest (farthest) flake's drift takes up the wind, per second — a near, heavy flake takes it slower
            flutter: 1 };            // how wide a flake swings on its own as it tumbles (1 = 3 px far … 15 px near)
  var R = u.rng(D.seed), flakes = [];
  for (var j = 0; j < D.flakes; j++) flakes.push({ x: R(), ph: R(), z: R(), vx: 0, s: 0, sv: 0, next: R() * 2 });   // x and vx in screens; s, sv the swing in px
  flakes.sort(function (a, b) { return a.z - b.z; });                    // far first, near last — painter's order
  // the fall is a steady rate (a flake at terminal velocity), but the DRIFT is
  // simulated: each flake carries a sideways velocity that the wind drags toward
  // its own speed — a light far flake takes it up in a quarter of a second, a
  // heavy near one over a second or two — so a press does not turn the whole
  // field on one frame: the gust sweeps through it, back to front. the flutter
  // is a pendulum swing about the flake's path, kicked at random moments as it
  // tumbles and catches the air, under-damped so it swings past and back.
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.soft(u.W * 0.5, u.H * 0.82, u.W * 0.6, D.glow, 0.35);            // something still burning below the rise
      u.ground(u.H * 0.8, "#050305");
      u.ctx.fillStyle = "#050305";
      for (var k = 0; k < 5; k++) u.ctx.fillRect(u.W * (0.08 + k * 0.2), u.H * (0.62 + (k % 2) * 0.08), u.W * 0.07, u.H * 0.2);   // ruined walls
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, want = D.wind * D.gust;   // substeps of ≤ 0.02 s keep the springs stable at any frame rate
      for (var j = 0; j < flakes.length; j++) {
        var f = flakes[j], z = f.z;                                      // z: 0 far … 1 near
        var rate = D.response / (0.25 + z * 1.5);                        // heavier = slower to take the wind
        var ks = 9 / (0.5 + z), w = Math.sqrt(ks), ds = 0.25 * 2 * w;   // the swing: near flakes are wider, slower pendulums, a quarter of critical
        var amp = D.flutter * (3 + z * 12);
        f.next -= dt;
        if (f.next <= 0) { f.next = 0.6 + R() * 1.6; f.sv += (R() < 0.5 ? -1 : 1) * (0.5 + R()) * amp * w; }   // a tumble catches the air: a kick of amp·ω swings it about amp
        for (var s = 0; s < sub; s++) {
          f.vx += (want - f.vx) * rate * h;                              // the wind drags the drift toward its own speed
          f.x += f.vx * h;
          f.sv += (ks * (0 - f.s) - ds * f.sv) * h; f.s = u.clamp(f.s + f.sv * h, -amp * 3, amp * 3);
        }
        f.x -= Math.floor(f.x);                                          // wrap: out one side, in the other
        var p = (t * D.fall * (0.3 + z) + f.ph) % 1;                     // near flakes fall faster
        var y = p * (u.H + 20) - 10;
        var x = f.x * u.W + f.s;
        var c = u.fog(u.mix(D.far, D.near, z), (1 - z) * 0.6, D.sky[1]);  // far flakes take on the glow-lit air
        var r = 0.6 + z * 3.2, a = 0.15 + z * 0.8;
        if (z > 0.6) u.soft(x, y, r * 2.4, c, a * 0.35);                  // the nearest are a touch out of focus
        u.dot(x, y, r, u.rgba(c, a));
      }
      u.label("matter covers: near flakes big, pale, fast, slightly blurred — far ones tiny, dim, slow, fogged, and first to take the wind", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = (x / u.W - 0.5) * 2; }               // click left/right = the wind the drifts will chase
  };
});

def("B", "Blaze", "volume", "flame in three depth planes: back tongues dark red, soft, slow; middle orange; front ones yellow-white, sharp, fast — additive, so overlaps burn hot", function make(u) {
  var D = { sky: ["#0A0508", "#1E0A08"], planes: ["#8A1E10", "#F07A20", "#FFF0A0"],       // far → near
            per: 6, speed: 1, gust: 0, seed: 7 };
  var R = u.rng(D.seed), tongues = [];
  for (var i = 0; i < D.planes.length; i++)                              // plane by plane = already far → near
    for (var j = 0; j < D.per; j++)
      tongues.push({ z: (i + 0.5) / D.planes.length, c: D.planes[i], x: 0.2 + (j + R() * 0.6) / D.per * 0.6, ph: R() * 9, s: 0.7 + R() * 0.6 });
  function tongue(x, y, w, h, lean, c, a) {                               // a teardrop: two curves meeting at the tip
    u.ctx.fillStyle = u.lin(0, y, 0, y - h, [[0, u.rgba(c, a)], [0.6, u.rgba(c, a * 0.8)], [1, u.rgba(c, 0)]]);
    u.ctx.beginPath(); u.ctx.moveTo(x - w / 2, y);
    u.ctx.quadraticCurveTo(x - w / 2 + lean * 0.3, y - h * 0.55, x + lean, y - h);
    u.ctx.quadraticCurveTo(x + w / 2 + lean * 0.3, y - h * 0.55, x + w / 2, y);
    u.ctx.closePath(); u.ctx.fill();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var GY = u.H * 0.82;
      u.ground(GY, "#050305");
      u.ctx.globalCompositeOperation = "lighter";                        // light adds
      u.soft(u.W / 2, GY, u.W * 0.45, D.planes[1], 0.25);                  // the light the fire throws on the ground
      for (var j = 0; j < tongues.length; j++) {
        var g = tongues[j], z = g.z, sp = D.speed * (1.5 + z * 3);         // near planes flicker faster
        var h = u.H * (0.18 + z * 0.3) * g.s * (0.8 + 0.2 * Math.sin(t * sp + g.ph)), w = u.W * (0.05 + z * 0.06);
        var lean = Math.sin(t * sp * 1.3 + g.ph) * w * 0.6 + D.gust * w * 1.5;
        var x = u.W * g.x, y = GY - (1 - z) * u.H * 0.03;                  // far tongues stand a little farther back
        u.soft(x + lean * 0.4, y - h * 0.4, h * 0.5, g.c, 0.12 + (1 - z) * 0.3);   // far = mostly halo
        tongue(x, y, w, h, lean, g.c, 0.3 + z * 0.65);                      // near = mostly crisp shape
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("z picks the plane: back = dark, soft, slow; front = bright, sharp, fast. Light adds, so overlaps burn white", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.gust = (x / u.W - 0.5) * 2; }               // click left/right = a gust leans the flames
  };
});

def("D", "Dustcloud", "volume", "a dust cloud rolling along the ground: each puff is a ball lit from one side (inner point pushed toward the light); near puffs darker, bigger, faster", function make(u) {
  var D = { sky: ["#C8B89A", "#E8D8B8"], dust: "#B08A5A", puffs: 36, roll: 1, lightX: -1, seed: 17 };   // lightX: -1 sun on the left, +1 on the right
  var R = u.rng(D.seed), puffs = [];
  for (var j = 0; j < D.puffs; j++) puffs.push({ x: R(), z: R(), ph: R() * 9 });
  puffs.sort(function (a, b) { return a.z - b.z; });                     // far first
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var GY = u.H * 0.72;
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.shade(D.dust, -0.1), u.shade(D.dust, -0.45)]);
      u.ctx.fillRect(0, GY, u.W, u.H - GY);
      for (var j = 0; j < puffs.length; j++) {
        var q = puffs[j], z = q.z;
        var r = u.W * (0.05 + z * 0.09), span = u.W + r * 2;
        var x = ((q.x * span + t * D.roll * (15 + z * 55)) % span) - r;     // near puffs roll past faster
        var y = GY + z * u.H * 0.12 - r * 0.4 + Math.sin(t * (0.8 + z) + q.ph) * 3;   // near puffs sit lower on the ground plane
        var c = u.fog(u.shade(D.dust, -0.45 * z), (1 - z) * 0.7, D.sky[1]);   // near = darker; far = paler, into the sky
        var a = 0.35 + z * 0.5;
        u.ctx.fillStyle = u.rad(x, y, r, [[0, u.rgba(u.shade(c, 0.4), a)], [0.55, u.rgba(c, a)], [1, u.rgba(u.shade(c, -0.3), 0)]], D.lightX * r * 0.45, -r * 0.25);
        u.ctx.beginPath(); u.ctx.arc(x, y, r, 0, u.TAU); u.ctx.fill();    // a lit edge and a dark edge = a round puff
      }
      u.label("one radial gradient per puff, inner point toward the sun; z sets size, darkness, speed and where it sits", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lightX = (x / u.W - 0.5) * 2; }             // click = move the sun left/right
  };
});

def("F", "Fireflies", "volume", "points of light over a dusk meadow: z sets each one's size, brightness, blink speed and wander — near ones wear a wide halo, far ones are pinpricks", function make(u) {
  var D = { sky: ["#1A1E4A", "#5A3A5A", "#2A3A2A"], glow: "#D8F07A", flies: 40, halo: 1, seed: 23 };
  var R = u.rng(D.seed), flies = [], grass = [];
  for (var j = 0; j < D.flies; j++) flies.push({ x: R(), y: 0.3 + R() * 0.5, z: R(), a: 0.3 + R() * 0.5, b: 0.2 + R() * 0.4, ph: R() * 9 });
  flies.sort(function (a, b) { return a.z - b.z; });                     // far first
  for (var k = 0; k < 30; k++) grass.push([R(), 0.06 + R() * 0.1, R() * 9]);
  return {
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]], [1, D.sky[2]]]);
      var GY = u.H * 0.8;
      u.ground(GY, "#0A140A");
      for (var k = 0; k < grass.length; k++)
        u.line(grass[k][0] * u.W, GY + 1, grass[k][0] * u.W + Math.sin(t * 0.8 + grass[k][2]) * 3, GY - grass[k][1] * u.H, "#0A140A", 1.5);
      u.ctx.globalCompositeOperation = "lighter";
      for (var j = 0; j < flies.length; j++) {
        var f = flies[j], z = f.z, wander = 0.3 + z;                       // near ones wander wider
        var x = f.x * u.W + Math.sin(t * f.a + f.ph) * u.W * 0.08 * wander;
        var y = f.y * u.H + Math.sin(t * f.b * 1.3 + f.ph * 2) * u.H * 0.05 * wander;
        var blink = Math.pow(0.5 + 0.5 * Math.sin(t * (0.8 + z * 3) + f.ph), 3);   // near ones blink faster
        var c = u.fog(D.glow, (1 - z) * 0.7, D.sky[1]);
        var r = 0.6 + z * 2.2;
        u.soft(x, y, r * (3 + z * 8) * D.halo, c, (0.05 + 0.5 * z) * blink);   // the halo is the near one's badge
        u.dot(x, y, r, u.rgba(c, (0.25 + z * 0.75) * blink));
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("a point of light has a depth too: size, brightness, blink rate and halo width all read off z", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { for (var j = 0; j < flies.length; j++) { flies[j].x += (x / u.W - flies[j].x) * 0.4 * flies[j].z; flies[j].y += (y / u.H - flies[j].y) * 0.4 * flies[j].z; } }   // near ones gather most
  };
});

def("G", "Glitter", "volume", "four-point twinkles at many depths drifting up: far ones tiny, dim, slow; near ones big, bright, fast, wrapped in a soft halo — additive, in violet", function make(u) {
  var D = { sky: ["#0A0616", "#1E1030"], star: "#E8C8FF", deep: "#C9A0F5", count: 70, drift: 1, seed: 41 };
  var R = u.rng(D.seed), stars = [];
  for (var j = 0; j < D.count; j++) stars.push({ x: R(), y: R(), z: R(), ph: R() * 9 });
  stars.sort(function (a, b) { return a.z - b.z; });                     // far first
  var burst = null, lastT = 0;
  function star4(x, y, r, c) {                                           // 8 points: long, short, long, short…
    var pts = [];
    for (var k = 0; k < 8; k++) { var ang = k * u.TAU / 8, rr = k % 2 ? r * 0.3 : r; pts.push([x + Math.cos(ang) * rr, y + Math.sin(ang) * rr]); }
    u.poly(pts, c);
  }
  return {
    frame: function (dt, t) {
      lastT = t;
      u.sky(D.sky);
      u.ctx.globalCompositeOperation = "lighter";
      for (var j = 0; j < stars.length; j++) {
        var s = stars[j], z = s.z;
        var tw = 0.5 + 0.5 * Math.sin(t * (1 + z * 4) + s.ph);              // near ones twinkle faster
        var y = (((s.y - t * D.drift * (0.01 + z * 0.05)) % 1) + 1) % 1 * u.H;   // and drift up faster
        var x = s.x * u.W + Math.sin(t * 0.5 + s.ph) * (2 + z * 8);
        var c = u.fog(u.mix(D.deep, D.star, z), (1 - z) * 0.7, D.sky[1]);
        var r = (1 + z * 5) * (0.6 + 0.4 * tw), a = (0.15 + z * 0.85) * (0.4 + 0.6 * tw);
        if (z > 0.5) u.soft(x, y, r * 3, c, 0.35 * z * tw);                 // only the near half get a halo
        star4(x, y, r, u.rgba(c, a));
      }
      if (burst) {
        var age = (t - burst.t) / 1.2;                                     // a ring of twelve, 1.2 s long
        if (age < 1) for (var k = 0; k < 12; k++) {
          var ang = k * u.TAU / 12, d = u.ease(age) * u.W * 0.18;
          star4(burst.x + Math.cos(ang) * d, burst.y + Math.sin(ang) * d, 4 * (1 - age) + 0.5, u.rgba(D.star, 1 - age));
        } else burst = null;
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("size, brightness, twinkle speed and halo all from one z — sorted far to near, added like light", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { burst = { x: x, y: y, t: lastT }; }          // click = a burst of sparkle there
  };
});

def("I", "Incense", "volume", "one thin ribbon of smoke: small soft dots along a sine path that widens, pales and thins with height — dark at the stick, air-coloured at the top", function make(u) {
  var D = { room: ["#1A1418", "#0A080C"], smoke: "#3A3A48", pale: "#C8C8D8", tip: "#FF8A3A", dots: 60, curl: 1 };
  var cx = u.W * 0.5, sy = u.H * 0.78, current = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.room);
      u.line(cx, u.H * 0.96, cx, sy, "#2A1E14", 3);                      // the stick
      u.ctx.fillStyle = "#050305"; u.ctx.fillRect(cx - u.W * 0.08, u.H * 0.94, u.W * 0.16, u.H * 0.03);   // its holder
      for (var i = D.dots - 1; i >= 0; i--) {                             // top (far, pale) first; the stick end covers it
        var k = i / D.dots;                                                // 0 at the tip … 1 high up
        var y = sy - k * u.H * 0.72;
        var x = cx + Math.sin(k * 5 - t * 0.8 * D.curl) * u.W * (0.01 + k * 0.1)
                   + Math.sin(k * 13 - t * 1.7 * D.curl) * u.W * 0.02 * k + current * k * k * u.W * 0.3;
        var r = 1.2 + k * 4 + k * k * 14;                                  // the ribbon widens as it climbs
        var c = u.fog(u.mix(D.smoke, D.pale, k), k * 0.6, D.room[0]);      // pales with height, then into the room's air
        u.soft(x, y, r, c, 0.75 * (1 - k * 0.8));                          // and thins
      }
      u.soft(cx, sy, 9, D.tip, 0.6 * (0.7 + 0.3 * Math.sin(t * 5)));      // the glowing tip
      u.dot(cx, sy, 1.6, "#FFE0A0");
      u.label("height is distance here: darker, thinner and sharper at the stick; paler, wider and fainter as it climbs", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { current = (x / u.W - 0.5) * 2; }              // click left/right = an air current
  };
});

def("J", "Jellyfish", "volume", "three of the same jelly at three depths: a dome is a radial gradient with alpha; the far one is smaller, paler, slower, and its glow dimmer — every bell snaps shut on a kicked spring and glides, its tentacles trailing and whipping after it; press to call them over", function make(u) {
  var D = { sea: ["#0A2A50", "#041428"], bell: "#A8C8F0", core: "#7AF0E0", bells: 3, pulse: 1, seed: 5,
            snap: 60,                // the bell's spring: how hard it springs back open after a contraction
            relax: 0.5,              // its damping as a fraction of critical — under 1, so it flares a touch past open before it settles
            contract: 0.1,           // how much of the radius a full contraction takes in
            thrust: 0.12,            // the swim each contraction buys, screens per second, toward where the jelly is headed
            drag: 1.6,               // the water's drag on the glide, per second
            sink: 0.02,              // how fast a jelly sinks between pulses, screens per second per second
            arms: 90,                // a tentacle segment's spring toward hanging straight under the one above
            armdamp: 0.3 };          // its damping as a fraction of critical — low, so the tentacles overshoot and whip
  var R = u.rng(D.seed), jellies = [], ARMS = 5, SEGS = 8;
  for (var j = 0; j < D.bells; j++) {                                      // built far → near
    var z = (j + 0.5) / D.bells;
    var J = { x: 0.15 + R() * 0.7, y: 0.25 + R() * 0.35, z: z, vx: 0, vy: 0, c: 0, cv: 0, clk: R() * 4 };   // position and glide in screens; c the contraction (0 open … 1 shut); clk the pulse clock
    J.hx = J.x; J.hy = J.y;                                                // home: where it keeps swimming back to
    J.r0 = u.W * (0.05 + z * 0.09);                                        // the open radius; a contraction takes it in from here
    J.px = new Float32Array(ARMS * SEGS); J.py = new Float32Array(ARMS * SEGS);     // tentacle segments in px, arm-major [k * SEGS + s]
    J.tvx = new Float32Array(ARMS * SEGS); J.tvy = new Float32Array(ARMS * SEGS);   // and their velocities
    for (var k = 0; k < ARMS; k++) for (var s = 0; s < SEGS; s++) {         // hanging straight down to begin with
      J.px[k * SEGS + s] = J.x * u.W - J.r0 * 0.7 + k * J.r0 * 0.35; J.py[k * SEGS + s] = J.y * u.H + (s + 1) * J.r0 * 0.35;
    }
    jellies.push(J);
  }
  // a jellyfish moves by pulsing. the bell is a spring around OPEN: every
  // period (2π/sp seconds, the old sine's beat) it takes a kick that snaps it
  // shut, and the spring relaxes it open again, flaring a touch past open
  // because the damping is under critical. the same kick is the swim: a shove
  // toward home (give or take a random heading, so they wander) and a little
  // lift, dying in the water's drag, while between pulses the jelly sinks.
  // each tentacle is a chain of eight points, every one a spring toward the
  // spot straight under the point above it, lightly damped — so when the rim
  // pulls in and the bell jerks up, the arms lag, trail, and whip through
  // after it. nothing here is a sine: the rhythm is a clock and everything
  // that moves is integrated.
  return {
    frame: function (dt, t) {
      u.sky(D.sea);
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;             // substeps of ≤ 0.02 s: the arm springs need √k·h small
      var bd = D.relax * 2 * Math.sqrt(D.snap), ad = D.armdamp * 2 * Math.sqrt(D.arms);   // dampings from their fractions of critical
      for (var j = 0; j < jellies.length; j++) {
        var J = jellies[j], z = J.z, sp = D.pulse * (0.6 + z * 1.2), per = u.TAU / sp;   // near ones pulse faster
        var seg = J.r0 * 0.35;
        for (var s = 0; s < sub; s++) {
          J.clk += h;
          if (J.clk >= per) {                                              // the bell fires
            J.clk -= per;
            J.cv += 2 * Math.sqrt(D.snap);                                 // a kick of 2ω shuts it about all the way
            var dx = J.hx - J.x, dy = J.hy - J.y, dist = Math.sqrt(dx * dx + dy * dy);
            var ang = dist < 0.03 ? R() * u.TAU : Math.atan2(dy, dx) + (R() - 0.5) * 1.2;   // headed home, roughly; at home, any way
            var go = D.thrust * (0.6 + z * 0.8);                            // the near one swims further per pulse
            J.vx += Math.cos(ang) * go; J.vy += Math.sin(ang) * go - D.thrust * 0.6;   // and every pulse lifts it a little
          }
          J.cv += (D.snap * (0 - J.c) - bd * J.cv) * h; J.c = u.clamp(J.c + J.cv * h, -0.5, 1.5);   // the bell: a spring around open
          J.vy += D.sink * h;                                              // between pulses it sinks
          J.vx -= J.vx * D.drag * h; J.vy -= J.vy * D.drag * h;            // the glide dies in the water
          J.x += J.vx * h; J.y += J.vy * h;
          if (J.x < 0.04) { J.x = 0.04; J.vx = 0; } else if (J.x > 0.96) { J.x = 0.96; J.vx = 0; }   // the tank has walls
          if (J.y < 0.08) { J.y = 0.08; J.vy = 0; } else if (J.y > 0.85) { J.y = 0.85; J.vy = 0; }
          var r = J.r0 * (1 - D.contract * J.c), bx = J.x * u.W, by = J.y * u.H;
          for (var k = 0; k < ARMS; k++) {                                 // the tentacles: each point chases the spot under the one above
            var ax = bx - r * 0.7 + k * r * 0.35, ay = by;                 // the anchor on the rim — it moves in as the bell shuts
            for (var q = 0; q < SEGS; q++) {
              var i = k * SEGS + q;
              J.tvx[i] += (D.arms * (ax - J.px[i]) - ad * J.tvx[i]) * h;
              J.tvy[i] += (D.arms * (ay + seg - J.py[i]) - ad * J.tvy[i]) * h;
              J.px[i] += J.tvx[i] * h; J.py[i] += J.tvy[i] * h;
              ax = J.px[i]; ay = J.py[i];
            }
          }
        }
        var pulse = u.clamp(J.c, 0, 1), rr = J.r0 * (1 - D.contract * J.c);
        var x = J.x * u.W, y = J.y * u.H;
        var c = u.fog(D.bell, (1 - z) * 0.75, D.sea[0]), a = 0.25 + z * 0.45;   // far = mostly water-coloured
        u.ctx.strokeStyle = u.rgba(c, a * 0.6); u.ctx.lineWidth = 0.6 + z * 1.2;
        for (var k = 0; k < ARMS; k++) {                                   // tentacles: the chains, drawn from the rim down
          u.ctx.beginPath(); u.ctx.moveTo(x - rr * 0.7 + k * rr * 0.35, y);
          for (var q = 0; q < SEGS; q++) u.ctx.lineTo(J.px[k * SEGS + q], J.py[k * SEGS + q]);
          u.ctx.stroke();
        }
        u.ctx.fillStyle = u.rad(x, y, rr, [[0, u.rgba(u.shade(c, 0.5), a)], [0.7, u.rgba(c, a * 0.8)], [1, u.rgba(c, a * 0.2)]], -rr * 0.3, -rr * 0.4);
        u.ctx.beginPath(); u.ctx.arc(x, y, rr, Math.PI, 0); u.ctx.quadraticCurveTo(x, y + rr * 0.35, x - rr, y); u.ctx.fill();   // the dome
        u.ctx.globalCompositeOperation = "lighter";
        u.soft(x, y - rr * 0.2, rr * 0.7, D.core, (0.15 + z * 0.5) * (0.6 + 0.4 * pulse));   // the bioluminescent core adds, brightest shut
        u.ctx.globalCompositeOperation = "source-over";
      }
      u.label("one jelly, three z: size, alpha, water-colour, pulse rate and glow all follow — a kicked spring for the bell, chains for the arms", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { for (var j = 0; j < jellies.length; j++) { jellies[j].hx += (x / u.W - jellies[j].hx) * 0.5 * jellies[j].z; jellies[j].hy += (y / u.H - jellies[j].hy) * 0.5 * jellies[j].z; } }   // moves their homes — the near one's most — and they swim over in a few pulses
  };
});

def("M", "Motes", "volume", "dust in a light shaft: the shaft is one gradient with alpha, a mote is bright only inside it — near motes large and lazy, far ones tiny; with the bounce dial up they hop under real gravity, land with a bounce, and lie still a moment before the next kick", function make(u) {
  var D = { room: ["#141018", "#0A080C"], light: "#FFE8B0", motes: 60, shaftX: 0.35, bounce: 0, seed: 29,   // bounce: 0 float, 1 snow-globe hop (the height of a fresh hop, in units of 8% of H, scaled by depth)
            gravity: 2.5,            // the pull on a hopping mote, screen heights per second per second
            rebound: 0.5,            // how much of its speed a mote keeps when it lands — each bounce a quarter the height of the last
            rest: 0.5 };             // the longest a landed mote lies still before its next kick, seconds
  var R = u.rng(D.seed), motes = [];
  for (var j = 0; j < D.motes; j++) motes.push({ x: R(), y: R(), z: R(), ph: R() * 9, a: 0, av: 0, wait: R() });   // a: the hop's altitude above the mote's drift line, px; av its speed; wait the pause before a kick
  motes.sort(function (a, b) { return a.z - b.z; });                     // far first
  // the drift is the old slow wander; the HOP is simulated. each mote has an
  // altitude above its own drift line and a vertical speed: gravity pulls the
  // speed down, the speed moves the altitude, and the drift line is a floor —
  // land, keep `rebound` of the speed, go up again a quarter as high, and when
  // the next bounce would be under half a pixel, lie still. a resting mote gets
  // a random kick after a random pause (the globe being shaken), sized so a
  // near mote's hop is taller than a far one's. at bounce 0 there are no kicks
  // and the motes float exactly as before.
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.room);
      var x0 = u.W * D.shaftX, slope = u.W * 0.3, hw = u.W * 0.13;        // the shaft leans right as it falls
      u.ctx.globalCompositeOperation = "lighter";
      u.ctx.save(); u.ctx.transform(1, 0, slope / u.H, 1, 0, 0);           // a skew: x slides right as y goes down
      u.ctx.fillStyle = u.lin(x0 - hw, 0, x0 + hw, 0, [[0, u.rgba(D.light, 0)], [0.5, u.rgba(D.light, 0.22)], [1, u.rgba(D.light, 0)]]);
      u.ctx.fillRect(x0 - hw, 0, hw * 2, u.H);
      u.ctx.restore();
      var g = D.gravity * u.H, sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;   // substeps of ≤ 0.02 s so a coarse frame cannot tunnel through the floor
      for (var j = 0; j < motes.length; j++) {
        var m = motes[j], z = m.z, slow = 1.4 - z;                          // near motes drift slower (they are heavier, lazier)
        var top = D.bounce * (0.3 + z) * u.H * 0.08;                        // how high a fresh hop reaches: near motes higher
        for (var s = 0; s < sub; s++) {
          if (m.a > 0 || m.av > 0) {                                        // in the air: gravity, then the floor
            m.av -= g * h; m.a += m.av * h;
            if (m.a <= 0) {
              m.a = 0; m.av = -m.av * D.rebound;                            // land: a bounce with part of the speed
              if (m.av * m.av < 2 * g * 0.5) { m.av = 0; m.wait = R() * D.rest; }   // too small to see — lie still
            }
          } else if (top > 0) {                                             // at rest: the pause, then a kick
            m.wait -= h;
            if (m.wait <= 0) m.av = Math.sqrt(2 * g * top) * (0.7 + 0.6 * R());   // √(2·g·top) reaches top; a little random so they scatter
          }
        }
        var x = ((m.x + t * 0.012 * slow) % 1) * u.W + Math.sin(t * 0.4 + m.ph) * (3 + z * 6);
        var y = ((m.y + t * 0.008 * slow) % 1) * u.H - m.a;                  // the hop lifts the mote off its drift line
        var tumble = 0.6 + 0.4 * Math.sin(t * (1 + z * 2) + m.ph);          // a turning speck catches light on and off
        var inside = Math.abs(x - (x0 + slope * y / u.H)) < hw;
        var bright = inside ? 1 : 0.15;                                    // outside the shaft a mote is barely there
        var r = 0.5 + z * 2.2, a = (0.2 + z * 0.8) * bright * tumble;
        var c = u.mix(D.room[0], D.light, 0.3 + z * 0.7);
        if (inside && z > 0.6) u.soft(x, y, r * 3, D.light, 0.25 * z * tumble);
        u.dot(x, y, r, u.rgba(c, a));
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("the light is a gradient with alpha; a mote is bright where the light is and big only when it is near", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.shaftX = x / u.W - 0.3 * (y / u.H); }      // click = the shaft passes through here
  };
});

def("P", "Plume", "volume", "a smoke column of soft puffs: one z per puff sets size, darkness, speed and edge — near puffs big, dark, firm, fast; far ones small, pale, slow, soft", function make(u) {
  var D = { sky: ["#2A2F4A", "#6A7498", "#9AA0B8"], smoke: "#3A3A44", lit: "#9AA0B8", litY: -1,   // lit: the light on each puff; litY -1 from above, +1 from below
            puffs: 40, rise: 0.35, wind: 0, seed: 3 };
  var R = u.rng(D.seed), puffs = [];
  for (var j = 0; j < D.puffs; j++) puffs.push({ z: R(), ph: R(), sw: R() * 9, side: R() * 2 - 1 });
  puffs.sort(function (a, b) { return a.z - b.z; });                     // far first, near last — painter's order
  function puff(x, y, r, c, a, hard) {                                   // hard: where the falloff starts — 0 = all soft, 0.5 = a firm core
    u.ctx.fillStyle = u.rad(x, y, r, [[0, u.rgba(u.mix(c, D.lit, 0.35), a)], [hard, u.rgba(c, a * 0.9)], [1, u.rgba(c, 0)]], 0, D.litY * r * 0.35);
    u.ctx.beginPath(); u.ctx.arc(x, y, r, 0, u.TAU); u.ctx.fill();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]], [1, D.sky[2]]]);
      var GY = u.H * 0.86, cx = u.W * 0.42, top = GY - u.H * 0.2;
      u.ground(GY, "#0E0B1A");
      u.ctx.fillStyle = "#0E0B1A"; u.ctx.fillRect(cx - u.W * 0.04, top, u.W * 0.08, u.H * 0.2);   // the stack
      for (var j = 0; j < puffs.length; j++) {
        var q = puffs[j], z = q.z;                                       // z: 0 far … 1 near
        var p = (t * D.rise * (0.5 + z) + q.ph) % 1;                     // near puffs rise faster
        var y = top - p * u.H * 0.8;
        var x = cx + D.wind * p * p * u.W * 0.35 + q.side * p * u.W * 0.08 * (0.5 + z) + Math.sin(q.sw + p * 5 + t * 0.3) * (3 + z * 8);
        var r = u.W * (0.02 + z * 0.06) * (0.4 + p * 1.4);               // puffs swell as they rise
        var a = (0.15 + z * 0.55) * (1 - p) * Math.min(1, p * 5 + 0.2);  // and fade away
        var c = u.fog(D.smoke, (1 - z) * 0.7 + p * 0.25, D.sky[1]);      // far smoke is the colour of the sky it is in front of
        puff(x, y, r, c, a, 0.05 + z * 0.45);                            // near = a firmer core
      }
      u.label("one z per puff drives size × darkness × speed × edge together; sort far to near so near covers far", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = (x / u.W - 0.5) * 2; }               // click left/right = wind direction
  };
});

def("S", "Steam", "volume", "pale soft volumes rising off a cup, added onto a dark room: near wisps bigger, brighter, faster, firmer; far ones fade into the room; all curl upward", function make(u) {
  var D = { room: ["#0E0C14", "#1E1A22"], steam: "#DCE8F5", cup: "#2A2430", wisps: 34, rise: 0.4, gain: 1, curl: 1, wind: 0, seed: 13 };   // gain: how hard the steam adds
  var R = u.rng(D.seed), wisps = [];
  for (var j = 0; j < D.wisps; j++) wisps.push({ z: R(), ph: R(), sw: R() * 9, side: R() * 2 - 1 });
  wisps.sort(function (a, b) { return a.z - b.z; });                     // far first
  function puff(x, y, r, c, a, hard) {
    u.ctx.fillStyle = u.rad(x, y, r, [[0, u.rgba(c, a)], [hard, u.rgba(c, a * 0.85)], [1, u.rgba(c, 0)]]);
    u.ctx.beginPath(); u.ctx.arc(x, y, r, 0, u.TAU); u.ctx.fill();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.room);
      var cx = u.W * 0.5, top = u.H * 0.62;
      u.cyl(cx, u.H * 0.9, u.W * 0.22, u.H * 0.28, D.cup, -0.4);          // the cup is a cylinder
      u.ctx.fillStyle = u.shade(D.cup, 0.25);
      u.ctx.beginPath(); u.ctx.ellipse(cx, top, u.W * 0.11, u.H * 0.025, 0, 0, u.TAU); u.ctx.fill();   // its rim
      u.ctx.globalCompositeOperation = "lighter";                        // steam is light on dark: it adds
      for (var j = 0; j < wisps.length; j++) {
        var w = wisps[j], z = w.z;
        var p = (t * D.rise * (0.5 + z) + w.ph) % 1;                     // near wisps rise faster
        var y = top - p * u.H * 0.55;
        var x = cx + w.side * u.W * 0.06 * (0.4 + z * 0.6) + Math.sin(p * 4 * D.curl + w.sw + t * 0.4) * u.W * (0.02 + p * 0.08) + D.wind * p * p * u.W * 0.3;   // x sways more the higher it gets
        var r = u.W * (0.02 + z * 0.05) * (0.5 + p * 1.2);
        var a = (0.08 + z * 0.35) * D.gain * (1 - p) * Math.min(1, p * 6 + 0.15);
        var c = u.mix(D.room[1], D.steam, 0.3 + z * 0.7);                // far wisps are already halfway to the room's colour
        puff(x, y, r, c, a, 0.05 + z * 0.35);
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("light adds: near wisps bigger, brighter, faster, firmer-edged — far ones melt into the room's dark", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = (x / u.W - 0.5) * 2; }               // click left/right = a draught
  };
});

def("V", "Vapour", "volume", "ground fog in four depth bands — far band pale, thin, slow; near band darker, thick, fast — and tree silhouettes paler the more fog stands before them", function make(u) {
  var D = { sky: ["#3A4A6A", "#8A98B0", "#B8C0CC"], fog: "#C8CCD8", tree: "#0A1210", bands: 4, per: 12, drift: 1, seed: 19 };
  var R = u.rng(D.seed), blobs = [], trees = [];
  for (var i = 0; i < D.bands; i++) for (var j = 0; j < D.per; j++) blobs.push({ band: i, x: R(), ph: R() * 9 });
  for (var k = 0; k < 9; k++) trees.push({ x: R(), d: R() });               // d: 0 far … 1 near
  trees.sort(function (a, b) { return a.d - b.d; });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.5, D.sky[1]], [1, D.sky[2]]]);
      var hor = u.H * 0.45, ti = 0;
      u.ground(hor, u.mix(D.tree, D.sky[2], 0.5));
      for (var i = 0; i < D.bands; i++) {
        var d = i / (D.bands - 1), by = hor + Math.pow(d, 1.5) * u.H * 0.45 + u.H * 0.03;   // band 0 hugs the horizon
        while (ti < trees.length && trees[ti].d <= (i + 1) / D.bands) {   // trees standing in this slice go in BEFORE its fog
          var tr = trees[ti++], td = tr.d, ty = hor + Math.pow(td, 1.5) * u.H * 0.45 + u.H * 0.03, h = u.H * (0.08 + td * 0.3), tx = tr.x * u.W;
          var tc = u.fog(D.tree, (1 - td) * 0.85, D.sky[1]);              // the fog between you and the tree pales it
          u.poly([[tx - h * 0.18, ty], [tx, ty - h], [tx + h * 0.18, ty]], tc);
          u.ctx.fillStyle = tc; u.ctx.fillRect(tx - h * 0.03, ty - 1, h * 0.06, h * 0.12);
        }
        var r = u.W * (0.08 + d * 0.1), span = u.W + r * 2;
        var c = u.shade(u.mix(D.fog, D.sky[1], (1 - d) * 0.6), -0.25 * d);   // far band pale toward the sky, near band darker
        for (var j = 0; j < blobs.length; j++) {
          var b = blobs[j]; if (b.band !== i) continue;
          var x = ((((b.x * span + t * D.drift * (4 + d * 28)) % span) + span) % span) - r;   // near bands drift faster
          u.ctx.save(); u.ctx.translate(x, by + Math.sin(t * 0.3 + b.ph) * 3); u.ctx.scale(1, 0.4);   // flattened blobs
          u.soft(0, 0, r, c, 0.2 + d * 0.4);                                // far thin, near thick
          u.ctx.restore();
        }
      }
      u.label("fog is layers: each band paler, thinner and slower the farther back — and it pales whatever stands behind it", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.drift = (x / u.W - 0.5) * 4; }              // click left/right = which way the fog drifts
  };
});

def("W", "Wildfire", "volume", "a field of small flames in perspective rows: rows shrink and bunch toward the horizon (horizon + p²); size, brightness and flicker come from the row", function make(u) {
  var D = { sky: ["#0A0406", "#3A0E0A"], far: "#8A1E10", near: "#FFE08A", rows: 7, dense: 12, flicker: 1, smoke: 10, wind: 0, seed: 37 };   // dense: flames in the farthest row
  var R = u.rng(D.seed), flames = [], smokes = [];
  for (var i = 0; i < D.rows; i++) {                                     // row by row = far → near
    var p = i / (D.rows - 1), n = Math.max(1, Math.round(D.dense - p * D.dense * 0.5));   // far rows hold more, smaller flames
    for (var j = 0; j < n; j++) flames.push({ p: p, x: (j + 0.2 + R() * 0.6) / n, ph: R() * 9, s: 0.7 + R() * 0.6 });
  }
  for (var k = 0; k < D.smoke; k++) smokes.push({ x: R(), ph: R(), z: R() });
  function tongue(x, y, w, h, lean, c, a) {
    u.ctx.fillStyle = u.lin(0, y, 0, y - h, [[0, u.rgba(c, a)], [0.6, u.rgba(c, a * 0.8)], [1, u.rgba(c, 0)]]);
    u.ctx.beginPath(); u.ctx.moveTo(x - w / 2, y);
    u.ctx.quadraticCurveTo(x - w / 2 + lean * 0.3, y - h * 0.55, x + lean, y - h);
    u.ctx.quadraticCurveTo(x + w / 2 + lean * 0.3, y - h * 0.55, x + w / 2, y);
    u.ctx.closePath(); u.ctx.fill();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var hor = u.H * 0.42;
      u.ctx.fillStyle = u.lin(0, hor, 0, u.H, ["#2A0C08", "#0A0406"]); u.ctx.fillRect(0, hor, u.W, u.H - hor);
      for (var k = 0; k < smokes.length; k++) {                           // smoke is matter: it covers, so it goes first
        var s = smokes[k], q = (t * 0.08 * (0.5 + s.z) + s.ph) % 1;
        u.soft(((s.x + D.wind * q * 0.3 + 10) % 1) * u.W, hor - q * hor * 0.9, u.W * (0.05 + s.z * 0.08) * (0.5 + q), u.mix("#3A2A28", D.sky[1], 0.5), (0.1 + s.z * 0.25) * (1 - q));
      }
      u.ctx.globalCompositeOperation = "lighter";
      u.soft(u.W / 2, hor, u.W * 0.6, D.far, 0.3);                          // the glow on the horizon
      for (var j = 0; j < flames.length; j++) {
        var f = flames[j], p = f.p, scale = 0.12 + p * 0.88, sp = (3 + p * 4) * D.flicker;   // near rows flicker faster
        var y = hor + p * p * u.H * 0.55 + 2, x = f.x * u.W;
        var h = u.H * 0.17 * scale * f.s * (0.8 + 0.2 * Math.sin(t * sp + f.ph)), w = u.W * 0.045 * scale + 1;
        var lean = Math.sin(t * sp * 1.3 + f.ph) * w * 0.5 + D.wind * w * 1.2;
        var c = u.mix(D.far, D.near, p);                                    // far rows dark red, near rows yellow-white
        if (p > 0.5) u.soft(x, y - h * 0.3, h * 0.6, c, 0.15 * p);
        tongue(x, y, w, h, lean, c, 0.3 + p * 0.7);
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("rows at horizon + p² shrink and bunch; z here is the row — size, colour, alpha and flicker all follow it", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = (x / u.W - 0.5) * 2; }               // click left/right = wind leans every flame
  };
});

def("Y", "Yule", "volume", "a log fire: dark tongues far back, bright tongues just behind the logs, embers on the near wood — logs are turned cylinders; overlap does the depth", function make(u) {
  var D = { room: ["#1A0E0A", "#3A1A10"], hearth: "#141010", planes: ["#8A1E10", "#F0A030"], log: "#4A2E1A", ember: "#FF9A3A",
            per: 5, flame: 1, embers: 10, seed: 43 };                     // flame: height of the tongues; embers: how many coals glow
  var R = u.rng(D.seed), tongues = [], embers = [];
  for (var i = 0; i < D.planes.length; i++)                              // far plane first
    for (var j = 0; j < D.per; j++) tongues.push({ z: (i + 0.5) / D.planes.length, c: D.planes[i], x: 0.32 + (j + R() * 0.6) / D.per * 0.36, ph: R() * 9, s: 0.7 + R() * 0.6 });
  for (var k = 0; k < D.embers; k++) embers.push({ x: R(), ph: R() * 9, front: k % 2 });
  var flare = 0;
  function tongue(x, y, w, h, lean, c, a) {
    u.ctx.fillStyle = u.lin(0, y, 0, y - h, [[0, u.rgba(c, a)], [0.6, u.rgba(c, a * 0.8)], [1, u.rgba(c, 0)]]);
    u.ctx.beginPath(); u.ctx.moveTo(x - w / 2, y);
    u.ctx.quadraticCurveTo(x - w / 2 + lean * 0.3, y - h * 0.55, x + lean, y - h);
    u.ctx.quadraticCurveTo(x + w / 2 + lean * 0.3, y - h * 0.55, x + w / 2, y);
    u.ctx.closePath(); u.ctx.fill();
  }
  function log(x, y, len, thick, tilt) {                                 // a cylinder turned on its side
    u.ctx.save(); u.ctx.translate(x, y); u.ctx.rotate(Math.PI / 2 + tilt);
    u.cyl(0, len / 2, thick, len, D.log, -0.3);
    u.ctx.restore();
  }
  return {
    frame: function (dt, t) {
      var fl = 0.85 + 0.15 * Math.sin(t * 7.3) * Math.sin(t * 3.1) + flare * 0.4;   // the fire's breathing lights the room
      flare *= 0.96;
      u.sky([u.mix(D.room[0], D.room[1], fl * 0.5), u.mix(D.room[1], "#8A4A20", fl * 0.4)]);
      var GY = u.H * 0.84;
      u.ctx.fillStyle = D.hearth; u.ctx.fillRect(u.W * 0.2, u.H * 0.3, u.W * 0.6, GY - u.H * 0.3);   // the hearth's dark back
      u.ground(GY, "#1E1410");
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [[0, u.rgba(D.ember, 0.35 * fl)], [1, u.rgba(D.ember, 0)]]); u.ctx.fillRect(0, GY, u.W, u.H - GY);   // firelight on the floor
      u.ctx.globalCompositeOperation = "lighter";
      for (var j = 0; j < tongues.length; j++) {                          // flame BEHIND the logs, dark plane first
        var g = tongues[j], z = g.z, sp = 1.5 + z * 3;
        var h = u.H * (0.14 + z * 0.14) * g.s * D.flame * (0.8 + 0.2 * Math.sin(t * sp + g.ph)) * (1 + flare * 0.5), w = u.W * (0.04 + z * 0.04);
        var lean = Math.sin(t * sp * 1.3 + g.ph) * w * 0.5, x = u.W * g.x, y = GY - u.H * 0.06 - (1 - z) * u.H * 0.04;
        u.soft(x, y - h * 0.4, h * 0.5, g.c, 0.1 + (1 - z) * 0.3);
        tongue(x, y, w, h, lean, g.c, 0.3 + z * 0.65);
      }
      u.ctx.globalCompositeOperation = "source-over";
      log(u.W * 0.5, GY - u.H * 0.075, u.W * 0.4, u.H * 0.06, 0.15);     // the back log, tilted up to the right
      log(u.W * 0.5, GY - u.H * 0.045, u.W * 0.44, u.H * 0.07, -0.1);    // the front log covers it
      u.ctx.globalCompositeOperation = "lighter";
      for (var k = 0; k < embers.length; k++) {                           // embers ride the top of the logs
        var e = embers[k], ex = u.W * (0.3 + e.x * 0.4);
        var ey = e.front ? GY - u.H * 0.045 - (ex - u.W / 2) * 0.1 - u.H * 0.02 : GY - u.H * 0.075 + (ex - u.W / 2) * 0.15 - u.H * 0.02;
        var glow = 0.5 + 0.5 * Math.sin(t * (2 + e.ph * 0.3) + e.ph);
        u.soft(ex, ey, 3 + glow * 3 + flare * 4, D.ember, 0.25 + 0.5 * glow);
        u.dot(ex, ey, 1, "#FFE0A0");
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("overlap is depth order: dark flame far back, bright flame nearer, then the logs, then the embers on them", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { flare = 1; }                                 // click = poke the fire
  };
});

/* ---- the rhymes: same pictures, two or three dials moved ---- */

rhymeOf("Ash", "Snowfall", "the same falling flakes in white over a blue night, half the speed — the ash code IS the snow code", function make(u) {
  // rhyme of Ash: dials moved — sky/glow/near/far palette to a cold night, fall 0.35 → 0.18
  var D = { sky: ["#060A1E", "#1A2A50"], glow: "#8AA0D8", near: "#FFFFFF", far: "#8A98B8",
            flakes: 80, fall: 0.18, wind: 0, seed: 31,
            gust: 0.25, response: 1, flutter: 1 };
  var R = u.rng(D.seed), flakes = [];
  for (var j = 0; j < D.flakes; j++) flakes.push({ x: R(), ph: R(), z: R(), vx: 0, s: 0, sv: 0, next: R() * 2 });
  flakes.sort(function (a, b) { return a.z - b.z; });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.soft(u.W * 0.5, u.H * 0.82, u.W * 0.6, D.glow, 0.35);
      u.ground(u.H * 0.8, "#050305");
      u.ctx.fillStyle = "#050305";
      for (var k = 0; k < 5; k++) u.ctx.fillRect(u.W * (0.08 + k * 0.2), u.H * (0.62 + (k % 2) * 0.08), u.W * 0.07, u.H * 0.2);
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, want = D.wind * D.gust;
      for (var j = 0; j < flakes.length; j++) {
        var f = flakes[j], z = f.z;
        var rate = D.response / (0.25 + z * 1.5);
        var ks = 9 / (0.5 + z), w = Math.sqrt(ks), ds = 0.25 * 2 * w;
        var amp = D.flutter * (3 + z * 12);
        f.next -= dt;
        if (f.next <= 0) { f.next = 0.6 + R() * 1.6; f.sv += (R() < 0.5 ? -1 : 1) * (0.5 + R()) * amp * w; }
        for (var s = 0; s < sub; s++) {
          f.vx += (want - f.vx) * rate * h;
          f.x += f.vx * h;
          f.sv += (ks * (0 - f.s) - ds * f.sv) * h; f.s = u.clamp(f.s + f.sv * h, -amp * 3, amp * 3);
        }
        f.x -= Math.floor(f.x);
        var p = (t * D.fall * (0.3 + z) + f.ph) % 1;
        var y = p * (u.H + 20) - 10;
        var x = f.x * u.W + f.s;
        var c = u.fog(u.mix(D.far, D.near, z), (1 - z) * 0.6, D.sky[1]);
        var r = 0.6 + z * 3.2, a = 0.15 + z * 0.8;
        if (z > 0.6) u.soft(x, y, r * 2.4, c, a * 0.35);
        u.dot(x, y, r, u.rgba(c, a));
      }
      u.label("change four colours and one speed: the ruin becomes a village and the ash becomes snow", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Blaze", "Spirit fire", "the same three planes of flame in blue-green, burning at half speed — a ghost's hearth", function make(u) {
  // rhyme of Blaze: dials moved — planes palette to blue-green, speed 1 → 0.5, sky to a cold dark
  var D = { sky: ["#040A10", "#081A20"], planes: ["#0A3A5A", "#20B0A0", "#C8FFF0"],
            per: 6, speed: 0.5, gust: 0, seed: 7 };
  var R = u.rng(D.seed), tongues = [];
  for (var i = 0; i < D.planes.length; i++)
    for (var j = 0; j < D.per; j++)
      tongues.push({ z: (i + 0.5) / D.planes.length, c: D.planes[i], x: 0.2 + (j + R() * 0.6) / D.per * 0.6, ph: R() * 9, s: 0.7 + R() * 0.6 });
  function tongue(x, y, w, h, lean, c, a) {
    u.ctx.fillStyle = u.lin(0, y, 0, y - h, [[0, u.rgba(c, a)], [0.6, u.rgba(c, a * 0.8)], [1, u.rgba(c, 0)]]);
    u.ctx.beginPath(); u.ctx.moveTo(x - w / 2, y);
    u.ctx.quadraticCurveTo(x - w / 2 + lean * 0.3, y - h * 0.55, x + lean, y - h);
    u.ctx.quadraticCurveTo(x + w / 2 + lean * 0.3, y - h * 0.55, x + w / 2, y);
    u.ctx.closePath(); u.ctx.fill();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var GY = u.H * 0.82;
      u.ground(GY, "#050305");
      u.ctx.globalCompositeOperation = "lighter";
      u.soft(u.W / 2, GY, u.W * 0.45, D.planes[1], 0.25);
      for (var j = 0; j < tongues.length; j++) {
        var g = tongues[j], z = g.z, sp = D.speed * (1.5 + z * 3);
        var h = u.H * (0.18 + z * 0.3) * g.s * (0.8 + 0.2 * Math.sin(t * sp + g.ph)), w = u.W * (0.05 + z * 0.06);
        var lean = Math.sin(t * sp * 1.3 + g.ph) * w * 0.6 + D.gust * w * 1.5;
        var x = u.W * g.x, y = GY - (1 - z) * u.H * 0.03;
        u.soft(x + lean * 0.4, y - h * 0.4, h * 0.5, g.c, 0.12 + (1 - z) * 0.3);
        tongue(x, y, w, h, lean, g.c, 0.3 + z * 0.65);
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("cold colours and half the flicker: the same depth planes read as something that is not quite fire", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.gust = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Dustcloud", "Sandstorm", "the same lit puffs in ochre, sixty of them rolling nearly three times as fast — the sky itself goes the colour of sand", function make(u) {
  // rhyme of Dustcloud: dials moved — sky/dust palette to ochre, puffs 36 → 60, roll 1 → 2.6
  var D = { sky: ["#B07A3A", "#E0B070"], dust: "#C89050", puffs: 60, roll: 2.6, lightX: -1, seed: 17 };
  var R = u.rng(D.seed), puffs = [];
  for (var j = 0; j < D.puffs; j++) puffs.push({ x: R(), z: R(), ph: R() * 9 });
  puffs.sort(function (a, b) { return a.z - b.z; });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var GY = u.H * 0.72;
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.shade(D.dust, -0.1), u.shade(D.dust, -0.45)]);
      u.ctx.fillRect(0, GY, u.W, u.H - GY);
      for (var j = 0; j < puffs.length; j++) {
        var q = puffs[j], z = q.z;
        var r = u.W * (0.05 + z * 0.09), span = u.W + r * 2;
        var x = ((q.x * span + t * D.roll * (15 + z * 55)) % span) - r;
        var y = GY + z * u.H * 0.12 - r * 0.4 + Math.sin(t * (0.8 + z) + q.ph) * 3;
        var c = u.fog(u.shade(D.dust, -0.45 * z), (1 - z) * 0.7, D.sky[1]);
        var a = 0.35 + z * 0.5;
        u.ctx.fillStyle = u.rad(x, y, r, [[0, u.rgba(u.shade(c, 0.4), a)], [0.55, u.rgba(c, a)], [1, u.rgba(u.shade(c, -0.3), 0)]], D.lightX * r * 0.45, -r * 0.25);
        u.ctx.beginPath(); u.ctx.arc(x, y, r, 0, u.TAU); u.ctx.fill();
      }
      u.label("more puffs, more speed, and the air the same colour as the dust: the far ones vanish into it entirely", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.lightX = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Fireflies", "Will-o'-wisps", "the same wandering lights in teal over a swamp, with halos twice as wide — the near ones become lanterns", function make(u) {
  // rhyme of Fireflies: dials moved — sky/glow palette to swamp teal, halo 1 → 2.2
  var D = { sky: ["#0A1A1E", "#1A3A3A", "#0E2A1E"], glow: "#60F0D0", flies: 40, halo: 2.2, seed: 23 };
  var R = u.rng(D.seed), flies = [], grass = [];
  for (var j = 0; j < D.flies; j++) flies.push({ x: R(), y: 0.3 + R() * 0.5, z: R(), a: 0.3 + R() * 0.5, b: 0.2 + R() * 0.4, ph: R() * 9 });
  flies.sort(function (a, b) { return a.z - b.z; });
  for (var k = 0; k < 30; k++) grass.push([R(), 0.06 + R() * 0.1, R() * 9]);
  return {
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]], [1, D.sky[2]]]);
      var GY = u.H * 0.8;
      u.ground(GY, "#0A140A");
      for (var k = 0; k < grass.length; k++)
        u.line(grass[k][0] * u.W, GY + 1, grass[k][0] * u.W + Math.sin(t * 0.8 + grass[k][2]) * 3, GY - grass[k][1] * u.H, "#0A140A", 1.5);
      u.ctx.globalCompositeOperation = "lighter";
      for (var j = 0; j < flies.length; j++) {
        var f = flies[j], z = f.z, wander = 0.3 + z;
        var x = f.x * u.W + Math.sin(t * f.a + f.ph) * u.W * 0.08 * wander;
        var y = f.y * u.H + Math.sin(t * f.b * 1.3 + f.ph * 2) * u.H * 0.05 * wander;
        var blink = Math.pow(0.5 + 0.5 * Math.sin(t * (0.8 + z * 3) + f.ph), 3);
        var c = u.fog(D.glow, (1 - z) * 0.7, D.sky[1]);
        var r = 0.6 + z * 2.2;
        u.soft(x, y, r * (3 + z * 8) * D.halo, c, (0.05 + 0.5 * z) * blink);
        u.dot(x, y, r, u.rgba(c, (0.25 + z * 0.75) * blink));
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("the halo dial is the whole difference between an insect and a haunting", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { for (var j = 0; j < flies.length; j++) { flies[j].x += (x / u.W - flies[j].x) * 0.4 * flies[j].z; flies[j].y += (y / u.H - flies[j].y) * 0.4 * flies[j].z; } }
  };
});

rhymeOf("Glitter", "Pixie dust", "the same twinkles in gold, twice as many, drifting up twice as fast — a trail that never settles", function make(u) {
  // rhyme of Glitter: dials moved — star/deep palette to gold, count 70 → 140, drift 1 → 2
  var D = { sky: ["#0E0A06", "#2A1E10"], star: "#FFF4C0", deep: "#F5C169", count: 140, drift: 2, seed: 41 };
  var R = u.rng(D.seed), stars = [];
  for (var j = 0; j < D.count; j++) stars.push({ x: R(), y: R(), z: R(), ph: R() * 9 });
  stars.sort(function (a, b) { return a.z - b.z; });
  var burst = null, lastT = 0;
  function star4(x, y, r, c) {
    var pts = [];
    for (var k = 0; k < 8; k++) { var ang = k * u.TAU / 8, rr = k % 2 ? r * 0.3 : r; pts.push([x + Math.cos(ang) * rr, y + Math.sin(ang) * rr]); }
    u.poly(pts, c);
  }
  return {
    frame: function (dt, t) {
      lastT = t;
      u.sky(D.sky);
      u.ctx.globalCompositeOperation = "lighter";
      for (var j = 0; j < stars.length; j++) {
        var s = stars[j], z = s.z;
        var tw = 0.5 + 0.5 * Math.sin(t * (1 + z * 4) + s.ph);
        var y = (((s.y - t * D.drift * (0.01 + z * 0.05)) % 1) + 1) % 1 * u.H;
        var x = s.x * u.W + Math.sin(t * 0.5 + s.ph) * (2 + z * 8);
        var c = u.fog(u.mix(D.deep, D.star, z), (1 - z) * 0.7, D.sky[1]);
        var r = (1 + z * 5) * (0.6 + 0.4 * tw), a = (0.15 + z * 0.85) * (0.4 + 0.6 * tw);
        if (z > 0.5) u.soft(x, y, r * 3, c, 0.35 * z * tw);
        star4(x, y, r, u.rgba(c, a));
      }
      if (burst) {
        var age = (t - burst.t) / 1.2;
        if (age < 1) for (var k = 0; k < 12; k++) {
          var ang = k * u.TAU / 12, d = u.ease(age) * u.W * 0.18;
          star4(burst.x + Math.cos(ang) * d, burst.y + Math.sin(ang) * d, 4 * (1 - age) + 0.5, u.rgba(D.star, 1 - age));
        } else burst = null;
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("double the count and the depth sort matters more: near gold covers far gold, never the other way", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { burst = { x: x, y: y, t: lastT }; }
  };
});

rhymeOf("Incense", "Cigarette", "the same ribbon in plain grey, curling twice as fast, thinner and shorter — a bar at closing time", function make(u) {
  // rhyme of Incense: dials moved — smoke/pale palette to greys, curl 1 → 2.4, dots 60 → 40
  var D = { room: ["#141416", "#08080A"], smoke: "#4A4A4C", pale: "#A8A8AC", tip: "#FF6A2A", dots: 40, curl: 2.4 };
  var cx = u.W * 0.5, sy = u.H * 0.78, current = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.room);
      u.line(cx, u.H * 0.96, cx, sy, "#2A1E14", 3);
      u.ctx.fillStyle = "#050305"; u.ctx.fillRect(cx - u.W * 0.08, u.H * 0.94, u.W * 0.16, u.H * 0.03);
      for (var i = D.dots - 1; i >= 0; i--) {
        var k = i / D.dots;
        var y = sy - k * u.H * 0.72;
        var x = cx + Math.sin(k * 5 - t * 0.8 * D.curl) * u.W * (0.01 + k * 0.1)
                   + Math.sin(k * 13 - t * 1.7 * D.curl) * u.W * 0.02 * k + current * k * k * u.W * 0.3;
        var r = 1.2 + k * 4 + k * k * 14;
        var c = u.fog(u.mix(D.smoke, D.pale, k), k * 0.6, D.room[0]);
        u.soft(x, y, r, c, 0.75 * (1 - k * 0.8));
      }
      u.soft(cx, sy, 9, D.tip, 0.6 * (0.7 + 0.3 * Math.sin(t * 5)));
      u.dot(cx, sy, 1.6, "#FFE0A0");
      u.label("fewer dots and a quicker curl: the same ribbon, restless instead of ceremonial", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { current = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Jellyfish", "Alien jellies", "the same bells in magenta, six of them at six depths, pulsing faster — a deeper, stranger sea", function make(u) {
  // rhyme of Jellyfish: dials moved — sea/bell/core palette to magenta, bells 3 → 6, pulse 1 → 1.6
  var D = { sea: ["#1A0A30", "#08041A"], bell: "#F080D0", core: "#FFB0F0", bells: 6, pulse: 1.6, seed: 5,
            snap: 60, relax: 0.5, contract: 0.1, thrust: 0.12, drag: 1.6, sink: 0.02, arms: 90, armdamp: 0.3 };
  var R = u.rng(D.seed), jellies = [], ARMS = 5, SEGS = 8;
  for (var j = 0; j < D.bells; j++) {
    var z = (j + 0.5) / D.bells;
    var J = { x: 0.15 + R() * 0.7, y: 0.25 + R() * 0.35, z: z, vx: 0, vy: 0, c: 0, cv: 0, clk: R() * 4 };
    J.hx = J.x; J.hy = J.y;
    J.r0 = u.W * (0.05 + z * 0.09);
    J.px = new Float32Array(ARMS * SEGS); J.py = new Float32Array(ARMS * SEGS);
    J.tvx = new Float32Array(ARMS * SEGS); J.tvy = new Float32Array(ARMS * SEGS);
    for (var k = 0; k < ARMS; k++) for (var s = 0; s < SEGS; s++) {
      J.px[k * SEGS + s] = J.x * u.W - J.r0 * 0.7 + k * J.r0 * 0.35; J.py[k * SEGS + s] = J.y * u.H + (s + 1) * J.r0 * 0.35;
    }
    jellies.push(J);
  }
  return {
    frame: function (dt, t) {
      u.sky(D.sea);
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      var bd = D.relax * 2 * Math.sqrt(D.snap), ad = D.armdamp * 2 * Math.sqrt(D.arms);
      for (var j = 0; j < jellies.length; j++) {
        var J = jellies[j], z = J.z, sp = D.pulse * (0.6 + z * 1.2), per = u.TAU / sp;
        var seg = J.r0 * 0.35;
        for (var s = 0; s < sub; s++) {
          J.clk += h;
          if (J.clk >= per) {
            J.clk -= per;
            J.cv += 2 * Math.sqrt(D.snap);
            var dx = J.hx - J.x, dy = J.hy - J.y, dist = Math.sqrt(dx * dx + dy * dy);
            var ang = dist < 0.03 ? R() * u.TAU : Math.atan2(dy, dx) + (R() - 0.5) * 1.2;
            var go = D.thrust * (0.6 + z * 0.8);
            J.vx += Math.cos(ang) * go; J.vy += Math.sin(ang) * go - D.thrust * 0.6;
          }
          J.cv += (D.snap * (0 - J.c) - bd * J.cv) * h; J.c = u.clamp(J.c + J.cv * h, -0.5, 1.5);
          J.vy += D.sink * h;
          J.vx -= J.vx * D.drag * h; J.vy -= J.vy * D.drag * h;
          J.x += J.vx * h; J.y += J.vy * h;
          if (J.x < 0.04) { J.x = 0.04; J.vx = 0; } else if (J.x > 0.96) { J.x = 0.96; J.vx = 0; }
          if (J.y < 0.08) { J.y = 0.08; J.vy = 0; } else if (J.y > 0.85) { J.y = 0.85; J.vy = 0; }
          var r = J.r0 * (1 - D.contract * J.c), bx = J.x * u.W, by = J.y * u.H;
          for (var k = 0; k < ARMS; k++) {
            var ax = bx - r * 0.7 + k * r * 0.35, ay = by;
            for (var q = 0; q < SEGS; q++) {
              var i = k * SEGS + q;
              J.tvx[i] += (D.arms * (ax - J.px[i]) - ad * J.tvx[i]) * h;
              J.tvy[i] += (D.arms * (ay + seg - J.py[i]) - ad * J.tvy[i]) * h;
              J.px[i] += J.tvx[i] * h; J.py[i] += J.tvy[i] * h;
              ax = J.px[i]; ay = J.py[i];
            }
          }
        }
        var pulse = u.clamp(J.c, 0, 1), rr = J.r0 * (1 - D.contract * J.c);
        var x = J.x * u.W, y = J.y * u.H;
        var c = u.fog(D.bell, (1 - z) * 0.75, D.sea[0]), a = 0.25 + z * 0.45;
        u.ctx.strokeStyle = u.rgba(c, a * 0.6); u.ctx.lineWidth = 0.6 + z * 1.2;
        for (var k = 0; k < ARMS; k++) {
          u.ctx.beginPath(); u.ctx.moveTo(x - rr * 0.7 + k * rr * 0.35, y);
          for (var q = 0; q < SEGS; q++) u.ctx.lineTo(J.px[k * SEGS + q], J.py[k * SEGS + q]);
          u.ctx.stroke();
        }
        u.ctx.fillStyle = u.rad(x, y, rr, [[0, u.rgba(u.shade(c, 0.5), a)], [0.7, u.rgba(c, a * 0.8)], [1, u.rgba(c, a * 0.2)]], -rr * 0.3, -rr * 0.4);
        u.ctx.beginPath(); u.ctx.arc(x, y, rr, Math.PI, 0); u.ctx.quadraticCurveTo(x, y + rr * 0.35, x - rr, y); u.ctx.fill();
        u.ctx.globalCompositeOperation = "lighter";
        u.soft(x, y - rr * 0.2, rr * 0.7, D.core, (0.15 + z * 0.5) * (0.6 + 0.4 * pulse));
        u.ctx.globalCompositeOperation = "source-over";
      }
      u.label("six depths instead of three and the ladder of size, alpha and speed becomes a staircase you can count", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { for (var j = 0; j < jellies.length; j++) { jellies[j].hx += (x / u.W - jellies[j].hx) * 0.5 * jellies[j].z; jellies[j].hy += (y / u.H - jellies[j].hy) * 0.5 * jellies[j].z; } }
  };
});

rhymeOf("Motes", "Snow globe motes", "the same shaft of light in cold white, and the motes now hop instead of float — the bounce dial turned to one", function make(u) {
  // rhyme of Motes: dials moved — room/light palette to cold white, bounce 0 → 1
  var D = { room: ["#0E1420", "#060A14"], light: "#E8F4FF", motes: 60, shaftX: 0.35, bounce: 1, seed: 29,
            gravity: 2.5, rebound: 0.5, rest: 0.5 };
  var R = u.rng(D.seed), motes = [];
  for (var j = 0; j < D.motes; j++) motes.push({ x: R(), y: R(), z: R(), ph: R() * 9, a: 0, av: 0, wait: R() });
  motes.sort(function (a, b) { return a.z - b.z; });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.room);
      var x0 = u.W * D.shaftX, slope = u.W * 0.3, hw = u.W * 0.13;
      u.ctx.globalCompositeOperation = "lighter";
      u.ctx.save(); u.ctx.transform(1, 0, slope / u.H, 1, 0, 0);
      u.ctx.fillStyle = u.lin(x0 - hw, 0, x0 + hw, 0, [[0, u.rgba(D.light, 0)], [0.5, u.rgba(D.light, 0.22)], [1, u.rgba(D.light, 0)]]);
      u.ctx.fillRect(x0 - hw, 0, hw * 2, u.H);
      u.ctx.restore();
      var g = D.gravity * u.H, sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      for (var j = 0; j < motes.length; j++) {
        var m = motes[j], z = m.z, slow = 1.4 - z;
        var top = D.bounce * (0.3 + z) * u.H * 0.08;
        for (var s = 0; s < sub; s++) {
          if (m.a > 0 || m.av > 0) {
            m.av -= g * h; m.a += m.av * h;
            if (m.a <= 0) {
              m.a = 0; m.av = -m.av * D.rebound;
              if (m.av * m.av < 2 * g * 0.5) { m.av = 0; m.wait = R() * D.rest; }
            }
          } else if (top > 0) {
            m.wait -= h;
            if (m.wait <= 0) m.av = Math.sqrt(2 * g * top) * (0.7 + 0.6 * R());
          }
        }
        var x = ((m.x + t * 0.012 * slow) % 1) * u.W + Math.sin(t * 0.4 + m.ph) * (3 + z * 6);
        var y = ((m.y + t * 0.008 * slow) % 1) * u.H - m.a;
        var tumble = 0.6 + 0.4 * Math.sin(t * (1 + z * 2) + m.ph);
        var inside = Math.abs(x - (x0 + slope * y / u.H)) < hw;
        var bright = inside ? 1 : 0.15;
        var r = 0.5 + z * 2.2, a = (0.2 + z * 0.8) * bright * tumble;
        var c = u.mix(D.room[0], D.light, 0.3 + z * 0.7);
        if (inside && z > 0.6) u.soft(x, y, r * 3, D.light, 0.25 * z * tumble);
        u.dot(x, y, r, u.rgba(c, a));
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("near motes hop higher (the kick scales with z) and every landing bounces — even a toy obeys the depth rule", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.shaftX = x / u.W - 0.3 * (y / u.H); }
  };
});

rhymeOf("Plume", "Chimney at dusk", "the same smoke column with the light on each puff moved to its UNDERSIDE, warm orange, against a sunset — the low sun lights it from below", function make(u) {
  // rhyme of Plume: dials moved — sky palette to dusk, lit "#9AA0B8" → "#F5A15A", litY -1 → +1
  var D = { sky: ["#2A1E4A", "#8A4A6A", "#F5A15A"], smoke: "#3A3A44", lit: "#F5A15A", litY: 1,
            puffs: 40, rise: 0.22, wind: 0, seed: 3 };
  var R = u.rng(D.seed), puffs = [];
  for (var j = 0; j < D.puffs; j++) puffs.push({ z: R(), ph: R(), sw: R() * 9, side: R() * 2 - 1 });
  puffs.sort(function (a, b) { return a.z - b.z; });
  function puff(x, y, r, c, a, hard) {
    u.ctx.fillStyle = u.rad(x, y, r, [[0, u.rgba(u.mix(c, D.lit, 0.35), a)], [hard, u.rgba(c, a * 0.9)], [1, u.rgba(c, 0)]], 0, D.litY * r * 0.35);
    u.ctx.beginPath(); u.ctx.arc(x, y, r, 0, u.TAU); u.ctx.fill();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]], [1, D.sky[2]]]);
      var GY = u.H * 0.86, cx = u.W * 0.42, top = GY - u.H * 0.2;
      u.ground(GY, "#0E0B1A");
      u.ctx.fillStyle = "#0E0B1A"; u.ctx.fillRect(cx - u.W * 0.04, top, u.W * 0.08, u.H * 0.2);
      for (var j = 0; j < puffs.length; j++) {
        var q = puffs[j], z = q.z;
        var p = (t * D.rise * (0.5 + z) + q.ph) % 1;
        var y = top - p * u.H * 0.8;
        var x = cx + D.wind * p * p * u.W * 0.35 + q.side * p * u.W * 0.08 * (0.5 + z) + Math.sin(q.sw + p * 5 + t * 0.3) * (3 + z * 8);
        var r = u.W * (0.02 + z * 0.06) * (0.4 + p * 1.4);
        var a = (0.15 + z * 0.55) * (1 - p) * Math.min(1, p * 5 + 0.2);
        var c = u.fog(D.smoke, (1 - z) * 0.7 + p * 0.25, D.sky[1]);
        puff(x, y, r, c, a, 0.05 + z * 0.45);
      }
      u.label("flip the inner point of each puff's gradient from top to bottom and the light comes from a setting sun", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Steam", "Sci-fi coolant", "the same wisps in cyan off a steel vent, adding nearly twice as hard — leaking reactor, not breakfast", function make(u) {
  // rhyme of Steam: dials moved — steam/cup/room palette to cyan and steel, gain 1 → 1.8
  var D = { room: ["#06080E", "#0E1620"], steam: "#60E8FF", cup: "#3A4450", wisps: 34, rise: 0.25, gain: 1.8, curl: 1, wind: 0, seed: 13 };
  var R = u.rng(D.seed), wisps = [];
  for (var j = 0; j < D.wisps; j++) wisps.push({ z: R(), ph: R(), sw: R() * 9, side: R() * 2 - 1 });
  wisps.sort(function (a, b) { return a.z - b.z; });
  function puff(x, y, r, c, a, hard) {
    u.ctx.fillStyle = u.rad(x, y, r, [[0, u.rgba(c, a)], [hard, u.rgba(c, a * 0.85)], [1, u.rgba(c, 0)]]);
    u.ctx.beginPath(); u.ctx.arc(x, y, r, 0, u.TAU); u.ctx.fill();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.room);
      var cx = u.W * 0.5, top = u.H * 0.62;
      u.cyl(cx, u.H * 0.9, u.W * 0.22, u.H * 0.28, D.cup, -0.4);
      u.ctx.fillStyle = u.shade(D.cup, 0.25);
      u.ctx.beginPath(); u.ctx.ellipse(cx, top, u.W * 0.11, u.H * 0.025, 0, 0, u.TAU); u.ctx.fill();
      u.ctx.globalCompositeOperation = "lighter";
      for (var j = 0; j < wisps.length; j++) {
        var w = wisps[j], z = w.z;
        var p = (t * D.rise * (0.5 + z) + w.ph) % 1;
        var y = top - p * u.H * 0.55;
        var x = cx + w.side * u.W * 0.06 * (0.4 + z * 0.6) + Math.sin(p * 4 * D.curl + w.sw + t * 0.4) * u.W * (0.02 + p * 0.08) + D.wind * p * p * u.W * 0.3;
        var r = u.W * (0.02 + z * 0.05) * (0.5 + p * 1.2);
        var a = (0.08 + z * 0.35) * D.gain * (1 - p) * Math.min(1, p * 6 + 0.15);
        var c = u.mix(D.room[1], D.steam, 0.3 + z * 0.7);
        puff(x, y, r, c, a, 0.05 + z * 0.35);
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("turn the gain up and additive light saturates where near wisps overlap — the glow is the genre", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Vapour", "Swamp gas", "the same four fog bands tinted sickly green under a low sky, drifting two and a half times as fast", function make(u) {
  // rhyme of Vapour: dials moved — sky/fog palette to green, drift 1 → 2.5
  var D = { sky: ["#1A2A20", "#4A6A48", "#7A9A70"], fog: "#9AC89A", tree: "#0A1210", bands: 4, per: 12, drift: 2.5, seed: 19 };
  var R = u.rng(D.seed), blobs = [], trees = [];
  for (var i = 0; i < D.bands; i++) for (var j = 0; j < D.per; j++) blobs.push({ band: i, x: R(), ph: R() * 9 });
  for (var k = 0; k < 9; k++) trees.push({ x: R(), d: R() });
  trees.sort(function (a, b) { return a.d - b.d; });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.5, D.sky[1]], [1, D.sky[2]]]);
      var hor = u.H * 0.45, ti = 0;
      u.ground(hor, u.mix(D.tree, D.sky[2], 0.5));
      for (var i = 0; i < D.bands; i++) {
        var d = i / (D.bands - 1), by = hor + Math.pow(d, 1.5) * u.H * 0.45 + u.H * 0.03;
        while (ti < trees.length && trees[ti].d <= (i + 1) / D.bands) {
          var tr = trees[ti++], td = tr.d, ty = hor + Math.pow(td, 1.5) * u.H * 0.45 + u.H * 0.03, h = u.H * (0.08 + td * 0.3), tx = tr.x * u.W;
          var tc = u.fog(D.tree, (1 - td) * 0.85, D.sky[1]);
          u.poly([[tx - h * 0.18, ty], [tx, ty - h], [tx + h * 0.18, ty]], tc);
          u.ctx.fillStyle = tc; u.ctx.fillRect(tx - h * 0.03, ty - 1, h * 0.06, h * 0.12);
        }
        var r = u.W * (0.08 + d * 0.1), span = u.W + r * 2;
        var c = u.shade(u.mix(D.fog, D.sky[1], (1 - d) * 0.6), -0.25 * d);
        for (var j = 0; j < blobs.length; j++) {
          var b = blobs[j]; if (b.band !== i) continue;
          var x = ((((b.x * span + t * D.drift * (4 + d * 28)) % span) + span) % span) - r;
          u.ctx.save(); u.ctx.translate(x, by + Math.sin(t * 0.3 + b.ph) * 3); u.ctx.scale(1, 0.4);
          u.soft(0, 0, r, c, 0.2 + d * 0.4);
          u.ctx.restore();
        }
      }
      u.label("the air's colour is a dial: tint the fog and every tree behind it takes the tint — that is what 'air' means", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.drift = (x / u.W - 0.5) * 4; }
  };
});

rhymeOf("Wildfire", "Candle field", "the same perspective rows with five flames a row instead of twelve, flickering gently, no smoke — a vigil, not a disaster", function make(u) {
  // rhyme of Wildfire: dials moved — far/near palette to candle cream, dense 12 → 5, flicker 1 → 0.4, smoke 10 → 0
  var D = { sky: ["#0A0608", "#1E1010"], far: "#A05A20", near: "#FFF0C0", rows: 7, dense: 5, flicker: 0.4, smoke: 0, wind: 0, seed: 37 };
  var R = u.rng(D.seed), flames = [], smokes = [];
  for (var i = 0; i < D.rows; i++) {
    var p = i / (D.rows - 1), n = Math.max(1, Math.round(D.dense - p * D.dense * 0.5));
    for (var j = 0; j < n; j++) flames.push({ p: p, x: (j + 0.2 + R() * 0.6) / n, ph: R() * 9, s: 0.7 + R() * 0.6 });
  }
  for (var k = 0; k < D.smoke; k++) smokes.push({ x: R(), ph: R(), z: R() });
  function tongue(x, y, w, h, lean, c, a) {
    u.ctx.fillStyle = u.lin(0, y, 0, y - h, [[0, u.rgba(c, a)], [0.6, u.rgba(c, a * 0.8)], [1, u.rgba(c, 0)]]);
    u.ctx.beginPath(); u.ctx.moveTo(x - w / 2, y);
    u.ctx.quadraticCurveTo(x - w / 2 + lean * 0.3, y - h * 0.55, x + lean, y - h);
    u.ctx.quadraticCurveTo(x + w / 2 + lean * 0.3, y - h * 0.55, x + w / 2, y);
    u.ctx.closePath(); u.ctx.fill();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var hor = u.H * 0.42;
      u.ctx.fillStyle = u.lin(0, hor, 0, u.H, ["#2A0C08", "#0A0406"]); u.ctx.fillRect(0, hor, u.W, u.H - hor);
      for (var k = 0; k < smokes.length; k++) {
        var s = smokes[k], q = (t * 0.08 * (0.5 + s.z) + s.ph) % 1;
        u.soft(((s.x + D.wind * q * 0.3 + 10) % 1) * u.W, hor - q * hor * 0.9, u.W * (0.05 + s.z * 0.08) * (0.5 + q), u.mix("#3A2A28", D.sky[1], 0.5), (0.1 + s.z * 0.25) * (1 - q));
      }
      u.ctx.globalCompositeOperation = "lighter";
      u.soft(u.W / 2, hor, u.W * 0.6, D.far, 0.3);
      for (var j = 0; j < flames.length; j++) {
        var f = flames[j], p = f.p, scale = 0.12 + p * 0.88, sp = (3 + p * 4) * D.flicker;
        var y = hor + p * p * u.H * 0.55 + 2, x = f.x * u.W;
        var h = u.H * 0.17 * scale * f.s * (0.8 + 0.2 * Math.sin(t * sp + f.ph)), w = u.W * 0.045 * scale + 1;
        var lean = Math.sin(t * sp * 1.3 + f.ph) * w * 0.5 + D.wind * w * 1.2;
        var c = u.mix(D.far, D.near, p);
        if (p > 0.5) u.soft(x, y - h * 0.3, h * 0.6, c, 0.15 * p);
        tongue(x, y, w, h, lean, c, 0.3 + p * 0.7);
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("fewer flames, slower flicker, no smoke: the same rows read as candles because calm is a dial too", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = (x / u.W - 0.5) * 2; }
  };
});

rhymeOf("Yule", "Campfire embers", "the same logs under an open night sky, the flame burnt down to a third and forty coals glowing — the fire an hour later", function make(u) {
  // rhyme of Yule: dials moved — room/hearth palette to night, flame 1 → 0.35, embers 10 → 40
  var D = { room: ["#04060E", "#0E1424"], hearth: "#0A0C14", planes: ["#8A1E10", "#F0A030"], log: "#3A2416", ember: "#FF9A3A",
            per: 5, flame: 0.35, embers: 40, seed: 43 };
  var R = u.rng(D.seed), tongues = [], embers = [];
  for (var i = 0; i < D.planes.length; i++)
    for (var j = 0; j < D.per; j++) tongues.push({ z: (i + 0.5) / D.planes.length, c: D.planes[i], x: 0.32 + (j + R() * 0.6) / D.per * 0.36, ph: R() * 9, s: 0.7 + R() * 0.6 });
  for (var k = 0; k < D.embers; k++) embers.push({ x: R(), ph: R() * 9, front: k % 2 });
  var flare = 0;
  function tongue(x, y, w, h, lean, c, a) {
    u.ctx.fillStyle = u.lin(0, y, 0, y - h, [[0, u.rgba(c, a)], [0.6, u.rgba(c, a * 0.8)], [1, u.rgba(c, 0)]]);
    u.ctx.beginPath(); u.ctx.moveTo(x - w / 2, y);
    u.ctx.quadraticCurveTo(x - w / 2 + lean * 0.3, y - h * 0.55, x + lean, y - h);
    u.ctx.quadraticCurveTo(x + w / 2 + lean * 0.3, y - h * 0.55, x + w / 2, y);
    u.ctx.closePath(); u.ctx.fill();
  }
  function log(x, y, len, thick, tilt) {
    u.ctx.save(); u.ctx.translate(x, y); u.ctx.rotate(Math.PI / 2 + tilt);
    u.cyl(0, len / 2, thick, len, D.log, -0.3);
    u.ctx.restore();
  }
  return {
    frame: function (dt, t) {
      var fl = 0.85 + 0.15 * Math.sin(t * 7.3) * Math.sin(t * 3.1) + flare * 0.4;
      flare *= 0.96;
      u.sky([u.mix(D.room[0], D.room[1], fl * 0.5), u.mix(D.room[1], "#8A4A20", fl * 0.4)]);
      var GY = u.H * 0.84;
      u.ctx.fillStyle = D.hearth; u.ctx.fillRect(u.W * 0.2, u.H * 0.3, u.W * 0.6, GY - u.H * 0.3);
      u.ground(GY, "#1E1410");
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [[0, u.rgba(D.ember, 0.35 * fl)], [1, u.rgba(D.ember, 0)]]); u.ctx.fillRect(0, GY, u.W, u.H - GY);
      u.ctx.globalCompositeOperation = "lighter";
      for (var j = 0; j < tongues.length; j++) {
        var g = tongues[j], z = g.z, sp = 1.5 + z * 3;
        var h = u.H * (0.14 + z * 0.14) * g.s * D.flame * (0.8 + 0.2 * Math.sin(t * sp + g.ph)) * (1 + flare * 0.5), w = u.W * (0.04 + z * 0.04);
        var lean = Math.sin(t * sp * 1.3 + g.ph) * w * 0.5, x = u.W * g.x, y = GY - u.H * 0.06 - (1 - z) * u.H * 0.04;
        u.soft(x, y - h * 0.4, h * 0.5, g.c, 0.1 + (1 - z) * 0.3);
        tongue(x, y, w, h, lean, g.c, 0.3 + z * 0.65);
      }
      u.ctx.globalCompositeOperation = "source-over";
      log(u.W * 0.5, GY - u.H * 0.075, u.W * 0.4, u.H * 0.06, 0.15);
      log(u.W * 0.5, GY - u.H * 0.045, u.W * 0.44, u.H * 0.07, -0.1);
      u.ctx.globalCompositeOperation = "lighter";
      for (var k = 0; k < embers.length; k++) {
        var e = embers[k], ex = u.W * (0.3 + e.x * 0.4);
        var ey = e.front ? GY - u.H * 0.045 - (ex - u.W / 2) * 0.1 - u.H * 0.02 : GY - u.H * 0.075 + (ex - u.W / 2) * 0.15 - u.H * 0.02;
        var glow = 0.5 + 0.5 * Math.sin(t * (2 + e.ph * 0.3) + e.ph);
        u.soft(ex, ey, 3 + glow * 3 + flare * 4, D.ember, 0.25 + 0.5 * glow);
        u.dot(ex, ey, 1, "#FFE0A0");
      }
      u.ctx.globalCompositeOperation = "source-over";
      u.label("low flame, many coals: the depth order is untouched — the fire is just older", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { flare = 1; }
  };
});
/* ============================== WAVES & RIBBONS ==============================
   A moving surface looks solid the moment its SHADE follows its SLOPE. The
   slope of a sine is its cosine — so shade each strip by cos and the side
   facing the light goes pale, the side facing away goes dark, and a flat
   wiggle becomes a fold. A ribbon adds one rule: its apparent width is
   |cos(twist)|, and when cos turns negative you are looking at the BACK,
   so the colour flips. Rows of sea recede the way every horizon does —
   spacing bunches toward the horizon (horizon + p²), far rows lose their
   amplitude and mix toward the air. Thirteen pictures. */

def("F", "Flag", "wave", "a flag is vertical strips sewn to the pole and pulled by their neighbours: the pole's vortices shove the first strip, the cloth carries the wave out and the free end swings furthest — shade each strip by its slope and the ripple becomes folds; a gust takes a second to reach the free end", function make(u) {
  var D = { sky: ["#6FA8E8", "#CFE6F5"], cloth: "#D8302A", band: "#F5F0E0", pole: "#8A8A96",
            strips: 16,              // strips of cloth: the first is sewn to the pole and never moves
            wind: 1.0,               // the wind a press asks for — the cloth feels a wind that CHASES this, it never jumps
            waves: 1.6,              // waves along the flag at wind 1: sets the cloth's tension, k = (strips · f / waves)²
            shadeBy: 0.45,           // how hard the slope shades the cloth
            damp: 0.6,               // each strip's damping, per second — low, so a gust rings down the cloth for a while
            light: 1.1,              // each strip's stiffness-per-mass over the one before: the hoist is the heaviest band, so the wave GROWS toward the free end
            drive: 0.04,             // the pole's vortex shove on the first strip, as a fraction of the flag's height per unit wind
            flutter: 1.5 };          // how fast the shedding oscillator grows to full swing (its van der pol gain)
  var N = Math.max(4, Math.floor(D.strips));
  var y = new Float32Array(N), v = new Float32Array(N);                      // each strip's lift as a fraction of the flag's height, and its velocity; strip 0 is the pole
  var wv = 0, wvv = 0, fx = 0.5, fv = 0;                                      // the wind the cloth feels (a spring chasing D.wind), and the shedding oscillator
  // the cloth is a STRING of strips: each one pulled toward both its
  // neighbours by the cloth's tension (a wave equation), the first strip sewn
  // to the pole, the last with nothing beyond it — so a wave reaching the free
  // end has nothing to pull back and swings double. what sets it going is the
  // pole: air shedding off a rod pulses at a rate proportional to the wind
  // (strouhal), modelled as a self-excited oscillator that grows from any nudge
  // and saturates, shoving the first strip. the wind itself is a spring
  // chasing the pressed value, so a gust arrives late, and later still at the
  // free end: watch the ripple run out along the flag after a click.
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var px = u.W * 0.18, top = u.H * 0.16, fw = u.W * 0.58, fh = u.H * 0.34, GY = u.H * 0.86;
      u.ground(GY, "#3A5A3A");
      u.shadow(px + fw * 0.35, GY + 2, fw * 0.45, 5, 0.3);                   // the flag's shadow on the grass
      u.cyl(px - 3, GY, 6, GY - top + 14, D.pole, -0.3);
      u.sphere(px - 3, top - 16, 5, "#E8C060", -0.5, -0.5);
      // the string's top mode rings at 2√k, and a symplectic step holds only while
      // √k·h < 1 — so a coarse frame is cut into substeps of at most 1/60 s
      var sub = Math.max(1, Math.ceil(dt * 60)), h = dt / sub, kw = 6;       // kw: the wind's own spring — it settles on a press in about a second
      for (var st = 0; st < sub; st++) {
        wvv += (kw * (D.wind - wv) - 0.9 * 2 * Math.sqrt(kw) * wvv) * h; wv += wvv * h;   // the wind eases toward the pressed value, just under critical
        var om = 4 * Math.max(0.05, wv);                                     // the shedding rate follows the wind
        fv += (-om * om * fx + D.flutter * om * (1 - fx * fx) * fv) * h; fx += fv * h;   // van der pol: negative damping below |x| = 1, positive above — it settles at |x| ≈ 2
        var k = Math.pow(N * om / u.TAU / D.waves, 2), inv = 1;             // tension so that `waves` fit along the flag at this wind; inv: 1 / this strip's mass
        for (var i = 1; i < N; i++) {
          inv *= D.light;
          var f = k * (y[i - 1] - y[i]);                                     // pulled toward the strip before …
          if (i + 1 < N) f += k * (y[i + 1] - y[i]);                         // … and the one after; the free end has none, and swings double
          if (i === 1) f += fx * D.drive * wv * k;                           // the pole's vortex street shoves the first free strip
          v[i] += (f * inv - D.damp * v[i]) * h;
        }
        for (var i2 = 1; i2 < N; i2++) y[i2] = u.clamp(y[i2] + v[i2] * h, -0.5, 0.5);
      }
      var sw = fw / (N - 1);
      for (var j = 0; j < N - 1; j++) {                                      // a quad per strip: its top edge runs from this lift to the next
        var kk = j / (N - 1), x0 = px + j * sw, x1 = x0 + sw, y0 = top + y[j] * fh, y1 = top + y[j + 1] * fh;
        var h0 = fh * (1 - kk * 0.08), h1 = fh * (1 - (j + 1) / (N - 1) * 0.08);   // the free end hangs a little shorter
        var slope = (y1 - y0) / sw;                                          // dy/dx across the strip — which way it faces
        var fold = u.clamp(1 - kk * 3, 0, 1) * 0.25;                         // the cloth shades itself where it bunches at the pole
        var lit = u.clamp(slope * 2 * D.shadeBy - fold, -0.45, 0.45);
        u.poly([[x0, y0], [x1 + 0.5, y1], [x1 + 0.5, y1 + h1], [x0, y0 + h0]], u.shade(D.cloth, lit));
        u.poly([[x0, y0 + h0 * 0.38], [x1 + 0.5, y1 + h1 * 0.38], [x1 + 0.5, y1 + h1 * 0.58], [x0, y0 + h0 * 0.58]], u.shade(D.band, lit));   // a stripe rides the same folds
      }
      u.label("wind chases the press · pole vortices shove strip 1 · yᵢ'' = k(yᵢ₋₁ − 2yᵢ + yᵢ₊₁)/mᵢ − damp·yᵢ' · shade = slope", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = 0.3 + (x / u.W) * 2; }                // click right = more wind — the cloth's wind catches up over a second
  };
});

def("H", "Helix", "wave", "a ribbon coiled round a rod: slice by slice x = sin θ, width = |cos θ|, back colour when cos < 0 — draw the far half, the rod, then the near half", function make(u) {
  var D = { sky: ["#0E1230", "#1A1E4A"], front: "#5AF0AA", back: "#1E6A4A", rod: "#8A8A96",
            ribbons: 1, turns: 3, slices: 96, radius: 0.2, speed: 0.8 };
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var cx = u.W / 2, top = u.H * 0.1, hgt = u.H * 0.72, R = u.W * D.radius, sh = hgt / D.slices, W2 = R * 0.9;   // W2: the ribbon's true width
      u.ground(top + hgt + 4, "#0A0C20");
      u.shadow(cx, top + hgt + 10, R * 1.4, R * 0.3, 0.45);
      for (var pass = 0; pass < 2; pass++) {                                 // pass 0 = the far half, pass 1 = the near half
        if (pass === 1) u.cyl(cx, top + hgt + 2, R * 0.16, hgt + 8, D.rod, -0.4);   // the rod goes between them
        for (var r = 0; r < D.ribbons; r++)
          for (var i = 0; i < D.slices; i++) {
            var th = (i / D.slices) * D.turns * u.TAU + t * D.speed + r * Math.PI;   // extra ribbons: half a turn apart
            var c = Math.cos(th);                                            // c > 0 = toward you, c < 0 = away
            if ((c >= 0) !== (pass === 1)) continue;
            var x = cx + Math.sin(th) * R, w = Math.abs(c) * W2 + 1;         // apparent width: |cos θ|
            var lit = -Math.sin(th) * 0.2 + Math.abs(c) * 0.15 - 0.1;        // pale on the left (the light side), dim edge-on
            u.ctx.fillStyle = u.shade(c >= 0 ? D.front : D.back, lit);
            u.ctx.fillRect(x - w / 2, top + i * sh, w, sh + 0.8);
          }
      }
      u.label("painter's order: the far half, then the rod, then the near half — occlusion is the depth", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.speed = (x / u.W - 0.5) * 3; }              // click left of centre = spin the other way
  };
});

def("J", "Jetstream", "wave", "four ribbons of wind crossing the sky at different depths — each a band of parallel sines under a soft alpha gradient; far ones paler, thinner, slower", function make(u) {
  var D = { sky: ["#2A4A8F", "#7FA8D8", "#D9E3F0"], ink: "#FFFFFF", streams: 4, lines: 5, speed: 1.0, alpha: 0.45 };
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]], [1, D.sky[2]]]);
      for (var s = 0; s < D.streams; s++) {
        var z = (s + 1) / D.streams;                                         // 0 = far, 1 = near; near streams painted last
        var y0 = u.H * (0.12 + s * 0.19), band = u.H * (0.025 + z * 0.09), amp = u.H * (0.02 + z * 0.05);
        var len = u.W * (0.4 + z * 0.4), ph = t * (0.25 + z * 0.9) * D.speed * 2 + s * 2;
        var a = D.alpha * (0.35 + z * 0.65);                                 // far = fainter
        u.ctx.fillStyle = u.lin(0, y0 - band / 2 - amp, 0, y0 + band / 2 + amp, [[0, u.rgba(D.ink, 0)], [0.5, u.rgba(D.ink, a * 0.5)], [1, u.rgba(D.ink, 0)]]);
        u.ctx.beginPath();
        for (var x = -8; x <= u.W + 8; x += 8) u.ctx.lineTo(x, y0 - band / 2 + Math.sin(x / len * u.TAU - ph) * amp);
        for (var x2 = u.W + 8; x2 >= -8; x2 -= 8) u.ctx.lineTo(x2, y0 + band / 2 + Math.sin(x2 / len * u.TAU - ph + 0.3) * amp);
        u.ctx.closePath(); u.ctx.fill();
        u.ctx.lineWidth = 0.4 + z * 1.2;                                     // far = thinner
        for (var l = 0; l < D.lines; l++) {
          var q = (l + 0.5) / D.lines;
          u.ctx.strokeStyle = u.rgba(D.ink, a * Math.sin(q * Math.PI));       // dense in the middle of the band, soft at its edges
          u.ctx.beginPath();
          for (var x3 = -8; x3 <= u.W + 8; x3 += 8) u.ctx.lineTo(x3, y0 + (q - 0.5) * band + Math.sin(x3 / len * u.TAU - ph + q * 0.3) * amp);
          u.ctx.stroke();
        }
      }
      u.label("one number z sets alpha, width, amplitude and speed — a far stream is less of everything", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.speed = 0.3 + (x / u.W) * 2.2; }             // click right = a stronger wind aloft
  };
});

def("K", "Kite", "wave", "a diamond of two triangles, lit and dark either side of the spar, held on a spring toward a slowly wandering point in the wind — click for a gust: it kicks the kite up and downwind, and the spring brings it back with an overshoot; its tail is a chain, each link following the last, twisting as it trails", function make(u) {
  var D = { sky: ["#3A7FD0", "#B8D8F5"], kite: "#F5A15A", tail: "#F05A8A", tailBack: "#F5E0B0",
            links: 26, link: 0.022, bob: 1.0, wind: 1.0,                    // link: one chain segment, as a share of H
            k: 20, damp: 0.3,          // the body's position spring toward its wind-held point: stiffness, and damping as a fraction of critical (2√k) — under 1, so a gust overshoots
            gust: 0.8 };               // a click's kick, in screens per second: up by gust·H, downwind by half that
  // the kite is a point on a spring. its REST wanders slowly — two slow sines
  // per axis stand in for the wind's drift — and the kite chases it, always
  // a little behind, always overshooting a touch. a gust is not a position:
  // it is velocity added to the kite, which then flies up and past the rest
  // and is pulled back, ringing down over a couple of seconds. the tail is a
  // constrained chain hung from the sprung body, so its whip is the body's
  // real motion run through 26 links.
  var tail = [];
  for (var i = 0; i <= D.links; i++) tail.push([u.W * 0.6 - i * 4, u.H * 0.5 + i * 4]);
  var kx = u.W * 0.6, ky = u.H * 0.36, vx = 0, vy = 0;
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ground(u.H * 0.9, "#4A7A4A");
      var rx = u.W * (0.6 + 0.05 * Math.sin(t * 0.7) + 0.03 * Math.sin(t * 1.9 + 1));           // the wind-held point drifts
      var ry = u.H * (0.36 + 0.05 * Math.sin(t * 1.3 * D.bob) + 0.03 * Math.sin(t * 0.53 + 2));
      // symplectic euler is stable while √k·h < 2 — a coarse frame is cut into substeps of at most 0.02 s
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, damp = D.damp * 2 * Math.sqrt(D.k);
      for (var q = 0; q < sub; q++) {
        vx += (D.k * (rx - kx) - damp * vx) * h; kx += vx * h;
        vy += (D.k * (ry - ky) - damp * vy) * h; ky += vy * h;
      }
      kx = u.clamp(kx, u.W * 0.1, u.W * 0.95); ky = u.clamp(ky, u.H * 0.05, u.H * 0.8);
      var lean = u.clamp(vx / (u.W * 0.6), -0.35, 0.35), kw = u.W * 0.07, kh = u.H * 0.1;   // the kite banks with its sideways speed: the fold's shading shifts
      u.line(u.W * 0.08, u.H * 0.9, kx - kw * 0.3, ky + kh * 0.4, "rgba(0,0,0,0.35)", 1);   // the string
      tail[0] = [kx, ky + kh * 1.2];                                          // the tail: a chain. wind and gravity move each link,
      var L = u.H * D.link, step = Math.min(dt, 0.05);                       // then the link before it pulls it back to length
      for (var i = 1; i <= D.links; i++) {
        var p = tail[i], q2 = tail[i - 1];
        p[1] += 60 * step; p[0] += (30 + 40 * Math.sin(t * 3 + i * 0.4)) * step * D.wind;
        var dx = p[0] - q2[0], dy = p[1] - q2[1], d = Math.sqrt(dx * dx + dy * dy) + 1e-6;
        p[0] = q2[0] + dx / d * L; p[1] = q2[1] + dy / d * L;
      }
      for (var j = 0; j < D.links; j++) {                                    // the tail twists: width by |cos|, colour by its sign
        var a = tail[j], b = tail[j + 1], c = Math.cos(j * 0.45 - t * 4), hw = (Math.abs(c) * 3.5 + 0.5) * (1 - j / D.links * 0.5);
        var ex = b[0] - a[0], ey = b[1] - a[1], el = Math.sqrt(ex * ex + ey * ey) + 1e-6, nx = -ey / el * hw, ny = ex / el * hw;
        u.poly([[a[0] + nx, a[1] + ny], [b[0] + nx, b[1] + ny], [b[0] - nx, b[1] - ny], [a[0] - nx, a[1] - ny]], c >= 0 ? D.tail : D.tailBack);
      }
      u.poly([[kx, ky - kh], [kx - kw, ky], [kx, ky + kh * 1.2]], u.shade(D.kite, 0.22 + lean));    // the lit half
      u.poly([[kx, ky - kh], [kx + kw, ky], [kx, ky + kh * 1.2]], u.shade(D.kite, -0.35 + lean));   // the shadowed half
      u.line(kx, ky - kh, kx, ky + kh * 1.2, "rgba(0,0,0,0.4)", 1);           // the spar: the fold line
      u.label("two flat shades meeting at the spar make a fold; the body is a spring on the wind, the tail a chain — each link follows the one before", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { vy -= u.H * D.gust; vx += u.W * D.gust * 0.5; }   // click = a gust: velocity, not a place — the spring does the rest
  };
});

def("L", "Loop", "wave", "a ribbon tied in a loop-de-loop: quads round a circle, width = |cos| of the angle from the bottom, colour flipping to the back at the top — a car rides the inside, fast through the bottom and slow over the crown, its speed traded for height", function make(u) {
  var D = { sky: ["#6FA8E8", "#CFE6F5"], front: "#F5C169", back: "#8A5A2A", car: "#D82A2A",
            segs: 72, width: 0.11, radius: 0.3,
            carSpeed: 1.2,             // the car's angular speed at the bottom of the loop, rad/s — negative runs it backwards
            gravity: 0.3,              // the pull that trades speed for height, in (rad/s)² per loop radius: at the crown v² = carSpeed² − 4·gravity
            minSpeed: 0.25 };          // the car never quite stalls at the crown — a chain lift, rad/s
  // the car's speed is not a dial, it is ENERGY: v² = v₀² − 2·g·h, with h the
  // height above the bottom of the loop (1 − cos of the angle, in radii). so
  // it is fastest through the bottom, slows climbing, crawls over the crown
  // and comes down faster again — and the angle is integrated with that
  // speed each frame rather than read off the clock. a floor keeps it from
  // stalling when the press sets a bottom speed too low to make the top.
  var ca = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var dir = D.carSpeed < 0 ? -1 : 1, w2 = D.carSpeed * D.carSpeed - 2 * D.gravity * (1 - Math.cos(ca));   // v² from the energy left at this height
      ca += dir * Math.sqrt(Math.max(w2, D.minSpeed * D.minSpeed)) * Math.min(dt, 0.05);
      ca = ca - Math.floor(ca / u.TAU) * u.TAU;                              // keep the angle in one turn
      var cx = u.W / 2, R = u.H * D.radius, cy = u.H * 0.5, GY = cy + R, w = u.H * D.width;
      u.ground(GY + 6, "#3A5A3A");
      u.shadow(cx, GY + 8, R * 1.2, R * 0.2, 0.35);
      u.ctx.fillStyle = u.lin(0, GY - w / 2, 0, GY + w / 2, [u.shade(D.front, 0.25), D.front, u.shade(D.front, -0.3)]);   // the flat run: full width, front colour
      u.ctx.fillRect(0, GY - w / 2, u.W, w);
      for (var i = 0; i < D.segs; i++) {
        var a0 = (i / D.segs) * u.TAU, a1 = ((i + 1) / D.segs) * u.TAU, am = (a0 + a1) / 2;   // angle measured from the bottom
        var c = Math.cos(am), hw = Math.abs(c) * w / 2 + 0.6;                 // apparent width: |cos| — edge-on at the sides
        var lit = (-Math.sin(am) - c) * 0.18;                                // pale where the surface faces up-left
        var s0 = Math.sin(a0), c0 = Math.cos(a0), s1 = Math.sin(a1), c1 = Math.cos(a1);
        u.poly([[cx + s0 * (R - hw), cy + c0 * (R - hw)], [cx + s1 * (R - hw), cy + c1 * (R - hw)],
                [cx + s1 * (R + hw), cy + c1 * (R + hw)], [cx + s0 * (R + hw), cy + c0 * (R + hw)]],
               u.shade(c >= 0 ? D.front : D.back, u.clamp(lit, -0.4, 0.4))); // cos < 0 (the top half) shows the back
      }
      var cr = w * 0.35, cw = Math.abs(Math.cos(ca)) * w / 2 + 0.6;           // the car hugs the inside of the track
      u.sphere(cx + Math.sin(ca) * (R - cw - cr), cy + Math.cos(ca) * (R - cw - cr), cr, D.car, -0.5, -0.5, { spec: 0.5 });
      u.label("the |cos| rule bent into a circle — front at the bottom, back at the top, edge-on at the sides; the car's speed is √(v₀² − 2g·h)", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.carSpeed = (x / u.W - 0.5) * 5; }            // click left of centre = the car runs backwards; near the centre it barely makes the crown
  };
});

def("O", "Ocean", "wave", "seven rows of travelling sines from horizon to foreground — spacing bunches toward the horizon, far rows fog into the sky, crests pale, troughs dark", function make(u) {
  var D = { sky: ["#8FB8E0", "#D9E8F5"], sea: "#1E5A8F", air: "#C8DCEE", foam: "#F0F6FF",
            rows: 7, wind: 1.0, horizon: 0.38, step: 4 };                   // step: px between points along each crest
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var HY = u.H * D.horizon;
      u.ctx.fillStyle = u.fog(D.sea, 0.85, D.air); u.ctx.fillRect(0, HY, u.W, u.H - HY);   // the far sea is nearly air
      for (var i = 0; i < D.rows; i++) {
        var p = (i + 1) / D.rows;                                            // 0 = at the horizon, 1 = at your feet
        var y = HY + p * p * (u.H - HY) * 0.92;                              // horizon + p²: rows bunch toward the horizon
        var amp = (1.5 + p * p * 14) * D.wind, len = u.W * (0.12 + p * 0.4); // near waves: taller, longer, faster
        var ph = t * (0.4 + p * 1.2) * D.wind * 2 + i * 1.7;
        var c = u.fog(D.sea, (1 - p) * 0.8, D.air);                          // far rows mix toward the air
        u.ctx.fillStyle = u.lin(0, y - amp, 0, y + amp * 3, [[0, D.foam], [0.08, u.shade(c, 0.3)], [0.4, c], [1, u.shade(c, -0.35)]]);   // only a crest tip reaches the foam stop
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W + D.step; x += D.step) u.ctx.lineTo(x, y + Math.sin(x / len * u.TAU + ph) * amp);
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      u.label("rows bunch toward the horizon (horizon + p²) and fade into the air; only a crest tip reaches the foam", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = 0.3 + (x / u.W) * 1.9; }             // click right = more wind
  };
});

def("R", "Ribbon", "wave", "a long strip drawn as short quads along a moving sine — its width is |cos(twist)|, and when cos goes negative the BACK colour shows; click to flick the head, and the extra twist runs down the strip as a real wave, reflects off the tail and rings down", function make(u) {
  var D = { sky: ["#1A1030", "#2A1E4A"], front: "#F05A8A", back: "#F5C169",   // the two faces of the strip
            width: 0.1, segs: 64, twists: 2.5, speed: 1.0, step: 0,          // step > 0 snaps the shown clock to 1/step s (jerky)
            k: 2500,                 // the torsion coupling between neighbouring segments: sets how fast a twist travels (√k segments per second)
            damp: 2,                 // each segment's damping, per second — a flick rings for a couple of seconds
            ret: 40,                 // the strip's own stiffness, pulling every segment back to its steady twist
            flick: 160 };            // the angular velocity a click gives the head, radians per second
  var N = Math.max(4, Math.floor(D.segs));
  var ps = new Float32Array(N + 1), om = new Float32Array(N + 1);            // each node's extra twist over the steady spin, and its angular velocity
  var shown = new Float32Array(N + 1), snapAt = -1;                          // the twist the picture shows: the live one, or a snapshot when the clock is stepped
  // the steady twist is a spin along the strip that the clock winds on. on
  // top of it every node carries its OWN extra twist, and the nodes are a
  // torsion chain: each pulled toward both its neighbours (a wave equation),
  // and weakly back to zero by the strip's own stiffness. a click does not
  // draw a bump — it gives the head an angular VELOCITY, and the twist it
  // makes travels down the strip at √k nodes a second, doubles as it reflects
  // off the free tail, and rings down as the damping eats it.
  return {
    frame: function (dt, t) {
      // the chain's top mode rings at 2√k, and a symplectic step holds only while
      // √k·h < 1 — so a coarse frame is cut into substeps of at most 1/60 s
      var sub = Math.max(1, Math.ceil(dt * 60)), h = dt / sub;
      for (var st = 0; st < sub; st++) {
        for (var n = 0; n <= N; n++) {
          var f = -D.ret * ps[n];                                            // the strip's own stiffness: back toward the steady twist
          if (n > 0) f += D.k * (ps[n - 1] - ps[n]);                         // pulled toward the node before …
          if (n < N) f += D.k * (ps[n + 1] - ps[n]);                         // … and after; the tail has none, and swings double
          om[n] += (f - D.damp * om[n]) * h;
        }
        for (var n2 = 0; n2 <= N; n2++) ps[n2] = u.clamp(ps[n2] + om[n2] * h, -6, 6);
      }
      var tt = t, live = ps;
      if (D.step) {                                                          // a stepped clock: the picture only refreshes 1/step s, physics runs on
        tt = Math.floor(t * D.step) / D.step;
        if (tt !== snapAt) { snapAt = tt; shown.set(ps); }
        live = shown;
      }
      u.sky(D.sky);
      var w = u.H * D.width, px = [], py = [], tw = [];
      for (var i = 0; i <= N; i++) {
        var k = i / N;
        px.push(u.W * (-0.04 + k * 1.08));
        py.push(u.H * (0.48 + 0.2 * Math.sin(k * u.TAU * 1.2 - tt * D.speed * 1.4) + 0.06 * Math.sin(k * u.TAU * 2.7 + tt * D.speed * 0.9)));
        tw.push(k * u.TAU * D.twists - tt * D.speed * 2 + live[i]);         // the steady spin plus this node's own extra twist
      }
      for (var j = 0; j < N; j++) {
        var c = Math.cos((tw[j] + tw[j + 1]) / 2);                           // the twist, seen edge-on at cos = 0
        var hw = Math.abs(c) * w / 2 + 0.6;                                  // apparent half-width: |cos|
        var dx = px[j + 1] - px[j], dy = py[j + 1] - py[j], len = Math.sqrt(dx * dx + dy * dy) + 1e-6;
        var lit = ((dx - dy) / len - 0.7) * 0.5;                             // slope → shade: pale where it faces up-left
        u.poly([[px[j], py[j] - hw], [px[j + 1], py[j + 1] - hw], [px[j + 1], py[j + 1] + hw], [px[j], py[j] + hw]],
               u.shade(c >= 0 ? D.front : D.back, u.clamp(lit, -0.4, 0.4))); // the sign of cos picks the face
      }
      u.label("width = |cos(twist)|; cos < 0 shows the back · twist: ψₙ'' = k(ψₙ₋₁ − 2ψₙ + ψₙ₊₁) − ret·ψₙ − damp·ψₙ' · click: ψ₀' += flick", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { om[0] += D.flick; }                            // click = flick the head: a kick of angular velocity, never a jump in twist
  };
});

def("T", "Tide", "wave", "waves lapping a beach: three rows whose front edge advances and retreats on a slow sine — the sand stays dark where the last wave reached, and dries", function make(u) {
  var D = { sky: ["#8FB8E0", "#D9E8F5"], sea: "#1E6A9A", shallow: "#7AC8D8", sand: "#E0C890", wet: "#7A5A30", foam: "#FFFFFF",
            rows: 3, tide: 0.5, dry: 6, cols: 48, moon: 0 };                // dry: seconds for wet sand to fade back
  var wet = [], wetT = [];
  for (var c = 0; c < D.cols; c++) { wet.push(0); wetT.push(-99); }
  var surgeAt = -99, lastT = 0;
  function edgeAt(x, r, reach, t) {                                          // the front edge of row r at column x
    return reach + Math.sin(x / u.W * u.TAU * 1.5 - t * 1.2 + r * 1.1) * u.H * 0.03;
  }
  return {
    frame: function (dt, t) {
      lastT = t;
      u.sky(D.sky);
      var HY = u.H * 0.3;
      if (D.moon) u.dot(u.W * 0.75, u.H * 0.12, u.W * 0.035, "#F0EEFF");
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.shade(D.sand, 0.1), u.shade(D.sand, -0.2)]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      var reach = u.H * (0.5 + 0.22 * Math.sin(t * D.tide) + 0.15 * Math.exp(-(t - surgeAt) * 1.5));   // the front's base: in, out, and a click's surge
      var cw = u.W / D.cols;
      for (var i = 0; i < D.cols; i++) {                                     // wet sand: each column remembers the last reach, and when
        var edge = edgeAt((i + 0.5) * cw, D.rows - 1, reach, t);
        if (edge >= wet[i]) { wet[i] = edge; wetT[i] = t; }
        var dark = u.clamp(1 - (t - wetT[i]) / D.dry, 0, 1) * 0.55;         // dries over D.dry seconds
        u.ctx.fillStyle = u.rgba(D.wet, dark);
        u.ctx.fillRect(i * cw, HY, cw + 1, wet[i] - HY);
      }
      for (var r = 0; r < D.rows; r++) {
        var p = (r + 1) / D.rows, base = HY + (reach - HY) * (0.45 + 0.55 * p);   // the last row's edge is the reach itself
        u.ctx.fillStyle = u.rgba(u.mix(D.sea, D.shallow, p), r === 0 ? 1 : 0.55);   // thin water lets the wet sand through
        u.ctx.beginPath(); u.ctx.moveTo(0, HY);
        for (var x = 0; x <= u.W + 6; x += 6) u.ctx.lineTo(x, edgeAt(x, r, base, t));
        u.ctx.lineTo(u.W, HY); u.ctx.closePath(); u.ctx.fill();
        u.ctx.strokeStyle = u.rgba(D.foam, 0.3 + p * 0.5); u.ctx.lineWidth = 1 + p;   // the foam line
        u.ctx.beginPath();
        for (var x2 = 0; x2 <= u.W + 6; x2 += 6) u.ctx.lineTo(x2, edgeAt(x2, r, base, t));
        u.ctx.stroke();
      }
      u.label("the edge is a slow sine over a fast one; the sand remembers the last reach and dries — time as a gradient", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { surgeAt = lastT; }                             // click = one big wave
  };
});

def("U", "Undertow", "wave", "under the surface: caustic stripes wobbling in the light, seaweed at three depths — far ones paler, slower — each weed a chain of springs the current bends from the root, so the tips lag and whip through — and bubbles rising faster the nearer they are", function make(u) {
  var D = { water: ["#1A6A9A", "#052040"], air: "#2A6A9A", weed: "#2A8A4A", light: "#B8F0FF", bubble: "#E8F8FF",
            depths: 3, weeds: 4, bubbles: 22, glow: 0,
            sway: 1.0,               // the current's strength: scales the lean the root's rest is bent to (a press moves this, never the weed)
            k: 40,                   // the root spring's stiffness (per inertia): a weed rights itself in about a second
            damp: 6,                 // its damping (2√k = 12.6 would be critical): well under, so the root overshoots
            tip: 1.25,               // each segment's k as a multiple of the one below — lighter up the weed, so the same bend rights it faster
            tipdamp: 0.6,            // a segment's damping as a fraction of ITS OWN critical: under 1, so the tip overshoots the root and whips through
            lean: 0.45 };            // radians the current asks of the root at sway 1
  var R = u.rng(7), weeds = [], bubbles = [], SEG = 9;                       // SEG: segments per weed, root to tip
  for (var d = 0; d < D.depths; d++)                                         // far layer first: painter's order for free
    for (var w = 0; w < D.weeds; w++) weeds.push({ x: R() * u.W, z: (d + 0.5) / D.depths, h: 0.28 + R() * 0.3, ph: R() * 9 });
  for (var b = 0; b < D.bubbles; b++) bubbles.push({ x: R() * u.W, y: R(), z: R(), ph: R() * 9 });
  var th = new Float32Array(weeds.length * SEG), om = new Float32Array(weeds.length * SEG);   // segment angles from vertical + angular velocities, weed-major
  // a weed is a CHAIN of angles from vertical, one per segment — the stagecraft
  // Grass, under water. the root is a damped spring toward a rest the CURRENT
  // sets: two slow sines, slower for the far weeds, scaled by sway. every
  // segment above is the same spring again, its rest the angle of the segment
  // below, quicker (k · tip: a lighter segment, same bend) and less damped
  // (tipdamp of its own critical) — so when the current turns, the root goes
  // first, the tip follows late and whips through when the current comes back.
  // a press moves the rest; the weed has to get there by itself.
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      // the segments up a weed are stiffer than the root (k · tip each), and a
      // symplectic step holds only while √k·h < 2 — so a coarse frame is cut into
      // substeps of at most 0.02 s; at 60 fps that is one step
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      for (var j = 0; j < weeds.length; j++) {
        var s = weeds[j], sp = 0.6 + s.z * 0.8;                              // far weed: a slower current
        var rest = D.lean * D.sway * (0.6 * Math.sin(t * sp * 0.9 + s.ph) + 0.4 * Math.sin(t * sp * 0.37 + s.ph * 2));
        for (var st = 0; st < sub; st++) {
          var below = rest, kj = D.k, dj = D.damp;                           // the root chases the current; each segment chases the one below
          for (var g = 0; g < SEG; g++) {
            var i = j * SEG + g;
            om[i] += (kj * (below - th[i]) - dj * om[i]) * h;
            th[i] = u.clamp(th[i] + om[i] * h, -1.4, 1.4);
            below = th[i]; kj *= D.tip; dj = D.tipdamp * 2 * Math.sqrt(kj);   // the next segment up: quicker, and a fraction of ITS critical
          }
        }
      }
      u.sky(D.water);
      u.soft(u.W * 0.5, -u.H * 0.2, u.H * 0.8, D.light, 0.25);               // the surface, lit from above
      for (var c0 = 0; c0 < 7; c0++) {                                       // caustics: bright stripes that wobble
        u.ctx.strokeStyle = u.rgba(D.light, 0.35 * (1 - c0 / 7)); u.ctx.lineWidth = 1.5;
        u.ctx.beginPath();
        for (var x = 0; x <= u.W; x += 8) u.ctx.lineTo(x, u.H * (0.04 + c0 * 0.05) + Math.sin(x * 0.04 + t * 1.5 + c0) * 3 + Math.sin(x * 0.011 - t * 0.9 + c0 * 2) * 5);
        u.ctx.stroke();
      }
      var GY = u.H * 0.9;
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.fog("#4A3A2A", 0.5, D.air), "#2A1A10"]); u.ctx.fillRect(0, GY, u.W, u.H - GY);
      for (var j2 = 0; j2 < weeds.length; j2++) {                            // seaweed: walk the chain, a quad per segment, shaded by its lean
        var s2 = weeds[j2], z = s2.z, hgt = u.H * s2.h * (0.5 + z * 0.6), base = GY - (1 - z) * u.H * 0.05, seg = hgt / SEG;
        var c = u.fog(D.weed, (1 - z) * 0.75, D.air), px = s2.x, py = base;
        for (var k = 0; k < SEG; k++) {
          var q = (k + 1) / SEG, a = th[j2 * SEG + k];
          var nx = px + Math.sin(a) * seg, ny = py - Math.cos(a) * seg, hw = (1 - q * 0.7) * (2 + z * 5);
          u.poly([[px - hw, py], [nx - hw, ny], [nx + hw, ny], [px + hw, py]], u.shade(c, Math.sin(a) * 0.3));   // the lean is the slope: pale when leaning into the light
          px = nx; py = ny;
        }
      }
      for (var m = 0; m < bubbles.length; m++) {
        var o = bubbles[m], zz = o.z, yy = (((o.y - t * (0.04 + zz * 0.12)) % 1) + 1) % 1 * u.H;   // near bubbles rise faster
        var xx = o.x + Math.sin(t * 2 + o.ph) * (2 + zz * 4), r = 1 + zz * 3;
        if (D.glow) u.soft(xx, yy, r * 4, D.bubble, 0.4);
        u.ctx.strokeStyle = u.rgba(D.bubble, 0.25 + zz * 0.5); u.ctx.lineWidth = 0.8;
        u.ctx.beginPath(); u.ctx.arc(xx, yy, r, 0, u.TAU); u.ctx.stroke();
        u.dot(xx - r * 0.35, yy - r * 0.35, r * 0.3, u.rgba(D.bubble, 0.4 + zz * 0.5));   // one bright spot: a sphere in two marks
      }
      u.label("root: θ'' = k·(current − θ) − damp·θ' · segment j: kⱼ = tip·kⱼ₋₁ chasing θⱼ₋₁ · far weed paler and slower, near bubbles bigger and faster", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.sway = 0.2 + (x / u.W) * 2.5; }              // click right = a stronger current — the rest moves, the weed catches up
  };
});

def("W", "Wake", "wave", "a boat crossing rows of receding sea, trailing a V of ripples — every ring is dropped where the stern was and grows from there, older ones wider and fainter, squashed flat by perspective; the hull rides the swell on a spring, pitching with its heave — click right = faster boat, and the rings already dropped stay put", function make(u) {
  var D = { sky: ["#6FA8E8", "#CFE6F5"], sea: "#1E5A8F", air: "#C8DCEE", hull: "#2A1E1A", sail: "#F5F0E0",
            rows: 6,
            rings: 32,                 // how many rings are kept alive — the oldest is recycled when a new one drops
            speed: 1.0,                // the boat's speed: 1 = 0.18 screens per second
            spread: 0.45,              // how fast a ring grows, as a share of the boat's speed at speed 1 — the V's half-angle is atan(spread / speed)
            drop: 0.08,                // seconds between rings
            life: 2.4,                 // seconds a ring lives, growing and fading the whole time
            k: 36, damp: 0.35,         // the hull's heave spring toward the water under it: stiffness, and damping as a fraction of critical (2√k)
            pitchK: 25, pitchDamp: 0.3,   // the pitch spring, whose rest is the heave velocity × pitchGain — the bow lifts as the hull rises
            pitchGain: 0.004 };        // radians of pitch per px/s of heave
  // the wake is a MEMORY: every `drop` seconds the stern leaves a ring on the
  // water, and from then on the ring is on its own — radius and alpha come from
  // its age, nothing else. the boat never looks back to draw them, so when it
  // wraps to the left edge, or a press changes its speed, the rings already
  // dropped stay exactly where they were. the V is only their envelope: the
  // tangent through the stern, whose slope is ring growth over boat speed.
  // the hull is a damped spring toward the water height under it (the same
  // sine the boat's sea row draws), and the pitch is a second spring whose
  // rest is the heave velocity — so the bow lifts as the hull rises and the
  // hull overshoots each crest a little, because both are under-damped.
  var cap = Math.max(1, Math.floor(D.rings));
  var rx = new Float32Array(cap), ry = new Float32Array(cap), rborn = new Float32Array(cap), head = 0, count = 0, since = 0;
  var BY = u.H * 0.62, bx = -u.W * 0.25, by = BY, vy = 0, pitch = 0, pv = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var HY = u.H * 0.32;                                                   // the horizon; BY is the boat's row
      u.ctx.fillStyle = u.fog(D.sea, 0.85, D.air); u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (var i = 0; i < D.rows; i++) {                                     // the sea recedes: rows bunch toward the horizon
        var p = (i + 1) / D.rows, y = HY + p * p * (u.H - HY) * 0.9, amp = 1 + p * p * 5, len = u.W * (0.15 + p * 0.35);
        var c = u.fog(D.sea, (1 - p) * 0.8, D.air);
        u.ctx.fillStyle = u.lin(0, y - amp, 0, y + amp * 3, [u.shade(c, 0.25), c, u.shade(c, -0.3)]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W + 6; x += 6) u.ctx.lineTo(x, y + Math.sin(x / len * u.TAU + t * (0.5 + p) + i) * amp);
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      var s = u.W * 0.004, v = D.speed * u.W * 0.18, grow = D.spread * u.W * 0.18;   // px/s: the boat, and a ring's radius
      bx += v * dt;
      if (bx > u.W * 1.25) bx -= u.W * 1.5;                                  // the boat wraps; the rings it dropped do not
      var ri = Math.max(0, D.rows - 3), rp = (ri + 1) / D.rows, ramp = 1 + rp * rp * 5, rlen = u.W * (0.15 + rp * 0.35);   // the boat's sea row
      var ph = bx / rlen * u.TAU + t * (0.5 + rp) + ri, water = BY + Math.sin(ph) * ramp;   // the water under the hull, this frame
      // symplectic euler is stable while √k·h < 2 — a coarse frame is cut into substeps of at most 0.02 s
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, damp = D.damp * 2 * Math.sqrt(D.k), pdamp = D.pitchDamp * 2 * Math.sqrt(D.pitchK);
      for (var q = 0; q < sub; q++) {
        vy += (D.k * (water - by) - damp * vy) * h; by += vy * h;            // heave: chase the water
        var prest = u.clamp(vy * D.pitchGain, -0.3, 0.3);                    // pitch: chase the heave velocity — rising = bow up
        pv += (D.pitchK * (prest - pitch) - pdamp * pv) * h; pitch = u.clamp(pitch + pv * h, -0.5, 0.5);
      }
      by = u.clamp(by, BY - u.H * 0.2, BY + u.H * 0.2);
      since += dt;
      var drop = Math.max(0.01, D.drop);
      while (since >= drop) {                                                // drop a ring where the stern is now (it is `since` seconds old already)
        since -= drop;
        rx[head] = bx - 16 * s; ry[head] = water; rborn[head] = t - since;
        head = (head + 1) % cap; count = Math.min(count + 1, cap);
      }
      for (var j = 0; j < count; j++) {                                      // oldest rings first
        var idx = (head - count + j + cap) % cap, age = t - rborn[idx];
        if (age < 0 || age > D.life) continue;
        var r = grow * age, fade = 1 - age / D.life;                         // each ring has grown since it was dropped, and faded
        u.ctx.strokeStyle = u.rgba("#FFFFFF", fade * 0.55); u.ctx.lineWidth = 1 + fade * 1.2;
        u.ctx.beginPath(); u.ctx.ellipse(rx[idx], ry[idx], r, r * 0.3, 0, 0, u.TAU); u.ctx.stroke();   // squashed: we see the water at a low angle
      }
      var L = v * D.life, A = grow * D.life * 0.3;                           // the envelope: where the oldest living ring is, and how wide it has grown (squashed)
      u.ctx.strokeStyle = u.lin(bx, 0, bx - L, 0, [u.rgba("#FFFFFF", 0.6), u.rgba("#FFFFFF", 0)]); u.ctx.lineWidth = 1;   // the V's arms fade with distance
      u.ctx.beginPath(); u.ctx.moveTo(bx, by); u.ctx.lineTo(bx - L, by - A); u.ctx.moveTo(bx, by); u.ctx.lineTo(bx - L, by + A); u.ctx.stroke();
      u.ctx.save(); u.ctx.translate(bx, by); u.ctx.rotate(pitch);            // the hull: heaved and pitched by the springs
      u.soft(-16 * s, 0, 8 * s, "#FFFFFF", 0.6);                             // foam at the stern
      u.poly([[-18 * s, -5 * s], [20 * s, -5 * s], [14 * s, 5 * s], [-13 * s, 5 * s]], D.hull);
      u.line(0, -5 * s, 0, -40 * s, D.hull, 1);
      u.ctx.fillStyle = u.lin(0, 0, 22 * s, 0, [u.shade(D.sail, 0.1), D.sail, u.shade(D.sail, -0.3)]);   // the sail bellies: light → dark across it
      u.poly([[s, -38 * s], [s, -7 * s], [22 * s, -7 * s]], u.ctx.fillStyle);
      u.ctx.restore();
      u.label("each ring is a stored (x, y, born): it grows at one rate while the boat runs on — the V is their envelope, angle = ring growth ÷ boat speed", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.speed = 0.3 + (x / u.W) * 2; }              // click right = faster boat — the rings already dropped stay where they are
  };
});

def("X", "Xebec", "wave", "a ship with lateen sails: each triangle filled dark → light across its width reads as a bellied curve — the hull rides the swell under it on a spring, rolls to the water's slope on another, and the sails fill and slacken on a third that chases the roll and overshoots; the sea recedes behind — click right = a stiffer wind", function make(u) {
  var D = { sky: ["#F5C169", "#F5E1B0", "#8FB8E0"], sea: "#2A5A8A", air: "#E8D8B8", hull: "#4A2A1A", sail: "#F0E6D0",
            rows: 6,
            belly: 1.0,                // the belly the wind asks for — the sails' spring chases it
            alpha: 1,                  // how solid the ship is
            k: 16, damp: 0.4,          // the hull's heave spring toward the water under it: stiffness, and damping as a fraction of critical (2√k)
            rollK: 12, rollDamp: 0.35, // the roll spring — its rest is the water's slope under the hull × rollGain
            rollGain: 0.35,            // radians of roll per unit of slope (dy/dx)
            sailK: 25, sailDamp: 0.25, // the sails' belly spring, chasing the hull's roll — less damped, so the rig lags and overshoots at the top of each roll
            sailGain: 3 };             // how much a radian of roll swells (or slackens) the belly
  // three springs, each chasing the one before. the hull chases the water
  // height under it — the same sine its sea row draws — and overshoots each
  // crest a little (damp < 1). the roll chases the water's SLOPE there, so
  // the ship leans down the face of each swell and rights itself past
  // vertical. the sails chase the roll on a looser spring: they fill as the
  // hull rolls toward the wind, lag behind it, and swell past the rest at
  // the top of the roll — the rig is the last thing to settle. a press moves
  // the belly's target; the sails take their own time getting there.
  var ri = Math.max(0, D.rows - 3), rp = (ri + 1) / D.rows, ramp = 1 + rp * rp * 5, rlen = u.W * (0.15 + rp * 0.35);   // the ship's sea row
  var SY = u.H * 0.66, sy = SY, vy = 0, roll = 0, rv = 0, bel = D.belly * 0.85, bv = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[2]], [0.6, D.sky[1]], [1, D.sky[0]]]);
      var HY = u.H * 0.45, s = u.W * 0.0045, sx = u.W * 0.5;
      u.soft(u.W * 0.7, HY, u.W * 0.3, D.sky[0], 0.5);                       // a low sun behind the ship
      u.ctx.fillStyle = u.fog(D.sea, 0.85, D.air); u.ctx.fillRect(0, HY, u.W, u.H - HY);
      var ph = sx / rlen * u.TAU - t * (0.5 + rp) + ri;                       // the water under the hull: its height, and its slope
      var water = SY + Math.sin(ph) * ramp, slope = Math.cos(ph) * ramp * u.TAU / rlen;
      // symplectic euler is stable while √k·h < 2 — a coarse frame is cut into substeps of at most 0.02 s
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      var damp = D.damp * 2 * Math.sqrt(D.k), rdamp = D.rollDamp * 2 * Math.sqrt(D.rollK), sdamp = D.sailDamp * 2 * Math.sqrt(D.sailK);
      for (var q = 0; q < sub; q++) {
        vy += (D.k * (water - sy) - damp * vy) * h; sy += vy * h;            // heave: chase the water height
        var rrest = u.clamp(slope * D.rollGain, -0.4, 0.4);                  // roll: chase the water's slope
        rv += (D.rollK * (rrest - roll) - rdamp * rv) * h; roll = u.clamp(roll + rv * h, -0.6, 0.6);
        var brest = D.belly * (0.85 + D.sailGain * roll);                    // belly: chase the roll, on the loosest spring
        bv += (D.sailK * (brest - bel) - sdamp * bv) * h; bel = u.clamp(bel + bv * h, 0.05, 3);
      }
      sy = u.clamp(sy, SY - u.H * 0.2, SY + u.H * 0.2);
      function row(i) {                                                       // one row of sea, bunching toward the horizon
        var p = (i + 1) / D.rows, y = HY + p * p * (u.H - HY) * 0.9, amp = 1 + p * p * 5, len = u.W * (0.15 + p * 0.35);
        var c = u.fog(D.sea, (1 - p) * 0.8, D.air);
        u.ctx.fillStyle = u.lin(0, y - amp, 0, y + amp * 3, [u.shade(c, 0.25), c, u.shade(c, -0.3)]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W + 6; x += 6) u.ctx.lineTo(x, y + Math.sin(x / len * u.TAU - t * (0.5 + p) + i) * amp);
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      function sail(mx, size) {                                               // a lateen sail: yard slanting low-forward to high-aft
        var ax = mx - size * 0.45, ay = -size * 1.05, fx = mx + size * 0.45, fy = -size * 0.35, cx = mx - size * 0.4, cy = -size * 0.12;
        var breathe = bel;                                                    // the sail's fill is the sprung belly
        u.ctx.fillStyle = u.lin(ax, 0, fx, 0, [[0, u.shade(D.sail, -0.35)], [u.clamp(0.45 + breathe * 0.15, 0.01, 0.99), u.shade(D.sail, -0.05)], [1, u.shade(D.sail, 0.15)]]);   // dark at the yard, light on the belly
        u.ctx.beginPath(); u.ctx.moveTo(ax, ay); u.ctx.lineTo(fx, fy);
        u.ctx.quadraticCurveTo((fx + cx) / 2 + size * 0.25 * breathe, (fy + cy) / 2 + size * 0.1, cx, cy); u.ctx.closePath(); u.ctx.fill();
        u.line(ax, ay, fx, fy, u.shade(D.hull, -0.3), 1.5);                  // the yard
        u.line(mx, -6 * s, mx, -size, u.shade(D.hull, -0.3), 1.5);           // the mast
      }
      for (var i = 0; i < D.rows - 1; i++) row(i);                            // far rows first
      u.ctx.save(); u.ctx.translate(sx, sy); u.ctx.rotate(roll); u.ctx.globalAlpha = D.alpha;   // the hull: heaved and rolled by its springs
      sail(-2 * s, 58 * s); sail(28 * s, 42 * s);
      u.ctx.fillStyle = u.lin(0, -8 * s, 0, 6 * s, [u.shade(D.hull, 0.2), u.shade(D.hull, -0.4)]);   // dark at the waterline
      u.poly([[-40 * s, -6 * s], [44 * s, -9 * s], [36 * s, 6 * s], [-34 * s, 6 * s]], u.ctx.fillStyle);
      u.ctx.restore();
      row(D.rows - 1);                                                        // the nearest row in front of the hull
      u.label("a sideways gradient bends a triangle into a sail; hull chases the swell, roll chases its slope, the rig chases the roll — three springs", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.belly = 0.3 + (x / u.W) * 1.5; }             // click right = a stiffer wind — it moves the belly's target, and the sails' spring follows
  };
});

def("Y", "Yacht", "wave", "a yacht heeling in the wind: one tall triangle shaded across its width as a curved sail, the whole boat rotated by the heel — the heel is an under-damped spring, so a tack swings past upright and settles back, and the hull rides its row's swell on another; rows of sea behind and in front — click = tack", function make(u) {
  var D = { sky: ["#3A7FD0", "#B8D8F5"], sea: "#1E5A8F", air: "#C8DCEE", hull: "#F5F0E0", sail: "#FFFFFF", trim: "#D82A2A",
            rows: 6, boats: 1,
            heel: 0.22,                // radians of lean the wind asks for
            speed: 1.0,
            k: 16, damp: 0.35,         // the heel spring: ω = √k ≈ 4 rad/s, and damping as a fraction of critical (2√k) — under 1, so a tack overshoots
            slopeGain: 0.25,            // radians of extra heel per unit of the water's slope under the hull — the swell rocks the boat
            bobK: 30, bobDamp: 0.4 };  // the hull's heave spring toward the water under it
  // the heel is a damped spring toward heel·dir plus the slope of the water
  // under the hull. a tack flips the TARGET, never the angle: the boat swings
  // through upright, overshoots the new side by a third (ζ ≈ 0.35), and
  // settles in about two seconds — the follow-through is what sells the
  // weight of the boat. the hull's height is a second spring chasing the
  // water under it, so it lifts a beat after each crest. every boat keeps
  // its own state, so in a fleet no two are at the same point of the swing.
  var HY = u.H * 0.4, n = Math.max(1, Math.floor(D.boats)), dir = 1;
  var th = new Float32Array(n), om = new Float32Array(n), by = new Float32Array(n), vy = new Float32Array(n);
  var rowOf = [], bx = [], rowY = [], rowP = [], rowAmp = [], rowLen = [];
  for (var b = 0; b < n; b++) {                                              // which row each boat sits on, and where — fixed for the card's life
    rowOf[b] = n === 1 ? D.rows - 2 : Math.round(1 + (b / (n - 1)) * (D.rows - 3));
    rowP[b] = (rowOf[b] + 1) / D.rows; rowY[b] = HY + rowP[b] * rowP[b] * (u.H - HY) * 0.9;
    rowAmp[b] = 1 + rowP[b] * rowP[b] * 5; rowLen[b] = u.W * (0.15 + rowP[b] * 0.35);
    bx[b] = u.W * (0.5 + (b - (n - 1) / 2) * 0.3); th[b] = D.heel; by[b] = rowY[b] - 2;
  }
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      // symplectic euler is stable while √k·h < 2 — a coarse frame is cut into substeps of at most 0.02 s
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, damp = D.damp * 2 * Math.sqrt(D.k), bdamp = D.bobDamp * 2 * Math.sqrt(D.bobK);
      for (var b = 0; b < n; b++) {
        var ph = bx[b] / rowLen[b] * u.TAU - t * (0.5 + rowP[b]) * D.speed + rowOf[b];   // the water under this hull: height and slope
        var water = rowY[b] - 2 + Math.sin(ph) * rowAmp[b], slope = Math.cos(ph) * rowAmp[b] * u.TAU / rowLen[b];
        var rest = D.heel * dir + u.clamp(slope * D.slopeGain, -0.3, 0.3);   // the wind's side, plus the swell's tilt
        for (var q = 0; q < sub; q++) {
          om[b] += (D.k * (rest - th[b]) - damp * om[b]) * h; th[b] = u.clamp(th[b] + om[b] * h, -1.2, 1.2);
          vy[b] += (D.bobK * (water - by[b]) - bdamp * vy[b]) * h; by[b] += vy[b] * h;
        }
        by[b] = u.clamp(by[b], rowY[b] - u.H * 0.15, rowY[b] + u.H * 0.15);
      }
      u.ctx.fillStyle = u.fog(D.sea, 0.85, D.air); u.ctx.fillRect(0, HY, u.W, u.H - HY);
      function boat(x, y, z, angle) {                                         // z: 0 far … 1 near — size and fog follow it
        var s = u.W * 0.0045 * (0.3 + z * 0.7), hull = u.fog(D.hull, (1 - z) * 0.6, D.air), sail = u.fog(D.sail, (1 - z) * 0.6, D.air);
        u.ctx.save(); u.ctx.translate(x, y); u.ctx.rotate(angle); u.ctx.scale(dir, 1);   // the sprung heel, and a mirror for the wind's side
        u.poly([[-24 * s, -5 * s], [26 * s, -6 * s], [20 * s, 6 * s], [-20 * s, 6 * s]], hull);
        u.poly([[-23 * s, 1 * s], [24 * s, 1 * s], [20 * s, 6 * s], [-20 * s, 6 * s]], u.fog(D.trim, (1 - z) * 0.6, D.air));   // the stripe at the waterline
        u.line(0, -5 * s, 0, -70 * s, "rgba(0,0,0,0.5)", 1);
        u.ctx.fillStyle = u.lin(0, 0, -32 * s, 0, [[0, u.shade(sail, -0.3)], [0.55, u.shade(sail, -0.08)], [1, sail]]);   // dark at the mast, light where the belly faces the light
        u.ctx.beginPath(); u.ctx.moveTo(0, -68 * s); u.ctx.lineTo(0, -8 * s); u.ctx.lineTo(-32 * s, -8 * s);
        u.ctx.quadraticCurveTo(-28 * s, -40 * s, 0, -68 * s); u.ctx.fill();   // the leech bows outward: the belly
        u.ctx.fillStyle = u.lin(0, 0, 26 * s, 0, [u.shade(sail, -0.2), sail]);
        u.poly([[1 * s, -56 * s], [26 * s, -7 * s], [0, -16 * s]], u.ctx.fillStyle);   // the jib
        u.ctx.restore();
      }
      for (var i = 0; i < D.rows; i++) {                                     // rows far → near, each boat painted right after its row
        var p = (i + 1) / D.rows, y = HY + p * p * (u.H - HY) * 0.9, amp = 1 + p * p * 5, len = u.W * (0.15 + p * 0.35);
        var c = u.fog(D.sea, (1 - p) * 0.8, D.air);
        u.ctx.fillStyle = u.lin(0, y - amp, 0, y + amp * 3, [u.shade(c, 0.25), c, u.shade(c, -0.3)]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W + 6; x += 6) u.ctx.lineTo(x, y + Math.sin(x / len * u.TAU - t * (0.5 + p) * D.speed + i) * amp);
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
        for (var k = 0; k < n; k++) if (rowOf[k] === i) boat(bx[k], by[k], p, th[k]);
      }
      u.label("a triangle with a gradient across it is a sail; the heel is one rotate on a spring — a tack swings past and settles; rows behind, boat, rows in front", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { dir = -dir; }                                   // click = the wind changes sides; the target flips, the spring does the tack
  };
});

def("Z", "Zephyr", "wave", "the wind made visible: three translucent ribbons streaming across on long sine paths, twisting (width by |cos|) and fading toward their tails — leaves chase the same paths on a spring, so they lag each crest, overshoot it, and spin as fast as they are thrown", function make(u) {
  var D = { sky: ["#8FB8E0", "#E8F0F8"], ribbon: "#FFFFFF", back: "#B8D8F5", leaf: "#7AB85A",
            ribbons: 3, leaves: 6, speed: 1.0, len: 0.8, segs: 40,          // len: ribbon length as a share of W
            k: 40,                   // a leaf's spring toward the ribbon's height at its x: light, so it takes ~0.2 s to answer
            damp: 5,                 // its damping (2√k = 12.6 would be critical): well under, so a leaf overshoots every crest
            spin: 8 };               // radians of spin per screen-width of travel — the leaf turns as fast as it is thrown
  var R = u.rng(17), paths = [], leaves = [];
  for (var i = 0; i < D.ribbons; i++) paths.push({ y: 0.22 + i * 0.24, amp: 0.05 + R() * 0.05, f: 1 + R() * 1.2, off: R() * 4, sp: 0.8 + R() * 0.4 });
  for (var l = 0; l < D.leaves; l++) leaves.push({ p: l % D.ribbons, s: 0.1 + R() * 0.6, spin: R() * 9, y: -1, vy: 0, rot: 0, px: -1e9 });   // y, vy, rot: the leaf's state; px: last x, to spot a wrap
  function pathY(p, x, t) { return u.H * (p.y + p.amp * Math.sin(x / u.W * p.f * u.TAU - t * 1.5 * p.sp)); }
  // the ribbon is the wind's path, y(x). a leaf is not ON it: it is carried
  // along in x at the wind's speed, and in y it is a damped spring chasing
  // the ribbon's height at its x — so it lags every crest and overshoots it,
  // more the faster the wind (a press moves the wind; the leaf catches up).
  // its spin is integrated from how fast it is being thrown, sideways and
  // up-down, not read off the clock: a leaf at rest in still air would stop.
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ground(u.H * 0.9, "#5A8A5A");
      var len = u.W * D.len, w = u.H * 0.05;
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;               // substeps of at most 0.02 s keep the leaf springs stable on a coarse frame
      for (var i = 0; i < paths.length; i++) {
        var p = paths[i], head = ((t * D.speed * u.W * 0.35 * p.sp + p.off * u.W) % (u.W + len));   // the head crosses, then wraps
        for (var j = 0; j < D.segs; j++) {
          var s0 = j / D.segs, s1 = (j + 1) / D.segs, x0 = head - s0 * len, x1 = head - s1 * len;
          if (x0 < 0 || x1 > u.W) continue;
          var c = Math.cos(s0 * u.TAU * 1.5 + t * 3 + i), hw = Math.abs(c) * w / 2 + 0.4;   // twist: width by |cos|, colour by its sign
          u.poly([[x0, pathY(p, x0, t) - hw], [x1, pathY(p, x1, t) - hw], [x1, pathY(p, x1, t) + hw], [x0, pathY(p, x0, t) + hw]],
                 u.rgba(c >= 0 ? D.ribbon : D.back, (1 - s0) * 0.6));         // fading toward the tail
        }
        for (var k = 0; k < leaves.length; k++) {
          var o = leaves[k];
          if (o.p !== i) continue;
          var lx = head - o.s * len, target = pathY(p, lx, t), vx = D.speed * u.W * 0.35 * p.sp;   // vx: how fast the wind carries it
          if (o.px < -1e8 || lx < o.px - u.W * 0.5) { o.y = target; o.vy = 0; }            // the ribbon wrapped: this is a fresh leaf, starting on the path
          o.px = lx;
          for (var st = 0; st < sub; st++) {
            o.vy += (D.k * (target - o.y) - D.damp * o.vy) * h;              // chase the ribbon's height, under-damped
            o.y = u.clamp(o.y + o.vy * h, -u.H, u.H * 2);
            o.rot += (Math.abs(vx) + Math.abs(o.vy) * 2) / u.W * D.spin * h;   // spin from how fast it is thrown, not from the clock
          }
          if (lx < 0 || lx > u.W) continue;
          u.ctx.save(); u.ctx.translate(lx, o.y); u.ctx.rotate(o.rot + o.spin);
          u.ctx.fillStyle = D.leaf; u.ctx.beginPath(); u.ctx.ellipse(0, 0, u.W * 0.014, u.W * 0.007, 0, 0, u.TAU); u.ctx.fill();
          u.ctx.restore();
        }
      }
      u.label("the ribbon is the wind: alpha fades to the tail, |cos| twists it · leaf: y'' = k·(ribbon(x) − y) − damp·y' · spin' ∝ |vx| + |vy|", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.speed = 0.3 + (x / u.W) * 2.5; }             // click right = a stronger wind — the leaves fall behind, then catch up
  };
});

/* ---- the rhymes: same pictures, two or three dials moved ---- */

rhymeOf("Flag", "Pirate flag", "the same strips in black under a storm sky, a stiffer wind and more ripples — the folds now read from the white band alone", function make(u) {
  // rhyme of Flag: dials moved — cloth/band/sky palette, wind 1.0 → 1.9, waves 1.6 → 2.2
  var D = { sky: ["#2A2A3A", "#6A6A7A"], cloth: "#111118", band: "#E8E5F4", pole: "#5A5A66",
            strips: 16, wind: 1.9, waves: 2.2, shadeBy: 0.45, damp: 0.6, light: 1.1, drive: 0.04, flutter: 1.5 };
  var N = Math.max(4, Math.floor(D.strips));
  var y = new Float32Array(N), v = new Float32Array(N);
  var wv = 0, wvv = 0, fx = 0.5, fv = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var px = u.W * 0.18, top = u.H * 0.16, fw = u.W * 0.58, fh = u.H * 0.34, GY = u.H * 0.86;
      u.ground(GY, "#3A5A3A");
      u.shadow(px + fw * 0.35, GY + 2, fw * 0.45, 5, 0.3);
      u.cyl(px - 3, GY, 6, GY - top + 14, D.pole, -0.3);
      u.sphere(px - 3, top - 16, 5, "#E8C060", -0.5, -0.5);
      var sub = Math.max(1, Math.ceil(dt * 60)), h = dt / sub, kw = 6;
      for (var st = 0; st < sub; st++) {
        wvv += (kw * (D.wind - wv) - 0.9 * 2 * Math.sqrt(kw) * wvv) * h; wv += wvv * h;
        var om = 4 * Math.max(0.05, wv);
        fv += (-om * om * fx + D.flutter * om * (1 - fx * fx) * fv) * h; fx += fv * h;
        var k = Math.pow(N * om / u.TAU / D.waves, 2), inv = 1;
        for (var i = 1; i < N; i++) {
          inv *= D.light;
          var f = k * (y[i - 1] - y[i]);
          if (i + 1 < N) f += k * (y[i + 1] - y[i]);
          if (i === 1) f += fx * D.drive * wv * k;
          v[i] += (f * inv - D.damp * v[i]) * h;
        }
        for (var i2 = 1; i2 < N; i2++) y[i2] = u.clamp(y[i2] + v[i2] * h, -0.5, 0.5);
      }
      var sw = fw / (N - 1);
      for (var j = 0; j < N - 1; j++) {
        var kk = j / (N - 1), x0 = px + j * sw, x1 = x0 + sw, y0 = top + y[j] * fh, y1 = top + y[j + 1] * fh;
        var h0 = fh * (1 - kk * 0.08), h1 = fh * (1 - (j + 1) / (N - 1) * 0.08);
        var slope = (y1 - y0) / sw;
        var fold = u.clamp(1 - kk * 3, 0, 1) * 0.25;
        var lit = u.clamp(slope * 2 * D.shadeBy - fold, -0.45, 0.45);
        u.poly([[x0, y0], [x1 + 0.5, y1], [x1 + 0.5, y1 + h1], [x0, y0 + h0]], u.shade(D.cloth, lit));
        u.poly([[x0, y0 + h0 * 0.38], [x1 + 0.5, y1 + h1 * 0.38], [x1 + 0.5, y1 + h1 * 0.58], [x0, y0 + h0 * 0.58]], u.shade(D.band, lit));
      }
      u.label("black cloth barely shades — the band carries the folds; more waves, a harder wind: a gale is two dials, the cloth still has to catch up", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = 0.3 + (x / u.W) * 2; }
  };
});

rhymeOf("Helix", "Double helix", "the same slices with a second ribbon half a turn behind, in rose, the rod painted the colour of the dark — a strand of DNA", function make(u) {
  // rhyme of Helix: dials moved — ribbons 1 → 2, turns 3 → 2, front/back/rod palette
  var D = { sky: ["#0A0818", "#1A1030"], front: "#F05A8A", back: "#7A2A4A", rod: "#1A1030",
            ribbons: 2, turns: 2, slices: 96, radius: 0.2, speed: 0.8 };
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var cx = u.W / 2, top = u.H * 0.1, hgt = u.H * 0.72, R = u.W * D.radius, sh = hgt / D.slices, W2 = R * 0.9;
      u.ground(top + hgt + 4, "#0A0C20");
      u.shadow(cx, top + hgt + 10, R * 1.4, R * 0.3, 0.45);
      for (var pass = 0; pass < 2; pass++) {
        if (pass === 1) u.cyl(cx, top + hgt + 2, R * 0.16, hgt + 8, D.rod, -0.4);
        for (var r = 0; r < D.ribbons; r++)
          for (var i = 0; i < D.slices; i++) {
            var th = (i / D.slices) * D.turns * u.TAU + t * D.speed + r * Math.PI;
            var c = Math.cos(th);
            if ((c >= 0) !== (pass === 1)) continue;
            var x = cx + Math.sin(th) * R, w = Math.abs(c) * W2 + 1;
            var lit = -Math.sin(th) * 0.2 + Math.abs(c) * 0.15 - 0.1;
            u.ctx.fillStyle = u.shade(c >= 0 ? D.front : D.back, lit);
            u.ctx.fillRect(x - w / 2, top + i * sh, w, sh + 0.8);
          }
      }
      u.label("count 1 → 2: the second ribbon is the same loop with θ + π — the two never touch, because they can't", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.speed = (x / u.W - 0.5) * 3; }
  };
});

rhymeOf("Jetstream", "Aurora streams", "the same four bands in green over a night sky — alpha up, speed down — and the wind becomes the northern lights", function make(u) {
  // rhyme of Jetstream: dials moved — sky/ink palette, alpha 0.45 → 0.7, speed 1.0 → 0.4
  var D = { sky: ["#05051A", "#0E1230", "#1A2040"], ink: "#5AF0AA", streams: 4, lines: 5, speed: 0.4, alpha: 0.7 };
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[0]], [0.6, D.sky[1]], [1, D.sky[2]]]);
      for (var s = 0; s < D.streams; s++) {
        var z = (s + 1) / D.streams;
        var y0 = u.H * (0.12 + s * 0.19), band = u.H * (0.025 + z * 0.09), amp = u.H * (0.02 + z * 0.05);
        var len = u.W * (0.4 + z * 0.4), ph = t * (0.25 + z * 0.9) * D.speed * 2 + s * 2;
        var a = D.alpha * (0.35 + z * 0.65);
        u.ctx.fillStyle = u.lin(0, y0 - band / 2 - amp, 0, y0 + band / 2 + amp, [[0, u.rgba(D.ink, 0)], [0.5, u.rgba(D.ink, a * 0.5)], [1, u.rgba(D.ink, 0)]]);
        u.ctx.beginPath();
        for (var x = -8; x <= u.W + 8; x += 8) u.ctx.lineTo(x, y0 - band / 2 + Math.sin(x / len * u.TAU - ph) * amp);
        for (var x2 = u.W + 8; x2 >= -8; x2 -= 8) u.ctx.lineTo(x2, y0 + band / 2 + Math.sin(x2 / len * u.TAU - ph + 0.3) * amp);
        u.ctx.closePath(); u.ctx.fill();
        u.ctx.lineWidth = 0.4 + z * 1.2;
        for (var l = 0; l < D.lines; l++) {
          var q = (l + 0.5) / D.lines;
          u.ctx.strokeStyle = u.rgba(D.ink, a * Math.sin(q * Math.PI));
          u.ctx.beginPath();
          for (var x3 = -8; x3 <= u.W + 8; x3 += 8) u.ctx.lineTo(x3, y0 + (q - 0.5) * band + Math.sin(x3 / len * u.TAU - ph + q * 0.3) * amp);
          u.ctx.stroke();
        }
      }
      u.label("the same bands, one hue and more alpha — light in the air is wind you can see", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.speed = 0.3 + (x / u.W) * 2.2; }
  };
});

rhymeOf("Kite", "Dragon kite", "the same diamond in red with a gold-and-crimson tail almost twice as long, over a festival dusk — the chain just has more links", function make(u) {
  // rhyme of Kite: dials moved — kite/tail/sky palette, links 26 → 44, link 0.022 → 0.02
  var D = { sky: ["#3A2A6A", "#F5A15A"], kite: "#D82A2A", tail: "#F5C169", tailBack: "#B81A1A",
            links: 44, link: 0.02, bob: 1.0, wind: 1.0, k: 20, damp: 0.3, gust: 0.8 };
  var tail = [];
  for (var i = 0; i <= D.links; i++) tail.push([u.W * 0.6 - i * 4, u.H * 0.5 + i * 4]);
  var kx = u.W * 0.6, ky = u.H * 0.36, vx = 0, vy = 0;
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ground(u.H * 0.9, "#4A7A4A");
      var rx = u.W * (0.6 + 0.05 * Math.sin(t * 0.7) + 0.03 * Math.sin(t * 1.9 + 1));
      var ry = u.H * (0.36 + 0.05 * Math.sin(t * 1.3 * D.bob) + 0.03 * Math.sin(t * 0.53 + 2));
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, damp = D.damp * 2 * Math.sqrt(D.k);
      for (var q = 0; q < sub; q++) {
        vx += (D.k * (rx - kx) - damp * vx) * h; kx += vx * h;
        vy += (D.k * (ry - ky) - damp * vy) * h; ky += vy * h;
      }
      kx = u.clamp(kx, u.W * 0.1, u.W * 0.95); ky = u.clamp(ky, u.H * 0.05, u.H * 0.8);
      var lean = u.clamp(vx / (u.W * 0.6), -0.35, 0.35), kw = u.W * 0.07, kh = u.H * 0.1;
      u.line(u.W * 0.08, u.H * 0.9, kx - kw * 0.3, ky + kh * 0.4, "rgba(0,0,0,0.35)", 1);
      tail[0] = [kx, ky + kh * 1.2];
      var L = u.H * D.link, step = Math.min(dt, 0.05);
      for (var i = 1; i <= D.links; i++) {
        var p = tail[i], q2 = tail[i - 1];
        p[1] += 60 * step; p[0] += (30 + 40 * Math.sin(t * 3 + i * 0.4)) * step * D.wind;
        var dx = p[0] - q2[0], dy = p[1] - q2[1], d = Math.sqrt(dx * dx + dy * dy) + 1e-6;
        p[0] = q2[0] + dx / d * L; p[1] = q2[1] + dy / d * L;
      }
      for (var j = 0; j < D.links; j++) {
        var a = tail[j], b = tail[j + 1], c = Math.cos(j * 0.45 - t * 4), hw = (Math.abs(c) * 3.5 + 0.5) * (1 - j / D.links * 0.5);
        var ex = b[0] - a[0], ey = b[1] - a[1], el = Math.sqrt(ex * ex + ey * ey) + 1e-6, nx = -ey / el * hw, ny = ex / el * hw;
        u.poly([[a[0] + nx, a[1] + ny], [b[0] + nx, b[1] + ny], [b[0] - nx, b[1] - ny], [a[0] - nx, a[1] - ny]], c >= 0 ? D.tail : D.tailBack);
      }
      u.poly([[kx, ky - kh], [kx - kw, ky], [kx, ky + kh * 1.2]], u.shade(D.kite, 0.22 + lean));
      u.poly([[kx, ky - kh], [kx + kw, ky], [kx, ky + kh * 1.2]], u.shade(D.kite, -0.35 + lean));
      u.line(kx, ky - kh, kx, ky + kh * 1.2, "rgba(0,0,0,0.4)", 1);
      u.label("a longer chain is the same rule run more times — the tail's whip is emergent, not drawn", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { vy -= u.H * D.gust; vx += u.W * D.gust * 0.5; }
  };
});

rhymeOf("Loop", "Roller coaster", "the same loop as a red rail under a carnival night, the car in gold running two and a half times faster", function make(u) {
  // rhyme of Loop: dials moved — front/back/car/sky palette, carSpeed 1.2 → 3.0
  var D = { sky: ["#1A1030", "#3A2A6A"], front: "#D82A2A", back: "#5A0A0A", car: "#F5C169",
            segs: 72, width: 0.11, radius: 0.3, carSpeed: 3.0, gravity: 0.3, minSpeed: 0.25 };
  var ca = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var dir = D.carSpeed < 0 ? -1 : 1, w2 = D.carSpeed * D.carSpeed - 2 * D.gravity * (1 - Math.cos(ca));
      ca += dir * Math.sqrt(Math.max(w2, D.minSpeed * D.minSpeed)) * Math.min(dt, 0.05);
      ca = ca - Math.floor(ca / u.TAU) * u.TAU;
      var cx = u.W / 2, R = u.H * D.radius, cy = u.H * 0.5, GY = cy + R, w = u.H * D.width;
      u.ground(GY + 6, "#3A5A3A");
      u.shadow(cx, GY + 8, R * 1.2, R * 0.2, 0.35);
      u.ctx.fillStyle = u.lin(0, GY - w / 2, 0, GY + w / 2, [u.shade(D.front, 0.25), D.front, u.shade(D.front, -0.3)]);
      u.ctx.fillRect(0, GY - w / 2, u.W, w);
      for (var i = 0; i < D.segs; i++) {
        var a0 = (i / D.segs) * u.TAU, a1 = ((i + 1) / D.segs) * u.TAU, am = (a0 + a1) / 2;
        var c = Math.cos(am), hw = Math.abs(c) * w / 2 + 0.6;
        var lit = (-Math.sin(am) - c) * 0.18;
        var s0 = Math.sin(a0), c0 = Math.cos(a0), s1 = Math.sin(a1), c1 = Math.cos(a1);
        u.poly([[cx + s0 * (R - hw), cy + c0 * (R - hw)], [cx + s1 * (R - hw), cy + c1 * (R - hw)],
                [cx + s1 * (R + hw), cy + c1 * (R + hw)], [cx + s0 * (R + hw), cy + c0 * (R + hw)]],
               u.shade(c >= 0 ? D.front : D.back, u.clamp(lit, -0.4, 0.4)));
      }
      var cr = w * 0.35, cw = Math.abs(Math.cos(ca)) * w / 2 + 0.6;
      u.sphere(cx + Math.sin(ca) * (R - cw - cr), cy + Math.cos(ca) * (R - cw - cr), cr, D.car, -0.5, -0.5, { spec: 0.5 });
      u.label("speed is a dial: at 3.0 the eye stops seeing a ribbon and starts seeing a ride — and a car that fast barely slows at the crown", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.carSpeed = (x / u.W - 0.5) * 5; }
  };
});

rhymeOf("Ocean", "Lava sea", "the same seven rows in orange under a black sky, a slow wind — the air is smoke, so far rows go dark, and the foam stop glows", function make(u) {
  // rhyme of Ocean: dials moved — sky/sea/air/foam palette, wind 1.0 → 0.35
  var D = { sky: ["#0A0404", "#3A1008"], sea: "#C84A10", air: "#2A0E0A", foam: "#FFE080",
            rows: 7, wind: 0.35, horizon: 0.38, step: 4 };
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var HY = u.H * D.horizon;
      u.ctx.fillStyle = u.fog(D.sea, 0.85, D.air); u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (var i = 0; i < D.rows; i++) {
        var p = (i + 1) / D.rows;
        var y = HY + p * p * (u.H - HY) * 0.92;
        var amp = (1.5 + p * p * 14) * D.wind, len = u.W * (0.12 + p * 0.4);
        var ph = t * (0.4 + p * 1.2) * D.wind * 2 + i * 1.7;
        var c = u.fog(D.sea, (1 - p) * 0.8, D.air);
        u.ctx.fillStyle = u.lin(0, y - amp, 0, y + amp * 3, [[0, D.foam], [0.08, u.shade(c, 0.3)], [0.4, c], [1, u.shade(c, -0.35)]]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W + D.step; x += D.step) u.ctx.lineTo(x, y + Math.sin(x / len * u.TAU + ph) * amp);
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      u.label("fog toward a DARK air and distance goes black instead of pale — the air's colour is the whole mood", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.wind = 0.3 + (x / u.W) * 1.9; }
  };
});

rhymeOf("Ribbon", "Glitch tape", "the same quads in magenta and cyan on black, faster, with time snapped to ninths of a second — the smoothness was a dial", function make(u) {
  // rhyme of Ribbon: dials moved — sky/front/back palette, speed 1.0 → 1.6, step 0 → 9
  var D = { sky: ["#050508", "#0A0A12"], front: "#FF00C8", back: "#00E5FF",
            width: 0.1, segs: 64, twists: 2.5, speed: 1.6, step: 9, k: 2500, damp: 2, ret: 40, flick: 160 };
  var N = Math.max(4, Math.floor(D.segs));
  var ps = new Float32Array(N + 1), om = new Float32Array(N + 1);
  var shown = new Float32Array(N + 1), snapAt = -1;
  return {
    frame: function (dt, t) {
      var sub = Math.max(1, Math.ceil(dt * 60)), h = dt / sub;
      for (var st = 0; st < sub; st++) {
        for (var n = 0; n <= N; n++) {
          var f = -D.ret * ps[n];
          if (n > 0) f += D.k * (ps[n - 1] - ps[n]);
          if (n < N) f += D.k * (ps[n + 1] - ps[n]);
          om[n] += (f - D.damp * om[n]) * h;
        }
        for (var n2 = 0; n2 <= N; n2++) ps[n2] = u.clamp(ps[n2] + om[n2] * h, -6, 6);
      }
      var tt = t, live = ps;
      if (D.step) {
        tt = Math.floor(t * D.step) / D.step;
        if (tt !== snapAt) { snapAt = tt; shown.set(ps); }
        live = shown;
      }
      u.sky(D.sky);
      var w = u.H * D.width, px = [], py = [], tw = [];
      for (var i = 0; i <= N; i++) {
        var k = i / N;
        px.push(u.W * (-0.04 + k * 1.08));
        py.push(u.H * (0.48 + 0.2 * Math.sin(k * u.TAU * 1.2 - tt * D.speed * 1.4) + 0.06 * Math.sin(k * u.TAU * 2.7 + tt * D.speed * 0.9)));
        tw.push(k * u.TAU * D.twists - tt * D.speed * 2 + live[i]);
      }
      for (var j = 0; j < N; j++) {
        var c = Math.cos((tw[j] + tw[j + 1]) / 2);
        var hw = Math.abs(c) * w / 2 + 0.6;
        var dx = px[j + 1] - px[j], dy = py[j + 1] - py[j], len = Math.sqrt(dx * dx + dy * dy) + 1e-6;
        var lit = ((dx - dy) / len - 0.7) * 0.5;
        u.poly([[px[j], py[j] - hw], [px[j + 1], py[j + 1] - hw], [px[j + 1], py[j + 1] + hw], [px[j], py[j] + hw]],
               u.shade(c >= 0 ? D.front : D.back, u.clamp(lit, -0.4, 0.4)));
      }
      u.label("floor(t × 9) / 9: the twist wave runs on smoothly underneath, the picture only refreshes nine times a second — glitch is a time dial", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { om[0] += D.flick; }
  };
});

rhymeOf("Tide", "Moon tide", "the same beach at night under a moon — half the tide's speed, the wet sand drying twice as slowly, silver water on grey sand", function make(u) {
  // rhyme of Tide: dials moved — palette to night, tide 0.5 → 0.25, dry 6 → 12, moon 0 → 1
  var D = { sky: ["#05051A", "#1A2040"], sea: "#101E4A", shallow: "#3A5A8A", sand: "#5A5A6A", wet: "#1A1A2A", foam: "#E8E5F4",
            rows: 3, tide: 0.25, dry: 12, cols: 48, moon: 1 };
  var wet = [], wetT = [];
  for (var c = 0; c < D.cols; c++) { wet.push(0); wetT.push(-99); }
  var surgeAt = -99, lastT = 0;
  function edgeAt(x, r, reach, t) {
    return reach + Math.sin(x / u.W * u.TAU * 1.5 - t * 1.2 + r * 1.1) * u.H * 0.03;
  }
  return {
    frame: function (dt, t) {
      lastT = t;
      u.sky(D.sky);
      var HY = u.H * 0.3;
      if (D.moon) u.dot(u.W * 0.75, u.H * 0.12, u.W * 0.035, "#F0EEFF");
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.shade(D.sand, 0.1), u.shade(D.sand, -0.2)]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      var reach = u.H * (0.5 + 0.22 * Math.sin(t * D.tide) + 0.15 * Math.exp(-(t - surgeAt) * 1.5));
      var cw = u.W / D.cols;
      for (var i = 0; i < D.cols; i++) {
        var edge = edgeAt((i + 0.5) * cw, D.rows - 1, reach, t);
        if (edge >= wet[i]) { wet[i] = edge; wetT[i] = t; }
        var dark = u.clamp(1 - (t - wetT[i]) / D.dry, 0, 1) * 0.55;
        u.ctx.fillStyle = u.rgba(D.wet, dark);
        u.ctx.fillRect(i * cw, HY, cw + 1, wet[i] - HY);
      }
      for (var r = 0; r < D.rows; r++) {
        var p = (r + 1) / D.rows, base = HY + (reach - HY) * (0.45 + 0.55 * p);
        u.ctx.fillStyle = u.rgba(u.mix(D.sea, D.shallow, p), r === 0 ? 1 : 0.55);
        u.ctx.beginPath(); u.ctx.moveTo(0, HY);
        for (var x = 0; x <= u.W + 6; x += 6) u.ctx.lineTo(x, edgeAt(x, r, base, t));
        u.ctx.lineTo(u.W, HY); u.ctx.closePath(); u.ctx.fill();
        u.ctx.strokeStyle = u.rgba(D.foam, 0.3 + p * 0.5); u.ctx.lineWidth = 1 + p;
        u.ctx.beginPath();
        for (var x2 = 0; x2 <= u.W + 6; x2 += 6) u.ctx.lineTo(x2, edgeAt(x2, r, base, t));
        u.ctx.stroke();
      }
      u.label("halve the tide's speed and double the drying and the beach keeps a longer memory — pace is a dial", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { surgeAt = lastT; }
  };
});

rhymeOf("Undertow", "Deep sea", "the same water gone near-black, the weed a dim teal, half the current — and every bubble carries its own glow", function make(u) {
  // rhyme of Undertow: dials moved — water/air/weed/light/bubble palette, sway 1.0 → 0.5, glow 0 → 1
  var D = { water: ["#031020", "#000306"], air: "#0A1A2A", weed: "#1A3A3A", light: "#3A8AA0", bubble: "#8AF0FF",
            depths: 3, weeds: 4, bubbles: 22, glow: 1,
            sway: 0.5, k: 40, damp: 6, tip: 1.25, tipdamp: 0.6, lean: 0.45 };
  var R = u.rng(7), weeds = [], bubbles = [], SEG = 9;
  for (var d = 0; d < D.depths; d++)
    for (var w = 0; w < D.weeds; w++) weeds.push({ x: R() * u.W, z: (d + 0.5) / D.depths, h: 0.28 + R() * 0.3, ph: R() * 9 });
  for (var b = 0; b < D.bubbles; b++) bubbles.push({ x: R() * u.W, y: R(), z: R(), ph: R() * 9 });
  var th = new Float32Array(weeds.length * SEG), om = new Float32Array(weeds.length * SEG);
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      for (var j = 0; j < weeds.length; j++) {
        var s = weeds[j], sp = 0.6 + s.z * 0.8;
        var rest = D.lean * D.sway * (0.6 * Math.sin(t * sp * 0.9 + s.ph) + 0.4 * Math.sin(t * sp * 0.37 + s.ph * 2));
        for (var st = 0; st < sub; st++) {
          var below = rest, kj = D.k, dj = D.damp;
          for (var g = 0; g < SEG; g++) {
            var i = j * SEG + g;
            om[i] += (kj * (below - th[i]) - dj * om[i]) * h;
            th[i] = u.clamp(th[i] + om[i] * h, -1.4, 1.4);
            below = th[i]; kj *= D.tip; dj = D.tipdamp * 2 * Math.sqrt(kj);
          }
        }
      }
      u.sky(D.water);
      u.soft(u.W * 0.5, -u.H * 0.2, u.H * 0.8, D.light, 0.25);
      for (var c0 = 0; c0 < 7; c0++) {
        u.ctx.strokeStyle = u.rgba(D.light, 0.35 * (1 - c0 / 7)); u.ctx.lineWidth = 1.5;
        u.ctx.beginPath();
        for (var x = 0; x <= u.W; x += 8) u.ctx.lineTo(x, u.H * (0.04 + c0 * 0.05) + Math.sin(x * 0.04 + t * 1.5 + c0) * 3 + Math.sin(x * 0.011 - t * 0.9 + c0 * 2) * 5);
        u.ctx.stroke();
      }
      var GY = u.H * 0.9;
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [u.fog("#4A3A2A", 0.5, D.air), "#2A1A10"]); u.ctx.fillRect(0, GY, u.W, u.H - GY);
      for (var j2 = 0; j2 < weeds.length; j2++) {
        var s2 = weeds[j2], z = s2.z, hgt = u.H * s2.h * (0.5 + z * 0.6), base = GY - (1 - z) * u.H * 0.05, seg = hgt / SEG;
        var c = u.fog(D.weed, (1 - z) * 0.75, D.air), px = s2.x, py = base;
        for (var k = 0; k < SEG; k++) {
          var q = (k + 1) / SEG, a = th[j2 * SEG + k];
          var nx = px + Math.sin(a) * seg, ny = py - Math.cos(a) * seg, hw = (1 - q * 0.7) * (2 + z * 5);
          u.poly([[px - hw, py], [nx - hw, ny], [nx + hw, ny], [px + hw, py]], u.shade(c, Math.sin(a) * 0.3));
          px = nx; py = ny;
        }
      }
      for (var m = 0; m < bubbles.length; m++) {
        var o = bubbles[m], zz = o.z, yy = (((o.y - t * (0.04 + zz * 0.12)) % 1) + 1) % 1 * u.H;
        var xx = o.x + Math.sin(t * 2 + o.ph) * (2 + zz * 4), r = 1 + zz * 3;
        if (D.glow) u.soft(xx, yy, r * 4, D.bubble, 0.4);
        u.ctx.strokeStyle = u.rgba(D.bubble, 0.25 + zz * 0.5); u.ctx.lineWidth = 0.8;
        u.ctx.beginPath(); u.ctx.arc(xx, yy, r, 0, u.TAU); u.ctx.stroke();
        u.dot(xx - r * 0.35, yy - r * 0.35, r * 0.3, u.rgba(D.bubble, 0.4 + zz * 0.5));
      }
      u.label("take the light away and each bubble becomes a light source — glow is one soft() per dot", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.sway = 0.2 + (x / u.W) * 2.5; }
  };
});

rhymeOf("Wake", "Speedboat", "the same rings behind a white hull with no sail, two and a half times faster, the rings growing nearly twice as fast — bigger rings, but a tighter V, because the V's angle is growth over speed; click to change speed and the rings already dropped stay put", function make(u) {
  // rhyme of Wake: dials moved — hull/sail palette (sail fully transparent), speed 1.0 → 2.4, spread 0.45 → 0.8
  var D = { sky: ["#6FA8E8", "#CFE6F5"], sea: "#1E5A8F", air: "#C8DCEE", hull: "#F0F0F5", sail: "rgba(0,0,0,0)",
            rows: 6, rings: 32, speed: 2.4, spread: 0.8, drop: 0.08, life: 2.4,
            k: 36, damp: 0.35, pitchK: 25, pitchDamp: 0.3, pitchGain: 0.004 };
  var cap = Math.max(1, Math.floor(D.rings));
  var rx = new Float32Array(cap), ry = new Float32Array(cap), rborn = new Float32Array(cap), head = 0, count = 0, since = 0;
  var BY = u.H * 0.62, bx = -u.W * 0.25, by = BY, vy = 0, pitch = 0, pv = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var HY = u.H * 0.32;
      u.ctx.fillStyle = u.fog(D.sea, 0.85, D.air); u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (var i = 0; i < D.rows; i++) {
        var p = (i + 1) / D.rows, y = HY + p * p * (u.H - HY) * 0.9, amp = 1 + p * p * 5, len = u.W * (0.15 + p * 0.35);
        var c = u.fog(D.sea, (1 - p) * 0.8, D.air);
        u.ctx.fillStyle = u.lin(0, y - amp, 0, y + amp * 3, [u.shade(c, 0.25), c, u.shade(c, -0.3)]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W + 6; x += 6) u.ctx.lineTo(x, y + Math.sin(x / len * u.TAU + t * (0.5 + p) + i) * amp);
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      var s = u.W * 0.004, v = D.speed * u.W * 0.18, grow = D.spread * u.W * 0.18;
      bx += v * dt;
      if (bx > u.W * 1.25) bx -= u.W * 1.5;                                  // the boat wraps; the rings it dropped do not
      var ri = Math.max(0, D.rows - 3), rp = (ri + 1) / D.rows, ramp = 1 + rp * rp * 5, rlen = u.W * (0.15 + rp * 0.35);
      var ph = bx / rlen * u.TAU + t * (0.5 + rp) + ri, water = BY + Math.sin(ph) * ramp;
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, damp = D.damp * 2 * Math.sqrt(D.k), pdamp = D.pitchDamp * 2 * Math.sqrt(D.pitchK);
      for (var q = 0; q < sub; q++) {
        vy += (D.k * (water - by) - damp * vy) * h; by += vy * h;
        var prest = u.clamp(vy * D.pitchGain, -0.3, 0.3);
        pv += (D.pitchK * (prest - pitch) - pdamp * pv) * h; pitch = u.clamp(pitch + pv * h, -0.5, 0.5);
      }
      by = u.clamp(by, BY - u.H * 0.2, BY + u.H * 0.2);
      since += dt;
      var drop = Math.max(0.01, D.drop);
      while (since >= drop) {
        since -= drop;
        rx[head] = bx - 16 * s; ry[head] = water; rborn[head] = t - since;
        head = (head + 1) % cap; count = Math.min(count + 1, cap);
      }
      for (var j = 0; j < count; j++) {
        var idx = (head - count + j + cap) % cap, age = t - rborn[idx];
        if (age < 0 || age > D.life) continue;
        var r = grow * age, fade = 1 - age / D.life;
        u.ctx.strokeStyle = u.rgba("#FFFFFF", fade * 0.55); u.ctx.lineWidth = 1 + fade * 1.2;
        u.ctx.beginPath(); u.ctx.ellipse(rx[idx], ry[idx], r, r * 0.3, 0, 0, u.TAU); u.ctx.stroke();
      }
      var L = v * D.life, A = grow * D.life * 0.3;
      u.ctx.strokeStyle = u.lin(bx, 0, bx - L, 0, [u.rgba("#FFFFFF", 0.6), u.rgba("#FFFFFF", 0)]); u.ctx.lineWidth = 1;
      u.ctx.beginPath(); u.ctx.moveTo(bx, by); u.ctx.lineTo(bx - L, by - A); u.ctx.moveTo(bx, by); u.ctx.lineTo(bx - L, by + A); u.ctx.stroke();
      u.ctx.save(); u.ctx.translate(bx, by); u.ctx.rotate(pitch);
      u.soft(-16 * s, 0, 8 * s, "#FFFFFF", 0.6);
      u.poly([[-18 * s, -5 * s], [20 * s, -5 * s], [14 * s, 5 * s], [-13 * s, 5 * s]], D.hull);
      u.line(0, -5 * s, 0, -40 * s, D.hull, 1);
      u.ctx.fillStyle = u.lin(0, 0, 22 * s, 0, [u.shade(D.sail, 0.1), D.sail, u.shade(D.sail, -0.3)]);
      u.poly([[s, -38 * s], [s, -7 * s], [22 * s, -7 * s]], u.ctx.fillStyle);
      u.ctx.restore();
      u.label("the V's angle is ring growth over boat speed: 0.8 / 2.4 — bigger rings, tighter V; a press leaves the old rings behind", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.speed = 0.3 + (x / u.W) * 2; }
  };
});

rhymeOf("Xebec", "Ghost ship", "the same ship in grey under a night sky, drawn at half alpha so the sea shows through the hull — translucency is the whole haunting", function make(u) {
  // rhyme of Xebec: dials moved — sky/sea/air/hull/sail palette, alpha 1 → 0.55
  var D = { sky: ["#3A4A6A", "#1A2040", "#05051A"], sea: "#0A1A2A", air: "#2A3A5A", hull: "#3A4A5A", sail: "#A8C8D8",
            rows: 6, belly: 1.0, alpha: 0.55,
            k: 16, damp: 0.4, rollK: 12, rollDamp: 0.35, rollGain: 0.35, sailK: 25, sailDamp: 0.25, sailGain: 3 };
  var ri = Math.max(0, D.rows - 3), rp = (ri + 1) / D.rows, ramp = 1 + rp * rp * 5, rlen = u.W * (0.15 + rp * 0.35);
  var SY = u.H * 0.66, sy = SY, vy = 0, roll = 0, rv = 0, bel = D.belly * 0.85, bv = 0;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([[0, D.sky[2]], [0.6, D.sky[1]], [1, D.sky[0]]]);
      var HY = u.H * 0.45, s = u.W * 0.0045, sx = u.W * 0.5;
      u.soft(u.W * 0.7, HY, u.W * 0.3, D.sky[0], 0.5);
      u.ctx.fillStyle = u.fog(D.sea, 0.85, D.air); u.ctx.fillRect(0, HY, u.W, u.H - HY);
      var ph = sx / rlen * u.TAU - t * (0.5 + rp) + ri;
      var water = SY + Math.sin(ph) * ramp, slope = Math.cos(ph) * ramp * u.TAU / rlen;
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      var damp = D.damp * 2 * Math.sqrt(D.k), rdamp = D.rollDamp * 2 * Math.sqrt(D.rollK), sdamp = D.sailDamp * 2 * Math.sqrt(D.sailK);
      for (var q = 0; q < sub; q++) {
        vy += (D.k * (water - sy) - damp * vy) * h; sy += vy * h;
        var rrest = u.clamp(slope * D.rollGain, -0.4, 0.4);
        rv += (D.rollK * (rrest - roll) - rdamp * rv) * h; roll = u.clamp(roll + rv * h, -0.6, 0.6);
        var brest = D.belly * (0.85 + D.sailGain * roll);
        bv += (D.sailK * (brest - bel) - sdamp * bv) * h; bel = u.clamp(bel + bv * h, 0.05, 3);
      }
      sy = u.clamp(sy, SY - u.H * 0.2, SY + u.H * 0.2);
      function row(i) {
        var p = (i + 1) / D.rows, y = HY + p * p * (u.H - HY) * 0.9, amp = 1 + p * p * 5, len = u.W * (0.15 + p * 0.35);
        var c = u.fog(D.sea, (1 - p) * 0.8, D.air);
        u.ctx.fillStyle = u.lin(0, y - amp, 0, y + amp * 3, [u.shade(c, 0.25), c, u.shade(c, -0.3)]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W + 6; x += 6) u.ctx.lineTo(x, y + Math.sin(x / len * u.TAU - t * (0.5 + p) + i) * amp);
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
      }
      function sail(mx, size) {
        var ax = mx - size * 0.45, ay = -size * 1.05, fx = mx + size * 0.45, fy = -size * 0.35, cx = mx - size * 0.4, cy = -size * 0.12;
        var breathe = bel;
        u.ctx.fillStyle = u.lin(ax, 0, fx, 0, [[0, u.shade(D.sail, -0.35)], [u.clamp(0.45 + breathe * 0.15, 0.01, 0.99), u.shade(D.sail, -0.05)], [1, u.shade(D.sail, 0.15)]]);
        u.ctx.beginPath(); u.ctx.moveTo(ax, ay); u.ctx.lineTo(fx, fy);
        u.ctx.quadraticCurveTo((fx + cx) / 2 + size * 0.25 * breathe, (fy + cy) / 2 + size * 0.1, cx, cy); u.ctx.closePath(); u.ctx.fill();
        u.line(ax, ay, fx, fy, u.shade(D.hull, -0.3), 1.5);
        u.line(mx, -6 * s, mx, -size, u.shade(D.hull, -0.3), 1.5);
      }
      for (var i = 0; i < D.rows - 1; i++) row(i);
      u.ctx.save(); u.ctx.translate(sx, sy); u.ctx.rotate(roll); u.ctx.globalAlpha = D.alpha;
      sail(-2 * s, 58 * s); sail(28 * s, 42 * s);
      u.ctx.fillStyle = u.lin(0, -8 * s, 0, 6 * s, [u.shade(D.hull, 0.2), u.shade(D.hull, -0.4)]);
      u.poly([[-40 * s, -6 * s], [44 * s, -9 * s], [36 * s, 6 * s], [-34 * s, 6 * s]], u.ctx.fillStyle);
      u.ctx.restore();
      row(D.rows - 1);
      u.label("globalAlpha 0.55: the far rows show through the hull, so the ship reads as less THERE — alpha is presence", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.belly = 0.3 + (x / u.W) * 1.5; }
  };
});

rhymeOf("Yacht", "Regatta", "three of the same yacht, each on its own row — the far ones smaller and paler by the row they sit on — leaning harder, sailing faster", function make(u) {
  // rhyme of Yacht: dials moved — boats 1 → 3, heel 0.22 → 0.3, speed 1.0 → 1.6
  var D = { sky: ["#3A7FD0", "#B8D8F5"], sea: "#1E5A8F", air: "#C8DCEE", hull: "#F5F0E0", sail: "#FFFFFF", trim: "#D82A2A",
            rows: 6, boats: 3, heel: 0.3, speed: 1.6,
            k: 16, damp: 0.35, slopeGain: 0.25, bobK: 30, bobDamp: 0.4 };
  var HY = u.H * 0.4, n = Math.max(1, Math.floor(D.boats)), dir = 1;
  var th = new Float32Array(n), om = new Float32Array(n), by = new Float32Array(n), vy = new Float32Array(n);
  var rowOf = [], bx = [], rowY = [], rowP = [], rowAmp = [], rowLen = [];
  for (var b = 0; b < n; b++) {
    rowOf[b] = n === 1 ? D.rows - 2 : Math.round(1 + (b / (n - 1)) * (D.rows - 3));
    rowP[b] = (rowOf[b] + 1) / D.rows; rowY[b] = HY + rowP[b] * rowP[b] * (u.H - HY) * 0.9;
    rowAmp[b] = 1 + rowP[b] * rowP[b] * 5; rowLen[b] = u.W * (0.15 + rowP[b] * 0.35);
    bx[b] = u.W * (0.5 + (b - (n - 1) / 2) * 0.3); th[b] = D.heel; by[b] = rowY[b] - 2;
  }
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub, damp = D.damp * 2 * Math.sqrt(D.k), bdamp = D.bobDamp * 2 * Math.sqrt(D.bobK);
      for (var b = 0; b < n; b++) {                                          // every boat has its own springs — each row's swell rocks it at its own moment
        var ph = bx[b] / rowLen[b] * u.TAU - t * (0.5 + rowP[b]) * D.speed + rowOf[b];
        var water = rowY[b] - 2 + Math.sin(ph) * rowAmp[b], slope = Math.cos(ph) * rowAmp[b] * u.TAU / rowLen[b];
        var rest = D.heel * dir + u.clamp(slope * D.slopeGain, -0.3, 0.3);
        for (var q = 0; q < sub; q++) {
          om[b] += (D.k * (rest - th[b]) - damp * om[b]) * h; th[b] = u.clamp(th[b] + om[b] * h, -1.2, 1.2);
          vy[b] += (D.bobK * (water - by[b]) - bdamp * vy[b]) * h; by[b] += vy[b] * h;
        }
        by[b] = u.clamp(by[b], rowY[b] - u.H * 0.15, rowY[b] + u.H * 0.15);
      }
      u.ctx.fillStyle = u.fog(D.sea, 0.85, D.air); u.ctx.fillRect(0, HY, u.W, u.H - HY);
      function boat(x, y, z, angle) {
        var s = u.W * 0.0045 * (0.3 + z * 0.7), hull = u.fog(D.hull, (1 - z) * 0.6, D.air), sail = u.fog(D.sail, (1 - z) * 0.6, D.air);
        u.ctx.save(); u.ctx.translate(x, y); u.ctx.rotate(angle); u.ctx.scale(dir, 1);
        u.poly([[-24 * s, -5 * s], [26 * s, -6 * s], [20 * s, 6 * s], [-20 * s, 6 * s]], hull);
        u.poly([[-23 * s, 1 * s], [24 * s, 1 * s], [20 * s, 6 * s], [-20 * s, 6 * s]], u.fog(D.trim, (1 - z) * 0.6, D.air));
        u.line(0, -5 * s, 0, -70 * s, "rgba(0,0,0,0.5)", 1);
        u.ctx.fillStyle = u.lin(0, 0, -32 * s, 0, [[0, u.shade(sail, -0.3)], [0.55, u.shade(sail, -0.08)], [1, sail]]);
        u.ctx.beginPath(); u.ctx.moveTo(0, -68 * s); u.ctx.lineTo(0, -8 * s); u.ctx.lineTo(-32 * s, -8 * s);
        u.ctx.quadraticCurveTo(-28 * s, -40 * s, 0, -68 * s); u.ctx.fill();
        u.ctx.fillStyle = u.lin(0, 0, 26 * s, 0, [u.shade(sail, -0.2), sail]);
        u.poly([[1 * s, -56 * s], [26 * s, -7 * s], [0, -16 * s]], u.ctx.fillStyle);
        u.ctx.restore();
      }
      for (var i = 0; i < D.rows; i++) {
        var p = (i + 1) / D.rows, y = HY + p * p * (u.H - HY) * 0.9, amp = 1 + p * p * 5, len = u.W * (0.15 + p * 0.35);
        var c = u.fog(D.sea, (1 - p) * 0.8, D.air);
        u.ctx.fillStyle = u.lin(0, y - amp, 0, y + amp * 3, [u.shade(c, 0.25), c, u.shade(c, -0.3)]);
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W + 6; x += 6) u.ctx.lineTo(x, y + Math.sin(x / len * u.TAU - t * (0.5 + p) * D.speed + i) * amp);
        u.ctx.lineTo(u.W, u.H); u.ctx.closePath(); u.ctx.fill();
        for (var k = 0; k < n; k++) if (rowOf[k] === i) boat(bx[k], by[k], p, th[k]);
      }
      u.label("count 1 → 3: each boat is drawn right after its row, so the near sea covers the far hulls — and each tacks on its own spring", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { dir = -dir; }
  };
});

rhymeOf("Zephyr", "Autumn gale", "the same wind in a warm dusk, nearly twice as fast, carrying three times the leaves in rust and orange — the ribbons barely change, the load does", function make(u) {
  // rhyme of Zephyr: dials moved — sky/ribbon/back/leaf palette, leaves 6 → 18, speed 1.0 → 1.8
  var D = { sky: ["#C88A4A", "#F5D9B0"], ribbon: "#FFF3E0", back: "#E8B888", leaf: "#D8602A",
            ribbons: 3, leaves: 18, speed: 1.8, len: 0.8, segs: 40, k: 40, damp: 5, spin: 8 };
  var R = u.rng(17), paths = [], leaves = [];
  for (var i = 0; i < D.ribbons; i++) paths.push({ y: 0.22 + i * 0.24, amp: 0.05 + R() * 0.05, f: 1 + R() * 1.2, off: R() * 4, sp: 0.8 + R() * 0.4 });
  for (var l = 0; l < D.leaves; l++) leaves.push({ p: l % D.ribbons, s: 0.1 + R() * 0.6, spin: R() * 9, y: -1, vy: 0, rot: 0, px: -1e9 });
  function pathY(p, x, t) { return u.H * (p.y + p.amp * Math.sin(x / u.W * p.f * u.TAU - t * 1.5 * p.sp)); }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      u.ground(u.H * 0.9, "#5A8A5A");
      var len = u.W * D.len, w = u.H * 0.05;
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      for (var i = 0; i < paths.length; i++) {
        var p = paths[i], head = ((t * D.speed * u.W * 0.35 * p.sp + p.off * u.W) % (u.W + len));
        for (var j = 0; j < D.segs; j++) {
          var s0 = j / D.segs, s1 = (j + 1) / D.segs, x0 = head - s0 * len, x1 = head - s1 * len;
          if (x0 < 0 || x1 > u.W) continue;
          var c = Math.cos(s0 * u.TAU * 1.5 + t * 3 + i), hw = Math.abs(c) * w / 2 + 0.4;
          u.poly([[x0, pathY(p, x0, t) - hw], [x1, pathY(p, x1, t) - hw], [x1, pathY(p, x1, t) + hw], [x0, pathY(p, x0, t) + hw]],
                 u.rgba(c >= 0 ? D.ribbon : D.back, (1 - s0) * 0.6));
        }
        for (var k = 0; k < leaves.length; k++) {
          var o = leaves[k];
          if (o.p !== i) continue;
          var lx = head - o.s * len, target = pathY(p, lx, t), vx = D.speed * u.W * 0.35 * p.sp;
          if (o.px < -1e8 || lx < o.px - u.W * 0.5) { o.y = target; o.vy = 0; }
          o.px = lx;
          for (var st = 0; st < sub; st++) {
            o.vy += (D.k * (target - o.y) - D.damp * o.vy) * h;
            o.y = u.clamp(o.y + o.vy * h, -u.H, u.H * 2);
            o.rot += (Math.abs(vx) + Math.abs(o.vy) * 2) / u.W * D.spin * h;
          }
          if (lx < 0 || lx > u.W) continue;
          u.ctx.save(); u.ctx.translate(lx, o.y); u.ctx.rotate(o.rot + o.spin);
          u.ctx.fillStyle = D.leaf; u.ctx.beginPath(); u.ctx.ellipse(0, 0, u.W * 0.014, u.W * 0.007, 0, 0, u.TAU); u.ctx.fill();
          u.ctx.restore();
        }
      }
      u.label("more leaves chasing the same y(x), faster, and the wind reads as stronger — they fall further behind each crest, and spin harder", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.speed = 0.3 + (x / u.W) * 2.5; }
  };
});
/* ============================== SHADOWS & FOCUS ==============================
   Two depth cues cost almost nothing. A SHADOW is a dark ellipse on the
   ground: tight and black when the thing touches, smaller-softer-fainter
   as it lifts, long when the sun is low — the shadow tells the eye where
   the floor is and how far above it a thing floats. OVERLAP is free: what
   is drawn last is nearest. And BLUR stands in for the eye itself — what
   is sharp is where you are looking; everything else is far from it.
   Fourteen pictures: cast, contact, ambient, soft, long, mirrored — and
   then the lens: bokeh, tilt-shift, vignette, ink, hard light, x-ray. */

def("C", "Contact", "shadow", "a ball on the ground with a tight dark shadow — press to lift it: as it floats up the shadow shrinks, softens and fades; height is written on the floor", function make(u) {
  var D = { sky: ["#2A2F4A", "#4A5578"], floor: "#5A6080", ball: "#F58A8A",   // room and ball
            shadowA: 0.6, float: -0.25, lift: 0.4 };                            // shadow darkness; drift of the target height per second (negative = sinks back); press lift
  var h = 0, v = 0, target = 0;                                                 // height (fraction of H), velocity, where the spring wants to be
  return {
    frame: function (dt, t) {
      dt = Math.min(dt, 0.05);
      target = u.clamp(target + D.float * dt, 0, 0.5);                          // the target sinks (or rises, for a balloon)
      v += (target - h) * 60 * dt; v -= v * 4 * dt; h += v * dt;              // a soft spring toward the target
      if (h < 0) { h = 0; v = -v * 0.3; }                                       // the floor is a floor
      u.sky(D.sky);
      var GY = u.H * 0.78, r = u.W * 0.085, x = u.W * 0.5, hp = h * u.H;       // hp: height in pixels
      u.ground(GY, D.floor);
      var k = 1 / (1 + hp / (r * 0.9));                                         // 1 on the ground → toward 0 with height
      u.shadow(x, GY, r * (0.5 + 0.7 * k) + hp * 0.25, r * (0.2 + 0.2 * k) + hp * 0.08, D.shadowA * 0.35 * k);   // the soft halo: grows and fades
      u.shadow(x, GY, r * (0.35 + 0.75 * k), r * (0.14 + 0.22 * k), D.shadowA * k);                             // the tight core: shrinks and fades
      u.sphere(x, GY - r - hp, r, D.ball, -0.4, -0.6, { spec: 0.4 });
      u.label("height: " + (hp / r).toFixed(1) + " radii", x, GY - r * 2 - hp - 8, u.rgba(u.INK, 0.7), "center");
      u.label("touching = tight and dark; floating = smaller, softer, fainter — the shadow IS the height", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { target = u.clamp((u.H * 0.78 - y) / u.H, 0.05, 0.5); v += D.lift; }   // click above the ball = lift it there
  };
});

def("J", "Jump", "shadow", "two balls hop along under real gravity — a crouch, a push-off, an arc, a landing that squashes and bounces; only one has a shadow that stays on the ground and shrinks with altitude — cover it and the other ball just wobbles", function make(u) {
  var D = { sky: ["#1E2A3A", "#3A5068"], floor: "#3A4A3A", grass: "#5A8A4A", ball: "#F5C169", ghost: "#8AD9F5",
            hop: 0.24, hops: 1.1, speed: 0.2,                                  // hop height (of H), hops per second, path speed (of W per second)
            air: 0.7,                // the share of each hop spent in the air — the rest is the landing, the crouch and the push-off
            rebound: 0.25,           // how much of the landing speed comes back as a bounce (a second hop a sixteenth as high)
            squash: 0.3 };           // how far a landing flattens the ball, as a fraction of its radius; the crouch is half of it
  var hgt = 0, v = 0, sq = 0, sqv = 0, stance = 0, crouched = true;            // altitude (px) and its speed; the squash (− flat … + tall) and its speed; time on the ground (−1 = airborne)
  // the hop is ballistics, the same integrator as Contact: the push-off sets a
  // speed, gravity eats it, the altitude follows, and the ground is a floor
  // with a little restitution — so a landing gives a small second bounce
  // before the ball is still. the cadence stays a dial: the period is 1/hops
  // and `air` of it is flight, so g and the push-off are derived to make an
  // arch exactly hop·H tall that lands on time (a higher hop under the same
  // cadence means a stronger gravity — arcade physics). the squash is a
  // separate spring around round, kicked flat by the landing and by the
  // crouch just before take-off, under-damped so it wobbles a moment.
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var GY = u.H * 0.8, r = u.W * 0.05;
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [D.grass, D.floor]); u.ctx.fillRect(0, GY, u.W, u.H - GY);
      var P = 1 / D.hops, flight = P * D.air, hp = D.hop * u.H;
      var g = 8 * hp / (flight * flight), v0 = Math.sqrt(2 * g * hp);         // the gravity and push-off that make an arch hp tall land after `flight` seconds
      var sk = 400, sw = Math.sqrt(sk), sd = 0.3 * 2 * sw;                      // the squash spring: ω = 20, a fifth of a second per wobble, 0.3 of critical
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;                 // substeps of ≤ 0.02 s: the squash spring needs √k·h small
      for (var s = 0; s < sub; s++) {
        if (hgt > 0 || v > 0) {                                                 // in the air (the hop, or the little bounce after it)
          v -= g * h; hgt += v * h;
          if (hgt <= 0) {                                                       // the floor is a floor
            hgt = 0;
            sqv -= D.squash * 1.6 * sw * Math.min(1, -v / v0);                  // the landing kicks the squash flat (1.6ω peaks at about `squash`), harder the faster it hit
            v = -v * D.rebound;                                                 // and keeps a little speed as a bounce
            if (v < 0.15 * v0) v = 0;                                           // too small to see — it is down
            if (stance < 0) { stance = 0; crouched = false; }                   // the ground clock starts at first touch, bounce or no bounce
          }
        }
        if (stance >= 0) {                                                      // on the ground: wait out the stance, crouch, push off
          stance += h;
          if (!crouched && stance > P - flight - 0.12) { crouched = true; sqv -= D.squash * 0.8 * sw; }   // the anticipation dip, a tenth of a second before take-off
          if (stance >= P - flight && hgt === 0 && v === 0) { stance = -1; v = v0; sqv += D.squash * 0.6 * sw; }   // take-off, once it is down: the push-off, and the ball stretches after it
        }
        sqv += (sk * (0 - sq) - sd * sqv) * h; sq = u.clamp(sq + sqv * h, -0.6, 0.6);
      }
      var x1 = ((t * D.speed) % 1) * (u.W + 4 * r) - 2 * r;                     // the hero, crossing left → right
      var x2 = ((t * D.speed + 0.5) % 1) * (u.W + 4 * r) - 2 * r;               // the ghost, half a lap behind
      var k = 1 / (1 + hgt / (r * 1.2));                                        // shadow factor: 1 touching → small when high
      var sx = 1 - sq * 0.6, sy = 1 + sq;                                       // flat = wider, tall = narrower: the volume roughly keeps
      u.shadow(x1, GY, r * (0.4 + 0.9 * k) * sx, r * (0.15 + 0.25 * k), 0.55 * k);   // the shadow never leaves the ground
      u.ctx.save(); u.ctx.translate(x1, GY - hgt); u.ctx.scale(sx, sy);          // the squash scales about the point of contact
      u.sphere(0, -r, r, D.ball, -0.4, -0.6, { spec: 0.4 });
      u.ctx.restore();
      u.ctx.save(); u.ctx.translate(x2, GY - hgt); u.ctx.scale(sx, sy);
      u.sphere(0, -r, r, D.ghost, -0.4, -0.6, { spec: 0.4 });                    // same arc, same squash, no shadow: is it jumping or just higher up the wall?
      u.ctx.restore();
      u.label("which one is jumping?", u.W / 2, u.H * 0.14, u.rgba(u.INK, 0.7), "center");
      u.label("the ball's y says nothing on its own; the gap to its shadow says 'altitude'", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.hop = 0.08 + (1 - y / u.H) * 0.32; }            // click higher = higher hops: it moves the push-off and the gravity, never the ball
  };
});

def("L", "Longshadow", "shadow", "a low sun: posts throw long parallelogram shadows across the floor, length = height / tan(elevation) — press moves the sun and the shadows swing", function make(u) {
  var D = { sky: ["#3A2A5A", "#F5A15A"], floor: "#E8B87A", post: "#4A3A6A", sun: "#FFF3D0",
            elev: 0.32, dir: 1, tilt: 0.28, posts: 5, shadowA: 0.35 };          // sun elevation (radians), side (+1 = sun on the left), how much shadows lean toward the viewer, count
  var R = u.rng(31), posts = [];
  for (var j = 0; j < D.posts; j++) posts.push({ x: 0.12 + j * 0.76 / (D.posts - 1) + (R() - 0.5) * 0.06, h: 0.16 + R() * 0.2, w: 0.035 + R() * 0.02 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var HY = u.H * 0.42, GY = u.H * 0.7;
      var el = u.clamp(D.elev + Math.sin(t * 0.35) * 0.08, 0.12, 1.45);        // the sun drifts a little; never quite on the horizon (tan → 0)
      var stretch = 1 / Math.tan(el);                                           // shadow length per unit of height
      var sx = D.dir > 0 ? u.W * 0.1 : u.W * 0.9, sy = HY - Math.sin(el) * u.H * 0.4;
      u.soft(sx, sy, u.W * 0.3, D.sun, 0.5); u.dot(sx, sy, u.W * 0.035, D.sun);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.shade(D.floor, 0.1), u.shade(D.floor, -0.25)]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (var j = 0; j < posts.length; j++) {                                  // shadows first — they lie on the floor
        var p = posts[j], x0 = p.x * u.W, w = p.w * u.W, h = p.h * u.H, L = h * stretch;
        var dx = L * D.dir, dy = L * D.tilt;                                    // the shadow slides away from the sun and leans toward us
        u.poly([[x0, GY], [x0 + w, GY], [x0 + w + dx, GY + dy], [x0 + dx, GY + dy]], "rgba(20,10,40," + D.shadowA + ")");
      }
      for (var j = 0; j < posts.length; j++) {
        var p = posts[j], x0 = p.x * u.W, w = p.w * u.W, h = p.h * u.H;
        u.ctx.fillStyle = u.lin(x0, 0, x0 + w, 0, D.dir > 0 ? [u.shade(D.post, 0.3), u.shade(D.post, -0.3)] : [u.shade(D.post, -0.3), u.shade(D.post, 0.3)]);   // lit on the sun's side
        u.ctx.fillRect(x0, GY - h, w, h);
      }
      u.label("elevation " + Math.round(el * 57.3) + "°: shadow = " + stretch.toFixed(1) + "× the post's height", u.W / 2, u.H * 0.1, u.rgba(u.INK, 0.7), "center");
      u.label("a low sun makes long shadows — their length is the time of day, their direction the compass", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.dir = x < u.W / 2 ? 1 : -1; D.elev = 0.15 + (1 - y / u.H) * 1.2; }   // click = put the sun there (side by x, height by y)
  };
});

def("A", "Ambient", "shadow", "ambient occlusion: cubes with no directional light at all — only the crevices and the ground contact darkened by soft blobs — and they still read as solid", function make(u) {
  var D = { sky: ["#DCD8E8", "#B8B4CC"], floor: "#A8A4BC", cube: "#C8C4DC",   // near-flat, no sun anywhere
            faceDiff: 0.05, ao: true, aoA: 0.32, aoR: 0.85 };                 // how different the faces are (0 = identical), AO on/off, its darkness and reach (× cube size)
  var cells = [[0, 0, 0], [1, 0, 0], [2, 0, 0], [0, 1, 0], [1, 1, 0], [2, 1, 0], [0, 2, 0], [1, 2, 0], [2, 2, 0], [1, 1, 1], [2, 0, 1], [0, 2, 1]];
  cells.sort(function (a, b) { return (a[0] + a[1] + a[2] * 0.1) - (b[0] + b[1] + b[2] * 0.1); });   // far first, then low first
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = u.W * 0.085, cx = u.W * 0.5, cy = u.H * 0.7;
      u.ground(u.H * 0.55, D.floor);
      var c = D.cube, faces = { top: u.shade(c, D.faceDiff), left: c, right: u.shade(c, -D.faceDiff) };
      for (var i = 0; i < cells.length; i++) {
        var q = cells[i], lift = q[2] === 1 && q[0] === 1 ? (0.5 + 0.5 * Math.sin(t * 0.9)) * 0.9 : 0;   // the middle top cube hovers a little
        var p = u.iso(q[0] - 1, q[1] - 1, q[2] + lift, s), x = cx + p[0], y = cy + p[1];
        var a = D.aoA / (1 + lift * 3);                                        // AO fades as the cube leaves its neighbours
        if (D.ao) {                                                            // the crevices: base point, base corners, and the wall it meets
          u.soft(x, y, s * D.aoR, "#20183A", a);
          u.soft(x - s * 0.866, y - s * 0.5, s * D.aoR * 0.7, "#20183A", a * 0.7);
          u.soft(x + s * 0.866, y - s * 0.5, s * D.aoR * 0.7, "#20183A", a * 0.7);
        }
        u.cube(x, y, s, c, faces);
      }
      u.label(D.ao ? "AO on — press to switch it off" : "AO off — press to switch it on", u.W / 2, u.H * 0.1, u.rgba("#20183A", 0.6), "center");
      u.label("no sun, no shading — just dark where things meet, and the eye supplies the solid", u.W / 2, u.H - 8, u.rgba("#20183A", 0.7), "center");
    },
    press: function (x, y) { D.ao = !D.ao; }
  };
});

def("U", "Umbra", "shadow", "an area light: the shadow has a dark core (umbra) and a soft rim (penumbra) that widens the wider and nearer the light — press moves the light", function make(u) {
  var D = { sky: ["#1A1E2E", "#2A3048"], floor: "#3A4058", ball: "#8AD9F5", lamp: "#FFF3D0",
            lightW: 0.3, lightX: 0.3, lightY: 0.12, steps: 9, shadowA: 0.6 };  // light width (of W), position, how many ellipses build the gradient, core darkness
  var lx = null, ly = null;                                                     // pressed light position (null = the slow sway)
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var GY = u.H * 0.8, r = u.W * 0.08, ox = u.W * 0.55, oy = GY - r;         // the floor, the ball
      var LX = lx !== null ? lx : u.W * (D.lightX + 0.12 * Math.sin(t * 0.5)), LY = ly !== null ? ly : u.H * D.lightY;
      var LW = u.W * D.lightW;
      u.ground(GY, D.floor);
      var drop = GY - oy, rise = Math.max(20, oy - LY);                         // ball-to-floor, light-to-ball
      var sx = ox + (ox - LX) * drop / rise;                                    // where the light-through-the-ball-centre hits the floor
      var pen = LW * drop / rise;                                               // penumbra width: a wider or nearer light blurs more
      var core = r * (1 + drop / rise);                                         // the umbra's half-width
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, GY, u.W, u.H - GY); u.ctx.clip();
      for (var i = D.steps - 1; i >= 0; i--) {                                  // big faint ellipses first, then smaller darker ones on top
        var k = i / (D.steps - 1), rx = Math.max(1, core - pen * 0.5 + pen * k), ry = rx * 0.32;
        u.ctx.fillStyle = "rgba(0,0,10," + (D.shadowA / D.steps * 1.4).toFixed(3) + ")";
        u.ctx.beginPath(); u.ctx.ellipse(sx, GY + 1, rx, ry, 0, 0, u.TAU); u.ctx.fill();
      }
      u.ctx.restore();
      var dx = LX - ox, dy = LY - oy, len = Math.sqrt(dx * dx + dy * dy) || 1;
      u.sphere(ox, oy, r, D.ball, dx / len, dy / len, { spec: 0.4, rim: D.lamp });
      u.soft(LX, LY, LW, D.lamp, 0.25);                                         // the light itself: a glowing bar
      u.ctx.fillStyle = D.lamp; u.ctx.fillRect(LX - LW / 2, LY - 3, LW, 6);
      u.label("a point light makes a hard edge; a wide one blurs it — the blur is the light's size", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { lx = x; ly = Math.min(y, u.H * 0.55); }            // click = hang the lamp there
  };
});

def("O", "Occlusion", "shadow", "five identical flat discs crossing paths: what is drawn last is nearest, and each is scaled by its z — overlap alone sorts them; press reverses the sort", function make(u) {
  var D = { sky: ["#F0ECE4", "#D8D2C4"], disc: "#E86A5A", edge: "#3A2A2A", n: 5, speed: 0.6, shape: "disc", flip: false };
  var R = u.rng(17), items = [];
  for (var j = 0; j < D.n; j++) items.push({ ph: j / D.n * u.TAU, ry: 0.28 + R() * 0.14, sp: 0.7 + R() * 0.6, x: 0, y: 0, z: 0 });
  var order = [];
  for (var k = 0; k < D.n; k++) order.push(k);
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      for (var j = 0; j < items.length; j++) {                                  // an orbit seen from the side: z is the depth along it
        var it = items[j], a = t * D.speed * it.sp + it.ph;
        it.z = 0.5 + 0.5 * Math.sin(a);                                         // 0 far … 1 near
        it.x = u.W * 0.5 + Math.cos(a) * u.W * 0.3; it.y = u.H * 0.48 + (it.z - 0.5) * u.H * it.ry;
      }
      order.sort(function (a, b) { return D.flip ? items[b].z - items[a].z : items[a].z - items[b].z; });   // painter's order: far first
      for (var o = 0; o < order.length; o++) {
        var d = items[order[o]], r = u.W * (0.05 + d.z * 0.07);                 // near = bigger
        u.ctx.fillStyle = D.disc; u.ctx.strokeStyle = D.edge; u.ctx.lineWidth = 1.5;
        u.ctx.beginPath();
        if (D.shape === "disc") u.ctx.arc(d.x, d.y, r, 0, u.TAU); else u.ctx.rect(d.x - r * 0.8, d.y - r * 1.1, r * 1.6, r * 2.2);
        u.ctx.fill(); u.ctx.stroke();
      }
      u.label(D.flip ? "sorted near → far: the small ones cover the big ones and depth breaks" : "sorted far → near: the last drawn wins the overlap", u.W / 2, u.H * 0.1, u.rgba(D.edge, 0.6), "center");
      u.label("no shading, no shadow: draw order + size are already a third axis", u.W / 2, u.H - 8, u.rgba(D.edge, 0.7), "center");
    },
    press: function (x, y) { D.flip = !D.flip; }
  };
});

def("G", "Ground", "shadow", "a perspective floor: rows at horizon + p², columns converging on one vanishing point, fog toward the horizon; a ball rolls away and shrinks, overruns each end and turns back with its own weight — press moves the vanishing point, and the grid swings over on a spring", function make(u) {
  var D = { sky: ["#2A3A5A", "#8AA0C8"], floor: "#3A4A5A", lines: "#C8D8F0", ball: "#F58A8A",
            rows: 12, cols: 9, fogK: 0.9, speed: 0.3,                          // grid density, how much the far floor fades into the air, the ball's beat (about this many out-and-backs a second)
            damp: 0.5,               // the ball's damping as a fraction of critical — under 1, so it overruns each end and rolls back before turning
            steer: 40 };             // the vanishing point's spring toward a press
  var vx = u.W * 0.5, vxT = vx, vv = 0;                                          // the vanishing point, where it is asked to be, its speed
  var q = 0.9, qv = 0, tgt = 0.18;                                              // the ball's depth (0 = horizon, 1 = here), its speed, the end it is rolling for
  // the ball has mass: it is pulled toward the far end by a spring (stiffness
  // from `speed`, so the beat is the old sine's) and damped under critical, so
  // it arrives fast, overruns, and comes to rest a little past the end — and
  // that first moment of rest is when the target flips to the near end, so it
  // reverses from a standstill, accelerating, instead of turning on a curve
  // that was always going to turn. the vanishing point is the same spring,
  // nearly critical, so a press swings the whole grid over and settles it.
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var w = u.TAU * D.speed, k = w * w, dd = D.damp * 2 * w;                   // the ball's spring: ω = 2π·speed
      var sd = 0.9 * 2 * Math.sqrt(D.steer);                                    // the grid's: 0.9 of critical, one small overswing
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      for (var s = 0; s < sub; s++) {
        vv += (D.steer * (vxT - vx) - sd * vv) * h; vx = u.clamp(vx + vv * h, -u.W, 2 * u.W);
        var was = qv;
        qv += (k * (tgt - q) - dd * qv) * h; q = u.clamp(q + qv * h, 0, 1.15);   // the horizon is as far as it goes
        var still = (was !== 0 && (was < 0) !== (qv < 0)) || (Math.abs(q - tgt) < 0.005 && Math.abs(qv) < 0.02);   // it has stopped
        if (still && Math.abs(q - tgt) < 0.3) tgt = tgt < 0.5 ? 0.9 : 0.18;    // … past the end it was rolling for: send it back
      }
      u.sky(D.sky);
      var HY = u.H * 0.42, air = D.sky[1];
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.mix(D.floor, air, D.fogK), D.floor]); u.ctx.fillRect(0, HY, u.W, u.H - HY);   // the floor is a fog gradient
      for (var i = 1; i <= D.rows; i++) {
        var p = i / D.rows, y = HY + p * p * (u.H - HY);                         // p² bunches the rows toward the horizon
        u.line(0, y, u.W, y, u.rgba(D.lines, 0.1 + p * 0.5), 1);
      }
      for (var j = 0; j <= D.cols; j++) {                                       // columns: every one aims at the vanishing point
        var bx = vx + (j / D.cols - 0.5) * u.W * 2.4;
        u.ctx.strokeStyle = u.lin(0, HY, 0, u.H, [u.rgba(D.lines, 0), u.rgba(D.lines, 0.55)]);
        u.ctx.lineWidth = 1; u.ctx.beginPath(); u.ctx.moveTo(vx, HY); u.ctx.lineTo(bx, u.H); u.ctx.stroke();
      }
      var qd = u.clamp(q, 0, 1);                                                // the ball's depth for the cues: q 0 = horizon, 1 = here (the overrun keeps rolling in size and place)
      var by = HY + q * q * (u.H - HY), bx2 = u.lerp(vx, u.W * 0.62, q), r = u.W * 0.02 + q * q * u.W * 0.07;   // size follows the same p² rule
      u.shadow(bx2, by, r * 1.15, r * 0.35, 0.5 * (0.3 + qd * 0.7));           // the shadow pins the ball to a row
      u.sphere(bx2, by - r, r, u.fog(D.ball, (1 - qd) * D.fogK, air), -0.4, -0.6, { spec: 0.35 });
      u.label("rows bunch as p², columns meet at one point, colour fades into the air — three cues, one floor", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { vxT = x; }                                         // click = ask the vanishing point over; the spring carries it
  };
});

def("M", "Mirror", "shadow", "a floor reflection: the object drawn again upside-down under the floor line, darker and fading with distance from it, with a faint ripple — press moves the object: it slides over on a spring and settles, the sphere swinging behind, reflection and all", function make(u) {
  var D = { sky: ["#1A1030", "#3A2A5A"], floor: "#141020", ball: "#C9A0F5", block: "#5A7AB8",
            refA: 0.55, fade: 0.8, ripple: 2.0,                                  // reflection strength, how fast it fades (of the pool depth), ripple amplitude in px
            slide: 30,               // the spring that carries the object toward a press (0.6 of critical: one small overrun, settled in a second)
            swing: 25,               // the sphere's pendulum stiffness over the block — how quickly its lag behind a slide swings back
            hover: 1.5 };            // seconds between the kicks of the lift that keeps the sphere bobbing
  var ox = u.W * 0.5, tx = ox, ov = 0;                                          // where the object is, where it was asked to be, its speed
  var sway = 0, swv = 0, bob = 0, bv = 0, clk = 0;                              // the sphere's lag behind the block (px) and its speed; its lift above rest (px) and its speed; the lift's clock
  // the object slides on a spring toward the pressed x, damped a little under
  // critical so it overruns and settles. the sphere is a pendulum hanging over
  // the block: its sway is a spring around zero DRIVEN BY THE BLOCK'S
  // ACCELERATION (a cart jerks, the bob swings the other way), so it lags a
  // slide and swings through after. the bob is a spring around its rest
  // height, kicked by the lift every `hover` seconds — a hovering thing that
  // never quite holds still — and dipped by a hard slide. the reflection is
  // the same drawing flipped, so all of it shows twice for free.
  function object(x, FY) {                                                      // the thing and its reflection are the same drawing
    var s = u.W * 0.07;
    u.cube(x, FY, s, D.block);
    u.sphere(x + sway, FY - s - s * 0.9 - bob - u.H * 0.03, s * 0.8, D.ball, -0.5, -0.6, { spec: 0.4, rim: "#8AD9F5" });
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var kd = 0.6 * 2 * Math.sqrt(D.slide), sd = 0.2 * 2 * Math.sqrt(D.swing);    // the slide's and the sway's dampings from their fractions of critical (the pendulum rings for a few seconds)
      var kb = 16, bd = 0.12 * 2 * Math.sqrt(kb);                                 // the bob: ω = 4 (a swing and a half a second), lightly damped so the kicks carry
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      for (var s = 0; s < sub; s++) {
        var acc = D.slide * (tx - ox) - kd * ov;                                  // the block's acceleration this step
        ov += acc * h; ox = u.clamp(ox + ov * h, u.W * 0.08, u.W * 0.92);
        swv += (D.swing * (0 - sway) - sd * swv - acc * 0.4) * h;                 // the pendulum: thrown the other way by the block's acceleration (0.4 of it — the sphere is the light end)
        sway = u.clamp(sway + swv * h, -u.W * 0.1, u.W * 0.1);
        clk += h;
        if (clk >= D.hover) { clk -= D.hover; bv += u.H * 0.08; }                 // the lift's kick
        bv += (kb * (0 - bob) - bd * bv - Math.abs(acc) * 0.05) * h;              // the bob: a spring around rest, dipped by a jerk
        bob = u.clamp(bob + bv * h, -u.H * 0.1, u.H * 0.1);
      }
      u.sky(D.sky);
      var FY = u.H * 0.64;
      u.ground(FY, D.floor);
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, FY, u.W, u.H - FY); u.ctx.clip();
      u.ctx.translate(Math.sin(t * 2.1) * D.ripple, FY * 2); u.ctx.scale(1, -1);   // flip about the floor line, sliding a hair sideways
      u.ctx.globalAlpha = D.refA;
      object(ox, FY);
      u.ctx.globalAlpha = 1;
      u.ctx.restore();
      u.ctx.fillStyle = u.lin(0, FY, 0, FY + (u.H - FY) * D.fade, [u.rgba(D.floor, 0.25), u.rgba(D.floor, 1)]);   // the mask: the reflection dies with distance from the floor
      u.ctx.fillRect(0, FY, u.W, u.H - FY);
      for (var i = 0; i < 4; i++) u.line(0, FY + 6 + i * 11 + Math.sin(t + i) * 2, u.W, FY + 6 + i * 11 + Math.sin(t + i) * 2, u.rgba(D.ball, 0.06 + 0.03 * Math.sin(t * 3 + i)), 1);   // a few ripple lines
      object(ox, FY);
      u.label("a reflection is the picture flipped, dimmed, and faded out — the fade says 'this floor is a surface'", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { tx = u.clamp(x, u.W * 0.08, u.W * 0.92); }        // click = ask the object over; the spring does the moving
  };
});

def("B", "Bokeh", "shadow", "depth of field: lights at many depths; the ones on the focus plane are small and sharp, the ones far from it big, soft and dim — the plane slides; press sets it by y", function make(u) {
  var D = { sky: ["#0A0A18", "#1A1830"], hues: [40, 200, 320], n: 40, seed: 5,   // palette of the lights, how many
            blurK: 4, dimK: 6, sweep: 0.45 };                                    // how fast size grows / brightness drops with distance from focus; sweep speed of the plane
  var R = u.rng(D.seed), lights = [];
  for (var j = 0; j < D.n; j++) {
    var z = R();                                                                 // 0 far (high on the canvas) … 1 near (low)
    lights.push({ z: z, x: R() * u.W, y: u.H * (0.12 + (1 - z) * 0.62) + (R() - 0.5) * u.H * 0.08, hue: D.hues[j % D.hues.length] + R() * 25, ph: R() * 9 });
  }
  lights.sort(function (a, b) { return a.z - b.z; });                            // far first
  var focus = null;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var f = focus !== null ? focus : 0.5 + 0.45 * Math.sin(t * D.sweep * u.TAU);   // the focus plane, 0 far … 1 near
      var fy = u.H * (0.12 + (1 - f) * 0.62);
      u.line(0, fy, u.W, fy, u.rgba(u.INK, 0.12), 1);                            // where the plane cuts the picture
      for (var j = 0; j < lights.length; j++) {
        var L = lights[j], d = Math.abs(L.z - f), tw = 0.8 + 0.2 * Math.sin(t * 2 + L.ph);   // d: distance from focus
        var r = u.W * (0.008 + L.z * 0.012) * (1 + d * D.blurK), a = tw / (1 + d * D.dimK);  // out of focus = bigger, fainter
        var c = u.hsl(L.hue, 0.8, 0.65);
        if (d < 0.06) { u.dot(L.x, L.y, r, u.rgba(c, a)); u.soft(L.x, L.y, r * 2.5, c, a * 0.4); }   // sharp: a hard disc with a little glow
        else u.soft(L.x, L.y, r, c, a);                                          // soft: only the glow, wider
      }
      u.label("focus " + (f < 0.33 ? "far" : f < 0.66 ? "middle" : "near"), u.W - 8, fy - 4, u.rgba(u.INK, 0.5), "right");
      u.label("sharp = where the eye is looking; everything else grows into a soft disc — blur is a distance", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { focus = u.clamp(1 - (y / u.H - 0.12) / 0.62, 0, 1); }   // click = focus on that row
  };
});

def("T", "Tiltshift", "shadow", "a miniature: rows of little cubes, one sharp band across the middle and rows above and below drawn thrice with offsets — the fake blur makes a town look toy-sized", function make(u) {
  var D = { sky: ["#8AB8E8", "#D8E8F5"], floor: "#7A9A6A", cols: ["#F58A8A", "#F5C169", "#8AD9F5", "#C9A0F5", "#9BE28A", "#F5A15A"],
            rows: 5, perRow: 7, blur: 14, band: 0.5 };                            // rows of houses, houses per row, max ghost offset (px at 250 wide), where the sharp band sits (0 top … 1 bottom)
  var R = u.rng(23), town = [];
  for (var r = 0; r < D.rows; r++) for (var c = 0; c < D.perRow; c++)
    town.push({ r: r, c: c, h: 0.6 + R() * 1.2, col: D.cols[Math.floor(R() * D.cols.length)], dx: (R() - 0.5) * 0.4 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var HY = u.H * 0.3;
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.shade(D.floor, 0.25), u.shade(D.floor, -0.15)]); u.ctx.fillRect(0, HY, u.W, u.H - HY);
      var bandY = u.H * (0.3 + D.band * 0.6);
      for (var i = 0; i < town.length; i++) {
        var b = town[i], p = (b.r + 1) / D.rows;                                 // p: row depth, 1 = nearest
        var y = HY + p * p * (u.H - HY) * 0.9 + u.H * 0.03, s = u.W * (0.018 + p * 0.03);
        var x = u.W * ((b.c + 0.5 + b.dx) / D.perRow) * (0.7 + p * 0.4) + u.W * (0.15 - p * 0.2) + Math.sin(t * 0.3) * 4 * p;   // near rows spread wider
        var blur = Math.abs(y - bandY) / u.H * D.blur * (u.W / 250);          // ghost offset grows away from the sharp band
        var passes = blur < 0.7 ? 1 : 3;
        u.ctx.globalAlpha = passes === 1 ? 1 : 0.45;
        for (var k = 0; k < passes; k++) u.cube(x + (k - 1) * blur, y, s, b.col, { h: s * b.h });   // the same house three times = a smear
        u.ctx.globalAlpha = 1;
      }
      u.line(0, bandY, u.W, bandY, u.rgba(u.INK, 0.15), 1);
      u.label("sharp band — press to move it", u.W - 8, bandY - 4, u.rgba(u.INK, 0.5), "right");
      u.label("a real camera can only blur the near and far like this on a tiny scene — so the eye reads 'tiny'", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.band = u.clamp((y / u.H - 0.3) / 0.6, 0, 1); }
  };
});

def("V", "Vignette", "shadow", "the same view twice: plain on the left, on the right a radial darkening at the rim — the dark edges push the eye to the centre and the centre reads as far", function make(u) {
  var D = { sky: ["#3A5A9A", "#D8C8A8"], hill: "#4A6A4A", far: "#8A9AB8", sun: "#FFF3D0", tint: null,   // tint: an overall colour wash (null = none)
            inner: 0.35, dark: 0.8 };                                            // where the darkening starts (of the half-radius), how black the rim gets
  var vc = [0.5, 0.5];                                                           // vignette centre, as fractions of the half
  function scene(x0, w, t) {
    u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(x0, 0, w, u.H); u.ctx.clip();
    u.ctx.fillStyle = u.lin(0, 0, 0, u.H, [[0, D.sky[0]], [0.7, D.sky[1]]]); u.ctx.fillRect(x0, 0, w, u.H);
    var sx = x0 + w * 0.5, sy = u.H * 0.3 + Math.sin(t * 0.2) * u.H * 0.03;
    u.soft(sx, sy, w * 0.35, D.sun, 0.35); u.dot(sx, sy, w * 0.05, D.sun);
    u.poly([[x0, u.H * 0.62], [x0 + w * 0.3, u.H * 0.5], [x0 + w * 0.55, u.H * 0.58], [x0 + w * 0.8, u.H * 0.48], [x0 + w, u.H * 0.56], [x0 + w, u.H], [x0, u.H]], D.far);
    u.poly([[x0, u.H * 0.8], [x0 + w * 0.25, u.H * 0.7], [x0 + w * 0.5, u.H * 0.78], [x0 + w * 0.75, u.H * 0.68], [x0 + w, u.H * 0.76], [x0 + w, u.H], [x0, u.H]], D.hill);
    if (D.tint) { u.ctx.fillStyle = D.tint; u.ctx.fillRect(x0, 0, w, u.H); }
    u.ctx.restore();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var hw = u.W / 2;
      scene(0, hw, t);
      scene(hw, hw, t);
      var cx = hw + vc[0] * hw, cy = vc[1] * u.H, rr = Math.max(hw, u.H) * 0.85;
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(hw, 0, hw, u.H); u.ctx.clip();
      u.ctx.fillStyle = u.rad(cx, cy, rr, [[D.inner, "rgba(10,5,20,0)"], [1, "rgba(10,5,20," + D.dark + ")"]]);   // clear at the centre, dark at the rim
      u.ctx.fillRect(hw, 0, hw, u.H);
      u.ctx.restore();
      u.line(hw, 0, hw, u.H, u.rgba(u.INK, 0.5), 1);
      u.label("plain", 8, 14, u.rgba(u.INK, 0.6)); u.label("vignette", u.W - 8, 14, u.rgba(u.INK, 0.6), "right");
      u.label("one radial gradient over everything: the rim recedes, the centre comes forward — a lens, not a light", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { if (x > u.W / 2) vc = [(x - u.W / 2) / (u.W / 2), y / u.H]; }   // click on the right half = move the clear spot
  };
});

def("I", "Inkwash", "shadow", "a sumi-e landscape in one ink: five silhouette layers at rising alpha — far faint, near dark — and a few brush strokes; no colour at all, just value as distance", function make(u) {
  var D = { paper: "#F2EDE2", ink: "#1E2230", layers: 5, fill: true,             // paper, the one ink, how many ridges, painted (true) or outlined (false)
            farA: 0.12, nearA: 0.9, drift: 0.06, hues: ["#1E2230", "#2A1A3A", "#1A3A2A", "#3A1E1A"] };   // alpha of the farthest / nearest ridge, parallax speed, inks the press cycles through
  var R = u.rng(41), ridges = [], hue = 0;
  for (var j = 0; j < D.layers; j++) ridges.push({ y: 0.32 + j * 0.11, amp: 0.05 + R() * 0.05, f: 1.2 + R() * 2, ph: R() * 9 });
  return {
    frame: function (dt, t) {
      u.sky([D.paper, u.shade(D.paper, -0.06)]);
      for (var j = 0; j < ridges.length; j++) {
        var g = ridges[j], k = j / (ridges.length - 1), a = u.lerp(D.farA, D.nearA, k * k);   // alpha climbs toward the viewer
        var shift = t * D.drift * (0.3 + k) * u.W;                               // near ridges slide faster: parallax for free
        u.ctx.fillStyle = u.ctx.strokeStyle = u.rgba(D.ink, a); u.ctx.lineWidth = 1.5;
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += 5)
          u.ctx.lineTo(x, u.H * (g.y + Math.sin((x + shift) / u.W * g.f * u.TAU + g.ph) * g.amp + Math.sin((x + shift) * 0.05 + g.ph) * 0.012));
        u.ctx.lineTo(u.W, u.H);
        if (D.fill) { u.ctx.closePath(); u.ctx.fill(); } else u.ctx.stroke();
      }
      u.ctx.lineCap = "round";
      for (var s = 0; s < 4; s++) {                                              // reeds: a stroke that thins as it rises
        var bx = u.W * (0.12 + s * 0.09), sway = Math.sin(t * 1.2 + s) * 4;
        for (var seg = 0; seg < 5; seg++)
          u.line(bx + sway * seg / 5 * 0.4, u.H * (0.95 - seg * 0.05), bx + sway * (seg + 1) / 5 * 0.4 + 2, u.H * (0.9 - seg * 0.05), u.rgba(D.ink, 0.85), 3.5 - seg * 0.6);
      }
      u.ctx.lineCap = "butt";
      u.label("one ink, five alphas — the farthest ridge is mostly paper. That is atmospheric perspective with nothing else", u.W / 2, u.H - 8, u.rgba(D.ink, 0.65), "center");
    },
    press: function (x, y) { hue = (hue + 1) % D.hues.length; D.ink = D.hues[hue]; }   // click = another ink
  };
});

def("N", "Noir", "shadow", "hard light through a blind: bright bars across a dark room and a sphere — the bars shift where they cross the ball, and that shift is its roundness; press moves the light angle", function make(u) {
  var D = { room: "#0C0A14", wall: "#1A1622", light: "#F5E6C0", ball: "#3A3A4A",
            angle: -0.55, gap: 0.09, barK: 0.45, speed: 0.06, bend: 0.4 };       // bar angle (radians; 0 = horizontal, π/2 = vertical), spacing (of W), lit share of each gap, drift, how far the bars jump on the ball (× radius)
  var angle0 = D.angle;                                                          // the press swings the light around this resting angle
  function bars(offset, alpha) {                                                 // parallel stripes covering the canvas, rotated by the angle
    var gap = u.W * D.gap, n = Math.ceil((u.W + u.H) * 2 / gap) + 2;
    u.ctx.save(); u.ctx.translate(u.W / 2, u.H / 2); u.ctx.rotate(D.angle);
    u.ctx.fillStyle = u.rgba(D.light, alpha);
    for (var i = -n; i < n; i++) u.ctx.fillRect(-u.W - u.H, i * gap + offset, (u.W + u.H) * 2, gap * D.barK);
    u.ctx.restore();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([D.room, D.wall]);
      var GY = u.H * 0.78, r = u.W * 0.13, ox = u.W * 0.5, oy = GY - r;
      var off = (t * D.speed * u.W) % (u.W * D.gap);                             // the sun crawls: bars drift across the room
      u.ground(GY, u.shade(D.wall, -0.3));
      bars(off, 0.18);                                                           // on the wall and floor: dim, flat
      u.shadow(ox, GY, r * 1.2, r * 0.3, 0.8);
      u.sphere(ox, oy, r, D.ball, Math.sin(D.angle), -0.7, { spec: 0.15, dark: "#08080E" });
      u.ctx.save(); u.ctx.beginPath(); u.ctx.arc(ox, oy, r, 0, u.TAU); u.ctx.clip();   // on the ball: the same bars, brighter, shifted toward the light
      bars(off + r * D.bend, 0.5);
      u.ctx.fillStyle = u.rad(ox, oy, r, [[0.5, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,0.6)"]], -r * 0.3, -r * 0.4);   // and they dim at the ball's edge, where it turns away
      u.ctx.beginPath(); u.ctx.arc(ox, oy, r, 0, u.TAU); u.ctx.fill();
      u.ctx.restore();
      u.label("stripes that agree are a wall; stripes that jump are a thing in front of it — hard light draws form by breaking pattern", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.angle = angle0 + (x / u.W - 0.5) * 1.0; }        // click left or right = swing the light half a radian either way
  };
});

def("X", "Xray", "shadow", "three translucent panes over a scene: where they overlap they darken more, so the stacking order shows — a lens follows the pointer and shows the panes sharp inside, faint outside", function make(u) {
  var D = { sky: ["#F0ECE4", "#D8D2C4"], panes: ["#F58A8A", "#8AD9F5", "#F5C169"], ink: "#3A2A2A",
            alpha: 0.55, outside: 0.3, blend: "multiply", lensR: 0.28, drift: 0.8 };   // pane alpha inside the lens, alpha outside, how panes combine, lens radius (of W), pane drift speed
  var lens = null;
  function scene(t) {
    u.sky(D.sky);
    u.ground(u.H * 0.72, "#B8B0A0");
    u.sphere(u.W * 0.3, u.H * 0.6, u.W * 0.08, "#9BE28A", -0.5, -0.6, { spec: 0.4 });
    u.cube(u.W * 0.62, u.H * 0.72, u.W * 0.08, "#C9A0F5");
    u.dot(u.W * 0.8, u.H * 0.25, u.W * 0.05, "#FFF3D0");
  }
  function panes(t, a) {                                                         // three overlapping sheets, each drifting on its own sine
    u.ctx.save(); u.ctx.globalCompositeOperation = D.blend;
    for (var i = 0; i < D.panes.length; i++) {
      var w = u.W * 0.42, h = u.H * 0.5;
      var x = u.W * (0.15 + i * 0.18) + Math.sin(t * D.drift + i * 2) * u.W * 0.06, y = u.H * (0.15 + i * 0.1) + Math.cos(t * D.drift * 0.7 + i) * u.H * 0.05;
      u.ctx.fillStyle = u.rgba(D.panes[i], a); u.ctx.fillRect(x, y, w, h);
      u.ctx.strokeStyle = u.rgba(D.ink, a * 0.8); u.ctx.lineWidth = 1; u.ctx.strokeRect(x, y, w, h);
    }
    u.ctx.restore();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      scene(t);
      panes(t, D.outside);                                                       // faint everywhere…
      var lx = lens ? lens[0] : u.W * (0.5 + 0.3 * Math.sin(t * 0.6)), ly = lens ? lens[1] : u.H * (0.5 + 0.2 * Math.cos(t * 0.45)), R = u.W * D.lensR;
      u.ctx.save(); u.ctx.beginPath(); u.ctx.arc(lx, ly, R, 0, u.TAU); u.ctx.clip();
      scene(t); panes(t, D.alpha);                                               // …full strength inside the lens
      u.ctx.restore();
      u.ctx.strokeStyle = u.rgba(D.ink, 0.6); u.ctx.lineWidth = 2; u.ctx.beginPath(); u.ctx.arc(lx, ly, R, 0, u.TAU); u.ctx.stroke();
      u.label("where two panes cross the colour multiplies: darker means more layers — depth counted in sheets", u.W / 2, u.H - 8, u.rgba(D.ink, 0.7), "center");
    },
    press: function (x, y) { lens = [x, y]; }
  };
});

/* ---- the rhymes: same pictures, two or three dials moved ---- */

rhymeOf("Contact", "Balloon contact", "the same ball filled with helium: the target height drifts UP instead of down, so it floats — and its shadow is half as dark; press pulls it toward the floor", function make(u) {
  // rhyme of Contact: dials moved — float -0.25 → +0.08 (rises on its own), shadowA 0.6 → 0.3, ball colour to pastel
  var D = { sky: ["#2A2F4A", "#4A5578"], floor: "#5A6080", ball: "#F5C8E0",
            shadowA: 0.3, float: 0.08, lift: 0.4 };
  var h = 0, v = 0, target = 0;
  return {
    frame: function (dt, t) {
      dt = Math.min(dt, 0.05);
      target = u.clamp(target + D.float * dt, 0, 0.5);
      v += (target - h) * 60 * dt; v -= v * 4 * dt; h += v * dt;
      if (h < 0) { h = 0; v = -v * 0.3; }
      u.sky(D.sky);
      var GY = u.H * 0.78, r = u.W * 0.085, x = u.W * 0.5, hp = h * u.H;
      u.ground(GY, D.floor);
      var k = 1 / (1 + hp / (r * 0.9));
      u.shadow(x, GY, r * (0.5 + 0.7 * k) + hp * 0.25, r * (0.2 + 0.2 * k) + hp * 0.08, D.shadowA * 0.35 * k);
      u.shadow(x, GY, r * (0.35 + 0.75 * k), r * (0.14 + 0.22 * k), D.shadowA * k);
      u.sphere(x, GY - r - hp, r, D.ball, -0.4, -0.6, { spec: 0.4 });
      u.label("height: " + (hp / r).toFixed(1) + " radii", x, GY - r * 2 - hp - 8, u.rgba(u.INK, 0.7), "center");
      u.label("flip the sign of one dial and a ball becomes a balloon — the faint shadow says 'light, and high'", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { target = u.clamp((u.H * 0.78 - y) / u.H, 0.05, 0.5); v += D.lift; }
  };
});

rhymeOf("Jump", "Pixel jump", "the same two hoppers in an arcade palette — a navy sky, neon grass — hopping half again as high and half again as often", function make(u) {
  // rhyme of Jump: dials moved — palette to arcade, hop 0.24 → 0.38, hops 1.1 → 1.6
  var D = { sky: ["#000020", "#20206A"], floor: "#1A6A1A", grass: "#40C040", ball: "#FFE040", ghost: "#40E0FF",
            hop: 0.38, hops: 1.6, speed: 0.12,
            air: 0.7, rebound: 0.25, squash: 0.3 };
  var hgt = 0, v = 0, sq = 0, sqv = 0, stance = 0, crouched = true;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var GY = u.H * 0.8, r = u.W * 0.05;
      u.ctx.fillStyle = u.lin(0, GY, 0, u.H, [D.grass, D.floor]); u.ctx.fillRect(0, GY, u.W, u.H - GY);
      var P = 1 / D.hops, flight = P * D.air, hp = D.hop * u.H;
      var g = 8 * hp / (flight * flight), v0 = Math.sqrt(2 * g * hp);
      var sk = 400, sw = Math.sqrt(sk), sd = 0.3 * 2 * sw;
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      for (var s = 0; s < sub; s++) {
        if (hgt > 0 || v > 0) {
          v -= g * h; hgt += v * h;
          if (hgt <= 0) {
            hgt = 0;
            sqv -= D.squash * 1.6 * sw * Math.min(1, -v / v0);
            v = -v * D.rebound;
            if (v < 0.15 * v0) v = 0;
            if (stance < 0) { stance = 0; crouched = false; }
          }
        }
        if (stance >= 0) {
          stance += h;
          if (!crouched && stance > P - flight - 0.12) { crouched = true; sqv -= D.squash * 0.8 * sw; }
          if (stance >= P - flight && hgt === 0 && v === 0) { stance = -1; v = v0; sqv += D.squash * 0.6 * sw; }
        }
        sqv += (sk * (0 - sq) - sd * sqv) * h; sq = u.clamp(sq + sqv * h, -0.6, 0.6);
      }
      var x1 = ((t * D.speed) % 1) * (u.W + 4 * r) - 2 * r;
      var x2 = ((t * D.speed + 0.5) % 1) * (u.W + 4 * r) - 2 * r;
      var k = 1 / (1 + hgt / (r * 1.2));
      var sx = 1 - sq * 0.6, sy = 1 + sq;
      u.shadow(x1, GY, r * (0.4 + 0.9 * k) * sx, r * (0.15 + 0.25 * k), 0.55 * k);
      u.ctx.save(); u.ctx.translate(x1, GY - hgt); u.ctx.scale(sx, sy);
      u.sphere(0, -r, r, D.ball, -0.4, -0.6, { spec: 0.4 });
      u.ctx.restore();
      u.ctx.save(); u.ctx.translate(x2, GY - hgt); u.ctx.scale(sx, sy);
      u.sphere(0, -r, r, D.ghost, -0.4, -0.6, { spec: 0.4 });
      u.ctx.restore();
      u.label("which one is jumping?", u.W / 2, u.H * 0.14, u.rgba(u.INK, 0.7), "center");
      u.label("every platformer since 1985: the shadow disc under the hero is the whole sense of landing", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.hop = 0.08 + (1 - y / u.H) * 0.32; }
  };
});

rhymeOf("Longshadow", "Noon", "the same posts under a high sun — elevation 72° instead of 18° — so the shadows are stubs at their feet; a bright, flat midday", function make(u) {
  // rhyme of Longshadow: dials moved — elev 0.32 → 1.25, sky/floor palette to noon, shadowA 0.35 → 0.45
  var D = { sky: ["#3A7AD8", "#CFE6F5"], floor: "#E8D8B8", post: "#4A3A6A", sun: "#FFFFFF",
            elev: 1.25, dir: 1, tilt: 0.28, posts: 5, shadowA: 0.45 };
  var R = u.rng(31), posts = [];
  for (var j = 0; j < D.posts; j++) posts.push({ x: 0.12 + j * 0.76 / (D.posts - 1) + (R() - 0.5) * 0.06, h: 0.16 + R() * 0.2, w: 0.035 + R() * 0.02 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var HY = u.H * 0.42, GY = u.H * 0.7;
      var el = u.clamp(D.elev + Math.sin(t * 0.35) * 0.08, 0.12, 1.45);
      var stretch = 1 / Math.tan(el);
      var sx = D.dir > 0 ? u.W * 0.1 : u.W * 0.9, sy = HY - Math.sin(el) * u.H * 0.4;
      u.soft(sx, sy, u.W * 0.3, D.sun, 0.5); u.dot(sx, sy, u.W * 0.035, D.sun);
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.shade(D.floor, 0.1), u.shade(D.floor, -0.25)]);
      u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (var j = 0; j < posts.length; j++) {
        var p = posts[j], x0 = p.x * u.W, w = p.w * u.W, h = p.h * u.H, L = h * stretch;
        var dx = L * D.dir, dy = L * D.tilt;
        u.poly([[x0, GY], [x0 + w, GY], [x0 + w + dx, GY + dy], [x0 + dx, GY + dy]], "rgba(20,10,40," + D.shadowA + ")");
      }
      for (var j = 0; j < posts.length; j++) {
        var p = posts[j], x0 = p.x * u.W, w = p.w * u.W, h = p.h * u.H;
        u.ctx.fillStyle = u.lin(x0, 0, x0 + w, 0, D.dir > 0 ? [u.shade(D.post, 0.3), u.shade(D.post, -0.3)] : [u.shade(D.post, -0.3), u.shade(D.post, 0.3)]);
        u.ctx.fillRect(x0, GY - h, w, h);
      }
      u.label("elevation " + Math.round(el * 57.3) + "°: shadow = " + stretch.toFixed(1) + "× the post's height", u.W / 2, u.H * 0.1, u.rgba("#20183A", 0.6), "center");
      u.label("same code, sun moved: short shadows read as noon, and the scene goes flat — length IS the hour", u.W / 2, u.H - 8, u.rgba("#20183A", 0.7), "center");
    },
    press: function (x, y) { D.dir = x < u.W / 2 ? 1 : -1; D.elev = 0.15 + (1 - y / u.H) * 1.2; }
  };
});

rhymeOf("Ambient", "Marshmallow blocks", "the same cubes in pastel pink and cream with the AO half as dark and half again as wide — squishy, sugar-soft blocks", function make(u) {
  // rhyme of Ambient: dials moved — palette to pastel, aoA 0.32 → 0.18, aoR 0.85 → 1.25
  var D = { sky: ["#F8E8F0", "#F0D8E8"], floor: "#E8C8D8", cube: "#F8E0EA",
            faceDiff: 0.05, ao: true, aoA: 0.18, aoR: 1.25 };
  var cells = [[0, 0, 0], [1, 0, 0], [2, 0, 0], [0, 1, 0], [1, 1, 0], [2, 1, 0], [0, 2, 0], [1, 2, 0], [2, 2, 0], [1, 1, 1], [2, 0, 1], [0, 2, 1]];
  cells.sort(function (a, b) { return (a[0] + a[1] + a[2] * 0.1) - (b[0] + b[1] + b[2] * 0.1); });
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      var s = u.W * 0.085, cx = u.W * 0.5, cy = u.H * 0.7;
      u.ground(u.H * 0.55, D.floor);
      var c = D.cube, faces = { top: u.shade(c, D.faceDiff), left: c, right: u.shade(c, -D.faceDiff) };
      for (var i = 0; i < cells.length; i++) {
        var q = cells[i], lift = q[2] === 1 && q[0] === 1 ? (0.5 + 0.5 * Math.sin(t * 0.9)) * 0.9 : 0;
        var p = u.iso(q[0] - 1, q[1] - 1, q[2] + lift, s), x = cx + p[0], y = cy + p[1];
        var a = D.aoA / (1 + lift * 3);
        if (D.ao) {
          u.soft(x, y, s * D.aoR, "#8A4A6A", a);
          u.soft(x - s * 0.866, y - s * 0.5, s * D.aoR * 0.7, "#8A4A6A", a * 0.7);
          u.soft(x + s * 0.866, y - s * 0.5, s * D.aoR * 0.7, "#8A4A6A", a * 0.7);
        }
        u.cube(x, y, s, c, faces);
      }
      u.label(D.ao ? "AO on — press to switch it off" : "AO off — press to switch it on", u.W / 2, u.H * 0.1, u.rgba("#8A4A6A", 0.6), "center");
      u.label("wider, fainter occlusion reads as a softer material — the AO dial is also a hardness dial", u.W / 2, u.H - 8, u.rgba("#8A4A6A", 0.7), "center");
    },
    press: function (x, y) { D.ao = !D.ao; }
  };
});

rhymeOf("Umbra", "Spotlight", "the same lamp shrunk to a point — a fifteenth of the width — so the shadow has no penumbra at all: one hard edge on a theatre floor", function make(u) {
  // rhyme of Umbra: dials moved — lightW 0.3 → 0.02, steps 9 → 3, palette to a red-curtain theatre
  var D = { sky: ["#1A0A10", "#2A1018"], floor: "#3A1A22", ball: "#F5C169", lamp: "#FFFFFF",
            lightW: 0.02, lightX: 0.3, lightY: 0.12, steps: 3, shadowA: 0.6 };
  var lx = null, ly = null;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var GY = u.H * 0.8, r = u.W * 0.08, ox = u.W * 0.55, oy = GY - r;
      var LX = lx !== null ? lx : u.W * (D.lightX + 0.12 * Math.sin(t * 0.5)), LY = ly !== null ? ly : u.H * D.lightY;
      var LW = u.W * D.lightW;
      u.ground(GY, D.floor);
      var drop = GY - oy, rise = Math.max(20, oy - LY);
      var sx = ox + (ox - LX) * drop / rise;
      var pen = LW * drop / rise;
      var core = r * (1 + drop / rise);
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, GY, u.W, u.H - GY); u.ctx.clip();
      for (var i = D.steps - 1; i >= 0; i--) {
        var k = i / (D.steps - 1), rx = Math.max(1, core - pen * 0.5 + pen * k), ry = rx * 0.32;
        u.ctx.fillStyle = "rgba(0,0,10," + (D.shadowA / D.steps * 1.4).toFixed(3) + ")";
        u.ctx.beginPath(); u.ctx.ellipse(sx, GY + 1, rx, ry, 0, 0, u.TAU); u.ctx.fill();
      }
      u.ctx.restore();
      var dx = LX - ox, dy = LY - oy, len = Math.sqrt(dx * dx + dy * dy) || 1;
      u.sphere(ox, oy, r, D.ball, dx / len, dy / len, { spec: 0.4, rim: D.lamp });
      u.soft(LX, LY, LW * 6, D.lamp, 0.25);
      u.ctx.fillStyle = D.lamp; u.ctx.fillRect(LX - LW / 2, LY - 3, LW, 6);
      u.label("a tiny light is all umbra: the shadow's edge is as sharp as the ball's — stage lighting in one dial", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { lx = x; ly = Math.min(y, u.H * 0.55); }
  };
});

rhymeOf("Occlusion", "Card shuffle", "the same five things as playing cards on green felt, shuffling at nearly four times the speed — overlap still says who is on top", function make(u) {
  // rhyme of Occlusion: dials moved — shape disc → rect, speed 0.6 → 2.2, palette to cards on felt
  var D = { sky: ["#1A5A3A", "#0E3A26"], disc: "#F5F0E8", edge: "#B02030", n: 5, speed: 2.2, shape: "rect", flip: false };
  var R = u.rng(17), items = [];
  for (var j = 0; j < D.n; j++) items.push({ ph: j / D.n * u.TAU, ry: 0.28 + R() * 0.14, sp: 0.7 + R() * 0.6, x: 0, y: 0, z: 0 });
  var order = [];
  for (var k = 0; k < D.n; k++) order.push(k);
  return {
    frame: function (dt, t) {
      u.sky(D.sky);
      for (var j = 0; j < items.length; j++) {
        var it = items[j], a = t * D.speed * it.sp + it.ph;
        it.z = 0.5 + 0.5 * Math.sin(a);
        it.x = u.W * 0.5 + Math.cos(a) * u.W * 0.3; it.y = u.H * 0.48 + (it.z - 0.5) * u.H * it.ry;
      }
      order.sort(function (a, b) { return D.flip ? items[b].z - items[a].z : items[a].z - items[b].z; });
      for (var o = 0; o < order.length; o++) {
        var d = items[order[o]], r = u.W * (0.05 + d.z * 0.07);
        u.ctx.fillStyle = D.disc; u.ctx.strokeStyle = D.edge; u.ctx.lineWidth = 1.5;
        u.ctx.beginPath();
        if (D.shape === "disc") u.ctx.arc(d.x, d.y, r, 0, u.TAU); else u.ctx.rect(d.x - r * 0.8, d.y - r * 1.1, r * 1.6, r * 2.2);
        u.ctx.fill(); u.ctx.stroke();
      }
      u.label(D.flip ? "sorted near → far: the small ones cover the big ones and depth breaks" : "sorted far → near: the last drawn wins the overlap", u.W / 2, u.H * 0.1, u.rgba("#F5F0E8", 0.6), "center");
      u.label("a card game is a z-sort you can see — the deck is the painter's algorithm made of paper", u.W / 2, u.H - 8, u.rgba("#F5F0E8", 0.7), "center");
    },
    press: function (x, y) { D.flip = !D.flip; }
  };
});

rhymeOf("Ground", "Synthwave grid", "the same floor in hot pink on black with a cyan ball — 16 rows, half the fog, so the grid stays crisp all the way to the horizon", function make(u) {
  // rhyme of Ground: dials moved — palette to neon on black, rows 12 → 16, fogK 0.9 → 0.5
  var D = { sky: ["#0A0018", "#2A0040"], floor: "#000000", lines: "#FF2A9A", ball: "#40E0FF",
            rows: 16, cols: 9, fogK: 0.5, speed: 0.15,
            damp: 0.5, steer: 40 };
  var vx = u.W * 0.5, vxT = vx, vv = 0;
  var q = 0.9, qv = 0, tgt = 0.18;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var w = u.TAU * D.speed, k = w * w, dd = D.damp * 2 * w;
      var sd = 0.9 * 2 * Math.sqrt(D.steer);
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      for (var s = 0; s < sub; s++) {
        vv += (D.steer * (vxT - vx) - sd * vv) * h; vx = u.clamp(vx + vv * h, -u.W, 2 * u.W);
        var was = qv;
        qv += (k * (tgt - q) - dd * qv) * h; q = u.clamp(q + qv * h, 0, 1.15);
        var still = (was !== 0 && (was < 0) !== (qv < 0)) || (Math.abs(q - tgt) < 0.005 && Math.abs(qv) < 0.02);
        if (still && Math.abs(q - tgt) < 0.3) tgt = tgt < 0.5 ? 0.9 : 0.18;
      }
      u.sky(D.sky);
      var HY = u.H * 0.42, air = D.sky[1];
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.mix(D.floor, air, D.fogK), D.floor]); u.ctx.fillRect(0, HY, u.W, u.H - HY);
      for (var i = 1; i <= D.rows; i++) {
        var p = i / D.rows, y = HY + p * p * (u.H - HY);
        u.line(0, y, u.W, y, u.rgba(D.lines, 0.1 + p * 0.5), 1);
      }
      for (var j = 0; j <= D.cols; j++) {
        var bx = vx + (j / D.cols - 0.5) * u.W * 2.4;
        u.ctx.strokeStyle = u.lin(0, HY, 0, u.H, [u.rgba(D.lines, 0), u.rgba(D.lines, 0.55)]);
        u.ctx.lineWidth = 1; u.ctx.beginPath(); u.ctx.moveTo(vx, HY); u.ctx.lineTo(bx, u.H); u.ctx.stroke();
      }
      var qd = u.clamp(q, 0, 1);
      var by = HY + q * q * (u.H - HY), bx2 = u.lerp(vx, u.W * 0.62, q), r = u.W * 0.02 + q * q * u.W * 0.07;
      u.shadow(bx2, by, r * 1.15, r * 0.35, 0.5 * (0.3 + qd * 0.7));
      u.sphere(bx2, by - r, r, u.fog(D.ball, (1 - qd) * D.fogK, air), -0.4, -0.6, { spec: 0.35 });
      u.label("less fog, more rows: the same p² floor turns from a foggy street into a poster — the maths is the genre's", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { vxT = x; }
  };
});

rhymeOf("Mirror", "Ice reflection", "the same object over a frozen lake — pale blues, a brighter reflection that dies quicker, a fifth of the ripple: glassy and still", function make(u) {
  // rhyme of Mirror: dials moved — palette to ice, refA 0.55 → 0.75, fade 0.8 → 0.45, ripple 2.0 → 0.4
  var D = { sky: ["#C8DCF0", "#E8F0F8"], floor: "#A8C8E0", ball: "#5A8AC8", block: "#7AA0C8",
            refA: 0.75, fade: 0.45, ripple: 0.4,
            slide: 30, swing: 25, hover: 1.5 };
  var ox = u.W * 0.5, tx = ox, ov = 0;
  var sway = 0, swv = 0, bob = 0, bv = 0, clk = 0;
  function object(x, FY) {
    var s = u.W * 0.07;
    u.cube(x, FY, s, D.block);
    u.sphere(x + sway, FY - s - s * 0.9 - bob - u.H * 0.03, s * 0.8, D.ball, -0.5, -0.6, { spec: 0.4, rim: "#8AD9F5" });
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var kd = 0.6 * 2 * Math.sqrt(D.slide), sd = 0.2 * 2 * Math.sqrt(D.swing);
      var kb = 16, bd = 0.12 * 2 * Math.sqrt(kb);
      var sub = Math.max(1, Math.ceil(dt * 50)), h = dt / sub;
      for (var s = 0; s < sub; s++) {
        var acc = D.slide * (tx - ox) - kd * ov;
        ov += acc * h; ox = u.clamp(ox + ov * h, u.W * 0.08, u.W * 0.92);
        swv += (D.swing * (0 - sway) - sd * swv - acc * 0.4) * h;
        sway = u.clamp(sway + swv * h, -u.W * 0.1, u.W * 0.1);
        clk += h;
        if (clk >= D.hover) { clk -= D.hover; bv += u.H * 0.08; }
        bv += (kb * (0 - bob) - bd * bv - Math.abs(acc) * 0.05) * h;
        bob = u.clamp(bob + bv * h, -u.H * 0.1, u.H * 0.1);
      }
      u.sky(D.sky);
      var FY = u.H * 0.64;
      u.ground(FY, D.floor);
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(0, FY, u.W, u.H - FY); u.ctx.clip();
      u.ctx.translate(Math.sin(t * 2.1) * D.ripple, FY * 2); u.ctx.scale(1, -1);
      u.ctx.globalAlpha = D.refA;
      object(ox, FY);
      u.ctx.globalAlpha = 1;
      u.ctx.restore();
      u.ctx.fillStyle = u.lin(0, FY, 0, FY + (u.H - FY) * D.fade, [u.rgba(D.floor, 0.25), u.rgba(D.floor, 1)]);
      u.ctx.fillRect(0, FY, u.W, u.H - FY);
      for (var i = 0; i < 4; i++) u.line(0, FY + 6 + i * 11 + Math.sin(t + i) * 2, u.W, FY + 6 + i * 11 + Math.sin(t + i) * 2, u.rgba(D.ball, 0.06 + 0.03 * Math.sin(t * 3 + i)), 1);
      object(ox, FY);
      u.label("a sharper, brighter, shorter reflection reads as ice, not water — three dials say what the floor is made of", u.W / 2, u.H - 8, u.rgba("#1A2A4A", 0.7), "center");
    },
    press: function (x, y) { tx = u.clamp(x, u.W * 0.08, u.W * 0.92); }
  };
});

rhymeOf("Bokeh", "City bokeh", "the same lights at night, seventy of them in amber and cyan — street lamps and shop signs — with the focus sweeping half as fast", function make(u) {
  // rhyme of Bokeh: dials moved — hues to amber/cyan, n 40 → 70, sweep 0.25 → 0.12, sky darker
  var D = { sky: ["#050510", "#0E0E1E"], hues: [35, 195], n: 70, seed: 5,
            blurK: 4, dimK: 6, sweep: 0.12 };
  var R = u.rng(D.seed), lights = [];
  for (var j = 0; j < D.n; j++) {
    var z = R();
    lights.push({ z: z, x: R() * u.W, y: u.H * (0.12 + (1 - z) * 0.62) + (R() - 0.5) * u.H * 0.08, hue: D.hues[j % D.hues.length] + R() * 25, ph: R() * 9 });
  }
  lights.sort(function (a, b) { return a.z - b.z; });
  var focus = null;
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var f = focus !== null ? focus : 0.5 + 0.45 * Math.sin(t * D.sweep * u.TAU);
      var fy = u.H * (0.12 + (1 - f) * 0.62);
      u.line(0, fy, u.W, fy, u.rgba(u.INK, 0.12), 1);
      for (var j = 0; j < lights.length; j++) {
        var L = lights[j], d = Math.abs(L.z - f), tw = 0.8 + 0.2 * Math.sin(t * 2 + L.ph);
        var r = u.W * (0.008 + L.z * 0.012) * (1 + d * D.blurK), a = tw / (1 + d * D.dimK);
        var c = u.hsl(L.hue, 0.8, 0.65);
        if (d < 0.06) { u.dot(L.x, L.y, r, u.rgba(c, a)); u.soft(L.x, L.y, r * 2.5, c, a * 0.4); }
        else u.soft(L.x, L.y, r, c, a);
      }
      u.label("focus " + (f < 0.33 ? "far" : f < 0.66 ? "middle" : "near"), u.W - 8, fy - 4, u.rgba(u.INK, 0.5), "right");
      u.label("two hues and more of them: warm near, cool far is the city's own colour temperature — the blur rule is unchanged", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { focus = u.clamp(1 - (y / u.H - 0.12) / 0.62, 0, 1); }
  };
});

rhymeOf("Tiltshift", "Toy town", "the same miniature in candy colours with seven rows instead of five and a stronger smear — a sweet-shop diorama", function make(u) {
  // rhyme of Tiltshift: dials moved — palette to candy, rows 5 → 7, blur 14 → 20
  var D = { sky: ["#F5C8E0", "#FFF0F5"], floor: "#A8E0C8", cols: ["#FF6FA0", "#FFD060", "#60D0FF", "#C080FF", "#80F090", "#FF9060"],
            rows: 7, perRow: 7, blur: 20, band: 0.5 };
  var R = u.rng(23), town = [];
  for (var r = 0; r < D.rows; r++) for (var c = 0; c < D.perRow; c++)
    town.push({ r: r, c: c, h: 0.6 + R() * 1.2, col: D.cols[Math.floor(R() * D.cols.length)], dx: (R() - 0.5) * 0.4 });
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky(D.sky);
      var HY = u.H * 0.3;
      u.ctx.fillStyle = u.lin(0, HY, 0, u.H, [u.shade(D.floor, 0.25), u.shade(D.floor, -0.15)]); u.ctx.fillRect(0, HY, u.W, u.H - HY);
      var bandY = u.H * (0.3 + D.band * 0.6);
      for (var i = 0; i < town.length; i++) {
        var b = town[i], p = (b.r + 1) / D.rows;
        var y = HY + p * p * (u.H - HY) * 0.9 + u.H * 0.03, s = u.W * (0.018 + p * 0.03);
        var x = u.W * ((b.c + 0.5 + b.dx) / D.perRow) * (0.7 + p * 0.4) + u.W * (0.15 - p * 0.2) + Math.sin(t * 0.3) * 4 * p;
        var blur = Math.abs(y - bandY) / u.H * D.blur * (u.W / 250);
        var passes = blur < 0.7 ? 1 : 3;
        u.ctx.globalAlpha = passes === 1 ? 1 : 0.45;
        for (var k = 0; k < passes; k++) u.cube(x + (k - 1) * blur, y, s, b.col, { h: s * b.h });
        u.ctx.globalAlpha = 1;
      }
      u.line(0, bandY, u.W, bandY, u.rgba("#4A2A4A", 0.2), 1);
      u.label("sharp band — press to move it", u.W - 8, bandY - 4, u.rgba("#4A2A4A", 0.5), "right");
      u.label("more rows and more smear: the thinner the sharp slice, the smaller the town feels", u.W / 2, u.H - 8, u.rgba("#4A2A4A", 0.7), "center");
    },
    press: function (x, y) { D.band = u.clamp((y / u.H - 0.3) / 0.6, 0, 1); }
  };
});

rhymeOf("Vignette", "Old photo", "the same two views in sepia with a brown wash and a tighter, blacker rim — the vignette an old lens gave for free", function make(u) {
  // rhyme of Vignette: dials moved — palette to sepia, tint null → a brown wash, inner 0.35 → 0.2, dark 0.8 → 0.92
  var D = { sky: ["#5A4A3A", "#D8C8A8"], hill: "#6A5A3A", far: "#9A8A6A", sun: "#F5E6C0", tint: "rgba(120,80,40,0.25)",
            inner: 0.2, dark: 0.92 };
  var vc = [0.5, 0.5];
  function scene(x0, w, t) {
    u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(x0, 0, w, u.H); u.ctx.clip();
    u.ctx.fillStyle = u.lin(0, 0, 0, u.H, [[0, D.sky[0]], [0.7, D.sky[1]]]); u.ctx.fillRect(x0, 0, w, u.H);
    var sx = x0 + w * 0.5, sy = u.H * 0.3 + Math.sin(t * 0.2) * u.H * 0.03;
    u.soft(sx, sy, w * 0.35, D.sun, 0.35); u.dot(sx, sy, w * 0.05, D.sun);
    u.poly([[x0, u.H * 0.62], [x0 + w * 0.3, u.H * 0.5], [x0 + w * 0.55, u.H * 0.58], [x0 + w * 0.8, u.H * 0.48], [x0 + w, u.H * 0.56], [x0 + w, u.H], [x0, u.H]], D.far);
    u.poly([[x0, u.H * 0.8], [x0 + w * 0.25, u.H * 0.7], [x0 + w * 0.5, u.H * 0.78], [x0 + w * 0.75, u.H * 0.68], [x0 + w, u.H * 0.76], [x0 + w, u.H], [x0, u.H]], D.hill);
    if (D.tint) { u.ctx.fillStyle = D.tint; u.ctx.fillRect(x0, 0, w, u.H); }
    u.ctx.restore();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      var hw = u.W / 2;
      scene(0, hw, t);
      scene(hw, hw, t);
      var cx = hw + vc[0] * hw, cy = vc[1] * u.H, rr = Math.max(hw, u.H) * 0.85;
      u.ctx.save(); u.ctx.beginPath(); u.ctx.rect(hw, 0, hw, u.H); u.ctx.clip();
      u.ctx.fillStyle = u.rad(cx, cy, rr, [[D.inner, "rgba(10,5,20,0)"], [1, "rgba(10,5,20," + D.dark + ")"]]);
      u.ctx.fillRect(hw, 0, hw, u.H);
      u.ctx.restore();
      u.line(hw, 0, hw, u.H, u.rgba(u.INK, 0.5), 1);
      u.label("plain", 8, 14, u.rgba(u.INK, 0.6)); u.label("vignette", u.W - 8, 14, u.rgba(u.INK, 0.6), "right");
      u.label("a wash plus a heavier rim: the same gradient now says 'long ago' as well as 'look here'", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { if (x > u.W / 2) vc = [(x - u.W / 2) / (u.W / 2), y / u.H]; }
  };
});

rhymeOf("Inkwash", "Blueprint", "the same ridges as white outlines on drafting blue — value inverted: the near ridge is the brightest line, the far one nearly vanishes into the paper", function make(u) {
  // rhyme of Inkwash: dials moved — paper/ink swapped to white-on-blue, fill true → false (outlines), farA 0.12 → 0.2
  var D = { paper: "#1A3A8A", ink: "#E8F0FF", layers: 5, fill: false,
            farA: 0.2, nearA: 1.0, drift: 0.02, hues: ["#E8F0FF", "#8AD9F5", "#F5F0C0", "#FFB0C0"] };
  var R = u.rng(41), ridges = [], hue = 0;
  for (var j = 0; j < D.layers; j++) ridges.push({ y: 0.32 + j * 0.11, amp: 0.05 + R() * 0.05, f: 1.2 + R() * 2, ph: R() * 9 });
  return {
    frame: function (dt, t) {
      u.sky([D.paper, u.shade(D.paper, -0.06)]);
      for (var j = 0; j < ridges.length; j++) {
        var g = ridges[j], k = j / (ridges.length - 1), a = u.lerp(D.farA, D.nearA, k * k);
        var shift = t * D.drift * (0.3 + k) * u.W;
        u.ctx.fillStyle = u.ctx.strokeStyle = u.rgba(D.ink, a); u.ctx.lineWidth = 1.5;
        u.ctx.beginPath(); u.ctx.moveTo(0, u.H);
        for (var x = 0; x <= u.W; x += 5)
          u.ctx.lineTo(x, u.H * (g.y + Math.sin((x + shift) / u.W * g.f * u.TAU + g.ph) * g.amp + Math.sin((x + shift) * 0.05 + g.ph) * 0.012));
        u.ctx.lineTo(u.W, u.H);
        if (D.fill) { u.ctx.closePath(); u.ctx.fill(); } else u.ctx.stroke();
      }
      u.ctx.lineCap = "round";
      for (var s = 0; s < 4; s++) {
        var bx = u.W * (0.12 + s * 0.09), sway = Math.sin(t * 1.2 + s) * 4;
        for (var seg = 0; seg < 5; seg++)
          u.line(bx + sway * seg / 5 * 0.4, u.H * (0.95 - seg * 0.05), bx + sway * (seg + 1) / 5 * 0.4 + 2, u.H * (0.9 - seg * 0.05), u.rgba(D.ink, 0.85), 3.5 - seg * 0.6);
      }
      u.ctx.lineCap = "butt";
      u.label("swap paper and ink and the rule still holds: far = closer to the paper's value, whichever way is 'light'", u.W / 2, u.H - 8, u.rgba(D.ink, 0.65), "center");
    },
    press: function (x, y) { hue = (hue + 1) % D.hues.length; D.ink = D.hues[hue]; }
  };
});

rhymeOf("Noir", "Prison bars", "the same hard light standing up: vertical bars, wider apart and thinner, in a cold blue-grey — the ball still bends them", function make(u) {
  // rhyme of Noir: dials moved — angle -0.55 → π/2 (vertical), gap 0.09 → 0.14, barK 0.45 → 0.3, palette to cold blue
  var D = { room: "#0A0E18", wall: "#1A2230", light: "#C8D8F0", ball: "#4A4A5A",
            angle: Math.PI / 2, gap: 0.14, barK: 0.3, speed: 0.02, bend: 0.4 };
  var angle0 = D.angle;
  function bars(offset, alpha) {
    var gap = u.W * D.gap, n = Math.ceil((u.W + u.H) * 2 / gap) + 2;
    u.ctx.save(); u.ctx.translate(u.W / 2, u.H / 2); u.ctx.rotate(D.angle);
    u.ctx.fillStyle = u.rgba(D.light, alpha);
    for (var i = -n; i < n; i++) u.ctx.fillRect(-u.W - u.H, i * gap + offset, (u.W + u.H) * 2, gap * D.barK);
    u.ctx.restore();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      u.sky([D.room, D.wall]);
      var GY = u.H * 0.78, r = u.W * 0.13, ox = u.W * 0.5, oy = GY - r;
      var off = (t * D.speed * u.W) % (u.W * D.gap);
      u.ground(GY, u.shade(D.wall, -0.3));
      bars(off, 0.18);
      u.shadow(ox, GY, r * 1.2, r * 0.3, 0.8);
      u.sphere(ox, oy, r, D.ball, Math.sin(D.angle), -0.7, { spec: 0.15, dark: "#08080E" });
      u.ctx.save(); u.ctx.beginPath(); u.ctx.arc(ox, oy, r, 0, u.TAU); u.ctx.clip();
      bars(off + r * D.bend, 0.5);
      u.ctx.fillStyle = u.rad(ox, oy, r, [[0.5, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,0.6)"]], -r * 0.3, -r * 0.4);
      u.ctx.beginPath(); u.ctx.arc(ox, oy, r, 0, u.TAU); u.ctx.fill();
      u.ctx.restore();
      u.label("turn the angle a quarter and the blind becomes a cell — the ball's roundness survives any stripe direction", u.W / 2, u.H - 8, null, "center");
    },
    press: function (x, y) { D.angle = angle0 + (x / u.W - 0.5) * 1.0; }
  };
});

rhymeOf("Xray", "Stained glass", "the same three panes in saturated red, blue and gold on a dark ground, blended with screen instead of multiply — overlaps glow instead of darkening", function make(u) {
  // rhyme of Xray: dials moved — panes to saturated glass, blend multiply → screen, sky to dark, alpha 0.55 → 0.8, outside 0.3 → 0.5
  var D = { sky: ["#101018", "#20202A"], panes: ["#E02040", "#2060E0", "#F0C000"], ink: "#F5F0E8",
            alpha: 0.8, outside: 0.5, blend: "screen", lensR: 0.28, drift: 0.4 };
  var lens = null;
  function scene(t) {
    u.sky(D.sky);
    u.ground(u.H * 0.72, "#B8B0A0");
    u.sphere(u.W * 0.3, u.H * 0.6, u.W * 0.08, "#9BE28A", -0.5, -0.6, { spec: 0.4 });
    u.cube(u.W * 0.62, u.H * 0.72, u.W * 0.08, "#C9A0F5");
    u.dot(u.W * 0.8, u.H * 0.25, u.W * 0.05, "#FFF3D0");
  }
  function panes(t, a) {
    u.ctx.save(); u.ctx.globalCompositeOperation = D.blend;
    for (var i = 0; i < D.panes.length; i++) {
      var w = u.W * 0.42, h = u.H * 0.5;
      var x = u.W * (0.15 + i * 0.18) + Math.sin(t * D.drift + i * 2) * u.W * 0.06, y = u.H * (0.15 + i * 0.1) + Math.cos(t * D.drift * 0.7 + i) * u.H * 0.05;
      u.ctx.fillStyle = u.rgba(D.panes[i], a); u.ctx.fillRect(x, y, w, h);
      u.ctx.strokeStyle = u.rgba(D.ink, a * 0.8); u.ctx.lineWidth = 1; u.ctx.strokeRect(x, y, w, h);
    }
    u.ctx.restore();
  }
  return { drag: true,                                 // press is continuous — dragging scrubs it
    frame: function (dt, t) {
      scene(t);
      panes(t, D.outside);
      var lx = lens ? lens[0] : u.W * (0.5 + 0.3 * Math.sin(t * 0.6)), ly = lens ? lens[1] : u.H * (0.5 + 0.2 * Math.cos(t * 0.45)), R = u.W * D.lensR;
      u.ctx.save(); u.ctx.beginPath(); u.ctx.arc(lx, ly, R, 0, u.TAU); u.ctx.clip();
      scene(t); panes(t, D.alpha);
      u.ctx.restore();
      u.ctx.strokeStyle = u.rgba(D.ink, 0.6); u.ctx.lineWidth = 2; u.ctx.beginPath(); u.ctx.arc(lx, ly, R, 0, u.TAU); u.ctx.stroke();
      u.label("screen adds light where multiply took it away — the overlaps still count the layers, now in brightness", u.W / 2, u.H - 8, u.rgba(D.ink, 0.7), "center");
    },
    press: function (x, y) { lens = [x, y]; }
  };
});

/* ============================== the atlas grid ============================== */

var grid = document.getElementById("atlas");
var statusEl = document.getElementById("status");
var runAllBtn = document.getElementById("runall");
var stopAllBtn = document.getElementById("stopall");
var cards = [];

function buildCard(effect) {
  var card = document.createElement("div");
  card.className = "bcard";
  var canvas = document.createElement("canvas");
  canvas.title = effect.letter + " · " + effect.name + " — click to wake it; click again to move the light, the camera, or the weather";
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

/* a small pulsing badge, top-right, until the card has been touched once -
   so nobody has to guess that a picture can be poked or dragged */
function badge(u, drag, t) {
  var c = u.ctx, txt = drag ? "\u2190 drag \u2192" : "click \u2726";
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
  u.sky(["#1A1532", "#131020"]);
  u.ctx.fillStyle = "rgba(232,229,244,0.14)";
  u.ctx.font = "700 " + Math.round(u.H * 0.5) + "px 'Spline Sans Mono', Consolas, monospace";
  u.ctx.textAlign = "center";
  u.ctx.textBaseline = "middle";
  u.ctx.fillText(st.effect.letter, u.W / 2, u.H * 0.52);
  u.ctx.fillStyle = "rgba(230,227,242,0.55)";
  u.ctx.font = "12px system-ui, sans-serif";
  u.ctx.textBaseline = "alphabetic";
  u.ctx.fillText("▶ click to wake", u.W / 2, u.H * 0.16);
  u.ctx.textAlign = "left";
}

/* the opt-in notice: plain, static (nothing here may flash), and honest */
function warning(u, text) {
  var c = u.ctx;
  u.sky(["#1A1532", "#131020"]);
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
var tempo = 1;                                         // the page-wide time-lapse dial (x1 / x2 / x4)

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
    st.elapsed += dt * tempo;
    var c = st.u.ctx;
    c.globalCompositeOperation = "source-over";        // every frame starts clean,
    c.globalAlpha = 1;                                 // whatever the last one left
    c.setLineDash([]);
    try { st.inst.frame(dt * tempo, st.elapsed); } catch (err) { failCard(st, err); continue; }
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
    statusEl.textContent = n === 0 ? "" : n + " of " + cards.length + " pictures alive";
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
  small.textContent = list.length + " pictures (+" + list.filter(function (e) { return e.rhyme; }).length + " rhymes) — " + fam[2];
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
  u.sky(["#1A1532", "#131020"]);
  u.ctx.fillStyle = "rgba(232,229,244,0.12)";
  u.ctx.font = "700 " + Math.round(u.H * 0.45) + "px 'Spline Sans Mono', Consolas, monospace";
  u.ctx.textAlign = "center";
  u.ctx.textBaseline = "middle";
  u.ctx.fillText(current.effect.letter, u.W / 2, u.H * 0.52);
  u.ctx.fillStyle = "rgba(230,227,242,0.6)";
  u.ctx.font = "15px system-ui, sans-serif";
  u.ctx.textBaseline = "alphabetic";
  u.ctx.fillText("Press ▶ Run — the picture repaints from your edits.", u.W / 2, u.H * 0.14);
  u.ctx.textAlign = "left";
}

function openInEditor(effect, useRhyme) {
  current = { effect: effect, useRhyme: !!(useRhyme && effect.rhyme) };
  var v = current.useRhyme ? effect.rhyme : effect;
  edname.textContent = (current.useRhyme
    ? effect.letter + " · " + v.name + " — a rhyme of " + effect.name + " — " + v.hint
    : effect.letter + " · " + v.name + " — " + v.hint) + (effect.warn ? "  ⚠ " + effect.warn + " — Run starts it" : "");
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
  pv.u = u;
  pv.elapsed = 0;
  pv.pressed = false;
  var last = null;
  function step(ts) {
    if (last === null) last = ts;
    var dt = Math.min(0.05, (ts - last) / 1000) * tempo;
    last = ts;
    pv.elapsed += dt;
    u.ctx.globalCompositeOperation = "source-over";
    u.ctx.globalAlpha = 1;
    u.ctx.setLineDash([]);
    try { pv.inst.frame(dt, pv.elapsed); }
    catch (e) { errBox.textContent = "The code hit a snag mid-frame: " + e.message; stopPreview(); return; }
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
window.__atlas = { EFFECTS: EFFECTS, apiFor: apiFor, cards: cards };
})();
