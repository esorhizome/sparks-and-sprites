# The glyph grimoire — text animation, family by family (2D and 3D)

`SSTextFx.h/.cpp` is the working skeleton: one `UTextRenderComponent` per
letter, an idle loop per mode, and a BlueprintCallable `TriggerPress`. This
recipe maps the grimoire's fourteen families — all 104 effects (plus 104
rhymes) live on
[the web page](https://esorhizome.github.io/sparks-and-sprites/text-fx.html)
and in Godot (`demos/godot/scenes/textfx/`) — onto Unreal's tools, **in both
dimensions**:

- **The 2D route is UMG.** Build a `HorizontalBox` of one `UTextBlock` per
  letter (a Blueprint loop over the phrase string at construct time), then
  animate each block's **RenderTransform** (translation, scale, shear,
  angle) and **ColorAndOpacity** from `NativeTick`, a widget animation, or
  a timeline. Every dial below has a RenderTransform twin. For paragraph
  text, `URichTextBlock` + a custom `URichTextBlockDecorator` gives you
  per-run styling; for letter-by-letter reveals a single TextBlock and
  `SetText(Phrase.Left(Shown))` is the cheap classic.
- **The 3D route is TextRender** (what `SSTextFx` does), which also serves
  a "2D look" — orthographic camera, fixed depth — when you want text
  living inside a Paper2D scene rather than on the HUD.

| Family | 2D spelling (UMG) | 3D spelling (TextRender / Niagara / materials) |
|---|---|---|
| Weight & width | swap font weight per block (`FSlateFontInfo.TypefaceFontName` across a variable-font family), or fake it: scale ×(1+k) with a bold typeface; shear = RenderTransform for the italic lean | `SetWorldSize` for the swell; true weight needs font swaps — or an outline material with a growing `Outline` scalar param |
| Glow & neon | a duplicate TextBlock behind, tinted, with `Blur` (UMG BackgroundBlur) or a soft-glow PNG brush; flicker = ColorAndOpacity keyed to noise | emissive material on the TextRender (`DefaultTextMaterialOpaque` → duplicate, crank Emissive), bloom does the rest; the buzz = SetTextRenderColor per frame |
| Typewriters | `SetText(Phrase.Left(Shown))` on a timer — the caret is one more TextBlock blinking on a 0.5s loop; the RPG box is a Border + this | reveal per-letter components with `SetVisibility(i < Shown)` (what `SSTextFx::Typewriter` does); the teletype jolt = a tiny root-component shake per arrival |
| Fades & pulses | ColorAndOpacity.A per block — the firefly pulse is one `Sin` curve in NativeTick; the lottery is a shuffled delay array | same alphas via `SetTextRenderColor`; TextRender has no per-component opacity fade on opaque materials — use the translucent text material |
| Grow & shrink | RenderTransform.Scale about each block's pivot (set Pivot 0.5,1.0 for baseline-anchored growth); the heartbeat is the same `exp(-beat·14)` envelope | `SetRelativeScale3D` + respread the centres (multiply resting Y by the swell, as `SSTextFx::Heartbeat` does) |
| Scrambles & decodes | `SetText` with wrong glyphs on a 0.05s churn timer, resolving left to right; the slot machine = a vertical `ScrollBox` of glyphs per column, eased to the target index | `SetText(FText::FromString(ScrambleGlyph()))` per letter per churn (what `SSTextFx::Decoder` does); matrix rain = a Niagara sprite emitter with a glyph flipbook behind the resolving TextRenders |
| Waves & bounces | RenderTransform.Translation.Y from one phase per block + Angle for the lean; the bounce is three parabolic hops in a curve asset | `SetRelativeLocation` Z from the same phase (what `SSTextFx::Wave` does); the jelly ripple reads the click point and displaces by distance-to-front |
| Arrivals | animate Translation from off-screen with per-block delays — a widget animation with staggered tracks, or NativeTick easing; Whoosh's streaks = a decorative image swept behind | letters lerp home from spawn offsets (compass = random unit vectors × radius); speed-line ribbons = Niagara ribbons keyed to the travel |
| Spins & flips | RenderTransform.Angle for cartwheels; the split-flap = Scale.Y = |cos| with a glyph swap at the edge-on frame (two keyframes and a callback) | real rotation at last: `SetRelativeRotation` Yaw spin lands face-on (`SSTextFx` coin-spin note in TextFx3D.cs's Unity twin); the flap plate = a thin box mesh per slot |
| Ink & colour | ColorAndOpacity per block — rainbow = HSV walk by (time + index); the misprint = three offset duplicates in an Overlay, additive-ish via low alpha | `SetTextRenderColor` per letter (what `SSTextFx::ColorRide` does); metals/fire want a material: gradient by `TexCoord.V` + a panning highlight |
| Shakes & glitches | Translation jitter (`FMath::FRandRange`) per block; RGB split = the misprint trick with red/green/blue duplicates snapping apart on a trigger | jitter the relative locations (what `SSTextFx::Shiver` does); the earthquake shakes the ROOT with trauma², same as `SSTraumaShake` |
| Strokes & outlines | UMG has font **outline settings** (`FFontOutlineSettings`): animate OutlineSize for double-stroke breathing; the marching ants need a material brush with a panning dashed border | the text outline material's `Outline` param; write-on = a radial-alpha erosion material on the text, driven by a scalar curve |
| Dust & particles | spawn tiny Image widgets (a pooled panel) for dust/confetti — or cheat honestly: one Niagara UI renderer plugin; the assembly = blocks lerping from scatter with sparkle images | Niagara everywhere: converge-to-point for star assembly (Point Attraction force), burst-at-letter for dust; letters fade in as arrival counts accumulate |
| Depth & shadow | a dark duplicate TextBlock offset behind = drop shadow (UMG TextBlock has a built-in Shadow Offset/Color — animate it); long shadow = N stacked duplicates | the true home of this family: extrusion copies trailing in camera depth (what `SSTextFx::StackExtrude` does), a real `UPointLightComponent` strolling the line, floor-flattened shadow copies under a wheeling sun |

Working order that keeps the anatomy honest, in either dimension: the
**idle loop first** (the phrase must read as alive with nobody touching
it), then the **press reaction** as one function call (`TriggerPress`, a
widget event), then the polish (the caret, the streaks, the dust) —
chapter 13's recipes, spelled in Unreal.
