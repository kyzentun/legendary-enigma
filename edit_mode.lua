local save= require("save_system")
local dimensions= require("dimensions")
local images= require("images")
local key_config= require("key_config")
local campaign= require("campaign")
local menu= require("menu")
local tree= require("tree")
local sprite_oneesan= require("sprite")

local return_to_pregame

local campaign_meta_data= {}

local entry_path_color= {192, 64, 0}
local attack_path_color= {0, 64, 192}
local editing_path_color= {64, 192, 0}
local selected_path_color= {0, 192, 64}

local active_campaign_data
local drawable_paths= {}
local main_menu
local main_tree

local main_menu_x= dimensions.edit_width * .75
local main_menu_y= 0
local main_tree_x= 0
local main_tree_y= 0
local main_tree_w= dimensions.edit_width * .25

local edit_state_data= {}
-- Path group edit mode:
-- {
--   unselected_paths= {
--     {
--       name= "entry_paths.group.name",
--       source= original,
--       x= x, y= y,
--       drawable_path= drawb,
--       -- x and y are copied from the entry path entry.
--       -- Attack paths can be repositioned for editing purposes.
--     },
--   },
--   selected_paths= {}, -- Identical to unselected_paths.
-- }

local function numstr_cmp(left, right)
	local lt= type(left)
	if lt == type(right) then
		return left < right
	end
	if lt == "number" then
		return true
	end
	return false
end

local function foreach_ordered(tab, func)
	local keys= {}
	for key, value in pairs(tab) do
		keys[#keys+1]= key
	end
	table.sort(keys, numstr_cmp)
	for k= 1, #keys do
		func(keys[k], tab[keys[k]])
	end
end

local function make_drawable_path(cont_name, group_name, path_name, path)
	local new_drawb_path= {}
	local x= 0
	local y= 0
	new_drawb_path[1]= x
	new_drawb_path[2]= y
	for i= 1, #path-1 do
		local step= path[i]
		x= x + (step[1] * step[3])
		y= y + (step[2] * step[3])
		new_drawb_path[#new_drawb_path+1]= x
		new_drawb_path[#new_drawb_path+1]= y
	end
	drawable_paths[cont_name.."."..group_name.."."..path_name]= new_drawb_path
	return new_drawb_path
end

local function path_rename(name, info)
	
end

local function path_select(info)
	
end

local function path_unselect(info)
	
end

local function group_rename(name, info)
	
end

local function group_select(info)
	
end

local function group_unselect(info)
	
end

local function cont_select(info)
	
end

local function cont_unselect(info)
	
end

local function level_select(info)
	
end

local function level_unselect(info)
	
end

local function make_tree_of_paths(cont_name, paths)
	local top= {}
	foreach_ordered(
		paths, function(group_name, group)
			local group_items= {}
			foreach_ordered(
				group, function(path_name, path)
					group_items[#group_items+1]= {
						name= path_name, rename= path_rename, select= path_select,
						unselect= path_unselect,
						info= {self= path, name= path_name, group= group},
					}
			end)
			top[#top+1]= {
				name= group_name, rename= group_rename, select= group_select,
				unselect= group_unselect, sub_items= group_items,
				info= {self= group, name= group_name, cont= paths}
			}
	end)
	return {
		name= cont_name, select= cont_select, unselect= cont_unselect,
		info= {self= paths, name= cont_name}, sub_items= top,
	}
end

local function make_tree_of_levels(levels)
	local top= {}
	for l= 1, #levels do
		local level= levels[l]
		local sub_items= {}
		for s= 1, #level do
			local ship= level[s]
			sub_items[#sub_items+1]= {
				name= "Ship " .. s, select= ship_select, unselect= ship_unselect,
				info= {self= ship, name= s, level= level},
			}
		end
		top[#top+1]= {
			name= "Level " .. l, select= level_select, unselect= level_unselect,
			info= {self= level, name= l, levels= levels},
		}
	end
	return {
		name= "levels", select= levels_select, unselect= levels_unselect,
		info= {self= levels, name= "levels"}, sub_items= top,
	}
end

local function make_tree_for_campaign(camp_name, camp_data)
	return {
		name= camp_name, rename= camp_rename,
		sub_items= {
			make_tree_of_paths("attack_paths", camp_data.attack_paths),
			make_tree_of_paths("entry_paths", camp_data.entry_paths),
			make_tree_of_levels(camp_data.levels)
		},
	}
end

local function update(delta)
	local curr_time= love.timer.getTime()
	sprite_oneesan.update(curr_time)
end

local function draw()
	main_menu:draw()
	main_tree:draw()
end

local function end_edit_mode()
	love.window.setMode(dimensions.space_width, dimensions.window_height)
	main_menu:destroy()
	love.mousemoved= nil
	love.mousepressed= nil
	love.wheelmoved= nil
	return_to_pregame()
end

local function mousemoved(x, y)
	if x <= main_tree_w then
		main_tree:activate()
		main_tree:mousemoved(x, y)
	elseif x > main_menu_x then
		main_menu:activate()
		main_menu:mousemoved(x, y)
	else
		main_menu:deactivate()
		main_tree:deactivate()
		key_config.set_active_section("edit_mode")
	end
end

local function mousepressed(x, y, button)
	if x <= main_tree_w then
		main_tree:mousepressed(x, y)
	elseif x > main_menu_x then
		main_menu:mousepressed(x, y, button)
	else
		
	end
end

local function mousewheel(x, y)
	if main_tree.active then
		main_tree:mousewheel(x, y)
	elseif main_menu.active then
		main_menu:mousewheel(x, y)
	else
		
	end
end

local function pick_campaign_menu(include_all, pick_func)
	local items= {}
	local sorted_names= {}
	for name, meta in pairs(campaign_meta_data) do
		sorted_names[#sorted_names+1]= name
	end
	table.sort(sorted_names)
	for i= 1, #sorted_names do
		local name= sorted_names[i]
		local meta= campaign_meta_data[name]
		if (meta.editable or include_all) and not
		(active_campaign_data and name == active_campaign_data.meta.name) then
			items[#items+1]= {name= name, func= pick_func, arg= {name= name, meta= meta}}
		end
	end
	return items
end

local function general_after()
	key_config.set_active_section("edit_mode")
	love.update= update
	love.draw= draw
end

local function after_pick_campaign_to_edit()
	general_after()
	drawable_paths= {}
	for group_name, group in pairs(active_campaign_data.data.entry_paths) do
		for path_name, path in pairs(group) do
			make_drawable_path("entry_paths", group_name, path_name, path.path)
		end
	end
	for group_name, group in pairs(active_campaign_data.data.attack_paths) do
		for path_name, path in pairs(group) do
			make_drawable_path("attack_paths", group_name, path_name, path)
		end
	end
end

local function save()
	if active_campaign_data then
		campaign.save_campaign_data(active_campaign_data.meta, active_campaign_data.data)
	end
end

local function save_and_exit()
	save()
	end_edit_mode()
end

local function import_paths(src, dst)
	for src_group_name, src_group in pairs(src) do
		local dst_group= dst[src_group_name]
		if dst_group then
			for src_path_name, src_path in pairs(src_group) do
				if not dst_group[src_path_name] then
					dst_group[src_path_name]= src_path
				end
			end
		else
			dst[src_group_name]= src_group
		end
	end
	main_tree.top= make_tree_for_campaign(
		active_campaign_data.meta.name, active_campaign_data.data)
	main_tree:build_render_items()
end

local function import_entry_paths(info)
	local data, err= campaign.load_campaign_level_data(info.name)
	if not data then
		save.log(err)
		return "close", -1
	end
	import_paths(data.entry_paths, active_campaign_data.data.entry_paths)
	main_tree.top= make_tree_for_campaign(
		active_campaign_data.meta.name, active_campaign_data.data)
	main_tree:build_render_items()
	return "close", -1
end

local function import_attack_paths(info)
	local data, err= campaign.load_campaign_level_data(info.name)
	if not data then
		save.log(err)
		return "close", -1
	end
	import_paths(data.attack_paths, active_campaign_data.data.attack_paths)
	main_tree.top= make_tree_for_campaign(
		active_campaign_data.meta.name, active_campaign_data.data)
	main_tree:build_render_items()
	return "close", -1
end

local function copy_levels(src, dst)
	for l= 1, #src do
		dst[#dst+1]= src[l]
	end
end

local function import_levels(info)
	local data, err= campaign.load_campaign_level_data(info.name)
	if not data then
		save.log(err)
		return "close", -1
	end
	import_paths(data.entry_paths, active_campaign_data.data.entry_paths)
	copy_levels(data.levels, active_campaign_data.data.levels)
	main_tree.top= make_tree_for_campaign(
		active_campaign_data.meta.name, active_campaign_data.data)
	main_tree:build_render_items()
	return "close", -1
end

local function import_all(info)
	local data, err= campaign.load_campaign_level_data(info.name)
	if not data then
		save.log(err)
		return "close", -1
	end
	import_paths(data.entry_paths, active_campaign_data.data.entry_paths)
	import_paths(data.attack_paths, active_campaign_data.data.attack_paths)
	copy_levels(data.levels, active_campaign_data.data.levels)
	main_tree.top= make_tree_for_campaign(
		active_campaign_data.meta.name, active_campaign_data.data)
	main_tree:build_render_items()
	return "close", -1
end

local function import_from_menu(import_func)
	return "submenu", pick_campaign_menu(true, import_func)
end

local manage_campaign_menu

local function make_new_campaign()
	active_campaign_data= {
		meta= campaign.unique_untitled_meta(),
		data= campaign.blank_campaign_data(),
	}
	return manage_campaign_menu()
end

local function copy_campaign(info)
	local data, err= campaign.load_campaign_level_data(info.name)
	if not data then
		save.log(err)
		return "close", -1
	end
	active_campaign_data= {
		meta= campaign.unique_untitled_meta(),
		data= campaign.blank_campaign_data(),
	}
	import_paths(data.entry_paths, active_campaign_data.data.entry_paths)
	import_paths(data.attack_paths, active_campaign_data.data.attack_paths)
	copy_levels(data.levels, active_campaign_data.data.levels)
	main_tree.top= make_tree_for_campaign(
		active_campaign_data.meta.name, active_campaign_data.data)
	main_tree:build_render_items()
	local ref, items= manage_campaign_menu()
	return "close", -1, items
end

local function set_campaign_to_edit(info)
	local meta= campaign_meta_data[info.meta]
	local data, err= campaign.load_campaign_level_data(info.name)
	if not data then
		save.log(err)
		return
	end
	active_campaign_data= {meta= meta, data= data}
	main_tree.top= make_tree_for_campaign(info.name, data)
	main_tree:build_render_items()
	return manage_campaign_menu()
end

local function load_campaign_menu()
	local items= pick_campaign_menu(false, set_campaign_to_edit)
	table.insert(items, 1, {name= "New campaign", func= make_new_campaign})
	table.insert(items, 2, {name= "Copy campaign", func= import_from_menu, arg= copy_campaign})
	return items
end

local function open_different_campaign()
	return "submenu", load_campaign_menu()
end

manage_campaign_menu= function()
	local items= {
		{name= "Save and exit", func= save_and_exit},
		{name= "Save", func= save},
		{name= "Exit", func= end_edit_mode},
		{name= "Open different campaign", func= open_different_campaign},
		{name= "Import entry paths", func= import_from_menu, arg= import_entry_paths},
		{name= "Import attack paths", func= import_from_menu, arg= import_attack_paths},
		{name= "Import levels", func= import_from_menu, arg= import_levels},
		{name= "Import all data", func= import_from_menu, arg= import_all},
	}
	return "refresh", items
end

local function begin(modore)
	love.window.setMode(dimensions.edit_width, dimensions.edit_height)
	campaign_meta_data= campaign.load_all_campaign_meta()
	return_to_pregame= modore
	main_menu= menu.create(load_campaign_menu(), nil, main_menu_x, main_menu_y)
	main_tree= tree.create(main_tree_x, main_tree_y, main_tree_w, dimensions.edit_height, nil)
	love.mousemoved= mousemoved
	love.mousepressed= mousepressed
	love.wheelmoved= mousewheel
	general_after()
end

key_config.register_section(
	"edit_mode", {
		{name= "exit", keys= {"escape"}, release= function() end_edit_mode() end},
})

return {
	begin= begin,
}
