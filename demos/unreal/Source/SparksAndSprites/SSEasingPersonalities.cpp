#include "SSEasingPersonalities.h"

ASSEasingPersonalities::ASSEasingPersonalities()
{
	PrimaryActorTick.bCanEverTick = true;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

void ASSEasingPersonalities::BeginPlay()
{
	Super::BeginPlay();
	Origin = GetActorLocation();
}

float ASSEasingPersonalities::DurationFor(ESSSoul S)
{
	switch (S)
	{
	case ESSSoul::Human: return 2.0f;      case ESSSoul::Superhuman: return 2.2f;
	case ESSSoul::Alien: return 3.4f;      case ESSSoul::Excited: return 2.4f;
	case ESSSoul::Sad: return 3.6f;        case ESSSoul::Emotionless: return 2.4f;
	case ESSSoul::Robot: return 3.0f;      default: return 4.2f;
	}
}

FVector2D ASSEasingPersonalities::PosFor(float U) const
{
	switch (Soul)
	{
	case ESSSoul::Human:
	{	// ease both ends + gentle bob
		const float E = U < 0.5f ? 4 * U * U * U : 1 - FMath::Pow(-2 * U + 2, 3) / 2;
		return FVector2D(E, FMath::Sin(U * PI * 2.2f) * 0.06f);
	}
	case ESSSoul::Superhuman:
	{	// anticipation pull-back, then t⁴ snap
		if (U < 0.25f) return FVector2D(-0.05f * (U / 0.25f), 0);
		if (U < 0.45f) { const float K = (U - 0.25f) / 0.2f; return FVector2D(-0.05f + 1.05f * K * K * K * K, 0); }
		return FVector2D(1, 0);
	}
	case ESSSoul::Alien:
	{	// unsynced sines + abrupt reorientation
		float Y = 0.35f * FMath::Sin(U * 2 * PI) + 0.25f * FMath::Sin(U * 2 * PI * 1.618f + 2);
		if (int(U * 5) % 2 == 1) Y = -Y * 0.6f;
		return FVector2D(FMath::Min(1.f, U + 0.06f * FMath::Sin(U * 13)), Y * 0.5f);
	}
	case ESSSoul::Excited:
	{	// springy overshoot with bounces
		const float E = 1 - FMath::Pow(2.f, -8 * U) * FMath::Cos(U * 14);
		return FVector2D(FMath::Min(1.06f, E), -FMath::Abs(FMath::Sin(U * 12)) * 0.22f * (1 - U));
	}
	case ESSSoul::Sad:
	{	// hesitate… then droop through a sagging arc
		if (U < 0.22f) return FVector2D(0, 0.05f);
		const float K = (U - 0.22f) / 0.78f;
		return FVector2D(1 - FMath::Pow(1 - K, 2.6f), 0.05f + FMath::Sin(K * PI) * 0.28f);
	}
	case ESSSoul::Robot:
	{	// 7 quantised steps + tiny servo settle
		const float Steps = 7, S = FMath::Floor(U * Steps) / Steps, F = FMath::Fmod(U * Steps, 1.f);
		const float Settle = F < 0.3f ? FMath::Sin(F / 0.3f * PI * 3) * FMath::Exp(-F * 10) * 0.015f : 0.f;
		return FVector2D(S + Settle, 0);
	}
	case ESSSoul::Stately:
	{	// long sine ease + wide unhurried arc
		const float E = -(FMath::Cos(PI * U) - 1) / 2;
		return FVector2D(E, -FMath::Sin(U * PI) * 0.42f);
	}
	default:  // Emotionless: pure linear — that's the whole recipe
		return FVector2D(U, 0);
	}
}

void ASSEasingPersonalities::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	Clock += DeltaTime;
	const float U = FMath::Clamp(Clock / DurationFor(Soul), 0.f, 1.f);
	const FVector2D P = PosFor(U);
	SetActorLocation(Origin + FVector(0.f, P.X * TravelDistance, -P.Y * TravelDistance * 0.4f));
	if (U >= 1.f && bLoop) Clock = -0.4f;   // a short breath, then again
}
