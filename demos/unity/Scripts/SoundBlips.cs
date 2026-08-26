// SOUND BLIPS — coin, laser, hit: synthesized from nothing.
// OnAudioFilterRead hands you the raw sample buffer; fill it with sine
// arithmetic and you have a synthesizer. Keys 1 / 2 / 3 to play.
// Chapter 07 of the book.
using UnityEngine;

[RequireComponent(typeof(AudioSource))]
public class SoundBlips : MonoBehaviour
{
    string blip = "";
    double phase, blipTime;
    int sampleRate;
    readonly System.Object gate = new System.Object();

    void Start()
    {
        sampleRate = AudioSettings.outputSampleRate;
        var src = GetComponent<AudioSource>();
        src.Play();                        // an empty source keeps the filter running
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Alpha1)) Trigger("coin");
        if (Input.GetKeyDown(KeyCode.Alpha2)) Trigger("laser");
        if (Input.GetKeyDown(KeyCode.Alpha3)) Trigger("hit");
    }

    void Trigger(string name) { lock (gate) { blip = name; blipTime = 0; } }

    void OnAudioFilterRead(float[] data, int channels)
    {
        lock (gate)
        {
            for (int i = 0; i < data.Length; i += channels)
            {
                float s = 0;
                double u = blipTime;                     // seconds since the trigger
                switch (blip)
                {
                    case "coin":   // two quick square-ish notes, B5 → E6
                        if (u < 0.18)
                        {
                            double f = u < 0.08 ? 988 : 1319;
                            s = Mathf.Sign(Mathf.Sin((float)(phase * f))) * 0.12f *
                                (1f - (float)(u / 0.18));
                        }
                        break;
                    case "laser":  // a falling pitch sweep
                        if (u < 0.25)
                        {
                            double f = 1400 - u * 4200;
                            s = Mathf.Sin((float)(phase * f)) * 0.15f * (1f - (float)(u / 0.25));
                        }
                        break;
                    case "hit":    // shaped noise — a thump of static
                        if (u < 0.2)
                            s = (float)(new System.Random((int)(u * 99991)).NextDouble() * 2 - 1)
                                * 0.2f * (1f - (float)(u / 0.2));
                        break;
                }
                for (int c = 0; c < channels; c++) data[i + c] = s;
                phase += 2 * Mathf.PI / sampleRate;
                blipTime += 1.0 / sampleRate;
            }
        }
    }

    void OnGUI() => GUI.Label(new Rect(10, 10, 800, 40),
        "Sound blips: 1 = coin, 2 = laser, 3 = hit — pure OnAudioFilterRead arithmetic.");
}
