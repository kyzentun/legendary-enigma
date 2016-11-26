local menu= require("menu")

local num_noop= 0

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

local function begin(modore)
	menu.begin(modore, nil, make_menu_layer())
end

return {
	begin= begin,
}
