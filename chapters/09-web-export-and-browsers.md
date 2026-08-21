# 09 · Web export & browser troubleshooting

*Fresh-start note: **WebGL/WebGPU** are the browser's ways of talking to the graphics card; a **.wasm** file is your engine compiled to run in browsers; **headers** are metadata a web server sends alongside files; **DevTools** is the browser's built-in inspector (press F12). All re-mentioned where used.*

---

Web builds fail for a small, learnable set of reasons. Here they are, in the order they actually bite people.

## №1 — The blank page: missing cross-origin isolation headers

Godot 4 web exports (and any engine build using threads) need a browser feature called `SharedArrayBuffer`, which browsers only switch on when the *server* sends two headers (bits of metadata that accompany every file it serves):

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

- **itch.io:** tick "SharedArrayBuffer support" in the project's Embed options.
- **Your own host / Cloudflare Pages:** add the headers (on Pages, via a `_headers` file).
- **Opening index.html by double-click:** never works — `file://` can't send headers. Always test through a local server.
- **Escape hatch:** Godot's web export offers thread-free fallback options that relax this requirement, at a performance cost.

## №2 — iPhone/iPad tab crashes: memory ceilings

iOS Safari gives a tab far less memory than a desktop browser, and over-budget tabs reload *silently* — no error, just a blink and restart. Fixes, in payoff order: smaller textures (1024 px is plenty for most 2D), compressed audio (OGG/MP3, never WAV), fewer things loaded at once, and — for Unity — a reduced initial memory size in Player Settings. Desktop-fine + iPhone-crashy = memory, almost every time.

## №3 — Silent audio until the player clicks

All browsers block audio before the first user interaction — by design. The standard cure is cultural, not technical: a "click to start" title screen (this is *why* every web game has one). Start or resume audio inside that click's handler; everything after flows normally.

## №4 — Blurry canvas on sharp screens

A canvas (the browser's drawing surface) has two sizes: its internal pixel buffer and its CSS display size. On a 2× display they must differ by `devicePixelRatio`, or the browser upscales your pixels into soup:

```js
const dpr = window.devicePixelRatio || 1;
canvas.width  = cssWidth  * dpr;
canvas.height = cssHeight * dpr;
ctx.scale(dpr, dpr);   // now draw in CSS units, crisply
```

For pixel-art that should stay chunky, instead use `image-rendering: pixelated` in CSS (and "nearest" texture filtering in engines).

## №5 — Loads forever: size & compression

Engine web builds ship a multi-megabyte `.wasm` file (the engine itself, compiled for browsers); serving it Brotli-compressed roughly halves it. itch.io and Cloudflare Pages compress automatically — a reason to like both. Unity: enable Brotli in Publishing Settings. Beyond that, it's usually your *assets*, not the engine — audio first, then oversized textures. A loading bar is not optional decoration on the web; the engines' default templates include one.

## №6 — Black canvas / "context lost"

The page loads but the game area is black: usually WebGL2 (the browser's graphics-card API) is unavailable — very old device, disabled in settings, blocklisted GPU driver — or the GPU "lost the context" under pressure. Check any machine at [webglreport.com](https://webglreport.com/); check feature support across browsers at [caniuse.com](https://caniuse.com/). WebGPU (the newer API) is broadly available in current Chromium and Safari with Firefox close behind — but for maximum reach in 2026, WebGL2 remains the safe floor, and it's what Godot targets.

## Who actually needs testing — the engine-family shortcut

Nearly every browser is built on one of **three engines**. Test one browser per family and you've covered that family's core rendering; the rest is small per-browser quirks.

**Family 1 — Chromium (Blink).** Chromium is the open-source foundation underneath *many* browsers: Chrome, Edge, Opera, Brave, Samsung Internet, Vivaldi, Yandex Browser, and more. **Test Chrome and you've tested this family's core.** Per-browser quirks worth knowing:
- *Opera* — built-in ad blocker can block trackers/CDNs; test with it on.
- *Brave* — its "Shields" block third-party requests aggressively (the main source of Brave-only bugs); self-host your files and you're fine.
- *Samsung Internet* — Android-only, slightly older Chromium base than Chrome; avoid week-old bleeding-edge features, test via any Android phone or emulator.

**Family 2 — Gecko.** Firefox. The second real test target: occasionally different WebGL performance and audio timing. Usually fine; worth one play-through per release.

**Family 3 — WebKit.** Safari on macOS and iOS — the third real test target and the strictest: memory limits, autoplay rules. Note that on iPhones (pre-EU-rule devices), *every* browser — Chrome-on-iPhone included — is WebKit underneath. The DuckDuckGo browser also borrows the platform's engine: WebKit on Apple devices, Blink elsewhere — so your Safari + Chrome testing already covers it (its tracker blocking behaves like Brave's).

## Testing Safari without owning any Apple device

Yes, possible, in tiers:

1. **[Playwright](https://playwright.dev/)** *(free)* — installs a real WebKit engine build on Windows/Linux. `npx playwright open --browser=webkit https://your-game.example` gives an interactive WebKit window. Not pixel-identical to shipping Safari, but catches the majority of WebKit-specific breakage. The right first tier.
2. **[BrowserStack](https://www.browserstack.com/) / [LambdaTest](https://www.lambdatest.com/)** *(freemium; paid ≈ $29–39/month, estimate)* — real Safari on real Apple hardware, streamed to your browser. Both offer limited free minutes. The only way to truly test *iOS* Safari's memory ceiling without hardware.
3. **Kind humans** *(free)* — one friend with an iPhone running your itch.io link for five minutes finds what no simulator will. Web-jam communities do this for each other constantly.

⚠️ [Safari Technology Preview](https://developer.apple.com/safari/technology-preview/) is macOS-only — it is not the Windows answer, despite often being suggested as one.

## The pre-release checklist

- [ ] Served over HTTPS with the two cross-origin headers (if the engine needs them) — verified in DevTools (F12) → Network.
- [ ] Tested via a real server, never `file://`.
- [ ] One full play-through each: a Chromium browser, Firefox, and a WebKit tier from above.
- [ ] Once on a mid-range phone — performance *and* touch input.
- [ ] Audio starts after a click; nothing depends on autoplay.
- [ ] Total download known (DevTools → Network → "transferred") and under ~50 MB for casual web play, ideally far under.
- [ ] Browser console (F12) free of red errors on load — warnings are usually fine; errors rarely are.

---

*Three engine families, six known failure modes, one checklist. "Web games break mysteriously" turns out to be a short, finite list — and now you hold the whole of it.*
