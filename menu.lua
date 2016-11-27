local dimensions= require("dimensions")
local key_config= require("key_config")
local images= require("images")
local sprite_oneesan= require("sprite")

local return_to_thing
local bg_draw

local active_menu

local items_per_page= 20
local option_key_info_offset -- Set when first menu is created.
local cursor_x= 30
local menu_start_y= 20
local menu_row_spacing= 20
local menu_item_key_x= 5
local menu_item_name_x= 35
local menu_item_value_x= 160
local menu_adjust_up_x= 210
local menu_adjust_down_x= 140
local close_menu_key_x= 20
local close_menu_name_x= 90
local close_menu_y= menu_start_y - menu_row_spacing
-- info example:
-- {
--   {name= "foo", arg= {}, func= function(arg) end},
--   -- arg is for any information that func needs.  The menu system will not
--   --   touch arg in any way except to pass it to func.
--   -- func must return the action to perform when the item is chosen.
--   -- If func returns nil, the menu stays as-is.
--   -- If func returns "'refresh', {}", the table replaces the current menu.
--   -- If func returns "'submenu', {}", the table is another menu to open.
--   -- If func returns "'close', 1", the current submenu is closed.
--   --   The number returned with "close" is the number of submenu layers to
--   --   close.  -1 will close the entire menu.
--   {name= "foo", value= "bar", arg= {}, func= function(arg) end,
--     adjust_up= function(arg) end, adjust_down= function(arg) end},
--   -- func has the same behavior as the first example.
--   -- The player has two buttons for adjusting the value of a menu item.
--   -- adjust_up and adjust_down are used for these buttons.
--   -- adjust_* must return the new value to display.
--   ...
-- }

-- Menu object:
-- {
--   x= x, y= y, -- Provided by creator.
--   top= menu info, -- Provided by creator.
--   on_close= function() end, -- Provided by creator.
--   -- With no on_close function, the menu cannot be closed from within.
--   stack= {},
--   menu_offset= 1,
--   cursor_offset= 0,
--   cursor_sprite= sprite,
--   draw= function() end,
--   mousemoved= function() end,
--   mousepressed= function() end,
--   mousewheel= function() end,
--   activate= function() end,
--   deactivate= function() end,
--   destroy= function() end,
--   close_level= function() end,
--   handle_func_call= function() end,
--   handle_adjust_up= function() end,
--   handle_adjust_down= function() end,
-- }

local function min_clamp_menu_offset(off)
	return math.max(1, off)
end

local function max_clamp_menu_offset(top, off)
	return math.min(math.max(1, #top - items_per_page + 1), off)
end

local function deactivate(self)
	if active_menu == self then
		active_menu= nil
	end
end

local function destroy(self)
	self:deactivate()
	self.cursor_sprite:destroy()
end

local function activate(self)
	active_menu= self
	key_config.set_active_section("menu")
end

local function draw(self)
	love.graphics.push()
	love.graphics.setColor(255, 255, 255)
	love.graphics.translate(self.x, self.y)
	local key_info= key_config.get_section_info("menu")
	love.graphics.print(key_info[1].keys[1], close_menu_key_x, close_menu_y)
	love.graphics.print(key_info[1].name, close_menu_name_x, close_menu_y)
	local first_item= self.menu_offset
	local after_last_item= math.min(#self.top+1, first_item + items_per_page)
	local num_items= after_last_item - first_item
	for i= 0, num_items-1 do
		local item= self.top[i + first_item]
		local row_y= menu_start_y + (i * menu_row_spacing)
		local key= key_info[i + option_key_info_offset].keys[1]
		love.graphics.print(key, menu_item_key_x, row_y)
		love.graphics.print(item.name, menu_item_name_x, row_y)
		if item.value ~= nil then
			love.graphics.print("<", menu_adjust_down_x, row_y)
			love.graphics.print(">", menu_adjust_up_x, row_y)
			love.graphics.print(item.value, menu_item_value_x, row_y)
		end
	end
	local cursor_y= menu_start_y + ((self.cursor_offset+1) * menu_row_spacing) - 3
	love.graphics.push()
	local center_data= self.cursor_image.center
	love.graphics.translate(cursor_x - center_data.x, cursor_y - center_data.y)
	love.graphics.rotate(math.pi/2)
	love.graphics.draw(self.cursor_image.image, self.cursor_image.frames[self.cursor_sprite.curr_frame], -center_data.x, -center_data.y)
	love.graphics.pop()
	love.graphics.pop()
end

local function handle_func_call(self, row_info)
	if not row_info.func then return end
	local action, info= row_info.func(row_info.arg)
	if action == "close" then
		if type(info) ~= "number" then
			info= 1
		end
		self:close_level(info)
	elseif action == "refresh" then
		self.top= info
		self.menu_offset= max_clamp_menu_offset(self.top, self.menu_offset)
		self.cursor_offset= math.min(self.cursor_offset, #self.top - self.menu_offset)
	elseif action == "submenu" then
		self.stack[#self.stack+1]= {
			moff= self.menu_offset, coff= self.cursor_offset, menu= self.top}
		self.top= info
		self.menu_offset= 1
		self.cursor_offset= 0
	else
		-- do nothing
	end
end

local function handle_adjust_down(self, row_info)
	if not row_info.adjust_down then return end
	row_info.value= row_info.adjust_down(row_info.arg)
end

local function handle_adjust_up(self, row_info)
	if not row_info.adjust_up then return end
	row_info.value= row_info.adjust_up(row_info.arg)
end

local function mouse_y_to_row_id(y, min_row)
	return math.floor((y - menu_start_y) / menu_row_spacing)
end

local function mousemoved(self, x, y)
	local row_id= mouse_y_to_row_id(y - self.y)
	if row_id < 0 or row_id >= items_per_page then return end
	self.cursor_offset= math.min(row_id, #self.top - self.menu_offset)
end

local function mousepressed(self, x, y, button)
	if button ~= 1 then return end
	local row_id= mouse_y_to_row_id(y - self.y)
	if row_id < -1 or row_id > items_per_page then return end
	if row_id == -1 then
		self:close_level(1)
	else
		local row_info= self.top[row_id+self.menu_offset]
		if not row_info then return end
		if row_info.value == nil then
			self:handle_func_call(row_info)
		else
			if x < menu_adjust_down_x then
				self:handle_func_call(row_info)
			elseif x < menu_item_value_x then
				self:handle_adjust_down(row_info)
			elseif x >= menu_adjust_up_x and x < menu_adjust_up_x + 30 then
				self:handle_adjust_up(row_info)
			end
		end
	end
end

local function mousewheel(self, x, y)
	if y >= 1 then
		self.menu_offset= min_clamp_menu_offset(self.menu_offset - 1)
	elseif y <= 1 then
		self.menu_offset= max_clamp_menu_offset(self.top, self.menu_offset + 1)
	end
end

local function full_close(self)
	if self.on_close then
		self:on_close()
	else
		local info= self.stack[1]
		if info then
			self.top= info.menu
			self.menu_offset= info.moff
			self.cursor_offset= info.coff
			self.stack= {}
		end
	end
end

local function close_level(self, num)
	num= num or 1
	if num < 0 then
		self:full_close()
	else
		local new_top_index= #self.stack - num + 1
		if new_top_index < 1 then
			self:full_close()
		else
			local info= self.stack[new_top_index]
			self.top= info.menu
			self.menu_offset= info.moff
			self.cursor_offset= info.coff
			for i= #self.stack, new_top_index, -1 do
				table.remove(self.stack, i)
			end
		end
	end
end

local function page_up(self)
	self.menu_offset= min_clamp_menu_offset(self.menu_offset - items_per_page)
end

local function page_down(self)
	self.menu_offset= max_clamp_menu_offset(self.top, self.menu_offset + items_per_page)
end

local function choose_option(self, id)
	local row_info= self.top[id + self.menu_offset - 1]
	if not row_info then return end
	self:handle_func_call(row_info)
end

local function cursor_up(self)
	local cursor_abs_pos= self.menu_offset + self.cursor_offset
	if cursor_abs_pos <= 1 then
		self.menu_offset= max_clamp_menu_offset(#self.top)
		self.cursor_offset= #self.top - self.menu_offset
	else
		if self.cursor_offset <= 0 then
			self:page_up()
			self.cursor_offset= (cursor_abs_pos - 1) - self.menu_offset
		else
			self.cursor_offset= self.cursor_offset - 1
		end
	end
end

local function cursor_down(self)
	local cursor_abs_pos= self.menu_offset + self.cursor_offset
	if cursor_abs_pos >= #self.top then
		self.menu_offset= 1
		self.cursor_offset= 0
	else
		if self.cursor_offset >= items_per_page-1 then
			self:page_down()
			self.cursor_offset= (cursor_abs_pos + 1) - self.menu_offset
		else
			self.cursor_offset= self.cursor_offset + 1
		end
	end
end

local function adjust_up(self)
	local row_info= self.top[self.cursor_offset + self.menu_offset]
	if not row_info then return end
	self:handle_adjust_up(row_info)
end

local function adjust_down(self)
	local row_info= self.top[self.cursor_offset + self.menu_offset]
	if not row_info then return end
	self:handle_adjust_down(row_info)
end

local function action(self)
	local row_info= self.top[self.cursor_offset + self.menu_offset]
	if not row_info then return end
	self:handle_func_call(row_info)
end

local function create(menu_info, on_close, x, y)
	if not option_key_info_offset then
		local key_info= key_config.get_section_info("menu")
		for i= 1, #key_info do
			if key_info[i].name == "option_1" then
				option_key_info_offset= i
				break
			end
		end
	end
	return {
		x= x, y= y, top= menu_info, on_close= on_close,
		stack= {}, menu_offset= 1, cursor_offset= 0, cursor_image= images.player,
		cursor_sprite= sprite_oneesan.create_sprite(#images.player.frames, 1, .25),
		draw= draw, mousemoved= mousemoved, mousepressed= mousepressed,
		mousewheel= mousewheel, activate= activate, deactivate= deactivate,
		destroy= destroy, close_level= close_level, full_close= full_close,
		handle_func_call= handle_func_call, handle_adjust_up= handle_adjust_up,
		handle_adjust_down= handle_adjust_down, choose_option= choose_option,
		cursor_up= cursor_up, cursor_down= cursor_down, adjust_down= adjust_down,
		adjust_up= adjust_up, action= action, page_up= page_up,
		page_down= page_down,
	}
end

local function amw(func, arg)
	return function() func(active_menu, arg) end
end

key_config.register_section(
	"menu", {
		-- close must be the first entry because I don't feel like writing extra
		-- code to find it.
		{name= "close", keys= {"escape"}, release= amw(close_level)},
		{name= "page_up", keys= {"`"}, press= amw(page_up)},
		{name= "page_down", keys= {"tab"}, press= amw(page_down)},
		{name= "cursor_up", keys= {"up"}, press= amw(cursor_up)},
		{name= "cursor_down", keys= {"down"}, press= amw(cursor_down)},
		{name= "adjust_up", keys= {"right"}, press= amw(adjust_up)},
		{name= "adjust_down", keys= {"left"}, press= amw(adjust_down)},
		{name= "action", keys= {"return"}, press= amw(action)},
		-- option keys must be in order for prompts to be correct.
		{name= "option_1", keys= {"1"}, press= amw(choose_option, 1)},
		{name= "option_2", keys= {"2"}, press= amw(choose_option, 2)},
		{name= "option_3", keys= {"3"}, press= amw(choose_option, 3)},
		{name= "option_4", keys= {"4"}, press= amw(choose_option, 4)},
		{name= "option_5", keys= {"5"}, press= amw(choose_option, 5)},
		{name= "option_6", keys= {"q"}, press= amw(choose_option, 6)},
		{name= "option_7", keys= {"w"}, press= amw(choose_option, 7)},
		{name= "option_8", keys= {"e"}, press= amw(choose_option, 8)},
		{name= "option_9", keys= {"r"}, press= amw(choose_option, 9)},
		{name= "option_10", keys= {"t"}, press= amw(choose_option, 10)},
		{name= "option_11", keys= {"a"}, press= amw(choose_option, 11)},
		{name= "option_12", keys= {"s"}, press= amw(choose_option, 12)},
		{name= "option_13", keys= {"d"}, press= amw(choose_option, 12)},
		{name= "option_14", keys= {"f"}, press= amw(choose_option, 12)},
		{name= "option_15", keys= {"g"}, press= amw(choose_option, 12)},
		{name= "option_16", keys= {"z"}, press= amw(choose_option, 12)},
		{name= "option_17", keys= {"x"}, press= amw(choose_option, 12)},
		{name= "option_18", keys= {"c"}, press= amw(choose_option, 12)},
		{name= "option_19", keys= {"v"}, press= amw(choose_option, 12)},
		{name= "option_20", keys= {"b"}, press= amw(choose_option, 12)},
})

return {
	create= create,
}
