/**
 * Key-binding rows on the Settings -> Game page (0.2). Per key one of the game's own settings rows
 * (W_SettingsRow_C: name left in Text_Name, entry right in SizeBox_SettingsEntry). The entry holds the game's own
 * key box W_Setting_KeyMapping_KeySelector_C (as on the Key Bindings page) and we drive its inner UMG
 * UInputKeySelector named "InputKeySelector". Key box fallback (decided once: class not loaded, construct failed
 * or no inner selector after adding it): our own engine-styled UInputKeySelector in the row.
 * Built once per page instance from URunicMarkersKeyRowsPage.Tick (RunicMarkersKeyRowsPage.as) on
 * a tick where the "[Mod] Runic Markers" section header exists (the modkit adds that section after the page's
 * Initialize) and VerticalBox_Content's child count has not changed for 2 ticks (the section's rows are in),
 * appended at the end of VerticalBox_Content, so after the mod section's rows; never moved. Not ready after
 * MaxWaitTicks: appended at the end anyway, the status says so.
 * Row fallback when the row class does not load or a row lacks a named child (decided once): a text label above
 * the selector, both directly in VerticalBox_Content; the build status says so, and the key handler statuses
 * (rebind results) of fallback keys end with FallbackNote.
 * A selected key is written to the URunicMarkersKeyConfig default object and saved (SaveConfig ->
 * GameUserSettings.ini); key polling reads that object every poll, so the new key works at once.
 * Rejected (the selector shows the old key again): invalid keys, Escape, left / right mouse button (clicking
 * elsewhere to cancel would bind them; also attack / block) and a key used by another of our three keys.
 */
namespace RunicKeyRows
{
	// 0 = place, 1 = next symbol, 2 = delete.
	const int NumKeys = 3;
	// Build anyway (at the end of the list) when not ready (header + stable child count) after this many page ticks.
	const int MaxWaitTicks = 300;
	// Ticks VerticalBox_Content's child count must stay unchanged (with the header present) before the build.
	const int StableTicksNeeded = 2;
	const FString ModSectionTitle = "Runic Markers";
	const FString FallbackNote = " [FALLBACK layout]";

	FString KeyTitle(int KeyIndex)
	{
		if (KeyIndex == 0)
			return "Place key";
		if (KeyIndex == 1)
			return "Next symbol key";
		return "Delete key";
	}

	/** Short name for status lines ("place key set to X"). */
	FString KeyShortName(int KeyIndex)
	{
		if (KeyIndex == 0)
			return "place";
		if (KeyIndex == 1)
			return "next symbol";
		return "delete";
	}

	FName RowWidgetName(int KeyIndex)
	{
		return FName(f"RunicMarkersKeyRow_{KeyIndex}");
	}

	/** Fallback layout only. */
	FName LabelWidgetName(int KeyIndex)
	{
		return FName(f"RunicMarkersKeyLabel_{KeyIndex}");
	}

	FName SelectorWidgetName(int KeyIndex)
	{
		return FName(f"RunicMarkersKeySelector_{KeyIndex}");
	}

	FKey GetKey(int KeyIndex)
	{
		if (KeyIndex == 0)
			return RunicMarkers::PlaceKey();
		if (KeyIndex == 1)
			return RunicMarkers::NextSymbolKey();
		return RunicMarkers::DeleteKey();
	}

	FString KeyText(FKey Key)
	{
		return Input::Key_GetDisplayName(Key).ToString();
	}

	FString KeysText()
	{
		return f"keys: {KeyText(GetKey(0))} / {KeyText(GetKey(1))} / {KeyText(GetKey(2))}";
	}

	void SetStatus(FString Status)
	{
		Log(f"[RunicMarkers][KeyRows] {Status}");
		// The settings page may also be open in the main menu, where this world subsystem may not exist.
		auto RuneState = URunicMarkersState::Get();
		if (IsValid(RuneState))
			RuneState.KeyRowsStatus = Status;
	}

	/** OnKeySelected of row KeyIndex: validate, store, save; otherwise show the old key again. */
	void ApplySelectedKey(int KeyIndex, FKey NewKey, UInputKeySelector Selector, FString Note)
	{
		FKey OldKey = GetKey(KeyIndex);
		// Same as the current key: nothing to do. This is also the path of the OnKeySelected that our own
		// SetSelectedKey calls below fire again (seen in-game), so they cannot loop or save twice.
		if (NewKey == OldKey)
			return;
		FString Reject = "";
		if (!Input::Key_IsValid(NewKey))
			Reject = "no valid key";
		else if (NewKey == EKeys::Escape)
			Reject = "Escape";
		else if (NewKey == EKeys::LeftMouseButton || NewKey == EKeys::RightMouseButton)
			Reject = "left / right mouse button not allowed";
		else
		{
			for (int i = 0; i < NumKeys; i++)
			{
				if (i != KeyIndex && GetKey(i) == NewKey)
					Reject = f"{KeyText(NewKey)} is already the {KeyShortName(i)} key";
			}
		}
		if (Reject != "")
		{
			if (IsValid(Selector))
				Selector.SetSelectedKey(FInputChord(OldKey));
			SetStatus(f"{KeyShortName(KeyIndex)} key kept {KeyText(OldKey)} ({Reject}){Note}");
			return;
		}

		URunicMarkersKeyConfig Config = RunicMarkers::GetKeyConfigForWrite();
		if (!IsValid(Config))
		{
			if (IsValid(Selector))
				Selector.SetSelectedKey(FInputChord(OldKey));
			SetStatus(f"FAIL: key config default object not found{Note}");
			return;
		}
		if (KeyIndex == 0)
			Config.PlaceKey = NewKey;
		else if (KeyIndex == 1)
			Config.NextSymbolKey = NewKey;
		else
			Config.DeleteKey = NewKey;
		Config.SaveConfig();
		// Show the stored key again, in case the key box blueprint's own OnKeySelected changed what it shows.
		if (IsValid(Selector))
			Selector.SetSelectedKey(FInputChord(NewKey));
		SetStatus(f"{KeyShortName(KeyIndex)} key set to {KeyText(NewKey)}{Note}");
	}

	/** Our row KeyIndex on the page (null = none, or the fallback layout is used). */
	UUserWidget FindRow(UUserWidget Host, int KeyIndex)
	{
		return Host.GetWidgetFromName(RowWidgetName(KeyIndex), UUserWidget);
	}

	/** Game key box widget of key KeyIndex (inside our row). */
	FName KeyWidgetName(int KeyIndex)
	{
		return FName(f"RunicMarkersKeyWidget_{KeyIndex}");
	}

	/** Our selector setup (also applied to the game key box's inner selector). */
	void SetupSelector(UInputKeySelector Selector)
	{
		Selector.SetAllowModifierKeys(false);
		Selector.SetAllowGamepadKeys(false);
		TArray<FKey> EscapeKeys;
		EscapeKeys.Add(EKeys::Escape);
		Selector.SetEscapeKeys(EscapeKeys);
		Selector.SetKeySelectionText(FText::FromString("Press a key..."));
	}

	/** New selector for key KeyIndex (not added anywhere yet), null on failure. */
	UInputKeySelector MakeSelector(UUserWidget Host, int KeyIndex)
	{
		UInputKeySelector Selector = Cast<UInputKeySelector>(Host.ConstructWidget(UInputKeySelector, SelectorWidgetName(KeyIndex)));
		if (!IsValid(Selector))
			return nullptr;
		SetupSelector(Selector);
		return Selector;
	}

	/** The "[Mod] Runic Markers" section header on Host, or null. */
	UUserWidget FindModSectionHeader(UUserWidget Host)
	{
		TArray<UWidget> Widgets;
		Host.GetAllWidgets(Widgets);
		for (int i = 0; i < Widgets.Num(); i++)
		{
			if (!IsValid(Widgets[i]) || !Widgets[i].Class.GetName().ToString().StartsWith("W_SettingsSectionHeader_C"))
				continue;
			UUserWidget Header = Cast<UUserWidget>(Widgets[i]);
			if (!IsValid(Header))
				continue;
			UTextBlock Title = Header.GetWidgetFromName(n"TextBlock_Title", UTextBlock);
			if (IsValid(Title) && Title.GetText().ToString().Contains(ModSectionTitle))
				return Header;
		}
		return nullptr;
	}

	/**
	 * Builds the rows at the end of VerticalBox_Content of Host (Where = for the status). A key whose row (or
	 * fallback selector) is already on the page (Initialize ran again on this widget) is reused, never
	 * constructed again; a reused row without a usable selector is skipped. Per key (index = key index, null
	 * where there is none): Text_Name to OutLabels, SizeBox_SettingsEntry to OutEntries, the widget put into
	 * that entry (game key box or our selector) to OutEntryWidgets. Handlers go to OutHandlers (keep them alive).
	 */
	void BuildKeyRows(UUserWidget Host, UClass RowClass, UClass KeyWidgetClass, TSoftObjectPtr<UDataTable> TextStyle,
		FString Where, UObject HandlerOuter, TArray<URunicKeyRowHandler>& OutHandlers, TArray<UTextBlock>& OutLabels,
		TArray<UPanelWidget>& OutEntries, TArray<UWidget>& OutEntryWidgets)
	{
		OutHandlers.Empty();
		OutLabels.Empty();
		OutEntries.Empty();
		OutEntryWidgets.Empty();
		if (!IsValid(Host))
		{
			SetStatus("no host widget");
			return;
		}
		UPanelWidget Content = Host.GetWidgetFromName(n"VerticalBox_Content", UPanelWidget);
		if (!IsValid(Content))
		{
			SetStatus("VerticalBox_Content not found, no rows added");
			return;
		}

		// Row layout decided once: game rows while the class loaded and a constructed row has both named children.
		bool bGameRows = IsValid(RowClass);
		FString FallbackReason = bGameRows ? "" : "W_SettingsRow_C not loaded";
		// Key box decided once: the game's key box while its class loaded and it has the inner selector.
		bool bGameKeyBox = IsValid(KeyWidgetClass);
		FString KeyBoxReason = bGameKeyBox ? "" : "W_Setting_KeyMapping_KeySelector_C not loaded";
		int Added = 0;
		int Reused = 0;
		int Skipped = 0;
		int FallbackCount = 0;
		int GameKeyBoxCount = 0;
		int EngineKeyBoxCount = 0;
		for (int i = 0; i < NumKeys; i++)
		{
			UInputKeySelector Selector = nullptr;
			UWidget EntryWidget = nullptr;
			UTextBlock RowName = nullptr;
			UPanelWidget Entry = nullptr;
			bool bFallback = false;
			UUserWidget Row = FindRow(Host, i);
			if (IsValid(Row))
			{
				// Reused row: its game key box (and that one's inner selector) or our selector.
				RowName = Row.GetWidgetFromName(n"Text_Name", UTextBlock);
				Entry = Row.GetWidgetFromName(n"SizeBox_SettingsEntry", UPanelWidget);
				UUserWidget KeyWidget = Row.GetWidgetFromName(KeyWidgetName(i), UUserWidget);
				if (IsValid(KeyWidget))
				{
					Selector = KeyWidget.GetWidgetFromName(n"InputKeySelector", UInputKeySelector);
					EntryWidget = KeyWidget;
					if (IsValid(Selector))
						GameKeyBoxCount++;
				}
				else
				{
					Selector = Row.GetWidgetFromName(SelectorWidgetName(i), UInputKeySelector);
					EntryWidget = Selector;
					if (IsValid(Selector))
						EngineKeyBoxCount++;
				}
				if (IsValid(Selector))
					Reused++;
			}
			else
			{
				Selector = Host.GetWidgetFromName(SelectorWidgetName(i), UInputKeySelector);
				if (IsValid(Selector))
				{
					Reused++;
					bFallback = true;
				}
				else
				{
					if (bGameRows)
					{
						// Added to the page first: a freshly constructed blueprint widget has an empty widget tree
						// until it is in a live panel.
						Row = Cast<UUserWidget>(Host.ConstructWidget(RowClass, RowWidgetName(i)));
						if (IsValid(Row))
						{
							Content.AddChild(Row);
							RowName = Row.GetWidgetFromName(n"Text_Name", UTextBlock);
							Entry = Row.GetWidgetFromName(n"SizeBox_SettingsEntry", UPanelWidget);
						}
						if (!IsValid(RowName) || !IsValid(Entry))
						{
							// That row is removed again; this and every later key use the fallback.
							if (IsValid(Row))
								Row.RemoveFromParent();
							bGameRows = false;
							FallbackReason = "row lacks Text_Name / SizeBox_SettingsEntry (after AddChild)";
							Row = nullptr;
							RowName = nullptr;
							Entry = nullptr;
						}
					}

					if (bGameRows && bGameKeyBox)
					{
						// The game's key box, into the row's entry first (the row is live), then its inner selector.
						UUserWidget KeyWidget = Cast<UUserWidget>(Host.ConstructWidget(KeyWidgetClass, KeyWidgetName(i)));
						if (IsValid(KeyWidget))
						{
							Entry.ClearChildren();
							Entry.AddChild(KeyWidget);
							Selector = KeyWidget.GetWidgetFromName(n"InputKeySelector", UInputKeySelector);
						}
						if (IsValid(Selector))
						{
							SetupSelector(Selector);
							EntryWidget = KeyWidget;
							GameKeyBoxCount++;
						}
						else
						{
							// Removed again; this and every later key use our engine selector.
							bGameKeyBox = false;
							if (IsValid(KeyWidget))
							{
								KeyWidget.RemoveFromParent();
								KeyBoxReason = "no inner InputKeySelector (after AddChild)";
							}
							else
								KeyBoxReason = "W_Setting_KeyMapping_KeySelector_C construct failed";
						}
					}
					if (!IsValid(Selector))
					{
						Selector = MakeSelector(Host, i);
						EntryWidget = Selector;
						if (IsValid(Selector) && bGameRows)
						{
							Entry.ClearChildren();
							Entry.AddChild(Selector);
							EngineKeyBoxCount++;
						}
					}
					if (!IsValid(Selector) && IsValid(Row))
					{
						// No selector for an already added row: take the row out again (skipped below).
						Row.RemoveFromParent();
						Row = nullptr;
					}
					if (IsValid(Selector))
					{
						Added++;
						if (bGameRows)
						{
							RowName.SetText(FText::FromString(KeyTitle(i)));
						}
						else
						{
							// Row fallback: text label above the selector.
							bFallback = true;
							UAlkRichTextBlock Label = Cast<UAlkRichTextBlock>(Host.ConstructWidget(UAlkRichTextBlock, LabelWidgetName(i)));
							if (IsValid(Label))
							{
								Label.SetTextStyleSet(FAssetPreload::BlockingLoad(TextStyle));
								Label.SetText(FText::FromString(f"Runic Markers: {KeyTitle(i)}"));
								Content.AddChild(Label);
							}
							Content.AddChild(Selector);
						}
					}
				}
			}

			if (!IsValid(Selector))
			{
				Skipped++;
				Log(f"[RunicMarkers][KeyRows] {KeyShortName(i)} key: no selector (row reused without it, or construct failed), skipped");
				OutLabels.Add(nullptr);
				OutEntries.Add(nullptr);
				OutEntryWidgets.Add(nullptr);
				continue;
			}
			if (bFallback)
			{
				FallbackCount++;
				Entry = nullptr;
				EntryWidget = nullptr;
			}
			OutLabels.Add(RowName);
			OutEntries.Add(Entry);
			OutEntryWidgets.Add(EntryWidget);
			Selector.SetSelectedKey(FInputChord(GetKey(i)));

			auto Handler = Cast<URunicKeyRowHandler>(NewObject(HandlerOuter, URunicKeyRowHandler::StaticClass()));
			Handler.KeyIndex = i;
			Handler.Selector = Selector;
			if (bFallback)
				Handler.Note = FallbackNote;
			Selector.OnKeySelected.AddUFunction(Handler, n"OnKeySelected");
			OutHandlers.Add(Handler);
		}
		FString Layout = "game rows";
		if (FallbackCount > 0)
		{
			if (FallbackReason == "")
				FallbackReason = "reused fallback widgets";
			Layout = f"FALLBACK layout for {FallbackCount}: {FallbackReason}";
		}
		FString KeyBox = f"game key box: {GameKeyBoxCount}";
		if (EngineKeyBoxCount > 0)
		{
			if (KeyBoxReason == "")
				KeyBoxReason = "reused engine key boxes";
			KeyBox = f"{KeyBox}, engine key box: {EngineKeyBoxCount} ({KeyBoxReason})";
		}
		SetStatus(f"rows added: {Added}, reused: {Reused}, skipped: {Skipped}, {Layout}, {KeyBox}; {Where} ({KeysText()})");
	}

	/**
	 * Sets our rows' names again where they differ (the row blueprint may reset Text_Name when constructed, e.g. on
	 * page reopen / tab switch). Every tick after the build; writes only on a difference.
	 */
	void ApplyRowLabels(TArray<UTextBlock>& Labels)
	{
		for (int i = 0; i < Labels.Num() && i < NumKeys; i++)
		{
			if (IsValid(Labels[i]) && Labels[i].GetText().ToString() != KeyTitle(i))
				Labels[i].SetText(FText::FromString(KeyTitle(i)));
		}
	}

	/**
	 * Cheap per-tick guard: true (and the status says so) when a row's SizeBox_SettingsEntry no longer holds
	 * the widget we put there (game key box or our selector) as its child. Nothing is rebuilt.
	 */
	bool CheckEntries(TArray<UPanelWidget>& Entries, TArray<UWidget>& EntryWidgets)
	{
		for (int i = 0; i < Entries.Num() && i < EntryWidgets.Num(); i++)
		{
			if (!IsValid(Entries[i]) || !IsValid(EntryWidgets[i]))
				continue;
			int Count = Entries[i].GetChildrenCount();
			UWidget First = nullptr;
			if (Count > 0)
				First = Entries[i].GetChildAt(0);
			UWidget Ours = EntryWidgets[i];
			if (Count == 0 || First != Ours)
			{
				SetStatus(f"WARNING: {KeyShortName(i)} row entry no longer holds our key box ({Count} children)");
				return true;
			}
		}
		return false;
	}
}

/** One per key row: OnKeySelected carries only the chord, not which row. */
class URunicKeyRowHandler : UObject
{
	int KeyIndex = 0;
	// Appended to status lines (fallback layout note).
	FString Note = "";
	UPROPERTY()
	UInputKeySelector Selector;

	UFUNCTION()
	void OnKeySelected(FInputChord SelectedKey)
	{
		RunicKeyRows::ApplySelectedKey(KeyIndex, SelectedKey.Key, Selector, Note);
	}
}
