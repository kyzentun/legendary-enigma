local dimensions= require("dimensions")
local images= require("images")
local key_config= require("key_config")
local sprite_oneesan= require("sprite")
local entity_oneesan= require("entity")
local player= require("player")
local aliens= require("aliens")
local save= require("save_system")
local campaign= require("campaign")

local return_to_pregame

local pause_menu_start_y= 100
local pause_menu_row_spacing= 20
local pause_menu_key_x= 50
local pause_menu_name_x= 100

local pause_start_time= 0
local pause_time_adjust= 0

local campaign_data= {}

function get_game_time()
	return love.timer.getTime() - pause_time_adjust
end

function get_sprite_time()
	return love.timer.getTime()
end

function get_sprite_and_game_time()
	local love_time= love.timer.getTime()
	return love_time, love_time - pause_time_adjust
end

local update_time= 0

local function update(delta)
	local sprite_time, game_time= get_sprite_and_game_time()
	local update_start_time= love.timer.getTime()
	aliens.update(game_time)
	aliens.hit_torps(game_time, player.get_torps())
	player.update(game_time)
	sprite_oneesan.update(sprite_time)
	entity_oneesan.update(game_time)
	aliens.ai_update(game_time)
	local update_end_time= love.timer.getTime()
	update_time= update_end_time - update_start_time
end

local function draw()
	love.graphics.setColor(255, 255, 255)
	love.graphics.print(save.get_recent_log(), 0, 0)
	love.graphics.print(love.timer.getFPS() .. ", " .. math.round(1 / update_time), 0, 10)
	love.graphics.push()
	love.graphics.translate(0, dimensions.status_height)
	love.graphics.setColor(255, 255, 255)
	aliens.draw()
	player.draw()
	love.graphics.pop()
end

local function pause_update(delta)
	sprite_oneesan.update(get_sprite_time())
end

local function pause_draw()
	draw()
	local section_info= key_config.get_section_info("pause")
	for i= 1, #section_info do
		local entry= section_info[i]
		local row_y= pause_menu_start_y + ((i-1) * pause_menu_row_spacing)
		local key= entry.keys[1]
		if key then
			love.graphics.print(key, pause_menu_key_x, row_y)
		end
		love.graphics.print(entry.name, pause_menu_name_x, row_y)
	end
end

local function pause_mousepressed(x, y, button)
	local row_id= math.ceil((y - pause_menu_start_y) / pause_menu_row_spacing)
	if row_id < 1 then return end
	local section_info= key_config.get_section_info("pause")
	if row_id > #section_info then return end
	if x >= pause_menu_name_x and x < pause_menu_name_x + 100 then
		local row= section_info[row_id]
		if row.press then
			row.press()
		elseif row.release then
			row.release()
		end
	end
end

local function begin(modore)
	campaign.load_all_campaign_meta()
	local camp, message= campaign.load_campaign_level_data("default")
	assert(camp, message)
	campaign_data= camp
	return_to_pregame= modore
	pause_time_adjust= love.timer.getTime()
	entity_oneesan.create_pool("player")
	entity_oneesan.create_pool("mtorps")
	entity_oneesan.create_pool("etorps")
	entity_oneesan.create_pool("aliens")
	entity_oneesan.create_pool("prizes")
	entity_oneesan.create_pool("explosions")
	player.begin()
	aliens.begin()
	love.update= update
	love.draw= draw
	key_config.set_active_section("gameplay")
end

local function pause()
	pause_start_time= love.timer.getTime()
	key_config.set_active_section("pause")
	love.update= pause_update
	love.draw= pause_draw
	love.mousepressed= pause_mousepressed
end

local function resume()
	key_config.set_active_section("gameplay")
	local curr_time= love.timer.getTime()
	pause_time_adjust= pause_time_adjust + (curr_time - pause_start_time)
	love.update= update
	love.draw= draw
	love.mousepressed= nil
end

local function end_gameplay()
	player.end_gameplay()
	sprite_oneesan.clear()
	entity_oneesan.clear()
	return_to_pregame()
end

local function key_config_return()
	sprite_oneesan.pop_stack()
	entity_oneesan.pop_stack()
	pause()
end

local function open_key_config()
	sprite_oneesan.push_stack()
	entity_oneesan.push_stack()
	key_config.begin(key_config_return)
end

local function spawn(level_id)
	local level_data= campaign_data.levels[((level_id-1)%#campaign_data.levels)+1]
	aliens.spawn(level_data, campaign_data.entry_paths, 1)
end

key_config.register_section(
	"gameplay", {
		{name= "pause", keys= {"escape"}, press= pause},

		{name= "spawn all", keys= {"w"}, press= function()
			 for l= 1, #campaign_data.levels do spawn(l) end end},
		{name= "spawn double", keys= {"e"}, press= function()
			 for l= 1, #campaign_data.levels*2 do spawn(l) end end},
		{name= "spawn 1", keys= {"a"}, press= function() spawn(1) end},
		{name= "spawn 2", keys= {"s"}, press= function() spawn(2) end},
		{name= "spawn 3", keys= {"d"}, press= function() spawn(3) end},
		{name= "spawn 4", keys= {"f"}, press= function() spawn(4) end},
		{name= "spawn 5", keys= {"g"}, press= function() spawn(5) end},
		{name= "spawn 6", keys= {"h"}, press= function() spawn(6) end},
		{name= "spawn 7", keys= {"j"}, press= function() spawn(7) end},
		{name= "spawn 8", keys= {"k"}, press= function() spawn(8) end},
		{name= "spawn 9", keys= {"l"}, press= function() spawn(9) end},
		{name= "spawn 10", keys= {";"}, press= function() spawn(10) end},
		{name= "spawn 11", keys= {"z"}, press= function() spawn(11) end},
		{name= "spawn 12", keys= {"x"}, press= function() spawn(12) end},
		{name= "spawn 13", keys= {"c"}, press= function() spawn(13) end},
		{name= "spawn 14", keys= {"v"}, press= function() spawn(14) end},
		{name= "spawn 15", keys= {"b"}, press= function() spawn(15) end},
		{name= "spawn 16", keys= {"n"}, press= function() spawn(16) end},
})

key_config.register_section(
	"pause", {
		{name= "exit", keys= {"q"}, release= end_gameplay},
		{name= "resume", keys= {"escape"}, press= resume},
		{name= "key_config", keys= {"k"}, press= open_key_config},
})

return {
	begin= begin,
}
