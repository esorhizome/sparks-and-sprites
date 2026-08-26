// TRAILS — the trail as short-term memory, drawn.
// Unity ships the whole idea as one component: TrailRenderer remembers
// where its object has been and draws the memory with fading width.
// Move the mouse. Chapter 06 of the book.
using UnityEngine;

public class Trails : MonoBehaviour
{
    Transform dot;

    void Start()
    {
        dot = new GameObject("Comet").transform;
        var tr = dot.gameObject.AddComponent<TrailRenderer>();
        tr.time = 0.6f;                                    // memory span, in seconds
        tr.startWidth = 0.35f;                             // bright head…
        tr.endWidth = 0f;                                  // …fading tail
        tr.material = new Material(Shader.Find("Legacy Shaders/Particles/Additive"));
        tr.startColor = new Color(0.61f, 0.64f, 0.94f);
        tr.endColor = new Color(0.61f, 0.64f, 0.94f, 0f);
        tr.minVertexDistance = 0.05f;
    }

    void Update()
    {
        var p = Camera.main.ScreenToWorldPoint(Input.mousePosition);
        p.z = 0;
        // ease toward the pointer — the slight lag is what makes it a comet
        dot.position = Vector3.Lerp(dot.position, p, 12f * Time.deltaTime);
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 800, 40),
        "Trails: TrailRenderer = the don't-clear trick as a component. Move the mouse.");
}
