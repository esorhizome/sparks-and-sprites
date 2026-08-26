#include "SSCubeVfx.h"
#include "Components/StaticMeshComponent.h"
#include "Components/PointLightComponent.h"
#include "NiagaraFunctionLibrary.h"
#include "NiagaraComponent.h"
#include "NiagaraSystem.h"

ASSCubeVfx::ASSCubeVfx()
{
	PrimaryActorTick.bCanEverTick = true;
	Cube = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Cube"));
	RootComponent = Cube;

	HaloRing = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("HaloRing"));
	HaloRing->SetupAttachment(nullptr);   // detached on purpose: it FOLLOWS, not rides
	HaloRing->SetUsingAbsoluteLocation(true);

	HaloLight = CreateDefaultSubobject<UPointLightComponent>(TEXT("HaloLight"));
	HaloLight->SetupAttachment(HaloRing);
	HaloLight->SetLightColor(FLinearColor(1.f, 0.92f, 0.67f));
	HaloLight->SetIntensity(1200.f);
	HaloLight->SetAttenuationRadius(400.f);
}

void ASSCubeVfx::BeginPlay()
{
	Super::BeginPlay();
	Origin = GetActorLocation();
	HaloX = Origin.Y;
	if (AuraFX)                            // the idle loop that never stops
		UNiagaraFunctionLibrary::SpawnSystemAttached(AuraFX, Cube, NAME_None,
			FVector::ZeroVector, FRotator::ZeroRotator,
			EAttachLocation::KeepRelativeOffset, false);
}

void ASSCubeVfx::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	Clock += DeltaTime;

	// --- the patrol: the same stroll as every codex, with the honest lean ---
	const float NY = Origin.Y + FMath::Sin(Clock * 0.55f) * PatrolRadius;
	FVector Loc = GetActorLocation();
	Loc.Y = NY;
	SetActorLocation(Loc);
	SetActorRotation(FRotator(0.f, 0.f, -FMath::Cos(Clock * 0.55f) * 5.f));

	// --- the following halo: lag + bob + the ±3% breath ---
	const bool bHalo = bHaloEnabled && HaloRing;
	HaloRing->SetVisibility(bHalo);
	HaloLight->SetVisibility(bHalo);
	if (bHalo)
	{
		HaloX = FMath::Lerp(HaloX, NY, FMath::Min(1.f, 5.f * DeltaTime));   // the loyal lag
		HaloPulse = FMath::Max(0.f, HaloPulse - DeltaTime * 1.6f);
		const float Breath = 1.f + 0.03f * FMath::Sin(Clock * 2.f * PI / 3.f);
		HaloRing->SetWorldLocation(FVector(Loc.X, HaloX,
			Loc.Z + 120.f + FMath::Sin(Clock * 1.2f) * 4.f));
		HaloRing->SetWorldScale3D(FVector(Breath + HaloPulse * 0.3f,
			Breath + HaloPulse * 0.3f, 0.06f));                              // the y-squash IS the halo
		HaloLight->SetIntensity(1200.f + HaloPulse * 2400.f);
	}
}

void ASSCubeVfx::TriggerFireburst()
{
	if (FireburstFX)
		UNiagaraFunctionLibrary::SpawnSystemAtLocation(this, FireburstFX, GetActorLocation());
}

void ASSCubeVfx::TriggerWaterhose()
{
	if (WaterhoseFX)                       // aimed the way the cube is walking
		UNiagaraFunctionLibrary::SpawnSystemAtLocation(this, WaterhoseFX,
			GetActorLocation() + FVector(0, 0, 40),
			FRotator(-35.f, GetVelocity().Y >= 0 ? 90.f : -90.f, 0.f));
}

void ASSCubeVfx::TriggerSkyBolt(FVector WorldPoint)
{
	if (SkyBoltFX)                         // the strike lands where you asked
		UNiagaraFunctionLibrary::SpawnSystemAtLocation(this, SkyBoltFX, WorldPoint);
}

void ASSCubeVfx::PulseHalo()
{
	HaloPulse = 1.f;
}
