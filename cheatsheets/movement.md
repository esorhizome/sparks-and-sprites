# Cheatsheet · Movement & personality

Personality = **timing curve + detour + imperfection.** Full chapter: [05](../chapters/05-movement-and-personality.md). Live demo: [easing-personalities](https://esorhizome.github.io/sparks-and-sprites/easing-personalities.html).

| Personality | Curve | Detour | Imperfection |
|---|---|---|---|
| Human | ease-in-out + slight overshoot ("back") | small arc | ±5% duration jitter, idle sine breath |
| Superhuman | anticipation pull-back → `t⁶` snap | none (straight = force) | smear/afterimages, impact shake |
| Alien | constant glide, instant reorientation | noise-driven wander | two unsynced sine frequencies |
| Excited | spring: stiffness 40, damping 0.95 | leans toward target first | extra vertical bounce |
| Sad | slow ease-out | drooping arc (sags below line) | hesitation beat before starting |
| Emotionless | pure linear | none | none — that's the point |
| Robot | quantised steps + servo settle | one axis at a time | tiny 0.2 s settle oscillation |
| Cyborg | human base | human arcs | 200 ms quantise-glitches every few seconds |
| Stately / grand | long ease-in-out sine, 1.5–4 s | wide deliberate arcs | none — stillness between gestures instead |

**The universal spring (any language):**
```
velocity += (target - position) * stiffness * dt
velocity *= damping
position += velocity * dt
```

**One-liners:** Godot `create_tween().tween_property(...).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)` · Unity+DOTween `transform.DOMove(t, 0.5f).SetEase(Ease.OutBack)` · Unreal: Timeline node + hand-drawn curve · Web `el.animate([...], {duration: 500, easing: "cubic-bezier(.34,1.56,.64,1)"})`.

**Curve references:** [easings.net](https://easings.net/) (named curves, visual) · [cubic-bezier.com](https://cubic-bezier.com/) (draw your own).
