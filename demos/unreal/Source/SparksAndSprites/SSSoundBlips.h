// SOUND BLIPS — coin, laser, hit: synthesized from nothing.
// USoundWaveProcedural accepts raw PCM you generate on demand — the same
// sine arithmetic as the web AudioContext and Godot AudioStreamGenerator
// versions. Call PlayCoin()/PlayLaser()/PlayHit() from Blueprint or bind
// them to keys. Chapter 07 of the book.
// 2D: sound is dimensionless — this works verbatim in a Paper2D game or
// behind a UMG menu. The only spatial choice is whether to spawn the
// AudioComponent 2D (UGameplayStatics::PlaySound2D-style, UI blips) or at
// a world location for attenuation in the scene.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SSSoundBlips.generated.h"

class UAudioComponent;
class USoundWaveProcedural;

UCLASS()
class ASSSoundBlips : public AActor
{
	GENERATED_BODY()

public:
	ASSSoundBlips();

	UFUNCTION(BlueprintCallable, Category="SparksAndSprites") void PlayCoin();
	UFUNCTION(BlueprintCallable, Category="SparksAndSprites") void PlayLaser();
	UFUNCTION(BlueprintCallable, Category="SparksAndSprites") void PlayHit();

protected:
	virtual void BeginPlay() override;

private:
	static constexpr int32 Rate = 44100;
	UPROPERTY() UAudioComponent* Audio = nullptr;
	UPROPERTY() USoundWaveProcedural* Wave = nullptr;
	void Queue(const TArray<int16>& Samples);
};
