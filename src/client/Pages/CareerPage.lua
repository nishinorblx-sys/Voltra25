--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local PageBase = require(script.Parent.PageBase)
local Button = require(script.Parent.Parent.Components.Button)
local CareerService = require(script.Parent.Parent.Services.PlayerCareerService)
local NetworkClient = require(script.Parent.Parent.Services.NetworkClient)

local Page = {}
local C = Theme.Colors

local function operationId(prefix: string): string
	return prefix .. "_" .. HttpService:GenerateGUID(false)
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0.5
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function text(parent: Instance, value: string, pos: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Text = value
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = font or Theme.Fonts.Body
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

local function shell(parent: Instance, name: string, size: UDim2, color: Color3?, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color or C.Graphite
	frame.BackgroundTransparency = transparency or 0.08
	frame.BorderSizePixel = 0
	frame.Size = size
	frame.Parent = parent
	corner(frame, 8)
	stroke(frame, C.Border, 0.25, 1)
	return frame
end

local function energyStrips(parent: Instance)
	for index = 1, 7 do
		local strip = Instance.new("Frame")
		strip.Name = "CareerEnergyStrip"
		strip.AnchorPoint = Vector2.new(0.5, 0.5)
		strip.BackgroundColor3 = index % 2 == 0 and C.Electric or Color3.fromHex("24C6B8")
		strip.BackgroundTransparency = 0.78 + index * 0.02
		strip.BorderSizePixel = 0
		strip.Position = UDim2.new(0.1 + index * 0.13, 0, 0.5, 0)
		strip.Size = UDim2.fromScale(0.012, 1.4)
		strip.Rotation = 24
		strip.Parent = parent
	end
end

local function actionButton(parent: Instance, title: string, variant: string?, x: number, y: number, callback: () -> ())
	local button = Button.new({Text = title, Variant = variant, Size = UDim2.fromOffset(154, 38), OnActivated = callback})
	button.Position = UDim2.fromOffset(x, y)
	button.Parent = parent
	return button
end

local function metric(parent: Instance, title: string, value: string, meta: string, x: number, accent: boolean?)
	local frame = shell(parent, title:gsub("%W", "") .. "Metric", UDim2.fromOffset(152, 82), accent and C.Electric or C.Gunmetal, accent and 0.02 or 0.1)
	frame.Position = UDim2.fromOffset(x, 176)
	text(frame, title, UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 16), 9, accent and C.Black or C.Muted, Theme.Fonts.Strong)
	text(frame, value, UDim2.fromOffset(12, 26), UDim2.new(1, -24, 0, 28), 24, accent and C.Black or C.White, Theme.Fonts.Display)
	text(frame, meta, UDim2.fromOffset(12, 55), UDim2.new(1, -24, 0, 16), 9, accent and C.Black or C.Silver, Theme.Fonts.Body)
end

local function detailPanel(parent: Instance, title: string, body: string, meta: string, actionText: string?, callback: (() -> ())?)
	local frame = shell(parent, title:gsub("%W", "") .. "Panel", UDim2.new(1, 0, 0, actionText and 132 or 112), C.Graphite, 0.06)
	text(frame, string.upper(title), UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 18), 12, C.White, Theme.Fonts.Strong)
	text(frame, body, UDim2.fromOffset(16, 36), UDim2.new(1, -32, 0, 24), 13, C.Silver, Theme.Fonts.Body)
	text(frame, meta, UDim2.fromOffset(16, 64), UDim2.new(1, -32, 0, 20), 10, C.Muted, Theme.Fonts.Body)
	if actionText and callback then actionButton(frame, actionText, nil, 16, 88, callback) end
	return frame
end

local function selectedSlot(hub: any): number
	return math.clamp(math.floor(tonumber(hub and hub.SelectedSlot) or 1), 1, 3)
end

function Page.new(_context: any): Frame
	local group, scroll = PageBase.new("Career", 1380)
	PageBase.heading(scroll, "PLAYER STORY", "MY CAREER", "One footballer. One place in the squad. Every decision earned.")

	local root = Instance.new("Frame")
	root.Name = "CareerCommandCenter"
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromOffset(0, 98)
	root.Size = UDim2.new(1, 0, 0, 1220)
	root.Parent = scroll

	local status = text(root, "LOADING CAREER", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 20), 10, C.Muted, Theme.Fonts.Strong)

	local function setStatus(value: string)
		status.Text = string.upper(value)
	end

	local function clear()
		for _, child in root:GetChildren() do
			if child ~= status then child:Destroy() end
		end
	end

	local function render(hub: any) end

	local function invoke(action: string, payload: any?)
		setStatus("Working")
		task.defer(function()
			local response = CareerService.Action(action, payload)
			setStatus(response.Success and (response.Message or "Done") or (response.Message or "Career action failed"))
			render(CareerService.GetHub())
		end)
	end

	function render(hub: any)
		clear()
		local slotNumber = selectedSlot(hub)
		local active = hub and hub.ActiveCareer
		local hasPlayer = type(active) == "table" and active.Type == "Player"
		local isManager = type(active) == "table" and active.Type == "Manager"
		setStatus(hub and "Career data loaded" or "Career data unavailable")

		local hero = shell(root, "CareerHero", UDim2.new(1, 0, 0, 284), Color3.fromHex("050807"), 0.02)
		hero.Position = UDim2.fromOffset(0, 30)
		hero.ClipsDescendants = true
		energyStrips(hero)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("0B1511")),
			ColorSequenceKeypoint.new(0.45, Color3.fromHex("101419")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("050505")),
		})
		gradient.Rotation = 16
		gradient.Parent = hero

		local crest = Instance.new("Frame")
		crest.Name = "CareerIdentityCore"
		crest.BackgroundColor3 = hasPlayer and C.Electric or C.Gunmetal
		crest.BackgroundTransparency = hasPlayer and 0 or 0.08
		crest.Position = UDim2.fromOffset(24, 34)
		crest.Size = UDim2.fromOffset(124, 124)
		crest.Rotation = 45
		crest.Parent = hero
		corner(crest, 18)
		stroke(crest, C.White, 0.18, 2)
		local crestText = text(crest, hasPlayer and tostring(active.Position or "ST") or isManager and "MGR" or "NEW", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 24, hasPlayer and C.Black or C.White, Theme.Fonts.Display)
		crestText.Rotation = -45
		crestText.TextXAlignment = Enum.TextXAlignment.Center

		local name = hasPlayer and tostring(active.Name or "Career Player") or isManager and tostring(active.Name or "Manager Career") or "CREATE YOUR FOOTBALLER"
		local club = hasPlayer and tostring(active.Club or "VOLTRA ACADEMY") or isManager and tostring(active.Club or "NO CLUB") or "BUILD YOUR PLAYER STORY"
		text(hero, "SLOT " .. tostring(slotNumber) .. " / " .. (hasPlayer and "PLAYER LOCK CAREER" or isManager and "MANAGER SAVE" or "EMPTY SAVE"), UDim2.fromOffset(176, 34), UDim2.new(1, -210, 0, 18), 10, C.Electric, Theme.Fonts.Strong)
		text(hero, string.upper(name), UDim2.fromOffset(174, 56), UDim2.new(1, -210, 0, 58), 38, C.White, Theme.Fonts.Display)
		text(hero, club, UDim2.fromOffset(178, 116), UDim2.new(1, -220, 0, 22), 13, C.Silver, Theme.Fonts.Strong)
		text(hero, hasPlayer and "Selection, training, match day, agent and story decisions shape your season." or "Pick a slot below, then start a player career or preserve your manager save.", UDim2.fromOffset(178, 142), UDim2.new(1, -220, 0, 26), 11, C.Muted, Theme.Fonts.Body)

		metric(hero, "OVR", hasPlayer and tostring(active.Overall or "--") or "--", hasPlayer and tostring(active.Position or "--") or "Position", 176, true)
		metric(hero, "FIT", hasPlayer and tostring(active.Condition and active.Condition.Fitness or "--") or "--", "Match fitness", 340, false)
		metric(hero, "TRUST", hasPlayer and tostring(active.ClubState and active.ClubState.ManagerTrust or "--") or "--", "Manager", 504, false)
		metric(hero, "FORM", hasPlayer and tostring(active.Condition and active.Condition.Form or "--") or "--", "Trend", 668, false)

		if hasPlayer then
			actionButton(hero, "Prepare Match", "Primary", 24, 188, function()
				invoke("StartCareerMatch", {CareerId = active.CareerId, Slot = active.Slot, FixtureId = active.Calendar and active.Calendar.NextActivity or "", OperationId = operationId("match")})
			end)
			actionButton(hero, "Sim Match", nil, 190, 188, function()
				invoke("SimulateCareerMatch", {CareerId = active.CareerId, Slot = active.Slot, OperationId = operationId("sim")})
			end)
			actionButton(hero, "Advance Day", nil, 356, 188, function()
				invoke("AdvanceCareerDay", {CareerId = active.CareerId, Slot = active.Slot, OperationId = operationId("day")})
			end)
		end

		local slots = shell(root, "SaveSlotDeck", UDim2.new(1, 0, 0, 138), C.Graphite, 0.08)
		slots.Position = UDim2.fromOffset(0, 330)
		text(slots, "CAREER SAVE DECK", UDim2.fromOffset(18, 8), UDim2.new(1, -36, 0, 20), 12, C.White, Theme.Fonts.Strong)
		for index, slot in hub and hub.Slots or {{Slot = 1, Type = "Empty"}, {Slot = 2, Type = "Empty"}, {Slot = 3, Type = "Empty"}} do
			local x = 18 + (index - 1) * 218
			local item = shell(slots, "Slot" .. tostring(slot.Slot), UDim2.fromOffset(198, 82), slot.Slot == slotNumber and C.Electric or C.Gunmetal, slot.Slot == slotNumber and 0.02 or 0.12)
			item.Position = UDim2.fromOffset(x, 44)
			text(item, "SLOT " .. tostring(slot.Slot), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 16), 9, slot.Slot == slotNumber and C.Black or C.Muted, Theme.Fonts.Strong)
			text(item, slot.Type == "Empty" and "EMPTY" or tostring(slot.Name or slot.Type), UDim2.fromOffset(12, 28), UDim2.new(1, -24, 0, 22), 13, slot.Slot == slotNumber and C.Black or C.White, Theme.Fonts.Strong)
			text(item, slot.Type == "Player" and ("OVR " .. tostring(slot.Overall or "--") .. " / " .. tostring(slot.Position or "--")) or slot.Type == "Manager" and "MANAGER SAVE" or "READY", UDim2.fromOffset(12, 54), UDim2.new(1, -24, 0, 16), 9, slot.Slot == slotNumber and C.Black or C.Silver, Theme.Fonts.Body)
			local hit = Instance.new("TextButton")
			hit.Name = "SelectSlot"
			hit.BackgroundTransparency = 1
			hit.Text = ""
			hit.Size = UDim2.fromScale(1, 1)
			hit.Parent = item
			hit.Activated:Connect(function()
				invoke("SelectCareer", {Slot = slot.Slot})
			end)
		end
		actionButton(slots, "Create Player", "Primary", 684, 46, function()
			invoke("CreatePlayerCareer", {Slot = slotNumber, FirstName = "Rin", LastName = "Vale", ShortName = "Rin Vale", Nationality = "Voltra", PrimaryPosition = "CAM", OriginId = "academy_graduate", ArchetypeId = "advanced_creator", OperationId = operationId("create")})
		end)
		actionButton(slots, "Create Manager", nil, 850, 46, function()
			invoke("CreateManagerCareer", {Slot = slotNumber, OperationId = operationId("manager")})
		end)
		actionButton(slots, "Delete Slot", "Danger", 684, 90, function()
			invoke("DeleteCareer", {Slot = slotNumber, OperationId = operationId("delete")})
		end)

		local left = Instance.new("Frame")
		left.BackgroundTransparency = 1
		left.Position = UDim2.fromOffset(0, 486)
		left.Size = UDim2.new(0.5, -8, 0, 680)
		left.Parent = root
		local leftLayout = Instance.new("UIListLayout")
		leftLayout.Padding = UDim.new(0, 12)
		leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
		leftLayout.Parent = left

		local right = Instance.new("Frame")
		right.BackgroundTransparency = 1
		right.Position = UDim2.new(0.5, 8, 0, 486)
		right.Size = UDim2.new(0.5, -8, 0, 680)
		right.Parent = root
		local rightLayout = Instance.new("UIListLayout")
		rightLayout.Padding = UDim.new(0, 12)
		rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rightLayout.Parent = right

		if not hasPlayer then
			detailPanel(left, "Player Career Concept", "Create your footballer and play as one locked player.", "Origins, archetypes, weighted OVR and long-term state are ready.", nil, nil)
			detailPanel(right, "What Carries Forward", "Manager saves stay safe. Empty slots can become Player or Manager.", "Use the save deck above to pick the target slot.", nil, nil)
			return
		end

		local condition = active.Condition or {}
		local clubState = active.ClubState or {}
		local contract = active.Contract or {}
		local calendar = active.Calendar or {}
		local training = active.Training or {}
		local story = active.Story or {}
		local stats = active.Statistics and active.Statistics.Career or {}
		local activeSession = training.ActiveSession

		detailPanel(left, "Match Day Brief", "Next activity: " .. tostring(calendar.NextActivity or "training"), "Role: " .. tostring(clubState.SquadRole or "Development Player") .. " / Tactical fit " .. tostring(clubState.TacticalFit or 0), "Prepare Match", function()
			invoke("StartCareerMatch", {CareerId = active.CareerId, Slot = active.Slot, FixtureId = calendar.NextActivity or "", OperationId = operationId("brief")})
		end)
		detailPanel(left, "Training Lab", activeSession and ("Active: " .. tostring(activeSession.DrillId)) or "Scan-and-receive drill ready.", "Drill score, grade and growth progress are tracked after each session.", activeSession and "Complete B" or "Start Drill", function()
			if activeSession then
				invoke("CompleteTraining", {CareerId = active.CareerId, Slot = active.Slot, TrainingSessionId = activeSession.TrainingSessionId, Score = 760, OperationId = operationId("train_done")})
			else
				invoke("StartTraining", {CareerId = active.CareerId, Slot = active.Slot, DrillId = "scan_and_receive", Difficulty = "Normal", OperationId = operationId("train_start")})
			end
		end)
		detailPanel(left, "Development Identity", tostring(active.Archetype or "archetype") .. " / " .. tostring(active.Origin or "origin"), "Hidden decimal attributes feed a weighted " .. tostring(active.Position or "ST") .. " overall.", nil, nil)
		detailPanel(left, "Condition Room", "Fitness " .. tostring(condition.Fitness or 0) .. " / Fatigue " .. tostring(condition.Fatigue or 0) .. " / Sharpness " .. tostring(condition.Sharpness or 0), "Morale " .. tostring(condition.Morale or 0) .. " / Injury risk " .. tostring(condition.InjuryRisk or 0), nil, nil)

		detailPanel(right, "Coach View", "Trust " .. tostring(clubState.ManagerTrust or 0) .. " / Squad role " .. tostring(clubState.SquadRole or "Development Player"), "Contract role: " .. tostring(contract.SquadRole or "Prospect") .. " / Shirt #" .. tostring(clubState.ShirtNumber or "--"), nil, nil)
		detailPanel(right, "Agent Desk", "Requests, offers and market posture live here.", "Current club: " .. tostring(contract.ClubId or "voltra_academy") .. " / Deal ends " .. tostring(contract.EndDate or "--"), "Request Move", function()
			invoke("RequestTransfer", {CareerId = active.CareerId, Slot = active.Slot, Reason = "Playing time", OperationId = operationId("transfer")})
		end)
		detailPanel(right, "Story Pulse", tostring(type(story.Inbox) == "table" and #story.Inbox or 0) .. " inbox messages / " .. tostring(type(story.SocialFeed) == "table" and #story.SocialFeed or 0) .. " feed posts", "Arcs react to career flags, relationships and selection state.", nil, nil)
		detailPanel(right, "Career Record", tostring(stats.Appearances or 0) .. " appearances / " .. tostring(stats.Minutes or 0) .. " minutes", "Average rating " .. tostring(math.floor((tonumber(stats.AverageRating) or 6) * 10 + 0.5) / 10), nil, nil)
	end

	task.defer(function()
		render(CareerService.GetHub())
	end)

	local disconnect = NetworkClient:Observe("Career", function(payload)
		render(payload)
	end)
	group.Destroying:Connect(disconnect)

	return group
end

return Page
