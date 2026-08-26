// THE CUBE CODEX (3D) — the same protagonist anatomy, in real 3D.
// A cube patrols a floor plane (3D project: add a Directional Light and,
// for the glows, URP Bloom). Keys 1–5 equip an effect; click to trigger.
//
//   1 Fireburst      — a 3D particle explosion at the cube
//   2 Halo light     — a point light + flattened emissive ring that follows
//   3 Waterhose      — an arcing particle jet with real gravity
//   4 Sky bolt       — a jagged LineRenderer strike at the clicked floor point
//   5 Power-up aura  — rising particles + the cube's emissive climbing
//
// Same two-part anatomy as the web and Godot codexes (all 104 live there);
// extending = one more case per switch. Chapter 06 names every ingredient.
using UnityEngine;

public class CubeVfx3D : MonoBehaviour
{
    Transform cube, halo;
    Light haloLight;
    Material cubeMat;
    ParticleSystem burst, hose, aura;
    LineRenderer bolt;
    int equipped = 1;
    float t, boltLife, haloX, surge;

    void Start()
    {
        var floor = GameObject.CreatePrimitive(PrimitiveType.Plane);
        floor.GetComponent<Renderer>().material.color = new Color(0.11f, 0.09f, 0.19f);

        cube = GameObject.CreatePrimitive(PrimitiveType.Cube).transform;   // the hero
        cube.position = new Vector3(0, 0.5f, 0);
        cubeMat = cube.GetComponent<Renderer>().material;
        cubeMat.color = new Color(0.29f, 0.26f, 0.44f);
        cubeMat.EnableKeyword("_EMISSION");

        haloLight = new GameObject("HaloLight").AddComponent<Light>();     // key 2
        haloLight.type = LightType.Point;
        haloLight.color = new Color(1f, 0.92f, 0.67f);
        haloLight.range = 4f;
        halo = GameObject.CreatePrimitive(PrimitiveType.Cylinder).transform;
        halo.localScale = new Vector3(0.9f, 0.02f, 0.9f);                  // the thin ring stand-in
        var hm = halo.GetComponent<Renderer>().material;
        hm.EnableKeyword("_EMISSION");
        hm.SetColor("_EmissionColor", new Color(1f, 0.92f, 0.67f) * 2f);   // HDR → bloom

        burst = Particles(new Color(1f, 0.6f, 0.25f), speed: 4f, gravity: 0.8f);
        hose = Particles(new Color(0.47f, 0.75f, 0.94f), speed: 7f, gravity: 1.4f);
        var hs = hose.shape; hs.angle = 4f;
        aura = Particles(new Color(0.55f, 0.67f, 1f), speed: 1.5f, gravity: -0.1f);
        var aem = aura.emission; aem.rateOverTime = 0;

        bolt = new GameObject("Bolt").AddComponent<LineRenderer>();        // key 4
        bolt.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
        bolt.startWidth = 0.12f; bolt.endWidth = 0.06f;
        bolt.startColor = bolt.endColor = new Color(0.86f, 0.9f, 1f);
        bolt.positionCount = 0;
    }

    ParticleSystem Particles(Color col, float speed, float gravity)
    {
        var go = new GameObject("PS");
        go.transform.SetParent(cube, false);
        var ps = go.AddComponent<ParticleSystem>();
        var main = ps.main;
        main.startLifetime = 0.9f;
        main.startSpeed = speed;
        main.startSize = 0.12f;
        main.startColor = col;
        main.gravityModifier = gravity;
        var em = ps.emission; em.rateOverTime = 0;
        ps.GetComponent<ParticleSystemRenderer>().material =
            new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
        return ps;
    }

    void Update()
    {
        t += Time.deltaTime;
        for (int i = 1; i <= 5; i++)
            if (Input.GetKeyDown(KeyCode.Alpha0 + i)) equipped = i;

        // --- the patrol, now in metres ---
        cube.position = new Vector3(Mathf.Sin(t * 0.55f) * 3f, 0.5f, 0);
        cube.rotation = Quaternion.Euler(0, 0, -Mathf.Cos(t * 0.55f) * 5f);

        // --- idle loops ---
        haloX = Mathf.Lerp(haloX, cube.position.x, 5f * Time.deltaTime);
        bool haloOn = equipped == 2;
        halo.gameObject.SetActive(haloOn);
        haloLight.enabled = haloOn;
        halo.position = new Vector3(haloX, 1.6f + Mathf.Sin(t * 1.2f) * 0.06f, 0);
        haloLight.transform.position = halo.position + Vector3.up * 0.2f;
        haloLight.intensity = 1.2f + Mathf.Sin(t * Mathf.PI * 2f / 3f) * 0.15f;   // the ±breath
        var am = aura.emission; am.rateOverTime = equipped == 5 ? 35 : 0;
        surge = Mathf.Max(0, surge - Time.deltaTime);
        cubeMat.SetColor("_EmissionColor",
            new Color(0.35f, 0.4f, 1f) * (equipped == 5 ? 0.4f + surge * 2f : 0f));
        boltLife -= Time.deltaTime * 3f;
        if (boltLife <= 0) bolt.positionCount = 0;

        // --- press reactions ---
        if (Input.GetMouseButtonDown(0))
        {
            switch (equipped)
            {
                case 1: burst.Emit(30); break;
                case 2: haloLight.intensity = 3f; break;                    // the pulse
                case 3:                                                     // aim the hose forward
                    hose.transform.rotation = Quaternion.Euler(-35f, cube.position.x < 0 ? 90f : -90f, 0);
                    hose.Emit(40);
                    break;
                case 4:
                    // strike wherever the click ray meets the floor
                    var ray = Camera.main.ScreenPointToRay(Input.mousePosition);
                    if (Physics.Raycast(ray, out var hit))
                    {
                        bolt.positionCount = 8;
                        for (int i = 0; i < 8; i++)
                            bolt.SetPosition(i, Vector3.Lerp(hit.point + Vector3.up * 8f, hit.point, i / 7f)
                                + new Vector3(Random.Range(-0.3f, 0.3f), 0, Random.Range(-0.3f, 0.3f)));
                        boltLife = 1;
                    }
                    break;
                case 5: surge = 1; aura.Emit(20); break;
            }
        }
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 980, 60),
        $"The cube codex (3D): equipped = {equipped}. 1 fireburst · 2 halo light · 3 waterhose · 4 sky bolt · 5 aura.\n" +
        "Click to trigger. Add URP Bloom so the emissive halo and aura actually glow.");
}
