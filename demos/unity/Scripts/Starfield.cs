// STARFIELD & AMBIENCE — sparks at one-tenth speed.
// An ambient field = a particle system with the urgency removed: few per
// second, long lives, tiny sizes, slow drift. Keys 1–4 switch costumes.
// Chapter 06 of the book (ambient atmosphere).
using UnityEngine;

public class Starfield : MonoBehaviour
{
    static readonly string[] Presets = { "stars", "snow", "motes", "fireflies" };
    int preset;
    GameObject rig;

    void Start() => Rebuild();

    void Update()
    {
        for (int i = 0; i < Presets.Length; i++)
            if (Input.GetKeyDown(KeyCode.Alpha1 + i)) { preset = i; Rebuild(); }
    }

    void Rebuild()
    {
        if (rig) Destroy(rig);
        rig = new GameObject("Ambience");
        var ps = rig.AddComponent<ParticleSystem>();
        var main = ps.main;
        main.startLifetime = 12f;                           // long lives
        main.startSpeed = 0f;                               // drift comes from modules
        main.startSize = new ParticleSystem.MinMaxCurve(0.03f, 0.08f);   // tiny
        main.maxParticles = 200;
        main.prewarm = true; main.loop = true;
        var em = ps.emission; em.rateOverTime = 8;          // few per second
        var shape = ps.shape;                               // born anywhere on screen
        shape.shapeType = ParticleSystemShapeType.Box;
        shape.scale = new Vector3(16, 10, 0);
        var vel = ps.velocityOverLifetime;
        vel.enabled = true;
        var rend = ps.GetComponent<ParticleSystemRenderer>();
        rend.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));

        switch (Presets[preset])
        {
            case "stars":                                   // twinkle in place
                main.startColor = new Color(0.86f, 0.86f, 1f);
                var colS = ps.colorOverLifetime; colS.enabled = true;
                colS.color = Twinkle();
                break;
            case "snow":
                main.startColor = new Color(0.92f, 0.96f, 1f);
                vel.y = new ParticleSystem.MinMaxCurve(-0.5f, -0.9f);
                vel.x = new ParticleSystem.MinMaxCurve(-0.1f, 0.2f);
                break;
            case "motes":
                main.startColor = new Color(0.85f, 0.8f, 0.65f, 0.6f);
                vel.x = new ParticleSystem.MinMaxCurve(0.05f, 0.25f);
                break;
            case "fireflies":                               // wander + blink
                main.startColor = new Color(0.86f, 1f, 0.55f);
                em.rateOverTime = 3;
                var noise = ps.noise; noise.enabled = true;
                noise.strength = 0.6f; noise.frequency = 0.3f;
                var colF = ps.colorOverLifetime; colF.enabled = true;
                colF.color = Twinkle();
                break;
        }
    }

    static ParticleSystem.MinMaxGradient Twinkle()
    {
        var g = new Gradient();                             // bright-dim-bright = a blink
        g.SetKeys(new[] { new GradientColorKey(Color.white, 0), new GradientColorKey(Color.white, 1) },
            new[] { new GradientAlphaKey(0.1f, 0), new GradientAlphaKey(0.9f, 0.3f),
                    new GradientAlphaKey(0.2f, 0.6f), new GradientAlphaKey(0.8f, 0.8f),
                    new GradientAlphaKey(0, 1) });
        return g;
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        $"Ambience: 1=stars 2=snow 3=motes 4=fireflies (now: {Presets[preset]}) — sparks with the urgency removed.");
}
