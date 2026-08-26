// INFINITE SCROLL — the one-line UV trick, Unity spelling.
// The texture doesn't move; WHERE WE READ IT moves. mainTextureOffset
// slides the read position, wrap mode Repeat wraps it forever.
// Chapter 04 of the book.
using UnityEngine;

public class ScrollUV : MonoBehaviour
{
    Material far, near;

    void Start()
    {
        far = Layer(0.02f, new Color(0.61f, 0.63f, 0.87f), 4.9f);   // slow = far
        near = Layer(0.09f, new Color(0.45f, 0.38f, 0.62f), 5f);    // fast = near
    }

    Material Layer(float unused, Color tint, float z)
    {
        // a seamless "cloudy" tile painted in code (no image files needed)
        var tex = new Texture2D(128, 128, TextureFormat.RGBA32, false);
        tex.wrapMode = TextureWrapMode.Repeat;             // ← lets the offset wrap
        var px = new Color[128 * 128];
        var rng = new System.Random(4477);                 // pinned seed: same tile every run
        for (int i = 0; i < px.Length; i++) px[i] = Color.clear;
        for (int blob = 0; blob < 30; blob++)
        {
            float bx = (float)rng.NextDouble() * 128, by = (float)rng.NextDouble() * 128;
            float r = 8 + (float)rng.NextDouble() * 14;
            for (int y = 0; y < 128; y++)
                for (int x = 0; x < 128; x++)
                {
                    // seamless: measure distance on the wrapped torus
                    float dx = Mathf.Min(Mathf.Abs(x - bx), 128 - Mathf.Abs(x - bx));
                    float dy = Mathf.Min(Mathf.Abs(y - by), 128 - Mathf.Abs(y - by));
                    if (dx * dx + dy * dy < r * r)
                        px[y * 128 + x] = Color.Lerp(px[y * 128 + x], new Color(tint.r, tint.g, tint.b, 1), 0.13f);
                }
        }
        tex.SetPixels(px); tex.Apply();

        var quad = GameObject.CreatePrimitive(PrimitiveType.Quad);
        quad.transform.position = new Vector3(0, 0, z);
        quad.transform.localScale = new Vector3(16, 9, 1);
        var m = quad.GetComponent<Renderer>().material;
        m.shader = Shader.Find("Unlit/Transparent");
        m.mainTexture = tex;
        m.mainTextureScale = new Vector2(7, 4);            // tile it across the quad
        return m;
    }

    void Update()
    {
        // ← the line. Two layers, two speeds; the gap between them is the depth.
        far.mainTextureOffset += new Vector2(0.02f * Time.deltaTime, 0);
        near.mainTextureOffset += new Vector2(0.09f * Time.deltaTime, 0);
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 800, 40),
        "Infinite scroll: one tile, endless sky. mainTextureOffset += speed * dt — that's everything.");
}
