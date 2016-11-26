local dimensions= require("dimensions")
local motion= require("motion")

local entity_pools= {}
local pools_by_name= {}

local pool_stack= {}

local function create_pool(name)
	local new_pool= {name= name}
	entity_pools[#entity_pools+1]= new_pool
	pools_by_name[name]= new_pool
end

local function clear_system()
	entity_pools= {}
	pools_by_name= {}
end

local function entity_set_pos(self, x, y)
	self.start_x= self.x
	self.start_y= self.y
	self.time_offset= get_game_time()
	self.x= x
	self.y= y
end

local function entity_set_pos_at(self, curr_time, x, y)
	self.start_x= self.x
	self.start_y= self.y
	self.time_offset= curr_time
	self.x= x
	self.y= y
end

local function entity_set_size(self, w, h)
	self.w= w
	self.h= h
end

local function entity_set_speed(self, xs, ys)
	self.start_x= self.x
	self.start_y= self.y
	self.time_offset= get_game_time()
	self.speed_x= xs
	self.speed_y= ys
end

local function entity_set_speed_at(self, curr_time, xs, ys)
	self.start_x= self.x
	self.start_y= self.y
	self.time_offset= curr_time
	self.speed_x= xs
	self.speed_y= ys
end

local function entity_destroy(self, pool_name)
	self.needs_destruction= true
	pools_by_name[pool_name].need_destruction_pass= true
end

local function create_entity(pool_name, curr_time, x, y, w, h, xs, xy)
	local new_entity= {
		start_x= x, start_y= y, x= x, y= y, w= w, h= h, speed_x= xs, speed_y= xy,
		time_offset= curr_time,
		set_pos= entity_set_pos, set_size= entity_set_size,
		set_speed= entity_set_speed,
		set_pos_at= entity_set_pos_at, set_speed_at= entity_set_speed_at,
		position_eval= motion.linear,
		destroy= entity_destroy,
	}
	local pool= pools_by_name[pool_name]
	assert(pool, "Unknown entity pool: " .. pool_name)
	pool[#pool+1]= new_entity
	return new_entity
end

local function update_entities(curr_time)
	for p= 1, #entity_pools do
		local pool= entity_pools[p]
		if pool.need_destruction_pass then
			for e= #pool, 1, -1 do
				if pool[e].needs_destruction then
					table.remove(pool, e)
				end
			end
		end
		for e= #pool, 1, -1 do
			pool[e]:position_eval(curr_time)
		end
	end
end

local function push_stack()
	pool_stack[#pool_stack+1]= {entity_pools, pools_by_name}
	entity_pools= {}
	pools_by_name= {}
end

local function pop_stack()
	local top= pool_stack[#pool_stack]
	entity_pools= top[1]
	pools_by_name= top[2]
	pool_stack[#pool_stack]= nil
end

return {
	create_pool= create_pool,
	create_entity= create_entity,
	update= update_entities,
	clear= clear_system,
	push_stack= push_stack,
	pop_stack= pop_stack,
}
