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

_M.skoobot_ai_state = SAI_STATE_REST
_M.skoobot_aiTurnCount = 0

local SAI_LOWHEALTH_RATIO = 0.50
local SAI_DO_NOTHING = false

_M.AI_talentfailed = {}

-------------------------------------------------------

local function aiStateString()
    if _M.skoobot_ai_state == SAI_STATE_REST then
        return "SAI_STATE_REST"
    elseif _M.skoobot_ai_state == SAI_STATE_EXPLORE then
        return "SAI_STATE_EXPLORE"
    elseif _M.skoobot_ai_state == SAI_STATE_HUNT then
        return "SAI_STATE_HUNT"
    elseif _M.skoobot_ai_state == SAI_STATE_FIGHT then
        return "SAI_STATE_FIGHT"
    end
    return "Unknown State"
end

local function aiStop(msg)
    _M.ai_active = false
    _M.skoobot_ai_state = SAI_STATE_REST
    _M.skoobot_aiTurnCount = 0
    game.log((msg ~= nil and msg) or "#LIGHT_RED#AI Stopping!")
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
        _M.skoobot_ai_state = SAI_STATE_EXPLORE
        game.player.resting = nil
        game.player:act()
    end
    -- else do nothing
end

local function SAI_useTalent(tid, _a, _b, _c, target)
	if SAI_DO_NOTHING then
		game.log("[Skoobai] AI would use the talent "..game.player:getTalentFromId(tid).name..(target and target.name or ""))
		return
	end
	return game.player:useTalent(tid, _a, _b, _c, target)
end

local function SAI_passTurn()
	if SAI_DO_NOTHING then
		game.log("[Skoobai] AI would pass a turn.")
		return
	end
	game.player:useEnergy()
end

local function SAI_movePlayer(x, y)
	if SAI_DO_NOTHING then
		game.log("[Skoobai] AI would move to the "..game.level.map:compassDirection(x - game.player.x, y - game.player.y))
		return
	end
	return game.player:move(x, y)
end

local function SAI_beginExplore()
	if SAI_DO_NOTHING then
		game.log("[Skoobai] AI would begin exploring.")
		return
	end
	game.player:autoExplore()
end

local function SAI_beginRest()
	if SAI_DO_NOTHING then
		game.log("[Skoobai] AI would begin resting.")
		return false
	end
	game.player:restInit(nil,nil,nil,nil,validateRest)
	return true
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

local function getCombatTalents()
--This function should grab the talents from the hotbar intended for combat
-- at time of writing that should be the talents in 1,2,3..0 in order
	local hotkeys = { game.player.hotkey[10], game.player.hotkey[9], game.player.hotkey[8], game.player.hotkey[7], game.player.hotkey[6], game.player.hotkey[5], game.player.hotkey[4], game.player.hotkey[3], game.player.hotkey[2], game.player.hotkey[1] };
	local combatTalents = {}
	for k, v in pairs(hotkeys) do
		combatTalents[#combatTalents + 1] = v[2]
	end
	return combatTalents
end
_M.getCombatTalents = getCombatTalents;

local function getSustainableTalents()
--This function should grab the talents from the hotbar intended for combat
-- at time of writing that should be the talents in A1,A2,A3..A0 in order
	local offset = 36
	local hotkeys = { game.player.hotkey[10+offset], game.player.hotkey[9+offset], game.player.hotkey[8+offset], game.player.hotkey[7+offset], game.player.hotkey[6+offset], game.player.hotkey[5+offset], game.player.hotkey[4+offset], game.player.hotkey[3+offset], game.player.hotkey[2+offset], game.player.hotkey[1+offset] };
	local sustainableTalents = {}
	for k, v in pairs(hotkeys) do
		sustainableTalents[#sustainableTalents + 1] = v[2]
	end
	return sustainableTalents
end
_M.getSustainableTalents = getSustainableTalents;

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
	if(talentsToUse ~= nil) then
		print("[Skoobot] getting available talents with these to use:")
		table.print(talentsToUse)
	end
	local theseTalents = talentsToUse or getTalents()
	for i,tid in pairs(theseTalents) do
		local t = game.player:getTalentFromId(tid)
		-- For dumb AI assume we need range and LOS
		-- No special check for bolts, etc.
		local total_range = (game.player:getTalentRange(t) or 0) + (game.player:getTalentRadius(t) or 0)
		local tg = {type=util.getval(t.direct_hit, game.player, t) and "hit" or "bolt", range=total_range}
		--print(tid.." tg = ")
		--table.print(tg)
		if t.mode == "activated" and not t.no_npc_use and not t.no_dumb_use and
		   not game.player:isTalentCoolingDown(t) and game.player:preUseTalent(t, true, true) and
		   (target ~= nil and not game.player:getTalentRequiresTarget(t) or game.player:canProject(tg, tx, ty))
		   then
			avail[#avail+1] = tid
			print(game.player.name, game.player.uid, "dumb ai talents can use", t.name, tid)
		elseif t.mode == "sustained" and not t.no_npc_use and not t.no_dumb_use and not game.player:isTalentCoolingDown(t) and
		   not game.player:isTalentActive(t.id) and
		   game.player:preUseTalent(t, true, true)
		   then
			avail[#avail+1] = tid
			print(game.player.name, game.player.uid, "dumb ai talents can activate", t.name, tid)
		else
			print("[Skoobot] [AvailableTalentFilter] Excluding talent: "..tid..", cannot be used on "..(target~=nil and target.name or "nil"))
		end
	end
	return avail
end

local function filterFailedTalents(t)
    local out = {}

    for k, v in pairs(t) do
		if not game.player:isTalentCoolingDown(game.player:getTalentFromId(v)) and game.player.AI_talentfailed[v] == nil then
            out[#out + 1] = v
        end
    end

    return out
end

local old_postUseTalent = _M.postUseTalent
function _M:postUseTalent(talent, ret, silent)
    local result = old_postUseTalent(self, talent, ret, silent)
    if not result then self.AI_talentfailed[talent.id] = true end
    return result
end

local function lowHealth(enemy)
    -- TODO make threshold configurable
    if game.player.life < game.player.max_life * SAI_LOWHEALTH_RATIO then
        if enemy ~= nil then
            local dir = game.level.map:compassDirection(enemy.x - game.player.x, enemy.y - game.player.y)
            local name = enemy.name
		    return true, ("#RED#AI cancelled for low health while hostile spotted to the %s (%s%s)"):format(dir ~= nil and dir or "???", name, game.level.map:isOnScreen(enemy.x, enemy.y) and "" or " - offscreen")
		else
		    return true, "#RED#AI cancelled for low health"
		end
    end
end

-- TODO add configurability, at least for Meditation
local function activateSustained()
-- returns true if anything was sustained, else returns false.
    local talents = filterFailedTalents(getSustainableTalents())
    for i,tid in pairs(talents) do
        local t = game.player:getTalentFromId(tid)
		print("Attempting to sustain: "..tid)
        if t.mode == "sustained" and game.player.sustain_talents[tid] == nil then
            if(SAI_useTalent(tid)) then
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

local function skoobot_act(noAction)
-- THIS FUNCTION CAUSES THE AI TO MAKE A SINGLE DECISION AND ACT UPON IT
-- IT CALLS ITSELF RECURSIVELY TO PROCEED TO THE NEXT ACTION
    game.player.AI_talentfailed = {}
	
    local hostiles = spotHostiles(game.player, true)
    if #hostiles > 0 then
        local low, msg = lowHealth(hostiles[0])
        if low then return aiStop(msg) end
        
        _M.skoobot_ai_state = SAI_STATE_FIGHT
    end
	
	_M.skoobot_ai_lastlife = _M.skoobot_ai_lastlife~=nil and _M.skoobot_ai_lastlife or game.player.life
	print("[Skoobot] [Survival] Current Life = "..game.player.life)
	print("[Skoobot] [Survival]  Last Life = ".._M.skoobot_ai_lastlife)
	if not noAction then
		print("[Skoobot] [Survival]  Evaluating life change...")
		_M.skoobot_ai_deltalife = game.player.life - _M.skoobot_ai_lastlife
		_M.skoobot_ai_lastlife = game.player.life
		if(abs(_M.skoobot_ai_deltalife) > 0) then
			print("[Skoobot] [Survival] Delta detected! = ".._M.skoobot_ai_deltalife)
		end
		if (_M.skoobot_ai_deltalife < 0) and ( abs(_M.skoobot_ai_deltalife) / game.player.max_life >= SAI_LOWHEALTH_RATIO / 2) then
			print("#RED#[Skoobot] [Survival] AI Stopped: Lost more than "..math.floor(100*SAI_LOWHEALTH_RATIO/2).."% life in one turn!")
			return aiStop("AI Stopped: Lost more than "..math.floor(100*SAI_LOWHEALTH_RATIO/2).."%% life in one turn!")
		end
	end
    
    if activateSustained() then
		return
	end
    
    game.log(aiStateString())
    
	if _M.skoobot_ai_state == SAI_STATE_STOP then
		return
    elseif _M.skoobot_ai_state == SAI_STATE_REST then
        local terrain = game.level.map(game.player.x, game.player.y, game.level.map.TERRAIN)
        if terrain.air_level and terrain.air_level < 0 then
            -- run to air
            local path = getPathToAir(game.player)
            if path ~= nil then
                local moved = SAI_movePlayer(path[1].x, path[1].y)
            end
            
            if not moved and _M.ai_active then
                return aiStop("#RED#AI stopped: Suffocating, no air in sight!")
			else
				return
            end
        end
        if not SAI_beginRest() then
			return
		end
    elseif _M.skoobot_ai_state == SAI_STATE_EXPLORE then
		if _M.skoobot_ai_deltalife < 0 then
			if #hostiles > 0 then
				_M.skoobot_ai_state = SAI_STATE_FIGHT
				return skoobot_act(true)
			else
				aiStop("#RED#AI stopped: took damage while exploring!")
			end
		end
        if game.player.air < 75 then
            _M.skoobot_ai_state = SAI_STATE_REST
            return skoobot_act(true)
        end
        SAI_beginExplore()
        -- NOTE: Due to execution order, this may actually be checking the start tile
        if game.level.map:checkEntity(game.player.x, game.player.y, engine.Map.TERRAIN, "change_level") then
            aiStop("#GOLD#AI stopping: level change found")
        end
        return
        
    elseif _M.skoobot_ai_state == SAI_STATE_HUNT then
        -- TODO figure out how to hook takeHit() to get here
        -- then figure out if we can target the damage source
        -- or we have to randomwalk/flee
        
        -- for now:
        _M.skoobot_ai_state = SAI_STATE_EXPLORE
        return skoobot_act(true)
    
    elseif _M.skoobot_ai_state == SAI_STATE_FIGHT then
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
				_M.skoobot_ai_state = SAI_STATE_REST
				return skoobot_act(true)
			end
			
			for i,enemy in pairs(targets) do
				print("[Skoobot] [Combat] Target selected: "..enemy.name)
				local talents = getAvailableTalents(enemy, combatTalents)
				print("[Skoobot] [Combat] Talents ready to go: ("..#talents..")")
				table.print(talents)
				talents = filterFailedTalents(talents)
				print("[Skoobot] [Combat] Talents after filter: ("..#talents..")")
				table.print(talents)
				local tid = talents[1]
				if tid ~= nil then
					print("[Skoobot] [Combat] Using talent: "..tid.." on target "..enemy.name)
					game.player:setTarget(enemy.actor)
					SAI_useTalent(tid,nil,nil,nil,enemy.actor)
					if game.player:enoughEnergy() then
						return skoobot_act()
					end
					return
				end
			end
		else
			-- everything is on cooldown, what do?
			-- pass a turn!
			print("[Skoobot] [Combat] All Combat talents on cooldown. Waiting.")
			SAI_passTurn()
			return
		end
		
		
		-- for now just end the ai if we have nothing usable, will diagnose as this occurs
		return aiStop("#GOLD#[Skoobot] [Combat] AI stopping: no usable talents available at this time")
		
		-- no legal target! let's get closer
		-- local a = Astar.new(game.level.map, game.player)
        -- local path = a:calc(game.player.x, game.player.y, target.x, target.y)
        -- local dir = getDirNum(game.player, target)
        -- local moved = false
        
        -- if not path then
            -- --game.log("#RED#Path not found, trying beeline")
            -- moved = game.player:attackOrMoveDir(dir)
        -- else
            -- --game.log("#GREEN#move via path")
            -- local moved = game.player:move(path[1].x, path[1].y)
            -- if not moved then
                -- --game.log("#RED#Normal movement failed, trying beeline")
                -- moved = game.player:attackOrMoveDir(dir)
            -- end
        -- end
        -- if not moved then
            -- -- Maybe we're pinned and can't move?
            -- SAI_passTurn()
        -- end
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
	_M.skoobot_ai_lastlife = game.player.life
    
    skoobot_act(true)
end

local old_act = _M.act
function _M:act()
    local ret = old_act(game.player)
    if (not game.player.running) and (not game.player.resting) and _M.ai_active then
        if game.zone.wilderness then
            aiStop("#RED#Player AI cancelled by wilderness zone!")
            return ret
        end
        _M.skoobot_aiTurnCount = _M.skoobot_aiTurnCount + 1
		print("[Skoobot] Player Act Number ".._M.skoobot_aiTurnCount)
        skoobot_act()
    end
    if _M.skoobot_aiTurnCount > 10 then
		aiStop("Ai ran for 10 turns. Remember to disable this for real runs")
        --aiStop("#LIGHT_RED#AI Disabled. AI acted for 1000 turns. Did it get stuck?")
    end
    return ret
end

return _M