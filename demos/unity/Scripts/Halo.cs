// HALO — a code-painted additive ring with a ±3% breath.
// Key 1 = full ring; key 2 = the thin ellipse floating over a head.
// ±3% every 3 seconds is the "it is alive" number from chapter 06.
using UnityEngine;

public class Halo : MonoBehaviour
{
    Transform halo, halo2, head;
    bool headMode;
    float t;

    void Start()
    {
        // paint the ring: alpha peaks at the ring radius, falls off both ways
        var tex = new Texture2D(256, 256, TextureFormat.RGBA32, false);
        for (int y = 0; y < 256; y++)
            for (int x = 0; x < 256; x++)
            {
                float d = new Vector2(x - 128, y - 128).magnitude;
                float fall = Mathf.Abs(d - 82f) / 26f;
                float a = Mathf.Clamp01(1 - fall); a *= a;
                tex.SetPixel(x, y, new Color(0.61f, 0.64f, 0.94f, a * 0.9f));
            }
        tex.Apply();
        var sprite = Sprite.Create(tex, new Rect(0, 0, 256, 256), new Vector2(0.5f, 0.5f), 64);
        halo = MakeSprite(sprite, 1f);
        halo2 = MakeSprite(sprite, 0.5f);                  // second copy: additive overlap
        halo2.localScale = Vector3.one * 1.25f;

        head = new GameObject("Head").transform;           // for mode 2
        var htex = new Texture2D(4, 4); var px = new Color[16];
        for (int i = 0; i < 16; i++) px[i] = new Color(0.09f, 0.08f, 0.14f);
        htex.SetPixels(px); htex.Apply();
        var hsr = head.gameObject.AddComponent<SpriteRenderer>();
        hsr.sprite = Sprite.Create(htex, new Rect(0, 0, 4, 4), new Vector2(0.5f, 0.5f), 2);
        head.gameObject.SetActive(false);
    }

    Transform MakeSprite(Sprite s, float alpha)
    {
        var go = new GameObject("Halo");
        var sr = go.AddComponent<SpriteRenderer>();
        sr.sprite = s;
        sr.color = new Color(1, 1, 1, alpha);
        sr.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
        return go.transform;
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Alpha1)) Set(false);
        if (Input.GetKeyDown(KeyCode.Alpha2)) Set(true);
        t += Time.deltaTime;
        float breath = 1f + 0.03f * Mathf.Sin(t * Mathf.PI * 2 / 3f);   // ±3% / 3 s
        if (!headMode)
        {
            halo.position = Vector3.zero;
            halo.localScale = Vector3.one * breath;
        }
        else
        {
            // the working halo: same texture squashed thin, hovering over the head
            float bob = Mathf.Sin(t * 1.2f) * 0.08f;
            halo.position = new Vector3(0, 1.6f + bob, 0);
            halo.localScale = new Vector3(0.55f * breath, 0.16f * breath, 1);
        }
    }

    void Set(bool mode)
    {
        headMode = mode;
        halo2.gameObject.SetActive(!mode);
        head.gameObject.SetActive(mode);
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 800, 40),
        "Halo: additive ring breathing at ±3%. 1 = ring, 2 = thin ellipse over a head.");
}
