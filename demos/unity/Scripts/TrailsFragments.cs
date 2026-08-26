// FRAGMENTED TRAILS — a comet of pieces, spawned BY DISTANCE MOVED.
// The one setting that carries the demo: emission Rate over DISTANCE.
// Fragments appear only while the pointer travels — that's the
// responsive feel. Keys 1–4 change the costume colour.
// Chapter 06 (and chapter 12, as a cursor trail).
using UnityEngine;

public class TrailsFragments : MonoBehaviour
{
    static readonly Color[] Costumes = {
        new Color(1f, 0.6f, 0.25f),      // ember
        new Color(1f, 0.9f, 0.5f),       // star
        new Color(0.55f, 0.8f, 1f),      // drop
        new Color(0.95f, 0.9f, 1f) };    // sparkle
    ParticleSystem ps;
    Transform emitter;

    void Start()
    {
        emitter = new GameObject("Emitter").transform;
        ps = emitter.gameObject.AddComponent<ParticleSystem>();
        var main = ps.main;
        main.startLifetime = 0.9f;
        main.startSpeed = new ParticleSystem.MinMaxCurve(0.1f, 0.5f);
        main.startSize = new ParticleSystem.MinMaxCurve(0.05f, 0.12f);
        main.gravityModifier = 0.15f;
        main.startColor = Costumes[0];
        var emission = ps.emission;
        emission.rateOverTime = 0;                          // NOT by time…
        emission.rateOverDistance = 6;                      // …by distance. The demo.
        var col = ps.colorOverLifetime;
        col.enabled = true;
        var g = new Gradient();
        g.SetKeys(new[] { new GradientColorKey(Color.white, 0), new GradientColorKey(Color.white, 1) },
                  new[] { new GradientAlphaKey(1, 0), new GradientAlphaKey(0, 1) });
        col.color = g;
        ps.GetComponent<ParticleSystemRenderer>().material =
            new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
    }

    void Update()
    {
        for (int i = 0; i < 4; i++)
            if (Input.GetKeyDown(KeyCode.Alpha1 + i))
            { var main = ps.main; main.startColor = Costumes[i]; }
        var p = Camera.main.ScreenToWorldPoint(Input.mousePosition);
        p.z = 0;
        emitter.position = p;              // the emitter IS the pointer
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        "Fragmented trails: Rate over Distance emission. Move the mouse; 1–4 change the costume.");
}
