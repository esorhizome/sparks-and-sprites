// STAGECRAFT (2D) — scene-level effects, done on the CPU so every step is visible.
// The web almanac (docs/stagecraft.html) holds 104 of these across eight families;
// this template paints one small scene into a Texture2D each frame and runs six
// AMBASSADOR passes over it (keys 1–6). Each pass is a post-process, a light or a
// HUD rule written out in plain C# — and each comment names the spelling Unity
// would use to do it properly (a URP Renderer Feature, a Volume override, a Light2D,
// an ObjectPool<T>). The picture is the same; only who does the arithmetic moves.
//   [1] Ordered   — a 4×4 BAYER matrix turns brightness into on/off patterns (the 1-bit look)
//   [2] Quantise  — every pixel snapped to the NEAREST of N palette colours
//   [3] Xsplit    — CHROMATIC ABERRATION: R, G, B sampled at offsets that grow toward the edges
//   [4] Visibility — a VISIBILITY POLYGON: rays to every wall corner (±ε), sorted by angle, the fan filled
//   [5] Healthbar — the red bar SNAPS, a white GHOST CHUNK lags and drains — the damage made visible
//   [6] Pool      — OBJECT POOLING: N particles pre-made and REUSED from a free list; allocations: 0
// Keys 1–6 switch; click = cycle levels / cycle palette / set split / move the light / take a hit / burst.
// Chapters 17–18's companion gallery; the eight family names are in the almanac's header.
using UnityEngine;

public class Stagecraft2D : MonoBehaviour
{
    const int S = 256;                 // texture size, px
    const float PPU = 128f;            // → the card is 2 units wide

    int mode = 1;
    float t;
    Texture2D tex; SpriteRenderer sr;
    Color[] scene, px;                 // the scene as painted, and the scene after this frame's pass
    float[] mask;                      // [4] the light's coverage, 0..1 per pixel

    // [1] the Bayer 4×4 threshold matrix — each cell's rank, 0..15, in the classic order
    static readonly int[] BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };
    int levels = 4;                    // 2 = pure 1-bit
    // [2] palettes: four Game Boy greens, then an 8-colour pastel set (the Quartz rhyme)
    static readonly Color[][] PALETTES = {
        new[] { Hex(0x0f380f), Hex(0x306230), Hex(0x8bac0f), Hex(0x9bbc0f) },
        new[] { Hex(0x2b2d42), Hex(0x8d99ae), Hex(0xedf2f4), Hex(0xef233c), Hex(0xd90429), Hex(0xffb703), Hex(0x8ecae6), Hex(0x219ebc) },
    };
    int palette;
    // [3] the split strength, as a fraction of the half-width at the far corner
    float split = 0.03f;
    // [4] the light and the walls (the crates' edges + the frame)
    Vector2 light = new Vector2(S * 0.5f, S * 0.6f); bool lightPinned;
    struct Seg { public Vector2 a, b; }
    Seg[] segs;
    RectInt[] crates = { new RectInt(48, 72, 30, 30), new RectInt(140, 72, 22, 40), new RectInt(196, 72, 26, 54) };
    int rays;
    // [5] health: hp snaps, ghost chases
    float hp = 1f, ghost = 1f, ghostHold, hitTimer = 1.5f, flash;
    // [6] the pool: a fixed array of structs + a stack of free indices
    struct Particle { public float x, y, vx, vy, life, age; public bool alive; }
    const int POOL = 64;
    Particle[] pool = new Particle[POOL];
    int[] free = new int[POOL]; int freeCount;
    int poolAllocs, naiveAllocs, stolen, alive; float burstTimer = 0.5f;

    void Start()
    {
        tex = new Texture2D(S, S, TextureFormat.RGBA32, false);
        tex.wrapMode = TextureWrapMode.Clamp; tex.filterMode = FilterMode.Point;
        scene = new Color[S * S]; px = new Color[S * S]; mask = new float[S * S];
        var go = new GameObject("StageCard"); go.transform.parent = transform;
        sr = go.AddComponent<SpriteRenderer>();
        sr.sprite = Sprite.Create(tex, new Rect(0, 0, S, S), new Vector2(0.5f, 0.5f), PPU);

        // [4] every crate is four wall segments; the frame closes the room
        var list = new System.Collections.Generic.List<Seg>();
        foreach (var c in crates)
        {
            Vector2 a = new Vector2(c.xMin, c.yMin), b = new Vector2(c.xMax, c.yMin), d = new Vector2(c.xMax, c.yMax), e = new Vector2(c.xMin, c.yMax);
            list.Add(new Seg { a = a, b = b }); list.Add(new Seg { a = b, b = d }); list.Add(new Seg { a = d, b = e }); list.Add(new Seg { a = e, b = a });
        }
        list.Add(new Seg { a = new Vector2(0, 0), b = new Vector2(S, 0) }); list.Add(new Seg { a = new Vector2(S, 0), b = new Vector2(S, S) });
        list.Add(new Seg { a = new Vector2(S, S), b = new Vector2(0, S) }); list.Add(new Seg { a = new Vector2(0, S), b = new Vector2(0, 0) });
        segs = list.ToArray();

        // [6] fill the free list once — this is the only allocation the pool ever makes
        for (int i = 0; i < POOL; i++) free[i] = POOL - 1 - i;
        freeCount = POOL;
    }

    void Update()
    {
        t += Time.deltaTime;
        for (int k = 1; k <= 6; k++) if (Input.GetKeyDown(KeyCode.Alpha0 + k)) mode = k;
        Vector2 click = Vector2.zero; bool pressed = Input.GetMouseButtonDown(0);
        if (pressed)
        {
            var w = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            click = new Vector2(Mathf.Clamp01(w.x * 0.5f + 0.5f) * S, Mathf.Clamp01(w.y * 0.5f + 0.5f) * S);   // world → texture px
        }
        PaintScene(mode == 4);
        switch (mode)
        {
            case 1: if (pressed) levels = levels >= 4 ? 2 : levels + 1; Ordered(); break;
            case 2: if (pressed) palette = (palette + 1) % PALETTES.Length; Quantise(); break;
            case 3: if (pressed) split = Vector2.Distance(click, new Vector2(S / 2, S / 2)) / (S * 0.7f) * 0.12f; Xsplit(); break;
            case 4: if (pressed) { light = click; lightPinned = true; } Visibility(); break;
            case 5: if (pressed) Hit(0.18f); Healthbar(); break;
            case 6: if (pressed) Burst(click, 24); Pool(); break;
        }
        tex.SetPixels(px); tex.Apply();
    }

    // ---- the scene itself: a sky, a ground, three crates, a hero, a sun -----------------
    void PaintScene(bool night)
    {
        Color top = night ? new Color(0.03f, 0.03f, 0.08f) : new Color(0.35f, 0.55f, 0.90f);
        Color hor = night ? new Color(0.10f, 0.08f, 0.16f) : new Color(0.98f, 0.72f, 0.45f);
        float ground = S * 0.28f;
        for (int y = 0; y < S; y++)
        {
            Color c = y < ground ? Color.Lerp(new Color(0.20f, 0.30f, 0.16f), new Color(0.32f, 0.48f, 0.22f), y / ground)
                                 : Color.Lerp(hor, top, Mathf.Pow((y - ground) / (S - ground), 0.7f));
            for (int x = 0; x < S; x++) scene[y * S + x] = c;
        }
        Disc(scene, S * 0.78f, S * 0.78f, S * 0.07f, night ? new Color(0.85f, 0.85f, 0.75f) : new Color(1f, 0.95f, 0.7f));
        foreach (var c in crates) Fill(scene, c.xMin, c.yMin, c.xMax, c.yMax, new Color(0.55f, 0.38f, 0.25f));
        float hx = S * (0.5f + 0.3f * Mathf.Sin(t * 0.6f)), bob = Mathf.Abs(Mathf.Sin(t * 4f)) * 3f;
        Color hero = Color.Lerp(new Color(0.55f, 0.67f, 1f), Color.white, flash);            // [5] the hurt flash
        Fill(scene, (int)hx - 6, (int)(ground + bob), (int)hx + 6, (int)(ground + bob + 18), hero);
        flash = Mathf.Max(0, flash - Time.deltaTime * 4f);
    }

    // ---- [1] ORDERED DITHER: compare brightness with a threshold that tiles ---------------
    // Unity spelling: a Full Screen Pass Renderer Feature (URP Renderer Data → Add Renderer
    // Feature) driving a Shader Graph set to Fullscreen; sample the frame with the URP Sample
    // Buffer node (BlitSource), the matrix as a 4×4 Point-filtered texture read at frac(pixel/4).
    void Ordered()
    {
        for (int y = 0; y < S; y++) for (int x = 0; x < S; x++)
        {
            int i = y * S + x;
            float lum = Lum(scene[i]);
            float th = (BAYER[(y & 3) * 4 + (x & 3)] + 0.5f) / 16f;               // this pixel's own threshold, 0..1
            int q = Mathf.Clamp(Mathf.FloorToInt(lum * (levels - 1) + th), 0, levels - 1);   // the tile decides which way to round
            px[i] = Color.Lerp(PALETTES[0][0], PALETTES[0][3], q / (float)(levels - 1));    // painted in Game Boy greens
        }
        for (int y = 0; y < 4; y++) for (int x = 0; x < 4; x++)                   // the matrix itself, as a tile in the corner
            Fill(px, 8 + x * 6, S - 32 + (3 - y) * 6, 14 + x * 6, S - 26 + (3 - y) * 6, Color.Lerp(Color.black, Color.white, BAYER[y * 4 + x] / 15f));
    }

    // ---- [2] PALETTE QUANTISE: the nearest swatch by RGB distance ------------------------
    // Unity spelling: URP Volume → Color Lookup (a 2D LUT texture) is the shipping version; a
    // tiny palette like this is the same fullscreen pass with a loop over N colours, or a
    // 3D LUT baked once from this exact loop.
    void Quantise()
    {
        var pal = PALETTES[palette];
        for (int i = 0; i < px.Length; i++)
        {
            Color c = scene[i]; int best = 0; float bestD = float.MaxValue;
            for (int k = 0; k < pal.Length; k++)
            {
                float d = (c.r - pal[k].r) * (c.r - pal[k].r) + (c.g - pal[k].g) * (c.g - pal[k].g) + (c.b - pal[k].b) * (c.b - pal[k].b);
                if (d < bestD) { bestD = d; best = k; }                          // nearest in RGB space (luma-only is the other mode)
            }
            px[i] = pal[best];
        }
        for (int k = 0; k < pal.Length; k++) Fill(px, 8 + k * 14, S - 22, 20 + k * 14, S - 10, pal[k]);   // the swatches
    }

    // ---- [3] CHROMATIC ABERRATION: three samples, offsets growing with the radius ----------
    // Unity spelling: URP Volume → Chromatic Aberration override —
    //   using UnityEngine.Rendering; using UnityEngine.Rendering.Universal;
    //   if (volume.profile.TryGet(out ChromaticAberration ca)) ca.intensity.value = k;
    void Xsplit()
    {
        for (int y = 0; y < S; y++) for (int x = 0; x < S; x++)
        {
            float ox = (x - S * 0.5f) * split, oy = (y - S * 0.5f) * split;        // the offset vector: zero at the centre, largest at the corners
            px[y * S + x] = new Color(
                Sample(x + ox, y + oy).r,                                          // red pulled outward
                scene[y * S + x].g,                                                // green stays home
                Sample(x - ox, y - oy).b, 1f);                                     // blue pulled inward
        }
    }
    Color Sample(float fx, float fy) => scene[Mathf.Clamp((int)fy, 0, S - 1) * S + Mathf.Clamp((int)fx, 0, S - 1)];

    // ---- [4] VISIBILITY POLYGON: rays to every corner, sorted, a fan of triangles ---------
    // Unity spelling (URP 2D Renderer): a Light2D of type Point on the lamp, a ShadowCaster2D
    // on each crate, Light2D.shadowIntensity = 1 — the GPU builds this same polygon per frame.
    void Visibility()
    {
        if (!lightPinned) light = new Vector2(S * (0.5f + 0.35f * Mathf.Sin(t * 0.5f)), S * (0.55f + 0.2f * Mathf.Sin(t * 0.8f)));   // the lamp wanders
        // one ray at each corner's angle and one a hair either side, so the fan hugs the corner
        var pts = new System.Collections.Generic.List<Vector3>();
        foreach (var s in segs)
            for (int e = 0; e < 2; e++)
            {
                Vector2 corner = e == 0 ? s.a : s.b;
                float ang = Mathf.Atan2(corner.y - light.y, corner.x - light.x);
                for (int k = -1; k <= 1; k++)
                {
                    float a = ang + k * 1e-4f;
                    Vector2 d = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                    float best = float.PositiveInfinity;
                    foreach (var w in segs) { float hit = RaySeg(light, d, w.a, w.b); if (hit < best) best = hit; }   // the nearest wall along this ray
                    if (float.IsInfinity(best)) best = S * 2;
                    pts.Add(new Vector3(light.x + d.x * best, light.y + d.y * best, a));
                }
            }
        pts.Sort((p, q) => p.z.CompareTo(q.z));                                   // by angle: neighbours in the list are neighbours in the fan
        rays = pts.Count;
        System.Array.Clear(mask, 0, mask.Length);
        for (int i = 0; i < pts.Count; i++)
        {
            Vector3 p = pts[i], q = pts[(i + 1) % pts.Count];
            Tri(light, new Vector2(p.x, p.y), new Vector2(q.x, q.y));             // fill the fan into the mask
        }
        for (int y = 0; y < S; y++) for (int x = 0; x < S; x++)
        {
            int i = y * S + x;
            float fall = Mathf.Clamp01(1f - Vector2.Distance(new Vector2(x, y), light) / (S * 0.8f));   // and let it fade with distance
            px[i] = scene[i] * (0.15f + 0.85f * mask[i] * fall * fall);
            px[i].a = 1f;                                                          // darken the colour, not the sprite
        }
        for (int i = 0; i < pts.Count; i += 3) Line(light, new Vector2(pts[i].x, pts[i].y), new Color(1f, 0.9f, 0.6f, 0.25f));   // the rays, faintly
        Disc(px, light.x, light.y, 4f, new Color(1f, 0.95f, 0.75f));
    }
    // does a ray from o along d hit segment ab? returns the distance, or +∞
    static float RaySeg(Vector2 o, Vector2 d, Vector2 a, Vector2 b)
    {
        Vector2 e = b - a; float den = d.x * e.y - d.y * e.x;
        if (Mathf.Abs(den) < 1e-9f) return float.PositiveInfinity;               // parallel
        Vector2 ao = a - o;
        float tRay = (ao.x * e.y - ao.y * e.x) / den;                            // how far along the ray
        float tSeg = (ao.x * d.y - ao.y * d.x) / den;                            // how far along the segment (must be 0..1)
        return tRay >= 0 && tSeg >= 0 && tSeg <= 1 ? tRay : float.PositiveInfinity;
    }

    // ---- [5] HEALTH BAR WITH GHOST CHUNK: snap the truth, lag the memory -----------------
    // Unity spelling: two stacked uGUI Images with type = Filled; red.fillAmount = hp at once,
    // white.fillAmount = Mathf.MoveTowards(white.fillAmount, hp, dt / 0.5f) after a short hold.
    // (UI Toolkit: the same two VisualElements with style.width as a percentage.)
    void Healthbar()
    {
        hitTimer -= Time.deltaTime;
        if (hitTimer <= 0) { Hit(Random.Range(0.08f, 0.22f)); hitTimer = Random.Range(1.2f, 2.4f); }
        if (hp < 0.05f) hp = 1f;                                                  // respawn
        if (hitTimer > 0.8f) hp = Mathf.Min(1f, hp + Time.deltaTime * 0.05f);    // slow regeneration when left alone
        ghostHold -= Time.deltaTime;
        if (ghostHold <= 0) ghost = Mathf.MoveTowards(ghost, hp, Time.deltaTime / 0.5f);   // the GHOST drains toward the truth over 0.5 s
        System.Array.Copy(scene, px, px.Length);
        int x0 = (int)(S * 0.1f), x1 = (int)(S * 0.9f), y0 = S - 30, y1 = S - 18;
        Fill(px, x0 - 2, y0 - 2, x1 + 2, y1 + 2, new Color(0.05f, 0.05f, 0.08f));
        float lo = Mathf.Min(hp, ghost), hi = Mathf.Max(hp, ghost);
        Fill(px, x0, y0, x0 + (int)((x1 - x0) * lo), y1, new Color(0.85f, 0.2f, 0.25f));                        // what you have: red, snapped
        Fill(px, x0 + (int)((x1 - x0) * lo), y0, x0 + (int)((x1 - x0) * hi), y1,
             ghost > hp ? new Color(0.95f, 0.95f, 0.9f) : new Color(0.4f, 0.9f, 0.5f));                        // what you just lost: white · what is coming: green
    }
    void Hit(float dmg) { ghost = Mathf.Max(ghost, hp); hp = Mathf.Max(0, hp - dmg); ghostHold = 0.25f; flash = 1f; }   // the ghost stays where hp WAS

    // ---- [6] OBJECT POOLING: never `new` in the hot path — borrow, use, return -------------
    // Unity spelling: UnityEngine.Pool.ObjectPool<T> — new ObjectPool<Spark>(create, onGet,
    // onRelease, onDestroy, maxSize: 64); pool.Get() / pool.Release(spark). And a ParticleSystem
    // is already a pool: maxParticles is its size, Emit(n) borrows n slots.
    void Pool()
    {
        burstTimer -= Time.deltaTime;
        if (burstTimer <= 0) { Burst(new Vector2(S * (0.5f + 0.3f * Mathf.Sin(t * 0.6f)), S * 0.28f + 10), 20); burstTimer = 1.4f; }
        System.Array.Copy(scene, px, px.Length);
        alive = 0;
        for (int i = 0; i < POOL; i++)
        {
            if (!pool[i].alive) continue;
            ref Particle p = ref pool[i];
            p.age += Time.deltaTime; p.vy -= 120f * Time.deltaTime; p.x += p.vx * Time.deltaTime; p.y += p.vy * Time.deltaTime;
            if (p.age >= p.life || p.y < 0) { p.alive = false; free[freeCount++] = i; continue; }   // RETURN the slot to the free list
            alive++;
            float k = 1f - p.age / p.life;
            SoftDisc(p.x, p.y, 2f + 3f * k, new Color(1f, 0.6f + 0.3f * k, 0.25f, k));
        }
        for (int i = 0; i < POOL; i++)                                            // the pool drawn as an 8×8 grid of slots: lit = borrowed
        {
            int gx = S - 60 + (i % 8) * 7, gy = S - 12 - (i / 8) * 7;
            Fill(px, gx, gy - 5, gx + 5, gy, pool[i].alive ? new Color(1f, 0.75f, 0.3f) : new Color(0.15f, 0.15f, 0.2f));
        }
    }
    void Burst(Vector2 at, int n)
    {
        naiveAllocs += n;                                                         // what `new Spark()` per particle would have cost by now
        for (int k = 0; k < n; k++)
        {
            int i;
            if (freeCount > 0) i = free[--freeCount];                             // BORROW from the free list
            else                                                                  // starved: steal the oldest (the Puddlepool rhyme)
            {
                i = 0; for (int j = 1; j < POOL; j++) if (pool[j].age > pool[i].age) i = j;
                stolen++;
            }
            float a = Random.Range(0f, Mathf.PI * 2f), sp = Random.Range(40f, 110f);
            pool[i] = new Particle { x = at.x, y = at.y, vx = Mathf.Cos(a) * sp, vy = Mathf.Sin(a) * sp + 40f, life = Random.Range(0.5f, 1.1f), alive = true };   // a struct write, not a heap allocation
        }
    }

    // ---- the tiny painter ----------------------------------------------------------------
    static Color Hex(int h) => new Color(((h >> 16) & 255) / 255f, ((h >> 8) & 255) / 255f, (h & 255) / 255f);
    static float Lum(Color c) => 0.299f * c.r + 0.587f * c.g + 0.114f * c.b;
    void Fill(Color[] buf, int x0, int y0, int x1, int y1, Color c)
    {
        for (int y = Mathf.Max(0, y0); y < Mathf.Min(S, y1); y++) for (int x = Mathf.Max(0, x0); x < Mathf.Min(S, x1); x++) buf[y * S + x] = c;
    }
    void Disc(Color[] buf, float cx, float cy, float r, Color c)
    {
        for (int y = Mathf.Max(0, (int)(cy - r)); y <= Mathf.Min(S - 1, (int)(cy + r)); y++)
            for (int x = Mathf.Max(0, (int)(cx - r)); x <= Mathf.Min(S - 1, (int)(cx + r)); x++)
                if (Vector2.Distance(new Vector2(x, y), new Vector2(cx, cy)) < r) buf[y * S + x] = c;
    }
    void SoftDisc(float cx, float cy, float r, Color c)
    {
        for (int y = Mathf.Max(0, (int)(cy - r)); y <= Mathf.Min(S - 1, (int)(cy + r)); y++)
            for (int x = Mathf.Max(0, (int)(cx - r)); x <= Mathf.Min(S - 1, (int)(cx + r)); x++)
            {
                float k = Vector2.Distance(new Vector2(x, y), new Vector2(cx, cy)) / r;
                if (k < 1f) px[y * S + x] = Color.Lerp(px[y * S + x], new Color(c.r, c.g, c.b), c.a * (1f - k) * (1f - k));
            }
    }
    void Line(Vector2 a, Vector2 b, Color c)
    {
        int n = Mathf.CeilToInt(Vector2.Distance(a, b));
        for (int i = 0; i <= n; i++)
        {
            Vector2 p = Vector2.Lerp(a, b, n == 0 ? 0 : i / (float)n);
            int x = (int)p.x, y = (int)p.y;
            if (x >= 0 && x < S && y >= 0 && y < S) px[y * S + x] = Color.Lerp(px[y * S + x], new Color(c.r, c.g, c.b), c.a);
        }
    }
    void Tri(Vector2 a, Vector2 b, Vector2 c)   // rasterise one fan triangle into the light mask
    {
        int y0 = Mathf.Max(0, (int)Mathf.Min(a.y, Mathf.Min(b.y, c.y))), y1 = Mathf.Min(S - 1, (int)Mathf.Max(a.y, Mathf.Max(b.y, c.y)));
        int x0 = Mathf.Max(0, (int)Mathf.Min(a.x, Mathf.Min(b.x, c.x))), x1 = Mathf.Min(S - 1, (int)Mathf.Max(a.x, Mathf.Max(b.x, c.x)));
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++)
        {
            var p = new Vector2(x + 0.5f, y + 0.5f);
            float w0 = Edge(b, c, p), w1 = Edge(c, a, p), w2 = Edge(a, b, p);
            if ((w0 >= 0 && w1 >= 0 && w2 >= 0) || (w0 <= 0 && w1 <= 0 && w2 <= 0)) mask[y * S + x] = 1f;
        }
    }
    static float Edge(Vector2 a, Vector2 b, Vector2 p) => (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);

    void OnGUI()
    {
        string[] names = { "",
            $"Ordered — Bayer 4×4, {levels} levels (click cycles 2/3/4); URP: Full Screen Pass Renderer Feature + Fullscreen Shader Graph",
            $"Quantise — nearest of {PALETTES[palette].Length} palette colours (click cycles); URP: Volume → Color Lookup, or the same loop in a fullscreen pass",
            $"Xsplit — chromatic split {split:0.000} per px of radius (click: distance from centre); URP: Volume → Chromatic Aberration.intensity",
            $"Visibility — {rays} rays to every corner ±ε, sorted, fan-filled (click pins the lamp); URP 2D: Light2D (Point) + ShadowCaster2D",
            $"Healthbar — hp {hp:0.00}, ghost {ghost:0.00} (click = hit); uGUI: two Filled Images, white.fillAmount chases red over 0.5 s",
            $"Pool — {alive}/{POOL} slots borrowed · pool allocations: {poolAllocs} since start · naive `new` would be {naiveAllocs} · stolen {stolen} (click = burst); UnityEngine.Pool.ObjectPool<T>" };
        GUI.Label(new Rect(10, 10, 1200, 44), "STAGECRAFT (2D) — keys 1–6 · " + names[mode]);
    }
}
