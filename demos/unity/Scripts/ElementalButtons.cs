// THE ELEMENTAL BUTTON ANATOMY — the bestiary's skeleton, Unity spelling.
// Every one of the 104 elemental buttons (see the web page, or the full
// GDScript port in demos/godot/scenes/elements/) is exactly this shape:
//
//     idle(button, t)      — the static loop: runs every frame, forever
//     press(button)        — the thank-you: fires once per click
//
// This file implements that skeleton plus FOUR ambassador elements —
// Breath (light), Candleflame (fire), Static charge (lightning), and
// Flint (sparks) — using only code-generated sprites and particles.
// To add element #5: append one entry to Elements with two lambdas.
// Chapter 12 of the book.
using System;
using System.Collections.Generic;
using UnityEngine;

public class ElementalButtons : MonoBehaviour
{
    class Btn
    {
        public string name;
        public Vector2 pos;
        public Transform face, glow;
        public ParticleSystem burst;
        public float press;                                 // 1 on click, decays to 0
        public Action<Btn, float> idle;                     // the static loop
        public Action<Btn> onPress;                         // the thank-you
    }

    readonly List<Btn> buttons = new();
    float t;

    void Start()
    {
        var soft = SoftDot();
        // ---- the registry: name, position, idle loop, press reaction ----
        Add("BREATHE", new Vector2(-3.5f, 1.2f), soft, new Color(0.59f, 0.63f, 1f),
            idle: (b, tt) =>
            {   // glow expands, then dims, forever; press blooms it
                float breath = 0.5f + 0.5f * Mathf.Sin(tt * 1.1f);
                b.glow.localScale = Vector3.one * (2.2f + breath * 0.8f + b.press * 1.6f);
            },
            press: b => { });
        Add("IGNITE", new Vector2(3.5f, 1.2f), soft, new Color(1f, 0.55f, 0.18f),
            idle: (b, tt) =>
            {   // flames lick upward: the glow flickers on two sine speeds
                float flick = Mathf.Sin(tt * 9) * 0.5f + Mathf.Sin(tt * 23) * 0.5f;
                b.glow.localScale = Vector3.one * (1.8f + flick * 0.3f) * (1 + b.press * 1.2f);
                b.glow.localPosition = new Vector3(0, 0.3f + b.press * 0.3f, 1);
            },
            press: b => { });
        Add("CHARGE", new Vector2(-3.5f, -1.2f), soft, new Color(0.55f, 0.67f, 1f),
            idle: (b, tt) =>
            {   // idle micro-crackle: brief random glow blips at the edges
                bool blip = Mathf.PerlinNoise(tt * 6f, b.pos.x) > 0.72f;
                b.glow.localScale = Vector3.one * (blip ? 2.6f : 1.1f) * (1 + b.press);
            },
            press: b => b.burst.Emit(20));                  // the bolt, as sparks
        Add("STRIKE", new Vector2(3.5f, -1.2f), soft, new Color(1f, 0.82f, 0.47f),
            idle: (b, tt) =>
            {   // flint is the pure thank-you species: (almost) dead until struck
                b.glow.localScale = Vector3.one * (0.4f + b.press * 2.5f);
            },
            press: b => b.burst.Emit(24));

        // extension pattern: Add("NAME", where, soft, colour, idleLambda, pressLambda);
    }

    void Add(string name, Vector2 pos, Sprite soft, Color col, Action<Btn, float> idle, Action<Btn> press)
    {
        var b = new Btn { name = name, pos = pos, idle = idle, onPress = press };
        b.glow = Sprite2D(soft, col, pos, true);            // the light, behind
        b.glow.localPosition = new Vector3(pos.x, pos.y, 1);
        var faceTex = new Texture2D(4, 4);
        var px = new Color[16];
        for (int i = 0; i < 16; i++) px[i] = new Color(0.07f, 0.055f, 0.125f, 0.88f);
        faceTex.SetPixels(px); faceTex.Apply();
        b.face = Sprite2D(Sprite.Create(faceTex, new Rect(0, 0, 4, 4), new Vector2(0.5f, 0.5f), 1.6f),
            Color.white, pos, false);
        b.face.localScale = new Vector3(1.1f, 0.35f, 1);

        b.burst = b.face.gameObject.AddComponent<ParticleSystem>();   // shared press particles
        var main = b.burst.main;
        main.startLifetime = 0.7f;
        main.startSpeed = new ParticleSystem.MinMaxCurve(1.5f, 4f);
        main.startSize = 0.07f;
        main.gravityModifier = 1f;
        main.startColor = col;
        var em = b.burst.emission; em.rateOverTime = 0;
        b.burst.GetComponent<ParticleSystemRenderer>().material =
            new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
        buttons.Add(b);
    }

    void Update()
    {
        t += Time.deltaTime;
        foreach (var b in buttons)
        {
            b.press = Mathf.Max(0, b.press - Time.deltaTime * 2);
            b.idle(b, t);                                   // the static loop, always
        }
        if (Input.GetMouseButtonDown(0))
        {
            var p = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            foreach (var b in buttons)
                if (Mathf.Abs(p.x - b.pos.x) < 1.7f && Mathf.Abs(p.y - b.pos.y) < 0.7f)
                { b.press = 1; b.onPress(b); }              // the thank-you, once
        }
    }

    Sprite SoftDot()
    {
        var tex = new Texture2D(64, 64, TextureFormat.RGBA32, false);
        for (int y = 0; y < 64; y++)
            for (int x = 0; x < 64; x++)
            {
                float d = new Vector2(x - 32, y - 32).magnitude / 32f;
                float a = Mathf.Pow(Mathf.Clamp01(1 - d), 2);
                tex.SetPixel(x, y, new Color(1, 1, 1, a));
            }
        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, 64, 64), new Vector2(0.5f, 0.5f), 32);
    }

    Transform Sprite2D(Sprite s, Color c, Vector2 pos, bool additive)
    {
        var go = new GameObject("s");
        var sr = go.AddComponent<SpriteRenderer>();
        sr.sprite = s; sr.color = c;
        if (additive) sr.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
        go.transform.position = pos;
        return go.transform;
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 980, 60),
        "The elemental anatomy: idle(b, t) runs forever, press(b) fires on click. Four ambassadors here;\n" +
        "all 104 live on the web page and in demos/godot/scenes/elements/. Add one: append to the registry.");
}
