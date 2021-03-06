function widget:GetInfo()
   return {
      name         = "CrabCoverAI",
      desc         = "attempt to Crab cover upon aproaching bombing. Version 1.1",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 10,
      enabled      = true
   }
end
local UPDATE_FRAME=10
local CrabStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local IsUnitSelected = Spring.IsUnitSelected
local GetTeamUnits = Spring.GetTeamUnits
local Echo = Spring.Echo
local Crab_ID = UnitDefNames.spidercrabe.id
local Raven_ID = UnitDefNames.bomberprec.id
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_MOVE = CMD.MOVE
local CMD_OPT_INTERNAL = CMD.OPT_INTERNAL
local CMD_RAW_MOVE  = 31109
local CMD_MOVE_ID = 10

local CrabAIMT
local CrabAI = {
	unitID,
	pos,
	range,
	moveTarget,
	enemyClose = false,


	new = function(index, unitID)
		--Echo("CrabAI added:" .. unitID)
		local self = {}
		setmetatable(self,CrabAIMT)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		self.moveTarget = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("CrabAI removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	setMoveTarget = function(self, params)
		self.moveTarget = params
		Echo("move params updated")
		self.enemyClose = false
	end,

	cancelMoveTarget = function(self)
		self.moveTarget = {GetUnitPosition(self.unitID)}
		Echo("movement cancelled")
	end,

	isEnemyInRange = function (self)
		self.pos = {GetUnitPosition(self.unitID)}
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range, Spring.ENEMY_UNITS)
		for i=1, #units do
			local unitDefID = GetUnitDefID(units[i])
			if not(unitDefID == nil)then
				if (GetUnitIsDead(units[i]) == false and UnitDefs[unitDefID].isBuilding == false) then
					if (IsUnitSelected(self.unitID) == false or unitDefID == Raven_ID) then
						if (self.enemyClose)then
							return true
						end
						GiveOrderToUnit(self.unitID,CMD_MOVE, self.pos, CMD_OPT_INTERNAL)
						self.enemyClose = true
						return true
					end
				end
			end
		end
		if (self.enemyClose)then
			GiveOrderToUnit(self.unitID,CMD_MOVE, self.moveTarget, CMD_OPT_INTERNAL)
		end
		self.enemyClose = false
		return false
	end,


	handle = function(self)
		self:isEnemyInRange()
	end
}
CrabAIMT = {__index=CrabAI}

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Crab_ID)
		and (unitTeam==GetMyTeamID()) then
			CrabStack[unitID] = CrabAI:new(unitID);
		end
end

function widget:UnitDestroyed(unitID)
	if not (CrabStack[unitID]==nil) then
		CrabStack[unitID]=CrabStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		for _,crab in pairs(CrabStack) do
			crab:handle()
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (cmdID == CMD_RAW_MOVE  and #cmdParams == 3 and unitDefID == Crab_ID) then
		if (CrabStack[unitID]) then
			CrabStack[unitID]:setMoveTarget(cmdParams)
			return
		end
	end
	if (not(cmdID == CMD_MOVE_ID or cmdID == 2 or cmdID ==1) and unitDefID == Crab_ID) then
		if (CrabStack[unitID]) then
			CrabStack[unitID]:cancelMoveTarget()
		end
	end
end

-- The rest of the code is there to disable the widget for spectators
local function DisableForSpec()
	if GetSpecState() then
		widgetHandler:RemoveWidget(widget)
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		local unitDefID = GetUnitDefID(units[i])
		if (unitDefID == Crab_ID)  then
			if  (CrabStack[units[i]]==nil) then
				CrabStack[units[i]]=CrabAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
