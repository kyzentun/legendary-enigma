local dimensions= require("dimensions")

function love.conf(t)
	t.identity = "legendary-enigma"
	t.version = "0.10.1"
	t.console = false
	t.accelerometerjoystick = false
	t.externalstorage = false

	t.window.title = "Galagag"
	t.window.icon = nil
	t.window.width = dimensions.space_width
	t.window.height = dimensions.window_height
	t.window.resizable = false
	t.window.minwidth = t.window.width
	t.window.minheight = t.window.height
	t.window.fullscreen = false

	t.modules.audio = false
	t.modules.image = true
	t.modules.joystick = true
	t.modules.keyboard = true
	t.modules.math = true
	t.modules.mouse = true
	t.modules.physics = false
	t.modules.sound = false
	t.modules.system = true
	t.modules.timer = true
	t.modules.touch = true
	t.modules.video = true
	t.modules.window = true
	t.modules.thread = true
end
