mcl_particles = {}

-- Table of particlespawner IDs on a per-node hash basis
-- Keys: node position hashes
-- Values: Tables of particlespawner IDs (each node pos can have an arbitrary number of particlespawners)
local particle_nodes = {}

-- Node particles can be disabled via setting
local node_particles_allowed = minetest.settings:get("mcl_node_particles") or "none"

local levels = {
	high = 3,
	medium = 2,
	low = 1,
	none = 0,
}

allowed_level = levels[node_particles_allowed]
if not allowed_level then
	allowed_level = levels["none"]
end


-- Add a particlespawner that is assigned to a given node position.
-- * pos: Node positon. MUST use integer values!
-- * particlespawner_definition: definition for minetest.add_particlespawner
-- * level: detail level of particles. "high", "medium", "low" or "none". High detail levels are for
-- CPU-demanding particles, like smoke of fire (which occurs frequently)
-- NOTE: All particlespawners are automatically removed on shutdown.
-- Returns particlespawner ID on succcess and nil on failure
function mcl_particles.add_node_particlespawner(pos, particlespawner_definition, level)
	if allowed_level == 0 or levels[level] > allowed_level then
		return
	end
	local poshash = minetest.hash_node_position(pos)
	if not poshash then
		return
	end
	local id = minetest.add_particlespawner(particlespawner_definition)
	if id == -1 then
		return
	end
	if not particle_nodes[poshash] then
		particle_nodes[poshash] = {}
	end
	table.insert(particle_nodes[poshash], id)
	return id
end

-- Deletes all particlespawners that are assigned to a node position.
-- If no particlespawners exist for this position, nothing happens.
-- pos: Node positon. MUST use integer values!
-- Returns true if particlespawner could be removed and false if not
function mcl_particles.delete_node_particlespawners(pos)
	if allowed_level == 0 then
		return false
	end
	local poshash = minetest.hash_node_position(pos)
	local ids = particle_nodes[poshash]
	if ids then
		for i=1, #ids do
			minetest.delete_particlespawner(ids[i])
		end
		particle_nodes[poshash] = nil
		return true
	end
	return false
end

-- 3 exptime variants because the animation is not tied to particle expiration time.
-- 3 colorized variants to imitate minecraft's

function mcl_particles.get_smoke_def(def_base)
	local defs = {}

	local def = table.copy(def_base)
	def.amount = def.amount / 9
	def.time = 0
	def.animation = {
		type = "vertical_frames",
		aspect_w = 8,
		aspect_h = 8,
		-- length = 3 exptime variants
	}
	def.collisiondetection = true

	-- the last frame plays for 1/8 * N seconds, so we can take advantage of it
	-- to have varying exptime for each variant.
	local exptimes = {0.175, 0.375, 1.0}
	local colorizes = {"199", "209", "243"} -- round(78%, 82%, 90% of 256) - 1
	for _, exptime in ipairs(exptimes) do
		for _, colorize in ipairs(colorizes) do
			def.maxexptime = exptime * def_base.maxexptime
			def.animation.length = exptime + 0.1
			-- minexptime must be set such that the last frame is actully rendered,
			-- even if its very short. Larger exptime -> larger range
			def.minexptime = math.min(exptime, (7.0 / 8.0 * (exptime + 0.1) + 0.1))
			def.texture = "mcl_particles_smoke_anim.png^[colorize:#000000:" .. colorize

			table.insert(defs, table.copy(def))
		end
	end

	return defs
end

function mcl_particles.add_node_smoke_particlespawner(pos, defs)
	local minpos = vector.add(pos, defs[1].minrelpos)
	local maxpos = vector.add(pos, defs[1].maxrelpos)

	for i, def in ipairs(defs) do
		def.minpos = minpos
		def.maxpos = maxpos
		def.attached = nil
		mcl_particles.add_node_particlespawner(pos, def, "high")
	end
end

function mcl_particles.add_object_smoke_particlespawner(obj, defs)
	local minpos = defs[1].minrelpos
	local maxpos = defs[1].maxrelpos

	for i, def in ipairs(defs) do
		def.minpos = def.minrelpos
		def.maxpos = def.maxrelpos
		def.attached = obj
		minetest.add_particlespawner(def)
	end
end
