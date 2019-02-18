-- table reduction helper
function reduce(list, fn) 
    local acc
    for k, v in ipairs(list) do
        if 1 == k then
            acc = v
        else
            acc = fn(acc, v)
        end 
    end 
    return acc 
end

-- recursive object sum helper
function recSum(list)
	local sum = 0;
	for _,v in pairs(list) do
		if type(v) == "table" then
			sum = sum + recSum(v)
		else
			sum = sum + v
		end
	end
	return sum
end

-------------------------------------------------------
--================ VARIABLES ================--

local _M = loadPrevious(...)

-------------------------------------------------------

local function offensePowerLevel(power, critChance, critBonus, speed)
	return (power * (critChance/100 * ((critBonus/100 or 0) + 1.5)) + 1 ) * speed or 1
end

local function weaponPowerLevels(actor)
	local attackScores = {}
	local temp = {}
	temp.o = actor:getInven(actor.INVEN_MAINHAND)
	temp.ammo = table.get(actor:getInven("QUIVER"), 1)
	temp.archery = temp.o
		and temp.o[1]
		and temp.o[1].archery
		and temp.ammo
		and temp.ammo.archery_ammo == temp.o[1].archery
		and temp.ammo.combat
		and (type ~= "offhand" or actor:attr("can_offshoot"))
		and (type ~= "psionic" or actor:attr("psi_focus_combat")) -- ranged combat
	
	if temp.archery and actor.combat and temp.ammo.combat then
		attackScores.ranged = actor:combatDamage(actor.combat, nil, temp.ammo.combat)
	end
	attackScores.melee = not attackScores.ranged and temp.o and temp.o[1] and temp.o[1].combat and temp.o[1].combat.dam or actor:combatDamage(actor.combat)
	return attackScores
end

function _M:evaluatePowerScores()
	local scores = {}
	scores.survivalScore = self.life/10 * self.life/self.max_life
	scores.physScore = offensePowerLevel(self.combat_dam, self.combat_generic_crit or self.combat_physcrit and (self.combat_physcrit+9)/100, self.combat_critical_power or 0,self.combat_physspeed*game.player.global_speed)
	scores.spellScore = offensePowerLevel(self.combat_spellpower, self.combat_generic_crit or self.combat_spellcrit and (self.combat_spellcrit+4)/100, self.combat_critical_power or 0,self.combat_spellspeed*game.player.global_speed)
	scores.mindScore = offensePowerLevel(self.combat_mindpower, self.combat_generic_crit or self.combat_mindcrit and (self.combat_mindcrit+4)/100, self.combat_critical_power or 0,self.combat_mindspeed*game.player.global_speed)
	scores.defenseScore = self.combat_def/2 + self.combat_armor
	scores.statScore = reduce(self.inc_stats, function(a,b) return a+b end)
	
	scores.attackScores = weaponPowerLevels(self)
	return scores
end

function _M:evaluatePowerLevel()
	return recSum(self:evaluatePowerScores())
end

local old_tooltip = _M.tooltip
function _M:tooltip(x, y, seen_by)
	local result = old_tooltip(self, x, y, seen_by)
	if core.key.modState("ctrl") then
		local scores = self:evaluatePowerScores()
		result:add(true, "#FFD700#Power Level#FFFFFF#: "..string.format("%d",recSum(scores)), {"color", "WHITE"})
		for k,v in pairs(scores) do
			if type(v) ~= "table" then
				result:add(true, " #FFD700#"..k.."#FFFFFF#: "..string.format("%1.2f",v))
			else
				for k2,v2 in pairs(v) do
					result:add(true, " #FFD700#Weapon "..k2.."#FFFFFF#: "..string.format("%1.2f",v2))
				end
			end
		end
	else
		result:add(true, "#FFD700#Power Level#FFFFFF#: "..string.format("%d",self:evaluatePowerLevel()), {"color", "WHITE"})
	end
    return result
end