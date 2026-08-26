// THE CUBE CODEX — one protagonist, many effects, Unreal spelling (3D).
// An actor with a cube mesh that patrols on its own, plus named EFFECT
// SLOTS: assign Niagara systems in the details panel and call the
// Trigger* functions (from Blueprint, an input mapping, or C++). The
// following-halo is built in: a point light + a flattened emissive ring
// that chases the cube with a deliberate lag and a ±3% breath.
//
// Every effect keeps the codex anatomy: an idle loop (the patrol, the
// halo's breath, the aura's drip) + a press reaction (one Trigger call).
// The full 104 live on the web page (cube-vfx.html) and in the Godot
// project (demos/godot/scenes/cubefx/); recipes/cube-vfx.md maps each
// family onto Niagara, materials, and UMG.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SSCubeVfx.generated.h"

class UNiagaraSystem;
class UPointLightComponent;

UCLASS()
class ASSCubeVfx : public AActor
{
	GENERATED_BODY()

public:
	ASSCubeVfx();

	UPROPERTY(VisibleAnywhere, Category="SparksAndSprites")
	UStaticMeshComponent* Cube;           // assign a cube mesh (engine basic shapes)

	UPROPERTY(VisibleAnywhere, Category="SparksAndSprites")
	UStaticMeshComponent* HaloRing;       // a flattened torus/cylinder, emissive material

	UPROPERTY(VisibleAnywhere, Category="SparksAndSprites")
	UPointLightComponent* HaloLight;

	// --- the effect slots: assign Niagara systems in the editor ---
	UPROPERTY(EditAnywhere, Category="SparksAndSprites|Effects")
	UNiagaraSystem* FireburstFX = nullptr;   // radial burst (see recipes/sparks.md, warm palette)

	UPROPERTY(EditAnywhere, Category="SparksAndSprites|Effects")
	UNiagaraSystem* WaterhoseFX = nullptr;   // arcing jet: cone + gravity (recipes/cube-vfx.md)

	UPROPERTY(EditAnywhere, Category="SparksAndSprites|Effects")
	UNiagaraSystem* SkyBoltFX = nullptr;     // a beam/ribbon strike from above

	UPROPERTY(EditAnywhere, Category="SparksAndSprites|Effects")
	UNiagaraSystem* AuraFX = nullptr;        // looping updraft parented to the cube

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	float PatrolRadius = 300.f;

	UPROPERTY(EditAnywhere, Category="SparksAndSprites")
	bool bHaloEnabled = true;

	// --- the press reactions ---
	UFUNCTION(BlueprintCallable, Category="SparksAndSprites") void TriggerFireburst();
	UFUNCTION(BlueprintCallable, Category="SparksAndSprites") void TriggerWaterhose();
	UFUNCTION(BlueprintCallable, Category="SparksAndSprites") void TriggerSkyBolt(FVector WorldPoint);
	UFUNCTION(BlueprintCallable, Category="SparksAndSprites") void PulseHalo();

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaTime) override;

private:
	float Clock = 0.f;
	float HaloX = 0.f;
	float HaloPulse = 0.f;
	FVector Origin;
};
