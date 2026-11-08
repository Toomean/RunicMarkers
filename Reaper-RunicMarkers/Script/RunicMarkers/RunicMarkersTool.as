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
		ImGui::Text(f"Keys bound: {Bound} (hold/release T place, Y next symbol, U delete)");
		ImGui::Text(f"Rune assets: {Sub.AssetStatus}");
		ImGui::Text(f"Current symbol: {Sub.CurrentSymbol} {Sub.GetCurrentSymbolId()}");
		ImGui::Text(f"Max distance: {RunicMarkers::GetMaxDistance()} cm");
		ImGui::Text(f"Glow: {RunicMarkers::GetLightCandela()} cd");
		ImGui::Separator();
		ImGui::Text(f"Places: {Sub.PressCount}   aiming: {Sub.bAiming}   T down: {Sub.IsKeyHeld(Sub.PlaceKey)}   U down: {Sub.IsKeyHeld(Sub.DeleteKey)}");
		ImGui::Text(f"Last place: {RunicPlaceResultToString(Sub.LastResult)}");
		ImGui::Text(f"Last preview: {RunicPlaceResultToString(Sub.LastPreviewResult)}");
		ImGui::Text(f"Last delete: {RunicPlaceResultToString(Sub.LastDeleteResult)}");
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
	}
}
