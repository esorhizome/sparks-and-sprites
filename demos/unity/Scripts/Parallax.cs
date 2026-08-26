// PARALLAX — depth from three multiplications. You are the camera.
// Each layer moves by (pointer offset × its own factor): far layers barely
// move, near layers move a lot. The GAP between factors is the depth.
// Chapter 04 of the book.
using UnityEngine;

public class Parallax : MonoBehaviour
{
    Transform[] layers = new Transform[3];
    static readonly float[] Factor = { 0.1f, 0.35f, 0.9f };   // far → near

    void Start()
    {
        for (int L = 0; L < 3; L++)
        {
            var parent = new GameObject("Layer" + L).transform;
            layers[L] = parent;
            // each layer: a row of code-made blocks, nearer = bigger + brighter
            for (int i = 0; i < 8; i++)
            {
                var block = GameObject.CreatePrimitive(PrimitiveType.Quad).transform;
                block.SetParent(parent);
                float s = 0.4f + L * 0.5f;
                block.localScale = new Vector3(s, s * 1.6f, 1);
                block.position = new Vector3(-7 + i * 2f + L * 0.4f, -1 + L * 0.5f, 5 - L);
                var m = block.GetComponent<Renderer>().material;
                m.shader = Shader.Find("Unlit/Color");
                float v = 0.25f + L * 0.22f;
                m.color = new Color(v * 0.9f, v * 0.85f, v * 1.2f);
            }
        }
    }

    void Update()
    {
        // pointer position −0.5..0.5 across the screen = the "camera"
        float mx = Input.mousePosition.x / Screen.width - 0.5f;
        for (int L = 0; L < 3; L++)
        {
            var p = layers[L].position;
            p.x = -mx * 6f * Factor[L];        // ← the entire trick, per layer
            layers[L].position = p;
        }
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 800, 40),
        "Parallax: move the mouse. Three layers × three factors (0.1 / 0.35 / 0.9) = depth.");
}
