-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009, 2010, 2011, 2012, 2013 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

defineAction{
	default = { "sym:_F1:false:false:true:false" },
	type = "TOGGLE_SKOOBOT",
	group = "actions",
	name = "Toggle SkooBot",
}

defineAction{
	default = { "sym:_F2:false:false:true:false" },
	type = "SKOOBOT_RUNONCE",
	group = "actions",
	name = "Run SkooBot Once",
}

defineAction{
	default = { "sym:_F3:false:false:true:false" },
	type = "ASK_SKOOBOT",
	group = "actions",
	name = "Ask SkooBot for action",
}