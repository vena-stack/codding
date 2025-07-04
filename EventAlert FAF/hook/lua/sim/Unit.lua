#****************************************************************************
#**
#**  File     :  /lua/unit.lua
#**  Author(s):  John Comes, David Tomandl, Gordon Duclos
#**
#**  Summary  : The Unit lua module
#**
#**  Copyright ?2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************
-- not super smart but working
local EventAlertUnit = Unit
Unit = Class(EventAlertUnit) {    
    OnDetectedBy = function(self, index)
		EventAlertUnit.OnDetectedBy(self, index)
		import('/mods/EventAlert FAF/lua/EventControl.lua').UnitDetected(self)
    end,
	
	OnDestroy = function(self)
		EventAlertUnit.OnDestroy(self)
		import('/mods/EventAlert FAF/lua/EventControl.lua').UnitDestroy(self)
    end,
}

