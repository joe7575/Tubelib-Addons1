--[[

	Tubelib Addons 1
	================

	Copyright (C) 2017 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information

	grinder.lua
	
	Grinding Cobble to Gravel
	
]]--

local TICKS_TO_SLEEP = 10
local CYCLE_TIME = 2
local STOP_STATE = 0
local STANDBY_STATE = -1
local FAULT_STATE = -2


local function formspec(state)
	return "size[8,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"list[context;src;0,0;3,3;]"..
	"item_image[0,0;1,1;default:cobble]"..
	"image[3.5,1;1,1;tubelib_gui_arrow.png]"..
	"image_button[3.5,2;1,1;".. tubelib.state_button(state) ..";button;]"..
	"list[context;dst;5,0;3,3;]"..
	"item_image[5,0;1,1;default:gravel]"..
	"list[current_player;main;0,4;8,4;]"..
	"listring[context;dst]"..
	"listring[current_player;main]"..
	"listring[context;src]"..
	"listring[current_player;main]"
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if listname == "src" then
		return stack:get_count()
	elseif listname == "dst" then
		return 0
	end
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack(from_list, from_index)
	return allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end


local function convert_stone_to_gravel(inv)
	local cobble = ItemStack("default:cobble")
	local gravel = ItemStack("default:gravel")
	if inv:room_for_item("dst", gravel) and inv:contains_item("src", cobble) then
		inv:add_item("dst", gravel)
		inv:remove_item("src", cobble)
		return true
	end
	return false
end


local function start_the_machine(pos)
	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local number = meta:get_string("number")
	meta:set_int("running", TICKS_TO_SLEEP)
	meta:set_string("infotext", "Tubelib Grinder "..number..": running")
	meta:set_string("formspec", formspec(tubelib.RUNNING))
	node.name = "tubelib_addons1:grinder_active"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):start(CYCLE_TIME)
	return false
end

local function stop_the_machine(pos)
	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local number = meta:get_string("number")
	meta:set_int("running", STOP_STATE)
	meta:set_string("infotext", "Tubelib Grinder "..number..": stopped")
	meta:set_string("formspec", formspec(tubelib.STOPPED))
	node.name = "tubelib_addons1:grinder"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):stop()
	return false
end

local function goto_sleep(pos)
	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local number = meta:get_string("number")
	meta:set_int("running", STANDBY_STATE)
	meta:set_string("infotext", "Tubelib Grinder "..number..": standby")
	meta:set_string("formspec", formspec(tubelib.STANDBY))
	node.name = "tubelib_addons1:grinder"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):start(CYCLE_TIME * TICKS_TO_SLEEP)
	return false
end

local function goto_fault(pos)
	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local number = meta:get_string("number")
	meta:set_int("running", FAULT_STATE)
	meta:set_string("infotext", "Tubelib Grinder "..number..": fault")
	meta:set_string("formspec", formspec(tubelib.FAULT))
	node.name = "tubelib_addons1:grinder"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):stop()
	return false
end

local function keep_running(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local running = meta:get_int("running") - 1
	--print("running", running)
	local inv = meta:get_inventory()
	local busy = convert_stone_to_gravel(inv)
	
	if busy == true then 
		if running <= STOP_STATE then
			return start_the_machine(pos)
		else
			running = TICKS_TO_SLEEP
		end
	elseif not inv:is_empty("src") then
		return goto_fault(pos)
	else
		if running <= STOP_STATE then
			return goto_sleep(pos)
		end
	end
	meta:set_int("running", running)
	return true
end

local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local meta = minetest.get_meta(pos)
	local running = meta:get_int("running") or 1
	if fields.button ~= nil then
		if running > STOP_STATE or running == FAULT_STATE then
			stop_the_machine(pos)
		else
			start_the_machine(pos)
		end
	end
end

minetest.register_node("tubelib_addons1:grinder", {
	description = "Tubelib Grinder",
	tiles = {
		-- up, down, right, left, back, front
		'tubelib_addons1_grinder.png',
		'tubelib_front.png',
		'tubelib_front.png',
		'tubelib_front.png',
		"tubelib_front.png",
		"tubelib_front.png",
	},

	after_place_node = function(pos, placer)
		local number = tubelib.add_node(pos, "tubelib_addons1:grinder")
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size('src', 9)
		inv:set_size('dst', 9)
		meta:set_string("number", number)
		meta:set_string("infotext", "Tubelib Grinder "..number..": stopped")
		meta:set_string("formspec", formspec(tubelib.STOPPED))
	end,

	on_dig = function(pos, node, puncher, pointed_thing)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		if inv:is_empty("dst") and inv:is_empty("src") then
			minetest.node_dig(pos, node, puncher, pointed_thing)
			tubelib.remove_node(pos)
		end
	end,

	on_timer = keep_running,
	on_receive_fields = on_receive_fields,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	paramtype2 = "facedir",
	groups = {cracky=1},
	is_ground_content = false,
})


minetest.register_node("tubelib_addons1:grinder_active", {
	description = "Tubelib Grinder",
	tiles = {
		-- up, down, right, left, back, front
		{
			image = 'tubelib_addons1_grinder_active.png',
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 32,
				aspect_h = 32,
				length = 1.0,
			},
		},
		
		'tubelib_front.png',
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
	},

	on_timer = keep_running,
	on_receive_fields = on_receive_fields,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	paramtype2 = "facedir",
	groups = {crumbly=0, not_in_creative_inventory=1},
	is_ground_content = false,
})

minetest.register_craft({
	output = "tubelib_addons1:grinder",
	recipe = {
		{"group:wood", 		"default:tin_ingot",  	"group:wood"},
		{"tubelib:tube1", 	"default:mese_crystal",	"tubelib:tube1"},
		{"group:wood", 		"default:tin_ingot",  	"group:wood"},
	},
})


tubelib.register_node("tubelib_addons1:grinder", {"tubelib_addons1:grinder_active"}, {
	on_pull_item = function(pos, side)
		local meta = minetest.get_meta(pos)
		return tubelib.get_item(meta, "dst")
	end,
	on_push_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		return tubelib.put_item(meta, "src", item)
	end,
	on_unpull_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		return tubelib.put_item(meta, "dst", item)
	end,
	on_recv_message = function(pos, topic, payload)
		if topic == "start" then
			start_the_machine(pos)
		elseif topic == "stop" then
			stop_the_machine(pos)
		elseif topic == "state" then
			local meta = minetest.get_meta(pos)
			local running = meta:get_int("running")
			return tubelib.statestring(runnnig)
		else
			return "unsupported"
		end
	end,
})	
