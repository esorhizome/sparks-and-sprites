// FLIPBOOK VFX — bake a transparent sprite sheet in C++, play it as SubUV.
// The web folio (docs/flipbook.html) bakes 26 sheets from code; this actor
// bakes one ambassador (the Burst) into a transient UTexture2D at BeginPlay
// — no imported asset anywhere — and plays it back by driving one scalar
// parameter, "Frame", on a SubUV material. Unreal already speaks flipbook
// fluently; this template shows the runtime-baked end of the vocabulary.
//
// Material setup (once, in the editor) — the SubUV playback graph:
//   Texture Sampler (this actor's sheet, addressing Clamp)
//   → SubUV_Function (or by hand: UV.x = (frac(Frame)/Frames + TexCoord.x)
//     / 1, offsetting U by Frame/Frames) with "Frame" a Scalar Parameter
//   → Emissive (additive blend mode — bursts are light) + Opacity from A.
//   Blend Mode: Additive. Shading Model: Unlit.
// Assign that material to this actor's plane; the C++ below feeds it the
// texture and steps "Frame" with the one-shot index line:
//   Frame = min(N−1, ⌊(t−t₀)·fps⌋)          (a loop would use fmod instead)
//
// Where Unreal's OTHER flipbook machinery lives (chapter 15 has the map):
//   • Paper2D: import a sheet → Extract Sprites → right-click → Create
//     Flipbook. UPaperFlipbookComponent plays it. THE 2D route.
//   • Niagara: Sprite Renderer → Sub UV, drive "SubImage Index" 0..N over
//     particle life — every particle plays the flipbook.
//   • Materials: the SubUV_Function graph above, on anything.
// 2D: this same actor works under an orthographic camera unchanged; or use
// the Paper2D route above — a PaperFlipbook is this mechanism as an asset.
// Chapter 15 of the book.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SSFlipbookVfx.generated.h"

UCLASS()
class ASSFlipbookVfx : public AActor
{
	GENERATED_BODY()

public:
	ASSFlipbookVfx();

	UPROPERTY(VisibleAnywhere, Category="SparksAndSprites")
	UStaticMeshComponent* Plane;

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	int32 Frames = 12;               // cells in the sheet (one row)

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	int32 CellSize = 96;             // px per cell

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float Fps = 20.f;                // reading speed — the sheet never changes

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float ReplayDelay = 1.1f;        // polite pause before the one-shot replays

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaTime) override;

private:
	void BakeSheet();                // draw every frame ONCE, into pixels
	void PaintBurst(TArray<FColor>& Px, int32 Frame) const;   // one cell

	UPROPERTY()
	UTexture2D* Sheet = nullptr;

	UPROPERTY()
	UMaterialInstanceDynamic* Mid = nullptr;

	float PlayT = 0.f;               // t − t₀ for the one-shot index line
};
