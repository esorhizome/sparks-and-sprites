#include "SSTraumaShake.h"
#include "GameFramework/Actor.h"

USSTraumaShake::USSTraumaShake()
{
	PrimaryComponentTick.bCanEverTick = true;
}

void USSTraumaShake::AddTrauma(float Amount)
{
	Trauma = FMath::Min(1.f, Trauma + Amount);
}

void USSTraumaShake::TickComponent(float DeltaTime, ELevelTick TickType,
	FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	AActor* Owner = GetOwner();
	if (!Owner) return;
	if (!bCapturedBase)
	{
		BaseLocation = Owner->GetActorLocation();
		bCapturedBase = true;
	}

	Clock += DeltaTime;
	Trauma = FMath::Max(0.f, Trauma - DeltaTime * DecayPerSecond);   // rule 3
	const float Shake = Trauma * Trauma;                             // rule 1

	// rule 2: three independent smooth-noise channels
	const float NX = FMath::PerlinNoise1D(Clock * 25.f);
	const float NY = FMath::PerlinNoise1D(Clock * 25.f + 100.f);
	const float NR = FMath::PerlinNoise1D(Clock * 20.f + 200.f);

	Owner->SetActorLocation(BaseLocation +
		FVector(0.f, NX * MaxOffset * Shake, NY * MaxOffset * Shake));
	FRotator R = Owner->GetActorRotation();
	R.Roll = NR * MaxRollDegrees * Shake;
	Owner->SetActorRotation(R);
}
