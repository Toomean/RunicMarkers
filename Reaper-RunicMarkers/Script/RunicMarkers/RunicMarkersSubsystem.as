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
	NothingToDelete,
	CancelledByMenu,
	CancelledByPause
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
		case ERunicPlaceResult::CancelledByMenu: return "cancelled: a menu opened";
		case ERunicPlaceResult::CancelledByPause: return "cancelled: the game was paused";
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
 * Keys (configurable, URunicMarkersKeyConfig): hold place key = preview at the aimed point, release = place;
 * mouse wheel while aiming / next-symbol key = change symbol; hold delete key = aimed rune glows red,
 * release = delete it.
 */
class URunicMarkersState : UScriptWorldSubsystem
{
	// Keys are polled (configurable keys work at once, no rebinding). Last seen down state per key:
	bool bPlaceWasDown = false;
	bool bNextWasDown = false;
	bool bDeleteWasDown = false;
	// False until the first poll: a key already held at load must not count as a press.
	bool bInputPrimed = false;
	UPROPERTY()
	FTimerHandle InputTimer;

	// C5 (see RunicMarkers::ReleaseConfirmDelay): released place/delete keys wait for OnReleaseConfirm.
	// MenuTickCount is bumped by URunicMarkersMenuWatch; *MenuSnap = its value when the key was last seen down.
	int MenuTickCount = 0;
	int PlaceMenuSnap = 0;
	int DeleteMenuSnap = 0;
	// C7 (see RunicMarkers::PauseCancelThreshold): GetPausedSeconds() when the key was last seen down,
	// taken at the same moment as *MenuSnap.
	float64 PlacePauseSnap = 0.0f;
	float64 DeletePauseSnap = 0.0f;
	bool bPendingPlace = false;
	bool bPendingDelete = false;
	// Place-key release: placement computed then (AimOk or the failure), spawned on confirm as is.
	ERunicPlaceResult PendingPlaceResult = ERunicPlaceResult::None;
	FVector PendingPlaceLocation;
	FRotator PendingPlaceRotation;
	int PendingPlaceSymbol = 0;
	// Delete-key release: what was aimed at then (the red rune), deleted on confirm if still there.
	ERunicPlaceResult PendingDeleteResult = ERunicPlaceResult::None;
	UPROPERTY()
	ARunicMarker PendingDeleteTarget;
	UPROPERTY()
	FTimerHandle ReleaseTimer;

	// Input components the mouse wheel is bound to (wheel events are too short to poll reliably).
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
	// Rune currently glowing red while the delete key is held.
	UPROPERTY()
	ARunicMarker DeleteTarget;
	// Delete aim dot while the delete key is held (same class as Preview, light off, scaled down):
	// always at the aimed point (not snapped onto the target; its red light marks it). Hidden otherwise.
	UPROPERTY()
	ARunicMarker DeleteAim;
	// Its material: the dot texture (RunicMarkers::DeleteAimMarkId) in the decal material, loaded with the
	// symbols but kept out of SymbolMaterials (not a placeable symbol). Null = dot texture missing.
	UPROPERTY()
	UMaterialInstanceDynamic DeleteAimMaterial;
	// Set by FindDeleteTarget: where the aim dot goes (bDeleteAimValid = something aimed), how the rune was
	// chosen ("angle" / "hit point" / "none") and its angle off the view direction (deg, -1 = not by angle).
	bool bDeleteAimValid = false;
	FVector DeleteAimLocation;
	FRotator DeleteAimRotation;
	FString DeleteSelectMode = "none";
	float DeleteSelectAngle = -1.0f;

	UPROPERTY()
	TArray<ARunicMarker> Markers;

	// One material per symbol: MID of the game decal material with our cooked VT rune in 'Texture'.
	UPROPERTY()
	TArray<UMaterialInstanceDynamic> SymbolMaterials;
	int CurrentSymbol = 0;

	// Place-key preview (same actor class, light off). Hidden when the aim is not placeable.
	UPROPERTY()
	ARunicMarker Preview;
	bool bAiming = false;
	float AppliedCandela = -1.0f;

	// Symbol indicator on the HUD (URunicMarkersHudExtension, RunicMarkersHud.as). While it is live
	// (IsHudLive), the next-symbol key does not flash the symbol on a surface. HudLastTickRealTime is the
	// world real time of its last tick with a text block; the start value counts as not live.
	// SymbolChangeCounter is bumped on every symbol change; the indicator shows itself for a while when it moves.
	float64 HudLastTickRealTime = -1000.0f;
	int SymbolChangeCounter = 0;
	FString HudHostStatus = "not attached";
	int HudTickCount = 0;
	// Key rows on the settings page (RunicMarkersKeyRows.as): last insert / rebind result for Debug.
	FString KeyRowsStatus = "not built";

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
		bInputPrimed = false;
		if (!System::IsTimerActiveHandle(InputTimer))
			InputTimer = System::SetTimerDelegate(FTimerDynamicDelegate(this, n"OnInputPoll"), RunicMarkers::InputPollInterval, true);
	}

	void LoadSymbolMaterials()
	{
		SymbolMaterials.Empty();
		DeleteAimMaterial = nullptr;
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

		// Delete aim dot: same mechanism, separate from the symbol list.
		UTexture DotTex = Cast<UTexture>(LoadObject(nullptr, RunicMarkers::SymbolTexturePath(RunicMarkers::DeleteAimMarkId)));
		UMaterialInstanceDynamic DotMID = Material::CreateDynamicMaterialInstance(Base);
		if (IsValid(DotTex) && IsValid(DotMID))
		{
			DotMID.SetTextureParameterValue(RunicMarkers::DecalTextureParam, DotTex);
			DeleteAimMaterial = DotMID;
		}
		else
		{
			AssetStatus = f"{AssetStatus}; aim dot missing";
		}
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

		InputComp.BindKey(EKeys::MouseScrollUp, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnWheelUp"), false);
		InputComp.BindKey(EKeys::MouseScrollDown, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnWheelDown"), false);
		BoundInputComps.Add(InputComp);
		Log("[RunicMarkers] Mouse wheel bound (symbol change while aiming)");
	}

	// ---------------------------------------------------------------- input

	/** Same gating as ComputeAim's first checks; used by keys that do not trace (next-symbol key). */
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
		// An earlier release still waiting for its confirm is placed now, at its stored pose.
		if (bPendingPlace)
			ResolvePendingPlace();
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
		if (!bAiming)
		{
			HidePreview();
			return;
		}
		bAiming = false;
		// Compute the placement now (what the preview shows); the confirm only spawns it, no re-trace.
		// The preview stays at that pose until the confirm, so the rune appears exactly there.
		PendingPlaceSymbol = CurrentSymbol;
		PendingPlaceResult = ComputePlacement(PendingPlaceLocation, PendingPlaceRotation);
		if (PendingPlaceResult == ERunicPlaceResult::AimOk)
			ShowPreviewAt(PendingPlaceLocation, PendingPlaceRotation, PendingPlaceSymbol);
		else
			HidePreview();
		bPendingPlace = true;
		StartReleaseConfirm();
	}

	/**
	 * (Re)starts the one confirm timer. Pending flags stay set until resolved (OnReleaseConfirm, or a
	 * new press of the same key, which resolves its own pending action first), so a restart only
	 * delays an earlier pending action, never drops or repeats it.
	 */
	void StartReleaseConfirm()
	{
		System::ClearAndInvalidateTimerHandle(ReleaseTimer);
		ReleaseTimer = System::SetTimerDelegate(FTimerDynamicDelegate(this, n"OnReleaseConfirm"), RunicMarkers::ReleaseConfirmDelay, false);
	}

	/**
	 * Runs ReleaseConfirmDelay after a place/delete release (a new press of the same key resolves it
	 * earlier): acts, or cancels if a menu ticked since the key was last seen down (C5). The snapshot
	 * is frozen while the action is pending and the count only grows, so this one check covers a tick
	 * before the release was seen and after it.
	 */
	UFUNCTION()
	void OnReleaseConfirm()
	{
		if (bPendingPlace)
			ResolvePendingPlace();
		if (bPendingDelete)
			ResolvePendingDelete();
	}

	/**
	 * Seconds the game has spent paused so far: UnpausedTimeSeconds runs while paused, TimeSeconds stops.
	 * Pure pause signal: both are dilated and frame-clamped the same way, so time dilation and long frames
	 * (loading, hitches) do not move it. In-game (2026-11-11) the Esc menu grows only this part.
	 */
	float64 GetPausedSeconds()
	{
		return World.UnpausedTimeSeconds - World.TimeSeconds;
	}

	/** HUD indicator ticked recently, so it is on screen (see RunicMarkers::HudLiveWindow). */
	bool IsHudLive()
	{
		return World.RealTimeSeconds - HudLastTickRealTime < RunicMarkers::HudLiveWindow;
	}

	bool WasPausedSince(float64 Snap)
	{
		return GetPausedSeconds() - Snap > RunicMarkers::PauseCancelThreshold;
	}

	/** Pending place: cancel (menu / pause), or spawn at the pose stored at the release, or report its failure. */
	void ResolvePendingPlace()
	{
		bPendingPlace = false;
		if (MenuTickCount != PlaceMenuSnap)
			LastResult = ERunicPlaceResult::CancelledByMenu;
		else if (WasPausedSince(PlacePauseSnap))
			LastResult = ERunicPlaceResult::CancelledByPause;
		else
		{
			PressCount++;
			if (PendingPlaceResult == ERunicPlaceResult::AimOk)
				LastResult = PlaceAt(PendingPlaceLocation, PendingPlaceRotation, PendingPlaceSymbol);
			else
				LastResult = PendingPlaceResult;
		}
		// After the spawn, so the preview is replaced by the rune without a gap.
		HidePreview();
		Log(f"[RunicMarkers] Place #{PressCount}: {RunicPlaceResultToString(LastResult)}");
	}

	/** Pending delete: cancel (menu / pause), or delete the rune aimed at the release if it still exists. */
	void ResolvePendingDelete()
	{
		bPendingDelete = false;
		if (MenuTickCount != DeleteMenuSnap)
			LastDeleteResult = ERunicPlaceResult::CancelledByMenu;
		else if (WasPausedSince(DeletePauseSnap))
			LastDeleteResult = ERunicPlaceResult::CancelledByPause;
		else
			LastDeleteResult = PendingDeleteResult;
		if (LastDeleteResult == ERunicPlaceResult::Deleted)
		{
			int Index = IsValid(PendingDeleteTarget) ? Markers.FindIndex(PendingDeleteTarget) : -1;
			if (Index >= 0)
				DeleteRuneAt(Index);
			else
				LastDeleteResult = ERunicPlaceResult::NothingToDelete;
		}
		PendingDeleteTarget = nullptr;
		HideDeleteAim();
		Log(f"[RunicMarkers] Delete: {RunicPlaceResultToString(LastDeleteResult)}");
	}

	/** Polled down state; the poll (OnInputPoll) is the only press/release detector. */
	bool IsKeyHeld(FKey Key) const
	{
		auto PC = Gameplay::GetPlayerController(0);
		return IsValid(PC) && Input::Key_IsValid(Key) && PC.IsInputKeyDown(Key);
	}

	/** Turns the polled down state of the configured keys into press / release events. */
	UFUNCTION()
	void OnInputPoll()
	{
		bool PlaceDown = IsKeyHeld(RunicMarkers::PlaceKey());
		bool NextDown = IsKeyHeld(RunicMarkers::NextSymbolKey());
		bool DeleteDown = IsKeyHeld(RunicMarkers::DeleteKey());
		if (bInputPrimed)
		{
			if (PlaceDown && !bPlaceWasDown)
				OnPlacePressed(RunicMarkers::PlaceKey());
			else if (!PlaceDown && bPlaceWasDown)
				OnPlaceReleased(RunicMarkers::PlaceKey());
			if (NextDown && !bNextWasDown)
				ChangeSymbol(1);
			if (DeleteDown && !bDeleteWasDown)
				OnDeletePressed(RunicMarkers::DeleteKey());
			else if (!DeleteDown && bDeleteWasDown)
				OnDeleteReleased(RunicMarkers::DeleteKey());
		}
		// C5 / C7 snapshots; frozen while that key's action is pending (see OnReleaseConfirm). World
		// timers stop while paused, so a key released in the Esc menu is seen only after the pause; the
		// paused time then grew since this snapshot.
		if (PlaceDown && !bPendingPlace)
		{
			PlaceMenuSnap = MenuTickCount;
			PlacePauseSnap = GetPausedSeconds();
		}
		if (DeleteDown && !bPendingDelete)
		{
			DeleteMenuSnap = MenuTickCount;
			DeletePauseSnap = GetPausedSeconds();
		}
		bInputPrimed = true;
		bPlaceWasDown = PlaceDown;
		bNextWasDown = NextDown;
		bDeleteWasDown = DeleteDown;
	}

	/** The wheel only changes the symbol while the place key is held (otherwise it is the game's). */
	UFUNCTION()
	void OnWheelUp(FKey Key)
	{
		if (bAiming)
			ChangeSymbol(1);
	}

	UFUNCTION()
	void OnWheelDown(FKey Key)
	{
		if (bAiming)
			ChangeSymbol(-1);
	}

	void ChangeSymbol(int Step)
	{
		if (!IsInputAllowed())
			return;
		int Count = RunicMarkers::SymbolIds().Num();
		CurrentSymbol = (CurrentSymbol + Step + Count) % Count;
		SymbolChangeCounter++;
		// Not aiming and the HUD indicator shows the symbol: no flash on a surface.
		if (!bAiming && IsHudLive())
			return;
		UpdatePreview();
		if (!bAiming)
		{
			// Fallback without the HUD indicator: short look at the new symbol at the aimed point.
			System::ClearAndInvalidateTimerHandle(FlashTimer);
			FlashTimer = System::SetTimerDelegate(FTimerDynamicDelegate(this, n"OnFlashEnd"), RunicMarkers::FlashDuration, false);
		}
	}

	UFUNCTION()
	void OnFlashEnd()
	{
		if (!bAiming && !bPendingPlace)
			HidePreview();
	}

	// Delete key held: the rune that its release would delete glows red.
	UFUNCTION()
	void OnDeletePressed(FKey Key)
	{
		// An earlier release still waiting for its confirm is resolved now (its stored target).
		if (bPendingDelete)
			ResolvePendingDelete();
		System::ClearAndInvalidateTimerHandle(DeleteTimer);
		UpdateDeleteTarget();
		DeleteTimer = System::SetTimerDelegate(FTimerDynamicDelegate(this, n"UpdateDeleteTarget"), RunicMarkers::PreviewInterval, true);
	}

	UFUNCTION()
	void OnDeleteReleased(FKey Key)
	{
		System::ClearAndInvalidateTimerHandle(DeleteTimer);
		SetDeleteTarget(nullptr);
		// Remember what is aimed at now (what was just red); no re-trace at confirm.
		int Index = -1;
		PendingDeleteResult = FindDeleteTarget(Index);
		PendingDeleteTarget = PendingDeleteResult == ERunicPlaceResult::Deleted ? Markers[Index] : nullptr;
		HideDeleteAim();
		bPendingDelete = true;
		StartReleaseConfirm();
	}

	UFUNCTION()
	void UpdateDeleteTarget()
	{
		if (!IsKeyHeld(RunicMarkers::DeleteKey()))
		{
			// Safety net: the key reads up before the poll handled the release. Only drops the red
			// highlight; deleting is decided by the poll's release (OnDeleteReleased).
			System::ClearAndInvalidateTimerHandle(DeleteTimer);
			SetDeleteTarget(nullptr);
			HideDeleteAim();
			return;
		}
		int Index = -1;
		ERunicPlaceResult Result = FindDeleteTarget(Index);
		SetDeleteTarget(Result == ERunicPlaceResult::Deleted ? Markers[Index] : nullptr);
		if (bDeleteAimValid)
			ShowDeleteAimAt(DeleteAimLocation, DeleteAimRotation);
		else
			HideDeleteAim();
	}

	/** Shows the delete aim dot (spawned once, light off, scaled down). */
	void ShowDeleteAimAt(FVector Location, FRotator Rotation)
	{
		if (!IsValid(DeleteAimMaterial))
		{
			HideDeleteAim();
			return;
		}
		if (!IsValid(DeleteAim))
		{
			DeleteAim = Cast<ARunicMarker>(SpawnActor(ARunicMarker::StaticClass(), Location, FRotator::ZeroRotator));
			if (!IsValid(DeleteAim))
				return;
			DeleteAim.SetLightEnabled(false);
			// Actor X = surface normal = decal projection depth: keep it, shrink only the symbol.
			DeleteAim.SetActorScale3D(FVector(1.0f, RunicMarkers::DeleteAimScale, RunicMarkers::DeleteAimScale));
			// -1: not a symbol index (the aim actor is never in Markers, never saved).
			DeleteAim.SetSymbol(-1, DeleteAimMaterial);
		}
		DeleteAim.SetActorLocation(Location);
		DeleteAim.SetActorRotation(Rotation);
		DeleteAim.SetActorHiddenInGame(false);
	}

	void HideDeleteAim()
	{
		if (IsValid(DeleteAim))
			DeleteAim.SetActorHiddenInGame(true);
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

	/** Actors the aim traces ignore: the player, anything attached to them, our preview and delete aim dot. */
	void GetAimIgnore(AGothicCharacter Player, TArray<AActor>& OutIgnore)
	{
		Player.GetAttachedActors(OutIgnore, true, true);
		OutIgnore.Add(Player);
		if (IsValid(Preview))
			OutIgnore.Add(Preview);
		if (IsValid(DeleteAim))
			OutIgnore.Add(DeleteAim);
	}

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

		TArray<AActor> Ignore;
		GetAimIgnore(Player, Ignore);
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

	/** Place-key release: AimOk = OutLocation / OutRotation are where the current symbol would go. */
	ERunicPlaceResult ComputePlacement(FVector& OutLocation, FRotator& OutRotation)
	{
		if (!IsValid(GetSymbolMaterial(CurrentSymbol)))
			return ERunicPlaceResult::AssetsMissing;

		FHitResult Hit;
		FVector CamDir;
		ERunicPlaceResult Aim = ComputeAim(Hit, CamDir);
		if (Aim != ERunicPlaceResult::AimOk)
			return Aim;

		OutLocation = Hit.ImpactPoint + Hit.ImpactNormal * RunicMarkers::SurfaceOffset;
		OutRotation = RuneRotation(Hit.ImpactNormal, CamDir);
		return ERunicPlaceResult::AimOk;
	}

	/** Spawns a placed rune (no trace), drops the oldest above MaxMarkers and saves. */
	ERunicPlaceResult PlaceAt(FVector Location, FRotator Rotation, int Symbol)
	{
		if (!IsValid(SpawnRune(Location, Rotation, Symbol)))
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

	/**
	 * Delete-target visibility, used by both delete picks: the rune faces the camera (rune X = its surface
	 * normal; a rune facing away is on the far side of its surface, e.g. the back of a thin wall) and a
	 * Visibility trace from the camera to the rune hits nothing more than DeleteLosTolerance before it
	 * (no deleting through walls or characters).
	 */
	bool IsRuneVisibleFromCamera(ARunicMarker Rune, FVector CamLoc, const TArray<AActor>& Ignore)
	{
		if (!IsValid(Rune))
			return false;
		FVector RuneLoc = Rune.ActorLocation;
		if ((CamLoc - RuneLoc).DotProduct(Rune.ActorForwardVector) <= 0)
			return false;
		// Runes have no collision and sit SurfaceOffset off their surface (on the camera side, given the
		// facing check), so a clear path hits nothing up to the rune, at most its own surface just past it.
		ETraceTypeQuery TraceType = UCollisionProfile::ConvertToTraceType(ECollisionChannel::ECC_Visibility);
		FHitResult LosHit;
		if (System::LineTraceSingle(CamLoc, RuneLoc, TraceType, false, Ignore, EDrawDebugTrace::None, LosHit, true)
			&& CamLoc.Distance(LosHit.ImpactPoint) < CamLoc.Distance(RuneLoc) - RunicMarkers::DeleteLosTolerance)
			return false;
		return true;
	}

	/**
	 * Rune closest to the crosshair: smallest angle between the view direction and camera->rune, up to
	 * DeleteAimMaxAngleDeg, within MaxDistance + DeleteRadius of the player, in front of the player, and
	 * IsRuneVisibleFromCamera (facing check + camera->rune trace with DeleteLosTolerance).
	 * -1 = none; OutAngle = its angle (deg).
	 */
	int FindDeleteTargetByAngle(AGothicCharacter Player, FVector CamLoc, FVector CamDir,
		const TArray<AActor>& Ignore, float& OutAngle)
	{
		OutAngle = -1.0f;
		const FVector PlayerPos = Player.ActorLocation;
		const float MaxDist = RunicMarkers::GetMaxDistance() + RunicMarkers::DeleteRadius;

		int Best = -1;
		float BestAngle = RunicMarkers::DeleteAimMaxAngleDeg;
		for (int i = 0; i < Markers.Num(); i++)
		{
			if (!IsValid(Markers[i]))
				continue;
			FVector RuneLoc = Markers[i].ActorLocation;
			if (PlayerPos.Distance(RuneLoc) > MaxDist)
				continue;
			// Same rule as ComputeAim's BehindPlayer: nothing between the camera and the player.
			if ((RuneLoc - PlayerPos).DotProduct(CamDir) < 0)
				continue;
			FVector ToRune = RuneLoc - CamLoc;
			if (ToRune.Size() < 1.0f)
				continue;
			float CosAngle = Math::Clamp(CamDir.DotProduct(ToRune.GetSafeNormal()), -1.0f, 1.0f);
			float Angle = Math::RadiansToDegrees(Math::Acos(CosAngle));
			if (Angle > BestAngle)
				continue;
			if (!IsRuneVisibleFromCamera(Markers[i], CamLoc, Ignore))
				continue;
			Best = i;
			BestAngle = Angle;
		}
		if (Best >= 0)
			OutAngle = BestAngle;
		return Best;
	}

	/**
	 * Deleted = OutIndex is the rune to delete (nothing is destroyed here): first the rune closest to the
	 * crosshair (FindDeleteTargetByAngle), else the rune nearest to the aimed point within DeleteRadius
	 * that passes IsRuneVisibleFromCamera. Also sets the delete aim dot pose (bDeleteAimValid,
	 * DeleteAimLocation / Rotation: always the aimed point, never snapped onto the rune; the red light
	 * marks the target) and the DeleteSelectMode / DeleteSelectAngle shown in Debug.
	 */
	ERunicPlaceResult FindDeleteTarget(int& OutIndex)
	{
		OutIndex = -1;
		bDeleteAimValid = false;
		DeleteSelectMode = "none";
		DeleteSelectAngle = -1.0f;
		FHitResult Hit;
		FVector CamDir;
		ERunicPlaceResult Aim = ComputeAim(Hit, CamDir);
		if (Aim == ERunicPlaceResult::NoPlayer || Aim == ERunicPlaceResult::InConversation
			|| Aim == ERunicPlaceResult::InputBlocked)
			return Aim;

		// Usable aimed point for the hit-point rule and the aim dot. Runes have no collision, so the trace
		// hits the surface under them; non-static / too-far surfaces are still fine to delete from.
		// Blocked = aimed point not visible (no deleting through thin walls); a character in the way
		// must not delete the rune behind it.
		ERunicPlaceResult HitResult = ERunicPlaceResult::AimOk;
		if (Aim == ERunicPlaceResult::NoHit
			|| Aim == ERunicPlaceResult::BehindPlayer || Aim == ERunicPlaceResult::Blocked
			|| Aim == ERunicPlaceResult::RejectedCharacter)
			HitResult = Aim;
		else if (LastDistance > RunicMarkers::GetMaxDistance() + RunicMarkers::DeleteRadius)
			HitResult = ERunicPlaceResult::TooFar;
		if (HitResult == ERunicPlaceResult::AimOk)
		{
			// The aim dot always shows at the aimed point.
			bDeleteAimValid = true;
			DeleteAimLocation = Hit.ImpactPoint + Hit.ImpactNormal * RunicMarkers::SurfaceOffset;
			DeleteAimRotation = RuneRotation(Hit.ImpactNormal, CamDir);
		}

		// ComputeAim passed its player checks, so the player is valid here.
		auto Player = Cast<AGothicCharacter>(Gameplay::GetPlayerCharacter(0));
		if (!IsValid(Player))
			return ERunicPlaceResult::NoPlayer;
		FVector ViewDir;
		FVector CamLoc;
		MagicScript::GetCameraDirectionAndLocation(Player, ViewDir, CamLoc);
		ViewDir.Normalize();
		TArray<AActor> Ignore;
		GetAimIgnore(Player, Ignore);

		float Angle = -1.0f;
		int ByAngle = FindDeleteTargetByAngle(Player, CamLoc, ViewDir, Ignore, Angle);
		if (ByAngle >= 0)
		{
			OutIndex = ByAngle;
			DeleteSelectMode = "angle";
			DeleteSelectAngle = Angle;
			return ERunicPlaceResult::Deleted;
		}

		// Fallback: rune nearest to the aimed point (and visible from the camera).
		if (HitResult != ERunicPlaceResult::AimOk)
			return HitResult;

		int Best = -1;
		float BestDist = RunicMarkers::DeleteRadius;
		for (int i = 0; i < Markers.Num(); i++)
		{
			if (!IsValid(Markers[i]))
				continue;
			float D = Markers[i].ActorLocation.Distance(Hit.ImpactPoint);
			if (D > BestDist)
				continue;
			// E.g. a rune on the far face of a thin wall is within DeleteRadius of the hit point.
			if (!IsRuneVisibleFromCamera(Markers[i], CamLoc, Ignore))
				continue;
			Best = i;
			BestDist = D;
		}
		if (Best < 0)
			return ERunicPlaceResult::NothingToDelete;
		OutIndex = Best;
		DeleteSelectMode = "hit point";
		return ERunicPlaceResult::Deleted;
	}

	// ---------------------------------------------------------------- preview

	UFUNCTION()
	void UpdatePreview()
	{
		if (bAiming && !IsKeyHeld(RunicMarkers::PlaceKey()))
		{
			// Safety net: the key reads up before the poll handled the release. Only hides a stale
			// preview; placing is decided by the poll's release (OnPlaceReleased).
			System::ClearAndInvalidateTimerHandle(PreviewTimer);
			HidePreview();
			return;
		}
		// A released place waits for its confirm: the preview stays at its stored pose (no symbol flash).
		if (!bAiming && bPendingPlace)
			return;
		UMaterialInterface SymbolMat = GetSymbolMaterial(CurrentSymbol);
		FHitResult Hit;
		FVector CamDir;
		LastPreviewResult = IsValid(SymbolMat) ? ComputeAim(Hit, CamDir) : ERunicPlaceResult::AssetsMissing;
		if (LastPreviewResult != ERunicPlaceResult::AimOk)
		{
			HidePreview();
			return;
		}
		ShowPreviewAt(Hit.ImpactPoint + Hit.ImpactNormal * RunicMarkers::SurfaceOffset, RuneRotation(Hit.ImpactNormal, CamDir), CurrentSymbol);
	}

	void ShowPreviewAt(FVector Location, FRotator Rotation, int Symbol)
	{
		UMaterialInterface SymbolMat = GetSymbolMaterial(Symbol);
		if (!IsValid(SymbolMat))
		{
			HidePreview();
			return;
		}
		if (!IsValid(Preview))
		{
			Preview = Cast<ARunicMarker>(SpawnActor(ARunicMarker::StaticClass(), Location, FRotator::ZeroRotator));
			if (!IsValid(Preview))
				return;
			Preview.SetLightEnabled(false);
		}
		Preview.SetActorLocation(Location);
		Preview.SetActorRotation(Rotation);
		Preview.SetSymbol(Symbol, SymbolMat);
		Preview.SetActorHiddenInGame(false);
	}

	void HidePreview()
	{
		if (IsValid(Preview))
			Preview.SetActorHiddenInGame(true);
	}
}

/**
 * Counts ticks of the management UI (inventory, stats, map...) for C5 (see ReleaseConfirmDelay).
 * Assumed to tick only while open: UNVERIFIED, check the Debug "Menu ticks" line in-game.
 */
class URunicMarkersMenuWatch : UGothicModExt_WidgetExtension
{
	default AddToWidgetOfClass = n"/Game/UI/ManagementUI/W_ManagementUI_Main.W_ManagementUI_Main_C";

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		auto RuneState = URunicMarkersState::Get();
		if (IsValid(RuneState))
			RuneState.MenuTickCount++;
	}
}
