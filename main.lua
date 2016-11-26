function math.round_to_zero(num)
	if num > 0 then
		return math.floor(num)
	else
		return math.ceil(num)
	end
end

function math.round(num)
	if num > 0 then
		return math.floor(num+.5)
	else
		return math.ceil(num-.5)
	end
end

function table.copy(tab, visited)
	local ret= {}
	visited= visited or {}
	for key, entry in pairs(tab) do
		local entry_type= type(entry)
		if entry_type == "table" then
			if visited[entry] then
				ret[key]= visited[entry]
			else
				visited[entry]= entry
				ret[key]= table.copy(entry, visited)
			end
		else
			ret[key]= entry
		end
	end
	return ret
end

local save= require("save_system")
local dimensions= require("dimensions")
local images= require("images")
local key_config= require("key_config")
local pregame= require("pregame")
local gameplay= require("gameplay")
--local xgal_paths= require("xgal_paths")

local fps= 0
local function pregame_update(delta)
	fps= 1/delta
end

local load_message= images.load_message
local load_progress= 0

local function loading_update(delta)
	local new_progress= images.load_update()
	if new_progress then
		load_progress= new_progress
	else
		pregame.preload()
		pregame.begin()
	end
end

local function loading_draw()
	love.graphics.print(load_message, 0, 0)
	love.graphics.rectangle("fill", 0, 20, dimensions.space_width * load_progress, 20)
end

function love.load()
	--xgal_paths.convert_xgal_dir_paths()
	--xgal_paths.convert_xgal_enter_paths()
end

function love.quit()
	key_config.save_keys()
end

love.update= loading_update
love.draw= loading_draw
key_config.load_keys()
