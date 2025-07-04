local VizMarker = import('/lua/sim/VizMarker.lua').VizMarker

local ExpAlert = false
local ExpDetected = {}

#unit detected
UnitDetected = function(unit)
    ForkThread(function() 
	    if EntityCategoryContains(categories.EXPERIMENTAL, unit) and IsEnemy(ArmyBrains[GetFocusArmy()]:GetArmyIndex(), unit:GetArmy()) then
			ExpEvent(unit)
		end
	end)
	
	ForkThread(function() 
	    if EntityCategoryContains(categories.NUKE*categories.STRUCTURE, unit) and IsEnemy(ArmyBrains[GetFocusArmy()]:GetArmyIndex(), unit:GetArmy()) then
		    NukeDetectedData(unit)
		end
	end)
	
	ForkThread(function() 
	    if EntityCategoryContains(categories.ARTILLERY*categories.STRUCTURE*categories.TECH3, unit) and IsEnemy(ArmyBrains[GetFocusArmy()]:GetArmyIndex(), unit:GetArmy()) then
		    ArtDetectedData(unit)
		end
	end)
end

#unit detected to event reminder
NukeDetectedData = function(unit)
	#arrow alert
	local ObjectiveArrow = import('/lua/objectiveArrow.lua').ObjectiveArrow
	#one arrow for a unit, control one-time sync
	if not unit.arrow then
	    unit.arrow = ObjectiveArrow {Size = 0.3, AttachTo = unit}
		local position = unit:GetPosition()
		local bpID = unit:GetBlueprint().BlueprintId
		local army = unit:GetArmy()
		local text = 'Detected'
		Sync.NukeDetectedEventAlert = {position, bpID, army, text}
		CreateVizAtUnit(unit)
	end
end

#unit detected to event reminder
ArtDetectedData = function(unit)
	#arrow alert
	local ObjectiveArrow = import('/lua/objectiveArrow.lua').ObjectiveArrow
	#one arrow for a unit, control one-time sync
	if not unit.arrow then
	    unit.arrow = ObjectiveArrow {Size = 0.3, AttachTo = unit}
		local position = unit:GetPosition()
		local bpID = unit:GetBlueprint().BlueprintId
		local army = unit:GetArmy()
		local text = 'Detected'
		Sync.ArtDetectedEventAlert = {position, bpID, army, text}
		CreateVizAtUnit(unit)
	end
end

#exp alert on event reminder
ExpEvent = function(unit)
    local bp = unit:GetBlueprint()
	if bp.Audio then
	    if bp.Audio['ExperimentalDetected'] then
		    ArmyBrains[GetFocusArmy()]:PlayVOSound(bp.BlueprintId, bp.Audio['ExperimentalDetected'])
		else
			ArmyBrains[GetFocusArmy()]:PlayVOSound('OtherExpUnits', Sound{Bank = 'X06_VO', Cue = 'X06_Fletcher_T01_04805'})
		end
	end
	#arrow alert
	local ObjectiveArrow = import('/lua/objectiveArrow.lua').ObjectiveArrow
	#one arrow for a unit, control one-time sync
	if not unit.arrow then
	    unit.arrow = ObjectiveArrow {Size = 0.3, AttachTo = unit}
		local position = unit:GetPosition()
		local bpID = unit:GetBlueprint().BlueprintId
		local army = unit:GetArmy()
		local text = 'Detected'
		Sync.ExpDetectedEventAlert = {position, bpID, army, text}
		CreateVizAtUnit(unit)
	end
end

#unit destroyed
UnitDestroy = function(unit)
    #exp destroyed
    if EntityCategoryContains(categories.EXPERIMENTAL, unit) and IsEnemy(ArmyBrains[GetFocusArmy()]:GetArmyIndex(), unit:GetArmy()) then
	    EXPDestroy(unit)
	end
	
    #nuke destroyed
    if EntityCategoryContains(categories.NUKE*categories.STRUCTURE, unit) and IsEnemy(ArmyBrains[GetFocusArmy()]:GetArmyIndex(), unit:GetArmy()) then
	    NukeDestroy(unit)
	end
	
    #artillery destroyed
    if EntityCategoryContains(categories.ARTILLERY*categories.STRUCTURE*categories.TECH3, unit) and IsEnemy(ArmyBrains[GetFocusArmy()]:GetArmyIndex(), unit:GetArmy()) then
	    ArtilleryDestroy(unit)
	end
end

#EXP destroyed
EXPDestroy = function(unit)
    local position = unit:GetPosition()
	local bpID = unit:GetBlueprint().BlueprintId
	local army = unit:GetArmy()
	local text = 'Destroyed'
	Sync.EXPDestroyEventAlert = {position, bpID, army, text}
	CreateVizAtUnit(unit)
end

#Nuke destroyed
NukeDestroy = function(unit)
    local position = unit:GetPosition()
	local bpID = unit:GetBlueprint().BlueprintId
	local army = unit:GetArmy()
	local text = 'Destroyed'
	Sync.NukeDestroyEventAlert = {position, bpID, army, text}
	CreateVizAtUnit(unit)
end

#artillery destroyed
ArtilleryDestroy = function(unit)
    local position = unit:GetPosition()
	local bpID = unit:GetBlueprint().BlueprintId
	local army = unit:GetArmy()
	local text = 'Destroyed'
	Sync.ArtilleryDestroyEventAlert = {position, bpID, army, text}
	CreateVizAtUnit(unit)
end

# #vision at unit
CreateVizAtUnit = function(unit)
	local position = unit:GetPosition()
	local spec = {
    	X = position[1],
		Z = position[3],
		Radius = 20,
		LifeTime = 20,
		Omni = false,
		Radar = false,
		Vision = true,
		Army = GetFocusArmy(),
	}
	VizMarker(spec)
	Satellite:EnableIntel('Vision')
end