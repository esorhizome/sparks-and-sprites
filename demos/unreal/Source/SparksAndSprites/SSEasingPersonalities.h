// MOVEMENT PERSONALITIES — one actor, eight souls.
// Personality is not what moves — it's the SHAPE of the speed. PosFor()
// maps journey-progress u (0→1) to a position; the actor replays it.
// Set Soul in the details panel (0–7), tick bLoop to replay forever.
// Chapter 05 of the book.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SSEasingPersonalities.generated.h"

UENUM()
enum class ESSSoul : uint8
{
	Human, Superhuman, Alien, Excited, Sad, Emotionless, Robot, Stately
};

UCLASS()
class ASSEasingPersonalities : public AActor
{
	GENERATED_BODY()

public:
	ASSEasingPersonalities();

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	ESSSoul Soul = ESSSoul::Human;

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	bool bLoop = true;

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float TravelDistance = 800.f;

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaTime) override;

private:
	FVector2D PosFor(float U) const;   // u (0→1) → (x across, y detour)
	float Clock = 0.f;
	FVector Origin;
	static float DurationFor(ESSSoul S);
};
