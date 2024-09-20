local registered_generators = {}

local lvm, nodes, param2 = 0, 0, 0
local lvm_buffer, lvm_buffer2 = {}, {}

local logging = minetest.settings:get_bool("mcl_logging_mapgen", false)
local log_timing = minetest.settings:get_bool("mcl_logging_mapgen_timing", false) -- detailed, for performance debugging

local function run_generators(minp, maxp, blockseed)
	if nodes == 0 then return end
	for _, rec in ipairs(registered_generators) do
		if rec.nf then
			local gt1 = os.clock()
			local p1, p2 = vector.copy(minp), vector.copy(maxp) -- defensive copies
			rec.nf(p1, p2, blockseed)
			if log_timing then
				minetest.log("action", string.format("[mcl_mapgen_core] %-20s %s ... %s %8.2fms", rec.id, minetest.pos_to_string(minp), minetest.pos_to_string(maxp), (os.clock() - gt1)*1000))
			end
		end
	end
end

local function update_data (vm, data, data2)
	-- Write stuff
	vm:set_data(data)
	if param2 > 0 then
		vm:set_param2_data(data2)
	end
end

local function post_generator_processing(vm, minp, maxp, deco_used, deco_table, ore_used, ore_table)
	if deco_table then
		minetest.generate_decorations(vm,vector.new(minp.x,deco_table.min,minp.z),vector.new(maxp.x,deco_table.max,maxp.z))
	elseif deco_used then
		minetest.generate_decorations(vm)
	end
	if ore_table then
		minetest.generate_ores(vm,vector.new(minp.x,ore_table.min,minp.z),vector.new(maxp.x,ore_table.max,maxp.z))
	elseif ore_used then
		minetest.generate_ores(vm)
	end
end

local function post_generator_processing_2(vm, p1, p2, shadow)
	vm:calc_lighting(p1, p2, shadow)
	vm:write_to_map()
	vm:update_liquids()
end

minetest.register_on_generated(function(minp, maxp, blockseed)
	local t1 = os.clock()
	if lvm > 0 then
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local area = VoxelArea(emin, emax)
		local data = vm:get_data(lvm_buffer)
		local data2 = param2 > 0 and vm:get_param2_data(lvm_buffer2)
		if log_timing then
			minetest.log("action", string.format("[mcl_mapgen_core] %-20s %s ... %s %8.2fms", "get_data", minetest.pos_to_string(minp), minetest.pos_to_string(maxp), (os.clock() - t1)*1000))
		end

		local lvm_used, shadow, deco_used, deco_table, ore_used, ore_table = false, false, false, false, false, false
		for _, rec in ipairs(registered_generators) do
			if rec.vf then
				local gt1 = os.clock()
				local p1, p2 = vector.copy(minp), vector.copy(maxp) -- defensive copies
				local e1, e2 = vector.copy(emin), vector.copy(emax) -- defensive copies
				local lvm_used0, shadow0, deco, ore = rec.vf(vm, data, data2, e1, e2, area, p1, p2, blockseed)
				lvm_used = lvm_used or lvm_used0
				shadow = shadow or shadow0
				if deco and type(deco) == "table" then
					deco_table = deco
				elseif deco then
					deco_used = true
				end
				if ore and type(ore) == "table" then
					ore_table = ore
				elseif deco then
					ore_used = true
				end
				if log_timing then
					minetest.log("action", string.format("[mcl_mapgen_core] %-20s %s ... %s %8.2fms", rec.id, minetest.pos_to_string(minp), minetest.pos_to_string(maxp), (os.clock() - gt1)*1000))
				end
			end
		end

		if lvm_used then
			local gt1 = os.clock()
			vm:set_data(data)
			if param2 > 0 then vm:set_param2_data(data2) end
			if log_timing then
				minetest.log("action", string.format("[mcl_mapgen_core] %-20s %s ... %s %8.2fms", "set_data", minetest.pos_to_string(minp), minetest.pos_to_string(maxp), (os.clock() - gt1)*1000))
			end
			local gt1 = os.clock()
			if deco_table then
				minetest.generate_decorations(vm,vector.new(minp.x,deco_table.min,minp.z),vector.new(maxp.x,deco_table.max,maxp.z))
			elseif deco_used then
				minetest.generate_decorations(vm)
			end
			if log_timing and (deco_table or deco_used) then
				minetest.log("action", string.format("[mcl_mapgen_core] %-20s %s ... %s %8.2fms", "decorations", minetest.pos_to_string(minp), minetest.pos_to_string(maxp), (os.clock() - gt1)*1000))
			end
			local gt1 = os.clock()
			if ore_table then
				minetest.generate_ores(vm,vector.new(minp.x,ore_table.min,minp.z),vector.new(maxp.x,ore_table.max,maxp.z))
			elseif ore_used then
				minetest.generate_ores(vm)
			end
			if log_timing and (ore_table or ore_used) then
				minetest.log("action", string.format("[mcl_mapgen_core] %-20s %s ... %s %8.2fms", "ores", minetest.pos_to_string(minp), minetest.pos_to_string(maxp), (os.clock() - gt1)*1000))
			end
			local gt1 = os.clock()
			vm:calc_lighting(minp, maxp, shadow)
			vm:write_to_map()
			vm:update_liquids()
			if log_timing then
				minetest.log("action", string.format("[mcl_mapgen_core] %-20s %s ... %s %8.2fms", "light/write/liquids", minetest.pos_to_string(minp), minetest.pos_to_string(maxp), (os.clock() - gt1)*1000))
			end
		end
	end

	run_generators(minp, maxp, blockseed)

	mcl_vars.add_chunk(minp)
	if logging then
		minetest.log("action", string.format("[mcl_mapgen_core] %-20s %s ... %s %8.2fms", "Generating chunk", minetest.pos_to_string(minp), minetest.pos_to_string(maxp), (os.clock() - t1)*1000))
	end
end)

function minetest.register_on_generated(node_function)
	mcl_mapgen_core.register_generator("mod_"..minetest.get_current_modname().."_"..tostring(#registered_generators+1), nil, node_function)
end

function mcl_mapgen_core.register_generator(id, lvm_function, node_function, priority, needs_param2)
	if not id then return end

	local priority = priority or 5000

	if lvm_function then lvm = lvm + 1 end
	if node_function then nodes = nodes + 1 end
	if needs_param2 then param2 = param2 + 1 end

	local new_record = {
		id = id,
		i = priority,
		vf = lvm_function,
		nf = node_function,
		needs_param2 = needs_param2,
	}

	table.insert(registered_generators, new_record)
	table.sort(registered_generators, function(a, b)
		return (a.i < b.i) or ((a.i == b.i) and a.vf and (b.vf == nil))
	end)
end

function mcl_mapgen_core.unregister_generator(id)
	local index
	for i, gen in ipairs(registered_generators) do
		if gen.id == id then
			index = i
			break
		end
	end
	if not index then return end
	local rec = registered_generators[index]
	table.remove(registered_generators, index)
	if rec.vf then lvm = lvm - 1 end
	if rec.nf then nodes = nodes - 1 end
	if rec.needs_param2 then param2 = param2 - 1 end
	--if rec.needs_level0 then level0 = level0 - 1 end
end

-- Try to make decorations more deterministic in order, by sorting by priority and name
-- At least for low-priority this should make map seeds more comparable, but
-- adding for example a new structure can still change everything that comes
-- later, because currently decoration blockseeds are incremented sequentially
-- c.f., https://github.com/minetest/minetest/issues/14919
local minetest_register_decoration = minetest.register_decoration
local pending_decorations = {}
function mcl_mapgen_core.register_decoration(def, callback)
	if pending_decorations == nil then
		minetest.log("warning", "Decoration registered after mapgen: "..tostring(def.name))
		minetest_register_decoration(def)
		if callback ~= nil then callback() end
		return
	end
	def = table.copy(def) -- defensive deep copy, needed for water lily
	def.callback = callback
	table.insert(pending_decorations, def)
end
local function sort_decorations()
	local keys, map = {}, {}
	for i, def in pairs(pending_decorations) do
		local name = def.name
		-- we try to generate fallback names to make order more deterministic
		name = name or (def.decoration and string.format("%s:%04d", def.decoration, i))
		if not name and type(def.schematic) == "string" then
			local sc = string.split(def.schematic, "/")
			name = string.format("%s:%04d", sc[#sc], i)
		end
		if not name and type(def.schematic) == "table" and def.schematic.data then
			name = ""
			for _, v in ipairs(def.schematic.data) do
				if v.name then name = name .. v.name .. ":" end
			end
			name = name .. string.format("%04d", i)
		end
		name = name or string.format("%04d", i)
		local prio = (def.priority or 1000) + i/1000
		local key = string.format("%08.3f:%s", prio, name)
		table.insert(keys, key)
		map[key] = def
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		-- minetest.log("action", "Deco: "..key)
		minetest_register_decoration(map[key])
		if map[key].callback then map[key].callback() end
	end
	pending_decorations = nil -- as we will not run again
end
minetest.register_on_mods_loaded(sort_decorations)
