// MOVEMENT PERSONALITIES — one dot, eight souls.
// Personality is not what moves — it's the SHAPE of the speed. Each recipe
// maps journey-progress u (0→1) to a position; the dot replays it.
// Keys 1–8 switch personality, Space replays, L toggles looping.
// Chapter 05 of the book.
using UnityEngine;

public class EasingPersonalities : MonoBehaviour
{
    static readonly string[] Names = { "human", "superhuman", "alien", "excited",
                                       "sad", "emotionless", "robot", "stately" };
    static readonly float[] Duration = { 2.0f, 2.2f, 3.4f, 2.4f, 3.6f, 2.4f, 3.0f, 4.2f };

    int soul;
    float t;
    bool playing = true, looping;
    Transform dot;

    void Start()
    {
        dot = GameObject.CreatePrimitive(PrimitiveType.Sphere).transform;
        dot.localScale = Vector3.one * 0.35f;
    }

    // u (0→1) → (x across the screen, y detour) — the personality itself
    Vector2 PosFor(float u)
    {
        switch (Names[soul])
        {
            case "human":       // ease both ends + gentle bob
                float e = u < 0.5f ? 4 * u * u * u : 1 - Mathf.Pow(-2 * u + 2, 3) / 2;
                return new Vector2(e, Mathf.Sin(u * Mathf.PI * 2.2f) * 0.06f);
            case "superhuman":  // anticipation pull-back, then t⁴ snap
                if (u < 0.25f) return new Vector2(-0.05f * (u / 0.25f), 0);
                if (u < 0.45f) { float k = (u - 0.25f) / 0.2f; return new Vector2(-0.05f + 1.05f * k * k * k * k, 0); }
                return new Vector2(1, 0);
            case "alien":       // unsynced sines + abrupt reorientation
                float ya = 0.35f * Mathf.Sin(u * Mathf.PI * 2) + 0.25f * Mathf.Sin(u * Mathf.PI * 2 * 1.618f + 2);
                if ((int)(u * 5) % 2 == 1) ya = -ya * 0.6f;
                return new Vector2(Mathf.Min(1, u + 0.06f * Mathf.Sin(u * 13)), ya * 0.5f);
            case "excited":     // springy overshoot with bounces
                float ee = 1 - Mathf.Pow(2, -8 * u) * Mathf.Cos(u * 14);
                return new Vector2(Mathf.Min(1.06f, ee), -Mathf.Abs(Mathf.Sin(u * 12)) * 0.22f * (1 - u));
            case "sad":         // hesitate… then droop through a sagging arc
                if (u < 0.22f) return new Vector2(0, 0.05f);
                float ks = (u - 0.22f) / 0.78f;
                return new Vector2(1 - Mathf.Pow(1 - ks, 2.6f), 0.05f + Mathf.Sin(ks * Mathf.PI) * 0.28f);
            case "robot":       // 7 quantised steps + tiny servo settle
                float steps = 7, s = Mathf.Floor(u * steps) / steps, f = (u * steps) % 1;
                float settle = f < 0.3f ? Mathf.Sin(f / 0.3f * Mathf.PI * 3) * Mathf.Exp(-f * 10) * 0.015f : 0;
                return new Vector2(s + settle, 0);
            case "stately":     // long sine ease + wide unhurried arc
                float es = -(Mathf.Cos(Mathf.PI * u) - 1) / 2;
                return new Vector2(es, -Mathf.Sin(u * Mathf.PI) * 0.42f);
            default:            // emotionless: pure linear — that's the whole recipe
                return new Vector2(u, 0);
        }
    }

    void Update()
    {
        for (int i = 0; i < 8; i++)
            if (Input.GetKeyDown(KeyCode.Alpha1 + i)) { soul = i; t = 0; playing = true; }
        if (Input.GetKeyDown(KeyCode.Space)) { t = 0; playing = true; }
        if (Input.GetKeyDown(KeyCode.L)) { looping = !looping; t = 0; playing = true; }
        if (!playing) return;
        t += Time.deltaTime;
        float u = Mathf.Clamp01(t / Duration[soul]);
        Vector2 p = PosFor(u);
        dot.position = new Vector3(-5 + p.x * 10, -p.y * 4, 0);
        if (u >= 1) { if (looping) t = -0.4f; else playing = false; }
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        $"Personality: {Names[soul]} — 1-8 switch, Space replays, L loops ({(looping ? "on" : "off")})");
}
