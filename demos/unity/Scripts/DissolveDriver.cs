// DISSOLVE DRIVER — generates a sprite + a noise texture in code, puts the
// Dissolve shader on a quad, and animates the threshold 0→1→0 forever.
// Click to restart the burn. Chapter 03 of the book.
using UnityEngine;

public class DissolveDriver : MonoBehaviour
{
    Material mat;
    float t;

    void Start()
    {
        // the victim: a round code-painted creature (same as SpriteBasics)
        var body = new Texture2D(64, 64, TextureFormat.RGBA32, false);
        for (int y = 0; y < 64; y++)
            for (int x = 0; x < 64; x++)
                body.SetPixel(x, y, new Vector2(x - 32, y - 28).magnitude < 24
                    ? new Color(0.35f, 0.39f, 0.78f) : Color.clear);
        body.Apply();

        // the noise: blurry random blotches — the SHAPE of the dissolve
        var noise = new Texture2D(64, 64, TextureFormat.RGBA32, false);
        var rng = new System.Random(7);
        for (int y = 0; y < 64; y++)
            for (int x = 0; x < 64; x++)
            {
                float v = (float)rng.NextDouble();
                noise.SetPixel(x, y, new Color(v, v, v, 1));
            }
        noise.Apply();

        var quad = GameObject.CreatePrimitive(PrimitiveType.Quad);
        quad.transform.localScale = new Vector3(4, 4, 1);
        mat = quad.GetComponent<Renderer>().material;
        mat.shader = Shader.Find("SparksAndSprites/Dissolve");
        mat.SetTexture("_MainTex", body);
        mat.SetTexture("_NoiseTex", noise);
    }

    void Update()
    {
        if (Input.GetMouseButtonDown(0)) t = 0;
        t += Time.deltaTime;
        // threshold breathes 0→1→0 on a 4-second cycle
        mat.SetFloat("_Threshold", Mathf.PingPong(t * 0.5f, 1f));
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 800, 40),
        "Dissolve: noise < threshold → discard. Click to restart the burn.");
}
