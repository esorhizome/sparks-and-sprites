// RESPONSIVE CURSOR — a companion that CHASES the pointer.
// Hide the OS cursor only because we draw a better one (never hide it and
// offer nothing back). The chase lag is deliberate: easing into latency
// looks alive; fighting it looks laggy. Assign a small emissive sphere as
// the Body, and (optionally) a Niagara system for the press-pop.
// Chapter 12 of the book.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SSCursorCompanion.generated.h"

class UNiagaraSystem;

UCLASS()
class ASSCursorCompanion : public AActor
{
	GENERATED_BODY()

public:
	ASSCursorCompanion();

	UPROPERTY(VisibleAnywhere, Category="SparksAndSprites")
	UStaticMeshComponent* Body;           // a small emissive sphere reads best

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	UNiagaraSystem* PressPop = nullptr;   // optional: a burst on click

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float ChaseSpeed = 12.f;              // x += (target − x) · speed · dt

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float PlaneZ = 0.f;                   // the world plane the companion lives on

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaTime) override;

private:
	float Squish = 0.f;                   // the flinch on press
};
