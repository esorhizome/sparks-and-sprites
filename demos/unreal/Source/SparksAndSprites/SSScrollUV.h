// INFINITE SCROLL — the one-line UV trick, Unreal spelling.
// The material does it natively with a Panner node (TexCoord → Panner
// (SpeedX) → BaseColor, texture sampler set to Wrap). This actor shows the
// C++ half: driving a scalar parameter on a Material Instance Dynamic, so
// gameplay can change the speed (or scrub the offset) at runtime.
//
// Material setup (once, in the editor):
//   TexCoord → Add( TexCoord, AppendVector(Offset, 0) ) → Frac → sampler UV
//   where "Offset" is a Scalar Parameter. Sampler addressing: Wrap.
// Chapter 04 of the book.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SSScrollUV.generated.h"

UCLASS()
class ASSScrollUV : public AActor
{
	GENERATED_BODY()

public:
	ASSScrollUV();

	UPROPERTY(VisibleAnywhere, Category="SparksAndSprites")
	UStaticMeshComponent* Plane;

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float TilesPerSecond = 0.22f;    // keep two layers far apart — the gap is the depth

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaTime) override;

private:
	UPROPERTY()
	UMaterialInstanceDynamic* Mid = nullptr;
	float Offset = 0.f;
};
