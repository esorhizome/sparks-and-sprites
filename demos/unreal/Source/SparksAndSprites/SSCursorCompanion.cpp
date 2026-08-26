#include "SSCursorCompanion.h"
#include "Components/StaticMeshComponent.h"
#include "Kismet/GameplayStatics.h"
#include "NiagaraFunctionLibrary.h"
#include "NiagaraSystem.h"

ASSCursorCompanion::ASSCursorCompanion()
{
	PrimaryActorTick.bCanEverTick = true;
	Body = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Body"));
	RootComponent = Body;
}

void ASSCursorCompanion::BeginPlay()
{
	Super::BeginPlay();
	if (APlayerController* PC = UGameplayStatics::GetPlayerController(this, 0))
		PC->bShowMouseCursor = false;      // …because we draw a better one below
}

void ASSCursorCompanion::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	APlayerController* PC = UGameplayStatics::GetPlayerController(this, 0);
	if (!PC) return;

	// deproject the mouse onto our working plane
	FVector Origin, Dir;
	if (PC->DeprojectMousePositionToWorld(Origin, Dir) && !FMath::IsNearlyZero(Dir.Z))
	{
		const float T = (PlaneZ - Origin.Z) / Dir.Z;
		const FVector Target = Origin + Dir * T;
		// the chase: the lag is the personality
		SetActorLocation(FMath::Lerp(GetActorLocation(), Target,
			FMath::Min(1.f, ChaseSpeed * DeltaTime)));
	}

	Squish = FMath::Max(0.f, Squish - DeltaTime * 3.f);
	Body->SetRelativeScale3D(FVector(1 + Squish * 0.45f, 1 + Squish * 0.45f, 1 - Squish * 0.45f));

	if (PC->WasInputKeyJustPressed(EKeys::LeftMouseButton))
	{
		Squish = 1.f;                      // the flinch
		if (PressPop)                      // the pop
			UNiagaraFunctionLibrary::SpawnSystemAtLocation(this, PressPop, GetActorLocation());
	}
}
