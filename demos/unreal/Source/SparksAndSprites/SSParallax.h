// PARALLAX — depth from three multiplications. You are the camera.
// Register any number of layers (scene components or child actors) each
// with a factor; every tick each layer moves by CameraOffset × Factor.
// Far layers get small factors, near layers get big ones — the GAP between
// the factors is the depth. Chapter 04 of the book.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SSParallax.generated.h"

USTRUCT()
struct FSSParallaxLayer
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere)
	AActor* Layer = nullptr;

	UPROPERTY(EditAnywhere)
	float Factor = 0.5f;       // 0.1 = far, 0.9 = near

	FVector Home = FVector::ZeroVector;
};

UCLASS()
class ASSParallax : public AActor
{
	GENERATED_BODY()

public:
	ASSParallax();

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	TArray<FSSParallaxLayer> Layers;

	// what drives the parallax: the tracked actor's sideways travel
	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	AActor* Tracked = nullptr;

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaTime) override;

private:
	FVector TrackedHome;
};
