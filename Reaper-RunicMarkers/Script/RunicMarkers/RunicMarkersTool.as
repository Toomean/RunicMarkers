// Diagnostics panel; visible with -ingametools (top menu bar: RunicMarkers).
class UIngameTool_RunicMarkers : UIngameTool
{
	default Category = "RunicMarkers";
	default MenuPath = "RunicMarkers.Debug";
	default Title = "RunicMarkers";

	UFUNCTION(BlueprintOverride)
	void DrawImGuiWindow()
	{
		auto Sub = URunicMarkersState::Get();
		if (!IsValid(Sub))
		{
			ImGui::Text("Subsystem alive: no");
			return;
		}

		FString Started = Sub.bStarted ? "yes" : "no";
		ImGui::Text(f"Subsystem alive: yes (started: {Started})");
		FString Bound = Sub.IsKeyBound() ? "yes" : "no";
		ImGui::Text(f"Wheel bound: {Bound}   keys: place {Input::Key_GetDisplayName(RunicMarkers::PlaceKey()).ToString()}, next symbol {Input::Key_GetDisplayName(RunicMarkers::NextSymbolKey()).ToString()}, delete {Input::Key_GetDisplayName(RunicMarkers::DeleteKey()).ToString()}");
		ImGui::Text(f"Rune assets: {Sub.AssetStatus}");
		ImGui::Text(f"Current symbol: {Sub.CurrentSymbol} {Sub.GetCurrentSymbolId()}");
		ImGui::Text(f"Max distance: {RunicMarkers::GetMaxDistance()} cm");
		ImGui::Text(f"Glow: {RunicMarkers::GetLightCandela()} cd");
		ImGui::Separator();
		ImGui::Text(f"Places: {Sub.PressCount}   aiming: {Sub.bAiming}   place down: {Sub.IsKeyHeld(RunicMarkers::PlaceKey())}   delete down: {Sub.IsKeyHeld(RunicMarkers::DeleteKey())}");
		ImGui::Text(f"Last place: {RunicPlaceResultToString(Sub.LastResult)}");
		ImGui::Text(f"Last preview: {RunicPlaceResultToString(Sub.LastPreviewResult)}");
		ImGui::Text(f"Last delete: {RunicPlaceResultToString(Sub.LastDeleteResult)}");
		// Updated while the delete key is held (and at its release): how the red rune was chosen.
		FString DeleteAngle = "-";
		if (Sub.DeleteSelectAngle >= 0.0f)
			DeleteAngle = f"{Sub.DeleteSelectAngle} deg";
		FString DotShown = Sub.bDeleteAimValid ? "yes" : "no";
		ImGui::Text(f"Delete aim: {Sub.DeleteSelectMode}   angle: {DeleteAngle} (max {RunicMarkers::DeleteAimMaxAngleDeg})   dot pose: {DotShown}");
		ImGui::Text(f"Menu ticks (inventory etc. open): {Sub.MenuTickCount}");
		// C7: the C7 signal is the pause part (GetPausedSeconds = Unpaused - game time); the dilation /
		// frame-clamp part (Real - Unpaused) is shown for reference only, it is not used for the cancel.
		float64 DilationPart = Sub.World.RealTimeSeconds - Sub.World.UnpausedTimeSeconds;
		ImGui::Text(f"Paused time (C7 signal): {Sub.GetPausedSeconds()} s   dilation/clamp (not used): {DilationPart} s");
		FString HudLive = Sub.IsHudLive() ? "yes" : "no";
		ImGui::Text(f"HUD indicator live: {HudLive}   host: {Sub.HudHostStatus}   HUD ticks: {Sub.HudTickCount}   symbol changes: {Sub.SymbolChangeCounter}");
		ImGui::Text(f"Hit actor: {Sub.LastHitActorName}");
		ImGui::Text(f"Hit component: {Sub.LastHitComponentName} ({Sub.LastHitMobility})");
		ImGui::Text(f"ImpactPoint: {Sub.LastImpactPoint.ToString()}");
		ImGui::Text(f"ImpactNormal: {Sub.LastImpactNormal.ToString()}");
		ImGui::Text(f"Distance from player: {Sub.LastDistance}");
		ImGui::Separator();
		ImGui::Text(f"Markers: {Sub.Markers.Num()} / {RunicMarkers::MaxMarkers}");

		ImGui::SeparatorText("Persistence");
		ImGui::Text(f"World: {Sub.World.Name.ToString()}   Start() calls: {Sub.StartCount}");
		ImGui::Text(f"Status: {Sub.PersistenceStatus}");

		ImGui::Text(f"Key rows: {Sub.KeyRowsStatus}");
	}
}
