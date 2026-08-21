# 05 · Movement & personality

*Fresh-start note: a **tween** animates a value from A to B over a duration; **easing** is the shape of that animation's speed (linear = constant, ease-out = fast then gentle, ease-in-out = gentle both ends); **lerp(a, b, t)** gives the value `t` of the way from a to b; **noise** is smooth organic randomness; **delta time (`dt`)** is the seconds since last frame. Every one of these is re-mentioned where it's used.*

---

Here is the load-bearing secret of character animation, stated once, plainly:

> **Personality is not what moves — it's the shape of the speed.**

The same dot travelling the same line reads as a person, a machine, or something unearthly depending only on its timing curve, its detours, and its little imperfections. Which means personality is *programmable*.

▶ **See all eight before reading on:** [movement personalities demo](https://esorhizome.github.io/sparks-and-sprites/easing-personalities.html) — one dot, eight buttons, editable code.
🎮 *Godot direct demo:* the **personalities** scene in `demos/godot/` — press keys 1–8.

## Human

- **Ease both ends** — people accelerate and brake; nothing starts at full speed. (Easing = the speed-shape of an animation.)
- **Slight overshoot** — reach a touch past the target, settle back (the "back" easing family, or a soft spring).
- **Never perfectly still** — an idle sine-wave "breath": `y += sin(time * 1.5) * 2`.
- **Imperfect timing** — add ±5% random variation to durations so repeats never match exactly.

```gdscript
# Godot: humane move in one line
create_tween().tween_property(self, "position", target, 0.5)\
  .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

**Unity try-it:** with the free core of DOTween: `transform.DOMove(target, 0.5f).SetEase(Ease.OutBack);` — the same sentence in a different accent. Tweak `OutBack`'s overshoot until it feels like *your* character.
**Unreal try-it:** a Timeline node with a float curve shaped like ease-out-back, driving a Lerp between start and target positions. Drawing the curve by hand in the curve editor is genuinely instructive — you are drawing the personality.

## Superhuman

- **Anticipation, then violence** — a small pull *backwards* (2–4 frames), then cover the whole distance in 3–6 frames. The pause is what sells the speed.
- **Smear** — stretch the sprite along its velocity during the fast frames, or leave 2–3 fading afterimage copies.
- **Impact receipt** — a hard stop plus a small camera shake or dust puff says the world felt it.

Easing shape: a curve like `t⁶` — nearly nothing, then everything.

## Alien

Alien = 90% human rules kept, 1–2 rules deliberately broken. Break them all and you get visual noise, not a creature.

- **Wrong smoothness** — glide with zero acceleration, then reorient *instantly* (no turning arc). Insects and octopus arms live here.
- **Wrong axes** — drift sideways while facing forward; rotate without banking.
- **Noise-driven wandering** — position fed by low-frequency noise (smooth randomness) never repeats and never *decides*, which reads as "thinking, but not like us."
- **Unearthly frequency** — oscillate too slowly (0.1 Hz), or with two frequencies that never sync: `sin(t·1.0) + sin(t·1.618)`.

## Emotional — excited ↔ sad as two ends of one dial

The programmable dial is a **spring** (a value pulled toward a target, with momentum):

```js
// a spring in 4 lines (works anywhere, any language)
velocity += (target - position) * stiffness * dt;  // dt = seconds since last frame
velocity *= damping;
position += velocity * dt;
// stiffness 40, damping 0.95 → excited (bouncy overshoot)
// stiffness  6, damping 0.85 → sad (slow, drooping, no bounce)
```

- **Excited** — springy overshoot with several bounces, quick durations, motion *leans toward* the target before departing, extra vertical bounce.
- **Sad** — slow ease-out (fast-then-gentle speed shape), a drooping arc that sags below the straight line, every gesture's amplitude reduced, and a *hesitation* — a beat of stillness — before starting.

Stiff+bouncy = joy; soft+overdamped = sorrow. Emotion as a tuning knob is a genuinely beautiful fact.

**Unity try-it:** the four spring lines drop straight into `Update()` with `Time.deltaTime` as `dt`. **Unreal try-it:** the same four lines in a Blueprint tick, or use the built-in `FMath::CriticalDamp`-family helpers; either way, expose stiffness and damping as editable variables and play.

## Emotionless

Pure linear interpolation (constant speed — the lerp with no easing), zero idle motion, identical repeats. Unsettling precisely because every human rule is absent. Switching a character from eased to linear mid-scene is a cheap, chilling storytelling beat.

## Robot — and cyborg as a blend

- **Quantised motion** — move in discrete ticks: `x = floor(smooth_x / step) * step`. Instant servo feel.
- **One axis at a time** — rotate, *stop*, then translate. Never blend the two.
- **Servo settle** — arrive with a tiny fast oscillation that dies in ~0.2 s (an overdamped spring — see the four lines above), like a hard-drive head parking.
- **Cyborg** — run the human recipe, but every few seconds quantise for 200 ms or drop two frames (a glitch). Human base + mechanical interruptions = uncanny in exactly the right way.

## Stately / grand

- **Long, symmetric ease-in-out** (sine or cubic, 1.5–4 s) — unhurried in both directions; nothing startles it.
- **Arcs, never straight lines** — route every move along a wide curve. Straight lines are for errands; curves are for ceremony.
- **Few gestures, fully finished** — one slow motion that completes beats five small ones. Stillness between moves is part of the performance.
- **Follow-through** — trailing elements (cloak, ribbon, hair) arrive a beat later, softly. Even a fading particle trail supplies this.

Grand is mostly *restraint plus duration* — the cheapest personality to program and the hardest to fake with assets.

## The tools that do the tweening for you

- **Godot:** built-in `Tween` (excellent; every easing family included) and `AnimationPlayer` for authored timelines.
- **Unity:** coroutine lerping works bare; **DOTween** (free core; Pro ≈ $15 one-time) is the community standard; **PrimeTween** is a newer free alternative.
- **Unreal:** *Timeline* nodes in Blueprints; UMG animations for UI; Curve assets for custom easing shapes.
- **Web:** the built-in [Web Animations API](https://developer.mozilla.org/) (no library needed); [GSAP](https://gsap.com/) — 100% free including all formerly-paid plugins (since 2025); [anime.js](https://animejs.com/) (free, MIT); [Motion](https://motion.dev/) (free core). Hand-design easing curves at [cubic-bezier.com](https://cubic-bezier.com/); browse named ones at [easings.net](https://easings.net/).

---

*Timing curve + detour + imperfection: three dials, every personality. You could have invented most of this chapter — these recipes are observations you've already made about how things move, written as arithmetic.*
