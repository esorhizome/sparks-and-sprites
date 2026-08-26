#include "SSScrollUV.h"
#include "Components/StaticMeshComponent.h"
#include "Materials/MaterialInstanceDynamic.h"

ASSScrollUV::ASSScrollUV()
{
	PrimaryActorTick.bCanEverTick = true;
	Plane = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Plane"));
	RootComponent = Plane;
	// assign a plane mesh + the scroll material (with an "Offset" scalar
	// parameter) in the editor; this class only drives the number.
}

void ASSScrollUV::BeginPlay()
{
	Super::BeginPlay();
	if (Plane->GetMaterial(0))
		Mid = Plane->CreateAndSetMaterialInstanceDynamic(0);
}

void ASSScrollUV::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	Offset = FMath::Fmod(Offset + TilesPerSecond * DeltaTime, 1.f);   // ← the line
	if (Mid) Mid->SetScalarParameterValue(TEXT("Offset"), Offset);
}
