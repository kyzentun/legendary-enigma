local menu= require("menu")
local sprite_oneesan= require("sprite")

local return_to_thing
local num_noop= 0
local active_menu

local function close()
	active_menu:destroy()
	love.mousemoved= nil
	love.mousepressed= nil
	love.wheelmoved= nil
	return_to_thing()
end

local function make_menu_layer()
	local ret= {
		{name= "num_noop", value= num_noop,
		 adjust_up= function() num_noop= num_noop + 1 return num_noop end,
		 adjust_down= function() num_noop= num_noop - 1 return num_noop end},
		{name= "refresh", func= function() return "refresh", make_menu_layer() end},
		{name= "submenu", func= function() return "submenu", make_menu_layer() end},
		{name= "close 1", func= function() return "close", 1 end},
		{name= "close 2", func= function() return "close", 2 end},
		{name= "close all", func= function() return "close", -1 end},
	}
	for i= 1, num_noop do
		ret[#ret+1]= {name= "noop " .. i}
	end
	return ret
end

local function draw()
	active_menu:draw()
end

local function update()
	local curr_time= love.timer.getTime()
	sprite_oneesan.update(curr_time)
end

local function mousemoved(x, y)
	active_menu:mousemoved(x, y)
end

local function mousepressed(x, y, button)
	active_menu:mousepressed(x, y, button)
end

local function mousewheel(x, y)
	active_menu:mousewheel(x, y)
end

local function begin(modore)
	active_menu= menu.create(make_menu_layer(), close, 0, 0)
	return_to_thing= modore
	love.update= update
	love.draw= draw
	love.mousemoved= mousemoved
	love.mousepressed= mousepressed
	love.wheelmoved= mousewheel
	active_menu:activate()
end

return {
	begin= begin,
}
