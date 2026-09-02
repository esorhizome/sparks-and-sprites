// DEPTH ATLAS (2D) — the illusion of depth on a flat plane, painted from code.
// The web atlas (docs/depth.html) draws 104 of these; this template paints
// six AMBASSADORS — one per load-bearing cue — into code-generated sprites:
//   [1] Sky        — a vertical gradient is a clock and a compass
//   [2] Ridges     — atmospheric perspective: far layers mixed toward the air
//   [3] Orb        — a radial gradient with its centre pushed toward the light
//   [4] Block      — three flat shades meeting at an edge = a cube from squares
//   [5] Plume      — depth-sorted smoke: one z drives size, darkness, speed
//   [6] Contact    — a shadow that shrinks and fades as the ball rises
// Keys 1–6 switch; click moves the light / lifts the ball / scrubs the sky.
//
// Unity has no "fill with gradient" call either, so every gradient here is
// the honest thing: a Gradient asset (colour + alpha keys) evaluated per
// pixel into a Texture2D, then shown by a SpriteRenderer. That is also what
// Shader Graph's Gradient node does — on the GPU, per frame, for free.
// The placing rules never change between platforms; only the spelling does.
// Chapter 16 of the book.
using UnityEngine;

public class DepthAtlas2D : MonoBehaviour
{
    const int S = 256;                 // texture size, px
    const float PPU = 128f;            // pixels per unit → the card is 2 units wide

    int mode = 1;
    float t;
    float lx = -0.5f, ly = -0.5f;      // light direction, −1..1 (rounded-form cue)
    float lift;                        // ball height (contact-shadow cue)
    Texture2D tex;
    SpriteRenderer sr;
    Color[] px;

    struct Puff { public float x, y0, z, phase; }
    Puff[] puffs;

    void Start()
    {
        tex = new Texture2D(S, S, TextureFormat.RGBA32, false);
        tex.wrapMode = TextureWrapMode.Clamp;
        px = new Color[S * S];
        var go = new GameObject("AtlasCard");
        go.transform.parent = transform;
        sr = go.AddComponent<SpriteRenderer>();
        sr.sprite = Sprite.Create(tex, new Rect(0, 0, S, S), new Vector2(0.5f, 0.5f), PPU);
        puffs = new Puff[26];
        var rng = new System.Random(7);                              // a seed: same smoke every run
        for (int i = 0; i < puffs.Length; i++)
            puffs[i] = new Puff { x = (float)rng.NextDouble(), y0 = (float)rng.NextDouble(), z = (float)rng.NextDouble(), phase = (float)rng.NextDouble() };
        System.Array.Sort(puffs, (a, b) => a.z.CompareTo(b.z));     // far first — the painter's algorithm
    }

    void Update()
    {
        t += Time.deltaTime;
        for (int k = 1; k <= 6; k++) if (Input.GetKeyDown(KeyCode.Alpha0 + k)) mode = k;
        if (Input.GetMouseButtonDown(0))
        {
            var w = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            lx = Mathf.Clamp(w.x, -1f, 1f); ly = Mathf.Clamp(-w.y, -1f, 1f);
            lift = Mathf.Clamp01((w.y + 1f) * 0.5f);
        }
        Clear(new Color(0.075f, 0.063f, 0.125f));
        switch (mode)
        {
            case 1: Sky(); break;
            case 2: Ridges(); break;
            case 3: Orb(); break;
            case 4: Block(); break;
            case 5: Plume(); break;
            case 6: Contact(); break;
        }
        tex.SetPixels(px); tex.Apply();
    }

    // ---- [1] the sky: two colour stops, mixed by a clock -------------------
    void Sky()
    {
        float k = 0.5f - 0.5f * Mathf.Cos(t * 0.2f);                  // 0 night … 1 day, and back
        Color top = Color.Lerp(new Color(0.02f, 0.02f, 0.10f), new Color(0.44f, 0.66f, 0.91f), k);
        Color hor = Color.Lerp(new Color(0.10f, 0.06f, 0.19f), new Color(0.96f, 0.63f, 0.35f), Mathf.Sin(k * Mathf.PI));
        for (int y = 0; y < S; y++)
        {
            Color c = Color.Lerp(top, hor, Mathf.Pow(1f - y / (float)S, 1.6f)); // paler toward the horizon (row 0 = bottom)
            for (int x = 0; x < S; x++) px[y * S + x] = c;
        }
        Disc(S * 0.62f, S * (0.2f + k * 0.5f), S * 0.07f, new Color(1f, 0.95f, 0.8f), true);   // the sun climbs
    }

    // ---- [2] ridges: each layer mixed toward the air colour by depth -------
    void Ridges()
    {
        Color air = new Color(0.62f, 0.70f, 0.85f), near = new Color(0.12f, 0.10f, 0.20f);
        for (int y = 0; y < S; y++) for (int x = 0; x < S; x++) px[y * S + x] = Color.Lerp(air, new Color(0.30f, 0.45f, 0.75f), y / (float)S);
        for (int layer = 0; layer < 5; layer++)
        {
            float depth = 1f - layer / 5f;                             // layer 0 is the farthest
            Color c = Color.Lerp(near, air, depth * 0.85f);            // THE cue: more air, more air-colour
            float baseY = S * (0.55f - depth * 0.25f);
            for (int x = 0; x < S; x++)
            {
                float u = x / (float)S + layer * 0.7f + t * 0.01f * (1f - depth);   // near layers drift more (parallax)
                float h = baseY + S * (0.08f * Mathf.Sin(u * 6f) + 0.04f * Mathf.Sin(u * 15f + layer)) * (1.2f - depth * 0.6f);
                for (int y = 0; y < h && y < S; y++) px[y * S + x] = c;
            }
        }
    }

    // ---- [3] the orb: a radial gradient offset toward the light -----------
    void Orb()
    {
        Vector2 c = new Vector2(S * 0.5f, S * 0.5f); float r = S * 0.3f;
        Vector2 hi = c + new Vector2(lx, -ly) * r * 0.55f;            // the highlight's home — THE offset
        Color body = new Color(0.54f, 0.39f, 0.78f);
        Shadow(c.x, S * 0.18f, r * 0.9f, r * 0.25f, 0.45f);
        for (int y = 0; y < S; y++) for (int x = 0; x < S; x++)
        {
            float d = Vector2.Distance(new Vector2(x, y), c);
            if (d > r) continue;
            float k = Mathf.Clamp01(Vector2.Distance(new Vector2(x, y), hi) / (r * 1.4f));  // 0 at the highlight, 1 far from it
            Color col = k < 0.35f ? Color.Lerp(Lighten(body, 0.35f), body, k / 0.35f)
                      : k < 0.8f ? Color.Lerp(body, Darken(body, 0.35f), (k - 0.35f) / 0.45f)
                      : Color.Lerp(Darken(body, 0.35f), Darken(body, 0.75f), (k - 0.8f) / 0.2f);
            px[y * S + x] = col;
        }
        Disc(S * (0.5f + lx * 0.45f), S * (0.5f - ly * 0.45f), 4f, Color.white, false);   // where the light is
    }

    // ---- [4] the block: three flat shades from one light --------------------
    void Block()
    {
        Color c = new Color(0.36f, 0.50f, 0.78f);
        Color top = Lighten(c, 0.32f), left = c, right = Darken(c, 0.42f);
        float s = S * 0.28f; Vector2 b = new Vector2(S * 0.5f, S * 0.22f);   // base point
        Vector2 dx = new Vector2(0.866f * s, 0), dy = new Vector2(0, 0.5f * s), up = new Vector2(0, s);
        Shadow(b.x, b.y - 4, s * 1.1f, s * 0.35f, 0.4f);
        Quad(b, b - dx + dy, b - dx + dy + up, b + up, left);
        Quad(b, b + dx + dy, b + dx + dy + up, b + up, right);
        Quad(b + up, b - dx + dy + up, b + 2 * dy + up, b + dx + dy + up, top);
    }

    // ---- [5] the plume: one z drives size, darkness, speed -----------------
    void Plume()
    {
        Color air = new Color(0.55f, 0.58f, 0.70f), soot = new Color(0.10f, 0.09f, 0.14f);
        for (int i = 0; i < puffs.Length; i++)
        {
            var p = puffs[i];
            float rise = (p.y0 + t * (0.05f + p.z * 0.12f)) % 1f;    // near puffs rise faster
            float y = S * (0.1f + rise * 0.85f), x = S * (0.5f + (p.x - 0.5f) * 0.3f * (0.3f + rise) + Mathf.Sin(t + p.phase * 6f) * 0.03f);
            float rad = S * (0.03f + p.z * 0.07f) * (0.4f + rise);    // near puffs are bigger
            Color col = Color.Lerp(air, soot, p.z);                    // near puffs are darker
            col.a = (1f - rise) * (0.35f + p.z * 0.5f);
            SoftDisc(x, y, rad, col);
        }
    }

    // ---- [6] contact shadow: the shadow places the ball ---------------------
    void Contact()
    {
        float ground = S * 0.2f, r = S * 0.12f;
        float h = lift * S * 0.45f;                                    // click higher = lift higher
        float k = h / (S * 0.45f);
        Shadow(S * 0.5f, ground, r * (1.1f - k * 0.6f), r * (0.35f - k * 0.2f), 0.55f * (1f - k * 0.8f));   // smaller, fainter with height
        for (int y = 0; y < S; y++) for (int x = 0; x < S; x++)
        {
            float d = Vector2.Distance(new Vector2(x, y), new Vector2(S * 0.5f, ground + r + h));
            if (d < r) px[y * S + x] = Color.Lerp(new Color(0.96f, 0.76f, 0.41f), new Color(0.45f, 0.25f, 0.10f), Mathf.Pow(d / r, 2f));
        }
    }

    // ---- the tiny painter ----------------------------------------------------
    void Clear(Color c) { for (int i = 0; i < px.Length; i++) px[i] = c; }
    static Color Lighten(Color c, float k) => Color.Lerp(c, Color.white, k);
    static Color Darken(Color c, float k) => Color.Lerp(c, Color.black, k);
    void Disc(float cx, float cy, float r, Color c, bool glow)
    {
        int x0 = Mathf.Max(0, (int)(cx - r * 4)), x1 = Mathf.Min(S - 1, (int)(cx + r * 4));
        int y0 = Mathf.Max(0, (int)(cy - r * 4)), y1 = Mathf.Min(S - 1, (int)(cy + r * 4));
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++)
        {
            float d = Vector2.Distance(new Vector2(x, y), new Vector2(cx, cy));
            if (d < r) px[y * S + x] = c;
            else if (glow && d < r * 4) px[y * S + x] += c * (1f - d / (r * 4)) * 0.25f;   // additive falloff
        }
    }
    void SoftDisc(float cx, float cy, float r, Color c)
    {
        int x0 = Mathf.Max(0, (int)(cx - r)), x1 = Mathf.Min(S - 1, (int)(cx + r));
        int y0 = Mathf.Max(0, (int)(cy - r)), y1 = Mathf.Min(S - 1, (int)(cy + r));
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++)
        {
            float k = Vector2.Distance(new Vector2(x, y), new Vector2(cx, cy)) / r;
            if (k >= 1f) continue;
            float a = c.a * (1f - k) * (1f - k);
            px[y * S + x] = Color.Lerp(px[y * S + x], new Color(c.r, c.g, c.b), a);      // matter covers (source-over)
        }
    }
    void Shadow(float cx, float cy, float rx, float ry, float a)
    {
        for (int y = Mathf.Max(0, (int)(cy - ry)); y < Mathf.Min(S, cy + ry); y++)
            for (int x = Mathf.Max(0, (int)(cx - rx)); x < Mathf.Min(S, cx + rx); x++)
            {
                float k = Mathf.Sqrt(Mathf.Pow((x - cx) / rx, 2) + Mathf.Pow((y - cy) / ry, 2));
                if (k < 1f) px[y * S + x] = Color.Lerp(px[y * S + x], Color.black, a * (1f - k));
            }
    }
    void Quad(Vector2 a, Vector2 b, Vector2 c, Vector2 d, Color col)
    {
        Tri(a, b, c, col); Tri(a, c, d, col);
    }
    void Tri(Vector2 a, Vector2 b, Vector2 c, Color col)
    {
        int y0 = Mathf.Max(0, (int)Mathf.Min(a.y, Mathf.Min(b.y, c.y))), y1 = Mathf.Min(S - 1, (int)Mathf.Max(a.y, Mathf.Max(b.y, c.y)));
        int x0 = Mathf.Max(0, (int)Mathf.Min(a.x, Mathf.Min(b.x, c.x))), x1 = Mathf.Min(S - 1, (int)Mathf.Max(a.x, Mathf.Max(b.x, c.x)));
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++)
        {
            var p = new Vector2(x + 0.5f, y + 0.5f);
            float w0 = Edge(b, c, p), w1 = Edge(c, a, p), w2 = Edge(a, b, p);
            if ((w0 >= 0 && w1 >= 0 && w2 >= 0) || (w0 <= 0 && w1 <= 0 && w2 <= 0)) px[y * S + x] = col;
        }
    }
    static float Edge(Vector2 a, Vector2 b, Vector2 p) => (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);

    void OnGUI()
    {
        string[] names = { "", "Sky — a vertical gradient is a clock (mixes over time)", "Ridges — far layers mixed toward the air",
            "Orb — click to move the light; the highlight offset IS the roundness", "Block — three flat shades from one light",
            "Plume — one z drives size, darkness and speed; sorted far → near", "Contact — click higher to lift the ball; the shadow shrinks and fades" };
        GUI.Label(new Rect(10, 10, 900, 22), "DEPTH ATLAS (2D) — keys 1–6 · " + names[mode]);
    }
}
