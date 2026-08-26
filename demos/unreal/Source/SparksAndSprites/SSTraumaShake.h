// SCREEN SHAKE — the kind version: trauma², smooth noise, fast calm.
// A component you attach to any camera-owning actor. Call AddTrauma(0.3f)
// for a small hit, AddTrauma(0.7f) for a big one.
// Rule 1: shake by trauma SQUARED (small hits whisper, big hits roar).
// Rule 2: sample SMOOTH noise (FMath::PerlinNoise1D), never random jumps.
// Rule 3: decay fast — the calm is what makes the shake readable.
// (Unreal also ships this idea packaged: UPerlinNoiseCameraShakePattern.
//  This template writes it out so the three rules stay visible.)
// Chapter 06 of the book.
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "SSTraumaShake.generated.h"

UCLASS(ClassGroup=(SparksAndSprites), meta=(BlueprintSpawnableComponent))
class USSTraumaShake : public UActorComponent
{
	GENERATED_BODY()

public:
	USSTraumaShake();

	UFUNCTION(BlueprintCallable, Category="SparksAndSprites")
	void AddTrauma(float Amount);

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float MaxOffset = 30.f;      // world units at full trauma

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float MaxRollDegrees = 4.f;

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float DecayPerSecond = 1.1f; // rule 3

protected:
	virtual void TickComponent(float DeltaTime, ELevelTick TickType,
		FActorComponentTickFunction* ThisTickFunction) override;

private:
	float Trauma = 0.f;
	float Clock = 0.f;
	FVector BaseLocation;
	bool bCapturedBase = false;
};
