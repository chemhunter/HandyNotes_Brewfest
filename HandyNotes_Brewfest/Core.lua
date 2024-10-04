
-- declaration
local addOnName, Brewfest = ...
local L = Brewfest.L
Brewfest.points = {}

-- our db and defaults
local db
local defaults = { profile = { completed = false, icon_scale = 1.4, icon_alpha = 0.8 } }

local continents = {
	[1978] = true, -- Dragon Isles
	[2025] = true, -- Thaldraszus
}

local notes = {
	-- Arathi
	[77152] = "Bar Tab Barrel.",
	[77745] = "Bar Tab Barrel.",
	[77099] = "Bar Tab Barrel.",
	[77747] = "Bar Tab Barrel.",
	[77155] = "Bar Tab Barrel.",
	[77153] = "Bar Tab Barrel.",
	[77096] = "Bar Tab Barrel.",
	[77746] = "Bar Tab Barrel.",
	[77097] = "Bar Tab Barrel.",
	[77744] = "Bar Tab Barrel.",
	[76531] = "Bar Tab Barrel.",
	[77095] = "Bar Tab Barrel.",
}

-- upvalues
local C_Calendar = _G.C_Calendar
local C_DateAndTime = _G.C_DateAndTime
local C_Map = _G.C_Map
local GetAllCompletedQuestIDs = _G.C_QuestLog.GetAllCompletedQuestIDs
local GetQuestsCompleted = _G.GetQuestsCompleted
local C_Timer_After = _G.C_Timer.After
local GameTooltip = _G.GameTooltip
local IsControlKeyDown = _G.IsControlKeyDown
local UIParent = _G.UIParent

local LibStub = _G.LibStub
local HandyNotes = _G.HandyNotes
local TomTom = _G.TomTom

local completedQuests = {}
local points = Brewfest.points


-- plugin handler for HandyNotes
function Brewfest:OnEnter(mapFile, coord)
	if self:GetCenter() > UIParent:GetCenter() then -- compare X coordinate
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end

	local questID = points[mapFile] and points[mapFile][coord]
	GameTooltip:SetText(L["Brewfest"])

	if notes[questID] then
		GameTooltip:AddLine(notes[questID])
		--GameTooltip:AddLine(" ")
	end

	if TomTom then
		GameTooltip:AddLine("Right-click to set a waypoint.", 1, 1, 1)
		GameTooltip:AddLine("Control-Right-click to set waypoints to every bonfire.", 1, 1, 1)
	end

	GameTooltip:Show()
end

function Brewfest:OnLeave()
	GameTooltip:Hide()
end

local function createWaypoint(mapFile, coord)
	local x, y = HandyNotes:getXY(coord)
	local point = points[mapFile] and points[mapFile][coord]
	local text = L["Bar Tab Barrel."]

	TomTom:AddWaypoint(mapFile, x, y, { title = text, from = addOnName, persistent = false, minimap = true, world = true })
end

local function createAllWaypoints()
	for mapFile, coords in next, points do
		if not continents[mapFile] then
			for coord, value in next, coords do
				local questID = value

				if coord and (db.completed or not completedQuests[tonumber(questID)]) then
					createWaypoint(mapFile, coord)
				end
			end
		end
	end

	TomTom:SetClosestWaypoint()
end

function Brewfest:OnClick(button, down, mapFile, coord)
	if TomTom and button == "RightButton" and not down then
		if IsControlKeyDown() then
			createAllWaypoints()
		else
			createWaypoint(mapFile, coord)
		end
	end
end


do
	-- custom iterator we use to iterate over every node in a given zone
	local function iterator(t, prev)
		if not Brewfest.isEnabled then return end
		if not t then return end

		local coord, value = next(t, prev)
		while coord do
			local questID = value
			local icon =132800

			if value and (db.completed or not completedQuests[tonumber(questID)]) then
				return coord, nil, icon, db.icon_scale, db.icon_alpha
			end

			coord, value = next(t, coord)
		end
	end

	function Brewfest:GetNodes2(mapID)
		return iterator, points[mapID]
	end
end


-- config
local options = {
	type = "group",
	name = L["Brewfest"],
	desc = L["Desc"],
	get = function(info) return db[info[#info]] end,
	set = function(info, v)
		db[info[#info]] = v
		Brewfest:Refresh()
	end,
	args = {
		desc = {
			name = "These settings control the look and feel of the icon.",
			type = "description",
			order = 1,
		},
		completed = {
			name = "Show completed",
			desc = "Show icons for quests you have already visited.",
			type = "toggle",
			width = "full",
			arg = "completed",
			order = 2,
		},
		icon_scale = {
			type = "range",
			name = "Icon Scale",
			desc = "Change the size of the icons.",
			min = 0.25, max = 2, step = 0.01,
			arg = "icon_scale",
			order = 3,
		},
		icon_alpha = {
			type = "range",
			name = "Icon Alpha",
			desc = "Change the transparency of the icons.",
			min = 0, max = 1, step = 0.01,
			arg = "icon_alpha",
			order = 4,
		},
	},
}


-- check
local setEnabled = false
local function CheckEventActive()
	local calendar = C_DateAndTime.GetCurrentCalendarTime()
	local month, day, year = calendar.month, calendar.monthDay, calendar.year
	local hour, minute = calendar.hour, calendar.minute

	local monthInfo = C_Calendar.GetMonthInfo()
	local curMonth, curYear = monthInfo.month, monthInfo.year

	local monthOffset = -12 * (curYear - year) + month - curMonth
	local numEvents = C_Calendar.GetNumDayEvents(monthOffset, day)

	for i=1, numEvents do
		local event = C_Calendar.GetDayEvent(monthOffset, day, i)
		--print(event.title)
		if event.iconTexture == 235441 then
			setEnabled = event.sequenceType == "ONGOING"
			if event.sequenceType == "START" then
				setEnabled = hour >= event.startTime.hour and (hour > event.startTime.hour or minute >= event.startTime.minute)
			elseif event.sequenceType == "END" then
				setEnabled = hour <= event.endTime.hour and (hour < event.endTime.hour or minute <= event.endTime.minute)
			end
		end
	end

	if setEnabled and not Brewfest.isEnabled then
			for _, id in ipairs(GetAllCompletedQuestIDs()) do
				completedQuests[id] = true
			end
		Brewfest.isEnabled = true
		Brewfest:Refresh()
		Brewfest:RegisterEvent("QUEST_TURNED_IN", "Refresh")

		HandyNotes:Print(L['Began'])
	elseif not setEnabled and Brewfest.isEnabled then
		Brewfest.isEnabled = false
		Brewfest:Refresh()
		Brewfest:UnregisterAllEvents()

		HandyNotes:Print(L['Ended'] )
	end
end

local function RepeatingCheck()
	CheckEventActive()
	C_Timer_After(60, RepeatingCheck)
end


-- initialise
function Brewfest:OnEnable()
	self.isEnabled = false

	local HereBeDragons = LibStub("HereBeDragons-2.0", true)
	if not HereBeDragons then
		HandyNotes:Print(L['LowVersionHandyNotes'])
		return
	end

	for continentMapID in next, continents do
		local children = C_Map.GetMapChildrenInfo(continentMapID, nil, true)
		if not children then 
			HandyNotes:Print("Map ID " .. continentMapID .. " has invalid data.  Please inform the author of HandyNotes_Brewfest.")
		else
			for _, map in next, children do
				local coords = points[map.mapID]
				if coords then
					for coord, criteria in next, coords do
						local mx, my = HandyNotes:getXY(coord)
						local cx, cy = HereBeDragons:TranslateZoneCoordinates(mx, my, map.mapID, continentMapID, false)
						if cx and cy then
							points[continentMapID] = points[continentMapID] or {}
							points[continentMapID][HandyNotes:getCoord(cx, cy)] = criteria
						end
					end
				end
			end
		end
	end

	local calendar = C_DateAndTime.GetCurrentCalendarTime()
	C_Calendar.SetAbsMonth(calendar.month, calendar.year)
	CheckEventActive()

	HandyNotes:RegisterPluginDB("Brewfest", self, options)
	db = LibStub("AceDB-3.0"):New("HandyNotes_BrewfestDB", defaults, "Default").profile

	self:RegisterEvent("CALENDAR_UPDATE_EVENT", CheckEventActive)
	self:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST", CheckEventActive)
	self:RegisterEvent("ZONE_CHANGED", CheckEventActive)

	C_Timer_After(60, RepeatingCheck)
end

function Brewfest:Refresh(_, questID)
	if questID then completedQuests[questID] = true end
	self:SendMessage("HandyNotes_NotifyUpdate", "Brewfest")
end


-- activate
LibStub("AceAddon-3.0"):NewAddon(Brewfest, addOnName, "AceEvent-3.0")
