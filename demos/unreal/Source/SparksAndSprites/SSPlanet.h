// PLANET — a noise-displaced world from a ProceduralMeshComponent.
// Build a UV sphere in code, push each vertex outward by noise (mountains
// rise, seas stay round), colour by height, hand it to the mesh component,
// spin it slowly. The same recipe as the three.js / Godot / Unity versions.
// Requires "ProceduralMeshComponent" in your module's dependency list.
// 2D: a genuinely 3D demo — the honest 2D spellings are (a) render this
// planet to a SceneCaptureComponent2D and show the RenderTarget in UMG or
// on a sprite (a spinning planet in a 2D game's sky), or (b) fake it flat:
// a disc sprite with a scrolling noise material and a shaded rim, which is
// how 2D games have always drawn planets. Both are noted in chapter 11.
// Chapter 11 of the book.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ProceduralMeshComponent.h"
#include "SSPlanet.generated.h"

UCLASS()
class ASSPlanet : public AActor
{
	GENERATED_BODY()

public:
	ASSPlanet();

	UPROPERTY(VisibleAnywhere, Category="SparksAndSprites")
	UProceduralMeshComponent* Mesh;

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float Radius = 200.f;

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float MountainHeight = 36.f;

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	int32 Segments = 48;

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaTime) override;
};
