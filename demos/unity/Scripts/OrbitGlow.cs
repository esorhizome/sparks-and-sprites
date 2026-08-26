// ORBIT & GLOW — drag to orbit + an emissive centrepiece (3D project).
// Babylon ships ArcRotateCamera; Unity asks for the same rig written out:
// a yaw pivot → a pitch pivot → the camera on a stick. Six honest lines of
// drag math — so you can see there's no magic in either engine.
// For the bloom: add a URP Volume with Bloom, and the emissive torus lights up.
// Chapter 11 of the book.
using UnityEngine;

public class OrbitGlow : MonoBehaviour
{
    Transform yaw, pitch, knot;
    void Start()
    {
        // the glowing centrepiece: a torus generated from code
        var torus = new GameObject("Torus");
        knot = torus.transform;
        var mf = torus.AddComponent<MeshFilter>();
        mf.mesh = TorusMesh(1.1f, 0.35f, 48, 18);
        var mr = torus.AddComponent<MeshRenderer>();
        mr.material = new Material(Shader.Find("Standard"));
        mr.material.EnableKeyword("_EMISSION");
        mr.material.SetColor("_EmissionColor", new Color(0.61f, 0.64f, 0.94f) * 2.5f);  // HDR → bloom

        yaw = new GameObject("Yaw").transform;              // rotates left-right…
        pitch = new GameObject("Pitch").transform;          // …carries the up-down tilt
        pitch.SetParent(yaw);
        Camera.main.transform.SetParent(pitch);
        Camera.main.transform.localPosition = new Vector3(0, 0, -5);   // the stick
        pitch.localRotation = Quaternion.Euler(20, 0, 0);
    }

    void Update()
    {
        knot.Rotate(8f * Time.deltaTime, 23f * Time.deltaTime, 0);   // alive before you touch it
        if (Input.GetMouseButton(0))
        {
            // the whole orbit camera: two rotations and a clamp
            yaw.Rotate(0, Input.GetAxis("Mouse X") * 4f, 0, Space.World);
            float p = pitch.localEulerAngles.x - Input.GetAxis("Mouse Y") * 3f;
            if (p > 180) p -= 360;
            pitch.localRotation = Quaternion.Euler(Mathf.Clamp(p, -70, 20), 0, 0);
        }
    }

    // a torus, one ring of vertices at a time — no asset, no import
    static Mesh TorusMesh(float R, float r, int seg, int side)
    {
        var verts = new Vector3[(seg + 1) * (side + 1)];
        var tris = new int[seg * side * 6];
        for (int i = 0; i <= seg; i++)
        {
            float u = i / (float)seg * Mathf.PI * 2;
            for (int j = 0; j <= side; j++)
            {
                float v = j / (float)side * Mathf.PI * 2;
                verts[i * (side + 1) + j] = new Vector3(
                    (R + r * Mathf.Cos(v)) * Mathf.Cos(u),
                    r * Mathf.Sin(v),
                    (R + r * Mathf.Cos(v)) * Mathf.Sin(u));
            }
        }
        int k = 0;
        for (int i = 0; i < seg; i++)
            for (int j = 0; j < side; j++)
            {
                int a = i * (side + 1) + j;
                int b = (i + 1) * (side + 1) + j;
                tris[k++] = a; tris[k++] = b; tris[k++] = a + 1;
                tris[k++] = b; tris[k++] = b + 1; tris[k++] = a + 1;
            }
        var mesh = new Mesh { vertices = verts, triangles = tris };
        mesh.RecalculateNormals();
        return mesh;
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 900, 40),
        "Orbit & glow: drag to orbit (yaw → pitch → camera-on-a-stick). Add URP Bloom for the glow.");
}
