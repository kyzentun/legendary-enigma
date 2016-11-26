-- Saving all configuration and data as lua saves me the trouble of writing a
-- parser.  Consider: In loading a data file there are two primary steps:
-- 1. Load the data into a structure.  2. Verify the consistency (sanity).
-- Lua provides a simple, robust solution for step 1.  Less code, less bugs.

local savable_types= {
	bool= true,
	number= true,
	string= true,
	table= true,
}

local function string_needs_escape(str)
	if str:match("^[a-zA-Z_][a-zA-Z_0-9]*$") then
		return false
	else
		return true
	end
end

local function parts_longer_than_limit(parts, limit)
	local total= 0
	for i= 1, #parts do
		total= total + #parts[i]
		if total > limit then return true end
	end
	return false
end

local function lua_table_to_string(tab, indent, line_pos)
	indent= indent or ""
	line_pos= (line_pos or #indent) + 1
	local internal_indent= indent .. "  "
	local ret_parts= {}
	local has_table= false
	local function do_value_for_key(key, value, need_key_str)
		if type(value) == "nil" then return end
		local key_type= type(key)
		local key_str= key
		if need_key_str then
			if key_type == "number" then
				key_str= "["..key.."]"
			elseif key_str == "boolean" then
				key_str= "["..tostring(key).."]"
			else
				if string_needs_escape(key) then
					key_str= "[" .. ("%q"):format(key) .. "]"
				else
					key_str= key
				end
			end
			key_str= key_str .. "= "
		else
			key_str= ""
		end
		local value_str= ""
		local value_type= type(value)
		if value_type == "table" then
			value_str= lua_table_to_string(value, internal_indent, line_pos + #key_str)
		elseif value_type == "string" then
			value_str= ("%q"):format(value)
		elseif value_type == "number" then
			if value ~= math.floor(value) then
				value_str= ("%.6f"):format(value)
				local last_nonz= value_str:reverse():find("[^0]")
				if last_nonz then
					value_str= value_str:sub(1, -last_nonz)
				end
			else
				value_str= tostring(value)
			end
		else
			value_str= tostring(value)
		end
		ret_parts[#ret_parts+1]= key_str .. value_str
	end
	if tab.sorted_fields then
		for i= 1, #tab.sorted_fields do
			local key= tab.sorted_fields[i]
			do_value_for_key(key, tab[key], true)
		end
	else
		local non_array_number_keys= {}
		local named_keys= {}
		for key, value in pairs(tab) do
			local key_type= type(key)
			local value_type= type(value)
			if savable_types[key_type] and savable_types[value_type] then
				if not has_table and type(value) == "table" then has_table= true end
				if key_type == "number" then
					if key <= 0 or key > #tab or math.abs(key - math.floor(key)) >= .001 then
						non_array_number_keys[#non_array_number_keys+1]= key
					end
				elseif key_type == "string" then
					named_keys[#named_keys+1]= key
				end
			end
		end
		for i= 1, #tab do
			local value= tab[i]
			if value == nil then
				ret_parts[#ret_parts+1]= "nil"
			else
				do_value_for_key(i, value, false)
			end
		end
		for i= 1, #non_array_number_keys do
			local key= non_array_number_keys[i]
			do_value_for_key(key, tab[key], true)
		end
		for i= 1, #named_keys do
			local key= named_keys[i]
			do_value_for_key(key, tab[key], true)
		end
	end
	if parts_longer_than_limit(ret_parts, 80 - #indent) then
		return "{\n" .. internal_indent ..
			table.concat(ret_parts, ",\n"..internal_indent) .. "\n" ..
			internal_indent .. "}"
	else
		return "{" .. table.concat(ret_parts, ", ") .. "}"
	end
end

local recent_log= ""

return {
	load_save_file= function(path, get_blank, sanity)
		if love.filesystem.exists(path) then
			local success, chunk, errormsg= pcall(love.filesystem.load, path)
			if success then
				if chunk then
					setfenv(chunk, {})
					local success, data= pcall(chunk)
					if success then
						local sane, message= sanity(data)
						if sane then
							return data
						else
							return get_blank(), path .. " validity error: " .. message
						end
					else
						return get_blank(), path .. " load error: " .. errormsg
					end
				else
					return get_blank(), path .. " read error: " .. chunk
				end
			else
				return get_blank(), path .. " parse error: " .. chunk
			end
		else
			return get_blank()
		end
	end,
	write_save_file= function(path, data)
		local str= "return " .. lua_table_to_string(data)
		local in_file= love.filesystem.newFileData(str, path)
		if not love.filesystem.write(path, in_file) then
			return false, "Save failed"
		end
	end,
	log_table= function(name, tab)
		print(name)
		print(lua_table_to_string(tab, "  "))
	end,
	log= function(message)
		recent_log= message
		print(message)
	end,
	get_recent_log= function()
		return recent_log
	end,
}
