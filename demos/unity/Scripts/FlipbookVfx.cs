// FLIPBOOK VFX — bake a transparent sprite sheet in code, then play it back.
// The web folio (docs/flipbook.html) bakes 26 of these; this template bakes
// three ambassadors — enough to carry the whole mechanism:
//   [1] Burst — a one-shot, played ADDITIVELY (light adds up)
//   [2] Aura  — a seamless loop (phase = i/N, so frame N lands on frame 0)
//   [3] Poof  — a one-shot, played NORMALLY (smoke is matter, not light)
// Click anywhere to retrigger the current effect at the click.
//
// The pipeline is the honest one you'd use for an artist's PNG sequence:
//   Texture2D (the sheet) → one Sprite per frame (Sprite.Create with a
//   Rect) → swap SpriteRenderer.sprite by frame index. Loop index is
//   ⌊t·fps⌋ mod N; one-shot index is min(N−1, ⌊(t−t₀)·fps⌋) with the last
//   frame baked empty, so "holding on the end" IS "the effect is over".
//
// Unity's OTHER flipbook machinery, for when you outgrow this script:
//   • Import a sheet with Sprite Mode = Multiple, slice it in the Sprite
//     Editor, and drop the frames on an Animator/Animation clip — the
//     designer-facing version of exactly this code.
//   • Particle System → Texture Sheet Animation module: every particle
//     plays the flipbook (smoke puffs, fire wisps, debris).
//   • Shader Graph's Flipbook node: the UV-offset trick on any material,
//     for meshes and VFX Graph output.
// Chapter 15 of the book.
using UnityEngine;

public class FlipbookVfx : MonoBehaviour
{
    const int S = 96;                    // baked cell size, px
    const float PPU = 96f;               // pixels per unit → each frame is 1 unit

    struct Fx
    {
        public string name;
        public int n; public float fps;
        public bool loop, additive;
        public System.Action<Color[], int, int> paint;   // (pixels, frame i, N)
    }

    Fx[] fx;
    int cur;                             // which effect [1]/[2]/[3]
    Sprite[][] frames;                   // frames[effect][i]
    SpriteRenderer sr;
    float t0;                            // one-shot start time

    void Start()
    {
        fx = new[]
        {
            new Fx { name = "Burst (one-shot, additive)", n = 10, fps = 20, loop = false, additive = true,  paint = PaintBurst },
            new Fx { name = "Aura (loop, additive)",      n = 12, fps = 12, loop = true,  additive = true,  paint = PaintAura  },
            new Fx { name = "Poof (one-shot, normal)",    n = 10, fps = 15, loop = false, additive = false, paint = PaintPoof  },
        };
        frames = new Sprite[fx.Length][];
        for (int e = 0; e < fx.Length; e++) frames[e] = Bake(fx[e]);

        var go = new GameObject("FlipbookSprite");
        go.transform.parent = transform;
        sr = go.AddComponent<SpriteRenderer>();
        Select(0);
    }

    // ---- the baker: draw every frame ONCE into one Texture2D ----------------
    Sprite[] Bake(Fx f)
    {
        var tex = new Texture2D(f.n * S, S, TextureFormat.RGBA32, false);
        tex.wrapMode = TextureWrapMode.Clamp;
        var clear = new Color(0, 0, 0, 0);               // THE point: transparent
        var px = new Color[S * S];
        var sheet = new Color[f.n * S * S];
        for (int i = 0; i < f.n; i++)
        {
            for (int p = 0; p < px.Length; p++) px[p] = clear;
            f.paint(px, i, f.n);                         // one frame, cell-local
            for (int y = 0; y < S; y++)                  // copy the cell into the
                for (int x = 0; x < S; x++)              // sheet at column i
                    sheet[y * f.n * S + i * S + x] = px[y * S + x];
        }
        tex.SetPixels(sheet);
        tex.Apply();

        var spr = new Sprite[f.n];                       // slice: one Sprite per
        for (int i = 0; i < f.n; i++)                    // rectangle of the sheet
            spr[i] = Sprite.Create(tex, new Rect(i * S, 0, S, S),
                new Vector2(0.5f, 0.5f), PPU);
        return spr;
    }

    // ---- tiny CPU rasterizer: the "artist" -----------------------------------
    // (0,0) is the cell's bottom-left; c is the centre. Additive accumulate so
    // overlapping glows brighten, exactly like canvas "lighter" at bake time.
    static void Glow(Color[] px, float cx, float cy, float r, Color col, float a)
    {
        int x0 = Mathf.Max(0, (int)(cx - r)), x1 = Mathf.Min(S - 1, (int)(cx + r));
        int y0 = Mathf.Max(0, (int)(cy - r)), y1 = Mathf.Min(S - 1, (int)(cy + r));
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
            {
                float d = Mathf.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) / r;
                if (d >= 1) continue;
                float w = (1 - d) * (1 - d) * a;         // soft radial falloff
                int idx = y * S + x;
                px[idx].r += col.r * w; px[idx].g += col.g * w; px[idx].b += col.b * w;
                px[idx].a = Mathf.Min(1, px[idx].a + w);
            }
    }
    static void Disc(Color[] px, float cx, float cy, float r, Color col)
    {
        int x0 = Mathf.Max(0, (int)(cx - r)), x1 = Mathf.Min(S - 1, (int)(cx + r));
        int y0 = Mathf.Max(0, (int)(cy - r)), y1 = Mathf.Min(S - 1, (int)(cy + r));
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
                if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r)
                {
                    int idx = y * S + x;                 // plain alpha-over blend
                    px[idx] = Color.Lerp(px[idx], new Color(col.r, col.g, col.b, 1), col.a);
                    px[idx].a = Mathf.Min(1, px[idx].a + col.a);
                }
    }

    // ---- the three ambassadors ----------------------------------------------
    static void PaintBurst(Color[] px, int i, int n)
    {
        float k = i / (n - 1f);                          // 0..1 INCLUSIVE — one-shot
        float c = S / 2f;
        if (k < 0.22f) Glow(px, c, c, 16 * (1 - k / 0.22f), new Color(0.96f, 0.95f, 0.86f), 0.95f);
        for (int j = 0; j < 12; j++)                     // twelve rays, deterministic
        {
            float a = j / 12f * Mathf.PI * 2 + j * 0.61f % 0.3f;
            float d0 = Mathf.Pow(k, 0.65f) * 34;
            for (float d = d0; d < d0 + (1 - k) * 9 + 2; d += 1.5f)
                Glow(px, c + Mathf.Cos(a) * d, c + Mathf.Sin(a) * d,
                    2.4f * (1 - k * 0.6f), new Color(0.96f, 0.63f, 0.35f), (1 - k) * 0.8f);
        }
    }
    static void PaintAura(Color[] px, int i, int n)
    {
        float kl = i / (float)n;                         // i/N — the loop is seamless
        float c = S / 2f;
        float br = 0.5f - 0.5f * Mathf.Cos(kl * Mathf.PI * 2);
        Glow(px, c, c, 24 + br * 9, new Color(0.54f, 0.85f, 0.96f), 0.5f + br * 0.3f);
        for (float a = 0; a < Mathf.PI * 2; a += 0.05f)  // the ring, dotted on
            Glow(px, c + Mathf.Cos(a) * (28 + br * 7), c + Mathf.Sin(a) * (28 + br * 7),
                2.2f, new Color(0.54f, 0.85f, 0.96f), (0.5f + br * 0.4f) * 0.5f);
    }
    static void PaintPoof(Color[] px, int i, int n)
    {
        float k = i / (n - 1f);
        float c = S / 2f;
        for (int j = 0; j < 5; j++)                      // five swelling grey blobs
        {
            float off = j * 0.04f;
            float kk = Mathf.Clamp01((k - off) / (1 - off));
            float al = (1 - kk) * 0.6f;
            if (al <= 0) continue;
            float dx = (j * 2.39f % 1f - 0.5f) * 20, dy = (j * 3.17f % 1f - 0.5f) * 12;
            float r = (7 + j * 1.4f) * (0.5f + kk * 1.1f);
            Disc(px, c + dx * (1 + kk * 0.5f), c + dy + kk * 10, r,
                new Color(0.73f, 0.71f, 0.76f, al));
        }
    }

    // ---- playback: choose an index, swap a sprite ---------------------------
    void Select(int e)
    {
        cur = e;
        t0 = Time.time;
        // Additive playback wants an additive material; normal wants the
        // default sprite material. (URP: use "Universal Render Pipeline/2D/
        // Sprite-Unlit-Default" and bake brightness in, or add Bloom.)
        var shader = fx[e].additive ? Shader.Find("Legacy Shaders/Particles/Additive")
                                    : Shader.Find("Sprites/Default");
        if (shader != null) sr.material = new Material(shader);
    }

    void Update()
    {
        for (int e = 0; e < fx.Length; e++)
            if (Input.GetKeyDown(KeyCode.Alpha1 + e)) Select(e);
        if (Input.GetMouseButtonDown(0))
        {
            var p = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            p.z = 0;
            sr.transform.position = p;
            t0 = Time.time;                              // retrigger where clicked
        }

        var f = fx[cur];
        float t = Time.time - t0;
        int i = f.loop ? (int)(t * f.fps) % f.n          // the two index lines —
              : Mathf.Min(f.n - 1, (int)(t * f.fps));    // the entire technology
        sr.sprite = frames[cur][i];
        if (!f.loop && t > f.n / f.fps + 1.1f) t0 = Time.time;   // polite replay
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 60),
        $"Flipbook VFX: [{cur + 1}] {fx[cur].name} — keys 1-3 switch, click retriggers there.\n" +
        "The sheet was baked ONCE in Start(); playback only swaps which Sprite rectangle shows.");
}
