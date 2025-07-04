#****************************************************************************
#**
#**  File     :  /hook/lua/UserSync.lua
#**  Author(s):  novaprim3
#**
#**  Summary  :  Multi-Phantom Mod for Forged Alliance
#**
#****************************************************************************

local EventAlertOnSync = OnSync
function OnSync()
	EventAlertOnSync ()
	
	#unit detecte
	if Sync.ExpDetectedEventAlert then
		import('/Mods/EventAlert FAF/lua/ui/EventTab.lua').EventAlertId(Sync.ExpDetectedEventAlert)
	end
	if Sync.NukeDetectedEventAlert then
		import('/Mods/EventAlert FAF/lua/ui/EventTab.lua').EventAlertId(Sync.NukeDetectedEventAlert)
	end
	if Sync.ArtDetectedEventAlert then
		import('/Mods/EventAlert FAF/lua/ui/EventTab.lua').EventAlertId(Sync.ArtDetectedEventAlert)
	end

	#exp destroy
	if Sync.EXPDestroyEventAlert then
		import('/Mods/EventAlert FAF/lua/ui/EventTab.lua').EventAlertId(Sync.EXPDestroyEventAlert)
	end
	
	#nuke destroy
	if Sync.NukeDestroyEventAlert then
		import('/Mods/EventAlert FAF/lua/ui/EventTab.lua').EventAlertId(Sync.NukeDestroyEventAlert)
	end
	
	#artillery destroy
	if Sync.ArtilleryDestroyEventAlert then
		import('/Mods/EventAlert FAF/lua/ui/EventTab.lua').EventAlertId(Sync.ArtilleryDestroyEventAlert)
		import('/Mods/EventAlert FAF/lua/ui/EventVoice.lua').ArtilleryDestory()
	end
end
