local dimensions= require("dimensions")
local images= require("images")
local key_config= require("key_config")
local gameplay= require("gameplay")
local menu_test= require("menu_test")
local edit_mode= require("edit_mode")

local title_x= (dimensions.space_width - 126) * .5
local title_y= (dimensions.status_height + dimensions.space_height) * .05
local version_string= "1.0"
local version_x= title_x + 57
local version_y= title_y + 28
local info_start_y= version_y + 20
local info_height= dimensions.space_height * .75
local curr_info_index= 1
local info_entry_height= 30
local info_scroll_speed= -30
local info_offset= 0
local info_image_x= dimensions.space_width * .2
local info_text_x= dimensions.space_width * .3
local info_black_top_end_y= info_start_y
local info_black_bot_start_y= info_start_y + info_height

local prize_info= {}

local function preload()
	prize_info= {
		{images.prizes.pr_sing, "Small main weapon improvemnt"},
		{images.prizes.pr_doub, "Medium main weapon improvemnt"},
		{images.prizes.pr_trip, "Large main weapon improvemnt"},
		{images.prizes.pr_cluster_sing, "Small cluster weapon improvement"},
		{images.prizes.pr_cluster_doub, "Medium cluster weapon improvement"},
		{images.prizes.pr_cluster_trip, "Large cluster weapon improvement"},
		{images.prizes.pr_wave_sing, "Small wave weapon improvement"},
		{images.prizes.pr_wave_doub, "Medium wave weapon improvement"},
		{images.prizes.pr_wave_trip, "Large wave weapon improvement"},
		{images.prizes.pr_tree_sing, "Small tree weapon improvement"},
		{images.prizes.pr_tree_doub, "Medium tree weapon improvement"},
		{images.prizes.pr_tree_trip, "Large tree weapon improvement"},
		{images.prizes.pr_inc_cannon_spread, "Increases weapon spread"},
		{images.prizes.pr_dec_cannon_spread, "Decreases weapon spread"},
		{images.prizes.pr_speed, "Increases player speed"},
		{images.prizes.pr_shield, "Invulnerability"},
		{images.prizes.pr_safety_bubble, "Protection from one hit"},
		{images.prizes.pr_brain, "Hurts all aliens"},
		{images.prizes.pr_extrabullet, "Detroys all etorps"},
		{images.prizes.pr_wrap, "Increases range of torps"},
		{images.prizes.pr_inc_torp_speed, "Increases torp launch speed"},
		{images.prizes.pr_dec_torp_speed, "Decreases torp launch speed"},
		{images.prizes.pr_inc_prize_speed, "Increases prize fall speed"},
		{images.prizes.pr_dec_prize_speed, "Decreases prize fall speed"},
		{images.prizes.pr_blizzard1, "Emits a storm of torps"},
		{images.prizes.pr_blizzard2, "Thicker storm of torps"},
		{images.prizes.pr_changer, "Changes every second"},
		{images.prizes.pr_bonus_attractor, "Player attracts bonuses"},
		{images.prizes.pr_malus_attractor, "Player attracts maluses"},
		{images.prizes.pr_neutral_attractor, "Player attracts neutrals"},
		{images.prizes.pr_bonus_repulsor, "Player repulses bonuses"},
		{images.prizes.pr_malus_repulsor, "Player repulses maluses"},
		{images.prizes.pr_neutral_repulsor, "Player repulses neutrals"},
		{images.prizes.pr_bonus_destructor, "Destroys bonuses"},
		{images.prizes.pr_malus_destructor, "Destroys maluses"},
		{images.prizes.pr_neutral_destructor, "Destroys neutrals"},
		{images.prizes.pr_lemon, "Removes all loot"},
	}
end

local function update(delta)
	info_offset= info_offset + (info_scroll_speed * delta)
	local info_steps= -math.round((info_offset / info_entry_height) - .5)
	curr_info_index= curr_info_index + info_steps
	info_offset= info_offset + (info_entry_height * info_steps)
end

local function draw()
	for i= 1, (info_height / info_entry_height) + 2 do
		local entry= prize_info[((i + curr_info_index - 2) % #prize_info) + 1]
		local y= info_start_y + ((i-2) * info_entry_height) + info_offset
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(entry[1].image, entry[1].frames[1], info_image_x, y)
		love.graphics.setColor(240, 224, 0)
		love.graphics.print(entry[2], info_text_x, y)
	end
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", 0, 0, dimensions.space_width, info_black_top_end_y)
	love.graphics.rectangle("fill", 0, info_black_bot_start_y, dimensions.space_width, dimensions.space_height)

	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(images.title.image, images.title.frames[1], title_x, title_y)
	love.graphics.setColor(240, 224, 0)
	love.graphics.print(version_string, version_x, version_y)
end

local function pregame_begin()
	love.update= update
	love.draw= draw
	key_config.set_active_section("pregame")
end

key_config.register_section(
	"pregame", {
		{name= "exit", keys= {"escape"}, release= function() love.event.quit() end},
		{name= "scroll_down", keys= {"s"}, optional= true,
		 press= function() info_scroll_speed= 120 end,
		 release= function() info_scroll_speed= -30 end,
		},
		{name= "scroll_up", keys= {"w"}, optional= true,
		 press= function() info_scroll_speed= -120 end,
		 release= function() info_scroll_speed= -30 end,
		},
		{name= "key_config", keys= {"k"},
		 release= function() key_config.begin(pregame_begin) end,
		},
		{name= "play", keys= {"1"},
		 press= function() gameplay.begin(pregame_begin) end,
		},
		{name= "menu_test", keys= {"m"},
		 press= function() menu_test.begin(pregame_begin) end,
		},
		{name= "edit_mode", keys= {"e"},
		 press= function() edit_mode.begin(pregame_begin) end,
		},
})

return {
	begin= pregame_begin,
	preload= preload,
}
