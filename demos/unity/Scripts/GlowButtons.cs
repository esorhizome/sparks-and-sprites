// LIVING BUTTONS — the two species from chapter 12, Unity spelling.
// Button A (top): a STATIC LOOP — plasma blobs orbiting behind the face.
// Button B (bottom): TAP-REACTIVE — a click adds spin VELOCITY, and
// per-frame friction turns the push into a free ease-out.
// Click both. Chapter 12 of the book.
using UnityEngine;

public class GlowButtons : MonoBehaviour
{
    Transform[] plasma = new Transform[3];
    Transform face, ringA, ringB, ringC;
    float t, energy, spin, spinVel;
    static readonly Color[] Cols = {
        new Color(0.47f, 0.55f, 1f), new Color(1f, 0.47f, 0.78f), new Color(0.47f, 0.9f, 0.86f) };

    void Start()
    {
        var blob = SoftDot(64, 1f);
        for (int i = 0; i < 3; i++)                        // the plasma, BEHIND the face
        {
            plasma[i] = SpriteAt(blob, Cols[i], true, new Vector3(0, 1.6f, 1));
            plasma[i].localScale = Vector3.one * 2.2f;
        }
        var faceTex = new Texture2D(4, 4); var px = new Color[16];
        for (int i = 0; i < 16; i++) px[i] = new Color(0.07f, 0.055f, 0.125f, 0.84f);
        faceTex.SetPixels(px); faceTex.Apply();
        face = SpriteAt(Sprite.Create(faceTex, new Rect(0, 0, 4, 4), new Vector2(0.5f, 0.5f), 1.5f),
            Color.white, false, new Vector3(0, 1.6f, 0));
        face.localScale = new Vector3(1.1f, 0.35f, 1);

        var ring = RingSprite();                            // button B: three gappy rings
        ringA = SpriteAt(ring, new Color(0.59f, 0.86f, 0.82f), true, new Vector3(0, -1.6f, 0));
        ringB = SpriteAt(ring, new Color(0.59f, 0.86f, 0.82f), true, new Vector3(0, -1.6f, 0));
        ringC = SpriteAt(ring, new Color(0.59f, 0.86f, 0.82f), true, new Vector3(0, -1.6f, 0));
        ringB.localScale = Vector3.one * 0.72f;
        ringC.localScale = Vector3.one * 0.45f;
    }

    void Update()
    {
        t += Time.deltaTime;
        for (int i = 0; i < 3; i++)                        // three blobs, three speeds
            plasma[i].position = new Vector3(
                Mathf.Cos(t * 0.7f + i * 2.1f) * 0.9f,
                1.6f + Mathf.Sin(t * 1.1f + i * 2.1f) * 0.35f, 1);
        energy = Mathf.Max(0, energy - Time.deltaTime * 2);
        foreach (var p in plasma)
            p.GetComponent<SpriteRenderer>().color = new Color(1, 1, 1, 0.5f + energy * 0.5f);

        spin += spinVel * Time.deltaTime;
        spinVel *= Mathf.Pow(0.15f, Time.deltaTime);       // friction → built-in ease-out
        ringA.rotation = Quaternion.Euler(0, 0, t * 8f + spin);
        ringB.rotation = Quaternion.Euler(0, 0, -t * 6f - spin);
        ringC.rotation = Quaternion.Euler(0, 0, t * 3.5f + spin);

        if (Input.GetMouseButtonDown(0))
        {
            var p = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            if (Mathf.Abs(p.x) < 1.6f && Mathf.Abs(p.y - 1.6f) < 0.6f) energy = 1;       // flare
            if (Vector2.Distance(p, new Vector2(0, -1.6f)) < 1.4f) spinVel += 360;       // a push
        }
    }

    Sprite SoftDot(int s, float pow)
    {
        var tex = new Texture2D(s, s, TextureFormat.RGBA32, false);
        for (int y = 0; y < s; y++)
            for (int x = 0; x < s; x++)
            {
                float d = new Vector2(x - s / 2f, y - s / 2f).magnitude / (s / 2f);
                tex.SetPixel(x, y, new Color(1, 1, 1, Mathf.Pow(Mathf.Clamp01(1 - d), 2) * pow));
            }
        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, s, s), new Vector2(0.5f, 0.5f), s / 2f);
    }

    Sprite RingSprite()
    {
        int s = 128;
        var tex = new Texture2D(s, s, TextureFormat.RGBA32, false);
        for (int y = 0; y < s; y++)
            for (int x = 0; x < s; x++)
            {
                var v = new Vector2(x - 64, y - 64);
                float band = Mathf.Abs(v.magnitude - 52) < 5 ? 1 : 0;
                // gaps make rotation visible: keep ~76% of the circle
                float ang = Mathf.Atan2(v.y, v.x);
                if (Mathf.Repeat(ang, 2.1f) > 1.6f) band = 0;
                tex.SetPixel(x, y, new Color(1, 1, 1, band * 0.85f));
            }
        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, s, s), new Vector2(0.5f, 0.5f), 52);
    }

    Transform SpriteAt(Sprite s, Color c, bool additive, Vector3 pos)
    {
        var go = new GameObject("s");
        var sr = go.AddComponent<SpriteRenderer>();
        sr.sprite = s; sr.color = c;
        if (additive) sr.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
        go.transform.position = pos;
        return go.transform;
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        "Living buttons: click both. Top = plasma static loop; bottom = tap adds VELOCITY, friction is the easing.");
}
