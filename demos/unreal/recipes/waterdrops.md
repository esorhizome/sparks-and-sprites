# Waterdrops — a particle's death as an event

The lesson: one drop's END spawns two new things — splash droplets and a
ripple ring. Niagara spells this hand-off with **events**:

1. **Drops emitter**: Spawn Rate ~6, velocity (0, 0, −400), Lifetime set so
   particles die at the waterline (or use Collision with a plane).
   Add a **Generate Death Event** (or Collision Event) module.
2. **Splash emitter**: *Event Handler* → receives the death event →
   **Spawn Burst 5** at the event position, velocity up-and-out (cone 60°,
   speed 60–160), Gravity Force on, Lifetime 0.7, fade out.
3. **Ripple emitter**: second Event Handler → spawns **1** flat ring at the
   event position — a camera-facing (or floor-aligned) sprite of a ring
   texture, Scale Sprite Size 0 → big over 1.2 s, alpha 1 → 0.

Unity calls the same idea Sub Emitters; the web and Godot versions write it
out with two lists. Same hand-off, four accents.
