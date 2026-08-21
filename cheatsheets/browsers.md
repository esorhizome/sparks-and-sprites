# Cheatsheet · Web export & browsers

Full chapter: [09](../chapters/09-web-export-and-browsers.md).

## The six failure modes, in bite order

1. **Blank page** → missing headers: `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp` (itch.io: tick SharedArrayBuffer; Cloudflare Pages: `_headers` file). Never test via `file://`.
2. **iPhone tab silently reloads** → memory ceiling. Shrink textures (≤1024px), compress audio (OGG, never WAV), load less at once.
3. **No audio** → autoplay block. Start audio inside the first click ("click to start" screen).
4. **Blurry canvas** → multiply canvas buffer size by `devicePixelRatio`, then `ctx.scale(dpr, dpr)`. Pixel art: `image-rendering: pixelated`.
5. **Loads forever** → Brotli-compress the `.wasm` (itch/Pages do it free); then audio, then textures.
6. **Black canvas** → WebGL2 unavailable or context lost. Diagnose: [webglreport.com](https://webglreport.com/), [caniuse.com](https://caniuse.com/). WebGL2 is still the safe floor in 2026.

## Engine families (test one per family)

| Family | Browsers | Test with |
|---|---|---|
| Chromium (Blink) | Chrome, Edge, Opera, Brave, Samsung Internet, Vivaldi, Yandex Browser, more | **Chrome** (quirks: Brave Shields & Opera ad-block may block third-party files; Samsung ≈ slightly older Chromium) |
| Gecko | Firefox | **Firefox** |
| WebKit | Safari (and *all* iPhone browsers pre-EU-rules; DuckDuckGo on Apple devices) | **Safari tier below** |

## Safari without Apple hardware

1. [Playwright](https://playwright.dev/) WebKit build — free, local: `npx playwright open --browser=webkit <url>`
2. [BrowserStack](https://www.browserstack.com/) / [LambdaTest](https://www.lambdatest.com/) — real devices, freemium (paid ≈ $29–39/mo est.)
3. A friend with an iPhone + your itch.io link — free, finds what simulators can't

## Pre-release checklist

- [ ] HTTPS + the two headers (verify in DevTools → Network)
- [ ] Real server, never `file://`
- [ ] Play-through: one Chromium + Firefox + one WebKit tier
- [ ] Once on a mid-range phone (perf + touch)
- [ ] Audio starts after a click
- [ ] Download size known, ideally ≪ 50 MB
- [ ] Console (F12) free of red errors
