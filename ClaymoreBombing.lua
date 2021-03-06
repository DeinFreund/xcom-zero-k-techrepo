function widget:GetInfo()
	return {
		name      = "ClaymoreBombing",
		desc      = "Allows Claymores to drop bombs while transported. Version 3.20",
		author    = "terve886",
		date      = "2019",
		license   = "PD", -- should be compatible with Spring
		layer     = 0,
		handler		= true, --for adding customCommand into UI
		enabled   = true  --  loaded by default?
	}
end

local currentFrame = 0
local CMD_FORCE_DROP_UNIT = 35000
local CMD_INSERT = 1
local CMD_DROP_BOMB = 35000
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitPosition = Spring.GetUnitPosition
local GetGroundHeight = Spring.GetGroundHeight
local GetMyTeamID = Spring.GetMyTeamID
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local Echo = Spring.Echo
local Charon_ID = UnitDefNames.gunshiptrans.id
local Claymore_ID = UnitDefNames.hoverdepthcharge.id
local Hercules_ID = UnitDefNames.gunshipheavytrans.id
local Imp_ID = UnitDefNames.cloakbomb.id
local Scuttle_ID = UnitDefNames.jumpbomb.id
local Snitch_ID = UnitDefNames.shieldbomb.id
local Limpet_ID = UnitDefNames.amphbomb.id
local GetSpecState = Spring.GetSpectatingState
local GetUnitIsTransporting = Spring.GetUnitIsTransporting
local GetUnitWeaponState = Spring.GetUnitWeaponState
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_STOP = CMD.STOP
local selectedTransports = nil
local reloaderStack = {}
local TransporterStack = {}

local CMD_ATTACK_MOVE_ID = 16
local CMD_FIND_PAD = 33411
local CMD_SET_RELOAD_ZONE = 19894
local CMD_DROP_CLAYMORE_BOMB = 19893
local CMD_RELOAD_CLAYMORE = 19892

local cmdReloadClaymore = {
	id      = CMD_RELOAD_CLAYMORE,
	type    = CMDTYPE.ICON,
	tooltip = 'Makes transport land Claymore with the purpose of letting it reload before lifting it up again',
	action  = 'repair',
	params  = { },
	texture = 'LuaUI/Images/plus_green.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}
local cmdDropClaymoreBomb = {
	id      = CMD_DROP_CLAYMORE_BOMB,
	type    = CMDTYPE.ICON,
	tooltip = 'Makes transport force claymore bomb drop',
	action  = 'reclaim',
	params  = {},
	texture = 'LuaUI/Images/commands/states/divebomb_shield.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}
local cmdSetReloadingZone = {
	id      = CMD_SET_RELOAD_ZONE,
	type    = CMDTYPE.ICON_MAP,
	tooltip = 'Sets automatic resupply Zone for the transport',
	action  = '',
	params  = {},
	texture = 'LuaUI/Images/commands/Bold/drop_flag.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}


local reloadControllerMT
local reloadController = {
	unitID,
	targetFrame,
	pickupTarget,


	new = function(index, unitID, target, reload)
		local self = {}
		setmetatable(self,reloadControllerMT)
		self.unitID = unitID
		self.targetFrame = currentFrame+50
		self.pickupTarget = target
		return self
	end,

	handle = function(self)
		if (currentFrame>self.targetFrame)then
			local reload = GetUnitWeaponState(self.pickupTarget, 1, "reloadState")
			if (reload) then
				if(currentFrame > reload)then
					GiveOrderToUnit(self.unitID, CMD_INSERT,{0, CMD_LOAD_UNITS, CMD_OPT_SHIFT, self.pickupTarget}, {"alt"})
					reloaderStack[self.unitID] = nil
					return true
				else
					self.targetFrame=reload
					return false
				end
			end
		end
	end
}
reloadControllerMT = {__index=reloadController}

local transportControllerMT
local transportController = {
	unitID,
	pos,
	reloadZone,
	autoReloadToggle = true,
	fight = false,
	fightPos,

	new = function(index, unitID)
		--Echo("transportController added:" .. unitID)
		local self = {}
		setmetatable(self, transportControllerMT)
		self.unitID = unitID
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("transportController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	getToggleState = function(self)
		return self.autoReloadToggle
	end,

	toggleOn = function (self)
		self.autoReloadToggle = true
	end,

	toggleOff = function (self)
		self.autoReloadToggle = false
	end,

	toggleFightOn = function (self)
		self.fight = true
	end,

	toggleFightOff = function (self)
		self.fight = false
	end,

	setReloadZone = function(self, coordinates)
		self.reloadZone = coordinates
	end,

	handle = function(self)
		if(self.fight)then
			self.pos = {GetUnitPosition(self.unitID)}
			local units = GetUnitsInCylinder(self.pos[1], self.pos[3], 50, Spring.ENEMY_UNITS)
			for i=1, #units do
				local unitDefID = GetUnitDefID(units[i])
				if not(unitDefID == nil)then
					if (not( unitDefID == Claymore_ID) and UnitDefs[unitDefID].canFly == false)then
						local transportedUnit = GetUnitIsTransporting(self.unitID)
						if (transportedUnit[1] == nil) then
							--Echo("No unit being transported")
							return
						end
						local transportedUnitID = transportedUnit[1]
						unitDefID = GetUnitDefID(transportedUnitID)
						if (unitDefID == Claymore_ID) then
							if(self.reloadZone and self.autoReloadToggle)then
								--Unit is sent to reloadzone--
								GiveOrderToUnit(self.unitID, CMD_FORCE_DROP_UNIT, {},{""})
								GiveOrderToUnit(transportedUnitID, CMD_DROP_BOMB, {},0)
								--Echo("Bomb drop order given to unit:" .. transportedUnitID)
								GiveOrderToUnit(self.unitID, CMD_INSERT,{0, CMD_LOAD_UNITS, CMD_OPT_SHIFT, transportedUnitID}, {"alt"})
								--Echo("Load order given to unit:" .. selectedTransports[i])

								GiveOrderToUnit(self.unitID, CMD_INSERT,{0, CMD_UNLOAD_UNITS, CMD_OPT_SHIFT, self.reloadZone[1],self.reloadZone[2],self.reloadZone[3]}, {"alt"})
								local reloadState = GetUnitWeaponState(transportedUnitID, 1, "reloadState")
								reloaderStack[self.unitID] = reloadController:new(self.unitID, transportedUnitID, reloadState);
							else
								GiveOrderToUnit(self.unitID, CMD_FORCE_DROP_UNIT, {},{""})
								GiveOrderToUnit(transportedUnitID, CMD_DROP_BOMB, {},0)
								--Echo("Bomb drop order given to unit:" .. transportedUnitID)
								GiveOrderToUnit(self.unitID, CMD_INSERT,{0, CMD_LOAD_UNITS, CMD_OPT_SHIFT, transportedUnitID}, {"alt"})

								GiveOrderToUnit(self.unitID, CMD_INSERT,{0, CMD_ATTACK_MOVE_ID, CMD_OPT_SHIFT, self.fightPos[1],self.fightPos[2],self.fightPos[3]}, {"alt"})
								--Echo("Load order given to unit:" .. selectedTransports[i])
							end
						end
					end
				end
			end
		end
	end
}
transportControllerMT={__index=transportController}

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if (unitDefID == Charon_ID or unitDefID == Hercules_ID)
			and (unitTeam==GetMyTeamID()) then
		TransporterStack[unitID] = transportController:new(unitID);
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if (unitDefID == Charon_ID or UnitDefs[unitDefID].name == Hercules_ID)
			and not TransporterStack[unitID] then
		TransporterStack[unitID] = transportController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (TransporterStack[unitID]==nil) then
		TransporterStack[unitID]=TransporterStack[unitID]:unset();
	end
end




--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)

	if selectedTransports ~= nil then
		if (cmdID == CMD_DROP_CLAYMORE_BOMB)then
			for i=1, #selectedTransports do
				repeat
					local transportedUnit = GetUnitIsTransporting(selectedTransports[i])
					if (transportedUnit[1] == nil) then
						--Echo("No unit being transported")
						i=i+1
						break
					end
					local transportedUnitID = transportedUnit[1]
					local unitDefID = GetUnitDefID(transportedUnitID)
					if (unitDefID == Claymore_ID or unitDefID == Limpet_ID or unitDefID == Snitch_ID or unitDefID == Imp_ID or unitDefID == Scuttle_ID) then
						if(TransporterStack[selectedTransports[i]] and TransporterStack[selectedTransports[i]].reloadZone and TransporterStack[selectedTransports[i]].autoReloadToggle)then
							--Unit is sent to reloadzone--
							GiveOrderToUnit(selectedTransports[i], CMD_FORCE_DROP_UNIT, {},{""})
							GiveOrderToUnit(transportedUnitID, CMD_DROP_BOMB, {},0)
							--Echo("Bomb drop order given to unit:" .. transportedUnitID)
							GiveOrderToUnit(selectedTransports[i], CMD_INSERT,{0, CMD_LOAD_UNITS, CMD_OPT_SHIFT, transportedUnitID}, {"alt"})
							--Echo("Load order given to unit:" .. selectedTransports[i])

							GiveOrderToUnit(selectedTransports[i], CMD_INSERT,{0, CMD_UNLOAD_UNITS, CMD_OPT_SHIFT, TransporterStack[selectedTransports[i]].reloadZone[1],TransporterStack[selectedTransports[i]].reloadZone[2],TransporterStack[selectedTransports[i]].reloadZone[3]}, {"alt"})
							local reloadState = GetUnitWeaponState(transportedUnitID, 1, "reloadState")
							reloaderStack[selectedTransports[i]] = reloadController:new(selectedTransports[i], transportedUnitID, reloadState);
						else
							GiveOrderToUnit(selectedTransports[i], CMD_INSERT,{0, CMD_FORCE_DROP_UNIT, CMD_OPT_SHIFT}, {"alt"})
							GiveOrderToUnit(transportedUnitID, CMD_DROP_BOMB, {},0)
							--Echo("Bomb drop order given to unit:" .. transportedUnitID)
							GiveOrderToUnit(selectedTransports[i], CMD_INSERT,{0, CMD_LOAD_UNITS, CMD_OPT_SHIFT, transportedUnitID}, {"alt"})
							--Echo("Load order given to unit:" .. selectedTransports[i])
						end
					end
				until true
			end
			return true
		end
		if (cmdID == CMD_RELOAD_CLAYMORE)then
			for i=1, #selectedTransports do
				repeat
					local transportedUnit = GetUnitIsTransporting(selectedTransports[i])
					if (transportedUnit[1] == nil) then
						Echo("No unit being transported")
						i=i+1
						break
					end
					local transportedUnitID = transportedUnit[1]
					local unitDefID = GetUnitDefID(transportedUnitID)
					if (unitDefID == Claymore_ID) then

						local reloadState = GetUnitWeaponState(transportedUnitID, 1, "reloadState")
						if(currentFrame >= reloadState)then
							break --already loaded
						else
							local position = {GetUnitPosition(selectedTransports[i])}
							GiveOrderToUnit(selectedTransports[i], CMD_UNLOAD_UNITS, {position[1], GetGroundHeight(position[1], position[3]), position[3], 1},0)
							reloaderStack[selectedTransports[i]] = reloadController:new(selectedTransports[i], transportedUnitID, reloadState);
						end
					end
				until true
			end
		end

		if (cmdID == CMD_FIND_PAD)then
			local toggleStateGot = false
			local toggleState
			for i=1, #selectedTransports do
				if (TransporterStack[selectedTransports[i]])then
					if (toggleStateGot == false)then
						toggleState = TransporterStack[selectedTransports[i]]:getToggleState()
						toggleStateGot = true
					end
					if (toggleState) then
						TransporterStack[selectedTransports[i]]:toggleOff()
						Echo("Return to reloadZone turned Off")
					else
						TransporterStack[selectedTransports[i]]:toggleOn()
						Echo("Return to reloadZone turned On")
					end
				end
			end
			return true
		end

		if (cmdID == CMD_SET_RELOAD_ZONE and #params==3)then
			for i=1, #selectedTransports do
				TransporterStack[selectedTransports[i]]:setReloadZone(params)
			end
			return
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (TransporterStack[unitID])then
		if (cmdID == CMD_ATTACK_MOVE_ID) then
			TransporterStack[unitID]:toggleFightOn()
			TransporterStack[unitID].fightPos=cmdParams
		else
			TransporterStack[unitID]:toggleFightOff()
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedTransports = filterTransports(selectedUnits)
end

function filterTransports(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (Charon_ID == GetUnitDefID(unitID) or Hercules_ID == GetUnitDefID(unitID)) then
			n = n + 1
			filtered[n] = unitID
		end
	end
	if n == 0 then
		return nil
	else
		return filtered
	end
end

function widget:CommandsChanged()
	if selectedTransports ~= nil then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdDropClaymoreBomb
		customCommands[#customCommands+1] = cmdReloadClaymore
		customCommands[#customCommands+1] = cmdSetReloadingZone
	end
end

function widget:GameFrame(n)
	currentFrame = n

	for _,Reloader in pairs(reloaderStack) do
		Reloader:handle()
	end

	for _,ClaymoreBomber in pairs(TransporterStack) do
		ClaymoreBomber:handle()
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

	local units = GetTeamUnits(GetMyTeamID())
	for i=1, #units do
		local unitID = units[i]
		local unitDefID = GetUnitDefID(unitID)
		if (unitDefID == Charon_ID or unitDefID == Hercules_ID) then
			TransporterStack[unitID] = transportController:new(unitID);
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
