/**
 * Per-save-slot rune storage in the game's world float store (AG1RGameState::SaveWorldFloatData).
 * Verified in-game 2026-11-03: values survive save -> load and a full restart, are per save slot
 * (an older save reads NOT FOUND), unsaved writes are dropped by a load, float32 precision ~0.01 cm.
 * There is no delete/enumerate API, so a count key bounds the list; stale keys above it are ignored.
 *
 * Keys: RunicMarkers_<World>_Count and RunicMarkers_<World>_<i>_<Field>,
 * fields PX PY PZ (location), RP RY RR (rotation pitch/yaw/roll), S (symbol index).
 * S is an index into RunicMarkers::SymbolIds(), so that list is APPEND-ONLY: reordering it would
 * change the symbol of runes in existing saves.
 */
struct FRunicSavedRune
{
	FVector Location;
	FRotator Rotation;
	int Symbol = 0;
}

namespace RunicPersistence
{
	FName Key(UWorld World, FString Suffix)
	{
		return FName(f"RunicMarkers_{World.Name.ToString()}_{Suffix}");
	}

	FName FieldKey(UWorld World, int Index, FString Field)
	{
		return Key(World, f"{Index}_{Field}");
	}

	void WriteFloat(UWorld World, FName K, float Value)
	{
		AG1RGameState::SaveWorldFloatData(World, K, float32(Value));
	}

	bool ReadFloat(UWorld World, FName K, float& OutValue)
	{
		float32 Value = 0.0f;
		bool bFound = AG1RGameState::GetWorldFloatData(World, K, Value);
		OutValue = Value;
		return bFound;
	}

	/** Rewrites the whole list (<= 100 runes x 7 floats): simple and keeps order = placement order. */
	void SaveAll(UWorld World, TArray<FRunicSavedRune> Runes)
	{
		for (int i = 0; i < Runes.Num(); i++)
		{
			WriteFloat(World, FieldKey(World, i, "PX"), Runes[i].Location.X);
			WriteFloat(World, FieldKey(World, i, "PY"), Runes[i].Location.Y);
			WriteFloat(World, FieldKey(World, i, "PZ"), Runes[i].Location.Z);
			WriteFloat(World, FieldKey(World, i, "RP"), Runes[i].Rotation.Pitch);
			WriteFloat(World, FieldKey(World, i, "RY"), Runes[i].Rotation.Yaw);
			WriteFloat(World, FieldKey(World, i, "RR"), Runes[i].Rotation.Roll);
			WriteFloat(World, FieldKey(World, i, "S"), float(Runes[i].Symbol));
		}
		// Writes are synchronous and the game cannot save mid-loop, so entries and count stay consistent.
		WriteFloat(World, Key(World, "Count"), float(Runes.Num()));
	}

	/** Missing count = no runes saved (e.g. a save made before the mod). Incomplete entries are skipped. */
	TArray<FRunicSavedRune> LoadAll(UWorld World, int MaxCount, int& OutSkipped)
	{
		TArray<FRunicSavedRune> Runes;
		OutSkipped = 0;
		float CountF = 0.0f;
		if (!ReadFloat(World, Key(World, "Count"), CountF))
			return Runes;
		int Count = Math::Clamp(Math::RoundToInt(CountF), 0, MaxCount);
		for (int i = 0; i < Count; i++)
		{
			float PX = 0, PY = 0, PZ = 0, RP = 0, RY = 0, RR = 0, S = 0;
			bool bOk = ReadFloat(World, FieldKey(World, i, "PX"), PX)
				&& ReadFloat(World, FieldKey(World, i, "PY"), PY)
				&& ReadFloat(World, FieldKey(World, i, "PZ"), PZ)
				&& ReadFloat(World, FieldKey(World, i, "RP"), RP)
				&& ReadFloat(World, FieldKey(World, i, "RY"), RY)
				&& ReadFloat(World, FieldKey(World, i, "RR"), RR)
				&& ReadFloat(World, FieldKey(World, i, "S"), S);
			if (!bOk)
			{
				OutSkipped++;
				continue;
			}
			FRunicSavedRune Rune;
			Rune.Location = FVector(PX, PY, PZ);
			Rune.Rotation = FRotator(RP, RY, RR);
			Rune.Symbol = Math::RoundToInt(S);
			Runes.Add(Rune);
		}
		return Runes;
	}
}
