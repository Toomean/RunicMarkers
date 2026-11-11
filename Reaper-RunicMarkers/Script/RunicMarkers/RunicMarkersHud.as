/**
 * Current-symbol indicator on the HUD: one line of text, bottom centre, shown while the place key is held
 * and for RunicMarkers::SymbolIndicatorDuration after a symbol change. Hosted by the HUD notification
 * container (registered in the modkit's Script/UI/GothicHUD.as; assumed present during gameplay, UNVERIFIED).
 * Text block made like the Stats page section (RunicMarkersStatsPage.as). The root widget type of the host
 * is unknown, so the slot setup tries canvas, then overlay, then any panel; Debug shows which one was used.
 * Canvas root only: a rune image (non-VT UI texture T_RuneIcon_<symbol>, RunicMarkers::SymbolIconPath) sits
 * right above the text. If the image is missing the text still works; Debug then shows "icons: ...".
 */
class URunicMarkersHudExtension : UGothicModExt_WidgetExtension
{
	default AddToWidgetOfClass = n"/Game/UI/Notifications/W_NotificationMain.W_NotificationMain_C";

	TSoftObjectPtr<UDataTable> TextStyle = n"/Game/UI/Texts/TS_Dialogue.TS_Dialogue";

	UPROPERTY()
	UAlkRichTextBlock m_Text;
	// Rune image above the text (canvas root only; null on the overlay / panel paths).
	UPROPERTY()
	UImage m_Icon;
	// Icon texture per symbol index, loaded on first use (m_IconTried) and kept here.
	UPROPERTY()
	TArray<UTexture2D> m_IconTextures;
	TArray<bool> m_IconTried;
	int m_IconSymbol = -1;
	bool m_bIconLoaded = false;
	// Appended to the host status for Debug ("" while the icons are fine).
	FString m_IconStatus;
	// How the text block was attached ("canvas", "overlay", "panel", or why not), for the Debug panel.
	FString m_HostStatus = "not initialized";
	int m_SeenSymbolChange = -1;
	float m_ShowTimeLeft = 0.0f;
	FString m_ShownText;
	bool m_bShown = true;
	// GetPausedSeconds() at the previous tick (-1 = no tick yet), to see the pause.
	float64 m_LastPausedSeconds = -1.0f;

	UFUNCTION(BlueprintOverride)
	void Initialize()
	{
		UUserWidget Host = GetWidget();
		if (!IsValid(Host))
		{
			m_HostStatus = "no host widget";
			return;
		}
		UWidget Root = Host.GetRootWidget();
		if (!IsValid(Root))
		{
			m_HostStatus = "no root";
			return;
		}
		FString RootClass = Root.Class.GetName().ToString();

		UAlkRichTextBlock Indicator = Cast<UAlkRichTextBlock>(Host.ConstructWidget(UAlkRichTextBlock, n"RunicMarkersSymbolIndicator"));
		if (!IsValid(Indicator))
		{
			m_HostStatus = f"text block not created (root {RootClass})";
			return;
		}
		Indicator.SetTextStyleSet(FAssetPreload::BlockingLoad(TextStyle));

		UCanvasPanel Canvas = Cast<UCanvasPanel>(Root);
		UOverlay Overlay = Cast<UOverlay>(Root);
		UPanelWidget Panel = Cast<UPanelWidget>(Root);
		if (IsValid(Canvas))
		{
			UCanvasPanelSlot CanvasSlot = Canvas.AddChildToCanvas(Indicator);
			if (IsValid(CanvasSlot))
			{
				FAnchors Anchors(0.5f, RunicMarkers::IndicatorAnchorY, 0.5f, RunicMarkers::IndicatorAnchorY);
				CanvasSlot.SetAnchors(Anchors);
				// Top edge at the anchor, so the rune image can sit above it (bottom edge at the anchor).
				CanvasSlot.SetAlignment(FVector2D(0.5f, 0.0f));
				CanvasSlot.SetAutoSize(true);
			}
			m_HostStatus = f"canvas (root {RootClass})";
			AddIcon(Host, Canvas);
		}
		else if (IsValid(Overlay))
		{
			UOverlaySlot OverlaySlot = Overlay.AddChildToOverlay(Indicator);
			if (IsValid(OverlaySlot))
			{
				OverlaySlot.SetHorizontalAlignment(EHorizontalAlignment::HAlign_Center);
				OverlaySlot.SetVerticalAlignment(EVerticalAlignment::VAlign_Bottom);
				OverlaySlot.SetPadding(FMargin(0.0f, 0.0f, 0.0f, RunicMarkers::IndicatorBottomPadding));
			}
			m_HostStatus = f"overlay (root {RootClass})";
		}
		else if (IsValid(Panel))
		{
			Panel.AddChild(Indicator);
			m_HostStatus = f"panel (root {RootClass})";
		}
		else
		{
			m_HostStatus = f"no panel root (root {RootClass})";
			return;
		}
		m_Text = Indicator;
		SetShown(false);
	}

	void AddIcon(UUserWidget Host, UCanvasPanel Canvas)
	{
		UImage Icon = Cast<UImage>(Host.ConstructWidget(UImage, n"RunicMarkersSymbolIcon"));
		if (!IsValid(Icon))
		{
			m_IconStatus = ", icons: image not created";
			return;
		}
		UCanvasPanelSlot IconSlot = Canvas.AddChildToCanvas(Icon);
		if (!IsValid(IconSlot))
		{
			m_IconStatus = ", icons: image not attached";
			return;
		}
		FAnchors Anchors(0.5f, RunicMarkers::IndicatorAnchorY, 0.5f, RunicMarkers::IndicatorAnchorY);
		IconSlot.SetAnchors(Anchors);
		IconSlot.SetAlignment(FVector2D(0.5f, 1.0f));
		// Lift the image a little off the anchor so it does not touch the text below it.
		IconSlot.SetPosition(FVector2D(0.0f, -RunicMarkers::IndicatorIconGap));
		IconSlot.SetAutoSize(true);
		Icon.SetDesiredSizeOverride(FVector2D(RunicMarkers::IndicatorIconSize, RunicMarkers::IndicatorIconSize));
		Icon.SetVisibility(ESlateVisibility::Collapsed);
		m_Icon = Icon;
	}

	/** Icon texture of a symbol, loaded once. Null (and noted in m_IconStatus) if it is not in the pak. */
	UTexture2D GetIconTexture(int Symbol)
	{
		TArray<FString> Ids = RunicMarkers::SymbolIds();
		if (Symbol < 0 || Symbol >= Ids.Num())
			return nullptr;
		if (m_IconTextures.Num() != Ids.Num())
		{
			// Explicit fill: do not rely on SetNum zero-initialising the new elements.
			m_IconTextures.Empty();
			m_IconTried.Empty();
			for (int i = 0; i < Ids.Num(); i++)
			{
				m_IconTextures.Add(nullptr);
				m_IconTried.Add(false);
			}
		}
		if (!m_IconTried[Symbol])
		{
			m_IconTried[Symbol] = true;
			m_IconTextures[Symbol] = Cast<UTexture2D>(LoadObject(nullptr, RunicMarkers::SymbolIconPath(Ids[Symbol])));
			if (!IsValid(m_IconTextures[Symbol]))
				m_IconStatus = f", icons: missing ({Ids[Symbol]})";
		}
		return m_IconTextures[Symbol];
	}

	/** Points the image at the current symbol's icon; hides the image if that icon did not load. */
	void UpdateIcon(int Symbol)
	{
		if (!IsValid(m_Icon) || Symbol == m_IconSymbol)
			return;
		m_IconSymbol = Symbol;
		UTexture2D Tex = GetIconTexture(Symbol);
		m_bIconLoaded = IsValid(Tex);
		if (m_bIconLoaded)
			m_Icon.SetBrushFromTexture(Tex, false);
		SetIconVisible(m_bShown && m_bIconLoaded);
	}

	void SetIconVisible(bool bShow)
	{
		if (!IsValid(m_Icon))
			return;
		if (bShow)
			m_Icon.SetVisibility(ESlateVisibility::HitTestInvisible);
		else
			m_Icon.SetVisibility(ESlateVisibility::Collapsed);
	}

	void SetShown(bool bShow)
	{
		if (bShow == m_bShown || !IsValid(m_Text))
			return;
		m_bShown = bShow;
		if (bShow)
			m_Text.SetVisibility(ESlateVisibility::HitTestInvisible);
		else
			m_Text.SetVisibility(ESlateVisibility::Collapsed);
		SetIconVisible(bShow && m_bIconLoaded);
	}

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		auto RuneState = URunicMarkersState::Get();
		if (!IsValid(RuneState))
			return;
		// Tick count also tells (Debug) whether this widget ticks during the Esc pause menu.
		RuneState.HudTickCount++;
		RuneState.HudHostStatus = m_HostStatus + m_IconStatus;
		if (!IsValid(m_Text))
			return;
		RuneState.HudLastTickRealTime = RuneState.World.RealTimeSeconds;

		// Esc pause menu: this widget still ticks, but only the paused time grows (GetPausedSeconds).
		// Hidden while paused, and the show timer does not run down.
		float64 PausedSeconds = RuneState.GetPausedSeconds();
		bool bPaused = m_LastPausedSeconds >= 0.0f && PausedSeconds - m_LastPausedSeconds > RunicMarkers::HudPauseEpsilon;
		m_LastPausedSeconds = PausedSeconds;
		if (bPaused)
		{
			// Only the indicator; the delete aim dot is a world decal and stays (hidden on release /
			// resolve / nothing aimed by the subsystem).
			SetShown(false);
			return;
		}

		m_ShowTimeLeft = Math::Max(0.0f, m_ShowTimeLeft - InDeltaTime);
		if (RuneState.SymbolChangeCounter != m_SeenSymbolChange)
		{
			// The first tick only takes the current count (no indicator at load).
			if (m_SeenSymbolChange >= 0)
				m_ShowTimeLeft = RunicMarkers::SymbolIndicatorDuration;
			m_SeenSymbolChange = RuneState.SymbolChangeCounter;
		}

		bool bAiming = RuneState.bAiming && RuneState.IsInputAllowed();
		if (!bAiming && m_ShowTimeLeft <= 0.0f)
		{
			SetShown(false);
			return;
		}
		FString Line = f"Rune: {RunicMarkers::SymbolName(RuneState.CurrentSymbol)}";
		if (bAiming)
			Line += f"   (mouse wheel / {Input::Key_GetDisplayName(RunicMarkers::NextSymbolKey()).ToString()})";
		if (Line != m_ShownText)
		{
			m_ShownText = Line;
			m_Text.SetText(FText::FromString(Line));
		}
		UpdateIcon(RuneState.CurrentSymbol);
		SetShown(true);
	}
}
