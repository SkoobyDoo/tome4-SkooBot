--================ HELPER FUNCTIONS ================--

-- THIS IS A HACK TO MAKE A MAX_INT
local MAX_INT = 2
while true do
    local nextstep = MAX_INT*2
    if (math.floor(nextstep) == nextstep) and (nextstep-1 ~= nextstep) then
        MAX_INT = nextstep
    else
        break
    end
end
-- END HACK

-- Absolute value
local function abs(n)
    if n < 0 then return -n end
    return n
end

local function checkConfig(str)
	return config.settings.tome.SkooBot and config.settings.tome.SkooBot[str]
end

-------------------------------------------------------
--================ VARIABLES ================--

local Astar = require "engine.Astar"
local Dialog = require "engine.ui.Dialog"
local Map = require "engine.Map"
local PlayerRest = require "engine.interface.PlayerRest"
local PlayerExplore = require "mod.class.interface.PlayerExplore"

local _M = loadPrevious(...)

local SAI_STATE_REST = 10
local SAI_STATE_EXPLORE = 11
local SAI_STATE_HUNT = 12
local SAI_STATE_FIGHT = 13

-- all skoobot data should be stored in this object on the player
_M.skoobot = {}

-- temporary values that need to stay on the player even between activations
_M.skoobot.tempvals = {}
_M.skoobot.tempvals.state = SAI_STATE_REST
_M.skoobot.tempvals.do_nothing = false
_M.skoobot.tempvals.countSuccessiveAutoExploreActions = 0

-- temporary values that should be recalculated from scratch each time the bot is turned on
_M.skoobot.tempActivationInit = function()
	local tempActivation = {}
	tempActivation.turnCount = 0
	tempActivation.unspentTotal = getUnspentTotal()
	return tempActivation
end
--_M.skoobot.tempActivation = _M.skoobot.tempActivationInit() // handled on hotkey press

-- temporary values that should be recalculated each time the bot loops
-- each turn Loop should get moved to PrevLoop
_M.skoobot.tempLoopInit = function()
	local loop = {}
	loop.thinkCount = 0
	loop.talentfailed = {}
	
	print("[Skoobot] [Survival]  Evaluating life change...")
	loop.delta = game.player.life - (_M.skoobot.tempPrevLoop and _M.skoobot.tempPrevLoop.life or game.player.life)
	loop.life = game.player.life
	if(abs(loop.delta) > 0) then
		print("[Skoobot] [Survival] Delta detected! = "..loop.delta)
	end
	if (loop.delta < 0) and ( abs(loop.delta) / game.player.max_life >= checkConfig("LOWHEALTH_RATIO") / 2) then
		if game.player:tryStop("LIFE_BIGLOSS", "#RED#AI Stopped: Lost more than "..math.floor(100*checkConfig("LOWHEALTH_RATIO")/2).."%% life in one turn!") then return end
	end
	return loop
end

-------------------------------------------------------

local function aiStateString()
    if _M.skoobot.tempvals.state == SAI_STATE_REST then
        return "SAI_STATE_REST"
    elseif _M.skoobot.tempvals.state == SAI_STATE_EXPLORE then
        return "SAI_STATE_EXPLORE"
    elseif _M.skoobot.tempvals.state == SAI_STATE_HUNT then
        return "SAI_STATE_HUNT"
    elseif _M.skoobot.tempvals.state == SAI_STATE_FIGHT then
        return "SAI_STATE_FIGHT"
    end
    return "Unknown State"
end

function aiStop(msg)
    _M.ai_active = false
    _M.skoobot.tempvals.state = SAI_STATE_REST
	_M.skoobot.tempActivation = nil
	_M.skoobot.tempLoop = nil
	_M.skoobot.tempPrevLoop = nil
    game.log((msg ~= nil and msg) or "#LIGHT_RED#AI Stopping!")
end

_M.checkStop = function(self, stopcategory, condition, msg)
--check condition (==true) to see if bot should stop.
--will check stoptype config to see if it is a WARN stoptype
--for warn stoptypes, will set flag if true, clear if false
	local stoptype = self:getStopCondition(stopcategory).stoptype
	
	if stoptype == "WARN" then
		if condition then
			-- make sure the warn memory object exists
			if not self.skoobotstopwarn then self.skoobotstopwarn = {} end
			-- if we've already acknowledged this, no need to stop
			if self.skoobotstopwarn[stopcategory] and self.skoobotstopwarn[stopcategory] == true then return false end
			-- new alert, mark that we've seen stopcategory and tryStop
			self.skoobotstopwarn[stopcategory] = true
			return self:tryStop(stopcategory, msg)
		else
			-- clear old alert, if applicable
			if self.skoobotstopwarn then self.skoobotstopwarn[stopcategory] = nil end
			return false
		end
	end
	
	-- not WARN, just check condition and execute tryStop if needed
	if condition then return self:tryStop(stopcategory, msg) end
	return false
end

_M.tryStop = function(self, stoptype, msg)
-- tries to stop the bot, returning true. if stoptype is set to IGNORED will disregard and return false
	--check if stoptype is IGNORED
	local stoptype = self:getStopCondition(stoptype).stoptype
	if stoptype == "IGNORE" then print("[Skoobot] [StopConditions] [HIGHLIGHT] Ignoring stop condition: "..stoptype) return false end
	
	aiStop(msg)
	return true
end

_M.getStopConditionList = function()
	if not game.player.skoobotstopconditions then game.player.skoobotstopconditions = {
		{label="Debuff: STUNNED", code="DEBUFF_STUNNED", stoptype="WARN"},
		{label="Debuff: CONFUSED", code="DEBUFF_CONFUSED", stoptype="WARN"},
		{label="Debuff: DAZED", code="DEBUFF_DAZED", stoptype="WARN"},
		{label="Debuff: FROZEN", code="DEBUFF_FROZEN", stoptype="WARN"},
		{label="Debuff: ASLEEP", code="DEBUFF_ASLEEP", stoptype="WARN"},
		
		{label="Life: BIGLOSS", code="LIFE_BIGLOSS", stoptype="WARN"},
		{label="Life: LOWLIFE", code="LIFE_LOWLIFE", stoptype="STOP"},
		
		{label="Dialog: LORE", code="DIALOG_LORE", stoptype="IGNORE"},
		
		{label="Power Level: ENEMYCOUNT", code="SCOUTER_ENEMYCOUNT", stoptype="STOP"},
		{label="Power Level: BIGENEMY", code="SCOUTER_BIGENEMY", stoptype="STOP"},
		{label="Power Level: STRONGERENEMY", code="SCOUTER_STRONGERENEMY", stoptype="STOP"},
		{label="Power Level: CROWDPOWER", code="SCOUTER_CROWDPOWER", stoptype="STOP"},
	} end
	return game.player.skoobotstopconditions
end

_M.getStopCondition = function(self, getcode)
	self:getStopConditionList() -- to ensure list exists
	for index,v in ipairs(game.player.skoobotstopconditions) do
		if v.code == getcode then return v, index end
	end
	print("[Skoobot] [StopConditions] [ERROR] Attempt to fetch nonexistent stop condition: "..getcode)
end

_M.setStopCondition = function(self, code, stoptype)
	local v,index = self:getStopCondition(code)
	game.player.skoobotstopconditions[index] = {label = v.label, code=code, stoptype=stoptype}
end

local function getDirNum(src, dst)
    local dx = dst.x - src.x
    if dx ~= 0 then dx = dx/dx end
    local dy = dst.y - src.y
    if dy ~= 0 then dy = dy/dy end
    return util.coordToDir(dx, dy)
end

local function validateRest(turns)
    if not turns or turns == 0 then
        game.log("#GOLD#AI Turns Rested: "..tostring(turns))
        -- TODO make sure this doesn't override damage taken
        _M.skoobot.tempvals.state = SAI_STATE_EXPLORE
        game.player.resting = nil
        game.player:act()
    end
    -- else do nothing
end

local function SAI_useTalent(tid, _a, _b, _c, target)
	if _M.skoobot.tempvals.do_nothing then
		game.log("[Skoobot] AI would use the talent "..game.player:getTalentFromId(tid).name.." on target "..(target and target.name or ""))
		return
	end
	print("[Skoobot] [Action] Using Talent "..game.player:getTalentFromId(tid).name.." on target "..(target and target.name or ""))
	return game.player:useTalent(tid, _a, _b, _c, target)
end

local function SAI_passTurn()
	if _M.skoobot.tempvals.do_nothing then
		game.log("[Skoobot] AI would pass a turn.")
		return
	end
	print("[Skoobot] [Action] Passing a turn.")
	game.player:useEnergy()
end

local function SAI_movePlayer(x, y)
	if _M.skoobot.tempvals.do_nothing then
		game.log("[Skoobot] AI would move to the "..game.level.map:compassDirection(x - game.player.x, y - game.player.y))
		return
	end
	print("[Skoobot] [Action] Moving to the "..game.level.map:compassDirection(x - game.player.x, y - game.player.y))
	return game.player:move(x, y)
end

local function SAI_beginExplore()
	if _M.skoobot.tempvals.do_nothing then
		game.log("[Skoobot] AI would begin exploring.")
		return
	end
	if _M.skoobot.tempvals.countSuccessiveAutoExploreActions > 100 then
		return aiStop("#RED#AI Stopped: autoExplore infinite cycle detected.")
	end
	print("[Skoobot] [Action] Beginning to explore.")
	_M.skoobot.tempvals.countSuccessiveAutoExploreActions = _M.skoobot.tempvals.countSuccessiveAutoExploreActions + 1
	game.player:autoExplore()
end

local function SAI_beginRest()
	if _M.skoobot.tempvals.do_nothing then
		game.log("[Skoobot] AI would begin resting.")
		return false
	end
	print("[Skoobot] [Action] Beginning to rest.")
	game.player:restInit(nil,nil,nil,nil,validateRest)
	return true
end

local function checkForDebuffs()
	if game.player:checkStop("DEBUFF_CONFUSED",
		game.player.confused == 1,
		"#RED#AI Stopped: Player is Confused!") then
		return true
	end
	if game.player:checkStop("DEBUFF_DAZED",
		game.player.dazed == 1,
		"#RED#AI Stopped: Player is Dazed!") then
		return true
	end
	if game.player:checkStop("DEBUFF_STUNNED",
		game.player.stunned == 1,
		"#RED#AI Stopped: Player is Stunned!") then
		return true
	end
	if game.player:checkStop("DEBUFF_FROZEN",
		game.player.frozen == 1,
		"#RED#AI Stopped: Player is Frozen!") then
		return true
	end
	if game.player:checkStop("DEBUFF_ASLEEP",
		game.player.sleep == 1 and not game.player.lucid_dreamer == 1,
		"#RED#AI Stopped: Player is Asleep!") then
		return true
	end
	return false
end

function checkForAdditionalAction()
	if game.player:enoughEnergy() and _M.ai_active then
		return skoobot_act(true)
	end
end

function getUnspentTotal()
	return game.player.unused_talents + game.player.unused_generics + game.player.unused_talents_types + game.player.unused_stats + game.player.unused_prodigies
end

local function spotHostiles(self, actors_only)
	local seen = {}
	if not self.x then return seen end

	-- Check for visible monsters, only see LOS actors, so telepathy wont prevent resting
	core.fov.calc_circle(self.x, self.y, game.level.map.w, game.level.map.h, self.sight or 10, function(_, x, y) return game.level.map:opaque(x, y) end, function(_, x, y)
		local actor = game.level.map(x, y, game.level.map.ACTOR)
		if actor and self:reactionToward(actor) < 0 and self:canSee(actor) and game.level.map.seens(x, y) then
			seen[#seen + 1] = {x=x,y=y,actor=actor, entity=actor, name=actor.name}
		end
	end, nil)
	
	game.player.skoobot.tempLoop.sumVisibleEnemyPower = 0
	game.player.skoobot.tempLoop.maxVisibleEnemyPower = 0
	game.player.skoobot.tempLoop.enemyCount = #seen
	for _,a in ipairs(seen) do
		local power = a.actor:evaluatePowerLevel()
		game.player.skoobot.tempLoop.sumVisibleEnemyPower = game.player.skoobot.tempLoop.sumVisibleEnemyPower + power
		if game.player.skoobot.tempLoop.maxVisibleEnemyPower < power then
			game.player.skoobot.tempLoop.maxVisibleEnemyPower = power
		end
	end

	if not actors_only then
		-- Check for projectiles in line of sight
		core.fov.calc_circle(self.x, self.y, game.level.map.w, game.level.map.h, self.sight or 10, function(_, x, y) return game.level.map:opaque(x, y) end, function(_, x, y)
			local proj = game.level.map(x, y, game.level.map.PROJECTILE)
			if not proj or not game.level.map.seens(x, y) then return end

			-- trust ourselves but not our friends
			if proj.src and self == proj.src then return end
			local sx, sy = proj.start_x, proj.start_y
			local tx, ty

			-- Bresenham is too so check if we're anywhere near the mathematical line of flight
			if type(proj.project) == "table" then
				tx, ty = proj.project.def.x, proj.project.def.y
			elseif proj.homing then
				tx, ty = proj.homing.target.x, proj.homing.target.y
			end
			if tx and ty then
				local dist_to_line = math.abs((self.x - sx) * (ty - sy) - (self.y - sy) * (tx - sx)) / core.fov.distance(sx, sy, tx, ty)
				local our_way = ((self.x - x) * (tx - x) + (self.y - y) * (ty - y)) > 0
				if our_way and dist_to_line < 1.0 then
					seen[#seen+1] = {x=x, y=y, projectile=proj, entity=proj, name=(proj.getName and proj:getName()) or proj.name}
				end
			end
		end, nil)
	end
	return seen
end

local function getPathToAir(self)
    local seen = {}
	if not self.x then return seen end

	-- Check for visible monsters, only see LOS actors, so telepathy wont prevent resting
	core.fov.calc_circle(self.x, self.y, game.level.map.w, game.level.map.h, self.sight or 10, function(_, x, y) return game.level.map:opaque(x, y) end, function(_, x, y)
		local terrain = game.level.map(x, y, game.level.map.TERRAIN)
		if not terrain.air_level or terrain.air_level > 0 then
		    seen[#seen+1] = {x=x, y=y, terrain=terrain}
		end
	end, nil)
	
	local min_dist = MAX_INT
	local close_coord = nil
	for i,coord in pairs(seen) do
	    local dist = abs(coord.x - self.x) + abs(coord.y - self.y)
	    if dist < min_dist then
	        min_dist = dist
	        close_coord = coord
	    end
	end
	
	if close_coord ~= nil then
    	local a = Astar.new(game.level.map, self)
        local path = a:calc(self.x, self.y, close_coord.x, close_coord.y)
	    return path
	end
	return nil
end

local function getNearestHostile()
    local seen = spotHostiles(game.player, true)
    
    local target = nil
	local targetdist = nil
    for index,enemy in pairs(seen) do
        if target == nil then
            target = enemy
			targetdist = core.fov.distance(game.player.x, game.player.y, enemy.x, enemy.y)
		else
			local nextdist = core.fov.distance(game.player.x, game.player.y, enemy.x, enemy.y)
			if nextdist < targetdist then
				targetdist = nextdist
				target = enemy
			end
        end
    end
	_M.skoobot_aiNearestHostileDistance = targetdist
    return target
end

local function getTalents()
	local talents = {}
	for k, v in pairs(game.player.talents) do
		talents[#talents+1] = k
	end
	return talents
end

local function getHotbarTalents(offset, count)
	local talents = {}
	for i=offset+1,offset+count do
		if game.player.hotkey[i] and game.player.hotkey[i][1] == "talent" then
			talents[#talents + 1] = game.player.hotkey[i][2]
		end
	end
	return talents
end

local function getAutoTalents(usetype)
--This function should grab the combat talents from skoobotautotalents[] where usetype=usetype
	local talents = {}
	game.player.pruneAutoTalents()
	if not game.player.skoobot or not game.player.skoobotautotalents then return talents end
	local tbl = {}
	for _,v in pairs(game.player.skoobotautotalents) do
		table.insert(tbl, v)
	end
	table.sort(tbl, function(a,b) return a.priority > b.priority end)
	
	for index,entry in ipairs(tbl) do
		if entry.usetype == usetype then
			talents[#talents + 1] = entry.tid
		end
	end
	return talents
end

_M.pruneAutoTalents = function()
-- this function should remove any autotalents that the player no longer has
	if not game.player.skoobotautotalents then return end
	local badindexes = {}
	for index, info in ipairs(game.player.skoobotautotalents) do
		local t = game.player:getTalentFromId(info.tid)
		if not game.player.talents[info.tid] then
			print("[SkooBot] [TalentList] [WARN] Attempt to fetch missing talent: "..info.tid)
			badindexes[#badindexes+1] = index
		end
	end
	for i = #badindexes, 1, -1 do
		table.remove(game.player.skoobotautotalents,badindexes[i])
	end
end

local function getCombatTalents()
--This function should grab the talents from skoobotautotalents[] where usetype=Combat
	return getAutoTalents("Combat")
end
_M.getCombatTalents = getCombatTalents;

local function getSustainableTalents()
--This function should grab the talents from skoobotautotalents[] where usetype=Sustain
	return getAutoTalents("Sustain")
end
_M.getSustainableTalents = getSustainableTalents;

local function getSustainTalents()
--This function should grab the talents from skoobotautotalents[] where usetype=DamagePrevention
	return getAutoTalents("DamagePrevention")
end
_M.getSustainTalents = getSustainTalents;

local function getRecoveryTalents()
--This function should grab the talents from skoobotautotalents[] where usetype=Recovery
	return getAutoTalents("Recovery")
end
_M.getRecoveryTalents = getRecoveryTalents;

-- TODO exclude enemies in LOS but not LOE (can't Rush over pits, but can see)
-- like when someone is standing in front of the target actor (with a non-piercing attack)?
local function getAvailableTalents(target, talentsToUse)
    local avail = {}
    local tx = nil
    local ty = nil
    local target_dist = nil
    if target ~= nil then
	    tx = target.x
	    ty = target.y
	    target_dist = core.fov.distance(game.player.x, game.player.y, tx, ty)
	end
	local theseTalents = talentsToUse or getTalents()
	for i,tid in pairs(theseTalents) do
		local t = game.player:getTalentFromId(tid)
		-- For dumb AI assume we need range and LOS
		-- No special check for bolts, etc.
		local total_range = (game.player:getTalentRange(t) or 0) + (game.player:getTalentRadius(t) or 0)
		local tg = {type=util.getval(t.direct_hit, game.player, t) and "hit" or "bolt", range=total_range}
		if t.mode == "activated" and not t.no_npc_use and not t.no_dumb_use and
		   not game.player:isTalentCoolingDown(t) and game.player:preUseTalent(t, true, true) and
		   (target ~= nil and not game.player:getTalentRequiresTarget(t) or game.player:canProject(tg, tx, ty))
		   then
			avail[#avail+1] = tid
			print("[Skoobot] [AvailableTalentFilter]", game.player.name, game.player.uid, "dumb ai talents can use", t.name, tid)
		elseif t.mode == "sustained" and not t.no_npc_use and not t.no_dumb_use and not game.player:isTalentCoolingDown(t) and
		   not game.player:isTalentActive(t.id) and
		   game.player:preUseTalent(t, true, true)
		   then
			avail[#avail+1] = tid
		else
			print("[Skoobot] [AvailableTalentFilter] Excluding talent: "..tid..", cannot be used on "..(target~=nil and target.name or "nil"))
		end
	end
	return avail
end

local function filterFailedTalents(t)
    local out = {}

    for k, v in pairs(t) do
		if not game.player:isTalentCoolingDown(game.player:getTalentFromId(v)) and _M.skoobot.tempLoop.talentfailed[v] == nil then
            out[#out + 1] = v
        end
    end

    return out
end

local old_postUseTalent = _M.postUseTalent
function _M:postUseTalent(talent, ret, silent)
    local result = old_postUseTalent(self, talent, ret, silent)
    if not result and self.skoobot.tempLoop then self.skoobot.tempLoop.talentfailed[talent.id] = true end
    return result
end

local function checkPowerLevel()
	local myPowerLevel = game.player:evaluatePowerLevel()
	if game.player:checkStop("SCOUTER_BIGENEMY",
		_M.skoobot.tempLoop.maxVisibleEnemyPower > checkConfig("MAX_INDIVIDUAL_POWER"),
		"Max enemy power level too high: ".._M.skoobot.tempLoop.maxVisibleEnemyPower) then
		return true
	end
	if game.player:checkStop("SCOUTER_STRONGERENEMY",
		_M.skoobot.tempLoop.maxVisibleEnemyPower > myPowerLevel + checkConfig("MAX_DIFF_POWER"),
		"Max enemy power level too much stronger than player: ".._M.skoobot.tempLoop.maxVisibleEnemyPower.." > "..myPowerLevel) then
		return true
	end
	if game.player:checkStop("SCOUTER_CROWDPOWER",
		_M.skoobot.tempLoop.sumVisibleEnemyPower > checkConfig("MAX_COMBINED_POWER"),
		"Combined enemy power level too high: ".._M.skoobot.tempLoop.sumVisibleEnemyPower) then
		return true
	end
	if game.player:checkStop("SCOUTER_ENEMYCOUNT",
		_M.skoobot.tempLoop.enemyCount > checkConfig("MAX_ENEMY_COUNT"),
		"Too many enemies in sight: ".._M.skoobot.tempLoop.enemyCount) then
		return true
	end
	return false
end

-- TODO add configurability, at least for Meditation
local function activateSustained()
-- returns true if anything was sustained, else returns false.
    local talents = filterFailedTalents(getSustainableTalents())
    for i,tid in pairs(talents) do
        local t = game.player:getTalentFromId(tid)
		print("[Skoobot] [Sustain] Attempting to sustain: "..tid)
        if t.mode == "sustained" and game.player.sustain_talents[tid] == nil then
            if(SAI_useTalent(tid)) then
				checkForAdditionalAction()
				return true
			end
        end
    end
	return false
end

local function getLowestHealthEnemy(enemySet)
    local low_mark = MAX_INT -- remember this value is a hack from above
    local target = nil
    for index, enemy in pairs(enemySet) do
        -- ENEMY is a table with { x, y, entity, name, actor }
        if enemy.actor.life < low_mark then
            low_mark = enemy.actor.life
            target = enemy
        end
    end
    return target
end

local function initLoopTempVars()
	_M.skoobot.tempPrevLoop = _M.skoobot.tempLoop or _M.skoobot.tempLoopInit()
	_M.skoobot.tempLoop = _M.skoobot.tempLoopInit()
end

function skoobot_act(noAction)
-- THIS FUNCTION CAUSES THE AI TO MAKE A SINGLE DECISION AND ACT UPON IT
-- IT CALLS ITSELF RECURSIVELY TO PROCEED TO THE NEXT ACTION
    if _M.skoobot.tempActivation == nil then
		-- this is a fresh run and should do a fresh start
		_M.skoobot.tempActivation = _M.skoobot.tempActivationInit()
		initLoopTempVars()
	end
	
	--while #game.dialogs > 0 do
	if #game.dialogs > 0 then
		if string.match(game.dialogs[#game.dialogs].title, "Lore found:") and game.dialogs[#game.dialogs].key.virtuals.EXIT then
			-- this is a lore dialog, check if player has configured to ignore
			if game.player:tryStop("DIALOG_LORE","#RED# Ai Stopped: Dialog shown on screen: "..game.dialogs[#game.dialogs].title) then
				print("[Skoobot] [HIGHLIGHT] tried to stop bot due to presence of dialog:", game.dialogs[#game.dialogs].title)
				return
			else
				print("[Skoobot] [HIGHLIGHT] unregistering dialog:", game.dialogs[#game.dialogs].title)
				game.dialogs[#game.dialogs].key.virtuals.EXIT()
			end
		else
			return aiStop("#RED# Ai Stopped: Dialog shown on screen: "..game.dialogs[#game.dialogs].title)
		end
	end
	
    local hostiles = spotHostiles(game.player, true)
    if #hostiles > 0 then
        if game.player:checkStop("LIFE_LOWLIFE", game.player.life < game.player.max_life * checkConfig("LOWHEALTH_RATIO"), "#RED#AI cancelled for low health") then return end
        _M.skoobot.tempvals.state = SAI_STATE_FIGHT
    end
	
	if checkPowerLevel() then
		return
	end
	
	if checkForDebuffs() then
		return
	end
	
	if _M.skoobot.tempActivation.unspentTotal ~= getUnspentTotal() then
		return aiStop("#RED#AI Stopped: Unspent points changed!")
	end
	
	if _M.skoobot.tempLoop == nil or (not noAction) then
		initLoopTempVars()
		if _M.skoobot.tempActivation == nil then
			-- triggered a delta health alert and stopped ai
			return
		end
	end
	
	_M.skoobot.tempLoop.thinkCount = _M.skoobot.tempLoop.thinkCount + 1
	if _M.skoobot.tempLoop.thinkCount > 25 then
		return aiStop("#LIGHT_RED#AI Stopped: Number of attempts to calculate action exceeded maximum!")
	end
    
    if activateSustained() then
		return
	end
    
    print("[Skoobot] [State] "..aiStateString())
    
	if _M.skoobot.tempvals.state ~= SAI_STATE_EXPLORE then
		_M.skoobot.tempvals.countSuccessiveAutoExploreActions = 0
	end

	if _M.skoobot.tempvals.state == SAI_STATE_STOP then
		return
    elseif _M.skoobot.tempvals.state == SAI_STATE_REST then
		if game.player.air < 50 then
			return aiStop("#RED#AI stopped: Attempting to rest while under half breath!")
		end
        local terrain = game.level.map(game.player.x, game.player.y, game.level.map.TERRAIN)
        if terrain.air_level and terrain.air_level < 0 and not game.player.undead == 1 then
            -- run to air
            local path = getPathToAir(game.player)
            if path ~= nil then
                local moved = SAI_movePlayer(path[1].x, path[1].y)
            end
            
            if not moved and _M.ai_active then
                return aiStop("#RED#AI stopped: Suffocating, no air in sight!")
			else
				checkForAdditionalAction()
				return
            end
        end
        return SAI_beginRest()
    elseif _M.skoobot.tempvals.state == SAI_STATE_EXPLORE then
		if _M.skoobot.tempLoop.delta < 0 then
			if #hostiles > 0 then
				_M.skoobot.tempvals.state = SAI_STATE_FIGHT
				return skoobot_act(true)
			else
				aiStop("#RED#AI stopped: took damage while exploring!")
			end
		end
        if game.player.air < 75 then
            _M.skoobot.tempvals.state = SAI_STATE_REST
            return skoobot_act(true)
        end
        if game.level.map:checkEntity(game.player.x, game.player.y, engine.Map.TERRAIN, "change_level") then
            aiStop("#GOLD#AI stopping: level change found")
        end
        SAI_beginExplore()
        return
        
    elseif _M.skoobot.tempvals.state == SAI_STATE_HUNT then
        -- TODO figure out how to hook takeHit() to get here
        -- then figure out if we can target the damage source
        -- or we have to randomwalk/flee
        
        -- for now:
        _M.skoobot.tempvals.state = SAI_STATE_EXPLORE
        return skoobot_act(true)
    
    elseif _M.skoobot.tempvals.state == SAI_STATE_FIGHT then
        local targets = {}
        for index, enemy in pairs(hostiles) do
            -- attacking is a talent, so we don't need to add it as a choice
            if filterFailedTalents(getAvailableTalents(enemy)) then
                --enemy in range! Add them to possible target queue
                table.insert(targets, enemy)
            end
        end
		
		local combatTalents = filterFailedTalents(getCombatTalents())
		
		if #combatTalents > 0 then
			local targets = {getLowestHealthEnemy(targets), getNearestHostile()}
			if #targets == 0 then
				-- no enemies left in sight! fight's over
				-- TODO OR WE'RE BLIND!!!!!!! this edge case will likely resolve itself once HUNT works.
				_M.skoobot.tempvals.state = SAI_STATE_REST
				return skoobot_act(true)
			end
			
			if (_M.skoobot.tempLoop.delta < 0) and ( abs(_M.skoobot.tempLoop.delta) / game.player.max_life >= checkConfig("LOWHEALTH_RATIO") / 4) then
				talents = filterFailedTalents(getSustainTalents())
				if #talents > 0 then
					print("[Skoobot] [Survival] [Sustain] using sustain, lost more than "..math.floor(100*checkConfig("LOWHEALTH_RATIO")/4).."% life in one turn!")
					SAI_useTalent(talents[1])
					checkForAdditionalAction()
					return
				else
					print("[Skoobot] [Survival] [Sustain] Lost more than "..math.floor(100*checkConfig("LOWHEALTH_RATIO")/4).."% life, but no sustain off cooldown!")
				end
			end
			
			if (game.player.life / game.player.max_life <= 1 - checkConfig("LOWHEALTH_RATIO") / 4) then
				talents = filterFailedTalents(getRecoveryTalents())
				if #talents > 0 then
					print("[Skoobot] [Survival] [Recovery] using recovery, missing more than "..math.floor(100*checkConfig("LOWHEALTH_RATIO")/4).."% life...")
					SAI_useTalent(talents[1])
					checkForAdditionalAction()
					return
				else
					print("[Skoobot] [Survival] [Recovery] Missing more than "..math.floor(100*checkConfig("LOWHEALTH_RATIO")/4).."% life, but no recovery off cooldown!")
				end
			end
			
			for i,enemy in pairs(targets) do
				print("[Skoobot] [Combat] Target selected: "..enemy.name)
				local talents = getAvailableTalents(enemy, combatTalents)
				talents = filterFailedTalents(talents)
				local tid = talents[1]
				if tid ~= nil then
					print("[Skoobot] [Combat] Using talent: "..tid.." on target "..enemy.name)
					game.player:setTarget(enemy.actor)
					SAI_useTalent(tid,nil,nil,nil,enemy.actor)
					checkForAdditionalAction()
					return
				end
			end
			
			-- no legal target! let's get closer
			local a = Astar.new(game.level.map, game.player)
			local path = a:calc(game.player.x, game.player.y, targets[1].x, targets[1].y)
			print("[Skoobot] [Combat] [Movement] Pathing towards "..targets[1].name)
			local dir = getDirNum(game.player, targets[1])
			local moved = false
			
			if not path then
				--game.log("#RED#[Skoobot] [Combat] Path not found, trying beeline")
				--moved = game.player:attackOrMoveDir(dir)
				return aiStop("#RED#[Skoobot] [Combat] [Movement] AI stopped: Unable to calcuate path to nearest enemy!")
			else
				--game.log("#GREEN#move via path")
				local moved = SAI_movePlayer(path[1].x, path[1].y)
				if not moved and not _M.skoobot.tempvals.do_nothing then
					--game.log("#RED#[Skoobot] [Combat] Normal movement failed, trying beeline")
					--moved = game.player:attackOrMoveDir(dir)
					return aiStop("#RED#[Skoobot] [Combat] [Movement] AI stopped: Movement along path to nearest enemy failed!")
				end
				checkForAdditionalAction()
				return
			end
			if not moved then
				-- Maybe we're pinned and can't move?
				SAI_passTurn()
				return
			end
		else
			-- everything is on cooldown, what do?
			-- pass a turn!
			print("[Skoobot] [Combat] All Combat talents on cooldown. Waiting.")
			return aiStop("#RED#[Skoobot] [Combat] [Movement] All Combat talents on cooldown!\nHave you configured talent usage? (Shift+F2 by default)")
		end
		
		
		-- for now just end the ai if we have nothing usable, will diagnose as this occurs
		return aiStop("#RED#[Skoobot] [Combat] AI stopping: AI was unable to take a combat action (movement/talent)")
    end
end

function _M:skoobot_start()
-- THIS FUNCTION IS TRIGGERED BY THE KEYBIND FOR THE AI.
-- THIS IS WHERE THE AI BEGINS RUNNING, OR STOPS RUNNING
    if _M.ai_active == true then
        return aiStop("#GOLD#Disabling Player AI!")
    end
    if game.zone.wilderness then
        return aiStop("#RED#Player AI cannot be used in the wilderness!")
    end
	
    _M.ai_active = true
    
    skoobot_act()
end

function _M:skoobot_query()
-- THIS FUNCTION IS TRIGGERED BY THE KEYBIND FOR THE AI.
-- THIS IS WHERE THE AI BEGINS RUNNING, OR STOPS RUNNING
    if _M.ai_active == true then
        return game.log("Cannot query while SkooBot is active!")
    end
    if game.zone.wilderness then
        return aiStop("#RED#SkooBot cannot be used in the wilderness!")
    end
	
	_M.skoobot.tempvals.do_nothing = true
    skoobot_act()
	_M.skoobot.tempvals.do_nothing = nil
end

function _M:skoobot_runonce()
-- THIS FUNCTION IS TRIGGERED BY THE KEYBIND FOR THE AI.
-- THIS IS WHERE THE AI BEGINS RUNNING, OR STOPS RUNNING
    if _M.ai_active == true then
        return game.log("Cannot runonce while SkooBot is active!")
    end
    if game.zone.wilderness then
        return aiStop("#RED#SkooBot cannot be used in the wilderness!")
    end
	
	_M.skoobot.tempvals.runonce = true
    skoobot_act()
	_M.skoobot.tempvals.runonce = nil
end

_M.playerActions = function()
	if (not game.player.running) and (not game.player.resting) and _M.ai_active then
		if not game.player:enoughEnergy() then
			print("[WARN] [Skoobot] [Bugfix] Player act called with insufficient energy for action. Returning.")
			return
		end
		if game.zone.wilderness then
			aiStop("#RED#Player AI cancelled by wilderness zone!")
			return ret
		end
		skoobot_act()
		if _M.skoobot.tempActivation then
			_M.skoobot.tempActivation.turnCount = _M.skoobot.tempActivation.turnCount + 1
			print("[Skoobot] Player Act Number ".._M.skoobot.tempActivation.turnCount)
			if _M.skoobot.tempActivation.turnCount > 1000 then
				aiStop("#LIGHT_RED#AI Disabled. AI acted for 1000 turns. Did it get stuck?")
			end
		end
	end
	if not _M.ai_active and not _M.skoobot.tempvals.runonce then
		_M.skoobot.tempActivation = nil
		_M.skoobot.tempLoop = nil
		_M.skoobot.tempPrevLoop = nil
	end
	if checkConfig("ACTION_DELAY") ~= 0 then
		_M:act()
	end
end

local old_act = _M.act
function _M:act()
    local ret = old_act(game.player)
	if checkConfig("ACTION_DELAY") == 0 then
		_M:playerActions()
	else
		game:registerTimer(checkConfig("ACTION_DELAY"), function()
			_M:playerActions()
		end)
	end
    return ret
end

return _M