// SPARKS — a one-shot particle burst, configured ENTIRELY in code.
// Every line maps one-to-one to an inspector field — the panel is just a
// form that fills in these values. Click anywhere to burst.
// Chapter 06 of the book.
using UnityEngine;

public class SparksBurst : MonoBehaviour
{
    void Start() => Burst(Vector3.zero);   // one free burst on load

    void Update()
    {
        if (Input.GetMouseButtonDown(0))
        {
            var p = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            p.z = 0;
            Burst(p);
        }
    }

    void Burst(Vector3 at)
    {
        var go = new GameObject("Burst");
        go.transform.position = at;
        var ps = go.AddComponent<ParticleSystem>();

        var main = ps.main;
        main.loop = false;                                  // a burst, not a stream
        main.startLifetime = 1.2f;                          // seconds each spark lives
        main.startSpeed = new ParticleSystem.MinMaxCurve(1.5f, 6f);
        main.startSize = new ParticleSystem.MinMaxCurve(0.06f, 0.14f);
        main.gravityModifier = 1.4f;                        // the fall that makes them sparks
        main.startColor = new Color(0.61f, 0.64f, 0.94f);

        var emission = ps.emission;
        emission.rateOverTime = 0;
        emission.SetBursts(new[] { new ParticleSystem.Burst(0f, 48) });  // all at once

        var shape = ps.shape;
        shape.shapeType = ParticleSystemShapeType.Cone;     // aim up…
        shape.angle = 40f;                                  // …within a cone
        shape.rotation = new Vector3(-90, 0, 0);

        var col = ps.colorOverLifetime;                     // periwinkle → warm ember → gone
        col.enabled = true;
        var g = new Gradient();
        g.SetKeys(
            new[] { new GradientColorKey(new Color(0.61f, 0.64f, 0.94f), 0),
                    new GradientColorKey(new Color(0.84f, 0.66f, 0.47f), 1) },
            new[] { new GradientAlphaKey(1, 0), new GradientAlphaKey(0, 1) });
        col.color = g;

        Destroy(go, 1.5f);                                  // tidy up after the show
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 700, 40),
        "Sparks: click anywhere to burst. Every property is set from code — read SparksBurst.cs.");
}
