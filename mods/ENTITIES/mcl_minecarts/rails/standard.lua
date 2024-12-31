local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local mod = mcl_minecarts
local S = minetest.get_translator(modname)

mod.register_rail("mcl_minecarts:rail_v2", {
	tiles = {"default_rail.png"},
	description = S("Rail"),
	_tt_help = S("Track for minecarts"),
	_doc_items_longdesc = S("Rails can be used to build transport tracks for minecarts. Normal rails slightly slow down minecarts due to friction."),
	_doc_items_usagehelp = mod.text.railuse,
	craft = {
		output = "mcl_minecarts:rail_v2 16",
		recipe = {
			{"mcl_core:iron_ingot", "", "mcl_core:iron_ingot"},
			{"mcl_core:iron_ingot", "mcl_core:stick", "mcl_core:iron_ingot"},
			{"mcl_core:iron_ingot", "", "mcl_core:iron_ingot"},
		}
	}
})

