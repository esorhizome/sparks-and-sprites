// CHROME & LIQUID METAL — a mirror with opinions, repainted every frame.
// Chrome is a LOOKUP: each height on the ball reads a brightness from a
// striped fake world (a 1-D environment map — the matcap idea). LIQUID
// wobbles where the lookup happens; the glint is a moving bright band.
// Click to toggle rigid ↔ molten. Chapter 06 of the book.
using UnityEngine;

public class MetalChrome : MonoBehaviour
{
    Texture2D tex;
    float t, liquid = 0.5f;
    const int Size = 128;

    // the fake world: sky, horizon line, ground, sky — as [stop, colour]
    static readonly (float k, Color c)[] Bands = {
        (0.00f, new Color(0.99f, 0.99f, 1f)),
        (0.42f, new Color(0.63f, 0.67f, 0.77f)),
        (0.50f, new Color(0.15f, 0.17f, 0.24f)),
        (0.58f, new Color(0.38f, 0.42f, 0.50f)),
        (1.00f, new Color(0.82f, 0.86f, 0.94f)) };

    void Start()
    {
        tex = new Texture2D(Size, Size, TextureFormat.RGBA32, false);
        var quad = GameObject.CreatePrimitive(PrimitiveType.Quad);
        quad.transform.localScale = new Vector3(4, 4, 1);
        var m = quad.GetComponent<Renderer>().material;
        m.shader = Shader.Find("Unlit/Transparent");
        m.mainTexture = tex;
    }

    Color BandColor(float k)
    {
        for (int i = 0; i < Bands.Length - 1; i++)
            if (k <= Bands[i + 1].k)
                return Color.Lerp(Bands[i].c, Bands[i + 1].c,
                    (k - Bands[i].k) / Mathf.Max(0.001f, Bands[i + 1].k - Bands[i].k));
        return Bands[^1].c;
    }

    void Update()
    {
        if (Input.GetMouseButtonDown(0)) liquid = liquid < 0.75f ? 1f : 0f;
        t += Time.deltaTime;
        float c = Size / 2f, radius = Size * 0.46f;
        var px = new Color[Size * Size];
        for (int y = 0; y < Size; y++)
        {
            float k = y / (float)(Size - 1);               // 0 = top of ball, 1 = bottom
            float half = Mathf.Sqrt(Mathf.Max(0, radius * radius - (y - c) * (y - c)));
            // the liquid wobble bends WHERE this scanline samples the fake world
            float wob = Mathf.Sin(k * 9 + t * 2.2f) * 0.06f * liquid;
            Color col = BandColor(Mathf.Clamp01(1 - k + wob));
            // the glint: a bright band sweeping down every few seconds
            float glint = Mathf.Exp(-Mathf.Pow((1 - k - (t * 0.45f % 1.4f)) * 9f, 2));
            col = Color.Lerp(col, Color.white, glint * 0.8f);
            for (int x = 0; x < Size; x++)
                px[y * Size + x] = Mathf.Abs(x - c) < half ? col : Color.clear;
        }
        tex.SetPixels(px);
        tex.Apply();
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        $"Chrome ball (liquid = {liquid:0.0}): click to toggle rigid/molten. Each scanline reads a striped fake world.");
}
