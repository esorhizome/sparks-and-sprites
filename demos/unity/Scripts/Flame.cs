// FLAME — one particle skeleton, four costumes (keys 1–4).
// Fire = rise + shrink + fade + wobble + additive blend, one property each.
// The same skeleton retuned becomes smoke, a fountain, or an ember ring —
// each preset's comment names exactly which dials it turns.
// Chapter 06 of the book.
using UnityEngine;

public class Flame : MonoBehaviour
{
    static readonly string[] Presets = { "flame", "smoke", "fountain", "ember ring" };
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
        rig = new GameObject("Particles");
        rig.transform.position = new Vector3(0, -1.5f, 0);
        var ps = rig.AddComponent<ParticleSystem>();

        // ---- the shared skeleton (fire's five decisions) ----
        var main = ps.main;
        main.startLifetime = 0.9f;                          // short lives = tight flame
        main.startSpeed = new ParticleSystem.MinMaxCurve(1.4f, 2.4f);   // RISE
        main.startSize = new ParticleSystem.MinMaxCurve(0.25f, 0.5f);
        main.gravityModifier = 0f;                          // fire doesn't fall
        var emission = ps.emission; emission.rateOverTime = 90;
        var shape = ps.shape;
        shape.shapeType = ParticleSystemShapeType.Cone;
        shape.angle = 8; shape.rotation = new Vector3(-90, 0, 0);
        var size = ps.sizeOverLifetime;                     // SHRINK as particles age
        size.enabled = true;
        size.size = new ParticleSystem.MinMaxCurve(1, AnimationCurve.Linear(0, 1, 1, 0));
        var col = ps.colorOverLifetime;                     // FADE: yellow → orange → gone
        col.enabled = true;
        col.color = Ramp(new Color(1f, 0.95f, 0.6f), new Color(0.9f, 0.3f, 0.05f));
        var noise = ps.noise;                               // WOBBLE
        noise.enabled = true; noise.strength = 0.35f;
        var rend = ps.GetComponent<ParticleSystemRenderer>();
        rend.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));  // ADD

        // ---- the retunes: what each preset changes, and nothing else ----
        switch (Presets[preset])
        {
            case "smoke":     // slower, longer, greyer, GROWS, and no additive
                main.startLifetime = 2.4f;
                main.startSpeed = new ParticleSystem.MinMaxCurve(0.5f, 1f);
                size.size = new ParticleSystem.MinMaxCurve(1, AnimationCurve.Linear(0, 0.4f, 1, 1));
                col.color = Ramp(new Color(0.7f, 0.7f, 0.75f, 0.25f), new Color(0.5f, 0.5f, 0.55f));
                rend.material = new Material(Shader.Find("Legacy Shaders/Particles/Alpha Blended"));
                break;
            case "fountain":  // gravity back on + a harder launch
                main.gravityModifier = 1.6f;
                main.startSpeed = new ParticleSystem.MinMaxCurve(6f, 8f);
                main.startLifetime = 1.4f;
                col.color = Ramp(new Color(0.75f, 0.9f, 1f), new Color(0.4f, 0.6f, 0.9f));
                break;
            case "ember ring": // same fire, born on a CIRCLE — the emission shape
                shape.shapeType = ParticleSystemShapeType.Circle;
                shape.radius = 2.2f;
                shape.radiusThickness = 0f;                 // surface only
                main.startSpeed = new ParticleSystem.MinMaxCurve(0.2f, 0.7f);
                main.startLifetime = 1.6f;
                main.startSize = new ParticleSystem.MinMaxCurve(0.08f, 0.16f);
                rig.transform.position = Vector3.zero;
                break;
        }
    }

    static ParticleSystem.MinMaxGradient Ramp(Color a, Color b)
    {
        var g = new Gradient();
        g.SetKeys(new[] { new GradientColorKey(a, 0), new GradientColorKey(b, 1) },
                  new[] { new GradientAlphaKey(a.a, 0), new GradientAlphaKey(0, 1) });
        return g;
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        $"Particles: 1=flame 2=smoke 3=fountain 4=ember ring (now: {Presets[preset]}) — one skeleton, four costumes.");
}
