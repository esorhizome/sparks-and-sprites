# Cheatsheet · Sound

Three levels: **play a file → randomize it → synthesize it.** Full chapter: [07](../chapters/07-sound-effects.md). Live demo: [sound-blips](https://esorhizome.github.io/sparks-and-sprites/sound-blips.html).

**Play:**
| Platform | Code |
|---|---|
| Godot | `AudioStreamPlayer` → `.stream = load(...)` → `.play()` |
| Unity | `audioSource.PlayOneShot(clip)` |
| Unreal | *Play Sound 2D* / *Play Sound at Location* node |
| Web | `new Audio("x.ogg").play()` — only after a user click |

**Randomize (the one-line transformation):**
| Platform | Pitch ±10% |
|---|---|
| Godot | `player.pitch_scale = randf_range(0.9, 1.1)` |
| Unity | `audioSource.pitch = Random.Range(0.9f, 1.1f);` |
| Unreal | Pitch Multiplier pin / Sound Cue pitch range |
| Web | `source.playbackRate.value = 0.9 + Math.random() * 0.2` |

Stack with ±20% volume variation and 3-variant round-robin → any repeated sound becomes organic.

**Synthesize:** WebAudio oscillator + gain envelope (see demo) · Godot `AudioStreamGenerator` · Unity `OnAudioFilterRead` · Unreal MetaSounds (osc → envelope → out, 3 nodes). Generator tools: [sfxr.me](https://sfxr.me/) · [ChipTone](https://sfbgames.itch.io/chiptone).

**Mix:** route through named buses ("Music"/"SFX"); fade linear gain (not dB) with a tween; duck music under dialogue.

**Beyond the three blips** — the audio family of [the stagecraft almanac](https://esorhizome.github.io/sparks-and-sprites/stagecraft.html) (13 cards, each drawn; no sound until clicked) and cheatsheet [stagecraft](stagecraft.md):
| Wanted | Card | Mechanism |
|---|---|---|
| footsteps by surface | **Footsteps** | the surface under the foot picks the recipe; the foot-plant event fires it |
| beep-speak dialogue | **Natter** | a blip per letter, pitched by character; vowels sine, consonants square |
| engine hum | **Engine** | oscillator pitch + volume follow speed |
| wind / rain / surf beds | **Noisebed** | filtered noise, slow LFOs on cutoff and gain |
| muffle (underwater, pause, behind a wall) | **Quiet** | a lowpass whose cutoff drops |
| reverb / echo zones | **Yodel** | a feedback delay whose mix rises inside the zone |
| adaptive music | **Jukebox** | layers fade by intensity; switch on the bar; stingers on the beat |
| tight timing | **Lookahead** | book notes ahead on the audio clock, never on a frame timer |
| too many voices | **Quota** | cap per sound; steal the oldest or quietest |
| haptics | **Rumble** | two motors (low / high) with intensity envelopes |
| positional / Doppler | **Positional** | pan by x, gain by distance, pitch by relative speed |
| synth recipes, visuals from sound | **Envelopes**, **Analyser** | shaped sweeps; the spectrum drives bars and a glow |

**Free sources:** [Kenney audio](https://kenney.nl/assets/category:Audio) (CC0) · [freesound.org](https://freesound.org/) (filter CC0!) · [Sonniss GDC](https://sonniss.com/gameaudiogdc) (free commercial) · [Pixabay SFX](https://pixabay.com/sound-effects/).

**Web rule:** no audio before the first user interaction — hence every web game's "click to start" screen.
