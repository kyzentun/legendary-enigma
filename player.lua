local dimensions= require("dimensions")
local images= require("images")
local key_config= require("key_config")
local sprite_oneesan= require("sprite")
local entity_oneesan= require("entity")
local clutter= require("clutter")

local player= {}
local player_speed= 120

local fire_is_down= false
local next_fire_time= 0
local reload_time= .0625
local mtorp_speed= 150
local mtorp_life_time= dimensions.space_height / mtorp_speed

local mtorp_pool= {}
local mtorp_clutter= {}
local mtorp_image= {}
local mtorp_frame= {}

local function update_torpor(pool, curr_time)
	for t= #pool, 1, -1 do
		local torp= pool[t]
		if curr_time >= torp.death_time then
			torp.entity:destroy("mtorps")
			table.remove(pool, t)
		end
	end
end

local function player_draw()
	local torp_center= images.mtorp.center
	local tcx= torp_center.x
	local tcy= torp_center.y
	for t= 1, #mtorp_pool do
		local torp= mtorp_pool[t]
		love.graphics.draw(
			mtorp_image, mtorp_frame, torp.entity.x - tcx, torp.entity.y - tcy)
	end
	local player_center= player.image.center
	love.graphics.draw(
		player.image.image, player.image.frames[player.sprite.curr_frame],
		player.entity.x - player_center.x, player.entity.y - player_center.y)
end

local function player_update(curr_time)
	update_torpor(mtorp_pool, curr_time)
	if fire_is_down and curr_time >= next_fire_time then
		next_fire_time= curr_time + reload_time
		local player_ent= player.entity
		local fire_x= player_ent.x
		local torp_cen= images.mtorp.center
		local torp_w= torp_cen.w
		local torp_h= torp_cen.h
		mtorp_pool[#mtorp_pool+1]= {
			death_time= curr_time + mtorp_life_time,
			entity= entity_oneesan.create_entity(
				"mtorps", curr_time, player_ent.x, player_ent.y, torp_w, torp_h, 0, -mtorp_speed),
		}
	end
	mtorp_clutter:fill(mtorp_pool)
end

local function get_torps()
	return mtorp_clutter
end

local function begin()
	mtorp_image= images.mtorp.image
	mtorp_frame= images.mtorp.frames[1]
	local sprite_time, game_time= get_sprite_and_game_time()
	local player_center= images.player.center
	player= {
		image= images.player,
		sprite= sprite_oneesan.create_sprite(sprite_time, #images.player.frames, .25),
		entity= entity_oneesan.create_entity(
			"player", game_time, dimensions.space_width * .5,
			dimensions.space_height - (player_center.h * 2),
			player_center.w, player_center.h, 0, 0),
	}
	mtorp_clutter= clutter.create_clutter(
		dimensions.space_width, dimensions.space_height,
		images.mtorp.center.w, images.mtorp.center.h)
end

local function end_gameplay()
	player= nil
	mtorp_clutter= nil
end

local function up_press()
	local ent= player.entity
	ent:set_speed(ent.speed_x, ent.speed_y - player_speed)
end

local function up_release()
	local ent= player.entity
	ent:set_speed(ent.speed_x, ent.speed_y + player_speed)
end

local function left_press()
	local ent= player.entity
	ent:set_speed(ent.speed_x - player_speed, ent.speed_y)
end

local function left_release()
	local ent= player.entity
	ent:set_speed(ent.speed_x + player_speed, ent.speed_y)
end

local function fire_press()
	fire_is_down= true
end

local function fire_release()
	fire_is_down= false
end

key_config.register_section(
	"gameplay", {
		{name= "up", keys= {"up"}, press= up_press, release= up_release},
		{name= "down", keys= {"down"}, press= up_release, release= up_press},
		{name= "left", keys= {"left"}, press= left_press, release= left_release},
		{name= "right", keys= {"right"}, press= left_release, release= left_press},
		{name= "fire", keys= {"space"}, press= fire_press, release= fire_release},
})

return {
	draw= player_draw,
	update= player_update,
	get_torps= get_torps,
	begin= begin,
	end_gameplay= end_gameplay,
}
