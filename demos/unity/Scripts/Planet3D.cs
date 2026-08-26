// PLANET — real 3D, still all from code (use a 3D project + a Directional Light).
// Take a sphere's vertices, push each outward by noise (mountains rise, seas
// stay round), colour by height, recalc normals, set it spinning. The same
// recipe as the three.js and Godot versions, different accent.
// Chapter 11 of the book.
using UnityEngine;

public class Planet3D : MonoBehaviour
{
    Transform planet;

    void Start()
    {
        var go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        planet = go.transform;
        planet.localScale = Vector3.one * 2.5f;
        var mesh = Instantiate(go.GetComponent<MeshFilter>().mesh);   // writable copy
        var verts = mesh.vertices;
        var colors = new Color[verts.Length];
        for (int i = 0; i < verts.Length; i++)
        {
            Vector3 n = verts[i].normalized;
            // 3-D noise from stacked 2-D Perlin — enough for a small world
            float h = Mathf.PerlinNoise(n.x * 1.8f + 7f, n.y * 1.8f + 3f)
                    + Mathf.PerlinNoise(n.y * 1.8f + 1f, n.z * 1.8f + 5f) - 1f;
            float height = Mathf.Max(0, h) * 0.18f;       // only mountains rise
            verts[i] = n * (0.5f + height);
            colors[i] = height < 0.005f
                ? new Color(0.16f, 0.35f, 0.55f)          // sea level
                : Color.Lerp(new Color(0.30f, 0.52f, 0.30f), new Color(0.85f, 0.82f, 0.75f), height * 5f);
        }
        mesh.vertices = verts;
        mesh.colors = colors;
        mesh.RecalculateNormals();
        go.GetComponent<MeshFilter>().mesh = mesh;
        // a vertex-colour material: URP's default lit shader reads vertex colour
        // via a simple unlit fallback here, so the height-paint shows everywhere
        var m = go.GetComponent<Renderer>().material;
        m.shader = Shader.Find("Particles/Standard Unlit");

        var stars = new GameObject("Stars").AddComponent<ParticleSystem>();  // the sky
        var main = stars.main;
        main.startSpeed = 0; main.startLifetime = 1000f; main.startSize = 0.04f;
        main.maxParticles = 400; main.prewarm = true;
        var shape = stars.shape;
        shape.shapeType = ParticleSystemShapeType.Sphere;
        shape.radius = 12f; shape.radiusThickness = 0.2f;
        var em = stars.emission; em.rateOverTime = 400;
        stars.GetComponent<ParticleSystemRenderer>().material =
            new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
    }

    void Update() => planet.Rotate(0, 15f * Time.deltaTime, 0);   // worlds turn slowly

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        "Planet: sphere vertices displaced by noise, coloured by height. Same recipe as the three.js demo.");
}
