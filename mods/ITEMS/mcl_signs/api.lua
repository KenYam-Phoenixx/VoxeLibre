local S, charmap = ...

local function table_merge(t, ...)
	local t2 = table.copy(t)
	return table.update(t2, ...)
end

local SIGN_WIDTH = 115

local LINE_LENGTH = 15
local NUMBER_OF_LINES = 4

local LINE_HEIGHT = 14
local CHAR_WIDTH = 5

local DEFAULT_COLOR = "#000000"
local DYE_TO_COLOR = {
	["white"] = "#d0d6d7",
	["grey"] = "#818177",
	["dark_grey"] = "#383c40",
	["black"] = "#080a10",
	["violet"] = "#6821a0",
	["blue"] = "#2e3094",
	["lightblue"] = "#258ec9",
	["cyan"] = "#167b8c",
	["dark_green"] = "#4b5e25",
	["green"] = "#60ac19",
	["yellow"] = "#f1b216",
	["brown"] = "#633d20",
	["orange"] = "#e26501",
	["red"] = "#912222",
	["magenta"] = "#ab31a2",
	["pink"] = "#d56791",
}

local wordwrap_enabled = core.settings:get_bool("vl_signs_word_wrap", true)

local SIGN_GLOW_INTENSITY = 14

local F = core.formspec_escape

-- Template definition
local sign_tpl = {
	_tt_help = S("Can be written"),
	_doc_items_longdesc = S("Signs can be written and come in two variants: Wall sign and sign on a sign post. Signs can be placed on the top and the sides of other blocks, but not below them."),
	_doc_items_usagehelp = S("After placing the sign, you can write something on it. You have @1 lines of text with up to @2 characters for each line; anything beyond these limits is lost. Not all characters are supported. The text can not be changed once it has been written; you have to break and place the sign again. Can be colored and made to glow. Use bone meal to remove color and glow.", NUMBER_OF_LINES, LINE_LENGTH),
	use_texture_alpha = "opaque",
	sunlight_propagates = true,
	walkable = false,
	is_ground_content = false,
	paramtype2 = "degrotate",
	drawtype = "mesh",
	mesh = "mcl_signs_sign.obj",
	paramtype = "light",
	selection_box = {
		type = "fixed",
		fixed = {-0.2, -0.5, -0.2, 0.2, 0.5, 0.2}
	},
	groups = {axey = 1, handy = 2, sign = 1, not_in_creative_inventory = 1},
	stack_max = 16,
	sounds = mcl_sounds.node_sound_wood_defaults(),
	node_placement_prediction = "",
	_mcl_sign_type = "standing"
}

-- Signs data / meta
local function normalize_rotation(rot)
	return math.floor(0.5 + rot / 15) * 15
end

local function get_signdata(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	if not def or core.get_item_group(node.name, "sign") < 1 then return end
	local meta = core.get_meta(pos)
	local text = meta:get_string("text")
	local color = meta:get_string("color")
	local glow = core.is_yes(meta:get_string("glow"))
	local yaw, spos
	local typ = "standing"
	if def.paramtype2  == "wallmounted" then
		typ = "wall"
		local dir = core.wallmounted_to_dir(node.param2)
		spos = vector.add(vector.offset(pos, 0, -0.25, 0), dir * 0.41)
		yaw = core.dir_to_yaw(dir)
	else
		yaw = math.rad(((node.param2 * 1.5 ) + 1 ) % 360)
		local dir = core.yaw_to_dir(yaw)
		spos = vector.add(vector.offset(pos, 0, 0.08, 0), dir * -0.05)
	end
	if color == "" then color = DEFAULT_COLOR end
	return {
		text = text,
		color = color,
		yaw = yaw,
		node = node,
		typ = typ,
		glow = glow,
		text_pos = spos,
	}
end

local function set_signmeta(pos, def)
	local meta = core.get_meta(pos)
	if def.text then meta:set_string("text", def.text) end
	if def.color then meta:set_string("color", def.color) end
	if def.glow then meta:set_string("glow", def.glow) end
end

local function word_wrap(str)
	local output = {}
	for line in str:gmatch("[^\r\n]*") do
		local nline = ""
		for word in line:gmatch("%S+") do
			if #nline + #word + 1 > LINE_LENGTH then
				if nline ~= "" then table.insert(output, nline) end
				nline = word
			else
				if nline ~= "" then nline = nline .. " " end
				nline = nline .. word
			end
		end
		table.insert(output, nline)
	end
	return table.concat(output, "\n")
end

local function string_to_line_array(str)
	local linechar_table = {}
	local current = 1
	local linechar = 1
	local cr_last = false
	linechar_table[current] = ""

	-- compile characters
	for char in str:gmatch(".") do
		local add
		local is_cr, is_lf = char == "\r", char == "\n"

		if is_cr and not cr_last then
			cr_last = true
			add = false
		elseif is_lf or cr_last or linechar > LINE_LENGTH then
			cr_last = is_cr
			add = not (is_cr or is_lf)
			current = current + 1
			linechar_table[current] = ""
			linechar = 1
		else
			add = true
		end

		if add then
			linechar_table[current] = linechar_table[current] .. char
			linechar = linechar + 1
		end
	end

	return linechar_table
end

function mcl_signs.create_lines(text)
	local text_table = {}
	for idx, line in ipairs(string_to_line_array(text)) do
		if idx > NUMBER_OF_LINES then
			break
		end
		table.insert(text_table, line)
	end
	return text_table
end

function mcl_signs.generate_line(s, ypos)
	local i = 1
	local parsed = {}
	local width = 0
	local chars = 0
	local printed_char_width = CHAR_WIDTH + 1
	while chars < LINE_LENGTH and i <= #s do
		local file
		-- Get and render character
		if charmap[s:sub(i, i)] then
			file = charmap[s:sub(i, i)]
			i = i + 1
		elseif i < #s and charmap[s:sub(i, i + 1)] then
			file = charmap[s:sub(i, i + 1)]
			i = i + 2
		else
			-- Use replacement character:
			file = "_rc"
			i = i + 1
		end
		if file then
			width = width + printed_char_width
			table.insert(parsed, file)
			chars = chars + 1
		end
	end
	width = width - 1
	local texture = ""
	local xpos = math.floor((SIGN_WIDTH - width) / 2)

	for _, file in ipairs(parsed) do
		texture = texture .. ":" .. xpos .. "," .. ypos .. "=" .. file.. ".png"
		xpos = xpos + printed_char_width
	end
	return texture
end

function mcl_signs.generate_texture(data)
	data.text = data.text or ""
	--local lines = mcl_signs.create_lines(data.wordwrap and word_wrap(data.text) or data.text)
	local lines = mcl_signs.create_lines(wordwrap_enabled and word_wrap(data.text) or data.text)
	local texture = "[combine:" .. SIGN_WIDTH .. "x" .. SIGN_WIDTH
	local ypos = 0
	local letter_color = data.color or DEFAULT_COLOR

	for _, line in ipairs(lines) do
		texture = texture .. mcl_signs.generate_line(line, ypos)
		ypos = ypos + LINE_HEIGHT
	end

	texture = "(" .. texture .. "^[multiply:" .. letter_color .. ")"
	return texture
end

function sign_tpl.on_place(itemstack, placer, pointed_thing)
	if pointed_thing.type ~= "node" then
		return itemstack
	end

	local under = pointed_thing.under
	local node = core.get_node(under)
	local def = core.registered_nodes[node.name]
	if not def then return itemstack end

	if mcl_util.call_on_rightclick(itemstack, placer, pointed_thing) then
		return itemstack
	end

	local above = pointed_thing.above
	local dir = vector.subtract(under, above)
	local wdir = core.dir_to_wallmounted(dir)

	local itemstring = itemstack:get_name()
	local placestack = ItemStack(itemstack)
	local def = itemstack:get_definition()

	local pos
	-- place on wall
	if wdir ~= 0 and wdir ~= 1 then
		placestack:set_name("mcl_signs:wall_sign_"..def._mcl_sign_wood)
		itemstack, pos = core.item_place_node(placestack, placer, pointed_thing, wdir)
	elseif wdir == 1 then -- standing, not ceiling
		placestack:set_name("mcl_signs:standing_sign_"..def._mcl_sign_wood)
		-- param2 value is degrees / 1.5
		local rot = normalize_rotation(placer:get_look_horizontal() * 180 / math.pi / 1.5)
		itemstack, pos = core.item_place_node(placestack, placer, pointed_thing, rot)
	else
		return itemstack
	end

	mcl_signs.show_formspec(placer, pos)
	itemstack:set_name(itemstring)
	return itemstack
end

function sign_tpl.on_rightclick(pos, _, clicker, itemstack)
	local iname = itemstack:get_name()
	if iname == "mcl_mobitems:glow_ink_sac" then
		local data = get_signdata(pos)
		if data then
			if data.color == "#000000" then
				data.color = "#7e7e7e" -- black doesn't glow in the dark
			end
			set_signmeta(pos, {glow = "true", color = data.color})
			mcl_signs.update_sign(pos)
			if not core.is_creative_enabled(clicker:get_player_name()) then
				itemstack:take_item()
			end
		end
	elseif iname == "mcl_bone_meal:bone_meal" then
		set_signmeta(pos, {
			glow = "false",
			color = DEFAULT_COLOR,
		})
		mcl_signs.update_sign(pos)
	elseif iname:sub(1, 8) == "mcl_dye:" then
		local color = iname:sub(9)
		set_signmeta(pos, {color = DYE_TO_COLOR[color]})
		mcl_signs.update_sign(pos)
		if not core.is_creative_enabled(clicker:get_player_name()) then
			itemstack:take_item()
		end
	elseif not mcl_util.check_position_protection(pos, clicker) then
		mcl_signs.show_formspec(clicker, pos)
	end
	return itemstack
end

function sign_tpl.on_destruct(pos)
	mcl_signs.get_text_entity(pos, true)
end

-- TODO: reactivate when a good dyes API is finished
--function sign_tpl._on_dye_place(pos, color)
--	set_signmeta(pos, {
--		color = mcl_dyes.colors[color].rgb
--	})
--	mcl_signs.update_sign(pos)
--end

local sign_wall = table_merge(sign_tpl, {
	mesh = "mcl_signs_signonwallmount.obj",
	paramtype2 = "wallmounted",
	selection_box = {
		type = "wallmounted",
		wall_side = {-0.5, -7/28, -0.5, -23/56, 7/28, 0.5}
	},
	groups = {axey = 1, handy = 2, sign = 1, deco_block = 1},
	_mcl_sign_type = "wall",
})

-- Formspec
function mcl_signs.show_formspec(player, pos)
	if not pos then return end
	local meta = core.get_meta(pos)
	local old_text = meta:get_string("text")
	core.show_formspec(player:get_player_name(), "mcl_signs:set_text_"..pos.x.."_"..pos.y.."_"..pos.z, table.concat({
		"size[6,3]textarea[0.25,0.25;6,1.5;text;",
		F(S("Enter sign text:")), ";", F(old_text), "]",
		"label[0,1.5;",
			F(S("Maximum line length: @1", LINE_LENGTH)), "\n",
			F(S("Maximum lines: @1", NUMBER_OF_LINES)),
		"]",
		"button_exit[0,2.5;6,1;submit;", F(S("Done")), "]"
	}))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:find("mcl_signs:set_text_") == 1 then
		local x, y, z = formname:match("mcl_signs:set_text_(.-)_(.-)_(.*)")
		local pos = vector.new(tonumber(x), tonumber(y), tonumber(z))
		if not fields or not fields.text then return end
		if not mcl_util.check_position_protection(pos, player) then
			set_signmeta(pos, {
				-- limit saved text to 256 characters
				-- (4 lines x 15 chars = 60 so this should be more than is ever needed)
				text = tostring(fields.text):sub(1, 256)
			})
			mcl_signs.update_sign(pos)
		end
	end
end)

-- Text entity handling
function mcl_signs.get_text_entity(pos, force_remove)
	local objects = core.get_objects_inside_radius(pos, 0.5)
	local text_entity
	local i = 0
	for _, v in pairs(objects) do
		local ent = v:get_luaentity()
		if ent and ent.name == "mcl_signs:text" then
			i = i + 1
			if i > 1 or force_remove == true then
				v:remove()
			else
				text_entity = v
			end
		end
	end
	return text_entity
end

function mcl_signs.update_sign(pos)
	local data = get_signdata(pos)

	local text_entity = mcl_signs.get_text_entity(pos)
	if text_entity and not data then
		text_entity:remove()
		return false
	elseif not data then
		return false
	elseif not text_entity then
		text_entity = core.add_entity(data.text_pos, "mcl_signs:text")
		if not text_entity or not text_entity:get_pos() then return end
	end

	local glow = 0
	if data.glow then
		glow = SIGN_GLOW_INTENSITY
	end
	text_entity:set_properties({
		textures = {mcl_signs.generate_texture(data)},
		glow = glow,
	})
	text_entity:set_yaw(data.yaw)
	text_entity:set_armor_groups({immortal = 1})
	return true
end

core.register_lbm({
	nodenames = {"group:sign"},
	name = "mcl_signs:restore_entities",
	label = "Restore sign text",
	run_at_every_load = true,
	action = function(pos)
		mcl_signs.update_sign(pos)
	end
})

core.register_entity("mcl_signs:text", {
	initial_properties = {
		pointable = false,
		visual = "upright_sprite",
		physical = false,
		collide_with_objects = false,
	},
	on_activate = function(self)
		local pos = self.object:get_pos()
		mcl_signs.update_sign(pos)
		local props = self.object:get_properties()
		local t = props and props.textures
		if type(t) ~= "table" or #t == 0 then self.object:remove() end
	end,
})

local function colored_texture(texture, color)
	return texture.."^[multiply:"..color
end

function mcl_signs.register_sign(name, color, def)
	local newfields = {
		tiles = {colored_texture("mcl_signs_sign_greyscale.png", color)},
		inventory_image = colored_texture("mcl_signs_default_sign_greyscale.png", color),
		wield_image = colored_texture("mcl_signs_default_sign_greyscale.png", color),
		drop = "mcl_signs:wall_sign_"..name,
		_mcl_sign_wood = name,
	}

	def = def or {}
	core.register_node(":mcl_signs:standing_sign_"..name, table_merge(sign_tpl, newfields, def))
	core.register_node(":mcl_signs:wall_sign_"..name, table_merge(sign_wall, newfields, def))
end
