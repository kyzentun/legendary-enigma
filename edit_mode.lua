local save= require("save_system")
local dimensions= require("dimensions")
local images= require("images")
local key_config= require("key_config")
local campaign= require("campaign")
local menu= require("menu")

local return_to_pregame

local campaign_meta_data= {}

local entry_path_color= {192, 64, 0}
local attack_path_color= {0, 64, 192}
local editing_path_color= {64, 192, 0}
local selected_path_color= {0, 192, 64}

local active_campaign_data
local drawable_paths= {}

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

local function update(delta)
	
end

local function draw()
	
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
		if meta.editable or include_all then
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
	for group_name, group in pairs(active_campaign_data.entry_paths) do
		for path_name, path in pairs(group) do
			make_drawable_path("entry_paths", group_name, path_name, path.path)
		end
	end
	for group_name, group in pairs(active_campaign_data.attack_paths) do
		for path_name, path in pairs(group) do
			make_drawable_path("attack_paths", group_name, path_name, path)
		end
	end
end

local function make_new_campaign()
	active_campaign_data= {
		meta= campaign.unique_untitled_meta(),
		data= campaign.blank_campaign_data(),
	}
end

local function set_campaign_to_edit(info)
	local meta= campaign_meta_data[info.meta]
	local data, err= campaign.load_campaign_level_data(info.name)
	if not data then
		save.log(err)
		return
	end
	active_campaign_data= {meta= meta, data= data}
end

local function pick_campaign_to_edit()
	local menu_info= pick_campaign_menu(false, set_campaign_to_edit)
	table.insert(menu_info, 1, {name= "New campaign", func= make_new_campaign})
	menu.begin(after_pick_campaign_to_edit, draw, menu_info)
end

local function begin(modore)
	campaign_meta_data= campaign.load_all_campaign_meta()
	return_to_pregame= modore
	general_after()
end

local function end_edit_mode()
	return_to_pregame()
end

key_config.register_section(
	"edit_mode", {
		{name= "exit", keys= {"escape"}, release= function() end_edit_mode() end},
})

return {
	begin= begin,
}
