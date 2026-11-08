enum ERunicPlaceResult
{
	None,
	Placed,
	AimOk,
	NoPlayer,
	InConversation,
	InputBlocked,
	NoHit,
	BehindPlayer,
	TooFar,
	Blocked,
	RejectedCharacter,
	RejectedNonStatic,
	SpawnFailed,
	AssetsMissing,
	Deleted,
	NothingToDelete
}

FString RunicPlaceResultToString(ERunicPlaceResult Result)
{
	switch (Result)
	{
		case ERunicPlaceResult::None: return "-";
		case ERunicPlaceResult::Placed: return "placed";
		case ERunicPlaceResult::AimOk: return "aim ok";
		case ERunicPlaceResult::NoPlayer: return "no player";
		case ERunicPlaceResult::InConversation: return "in conversation";
		case ERunicPlaceResult::InputBlocked: return "input blocked / dead";
		case ERunicPlaceResult::NoHit: return "no hit";
		case ERunicPlaceResult::BehindPlayer: return "behind player";
		case ERunicPlaceResult::TooFar: return "too far";
		case ERunicPlaceResult::Blocked: return "blocked";
		case ERunicPlaceResult::RejectedCharacter: return "rejected: character";
		case ERunicPlaceResult::RejectedNonStatic: return "rejected: non-static";
		case ERunicPlaceResult::SpawnFailed: return "spawn failed";
		case ERunicPlaceResult::AssetsMissing: return "rune assets missing (pak not loaded?)";
		case ERunicPlaceResult::Deleted: return "deleted";
		case ERunicPlaceResult::NothingToDelete: return "no rune near the aimed point";
	}
}

/** Thin mod entry point: only starts the state subsystem once the game is ready. */
class URunicMarkersModHook : UGothicModExt_WorldSubsystem
{
	UFUNCTION(BlueprintOverride)
	void HandleReadyForPlay()
	{
		URunicMarkersState::Get().Start();
	}
}

/**
 * All logic and diagnostic state. UScriptWorldSubsystem for a well-evidenced ::Get().
 * Keys: hold T = preview at the aimed point, release T = place; Y = next symbol;
 * hold U = aimed rune glows red, release U = delete it.
 */
class URunicMarkersState : UScriptWorldSubsystem
{
	// Hotkeys are fixed (no FKey user-setting precedent in the modkit).
	FKey PlaceKey = EKeys::T;
	FKey NextSymbolKey = EKeys::Y;
	FKey DeleteKey = EKeys::U;

	// Input components we bound to; prevents double binding, survives pawn swaps.
	UPROPERTY()
	TArray<UInputComponent> BoundInputComps;

	UPROPERTY()
	FTimerHandle BindPollTimer;
	UPROPERTY()
	FTimerHandle PreviewTimer;
	UPROPERTY()
	FTimerHandle FlashTimer;
	UPROPERTY()
	FTimerHandle DeleteTimer;
	// Rune currently glowing red under hold-U.
	UPROPERTY()
	ARunicMarker DeleteTarget;

	UPROPERTY()
	TArray<ARunicMarker> Markers;

	// One material per symbol: MID of the game decal material with our cooked VT rune in 'Texture'.
	UPROPERTY()
	TArray<UMaterialInstanceDynamic> SymbolMaterials;
	int CurrentSymbol = 0;

	// Hold-T preview (same actor class, light off). Hidden when the aim is not placeable.
	UPROPERTY()
	ARunicMarker Preview;
	bool bAiming = false;
	float AppliedCandela = -1.0f;

	// Diagnostics for the ImGui panel.
	bool bStarted = false;
	FString AssetStatus = "not loaded";
	ERunicPlaceResult LastResult = ERunicPlaceResult::None;
	ERunicPlaceResult LastDeleteResult = ERunicPlaceResult::None;
	ERunicPlaceResult LastPreviewResult = ERunicPlaceResult::None;
	int PressCount = 0;
	FString LastHitActorName;
	FString LastHitComponentName;
	FString LastHitMobility;
	FVector LastImpactPoint;
	FVector LastImpactNormal;
	float LastDistance = -1.0f;

	// How many times HandleReadyForPlay -> Start ran in this world (verified: once per loaded save).
	int StartCount = 0;
	bool bRestored = false;
	// Bumped on every rune change (place / delete / restore); the Stats page list rebuilds when it moves.
	int ChangeCounter = 0;
	// Set when the saved list could not be restored completely: rewriting it would drop those runes.
	bool bSavingBlocked = false;
	FString PersistenceStatus = "-";

	// ---------------------------------------------------------------- persistence

	/** Spawns the saved runes of this save slot once per world. Clears runes already present first. */
	void RestoreRunes()
	{
		if (bRestored)
			return;
		bRestored = true;
		if (!AreAssetsLoaded())
		{
			// Do not touch the saved data: a later save would overwrite it with an empty list.
			bSavingBlocked = true;
			PersistenceStatus = "restore skipped: rune assets missing. Saving is OFF, new runes will not be saved";
			return;
		}

		TArray<AActor> Existing;
		GetAllActorsOfClass(ARunicMarker::StaticClass(), Existing);
		for (int i = 0; i < Existing.Num(); i++)
			Existing[i].DestroyActor();
		Markers.Empty();

		int Skipped = 0;
		TArray<FRunicSavedRune> Saved = RunicPersistence::LoadAll(World, RunicMarkers::MaxMarkers, Skipped);
		int Failed = 0;
		for (int i = 0; i < Saved.Num(); i++)
		{
			if (!IsValid(SpawnRune(Saved[i].Location, Saved[i].Rotation, Saved[i].Symbol)))
				Failed++;
		}
		ChangeCounter++;
		PersistenceStatus = f"restored {Markers.Num()} (cleared {Existing.Num()}, skipped {Skipped}, spawn failed {Failed})";
		if (Skipped + Failed > 0)
		{
			bSavingBlocked = true;
			PersistenceStatus += ". Saving is OFF to keep the unrestored runes";
		}
	}

	/** Called after every place / delete. The game writes it into the save file on its next save. */
	void SaveRunes()
	{
		ChangeCounter++;
		if (bSavingBlocked || !AreAssetsLoaded())
			return;
		TArray<FRunicSavedRune> Runes;
		for (int i = 0; i < Markers.Num(); i++)
		{
			if (!IsValid(Markers[i]))
				continue;
			FRunicSavedRune Rune;
			Rune.Location = Markers[i].ActorLocation;
			Rune.Rotation = Markers[i].ActorRotation;
			Rune.Symbol = Markers[i].SymbolIndex;
			Runes.Add(Rune);
		}
		RunicPersistence::SaveAll(World, Runes);
		PersistenceStatus = f"stored {Runes.Num()} (written to disk on the next game save)";
	}

	/** Rune list UI (stats page): delete one rune by its index in Markers. */
	bool DeleteRuneAt(int Index)
	{
		if (Index < 0 || Index >= Markers.Num())
			return false;
		if (IsValid(Markers[Index]))
			Markers[Index].DestroyActor();
		Markers.RemoveAt(Index);
		SaveRunes();
		return true;
	}

	/** Rune list UI: remove every rune of this save. */
	int ClearAllRunes()
	{
		int Count = Markers.Num();
		for (int i = 0; i < Markers.Num(); i++)
		{
			if (IsValid(Markers[i]))
				Markers[i].DestroyActor();
		}
		Markers.Empty();
		SaveRunes();
		return Count;
	}

	bool AreAssetsLoaded() const
	{
		if (SymbolMaterials.Num() != RunicMarkers::SymbolIds().Num())
			return false;
		for (int i = 0; i < SymbolMaterials.Num(); i++)
		{
			if (!IsValid(SymbolMaterials[i]))
				return false;
		}
		return true;
	}

	ARunicMarker SpawnRune(FVector Location, FRotator Rotation, int Symbol)
	{
		UMaterialInterface SymbolMat = GetSymbolMaterial(Symbol);
		if (!IsValid(SymbolMat))
			return nullptr;
		ARunicMarker Marker = Cast<ARunicMarker>(SpawnActor(ARunicMarker::StaticClass(), Location, Rotation));
		if (!IsValid(Marker))
			return nullptr;
		Marker.SetSymbol(Symbol, SymbolMat);
		Markers.Add(Marker);
		return Marker;
	}

	void Start()
	{
		bStarted = true;
		StartCount++;
		auto Player = Cast<AGothicCharacter>(Gameplay::GetPlayerCharacter(0));
		Log(f"[RunicMarkers] Start: player character valid = {IsValid(Player)}");

		LoadSymbolMaterials();
		RestoreRunes();
		BindHotkey();
		// Polling re-binds when the pawn / its input component is replaced (e.g. after a load)
		// and pushes a changed glow setting to placed runes.
		if (!System::IsTimerActiveHandle(BindPollTimer))
			BindPollTimer = System::SetTimerDelegate(FTimerDynamicDelegate(this, n"OnPoll"), RunicMarkers::BindPollInterval, true);
	}

	void LoadSymbolMaterials()
	{
		SymbolMaterials.Empty();
		UMaterialInterface Base = Cast<UMaterialInterface>(LoadObject(nullptr, RunicMarkers::DecalMaterialPath));
		if (!IsValid(Base))
		{
			AssetStatus = f"FAIL: decal material not found: {RunicMarkers::DecalMaterialPath}";
			return;
		}
		TArray<FString> Ids = RunicMarkers::SymbolIds();
		int Missing = 0;
		for (int i = 0; i < Ids.Num(); i++)
		{
			UTexture Tex = Cast<UTexture>(LoadObject(nullptr, RunicMarkers::SymbolTexturePath(Ids[i])));
			UMaterialInstanceDynamic MID = Material::CreateDynamicMaterialInstance(Base);
			if (!IsValid(Tex) || !IsValid(MID))
			{
				Missing++;
				SymbolMaterials.Add(nullptr);
				continue;
			}
			MID.SetTextureParameterValue(RunicMarkers::DecalTextureParam, Tex);
			SymbolMaterials.Add(MID);
		}
		AssetStatus = Missing == 0 ? f"OK: {Ids.Num()} symbols" : f"FAIL: {Missing} of {Ids.Num()} symbols missing (pak not loaded?)";
	}

	UMaterialInterface GetSymbolMaterial(int Index) const
	{
		if (Index < 0 || Index >= SymbolMaterials.Num())
			return nullptr;
		return SymbolMaterials[Index];
	}

	FString GetCurrentSymbolId() const
	{
		TArray<FString> Ids = RunicMarkers::SymbolIds();
		return Ids[CurrentSymbol];
	}

	UInputComponent GetCurrentPlayerInputComp() const
	{
		auto Player = Cast<AGothicCharacter>(Gameplay::GetPlayerCharacter(0));
		if (!IsValid(Player))
			return nullptr;
		return UInputComponent::Get(Player);
	}

	bool IsKeyBound() const
	{
		auto InputComp = GetCurrentPlayerInputComp();
		return IsValid(InputComp) && BoundInputComps.Contains(InputComp);
	}

	UFUNCTION()
	void OnPoll()
	{
		BindHotkey();
		float Candela = RunicMarkers::GetLightCandela();
		if (Candela != AppliedCandela)
		{
			AppliedCandela = Candela;
			for (int i = 0; i < Markers.Num(); i++)
			{
				if (IsValid(Markers[i]))
					Markers[i].RefreshLight();
			}
		}
	}

	void BindHotkey()
	{
		for (int i = BoundInputComps.Num() - 1; i >= 0; i--)
		{
			if (!IsValid(BoundInputComps[i]))
				BoundInputComps.RemoveAt(i);
		}

		auto InputComp = GetCurrentPlayerInputComp();
		if (!IsValid(InputComp) || BoundInputComps.Contains(InputComp))
			return;

		InputComp.BindKey(PlaceKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnPlacePressed"), false);
		InputComp.BindKey(PlaceKey, EInputEvent::IE_Released, FInputActionHandlerDynamicSignature(this, n"OnPlaceReleased"), false);
		InputComp.BindKey(NextSymbolKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnNextSymbol"), false);
		InputComp.BindKey(DeleteKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnDeletePressed"), false);
		InputComp.BindKey(DeleteKey, EInputEvent::IE_Released, FInputActionHandlerDynamicSignature(this, n"OnDeleteReleased"), false);
		BoundInputComps.Add(InputComp);
		Log("[RunicMarkers] Hotkeys bound (T place, Y next symbol, U delete)");
	}

	// ---------------------------------------------------------------- input

	/** Same gating as ComputeAim's first checks; used by keys that do not trace (Y). */
	bool IsInputAllowed() const
	{
		auto Player = Cast<AGothicCharacter>(Gameplay::GetPlayerCharacter(0));
		return IsValid(Player)
			&& !Player.IsInConversation()
			&& !Player.HasGameplayTag(GameplayTag::State_IgnoreAllInput)
			&& !Player.HasGameplayTag(GameplayTag::State_IgnoreAllInputButCamera)
			&& !Player.HasGameplayTag(GameplayTag::State_Dead);
	}

	UFUNCTION()
	void OnPlacePressed(FKey Key)
	{
		bAiming = true;
		System::ClearAndInvalidateTimerHandle(FlashTimer);
		// A lost Released event must not leave an older repeating timer running.
		System::ClearAndInvalidateTimerHandle(PreviewTimer);
		UpdatePreview();
		PreviewTimer = System::SetTimerDelegate(FTimerDynamicDelegate(this, n"UpdatePreview"), RunicMarkers::PreviewInterval, true);
	}

	UFUNCTION()
	void OnPlaceReleased(FKey Key)
	{
		System::ClearAndInvalidateTimerHandle(PreviewTimer);
		HidePreview();
		if (!bAiming)
			return;
		bAiming = false;
		// Known limitation: opening the inventory while holding T sends a release, and it places.
		PressCount++;
		LastResult = TryPlace();
		Log(f"[RunicMarkers] Place #{PressCount}: {RunicPlaceResultToString(LastResult)}");
	}

	/** A key released inside a menu (Esc) never sends Released to us: timers end the hold mode then. */
	bool IsKeyHeld(FKey Key) const
	{
		auto PC = Gameplay::GetPlayerController(0);
		return IsValid(PC) && PC.IsInputKeyDown(Key);
	}

	UFUNCTION()
	void OnNextSymbol(FKey Key)
	{
		if (!IsInputAllowed())
			return;
		CurrentSymbol = (CurrentSymbol + 1) % RunicMarkers::SymbolIds().Num();
		UpdatePreview();
		if (!bAiming)
		{
			// Short look at the newly selected symbol at the aimed point.
			System::ClearAndInvalidateTimerHandle(FlashTimer);
			FlashTimer = System::SetTimerDelegate(FTimerDynamicDelegate(this, n"OnFlashEnd"), RunicMarkers::FlashDuration, false);
		}
	}

	UFUNCTION()
	void OnFlashEnd()
	{
		if (!bAiming)
			HidePreview();
	}

	// Hold U: the rune that release-U would delete glows red.
	UFUNCTION()
	void OnDeletePressed(FKey Key)
	{
		System::ClearAndInvalidateTimerHandle(DeleteTimer);
		UpdateDeleteTarget();
		DeleteTimer = System::SetTimerDelegate(FTimerDynamicDelegate(this, n"UpdateDeleteTarget"), RunicMarkers::PreviewInterval, true);
	}

	UFUNCTION()
	void OnDeleteReleased(FKey Key)
	{
		System::ClearAndInvalidateTimerHandle(DeleteTimer);
		SetDeleteTarget(nullptr);
		int Index = -1;
		LastDeleteResult = FindDeleteTarget(Index);
		if (LastDeleteResult == ERunicPlaceResult::Deleted)
		{
			Markers[Index].DestroyActor();
			Markers.RemoveAt(Index);
			SaveRunes();
		}
		Log(f"[RunicMarkers] Delete: {RunicPlaceResultToString(LastDeleteResult)}");
	}

	UFUNCTION()
	void UpdateDeleteTarget()
	{
		if (!IsKeyHeld(DeleteKey))
		{
			// Release was swallowed by a menu: drop the red highlight (deleting still needs a release).
			System::ClearAndInvalidateTimerHandle(DeleteTimer);
			SetDeleteTarget(nullptr);
			return;
		}
		int Index = -1;
		ERunicPlaceResult Result = FindDeleteTarget(Index);
		SetDeleteTarget(Result == ERunicPlaceResult::Deleted ? Markers[Index] : nullptr);
	}

	void SetDeleteTarget(ARunicMarker Target)
	{
		if (DeleteTarget == Target)
			return;
		if (IsValid(DeleteTarget))
			DeleteTarget.SetHighlighted(false);
		DeleteTarget = Target;
		if (IsValid(DeleteTarget))
			DeleteTarget.SetHighlighted(true);
	}

	// ---------------------------------------------------------------- aim

	/** Shared aim checks for preview, place and delete. AimOk = placeable surface. */
	ERunicPlaceResult ComputeAim(FHitResult& OutHit, FVector& OutCamDir)
	{
		LastHitActorName = "";
		LastHitComponentName = "";
		LastHitMobility = "";
		LastImpactPoint = FVector::ZeroVector;
		LastImpactNormal = FVector::ZeroVector;
		LastDistance = -1.0f;

		auto Player = Cast<AGothicCharacter>(Gameplay::GetPlayerCharacter(0));
		if (!IsValid(Player))
			return ERunicPlaceResult::NoPlayer;
		if (Player.IsInConversation())
			return ERunicPlaceResult::InConversation;
		if (Player.HasGameplayTag(GameplayTag::State_IgnoreAllInput)
			|| Player.HasGameplayTag(GameplayTag::State_IgnoreAllInputButCamera)
			|| Player.HasGameplayTag(GameplayTag::State_Dead))
			return ERunicPlaceResult::InputBlocked;

		const float MaxDistance = RunicMarkers::GetMaxDistance();
		// ActorLocation is the capsule centre (~half capsule height above the feet).
		const FVector PlayerPos = Player.ActorLocation;

		FVector CamLoc;
		MagicScript::GetCameraDirectionAndLocation(Player, OutCamDir, CamLoc);
		OutCamDir.Normalize();

		// Ignore the player, anything attached to them, and our preview.
		TArray<AActor> Ignore;
		Player.GetAttachedActors(Ignore, true, true);
		Ignore.Add(Player);
		if (IsValid(Preview))
			Ignore.Add(Preview);
		ETraceTypeQuery TraceType = UCollisionProfile::ConvertToTraceType(ECollisionChannel::ECC_Visibility);

		// The camera is behind the player, so extend the ray by the camera->player distance.
		FVector AimEnd = CamLoc + OutCamDir * (CamLoc.Distance(PlayerPos) + MaxDistance + RunicMarkers::AimTraceExtra);
		if (!System::LineTraceSingle(CamLoc, AimEnd, TraceType, false, Ignore, EDrawDebugTrace::None, OutHit, true))
			return ERunicPlaceResult::NoHit;

		LastImpactPoint = OutHit.ImpactPoint;
		LastImpactNormal = OutHit.ImpactNormal;
		LastDistance = PlayerPos.Distance(OutHit.ImpactPoint);
		if (IsValid(OutHit.Actor))
			LastHitActorName = OutHit.Actor.Name.ToString();
		if (IsValid(OutHit.Component))
		{
			LastHitComponentName = OutHit.Component.Name.ToString();
			LastHitMobility = OutHit.Component.Mobility == EComponentMobility::Static ? "Static" : "Not static";
		}

		// Something between the camera and the player (e.g. a wall behind the hero).
		if ((OutHit.ImpactPoint - PlayerPos).DotProduct(OutCamDir) < 0)
			return ERunicPlaceResult::BehindPlayer;
		if (Cast<AGothicCharacter>(OutHit.Actor) != nullptr)
			return ERunicPlaceResult::RejectedCharacter;
		if (LastDistance > MaxDistance)
			return ERunicPlaceResult::TooFar;
		if (!IsValid(OutHit.Component) || OutHit.Component.Mobility != EComponentMobility::Static)
			return ERunicPlaceResult::RejectedNonStatic;

		// Line of sight from the eyes to just past the surface. Hitting the aimed component
		// is fine; anything else hit clearly before the target blocks.
		FVector EyePos = PlayerPos + FVector(0, 0, RunicMarkers::EyeHeightOffset);
		FVector LosEnd = OutHit.ImpactPoint - OutHit.ImpactNormal * RunicMarkers::LosPastSurface;
		FHitResult LosHit;
		if (System::LineTraceSingle(EyePos, LosEnd, TraceType, false, Ignore, EDrawDebugTrace::None, LosHit, true)
			&& LosHit.Component != OutHit.Component
			&& EyePos.Distance(LosHit.ImpactPoint) < EyePos.Distance(OutHit.ImpactPoint) - RunicMarkers::BlockTolerance)
			return ERunicPlaceResult::Blocked;

		return ERunicPlaceResult::AimOk;
	}

	/**
	 * X = surface normal. Walls/slopes: zero roll keeps the symbol's Z (up) at world up (stage-1 proven).
	 * Floors/ceilings (pitch ~ +-90, where yaw spins around the normal): yaw so the symbol's up points
	 * along the view direction (sign chosen in-game, see the decal roll in RunicMarkerActor).
	 * Only Rotation()/FRotator fields: FRotator::MakeFromXZ / Atan2 have no modkit precedent.
	 */
	FRotator RuneRotation(FVector Normal, FVector CamDir) const
	{
		FRotator Rot = Normal.Rotation();
		FVector WorldUpOnPlane = FVector(0, 0, 1) - Normal * Normal.DotProduct(FVector(0, 0, 1));
		if (WorldUpOnPlane.Size() >= 0.3f)
			return Rot;
		FVector ViewOnPlane = CamDir - Normal * Normal.DotProduct(CamDir);
		ViewOnPlane.Z = 0.0f;
		if (ViewOnPlane.Size() < 0.01f)
			return Rot;
		// Sign chosen in-game with decal roll +90: this way the symbol's head points away from the player.
		Rot.Yaw = Normal.Z > 0.0f ? (ViewOnPlane * -1.0f).Rotation().Yaw : ViewOnPlane.Rotation().Yaw;
		return Rot;
	}

	ERunicPlaceResult TryPlace()
	{
		UMaterialInterface SymbolMat = GetSymbolMaterial(CurrentSymbol);
		if (!IsValid(SymbolMat))
			return ERunicPlaceResult::AssetsMissing;

		FHitResult Hit;
		FVector CamDir;
		ERunicPlaceResult Aim = ComputeAim(Hit, CamDir);
		if (Aim != ERunicPlaceResult::AimOk)
			return Aim;

		FVector Location = Hit.ImpactPoint + Hit.ImpactNormal * RunicMarkers::SurfaceOffset;
		if (!IsValid(SpawnRune(Location, RuneRotation(Hit.ImpactNormal, CamDir), CurrentSymbol)))
			return ERunicPlaceResult::SpawnFailed;

		while (Markers.Num() > RunicMarkers::MaxMarkers)
		{
			if (IsValid(Markers[0]))
				Markers[0].DestroyActor();
			Markers.RemoveAt(0);
		}
		SaveRunes();
		return ERunicPlaceResult::Placed;
	}

	/** Deleted = OutIndex is the rune nearest to the aimed point (nothing is destroyed here). */
	ERunicPlaceResult FindDeleteTarget(int& OutIndex)
	{
		OutIndex = -1;
		FHitResult Hit;
		FVector CamDir;
		ERunicPlaceResult Aim = ComputeAim(Hit, CamDir);
		// Runes have no collision, so the trace hits the surface under them; non-static / too-far
		// surfaces are still fine to delete from. Blocked = aimed point not visible (no deleting
		// through thin walls); a character in the way must not delete the rune behind it.
		if (Aim == ERunicPlaceResult::NoPlayer || Aim == ERunicPlaceResult::InConversation
			|| Aim == ERunicPlaceResult::InputBlocked || Aim == ERunicPlaceResult::NoHit
			|| Aim == ERunicPlaceResult::BehindPlayer || Aim == ERunicPlaceResult::Blocked
			|| Aim == ERunicPlaceResult::RejectedCharacter)
			return Aim;
		if (LastDistance > RunicMarkers::GetMaxDistance() + RunicMarkers::DeleteRadius)
			return ERunicPlaceResult::TooFar;

		int Best = -1;
		float BestDist = RunicMarkers::DeleteRadius;
		for (int i = 0; i < Markers.Num(); i++)
		{
			if (!IsValid(Markers[i]))
				continue;
			float D = Markers[i].ActorLocation.Distance(Hit.ImpactPoint);
			if (D <= BestDist)
			{
				Best = i;
				BestDist = D;
			}
		}
		if (Best < 0)
			return ERunicPlaceResult::NothingToDelete;
		OutIndex = Best;
		return ERunicPlaceResult::Deleted;
	}

	// ---------------------------------------------------------------- preview

	UFUNCTION()
	void UpdatePreview()
	{
		if (bAiming && !IsKeyHeld(PlaceKey))
		{
			// Release was swallowed by a menu: stop the preview. Placing still needs a real release,
			// so a misbehaving IsInputKeyDown can only hide the preview, never block or fake a place.
			System::ClearAndInvalidateTimerHandle(PreviewTimer);
			HidePreview();
			return;
		}
		UMaterialInterface SymbolMat = GetSymbolMaterial(CurrentSymbol);
		FHitResult Hit;
		FVector CamDir;
		LastPreviewResult = IsValid(SymbolMat) ? ComputeAim(Hit, CamDir) : ERunicPlaceResult::AssetsMissing;
		if (LastPreviewResult != ERunicPlaceResult::AimOk)
		{
			HidePreview();
			return;
		}
		if (!IsValid(Preview))
		{
			Preview = Cast<ARunicMarker>(SpawnActor(ARunicMarker::StaticClass(), Hit.ImpactPoint, FRotator::ZeroRotator));
			if (!IsValid(Preview))
				return;
			Preview.SetLightEnabled(false);
		}
		Preview.SetActorLocation(Hit.ImpactPoint + Hit.ImpactNormal * RunicMarkers::SurfaceOffset);
		Preview.SetActorRotation(RuneRotation(Hit.ImpactNormal, CamDir));
		Preview.SetSymbol(CurrentSymbol, SymbolMat);
		Preview.SetActorHiddenInGame(false);
	}

	void HidePreview()
	{
		if (IsValid(Preview))
			Preview.SetActorHiddenInGame(true);
	}
}
