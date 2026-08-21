# 07 · Sound effects, programmatically

*Fresh-start note: **pitch** is how high or low a sound is (2× playback speed ≈ one octave up); a **tween** animates a value over time; **delta time** is the seconds since last frame; a **bus/mixer** is a named channel that groups sounds so you can control their volume together (like "SFX" vs "Music" sliders). All re-mentioned below.*

---

Sound is the most neglected half of "game feel," and the programmatic tricks are *simpler* than the visual ones. Three levels: play a file → randomize it → synthesize it from nothing.

## Level 1 · Playing a sound file from code

**Godot:**
```gdscript
var player := AudioStreamPlayer.new()      # non-positional; use AudioStreamPlayer2D for placed sound
add_child(player)
player.stream = load("res://sfx/coin.ogg")
player.play()
```

**Unity:**
```csharp
// AudioSource component on any GameObject:
audioSource.PlayOneShot(coinClip);   // fire-and-forget; overlapping plays are fine
```
*Try it: `PlayOneShot` on every coin in a pickup burst — Unity voices them all without cutting each other off. Then try the same with `Play()` and hear why `PlayOneShot` exists.*

**Unreal:** the *Play Sound 2D* Blueprint node (UI/global sounds) or *Play Sound at Location* (world sounds). One node, drag in the sound asset. MetaSounds (Unreal's sound-graph system) is where sounds themselves become programmable — worth one curious afternoon.

**Web:**
```js
const coin = new Audio("sfx/coin.ogg");
coin.play();                          // must happen after a user click — see below
```

⚠️ **The web autoplay rule:** every browser blocks audio before the first user interaction — by design, not by bug. The cure is cultural, not technical: a "click to start" screen, which every web game has for exactly this reason. Start or resume audio inside that click's event handler and everything after flows normally.

## Level 2 · The one trick that transforms everything: pitch randomization

The same footstep file played 40 times sounds like a machine gun. Played 40 times at a random pitch (highness/lowness) between 0.9 and 1.1, it sounds like walking. This is the single highest-value line of audio code in existence:

- **Godot:** `player.pitch_scale = randf_range(0.9, 1.1)` before each `play()`.
- **Unity:** `audioSource.pitch = Random.Range(0.9f, 1.1f);` — *try widening the range until it sounds silly, then pull back; you'll land near 0.85–1.15.*
- **Unreal:** *Play Sound* nodes expose Pitch Multiplier; or set a pitch range on a Sound Cue / MetaSound so the asset randomizes itself.
- **Web (WebAudio):** `source.playbackRate.value = 0.9 + Math.random() * 0.2;`

Second-highest-value trick: **volume variation** (±20%) and **round-robin** (record 3 variants, cycle them randomly). Stack all three and any repeated sound becomes organic.

## Level 3 · Synthesizing sound from pure code

No files at all — the audio equivalent of procedural textures.

**Web — the WebAudio API (built into every browser):**
```js
const ac = new AudioContext();               // create once, after a user click
function blip(freq = 880) {
  const osc = ac.createOscillator();          // a tone generator
  const gain = ac.createGain();               // a volume knob
  osc.frequency.value = freq;                 // pitch in Hz
  osc.type = "square";                        // square = chiptune voice
  gain.gain.setValueAtTime(0.2, ac.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + 0.15); // fade = no click
  osc.connect(gain).connect(ac.destination);
  osc.start();
  osc.stop(ac.currentTime + 0.15);
}
blip(880);            // coin-ish. blip(220) = thud-ish. Sweep freq downward = laser.
```

▶ *See (hear) it:* [sound blips demo](https://esorhizome.github.io/sparks-and-sprites/sound-blips.html) — coin, laser, and hit, all synthesized in front of you, all editable.

**Godot — `AudioStreamGenerator`:** push samples (numbers between −1 and 1 describing the speaker's position) into a buffer from GDScript. A sine wave at 440 Hz is `sin(TAU * 440.0 * t)` pushed sample by sample.
🎮 *Godot direct demo:* the **sound blips** scene in `demos/godot/` synthesizes the same coin/laser/hit trio, commented line by line.

**Unity try-it:** implement `OnAudioFilterRead(float[] data, int channels)` on any component — fill `data` with your samples and Unity plays them. The same sine formula works verbatim.
**Unreal:** MetaSounds is genuinely the friendliest node-based synth in any engine — oscillator → envelope → output is three nodes. Recreate the coin blip there and you'll understand every mobile game's audio budget.

**Or use a generator tool** (free, browser-based, export .wav):
- [sfxr.me](https://sfxr.me/) (jsfxr) — the classic "press button, get retro sound effect" tool. Press *randomize* until happy, export.
- [ChipTone](https://sfbgames.itch.io/chiptone) — friendlier interface, more control, free.

## Mixing, fading, ducking (the 10% that sounds professional)

- **Buses/mixers** — route every sound through named channels ("Music", "SFX", "UI") so a settings slider is one line: Godot *Audio Buses* panel + `AudioServer.set_bus_volume_db()`; Unity *Audio Mixer* asset; Unreal *Sound Classes / Control Buses*; WebAudio: one shared `GainNode` per group.
- **Fade with a tween** (animating a value over time — volume is just another value): fade music out over 2 s instead of cutting it. Decibels are logarithmic; fading the *linear* gain (0–1) sounds more natural than fading dB directly.
- **Ducking** — auto-lower music while dialogue/SFX plays: built into Unity's mixer (*Duck Volume* effect) and Unreal (*Sound Class* passive mix modifiers); in Godot/Web, tween the music bus down and back.

## Free & legal sound sources

| Source | What | License | Cost |
|---|---|---|---|
| [Kenney audio packs](https://kenney.nl/assets/category:Audio) | UI, impacts, jingles, footsteps | CC0 (free for anything, no credit needed) | free |
| [freesound.org](https://freesound.org/) | Enormous recorded-sound archive | varies per sound — CC0 to CC-BY-NC; filter by license | free |
| [Sonniss GDC archives](https://sonniss.com/gameaudiogdc) | ~100 GB of professional SFX libraries | free for commercial use, no credit required | free |
| [Pixabay SFX](https://pixabay.com/sound-effects/) | Broad general-purpose SFX | Pixabay license (free use; no reselling as-is) | free |
| [sfxr.me](https://sfxr.me/) / [ChipTone](https://sfbgames.itch.io/chiptone) | *Generate* your own retro SFX | yours — you made them | free |

⚠️ On freesound.org the license is **per sound, not per site** — the filter sidebar lets you show only CC0. Do that and browsing becomes worry-free.

---

*Play, randomize, synthesize. Three levels, and level 2 — one line — is where most of the magic lives. You now know more about game audio than a large fraction of shipped games demonstrate.*
