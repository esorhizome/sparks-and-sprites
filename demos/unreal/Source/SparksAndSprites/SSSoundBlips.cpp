#include "SSSoundBlips.h"
#include "Components/AudioComponent.h"
#include "Sound/SoundWaveProcedural.h"

ASSSoundBlips::ASSSoundBlips()
{
	PrimaryActorTick.bCanEverTick = false;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
	Audio = CreateDefaultSubobject<UAudioComponent>(TEXT("Audio"));
	Audio->SetupAttachment(RootComponent);
}

void ASSSoundBlips::BeginPlay()
{
	Super::BeginPlay();
	Wave = NewObject<USoundWaveProcedural>(this);
	Wave->SetSampleRate(Rate);
	Wave->NumChannels = 1;
	Wave->Duration = INDEFINITELY_LOOPING_DURATION;
	Wave->bLooping = false;
	Audio->SetSound(Wave);
	Audio->Play();
}

void ASSSoundBlips::Queue(const TArray<int16>& Samples)
{
	Wave->QueueAudio(reinterpret_cast<const uint8*>(Samples.GetData()),
		Samples.Num() * sizeof(int16));
}

void ASSSoundBlips::PlayCoin()
{
	// two quick square-ish notes, B5 → E6, with a fast fade
	TArray<int16> S; S.Reserve(int32(Rate * 0.18f));
	for (int32 I = 0; I < int32(Rate * 0.18f); I++)
	{
		const float U = I / float(Rate);
		const float F = U < 0.08f ? 988.f : 1319.f;
		const float V = FMath::Sign(FMath::Sin(2 * PI * F * U)) * 0.12f * (1 - U / 0.18f);
		S.Add(int16(V * 32767));
	}
	Queue(S);
}

void ASSSoundBlips::PlayLaser()
{
	// a falling pitch sweep
	TArray<int16> S; S.Reserve(int32(Rate * 0.25f));
	float Phase = 0.f;
	for (int32 I = 0; I < int32(Rate * 0.25f); I++)
	{
		const float U = I / float(Rate);
		Phase += 2 * PI * (1400.f - U * 4200.f) / Rate;    // frequency falls as it goes
		S.Add(int16(FMath::Sin(Phase) * 0.15f * (1 - U / 0.25f) * 32767));
	}
	Queue(S);
}

void ASSSoundBlips::PlayHit()
{
	// shaped noise — a thump of static with a fast fade
	TArray<int16> S; S.Reserve(int32(Rate * 0.2f));
	FRandomStream Rng(7);
	for (int32 I = 0; I < int32(Rate * 0.2f); I++)
	{
		const float U = I / float(Rate);
		S.Add(int16((Rng.FRand() * 2 - 1) * 0.2f * (1 - U / 0.2f) * 32767));
	}
	Queue(S);
}
