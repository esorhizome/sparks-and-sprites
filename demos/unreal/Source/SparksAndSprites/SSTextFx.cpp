#include "SSTextFx.h"
#include "Components/TextRenderComponent.h"

namespace
{
	const TCHAR* Glyphs = TEXT("abcdefghjkmnpqrstuvwxyz023456789#%&@+=?");
}

ASSTextFx::ASSTextFx()
{
	PrimaryActorTick.bCanEverTick = true;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

void ASSTextFx::BeginPlay()
{
	Super::BeginPlay();
	BuildLetters();
}

void ASSTextFx::BuildLetters()
{
	// one TextRender per letter — the whole trick, same as every grimoire port
	const int32 N = Phrase.Len();
	for (int32 i = 0; i < N; ++i)
	{
		UTextRenderComponent* L = NewObject<UTextRenderComponent>(this);
		L->RegisterComponent();
		L->AttachToComponent(RootComponent, FAttachmentTransformRules::KeepRelativeTransform);
		L->SetText(FText::FromString(Phrase.Mid(i, 1)));
		L->SetHorizontalAlignment(EHTA_Center);
		L->SetVerticalAlignment(EVRTA_TextCenter);
		L->SetWorldSize(42.f);
		L->SetTextRenderColor(FColor(232, 229, 244));
		// the resting slot: centred line along Y (Unreal's "screen x" for a default camera)
		L->SetRelativeLocation(FVector(0.f, (i - (N - 1) * 0.5f) * LetterSpacing, 0.f));
		Letters.Add(L);
	}
	if (Mode == ESSTextFxMode::StackExtrude)
	{
		for (int32 i = 0; i < N; ++i)
			for (int32 d = 0; d < ExtrudeDepth; ++d)
			{
				UTextRenderComponent* E = NewObject<UTextRenderComponent>(this);
				E->RegisterComponent();
				E->AttachToComponent(RootComponent, FAttachmentTransformRules::KeepRelativeTransform);
				E->SetText(FText::FromString(Phrase.Mid(i, 1)));
				E->SetHorizontalAlignment(EHTA_Center);
				E->SetVerticalAlignment(EVRTA_TextCenter);
				E->SetWorldSize(42.f);
				const uint8 V = uint8(40 + (ExtrudeDepth - d) * 6);      // darker with depth
				E->SetTextRenderColor(FColor(V, V, uint8(V * 1.5f)));
				Extrusion.Add(E);
			}
	}
}

FString ASSTextFx::ScrambleGlyph() const
{
	const FString G(Glyphs);
	return G.Mid(FMath::RandRange(0, G.Len() - 1), 1);
}

void ASSTextFx::TriggerPress()
{
	Press = 1.f;
	if (Mode == ESSTextFxMode::Typewriter || Mode == ESSTextFxMode::Decoder)
	{
		Shown = 0;                          // replay the reveal — the classic press reaction
		Clock = 0.f;
	}
}

void ASSTextFx::SetMode(ESSTextFxMode NewMode)
{
	Mode = NewMode;
	Shown = 0;
	Clock = 0.f;
	// StackExtrude's copies are built lazily; simplest honest reset:
	for (UTextRenderComponent* E : Extrusion) if (E) E->DestroyComponent();
	Extrusion.Empty();
	if (Mode == ESSTextFxMode::StackExtrude && Letters.Num() > 0)
	{
		const int32 N = Letters.Num();
		for (int32 i = 0; i < N; ++i)
			for (int32 d = 0; d < ExtrudeDepth; ++d)
			{
				UTextRenderComponent* E = NewObject<UTextRenderComponent>(this);
				E->RegisterComponent();
				E->AttachToComponent(RootComponent, FAttachmentTransformRules::KeepRelativeTransform);
				E->SetText(FText::FromString(Phrase.Mid(i, 1)));
				E->SetHorizontalAlignment(EHTA_Center);
				E->SetVerticalAlignment(EVRTA_TextCenter);
				E->SetWorldSize(42.f);
				const uint8 V = uint8(40 + (ExtrudeDepth - d) * 6);
				E->SetTextRenderColor(FColor(V, V, uint8(V * 1.5f)));
				Extrusion.Add(E);
			}
	}
}

void ASSTextFx::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	Clock += DeltaTime;
	Press = FMath::Max(0.f, Press - DeltaTime);
	const int32 N = Letters.Num();
	if (N == 0) return;

	// the reveal clocks (typewriter & decoder share one, different cadences)
	TypeTimer += DeltaTime;
	const float Cadence = Mode == ESSTextFxMode::Decoder ? 0.22f : TypeCadence;
	if (TypeTimer > Cadence && Shown < N) { TypeTimer = 0.f; ++Shown; }
	ChurnTimer += DeltaTime;
	const bool bChurn = ChurnTimer > 0.05f;
	if (bChurn) ChurnTimer = 0.f;
	if ((Mode == ESSTextFxMode::Typewriter || Mode == ESSTextFxMode::Decoder)
		&& Shown >= N && Clock > 6.f) { Shown = 0; Clock = 0.f; }        // retype forever

	for (int32 i = 0; i < N; ++i)
	{
		UTextRenderComponent* L = Letters[i];
		const FVector Home(0.f, (i - (N - 1) * 0.5f) * LetterSpacing, 0.f);
		// reset, then let the mode write its offsets — layout() first, decide per letter
		FVector Loc = Home;
		FRotator Rot = FRotator::ZeroRotator;
		float Scale = 1.f;
		FColor Col(232, 229, 244);
		L->SetVisibility(true);
		L->SetText(FText::FromString(Phrase.Mid(i, 1)));

		switch (Mode)
		{
		case ESSTextFxMode::Typewriter:    // "does it exist yet" is the only dial
			L->SetVisibility(i < Shown);
			break;
		case ESSTextFxMode::Wave:          // position + lean from one phase
			Loc.Z += FMath::Sin(Clock * 2.4f - i * 0.65f) * 7.f * (1.f + Press * 1.6f);
			Rot.Roll = FMath::Cos(Clock * 2.4f - i * 0.65f) * -8.f;
			break;
		case ESSTextFxMode::Decoder:       // wrong glyph until your turn comes
			L->SetVisibility(Phrase.Mid(i, 1) != TEXT(" "));
			if (i >= Shown)
			{
				if (bChurn) L->SetText(FText::FromString(ScrambleGlyph()));
				Col = FColor(150, 220, 180);
			}
			break;
		case ESSTextFxMode::Heartbeat:     // the lub-dub, scaled about the phrase centre
		{
			const float Beat = FMath::Fmod(Clock * (Press > 0.f ? 150.f : 62.f) / 60.f, 1.f);
			const float K = FMath::Exp(-Beat * 14.f)
				+ (Beat > 0.28f ? 0.72f * FMath::Exp(-(Beat - 0.28f) * 14.f) : 0.f);
			Scale = 1.f + K * 0.16f;
			Loc.Y *= Scale;                // centres spread with the swell
			break;
		}
		case ESSTextFxMode::ColorRide:     // hue is just (time + index) wrapped
		{
			const FLinearColor H = FLinearColor::MakeFromHSV8(
				uint8(FMath::Fmod(Clock * 42.f + i * 25.f, 255.f)), 180, 255);
			Col = H.ToFColor(false);
			break;
		}
		case ESSTextFxMode::Shiver:        // fine tremble + the travelling shiver
		{
			const float WaveK = FMath::Max(0.f, FMath::Sin(Press * PI)) * 3.f;
			Loc.Y += FMath::FRandRange(-1.f, 1.f) * (0.5f + WaveK);
			Loc.Z += FMath::FRandRange(-1.f, 1.f) * (0.5f + WaveK);
			break;
		}
		case ESSTextFxMode::StackExtrude:  // depth is the new dial: the queue trails in +X
		{
			const float Depth = 6.f + FMath::Sin(Clock * PI / 2.f) * 2.f + Press * 10.f;
			for (int32 d = 0; d < ExtrudeDepth; ++d)
			{
				const int32 Idx = i * ExtrudeDepth + d;
				if (Extrusion.IsValidIndex(Idx) && Extrusion[Idx])
					Extrusion[Idx]->SetRelativeLocation(Home
						+ FVector(4.f, 0.9f, -0.9f) * (d + 1) * Depth * 0.5f);
			}
			break;
		}
		}
		L->SetRelativeLocation(Loc);
		L->SetRelativeRotation(Rot);
		L->SetRelativeScale3D(FVector(Scale));
		L->SetTextRenderColor(Col);
	}
}
