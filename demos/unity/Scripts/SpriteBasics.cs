// SPRITE BASICS — load, attach, place, with an image generated from pure code.
// The whole pipeline: paint a Texture2D pixel by pixel → wrap it in a Sprite
// → put it on SpriteRenderers → move them by setting transform.position.
// "Moving a sprite" = changing those x, y numbers. That's the whole secret.
// Chapter 02 of the book.
using UnityEngine;

public class SpriteBasics : MonoBehaviour
{
    SpriteRenderer[] crowd;
    float t;

    void Start()
    {
        // paint a 16×16 round creature with two eyes, exactly like the web demo
        var tex = new Texture2D(16, 16, TextureFormat.RGBA32, false);
        tex.filterMode = FilterMode.Point;                 // crisp pixels
        for (int y = 0; y < 16; y++)
            for (int x = 0; x < 16; x++)
            {
                bool inBody = new Vector2(x - 8, y - 7).magnitude < 6f;  // round body
                bool inEye = (x == 6 || x == 10) && y == 8;
                Color c = inEye ? new Color(0.17f, 0.14f, 0.25f)
                        : inBody ? new Color(0.35f, 0.39f, 0.78f)
                        : Color.clear;                     // transparent pixel
                tex.SetPixel(x, y, c);
            }
        tex.Apply();
        var sprite = Sprite.Create(tex, new Rect(0, 0, 16, 16), new Vector2(0.5f, 0.5f), 16);

        crowd = new SpriteRenderer[5];                     // five copies, placed
        for (int i = 0; i < 5; i++)
        {
            var go = new GameObject("Creature" + i);       // attach…
            crowd[i] = go.AddComponent<SpriteRenderer>();
            crowd[i].sprite = sprite;
            go.transform.position = new Vector3(-4 + i * 2, 0, 0);   // …place
        }
    }

    void Update()
    {
        t += Time.deltaTime;
        for (int i = 0; i < crowd.Length; i++)             // move = change the numbers
        {
            var p = crowd[i].transform.position;
            p.y = Mathf.Sin(t * 2f + i) * 0.6f;
            crowd[i].transform.position = p;
        }
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 800, 40),
        "Sprite basics: a code-painted 16×16 creature, placed five times, bobbing on a sine.");
}
