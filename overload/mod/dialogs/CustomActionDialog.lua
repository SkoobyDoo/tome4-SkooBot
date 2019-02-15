
require "engine.class"
require "engine.ui.Dialog"
local List = require "engine.ui.List"

module(..., package.seeall, class.inherit(engine.ui.Dialog))

function _M:init(title, optionlist)
	-- optionlist must be an object that contains a list of objects with the following properties:
	--		name - The text to be presented for a given option
	--		action - the function to be called when a given option is selected
	self.optionlist = optionlist
	self:generateList()
	print("[SkooBot] [CustomActionDialog] Custom Action Dialog init with title "..title)
	
	engine.ui.Dialog.init(self, title, 1, 1)

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

function _M:use(item)
	if not item then return end
	game:unregisterDialog(self)

	print("[SkooBot] [CustomActionDialog] Custom Action Dialog option selected: "..item.name)
	if (item.action) then item.action() end
end

function _M:generateList()
	local list = self.optionlist
	local chars = {}
	for i, v in ipairs(list) do
		v.name = self:makeKeyChar(i)..") "..v.name
		chars[self:makeKeyChar(i)] = i
	end
	list.chars = chars

	self.list = list
end
