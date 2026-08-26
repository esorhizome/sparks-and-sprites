# The cube codex — character VFX, family by family

`SSCubeVfx.h/.cpp` is the working skeleton: a patrolling cube with named
Niagara slots, a following halo (point light + flattened emissive ring with
lag, bob, and the ±3% breath), and BlueprintCallable `Trigger*` reactions.
This recipe maps the codex's fourteen families — all 104 effects live on
[the web page](https://esorhizome.github.io/sparks-and-sprites/cube-vfx.html)
and in Godot (`demos/godot/scenes/cubefx/`) — onto Unreal's tools:

| Family | Unreal spelling |
|---|---|
| Fire attacks | Niagara bursts/cones (see `flame.md`, warm palette); attach to a socket for fists/mouth; recoil = a small additive rotation on the mesh |
| Water attacks | cone emitter + **Gravity Force** for the hose arc; Collision module + event → splash emitter (see `waterdrops.md`) |
| Lightning | a Niagara **beam/ribbon** from sky to impact point; screen flash = a brief post-process weight; chain = sequential beam spawns |
| Sparkles & charms | sprite emitters with a twinkle-alpha curve; *Spawn Per Unit* for the walking trail (see `trails-fragments.md`) |
| Halos & blessings | built into `SSCubeVfx`: detached ring mesh + point light that LERPs after the character — the lag is the charm |
| Auras & energy | a looping emitter **attached** to the mesh (velocity inherits automatically); power-up = crank spawn rate + an emissive material param |
| Movement | afterimages = ghost mesh copies with a fading translucent material; dust = burst at landing via `OnLanded`; speed lines = a camera post-process or ribbon |
| Impacts & hits | the hit-spark star as a single-frame flipbook sprite; hit-stop = brief `CustomTimeDilation`; shake = `SSTraumaShake` |
| Earth & nature | rock = a small mesh with projectile motion + shatter burst on hit; vines/thorns = timeline-driven spline meshes rising from the floor |
| Projectiles | an actor with `UProjectileMovementComponent` + a ribbon trail; beams = Niagara beam with a lifetime |
| Ice | shard meshes with instanced rotation; frost armour = a material overlay (fresnel + sparkle noise) toggled on the mesh |
| Wind | translucent ring meshes scaled outward; the tornado = a stack of rotating ring ribbons parented to the character |
| Dark & void | the clone = a second mesh sampling the character's position N frames back (a ring buffer); veils = a sphere with an inverted-alpha material |
| Decorations | tiny looping Niagara systems parented to the world, softly steered toward the character (butterflies, fireflies, petals) |

Working order that keeps the anatomy honest: idle loop first (it must read
as alive with nobody touching it), then the press reaction as one function
call, then the polish (recoil, shake, flash) — chapter 06's recipes, worn
by a character.
