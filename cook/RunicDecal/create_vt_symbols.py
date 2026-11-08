# Headless: imports every rune (white stroke + dark edge, alpha = shape) as a VIRTUAL texture
#   /Reaper-RunicMarkers/Textures/T_Rune_<symbol>_VT
import unreal
PLUGIN_ROOT = "/Reaper-RunicMarkers"
SRC = "C:/RunicCook/RunicDecal/Source_PNG/rune_%s.png"  # copied by cook/build.sh
SYMBOLS = ["x_visited", "o_other", "innos", "beliar", "adanos", "sleeper", "human"]
tools = unreal.AssetToolsHelpers.get_asset_tools()
done = []
for sym in SYMBOLS:
    name = "T_Rune_%s_VT" % sym
    task = unreal.AssetImportTask()
    task.set_editor_property("filename", SRC % sym)
    task.set_editor_property("destination_path", PLUGIN_ROOT + "/Textures")
    task.set_editor_property("destination_name", name)
    task.set_editor_property("automated", True)
    task.set_editor_property("replace_existing", True)
    task.set_editor_property("save", False)
    tools.import_asset_tasks([task])
    tex = unreal.load_asset(PLUGIN_ROOT + "/Textures/" + name)
    if tex is None:
        raise RuntimeError("import failed: " + sym)
    tex.set_editor_property("virtual_texture_streaming", True)
    tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_DEFAULT)
    tex.set_editor_property("srgb", True)
    unreal.EditorAssetLibrary.save_loaded_asset(tex)
    done.append("%s(vt=%s)" % (name, tex.get_editor_property("virtual_texture_streaming")))
unreal.log("RUNIC_OK " + " ".join(done))
