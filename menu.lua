local dimensions= require("dimensions")
local key_config= require("key_config")
local images= require("images")
local sprite_oneesan= require("sprite")

local return_to_thing
local bg_draw
local menu_offset= 1
local cursor_offset= 0
local items_per_page= 20
local option_key_info_offset= 8 -- ish, probably
local cursor_x= 30
local menu_start_y= 40
local menu_row_spacing= 20
local menu_item_key_x= 5
local menu_item_name_x= 35
local menu_item_value_x= 160
local menu_adjust_up_x= 210
local menu_adjust_down_x= 140
local close_menu_key_x= 20
local close_menu_name_x= 90
local close_menu_y= menu_start_y - menu_row_spacing
-- info example:
-- {
--   {name= "foo", arg= {}, func= function(arg) end},
--   -- arg is for any information that func needs.  The menu system will not
--   --   touch arg in any way except to pass it to func.
--   -- func must return the action to perform when the item is chosen.
--   -- If func returns nil, the menu stays as-is.
--   -- If func returns "'refresh', {}", the table replaces the current menu.
--   -- If func returns "'submenu', {}", the table is another menu to open.
--   -- If func returns "'close', 1", the current submenu is closed.
--   --   The number returned with "close" is the number of submenu layers to
--   --   close.  -1 will close the entire menu.
--   {name= "foo", value= "bar", arg= {}, func= function(arg) end,
--     adjust_up= function(arg) end, adjust_down= function(arg) end},
--   -- func has the same behavior as the first example.
--   -- The player has two buttons for adjusting the value of a menu item.
--   -- adjust_up and adjust_down are used for these buttons.
--   -- adjust_* must return the new value to display.
--   ...
-- }

local menu_info_stack= {}
local top_menu
local cursor_sprite

local function min_clamp_menu_offset(off)
	return math.max(1, off)
end

local function max_clamp_menu_offset(off)
	return math.min(math.max(1, #top_menu - items_per_page + 1), off)
end

local function exit_menu()
	menu_info_stack= {}
	top_menu= nil
	cursor_sprite.sprite:destroy()
	cursor_sprite= nil
	love.mousepressed= nil
	love.mousemoved= nil
	love.wheelmoved= nil
	bg_draw= nil
	return_to_thing()
end

local function draw()
	if bg_draw then
		bg_draw()
	end
	love.graphics.setColor(255, 255, 255)
	local key_info= key_config.get_section_info("menu")
	love.graphics.print(key_info[1].keys[1], close_menu_key_x, close_menu_y)
	love.graphics.print(key_info[1].name, close_menu_name_x, close_menu_y)
	local first_item= menu_offset
	local after_last_item= math.min(#top_menu+1, first_item + items_per_page)
	local num_items= after_last_item - first_item
	for i= 0, num_items-1 do
		local item= top_menu[i + first_item]
		local row_y= menu_start_y + (i * menu_row_spacing)
		local key= key_info[i + option_key_info_offset].keys[1]
		love.graphics.print(key, menu_item_key_x, row_y)
		love.graphics.print(item.name, menu_item_name_x, row_y)
		if item.value ~= nil then
			love.graphics.print("<", menu_adjust_down_x, row_y)
			love.graphics.print(">", menu_adjust_up_x, row_y)
			love.graphics.print(item.value, menu_item_value_x, row_y)
		end
	end
	local cursor_y= menu_start_y + ((cursor_offset+1) * menu_row_spacing) - 3
	love.graphics.push()
	local center_data= cursor_sprite.image.center
	love.graphics.translate(cursor_x - center_data.x, cursor_y - center_data.y)
	love.graphics.rotate(math.pi/2)
	love.graphics.draw(cursor_sprite.image.image, cursor_sprite.image.frames[cursor_sprite.sprite.curr_frame], -center_data.x, -center_data.y)
	love.graphics.pop()
end

local function update()
	local curr_time= love.timer.getTime()
	sprite_oneesan.update(curr_time)
end

local function close_level(num)
	num= num or 1
	if num < 0 then
		exit_menu()
	else
		local new_top_index= #menu_info_stack - num + 1
		if new_top_index < 1 then
			exit_menu()
		else
			local info= menu_info_stack[new_top_index]
			top_menu= info.menu
			menu_offset= info.moff
			cursor_offset= info.coff
			for i= #menu_info_stack, new_top_index, -1 do
				table.remove(menu_info_stack, i)
			end
		end
	end
end

local function handle_func_call(row_info)
	if not row_info.func then return end
	local action, info= row_info.func(row_info.arg)
	if action == "close" then
		if type(info) ~= "number" then
			info= 1
		end
		close_level(info)
	elseif action == "refresh" then
		top_menu= info
		menu_offset= max_clamp_menu_offset(menu_offset)
		cursor_offset= math.min(cursor_offset, #top_menu - menu_offset)
	elseif action == "submenu" then
		menu_info_stack[#menu_info_stack+1]= {
			moff= menu_offset, coff= cursor_offset, menu= top_menu}
		top_menu= info
		menu_offset= 1
		cursor_offset= 0
	else
		-- do nothing
	end
end

local function handle_adjust_down(row_info)
	if not row_info.adjust_down then return end
	row_info.value= row_info.adjust_down(row_info.arg)
end

local function handle_adjust_up(row_info)
	if not row_info.adjust_up then return end
	row_info.value= row_info.adjust_up(row_info.arg)
end

local function page_up()
	menu_offset= min_clamp_menu_offset(menu_offset - items_per_page)
end

local function page_down()
	menu_offset= max_clamp_menu_offset(menu_offset + items_per_page)
end

local function choose_option(id)
	local row_info= top_menu[id + menu_offset - 1]
	if not row_info then return end
	handle_func_call(row_info)
end

local function cursor_up()
	local cursor_abs_pos= menu_offset + cursor_offset
	if cursor_abs_pos <= 1 then
		menu_offset= max_clamp_menu_offset(#top_menu)
		cursor_offset= #top_menu - menu_offset
	else
		if cursor_offset <= 0 then
			page_up()
			cursor_offset= (cursor_abs_pos - 1) - menu_offset
		else
			cursor_offset= cursor_offset - 1
		end
	end
end

local function cursor_down()
	local cursor_abs_pos= menu_offset + cursor_offset
	if cursor_abs_pos >= #top_menu then
		menu_offset= 1
		cursor_offset= 0
	else
		if cursor_offset >= items_per_page-1 then
			page_down()
			cursor_offset= (cursor_abs_pos + 1) - menu_offset
		else
			cursor_offset= cursor_offset + 1
		end
	end
end

local function adjust_up()
	local row_info= top_menu[cursor_offset + menu_offset]
	if not row_info then return end
	handle_adjust_up(row_info)
end

local function adjust_down()
	local row_info= top_menu[cursor_offset + menu_offset]
	if not row_info then return end
	handle_adjust_down(row_info)
end

local function action()
	local row_info= top_menu[cursor_offset + menu_offset]
	if not row_info then return end
	handle_func_call(row_info)
end

local function mouse_y_to_row_id(y, min_row)
	return math.floor((y - menu_start_y) / menu_row_spacing)
end

local function mousepressed(x, y, button)
	if button ~= 1 then return end
	local row_id= mouse_y_to_row_id(y)
	if row_id < -1 or row_id > items_per_page then return end
	if row_id == -1 then
		close_level(1)
	else
		local row_info= top_menu[row_id+menu_offset]
		if not row_info then return end
		if row_info.value == nil then
			handle_func_call(row_info)
		else
			if x < menu_adjust_down_x then
				handle_func_call(row_info)
			elseif x < menu_item_value_x then
				handle_adjust_down(row_info)
			elseif x >= menu_adjust_up_x and x < menu_adjust_up_x + 30 then
				handle_adjust_up(row_info)
			end
		end
	end
end

local function mousemoved(x, y)
	local row_id= mouse_y_to_row_id(y)
	if row_id < 0 or row_id >= items_per_page then return end
	cursor_offset= math.min(row_id, #top_menu - menu_offset)
end

local function mousewheel(x, y)
	if y >= 1 then
		menu_offset= min_clamp_menu_offset(menu_offset - 1)
	elseif y <= 1 then
		menu_offset= max_clamp_menu_offset(menu_offset + 1)
	end
end

local function begin(modore, bgd, info)
	return_to_thing= modore
	bg_draw= bgd
	top_menu= info
	menu_offset= 1
	cursor_offset= 0
	local key_info= key_config.get_section_info("menu")
	for i= 1, #key_info do
		if key_info[i].name == "option_1" then
			option_key_info_offset= i
			break
		end
	end
	cursor_sprite= {
		image= images.player,
		sprite= sprite_oneesan.create_sprite(#images.player.frames, 1, .25),
	}
	key_config.set_active_section("menu")
	love.update= update
	love.draw= draw
	love.mousepressed= mousepressed
	love.mousemoved= mousemoved
	love.wheelmoved= mousewheel
end

key_config.register_section(
	"menu", {
		-- close must be the first entry because I don't feel like writing extra
		-- code to find it.
		{name= "close", keys= {"escape"}, release= close_level},
		{name= "page_up", keys= {"`"}, press= page_up},
		{name= "page_down", keys= {"tab"}, press= page_down},
		{name= "cursor_up", keys= {"up"}, press= cursor_up},
		{name= "cursor_down", keys= {"down"}, press= cursor_down},
		{name= "adjust_up", keys= {"right"}, press= adjust_up},
		{name= "adjust_down", keys= {"left"}, press= adjust_down},
		{name= "action", keys= {"return"}, press= action},
		-- option keys must be in order for prompts to be correct.
		{name= "option_1", keys= {"1"}, press= function() choose_option(1) end},
		{name= "option_2", keys= {"2"}, press= function() choose_option(2) end},
		{name= "option_3", keys= {"3"}, press= function() choose_option(3) end},
		{name= "option_4", keys= {"4"}, press= function() choose_option(4) end},
		{name= "option_5", keys= {"5"}, press= function() choose_option(5) end},
		{name= "option_6", keys= {"q"}, press= function() choose_option(6) end},
		{name= "option_7", keys= {"w"}, press= function() choose_option(7) end},
		{name= "option_8", keys= {"e"}, press= function() choose_option(8) end},
		{name= "option_9", keys= {"r"}, press= function() choose_option(9) end},
		{name= "option_10", keys= {"t"}, press= function() choose_option(10) end},
		{name= "option_11", keys= {"a"}, press= function() choose_option(11) end},
		{name= "option_12", keys= {"s"}, press= function() choose_option(12) end},
		{name= "option_13", keys= {"d"}, press= function() choose_option(12) end},
		{name= "option_14", keys= {"f"}, press= function() choose_option(12) end},
		{name= "option_15", keys= {"g"}, press= function() choose_option(12) end},
		{name= "option_16", keys= {"z"}, press= function() choose_option(12) end},
		{name= "option_17", keys= {"x"}, press= function() choose_option(12) end},
		{name= "option_18", keys= {"c"}, press= function() choose_option(12) end},
		{name= "option_19", keys= {"v"}, press= function() choose_option(12) end},
		{name= "option_20", keys= {"b"}, press= function() choose_option(12) end},
})

return {
	begin= begin,
}
