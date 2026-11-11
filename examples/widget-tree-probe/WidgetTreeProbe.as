// Widget tree probe: example for Gothic 1 Remake mods (G1R Modkit, UnrealEngine-AngelScript).
// MIT License, see LICENSE in the Runic Markers repository root.
//
// Lists the widget tree of one game widget (name : class (parent: ...)) and shows it in an ImGui debug
// tool (start the game with -as-development-mode -ingametools, top menu bar: WidgetTreeProbe -> Debug).
// Changes nothing on the page. Runs in Initialize and once more on the first Tick (widgets may be added
// after Initialize); each run replaces the stored lines. Nested user widgets are listed indented below
// their entry, because a host's GetAllWidgets does not descend into them.
//
// Assembled from code verified in-game in Runic Markers (commits 29f6c08 / ff9d6d8, file
// RunicMarkersSettingsProbe.as); this standalone file was not compiled as-is. See README.md.

UCLASS()
class UWidgetTreeProbeStore : UObject
{
	UPROPERTY()
	TArray<FString> Lines;
	UPROPERTY()
	int RunCount = 0;
}

namespace WidgetTreeProbe
{
	const int MaxLines = 400;
	// How deep nested user widgets are opened (0 = host tree only).
	const int MaxDepth = 4;

	/** Storage without a subsystem: the class default object (written via UClass.GetDefaultObject()). */
	UWidgetTreeProbeStore GetStore()
	{
		return Cast<UWidgetTreeProbeStore>(UWidgetTreeProbeStore::StaticClass().GetDefaultObject());
	}
}

class UWidgetTreeProbeExtension : UGothicModExt_WidgetExtension
{
	// Target widget class (soft class path; set it to the widget you want to inspect).
	// Default: the Settings -> Game page (path taken verbatim from the game exe strings, exact match).
	default AddToWidgetOfClass = n"/Game/UI/CoreMenus/Settings/W_SettingsPage_Game.W_SettingsPage_Game_C";

	bool m_bTickProbeDone = false;

	UFUNCTION(BlueprintOverride)
	void Initialize()
	{
		RunProbe("init");
	}

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		if (m_bTickProbeDone)
			return;
		m_bTickProbeDone = true;
		RunProbe("tick");
	}

	bool IsFull(UWidgetTreeProbeStore ProbeStore)
	{
		return ProbeStore.Lines.Num() >= WidgetTreeProbe::MaxLines - 1;
	}

	FString DescribeWidget(UWidget W)
	{
		FString ParentName = "none";
		UPanelWidget Parent = W.GetParent();
		if (IsValid(Parent))
			ParentName = Parent.GetName().ToString();
		return f"{W.GetName().ToString()} : {W.Class.GetName().ToString()} (parent: {ParentName})";
	}

	void AddLine(UWidgetTreeProbeStore ProbeStore, FString Line)
	{
		ProbeStore.Lines.Add(Line);
		// Log output is not readable everywhere (e.g. no log file under CrossOver); the ImGui tool is the readout.
		Log(f"[WidgetTreeProbe] {Line}");
	}

	void RunProbe(FString When)
	{
		auto ProbeStore = WidgetTreeProbe::GetStore();
		if (!IsValid(ProbeStore))
			return;
		ProbeStore.RunCount++;
		ProbeStore.Lines.Empty();

		UUserWidget Host = GetWidget();
		if (!IsValid(Host))
		{
			AddLine(ProbeStore, f"[{When}] no host widget");
			return;
		}
		FString RootClass = "none";
		UWidget Root = Host.GetRootWidget();
		if (IsValid(Root))
			RootClass = Root.Class.GetName().ToString();

		TArray<UWidget> Widgets;
		Host.GetAllWidgets(Widgets);
		AddLine(ProbeStore, f"[{When}] host: {Host.Class.GetName().ToString()}   root: {RootClass}   widgets: {Widgets.Num()}");
		ListWidgets(ProbeStore, Widgets, "", 0);
	}

	/** Returns false when the line cap was hit (stop everything). */
	bool ListWidgets(UWidgetTreeProbeStore ProbeStore, const TArray<UWidget>& Widgets, FString Indent, int Depth)
	{
		for (int i = 0; i < Widgets.Num(); i++)
		{
			if (IsFull(ProbeStore))
			{
				AddLine(ProbeStore, f"... cut at {WidgetTreeProbe::MaxLines} lines");
				return false;
			}
			UWidget W = Widgets[i];
			if (!IsValid(W))
				continue;
			AddLine(ProbeStore, f"{Indent}{DescribeWidget(W)}");

			// Nested user widget: its own tree (the host's GetAllWidgets does not include it).
			if (Depth >= WidgetTreeProbe::MaxDepth)
				continue;
			UUserWidget Inner = Cast<UUserWidget>(W);
			if (!IsValid(Inner))
				continue;
			TArray<UWidget> InnerWidgets;
			Inner.GetAllWidgets(InnerWidgets);
			if (!ListWidgets(ProbeStore, InnerWidgets, f"{Indent}    ", Depth + 1))
				return false;
		}
		return true;
	}
}

// Debug readout; visible with -ingametools (top menu bar: WidgetTreeProbe).
class UIngameTool_WidgetTreeProbe : UIngameTool
{
	default Category = "WidgetTreeProbe";
	default MenuPath = "WidgetTreeProbe.Debug";
	default Title = "WidgetTreeProbe";

	UFUNCTION(BlueprintOverride)
	void DrawImGuiWindow()
	{
		auto ProbeStore = WidgetTreeProbe::GetStore();
		if (!IsValid(ProbeStore))
		{
			ImGui::Text("Store: none");
			return;
		}
		ImGui::SeparatorText("Widget tree probe");
		ImGui::Text(f"Probe runs: {ProbeStore.RunCount}   lines: {ProbeStore.Lines.Num()}");
		for (int i = 0; i < ProbeStore.Lines.Num(); i++)
			ImGui::Text(ProbeStore.Lines[i]);
	}
}
