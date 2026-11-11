/**
 * Settings -> Game page extension that builds our key rows (RunicMarkersKeyRows.as): not in Initialize but on
 * the first Tick where the "[Mod] Runic Markers" section header exists and the page's child count has been
 * stable for RunicKeyRows::StableTicksNeeded ticks (or after RunicKeyRows::MaxWaitTicks), appended at the end of
 * the list. After the build, every Tick re-applies the row names and checks the row entries.
 */
class URunicMarkersKeyRowsPage : UGothicModExt_WidgetExtension
{
	// Path taken verbatim from the game exe strings (exact match), not from the modkit.
	default AddToWidgetOfClass = n"/Game/UI/CoreMenus/Settings/W_SettingsPage_Game.W_SettingsPage_Game_C";

	// Fallback layout only (loaded only when used).
	TSoftObjectPtr<UDataTable> TextStyle = n"/Game/UI/Texts/TS_Dialogue.TS_Dialogue";
	// The game's settings row (path verbatim from the exe strings) and its key box widget (path from the pak
	// listing).
	TSoftClassPtr<UUserWidget> RowWidgetClass = n"WidgetBlueprint'/Game/UI/CoreMenus/Settings/W_SettingsRow.W_SettingsRow_C'";
	TSoftClassPtr<UUserWidget> KeyWidgetClass = n"WidgetBlueprint'/Game/UI/CoreMenus/Settings/W_Setting_KeyMapping_KeySelector.W_Setting_KeyMapping_KeySelector_C'";

	// Key rows (RunicMarkersKeyRows.as), per page instance: handlers kept alive here; per key (index = key
	// index, null where there is none) the row name, the row entry and the widget we put into it.
	UPROPERTY()
	TArray<URunicKeyRowHandler> m_KeyRowHandlers;
	UPROPERTY()
	TArray<UTextBlock> m_KeyRowLabels;
	UPROPERTY()
	TArray<UPanelWidget> m_KeyRowEntries;
	UPROPERTY()
	TArray<UWidget> m_KeyRowEntryWidgets;
	bool m_bKeyRowsBuilt = false;
	int m_KeyRowsWaitTicks = 0;
	// Build readiness: VerticalBox_Content child count last tick and for how many ticks it stayed unchanged.
	int m_LastContentCount = -1;
	int m_StableTicks = 0;
	bool m_bEntryWarned = false;

	UFUNCTION(BlueprintOverride)
	void Initialize()
	{
		m_bKeyRowsBuilt = false;
		m_KeyRowsWaitTicks = 0;
		m_LastContentCount = -1;
		m_StableTicks = 0;
		m_bEntryWarned = false;
		m_KeyRowHandlers.Empty();
		m_KeyRowLabels.Empty();
		m_KeyRowEntries.Empty();
		m_KeyRowEntryWidgets.Empty();
	}

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		if (!m_bKeyRowsBuilt)
		{
			TryBuildKeyRows();
			return;
		}
		// Every tick (three text compares; writes only on a difference): the row blueprint may reset its name
		// on page reopen / tab switch without a new Initialize.
		RunicKeyRows::ApplyRowLabels(m_KeyRowLabels);
		if (!m_bEntryWarned)
			m_bEntryWarned = RunicKeyRows::CheckEntries(m_KeyRowEntries, m_KeyRowEntryWidgets);
	}

	/**
	 * Builds the key rows once the mod section header exists and VerticalBox_Content's child count stayed
	 * unchanged for StableTicksNeeded ticks (or after the wait limit).
	 */
	void TryBuildKeyRows()
	{
		UUserWidget Host = GetWidget();
		if (!IsValid(Host))
			return;
		m_KeyRowsWaitTicks++;
		bool bHeader = IsValid(RunicKeyRows::FindModSectionHeader(Host));
		int Count = -1;
		UPanelWidget Content = Host.GetWidgetFromName(n"VerticalBox_Content", UPanelWidget);
		if (IsValid(Content))
			Count = Content.GetChildrenCount();
		if (bHeader && Count == m_LastContentCount)
			m_StableTicks++;
		else
			m_StableTicks = 0;
		m_LastContentCount = Count;

		FString Where = f"after the mod section (tick {m_KeyRowsWaitTicks})";
		if (!bHeader || m_StableTicks < RunicKeyRows::StableTicksNeeded)
		{
			if (m_KeyRowsWaitTicks < RunicKeyRows::MaxWaitTicks)
				return;
			if (bHeader)
				Where = f"page child count not stable after {m_KeyRowsWaitTicks} ticks, appended at the end";
			else
				Where = f"mod section header not found after {m_KeyRowsWaitTicks} ticks, appended at the end";
		}
		m_bKeyRowsBuilt = true;
		UClass RowClass = FAssetPreload::BlockingLoad(RowWidgetClass);
		UClass KeyClass = FAssetPreload::BlockingLoad(KeyWidgetClass);
		RunicKeyRows::BuildKeyRows(Host, RowClass, KeyClass, TextStyle, Where, this, m_KeyRowHandlers, m_KeyRowLabels,
			m_KeyRowEntries, m_KeyRowEntryWidgets);
	}
}
