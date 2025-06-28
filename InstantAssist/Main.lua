ReUI.Require
{
    "ReUI.Core >= 1.0.0",
}

function Main(isReplay)
    if isReplay then
        return
    end

    local EntityCategoryContains = EntityCategoryContains
    local MathMax = math.max
    local VDist3 = VDist3

    local SetIgnoreSelection = import("/lua/ui/game/gamemain.lua").SetIgnoreSelection
    local CommandMode = import('/lua/ui/game/commandmode.lua')

    ---@param callback fun()
    local function HiddenSelection(callback)
        local currentCommand = CommandMode.GetCommandMode()
        local oldSelection = GetSelectedUnits()
        SetIgnoreSelection(true)
        callback()
        SelectUnits(oldSelection)
        CommandMode.StartCommandMode(currentCommand[1], currentCommand[2])
        SetIgnoreSelection(false)
    end

    ---@param targetUnit UserUnit
    ---@param unit UserUnit
    ---@return boolean
    local function IsWithinBuildRange(targetUnit, unit)
        local targetSkirtSize = 1
        local bpPhysics = targetUnit:GetBlueprint().Physics
        if bpPhysics then
            targetSkirtSize = MathMax(bpPhysics.SkirtSizeX, bpPhysics.SkirtSizeZ)
        end

        local bp = unit:GetBlueprint()
        local bpFoot = bp.Footprint
        local buildRadius = (bp.Economy.MaxBuildDistance or 5) + MathMax(bpFoot.SizeX or 0, bpFoot.SizeZ or 0) +
            targetSkirtSize

        return buildRadius > VDist3(targetUnit:GetPosition(), unit:GetPosition())
    end

    ReUI.Core.Hook("/lua/ui/game/commandmode.lua", "OnCommandIssued", function(field)
        ---@param command UserCommand
        return function(command)
            field(command)

            if (command.CommandType == "Guard" or command.CommandType == "Repair" or command.CommandType == "TransportLoadUnits") and command.Target.EntityId and --now we need put some <if then> stuff or it work 😎
                command.Clear and command.Units then
                ---@type UserUnit
                ---@diagnostic disable-next-line:assign-type-mismatch
                local targetUnit = GetUnitById(command.Target.EntityId)
                local fraction = targetUnit:GetFractionComplete()

                local isStructure = targetUnit:IsInCategory "STRUCTURE"
                local isMassExtractor = EntityCategoryContains(categories.MASSEXTRACTION * categories.STRUCTURE,
                    targetUnit)
                local IsTransport = EntityCategoryContains(categories.TRANSPORTATION,
                    targetUnit)

                if not isStructure or isMassExtractor or IsTransport and fraction >= 1 then
                    return
                end

                local engineers = EntityCategoryFilterDown(categories.ENGINEER, command.Units)
                end

                local withInRangeEngineers = {}
                ForkThread(function()
                    WaitTicks(1)
                    HiddenSelection(function()
                        SelectUnits(withInRangeEngineers)
                        SimCallback({ Func = 'AbortNavigation', Args = {} }, true)
                    end)
                end)
            end
        end
    end)
end
