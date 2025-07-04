--*****************************************************************************
--* File: lua/modules/ui/game/chat.lua
--* Author: Chris Blackwell
--* Summary: In game chat ui
--*
--* Copyright ?:005 Gas Powered Games, Inc.  All rights reserved.
--*****************************************************************************
local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Button = import('/lua/maui/button.lua').Button
local Prefs = import('/lua/user/prefs.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local scale = Prefs.GetFromCurrentProfile("options.ui_scale") or 1

local buttonSize = 30
local backgroundWidth = 60
local btnBGWidth = 60
local eventRemoveThread = false
local eventRemoveInterval = 300

GUI = {
    eventBG = false,
}

local eventTable = {}

function EventAlertId(data)
    #10 event recorders
    if table.getn(eventTable) <= 9 then
	    table.insert(eventTable, data)
	else
	    table.removeByValue(eventTable, eventTable[1])
		table.insert(eventTable, data)
	end
	Initial()
end

function Initial()
    GUI.eventBG = CreateDialog()
end

function CreateDialog()
    KillEventDialog()

	eventBG = Bitmap(GetFrame(0))
	eventBG.Width:Set(backgroundWidth*scale)
	eventBG.Height:Set(buttonSize*scale)
	LayoutHelpers.AtTopIn(eventBG, GetFrame(0), 12*scale)
    LayoutHelpers.AtHorizontalCenterIn(eventBG, GetFrame(0))
	eventBG.Depth:Set(function() return GetFrame(0).Depth() + 10 end)
		
    -- tab layout
	local prev = false
	local icon = false
    for index, key in eventTable do
		if DiskGetFileInfo('/textures/ui/common/icons/units/'..key[2]..'_icon.dds') then
	        icon = UIUtil.UIFile('/textures/ui/common/icons/units/'..key[2]..'_icon.dds')
		else
		    icon = DiskFindFiles('/mods', key[2]..'_icon.dds')
		end
		
		curButton = Button(eventBG, icon, icon, icon, icon)
		curButton.Height:Set(buttonSize*scale)
		curButton.Width:Set(buttonSize*scale)
		curButton.Depth:Set(function() return eventBG.Depth() + 10 end)
		
		eventBG.Width:Set(backgroundWidth*index*scale)
		
        if prev then
            LayoutHelpers.RightOf(curButton, prev, (btnBGWidth-buttonSize))
        else
			LayoutHelpers.AtLeftTopIn(curButton, eventBG)
        end
        prev = curButton
		
		local tempTable = {}
	    tempTable = {
	    	button = curButton,
	    	pos = key[1],
			id = key[2],
			army = key[3],
			text = key[4],
	    }
		
		local btnBG = Bitmap(tempTable.button)
		local armyColor = GetArmiesTable().armiesTable[tempTable.army].color or 'FF004142' --observer
		btnBG:SetSolidColor(armyColor)

		btnBG.Width:Set(btnBGWidth*scale)
		btnBG.Height:Set(buttonSize*scale)
		LayoutHelpers.AtLeftTopIn(btnBG, tempTable.button)
		btnBG.Depth:Set(function() return tempTable.button.Depth() - 1 end)
		
		#not in drag buid mode, if we are in drag build, we cannot turn On/Off the minimap, otherwise the sudden appearing/disappearing of minimap will cause building in error.
		#['01'] = 'LeftMouse'
		#key down means holding a key, button press/mouse click means pressing the button once and then release it
		if not IsKeyDown('1') then 
		    import('/mods/EventAlert FAF/lua/ui/EventReminder.lua').CreatEventCam(tempTable.button, tempTable.pos, {tempTable.id}, armyColor, tempTable.text)
		end

		tempTable.button.HandleEvent = function(self, event)
		    if event.Type == 'MouseEnter' then
			    if not IsKeyDown('1') then 
				    import('/mods/EventAlert FAF/lua/ui/EventReminder.lua').CreatEventCam(tempTable.button, tempTable.pos, {tempTable.id}, armyColor, tempTable.text)
					PlaySound(Sound({Bank = 'Interface', Cue = 'UI_Opt_Mini_Button_Over'}))
				end
			end
		end
    end
	
	return eventBG
end

function KillEventDialog()
    if GUI.eventBG then 
	    GUI.eventBG:Destroy() 
		import('/mods/EventAlert FAF/lua/ui/EventReminder.lua').KillEventMonitor()
	end
end