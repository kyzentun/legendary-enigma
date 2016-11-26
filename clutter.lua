local function fill(clutter, obj_set)
	clutter.obj_rows= {}
	local ow_rec= clutter.ow_rec
	local oh_rec= clutter.oh_rec
	local obj_rows= clutter.obj_rows
	for o= 1, #obj_set do
		local obj= obj_set[o]
		local ent= obj.entity
		local row_id= math.floor(ent.y * oh_rec)
		local col_id= math.floor(ent.x * ow_rec)
		local row= obj_rows[row_id]
		if row then
			local col= row[col_id]
			if col then
				col[#col+1]= obj
			else
				row[col_id]= {obj}
			end
		else
			obj_rows[row_id]= {[col_id]= {obj}}
		end
	end
end

local function clear(clutter)
	clutter.obj_rows= {}
end

local function sectorize_range(start, finish, max)
	local ret= {}
	if start < 0 then
		return {{0, finish}, {start + max, max}}
	elseif finish > max then
		return {{0, finish - max}, {start, max}}
	else
		return {{start, finish}}
	end
end

local function find_collisions(clutter, curr_time, ent)
	local ow_rec= clutter.ow_rec
	local oh_rec= clutter.oh_rec
	local obj_rows= clutter.obj_rows
	local ent_left= ent.x - (ent.w * .5)
	local ent_right= ent.x + (ent.w * .5)
	local ent_top= ent.y - (ent.h * .5)
	local ent_bottom= ent.y + (ent.h * .5)
	-- space wraps toroidally
	local row_sectors= sectorize_range(
		math.floor(ent_top * oh_rec) - 1, math.floor(ent_bottom * oh_rec) + 1,
		clutter.max_row_id)
	local col_sectors= sectorize_range(
		math.floor(ent_left * ow_rec) - 1, math.floor(ent_right * ow_rec) + 1,
		clutter.max_col_id)
	local collision_list= {}
	for rs= 1, #row_sectors do
		local row_start= row_sectors[rs][1]
		local row_end= row_sectors[rs][2]
		for ri= row_start, row_end do
			local row= obj_rows[ri]
			if row then
				for cs= 1, #col_sectors do
					local col_start= col_sectors[cs][1]
					local col_end= col_sectors[cs][2]
					for ci= col_start, col_end do
						local col= row[ci]
						if col then
							if ri > row_start and ri < row_end and
							ci > col_start and ci < col_end then
								-- sector entirely inside entity, hit everything
								for oi= 1, #col do
									if col[oi].death_time > curr_time then
										collision_list[#collision_list+1]= col[oi]
									end
								end
							else
								for oi= 1, #col do
									if col[oi].death_time > curr_time then
										local obj= col[oi].entity
										local obj_left= obj.x - (obj.w * .5)
										local obj_right= obj.x + (obj.w * .5)
										local obj_top= obj.y - (obj.h * .5)
										local obj_bottom= obj.y + (obj.h * .5)
										if ent_right >= obj_left and ent_left <= obj_right and
										ent_bottom >= obj_top and ent_top <= obj_bottom then
											collision_list[#collision_list+1]= col[oi]
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return collision_list
end

local function create_clutter(space_width, space_height, obj_width, obj_height)
	return {
		space_width= space_width, space_height= space_height,
		obj_width= obj_width, obj_height= obj_height,
		ow_rec= 1 / obj_width, oh_rec= 1 / obj_height,
		max_row_id= math.floor(space_height / obj_height),
		max_col_id= math.floor(space_width / obj_width),
		obj_rows= {},
		fill= fill, clear= clear, find_collisions= find_collisions,
	}
end

return {
	create_clutter= create_clutter,
}
