// CONTACT & INTENT (2D) — a platformer test room built from code, physics by hand.
// The web lexicon's `input` and `contact` families (docs/locomotion.html, chapters 17
// and 18) hold 26 cards; this template carries seven AMBASSADORS in one small room:
//   Coyote time      — a jump stays legal for COYOTE seconds after the feet leave a ledge
//   Jump buffer      — a press up to BUFFER seconds before landing is stored, then fired
//   Variable height  — release early = the rise is cut (vy × CUT); falling is heavier
//   Dead zone        — the stick is radially RESCALED, not merely clamped (no jump at the edge)
//   AABB push-out    — the drifting crate: four inequalities, then push along the LEAST penetration
//   One-way platform — solid only when falling AND the feet were above its top; S+Space drops through
//   Swept wall       — every move is a SWEEP: time of impact along the axis, so a dash never tunnels
// Keys: A/D or ←/→ walk (through the dead zone) · Space jump (hold = higher) · S+Space drop
//       LeftShift dash (the sweep's stress test) · click = place the crate · hold right mouse = pointer as stick
//
// INPUT: this file reads the LEGACY `Input` class like every other template here (if the
// Input System package is in the project set Project Settings → Player → Active Input
// Handling to "Both"). The Input System spelling is named in comments where it differs;
// the maths is identical — only who hands you the numbers changes.
// No Rigidbody2D, no Collider2D: the point of the room is to see the rules written out.
using UnityEngine;

public class ContactAndIntent2D : MonoBehaviour
{
    // ---- the dials (every number the two chapters name) -------------------------
    const float G = 30f;            // gravity, units/s²
    const float FALL_G = 1.6f;      // gravity multiplier while falling (Variable: the heavy half)
    const float JUMP_V = 12f;       // take-off speed → apex ≈ v²/2g = 2.4 units
    const float CUT = 0.45f;        // Variable: vy is multiplied by this on an early release
    const float COYOTE = 0.10f;     // Coyote: seconds of grace after leaving the ground
    const float BUFFER = 0.12f;     // Jumpbuffer: seconds a press is remembered before landing
    const float DROP = 0.25f;       // Oneway: seconds the platform is ignored after S+Space
    const float DZ = 0.25f;         // Deadzone: the stick radius that must read as "nothing"
    const float WALK = 6f, ACCEL = 40f, BRAKE = 60f, AIR_ACCEL = 20f;   // Accelerate: three rates, not one
    const float DASH_V = 60f, DASH_T = 0.12f;   // the dash: ~1 unit per frame — a 0.2-wide wall would be skipped without a sweep

    // an AABB is a centre and a half-size; Min/Max are the four numbers every test reads
    struct Box { public Vector2 c, h; public Vector2 Min => c - h; public Vector2 Max => c + h; }

    Box hero, crate, oneWay;
    Box[] solids;                   // two grounds, the pit floor, the thin wall
    Vector2 vel;
    bool grounded, onOneWay, holding;
    float facing = 1f, dashDir = 1f;
    float coyoteT, bufferT, dropT, dashT, holdT, apexY, sweepToi = 1f, lastDx, naiveGhostT, t;
    Vector2 rawStick, hardStick, treated;      // Deadzone: the three readings, side by side
    bool[] ineq = new bool[4]; bool crateHit; Vector2 pushArrow;
    Vector2 crateHome = new Vector2(-4f, -2.3f);

    Transform heroTf, crateTf, ghostTf, coyoteBar, bufferPip;
    Sprite unit; Texture2D ring;

    void Start()
    {
        // one white pixel → a 1-unit square sprite; every block in the room is that sprite, scaled
        var white = new Texture2D(1, 1, TextureFormat.RGBA32, false); white.SetPixel(0, 0, Color.white); white.Apply();
        unit = Sprite.Create(white, new Rect(0, 0, 1, 1), new Vector2(0.5f, 0.5f), 1f);
        Camera.main.clearFlags = CameraClearFlags.SolidColor;
        Camera.main.backgroundColor = new Color(0.075f, 0.063f, 0.125f);

        // the room: ledge · pit · floor · thin wall · a one-way shelf · a drifting crate
        solids = new[] {
            B(-4.5f, -4.25f, 7f, 0.5f),        // ground A (its right edge at x = −1 is the coyote ledge)
            B(0f, -5.75f, 2f, 0.5f),           // the pit floor, 1.5 units down — jumpable
            B(4.5f, -4.25f, 7f, 0.5f),         // ground B
            B(7f, -2.5f, 0.2f, 3f),            // the wall: 0.2 wide, the dash's tunnelling test
        };
        oneWay = B(3f, -2.2f, 3f, 0.2f);
        crate = B(crateHome.x, crateHome.y, 0.8f, 0.8f);
        hero = B(-6f, -3.6f, 0.6f, 0.8f);
        var ground = new Color(0.28f, 0.30f, 0.42f);
        foreach (var s in solids) Block("Solid", s, ground);
        Block("OneWay", oneWay, new Color(0.96f, 0.72f, 0.35f));
        crateTf = Block("Crate", crate, new Color(0.62f, 0.42f, 0.28f));
        heroTf = Block("Hero", hero, new Color(0.55f, 0.67f, 1f)); heroTf.GetComponent<SpriteRenderer>().sortingOrder = 2;
        ghostTf = Block("NaiveGhost", hero, new Color(1f, 0.3f, 0.3f, 0.5f)); ghostTf.gameObject.SetActive(false);
        coyoteBar = Block("CoyoteBar", B(0, 0, 0.8f, 0.08f), new Color(0.45f, 0.9f, 0.55f));
        bufferPip = Block("BufferPip", B(0, 0, 0.16f, 0.16f), new Color(1f, 0.75f, 0.3f));

        // a ring for the stick readout (OnGUI has no circle call either)
        ring = new Texture2D(48, 48, TextureFormat.RGBA32, false);
        for (int y = 0; y < 48; y++) for (int x = 0; x < 48; x++)
        {
            float d = Vector2.Distance(new Vector2(x, y), new Vector2(23.5f, 23.5f));
            ring.SetPixel(x, y, new Color(1, 1, 1, d > 21 && d < 23 ? 0.8f : d < 23 ? 0.08f : 0f));
        }
        ring.Apply();
    }

    static Box B(float cx, float cy, float w, float h) => new Box { c = new Vector2(cx, cy), h = new Vector2(w * 0.5f, h * 0.5f) };

    Transform Block(string name, Box b, Color col)
    {
        var go = new GameObject(name); go.transform.parent = transform;
        var sr = go.AddComponent<SpriteRenderer>(); sr.sprite = unit; sr.color = col;
        go.transform.position = b.c; go.transform.localScale = new Vector3(b.h.x * 2, b.h.y * 2, 1);
        return go.transform;
    }

    void Update()
    {
        float dt = Mathf.Min(Time.deltaTime, 1f / 30f);   // a long hitch must not become a long step
        t += dt;

        // ---- 1. the stick → intent (Deadzone) --------------------------------------
        ReadStick();
        if (Mathf.Abs(treated.x) > 0.01f) facing = Mathf.Sign(treated.x);

        // ---- 2. the grace timers (Coyote, Jumpbuffer, Oneway) ------------------------
        bool jumpPressed = Input.GetKeyDown(KeyCode.Space);   // Input System: Keyboard.current.spaceKey.wasPressedThisFrame
        bool jumpHeld = Input.GetKey(KeyCode.Space);          //               Keyboard.current.spaceKey.isPressed
        bool down = Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow) || treated.y < -0.5f;
        if (jumpPressed) bufferT = BUFFER;                    // JUMP BUFFER: remember the press, do not judge it yet
        bufferT -= dt; coyoteT -= dt; dropT -= dt; dashT -= dt; naiveGhostT -= dt;
        if (grounded) coyoteT = COYOTE;                       // COYOTE: standing refills the grace; leaving starts the clock
        if (jumpPressed && down && onOneWay) { dropT = DROP; bufferT = 0; }          // ONE-WAY drop: ignore the shelf briefly
        else if (bufferT > 0 && coyoteT > 0)                  // a stored press meets a live grace → the jump happens
        {
            vel.y = JUMP_V; bufferT = 0; coyoteT = 0;         // spend both, so one press cannot jump twice
            holding = true; holdT = 0; apexY = hero.c.y; grounded = false;
        }
        if (holding)                                          // VARIABLE HEIGHT: the hold only matters while rising
        {
            holdT += dt;
            if (!jumpHeld && vel.y > 0) { vel.y *= CUT; holding = false; }   // let go early = the rise is cut short
            if (vel.y <= 0) holding = false;
        }
        apexY = Mathf.Max(apexY, hero.c.y);

        // ---- 3. horizontal intent (Accelerate) --------------------------------------
        float want = treated.x * WALK;
        bool reversing = Mathf.Abs(vel.x) > 0.01f && Mathf.Sign(want) != Mathf.Sign(vel.x);
        float rate = !grounded ? AIR_ACCEL : (Mathf.Abs(want) < 0.01f || reversing) ? BRAKE : ACCEL;
        vel.x = Mathf.MoveTowards(vel.x, want, rate * dt);
        if (Input.GetKeyDown(KeyCode.LeftShift) && dashT <= 0) { dashT = DASH_T; dashDir = facing; }
        if (dashT > 0) { vel.x = dashDir * DASH_V; vel.y = 0; }
        vel.y -= G * (vel.y < 0 ? FALL_G : 1f) * dt;         // heavier on the way down (Variable's other half)
        vel.y = Mathf.Max(vel.y, -25f);

        // ---- 4. move: sweep X, then sweep Y (the Xaxis card's order) -----------------
        MoveX(vel.x * dt);
        MoveY(vel.y * dt);

        // ---- 5. the crate: AABB overlap + least-penetration push-out (Aabb card) -----
        crate.c = crateHome + new Vector2(Mathf.Sin(t * 0.7f) * 1.2f, Mathf.Sin(t * 1.1f) * 0.6f);   // a Lissajous drift
        if (Input.GetMouseButtonDown(0)) { var w = Camera.main.ScreenToWorldPoint(Input.mousePosition); crateHome = new Vector2(w.x, w.y); }
        ResolveCrate();

        // the room's edges and the fall-out respawn
        hero.c.x = Mathf.Clamp(hero.c.x, -8.5f, 8.5f);
        if (hero.c.y < -8f) { hero.c = new Vector2(-6f, -3.6f); vel = Vector2.zero; }

        // ---- 6. show it ----------------------------------------------------------
        heroTf.position = hero.c; crateTf.position = crate.c;
        ghostTf.gameObject.SetActive(naiveGhostT > 0);
        coyoteBar.position = hero.c + new Vector2(0, 1.1f);
        coyoteBar.localScale = new Vector3(0.8f * Mathf.Clamp01(coyoteT / COYOTE), 0.08f, 1);   // the shrinking grace bar
        bufferPip.gameObject.SetActive(bufferT > 0);                                              // the amber pip that waits
        bufferPip.position = hero.c + new Vector2(0, 1.4f);
    }

    // ---- the stick: raw → hard dead zone → RADIAL RESCALE ----------------------------
    void ReadStick()
    {
        // raw axes (keys give ±1, a pad gives analogue). Input System: Gamepad.current.leftStick
        // .ReadUnprocessedValue() — .ReadValue() already runs a radial "Stick Deadzone" processor
        // (min 0.125, max 0.925), which is exactly the treatment written out below.
        Vector2 raw = new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
        if (Input.GetMouseButton(1))                                                         // right mouse: the pointer IS the stick
            raw = (Camera.main.ScreenToWorldPoint(Input.mousePosition) - (Vector3)hero.c) / 1.5f;
        // the Jitter card: a real thumb never rests at exactly zero — add the wobble a worn stick reports
        raw += new Vector2(Mathf.PerlinNoise(t * 3f, 0.3f) - 0.5f, Mathf.PerlinNoise(0.7f, t * 3f) - 0.5f) * 0.3f;
        rawStick = Vector2.ClampMagnitude(raw, 1f);
        float len = rawStick.magnitude;
        hardStick = len < DZ ? Vector2.zero : rawStick;                     // the naive cut: 0 then suddenly 0.25 — a jump at the edge
        treated = len < DZ ? Vector2.zero                                   // RADIAL RESCALE: 0 at the dead-zone edge, 1 at the rim,
                : rawStick.normalized * Mathf.Clamp01((len - DZ) / (1f - DZ));   // and the direction untouched (an axis-wise cut bends diagonals)
    }

    // ---- sweep along X: the distance to the first face we would cross, as a fraction of the step
    void MoveX(float dx)
    {
        lastDx = dx;
        if (Mathf.Abs(dx) < 1e-6f) return;
        float tHit = 1f; bool hit = false;
        Vector2 naive = hero.c + new Vector2(dx, 0);                        // where "x += vx·dt" would put us
        foreach (var s in solids)
        {
            if (hero.Max.y <= s.Min.y || hero.Min.y >= s.Max.y) continue;  // not sharing any rows: the sweep cannot touch it
            float gap = dx > 0 ? s.Min.x - hero.Max.x : hero.Min.x - s.Max.x;   // room left before the face we move toward
            if (gap < -1e-4f) continue;                                     // already past that face: not this axis's business
            float toi = gap / Mathf.Abs(dx);                                // TIME OF IMPACT, 0..1 of this step
            if (toi < tHit) { tHit = toi; hit = true; }
        }
        hero.c.x += dx * Mathf.Clamp01(tHit);                               // move up to the wall, never through it
        sweepToi = hit ? tHit : 1f;
        if (hit)
        {
            vel.x = 0;
            if (dashT > 0) { dashT = 0; ghostTf.position = naive; naiveGhostT = 0.8f; }   // show the tunnelled ghost the naive step would have made
        }
    }

    // ---- sweep along Y: the same test, plus the ONE-WAY rule for the shelf ------------
    void MoveY(float dy)
    {
        grounded = false; onOneWay = false;
        if (Mathf.Abs(dy) < 1e-7f) return;
        float tHit = 1f; bool hit = false, hitShelf = false;
        for (int i = 0; i <= solids.Length; i++)
        {
            bool shelf = i == solids.Length; Box s = shelf ? oneWay : solids[i];
            // ONE-WAY: only when falling, only if the feet started above the top, and not while dropping through
            if (shelf && (dy >= 0 || hero.Min.y < s.Max.y - 1e-3f || dropT > 0)) continue;
            if (hero.Max.x <= s.Min.x || hero.Min.x >= s.Max.x) continue;  // not sharing any columns
            float gap = dy > 0 ? s.Min.y - hero.Max.y : hero.Min.y - s.Max.y;
            if (gap < -1e-4f) continue;
            float toi = gap / Mathf.Abs(dy);
            if (toi < tHit) { tHit = toi; hit = true; hitShelf = shelf; }
        }
        hero.c.y += dy * Mathf.Clamp01(tHit);
        if (hit) { vel.y = 0; if (dy < 0) { grounded = true; onOneWay = hitShelf; } }
    }

    // ---- the crate: four inequalities, then the smaller of the two overlaps wins -------
    void ResolveCrate()
    {
        ineq[0] = hero.Min.x < crate.Max.x;  ineq[1] = hero.Max.x > crate.Min.x;   // overlap on X
        ineq[2] = hero.Min.y < crate.Max.y;  ineq[3] = hero.Max.y > crate.Min.y;   // overlap on Y
        crateHit = ineq[0] && ineq[1] && ineq[2] && ineq[3];                        // AABB OVERLAP = all four pass
        pushArrow = Vector2.zero;
        if (!crateHit) return;
        Vector2 d = hero.c - crate.c, sum = hero.h + crate.h;
        float px = sum.x - Mathf.Abs(d.x), py = sum.y - Mathf.Abs(d.y);            // how deep on each axis
        if (px < py) { pushArrow = new Vector2(Mathf.Sign(d.x) * px, 0); hero.c.x += pushArrow.x; vel.x = 0; }   // LEAST PENETRATION: the short way out
        else
        {
            pushArrow = new Vector2(0, Mathf.Sign(d.y) * py); hero.c.y += pushArrow.y;
            if (d.y > 0) { grounded = true; vel.y = Mathf.Max(vel.y, 0); } else vel.y = Mathf.Min(vel.y, 0);   // standing on it / bumping it
        }
    }

    // ---- readouts ---------------------------------------------------------------------
    void OnGUI()
    {
        GUI.Label(new Rect(10, 8, 1100, 22), "CONTACT & INTENT (2D) — A/D walk · Space jump (hold = higher) · S+Space drop through · Shift dash · click = crate · right-drag = stick");
        string tick(bool b) => b ? "yes" : "no";
        GUI.Label(new Rect(10, 30, 1100, 22), $"coyote {Mathf.Max(0, coyoteT):0.000} s   buffer {Mathf.Max(0, bufferT):0.000} s   drop {Mathf.Max(0, dropT):0.00} s   dash {Mathf.Max(0, dashT):0.00} s   hold {holdT:0.00} s   apex +{apexY + 3.6f:0.00}   grounded {tick(grounded)}{(onOneWay ? " (one-way)" : "")}");
        GUI.Label(new Rect(10, 46, 70, 20), "grace");  Bar(80, 52, 120, 8, coyoteT / COYOTE, new Color(0.45f, 0.9f, 0.55f));
        GUI.Label(new Rect(210, 46, 70, 20), "buffer"); Bar(280, 52, 120, 8, bufferT / BUFFER, new Color(1f, 0.75f, 0.3f));
        GUI.Label(new Rect(10, 68, 1100, 22), $"stick   raw ({rawStick.x:+0.00;-0.00}, {rawStick.y:+0.00;-0.00})   hard dead zone ({hardStick.x:+0.00;-0.00}, {hardStick.y:+0.00;-0.00})   radial rescale ({treated.x:+0.00;-0.00}, {treated.y:+0.00;-0.00})  ← drives the hero");
        Stick(20, 96, rawStick, "raw"); Stick(90, 96, hardStick, "hard"); Stick(160, 96, treated, "radial");
        string crateLine = crateHit ? $"OVERLAP, pushed ({pushArrow.x:+0.00;-0.00}, {pushArrow.y:+0.00;-0.00})" : "no overlap";
        GUI.Label(new Rect(10, 156, 1100, 22), $"crate   minX<crate.maxX {tick(ineq[0])}   maxX>crate.minX {tick(ineq[1])}   minY<crate.maxY {tick(ineq[2])}   maxY>crate.minY {tick(ineq[3])}   →  {crateLine}");
        GUI.Label(new Rect(10, 176, 1100, 22), sweepToi < 1f
            ? $"sweep   the X step ({lastDx:+0.000;-0.000}) stopped at t = {sweepToi:0.00} of the way — a wall face; the red ghost is where the naive step lands"
            : "sweep   last X step ran its full length (t = 1)");
    }
    void Bar(float x, float y, float w, float h, float k, Color c)
    {
        GUI.color = new Color(1, 1, 1, 0.15f); GUI.DrawTexture(new Rect(x, y, w, h), Texture2D.whiteTexture);
        GUI.color = c; GUI.DrawTexture(new Rect(x, y, w * Mathf.Clamp01(k), h), Texture2D.whiteTexture); GUI.color = Color.white;
    }
    void Stick(float x, float y, Vector2 v, string name)
    {
        GUI.DrawTexture(new Rect(x, y, 48, 48), ring);
        GUI.color = new Color(1, 1, 1, 0.25f); GUI.DrawTexture(new Rect(x + 24 - 24 * DZ, y + 24 - 24 * DZ, 48 * DZ, 48 * DZ), ring);   // the dead zone, to scale
        GUI.color = Color.white; GUI.DrawTexture(new Rect(x + 22 + v.x * 22, y + 22 - v.y * 22, 5, 5), Texture2D.whiteTexture);
        GUI.Label(new Rect(x, y + 46, 60, 20), name);
    }
}
