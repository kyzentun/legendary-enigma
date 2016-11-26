local dimensions= require("dimensions")
local images= require("images")
local save= require("save_system")
local sprite_oneesan= require("sprite")

local key_config_path= "key_config"

local sorted_section_names= {}
local default_sections= {}
local sections= {}
local active_press= {}
local active_release= {}
local need_reconfig_list= {}

local function make_name_lookup(tab)
	local lookup= {}
	for i= 1, #tab do
		lookup[tab[i].name]= tab[i]
	end
	return lookup
end

local function register_section(name, defaults)
	if default_sections[name] then
		local section= default_sections[name]
		for d= 1, #defaults do
			section[#section+1]= defaults[d]
		end
	else
		sorted_section_names[#sorted_section_names+1]= name
		default_sections[name]= defaults
	end
end

local function set_active_section(name)
	local entry= sections[name]
	if entry then
		active_press= {}
		active_release= {}
		for i= 1, #entry do
			local fun_info= entry[i]
			if fun_info.press then
				for k= 1, #fun_info.keys do
					active_press[fun_info.keys[k]]= fun_info.press
				end
			end
			if fun_info.release then
				for k= 1, #fun_info.keys do
					active_release[fun_info.keys[k]]= fun_info.release
				end
			end
		end
	end
end

local function get_section_info(name)
	return sections[name]
end

local function sanity_check_config(config)
	for section_name, section_data in pairs(default_sections) do
		local config_section= config[section_name]
		if not config_section then
			config[section_name]= table.copy(section_data)
		else
			local mapped_keys= {}
			local reordered_section= {}
			local config_section_by_name= make_name_lookup(config_section)
			for d= 1, #section_data do
				local default_entry= section_data[d]
				local config_entry= config_section_by_name[default_entry.name]
				local new_entry= table.copy(default_entry)
				if config_entry then
					new_entry.keys= config_entry.keys
				end
				for k= #new_entry.keys, 1, -1 do
					local key= new_entry.keys[k]
					if mapped_keys[key] then
						table.remove(new_entry.keys, k)
						need_reconfig_list[#need_reconfig_list+1]= {
							section= section_name, name= default_entry.name}
					else
						mapped_keys[key]= true
					end
				end
				reordered_section[#reordered_section+1]= new_entry
			end
			config[section_name]= reordered_section
		end
	end
	return true
end

local function get_blank_config()
	return table.copy(default_sections)
end

local function apply_config(config_data)
	sections= {}
	for section_name, config_section in pairs(config_data) do
		local default_section= default_sections[section_name]
		local new_section= {}
		local def_by_name= make_name_lookup(default_section)
		for i= 1, #config_section do
			local config_entry= config_section[i]
			local default_entry= def_by_name[config_entry.name]
			if not default_entry then
				save.log("bad section: " .. config_entry.name)
				save.log_table(config_entry)
			end
			new_section[#new_section+1]= {
				name= config_entry.name, keys= config_entry.keys,
				press= default_entry.press, release= default_entry.release,
			}
		end
		sections[section_name]= new_section
	end
end

local function load_keys()
	apply_config(save.load_save_file(
		key_config_path, get_blank_config, sanity_check_config))
end

local function save_keys()
	save.write_save_file(key_config_path, sections)
end

local function main_keypressed(key)
	local func= active_press[key]
	if func then func() end
end

local function main_keyreleased(key)
	local func= active_release[key]
	if func then func() end
end

love.keypressed= main_keypressed
love.keyreleased= main_keyreleased


local key_entry_being_set= 0
local keys_list_being_set= {}
local temp_config= {}

local cursor_sprite= {}

local config_menu= {}
local cursor_row= 1
local cursor_item= 1
local first_item_x= 150
local item_spacing= 75
local first_row_y= 30
local row_spacing= 20
local row_id_offset= 1
local min_ridoff= 1
local max_ridoff= 1
local wheel_move_x= 0
local wheel_move_y= 0

local type_x= {
	global= 20,
	section= 20,
	command= 30,
}

local type_colors= {
	global= {32, 128, 192},
	section= {128, 192, 32},
	command= {192, 128, 32},
}

local return_to_prev_game_mode
local build_menu_from_config
local build_command_menu_row

local function cursor_pos_from_mouse_pos(x, y)
	local row_id= math.ceil((y - first_row_y) / row_spacing) +
		math.floor(row_id_offset - 1)
	if row_id < 1 or row_id > #config_menu then return nil end
	if x < first_item_x then
		return row_id, 1
	end
	local item_id= math.ceil((x - first_item_x) / item_spacing)
	if item_id > #config_menu[row_id].items then return nil end
	return row_id, item_id + 1
end

local function mousemoved(x, y)
	local row_id, item_id= cursor_pos_from_mouse_pos(x, y)
	if row_id then
		cursor_row= row_id
		cursor_item= item_id
	end
end

local function mousepressed(x, y, button)
	if button ~= 1 then return end
	local row_id, item_id= cursor_pos_from_mouse_pos(x, y)
	if row_id then
		cursor_row= row_id
		cursor_item= item_id
		if item_id == 1 then return end
		local row= config_menu[row_id]
		local item= row.items[item_id-1]
		item.func(item.info)
	end
end

local function mousewheel(x, y)
	wheel_move_x= x
	wheel_move_y= y
	if y >= 1 then
		row_id_offset= math.max(row_id_offset - 1, min_ridoff)
	elseif y <= 1 then
		row_id_offset= math.min(row_id_offset + 1, max_ridoff)
	end
end

local function set_key_keypressed(key)
	keys_list_being_set[key_entry_being_set]= key
	build_menu_from_config()
end

local function set_key_keyreleased(key)
	love.keypressed= main_keypressed
	love.keyreleased= main_keyreleased
	love.mousemoved= mousemoved
	love.mousepressed= mousepressed
end

local function update(delta)
	local curr_time= love.timer.getTime()
	sprite_oneesan.update(curr_time)
end

local function draw_cursor(x, y)
	love.graphics.push()
	local center_data= cursor_sprite.image.center
	love.graphics.translate(x - center_data.x - 4, y + 6)
	love.graphics.rotate(math.pi/2)
	love.graphics.draw(cursor_sprite.image.image, cursor_sprite.image.frames[cursor_sprite.sprite.curr_frame], -center_data.x, -center_data.y)
	love.graphics.pop()
end

local function draw()
	love.graphics.setColor(255, 255, 255)
	love.graphics.print("key_config", 0, 0)
	for row_id= math.floor(row_id_offset), #config_menu do
		local row= config_menu[row_id]
		local row_y= math.floor(first_row_y + ((row_id-row_id_offset) * row_spacing))
		local color= type_colors[row.type]
		love.graphics.setColor(color[1], color[2], color[3])
		love.graphics.print(row.name, type_x[row.type], row_y)
		love.graphics.setColor(255, 255, 255)
		if cursor_row == row_id and cursor_item == 1 then
			draw_cursor(type_x[row.type], row_y)
		end
		for item_id= 1, #row.items do
			local item= row.items[item_id]
			local item_x= first_item_x + ((item_id-1) * item_spacing)
			love.graphics.print(item.name, item_x, row_y)
			if cursor_row == row_id and cursor_item-1 == item_id then
				draw_cursor(item_x, row_y)
			end
		end
	end
end

local function apply_and_exit()
	cursor_sprite.sprite:destroy()
	cursor_sprite= nil
	sections= temp_config
	love.mousemoved= nil
	love.mousepressed= nil
	love.wheelmoved= nil
	save_keys()
	return_to_prev_game_mode()
end

local function reset_all()
	temp_config= table.copy(sections)
	build_menu_from_config()
end

local function default_all()
	temp_config= get_blank_config()
	build_menu_from_config()
end

local function reset_section(name)
	temp_config[name]= table.copy(sections[name])
	build_menu_from_config()
end

local function default_section(name)
	temp_config[name]= table.copy(default_section[name])
	build_menu_from_config()
end

local function set_key(info)
	keys_list_being_set= info[2].keys
	key_entry_being_set= info[1]
	love.keypressed= set_key_keypressed
	love.keyreleased= set_key_keyreleased
	love.mousemoved= nil
	love.mousepressed= nil
end

local function clamp_cursor_on_row()
	local row= config_menu[cursor_row]
	if cursor_item < 1 then
		cursor_item= #row.items
	elseif cursor_item > #row.items + 1 then
		cursor_item= 1
	end
end

local function action()
	if cursor_item == 1 then return end
	local row= config_menu[cursor_row]
	local item= row.items[cursor_item-1]
	item.func(item.info)
end

local function clear()
	if cursor_item == 1 then return end
	local row= config_menu[cursor_row]
	if row.type ~= "command" then return end
	local item_id= cursor_item-1
	local item= row.items[item_id]
	local command= item.info[2]
	if item_id > #command.keys then return end
	table.remove(command.keys, item.info[1])
	local new_row= build_command_menu_row(command)
	config_menu[cursor_row]= new_row
end

local function next_section()
	for r= cursor_row + 1, #config_menu do
		if config_menu[r].type == "section" then
			cursor_row= r
			return
		end
	end
	cursor_row= 1
end

local function prev_section()
	for r= cursor_row - 1, 1, -1 do
		if config_menu[r].type == "section" then
			cursor_row= r
			return
		end
	end
	cursor_row= 1
end

local function lerp_ridoff()
	local ridoff_len= max_ridoff - min_ridoff
	if ridoff_len <= 1 then
		row_id_offset= 1
		return
	end
	local percent_through= (cursor_row - 1) / (#config_menu - 1)
	row_id_offset= (ridoff_len * percent_through) + min_ridoff
end

local function next_command()
	cursor_row= cursor_row + 1
	if cursor_row > #config_menu then
		cursor_row= 1
	end
	lerp_ridoff()
	clamp_cursor_on_row()
end

local function prev_command()
	cursor_row= cursor_row - 1
	if cursor_row < 1 then
		cursor_row= #config_menu
	end
	lerp_ridoff()
	clamp_cursor_on_row()
end

local function next_key()
	cursor_item= cursor_item + 1
	clamp_cursor_on_row()
end

local function prev_key()
	cursor_item= cursor_item - 1
	clamp_cursor_on_row()
end

local function build_items_from_keys(command)
	local ret= {}
	for k= 1, #command.keys do
		ret[#ret+1]= {name= command.keys[k], info= {k, command}, func= set_key}
	end
	ret[#ret+1]= {name= "add", info= {#command.keys+1, command}, func= set_key}
	return ret
end

build_command_menu_row= function(command)
	return {
		type= "command", name= command.name,
		items= build_items_from_keys(command)}
end

build_menu_from_config= function()
	config_menu= {}
	config_menu[1]= {
		type= "global", name= "Global", items= {
			{name= "apply", func= apply_and_exit},
			{name= "undo", func= reset_all},
			{name= "default", func= default_all},
	}}
	for n= 1, #sorted_section_names do
		local section_name= sorted_section_names[n]
		local section_data= temp_config[section_name]
		config_menu[#config_menu+1]= {
			type= "section", name= section_name, items= {
				{name= "undo", info= section_name, func= reset_section},
				{name= "default", info= section_name, func= default_section},
		}}
		for i= 1, #section_data do
			local command= section_data[i]
			local new_row= build_command_menu_row(command)
			config_menu[#config_menu+1]= new_row
			if cursor_row == #config_menu and cursor_item > #new_row.items+1 then
				cursor_item= #new_row.items+1
			end
		end
	end
	local possible_rows= (dimensions.window_height - first_row_y) / row_spacing
	max_ridoff= math.max(1, math.ceil(#config_menu - possible_rows) + 1)
end

local function begin(modore)
	return_to_prev_game_mode= modore
	set_active_section("key_config")
	temp_config= table.copy(sections)
	build_menu_from_config()
	cursor_sprite= {
		image= images.player,
		sprite= sprite_oneesan.create_sprite(#images.player.frames, 1, .25),
	}
	cursor_pos= 1
	cursor_section_name= sorted_section_names[1]
	love.update= update
	love.draw= draw
	love.mousemoved= mousemoved
	love.mousepressed= mousepressed
	love.wheelmoved= mousewheel
end

register_section(
	"key_config", {
		{name= "apply_and_exit", keys= {"escape"}, release= apply_and_exit},
		{name= "action", keys= {"return"}, release= action},
		{name= "clear", keys= {"backspace"}, press= clear},
		{name= "next_section", keys= {"pagedown"}, press= next_section},
		{name= "prev_section", keys= {"pageup"}, press= prev_section},
		{name= "next_command", keys= {"down"}, press= next_command},
		{name= "prev_command", keys= {"up"}, press= prev_command},
		{name= "next_key", keys= {"right"}, press= next_key},
		{name= "prev_key", keys= {"left"}, press= prev_key},
})

return {
	register_section= register_section,
	set_active_section= set_active_section,
	get_section_info= get_section_info,
	load_keys= load_keys,
	save_keys= save_keys,
	begin= begin,
}
