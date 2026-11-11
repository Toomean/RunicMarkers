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

/**
 * Key bindings, stored in GameUserSettings.ini like the settings above. Not an FModUserSettings type:
 * the modkit has no key setting, so these are plain Config FKeys (approach seen in "Put Away Torch").
 * Defaults avoid the game's bindings (screenshots of its key list, 2026-11-09) and T (that mod).
 */
UCLASS(Config=GameUserSettings)
class URunicMarkersKeyConfig : UObject
{
	UPROPERTY(Config)
	FKey PlaceKey = EKeys::V;
	UPROPERTY(Config)
	FKey NextSymbolKey = EKeys::N;
	UPROPERTY(Config)
	FKey DeleteKey = EKeys::H;
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
	// Key polling interval (s); press/release are detected from the down state between polls.
	const float InputPollInterval = 0.02f;
	// C5: opening the management UI (inventory, stats, map...) while holding the place or delete key
	// makes IsInputKeyDown go false, and the poll would see a release and place / delete. So a release
	// acts only after this delay (s), and not at all if that UI ticked (URunicMarkersMenuWatch ->
	// MenuTickCount) since the poll last saw the key down. The snapshot is taken while the key is down,
	// so this also works if the UI pauses world timers (the poll then sees the release only after it
	// closes); the delay covers the case where the UI starts ticking just after the release is seen.
	const float ReleaseConfirmDelay = 0.15f;
	// C7: the Esc pause menu stops world timers, so the key poll sees a release made in that menu only
	// after the pause ends. A released place / delete is cancelled when the paused time
	// (URunicMarkersState::GetPausedSeconds, Unpaused - game time) grew by more than this (s) since the key
	// was last seen down. Pure pause signal: time dilation and long frames add 0 to it, so it can stay small.
	const float PauseCancelThreshold = 0.05f;
	// Aim trace goes this far beyond MaxDistance so far points report "too far", not "no hit".
	const float AimTraceExtra = 500.0f;

	// Rune decal box (cm): X = projection depth, Y/Z = half-size of the symbol (spike: 10 / 25 looked right).
	// 5 (was 10): a deep box spilled onto the neighbouring plank of overlapping hut walls. Too shallow
	// would cut strokes on rough rock (in-game check pending).
	const float DecalDepth = 5.0f;
	const float DecalHalfSize = 25.0f;
	// Light candela at glow setting 100 (UNVERIFIED mapping, tune in-game).
	const float MaxLightCandela = 25.0f;
	// The delete key deletes the rune nearest to the aimed point within this radius (cm).
	const float DeleteRadius = 40.0f;
	// 0.2 step 4: the delete key first picks the rune closest to the crosshair: smallest angle (deg) between
	// the view direction and camera->rune, up to this angle; the hit-point rule above is the fallback.
	// 6 is UNVERIFIED (tune in-game).
	const float DeleteAimMaxAngleDeg = 6.0f;
	// Camera->rune visibility trace for delete targets (cm; IsRuneVisibleFromCamera). The rune sits
	// SurfaceOffset (1.5) off its surface and must face the camera, so a clear trace can only end on the
	// rune's own surface, a few cm past the rune; BlockTolerance (15) would let runes just behind thin
	// occluders through. 5 is UNVERIFIED (grazing floors at long range).
	const float DeleteLosTolerance = 5.0f;
	// Delete aim dot: a second ARunicMarker with the "dot" texture (T_Rune_dot_VT, art/gen_symbols.py MARKS),
	// decal width/height scaled by DeleteAimScale (actor scale Y/Z; X = projection depth stays 1).
	// NOT a placeable symbol: not in SymbolIds() / SymbolNames(), loaded separately (DeleteAimMaterial).
	// Until 0.2 step 5 this was the "O" symbol at 0.35 (read like a tiny rune). 0.2 is UNVERIFIED.
	const FString DeleteAimMarkId = "dot";
	const float DeleteAimScale = 0.2f;
	// HUD indicator: GetPausedSeconds() growing by more than this (s) between two HUD ticks = game paused.
	// Only to ignore double rounding; a paused frame grows it by the whole frame time.
	const float HudPauseEpsilon = 0.0001f;
	// Red light on the delete-key target (candela), shown even when glow is 0.
	const float HighlightCandela = 10.0f;
	// Hold-place preview refresh and next-symbol "flash" preview duration (s). The flash is only the
	// fallback when the HUD symbol indicator could not be attached (RunicMarkersHud.as).
	const float PreviewInterval = 0.05f;
	const float FlashDuration = 1.2f;
	// HUD symbol indicator: shown while the place key is held and this long (s) after a symbol change.
	const float SymbolIndicatorDuration = 1.5f;
	// Where the indicator sits: canvas root = anchor height (0 top .. 1 bottom), centred horizontally; the
	// rune image ends and the text starts there (until 0.2 step 3 the text was centred on it); overlay root =
	// bottom padding (Slate units). 0.85 (was 0.8, a little high in-game 2026-11-11) is UNVERIFIED.
	const float IndicatorAnchorY = 0.85f;
	const float IndicatorBottomPadding = 200.0f;
	// Rune image above the indicator text (canvas root only), drawn at this size (Slate units).
	const float IndicatorIconSize = 64.0f;
	// Gap (Slate units) between the bottom of the rune image and the top of the indicator text.
	const float IndicatorIconGap = 6.0f;
	// HUD indicator counts as on screen if it ticked within this many real seconds. The widget extension
	// only ticks while its host is visible, so a stale stamp means the indicator is not shown and the
	// next-symbol key uses the surface flash fallback instead.
	const float HudLiveWindow = 0.25f;

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

	/** Non-VT UI copy of the rune for the HUD indicator image (cook/RunicDecal/create_vt_symbols.py). */
	FString SymbolIconPath(FString SymbolId)
	{
		return f"/Reaper-RunicMarkers/Textures/T_RuneIcon_{SymbolId}.T_RuneIcon_{SymbolId}";
	}

	/** Key config default object for writing (RunicMarkersKeyRows.as). Reading keeps the .DefaultObject form below
	 * (compiled and verified); writing uses UClass.GetDefaultObject() (non-const UObject, modkit precedent
	 * GASCharacterStateMixins.as:931) because writes through .DefaultObject have no precedent. Same object. */
	URunicMarkersKeyConfig GetKeyConfigForWrite()
	{
		return Cast<URunicMarkersKeyConfig>(URunicMarkersKeyConfig::StaticClass().GetDefaultObject());
	}

	FKey PlaceKey() { return URunicMarkersKeyConfig.DefaultObject.PlaceKey; }
	FKey NextSymbolKey() { return URunicMarkersKeyConfig.DefaultObject.NextSymbolKey; }
	FKey DeleteKey() { return URunicMarkersKeyConfig.DefaultObject.DeleteKey; }

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
