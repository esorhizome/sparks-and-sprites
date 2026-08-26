// THE CUBE CODEX (2D) — one protagonist, many effects, Unity spelling.
// A sprite cube patrols; every effect is the same two-part anatomy the web
// and Godot codexes use: an IDLE loop (runs forever) + a PRESS reaction
// (fires on click). Keys 1–6 pick the equipped effect; click to trigger it.
//
//   1 Fireburst        — radial particle explosion at the cube
//   2 Following halo   — an additive ring that follows, a beat behind
//   3 Sparkle trail    — glitter shed by DISTANCE moved (Rate over Distance)
//   4 Sky bolt         — a jagged LineRenderer strike where you click
//   5 Power-up aura    — rising particles hugging the hero
//   6 Smoke vanish     — a poof, a second of invisibility, a poof back
//
// The full 104 live on the web page (cube-vfx.html) and in the Godot
// project (demos/godot/scenes/cubefx/). Extending here = one more case in
// each switch. Chapter 06 teaches every ingredient used below.
using UnityEngine;

public class CubeVfx2D : MonoBehaviour
{
    Transform cube, halo;
    SpriteRenderer cubeSr;
    ParticleSystem burstPs, trailPs, auraPs;
    LineRenderer bolt;
    int equipped = 1;
    float t, boltLife, vanish, haloX;

    void Start()
    {
        // the protagonist: a code-painted cube with two earnest eyes
        var tex = new Texture2D(16, 16, TextureFormat.RGBA32, false);
        tex.filterMode = FilterMode.Point;
        for (int y = 0; y < 16; y++)
            for (int x = 0; x < 16; x++)
                tex.SetPixel(x, y, new Color(0.29f, 0.26f, 0.44f));
        for (int e = 0; e < 2; e++) { tex.SetPixel(5 + e * 5, 10, Color.white); tex.SetPixel(5 + e * 5, 11, Color.white); }
        tex.Apply();
        cube = new GameObject("Cube").transform;
        cubeSr = cube.gameObject.AddComponent<SpriteRenderer>();
        cubeSr.sprite = Sprite.Create(tex, new Rect(0, 0, 16, 16), new Vector2(0.5f, 0f), 16);

        burstPs = MakeParticles(cube, burst: true, new Color(1f, 0.6f, 0.25f));
        auraPs = MakeParticles(cube, burst: false, new Color(0.55f, 0.67f, 1f));
        var am = auraPs.main; am.startSpeed = 1.2f;      // the aura rises
        var ash = auraPs.shape; ash.angle = 6f;
        trailPs = MakeParticles(cube, burst: false, new Color(0.95f, 0.88f, 1f));
        var em = trailPs.emission; em.rateOverTime = 0; em.rateOverDistance = 5;   // key 3's whole lesson

        halo = new GameObject("Halo").transform;         // key 2: painted ring, squashed thin
        var hsr = halo.gameObject.AddComponent<SpriteRenderer>();
        var htex = new Texture2D(64, 64, TextureFormat.RGBA32, false);
        for (int y = 0; y < 64; y++)
            for (int x = 0; x < 64; x++)
            {
                float d = Mathf.Abs(new Vector2(x - 32, y - 32).magnitude - 22) / 8f;
                htex.SetPixel(x, y, new Color(1f, 0.92f, 0.67f, Mathf.Pow(Mathf.Clamp01(1 - d), 2)));
            }
        htex.Apply();
        hsr.sprite = Sprite.Create(htex, new Rect(0, 0, 64, 64), new Vector2(0.5f, 0.5f), 48);
        hsr.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
        halo.localScale = new Vector3(1f, 0.3f, 1f);     // the y-squash IS the halo

        bolt = new GameObject("Bolt").AddComponent<LineRenderer>();   // key 4
        bolt.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
        bolt.startWidth = 0.08f; bolt.endWidth = 0.05f;
        bolt.startColor = bolt.endColor = new Color(0.86f, 0.9f, 1f);
        bolt.positionCount = 0;
    }

    ParticleSystem MakeParticles(Transform parent, bool burst, Color col)
    {
        var go = new GameObject(burst ? "Burst" : "Stream");
        go.transform.SetParent(parent, false);
        var ps = go.AddComponent<ParticleSystem>();
        var main = ps.main;
        main.startLifetime = 0.8f;
        main.startSpeed = burst ? new ParticleSystem.MinMaxCurve(1.5f, 4f) : 0.4f;
        main.startSize = 0.08f;
        main.startColor = col;
        main.gravityModifier = burst ? 0.8f : 0f;
        var em = ps.emission; em.rateOverTime = 0;
        ps.GetComponent<ParticleSystemRenderer>().material =
            new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
        return ps;
    }

    void Update()
    {
        t += Time.deltaTime;
        for (int i = 1; i <= 6; i++)
            if (Input.GetKeyDown(KeyCode.Alpha0 + i)) equipped = i;

        // --- the patrol: the same stroll as every codex ---
        float nx = Mathf.Sin(t * 0.55f) * 3f;
        cube.position = new Vector3(nx, -1.5f, 0);
        cube.rotation = Quaternion.Euler(0, 0, -Mathf.Cos(t * 0.55f) * 4f);   // the lean

        // --- per-effect idle loops ---
        var aem = auraPs.emission; aem.rateOverTime = equipped == 5 ? 40 : 0;
        var tem = trailPs.emission; tem.rateOverDistance = equipped == 3 ? 5 : 0;
        haloX = Mathf.Lerp(haloX, cube.position.x, 5f * Time.deltaTime);      // the loyal lag
        halo.gameObject.SetActive(equipped == 2);
        halo.position = new Vector3(haloX, -0.1f + Mathf.Sin(t * 1.2f) * 0.06f, 0);
        boltLife -= Time.deltaTime * 3f;
        if (boltLife <= 0) bolt.positionCount = 0;
        vanish -= Time.deltaTime;
        cubeSr.enabled = vanish <= 0;

        // --- the press reactions ---
        if (Input.GetMouseButtonDown(0))
        {
            var p = Camera.main.ScreenToWorldPoint(Input.mousePosition); p.z = 0;
            switch (equipped)
            {
                case 1: burstPs.Emit(26); break;
                case 2: halo.localScale = new Vector3(1.3f, 0.4f, 1f); break;   // the pulse
                case 3: trailPs.Emit(20); break;
                case 4:                                       // jagged march, sky to click
                    bolt.positionCount = 8;
                    for (int i = 0; i < 8; i++)
                        bolt.SetPosition(i, Vector3.Lerp(new Vector3(p.x, 5, 0), p, i / 7f)
                            + Vector3.right * Random.Range(-0.2f, 0.2f));
                    boltLife = 1;
                    break;
                case 5: burstPs.Emit(16); break;              // the surge
                case 6:                                        // poof, gone, poof, back
                    burstPs.Emit(12); vanish = 0.8f;
                    Invoke(nameof(Reappear), 0.8f);
                    break;
            }
        }
        halo.localScale = Vector3.Lerp(halo.localScale, new Vector3(1f, 0.3f, 1f), 3f * Time.deltaTime);
    }

    void Reappear() => burstPs.Emit(8);

    void OnGUI() => GUI.Label(new Rect(10, 10, 980, 60),
        $"The cube codex (2D): equipped = {equipped}. 1 fireburst · 2 halo · 3 sparkle trail · 4 sky bolt · 5 aura · 6 vanish.\n" +
        "Click to trigger. Every effect = one idle loop + one press reaction — same anatomy as all 104 on the web/Godot codex.");
}
