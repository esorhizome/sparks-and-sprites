// RESPONSIVE CURSOR — hide the real cursor, draw a companion that CHASES it.
// The chase lag is deliberate: easing into latency looks alive; fighting it
// looks laggy. Sparkles shed by distance moved; press = flinch + pop.
// Chapter 12 of the book. (Rule: never hide the cursor without a replacement.)
using UnityEngine;

public class CursorSparkle : MonoBehaviour
{
    Transform companion;
    ParticleSystem sparkles;
    Vector3 lastMouse;
    float travelled, squish;

    void Start()
    {
        Cursor.visible = false;                            // …because we draw a better one
        var tex = new Texture2D(32, 32, TextureFormat.RGBA32, false);
        for (int y = 0; y < 32; y++)
            for (int x = 0; x < 32; x++)
            {
                float d = new Vector2(x - 16, y - 16).magnitude / 16f;
                tex.SetPixel(x, y, new Color(0.75f, 0.78f, 1f, Mathf.Pow(Mathf.Clamp01(1 - d), 1.6f)));
            }
        tex.Apply();
        companion = new GameObject("Companion").transform;
        var sr = companion.gameObject.AddComponent<SpriteRenderer>();
        sr.sprite = Sprite.Create(tex, new Rect(0, 0, 32, 32), new Vector2(0.5f, 0.5f), 48);
        sr.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));

        sparkles = companion.gameObject.AddComponent<ParticleSystem>();  // shed by distance
        var main = sparkles.main;
        main.startLifetime = 0.6f;
        main.startSpeed = new ParticleSystem.MinMaxCurve(0.2f, 1f);
        main.startSize = 0.06f;
        main.startColor = new Color(0.95f, 0.9f, 1f);
        var em = sparkles.emission;
        em.rateOverTime = 0;
        em.rateOverDistance = 4;                           // the chapter-12 rule again
        sparkles.GetComponent<ParticleSystemRenderer>().material =
            new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
    }

    void OnDestroy() => Cursor.visible = true;             // hand the cursor back politely

    void Update()
    {
        var m = Camera.main.ScreenToWorldPoint(Input.mousePosition);
        m.z = 0;
        // the chase: x += (target − x) · 12 · dt — the lag is the personality
        companion.position = Vector3.Lerp(companion.position, m, 12f * Time.deltaTime);
        squish = Mathf.Max(0, squish - Time.deltaTime * 3);
        companion.localScale = new Vector3(1 + squish * 0.45f, 1 - squish * 0.45f, 1);
        if (Input.GetMouseButtonDown(0))
        {
            squish = 1;                                    // the flinch
            sparkles.Emit(16);                             // the pop
        }
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        "Responsive cursor: move, then click. The circle chases the pointer; sparkles shed by distance.");
}
