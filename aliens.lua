local dimensions= require("dimensions")
local images= require("images")
local key_config= require("key_config")
local sprite_oneesan= require("sprite")
local entity_oneesan= require("entity")
local clutter= require("clutter")
local motion= require("motion")
local campaign= require("campaign")

local alien_pool= {}
local alien_speed= 120
local alien_w= -1
local alien_h= -1
local explosion_pool= {}
local explosion_life= .125

local convoy_snap_dist= alien_speed / 60
local convoy_x_spacing= 20
local convoy_y_spacing= 20
local convoy_barycenter= dimensions.space_width / 2
local convoy_width= dimensions.space_width / convoy_x_spacing / 2
local convoy_max_dist_from_center=
	(dimensions.space_width - (convoy_width * convoy_x_spacing)) / 2
local convoy_speed= alien_speed / 4
local convoy_wave_frequency= (convoy_max_dist_from_center * 4) / convoy_speed
local convoy_time_to_angle= 1 / convoy_wave_frequency
local convoy_entity= {}
local convoy_y_start= 20
local next_convoy_reverse_time= 0

local function convoy_move(ent, curr_time)
	local time_diff= curr_time - ent.time_offset
	local angle= (time_diff * convoy_time_to_angle) % 2
	if angle < 1 then
		ent.x= ((angle - .5) * convoy_max_dist_from_center * 2) + convoy_barycenter
		ent.speed_x= convoy_speed
	else
		ent.x= ((angle - 1.5) * -convoy_max_dist_from_center * 2) + convoy_barycenter
		ent.speed_x= -convoy_speed
	end
end

local function convoy_x_pos(id)
	return convoy_x_spacing * ((id % convoy_width) - ((convoy_width-1) * .5))
end

local function convoy_y_pos(id)
	return convoy_y_spacing * math.floor(id / convoy_width)
end

local function alien_in_convoy_move(ent, curr_time)
	ent.x= convoy_entity.x + ent.convoy_x
	ent.y= convoy_entity.y + ent.convoy_y
	ent.speed_x= convoy_entity.speed_x
	ent.speed_y= convoy_entity.speed_y
end

local function in_space(x, y)
	return x >= 0 and x <= dimensions.space_width and
		y >= 0 and y <= dimensions.space_height
end

local function explode_entity(curr_time, ent)
	explosion_pool[#explosion_pool+1]= {
		death_time= explosion_life + curr_time,
		image= images.explosion,
		sprite= sprite_oneesan.create_sprite(
			curr_time, #images.explosion.frames, explosion_life),
		entity= entity_oneesan.create_entity(
			"explosions", curr_time, ent.x, ent.y, 0, 0, ent.speed_x, ent.speed_y),
	}
end

local function speed_to_frame(sx, sy)
	return math.floor((((math.atan2(sx, sy) * -1) + math.pi) / (math.pi * 2)) * 16) + 1
end

local ai_decide= {}
ai_decide.waiting_to_enter= function(alien, curr_time)
	if curr_time > alien.enter_time then
		alien.ai_update= ai_decide.entering
		motion.set_dir_path(alien.entity, alien.enter_path, curr_time, alien_speed)
	end
end
ai_decide.entering= function(alien, curr_time)
	alien.frame= speed_to_frame(alien.entity.speed_x, alien.entity.speed_y)
	if alien.entity.position_eval == motion.linear then
		alien.ai_update= ai_decide.returning
	end
end
ai_decide.in_convoy= function(alien, curr_time)
	
end
ai_decide.attacking= function(alien, curr_time)
	
end
ai_decide.escorting= function(alien, curr_time)
	
end
ai_decide.returning= function(alien, curr_time)
	local cxp= alien.entity.convoy_x + convoy_entity.x
	local cyp= alien.entity.convoy_y + convoy_entity.y
	local xd= cxp - alien.entity.x
	local yd= cyp - alien.entity.y
	if math.abs(xd) < convoy_snap_dist and math.abs(yd) < convoy_snap_dist then
		alien.frame= 9
		alien.entity:set_pos_at(curr_time, cxp, cyp)
		alien.entity:set_speed_at(curr_time, convoy_speed, 0)
		alien.ai_update= ai_decide.in_convoy
		alien.entity.position_eval= alien_in_convoy_move
	else
		local dist= math.sqrt((xd*xd) + (yd*yd))
		local sx= alien_speed * (xd / dist)
		local sy= alien_speed * (yd / dist)
		alien.frame= speed_to_frame(sx, sy)
		alien.entity:set_speed_at(curr_time, sx, sy)
	end
end

local function update(curr_time)
	for e= #explosion_pool, 1, -1 do
		local exp= explosion_pool[e]
		if curr_time >= exp.death_time then
			exp.entity:destroy("explosions")
			exp.sprite:destroy()
			table.remove(explosion_pool, e)
		end
	end
end

local function ai_update(curr_time)
	for a= 1, #alien_pool do
		alien_pool[a]:ai_update(curr_time) 
	end
end

local function hit_torps(curr_time, torp_clutter)
	for a= #alien_pool, 1, -1 do
		local alien= alien_pool[a]
		if in_space(alien.entity.x, alien.entity.y) then
			local collision_list= torp_clutter:find_collisions(curr_time, alien.entity)
			if #collision_list > 0 then
				local torps_to_hit= math.min(#collision_list, alien.hp)
				alien.hp= alien.hp - torps_to_hit
				for t= 1, #collision_list do
					local torp= collision_list[t]
					torp.death_time= curr_time
				end
				if alien.hp <= 0 then
					explode_entity(curr_time, alien.entity)
					alien.entity:destroy("aliens")
					table.remove(alien_pool, a)
				end
			end
		end
	end
end

local function draw()
	local acx= images.aliens[1].center.x
	local acy= images.aliens[1].center.y
	for a= 1, #alien_pool do
		local alien= alien_pool[a]
		if in_space(alien.entity.x, alien.entity.y) then
			love.graphics.draw(
				alien.image.image, alien.image.frames[alien.frame],
				alien.entity.x - acx, alien.entity.y - acy)
		end
	end
	if #explosion_pool > 0 then
		local ecx= images.explosion.center.x
		local ecy= images.explosion.center.y
		for e= 1, #explosion_pool do
			local exp= explosion_pool[e]
			love.graphics.draw(
				exp.image.image, exp.image.frames[exp.sprite.curr_frame],
				exp.entity.x - ecx, exp.entity.y - ecy)
		end
	end
end

local function spawn(level, entry_paths, hp)
	local curr_time= get_game_time()
	for i= 1, #level do
		local ship= level[i]
		local entry, message= campaign.find_path(entry_paths, ship.enter)
		if entry then
			local alien= {
				convoy_id= ship.convoy_id,
				image= images.aliens[ship.ship], frame= 1,
				hp= hp, ai_update= ai_decide.waiting_to_enter,
				enter_time= curr_time + ship.delay,
				enter_path= entry.path,
				entity= entity_oneesan.create_entity(
					"aliens", curr_time, entry.x, entry.y, alien_w, alien_h, 0, 0),
			}
			alien.entity.convoy_x= convoy_x_pos(ship.convoy_id)
			alien.entity.convoy_y= convoy_y_pos(ship.convoy_id)
			alien.entity.position_eval= motion.motionless
			alien_pool[#alien_pool+1]= alien
		else
			save.log(message)
		end
	end
end

local function begin()
	alien_w= images.aliens[1].center.w
	alien_h= images.aliens[1].center.h
	alien_pool= {}
	local curr_time= get_game_time()
	convoy_entity= entity_oneesan.create_entity(
		"aliens", curr_time, dimensions.space_width / 2, convoy_y_start, 0, 0, convoy_speed, 0)
	convoy_entity.position_eval= convoy_move
	next_convoy_reverse_time= curr_time
end

local function end_gameplay()
	alien_pool= nil
end

return {
	update= update,
	ai_update= ai_update,
	draw= draw,
	hit_torps= hit_torps,
	spawn= spawn,
	begin= begin,
	end_gameplay= end_gameplay,
}
