local S = minetest.get_translator(minetest.get_current_modname())

local mod_target = minetest.get_modpath("mcl_target")
local mod_campfire = minetest.get_modpath("mcl_campfires")
local enable_pvp = minetest.settings:get_bool("enable_pvp")

local math = math
local vector = vector

-- Time in seconds after which a stuck arrow is deleted
local ARROW_TIMEOUT = 60

-- Time after which stuck arrow is rechecked for being stuck
local STUCK_RECHECK_TIME = 5

local YAW_OFFSET = -math.pi/2

local function dir_to_pitch(dir)
	local xz = math.abs(dir.x) + math.abs(dir.z)
	return -math.atan2(-dir.y, xz)
end

local function random_arrow_positions(positions, placement)
	if positions == "x" then
		return math.random(-4, 4)
	elseif positions == "y" then
		return math.random(0, 10)
	end
	if placement == "front" and positions == "z" then
		return 3
	elseif placement == "back" and positions == "z" then
		return -3
	end
	return 0
end

local mod_awards = minetest.get_modpath("awards") and minetest.get_modpath("mcl_achievements")
local mod_button = minetest.get_modpath("mesecons_button")

minetest.register_craftitem("mcl_bows:arrow", {
	description = S("Arrow"),
	_tt_help = S("Ammunition").."\n"..S("Damage from bow: 1-10").."\n"..S("Damage from dispenser: 3"),
	_doc_items_longdesc = S("Arrows are ammunition for bows and dispensers.").."\n"..
S("An arrow fired from a bow has a regular damage of 1-9. At full charge, there's a 20% chance of a critical hit dealing 10 damage instead. An arrow fired from a dispenser always deals 3 damage.").."\n"..
S("Arrows might get stuck on solid blocks and can be retrieved again. They are also capable of pushing wooden buttons."),
	_doc_items_usagehelp = S("To use arrows as ammunition for a bow, just put them anywhere in your inventory, they will be used up automatically. To use arrows as ammunition for a dispenser, place them in the dispenser's inventory. To retrieve an arrow that sticks in a block, simply walk close to it."),
	inventory_image = "mcl_bows_arrow_inv.png",
	groups = { ammo=1, ammo_bow=1, ammo_bow_regular=1, ammo_crossbow=1 },
	_on_dispense = function(itemstack, dispenserpos, droppos, dropnode, dropdir)
		-- Shoot arrow
		local shootpos = vector.add(dispenserpos, vector.multiply(dropdir, 0.51))
		local yaw = math.atan2(dropdir.z, dropdir.x) + YAW_OFFSET
		mcl_bows.shoot_arrow(itemstack:get_name(), shootpos, dropdir, yaw, nil, 19, 3)
	end,
})

-- Destroy arrow entity self at pos and drops it as an item
local function spawn_item(self, pos)
	if not minetest.is_creative_enabled("") then
		local item = minetest.add_item(pos, "mcl_bows:arrow")
		item:set_velocity(vector.zero())
		item:set_yaw(self.object:get_yaw())
	end
	mcl_burning.extinguish(self.object)
	self.object:remove()
end

local function stuck_arrow_on_step(self, dtime)
	self._stucktimer = self._stucktimer + dtime
	self._stuckrechecktimer = self._stuckrechecktimer + dtime
	if self._stucktimer > ARROW_TIMEOUT then
		mcl_burning.extinguish(self.object)
		self._removed = true
		self.object:remove()
		return
	end

	local pos = self.object:get_pos()
	if not pos then return end

	-- Drop arrow as item when it is no longer stuck
	-- FIXME: Arrows are a bit slow to react and continue to float in mid air for a few seconds.
	if self._stuckrechecktimer > STUCK_RECHECK_TIME then
		local stuckin_def
		if self._stuckin then
			stuckin_def = minetest.registered_nodes[minetest.get_node(self._stuckin).name]
		end
		-- TODO: In MC, arrow just falls down without turning into an item
		if stuckin_def and stuckin_def.walkable == false then
			spawn_item(self, pos)
			return
		end
		self._stuckrechecktimer = 0
	end

	-- Pickup arrow if player is nearby (not in Creative Mode)
	local objects = minetest.get_objects_inside_radius(pos, 1)
	for _,obj in ipairs(objects) do
		if obj:is_player() then
			if self._collectable and not minetest.is_creative_enabled(obj:get_player_name()) then
				if obj:get_inventory():room_for_item("main", "mcl_bows:arrow") then
					obj:get_inventory():add_item("main", "mcl_bows:arrow")
					minetest.sound_play("item_drop_pickup", {
						pos = pos,
						max_hear_distance = 16,
						gain = 1.0,
					}, true)
				end
			end
			mcl_burning.extinguish(self.object)
			self.object:remove()
			return
		end
	end
end

local arrow_entity = {
	physical = true,
	pointable = false,
	visual = "mesh",
	mesh = "mcl_bows_arrow.obj",
	visual_size = {x=-1, y=1},
	textures = {"mcl_bows_arrow.png"},
	collisionbox = {-0.19, -0.125, -0.19, 0.19, 0.125, 0.19},
	collide_with_objects = false,
	_fire_damage_resistant = true,

	_save_fields = {
		"last_pos", "startpos", "damage", "is_critical", "stuck", "stuckin", "stuckin_player", "time_in_air",
	},

	_startpos=nil,
	_damage=1,	-- Damage on impact
	_is_critical=false, -- Whether this arrow would deal critical damage
	_stuck=false,   -- Whether arrow is stuck
	_stucktimer=nil,-- Amount of time (in seconds) the arrow has been stuck so far
	_stuckrechecktimer=nil,-- An additional timer for periodically re-checking the stuck status of an arrow
	_stuckin=nil,	--Position of node in which arow is stuck.
	_shooter=nil,	-- ObjectRef of player or mob who shot it
	_is_arrow = true,
	_in_player = false,
	_blocked = false,
	_viscosity=0,   -- Viscosity of node the arrow is currently in
	_deflection_cooloff=0, -- Cooloff timer after an arrow deflection, to prevent many deflections in quick succession

	_vl_projectile = {
		survive_collision = true,
		sticks_in_players = true,
		damage_groups = function(self)
			return { fleshy = self._damage }
		end,
		behaviors = {
			vl_projectile.collides_with_solids,
			vl_projectile.raycast_collides_with_entities,
		},
		allow_punching = function(self, entity_def, projectile_def, entity)
			local lua = entity:get_luaentity()
			if lua and lua.name == "mobs_mc:rover" then return false end

			return true
		end,
		sounds = {
			on_entity_collision = function(self, _, _, _, obj)
				if obj:is_player() then
					return {{name="mcl_bows_hit_player", gain=0.1}, {to_player=self._shooter:get_player_name()}, true}
				end

				return {{name="mcl_bows_hit_other", gain=0.3}, {pos=self.object:get_pos(), max_hear_distance=16}, true}
			end
		},
		on_collide_with_solid = function(self, pos, node, node_def)
			local def = node_def
			local vel = self.object:get_velocity()
			local dpos = vector.round(vector.new(pos)) -- digital pos

			-- Check for the node to which the arrow is pointing
			local dir
			if math.abs(vel.y) < 0.00001 then
				if self._last_pos.y < pos.y then
					dir = vector.new(0, 1, 0)
				else
					dir = vector.new(0, -1, 0)
				end
			else
				dir = minetest.facedir_to_dir(minetest.dir_to_facedir(minetest.yaw_to_dir(self.object:get_yaw()-YAW_OFFSET)))
			end
			self._stuckin = vector.add(dpos, dir)
			local snode = minetest.get_node(self._stuckin)
			local sdef = minetest.registered_nodes[snode.name]

			-- If node is non-walkable, unknown or ignore, don't make arrow stuck.
			-- This causes a deflection in the engine.
			if not sdef or sdef.walkable == false or snode.name == "ignore" then
				self._stuckin = nil
				if self._deflection_cooloff <= 0 then
					-- Lose 1/3 of velocity on deflection
					local newvel = vector.multiply(vel, 0.6667)

					self.object:set_velocity(newvel)
					-- Reset deflection cooloff timer to prevent many deflections happening in quick succession
					self._deflection_cooloff = 1.0
				end
				return
			end

			-- Node was walkable, make arrow stuck
			self._stuck = true
			self._stucktimer = 0
			self._stuckrechecktimer = 0

			self.object:set_velocity(vector.zero())
			self.object:set_acceleration(vector.zero())

			minetest.sound_play({name="mcl_bows_hit_other", gain=0.3}, {pos=self.object:get_pos(), max_hear_distance=16}, true)

			if mcl_burning.is_burning(self.object) and snode.name == "mcl_tnt:tnt" then
				tnt.ignite(self._stuckin)
			end

			-- Ignite Campfires
			if mod_campfire and mcl_burning.is_burning(self.object) and minetest.get_item_group(snode.name, "campfire") ~= 0 then
				mcl_campfires.light_campfire(self._stuckin)
			end

			-- Activate target
			if mod_target and snode.name == "mcl_target:target_off" then
				mcl_target.hit(self._stuckin, 1) --10 redstone ticks
			end

			-- Push the button! Push, push, push the button!
			if mod_button and minetest.get_item_group(node.name, "button") > 0 and minetest.get_item_group(node.name, "button_push_by_arrow") == 1 then
				local bdir = minetest.wallmounted_to_dir(node.param2)
				-- Check the button orientation
				if vector.equals(vector.add(dpos, bdir), self._stuckin) then
					mesecon.push_button(dpos, node)
				end
			end
		end,
		on_collide_with_entity = function(self, pos, obj)
			local is_player = obj:is_player()
			local lua = obj:get_luaentity()

			-- Make sure collision is valid
			if obj == self._shooter then
				if self._time_in_air < 1.02 then return end
			else
				if not (is_player or (lua and (lua.is_mob or lua._hittable_by_projectile))) then
					return
				end
			end

			if obj:get_hp() > 0 then
				-- Check if there is no solid node between arrow and object
				-- TODO: remove. this code should never occur if vl_projectile is working correctly
				local ray = minetest.raycast(self.object:get_pos(), obj:get_pos(), true)
				for pointed_thing in ray do
					if pointed_thing.type == "object" and pointed_thing.ref == obj then
						-- Target reached! We can proceed now.
						break
					elseif pointed_thing.type == "node" then
						local nn = minetest.get_node(minetest.get_pointed_thing_position(pointed_thing)).name
						local def = minetest.registered_nodes[nn]
						if (not def) or def.walkable then
							-- There's a node in the way. Delete arrow without damage
							mcl_burning.extinguish(self.object)
							self.object:remove()
							return
						end
					end
				end

				if lua then
					local entity_name = lua.name
					-- Achievement for hitting skeleton, wither skeleton or stray (TODO) with an arrow at least 50 meters away
					-- NOTE: Range has been reduced because mobs unload much earlier than that ... >_>
					-- TODO: This achievement should be given for the kill, not just a hit
					if self._shooter and self._shooter:is_player() and vector.distance(pos, self._startpos) >= 20 then
						if mod_awards and (entity_name == "mobs_mc:skeleton" or entity_name == "mobs_mc:stray" or entity_name == "mobs_mc:witherskeleton") then
							awards.unlock(self._shooter:get_player_name(), "mcl:snipeSkeleton")
						end
					end
				end
			end

			if not obj:is_player() then
				mcl_burning.extinguish(self.object)
				if self._piercing == 0 then
					self._removed = true
					self.object:remove()
				end
			end

			-- Item definition entity collision hook
			local item_def = minetest.registered_items[self._arrow_item]
			local hook = item_def and item_def._on_collide_with_entity
			if hook then hook(self, pos, obj) end

			-- Because arrows are flagged to survive collisions to allow sticking into blocks, manually remove it now that it
			-- has collided with an entity
			self._removed = true
			self.object:remove()
		end
	},
	on_step = function(self, dtime)
		mcl_burning.tick(self.object, dtime, self)

		-- mcl_burning.tick may remove object immediately
		if not self.object:get_pos() then return end

		self._time_in_air = self._time_in_air + dtime

		-- Give the arrows a maximum flight time
		if self._time_in_air > ARROW_TIMEOUT then
			self._removed = true
			self.object:remove()
		end

		local pos = self.object:get_pos()
		--local dpos = vector.round(vector.new(pos)) -- digital pos
		--local node = minetest.get_node(dpos)

		if self._stuck then
			return stuck_arrow_on_step(self, dtime)
		end

		-- Add tracer
		if self._damage >= 9 and self._in_player == false then
			minetest.add_particlespawner({
				amount = 20,
				time = .2,
				minpos = vector.new(0,0,0),
				maxpos = vector.new(0,0,0),
				minvel = vector.new(-0.1,-0.1,-0.1),
				maxvel = vector.new(0.1,0.1,0.1),
				minexptime = 0.5,
				maxexptime = 0.5,
				minsize = 2,
				maxsize = 2,
				attached = self.object,
				collisiondetection = false,
				vertical = false,
				texture = "mobs_mc_arrow_particle.png",
				glow = 1,
			})
		end

		if self._deflection_cooloff > 0 then
			self._deflection_cooloff = self._deflection_cooloff - dtime
		end

		-- TODO: change to use vl_physics
		-- TODO: move to vl_projectile
		local def = minetest.registered_nodes[minetest.get_node(pos).name]
		if def and def.liquidtype ~= "none" then
			-- Slow down arrow in liquids
			local v = def.liquid_viscosity or 0
			self._viscosity = v

			local vpenalty = math.max(0.1, 0.98 - 0.1 * v)
			local vel = self.object:get_velocity()
			if math.abs(vel.x) > 0.001 then
				vel.x = vel.x * vpenalty
			end
			if math.abs(vel.z) > 0.001 then
				vel.z = vel.z * vpenalty
			end
			self.object:set_velocity(vel)
		end

		-- Process as projectile
		vl_projectile.update_projectile(self, dtime)

		-- Update yaw
		local vel = self.object:get_velocity()
		if vel and not self._stuck then
			local yaw = minetest.dir_to_yaw(vel)+YAW_OFFSET
			local pitch = dir_to_pitch(vel)
			self.object:set_rotation(vector.new(0,yaw,pitch))
		end
	end,

	-- Force recheck of stuck arrows when punched.
	-- Otherwise, punching has no effect.
	on_punch = function(self)
		if self._stuck then
			self._stuckrechecktimer = STUCK_RECHECK_TIME
		end
	end,
	get_staticdata = function(self)
		local out = {}
		local save_fields = self._save_fields
		for i = 1,#save_fields do
			local field = save_fields[i]
			out[field] = self["_"..field]
		end

		if self._stuck then
			-- If _stucktimer is missing for some reason, assume the maximum
			if not self._stucktimer then
				self._stucktimer = ARROW_TIMEOUT
			end
			out.stuckstarttime = minetest.get_gametime() - self._stucktimer
		end

		if self._shooter and self._shooter:is_player() then
			out.shootername = self._shooter:get_player_name()
		end
		return minetest.serialize(out)
	end,
	on_activate = function(self, staticdata, dtime_s)
		self.object:set_armor_groups({ immortal = 1 })

		self._time_in_air = 1.0
		local data = minetest.deserialize(staticdata)
		if not data then return end

		-- Restore arrow state
		local save_fields = self._save_fields
		for i = 1,#save_fields do
			local field = save_fields[i]
			self["_"..field] = data[field]
		end

		if data.stuckstarttime then
			-- First, check if the stuck arrow is aleady past its life timer.
			-- If yes, delete it.
			self._stucktimer = minetest.get_gametime() - data.stuckstarttime
		end

		-- Perform a stuck recheck on the next step.
		self._stuckrechecktimer = STUCK_RECHECK_TIME

		if data.shootername then
			local shooter = minetest.get_player_by_name(data.shootername)
			if shooter and shooter:is_player() then
				self._shooter = shooter
			end
		end

		if data.stuckin_player then
			self._removed = true
			self.object:remove()
		end
	end,
}

-- Make the arrow entity available to other mods as a template
mcl_bows.arrow_entity = table.copy(arrow_entity)

vl_projectile.register("mcl_bows:arrow_entity", arrow_entity)

minetest.register_on_respawnplayer(function(player)
	for _, obj in pairs(player:get_children()) do
		local ent = obj:get_luaentity()
		if ent and ent.name and string.find(ent.name, "mcl_bows:arrow_entity") then
			obj:remove()
		end
	end
end)

if minetest.get_modpath("mcl_core") and minetest.get_modpath("mcl_mobitems") then
	minetest.register_craft({
		output = "mcl_bows:arrow 4",
		recipe = {
			{"mcl_core:flint"},
			{"mcl_core:stick"},
			{"mcl_mobitems:feather"}
		}
	})
end

if minetest.get_modpath("doc_identifier") then
	doc.sub.identifier.register_object("mcl_bows:arrow_entity", "craftitems", "mcl_bows:arrow")
end
