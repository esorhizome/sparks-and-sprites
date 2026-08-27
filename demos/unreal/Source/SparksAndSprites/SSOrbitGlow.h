// ORBIT & GLOW — drag to orbit + an emissive centrepiece.
// Babylon ships ArcRotateCamera; Unreal ships the rig prebuilt too:
// a SpringArm (the stick) on a Pawn, rotated by mouse drag. The glow is an
// emissive material (HDR emissive colour) — bloom is on by default.
// Possess this pawn (Auto Possess Player = Player 0) and drag the mouse.
// 2D: orbiting is the one verb 2D cannot truly do — the 2D cousins are
// pan and zoom: keep the SpringArm but lock rotation, drag to move the
// target (pan) and scroll TargetArmLength (zoom) over a Paper2D scene.
// The glow half is dimensionless: the same HDR emissive material on a
// sprite blooms identically under an ortho camera.
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
