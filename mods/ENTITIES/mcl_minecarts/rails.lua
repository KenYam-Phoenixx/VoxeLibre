local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local mod = mcl_minecarts
local S = minetest.get_translator(modname)
mod.RAIL_GROUPS = {
	STANDARD = 1,
	CURVES = 2,
}

-- Inport functions and constants from elsewhere
local table_merge = mcl_util.table_merge
local check_connection_rules = mod.check_connection_rules
local update_rail_connections = mod.update_rail_connections
local minetest_fourdir_to_dir = minetest.fourdir_to_dir
local minetest_dir_to_fourdir = minetest.dir_to_fourdir
local vector_offset = vector.offset
local vector_equals = vector.equals
local north = mod.north
local south = mod.south
local east = mod.east
local west = mod.west

--- Rail direction Handleres
local function rail_dir_straight(pos, dir, node)
	dir = vector.new(dir)
	dir.y = 0

	if node.param2 == 0 or node.param2 == 2 then
		if vector_equals(dir, north) then
			return north
		else
			return south
		end
	else
		if vector_equals(dir,east) then
			return east
		else
			return west
		end
	end
end
local function rail_dir_sloped(pos, dir, node)
	local uphill = minetest_fourdir_to_dir(node.param2)
	local downhill = minetest_fourdir_to_dir((node.param2+2)%4)
	local up_uphill = vector_offset(uphill,0,1,0)

	if vector_equals(dir, uphill) or vector_equals(dir, up_uphill) then
		return up_uphill
	else
		return downhill
	end
end
-- Fourdir to cardinal direction
-- 0 = north
-- 1 = east
-- 2 = south
-- 3 = west

-- This takes a table `dirs` that has one element for each cardinal direction
-- and which specifies the direction for a cart to continue in when entering
-- a rail node in the direction of the cardinal. This function takes node
-- rotations into account.
local function rail_dir_from_table(pos, dir, node, dirs)
	dir = vector.new(dir)
	dir.y = 0
	local dir_fourdir = (minetest_dir_to_fourdir(dir) - node.param2 + 4) % 4
	local new_fourdir = (dirs[dir_fourdir] + node.param2) % 4
	return minetest_fourdir_to_dir(new_fourdir)
end

local CURVE_RAIL_DIRS = { [0] = 1, 1, 2, 2, }
local function rail_dir_curve(pos, dir, node)
	return rail_dir_from_table(pos, dir, node, CURVE_RAIL_DIRS)
end
local function rail_dir_tee_off(pos, dir, node)
	return rail_dir_from_table(pos, dir, node, CURVE_RAIL_DIRS)
end

local TEE_RAIL_ON_DIRS = { [0] = 0, 1, 1, 0 }
local function rail_dir_tee_on(pos, dir, node)
	return rail_dir_from_table(pos, dir, node, TEE_RAIL_ON_DIRS)
end

local function rail_dir_cross(pos, dir, node)
	dir = vector.new(dir)
	dir.y = 0

	-- Always continue in the same direction. No direction changes allowed
	return dir
end

-- Setup shared text
local railuse = S(
	"Place them on the ground to build your railway, the rails will automatically connect to each other and will"..
	" turn into curves, T-junctions, crossings and slopes as needed."
)
mod.text = mod.text or {}
mod.text.railuse = railuse
local BASE_DEF = {
	drawtype = "mesh",
	mesh = "flat_track.obj",
	paramtype = "light",
	paramtype2 = "4dir",
	stack_max = 64,
	sounds = mcl_sounds.node_sound_metal_defaults(),
	is_ground_content = true,
	paramtype = "light",
	use_texture_alpha = "clip",
	collision_box = {
		type = "fixed",
		fixed = { -8/16, -8/16, -8/16, 8/16, -7/16, 8/15 }
	},
	selection_box = {
		type = "fixed",
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	groups = {
		handy=1, pickaxey=1,
		attached_node=1,
		rail=1,
		connect_to_raillike=minetest.raillike_group("rail"),
		dig_by_water=0,destroy_by_lava_flow=0,
		transport=1
	},
	description = S("New Rail"), -- Temporary name to make debugging easier
	_tt_help = S("Track for minecarts"),
	_doc_items_usagehelp = railuse,
	_doc_items_longdesc = S("Rails can be used to build transport tracks for minecarts. Normal rails slightly slow down minecarts due to friction."),
	on_place = function(itemstack, placer, pointed_thing)
		local node_name = minetest.get_node(pointed_thing.under).name
		-- Don't allow placing rail above rail
		if minetest.get_item_group(node_name,"rail") == 0 then
			return minetest.item_place_node(itemstack, placer, pointed_thing)
		else
			return itemstack
		end
	end,
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		update_rail_connections(pos)
	end,
	_mcl_minecarts = {
		get_next_dir = rail_dir_straight,
	},
	_mcl_blast_resistance = 0.7,
	_mcl_hardness = 0.7,
}

local SLOPED_RAIL_DEF = table.copy(BASE_DEF)
table_merge(SLOPED_RAIL_DEF,{
	drawtype = "mesh",
	mesh = "sloped_track.obj",
	groups = {
		rail_slope = 1,
		not_in_creative_inventory = 1,
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5,  0.5,  0.0,  0.5 },
			{ -0.5,  0.0,  0.0,  0.5,  0.5,  0.5 }
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5,  0.5,  0.0,  0.5 },
			{ -0.5,  0.0,  0.0,  0.5,  0.5,  0.5 }
		}
	},
	_mcl_minecarts = {
		get_next_dir = rail_dir_sloped,
	},
})

function mod.register_rail(itemstring, ndef)
	assert(ndef.tiles)

	-- Extract out the craft recipe
	local craft = ndef.craft
	ndef.craft = nil

	-- Add sensible defaults
	if not ndef.inventory_image then ndef.inventory_image = ndef.tiles[1] end
	if not ndef.wield_image then ndef.wield_image = ndef.tiles[1] end

	--print("registering rail "..itemstring.." with definition: "..dump(ndef))

	-- Make registrations
	minetest.register_node(itemstring, ndef)
	if craft then minetest.register_craft(craft) end
end

function mod.register_straight_rail(base_name, tiles, def)
	def = def or {}
	local base_def = table.copy(BASE_DEF)
	local sloped_def = table.copy(SLOPED_RAIL_DEF)
	local add = {
		tiles = { tiles[1] },
		drop = base_name,
		groups = {
			rail = mod.RAIL_GROUPS.STANDARD,
		},
		_mcl_minecarts = {
			base_name = base_name,
			can_slope = true,
		},
	}
	table_merge(base_def, add); table_merge(sloped_def, add)
	table_merge(base_def, def); table_merge(sloped_def, def)

	-- Register the base node
	mod.register_rail(base_name, base_def)
	base_def.craft = nil; sloped_def.craft = nil
	table_merge(base_def,{
		_mcl_minecarts = {
			railtype = "straight",
		},
	})

	-- Sloped variant
	mod.register_rail_sloped(base_name.."_sloped", table_merge(table.copy(sloped_def),{
		_mcl_minecarts = {
			get_next_dir = rail_dir_sloped,
		},
		mesecons = def.mesecons_sloped,
		tiles = { tiles[1] },
		_mcl_minecarts = {
			railtype = "sloped",
		},
	}))
end

function mod.register_curves_rail(base_name, tiles, def)
	def = def or {}
	local base_def = table.copy(BASE_DEF)
	local sloped_def = table.copy(SLOPED_RAIL_DEF)
	local add = {
		_mcl_minecarts = { base_name = base_name },
		groups = {
			rail = mod.RAIL_GROUPS.CURVES
		},
		drop = base_name,
	}
	table_merge(base_def, add); table_merge(sloped_def, add)
	table_merge(base_def, def); table_merge(sloped_def, def)

	-- Register the base node
	mod.register_rail(base_name, table_merge(table.copy(base_def),{
		tiles = { tiles[1] },
		_mcl_minecarts = {
			get_next_dir = rail_dir_straight,
			railtype = "straight",
			can_slope = true,
		},
	}))

	-- Update for other variants
	base_def.craft = nil
	table_merge(base_def, {
		groups = {
			not_in_creative_inventory = 1
		}
	})

	-- Corner variants
	mod.register_rail(base_name.."_corner", table_merge(table.copy(base_def),{
		tiles = { tiles[2] },
		_mcl_minecarts = {
			get_next_dir = rail_dir_curve,
			railtype = "corner",
		},
	}))

	-- Tee variants
	mod.register_rail(base_name.."_tee_off", table_merge(table.copy(base_def),{
		tiles = { tiles[3] },
		mesecons = {
			effector = {
				action_on = function(pos, node)
					local new_node = {name = base_name.."_tee_on", param2 = node.param2}
					minetest.swap_node(pos, new_node)
				end,
				rules = mesecon.rules.alldirs,
			}
		},
		_mcl_minecarts = {
			get_next_dir = rail_dir_tee_off,
			railtype = "tee",
		},
	}))
	mod.register_rail(base_name.."_tee_on", table_merge(table.copy(base_def),{
		tiles = { tiles[4] },
		_mcl_minecarts = {
			get_next_dir = rail_dir_tee_on,
			railtype = "tee",
		},
		mesecons = {
			effector = {
				action_off = function(pos, node)
					local new_node = {name = base_name.."_tee_off", param2 = node.param2}
					minetest.swap_node(pos, new_node)
				end,
				rules = mesecon.rules.alldirs,
			}
		}
	}))

	-- Sloped variant
	mod.register_rail_sloped(base_name.."_sloped", table_merge(table.copy(sloped_def),{
		description = S("Sloped Rail"), -- Temporary name to make debugging easier
		_mcl_minecarts = {
			get_next_dir = rail_dir_sloped,
			railtype = "tee",
		},
		tiles = { tiles[1] },
	}))

	-- Cross variant
	mod.register_rail(base_name.."_cross", table_merge(table.copy(base_def),{
		tiles = { tiles[5] },
		_mcl_minecarts = {
			get_next_dir = rail_dir_cross,
			railtype = "cross",
		},
	}))
end

function mod.register_rail_sloped(itemstring, def)
	assert(def.tiles)

	-- Build the node definition
	local ndef = table.copy(SLOPED_RAIL_DEF)
	table_merge(ndef, def)

	-- Add sensible defaults
	if not ndef.inventory_image then ndef.inventory_image = ndef.tiles[1] end
	if not ndef.wield_image then ndef.wield_image = ndef.tiles[1] end

	--print("registering sloped rail "..itemstring.." with definition: "..dump(ndef))

	-- Make registrations
	minetest.register_node(itemstring, ndef)
end

-- Redstone rules
mod.rail_rules_long =
{{x=-1,  y= 0, z= 0, spread=true},
 {x= 1,  y= 0, z= 0, spread=true},
 {x= 0,  y=-1, z= 0, spread=true},
 {x= 0,  y= 1, z= 0, spread=true},
 {x= 0,  y= 0, z=-1, spread=true},
 {x= 0,  y= 0, z= 1, spread=true},

 {x= 1, y= 1, z= 0},
 {x= 1, y=-1, z= 0},
 {x=-1, y= 1, z= 0},
 {x=-1, y=-1, z= 0},
 {x= 0, y= 1, z= 1},
 {x= 0, y=-1, z= 1},
 {x= 0, y= 1, z=-1},
 {x= 0, y=-1, z=-1}}

dofile(modpath.."/rails/normal.lua")
dofile(modpath.."/rails/activator.lua")
dofile(modpath.."/rails/detector.lua")
dofile(modpath.."/rails/powered.lua")

-- Aliases
if minetest.get_modpath("doc") then
	doc.add_entry_alias("nodes", "mcl_minecarts:golden_rail", "nodes", "mcl_minecarts:golden_rail_on")
end

local CURVY_RAILS_MAP = {
	["mcl_minecarts:rail"] = "mcl_minecarts:rail_v2",
}
for old,new in pairs(CURVY_RAILS_MAP) do
	minetest.register_node(old, {
		inventory_image = minetest.registered_nodes[new].inventory_image,
		groups = { rail = 1 }
	})
end
minetest.register_lbm({
	name = "mcl_minecarts:update_legacy_curvy_rails",
	nodenames = mcl_util.table_keys(CURVY_RAILS_MAP),
	action = function(pos, node)
		node.name = CURVY_RAILS_MAP[node.name]
		if node.name then
			minetest.swap_node(pos, node)
			mod.update_rail_connections(pos, { legacy = true, ignore_neighbor_connections = true })
		end
	end
})
local STRAIGHT_RAILS_MAP ={
	["mcl_minecarts:golden_rail"] = "mcl_minecarts:golden_rail_v2",
	["mcl_minecarts:golden_rail_on"] = "mcl_minecarts:golden_rail_v2_on",
	["mcl_minecarts:activator_rail"] = "mcl_minecarts:activator_rail_v2",
	["mcl_minecarts:activator_rail_on"] = "mcl_minecarts:activator_rail_v2_on",
	["mcl_minecarts:detector_rail"] = "mcl_minecarts:detector_rail_v2",
	["mcl_minecarts:detector_rail_on"] = "mcl_minecarts:detector_rail_v2_on",
}
for old,new in pairs(STRAIGHT_RAILS_MAP) do
	minetest.register_node(old, {
		inventory_image = minetest.registered_nodes[new].inventory_image,
		groups = { rail = 1 }
	})
end
local TRANSLATE_RAILS_MAP = table.copy(STRAIGHT_RAILS_MAP)
table_merge(TRANSLATE_RAILS_MAP, CURVY_RAILS_MAP)

minetest.register_lbm({
	name = "mcl_minecarts:update_legacy_straight_rails",
	nodenames = mcl_util.table_keys(STRAIGHT_RAILS_MAP),
	action = function(pos, node)
		node.name = STRAIGHT_RAILS_MAP[node.name]
		if node.name then
			local connections = mod.get_rail_connections(pos, { legacy = true, ignore_neighbor_connections = true })
			if not mod.HORIZONTAL_STANDARD_RULES[connections] then
				-- Drop an immortal object at this location
				local item_entity = minetest.add_item(pos, ItemStack(node.name))
				if item_entity then
					item_entity:get_luaentity()._immortal = true
				end

				-- This is a configuration that doesn't exist in the new rail
				-- Replace with a standard rail
				node.name = "mcl_minecarts:rail_v2"
			end
			minetest.swap_node(pos, node)
			mod.update_rail_connections(pos, { legacy = true, ignore_neighbor_connections = true })
		end
	end
})

-- Convert old rail in the player's inventory to new rail
minetest.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	local size = inv:get_size("main")
	for i=1,size do
		local stack = inv:get_stack("main", i)

		local new_name = TRANSLATE_RAILS_MAP[stack:get_name()]
		if new_name then
			stack:set_name(new_name)
			inv:set_stack("main", i, stack)
		end
	end
end)

