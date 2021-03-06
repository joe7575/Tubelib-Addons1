--[[

	Tubelib Addons 1
	================

	Copyright (C) 2017,2018 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	funnel.lua
	
]]--

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if listname == "main" then
		return stack:get_count()
	end
	return 0
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

local function formspec()
	return "size[9,7]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"list[context;main;0.5,0;8,2;]"..
	"list[current_player;main;0.5,3.3;8,4;]"..
	"listring[context;main]"..
	"listring[current_player;main]"
end

local function scan_for_objects(pos, elapsed)
	local meta = minetest.get_meta(pos)
	for _, object in pairs(minetest.get_objects_inside_radius(pos, 1)) do
		local lua_entity = object:get_luaentity()
		if not object:is_player() and lua_entity and lua_entity.name == "__builtin:item" then
			local obj_pos = object:getpos()
			if lua_entity.itemstring ~= "" and ((obj_pos.y - pos.y) >= 0.4) then
				if tubelib.put_item(meta, "main", lua_entity.itemstring) then
					lua_entity.itemstring = ""
					object:remove()
				end
			end
			
		end
	end
	return true
end

minetest.register_node("tubelib_addons1:funnel", {
	description = "Tubelib Funnel",
	tiles = {
		-- up, down, right, left, back, front
		'tubelib_addons1_funnel_top.png',
		'tubelib_addons1_funnel_top.png',
		'tubelib_addons1_funnel.png',
	},

	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-8/16, -8/16, -8/16,  8/16, 8/16, -6/16},
			{-8/16, -8/16,  6/16,  8/16, 8/16,  8/16},
			{-8/16, -8/16, -8/16, -6/16, 8/16,  8/16},
			{ 6/16, -8/16, -8/16,  8/16, 8/16,  8/16},
			{-6/16, -8/16, -6/16,  6/16, 4/16,  6/16},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {-8/16, -8/16, -8/16,   8/16, 8/16, 8/16},
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size('main', 16)
	end,
	
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local facedir = minetest.dir_to_facedir(placer:get_look_dir(), false)
		meta:set_string("formspec", formspec())
		minetest.get_node_timer(pos):start(1)
	end,

	on_timer = scan_for_objects,
		
	on_dig = function(pos, node, puncher, pointed_thing)
		if minetest.is_protected(pos, puncher:get_player_name()) then
			return
		end
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		if inv:is_empty("main") then
			minetest.node_dig(pos, node, puncher, pointed_thing)
		end
	end,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = {choppy=2, cracky=2, crumbly=2},
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
})


minetest.register_craft({
	output = "tubelib_addons1:funnel 2",
	recipe = {
		{"group:wood", 			"", 					"group:wood"},
		{"default:steel_ingot", "default:mese_crystal",	"tubelib:tube1"},
		{"group:wood", 			"", 					"group:wood"},
	},
})


tubelib.register_node("tubelib_addons1:funnel", {}, {
	on_pull_item = function(pos, side)
		local meta = minetest.get_meta(pos)
		return tubelib.get_item(meta, "main")
	end,
	on_unpull_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		return tubelib.put_item(meta, "main", item)
	end,
	
	on_recv_message = function(pos, topic, payload)
		return "unsupported"
	end,
})	

