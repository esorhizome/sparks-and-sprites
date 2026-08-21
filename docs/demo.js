/* Sparks & Sprites — shared demo runner.
   Contract for each demo page:
   - a <textarea id="code"> holding the editable demo code
   - a <canvas id="cv">, buttons #run #stop #reset, and a <div id="err"> for errors
   The demo code runs with these names available:
     canvas, ctx  — the canvas and its 2D drawing context
     W, H         — canvas size in CSS pixels
     onFrame(fn)  — run fn(dt, t) every frame (dt = seconds since last frame,
                    t = seconds since Run was pressed) until Stop is pressed.
     rand(a, b)   — random number between a and b
   Animation only ever starts from a Run press (nothing autoplays),
   and stops itself after 60 seconds as a courtesy. */
(function () {
  "use strict";
  var canvas = document.getElementById("cv");
  var codeBox = document.getElementById("code");
  var runBtn = document.getElementById("run");
  var stopBtn = document.getElementById("stop");
  var resetBtn = document.getElementById("reset");
  var errBox = document.getElementById("err");
  if (!canvas || !codeBox || !runBtn) return;

  var initialCode = codeBox.value;
  var raf = null;
  var ctx = null, W = 0, H = 0;

  function fit() {
    var dpr = window.devicePixelRatio || 1;
    W = canvas.clientWidth; H = canvas.clientHeight;
    canvas.width = Math.round(W * dpr);
    canvas.height = Math.round(H * dpr);
    ctx = canvas.getContext("2d");
    ctx.scale(dpr, dpr);
  }

  function stop() {
    if (raf) cancelAnimationFrame(raf);
    raf = null;
  }

  function run() {
    stop();
    errBox.textContent = "";
    fit();
    ctx.clearRect(0, 0, W, H);
    var frameFn = null;
    function onFrame(fn) { frameFn = fn; }
    function rand(a, b) { return a + Math.random() * (b - a); }
    try {
      var user = new Function("canvas", "ctx", "W", "H", "onFrame", "rand", codeBox.value);
      user(canvas, ctx, W, H, onFrame, rand);
    } catch (e) {
      errBox.textContent = "The code hit a snag (totally fixable): " + e.message;
      return;
    }
    if (frameFn) {
      var last = null, t0 = null;
      function step(ts) {
        if (last === null) { last = ts; t0 = ts; }
        var dt = Math.min(0.05, (ts - last) / 1000);
        var t = (ts - t0) / 1000;
        last = ts;
        try {
          frameFn(dt, t);
        } catch (e) {
          errBox.textContent = "The code hit a snag mid-frame: " + e.message;
          stop();
          return;
        }
        if (t < 60) { raf = requestAnimationFrame(step); }
        else { raf = null; }
      }
      raf = requestAnimationFrame(step);
    }
  }

  runBtn.addEventListener("click", run);
  if (stopBtn) stopBtn.addEventListener("click", stop);
  if (resetBtn) resetBtn.addEventListener("click", function () {
    stop();
    codeBox.value = initialCode;
    errBox.textContent = "";
  });

  // draw a gentle "press Run" hint on the empty canvas (static, no motion)
  fit();
  ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue("--soft").trim() || "#888";
  ctx.font = "15px system-ui, sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("Press ▶ Run — nothing moves until you do.", W / 2, H / 2);
})();
