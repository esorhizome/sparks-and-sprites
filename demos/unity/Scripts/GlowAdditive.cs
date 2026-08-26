// ADDITIVE GLOW — light that adds up where it overlaps.
// Three soft blobs on an additive material orbit slowly; wherever they
// cross, the colours SUM toward white — that's what "made of light" means.
// Chapter 03 of the book.
using UnityEngine;

public class GlowAdditive : MonoBehaviour
{
    Transform[] blobs = new Transform[3];
    static readonly Color[] Cols = {
        new Color(0.47f, 0.55f, 1f), new Color(1f, 0.47f, 0.78f), new Color(0.47f, 0.9f, 0.86f) };
    float t;

    void Start()
    {
        // a soft radial blob, painted in code: alpha falls off from the centre
        var tex = new Texture2D(64, 64, TextureFormat.RGBA32, false);
        for (int y = 0; y < 64; y++)
            for (int x = 0; x < 64; x++)
            {
                float d = new Vector2(x - 32, y - 32).magnitude / 32f;
                float a = Mathf.Clamp01(1 - d); a *= a;
                tex.SetPixel(x, y, new Color(1, 1, 1, a));
            }
        tex.Apply();
        var sprite = Sprite.Create(tex, new Rect(0, 0, 64, 64), new Vector2(0.5f, 0.5f), 24);
        for (int i = 0; i < 3; i++)
        {
            var go = new GameObject("Blob" + i);
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = sprite;
            sr.color = Cols[i];
            // the whole lesson is this one material choice:
            sr.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
            blobs[i] = go.transform;
        }
    }

    void Update()
    {
        t += Time.deltaTime;
        for (int i = 0; i < 3; i++)
            blobs[i].position = new Vector3(
                Mathf.Cos(t * 0.7f + i * 2.1f) * 1.4f,
                Mathf.Sin(t * 1.1f + i * 2.1f) * 0.9f, 0);
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 800, 40),
        "Additive glow: three coloured blobs summing toward white where they overlap.");
}
