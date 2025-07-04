local mobileInterval = 60
local structureInterval = 60

local ResearchAIBrain = AIBrain
AIBrain = Class(ResearchAIBrain) {
    OnCreateHuman = function(self, planName)
    	ResearchAIBrain.OnCreateHuman(self)
		ForkThread(ABSyspath.AbilityGeneratedThread, self)
		ForkThread(ABSyspath.AbilityKillsThread, self)
		ForkThread(Enhpath.EcoStructureAddThread, self)
		ForkThread(Enhpath.BuildrateBuffThread, self)
		ForkThread(Enhpath.EcoBalanceExchange, self)
		ForkThread(Enhpath.KillReclaim, self)
		ForkThread(VOTable, self)
    end,
	
	--https://github.com/FAForever/fa/blob/develop/lua/aibrain.lua
    VOSounds = {
        NuclearLaunchDetected = { timeout = 1, bank = nil, obs = true },
        OnTransportFull = { timeout = 1, bank = nil },
        OnFailedUnitTransfer = { timeout = 10, bank = 'Computer_Computer_CommandCap_01298' },
        OnPlayNoStagingPlatformsVO = { timeout = 5, bank = 'XGG_Computer_CV01_04756' },
        OnPlayBusyStagingPlatformsVO = { timeout = 5, bank = 'XGG_Computer_CV01_04755' },
        OnPlayCommanderUnderAttackVO = { timeout = 15, bank = 'Computer_Computer_Commanders_01314' },
		
		#how to use table.merged() here???
		uel0401 = { timeout = mobileInterval},
		ues0401 = { timeout = mobileInterval},
		ueb2401 = { timeout = structureInterval},
		url0402 = { timeout = mobileInterval},
		ura0401 = { timeout = mobileInterval},
		url0401 = { timeout = mobileInterval},
		ual0401 = { timeout = mobileInterval},
		uaa0310 = { timeout = mobileInterval},
		uas0401 = { timeout = mobileInterval},
		xab1401 = { timeout = structureInterval},
		xsl0401 = { timeout = mobileInterval},
		xsa0402 = { timeout = mobileInterval},
		xsb2401 = { timeout = structureInterval},
		OtherExpUnits = { timeout = 60},
    },
} 
