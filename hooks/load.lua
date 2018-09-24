local KeyBind = require "engine.KeyBind"

class:bindHook("ToME:run", function(self, data)
	KeyBind:load("toggle-skoobot")
	game.key:addBinds {
		TOGGLE_SKOOBOT = function()
		    local Player = require "mod.class.Player"
		    game.log("#GOLD#SkooBot Toggle requested!")
			Player.skoobot_start()
		end,
		SKOOBOT_RUNONCE = function()
		    local Player = require "mod.class.Player"
		    game.log("#GOLD#SkooBot Toggle requested!")
			Player.skoobot_runonce()
		end,
		ASK_SKOOBOT = function()
		    local Player = require "mod.class.Player"
		    game.log("#GOLD#SkooBot Query requested!")
			Player.skoobot_query()
		end
	}
end)













