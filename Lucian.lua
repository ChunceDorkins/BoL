if myHero.charName ~= 'Lucian' then
    return
end

--
-- Lucian
---------------------
class 'Lucian'
function Lucian:__init()
	self:Variables()
	self:Prediction()
	self:OrbWalker()
end

--
-- Populate variables
---------------------
function Lucian:Variables()
    self.TargetSelector = TargetSelector(TARGET_LESS_CAST_PRIORITY, 1250, DAMAGE_PHYSICAL, true)
end

--
-- Populate prediction
---------------------
function Lucian:Prediction()
	--[[if FileExist(LIB_PATH .. "DivinePred.lua") and FileExist(LIB_PATH .. "DivinePred.luac") then
        require "DivinePred"
        self.DivinePrediction = DivinePred()
    end]]

    if FileExist(LIB_PATH .. "VPrediction.lua") then
        require "VPrediction"
        self.VPrediction = VPrediction()
    end
end

--
-- Populate the orbwalkers
---------------------
function Lucian:OrbWalker()
    if _G.RebornScriptName then
        PrintMessage("Waiting for SAC:Reborn...")
        self:WaitForReborn()
    else
    	if FileExist(LIB_PATH .. "SxOrbWalk.lua") then
    		require "SxOrbWalk"
    		self.SxOrbWalk = SxOrbWalk()
    	else
    		PrintMessage("Unable to find any OrbWalker, please use SxOrbWalk")
    	end

        self.Loaded = true
    end
end

--
-- Wait for reborn to authenticate
---------------------
function Lucian:WaitForReborn()
    if _G.AutoCarry then
        self.Loaded = true
    else
        DelayAction(function()
            self:WaitForReborn()
        end, 1)
    end
end

--
-- Attack current target or a specific target
---------------------
function Lucian:Attack(unit)
	if unit == nil then
		unit = self:GetTarget()
	end

	if unit == nil then
		return
	end

	local attackRange = self:GetAutoAttackRange(unit)
	local attackRangeSqr = attackRange * attackRange
	if GetDistanceSqr(unit) > attackRangeSqr then
		return
	end

	myHero:Attack(unit)
end

--
-- Get the auto attack range between myHero and a target unit
---------------------
function Lucian:GetAutoAttackRange(unit)
    local unitBoundingBox = 0
    if unit ~= nil and ValidTarget(unit) then
        unitBoundingBox = GetDistance(unit.minBBox, unit) / 2
    end
    return myHero.range + GetDistance(myHero, myHero.minBBox) + unitBoundingBox + 50
end

--
-- Gets the current target from OrbWalker / Target Selector
---------------------
function Lucian:GetTarget()
	if _G.AutoCarry then
    	local target = _G.AutoCarry.Crosshair:GetTarget()
    	if target then
    		return target
    	end
    end

    if self.SxOrbWalk then
    	local target = self.SxOrbWalk:GetTarget()
    	if target then
    		return target
    	end
    end

    self.TargetSelector:update()
    return self.TargetSelector.target
end

--
-- Piercing Light
---------------------
class 'PiercingLight'
function PiercingLight:__init(lucian, prediction, weaving, menu)
	self.Lucian = lucian
	self.Prediction = prediction
	self.Weaving = weaving
	self.Menu = menu

	self.Range = 500
	self.RangeSqr = 500*500
	self.MaxRange = 1100
	self.Delay = 0.35

	self.MinionManager = minionManager(MINION_ENEMY, self.Range, myHero, MINION_SORT_MAXHEALTH_ASC)

	AddTickCallback(function()
		self.MinionManager:update()
	end)
end

--
-- Draws the polygon in which we search for enemies/minions
---------------------
function PiercingLight:Draw()
	if self.LeftVector ~= nil and self.RightVector ~= nil and self.TopVector ~= nil then
		DrawLine(self.LeftVector.x, self.LeftVector.y, self.RightVector.x, self.RightVector.y, 1, 0xFFFF0000)
		DrawLine(self.LeftVector.x, self.LeftVector.y, self.TopVector.x, self.TopVector.y, 1, 0xFFFF0000)
		DrawLine(self.RightVector.x, self.RightVector.y, self.TopVector.x, self.TopVector.y, 1, 0xFFFF0000)
		self.LeftVector, self.RightVector, self.TopVector = nil
	end
end

--
-- Try to cast Piercing Light onto a unit
---------------------
function PiercingLight:Cast(unit)
	if self.Weaving.IsWeaving then
		return false
	end

	if GetDistanceSqr(unit) <= self.RangeSqr then
		CastSpell(_Q, unit)
		return true
	end

	local boundingPolygon = self:GetBoundingPolygon(unit)

	for _, enemy in ipairs(GetEnemyHeroes()) do
		local screenPosition = WorldToScreen(D3DXVECTOR3(enemy.x, enemy.y, enemy.z))
		local screenPoint = Point(screenPosition.x, screenPosition.y)
		if boundingPolygon:contains(screenPoint) and GetDistanceSqr(enemy) <= self.RangeSqr then
			CastSpell(_Q, enemy)
			return true
		end
	end

	for _, minion in ipairs(self.MinionManager.objects) do
		local screenPosition = WorldToScreen(D3DXVECTOR3(minion.x, minion.y, minion.z))
		local screenPoint = Point(screenPosition.x, screenPosition.y)
		if boundingPolygon:contains(screenPoint) and GetDistanceSqr(minion) <= self.RangeSqr then
			CastSpell(_Q, minion)
			return true
		end
	end

	return false
end

--
-- Gets the bounding polygon of the piercing light ability
---------------------
function PiercingLight:GetBoundingPolygon(unit)
	local targetRadius = GetDistance(unit, unit.minBBox)

	local position = self:GetPredictedPosition(unit)

	local distance = GetDistance(position, myHero)

	local targetVector = Vector(position) - Vector(myHero)
	local targetVectorNormalized = targetVector:normalized()

	local targetX, targetY, targetZ = targetVectorNormalized:unpack()

	local maxX = position.x - (targetX * distance)
	local maxY = position.y  - (targetY * distance)
	local maxZ = position.z - (targetZ * distance)

	local targetPerpendicularVector = targetVector:perpendicular():normalized()

	targetX, targetY, targetZ = targetPerpendicularVector:unpack()

	local leftX = position.x + (targetX * targetRadius)
	local leftY = position.y + (targetY * targetRadius)
	local leftZ = position.z + (targetZ * targetRadius)

	local rightX = position.x - (targetX * targetRadius)
	local rightY = position.y - (targetY * targetRadius)
	local rightZ = position.z - (targetZ * targetRadius)

	local leftVector = WorldToScreen(D3DXVECTOR3(leftX, leftY, leftZ))
	local rightVector = WorldToScreen(D3DXVECTOR3(rightX, rightY, rightZ))
	local topVector = WorldToScreen(D3DXVECTOR3(maxX, maxY, maxZ))

	local boundingPolygon = Polygon(Point(leftVector.x, leftVector.y), Point(rightVector.x, rightVector.y), Point(topVector.x, topVector.y))

	if self.Menu.Draw.PiercingLight then
		self.LeftVector = leftVector
		self.RightVector = rightVector
		self.TopVector = topVector
	end

	return boundingPolygon
end

--
-- Get the prediction position of a unit for the piercing light ability
---------------------
function PiercingLight:GetPredictedPosition(unit)
	local position, hitChance = self.Prediction:GetPredictedPos(unit, self.Delay, false, myHero, false)
	return position
end

--
-- Ardent Blaze
---------------------
class 'ArdentBlaze'
function ArdentBlaze:__init(lucian, prediction, weaving)
	self.Lucian = lucian
	self.Prediction = prediction
	self.Weaving = weaving

	self.Range = 1000
	self.RangeSqr = 1000*1000
	self.Speed = 1600
	self.Width = 80
	self.Delay = 0.3
end

--
-- Trys to cast Ardent Blaze onto a unit
---------------------
function ArdentBlaze:Cast(unit)
	if self.Weaving.IsWeaving then
		return false
	end

	local position, hitChance = self:GetPredictedPosition(unit)
	if position and hitChance >= 1 and GetDistanceSqr(position, myHero) <= self.RangeSqr then
		CastSpell(_W, position.x, position.z)
		return true
	end

	return false
end

--
-- Get the prediction position of a unit for the ardent blaze ability
---------------------
function ArdentBlaze:GetPredictedPosition(unit)
	local position, hitChance = self.Prediction:GetLineCastPosition(unit, self.Delay, self.Width, self.Range, self.Speed, myHero, true)
	return position, hitChance
end

--
-- Weaving
-- Tracks the passive and attacks after every spell cast
---------------------
class 'Weaving'
function Weaving:__init(lucian, menu)
	self.Lucian = lucian
	self.Menu = menu
	self.IsWeaving = false

	AddProcessSpellCallback(function(unit, spell)
		-- If we're not pressing the key don't force an attack
		if not self.Menu.Keys.ComboKey and not self.Menu.Keys.HarassKey1 and not self.Menu.Keys.HarassKey2 then
			return
		end

		if not unit.isMe then
			return
		end

		local spellName = spell.name:lower()

		if spellName:find("attack") then
			return
		end

		if spellName:find("lucian") then
			DelayAction(function()
				if spellName:find("luciane") and self.Lucian.SxOrbWalk then
					self.Lucian.SxOrbWalk:ResetAA()
				end

				self.Lucian:Attack()
            end, spell.windUpTime)
		end
	end)

	AddApplyBuffCallback(function(source, unit, buff)
		if unit == nil or buff == nil then
			return
		end

		if not unit.isMe then
			return
		end

		if not self:IsBuffValid(buff) then
			return
		end

		if buff.name:lower():find("lucianpassivebuff") then
			self.IsWeaving = true
		end
	end)

	AddRemoveBuffCallback(function(unit, buff)
		if unit == nil or buff == nil then
			return
		end

		if not unit.isMe then
			return
		end

		if buff.name:lower():find("lucianpassivebuff") then
			self.IsWeaving = false
		end
	end)
end

--
-- Checks if the buff is valid
---------------------
function Weaving:IsBuffValid(buff)
    if buff == nil or buff.name == nil then
        return false
    end

    local gameTime = GetGameTimer()
    return buff.startTime <= gameTime and buff.endTime >= gameTime
end

--
-- Harass
---------------------
class 'Harass'
function Harass:__init(lucian, menu, piercingLight)
	self.Lucian = lucian
	self.Menu = menu
	self.PiercingLight = piercingLight

	AddTickCallback(function()
		if not self.Menu.Keys.HarassKey1 and not self.Menu.Keys.HarassKey2 then
			return
		end

		local manaPercent = (myHero.mana / myHero.maxMana) * 100
		if manaPercent < self.Menu.ManaManagement.Harass then
			return
		end

		for _, enemy in ipairs(GetEnemyHeroes()) do
			if self.Menu.Harass[enemy.charName] and ValidTarget(enemy, self.PiercingLight.MaxRange) then
				self.PiercingLight:Cast(enemy)
			end
		end
	end)
end

--
-- Combo
---------------------
class 'Combo'
function Combo:__init(lucian, menu, piercingLight, ardentBlaze)
	self.Lucian = lucian
	self.Menu = menu
	self.PiercingLight = piercingLight
	self.ArdentBlaze = ardentBlaze

	AddTickCallback(function()
		if not self.Menu.Keys.ComboKey then
			return
		end

		local target = self.Lucian:GetTarget()

		if not ValidTarget(target) then
            return
        end

        local piercingLightReady = myHero:CanUseSpell(_Q) == READY
        if piercingLightReady then
        	if self.PiercingLight:Cast(target) then
        		return
        	end
        end

        local ardentBlazeReady = myHero:CanUseSpell(_W) == READY
        if ardentBlazeReady then
        	if self.ArdentBlaze:Cast(target) then
        		return
        	end
        end
	end)
end

--
-- Menu
---------------------
class 'LucianMenu'
function LucianMenu:__init(lucian)
    self.Menu = scriptConfig('Lucian', 'Lucian')

    self.Menu:addSubMenu('Keys', 'Keys')
    self.Menu.Keys:addParam('ComboKey', 'Combo', SCRIPT_PARAM_ONKEYDOWN, false, string.byte(" "))
    self.Menu.Keys:addParam('HarassKey1', 'Harass (1)', SCRIPT_PARAM_ONKEYDOWN, false, string.byte("C"))
    self.Menu.Keys:addParam('HarassKey2', 'Harass (2)', SCRIPT_PARAM_ONKEYDOWN, false, string.byte("V"))

    self.Menu:addSubMenu('Mana Management', 'ManaManagement')
    self.Menu.ManaManagement:addParam('Harass', 'Harass Mana %', SCRIPT_PARAM_SLICE, 30, 1, 100, 0)

    self.Menu:addSubMenu('Harass', 'Harass')
    self.Menu.Harass:addParam('PiercingLight', 'Use Piercing Light', SCRIPT_PARAM_ONOFF, true)

    self.Menu.Harass:addParam('info', 'Whitelist', SCRIPT_PARAM_INFO, '')
    for _, enemy in ipairs(GetEnemyHeroes()) do
    	self.Menu.Harass:addParam(enemy.charName, enemy.charName, SCRIPT_PARAM_ONOFF, true)
	end

	self.Menu:addSubMenu('Drawing', 'Draw')
	self.Menu.Draw:addParam('PiercingLight', 'Draw Piercing Light', SCRIPT_PARAM_ONOFF, true)

	if lucian.SxOrbWalk then
		self.Menu:addSubMenu('Orbwalker', 'Orbwalker')
		lucian.SxOrbWalk:LoadToMenu(self.Menu.Orbwalker)
	end
end

--
-- BoL functions
---------------------
function OnLoad()
    local lucian = Lucian()
    WaitForLucian(lucian)
end

function OnDraw()
	if PiercingLightObj ~= nil then
		PiercingLightObj:Draw()
	end
end

--
-- Startup functions
---------------------
function WaitForLucian(lucian)
    if lucian.Loaded then
        PrintMessage("Ready")
        Create(lucian)
    else
        DelayAction(function()
            WaitForLucian(lucian)
        end, 1)
    end
end

function Create(lucian)
	local menu = LucianMenu(lucian)

	local weaving = Weaving(lucian, menu.Menu)
	PiercingLightObj = PiercingLight(lucian, lucian.VPrediction, weaving, menu.Menu)
	ArdentBlazeObj = ArdentBlaze(lucian, lucian.VPrediction, weaving)

	Harass(lucian, menu.Menu, PiercingLightObj)
	Combo(lucian, menu.Menu, PiercingLightObj, ArdentBlazeObj)
end

function PrintMessage(message)
    print(string.format("<font color=\"#2980b9\"><b>Lucian:</b></font> <font color=\"#ffffff\">%s</font>", message))
end