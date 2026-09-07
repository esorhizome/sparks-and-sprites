// THE WORLD WORKSHOP — worlds from arithmetic, painted into a Texture2D from one seed.
// The web workshop (docs/worlds.html, chapter 19) holds 13 generators and their rhymes;
// this template carries six AMBASSADORS, each grown step by step on screen, then rested,
// then regrown with the next seed — the living loop every card on the web page keeps:
//   [1] Poisson   — POISSON-DISC scatter (Bridson): random points that keep a minimum distance r
//   [2] Caves     — CELLULAR AUTOMATA: random fill, then "rock if ≥ 5 of 8 neighbours are rock", ×4
//   [3] Bsp       — BINARY SPACE PARTITION: split, split, split; a room per leaf; corridors between siblings
//   [4] Maze      — RECURSIVE BACKTRACKER: carve to a random unvisited neighbour, back up when stuck
//   [5] Autotile  — a 4-BIT NEIGHBOUR MASK (N=1 E=2 S=4 W=8) picks the tile; the index drawn as a hex glyph
//   [6] Save      — JsonUtility save/load with a `version` field and a MIGRATION for old saves
// Keys 1–6 switch · R = next seed · click = set r / regrow / resplit / carve again / paint a wall / save
// (mode 6: S = save to the next slot, L = load the newest slot, M = load a hard-coded version-1 save).
//
// THE PROMISE: Random.InitState(seed) at the top of every generator, and nothing else random
// in the loop, so seed 4477 is the same world on your machine and mine (chapter 01, "Seed").
using System.Collections.Generic;
using UnityEngine;

public class WorldWorkshop : MonoBehaviour
{
    const int W = 256, H = 160;        // texture size, px (grids below are sized to divide it)
    const float PPU = 32f;             // → 8 × 5 units
    const float REST = 2.5f;           // seconds a finished world rests before the next seed grows

    int mode = 1, seed = 7;
    float shown, t;                    // how many steps of the current world are revealed (grows with time)
    int steps;                         // how many steps the current world has
    Texture2D tex; Color[] px;

    static readonly Color ROCK = new Color(0.16f, 0.14f, 0.22f), FLOOR = new Color(0.62f, 0.56f, 0.46f), BG = new Color(0.075f, 0.063f, 0.125f),
                          INK = new Color(0.93f, 0.92f, 0.88f), DIM = new Color(0.45f, 0.45f, 0.55f), HERO = new Color(0.55f, 0.67f, 1f),
                          GOOD = new Color(0.45f, 0.9f, 0.55f), SUN = new Color(1f, 0.8f, 0.35f), WATER = new Color(0.3f, 0.55f, 0.9f);

    // a 3×5 glyph font for 0–9 A–F, rows top to bottom (the workshop draws its numbers ON the tiles)
    static readonly string[] GLYPH = {
        "111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001", "111100111001111", "111100111101111", "111001001001001",
        "111101111101111", "111101111001111", "010101111101101", "110101110101110", "111100100100111", "110101101101110", "111100111100111", "111100111100100" };

    // ---- [1] Poisson ----
    float radius = 12f; const int K = 30;                  // K = tries per active point before it retires
    List<Vector2> pts = new List<Vector2>(); List<Vector2> naive = new List<Vector2>();
    const int PW = 176;                                    // the disc scatter lives in the left 176 px; the naive strip on the right
    // ---- [2] Caves ----
    const int CC = 48, CR = 30, CELL = 5;                  // 48 × 30 cells of 5 px = 240 × 150
    const float FILLP = 0.45f; const int RULE = 5, PASSES = 4;
    List<bool[]> snaps = new List<bool[]>();               // the grid after each pass; the last one = only the largest open region kept
    // ---- [3] Bsp ----
    class Node { public RectInt r, room; public Node a, b; public bool vertical; public int cut; }
    Node root; List<Node> splitOrder = new List<Node>(); List<RectInt> rooms = new List<RectInt>(); List<Vector2Int[]> corridors = new List<Vector2Int[]>();
    // ---- [4] Maze ----
    const int MC = 24, MR = 15;                            // cells; drawn as a (2·MC+1) × (2·MR+1) tile grid of 5 px
    bool[] open; List<int> carve = new List<int>(); List<int> frontier = new List<int>(); int deadEnds;
    const int TW = 2 * MC + 1, TH = 2 * MR + 1, TS = 5;
    // ---- [5] Autotile ----
    const int AC = 32, AR = 20, AS = 8;                    // 32 × 20 tiles of 8 px = 256 × 160
    bool[] wall; bool paintTo;
    // ---- [6] Save ----
    [System.Serializable] public class SaveV2 { public int version = 2; public int seed; public float heroX, heroY; public int score; public bool[] coins = new bool[5]; public string biome = "meadow"; }
    [System.Serializable] class SaveV1 { public int version = 1; public int seed; public float heroX, heroY; public int score; public int coinMask; }   // the old shape: coins were a bitmask
    [System.Serializable] class Header { public int version; }
    SaveV2 world = new SaveV2();
    string[] slots = new string[3]; int nextSlot; string lastJson = "(nothing saved yet — press S)", note = "";
    Vector2 heroTarget; Vector2[] coinAt = new Vector2[5];
    const string LEGACY_V1 = "{\"version\":1,\"seed\":4477,\"heroX\":60,\"heroY\":40,\"score\":30,\"coinMask\":11}";   // a save from before `coins` existed

    void Start()
    {
        tex = new Texture2D(W, H, TextureFormat.RGBA32, false);
        tex.wrapMode = TextureWrapMode.Clamp; tex.filterMode = FilterMode.Point;
        px = new Color[W * H];
        var go = new GameObject("WorldCard"); go.transform.parent = transform;
        var sr = go.AddComponent<SpriteRenderer>();
        sr.sprite = Sprite.Create(tex, new Rect(0, 0, W, H), new Vector2(0.5f, 0.5f), PPU);
        Camera.main.clearFlags = CameraClearFlags.SolidColor; Camera.main.backgroundColor = BG;
        Regenerate();
    }

    void Update()
    {
        float dt = Time.deltaTime; t += dt;
        for (int k = 1; k <= 6; k++) if (Input.GetKeyDown(KeyCode.Alpha0 + k) && mode != k) { mode = k; Regenerate(); }
        if (Input.GetKeyDown(KeyCode.R)) { seed++; Regenerate(); }
        bool pressed = Input.GetMouseButtonDown(0), held = Input.GetMouseButton(0);
        Vector2 m = Vector2.zero;
        if (pressed || held)
        {
            var w = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            m = new Vector2((w.x + W / PPU * 0.5f) * PPU, (w.y + H / PPU * 0.5f) * PPU);   // world → texture px
        }
        // the living loop: reveal a few steps per second, rest, then grow the next seed
        float rate = mode == 1 ? 60f : mode == 2 ? 1.2f : mode == 3 ? 6f : 90f;
        if (mode <= 4)
        {
            shown += dt * rate;
            if (shown > steps + REST * rate) { seed++; Regenerate(); }
        }
        Clear(BG);
        switch (mode)
        {
            case 1: if (pressed) { radius = Mathf.Clamp(Vector2.Distance(m, new Vector2(PW / 2, H / 2)) / 5f, 5f, 28f); Regenerate(); } DrawPoisson(); break;
            case 2: if (pressed) Regenerate(); DrawCaves(); break;
            case 3: if (pressed) Regenerate(); DrawBsp(); break;
            case 4: if (pressed) Regenerate(); DrawMaze(); break;
            case 5:
                if (pressed || held)
                {
                    int cx = (int)(m.x / AS), cy = (int)(m.y / AS);
                    if (cx >= 0 && cx < AC && cy >= 0 && cy < AR) { if (pressed) paintTo = !wall[cy * AC + cx]; wall[cy * AC + cx] = paintTo; }   // click toggles, drag paints the same value
                }
                DrawAutotile(); break;
            case 6: TickWorld(dt); if (pressed || Input.GetKeyDown(KeyCode.S)) Save(); if (Input.GetKeyDown(KeyCode.L)) Load(slots[(nextSlot + 2) % 3]); if (Input.GetKeyDown(KeyCode.M)) Load(LEGACY_V1); DrawWorld(); break;
        }
        tex.SetPixels(px); tex.Apply();
    }

    // ---- one seed in, one world out ---------------------------------------------------------
    void Regenerate()
    {
        Random.InitState(seed);                              // THE line. Everything below is now a pure function of `seed`.
        shown = 0;
        switch (mode)
        {
            case 1: GenPoisson(); break;
            case 2: GenCaves(); break;
            case 3: GenBsp(); break;
            case 4: GenMaze(); break;
            case 5: GenAutotile(); break;
            case 6: GenWorld(); break;
        }
    }

    // ---- [1] POISSON-DISC (Bridson): a grid of cells r/√2 wide holds at most one point each ---
    void GenPoisson()
    {
        pts.Clear(); naive.Clear();
        float cell = radius / Mathf.Sqrt(2f);
        int gw = Mathf.CeilToInt(PW / cell), gh = Mathf.CeilToInt(H / cell);
        int[] grid = new int[gw * gh]; for (int i = 0; i < grid.Length; i++) grid[i] = -1;
        var active = new List<int>();
        void Insert(Vector2 p) { pts.Add(p); active.Add(pts.Count - 1); grid[(int)(p.y / cell) * gw + (int)(p.x / cell)] = pts.Count - 1; }
        bool Far(Vector2 p)                                  // is every already-placed point at least r away? only 5×5 cells need checking
        {
            int gx = (int)(p.x / cell), gy = (int)(p.y / cell);
            for (int y = Mathf.Max(0, gy - 2); y <= Mathf.Min(gh - 1, gy + 2); y++)
                for (int x = Mathf.Max(0, gx - 2); x <= Mathf.Min(gw - 1, gx + 2); x++)
                {
                    int j = grid[y * gw + x];
                    if (j >= 0 && Vector2.Distance(pts[j], p) < radius) return false;
                }
            return true;
        }
        Insert(new Vector2(Random.Range(0f, PW - 0.01f), Random.Range(0f, H - 0.01f)));
        while (active.Count > 0 && pts.Count < 1500)
        {
            int ai = Random.Range(0, active.Count); Vector2 p = pts[active[ai]]; bool found = false;
            for (int k = 0; k < K; k++)                      // K candidates in the ring r..2r around the active point
            {
                float a = Random.Range(0f, Mathf.PI * 2f), d = radius * (1f + Random.value);
                Vector2 q = p + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * d;
                if (q.x < 0 || q.y < 0 || q.x >= PW || q.y >= H || !Far(q)) continue;
                Insert(q); found = true; break;
            }
            if (!found) { active[ai] = active[active.Count - 1]; active.RemoveAt(active.Count - 1); }   // nothing fits around it any more: retire it
        }
        for (int i = 0; i < pts.Count * (W - PW) / PW; i++) naive.Add(new Vector2(PW + 4 + Random.Range(0f, W - PW - 8), Random.Range(0f, H)));   // the same density, no rule: clumps and voids
        steps = pts.Count;
    }
    void DrawPoisson()
    {
        float cell = radius / Mathf.Sqrt(2f);
        for (float x = 0; x < PW; x += cell) VLine((int)x, 0, H, new Color(1, 1, 1, 0.05f));   // the background grid
        for (float y = 0; y < H; y += cell) HLine(0, PW, (int)y, new Color(1, 1, 1, 0.05f));
        VLine(PW, 0, H, DIM);
        int n = Mathf.Min(pts.Count, (int)shown);
        for (int i = 0; i < n; i++) Disc(pts[i].x, pts[i].y, 1.6f, INK);
        if (n > 0 && n < pts.Count) Ring(pts[n - 1].x, pts[n - 1].y, radius, SUN);              // the newest point and its exclusion ring
        for (int i = 0; i < naive.Count; i++) Disc(naive[i].x, naive[i].y, 1.6f, DIM);
    }

    // ---- [2] CELLULAR CAVES: noise → a neighbour rule, a few times → keep the biggest room ---
    void GenCaves()
    {
        snaps.Clear();
        bool[] g = new bool[CC * CR];
        for (int i = 0; i < g.Length; i++) g[i] = Random.value < FILLP;
        snaps.Add((bool[])g.Clone());
        for (int pass = 0; pass < PASSES; pass++)
        {
            bool[] n = new bool[CC * CR];
            for (int y = 0; y < CR; y++) for (int x = 0; x < CC; x++)
                n[y * CC + x] = Neighbours(g, x, y) >= RULE || x == 0 || y == 0 || x == CC - 1 || y == CR - 1;   // the rule, and a solid border
            g = n; snaps.Add((bool[])g.Clone());
        }
        // flood-fill every open region, keep the largest, fill the rest — no unreachable pockets
        int[] region = new int[CC * CR]; var sizes = new List<int>(); var stack = new Stack<int>();
        for (int i = 0; i < g.Length; i++)
        {
            if (g[i] || region[i] != 0) continue;
            int id = sizes.Count + 1, size = 0; stack.Push(i); region[i] = id;
            while (stack.Count > 0)
            {
                int c = stack.Pop(); size++; int cx = c % CC, cy = c / CC;
                foreach (var d in new[] { 1, -1, CC, -CC })
                {
                    int j = c + d; if (j < 0 || j >= g.Length || (d == 1 && cx == CC - 1) || (d == -1 && cx == 0)) continue;
                    if (!g[j] && region[j] == 0) { region[j] = id; stack.Push(j); }
                }
            }
            sizes.Add(size);
        }
        int best = 0; for (int i = 1; i < sizes.Count; i++) if (sizes[i] > sizes[best]) best = i;
        bool[] final = (bool[])g.Clone();
        for (int i = 0; i < g.Length; i++) if (!g[i] && region[i] != best + 1) final[i] = true;
        snaps.Add(final);
        steps = snaps.Count;
    }
    static int Neighbours(bool[] g, int x, int y)
    {
        int n = 0;
        for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++)
        {
            if (dx == 0 && dy == 0) continue;
            int nx = x + dx, ny = y + dy;
            n += (nx < 0 || ny < 0 || nx >= CC || ny >= CR) ? 1 : g[ny * CC + nx] ? 1 : 0;   // off the map counts as rock
        }
        return n;
    }
    void DrawCaves()
    {
        int k = Mathf.Clamp((int)shown, 0, snaps.Count - 1); bool[] g = snaps[k];
        for (int y = 0; y < CR; y++) for (int x = 0; x < CC; x++) Fill(x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL, g[y * CC + x] ? ROCK : FLOOR);
        int hx = CC / 2, hy = CR / 2;                                                           // one cell, its rule shown
        Fill(hx * CELL - CELL, hy * CELL - CELL, hx * CELL + 2 * CELL, hy * CELL + 2 * CELL, new Color(SUN.r, SUN.g, SUN.b, 0.35f));
        Glyph(hx * CELL + 1, hy * CELL, Neighbours(g, hx, hy), INK);
        for (int i = 0; i <= PASSES + 1; i++) Fill(4 + i * 8, H - 6, 10 + i * 8, H - 2, i <= k ? GOOD : DIM);   // pass pips: 0 = noise … 4 = smoothed, 5 = largest region kept
    }

    // ---- [3] BSP: cut the rectangle in two, recurse; rooms in the leaves; corridors between siblings
    void GenBsp()
    {
        splitOrder.Clear(); rooms.Clear(); corridors.Clear();
        root = new Node { r = new RectInt(0, 0, CC, CR) };
        Split(root, 0);
        PlaceRooms(root);
        steps = splitOrder.Count + rooms.Count + corridors.Count;
    }
    void Split(Node n, int depth)
    {
        const int MIN = 7;                                    // a leaf must fit a room plus a margin
        bool canV = n.r.width >= MIN * 2, canH = n.r.height >= MIN * 2;
        if (depth >= 4 || (!canV && !canH)) return;
        n.vertical = canV && (!canH || Random.value < (n.r.width > n.r.height * 1.25f ? 0.8f : 0.4f));   // prefer cutting the long way
        if (n.vertical)
        {
            n.cut = Random.Range(n.r.xMin + MIN, n.r.xMax - MIN + 1);
            n.a = new Node { r = new RectInt(n.r.xMin, n.r.yMin, n.cut - n.r.xMin, n.r.height) };
            n.b = new Node { r = new RectInt(n.cut, n.r.yMin, n.r.xMax - n.cut, n.r.height) };
        }
        else
        {
            n.cut = Random.Range(n.r.yMin + MIN, n.r.yMax - MIN + 1);
            n.a = new Node { r = new RectInt(n.r.xMin, n.r.yMin, n.r.width, n.cut - n.r.yMin) };
            n.b = new Node { r = new RectInt(n.r.xMin, n.cut, n.r.width, n.r.yMax - n.cut) };
        }
        splitOrder.Add(n);
        Split(n.a, depth + 1); Split(n.b, depth + 1);
    }
    RectInt PlaceRooms(Node n)                               // returns a room inside this subtree, for the parent to connect to
    {
        if (n.a == null)
        {
            int w = Random.Range(3, n.r.width - 2), h = Random.Range(3, n.r.height - 2);
            n.room = new RectInt(Random.Range(n.r.xMin + 1, n.r.xMax - w), Random.Range(n.r.yMin + 1, n.r.yMax - h), w, h);
            rooms.Add(n.room); return n.room;
        }
        RectInt ra = PlaceRooms(n.a), rb = PlaceRooms(n.b);
        Vector2Int p = new Vector2Int(ra.x + ra.width / 2, ra.y + ra.height / 2), q = new Vector2Int(rb.x + rb.width / 2, rb.y + rb.height / 2);
        corridors.Add(new[] { p, new Vector2Int(q.x, p.y), q });                               // an L: across, then up — SIBLINGS only, so the map is a tree
        return Random.value < 0.5f ? ra : rb;
    }
    void DrawBsp()
    {
        Fill(0, 0, CC * CELL, CR * CELL, ROCK);
        int k = (int)shown, i = 0;
        foreach (var n in splitOrder) { if (i++ >= k) break; if (n.vertical) VLine(n.cut * CELL, n.r.yMin * CELL, n.r.yMax * CELL, DIM); else HLine(n.r.xMin * CELL, n.r.xMax * CELL, n.cut * CELL, DIM); }
        foreach (var r in rooms) { if (i++ >= k) break; Fill(r.xMin * CELL, r.yMin * CELL, r.xMax * CELL, r.yMax * CELL, FLOOR); }
        foreach (var c in corridors)
        {
            if (i++ >= k) break;
            for (int s = 0; s < 2; s++)
            {
                Vector2Int a = c[s], b = c[s + 1];
                for (int x = Mathf.Min(a.x, b.x); x <= Mathf.Max(a.x, b.x); x++) for (int y = Mathf.Min(a.y, b.y); y <= Mathf.Max(a.y, b.y); y++)
                    Fill(x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL, FLOOR);
            }
        }
    }

    // ---- [4] RECURSIVE BACKTRACKER: a depth-first walk that knocks down the wall it crosses --
    void GenMaze()
    {
        open = new bool[TW * TH]; carve.Clear(); frontier.Clear();
        bool[] seen = new bool[MC * MR]; var stack = new Stack<int>();
        int start = Random.Range(0, MC * MR); seen[start] = true; stack.Push(start);
        carve.Add(Tile(start % MC, start % MC, start / MC, start / MC));
        var dirs = new[] { new Vector2Int(1, 0), new Vector2Int(-1, 0), new Vector2Int(0, 1), new Vector2Int(0, -1) };
        while (stack.Count > 0)
        {
            int c = stack.Peek(), cx = c % MC, cy = c / MC;
            var options = new List<int>();
            foreach (var d in dirs) { int nx = cx + d.x, ny = cy + d.y; if (nx >= 0 && ny >= 0 && nx < MC && ny < MR && !seen[ny * MC + nx]) options.Add(ny * MC + nx); }
            if (options.Count == 0) { stack.Pop(); frontier.Add(-1); continue; }   // stuck: back up (the -1 marks a retreat in the animation)
            int n = options[Random.Range(0, options.Count)]; seen[n] = true; stack.Push(n);
            carve.Add(Tile(cx, n % MC, cy, n / MC)); carve.Add(Tile(n % MC, n % MC, n / MC, n / MC));   // the wall between, then the cell
            frontier.Add(n);
        }
        // the personality number: Prim's would give many short branches, the backtracker gives long corridors and few dead ends
        deadEnds = 0;
        for (int i = 0; i < carve.Count; i++) open[carve[i]] = true;
        for (int y = 0; y < MR; y++) for (int x = 0; x < MC; x++)
        {
            int tx = 2 * x + 1, ty = 2 * y + 1, exits = 0;
            if (open[ty * TW + tx + 1]) exits++; if (open[ty * TW + tx - 1]) exits++; if (open[(ty + 1) * TW + tx]) exits++; if (open[(ty - 1) * TW + tx]) exits++;
            if (exits == 1) deadEnds++;
        }
        steps = carve.Count;
    }
    static int Tile(int x0, int x1, int y0, int y1) => (y0 + y1 + 1) * TW + (x0 + x1 + 1);   // cell (x,y) → tile (2x+1, 2y+1); two cells → the wall tile between
    void DrawMaze()
    {
        int ox = (W - TW * TS) / 2, oy = (H - TH * TS) / 2;
        Fill(ox, oy, ox + TW * TS, oy + TH * TS, ROCK);
        int k = Mathf.Min(carve.Count, (int)shown);
        for (int i = 0; i < k; i++) { int tx = carve[i] % TW, ty = carve[i] / TW; Fill(ox + tx * TS, oy + ty * TS, ox + (tx + 1) * TS, oy + (ty + 1) * TS, FLOOR); }
        if (k > 0 && k < carve.Count) { int tx = carve[k - 1] % TW, ty = carve[k - 1] / TW; Fill(ox + tx * TS, oy + ty * TS, ox + (tx + 1) * TS, oy + (ty + 1) * TS, SUN); }   // the head of the walk
    }

    // ---- [5] AUTOTILE: four neighbour bits make an index 0..15; the tile draws its open faces ---
    void GenAutotile()
    {
        wall = new bool[AC * AR];
        float ox = Random.Range(0f, 100f), oy = Random.Range(0f, 100f);           // a seeded offset into Perlin space = seeded blobs
        for (int y = 0; y < AR; y++) for (int x = 0; x < AC; x++) wall[y * AC + x] = Mathf.PerlinNoise(ox + x * 0.18f, oy + y * 0.18f) > 0.5f;
        steps = 0;
    }
    bool IsWall(int x, int y) => x >= 0 && y >= 0 && x < AC && y < AR && wall[y * AC + x];
    void DrawAutotile()
    {
        for (int y = 0; y < AR; y++) for (int x = 0; x < AC; x++)
        {
            int X = x * AS, Y = y * AS;
            if (!wall[y * AC + x]) { Fill(X, Y, X + AS, Y + AS, ((x + y) & 1) == 0 ? FLOOR : FLOOR * 0.95f); continue; }
            int idx = (IsWall(x, y + 1) ? 1 : 0) | (IsWall(x + 1, y) ? 2 : 0) | (IsWall(x, y - 1) ? 4 : 0) | (IsWall(x - 1, y) ? 8 : 0);   // N=1 E=2 S=4 W=8
            Fill(X, Y, X + AS, Y + AS, ROCK);
            Color lip = new Color(0.36f, 0.32f, 0.46f);                              // an exposed face gets a lip; a shared face stays flat
            if ((idx & 1) == 0) Fill(X, Y + AS - 1, X + AS, Y + AS, lip);
            if ((idx & 2) == 0) Fill(X + AS - 1, Y, X + AS, Y + AS, lip);
            if ((idx & 4) == 0) Fill(X, Y, X + AS, Y + 1, lip);
            if ((idx & 8) == 0) Fill(X, Y, X + 1, Y + AS, lip);
            Glyph(X + 3, Y + 2, idx, DIM);                                             // the mask value, in hex, on the tile
        }
        // Unity spelling: a Tilemap with a Rule Tile (2D Tilemap Extras) does exactly this lookup;
        // the 16 (or 47, with corners) sprites are the same index into a sheet.
    }

    // ---- [6] SAVE & LOAD: the state IS the world; the version field is the contract ------------
    void GenWorld()
    {
        world = new SaveV2 { seed = seed, heroX = W * 0.5f, heroY = H * 0.5f };
        for (int i = 0; i < 5; i++) coinAt[i] = new Vector2(Random.Range(16f, W - 16f), Random.Range(16f, H - 16f));   // coin spots come from the seed
        heroTarget = coinAt[0]; steps = 0;
    }
    void TickWorld(float dt)
    {
        // an autopilot: walk to the nearest uncollected coin, take it, score, respawn them all when done
        int target = -1; float bestD = float.MaxValue;
        for (int i = 0; i < 5; i++) if (!world.coins[i]) { float d = Vector2.Distance(coinAt[i], new Vector2(world.heroX, world.heroY)); if (d < bestD) { bestD = d; target = i; } }
        if (target < 0) { for (int i = 0; i < 5; i++) world.coins[i] = false; return; }
        var pos = Vector2.MoveTowards(new Vector2(world.heroX, world.heroY), coinAt[target], 40f * dt);
        world.heroX = pos.x; world.heroY = pos.y;
        if (bestD < 4f) { world.coins[target] = true; world.score += 10; }
    }
    void Save()
    {
        string json = JsonUtility.ToJson(world, true);                                // prettyPrint: the text is the lesson
        slots[nextSlot] = json; lastJson = json;
        // a real save goes to disk: System.IO.File.WriteAllText(System.IO.Path.Combine(Application.persistentDataPath, $"slot{nextSlot}.json"), json);
        note = $"saved to slot {nextSlot} (version {world.version})"; nextSlot = (nextSlot + 1) % 3;
    }
    void Load(string json)
    {
        if (string.IsNullOrEmpty(json)) { note = "that slot is empty"; return; }
        int version = JsonUtility.FromJson<Header>(json).version;                     // read ONLY the version first — never trust the shape before you know it
        if (version >= 2) world = JsonUtility.FromJson<SaveV2>(json);
        else                                                                          // MIGRATION: the old shape in, the new shape out, missing fields defaulted
        {
            var old = JsonUtility.FromJson<SaveV1>(json);
            world = new SaveV2 { seed = old.seed, heroX = old.heroX, heroY = old.heroY, score = old.score };   // biome keeps its default, "meadow"
            for (int i = 0; i < 5; i++) world.coins[i] = ((old.coinMask >> i) & 1) == 1;                    // the bitmask unpacked into the bool array
            world.version = 2;
        }
        if (world.seed != seed) { seed = world.seed; Random.InitState(seed); for (int i = 0; i < 5; i++) coinAt[i] = new Vector2(Random.Range(16f, W - 16f), Random.Range(16f, H - 16f)); }   // the seed rebuilds the coin spots
        lastJson = json; note = version >= 2 ? $"loaded a version-{version} save" : $"loaded a version-{version} save and MIGRATED it to 2";
    }
    void DrawWorld()
    {
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) px[y * W + x] = Color.Lerp(new Color(0.20f, 0.30f, 0.16f), new Color(0.26f, 0.40f, 0.20f), ((x / 8 + y / 8) & 1));
        for (int i = 0; i < 5; i++) if (!world.coins[i]) Disc(coinAt[i].x, coinAt[i].y, 3f, SUN);
        Fill((int)world.heroX - 3, (int)world.heroY - 3, (int)world.heroX + 3, (int)world.heroY + 3, HERO);
        int s = world.score; for (int d = 0; d < 4; d++) { Glyph(W - 8 - d * 5, H - 8, s % 10, INK); s /= 10; }   // the score, in glyphs
        for (int i = 0; i < 3; i++) Fill(4 + i * 8, H - 6, 10 + i * 8, H - 2, slots[i] != null ? GOOD : DIM);      // three slots
    }

    // ---- the tiny painter -----------------------------------------------------------------------
    void Clear(Color c) { for (int i = 0; i < px.Length; i++) px[i] = c; }
    void Fill(int x0, int y0, int x1, int y1, Color c)
    {
        for (int y = Mathf.Max(0, y0); y < Mathf.Min(H, y1); y++) for (int x = Mathf.Max(0, x0); x < Mathf.Min(W, x1); x++)
            px[y * W + x] = c.a < 1f ? Color.Lerp(px[y * W + x], new Color(c.r, c.g, c.b), c.a) : c;
    }
    void HLine(int x0, int x1, int y, Color c) => Fill(x0, y, x1, y + 1, c);
    void VLine(int x, int y0, int y1, Color c) => Fill(x, y0, x + 1, y1, c);
    void Disc(float cx, float cy, float r, Color c)
    {
        for (int y = Mathf.Max(0, (int)(cy - r)); y <= Mathf.Min(H - 1, (int)(cy + r)); y++)
            for (int x = Mathf.Max(0, (int)(cx - r)); x <= Mathf.Min(W - 1, (int)(cx + r)); x++)
                if (Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(cx, cy)) < r) px[y * W + x] = c;
    }
    void Ring(float cx, float cy, float r, Color c)
    {
        for (int y = Mathf.Max(0, (int)(cy - r - 1)); y <= Mathf.Min(H - 1, (int)(cy + r + 1)); y++)
            for (int x = Mathf.Max(0, (int)(cx - r - 1)); x <= Mathf.Min(W - 1, (int)(cx + r + 1)); x++)
                if (Mathf.Abs(Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(cx, cy)) - r) < 0.7f) px[y * W + x] = c;
    }
    void Glyph(int x, int y, int digit, Color c)            // 3×5, rows top-down; texture rows run bottom-up, hence the flip
    {
        string g = GLYPH[Mathf.Clamp(digit, 0, 15)];
        for (int r = 0; r < 5; r++) for (int col = 0; col < 3; col++)
            if (g[r * 3 + col] == '1') { int X = x + col, Y = y + 4 - r; if (X >= 0 && Y >= 0 && X < W && Y < H) px[Y * W + X] = c; }
    }

    void OnGUI()
    {
        string[] names = { "",
            $"Poisson — Bridson disc scatter, r = {radius:0.0} px, {pts.Count} points (left) vs a naive uniform scatter (right) · click sets r",
            $"Caves — fill {FILLP:0.00}, rock if ≥ {RULE} of 8 neighbours, ×{PASSES} passes, then keep the largest region · click regrows",
            $"Bsp — {splitOrder.Count} splits → {rooms.Count} rooms → {corridors.Count} sibling corridors · click resplits",
            $"Maze — recursive backtracker, {MC}×{MR} cells, dead ends: {deadEnds} (Prim's would give many more) · click carves again",
            "Autotile — index = N·1 + E·2 + S·4 + W·8, drawn in hex on every wall tile · click toggles, drag paints",
            $"Save — JsonUtility, version {world.version} · S / click = save · L = load newest · M = load a version-1 save (migrates) · {note}" };
        GUI.Label(new Rect(10, 10, 1200, 22), $"WORLD WORKSHOP — keys 1–6 · R = next seed · seed {seed} · " + names[mode]);
        if (mode == 6) { GUI.Box(new Rect(10, 36, 300, 190), ""); GUI.Label(new Rect(16, 40, 290, 184), lastJson); }
    }
}
