# Starfield & ambience — sparks at one-tenth speed

An ambient field is a particle system with the urgency removed. One Niagara
emitter, five calm numbers:

- Spawn Rate **2–8** per second (not hundreds)
- Lifetime **10+** seconds
- Sprite Size **tiny** (1–3)
- Velocity **near zero** (stars) or a slow drift (snow: down; motes: sideways)
- Gravity: **none**

Box Location module sized to cover the camera's view. Additive renderer.

Costumes, same skeleton:
- **Stars**: zero velocity + a Scale Color curve that dips and returns
  (bright–dim–bright = a twinkle).
- **Snow**: velocity (0, 0, −30) with a little X jitter.
- **Motes**: velocity (20, 0, 0), warm dust colour, alpha ~0.5.
- **Fireflies**: Spawn Rate 2, Curl Noise Force for wander, green-yellow,
  twinkle curve with long dark gaps.

## The 2D spelling

Flatten the Box Location to a plane (X extent 0) under an ortho camera and
nothing else changes — ambience is the least dimensional effect in the
book. Behind a Paper2D scene, put the emitter at a far depth for painless
parallax layering. The UMG spelling is a handful of Image stars whose
opacity runs slow sine twinkles from `NativeTick` — at 2–8 spawns a second,
widgets are plenty.
