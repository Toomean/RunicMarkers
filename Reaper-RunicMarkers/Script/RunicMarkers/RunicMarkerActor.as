/**
 * A placed rune: a decal (our cooked VT symbol inside the game decal material, see URunicMarkersState)
 * plus a soft spot light that shines back at the surface (the "glow": game decal emission did not work).
 * Actor X axis = surface normal, Z axis = "up" of the symbol. No collision, no Tick.
 */
class ARunicMarker : AActor
{
	UPROPERTY(DefaultComponent, RootComponent)
	USceneComponent m_RootComp;

	UPROPERTY(DefaultComponent, Attach=m_RootComp)
	UDecalComponent m_Decal;
	// DecalSize is BlueprintReadOnly in UE: set it as a default, not in ConstructionScript.
	default m_Decal.DecalSize = FVector(RunicMarkers::DecalDepth, RunicMarkers::DecalHalfSize, RunicMarkers::DecalHalfSize);

	UPROPERTY(DefaultComponent, Attach=m_RootComp)
	USpotLightComponent m_Light;
	default m_Light.Mobility = EComponentMobility::Movable;

	// Index into RunicMarkers::SymbolIds(); kept for stage-3 persistence.
	int SymbolIndex = 0;

	UFUNCTION(BlueprintOverride)
	void ConstructionScript()
	{
		// Decals project along their local X: yaw 180 turns it into the surface. In-game: roll 0 laid the
		// symbols on their side, roll -90 stood them upside down on walls, so roll +90 = upright.
		m_Decal.SetRelativeRotation(FRotator(0, 180, 90));

		// 40 cm out along the normal, rotated 180 deg so the light points back at the surface.
		m_Light.SetRelativeLocation(FVector(40, 0, 0));
		m_Light.SetRelativeRotation(FRotator(0, 180, 0));
		m_Light.SetAttenuationRadius(120);
		m_Light.SetLightColor(FLinearColor(0.2, 0.6, 1.0));
		m_Light.SetUseTemperature(false);
		m_Light.SetCastShadows(false);
		RefreshLight();
	}

	void SetSymbol(int Index, UMaterialInterface SymbolMaterial)
	{
		SymbolIndex = Index;
		m_Decal.SetDecalMaterial(SymbolMaterial);
	}

	bool bHighlighted = false;

	/** Re-reads the glow setting (0 = light off). */
	void RefreshLight()
	{
		if (bHighlighted)
			return;
		float Candela = RunicMarkers::GetLightCandela();
		m_Light.SetLightColor(FLinearColor(0.2, 0.6, 1.0));
		m_Light.SetIntensity(Candela);
		m_Light.SetVisibility(Candela > 0.0f);
	}

	/** Red light while targeted by the delete key (visible even when the glow setting is 0). */
	void SetHighlighted(bool bOn)
	{
		bHighlighted = bOn;
		if (!bOn)
		{
			RefreshLight();
			return;
		}
		m_Light.SetLightColor(FLinearColor(1.0, 0.1, 0.05));
		m_Light.SetIntensity(Math::Max(RunicMarkers::GetLightCandela(), RunicMarkers::HighlightCandela));
		m_Light.SetVisibility(true);
	}

	void SetLightEnabled(bool bEnabled)
	{
		m_Light.SetVisibility(bEnabled && RunicMarkers::GetLightCandela() > 0.0f);
	}
}
