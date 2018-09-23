local KeyBind = require "engine.KeyBind"


class:bindHook("ToME:run", function(self, data)
	KeyBind:load("toggle-skoobot")
	game.key:addBinds {
		TOGGLE_PLAYER_AI = function()
		    local Player = require "mod.class.Player"
		    game.log("#GOLD#SkooBot Toggle requested!")
			--Player.player_ai_start()
		end
	}
end)













