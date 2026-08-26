// ORBIT & GLOW — drag to orbit + an emissive centrepiece.
// Babylon ships ArcRotateCamera; Unreal ships the rig prebuilt too:
// a SpringArm (the stick) on a Pawn, rotated by mouse drag. The glow is an
// emissive material (HDR emissive colour) — bloom is on by default.
// Possess this pawn (Auto Possess Player = Player 0) and drag the mouse.
// Chapter 11 of the book.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "SSOrbitGlow.generated.h"

class USpringArmComponent;
class UCameraComponent;

UCLASS()
class ASSOrbitGlow : public APawn
{
	GENERATED_BODY()

public:
	ASSOrbitGlow();

	UPROPERTY(VisibleAnywhere, Category="SparksAndSprites")
	UStaticMeshComponent* Centrepiece;    // assign a torus mesh + emissive material

	UPROPERTY(VisibleAnywhere, Category="SparksAndSprites")
	USpringArmComponent* Arm;             // the camera-on-a-stick

	UPROPERTY(VisibleAnywhere, Category="SparksAndSprites")
	UCameraComponent* Camera;

protected:
	virtual void Tick(float DeltaTime) override;
};
