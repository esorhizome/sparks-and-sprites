# Sprite basics — load, attach, place

The book's three verbs, in Unreal's two 2-D dialects:

**Paper2D** (in-world sprites):
1. Import a texture (or use any small image) → right-click → *Create Sprite*.
2. Load: the sprite asset. Attach: a `PaperSpriteComponent` on an actor.
   Place: `SetActorLocation` / `SetRelativeLocation`.
3. "Moving a sprite" = changing those numbers per tick — a sine bob is
   `Loc.Z = sin(Time × 2) × 30`.

**UMG** (screen-space images):
1. Widget Blueprint → add an **Image**, set the texture.
2. Place with Canvas slot position; move by animating that position.

C++ one-liner flavour (Paper2D):
```cpp
UPaperSpriteComponent* S = NewObject<UPaperSpriteComponent>(Owner);
S->SetSprite(SpriteAsset);
S->RegisterComponent();
S->SetRelativeLocation(FVector(0, X, Y));   // place = the whole secret
```
Chapter 02 shows the same recipe in all four accents.
