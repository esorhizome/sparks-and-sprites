// THE GLYPH GRIMOIRE (3D) — text effects with real depth, Unity spelling.
// Same per-letter anatomy as TextFx2D, but the letters live in 3D space:
// they orbit in, stack into extrusions, catch a following light, and turn
// to face (or defy) the camera. Keys 1–6 pick the effect; click to trigger.
//
//   1 Orbit assembly   — letters circle in a 3D ring, then spiral into line
//   2 Stack extrude    — each letter drags a queue of dark copies behind it
//                        in Z; click slams the stack deep
//   3 Following light  — a point light strolls the phrase; letters brighten
//                        as it passes (the lighthouse, in real light)
//   4 Coin spin        — letters spin about their Y axis and land face-on
//   5 Tumble           — weightless 3D tumble; click = gravity + baseline
//   6 Long shadow      — a directional "sun" wheels; shadow copies stretch
//                        away from it on the floor plane
//
// The full 104 live on the web page (text-fx.html) and in Godot
// (demos/godot/scenes/textfx/); this file shows how the same dials feel
// when position/rotation are Vector3 and the glow is a real Light.
using UnityEngine;

public class TextFx3D : MonoBehaviour
{
    const string PHRASE = "just this";
    const int DEPTH = 6;                   // extrusion copies per letter

    TextMesh[] letters;
    TextMesh[,] stack;                     // [letter, depth] — the extrusion queue
    Vector3[] homes;
    Light lamp;
    int equipped = 1;
    float t, press;
    Vector3[] tumblePos; Vector3[] tumbleVel; Vector3[] tumbleSpin; Vector3[] tumbleAng;

    TextMesh MakeLetter(string ch, Color col, int fontSize = 64)
    {
        var go = new GameObject("L" + ch);
        go.transform.SetParent(transform, false);
        var tm = go.AddComponent<TextMesh>();
        tm.text = ch;
        tm.anchor = TextAnchor.MiddleCenter;
        tm.alignment = TextAlignment.Center;
        tm.fontSize = fontSize;
        tm.characterSize = 0.1f;
        tm.color = col;
        return tm;
    }

    void Start()
    {
        letters = new TextMesh[PHRASE.Length];
        stack = new TextMesh[PHRASE.Length, DEPTH];
        homes = new Vector3[PHRASE.Length];
        tumblePos = new Vector3[PHRASE.Length]; tumbleVel = new Vector3[PHRASE.Length];
        tumbleSpin = new Vector3[PHRASE.Length]; tumbleAng = new Vector3[PHRASE.Length];
        for (int i = 0; i < PHRASE.Length; i++)
        {
            homes[i] = new Vector3((i - (PHRASE.Length - 1) * 0.5f) * 0.55f, 0, 0);
            letters[i] = MakeLetter(PHRASE[i].ToString(), new Color(0.91f, 0.9f, 0.96f));
            for (int d = 0; d < DEPTH; d++)
            {   // the extrusion: darker with depth, drawn "behind" via Z
                float k = (d + 1f) / DEPTH;
                stack[i, d] = MakeLetter(PHRASE[i].ToString(), new Color(0.16f + 0.1f * (1 - k), 0.14f, 0.27f));
            }
            tumblePos[i] = Random.insideUnitSphere * 1.5f;
            tumbleVel[i] = Random.insideUnitSphere * 0.4f;
            tumbleSpin[i] = Random.insideUnitSphere * 90f;
        }
        var lgo = new GameObject("Lamp");
        lamp = lgo.AddComponent<Light>();
        lamp.type = LightType.Point;
        lamp.range = 3f; lamp.intensity = 2.5f;
        lamp.color = new Color(1f, 0.9f, 0.63f);
        // letters need a lit shader to feel the lamp — TextMesh's default font
        // material is unlit, so this demo brightens colours manually in case 3;
        // the light still sells the effect on any lit geometry around it.
    }

    void Update()
    {
        t += Time.deltaTime;
        press = Mathf.Max(0, press - Time.deltaTime * 0.7f);
        for (int i = 1; i <= 6; i++)
            if (Input.GetKeyDown(KeyCode.Alpha0 + i)) { equipped = i; t = 0; press = 0; }
        if (Input.GetMouseButtonDown(0)) { press = 1f; if (equipped == 1 || equipped == 4) t = 0; }

        bool useStack = equipped == 2 || equipped == 6;
        float lampOn = equipped == 3 ? 1 : 0;
        lamp.enabled = lampOn > 0;

        for (int i = 0; i < letters.Length; i++)
        {
            var lt = letters[i].transform;
            var col = new Color(0.91f, 0.9f, 0.96f);
            lt.localRotation = Quaternion.identity;
            for (int d = 0; d < DEPTH; d++) stack[i, d].gameObject.SetActive(useStack);

            switch (equipped)
            {
                case 1:                            // orbit in, spiral to the line — Vector3 makes the ring free
                {
                    float p = Mathf.Clamp01((t - 1.2f) / 1.8f);
                    float e = p * p * (3 - 2 * p);
                    float a = (float)i / PHRASE.Length * Mathf.PI * 2 + t * 1.4f;
                    float r = 1.6f * (1 - e);
                    lt.localPosition = Vector3.Lerp(Vector3.zero, homes[i], e)
                        + new Vector3(Mathf.Cos(a) * r, Mathf.Sin(a * 0.7f) * r * 0.3f, Mathf.Sin(a) * r);
                    if (t > 8) t = 0;
                    break;
                }
                case 2:                            // extrusion: the queue trails in +Z
                {
                    lt.localPosition = homes[i];
                    float depth = (0.09f + Mathf.Sin(t * Mathf.PI / 2) * 0.03f + press * 0.22f);
                    for (int d = 0; d < DEPTH; d++)
                        stack[i, d].transform.localPosition = homes[i] + new Vector3(0.02f, -0.02f, 0.12f) * (d + 1) * depth * 10f;
                    break;
                }
                case 3:                            // the strolling lamp
                {
                    lt.localPosition = homes[i];
                    float lx = Mathf.Sin(t * 0.8f) * 2.4f;
                    lamp.transform.position = transform.position + new Vector3(lx, 0.4f, -0.6f);
                    float k = Mathf.Max(0, 1 - Mathf.Abs(homes[i].x - lx) / 1.2f);
                    col = Color.Lerp(new Color(0.25f, 0.24f, 0.32f), new Color(1f, 0.97f, 0.86f), k);
                    break;
                }
                case 4:                            // coin spin about Y — real rotation, not an x-scale trick
                {
                    float p = Mathf.Clamp01((t - i * 0.12f) / 0.7f);
                    lt.localPosition = homes[i];
                    lt.localRotation = Quaternion.Euler(0, (1 - Mathf.Pow(1 - p, 2)) * 450f % 360f * (p < 1 ? 1 : 0), 0);
                    if (t > PHRASE.Length * 0.12f + 4) t = 0;
                    break;
                }
                case 5:                            // weightless tumble; press = gravity and a landing
                {
                    if (press > 0)
                    {
                        tumblePos[i] = Vector3.Lerp(tumblePos[i], homes[i], Time.deltaTime * 5f);
                        tumbleAng[i] = Vector3.Lerp(tumbleAng[i], Vector3.zero, Time.deltaTime * 5f);
                    }
                    else
                    {
                        tumblePos[i] += tumbleVel[i] * Time.deltaTime;
                        if (tumblePos[i].magnitude > 1.8f) tumbleVel[i] = -tumbleVel[i];
                        tumbleAng[i] += tumbleSpin[i] * Time.deltaTime;
                    }
                    lt.localPosition = tumblePos[i];
                    lt.localRotation = Quaternion.Euler(tumbleAng[i]);
                    break;
                }
                case 6:                            // the wheeling sun: shadow copies flatten onto y = -0.4
                {
                    lt.localPosition = homes[i];
                    float sunA = (t * 0.15f % 1f) * Mathf.PI;
                    float dirX = Mathf.Cos(sunA);
                    float len = 0.25f + Mathf.Abs(dirX) * 0.8f;
                    for (int d = 0; d < DEPTH; d++)
                    {
                        float k = (d + 1f) / DEPTH;
                        stack[i, d].transform.localPosition = homes[i]
                            + new Vector3(dirX * len * k, -0.45f * k, 0.01f * d);   // stretch along the floor
                        stack[i, d].transform.localScale = new Vector3(1, 0.6f, 1); // squashed, shadow-flat
                    }
                    break;
                }
            }
            letters[i].color = col;
        }
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 980, 60),
        $"The glyph grimoire (3D): equipped = {equipped}. 1 orbit assembly · 2 stack extrude · 3 following light · 4 coin spin · 5 tumble · 6 long shadow.\n" +
        "Click to trigger. Depth is the new dial: Z position, Y rotation, and a real Light join the 2D anatomy.");
}
