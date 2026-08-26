# Living buttons — the two species, in UMG

**Species 1 — the static loop** (alive before you touch it):
1. UMG widget: a Button with an Image *behind* it (the plasma underlay).
2. The Image's material: 2–3 radial blobs (periwinkle / pink / teal) whose
   centres orbit on `Time` — Additive blend, blurred and oversized so light
   leaks past the button's edges.
3. The face sits on top of its own light, so the label stays readable.

**Species 2 — the thank-you** (velocity, never position):
1. On Click: add to a `SpinVelocity` float — a **push**, not a set-angle.
2. Every tick: `Angle += SpinVelocity · dt; SpinVelocity *= 0.15^dt` —
   friction turns the push into a free ease-out. Apply Angle to a ring
   image's Render Transform.
3. Stack a Widget Animation on top: an expanding, fading ring (the
   luminous pulse) played from the click handler.

Wrap idle motion behind a "reduce motion" setting; keep the press
reactions — the user asked for those. Chapter 12 of the book.
