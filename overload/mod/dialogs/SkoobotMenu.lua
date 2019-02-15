
require "engine.class"
require "engine.ui.Dialog"
local List = require "engine.ui.List"

module(..., package.seeall, class.inherit(engine.ui.Dialog))

function _M:init()
	self:generateList()
	engine.ui.Dialog.init(self, "SkooBot Menu", 1, 1)

	local list = List.new{width=400, nb_items=#self.list, list=self.list, fct=function(item) self:use(item) end}

	self:loadUI{
		{left=0, top=0, ui=list},
	}
	self:setupUI(true, true)

	self.key:addCommands{ __TEXTINPUT = function(c) if self.list and self.list.chars[c] then self:use(self.list[self.list.chars[c]]) end end}
	self.key:addBinds{ EXIT = function() game:unregisterDialog(self) end, }
end

function _M:on_register()
	game:onTickEnd(function() self.key:unicodeInput(true) end)
end

local menuActions = {
	skillconfig = function()
		print("[SkooBot] [Menu] skillconfig menu action chosen.")
		local d = require("mod.dialogs.BotTalentDialog").new(game.player)
		
		game:registerDialog(d)
	end
}

function _M:use(item)
	if not item then return end
	game:unregisterDialog(self)
	print("[SkooBot] [Menu] Menu option chosen: '"..item.name.."'	with order code: "..item.order)
	
	if (menuActions[item.order]) then menuActions[item.order]() end
end

function _M:generateList()
	local list = {
		{1,name="Set Skill Usage",order="skillconfig"},
		{2,name="Cancel",order="donothing"}
	}

	local chars = {}
	for i, v in ipairs(list) do
		v.name = self:makeKeyChar(i)..") "..v.name
		chars[self:makeKeyChar(i)] = i
	end
	list.chars = chars

	self.list = list
end
