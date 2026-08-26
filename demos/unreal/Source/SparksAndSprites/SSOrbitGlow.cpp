#include "SSOrbitGlow.h"
#include "GameFramework/SpringArmComponent.h"
#include "Camera/CameraComponent.h"
#include "Components/StaticMeshComponent.h"

ASSOrbitGlow::ASSOrbitGlow()
{
	PrimaryActorTick.bCanEverTick = true;

	Centrepiece = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Centrepiece"));
	RootComponent = Centrepiece;

	Arm = CreateDefaultSubobject<USpringArmComponent>(TEXT("Arm"));
	Arm->SetupAttachment(RootComponent);
	Arm->TargetArmLength = 500.f;         // the stick's length = orbit radius
	Arm->bDoCollisionTest = false;
	Arm->SetRelativeRotation(FRotator(-20.f, 0.f, 0.f));

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(Arm);

	AutoPossessPlayer = EAutoReceiveInput::Player0;
}

void ASSOrbitGlow::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	Centrepiece->AddLocalRotation(FRotator(8.f * DeltaTime, 23.f * DeltaTime, 0.f));

	APlayerController* PC = Cast<APlayerController>(GetController());
	if (!PC) return;
	PC->bShowMouseCursor = true;
	if (PC->IsInputKeyDown(EKeys::LeftMouseButton))
	{
		float DX, DY;
		PC->GetInputMouseDelta(DX, DY);
		// the whole orbit camera: two rotations and a clamp
		FRotator R = Arm->GetRelativeRotation();
		R.Yaw += DX * 2.f;
		R.Pitch = FMath::Clamp(R.Pitch + DY * 2.f, -70.f, 20.f);
		Arm->SetRelativeRotation(R);
	}
}
