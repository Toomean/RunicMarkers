# Headless: imports every rune (white stroke + dark edge, alpha = shape) twice, from two PNGs that
# cook/build.sh writes per symbol:
#   rune_<symbol>.png (512 px) -> /Reaper-RunicMarkers/Textures/T_Rune_<symbol>_VT
#                                 VIRTUAL texture for the decals (the game's decal materials sample VT only)
#   icon_<symbol>.png (128 px) -> /Reaper-RunicMarkers/Textures/T_RuneIcon_<symbol>
#                                 plain UI texture (no VT, no mips) for the HUD indicator image; UMG brushes
#                                 most likely cannot draw a VT. Downscaled source because it is drawn at
#                                 64 px without mips (the 512 px source would alias).
# plus rune_dot.png -> T_Rune_dot_VT (delete aim dot, VT only: no HUD icon, not a placeable symbol).
import unreal
PLUGIN_ROOT = "/Reaper-RunicMarkers"
SRC_DIR = "C:/RunicCook/RunicDecal/Source_PNG/"  # filled by cook/build.sh
SYMBOLS = ["x_visited", "o_other", "innos", "beliar", "adanos", "sleeper", "human"]
VT_ONLY = ["dot"]
tools = unreal.AssetToolsHelpers.get_asset_tools()
done = []


def import_png(filename, name):
    task = unreal.AssetImportTask()
    task.set_editor_property("filename", SRC_DIR + filename)
    task.set_editor_property("destination_path", PLUGIN_ROOT + "/Textures")
    task.set_editor_property("destination_name", name)
    task.set_editor_property("automated", True)
    task.set_editor_property("replace_existing", True)
    task.set_editor_property("save", False)
    tools.import_asset_tasks([task])
    tex = unreal.load_asset(PLUGIN_ROOT + "/Textures/" + name)
    if tex is None:
        raise RuntimeError("import failed: " + name)
    return tex


def save(asset, name):
    if not unreal.EditorAssetLibrary.save_loaded_asset(asset):
        raise RuntimeError("save failed: " + name)


def import_vt(sym):
    name = "T_Rune_%s_VT" % sym
    tex = import_png("rune_%s.png" % sym, name)
    tex.set_editor_property("virtual_texture_streaming", True)
    tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_DEFAULT)
    tex.set_editor_property("srgb", True)
    save(tex, name)
    done.append("%s(vt=%s)" % (name, tex.get_editor_property("virtual_texture_streaming")))


for sym in VT_ONLY:
    import_vt(sym)

for sym in SYMBOLS:
    import_vt(sym)
    icon_name = "T_RuneIcon_%s" % sym
    icon = import_png("icon_%s.png" % sym, icon_name)
    icon.set_editor_property("virtual_texture_streaming", False)
    icon.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_EDITOR_ICON)
    icon.set_editor_property("lod_group", unreal.TextureGroup.TEXTUREGROUP_UI)
    icon.set_editor_property("mip_gen_settings", unreal.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    icon.set_editor_property("srgb", True)
    save(icon, icon_name)
    done.append("%s(vt=%s,comp=%s,mips=%s)" % (
        icon_name,
        icon.get_editor_property("virtual_texture_streaming"),
        str(icon.get_editor_property("compression_settings")),
        str(icon.get_editor_property("mip_gen_settings"))))
unreal.log("RUNIC_OK " + " ".join(done))
