#include "SSFlipbookVfx.h"
#include "Components/StaticMeshComponent.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Engine/Texture2D.h"

ASSFlipbookVfx::ASSFlipbookVfx()
{
	PrimaryActorTick.bCanEverTick = true;
	Plane = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Plane"));
	RootComponent = Plane;
	// assign a plane mesh + the SubUV material (see the header) in the
	// editor; this class bakes the texture and drives the "Frame" number.
}

void ASSFlipbookVfx::BeginPlay()
{
	Super::BeginPlay();
	BakeSheet();
	if (Plane->GetMaterial(0))
	{
		Mid = Plane->CreateAndSetMaterialInstanceDynamic(0);
		Mid->SetTextureParameterValue(TEXT("Sheet"), Sheet);
		Mid->SetScalarParameterValue(TEXT("Frames"), Frames);
	}
}

void ASSFlipbookVfx::BakeSheet()
{
	const int32 W = Frames * CellSize, H = CellSize;
	// A transient texture: born in code, never an asset. BGRA8, one mip.
	Sheet = UTexture2D::CreateTransient(W, H, PF_B8G8R8A8);
	Sheet->SRGB = true;
	Sheet->Filter = TF_Bilinear;

	TArray<FColor> Px;
	Px.Init(FColor(0, 0, 0, 0), W * H);          // THE point: transparent
	TArray<FColor> Cell;
	for (int32 i = 0; i < Frames; i++)
	{
		Cell.Init(FColor(0, 0, 0, 0), CellSize * CellSize);
		PaintBurst(Cell, i);                     // one frame, cell-local
		for (int32 y = 0; y < CellSize; y++)     // copy the cell into column i
			for (int32 x = 0; x < CellSize; x++)
				Px[y * W + i * CellSize + x] = Cell[y * CellSize + x];
	}

	void* Data = Sheet->GetPlatformData()->Mips[0].BulkData.Lock(LOCK_READ_WRITE);
	FMemory::Memcpy(Data, Px.GetData(), Px.Num() * sizeof(FColor));
	Sheet->GetPlatformData()->Mips[0].BulkData.Unlock();
	Sheet->UpdateResource();
}

// The Burst, cell-local: twelve rays race outward and die. Additive glows
// are approximated by summing into the pixel — the material's Additive
// blend does the scene-side half at playback.
void ASSFlipbookVfx::PaintBurst(TArray<FColor>& Px, int32 Frame) const
{
	const float k = Frame / (Frames - 1.f);      // 0..1 inclusive — a one-shot;
	const float C = CellSize / 2.f;              // the LAST frame paints nothing

	auto Glow = [&](float cx, float cy, float r, FVector Col, float a)
	{
		const int32 x0 = FMath::Max(0, (int32)(cx - r)), x1 = FMath::Min(CellSize - 1, (int32)(cx + r));
		const int32 y0 = FMath::Max(0, (int32)(cy - r)), y1 = FMath::Min(CellSize - 1, (int32)(cy + r));
		for (int32 y = y0; y <= y1; y++)
			for (int32 x = x0; x <= x1; x++)
			{
				const float d = FMath::Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) / FMath::Max(r, 0.5f);
				if (d >= 1.f) continue;
				const float w = (1 - d) * (1 - d) * a;
				FColor& P = Px[y * CellSize + x];
				P.R = (uint8)FMath::Min(255.f, P.R + Col.X * 255.f * w);
				P.G = (uint8)FMath::Min(255.f, P.G + Col.Y * 255.f * w);
				P.B = (uint8)FMath::Min(255.f, P.B + Col.Z * 255.f * w);
				P.A = (uint8)FMath::Min(255.f, P.A + 255.f * w);
			}
	};

	if (k < 0.22f)                               // the birth flash
		Glow(C, C, 16 * (1 - k / 0.22f), FVector(0.96f, 0.95f, 0.86f), 0.95f);
	for (int32 j = 0; j < 12; j++)               // the rays — deterministic,
	{                                            // same sheet every bake
		const float a = j / 12.f * 2 * PI + FMath::Fmod(j * 0.61f, 0.3f);
		const float d0 = FMath::Pow(k, 0.65f) * 34;
		for (float d = d0; d < d0 + (1 - k) * 9 + 2; d += 1.5f)
			Glow(C + FMath::Cos(a) * d, C + FMath::Sin(a) * d,
				2.4f * (1 - k * 0.6f), FVector(0.96f, 0.63f, 0.35f), (1 - k) * 0.8f);
	}
}

void ASSFlipbookVfx::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	PlayT += DeltaTime;
	// the one-shot index line — the entire playback technology:
	const int32 i = FMath::Min(Frames - 1, (int32)(PlayT * Fps));
	if (Mid) Mid->SetScalarParameterValue(TEXT("Frame"), i);
	if (PlayT > Frames / Fps + ReplayDelay) PlayT = 0.f;   // polite replay
}
