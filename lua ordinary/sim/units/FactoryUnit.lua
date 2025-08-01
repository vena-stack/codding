
local Unit = import("/lua/sim/unit.lua").Unit
local UnitOnStopBuild = Unit.OnStopBuild

local StructureUnit = import("/lua/sim/units/structureunit.lua").StructureUnit
local StructureUnitOnCreate = StructureUnit.OnCreate
local StructureUnitOnDestroy = StructureUnit.OnDestroy
local StructureUnitOnPaused = StructureUnit.OnPaused
local StructureUnitOnUnpaused = StructureUnit.OnUnpaused
local StructureUnitOnStartBuild = StructureUnit.OnStartBuild
local StructureUnitOnStopBuild = StructureUnit.OnStopBuild
local StructureUnitOnStopBeingBuilt = StructureUnit.OnStopBeingBuilt
local StructureUnitCheckBuildRestriction = StructureUnit.CheckBuildRestriction
local StructureUnitOnFailedToBuild = StructureUnit.OnFailedToBuild

-- upvalue scope for performance
local WaitFor = WaitFor
local WaitTicks = WaitTicks
local ForkThread = ForkThread
local IsDestroyed = IsDestroyed
local ChangeState = ChangeState
local CreateRotator = CreateRotator
local CreateAnimator = CreateAnimator
local EntityCategoryContains = EntityCategoryContains

-- pre-compute for performance
local categoriesAIR = categories.AIR
local categoriesENGINEER = categories.ENGINEER

---@class FactoryUnit : StructureUnit
---@field BuildingUnit boolean
---@field BuildEffectsBag TrashBag
---@field BuildBoneRotator moho.RotateManipulator
---@field BuildEffectBones string[]
---@field FactoryBuildFailed boolean
---@field RollOffPoint Vector
FactoryUnit = ClassUnit(StructureUnit) {

    RollOffAnimationRate = 10,

    ---------------------------------------------------------------------------
    --#region Engine events

    ---@param self FactoryUnit
    OnCreate = function(self)
        StructureUnitOnCreate(self)

        local blueprint = self.Blueprint

        -- if we're a support factory, make sure our build restrictions are correct
        if blueprint.CategoriesHash["SUPPORTFACTORY"] then
            self:UpdateBuildRestrictions()
        end

        -- store build bone rotator to prevent trashing the memory
        local buildBoneRotator = CreateRotator(self, blueprint.Display.BuildAttachBone or 0, 'y', 0, 10000)
        buildBoneRotator:SetPrecedence(1000)
        self.BuildBoneRotator = self.Trash:Add(buildBoneRotator)

        -- store build effect bones for quick access
        self.BuildEffectBones = blueprint.General.BuildBones.BuildEffectBones

        -- save for quick access later
        self.RollOffPoint = { 0, 0, 0 }
    end,

    ---@param self FactoryUnit
    OnDestroy = function(self)
        StructureUnitOnDestroy(self)
        local brain = self.Brain
        local blueprint = self.Blueprint

        if blueprint.CategoriesHash["RESEARCH"] and self:GetFractionComplete() == 1.0 then
            -- update internal state
            brain:RemoveHQ(blueprint.FactionCategory, blueprint.LayerCategory, blueprint.TechCategory)
            brain:SetHQSupportFactoryRestrictions(blueprint.FactionCategory, blueprint.LayerCategory)

            -- update all units affected by this
            local affected = brain:GetListOfUnits(categories.SUPPORTFACTORY - categories.EXPERIMENTAL, false)
            for _, unit in affected do
                unit:UpdateBuildRestrictions()
            end
        end

        self:DestroyUnitBeingBuilt()
    end,

    ---@param self FactoryUnit
    OnPaused = function(self)
        StructureUnitOnPaused(self)

        -- remove the build effects
        if self:IsUnitState('Building') then
            self:StopBuildingEffects(self.UnitBeingBuilt)
        end
    end,

    ---@param self FactoryUnit
    OnUnpaused = function(self)
        StructureUnitOnUnpaused(self)

        -- re-introduce the build effects
        local unitBeingBuilt = self.UnitBeingBuilt --[[@as Unit]]
        local unitBuildOrder = self.UnitBuildOrder
        if self:IsUnitState('Building') and (not IsDestroyed(unitBeingBuilt)) then
            self:StartBuildingEffects(unitBeingBuilt, unitBuildOrder)
        end
    end,

    ---@param self FactoryUnit
    ---@param unitBeingBuilt Unit
    ---@param order string
    OnStartBuild = function(self, unitBeingBuilt, order)
        StructureUnitOnStartBuild(self, unitBeingBuilt, order)

        self.FactoryBuildFailed = nil
        self.BuildingUnit = true
        if order ~= 'Upgrade' then
            ChangeState(self, self.BuildingState)
            self.BuildingUnit = nil
        elseif unitBeingBuilt.Blueprint.CategoriesHash["RESEARCH"] then
            -- temporarily remove the ability to assist to prevent cancelling the upgrade
            self:RemoveCommandCap('RULEUCC_Guard')
            self.DisabledAssist = true
        end
    end,

    --- Introduce a rolloff delay, where defined.
    ---@param self FactoryUnit
    ---@param unitBeingBuilt Unit
    ---@param order string
    OnStopBuild = function(self, unitBeingBuilt, order)
        StructureUnitOnStopBuild(self, unitBeingBuilt, order)

        self.BuildingUnit = false

        -- re-introduce the ability to assist
        if self.DisabledAssist then
            self:AddCommandCap('RULEUCC_Guard')
            self.DisabledAssist = nil
        end

        -- Factory can stop building but still have an unbuilt unit if a mobile build order is issued and the order is cancelled
        if unitBeingBuilt:GetFractionComplete() < 1 then
            unitBeingBuilt:Destroy()
        end

        if not (self.FactoryBuildFailed or IsDestroyed(self)) then
            self:StopBuildFx()

            -- Moving off factory has to be issued this tick so that rally points are issued after it
            -- Air units don't need the move order since they fly off the factory by themselves
            -- Pass the spin up so that engineers can be rotated towards the rolloff point after the "build finished" animation

            local spin = nil
            if not EntityCategoryContains(categoriesAIR, unitBeingBuilt) then
                local rollOffPoint = self.RollOffPoint
                local x, y, z
                spin, x, y, z = self:CalculateRollOffPoint()
                rollOffPoint[1], rollOffPoint[2], rollOffPoint[3] = x, y, z
                IssueToUnitMoveOffFactory(unitBeingBuilt, rollOffPoint)
            end

            self:ForkThread(self.FinishBuildThread, unitBeingBuilt, order, spin)
        end

    end,

    ---@param self FactoryUnit
    ---@param builder Unit
    ---@param layer Layer
    OnStopBeingBuilt = function(self, builder, layer)
        StructureUnitOnStopBeingBuilt(self, builder, layer)

        local brain = self.Brain
        local blueprint = self.Blueprint

        if blueprint.CategoriesHash["RESEARCH"] then
            -- update internal state
            brain:AddHQ(blueprint.FactionCategory, blueprint.LayerCategory, blueprint.TechCategory)
            brain:SetHQSupportFactoryRestrictions(blueprint.FactionCategory, blueprint.LayerCategory)

            -- update all units affected by this
            local affected = brain:GetListOfUnits(categories.SUPPORTFACTORY - categories.EXPERIMENTAL, false)
            for _, unit in affected do
                unit:UpdateBuildRestrictions()
            end
        end

        -- Blinking lights functionality
        brain:RegisterUnitEnergyStorage(self)
        brain:RegisterUnitMassStorage(self)

        if brain.MassStorageState == 'EconLowMassStore' or brain.EnergyStorageState == 'EconLowEnergyStore' then
            self.BlinkingLightsState = 'Red'
        else
           self.BlinkingLightsState = 'Green'
        end
        self:CreateBlinkingLights()
    end,

    ---@param self FactoryUnit
    OnFailedToBuild = function(self)
        -- Instantly clear the build area so the next build can start, since unit `Destroy` doesn't do so.
        self.UnitBeingBuilt:SetCollisionShape('None')
        StructureUnitOnFailedToBuild(self)
        self.FactoryBuildFailed = true
        self:StopBuildFx()
        ChangeState(self, self.IdleState)
    end,

    --- When the factory is killed, kills the unit being built, with veterancy dispersal and credit to the instigator.
    ---@param self FactoryUnit
    ---@param instigator Unit | Projectile
    ---@param type string
    ---@param overkillRatio number
    OnKilled = function(self, instigator, type, overkillRatio)
        self:KillUnitBeingBuilt(instigator, type, overkillRatio)
        StructureUnit.OnKilled(self, instigator, type, overkillRatio)
    end,

    --#endregion

    ---------------------------------------------------------------------------
    --#region Lua functionality

    --- Kills the unit being built, with veterancy dispersal and credit to the instigator.
    ---@param self FactoryUnit
    ---@param instigator Unit | Projectile
    ---@param type string
    ---@param overkillRatio number
    KillUnitBeingBuilt = function(self, instigator, type, overkillRatio)
        local unitBeingBuilt = self.UnitBeingBuilt
        if unitBeingBuilt and not unitBeingBuilt.Dead and not unitBeingBuilt.isFinishedUnit then
            -- Detach the unit to allow things like sinking
            unitBeingBuilt:DetachFrom(true)
            -- Disperse the unit's veterancy to our killers
            -- only take remaining HP so we don't double count
            -- Identical logic is used for cargo of transports, so this vet behavior is consistent.
            self:VeterancyDispersal(unitBeingBuilt:GetTotalMassCost() * unitBeingBuilt:GetHealth() / unitBeingBuilt:GetMaxHealth())
            if instigator then
                unitBeingBuilt:Kill(instigator, type, 0)
            else
                unitBeingBuilt:Kill()
            end
        end
    end,

    --- Destroys the unit being built if it isn't already dead/destroyed, this fixes cases
    --- where the factory is reclaimed or transferred and the unit being built still exists.
    ---@param self FactoryUnit
    DestroyUnitBeingBuilt = function(self)
        local unitBeingBuilt = self.UnitBeingBuilt --[[@as Unit]]
        -- unit is dead, so it should destroy itself
        if not unitBeingBuilt.Dead and not IsDestroyed(unitBeingBuilt)
            and not unitBeingBuilt.isFinishedUnit
        then
            unitBeingBuilt:Destroy()
        end
    end,

    ---@param self FactoryUnit
    ---@param unitBeingBuilt Unit
    ---@param order boolean
    ---@param rollOffPointSpin number?
    FinishBuildThread = function(self, unitBeingBuilt, order, rollOffPointSpin)
        self:SetBusy(true)
        self:SetBlockCommandQueue(true)
        local bp = self.Blueprint
        local bpAnim = bp.Display.AnimationFinishBuildLand
        if bpAnim and EntityCategoryContains(categories.LAND, unitBeingBuilt) then
            self.RollOffAnim = CreateAnimator(self):PlayAnim(bpAnim):SetRate(self.RollOffAnimationRate)
            self.Trash:Add(self.RollOffAnim)
            WaitTicks(1)
            WaitFor(self.RollOffAnim)
        end

        -- engineers can only be rotated during rolloff after the "build finished" animation ends
        if rollOffPointSpin and unitBeingBuilt and EntityCategoryContains(categoriesENGINEER, unitBeingBuilt) then
            unitBeingBuilt:SetRotation(rollOffPointSpin)
        end

        if unitBeingBuilt and not unitBeingBuilt.Dead then
            unitBeingBuilt:DetachFrom(true)
        end
        self:DetachAll(bp.Display.BuildAttachBone or 0)
        self:DestroyBuildRotator()
        if order ~= 'Upgrade' then
            ChangeState(self, self.RollingOffState)
        else
            self:SetBusy(false)
            self:SetBlockCommandQueue(false)
        end
    end,

    ---@param self FactoryUnit
    ---@param target_bp any
    ---@return boolean
    CheckBuildRestriction = function(self, target_bp)
        -- Check basic build restrictions first (Unit.CheckBuildRestriction but we only go up one inheritance level)
        if not StructureUnitCheckBuildRestriction(self, target_bp) then
            return false
        end
        -- Factories never build factories (this does not break Upgrades since CheckBuildRestriction is never called for Upgrades)
        -- Note: We check for the primary category, since e.g. AircraftCarriers have the FACTORY category.
        -- TODO: This is a hotfix for --1043, remove when engymod design is properly fixed
        return target_bp.General.Category ~= 'Factory'
    end,

    ---@param self FactoryUnit
    CalculateRollOffPoint = function(self)
        local px, py, pz = self:GetPositionXYZ()

        -- check if we have roll of points set
        local rollOffPoints = self.Blueprint.Physics.RollOffPoints
        if not rollOffPoints then
            return 0, px, py, pz
        end

        -- find our rally point, or of the factory that we're assisting
        local rally = self:GetRallyPoint()
        local focus = self:GetGuardedUnit()
        while focus and focus != self do
            local next = focus:GetGuardedUnit()
            if next then
                focus = next
            else
                break
            end
        end

        if focus then
            rally = focus:GetRallyPoint()
        end

        -- check if we have a rally point set
        if not rally then
            return 0, px, py, pz
        end

        -- find nearest roll off point for rally point
        local nearestRollOffPoint = nil
        local d, dx, dz, lowest = 0, 0, 0, nil
        for k, rollOffPoint in rollOffPoints do
            dx = rally[1] - (px + rollOffPoint.X)
            dz = rally[3] - (pz + rollOffPoint.Z)
            d = dx * dx + dz * dz

            if not lowest or d < lowest then
                nearestRollOffPoint = rollOffPoint
                lowest = d
            end
        end

        -- determine return parameters
        local spin = self.UnitBeingBuilt.Blueprint.Display.ForcedBuildSpin or nearestRollOffPoint.UnitSpin
        local fx = nearestRollOffPoint.X + px
        local fy = nearestRollOffPoint.Y + py
        local fz = nearestRollOffPoint.Z + pz

        return spin, fx, fy, fz
    end,

    ---@param self FactoryUnit
    ---@param unitBeingBuilt Unit
    StartBuildFx = function(self, unitBeingBuilt)
    end,

    ---@param self FactoryUnit
    StopBuildFx = function(self)
    end,

    ---@param self FactoryUnit
    PlayFxRollOff = function(self)
    end,

    ---@param self FactoryUnit
    PlayFxRollOffEnd = function(self)
        local rollOffAnim = self.RollOffAnim
        if rollOffAnim then
            rollOffAnim:SetRate(-1 * self.RollOffAnimationRate)
            WaitFor(rollOffAnim)
            rollOffAnim:Destroy()
            self.RollOffAnim = nil
        end
    end,

    ---@param self FactoryUnit
    RolloffBody = function(self)
        self:SetBusy(true)
        self:SetBlockCommandQueue(true)
        self:PlayFxRollOff()

        local unitBeingBuilt = self.UnitBeingBuilt --[[@as Unit]]

        -- find out when build pad is free again
        local size = unitBeingBuilt.Blueprint.SizeX
        if size < unitBeingBuilt.Blueprint.SizeZ then
            size = unitBeingBuilt.Blueprint.SizeZ
        end

        size = (0.5 * size) * (0.5 * size)
        local unitPosition, dx, dz, d
        local buildPosition = self:GetPosition(self.Blueprint.Display.BuildAttachBone or 0)
        repeat
            unitPosition = unitBeingBuilt:GetPosition()
            dx = buildPosition[1] - unitPosition[1]
            dz = buildPosition[3] - unitPosition[3]
            d = dx * dx + dz * dz
            WaitTicks(2)
        until IsDestroyed(unitBeingBuilt) or d > size

        self:PlayFxRollOffEnd()
        self:SetBusy(false)
        self:SetBlockCommandQueue(false)

        ChangeState(self, self.IdleState)
    end,

    --#endregion

    ---------------------------------------------------------------------------
    --#region States

    IdleState = State {
        ---@param self FactoryUnit
        Main = function(self)
            self:SetBusy(false)
            self:SetBlockCommandQueue(false)
        end,
    },

    BuildingState = State {
        ---@param self FactoryUnit
        Main = function(self)

            local unitBeingBuilt = self.UnitBeingBuilt --[[@as Unit]]

            -- to help prevent a 1-tick rotation on most units
            local hasEnhancements = unitBeingBuilt.Blueprint.Enhancements
            if not hasEnhancements then
                unitBeingBuilt:HideBone(0, true)
            end

            -- determine and preserve the roll off point
            local spin, x, y, z = self:CalculateRollOffPoint()
            local rollOffPoint = self.RollOffPoint
            rollOffPoint[1] = x
            rollOffPoint[2] = y
            rollOffPoint[3] = z

            self.BuildBoneRotator:SetGoal(spin)
            unitBeingBuilt:AttachBoneTo(-2, self, self.Blueprint.Display.BuildAttachBone or 0)
            self:StartBuildFx(unitBeingBuilt)

            -- prevents a 1-tick rotating visual 'glitch' of unit
            -- as it is being attached and the rotator is applied
            WaitTicks(3)
            if not hasEnhancements then
                unitBeingBuilt:ShowBone(0, true)
            end
        end,
    },

    RollingOffState = State {
        ---@param self FactoryUnit
        Main = function(self)
            self:RolloffBody()
        end,
    },

    UpgradingState = State(StructureUnit.UpgradingState) {
        --- Adapted from StructureUnit to unblock the build area when the factory upgrade finishes.
        ---@param self FactoryUnit
        ---@param unitBuilding Unit
        ---@param order string
        OnStopBuild = function(self, unitBuilding, order)
            UnitOnStopBuild(self, unitBuilding, order)
            self:EnableDefaultToggleCaps()

            if unitBuilding:GetFractionComplete() == 1 then
                NotifyUpgrade(self, unitBuilding)
                self:StopUpgradeEffects(unitBuilding)
                self:PlayUnitSound('UpgradeEnd')

                -- Since `Destroy` wouldn't do so, immediately unblock the build area
                -- of the new factory by setting collision shape to none. This allows
                -- the new factory to immediately start working on its queue.
                self:SetCollisionShape("None")

                self:Destroy()
            end
        end,
    },

    --#endregion

    ---------------------------------------------------------------------------
    --#region Utility functions

    ---@param self FactoryUnit
    ---@return string?
    ToSupportFactoryIdentifier = function(self)
        local blueprint = self.Blueprint
        local hashedCategories = blueprint.CategoriesHash
        local identifier = blueprint.BlueprintId
        local faction = identifier:sub(2, 2)
        local layer = identifier:sub(7, 7)

        -- HQs can not upgrade to support factories
        if hashedCategories["RESEARCH"] then
            return nil
        end

        -- tech 1 factories can go tech 2 support factories if we have a tech 2 hq
        if  hashedCategories["TECH1"] and
            self.Brain:CountHQs(blueprint.FactionCategory, blueprint.LayerCategory, 'TECH2') > 0
        then
            return 'z' .. faction .. 'b950' .. layer
        end

        -- tech 2 support factories can go tech 3 support factories if we have a tech 3 hq
        if  hashedCategories["TECH2"] and
            hashedCategories["SUPPORTFACTORY"] and
            self.Brain:CountHQs(blueprint.FactionCategory, blueprint.LayerCategory, 'TECH3') > 0
        then
            return 'z' .. faction .. 'b960' .. layer
        end

        -- anything else can not upgrade
        return nil
    end,

    ---@param self FactoryUnit
    ToHQFactoryIdentifier = function(self)
        local blueprint = self.Blueprint
        local hashedCategories = blueprint.CategoriesHash
        local identifier = blueprint.BlueprintId
        local faction = identifier:sub(1, 3)
        local layer = identifier:sub(7, 7)

        -- support factories can not upgrade to HQs
        if hashedCategories["SUPPORTFACTORY"] then
            return nil
        end

        -- tech 1 factories can always upgrade
        if hashedCategories["TECH1"] then
            return faction .. '020' .. layer
        end

        -- tech 2 factories can always upgrade
        if hashedCategories["TECH2"] and hashedCategories["RESEARCH"] then
            return faction .. '030'  .. layer
        end

        -- anything else can not upgrade
        return nil
    end,

    --#endregion


    ---------------------------------------------------------------------------
    --#region Blinking lights functionality

    ---@param self FactoryUnit
    ---@param state AIBrainMassStorageState
    OnMassStorageStateChange = function(self, state)
        if state == 'EconLowMassStore' then
            self:ChangeBlinkingLights('Red')
        else
            self:ChangeBlinkingLights('Green')
        end
    end,

    ---@param self FactoryUnit
    ---@param state AIBrainEnergyStorageState
    OnEnergyStorageStateChange = function(self, state)
        if state == 'EconLowEnergyStore' then
            self:ChangeBlinkingLights('Red')
        else
            self:ChangeBlinkingLights('Green')
        end
    end,

    --#endregion

    ---------------------------------------------------------------------------
    --#region Deprecated functionality

    ---@deprecated
    ---@param self FactoryUnit
    ---@param unitBeingBuilt Unit
    ---@param order string
    DoStopBuild = function(self, unitBeingBuilt, order)
        -- StructureUnitOnStopBuild(self, unitBeingBuilt, order)

        -- if not self.FactoryBuildFailed and not self.Dead then
        --     if not EntityCategoryContains(categories.AIR, unitBeingBuilt) then
        --         self:RollOffUnit()
        --     end
        --     self:StopBuildFx()
        --     self:ForkThread(self.FinishBuildThread, unitBeingBuilt, order)
        -- end
        -- self.BuildingUnit = false
    end,

    --- Adds a pause between unit productions
    ---@deprecated
    ---@param self FactoryUnit
    ---@param productionpause number
    ---@param unitBeingBuilt Unit
    ---@param order string
    PauseThread = function(self, productionpause, unitBeingBuilt, order)
        -- self:StopBuildFx()
        -- self:SetBusy(true)
        -- self:SetBlockCommandQueue(true)

        -- WaitSeconds(productionpause)

        -- self:SetBusy(false)
        -- self:SetBlockCommandQueue(false)
        -- self:DoStopBuild(unitBeingBuilt, order)
    end,

    ---@deprecated
    ---@param self FactoryUnit
    CreateBuildRotator = function(self)
    end,

    ---@deprecated
    ---@param self FactoryUnit
    DestroyBuildRotator = function(self)
    end,

    --#endregion
}
