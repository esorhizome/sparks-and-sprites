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
