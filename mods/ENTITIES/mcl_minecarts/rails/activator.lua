local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local mod = mcl_minecarts
local S = minetest.get_translator(modname)

-- Activator rail (off)
mod.register_straight_rail("mcl_minecarts:activator_rail_v2", {"mcl_minecarts_rail_activator.png"},{
	description = S("Activator Rail"),
	_tt_help = S("Track for minecarts").."\n"..S("Activates minecarts when powered"),
	_doc_items_longdesc = S("Rails can be used to build transport tracks for minecarts. Activator rails are used to activate special minecarts."),
	_doc_items_usagehelp = mod.text.railuse .. "\n" .. S("To make this rail activate minecarts, power it with redstone power and send a minecart over this piece of rail."),
	mesecons = {
		conductor = {
			state = mesecon.state.off,
			offstate = "mcl_minecarts:activator_rail_v2",
			onstate  = "mcl_minecarts:activator_rail_v2_on",
			rules = mod.rail_rules_long,
		},
	},
	mesecons_sloped = {
		conductor = {
			state = mesecon.state.off,
			offstate = "mcl_minecarts:activator_rail_v2_sloped",
			onstate  = "mcl_minecarts:activator_rail_v2_on_sloped",
			rules = mod.rail_rules_long,
		},
	},
	craft = {
		output = "mcl_minecarts:activator_rail_v2 6",
		recipe = {
			{"mcl_core:iron_ingot", "mcl_core:stick", "mcl_core:iron_ingot"},
			{"mcl_core:iron_ingot", "mesecons_torch:mesecon_torch_on", "mcl_core:iron_ingot"},
			{"mcl_core:iron_ingot", "mcl_core:stick", "mcl_core:iron_ingot"},
		}
	},
})

-- Activator rail (on)
local function activator_rail_action_on(pos, node)
	local pos2 = { x = pos.x, y =pos.y + 1, z = pos.z }
	local objs = minetest.get_objects_inside_radius(pos2, 1)
	for _, o in pairs(objs) do
		local l = o:get_luaentity()
		if l and string.sub(l.name, 1, 14) == "mcl_minecarts:" and l.on_activate_by_rail then
			l:on_activate_by_rail()
		end
	end
end
mod.register_straight_rail("mcl_minecarts:activator_rail_v2_on", {"mcl_minecarts_rail_activator_powered.png"},{
	_doc_items_create_entry = false,
	groups = {
		not_in_creative_inventory = 1,
	},
	mesecons = {
		conductor = {
			state = mesecon.state.on,
			offstate = "mcl_minecarts:activator_rail_v2",
			onstate  = "mcl_minecarts:activator_rail_v2_on",
			rules = mod.rail_rules_long,
		},
		effector = {
			-- Activate minecarts
			action_on = activator_rail_action_on,
		},

	},
	mesecons_sloped = {
		conductor = {
			state = mesecon.state.on,
			offstate = "mcl_minecarts:activator_rail_v2_sloped",
			onstate  = "mcl_minecarts:activator_rail_v2_on_sloped",
			rules = mod.rail_rules_long,
		},
		effector = {
			-- Activate minecarts
			action_on = activator_rail_action_on,
		},

	},
	_mcl_minecarts_on_enter = function(pos, cart)
		if cart.on_activate_by_rail then
			cart:on_activate_by_rail()
		end
	end,
	drop = "mcl_minecarts:activator_rail_v2",
})

