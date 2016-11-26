local sprite_pool= {}
local need_destruction_pass= false

local pool_stack= {}

local function sprite_set_frame(self, frame)
	self.time_offset= get_sprite_time()
	self.frame_offset= frame - 1
end

local function sprite_set_duration(self, duration)
	-- This should result in the sprite staying on the same frame, but moving
	-- at a different speed from now until the next change.
	-- FIXME?  This loses a partial frame.
	self.time_offset= get_sprite_time()
	self.frame_offset= sprite.curr_frame - 1
	self.duration= duration
	self.time_to_frame_factor= self.num_frames / duration
end

local function sprite_destroy(self)
	need_destruction_pass= true
	self.needs_destruction= true
end

local function create_sprite(curr_time, num_frames, duration)
	local new_sprite= {
		num_frames= num_frames, duration= duration, time_offset= curr_time,
		curr_frame= 1, frame_offset= 0,
		time_to_frame_factor= num_frames / duration,
		set_frame= sprite_set_frame,
		set_duration= sprite_set_duration,
		destroy= sprite_destroy,
	}
	sprite_pool[#sprite_pool+1]= new_sprite
	return new_sprite
end

local function update_sprites(curr_time)
	-- Mixed feelings about this.  Many deletions in one frame should be
	-- handled nicely, but two passes is generally considered bad.
	if need_destruction_pass then
		for s= #sprite_pool, 1, -1 do
			if sprite_pool[s].needs_destruction then
				table.remove(sprite_pool, s)
			end
		end
		need_destruction_pass= false
	end
	for s= #sprite_pool, 1, -1 do
		local sprite= sprite_pool[s]
		local time_diff= curr_time - sprite.time_offset
		local frame_time= time_diff % sprite.duration
		local frame_index= math.floor(frame_time * sprite.time_to_frame_factor)
		sprite.curr_frame= ((frame_index + sprite.frame_offset) % sprite.num_frames) + 1
	end
end

local function clear_sprites()
	sprite_pool= {}
end

local function push_stack()
	pool_stack[#pool_stack+1]= sprite_pool
	sprite_pool= {}
end

local function pop_stack()
	sprite_pool= pool_stack[#pool_stack]
	pool_stack[#pool_stack]= nil
end

return {
	create_sprite= create_sprite,
	update= update_sprites,
	clear= clear_sprites,
	push_stack= push_stack,
	pop_stack= pop_stack,
}
