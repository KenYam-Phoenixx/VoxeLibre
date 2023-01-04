---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by michieal.
--- DateTime: 12/29/22 12:38 PM -- Restructure Date
---
-- LOCALS
local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)
local bamboo = "mcl_bamboo:bamboo"
local adj_nodes = {
	vector.new(0, 0, 1),
	vector.new(0, 0, -1),
	vector.new(1, 0, 0),
	vector.new(-1, 0, 0),
}

-- CONSTS
-- Due to door fix #2736, doors are displayed backwards. When this is fixed, set this variable to false.
local BROKEN_DOORS = true
local SIDE_SCAFFOLDING = false

local node_sound = mcl_sounds.node_sound_wood_defaults()

-- specific bamboo nodes (Items)... Pt. 1
if minetest.get_modpath("mcl_flowerpots") then
	mcl_bamboo.mcl_log("FlowerPot Section Entrance. Modpath exists.")
	if mcl_flowerpots ~= nil then
		-- Flower-potted Bamboo...
		local flwr_name = "mcl_bamboo:bamboo"
		local flwr_def = {name = "bamboo_plant",
						  desc = S("Bamboo"),
						  image = "mcl_bamboo_bamboo_fpm.png", -- use with "register_potted_cube"
			-- "mcl_bamboo_flower_pot.png", -- use with "register_potted_flower"
		}

		mcl_flowerpots.register_potted_cube(flwr_name, flwr_def)
		--			mcl_flowerpots.register_potted_flower(flwr_name, flwr_def)
		minetest.register_alias("bamboo_flower_pot", "mcl_flowerpots:flower_pot_bamboo_plant")
	end
end

if minetest.get_modpath("mcl_doors") then
	if mcl_doors then
		local top_door_tiles = {}
		local bot_door_tiles = {}

		if BROKEN_DOORS then
			top_door_tiles = {"mcl_bamboo_door_top_alt.png", "mcl_bamboo_door_top.png"}
			bot_door_tiles = {"mcl_bamboo_door_bottom_alt.png", "mcl_bamboo_door_bottom.png"}
		else
			top_door_tiles = {"mcl_bamboo_door_top.png", "mcl_bamboo_door_top.png"}
			bot_door_tiles = {"mcl_bamboo_door_bottom.png", "mcl_bamboo_door_bottom.png"}
		end

		local name = "mcl_bamboo:bamboo_door"
		local def = {
			description = S("Bamboo Door."),
			inventory_image = "mcl_bamboo_door_wield.png",
			wield_image = "mcl_bamboo_door_wield.png",
			groups = {handy = 1, axey = 1, material_wood = 1, flammable = -1},
			_mcl_hardness = 3,
			_mcl_blast_resistance = 3,
			tiles_bottom = bot_door_tiles,
			tiles_top = top_door_tiles,
			sounds = mcl_sounds.node_sound_wood_defaults(),
		}

		mcl_doors:register_door(name, def)

		name = "mcl_bamboo:bamboo_trapdoor"
		local trap_def = {
			description = S("Bamboo Trapdoor."),
			inventory_image = "mcl_bamboo_door_complete.png",
			groups = {},
			tile_front = "mcl_bamboo_trapdoor_top.png",
			tile_side = "mcl_bamboo_trapdoor_side.png",
			_doc_items_longdesc = S("Wooden trapdoors are horizontal barriers which can be opened and closed by hand or a redstone signal. They occupy the upper or lower part of a block, depending on how they have been placed. When open, they can be climbed like a ladder."),
			_doc_items_usagehelp = S("To open or close the trapdoor, rightclick it or send a redstone signal to it."),
			wield_image = "mcl_bamboo_trapdoor_wield.png",
			inventory_image = "mcl_bamboo_trapdoor_wield.png",
			groups = {handy = 1, axey = 1, mesecon_effector_on = 1, material_wood = 1, flammable = -1},
			_mcl_hardness = 3,
			_mcl_blast_resistance = 3,
			sounds = mcl_sounds.node_sound_wood_defaults(),
		}

		mcl_doors:register_trapdoor(name, trap_def)

		minetest.register_alias("bamboo_door", "mcl_bamboo:bamboo_door")
		minetest.register_alias("bamboo_trapdoor", "mcl_bamboo:bamboo_trapdoor")
	end
end

if minetest.get_modpath("mcl_stairs") then
	if mcl_stairs ~= nil then
		mcl_stairs.register_stair_and_slab_simple(
				"bamboo_block",
				"mcl_bamboo:bamboo_block",
				S("Bamboo Stair"),
				S("Bamboo Slab"),
				S("Double Bamboo Slab")
		)
		mcl_stairs.register_stair_and_slab_simple(
				"bamboo_stripped",
				"mcl_bamboo:bamboo_block_stripped",
				S("Stripped Bamboo Stair"),
				S("Stripped Bamboo Slab"),
				S("Double Stripped Bamboo Slab")
		)
		mcl_stairs.register_stair_and_slab_simple(
				"bamboo_plank",
				"mcl_bamboo:bamboo_plank",
				S("Bamboo Plank Stair"),
				S("Bamboo Plank Slab"),
				S("Double Bamboo Plank Slab")
		)

		-- let's add plank slabs to the wood_slab group.
		local bamboo_plank_slab = "mcl_stairs:slab_bamboo_plank"
		local node_groups = {
			wood_slab = 1,
			building_block = 1,
			slab = 1,
			axey = 1,
			handy = 1,
			stair = 1,
			flammable = 1,
			fire_encouragement = 5,
			fire_flammability = 20
		}

		minetest.override_item(bamboo_plank_slab, {groups = node_groups})
	end
end

if minetest.get_modpath("mesecons_pressureplates") then

	if mesecon ~= nil and mesecon.register_pressure_plate ~= nil then
		-- make sure that pressure plates are installed.

		-- Bamboo Pressure Plate...

		-- Register a Pressure Plate (api command doc.)
		-- basename:    base name of the pressure plate
		-- description:	description displayed in the player's inventory
		-- textures_off:textures of the pressure plate when inactive
		-- textures_on:	textures of the pressure plate when active
		-- image_w:	wield image of the pressure plate
		-- image_i:	inventory image of the pressure plate
		-- recipe:	crafting recipe of the pressure plate
		-- sounds:	sound table (like in minetest.register_node)
		-- plusgroups:	group memberships (attached_node=1 and not_in_creative_inventory=1 are already used)
		-- activated_by: optimal table with elements denoting by which entities this pressure plate is triggered
		--		Possible table fields:
		--		* player=true: Player
		--		* mob=true: Mob
		--		By default, is triggered by all entities
		-- longdesc:	Customized long description for the in-game help (if omitted, a dummy text is used)

		mesecon.register_pressure_plate(
				"mcl_bamboo:pressure_plate_bamboo_wood",
				S("Bamboo Pressure Plate"),
				{"mcl_bamboo_bamboo_plank.png"},
				{"mcl_bamboo_bamboo_plank.png"},
				"mcl_bamboo_bamboo_plank.png",
				nil,
				{{"mcl_bamboo:bamboo_plank", "mcl_bamboo:bamboo_plank"}},
				mcl_sounds.node_sound_wood_defaults(),
				{axey = 1, material_wood = 1},
				nil,
				S("A wooden pressure plate is a redstone component which supplies its surrounding blocks with redstone power while any movable object (including dropped items, players and mobs) rests on top of it."))

		minetest.register_craft({
			type = "fuel",
			recipe = "mcl_bamboo:pressure_plate_bamboo_wood_off",
			burntime = 15
		})
		minetest.register_alias("bamboo_pressure_plate", "mcl_bamboo:pressure_plate_bamboo_wood")

	end
end

if minetest.get_modpath("mcl_signs") then
	mcl_bamboo.mcl_log("Signs Section Entrance. Modpath exists.")
	if mcl_signs ~= nil then
		-- Bamboo Signs...
		mcl_signs.register_sign_custom("mcl_bamboo", "_bamboo", "mcl_signs_sign_greyscale.png",
				"#f6dc91", "default_sign_greyscale.png", "default_sign_greyscale.png",
				"Bamboo Sign")
		mcl_signs.register_sign_craft("mcl_bamboo", "mcl_bamboo:bamboo_plank", "_bamboo")
		minetest.register_alias("bamboo_sign", "mcl_signs:wall_sign_bamboo")
	end
end

if minetest.get_modpath("mcl_fences") then
	mcl_bamboo.mcl_log("Fences Section Entrance. Modpath exists.")

	local id = "bamboo_fence"
	local id_gate = "bamboo_fence_gate"
	local wood_groups = {handy = 1, axey = 1, flammable = 2, fence_wood = 1, fire_encouragement = 5, fire_flammability = 20}
	local wood_connect = {"group:fence_wood"}

	local fence_id = mcl_fences.register_fence(id, S("Bamboo Fence"), "mcl_bamboo_fence_bamboo.png", wood_groups,
			2, 15, wood_connect, node_sound)
	local gate_id = mcl_fences.register_fence_gate(id, S("Bamboo Fence Gate"), "mcl_bamboo_fence_gate_bamboo.png",
			wood_groups, 2, 15, node_sound) -- note: about missing params.. will use defaults.

	mcl_bamboo.mcl_log(dump(fence_id))
	mcl_bamboo.mcl_log(dump(gate_id))

	local craft_wood = "mcl_bamboo:bamboo_plank"
	minetest.register_craft({
		output = "mcl_bamboo:" .. id .. " 3",
		recipe = {
			{craft_wood, "mcl_core:stick", craft_wood},
			{craft_wood, "mcl_core:stick", craft_wood},
		}
	})
	minetest.register_craft({
		output = "mcl_bamboo:" .. id_gate,
		recipe = {
			{"mcl_core:stick", craft_wood, "mcl_core:stick"},
			{"mcl_core:stick", craft_wood, "mcl_core:stick"},
		}
	})
	minetest.register_alias("bamboo_fence", "mcl_fences:" .. id)
	minetest.register_alias("bamboo_fence_gate", "mcl_fences:" .. id_gate)
end

if minetest.get_modpath("mesecons_button") then
	if mesecon ~= nil then
		mesecon.register_button(
				"bamboo",
				S("Bamboo Button"),
				"mcl_bamboo_bamboo_plank.png",
				"mcl_bamboo:bamboo_plank",
				node_sound,
				{material_wood = 1, handy = 1, pickaxey = 1, flammable = 3, fire_flammability = 20, fire_encouragement = 5, },
				1,
				false,
				S("A bamboo button is a redstone component made out of stone which can be pushed to provide redstone power. When pushed, it powers adjacent redstone components for 1 second."),
				"mesecons_button_push")
	end
end

if minetest.get_modpath("mcl_stairs") then
	if mcl_stairs ~= nil then
		mcl_stairs.register_stair_and_slab_simple(
				"bamboo_mosaic",
				"mcl_bamboo:bamboo_mosaic",
				S("Bamboo Mosaic Stair"),
				S("Bamboo Mosaic Slab"),
				S("Double Bamboo Mosaic Slab")
		)
	end
end

local scaffold_name = "mcl_bamboo:scaffolding"
local side_scaffold_name = "mcl_bamboo:scaffolding_horizontal"

local disallow_on_rotate
if minetest.get_modpath("screwdriver") then
	disallow_on_rotate = screwdriver.disallow
end

minetest.register_node(scaffold_name, {
	description = S("Scaffolding"),
	doc_items_longdesc = S("Scaffolding block used to climb up or out across areas."),
	doc_items_hidden = false,
	tiles = {"mcl_bamboo_scaffolding_top.png", "mcl_bamboo_scaffolding_top.png", "mcl_bamboo_scaffolding_bottom.png"},
	drawtype = "nodebox",
	paramtype = "light",
	use_texture_alpha = "clip",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, 0.375, -0.5, 0.5, 0.5, 0.5},
			{-0.5, -0.5, -0.5, -0.375, 0.5, -0.375},
			{0.375, -0.5, -0.5, 0.5, 0.5, -0.375},
			{0.375, -0.5, 0.375, 0.5, 0.5, 0.5},
			{-0.5, -0.5, 0.375, -0.375, 0.5, 0.5},
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		},
	},
	buildable_to = false,
	is_ground_content = false,
	walkable = false,
	climbable = true,
	physical = true,
	node_placement_prediction = "",
	groups = {handy = 1, axey = 1, flammable = 3, building_block = 1, material_wood = 1, fire_encouragement = 5, fire_flammability = 20, falling_node = 1, stack_falling = 1},
	sounds = mcl_sounds.node_sound_wood_defaults(),
	_mcl_blast_resistance = 0,
	_mcl_hardness = 0,

	on_rotate = disallow_on_rotate,

	on_place = function(itemstack, placer, pointed)
		mcl_bamboo.mcl_log("Checking for protected placement of scaffolding.")
		local node = minetest.get_node(pointed.under)
		local pos = pointed.under
		local dir = vector.subtract(pointed.under, pointed.above)
		local wdir = minetest.dir_to_wallmounted(dir)
		local h = 0
		if wdir == 1 then
			-- top placement. Prevents placing scaffolding along the sides of other nodes.

			if mcl_bamboo.is_protected(pos, placer) then
				return
			end
			mcl_bamboo.mcl_log("placement of scaffolding is not protected.")
			-- place on solid nodes
			if node.name ~= scaffold_name then
				minetest.set_node(pointed.above, {name = scaffold_name, param2 = 0})
				if not minetest.is_creative_enabled(placer:get_player_name()) then
					itemstack:take_item(1)
				end
				return itemstack
			end
			--build up when placing on existing scaffold
			repeat
				pos.y = pos.y + 1
				local cn = minetest.get_node(pos)
				local cnb = minetest.get_node(pointed.under)
				local bn = minetest.get_node(vector.offset(pointed.under, 0, -1, 0))
				if cn.name == "air" then
					-- first step to making scaffolding work like Minecraft scaffolding.
					if cnb.name == scaffold_name and bn == scaffold_name and SIDE_SCAFFOLDING == false then
						return itemstack
					end

					if mcl_bamboo.is_protected(pos, placer) then
						return
					end

					minetest.set_node(pos, node)
					if not minetest.is_creative_enabled(placer:get_player_name()) then
						itemstack:take_item(1)
					end
					placer:set_wielded_item(itemstack)
					return itemstack
				end
				h = h + 1
			until cn.name ~= node.name or itemstack:get_count() == 0 or h >= 128
		else
			-- Don't use. From cora, who failed to make something awesome.
			--[[
						if SIDE_SCAFFOLDING then
							-- count param2 up when placing to the sides. Fall when > 6
							local ctrl = placer:get_player_control()
							if ctrl and ctrl.sneak then
								local pp2 = minetest.get_node(ptd.under).param2
								local np2 = pp2 + 1
								if minetest.get_node(vector.offset(ptd.above, 0, -1, 0)).name == "air" then
									minetest.set_node(ptd.above, {name = side_scaffold_name, param2 = np2})
									itemstack:take_item(1)
								end
								if np2 > 6 then
									minetest.check_single_for_falling(ptd.above)
								end
								return itemstack
							end
						end
			]]

			--[[  Commenting out untested code, for commit.
						local fdir = minetest.dir_to_facedir(dir) % 4

						local meta = minetest.get_meta(pos)

						if not meta then
							return false
						end
						local count = meta:get_int("count", 0)

						h = minetest.get_node(pointed.under).param2
						--repeat
						local ctrl = placer:get_player_control()
						if ctrl and ctrl.sneak then
							local pp2 = h

							local np2 = pp2 + 1
							fdir = fdir + 1 -- convert fdir to a base of one.
							local new_pos = adj_nodes[fdir]

							new_pos = vector.offset(pointed.above, new_pos.x, -1, new_pos.z)
							if mcl_bamboo.is_protected(new_pos, placer) then
								-- disallow placement in protected area
								return
							end

							itemstack:take_item(1)
							if minetest.get_node(new_pos).name == "air" then
								minetest.set_node(new_pos, {name = side_scaffold_name, param2 = np2})
								if np2 >= 6 then
									np2 = 6
									minetest.minetest.dig_node(new_pos)
								end
							end
							return itemstack

						end
			]]
			--	h = h + 1
			--until h >= 7 or itemstack.get_count() <= 0

		end
	end,
	on_destruct = function(pos)
		-- Node destructor; called before removing node.
		local new_pos = vector.offset(pos, 0, 1, 0)
		local node_above = minetest.get_node(new_pos)
		if node_above and node_above.name == scaffold_name then
			local sound_params = {
				pos = new_pos,
				gain = 1.0, -- default
				max_hear_distance = 10, -- default, uses a Euclidean metric
			}

			minetest.remove_node(new_pos)
			minetest.sound_play(node_sound.dug, sound_params, true)
			local istack = ItemStack(scaffold_name)
			minetest.add_item(new_pos, istack)
		end
	end,
})

minetest.register_node(side_scaffold_name, {
	description = S("Scaffolding"),
	doc_items_longdesc = S("Scaffolding block used to climb up or out across areas."),
	doc_items_hidden = false,
	tiles = {"mcl_bamboo_scaffolding_top.png", "mcl_bamboo_scaffolding_top.png", "mcl_bamboo_scaffolding_bottom.png"},
	drop = "mcl_bamboo:scaffolding",
	drawtype = "nodebox",
	paramtype = "light",
	use_texture_alpha = "clip",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, 0.375, -0.5, 0.5, 0.5, 0.5},
			{-0.5, -0.5, -0.5, -0.375, 0.5, -0.375},
			{0.375, -0.5, -0.5, 0.5, 0.5, -0.375},
			{0.375, -0.5, 0.375, 0.5, 0.5, 0.5},
			{-0.5, -0.5, 0.375, -0.375, 0.5, 0.5},
			{-0.5, -0.5, -0.5, 0.5, -0.375, 0.5},
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		},
	},
	groups = {handy = 1, axey = 1, flammable = 3, building_block = 1, material_wood = 1, fire_encouragement = 5, fire_flammability = 20, not_in_creative_inventory = 1, falling_node = 1},
	_mcl_after_falling = function(pos)
		if minetest.get_node(pos).name == "mcl_bamboo:scaffolding_horizontal" then
			if minetest.get_node(vector.offset(pos, 0, 0, 0)).name ~= scaffold_name then
				minetest.remove_node(pos)
				minetest.add_item(pos, scaffold_name)
			else
				minetest.set_node(vector.offset(pos, 0, 1, 0), {name = side_scaffold_name})
			end
		end
	end,
	buildable_to = false,
	is_ground_content = false,
	walkable = false,
	climbable = true,
	physical = true,

	on_rotate = disallow_on_rotate,

	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then
			return itemstack
		end
		local node = minetest.get_node(pointed_thing.under)
		local pos = pointed_thing.under
		if mcl_bamboo.is_protected(pos, placer) then
			return
		end
		-- todo: finish this section.
	end


})
