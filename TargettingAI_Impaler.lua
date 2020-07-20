function widget:GetInfo()
   return {
      name         = "TargettingAI_Impaler",
      desc         = "attempt to make Impaler not fire Razors, solars and wind generators without order. Meant to be used with return fire state. Version 1.00",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 11,
      enabled      = true
   }
end

local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan
local sqrt = math.sqrt
local UPDATE_FRAME=4
local ImpalerStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitShieldState = Spring.GetUnitShieldState
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitArmored = Spring.GetUnitArmored
local GetUnitStates = Spring.GetUnitStates
local ENEMY_DETECT_BUFFER  = 40
local Echo = Spring.Echo
local Impaler_NAME = "vehheavyarty"
local Crab_NAME = "spidercrabe"
local Fencer_NAME = "vehsupport"
local Caretaker_NAME = "staticcon"
local Badger_Mine_NAME = "wolverine_mine"
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK



local ImpalerControllerMT
local ImpalerController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	damage,
	forceTarget,


	new = function(index, unitID)
		--Echo("ImpalerController added:" .. unitID)
		local self = {}
		setmetatable(self, ImpalerControllerMT)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		local unitDefID = GetUnitDefID(self.unitID)
		local weaponDefID = UnitDefs[unitDefID].weapons[1].weaponDef
		local wd = WeaponDefs[weaponDefID]
		self.damage = wd.damages[4]
		return self
	end,

	unset = function(self)
		--Echo("ImpalerController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	setForceTarget = function(self, param)
		self.forceTarget = param[1]
	end,

	isEnemyInRange = function (self)
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], self.range+ENEMY_DETECT_BUFFER)
		local target = nil
		for i=1, #units do
			if not (GetUnitAllyTeam(units[i]) == self.allyTeamID) then

				enemyPosition = {GetUnitPosition(units[i])}
				if(enemyPosition[2]>-30)then
					if (units[i]==self.forceTarget and GetUnitIsDead(units[i]) == false)then
						GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
						return true
					end
						DefID = GetUnitDefID(units[i])
						if not(DefID == nil)then
						if  (GetUnitIsDead(units[i]) == false)then
							if (UnitDefs[DefID].isBuilding and UnitDefs[DefID].name ~= Badger_Mine_NAME or UnitDefs[DefID].name == Crab_NAME or UnitDefs[DefID].name == Fencer_NAME or UnitDefs[DefID].name == Caretaker_NAME) then
								if (target == nil) then
									target = units[i]
								end
								if (UnitDefs[GetUnitDefID(target)].metalCost < UnitDefs[DefID].metalCost)then
									target = units[i]
								end

							end
						end
					end
				end
			end
		end
		if (target == nil) then
			GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
			return false
		else
			GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, target, 0)
			return true
		end
	end,



	handle=function(self)
		if(GetUnitStates(self.unitID).firestate==1)then
			self.pos = {GetUnitPosition(self.unitID)}
			self:isEnemyInRange()
		end
	end
}
ImpalerControllerMT = {__index = ImpalerController}

function distance ( x1, y1, x2, y2 )
  local dx = (x1 - x2)
  local dy = (y1 - y2)
  return sqrt ( dx * dx + dy * dy )
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (UnitDefs[unitDefID].name == Impaler_NAME and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		if (ImpalerStack[unitID])then
			ImpalerStack[unitID]:setForceTarget(cmdParams)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Impaler_NAME)
		and (unitTeam==GetMyTeamID()) then
			ImpalerStack[unitID] = ImpalerController:new(unitID);
		end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if (UnitDefs[unitDefID].name==Impaler_NAME)
		and not ImpalerStack[unitID] then
		ImpalerStack[unitID] = ImpalerController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (ImpalerStack[unitID]==nil) then
		ImpalerStack[unitID]=ImpalerStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	--if (n%UPDATE_FRAME==0) then
		for _,Impaler in pairs(ImpalerStack) do
			Impaler:handle()
		end
	--end
end

-- The rest of the code is there to disable the widget for spectators
local function DisableForSpec()
	if GetSpecState() then
		widgetHandler:RemoveWidget()
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		DefID = GetUnitDefID(units[i])
		if (UnitDefs[DefID].name==Impaler_NAME)  then
			if  (ImpalerStack[units[i]]==nil) then
				ImpalerStack[units[i]]=ImpalerController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
