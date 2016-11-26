local image_load_queue= {}
local images_table= {}

local function load_image_with_frames(path, num_frames)
	local entry= {image= love.graphics.newImage(path)}
	local frames= {}
	local width, height= entry.image:getDimensions()
	local frame_height= height / num_frames
	for fri= 1, num_frames do
		frames[fri]= love.graphics.newQuad(0, (fri-1) * frame_height, width, frame_height, width, height)
	end
	entry.frames= frames
	entry.center= {w= width, h= frame_height, x= width/2, y= frame_height/2}
	return entry
end

local alien_draw_data= {}
for i= 1, 17 do
	image_load_queue[#image_load_queue+1]= {
		path= "images/alien"..i..".png", frames= 16, dest= alien_draw_data}
end

local prize_names= {
	"pr_blizzard1",
	"pr_blizzard2",
	"pr_bonus_attractor",
	"pr_bonus_destructor",
	"pr_bonus_repulsor",
	"pr_brain",
	"pr_changer",
	"pr_cluster_doub",
	"pr_cluster_sing",
	"pr_cluster_trip",
	"pr_dec_cannon_spread",
	"pr_dec_prize_speed",
	"pr_dec_torp_speed",
	"pr_doub",
	"pr_extrabullet",
	"pr_inc_cannon_spread",
	"pr_inc_prize_speed",
	"pr_inc_torp_speed",
	"pr_lemon",
	"pr_malus_attractor",
	"pr_malus_destructor",
	"pr_malus_repulsor",
	"pr_neutral_attractor",
	"pr_neutral_destructor",
	"pr_neutral_repulsor",
	"pr_safety_bubble",
	"pr_shield",
	"pr_shoot_down_etorps",
	"pr_sing",
	"pr_speed",
	"pr_tree_doub",
	"pr_tree_sing",
	"pr_tree_trip",
	"pr_trip",
	"pr_wave_doub",
	"pr_wave_sing",
	"pr_wave_trip",
	"pr_wrap",
}
local prize_draw_data= {}
for pi= 1, #prize_names do
	image_load_queue[#image_load_queue+1]= {
		path= "images/"..prize_names[pi]..".png", frames= 1,
		dest= prize_draw_data, dest_index= prize_names[pi]}
end

for i, entry in ipairs{{"player", 4}, {"etorp", 8}, {"explosion", 5}} do
	image_load_queue[#image_load_queue+1]= {
		path= "images/"..entry[1]..".png", frames= entry[2],
		dest= images_table, dest_index= entry[1]
	}
end
for i, name in ipairs{
	"extra", "miniship", "mtorp", "pause", "s500", "s1000", "s2000", "s4000",
	"safety_bubble", "shield", "title"} do
	image_load_queue[#image_load_queue+1]= {
		path= "images/"..name..".png", frames= 1,
		dest= images_table, dest_index= name
	}
end


local next_image_load_id= 1
local function image_load_update()
	local queue_entry= image_load_queue[next_image_load_id]
	if queue_entry then
		local dest_index= queue_entry.dest_index or #queue_entry.dest+1
		queue_entry.dest[dest_index]=
			load_image_with_frames(queue_entry.path, queue_entry.frames)
		next_image_load_id= next_image_load_id + 1
		return next_image_load_id / #image_load_queue
	else
		return nil
	end
end

images_table.load_update= image_load_update
images_table.load_message= "Loading images"
images_table.aliens= alien_draw_data
images_table.prizes= prize_draw_data

return images_table
