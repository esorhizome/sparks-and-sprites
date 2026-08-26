// SCREEN SHAKE — the kind version: trauma², smooth noise, fast calm.
// Rule 1: accumulate "trauma", shake by trauma SQUARED (small hits whisper,
// big hits roar). Rule 2: sample SMOOTH noise, never random jumps.
// Rule 3: decay fast — the calm is what makes the shake readable.
// Click = small hit, right-click = big hit. Attach to the Camera.
// Chapter 06 of the book.
using UnityEngine;

public class CameraShake : MonoBehaviour
{
    const float MaxOffset = 0.4f, MaxRoll = 3f;
    float trauma, t;
    Vector3 basePos;

    void Start()
    {
        basePos = transform.position;
        // something worth shaking: a field of code-made blocks
        var rng = new System.Random(9);
        for (int i = 0; i < 40; i++)
        {
            var q = GameObject.CreatePrimitive(PrimitiveType.Quad).transform;
            q.position = new Vector3((float)rng.NextDouble() * 14 - 7, (float)rng.NextDouble() * 8 - 4, 5);
            q.localScale = Vector3.one * (0.3f + (float)rng.NextDouble() * 0.8f);
            var m = q.GetComponent<Renderer>().material;
            m.shader = Shader.Find("Unlit/Color");
            m.color = Color.Lerp(new Color(0.35f, 0.32f, 0.5f), new Color(0.61f, 0.64f, 0.94f),
                (float)rng.NextDouble());
        }
    }

    void Update()
    {
        if (Input.GetMouseButtonDown(0)) trauma = Mathf.Min(1, trauma + 0.3f);
        if (Input.GetMouseButtonDown(1)) trauma = Mathf.Min(1, trauma + 0.7f);
    }

    void LateUpdate()                                       // after everything else moved
    {
        t += Time.deltaTime;
        trauma = Mathf.Max(0, trauma - Time.deltaTime * 1.1f);     // rule 3
        float shake = trauma * trauma;                              // rule 1
        float nx = Mathf.PerlinNoise(t * 5f, 0.0f) * 2 - 1;         // rule 2
        float ny = Mathf.PerlinNoise(0.0f, t * 5f) * 2 - 1;
        float nr = Mathf.PerlinNoise(t * 4f, 99f) * 2 - 1;
        transform.position = basePos + new Vector3(nx, ny, 0) * MaxOffset * shake;
        transform.rotation = Quaternion.Euler(0, 0, nr * MaxRoll * shake);
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        "Screen shake (attach to Camera): click = small hit, right-click = big. trauma² + Perlin + fast decay.");
}
