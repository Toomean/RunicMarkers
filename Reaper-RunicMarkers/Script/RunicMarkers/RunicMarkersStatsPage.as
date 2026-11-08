/**
 * Rune list on the game's Stats page (management UI), so players can find and remove old runes.
 * Pattern from the modkit's Example-StatsPage: UGothicModExt_WidgetExtension + the game's own text style
 * and generic button. Each rune is one button ("<symbol> - 32 m"), nearest first; clicking deletes it.
 * "Delete all runes" needs a second click within ConfirmSeconds.
 * Runes cannot change while the menu is open, so the list is rebuilt when it is first drawn, after a
 * delete, and when the player has moved since the last build (= the page was reopened elsewhere).
 */
namespace RunicStatsPage
{
	const float ConfirmSeconds = 5.0f;
	// Rebuild when the player moved more than this since the last build (cm).
	const float RebuildMoveThreshold = 100.0f;
}

/** One per rune button: the generic button's click delegate carries no payload. */
class URunicRuneButtonHandler : UObject
{
	UPROPERTY()
	URunicMarkersStatsExtension Owner;
	UPROPERTY()
	ARunicMarker Rune;

	UFUNCTION()
	void OnClicked()
	{
		if (Owner != nullptr)
			Owner.DeleteRune(Rune);
	}
}

class URunicMarkersStatsExtension : UGothicModExt_WidgetExtension
{
	default AddToWidgetOfClass = n"/Game/UI/ManagementUI/Stats/W_Stats_Main.W_Stats_Main_C";

	TSoftObjectPtr<UDataTable> TextStyle = n"/Game/UI/Texts/TS_Dialogue.TS_Dialogue";
	TSoftClassPtr<UButtonWidget> ButtonWidgetClass = n"WidgetBlueprint'/Game/UI/Common/W_GenericButton.W_GenericButton_C'";

	UPanelWidget m_ListParent;
	UAlkRichTextBlock m_HeaderText;
	UButtonWidget m_ClearAllButton;

	// Widgets of the current list (removed on rebuild) and their click handlers (kept alive here).
	UPROPERTY()
	TArray<UWidget> m_RowWidgets;
	UPROPERTY()
	TArray<URunicRuneButtonHandler> m_Handlers;
	// Label per entry of m_RowWidgets. The generic button seems to reset its label when it is added to the
	// page (in-game: every button read "Confirm"), so labels are applied after AddChild and again on the
	// next ticks.
	TArray<FString> m_RowLabels;
	FString m_ClearAllLabel = "Delete all runes";
	int m_LabelTicksLeft = 0;
	// Unique widget names: removed widgets keep their names until garbage collected.
	int m_BuildNumber = 0;
	int m_SeenChange = -1;

	bool m_bDirty = true;
	FVector m_BuiltAtLocation;
	float m_ConfirmTimeLeft = 0.0f;

	UFUNCTION(BlueprintOverride)
	void Initialize()
	{
		UUserWidget StatsPage = GetWidget();
		m_ListParent = StatsPage.GetWidgetFromName(n"ScrollBox_Content", UPanelWidget);
		if (!IsValid(m_ListParent))
		{
			Error("RunicMarkers: could not find the content area of the stats page.");
			return;
		}

		m_HeaderText = Cast<UAlkRichTextBlock>(StatsPage.ConstructWidget(UAlkRichTextBlock, n"RunicMarkersHeader"));
		if (IsValid(m_HeaderText))
		{
			m_HeaderText.SetTextStyleSet(FAssetPreload::BlockingLoad(TextStyle));
			m_ListParent.AddChild(m_HeaderText);
		}

		m_ClearAllButton = MakeButton(n"RunicMarkersClearAll");
		if (IsValid(m_ClearAllButton))
		{
			m_ClearAllButton.m_OnClickedBP.AddUFunction(this, n"OnClearAllClicked");
			m_ListParent.AddChild(m_ClearAllButton);
		}
		m_bDirty = true;
	}

	UButtonWidget MakeButton(FName WidgetName)
	{
		UUserWidget StatsPage = GetWidget();
		return Cast<UButtonWidget>(StatsPage.ConstructWidget(FAssetPreload::BlockingLoad(ButtonWidgetClass), WidgetName));
	}

	bool SetButtonLabel(UButtonWidget Button, FString Label)
	{
		// The label is a text block inside the widget blueprint (Example-StatsPage).
		if (!IsValid(Button))
			return false;
		auto LabelText = Button.GetWidgetFromName(n"TextBlock_Label", UTextBlock);
		if (!IsValid(LabelText))
			return false;
		// Only when it differs: this runs every tick, because the game sometimes resets the label to its
		// default ("Confirm"), e.g. when the keyboard layout / language changes while the page is open.
		if (LabelText.GetText().ToString() != Label)
			LabelText.SetText(FText::FromString(Label));
		return true;
	}

	void ApplyLabels()
	{
		SetButtonLabel(m_ClearAllButton, m_ClearAllLabel);
		for (int i = 0; i < m_RowWidgets.Num(); i++)
			SetButtonLabel(Cast<UButtonWidget>(m_RowWidgets[i]), m_RowLabels[i]);
	}

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		if (m_ConfirmTimeLeft > 0.0f)
		{
			m_ConfirmTimeLeft -= InDeltaTime;
			if (m_ConfirmTimeLeft <= 0.0f)
			{
				m_ClearAllLabel = "Delete all runes";
				m_LabelTicksLeft = 3;
			}
		}

		auto Player = Gameplay::GetPlayerCharacter(0);
		if (IsValid(Player) && Player.ActorLocation.Distance(m_BuiltAtLocation) > RunicStatsPage::RebuildMoveThreshold)
			m_bDirty = true;
		auto RuneState = URunicMarkersState::Get();
		if (IsValid(RuneState) && RuneState.ChangeCounter != m_SeenChange)
			m_bDirty = true;
		if (m_bDirty)
			Rebuild();
		ApplyLabels();
		if (m_LabelTicksLeft > 0)
		{
			m_LabelTicksLeft--;
			UpdateHeader();
		}
	}

	int m_ShownCount = 0;

	void UpdateHeader()
	{
		// Leading newline = gap above the section (no spacer widget precedent in the modkit). Two lines: the
		// text does not wrap, and one line was cut off in-game ("Click a rune to dele").
		if (IsValid(m_HeaderText))
			m_HeaderText.SetText(FText::FromString(f"\nRunic Markers: {m_ShownCount} / {RunicMarkers::MaxMarkers}\nClick a rune to delete it."));
	}

	void Rebuild()
	{
		m_bDirty = false;
		if (!IsValid(m_ListParent))
			return;
		for (int i = 0; i < m_RowWidgets.Num(); i++)
		{
			if (IsValid(m_RowWidgets[i]))
				m_RowWidgets[i].RemoveFromParent();
		}
		m_RowWidgets.Empty();
		m_RowLabels.Empty();
		if (IsValid(m_GapWidget))
			m_GapWidget.RemoveFromParent();
		m_Handlers.Empty();
		m_BuildNumber++;

		auto RuneState = URunicMarkersState::Get();
		auto Player = Gameplay::GetPlayerCharacter(0);
		if (!IsValid(RuneState) || !IsValid(Player))
			return;
		m_SeenChange = RuneState.ChangeCounter;
		m_BuiltAtLocation = Player.ActorLocation;

		// Nearest first (simple selection sort: at most 100 runes, rebuilt rarely).
		TArray<ARunicMarker> Sorted;
		for (int i = 0; i < RuneState.Markers.Num(); i++)
		{
			if (IsValid(RuneState.Markers[i]))
				Sorted.Add(RuneState.Markers[i]);
		}
		for (int i = 0; i < Sorted.Num(); i++)
		{
			int Best = i;
			for (int j = i + 1; j < Sorted.Num(); j++)
			{
				if (Sorted[j].ActorLocation.Distance(m_BuiltAtLocation) < Sorted[Best].ActorLocation.Distance(m_BuiltAtLocation))
					Best = j;
			}
			if (Best != i)
			{
				ARunicMarker Tmp = Sorted[i];
				Sorted[i] = Sorted[Best];
				Sorted[Best] = Tmp;
			}
		}

		m_ShownCount = Sorted.Num();

		for (int i = 0; i < Sorted.Num(); i++)
		{
			FString Where = RunicMarkers::DistanceText(m_BuiltAtLocation, Sorted[i].ActorLocation);
			UButtonWidget Button = MakeButton(FName(f"RunicMarkersRune{m_BuildNumber}_{i}"));
			if (!IsValid(Button))
				continue;
			auto Handler = Cast<URunicRuneButtonHandler>(NewObject(this, URunicRuneButtonHandler::StaticClass()));
			Handler.Owner = this;
			Handler.Rune = Sorted[i];
			Button.m_OnClickedBP.AddUFunction(Handler, n"OnClicked");
			m_Handlers.Add(Handler);
			m_ListParent.AddChild(Button);
			m_RowWidgets.Add(Button);
			m_RowLabels.Add(f"{RunicMarkers::SymbolName(Sorted[i].SymbolIndex)} - {Where}");
		}
		// Empty text block = gap below the list.
		UUserWidget StatsPage = GetWidget();
		auto Gap = Cast<UAlkRichTextBlock>(StatsPage.ConstructWidget(UAlkRichTextBlock, FName(f"RunicMarkersGap{m_BuildNumber}")));
		if (IsValid(Gap))
		{
			Gap.SetTextStyleSet(FAssetPreload::BlockingLoad(TextStyle));
			Gap.SetText(FText::FromString(" "));
			m_ListParent.AddChild(Gap);
			m_GapWidget = Gap;
		}
		ApplyLabels();
		UpdateHeader();
		m_LabelTicksLeft = 3;
	}

	UPROPERTY()
	UWidget m_GapWidget;

	void DeleteRune(ARunicMarker Rune)
	{
		auto RuneState = URunicMarkersState::Get();
		if (IsValid(RuneState))
			RuneState.DeleteRuneAt(RuneState.Markers.FindIndex(Rune));
		m_bDirty = true;
	}

	UFUNCTION()
	private void OnClearAllClicked()
	{
		auto RuneState = URunicMarkersState::Get();
		if (!IsValid(RuneState) || RuneState.Markers.Num() == 0)
			return;
		if (m_ConfirmTimeLeft <= 0.0f)
		{
			m_ConfirmTimeLeft = RunicStatsPage::ConfirmSeconds;
			m_ClearAllLabel = f"Click again to delete all {RuneState.Markers.Num()} runes";
			m_LabelTicksLeft = 3;
			return;
		}
		m_ConfirmTimeLeft = 0.0f;
		m_ClearAllLabel = "Delete all runes";
		RuneState.ClearAllRunes();
		m_bDirty = true;
	}
}
