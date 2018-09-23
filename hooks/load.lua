local KeyBind = require "engine.KeyBind"

class:bindHook("ToME:run", function(self, data)
	KeyBind:load("toggle-skoobot")
	game.key:addBinds {
		TOGGLE_SKOOBOT = function()
		    local Player = require "mod.class.Player"
		    game.log("#GOLD#SkooBot Toggle requested!")
			Player.skoobot_start()
		end
	}
end)













