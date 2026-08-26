#include "SSParallax.h"

ASSParallax::ASSParallax()
{
	PrimaryActorTick.bCanEverTick = true;
}

void ASSParallax::BeginPlay()
{
	Super::BeginPlay();
	if (Tracked) TrackedHome = Tracked->GetActorLocation();
	for (FSSParallaxLayer& L : Layers)
		if (L.Layer) L.Home = L.Layer->GetActorLocation();
}

void ASSParallax::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	if (!Tracked) return;
	const FVector Offset = Tracked->GetActorLocation() - TrackedHome;
	for (const FSSParallaxLayer& L : Layers)
		if (L.Layer)
			// ← the entire trick, once per layer
			L.Layer->SetActorLocation(L.Home + Offset * L.Factor);
}
