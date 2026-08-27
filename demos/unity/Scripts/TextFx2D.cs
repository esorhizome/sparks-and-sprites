// THE GLYPH GRIMOIRE (2D) — one phrase, many text effects, Unity spelling.
// One TextMesh PER LETTER (that is the entire trick — once each letter is its
// own Transform, every grimoire family is just math on position/scale/color).
// Keys 1–8 pick the equipped effect; click to trigger its press reaction.
//
//   1 Typewriter       — letter by letter, with a block caret
//   2 Sine wave        — letters ride a rolling sine, leaning into the slope
//   3 Decoder          — wrong glyphs churn, resolving left to right
//   4 Heartbeat        — the phrase swells on a lub-dub (click races it)
//   5 Rainbow ride     — hue slides along the letters forever
//   6 Cold shiver      — a fine tremble, with travelling shivers
//   7 Pop-in           — letters pop in one by one with overshoot
//   8 Firefly pulse    — dim to visible and back (click holds it bright)
//
// The full 104 (plus 104 rhymes) live on the web page (text-fx.html) and in
// the Godot project (demos/godot/scenes/textfx/). Extending here = one more
// case in each switch. Chapter 13 teaches every ingredient used below.
//
// TextMesh is the built-in 3D text component — no packages, works in any
// project. For production UI you would use TMP_Text and animate its mesh
// vertices per glyph (TMP_Text.textInfo), but the anatomy is identical:
// per-letter position, scale, colour, and "does it exist yet".
using UnityEngine;

public class TextFx2D : MonoBehaviour
{
    const string PHRASE = "just this";
    const string GLYPHS = "abcdefghjkmnpqrstuvwxyz023456789#%&@+=?";

    TextMesh[] letters;
    Transform[] slots;                     // resting positions, never mutated
    TextMesh caret;
    int equipped = 1;
    float t, press;                        // press: 1 at click, decays — most reactions read this
    int shown;                             // typewriter / decoder progress
    float typeTimer, churnTimer;

    void Start()
    {
        letters = new TextMesh[PHRASE.Length];
        slots = new Transform[PHRASE.Length];
        for (int i = 0; i < PHRASE.Length; i++)
        {
            var slot = new GameObject("Slot" + i).transform;   // the home position
            slot.SetParent(transform, false);
            slot.localPosition = new Vector3((i - (PHRASE.Length - 1) * 0.5f) * 0.55f, 0, 0);
            slots[i] = slot;
            var go = new GameObject("Letter" + i);
            go.transform.SetParent(slot, false);
            var tm = go.AddComponent<TextMesh>();
            tm.text = PHRASE[i].ToString();
            tm.anchor = TextAnchor.MiddleCenter;
            tm.alignment = TextAlignment.Center;
            tm.fontSize = 64;
            tm.characterSize = 0.1f;
            tm.color = new Color(0.91f, 0.9f, 0.96f);
            letters[i] = tm;
        }
        var cgo = new GameObject("Caret");
        cgo.transform.SetParent(transform, false);
        caret = cgo.AddComponent<TextMesh>();
        caret.text = "▌";
        caret.anchor = TextAnchor.MiddleCenter;
        caret.fontSize = 64;
        caret.characterSize = 0.1f;
        caret.color = new Color(0.91f, 0.9f, 0.96f);
    }

    char Scramble() => GLYPHS[Random.Range(0, GLYPHS.Length)];

    void Update()
    {
        t += Time.deltaTime;
        press = Mathf.Max(0, press - Time.deltaTime);
        for (int i = 1; i <= 8; i++)
            if (Input.GetKeyDown(KeyCode.Alpha0 + i)) { equipped = i; shown = 0; t = 0; }
        if (Input.GetMouseButtonDown(0)) { press = 1f; if (equipped == 1 || equipped == 3 || equipped == 7) { shown = 0; t = 0; } }

        // --- the reveal clocks (typewriter & decoder share one) ---
        typeTimer += Time.deltaTime;
        if (typeTimer > (equipped == 3 ? 0.22f : 0.12f) && shown < PHRASE.Length) { typeTimer = 0; shown++; }
        churnTimer += Time.deltaTime;

        caret.gameObject.SetActive(equipped == 1 && Mathf.Sin(t * 7) > -0.2f);
        if (equipped == 1)
            caret.transform.position = slots[Mathf.Min(shown, PHRASE.Length - 1)].position
                + Vector3.right * (shown >= PHRASE.Length ? 0.5f : 0f);

        for (int i = 0; i < letters.Length; i++)
        {
            var tm = letters[i];
            var lt = tm.transform;
            // reset to the slot every frame; each effect then writes its offsets —
            // the same "layout() first, then decide per letter" anatomy as the web kit
            lt.localPosition = Vector3.zero;
            lt.localRotation = Quaternion.identity;
            lt.localScale = Vector3.one;
            var col = new Color(0.91f, 0.9f, 0.96f);
            tm.text = PHRASE[i].ToString();

            switch (equipped)
            {
                case 1:                            // typewriter: exists-yet is the only dial
                    tm.gameObject.SetActive(i < shown);
                    break;
                case 2:                            // sine wave: position + lean from one phase
                    tm.gameObject.SetActive(true);
                    lt.localPosition = Vector3.up * Mathf.Sin(t * 2.4f - i * 0.65f) * 0.16f * (1 + press * 1.6f);
                    lt.localRotation = Quaternion.Euler(0, 0, Mathf.Cos(t * 2.4f - i * 0.65f) * -8f);
                    break;
                case 3:                            // decoder: wrong glyph until your turn comes
                    tm.gameObject.SetActive(PHRASE[i] != ' ');
                    if (i >= shown)
                    {
                        if (churnTimer > 0.05f) tm.text = Scramble().ToString();
                        col = new Color(0.59f, 0.86f, 0.71f, 0.75f);
                    }
                    break;
                case 4:                            // heartbeat: scale about the phrase centre
                    tm.gameObject.SetActive(true);
                    float beat = (t * (press > 0 ? 150f : 62f) / 60f) % 1f;
                    float k = Mathf.Exp(-beat * 14f) + (beat > 0.28f ? 0.72f * Mathf.Exp(-(beat - 0.28f) * 14f) : 0f);
                    float s = 1 + k * 0.16f;
                    lt.localScale = Vector3.one * s;
                    lt.position = Vector3.LerpUnclamped(transform.position, slots[i].position, s);
                    break;
                case 5:                            // rainbow: hue is just (time + index) wrapped
                    tm.gameObject.SetActive(true);
                    col = Color.HSVToRGB(((t * 60f * (1 + press * 2) + i * 36f) % 360f) / 360f, 0.7f, 1f);
                    break;
                case 6:                            // shiver: smooth small noise + travelling wave
                    tm.gameObject.SetActive(true);
                    float wave = Mathf.Max(0, Mathf.Sin(press * Mathf.PI)) * 3f;
                    lt.localPosition = new Vector3(
                        (Mathf.PerlinNoise(t * 6f, i * 3.1f) - 0.5f) * 0.06f * (1 + wave),
                        (Mathf.PerlinNoise(i * 3.1f, t * 6f) - 0.5f) * 0.06f * (1 + wave), 0);
                    break;
                case 7:                            // pop-in: each letter's own little life
                    float a = (t - i * 0.11f) / 0.4f;
                    tm.gameObject.SetActive(a > 0);
                    if (a > 0)
                    {
                        float ps = a >= 1 ? 1 : 1.75f * a * Mathf.Exp(1 - 1.75f * a) * 1.55f;  // overshoot then settle
                        lt.localScale = Vector3.one * Mathf.Max(0.01f, ps);
                    }
                    if (t > PHRASE.Length * 0.11f + 3.4f) t = 0;
                    break;
                case 8:                            // firefly: opacity IS the animation
                    tm.gameObject.SetActive(true);
                    float al = press > 0 ? 1f : 0.08f + 0.92f * Mathf.Pow(0.5f + 0.5f * Mathf.Sin(t * Mathf.PI * 2 / 3.6f), 2);
                    col.a = al;
                    break;
            }
            tm.color = col;
        }
        if (churnTimer > 0.05f) churnTimer = 0;
        if ((equipped == 1 || equipped == 3) && shown >= PHRASE.Length && t > 6f) { shown = 0; t = 0; }   // retype forever
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 980, 60),
        $"The glyph grimoire (2D): equipped = {equipped}. 1 typewriter · 2 wave · 3 decoder · 4 heartbeat · 5 rainbow · 6 shiver · 7 pop-in · 8 firefly.\n" +
        "Click to trigger/replay. Every effect = per-letter position, scale, colour, and 'does it exist yet' — same anatomy as all 104 on the web/Godot grimoire.");
}
