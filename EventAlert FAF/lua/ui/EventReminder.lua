--*****************************************************************************
--* File: lua/modules/ui/game/chat.lua
--* Author: Chris Blackwell
--* Summary: In game chat ui
--*
--* Copyright © :005 Gas Powered Games, Inc.  All rights reserved.
--*****************************************************************************
local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local scale = import('/lua/user/prefs.lua').GetFromCurrentProfile("options.ui_scale") or 1
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Button = import('/lua/maui/button.lua').Button
local Tooltip = import('/lua/ui/game/tooltip.lua')

local eventCamSize = 150

GUI = {
    bg = false,
}

local zoom = 15
local hpr = { -3.1415901184082, 1.58, 0 }

function CreatEventCam(parentBtn, pos, id, color, title)
    if id then
	    KillEventMonitor()
		GUI.bg = CreateWindow(parentBtn, pos, color, title)
	end
end

function CreateWindow(Btn, pos, color, title)
    local eventTitle = Bitmap(GetFrame(0))
	eventTitle.Width:Set(eventCamSize*scale)
	eventTitle.Height:Set(36*scale)
	eventTitle.Left:Set(function() return Btn.Left() end)
	eventTitle.Top:Set(function() return Btn.Bottom() end)
	eventTitle.Depth:Set(0)
	eventTitle:SetSolidColor('E6333333')
	
    eventTitle.text= UIUtil.CreateText(eventTitle, title, 16, UIUtil.bodyFont)
    LayoutHelpers.AtCenterIn(eventTitle.text, eventTitle)
	
    local camBG = Bitmap(eventTitle)
	camBG.Width:Set(eventCamSize*scale)
	camBG.Height:Set(eventCamSize*scale)
	camBG.Left:Set(function() return eventTitle.Left() end)
	camBG.Top:Set(function() return eventTitle.Bottom() end)
	camBG.Depth:Set(0)
	
	local eventCam = import('/lua/ui/controls/worldview.lua').WorldView(camBG, 'EventReminder', 2, true, 'WorldCamera')    -- depth value is above minimap
	eventCam:SetRenderPass(UIUtil.UIRP_UnderWorld)
	LayoutHelpers.FillParent(eventCam, camBG)
    eventCam.Depth:Set(camBG.Depth() + 5)
    eventCam:SetNeedsFrameUpdate(true)

	GetCamera('EventReminder'):SnapTo(pos, hpr, zoom)
	
	eventCam.HandleEvent = function(self, event)
	    if event.Type == 'MouseExit' then
		    #not in drag buid mode, if we are in drag build, we cannot turn On/Off the minimap, otherwise the sudden appearing/disappearing of minimap will cause building in error.
			#['01'] = 'LeftMouse'
			if not IsKeyDown('1') then 
			    KillEventMonitor()
			end
		end
	end

	return eventTitle
end

function KillEventMonitor()
    if GUI.bg then 
	    GUI.bg:Destroy()
	end
end