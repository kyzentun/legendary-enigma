local dimensions= require("dimensions")
local save= require("save_system")

local function motionless()
	-- not moving.
end

local function linear(ent, curr_time)
	local time_diff= curr_time - ent.time_offset
	ent.x= (ent.start_x + (ent.speed_x * time_diff)) % dimensions.space_width
	ent.y= (ent.start_y + (ent.speed_y * time_diff)) % dimensions.space_height
end

local function follow_path(ent, curr_time)
	local curr_step= ent.path[ent.path_pos]
	while curr_time > curr_step.end_time do
		local next_step= ent.path[ent.path_pos+1]
		if next_step then
			ent.path_pos= ent.path_pos + 1
			curr_step= next_step
		else
			ent.start_x= curr_step.x + (curr_step.speed_x * curr_step.duration)
			ent.start_y= curr_step.y + (curr_step.speed_y * curr_step.duration)
			ent.time_offset= curr_step.end_time
			ent.path= nil
			ent.path_pos= nil
			ent.position_eval= linear
			ent:position_eval(curr_time)
			return
		end
	end
	local step_time= curr_time - curr_step.start_time
	-- Path following does not wrap coordinates because it's for aliens that
	-- start outside the play area and enter.
	--save.log(("path step: %d  step_time: %.2f  step_pos: %d, %d  step_speed: %.2f, %.2f  ent_pos: %d, %d"):format(ent.path_pos, step_time, curr_step.x, curr_step.y, curr_step.speed_x, curr_step.speed_y, ent.x, ent.y))
	ent.speed_x= curr_step.speed_x
	ent.speed_y= curr_step.speed_y
	ent.x= curr_step.x + (curr_step.speed_x * step_time)
	ent.y= curr_step.y + (curr_step.speed_y * step_time)
end

local function followable_point_path(path, start_time, start_x, start_y, speed)
	local ret= {}
	local step_end_time= start_time
	for i= 1, #path-1 do
		local step= path[i]
		local next_step= path[i+1]
		local xd= next_step[1] - step[1]
		local yd= next_step[2] - step[2]
		local dist= math.sqrt((xd*xd) + (yd*yd))
		local duration= dist / speed
		local step_start_time= step_end_time
		step_end_time= step_end_time + duration
		ret[#ret+1]= {
			x= start_x + step[1], y= start_y + step[2], duration= duration,
			speed_x= (xd / dist) * speed, speed_y= (yd / dist) * speed,
			start_time= step_start_time, end_time= step_end_time,
		}
	end
	return ret
end

local function set_point_path(ent, path, curr_time, speed)
	ent.start_x= ent.x
	ent.start_y= ent.y
	ent.position_eval= follow_path
	ent.path= followable_point_path(path, curr_time, ent.x, ent.y, speed)
	ent.time_offset= curr_time
	ent.path_pos= 1
end

local function followable_dir_path(path, start_time, start_x, start_y, speed)
	local ret= {}
	local step_x= start_x
	local step_y= start_y
	local step_end_time= start_time
	for i= 1, #path do
		local step= path[i]
		local ssx= step[1]
		local ssy= step[2]
		local step_dur= step[3]
		local step_start_time= step_end_time
		step_end_time= step_end_time + step_dur
		ret[#ret+1]= {
			x= step_x, y= step_y, speed_x= ssx, speed_y= ssy, duration= step_dur,
			start_time= step_start_time, end_time= step_end_time,
		}
		step_x= step_x + (ssx * step_dur)
		step_y= step_y + (ssy * step_dur)
	end
	return ret
end

local function set_dir_path(ent, path, curr_time, speed)
	ent.start_x= ent.x
	ent.start_y= ent.y
	ent.position_eval= follow_path
	ent.path= followable_dir_path(path, curr_time, ent.x, ent.y, speed)
	ent.time_offset= curr_time
	ent.path_pos= 1
end

return {
	motionless= motionless,
	linear= linear,
	set_point_path= set_point_path,
	set_dir_path= set_dir_path,
}
