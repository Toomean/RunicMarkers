UCLASS(Config=GameUserSettings)
class UGothicModExt_UserSettings_RunicMarkers : UGothicModExt_UserSettings
{
	default CategoryName = FText::FromString("Runic Markers");

	UPROPERTY(Config)
	FModUserSettingsFloat MaxDistance = FModUserSettingsFloat(
		Value = 300.0f,
		DefaultValue = 300.0f,
		DisplayText = FText::FromString("Max marker distance (cm)"),
		MinValue = 100.0f,
		MaxValue = 1000.0f,
		StepSize = 25.0f);

	// 0 = no light. Stage 1 showed 50 candela already very bright, so 100 maps to MaxLightCandela.
	UPROPERTY(Config)
	FModUserSettingsFloat LightIntensity = FModUserSettingsFloat(
		Value = 12.0f,
		DefaultValue = 12.0f,
		DisplayText = FText::FromString("Rune glow (0-100)"),
		MinValue = 0.0f,
		MaxValue = 100.0f,
		StepSize = 1.0f);
}

namespace RunicMarkers
{
	const int MaxMarkers = 100;
	const float SurfaceOffset = 1.5f;
	// Tolerance for the player->hit visibility check (grazing angles, mesh seams).
	const float BlockTolerance = 15.0f;
	// Line-of-sight start above ActorLocation (capsule centre, ~half capsule height above the feet).
	const float EyeHeightOffset = 60.0f;
	// LOS trace ends this far behind the surface so it reliably hits the aimed surface.
	const float LosPastSurface = 2.0f;
	const float BindPollInterval = 1.0f;
	// Aim trace goes this far beyond MaxDistance so far points report "too far", not "no hit".
	const float AimTraceExtra = 500.0f;

	// Rune decal box (cm): X = projection depth, Y/Z = half-size of the symbol (spike: 10 / 25 looked right).
	// 5 (was 10): a deep box spilled onto the neighbouring plank of overlapping hut walls. Too shallow
	// would cut strokes on rough rock (in-game check pending).
	const float DecalDepth = 5.0f;
	const float DecalHalfSize = 25.0f;
	// Light candela at glow setting 100 (UNVERIFIED mapping, tune in-game).
	const float MaxLightCandela = 25.0f;
	// U deletes the rune nearest to the aimed point within this radius (cm).
	const float DeleteRadius = 40.0f;
	// Red hold-U target light (candela), shown even when glow is 0.
	const float HighlightCandela = 10.0f;
	// Hold-T preview refresh and Y "flash" preview duration (s).
	const float PreviewInterval = 0.05f;
	const float FlashDuration = 1.2f;

	// Game decal material whose 'Texture' (VT) param renders our cooked VT runes (verified 2026-11-03).
	const FString DecalMaterialPath = "/Game/Assets/Environment/Decals/M_Dirt_101.M_Dirt_101";
	const FName DecalTextureParam = n"Texture";

	// APPEND-ONLY: saves store the index into this list (see RunicMarkersPersistence.as).
	TArray<FString> SymbolIds()
	{
		TArray<FString> S;
		S.Add("x_visited");
		S.Add("o_other");
		S.Add("innos");
		S.Add("beliar");
		S.Add("adanos");
		S.Add("sleeper");
		S.Add("human");
		return S;
	}

	/** Player-facing names, same order as SymbolIds(). */
	TArray<FString> SymbolNames()
	{
		TArray<FString> S;
		S.Add("X (visited)");
		S.Add("O (mark)");
		S.Add("Sun of Innos");
		S.Add("Moon of Beliar");
		S.Add("Waves of Adanos");
		S.Add("Eye of the Sleeper");
		S.Add("Human");
		return S;
	}

	FString SymbolName(int Index)
	{
		TArray<FString> Names = SymbolNames();
		return (Index >= 0 && Index < Names.Num()) ? Names[Index] : "?";
	}

	/** "32 m" (horizontal distance) from the player to a world point. */
	FString DistanceText(FVector From, FVector To)
	{
		FVector Delta = To - From;
		Delta.Z = 0.0f;
		if (Delta.Size() < 100.0f)
			return "here";
		return f"{Math::RoundToInt(Delta.Size() / 100.0f)} m";
	}

	FString SymbolTexturePath(FString SymbolId)
	{
		return f"/Reaper-RunicMarkers/Textures/T_Rune_{SymbolId}_VT.T_Rune_{SymbolId}_VT";
	}

	float GetMaxDistance()
	{
		return UGothicModExt_UserSettings_RunicMarkers.DefaultObject.MaxDistance.Value;
	}

	/** Glow setting 0..100 -> spot light candela. */
	float GetLightCandela()
	{
		float Glow = Math::Clamp(UGothicModExt_UserSettings_RunicMarkers.DefaultObject.LightIntensity.Value, 0.0f, 100.0f);
		return Glow / 100.0f * MaxLightCandela;
	}
}
