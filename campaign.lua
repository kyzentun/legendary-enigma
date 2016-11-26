local dimensions= require("dimensions")
local save= require("save_system")

-- Campaign data plan:
-- Campaign data consists of two parts, stored in separate files.
-- Part 1: Metadata
--   Filename: name_meta.lua
--   Contents:
--     Name
--     Author credit
--     Description or notes
--     Campaign version
--     Format version
-- Part 2: Level data
--   Filename: name_data.lua
--   Contents:
--     Entry path list
--     Attack path list
--     Level list
--
-- With lots of campaigns, level data can be large and take time to sanity
--   check.  Separating the parts avoids loading data that won't be used.
--
-- If the meta data file for a campaign does not exist, the data in it can be
-- generated.
--
-- Metadata details:
--   The name field in the meta data can be different from the one in the
--   filename.  It is what the player sees in a menu.
--
--   Campaign version is for tagging scores if a campaign author makes a new
--   version.
--
--   Format version is for if the campaign file format ever changes.
--
-- Level data details:
--   Entry path parts:
--     Group name
--       Group names allows organizing similar paths.
--     Name
--     Start position
--     Step list
--       Each step in a path is a speed vector and a duration.
--   Attack path parts:
--     Group name
--     Name
--     Step list
--   Level details:
--     A level is a list of ships that enter to form the convoy.
--     Ship entry parts:
--       convoy_id sets the ship's place in the convoy.
--       ship sets the type of ship to use, which affects image and behavior.
--       delay is how long the ship waits before entering.
--       enter gives the group name and name of the entry path to use.

-- Extra aliens added when levels repeat can reuse ship entries with an
-- unused convoy_id.

local campaign_path= "campaigns/"
local meta_end= "meta.lua"
local data_end= "data.lua"

local sturm= {string= true, number= true}

local function blank_campaign_meta()
	return {}
end

local function blank_campaign_data()
	return {
		entry_paths= {},
		attack_paths= {},
		levels= {},
	}
end

local function end_match(str, pat)
	return #str > #pat + 2 and str:sub(-#pat, -1) == pat
end

local function end_clip(str, pat)
	return str:sub(1, -#pat - 2)
end

local campaign_meta_data= {}

local function sanity_check_version(vertab)
	if type(vertab) ~= "table" then
		return {1, 0, 0}
	end
	for i= 1, 3 do
		if type(vertab[i]) ~= "number" then
			vertab[i]= 1
		end
	end
	return vertab
end

local function campaign_meta_sanity(data)
	if type(data.author) ~= "string" then
		data.author= "Unknown"
	end
	if type(data.description) ~= "string" then
		data.description= ""
	end
	data.campaign_version= sanity_check_version(data.campaign_version)
	data.format_version= sanity_check_version(data.format_version)
	return true
end

local function path_sanity(path)
	if type(path) ~= "table" then
		return false, "Is not a table."
	end
	if #path < 1 then
		return false, "Does not contain points."
	end
	for i= 1, #path do
		local point= path[i]
		if type(point) ~= "table" then
			return false, "Point " .. i .. " is not a table."
		end
		for c= 1, 3 do
			if type(point[c]) ~= "number" then
				return false, "Malformed point " .. i .. "."
			end
		end
	end
	return true
end

local function find_path(path_set, reference)
	local group= path_set[reference[1]]
	if not group then
		return false, "Group " .. reference[1] .. " does not exist."
	end
	local path= group[reference[2]]
	if not path then
		return false, "Path " .. reference[2] .. " does not exist in group " .. reference[1] .. "."
	end
	return path
end

local function ship_lev_mes(l, s)
	return "level " .. l .. ", ship " .. s
end

local function campaign_data_sanity(data)
	if not data.entry_paths then
		return false, "Campaign data lacks entry paths."
	end
	for group_name, group in pairs(data.entry_paths) do
		if type(group) ~= "table" then
			return false, "Invalid group " .. group_name .. " in entry_paths."
		end
		for entry_name, entry in pairs(group) do
			if type(entry) ~= "table" then
				return false, "Invalid entry path " .. entry_name .. "."
			end
			if type(entry.x) ~= "number" then
				return false, "Entry path " .. entry_name .. " lacks x start."
			end
			if type(entry.y) ~= "number" then
				return false, "Entry path " .. entry_name .. " lacks y chromosome."
			end
			local path_sane, messsage= path_sanity(entry.path)
			if not path_sane then
				return false, "Path for entry path " .. entry_name .. ": " .. message
			end
		end
	end
	if not data.attack_paths then
		return false, "Campaign data lacks attack paths."
	end
	for group_name, group in pairs(data.attack_paths) do
		if type(group) ~= "table" then
			return false, "Invalid attack_paths group " .. group_name .. "."
		end
		for entry_name, entry in pairs(group) do
			local path_sane, message= path_sanity(entry)
			if not path_sane then
				return false, "Attack path " .. entry_name .. " is not valid: " .. meessage
			end
		end
	end
	if not data.levels then
		return false, "Campaign data lacks levels."
	end
	if #data.levels < 1 then
		return false, "An empty table named levels does not count as level data."
	end
	for l= 1, #data.levels do
		local level= data.levels[l]
		if type(level) ~= "table" then
			return false, "Level " .. l .. " is invalid."
		end
		if #level < 1 then
			return false, "A level " .. l .. " without ships is "
		end
		for s= 1, #level do
			local ship= level[s]
			if type(ship) ~= "table" then
				return false, ship_lev_mes(l, s) .. " is invalid."
			end
			if type(ship.convoy_id) ~= "number" then
				return false, ship_lev_mes(l, s) .. " needs convoy_id."
			end
			if type(ship.ship) ~= "number" then
				return false, ship_lev_mes(l, s) .. " needs ship type."
			end
			if type(ship.delay) ~= "number" then
				return false, ship_lev_mes(l, s) .. " needs delay."
			end
			if type(ship.enter) ~= "table" then
				return false, ship_lev_mes(l, s) .. " needs enter path."
			end
			if #ship.enter ~= 2 then
				return false, ship_lev_mes(l, s) .. " enter path is invalid."
			end
			local entry_path, err= find_path(data.entry_paths, ship.enter)
			if not entry_path then
				return false, "Enter path for " .. ship_lev_mes(l, s) .. " not found: " .. err
			end
		end
	end
	return true
end

local function load_all_campaign_meta()
	local campaign_files= love.filesystem.getDirectoryItems(campaign_path)
	campaign_meta_data= {}
	for i= 1, #campaign_files do
		local fname= campaign_files[i]
		if end_match(fname, meta_end) then
			local camp_name= end_clip(fname, meta_end)
			local data, err= save.load_save_file(fname, blank_campaign_meta, campaign_meta_sanity)
			if err then
				save.log("Cannot load campaign meta data: " .. err)
			else
				if type(data.name) ~= "string" then
					data.name= camp_name
				end
				if campaign_meta_data[camp_name] then
					data.data_file= campaign_meta_data[camp_name].data_file
				end
				campaign_meta_data[camp_name]= data
			end
		elseif end_match(fname, data_end) then
			local camp_name= end_clip(fname, data_end)
			if campaign_meta_data[camp_name] then
				campaign_meta_data[camp_name].data_file= fname
			else
				campaign_meta_data[camp_name]= {
					name= camp_name, author= "Unknown", description= "",
					campaign_version= {1, 0, 0}, format_version= {1, 0, 0},
					data_file= fname,
				}
			end
			if love.filesystem.getRealDirectory(campaign_path..fname) == love.filesystem.getSaveDirectory() then
				campaign_meta_data[camp_name].editable= true
			end
		end
	end
	return campaign_meta_data
end

local function unique_untitled_meta()
	local unt= "Untitled"
	local final_name= unt
	if campaign_meta_data[unt] then
		local i= 2
		local name= unt .. " " .. i
		while campaign_meta_data[name] do
			i= i + 1
			name= unt .. " " .. i
		end
		final_name= name
	end
	local data= {
		name= final_name, author= "Unknown", description= "",
		campaign_version= {1, 0, 0}, format_version= {1, 0, 0},
		data_file= name .. "_" .. data_end,
	}
	campaign_meta_data[final_name]= data
	return data
end

local function load_campaign_level_data(camp_name)
	local meta= campaign_meta_data[camp_name]
	if not meta then
		return false, "Campaign '" .. camp_name .. "' does not exist."
	end
	if not meta.data_file then
		return false, "Campaign '" .. camp_name .. "' data does not exist."
	end
	local data, err= save.load_save_file(campaign_path .. meta.data_file, blank_campaign_data, campaign_data_sanity)
	if err then
		return false, "Campaign loading failed: " .. err
	end
	return data
end

local function make_randomable_attack_path_list(camp_data)
	local list= {}
	for group_name, group in pairs(camp_data.attack_paths) do
		for path_name, path in pairs(group) do
			list[#list+1]= path
		end
	end
	return list
end

return {
	load_all_campaign_meta= load_all_campaign_meta,
	load_campaign_level_data= load_campaign_level_data,
	make_randomable_attack_path_list= make_randomable_attack_path_list,
	find_path= find_path,
	unique_untitled_meta= unique_untitled_meta,
	blank_campaign_data= blank_campaign_data,
}
