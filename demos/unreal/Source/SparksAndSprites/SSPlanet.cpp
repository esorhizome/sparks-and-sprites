#include "SSPlanet.h"

ASSPlanet::ASSPlanet()
{
	PrimaryActorTick.bCanEverTick = true;
	Mesh = CreateDefaultSubobject<UProceduralMeshComponent>(TEXT("Mesh"));
	RootComponent = Mesh;
}

void ASSPlanet::BeginPlay()
{
	Super::BeginPlay();

	TArray<FVector> Verts;
	TArray<int32> Tris;
	TArray<FVector> Normals;
	TArray<FVector2D> UVs;
	TArray<FLinearColor> Colors;
	TArray<FProcMeshTangent> Tangents;

	// a UV sphere, ring by ring — then the displacement that makes it a world
	for (int32 R = 0; R <= Segments; R++)
	{
		const float V = R / float(Segments);
		const float Phi = V * PI;
		for (int32 S = 0; S <= Segments; S++)
		{
			const float U = S / float(Segments);
			const float Theta = U * 2 * PI;
			FVector N(FMath::Sin(Phi) * FMath::Cos(Theta),
			          FMath::Sin(Phi) * FMath::Sin(Theta),
			          FMath::Cos(Phi));
			// only mountains rise; seas stay round
			const float Noise = FMath::PerlinNoise3D(N * 1.8f + FVector(7, 3, 5));
			const float Height = FMath::Max(0.f, Noise) * MountainHeight;
			Verts.Add(N * (Radius + Height));
			Normals.Add(N);
			UVs.Add(FVector2D(U, V));
			Colors.Add(Height < 1.f
				? FLinearColor(0.16f, 0.35f, 0.55f)                       // sea level
				: FMath::Lerp(FLinearColor(0.30f, 0.52f, 0.30f),
				              FLinearColor(0.85f, 0.82f, 0.75f),
				              FMath::Min(1.f, Height / MountainHeight)));
		}
	}
	for (int32 R = 0; R < Segments; R++)
		for (int32 S = 0; S < Segments; S++)
		{
			const int32 A = R * (Segments + 1) + S;
			const int32 B = A + Segments + 1;
			Tris.Append({ A, B, A + 1,  B, B + 1, A + 1 });
		}

	Mesh->CreateMeshSection_LinearColor(0, Verts, Tris, Normals, UVs, Colors, Tangents, false);
	// pair with a material whose Base Color reads Vertex Color, so the
	// height-paint above is what you see.
}

void ASSPlanet::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	AddActorLocalRotation(FRotator(0.f, 15.f * DeltaTime, 0.f));   // worlds turn slowly
}
