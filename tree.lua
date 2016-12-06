local key_config= require("key_config")

local collapse_icon_w= 10
local per_level_indent= 10
local row_spacing= 20

-- Tree item example:
-- {
--   collapsed= true,
--   selected= false,
--   name= "foo",
--   sub_items= {},
--   info= {},
--   rename= function(name, info) end,
--   select= function(info) end,
--   unselect= function(info) end,
--   -- select and unselect should not return anything or change the state
--   -- of the tree.
-- }

-- Tree object:
-- {
--   x= x, y= y, -- Provided by creator.
--   top= tree item, -- Provided by creator.
--   display_offset= 1,
--   draw= function() end,
--   mousemoved= function() end,
--   mousepressed= function() end,
--   mousewheel= function() end,
--   activate= function() end,
--   deactivate= function() end,
--   destroy= function() end,
-- }

local function rec_build_render_items(
		first_row, curr_row, last_row, item, indent, render_items)
	local renitem= {name= item.name, indent= indent, item= item}
	if curr_row >= first_row then
		render_items[#render_items+1]= renitem
	end
	curr_row= curr_row + 1
	if item.sub_items then
		renitem.collapsed= not not item.collapsed
		if curr_row < last_row and not item.collapsed then
			for i= 1, #item.sub_items do
				curr_row= rec_build_render_items(
					first_row, curr_row, last_row, item.sub_items[i], indent+1, render_items)
				if curr_row >= last_row then return curr_row end
			end
		end
	end
	return curr_row
end

local function build_render_items(self)
	local num_rows= math.floor(self.h / row_spacing)
	local last_row= self.display_offset + num_rows
	local render_items= {}
	if self.top then
		rec_build_render_items(self.display_offset, 1, last_row, self.top, 0, render_items)
	end
	self.render_items= render_items
end

local function draw(self)
	if not self.top then return end
	love.graphics.push()
	love.graphics.setColor(255, 255, 255)
	love.graphics.translate(self.x, self.y)
	for i= 1, #self.render_items do
		local renitem= self.render_items[i]
		local y= (i-1) * row_spacing
		local x= renitem.indent * per_level_indent
		if renitem.collapsed then
			love.graphics.print("+", x, y)
		elseif renitem.collapsed == false then
			love.graphics.print("-", x, y)
		end
		love.graphics.print(renitem.name, x + collapse_icon_w, y)
	end
	love.graphics.pop()
end

local function mousemoved(self, x, y)
	
end

local function mousepressed(self, x, y, button)
	local row_id= math.floor((y-self.y) / row_spacing) + 1
	local renitem= self.render_items[row_id]
	if not renitem then return end
	if renitem.collapsed ~= nil then
		local collapse_left= renitem.indent * per_level_indent
		local collapse_right= collapse_left + collapse_icon_w
		if x >= collapse_left and x <= collapse_right then
			renitem.item.collapsed= not renitem.item.collapsed
			self:build_render_items()
		end
	end
end

local function mousewheel(self, x, y)
	if y >= 1 then
		self.display_offset= math.max(1, self.display_offset - 1)
	elseif y <= -1 then
		self.display_offset= self.display_offset + 1
	end
	self:build_render_items()
end

local function activate(self)
	self.active= true
	
end

local function deactivate(self)
	self.active= false
	
end

local function destroy(self)
	
end

local function create(x, y, w, h, info)
	local self= {
		x= x, y= y, w= w, h= h, top= info,
		display_offset= 1, build_render_items= build_render_items,
		draw= draw, mousemoved= mousemoved, mousepressed= mousepressed,
		mousewheel= mousewheel, activate= activate, deactivate= deactivate,
		destroy= destroy,
	}
	self:build_render_items()
	return self
end

return {
	create= create,
}
