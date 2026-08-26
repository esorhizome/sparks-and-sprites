// WATERDROPS — fall, splash, ripple: a particle's DEATH as an event.
// The node-free spelling: plain C# lists. One drop reaching the waterline
// spawns two new things — splash droplets and an expanding ripple ring.
// (Unity's packaged version of this hand-off is Sub Emitters.)
// Click for a downpour. Chapter 06 of the book.
using System.Collections.Generic;
using UnityEngine;

public class Waterdrops : MonoBehaviour
{
    class P { public Vector2 pos, vel; public float life = 1; }
    readonly List<P> drops = new(), splash = new();
    readonly List<float[]> ripples = new();   // [x, radius, life]
    float spawn, boost;
    Sprite dot;
    readonly List<SpriteRenderer> pool = new();
    const float WaterY = -1.5f;

    void Start()
    {
        var tex = new Texture2D(8, 8, TextureFormat.RGBA32, false);
        for (int y = 0; y < 8; y++)
            for (int x = 0; x < 8; x++)
                tex.SetPixel(x, y, new Vector2(x - 4, y - 4).magnitude < 3.4f ? Color.white : Color.clear);
        tex.Apply();
        dot = Sprite.Create(tex, new Rect(0, 0, 8, 8), new Vector2(0.5f, 0.5f), 32);
    }

    void Update()
    {
        float dt = Time.deltaTime;
        boost = Mathf.Max(0, boost - dt * 0.5f);
        if (Input.GetMouseButtonDown(0)) boost = 1;
        spawn -= dt;
        if (spawn <= 0)
        {
            drops.Add(new P { pos = new Vector2(Random.Range(-7f, 7f), 5f), vel = new Vector2(0, -Random.Range(6f, 9f)) });
            spawn = Random.Range(0.08f, 0.3f) * (1 - boost * 0.85f);
        }
        for (int i = drops.Count - 1; i >= 0; i--)
        {
            drops[i].pos += drops[i].vel * dt;
            if (drops[i].pos.y <= WaterY)                   // the death — and the two births
            {
                for (int k = 0; k < 5; k++)
                    splash.Add(new P { pos = new Vector2(drops[i].pos.x, WaterY),
                        vel = new Vector2(Random.Range(-2f, 2f), Random.Range(2f, 4.5f)) });
                ripples.Add(new[] { drops[i].pos.x, 0.05f, 1f });
                drops.RemoveAt(i);
            }
        }
        for (int i = splash.Count - 1; i >= 0; i--)
        {
            splash[i].pos += splash[i].vel * dt;
            splash[i].vel.y -= 9f * dt;
            splash[i].life -= dt * 1.4f;
            if (splash[i].life <= 0) splash.RemoveAt(i);
        }
        for (int i = ripples.Count - 1; i >= 0; i--)
        {
            ripples[i][1] += 1.2f * dt;
            ripples[i][2] -= 0.8f * dt;
            if (ripples[i][2] <= 0) ripples.RemoveAt(i);
        }
        Render();
    }

    // a tiny sprite pool renders drops + splash; ripples are Debug-free rings
    void Render()
    {
        int need = drops.Count + splash.Count + ripples.Count * 12;
        while (pool.Count < need)
        {
            var sr = new GameObject("p").AddComponent<SpriteRenderer>();
            sr.sprite = dot;
            pool.Add(sr);
        }
        int u = 0;
        foreach (var d in drops) Place(pool[u++], d.pos, 0.7f, new Color(0.62f, 0.82f, 1f, 0.8f));
        foreach (var s in splash) Place(pool[u++], s.pos, 0.4f, new Color(0.75f, 0.9f, 1f, s.life));
        foreach (var r in ripples)                          // a ring as 12 dots (cheap + honest)
            for (int k = 0; k < 12; k++)
            {
                float a = k / 12f * Mathf.PI * 2;
                Place(pool[u++], new Vector2(r[0] + Mathf.Cos(a) * r[1], WaterY + Mathf.Sin(a) * r[1] * 0.3f),
                    0.25f, new Color(0.7f, 0.88f, 1f, r[2] * 0.8f));
            }
        for (; u < pool.Count; u++) pool[u].enabled = false;
    }

    void Place(SpriteRenderer sr, Vector2 p, float s, Color c)
    { sr.enabled = true; sr.transform.position = p; sr.transform.localScale = Vector3.one * s; sr.color = c; }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        "Waterdrops: click for a downpour. One drop dies → a splash AND a ripple are born.");
}
