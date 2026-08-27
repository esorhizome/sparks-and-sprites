// THE GLYPH GRIMOIRE — one phrase, many text effects, Unreal spelling.
// An actor that spawns one UTextRenderComponent PER LETTER of its phrase —
// once each letter is its own component, every grimoire family is just
// math on relative location/rotation/scale/colour, exactly like the web
// kit's layout() loop. Pick a mode in the details panel (or call SetMode
// from Blueprint) and the idle loop runs on its own; TriggerPress is the
// press reaction, same anatomy as all 104 on the web/Godot grimoire.
//
// Modes: Typewriter (letter-by-letter reveal), Wave (a rolling sine with
// the lean), Decoder (wrong glyphs churn, resolving left to right),
// Heartbeat (the lub-dub swell), ColorRide (hue slides down the line),
// Shiver (fine tremble + travelling shivers), StackExtrude (per-letter
// dark copies trailing in depth — the 3D-only dial).
//
// 3D vs 2D, plainly:
//  · This actor IS the 3D spelling (and the "2D look" spelling: put it in
//    front of an orthographic camera and lock Y — TextRender quads are
//    flat, so ortho + fixed depth reads as pure 2D).
//  · The TRUE 2D spelling in Unreal is UMG: one UTextBlock per letter in
//    a HorizontalBox (or a RichTextBlock decorator), animated by widget
//    Transform (RenderTransform: translation/scale/shear/angle) from
//    NativeTick or a Blueprint timeline. Same dials, same numbers —
//    recipes/text-fx.md walks every family through both routes.
// The full 104 live on the web page (text-fx.html) and in the Godot
// project (demos/godot/scenes/textfx/); chapter 13 teaches the anatomy.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SSTextFx.generated.h"

class UTextRenderComponent;

UENUM(BlueprintType)
enum class ESSTextFxMode : uint8
{
	Typewriter, Wave, Decoder, Heartbeat, ColorRide, Shiver, StackExtrude
};

UCLASS()
class ASSTextFx : public AActor
{
	GENERATED_BODY()

public:
	ASSTextFx();

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	FString Phrase = TEXT("just this");    // everything below measures, nothing hard-codes

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	ESSTextFxMode Mode = ESSTextFxMode::Typewriter;

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float LetterSpacing = 34.f;            // world units between letter centres

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float TypeCadence = 0.12f;             // seconds per letter (the typewriter's whole soul)

	UPROPERTY(EditAnywhere, Category="SparksAndSprites|StackExtrude")
	int32 ExtrudeDepth = 6;                // dark copies per letter, trailing in +X (camera depth)

	// --- the press reaction: replays reveals, races the heart, shivers the line ---
	UFUNCTION(BlueprintCallable, Category="SparksAndSprites") void TriggerPress();
	UFUNCTION(BlueprintCallable, Category="SparksAndSprites") void SetMode(ESSTextFxMode NewMode);

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaTime) override;

private:
	void BuildLetters();
	FString ScrambleGlyph() const;

	UPROPERTY() TArray<UTextRenderComponent*> Letters;
	UPROPERTY() TArray<UTextRenderComponent*> Extrusion;   // Letters.Num() * ExtrudeDepth, StackExtrude only
	float Clock = 0.f;
	float Press = 0.f;                     // 1 at the press, decays — most reactions read this
	int32 Shown = 0;                       // typewriter / decoder progress
	float TypeTimer = 0.f;
	float ChurnTimer = 0.f;
};
